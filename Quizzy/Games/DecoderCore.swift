//
//  DecoderCore.swift — Kaffa
//  Decoder: an original colour-code deduction game (4 DISTINCT colours out of
//  6, 7 attempts). Pure Foundation: no UI, no UIKit, no PuzzleProgress. The same
//  file is compiled by iOS, macOS (inert), watchOS and the Tests/Decoder
//  harness, so the rules cannot drift between the phone and the wrist.
//
//  Rules (stated once, used everywhere):
//   - The secret is 4 DIFFERENT colours drawn from 6 (360 possible codes).
//     Colours NEVER repeat: not in the secret and not in any guess (rules v2).
//   - 7 attempts. Every guess must fill all 4 slots with 4 different colours.
//   - Feedback is AGGREGATE: `exact` = right colour in the right slot,
//     `misplaced` = right colour in another slot, counted with multiplicities.
//     It never says which slot is which.
//   - A finished game (won or lost) is immutable.
//

import Foundation

// MARK: - Palette

/// Eight LED-style colours, each with its own NAME and NUMBER. The first six
/// (rawValue 0...5, same order as before) are the daily palette; `orange` and
/// `cyan` (6, 7) only appear in Infinite levels 16+ / 31+.
///
/// API change: rawValue 5 used to be `graphite` (a dull grey). It is now
/// `violet`, a lit LED colour like the rest of the device. Stored data holds
/// raw indices only, so old guesses restore unchanged (their grey simply
/// renders violet). `red` also moved from vermilion to a true LED red so it is
/// not confused with `orange`.
///
/// The UI draws no symbol on keys or on the knob; the name is always the
/// accessible label and the number is shown only when the system's
/// "Differentiate Without Colour" is on.
enum DecoderColor: Int, CaseIterable, Sendable {
    case red = 0, yellow, green, blue, pink, violet, orange, cyan

    var number: Int { rawValue + 1 }

    /// LEGACY, NOT RENDERED. Kept only because the harness checks it is unique
    /// and old docs reference it. Do not draw it on keys or the knob.
    var symbol: String {
        switch self {
        case .red:    return "circle.fill"
        case .yellow: return "square.fill"
        case .green:  return "triangle.fill"
        case .blue:   return "diamond.fill"
        case .pink:   return "star.fill"
        case .violet: return "hexagon.fill"
        case .orange: return "pentagon.fill"
        case .cyan:   return "oval.fill"
        }
    }

    func name(spanish: Bool) -> String {
        switch self {
        case .red:    return spanish ? "Rojo" : "Red"
        case .yellow: return spanish ? "Amarillo" : "Yellow"
        case .green:  return spanish ? "Verde" : "Green"
        case .blue:   return spanish ? "Azul" : "Blue"
        case .pink:   return spanish ? "Rosa" : "Pink"
        case .violet: return spanish ? "Violeta" : "Violet"
        case .orange: return spanish ? "Naranja" : "Orange"
        case .cyan:   return spanish ? "Cian" : "Cyan"
        }
    }

    /// sRGB hex (light appearance, dark appearance). LED hues: recognisable,
    /// saturated, none of them a muted grey.
    var hex: (light: UInt32, dark: UInt32) {
        switch self {
        case .red:    return (0xD92B2B, 0xFF4040)
        case .yellow: return (0xE0B800, 0xFFE12E)
        case .green:  return (0x1FA84A, 0x3CE06A)
        case .blue:   return (0x2563EB, 0x4D8BFF)
        case .pink:   return (0xD6459A, 0xFF6EC0)
        case .violet: return (0x7B3FE4, 0xA878FF)
        case .orange: return (0xE86A00, 0xFF9A2E)
        case .cyan:   return (0x0097B8, 0x2AD8F2)
        }
    }

    /// Ink that stays legible on top of the key (numbers, Differentiate mode).
    var prefersDarkInk: Bool { self == .yellow || self == .pink || self == .orange || self == .cyan }

    /// The first `count` colours (count sanitised to 4...8).
    static func palette(count: Int) -> [DecoderColor] {
        Array(allCases.prefix(DecoderRules.clampedColors(count)))
    }
}

// MARK: - Scoring

struct DecoderFeedback: Equatable, Hashable, Sendable {
    let exact: Int
    let misplaced: Int
    var isSolved: Bool { exact == DecoderRules.slots }
}

/// Why a code is not acceptable. Shared by core validation and UI feedback.
enum DecoderRuleViolation: Equatable, Hashable, Sendable {
    case wrongLength(Int)
    case outOfRange(Int)
    case repeatedColor(Int)     // the colour that appears more than once
    case invalidSecret
}

/// Per-key hint of a played row: what the lit lip under each key says.
///  - `exact`:   this colour is in the code AND in this slot (green).
///  - `present`: this colour is in the code, in another slot (white).
///  - `absent`:  this colour is not in the code (off).
enum DecoderSlotHint: Equatable, Hashable, Sendable { case exact, present, absent }

/// Outcome of pressing the HINT button (2026-11-10). Per-key hints are hidden
/// until asked for: one press lights the lips of the LAST submitted row only.
enum DecoderHintResult: Equatable, Sendable {
    case revealed(row: Int)
    case alreadyRevealed(row: Int)
    case noRow          // nothing submitted yet
    case finished       // the game is over: nothing more to reveal
}

enum DecoderRules {
    /// Rules generation. v1 allowed repeated colours; v2 forbids them. Ids and
    /// storage keys carry the version so v1 data is never replayed under v2.
    static let version = 2
    static let slots = 4
    /// The DAILY palette size. Deliberately a literal and NOT
    /// `DecoderColor.allCases.count` (which is 8): the daily game, its seeds,
    /// codes and stored data must not change when the palette grows.
    static let colors = 6
    /// Per-game palette range. Every function below takes a `colors:` argument
    /// that defaults to the daily 6 and is sanitised into this range.
    /// 4 is the floor (Infinite levels 1...10): with 4 colours the code is a
    /// permutation of all four. The DAILY game never goes below/above 6.
    /// Infinite never goes above 6 either (`DecoderInfinite.maxColors`); 7 and 8
    /// stay legal here only so stored rounds of build 865 can be recognised.
    static let minColors = 4
    static let maxColors = 8
    static let maxAttempts = 7
    /// Fewest attempts a game may have (Infinite levels 41+). Daily is always
    /// `maxAttempts`. The board keeps `maxAttempts` rows; unusable ones are off.
    static let minAttempts = 5
    static let colorsMustBeDistinct = true
    /// 6 · 5 · 4 · 3 = 360 (daily)
    static let possibleCodes = DecoderRules.codeCount(colors: 6)

    /// Any integer becomes a legal palette size (4...8: never 0, negative or > 8).
    static func clampedColors(_ n: Int) -> Int { min(max(n, minColors), maxColors) }

    /// Any integer becomes a legal attempt budget (5...7).
    static func clampedAttempts(_ n: Int) -> Int { min(max(n, minAttempts), maxAttempts) }

    /// n · (n-1) · (n-2) · (n-3): 24 / 120 / 360 / 840 / 1680 for 4 / 5 / 6 / 7 / 8 colours.
    static func codeCount(colors n: Int) -> Int {
        let c = clampedColors(n)
        return (0..<slots).reduce(1) { $0 * (c - $1) }
    }

    /// First violation, or nil when the code is a legal 4-of-`colors` arrangement.
    static func violation(_ code: [Int], colors n: Int = DecoderRules.colors) -> DecoderRuleViolation? {
        let c = clampedColors(n)
        guard code.count == slots else { return .wrongLength(code.count) }
        var seen = Set<Int>()
        for value in code {
            guard (0..<c).contains(value) else { return .outOfRange(value) }
            if !seen.insert(value).inserted { return .repeatedColor(value) }
        }
        return nil
    }

    static func isValid(_ code: [Int], colors n: Int = DecoderRules.colors) -> Bool { violation(code, colors: n) == nil }

    /// Exact matches first; leftovers are matched by colour counts. With
    /// distinct codes this reduces to set overlap, but the general form is kept
    /// so the arithmetic stays obviously correct.
    static func score(secret: [Int], guess: [Int], colors n: Int = DecoderRules.colors) -> DecoderFeedback? {
        let c = clampedColors(n)
        guard isValid(secret, colors: c), isValid(guess, colors: c) else { return nil }
        var exact = 0
        var secretLeft = [Int](repeating: 0, count: c)
        var guessLeft = [Int](repeating: 0, count: c)
        for i in 0..<slots {
            if secret[i] == guess[i] { exact += 1 }
            else { secretLeft[secret[i]] += 1; guessLeft[guess[i]] += 1 }
        }
        let misplaced = (0..<c).reduce(0) { $0 + min(secretLeft[$1], guessLeft[$1]) }
        return DecoderFeedback(exact: exact, misplaced: misplaced)
    }

    /// One hint PER SLOT of `guess` (same order as the guess). Pure. nil when
    /// either code is illegal for `colors` (same contract as `score`). Because
    /// colours never repeat, each hint is independent: the number of `.exact`
    /// equals `score().exact` and the number of `.present` equals
    /// `score().misplaced`.
    static func slotHints(secret: [Int], guess: [Int], colors n: Int = DecoderRules.colors) -> [DecoderSlotHint]? {
        let c = clampedColors(n)
        guard isValid(secret, colors: c), isValid(guess, colors: c) else { return nil }
        return (0..<slots).map { i in
            if guess[i] == secret[i] { return .exact }
            return secret.contains(guess[i]) ? .present : .absent
        }
    }

    /// Every legal code, in lexicographic order (24 / 120 / 360 / 840 / 1680).
    static func allCodes(colors n: Int = DecoderRules.colors) -> [[Int]] {
        let c = clampedColors(n)
        var out: [[Int]] = []
        func build(_ prefix: [Int]) {
            if prefix.count == slots { out.append(prefix); return }
            for color in 0..<c where !prefix.contains(color) { build(prefix + [color]) }
        }
        build([])
        return out
    }
}

// MARK: - Game state

enum DecoderStatus: Equatable, Sendable { case playing, won, lost }

enum DecoderSubmitResult: Equatable, Sendable {
    case accepted(DecoderFeedback)
    case invalid(DecoderRuleViolation)   // wrong length, out of range or repeated colour
    case finished       // game already won/lost: immutable
}

struct DecoderGame: Equatable, Sendable {
    static let dailySalt: UInt64 = 283
    /// v2 ids. v1 ("dec-<seed>") belonged to the repeated-colour rules.
    static let idPrefix = "dec2-"

    let id: String
    let secret: [Int]
    /// Palette size of THIS game (4...8). Daily games are always 6.
    let colorCount: Int
    /// Attempt budget of THIS game (5...7). Daily/Práctica are always 7;
    /// Infinite gets fewer at high levels (`DecoderInfinite.maxAttempts(level:)`).
    let maxAttempts: Int
    private(set) var guesses: [[Int]]
    /// Played rows whose per-key hint (the lip) the player has revealed with
    /// the hint button. Always a subset of `guesses.indices`; never shrinks.
    private(set) var revealedHints: Set<Int>

    init(id: String, secret: [Int], guesses: [[Int]] = [], colorCount: Int = DecoderRules.colors,
         maxAttempts: Int = DecoderRules.maxAttempts, revealedHints: [Int] = []) {
        self.id = id
        self.secret = secret
        self.colorCount = DecoderRules.clampedColors(colorCount)
        self.maxAttempts = DecoderRules.clampedAttempts(maxAttempts)
        self.guesses = []
        self.revealedHints = []
        // A secret that breaks the rules (e.g. a v1 code with repeats) yields
        // an inert game: nothing restored, nothing playable.
        guard DecoderRules.isValid(secret, colors: self.colorCount) else { return }
        // Restoring corrupt/overlong data replays only the legal prefix.
        for guess in guesses where status == .playing && DecoderRules.isValid(guess, colors: self.colorCount) {
            self.guesses.append(guess)
        }
        // Stored reveals only count for rows that were actually restored.
        self.revealedHints = Set(revealedHints.filter { self.guesses.indices.contains($0) })
    }

    /// False when the secret itself is illegal; such a game cannot be played.
    var isPlayable: Bool { DecoderRules.isValid(secret, colors: colorCount) }

    var feedbacks: [DecoderFeedback] {
        guesses.compactMap { DecoderRules.score(secret: secret, guess: $0, colors: colorCount) }
    }

    /// Per-key hints, one array per played row (same indices as `guesses`).
    var slotHints: [[DecoderSlotHint]] {
        guesses.compactMap { DecoderRules.slotHints(secret: secret, guess: $0, colors: colorCount) }
    }

    /// Rows with a revealed hint, sorted (property-list form).
    var revealedHintRows: [Int] { revealedHints.sorted() }

    func isHintRevealed(row: Int) -> Bool { revealedHints.contains(row) }

    /// Per-key hint of `row` ONLY if the player revealed it; nil otherwise
    /// (the lip stays off and VoiceOver does not read it).
    func visibleSlotHints(row: Int) -> [DecoderSlotHint]? {
        guard revealedHints.contains(row), guesses.indices.contains(row) else { return nil }
        return DecoderRules.slotHints(secret: secret, guess: guesses[row], colors: colorCount)
    }

    /// Can the hint button do something right now? (a game in progress whose
    /// last submitted row is still hidden)
    var canRevealHint: Bool {
        guard status == .playing, let last = guesses.indices.last else { return false }
        return !revealedHints.contains(last)
    }

    /// The HINT button: lights the lips of the LAST submitted row only. Earlier
    /// hidden rows stay hidden. Idempotent; refused once the game is over.
    @discardableResult
    mutating func revealHint() -> DecoderHintResult {
        guard isPlayable, status == .playing else { return .finished }
        guard let last = guesses.indices.last else { return .noRow }
        if revealedHints.contains(last) { return .alreadyRevealed(row: last) }
        revealedHints.insert(last)
        return .revealed(row: last)
    }

    /// Union with reveals coming from another copy of the SAME game (a reveal
    /// is never undone by merging). Rows that do not exist here are ignored.
    mutating func mergeRevealed(_ rows: Set<Int>) {
        revealedHints.formUnion(rows.filter { guesses.indices.contains($0) })
    }

    var status: DecoderStatus {
        if !isPlayable { return .lost }
        if guesses.last == secret { return .won }
        return guesses.count >= maxAttempts ? .lost : .playing
    }
    var isFinished: Bool { status != .playing }
    var attemptsUsed: Int { guesses.count }
    var attemptsLeft: Int { max(0, maxAttempts - guesses.count) }

    @discardableResult
    mutating func submit(_ guess: [Int]) -> DecoderSubmitResult {
        guard isPlayable else { return .invalid(.invalidSecret) }
        guard status == .playing else { return .finished }
        if let violation = DecoderRules.violation(guess, colors: colorCount) { return .invalid(violation) }
        guard let feedback = DecoderRules.score(secret: secret, guess: guess, colors: colorCount) else { return .invalid(.invalidSecret) }
        guesses.append(guess)
        return .accepted(feedback)
    }

    // MARK: Generation

    /// Pure and deterministic: the same seed gives the same secret everywhere.
    /// Partial Fisher–Yates over the `colors` colours: always 4 different
    /// colours and every legal code is equally likely. With the default 6 the
    /// draw is identical to the original daily generator (frozen vectors).
    static func secret(seed: UInt64, colors: Int = DecoderRules.colors) -> [Int] {
        let n = DecoderRules.clampedColors(colors)
        var rng = DecoderRNG(seed: seed)
        var pool = Array(0..<n)
        for i in 0..<DecoderRules.slots {
            pool.swapAt(i, i + rng.int(pool.count - i))
        }
        return Array(pool.prefix(DecoderRules.slots))
    }

    static func make(seed: UInt64, spanish: Bool) -> DecoderGame {
        DecoderGame(id: (spanish ? "" : "en-") + idPrefix + "\(seed)", secret: secret(seed: seed))
    }

    /// True for ids minted under the current (distinct-colour) rules.
    static func isCurrentID(_ id: String) -> Bool {
        id.hasPrefix(idPrefix) || id.hasPrefix("en-" + idPrefix)
    }

    /// QA fixtures (screenshots / simulator): legal guesses for "mid", "win",
    /// "lose". Pure; never used in normal play. Every row obeys the rules.
    static func fixtureGuesses(_ name: String, secret s: [Int], colors: Int = DecoderRules.colors) -> [[Int]] {
        let n = DecoderRules.clampedColors(colors)
        // A bijection (stays distinct) that is never the identity: the shift is
        // folded into 1...(n-1), so with 4 or 5 colours "lose" cannot contain the
        // secret by accident. With 6+ colours shifts 1...5 are what they always were.
        func shifted(_ d: Int) -> [Int] { let k = 1 + (d - 1) % (n - 1); return s.map { ($0 + k) % n } }
        let swapped = [s[1], s[0], s[2], s[3]]
        switch name {
        case "mid":  return [shifted(1), shifted(2), swapped]
        case "win":  return [shifted(1), swapped, s]
        case "lose": return [shifted(1), shifted(2), shifted(3), shifted(4), shifted(5), swapped, [s[0], s[2], s[1], s[3]]]
        default:     return []
        }
    }

    /// Same recipe as `PuzzleSeed.daily` (day * 131 + salt).
    static func dailySeed(year: Int, month: Int, day: Int) -> UInt64 {
        UInt64(year * 10_000 + month * 100 + day) &* 131 &+ dailySalt
    }
}

/// SplitMix64, independent of the app's SeededGenerator so watchOS needs no
/// puzzle code. The bound rejection keeps the 6-colour draw unbiased.
struct DecoderRNG {
    private var state: UInt64
    init(seed: UInt64) { state = seed == 0 ? 0x9E37_79B9_7F4A_7C15 : seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
    mutating func int(_ upper: Int) -> Int {
        let bound = UInt64(max(1, upper))
        let limit = UInt64.max - UInt64.max % bound
        var value = next()
        while value >= limit { value = next() }
        return Int(value % bound)
    }
}

// MARK: - Wheel maths

/// Detented rotary knob. Positions are UNWRAPPED integers (`k`) so the knob can
/// spin past a full turn; the colour index is `wrap(k, count:)`.
/// Rotation `r` is degrees clockwise; detent i sits at i·(360/count)° from the
/// fixed index mark, so the selected detent is -r/step.
/// Every function takes the game's colour `count` (4...8, default 6 = daily);
/// the count is sanitised, so 0 / negative / huge never divides by zero.
enum DecoderWheel {
    static let detents = DecoderRules.colors
    static let stepDegrees = 360.0 / Double(detents)
    /// Extra travel beyond the half-step before a detent flips, so a finger
    /// resting on a boundary cannot chatter.
    static let hysteresis = 0.12

    static func step(count: Int) -> Double { 360.0 / Double(DecoderRules.clampedColors(count)) }

    static func wrap(_ k: Int, count: Int = DecoderWheel.detents) -> Int {
        let n = DecoderRules.clampedColors(count)
        return ((k % n) + n) % n
    }

    static func rotation(forPosition k: Int, count: Int = DecoderWheel.detents) -> Double { -Double(k) * step(count: count) }

    /// Continuous dial position in detent units for a rotation in degrees.
    static func position(forRotation degrees: Double, count: Int = DecoderWheel.detents) -> Double { -degrees / step(count: count) }

    /// Next unwrapped detent for a continuous position, with hysteresis.
    /// (Independent of the colour count: positions are in detent units.)
    static func resolve(position: Double, current k: Int) -> Int {
        guard position.isFinite, abs(position - Double(k)) < 10_000 else { return k }
        var k = k
        while position > Double(k) + 0.5 + hysteresis { k += 1 }
        while position < Double(k) - 0.5 - hysteresis { k -= 1 }
        return k
    }

    /// Clockwise angle from 12 o'clock in [0, 360).
    static func angle(dx: Double, dy: Double) -> Double {
        let degrees = atan2(dx, -dy) * 180 / .pi
        return degrees < 0 ? degrees + 360 : degrees
    }

    /// Smallest signed change from `a` to `b`, in (-180, 180].
    static func shortestDelta(from a: Double, to b: Double) -> Double {
        var d = (b - a).truncatingRemainder(dividingBy: 360)
        if d > 180 { d -= 360 }
        if d <= -180 { d += 360 }
        return d
    }

    /// Colour index sitting under a screen angle for a dial rotation.
    static func segment(atScreenAngle angle: Double, rotation: Double, count: Int = DecoderWheel.detents) -> Int {
        let raw = ((angle - rotation) / step(count: count)).rounded()
        guard raw.isFinite, abs(raw) < 1e9 else { return 0 }
        return wrap(Int(raw), count: count)
    }

    /// Unwrapped detent for colour `target` nearest to `current` (tap-to-select).
    /// Ties (even counts) go clockwise.
    static func nearest(current k: Int, target: Int, count: Int = DecoderWheel.detents) -> Int {
        let n = DecoderRules.clampedColors(count)
        var diff = wrap(target, count: n) - wrap(k, count: n)   // -(n-1)...(n-1)
        if diff > n / 2 { diff -= n }                           // 6: 4,5 -> -2,-1
        if n % 2 == 0 { if diff <= -(n / 2) { diff += n } }     // 6: -3 -> 3 (tie clockwise)
        else if diff < -(n / 2) { diff += n }                   // 7: -4 -> 3
        return k + diff
    }

    static func next(_ k: Int) -> Int { k + 1 }
    static func previous(_ k: Int) -> Int { k - 1 }
}

/// Minimum spacing between detent clicks. Pure (time injected) so it can be
/// tested; a fast spin yields at most one click per window, never one per frame.
struct DecoderHapticThrottle: Sendable {
    var minInterval: Double = 0.045
    private var last: Double?
    init(minInterval: Double = 0.045) { self.minInterval = minInterval }
    mutating func allow(at now: Double) -> Bool {
        if let last, now - last < minInterval, now >= last { return false }
        last = now
        return true
    }
    mutating func reset() { last = nil }
}

// MARK: - Haptic recipes (pure data; the platforms only PLAY them)

/// Every moment of the game that is felt. Shared by iPhone (CoreHaptics) and
/// Watch (WatchKit native taps) so both speak the same vocabulary.
enum DecoderHapticCue: Equatable, Sendable {
    case detent, place, slot, clear, reject, warning, error, win, loss
    case submit(exact: Int, misplaced: Int)
}

/// One CoreHaptics event. `duration == 0` is a transient (a click); `> 0` is a
/// short continuous body. Values are in 0...1 once sanitised.
struct DecoderHapticEvent: Equatable, Sendable {
    var time: Double
    var intensity: Double
    var sharpness: Double
    var duration: Double = 0
    var isContinuous: Bool { duration > 0 }
    var end: Double { time + duration }
}

/// WatchKit offers only fixed native patterns (no amplitude control), so a Watch
/// recipe is a short list of those patterns with a delay from the start.
enum DecoderWatchTap: Equatable, Sendable { case click, directionUp, directionDown, success, failure, retry, start }
struct DecoderWatchStep: Equatable, Sendable {
    var delay: Double
    var tap: DecoderWatchTap
}

enum DecoderHapticRecipe {
    /// Hard limits, asserted by the harness. No pattern may exceed them.
    static let maxDuration = 1.2          // seconds, whole pattern
    static let maxContinuous = 0.35       // seconds, one continuous body
    static let maxEvents = 12
    static let wheelMinInterval = 0.05    // seconds between detent clicks
    static let watchMaxSteps = 5
    static let watchMinGap = 0.12         // seconds between two native Watch taps

    private static func tr(_ time: Double, _ i: Double, _ s: Double) -> DecoderHapticEvent {
        DecoderHapticEvent(time: time, intensity: i, sharpness: s, duration: 0)
    }
    private static func body(_ time: Double, _ i: Double, _ s: Double, _ d: Double) -> DecoderHapticEvent {
        DecoderHapticEvent(time: time, intensity: i, sharpness: s, duration: d)
    }

    /// Clamps to the hard limits and drops anything non-finite. Idempotent.
    static func sanitize(_ events: [DecoderHapticEvent]) -> [DecoderHapticEvent] {
        var out: [DecoderHapticEvent] = []
        for e in events {
            guard e.time.isFinite, e.intensity.isFinite, e.sharpness.isFinite, e.duration.isFinite else { continue }
            let time = max(0, e.time)
            guard time < maxDuration else { continue }
            let duration = min(max(0, e.duration), maxContinuous, maxDuration - time)
            out.append(DecoderHapticEvent(time: time, intensity: min(max(e.intensity, 0), 1),
                                          sharpness: min(max(e.sharpness, 0), 1), duration: duration))
        }
        out.sort { $0.time < $1.time }
        return Array(out.prefix(maxEvents))
    }

    static func events(for cue: DecoderHapticCue) -> [DecoderHapticEvent] { sanitize(raw(cue)) }

    private static func raw(_ cue: DecoderHapticCue) -> [DecoderHapticEvent] {
        switch cue {
        case .detent:     // hard mechanical tick
            return [tr(0, 0.9, 1.0), body(0, 0.55, 0.7, 0.012)]
        case .place:      // firm knock + settle
            return [tr(0, 1.0, 0.8), body(0, 0.75, 0.3, 0.06), tr(0.075, 0.6, 0.5)]
        case .slot:       // lighter than place
            return [tr(0, 0.8, 0.7), body(0, 0.4, 0.4, 0.025)]
        case .clear:      // dull scrape down
            return [tr(0, 0.9, 0.3), tr(0.055, 0.6, 0.2), body(0.055, 0.4, 0.1, 0.05)]
        case .reject:     // double hard knock + short buzz
            return [tr(0, 1.0, 1.0), tr(0.075, 1.0, 1.0), body(0.15, 0.85, 0.2, 0.13)]
        case .warning:    // three stepped-down taps
            return [tr(0, 1.0, 0.7), tr(0.09, 0.75, 0.6), tr(0.18, 0.5, 0.5)]
        case .error:
            return [body(0, 1.0, 0.3, 0.14), tr(0.2, 1.0, 1.0)]
        case .submit(let exact, let misplaced):
            let e = min(max(exact, 0), DecoderRules.slots)
            let m = min(max(misplaced, 0), DecoderRules.slots - e)
            var ev = [body(0, 0.8, 0.4, 0.05), tr(0, 1.0, 0.8)]       // the key press
            var time = 0.16
            if e + m == 0 { ev.append(body(time, 0.45, 0.1, 0.09)) }  // nothing matched: one dull thud
            for _ in 0..<e { ev.append(tr(time, 1.0, 0.95)); ev.append(body(time, 0.7, 0.4, 0.03)); time += 0.085 }
            for _ in 0..<m { ev.append(tr(time, 0.55, 0.2)); time += 0.085 }
            return ev
        case .win:        // rising run, then a bright held swell
            return [body(0, 0.6, 0.2, 0.08),
                    tr(0, 0.5, 0.3), tr(0.09, 0.65, 0.45), tr(0.18, 0.8, 0.6), tr(0.27, 0.9, 0.75), tr(0.36, 1.0, 0.9),
                    body(0.45, 0.9, 0.5, 0.3)]
        case .loss:       // heavy thud, low rumble, two falling taps
            return [body(0, 1.0, 0.15, 0.3), tr(0, 1.0, 1.0),
                    tr(0.38, 0.8, 0.3), tr(0.6, 0.6, 0.1), body(0.6, 0.5, 0.1, 0.15)]
        }
    }

    /// Native Watch sequence (fixed WatchKit patterns, delays in seconds).
    static func watchSteps(for cue: DecoderHapticCue) -> [DecoderWatchStep] {
        func s(_ d: Double, _ t: DecoderWatchTap) -> DecoderWatchStep { DecoderWatchStep(delay: d, tap: t) }
        let steps: [DecoderWatchStep]
        switch cue {
        case .detent, .slot: steps = [s(0, .click)]
        case .place:         steps = [s(0, .directionUp), s(0.15, .click)]
        case .clear:         steps = [s(0, .directionDown), s(0.16, .click)]
        case .reject:        steps = [s(0, .failure), s(0.4, .retry)]
        case .warning:       steps = [s(0, .retry)]
        case .error:         steps = [s(0, .failure)]
        case .submit(let exact, let misplaced):
            let e = min(max(exact, 0), DecoderRules.slots)
            let m = min(max(misplaced, 0), DecoderRules.slots - e)
            var out = [s(0, .start)]
            if e + m == 0 { out.append(s(0.3, .directionDown)) }
            if e > 0 { out.append(s(0.3, .directionUp)) }
            if m > 0 { out.append(s(e > 0 ? 0.55 : 0.3, .click)) }
            steps = out
        case .win:           steps = [s(0, .success), s(0.4, .directionUp), s(0.7, .directionUp)]
        case .loss:          steps = [s(0, .failure), s(0.45, .directionDown), s(0.75, .directionDown)]
        }
        return Array(steps.prefix(watchMaxSteps))
    }
}

// MARK: - Entry editing (pure, shared by iPhone and Watch)

/// Outcome of trying to put a colour in the selected slot. The UI maps each
/// case to visual, spoken and haptic feedback; nothing is ever placed twice.
enum DecoderPlaceResult: Equatable, Sendable {
    case placed(slot: Int)
    case unchanged(slot: Int)                 // same colour already in this very slot
    case duplicate(color: Int, heldBy: Int)   // rejected: colour already sits in slot `heldBy`
    case invalid                              // colour index outside 0..<colorCount
}

/// The row being composed. Slots are optional until filled. INVARIANT: the
/// filled slots always hold different colours (enforced here, not in the UI).
struct DecoderDraft: Equatable, Sendable {
    private(set) var slots: [Int?] = Array(repeating: nil, count: DecoderRules.slots)
    private(set) var selected = 0
    /// Palette size of the game this row belongs to (4...8, default 6).
    let colorCount: Int

    init(colorCount: Int = DecoderRules.colors) {
        self.colorCount = DecoderRules.clampedColors(colorCount)
    }

    /// Rebuilds a stored row THROUGH `place`, so a corrupt payload can never
    /// produce a repeated or out-of-range colour. `stored` uses -1 for empty.
    init(restoring stored: [Int], selected: Int, colorCount: Int) {
        self.init(colorCount: colorCount)
        for (index, value) in stored.prefix(DecoderRules.slots).enumerated() where value >= 0 {
            select(index)
            _ = place(value)
        }
        select(selected)
    }

    /// Plain-integer form for property lists: -1 = empty slot.
    var rawSlots: [Int] { slots.map { $0 ?? -1 } }

    var isComplete: Bool { slots.allSatisfy { $0 != nil } }
    var code: [Int]? {
        guard isComplete else { return nil }
        let code = slots.compactMap { $0 }
        return DecoderRules.isValid(code, colors: colorCount) ? code : nil
    }
    var usedColors: Set<Int> { Set(slots.compactMap { $0 }) }
    var filledCount: Int { slots.compactMap { $0 }.count }

    /// Slot (other than the selected one) already holding `color`.
    func holder(of color: Int) -> Int? {
        slots.indices.first { $0 != selected && slots[$0] == color }
    }
    /// Can `color` go into the selected slot right now?
    func canPlace(_ color: Int) -> Bool {
        (0..<colorCount).contains(color) && holder(of: color) == nil
    }

    mutating func select(_ slot: Int) {
        guard (0..<DecoderRules.slots).contains(slot) else { return }
        selected = slot
    }

    /// Writes into the selected slot and moves to the next EMPTY slot (if any).
    /// A colour already used in ANOTHER slot is rejected and nothing changes.
    @discardableResult
    mutating func place(_ color: Int) -> DecoderPlaceResult {
        guard (0..<colorCount).contains(color) else { return .invalid }
        if let other = holder(of: color) { return .duplicate(color: color, heldBy: other) }
        if slots[selected] == color { return .unchanged(slot: selected) }
        let target = selected
        slots[target] = color
        for offset in 1...DecoderRules.slots {
            let candidate = (selected + offset) % DecoderRules.slots
            if slots[candidate] == nil { selected = candidate; break }
        }
        return .placed(slot: target)
    }

    mutating func clearSelected() { slots[selected] = nil }
    mutating func reset() { self = DecoderDraft(colorCount: colorCount) }
}

// MARK: - Persistence

/// Sessions (guesses per game id) and write-once results. Property-list only,
/// so it works in any UserDefaults suite. Results are recorded exactly once per
/// id: restarting or reopening a finished game cannot farm wins or losses.
struct DecoderStore {
    /// v2 = distinct-colour rules. A NEW key space: v1 data (which may contain
    /// repeated colours) is never read, merged, rewritten or counted in stats.
    static let sessionsKey = "newsraider.decoder.sessions.v2"
    static let orderKey = "newsraider.decoder.order.v2"
    static let resultsKey = "newsraider.decoder.results.v2"
    /// id -> rows whose per-key hint was revealed (2026-11-10). A SEPARATE key so
    /// the sessions blob keeps its exact v2 shape; missing = nothing revealed.
    static let hintsKey = "newsraider.decoder.hints.v2"
    /// Left untouched on disk by every operation except `wipeAll` (the explicit
    /// "reset all progress" action).
    static let legacyV1Keys = ["newsraider.decoder.sessions.v1",
                               "newsraider.decoder.order.v1",
                               "newsraider.decoder.results.v1"]
    static let keepSessions = 60

    let defaults: UserDefaults
    init(defaults: UserDefaults) { self.defaults = defaults }

    private var sessions: [String: [[Int]]] {
        defaults.dictionary(forKey: Self.sessionsKey) as? [String: [[Int]]] ?? [:]
    }

    func guesses(for id: String) -> [[Int]] { sessions[id] ?? [] }

    private var hints: [String: [Int]] {
        defaults.dictionary(forKey: Self.hintsKey) as? [String: [Int]] ?? [:]
    }

    /// Rows with a revealed hint for `id` (empty when never stored).
    func revealedHints(for id: String) -> [Int] { hints[id] ?? [] }

    func save(_ game: DecoderGame) {
        var all = sessions
        all[game.id] = game.guesses
        var revealed = hints
        // Union with what is stored: a reveal is never undone by a save.
        let rows = Set(revealed[game.id] ?? []).union(game.revealedHintRows).sorted()
        if rows.isEmpty { revealed.removeValue(forKey: game.id) } else { revealed[game.id] = rows }
        var order = defaults.stringArray(forKey: Self.orderKey) ?? []
        order.removeAll { $0 == game.id }
        order.append(game.id)
        while order.count > Self.keepSessions {
            let dropped = order.removeFirst()
            all.removeValue(forKey: dropped)
            revealed.removeValue(forKey: dropped)
        }
        defaults.set(all, forKey: Self.sessionsKey)
        defaults.set(order, forKey: Self.orderKey)
        // Only touch the hints key once something was ever revealed.
        if !revealed.isEmpty || defaults.object(forKey: Self.hintsKey) != nil {
            defaults.set(revealed, forKey: Self.hintsKey)
        }
    }

    /// Clears the board of one game ("start over"). Results are NOT touched.
    func clear(id: String) {
        var all = sessions
        all.removeValue(forKey: id)
        defaults.set(all, forKey: Self.sessionsKey)
        if var revealed = defaults.dictionary(forKey: Self.hintsKey) as? [String: [Int]], revealed[id] != nil {
            revealed.removeValue(forKey: id)
            defaults.set(revealed, forKey: Self.hintsKey)
        }
        defaults.set((defaults.stringArray(forKey: Self.orderKey) ?? []).filter { $0 != id },
                     forKey: Self.orderKey)
    }

    /// True when rules-v1 data is still sitting on disk (kept, never used).
    var hasLegacyV1Data: Bool { Self.legacyV1Keys.contains { defaults.object(forKey: $0) != nil } }

    /// Explicit user action ("reset all progress"): clears v2 AND the dormant
    /// v1 keys so no incompatible leftovers survive a full reset.
    func wipeAll() {
        for key in [Self.sessionsKey, Self.orderKey, Self.resultsKey, Self.hintsKey] + Self.legacyV1Keys {
            defaults.removeObject(forKey: key)
        }
    }

    /// Restores a game. Only v2 ids are restored, and the game re-validates
    /// every stored guess against the rules (illegal rows are dropped).
    func load(id: String, secret: [Int]) -> DecoderGame {
        guard DecoderGame.isCurrentID(id) else { return DecoderGame(id: id, secret: secret) }
        return DecoderGame(id: id, secret: secret, guesses: guesses(for: id), revealedHints: revealedHints(for: id))
    }

    // Results: id -> attempts used when won (1...7), 0 when lost.
    private var results: [String: Int] {
        defaults.dictionary(forKey: Self.resultsKey) as? [String: Int] ?? [:]
    }

    /// Returns true only the first time a terminal state is recorded for `id`.
    @discardableResult
    func recordResultIfNew(_ game: DecoderGame) -> Bool {
        guard game.isPlayable, game.isFinished, DecoderGame.isCurrentID(game.id), results[game.id] == nil else { return false }
        var all = results
        all[game.id] = game.status == .won ? game.attemptsUsed : 0
        defaults.set(all, forKey: Self.resultsKey)
        return true
    }

    struct Stats: Equatable {
        var played = 0, wins = 0, losses = 0
        var distribution = [Int](repeating: 0, count: DecoderRules.maxAttempts)
    }

    var stats: Stats {
        var s = Stats()
        for value in results.values {
            s.played += 1
            if value == 0 { s.losses += 1 }
            else if (1...DecoderRules.maxAttempts).contains(value) {
                s.wins += 1
                s.distribution[value - 1] += 1
            }
        }
        return s
    }
}

// MARK: - Infinite mode (independent of the daily game)

/// Infinite: an endless ladder of levels with its OWN rules of progression,
/// ids (`decinf-…`) and storage key. It never touches `DecoderStore` keys,
/// `PuzzleProgress`, streaks, timings or daily stats.
///
///  - Colours (2026-11-10, Josu): a new colour every 10 levels, at most 6:
///    1...10 use 4 colours, 11...20 use 5, 21 and beyond use 6.
///  - Attempts: once the palette is full the difficulty keeps rising with
///    fewer attempts: 1...30 have 7, 31...40 have 6, 41 and beyond have 5.
///  - One level per win. A loss never lowers or resets anything; the player
///    may replay with a NEW code. Same 4 slots, no timer.
///  - `best` = the highest level UNLOCKED. It never goes down. Any level in
///    1...best can be started; winning a lower level again does not raise
///    `best`, and winning `best` raises it by exactly one.
///  - Levels saturate at `maxLevel` instead of overflowing.
enum DecoderInfinite {
    static let idPrefix = "decinf-"
    /// Every Int constant here must fit Int32: KaffaWatch also builds for
    /// arm64_32, where Int is 32-bit.
    static let maxLevel = 1_000_000_000
    static let maxSerial = 1_000_000_000
    static let maxElapsed = 100 * 3600
    /// Levels per colour tier: one more colour every `tierSize` levels...
    static let tierSize = 10
    /// ...up to this many colours (never 7 or 8 in Infinite).
    static let maxColors = 6
    /// Attempts by level: 1...attemptsTier1Last -> 7, ...attemptsTier2Last -> 6, beyond -> 5.
    static let attemptsTier1Last = 30
    static let attemptsTier2Last = 40
    /// Tiers of the first release (blobs without a "colors" field).
    static let legacyTier1Last = 15
    static let legacyTier2Last = 30

    static func clampLevel(_ level: Int) -> Int { min(max(level, 1), maxLevel) }

    /// 1–10 → 4, 11–20 → 5, 21+ → 6 (never more than `maxColors`).
    static func colorCount(level: Int) -> Int {
        let l = clampLevel(level)
        return min(DecoderRules.minColors + (l - 1) / tierSize, maxColors)
    }

    /// 1–30 → 7, 31–40 → 6, 41+ → 5. Pure; levels are clamped first.
    static func maxAttempts(level: Int) -> Int {
        let l = clampLevel(level)
        if l <= attemptsTier1Last { return DecoderRules.maxAttempts }
        if l <= attemptsTier2Last { return DecoderRules.maxAttempts - 1 }
        return DecoderRules.minAttempts
    }

    /// The tiers shipped in build 865 (1–20 → 4, 21–40 → 5, 41–60 → 6, 61–80 → 7,
    /// 81+ → 8). Documentation/tests only: stored rounds carry their palette in
    /// the "colors" field, so recognising them needs no formula.
    static func previousColorCount(level: Int) -> Int {
        let l = clampLevel(level)
        return min(DecoderRules.minColors + (l - 1) / 20, DecoderRules.maxColors)
    }

    /// What the FIRST release dealt (1–15 → 6, 16–30 → 7, 31+ → 8). Only used to
    /// recognise stored rounds that predate the current tiers.
    static func legacyColorCount(level: Int) -> Int {
        let l = clampLevel(level)
        if l <= legacyTier1Last { return 6 }
        if l <= legacyTier2Last { return 7 }
        return 8
    }

    /// A level the selector may show: always inside 1...best.
    static func clampPick(_ level: Int, best: Int) -> Int { min(max(level, 1), clampLevel(best)) }

    /// Level after a win. Saturates; never overflows.
    static func nextLevel(_ level: Int) -> Int {
        let l = clampLevel(level)
        return l >= maxLevel ? maxLevel : l + 1
    }

    static func nextSerial(_ serial: Int) -> Int {
        let s = min(max(serial, 0), maxSerial)
        return s >= maxSerial ? 1 : s + 1
    }

    static func gameID(level: Int, serial: Int) -> String { "\(idPrefix)\(clampLevel(level))-\(serial)" }
    static func isInfiniteID(_ id: String) -> Bool { id.hasPrefix(idPrefix) }
}

/// One round of Infinite: the game plus everything needed to reopen it exactly
/// where the player left it (row being composed, selected slot, knob, time).
struct DecoderInfiniteRound: Equatable, Sendable {
    let level: Int
    let serial: Int
    let seed: UInt64
    var game: DecoderGame
    var draft: DecoderDraft
    var wheel: Int
    var elapsed: Int
    /// True once the round was WON and the level already advanced.
    var isCleared: Bool

    var id: String { game.id }

    /// No game in progress: the round is over (won or lost) or was never begun
    /// (no attempts and an empty row). Only then may another level be started.
    var isIdle: Bool {
        isCleared || game.isFinished || (game.guesses.isEmpty && draft.filledCount == 0)
    }

    static func fresh(level: Int, serial: Int, seed: UInt64) -> DecoderInfiniteRound {
        let lv = DecoderInfinite.clampLevel(level)
        let n = DecoderInfinite.colorCount(level: lv)
        let game = DecoderGame(id: DecoderInfinite.gameID(level: lv, serial: serial),
                               secret: DecoderGame.secret(seed: seed, colors: n), colorCount: n,
                               maxAttempts: DecoderInfinite.maxAttempts(level: lv))
        return DecoderInfiniteRound(level: lv, serial: serial, seed: seed, game: game,
                                    draft: DecoderDraft(colorCount: n), wheel: 0, elapsed: 0, isCleared: false)
    }
}

/// `level` = the level PROPOSED next: `round.level` while the round is being
/// played or was lost, `round.level + 1` once it is cleared (so closing right
/// after a win loses nothing). `best` = highest level unlocked (>= `level`).
struct DecoderInfiniteSession: Equatable, Sendable {
    let level: Int
    let best: Int
    let round: DecoderInfiniteRound
}

enum DecoderInfiniteSaveOutcome: Equatable, Sendable {
    case saved      // progress stored
    case cleared    // the round was won: level advanced, atomically, exactly once
    case stale      // the caller's round is not the stored one (or is behind it): nothing written
}

/// ONE property-list blob under ONE key, written in a single `set`, so level,
/// best level and active round can never disagree. Every write goes through a
/// guard on the expected round id: a stale view (old round, or a round already
/// won) cannot overwrite a newer state, and `best` can only grow by exactly one
/// per win of the best level. Secrets are never trusted from the caller: they
/// are recomputed from the stored seed, and guesses/draft are revalidated.
///
/// MIGRATION (same key, blob "v" 1 -> 2):
///  - `best` missing -> best = stored level (the old "level" WAS the best).
///  - `colors` missing -> the round was dealt with the first release's tiers.
///    If that palette differs from the current tier of its level, the round is
///    dropped and a NEW code is dealt at the SAME stored level. Level and best
///    are never lowered by a migration or by a damaged round. (2026-11-10: the
///    same rule re-deals build-865 rounds whose tier of 20 no longer matches the
///    new tiers of 10.)
///  - `attempts` missing -> the round was dealt when every level had 7: it
///    KEEPS 7 (nobody loses a round in progress to the new budget) and is
///    re-saved with "attempts": 7. Any other value than 7 or its level's
///    budget (edited) -> re-dealt like `colors`.
///  - `hints` missing -> no per-key hint revealed (all lips off).
struct DecoderInfiniteStore {
    static let key = "newsraider.decoder.infinite.v1"

    let defaults: UserDefaults
    init(defaults: UserDefaults) { self.defaults = defaults }

    static func randomSeed() -> UInt64 { UInt64.random(in: 1...UInt64.max) }

    // MARK: Read

    private struct Stored {
        var level: Int
        var best: Int
        var serial: Int
        var round: DecoderInfiniteRound?
    }

    private func read() -> Stored? {
        guard let d = defaults.dictionary(forKey: Self.key) else { return nil }
        let rawLevel = d["level"] as? Int
        let rawBest = d["best"] as? Int
        // Either number is enough to keep the progress; with neither the blob is unusable.
        guard let anchor = rawLevel ?? rawBest else { return nil }
        let level = DecoderInfinite.clampLevel(anchor)
        // v1 blobs have no "best": the level was the best. A best below the
        // level (edited / damaged) is lifted to the level: it never goes down.
        let best = max(level, DecoderInfinite.clampLevel(rawBest ?? anchor))
        let serial = min(max(d["serial"] as? Int ?? 0, 0), DecoderInfinite.maxSerial)
        return Stored(level: level, best: best, serial: serial, round: parseRound(d, level: level, serial: serial))
    }

    private func parseRound(_ d: [String: Any], level: Int, serial: Int) -> DecoderInfiniteRound? {
        guard serial >= 1,
              let rawRoundLevel = d["roundLevel"] as? Int,
              let seedText = d["seed"] as? String,
              let seed = UInt64(seedText) else { return nil }
        let roundLevel = DecoderInfinite.clampLevel(rawRoundLevel)
        let cleared = d["cleared"] as? Bool ?? false
        // Consistency between the two halves of the blob.
        if cleared { guard DecoderInfinite.nextLevel(roundLevel) == level else { return nil } }
        else { guard roundLevel == level else { return nil } }
        let n = DecoderInfinite.colorCount(level: roundLevel)
        // The palette this round was dealt with. If it is not the palette its
        // level uses today, the stored board no longer validates: drop the round
        // (load() deals a new code at the same stored level).
        let dealt = d["colors"] as? Int ?? DecoderInfinite.legacyColorCount(level: roundLevel)
        guard dealt == n else { return nil }
        let budget: Int
        if let stored = d["attempts"] as? Int {
            // The level's budget, or the legacy 7 of a round dealt before
            // budgets existed (once re-saved it carries "attempts": 7).
            guard stored == DecoderInfinite.maxAttempts(level: roundLevel) || stored == DecoderRules.maxAttempts else { return nil }
            budget = stored
        } else {
            budget = DecoderRules.maxAttempts      // dealt before budgets existed: keeps 7
        }
        var round = DecoderInfiniteRound.fresh(level: roundLevel, serial: serial, seed: seed)
        round.game = DecoderGame(id: round.game.id, secret: round.game.secret,
                                 guesses: d["guesses"] as? [[Int]] ?? [], colorCount: n,
                                 maxAttempts: budget, revealedHints: d["hints"] as? [Int] ?? [])
        if cleared && round.game.status != .won { return nil }
        // A won round that was never marked cleared cannot come from this store
        // (a win is written together with `cleared`): discard it instead of
        // guessing, so edited data can never mint a level.
        if !cleared && round.game.status == .won { return nil }
        round.isCleared = cleared
        round.draft = round.game.isFinished
            ? DecoderDraft(colorCount: n)
            : DecoderDraft(restoring: d["draft"] as? [Int] ?? [], selected: d["selected"] as? Int ?? 0, colorCount: n)
        round.wheel = DecoderWheel.wrap(d["wheel"] as? Int ?? 0, count: n)
        round.elapsed = min(max(d["elapsed"] as? Int ?? 0, 0), DecoderInfinite.maxElapsed)
        return round
    }

    private func write(level: Int, best: Int, round: DecoderInfiniteRound) {
        let blob: [String: Any] = [
            "v": 2,
            "level": level,
            "best": max(DecoderInfinite.clampLevel(best), level),
            "serial": round.serial,
            "roundLevel": round.level,
            "colors": round.game.colorCount,
            "attempts": round.game.maxAttempts,
            "hints": round.game.revealedHintRows,
            "seed": String(round.seed),
            "guesses": round.game.guesses,
            "draft": round.draft.rawSlots,
            "selected": round.draft.selected,
            "wheel": round.wheel,
            "elapsed": round.elapsed,
            "cleared": round.isCleared
        ]
        defaults.set(blob, forKey: Self.key)
    }

    /// A seed whose code differs from `avoiding` (a retry must be a NEW code).
    private func pickSeed(from provider: () -> UInt64, level: Int, avoiding old: [Int]?) -> UInt64 {
        var seed = provider()
        guard let old else { return seed }
        let n = DecoderInfinite.colorCount(level: level)
        var tries = 0
        while DecoderGame.secret(seed: seed, colors: n) == old && tries < 64 { seed = seed &+ 1; tries += 1 }
        return seed
    }

    // MARK: Operations

    /// Current state. Creates (and stores) a first round at level 1 when there
    /// is nothing usable; keeps the stored LEVEL and BEST when only the round is
    /// damaged or was dealt with another palette (new code, same level).
    func load(newSeed: () -> UInt64 = DecoderInfiniteStore.randomSeed) -> DecoderInfiniteSession {
        let stored = read()
        if let stored, let round = stored.round {
            return DecoderInfiniteSession(level: stored.level, best: stored.best, round: round)
        }
        let level = stored?.level ?? 1
        let best = max(stored?.best ?? 1, level)
        let serial = DecoderInfinite.nextSerial(stored?.serial ?? 0)
        let round = DecoderInfiniteRound.fresh(level: level, serial: serial, seed: newSeed())
        write(level: level, best: best, round: round)
        return DecoderInfiniteSession(level: level, best: best, round: round)
    }

    /// Stores progress of `incoming` if (and only if) it is the stored round,
    /// not cleared, not finished, and not behind. A winning save advances the
    /// level and marks the round cleared in the SAME write (idempotent: a second
    /// save of the same round is `.stale`).
    @discardableResult
    func save(_ incoming: DecoderInfiniteRound,
              newSeed: () -> UInt64 = DecoderInfiniteStore.randomSeed) -> (outcome: DecoderInfiniteSaveOutcome, session: DecoderInfiniteSession) {
        let session = load(newSeed: newSeed)
        var stored = session.round
        guard stored.id == incoming.id, stored.seed == incoming.seed,
              !stored.isCleared, !stored.game.isFinished else { return (.stale, session) }
        let n = stored.game.colorCount
        // The secret comes from the STORED seed, never from the caller.
        // Budget from the STORED round too; reveals are a union (never undone).
        var merged = DecoderGame(id: stored.id, secret: stored.game.secret,
                                 guesses: incoming.game.guesses, colorCount: n,
                                 maxAttempts: stored.game.maxAttempts, revealedHints: incoming.game.revealedHintRows)
        merged.mergeRevealed(Set(stored.game.revealedHintRows))
        let before = stored.game.guesses
        guard merged.guesses.count >= before.count,
              Array(merged.guesses.prefix(before.count)) == before else { return (.stale, session) }
        stored.game = merged
        stored.draft = merged.isFinished
            ? DecoderDraft(colorCount: n)
            : DecoderDraft(restoring: incoming.draft.rawSlots, selected: incoming.draft.selected, colorCount: n)
        stored.wheel = DecoderWheel.wrap(incoming.wheel, count: n)
        stored.elapsed = min(max(max(incoming.elapsed, stored.elapsed), 0), DecoderInfinite.maxElapsed)
        var level = session.level
        var best = session.best
        var outcome = DecoderInfiniteSaveOutcome.saved
        if merged.status == .won {
            stored.isCleared = true
            // The proposal moves to the level after the one just won. `best`
            // only moves when that is beyond it: re-winning a lower level
            // changes nothing (no farming), winning `best` adds exactly one.
            level = DecoderInfinite.nextLevel(stored.level)
            best = max(best, level)
            outcome = .cleared
        }
        write(level: level, best: best, round: stored)
        return (outcome, DecoderInfiniteSession(level: level, best: best, round: stored))
    }

    /// Deals a fresh round and stores it; `best` is carried over untouched.
    private func deal(level: Int, after session: DecoderInfiniteSession,
                      newSeed: () -> UInt64) -> DecoderInfiniteSession {
        let old = session.round.game
        // A replay must be a NEW code (only comparable when the palette is the same).
        let avoid = DecoderInfinite.colorCount(level: level) == old.colorCount ? old.secret : nil
        let seed = pickSeed(from: newSeed, level: level, avoiding: avoid)
        let round = DecoderInfiniteRound.fresh(level: level,
                                               serial: DecoderInfinite.nextSerial(session.round.serial), seed: seed)
        write(level: level, best: session.best, round: round)
        return DecoderInfiniteSession(level: level, best: session.best, round: round)
    }

    /// LEVEL SELECTOR: starts `level` with a new code. Only when
    ///  - the caller is looking at the stored round (`expectedID`),
    ///  - no game is in progress (`isIdle`: finished, or never begun), and
    ///  - `level` is inside 1...best (a locked level is refused, not clamped).
    /// Never changes `best`.
    func start(level: Int, expectedID: String,
               newSeed: () -> UInt64 = DecoderInfiniteStore.randomSeed) -> DecoderInfiniteSession? {
        let session = load(newSeed: newSeed)
        guard session.round.id == expectedID, session.round.isIdle,
              level >= 1, level <= session.best else { return nil }
        return deal(level: level, after: session, newSeed: newSeed)
    }

    /// After a LOSS: a new code at the SAME level. Only valid for the stored,
    /// lost round (so it cannot be used to re-roll a round in progress).
    func retry(expectedID: String,
               newSeed: () -> UInt64 = DecoderInfiniteStore.randomSeed) -> DecoderInfiniteSession? {
        let session = load(newSeed: newSeed)
        guard session.round.id == expectedID, session.round.game.status == .lost else { return nil }
        return deal(level: session.level, after: session, newSeed: newSeed)
    }

    /// After a WIN: start the round of the (already advanced) level.
    func advance(expectedID: String,
                 newSeed: () -> UInt64 = DecoderInfiniteStore.randomSeed) -> DecoderInfiniteSession? {
        let session = load(newSeed: newSeed)
        guard session.round.id == expectedID, session.round.isCleared else { return nil }
        return deal(level: session.level, after: session, newSeed: newSeed)
    }
}

// MARK: - Numeric device readout

/// Three digits minimum, never truncate a real Infinite level (e.g. 1000).
enum DecoderCounter {
    static func digits(_ value: Int) -> [Int] {
        let digits = String(max(value, 0)).compactMap { $0.wholeNumberValue }
        return Array(repeating: 0, count: max(0, 3 - digits.count)) + digits
    }
}

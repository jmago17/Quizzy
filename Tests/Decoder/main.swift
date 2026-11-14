// Executable checks for Shared/Games/DecoderCore.swift (pure Foundation).
import Foundation

nonisolated(unsafe) var failures = 0
nonisolated(unsafe) var checks = 0
func check(_ ok: @autoclosure () -> Bool, _ name: String, line: Int = #line) {
    checks += 1
    if !ok() { failures += 1; print("FAIL [\(line)] \(name)") }
}

@main struct Runner {
    static func main() {
        // --- Rules v2: 4 DISTINCT colours of 6 ---
        check(DecoderRules.version == 2 && DecoderRules.colorsMustBeDistinct && DecoderRules.possibleCodes == 360, "rules v2 constants")
        check(DecoderRules.maxAttempts == 7 && DecoderRules.slots == 4 && DecoderRules.colors == 6, "constants")
        let codes = DecoderRules.allCodes()
        check(codes.count == 360 && Set(codes).count == 360 && codes.allSatisfy { DecoderRules.isValid($0) }, "allCodes = 360 unique legal codes")

        // --- Validation: exhaustive over every 4-slot arrangement of -1...6 ---
        var legal = 0, illegalRepeat = 0, illegalRange = 0, mismatch = 0
        for a in -1...6 { for b in -1...6 { for c in -1...6 { for d in -1...6 {
            let code = [a, b, c, d]
            let v = DecoderRules.violation(code)
            let inRange = code.allSatisfy { (0..<6).contains($0) }
            let distinct = Set(code).count == 4
            if v == nil { legal += 1; if !(inRange && distinct) { mismatch += 1 } }
            else if case .outOfRange = v! { illegalRange += 1; if inRange { mismatch += 1 } }
            else if case .repeatedColor(let r) = v! { illegalRepeat += 1; if code.filter({ $0 == r }).count < 2 { mismatch += 1 } }   // repeat may precede an out-of-range value
            else { mismatch += 1 }
        } } } }
        check(legal == 360 && mismatch == 0 && illegalRepeat > 0 && illegalRange > 0, "validation exhaustive: exactly 360 legal of 8^4 (legal=\(legal) mismatch=\(mismatch))")
        check(DecoderRules.violation([0,1,2]) == .wrongLength(3) && DecoderRules.violation([0,1,2,3,4]) == .wrongLength(5) && DecoderRules.violation([]) == .wrongLength(0), "wrong length")
        check(DecoderRules.violation([0,1,2,6]) == .outOfRange(6) && DecoderRules.violation([0,1,2,-1]) == .outOfRange(-1), "out of range")
        check(DecoderRules.violation([2,2,0,1]) == .repeatedColor(2) && DecoderRules.violation([0,1,2,0]) == .repeatedColor(0), "repeat detected")
        check(!DecoderRules.isValid([5,5,5,5]) && !DecoderRules.isValid([0,0,1,1]) && DecoderRules.isValid([5,4,3,2]), "isValid")

        // --- Scoring (hand-verified, distinct codes) ---
        func fb(_ s: [Int], _ g: [Int]) -> DecoderFeedback? { DecoderRules.score(secret: s, guess: g) }
                check(fb([0,1,2,3],[0,1,2,3]) == DecoderFeedback(exact: 4, misplaced: 0), "all exact")
        check(fb([0,1,2,3],[3,2,1,0]) == DecoderFeedback(exact: 0, misplaced: 4), "all misplaced")
        check(fb([0,1,2,3],[4,5,3,2]) == DecoderFeedback(exact: 0, misplaced: 2), "2 misplaced, 2 absent")
        check(fb([0,1,2,3],[4,5,0,1]) == DecoderFeedback(exact: 0, misplaced: 2), "two present elsewhere")
        check(fb([0,1,2,3],[0,1,5,4]) == DecoderFeedback(exact: 2, misplaced: 0), "two exact")
        check(fb([0,1,2,3],[0,1,3,2]) == DecoderFeedback(exact: 2, misplaced: 2), "2 exact 2 swapped")
        check(fb([0,1,2,3],[0,4,5,1]) == DecoderFeedback(exact: 1, misplaced: 1), "1 exact 1 misplaced")
        check(fb([0,1,2,3],[4,5,0,1]) != nil && fb([0,1,2,3],[0,0,1,1]) == nil, "guess with repeats is rejected by scoring")
        check(fb([0,0,1,2],[0,1,2,3]) == nil, "secret with repeats is rejected by scoring")
        check(fb([0,1,2,3],[4,5,4,5]) == nil, "repeated absent colours rejected too")
        // Exhaustive over all 360 x 360 pairs.
        var ok = true; var seenFeedback = Set<DecoderFeedback>(); var solvedCount = 0
        outer: for s in codes {
            for g in codes {
                let f = DecoderRules.score(secret: s, guess: g)!
                let rev = DecoderRules.score(secret: g, guess: s)!
                let common = Set(s).intersection(Set(g)).count
                let exact = zip(s, g).filter { $0 == $1 }.count
                if f.exact != exact || f.exact + f.misplaced != common || f != rev || f.exact > 4 { ok = false; break outer }
                if (f.exact == 4) != (s == g) || f.isSolved != (s == g) { ok = false; break outer }
                if common < 2 { ok = false; break outer }   // 4+4 colours out of 6 always share >= 2
                seenFeedback.insert(f); if f.isSolved { solvedCount += 1 }
            }
        }
        check(ok, "exhaustive 360x360: exact==positional matches, exact+misplaced==set overlap (>=2), symmetric, solved iff equal")
        check(solvedCount == 360, "each code solves exactly itself")
        check(!seenFeedback.contains(DecoderFeedback(exact: 3, misplaced: 1)), "3 exact + 1 misplaced is impossible")
        check(seenFeedback.count == 11, "11 reachable feedback pairs with distinct codes (got \(seenFeedback.count))")

        // --- QA fixtures obey the rules for every secret ---
        var fixturesOK = true
        for secret in codes {
            for name in ["mid", "win", "lose"] {
                var fg = DecoderGame(id: "dec2-f", secret: secret)
                let rows = DecoderGame.fixtureGuesses(name, secret: secret)
                for r in rows { if case .accepted = fg.submit(r) {} else { fixturesOK = false } }
                if rows.count != fg.guesses.count { fixturesOK = false }
                if name == "win" && fg.status != .won { fixturesOK = false }
                if name == "lose" && fg.status != .lost { fixturesOK = false }
                if name == "mid" && fg.status != .playing { fixturesOK = false }
            }
        }
        check(fixturesOK, "fixtures mid/win/lose are legal and reach the intended state for all 360 secrets")

        // --- Game flow: 7-attempt limit, terminal immutability, no repeated guesses ---
        var g = DecoderGame(id: "dec2-t", secret: [0,1,2,3])
        check(g.isPlayable && g.status == .playing && g.attemptsLeft == 7, "fresh")
        check(g.submit([0,1]) == .invalid(.wrongLength(2)) && g.attemptsUsed == 0, "short guess does not consume attempt")
        check(g.submit([9,9,9,9]) == .invalid(.outOfRange(9)) && g.attemptsUsed == 0, "out-of-range does not consume attempt")
        check(g.submit([5,5,4,3]) == .invalid(.repeatedColor(5)) && g.attemptsUsed == 0, "repeated colour rejected, no attempt used")
        check(g.submit([0,0,0,0]) == .invalid(.repeatedColor(0)) && g.attemptsUsed == 0 && g.guesses.isEmpty, "all-same rejected")
        for i in 0..<6 {
            let r = g.submit([5,4,0,1])
            check(r == .accepted(DecoderFeedback(exact: 0, misplaced: 2)), "wrong guess \(i)")
            check(g.status == .playing, "still playing after \(i + 1)")
        }
        check(g.attemptsUsed == 6 && g.attemptsLeft == 1, "six used")
        check(g.submit([0,1,2,3]) == .accepted(DecoderFeedback(exact: 4, misplaced: 0)) && g.status == .won, "win on 7th attempt")
        check(g.submit([5,4,3,2]) == .finished && g.attemptsUsed == 7, "won game immutable")
        var l = DecoderGame(id: "dec2-l", secret: [0,1,2,3])
        for _ in 0..<7 { l.submit([5,4,3,2]) }
        check(l.status == .lost && l.isFinished && l.attemptsLeft == 0, "lost after 7")
        check(l.submit([0,1,2,3]) == .finished && l.status == .lost && l.attemptsUsed == 7, "lost game immutable even with right answer")
        var early = DecoderGame(id: "dec2-e", secret: [4,2,1,0])
        early.submit([4,2,1,0])
        check(early.status == .won && early.attemptsUsed == 1, "win on first")

        // --- Restoration: legal prefix only; repeated / corrupt rows dropped ---
        let corrupt = DecoderGame(id: "dec2-c", secret: [0,1,2,3], guesses: [[5,4,3,2],[0,1,2,3],[5,4,3,2],[9]])
        check(corrupt.guesses.count == 2 && corrupt.status == .won, "restore stops at win")
        let over = DecoderGame(id: "dec2-o", secret: [0,1,2,3], guesses: Array(repeating: [5,4,3,2], count: 12))
        check(over.guesses.count == 7 && over.status == .lost, "restore caps at 7")
        check(DecoderGame(id: "dec2-i", secret: [0,1,2,3], guesses: [[1],[2,2,2,9]]).guesses.isEmpty, "restore drops invalid")
        let withRepeats = DecoderGame(id: "dec2-r", secret: [0,1,2,3], guesses: [[5,5,4,3],[5,4,3,2],[0,0,1,1],[1,0,2,3]])
        check(withRepeats.guesses == [[5,4,3,2],[1,0,2,3]], "restore skips rows that repeat a colour, keeps legal ones (\(withRepeats.guesses))")
        let badSecret = DecoderGame(id: "dec2-b", secret: [0,0,1,2], guesses: [[5,4,3,2]])
        check(!badSecret.isPlayable && badSecret.guesses.isEmpty && badSecret.isFinished, "game with a repeated-colour secret is inert")
        var badSecret2 = badSecret
        check(badSecret2.submit([0,1,2,3]) == .invalid(.invalidSecret) && badSecret2.guesses.isEmpty, "inert game accepts nothing")

        // --- Generation: exhaustive over many seeds ---
        check(DecoderGame.secret(seed: 42) == DecoderGame.secret(seed: 42), "same seed same secret")
        check(DecoderRules.isValid(DecoderGame.secret(seed: 0)) && DecoderRules.isValid(DecoderGame.secret(seed: UInt64.max)), "seed 0 / max valid")
        var counts = [[Int]: Int](); var allDistinct = true; var colorHits = [Int](repeating: 0, count: 6)
        var slotHits = [[Int]](repeating: [Int](repeating: 0, count: 6), count: 4)
        let seeds = 360_000
        for seed in 1...seeds {
            let s = DecoderGame.secret(seed: UInt64(seed) &* 7919)
            if !DecoderRules.isValid(s) || Set(s).count != 4 { allDistinct = false; break }
            counts[s, default: 0] += 1
            for (i, c) in s.enumerated() { colorHits[c] += 1; slotHits[i][c] += 1 }
        }
        check(allDistinct, "\(seeds) seeds: every secret is 4 distinct valid colours")
        check(counts.count == 360, "all 360 codes are reachable (\(counts.count))")
        let expected = Double(seeds) / 360
        check(counts.values.allSatisfy { abs(Double($0) - expected) < expected * 0.25 }, "uniform over codes (min \(counts.values.min() ?? 0), max \(counts.values.max() ?? 0), expected \(Int(expected)))")
        check(slotHits.allSatisfy { row in row.allSatisfy { abs(Double($0) - Double(seeds) / 6) < Double(seeds) / 6 * 0.03 } }, "each colour equally likely in each slot")
        var sequential = true
        for seed in 0..<50_000 { if !DecoderRules.isValid(DecoderGame.secret(seed: UInt64(seed))) { sequential = false } }
        check(sequential, "50k consecutive seeds valid")
        // Real daily seeds: every day 2026-2036
        var dailyOK = true; var dailySecrets = Set<[Int]>()
        for y in 2026...2036 { for m in 1...12 { for d in 1...31 {
            let seed = DecoderGame.dailySeed(year: y, month: m, day: d)
            let s = DecoderGame.secret(seed: seed)
            if !DecoderRules.isValid(s) { dailyOK = false }
            if DecoderGame.secret(seed: seed) != s { dailyOK = false }
            dailySecrets.insert(s)
        } } }
        check(dailyOK && dailySecrets.count > 150, "daily seeds 2026-2036 valid + deterministic (\(dailySecrets.count) distinct)")
        let d1 = DecoderGame.dailySeed(year: 2026, month: 11, day: 8)
        check(d1 == 20261108 * 131 + 283, "daily seed formula unchanged")
        check(DecoderGame.dailySeed(year: 2026, month: 11, day: 8) == d1, "daily stable")
        check(DecoderGame.dailySeed(year: 2026, month: 11, day: 9) != d1, "daily differs by day")
        let es = DecoderGame.make(seed: d1, spanish: true), en = DecoderGame.make(seed: d1, spanish: false)
        check(es.secret == en.secret && es.id == "dec2-\(d1)" && en.id == "en-dec2-\(d1)", "language only changes id; ids are v2")
        check(DecoderGame.isCurrentID(es.id) && DecoderGame.isCurrentID(en.id), "v2 ids recognised")
        check(!DecoderGame.isCurrentID("dec-\(d1)") && !DecoderGame.isCurrentID("en-dec-\(d1)"), "v1 ids NOT current")
        // Frozen vectors: the daily code must not drift between releases/devices.
        check(DecoderGame.secret(seed: 1) == [5,0,4,1] && DecoderGame.secret(seed: 42) == [1,2,4,3] && DecoderGame.secret(seed: 777) == [0,3,2,4], "frozen vectors: seeds 1/42/777")
        check(DecoderGame.secret(seed: DecoderGame.dailySeed(year: 2026, month: 11, day: 9)) == [1,3,2,5]
              && DecoderGame.secret(seed: DecoderGame.dailySeed(year: 2026, month: 11, day: 10)) == [3,1,5,4], "frozen vectors: dailies 2026-11-09/10 (cross-device determinism)")

        // --- Palette accessibility: unique number, name, hex (symbol is LEGACY, not rendered) ---
        // allCases is 8 since the device edition (6 daily + orange/cyan for Infinite). The DAILY
        // palette stays 6 via DecoderRules.colors; the old "== 6" expectation is legitimately 8 now.
        let cs = DecoderColor.allCases
        check(cs.count == 8 && Set(cs.map(\.symbol)).count == 8, "8 unique legacy symbols (API kept, not rendered)")
        check(Set(cs.map(\.number)).count == 8 && cs.map(\.number) == [1,2,3,4,5,6,7,8], "numbers 1..8")
        check(Set(cs.map { $0.name(spanish: true) }).count == 8 && Set(cs.map { $0.name(spanish: false) }).count == 8, "unique names")
        check(Set(cs.map(\.hex.light)).count == 8 && Set(cs.map(\.hex.dark)).count == 8, "unique hex")

        // --- Wheel: wrap, quantisation, hysteresis, angles ---
        check(DecoderWheel.wrap(-1) == 5 && DecoderWheel.wrap(6) == 0 && DecoderWheel.wrap(-13) == 5 && DecoderWheel.wrap(13) == 1, "wrap")
        check(DecoderWheel.rotation(forPosition: 1) == -60 && DecoderWheel.position(forRotation: -60) == 1, "rotation<->position")
        check(DecoderWheel.resolve(position: 0.5, current: 0) == 0, "0.5 stays (hysteresis)")
        check(DecoderWheel.resolve(position: 0.61, current: 0) == 0, "0.61 stays (0.5+0.12 not reached)")
        check(DecoderWheel.resolve(position: 0.63, current: 0) == 1, "0.63 flips")
        check(DecoderWheel.resolve(position: 0.5, current: 1) == 1, "no chatter going back")
        check(DecoderWheel.resolve(position: 0.39, current: 1) == 1, "0.39 stays at 1")
        check(DecoderWheel.resolve(position: 0.37, current: 1) == 0, "flips back below 0.38")
        check(DecoderWheel.resolve(position: -2.9, current: 0) == -3, "multi-detent jump")
        check(DecoderWheel.resolve(position: 13.2, current: 0) == 13 && DecoderWheel.wrap(13) == 1, "past full turn")
        check(DecoderWheel.resolve(position: .nan, current: 4) == 4 && DecoderWheel.resolve(position: .infinity, current: 4) == 4, "non-finite ignored")
        // Sweeping slowly crosses exactly one detent per 60 degrees
        var k = 0; var flips = 0
        var r = 0.0
        while r > -360 { r -= 0.5; let nk = DecoderWheel.resolve(position: DecoderWheel.position(forRotation: r), current: k); if nk != k { flips += 1 }; k = nk }
        check(flips == 6 && DecoderWheel.wrap(k) == 0, "full clockwise sweep = 6 detents, back at start (flips=\(flips))")
        check(DecoderWheel.nearest(current: 0, target: 1) == 1 && DecoderWheel.nearest(current: 0, target: 5) == -1, "nearest short way")
        check(DecoderWheel.nearest(current: 0, target: 3) == 3 && DecoderWheel.nearest(current: 7, target: 0) == 6, "nearest tie/over wrap")
        check(DecoderWheel.nearest(current: 2, target: 2) == 2, "nearest same")
        check(abs(DecoderWheel.angle(dx: 0, dy: -1) - 0) < 1e-9 && abs(DecoderWheel.angle(dx: 1, dy: 0) - 90) < 1e-9
              && abs(DecoderWheel.angle(dx: 0, dy: 1) - 180) < 1e-9 && abs(DecoderWheel.angle(dx: -1, dy: 0) - 270) < 1e-9, "screen angles clockwise from top")
        check(DecoderWheel.shortestDelta(from: 350, to: 10) == 20 && DecoderWheel.shortestDelta(from: 10, to: 350) == -20 && DecoderWheel.shortestDelta(from: 0, to: 180) == 180, "shortest delta wraps")
        check(DecoderWheel.segment(atScreenAngle: 0, rotation: 0) == 0 && DecoderWheel.segment(atScreenAngle: 60, rotation: 0) == 1
              && DecoderWheel.segment(atScreenAngle: 0, rotation: -60) == 1 && DecoderWheel.segment(atScreenAngle: 300, rotation: 0) == 5
              && DecoderWheel.segment(atScreenAngle: 0, rotation: 60) == 5, "segment under angle")
        // Pointer consistency: after snapping to k the pointed segment is wrap(k)
        for kk in -12...12 { check(DecoderWheel.segment(atScreenAngle: 0, rotation: DecoderWheel.rotation(forPosition: kk)) == DecoderWheel.wrap(kk), "pointer segment k=\(kk)") }

        // --- Haptic throttle ---
        var t = DecoderHapticThrottle(minInterval: 0.05)
        check(t.allow(at: 1.0), "first click")
        check(!t.allow(at: 1.01) && !t.allow(at: 1.049), "suppressed inside window")
        check(t.allow(at: 1.06), "allowed after window")
        var burst = DecoderHapticThrottle(minInterval: 0.05); var played = 0
        for i in 0..<1000 { if burst.allow(at: 5.0 + Double(i) * 0.001) { played += 1 } }   // 1 s of 1 kHz updates
        check(played <= 21 && played >= 19, "1 s fast spin yields ~20 clicks, not 1000 (got \(played))")
        check(t.allow(at: 0.5), "clock going backwards does not wedge the throttle")

        // --- Draft editing: duplicates are impossible ---
        var d = DecoderDraft()
        check(!d.isComplete && d.code == nil && d.selected == 0 && d.usedColors.isEmpty, "draft empty")
        check(d.place(2) == .placed(slot: 0) && d.selected == 1, "place advances to next empty slot")
        check(d.place(2) == .duplicate(color: 2, heldBy: 0) && d.slots[1] == nil && d.selected == 1, "same colour in another slot REJECTED, nothing changes")
        check(!d.canPlace(2) && d.canPlace(3) && d.holder(of: 2) == 0, "canPlace / holder reflect used colours")
        d.select(0)
        check(d.place(2) == .unchanged(slot: 0) && d.slots[0] == 2, "re-placing the same colour in its own slot is a no-op")
        check(d.place(4) == .placed(slot: 0) && d.slots[0] == 4 && d.selected == 1, "replacing a slot frees its old colour")
        check(d.canPlace(2) && !d.canPlace(4), "freed colour is available again")
        check(d.place(2) == .placed(slot: 1) && d.selected == 2, "colour freed by replacement can be reused elsewhere")
        check(d.place(1) == .placed(slot: 2) && d.place(3) == .placed(slot: 3), "fill remaining")
        check(d.isComplete && d.code == [4,2,1,3] && d.usedColors == [1,2,3,4], "complete code \(String(describing: d.code))")
        d.select(1); d.clearSelected(); check(!d.isComplete && d.code == nil && d.canPlace(2), "clear slot frees colour")
        check(d.place(9) == .invalid && d.slots[1] == nil && d.place(-1) == .invalid, "invalid colour ignored")
        check(d.place(4) == .duplicate(color: 4, heldBy: 0) && d.place(3) == .duplicate(color: 3, heldBy: 3), "duplicates still rejected after edits")
        d.select(7); check(d.selected == 1, "invalid slot ignored")
        d.reset(); check(d == DecoderDraft(), "reset")
        // UI paths, exhaustively: any sequence of place/select/clear keeps the draft legal.
        var rng = DecoderRNG(seed: 99); var invariantOK = true; var rejected = 0; var completed = 0
        for _ in 0..<20_000 {
            var x = DecoderDraft()
            for _ in 0..<40 {
                switch rng.int(4) {
                case 0: x.select(rng.int(4))
                case 1: x.clearSelected()
                default:
                    let c = rng.int(6)
                    let before = x
                    let r = x.place(c)
                    if case .duplicate(let color, let held) = r {
                        rejected += 1
                        if x != before || x.slots[held] != color { invariantOK = false }
                    }
                }
                let filled = x.slots.compactMap { $0 }
                if Set(filled).count != filled.count { invariantOK = false }
                if let code = x.code { completed += 1; if !DecoderRules.isValid(code) { invariantOK = false } }
            }
        }
        check(invariantOK && rejected > 10_000 && completed > 1_000, "random UI walk (800k steps): draft never holds a repeated colour; \(rejected) rejections, \(completed) complete rows")
        // Every complete draft submits and every submitted draft is legal.
        var viaDraft = DecoderGame(id: "dec2-d", secret: [0,1,2,3])
        var dd = DecoderDraft(); for c in [5,4,3,2] { dd.place(c) }
        check(viaDraft.submit(dd.code!) == .accepted(DecoderFeedback(exact: 0, misplaced: 2)), "draft code is accepted by the game")

        // --- Persistence (isolated suite) ---
        let suite = "decoder-test-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = DecoderStore(defaults: defaults)
        var pg = DecoderGame(id: "dec2-p1", secret: [0,1,2,3])
        pg.submit([5,4,3,2]); pg.submit([0,5,4,1])
        store.save(pg)
        let back = store.load(id: "dec2-p1", secret: [0,1,2,3])
        check(back == pg && back.guesses.count == 2 && back.status == .playing, "round trip restart-safe")
        check(DecoderStore(defaults: defaults).load(id: "dec2-p1", secret: [0,1,2,3]) == pg, "fresh store instance sees data")
        check(store.load(id: "dec2-none", secret: [0,1,2,3]).guesses.isEmpty, "unknown id empty")
        check(!store.recordResultIfNew(pg), "unfinished game never recorded")
        pg.submit([0,1,2,3]); store.save(pg)
        check(store.recordResultIfNew(pg), "win recorded once")
        check(!store.recordResultIfNew(pg), "win not recorded twice")
        store.clear(id: "dec2-p1")
        check(store.load(id: "dec2-p1", secret: [0,1,2,3]).guesses.isEmpty, "clear wipes board")
        var replay = DecoderGame(id: "dec2-p1", secret: [0,1,2,3]); replay.submit([0,1,2,3])
        check(!store.recordResultIfNew(replay), "restart then re-win does not farm a second win")
        var lost = DecoderGame(id: "dec2-p2", secret: [0,1,2,3]); for _ in 0..<7 { lost.submit([5,4,3,2]) }
        check(store.recordResultIfNew(lost) && !store.recordResultIfNew(lost), "loss recorded once")
        var s = store.stats
        check(s.played == 2 && s.wins == 1 && s.losses == 1 && s.distribution[2] == 1, "stats \(s) (win on attempt 3, loss counted as loss)")
        var lostAsWin = DecoderGame(id: "dec2-p3", secret: [0,1,2,3]); for _ in 0..<7 { lostAsWin.submit([5,4,3,2]) }
        store.recordResultIfNew(lostAsWin); s = store.stats
        check(s.wins == 1 && s.losses == 2, "losses never count as wins")
        check(!store.recordResultIfNew(DecoderGame(id: "dec2-inert", secret: [1,1,1,1])), "inert game never recorded as a loss")
        var v1Lost = DecoderGame(id: "dec-12345", secret: [0,1,2,3]); for _ in 0..<7 { v1Lost.submit([5,4,3,2]) }
        check(v1Lost.isFinished && !store.recordResultIfNew(v1Lost), "v1-style id never recorded")
        for i in 0..<70 { var x = DecoderGame(id: "dec2-bulk\(i)", secret: [0,1,2,3]); x.submit([5,4,3,2]); store.save(x) }
        check((defaults.dictionary(forKey: DecoderStore.sessionsKey) as? [String: [[Int]]])?.count == DecoderStore.keepSessions, "sessions pruned to \(DecoderStore.keepSessions)")
        check(store.stats.played == 3, "pruning sessions keeps results")
        store.wipeAll(); check(store.stats.played == 0 && store.guesses(for: "dec2-bulk69").isEmpty, "wipeAll")

        // --- Migration from rules v1 (repeated colours allowed) ---
        let mSuite = "decoder-migration-\(UUID().uuidString)"
        let md = UserDefaults(suiteName: mSuite)!
        defer { md.removePersistentDomain(forName: mSuite) }
        let v1Sessions: [String: [[Int]]] = ["dec-777": [[0,0,1,1],[2,2,2,2]], "en-dec-777": [[5,5,5,5]], "dec-888": [[0,1,2,3]]]
        let v1Order = ["dec-888", "dec-777", "en-dec-777"]
        let v1Results: [String: Int] = ["dec-888": 1, "dec-777": 0]
        md.set(v1Sessions, forKey: "newsraider.decoder.sessions.v1")
        md.set(v1Order, forKey: "newsraider.decoder.order.v1")
        md.set(v1Results, forKey: "newsraider.decoder.results.v1")
        md.set("keep-me", forKey: "newsraider.puzzleSnapshots.v1")          // another game's data
        md.set(["x": 1], forKey: "newsraider.puzzleFullDays")
        let m = DecoderStore(defaults: md)
        check(m.hasLegacyV1Data, "legacy v1 data detected")
        check(m.stats.played == 0 && m.guesses(for: "dec-777").isEmpty, "v1 results and sessions are NOT visible to v2")
        // The v1 ids can never be restored, even if asked for with a legal secret.
        let v1Restore = m.load(id: "dec-777", secret: [0,1,2,3])
        check(v1Restore.guesses.isEmpty && v1Restore.status == .playing, "v1 id never restores guesses")
        // Playing v2 does not touch v1.
        var fresh = DecoderGame.make(seed: 777, spanish: true)
        check(fresh.id == "dec2-777" && fresh.guesses.isEmpty, "same seed under v2 starts clean on a new id")
        fresh.submit([0,1,2,3] == fresh.secret ? [5,4,3,2] : [0,1,2,3]); m.save(fresh)
        for _ in 0..<7 { fresh.submit(fresh.secret == [5,4,3,2] ? [0,1,2,3] : [5,4,3,2]) }
        m.save(fresh); m.recordResultIfNew(fresh)
        m.clear(id: fresh.id)
        check((md.dictionary(forKey: "newsraider.decoder.sessions.v1") as? [String: [[Int]]]) == v1Sessions
              && md.stringArray(forKey: "newsraider.decoder.order.v1") == v1Order
              && (md.dictionary(forKey: "newsraider.decoder.results.v1") as? [String: Int]) == v1Results, "v1 data byte-identical after v2 save/record/clear")
        check(md.string(forKey: "newsraider.puzzleSnapshots.v1") == "keep-me" && md.dictionary(forKey: "newsraider.puzzleFullDays") != nil, "other games' keys untouched")
        // Corrupt v2 payloads must not crash or poison the board.
        md.set(["dec2-bad": [[1,1,1,1],[0,1]]], forKey: DecoderStore.sessionsKey)
        md.set("garbage", forKey: DecoderStore.resultsKey)
        check(DecoderStore(defaults: md).load(id: "dec2-bad", secret: [0,1,2,3]).guesses.isEmpty, "illegal rows inside v2 payload dropped on restore")
        check(DecoderStore(defaults: md).stats.played == 0, "malformed results payload ignored")
        // Explicit full reset clears v2 and dormant v1, and only Decoder keys.
        m.wipeAll()
        check(!m.hasLegacyV1Data && md.string(forKey: "newsraider.puzzleSnapshots.v1") == "keep-me", "wipeAll clears Decoder v1+v2 only")

        // --- Haptic recipes: bounds, durations, distinct cues, defensive input ---
        var cues: [DecoderHapticCue] = [.detent, .place, .slot, .clear, .reject, .warning, .error, .win, .loss]
        for e in 0...4 { for m in 0...4 { cues.append(.submit(exact: e, misplaced: m)) } }
        cues += [.submit(exact: -3, misplaced: -1), .submit(exact: 99, misplaced: 99), .submit(exact: Int.max, misplaced: Int.min), .submit(exact: 2, misplaced: 99)]
        for cue in cues {
            let ev = DecoderHapticRecipe.events(for: cue)
            check(!ev.isEmpty && ev.count <= DecoderHapticRecipe.maxEvents, "haptic \(cue): 1...maxEvents events (\(ev.count))")
            check(ev.allSatisfy { (0...1).contains($0.intensity) && (0...1).contains($0.sharpness) && $0.time >= 0 && $0.duration >= 0
                                  && $0.intensity.isFinite && $0.sharpness.isFinite }, "haptic \(cue): intensity/sharpness in 0...1")
            check((ev.map(\.end).max() ?? 0) <= DecoderHapticRecipe.maxDuration, "haptic \(cue): total <= \(DecoderHapticRecipe.maxDuration) s")
            check(ev.allSatisfy { $0.duration <= DecoderHapticRecipe.maxContinuous }, "haptic \(cue): continuous bodies short")
            check(ev == ev.sorted { $0.time < $1.time } && DecoderHapticRecipe.sanitize(ev) == ev, "haptic \(cue): sorted + sanitize idempotent")
            check(ev.contains { !$0.isContinuous && $0.intensity >= 0.5 }, "haptic \(cue): has a transient click")
            let w = DecoderHapticRecipe.watchSteps(for: cue)
            check(!w.isEmpty && w.count <= DecoderHapticRecipe.watchMaxSteps && w.first?.delay == 0, "watch \(cue): 1...\(DecoderHapticRecipe.watchMaxSteps) steps starting now")
            check((w.last?.delay ?? 0) <= DecoderHapticRecipe.maxDuration && w.map(\.delay) == w.map(\.delay).sorted(), "watch \(cue): finite and ordered")
            check(zip(w, w.dropFirst()).allSatisfy { $1.delay - $0.delay >= DecoderHapticRecipe.watchMinGap }, "watch \(cue): gaps >= minimum")
        }
        check(DecoderHapticRecipe.maxDuration <= 1.2 && DecoderHapticRecipe.wheelMinInterval >= 0.045, "recipe limits: <=1.2 s, wheel >=45 ms")
        // Hostile raw input is clamped / dropped.
        let hostile = DecoderHapticRecipe.sanitize([
            DecoderHapticEvent(time: -1, intensity: 7, sharpness: -2, duration: 99),
            DecoderHapticEvent(time: .nan, intensity: 1, sharpness: 1, duration: 0),
            DecoderHapticEvent(time: 0.5, intensity: .infinity, sharpness: 1, duration: 0),
            DecoderHapticEvent(time: 5, intensity: 1, sharpness: 1, duration: 0),
            DecoderHapticEvent(time: 1.1, intensity: 1, sharpness: 1, duration: 1)])
        check(hostile.count == 2 && hostile[0] == DecoderHapticEvent(time: 0, intensity: 1, sharpness: 0, duration: DecoderHapticRecipe.maxContinuous)
              && abs(hostile[1].end - DecoderHapticRecipe.maxDuration) < 1e-9, "sanitize clamps, drops NaN/inf/late, trims overlong")
        check(DecoderHapticRecipe.sanitize((0..<50).map { DecoderHapticEvent(time: Double($0) * 0.01, intensity: 1, sharpness: 1) }).count == DecoderHapticRecipe.maxEvents, "sanitize caps event count")
        // Distinct patterns: every named cue differs from every other.
        let named: [DecoderHapticCue] = [.detent, .place, .slot, .clear, .reject, .warning, .error, .win, .loss, .submit(exact: 1, misplaced: 1)]
        var distinct = true
        for i in 0..<named.count { for j in (i + 1)..<named.count where DecoderHapticRecipe.events(for: named[i]) == DecoderHapticRecipe.events(for: named[j]) { distinct = false } }
        check(distinct, "all game cues have distinct haptic patterns")
        func steps(_ c: DecoderHapticCue) -> [DecoderWatchStep] { DecoderHapticRecipe.watchSteps(for: c) }
        let wNamed: [DecoderHapticCue] = [.place, .clear, .reject, .warning, .error, .win, .loss, .submit(exact: 1, misplaced: 1)]
        var wDistinct = true
        for i in 0..<wNamed.count { for j in (i + 1)..<wNamed.count where steps(wNamed[i]) == steps(wNamed[j]) { wDistinct = false } }
        check(wDistinct, "watch: place/clear/reject/warning/error/win/loss/submit sequences distinct")
        // Win and loss are long, rich and unlike each other (not a lone weak tap).
        let win = DecoderHapticRecipe.events(for: .win), loss = DecoderHapticRecipe.events(for: .loss)
        check(win.count >= 5 && loss.count >= 4 && (win.map(\.end).max() ?? 0) >= 0.5 && (loss.map(\.end).max() ?? 0) >= 0.5, "win/loss are multi-event and >= 0.5 s")
        let winPeaks = win.filter { !$0.isContinuous }.map(\.intensity)
        check(winPeaks == winPeaks.sorted() && (winPeaks.last ?? 0) == 1, "win transients rise to full intensity")
        check(loss.contains { $0.isContinuous && $0.time == 0 && $0.intensity == 1 && $0.sharpness <= 0.2 }, "loss opens with a heavy low-sharpness body")
        check(steps(.win).map(\.tap) != steps(.loss).map(\.tap) && steps(.win).count >= 3 && steps(.loss).count >= 3, "watch win/loss differ and have >= 3 steps")
        // Submit: pulse counts follow exact/misplaced, even zero, and defensive input is clamped.
        func transients(_ e: Int, _ m: Int, strong: Bool) -> Int {
            DecoderHapticRecipe.events(for: .submit(exact: e, misplaced: m)).filter { !$0.isContinuous && $0.time >= 0.16 && ($0.intensity >= 0.9) == strong }.count
        }
        check(transients(2, 1, strong: true) == 2 && transients(2, 1, strong: false) == 1, "submit(2,1): 2 firm + 1 light pulses")
        check(transients(0, 3, strong: true) == 0 && transients(0, 3, strong: false) == 3, "submit(0,3): only light pulses")
        check(transients(4, 0, strong: true) == 4, "submit(4,0): 4 firm pulses")
        let zero = DecoderHapticRecipe.events(for: .submit(exact: 0, misplaced: 0))
        check(zero.contains { $0.isContinuous && $0.time >= 0.16 } && zero.filter { !$0.isContinuous }.count == 1, "submit(0,0): key press + one dull thud, no result pulses")
        check(DecoderHapticRecipe.events(for: .submit(exact: -5, misplaced: -5)) == zero, "submit negatives = zero")
        check(DecoderHapticRecipe.events(for: .submit(exact: 99, misplaced: 99)) == DecoderHapticRecipe.events(for: .submit(exact: 4, misplaced: 0)), "submit overflow clamps to 4 exact")
        check(DecoderHapticRecipe.events(for: .submit(exact: 2, misplaced: 99)) == DecoderHapticRecipe.events(for: .submit(exact: 2, misplaced: 2)), "submit total never exceeds 4 slots")
        check(DecoderHapticRecipe.events(for: .submit(exact: 1, misplaced: 0)) != DecoderHapticRecipe.events(for: .submit(exact: 0, misplaced: 1)), "exact differs from misplaced")
        check(steps(.submit(exact: 1, misplaced: 0)) != steps(.submit(exact: 0, misplaced: 1)) && steps(.submit(exact: 0, misplaced: 0)) != steps(.submit(exact: 1, misplaced: 0)), "watch submit differs for exact / misplaced / none")

        // =====================================================================
        // Device edition: 8-colour palette, per-game colour count, Infinite
        // (own scope: it reuses short names such as r / hostile on purpose)
        // =====================================================================
        do {

        // --- Palette 8: rawValues 0...5 preserved, LED colours (no grey), distinct ---
        check(DecoderColor(rawValue: 0) == .red && DecoderColor(rawValue: 1) == .yellow && DecoderColor(rawValue: 2) == .green
              && DecoderColor(rawValue: 3) == .blue && DecoderColor(rawValue: 4) == .pink && DecoderColor(rawValue: 5) == .violet
              && DecoderColor(rawValue: 6) == .orange && DecoderColor(rawValue: 7) == .cyan && DecoderColor(rawValue: 8) == nil
              && DecoderColor(rawValue: -1) == nil, "rawValues 0...5 keep their order (5 was graphite, now violet); 6/7 new; 8 none")
        check(DecoderColor.palette(count: 6).count == 6 && DecoderColor.palette(count: 7).count == 7 && DecoderColor.palette(count: 8).count == 8
              && DecoderColor.palette(count: 0).count == 4 && DecoderColor.palette(count: -9).count == 4 && DecoderColor.palette(count: 99).count == 8
              && DecoderColor.palette(count: 4).map(\.rawValue) == [0,1,2,3] && DecoderColor.palette(count: 5).map(\.rawValue) == [0,1,2,3,4]
              && DecoderColor.palette(count: 7).map(\.rawValue) == [0,1,2,3,4,5,6], "palette(count:) is a clamped prefix (CHANGED 2026-11-10: floor is 4, was 6)")
        func channels(_ h: UInt32) -> [Int] { [Int((h >> 16) & 0xFF), Int((h >> 8) & 0xFF), Int(h & 0xFF)] }
        func dist2(_ a: UInt32, _ b: UInt32) -> Int { zip(channels(a), channels(b)).reduce(0) { $0 + ($1.0 - $1.1) * ($1.0 - $1.1) } }
        var ledOK = true, apartOK = true
        for c in cs {
            for h in [c.hex.light, c.hex.dark] {
                let ch = channels(h)
                if (ch.max() ?? 0) - (ch.min() ?? 0) < 0x70 { ledOK = false }   // saturated: no dull grey
            }
        }
        for i in 0..<cs.count { for j in (i + 1)..<cs.count {
            if dist2(cs[i].hex.light, cs[j].hex.light) < 3000 || dist2(cs[i].hex.dark, cs[j].hex.dark) < 3000 { apartOK = false }
        } }
        check(ledOK, "every colour is saturated (LED-like), none is a muted grey")
        check(apartOK, "every pair of colours is visibly different in both appearances")

        // --- Per-game configuration: daily stays 6 ---
        check(DecoderRules.colors == 6 && DecoderRules.colors != DecoderColor.allCases.count, "daily palette size is 6 and independent of allCases (8)")
        check(DecoderRules.possibleCodes == 360 && DecoderRules.codeCount(colors: 6) == 360
              && DecoderRules.codeCount(colors: 7) == 840 && DecoderRules.codeCount(colors: 8) == 1680, "360 / 840 / 1680 codes")
        // CHANGED 2026-11-10: minColors is 4 (was 6), so hostile counts clamp to 4 -> 24 codes.
        check(DecoderRules.codeCount(colors: 0) == 24 && DecoderRules.codeCount(colors: -4) == 24 && DecoderRules.codeCount(colors: Int.max) == 1680
              && DecoderRules.clampedColors(Int.min) == 4 && DecoderRules.clampedColors(Int.max) == 8, "config sanitised (0, negative, huge)")
        check(DecoderRules.minColors == 4 && DecoderRules.maxColors == 8 && (4...8).map { DecoderRules.clampedColors($0) } == [4,5,6,7,8]
              && DecoderRules.clampedColors(3) == 4 && DecoderRules.clampedColors(9) == 8, "palette range is 4...8")
        check((4...8).map { DecoderRules.codeCount(colors: $0) } == [24, 120, 360, 840, 1680], "24 / 120 / 360 / 840 / 1680 codes for 4...8 colours")
        let perms4 = DecoderRules.allCodes(colors: 4)
        check(perms4.count == 24 && perms4.allSatisfy { Set($0) == [0,1,2,3] }, "with 4 colours every code is a permutation of all four")
        for n in 4...8 {
            let all = DecoderRules.allCodes(colors: n)
            check(all.count == DecoderRules.codeCount(colors: n) && Set(all).count == all.count && all.allSatisfy { DecoderRules.isValid($0, colors: n) }, "allCodes(colors: \(n))")
        }
        check(DecoderRules.allCodes(colors: 8).count == 1680 && DecoderRules.allCodes().count == 360 && DecoderRules.allCodes() == codes, "8P4 = 1680 and the default is still the daily 360")
        check(DecoderRules.isValid([0,1,2,6], colors: 7) && !DecoderRules.isValid([0,1,2,6], colors: 6) && !DecoderRules.isValid([0,1,2,6]), "colour 6 legal only with 7+ colours")
        check(DecoderRules.isValid([0,1,2,7], colors: 8) && !DecoderRules.isValid([0,1,2,7], colors: 7), "colour 7 legal only with 8 colours")
        check(DecoderRules.violation([0,1,2,8], colors: 8) == .outOfRange(8) && DecoderRules.violation([0,1,2,-1], colors: 8) == .outOfRange(-1)
              && DecoderRules.violation([7,7,0,1], colors: 8) == .repeatedColor(7), "violations with 8 colours")
        check(DecoderRules.violation([0,1,2,6], colors: 3) == .outOfRange(6) && DecoderRules.violation([0,1,2,3], colors: Int.min) == nil
              && DecoderRules.violation([0,1,2,3], colors: Int.max) == nil, "hostile colour counts are clamped, never crash")

        // --- Scoring with 7 and 8 colours (exhaustive / strided) ---
        func fb8(_ s: [Int], _ g: [Int], _ n: Int) -> DecoderFeedback? { DecoderRules.score(secret: s, guess: g, colors: n) }
        check(fb8([0,1,2,3], [4,5,6,7], 8) == DecoderFeedback(exact: 0, misplaced: 0), "8 colours: disjoint codes score 0/0")
        check(fb8([6,1,2,7], [7,6,1,2], 8) == DecoderFeedback(exact: 0, misplaced: 4), "8 colours: all misplaced")
        check(fb8([6,1,2,7], [6,1,7,2], 8) == DecoderFeedback(exact: 2, misplaced: 2), "8 colours: 2 exact 2 swapped")
        check(fb8([6,1,2,5], [6,1,2,7], 8) == DecoderFeedback(exact: 3, misplaced: 0), "8 colours: 3 exact, 1 absent")
        check(fb8([6,1,2,3], [6,1,2,3], 7) == DecoderFeedback(exact: 4, misplaced: 0), "7 colours: solved")
        check(fb8([6,1,2,3], [0,1,2,3], 6) == nil && fb8([0,1,2,3], [7,6,5,4], 7) == nil && fb8([0,1,2,3], [7,6,5,4], 8) != nil, "colours outside the game's palette are rejected")
        check(fb8([0,1,2,3], [3,2,1,0], Int.min) == DecoderFeedback(exact: 0, misplaced: 4), "hostile count is clamped (to 4 colours) and still scores")
        check(fb8([0,1,2,4], [0,1,2,3], 4) == nil && fb8([0,1,2,3], [0,1,2,4], 4) == nil && fb8([0,1,2,4], [4,2,1,0], 5) == DecoderFeedback(exact: 0, misplaced: 4),
              "colour 4 is illegal with 4 colours, legal with 5")
        // 4 and 5 colours, fully exhaustive (24x24 and 120x120).
        for n in 4...5 {
            let all = DecoderRules.allCodes(colors: n)
            var good = true; var seen = Set<DecoderFeedback>(); var solved = 0
            for s in all { for g in all {
                guard let f = DecoderRules.score(secret: s, guess: g, colors: n), let rev = DecoderRules.score(secret: g, guess: s, colors: n) else { good = false; continue }
                let common = Set(s).intersection(Set(g)).count
                let exact = zip(s, g).filter { $0 == $1 }.count
                if f.exact != exact || f.exact + f.misplaced != common || f != rev { good = false }
                if common < 2 * DecoderRules.slots - n { good = false }      // 4 colours: always all 4; 5 colours: at least 3
                if f.isSolved != (s == g) { good = false }
                seen.insert(f); if f.isSolved { solved += 1 }
            } }
            check(good, "\(n) colours: exhaustive scoring (exact==positional, exact+misplaced==overlap, symmetric, solved iff equal)")
            check(solved == all.count, "\(n) colours: each code solves exactly itself")
            check(!seen.contains(DecoderFeedback(exact: 3, misplaced: 1)) && seen.count == (n == 4 ? 4 : 8), "\(n) colours: reachable feedback pairs = \(seen.count)")
        }
        for n in 7...8 {
            let all = DecoderRules.allCodes(colors: n)
            var good = true; var seen = Set<DecoderFeedback>(); var solved = 0
            let stepBy = n == 7 ? 1 : 7
            var si = 0
            outer8: while si < all.count {
                let s = all[si]; si += stepBy
                for g in all {
                    let f = DecoderRules.score(secret: s, guess: g, colors: n)!
                    let rev = DecoderRules.score(secret: g, guess: s, colors: n)!
                    let common = Set(s).intersection(Set(g)).count
                    let exact = zip(s, g).filter { $0 == $1 }.count
                    if f.exact != exact || f.exact + f.misplaced != common || f != rev { good = false; break outer8 }
                    if common < max(0, 2 * DecoderRules.slots - n) { good = false; break outer8 }
                    if f.isSolved != (s == g) { good = false; break outer8 }
                    seen.insert(f); if f.isSolved { solved += 1 }
                }
            }
            check(good, "\(n) colours: exact==positional, exact+misplaced==set overlap, symmetric, solved iff equal")
            check(solved == (all.count + stepBy - 1) / stepBy,"\(n) colours: each sampled secret is solved by exactly itself")
            check(!seen.contains(DecoderFeedback(exact: 3, misplaced: 1)) && seen.count == (n == 7 ? 13 : 14), "\(n) colours: reachable feedback pairs = \(seen.count)")
        }

        // --- Games with a colour count ---
        var g8 = DecoderGame(id: "t8", secret: [7,6,5,4], colorCount: 8)
        check(g8.isPlayable && g8.colorCount == 8 && g8.status == .playing, "8-colour game with a 7-valued secret is playable")
        check(g8.submit([0,1,2,3]) == .accepted(DecoderFeedback(exact: 0, misplaced: 0)), "8-colour game: 0/0 accepted")
        check(g8.submit([8,1,2,3]) == .invalid(.outOfRange(8)) && g8.submit([7,7,1,2]) == .invalid(.repeatedColor(7)) && g8.attemptsUsed == 1, "8-colour game: bad guesses do not consume attempts")
        check(g8.submit([7,6,5,4]) == .accepted(DecoderFeedback(exact: 4, misplaced: 0)) && g8.status == .won, "8-colour game can be won")
        let inert6 = DecoderGame(id: "t6", secret: [7,6,5,4])
        check(!inert6.isPlayable && inert6.colorCount == 6 && inert6.isFinished, "default 6 colours: a secret using colour 7 is inert")
        // CHANGED 2026-11-10: hostile counts clamp to the new floor 4 (was 6). The DEFAULT is still 6.
        check(DecoderGame(id: "c", secret: [0,1,2,3], colorCount: 99).colorCount == 8 && DecoderGame(id: "c", secret: [0,1,2,3], colorCount: -3).colorCount == 4
              && DecoderGame(id: "c", secret: [0,1,2,3], colorCount: 0).colorCount == 4 && DecoderGame(id: "c", secret: [0,1,2,3]).colorCount == 6, "game colourCount sanitised to 4...8, default 6")
        var g4 = DecoderGame(id: "t4", secret: [3,1,0,2], colorCount: 4)
        check(g4.isPlayable && g4.colorCount == 4 && g4.submit([0,1,2,4]) == .invalid(.outOfRange(4)) && g4.attemptsUsed == 0, "4-colour game refuses colour 4")
        check(g4.submit([0,1,2,3]) == .accepted(DecoderFeedback(exact: 1, misplaced: 3)) && g4.submit([3,1,0,2]) == .accepted(DecoderFeedback(exact: 4, misplaced: 0)) && g4.status == .won,
              "4-colour game: every guess is a permutation, exact+misplaced == 4, can be won")
        check(!DecoderGame(id: "t4b", secret: [0,1,2,4], colorCount: 4).isPlayable && DecoderGame(id: "t5", secret: [0,1,2,4], colorCount: 5).isPlayable, "a secret using colour 4 needs 5+ colours")
        let restored7 = DecoderGame(id: "r7", secret: [6,0,1,2], guesses: [[6,5,4,3],[7,1,2,3],[0,1,2,6]], colorCount: 7)
        check(restored7.guesses == [[6,5,4,3],[0,1,2,6]], "restoring under 7 colours drops the row that uses colour 7")
        var fixturesN = true
        for n in 4...8 {
            for secret in DecoderRules.allCodes(colors: n).enumerated().filter({ $0.offset % 11 == 0 }).map({ $0.element }) {
                for name in ["mid", "win", "lose"] {
                    var fg = DecoderGame(id: "f", secret: secret, colorCount: n)
                    let rows = DecoderGame.fixtureGuesses(name, secret: secret, colors: n)
                    for r in rows { if case .accepted = fg.submit(r) {} else { fixturesN = false } }
                    if rows.count != fg.guesses.count { fixturesN = false }
                    if name == "win" && fg.status != .won { fixturesN = false }
                    if name == "lose" && fg.status != .lost { fixturesN = false }
                    if name == "mid" && fg.status != .playing { fixturesN = false }
                }
            }
        }
        check(fixturesN, "fixtures stay legal and reach their state for 4/5/6/7/8 colours (with 4/5 'lose' never contains the secret)")
        check(DecoderGame.fixtureGuesses("lose", secret: [0,1,2,3]) == [[1,2,3,4],[2,3,4,5],[3,4,5,0],[4,5,0,1],[5,0,1,2],[1,0,2,3],[0,2,1,3]],
              "6-colour fixtures are byte-identical to before the 4/5-colour fix")

        // --- Generation for 6/7/8 colours; the daily draw is unchanged ---
        check(DecoderGame.secret(seed: 1, colors: 6) == DecoderGame.secret(seed: 1) && DecoderGame.secret(seed: 1) == [5,0,4,1]
              && DecoderGame.secret(seed: DecoderGame.dailySeed(year: 2026, month: 11, day: 9)) == [1,3,2,5], "daily draw (6 colours) is bit-for-bit the old one")
        check(DecoderGame.make(seed: d1, spanish: true).colorCount == 6 && DecoderGame.make(seed: d1, spanish: true).id == "dec2-\(d1)", "daily game: 6 colours, v2 id, stable seed")
        for n in 4...8 {
            let total = DecoderRules.codeCount(colors: n)
            let seedsN = total * 250
            var hits = [[Int]: Int](); var valid = true
            for seed in 1...seedsN {
                let s = DecoderGame.secret(seed: UInt64(seed) &* 7919, colors: n)
                if !DecoderRules.isValid(s, colors: n) { valid = false; break }
                hits[s, default: 0] += 1
            }
            check(valid && hits.count == total, "\(n) colours: every secret legal and all \(total) codes reachable (\(hits.count))")
            check(hits.values.allSatisfy { abs(Double($0) - 250) < 250 * 0.45 }, "\(n) colours: uniform over codes (min \(hits.values.min() ?? 0), max \(hits.values.max() ?? 0))")
        }
        check(DecoderGame.secret(seed: 0, colors: 8).count == 4 && DecoderRules.isValid(DecoderGame.secret(seed: UInt64.max, colors: 8), colors: 8)
              && DecoderRules.isValid(DecoderGame.secret(seed: 5, colors: Int.max), colors: 8) && DecoderRules.isValid(DecoderGame.secret(seed: 5, colors: -1)), "generation: seed 0/max and hostile counts")

        // --- Draft with a dynamic colour count ---
        var dd8 = DecoderDraft(colorCount: 8)
        check(dd8.colorCount == 8 && dd8.place(7) == .placed(slot: 0) && dd8.place(8) == .invalid && dd8.place(-1) == .invalid, "8-colour draft accepts colour 7, refuses 8")
        check(dd8.place(7) == .duplicate(color: 7, heldBy: 0) && dd8.canPlace(6) && !dd8.canPlace(7) && !dd8.canPlace(8), "8-colour draft: duplicates refused, canPlace follows count")
        dd8.reset(); check(dd8.colorCount == 8 && dd8.filledCount == 0, "reset keeps the colour count")
        var dd6 = DecoderDraft()
        check(dd6.colorCount == 6 && dd6.place(6) == .invalid && !dd6.canPlace(6), "default draft refuses colour 6")
        var dd7 = DecoderDraft(colorCount: 7)
        // CHANGED 2026-11-10: hostile counts clamp to 4 (was 6).
        check(DecoderDraft(colorCount: 99).colorCount == 8 && DecoderDraft(colorCount: -2).colorCount == 4 && dd7.place(6) == .placed(slot: 0), "draft colour count sanitised")
        var dd4 = DecoderDraft(colorCount: 4)
        check(dd4.place(4) == .invalid && dd4.place(3) == .placed(slot: 0) && dd4.place(3) == .duplicate(color: 3, heldBy: 0)
              && dd4.place(0) == .placed(slot: 1) && dd4.place(1) == .placed(slot: 2) && dd4.place(2) == .placed(slot: 3) && dd4.code == [3,0,1,2],
              "4-colour draft: refuses colour 4 and repeats; the full row is a permutation")
        let rest1 = DecoderDraft(restoring: [1, 1, 2, -1], selected: 2, colorCount: 6)
        check(rest1.slots == [1, nil, 2, nil] && rest1.selected == 2 && rest1.rawSlots == [1, -1, 2, -1], "restoring a row drops duplicates through place()")
        let rest2 = DecoderDraft(restoring: [9, 3, -5, 7], selected: 3, colorCount: 8)
        check(rest2.slots == [nil, 3, nil, 7] && rest2.selected == 3, "restoring drops out-of-range and negative values")
        check(DecoderDraft(restoring: [0,1,2,3,4,5,6,7,8], selected: 99, colorCount: 6).filledCount == 4
              && DecoderDraft(restoring: [], selected: -4, colorCount: 7) == DecoderDraft(colorCount: 7), "restoring: overlong / empty / hostile selection")
        var walkOK = true
        for n in [4, 5, 7, 8] {
            var wr = DecoderRNG(seed: UInt64(n) * 31)
            for _ in 0..<5000 {
                var x = DecoderDraft(colorCount: n)
                for _ in 0..<30 {
                    switch wr.int(4) {
                    case 0: x.select(wr.int(4))
                    case 1: x.clearSelected()
                    default: x.place(wr.int(n + 1) - (wr.int(10) == 0 ? 1 : 0))
                    }
                    let filled = x.slots.compactMap { $0 }
                    if Set(filled).count != filled.count || filled.contains(where: { !(0..<n).contains($0) }) { walkOK = false }
                    if let code = x.code, !DecoderRules.isValid(code, colors: n) { walkOK = false }
                }
            }
        }
        check(walkOK, "random walks with 4, 5, 7 and 8 colours (incl. out-of-range probes): draft stays legal")

        // --- Knob / wheel maths for 4...8 detents ---
        // CHANGED 2026-11-10: a hostile count clamps to 4 detents (90 degrees, wrap(-1) == 3); it was 6 (60, 5).
        check(DecoderWheel.step(count: 6) == 60 && DecoderWheel.step(count: 8) == 45 && abs(DecoderWheel.step(count: 7) - 360.0 / 7) < 1e-12
              && DecoderWheel.step(count: 4) == 90 && DecoderWheel.step(count: 5) == 72
              && DecoderWheel.step(count: 0) == 90 && DecoderWheel.step(count: 99) == 45 && DecoderWheel.stepDegrees == 60 && DecoderWheel.detents == 6, "step per detent, sanitised")
        check(DecoderWheel.wrap(-1, count: 7) == 6 && DecoderWheel.wrap(7, count: 7) == 0 && DecoderWheel.wrap(-1, count: 8) == 7 && DecoderWheel.wrap(8, count: 8) == 0
              && DecoderWheel.wrap(-1, count: 4) == 3 && DecoderWheel.wrap(4, count: 4) == 0 && DecoderWheel.wrap(-1, count: 5) == 4 && DecoderWheel.wrap(9, count: 5) == 4
              && (0..<8).contains(DecoderWheel.wrap(Int.min, count: 8)) && (0..<7).contains(DecoderWheel.wrap(Int.max, count: 7)) && DecoderWheel.wrap(-1, count: 0) == 3, "wrap for 4...8 detents and extremes")
        var nearestOK = true
        for n in 4...8 { for k in -20...20 { for t in 0..<n {
            let r = DecoderWheel.nearest(current: k, target: t, count: n)
            if DecoderWheel.wrap(r, count: n) != t || abs(r - k) > n / 2 { nearestOK = false }
        } } }
        check(nearestOK, "nearest(): reaches the target by the shortest way for 4...8 detents")
        check(DecoderWheel.nearest(current: 0, target: 2, count: 4) == 2 && DecoderWheel.nearest(current: 0, target: 3, count: 4) == -1
              && DecoderWheel.nearest(current: 0, target: 3, count: 5) == -2 && DecoderWheel.nearest(current: 0, target: 2, count: 5) == 2, "nearest with 4 (tie clockwise) and 5 detents")
        check(DecoderWheel.nearest(current: 0, target: 4, count: 8) == 4 && DecoderWheel.nearest(current: 4, target: 0, count: 8) == 8 && DecoderWheel.nearest(current: 0, target: 5, count: 8) == -3
              && DecoderWheel.nearest(current: 0, target: 4, count: 7) == -3 && DecoderWheel.nearest(current: 0, target: 3, count: 7) == 3, "ties go clockwise (even), odd counts have no tie")
        var roundTrip = true, pointer = true, sweepOK = true
        for n in 4...8 {
            for k in -12...12 {
                let rot = DecoderWheel.rotation(forPosition: k, count: n)
                if abs(DecoderWheel.position(forRotation: rot, count: n) - Double(k)) > 1e-9 { roundTrip = false }
                if DecoderWheel.segment(atScreenAngle: 0, rotation: rot, count: n) != DecoderWheel.wrap(k, count: n) { pointer = false }
            }
            var kk = 0, flips = 0, rr = 0.0
            while rr > -360 { rr -= 0.5; let nk = DecoderWheel.resolve(position: DecoderWheel.position(forRotation: rr, count: n), current: kk); if nk != kk { flips += 1 }; kk = nk }
            if flips != n || DecoderWheel.wrap(kk, count: n) != 0 { sweepOK = false }
        }
        check(roundTrip, "rotation <-> position round trip for 4...8")
        check(pointer, "pointer consistency for 4...8")
        check(sweepOK, "a full sweep crosses exactly n detents for n = 4...8")
        check(DecoderWheel.resolve(position: 1e300, current: 3) == 3 && DecoderWheel.resolve(position: -1e300, current: 3) == 3
              && DecoderWheel.segment(atScreenAngle: 1e300, rotation: 0, count: 8) == 0, "absurd positions cannot spin forever or trap")

        // --- Infinite: tiers, levels, ids ---
        // CHANGED 2026-11-10 (Josu, decoder-difficulty-hints): a new colour every 10 levels, at most 6:
        // 1-10 -> 4, 11-20 -> 5, 21+ -> 6. Build 865 had tiers of 20 up to 8 (previousColorCount);
        // the first release had 1-15 -> 6, 16-30 -> 7, 31+ -> 8 (legacyColorCount). Both only for migration.
        let tiers: [(Int, Int)] = [(1, 4), (2, 4), (9, 4), (10, 4), (11, 5), (12, 5), (19, 5), (20, 5), (21, 6), (22, 6), (30, 6), (31, 6),
                                   (41, 6), (61, 6), (81, 6), (100, 6), (999_999, 6), (DecoderInfinite.maxLevel, 6), (Int.max, 6)]
        check(tiers.allSatisfy { DecoderInfinite.colorCount(level: $0.0) == $0.1 }, "colours per level: 1-10 -> 4, 11-20 -> 5, 21+ -> 6")
        var tierScan = true
        for level in 1...400 {
            let expected = level <= 10 ? 4 : level <= 20 ? 5 : 6
            if DecoderInfinite.colorCount(level: level) != expected { tierScan = false }
            if DecoderInfinite.colorCount(level: level) > 6 { tierScan = false }
        }
        check(tierScan && DecoderInfinite.tierSize == 10 && DecoderInfinite.maxColors == 6, "every level 1...400 is in the right tier and never above 6 colours")
        var neverAbove6 = true
        var probeLevel = 1
        while probeLevel < DecoderInfinite.maxLevel { if DecoderInfinite.colorCount(level: probeLevel) > 6 { neverAbove6 = false }; probeLevel = probeLevel &* 3 &+ 1 }
        check(neverAbove6, "no Infinite level up to the cap uses 7 or 8 colours")
        // Attempts: 1-30 -> 7, 31-40 -> 6, 41+ -> 5 (pure, clamped).
        let budgets: [(Int, Int)] = [(1, 7), (10, 7), (11, 7), (20, 7), (21, 7), (30, 7), (31, 6), (35, 6), (40, 6), (41, 5), (42, 5), (100, 5),
                                     (DecoderInfinite.maxLevel, 5), (Int.max, 5), (0, 7), (-5, 7), (Int.min, 7)]
        check(budgets.allSatisfy { DecoderInfinite.maxAttempts(level: $0.0) == $0.1 }, "attempts per level: 1-30 -> 7, 31-40 -> 6, 41+ -> 5")
        var budgetScan = true
        for level in 1...400 {
            let expected = level <= 30 ? 7 : level <= 40 ? 6 : 5
            if DecoderInfinite.maxAttempts(level: level) != expected { budgetScan = false }
            if level > 1 && DecoderInfinite.maxAttempts(level: level) > DecoderInfinite.maxAttempts(level: level - 1) { budgetScan = false }
            if level > 1 && DecoderInfinite.colorCount(level: level) < DecoderInfinite.colorCount(level: level - 1) { budgetScan = false }
        }
        check(budgetScan, "difficulty is monotone: colours never drop and attempts never grow with the level")
        let prev865: [(Int, Int)] = [(1, 4), (20, 4), (21, 5), (40, 5), (41, 6), (60, 6), (61, 7), (80, 7), (81, 8), (Int.max, 8)]
        check(prev865.allSatisfy { DecoderInfinite.previousColorCount(level: $0.0) == $0.1 }, "build-865 tiers (20 levels, up to 8) kept only to document the migration")
        check(DecoderInfinite.colorCount(level: 0) == 4 && DecoderInfinite.colorCount(level: -7) == 4 && DecoderInfinite.colorCount(level: Int.min) == 4, "level <= 0 behaves as level 1")
        let legacyTiers: [(Int, Int)] = [(1, 6), (15, 6), (16, 7), (30, 7), (31, 8), (500, 8), (0, 6), (Int.max, 8)]
        check(legacyTiers.allSatisfy { DecoderInfinite.legacyColorCount(level: $0.0) == $0.1 }, "legacy tiers (first release) kept only to recognise old rounds")
        // Every Int constant of the ladder fits Int32 (KaffaWatch arm64_32).
        check([DecoderInfinite.maxLevel, DecoderInfinite.maxSerial, DecoderInfinite.maxElapsed, DecoderInfinite.tierSize, DecoderInfinite.maxColors,
               DecoderInfinite.attemptsTier1Last, DecoderInfinite.attemptsTier2Last, DecoderRules.minAttempts,
               DecoderInfinite.legacyTier1Last, DecoderInfinite.legacyTier2Last].allSatisfy { $0 >= 0 && $0 <= Int(Int32.max) }, "ladder constants fit Int32")
        check(DecoderInfinite.clampPick(5, best: 9) == 5 && DecoderInfinite.clampPick(10, best: 9) == 9 && DecoderInfinite.clampPick(0, best: 9) == 1
              && DecoderInfinite.clampPick(Int.min, best: 9) == 1 && DecoderInfinite.clampPick(Int.max, best: Int.max) == DecoderInfinite.maxLevel
              && DecoderInfinite.clampPick(3, best: -4) == 1, "clampPick keeps the selector inside 1...best")
        check(DecoderInfinite.nextLevel(1) == 2 && DecoderInfinite.nextLevel(15) == 16 && DecoderInfinite.nextLevel(30) == 31 && DecoderInfinite.nextLevel(0) == 2 && DecoderInfinite.nextLevel(-9) == 2, "nextLevel")
        check(DecoderInfinite.nextLevel(DecoderInfinite.maxLevel) == DecoderInfinite.maxLevel && DecoderInfinite.nextLevel(Int.max) == DecoderInfinite.maxLevel
              && DecoderInfinite.nextLevel(DecoderInfinite.maxLevel - 1) == DecoderInfinite.maxLevel, "nextLevel saturates, never overflows")
        check(DecoderInfinite.nextSerial(DecoderInfinite.maxSerial) == 1 && DecoderInfinite.nextSerial(Int.max) == 1 && DecoderInfinite.nextSerial(-5) == 1 && DecoderInfinite.nextSerial(7) == 8, "nextSerial wraps safely")
        check(DecoderInfinite.gameID(level: 5, serial: 3) == "decinf-5-3" && DecoderInfinite.gameID(level: 0, serial: 1) == "decinf-1-1" && DecoderInfinite.isInfiniteID("decinf-5-3")
              && !DecoderGame.isCurrentID("decinf-5-3") && !DecoderGame.isCurrentID("en-decinf-5-3") && !DecoderInfinite.isInfiniteID(es.id) && !DecoderInfinite.isInfiniteID(en.id), "infinite ids are their own namespace")
        let fr = DecoderInfiniteRound.fresh(level: 61, serial: 4, seed: 99)
        check(fr.game.colorCount == 6 && fr.draft.colorCount == 6 && fr.game.maxAttempts == 5 && DecoderRules.isValid(fr.game.secret, colors: 6) && fr.id == "decinf-61-4" && !fr.isCleared && fr.game.guesses.isEmpty, "fresh round at level 61: 6 colours, 5 attempts")
        check(DecoderInfiniteRound.fresh(level: 81, serial: 1, seed: 5).game.colorCount == 6 && DecoderInfiniteRound.fresh(level: -3, serial: 1, seed: 5).level == 1
              && DecoderInfiniteRound.fresh(level: Int.max, serial: 1, seed: 5).level == DecoderInfinite.maxLevel
              && DecoderInfiniteRound.fresh(level: Int.max, serial: 1, seed: 5).game.colorCount == 6, "fresh round: level 81 and the cap -> 6 colours; levels clamped")
        let freshPairs: [(Int, Int, Int)] = [(1, 4, 7), (10, 4, 7), (11, 5, 7), (20, 5, 7), (21, 6, 7), (30, 6, 7), (31, 6, 6), (40, 6, 6), (41, 6, 5), (100, 6, 5), (DecoderInfinite.maxLevel, 6, 5)]
        check(freshPairs.allSatisfy { let r = DecoderInfiniteRound.fresh(level: $0.0, serial: 1, seed: 9)
            return r.game.colorCount == $0.1 && r.draft.colorCount == $0.1 && r.game.maxAttempts == $0.2 && DecoderRules.isValid(r.game.secret, colors: $0.1) }, "fresh rounds at 1/10/11/20/21/30/31/40/41/100/max: palette and attempts of their level")
        // A 5-attempt round is lost on its 5th wrong row; a 6-attempt one on its 6th.
        var five = DecoderInfiniteRound.fresh(level: 45, serial: 1, seed: 11).game
        let fiveWrong = DecoderRules.allCodes(colors: 6).first { $0 != five.secret }!
        for _ in 0..<4 { five.submit(fiveWrong) }
        let fourLeft = five.status == .playing && five.attemptsLeft == 1
        five.submit(fiveWrong)
        check(fourLeft && five.status == .lost && five.attemptsUsed == 5 && five.submit(five.secret) == .finished, "level 45: lost after 5 wrong rows, then immutable")
        var six = DecoderInfiniteRound.fresh(level: 33, serial: 1, seed: 12).game
        for _ in 0..<5 { six.submit(DecoderRules.allCodes(colors: 6).first { $0 != six.secret }!) }
        let sixAlive = six.status == .playing
        six.submit(six.secret)
        check(sixAlive && six.status == .won && six.attemptsUsed == 6, "level 33: the 6th (last) row can still win")
        check(DecoderGame(id: "a", secret: [0,1,2,3], maxAttempts: 99).maxAttempts == 7 && DecoderGame(id: "a", secret: [0,1,2,3], maxAttempts: -1).maxAttempts == 5
              && DecoderGame(id: "a", secret: [0,1,2,3]).maxAttempts == 7 && DecoderGame.make(seed: 3, spanish: true).maxAttempts == 7, "game budget sanitised to 5...7; daily keeps 7")
        // Restoring more rows than the budget keeps only the legal prefix up to the loss.
        let over = DecoderGame(id: "o", secret: [0,1,2,3], guesses: Array(repeating: [3,2,1,0], count: 7), maxAttempts: 5)
        check(over.guesses.count == 5 && over.status == .lost, "restoring 7 rows into a 5-attempt game keeps 5 and is lost")
        let fr4 = DecoderInfiniteRound.fresh(level: 1, serial: 1, seed: 5)
        check(fr4.game.colorCount == 4 && Set(fr4.game.secret) == [0,1,2,3] && fr4.isIdle, "fresh round at level 1: 4 colours, the code is a permutation, nothing in progress")
        var frBusy = fr4; var busyDraft = DecoderDraft(colorCount: 4); busyDraft.place(2); frBusy.draft = busyDraft
        var frPlayed = fr4; frPlayed.game.submit(DecoderRules.allCodes(colors: 4).first { $0 != fr4.game.secret }!)
        var frWon = fr4; frWon.game.submit(fr4.game.secret)
        check(!frBusy.isIdle && !frPlayed.isIdle && frWon.isIdle, "isIdle: a placed colour or a played row means in progress; a finished round is idle")

        // --- Per-key hints (the lit lip under each key) ---
        func hints(_ s: [Int], _ g: [Int], _ n: Int = 6) -> [DecoderSlotHint]? { DecoderRules.slotHints(secret: s, guess: g, colors: n) }
        check(hints([0,1,2,3], [0,1,2,3])! == [.exact, .exact, .exact, .exact], "hints: solved row is all exact")
        check(hints([0,1,2,3], [3,2,1,0])! == [.present, .present, .present, .present], "hints: reversed row is all present")
        check(hints([0,1,2,3], [0,4,5,1])! == [.exact, .absent, .absent, .present], "hints: exact / absent / absent / present, in guess order")
        check(hints([0,1,2,3], [4,5,3,2])! == [.absent, .absent, .present, .present] && hints([5,4,3,2], [5,0,1,2])! == [.exact, .absent, .absent, .exact], "hints: mixed rows")
        check(hints([0,1,2,3], [4,5,6,7], 8)! == [.absent, .absent, .absent, .absent] && hints([6,1,2,7], [6,1,7,2], 8)! == [.exact, .exact, .present, .present], "hints with 8 colours")
        check(hints([3,1,0,2], [0,1,2,3], 4)! == [.present, .exact, .present, .present], "hints with 4 colours: never absent")
        // Invalid input: same contract as score() -> nil, never a partial array.
        check(hints([0,1,2,3], [0,0,1,2]) == nil && hints([0,0,1,2], [0,1,2,3]) == nil && hints([0,1,2], [0,1,2,3]) == nil && hints([0,1,2,3], []) == nil
              && hints([0,1,2,3], [0,1,2,6]) == nil && hints([0,1,2,6], [0,1,2,3]) == nil && hints([0,1,2,3], [0,1,2,-1]) == nil
              && hints([0,1,2,3], [0,1,2,4], 4) == nil && hints([0,1,2,3], [0,1,2,3,4]) == nil, "hints: repeated / short / long / out-of-range input gives nil")
        check(hints([0,1,2,3], [3,2,1,0], Int.min)! == [.present, .present, .present, .present] && hints([0,1,2,7], [7,0,1,2], Int.max)! == [.present, .present, .present, .present],
              "hints: hostile colour counts are clamped, never crash")
        // Exhaustive for 4, 5, 6, 7 colours and strided for 8: each hint matches its definition and the totals match score().
        for n in 4...8 {
            let all = DecoderRules.allCodes(colors: n)
            let stride = n == 8 ? 7 : 1
            var good = true; var kinds = Set<DecoderSlotHint>(); var si = 0
            while si < all.count {
                let s = all[si]; si += stride
                for g in all {
                    guard let h = DecoderRules.slotHints(secret: s, guess: g, colors: n), let f = DecoderRules.score(secret: s, guess: g, colors: n), h.count == 4 else { good = false; continue }
                    for i in 0..<4 {
                        let want: DecoderSlotHint = g[i] == s[i] ? .exact : (s.contains(g[i]) ? .present : .absent)
                        if h[i] != want { good = false }
                        kinds.insert(h[i])
                    }
                    if h.filter({ $0 == .exact }).count != f.exact || h.filter({ $0 == .present }).count != f.misplaced { good = false }
                    if (h == [.exact, .exact, .exact, .exact]) != (s == g) { good = false }
                }
            }
            check(good, "\(n) colours: every per-key hint is right and exact/present counts equal the aggregate feedback")
            check(kinds.contains(.absent) == (n > 4) && kinds.contains(.exact) && kinds.contains(.present), "\(n) colours: 'absent' appears only when there are spare colours")
        }
        var hintGame = DecoderGame(id: "h", secret: [0,1,2,3])
        hintGame.submit([0,4,5,1]); hintGame.submit([9,9,9,9]); hintGame.submit([3,2,1,0])
        check(hintGame.slotHints == [[.exact, .absent, .absent, .present], [.present, .present, .present, .present]] && hintGame.slotHints.count == hintGame.guesses.count
              && hintGame.slotHints.count == hintGame.feedbacks.count, "game.slotHints: one row per accepted guess, aligned with guesses and feedbacks")
        check(DecoderGame(id: "h0", secret: [0,0,1,2]).slotHints.isEmpty && DecoderGame(id: "h1", secret: [0,1,2,3]).slotHints.isEmpty, "game.slotHints: inert / untouched games have none")

        // --- Hint button (2026-11-10): lips are OFF until asked for, one row (the LAST) per press ---
        var hg = DecoderGame(id: "dec2-hint", secret: [0,1,2,3])
        check(hg.revealHint() == .noRow && hg.revealedHintRows.isEmpty && !hg.canRevealHint, "hint: nothing to reveal before the first row")
        hg.submit([0,4,5,1]); hg.submit([3,2,1,0])
        check(hg.visibleSlotHints(row: 0) == nil && hg.visibleSlotHints(row: 1) == nil && !hg.isHintRevealed(row: 1) && hg.canRevealHint, "hint: played rows start with the lips off")
        check(hg.revealHint() == .revealed(row: 1) && hg.visibleSlotHints(row: 1) == [.present, .present, .present, .present]
              && hg.visibleSlotHints(row: 0) == nil && hg.revealedHintRows == [1], "hint: one press lights ONLY the last submitted row")
        check(hg.revealHint() == .alreadyRevealed(row: 1) && hg.revealedHintRows == [1] && !hg.canRevealHint, "hint: pressing again changes nothing")
        hg.submit([0,1,5,4])
        check(hg.canRevealHint && hg.visibleSlotHints(row: 2) == nil && hg.isHintRevealed(row: 1), "hint: a new row starts off; the earlier reveal stays on")
        check(hg.revealHint() == .revealed(row: 2) && hg.revealedHintRows == [1, 2] && hg.visibleSlotHints(row: 2) == [.exact, .exact, .absent, .absent]
              && hg.visibleSlotHints(row: 0) == nil, "hint: the next press reveals the new last row only (row 0 never asked for)")
        check(hg.visibleSlotHints(row: -1) == nil && hg.visibleSlotHints(row: 99) == nil && !hg.isHintRevealed(row: 99), "hint: out-of-range rows have no visible hint")
        var hgDone = hg; hgDone.submit([0,1,2,3])
        check(hgDone.status == .won && hgDone.revealHint() == .finished && hgDone.revealedHintRows == [1, 2] && !hgDone.canRevealHint, "hint: refused once the game is over; reveals are kept")
        var inertHint = DecoderGame(id: "x", secret: [0,0,1,2]); check(inertHint.revealHint() == .finished, "hint: inert game cannot reveal")
        // Restoring: reveals only for restored rows; junk ignored; missing = all off.
        let hr = DecoderGame(id: "dec2-hint", secret: [0,1,2,3], guesses: [[0,4,5,1], [3,2,1,0]], revealedHints: [1, 1, 7, -3, Int.max, Int.min])
        check(hr.revealedHintRows == [1] && hr.visibleSlotHints(row: 1) != nil && hr.visibleSlotHints(row: 0) == nil, "hint restore: duplicates / out-of-range rows dropped")
        check(DecoderGame(id: "dec2-hint", secret: [0,1,2,3], guesses: [[0,4,5,1]]).revealedHintRows.isEmpty, "hint restore: no field = every lip off")
        check(DecoderGame(id: "dec2-hint", secret: [0,0,1,2], guesses: [[0,4,5,1]], revealedHints: [0]).revealedHintRows.isEmpty, "hint restore: inert game keeps nothing")
        var hm = hr; hm.mergeRevealed([0, 5]); check(hm.revealedHintRows == [0, 1], "hint merge: union, rows that do not exist ignored")
        // Pilots (aggregate feedback) are independent of the hint: always available.
        check(hg.feedbacks.count == hg.guesses.count && hr.feedbacks.count == 2, "pilots: aggregate feedback exists for every played row, revealed or not")
        // Equality includes reveals (views compare stored vs live state).
        check(hr != DecoderGame(id: "dec2-hint", secret: [0,1,2,3], guesses: [[0,4,5,1], [3,2,1,0]]), "hint reveals are part of the game state")

        // Daily store: reveals persist per id in their own key; old data (no key) loads with lips off.
        let hdName = "decoder-hints-\(UUID().uuidString)"
        let hd = UserDefaults(suiteName: hdName)!
        defer { hd.removePersistentDomain(forName: hdName) }
        let hs = DecoderStore(defaults: hd)
        var dh = DecoderGame.make(seed: 4321, spanish: true)
        let dhWrong = DecoderRules.allCodes().filter { $0 != dh.secret }
        dh.submit(dhWrong[0]); hs.save(dh)
        check(hd.object(forKey: DecoderStore.hintsKey) == nil && hs.load(id: dh.id, secret: dh.secret).revealedHintRows.isEmpty, "daily: no reveal = hints key never written, old blobs load with lips off")
        dh.revealHint(); hs.save(dh)
        check(hs.load(id: dh.id, secret: dh.secret).revealedHintRows == [0] && hs.load(id: dh.id, secret: dh.secret) == dh, "daily: a revealed hint survives reopening")
        check((hd.dictionary(forKey: DecoderStore.sessionsKey) as? [String: [[Int]]])?[dh.id] == [dhWrong[0]], "daily: the sessions blob keeps its exact v2 shape (guesses only)")
        let stale = DecoderGame(id: dh.id, secret: dh.secret, guesses: dh.guesses)   // a copy that never saw the reveal
        hs.save(stale)
        check(hs.load(id: dh.id, secret: dh.secret).revealedHintRows == [0], "daily: saving a copy without the reveal never switches a lip off")
        dh.submit(dhWrong[1]); hs.save(dh)
        check(hs.load(id: dh.id, secret: dh.secret).revealedHintRows == [0] && hs.load(id: dh.id, secret: dh.secret).visibleSlotHints(row: 1) == nil, "daily: the new row starts off after reopening")
        hd.set("garbage", forKey: DecoderStore.hintsKey)
        check(hs.load(id: dh.id, secret: dh.secret).revealedHintRows.isEmpty && hs.load(id: dh.id, secret: dh.secret).guesses.count == 2, "daily: corrupt hints payload = lips off, board intact")
        hd.set([dh.id: [0, 99, -1]], forKey: DecoderStore.hintsKey)
        check(hs.load(id: dh.id, secret: dh.secret).revealedHintRows == [0], "daily: stored rows beyond the board are ignored")
        hs.clear(id: dh.id)
        check((hd.dictionary(forKey: DecoderStore.hintsKey) as? [String: [Int]])?[dh.id] == nil && hs.load(id: dh.id, secret: dh.secret).revealedHintRows.isEmpty, "daily: clearing a board clears its reveals")
        for i in 0..<70 { var x = DecoderGame(id: "dec2-hb\(i)", secret: [0,1,2,3]); x.submit([5,4,3,2]); x.revealHint(); hs.save(x) }
        check((hd.dictionary(forKey: DecoderStore.hintsKey) as? [String: [Int]])?.count == DecoderStore.keepSessions, "daily: reveals are pruned together with their sessions")
        hs.wipeAll()
        check(hd.object(forKey: DecoderStore.hintsKey) == nil, "daily: wipeAll clears the hints key")

        // --- Infinite: persistence flows ---
        var suitesToClean: [String] = []
        func makeDefaults() -> UserDefaults {
            let name = "decoder-inf-\(UUID().uuidString)"
            suitesToClean.append(name)
            return UserDefaults(suiteName: name)!
        }
        defer { for name in suitesToClean { UserDefaults.standard.removePersistentDomain(forName: name) } }
        var seedCounter: UInt64 = 1000
        func nextSeed() -> UInt64 { seedCounter += 17; return seedCounter }
        func wrong(_ secret: [Int], _ n: Int, _ variant: Int = 0) -> [Int] {
            DecoderRules.allCodes(colors: n).filter { $0 != secret }[variant]
        }
        /// A blob exactly as the FIRST release wrote it ("v" 1: no "best", no "colors").
        func stateBlob(level: Int, roundLevel: Int? = nil, serial: Int = 5, seed: String = "77", guesses: [[Int]] = [], cleared: Bool = false) -> [String: Any] {
            ["v": 1, "level": level, "serial": serial, "roundLevel": roundLevel ?? level, "seed": seed, "guesses": guesses,
             "draft": [-1, -1, -1, -1], "selected": 0, "wheel": 0, "elapsed": 0, "cleared": cleared]
        }
        /// A blob as the current release writes it ("v" 2: with "best" and "colors").
        func stateBlobV2(level: Int, best: Int, roundLevel: Int? = nil, serial: Int = 5, seed: String = "77", guesses: [[Int]] = [], cleared: Bool = false, colors: Int? = nil) -> [String: Any] {
            var blob = stateBlob(level: level, roundLevel: roundLevel, serial: serial, seed: seed, guesses: guesses, cleared: cleared)
            blob["v"] = 2; blob["best"] = best
            blob["colors"] = colors ?? DecoderInfinite.colorCount(level: roundLevel ?? level)
            return blob
        }

        let infDefaults = makeDefaults()
        // Snapshot of every daily/legacy key, to prove Infinite never touches them.
        let daily = DecoderStore(defaults: infDefaults)
        var dg = DecoderGame.make(seed: 31337, spanish: true); dg.submit(wrong(dg.secret, 6)); daily.save(dg)
        var dgLost = DecoderGame.make(seed: 31338, spanish: false); for _ in 0..<7 { dgLost.submit(wrong(dgLost.secret, 6)) }; daily.save(dgLost); daily.recordResultIfNew(dgLost)
        infDefaults.set(["dec-9": [[0,0,1,1]]], forKey: "newsraider.decoder.sessions.v1")
        infDefaults.set(["dec-9": 0], forKey: "newsraider.decoder.results.v1")
        infDefaults.set("keep-me", forKey: "newsraider.puzzleSnapshots.v1")
        infDefaults.set(["x": 1], forKey: "newsraider.puzzleFullDays")
        func dailySnapshot() -> [String: String] {
            var out: [String: String] = [:]
            for key in [DecoderStore.sessionsKey, DecoderStore.orderKey, DecoderStore.resultsKey] + DecoderStore.legacyV1Keys + ["newsraider.puzzleSnapshots.v1", "newsraider.puzzleFullDays"] {
                // Order-independent: describing a bridged dictionary is not stable.
                if let value = infDefaults.object(forKey: key),
                   JSONSerialization.isValidJSONObject([value]),
                   let data = try? JSONSerialization.data(withJSONObject: [value], options: [.sortedKeys]) {
                    out[key] = String(decoding: data, as: UTF8.self)
                } else {
                    out[key] = "\(String(describing: infDefaults.object(forKey: key)))"
                }
            }
            return out
        }
        let dailyBefore = dailySnapshot()
        let dailyStatsBefore = daily.stats

        let inf = DecoderInfiniteStore(defaults: infDefaults)
        check(infDefaults.object(forKey: DecoderInfiniteStore.key) == nil, "nothing is written until Infinite is opened")
        let s0 = inf.load(newSeed: nextSeed)
        // CHANGED 2026-11-10: level 1 deals 4 colours (was 6); the session also carries `best`.
        check(s0.level == 1 && s0.best == 1 && s0.round.level == 1 && s0.round.game.colorCount == 4 && s0.round.game.guesses.isEmpty && !s0.round.isCleared
              && DecoderInfinite.isInfiniteID(s0.round.id) && infDefaults.dictionary(forKey: DecoderInfiniteStore.key) != nil, "first load: level 1, best 1, 4 colours, stored")
        let firstBlob = infDefaults.dictionary(forKey: DecoderInfiniteStore.key) ?? [:]
        check(firstBlob["v"] as? Int == 2 && firstBlob["best"] as? Int == 1 && firstBlob["colors"] as? Int == 4 && firstBlob["level"] as? Int == 1, "the blob stores v2, best and the dealt palette")
        let seedAfterFirst = seedCounter
        check(DecoderInfiniteStore(defaults: infDefaults).load(newSeed: nextSeed) == s0 && seedCounter == seedAfterFirst, "reloading never re-rolls the round")

        // Reopen the SAME challenge halfway: guesses, draft, selected slot, knob, elapsed.
        var r = s0.round
        // (4-colour round now: the draft uses colours 3 and 2, and knob position 9 wraps to 1 of 4.)
        let w1 = wrong(r.game.secret, 4, 0), w2 = wrong(r.game.secret, 4, 5)
        r.game.submit(w1); r.game.submit(w2)
        var half = DecoderDraft(colorCount: 4); half.place(3); half.place(2); half.select(3)
        r.draft = half; r.wheel = 9; r.elapsed = 123
        let saveHalf = inf.save(r, newSeed: nextSeed)
        check(saveHalf.outcome == .saved && saveHalf.session.level == 1 && saveHalf.session.best == 1, "mid-round save")
        let reopened = DecoderInfiniteStore(defaults: infDefaults).load(newSeed: nextSeed)
        check(reopened.round.id == r.id && reopened.round.seed == r.seed && reopened.round.game.secret == r.game.secret
              && reopened.round.game.guesses == [w1, w2] && reopened.round.draft.rawSlots == [3, 2, -1, -1] && reopened.round.draft.selected == 3
              && reopened.round.wheel == 1 && reopened.round.elapsed == 123 && reopened.level == 1 && seedCounter == seedAfterFirst, "reopening restores the same challenge mid-way (guesses, draft, slot, knob, time)")
        check(!reopened.round.isIdle && inf.start(level: 1, expectedID: r.id, newSeed: nextSeed) == nil
              && DecoderInfiniteStore(defaults: infDefaults).load(newSeed: nextSeed) == reopened, "the level selector cannot re-roll a round in progress")

        // Stale and forged saves.
        let olderCopy = s0.round                       // a view that never saw w1/w2
        check(inf.save(olderCopy, newSeed: nextSeed).outcome == .stale && DecoderInfiniteStore(defaults: infDefaults).load(newSeed: nextSeed).round.game.guesses == [w1, w2], "a save from behind cannot rewind the stored guesses")
        let otherSeed = DecoderInfiniteRound(level: r.level, serial: r.serial, seed: r.seed &+ 1, game: r.game, draft: r.draft, wheel: 0, elapsed: 0, isCleared: false)
        check(inf.save(otherSeed, newSeed: nextSeed).outcome == .stale, "same id but another seed is stale")
        let fake = DecoderRules.allCodes(colors: 4).first { $0 != r.game.secret && $0 != w1 && $0 != w2 }!
        var forged = r
        forged.game = DecoderGame(id: r.id, secret: fake, guesses: [w1, w2, fake], colorCount: 4)   // looks like a win for ITS secret
        let forgedSave = inf.save(forged, newSeed: nextSeed)
        check(forgedSave.outcome == .saved && forgedSave.session.level == 1 && !forgedSave.session.round.isCleared && forgedSave.session.round.game.secret == r.game.secret
              && forgedSave.session.round.game.status == .playing, "the secret is recomputed from the stored seed: a forged win cannot advance")
        r = forgedSave.session.round                   // the forged guess was just a (wrong) legal row: continue from the stored truth
        var elapsedHigh = r; elapsedHigh.elapsed = Int.max
        check(inf.save(elapsedHigh, newSeed: nextSeed).session.round.elapsed == DecoderInfinite.maxElapsed, "elapsed is clamped")
        var elapsedLow = r; elapsedLow.elapsed = -50
        check(inf.save(elapsedLow, newSeed: nextSeed).session.round.elapsed == DecoderInfinite.maxElapsed, "elapsed never goes backwards within a round")

        // Winning: level advances exactly once, atomically, and survives closing right away.
        var winning = inf.load(newSeed: nextSeed).round
        winning.game.submit(winning.game.secret)
        winning.draft = DecoderDraft(colorCount: 4)
        let won1 = inf.save(winning, newSeed: nextSeed)
        check(won1.outcome == .cleared && won1.session.level == 2 && won1.session.best == 2 && won1.session.round.isCleared && won1.session.round.game.status == .won && won1.session.round.level == 1, "win: cleared, level 2, best 2")
        let afterWin = DecoderInfiniteStore(defaults: infDefaults).load(newSeed: nextSeed)
        check(afterWin.level == 2 && afterWin.best == 2 && afterWin.round.isCleared && afterWin.round.game.status == .won && afterWin.round.id == winning.id && afterWin.round.isIdle, "closing right after the win keeps level 2, best 2 and the won board")
        var winCount = 0
        for _ in 0..<10 { if inf.save(winning, newSeed: nextSeed).outcome == .cleared { winCount += 1 } }
        check(winCount == 0 && inf.load(newSeed: nextSeed).level == 2, "winning exactly once: repeated saves of the same win never advance again")
        check(inf.save(olderCopy, newSeed: nextSeed).outcome == .stale && inf.save(r, newSeed: nextSeed).outcome == .stale
              && inf.load(newSeed: nextSeed).level == 2 && inf.load(newSeed: nextSeed).round.isCleared, "an old view saving after the win cannot overwrite the advanced level")
        check(inf.retry(expectedID: winning.id, newSeed: nextSeed) == nil, "a won round cannot be 'retried'")
        check(inf.advance(expectedID: "decinf-1-999", newSeed: nextSeed) == nil, "advance with a wrong id does nothing")
        let lvl2 = inf.advance(expectedID: winning.id, newSeed: nextSeed)
        check(lvl2 != nil && lvl2!.level == 2 && lvl2!.round.level == 2 && !lvl2!.round.isCleared && lvl2!.round.game.guesses.isEmpty && lvl2!.round.serial == winning.serial + 1
              && lvl2!.round.game.secret != winning.game.secret, "advance: a fresh round of level 2 with a new code")
        check(inf.advance(expectedID: winning.id, newSeed: nextSeed) == nil && inf.load(newSeed: nextSeed).round.id == lvl2!.round.id, "advance twice: the second call is a no-op")
        check(inf.save(winning, newSeed: nextSeed).outcome == .stale && inf.load(newSeed: nextSeed).round.id == lvl2!.round.id && inf.load(newSeed: nextSeed).round.game.guesses.isEmpty, "the cleared round cannot overwrite the new one")

        // Losing: never lowers or resets the level; retry = new code, same level, only after a loss.
        var lossRound = lvl2!.round
        let lossGuess = wrong(lossRound.game.secret, 4)
        check(inf.retry(expectedID: lossRound.id, newSeed: nextSeed) == nil, "no re-roll of a round in progress")
        var lastOutcome = DecoderInfiniteSaveOutcome.stale
        for _ in 0..<7 { lossRound.game.submit(lossGuess); lastOutcome = inf.save(lossRound, newSeed: nextSeed).outcome }
        let lostState = inf.load(newSeed: nextSeed)
        check(lastOutcome == .saved && lostState.round.game.status == .lost && lostState.level == 2 && !lostState.round.isCleared, "loss: stored as lost, level stays 2")
        check(inf.advance(expectedID: lossRound.id, newSeed: nextSeed) == nil, "a lost round cannot be advanced")
        check(inf.retry(expectedID: "decinf-2-0", newSeed: nextSeed) == nil, "retry with the wrong id does nothing")
        let retried = inf.retry(expectedID: lossRound.id, newSeed: nextSeed)
        check(retried != nil && retried!.level == 2 && retried!.round.level == 2 && retried!.round.serial == lossRound.serial + 1 && retried!.round.game.guesses.isEmpty
              && retried!.round.game.secret != lossRound.game.secret && !retried!.round.isCleared, "retry: same level, new code, empty board")
        check(inf.retry(expectedID: lossRound.id, newSeed: nextSeed) == nil, "retry twice: the second call is a no-op")
        check(inf.save(lossRound, newSeed: nextSeed).outcome == .stale && inf.load(newSeed: nextSeed).round.id == retried!.round.id && inf.load(newSeed: nextSeed).level == 2, "a stale lost round cannot overwrite the retry or lower the level")
        // A retry whose seed would repeat the old code is nudged to a different one.
        let sameSeedState = makeDefaults()
        let sameSeedStore = DecoderInfiniteStore(defaults: sameSeedState)
        let a0 = sameSeedStore.load(newSeed: { 4242 }).round
        var aLost = a0; for _ in 0..<7 { aLost.game.submit(wrong(a0.game.secret, 4)) }
        _ = sameSeedStore.save(aLost, newSeed: { 4242 })
        let aRetry = sameSeedStore.retry(expectedID: a0.id, newSeed: { 4242 })
        check(aRetry != nil && aRetry!.round.game.secret != a0.game.secret, "retry never repeats the code, even if the seed source does")

        // The ladder across the NEW tiers (20/21, 40/41, 60/61, 80/81) and at very high levels.
        // CHANGED 2026-11-10: boundaries were 15/16 and 30/31 with 6/7/8 colours. Works for
        // both blob generations: a v1 blob whose palette no longer matches is re-dealt at the same level.
        func playTier(_ level: Int, expectColors n: Int, thenColors m: Int, v2: Bool = true) -> Bool {
            let d = makeDefaults()
            d.set(v2 ? stateBlobV2(level: level, best: level) : stateBlob(level: level), forKey: DecoderInfiniteStore.key)
            let st = DecoderInfiniteStore(defaults: d)
            let s = st.load(newSeed: nextSeed)
            guard s.level == level, s.best == level, s.round.level == level, s.round.game.colorCount == n,
                  s.round.game.guesses.isEmpty, DecoderRules.isValid(s.round.game.secret, colors: n) else { return false }
            var rr = s.round; rr.game.submit(rr.game.secret)
            let w = st.save(rr, newSeed: nextSeed)
            guard w.outcome == .cleared, w.session.level == DecoderInfinite.nextLevel(level), w.session.best == DecoderInfinite.nextLevel(level) else { return false }
            guard let nx = st.advance(expectedID: rr.id, newSeed: nextSeed) else { return false }
            return nx.level == DecoderInfinite.nextLevel(level) && nx.best == nx.level && nx.round.game.colorCount == m && DecoderRules.isValid(nx.round.game.secret, colors: m)
        }
        for v2 in [true, false] {
            let tag = v2 ? "v2 blob" : "v1 blob"
            // CHANGED 2026-11-10: tiers of 10 up to 6 colours (boundaries 10/11, 20/21; no 7th or 8th colour).
            check(playTier(1, expectColors: 4, thenColors: 4, v2: v2) && playTier(9, expectColors: 4, thenColors: 4, v2: v2), "\(tag): levels 1 and 9 stay on 4 colours")
            check(playTier(10, expectColors: 4, thenColors: 5, v2: v2), "\(tag): winning level 10 -> level 11 with 5 colours")
            check(playTier(11, expectColors: 5, thenColors: 5, v2: v2) && playTier(19, expectColors: 5, thenColors: 5, v2: v2), "\(tag): levels 11 and 19 use 5 colours")
            check(playTier(20, expectColors: 5, thenColors: 6, v2: v2), "\(tag): winning level 20 -> level 21 with 6 colours")
            check(playTier(21, expectColors: 6, thenColors: 6, v2: v2) && playTier(59, expectColors: 6, thenColors: 6, v2: v2), "\(tag): levels 21 and 59 use 6 colours")
            check(playTier(60, expectColors: 6, thenColors: 6, v2: v2) && playTier(80, expectColors: 6, thenColors: 6, v2: v2), "\(tag): winning 60 or 80 stays on 6 colours")
            check(playTier(81, expectColors: 6, thenColors: 6, v2: v2) && playTier(500, expectColors: 6, thenColors: 6, v2: v2) && playTier(123_456_789, expectColors: 6, thenColors: 6, v2: v2), "\(tag): level 81 and beyond: 6 colours, new codes, no seventh colour")
            check(playTier(DecoderInfinite.maxLevel - 1, expectColors: 6, thenColors: 6, v2: v2), "\(tag): the level before the cap does not overflow")
        }
        // At the cap itself nextLevel saturates, so "next" is the same level.
        let capD = makeDefaults(); capD.set(stateBlobV2(level: DecoderInfinite.maxLevel, best: DecoderInfinite.maxLevel), forKey: DecoderInfiniteStore.key)
        let capSt = DecoderInfiniteStore(defaults: capD)
        var capR = capSt.load(newSeed: nextSeed).round; capR.game.submit(capR.game.secret)
        let capW = capSt.save(capR, newSeed: nextSeed)
        check(capW.outcome == .cleared && capW.session.level == DecoderInfinite.maxLevel && capW.session.best == DecoderInfinite.maxLevel
              && capSt.advance(expectedID: capR.id, newSeed: nextSeed)?.level == DecoderInfinite.maxLevel, "levels at the cap do not overflow")

        // --- Level selector + best level -------------------------------------------------
        // best = 10, round of level 10 not begun: any level 1...10 can be started, none above.
        let pickD = makeDefaults(); pickD.set(stateBlobV2(level: 10, best: 10), forKey: DecoderInfiniteStore.key)
        let pick = DecoderInfiniteStore(defaults: pickD)
        let p0 = pick.load(newSeed: nextSeed)
        check(p0.level == 10 && p0.best == 10 && p0.round.level == 10 && p0.round.isIdle, "selector fixture: level 10, best 10, nothing in progress")
        check(pick.start(level: 11, expectedID: p0.round.id, newSeed: nextSeed) == nil && pick.start(level: 0, expectedID: p0.round.id, newSeed: nextSeed) == nil
              && pick.start(level: -3, expectedID: p0.round.id, newSeed: nextSeed) == nil && pick.start(level: Int.max, expectedID: p0.round.id, newSeed: nextSeed) == nil
              && pick.start(level: Int.min, expectedID: p0.round.id, newSeed: nextSeed) == nil && pick.load(newSeed: nextSeed) == p0, "start: a level above best (or below 1) is refused and nothing is written")
        check(pick.start(level: 3, expectedID: "decinf-10-999", newSeed: nextSeed) == nil && pick.load(newSeed: nextSeed) == p0, "start: a wrong expected id is refused")
        let p3 = pick.start(level: 3, expectedID: p0.round.id, newSeed: nextSeed)
        check(p3 != nil && p3!.level == 3 && p3!.best == 10 && p3!.round.level == 3 && p3!.round.serial == p0.round.serial + 1 && p3!.round.game.guesses.isEmpty
              && p3!.round.game.colorCount == 4 && !p3!.round.isCleared && DecoderInfiniteStore(defaults: pickD).load(newSeed: nextSeed) == p3!, "start level 3 (<= best): new round, best untouched, stored")
        check(pick.start(level: 5, expectedID: p0.round.id, newSeed: nextSeed) == nil, "start: the previous round's id is stale after a start")
        // A fresh, untouched round may still be swapped for another level (it is not in progress).
        let p7 = pick.start(level: 7, expectedID: p3!.round.id, newSeed: nextSeed)
        check(p7 != nil && p7!.level == 7 && p7!.best == 10 && p7!.round.serial == p3!.round.serial + 1, "start again before playing: allowed, best untouched")
        // Starting the SAME level again deals a different code.
        let p7b = pick.start(level: 7, expectedID: p7!.round.id, newSeed: { p7!.round.seed })
        check(p7b != nil && p7b!.round.game.secret != p7!.round.game.secret && p7b!.round.level == 7, "start the same level: a NEW code even if the seed source repeats")
        // Once a row is played the selector is locked until the round ends.
        var busy = p7b!.round; busy.game.submit(wrong(busy.game.secret, 4))
        check(pick.save(busy, newSeed: nextSeed).outcome == .saved && pick.start(level: 2, expectedID: busy.id, newSeed: nextSeed) == nil
              && pick.load(newSeed: nextSeed).round.game.guesses.count == 1, "start: refused while a game is in progress")
        // A placed colour (no row yet) also counts as in progress.
        let draftD = makeDefaults(); draftD.set(stateBlobV2(level: 6, best: 9), forKey: DecoderInfiniteStore.key)
        let draftSt = DecoderInfiniteStore(defaults: draftD)
        var dr = draftSt.load(newSeed: nextSeed).round; var drDraft = DecoderDraft(colorCount: 4); drDraft.place(1); dr.draft = drDraft
        check(draftSt.save(dr, newSeed: nextSeed).outcome == .saved && draftSt.start(level: 2, expectedID: dr.id, newSeed: nextSeed) == nil, "start: refused while the row has a colour in it")
        // Winning a LOWER level: best does not move, nothing is farmed, the proposal is the next level.
        busy.game.submit(busy.game.secret)
        let lowWin = pick.save(busy, newSeed: nextSeed)
        check(lowWin.outcome == .cleared && lowWin.session.level == 8 && lowWin.session.best == 10 && lowWin.session.round.isCleared, "winning level 7 with best 10: proposal 8, best still 10")
        var farm = 0
        for _ in 0..<10 { if pick.save(busy, newSeed: nextSeed).outcome != .stale { farm += 1 } }
        check(farm == 0 && pick.load(newSeed: nextSeed).best == 10, "re-saving a won lower level never changes best")
        // Replay level 1 five times: best stays 10.
        var replayID = busy.id; var replayOK = true
        for _ in 0..<5 {
            guard let s1 = pick.start(level: 1, expectedID: replayID, newSeed: nextSeed) else { replayOK = false; break }
            var rr = s1.round; rr.game.submit(rr.game.secret)
            let w = pick.save(rr, newSeed: nextSeed)
            if w.outcome != .cleared || w.session.best != 10 || w.session.level != 2 { replayOK = false }
            replayID = rr.id
        }
        check(replayOK && pick.load(newSeed: nextSeed).best == 10, "replaying and winning level 1 five times: best stays 10 (no farming, no skipping)")
        // Losing a lower level: best does not go down; the proposal is the same level.
        let l4 = pick.start(level: 4, expectedID: replayID, newSeed: nextSeed)!
        var l4r = l4.round; for _ in 0..<7 { l4r.game.submit(wrong(l4r.game.secret, 4)); _ = pick.save(l4r, newSeed: nextSeed) }
        let l4s = pick.load(newSeed: nextSeed)
        check(l4s.round.game.status == .lost && l4s.level == 4 && l4s.best == 10 && l4s.round.isIdle, "losing level 4: proposal 4, best still 10")
        // From a lost round: back to the best level, win it -> best grows by EXACTLY one.
        let top = pick.start(level: 10, expectedID: l4r.id, newSeed: nextSeed)!
        var topR = top.round; topR.game.submit(topR.game.secret)
        let topW = pick.save(topR, newSeed: nextSeed)
        check(topW.outcome == .cleared && topW.session.best == 11 && topW.session.level == 11, "winning the best level unlocks exactly one more (10 -> 11)")
        check(pick.start(level: 12, expectedID: topR.id, newSeed: nextSeed) == nil && pick.start(level: 11, expectedID: topR.id, newSeed: nextSeed)?.round.level == 11, "level 12 is still locked; 11 can be started")
        // Best never goes down across any sequence of operations (random walk through the real store).
        let walkD = makeDefaults(); let walkSt = DecoderInfiniteStore(defaults: walkD)
        var walkRNG = DecoderRNG(seed: 4711); var bestSeen = 1; var monotone = true; var bounded = true
        for _ in 0..<1500 {
            let s = walkSt.load(newSeed: nextSeed)
            if s.best < bestSeen || s.best < s.level || s.round.level > s.best { monotone = false }
            bestSeen = max(bestSeen, s.best)
            switch walkRNG.int(6) {
            case 0: _ = walkSt.start(level: 1 + walkRNG.int(s.best + 2), expectedID: s.round.id, newSeed: nextSeed)   // sometimes above best
            case 1: _ = walkSt.retry(expectedID: s.round.id, newSeed: nextSeed)
            case 2: _ = walkSt.advance(expectedID: s.round.id, newSeed: nextSeed)
            case 3:
                var rr = s.round; rr.game.submit(rr.game.secret); _ = walkSt.save(rr, newSeed: nextSeed)
            default:
                var rr = s.round; rr.game.submit(wrong(rr.game.secret, rr.game.colorCount, walkRNG.int(5))); _ = walkSt.save(rr, newSeed: nextSeed)
            }
            let after = walkSt.load(newSeed: nextSeed)
            if after.best > bestSeen + 1 { bounded = false }          // at most one level per operation
        }
        check(monotone && bounded && bestSeen >= 2, "random walk (start/retry/advance/win/wrong x1500): best never drops, grows by at most 1, round level <= best (best reached \(bestSeen))")

        // --- Migration of blobs written by the first release ("v" 1) ---------------------
        // In progress at level 10 with 6-colour guesses: the round no longer validates (level 10 is 4 colours now).
        let mig1 = makeDefaults()
        mig1.set(stateBlob(level: 10, serial: 7, guesses: [[5,4,3,2], [0,5,4,1]]), forKey: DecoderInfiniteStore.key)
        let m1 = DecoderInfiniteStore(defaults: mig1).load(newSeed: nextSeed)
        check(m1.level == 10 && m1.best == 10 && m1.round.level == 10 && m1.round.game.colorCount == 4 && m1.round.game.guesses.isEmpty
              && m1.round.serial == 8 && m1.round.game.isPlayable && !m1.round.isCleared, "v1 in-progress round at level 10: same level, best = level, NEW 4-colour code, old guesses dropped")
        check(DecoderInfiniteStore(defaults: mig1).load(newSeed: nextSeed) == m1 && (mig1.dictionary(forKey: DecoderInfiniteStore.key)?["best"] as? Int) == 10
              && (mig1.dictionary(forKey: DecoderInfiniteStore.key)?["v"] as? Int) == 2, "migration is stable and rewrites the blob as v2 with best")
        // Cleared (won) round of level 15 -> stored level 16: nothing is lost, a round of level 16 is dealt.
        let v1Secret15 = DecoderGame.secret(seed: 77, colors: 6)
        let mig2 = makeDefaults()
        mig2.set(stateBlob(level: 16, roundLevel: 15, guesses: [v1Secret15], cleared: true), forKey: DecoderInfiniteStore.key)
        let m2 = DecoderInfiniteStore(defaults: mig2).load(newSeed: nextSeed)
        check(m2.level == 16 && m2.best == 16 && m2.round.level == 16 && m2.round.game.colorCount == 5 && !m2.round.isCleared && m2.round.game.guesses.isEmpty,
              "v1 cleared round (15 -> 16): level 16 and best 16 kept, fresh round at 16")
        // Lost round at level 35 (8 colours then, 6 now): same level, new code.
        let mig3 = makeDefaults()
        mig3.set(stateBlob(level: 35, guesses: Array(repeating: wrong(DecoderGame.secret(seed: 77, colors: 8), 8), count: 7)), forKey: DecoderInfiniteStore.key)
        let m3 = DecoderInfiniteStore(defaults: mig3).load(newSeed: nextSeed)
        check(m3.level == 35 && m3.best == 35 && m3.round.game.colorCount == 6 && m3.round.game.status == .playing && m3.round.game.guesses.isEmpty, "v1 lost round at level 35: level kept, fresh 6-colour round")
        // CHANGED 2026-11-10: level 90 was 8 colours and is 6 now (never 7/8 in Infinite): the round is
        // re-dealt at the SAME level with a new code; best is kept and can still grow.
        let secret90 = DecoderGame.secret(seed: 77, colors: 8)
        let g90 = [wrong(secret90, 8, 0), wrong(secret90, 8, 9)]
        let mig4 = makeDefaults()
        mig4.set(stateBlob(level: 90, serial: 12, guesses: g90), forKey: DecoderInfiniteStore.key)
        let m4 = DecoderInfiniteStore(defaults: mig4).load(newSeed: nextSeed)
        check(m4.level == 90 && m4.best == 90 && m4.round.serial == 13 && m4.round.game.guesses.isEmpty && m4.round.game.colorCount == 6 && m4.round.game.maxAttempts == 5,
              "v1 round at level 90 (8 colours then, 6 now): new code at level 90, 5 attempts, best = 90")
        var m4r = m4.round; m4r.game.submit(m4r.game.secret)
        let m4w = DecoderInfiniteStore(defaults: mig4).save(m4r, newSeed: nextSeed)
        check(m4w.outcome == .cleared && m4w.session.best == 91 && m4w.session.level == 91, "a migrated v1 round can be finished: best 90 -> 91")
        // Every v1 level keeps its level and gets best = level, whatever the palette change.
        var migAll = true
        for level in [1, 2, 14, 15, 16, 20, 21, 29, 30, 31, 40, 41, 60, 61, 80, 81, 82, 300, DecoderInfinite.maxLevel] {
            let d = makeDefaults(); d.set(stateBlob(level: level), forKey: DecoderInfiniteStore.key)
            let s = DecoderInfiniteStore(defaults: d).load(newSeed: nextSeed)
            if s.level != level || s.best != level || s.round.level != level || s.round.game.colorCount != DecoderInfinite.colorCount(level: level) || !s.round.game.isPlayable { migAll = false }
        }
        check(migAll, "v1 blobs at every tier boundary: level never lowered, best = stored level, playable round of the new palette")
        // A v2 blob whose "colors" disagrees with its level (edited / future tiers) is re-dealt at the same level too.
        let mig5 = makeDefaults(); mig5.set(stateBlobV2(level: 30, best: 44, colors: 8), forKey: DecoderInfiniteStore.key)
        let m5 = DecoderInfiniteStore(defaults: mig5).load(newSeed: nextSeed)
        check(m5.level == 30 && m5.best == 44 && m5.round.game.colorCount == 6 && m5.round.serial == 6, "a round dealt with another palette: new code, same level, best kept")
        // --- Corruption of the new fields -------------------------------------------------
        func loadBlob(_ blob: [String: Any]) -> DecoderInfiniteSession {
            let d = makeDefaults(); d.set(blob, forKey: DecoderInfiniteStore.key)
            return DecoderInfiniteStore(defaults: d).load(newSeed: nextSeed)
        }
        // 2026-11-10: build-865 rounds (tiers of 20) in progress whose palette no longer matches are re-dealt; best never drops.
        var stale865 = true
        for lv in [5, 11, 15, 20, 21, 25, 40, 41, 55, 61, 81, 120] {
            let old = DecoderInfinite.previousColorCount(level: lv)
            let oldSecret = DecoderGame.secret(seed: 77, colors: old)
            let s = loadBlob(stateBlobV2(level: lv, best: lv + 3, guesses: [wrong(oldSecret, old)], colors: old))
            let keeps = old == DecoderInfinite.colorCount(level: lv)
            if s.level != lv || s.best != lv + 3 || s.round.game.colorCount != DecoderInfinite.colorCount(level: lv) || !s.round.game.isPlayable { stale865 = false }
            if keeps != (s.round.serial == 5) { stale865 = false }
            if !keeps && !s.round.game.guesses.isEmpty { stale865 = false }
            if s.round.game.revealedHintRows != [] { stale865 = false }
        }
        check(stale865, "build-865 blobs: palette mismatch -> new code at the same level, best kept, lips off; matching palette kept")
        // "attempts": missing keeps the legacy 7; the level's budget is kept; anything else is re-dealt.
        let s45 = DecoderGame.secret(seed: 77, colors: 6)
        let noBudget = loadBlob(stateBlobV2(level: 45, best: 45, guesses: [wrong(s45, 6)]))
        check(noBudget.round.serial == 5 && noBudget.round.game.maxAttempts == 7 && noBudget.round.game.guesses.count == 1, "round without attempts field keeps 7 (no one loses a round in progress)")
        var b5 = stateBlobV2(level: 45, best: 45, guesses: [wrong(s45, 6)]); b5["attempts"] = 5
        check(loadBlob(b5).round.serial == 5 && loadBlob(b5).round.game.maxAttempts == 5, "level budget stored: kept")
        var b6 = b5; b6["attempts"] = 6
        check(loadBlob(b6).round.serial == 6 && loadBlob(b6).round.game.maxAttempts == 5 && loadBlob(b6).best == 45, "edited budget: new code at the same level, budget of the level")
        // "hints": restored for existing rows; written back by save.
        var bh = b5; bh["hints"] = [0, 9]
        let hs1 = loadBlob(bh)
        check(hs1.round.game.revealedHintRows == [0], "Infinite blob restores revealed hints (rows that exist only)")
        let hd2 = makeDefaults(); hd2.set(b5, forKey: DecoderInfiniteStore.key)
        let hstore = DecoderInfiniteStore(defaults: hd2)
        var hround = hstore.load(newSeed: nextSeed).round
        check(hround.game.revealedHintRows.isEmpty, "Infinite blob without hints: lips off")
        hround.game.revealHint()
        check(hstore.save(hround).outcome == .saved && hstore.load(newSeed: nextSeed).round.game.revealedHintRows == [0]
              && (hd2.dictionary(forKey: DecoderInfiniteStore.key)?["attempts"] as? Int) == 5, "Infinite save persists hints and attempts")

        var bestLow = stateBlobV2(level: 12, best: 3)
        check(loadBlob(bestLow).best == 12 && loadBlob(bestLow).level == 12, "best below the level is lifted to the level")
        bestLow["best"] = -50; check(loadBlob(bestLow).best == 12, "negative best is lifted to the level")
        bestLow["best"] = "many"; check(loadBlob(bestLow).best == 12, "best of the wrong type falls back to the level")
        bestLow["best"] = Int.max; check(loadBlob(bestLow).best == DecoderInfinite.maxLevel && loadBlob(bestLow).level == 12, "huge best is clamped to the cap")
        var noLevel = stateBlobV2(level: 12, best: 30); noLevel["level"] = "x"
        let nl = loadBlob(noLevel)
        check(nl.best == 30 && nl.level == 30 && nl.round.game.isPlayable, "unreadable level but readable best: progress is kept (level = best)")
        var badColors = stateBlobV2(level: 50, best: 50); badColors["colors"] = "six"
        check(loadBlob(badColors).level == 50 && loadBlob(badColors).best == 50 && loadBlob(badColors).round.game.colorCount == 6, "colors of the wrong type: level/best kept, playable round")
        var hugeColors = stateBlobV2(level: 5, best: 5); hugeColors["colors"] = Int.max
        check(loadBlob(hugeColors).level == 5 && loadBlob(hugeColors).round.game.colorCount == 4, "absurd colors value: re-dealt with the level's palette")
        // A cleared v2 round whose best is behind (edited): best is repaired upwards, never used to lock the player out.
        let clearedSecret = DecoderGame.secret(seed: 77, colors: 4)
        let behind = loadBlob(stateBlobV2(level: 9, best: 2, roundLevel: 8, guesses: [clearedSecret], cleared: true))
        check(behind.level == 9 && behind.best == 9 && behind.round.isCleared && behind.round.level == 8, "cleared round with a stale best: best lifted to the proposed level")

        // Corrupt / hostile payloads never crash, never overflow, always yield a playable round.
        func sane(_ s: DecoderInfiniteSession) -> Bool {
            (1...DecoderInfinite.maxLevel).contains(s.level) && (s.level...DecoderInfinite.maxLevel).contains(s.best) && s.round.level <= s.best
                && s.round.game.isPlayable
                && s.round.game.colorCount == DecoderInfinite.colorCount(level: s.round.level) && s.round.draft.colorCount == s.round.game.colorCount
                && (0..<s.round.game.colorCount).contains(s.round.wheel) && (0...DecoderInfinite.maxElapsed).contains(s.round.elapsed)
        }
        var corruptOK = true
        var corruptCases: [(String, Any)] = [
            ("string", "garbage"), ("number", 42), ("array", [1, 2, 3]), ("empty dict", [String: Any]()),
            ("no level", ["serial": 3, "seed": "5"] as [String: Any]),
            ("level wrong type", ["level": "ten"] as [String: Any]),
            ("level negative", stateBlob(level: -50)),
            ("level huge", stateBlob(level: Int.max)),
            ("level zero", stateBlob(level: 0)),
            ("bad seed", stateBlob(level: 20, seed: "not-a-number")),
            ("seed overflow", stateBlob(level: 20, seed: "99999999999999999999999")),
            ("negative serial", stateBlob(level: 4, serial: -9)),
            ("huge serial", stateBlob(level: 4, serial: Int.max)),
            ("roundLevel mismatch", stateBlob(level: 20, roundLevel: 3)),
            ("cleared but not won", stateBlob(level: 6, roundLevel: 5, guesses: [[0,1,2,3]], cleared: true)),
            ("cleared wrong level", stateBlob(level: 9, roundLevel: 5, cleared: true)),
            ("illegal guesses", stateBlob(level: 3, guesses: [[1,1,1,1], [9,9,9,9], [0], []])),
            ("too many guesses", stateBlob(level: 3, guesses: Array(repeating: [0,1,2,3], count: 30)))
        ]
        var hostile = stateBlob(level: 40); hostile["draft"] = [5, 5, 99, -3, 7, 7]; hostile["selected"] = Int.min; hostile["wheel"] = Int.max; hostile["elapsed"] = Int.min
        corruptCases.append(("hostile draft/wheel/elapsed", hostile))
        var wrongTypes = stateBlob(level: 12); wrongTypes["guesses"] = "nope"; wrongTypes["draft"] = "nope"; wrongTypes["cleared"] = "yes"; wrongTypes["wheel"] = "x"
        corruptCases.append(("wrong inner types", wrongTypes))
        for (label, payload) in corruptCases {
            let d = makeDefaults()
            d.set(payload, forKey: DecoderInfiniteStore.key)
            let st = DecoderInfiniteStore(defaults: d)
            let s = st.load(newSeed: nextSeed)
            if !sane(s) { corruptOK = false; print("corrupt case not sane: \(label)") }
            let again = DecoderInfiniteStore(defaults: d).load(newSeed: nextSeed)
            if again != s { corruptOK = false; print("corrupt case not stable after repair: \(label)") }
            guard !s.round.isCleared, !s.round.game.isFinished else { continue }   // nothing left to win
            var probe = s.round
            probe.game.submit(probe.game.secret)
            let w = st.save(probe, newSeed: nextSeed)
            if w.outcome != .cleared || w.session.level < s.level || w.session.level > DecoderInfinite.maxLevel
                || w.session.best < s.best || w.session.best > DecoderInfinite.maxLevel { corruptOK = false; print("corrupt case win broke: \(label)") }
        }
        check(corruptOK, "corrupt payloads: repaired to a sane playable round, level in range, win still advances without overflow")
        let keepLevel = makeDefaults(); keepLevel.set(stateBlob(level: 20, seed: "oops"), forKey: DecoderInfiniteStore.key)
        let keptSession = DecoderInfiniteStore(defaults: keepLevel).load(newSeed: nextSeed)
        // CHANGED 2026-11-10: level 20 is 5 colours now (tiers of 10).
        check(keptSession.level == 20 && keptSession.best == 20 && keptSession.round.game.colorCount == 5, "a damaged round keeps the stored LEVEL and best (new code, same level)")
        let capped = makeDefaults(); capped.set(stateBlob(level: Int.max), forKey: DecoderInfiniteStore.key)
        check(DecoderInfiniteStore(defaults: capped).load(newSeed: nextSeed).level == DecoderInfinite.maxLevel, "level Int.max is clamped to the cap")
        let capWin = DecoderInfiniteStore(defaults: capped)
        var capRound = capWin.load(newSeed: nextSeed).round; capRound.game.submit(capRound.game.secret)
        check(capWin.save(capRound, newSeed: nextSeed).session.level == DecoderInfinite.maxLevel, "winning at the cap stays at the cap")

        // Independence: daily, legacy v1, other games and languages.
        let dailyAfter = dailySnapshot()
        check(dailyBefore == dailyAfter && daily.stats == dailyStatsBefore && daily.stats.played == 1 && daily.stats.losses == 1, "Infinite flows left every daily/legacy/other key byte-identical")
        check(!inf.load(newSeed: nextSeed).round.id.hasPrefix("en-") && !DecoderGame.isCurrentID(inf.load(newSeed: nextSeed).round.id), "Infinite ids carry no language and are never daily ids")
        var infWon = DecoderGame(id: "decinf-1-1", secret: [0,1,2,3]); infWon.submit([0,1,2,3])
        check(!daily.recordResultIfNew(infWon) && daily.stats == dailyStatsBefore, "an Infinite win is never recorded in the daily results/stats")
        daily.wipeAll()
        check(infDefaults.dictionary(forKey: DecoderInfiniteStore.key) != nil && inf.load(newSeed: nextSeed).level >= 1, "the daily 'reset all' (wipeAll) does not touch Infinite")
        check(DecoderStore.sessionsKey != DecoderInfiniteStore.key && !DecoderStore.legacyV1Keys.contains(DecoderInfiniteStore.key) && DecoderInfiniteStore.key == "newsraider.decoder.infinite.v1", "Infinite has its own dedicated key")
        let freshDomain = makeDefaults()
        _ = DecoderInfiniteStore(defaults: freshDomain).load(newSeed: nextSeed)
        let freshName = suitesToClean.last!
        check(Set(UserDefaults.standard.persistentDomain(forName: freshName)?.keys.map { $0 } ?? []) == [DecoderInfiniteStore.key], "Infinite writes exactly one key (single atomic blob)")
        // Daily games keep working with their v2 ids/keys after all of the above.
        let dailyAgain = DecoderStore(defaults: makeDefaults())
        var dgNew = DecoderGame.make(seed: 555, spanish: true); dgNew.submit(wrong(dgNew.secret, 6)); dailyAgain.save(dgNew)
        check(dailyAgain.load(id: dgNew.id, secret: dgNew.secret) == dgNew && dgNew.colorCount == 6, "daily store round-trips unchanged")
        }   // end device-edition scope

        check(DecoderCounter.digits(0) == [0,0,0] && DecoderCounter.digits(3) == [0,0,3]
              && DecoderCounter.digits(999) == [9,9,9], "counter preserves the three-digit device display")
        check(DecoderCounter.digits(1000) == [1,0,0,0] && DecoderCounter.digits(-1) == [0,0,0]
              && DecoderCounter.digits(Int.min) == [0,0,0]
              && DecoderCounter.digits(Int.max).map(String.init).joined() == String(Int.max),
              "counter never truncates levels above 999 and handles integer bounds")
        print(failures == 0 ? "PASS Decoder core:\(checks) checks" : "FAILED \(failures) of \(checks) checks")
        if failures > 0 { exit(1) }
    }
}

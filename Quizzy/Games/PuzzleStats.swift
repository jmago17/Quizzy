#if os(iOS)
//
//  PuzzleStats.swift — News Raider
//  Read-only aggregates over the existing PuzzleProgress store.
//  No persistence-schema changes: everything here is derived.
//

import Foundation

extension PuzzleProgress {

    /// Marks today's puzzle of `kind` as finished, keyed by day.
    private var todayKey: String {
        let c = Calendar(identifier: .gregorian)
            .dateComponents([.year, .month, .day], from: PuzzleSeed.effectiveDate())
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    /// Whether today's daily puzzle for `kind` has been completed.
    ///
    /// Deriving the id from the seed alone is not enough: several generators
    /// retry with a different seed when the first one yields no valid grid
    /// (`crossword` returns nil), and the mini crossword keys its id on the
    /// day index rather than the seed. In both cases the puzzle actually
    /// played is stored under an id the hub would never ask about, so a
    /// finished game kept showing as pending. The id of whatever puzzle was
    /// built for today is therefore recorded when it is handed to the hub,
    /// and that is what we check first.
    func isDoneToday(_ kind: PuzzleKind) -> Bool {
        if let actual = todaysPuzzleID(kind), isDone(actual) { return true }
        let seed = PuzzleSeed.daily(kind: kind)
        return isDone(dailyID(kind: kind, seed: seed))
    }

    private var dailyIDMapKey: String { "newsraider.dailyPuzzleIDs" }

    /// The id of the puzzle actually generated for today, if it was recorded.
    func todaysPuzzleID(_ kind: PuzzleKind, language: PuzzleLanguage = AppLanguage.current) -> String? {
        let map = defaults.dictionary(forKey: dailyIDMapKey) as? [String: String] ?? [:]
        let id = map[Self.languageKey("\(todayKey)|\(kind.rawValue)", language: language, kind: kind)]
        // Decoder rules v2: a remembered v1 id ("dec-…") must not mark today as done.
        if kind == .decoder, let id, !DecoderGame.isCurrentID(id) { return nil }
        return id
    }

    /// Remembers which concrete puzzle is today's for `kind`. Called by the
    /// hub as soon as a daily puzzle exists, so completion can be matched to
    /// the real id instead of a recomputed guess.
    func rememberTodaysPuzzleID(_ id: String, kind: PuzzleKind) {
        var map = defaults.dictionary(forKey: dailyIDMapKey) as? [String: String] ?? [:]
        let key = Self.languageKey("\(todayKey)|\(kind.rawValue)", language: PuzzleLanguage.from(puzzleID: id), kind: kind)
        guard map[key] != id else { return }
        map[key] = id
        // Keep only the last few days: this is a lookup table, not history.
        let keep = Set(map.keys.filter { $0.contains(todayKey) })
        if map.count > 40 {
            map = map.filter { keep.contains($0.key) }
            map[key] = id
        }
        defaults.set(map, forKey: dailyIDMapKey)
    }

    /// The id the hub uses for a daily puzzle of a given kind.
    func dailyID(kind: PuzzleKind, seed: UInt64, language: PuzzleLanguage = AppLanguage.current) -> String {
        let base: String
        switch kind {
        case .quartiles:  base = "q-gen-\(seed)"
        case .wordsearch: base = "w-gen-\(seed)"
        case .crossword:  base = "c-gen-\(seed)"
        case .maze:       base = "m-gen-\(seed)"
        case .wordle:     base = "d-day-\(PuzzleSeed.dayIndex())"
        case .trivia:     base = "trivia-day-\(PuzzleSeed.dayIndex())"
        case .numbers:    base = "num-\(seed)"
        case .anygram:    base = "any-\(seed)"
        case .hashtag:    base = "hash-\(seed)"
        case .murdle:     base = "murdle-\(seed)"
        case .murdoku:    base = "murdoku-\(seed)"
        case .minicross:  base = "minicross-d\(PuzzleSeed.dayIndex())"
        case .ladder:     base = "ladder-\(seed)"
        case .decoder:    base = DecoderGame.idPrefix + "\(seed)"
        }
        return language == .english && kind != .maze ? "en-" + base : base
    }

    /// How many of today's offered puzzles are finished.
    var doneCount: Int {
        PuzzleKind.offered(in: AppLanguage.current).filter { isDoneToday($0) }.count
    }

    /// The next unfinished puzzle after `kind`, wrapping around.
    func nextPending(after kind: PuzzleKind) -> PuzzleKind? {
        let all = PuzzleKind.offered(in: AppLanguage.current)
        guard let i = all.firstIndex(of: kind) else { return firstPending }
        let rotated = Array(all[(i + 1)...]) + Array(all[..<i])
        return rotated.first { !isDoneToday($0) }
    }

    /// First unfinished puzzle of the day, for the featured card.
    var firstPending: PuzzleKind? {
        PuzzleKind.offered(in: AppLanguage.current).first { !isDoneToday($0) }
    }

    /// Best (fastest) recorded time for a kind.
    func best(_ kind: PuzzleKind) -> TimeInterval? {
        let samples = defaults.dictionary(forKey: "newsraider.puzzleTimings") as? [String: [Double]] ?? [:]
        return samples[Self.languageKey(kind.rawValue, language: AppLanguage.current, kind: kind)]?.min()
    }

    /// Consecutive days where all offered puzzles were completed.
    var streak: Int {
        let log = defaults.stringArray(forKey: Self.languageKey("newsraider.puzzleFullDays", language: AppLanguage.current)) ?? []
        guard !log.isEmpty else { return 0 }
        let cal = Calendar(identifier: .gregorian)
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.calendar = cal
        let days = Set(log)
        var count = 0
        var cursor = PuzzleSeed.effectiveDate()
        // Today only breaks the streak once it is over, so start from today
        // and walk backwards while each day is present.
        while days.contains(fmt.string(from: cursor)) {
            count += 1
            guard let prev = cal.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = prev
        }
        return count
    }

    /// Records a "clean sweep" day once all offered games are done.
    func noteDayIfComplete() {
        guard doneCount == PuzzleKind.offered(in: AppLanguage.current).count else { return }
        var log = defaults.stringArray(forKey: Self.languageKey("newsraider.puzzleFullDays", language: AppLanguage.current)) ?? []
        guard !log.contains(todayKey) else { return }
        log.append(todayKey)
        defaults.set(Array(log.suffix(400)), forKey: Self.languageKey("newsraider.puzzleFullDays", language: AppLanguage.current))
    }
}

/// Where a puzzle stands today, so the hub can distinguish "not touched" from
/// "half solved" instead of only flagging completion.
enum PuzzleState {
    case fresh, started, done
}

extension PuzzleProgress {
    func state(_ kind: PuzzleKind) -> PuzzleState {
        if isDoneToday(kind) { return .done }
        // Same reasoning as isDoneToday: prefer the id of the puzzle actually
        // built for today, since a retried seed changes it.
        let id = todaysPuzzleID(kind)
            ?? dailyID(kind: kind, seed: PuzzleSeed.daily(kind: kind))
        // Any of these means the player has engaged with today's puzzle.
        let touched = !found(id).isEmpty
            || !fill(id).isEmpty
            || elapsed(id) > 5
            || hintsUsed(id) > 0
            || (kind == .decoder && !DecoderStore(defaults: defaults).guesses(for: id).isEmpty)
        return touched ? .started : .fresh
    }
}
#endif

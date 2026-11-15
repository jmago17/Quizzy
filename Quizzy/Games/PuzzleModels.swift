#if os(iOS)
//
//  PuzzleModels.swift — News Raider
//  Procedurally generated word puzzles (Quartiles / Sopa / Autodefinido).
//

import Foundation

// MARK: - Bundle

struct PuzzleBundle: Codable {
    let quartiles: [QuartilePuzzle]
    let wordsearch: [WordSearchPuzzle]
    let crossword: [CrosswordPuzzle]
}

enum PuzzleKind: String, CaseIterable, Identifiable, Sendable {
    // Legacy cases remain decodable, but are not offered or generated.
    case quartiles, wordsearch, crossword, maze, wordle, trivia, numbers, anygram, hashtag, murdle, murdoku, minicross, ladder, decoder

    static let allCases: [PuzzleKind] = [
        .quartiles, .wordsearch, .crossword, .maze, .wordle,
        .anygram, .hashtag, .murdle, .murdoku, .minicross, .decoder
    ]
    /// Availability is separate from decoding: saved games and identifiers remain valid.
    static func offered(in language: PuzzleLanguage) -> [PuzzleKind] {
        allCases.filter { language != .english || $0 != .quartiles }
    }

    var id: String { rawValue }

    var title: String {
        switch self {
        case .quartiles:  return "Quartiles"
        case .wordsearch: return AppLanguage.text("Sopa de letras", "Word Search")
        case .crossword:  return AppLanguage.text("Autodefinido", "Crossword")
        case .maze:       return AppLanguage.text("Laberinto", "Maze")
        case .wordle:     return "Wordle"
        case .trivia:     return "10 en 60"
        case .numbers:    return "Cifras"
        case .anygram:    return "Anygram"
        case .hashtag:    return "Hashtag"
        case .murdle:     return "Murdle"
        case .murdoku:    return "Murdoku"
        case .minicross:  return AppLanguage.text("Mini crucigrama", "Mini Crossword")
        case .ladder:     return "Escalera de palabras"
        case .decoder:    return "Decoder"
        }
    }
    var blurb: String {
        switch self {
        case .quartiles:  return AppLanguage.text("Combina fragmentos para formar palabras", "Combine fragments to make words")
        case .wordsearch: return AppLanguage.text("Encuentra las palabras ocultas", "Find the hidden words")
        case .crossword:  return AppLanguage.text("Resuelve las definiciones cruzadas", "Solve the crossing clues")
        case .maze:       return AppLanguage.text("Encuentra el camino hasta la salida", "Find the way to the exit")
        case .wordle:     return AppLanguage.text("Adivina la palabra en seis intentos", "Guess the word in six attempts")
        case .trivia:     return "10 preguntas antes de que acabe el minuto"
        case .numbers:    return "Llega al número objetivo"
        case .anygram:    return AppLanguage.text("Encuentra anagramas en la rueda", "Find anagrams in the wheel")
        case .hashtag:    return AppLanguage.text("Reconstruye cuatro palabras cruzadas", "Rebuild four crossing words")
        case .murdle:     return AppLanguage.text("Resuelve un asesinato por deducción", "Solve a mystery through deduction")
        case .murdoku:    return AppLanguage.text("Sitúa a los sospechosos y descubre al asesino", "Place the suspects and find the murderer")
        case .minicross:  return AppLanguage.text("Rejilla entrelazada que cambia cada día", "An interlocking grid that changes daily")
        case .ladder:     return "Cambia una letra en cada peldaño"
        case .decoder:    return AppLanguage.text("Descifra el código de colores en siete intentos", "Crack the colour code in seven attempts")
        }
    }
    var symbol: String {
        switch self {
        case .quartiles:  return "square.grid.2x2"
        case .wordsearch: return "text.magnifyingglass"
        case .crossword:  return "square.grid.3x3"
        case .maze:       return "point.topleft.down.to.point.bottomright.curvepath"
        case .wordle:     return "square.grid.3x3.square"
        case .trivia:     return "timer"
        case .numbers:    return "textformat.abc"
        case .anygram:    return "text.badge.plus"
        case .hashtag:    return "number"
        case .murdle:     return "person.crop.circle.badge.questionmark"
        case .murdoku:    return "square.grid.3x3.topleft.filled"
        case .minicross:  return "square.grid.3x3.fill"
        case .ladder:     return "text.line.first.and.arrowtriangle.forward"
        case .decoder:    return "dial.medium"
        }
    }
    var difficulty: String {
        switch self {
        case .quartiles:  return AppLanguage.text("Difícil", "Hard")
        case .wordsearch: return AppLanguage.text("Fácil", "Easy")
        case .crossword:  return AppLanguage.text("Medio", "Medium")
        case .maze:       return AppLanguage.text("Medio", "Medium")
        case .wordle:     return AppLanguage.text("Medio", "Medium")
        case .trivia:     return AppLanguage.text("Rápido", "Quick")
        case .numbers:    return AppLanguage.text("Medio", "Medium")
        case .anygram:    return AppLanguage.text("Medio", "Medium")
        case .hashtag:    return AppLanguage.text("Fácil", "Easy")
        case .murdle:     return AppLanguage.text("Variable", "Variable")
        case .murdoku:    return AppLanguage.text("Medio", "Medium")
        case .minicross:  return AppLanguage.text("Medio", "Medium")
        case .ladder:     return AppLanguage.text("Medio", "Medium")
        case .decoder:    return AppLanguage.text("Medio", "Medium")
        }
    }
}

// MARK: - Quartiles

struct QuartilePuzzle: Codable, Identifiable, Sendable {
    let id: String
    let tiles: [String]
    let targets: [String]
    let solutions: [String: [String]]   // "1".."4" -> words
    /// Extra 4-fragment words that also spell something real but were not
    /// part of the designed targets. Accepted as valid plays (so a player
    /// typing a genuine word like AGUANTARE is never rejected) but excluded
    /// from the 5-quartile counter and the +10 quartile bonus.
    var bonusFour: [String] = []
    let maxScore: Int

    enum CodingKeys: String, CodingKey {
        case id, tiles, targets, solutions, bonusFour
        case maxScore = "max_score"
    }

    var allValid: Set<String> { Set(solutions.values.flatMap { $0 }).union(bonusFour) }

    /// Points for a word. Quartiles (4 fragments) carry a +10 bonus on top of
    /// their base 8, matching Apple News+ scoring: five quartiles = 90, so a
    /// handful of short words tips you over the 100-point goal. Bonus
    /// 4-fragment words (real, but not a designed target) score like a
    /// regular 3-fragment word — no quartile bonus, since they don't count
    /// toward the 5-quartile goal.
    func points(for word: String) -> Int {
        for k in ["4", "3", "2", "1"] where solutions[k]?.contains(word) == true {
            let base = [1: 1, 2: 2, 3: 4, 4: 8][Int(k)!] ?? 0
            return k == "4" ? base + 10 : base
        }
        if bonusFour.contains(word) { return 4 }
        return 0
    }

    /// Fixed, reachable goal — the puzzle is complete once you cross it.
    var targetScore: Int { 100 }
    func isQuartile(_ word: String) -> Bool {
        solutions["4"]?.contains(word) == true
    }
}

// MARK: - Word search

struct WordSearchPuzzle: Codable, Identifiable, Sendable {
    let id: String
    let size: Int
    let grid: [[String]]
    let words: [PlacedWord]
}

struct PlacedWord: Codable, Hashable, Sendable {
    let word: String
    let cells: [[Int]]
    let clue: String?
}

// MARK: - Crossword

struct CrosswordPuzzle: Codable, Identifiable, Sendable {
    let id: String
    let size: Int
    let blocks: [[Int]]
    let solution: [String: String]      // "r,c" -> letter
    let entries: [CrossEntry]
    let full: Bool

    /// Grids used to be square, so `size` described both axes. The mini
    /// crossword varies its shape through the week (5×5 up to 7×7), which
    /// needs the two axes separately. Both stay optional so puzzles already
    /// decoded from disk keep working: they fall back to `size`.
    private let storedRows: Int?
    private let storedCols: Int?

    var rows: Int { storedRows ?? size }
    var cols: Int { storedCols ?? size }

    var blockSet: Set<GridCell> {
        Set(blocks.map { GridCell(row: $0[0], col: $0[1]) })
    }

    enum CodingKeys: String, CodingKey {
        case id, size, blocks, solution, entries, full
        case storedRows = "rows"
        case storedCols = "cols"
    }

    init(id: String, size: Int, rows: Int? = nil, cols: Int? = nil,
         blocks: [[Int]], solution: [String: String],
         entries: [CrossEntry], full: Bool) {
        self.id = id
        self.size = size
        self.storedRows = rows
        self.storedCols = cols
        self.blocks = blocks
        self.solution = solution
        self.entries = entries
        self.full = full
    }
}

struct CrossEntry: Codable, Identifiable, Hashable, Sendable {
    let word: String
    let clue: String
    let dir: String                     // "H" | "V"
    let row: Int
    let col: Int
    let len: Int

    var id: String { "\(row),\(col),\(dir)" }
    var isAcross: Bool { dir == "H" }

    var cells: [GridCell] {
        (0..<len).map { i in
            isAcross ? GridCell(row: row, col: col + i)
                     : GridCell(row: row + i, col: col)
        }
    }
}

struct GridCell: Hashable, Identifiable, Sendable {
    let row: Int
    let col: Int
    var id: String { "\(row),\(col)" }
    var key: String { "\(row),\(col)" }
}

// MARK: - Loader

enum PuzzleLoader {
    static func load() -> PuzzleBundle? {
        guard let url = Bundle.main.url(forResource: "puzzles", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(PuzzleBundle.self, from: data)
    }
}

// MARK: - Progress (App Group, mirrors ReadStore)

@MainActor
final class PuzzleProgress: ObservableObject {
    static let shared = PuzzleProgress()
    let defaults = UserDefaults(suiteName: "quizzy.games")
        ?? .standard
    private let key = "newsraider.puzzles"
    private let timingKey = "newsraider.puzzleTimings"

    @Published private(set) var state: [String: [String: AnyCodableBox]] = [:]

    private init() { load() }

    /// Spanish keeps every historical key. Language-free mazes share progress.
    nonisolated static func languageKey(_ key: String, language: PuzzleLanguage,
                                        kind: PuzzleKind? = nil) -> String {
        language == .english && kind != .maze ? "en|" + key : key
    }


    private var raw: [String: Any] {
        get { defaults.dictionary(forKey: key) ?? [:] }
        set { defaults.set(newValue, forKey: key) }
    }

    private func load() { objectWillChange.send() }

    func isDone(_ id: String) -> Bool {
        (raw[id] as? [String: Any])?["done"] as? Bool ?? false
    }
    func markDone(_ id: String) {
        var all = raw
        var e = all[id] as? [String: Any] ?? [:]
        e["done"] = true
        all[id] = e
        raw = all
        objectWillChange.send()
    }
    func found(_ id: String) -> [String] {
        (raw[id] as? [String: Any])?["found"] as? [String] ?? []
    }
    func setFound(_ id: String, _ words: [String]) {
        var all = raw
        var e = all[id] as? [String: Any] ?? [:]
        e["found"] = words
        all[id] = e
        raw = all
        objectWillChange.send()
    }
    func tileOrder(_ id: String, default fallback: [Int]) -> [Int] {
        (raw[id] as? [String: Any])?["tileOrder"] as? [Int] ?? fallback
    }
    func setTileOrder(_ id: String, _ order: [Int]) {
        var all = raw
        var e = all[id] as? [String: Any] ?? [:]
        e["tileOrder"] = order
        all[id] = e
        raw = all
        objectWillChange.send()
    }
    func fill(_ id: String) -> [String: String] {
        (raw[id] as? [String: Any])?["fill"] as? [String: String] ?? [:]
    }
    func setFill(_ id: String, _ f: [String: String]) {
        var all = raw
        var e = all[id] as? [String: Any] ?? [:]
        e["fill"] = f
        all[id] = e
        raw = all
        objectWillChange.send()
    }
    func reset(_ id: String) {
        var all = raw
        all.removeValue(forKey: id)
        raw = all
        objectWillChange.send()
    }

    // MARK: Completion times

    private var timingRaw: [String: [Double]] {
        get { defaults.dictionary(forKey: timingKey) as? [String: [Double]] ?? [:] }
        set { defaults.set(newValue, forKey: timingKey) }
    }

    /// Stores a completed attempt once and keeps only the latest 30 samples.
    func recordTime(_ seconds: TimeInterval, kind: PuzzleKind, puzzleID: String) {
        guard seconds >= 5, completedTime(puzzleID) == nil else { return }
        var all = timingRaw
        let language = PuzzleLanguage.from(puzzleID: puzzleID)
        let sampleKey = Self.languageKey(kind.rawValue, language: language, kind: kind)
        var samples = all[sampleKey] ?? []
        samples.append(seconds)
        all[sampleKey] = Array(samples.suffix(30))
        all["completed:\(puzzleID)"] = [seconds]
        timingRaw = all
    }

    func completedTime(_ puzzleID: String) -> TimeInterval? {
        timingRaw["completed:\(puzzleID)"]?.first
    }

    func personalAverage(_ kind: PuzzleKind) -> TimeInterval? {
        let samples = timingRaw[Self.languageKey(kind.rawValue, language: AppLanguage.current, kind: kind)] ?? []
        guard samples.count >= 3 else { return nil }
        return samples.reduce(0, +) / Double(samples.count)
    }

    func elapsed(_ puzzleID: String) -> Int {
        (raw[puzzleID] as? [String: Any])?["elapsed"] as? Int ?? 0
    }

    func setElapsed(_ puzzleID: String, _ seconds: Int) {
        var all = raw
        var e = all[puzzleID] as? [String: Any] ?? [:]
        e["elapsed"] = seconds
        all[puzzleID] = e
        raw = all
    }

    // MARK: Wordle answer history

    func recentWordleAnswers(language: PuzzleLanguage = AppLanguage.current) -> [String] {
        defaults.stringArray(forKey: Self.languageKey("newsraider.wordleRecent", language: language)) ?? []
    }

    func rememberWordleAnswer(_ word: String, language: PuzzleLanguage = AppLanguage.current) {
        var recent = recentWordleAnswers(language: language).filter { $0 != word }
        recent.append(word)
        defaults.set(Array(recent.suffix(300)), forKey: Self.languageKey("newsraider.wordleRecent", language: language))
    }

    // MARK: Trivia question history

    /// Ids of trivia questions already served, so a freshly generated round
    /// avoids repeating them until the bank has been exhausted.
    func recentTriviaQuestions() -> [Int] {
        (defaults.array(forKey: "newsraider.triviaRecent") as? [Int]) ?? []
    }

    func rememberTriviaQuestions(_ ids: [Int], bankSize: Int) {
        var recent = recentTriviaQuestions().filter { !ids.contains($0) }
        recent.append(contentsOf: ids)
        // Keep just under a full bank so there is always something fresh.
        let cap = max(10, bankSize - 10)
        defaults.set(Array(recent.suffix(cap)), forKey: "newsraider.triviaRecent")
    }

    // MARK: Hints

    /// Hints taken on a puzzle. Each one costs `PZHintButton.penalty` seconds,
    /// applied to the running clock so the final time reflects the help.
    func hintsUsed(_ puzzleID: String) -> Int {
        (raw[puzzleID] as? [String: Any])?["hints"] as? Int ?? 0
    }

    func addHint(_ puzzleID: String) {
        var all = raw
        var e = all[puzzleID] as? [String: Any] ?? [:]
        e["hints"] = (e["hints"] as? Int ?? 0) + 1
        all[puzzleID] = e
        raw = all
        objectWillChange.send()
    }

    // MARK: Testing helpers

    /// Shifts every daily puzzle by N days without touching the clock, so the
    /// daily rotation can be exercised without waiting until tomorrow.
    var debugDayOffset: Int {
        get { defaults.integer(forKey: "newsraider.debugDayOffset") }
        set {
            defaults.set(newValue, forKey: "newsraider.debugDayOffset")
            objectWillChange.send()
        }
    }

    /// Wipes progress, timings, streaks and the Wordle history — a clean slate
    /// for testing the daily flow end to end.
    func resetAllProgress() {
        defaults.removeObject(forKey: key)
        defaults.removeObject(forKey: timingKey)
        defaults.removeObject(forKey: "newsraider.puzzleFullDays")
        defaults.removeObject(forKey: "newsraider.wordleRecent")
        defaults.removeObject(forKey: "newsraider.triviaRecent")
        defaults.removeObject(forKey: "en|newsraider.wordleRecent")
        defaults.removeObject(forKey: "en|newsraider.puzzleFullDays")
        defaults.removeObject(forKey: "newsraider.dailyPuzzleIDs")
        defaults.removeObject(forKey: "newsraider.puzzleSnapshots.v1")
        DecoderStore(defaults: defaults).wipeAll()
        objectWillChange.send()
    }
}

/// Minimal box so the published dictionary stays Sendable-friendly.
struct AnyCodableBox: Hashable {}


// MARK: - Anygram

/// A word wheel with a compact crossed-word board. Answers may use any
/// subset of the wheel, while respecting each letter's multiplicity.
struct AnygramPuzzle: Identifiable, Sendable, Hashable {
    struct Entry: Identifiable, Sendable, Hashable, Codable {
        enum Direction: Sendable, Hashable, Codable { case horizontal, vertical }

        let word: String
        let row: Int
        let col: Int
        let direction: Direction

        var id: String { "\(word)-\(row)-\(col)-\(direction)" }

        var cells: [GridCell] {
            word.indices.enumerated().map { offset, _ in
                direction == .horizontal
                    ? GridCell(row: row, col: col + offset)
                    : GridCell(row: row + offset, col: col)
            }
        }
    }

    let id: String
    let letters: [Character]
    let answers: [String]
    let boardRows: Int
    let boardCols: Int
    let entries: [Entry]

    var boardCells: [GridCell: Character] {
        var result: [GridCell: Character] = [:]
        for entry in entries {
            for (index, cell) in entry.cells.enumerated() {
                result[cell] = Array(entry.word)[index]
            }
        }
        return result
    }

    static func generate(seed: UInt64, language: PuzzleLanguage = .spanish) -> AnygramPuzzle? {
        if language == .english {
            let variants: [(String, Int, Int, [Entry])] = [
            ( "PLANET", 9, 10, [
                .init(word: "PLANET", row: 4, col: 4, direction: .horizontal),
                .init(word: "PLANE", row: 4, col: 4, direction: .vertical),
                .init(word: "PLANT", row: 2, col: 6, direction: .vertical),
                .init(word: "PLATE", row: 0, col: 8, direction: .vertical),
                .init(word: "PANEL", row: 5, col: 0, direction: .horizontal),
                .init(word: "PETAL", row: 8, col: 3, direction: .horizontal),
                .init(word: "LEAPT", row: 0, col: 5, direction: .horizontal),
                .init(word: "LEANT", row: 3, col: 1, direction: .vertical)
            ]),
            ( "GARDEN", 9, 11, [
                .init(word: "GARDEN", row: 3, col: 4, direction: .horizontal),
                .init(word: "DANGER", row: 0, col: 4, direction: .vertical),
                .init(word: "RANGED", row: 3, col: 6, direction: .vertical),
                .init(word: "ANGER", row: 0, col: 8, direction: .vertical),
                .init(word: "RANGE", row: 4, col: 0, direction: .horizontal),
                .init(word: "GRADE", row: 0, col: 1, direction: .horizontal),
                .init(word: "GRAND", row: 6, col: 6, direction: .horizontal),
                .init(word: "DEAR", row: 8, col: 6, direction: .horizontal)
            ]),
            ( "LISTEN", 8, 11, [
                .init(word: "LISTEN", row: 4, col: 5, direction: .horizontal),
                .init(word: "SILENT", row: 2, col: 5, direction: .vertical),
                .init(word: "ENLIST", row: 0, col: 7, direction: .vertical),
                .init(word: "TINSEL", row: 0, col: 9, direction: .vertical),
                .init(word: "INLETS", row: 2, col: 0, direction: .horizontal),
                .init(word: "LENT", row: 6, col: 3, direction: .horizontal),
                .init(word: "LENS", row: 2, col: 7, direction: .horizontal),
                .init(word: "LINE", row: 0, col: 4, direction: .horizontal)
            ])
            ]
            let (base, rows, cols, entries) = variants[Int(seed % UInt64(variants.count))]
            var rng = SeededGenerator(seed: seed)
            return .init(id: "en-any-\(seed)", letters: rng.shuffled(Array(base)),
                         answers: entries.map(\.word), boardRows: rows, boardCols: cols, entries: entries)
        }
        struct Board {
            var letters: [GridCell: Character]
            var directions: [GridCell: Set<Entry.Direction>]
            var entries: [Entry]
        }

        func isClean(_ word: String) -> Bool {
            guard (3...6).contains(word.count), word.unicodeScalars.count == word.count else {
                return false
            }
            return word.unicodeScalars.allSatisfy { (65...90).contains($0.value) }
        }

        func counts(_ word: String) -> [Character: Int] {
            var result: [Character: Int] = [:]
            for letter in word {
                result[letter, default: 0] += 1
            }
            return result
        }

        func canForm(_ word: String, from available: [Character: Int]) -> Bool {
            let needed = counts(word)
            return needed.allSatisfy { available[$0.key, default: 0] >= $0.value }
        }

        func stableRank(_ word: String, salt: UInt64) -> UInt64 {
            var value = seed ^ salt ^ 0x9E37_79B9_7F4A_7C15
            for byte in word.utf8 {
                value ^= UInt64(byte)
                value &*= 0x100_0000_01B3
                value ^= value >> 29
            }
            return value
        }

        func bounds(of board: Board) -> (minRow: Int, maxRow: Int, minCol: Int, maxCol: Int)? {
            guard let first = board.letters.keys.first else { return nil }
            var minRow = first.row
            var maxRow = first.row
            var minCol = first.col
            var maxCol = first.col
            for cell in board.letters.keys {
                minRow = min(minRow, cell.row)
                maxRow = max(maxRow, cell.row)
                minCol = min(minCol, cell.col)
                maxCol = max(maxCol, cell.col)
            }
            return (minRow, maxRow, minCol, maxCol)
        }

        func placed(_ word: String,
                    row: Int,
                    col: Int,
                    direction: Entry.Direction,
                    on board: Board) -> Board? {
            let letters = Array(word)
            let before = direction == .horizontal
                ? GridCell(row: row, col: col - 1)
                : GridCell(row: row - 1, col: col)
            let after = direction == .horizontal
                ? GridCell(row: row, col: col + letters.count)
                : GridCell(row: row + letters.count, col: col)

            guard board.letters[before] == nil, board.letters[after] == nil else { return nil }

            var crossings = 0
            for (offset, letter) in letters.enumerated() {
                let cell = direction == .horizontal
                    ? GridCell(row: row, col: col + offset)
                    : GridCell(row: row + offset, col: col)

                if let existing = board.letters[cell] {
                    guard existing == letter,
                          board.directions[cell]?.contains(direction) != true else {
                        return nil
                    }
                    crossings += 1
                } else {
                    let neighbors = direction == .horizontal
                        ? [GridCell(row: cell.row - 1, col: cell.col),
                           GridCell(row: cell.row + 1, col: cell.col)]
                        : [GridCell(row: cell.row, col: cell.col - 1),
                           GridCell(row: cell.row, col: cell.col + 1)]
                    guard neighbors.allSatisfy({ board.letters[$0] == nil }) else { return nil }
                }
            }
            guard crossings > 0 else { return nil }

            var result = board
            let entry = Entry(word: word, row: row, col: col, direction: direction)
            for (offset, letter) in letters.enumerated() {
                let cell = direction == .horizontal
                    ? GridCell(row: row, col: col + offset)
                    : GridCell(row: row + offset, col: col)
                result.letters[cell] = letter
                result.directions[cell, default: []].insert(direction)
            }
            result.entries.append(entry)

            guard let extent = bounds(of: result),
                  extent.maxRow - extent.minRow + 1 <= 8,
                  extent.maxCol - extent.minCol + 1 <= 8 else {
                return nil
            }
            return result
        }

        func placements(for word: String, on board: Board, salt: UInt64) -> [Board] {
            let letters = Array(word)
            let occupied = board.letters.keys.sorted {
                $0.row == $1.row ? $0.col < $1.col : $0.row < $1.row
            }
            var candidates: [(rank: UInt64, board: Board)] = []

            for cell in occupied {
                guard let existing = board.letters[cell] else { continue }
                for (offset, letter) in letters.enumerated() where letter == existing {
                    for direction in [Entry.Direction.horizontal, .vertical] {
                        let row = direction == .horizontal ? cell.row : cell.row - offset
                        let col = direction == .horizontal ? cell.col - offset : cell.col
                        if let candidate = placed(word, row: row, col: col,
                                                  direction: direction, on: board) {
                            let coordinateSalt = UInt64(bitPattern: Int64(row &* 31 &+ col &* 17 &+ offset))
                            candidates.append((
                                stableRank(word, salt: salt ^ coordinateSalt
                                           ^ (direction == .horizontal ? 0x48 : 0x56)),
                                candidate
                            ))
                        }
                    }
                }
            }
            candidates.sort { $0.rank < $1.rank }
            return candidates.prefix(40).map(\.board)
        }

        func better(_ lhs: Board, than rhs: Board?) -> Bool {
            guard let rhs else { return true }
            if lhs.entries.count != rhs.entries.count {
                return lhs.entries.count > rhs.entries.count
            }
            let lhsArea = bounds(of: lhs).map {
                ($0.maxRow - $0.minRow + 1) * ($0.maxCol - $0.minCol + 1)
            } ?? Int.max
            let rhsArea = bounds(of: rhs).map {
                ($0.maxRow - $0.minRow + 1) * ($0.maxCol - $0.minCol + 1)
            } ?? Int.max
            if lhsArea != rhsArea { return lhsArea < rhsArea }
            let lhsLength = lhs.entries.reduce(0) { $0 + $1.word.count }
            let rhsLength = rhs.entries.reduce(0) { $0 + $1.word.count }
            return lhsLength > rhsLength
        }

        func search(_ words: [String], index: Int, board: Board,
                    salt: UInt64, best: inout Board?) {
            if better(board, than: best) { best = board }
            guard index < words.count,
                  board.entries.count + words.count - index >= max(8, best?.entries.count ?? 0) else {
                return
            }

            let word = words[index]
            for candidate in placements(for: word, on: board,
                                        salt: salt ^ UInt64(index)) {
                search(words, index: index + 1, board: candidate,
                       salt: salt, best: &best)
            }
            search(words, index: index + 1, board: board, salt: salt, best: &best)
        }

        let blacklist: Set<String> = [
            "PUTA", "PUTO", "PORNO", "COÑO", "CULO", "PENE", "SEXO"
        ]
        // Natural clues are useful source material, but also contain uncommon
        // dictionary forms. Keep Anygram's hidden targets deliberately familiar:
        // guessing the layout should be the challenge, not guessing the lexicon.
        let friendlyWords: Set<String> = [
            "AIRE", "ALGO", "ALTERO", "ALTO", "AMO", "AMOR", "ANIMAL", "ARENA", "ARO",
            "AROMA", "ARTE", "BALON", "BARCO", "BARRO", "BRAZO", "CABRA", "CALOR",
            "CAMARA", "CAMINO", "CAMION", "CAMISA", "CAMPO", "CANTO", "CARA", "CARNE",
            "CARO", "CARTA", "CARTON", "CASA", "CASERO", "CASINO", "CASO", "CASTOR",
            "CELO", "CIELO", "CIMA", "CIRCO", "CLORO", "COCHE", "COLA", "COLEGA",
            "COLOR", "COMA", "COMPRA", "CONTRA", "COPA", "CORTAS", "CORTE", "COSTAR",
            "CREMA", "CUERDA", "CURA", "DEDO", "DENTRO", "DIA", "DINERO", "DUDA",
            "DUNA", "EGO", "FARO", "FERIA", "FIAR", "FIERA", "FLOR", "FORMA", "FORMAR",
            "FRUTA", "FUEGO", "GALO", "GATO", "GIRO", "GOLA", "GOTA", "GRATO", "GRITO",
            "HIELO", "IMAN", "ISLA", "JARDIN", "LADO", "LAGO", "LARGO", "LAS", "LATA",
            "LECHO", "LIBRO", "LIMA", "LIMO", "LIMON", "LINO", "LISTA", "LISTO", "LOBO",
            "LOMO", "LORO", "LOROS", "LUNAR", "LUZ", "MADERA", "MAL", "MALETA", "MANCO",
            "MANO", "MANTEL", "MANTO", "MAPA", "MAR", "MARCO", "MARTES", "MESA", "METRO",
            "MIEDO", "MIL", "MIRADA", "MOLE", "MONA", "MONEDA", "MONTA", "MONTE", "MORA",
            "MOTOR", "MURO", "MUSA", "MUSICA", "NACER", "NIDO", "NIEVE", "NOCHE", "NOTA",
            "NUBE", "NUDO", "OLA", "OLOR", "OPINA", "OPTA", "ORAL", "ORO", "OSO", "OTRO",
            "PADRE", "PALETO", "PALO", "PALOS", "PAN", "PARO", "PARQUE", "PASO", "PASTO",
            "PATIO", "PATO", "PAZ", "PELO", "PELOTA", "PERA", "PERLAS", "PERRO", "PIANO",
            "PIEDRA", "PISAR", "PISTA", "PLANTA", "PLATA", "PLATO", "PLAYA", "PODAR",
            "POSA", "PRADO", "PRENDA", "PRISA", "PROA", "PUENTE", "PUERTA", "RAMA",
            "RAMO", "RAMPA", "RASTRO", "RATO", "RATON", "REAL", "RECADO", "RECTO",
            "RED", "REINO", "RENO", "RETO", "RIO", "RISA", "ROCA", "ROL", "ROPA",
            "ROSA", "ROSAL", "ROSTRO", "ROTO", "RUEDA", "RUMOR", "RUTA", "SACA", "SAL",
            "SALA", "SALIDA", "SALON", "SALTO", "SAPO", "SENDA", "SERIAL", "SIERRA",
            "SILLA", "SIRENA", "SITIO", "SOL", "SOLAR", "SOLO", "SONIDO", "SOPA",
            "SOPLA", "SUELO", "SUERTE", "SUMA", "TALCO", "TALON", "TAPO", "TARDE",
            "TARIMA", "TELA", "TENOR", "TERNO", "TESORO", "TIEMPO", "TIENDA", "TIMBRE",
            "TINTA", "TOCAR", "TOGA", "TOMATE", "TONER", "TONO", "TOPE", "TORO",
            "TRAMO", "TREN", "TRIGO", "TRINEO", "TRONO", "TROZO", "TRUCHA", "TRUENO",
            "VELA", "VERANO", "VIAJE", "VIENTO", "VOZ"
        ]
        // The hand-written list above stays as a *preference*, not as the whole
        // vocabulary. Intersecting the clue words with those 252 entries left
        // 190 usable words and, after demanding a family of 8, only five
        // playable wheels — so the seed rotation had almost nothing to rotate
        // through and every round looked the same. common_words.json is the
        // curated frequent-word list Quartiles already seeds from: 3,276
        // distinct wheels, which is years of daily play.
        let vocabulary = Set(PuzzleLexicon.commonWords.map { $0.uppercased() })
            .filter { isClean($0) && !blacklist.contains($0) }
        // Distinct wheels only: bases sharing a letter multiset (CASTOR / CORTAS /
        // COSTAR) would produce an identical wheel, so keep one representative.
        var wheelKeys = Set<String>()
        let allBases = vocabulary.filter { (5...6).contains($0.count) }
            .sorted()
            // Bases from the friendly list first: when several wheels are
            // equally valid, prefer the everyday word.
            .sorted { friendlyWords.contains($0) && !friendlyWords.contains($1) }
            .filter { wheelKeys.insert(String($0.sorted())).inserted }
        // Only bases with a rich enough family are playable; rotate through them
        // with the seed so consecutive days never land on the same wheel.
        let playable = allBases.filter { base in
            let available = counts(base)
            return vocabulary.filter { canForm($0, from: available) }.count >= 8
        }
        let bases: [String]
        if playable.isEmpty {
            bases = []
        } else {
            let offset = Int(seed % UInt64(playable.count))
            bases = Array(playable[offset...] + playable[..<offset])
        }

        var generated: (base: String, board: Board)?
        for (baseIndex, base) in bases.enumerated() {
            let available = counts(base)
            let formable = vocabulary.filter { canForm($0, from: available) }
            guard formable.contains(base), formable.count >= 8 else { continue }

            let others = formable.filter { $0 != base }.sorted {
                if $0.count != $1.count { return $0.count > $1.count }
                let lhs = stableRank($0, salt: UInt64(baseIndex))
                let rhs = stableRank($1, salt: UInt64(baseIndex))
                return lhs == rhs ? $0 < $1 : lhs < rhs
            }
            let selected = [base] + Array(others.prefix(11))
            let first = Entry(word: base, row: 0, col: 0, direction: .horizontal)
            var initial = Board(letters: [:], directions: [:], entries: [first])
            for (offset, letter) in base.enumerated() {
                let cell = GridCell(row: 0, col: offset)
                initial.letters[cell] = letter
                initial.directions[cell] = [.horizontal]
            }

            var best: Board?
            for attempt in 0..<4 {
                var tail = Array(selected.dropFirst())
                tail.sort {
                    let lhs = stableRank($0, salt: UInt64(attempt) ^ UInt64(baseIndex))
                    let rhs = stableRank($1, salt: UInt64(attempt) ^ UInt64(baseIndex))
                    return lhs == rhs ? $0 < $1 : lhs < rhs
                }
                search(tail, index: 0, board: initial,
                       salt: UInt64(attempt) ^ UInt64(baseIndex), best: &best)
            }
            if let best, best.entries.count >= 8 {
                generated = (base, best)
                break
            }
        }

        if let generated, let extent = bounds(of: generated.board) {
            let normalized = generated.board.entries.map {
                Entry(word: $0.word,
                      row: $0.row - extent.minRow,
                      col: $0.col - extent.minCol,
                      direction: $0.direction)
            }
            var rng = SeededGenerator(seed: seed ^ 0xA11_6A2)
            let wheel = rng.shuffled(Array(generated.base))
            return .init(id: "any-\(seed)",
                         letters: wheel,
                         answers: normalized.map(\.word),
                         boardRows: extent.maxRow - extent.minRow + 1,
                         boardCols: extent.maxCol - extent.minCol + 1,
                         entries: normalized)
        }

        // Guaranteed eight-word fallback. Coordinates are normalized from a
        // validated connected 7×8 layout; all words use COMPRA's six letters.
        let fallbackBase = "COMPRA"
        let fallbackEntries: [Entry] = [
            Entry(word: "COMPRA", row: 4, col: 2, direction: .horizontal),
            Entry(word: "MAR", row: 4, col: 4, direction: .vertical),
            Entry(word: "COMA", row: 4, col: 2, direction: .vertical),
            Entry(word: "CAMPO", row: 0, col: 3, direction: .vertical),
            Entry(word: "PARO", row: 2, col: 6, direction: .vertical),
            Entry(word: "AMOR", row: 6, col: 1, direction: .horizontal),
            Entry(word: "ROPA", row: 1, col: 0, direction: .horizontal),
            Entry(word: "RAMO", row: 1, col: 0, direction: .vertical)
        ]
        var rng = SeededGenerator(seed: seed ^ 0xA11_6A2)
        return .init(id: "any-\(seed)",
                     letters: rng.shuffled(Array(fallbackBase)),
                     answers: fallbackEntries.map(\.word),
                     boardRows: 7,
                     boardCols: 8,
                     entries: fallbackEntries)
    }
}
#endif

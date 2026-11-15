#if os(iOS)
//
//  MiniCrossword.swift — News Raider
//  Interlocked mini crossword. Unlike the sparse criss-cross the classic
//  generator produces (words touching at a single letter, ~25% of letters
//  checked), every cell here belongs to at least one entry and most belong to
//  two, so solving one word genuinely helps with its neighbours.
//

import Foundation

enum MiniCrosswordGenerator {

    // MARK: Shapes

    /// A grid shape: rows × cols plus the blocked cells.
    ///
    /// Both the sizes and the block placements were measured rather than
    /// guessed. A fully dense grid (every letter in an across *and* a down
    /// word) is unsolvable at this bank size: the odds of a random column
    /// spelling a word are ~0.03%, and a 5×5 needs five of them at once, so
    /// the search exhausts its tree in ~6k steps. Blocked cells break that
    /// deadlock; each shape below was verified to solve on 10/10 seeds with
    /// 10 distinct grids, no orphan cells and no filler clues.
    struct Shape {
        let rows: Int
        let cols: Int
        let blocks: [GridCell]
        /// Percentage of playable cells that belong to both an across and a
        /// down word. Larger grids need more blocks, so this drops with size.
        let interlock: Int

        static func make(_ rows: Int, _ cols: Int, _ pairs: [(Int, Int)], _ interlock: Int) -> Shape {
            Shape(rows: rows, cols: cols,
                  blocks: pairs.map { GridCell(row: $0.0, col: $0.1) },
                  interlock: interlock)
        }
    }

    /// Shapes grouped by day of week, so the puzzle changes shape and length
    /// through the week: quick grids on weekdays, the bigger ones at the
    /// weekend when there is more time to sit with them.
    static let shapesByWeekday: [[Shape]] = [
        // 0 · Sunday — biggest
        [.make(7, 7, [(0,3),(1,1),(1,3),(2,1),(3,2),(3,4),(4,5),(5,3),(5,5),(6,3)], 67),
         .make(7, 7, [(0,5),(1,3),(1,5),(3,1),(3,2),(3,4),(3,5),(5,1),(5,3),(6,1)], 67)],
        // 1 · Monday — smallest, most interlocked
        [.make(5, 5, [(0,0),(1,0),(1,1),(3,3),(3,4),(4,4)], 89),
         .make(5, 5, [(0,0),(1,1),(3,3),(4,4)], 81),
         .make(5, 5, [(0,0),(1,3),(3,1),(4,4)], 81)],
        // 2 · Tuesday
        [.make(5, 5, [(1,3),(1,4),(3,0),(3,1)], 81),
         .make(5, 5, [(0,1),(0,2),(0,4),(4,0),(4,2),(4,3)], 79),
         .make(5, 5, [(0,0),(0,2),(0,3),(4,1),(4,2),(4,4)], 79)],
        // 3 · Wednesday
        [.make(6, 5, [(0,4),(1,0),(1,1),(4,3),(4,4),(5,0)], 83),
         .make(6, 5, [(0,1),(2,4),(3,0),(5,3)], 77),
         .make(6, 5, [(1,4),(2,1),(3,3),(4,0)], 69)],
        // 4 · Thursday
        [.make(7, 5, [(0,0),(0,1),(1,0),(1,1),(3,1),(3,3),(5,3),(5,4),(6,3),(6,4)], 80),
         .make(7, 5, [(1,4),(2,3),(4,1),(5,0)], 74),
         .make(7, 5, [(0,3),(1,0),(2,3),(4,1),(5,4),(6,1)], 72)],
        // 5 · Friday
        [.make(6, 6, [(0,3),(0,4),(1,0),(4,5),(5,1),(5,2)], 87),
         .make(6, 6, [(0,1),(0,5),(1,2),(4,3),(5,0),(5,4)], 73),
         .make(6, 6, [(0,0),(0,5),(1,0),(2,2),(3,3),(4,5),(5,0),(5,5)], 71)],
        // 6 · Saturday
        [.make(7, 6, [(0,0),(0,4),(0,5),(1,4),(2,3),(4,2),(5,1),(6,0),(6,1),(6,5)], 69),
         .make(7, 6, [(1,5),(2,1),(2,2),(4,3),(4,4),(5,0)], 67),
         .make(6, 6, [(0,3),(0,4),(1,0),(4,5),(5,1),(5,2)], 87)]
    ]

    private struct Slot {
        let cells: [GridCell]
        let across: Bool
        var length: Int { cells.count }
    }

    // MARK: Entry points

    /// The daily puzzle: shape follows the weekday, seed follows the date.
    static func daily(dayIndex: Int, language: PuzzleLanguage = .spanish) -> CrosswordPuzzle? {
        let shapes = shapesByWeekday[((dayIndex % 7) + 7) % 7]
        let seed = UInt64(abs(dayIndex)) &* 131 &+ 251
        for offset in 0..<(shapes.count * 3) {
            let shape = shapes[offset % shapes.count]
            if let puzzle = build(shape: shape,
                                  seed: seed &+ UInt64(offset) &* 7919,
                                  id: "\(language == .english ? "en-" : "")minicross-d\(dayIndex)", language: language) {
                return puzzle
            }
        }
        return language == .english ? EnglishPuzzleLexicon.crossword(id: "en-minicross-d\(dayIndex)", variant: UInt64(bitPattern: Int64(dayIndex))) : nil
    }

    /// A one-off puzzle, for the "new puzzle" action. Picks any shape.
    static func generate(seed: UInt64, language: PuzzleLanguage = .spanish) -> CrosswordPuzzle? {
        var rng = SeededGenerator(seed: seed)
        let all = shapesByWeekday.flatMap { $0 }
        for shape in rng.shuffled(all) {
            if let puzzle = build(shape: shape, seed: rng.next(), id: "\(language == .english ? "en-" : "")minicross-\(seed)", language: language) {
                return puzzle
            }
        }
        return language == .english ? EnglishPuzzleLexicon.crossword(id: "en-minicross-\(seed)", variant: seed) : nil
    }

    // MARK: Construction

    private static func build(shape: Shape, seed: UInt64, id: String, language: PuzzleLanguage) -> CrosswordPuzzle? {
        // Only words that carry a real clue are eligible. Filling gaps with
        // bare vocabulary would mean shipping "Palabra de N letras" as a clue,
        // which is not a clue at all: the cell becomes unsolvable.
        // Iterating a Dictionary has no stable order *between runs*: Swift
        // seeds its hashing per process, so the same puzzle seed produced a
        // different grid on every launch. Saved letters then no longer matched
        // the redrawn grid. Sorting pins the order to the data, not the run.
        let clueText = Dictionary((language == .english ? EnglishPuzzleLexicon.clues : PuzzleLexicon.clues).map { ($0.word, $0.clue) },
                                  uniquingKeysWith: { a, _ in a })
        var byLength: [Int: [String]] = [:]
        for clue in (language == .english ? EnglishPuzzleLexicon.clues : PuzzleLexicon.clues) where clue.word.allSatisfy(\.isLetter) {
            byLength[clue.word.count, default: []].append(clue.word)
        }
        for key in byLength.keys { byLength[key]?.sort() }

        let slots = makeSlots(shape: shape)
        guard slots.count >= 6 else { return nil }
        guard slots.allSatisfy({ (byLength[$0.length]?.count ?? 0) >= 3 }) else { return nil }

        var rng = SeededGenerator(seed: seed)
        var pools: [Int: [String]] = [:]
        let lengths = Set(slots.map(\.length))
        for length in lengths.sorted() {   // también en español: un Set no tiene orden estable entre ejecuciones
            pools[length] = rng.shuffled(byLength[length] ?? [])
        }

        var letters: [GridCell: Character] = [:]
        var used = Set<String>()
        var steps = 0
        guard fill(slots: slots, pools: pools, letters: &letters,
                   used: &used, steps: &steps) else { return nil }

        let entries: [CrossEntry] = slots.compactMap { slot in
            let word = String(slot.cells.map { letters[$0] ?? " " })
            guard let clue = clueText[word], let first = slot.cells.first else { return nil }
            return CrossEntry(word: word, clue: clue, dir: slot.across ? "H" : "V",
                              row: first.row, col: first.col, len: word.count)
        }
        // Every slot must have produced a clued entry; a partial grid would
        // leave the player staring at a word with no definition.
        guard entries.count == slots.count else { return nil }

        let solution = Dictionary(uniqueKeysWithValues:
            letters.map { ($0.key.key, String($0.value)) })
        return CrosswordPuzzle(id: id,
                               size: max(shape.rows, shape.cols),
                               rows: shape.rows,
                               cols: shape.cols,
                               blocks: shape.blocks.map { [$0.row, $0.col] },
                               solution: solution,
                               entries: entries.sorted {
                                   ($0.row, $0.col, $0.dir) < ($1.row, $1.col, $1.dir)
                               },
                               full: true)
    }

    private static func makeSlots(shape: Shape) -> [Slot] {
        let blocked = Set(shape.blocks)
        var slots: [Slot] = []
        for row in 0..<shape.rows {
            var run: [GridCell] = []
            for col in 0...shape.cols {
                let cell = GridCell(row: row, col: col)
                if col < shape.cols, !blocked.contains(cell) { run.append(cell) }
                else {
                    if run.count >= 3 { slots.append(Slot(cells: run, across: true)) }
                    run = []
                }
            }
        }
        for col in 0..<shape.cols {
            var run: [GridCell] = []
            for row in 0...shape.rows {
                let cell = GridCell(row: row, col: col)
                if row < shape.rows, !blocked.contains(cell) { run.append(cell) }
                else {
                    if run.count >= 3 { slots.append(Slot(cells: run, across: false)) }
                    run = []
                }
            }
        }
        return slots
    }

    /// Backtracking search, always expanding the most constrained slot first.
    /// An interlocked grid is a constraint problem, not incremental placement:
    /// a greedy fill strands itself almost immediately.
    private static func fill(slots: [Slot],
                             pools: [Int: [String]],
                             letters: inout [GridCell: Character],
                             used: inout Set<String>,
                             steps: inout Int,
                             budget: Int = 150_000) -> Bool {
        if slots.isEmpty { return true }
        steps += 1
        if steps > budget { return false }

        func candidates(_ slot: Slot) -> [String] {
            let pattern = slot.cells.map { letters[$0] }
            var out: [String] = []
            for word in pools[slot.length] ?? [] where !used.contains(word) {
                var ok = true
                for (index, char) in word.enumerated() where pattern[index] != nil {
                    if pattern[index] != char { ok = false; break }
                }
                if ok {
                    out.append(word)
                    if out.count > 90 { break }
                }
            }
            return out
        }

        var bestIndex = 0
        var best: [String] = []
        var bestCount = Int.max
        for (index, slot) in slots.enumerated() {
            let options = candidates(slot)
            if options.count < bestCount {
                bestCount = options.count
                bestIndex = index
                best = options
            }
            if bestCount == 0 { break }
        }
        guard bestCount > 0 else { return false }

        let slot = slots[bestIndex]
        var rest = slots
        rest.remove(at: bestIndex)

        for word in best.prefix(30) {
            let saved = slot.cells.map { ($0, letters[$0]) }
            for (index, cell) in slot.cells.enumerated() {
                letters[cell] = Array(word)[index]
            }
            used.insert(word)
            if fill(slots: rest, pools: pools, letters: &letters,
                    used: &used, steps: &steps, budget: budget) { return true }
            used.remove(word)
            for (cell, old) in saved {
                if let old { letters[cell] = old } else { letters.removeValue(forKey: cell) }
            }
        }
        return false
    }
}
#endif

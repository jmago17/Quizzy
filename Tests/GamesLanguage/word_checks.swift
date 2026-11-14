// Exercises production generators, including all curated English variants.
func runWordLanguageChecks() {
    func checkCrossword(_ p: CrosswordPuzzle) {
        precondition(p.rows > 0 && p.cols > 0 && p.entries.count >= 6)
        var covered = Set<String>()
        for e in p.entries {
            precondition(e.len == e.word.count && !e.clue.isEmpty)
            for (i, letter) in e.word.enumerated() {
                let r = e.row + (e.dir == "H" ? 0 : i)
                let c = e.col + (e.dir == "H" ? i : 0)
                precondition((0..<p.rows).contains(r) && (0..<p.cols).contains(c))
                let key = "\(r),\(c)"
                precondition(p.solution[key] == String(letter))
                precondition(!p.blockSet.contains(GridCell(row: r, col: c)))
                covered.insert(key)
            }
        }
        precondition(covered == Set(p.solution.keys))
        precondition(covered.count + p.blocks.count == p.rows * p.cols)
    }
    var quartileVariants = Set<String>(), wheelVariants = Set<String>(), miniVariants = Set<String>()
    for seed in UInt64(0)..<21 {
        let q = ProceduralPuzzleGenerator.quartiles(seed: seed, language: .english)!
        precondition(q.id == "en-q-gen-\(seed)" && q.tiles.count == 20 && q.targets.count == 5)
        quartileVariants.insert(q.targets.sorted().joined(separator: ","))
        var attainable = Set<String>()
        func search(_ prefix: String, _ used: Set<Int>) {
            if q.allValid.contains(prefix) { attainable.insert(prefix) }
            guard used.count < 4 else { return }
            for i in q.tiles.indices where !used.contains(i) { search(prefix + q.tiles[i], used.union([i])) }
        }
        search("", [])
        precondition(attainable == q.allValid)
        precondition(q.allValid.reduce(0) { $0 + q.points(for: $1) } == q.maxScore)
        precondition(q.maxScore >= q.targetScore)
        let w = ProceduralPuzzleGenerator.wordSearch(seed: seed, language: .english)!
        precondition(w.words.count == 10 && w.grid.count == w.size && w.grid.allSatisfy { $0.count == w.size })
        for word in w.words {
            precondition(EnglishPuzzleLexicon.wordSet.contains(word.word))
            precondition(word.cells.count == word.word.count)
            precondition(word.cells.map { w.grid[$0[0]][$0[1]] }.joined() == word.word)
        }
        let c = ProceduralPuzzleGenerator.crossword(seed: seed, language: .english)!
        checkCrossword(c)
        precondition(c.entries.allSatisfy { entry in EnglishPuzzleLexicon.cluePairs.contains { $0.0 == entry.word && $0.1 == entry.clue } })
        let mini = MiniCrosswordGenerator.daily(dayIndex: Int(seed), language: .english)!
        checkCrossword(mini)
        miniVariants.insert(mini.solution.sorted { $0.key < $1.key }.map { $0.value }.joined())
        let a = AnygramPuzzle.generate(seed: seed, language: .english)!
        wheelVariants.insert(String(a.letters.sorted()))
        precondition(a.answers.count >= 8 && a.answers.count == a.entries.count)
        var cells: [GridCell: Character] = [:]
        for entry in a.entries {
            var counts = Dictionary(a.letters.map { ($0, 1) }, uniquingKeysWith: +)
            precondition(EnglishPuzzleLexicon.wordSet.contains(entry.word))
            for (cell, letter) in zip(entry.cells, entry.word) {
                precondition((0..<a.boardRows).contains(cell.row) && (0..<a.boardCols).contains(cell.col))
                precondition(cells[cell] == nil || cells[cell] == letter)
                cells[cell] = letter
                counts[letter, default: 0] -= 1
                precondition(counts[letter]! >= 0)
            }
        }
        let h = HashtagPuzzle.generate(seed: seed, language: .english)
        var hc: [GridCell: Character] = [:]
        for word in h.words {
            precondition(word.answer.count == 5 && EnglishPuzzleLexicon.wordSet.contains(word.answer))
            for (cell, letter) in zip(word.cells, word.answer) {
                precondition(hc[cell] == nil || hc[cell] == letter)
                hc[cell] = letter
            }
        }
        precondition(hc.values.sorted() == h.letters.sorted())
        let d = WordlePuzzle.daily(dayIndex: Int(seed), language: .english)
        precondition(d.answer.count == 5 && EnglishPuzzleLexicon.wordSet.contains(d.answer))
    }
    precondition(quartileVariants.count >= 3 && wheelVariants.count >= 3 && miniVariants.count >= 3)
    for variant in UInt64(0)..<3 { checkCrossword(EnglishPuzzleLexicon.crossword(id: "test", variant: variant)) }
    print("PASS English word games: 21 seeds, three Quartiles/Anygram/mini variants, grid letters, crossings, clues, word validity and reachable score")
}

@main
struct GamesLanguageChecks {
    @MainActor static func main() async {
        defer { testDefaults.removePersistentDomain(forName: testSuiteName) }
        precondition(AppLanguage.resolve("es", preferredLanguages: ["en-US"]) == .spanish)
        precondition(AppLanguage.resolve("en", preferredLanguages: ["es-ES"]) == .english)
        precondition(AppLanguage.resolve("system", preferredLanguages: ["es-MX"]) == .spanish)
        precondition(AppLanguage.resolve("system", preferredLanguages: ["fr-FR", "en-US"]) == .english)
        precondition(AppLanguage.resolve("system", preferredLanguages: ["fr-FR"]) == .english)
        precondition(AppLanguage.resolve("invalid", preferredLanguages: ["es_ES"]) == .spanish)
        precondition(AppLanguage.resolve(nil, preferredLanguages: []) == .english)
        testDefaults.set(["es-ES"], forKey: "AppleLanguages")
        for choice in ["es", "en", "system"] {
            AppLanguage.setSelection(choice, in: testDefaults)
            precondition(AppLanguage.selected(in: testDefaults) == choice)
            precondition(testDefaults.stringArray(forKey: "AppleLanguages") == ["es-ES"])
        }
        AppLanguage.setSelection("invalid", in: testDefaults)
        precondition(AppLanguage.selected(in: testDefaults) == "system")
        precondition(PuzzleKind.allCases.count == 11)  // +Decoder
        precondition(!PuzzleKind.allCases.contains(.trivia) && !PuzzleKind.allCases.contains(.numbers) && !PuzzleKind.allCases.contains(.ladder))
        catalogDefinitionChecks()
        localizedMetadataChecks()
        precondition(!PuzzleLexicon.words.isEmpty && !PuzzleLexicon.clues.isEmpty, "Real Spanish resources must load")
        let mode = CommandLine.arguments.dropFirst().first ?? "all"
        if mode == "all" || mode == "english" {
            stage("English word checks")
            runWordLanguageChecks()
            stage("logic checks")
            runLogicLanguageChecks()
        }
        if mode == "all" || mode == "spanish" { spanishAndMazeChecks() }
        if mode == "spanish-anygram" { spanishAnygramChecks() }
        if mode == "spanish-wide" { stage("Spanish wide"); spanishWideChecks() }
        if mode == "fingerprint" { fingerprintChecks() }
        if mode == "all" || mode == "progress" {
            stage("progress checks")
            await progressChecks()
            catalogProgressChecks()
        }
        print("PASS mode: \(mode); language selection/persistence and catalog ES10/EN9 checked in every mode")
    }

    static func stage(_ message: String) {
        FileHandle.standardOutput.write(Data("Stage: \(message)\n".utf8))
    }

    static func catalogDefinitionChecks() {
        let es = PuzzleKind.offered(in: .spanish), en = PuzzleKind.offered(in: .english)
        precondition(es == PuzzleKind.allCases && es.count == 11)
        precondition(en == es.filter { $0 != .quartiles } && en.count == 10)
        precondition(en.first == .wordsearch && !en.contains(.quartiles))
        precondition(PuzzleKind(rawValue: "quartiles") == .quartiles)
        print("PASS offered catalog: ES11 / EN10; Quartiles remains decodable")
    }

    @MainActor static func catalogProgressChecks() {
        let progress = PuzzleProgress.shared
        let original = AppLanguage.selected(in: testDefaults)
        defer { AppLanguage.setSelection(original, in: testDefaults) }
        let seed = PuzzleSeed.daily(kind: .quartiles)
        let esID = progress.dailyID(kind: .quartiles, seed: seed, language: .spanish)
        let enID = progress.dailyID(kind: .quartiles, seed: seed, language: .english)
        progress.setFound(esID, ["EXISTING-SPANISH"])
        progress.setFound(enID, ["EXISTING-ENGLISH"])
        progress.setFill(esID, ["0,0": "S"])
        progress.setElapsed(esID, 73)
        AppLanguage.setSelection("en", in: testDefaults)
        precondition(progress.firstPending != .quartiles)
        for kind in PuzzleKind.allCases { precondition(progress.nextPending(after: kind) != .quartiles) }
        // Nine offered games complete a day, even with the retained Quartiles game unfinished.
        precondition(!progress.isDone(enID))
        for kind in PuzzleKind.offered(in: .english) {
            let id = progress.dailyID(kind: kind, seed: PuzzleSeed.daily(kind: kind), language: .english)
            progress.markDone(id)
            progress.rememberTodaysPuzzleID(id, kind: kind)
        }
        precondition(progress.doneCount == 10 && progress.firstPending == nil)
        progress.noteDayIfComplete()
        precondition(progress.streak >= 1)
        precondition(progress.found(enID) == ["EXISTING-ENGLISH"] && !progress.isDone(enID))
        AppLanguage.setSelection("es", in: testDefaults)
        precondition(PuzzleKind.offered(in: .spanish).contains(.quartiles))
        precondition(progress.firstPending == .quartiles)
        precondition(progress.found(esID) == ["EXISTING-SPANISH"])
        precondition(progress.fill(esID) == ["0,0": "S"] && progress.elapsed(esID) == 73)
        print("PASS EN recommendations/daily totals exclude Quartiles; ten games complete day; ES and EN saved Quartiles data preserved")
    }

    @MainActor static func localizedMetadataChecks() {
        let expected: [PuzzleKind: String] = [
            .quartiles: "Quartiles", .wordsearch: "Word Search", .crossword: "Crossword",
            .maze: "Maze", .wordle: "Wordle", .anygram: "Anygram", .hashtag: "Hashtag",
            .murdle: "Murdle", .murdoku: "Murdoku", .minicross: "Mini Crossword", .decoder: "Decoder"
        ]
        let original = AppLanguage.selected(in: testDefaults)
        defer { AppLanguage.setSelection(original, in: testDefaults) }
        AppLanguage.setSelection("en", in: testDefaults)
        for kind in PuzzleKind.allCases {
            precondition(kind.title == expected[kind], "Unexpected English title: \(kind.title)")
            precondition(!kind.blurb.isEmpty)
            let combined = kind.blurb + " " + kind.difficulty
            precondition(!combined.contains(where: { "áéíóúñ¿¡".contains($0) }))
            for spanish in ["Combina", "Encuentra", "Resuelve", "Adivina", "Reconstruye", "Sitúa", "Rejilla", "Difícil", "Fácil", "Medio"] {
                precondition(!combined.contains(spanish), "Spanish game metadata in English: \(combined)")
            }
        }
        print("PASS English title/blurb/difficulty metadata for all eleven games")
    }

    static func spanishAndMazeChecks() {
        for seed in UInt64(1)...1 {
            stage("Spanish wordsearch seed \(seed)")
            let w = ProceduralPuzzleGenerator.wordSearch(seed: seed, language: .spanish)!
            precondition(w.grid.count == w.size && w.grid.allSatisfy { $0.count == w.size })
            precondition(w.words.count == 10)
            for word in w.words {
                precondition(word.cells.count == word.word.count)
                precondition(word.cells.map { w.grid[$0[0]][$0[1]] }.joined() == word.word)
            }
            stage("Spanish Quartiles seed \(seed)")
            let q = ProceduralPuzzleGenerator.quartiles(seed: seed, language: .spanish)!
            precondition(q.tiles.count == 20 && q.targets.count == 5 && q.maxScore >= 100)
            for target in q.targets {
                func compose(_ remaining: String, _ used: Set<Int>) -> Bool {
                    if remaining.isEmpty { return used.count == 4 }
                    guard used.count < 4 else { return false }
                    return q.tiles.indices.contains { i in
                        !used.contains(i) && remaining.hasPrefix(q.tiles[i])
                        && compose(String(remaining.dropFirst(q.tiles[i].count)), used.union([i]))
                    }
                }
                precondition(compose(target, []))
            }
            stage("Spanish crossword and Mini seed \(seed)")
            let crosswords = [ProceduralPuzzleGenerator.crossword(seed: seed, language: .spanish),
                              MiniCrosswordGenerator.daily(dayIndex: Int(seed), language: .spanish)]
            for candidate in crosswords {
                guard let c = candidate else { preconditionFailure("Spanish generation failed") }
                var covered = Set<String>()
                for e in c.entries {
                    precondition(e.word.count == e.len && !e.clue.isEmpty)
                    for (cell, letter) in zip(e.cells, e.word) {
                        precondition(cell.row >= 0 && cell.row < c.rows && cell.col >= 0 && cell.col < c.cols)
                        precondition(c.solution[cell.key] == String(letter) && !c.blockSet.contains(cell))
                        covered.insert(cell.key)
                    }
                }
                precondition(covered == Set(c.solution.keys))
            }
            stage("Spanish Hashtag / Wordle / shared Maze seed \(seed)")
            let h = HashtagPuzzle.generate(seed: seed, language: .spanish)
            for word in h.words {
                for (cell, letter) in zip(word.cells, word.answer) { precondition(h.solution[cell] == letter) }
            }
            precondition(h.letters.sorted() == h.solution.values.sorted())
            let d = WordlePuzzle.daily(dayIndex: Int(seed), language: .spanish)
            precondition(d.answer.count == 5 && PuzzleLexicon.wordSet.contains(d.answer))
            let maze = MazePuzzle.generate(seed: seed)
            let origin = GridCell(row: 0, col: maze.entranceCol)
            var seen: Set<GridCell> = [origin], queue = [origin]
            while !queue.isEmpty {
                let cell = queue.removeFirst()
                for next in [GridCell(row: cell.row-1, col: cell.col), GridCell(row: cell.row+1, col: cell.col),
                             GridCell(row: cell.row, col: cell.col-1), GridCell(row: cell.row, col: cell.col+1)] {
                    if maze.canMove(from: cell, to: next) {
                        precondition(maze.canMove(from: next, to: cell))
                        if seen.insert(next).inserted { queue.append(next) }
                    }
                }
            }
            precondition(seen.count == maze.rows * maze.cols)
            precondition(seen.contains(GridCell(row: maze.rows-1, col: maze.exitCol)))
        }
        print("PASS Spanish wordsearch, Quartiles, crossword, Mini, Hashtag, Wordle: one seed; shared Maze fully connected with symmetric passages")
        print("NOT RUN in bounded suite: Spanish Anygram generation (existing broad vocabulary search); use --mode spanish-anygram")
    }

    static func spanishAnygramChecks() {
        let seed: UInt64 = 1
        stage("Spanish Anygram seed 1: existing exhaustive vocabulary search")
            let a = AnygramPuzzle.generate(seed: seed, language: .spanish)!
            var occupied: [GridCell: Character] = [:]
            for e in a.entries {
                var letters = Array(a.letters)
                for (cell, letter) in zip(e.cells, e.word) {
                    precondition(occupied[cell] == nil || occupied[cell] == letter)
                    occupied[cell] = letter
                    guard let i = letters.firstIndex(of: letter) else { preconditionFailure("Wheel multiplicity") }
                    letters.remove(at: i)
                }
            }
        print("PASS Spanish Anygram: one seed, crossing letters and wheel multiplicity")
    }

    @MainActor static func progressChecks() async {
        let progress = PuzzleProgress.shared
        AppLanguage.setSelection("es", in: testDefaults)
        let kind = PuzzleKind.wordsearch
        let seed = PuzzleSeed.daily(kind: kind)
        let esID = progress.dailyID(kind: kind, seed: seed)
        progress.setFound(esID, ["CASA"])
        progress.setFill(esID, ["0,0": "C"])
        progress.setElapsed(esID, 37)
        progress.addHint(esID)
        progress.markDone(esID)
        progress.rememberTodaysPuzzleID(esID, kind: kind)
        progress.rememberWordleAnswer("CASAS", language: .spanish)
        progress.recordTime(40, kind: kind, puzzleID: esID)
        let oldDictionary = testDefaults.dictionary(forKey: "newsraider.puzzles")! as NSDictionary
        AppLanguage.setSelection("en", in: testDefaults)
        let enID = progress.dailyID(kind: kind, seed: seed)
        precondition(enID == "en-" + esID)
        precondition(!progress.isDoneToday(kind) && progress.found(enID).isEmpty)
        precondition(progress.best(kind) == nil && progress.recentWordleAnswers().isEmpty)
        precondition((testDefaults.dictionary(forKey: "newsraider.puzzles")! as NSDictionary) == oldDictionary)
        progress.setFound(enID, ["HOUSE"])
        progress.rememberTodaysPuzzleID(enID, kind: kind)
        progress.rememberWordleAnswer("HOUSE", language: .english)
        progress.recordTime(65, kind: kind, puzzleID: enID)
        AppLanguage.setSelection("es", in: testDefaults)
        precondition(progress.isDoneToday(kind))
        precondition(progress.found(esID) == ["CASA"] && progress.fill(esID) == ["0,0": "C"])
        precondition(progress.elapsed(esID) == 37 && progress.hintsUsed(esID) == 1)
        precondition(progress.best(kind) == 40 && progress.recentWordleAnswers() == ["CASAS"])
        precondition(progress.todaysPuzzleID(kind) == esID)
        precondition(progress.todaysPuzzleID(kind, language: .english) == enID)
        precondition(progress.dailyID(kind: .maze, seed: seed, language: .spanish) == progress.dailyID(kind: .maze, seed: seed, language: .english))
        let grid = ProceduralPuzzleGenerator.wordSearch(seed: 99, language: .english)!
        PuzzleSnapshotStore.save(.wordSearch(grid), kind: kind, language: .english, day: 100, defaults: testDefaults)
        guard case .wordSearch(let restored) = PuzzleSnapshotStore.load(kind: kind, language: .english, day: 100, defaults: testDefaults) else { preconditionFailure("Snapshot missing") }
        precondition(restored.id == grid.id && restored.grid == grid.grid && restored.words == grid.words)
        precondition(PuzzleSnapshotStore.load(kind: kind, language: .spanish, day: 100, defaults: testDefaults) == nil)
        // Simultaneous generation uses its explicit input, never a shared mutable bank.
        await withTaskGroup(of: WordSearchPuzzle?.self) { group in
            for i in 0..<8 {
                let language: PuzzleLanguage = i.isMultiple(of: 2) ? .english : .spanish
                group.addTask { ProceduralPuzzleGenerator.wordSearch(seed: UInt64(i), language: language) }
            }
            for await result in group {
                let p = result!
                if p.id.hasPrefix("en-") { precondition(p.words.allSatisfy { EnglishPuzzleLexicon.words.contains($0.word) }) }
                else { precondition(p.words.allSatisfy { PuzzleLexicon.commonWords.contains($0.word) }) }
            }
        }
    }
}

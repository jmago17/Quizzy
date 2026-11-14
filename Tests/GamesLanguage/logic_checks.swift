// Compiled with source-extracted MurdlePuzzle/MurdokuPuzzle models, Foundation,
// GridCell, SeededGenerator, PuzzleLanguage, and AppLanguage by the test runner.
func runLogicLanguageChecks() {
    precondition(MurdlePuzzle.themes.count == 8)
    precondition(MurdlePuzzle.englishThemes.count == 8)
    for (es, en) in zip(MurdlePuzzle.themes, MurdlePuzzle.englishThemes) {
        precondition(es.id == en.id && es.kind == en.kind)
        precondition(es.suspects == en.suspects)
        precondition(es.places.count == en.places.count && es.weapons.count == en.weapons.count)
        precondition(es.titles.count == en.titles.count && es.victims.count == en.victims.count)
        precondition(zip(es.weapons, en.weapons).allSatisfy { $0.kind == $1.kind })
    }
    for seed in UInt64(0)..<100 {
        for difficulty in MurdlePuzzle.Difficulty.allCases {
            let es = MurdlePuzzle.generate(seed: seed, difficulty: difficulty, language: .spanish)
            let en = MurdlePuzzle.generate(seed: seed, difficulty: difficulty, language: .english)
            precondition(en.id == "en-" + es.id && es.id == "murdle-\(seed)")
            precondition(es.suspects == en.suspects && es.suspects.count == difficulty.rawValue)
            precondition(es.suspects.firstIndex(of: es.culprit.suspect) == en.suspects.firstIndex(of: en.culprit.suspect))
            for (a, b) in zip(es.assignments, en.assignments) {
                precondition(a.suspect == b.suspect)
                precondition(es.places.firstIndex(of: a.place) == en.places.firstIndex(of: b.place))
                precondition(es.weapons.firstIndex(of: a.weapon) == en.weapons.firstIndex(of: b.weapon))
            }
            for p in [es, en] {
                precondition(Set(p.assignments.map(\.place)).count == p.suspects.count)
                precondition(Set(p.assignments.map(\.weapon)).count == p.suspects.count)
                // N-1 direct suspect/place facts and N-1 place/item facts uniquely
                // determine both bijections by elimination, including the culprit.
                let bank = p.language == .english ? MurdlePuzzle.englishThemes : MurdlePuzzle.themes
                let theme = bank.first { $0.label == p.themeLabel }!
                var trueStatements = Set<String>()
                for a in p.assignments {
                    let phrase = theme.places.first { $0.name == a.place }!.phrase
                    if p.language == .english {
                        trueStatements.insert("\(a.suspect) was in \(phrase).")
                        trueStatements.insert("The person in \(phrase) carried the \(a.weapon.lowercased()).")
                    } else {
                        trueStatements.insert("\(a.suspect) estaba en \(phrase).")
                        trueStatements.insert("La persona de \(phrase) llevaba \(a.weapon.lowercased()).")
                    }
                    for place in theme.places where place.name != a.place {
                        trueStatements.insert(p.language == .english
                            ? "\(a.suspect) was not in \(place.phrase)."
                            : "\(a.suspect) no estuvo en \(place.phrase).")
                    }
                    for weapon in theme.weapons where weapon.name != a.weapon {
                        trueStatements.insert(p.language == .english
                            ? "\(a.suspect) did not carry the \(weapon.name.lowercased())."
                            : "\(a.suspect) no llevaba \(weapon.name.lowercased()).")
                    }
                }
                precondition(p.clues.allSatisfy { trueStatements.contains($0) })
                let facts = p.clues.filter { !($0.contains(" no ") || $0.contains(" not ")) }
                precondition(facts.count == 2 * (p.suspects.count - 1))
                for a in p.assignments where a.suspect != p.culprit.suspect {
                    precondition(facts.contains { $0.hasPrefix(a.suspect + (p.language == .english ? " was in " : " estaba en ")) })
                    precondition(facts.contains { $0.hasSuffix(a.weapon.lowercased() + ".") })
                }
            }
            precondition(!en.clues.contains { $0.contains(" estaba ") || $0.contains(" llevaba ") })
            precondition(!en.intro.contains("{victim}"))
        }
    }
    func permutations(_ values: [Int]) -> [[Int]] {
        if values.isEmpty { return [[]] }
        return values.flatMap { n in permutations(values.filter { $0 != n }).map { [n] + $0 } }
    }
    let orders = permutations(Array(0..<5))
    func valid(_ p: MurdokuPuzzle, _ cells: [GridCell], _ clue: MurdokuPuzzle.Clue) -> Bool {
        switch clue {
        case .inRoom(let a, let r): return p.room(at: cells[a]) == r
        case .notInRoom(let a, let r): return p.room(at: cells[a]) != r
        case .aloneInRoom(let a, let r): return p.room(at: cells[a]) == r && cells.filter { p.room(at: $0) == r }.count == 1
        case .northOf(let a, let b): return cells[a].row < cells[b].row
        case .westOf(let a, let b): return cells[a].col < cells[b].col
        case .besideObject(let a, let b):
            let x = cells[a], y = p.objects[b].cell
            return p.room(at: x) == p.room(at: y) && abs(x.row-y.row) + abs(x.col-y.col) == 1
        case .northOfObject(let a, let b): return cells[a].row < p.objects[b].cell.row
        case .southOfObject(let a, let b): return cells[a].row > p.objects[b].cell.row
        case .westOfObject(let a, let b): return cells[a].col < p.objects[b].cell.col
        case .eastOfObject(let a, let b): return cells[a].col > p.objects[b].cell.col
        case .onObject(let a, let b): return cells[a] == p.objects[b].cell
        case .cornerOfRoom(let a, let r):
            let c = cells[a]
            func outside(_ row: Int, _ col: Int) -> Bool {
                row < 0 || col < 0 || row >= p.size || col >= p.size || p.roomMap[row][col] != r
            }
            return p.room(at: c) == r && (outside(c.row-1,c.col) || outside(c.row+1,c.col)) && (outside(c.row,c.col-1) || outside(c.row,c.col+1))
        }
    }
    for seed in UInt64(0)..<16 {
        let es = MurdokuPuzzle.generate(seed: seed, language: .spanish)
        let en = MurdokuPuzzle.generate(seed: seed, language: .english)
        precondition(en.id == "en-" + es.id && es.id == "murdoku-\(seed)")
        precondition(es.solution == en.solution && es.roomMap == en.roomMap && es.victim == en.victim)
        precondition(es.suspects == en.suspects && es.clues == en.clues)
        precondition(es.objects.map(\.cell) == en.objects.map(\.cell))
        precondition(es.objects.map(\.kind) == en.objects.map(\.kind))
        for p in [es, en] {
            precondition(p.roomMap.count == 5 && p.roomMap.allSatisfy { $0.count == 5 && $0.allSatisfy { (0..<5).contains($0) } })
            precondition(Set(p.solution.map(\.row)).count == 5 && Set(p.solution.map(\.col)).count == 5)
            precondition(!p.solution.contains(p.victim))
            precondition(p.solution.filter { p.room(at: $0) == p.victimRoom }.count == 1)
            precondition(p.objects.allSatisfy { !$0.kind.blocksPerson || !p.solution.contains($0.cell) })
            precondition(p.clues.allSatisfy { valid(p, p.solution, $0) })
            var solutions = 0
            for rows in orders { for cols in orders {
                let cells = (0..<5).map { GridCell(row: rows[$0], col: cols[$0]) }
                if p.clues.allSatisfy({ valid(p, cells, $0) }) { solutions += 1 }
            } }
            precondition(solutions == 1)
            precondition(p.clues.allSatisfy { !p.clueText($0).isEmpty })
        }
        precondition(en.clues.allSatisfy { !en.clueText($0).contains(" estaba ") })
        precondition(en.objects.allSatisfy { en.objectPhrase($0.id).hasPrefix("the ") })
    }
    print("PASS: 600 bilingual Murdle cases; 32 Murdoku cases with exhaustive unique-solution checks; stable geometry and separate progress IDs")
}

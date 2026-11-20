#if os(iOS) || os(watchOS)
//
//  PuzzleGenerator.swift — News Raider
//  Offline, deterministic procedural generators. A seed reproduces a game.
//

import Foundation

struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed == 0 ? 0x9E3779B97F4A7C15 : seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
    mutating func int(_ upper: Int) -> Int { Int(next() % UInt64(max(1, upper))) }
    mutating func shuffled<T>(_ input: [T]) -> [T] {
        var a = input
        guard a.count > 1 else { return a }
        for i in stride(from: a.count - 1, through: 1, by: -1) {
            a.swapAt(i, int(i + 1))
        }
        return a
    }
}

struct NaturalClue: Codable, Hashable, Sendable {
    let word: String
    let clue: String
    init(word: String, clue: String) { self.word = word; self.clue = clue }
    init(from decoder: Decoder) throws {
        var box = try decoder.unkeyedContainer()
        word = try box.decode(String.self)
        clue = try box.decode(String.self)
    }
}

enum PuzzleLexicon {
    static let words: [String] = load("puzzle_words", as: [String].self) ?? []
    static let wordSet = Set(words)
    /// A smaller, curated frequent-word set used only to pick puzzle SEEDS
    /// (Quartiles fragments, Wordle answers). Keeping generation on a
    /// tighter vocabulary avoids obscure seed words and — for Quartiles —
    /// avoids "ghost" 4-fragment solutions that only exist because the full
    /// 160k validation dictionary is much broader than what a reasonable
    /// puzzle should ever require.
    static let commonWords: [String] = load("common_words", as: [String].self) ?? words
    /// Words a player could plausibly know: the frequent list plus inflected
    /// forms of frequent stems (AGUANTARE, AGUJEREAN, RESULTASE...), minus
    /// dictionary curiosities nobody would ever guess (DESBAGASE, ASTAMENTA).
    /// Used to accept plays in Quartiles without rejecting real Spanish.
    /// `commonWords` sin formas que solo son conjugación (ABANDONASTE, COMPROMETA...). De aquí
    /// salen las SOLUCIONES de Quartiles y Sopa de letras; las jugadas se siguen aceptando con
    /// las listas amplias. Generada con `Tools/lexicon/` (ver README allí).
    static let answerWords: [String] = load("answer_words", as: [String].self) ?? commonWords
    static let playableWords: [String] = load("playable_words", as: [String].self) ?? words
    static let playableSet = Set(playableWords)
    /// Hand-filtered 5-letter answers for Wordle: common nouns and adjectives
    /// only — no conjugations, no proper nouns, no dictionary curiosities.
    static let wordleAnswers: [String] = load("wordle_answers", as: [String].self) ?? []
    static let clues: [NaturalClue] = load("natural_clues", as: [NaturalClue].self) ?? []

    private static func load<T: Decodable>(_ name: String, as: T.Type) -> T? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
}

enum PuzzleSeed {
    /// Date used for every daily puzzle. In DEBUG a stored offset can shift it
    /// so the daily rotation is testable without waiting for tomorrow.
    static func effectiveDate(_ date: Date = .now) -> Date {
        #if DEBUG
        let offset = UserDefaults(suiteName: "quizzy.games")?
            .integer(forKey: "newsraider.debugDayOffset") ?? 0
        guard offset != 0,
              let shifted = Calendar(identifier: .gregorian)
                  .date(byAdding: .day, value: offset, to: date) else { return date }
        return shifted
        #else
        return date
        #endif
    }

    static func daily(kind: PuzzleKind, date: Date = .now) -> UInt64 {
        let c = Calendar(identifier: .gregorian).dateComponents([.year, .month, .day],
                                                                from: effectiveDate(date))
        let day = UInt64((c.year ?? 0) * 10_000 + (c.month ?? 0) * 100 + (c.day ?? 0))
        let salt: UInt64
        switch kind { case .quartiles: salt=11; case .wordsearch: salt=29; case .crossword: salt=47; case .maze: salt=71; case .wordle: salt=89; case .trivia: salt=101; case .numbers: salt=173; case .anygram: salt=191; case .hashtag: salt=211; case .murdle: salt=233; case .murdoku: salt=241; case .minicross: salt=251; case .ladder: salt=271; case .decoder: salt=DecoderGame.dailySalt }
        return day &* 131 &+ salt
    }
    static func random() -> UInt64 { UInt64.random(in: 1...UInt64.max) }

    /// Days since a fixed epoch — used to walk answer banks in order so a
    /// daily puzzle never repeats until the whole bank has been used.
    static func dayIndex(date: Date = .now) -> Int {
        let cal = Calendar(identifier: .gregorian)
        let epoch = DateComponents(year: 2026, month: 1, day: 1)
        guard let start = cal.date(from: epoch) else { return 0 }
        return cal.dateComponents([.day], from: cal.startOfDay(for: start),
                                  to: cal.startOfDay(for: effectiveDate(date))).day ?? 0
    }
}

enum ProceduralPuzzleGenerator {
    // MARK: Quartiles
    static func quartiles(seed: UInt64, language: PuzzleLanguage = .spanish) -> QuartilePuzzle? {
        if language == .english { return EnglishPuzzleLexicon.quartiles(seed: seed) }
        var rng = SeededGenerator(seed: seed)
        // Seeds and scoring both use the curated frequent-word list. Seeding
        // from the full 160k validation dictionary produced obscure targets
        // (CATETEARA, BAMBONEAR, DELEZNARE...) and "ghost" 4-fragment
        // solutions that inflated the 5-quartile counter with combinations
        // nobody would recognise as real words.
        let lexicon = PuzzleLexicon.answerWords
        let lexiconSet = PuzzleLexicon.playableSet
        let seeds = lexicon.filter {
            (9...12).contains($0.count) && isGoodSeed($0)
        }
        guard seeds.count >= 5 else { return nil }
        var chosen: [(String, [String])] = []
        var usedFragments = Set<String>()

        for word in rng.shuffled(seeds).prefix(800) {
            guard chosen.count < 5 else { break }
            guard let parts = splitFour(word, rng: &rng),
                  Set(parts).count == 4,
                  parts.allSatisfy({ !usedFragments.contains($0) }) else { continue }
            chosen.append((word, parts))
            usedFragments.formUnion(parts)
        }
        guard chosen.count == 5 else { return nil }
        let tiles = rng.shuffled(chosen.flatMap(\.1))
        var solutions = ["1": [String](), "2": [String](), "3": [String](), "4": [String]()]

        // Enumerate ordered combinations. Short bonus words (1-3 fragments)
        // are matched against the curated frequent list so they stay
        // recognisable. 4-fragment words are matched separately against the
        // full validation dictionary: any real word a player assembles must
        // be accepted, even if it wasn't one of the 5 designed targets — see
        // bonusFour below. Only the 5 designed words count as "quartiles"
        // (the 5/5 counter and the +10 bonus), so the goal is never inflated.
        func search(_ prefix: String, _ used: Set<Int>, _ depth: Int) {
            if depth > 0, depth < 4, lexiconSet.contains(prefix) {
                solutions[String(depth), default: []].append(prefix)
            }
            guard depth < 4, prefix.count < 13 else { return }
            for i in tiles.indices where !used.contains(i) {
                var next = used; next.insert(i)
                search(prefix + tiles[i], next, depth + 1)
            }
        }
        search("", [], 0)
        for key in solutions.keys { solutions[key] = Array(Set(solutions[key]!)).sorted() }
        let targetWords = Set(chosen.map(\.0))
        solutions["4"] = targetWords.sorted()

        // 4-fragment words that spell something real in the full dictionary
        // but aren't one of the 5 designed targets: accepted as valid plays,
        // scored like a 3-fragment word, but excluded from the quartile
        // counter/bonus so the 5-quartile goal stays exact.
        var bonusFour = Set<String>()
        func searchBonus(_ prefix: String, _ used: Set<Int>, _ depth: Int) {
            if depth == 4, PuzzleLexicon.playableSet.contains(prefix), !targetWords.contains(prefix) {
                bonusFour.insert(prefix)
            }
            guard depth < 4, prefix.count < 13 else { return }
            for i in tiles.indices where !used.contains(i) {
                var next = used; next.insert(i)
                searchBonus(prefix + tiles[i], next, depth + 1)
            }
        }
        searchBonus("", [], 0)
        let points = ["1": 1, "2": 2, "3": 4, "4": 8]
        // Scoring goal is a flat 100 (see QuartilePuzzle.targetScore): each
        // quartile is worth 8 + 10 bonus, so five of them give 90 and a few
        // short words tip the player over the line. maxScore is kept only as
        // an informational ceiling for the share text.
        let maxScore = solutions.reduce(0) { sum, entry in
            let bonus = entry.key == "4" ? 10 : 0
            return sum + ((points[entry.key] ?? 0) + bonus) * entry.value.count
        } + bonusFour.count * 4
        return QuartilePuzzle(id: "q-gen-\(seed)", tiles: tiles,
                              targets: chosen.map(\.0), solutions: solutions,
                              bonusFour: bonusFour.sorted(),
                              maxScore: maxScore)
    }

    private static func isGoodSeed(_ w: String) -> Bool {
        let bad = ["ABAIS", "AMOS", "ASEIS", "IESE", "IERE", "ARIAIS", "IRIAMOS"]
        return w.allSatisfy { $0.isLetter } && !bad.contains(where: w.contains)
    }

    private static func splitFour(_ word: String, rng: inout SeededGenerator) -> [String]? {
        let n = word.count
        for _ in 0..<30 {
            var lengths: [Int] = [], remaining = n
            for i in 0..<3 {
                let left = 3 - i
                let lo = max(2, remaining - 4 * left)
                let hi = min(4, remaining - 2 * left)
                guard lo <= hi else { break }
                let k = lo + rng.int(hi - lo + 1)
                lengths.append(k); remaining -= k
            }
            guard lengths.count == 3, (2...4).contains(remaining) else { continue }
            lengths.append(remaining)
            var out: [String] = [], index = word.startIndex
            for length in lengths {
                let end = word.index(index, offsetBy: length)
                out.append(String(word[index..<end])); index = end
            }
            return out
        }
        return nil
    }

    // MARK: Word search
    static func wordSearch(seed: UInt64, size: Int = 14, count: Int = 10, language: PuzzleLanguage = .spanish) -> WordSearchPuzzle? {
        var rng = SeededGenerator(seed: seed)
        // Curated frequent words keep the hidden words recognisable even as
        // the grid grows — a bigger haystack should not also hide obscure
        // needles.
        let candidates = (language == .english ? EnglishPuzzleLexicon.words : PuzzleLexicon.answerWords).filter { (4...min(9, size)).contains($0.count) && isGoodSeed($0) }
        var grid = Array(repeating: Array<String?>(repeating: nil, count: size), count: size)
        var placed: [PlacedWord] = []
        let dirs = [(0,1),(1,0),(1,1),(1,-1),(0,-1),(-1,0),(-1,-1),(-1,1)]

        for word in rng.shuffled(candidates).prefix(1200) where placed.count < count {
            var spots: [(Int,Int,Int,Int)] = []
            for r in 0..<size { for c in 0..<size { for (dr,dc) in dirs {
                var ok = true
                for (i,ch) in word.enumerated() {
                    let rr=r+dr*i, cc=c+dc*i
                    if rr < 0 || rr >= size || cc < 0 || cc >= size { ok=false; break }
                    if let old=grid[rr][cc], old != String(ch) { ok=false; break }
                }
                if ok { spots.append((r,c,dr,dc)) }
            } } }
            guard !spots.isEmpty else { continue }
            let (r,c,dr,dc)=spots[rng.int(spots.count)]
            var cells: [[Int]]=[]
            for (i,ch) in word.enumerated() {
                let rr=r+dr*i, cc=c+dc*i; grid[rr][cc]=String(ch); cells.append([rr,cc])
            }
            placed.append(PlacedWord(word: word, cells: cells, clue: nil))
        }
        guard placed.count == count else { return nil }
        // En español el relleno también lleva Ñ: si no, una Ñ en la sopa delataría la palabra.
        let letters = Array(language == .english ? "AAAAAABBCCDDEEEEEEEFGHIIIIIJLLLMMNNOOOOOPQRRRSSSSTTUUUVXYZ"
                                                 : "AAAAAABBCCDDEEEEEEEFGHIIIIIJLLLMMNNÑOOOOOPQRRRSSSSTTUUUVXYZ").map(String.init)
        let complete = grid.map { row in row.map { $0 ?? letters[rng.int(letters.count)] } }
        return WordSearchPuzzle(id: "\(language == .english ? "en-" : "")w-gen-\(seed)", size: size, grid: complete, words: placed)
    }

    // MARK: Crossword with natural clues
    static func crossword(seed: UInt64, size: Int = 9, language: PuzzleLanguage = .spanish) -> CrosswordPuzzle? {
        if language == .english { return crosswordAttempt(seed: seed, idSeed: seed, size: size, language: language) }
        // Algunas semillas no llegan a la densidad mínima (≈1 de cada 40 con el banco actual) y la app
        // caía al autodefinido fijo de puzzles.json. Se reintenta con semillas derivadas, como el Mini.
        // El intento 0 es el de siempre, así que las semillas que ya funcionaban no cambian; el id
        // sigue siendo el de la semilla original (el progreso guardado va por id).
        for attempt in 0..<8 {
            let s = attempt == 0 ? seed : seed &+ UInt64(attempt) &* 0x9E37_79B9_7F4A_7C15
            if let p = crosswordAttempt(seed: s, idSeed: seed, size: size, language: language) { return p }
        }
        return nil
    }

    private static func crosswordAttempt(seed: UInt64, idSeed: UInt64, size: Int, language: PuzzleLanguage) -> CrosswordPuzzle? {
        var rng = SeededGenerator(seed: seed)
        let source = rng.shuffled((language == .english ? EnglishPuzzleLexicon.clues : PuzzleLexicon.clues).filter { (3...9).contains($0.word.count) })
        var letters: [GridCell: Character] = [:]
        var occupied: [GridCell: Set<String>] = [:]
        var entries: [CrossEntry] = []

        func inside(_ p: GridCell) -> Bool {
            (0..<size).contains(p.row) && (0..<size).contains(p.col)
        }

        func canPlace(_ word: String, row: Int, col: Int, across: Bool) -> Bool {
            let chars = Array(word)
            let start = GridCell(row: row, col: col)
            let end = GridCell(row: row + (across ? 0 : chars.count - 1),
                               col: col + (across ? chars.count - 1 : 0))
            guard inside(start), inside(end) else { return false }

            // Exact word boundaries: a word may never be a substring of a
            // longer visible run (the V-REAL-E bug).
            let before = GridCell(row: row - (across ? 0 : 1),
                                  col: col - (across ? 1 : 0))
            let after = GridCell(row: end.row + (across ? 0 : 1),
                                 col: end.col + (across ? 1 : 0))
            if inside(before), letters[before] != nil { return false }
            if inside(after), letters[after] != nil { return false }

            var crossings = 0
            for i in chars.indices {
                let p = GridCell(row: row + (across ? 0 : i),
                                 col: col + (across ? i : 0))
                if let old = letters[p] {
                    guard old == chars[i] else { return false }
                    // Sharing is legal only with a perpendicular word.
                    guard occupied[p]?.contains(across ? "V" : "H") == true,
                          occupied[p]?.contains(across ? "H" : "V") != true else { return false }
                    crossings += 1
                } else {
                    // A fresh letter may not touch another letter beside the
                    // word: that would create an unnumbered parallel run.
                    let sideA = across ? GridCell(row: p.row - 1, col: p.col)
                                       : GridCell(row: p.row, col: p.col - 1)
                    let sideB = across ? GridCell(row: p.row + 1, col: p.col)
                                       : GridCell(row: p.row, col: p.col + 1)
                    if inside(sideA), letters[sideA] != nil { return false }
                    if inside(sideB), letters[sideB] != nil { return false }
                }
            }
            // The first word is placed directly; all later words must cross.
            return entries.isEmpty || crossings > 0
        }
        func place(_ item: NaturalClue, row: Int, col: Int, across: Bool) {
            for (i,ch) in item.word.enumerated() {
                let p=GridCell(row:row+(across ? 0:i),col:col+(across ? i:0))
                letters[p]=ch; occupied[p,default:[]].insert(across ? "H":"V")
            }
            entries.append(CrossEntry(word:item.word,clue:item.clue,dir:across ? "H":"V",
                                      row:row,col:col,len:item.word.count))
        }
        guard let first=source.first else { return nil }
        place(first,row:size/2,col:(size-first.word.count)/2,across:true)
        var used=Set([first.word])

        // Counts how many crossings a candidate placement would create. More
        // crossings mean a denser grid, which is what makes the puzzle feel
        // compact instead of a sparse star of words touching at one letter.
        func crossingCount(_ word: String, row: Int, col: Int, across: Bool) -> Int {
            var n = 0
            for (i, ch) in word.enumerated() {
                let p = GridCell(row: row + (across ? 0 : i), col: col + (across ? i : 0))
                if letters[p] == ch { n += 1 }
            }
            return n
        }

        // Several passes over the clue list: each pass can attach to letters
        // placed by the previous one, so the grid keeps filling up instead of
        // stopping at the first sparse layout that happens to work.
        let targetFill = (size * size) / 2      // aim for half the board lettered
        for pass in 0..<6 {
            for item in source where entries.count < 40 {
                guard !used.contains(item.word) else { continue }
                var options: [(Int, Int, Bool, Int)] = []
                for (wi, ch) in item.word.enumerated() {
                    // Orden fijo en ambos idiomas: recorrer el Dictionary tal cual cambia en cada
                    // ejecución (hash con semilla por proceso) y la misma semilla daba otro tablero.
                    for (cell, old) in letters.sorted(by: { ($0.key.row, $0.key.col) < ($1.key.row, $1.key.col) }) where old == ch {
                        let crossingDirs = occupied[cell] ?? []
                        if crossingDirs.contains("H") {
                            let r = cell.row - wi, c = cell.col
                            if canPlace(item.word, row: r, col: c, across: false) {
                                options.append((r, c, false, crossingCount(item.word, row: r, col: c, across: false)))
                            }
                        }
                        if crossingDirs.contains("V") {
                            let r = cell.row, c = cell.col - wi
                            if canPlace(item.word, row: r, col: c, across: true) {
                                options.append((r, c, true, crossingCount(item.word, row: r, col: c, across: true)))
                            }
                        }
                    }
                }
                guard !options.isEmpty else { continue }
                // Prefer the densest placements; break ties randomly so the
                // daily puzzle still varies.
                let best = options.map(\.3).max() ?? 1
                let densest = options.filter { $0.3 == best }
                let o = densest[rng.int(densest.count)]
                place(item, row: o.0, col: o.1, across: o.2)
                used.insert(item.word)
            }
            if letters.count >= targetFill, pass >= 2 { break }
        }
        // Reject layouts that leave the board mostly empty — that sparseness
        // was the whole complaint about the old generator.
        // Density targets: demanding enough to avoid a sparse star of words,
        // but reachable with the curated clue bank. Falling below this used to
        // return nil, which silently dropped the game from the hub.
        guard entries.count >= 8, letters.count >= (size * size) / 4 else {
            return language == .english ? EnglishPuzzleLexicon.crossword(id: "en-c-gen-\(idSeed)", variant: idSeed) : nil
        }
        let blocks=(0..<size).flatMap { r in (0..<size).compactMap { c -> [Int]? in
            letters[GridCell(row:r,col:c)] == nil ? [r,c] : nil
        }}
        let solution=Dictionary(uniqueKeysWithValues: letters.map { ($0.key.key,String($0.value)) })
        entries.sort { ($0.row,$0.col,$0.dir) < ($1.row,$1.col,$1.dir) }
        return CrosswordPuzzle(id:"\(language == .english ? "en-" : "")c-gen-\(idSeed)",size:size,blocks:blocks,
                               solution:solution,entries:entries,full:true)
    }
}
#endif

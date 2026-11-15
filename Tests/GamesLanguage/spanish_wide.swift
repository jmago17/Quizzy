// Modos `spanish-wide` y `fingerprint` (añadidos 2026-11-15).
//  · spanish-wide: 40 semillas por juego español; letras solo A–Z/Ñ, cruces correctos,
//    pistas presentes, soluciones de Quartiles/Sopa tomadas de answer_words, Wordle aceptable.
//  · fingerprint: imprime una huella por juego y semilla. run.py lo ejecuta en DOS procesos y
//    compara: el orden de un Dictionary/Set cambia entre procesos, y así se detecta un generador
//    que no es determinista (pasó con los crucigramas en español).

private func check(_ ok: @autoclosure () -> Bool, _ message: @autoclosure () -> String = "", line: Int = #line) {
    if !ok() { print("FAIL spanish_wide.swift:\(line) \(message())"); exit(1) }
}
private let spanishLetters = Set("ABCDEFGHIJKLMNÑOPQRSTUVWXYZ")
private func onlySpanishLetters(_ s: String) -> Bool { !s.isEmpty && s.allSatisfy { spanishLetters.contains($0) } }

func spanishWideChecks() {
    let answerSet = Set(PuzzleLexicon.answerWords)
    let seeds = (UInt64(1)...40).map { $0 &* 7919 }
    var crosswordFails = 0, miniFails = 0
    for seed in seeds {
        let w = ProceduralPuzzleGenerator.wordSearch(seed: seed, language: .spanish)!
        for word in w.words {
            check(answerSet.contains(word.word), "Sopa: \(word.word) no está en answer_words")
            check(word.cells.map { w.grid[$0[0]][$0[1]] }.joined() == word.word)
        }
        check(w.grid.joined().allSatisfy { onlySpanishLetters($0) })

        let q = ProceduralPuzzleGenerator.quartiles(seed: seed, language: .spanish)!
        for t in q.targets { check(answerSet.contains(t), "Quartiles: \(t) no está en answer_words") }

        if let c = ProceduralPuzzleGenerator.crossword(seed: seed, language: .spanish) {
            for e in c.entries { check(onlySpanishLetters(e.word) && !e.clue.isEmpty) }
        } else { crosswordFails += 1 }
        if let m = MiniCrosswordGenerator.generate(seed: seed, language: .spanish) {
            for e in m.entries { check(onlySpanishLetters(e.word) && !e.clue.isEmpty) }
        } else { miniFails += 1 }

        let h = HashtagPuzzle.generate(seed: seed, language: .spanish)
        for word in h.words {
            check(onlySpanishLetters(word.answer))
            for (cell, letter) in zip(word.cells, word.answer) { check(h.solution[cell] == letter) }
        }
    }
    check(crosswordFails == 0, "Autodefinido: \(crosswordFails)/40 semillas sin tablero")
    check(miniFails == 0, "Mini: \(miniFails)/40 semillas sin tablero")
    for day in 0..<400 { _ = MiniCrosswordGenerator.daily(dayIndex: day, language: .spanish)! }
    for answer in PuzzleLexicon.wordleAnswers {
        check(answer.count == 5 && onlySpanishLetters(answer) && PuzzleLexicon.wordSet.contains(answer),
                     "Wordle: \(answer) no se puede escribir/aceptar")
    }
    // Anygram: el léxico (bases jugables) es lo caro; cada puzzle debe salir rápido y válido.
    let start = Date()
    for seed in seeds.prefix(12) {
        let a = AnygramPuzzle.generate(seed: seed, language: .spanish)!
        check(a.entries.count >= 8 && a.answers.allSatisfy(onlySpanishLetters))
        for word in a.answers {
            var pool = a.letters
            for letter in word {
                guard let i = pool.firstIndex(of: letter) else { check(false, "Anygram: \(word) no sale de la rueda"); return }
                pool.remove(at: i)
            }
        }
    }
    let seconds = Date().timeIntervalSince(start)
    print("PASS Spanish wide: 40 seeds wordsearch/Quartiles/crossword/Mini/Hashtag, 400 Mini dailies, \(PuzzleLexicon.wordleAnswers.count) Wordle answers, 12 Anygram en \(String(format: "%.1f", seconds)) s")
}

func fingerprintChecks() {
    func h(_ s: String) -> String {
        var v: UInt64 = 0xcbf29ce484222325
        for b in s.utf8 { v ^= UInt64(b); v &*= 0x100000001b3 }
        return String(v, radix: 16)
    }
    for seed in (UInt64(1)...6).map({ $0 &* 104729 }) {
        let w = ProceduralPuzzleGenerator.wordSearch(seed: seed, language: .spanish)!
        let q = ProceduralPuzzleGenerator.quartiles(seed: seed, language: .spanish)!
        let c = ProceduralPuzzleGenerator.crossword(seed: seed, language: .spanish)
        let m = MiniCrosswordGenerator.generate(seed: seed, language: .spanish)
        let md = MiniCrosswordGenerator.daily(dayIndex: Int(seed % 1000), language: .spanish)
        let a = AnygramPuzzle.generate(seed: seed, language: .spanish)
        let hs = HashtagPuzzle.generate(seed: seed, language: .spanish)
        let d = WordlePuzzle.daily(dayIndex: Int(seed % 1000), language: .spanish)
        let cw = c.map { $0.entries.map { "\($0.word)\($0.row),\($0.col)\($0.dir)" }.joined() } ?? "nil"
        let mw = m.map { $0.entries.map { "\($0.word)\($0.row),\($0.col)\($0.dir)" }.joined() } ?? "nil"
        let mdw = md.map { $0.entries.map { "\($0.word)\($0.row),\($0.col)\($0.dir)" }.joined() } ?? "nil"
        let aw = a.map { $0.entries.map { "\($0.word)\($0.row),\($0.col)" }.joined() + String($0.letters) } ?? "nil"
        print("FP \(seed) sopa=\(h(w.grid.joined().joined())) quart=\(h(q.tiles.joined())) cruci=\(h(cw)) mini=\(h(mw)) minid=\(h(mdw)) any=\(h(aw)) hash=\(h(String(hs.letters))) wordle=\(d.answer)")
    }
}

//
//  WatchPalabroView.swift — Quizzy Watch
//  Palabro (5 letras, 6 intentos). La palabra se escribe con la entrada de texto del reloj
//  (teclado, garabato o dictado); las reglas son las del iPhone (`WordlePuzzle.evaluate`).
//  Intentos guardados en `PuzzleProgress.found(id)`, igual que en el iPhone.
//

import SwiftUI

struct WatchPalabroView: View {
    let puzzle: WordlePuzzle
    let onAnother: () -> Void

    @ObservedObject private var progress = PuzzleProgress.shared
    @State private var guesses: [String] = []
    @State private var input = ""
    @State private var elapsed = 0
    @State private var notice: WNotice?
    @State private var loaded = false

    private static let rows = 6
    private var won: Bool { guesses.last == puzzle.answer }
    private var finished: Bool { won || guesses.count >= Self.rows }
    private var english: Bool { puzzle.id.hasPrefix("en-") }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 6) {
                    // Entrada arriba: en la muñeca es lo primero que se toca; la rejilla va debajo.
                    if !finished {
                        TextField(AppLanguage.text("Escribe 5 letras", "Type 5 letters"), text: $input)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .onSubmit(submit)
                            .id("input")
                    }
                    WNoticeText(notice: $notice)
                    grid
                    if finished {
                        WResultPanel(kind: .wordle, won: won,
                                     headline: won ? AppLanguage.text("¡Acertaste!", "Solved!") : puzzle.answer,
                                     detail: won
                                        ? AppLanguage.text("\(guesses.count)/6 · \(wTime(elapsed))", "\(guesses.count)/6 · \(wTime(elapsed))")
                                        : AppLanguage.text("Era la palabra", "That was the word"),
                                     onAnother: onAnother)
                    } else {
                        keyHints
                    }
                }
                .padding(.horizontal, 2)
            }
            .onChange(of: guesses.count) { _, _ in withAnimation { proxy.scrollTo("input", anchor: .top) } }
        }
        .navigationTitle("Palabro")
        .wClock(puzzle.id, running: !finished, elapsed: $elapsed)
        .onAppear {
            guard !loaded else { return }
            loaded = true
            guesses = progress.found(puzzle.id).filter { $0.count == 5 }
            elapsed = progress.elapsed(puzzle.id)
        }
    }

    private var grid: some View {
        VStack(spacing: 3) {
            ForEach(0..<Self.rows, id: \.self) { row in
                HStack(spacing: 3) {
                    let word = row < guesses.count ? guesses[row] : ""
                    let marks = row < guesses.count ? WordlePuzzle.evaluate(word, answer: puzzle.answer) : []
                    ForEach(0..<5, id: \.self) { col in
                        let letter = col < word.count ? String(Array(word)[col]) : ""
                        WTile(fill: marks.isEmpty ? WTheme.fill : color(marks[col]), radius: 4) {
                            Text(letter).font(.system(size: 14, weight: .bold, design: .rounded))
                        }
                        .frame(width: 26, height: 24)
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(rowLabel(row))
            }
        }
    }

    /// Letras ya descartadas: en el reloj no cabe el teclado de colores, así que se resumen aquí.
    private var keyHints: some View {
        let absent = Set(guesses.flatMap { g in
            zip(g, WordlePuzzle.evaluate(g, answer: puzzle.answer)).compactMap { $0.1 == .absent ? $0.0 : nil }
        }).subtracting(Set(puzzle.answer))
        return Group {
            if !absent.isEmpty {
                Text(AppLanguage.text("Fuera: ", "Out: ") + String(absent.sorted()))
                    .font(.caption2).foregroundStyle(WTheme.inkSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func color(_ r: LetterResult) -> Color {
        switch r {
        case .correct: return WTheme.wCorrect
        case .present: return WTheme.wPresent
        case .absent: return WTheme.wAbsent
        }
    }

    private func rowLabel(_ row: Int) -> String {
        guard row < guesses.count else { return AppLanguage.text("Fila \(row + 1) vacía", "Row \(row + 1) empty") }
        let word = guesses[row]
        let marks = WordlePuzzle.evaluate(word, answer: puzzle.answer)
        let parts = zip(word, marks).map { letter, mark -> String in
            switch mark {
            case .correct: return "\(letter) " + AppLanguage.text("bien", "correct")
            case .present: return "\(letter) " + AppLanguage.text("en otro sitio", "elsewhere")
            case .absent: return "\(letter) " + AppLanguage.text("no está", "absent")
            }
        }
        return parts.joined(separator: ", ")
    }

    /// Mayúsculas y sin tildes, pero la Ñ se conserva (es letra propia en el diccionario).
    static func normalize(_ raw: String) -> String {
        String(raw.uppercased().compactMap { ch -> Character? in
            if ch == "Ñ" { return ch }
            let folded = String(ch).folding(options: .diacriticInsensitive, locale: Locale(identifier: "es"))
            return folded.first.flatMap { $0.isLetter ? $0 : nil }
        })
    }

    private func submit() {
        let word = Self.normalize(input)
        input = ""
        guard !finished else { return }
        guard word.count == 5 else {
            notice = WNotice(text: AppLanguage.text("Tienen que ser 5 letras", "It must be 5 letters"), kind: .error)
            WHaptics.error(); return
        }
        guard (english ? EnglishPuzzleLexicon.wordSet : PuzzleLexicon.wordSet).contains(word) else {
            notice = WNotice(text: AppLanguage.text("«\(word)» no vale", "“\(word)” isn't a word"), kind: .error)
            WHaptics.error(); return
        }
        guard !guesses.contains(word) else {
            notice = WNotice(text: AppLanguage.text("Ya la probaste", "Already tried"), kind: .info)
            WHaptics.warning(); return
        }
        withAnimation(.snappy) { guesses.append(word) }
        progress.setFound(puzzle.id, guesses)
        if finished {
            progress.setElapsed(puzzle.id, elapsed)
            progress.recordTime(TimeInterval(elapsed), kind: .wordle, puzzleID: puzzle.id)
            progress.markDone(puzzle.id)
            progress.noteDayIfComplete()
            won ? WHaptics.success() : WHaptics.error()
        } else {
            WHaptics.tick()
        }
    }
}

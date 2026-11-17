#if os(iOS)
//
//  WordleGame.swift — News Raider
//

import SwiftUI
import Combine
import UIKit

struct WordlePuzzle: Identifiable, Sendable, Hashable {
    let id: String
    let answer: String

    /// Curated answers, with a stable fallback that never reaches into the
    /// broad validation dictionary — that fallback is what produced FRANI.
    private static func bank(language: PuzzleLanguage) -> [String] {
        if language == .english { return EnglishPuzzleLexicon.answers }
        return PuzzleLexicon.wordleAnswers.isEmpty
            ? PuzzleLexicon.commonWords.filter { $0.count == 5 && $0.allSatisfy(\.isLetter) }
            : PuzzleLexicon.wordleAnswers
    }

    /// Daily answers walk a fixed permutation of the whole bank instead of
    /// picking at random, so every word is used exactly once before any
    /// repeats — with ~1,070 answers that's about three years of dailies.
    static func daily(dayIndex: Int, language: PuzzleLanguage = .spanish) -> WordlePuzzle {
        let words = bank(language: language)
        guard !words.isEmpty else { return .init(id: "\(language == .english ? "en-" : "")d-day-\(dayIndex)", answer: "RADIO") }
        let cycle = dayIndex / words.count            // reshuffle each full pass
        let position = ((dayIndex % words.count) + words.count) % words.count
        var rng = SeededGenerator(seed: 0x5EED &+ UInt64(bitPattern: Int64(cycle)))
        let order = rng.shuffled(words)
        return .init(id: "\(language == .english ? "en-" : "")d-day-\(dayIndex)", answer: order[position])
    }

    static func generate(seed: UInt64, excluding excluded: Set<String> = [], language: PuzzleLanguage = .spanish) -> WordlePuzzle {
        var rng = SeededGenerator(seed: seed)
        let allWords = bank(language: language)
        let freshWords = allWords.filter { !excluded.contains($0) }
        let words = freshWords.isEmpty ? allWords : freshWords
        let answer = words.isEmpty ? "RADIO" : words[rng.int(words.count)]
        return .init(id: "\(language == .english ? "en-" : "")d-gen-\(seed)", answer: answer)
    }
}

enum LetterResult: Int, Comparable {
    case absent = 0, present = 1, correct = 2
    static func < (a: Self, b: Self) -> Bool { a.rawValue < b.rawValue }
}

enum WordleOutcome: Identifiable, Equatable {
    case won(attempts: Int)
    case lost(answer: String)
    var id: String {
        switch self {
        case .won(let a):  return "won-\(a)"
        case .lost(let w): return "lost-\(w)"
        }
    }
    var isWin: Bool { if case .won = self { return true }; return false }
    var attempts: Int { if case .won(let a) = self { return a }; return 6 }
}

struct WordleGame: View {
    let puzzle: WordlePuzzle
    @ObservedObject private var progress = PuzzleProgress.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var guesses: [String] = []
    @State private var current = ""
    @State private var elapsed = 0
    @State private var finished = false
    @State private var outcome: WordleOutcome?
    @State private var toast: PZToast?
    @State private var shakeRow: Int?
    @State private var keyState: [Character: LetterResult] = [:]
    @State private var revealedRows = 0
    @State private var showHint = false
    @State private var showDefinition = false
    /// Hint tiers already paid for, so re-opening the popover is free.
    @State private var chargedHints: Set<Int> = []
    @FocusState private var hardwareKeyboardFocused: Bool

    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private var rows: [String] { ["QWERTYUIOP", puzzle.id.hasPrefix("en-") ? "ASDFGHJKL" : "ASDFGHJKLÑ", "ZXCVBNM"] }

    var body: some View {
        GeometryReader { geo in
            let landscape = geo.size.width > geo.size.height * 1.2
            if landscape {
                HStack(spacing: PZSpace.xl) {
                    VStack { status; board(maxSide: 62) }
                        .frame(width: geo.size.width * 0.42)
                        .padding(.leading, PZSpace.xl)
                    VStack { Spacer(); keyboard; Spacer() }
                        .padding(.trailing, PZSpace.lg)
                }
            } else {
                // Layout is fixed: the board and keyboard must never move or
                // resize mid-game. The hint lives behind the bulb in the
                // status row, so revealing it changes nothing on screen.
                // Header + tracker + the room the system keyboard will take.
                let reserved: CGFloat = 76 + 250
                let availableForBoard = max(220, geo.size.height - reserved)
                let sideFromHeight = (availableForBoard - PZSpace.sm * 5) / 6
                let sideFromWidth = (geo.size.width - PZSpace.lg * 2 - PZSpace.sm * 4) / 5
                let side = min(76, sideFromHeight, sideFromWidth)
                VStack(spacing: PZSpace.md) {
                    status
                    board(maxSide: side).padding(.horizontal, PZSpace.lg)
                    keyboard
                    Spacer(minLength: 0)
                }
                .padding(.top, PZSpace.md)
            }
        }
        .background(PZGameBackdrop(color: PZ.wordle))
        .background {
            PZHardwareKeyCapture { handleCapturedHardwareKey($0) }
                .frame(width: 1, height: 1)
                .accessibilityHidden(true)
        }
        .focusable(interactions: .activate)
        .focused($hardwareKeyboardFocused)
        .focusEffectDisabled()
        .onKeyPress(phases: .down) { press in
            handleHardwareKey(press)
        }
        .simultaneousGesture(TapGesture().onEnded { claimHardwareKeyboardFocus() })
        .navigationTitle("Wordle")
        .navigationBarTitleDisplayMode(.inline)
        .pzRules(.wordle)
        .pzToast($toast)
        .onAppear {
            elapsed = progress.elapsed(puzzle.id)
            finished = progress.isDone(puzzle.id)
            // Restore an interrupted round: guesses are stored in play order.
            if guesses.isEmpty {
                let saved = progress.found(puzzle.id)
                    .filter { $0.count == puzzle.answer.count }
                if !saved.isEmpty {
                    guesses = Array(saved.prefix(6))
                    guesses.forEach { absorbKeyStates(from: $0) }
                }
            }
            revealedRows = guesses.count
            claimHardwareKeyboardFocus()
        }
        .onReceive(tick) { _ in
            guard !finished else { return }
            elapsed += 1
            if elapsed % 5 == 0 { progress.setElapsed(puzzle.id, elapsed) }
        }
        .sheet(item: $outcome) { o in
            PZResultSheet(result: PZResult(
                kind: .wordle,
                didWin: o.isWin,
                headline: o.isWin ? AppLanguage.text("¡En \(o.attempts) \(o.attempts == 1 ? "intento" : "intentos")!", "Solved in \(o.attempts)!") : AppLanguage.text("Casi", "Almost"),
                detail: o.isWin ? nil : AppLanguage.text("La palabra era \(puzzle.answer)", "The word was \(puzzle.answer)"),
                metrics: [
                    (AppLanguage.text("Intentos", "Attempts"), o.isWin ? "\(o.attempts)/6" : "—"),
                    (AppLanguage.text("Tiempo", "Time"), PuzzleTiming.clock(TimeInterval(elapsed))),
                    (AppLanguage.text("Racha", "Streak"), "\(progress.streak)")
                ],
                shareText: shareGrid(won: o.isWin)))
        }
    }

    // MARK: Status

    private var status: some View {
        VStack(spacing: PZSpace.sm) {
            HStack {
                PZStat(label: AppLanguage.text("Intento", "Attempt"), value: "\(min(guesses.count + 1, 6))/6")
                Spacer()
                hintButton
                Spacer()
                PZStat(label: AppLanguage.text("Tiempo", "Time"), value: PuzzleTiming.clock(TimeInterval(elapsed)), alignment: .trailing)
            }
            // Once the word is out, the interesting question stops being "what
            // is it" and becomes "what does it mean".
            if finished { definitionBar }
        }
        .padding(.horizontal, PZSpace.xl)
    }

    /// Dictionary entry for the answer, shown only after the game ends so it
    /// can never leak the word mid-play.
    @ViewBuilder private var definitionBar: some View {
        if puzzle.id.hasPrefix("en-") || PZDictionary.hasDefinition(for: puzzle.answer) {
            Button { showDefinition = true } label: {
                HStack(spacing: PZSpace.xs) {
                    Image(systemName: "character.book.closed")
                        .font(.system(size: 12, weight: .semibold))
                    Text(AppLanguage.text("Ver definición de \(puzzle.answer.lowercased())", "See the definition of \(puzzle.answer.lowercased())"))
                        .font(PZFont.chip)
                }
                .foregroundStyle(PZ.wordle)
                .padding(.vertical, PZSpace.xs)
                .padding(.horizontal, PZSpace.md)
                .background(PZColor.wash(PZ.wordle), in: Capsule())
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $showDefinition) {
                if puzzle.id.hasPrefix("en-") {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(puzzle.answer.capitalized).font(.title.bold())
                        Text(EnglishPuzzleLexicon.cluePairs.first { $0.0 == puzzle.answer }?.1 ?? "An English word.")
                    }
                    .padding(24)
                    .presentationDetents([.medium])
                } else {
                    PZDefinitionView(term: puzzle.answer.lowercased()).ignoresSafeArea()
                }
            }
        }
    }

    /// The hint is tucked behind this bulb so the board and keyboard keep
    /// their exact position and size for the whole game.
    @ViewBuilder private var hintButton: some View {
        let hint = wordleHint
        Button {
            guard hint != nil else { return }
            // Consistent with the other games: seeing a hint costs 2 minutes,
            // charged once per hint level rather than per peek.
            if !chargedHints.contains(hintLevel) {
                chargedHints.insert(hintLevel)
                progress.addHint(puzzle.id)
                elapsed += PZHintButton.penalty
                progress.setElapsed(puzzle.id, elapsed)
            }
            showHint = true
            PZHaptics.warning()
        } label: {
            Image(systemName: hint == nil ? "lightbulb" : "lightbulb.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(hint == nil ? Color.secondary.opacity(0.45) : PZ.wordle)
                .frame(width: 44, height: 44)
                .background(hint == nil ? Color.clear : PZ.wordle.opacity(0.12), in: Circle())
        }
        .buttonStyle(.plain)
        .disabled(hint == nil)
        .accessibilityLabel(AppLanguage.text("Pista", "Hint"))
        .accessibilityHint(hint == nil ? AppLanguage.text("Disponible tras dos intentos fallidos", "Available after two unsuccessful guesses") : AppLanguage.text("Muestra una pista", "Show a hint"))
        .popover(isPresented: $showHint) {
            VStack(alignment: .leading, spacing: PZSpace.sm) {
                Label(AppLanguage.text("Pista", "Hint"), systemImage: "lightbulb.fill")
                    .font(PZFont.label)
                    .textCase(.uppercase)
                    .foregroundStyle(PZ.wordle)
                Text(hint ?? "")
                    .font(PZFont.body)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(PZSpace.lg)
            .frame(maxWidth: 280)
            .presentationCompactAdaptation(.popover)
        }
    }

    /// Which tier of hint is currently on offer.
    private var hintLevel: Int { guesses.filter { $0 != puzzle.answer }.count }

    private var wordleHint: String? {
        let misses = hintLevel
        guard misses >= 2, !finished else { return nil }
        let answer = puzzle.answer
        let chars = Array(answer)
        if puzzle.id.hasPrefix("en-") {
            if misses == 2 { return "Hint: \(EnglishPuzzleLexicon.cluePairs.first { $0.0 == answer }?.1 ?? "A five-letter word")" }
            if misses == 3 { return "Hint: starts with \(chars.first.map(String.init) ?? "?")." }
            if misses == 4 { return "Hint: pattern \(pattern(revealing: [0, 2]))." }
            return "Last hint: ends with \(chars.last.map(String.init) ?? "?") · pattern \(pattern(revealing: [0, 2, 4]))."
        }
        if misses == 2 {
            return WordleHints.category(for: answer) ?? "Pista: tiene \(vowelCount(answer)) vocal\(vowelCount(answer) == 1 ? "" : "es")."
        }
        if misses == 3 {
            return "Pista: empieza por \(chars.first.map(String.init) ?? "?")."
        }
        if misses == 4 {
            return "Pista: patrón \(pattern(revealing: [0, 2]))."
        }
        return "Última pista: termina en \(chars.last.map(String.init) ?? "?") · patrón \(pattern(revealing: [0, 2, 4]))."
    }

    private func vowelCount(_ word: String) -> Int {
        word.filter { "AEIOU".contains($0) }.count
    }

    private func pattern(revealing positions: Set<Int>) -> String {
        Array(puzzle.answer).enumerated().map { positions.contains($0.offset) ? String($0.element) : "_" }.joined(separator: " ")
    }

    // MARK: Board

    private func board(maxSide: CGFloat) -> some View {
        GeometryReader { geo in
            let side = min((geo.size.width - PZSpace.sm * 4) / 5, maxSide)
            VStack(spacing: PZSpace.sm) {
                ForEach(0..<6, id: \.self) { r in
                    HStack(spacing: PZSpace.sm) {
                        ForEach(0..<5, id: \.self) { c in tile(row: r, col: c, side: side) }
                    }
                    .modifier(ShakeEffect(animatableData: shakeRow == r ? 1 : 0))
                }
            }
            .frame(maxWidth: .infinity)
        }
        .frame(height: maxSide * 6 + PZSpace.sm * 5)
    }

    private func tile(row: Int, col: Int, side: CGFloat) -> some View {
        let word = row < guesses.count ? guesses[row] : (row == guesses.count ? current : "")
        let letters = Array(word)
        let ch = col < letters.count ? String(letters[col]) : ""
        let revealed = row < revealedRows
        let result = revealed ? evaluate(guesses[row])[col] : nil

        return Text(ch)
            .font(.system(size: side * 0.46, weight: .bold))
            // Volumen: la letra entra con un pequeño rebote al teclearla.
            .scaleEffect(ch.isEmpty ? 0.5 : 1)
            .animation(reduceMotion ? nil : .spring(response: 0.25, dampingFraction: 0.55), value: ch)
            .frame(width: side, height: side)
            // Ficha con volumen: apagada mientras no se comprueba; encendida con el color del resultado
            // (verde/ámbar/gris de siempre). Solo la correcta lleva halo.
            .pzVolume(result.map(color), radius: PZRadius.chip, glow: result == .correct)
            .overlay {
                // Casilla tecleada sin comprobar: borde claro para distinguirla de las vacías.
                if result == nil, !ch.isEmpty {
                    PZRadius.rect(PZRadius.chip).stroke(Color.primary.opacity(0.4), lineWidth: 2)
                }
            }
            .overlay(alignment: .topTrailing) {
                // Second channel for colour-blind users.
                if let result, result != .absent {
                    Image(systemName: result == .correct ? "checkmark" : "arrow.left.arrow.right")
                        .font(.system(size: 9, weight: .black))
                        .foregroundStyle(.white.opacity(0.9))
                        .padding(3)
                        .accessibilityHidden(true)
                }
            }
            .foregroundStyle(result == nil ? Color.primary : Color.white)
            .rotation3DEffect(.degrees(revealed && !reduceMotion ? 0 : 0), axis: (1, 0, 0))
            .animation(reduceMotion ? nil : PZAnim.reveal.delay(Double(col) * 0.08), value: revealedRows)
            .accessibilityLabel(accessibilityText(row: row, col: col, ch: ch, result: result))
    }

    private func accessibilityText(row: Int, col: Int, ch: String, result: LetterResult?) -> String {
        guard !ch.isEmpty else { return AppLanguage.text("Fila \(row + 1), letra \(col + 1), vacía", "Row \(row + 1), letter \(col + 1), empty") }
        let state: String
        switch result {
        case .correct: state = AppLanguage.text("correcta", "correct")
        case .present: state = AppLanguage.text("en otra posición", "in another position")
        case .absent:  state = AppLanguage.text("no está", "absent")
        case nil:      state = AppLanguage.text("sin comprobar", "not checked")
        }
        return AppLanguage.text("Fila \(row + 1), letra \(col + 1), \(ch), \(state)", "Row \(row + 1), letter \(col + 1), \(ch), \(state)")
    }

    private func color(_ r: LetterResult?) -> Color {
        switch r {
        case .correct: return PZColor.wCorrect
        case .present: return PZColor.wPresent
        case .absent:  return PZColor.wAbsent
        case nil:      return PZColor.surface
        }
    }

    // MARK: Keyboard

    /// Custom keyboard: the whole point is colouring keys with what you have
    /// already ruled out, which the system keyboard cannot do. Key positions
    /// mirror iOS: backspace on the right of the third row, return below it.
    private var keyboard: some View {
        VStack(spacing: PZSpace.sm) {
            ForEach(Array(rows.enumerated()), id: \.offset) { i, row in
                HStack(spacing: PZSpace.xs) {
                    ForEach(Array(row), id: \.self) { x in key(String(x)) }
                    if i == 2 {
                        wideKey(systemImage: "delete.left") { deleteLast() }
                    }
                }
            }
            HStack(spacing: PZSpace.xs) {
                Spacer(minLength: 0)
                Button { claimHardwareKeyboardFocus(); submit() } label: {
                    Label(AppLanguage.text("Comprobar", "Check"), systemImage: "return")
                        .font(PZFont.chip)
                        .frame(maxWidth: 200)
                        .frame(height: 44)
                        // Encendido (color del juego, con halo) cuando hay 5 letras; apagado si no.
                        .pzVolume(current.count == 5 ? PZ.wordle : nil, radius: PZRadius.chip,
                                  glow: current.count == 5)
                        .foregroundStyle(current.count == 5 ? Color.white : PZColor.inkTertiary)
                }
                .buttonStyle(.plain)
                .disabled(current.count != 5 || finished)
            }
        }
        .padding(.horizontal, PZSpace.xs)
    }

    private func key(_ label: String) -> some View {
        let ch = Character(label)
        let state = keyState[ch]
        return Button { claimHardwareKeyboardFocus(); tap(label) } label: {
            Text(label)
                .font(.system(size: 16, weight: .bold))
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                // Tecla con volumen: apagada sin información; con el color del estado si ya se sabe.
                .pzVolume(state.map(keyColor), radius: PZRadius.chip)
                .foregroundStyle(state == nil ? PZColor.ink : .white)
                .strikethrough(state == .absent, color: .white.opacity(0.7))
        }
        .buttonStyle(.plain)
        .disabled(finished)
        .animation(PZAnim.reveal, value: state)
        .accessibilityLabel(label)
        .accessibilityValue(stateName(state))
    }

    private func wideKey(systemImage: String, action: @escaping () -> Void) -> some View {
        Button { claimHardwareKeyboardFocus(); action() } label: {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .semibold))
                .frame(width: 52, height: 46)
                .pzVolume(radius: PZRadius.chip)
                .foregroundStyle(PZColor.ink)
        }
        .buttonStyle(.plain)
        .disabled(finished)
    }

    private func keyColor(_ s: LetterResult?) -> Color {
        switch s {
        case .correct: return PZColor.wCorrect
        case .present: return PZColor.wPresent
        case .absent:  return PZColor.wAbsent
        case nil:      return PZColor.fill
        }
    }

    private func stateName(_ s: LetterResult?) -> String {
        switch s {
        case .correct: return AppLanguage.text("correcta", "correct")
        case .present: return AppLanguage.text("en la palabra", "in the word")
        case .absent:  return AppLanguage.text("descartada", "ruled out")
        case nil:      return AppLanguage.text("sin usar", "unused")
        }
    }

    // MARK: Input

    /// Letters confirmed in place by an earlier guess, keyed by position.
    /// Once Wordle has told the player a letter is right, re-typing it every
    /// row is busywork, and deleting it throws away a known fact — so the
    /// green letters are carried into the next guess and held there.
    private var lockedLetters: [Int: Character] {
        var out: [Int: Character] = [:]
        let answer = Array(puzzle.answer)
        for guess in guesses {
            for (i, ch) in guess.enumerated() where i < answer.count && ch == answer[i] {
                out[i] = ch
            }
        }
        return out
    }

    /// The guess in progress, with locked letters forced into their slots.
    private var lockedPrefix: String {
        let locks = lockedLetters
        guard !locks.isEmpty else { return current }
        var chars = Array(current)
        while chars.count < 5 { chars.append(" ") }
        for (i, ch) in locks where i < 5 { chars[i] = ch }
        return String(chars).replacingOccurrences(of: " ", with: "")
    }

    private func tap(_ x: String) {
        guard !finished else { return }
        var chars = Array(current)
        let locks = lockedLetters
        // Skip over positions the player has already nailed down.
        var index = chars.count
        while let locked = locks[index], index < 5 {
            chars.append(locked)
            index += 1
        }
        guard chars.count < 5 else { current = String(chars); return }
        chars.append(Character(x))
        index = chars.count
        while let locked = locks[index], index < 5 {
            chars.append(locked)
            index += 1
        }
        current = String(chars)
        PZHaptics.tick()
    }

    /// Deletes the last letter the player actually chose, stepping over any
    /// locked ones so a confirmed letter can never be erased.
    private func deleteLast() {
        guard !current.isEmpty else { return }
        let locks = lockedLetters
        var chars = Array(current)
        while let last = chars.indices.last {
            let wasLocked = locks[last] != nil
            chars.removeLast()
            if !wasLocked { break }
        }
        // Re-apply any locks that sit at the start of the remaining prefix.
        var index = chars.count
        while let locked = locks[index], index < 5 {
            chars.append(locked)
            index += 1
        }
        current = String(chars)
        PZHaptics.tick()
    }

    private func handleHardwareKey(_ press: KeyPress) -> KeyPress.Result {
        guard !finished else { return .ignored }
        if press.key == .delete {
            deleteLast()
            return .handled
        }
        if press.key == .return {
            submit()
            return .handled
        }
        let text = press.characters.uppercased()
        guard text.count == 1, let letter = text.first,
              "ABCDEFGHIJKLMNÑOPQRSTUVWXYZ".contains(letter) else { return .ignored }
        tap(String(letter))
        return .handled
    }

    /// UIKit first-responder fallback for iPad hardware keyboards. This keeps
    /// letter, delete and return input alive when a virtual-key Button has
    /// displaced SwiftUI's focused game surface.
    private func handleCapturedHardwareKey(_ key: PZHardwareKey) -> Bool {
        guard !finished else { return false }
        switch key.unmodifiedInput {
        case UIKeyCommand.inputDelete:
            deleteLast()
            return true
        case "\r", "\n":
            submit()
            return true
        default:
            let text = key.unmodifiedInput.uppercased()
            guard text.count == 1, let letter = text.first,
                  "ABCDEFGHIJKLMNÑOPQRSTUVWXYZ".contains(letter) else { return false }
            tap(String(letter))
            return true
        }
    }

    /// SwiftUI gives a tapped Button focus after its action has returned.
    /// Deferring this assignment one turn reliably returns hardware-keyboard
    /// input to the game surface on iPad.
    private func claimHardwareKeyboardFocus() {
        Task { @MainActor in
            await Task.yield()
            hardwareKeyboardFocused = true
        }
    }

    private func submit() {
        guard !finished else { return }
        guard current.count == 5 else {
            flash(AppLanguage.text("Faltan letras", "Not enough letters"), .info)
            shake()
            return
        }
        guard (puzzle.id.hasPrefix("en-") ? EnglishPuzzleLexicon.wordSet : PuzzleLexicon.wordSet).contains(current) else {
            flash(AppLanguage.text("«\(current)» no está en el diccionario", "“\(current)” is not in this curated dictionary"), .error)
            shake()
            PZHaptics.error()
            return                       // never touches `outcome`
        }

        let guess = current
        guesses.append(guess)
        // Start the next row with the confirmed letters already in place.
        current = ""
        var seeded = ""
        let locks = lockedLetters
        var index = 0
        while let locked = locks[index], index < 5 {
            seeded.append(locked)
            index += 1
        }
        current = seeded
        absorbKeyStates(from: guess)
        // Persist immediately so leaving mid-round never loses progress.
        progress.setFound(puzzle.id, guesses)
        progress.setElapsed(puzzle.id, elapsed)
        withAnimation(reduceMotion ? nil : PZAnim.reveal) { revealedRows = guesses.count }

        if guess == puzzle.answer {
            complete(won: true)
        } else if guesses.count >= 6 {
            complete(won: false)
        } else {
            PZHaptics.tick()
        }
    }

    private func shake() {
        let row = guesses.count
        withAnimation(reduceMotion ? nil : .snappy(duration: 0.34)) { shakeRow = row }
        Task {
            try? await Task.sleep(nanoseconds: 400_000_000)
            await MainActor.run { shakeRow = nil }
        }
    }

    private func flash(_ text: String, _ kind: PZToast.Kind = .info) {
        toast = PZToast(text: text, kind: kind)
    }

    private func absorbKeyStates(from guess: String) {
        let results = evaluate(guess)
        for (i, ch) in Array(guess).enumerated() {
            let s = results[i]
            if let old = keyState[ch] { keyState[ch] = max(old, s) } else { keyState[ch] = s }
        }
    }

    private func evaluate(_ guess: String) -> [LetterResult] {
        let g = Array(guess), a = Array(puzzle.answer)
        var out = Array(repeating: LetterResult.absent, count: 5)
        var remaining: [Character: Int] = [:]
        for i in 0..<5 {
            if g[i] == a[i] { out[i] = .correct } else { remaining[a[i], default: 0] += 1 }
        }
        for i in 0..<5 where out[i] != .correct {
            if remaining[g[i], default: 0] > 0 { out[i] = .present; remaining[g[i]]! -= 1 }
        }
        return out
    }

    private func complete(won: Bool) {
        finished = true
        progress.setElapsed(puzzle.id, elapsed)
        progress.recordTime(TimeInterval(elapsed), kind: .wordle, puzzleID: puzzle.id)
        progress.markDone(puzzle.id)
        progress.noteDayIfComplete()
        if won { PZHaptics.success() } else { PZHaptics.warning() }
        Task {
            // Let the reveal animation finish before the sheet covers the board.
            try? await Task.sleep(nanoseconds: reduceMotion ? 200_000_000 : 900_000_000)
            await MainActor.run {
                outcome = won ? .won(attempts: guesses.count) : .lost(answer: puzzle.answer)
            }
        }
    }

    /// Emoji grid — never leaks the answer.
    private func shareGrid(won: Bool) -> String {
        let header = "NewsRaider Wordle · \(won ? "\(guesses.count)/6" : "X/6")"
        let grid = guesses.map { g in
            evaluate(g).map { r in
                switch r {
                case .correct: return "🟩"
                case .present: return "🟨"
                case .absent:  return "⬜"
                }
            }.joined()
        }.joined(separator: "\n")
        let date = Date().formatted(.dateTime.day().month().year().locale(Locale(identifier: puzzle.id.hasPrefix("en-") ? "en_US" : "es_ES")))
        return "\(header) · \(date)\n\(grid)"
    }
}

// MARK: - Wordle hints

enum WordleHints {
    static func category(for word: String) -> String? {
        let groups: [(String, Set<String>)] = [
            ("Categoría: animal.", ["PERRO","GATOS","CABRA","OVEJA","TIGRE","LEONA","CEBRA","RATON","MOSCA","ABEJA","PULPO","BURRO"]),
            ("Categoría: comida o bebida.", ["PANES","QUESO","LECHE","ARROZ","PASTA","CARNE","PIZZA","FRUTA","MELON","PERAS","SOPAS","VINO"]),
            ("Categoría: lugar o geografía.", ["PLAYA","MONTE","CAMPO","CALLE","PLAZA","HOTEL","RURAL","NORTE","OESTE","COSTA","RIBER"]),
            ("Categoría: casa u objeto cotidiano.", ["MESA","SILLA","CAMA","VASO","PLATO","LIBRO","PAPEL","LLAVE","RELOJ","BOLSA","CAJON"]),
            ("Categoría: persona o relación.", ["MADRE","PADRE","HIJOS","NIÑOS","AMIGO","JOVEN","MUJER","HOMBRE","NOVIA"]),
            ("Categoría: naturaleza.", ["ARBOL","FLOR","NUBES","LLUVIA","VIENTO","FUEGO","SOLAR","LUNAR","VERDE"]),
            ("Categoría: acción común.", ["CORRE","CANTA","BAILA","HABLA","MIRAR","COMER","BEBER","DORMI","SALIR","VENIR"])
        ]
        return groups.first { $0.1.contains(word) }?.0
    }
}
#endif

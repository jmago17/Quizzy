#if os(iOS)
//
//  CasualPuzzleGames.swift — News Raider
//  Trivial 10 en 60, Conexiones y Cifras.
//

import SwiftUI
import Combine
import UIKit

// MARK: - Casual puzzle models + generators

struct TriviaPuzzle: Identifiable, Sendable, Hashable {
    struct Question: Identifiable, Sendable, Hashable, Decodable {
        enum Style: String, Sendable, Decodable { case multiple, boolean, intruder, order }
        let id: Int
        let category: String
        let prompt: String
        let options: [String]
        let correct: [Int]
        let style: Style
    }

    let id: String
    let questions: [Question]

    private static let perRound = 10

    /// Number of questions available, used to size the "already seen" history.
    static var bankSize: Int { TriviaBank.questions.count }

    /// Daily rounds walk a fixed permutation of the whole bank, taking the
    /// next 10 questions each day. Every question is used once before any
    /// repeats — random picking from a small bank was why questions kept
    /// coming back within the same session.
    static func daily(dayIndex: Int) -> TriviaPuzzle {
        let bank = TriviaBank.questions
        guard bank.count >= perRound else {
            return TriviaPuzzle(id: "trivia-day-\(dayIndex)", questions: bank)
        }
        let roundsPerCycle = bank.count / perRound
        let cycle = dayIndex / roundsPerCycle
        let round = ((dayIndex % roundsPerCycle) + roundsPerCycle) % roundsPerCycle
        var rng = SeededGenerator(seed: 0x7217 &+ UInt64(bitPattern: Int64(cycle)))
        let order = rng.shuffled(bank)
        let slice = Array(order[(round * perRound)..<(round * perRound + perRound)])
        return TriviaPuzzle(id: "trivia-day-\(dayIndex)",
                            questions: shuffleOptions(slice, rng: &rng))
    }

    static func generate(seed: UInt64, excluding excluded: Set<Int> = []) -> TriviaPuzzle {
        var rng = SeededGenerator(seed: seed)
        let bank = TriviaBank.questions
        // Prefer questions the player hasn't seen recently; only fall back to
        // the full bank once every question has been used, so consecutive
        // rounds never repeat while unseen questions remain.
        let fresh = bank.filter { !excluded.contains($0.id) }
        let pool = fresh.count >= perRound ? fresh : bank
        let picked = Array(rng.shuffled(pool).prefix(perRound))
        return TriviaPuzzle(id: "trivia-\(seed)", questions: shuffleOptions(picked, rng: &rng))
    }

    /// Shuffles each question's answers and remaps the correct indices, so the
    /// right answer isn't always the one the bank happened to list first.
    /// `order` questions keep their sequence — there the option order *is*
    /// the puzzle — but their labels are still rearranged on screen.
    private static func shuffleOptions(_ qs: [Question],
                                       rng: inout SeededGenerator) -> [Question] {
        qs.map { q in
            let positions = Array(q.options.indices)
            let shuffled = q.style == .order ? positions : rng.shuffled(positions)
            // shuffled[newIndex] == oldIndex, so invert it to remap answers.
            var oldToNew = [Int](repeating: 0, count: positions.count)
            for (newIndex, oldIndex) in shuffled.enumerated() {
                oldToNew[oldIndex] = newIndex
            }
            return Question(id: q.id,
                            category: q.category,
                            prompt: q.prompt,
                            options: shuffled.map { q.options[$0] },
                            correct: q.correct.map { oldToNew[$0] },
                            style: q.style)
        }
    }

    /// Question ids stay as they are in the bank so played questions can be
    /// remembered across rounds; the UI uses array positions instead.
}

private enum TriviaBank {
    static let questions: [TriviaPuzzle.Question] = {
        guard let url = Bundle.main.url(forResource: "trivia_questions", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let qs = try? JSONDecoder().decode([TriviaPuzzle.Question].self, from: data),
              !qs.isEmpty
        else { return fallback }
        return qs
    }()

    /// Kept tiny on purpose: if the bundled bank ever fails to load we want
    /// the game to still run, not to silently serve a broken round.
    private static let fallback: [TriviaPuzzle.Question] = [
        .init(id: 0, category: "España", prompt: "¿Cuál es la capital de Galicia?",
              options: ["A Coruña", "Santiago de Compostela", "Vigo", "Lugo"], correct: [1], style: .multiple),
        .init(id: 1, category: "Ciencia", prompt: "El agua hierve a 100 ºC al nivel del mar.",
              options: ["Verdadero", "Falso"], correct: [0], style: .boolean),
        .init(id: 2, category: "Geografía", prompt: "Ordena estos planetas por distancia al Sol.",
              options: ["Mercurio", "Venus", "Tierra", "Marte"], correct: [0, 1, 2, 3], style: .order),
    ]
}

struct WordLadderPuzzle: Identifiable, Sendable, Hashable {
    let id: String
    let start: String
    let end: String
    /// A curated Spanish lexicon. A ladder is only generated from these words,
    /// avoiding the proper nouns and dictionary curiosities in broad word lists.
    let validWords: Set<String>
    /// One shortest route. Its length equals the Hamming distance between the
    /// endpoints, which proves that no shorter route can exist.
    let solution: [String]

    var minimumSteps: Int { solution.count - 1 }

    func isValidStep(from previous: String, to next: String) -> Bool {
        guard next.count == start.count, validWords.contains(next), previous != next else { return false }
        return zip(previous, next).filter { $0 != $1 }.count == 1
    }

    static func generate(seed: UInt64) -> WordLadderPuzzle {
        var rng = SeededGenerator(seed: seed)
        let routes = WordLadderBank.routes
        let solution = routes.isEmpty ? ["CASA", "CAMA", "CIMA"] : routes[rng.int(routes.count)]
        return .init(id: "ladder-\(seed)", start: solution[0], end: solution.last!,
                     validWords: WordLadderBank.words, solution: solution)
    }
}

private enum WordLadderBank {
    /// Every route changes exactly one letter per rung and has as many moves
    /// as its endpoints' differing positions, making it globally shortest.
    static let routes: [[String]] = [
        ["CASA", "CAMA", "CIMA"],
        ["CAMA", "CIMA", "CITA"],
        ["PESO", "PISO", "PITO", "PITA"],
        ["RAMA", "RIMA", "CIMA"],
        ["PELO", "PALO", "PATO"],
        ["RICO", "RITO", "RATO", "RATA"],
        ["LOBO", "LOCO", "LOCA"],
        ["FOTO", "FOCO", "FOCA"],
        ["MANO", "MALO", "PALO", "PALA"],
        ["RANA", "RARA", "PARA", "PARE"],
        ["SECO", "SENO", "SANO", "MANO"],
        ["RAMA", "RIMA", "CIMA", "CITA"],
        ["PERA", "PELA", "PALA", "SALA"],
        ["ROSA", "RISA", "RIMA", "CIMA"],
        ["CARO", "CARA", "CAMA", "CIMA"]
    ]

    static let words = Set(routes.flatMap { $0 })
}

struct DifferencesPuzzle: Identifiable, Sendable, Hashable {
    struct Item: Identifiable, Sendable, Hashable { let id: Int; let name: String; let x: Double; let y: Double; let color: String; let changed: Bool }
    let id: String; let left: [Item]; let right: [Item]; let differenceIDs: Set<Int>
    static func generate(seed: UInt64) -> DifferencesPuzzle {
        var rng = SeededGenerator(seed: seed)
        let names=["circle","square","triangle","star","heart","cloud","leaf","sun.max","moon","bolt","fish","car"]
        let colors=["red","blue","green","orange","purple","pink","yellow","teal"]
        var left:[Item]=[]; for i in 0..<12 { left.append(.init(id:i,name:names[i%names.count],x:0.12+Double(rng.int(76))/100,y:0.14+Double(rng.int(72))/100,color:colors[rng.int(colors.count)],changed:false)) }
        let diff=Set(Array(0..<12).shuffled().prefix(7)); var right:[Item]=[]
        for it in left { if diff.contains(it.id) { let mode=rng.int(3); right.append(.init(id:it.id,name: mode==0 ? names[rng.int(names.count)] : it.name, x:min(0.9,max(0.1,it.x + (mode==1 ? 0.08 : 0))), y:min(0.9,max(0.1,it.y + (mode==1 ? -0.06 : 0))), color: mode==2 ? colors[rng.int(colors.count)] : it.color, changed:true)) } else { right.append(it) } }
        return .init(id:"diff-\(seed)", left:left, right:right, differenceIDs:diff)
    }
}

// MARK: - Escalera de palabras

struct WordLadderGame: View {
    let puzzle: WordLadderPuzzle
    @ObservedObject private var progress = PuzzleProgress.shared

    @State private var rungs: [String] = []
    @State private var entry = ""
    @State private var elapsed = 0
    @State private var finished = false
    @State private var toast: PZToast?
    @State private var result: PZResult?
    @FocusState private var entryFocused: Bool

    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var current: String { rungs.last ?? puzzle.start }
    private var nextNumber: Int { rungs.count + 2 }
    private var remaining: Int { puzzle.minimumSteps - rungs.count }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PZSpace.lg) {
                header
                instructions
                ladderCard
                entryCard
            }
            .padding(.horizontal, PZSpace.screenH)
            .padding(.vertical, PZSpace.md)
        }
        .background(LiquidCanvasBackground())
        .navigationTitle("Escalera de palabras")
        .navigationBarTitleDisplayMode(.inline)
        .pzRules(.ladder)
        .pzToast($toast)
        .onAppear { restore() }
        .onReceive(tick) { _ in
            guard !finished else { return }
            elapsed += 1
            if elapsed.isMultiple(of: 5) { progress.setElapsed(puzzle.id, elapsed) }
        }
        .sheet(item: $result) { PZResultSheet(result: $0) }
    }

    private var header: some View {
        HStack {
            PZStat(label: "Pasos", value: "\(rungs.count)/\(puzzle.minimumSteps)")
            Spacer()
            PZStat(label: "Tiempo", value: PuzzleTiming.clock(TimeInterval(elapsed)), alignment: .trailing)
        }
    }

    private var instructions: some View {
        VStack(alignment: .leading, spacing: PZSpace.xs) {
            Text("CAMBIA UNA LETRA")
                .pzEyebrowStyle(PZ.ladder)
            Text("Llega de \(puzzle.start) a \(puzzle.end) en \(puzzle.minimumSteps) pasos. Cada peldaño debe ser una palabra española válida.")
                .font(PZFont.body)
                .foregroundStyle(PZColor.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var ladderCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            ladderRow(number: 1, word: puzzle.start, change: "inicio", isEndpoint: true)
            ForEach(Array(rungs.enumerated()), id: \.offset) { index, word in
                PZRule()
                ladderRow(number: index + 2, word: word,
                          change: changeDescription(from: index == 0 ? puzzle.start : rungs[index - 1], to: word),
                          isEndpoint: word == puzzle.end)
            }
            if !finished {
                PZRule()
                HStack(spacing: PZSpace.md) {
                    Text("\(nextNumber)").font(PZFont.metric).foregroundStyle(PZColor.inkTertiary)
                    Text(remaining == 1 ? "Último peldaño" : "Quedan \(max(0, remaining)) peldaños")
                        .font(PZFont.body).foregroundStyle(PZColor.inkSecondary)
                }
                .padding(PZSpace.cardPad)
            }
        }
        .pzCard()
    }

    private func ladderRow(number: Int, word: String, change: String, isEndpoint: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: PZSpace.md) {
            Text("\(number)").font(PZFont.metric).foregroundStyle(PZ.ladder).monospacedDigit()
            Text(word).font(.system(.title3, design: .monospaced).weight(.bold)).tracking(2)
            Spacer(minLength: PZSpace.sm)
            Text(change).font(PZFont.caption).foregroundStyle(isEndpoint ? PZ.ladder : PZColor.inkSecondary)
        }
        .padding(PZSpace.cardPad)
        .accessibilityElement(children: .combine)
    }

    private var entryCard: some View {
        VStack(alignment: .leading, spacing: PZSpace.md) {
            Text("SIGUIENTE PALABRA").pzEyebrowStyle(PZ.ladder)
            HStack(spacing: PZSpace.sm) {
                TextField("4 letras", text: $entry)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .font(.system(.title3, design: .monospaced).weight(.bold))
                    .tracking(2)
                    .focused($entryFocused)
                    .onChange(of: entry) { _, value in
                        entry = normalized(value)
                    }
                    .onSubmit { submit() }
                    .disabled(finished)
                Button("Añadir", action: submit)
                    .buttonStyle(.borderedProminent)
                    .tint(PZ.ladder)
                    .disabled(entry.count != 4 || finished)
            }
            Text("Solo se acepta un cambio de letra y no puedes repetir un peldaño.")
                .font(PZFont.caption).foregroundStyle(PZColor.inkSecondary)
        }
        .padding(PZSpace.cardPad)
        .pzCard()
    }

    private func restore() {
        guard rungs.isEmpty else { return }
        elapsed = progress.elapsed(puzzle.id)
        let saved = progress.found(puzzle.id)
        var previous = puzzle.start
        for word in saved where puzzle.isValidStep(from: previous, to: word) && !rungs.contains(word) {
            rungs.append(word)
            previous = word
        }
        finished = rungs.last == puzzle.end && rungs.count == puzzle.minimumSteps
        entryFocused = !finished
    }

    private func submit() {
        let word = normalized(entry)
        guard !word.isEmpty else { return }
        guard word.count == puzzle.start.count else {
            toast = PZToast(text: "Escribe una palabra de 4 letras", kind: .error); return
        }
        guard !rungs.contains(word) && word != puzzle.start else {
            toast = PZToast(text: "No puedes repetir un peldaño", kind: .error); return
        }
        guard puzzle.validWords.contains(word) else {
            toast = PZToast(text: "Esa palabra no está en el diccionario del juego", kind: .error); return
        }
        guard puzzle.isValidStep(from: current, to: word) else {
            toast = PZToast(text: "Cambia una sola letra", kind: .error); return
        }
        guard rungs.count < puzzle.minimumSteps else {
            toast = PZToast(text: "La ruta más corta ya no admite más pasos", kind: .error); return
        }
        let proposedSteps = rungs.count + 1
        guard word != puzzle.end || proposedSteps == puzzle.minimumSteps else {
            toast = PZToast(text: "Aún no has llegado en la ruta más corta", kind: .error); return
        }
        guard word == puzzle.end || proposedSteps < puzzle.minimumSteps else {
            toast = PZToast(text: "El último peldaño debe ser \(puzzle.end)", kind: .error); return
        }

        rungs.append(word)
        progress.setFound(puzzle.id, rungs)
        entry = ""
        PZHaptics.success()

        if word == puzzle.end {
            finish()
        }
    }

    private func finish() {
        guard !finished else { return }
        finished = true
        progress.markDone(puzzle.id)
        progress.recordTime(TimeInterval(max(5, elapsed)), kind: .ladder, puzzleID: puzzle.id)
        progress.noteDayIfComplete()
        result = PZResult(kind: .ladder, didWin: true, headline: "¡Escalera completa!",
                          detail: "Ruta más corta en \(puzzle.minimumSteps) pasos.",
                          metrics: [("Pasos", "\(puzzle.minimumSteps)"),
                                    ("Tiempo", PuzzleTiming.clock(TimeInterval(elapsed)))],
                          shareText: "NewsRaider Escalera de palabras · \(puzzle.minimumSteps) pasos · \(PuzzleTiming.clock(TimeInterval(elapsed)))")
    }

    private func normalized(_ value: String) -> String {
        value.uppercased().folding(options: .diacriticInsensitive, locale: Locale(identifier: "es_ES"))
            .filter(\.isLetter).prefix(4).uppercased()
    }

    private func changeDescription(from previous: String, to next: String) -> String {
        guard let pair = zip(previous, next).enumerated().first(where: { $0.element.0 != $0.element.1 }) else { return "" }
        return "\(pair.element.0)→\(pair.element.1), pos. \(pair.offset + 1)"
    }
}

// MARK: - Trivia 10 en 60

struct TriviaGame: View {
    let puzzle: TriviaPuzzle
    @ObservedObject private var progress = PuzzleProgress.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var index = 0
    @State private var score = 0
    @State private var streak = 0
    @State private var bestStreak = 0
    @State private var selectedOrder: [Int] = []
    @State private var lockedChoice: Int?
    @State private var wasCorrect: Bool?
    @State private var remaining = 60
    @State private var finished = false
    @State private var result: PZResult?
    @State private var eliminated: Set<Int> = []
    @State private var hintsTaken = 0

    private let total = 60
    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var q: TriviaPuzzle.Question {
        puzzle.questions[min(index, puzzle.questions.count - 1)]
    }
    private var isUrgent: Bool { remaining <= 10 }

    var body: some View {
        VStack(spacing: PZSpace.lg) {
            header
            questionCard
            answers
            Spacer(minLength: 0)
        }
        .padding(.horizontal, PZSpace.screenH)
        .padding(.top, PZSpace.sm)
        .background(LiquidCanvasBackground())
        .navigationTitle("10 en 60")
        .navigationBarTitleDisplayMode(.inline)
        .pzRules(.trivia)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                PZHintButton(kind: .trivia,
                             isAvailable: !finished && lockedChoice == nil
                                          && q.style != .order && eliminated.isEmpty,
                             used: progress.hintsUsed(puzzle.id)) { useFiftyFifty() }
            }
        }
        .onReceive(tick) { _ in
            guard !finished else { return }
            remaining -= 1
            if remaining <= 0 { finish() }
        }
        .sheet(item: $result) { PZResultSheet(result: $0) }
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: PZSpace.xxs) {
                Text("PREGUNTA").pzLabelStyle()
                Text("\(min(index + 1, puzzle.questions.count))/\(puzzle.questions.count)")
                    .font(PZFont.metric)
                    .monospacedDigit()
            }
            Spacer()
            timerRing
            Spacer()
            VStack(alignment: .trailing, spacing: PZSpace.xxs) {
                Text("PUNTOS").pzLabelStyle()
                Text("\(score)")
                    .font(PZFont.metric)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                if streak >= 2 {
                    Label("\(streak)", systemImage: "flame.fill")
                        .font(PZFont.caption)
                        .foregroundStyle(.orange)
                        .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .animation(reduceMotion ? nil : PZAnim.reveal, value: streak)
    }

    private var timerRing: some View {
        ZStack {
            Circle()
                .stroke(PZColor.fill, lineWidth: 7)
            Circle()
                .trim(from: 0, to: CGFloat(max(0, remaining)) / CGFloat(total))
                .stroke(isUrgent ? PZColor.danger : PZ.trivia,
                        style: .init(lineWidth: 7, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1), value: remaining)
            Text("\(max(0, remaining))")
                .font(.system(size: 24, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(isUrgent ? PZColor.danger : .primary)
                .contentTransition(.numericText(countsDown: true))
        }
        .frame(width: 68, height: 68)
        .scaleEffect(isUrgent && !reduceMotion ? 1.06 : 1)
        .animation(isUrgent && !reduceMotion
                   ? .easeInOut(duration: 0.5).repeatForever(autoreverses: true)
                   : .default, value: isUrgent)
        .accessibilityLabel("Quedan \(max(0, remaining)) segundos")
    }

    // MARK: Question

    private var questionCard: some View {
        VStack(alignment: .leading, spacing: PZSpace.sm) {
            HStack(spacing: PZSpace.xs) {
                Image(systemName: styleIcon)
                    .font(.system(size: 11, weight: .bold))
                Text(q.category)
                    .font(PZFont.label)
                    .textCase(.uppercase)
                    .kerning(0.6)
            }
            .foregroundStyle(PZ.trivia)
            .padding(.horizontal, PZSpace.sm)
            .padding(.vertical, PZSpace.xs)
            .background(PZ.trivia.opacity(0.14), in: Capsule())

            Text(q.prompt)
                .font(PZFont.title)
                .fixedSize(horizontal: false, vertical: true)

            if q.style == .order {
                Label("Toca las opciones en orden", systemImage: "hand.tap")
                    .font(PZFont.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(PZSpace.xl)
        .background(PZColor.surface, in: PZRadius.rect(PZRadius.card))
        .id(index)
        .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)))
    }

    private var styleIcon: String {
        switch q.style {
        case .multiple: return "list.bullet"
        case .boolean:  return "checkmark.circle"
        case .intruder: return "eye.trianglebadge.exclamationmark"
        case .order:    return "arrow.up.arrow.down"
        }
    }

    // MARK: Answers

    private var answers: some View {
        VStack(spacing: PZSpace.sm) {
            ForEach(q.options.indices, id: \.self) { i in
                answerButton(i)
            }
        }
        .animation(reduceMotion ? nil : PZAnim.reveal, value: lockedChoice)
        .animation(reduceMotion ? nil : PZAnim.reveal, value: selectedOrder)
    }

    private func answerButton(_ i: Int) -> some View {
        let picked = selectedOrder.contains(i)
        let position = selectedOrder.firstIndex(of: i)
        let revealedCorrect = lockedChoice != nil && q.correct.contains(i)
        let revealedWrong = lockedChoice == i && wasCorrect == false

        return Button { choose(i) } label: {
            HStack(spacing: PZSpace.md) {
                marker(index: i, position: position,
                       correct: revealedCorrect, wrong: revealedWrong)
                Text(q.options[i])
                    .font(PZFont.chip)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, PZSpace.lg)
            .padding(.vertical, PZSpace.md)
            .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
            .background(background(picked: picked,
                                   correct: revealedCorrect,
                                   wrong: revealedWrong),
                        in: PZRadius.rect(PZRadius.tile))
            .overlay {
                PZRadius.rect(PZRadius.tile)
                    .stroke(strokeColor(picked: picked,
                                        correct: revealedCorrect,
                                        wrong: revealedWrong),
                            lineWidth: 1.5)
            }
        }
        .buttonStyle(.plain)
        .disabled(lockedChoice != nil || eliminated.contains(i))
        .opacity(eliminated.contains(i) ? 0.3 : 1)
        .accessibilityLabel(q.options[i])
        .accessibilityValue(picked ? "seleccionada" : "")
    }

    @ViewBuilder
    private func marker(index i: Int, position: Int?, correct: Bool, wrong: Bool) -> some View {
        ZStack {
            Circle()
                .fill(correct ? PZColor.success.opacity(0.18)
                      : wrong ? PZColor.danger.opacity(0.18)
                      : position != nil ? PZ.trivia.opacity(0.2)
                      : PZColor.fill)
            if correct {
                Image(systemName: "checkmark")
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(PZColor.success)
            } else if wrong {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(PZColor.danger)
            } else if let position {
                Text("\(position + 1)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(PZ.trivia)
            } else {
                Text(letter(i))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 30, height: 30)
    }

    private func letter(_ i: Int) -> String {
        ["A", "B", "C", "D", "E", "F"][min(i, 5)]
    }

    private func background(picked: Bool, correct: Bool, wrong: Bool) -> Color {
        if correct { return PZColor.success.opacity(0.14) }
        if wrong { return PZColor.danger.opacity(0.14) }
        if picked { return PZ.trivia.opacity(0.14) }
        return PZColor.surface
    }

    private func strokeColor(picked: Bool, correct: Bool, wrong: Bool) -> Color {
        if correct { return PZColor.success.opacity(0.55) }
        if wrong { return PZColor.danger.opacity(0.55) }
        if picked { return PZ.trivia.opacity(0.5) }
        return .clear
    }

    // MARK: Flow

    /// Removes two wrong options. The clock here is the 60-second budget, so
    /// the penalty comes off the remaining time rather than being added on.
    private func useFiftyFifty() {
        let wrong = q.options.indices.filter { !q.correct.contains($0) }
        guard wrong.count >= 2 else { return }
        progress.addHint(puzzle.id)
        hintsTaken += 1
        // No time penalty here: the round is already a 60-second sprint, so
        // the cost is having it show up in the result instead.
        withAnimation(PZAnim.reveal) { eliminated = Set(wrong.shuffled().prefix(2)) }
        PZHaptics.warning()
    }

    private func choose(_ i: Int) {
        guard lockedChoice == nil, !finished else { return }
        if q.style == .order {
            guard !selectedOrder.contains(i) else { return }
            selectedOrder.append(i)
            PZHaptics.tick()
            if selectedOrder.count == q.correct.count {
                resolve(selectedOrder == q.correct, choice: i)
            }
        } else {
            resolve(q.correct.contains(i), choice: i)
        }
    }

    /// Briefly reveals the right answer before advancing, so a wrong tap
    /// teaches something instead of just flashing past.
    private func resolve(_ ok: Bool, choice: Int) {
        lockedChoice = choice
        wasCorrect = ok
        if ok {
            score += 1 + max(0, remaining / 15)
            streak += 1
            bestStreak = max(bestStreak, streak)
            PZHaptics.success()
        } else {
            streak = 0
            PZHaptics.error()
        }
        Task {
            try? await Task.sleep(nanoseconds: ok ? 450_000_000 : 900_000_000)
            await MainActor.run { advance() }
        }
    }

    private func advance() {
        guard !finished else { return }
        selectedOrder = []
        lockedChoice = nil
        wasCorrect = nil
        eliminated = []
        if index >= puzzle.questions.count - 1 {
            finish()
        } else {
            withAnimation(reduceMotion ? nil : PZAnim.reveal) { index += 1 }
        }
    }

    private func finish() {
        guard !finished else { return }
        finished = true
        let elapsed = total - remaining
        progress.markDone(puzzle.id)
        progress.recordTime(TimeInterval(max(5, elapsed)), kind: .trivia, puzzleID: puzzle.id)
        progress.noteDayIfComplete()
        let answered = min(index + 1, puzzle.questions.count)
        result = PZResult(
            kind: .trivia,
            didWin: score > 0,
            headline: "\(score) puntos",
            detail: "\(answered) de \(puzzle.questions.count) preguntas · racha máxima \(bestStreak)"
                + (hintsTaken > 0 ? " · con \(hintsTaken) pista\(hintsTaken == 1 ? "" : "s")" : ""),
            metrics: [("Puntos", "\(score)"),
                      ("Tiempo", "\(elapsed)s"),
                      (hintsTaken > 0 ? "Pistas" : "Racha",
                       hintsTaken > 0 ? "\(hintsTaken)" : "\(bestStreak)")],
            shareText: "NewsRaider 10 en 60 · \(score) pts · \(elapsed)s"
                + (hintsTaken > 0 ? " · \(hintsTaken) pista\(hintsTaken == 1 ? "" : "s") 😅" : " · sin pistas"))
    }
}


// MARK: - Word list base game

// MARK: - Número objetivo / Cifras

struct NumbersPuzzle: Identifiable, Sendable, Hashable {
    let id: String
    let target: Int
    let numbers: [Int]
    let solution: String

    static func generate(seed: UInt64) -> NumbersPuzzle {
        var rng = SeededGenerator(seed: seed)
        let large = [25, 50, 75, 100]
        let small = Array(1...10) + Array(1...10)
        for _ in 0..<80 {
            let bigCount = 1 + rng.int(3)
            var pool = rng.shuffled(large).prefix(bigCount).map { $0 }
            pool += rng.shuffled(small).prefix(6 - bigCount)
            let target = 100 + rng.int(900)
            if let sol = NumbersSolver.solve(numbers: pool, target: target, exactOnly: true) {
                return .init(id: "num-\(seed)", target: target, numbers: pool, solution: sol.expression)
            }
        }
        let fallback = [100, 8, 7, 4, 3, 2]
        return .init(id: "num-\(seed)", target: 527, numbers: fallback,
                     solution: NumbersSolver.solve(numbers: fallback, target: 527, exactOnly: false)?.expression ?? "")
    }
}

struct NumbersSolver {
    struct Result { let value: Int; let expression: String; var distance: Int }
    private struct Node: Hashable { let value: Int; let expression: String }

    static func solve(numbers: [Int], target: Int, exactOnly: Bool) -> Result? {
        var best: Result?
        func consider(_ value: Int, _ expression: String) {
            let d = abs(value - target)
            if best == nil || d < best!.distance {
                best = Result(value: value, expression: expression, distance: d)
            }
        }
        func walk(_ nodes: [Node]) {
            for n in nodes { consider(n.value, n.expression) }
            if best?.distance == 0 { return }
            guard nodes.count > 1 else { return }
            for i in 0..<nodes.count { for j in (i+1)..<nodes.count {
                let a = nodes[i], b = nodes[j]
                var rest = nodes.enumerated().compactMap { idx, n in (idx == i || idx == j) ? nil : n }
                var next: [Node] = [
                    Node(value: a.value + b.value, expression: "(\(a.expression)+\(b.expression))"),
                    Node(value: abs(a.value - b.value), expression: a.value >= b.value ? "(\(a.expression)-\(b.expression))" : "(\(b.expression)-\(a.expression))"),
                    Node(value: a.value * b.value, expression: "(\(a.expression)×\(b.expression))")
                ]
                if b.value != 0, a.value % b.value == 0 { next.append(Node(value: a.value / b.value, expression: "(\(a.expression)÷\(b.expression))")) }
                if a.value != 0, b.value % a.value == 0 { next.append(Node(value: b.value / a.value, expression: "(\(b.expression)÷\(a.expression))")) }
                for n in next where n.value > 0 && n.value < 10_000 {
                    rest.append(n); walk(rest); rest.removeLast()
                    if best?.distance == 0 { return }
                }
            } }
        }
        walk(numbers.map { Node(value: $0, expression: "\($0)") })
        if exactOnly, best?.distance != 0 { return nil }
        return best
    }
}

struct NumbersGame: View {
    let puzzle: NumbersPuzzle
    @ObservedObject private var progress = PuzzleProgress.shared

    /// A tile keeps its identity so selection highlighting never jumps around
    /// when equal values appear twice (e.g. two 4s).
    private struct Tile: Identifiable, Hashable {
        let id: Int
        let value: Int
        var consumed: Bool = false
        var isResult: Bool = false
    }

    private struct Step: Identifiable {
        let id: Int
        let text: String
        let consumedIDs: [Int]
        let producedID: Int
    }

    @State private var tiles: [Tile]
    @State private var steps: [Step] = []
    @State private var firstID: Int?
    @State private var op: String?
    @State private var result: PZResult?
    @State private var toast: PZToast?
    @State private var elapsed = 0
    @State private var finished = false
    @State private var nextTileID: Int
    @State private var flashTarget = false

    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private let operators = ["+", "−", "×", "÷"]

    init(puzzle: NumbersPuzzle) {
        self.puzzle = puzzle
        let initial = puzzle.numbers.enumerated().map { Tile(id: $0.offset, value: $0.element) }
        _tiles = State(initialValue: initial)
        _nextTileID = State(initialValue: initial.count)
    }

    private var activeTiles: [Tile] { tiles.filter { !$0.consumed } }
    private var firstTile: Tile? { firstID.flatMap { id in tiles.first { $0.id == id } } }
    private var bestValue: Int {
        activeTiles.map(\.value).min(by: { abs($0 - puzzle.target) < abs($1 - puzzle.target) }) ?? 0
    }

    var body: some View {
        GeometryReader { geo in
            let landscape = geo.size.width > geo.size.height * 1.2
            Group {
                if landscape {
                    HStack(alignment: .top, spacing: PZSpace.xl) {
                        ScrollView { VStack(spacing: PZSpace.lg) { targetCard; equationBar; tileGrid } }
                            .frame(width: geo.size.width * 0.52)
                        ScrollView { VStack(spacing: PZSpace.lg) { operatorRow; actionRow; historyPanel } }
                    }
                    .padding(PZSpace.screenH)
                } else {
                    ScrollView {
                        VStack(spacing: PZSpace.lg) {
                            targetCard
                            equationBar
                            tileGrid
                            operatorRow
                            actionRow
                            historyPanel
                        }
                        .padding(PZSpace.screenH)
                    }
                }
            }
        }
        .background(LiquidCanvasBackground())
        .navigationTitle("Cifras")
        .navigationBarTitleDisplayMode(.inline)
        .pzToast($toast)
        .pzRules(.numbers)
        .onReceive(tick) { _ in
            guard !finished else { return }
            elapsed += 1
            if elapsed % 5 == 0 { progress.setElapsed(puzzle.id, elapsed) }
        }
        .sheet(item: $result) { PZResultSheet(result: $0) }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                PZHintButton(kind: .numbers,
                             isAvailable: !finished,
                             used: progress.hintsUsed(puzzle.id)) {
                    progress.addHint(puzzle.id)
                    elapsed += PZHintButton.penalty
                    progress.setElapsed(puzzle.id, elapsed)
                    toast = PZToast(text: "\(puzzle.solution) · +2 min", kind: .info)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Empezar de nuevo", systemImage: "arrow.counterclockwise", role: .destructive) { resetAll() }
                } label: { Image(systemName: "ellipsis.circle") }
            }
        }
    }

    // MARK: Target

    private var targetCard: some View {
        VStack(spacing: PZSpace.xxs) {
            Text("OBJETIVO").pzLabelStyle()
            Text("\(puzzle.target)")
                .font(.system(size: 54, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .scaleEffect(flashTarget ? 1.08 : 1)
                .animation(.bouncy(duration: 0.4), value: flashTarget)
            HStack(spacing: PZSpace.md) {
                Label(PuzzleTiming.clock(TimeInterval(elapsed)), systemImage: "clock")
                Label("a \(abs(bestValue - puzzle.target))", systemImage: "target")
            }
            .font(PZFont.caption)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(PZSpace.xl)
        .background(PZ.numbers.opacity(0.14), in: PZRadius.rect(PZRadius.card))
    }

    // MARK: Equation bar — always shows exactly what you have pressed

    private var equationBar: some View {
        HStack(spacing: PZSpace.sm) {
            slot(firstTile.map { "\($0.value)" }, filled: firstTile != nil)
            slot(op, filled: op != nil, width: 52)
            slot(nil, filled: false)
            Text("=")
                .font(PZFont.title)
                .foregroundStyle(.tertiary)
            Text("?")
                .font(PZFont.title)
                .foregroundStyle(.tertiary)
            Spacer(minLength: 0)
            if firstID != nil || op != nil {
                Button {
                    stepBackSelection()
                } label: {
                    Image(systemName: "delete.left")
                        .font(.system(size: 17, weight: .semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(PZ.numbers)
                .accessibilityLabel("Borrar selección")
            }
        }
        .padding(.horizontal, PZSpace.lg)
        .padding(.vertical, PZSpace.md)
        .background(PZColor.surface, in: PZRadius.rect(PZRadius.card))
        .overlay(alignment: .topLeading) {
            Text(hintText)
                .font(PZFont.label)
                .textCase(.uppercase)
                .kerning(0.6)
                .foregroundStyle(.secondary)
                .padding(.leading, PZSpace.lg)
                .offset(y: -PZSpace.md)
        }
        .padding(.top, PZSpace.sm)
    }

    private var hintText: String {
        if firstID == nil { return "Elige el primer número" }
        if op == nil { return "Elige la operación" }
        return "Elige el segundo número"
    }

    private func slot(_ text: String?, filled: Bool, width: CGFloat = 74) -> some View {
        Text(text ?? "—")
            .font(PZFont.title)
            .monospacedDigit()
            .foregroundStyle(filled ? .white : .secondary)
            .frame(width: width, height: 46)
            .background(filled ? PZ.numbers : PZColor.fill, in: PZRadius.rect(PZRadius.tile))
            .animation(PZAnim.reveal, value: filled)
    }

    // MARK: Tiles

    private var tileGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: PZSpace.sm), count: 3),
                  spacing: PZSpace.sm) {
            ForEach(tiles) { tile in
                if !tile.consumed { tileButton(tile) }
            }
        }
        .animation(PZAnim.shuffle, value: tiles)
    }

    private func tileButton(_ tile: Tile) -> some View {
        let isSelected = firstID == tile.id
        let waiting = firstID != nil && op == nil
        return Button { tapTile(tile) } label: {
            VStack(spacing: 2) {
                Text("\(tile.value)")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .monospacedDigit()
                if tile.isResult {
                    Text("resultado")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(isSelected ? .white.opacity(0.85) : .secondary)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 64)
            .background(isSelected ? PZ.numbers : PZColor.surface, in: PZRadius.rect(PZRadius.tile))
            .foregroundStyle(isSelected ? .white : .primary)
            .overlay {
                PZRadius.rect(PZRadius.tile)
                    .stroke(isSelected ? Color.clear : PZ.numbers.opacity(waiting ? 0.0 : 0.25), lineWidth: 1.5)
            }
            .scaleEffect(isSelected ? 1.04 : 1)
        }
        .buttonStyle(.plain)
        .animation(PZAnim.reveal, value: isSelected)
        .accessibilityLabel("\(tile.value)")
        .accessibilityValue(isSelected ? "seleccionado" : "disponible")
    }

    // MARK: Operators

    private var operatorRow: some View {
        HStack(spacing: PZSpace.sm) {
            ForEach(operators, id: \.self) { symbol in
                let enabled = firstID != nil
                let isSelected = op == symbol
                Button { chooseOperator(symbol) } label: {
                    Text(symbol)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .background(isSelected ? PZ.numbers : PZColor.surface, in: PZRadius.rect(PZRadius.tile))
                        .foregroundStyle(isSelected ? .white : (enabled ? PZ.numbers : Color.secondary))
                }
                .buttonStyle(.plain)
                .disabled(!enabled)
                .opacity(enabled ? 1 : 0.5)
                .animation(PZAnim.reveal, value: isSelected)
                .accessibilityLabel(operatorName(symbol))
            }
        }
    }

    private func operatorName(_ symbol: String) -> String {
        switch symbol {
        case "+": return "más"
        case "−": return "menos"
        case "×": return "por"
        default:  return "entre"
        }
    }

    private var actionRow: some View {
        HStack(spacing: PZSpace.sm) {
            Button("Deshacer paso") { undoStep() }
                .buttonStyle(PZButton(filled: false))
                .disabled(steps.isEmpty)
            Button("Terminar") { finish() }
                .buttonStyle(PZButton(filled: true, tint: PZ.numbers))
        }
    }

    // MARK: History

    private var historyPanel: some View {
        VStack(alignment: .leading, spacing: PZSpace.sm) {
            Text("PASOS").pzLabelStyle()
            if steps.isEmpty {
                Text("Toca un número, luego una operación y después el segundo número.")
                    .font(PZFont.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ForEach(steps) { step in
                    HStack {
                        Text(step.text).font(PZFont.body).monospacedDigit()
                        Spacer()
                        if let last = steps.last, last.id == step.id {
                            Button { undoStep() } label: { Image(systemName: "arrow.uturn.backward") }
                                .buttonStyle(.plain)
                                .foregroundStyle(PZ.numbers)
                                .accessibilityLabel("Deshacer este paso")
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(PZSpace.lg)
        .background(PZColor.surface, in: PZRadius.rect(PZRadius.card))
    }

    // MARK: Interaction

    private func tapTile(_ tile: Tile) {
        PZHaptics.tick()
        guard let firstID else {
            self.firstID = tile.id
            return
        }
        if firstID == tile.id, op == nil {
            self.firstID = nil          // tapping the same tile deselects
            return
        }
        guard let op else {
            self.firstID = tile.id      // no operator yet: move the selection
            return
        }
        compute(firstID: firstID, op: op, secondID: tile.id)
    }

    private func chooseOperator(_ symbol: String) {
        guard firstID != nil else { return }
        op = (op == symbol) ? nil : symbol
        PZHaptics.tick()
    }

    private func stepBackSelection() {
        if op != nil { op = nil } else { firstID = nil }
        PZHaptics.tick()
    }

    private func compute(firstID: Int, op symbol: String, secondID: Int) {
        guard let a = tiles.first(where: { $0.id == firstID })?.value,
              let b = tiles.first(where: { $0.id == secondID })?.value else { return }
        let value: Int?
        switch symbol {
        case "+": value = a + b
        case "−": value = a - b
        case "×": value = a * b
        case "÷": value = (b != 0 && a % b == 0) ? a / b : nil
        default:  value = nil
        }
        guard let value else {
            toast = PZToast(text: "\(a) ÷ \(b) no es exacto", kind: .error)
            PZHaptics.error()
            self.op = nil
            return
        }
        guard value > 0 else {
            toast = PZToast(text: "El resultado debe ser positivo", kind: .error)
            PZHaptics.error()
            self.op = nil
            return
        }

        let produced = Tile(id: nextTileID, value: value, isResult: true)
        withAnimation(PZAnim.shuffle) {
            for i in tiles.indices where tiles[i].id == firstID || tiles[i].id == secondID {
                tiles[i].consumed = true
            }
            tiles.append(produced)
        }
        steps.append(Step(id: steps.count,
                          text: "\(a) \(symbol) \(b) = \(value)",
                          consumedIDs: [firstID, secondID],
                          producedID: produced.id))
        nextTileID += 1
        self.firstID = nil
        self.op = nil

        if value == puzzle.target {
            flashTarget = true
            PZHaptics.success()
            // finish() owns the state transition. Setting `finished` first
            // used to make its guard return before presenting the result sheet.
            finish()
        } else {
            PZHaptics.tick()
        }
    }

    private func undoStep() {
        guard let last = steps.popLast() else { return }
        withAnimation(PZAnim.shuffle) {
            tiles.removeAll { $0.id == last.producedID }
            for i in tiles.indices where last.consumedIDs.contains(tiles[i].id) {
                tiles[i].consumed = false
            }
        }
        firstID = nil
        op = nil
        PZHaptics.tick()
    }

    private func resetAll() {
        withAnimation(PZAnim.shuffle) {
            tiles = puzzle.numbers.enumerated().map { Tile(id: $0.offset, value: $0.element) }
        }
        nextTileID = puzzle.numbers.count
        steps = []
        firstID = nil
        op = nil
        finished = false
        flashTarget = false
    }

    private func finish() {
        guard !finished else { return }
        finished = true
        let best = bestValue
        let distance = abs(best - puzzle.target)
        progress.markDone(puzzle.id)
        progress.setElapsed(puzzle.id, elapsed)
        progress.recordTime(TimeInterval(max(5, elapsed)), kind: .numbers, puzzleID: puzzle.id)
        progress.noteDayIfComplete()
        result = PZResult(kind: .numbers, didWin: distance == 0,
                          headline: distance == 0 ? "¡Exacto!" : "A \(distance) del objetivo",
                          detail: distance == 0
                            ? "Llegaste a \(puzzle.target) en \(steps.count) paso\(steps.count == 1 ? "" : "s")"
                            : "Una solución posible: \(puzzle.solution)",
                          metrics: [("Objetivo", "\(puzzle.target)"),
                                    ("Mejor", "\(best)"),
                                    ("Tiempo", PuzzleTiming.clock(TimeInterval(elapsed)))],
                          shareText: "NewsRaider Cifras · objetivo \(puzzle.target) · mejor \(best) · \(PuzzleTiming.clock(TimeInterval(elapsed)))")
    }
}


// MARK: - Hashtag

/// Four five-letter words arranged as a physical hashtag. Intersections are
/// represented by one shared cell.
struct HashtagPuzzle: Identifiable, Sendable, Hashable {
    struct Word: Identifiable, Sendable, Hashable {
        enum Direction: Sendable, Hashable { case horizontal, vertical }
        let id: Int
        let answer: String
        let row: Int
        let col: Int
        let direction: Direction

        var cells: [GridCell] {
            answer.indices.enumerated().map { offset, _ in
                direction == .horizontal
                    ? GridCell(row: row, col: col + offset)
                    : GridCell(row: row + offset, col: col)
            }
        }
    }

    let id: String
    let words: [Word]
    let cells: [GridCell]
    let letters: [Character]

    var solution: [GridCell: Character] {
        var result: [GridCell: Character] = [:]
        for word in words {
            for (index, cell) in word.cells.enumerated() {
                result[cell] = Array(word.answer)[index]
            }
        }
        return result
    }

    static func generate(seed: UInt64, language: PuzzleLanguage = .spanish) -> HashtagPuzzle {
        var rng = SeededGenerator(seed: seed)
        let templates = language == .english ? HashtagBank.englishTemplates : HashtagBank.templates
        let template = templates[rng.int(templates.count)]
        let words = [
            Word(id: 0, answer: template.horizontalTop, row: 1, col: 0, direction: .horizontal),
            Word(id: 1, answer: template.horizontalBottom, row: 3, col: 0, direction: .horizontal),
            Word(id: 2, answer: template.verticalLeft, row: 0, col: 1, direction: .vertical),
            Word(id: 3, answer: template.verticalRight, row: 0, col: 3, direction: .vertical)
        ]
        let cells = Array(Set(words.flatMap(\.cells))).sorted {
            $0.row == $1.row ? $0.col < $1.col : $0.row < $1.row
        }
        var solution: [GridCell: Character] = [:]
        for word in words {
            for (index, cell) in word.cells.enumerated() {
                solution[cell] = Array(word.answer)[index]
            }
        }
        let letters = rng.shuffled(cells.compactMap { solution[$0] })
        return .init(id: "\(language == .english ? "en-" : "")hash-\(seed)", words: words, cells: cells, letters: letters)
    }
}

private enum HashtagBank {
    struct Template {
        let horizontalTop: String
        let horizontalBottom: String
        let verticalLeft: String
        let verticalRight: String
    }

    static let englishTemplates: [Template] = [
        .init(horizontalTop: "BEACH", horizontalBottom: "BREAD", verticalLeft: "HEART", verticalRight: "OCEAN"),
        .init(horizontalTop: "BREAD", horizontalBottom: "APPLE", verticalLeft: "GRAPE", verticalRight: "TABLE"),
        .init(horizontalTop: "BREAD", horizontalBottom: "FIELD", verticalLeft: "TRAIN", verticalRight: "TABLE"),
        .init(horizontalTop: "BREAD", horizontalBottom: "RIVER", verticalLeft: "TRAIN", verticalRight: "WATER")
    ]
    static let templates: [Template] = [
        .init(horizontalTop: "CASAS", horizontalBottom: "PERRO",
              verticalLeft: "PARED", verticalRight: "MADRE"),
        .init(horizontalTop: "LUNES", horizontalBottom: "SALTO",
              verticalLeft: "JUGAR", verticalRight: "MENTA"),
        .init(horizontalTop: "GATOS", horizontalBottom: "NUBES",
              verticalLeft: "SALUD", verticalRight: "PODER"),
        .init(horizontalTop: "MESAS", horizontalBottom: "COLOR",
              verticalLeft: "MENOR", verticalRight: "CALOR")
    ]
}


// MARK: - Hashtag game

struct HashtagGame: View {
    let puzzle: HashtagPuzzle
    @ObservedObject private var progress = PuzzleProgress.shared
    @State private var letters: [Character]
    @State private var selected: Int?
    @State private var elapsed = 0
    @State private var finished = false
    @State private var result: PZResult?
    @State private var toast: PZToast?
    @State private var keyboardCursor: GridCell?
    @FocusState private var hardwareKeyboardFocused: Bool
    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    init(puzzle: HashtagPuzzle) {
        self.puzzle = puzzle
        _letters = State(initialValue: puzzle.letters)
    }

    private var solvedCount: Int {
        puzzle.words.filter { word in
            word.cells.enumerated().allSatisfy { index, cell in
                guard let boardIndex = puzzle.cells.firstIndex(of: cell) else { return false }
                return letters[boardIndex] == Array(word.answer)[index]
            }
        }.count
    }

    var body: some View {
        VStack(spacing: PZSpace.lg) {
            HStack {
                PZStat(label: AppLanguage.text("PALABRAS", "WORDS"), value: "\(solvedCount)/4")
                Spacer()
                PZStat(label: AppLanguage.text("TIEMPO", "TIME"), value: PuzzleTiming.clock(TimeInterval(elapsed)), alignment: .trailing)
            }

            Text(AppLanguage.text("Intercambia letras para reconstruir el #", "Swap letters to rebuild the #"))
                .font(PZFont.summary)
                .foregroundStyle(PZColor.inkSecondary)
                .multilineTextAlignment(.center)

            board

            HStack(spacing: PZSpace.md) {
                Label(AppLanguage.text("Exacta", "Exact"), systemImage: "square.fill").foregroundStyle(PZColor.success)
                Label(AppLanguage.text("En la palabra", "In the word"), systemImage: "square.fill").foregroundStyle(.yellow)
                Label(AppLanguage.text("No pertenece", "Not in the word"), systemImage: "square").foregroundStyle(PZColor.inkSecondary)
            }
            .font(PZFont.caption)
        }
        .padding(PZSpace.screenH)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(LiquidCanvasBackground())
        .navigationTitle("Hashtag")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            elapsed = progress.elapsed(puzzle.id)
            let saved = progress.fill(puzzle.id)
            if saved.count == puzzle.cells.count {
                letters = puzzle.cells.enumerated().compactMap { index, _ in
                    saved[String(index)]?.first
                }
            }
        }
        .onReceive(tick) { _ in
            guard !finished else { return }
            elapsed += 1
            if elapsed % 5 == 0 { progress.setElapsed(puzzle.id, elapsed) }
        }
        .sheet(item: $result) { PZResultSheet(result: $0) }
        .pzToast($toast)
        .pzRules(.hashtag)
        // Hardware keyboard: arrows walk the board, space/return picks up and
        // drops a letter, so the whole puzzle is playable from an iPad keyboard
        // without reaching for the screen.
        .focusable(interactions: .activate)
        .focused($hardwareKeyboardFocused)
        .focusEffectDisabled()
        .onKeyPress(phases: .down) { handleHardwareKey($0) }
        .onAppear { claimHardwareKeyboardFocus() }
        // Tapping a letter or a cell moves focus to that button; without this
        // the hardware keyboard stops responding after the first touch.
        .simultaneousGesture(TapGesture().onEnded { claimHardwareKeyboardFocus() })
    }

    /// Index of the board cell the keyboard cursor sits on.
    private func cellIndex(row: Int, col: Int) -> Int? {
        puzzle.cells.firstIndex(of: GridCell(row: row, col: col))
    }

    private func handleHardwareKey(_ press: KeyPress) -> KeyPress.Result {
        guard !finished else { return .ignored }
        let cursor = keyboardCursor ?? puzzle.cells.first.map { $0 } ?? GridCell(row: 0, col: 0)

        func step(_ dr: Int, _ dc: Int) -> KeyPress.Result {
            var r = cursor.row, c = cursor.col
            for _ in 0..<5 {
                r += dr; c += dc
                guard (0..<5).contains(r), (0..<5).contains(c) else { break }
                if cellIndex(row: r, col: c) != nil {
                    keyboardCursor = GridCell(row: r, col: c)
                    PZHaptics.tick()
                    return .handled
                }
            }
            return .handled
        }

        switch press.key {
        case .upArrow:    return step(-1, 0)
        case .downArrow:  return step(1, 0)
        case .leftArrow:  return step(0, -1)
        case .rightArrow: return step(0, 1)
        case .space, .return:
            guard let index = cellIndex(row: cursor.row, col: cursor.col) else { return .handled }
            if feedback(at: index) == .exact {
                toast = PZToast(text: AppLanguage.text("Esa letra ya está en su sitio", "That letter is already in place"), kind: .info)
                return .handled
            }
            if let source = selected {
                if source != index {
                    withAnimation(PZAnim.shuffle) { letters.swapAt(source, index) }
                    persist()
                    if solvedCount == puzzle.words.count { finish() }
                }
                selected = nil
            } else {
                selected = index
            }
            PZHaptics.tick()
            return .handled
        case .escape:
            selected = nil
            return .handled
        default:
            return .ignored
        }
    }

    /// Reclaim focus after SwiftUI has finished focusing a tapped board cell.
    private func claimHardwareKeyboardFocus() {
        Task { @MainActor in
            await Task.yield()
            hardwareKeyboardFocused = true
        }
    }

    private var board: some View {
        GeometryReader { geometry in
            let spacing: CGFloat = 5
            let side = min(geometry.size.width, 330)
            let tileSide = (side - spacing * 4) / 5
            VStack(spacing: spacing) {
                ForEach(0..<5, id: \.self) { row in
                    HStack(spacing: spacing) {
                        ForEach(0..<5, id: \.self) { col in
                            let cell = GridCell(row: row, col: col)
                            if let index = puzzle.cells.firstIndex(of: cell) {
                                cellButton(index: index, side: tileSide)
                            } else {
                                Color.clear.frame(width: tileSide, height: tileSide)
                            }
                        }
                    }
                }
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(height: 330)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(AppLanguage.text("Tablero con forma de almohadilla", "Hash-shaped board"))
    }

    private func cellButton(index: Int, side: CGFloat) -> some View {
        let state = feedback(at: index)
        let isSelected = selected == index
        // A letter already in its correct square is settled: swapping it away
        // would undo progress the player has earned. It stays visible and
        // legible, just no longer draggable.
        let isLocked = state == .exact
        return Button {
            guard !isLocked else {
                toast = PZToast(text: AppLanguage.text("Esa letra ya está en su sitio", "That letter is already in place"), kind: .info)
                return
            }
            if let source = selected {
                if source == index {
                    selected = nil
                } else {
                    withAnimation(PZAnim.shuffle) {
                        letters.swapAt(source, index)
                        selected = nil
                    }
                    persist()
                    PZHaptics.tick()
                    if solvedCount == puzzle.words.count { finish() }
                }
            } else {
                selected = index
                PZHaptics.tick()
            }
        } label: {
            Text(String(letters[index]))
                .font(.system(size: min(27, side * 0.45), weight: .heavy, design: .rounded))
                .foregroundStyle(state == .neutral ? PZColor.ink : .white)
                .frame(width: side, height: side)
                .background(feedbackColor(state), in: PZRadius.rect(PZRadius.tile))
                .overlay {
                    PZRadius.rect(PZRadius.tile)
                        .stroke(isSelected ? PZ.hashtag
                                : keyboardCursor == puzzle.cells[index] ? PZ.hashtag.opacity(0.55)
                                : PZColor.hairline,
                                lineWidth: isSelected ? 3
                                : keyboardCursor == puzzle.cells[index] ? 2 : 1)
                }
                .scaleEffect(isSelected ? 1.06 : 1)
        }
        .buttonStyle(.plain)
        .disabled(isLocked)
        .accessibilityLabel(AppLanguage.text("Letra \(String(letters[index]))", "Letter \(String(letters[index]))"))
        .accessibilityValue(isLocked ? AppLanguage.text("fijada, posición correcta", "locked, correct position")
                            : isSelected ? AppLanguage.text("seleccionada", "selected") : feedbackLabel(state))
        .accessibilityHint(isLocked ? AppLanguage.text("Ya no se puede mover", "This letter cannot be moved")
                           : isSelected ? AppLanguage.text("Toca otra casilla para intercambiar", "Tap another square to swap")
                           : AppLanguage.text("Toca para seleccionar", "Tap to select"))
    }

    private enum CellFeedback { case exact, present, neutral }

    private func feedback(at index: Int) -> CellFeedback {
        let cell = puzzle.cells[index]
        let letter = letters[index]
        guard puzzle.solution[cell] != letter else { return .exact }
        for word in puzzle.words where legitimateYellows(in: word).contains(cell) {
            return .present
        }
        return .neutral
    }

    /// Wordle-style duplicate accounting for one word: exact positions are
    /// consumed first, then misplaced letters consume the remaining counts
    /// from left to right.
    private func legitimateYellows(in word: HashtagPuzzle.Word) -> Set<GridCell> {
        let answer = Array(word.answer)
        let placed = word.cells.map { cell -> Character? in
            guard let index = puzzle.cells.firstIndex(of: cell) else { return nil }
            return letters[index]
        }
        var remaining: [Character: Int] = [:]

        for offset in answer.indices where placed[offset] != answer[offset] {
            remaining[answer[offset], default: 0] += 1
        }

        var yellow = Set<GridCell>()
        for offset in answer.indices {
            guard let letter = placed[offset], letter != answer[offset],
                  remaining[letter, default: 0] > 0 else { continue }
            yellow.insert(word.cells[offset])
            remaining[letter, default: 0] -= 1
        }
        return yellow
    }

    private func feedbackColor(_ state: CellFeedback) -> Color {
        switch state {
        case .exact: return PZColor.success
        case .present: return .yellow
        case .neutral: return PZColor.surface
        }
    }

    private func feedbackLabel(_ state: CellFeedback) -> String {
        switch state {
        case .exact: return AppLanguage.text("posición correcta", "correct position")
        case .present: return AppLanguage.text("pertenece a una palabra de esta casilla", "belongs to a word through this square")
        case .neutral: return AppLanguage.text("no pertenece a la palabra", "does not belong to the word")
        }
    }

    private func persist() {
        progress.setFill(puzzle.id, Dictionary(uniqueKeysWithValues:
            letters.enumerated().map { (String($0.offset), String($0.element)) }))
    }

    private func finish() {
        guard !finished else { return }
        finished = true
        progress.markDone(puzzle.id)
        progress.setElapsed(puzzle.id, elapsed)
        progress.recordTime(TimeInterval(max(5, elapsed)), kind: .hashtag, puzzleID: puzzle.id)
        progress.noteDayIfComplete()
        PZHaptics.success()
        result = PZResult(
            kind: .hashtag,
            didWin: true,
            headline: AppLanguage.text("¡Hashtag completo!", "Hashtag complete!"),
            detail: AppLanguage.text("Has reconstruido las cuatro palabras cruzadas", "You rebuilt all four crossing words"),
            metrics: [(AppLanguage.text("Palabras", "Words"), "4"),
                      (AppLanguage.text("Tiempo", "Time"), PuzzleTiming.clock(TimeInterval(elapsed)))],
            shareText: AppLanguage.text("NewsRaider Hashtag · 4 palabras · \(PuzzleTiming.clock(TimeInterval(elapsed)))", "NewsRaider Hashtag · 4 words · \(PuzzleTiming.clock(TimeInterval(elapsed)))"))
    }
}



// MARK: - Anygram crossed-word game

/// Rueda de letras. Vive aparte para que la posición del dedo (`dragLocation`, que cambia
/// en cada evento táctil) solo reconstruya la rueda y no todo el juego: antes cada
/// movimiento rehacía el tablero, la lista de palabras y el fondo, y el trazo iba con retraso.
#if DEBUG
private enum AnygramAutoWin { static var used = false }
#endif

private struct AnygramWheel: View {
    let letters: [Character]
    let side: CGFloat
    @Binding var selected: [Int]
    let onSubmit: () -> Void
    @State private var dragLocation: CGPoint?

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, side)
            let center = CGPoint(x: side / 2, y: side / 2)
            let radius = side * 0.34
            let positions = letters.indices.map { index in
                let angle = (Double(index) / Double(letters.count)) * Double.pi * 2 - Double.pi / 2
                return CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
            }

            ZStack {
                Circle()
                    .fill(PZColor.surface)
                    .overlay { Circle().stroke(PZ.anygram.opacity(0.2), lineWidth: 2) }

                Path { path in
                    guard let first = selected.first else { return }
                    path.move(to: positions[first])
                    for index in selected.dropFirst() { path.addLine(to: positions[index]) }
                    if let dragLocation { path.addLine(to: dragLocation) }
                }
                .stroke(PZ.anygram, style: StrokeStyle(lineWidth: 8, lineCap: .round, lineJoin: .round))
                .opacity(selected.isEmpty ? 0 : 0.65)

                ForEach(letters.indices, id: \.self) { index in
                    let isSelected = selected.contains(index)
                    Text(String(letters[index]))
                        .font(.system(size: 23, weight: .heavy, design: .rounded))
                        .foregroundStyle(isSelected ? .white : PZ.anygram)
                        .frame(width: 42, height: 42)
                        .background(isSelected ? PZ.anygram : PZ.anygram.opacity(0.14), in: Circle())
                        .overlay { Circle().stroke(PZ.anygram.opacity(0.35), lineWidth: 1.5) }
                        .position(positions[index])
                        .accessibilityLabel(AppLanguage.text("Letra \(String(letters[index]))", "Letter \(String(letters[index]))"))
                        .accessibilityValue(isSelected ? AppLanguage.text("seleccionada", "selected") : "")
                }
            }
            .frame(width: side, height: side)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        dragLocation = value.location
                        guard let index = positions.indices.min(by: {
                            hypot(positions[$0].x - value.location.x, positions[$0].y - value.location.y)
                                < hypot(positions[$1].x - value.location.x, positions[$1].y - value.location.y)
                        }), hypot(positions[index].x - value.location.x, positions[index].y - value.location.y) < 30,
                              !selected.contains(index) else { return }
                        selected.append(index)
                        PZHaptics.tick()
                    }
                    .onEnded { _ in
                        onSubmit()
                        dragLocation = nil
                    }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityElement(children: .contain)
            .accessibilityLabel(AppLanguage.text("Rueda de letras", "Letter wheel"))
        }
        .frame(height: side)
    }
}

struct AnygramGame: View {
    let puzzle: AnygramPuzzle
    /// Calculado una vez: `puzzle.boardCells` reconstruye el diccionario entero en cada acceso.
    private let boardCells: [GridCell: Character]
    init(puzzle: AnygramPuzzle) {
        self.puzzle = puzzle
        self.boardCells = puzzle.boardCells
    }
    @ObservedObject private var progress = PuzzleProgress.shared
    @State private var selected: [Int] = []
    @State private var found = Set<String>()
    @State private var extraWords = Set<String>()
    @State private var hintedCells = Set<GridCell>()
    @State private var elapsed = 0
    @State private var finished = false
    @State private var toast: PZToast?
    @State private var result: PZResult?
    @FocusState private var hardwareKeyboardFocused: Bool
    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var candidate: String { String(selected.map { puzzle.letters[$0] }) }

    var body: some View {
        GeometryReader { geo in
            let compact = geo.size.height < 760
            VStack(spacing: compact ? 5 : 8) {
                header
                crosswordBoard(maxHeight: compact ? 190 : 220)

                // Keep the board independently readable, then use the spare
                // vertical space to lower the input wheel and found-word strip.
                // This avoids the wheel visually colliding with taller 7–8 row
                // boards and removes the unused band at the bottom on iPhone.
                Spacer(minLength: compact ? 12 : 18)

                Text(candidate.isEmpty ? AppLanguage.text("Desliza para formar una palabra", "Swipe to form a word") : candidate)
                    .font(candidate.isEmpty ? PZFont.body : PZFont.title)
                    .foregroundStyle(candidate.isEmpty ? PZColor.inkTertiary : PZ.anygram)
                    .lineLimit(1)
                    .frame(height: compact ? 28 : 34)
                    .accessibilityLabel(candidate.isEmpty ? AppLanguage.text("Ninguna letra seleccionada", "No letters selected") : candidate)

                wheel(side: compact ? 176 : 196)
                foundWords
            }
            .padding(.horizontal, PZSpace.screenH)
            .padding(.top, 4)
            .padding(.bottom, 6)
            .frame(maxWidth: 560, maxHeight: .infinity, alignment: .top)
            .frame(maxWidth: .infinity)
        }
        .background(LiquidCanvasBackground())
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
        .navigationTitle("Anygram")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            elapsed = progress.elapsed(puzzle.id)
            let savedWords = progress.found(puzzle.id)
            found = Set(savedWords.filter { puzzle.answers.contains($0) })
            extraWords = Set(savedWords.compactMap { value in
                value.hasPrefix("extra:") ? String(value.dropFirst(6)) : nil
            })
            hintedCells = Set(progress.fill(puzzle.id).keys.compactMap { key in
                let parts = key.split(separator: ",").compactMap { Int($0) }
                guard parts.count == 2 else { return nil }
                return GridCell(row: parts[0], col: parts[1])
            })
            claimHardwareKeyboardFocus()
            #if DEBUG
            // Ayuda de verificación: NR_AUTOWIN=1 termina la partida al abrirla para llegar a la hoja de resultado.
            if ProcessInfo.processInfo.environment["NR_AUTOWIN"] == "1", !AnygramAutoWin.used {
                AnygramAutoWin.used = true
                Task { @MainActor in try? await Task.sleep(for: .seconds(1)); finish() }
            }
            #endif
        }
        .onReceive(tick) { _ in
            guard !finished else { return }
            elapsed += 1
            if elapsed % 5 == 0 { progress.setElapsed(puzzle.id, elapsed) }
        }
        .sheet(item: $result) { PZResultSheet(result: $0) }
        .pzToast($toast)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { hintsMenu }
        }
        .pzRules(.anygram)
    }

    private var header: some View {
        HStack {
            PZStat(label: AppLanguage.text("ENCONTRADAS", "FOUND"), value: "\(found.count)/\(puzzle.answers.count)")
            Spacer()
            PZStat(label: AppLanguage.text("TIEMPO", "TIME"), value: PuzzleTiming.clock(TimeInterval(elapsed)), alignment: .trailing)
        }
    }

    private func crosswordBoard(maxHeight: CGFloat) -> some View {
        GeometryReader { geo in
            let spacing: CGFloat = 3
            let available = min(geo.size.width, 300)
            let widthTile = min(44, (available - spacing * CGFloat(puzzle.boardCols - 1))
                                    / CGFloat(puzzle.boardCols))
            let tile = puzzle.id.hasPrefix("en-")
                ? min(widthTile, (maxHeight - spacing * CGFloat(puzzle.boardRows - 1)) / CGFloat(puzzle.boardRows))
                : widthTile
            let width = tile * CGFloat(puzzle.boardCols)
                + spacing * CGFloat(puzzle.boardCols - 1)
            let height = tile * CGFloat(puzzle.boardRows)
                + spacing * CGFloat(puzzle.boardRows - 1)
            let cells = boardCells
            let revealed = revealedCells

            VStack(spacing: spacing) {
                ForEach(0..<puzzle.boardRows, id: \.self) { row in
                    HStack(spacing: spacing) {
                        ForEach(0..<puzzle.boardCols, id: \.self) { col in
                            let cell = GridCell(row: row, col: col)
                            if let letter = cells[cell] {
                                Text(revealed.contains(cell) || isHint(cell) ? String(letter) : "")
                                    .font(.system(size: min(22, tile * 0.5),
                                                  weight: .bold,
                                                  design: .rounded))
                                    .foregroundStyle(PZColor.ink)
                                    .frame(width: tile, height: tile)
                                    .background(PZColor.surface,
                                                in: PZRadius.rect(PZRadius.tile))
                                    .overlay {
                                        PZRadius.rect(PZRadius.tile)
                                            .stroke(PZ.anygram.opacity(0.35), lineWidth: 1)
                                    }
                            } else {
                                Color.clear.frame(width: tile, height: tile)
                            }
                        }
                    }
                }
            }
            .frame(width: width, height: height)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(height: maxHeight)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(AppLanguage.text("Tablero de palabras cruzadas", "Crossed-word board"))
        .accessibilityValue(AppLanguage.text("\(found.count) de \(puzzle.answers.count) palabras reveladas", "\(found.count) of \(puzzle.answers.count) words revealed"))
    }

    private var revealedCells: Set<GridCell> {
        var set = Set<GridCell>()
        for entry in puzzle.entries where found.contains(entry.word) { set.formUnion(entry.cells) }
        return set
    }

    /// The board starts completely blank: only found words and paid hints show
    /// letters, so no answer is given away for free.
    private func isHint(_ cell: GridCell) -> Bool {
        hintedCells.contains(cell)
    }

    private var nextHiddenCell: GridCell? {
        let revealed = revealedCells
        return puzzle.entries
            .filter { !found.contains($0.word) }
            .flatMap(\.cells)
            .first { !isHint($0) && !revealed.contains($0) }
    }

    private var nextHiddenEntry: AnygramPuzzle.Entry? {
        puzzle.entries.first { !found.contains($0.word) }
    }

    private var hintsMenu: some View {
        Menu {
            Button {
                revealLetter()
            } label: {
                Label(AppLanguage.text("Revelar letra · +30 s", "Reveal a letter · +30 s"), systemImage: "character.cursor.ibeam")
            }
            .disabled(nextHiddenCell == nil)

            Button {
                revealWord()
            } label: {
                Label(AppLanguage.text("Revelar palabra · +90 s", "Reveal a word · +90 s"), systemImage: "text.badge.checkmark")
            }
            .disabled(nextHiddenEntry == nil)
        } label: {
            Image(systemName: "lightbulb")
                .foregroundStyle(PZ.anygram)
        }
        .accessibilityLabel(AppLanguage.text("Pistas", "Hints"))
        .accessibilityHint(AppLanguage.text("Las pistas añaden una penalización al tiempo", "Hints add a time penalty"))
    }

    private func wheel(side: CGFloat) -> some View {
        AnygramWheel(letters: puzzle.letters, side: side, selected: $selected, onSubmit: submit)
    }

    private var foundWords: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(AppLanguage.text("TABLERO  \(found.count)/\(puzzle.answers.count)", "BOARD  \(found.count)/\(puzzle.answers.count)")).pzLabelStyle()
                Spacer()
                Text(AppLanguage.text("OTRAS  \(extraWords.count)", "EXTRAS  \(extraWords.count)")).pzLabelStyle()
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(puzzle.answers.filter(found.contains), id: \.self) { word in
                        compactWordChip(word, tint: PZ.anygram)
                    }
                    if !found.isEmpty && !extraWords.isEmpty { Divider().frame(height: 24) }
                    ForEach(extraWords.sorted(), id: \.self) { word in
                        compactWordChip(word, tint: PZColor.inkSecondary)
                    }
                    if found.isEmpty && extraWords.isEmpty {
                        Text(AppLanguage.text("Las palabras encontradas aparecerán aquí", "Your found words will appear here"))
                            .font(PZFont.caption)
                            .foregroundStyle(PZColor.inkSecondary)
                    }
                }
            }
            .frame(height: 34)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(PZColor.surface, in: PZRadius.rect(PZRadius.card))
    }

    private func compactWordChip(_ word: String, tint: Color) -> some View {
        Group {
            if puzzle.id.hasPrefix("en-") {
                // System dictionaries follow installed OS dictionaries, not the in-app language.
                Text(word).font(PZFont.caption).foregroundStyle(tint)
            } else {
                PZDefinableWord(word: word, font: PZFont.caption, tint: tint)
            }
        }
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(PZColor.wash(tint), in: Capsule())
    }

    private func persistWords() {
        let targets = puzzle.answers.filter(found.contains)
        let extras = extraWords.sorted().map { "extra:" + $0 }
        progress.setFound(puzzle.id, targets + extras)
    }

    private func distance(_ lhs: CGPoint, _ rhs: CGPoint) -> CGFloat {
        hypot(lhs.x - rhs.x, lhs.y - rhs.y)
    }

    private func handleHardwareKey(_ press: KeyPress) -> KeyPress.Result {
        guard !finished else { return .ignored }
        if press.key == .delete {
            if !selected.isEmpty { selected.removeLast(); PZHaptics.tick() }
            return .handled
        }
        if press.key == .return {
            submit()
            return .handled
        }
        let text = press.characters.uppercased()
        guard text.count == 1, let letter = text.first,
              let index = puzzle.letters.indices.first(where: {
                  puzzle.letters[$0] == letter && !selected.contains($0)
              }) else { return .ignored }
        selected.append(index)
        PZHaptics.tick()
        return .handled
    }

    private func handleCapturedHardwareKey(_ key: PZHardwareKey) -> Bool {
        guard !finished else { return false }
        switch key.unmodifiedInput {
        case UIKeyCommand.inputDelete:
            if !selected.isEmpty { selected.removeLast(); PZHaptics.tick() }
            return true
        case "\r", "\n":
            submit()
            return true
        default:
            let text = key.unmodifiedInput.uppercased()
            guard text.count == 1, let letter = text.first,
                  let index = puzzle.letters.indices.first(where: {
                      puzzle.letters[$0] == letter && !selected.contains($0)
                  }) else { return false }
            selected.append(index)
            PZHaptics.tick()
            return true
        }
    }

    /// Wheel buttons can become the focused element. Move focus back to this
    /// input surface after their action so letter keys keep working on iPad.
    private func claimHardwareKeyboardFocus() {
        Task { @MainActor in
            await Task.yield()
            hardwareKeyboardFocused = true
        }
    }

    private func revealLetter() {
        guard let cell = nextHiddenCell else { return }
        withAnimation(PZAnim.reveal) { _ = hintedCells.insert(cell) }
        elapsed += 30
        progress.setElapsed(puzzle.id, elapsed)
        progress.setFill(puzzle.id, Dictionary(uniqueKeysWithValues: hintedCells.map {
            ("\($0.row),\($0.col)", String(boardCells[$0] ?? " "))
        }))
        toast = PZToast(text: AppLanguage.text("Letra revelada · +30 s", "Letter revealed · +30 s"), kind: .info)
        PZHaptics.warning()
    }

    private func revealWord() {
        guard let entry = nextHiddenEntry else { return }
        elapsed += 90
        withAnimation(PZAnim.reveal) { _ = found.insert(entry.word) }
        progress.setElapsed(puzzle.id, elapsed)
        persistWords()
        toast = PZToast(text: AppLanguage.text("\(entry.word) revelada · +90 s", "\(entry.word) revealed · +90 s"), kind: .info)
        PZHaptics.warning()
        if found.count == puzzle.answers.count { finish() }
    }

    private func submit() {
        defer {
            withAnimation(PZAnim.reveal) {
                selected.removeAll()
            }
        }
        guard selected.count >= 3 else {
            if !selected.isEmpty {
                toast = PZToast(text: AppLanguage.text("Las palabras deben tener al menos 3 letras", "Words must have at least 3 letters"), kind: .error)
                PZHaptics.error()
            }
            return
        }
        if puzzle.answers.contains(candidate) {
            guard !found.contains(candidate) else {
                toast = PZToast(text: AppLanguage.text("Ya habías encontrado \(candidate)", "You already found \(candidate)"), kind: .info)
                PZHaptics.warning()
                return
            }
            found.insert(candidate)
            persistWords()
            PZHaptics.success()
            if found.count == puzzle.answers.count { finish() }
            return
        }

        guard (puzzle.id.hasPrefix("en-") ? EnglishPuzzleLexicon.wordSet : PuzzleLexicon.wordSet).contains(candidate) else {
            toast = PZToast(text: AppLanguage.text("«\(candidate)» no está en el diccionario", "“\(candidate)” is not in this curated dictionary"), kind: .error)
            PZHaptics.error()
            return
        }
        guard !extraWords.contains(candidate) else {
            toast = PZToast(text: AppLanguage.text("Ya habías encontrado \(candidate)", "You already found \(candidate)"), kind: .info)
            PZHaptics.warning()
            return
        }
        extraWords.insert(candidate)
        persistWords()
        toast = PZToast(text: AppLanguage.text("Palabra extra: \(candidate)", "Extra word: \(candidate)"), kind: .success)
        PZHaptics.success()
    }

    private func finish() {
        guard !finished else { return }
        finished = true
        progress.markDone(puzzle.id)
        progress.setElapsed(puzzle.id, elapsed)
        progress.recordTime(TimeInterval(max(5, elapsed)), kind: .anygram, puzzleID: puzzle.id)
        progress.noteDayIfComplete()
        result = PZResult(
            kind: .anygram,
            didWin: true,
            headline: AppLanguage.text("¡Tablero completo!", "Board complete!"),
            detail: AppLanguage.text("Has revelado todas las palabras cruzadas", "You revealed all the crossing words"),
            metrics: [(AppLanguage.text("Palabras", "Words"), "\(found.count)"),
                      (AppLanguage.text("Tiempo", "Time"), PuzzleTiming.clock(TimeInterval(elapsed)))],
            shareText: AppLanguage.text("NewsRaider Anygram · \(found.count) palabras · \(PuzzleTiming.clock(TimeInterval(elapsed)))", "NewsRaider Anygram · \(found.count) words · \(PuzzleTiming.clock(TimeInterval(elapsed)))"))
    }
}
#endif

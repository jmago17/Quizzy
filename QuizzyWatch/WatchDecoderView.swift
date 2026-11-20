//
//  WatchDecoderView.swift — Quizzy Watch
//  Decoder en el reloj. El JUEGO viene de Kaffa (`DecoderCore.swift`, idéntico en los dos repos:
//  4 colores DISTINTOS de 6, 7 intentos, pista que revela la última fila). La vista es nueva
//  (2026-11-20): la de Kaffa imitaba un aparato físico (antenas, contador de 7 segmentos, pomo
//  naranja) y Josu pidió quitar ese disfraz. De allí se conserva lo que funciona en la muñeca:
//   - la Corona elige el color (con su clic háptico por paso);
//   - tocar la casilla seleccionada (o la muestra de color de abajo) lo coloca y avanza;
//   - tocar otra casilla de la fila actual la selecciona.
//  Sin ScrollView: reclamaría la Corona. Persistencia y resultados en `DecoderStore`, mismas claves
//  que el iPhone, sobre `PuzzleProgress.defaults` del reloj.
//

import SwiftUI

private extension DecoderColor {
    var color: Color { Color(hex: hex.dark) }
}

struct WatchDecoderView: View {
    let seedGame: DecoderGame
    let onAnother: () -> Void

    @ObservedObject private var progress = PuzzleProgress.shared
    @State private var game: DecoderGame
    @State private var draft = DecoderDraft()
    @State private var crown: Double = 0
    @State private var elapsed = 0
    @State private var notice: WNotice?
    @State private var loaded = false
    @FocusState private var crownFocus: Bool

    init(seedGame: DecoderGame, onAnother: @escaping () -> Void) {
        self.seedGame = seedGame
        self.onAnother = onAnother
        _game = State(initialValue: seedGame)
        _draft = State(initialValue: DecoderDraft(colorCount: seedGame.colorCount))
    }

    private var store: DecoderStore { DecoderStore(defaults: progress.defaults) }
    private var spanish: Bool { !game.id.hasPrefix("en-") }
    private var accent: Color { WTheme.color(.decoder) }
    private var palette: [DecoderColor] { DecoderColor.palette(count: game.colorCount) }
    private var crownIndex: Int {
        let n = game.colorCount
        return ((Int(crown.rounded()) % n) + n) % n
    }

    var body: some View {
        GeometryReader { geo in
            if game.isFinished {
                ScrollView { result }
            } else {
                VStack(spacing: 4) {
                    boardView(height: geo.size.height - 40)
                    controls
                }
            }
        }
        .navigationTitle("Decoder")
        .focusable(!game.isFinished)
        .focused($crownFocus)
        .digitalCrownRotation($crown, from: 0, through: Double(game.colorCount - 1), by: 1,
                              sensitivity: .low, isContinuous: true, isHapticFeedbackEnabled: true)
        .wClock(game.id, running: !game.isFinished, elapsed: $elapsed)
        .onAppear(perform: load)
        .task(id: notice) {
            guard notice != nil else { return }
            try? await Task.sleep(for: .seconds(2))
            notice = nil
        }
    }

    // MARK: Board

    private func boardView(height: CGFloat) -> some View {
        let rows = DecoderRules.maxAttempts
        let rowH = max(12, (height - CGFloat(rows - 1) * 3) / CGFloat(rows))
        return VStack(spacing: 3) {
            ForEach(0..<rows, id: \.self) { row in
                rowView(row, size: rowH)
            }
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder private func rowView(_ row: Int, size: CGFloat) -> some View {
        let current = row == game.guesses.count
        let usable = row < game.maxAttempts
        HStack(spacing: 4) {
            ForEach(0..<DecoderRules.slots, id: \.self) { slot in
                peg(row: row, slot: slot, size: size, current: current)
            }
            feedback(row: row, size: size)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 1)
        .background {
            if current {
                Capsule().fill(accent.opacity(0.16)).overlay(Capsule().stroke(accent.opacity(0.5), lineWidth: 1))
            }
        }
        .opacity(usable ? 1 : 0.25)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(rowLabel(row))
    }

    @ViewBuilder private func peg(row: Int, slot: Int, size: CGFloat, current: Bool) -> some View {
        let d = size * 0.86
        if row < game.guesses.count {
            let color = DecoderColor(rawValue: game.guesses[row][slot])?.color ?? WTheme.fill
            let hint = game.visibleSlotHints(row: row)?[slot]
            ZStack {
                Circle().fill(color).shadow(color: .black.opacity(0.35), radius: 1, y: 1)
                Circle().fill(LinearGradient(colors: [.white.opacity(0.35), .clear], startPoint: .top, endPoint: .center))
                if let hint {
                    Circle().stroke(hint == .exact ? WTheme.success : (hint == .present ? .white : .clear), lineWidth: 2)
                        .padding(-2)
                }
            }
            .frame(width: d, height: d)
        } else if current {
            let placed = draft.slots[slot].flatMap(DecoderColor.init(rawValue:))
            let isSelected = draft.selected == slot
            let preview = palette[crownIndex]
            ZStack {
                if let placed {
                    Circle().fill(placed.color)
                    Circle().fill(LinearGradient(colors: [.white.opacity(0.35), .clear], startPoint: .top, endPoint: .center))
                } else {
                    Circle().fill(WTheme.fill)
                }
                if isSelected {
                    // Vista previa de la Corona: discontinua; tachada si ese color ya está en otra casilla.
                    Circle().strokeBorder(preview.color, style: StrokeStyle(lineWidth: 2.5, dash: [3, 2]))
                    if !draft.canPlace(preview.rawValue) {
                        Rectangle().fill(WTheme.ink.opacity(0.8)).frame(width: d * 0.9, height: 1.5).rotationEffect(.degrees(-45))
                    }
                }
            }
            .frame(width: d, height: d)
            .contentShape(Circle())
            .onTapGesture {
                if isSelected { place() } else { draft.select(slot); WHaptics.tick() }
            }
        } else {
            Circle().fill(WTheme.fill.opacity(0.6)).frame(width: d * 0.5, height: d * 0.5).frame(width: d, height: d)
        }
    }

    /// Resultado agregado: puntos verdes = color en su sitio; blancos = color en otro sitio.
    @ViewBuilder private func feedback(row: Int, size: CGFloat) -> some View {
        let dot = max(4, size * 0.28)
        let fb = row < game.feedbacks.count ? game.feedbacks[row] : nil
        let marks: [Color] = (0..<DecoderRules.slots).map { i in
            guard let fb else { return WTheme.fill.opacity(0.5) }
            if i < fb.exact { return WTheme.success }
            if i < fb.exact + fb.misplaced { return .white }
            return WTheme.fill
        }
        Grid(horizontalSpacing: 2, verticalSpacing: 2) {
            GridRow { Circle().fill(marks[0]).frame(width: dot, height: dot); Circle().fill(marks[1]).frame(width: dot, height: dot) }
            GridRow { Circle().fill(marks[2]).frame(width: dot, height: dot); Circle().fill(marks[3]).frame(width: dot, height: dot) }
        }
        .frame(width: size, height: size)
    }

    // MARK: Controls

    private var controls: some View {
        HStack(spacing: 6) {
            Button { revealHint() } label: { Image(systemName: "lightbulb") }
                .buttonStyle(.plain)
                .foregroundStyle(game.canRevealHint ? accent : WTheme.inkTertiary)
                .disabled(!game.canRevealHint)
                .accessibilityLabel(spanish ? "Pista" : "Hint")
                .frame(width: 26)

            // Muestra del color de la Corona: tocar = colocar.
            Button { place() } label: {
                HStack(spacing: 4) {
                    Circle().fill(palette[crownIndex].color).frame(width: 16, height: 16)
                    Text(notice?.text ?? palette[crownIndex].name(spanish: spanish))
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(notice?.color ?? WTheme.ink)
                        .lineLimit(1).minimumScaleFactor(0.6)
                }
                .frame(maxWidth: .infinity, minHeight: 32)
                .background(WTheme.surface, in: Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(spanish ? "Colocar \(palette[crownIndex].name(spanish: true))" : "Place \(palette[crownIndex].name(spanish: false))")
            .accessibilityHint(spanish ? "Gira la Corona para cambiar de color" : "Turn the Digital Crown to change colour")

            Button { submit() } label: { Image(systemName: "checkmark") }
                .buttonStyle(.plain)
                .frame(width: 32, height: 32)
                .background(draft.isComplete ? accent : WTheme.fill, in: Circle())
                .foregroundStyle(draft.isComplete ? Color(hex: 0x10141D) : WTheme.inkTertiary)
                .disabled(!draft.isComplete)
                .accessibilityLabel(spanish ? "Probar" : "Submit")
        }
        .frame(height: 34)
    }

    private var result: some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                ForEach(game.secret, id: \.self) { c in
                    Circle().fill(DecoderColor(rawValue: c)?.color ?? .gray).frame(width: 20, height: 20)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(game.secret.compactMap { DecoderColor(rawValue: $0)?.name(spanish: spanish) }.joined(separator: ", "))
            WResultPanel(kind: .decoder, won: game.status == .won,
                         headline: game.status == .won
                            ? (spanish ? "¡Código descifrado!" : "Code cracked!")
                            : (spanish ? "Sin intentos" : "Out of attempts"),
                         detail: "\(game.attemptsUsed)/\(game.maxAttempts) · \(wTime(elapsed))",
                         onAnother: onAnother)
        }
    }

    // MARK: Actions

    private func load() {
        guard !loaded else { return }
        loaded = true
        game = store.load(id: seedGame.id, secret: seedGame.secret)
        draft = DecoderDraft(colorCount: game.colorCount)
        elapsed = progress.elapsed(game.id)
        crownFocus = true
    }

    private func place() {
        guard !game.isFinished else { return }
        switch draft.place(palette[crownIndex].rawValue) {
        case .placed:
            WHaptics.tick()
            // La Corona salta al siguiente color libre: menos giro para la casilla siguiente.
            if let free = palette.indices.first(where: { draft.canPlace(palette[$0].rawValue) && $0 > crownIndex })
                ?? palette.indices.first(where: { draft.canPlace(palette[$0].rawValue) }) {
                crown = Double(free)
            }
        case .unchanged:
            break
        case .duplicate(_, let heldBy):
            notice = WNotice(text: spanish ? "Ya está en la \(heldBy + 1)" : "Already in slot \(heldBy + 1)", kind: .error)
            WHaptics.error()
        case .invalid:
            WHaptics.error()
        }
    }

    private func submit() {
        guard let code = draft.code else { return }
        var next = game
        switch next.submit(code) {
        case .accepted(let fb):
            withAnimation(.snappy) { game = next }
            draft = DecoderDraft(colorCount: game.colorCount)
            store.save(game)
            if game.isFinished {
                store.recordResultIfNew(game)
                progress.setElapsed(game.id, elapsed)
                progress.recordTime(TimeInterval(max(5, elapsed)), kind: .decoder, puzzleID: game.id)
                progress.markDone(game.id)
                progress.noteDayIfComplete()
                game.status == .won ? WHaptics.success() : WHaptics.error()
            } else {
                notice = WNotice(text: spanish ? "\(fb.exact) en su sitio · \(fb.misplaced) fuera" : "\(fb.exact) right · \(fb.misplaced) moved",
                                 kind: .info)
                WHaptics.tick()
            }
        case .invalid:
            notice = WNotice(text: spanish ? "Sin repetir colores" : "No repeated colours", kind: .error)
            WHaptics.error()
        case .finished:
            break
        }
    }

    private func revealHint() {
        var next = game
        if case .revealed = next.revealHint() {
            game = next
            store.save(game)
            WHaptics.tick()
        }
    }

    private func rowLabel(_ row: Int) -> String {
        if row < game.guesses.count {
            let names = game.guesses[row].compactMap { DecoderColor(rawValue: $0)?.name(spanish: spanish) }.joined(separator: ", ")
            let fb = game.feedbacks[row]
            return spanish ? "Intento \(row + 1): \(names). \(fb.exact) en su sitio, \(fb.misplaced) en otro sitio"
                           : "Attempt \(row + 1): \(names). \(fb.exact) right, \(fb.misplaced) misplaced"
        }
        if row == game.guesses.count {
            let names = draft.slots.map { $0.flatMap(DecoderColor.init(rawValue:))?.name(spanish: spanish) ?? (spanish ? "vacía" : "empty") }
            return (spanish ? "Fila actual: " : "Current row: ") + names.joined(separator: ", ")
        }
        return spanish ? "Intento \(row + 1), pendiente" : "Attempt \(row + 1), pending"
    }
}

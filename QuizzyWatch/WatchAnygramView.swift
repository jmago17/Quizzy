//
//  WatchAnygramView.swift — Quizzy Watch
//  Anygram en la muñeca: rueda para deslizar abajo, tablero compacto arriba (tocarlo lo abre a
//  pantalla completa con la lista de palabras). Mismas reglas y claves de progreso que el iPhone:
//  `found` (respuestas + "extra:…"), `fill` (casillas reveladas) y la letra gratis cada
//  `AnygramRules.extrasPerFreeLetter` palabras extra.
//

import SwiftUI

enum AnygramRules {
    /// Igual que `AnygramGame.extrasPerFreeLetter` en el iPhone (no se comparte el valor porque
    /// aquel fichero es de vista iOS).
    static let extrasPerFreeLetter = 3
}

struct WatchAnygramView: View {
    let puzzle: AnygramPuzzle
    let onAnother: () -> Void
    private let boardCells: [GridCell: Character]

    init(puzzle: AnygramPuzzle, onAnother: @escaping () -> Void) {
        self.puzzle = puzzle
        self.onAnother = onAnother
        self.boardCells = puzzle.boardCells
    }

    @ObservedObject private var progress = PuzzleProgress.shared
    @State private var selected: [Int] = []
    @State private var found = Set<String>()
    @State private var extras = Set<String>()
    @State private var hinted = Set<GridCell>()
    @State private var elapsed = 0
    @State private var finished = false
    @State private var notice: WNotice?
    @State private var showBoard = false
    @State private var loaded = false

    private var english: Bool { puzzle.id.hasPrefix("en-") }
    private var candidate: String { String(selected.map { puzzle.letters[$0] }) }
    private var color: Color { WTheme.color(.anygram) }

    var body: some View {
        GeometryReader { geo in
            if finished {
                ScrollView {
                    WResultPanel(kind: .anygram, won: true,
                                 headline: AppLanguage.text("¡Tablero completo!", "Board complete!"),
                                 detail: "\(found.count) · \(wTime(elapsed))", onAnother: onAnother)
                    board(height: geo.size.height * 0.6)
                }
            } else {
                VStack(spacing: 2) {
                    board(height: geo.size.height * 0.30)
                        .onTapGesture { showBoard = true }
                        .accessibilityAddTraits(.isButton)
                        .accessibilityHint(AppLanguage.text("Abre el tablero grande", "Opens the large board"))
                    HStack {
                        Text("\(found.count)/\(puzzle.answers.count)").foregroundStyle(color)
                        Spacer()
                        if let notice { Text(notice.text).foregroundStyle(notice.color).lineLimit(1).minimumScaleFactor(0.6) }
                        else { Text(candidate.isEmpty ? " " : candidate).foregroundStyle(WTheme.ink) }
                        Spacer()
                        Text("+\(extras.count % AnygramRules.extrasPerFreeLetter)/\(AnygramRules.extrasPerFreeLetter)")
                            .foregroundStyle(WTheme.inkSecondary)
                            .accessibilityLabel(AppLanguage.text("Palabras extra hacia la próxima letra gratis", "Extra words towards the next free letter"))
                    }
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .padding(.horizontal, 10)
                    WatchAnygramWheel(letters: puzzle.letters, color: color, selected: $selected, onSubmit: submit)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.bottom, 4)
                }
                .ignoresSafeArea(edges: .bottom)
            }
        }
        .navigationTitle("Anygram")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { revealLetter() } label: { Image(systemName: "lightbulb") }
                    .disabled(finished || nextHiddenCell == nil)
                    .accessibilityLabel(AppLanguage.text("Revelar letra, 30 segundos", "Reveal a letter, 30 seconds"))
            }
        }
        .sheet(isPresented: $showBoard) { bigBoard }
        .wClock(puzzle.id, running: !finished, elapsed: $elapsed)
        .task(id: notice) {
            guard notice != nil else { return }
            try? await Task.sleep(for: .seconds(2))
            notice = nil
        }
        .onAppear(perform: load)
    }

    // MARK: Board

    private var shown: Set<GridCell> {
        var set = hinted
        for entry in puzzle.entries where found.contains(entry.word) { set.formUnion(entry.cells) }
        return set
    }

    private func board(height: CGFloat) -> some View {
        WatchAnygramBoard(rows: puzzle.boardRows, cols: puzzle.boardCols, cells: boardCells,
                          shown: shown, color: color)
            .frame(height: height)
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(AppLanguage.text("Tablero", "Board"))
            .accessibilityValue(AppLanguage.text("\(found.count) de \(puzzle.answers.count) palabras", "\(found.count) of \(puzzle.answers.count) words"))
    }

    private var bigBoard: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                board(height: 150)
                Text(AppLanguage.text("TABLERO", "BOARD")).font(.caption2.bold()).foregroundStyle(WTheme.inkSecondary)
                Text(puzzle.answers.filter(found.contains).joined(separator: " · ")).font(.footnote).foregroundStyle(color)
                if !extras.isEmpty {
                    Text(AppLanguage.text("OTRAS", "EXTRAS")).font(.caption2.bold()).foregroundStyle(WTheme.inkSecondary)
                    Text(extras.sorted().joined(separator: " · ")).font(.footnote)
                }
            }
        }
    }

    private var nextHiddenCell: GridCell? {
        let visible = shown
        return puzzle.entries.filter { !found.contains($0.word) }.flatMap(\.cells).first { !visible.contains($0) }
    }

    // MARK: Logic (calcada de AnygramGame)

    private func load() {
        guard !loaded else { return }
        loaded = true
        elapsed = progress.elapsed(puzzle.id)
        let saved = progress.found(puzzle.id)
        found = Set(saved.filter { puzzle.answers.contains($0) })
        extras = Set(saved.compactMap { $0.hasPrefix("extra:") ? String($0.dropFirst(6)) : nil })
        hinted = Set(progress.fill(puzzle.id).keys.compactMap { key in
            let p = key.split(separator: ",").compactMap { Int($0) }
            return p.count == 2 ? GridCell(row: p[0], col: p[1]) : nil
        })
        finished = progress.isDone(puzzle.id)
    }

    private func persistWords() {
        progress.setFound(puzzle.id, puzzle.answers.filter(found.contains) + extras.sorted().map { "extra:" + $0 })
    }

    @discardableResult
    private func revealNextCell() -> Bool {
        guard let cell = nextHiddenCell else { return false }
        withAnimation(.snappy) { _ = hinted.insert(cell) }
        progress.setFill(puzzle.id, Dictionary(uniqueKeysWithValues: hinted.map {
            ("\($0.row),\($0.col)", String(boardCells[$0] ?? " "))
        }))
        return true
    }

    private func revealLetter() {
        guard revealNextCell() else { return }
        elapsed += 30
        progress.setElapsed(puzzle.id, elapsed)
        notice = WNotice(text: AppLanguage.text("Letra · +30 s", "Letter · +30 s"), kind: .info)
        WHaptics.warning()
    }

    private func submit() {
        let word = candidate
        defer { selected.removeAll() }
        guard word.count >= 3 else {
            if !word.isEmpty { notice = WNotice(text: AppLanguage.text("Mínimo 3 letras", "3 letters minimum"), kind: .error); WHaptics.error() }
            return
        }
        if puzzle.answers.contains(word) {
            guard !found.contains(word) else {
                notice = WNotice(text: AppLanguage.text("Ya la tienes", "Already found"), kind: .info); WHaptics.warning(); return
            }
            withAnimation(.snappy) { _ = found.insert(word) }
            persistWords()
            WHaptics.success()
            if found.count == puzzle.answers.count { finish() }
            return
        }
        guard (english ? EnglishPuzzleLexicon.wordSet : PuzzleLexicon.wordSet).contains(word) else {
            notice = WNotice(text: AppLanguage.text("No vale", "Not a word"), kind: .error); WHaptics.error(); return
        }
        guard !extras.contains(word) else {
            notice = WNotice(text: AppLanguage.text("Ya la tienes", "Already found"), kind: .info); WHaptics.warning(); return
        }
        extras.insert(word)
        persistWords()
        if extras.count % AnygramRules.extrasPerFreeLetter == 0, revealNextCell() {
            notice = WNotice(text: AppLanguage.text("¡Letra gratis!", "Free letter!"), kind: .success)
        } else {
            notice = WNotice(text: AppLanguage.text("Extra: \(word)", "Extra: \(word)"), kind: .success)
        }
        WHaptics.success()
    }

    private func finish() {
        guard !finished else { return }
        progress.markDone(puzzle.id)
        progress.setElapsed(puzzle.id, elapsed)
        progress.recordTime(TimeInterval(max(5, elapsed)), kind: .anygram, puzzleID: puzzle.id)
        progress.noteDayIfComplete()
        withAnimation { finished = true }
    }
}

/// Tablero dibujado con Canvas (una sola vista: con 60–90 casillas, una vista por casilla pesa en el reloj).
struct WatchAnygramBoard: View, Equatable {
    let rows: Int, cols: Int
    let cells: [GridCell: Character]
    let shown: Set<GridCell>
    let color: Color

    static func == (a: Self, b: Self) -> Bool { a.shown == b.shown && a.rows == b.rows && a.cols == b.cols }

    var body: some View {
        Canvas { ctx, size in
            let tile = min(size.width / CGFloat(cols), size.height / CGFloat(rows))
            let origin = CGPoint(x: (size.width - tile * CGFloat(cols)) / 2, y: (size.height - tile * CGFloat(rows)) / 2)
            for (cell, letter) in cells {
                let rect = CGRect(x: origin.x + CGFloat(cell.col) * tile, y: origin.y + CGFloat(cell.row) * tile,
                                  width: tile, height: tile).insetBy(dx: tile * 0.06, dy: tile * 0.06)
                let path = Path(roundedRect: rect, cornerRadius: tile * 0.18)
                let isShown = shown.contains(cell)
                ctx.fill(path, with: .color(isShown ? color.opacity(0.9) : WTheme.fill))
                ctx.stroke(path, with: .color(Color.white.opacity(isShown ? 0.25 : 0.08)), lineWidth: 0.5)
                if isShown, tile >= 7 {
                    let text = Text(String(letter)).font(.system(size: tile * 0.62, weight: .heavy, design: .rounded))
                        .foregroundColor(Color(hex: 0x10141D))
                    ctx.draw(text, at: CGPoint(x: rect.midX, y: rect.midY))
                }
            }
        }
    }
}

/// Rueda de letras: deslizar de una a otra, soltar = enviar. Volver a la penúltima deshace la última.
struct WatchAnygramWheel: View {
    let letters: [Character]
    let color: Color
    @Binding var selected: [Int]
    let onSubmit: () -> Void
    @State private var finger: CGPoint?

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let radius = side * 0.33
            let letterSize = min(side * 0.30, 2 * .pi * radius / CGFloat(max(letters.count, 1)) * 0.82)
            let points = letters.indices.map { i -> CGPoint in
                let a = -Double.pi / 2 + 2 * Double.pi * Double(i) / Double(letters.count)
                return CGPoint(x: center.x + radius * cos(a), y: center.y + radius * sin(a))
            }
            ZStack {
                Circle().fill(RadialGradient(colors: [WTheme.surface, WTheme.canvas], center: .center,
                                             startRadius: 0, endRadius: side / 2))
                // Trazo
                Path { p in
                    guard let first = selected.first else { return }
                    p.move(to: points[first])
                    for i in selected.dropFirst() { p.addLine(to: points[i]) }
                    if let finger { p.addLine(to: finger) }
                }
                .stroke(color.opacity(0.7), style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                ForEach(letters.indices, id: \.self) { i in
                    let on = selected.contains(i)
                    Text(String(letters[i]))
                        .font(.system(size: letterSize * 0.55, weight: .heavy, design: .rounded))
                        .foregroundStyle(on ? Color(hex: 0x10141D) : WTheme.ink)
                        .frame(width: letterSize, height: letterSize)
                        .background(Circle().fill(on ? color : WTheme.fill).shadow(color: .black.opacity(0.4), radius: 1, y: 1))
                        .position(points[i])
                }
            }
            .contentShape(Circle())
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { value in
                    finger = value.location
                    guard let hit = points.indices.first(where: { hypot(points[$0].x - value.location.x, points[$0].y - value.location.y) < letterSize * 0.55 }) else { return }
                    if selected.count >= 2, hit == selected[selected.count - 2] {
                        selected.removeLast(); WHaptics.tick()
                    } else if !selected.contains(hit) {
                        selected.append(hit); WHaptics.tick()
                    }
                }
                .onEnded { _ in
                    finger = nil
                    onSubmit()
                })
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(AppLanguage.text("Rueda de letras", "Letter wheel"))
            .accessibilityValue(String(letters))
        }
    }
}

//
//  WatchMazeView.swift — Quizzy Watch
//  Laberinto 8×10. Se juega deslizando: la bola corre en esa dirección hasta el siguiente cruce
//  (en la muñeca, casilla a casilla es agotador). Meta: la casilla de salida de la última fila.
//

import SwiftUI

struct WatchMazeView: View {
    let puzzle: MazePuzzle
    let onAnother: () -> Void

    @ObservedObject private var progress = PuzzleProgress.shared
    @State private var position = GridCell(row: 0, col: 0)
    @State private var trail: [GridCell] = []
    @State private var elapsed = 0
    @State private var finished = false
    @State private var loaded = false

    private var color: Color { WTheme.color(.maze) }

    var body: some View {
        Group {
            if finished {
                ScrollView {
                    WResultPanel(kind: .maze, won: true, headline: AppLanguage.text("¡Fuera!", "Out!"),
                                 detail: wTime(elapsed), onAnother: onAnother)
                }
            } else {
                board
                    .contentShape(Rectangle())
                    .gesture(DragGesture(minimumDistance: 12).onEnded { v in
                        let dx = v.translation.width, dy = v.translation.height
                        if abs(dx) > abs(dy) { slide(dr: 0, dc: dx > 0 ? 1 : -1) } else { slide(dr: dy > 0 ? 1 : -1, dc: 0) }
                    })
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(AppLanguage.text("Laberinto", "Maze"))
                    .accessibilityValue(AppLanguage.text("Fila \(position.row + 1), columna \(position.col + 1). Salida abajo, columna \(puzzle.exitCol + 1)",
                                                         "Row \(position.row + 1), column \(position.col + 1). Exit at the bottom, column \(puzzle.exitCol + 1)"))
                    .accessibilityAction(named: AppLanguage.text("Arriba", "Up")) { slide(dr: -1, dc: 0) }
                    .accessibilityAction(named: AppLanguage.text("Abajo", "Down")) { slide(dr: 1, dc: 0) }
                    .accessibilityAction(named: AppLanguage.text("Izquierda", "Left")) { slide(dr: 0, dc: -1) }
                    .accessibilityAction(named: AppLanguage.text("Derecha", "Right")) { slide(dr: 0, dc: 1) }
            }
        }
        .navigationTitle(wTime(elapsed))
        .wClock(puzzle.id, running: !finished, elapsed: $elapsed)
        .onAppear {
            guard !loaded else { return }
            loaded = true
            position = GridCell(row: 0, col: puzzle.entranceCol)
            trail = [position]
            elapsed = progress.elapsed(puzzle.id)
            finished = progress.isDone(puzzle.id)
        }
    }

    private var board: some View {
        Canvas { ctx, size in
            let cell = min(size.width / CGFloat(puzzle.cols), size.height / CGFloat(puzzle.rows))
            let ox = (size.width - cell * CGFloat(puzzle.cols)) / 2
            let oy = (size.height - cell * CGFloat(puzzle.rows)) / 2
            func center(_ c: GridCell) -> CGPoint { CGPoint(x: ox + (CGFloat(c.col) + 0.5) * cell, y: oy + (CGFloat(c.row) + 0.5) * cell) }

            ctx.fill(Path(roundedRect: CGRect(x: ox - 2, y: oy - 2, width: cell * CGFloat(puzzle.cols) + 4,
                                              height: cell * CGFloat(puzzle.rows) + 4), cornerRadius: 4),
                     with: .color(WTheme.surface))
            // Recorrido
            var path = Path()
            if let first = trail.first {
                path.move(to: center(first))
                for c in trail.dropFirst() { path.addLine(to: center(c)) }
            }
            ctx.stroke(path, with: .color(color.opacity(0.45)), style: StrokeStyle(lineWidth: cell * 0.3, lineCap: .round, lineJoin: .round))
            // Meta
            let exit = GridCell(row: puzzle.rows - 1, col: puzzle.exitCol)
            ctx.fill(Path(ellipseIn: CGRect(origin: center(exit), size: .zero).insetBy(dx: -cell * 0.32, dy: -cell * 0.32)),
                     with: .color(WTheme.success.opacity(0.8)))
            // Muros
            var walls = Path()
            for r in 0..<puzzle.rows {
                for c in 0..<puzzle.cols {
                    let w = puzzle.walls[r][c]
                    let x = ox + CGFloat(c) * cell, y = oy + CGFloat(r) * cell
                    if w & MazePuzzle.north != 0 { walls.move(to: CGPoint(x: x, y: y)); walls.addLine(to: CGPoint(x: x + cell, y: y)) }
                    if w & MazePuzzle.west != 0 { walls.move(to: CGPoint(x: x, y: y)); walls.addLine(to: CGPoint(x: x, y: y + cell)) }
                    if r == puzzle.rows - 1, w & MazePuzzle.south != 0 { walls.move(to: CGPoint(x: x, y: y + cell)); walls.addLine(to: CGPoint(x: x + cell, y: y + cell)) }
                    if c == puzzle.cols - 1, w & MazePuzzle.east != 0 { walls.move(to: CGPoint(x: x + cell, y: y)); walls.addLine(to: CGPoint(x: x + cell, y: y + cell)) }
                }
            }
            ctx.stroke(walls, with: .color(WTheme.ink.opacity(0.85)), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
            // Bola
            ctx.fill(Path(ellipseIn: CGRect(origin: center(position), size: .zero).insetBy(dx: -cell * 0.3, dy: -cell * 0.3)),
                     with: .color(color))
        }
    }

    /// Avanza en la dirección hasta chocar o llegar a un cruce/curva (casilla con ≠ 2 salidas o giro).
    private func slide(dr: Int, dc: Int) {
        guard !finished else { return }
        var moved = false
        while true {
            let next = GridCell(row: position.row + dr, col: position.col + dc)
            guard puzzle.canMove(from: position, to: next) else { break }
            position = next
            moved = true
            if let i = trail.lastIndex(of: next) { trail.removeSubrange((i + 1)...) } else { trail.append(next) }
            if next.row == puzzle.rows - 1 && next.col == puzzle.exitCol { complete(); return }
            if exits(next) != 2 { break }
            // Pasillo recto: sigue; si el pasillo gira, para (el jugador decide).
            if !puzzle.canMove(from: next, to: GridCell(row: next.row + dr, col: next.col + dc)) { break }
        }
        moved ? WHaptics.tick() : WHaptics.error()
    }

    private func exits(_ c: GridCell) -> Int {
        [(-1, 0), (1, 0), (0, -1), (0, 1)].filter { puzzle.canMove(from: c, to: GridCell(row: c.row + $0.0, col: c.col + $0.1)) }.count
    }

    private func complete() {
        progress.markDone(puzzle.id)
        progress.setElapsed(puzzle.id, elapsed)
        progress.recordTime(TimeInterval(max(5, elapsed)), kind: .maze, puzzleID: puzzle.id)
        progress.noteDayIfComplete()
        WHaptics.success()
        withAnimation { finished = true }
    }
}

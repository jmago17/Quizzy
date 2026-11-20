//
//  WatchTrocitosView.swift — Quizzy Watch
//  Trocitos: 20 fragmentos en 5 filas de 4. Tocar fragmentos en orden; con 4 se envía solo,
//  con menos se pulsa «OK». Reglas de `QuartilePuzzle` (puntos, joyas, meta = `goalScore`):
//  victoria = las 5 joyas Y la meta, igual que en el iPhone desde 2026-11-18.
//

import SwiftUI

struct WatchTrocitosView: View {
    let puzzle: QuartilePuzzle
    let onAnother: () -> Void

    @ObservedObject private var progress = PuzzleProgress.shared
    @State private var found: [String] = []
    @State private var selection: [Int] = []
    @State private var elapsed = 0
    @State private var finished = false
    @State private var notice: WNotice?
    @State private var loaded = false

    private var color: Color { WTheme.color(.quartiles) }
    private var score: Int { found.reduce(0) { $0 + puzzle.points(for: $1) } }
    private var gems: Int { found.filter(puzzle.isQuartile).count }
    private var isComplete: Bool { gems == puzzle.targets.count && score >= puzzle.goalScore }
    private var candidate: String { selection.map { puzzle.tiles[$0] }.joined() }
    /// Fragmentos que ya forman parte de una joya (se marcan, pero se pueden seguir usando).
    private var gemTiles: Set<Int> {
        var set = Set<Int>()
        for word in found where puzzle.isQuartile(word) {
            // Reconstruye qué fichas forman la joya (cada fragmento aparece una vez en el tablero).
            var rest = Substring(word)
            for _ in 0..<4 {
                guard let i = puzzle.tiles.indices.first(where: { !set.contains($0) && rest.hasPrefix(puzzle.tiles[$0]) }) else { break }
                set.insert(i); rest = rest.dropFirst(puzzle.tiles[i].count)
            }
        }
        return set
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 5) {
                HStack {
                    Text("\(score)/\(puzzle.goalScore)").foregroundStyle(color)
                    Spacer()
                    Text("💎 \(gems)/\(puzzle.targets.count)")
                }
                .font(.system(size: 12, weight: .bold, design: .rounded))

                if finished {
                    WResultPanel(kind: .quartiles, won: true,
                                 headline: AppLanguage.text("¡Las 5 joyas!", "All 5 gems!"),
                                 detail: "\(score) pts · \(wTime(elapsed))", onAnother: onAnother)
                } else {
                    Group {
                        if let notice { Text(notice.text).foregroundStyle(notice.color) }
                        else { Text(candidate.isEmpty ? " " : candidate.lowercased()) }
                    }
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .lineLimit(1).minimumScaleFactor(0.5)
                    .task(id: notice) {
                        guard notice != nil else { return }
                        try? await Task.sleep(for: .seconds(2))
                        notice = nil
                    }
                    tiles
                    HStack(spacing: 6) {
                        Button { selection.removeAll() } label: { Image(systemName: "delete.left") }
                            .disabled(selection.isEmpty)
                            .accessibilityLabel(AppLanguage.text("Borrar", "Clear"))
                        Button("OK", action: submit)
                            .tint(color)
                            .disabled(selection.isEmpty)
                    }
                }
                if !found.isEmpty {
                    Text(found.reversed().map { $0.lowercased() }.joined(separator: " · "))
                        .font(.caption2).foregroundStyle(WTheme.inkSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .navigationTitle(PuzzleKind.quartiles.title)
        .wClock(puzzle.id, running: !finished, elapsed: $elapsed)
        .onAppear {
            guard !loaded else { return }
            loaded = true
            found = progress.found(puzzle.id)
            elapsed = progress.elapsed(puzzle.id)
            finished = progress.isDone(puzzle.id)
        }
    }

    private var tiles: some View {
        let gemSet = gemTiles
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 3), count: 4), spacing: 3) {
            ForEach(puzzle.tiles.indices, id: \.self) { i in
                let picked = selection.firstIndex(of: i)
                WTile(fill: picked != nil ? color : (gemSet.contains(i) ? color.opacity(0.28) : WTheme.fill), radius: 5) {
                    Text(puzzle.tiles[i].lowercased())
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .lineLimit(1).minimumScaleFactor(0.6)
                        .foregroundStyle(picked != nil ? Color(hex: 0x10141D) : WTheme.ink)
                }
                .frame(height: 27)
                .onTapGesture { tap(i) }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(puzzle.tiles[i].lowercased())
                .accessibilityAddTraits(picked != nil ? [.isButton, .isSelected] : .isButton)
            }
        }
    }

    private func tap(_ i: Int) {
        if let at = selection.firstIndex(of: i) {
            selection.remove(at: at)
        } else if selection.count < 4 {
            selection.append(i)
            WHaptics.tick()
            if selection.count == 4 { submit() }
        }
    }

    private func submit() {
        let word = candidate
        if found.contains(word) {
            notice = WNotice(text: AppLanguage.text("Ya la tienes", "Already found"), kind: .info)
            WHaptics.warning()
        } else if puzzle.allValid.contains(word) {
            found.append(word)
            progress.setFound(puzzle.id, found)
            notice = WNotice(text: "\(word.lowercased()) +\(puzzle.points(for: word))", kind: .success)
            WHaptics.success()
            if isComplete {
                progress.markDone(puzzle.id)
                progress.setElapsed(puzzle.id, elapsed)
                progress.recordTime(TimeInterval(elapsed), kind: .quartiles, puzzleID: puzzle.id)
                progress.noteDayIfComplete()
                withAnimation { finished = true }
            } else if gems == puzzle.targets.count {
                notice = WNotice(text: AppLanguage.text("Faltan \(puzzle.goalScore - score) pts", "\(puzzle.goalScore - score) pts to go"), kind: .info)
            }
        } else {
            // Como en el iPhone: la palabra mala se queda para corregirla.
            notice = WNotice(text: AppLanguage.text("No vale", "Not a word"), kind: .error)
            WHaptics.error()
            return
        }
        selection = []
    }
}

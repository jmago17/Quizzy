#if os(iOS)
//
//  WordSearchGame.swift — News Raider
//

import SwiftUI
import Combine

struct WordSearchGame: View {
    @AppStorage(AppLanguage.storageKey) private var languageSelection = "system"
    let puzzle: WordSearchPuzzle
    @ObservedObject private var progress = PuzzleProgress.shared

    @State private var hits: [String] = []
    @State private var path: [GridCell] = []
    @State private var definitionWord: PZDefinitionTerm?
    @State private var anchor: GridCell?
    @State private var toast: PZToast?
    @State private var result: PZResult?
    @State private var finished = false
    @State private var elapsed = 0
    @State private var resultMessage = ""
    @State private var cellSize: CGFloat = 0

    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var lockedCells: Set<GridCell> {
        Set(puzzle.words.filter { hits.contains($0.word) }
            .flatMap { $0.cells.map { GridCell(row: $0[0], col: $0[1]) } })
    }

    var body: some View {
        GeometryReader { geo in
            let landscape = geo.size.width > geo.size.height * 1.2
            Group {
                if landscape {
                    HStack(spacing: 18) {
                        gridView.padding(.leading, 16).padding(.vertical, 10)
                        ScrollView {
                            VStack(alignment: .leading, spacing: 12) {
                                header
                                dragReadout
                                Text(AppLanguage.text("PALABRAS", "WORDS")).font(.caption.bold()).foregroundStyle(.secondary)
                                wordChips
                            }
                            .padding(.trailing, 16)
                        }
                        .frame(width: geo.size.width * 0.36)
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            header
                            dragReadout.padding(.bottom, PZSpace.sm)
                            gridView
                            wordChips
                        }
                            .padding(.horizontal, 16).padding(.bottom, 40)
                    }
                }
            }
        }
        .background(LiquidCanvasBackground())
        .navigationTitle(AppLanguage.text("Sopa de letras", "Word Search"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            hits = progress.found(puzzle.id)
            elapsed = progress.elapsed(puzzle.id)
            finished = progress.isDone(puzzle.id)
        }
        .onReceive(tick) { _ in
            guard !finished else { return }
            elapsed += 1
            if elapsed % 5 == 0 { progress.setElapsed(puzzle.id, elapsed) }
        }
        
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                PZHintButton(kind: .wordsearch,
                             isAvailable: !finished && hits.count < puzzle.words.count,
                             used: progress.hintsUsed(puzzle.id)) { revealNextWord() }
            }
        }
        .pzToast($toast)
        .sheet(item: $definitionWord) { term in
            PZDefinitionView(term: term.word.lowercased())
                .ignoresSafeArea()
        }
        .pzRules(.wordsearch)
        .sheet(item: $result) { r in PZResultSheet(result: r) }
    }

    /// Reveals the next word on the list and charges the hint penalty.
    private func revealNextWord() {
        guard let next = puzzle.words.first(where: { !hits.contains($0.word) }) else { return }
        hits.append(next.word)
        progress.setFound(puzzle.id, hits)
        progress.addHint(puzzle.id)
        elapsed += PZHintButton.penalty
        progress.setElapsed(puzzle.id, elapsed)
        flash("\(next.word.lowercased()) · +2 min", .info)
        if hits.count == puzzle.words.count { finishGame() }
    }

    /// Ends the round; shared by a winning drag and by hint-completion.
    private func finishGame() {
        guard !finished else { return }
        finished = true
        let finalElapsed = elapsed
        let avg = PuzzleTiming.average(kind: .wordsearch,
            itemCount: puzzle.words.count, boardSize: puzzle.size)
        progress.setElapsed(puzzle.id, finalElapsed)
        progress.recordTime(TimeInterval(finalElapsed), kind: .wordsearch, puzzleID: puzzle.id)
        resultMessage = AppLanguage.text("\(PuzzleTiming.clock(TimeInterval(finalElapsed))) · \(PuzzleTiming.comparison(elapsed: TimeInterval(finalElapsed), average: avg.seconds, personal: avg.personal, kind: .wordsearch))\n\(puzzle.words.count) palabras encontradas", "\(PuzzleTiming.clock(TimeInterval(finalElapsed))) · \(PuzzleTiming.comparison(elapsed: TimeInterval(finalElapsed), average: avg.seconds, personal: avg.personal, kind: .wordsearch))\n\(puzzle.words.count) words found")
        progress.markDone(puzzle.id)
        progress.noteDayIfComplete()
        result = PZResult(
            kind: .wordsearch,
            didWin: true,
            headline: AppLanguage.text("¡Sopa resuelta!", "Word search solved!"),
            detail: nil,
            metrics: [
                (AppLanguage.text("Palabras", "Words"), "\(puzzle.words.count)"),
                (AppLanguage.text("Tiempo", "Time"), PuzzleTiming.clock(TimeInterval(finalElapsed)))
            ],
            shareText: AppLanguage.text("NewsRaider Sopa de letras · \(puzzle.words.count) palabras · \(PuzzleTiming.clock(TimeInterval(finalElapsed)))", "NewsRaider Word Search · \(puzzle.words.count) words · \(PuzzleTiming.clock(TimeInterval(finalElapsed)))"))
    }

    private var timeString: String {
        String(format: "%d:%02d", elapsed / 60, elapsed % 60)
    }

    /// What the finger is currently spelling. Without this you only find out
    /// you overshot or stopped short after letting go.
    @ViewBuilder private var dragReadout: some View {
        let word = path.map { puzzle.grid[$0.row][$0.col] }.joined()
        let reversed = String(word.reversed())
        let isWord = puzzle.words.contains {
            ($0.word == word || $0.word == reversed) && !hits.contains($0.word)
        }
        HStack(spacing: PZSpace.sm) {
            if word.isEmpty {
                Text(AppLanguage.text("Arrastra sobre la rejilla", "Drag across the grid"))
                    .font(PZFont.caption)
                    .foregroundStyle(PZColor.inkTertiary)
            } else {
                Text(word.lowercased())
                    .font(.system(size: 20, weight: .bold, design: .serif))
                    .foregroundStyle(isWord ? PZColor.success : PZColor.ink)
                    .kerning(1.5)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                if isWord {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(PZColor.success)
                }
                Text("\(word.count)")
                    .font(PZFont.caption)
                    .foregroundStyle(PZColor.inkSecondary)
                    .monospacedDigit()
            }
        }
        .frame(maxWidth: .infinity, minHeight: 34)
        .padding(.horizontal, PZSpace.md)
        .background(isWord ? PZColor.wash(PZColor.success) : PZColor.fill,
                    in: Capsule())
        .animation(PZAnim.reveal, value: word)
        .accessibilityLabel(word.isEmpty ? AppLanguage.text("Sin selección", "No selection") : AppLanguage.text("Seleccionado: \(word)", "Selected: \(word)"))
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(AppLanguage.text("ENCONTRADAS", "FOUND"))
                    .font(.system(size: 12, weight: .semibold)).kerning(0.6)
                    .foregroundStyle(.secondary)
                Text("\(hits.count)/\(puzzle.words.count)")
                    .font(.system(size: 30, weight: .heavy)).kerning(-0.6)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(AppLanguage.text("TIEMPO", "TIME"))
                    .font(.system(size: 12, weight: .semibold)).kerning(0.6)
                    .foregroundStyle(.secondary)
                Text(timeString)
                    .font(.system(size: 30, weight: .heavy)).kerning(-0.6)
                    .monospacedDigit()
            }
        }
        .padding(.vertical, 14)
    }

    private var gridView: some View {
        GeometryReader { geo in
            let n = CGFloat(puzzle.size)
            let size = (geo.size.width - (n - 1)) / n
            Group {
                VStack(spacing: 1) {
                    ForEach(0..<puzzle.size, id: \.self) { r in
                        HStack(spacing: 1) {
                            ForEach(0..<puzzle.size, id: \.self) { c in
                                cellView(r, c, size: size)
                            }
                        }
                    }
                }
                .contentShape(Rectangle())
                .gesture(dragGesture(cell: size))
            }
            .onAppear { cellSize = size }
        }
        .aspectRatio(1, contentMode: .fit)
        .padding(10)
        .background(Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 14))
        .padding(.vertical, 12)
    }

    private func cellView(_ r: Int, _ c: Int, size: CGFloat) -> some View {
        let cell = GridCell(row: r, col: c)
        let picked = path.contains(cell)
        let locked = lockedCells.contains(cell)
        return Text(puzzle.grid[r][c])
            .font(.system(size: max(11, size * 0.45), weight: .semibold))
            .frame(width: size, height: size)
            .background(
                picked ? PZ.wordsearch
                : locked ? PZ.wordsearch.opacity(0.26)
                : Color.clear,
                in: RoundedRectangle(cornerRadius: 6)
            )
            .foregroundStyle(picked ? .white : .primary)
    }

    private func dragGesture(cell: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { v in
                guard cell > 0 else { return }
                let c = Int(v.location.x / (cell + 1))
                let r = Int(v.location.y / (cell + 1))
                guard r >= 0, r < puzzle.size, c >= 0, c < puzzle.size else { return }
                let here = GridCell(row: r, col: c)
                if anchor == nil { anchor = here; path = [here]; return }
                guard let a = anchor else { return }
                path = line(from: a, to: here)
            }
            .onEnded { _ in
                check()
                anchor = nil
                path = []
            }
    }

    /// Straight line (H/V/diagonal) between two cells, else just the anchor.
    private func line(from a: GridCell, to b: GridCell) -> [GridCell] {
        let dr = b.row - a.row, dc = b.col - a.col
        guard dr != 0 || dc != 0 else { return [a] }
        guard dr == 0 || dc == 0 || abs(dr) == abs(dc) else { return path }
        let n = max(abs(dr), abs(dc))
        let sr = dr == 0 ? 0 : dr / abs(dr)
        let sc = dc == 0 ? 0 : dc / abs(dc)
        return (0...n).map { GridCell(row: a.row + sr * $0, col: a.col + sc * $0) }
    }

    private func check() {
        guard path.count > 1 else { return }
        let word = path.map { puzzle.grid[$0.row][$0.col] }.joined()
        let rev = String(word.reversed())
        guard let hit = puzzle.words.first(where: {
            ($0.word == word || $0.word == rev) && !hits.contains($0.word)
        }) else { return }
        hits.append(hit.word)
        progress.setFound(puzzle.id, hits)
        pzHaptic(.medium)
        flash("\(hit.word.lowercased()) ✓", .success)
        if hits.count == puzzle.words.count { finishGame() }
    }

    private var wordChips: some View {
        PZFlowLayout(spacing: 7) {
            ForEach(puzzle.words, id: \.word) { w in
                let done = hits.contains(w.word)
                // Only solved words open their entry: tapping an unsolved one
                // would hand over a definition the player has not earned.
                let definable = done && PZDictionary.hasDefinition(for: w.word)
                HStack(spacing: 4) {
                    Text(w.word.lowercased())
                        .font(.system(size: 14, weight: .semibold))
                        .strikethrough(done)
                    if definable {
                        Image(systemName: "character.book.closed")
                            .font(.system(size: 9, weight: .semibold))
                    }
                }
                .opacity(done ? 0.42 : 1)
                .padding(.horizontal, 11).padding(.vertical, 8)
                .background(Color(.secondarySystemGroupedBackground),
                            in: RoundedRectangle(cornerRadius: 9))
                .contentShape(Rectangle())
                .onTapGesture { if definable { definitionWord = .init(word: w.word) } }
                .accessibilityHint(definable ? AppLanguage.text("Toca para ver la definición", "Tap to see the definition") : "")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func flash(_ text: String, _ kind: PZToast.Kind = .info) {
        toast = PZToast(text: text, kind: kind)
    }
}
#endif

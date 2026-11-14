#if os(iOS)
//
//  CrosswordGame.swift — News Raider
//

import SwiftUI
import Combine
import UIKit

struct CrosswordGame: View {
    @AppStorage(AppLanguage.storageKey) private var languageSelection = "system"
    let puzzle: CrosswordPuzzle
    @ObservedObject private var progress = PuzzleProgress.shared

    @State private var fill: [String: String] = [:]
    @State private var current = 0
    @State private var pos = 0
    @State private var toast: PZToast?
    @State private var result: PZResult?
    @State private var finished = false
    @State private var elapsed = 0
    @State private var resultMessage = ""
    @FocusState private var hardwareKeyboardFocused: Bool

    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()


    private var entry: CrossEntry { puzzle.entries[current] }

    /// True when the selected clue is already filled in correctly.
    private var entryIsSolved: Bool {
        entry.cells.allSatisfy { fill[$0.key] == puzzle.solution[$0.key] }
    }
    private var cells: [GridCell] { entry.cells }

    /// Clue numbers keyed by starting cell.
    private var numbers: [String: Int] {
        var out: [String: Int] = [:]
        var n = 1
        for e in puzzle.entries where out["\(e.row),\(e.col)"] == nil {
            out["\(e.row),\(e.col)"] = n
            n += 1
        }
        return out
    }

    var body: some View {
        GeometryReader { geo in
            let landscape = geo.size.width > geo.size.height * 1.2
            if landscape {
                HStack(spacing: 0) {
                    gridView.padding(12).frame(width: geo.size.width * 0.55)
                    VStack(spacing: 0) {
                        clueBar
                        Spacer(minLength: 4)
                    }
                }
            } else {
                VStack(spacing: 0) {
                    ScrollView { gridView.padding(.horizontal, 16).padding(.top, 12) }
                    clueBar
                }
            }
        }
        // Attached to the container, not to one layout branch: otherwise the
        // keyboard only exists in portrait and iPad never shows it.
        .safeAreaInset(edge: .bottom, spacing: 0) { crosswordKeyboard }
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
        // `simultaneousGesture` rather than `onTapGesture`: a plain tap gesture
        // on the container swallows taps meant for the cells and the on-screen
        // keys, which left the whole puzzle unresponsive.
        .simultaneousGesture(TapGesture().onEnded { claimHardwareKeyboardFocus() })
        .navigationTitle(AppLanguage.text("Autodefinido", "Crossword"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // Discard saved letters that do not belong to this grid. A puzzle
            // id alone is not proof the layout matches: an earlier build could
            // regenerate a different grid under the same id, leaving letters
            // stranded in cells that no longer exist or that belong to another
            // word. Keeping only cells present in the solution makes a stale
            // save degrade into a partly filled puzzle rather than a corrupt one.
            let saved = progress.fill(puzzle.id)
            fill = saved.filter { puzzle.solution[$0.key] != nil }
            if fill.count != saved.count {
                progress.setFill(puzzle.id, fill)
            }
            elapsed = progress.elapsed(puzzle.id)
            finished = progress.isDone(puzzle.id)
            focusFirstGap()
            claimHardwareKeyboardFocus()
            // The grid can already be complete on arrival: the last letter may
            // have landed via a crossing word, or the player may be returning
            // to a puzzle they finished earlier. Without this the result panel
            // is simply never shown.
            checkCompletion()
        }
        .onReceive(tick) { _ in
            guard !finished else { return }
            elapsed += 1
            if elapsed % 5 == 0 { progress.setElapsed(puzzle.id, elapsed) }
        }
        
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                PZHintButton(kind: .crossword,
                             isAvailable: !finished && !entryIsSolved,
                             used: progress.hintsUsed(puzzle.id)) { revealCurrentEntry() }
            }
        }
        .pzToast($toast)
        .pzRules(.crossword)
        .sheet(item: $result) { r in PZResultSheet(result: r) }
    }

    /// On-screen keyboard, mirroring iOS key placement: backspace to the right
    /// of the third row, return underneath.
    private var crosswordKeyboard: some View {
        VStack(spacing: PZSpace.xs) {
            ForEach(Array(keyRows.enumerated()), id: \.offset) { i, row in
                HStack(spacing: 4) {
                    ForEach(Array(row), id: \.self) { ch in
                        Button { claimHardwareKeyboardFocus(); type(String(ch)) } label: {
                            Text(String(ch))
                                .font(.system(size: 17, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .frame(height: 42)
                                .background(PZColor.surface, in: PZRadius.rect(PZRadius.chip))
                                .foregroundStyle(PZColor.ink)
                                .overlay {
                                    PZRadius.rect(PZRadius.chip)
                                        .stroke(PZColor.hairline, lineWidth: 1)
                                }
                        }
                        .buttonStyle(.plain)
                        .disabled(finished)
                    }
                    if i == 2 {
                        Button { claimHardwareKeyboardFocus(); backspace() } label: {
                            Image(systemName: "delete.left")
                                .font(.system(size: 16, weight: .semibold))
                                .frame(width: 50, height: 42)
                                .background(PZColor.fill, in: PZRadius.rect(PZRadius.chip))
                                .foregroundStyle(PZColor.ink)
                        }
                        .buttonStyle(.plain)
                        .disabled(finished)
                        .accessibilityLabel(AppLanguage.text("Borrar", "Clear"))
                    }
                }
            }
            HStack(spacing: PZSpace.sm) {
                Spacer(minLength: 0)
                Button { claimHardwareKeyboardFocus(); move(1) } label: {
                    Label(AppLanguage.text("Siguiente", "Next"), systemImage: "return")
                        .font(PZFont.chip)
                        .frame(maxWidth: 220)
                        .frame(height: 40)
                        .background(PZColor.wash(PZ.crossword), in: PZRadius.rect(PZRadius.chip))
                        .foregroundStyle(PZ.crossword)
                        .overlay {
                            PZRadius.rect(PZRadius.chip).stroke(PZColor.hairline, lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
                .disabled(finished)
            }
        }
        .padding(.horizontal, PZSpace.sm)
        .padding(.vertical, PZSpace.sm)
        .background(.bar)
    }

    private var keyRows: [String] { ["QWERTYUIOP", PuzzleLanguage.from(puzzleID: puzzle.id) == .spanish ? "ASDFGHJKLÑ" : "ASDFGHJKL", "ZXCVBNM"] }

    /// Button focus is assigned after its action. Claim on the following UI
    /// turn so the game surface, rather than the last tapped button, receives
    /// the next physical-keyboard event on iPad.
    private func claimHardwareKeyboardFocus() {
        Task { @MainActor in
            await Task.yield()
            hardwareKeyboardFocused = true
        }
    }


    // MARK: Grid

    private var gridView: some View {
        GeometryReader { geo in
            // Grids are no longer always square: the mini crossword runs from
            // 5×5 to 7×7 through the week. Size the cell from whichever axis
            // is tighter so a 7×5 stays on screen without distorting.
            let cols = CGFloat(puzzle.cols)
            let rows = CGFloat(puzzle.rows)
            let byWidth = (geo.size.width - (cols - 1)) / cols
            let byHeight = (geo.size.height - (rows - 1)) / rows
            let size = min(byWidth, byHeight)
            VStack(spacing: 1) {
                ForEach(0..<puzzle.rows, id: \.self) { r in
                    HStack(spacing: 1) {
                        ForEach(0..<puzzle.cols, id: \.self) { c in
                            cellView(r, c, size: size)
                        }
                    }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .aspectRatio(CGFloat(puzzle.cols) / CGFloat(puzzle.rows), contentMode: .fit)
        .padding(10)
        .background(Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 14))
    }

    private func cellView(_ r: Int, _ c: Int, size: CGFloat) -> some View {
        let cell = GridCell(row: r, col: c)
        let key = cell.key
        let isBlock = puzzle.solution[key] == nil
        let inWord = cells.contains(cell)
        let isCursor = inWord && cells.indices.contains(pos) && cells[pos] == cell
        let isLocked = !isBlock && lockedCells.contains(key)

        return ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: isBlock ? 2 : 3)
                // A crossword reads as ink on paper: blocks are always the dark
                // squares and playable cells the light ones. `Color.primary`
                // flips with the colour scheme, which in dark mode inverted the
                // grid — blocks turned white and playable cells black, so the
                // puzzle read as its own negative.
                .fill(isBlock ? PZ.gridBlock
                      : isCursor ? PZ.crossword.opacity(0.34)
                      : isLocked ? PZ.gridLocked
                      : inWord ? PZ.crossword.opacity(0.14)
                      : PZ.gridCell)
            if !isBlock {
                if let num = numbers[key] {
                    Text("\(num)")
                        .font(.system(size: max(7, size * 0.24), weight: .semibold))
                        .foregroundStyle(PZ.gridInk.opacity(0.55))
                        .padding(.leading, 2).padding(.top, 1)
                }
                Text(fill[key] ?? "")
                    .font(.system(size: max(12, size * 0.5),
                                  weight: isLocked ? .bold : .semibold))
                    .foregroundStyle(isLocked ? PZ.gridLockedInk : PZ.gridInk)
                    .frame(width: size, height: size)
            }
        }
        .frame(width: size, height: size)
        .contentShape(Rectangle())
        .onTapGesture { if !isBlock { focus(cell) } }
    }

    // MARK: Clue bar

    private var clueBar: some View {
        HStack(spacing: 12) {
            Button { move(-1) } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: 36, height: 36)
                    .background(Color.primary.opacity(0.06), in: Circle())
            }
            Text("\(numbers["\(entry.row),\(entry.col)"] ?? 0)\(entry.isAcross ? "H" : "V")")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(PZ.crossword)
                .frame(minWidth: 34, alignment: .leading)
            Text(entry.clue)
                .font(.system(size: 15))
                .frame(maxWidth: .infinity, alignment: .leading)
            VStack(alignment: .trailing, spacing: 2) {
                Text(PuzzleTiming.clock(TimeInterval(elapsed)))
                    .font(.system(size: 13, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                Button { move(1) } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 17, weight: .semibold))
                        .frame(width: 36, height: 36)
                        .background(Color.primary.opacity(0.06), in: Circle())
                }
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16).padding(.vertical, 14)
        .background(Color(.secondarySystemGroupedBackground))
        .overlay(alignment: .top) { Divider() }
    }

    // MARK: Input

    /// Cells whose letter matches the solution. Once a letter is right it is
    /// locked: typing or deleting cannot disturb it. Re-derived from `fill`
    /// rather than stored, so it survives reload and can never drift out of
    /// sync with what is on screen.
    private var lockedCells: Set<String> {
        var out: Set<String> = []
        for (key, value) in puzzle.solution where fill[key] == value { out.insert(key) }
        return out
    }

    private func focus(_ cell: GridCell) {
        if let idx = puzzle.entries.firstIndex(where: { $0.cells.contains(cell) }) {
            if idx != current { current = idx }
            pos = puzzle.entries[current].cells.firstIndex(of: cell) ?? 0
        }
    }

    private func focusFirstGap() {
        pos = cells.firstIndex { fill[$0.key] != puzzle.solution[$0.key] } ?? 0
    }

    /// Advances to the next cell the player can still change, so locked
    /// letters never trap the cursor.
    private func advanceToEditable(from index: Int) {
        var next = index
        while next < cells.count - 1 && lockedCells.contains(cells[next].key) { next += 1 }
        pos = next
    }

    private func move(_ delta: Int) {
        current = (current + delta + puzzle.entries.count) % puzzle.entries.count
        focusFirstGap()
    }

    /// Fills in the word the player is currently on and charges the penalty.
    private func revealCurrentEntry() {
        let target = entry
        for cell in target.cells {
            fill[cell.key] = puzzle.solution[cell.key]
        }
        progress.setFill(puzzle.id, fill)
        progress.addHint(puzzle.id)
        elapsed += PZHintButton.penalty
        progress.setElapsed(puzzle.id, elapsed)
        toast = PZToast(text: "\(target.word.lowercased()) · +2 min", kind: .info)
        checkCompletion()
        if !finished { move(1) }
    }

    private func handleHardwareKey(_ press: KeyPress) -> KeyPress.Result {
        guard !finished else { return .ignored }
        if press.key == .delete {
            backspace()
            return .handled
        }
        if press.key == .return || press.key == .tab {
            move(press.modifiers.contains(.shift) ? -1 : 1)
            return .handled
        }
        let text = press.characters.uppercased()
        guard text.count == 1, let letter = text.first,
              "ABCDEFGHIJKLMNÑOPQRSTUVWXYZ".contains(letter) else { return .ignored }
        type(String(letter))
        return .handled
    }

    /// UIKit fallback for iPad: unlike `onKeyPress`, this path does not depend
    /// on a custom SwiftUI board retaining focus after a Button tap.
    private func handleCapturedHardwareKey(_ key: PZHardwareKey) -> Bool {
        guard !finished else { return false }
        switch key.unmodifiedInput {
        case UIKeyCommand.inputDelete:
            backspace()
            return true
        case "\r", "\n", "\t":
            move(key.modifiers.contains(.shift) ? -1 : 1)
            return true
        default:
            let text = key.unmodifiedInput.uppercased()
            guard text.count == 1, let letter = text.first,
                  "ABCDEFGHIJKLMNÑOPQRSTUVWXYZ".contains(letter) else { return false }
            type(String(letter))
            return true
        }
    }

    private func type(_ ch: String) {
        guard cells.indices.contains(pos) else { return }
        // A confirmed letter is settled: overwriting it would undo progress the
        // player has already earned.
        guard !lockedCells.contains(cells[pos].key) else {
            advanceToEditable(from: pos)
            // The grid may already be finished — never leave a completed
            // puzzle without announcing it just because this keystroke
            // landed on a settled letter.
            checkCompletion()
            return
        }
        fill[cells[pos].key] = ch
        progress.setFill(puzzle.id, fill)
        pzHaptic()
        if pos < cells.count - 1 {
            advanceToEditable(from: pos + 1)
        }
        checkCompletion()
    }

    private func backspace() {
        guard cells.indices.contains(pos) else { return }
        let key = cells[pos].key
        if fill[key] != nil && !lockedCells.contains(key) {
            fill[key] = nil
        } else {
            // Walk back over locked letters instead of stopping dead on them.
            var back = pos - 1
            while back >= 0 && lockedCells.contains(cells[back].key) { back -= 1 }
            guard back >= 0 else { return }
            pos = back
            fill[cells[back].key] = nil
        }
        progress.setFill(puzzle.id, fill)
    }

    private func checkCompletion() {
        // whole grid
        if puzzle.solution.allSatisfy({ fill[$0.key] == $0.value }) {
            // Guard against re-announcing: checkCompletion now also runs on
            // appear, and the sheet would otherwise return every time the
            // player dismissed it.
            guard result == nil else { return }
            let alreadyRecorded = finished
            finished = true
            let finalElapsed = elapsed
            let avg = PuzzleTiming.average(kind: .crossword, itemCount: puzzle.entries.count)
            if !alreadyRecorded {
                progress.setElapsed(puzzle.id, finalElapsed)
                progress.recordTime(TimeInterval(finalElapsed), kind: .crossword, puzzleID: puzzle.id)
                progress.markDone(puzzle.id)
                progress.noteDayIfComplete()
            }
            resultMessage = AppLanguage.text("\(PuzzleTiming.clock(TimeInterval(finalElapsed))) · \(PuzzleTiming.comparison(elapsed: TimeInterval(finalElapsed), average: avg.seconds, personal: avg.personal, kind: .crossword))\n\(puzzle.entries.count) definiciones resueltas", "\(PuzzleTiming.clock(TimeInterval(finalElapsed))) · \(PuzzleTiming.comparison(elapsed: TimeInterval(finalElapsed), average: avg.seconds, personal: avg.personal, kind: .crossword))\n\(puzzle.entries.count) clues solved")
            result = PZResult(
                kind: .crossword,
                didWin: true,
                headline: AppLanguage.text("¡Autodefinido resuelto!", "Crossword solved!"),
                detail: nil,
                metrics: [
                    (AppLanguage.text("Definiciones", "Clues"), "\(puzzle.entries.count)"),
                    (AppLanguage.text("Tiempo", "Time"), PuzzleTiming.clock(TimeInterval(finalElapsed)))
                ],
                shareText: AppLanguage.text("NewsRaider Autodefinido · \(puzzle.entries.count) definiciones · \(PuzzleTiming.clock(TimeInterval(finalElapsed)))", "NewsRaider Crossword · \(puzzle.entries.count) clues · \(PuzzleTiming.clock(TimeInterval(finalElapsed)))"))
            return
        }
        // current word
        let letters = cells.compactMap { fill[$0.key] }
        if letters.count == cells.count, letters.joined() == entry.word {
            flash("✓ \(entry.word.lowercased())", .success)
            Task {
                try? await Task.sleep(for: .seconds(0.35))
                move(1)
            }
        }
    }

    private func flash(_ text: String, _ kind: PZToast.Kind = .info) {
        toast = PZToast(text: text, kind: kind)
    }

    
}
#endif

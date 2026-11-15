#if os(iOS)
//
//  QuartilesGame.swift — News Raider
//

import SwiftUI
import Combine
import UIKit

struct QuartilesGame: View {
    @AppStorage(AppLanguage.storageKey) private var languageSelection = "system"
    let puzzle: QuartilePuzzle
    @ObservedObject private var progress = PuzzleProgress.shared

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var selection: [Int] = []
    @State private var tileOrder: [Int] = []
    @State private var exhaustedTiles: Set<Int> = []
    @State private var found: [String] = []
    @State private var toast: PZToast?
    @State private var result: PZResult?
    @State private var finished = false
    @State private var elapsed = 0
    /// Word whose dictionary entry is on screen, if any.
    @State private var definitionWord: PZDefinitionTerm?
    @State private var resultMessage = ""
    @FocusState private var hardwareKeyboardFocused: Bool
    /// Tiles locked into a solved quartile. Cached because resolving them needs
    /// backtracking, and the board asks for it once per tile per redraw.
    @State private var lockedTiles: Set<Int> = []
    /// Dictionary availability is a system lookup, far too slow to run from
    /// `body`. Resolved once per new word and reused afterwards.
    @State private var definableWords: Set<String> = []
    /// Drives the input field's flash after a submit. Nil while idle.
    @State private var submitFlash: SubmitOutcome?
    /// Bumped on every rejection so the shake replays even for the same word.
    @State private var shakeTick = 0

    enum SubmitOutcome: Equatable {
        case accepted
        case rejected

        var tint: Color { self == .accepted ? PZColor.success : PZColor.danger }
    }

    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var score: Int { found.reduce(0) { $0 + puzzle.points(for: $1) } }
    private var quartilesFound: Int { found.filter { puzzle.isQuartile($0) }.count }

    private let cols = Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)

    /// Widest the board is allowed to get. Beyond this the tiles stop growing
    /// and the grid centres itself instead of stretching edge to edge.
    private let maxBoardWidth: CGFloat = 460

    var body: some View {
        GeometryReader { geo in
            let landscape = geo.size.width > geo.size.height * 1.2
            Group {
                if landscape {
                    // The board is the game; the panel is bookkeeping. So the
                    // board takes whatever height the window really offers
                    // (capped so tiles never turn cartoonish) and the panel
                    // gets what is left, both vertically centred — otherwise
                    // everything piled up top and left a third of the window
                    // empty, which is what this looked like in Stage Manager.
                    let boardSide = min(geo.size.height - 48, geo.size.width * 0.52, 760)
                    let panelWidth = min(max(geo.size.width - boardSide - 72, 280), 420)
                    // Board on the leading edge, controls on the trailing one:
                    // Enviar and Borrar now sit beside the tiles instead of
                    // across the window from them.
                    HStack(alignment: .center, spacing: 32) {
                        board(maxWidth: boardSide, maxHeight: geo.size.height - 48)
                            .frame(width: boardSide)

                        ScrollView {
                            VStack(spacing: 0) {
                                scoreBar
                                inputBar
                                actions
                                compactFoundList
                            }
                        }
                        .frame(width: panelWidth)
                        .frame(maxHeight: boardSide)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, 24)
                } else {
                    ScrollView {
                        // Everything shares the board's width so the column
                        // reads as one object instead of a wide bar sitting on
                        // top of a narrow grid.
                        let column = min(geo.size.width - 32, maxBoardWidth)
                        VStack(spacing: 0) {
                            scoreBar
                            if horizontalSizeClass == .compact { compactFoundList }
                            inputBar
                            board(maxWidth: column)
                                .padding(.top, horizontalSizeClass == .compact ? 14 : 0)
                                .padding(.bottom, 14)
                            actions
                            if horizontalSizeClass != .compact { foundList }
                        }
                        .frame(maxWidth: column)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 16).padding(.bottom, 40)
                    }
                }
            }
        }
        .background(LiquidCanvasBackground())
        .background {
            PZHardwareKeyCapture { handleCapturedHardwareKey($0) }
                .frame(width: 1, height: 1)
                .accessibilityHidden(true)
        }
        // Hardware keyboard: number keys pick tiles by position, return submits
        // and delete undoes the last pick, so an iPad keyboard can play without
        // touching the screen.
        .focusable(interactions: .activate)
        .focused($hardwareKeyboardFocused)
        .focusEffectDisabled()
        .onKeyPress(phases: .down) { handleHardwareKey($0) }
        // Every on-screen button steals focus from the container listening for
        // key presses, and nothing gave it back — so the hardware keyboard went
        // dead as soon as you tapped a tile. Re-claim it on any touch.
        .simultaneousGesture(TapGesture().onEnded { claimHardwareKeyboardFocus() })
        .navigationTitle("Quartiles")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            found = progress.found(puzzle.id)
            tileOrder = progress.tileOrder(puzzle.id, default: Array(puzzle.tiles.indices))
            elapsed = progress.elapsed(puzzle.id)
            finished = progress.isDone(puzzle.id)
            refreshDerivedState()
            claimHardwareKeyboardFocus()
        }
        .onReceive(tick) { _ in
            guard !finished else { return }
            elapsed += 1
            if elapsed % 5 == 0 { progress.setElapsed(puzzle.id, elapsed) }
        }
        
        .pzToast($toast)
        .pzRules(.quartiles)
        .sheet(item: $definitionWord) { term in
            PZDefinitionView(term: term.word.lowercased())
                .ignoresSafeArea()
        }
        .sheet(item: $result) { r in PZResultSheet(result: r) }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                PZHintButton(kind: .quartiles,
                             isAvailable: !finished && pendingTarget != nil,
                             used: progress.hintsUsed(puzzle.id)) { revealTarget() }
            }
        }
    }

    private var scoreBar: some View {
        HStack(alignment: .firstTextBaseline) {
            stat(AppLanguage.text("PUNTOS", "POINTS"), "\(score)/\(puzzle.targetScore)")
            Spacer()
            stat(AppLanguage.text("TIEMPO", "TIME"), PuzzleTiming.clock(TimeInterval(elapsed)))
            Spacer()
            stat("QUARTILES", "\(quartilesFound)/5", trailing: true)
        }
        .padding(.vertical, 14)
    }

    private func stat(_ label: String, _ value: String, trailing: Bool = false) -> some View {
        VStack(alignment: trailing ? .trailing : .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .kerning(0.6)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 30, weight: .heavy))
                .kerning(-0.6)
        }
    }

    private var inputBar: some View {
        HStack(spacing: 6) {
            if selection.isEmpty {
                Text(AppLanguage.text("Toca las fichas", "Tap the tiles"))
                    .foregroundStyle(.secondary)
                    .font(.system(size: 15))
            } else {
                ForEach(selection, id: \.self) { i in
                    Text(puzzle.tiles[i].lowercased())
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12).padding(.vertical, 9)
                        .background(submitFlash?.tint ?? PZ.quartiles,
                                    in: RoundedRectangle(cornerRadius: 9))
                        .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 56)
        .padding(10)
        // The whole field answers the submit: it washes green or red and the
        // border lights up, then fades. A toast alone was too easy to miss
        // while looking at the tiles.
        .background(submitFlash.map { PZColor.wash($0.tint) }
                        ?? PZColor.surface,
                    in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(submitFlash?.tint ?? .clear, lineWidth: 2)
        }
        .scaleEffect(submitFlash == .accepted ? 1.03 : 1)
        // Rejections shake; accepts do not, so the two never feel alike.
        .modifier(PZShake(shakes: submitFlash == .rejected ? shakeTick : 0))
        .animation(.spring(duration: 0.28), value: submitFlash)
        .padding(.bottom, 12)
    }

    /// Flashes the field, then clears itself so the next submit can replay.
    private func flashInput(_ outcome: SubmitOutcome) {
        if outcome == .rejected { shakeTick += 1 }
        withAnimation(.spring(duration: 0.2)) { submitFlash = outcome }
        Task {
            try? await Task.sleep(for: .milliseconds(outcome == .accepted ? 520 : 640))
            withAnimation(.easeOut(duration: 0.32)) { submitFlash = nil }
        }
    }

    /// Tiles locked into a solved quartile: greyed out and moved to the last rows.
    /// Reads the cache instead of recomputing — see `refreshDerivedState()`.
    private var quartileTileIndices: Set<Int> { lockedTiles }

    /// Recomputes everything derived from `found`. Called only when the set of
    /// found words actually changes, never from `body`.
    private func refreshDerivedState() {
        lockedTiles = Set(found.filter { puzzle.isQuartile($0) }.flatMap { quartileTiles($0) })
        for word in found where !definableWords.contains(word) {
            if PZDictionary.hasDefinition(for: word) { definableWords.insert(word) }
        }
        recomputeExhausted()
    }

    /// Tiles that can no longer contribute to any *unfound* solution.
    /// Only these get struck through — a tile used in a quartile may still be
    /// part of other shorter words, so it stays usable.
    private func recomputeExhausted() {
        let pending = puzzle.allValid.subtracting(found)
        guard !pending.isEmpty else {
            exhaustedTiles = Set(puzzle.tiles.indices)
            return
        }
        var usable = Set<Int>()
        for word in pending {
            usable.formUnion(combinationsFor(word))
            if usable.count == puzzle.tiles.count { break }
        }
        exhaustedTiles = Set(puzzle.tiles.indices).subtracting(usable)
    }

    /// Every tile index that can take part in forming `word`.
    private func combinationsFor(_ word: String) -> Set<Int> {
        var result = Set<Int>()
        func walk(_ prefix: String, _ used: [Int]) {
            if prefix == word { result.formUnion(used); return }
            guard word.hasPrefix(prefix), used.count < 4 else { return }
            for (i, frag) in puzzle.tiles.enumerated() where !used.contains(i) {
                let next = prefix + frag
                if word.hasPrefix(next) { walk(next, used + [i]) }
            }
        }
        walk("", [])
        return result
    }

    /// Centred, width-limited board. Tile height tracks tile width so the
    /// grid keeps its proportions instead of turning into a flat strip.
    /// Board sized from the space it is actually given.
    ///
    /// `maxHeight` matters as much as the width: capping tile height at a
    /// fixed 78pt left the grid marooned in the middle of a wide window with
    /// empty bands above and below. Now the tiles grow until either axis runs
    /// out, so the board fills the room it has.
    private func board(maxWidth: CGFloat, maxHeight: CGFloat? = nil) -> some View {
        let width = max(maxWidth, 240)
        let spacing: CGFloat = 8
        let tileWidth = (width - spacing * 3) / 4
        let rows = CGFloat((tileOrder.count + 3) / 4)

        // Height the tiles would like, and the height that actually fits.
        let preferred = max(tileWidth * 0.78, 46)
        let fitting = maxHeight.map { ($0 - spacing * (rows - 1)) / rows } ?? preferred
        let tileHeight = min(preferred, max(fitting, 46))

        return LazyVGrid(columns: cols, spacing: spacing) {
            ForEach(tileOrder, id: \.self) { i in
                tile(i, puzzle.tiles[i], height: tileHeight)
            }
        }
        .frame(maxWidth: width)
        .frame(maxWidth: .infinity)
    }

    private func tile(_ i: Int, _ text: String, height: CGFloat = 52) -> some View {
        let sel = selection.contains(i)
        let inQuartile = quartileTileIndices.contains(i)
        let exhausted = exhaustedTiles.contains(i)
        return Button {
            pzHaptic()
            // A Button consumes the touch, so the container's tap gesture
            // never fires — reclaim keyboard focus from the action itself.
            claimHardwareKeyboardFocus()
            if let at = selection.firstIndex(of: i) {
                selection.remove(at: at)
            } else if selection.count < 4 {
                selection.append(i)
                // Four fragments is the longest a word can be, so there is
                // nothing left to decide: submit without making the player
                // reach for a button that sits across the board on iPad.
                if selection.count == 4 { submit() }
            }
        } label: {
            Text(text.lowercased())
                .font(.system(size: min(max(height * 0.36, 15), 22), weight: .bold))
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .strikethrough(exhausted && !sel, color: PZ.quartiles)
                .frame(maxWidth: .infinity)
                .frame(height: height)
                .background(sel ? PZ.quartiles : PZColor.surface,
                            in: RoundedRectangle(cornerRadius: 11))
                .foregroundStyle(sel ? .white : .primary)
        }
        .buttonStyle(.plain)
        .opacity(sel ? 1 : (exhausted ? 0.4 : (inQuartile ? 0.62 : 1)))
        .accessibilityLabel(text)
        .accessibilityValue(exhausted ? AppLanguage.text("sin combinaciones restantes", "no combinations remaining")
                            : inQuartile ? AppLanguage.text("usada en un quartile", "used in a quartile") : AppLanguage.text("disponible", "available"))
        .accessibilityHint(AppLanguage.text("Toca para añadir a la palabra", "Tap to add to the word"))
    }

    /// Tile indices that compose a found 4-fragment word.
    /// Which tiles spell `word`. Needs backtracking, not greedy matching: when
    /// one fragment is a prefix of another ("CO" vs "CON"), taking the first
    /// match can strand the rest of the word and wrongly report no solution —
    /// which silently skipped both the reordering and the shading.
    private func quartileTiles(_ word: String) -> [Int] {
        func solve(_ remaining: Substring, _ pool: [(offset: Int, element: String)]) -> [Int]? {
            if remaining.isEmpty { return [] }
            for (i, candidate) in pool.enumerated() where remaining.hasPrefix(candidate.element) {
                var rest = pool
                rest.remove(at: i)
                if let tail = solve(remaining.dropFirst(candidate.element.count), rest) {
                    return [candidate.offset] + tail
                }
            }
            return nil
        }
        return solve(Substring(word), Array(puzzle.tiles.enumerated())) ?? []
    }

    private var lockedTileIndices: Set<Int> { lockedTiles }

    private func shuffleAvailableTiles() {
        let locked = lockedTileIndices
        let available = tileOrder.filter { !locked.contains($0) }.shuffled()
        let completed = tileOrder.filter { locked.contains($0) }
        withAnimation(.snappy(duration: 0.45)) {
            tileOrder = available + completed
        }
        progress.setTileOrder(puzzle.id, tileOrder)
        pzHaptic(.medium)
    }

    private var actions: some View {
        // Precomputed once per redraw instead of twice inside the button.
        let movableCount = tileOrder.reduce(into: 0) { total, index in
            if !lockedTiles.contains(index) { total += 1 }
        }
        return HStack(spacing: 8) {
            Button {
                shuffleAvailableTiles()
            } label: {
                Label(AppLanguage.text("Mezclar", "Shuffle"), systemImage: "shuffle")
            }
                .buttonStyle(PZButton(filled: false))
                .disabled(movableCount < 2)
            Button(AppLanguage.text("Borrar", "Clear")) { selection = [] }
                .buttonStyle(PZButton(filled: false))
                .disabled(selection.isEmpty)
            // Four fragments submit on their own, so this only exists for the
            // shorter one-to-three fragment words.
            Button(AppLanguage.text("Enviar", "Submit")) { submit() }
                .buttonStyle(PZButton(filled: true, tint: PZ.quartiles))
                .disabled(selection.isEmpty || selection.count == 4)
        }
        .padding(.bottom, 18)
    }

    private var compactFoundList: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(AppLanguage.text("PALABRAS · \(found.count)", "WORDS · \(found.count)"))
                .font(.system(size: 12, weight: .bold))
                .kerning(0.6)
                .foregroundStyle(.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 7) {
                    if found.isEmpty {
                        Text(AppLanguage.text("Las palabras que encuentres aparecerán aquí", "Words you find will appear here"))
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 8)
                    } else {
                        ForEach(found, id: \.self) { w in
                            let q = puzzle.isQuartile(w)
                            let definable = definableWords.contains(w)
                            Text(w.lowercased())
                                .font(.system(size: 14, weight: .semibold))
                                .padding(.horizontal, 11).padding(.vertical, 8)
                                .background(q ? PZ.quartiles : PZColor.surface,
                                            in: RoundedRectangle(cornerRadius: 9))
                                .onTapGesture { if definable { definitionWord = .init(word: w) } }
                                .foregroundStyle(q ? .white : .primary)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 12)
    }

    private var foundList: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(AppLanguage.text("ENCONTRADAS · \(found.count)", "FOUND · \(found.count)"))
                .font(.system(size: 13, weight: .bold))
                .kerning(0.6)
                .foregroundStyle(.secondary)
            PZFlowLayout(spacing: 7) {
                ForEach(found, id: \.self) { w in
                    let q = puzzle.isQuartile(w)
                    let definable = definableWords.contains(w)
                    Button {
                        guard definable else { return }
                        definitionWord = .init(word: w)
                    } label: {
                        HStack(spacing: 5) {
                            Text(w.lowercased())
                                .font(.system(size: 14, weight: .semibold))
                            // The book only appears when the system actually
                            // has an entry, so the tap never disappoints.
                            if definable {
                                Image(systemName: "character.book.closed")
                                    .font(.system(size: 9, weight: .semibold))
                                    .opacity(0.6)
                            }
                            Text("+\(puzzle.points(for: w))")
                                .font(.system(size: 11))
                                .opacity(0.65)
                        }
                        .padding(.horizontal, 11).padding(.vertical, 8)
                        .background(q ? PZ.quartiles : PZColor.surface,
                                    in: RoundedRectangle(cornerRadius: 9))
                        .foregroundStyle(q ? .white : .primary)
                    }
                    .buttonStyle(.plain)
                    .disabled(!definable)
                    .accessibilityHint(definable ? AppLanguage.text("Toca para ver la definición", "Tap to see the definition") : "")
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// The next quartile the player has not found yet.
    private var pendingTarget: String? {
        puzzle.targets.first { !found.contains($0) }
    }

    /// Solves one quartile outright and charges the hint penalty.
    private func revealTarget() {
        guard let word = pendingTarget else { return }
        found.append(word)
        progress.setFound(puzzle.id, found)
        progress.addHint(puzzle.id)
        elapsed += PZHintButton.penalty
        progress.setElapsed(puzzle.id, elapsed)
        if let indices = quartileTiles(word) as [Int]?, indices.count == 4 {
            withAnimation(.snappy(duration: 0.45)) {
                tileOrder.removeAll { indices.contains($0) }
                tileOrder.append(contentsOf: indices)
            }
            progress.setTileOrder(puzzle.id, tileOrder)
        }
        refreshDerivedState()
        flash("\(word.lowercased()) · +2 min", .info)
        if quartilesFound == puzzle.targets.count { finishGame() }
    }


    /// Ends the round: shared by a winning submit and by hint-completion.
    private func finishGame() {
        guard !finished else { return }
            finished = true
            let finalElapsed = elapsed
            let avg = PuzzleTiming.average(kind: .quartiles, itemCount: 5)
            progress.setElapsed(puzzle.id, finalElapsed)
            progress.recordTime(TimeInterval(finalElapsed), kind: .quartiles, puzzleID: puzzle.id)
            progress.markDone(puzzle.id)
            progress.noteDayIfComplete()
            result = PZResult(
                kind: .quartiles,
                didWin: true,
                headline: AppLanguage.text("¡Los 5 Quartiles!", "All 5 Quartiles!"),
                detail: PuzzleTiming.comparison(elapsed: TimeInterval(finalElapsed),
                                                average: avg.seconds,
                                                personal: avg.personal,
                                                kind: .quartiles),
                metrics: [
                    (AppLanguage.text("Puntos", "Points"), "\(score)"),
                    (AppLanguage.text("Tiempo", "Time"), PuzzleTiming.clock(TimeInterval(finalElapsed))),
                    (AppLanguage.text("Palabras", "Words"), "\(found.count)")
                ],
                shareText: "NewsRaider Quartiles · \(score) pts · \(quartilesFound)/5 Quartiles · \(PuzzleTiming.clock(TimeInterval(finalElapsed)))")

    }

    /// Keyboard play: 1-9 and 0 choose a tile by its position on the board,
    /// return submits, delete undoes the last pick, escape clears.
    private func handleHardwareKey(_ press: KeyPress) -> KeyPress.Result {
        guard !finished else { return .ignored }
        if press.key == .delete {
            if !selection.isEmpty { selection.removeLast(); PZHaptics.tick() }
            return .handled
        }
        if press.key == .return {
            submit()
            return .handled
        }
        if press.key == .escape {
            selection = []
            return .handled
        }
        guard let digit = press.characters.first, digit.isNumber,
              let typed = Int(String(digit)) else { return .ignored }
        // 1-9 map to the first nine tiles, 0 to the tenth.
        let index = typed == 0 ? 9 : typed - 1
        guard tileOrder.indices.contains(index) else { return .handled }
        let tile = tileOrder[index]
        guard !lockedTiles.contains(tile) else { return .handled }
        if let at = selection.firstIndex(of: tile) {
            selection.remove(at: at)
        } else if selection.count < 4 {
            selection.append(tile)
            PZHaptics.tick()
            // Same rule as tapping: a fourth fragment completes the word, so
            // there is nothing left to confirm.
            if selection.count == 4 { submit() }
            return .handled
        }
        PZHaptics.tick()
        return .handled
    }

    private func handleCapturedHardwareKey(_ key: PZHardwareKey) -> Bool {
        guard !finished else { return false }
        switch key.unmodifiedInput {
        case UIKeyCommand.inputDelete:
            if !selection.isEmpty { selection.removeLast(); PZHaptics.tick() }
            return true
        case "\r", "\n":
            submit()
            return true
        case UIKeyCommand.inputEscape:
            selection = []
            return true
        default:
            guard let digit = key.unmodifiedInput.first, digit.isNumber,
                  let typed = Int(String(digit)) else { return false }
            let index = typed == 0 ? 9 : typed - 1
            guard tileOrder.indices.contains(index) else { return true }
            let tile = tileOrder[index]
            guard !lockedTiles.contains(tile) else { return true }
            if let at = selection.firstIndex(of: tile) {
                selection.remove(at: at)
            } else if selection.count < 4 {
                selection.append(tile)
                PZHaptics.tick()
                if selection.count == 4 { submit() }
            }
            return true
        }
    }

    /// Keep the game surface as the key-event target after a tile Button has
    /// taken SwiftUI focus on iPad.
    private func claimHardwareKeyboardFocus() {
        Task { @MainActor in
            await Task.yield()
            hardwareKeyboardFocused = true
        }
    }

    private func submit() {
        let word = selection.map { puzzle.tiles[$0] }.joined()
        if found.contains(word) {
            flash(AppLanguage.text("Ya la encontraste", "Already found"), .info)
            flashInput(.rejected)
        } else if puzzle.allValid.contains(word) {
            found.append(word)
            progress.setFound(puzzle.id, found)
            if selection.count == 4, puzzle.isQuartile(word) {
                // Remove the four fragments from wherever they are and append
                // them in word order. The newest quartile becomes the last row;
                // earlier completed rows naturally move upward.
                let completed = selection
                withAnimation(.snappy(duration: 0.45)) {
                    tileOrder.removeAll { completed.contains($0) }
                    tileOrder.append(contentsOf: completed)
                }
                progress.setTileOrder(puzzle.id, tileOrder)
            }
            refreshDerivedState()
            PZHaptics.success()
            flashInput(.accepted)
            flash("¡\(word.lowercased())! +\(puzzle.points(for: word))", .success)
            if quartilesFound == puzzle.targets.count { finishGame() }
        } else {
            PZHaptics.error()
            flashInput(.rejected)
            flash(AppLanguage.text("No es una palabra válida", "Not a valid word"), .error)
            // Auto-submit fires the moment the fourth tile lands, so wiping
            // the selection here would erase the attempt before the player
            // sees what they built. A wrong word stays on screen to be
            // corrected with Borrar or by deselecting a tile.
            return
        }
        selection = []
    }

    private func flash(_ text: String, _ kind: PZToast.Kind = .info) {
        toast = PZToast(text: text, kind: kind)
    }

    
}

// MARK: - Shared button style

struct PZButton: ButtonStyle {
    var filled: Bool
    var tint: Color = .accentColor

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(filled ? tint : PZColor.surface,
                        in: RoundedRectangle(cornerRadius: 11))
            .foregroundStyle(filled ? .white : .primary)
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

// MARK: - Flow layout for chips

struct PZFlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxW = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0
        for s in subviews {
            let sz = s.sizeThatFits(.unspecified)
            if x + sz.width > maxW, x > 0 { x = 0; y += rowH + spacing; rowH = 0 }
            x += sz.width + spacing
            rowH = max(rowH, sz.height)
        }
        return CGSize(width: maxW, height: y + rowH)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize,
                       subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowH: CGFloat = 0
        for s in subviews {
            let sz = s.sizeThatFits(.unspecified)
            if x + sz.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX; y += rowH + spacing; rowH = 0
            }
            s.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(sz))
            x += sz.width + spacing
            rowH = max(rowH, sz.height)
        }
    }
}
#endif

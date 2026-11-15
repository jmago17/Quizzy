#if os(iOS)
//
//  PuzzlesScreen.swift — News Raider
//  Daily and on-device procedurally generated games.
//

import SwiftUI

enum PZ {
    // Editorial accents: desaturated, print-like. Used for icons, hairlines
    // and 8% washes rather than full-bleed fills.
    static let quartiles   = Color(light: "C0392B", dark: "D9604F")
    static let wordsearch  = Color(light: "2F5D50", dark: "4C8877")
    static let crossword   = Color(light: "2C4A7C", dark: "5C82C0")
    static let maze        = Color(light: "4A3F7A", dark: "8377C0")
    static let wordle      = Color(light: "6E7B3F", dark: "9BAA63")
    static let trivia      = Color(light: "B26A1F", dark: "D3913F")
    static let numbers     = Color(light: "1F5F73", dark: "4E93A8")
    static let anygram     = Color(light: "8B3E72", dark: "D584BD")
    static let hashtag     = Color(light: "A05A18", dark: "D79950")
    static let murdle      = Color(light: "7A2628", dark: "CB6468")
    static let murdoku     = Color(light: "5E3348", dark: "B77A98")
    static let minicross   = Color(light: "1F5F73", dark: "6FB3C7")
    static let ladder      = Color(light: "6B4C2A", dark: "B08A5A")
    static let decoder     = Color(light: "7A3B1E", dark: "D18A5E")

    // MARK: Puzzle grid
    //
    // A crossword is ink on paper: dark blocks, light playable squares. These
    // deliberately do NOT flip with the colour scheme. Using `Color.primary`
    // inverted the grid in dark mode — blocks went white and playable cells
    // black — so the puzzle read as a photographic negative of itself. Dark
    // mode instead gets a softer paper and dimmer ink, keeping the contrast
    // direction intact while staying easy on the eye.
    static let gridCell       = Color(light: "FBFAF7", dark: "D8D4CC")
    static let gridBlock      = Color(light: "23252B", dark: "16181C")
    static let gridInk        = Color(light: "1A1C20", dark: "1A1C20")
    /// A letter confirmed correct: it can no longer be edited, so it is shown
    /// settled rather than merely highlighted.
    static let gridLocked     = Color(light: "E4EDDF", dark: "BFCFB6")
    static let gridLockedInk  = Color(light: "2F5233", dark: "24422A")

    static func color(_ k: PuzzleKind) -> Color {
        switch k {
        case .quartiles:  return quartiles
        case .wordsearch: return wordsearch
        case .crossword:  return crossword
        case .maze:       return maze
        case .wordle:     return wordle
        case .trivia:     return trivia
        case .numbers:    return numbers
        case .anygram:    return anygram
        case .hashtag:    return hashtag
        case .murdle:     return murdle
        case .murdoku:    return murdoku
        case .minicross:  return minicross
        case .ladder:     return ladder
        case .decoder:    return decoder
        }
    }
}


func pzHaptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
    UIImpactFeedbackGenerator(style: style).impactOccurred()
}

struct PuzzlesScreen: View {
    var onExit: (() -> Void)? = nil
    /// Same LiquidCollectionsBar as Portada, supplied by the host.
    var topBar: AnyView? = nil
    /// Quizzy: control extra del anfitrión junto al menú del encabezado (ajustes).
    var headerAccessory: AnyView? = nil
    private let fallback = PuzzleLoader.load()
    @AppStorage(AppLanguage.storageKey) private var languageSelection = "system"
    @Environment(\.locale) private var interfaceLocale
    @State private var cachedGames: [PuzzleLanguage: [PuzzleKind: AnyPuzzle]] = [:]
    @State private var generationToken = UUID()
    @State private var generationLanguage = AppLanguage.current
    @ObservedObject private var progress = PuzzleProgress.shared
    @State private var generated: [PuzzleKind: AnyPuzzle] = [:]
    @State private var generating = Set<PuzzleKind>()
    @State private var error: String?
    @State private var route: AnyPuzzle?
    @State private var completedResult: PZResult?

    private var offered: [PuzzleKind] { PuzzleKind.offered(in: AppLanguage.current) }
    private var featured: PuzzleKind { progress.firstPending ?? offered.first ?? .wordsearch }
    private var others: [PuzzleKind] { offered.filter { $0 != featured } }

    var body: some View {
        let _ = languageSelection
        ScrollView {
            LazyVStack(alignment: .leading, spacing: PZSpace.lg) {
                if isTabRoot { tabHeader }
                progressHeader
                if let topBar {
                    topBar
                }
                if let item = puzzle(featured) {
                    Button { open(item, kind: featured) } label: {
                        PZFeaturedCard(kind: featured,
                                       subtitle: item.subtitle,
                                       state: progress.state(featured),
                                       generating: generating.contains(featured))
                    }
                    .buttonStyle(.plain)
                    .contextMenu { cardMenu(featured, item) }
                }
                Text(AppLanguage.text("Todos los puzzles", "All puzzles"))
                    .font(PZFont.section)
                    .foregroundStyle(PZColor.ink)
                    .padding(.top, PZSpace.lg)
                LazyVGrid(columns: [GridItem(.flexible(), spacing: PZSpace.md),
                                    GridItem(.flexible(), spacing: PZSpace.md)],
                          spacing: PZSpace.md) {
                    ForEach(others, id: \.self) { kind in
                        if let item = puzzle(kind) {
                            Button { open(item, kind: kind) } label: {
                                PZGameCard(kind: kind,
                                           subtitle: rowSubtitle(kind, item),
                                           state: progress.state(kind),
                                           generating: generating.contains(kind))
                            }
                            .buttonStyle(.plain)
                            .contextMenu { cardMenu(kind, item) }
                        }
                    }
                }

                Text(AppLanguage.text("Cada partida se genera en este dispositivo. El puzzle diario se reproduce con la fecha, así que es el mismo en todos tus dispositivos.", "Each game is generated on this device. Daily puzzles use the date and language, so they match across your devices."))
                    .font(PZFont.caption)
                    .foregroundStyle(PZColor.inkSecondary)
                    .padding(.top, PZSpace.sm)
                    .padding(.bottom, PZSpace.xxl)
                #if DEBUG
                if progress.debugDayOffset != 0 {
                    Label("\(AppLanguage.text("Día simulado", "Simulated day")): \(progress.debugDayOffset > 0 ? "+" : "")\(progress.debugDayOffset) · \(PuzzleSeed.effectiveDate().formatted(.dateTime.day().month().year().locale(AppLanguage.current.locale)))",
                          systemImage: "hammer.fill")
                        .font(PZFont.caption)
                        .foregroundStyle(PZColor.warning)
                        .padding(.bottom, PZSpace.xxl)
                }
                #endif
            }
            .padding(.horizontal, PZSpace.screenH)
            .padding(.bottom, 96)
        }
        .background(LiquidCanvasBackground())
        .navigationDestination(item: $route) { destination($0) }
        .navigationTitle(AppLanguage.text("Juegos", "Games"))
        .navigationBarTitleDisplayMode(.inline)
        // Raíz de pestaña (iPhone Tabs): sin barra; el encabezado serif sube a la zona segura.
        .toolbar(isTabRoot ? .hidden : .visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                if let onExit {
                    Button(AppLanguage.text("Portada", "Home"), systemImage: "chevron.left", action: onExit)
                        .accessibilityLabel(AppLanguage.text("Salir de Juegos y volver a Portada", "Leave Games and return Home"))
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                if !isTabRoot { generateMenu }
            }
        }
        .sheet(item: $completedResult) { PZResultSheet(result: $0) }
        .onReceive(NotificationCenter.default.publisher(for: .pzNewSameGame)) { note in
            guard let rawValue = note.object as? String,
                  let kind = PuzzleKind(rawValue: rawValue),
                  offered.contains(kind) else { return }
            // Sin pasar por el menú: la ruta pasa directamente a la partida nueva cuando está lista.
            newPuzzle(kind, openWhenReady: true)
        }
        .onReceive(NotificationCenter.default.publisher(for: .pzOpenNextGame)) { note in
            guard let rawValue = note.object as? String,
                  let kind = PuzzleKind(rawValue: rawValue),
                  offered.contains(kind),
                  let next = puzzle(kind) else { return }
            route = next
        }
        .task(id: interfaceLocale.identifier + languageSelection) {
            generationToken = UUID()
            if generationLanguage != AppLanguage.current {
                // Return to the hub; never put Spanish content under English chrome.
                // Each game persists edits under its unchanged ID on disappearance.
                route = nil
                completedResult = nil
            }
            generationLanguage = AppLanguage.current
            generated = cachedGames[generationLanguage] ?? [:]
            generating.removeAll()
            await generateDailyGames()
            #if DEBUG
            // NR_GAME=wordle opens a game directly — verification aid only.
            if let want = ProcessInfo.processInfo.environment["NR_GAME"],
               let kind = PuzzleKind(rawValue: want),
               let item = puzzle(kind) {
                route = item
            }
            #endif
        }
        .alert(AppLanguage.text("No se pudo generar", "Could not generate puzzle"), isPresented: .constant(error != nil)) {
            Button(AppLanguage.text("Aceptar", "OK")) { error = nil }
        } message: { Text(error ?? "") }
    }

    // MARK: Header

    private var generateMenu: some View {
        Menu {
            ForEach(offered) { kind in
                Button(AppLanguage.text("Nuevo \(kind.title)", "New \(kind.title)"), systemImage: kind.symbol) { newPuzzle(kind) }
            }
            Divider()
            Button(AppLanguage.text("Renovar todos", "Generate all again"), systemImage: "arrow.clockwise") {
                offered.forEach { newPuzzle($0) }
            }
            #if DEBUG
            Divider()
            Section(AppLanguage.text("Pruebas", "Testing")) {
                Button(AppLanguage.text("Simular día siguiente", "Simulate next day"), systemImage: "calendar.badge.plus") {
                    shiftDebugDay(by: 1)
                }
                Button(AppLanguage.text("Simular día anterior", "Simulate previous day"), systemImage: "calendar.badge.minus") {
                    shiftDebugDay(by: -1)
                }
                if progress.debugDayOffset != 0 {
                    Button("\(AppLanguage.text("Volver a hoy", "Return to today")) (\(progress.debugDayOffset > 0 ? "+" : "")\(progress.debugDayOffset)d)",
                           systemImage: "calendar") {
                        setDebugDay(0)
                    }
                }
                Button(AppLanguage.text("Borrar progreso y reiniciar", "Clear progress and restart"), systemImage: "trash", role: .destructive) {
                    progress.resetAllProgress()
                    regenerateAllDaily()
                }
            }
            #endif
        } label: { Image(systemName: "plus.circle") }
        .accessibilityLabel(AppLanguage.text("Generar nuevos puzzles", "Generate new puzzles"))
    }

    /// Raíz de pestaña iPhone: sin botón de salida ni topBar.
    private var isTabRoot: Bool { onExit == nil && topBar == nil }

    /// Encabezado estilo Portada; el menú de nuevos puzzles (antes en la barra) va a la derecha.
    private var tabHeader: some View {
        let streak = progress.streak
        return PortadaHeader(
            title: LocalizedStringKey(AppLanguage.text("Juegos", "Games")), userName: "",
            horizontalPadding: 0,
            detail: streak > 0 ? AppLanguage.text("Racha · \(streak) día\(streak == 1 ? "" : "s")", "Streak · \(streak) day\(streak == 1 ? "" : "s")") : nil)
            .overlay(alignment: .topTrailing) {
                HStack(spacing: PZSpace.md) {
                    if let headerAccessory { headerAccessory }
                    generateMenu
                }
                .padding(.top, 8)
            }
    }

    private var progressHeader: some View {
        let done = progress.doneCount
        let total = offered.count
        let streak = progress.streak
        return VStack(alignment: .leading, spacing: PZSpace.md) {
            // Date and streak share the eyebrow line, so the metric below it
            // stands alone the way a masthead figure does.
            HStack(alignment: .firstTextBaseline) {
                Text(Date().formatted(.dateTime.weekday(.wide).day().month(.wide)
                    .locale(AppLanguage.current.locale)))
                    .pzLabelStyle()
                Spacer(minLength: PZSpace.sm)
                if streak > 0 {
                    Text(AppLanguage.text("Racha · \(streak) día\(streak == 1 ? "" : "s")", "Streak · \(streak) day\(streak == 1 ? "" : "s")"))
                        .pzLabelStyle()
                        .accessibilityLabel(AppLanguage.text("Racha de \(streak) días", "\(streak)-day streak"))
                }
            }
            HStack(alignment: .firstTextBaseline, spacing: PZSpace.xs + 2) {
                Text(AppLanguage.text("\(done) de \(total)", "\(done) of \(total)"))
                    .font(PZFont.display)
                    .foregroundStyle(PZColor.ink)
                Text(AppLanguage.text("completados", "completed"))
                    .font(PZFont.body)
                    .foregroundStyle(PZColor.inkSecondary)
                Spacer(minLength: 0)
            }
            // One segment per puzzle: reads as "8 puzzles" at a glance and
            // gives the header some editorial texture.
            HStack(spacing: 3) {
                ForEach(offered) { kind in
                    Capsule()
                        .fill(progress.isDoneToday(kind) ? PZ.color(kind) : PZColor.hairline)
                        .frame(height: 4)
                        .animation(PZAnim.fill, value: progress.isDoneToday(kind))
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(AppLanguage.text("\(done) de \(total) completados hoy", "\(done) of \(total) completed today"))
        }
        .padding(.top, PZSpace.lg)
    }

    private func open(_ item: AnyPuzzle, kind: PuzzleKind) {
        guard offered.contains(kind) else { return }
        // Match on the puzzle actually built for today when we have it: the
        // seed-derived id misses generators that retry with a new seed.
        let dailyID = progress.todaysPuzzleID(kind)
            ?? progress.dailyID(kind: kind, seed: PuzzleSeed.daily(kind: kind))
        guard item.id == dailyID, progress.isDoneToday(kind) else {
            route = item
            return
        }
        let best = progress.best(kind)
        completedResult = PZResult(
            kind: kind,
            didWin: true,
            headline: AppLanguage.text("Juego de hoy completado", "Today's game completed"),
            detail: AppLanguage.text("Ya has terminado el \(kind.title) diario. Puedes jugar otro distinto.", "You have finished today's \(kind.title). You can play another puzzle."),
            metrics: best.map { [(AppLanguage.text("Récord", "Best time"), PuzzleTiming.clock($0))] } ?? [],
            shareText: AppLanguage.text("NewsRaider \(kind.title) · juego diario completado", "NewsRaider \(kind.title) · daily puzzle completed")
        )
    }

    private func rowSubtitle(_ kind: PuzzleKind, _ item: AnyPuzzle) -> String {
        if generating.contains(kind) { return AppLanguage.text("Generando…", "Generating…") }
        switch progress.state(kind) {
        case .done:
            if let best = progress.best(kind) {
                return AppLanguage.text("Hecho · récord \(PuzzleTiming.clock(best))", "Done · best \(PuzzleTiming.clock(best))")
            }
            return AppLanguage.text("Hecho", "Done")
        case .started:
            let id = progress.dailyID(kind: kind, seed: PuzzleSeed.daily(kind: kind))
            let spent = progress.elapsed(id)
            return spent > 5 ? AppLanguage.text("En curso · \(PuzzleTiming.clock(TimeInterval(spent)))", "In progress · \(PuzzleTiming.clock(TimeInterval(spent)))") : AppLanguage.text("En curso", "In progress")
        case .fresh:
            return item.subtitle
        }
    }

    // MARK: Generation

    private func puzzle(_ kind: PuzzleKind) -> AnyPuzzle? {
        guard offered.contains(kind) else { return nil }
        guard generationLanguage == AppLanguage.current else { return fallbackPuzzle(kind) }
        return generated[kind] ?? fallbackPuzzle(kind)
    }

    private func fallbackPuzzle(_ kind: PuzzleKind) -> AnyPuzzle? {
        guard AppLanguage.current == .spanish else { return nil }
        switch kind {
        case .quartiles:  return fallback?.quartiles.first.map(AnyPuzzle.q)
        case .wordsearch: return fallback?.wordsearch.first.map(AnyPuzzle.w)
        case .crossword:  return fallback?.crossword.first.map(AnyPuzzle.c)
        case .maze, .wordle, .trivia, .numbers, .anygram, .hashtag, .murdle, .murdoku, .minicross, .ladder, .decoder: return nil
        }
    }

    /// `dayIndex` is only meaningful for daily puzzles; pass nil for the
    /// "generate another" path so those stay random.
    nonisolated private static func make(_ kind: PuzzleKind, seed: UInt64, dayIndex: Int? = nil, language: PuzzleLanguage) -> AnyPuzzle? {
        guard PuzzleKind.offered(in: language).contains(kind) else { return nil }
        switch kind {
        case .quartiles:  return ProceduralPuzzleGenerator.quartiles(seed: seed, language: language).map(AnyPuzzle.q)
        case .wordsearch: return ProceduralPuzzleGenerator.wordSearch(seed: seed, language: language).map(AnyPuzzle.w)
        case .crossword:  return ProceduralPuzzleGenerator.crossword(seed: seed, language: language).map(AnyPuzzle.c)
        case .maze:       return .m(MazePuzzle.generate(seed: seed))
        case .wordle:
            if let dayIndex { return .d(WordlePuzzle.daily(dayIndex: dayIndex, language: language)) }
            return .d(WordlePuzzle.generate(seed: seed, language: language))
        case .trivia:
            if let dayIndex { return .t(TriviaPuzzle.daily(dayIndex: dayIndex)) }
            return .t(TriviaPuzzle.generate(seed: seed))
        case .numbers:    return .n(NumbersPuzzle.generate(seed: seed))
        case .anygram:    return AnygramPuzzle.generate(seed: seed, language: language).map(AnyPuzzle.a)
        case .hashtag:    return .h(HashtagPuzzle.generate(seed: seed, language: language))
        case .minicross:  return MiniCrosswordGenerator.daily(dayIndex: dayIndex ?? PuzzleSeed.dayIndex(), language: language)
            .map(AnyPuzzle.x) ?? MiniCrosswordGenerator.generate(seed: seed, language: language).map(AnyPuzzle.x)
        case .murdle:
            let levels = MurdlePuzzle.Difficulty.allCases
            return .u(MurdlePuzzle.generate(seed: seed, difficulty: levels[Int(seed % UInt64(levels.count))], language: language))
        case .murdoku:    return .k(MurdokuPuzzle.generate(seed: seed, language: language))
        case .ladder:     return .l(WordLadderPuzzle.generate(seed: seed))
        case .decoder:    return .r(DecoderGame.make(seed: seed, spanish: language == .spanish))
        }
    }

    @MainActor private func generateDailyGames() async {
        let language = AppLanguage.current
        let token = generationToken
        let day = PuzzleSeed.dayIndex()
        let available = PuzzleKind.offered(in: language)
        for kind in available where generated[kind] == nil {
            if let saved = PuzzleSnapshotStore.load(kind: kind, language: language, day: day,
                                                    defaults: progress.defaults) {
                let puzzle: AnyPuzzle
                switch saved {
                case .quartiles(let p): puzzle = .q(p)
                case .wordSearch(let p): puzzle = .w(p)
                case .crossword(let p): puzzle = kind == .minicross ? .x(p) : .c(p)
                case .anygram(let p): puzzle = .a(p)
                }
                generated[kind] = puzzle
                progress.rememberTodaysPuzzleID(puzzle.id, kind: kind)
            }
        }
        // Anygram (español) tarda ~10 s en generarse: si no hay uno guardado para hoy se usa el
        // incluido en la app (la primera vez, o el día en que no hubo tiempo de precalcular) y
        // no se genera nada en el arranque. El de mañana y un aleatorio se preparan en segundo plano.
        if generated[.anygram] == nil, language == .spanish, available.contains(.anygram),
           let fallbackPuzzle = AnygramDefault.puzzle,
           progress.todaysPuzzleID(.anygram) == fallbackPuzzle.id || !progress.isDone(fallbackPuzzle.id) {
            generated[.anygram] = .a(fallbackPuzzle)
            progress.rememberTodaysPuzzleID(fallbackPuzzle.id, kind: .anygram)
        }
        cachedGames[language] = generated
        AnygramPrefetch.ensureReady(language: language, defaults: progress.defaults)
        let pending = available.filter { generated[$0] == nil }
        guard !pending.isEmpty else { return }

        let today = PuzzleSeed.dayIndex()
        generating.formUnion(pending)

        // Built concurrently, not one after another. Sequentially the heavier
        // generators (crossword, anygram, minicross retry until they find a
        // valid layout) blocked everything behind them, so the last cards
        // took seconds to appear and a force-quit mid-run lost the lot.
        // Each result is published as soon as it lands, so cards fill in as
        // they are ready instead of all at the end.
        await withTaskGroup(of: (PuzzleKind, AnyPuzzle?).self) { group in
            for kind in pending {
                let seed = PuzzleSeed.daily(kind: kind)
                group.addTask(priority: .userInitiated) {
                    #if DEBUG
                    let t0 = CFAbsoluteTimeGetCurrent()
                    defer { NSLog("PZGEN %@ %d ms", kind.rawValue, Int((CFAbsoluteTimeGetCurrent() - t0) * 1000)) }
                    #endif
                    return (kind, Self.make(kind, seed: seed, dayIndex: today, language: language))
                }
            }
            for await (kind, game) in group {
                guard !Task.isCancelled, token == generationToken,
                      language == AppLanguage.current else { continue }
                if let game {
                    generated[kind] = game
                    cachedGames[language] = generated
                    remember(game)
                    // Record which concrete puzzle is today's, so completion
                    // is matched against the id that will actually be written
                    // when the player finishes — not one recomputed from the
                    // seed.
                    progress.rememberTodaysPuzzleID(game.id, kind: kind)
                    saveDailyGrid(game, kind: kind, language: language, day: today)
                }
                generating.remove(kind)
            }
        }
    }

    /// Long-press menu on a puzzle card. AppLanguage.text("Empezar de nuevo", "Start over") wipes the progress
    /// of the puzzle currently on that card without changing the puzzle
    /// itself, which is what a player wants after a wrong start; "Generar
    /// otro" replaces it with a freshly seeded one.
    @ViewBuilder private func cardMenu(_ kind: PuzzleKind, _ item: AnyPuzzle) -> some View {
        Button(AppLanguage.text("Empezar de nuevo", "Start over"), systemImage: "arrow.counterclockwise") {
            progress.reset(item.id)
            DecoderStore(defaults: progress.defaults).clear(id: item.id)
            pzHaptic()
        }
        Button(AppLanguage.text("Generar otro", "Generate another"), systemImage: "sparkles") { newPuzzle(kind) }
    }

    private func newPuzzle(_ kind: PuzzleKind, openWhenReady: Bool = false) {
        guard offered.contains(kind) else { return }
        let language = AppLanguage.current
        let token = generationToken
        generating.insert(kind)
        Task {
            let seed = PuzzleSeed.random()
            let recentWords: Set<String> = kind == .wordle
                ? Set(progress.recentWordleAnswers(language: language)) : Set<String>()
            let defaults = progress.defaults
            let recentQuestions: Set<Int> = kind == .trivia
                ? Set(progress.recentTriviaQuestions()) : Set<Int>()
            let game: AnyPuzzle? = await Task.detached(priority: .userInitiated) {
                switch kind {
                case .wordle:
                    return .d(WordlePuzzle.generate(seed: seed, excluding: recentWords, language: language))
                case .trivia:
                    return .t(TriviaPuzzle.generate(seed: seed, excluding: recentQuestions))
                case .anygram:
                    // Si hay uno ya preparado, instantáneo; si no, se genera (≈10 s en español).
                    if let ready = AnygramPrefetch.take(language: language, defaults: defaults) { return .a(ready) }
                    return Self.make(kind, seed: seed, language: language)
                default:
                    return Self.make(kind, seed: seed, language: language)
                }
            }.value
            await MainActor.run {
                guard token == generationToken, language == AppLanguage.current else { return }
                if let game {
                    generated[kind] = game
                    cachedGames[language] = generated
                    remember(game)
                    if openWhenReady { route = game }
                } else { error = AppLanguage.text("Prueba de nuevo: esta semilla no produjo una rejilla válida.", "Try again: this seed did not produce a valid grid.") }
                generating.remove(kind)
                if kind == .anygram { AnygramPrefetch.ensureReady(language: language, defaults: progress.defaults) }
            }
        }
    }

    private func saveDailyGrid(_ game: AnyPuzzle, kind: PuzzleKind, language: PuzzleLanguage, day: Int) {
        let grid: PuzzleSnapshotStore.Grid
        switch game {
        case .q(let p): grid = .quartiles(p)
        case .w(let p): grid = .wordSearch(p)
        case .c(let p), .x(let p): grid = .crossword(p)
        case .a(let p): grid = .anygram(p)
        default: return
        }
        PuzzleSnapshotStore.save(grid, kind: kind, language: language, day: day, defaults: progress.defaults)
    }

    /// Records what a freshly built puzzle used, so later rounds can avoid it.
    @MainActor private func remember(_ game: AnyPuzzle) {
        switch game {
        case .d(let wordle):
            progress.rememberWordleAnswer(wordle.answer, language: PuzzleLanguage.from(puzzleID: wordle.id))
        case .t(let trivia):
            progress.rememberTriviaQuestions(trivia.questions.map(\.id),
                                             bankSize: TriviaPuzzle.bankSize)
        default:
            break
        }
    }

    // MARK: Testing helpers

    #if DEBUG
    private func shiftDebugDay(by delta: Int) {
        setDebugDay(progress.debugDayOffset + delta)
    }

    private func setDebugDay(_ value: Int) {
        progress.debugDayOffset = value
        regenerateAllDaily()
    }

    /// Drops the cached puzzles so the daily set is rebuilt for the new date.
    private func regenerateAllDaily() {
        generationToken = UUID()
        cachedGames.removeAll()
        generated.removeAll()
        generating.removeAll()
        Task { await generateDailyGames() }
    }
    #endif

    @ViewBuilder private func destination(_ item: AnyPuzzle) -> some View {
        Group {
            switch item {
            case .q(let p):
                if offered.contains(.quartiles) { QuartilesGame(puzzle: p) }
            case .w(let p): WordSearchGame(puzzle: p)
            case .c(let p): CrosswordGame(puzzle: p)
            case .m(let p): MazeGame(puzzle: p)
            case .d(let p): WordleGame(puzzle: p)
            case .t(let p): TriviaGame(puzzle: p)
            case .n(let p): NumbersGame(puzzle: p)
            case .a(let p): AnygramGame(puzzle: p)
            case .h(let p): HashtagGame(puzzle: p)
            case .u(let p): MurdleGame(puzzle: p)
            case .k(let p): MurdokuGame(puzzle: p)
            case .x(let p): CrosswordGame(puzzle: p)
            case .l(let p): WordLadderGame(puzzle: p)
            case .r(let g): DecoderGameView(game: g)
            }
        }
        .id(item.id) // cada partida es una vista nueva: no hereda el estado de la anterior del mismo juego
        .toolbar(.visible, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
    }
}

enum AnyPuzzle: Identifiable, Sendable, Hashable {
    case q(QuartilePuzzle), w(WordSearchPuzzle), c(CrosswordPuzzle), m(MazePuzzle), d(WordlePuzzle)
    case t(TriviaPuzzle), n(NumbersPuzzle), a(AnygramPuzzle), h(HashtagPuzzle), u(MurdlePuzzle)
    case k(MurdokuPuzzle)
    case x(CrosswordPuzzle)
    case l(WordLadderPuzzle)
    case r(DecoderGame)
    var id: String {
        switch self {
        case .q(let p): return p.id
        case .w(let p): return p.id
        case .c(let p): return p.id
        case .m(let p): return p.id
        case .d(let p): return p.id
        case .t(let p): return p.id
        case .n(let p): return p.id
        case .a(let p): return p.id
        case .h(let p): return p.id
        case .u(let p): return p.id
        case .k(let p): return p.id
        case .x(let p): return p.id
        case .l(let p): return p.id
        case .r(let g): return g.id
        }
    }
    var subtitle: String {
        switch self {
        case .q(let p): return AppLanguage.text("\(p.tiles.count) fichas", "\(p.tiles.count) tiles")
        case .w(let p): return AppLanguage.text("\(p.words.count) palabras", "\(p.words.count) words")
        case .c(let p): return AppLanguage.text("\(p.entries.count) definiciones", "\(p.entries.count) clues")
        case .m(let p): return "\(p.cols) × \(p.rows)"
        case .d:        return AppLanguage.text("6 intentos", "6 attempts")
        case .t(let p): return "\(p.questions.count) preguntas"
        case .n(let p): return "objetivo \(p.target)"
        case .a(let p): return AppLanguage.text("\(p.answers.count) palabras cruzadas", "\(p.answers.count) crossing words")
        case .h(let p): return AppLanguage.text("\(p.words.count) palabras cruzadas", "\(p.words.count) crossing words")
        case .u(let p): return AppLanguage.text("\(p.suspects.count) sospechosos · \(p.difficulty.title)", "\(p.suspects.count) suspects · \(p.difficulty.title)")
        case .k(let p): return AppLanguage.text("\(p.size) × \(p.size) · \(p.suspects.count) sospechosos", "\(p.size) × \(p.size) · \(p.suspects.count) suspects")
        case .x(let p): return AppLanguage.text("\(p.entries.count) palabras cruzadas", "\(p.entries.count) crossing words")
        case .l(let p): return "\(p.minimumSteps) pasos mínimos"
        case .r:        return AppLanguage.text("4 casillas · 6 colores · 7 intentos", "4 slots · 6 colours · 7 attempts")
        }
    }
    static func == (a: AnyPuzzle, b: AnyPuzzle) -> Bool { a.id == b.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

// MARK: - Featured card

/// The lead of the Juegos hub, built like the lead of a page: white card, the
/// game's ink as a 3pt rule and an eyebrow, the title in serif ink. The glyph
/// stays a watermark at wash strength instead of white-on-saturated, so the
/// hero belongs to the same publication as the news cards. No fixed height —
/// the card grows with Dynamic Type instead of clipping.
struct PZFeaturedCard: View {
    @AppStorage(AppLanguage.storageKey) private var languageSelection = "system"
    let kind: PuzzleKind
    let subtitle: String
    let state: PuzzleState
    let generating: Bool

    private var ink: Color { PZ.color(kind) }

    var body: some View {
        let _ = languageSelection
        VStack(alignment: .leading, spacing: 0) {
            PZAccentRule(color: ink)
            VStack(alignment: .leading, spacing: PZSpace.sm) {
                Text(heroEyebrow)
                    .pzEyebrowStyle(ink)
                Text(kind.title)
                    .font(PZFont.hero)
                    .foregroundStyle(PZColor.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text(kind.blurb)
                    .font(PZFont.lede)
                    .foregroundStyle(PZColor.inkSecondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: PZSpace.md) {
                    Text(heroAction)
                        .pzPill(ink)
                    Text(generating ? AppLanguage.text("Generando…", "Generating…") : subtitle)
                        .font(PZFont.caption)
                        .foregroundStyle(PZColor.inkSecondary)
                    Spacer(minLength: 0)
                    if generating { ProgressView().tint(ink) }
                }
                .padding(.top, PZSpace.xs)
            }
            .padding(PZSpace.xl)
        }
        .pzCard(PZRadius.hero)
        // Bottom-right, so it never sits under the "…" menu the hub overlays
        // on the top-right corner.
        .overlay(alignment: .bottomTrailing) {
            Image(systemName: kind.symbol)
                .font(.system(size: 76, weight: .bold))
                .foregroundStyle(PZColor.wash(ink))
                .offset(x: 14, y: 14)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
        .clipShape(PZRadius.rect(PZRadius.hero))
        .accessibilityElement(children: .combine)
        .accessibilityHint(state.hint)
    }

    private var heroEyebrow: String {
        switch state {
        case .fresh:   return AppLanguage.text("Empieza por aquí", "Start here")
        case .started: return AppLanguage.text("Continúa donde lo dejaste", "Pick up where you left off")
        case .done:    return AppLanguage.text("Ya completado", "Already completed")
        }
    }

    private var heroAction: String {
        switch state {
        case .fresh:   return AppLanguage.text("Jugar", "Play")
        case .started: return AppLanguage.text("Continuar", "Continue")
        case .done:    return AppLanguage.text("Repetir", "Play again")
        }
    }

}

/// Small status dot used on the cards: empty ring when untouched, half-filled
/// while in progress, solid check once solved.
struct PZStateBadge: View {
    @AppStorage(AppLanguage.storageKey) private var languageSelection = "system"
    let kind: PuzzleKind
    let state: PuzzleState

    var body: some View {
        let _ = languageSelection
        Group {
            switch state {
            case .fresh:
                Circle()
                    .strokeBorder(PZColor.hairline, lineWidth: 1.5)
                    .frame(width: 15, height: 15)
            case .started:
                ZStack {
                    Circle().strokeBorder(PZ.color(kind), lineWidth: 1.5)
                    Circle().trim(from: 0, to: 0.5).fill(PZ.color(kind)).padding(3)
                }
                .frame(width: 15, height: 15)
            case .done:
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(PZ.color(kind))
            }
        }
        .accessibilityLabel(state.label)
    }
}

extension PuzzleState {
    var label: String {
        switch self {
        case .fresh:   return AppLanguage.text("Sin empezar", "Not started")
        case .started: return AppLanguage.text("Empezado", "Started")
        case .done:    return AppLanguage.text("Completado", "Completed")
        }
    }
    var hint: String {
        switch self {
        case .fresh:   return AppLanguage.text("Abrir juego", "Open game")
        case .started: return AppLanguage.text("Continuar partida", "Continue game")
        case .done:    return AppLanguage.text("Repetir partida", "Play again")
        }
    }
}

// MARK: - Game card

/// A smaller sibling of `PZFeaturedCard`: same visual language (gradient,
/// oversized glyph, pill) so every game reads as a card instead of a list row.
struct PZGameCard: View {
    @AppStorage(AppLanguage.storageKey) private var languageSelection = "system"
    let kind: PuzzleKind
    let subtitle: String
    let state: PuzzleState
    let generating: Bool

    var body: some View {
        let _ = languageSelection
        VStack(alignment: .leading, spacing: 0) {
            Rectangle()
                .fill(PZ.color(kind))
                .frame(height: 3)
            VStack(alignment: .leading, spacing: PZSpace.xs) {
                HStack {
                    Image(systemName: kind.symbol)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(PZ.color(kind))
                    Spacer()
                    if generating {
                        ProgressView().controlSize(.small)
                    } else {
                        PZStateBadge(kind: kind, state: state)
                    }
                }
                Spacer(minLength: PZSpace.sm)
                Text(kind.title)
                    .font(PZFont.title)
                    .foregroundStyle(PZColor.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .multilineTextAlignment(.leading)
                Text(generating ? AppLanguage.text("Generando…", "Generating…") : subtitle)
                    .font(PZFont.caption)
                    .foregroundStyle(PZColor.inkSecondary)
                    .lineLimit(1)
            }
            .padding(PZSpace.lg)
        }
        .frame(height: 132, alignment: .topLeading)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(state == .done ? PZColor.wash(PZ.color(kind)) : PZColor.surface)
        .clipShape(PZRadius.rect(PZRadius.card))
        .overlay {
            PZRadius.rect(PZRadius.card).stroke(PZColor.hairline, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityHint(state.hint)
    }
}
#endif

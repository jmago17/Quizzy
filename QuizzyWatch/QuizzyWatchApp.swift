//
//  QuizzyWatchApp.swift — Quizzy Watch
//  Portada del reloj: Palabro, Anygram, Laberinto y Decoder, más los juegos de acción que solo
//  existen aquí (`WatchArcade`: Brinco, Marcianitos y Escuadrón).
//  Trocitos se quitó del reloj el 2026-11-20 (20 fichas no caben: no era viable).
//  Los diarios usan las MISMAS semillas que el iPhone (`PuzzleSeed`), así que el reto del día es
//  el mismo; el progreso es local al reloj (no se sincroniza con el iPhone).
//

import SwiftUI

@main
struct QuizzyWatchApp: App {
    @StateObject private var hub = WatchHub()
    var body: some Scene {
        WindowGroup {
            WatchHomeView().environmentObject(hub)
        }
    }
}

/// Juegos que solo existen en el reloj (no son `PuzzleKind`: el iPhone no los conoce).
enum WatchArcade: String, Hashable, CaseIterable {
    case jump, aliens, planes, bubbles, leaks

    var title: String {
        switch self {
        case .jump: return WatchJump.title
        case .aliens: return WatchAliens.info.title
        case .planes: return WatchPlanes.info.title
        case .bubbles: return WatchBubbles.info.title
        case .leaks: return WatchLeaks.info.title
        }
    }
    var color: Color {
        switch self {
        case .jump: return WatchJump.color
        case .aliens: return WatchAliens.info.color
        case .planes: return WatchPlanes.info.color
        case .bubbles: return WatchBubbles.info.color
        case .leaks: return WatchLeaks.info.color
        }
    }
    var bestKey: String {
        switch self {
        case .jump: return WatchJump.bestKey
        case .aliens: return WatchAliens.info.bestKey
        case .planes: return WatchPlanes.info.bestKey
        case .bubbles: return WatchBubbles.info.bestKey
        case .leaks: return WatchLeaks.info.bestKey
        }
    }
    var blurb: String {
        switch self {
        case .jump: return AppLanguage.text("Salta con la Corona", "Jump with the Crown")
        case .aliens: return AppLanguage.text("Defiende con la Corona", "Defend with the Crown")
        case .planes: return AppLanguage.text("Pilota con la Corona", "Fly with the Crown")
        case .bubbles: return AppLanguage.text("Explota pompas con la Corona", "Pop bubbles with the Crown")
        case .leaks: return AppLanguage.text("Recoge gotas con la Corona", "Catch drops with the Crown")
        }
    }
    /// Fondo de la pantalla del juego. En Escuadrón y Brinco es un color liso de mar, para que la
    /// franja de la hora no corte el dibujo.
    var backdrop: AnyShapeStyle {
        switch self {
        case .planes: return AnyShapeStyle(Color(hex: 0x14355A))
        case .jump: return AnyShapeStyle(Color(hex: 0x0E3A4F))    // fondo del mar: el pulpo rosa destaca
        case .aliens, .bubbles, .leaks: return AnyShapeStyle(color.gradient.opacity(0.35))
        }
    }
    /// Icono de la portada: el protagonista de cada juego, dibujado.
    func drawIcon(in ctx: inout GraphicsContext, size: CGSize) {
        let c = CGPoint(x: size.width / 2, y: size.height / 2)
        switch self {
        case .jump: Octopus.draw(in: &ctx, feet: CGPoint(x: c.x, y: size.height - 1), size: size.height * 0.84)
        case .aliens: WatchAliens.drawAlien(in: &ctx, at: CGPoint(x: c.x, y: c.y + 2), size: size.height * 0.8, kind: 3, phase: 0)
        case .planes: WatchPlanes.drawPlane(in: &ctx, at: c, size: size.height * 0.9, body: Color(hex: 0xF2C14E), wing: Color(hex: 0xD99E2B))
        case .bubbles: WatchBubbles.drawBubble(in: &ctx, at: c, radius: size.height * 0.42, tier: 0)
        case .leaks: WatchLeaks.drawDrop(in: &ctx, at: CGPoint(x: c.x, y: c.y + 2), size: size.height * 0.42)
        }
    }
}

/// Partida en juego de cada tipo.
enum WatchPuzzle: Identifiable {
    case wordle(WordlePuzzle)
    case anygram(AnygramPuzzle)
    case maze(MazePuzzle)
    case decoder(DecoderGame)

    var id: String {
        switch self {
        case .wordle(let p): return p.id
        case .anygram(let p): return p.id
        case .maze(let p): return p.id
        case .decoder(let g): return g.id
        }
    }
}

@MainActor
final class WatchHub: ObservableObject {
    static let kinds: [PuzzleKind] = [.wordle, .anygram, .maze, .decoder]

    @Published private(set) var puzzles: [PuzzleKind: WatchPuzzle] = [:]
    @Published private(set) var preparing: Set<PuzzleKind> = []
    private(set) var language = AppLanguage.current
    private var loadedDay: Int?

    var offered: [PuzzleKind] { Self.kinds.filter { PuzzleKind.offered(in: language).contains($0) } }

    /// Carga (o recarga si cambió el día/idioma) los diarios. Lo lento (Anygram) va en segundo plano.
    func refreshIfNeeded() {
        let day = PuzzleSeed.dayIndex()
        let lang = AppLanguage.current
        guard loadedDay != day || lang != language else { return }
        loadedDay = day
        language = lang
        puzzles = [:]
        for kind in offered { loadDaily(kind, day: day) }
        AnygramPrefetch.ensureReady(language: lang, defaults: PuzzleProgress.shared.defaults)
    }

    private func loadDaily(_ kind: PuzzleKind, day: Int) {
        let lang = language
        let seed = PuzzleSeed.daily(kind: kind)
        let defaults = PuzzleProgress.shared.defaults
        switch kind {
        case .wordle:
            puzzles[kind] = .wordle(WordlePuzzle.daily(dayIndex: day, language: lang))
        case .maze:
            puzzles[kind] = .maze(Self.watchMaze(seed: seed))
        case .decoder:
            puzzles[kind] = .decoder(DecoderGame.make(seed: seed, spanish: lang == .spanish))
        case .anygram:
            if case .anygram(let p)? = PuzzleSnapshotStore.load(kind: kind, language: lang, day: day, defaults: defaults) {
                puzzles[kind] = .anygram(p)
                return
            }
            generate(kind) { AnygramPuzzle.generate(seed: seed, language: lang).map(WatchPuzzle.anygram) } store: { puzzle in
                // Igual que el iPhone: el diario se congela para que un cambio de listas no lo altere.
                if case .anygram(let p) = puzzle {
                    PuzzleSnapshotStore.save(.anygram(p), kind: kind, language: lang, day: day, defaults: defaults)
                }
            }
        default:
            break
        }
    }

    /// Partida nueva aleatoria del mismo tipo ("Jugar otro").
    func playAnother(_ kind: PuzzleKind) {
        let lang = language
        let seed = PuzzleSeed.random()
        switch kind {
        case .wordle:
            let recent = Set(PuzzleProgress.shared.recentWordleAnswers(language: lang))
            let puzzle = WordlePuzzle.generate(seed: seed, excluding: recent, language: lang)
            PuzzleProgress.shared.rememberWordleAnswer(puzzle.answer, language: lang)
            puzzles[kind] = .wordle(puzzle)
        case .maze:
            puzzles[kind] = .maze(Self.watchMaze(seed: seed))
        case .decoder:
            puzzles[kind] = .decoder(DecoderGame.make(seed: seed, spanish: lang == .spanish))
        case .anygram:
            if let ready = AnygramPrefetch.take(language: lang, defaults: PuzzleProgress.shared.defaults) {
                puzzles[kind] = .anygram(ready)
                AnygramPrefetch.ensureReady(language: lang, defaults: PuzzleProgress.shared.defaults)
            } else {
                generate(kind) { AnygramPuzzle.generate(seed: seed, language: lang).map(WatchPuzzle.anygram) }
            }
        default:
            break
        }
    }

    private func generate(_ kind: PuzzleKind, _ make: @escaping @Sendable () -> WatchPuzzle?,
                          store: ((WatchPuzzle) -> Void)? = nil) {
        guard !preparing.contains(kind) else { return }
        preparing.insert(kind)
        Task {
            let box = await Task.detached(priority: .userInitiated) { WatchPuzzleBox(make()) }.value
            preparing.remove(kind)
            guard let puzzle = box.value else { return }
            store?(puzzle)
            puzzles[kind] = puzzle
        }
    }

    /// Laberinto del reloj: 8×10 (el del iPhone es 12×16, ilegible en la muñeca). Id propio («w-»)
    /// para no confundirse nunca con el del iPhone.
    static func watchMaze(seed: UInt64) -> MazePuzzle {
        let m = MazePuzzle.generate(seed: seed, cols: 8, rows: 10)
        return MazePuzzle(id: "w-" + m.id, walls: m.walls, cols: m.cols, rows: m.rows,
                          entranceCol: m.entranceCol, exitCol: m.exitCol)
    }
}

/// `WatchPuzzle` lleva tipos Sendable; la caja solo sirve para cruzar del hilo de generación al principal.
private struct WatchPuzzleBox: @unchecked Sendable {
    let value: WatchPuzzle?
    init(_ value: WatchPuzzle?) { self.value = value }
}

struct WatchHomeView: View {
    @EnvironmentObject private var hub: WatchHub
    @ObservedObject private var progress = PuzzleProgress.shared
    @Environment(\.scenePhase) private var phase
    @State private var path = NavigationPath()
    @AppStorage(WatchJump.bestKey, store: PuzzleProgress.shared.defaults) private var jumpBest = 0
    @AppStorage(WatchAliens.info.bestKey, store: PuzzleProgress.shared.defaults) private var aliensBest = 0
    @AppStorage(WatchPlanes.info.bestKey, store: PuzzleProgress.shared.defaults) private var planesBest = 0
    @AppStorage(WatchBubbles.info.bestKey, store: PuzzleProgress.shared.defaults) private var bubblesBest = 0
    @AppStorage(WatchLeaks.info.bestKey, store: PuzzleProgress.shared.defaults) private var leaksBest = 0

    var body: some View {
        NavigationStack(path: $path) {
            List {
                ForEach(hub.offered) { kind in
                    NavigationLink(value: kind) { row(kind) }
                        .listRowBackground(WTheme.surface.clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous)))
                }
                ForEach(WatchArcade.allCases, id: \.self) { game in
                    NavigationLink(value: game) { arcadeRow(game) }
                        .listRowBackground(WTheme.surface.clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous)))
                }
            }
            .navigationTitle("Quizzy")
            .navigationDestination(for: PuzzleKind.self) { kind in
                WatchGameScreen(kind: kind)
            }
            .navigationDestination(for: WatchArcade.self) { game in
                Group {
                    switch game {
                    case .jump: WatchJumpView()
                    case .aliens: WatchAliensView()
                    case .planes: WatchPlanesView()
                    case .bubbles: WatchBubblesView()
                    case .leaks: WatchLeaksView()
                    }
                }
                .containerBackground(game.backdrop, for: .navigation)
            }
        }
        .onAppear {
            hub.refreshIfNeeded()
            #if DEBUG
            // Capturas en simulador sin tocar: QW_GAME=wordle|anygram|maze|decoder|jump|aliens|planes|bubbles|leaks abre ese juego.
            if path.isEmpty, let raw = ProcessInfo.processInfo.environment["QW_GAME"] {
                if let game = WatchArcade(rawValue: raw) { path.append(game) }
                else if let kind = PuzzleKind(rawValue: raw), hub.offered.contains(kind) { path.append(kind) }
            }
            #endif
        }
        .onChange(of: phase) { _, new in if new == .active { hub.refreshIfNeeded() } }
    }

    private func row(_ kind: PuzzleKind) -> some View {
        let puzzle = hub.puzzles[kind]
        let done = puzzle.map { progress.isDone($0.id) } ?? false
        return HStack(spacing: 8) {
            Image(systemName: kind.symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(WTheme.color(kind))
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 1) {
                Text(kind.title).font(.system(.body, design: .rounded).weight(.semibold))
                Text(status(kind, puzzle: puzzle, done: done))
                    .font(.caption2)
                    .foregroundStyle(done ? WTheme.success : WTheme.inkSecondary)
            }
            Spacer(minLength: 0)
            if done { Image(systemName: "checkmark.circle.fill").foregroundStyle(WTheme.success) }
        }
        .padding(.vertical, 2)
    }

    private func arcadeRow(_ game: WatchArcade) -> some View {
        let best: Int
        switch game {
        case .jump: best = jumpBest
        case .aliens: best = aliensBest
        case .planes: best = planesBest
        case .bubbles: best = bubblesBest
        case .leaks: best = leaksBest
        }
        return HStack(spacing: 8) {
            Canvas { ctx, size in game.drawIcon(in: &ctx, size: size) }
                .frame(width: 24, height: 24)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text(game.title).font(.system(.body, design: .rounded).weight(.semibold))
                Text(best > 0 ? AppLanguage.text("Récord: \(best)", "Best: \(best)") : game.blurb)
                    .font(.caption2).foregroundStyle(WTheme.inkSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
    }

    private func status(_ kind: PuzzleKind, puzzle: WatchPuzzle?, done: Bool) -> String {
        if puzzle == nil { return AppLanguage.text("Preparando…", "Preparing…") }
        if done { return AppLanguage.text("Hecho", "Done") }
        let spent = progress.elapsed(puzzle!.id)
        return spent > 5 ? AppLanguage.text("En curso · \(wTime(spent))", "In progress · \(wTime(spent))") : kind.blurb
    }
}

/// Pantalla de un juego: espera a que esté listo y pinta la vista del tipo.
struct WatchGameScreen: View {
    let kind: PuzzleKind
    @EnvironmentObject private var hub: WatchHub

    var body: some View {
        Group {
            if hub.preparing.contains(kind) || hub.puzzles[kind] == nil {
                VStack(spacing: 8) {
                    ProgressView()
                    Text(AppLanguage.text("Preparando \(kind.title)…", "Preparing \(kind.title)…"))
                        .font(.footnote).foregroundStyle(WTheme.inkSecondary)
                }
            } else if let puzzle = hub.puzzles[kind] {
                content(puzzle).id(puzzle.id)
            }
        }
        .containerBackground(WTheme.color(kind).gradient.opacity(0.35), for: .navigation)
    }

    @ViewBuilder private func content(_ puzzle: WatchPuzzle) -> some View {
        let another = { hub.playAnother(kind) }
        switch puzzle {
        case .wordle(let p): WatchPalabroView(puzzle: p, onAnother: another)
        case .anygram(let p): WatchAnygramView(puzzle: p, onAnother: another)
        case .maze(let p): WatchMazeView(puzzle: p, onAnother: another)
        case .decoder(let g): WatchDecoderView(seedGame: g, onAnother: another)
        }
    }
}

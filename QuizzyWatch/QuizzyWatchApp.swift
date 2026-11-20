//
//  QuizzyWatchApp.swift — Quizzy Watch
//  Portada del reloj: cinco juegos (Palabro, Anygram, Trocitos, Laberinto, Decoder).
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

/// Partida en juego de cada tipo.
enum WatchPuzzle: Identifiable {
    case wordle(WordlePuzzle)
    case anygram(AnygramPuzzle)
    case quartiles(QuartilePuzzle)
    case maze(MazePuzzle)
    case decoder(DecoderGame)

    var id: String {
        switch self {
        case .wordle(let p): return p.id
        case .anygram(let p): return p.id
        case .quartiles(let p): return p.id
        case .maze(let p): return p.id
        case .decoder(let g): return g.id
        }
    }
}

@MainActor
final class WatchHub: ObservableObject {
    static let kinds: [PuzzleKind] = [.wordle, .anygram, .quartiles, .maze, .decoder]

    @Published private(set) var puzzles: [PuzzleKind: WatchPuzzle] = [:]
    @Published private(set) var preparing: Set<PuzzleKind> = []
    private(set) var language = AppLanguage.current
    private var loadedDay: Int?

    var offered: [PuzzleKind] { Self.kinds.filter { PuzzleKind.offered(in: language).contains($0) } }

    /// Carga (o recarga si cambió el día/idioma) los diarios. Lo lento (Anygram, Trocitos) va en segundo plano.
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
        case .anygram, .quartiles:
            if let saved = PuzzleSnapshotStore.load(kind: kind, language: lang, day: day, defaults: defaults) {
                switch saved {
                case .anygram(let p): puzzles[kind] = .anygram(p)
                case .quartiles(let p): puzzles[kind] = .quartiles(p)
                default: break
                }
                return
            }
            generate(kind) { kind == .anygram
                ? AnygramPuzzle.generate(seed: seed, language: lang).map(WatchPuzzle.anygram)
                : ProceduralPuzzleGenerator.quartiles(seed: seed, language: lang).map(WatchPuzzle.quartiles)
            } store: { puzzle in
                // Igual que el iPhone: el diario se congela para que un cambio de listas no lo altere.
                switch puzzle {
                case .anygram(let p): PuzzleSnapshotStore.save(.anygram(p), kind: kind, language: lang, day: day, defaults: defaults)
                case .quartiles(let p): PuzzleSnapshotStore.save(.quartiles(p), kind: kind, language: lang, day: day, defaults: defaults)
                default: break
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
        case .quartiles:
            generate(kind) { ProceduralPuzzleGenerator.quartiles(seed: seed, language: lang).map(WatchPuzzle.quartiles) }
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
    @State private var path: [PuzzleKind] = []

    var body: some View {
        NavigationStack(path: $path) {
            List {
                ForEach(hub.offered) { kind in
                    NavigationLink(value: kind) { row(kind) }
                        .listRowBackground(WTheme.surface.clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous)))
                }
            }
            .navigationTitle("Quizzy")
            .navigationDestination(for: PuzzleKind.self) { kind in
                WatchGameScreen(kind: kind)
            }
        }
        .onAppear {
            hub.refreshIfNeeded()
            #if DEBUG
            // Capturas en simulador sin tocar: QW_GAME=wordle|anygram|quartiles|maze|decoder abre ese juego.
            if path.isEmpty, let raw = ProcessInfo.processInfo.environment["QW_GAME"], let kind = PuzzleKind(rawValue: raw) {
                path = [kind]
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
        case .quartiles(let p): WatchTrocitosView(puzzle: p, onAnother: another)
        case .maze(let p): WatchMazeView(puzzle: p, onAnother: another)
        case .decoder(let g): WatchDecoderView(seedGame: g, onAnother: another)
        }
    }
}

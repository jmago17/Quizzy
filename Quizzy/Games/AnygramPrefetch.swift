#if os(iOS) || os(watchOS)
import Foundation

// Anygram (español) tardaba ~10 s en generarse porque recalculaba el léxico entero en cada
// partida; desde 2026-11-15 el léxico se calcula una vez (`AnygramLexicon`) y cada puzzle tarda
// ~0,05–4 s (Mac, -O). Aun así se guarda y se deja preparado el siguiente, para que abrir la app
// y "Jugar otro" no esperen nunca:
//  · el diario de mañana (semilla determinista por fecha → idéntico en todos los dispositivos);
//  · un puzzle aleatorio listo para "Jugar otro" / "Generar otro".
// El inglés es una lista fija (instantáneo) y no pasa por aquí.

// `Character` no es Codable: las letras se guardan como String.
extension AnygramPuzzle: Codable {
    private enum CodingKeys: String, CodingKey { case id, letters, answers, boardRows, boardCols, entries }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(id: try c.decode(String.self, forKey: .id),
                  letters: Array(try c.decode(String.self, forKey: .letters)),
                  answers: try c.decode([String].self, forKey: .answers),
                  boardRows: try c.decode(Int.self, forKey: .boardRows),
                  boardCols: try c.decode(Int.self, forKey: .boardCols),
                  entries: try c.decode([Entry].self, forKey: .entries))
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(String(letters), forKey: .letters)
        try c.encode(answers, forKey: .answers)
        try c.encode(boardRows, forKey: .boardRows)
        try c.encode(boardCols, forKey: .boardCols)
        try c.encode(entries, forKey: .entries)
    }
}

/// Puzzle incluido en la app: se usa como "el de hoy" la primera vez que se abre (o el día en
/// que no hubo tiempo de precalcular), para que el juego esté disponible al instante.
enum AnygramDefault {
    static let puzzle: AnygramPuzzle? = {
        guard let data = json.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(AnygramPuzzle.self, from: data)
    }()
    static var id: String? { puzzle?.id }
}

enum AnygramPrefetch {
    private static func randomKey(_ language: PuzzleLanguage) -> String { "quizzy.anygram.prefetch.\(language.rawValue)" }

    /// Entrega el puzzle aleatorio ya preparado (y lo consume), o nil si no hay.
    static func take(language: PuzzleLanguage, defaults: UserDefaults) -> AnygramPuzzle? {
        let key = randomKey(language)
        guard let data = defaults.data(forKey: key) else { return nil }
        defaults.removeObject(forKey: key)
        return try? JSONDecoder().decode(AnygramPuzzle.self, from: data)
    }

    /// Prepara, en segundo plano y de uno en uno, el diario de mañana y un aleatorio de reserva.
    /// Es idempotente: si ya están guardados no hace nada, y solo hay una pasada a la vez.
    static func ensureReady(language: PuzzleLanguage, defaults: UserDefaults) {
        guard language == .spanish, runner.begin() else { return }
        // UserDefaults es seguro entre hilos (documentado), aunque no esté marcado Sendable.
        nonisolated(unsafe) let defaults = defaults
        Task.detached(priority: .utility) {
            defer { runner.end() }
            prepareTomorrow(language: language, defaults: defaults)
            prepareRandom(language: language, defaults: defaults)
        }
    }

    private static func prepareTomorrow(language: PuzzleLanguage, defaults: UserDefaults) {
        guard let tomorrow = Calendar(identifier: .gregorian).date(byAdding: .day, value: 1, to: .now) else { return }
        let day = PuzzleSeed.dayIndex(date: tomorrow)
        guard PuzzleSnapshotStore.load(kind: .anygram, language: language, day: day, defaults: defaults) == nil else { return }
        let seed = PuzzleSeed.daily(kind: .anygram, date: tomorrow)
        guard let puzzle = AnygramPuzzle.generate(seed: seed, language: language) else { return }
        PuzzleSnapshotStore.save(.anygram(puzzle), kind: .anygram, language: language, day: day, defaults: defaults)
    }

    private static func prepareRandom(language: PuzzleLanguage, defaults: UserDefaults) {
        let key = randomKey(language)
        guard defaults.data(forKey: key) == nil,
              let puzzle = AnygramPuzzle.generate(seed: PuzzleSeed.random(), language: language),
              let data = try? JSONEncoder().encode(puzzle) else { return }
        defaults.set(data, forKey: key)
    }

    private static let runner = Runner()
    private final class Runner: @unchecked Sendable {
        private let lock = NSLock()
        private var running = false
        func begin() -> Bool { lock.lock(); defer { lock.unlock() }; if running { return false }; running = true; return true }
        func end() { lock.lock(); running = false; lock.unlock() }
    }
}
#endif

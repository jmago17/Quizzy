#if os(iOS)
import Foundation

/// Freeze generated word grids, rather than reconstructing them over saved fills.
/// This is additive: the historical progress dictionary and Spanish IDs are untouched.
enum PuzzleSnapshotStore {
    private static let key = "newsraider.puzzleSnapshots.v1"
    enum Grid: Codable, Sendable {
        case quartiles(QuartilePuzzle)
        case wordSearch(WordSearchPuzzle)
        case crossword(CrosswordPuzzle)
    }

    static func slot(kind: PuzzleKind, language: PuzzleLanguage, day: Int) -> String {
        "\(day)|\(language.rawValue)|\(kind.rawValue)"
    }

    static func load(kind: PuzzleKind, language: PuzzleLanguage, day: Int,
                     defaults: UserDefaults) -> Grid? {
        let data = (defaults.dictionary(forKey: key) as? [String: Data])?[slot(kind: kind, language: language, day: day)]
        return data.flatMap { try? JSONDecoder().decode(Grid.self, from: $0) }
    }

    static func save(_ grid: Grid, kind: PuzzleKind, language: PuzzleLanguage, day: Int,
                     defaults: UserDefaults) {
        guard let data = try? JSONEncoder().encode(grid) else { return }
        var records = defaults.dictionary(forKey: key) as? [String: Data] ?? [:]
        records[slot(kind: kind, language: language, day: day)] = data
        // Keep recent daily grids. This never deletes historical fills or timings.
        records = records.filter { record in
            guard let prefix = record.key.split(separator: "|").first,
                  let storedDay = Int(prefix) else { return false }
            return storedDay >= day - 30
        }
        defaults.set(records, forKey: key)
    }
}
#endif

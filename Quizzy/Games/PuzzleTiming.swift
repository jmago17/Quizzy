#if os(iOS) || os(watchOS)
//
//  PuzzleTiming.swift — News Raider
//  Completion benchmarks and human-readable comparison copy.
//

import Foundation

enum PuzzleTiming {
    /// Initial benchmark until the player has at least three personal samples.
    static func reference(kind: PuzzleKind, itemCount: Int, boardSize: Int = 0) -> TimeInterval {
        switch kind {
        case .quartiles:
            // Five quartiles plus optional shorter words.
            return 7 * 60
        case .wordsearch:
            // About 24 seconds per word, adjusted slightly for board size.
            return Double(itemCount) * 24 + Double(max(0, boardSize - 10)) * 18
        case .crossword:
            // Natural clues: around 32 seconds per answer.
            return Double(itemCount) * 32
        case .maze:
            return max(90, Double(itemCount) * 0.9)
        case .wordle:
            return 4 * 60
        case .trivia:
            return 60
        case .numbers:
            return 3 * 60
        case .anygram:
            return 4 * 60
        case .hashtag:
            return 3 * 60
        case .minicross:
            return 5 * 60
        case .murdle:
            return 8 * 60
        case .murdoku:
            return 10 * 60
        case .decoder:
            return 3 * 60
        case .ladder:
            return max(45, Double(itemCount) * 25)
        }
    }

    @MainActor
    static func average(kind: PuzzleKind, itemCount: Int, boardSize: Int = 0) -> (seconds: TimeInterval, personal: Bool) {
        if let personal = PuzzleProgress.shared.personalAverage(kind) {
            return (personal, true)
        }
        return (reference(kind: kind, itemCount: itemCount, boardSize: boardSize), false)
    }

    static func clock(_ seconds: TimeInterval) -> String {
        let value = max(0, Int(seconds.rounded()))
        return String(format: "%d:%02d", value / 60, value % 60)
    }

    static func comparison(elapsed: TimeInterval, average: TimeInterval, personal: Bool,
                           kind: PuzzleKind? = nil) -> String {
        let delta = Int(abs(elapsed - average).rounded())
        let suffix = kind.map { AppLanguage.text(" en \($0.title)", " in \($0.title)") } ?? ""
        let source = personal ? AppLanguage.text("tu media\(suffix)", "your average\(suffix)") : AppLanguage.text("la media estimada\(suffix)", "the estimated average\(suffix)")
        if delta < 5 { return AppLanguage.text("Prácticamente igual que \(source)", "About the same as \(source)") }
        let amount: String
        if delta >= 60 {
            let mins = delta / 60, secs = delta % 60
            amount = secs == 0 ? "\(mins) min" : "\(mins):\(String(format: "%02d", secs))"
        } else {
            amount = "\(delta) s"
        }
        return elapsed < average
            ? AppLanguage.text("\(amount) por debajo de \(source)", "\(amount) faster than \(source)")
            : AppLanguage.text("\(amount) por encima de \(source)", "\(amount) slower than \(source)")
    }
}
#endif

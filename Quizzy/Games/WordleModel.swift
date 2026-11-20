#if os(iOS) || os(watchOS)
//
//  WordleModel.swift — Palabro sin UI (compartido por iPhone y Watch).
//  Movido tal cual desde WordleGame.swift el 2026-11-20; solo se añade `evaluate`.
//

import Foundation

struct WordlePuzzle: Identifiable, Sendable, Hashable {
    let id: String
    let answer: String

    /// Curated answers, with a stable fallback that never reaches into the
    /// broad validation dictionary — that fallback is what produced FRANI.
    private static func bank(language: PuzzleLanguage) -> [String] {
        if language == .english { return EnglishPuzzleLexicon.answers }
        return PuzzleLexicon.wordleAnswers.isEmpty
            ? PuzzleLexicon.commonWords.filter { $0.count == 5 && $0.allSatisfy(\.isLetter) }
            : PuzzleLexicon.wordleAnswers
    }

    /// Daily answers walk a fixed permutation of the whole bank instead of
    /// picking at random, so every word is used exactly once before any
    /// repeats — with ~1,070 answers that's about three years of dailies.
    static func daily(dayIndex: Int, language: PuzzleLanguage = .spanish) -> WordlePuzzle {
        let words = bank(language: language)
        guard !words.isEmpty else { return .init(id: "\(language == .english ? "en-" : "")d-day-\(dayIndex)", answer: "RADIO") }
        let cycle = dayIndex / words.count            // reshuffle each full pass
        let position = ((dayIndex % words.count) + words.count) % words.count
        var rng = SeededGenerator(seed: 0x5EED &+ UInt64(bitPattern: Int64(cycle)))
        let order = rng.shuffled(words)
        return .init(id: "\(language == .english ? "en-" : "")d-day-\(dayIndex)", answer: order[position])
    }

    static func generate(seed: UInt64, excluding excluded: Set<String> = [], language: PuzzleLanguage = .spanish) -> WordlePuzzle {
        var rng = SeededGenerator(seed: seed)
        let allWords = bank(language: language)
        let freshWords = allWords.filter { !excluded.contains($0) }
        let words = freshWords.isEmpty ? allWords : freshWords
        let answer = words.isEmpty ? "RADIO" : words[rng.int(words.count)]
        return .init(id: "\(language == .english ? "en-" : "")d-gen-\(seed)", answer: answer)
    }
}

enum LetterResult: Int, Comparable {
    case absent = 0, present = 1, correct = 2
    static func < (a: Self, b: Self) -> Bool { a.rawValue < b.rawValue }
}

enum WordleOutcome: Identifiable, Equatable {
    case won(attempts: Int)
    case lost(answer: String)
    var id: String {
        switch self {
        case .won(let a):  return "won-\(a)"
        case .lost(let w): return "lost-\(w)"
        }
    }
    var isWin: Bool { if case .won = self { return true }; return false }
    var attempts: Int { if case .won(let a) = self { return a }; return 6 }
}

extension WordlePuzzle {
    /// Misma regla que `WordleGame.evaluate` (verdes primero, después amarillas con multiplicidad).
    static func evaluate(_ guess: String, answer: String) -> [LetterResult] {
        let g = Array(guess), a = Array(answer)
        guard g.count == a.count else { return Array(repeating: .absent, count: a.count) }
        var out = Array(repeating: LetterResult.absent, count: a.count)
        var remaining: [Character: Int] = [:]
        for i in a.indices {
            if g[i] == a[i] { out[i] = .correct } else { remaining[a[i], default: 0] += 1 }
        }
        for i in a.indices where out[i] != .correct {
            if remaining[g[i], default: 0] > 0 { out[i] = .present; remaining[g[i]]! -= 1 }
        }
        return out
    }
}
#endif

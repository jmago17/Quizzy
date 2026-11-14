import Foundation

// Copiado de Kaffa Shared/AppLanguage.swift (944663d) sin FeatureFlags.

enum PuzzleLanguage: String, CaseIterable, Sendable {
    case spanish = "es"
    case english = "en"

    static func from(puzzleID: String) -> PuzzleLanguage { puzzleID.hasPrefix("en-") ? .english : .spanish }

    var locale: Locale { Locale(identifier: rawValue) }
}

/// Device-local preference. Never writes AppleLanguages or changes system settings.
enum AppLanguage {
    static let storageKey = "appLanguage"

    static func resolve(_ selection: String?, preferredLanguages: [String] = Locale.preferredLanguages) -> PuzzleLanguage {
        if let selection, let language = PuzzleLanguage(rawValue: selection) { return language }
        for identifier in preferredLanguages {
            let code = identifier.lowercased().split(whereSeparator: { $0 == "-" || $0 == "_" }).first
            if code == "es" { return .spanish }
            if code == "en" { return .english }
        }
        return .english
    }

    static func selected(in defaults: UserDefaults = .standard) -> String {
        let value = defaults.string(forKey: storageKey) ?? "system"
        return ["system", "es", "en"].contains(value) ? value : "system"
    }

    static func setSelection(_ selection: String, in defaults: UserDefaults = .standard) {
        defaults.set(["system", "es", "en"].contains(selection) ? selection : "system", forKey: storageKey)
    }

    static var current: PuzzleLanguage { resolve(selected()) }

    static func text(_ spanish: String, _ english: String, language: PuzzleLanguage? = nil) -> String {
        (language ?? current) == .spanish ? spanish : english
    }
}

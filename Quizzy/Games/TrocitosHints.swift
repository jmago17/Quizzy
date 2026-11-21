//
//  TrocitosHints.swift — Quizzy
//  Ayuda de color de Trocitos (2026-11-21). Foundation pura: la comprueba `Tests/Trocitos/run.py`.
//
//  Cada joya (palabra de 4 fichas) tiene un color. Las fichas empiezan sin color. Cada
//  `wordsPerHint` palabras que NO son joya se colorea una ficha de la primera joya pendiente;
//  la primera ayuda de cada joya colorea DOS (una sola ficha de un color no dice nada).
//  Así, completar el color de una joya cuesta 3 ayudas = 9 palabras cortas.
//
//  No se guarda nada: se deriva de las palabras encontradas. Consecuencia buscada: si el jugador
//  encuentra por su cuenta la joya que se estaba coloreando, esas ayudas pasan a la siguiente
//  (no se pierden), y al reabrir la partida sale exactamente lo mismo.
//

import Foundation

enum TrocitosHints {
    static let wordsPerHint = 3

    /// Palabras encontradas que cuentan para la ayuda (todas menos las joyas).
    static func shortWords(found: [String], targets: [String]) -> Int {
        found.filter { !targets.contains($0) }.count
    }

    /// Fichas (índices) que deletrean `word`, sin usar las de `excluding`. Con vuelta atrás:
    /// si un fragmento es prefijo de otro («CO» / «CON»), el primer encaje puede no ser el bueno.
    static func tiles(for word: String, in tiles: [String], excluding: Set<Int> = []) -> [Int]? {
        func solve(_ rest: Substring, _ used: [Int]) -> [Int]? {
            if rest.isEmpty { return used }
            for (i, fragment) in tiles.enumerated()
            where !excluding.contains(i) && !used.contains(i) && !fragment.isEmpty && rest.hasPrefix(fragment) {
                if let done = solve(rest.dropFirst(fragment.count), used + [i]) { return done }
            }
            return nil
        }
        return solve(Substring(word), [])
    }

    /// Ficha → índice de joya (= color) que se muestra ahora mismo.
    /// Joyas encontradas: sus 4 fichas. Joyas pendientes: las que hayan ganado las ayudas, en orden de palabra.
    static func colorGroups(tiles: [String], targets: [String], found: [String]) -> [Int: Int] {
        // Reparto de fichas entre joyas sin repetir ficha (cada joya usa 4 distintas).
        var owner: [[Int]] = []
        var taken = Set<Int>()
        for target in targets {
            let mine = Self.tiles(for: target, in: tiles, excluding: taken) ?? Self.tiles(for: target, in: tiles) ?? []
            owner.append(mine)
            taken.formUnion(mine)
        }
        var groups: [Int: Int] = [:]
        var hints = shortWords(found: found, targets: targets) / wordsPerHint
        for (gem, target) in targets.enumerated() {
            if found.contains(target) {
                for tile in owner[gem] { groups[tile] = gem }
            } else if hints > 0 {
                let shown = min(owner[gem].count, hints + 1)   // 1 ayuda → 2 fichas, 2 → 3, 3 → 4
                for tile in owner[gem].prefix(shown) { groups[tile] = gem }
                hints -= max(1, shown - 1)
            }
        }
        return groups
    }
}

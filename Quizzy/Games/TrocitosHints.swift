//
//  TrocitosHints.swift — Quizzy
//  Ayuda de color de Trocitos (2026-11-21). Foundation pura: la comprueba `Tests/Trocitos/run.py`.
//
//  Cada joya (palabra de 4 fichas) tiene un color. Las fichas empiezan sin color. Una ayuda
//  colorea DOS fichas de la primera joya pendiente que aún no tenga pareja, y ahí se queda:
//  una joya pendiente nunca enseña más de 2 de sus 4 fichas, y esas dos van SEGUIDAS en la
//  palabra (1.ª+2.ª o 3.ª+4.ª). La ayuda dice «estas dos van juntas», no resuelve la joya.
//  (Hasta el 2026-11-22 eran salteadas, 1.ª+3.ª o 2.ª+4.ª: Josu lo probó y despistaba mucho,
//  porque dos fichas del mismo color se leen como «van pegadas».)
//
//  Dosificación (2026-11-21, 2.ª versión). La 1.ª daba una ficha cada 3 palabras sin tope y era
//  demasiado fácil: medido sobre los 12 puzles, hay entre 93 y 240 palabras cortas por tablero,
//  así que con 9 se regalaba una joya entera y con 45 las cinco. Ahora cada ayuda cuesta más que
//  la anterior (`costs`: 3, 4, 5, 6, 7 → acumulado 3, 7, 12, 18, 25) y como mucho hay una por joya.
//
//  No se guarda nada: se deriva de las palabras encontradas. Consecuencia buscada: si el jugador
//  encuentra por su cuenta la joya que tenía pareja, esa ayuda pasa a la siguiente pendiente
//  (no se pierde), y al reabrir la partida sale exactamente lo mismo.
//

import Foundation

enum TrocitosHints {
    /// Palabras cortas que cuesta cada ayuda, en orden. Su número es el máximo de ayudas.
    static let costs = [3, 4, 5, 6, 7]

    /// Ayudas ganadas con `words` palabras cortas, y avance hacia la siguiente (nil si no hay más).
    static func earned(words: Int) -> (hints: Int, next: (have: Int, need: Int)?) {
        var left = words
        for (i, cost) in costs.enumerated() {
            if left < cost { return (i, (left, cost)) }
            left -= cost
        }
        return (costs.count, nil)
    }

    /// Avance hacia la próxima ayuda ÚTIL: nil si ya no queda joya pendiente sin pareja.
    static func progress(found: [String], targets: [String]) -> (have: Int, need: Int)? {
        let state = earned(words: shortWords(found: found, targets: targets))
        let pending = targets.filter { !found.contains($0) }.count
        return state.hints < pending ? state.next : nil
    }

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
    /// Joyas encontradas: sus 4 fichas. Joyas pendientes: una pareja por ayuda ganada, en orden de joya.
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
        var hints = earned(words: shortWords(found: found, targets: targets)).hints
        for (gem, target) in targets.enumerated() {
            if found.contains(target) {
                for tile in owner[gem] { groups[tile] = gem }
            } else if hints > 0 {
                hints -= 1
                let mine = owner[gem]
                // Pareja seguida en la palabra, alternando por joya: el principio o el final.
                let pair = mine.count >= 4 ? (gem % 2 == 0 ? [mine[0], mine[1]] : [mine[2], mine[3]]) : Array(mine.prefix(2))
                for tile in pair { groups[tile] = gem }
            }
        }
        return groups
    }
}

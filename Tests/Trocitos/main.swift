// Comprobaciones ejecutables de Quizzy/Games/TrocitosHints.swift (Foundation pura).
nonisolated(unsafe) var failures = 0
nonisolated(unsafe) var checks = 0
func check(_ ok: @autoclosure () -> Bool, _ name: String, line: Int = #line) {
    checks += 1
    if !ok() { failures += 1; print("FAIL [\(line)] \(name)") }
}

@main struct Runner {
    static func main() {
        // 5 joyas de 4 fichas; fichas barajadas. «CO»/«CON» obliga a la vuelta atrás.
        let gems = [["CON", "TRA", "TIEM", "PO"], ["CO", "CI", "NE", "RO"], ["MA", "RI", "PO2", "SA"],
                    ["BI", "BLIO", "TE", "CA"], ["FE", "RRO", "CA2", "RRIL"]]
        let targets = gems.map { $0.joined() }
        var tiles = gems.flatMap { $0 }
        tiles.swapAt(0, 4); tiles.swapAt(3, 17); tiles.swapAt(9, 12)   // CO queda antes que CON
        func groups(_ found: [String]) -> [Int: Int] { TrocitosHints.colorGroups(tiles: tiles, targets: targets, found: found) }
        func shown(_ g: [Int: Int], _ gem: Int) -> [String] { g.filter { $0.value == gem }.keys.sorted().map { tiles[$0] } }

        check(TrocitosHints.tiles(for: targets[0], in: tiles)?.map { tiles[$0] } == gems[0], "vuelta atrás: CON no se confunde con CO")
        check(TrocitosHints.tiles(for: "NOEXISTE", in: tiles) == nil, "palabra imposible → nil")

        let many = (1...40).map { "W\($0)" }
        func first(_ n: Int) -> [String] { Array(many.prefix(n)) }

        // Coste creciente: 3, 4, 5, 6, 7 → ayudas a las 3, 7, 12, 18 y 25 palabras cortas.
        check([0, 2, 3, 6, 7, 11, 12, 17, 18, 24, 25, 40].map { TrocitosHints.earned(words: $0).hints } == [0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5], "umbrales de ayuda")
        check(TrocitosHints.earned(words: 5).next! == (2, 4), "tras la 1.ª ayuda el contador va sobre 4")
        check(TrocitosHints.earned(words: 25).next == nil, "5 ayudas es el tope")

        check(groups([]).isEmpty, "empieza sin colores")
        check(groups(first(2)).isEmpty, "2 palabras cortas: aún nada")
        let g1 = groups(first(3))
        check(g1.count == 2 && Set(shown(g1, 0)) == Set(["CON", "TRA"]), "3 palabras → pareja seguida de la 1.ª joya (1.ª y 2.ª ficha)")
        check(groups(first(6)) == g1, "de 4 a 6 palabras no añade nada")
        let g2 = groups(first(7))
        check(g2.count == 4 && Set(shown(g2, 1)) == Set(["NE", "RO"]), "7 palabras → pareja de la 2.ª joya (3.ª y 4.ª ficha)")
        check(Set(shown(g2, 0)) == Set(["CON", "TRA"]), "la 1.ª joya sigue con solo 2 fichas")
        // Tope: una pareja por joya, nunca más de media joya pendiente.
        let top = groups(many)
        check(top.count == 10 && (0..<5).allSatisfy { g in top.values.filter { $0 == g }.count == 2 }, "40 palabras → 10 fichas, 2 por joya, ninguna joya resuelta")
        check(TrocitosHints.progress(found: many, targets: targets) == nil, "sin más ayudas, el contador desaparece")

        // Las joyas no cuentan como palabra corta, y encontrarlas colorea sus 4 fichas.
        let f1 = groups([targets[2]])
        check(f1.count == 4 && Set(shown(f1, 2)) == Set(gems[2]), "joya encontrada → sus 4 fichas con su color")
        check(groups([targets[2], targets[3], targets[4]]).count == 12, "3 joyas no dan ayuda (no son palabras cortas)")
        // Si el jugador encuentra la joya que tenía pareja, la ayuda pasa a la siguiente pendiente.
        let moved = groups(first(3) + [targets[0]])
        check(moved.count == 6 && Set(shown(moved, 1)) == Set(["NE", "RO"]), "la ayuda no se pierde: pasa a la siguiente joya")
        // El contador solo se enseña si la próxima ayuda sirve para algo.
        check(TrocitosHints.progress(found: first(3), targets: targets)! == (0, 4), "contador tras la 1.ª ayuda: 0/4")
        check(TrocitosHints.progress(found: first(7) + [targets[2], targets[3], targets[4]], targets: targets) == nil,
              "2 ayudas y 2 joyas pendientes: ya tienen pareja las dos, sin contador")
        check(TrocitosHints.progress(found: targets, targets: targets) == nil, "todo encontrado: sin contador")
        let all = groups(targets + many)
        check(all.count == 20 && (0..<5).allSatisfy { g in all.values.filter { $0 == g }.count == 4 }, "final: 5 grupos de 4")

        print(failures == 0 ? "PASS Trocitos hints: \(checks) checks" : "FAILED \(failures) of \(checks) checks")
        if failures > 0 { exit(1) }
    }
}

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
        let short = (1...12).map { "W\($0)" }   // palabras cortas cualesquiera (no son joyas)

        check(TrocitosHints.tiles(for: targets[0], in: tiles)?.map { tiles[$0] } == gems[0], "vuelta atrás: CON no se confunde con CO")
        check(TrocitosHints.tiles(for: "NOEXISTE", in: tiles) == nil, "palabra imposible → nil")

        check(groups([]).isEmpty, "empieza sin colores")
        check(groups(Array(short.prefix(2))).isEmpty, "2 palabras cortas: aún nada")
        let g1 = groups(Array(short.prefix(3)))
        check(g1.count == 2 && Set(shown(g1, 0)) == Set(["CON", "TRA"]), "3 palabras → 2 fichas de la 1.ª joya, en orden de palabra")
        check(groups(Array(short.prefix(5))) == g1, "4 y 5 palabras no añaden nada")
        check(groups(Array(short.prefix(6))).count == 3, "6 palabras → 3 fichas")
        let g3 = groups(Array(short.prefix(9)))
        check(g3.count == 4 && Set(shown(g3, 0)) == Set(gems[0]), "9 palabras → la 1.ª joya entera")
        let g4 = groups(short)
        check(g4.count == 6 && Set(shown(g4, 1)) == Set(["CO", "CI"]), "12 palabras → empieza la 2.ª joya con 2 fichas")

        // Las joyas no cuentan como palabra corta, y encontrarlas colorea sus 4 fichas.
        let f1 = groups([targets[2]])
        check(f1.count == 4 && Set(shown(f1, 2)) == Set(gems[2]), "joya encontrada → sus 4 fichas con su color")
        check(groups([targets[2], targets[3], targets[4]]).count == 12, "3 joyas no dan ayuda (no son palabras cortas)")
        // Si el jugador encuentra la joya que se coloreaba, la ayuda pasa a la siguiente pendiente.
        let moved = groups(Array(short.prefix(3)) + [targets[0]])
        check(moved.count == 6 && Set(shown(moved, 1)) == Set(["CO", "CI"]), "la ayuda no se pierde: pasa a la siguiente joya")
        // Todo encontrado: 20 fichas, 5 colores, 4 de cada uno, sin sobrantes aunque haya muchas ayudas.
        let all = groups(targets + short)
        check(all.count == 20 && (0..<5).allSatisfy { g in all.values.filter { $0 == g }.count == 4 }, "final: 5 grupos de 4")
        // Nunca se repite ficha entre joyas.
        check(Set(groups(short + short.map { $0 + "b" } + short.map { $0 + "c" } + short.map { $0 + "d" } + short.map { $0 + "e" }).keys).count == 20,
              "con ayudas de sobra se colorean las 20 fichas")

        print(failures == 0 ? "PASS Trocitos hints: \(checks) checks" : "FAILED \(failures) of \(checks) checks")
        if failures > 0 { exit(1) }
    }
}

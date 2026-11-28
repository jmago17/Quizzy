//
//  WatchDriftView.swift — Quizzy Watch
//  Derrape: la Corona es el VOLANTE, no la posición. Centrada (como empieza) el coche va recto;
//  girarla lo inclina hasta 40° a cada lado y el coche avanza EXACTAMENTE hacia donde apunta el
//  morro (vx = v·tan(ángulo)): coche paralelo al arcén = sigue la curva (ajustado con Josu el
//  2026-11-23; NO tocar esa física sin motivo). La pendiente de la carretera está acotada
//  (`maxSlope`) para que siempre haya volante de sobra.
//
//  Desde el 2026-11-28 (a Josu le parecía «un poco meh»: solo había que no chocar) hay algo que
//  buscar además de sobrevivir:
//  - ETAPAS de `stageLen` con meta de cuadros; cada una cambia el paisaje (campo, desierto, nieve,
//    noche con faros) y devuelve una vida.
//  - MONEDAS en hilera que marcan una trazada; la hilera entera sube el multiplicador (×1…×5), que
//    se pierde al chocar o al pisar una mancha (aceite/hielo).
//  - ADELANTAR ROZANDO da más puntos que adelantar lejos.
//  - TURBO: unos segundos más rápido y llevándose por delante coches y conos (el arcén sigue matando).
//  - Tráfico variado (coche, camión, furgoneta que cambia de carril con intermitente) y OBRAS (conos
//    que cierran medio carril).
//  Lo que mata (coches y conos) nunca coincide: se reparten por «punto de encuentro» con el jugador
//  (`meetOK`), para que siempre haya hueco y tiempo de cambiar de lado.
//  Puntos: distancia + lo anterior. Dibujos propios. Bucle y pantallas: `WatchArcadeStage`.
//

import SwiftUI

enum WatchDrift {
    static var info: ArcadeInfo {
        ArcadeInfo(id: "drift", title: AppLanguage.text("Derrape", "Drift"),
                   hint: AppLanguage.text("La Corona es el volante", "The Crown steers"), color: Color(hex: 0xF0766B))
    }
    static let grass = Color(hex: 0x24573A)

    /// Camión visto desde arriba: cabina delante (arriba) y caja.
    static func drawTruck(in ctx: inout GraphicsContext, at centre: CGPoint, angle: CGFloat, body: Color) {
        var ctx = ctx
        ctx.translateBy(x: centre.x, y: centre.y)
        ctx.rotate(by: .radians(Double(angle)))
        let c = CGPoint.zero
        let w: CGFloat = 13, h: CGFloat = 34
        for y in [-h * 0.3, h * 0.12, h * 0.36] as [CGFloat] {
            ctx.fill(Path(roundedRect: CGRect(x: c.x - w / 2 - 1.2, y: c.y + y - 3, width: w + 2.4, height: 6), cornerRadius: 1), with: .color(Color(hex: 0x14161B)))
        }
        ctx.fill(Path(roundedRect: CGRect(x: c.x - w / 2, y: c.y - h / 2 + 9, width: w, height: h - 9), cornerRadius: 2), with: .color(Color(hex: 0xD9DDE4)))
        ctx.fill(Path(CGRect(x: c.x - w / 2, y: c.y - h / 2 + 16, width: w, height: 2)), with: .color(body.opacity(0.9)))
        ctx.fill(Path(roundedRect: CGRect(x: c.x - w / 2 + 0.5, y: c.y - h / 2, width: w - 1, height: 8.5), cornerRadius: 2.5), with: .color(body))
        ctx.fill(Path(roundedRect: CGRect(x: c.x - w / 2 + 2, y: c.y - h / 2 + 1.5, width: w - 4, height: 3), cornerRadius: 1), with: .color(Color(hex: 0x1D2B3A)))
    }

    /// Coche visto desde arriba, mirando hacia arriba; `angle` lo gira (positivo = a la derecha).
    static func drawCar(in ctx: inout GraphicsContext, at c: CGPoint, size s: CGFloat, angle: CGFloat, body: Color) {
        var g = ctx
        g.translateBy(x: c.x, y: c.y)
        g.rotate(by: .radians(Double(angle)))
        let w = s * 0.52, h = s
        for (x, y) in [(-w / 2, -h * 0.32), (w / 2, -h * 0.32), (-w / 2, h * 0.28), (w / 2, h * 0.28)] as [(CGFloat, CGFloat)] {
            g.fill(Path(roundedRect: CGRect(x: x - s * 0.07, y: y - s * 0.11, width: s * 0.14, height: s * 0.22), cornerRadius: 1), with: .color(Color(hex: 0x14161B)))
        }
        g.fill(Path(roundedRect: CGRect(x: -w / 2, y: -h / 2, width: w, height: h), cornerRadius: s * 0.16), with: .color(body))
        g.fill(Path(roundedRect: CGRect(x: -w * 0.36, y: -h * 0.22, width: w * 0.72, height: h * 0.2), cornerRadius: 1.5), with: .color(Color(hex: 0x1D2B3A)))
        g.fill(Path(roundedRect: CGRect(x: -w * 0.32, y: h * 0.2, width: w * 0.64, height: h * 0.12), cornerRadius: 1.5), with: .color(Color(hex: 0x1D2B3A).opacity(0.8)))
        g.fill(Path(CGRect(x: -w * 0.08, y: -h / 2, width: w * 0.16, height: h)), with: .color(.white.opacity(0.35)))
    }
}

final class DriftWorld: ArcadeWorld {
    enum Theme: Int, CaseIterable {
        case meadow, desert, snow, night
        var ground: Color { [Color(hex: 0x24573A), Color(hex: 0xC9A46A), Color(hex: 0xD5E0EA), Color(hex: 0x0F1826)][rawValue] }
        var road: Color { [Color(hex: 0x3A3F4B), Color(hex: 0x4C4640), Color(hex: 0x566170), Color(hex: 0x262A33)][rawValue] }
        var speck: Color { [Color.black.opacity(0.14), Color(hex: 0x8A6A3A).opacity(0.35), Color(hex: 0x8FA6BC).opacity(0.45), Color.white.opacity(0.05)][rawValue] }
    }
    enum RivalKind { case car, truck, changer }
    struct Rival {
        var d: CGFloat; var off: CGFloat; var color: Color
        var kind = RivalKind.car
        var target: CGFloat = 0           // solo `.changer`: a qué lado se va
        var moving = false
        var passed = false
        var halfLen: CGFloat { kind == .truck ? 17 : 10 }
    }
    struct Coin { var d: CGFloat; var off: CGFloat; var group: Int }
    struct Spot { var d: CGFloat; var off: CGFloat }
    struct Popup { var p: CGPoint; var text: String; var color: Color; var life: CGFloat = 1 }

    static let maxSteer: CGFloat = 0.70       // radianes a tope de Corona (40°; tan = 0,84)
    static let maxSlope: CGFloat = 0.5        // desvío lateral máximo de la carretera por punto de avance (27°)
    static let carSize: CGFloat = 20
    static let stageLen: CGFloat = 4000
    static let turboTime: CGFloat = 3.5
    static let gold = Color(hex: 0xF2C14E)

    private var size: CGSize = .zero
    private var x: CGFloat = 0
    private var d: CGFloat = 0                // distancia recorrida
    private var heading: CGFloat = 0
    private var time: CGFloat = 0
    private var lives = 3
    private var invuln: CGFloat = 0
    private var turbo: CGFloat = 0
    private var spin: CGFloat = 0             // segundos de trompo (solo dibujo) tras una mancha
    private var mult = 1
    private var rivals: [Rival] = []
    private var coins: [Coin] = []
    private var groupLeft: [Int: Int] = [:]   // monedas que quedan por coger de cada hilera intacta
    private var nextGroup = 0
    private var cones: [Spot] = []
    private var slicks: [Spot] = []
    private var tokens: [Spot] = []
    private var skids: [Spot] = []            // `off` = x de pantalla
    private var popups: [Popup] = []
    private var nextAt: CGFloat = 260
    private var lastToken: CGFloat = 0
    private var bonus = 0
    private var sparks: [Spark] = []
    private(set) var score = 0
    // Para los tests.
    private(set) var crashes = 0, edgeCrashes = 0, coinsTaken = 0, nearMisses = 0, turbos = 0
    private(set) var causes: [String: Int] = [:]
    var stageIndex: Int { stage(d) }
    #if DEBUG
    private let god = ProcessInfo.processInfo.environment["QW_GOD"] == "1"
    private let startStage = Int(ProcessInfo.processInfo.environment["QW_STAGE"] ?? "") ?? 0
    #else
    private let god = false
    private let startStage = 0
    #endif

    private var carY: CGFloat { size.height - 46 }
    private var speed: CGFloat { min(190, 95 + time * 2.2) * (turbo > 0 ? 1.45 : 1) }
    private func half(_ at: CGFloat) -> CGFloat { max(26, 36 - at * 0.0015) }
    private func center(_ at: CGFloat) -> CGFloat {
        // Dos ondas largas. La pendiente máxima es amp·(1/150 + 0,35/85)/1,35 ≈ amp·0,008,
        // así que amp ≤ maxSlope/0,008 la mantiene dentro de lo que el volante puede seguir.
        let amp = min(size.width / 2 - half(at) - 10, Self.maxSlope / 0.008, 14 + max(0, at) * 0.012)
        return size.width / 2 + amp * (sin(at / 150) + 0.35 * sin(at / 85 + 1.3)) / 1.35
    }
    /// Distancia de carretera que se ve en la fila `y` de la pantalla.
    private func dist(atY y: CGFloat) -> CGFloat { d + (carY - y) }
    private func screenY(_ at: CGFloat) -> CGFloat { carY - (at - d) }
    /// Hacia dónde apunta la carretera en `at` (radianes, positivo = a la derecha).
    private func roadAngle(_ at: CGFloat) -> CGFloat { atan2(center(at + 8) - center(at - 8), 16) }
    /// Los rivales siguen la carretera: su costado, a la altura del jugador, está donde la curva lo lleva.
    private func lateral(_ r: Rival) -> CGFloat {
        center(min(r.d + r.halfLen, max(r.d - r.halfLen, d))) + r.off - x
    }
    private func stage(_ at: CGFloat) -> Int { Int(max(0, at) / Self.stageLen) }
    private func theme(_ stage: Int) -> Theme { Theme(rawValue: stage % Theme.allCases.count)! }

    func reset(size: CGSize) {
        self.size = size
        d = CGFloat(startStage) * Self.stageLen
        time = 0; lives = 3; invuln = 0; turbo = 0; spin = 0; mult = 1; bonus = 0; score = 0; heading = 0
        rivals = []; coins = []; groupLeft = [:]; cones = []; slicks = []; tokens = []; skids = []; popups = []; sparks = []
        nextAt = d + 260; lastToken = d
        causes = [:]; crashes = 0; edgeCrashes = 0; coinsTaken = 0; nearMisses = 0; turbos = 0
        x = center(d)
    }

    func resize(_ size: CGSize) { self.size = size }

    private func say(_ text: String, _ color: Color = .white, at p: CGPoint? = nil) {
        popups.append(Popup(p: p ?? CGPoint(x: x, y: carY - 26), text: text, color: color))
        if popups.count > 5 { popups.removeFirst() }
    }

    // MARK: Reparto de lo que sale por la carretera

    /// Dónde estará el jugador cuando alcance a un rival (los rivales van a la mitad de su velocidad).
    private func meet(_ r: Rival) -> CGFloat { 2 * r.d - d }
    /// ¿Cabe algo que mata con encuentro en `m`? Lo que mata se separa lo bastante para cambiar de lado.
    private func meetOK(_ m: CGFloat) -> Bool {
        let sep = max(170, 230 - time * 0.5)
        return !rivals.contains { abs(meet($0) - m) < sep } && !cones.contains { abs($0.d + 14 - m) < sep }
    }

    private func spawn() {
        let top = d + carY + 40
        guard top >= nextAt else { return }
        let st = stage(top)
        let room = half(top) - 11
        var placed = true
        let roll = CGFloat.random(in: 0..<1)
        if top - CGFloat(startStage) * Self.stageLen < 520 || roll < 0.33 {
            // Hilera de monedas: cruza de un lado a otro para marcar una trazada.
            if cones.contains(where: { $0.d > top - 50 }) { placed = false } else {
                let a = CGFloat.random(in: -room...room), b = CGFloat.random(in: -room...room)
                for i in 0..<6 { coins.append(Coin(d: top + CGFloat(i) * 15, off: a + (b - a) * CGFloat(i) / 5, group: nextGroup)) }
                groupLeft[nextGroup] = 6
                nextGroup += 1
                nextAt = top + 90
            }
        } else if roll < 0.74 {
            if meetOK(2 * top - d) {
                let p = CGFloat.random(in: 0..<1)
                let kind: RivalKind = st >= 1 && p < 0.22 ? .truck : (st >= 2 && p < 0.45 ? .changer : .car)
                // Nunca en el centro: siempre queda un lado ancho por el que pasar.
                var r = Rival(d: top, off: (Bool.random() ? 1 : -1) * CGFloat.random(in: room * 0.55...room),
                              color: [Color(hex: 0x6FB7F2), Color(hex: 0xF2C14E), Color(hex: 0xB58CFF), Color(hex: 0xE6E9EF)].randomElement()!, kind: kind)
                if kind == .changer {
                    r.off = (Bool.random() ? 1 : -1) * room * 0.8
                    r.target = -r.off
                    r.color = Color(hex: 0x58C4B0)
                }
                rivals.append(r)
            } else { placed = false }
        } else if roll < 0.86, st >= 1 || time > 25 {
            // Obras: tres conos en diagonal que cierran un lado.
            if meetOK(top + 14), !coins.contains(where: { $0.d > top - 40 }) {
                let side: CGFloat = Bool.random() ? 1 : -1
                for i in 0..<3 { cones.append(Spot(d: top + CGFloat(i) * 14, off: side * (room + 3 - CGFloat(i) * 9))) }
                nextAt = top + 60
            } else { placed = false }
        } else if roll < 0.95 {
            slicks.append(Spot(d: top, off: CGFloat.random(in: -room...room)))
        } else if top - lastToken > 3500 {
            tokens.append(Spot(d: top, off: CGFloat.random(in: -room * 0.7...room * 0.7)))
            lastToken = top
        } else { placed = false }
        if !placed { nextAt = top + 18 } else if nextAt <= top { nextAt = top + CGFloat.random(in: 55...105) * max(0.6, 1 - time * 0.004) }
    }

    func step(dt: CGFloat, input: CGFloat) -> ArcadeEvent {
        guard size.width > 0, lives > 0 else { return .none }
        var event = ArcadeEvent.none
        time += dt
        invuln = max(0, invuln - dt)
        turbo = max(0, turbo - dt)
        spin = max(0, spin - dt)
        Spark.step(&sparks, dt: dt)
        for i in popups.indices { popups[i].life -= dt * 1.1; popups[i].p.y -= 20 * dt }
        popups.removeAll { $0.life <= 0 }
        let v = speed
        heading = (input - 0.5) * 2 * Self.maxSteer
        let was = d
        d += v * dt
        x += v * tan(heading) * dt
        if abs(heading) > 0.42 {
            skids.append(Spot(d: d - 7, off: x - 4.5)); skids.append(Spot(d: d - 7, off: x + 4.5))
        }
        skids.removeAll { screenY($0.d) > size.height + 4 }

        // Meta de etapa: puntos y una vida de vuelta.
        if stage(d) > stage(was) {
            let n = stage(d)
            bonus += 15 * n
            lives = min(3, lives + 1)
            say(AppLanguage.text("ETAPA \(n + 1)", "STAGE \(n + 1)"), .white, at: CGPoint(x: size.width / 2, y: size.height * 0.4))
            event = .success
        }
        spawn()

        // Tráfico: va a la mitad de velocidad, así que baja por la pantalla.
        for i in rivals.indices {
            rivals[i].d += v * 0.5 * dt
            if rivals[i].kind == .changer {
                if !rivals[i].moving, rivals[i].d - d < 150 { rivals[i].moving = true }
                if rivals[i].moving, screenY(rivals[i].d) > 30 {
                    let room = half(rivals[i].d) - 11
                    let to = max(-room, min(room, rivals[i].target))
                    rivals[i].off += max(-15 * dt, min(15 * dt, to - rivals[i].off))
                }
            }
            // No atropellan las obras: se apartan.
            if let c = cones.first(where: { $0.d > rivals[i].d && $0.d - rivals[i].d < 70 && abs($0.off - rivals[i].off) < 17 }) {
                rivals[i].off += (c.off > 0 ? -1 : 1) * 34 * dt
            }
            if !rivals[i].passed, rivals[i].d < d - rivals[i].halfLen - 8 {
                rivals[i].passed = true
                let gap = abs(lateral(rivals[i]))
                if gap < 17.5, invuln <= 0, turbo <= 0 {
                    bonus += 4 * mult; nearMisses += 1
                    say(AppLanguage.text("¡Rozando!", "Close!"), Self.gold)
                    if event == .none { event = .bonus }
                } else { bonus += mult }
            }
        }
        rivals.removeAll { screenY($0.d) > size.height + 30 }
        cones.removeAll { screenY($0.d) > size.height + 10 }
        slicks.removeAll { screenY($0.d) > size.height + 16 }
        tokens.removeAll { screenY($0.d) > size.height + 10 }

        // Monedas.
        var i = 0
        while i < coins.count {
            let c = coins[i]
            if abs(c.d - d) < 11, abs(center(c.d) + c.off - x) < 11.5 {
                coins.remove(at: i)
                bonus += mult; coinsTaken += 1
                if let left = groupLeft[c.group] {
                    if left <= 1 {
                        groupLeft[c.group] = nil
                        if mult < 5 { mult += 1; say("×\(mult)", Self.gold) }
                        if event == .none { event = .bonus }
                    } else { groupLeft[c.group] = left - 1 }
                }
            } else if screenY(c.d) > size.height + 8 {
                coins.remove(at: i); groupLeft[c.group] = nil
            } else { i += 1 }
        }
        // Turbo.
        if let t = tokens.firstIndex(where: { abs($0.d - d) < 12 && abs(center($0.d) + $0.off - x) < 12 }) {
            tokens.remove(at: t)
            turbo = Self.turboTime; turbos += 1
            say("TURBO", Color(hex: 0x7FD6F2))
            if event == .none { event = .bonus }
        }
        // Mancha: no mata, pero se lleva el multiplicador.
        if invuln <= 0, turbo <= 0, spin <= 0,
           slicks.contains(where: { abs($0.d - d) < 11 && abs(center($0.d) + $0.off - x) < 11 }) {
            spin = 0.7
            if mult > 1 { mult = 1; say(theme(stage(d)) == .snow ? AppLanguage.text("¡Hielo! ×1", "Ice! ×1") : AppLanguage.text("¡Aceite! ×1", "Oil! ×1"), Color(hex: 0xF0766B)) }
            if event == .none { event = .bonus }
        }

        var crashed = false
        if invuln <= 0 {
            if abs(x - center(d)) > half(d) - 5 { crashed = true; edgeCrashes += 1 }
            if turbo > 0 {
                // Con turbo se lleva por delante coches y conos.
                let hitR = rivals.indices.filter { abs(rivals[$0].d - d) < rivals[$0].halfLen + 9 && abs(lateral(rivals[$0])) < 11.5 }
                for j in hitR.reversed() {
                    Spark.burst(&sparks, at: CGPoint(x: center(rivals[j].d) + rivals[j].off, y: screenY(rivals[j].d)), color: rivals[j].color, count: 10)
                    rivals.remove(at: j); bonus += 5 * mult
                    if event == .none { event = .bonus }
                }
                let n = cones.count
                cones.removeAll { abs($0.d - d) < 9 && abs(center($0.d) + $0.off - x) < 9 }
                bonus += (n - cones.count) * mult
            } else if !crashed {
                for r in rivals where abs(r.d - d) < r.halfLen + 8 && abs(lateral(r)) < (r.kind == .truck ? 11.5 : 10.5) { crashed = true; causes["\(r.kind)", default: 0] += 1 }
                for c in cones where abs(c.d - d) < 9 && abs(center(c.d) + c.off - x) < 8.5 { crashed = true; causes["cone", default: 0] += 1 }
            }
        }
        if crashed {
            Spark.burst(&sparks, at: CGPoint(x: x, y: carY), color: Self.gold, count: 14)
            crashes += 1
            if !god { lives -= 1 }
            mult = 1; turbo = 0
            score = Int(d / 25) + bonus
            if lives <= 0 { return .dead }
            invuln = 1.8
            x = center(d)
            rivals.removeAll { abs($0.d - d) < 90 }
            cones.removeAll { abs($0.d - d) < 60 }
            event = .hit
        }
        score = Int(d / 25) + bonus
        return event
    }

    // MARK: Dibujo

    /// 0…1 estable para el hueco `k` del arcén.
    private func noise(_ k: Int, _ salt: Int) -> CGFloat {
        var v = UInt32(truncatingIfNeeded: k) &* 2654435761 &+ UInt32(truncatingIfNeeded: salt) &* 40503
        v ^= v >> 15; v = v &* 2246822519; v ^= v >> 13
        return CGFloat(v % 1000) / 1000
    }

    private func drawDecor(_ ctx: inout GraphicsContext, theme: Theme, size: CGSize) {
        let lo = Int((dist(atY: size.height + 20) / 44).rounded(.down)), hi = Int((dist(atY: -20) / 44).rounded(.up))
        guard lo <= hi else { return }
        for k in lo...hi where k >= 0 {
            let at = CGFloat(k) * 44 + noise(k, 1) * 20
            let side: CGFloat = k % 2 == 0 ? -1 : 1
            let px = center(at) + side * (half(at) + 13 + noise(k, 2) * 30), py = screenY(at)
            guard px > -10, px < size.width + 10 else { continue }
            switch theme {
            case .meadow:
                ctx.fill(Path(ellipseIn: CGRect(x: px - 7, y: py - 7, width: 14, height: 14)), with: .color(Color(hex: 0x173D2A)))
                ctx.fill(Path(ellipseIn: CGRect(x: px - 5.5, y: py - 6.5, width: 9, height: 9)), with: .color(Color(hex: 0x2F7048)))
            case .desert:
                if noise(k, 3) < 0.55 {
                    ctx.fill(Path(roundedRect: CGRect(x: px - 2, y: py - 8, width: 4, height: 15), cornerRadius: 2), with: .color(Color(hex: 0x3F7A45)))
                    ctx.fill(Path(roundedRect: CGRect(x: px - 6.5, y: py - 3, width: 13, height: 3), cornerRadius: 1.5), with: .color(Color(hex: 0x3F7A45)))
                    ctx.fill(Path(roundedRect: CGRect(x: px - 6.5, y: py - 6, width: 3, height: 5), cornerRadius: 1.5), with: .color(Color(hex: 0x3F7A45)))
                    ctx.fill(Path(roundedRect: CGRect(x: px + 3.5, y: py - 5, width: 3, height: 4), cornerRadius: 1.5), with: .color(Color(hex: 0x3F7A45)))
                } else {
                    ctx.fill(Path(ellipseIn: CGRect(x: px - 6, y: py - 4, width: 12, height: 8)), with: .color(Color(hex: 0x8C6A45)))
                    ctx.fill(Path(ellipseIn: CGRect(x: px - 4, y: py - 4, width: 7, height: 4)), with: .color(Color(hex: 0xA8845A)))
                }
            case .snow:
                var tree = Path()
                tree.move(to: CGPoint(x: px, y: py - 10)); tree.addLine(to: CGPoint(x: px + 7, y: py + 6)); tree.addLine(to: CGPoint(x: px - 7, y: py + 6)); tree.closeSubpath()
                ctx.fill(tree, with: .color(Color(hex: 0x2C5F4A)))
                var cap = Path()
                cap.move(to: CGPoint(x: px, y: py - 10)); cap.addLine(to: CGPoint(x: px + 3.5, y: py - 2)); cap.addLine(to: CGPoint(x: px - 3.5, y: py - 2)); cap.closeSubpath()
                ctx.fill(cap, with: .color(.white))
            case .night:
                break   // las farolas van encima de la oscuridad (`drawLamps`)
            }
        }
    }

    private func drawLamps(_ ctx: inout GraphicsContext, size: CGSize) {
        let lo = Int((dist(atY: size.height + 30) / 88).rounded(.down)), hi = Int((dist(atY: -30) / 88).rounded(.up))
        guard lo <= hi else { return }
        for k in lo...hi where k >= 0 {
            let at = CGFloat(k) * 88
            let side: CGFloat = k % 2 == 0 ? -1 : 1
            let px = center(at) + side * (half(at) + 7), py = screenY(at)
            ctx.fill(Path(ellipseIn: CGRect(x: px - 17, y: py - 17, width: 34, height: 34)), with: .color(Color(hex: 0xF2D58A).opacity(0.13)))
            ctx.fill(Path(ellipseIn: CGRect(x: px - 8, y: py - 8, width: 16, height: 16)), with: .color(Color(hex: 0xF2D58A).opacity(0.16)))
            ctx.fill(Path(ellipseIn: CGRect(x: px - 2, y: py - 2, width: 4, height: 4)), with: .color(Color(hex: 0xFFF1C2)))
        }
    }

    private func drawPlayer(_ ctx: inout GraphicsContext) {
        guard lives > 0, invuln <= 0 || Int(time * 10) % 2 == 0 else { return }
        if turbo > 0 {
            var g = ctx
            g.translateBy(x: x, y: carY); g.rotate(by: .radians(Double(heading)))
            let len = 9 + 5 * sin(time * 40)
            var flame = Path()
            flame.move(to: CGPoint(x: -4, y: 9)); flame.addLine(to: CGPoint(x: 0, y: 10 + len)); flame.addLine(to: CGPoint(x: 4, y: 9)); flame.closeSubpath()
            g.fill(flame, with: .color(Color(hex: 0x7FD6F2)))
        }
        let wobble = spin > 0 ? sin(spin * 26) * 0.6 * (spin / 0.7) : 0
        WatchDrift.drawCar(in: &ctx, at: CGPoint(x: x, y: carY), size: Self.carSize, angle: heading + wobble, body: Color(hex: 0xF0766B))
    }

    /// Todo lo que va pegado a la carretera, con el paisaje de `theme`. Se llama una vez por etapa visible.
    private func drawWorld(_ ctx: inout GraphicsContext, theme: Theme, size: CGSize) {
        ctx.fill(Path(CGRect(x: 0, y: -40, width: size.width, height: size.height + 80)), with: .color(theme.ground))
        // Motas en el suelo, para que se note la velocidad también fuera del asfalto.
        for i in 0..<14 {
            let gx = CGFloat((i * 53 + 11) % 100) / 100 * size.width
            let gy = (CGFloat((i * 37 + 5) % 100) / 100 * (size.height + 20) + d).truncatingRemainder(dividingBy: size.height + 20) - 10
            ctx.fill(Path(ellipseIn: CGRect(x: gx - 2.5, y: gy - 1.5, width: 5, height: 3)), with: .color(theme.speck))
        }
        var left = Path(), right = Path(), mid = Path(), road = Path()
        var rights: [CGPoint] = []
        var first = true
        for y in stride(from: CGFloat(-12), through: size.height + 12, by: 6) {
            let at = dist(atY: y), c = center(at), h = half(at)
            let l = CGPoint(x: c - h, y: y), r = CGPoint(x: c + h, y: y), m = CGPoint(x: c, y: y)
            if first { left.move(to: l); right.move(to: r); mid.move(to: m); road.move(to: l); first = false }
            else { left.addLine(to: l); right.addLine(to: r); mid.addLine(to: m); road.addLine(to: l) }
            rights.append(r)
        }
        for p in rights.reversed() { road.addLine(to: p) }
        road.closeSubpath()
        ctx.fill(road, with: .color(theme.road))
        let phase = -d.truncatingRemainder(dividingBy: 12)
        for edge in [left, right] {
            ctx.stroke(edge, with: .color(.white), lineWidth: 3)
            ctx.stroke(edge, with: .color(Color(hex: 0xE0473B)), style: StrokeStyle(lineWidth: 3, dash: [6, 6], dashPhase: phase))
        }
        ctx.stroke(mid, with: .color(.white.opacity(0.55)),
                   style: StrokeStyle(lineWidth: 1.6, dash: [9, 11], dashPhase: -d.truncatingRemainder(dividingBy: 20)))
        drawDecor(&ctx, theme: theme, size: size)

        for s in skids {
            ctx.fill(Path(CGRect(x: s.off - 1.2, y: screenY(s.d) - 2, width: 2.4, height: 4)), with: .color(.black.opacity(0.28)))
        }
        for s in slicks {
            let p = CGPoint(x: center(s.d) + s.off, y: screenY(s.d))
            let c = theme == .snow ? Color(hex: 0xBFE6FA).opacity(0.85) : Color(hex: 0x0E1016).opacity(0.85)
            ctx.fill(Path(ellipseIn: CGRect(x: p.x - 10, y: p.y - 6.5, width: 20, height: 13)), with: .color(c))
            ctx.fill(Path(ellipseIn: CGRect(x: p.x - 3, y: p.y - 9, width: 11, height: 8)), with: .color(c))
            ctx.fill(Path(ellipseIn: CGRect(x: p.x - 6, y: p.y - 4, width: 6, height: 2.5)), with: .color(.white.opacity(theme == .snow ? 0.8 : 0.22)))
        }
        for c in coins {
            let p = CGPoint(x: center(c.d) + c.off, y: screenY(c.d))
            ctx.fill(Path(ellipseIn: CGRect(x: p.x - 4.5, y: p.y - 4.5, width: 9, height: 9)), with: .color(Color(hex: 0x9A6B12)))
            ctx.fill(Path(ellipseIn: CGRect(x: p.x - 3.6, y: p.y - 3.6, width: 7.2, height: 7.2)), with: .color(Self.gold))
            ctx.fill(Path(ellipseIn: CGRect(x: p.x - 2.2, y: p.y - 2.6, width: 2.4, height: 2.4)), with: .color(.white.opacity(0.75)))
        }
        for c in cones {
            let p = CGPoint(x: center(c.d) + c.off, y: screenY(c.d))
            ctx.fill(Path(roundedRect: CGRect(x: p.x - 5.5, y: p.y - 5.5, width: 11, height: 11), cornerRadius: 2), with: .color(Color(hex: 0x1A1C22)))
            ctx.fill(Path(ellipseIn: CGRect(x: p.x - 4.2, y: p.y - 4.2, width: 8.4, height: 8.4)), with: .color(Color(hex: 0xF07A2B)))
            ctx.fill(Path(ellipseIn: CGRect(x: p.x - 2.4, y: p.y - 2.4, width: 4.8, height: 4.8)), with: .color(.white))
            ctx.fill(Path(ellipseIn: CGRect(x: p.x - 1.1, y: p.y - 1.1, width: 2.2, height: 2.2)), with: .color(Color(hex: 0xF07A2B)))
        }
        for t in tokens {
            let p = CGPoint(x: center(t.d) + t.off, y: screenY(t.d))
            ctx.fill(Path(ellipseIn: CGRect(x: p.x - 8, y: p.y - 8, width: 16, height: 16)), with: .color(.white.opacity(0.9)))
            ctx.fill(Path(ellipseIn: CGRect(x: p.x - 7, y: p.y - 7, width: 14, height: 14)), with: .color(Color(hex: 0x7FD6F2)))
            var bolt = Path()
            bolt.move(to: CGPoint(x: p.x + 1.5, y: p.y - 5)); bolt.addLine(to: CGPoint(x: p.x - 3, y: p.y + 0.8)); bolt.addLine(to: CGPoint(x: p.x - 0.3, y: p.y + 0.8))
            bolt.addLine(to: CGPoint(x: p.x - 1.5, y: p.y + 5)); bolt.addLine(to: CGPoint(x: p.x + 3, y: p.y - 0.8)); bolt.addLine(to: CGPoint(x: p.x + 0.3, y: p.y - 0.8)); bolt.closeSubpath()
            ctx.fill(bolt, with: .color(Color(hex: 0x10141D)))
        }
        for r in rivals {
            let p = CGPoint(x: center(r.d) + r.off, y: screenY(r.d))
            if r.kind == .truck { WatchDrift.drawTruck(in: &ctx, at: p, angle: roadAngle(r.d), body: r.color) }
            else { WatchDrift.drawCar(in: &ctx, at: p, size: Self.carSize, angle: roadAngle(r.d), body: r.color) }
        }

        if theme == .night {
            // Oscuridad con el hueco de los faros.
            var dark = Path(CGRect(x: -10, y: -50, width: size.width + 20, height: size.height + 100))
            var cone = Path()
            let a = heading
            func pt(_ fx: CGFloat, _ fy: CGFloat) -> CGPoint { CGPoint(x: x + fx * cos(a) + fy * sin(a), y: carY + fx * sin(a) - fy * cos(a)) }
            cone.move(to: pt(-7, -12)); cone.addLine(to: pt(-30, 92)); cone.addQuadCurve(to: pt(30, 92), control: pt(0, 112)); cone.addLine(to: pt(7, -12)); cone.closeSubpath()
            dark.addPath(cone)
            ctx.fill(dark, with: .color(Color(hex: 0x05080F).opacity(0.6)), style: FillStyle(eoFill: true))
            drawLamps(&ctx, size: size)
            // Lo que brilla en la oscuridad: pilotos traseros, conos y monedas.
            for r in rivals {
                let p = CGPoint(x: center(r.d) + r.off, y: screenY(r.d) + r.halfLen - 1)
                for dx in [-3.6, 3.6] as [CGFloat] {
                    ctx.fill(Path(ellipseIn: CGRect(x: p.x + dx - 1.6, y: p.y - 1.6, width: 3.2, height: 3.2)), with: .color(Color(hex: 0xFF4A3D)))
                }
            }
            for c in cones {
                let p = CGPoint(x: center(c.d) + c.off, y: screenY(c.d))
                ctx.fill(Path(ellipseIn: CGRect(x: p.x - 2.4, y: p.y - 2.4, width: 4.8, height: 4.8)), with: .color(.white.opacity(0.85)))
            }
            for c in coins {
                let p = CGPoint(x: center(c.d) + c.off, y: screenY(c.d))
                ctx.fill(Path(ellipseIn: CGRect(x: p.x - 2, y: p.y - 2, width: 4, height: 4)), with: .color(Self.gold.opacity(0.7)))
            }
        }
        // Intermitente de la furgoneta que cambia de carril: encima de todo, también de noche.
        for r in rivals where r.kind == .changer && abs(r.target - r.off) > 2 && Int(time * 5) % 2 == 0 {
            let p = CGPoint(x: center(r.d) + r.off, y: screenY(r.d))
            let sx: CGFloat = r.target > r.off ? 6.5 : -6.5
            for dy in [-8, 8] as [CGFloat] {
                ctx.fill(Path(ellipseIn: CGRect(x: p.x + sx - 2.2, y: p.y + dy - 2.2, width: 4.4, height: 4.4)), with: .color(Color(hex: 0xFFB020)))
            }
        }
        drawPlayer(&ctx)
    }

    func draw(_ ctx: inout GraphicsContext, size: CGSize) {
        // Como mucho se ven dos etapas: la de abajo y, por encima de la meta, la siguiente.
        let low = stage(dist(atY: size.height + 12))
        let lineY = screenY(CGFloat(low + 1) * Self.stageLen)
        if lineY < -20 {
            drawWorld(&ctx, theme: theme(low), size: size)
        } else {
            var a = ctx
            a.clip(to: Path(CGRect(x: -10, y: lineY, width: size.width + 20, height: size.height + 60 - lineY)))
            drawWorld(&a, theme: theme(low), size: size)
            var b = ctx
            b.clip(to: Path(CGRect(x: -10, y: -60, width: size.width + 20, height: lineY + 60)))
            drawWorld(&b, theme: theme(low + 1), size: size)
            // Meta de cuadros.
            let at = CGFloat(low + 1) * Self.stageLen, c = center(at), h = half(at)
            let n = Int((2 * h / 5).rounded()), w = 2 * h / CGFloat(n)
            for row in 0..<2 {
                for i in 0..<n {
                    ctx.fill(Path(CGRect(x: c - h + CGFloat(i) * w, y: lineY - 5 + CGFloat(row) * 5, width: w + 0.3, height: 5)),
                             with: .color((i + row) % 2 == 0 ? .white : Color(hex: 0x14161B)))
                }
            }
        }
        Spark.draw(sparks, in: &ctx)
        for p in popups {
            let t = Text(p.text).font(.system(size: 13, weight: .black, design: .rounded))
            ctx.draw(t.foregroundColor(.black.opacity(0.55 * min(1, p.life * 2))), at: CGPoint(x: p.p.x + 0.8, y: p.p.y + 1))
            ctx.draw(t.foregroundColor(p.color.opacity(min(1, p.life * 2))), at: p.p)
        }
        // Marcador sobre una pastilla oscura: en la nieve el blanco no se leería.
        // Sobre suelo claro (nieve, desierto) la pastilla llega hasta la derecha: la hora del sistema es blanca.
        let topTheme = theme(stage(dist(atY: ArcadeHUD.y)))
        let light = topTheme == .snow || topTheme == .desert
        // (y el botón de salir, de cristal con la flecha blanca).
        let hudX: CGFloat = light ? 8 : ArcadeHUD.left - 6
        let hudW = light ? size.width - 16 : ArcadeHUD.scoreBand + 22 + 33 + (mult > 1 ? 22 : 0)
        ctx.fill(Path(roundedRect: CGRect(x: hudX, y: ArcadeHUD.y - 10, width: hudW, height: 20), cornerRadius: 10),
                 with: .color(.black.opacity(light ? 0.42 : 0.32)))
        drawLives(lives, in: &ctx, width: size.width)
        if mult > 1 {
            ctx.draw(Text("×\(mult)").font(.system(size: 12, weight: .black, design: .rounded)).foregroundColor(Self.gold),
                     at: CGPoint(x: ArcadeHUD.left + ArcadeHUD.scoreBand + 8 + 33, y: ArcadeHUD.y), anchor: .leading)
        }
        if turbo > 0 {
            let w: CGFloat = 60, bx = ArcadeHUD.left - 2, by = ArcadeHUD.y + 13
            ctx.fill(Path(roundedRect: CGRect(x: bx, y: by, width: w, height: 4), cornerRadius: 2), with: .color(.black.opacity(0.3)))
            ctx.fill(Path(roundedRect: CGRect(x: bx, y: by, width: w * turbo / Self.turboTime, height: 4), cornerRadius: 2), with: .color(Color(hex: 0x7FD6F2)))
        }
    }

    // MARK: Piloto automático (capturas y tests)

    func autopilot() -> CGFloat {
        let look: CGFloat = 34
        let room = half(d + look) - 7
        // Lo que mata: (cuánto falta hasta alcanzarlo, su desvío del centro, hueco que hay que dejar).
        var threats: [(CGFloat, CGFloat, CGFloat)] = []
        if turbo <= 0.4 {
            for r in rivals where r.d > d - r.halfLen - 12 && (r.d - d) * 2 < 170 {
                threats.append((max(0, (r.d - d) * 2), r.kind == .changer && r.moving ? (r.off + r.target) / 2 : r.off, r.kind == .changer ? 24 : 19))
            }
            for c in cones where c.d > d - 10 && c.d - d < 170 { threats.append((c.d - d, c.off, 16)) }
        }
        let coin = coins.filter { $0.d > d + 6 && $0.d - d < 80 }.min { $0.d < $1.d }
        let token = tokens.first { $0.d > d + 6 && $0.d - d < 120 }
        let prefer = token?.off ?? coin?.off
        let now = x - center(d)
        var best: CGFloat = 0, bestCost = CGFloat.infinity
        for off in stride(from: -room, through: room, by: 2) {
            var cost = abs(off - (prefer ?? 0)) * (prefer == nil ? 0.2 : 0.6) + abs(off - now) * 0.15
            for t in threats where abs(off - t.1) < t.2 { cost += 200 + (t.2 - abs(off - t.1)) * 30 * (1.3 - t.0 / 170) }
            for s in slicks where s.d > d && s.d - d < 90 && abs(off - s.off) < 14 { cost += 25 }
            if cost < bestCost { bestCost = cost; best = off }
        }
        // Apunta el morro al punto de la carretera que tiene 34 pt por delante.
        return min(1, max(0, 0.5 + atan2(center(d + look) + best - x, look) / (2 * Self.maxSteer)))
    }
}

#if os(watchOS)
struct WatchDriftView: View {
    var body: some View { WatchArcadeStage(info: WatchDrift.info, world: DriftWorld()) }
}
#endif

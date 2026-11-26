//
//  WatchAliensView.swift — Quizzy Watch
//  Marcianitos: una formación de marcianos se mece arriba y, de vez en cuando, alguno se lanza
//  en picado hacia la nave soltando una bomba. La nave dispara sola; el jugador solo la mueve
//  con la Corona. 3 vidas; cada oleada despejada trae otra más agresiva.
//  Disparo base lento (uno cada 0,5 s). Los marcianos sueltan a veces una MEJORA temporal
//  (`ArcadeBoost`, 10 s, acumulables): R cadencia, 2 doble, V uve, E escoltas.
//  Puntos: 10 por marciano en formación, 25 si se le caza en picado, 50 por oleada.
//  Cada oleada trae otra FORMACIÓN (`shapes`: bloque, rombo, uve, anillo, columnas, damero, flecha)
//  y otro vaivén (de lado a lado, respirando o en onda). Desde la 2.ª hay blindados que piden
//  2 impactos (casco) y desde la 4.ª, de 3 (casco dorado); valen 10 puntos más por impacto extra.
//  Dibujos propios (formas en Canvas). Bucle y pantallas: `WatchArcadeStage`.
//

import SwiftUI

enum WatchAliens {
    static var info: ArcadeInfo {
        ArcadeInfo(id: "aliens", title: AppLanguage.text("Marcianitos", "Martians"),
                   hint: AppLanguage.text("Gira la Corona", "Turn the Crown"), color: Color(hex: 0x7BE08A))
    }
    static let palette: [UInt32] = [0xF28FB5, 0xC59BFF, 0xF2B95C, 0x7BE08A]

    /// Marciano: cuerpo redondo, dos ojos, antenas y tres patas que se mueven.
    static func drawAlien(in ctx: inout GraphicsContext, at c: CGPoint, size s: CGFloat, kind: Int, phase: CGFloat,
                          armor: Int = 0, flash: Bool = false) {
        let color = flash ? Color.white : Color(hex: palette[kind % palette.count])
        let dark = Color(hex: 0x10141D)
        defer {
            // Blindaje: un casco por encima (gris = aguanta 1 impacto más; dorado = 2 más).
            if armor > 0 {
                var helmet = Path()
                helmet.addArc(center: CGPoint(x: c.x, y: c.y - s * 0.12), radius: s * 0.5, startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false)
                helmet.closeSubpath()
                ctx.fill(helmet, with: .color(armor > 1 ? Color(hex: 0xF2C14E) : Color(hex: 0xB9C2D0)))
                ctx.fill(Path(CGRect(x: c.x - s * 0.5, y: c.y - s * 0.16, width: s, height: s * 0.09)), with: .color(.black.opacity(0.35)))
                ctx.fill(Path(ellipseIn: CGRect(x: c.x - s * 0.28, y: c.y - s * 0.52, width: s * 0.22, height: s * 0.1)), with: .color(.white.opacity(0.6)))
            }
        }
        // Antenas
        for side in [-1.0, 1.0] as [CGFloat] {
            var antenna = Path()
            antenna.move(to: CGPoint(x: c.x + side * s * 0.18, y: c.y - s * 0.25))
            antenna.addLine(to: CGPoint(x: c.x + side * s * 0.34, y: c.y - s * 0.52))
            ctx.stroke(antenna, with: .color(color), lineWidth: 1.2)
            ctx.fill(Path(ellipseIn: CGRect(x: c.x + side * s * 0.34 - 1.4, y: c.y - s * 0.52 - 1.4, width: 2.8, height: 2.8)), with: .color(color))
        }
        // Patas (alternan con `phase`)
        for k in -1...1 {
            let lift: CGFloat = (k == 0) == (phase.truncatingRemainder(dividingBy: 1) < 0.5) ? 0 : 1.6
            ctx.fill(Path(roundedRect: CGRect(x: c.x + CGFloat(k) * s * 0.28 - 1.2, y: c.y + s * 0.22, width: 2.4, height: s * 0.24 - lift), cornerRadius: 1),
                     with: .color(color))
        }
        ctx.fill(Path(ellipseIn: CGRect(x: c.x - s * 0.46, y: c.y - s * 0.34, width: s * 0.92, height: s * 0.68)), with: .color(color))
        for side in [-1.0, 1.0] as [CGFloat] {
            ctx.fill(Path(ellipseIn: CGRect(x: c.x + side * s * 0.19 - s * 0.12, y: c.y - s * 0.16, width: s * 0.24, height: s * 0.26)), with: .color(.white))
            ctx.fill(Path(ellipseIn: CGRect(x: c.x + side * s * 0.19 - s * 0.05, y: c.y - s * 0.04, width: s * 0.11, height: s * 0.12)), with: .color(dark))
        }
    }

    /// Nave del jugador: cuña redondeada con cabina y dos aletas.
    static func drawShip(in ctx: inout GraphicsContext, at c: CGPoint, size s: CGFloat, flame: CGFloat) {
        let hull = Color(hex: 0x8FC2F2)
        var flamePath = Path()
        flamePath.move(to: CGPoint(x: c.x - s * 0.14, y: c.y + s * 0.38))
        flamePath.addLine(to: CGPoint(x: c.x, y: c.y + s * (0.62 + 0.16 * flame)))
        flamePath.addLine(to: CGPoint(x: c.x + s * 0.14, y: c.y + s * 0.38))
        ctx.fill(flamePath, with: .color(Color(hex: 0xF2B95C)))
        var body = Path()
        body.move(to: CGPoint(x: c.x, y: c.y - s * 0.55))
        body.addQuadCurve(to: CGPoint(x: c.x + s * 0.5, y: c.y + s * 0.42), control: CGPoint(x: c.x + s * 0.2, y: c.y - s * 0.1))
        body.addLine(to: CGPoint(x: c.x + s * 0.18, y: c.y + s * 0.3))
        body.addLine(to: CGPoint(x: c.x - s * 0.18, y: c.y + s * 0.3))
        body.addLine(to: CGPoint(x: c.x - s * 0.5, y: c.y + s * 0.42))
        body.addQuadCurve(to: CGPoint(x: c.x, y: c.y - s * 0.55), control: CGPoint(x: c.x - s * 0.2, y: c.y - s * 0.1))
        ctx.fill(body, with: .color(hull))
        ctx.fill(Path(ellipseIn: CGRect(x: c.x - s * 0.1, y: c.y - s * 0.22, width: s * 0.2, height: s * 0.3)), with: .color(Color(hex: 0x1B2233)))
    }
}

final class AlienWorld: ArcadeWorld {
    enum Mode { case slot, dive, back }
    struct Enemy {
        var col: Int, row: Int
        var pos: CGPoint = .zero
        var mode = Mode.slot
        var t: CGFloat = 0
        var fromX: CGFloat = 0, toX: CGFloat = 0
        var fired = false
        var hp = 1
        var flash: CGFloat = 0
    }
    static let cols = 6, rows = 4
    /// Formaciones, fila a fila (`#` = marciano). Rotan con la oleada.
    static let shapes: [[String]] = [
        ["######", "######", "######", "######"],     // bloque
        ["..##..", ".####.", "######", ".####."],     // rombo
        ["#....#", "##..##", ".####.", "..##.."],     // uve
        ["######", "#....#", "#....#", "######"],     // anillo
        ["##..##", "##..##", "##..##", "##..##"],     // columnas
        ["#.#.#.", ".#.#.#", "#.#.#.", ".#.#.#"],     // damero
        ["..##..", ".####.", "######", "..##.."],     // flecha
    ]

    private var size: CGSize = .zero
    private var enemies: [Enemy] = []
    struct Shot { var p: CGPoint; var vx: CGFloat = 0 }
    struct Pickup { var p: CGPoint; var kind: ArcadeBoost }
    private var shots: [Shot] = []
    private var pickups: [Pickup] = []
    private var boosts = ArcadeBoosts()
    static let wingGap: CGFloat = 15
    private var bombs: [CGPoint] = []
    private var sparks: [Spark] = []
    private var px: CGFloat = 0
    private var py: CGFloat = 0
    private var lives = 3
    private var wave = 1
    private var time: CGFloat = 0
    private var fireT: CGFloat = 0, diveT: CGFloat = 1.5, bombT: CGFloat = 2.5
    private var invuln: CGFloat = 0
    private var cleared = false, waveDelay: CGFloat = 0
    private(set) var score = 0

    func reset(size: CGSize) {
        self.size = size
        shots = []; bombs = []; sparks = []; pickups = []; boosts.clear()
        px = size.width / 2; py = size.height - 24
        lives = 3; wave = 1; time = 0; score = 0
        fireT = 0.3; diveT = 1.5; bombT = 2.5; invuln = 0; cleared = false; waveDelay = 0
        if ProcessInfo.processInfo.environment["QW_BOOST"] == "1" { ArcadeBoost.allCases.forEach { boosts.take($0) } }   // capturas: todas las mejoras
        spawn()
    }

    func resize(_ size: CGSize) { self.size = size }

    private func spawn() {
        let shape = Self.shapes[(wave - 1) % Self.shapes.count].map(Array.init)
        enemies = (0..<Self.rows).flatMap { r in (0..<Self.cols).compactMap { shape[r][$0] == "#" ? Enemy(col: $0, row: r) : nil } }
        // Blindados: ninguno en la 1.ª oleada; luego cada vez más, y desde la 4.ª algunos de 3.
        let share = wave < 2 ? 0 : min(0.5, 0.12 + Double(wave) * 0.05)
        for i in enemies.indices {
            if Double.random(in: 0..<1) < share { enemies[i].hp = wave >= 4 && Bool.random() ? 3 : 2 }
            enemies[i].pos = slot(enemies[i])
        }
    }

    private func slot(_ e: Enemy) -> CGPoint {
        var sx = min(27, (size.width - 26) / CGFloat(Self.cols))
        var dx = sin(time * 1.1) * 8, dy: CGFloat = 0
        switch (wave - 1) % 3 {
        case 1: sx *= 0.9 + 0.1 * sin(time * 1.6); dx *= 0.5          // respira (se abre y se cierra)
        case 2: dy = sin(time * 2 + CGFloat(e.col) * 0.9) * 3.5        // onda que recorre las columnas
        default: break                                                 // de lado a lado
        }
        return CGPoint(x: size.width / 2 + (CGFloat(e.col) - CGFloat(Self.cols - 1) / 2) * sx + dx,
                       y: ArcadeHUD.top + 14 + CGFloat(e.row) * 16 + dy)
    }

    func step(dt: CGFloat, input: CGFloat) -> ArcadeEvent {
        guard size.width > 0, lives > 0 else { return .none }
        var event = ArcadeEvent.none
        time += dt
        // A 24 pt del fondo y 16 de los lados: las esquinas de la pantalla son redondas.
        px = 16 + input * (size.width - 32)
        py = size.height - 24
        invuln = max(0, invuln - dt)
        Spark.step(&sparks, dt: dt)

        // Oleada despejada → pausa breve y la siguiente.
        if enemies.isEmpty {
            if !cleared { cleared = true; waveDelay = 1.2; score += 50; event = .bonus }
            waveDelay -= dt
            if waveDelay <= 0 { wave += 1; cleared = false; spawn(); diveT = 1.2 }
        }

        // Disparo automático: lento y de uno en uno; las mejoras lo aceleran, lo doblan, lo abren
        // en uve o le ponen dos escoltas.
        boosts.step(dt: dt)
        fireT -= dt
        if fireT <= 0 {
            fireT = boosts.on(.rapid) ? 0.24 : 0.5
            func shot(_ dx: CGFloat, _ dy: CGFloat, _ vx: CGFloat = 0) { shots.append(Shot(p: CGPoint(x: px + dx, y: py + dy), vx: vx)) }
            if boosts.on(.double) { shot(-4, -8); shot(4, -8) } else { shot(0, -9) }
            if boosts.on(.spread) { shot(-6, -6, -62); shot(6, -6, 62) }
            if boosts.on(.wing) { shot(-Self.wingGap, -2); shot(Self.wingGap, -2) }
        }
        for i in shots.indices { shots[i].p.y -= 280 * dt; shots[i].p.x += shots[i].vx * dt }
        shots.removeAll { $0.p.y < -6 || $0.p.x < -6 || $0.p.x > size.width + 6 }

        // Mejoras que caen: se recogen con la nave.
        for i in pickups.indices { pickups[i].p.y += 44 * dt }
        pickups.removeAll { $0.p.y > size.height + 10 }
        if let k = pickups.firstIndex(where: { abs($0.p.x - px) < 12 && abs($0.p.y - py) < 12 }) {
            boosts.take(pickups.remove(at: k).kind)
            event = .bonus
        }

        // Picados: más frecuentes y más a la vez según la oleada.
        diveT -= dt
        if diveT <= 0, !enemies.isEmpty {
            let divers = enemies.filter { $0.mode != .slot }.count
            if divers < min(1 + wave / 2, 4), let i = enemies.indices.filter({ enemies[$0].mode == .slot }).randomElement() {
                enemies[i].mode = .dive; enemies[i].t = 0; enemies[i].fired = false
                enemies[i].fromX = enemies[i].pos.x; enemies[i].toX = px
            }
            diveT = max(0.7, 2.8 - CGFloat(wave) * 0.2) * CGFloat.random(in: 0.7...1.3)
        }
        // Bombas sueltas desde la formación.
        bombT -= dt
        if bombT <= 0 {
            if let e = enemies.filter({ $0.mode == .slot }).randomElement() { bombs.append(CGPoint(x: e.pos.x, y: e.pos.y + 6)) }
            bombT = max(1.2, 4.4 - CGFloat(wave) * 0.3) * CGFloat.random(in: 0.7...1.3)
        }

        for i in enemies.indices {
            enemies[i].flash = max(0, enemies[i].flash - dt)
            switch enemies[i].mode {
            case .slot:
                enemies[i].pos = slot(enemies[i])
            case .dive:
                enemies[i].t += dt
                let t = enemies[i].t, k = min(1, t / 1.1)
                enemies[i].pos.y += (58 + CGFloat(wave) * 6) * dt
                enemies[i].pos.x = enemies[i].fromX + (enemies[i].toX - enemies[i].fromX) * k * k * (3 - 2 * k) + sin(t * 6) * 12
                // En la primera oleada los que bajan en picado no sueltan bomba (para aprender a esquivar).
                if !enemies[i].fired, t > 0.45, wave > 1 {
                    enemies[i].fired = true
                    bombs.append(CGPoint(x: enemies[i].pos.x, y: enemies[i].pos.y + 6))
                }
                if enemies[i].pos.y > size.height + 10 { enemies[i].pos.y = -10; enemies[i].mode = .back }
            case .back:
                let target = slot(enemies[i])
                let dx = target.x - enemies[i].pos.x, dy = target.y - enemies[i].pos.y
                let dist = max(0.001, hypot(dx, dy))
                if dist < 3 { enemies[i].mode = .slot } else {
                    enemies[i].pos.x += dx / dist * 100 * dt
                    enemies[i].pos.y += dy / dist * 100 * dt
                }
            }
        }

        let bombSpeed = 86 + CGFloat(wave) * 8
        for i in bombs.indices { bombs[i].y += bombSpeed * dt }
        bombs.removeAll { $0.y > size.height + 6 }

        // Disparos contra marcianos.
        for i in shots.indices.reversed() {
            let s = shots[i].p
            guard let j = enemies.firstIndex(where: { abs($0.pos.x - s.x) < 9 && abs($0.pos.y - s.y) < 8 }) else { continue }
            shots.remove(at: i)
            enemies[j].hp -= 1
            if enemies[j].hp > 0 {
                // Blindado: pierde una capa de casco, da puntos y sigue.
                enemies[j].flash = 0.1
                score += 10
                Spark.burst(&sparks, at: CGPoint(x: s.x, y: s.y), color: Color(hex: 0xB9C2D0), count: 4)
                continue
            }
            score += enemies[j].mode == .slot ? 10 : 25
            // Los cazados en picado sueltan mejora más a menudo; como mucho dos fichas a la vez.
            if pickups.count < 2, CGFloat.random(in: 0..<1) < (enemies[j].mode == .slot ? 0.05 : 0.25) {
                pickups.append(Pickup(p: enemies[j].pos, kind: boosts.drop()))
            }
            Spark.burst(&sparks, at: enemies[j].pos, color: Color(hex: WatchAliens.palette[enemies[j].row % 4]))
            enemies.remove(at: j)
        }

        // Golpes a la nave.
        if invuln <= 0 {
            var hit = false
            if let b = bombs.firstIndex(where: { abs($0.x - px) < 6.5 && abs($0.y - py) < 7 }) { bombs.remove(at: b); hit = true }
            if let j = enemies.firstIndex(where: { $0.mode != .slot && abs($0.pos.x - px) < 10 && abs($0.pos.y - py) < 9 }) {
                Spark.burst(&sparks, at: enemies[j].pos, color: .white)
                enemies.remove(at: j); hit = true
            }
            if hit {
                #if DEBUG
                if ArcadeProbe.shared.fps { print("QWHIT t=\(time) wave=\(wave) px=\(px) bombs=\(bombs.count) divers=\(enemies.filter { $0.mode == .dive }.count)") }
                #endif
                lives -= 1
                Spark.burst(&sparks, at: CGPoint(x: px, y: py), color: Color(hex: 0x8FC2F2), count: 14)
                invuln = 1.6
                bombs.removeAll()
                if lives <= 0 { return .dead }
                event = .hit
            }
        }
        return event
    }

    func draw(_ ctx: inout GraphicsContext, size: CGSize) {
        // Fondo: nebulosa y planeta (cambian de color con la oleada) y dos capas de estrellas que caen.
        let tint = Color(hex: WatchAliens.palette[(wave - 1) % WatchAliens.palette.count])
        ctx.fill(Path(CGRect(x: 0, y: -40, width: size.width, height: size.height + 80)),
                 with: .radialGradient(Gradient(colors: [tint.opacity(0.18), tint.opacity(0)]), center: CGPoint(x: size.width * 0.3, y: size.height * 0.55),
                                       startRadius: 0, endRadius: size.width * 0.5))
        let planet = CGRect(x: size.width - 46, y: size.height * 0.56, width: 34, height: 34)
        ctx.fill(Path(ellipseIn: planet), with: .linearGradient(Gradient(colors: [tint.opacity(0.5), tint.opacity(0.12)]),
                                                               startPoint: CGPoint(x: planet.minX, y: planet.minY), endPoint: CGPoint(x: planet.maxX, y: planet.maxY)))
        ctx.stroke(Path(ellipseIn: planet.insetBy(dx: -9, dy: 11)), with: .color(tint.opacity(0.3)), lineWidth: 1.5)
        for i in 0..<26 {
            let near = i % 3 == 0
            let x = CGFloat((i * 73 + 11) % 100) / 100 * size.width
            let y = (CGFloat((i * 131 + 37) % 100) / 100 * size.height + time * (near ? 14 : 5)).truncatingRemainder(dividingBy: size.height)
            let a = 0.25 + 0.25 * sin(time * 2 + CGFloat(i))
            let r: CGFloat = near ? 1.7 : 1.1
            ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: r, height: r)), with: .color(.white.opacity(a + (near ? 0.2 : 0))))
        }
        for e in enemies {
            WatchAliens.drawAlien(in: &ctx, at: e.pos, size: 15, kind: e.row, phase: time * 2 + CGFloat(e.col) * 0.5,
                                  armor: e.hp - 1, flash: e.flash > 0)
        }
        for s in shots {
            ctx.fill(Path(roundedRect: CGRect(x: s.p.x - 1.2, y: s.p.y - 4, width: 2.4, height: 8), cornerRadius: 1.2), with: .color(Color(hex: 0xFFF2B0)))
        }
        for b in bombs {
            ctx.fill(Path(ellipseIn: CGRect(x: b.x - 2.4, y: b.y - 2.4, width: 4.8, height: 4.8)), with: .color(Color(hex: 0xF0766B)))
        }
        for p in pickups { p.kind.draw(at: p.p, in: &ctx) }
        if lives > 0, boosts.on(.wing) {
            for side in [-1, 1] as [CGFloat] {
                WatchAliens.drawShip(in: &ctx, at: CGPoint(x: px + side * Self.wingGap, y: py + 3), size: 10, flame: sin(time * 30 + side))
            }
        }
        boosts.drawBars(in: &ctx, origin: CGPoint(x: ArcadeHUD.left, y: ArcadeHUD.y + 10), width: 34, height: 3)
        // Parpadea mientras es invulnerable tras un golpe.
        if lives > 0, invuln <= 0 || Int(time * 12) % 2 == 0 {
            WatchAliens.drawShip(in: &ctx, at: CGPoint(x: px, y: py), size: 18, flame: sin(time * 30))
        }
        Spark.draw(sparks, in: &ctx)
        drawLives(lives, in: &ctx, width: size.width)
        if cleared {
            ctx.draw(Text(AppLanguage.text("Oleada \(wave + 1)", "Wave \(wave + 1)"))
                .font(.system(size: 15, weight: .heavy, design: .rounded)).foregroundColor(WatchAliens.info.color),
                     at: CGPoint(x: size.width / 2, y: size.height * 0.4))
        }
    }

    func autopilot() -> CGFloat {
        // Esquiva la bomba más cercana; si no, se pone bajo el marciano más bajo.
        let threats = bombs + enemies.filter { $0.mode == .dive }.map(\.pos)
        if let b = threats.filter({ abs($0.x - px) < 15 && $0.y < py && py - $0.y < 75 }).max(by: { $0.y < $1.y }) {
            let side: CGFloat = px < 30 ? 1 : (px > size.width - 30 ? -1 : (b.x >= px ? -1 : 1))
            return (px + side * 34 - 16) / max(1, size.width - 32)
        }
        if let p = pickups.first { return (p.p.x - 16) / max(1, size.width - 32) }
        guard let target = enemies.max(by: { $0.pos.y < $1.pos.y }) else { return 0.5 }
        return (target.pos.x - 16) / max(1, size.width - 32)
    }
}

struct WatchAliensView: View {
    var body: some View { WatchArcadeStage(info: WatchAliens.info, world: AlienWorld()) }
}

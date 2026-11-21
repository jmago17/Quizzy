//
//  WatchAliensView.swift — Quizzy Watch
//  Marcianitos: una formación de marcianos se mece arriba y, de vez en cuando, alguno se lanza
//  en picado hacia la nave soltando una bomba. La nave dispara sola; el jugador solo la mueve
//  con la Corona. 3 vidas; cada oleada despejada trae otra más agresiva.
//  Puntos: 10 por marciano en formación, 25 si se le caza en picado, 50 por oleada.
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
    static func drawAlien(in ctx: inout GraphicsContext, at c: CGPoint, size s: CGFloat, kind: Int, phase: CGFloat) {
        let color = Color(hex: palette[kind % palette.count])
        let dark = Color(hex: 0x10141D)
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
    }
    static let cols = 6, rows = 4

    private var size: CGSize = .zero
    private var enemies: [Enemy] = []
    private var shots: [CGPoint] = []
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
        shots = []; bombs = []; sparks = []
        px = size.width / 2; py = size.height - 16
        lives = 3; wave = 1; time = 0; score = 0
        fireT = 0.3; diveT = 1.5; bombT = 2.5; invuln = 0; cleared = false; waveDelay = 0
        spawn()
    }

    func resize(_ size: CGSize) { self.size = size }

    private func spawn() {
        enemies = (0..<Self.rows).flatMap { r in (0..<Self.cols).map { Enemy(col: $0, row: r) } }
        for i in enemies.indices { enemies[i].pos = slot(enemies[i]) }
    }

    private func slot(_ e: Enemy) -> CGPoint {
        let sx = min(27, (size.width - 26) / CGFloat(Self.cols))
        return CGPoint(x: size.width / 2 + (CGFloat(e.col) - CGFloat(Self.cols - 1) / 2) * sx + sin(time * 1.1) * 8,
                       y: 24 + CGFloat(e.row) * 16)
    }

    func step(dt: CGFloat, input: CGFloat) -> ArcadeEvent {
        guard size.width > 0, lives > 0 else { return .none }
        var event = ArcadeEvent.none
        time += dt
        px = 12 + input * (size.width - 24)
        py = size.height - 16
        invuln = max(0, invuln - dt)
        Spark.step(&sparks, dt: dt)

        // Oleada despejada → pausa breve y la siguiente.
        if enemies.isEmpty {
            if !cleared { cleared = true; waveDelay = 1.2; score += 50; event = .bonus }
            waveDelay -= dt
            if waveDelay <= 0 { wave += 1; cleared = false; spawn(); diveT = 1.2 }
        }

        // Disparo automático (máx. 3 en pantalla).
        fireT -= dt
        if fireT <= 0, shots.count < 3 { shots.append(CGPoint(x: px, y: py - 9)); fireT = 0.3 }
        for i in shots.indices { shots[i].y -= 280 * dt }
        shots.removeAll { $0.y < -6 }

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
            let s = shots[i]
            guard let j = enemies.firstIndex(where: { abs($0.pos.x - s.x) < 9 && abs($0.pos.y - s.y) < 8 }) else { continue }
            score += enemies[j].mode == .slot ? 10 : 25
            Spark.burst(&sparks, at: enemies[j].pos, color: Color(hex: WatchAliens.palette[enemies[j].row % 4]))
            enemies.remove(at: j)
            shots.remove(at: i)
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
        for i in 0..<20 {   // estrellas fijas que titilan
            let x = CGFloat((i * 73 + 11) % 100) / 100 * size.width
            let y = CGFloat((i * 131 + 37) % 100) / 100 * size.height
            let a = 0.25 + 0.25 * sin(time * 2 + CGFloat(i))
            ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 1.4, height: 1.4)), with: .color(.white.opacity(a)))
        }
        for e in enemies {
            WatchAliens.drawAlien(in: &ctx, at: e.pos, size: 15, kind: e.row, phase: time * 2 + CGFloat(e.col) * 0.5)
        }
        for s in shots {
            ctx.fill(Path(roundedRect: CGRect(x: s.x - 1.2, y: s.y - 4, width: 2.4, height: 8), cornerRadius: 1.2), with: .color(Color(hex: 0xFFF2B0)))
        }
        for b in bombs {
            ctx.fill(Path(ellipseIn: CGRect(x: b.x - 2.4, y: b.y - 2.4, width: 4.8, height: 4.8)), with: .color(Color(hex: 0xF0766B)))
        }
        // Parpadea mientras es invulnerable tras un golpe.
        if lives > 0, invuln <= 0 || Int(time * 12) % 2 == 0 {
            WatchAliens.drawShip(in: &ctx, at: CGPoint(x: px, y: py), size: 18, flame: sin(time * 30))
        }
        Spark.draw(sparks, in: &ctx)
        drawLives(lives, in: &ctx)
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
            return (px + side * 34 - 12) / max(1, size.width - 24)
        }
        guard let target = enemies.max(by: { $0.pos.y < $1.pos.y }) else { return 0.5 }
        return (target.pos.x - 12) / max(1, size.width - 24)
    }
}

struct WatchAliensView: View {
    var body: some View { WatchArcadeStage(info: WatchAliens.info, world: AlienWorld()) }
}

//
//  WatchPlanesView.swift — Quizzy Watch
//  Escuadrón: avión visto desde arriba sobre un mar que avanza hacia abajo. Dispara solo; la
//  Corona lo mueve de lado a lado. Enemigos: cazas (rectos), acróbatas (en zigzag) y bombarderos
//  (lentos, 4 impactos, disparan apuntando). Los bombarderos pueden soltar una «P» (triple
//  disparo durante 10 s) o un corazón (vida). 3 vidas; la dificultad sube cada 20 s.
//  Dibujos propios (formas en Canvas), sin insignias. Bucle y pantallas: `WatchArcadeStage`.
//

import SwiftUI

enum WatchPlanes {
    static var info: ArcadeInfo {
        ArcadeInfo(id: "planes", title: AppLanguage.text("Escuadrón", "Squadron"),
                   hint: AppLanguage.text("Gira la Corona", "Turn the Crown"), color: Color(hex: 0xF2C14E))
    }

    /// Avión visto desde arriba. `down` = morro hacia abajo (enemigos). `engines` = 2 para el bombardero.
    static func drawPlane(in ctx: inout GraphicsContext, at c: CGPoint, size s: CGFloat, body: Color, wing: Color,
                          down: Bool = false, engines: Int = 1, spin: CGFloat = 0) {
        var g = ctx
        g.translateBy(x: c.x, y: c.y)
        if down { g.scaleBy(x: 1, y: -1) }
        func rect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ r: CGFloat, _ color: Color) {
            g.fill(Path(roundedRect: CGRect(x: (x - w / 2) * s, y: (y - h / 2) * s, width: w * s, height: h * s), cornerRadius: r * s), with: .color(color))
        }
        rect(0, 0.42, 0.42, 0.14, 0.06, wing)                     // cola
        rect(0, -0.04, 1.0, 0.24, 0.1, wing)                      // ala
        if engines == 2 {
            rect(-0.3, -0.12, 0.13, 0.3, 0.05, body)              // motores
            rect(0.3, -0.12, 0.13, 0.3, 0.05, body)
        }
        rect(0, 0, 0.2, 1.0, 0.1, body)                           // fuselaje
        rect(0, -0.14, 0.11, 0.2, 0.05, Color(hex: 0x1B2233))     // cabina
        // Hélices: disco fino que «gira» cambiando de ancho.
        let blade = 0.16 + 0.1 * abs(sin(spin))
        if engines == 2 {
            rect(-0.3, -0.29, blade, 0.035, 0.01, .white.opacity(0.7))
            rect(0.3, -0.29, blade, 0.035, 0.01, .white.opacity(0.7))
        } else {
            rect(0, -0.52, blade * 1.5, 0.04, 0.01, .white.opacity(0.7))
        }
    }
}

final class SkyWorld: ArcadeWorld {
    enum Kind { case fighter, weaver, bomber }
    struct Enemy {
        var kind: Kind
        var p: CGPoint
        var baseX: CGFloat
        var hp: Int
        var t: CGFloat = 0
        var fireT: CGFloat = 1
    }
    struct Bullet { var p: CGPoint; var v: CGVector }
    enum PickupKind { case power, life }
    struct Pickup { var p: CGPoint; var kind: PickupKind }
    struct Island { var x: CGFloat; var y: CGFloat; var w: CGFloat; var h: CGFloat }

    private var size: CGSize = .zero
    private var enemies: [Enemy] = []
    private var shots: [Bullet] = []
    private var bullets: [Bullet] = []
    private var pickups: [Pickup] = []
    private var islands: [Island] = []
    private var sparks: [Spark] = []
    private var px: CGFloat = 0, py: CGFloat = 0
    private var lives = 3
    private var time: CGFloat = 0, scroll: CGFloat = 0
    private var fireT: CGFloat = 0, spawnT: CGFloat = 1, islandT: CGFloat = 2
    private var power: CGFloat = 0     // segundos de triple disparo
    private var invuln: CGFloat = 0
    private(set) var score = 0

    private var level: CGFloat { 1 + floor(time / 20) }

    func reset(size: CGSize) {
        self.size = size
        enemies = []; shots = []; bullets = []; pickups = []; sparks = []
        islands = [Island(x: size.width * 0.25, y: size.height * 0.3, w: 46, h: 30)]
        px = size.width / 2; py = size.height - 20
        lives = 3; time = 0; scroll = 0; score = 0
        fireT = 0.2; spawnT = 1; islandT = 3; power = 0; invuln = 0
    }

    func resize(_ size: CGSize) { self.size = size }

    func step(dt: CGFloat, input: CGFloat) -> ArcadeEvent {
        guard size.width > 0, lives > 0 else { return .none }
        var event = ArcadeEvent.none
        time += dt
        scroll += 42 * dt
        px = 13 + input * (size.width - 26)
        py = size.height - 20
        invuln = max(0, invuln - dt)
        power = max(0, power - dt)
        Spark.step(&sparks, dt: dt)

        // Fondo: islas que bajan con el mar.
        for i in islands.indices { islands[i].y += 42 * dt }
        islands.removeAll { $0.y - $0.h > size.height }
        islandT -= dt
        if islandT <= 0 {
            let w = CGFloat.random(in: 30...62)
            islands.append(Island(x: CGFloat.random(in: 10...(size.width - 10)), y: -w, w: w, h: w * CGFloat.random(in: 0.55...0.85)))
            islandT = CGFloat.random(in: 2.5...5)
        }

        // Disparo automático: doble; triple en abanico con la «P».
        fireT -= dt
        if fireT <= 0 {
            fireT = 0.22
            shots.append(Bullet(p: CGPoint(x: px - 4, y: py - 10), v: CGVector(dx: 0, dy: -300)))
            shots.append(Bullet(p: CGPoint(x: px + 4, y: py - 10), v: CGVector(dx: 0, dy: -300)))
            if power > 0 {
                shots.append(Bullet(p: CGPoint(x: px - 7, y: py - 6), v: CGVector(dx: -70, dy: -290)))
                shots.append(Bullet(p: CGPoint(x: px + 7, y: py - 6), v: CGVector(dx: 70, dy: -290)))
            }
        }
        for i in shots.indices { shots[i].p.x += shots[i].v.dx * dt; shots[i].p.y += shots[i].v.dy * dt }
        shots.removeAll { $0.p.y < -8 || $0.p.x < -8 || $0.p.x > size.width + 8 }

        // Enemigos nuevos.
        spawnT -= dt
        if spawnT <= 0 {
            spawnT = max(0.55, 1.45 - level * 0.09) * CGFloat.random(in: 0.75...1.25)
            let x = CGFloat.random(in: 16...(size.width - 16))
            let roll = CGFloat.random(in: 0..<1)
            if roll < 0.14 + min(0.1, level * 0.01) {
                enemies.append(Enemy(kind: .bomber, p: CGPoint(x: x, y: -18), baseX: x, hp: 4, fireT: 0.8))
            } else if roll < 0.45 {
                enemies.append(Enemy(kind: .weaver, p: CGPoint(x: x, y: -12), baseX: min(max(x, 44), size.width - 44), hp: 1))
            } else if roll < 0.6 {
                // Tres cazas en cuña.
                let cx = min(max(x, 34), size.width - 34)
                for (dx, dy) in [(0.0, 0.0), (-20.0, -14.0), (20.0, -14.0)] as [(CGFloat, CGFloat)] {
                    enemies.append(Enemy(kind: .fighter, p: CGPoint(x: cx + dx, y: -12 + dy), baseX: cx + dx, hp: 1))
                }
            } else {
                enemies.append(Enemy(kind: .fighter, p: CGPoint(x: x, y: -12), baseX: x, hp: 1))
            }
        }

        for i in enemies.indices {
            enemies[i].t += dt
            switch enemies[i].kind {
            case .fighter:
                enemies[i].p.y += (82 + level * 5) * dt
            case .weaver:
                enemies[i].p.y += (64 + level * 4) * dt
                enemies[i].p.x = enemies[i].baseX + sin(enemies[i].t * 3.2) * 30
            case .bomber:
                enemies[i].p.y += 34 * dt
                enemies[i].fireT -= dt
                if enemies[i].fireT <= 0, enemies[i].p.y > 0, enemies[i].p.y < py - 40 {
                    enemies[i].fireT = max(1.0, 1.9 - level * 0.08)
                    let dx = px - enemies[i].p.x, dy = py - enemies[i].p.y, d = max(1, hypot(dx, dy))
                    bullets.append(Bullet(p: enemies[i].p, v: CGVector(dx: dx / d * 95, dy: dy / d * 95)))
                }
            }
        }
        enemies.removeAll { $0.p.y > size.height + 24 }

        for i in bullets.indices { bullets[i].p.x += bullets[i].v.dx * dt; bullets[i].p.y += bullets[i].v.dy * dt }
        bullets.removeAll { $0.p.y > size.height + 8 || $0.p.x < -8 || $0.p.x > size.width + 8 }
        for i in pickups.indices { pickups[i].p.y += 46 * dt }
        pickups.removeAll { $0.p.y > size.height + 10 }

        // Disparos contra enemigos.
        for i in shots.indices.reversed() {
            let s = shots[i].p
            guard let j = enemies.firstIndex(where: {
                let r: CGFloat = $0.kind == .bomber ? 13 : 9
                return abs($0.p.x - s.x) < r && abs($0.p.y - s.y) < r
            }) else { continue }
            shots.remove(at: i)
            enemies[j].hp -= 1
            if enemies[j].hp > 0 {
                Spark.burst(&sparks, at: s, color: .white, count: 3)
                continue
            }
            let e = enemies.remove(at: j)
            switch e.kind {
            case .fighter: score += 10
            case .weaver: score += 15
            case .bomber:
                score += 50
                if CGFloat.random(in: 0..<1) < 0.4 {
                    pickups.append(Pickup(p: e.p, kind: lives < 3 && Bool.random() ? .life : .power))
                }
            }
            Spark.burst(&sparks, at: e.p, color: Color(hex: 0xF2B95C), count: e.kind == .bomber ? 16 : 9)
        }

        // Recoger premios.
        if let k = pickups.firstIndex(where: { abs($0.p.x - px) < 13 && abs($0.p.y - py) < 13 }) {
            switch pickups.remove(at: k).kind {
            case .power: power = 10
            case .life: lives = min(3, lives + 1)
            }
            event = .bonus
        }

        // Golpes al avión.
        if invuln <= 0 {
            var hit = false
            if let b = bullets.firstIndex(where: { abs($0.p.x - px) < 7 && abs($0.p.y - py) < 8 }) { bullets.remove(at: b); hit = true }
            if let j = enemies.firstIndex(where: { abs($0.p.x - px) < ($0.kind == .bomber ? 17 : 12) && abs($0.p.y - py) < 12 }) {
                Spark.burst(&sparks, at: enemies[j].p, color: Color(hex: 0xF2B95C))
                if enemies[j].kind != .bomber { enemies.remove(at: j) }
                hit = true
            }
            if hit {
                lives -= 1
                Spark.burst(&sparks, at: CGPoint(x: px, y: py), color: WatchPlanes.info.color, count: 14)
                invuln = 1.6
                bullets.removeAll()
                if lives <= 0 { return .dead }
                event = .hit
            }
        }
        return event
    }

    func draw(_ ctx: inout GraphicsContext, size: CGSize) {
        // Mar.
        ctx.fill(Path(CGRect(origin: .zero, size: size)),
                 with: .linearGradient(Gradient(colors: [Color(hex: 0x14355A), Color(hex: 0x1D4E7A)]),
                                       startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))
        for i in 0..<16 {   // crestas de ola que bajan
            let x = CGFloat((i * 67 + 13) % 100) / 100 * size.width
            let y = (CGFloat((i * 139 + 29) % 100) / 100 * size.height + scroll).truncatingRemainder(dividingBy: size.height)
            ctx.fill(Path(roundedRect: CGRect(x: x, y: y, width: 9, height: 1.4), cornerRadius: 0.7), with: .color(.white.opacity(0.16)))
        }
        for isle in islands {
            let rect = CGRect(x: isle.x - isle.w / 2, y: isle.y - isle.h / 2, width: isle.w, height: isle.h)
            ctx.fill(Path(ellipseIn: rect.insetBy(dx: -3, dy: -3)), with: .color(Color(hex: 0xD9C48A)))
            ctx.fill(Path(ellipseIn: rect), with: .color(Color(hex: 0x4E9A5A)))
            ctx.fill(Path(ellipseIn: rect.insetBy(dx: isle.w * 0.22, dy: isle.h * 0.22).offsetBy(dx: -isle.w * 0.08, dy: -isle.h * 0.06)),
                     with: .color(Color(hex: 0x3C7F49)))
        }
        for p in pickups {
            let rect = CGRect(x: p.p.x - 7, y: p.p.y - 7, width: 14, height: 14)
            switch p.kind {
            case .power:
                ctx.fill(Path(ellipseIn: rect), with: .color(Color(hex: 0xF2C14E)))
                ctx.draw(Text("P").font(.system(size: 10, weight: .black, design: .rounded)).foregroundColor(Color(hex: 0x10141D)), at: p.p)
            case .life:
                ctx.fill(Path(ellipseIn: rect), with: .color(.white))
                ctx.draw(Text("♥").font(.system(size: 9, weight: .black)).foregroundColor(Color(hex: 0xF0766B)), at: p.p)
            }
        }
        for e in enemies {
            switch e.kind {
            case .fighter:
                WatchPlanes.drawPlane(in: &ctx, at: e.p, size: 17, body: Color(hex: 0xC9534A), wing: Color(hex: 0xA03E38), down: true, spin: time * 40)
            case .weaver:
                WatchPlanes.drawPlane(in: &ctx, at: e.p, size: 17, body: Color(hex: 0x9C7BD6), wing: Color(hex: 0x7558AE), down: true, spin: time * 40)
            case .bomber:
                WatchPlanes.drawPlane(in: &ctx, at: e.p, size: 30, body: Color(hex: 0x7C8F86), wing: Color(hex: 0x5E7068), down: true, engines: 2, spin: time * 40)
            }
        }
        for s in shots {
            ctx.fill(Path(roundedRect: CGRect(x: s.p.x - 1.1, y: s.p.y - 4, width: 2.2, height: 8), cornerRadius: 1.1), with: .color(Color(hex: 0xFFF2B0)))
        }
        for b in bullets {
            ctx.fill(Path(ellipseIn: CGRect(x: b.p.x - 2.6, y: b.p.y - 2.6, width: 5.2, height: 5.2)), with: .color(Color(hex: 0xFF8A6B)))
            ctx.fill(Path(ellipseIn: CGRect(x: b.p.x - 1.1, y: b.p.y - 1.1, width: 2.2, height: 2.2)), with: .color(.white))
        }
        if lives > 0, invuln <= 0 || Int(time * 12) % 2 == 0 {
            // Sombra sobre el mar + avión.
            ctx.fill(Path(ellipseIn: CGRect(x: px - 2, y: py + 8, width: 18, height: 7)), with: .color(.black.opacity(0.18)))
            WatchPlanes.drawPlane(in: &ctx, at: CGPoint(x: px, y: py), size: 22, body: Color(hex: 0xF2C14E), wing: Color(hex: 0xD99E2B), spin: time * 40)
        }
        Spark.draw(sparks, in: &ctx)
        drawLives(lives, in: &ctx, width: size.width)
        if power > 0 {
            // Barra de lo que queda de triple disparo.
            ctx.fill(Path(roundedRect: CGRect(x: size.width - 44, y: 6, width: 38 * power / 10, height: 4), cornerRadius: 2), with: .color(Color(hex: 0xF2C14E)))
        }
    }

    func autopilot() -> CGFloat {
        let span = max(1, size.width - 26)
        if let b = bullets.filter({ abs($0.p.x - px) < 12 && $0.p.y < py && py - $0.p.y < 60 }).max(by: { $0.p.y < $1.p.y }) {
            return (px + (b.p.x >= px ? -28 : 28) - 13) / span
        }
        if let p = pickups.first { return (p.p.x - 13) / span }
        // Se pone bajo el enemigo más cercano, salvo que esté a punto de chocar: entonces se aparta.
        guard let e = enemies.filter({ $0.p.y < py }).max(by: { $0.p.y < $1.p.y }) else { return 0.5 }
        if py - e.p.y < 34 { return (e.p.x + (e.p.x >= px ? -36 : 36) - 13) / span }
        return (e.p.x - 13) / span
    }
}

struct WatchPlanesView: View {
    var body: some View { WatchArcadeStage(info: WatchPlanes.info, world: SkyWorld()) }
}

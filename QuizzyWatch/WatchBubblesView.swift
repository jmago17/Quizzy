//
//  WatchBubblesView.swift — Quizzy Watch
//  Pompas: pompas que rebotan por la pantalla; el erizo dispara solo un pincho con cuerda hacia
//  arriba y la Corona lo mueve de lado a lado. Una pompa grande se parte en dos medianas, y cada
//  mediana en dos pequeñas. Que una pompa te toque cuesta una vida (3). Al limpiar la pantalla
//  llega otra tanda con más pompas y más rápidas.
//  Puntos: 10 / 20 / 30 por pompa grande / mediana / pequeña, 100 por pantalla.
//  Dibujos propios (formas en Canvas). Bucle y pantallas: `WatchArcadeStage`.
//

import SwiftUI

enum WatchBubbles {
    static var info: ArcadeInfo {
        ArcadeInfo(id: "bubbles", title: AppLanguage.text("Pompas", "Bubbles"),
                   hint: AppLanguage.text("Gira la Corona", "Turn the Crown"), color: Color(hex: 0xC59BFF))
    }
    static let radius: [CGFloat] = [17, 11, 6.5]
    static let colors: [UInt32] = [0xF28FB5, 0x8FC2F2, 0x7BE08A]

    static func drawBubble(in ctx: inout GraphicsContext, at c: CGPoint, radius r: CGFloat, tier: Int) {
        let color = Color(hex: colors[tier % colors.count])
        let rect = CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)
        ctx.fill(Path(ellipseIn: rect), with: .color(color.opacity(0.55)))
        ctx.stroke(Path(ellipseIn: rect.insetBy(dx: 0.6, dy: 0.6)), with: .color(color), lineWidth: 1.2)
        ctx.fill(Path(ellipseIn: CGRect(x: c.x - r * 0.55, y: c.y - r * 0.62, width: r * 0.5, height: r * 0.34)), with: .color(.white.opacity(0.7)))
    }

    /// El erizo, de frente. `feet` = punto de apoyo.
    static func drawHedgehog(in ctx: inout GraphicsContext, feet: CGPoint, size s: CGFloat) {
        let spikes = Color(hex: 0x7A5A44), face = Color(hex: 0xEBCFA8), dark = Color(hex: 0x2A1E1A)
        for k in -3...3 {   // púas
            let x = feet.x + CGFloat(k) * s * 0.14
            var spike = Path()
            spike.move(to: CGPoint(x: x - s * 0.10, y: feet.y - s * 0.55))
            spike.addLine(to: CGPoint(x: x + CGFloat(k) * s * 0.03, y: feet.y - s * (1.02 - abs(CGFloat(k)) * 0.07)))
            spike.addLine(to: CGPoint(x: x + s * 0.10, y: feet.y - s * 0.55))
            ctx.fill(spike, with: .color(spikes))
        }
        ctx.fill(Path(ellipseIn: CGRect(x: feet.x - s * 0.5, y: feet.y - s * 0.78, width: s, height: s * 0.78)), with: .color(spikes))
        ctx.fill(Path(ellipseIn: CGRect(x: feet.x - s * 0.33, y: feet.y - s * 0.56, width: s * 0.66, height: s * 0.54)), with: .color(face))
        for side in [-1.0, 1.0] as [CGFloat] {
            ctx.fill(Path(ellipseIn: CGRect(x: feet.x + side * s * 0.15 - s * 0.05, y: feet.y - s * 0.42, width: s * 0.10, height: s * 0.12)), with: .color(dark))
        }
        ctx.fill(Path(ellipseIn: CGRect(x: feet.x - s * 0.06, y: feet.y - s * 0.28, width: s * 0.12, height: s * 0.09)), with: .color(dark))
    }
}

final class BubbleWorld: ArcadeWorld {
    struct Ball { var p: CGPoint; var v: CGVector; var tier: Int }
    private static let gravity: CGFloat = 300
    private static let bounce: [CGFloat] = [250, 215, 175]   // alturas ≈ 104, 77 y 51 pt
    private static let drift: [CGFloat] = [32, 40, 48]
    private static let ceiling: CGFloat = 16

    private var size: CGSize = .zero
    private var balls: [Ball] = []
    private var sparks: [Spark] = []
    private var px: CGFloat = 0
    private var harpoonX: CGFloat = 0
    private var harpoonTip: CGFloat?      // y de la punta; nil = sin disparo
    private var reload: CGFloat = 0.4
    private var lives = 3
    private var level = 1
    private var time: CGFloat = 0
    private var invuln: CGFloat = 0
    private var cleared = false, levelDelay: CGFloat = 0
    private(set) var score = 0

    private var floorY: CGFloat { size.height - 6 }
    private var speedUp: CGFloat { 1 + 0.06 * CGFloat(level - 1) }

    func reset(size: CGSize) {
        self.size = size
        sparks = []; px = size.width / 2
        harpoonTip = nil; reload = 0.4
        lives = 3; level = 1; time = 0; score = 0; cleared = false; levelDelay = 0
        spawn()
    }

    func resize(_ size: CGSize) { self.size = size }

    private func spawn() {
        // 1 grande; luego se suman grandes (hasta 3) y, en las pantallas pares, una mediana.
        var tiers = Array(repeating: 0, count: min(1 + (level - 1) / 2, 3))
        if level % 2 == 0 { tiers.append(1) }
        balls = tiers.enumerated().map { i, tier in
            let x = size.width * CGFloat(i + 1) / CGFloat(tiers.count + 1)
            return Ball(p: CGPoint(x: x, y: 46), v: CGVector(dx: Self.drift[tier] * speedUp * (i % 2 == 0 ? 1 : -1), dy: 0), tier: tier)
        }
        invuln = 1.5   // respiro al empezar cada pantalla
    }

    func step(dt: CGFloat, input: CGFloat) -> ArcadeEvent {
        guard size.width > 0, lives > 0 else { return .none }
        var event = ArcadeEvent.none
        time += dt
        px = 10 + input * (size.width - 20)
        invuln = max(0, invuln - dt)
        Spark.step(&sparks, dt: dt)

        if balls.isEmpty {
            if !cleared { cleared = true; levelDelay = 1.2; score += 100; event = .bonus }
            levelDelay -= dt
            if levelDelay <= 0 { level += 1; cleared = false; spawn() }
        }

        // Pincho: sube desde donde estaba el erizo al disparar; al llegar arriba, recarga.
        if let tip = harpoonTip {
            let y = tip - 300 * dt
            harpoonTip = y < Self.ceiling ? nil : y
            if harpoonTip == nil { reload = 0.12 }
        } else {
            reload -= dt
            if reload <= 0, !balls.isEmpty { harpoonX = px; harpoonTip = floorY - 16 }
        }

        for i in balls.indices {
            let r = WatchBubbles.radius[balls[i].tier]
            balls[i].v.dy += Self.gravity * dt
            balls[i].p.x += balls[i].v.dx * dt
            balls[i].p.y += balls[i].v.dy * dt
            if balls[i].p.x < r { balls[i].p.x = r; balls[i].v.dx = abs(balls[i].v.dx) }
            if balls[i].p.x > size.width - r { balls[i].p.x = size.width - r; balls[i].v.dx = -abs(balls[i].v.dx) }
            if balls[i].p.y > floorY - r { balls[i].p.y = floorY - r; balls[i].v.dy = -Self.bounce[balls[i].tier] }
            if balls[i].p.y < Self.ceiling + r { balls[i].p.y = Self.ceiling + r; balls[i].v.dy = abs(balls[i].v.dy) }
        }

        // Pincho contra pompas: vale toda la cuerda, no solo la punta.
        if let tip = harpoonTip,
           let i = balls.firstIndex(where: { abs($0.p.x - harpoonX) < WatchBubbles.radius[$0.tier] + 1.5 && $0.p.y + WatchBubbles.radius[$0.tier] > tip }) {
            let b = balls.remove(at: i)
            score += 10 * (b.tier + 1)
            Spark.burst(&sparks, at: b.p, color: Color(hex: WatchBubbles.colors[b.tier]), count: 7)
            if b.tier < 2 {
                let speed = Self.drift[b.tier + 1] * speedUp
                for side in [-1.0, 1.0] as [CGFloat] {
                    balls.append(Ball(p: CGPoint(x: b.p.x + side * 4, y: b.p.y), v: CGVector(dx: side * speed, dy: -150), tier: b.tier + 1))
                }
            }
            harpoonTip = nil; reload = 0.12
        }

        // Pompa contra erizo.
        if invuln <= 0, balls.contains(where: { hypot($0.p.x - px, $0.p.y - (floorY - 8)) < WatchBubbles.radius[$0.tier] + 5 }) {
            lives -= 1
            Spark.burst(&sparks, at: CGPoint(x: px, y: floorY - 8), color: .white, count: 12)
            invuln = 1.8
            if lives <= 0 { return .dead }
            event = .hit
        }
        return event
    }

    func draw(_ ctx: inout GraphicsContext, size: CGSize) {
        ctx.fill(Path(CGRect(x: 0, y: floorY, width: size.width, height: size.height - floorY)), with: .color(Color(hex: 0x4E9A5A)))
        ctx.fill(Path(CGRect(x: 0, y: floorY, width: size.width, height: 1.5)), with: .color(Color(hex: 0x7BE08A)))
        if let tip = harpoonTip {
            var rope = Path()
            var y = floorY, k = 0
            rope.move(to: CGPoint(x: harpoonX, y: y))
            while y > tip + 4 { y -= 4; k += 1; rope.addLine(to: CGPoint(x: harpoonX + (k % 2 == 0 ? -1.2 : 1.2), y: y)) }
            ctx.stroke(rope, with: .color(Color(hex: 0xE8D9A0)), lineWidth: 1.2)
            var head = Path()
            head.move(to: CGPoint(x: harpoonX, y: tip - 4))
            head.addLine(to: CGPoint(x: harpoonX - 3.2, y: tip + 3)); head.addLine(to: CGPoint(x: harpoonX + 3.2, y: tip + 3))
            head.closeSubpath()
            ctx.fill(head, with: .color(.white))
        }
        for b in balls { WatchBubbles.drawBubble(in: &ctx, at: b.p, radius: WatchBubbles.radius[b.tier], tier: b.tier) }
        if lives > 0, invuln <= 0 || Int(time * 12) % 2 == 0 {
            WatchBubbles.drawHedgehog(in: &ctx, feet: CGPoint(x: px, y: floorY), size: 18)
        }
        Spark.draw(sparks, in: &ctx)
        drawLives(lives, in: &ctx, width: size.width)
        if cleared {
            ctx.draw(Text(AppLanguage.text("Pantalla \(level + 1)", "Stage \(level + 1)"))
                .font(.system(size: 15, weight: .heavy, design: .rounded)).foregroundColor(WatchBubbles.info.color),
                     at: CGPoint(x: size.width / 2, y: size.height * 0.4))
        }
    }

    func autopilot() -> CGFloat {
        let span = max(1, size.width - 20)
        // Si una pompa baja cerca, se aparta; si no, se pone bajo la más baja.
        if let b = balls.filter({ abs($0.p.x - px) < WatchBubbles.radius[$0.tier] + 16 && $0.p.y > floorY - 62 }).max(by: { $0.p.y < $1.p.y }) {
            let away: CGFloat = px < 34 ? 1 : (px > size.width - 34 ? -1 : (b.v.dx > 0 ? -1 : 1))
            return (px + away * 40 - 10) / span
        }
        guard let target = balls.max(by: { $0.p.y < $1.p.y }) else { return 0.5 }
        return (target.p.x + target.v.dx * 0.3 - 10) / span
    }
}

struct WatchBubblesView: View {
    var body: some View { WatchArcadeStage(info: WatchBubbles.info, world: BubbleWorld()) }
}

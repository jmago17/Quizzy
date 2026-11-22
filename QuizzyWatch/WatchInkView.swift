//
//  WatchInkView.swift — Quizzy Watch
//  Tintazo: el pulpo dispara tinta a los cangrejos. La Corona elige el ÁNGULO; la fuerza sube y
//  baja sola (se ve en la línea de puntos, que se alarga y se encoge) y un toque en la pantalla
//  dispara con la que haya en ese momento. Por turnos: no hay prisa.
//  Cada nivel da (cangrejos + 2) disparos. Limpiarlo: 10 por cangrejo y 5 por disparo sobrante.
//  Quedarse sin tinta con cangrejos vivos cuesta una vida (3) y el nivel se repite con otro reparto.
//  Rocas y repisas paran la tinta. No hay estructuras que se derrumben: a propósito (ver CLAUDE.md).
//  Todo nivel generado se comprueba con el mismo simulador del disparo: siempre tiene solución.
//  Dibujos propios (el pulpo y el cangrejo de Brinco). Bucle y pantallas: `WatchArcadeStage`.
//

import SwiftUI

enum WatchInk {
    static var info: ArcadeInfo {
        ArcadeInfo(id: "ink", title: AppLanguage.text("Tintazo", "Ink Shot"),
                   hint: AppLanguage.text("Apunta y toca", "Aim and tap"), color: Color(hex: 0xB58CFF))
    }
    static let ink = Color(hex: 0xB58CFF)

    static func drawBlob(in ctx: inout GraphicsContext, at c: CGPoint, radius r: CGFloat) {
        ctx.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)), with: .color(ink))
        ctx.fill(Path(ellipseIn: CGRect(x: c.x - r * 0.5, y: c.y - r * 0.6, width: r * 0.5, height: r * 0.4)), with: .color(.white.opacity(0.6)))
    }
}

final class InkWorld: ArcadeWorld {
    struct Target { var base: CGPoint; var alive = true }
    struct Shot { var p: CGPoint; var v: CGVector }
    struct Splat { var p: CGPoint; var life: CGFloat }
    private enum Outcome { case target(Int), splat, gone }
    private enum Pending { case nextLevel, retry }

    static let gravity: CGFloat = 260
    static let vMin: CGFloat = 115, vMax: CGFloat = 240
    static let period: CGFloat = 1.7          // segundos de un vaivén completo de la fuerza
    private static let hitRadius: CGFloat = 10

    private var size: CGSize = .zero
    private var targets: [Target] = []
    private var rocks: [CGRect] = []          // muro y repisas: paran la tinta
    private var shot: Shot?
    private var splats: [Splat] = []
    private var sparks: [Spark] = []
    private var shotsLeft = 0
    private var lives = 3
    private var level = 0
    private var time: CGFloat = 0
    private var input: CGFloat = 0.5
    private var wait: CGFloat = 0
    private var pending: Pending?
    private var plan: (input: CGFloat, v: CGFloat)?
    private(set) var score = 0

    // Suelo a 24 pt del fondo y todo a 15 pt de los lados: las esquinas de la pantalla son redondas.
    private var floorY: CGFloat { size.height - 24 }
    private var muzzle: CGPoint { CGPoint(x: 27, y: floorY - 19) }
    private var angle: CGFloat { Self.angle(input) }
    private static func angle(_ input: CGFloat) -> CGFloat { (12 + 68 * min(1, max(0, input))) * .pi / 180 }
    private var power: CGFloat {
        let p = (time / Self.period).truncatingRemainder(dividingBy: 1)
        return Self.vMin + (Self.vMax - Self.vMin) * (1 - abs(2 * p - 1))
    }
    private func launch(angle: CGFloat, v: CGFloat) -> Shot {
        Shot(p: muzzle, v: CGVector(dx: cos(angle) * v, dy: -sin(angle) * v))
    }

    func reset(size: CGSize) {
        self.size = size
        lives = 3; level = 0; score = 0; time = 0; wait = 0; pending = nil
        shot = nil; splats = []; sparks = []
        buildLevel()
    }

    func resize(_ size: CGSize) {
        guard size != self.size else { return }
        self.size = size
        if shot == nil { buildLevel() }
    }

    private func buildLevel() {
        guard size.width > 0 else { return }
        plan = nil
        let count = min(1 + level / 2, 3)
        for _ in 0..<30 {
            rocks = []; targets = []
            if level >= 2 {
                let h = CGFloat.random(in: 28...min(78, 34 + CGFloat(level) * 5))
                rocks.append(CGRect(x: size.width * CGFloat.random(in: 0.34...0.44), y: floorY - h, width: 9, height: h))
            }
            var xs: [CGFloat] = []
            var tries = 0
            while xs.count < count, tries < 60 {
                tries += 1
                let x = CGFloat.random(in: (size.width * 0.52)...(size.width - 26))
                if xs.allSatisfy({ abs($0 - x) > 30 }) { xs.append(x) }
            }
            for x in xs {
                if level >= 1, Bool.random() {
                    let y = floorY - CGFloat.random(in: 30...min(95, floorY - 60))
                    rocks.append(CGRect(x: x - 13, y: y, width: 26, height: 5))
                    targets.append(Target(base: CGPoint(x: x, y: y)))
                } else {
                    targets.append(Target(base: CGPoint(x: x, y: floorY)))
                }
            }
            if targets.count == count, targets.indices.allSatisfy({ solution(for: $0) != nil }) { break }
        }
        shotsLeft = targets.count + 2
    }

    /// Avanza un disparo un paso. nil = sigue volando.
    private func advance(_ s: inout Shot, dt: CGFloat) -> Outcome? {
        s.v.dy += Self.gravity * dt
        s.p.x += s.v.dx * dt
        s.p.y += s.v.dy * dt
        for (i, t) in targets.enumerated() where t.alive {
            if hypot(s.p.x - t.base.x, s.p.y - (t.base.y - 6)) < Self.hitRadius { return .target(i) }
        }
        if s.p.y >= floorY || rocks.contains(where: { $0.insetBy(dx: -2, dy: -2).contains(s.p) }) { return .splat }
        if s.p.x > size.width + 12 || s.p.x < -12 { return .gone }
        return nil
    }

    /// Ángulo (como entrada 0…1) y fuerza que aciertan al cangrejo `index`, si existen.
    private func solution(for index: Int) -> (input: CGFloat, v: CGFloat)? {
        for a in stride(from: CGFloat(0.02), through: 0.98, by: 0.03) {
            for v in stride(from: Self.vMin + 4, through: Self.vMax - 4, by: 6) {
                var s = launch(angle: Self.angle(a), v: v)
                for _ in 0..<420 {
                    guard let out = advance(&s, dt: 1.0 / 60) else { continue }
                    if case .target(let hit) = out, hit == index { return (a, v) }
                    break
                }
            }
        }
        return nil
    }

    func tap() {
        guard shot == nil, wait <= 0, shotsLeft > 0, lives > 0 else { return }
        shotsLeft -= 1
        shot = launch(angle: angle, v: power)
        plan = nil
        WHaptics.tick()
    }

    func step(dt: CGFloat, input: CGFloat) -> ArcadeEvent {
        guard size.width > 0, lives > 0 else { return .none }
        self.input = input
        time += dt
        Spark.step(&sparks, dt: dt)
        for i in splats.indices { splats[i].life -= dt }
        splats.removeAll { $0.life <= 0 }

        if wait > 0 {
            wait -= dt
            if wait <= 0, let what = pending {
                pending = nil
                if what == .nextLevel { level += 1 }
                buildLevel()
            }
            return .none
        }
        guard var s = shot else { return .none }
        var event = ArcadeEvent.none
        var out: Outcome?
        for _ in 0..<2 where out == nil { out = advance(&s, dt: dt / 2) }
        shot = s
        guard let result = out else { return .none }
        shot = nil
        switch result {
        case .target(let i):
            targets[i].alive = false
            score += 10
            Spark.burst(&sparks, at: CGPoint(x: targets[i].base.x, y: targets[i].base.y - 6), color: WatchInk.ink, count: 12)
            event = .bonus
        case .splat:
            splats.append(Splat(p: s.p, life: 1.2))
            Spark.burst(&sparks, at: s.p, color: WatchInk.ink, count: 5)
        case .gone: break
        }
        if targets.allSatisfy({ !$0.alive }) {
            score += shotsLeft * 5
            pending = .nextLevel; wait = 0.9
        } else if shotsLeft == 0 {
            lives -= 1
            if lives <= 0 { return .dead }
            pending = .retry; wait = 0.9
            event = .hit
        }
        return event
    }

    func draw(_ ctx: inout GraphicsContext, size: CGSize) {
        // Fondo de arena.
        ctx.fill(Path(CGRect(x: 0, y: floorY, width: size.width, height: size.height - floorY)), with: .color(Color(hex: 0x8A7350)))
        ctx.fill(Path(CGRect(x: 0, y: floorY, width: size.width, height: 2)), with: .color(Color(hex: 0xB89C6E)))
        for r in rocks {
            ctx.fill(Path(roundedRect: r, cornerRadius: 2.5), with: .color(Color(hex: 0x5E687A)))
            ctx.fill(Path(CGRect(x: r.minX + 1, y: r.minY + 1, width: r.width - 2, height: 1.2)), with: .color(.white.opacity(0.3)))
        }
        for s in splats {
            ctx.fill(Path(ellipseIn: CGRect(x: s.p.x - 6, y: s.p.y - 2.5, width: 12, height: 5)), with: .color(WatchInk.ink.opacity(min(0.8, s.life))))
        }
        for t in targets where t.alive { Crab.draw(in: &ctx, base: t.base, size: 16, phase: time * 2) }

        if lives > 0 {
            // Puntería: el principio de la trayectoria con la fuerza de este instante.
            if shot == nil, wait <= 0, shotsLeft > 0 {
                var s = launch(angle: angle, v: power)
                for i in 1...24 {
                    s.v.dy += Self.gravity / 60; s.p.x += s.v.dx / 60; s.p.y += s.v.dy / 60
                    if i % 3 == 0 {
                        let r = 1.7 - CGFloat(i) * 0.03
                        ctx.fill(Path(ellipseIn: CGRect(x: s.p.x - r, y: s.p.y - r, width: r * 2, height: r * 2)), with: .color(.white.opacity(0.85)))
                    }
                }
            }
            Octopus.draw(in: &ctx, feet: CGPoint(x: 24, y: floorY), size: 22, squash: shot != nil ? 0.5 : 0, time: time)
        }
        if let s = shot { WatchInk.drawBlob(in: &ctx, at: s.p, radius: 3.6) }
        // Tinta que queda, bajo el suelo.
        for i in 0..<max(0, shotsLeft) {
            WatchInk.drawBlob(in: &ctx, at: CGPoint(x: 44 + CGFloat(i) * 9, y: floorY + 11), radius: 2.8)
        }
        Spark.draw(sparks, in: &ctx)
        drawLives(lives, in: &ctx, width: size.width)
    }

    /// El piloto apunta al primer cangrejo vivo y dispara él mismo cuando ángulo y fuerza cuadran.
    func autopilot() -> CGFloat {
        guard shot == nil, wait <= 0, let index = targets.firstIndex(where: { $0.alive }) else { return input }
        if plan == nil { plan = solution(for: index) ?? (0.6, 180) }
        guard let plan else { return input }
        if abs(input - plan.input) < 0.004, abs(power - plan.v) < 5 { tap() }
        return plan.input
    }
}

struct WatchInkView: View {
    var body: some View { WatchArcadeStage(info: WatchInk.info, world: InkWorld()) }
}

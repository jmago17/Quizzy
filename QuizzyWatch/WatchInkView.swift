//
//  WatchInkView.swift — Quizzy Watch
//  Tintazo: el pulpo dispara tinta a los cangrejos. La Corona elige el ÁNGULO (una flecha lo
//  marca). Para disparar se MANTIENE el dedo en la pantalla: la fuerza carga despacio (barra
//  sobre el pulpo y línea de puntos que crece) y al SOLTAR sale el disparo. Si se mantiene de
//  más, la fuerza vuelve a bajar. Por turnos: no hay prisa.
//  (Hasta el 2026-11-23 la fuerza oscilaba sola y se disparaba con un toque: Josu lo encontró
//  rápido y poco intuitivo. Cargar y soltar va DESPUÉS de apuntar, así que no hay que girar la
//  Corona con el dedo apoyado, que era el motivo por el que se había descartado.)
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
                   hint: AppLanguage.text("Apunta, mantén y suelta", "Aim, hold, release"), color: Color(hex: 0xB58CFF))
    }
    static let ink = Color(hex: 0xB58CFF)
    static let deep = Color(hex: 0x0A2A45), shallow = Color(hex: 0x14506E)

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
    static let chargeTime: CGFloat = 1.5      // segundos de mínimo a máximo manteniendo el dedo
    static var usesPress: Bool { true }
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
    private var charging = false
    private var charge: CGFloat = 0           // segundos con el dedo apoyado
    private var banner: CGFloat = 0
    private var bannerText = ""
    private(set) var score = 0

    // Suelo a 24 pt del fondo y todo a 15 pt de los lados: las esquinas de la pantalla son redondas.
    private var floorY: CGFloat { size.height - 24 }
    private var muzzle: CGPoint { CGPoint(x: 27, y: floorY - 19) }
    private var angle: CGFloat { Self.angle(input) }
    private static func angle(_ input: CGFloat) -> CGFloat { (12 + 68 * min(1, max(0, input))) * .pi / 180 }
    /// Fuerza cargada, 0…1: sube en `chargeTime` y, si se sigue manteniendo, baja y vuelve a subir.
    private var chargeLevel: CGFloat {
        let p = (charge / (Self.chargeTime * 2)).truncatingRemainder(dividingBy: 1)
        return 1 - abs(2 * p - 1)
    }
    private var power: CGFloat { Self.vMin + (Self.vMax - Self.vMin) * chargeLevel }
    private func launch(angle: CGFloat, v: CGFloat) -> Shot {
        Shot(p: muzzle, v: CGVector(dx: cos(angle) * v, dy: -sin(angle) * v))
    }

    func reset(size: CGSize) {
        self.size = size
        lives = 3; level = 0; score = 0; time = 0; wait = 0; pending = nil
        shot = nil; splats = []; sparks = []
        charging = false; charge = 0; banner = 1.6; bannerText = AppLanguage.text("Nivel 1", "Level 1")
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

    private var canShoot: Bool { shot == nil && wait <= 0 && shotsLeft > 0 && lives > 0 }

    func press(_ down: Bool) {
        if down {
            guard canShoot else { return }
            charging = true; charge = 0
        } else if charging {
            charging = false
            guard canShoot else { return }
            shotsLeft -= 1
            shot = launch(angle: angle, v: power)
            plan = nil
            WHaptics.tick()
        }
    }

    func step(dt: CGFloat, input: CGFloat) -> ArcadeEvent {
        guard size.width > 0, lives > 0 else { return .none }
        self.input = input
        time += dt
        banner = max(0, banner - dt)
        if charging { charge += dt }
        Spark.step(&sparks, dt: dt)
        for i in splats.indices { splats[i].life -= dt }
        splats.removeAll { $0.life <= 0 }

        if wait > 0 {
            wait -= dt
            if wait <= 0, let what = pending {
                pending = nil
                if what == .nextLevel { level += 1 }
                banner = 1.4
                bannerText = what == .nextLevel ? AppLanguage.text("Nivel \(level + 1)", "Level \(level + 1)") : AppLanguage.text("Otra vez", "Try again")
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
        drawSea(&ctx, size: size)
        for r in rocks { drawRock(&ctx, r) }
        for s in splats {
            ctx.fill(Path(ellipseIn: CGRect(x: s.p.x - 7, y: s.p.y - 3, width: 14, height: 6)), with: .color(WatchInk.ink.opacity(min(0.8, s.life))))
            ctx.fill(Path(ellipseIn: CGRect(x: s.p.x + 5, y: s.p.y - 5, width: 4, height: 3)), with: .color(WatchInk.ink.opacity(min(0.6, s.life))))
        }
        for t in targets where t.alive { Crab.draw(in: &ctx, base: t.base, size: 16, phase: time * 2) }

        if lives > 0 {
            if canShoot {
                if charging {
                    // Cargando: la trayectoria con la fuerza de este instante, cada vez más larga.
                    var s = launch(angle: angle, v: power)
                    let steps = 14 + Int(chargeLevel * 34)
                    for i in 1...steps {
                        s.v.dy += Self.gravity / 60; s.p.x += s.v.dx / 60; s.p.y += s.v.dy / 60
                        if i % 3 == 0 {
                            let r = max(0.9, 2 - CGFloat(i) * 0.022)
                            ctx.fill(Path(ellipseIn: CGRect(x: s.p.x - r, y: s.p.y - r, width: r * 2, height: r * 2)), with: .color(.white.opacity(0.9)))
                        }
                    }
                } else {
                    // Apuntando: flecha fija en la dirección del disparo.
                    let a = angle, from = muzzle
                    let tip = CGPoint(x: from.x + cos(a) * 30, y: from.y - sin(a) * 30)
                    var aim = Path()
                    aim.move(to: CGPoint(x: from.x + cos(a) * 9, y: from.y - sin(a) * 9)); aim.addLine(to: tip)
                    ctx.stroke(aim, with: .color(.white.opacity(0.85)), style: StrokeStyle(lineWidth: 1.6, lineCap: .round, dash: [3, 4]))
                    var head = Path()
                    head.move(to: CGPoint(x: tip.x + cos(a + 2.6) * 6, y: tip.y - sin(a + 2.6) * 6)); head.addLine(to: tip)
                    head.addLine(to: CGPoint(x: tip.x + cos(a - 2.6) * 6, y: tip.y - sin(a - 2.6) * 6))
                    ctx.stroke(head, with: .color(.white), style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
                }
            }
            Octopus.draw(in: &ctx, feet: CGPoint(x: 24, y: floorY), size: 22, squash: charging ? 0.3 + chargeLevel * 0.6 : (shot != nil ? 0.4 : 0), time: time)
            // Barra de fuerza, sobre el pulpo.
            let bar = CGRect(x: 10, y: floorY - 38, width: 30, height: 5)
            ctx.fill(Path(roundedRect: bar.insetBy(dx: -1, dy: -1), cornerRadius: 3.5), with: .color(.black.opacity(0.45)))
            if charging {
                let level = chargeLevel
                let color = level > 0.8 ? Color(hex: 0xF0766B) : (level > 0.5 ? Color(hex: 0xF2C14E) : Color(hex: 0x6FD08C))
                ctx.fill(Path(roundedRect: CGRect(x: bar.minX, y: bar.minY, width: max(3, bar.width * level), height: bar.height), cornerRadius: 2.5), with: .color(color))
            }
        }
        if let s = shot {
            // Tinta en vuelo, con una estela corta.
            for k in 1...3 {
                let back = CGFloat(k) * 0.018
                WatchInk.drawBlob(in: &ctx, at: CGPoint(x: s.p.x - s.v.dx * back, y: s.p.y - s.v.dy * back), radius: 3.4 - CGFloat(k) * 0.8)
            }
            WatchInk.drawBlob(in: &ctx, at: s.p, radius: 3.8)
        }
        // Tinta que queda: tarros en la arena.
        for i in 0..<max(0, shotsLeft) {
            let c = CGPoint(x: 46 + CGFloat(i) * 10, y: floorY + 11)
            ctx.fill(Path(ellipseIn: CGRect(x: c.x - 3.8, y: c.y - 3.8, width: 7.6, height: 7.6)), with: .color(.black.opacity(0.35)))
            WatchInk.drawBlob(in: &ctx, at: c, radius: 3)
        }
        Spark.draw(sparks, in: &ctx)
        drawLives(lives, in: &ctx, width: size.width)
        if banner > 0 {
            ctx.draw(Text(bannerText).font(.system(size: 17, weight: .black, design: .rounded))
                .foregroundColor(.white.opacity(Double(min(1, banner * 2)))), at: CGPoint(x: size.width / 2, y: size.height * 0.3))
        }
    }

    /// Fondo marino: agua con degradado, rayos de luz, algas al fondo, burbujas y arena con relieve.
    private func drawSea(_ ctx: inout GraphicsContext, size: CGSize) {
        ctx.fill(Path(CGRect(x: 0, y: -40, width: size.width, height: floorY + 40)),
                 with: .linearGradient(Gradient(colors: [WatchInk.shallow, WatchInk.deep]), startPoint: .zero, endPoint: CGPoint(x: 0, y: floorY)))
        for k in 0..<3 {
            let x0 = size.width * (0.25 + CGFloat(k) * 0.27) + sin(time * 0.4 + CGFloat(k)) * 6
            var ray = Path()
            ray.move(to: CGPoint(x: x0, y: -40)); ray.addLine(to: CGPoint(x: x0 + 16, y: -40))
            ray.addLine(to: CGPoint(x: x0 - 26, y: floorY)); ray.addLine(to: CGPoint(x: x0 - 52, y: floorY)); ray.closeSubpath()
            ctx.fill(ray, with: .linearGradient(Gradient(colors: [.white.opacity(0.09), .white.opacity(0)]),
                                                startPoint: CGPoint(x: 0, y: 0), endPoint: CGPoint(x: 0, y: floorY)))
        }
        // Algas lejanas (siluetas) que se mecen.
        for k in 0..<7 {
            let x = size.width * (0.08 + CGFloat(k) * 0.145), h = CGFloat(22 + (k * 37) % 26)
            let sway = sin(time * 1.2 + CGFloat(k) * 1.7) * 5
            var weed = Path()
            weed.move(to: CGPoint(x: x - 3, y: floorY))
            weed.addQuadCurve(to: CGPoint(x: x + sway, y: floorY - h), control: CGPoint(x: x - 6 - sway * 0.3, y: floorY - h * 0.5))
            weed.addQuadCurve(to: CGPoint(x: x + 3, y: floorY), control: CGPoint(x: x + 6 + sway * 0.6, y: floorY - h * 0.5))
            ctx.fill(weed, with: .color(Color(hex: k % 2 == 0 ? 0x1C6A5A : 0x175448).opacity(0.75)))
        }
        for i in 0..<10 {
            let x = CGFloat((i * 73 + 11) % 100) / 100 * size.width + sin(time * 1.5 + CGFloat(i)) * 2
            let span = floorY + 20
            let y = span - (CGFloat((i * 131 + 37) % 100) / 100 * span + time * (10 + CGFloat(i % 3) * 5)).truncatingRemainder(dividingBy: span)
            let r: CGFloat = i % 3 == 0 ? 2.2 : 1.3
            ctx.stroke(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)), with: .color(Color(hex: 0xBFE6FF).opacity(0.35)), lineWidth: 0.8)
        }
        // Arena.
        ctx.fill(Path(CGRect(x: 0, y: floorY, width: size.width, height: size.height - floorY + 30)),
                 with: .linearGradient(Gradient(colors: [Color(hex: 0xC9A970), Color(hex: 0x8A6E45)]), startPoint: CGPoint(x: 0, y: floorY), endPoint: CGPoint(x: 0, y: size.height)))
        var crest = Path()
        crest.move(to: CGPoint(x: 0, y: floorY + 1))
        for k in 0...8 {
            let x = size.width * CGFloat(k) / 8
            crest.addQuadCurve(to: CGPoint(x: x, y: floorY + 1), control: CGPoint(x: x - size.width / 16, y: floorY - (k % 2 == 0 ? 2.5 : 1)))
        }
        ctx.stroke(crest, with: .color(Color(hex: 0xE3C891)), lineWidth: 2)
        for k in 0..<9 {
            let x = CGFloat((k * 61 + 23) % 100) / 100 * size.width, y = floorY + 6 + CGFloat((k * 29) % 12)
            ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 3.5, height: 2)), with: .color(Color(hex: 0x6E5636).opacity(0.6)))
        }
    }

    private func drawRock(_ ctx: inout GraphicsContext, _ r: CGRect) {
        let shape = Path(roundedRect: r, cornerRadius: min(4, r.width / 2.5))
        ctx.fill(Path(roundedRect: r.offsetBy(dx: 2, dy: 2), cornerRadius: 3), with: .color(.black.opacity(0.25)))
        ctx.fill(shape, with: .linearGradient(Gradient(colors: [Color(hex: 0x7C8798), Color(hex: 0x4A5263)]),
                                              startPoint: CGPoint(x: r.minX, y: r.minY), endPoint: CGPoint(x: r.maxX, y: r.maxY)))
        // Musgo arriba.
        ctx.fill(Path(roundedRect: CGRect(x: r.minX, y: r.minY - 1, width: r.width, height: 3), cornerRadius: 1.5), with: .color(Color(hex: 0x3E9A6E)))
    }

    /// El piloto apunta al primer cangrejo vivo y dispara él mismo cuando ángulo y fuerza cuadran.
    func autopilot() -> CGFloat {
        guard shot == nil, wait <= 0, let index = targets.firstIndex(where: { $0.alive }) else { return input }
        if plan == nil { plan = solution(for: index) ?? (0.6, 180) }
        guard let plan else { return input }
        // Apunta, mantiene «el dedo» hasta la fuerza del plan y suelta.
        if abs(input - plan.input) < 0.004 {
            if !charging { press(true) } else if power >= plan.v - 2 { press(false) }
        }
        return plan.input
    }
}

struct WatchInkView: View {
    var body: some View { WatchArcadeStage(info: WatchInk.info, world: InkWorld()) }
}

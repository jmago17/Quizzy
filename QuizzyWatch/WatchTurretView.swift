//
//  WatchTurretView.swift — Quizzy Watch
//  Torreta: una cúpula en el centro del suelo con un cañón encima. Del cielo caen meteoritos que
//  van a por la cúpula; la Corona gira el cañón (0,5 = recto hacia arriba) y dispara solo.
//  Roca (1 impacto), roca grande (3; al romperse suelta dos pequeñas) y esquirla (rápida, desde
//  el nivel 3). Una cápsula que baja despacio da cañón doble 8 s si se le acierta. La cúpula
//  aguanta 3 golpes. Nivel nuevo cada 25 s: caen más y más deprisa.
//  Puntos: 10 roca, 20 esquirla, 30 roca grande.
//  Dibujos propios (formas en Canvas). Bucle y pantallas: `WatchArcadeStage`.
//

import SwiftUI

enum WatchTurret {
    static let skyTop = Color(hex: 0x141B3A)
    static var info: ArcadeInfo {
        ArcadeInfo(id: "turret", title: AppLanguage.text("Torreta", "Turret"),
                   hint: AppLanguage.text("Gira la Corona", "Turn the Crown"), color: Color(hex: 0x7FD6F2))
    }
    static let domeRadius: CGFloat = 15
    static let barrel: CGFloat = 15

    /// Cúpula con cañón. `base` = centro de la cúpula a ras de suelo; `angle` desde la vertical.
    static func drawTurret(in ctx: inout GraphicsContext, base: CGPoint, scale s: CGFloat = 1, angle: CGFloat,
                           twin: Bool = false, hurt: CGFloat = 0, recoil: CGFloat = 0) {
        let r = domeRadius * s
        let pivot = CGPoint(x: base.x, y: base.y - r * 0.55)
        var g = ctx
        g.translateBy(x: pivot.x, y: pivot.y)
        g.rotate(by: .radians(Double(angle)))
        let len = (barrel - recoil * 3) * s
        for off in (twin ? [-2.6, 2.6] : [0]) as [CGFloat] {
            let tube = CGRect(x: off * s - 2.2 * s, y: -r * 0.45 - len, width: 4.4 * s, height: len + r * 0.3)
            g.fill(Path(roundedRect: tube, cornerRadius: 1.5 * s), with: .color(Color(hex: 0xC9D2E0)))
            g.fill(Path(CGRect(x: tube.minX, y: tube.minY, width: tube.width, height: 2.5 * s)), with: .color(Color(hex: 0x5E687A)))
        }
        var dome = Path()
        dome.addArc(center: base, radius: r, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        dome.closeSubpath()
        let glass = hurt > 0 ? Color(hex: 0xF0766B) : Color(hex: 0x7FD6F2)
        ctx.fill(dome, with: .linearGradient(Gradient(colors: [glass.opacity(0.85), glass.opacity(0.4)]),
                                             startPoint: CGPoint(x: base.x, y: base.y - r), endPoint: base))
        ctx.stroke(dome, with: .color(.white.opacity(0.8)), lineWidth: 1.1 * s)
        var shine = Path()
        shine.addArc(center: base, radius: r * 0.72, startAngle: .degrees(205), endAngle: .degrees(250), clockwise: false)
        ctx.stroke(shine, with: .color(.white.opacity(0.7)), style: StrokeStyle(lineWidth: 1.6 * s, lineCap: .round))
        ctx.fill(Path(ellipseIn: CGRect(x: pivot.x - 4 * s, y: pivot.y - 4 * s, width: 8 * s, height: 8 * s)), with: .color(Color(hex: 0x39424F)))
        ctx.fill(Path(roundedRect: CGRect(x: base.x - r - 3 * s, y: base.y - 1.5 * s, width: (r + 3 * s) * 2, height: 4 * s), cornerRadius: 2 * s),
                 with: .color(Color(hex: 0x5E687A)))
    }

    static func drawRock(in ctx: inout GraphicsContext, at c: CGPoint, radius r: CGFloat, spin: CGFloat, color: Color, flash: Bool = false) {
        var rock = Path()
        for k in 0..<8 {
            let a = spin + CGFloat(k) / 8 * 2 * .pi
            let rr = r * (k % 2 == 0 ? 1 : 0.78)
            let p = CGPoint(x: c.x + cos(a) * rr, y: c.y + sin(a) * rr)
            if k == 0 { rock.move(to: p) } else { rock.addLine(to: p) }
        }
        rock.closeSubpath()
        ctx.fill(rock, with: .color(flash ? .white : color))
        ctx.fill(Path(ellipseIn: CGRect(x: c.x - r * 0.45, y: c.y - r * 0.5, width: r * 0.5, height: r * 0.4)), with: .color(.white.opacity(0.25)))
        ctx.fill(Path(ellipseIn: CGRect(x: c.x + r * 0.05, y: c.y + r * 0.1, width: r * 0.4, height: r * 0.32)), with: .color(.black.opacity(0.22)))
    }
}

final class TurretWorld: ArcadeWorld {
    enum Kind { case rock, big, shard, capsule }
    struct Meteor { var kind: Kind; var p: CGPoint; var v: CGVector; var hp: Int; var spin: CGFloat; var flash: CGFloat = 0 }
    struct Shot { var p: CGPoint; var v: CGVector }

    private static let maxAngle: CGFloat = 1.36          // ±78° desde la vertical
    private static let shotSpeed: CGFloat = 270
    private static let levelTime: CGFloat = 25

    private var size: CGSize = .zero
    private var meteors: [Meteor] = []
    private var shots: [Shot] = []
    private var sparks: [Spark] = []
    private var angle: CGFloat = 0
    private var reload: CGFloat = 0.3
    private var recoil: CGFloat = 0
    private var spawnT: CGFloat = 1
    private var capsuleT: CGFloat = 18
    private var twin: CGFloat = 0
    private var lives = 3
    private var hurt: CGFloat = 0
    private var time: CGFloat = 0
    private var level = 1
    private var banner: CGFloat = 0
    private(set) var score = 0

    private var floorY: CGFloat { size.height - 24 }     // esquinas redondas
    private var base: CGPoint { CGPoint(x: size.width / 2, y: floorY) }
    private var pivot: CGPoint { CGPoint(x: base.x, y: base.y - WatchTurret.domeRadius * 0.55) }
    private var muzzleDistance: CGFloat { WatchTurret.domeRadius * 0.45 + WatchTurret.barrel }
    private var aim: CGVector { CGVector(dx: sin(angle), dy: -cos(angle)) }

    private static func radius(_ k: Kind) -> CGFloat {
        switch k { case .rock: return 6.5; case .big: return 11; case .shard: return 4.5; case .capsule: return 7 }
    }

    func reset(size: CGSize) {
        self.size = size
        meteors = []; shots = []; sparks = []
        angle = 0; reload = 0.3; recoil = 0; spawnT = 1; capsuleT = 18; twin = 0
        lives = 3; hurt = 0; time = 0; level = 1; banner = 0; score = 0
        #if DEBUG
        if let n = Int(ProcessInfo.processInfo.environment["QW_LEVEL"] ?? "") { level = n; time = CGFloat(n - 1) * Self.levelTime; capsuleT = 2 }
        #endif
    }

    func resize(_ size: CGSize) { self.size = size }

    private func spawn(_ kind: Kind, at p: CGPoint? = nil) {
        // Entran por arriba o, a partir del nivel 2, por los lados (mitad alta de la pantalla).
        var start = CGPoint(x: CGFloat.random(in: 8...(size.width - 8)), y: -12)
        if p == nil, kind != .capsule, level >= 2, Int.random(in: 0..<4) == 0 {
            start = CGPoint(x: Bool.random() ? -12 : size.width + 12, y: CGFloat.random(in: 10...(floorY * 0.45)))
        }
        if let p { start = p }
        let grow = 1 + 0.11 * CGFloat(level - 1)
        var speed: CGFloat
        switch kind {
        case .rock: speed = 30 * grow
        case .big: speed = 21 * grow
        case .shard: speed = 52 * grow
        case .capsule: speed = 24
        }
        speed = min(speed, 110)
        // Todo va a por la cúpula (con algo de dispersión); la cápsula baja recta.
        let target = kind == .capsule ? CGPoint(x: start.x, y: floorY) : CGPoint(x: base.x + CGFloat.random(in: -9...9), y: floorY - 6)
        let d = max(1, hypot(target.x - start.x, target.y - start.y))
        meteors.append(Meteor(kind: kind, p: start, v: CGVector(dx: (target.x - start.x) / d * speed, dy: (target.y - start.y) / d * speed),
                              hp: kind == .big ? 3 : 1, spin: CGFloat.random(in: 0..<6)))
    }

    func step(dt: CGFloat, input: CGFloat) -> ArcadeEvent {
        guard size.width > 0, lives > 0 else { return .none }
        var event = ArcadeEvent.none
        time += dt
        angle = (input - 0.5) * 2 * Self.maxAngle
        hurt = max(0, hurt - dt); twin = max(0, twin - dt); banner = max(0, banner - dt)
        recoil = max(0, recoil - dt * 8)
        Spark.step(&sparks, dt: dt)

        if time > CGFloat(level) * Self.levelTime { level += 1; banner = 1.6; event = .bonus }

        // Llegadas: el intervalo baja de 1,5 s a 0,5 s con el nivel.
        spawnT -= dt
        if spawnT <= 0 {
            spawnT = max(0.5, 1.5 - 0.13 * CGFloat(level - 1)) * CGFloat.random(in: 0.75...1.25)
            let roll = Int.random(in: 0..<100)
            if level >= 3, roll < 22 { spawn(.shard) }
            else if level >= 2, roll < 40 { spawn(.big) }
            else { spawn(.rock) }
        }
        capsuleT -= dt
        if capsuleT <= 0 { capsuleT = CGFloat.random(in: 22...32); spawn(.capsule) }

        // Cañón: dispara solo.
        reload -= dt
        if reload <= 0 {
            reload = twin > 0 ? 0.16 : 0.24
            recoil = 1
            let a = aim
            for off in (twin > 0 ? [-2.6, 2.6] : [0]) as [CGFloat] {
                let start = CGPoint(x: pivot.x + a.dx * muzzleDistance - a.dy * off, y: pivot.y + a.dy * muzzleDistance + a.dx * off)
                shots.append(Shot(p: start, v: CGVector(dx: a.dx * Self.shotSpeed, dy: a.dy * Self.shotSpeed)))
            }
        }
        for i in shots.indices { shots[i].p.x += shots[i].v.dx * dt; shots[i].p.y += shots[i].v.dy * dt }
        shots.removeAll { $0.p.y < -8 || $0.p.x < -8 || $0.p.x > size.width + 8 }

        for i in meteors.indices {
            meteors[i].p.x += meteors[i].v.dx * dt
            meteors[i].p.y += meteors[i].v.dy * dt
            meteors[i].spin += dt * (meteors[i].kind == .shard ? 5 : 1.6)
            meteors[i].flash = max(0, meteors[i].flash - dt)
        }

        // Disparos contra lo que cae.
        var born: [(Kind, CGPoint)] = []
        var s = 0
        while s < shots.count {
            let p = shots[s].p
            if let i = meteors.firstIndex(where: { hypot($0.p.x - p.x, $0.p.y - p.y) < Self.radius($0.kind) + 2.5 }) {
                shots.remove(at: s)
                meteors[i].hp -= 1
                meteors[i].flash = 0.08
                if meteors[i].hp <= 0 {
                    let m = meteors.remove(at: i)
                    switch m.kind {
                    case .rock: score += 10
                    case .shard: score += 20
                    case .big:
                        score += 30
                        born.append((.rock, CGPoint(x: m.p.x - 7, y: m.p.y))); born.append((.rock, CGPoint(x: m.p.x + 7, y: m.p.y)))
                    case .capsule: twin = 8; event = .bonus
                    }
                    Spark.burst(&sparks, at: m.p, color: m.kind == .capsule ? Color(hex: 0x7BE08A) : Color(hex: 0xF2A65A), count: m.kind == .big ? 14 : 8)
                }
            } else { s += 1 }
        }
        for (kind, p) in born { spawn(kind, at: p) }

        // Lo que llega abajo: contra la cúpula hace daño; al suelo, no.
        var i = 0
        while i < meteors.count {
            let m = meteors[i], r = Self.radius(m.kind)
            let onDome = hypot(m.p.x - base.x, m.p.y - base.y) < WatchTurret.domeRadius + r - 1 && m.p.y < floorY + 2
            if onDome || m.p.y > floorY - r * 0.5 {
                meteors.remove(at: i)
                Spark.burst(&sparks, at: m.p, color: onDome ? .white : Color(hex: 0xB08A5A), count: onDome ? 14 : 6)
                if onDome, m.kind != .capsule {
                    lives -= 1; hurt = 0.5
                    if lives <= 0 { return .dead }
                    event = .hit
                }
            } else { i += 1 }
        }
        return event
    }

    func draw(_ ctx: inout GraphicsContext, size: CGSize) {
        // Anochecer: cielo, estrellas, luna, sierra y suelo.
        ctx.fill(Path(CGRect(x: 0, y: -40, width: size.width, height: floorY + 40)),
                 with: .linearGradient(Gradient(colors: [WatchTurret.skyTop, Color(hex: 0x3A2F63), Color(hex: 0x9A5A6E)]),
                                       startPoint: .zero, endPoint: CGPoint(x: 0, y: floorY)))
        for k in 0..<26 {
            let x = CGFloat((k * 73 + 17) % 100) / 100 * size.width, y = CGFloat((k * 41 + 7) % 100) / 100 * floorY * 0.75
            let tw = 0.35 + 0.35 * sin(time * 2 + CGFloat(k))
            ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 1.4, height: 1.4)), with: .color(.white.opacity(Double(tw))))
        }
        let moon = CGPoint(x: size.width * 0.22, y: floorY * 0.34)
        ctx.fill(Path(ellipseIn: CGRect(x: moon.x - 26, y: moon.y - 26, width: 52, height: 52)),
                 with: .radialGradient(Gradient(colors: [Color(hex: 0xE8E4FF).opacity(0.35), .clear]), center: moon, startRadius: 6, endRadius: 26))
        ctx.fill(Path(ellipseIn: CGRect(x: moon.x - 9, y: moon.y - 9, width: 18, height: 18)), with: .color(Color(hex: 0xEDEAFA)))
        ctx.fill(Path(ellipseIn: CGRect(x: moon.x - 4, y: moon.y - 5, width: 5, height: 5)), with: .color(Color(hex: 0xCFCBE6)))
        for (k, color) in [Color(hex: 0x3B2F55), Color(hex: 0x2A2340)].enumerated() {
            var ridge = Path()
            let h: CGFloat = k == 0 ? 34 : 18
            ridge.move(to: CGPoint(x: -10, y: floorY))
            for j in 0...6 {
                let x = size.width * (CGFloat(j) + (k == 0 ? 0 : 0.5)) / 5
                ridge.addLine(to: CGPoint(x: x - size.width / 10, y: floorY - h * (j % 2 == 0 ? 1 : 0.55)))
                ridge.addLine(to: CGPoint(x: x, y: floorY - h * 0.25))
            }
            ridge.addLine(to: CGPoint(x: size.width + 10, y: floorY)); ridge.closeSubpath()
            ctx.fill(ridge, with: .color(color))
        }
        ctx.fill(Path(CGRect(x: 0, y: floorY, width: size.width, height: size.height - floorY + 30)),
                 with: .linearGradient(Gradient(colors: [Color(hex: 0x4A3E58), Color(hex: 0x231D30)]), startPoint: CGPoint(x: 0, y: floorY), endPoint: CGPoint(x: 0, y: size.height)))
        ctx.fill(Path(CGRect(x: 0, y: floorY, width: size.width, height: 1.5)), with: .color(Color(hex: 0x8C7AA6)))

        // Mira: puntos en la dirección del cañón.
        let a = aim
        for k in 1...5 {
            let d = muzzleDistance + CGFloat(k) * 11
            ctx.fill(Path(ellipseIn: CGRect(x: pivot.x + a.dx * d - 1, y: pivot.y + a.dy * d - 1, width: 2, height: 2)),
                     with: .color(.white.opacity(0.42 - Double(k) * 0.07)))
        }
        for m in meteors {
            let r = Self.radius(m.kind)
            if m.kind == .capsule {
                let rect = CGRect(x: m.p.x - r, y: m.p.y - r, width: r * 2, height: r * 2)
                var chute = Path()
                chute.addArc(center: CGPoint(x: m.p.x, y: m.p.y - r - 5), radius: r + 2, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
                chute.closeSubpath()
                ctx.fill(chute, with: .color(.white.opacity(0.85)))
                ctx.fill(Path(roundedRect: rect, cornerRadius: 3), with: .color(Color(hex: 0x7BE08A)))
                ctx.draw(Text("×2").font(.system(size: 8, weight: .black, design: .rounded)).foregroundColor(Color(hex: 0x12351C)), at: m.p)
                continue
            }
            // Estela de fuego, opuesta a la velocidad.
            let sp = max(1, hypot(m.v.dx, m.v.dy)), tail = r * 2.6 + sp * 0.12
            var trail = Path()
            trail.move(to: CGPoint(x: m.p.x - m.v.dy / sp * r * 0.8, y: m.p.y + m.v.dx / sp * r * 0.8))
            trail.addLine(to: CGPoint(x: m.p.x - m.v.dx / sp * tail, y: m.p.y - m.v.dy / sp * tail))
            trail.addLine(to: CGPoint(x: m.p.x + m.v.dy / sp * r * 0.8, y: m.p.y - m.v.dx / sp * r * 0.8))
            trail.closeSubpath()
            ctx.fill(trail, with: .linearGradient(Gradient(colors: [Color(hex: 0xF2C14E).opacity(0.75), Color(hex: 0xF0766B).opacity(0)]),
                                                  startPoint: m.p, endPoint: CGPoint(x: m.p.x - m.v.dx / sp * tail, y: m.p.y - m.v.dy / sp * tail)))
            let color: Color = m.kind == .shard ? Color(hex: 0xE0738C) : (m.kind == .big ? Color(hex: 0x8A6A58) : Color(hex: 0xA9805F))
            WatchTurret.drawRock(in: &ctx, at: m.p, radius: r, spin: m.spin, color: color, flash: m.flash > 0)
        }
        for s in shots {
            ctx.fill(Path(ellipseIn: CGRect(x: s.p.x - 2, y: s.p.y - 2, width: 4, height: 4)), with: .color(Color(hex: 0xFFF2B0)))
        }
        if lives > 0 {
            WatchTurret.drawTurret(in: &ctx, base: base, angle: angle, twin: twin > 0, hurt: hurt, recoil: recoil)
        }
        Spark.draw(sparks, in: &ctx)
        drawLives(lives, in: &ctx, width: size.width)
        if twin > 0 {
            ctx.fill(Path(roundedRect: CGRect(x: ArcadeHUD.left, y: ArcadeHUD.y + 10, width: 38 * twin / 8, height: 3.5), cornerRadius: 1.75), with: .color(Color(hex: 0x7BE08A)))
        }
        if banner > 0 {
            ctx.draw(Text(AppLanguage.text("Nivel \(level)", "Level \(level)")).font(.system(size: 16, weight: .heavy, design: .rounded))
                .foregroundColor(.white.opacity(Double(min(1, banner * 2)))), at: CGPoint(x: size.width / 2, y: size.height * 0.36))
        }
    }

    func autopilot() -> CGFloat {
        // Apunta a lo más cercano a la cúpula, adelantándose a su movimiento.
        guard let m = meteors.filter({ $0.p.y > 0 || $0.p.x < 0 || $0.p.x > size.width })
            .min(by: { hypot($0.p.x - base.x, $0.p.y - base.y) < hypot($1.p.x - base.x, $1.p.y - base.y) }) else { return 0.5 }
        let t = hypot(m.p.x - pivot.x, m.p.y - pivot.y) / (Self.shotSpeed + 40)
        let tx = m.p.x + m.v.dx * t, ty = m.p.y + m.v.dy * t
        let want = atan2(tx - pivot.x, pivot.y - ty)
        return 0.5 + max(-Self.maxAngle, min(Self.maxAngle, want)) / (2 * Self.maxAngle)
    }
}

struct WatchTurretView: View {
    var body: some View { WatchArcadeStage(info: WatchTurret.info, world: TurretWorld()) }
}

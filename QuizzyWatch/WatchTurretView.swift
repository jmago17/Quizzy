//
//  WatchTurretView.swift — Quizzy Watch
//  Torreta: una cúpula en el centro del suelo con un cañón encima. Del cielo caen meteoritos que
//  van a por la cúpula; la Corona gira el cañón (0,5 = recto hacia arriba) y dispara solo.
//  Roca (1 impacto), roca grande (3; al romperse suelta dos pequeñas) y esquirla (rápida, desde
//  el nivel 3). Una cápsula que baja despacio da cañón doble 8 s si se le acierta. La cúpula
//  aguanta 3 golpes. Nivel nuevo cada 25 s: caen más y más deprisa.
//  Puntos: 10 roca, 20 esquirla, 30 roca grande.
//  El cielo hace un ciclo completo día/noche (`dayLength` s) y el tiempo cambia (despejado, nubes,
//  lluvia, tormenta, nieve). Es solo decorado: no toca la física.
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

    /// Mezcla de dos colores hex, `t` 0…1.
    static func mix(_ a: UInt32, _ b: UInt32, _ t: CGFloat) -> Color {
        let t = Double(min(1, max(0, t)))
        func ch(_ v: UInt32, _ shift: UInt32) -> Double { Double((v >> shift) & 0xFF) / 255 }
        return Color(red: ch(a, 16) + (ch(b, 16) - ch(a, 16)) * t, green: ch(a, 8) + (ch(b, 8) - ch(a, 8)) * t,
                     blue: ch(a, 0) + (ch(b, 0) - ch(a, 0)) * t)
    }
    /// Cielo (arriba, medio, horizonte) a medianoche, amanecer, mediodía y atardecer.
    static let sky: [[UInt32]] = [[0x0B1030, 0x1B1F4A, 0x2E2A5C], [0x2B3566, 0x8A5E8E, 0xF0A07A],
                                  [0x2F7FD0, 0x5FA8E6, 0x9CCFF0], [0x2A2458, 0x7A3F73, 0xE8825A]]
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
    enum Weather: String, CaseIterable { case clear, cloudy, rain, storm, snow }

    private static let dayLength: CGFloat = 96           // un día entero, en segundos
    private var day: CGFloat = 0.7                       // 0 = medianoche, 0,5 = mediodía
    private var weather = Weather.clear
    private var wxAmount: CGFloat = 0                    // 0…1: cuánto se nota el tiempo actual
    private var wxLeft: CGFloat = 10                     // lo que le queda antes de cambiar
    private var bolt: [CGPoint] = []
    private var boltT: CGFloat = 0, boltWait: CGFloat = 3

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
        day = 0.7; weather = .clear; wxAmount = 0; wxLeft = 10; bolt = []; boltT = 0; boltWait = 3
        #if DEBUG
        if let d = Double(ProcessInfo.processInfo.environment["QW_DAY"] ?? "") { day = CGFloat(d) }
        if let w = Weather(rawValue: ProcessInfo.processInfo.environment["QW_WX"] ?? "") { weather = w; wxAmount = 1; wxLeft = 60 }
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
        stepSky(dt)

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
        drawSky(&ctx, size: size)

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
            let dot = Path(ellipseIn: CGRect(x: s.p.x - 2, y: s.p.y - 2, width: 4, height: 4))
            ctx.stroke(dot, with: .color(.black.opacity(0.35)), lineWidth: 1.2)   // de día el cielo es claro
            ctx.fill(dot, with: .color(Color(hex: 0xFFF2B0)))
        }
        if lives > 0 {
            WatchTurret.drawTurret(in: &ctx, base: base, angle: angle, twin: twin > 0, hurt: hurt, recoil: recoil)
        }
        drawWeather(&ctx, size: size)
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

    // MARK: Cielo y tiempo (decorado)

    /// Altura del sol: 1 a mediodía, −1 a medianoche.
    private var sunAlt: CGFloat { sin((day - 0.25) * 2 * .pi) }
    /// Luz del día, 0 (noche) … 1; con nubes de lluvia o tormenta baja.
    private var light: CGFloat { min(1, max(0, sunAlt * 2 + 0.5)) }
    private var overcast: CGFloat { weather == .clear ? 0 : wxAmount * (weather == .cloudy ? 0.45 : (weather == .storm ? 1 : 0.75)) }
    private var wind: CGFloat { weather == .storm ? 60 : (weather == .rain ? 28 : 10) }

    private func stepSky(_ dt: CGFloat) {
        day = (day + dt / Self.dayLength).truncatingRemainder(dividingBy: 1)
        wxLeft -= dt
        if wxLeft > 0 { wxAmount = min(1, wxAmount + dt / 3) }
        else {
            wxAmount = max(0, wxAmount - dt / 3)
            if wxAmount <= 0 {
                weather = Weather.allCases.filter { $0 != weather }.randomElement() ?? .clear
                wxLeft = CGFloat.random(in: 14...22)
            }
        }
        boltT = max(0, boltT - dt)
        if weather == .storm, wxAmount > 0.8 {
            boltWait -= dt
            if boltWait <= 0 {
                boltWait = CGFloat.random(in: 2.2...5)
                boltT = 0.28
                var x = CGFloat.random(in: 20...(size.width - 20)), y: CGFloat = 26
                bolt = [CGPoint(x: x, y: y)]
                while y < floorY - 30 { y += CGFloat.random(in: 12...22); x += CGFloat.random(in: -14...14); bolt.append(CGPoint(x: x, y: y)) }
            }
        }
    }

    private func drawSky(_ ctx: inout GraphicsContext, size: CGSize) {
        let seg = day * 4, k = Int(seg) % 4, t = seg - CGFloat(Int(seg))
        let from = WatchTurret.sky[k], to = WatchTurret.sky[(k + 1) % 4]
        ctx.fill(Path(CGRect(x: 0, y: -40, width: size.width, height: floorY + 40)),
                 with: .linearGradient(Gradient(colors: (0..<3).map { WatchTurret.mix(from[$0], to[$0], t) }),
                                       startPoint: .zero, endPoint: CGPoint(x: 0, y: floorY)))
        let lit = light, dim = 1 - overcast
        if lit < 1 {
            for k in 0..<26 {
                let x = CGFloat((k * 73 + 17) % 100) / 100 * size.width, y = CGFloat((k * 41 + 7) % 100) / 100 * floorY * 0.75
                let tw = (0.4 + 0.4 * sin(time * 2 + CGFloat(k))) * (1 - lit) * dim
                ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 1.4, height: 1.4)), with: .color(.white.opacity(Double(tw))))
            }
        }
        // Sol y luna cruzan de izquierda a derecha, cada uno en su media vuelta.
        let arc = floorY * 0.78
        let sun = CGPoint(x: size.width * (0.1 + 0.8 * (day - 0.25) * 2), y: floorY - sunAlt * arc)
        if sunAlt > -0.15 {
            ctx.fill(Path(ellipseIn: CGRect(x: sun.x - 34, y: sun.y - 34, width: 68, height: 68)),
                     with: .radialGradient(Gradient(colors: [Color(hex: 0xFFE2A0).opacity(0.6 * Double(dim)), .clear]), center: sun, startRadius: 5, endRadius: 34))
            ctx.fill(Path(ellipseIn: CGRect(x: sun.x - 10, y: sun.y - 10, width: 20, height: 20)),
                     with: .color(WatchTurret.mix(0xFF9A5A, 0xFFF1B8, sunAlt * 2).opacity(Double(dim))))
        }
        let night = (day + 0.5).truncatingRemainder(dividingBy: 1)
        let moon = CGPoint(x: size.width * (0.1 + 0.8 * (night - 0.25) * 2), y: floorY + sunAlt * arc)
        if sunAlt < 0.15 {
            ctx.fill(Path(ellipseIn: CGRect(x: moon.x - 26, y: moon.y - 26, width: 52, height: 52)),
                     with: .radialGradient(Gradient(colors: [Color(hex: 0xE8E4FF).opacity(0.35 * Double(dim)), .clear]), center: moon, startRadius: 6, endRadius: 26))
            ctx.fill(Path(ellipseIn: CGRect(x: moon.x - 9, y: moon.y - 9, width: 18, height: 18)), with: .color(Color(hex: 0xEDEAFA).opacity(Double(dim))))
            ctx.fill(Path(ellipseIn: CGRect(x: moon.x - 4, y: moon.y - 5, width: 5, height: 5)), with: .color(Color(hex: 0xCFCBE6).opacity(Double(dim))))
        }
        // Cielo cubierto: velo gris, y nubes que pasan con el viento.
        if overcast > 0 {
            ctx.fill(Path(CGRect(x: 0, y: -40, width: size.width, height: floorY + 40)), with: .color(Color(hex: 0x2C3140).opacity(Double(overcast) * 0.55)))
            let heavy = weather == .rain || weather == .storm
            let tone = WatchTurret.mix(heavy ? 0x3A3F4E : 0x5A5F78, heavy ? 0x7C8496 : 0xF2F4FA, lit)
            for c in 0..<6 {
                let span = size.width + 90
                let x = (CGFloat(c) * 57 + time * wind * (0.5 + CGFloat(c % 3) * 0.2)).truncatingRemainder(dividingBy: span) - 45
                let y = 34 + CGFloat((c * 29) % 46), w = 40 + CGFloat((c * 17) % 22)
                for (dx, sc) in [(-0.3, 0.62), (0.0, 1.0), (0.3, 0.72)] as [(CGFloat, CGFloat)] {
                    ctx.fill(Path(ellipseIn: CGRect(x: x + dx * w - w * sc * 0.32, y: y - w * sc * 0.17, width: w * sc * 0.64, height: w * sc * 0.34)),
                             with: .color(tone.opacity(Double(wxAmount) * 0.85)))
                }
            }
        }
        if boltT > 0 {
            var path = Path()
            path.addLines(bolt)
            ctx.stroke(path, with: .color(.white.opacity(Double(min(1, boltT * 6)))), style: StrokeStyle(lineWidth: 2, lineJoin: .round))
            ctx.fill(Path(CGRect(x: 0, y: -40, width: size.width, height: size.height + 80)), with: .color(.white.opacity(Double(boltT) * 1.1)))
        }
        // Sierra y suelo, más claros de día y más apagados con mal tiempo.
        let l = lit * (1 - overcast * 0.5)
        let snowy: CGFloat = weather == .snow ? wxAmount : 0
        for (k, pair) in ([(0x3B2F55, 0x6F86A6), (0x2A2340, 0x4D6F5C)] as [(UInt32, UInt32)]).enumerated() {
            var ridge = Path()
            let h: CGFloat = k == 0 ? 34 : 18
            ridge.move(to: CGPoint(x: -10, y: floorY))
            for j in 0...6 {
                let x = size.width * (CGFloat(j) + (k == 0 ? 0 : 0.5)) / 5
                ridge.addLine(to: CGPoint(x: x - size.width / 10, y: floorY - h * (j % 2 == 0 ? 1 : 0.55)))
                ridge.addLine(to: CGPoint(x: x, y: floorY - h * 0.25))
            }
            ridge.addLine(to: CGPoint(x: size.width + 10, y: floorY)); ridge.closeSubpath()
            ctx.fill(ridge, with: .color(WatchTurret.mix(pair.0, pair.1, l)))
            if snowy > 0 { ctx.fill(ridge, with: .color(.white.opacity(Double(snowy) * 0.28))) }
        }
        ctx.fill(Path(CGRect(x: 0, y: floorY, width: size.width, height: size.height - floorY + 30)),
                 with: .linearGradient(Gradient(colors: [WatchTurret.mix(0x4A3E58, 0x7C8F5E, l), WatchTurret.mix(0x231D30, 0x46593A, l)]),
                                       startPoint: CGPoint(x: 0, y: floorY), endPoint: CGPoint(x: 0, y: size.height)))
        if snowy > 0 { ctx.fill(Path(CGRect(x: 0, y: floorY, width: size.width, height: size.height - floorY + 30)), with: .color(.white.opacity(Double(snowy) * 0.5))) }
        ctx.fill(Path(CGRect(x: 0, y: floorY, width: size.width, height: 1.5)), with: .color(WatchTurret.mix(0x8C7AA6, 0xB9D08A, l)))
    }

    /// Lluvia y nieve, por delante de todo menos del marcador.
    private func drawWeather(_ ctx: inout GraphicsContext, size: CGSize) {
        guard wxAmount > 0 else { return }
        switch weather {
        case .rain, .storm:
            let storm = weather == .storm
            let fall: CGFloat = storm ? 330 : 250, slant = wind / fall, count = storm ? 46 : 30
            var rain = Path()
            for k in 0..<count {
                let y = (CGFloat((k * 61 + 13) % 100) / 100 * floorY + time * fall * (0.85 + CGFloat(k % 4) * 0.08)).truncatingRemainder(dividingBy: floorY)
                let x = (CGFloat((k * 37 + 5) % 100) / 100 * (size.width + 60) - 60 + y * slant)
                rain.move(to: CGPoint(x: x, y: y)); rain.addLine(to: CGPoint(x: x - slant * 9, y: y - 9))
            }
            ctx.stroke(rain, with: .color(Color(hex: 0xBFD9F2).opacity(Double(wxAmount) * 0.5)), lineWidth: 1)
        case .snow:
            for k in 0..<34 {
                let y = (CGFloat((k * 61 + 13) % 100) / 100 * floorY + time * (22 + CGFloat(k % 5) * 5)).truncatingRemainder(dividingBy: floorY)
                let x = CGFloat((k * 37 + 5) % 100) / 100 * size.width + sin(time * 1.3 + CGFloat(k)) * 6
                let r: CGFloat = k % 3 == 0 ? 1.6 : 1.1
                ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)), with: .color(.white.opacity(Double(wxAmount) * 0.85)))
            }
        default: break
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

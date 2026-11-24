//
//  WatchDriftView.swift — Quizzy Watch
//  Derrape: la Corona es el VOLANTE, no la posición. Centrada (como empieza) el coche va recto;
//  girarla lo inclina hasta 40° a cada lado y el coche avanza EXACTAMENTE hacia donde apunta el
//  morro (vx = v·tan(ángulo)). Hasta el 2026-11-23 el desplazamiento lateral iba multiplicado por
//  1,5: para seguir una curva había que llevar el coche menos girado que la carretera, y Josu
//  no encontraba «una orientación que coincida con la curva». Ahora coche paralelo al arcén =
//  sigue la curva. La pendiente de la carretera está acotada (`maxSlope`) para que siempre haya
//  volante de sobra. La
//  carretera serpentea, se estrecha y el coche acelera con el tiempo. Tocar el arcén o a otro
//  coche cuesta una vida (3) y devuelve al centro. Puntos: la distancia, y 3 por adelantamiento.
//  Es distinto de Escuadrón/Marcianitos a propósito: allí la Corona coloca, aquí gira.
//  Dibujos propios. Bucle y pantallas: `WatchArcadeStage`.
//

import SwiftUI

enum WatchDrift {
    static var info: ArcadeInfo {
        ArcadeInfo(id: "drift", title: AppLanguage.text("Derrape", "Drift"),
                   hint: AppLanguage.text("La Corona es el volante", "The Crown steers"), color: Color(hex: 0xF0766B))
    }
    static let grass = Color(hex: 0x24573A)

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
    struct Rival { var d: CGFloat; var off: CGFloat; var color: Color }
    static let maxSteer: CGFloat = 0.70       // radianes a tope de Corona (40°; tan = 0,84)
    static let maxSlope: CGFloat = 0.5        // desvío lateral máximo de la carretera por punto de avance (27°)
    static let carSize: CGFloat = 20

    private var size: CGSize = .zero
    private var x: CGFloat = 0
    private var d: CGFloat = 0                // distancia recorrida
    private var heading: CGFloat = 0
    private var time: CGFloat = 0
    private var lives = 3
    private var invuln: CGFloat = 0
    private var rivals: [Rival] = []
    private var spawnT: CGFloat = 6
    private var bonus = 0
    private var sparks: [Spark] = []
    private(set) var score = 0

    private var carY: CGFloat { size.height - 46 }
    private var speed: CGFloat { min(190, 95 + time * 2.2) }
    private func half(_ at: CGFloat) -> CGFloat { max(24, 36 - at * 0.002) }
    private func center(_ at: CGFloat) -> CGFloat {
        // Dos ondas largas. La pendiente máxima es amp·(1/150 + 0,35/85)/1,35 ≈ amp·0,008,
        // así que amp ≤ maxSlope/0,008 la mantiene dentro de lo que el volante puede seguir.
        let amp = min(size.width / 2 - half(at) - 10, Self.maxSlope / 0.008, 14 + max(0, at) * 0.012)
        return size.width / 2 + amp * (sin(at / 150) + 0.35 * sin(at / 85 + 1.3)) / 1.35
    }
    /// Distancia de carretera que se ve en la fila `y` de la pantalla.
    private func dist(atY y: CGFloat) -> CGFloat { d + (carY - y) }

    func reset(size: CGSize) {
        self.size = size
        d = 0; time = 0; lives = 3; invuln = 0; rivals = []; spawnT = 6; bonus = 0; sparks = []; score = 0; heading = 0
        x = center(0)
    }

    func resize(_ size: CGSize) { self.size = size }

    func step(dt: CGFloat, input: CGFloat) -> ArcadeEvent {
        guard size.width > 0, lives > 0 else { return .none }
        var event = ArcadeEvent.none
        time += dt
        invuln = max(0, invuln - dt)
        Spark.step(&sparks, dt: dt)
        let v = speed
        heading = (input - 0.5) * 2 * Self.maxSteer
        d += v * dt
        x += v * tan(heading) * dt

        // Tráfico: más lento que el jugador, así que baja por la pantalla.
        spawnT -= dt
        if spawnT <= 0 {
            spawnT = CGFloat.random(in: 1.5...2.8) * max(0.55, 1 - time * 0.006)
            let at = dist(atY: -30)
            let room = half(at) - 11
            rivals.append(Rival(d: at, off: CGFloat.random(in: -room...room),
                                color: [Color(hex: 0x6FB7F2), Color(hex: 0xF2C14E), Color(hex: 0xB58CFF), Color(hex: 0xE6E9EF)].randomElement()!))
        }
        for i in rivals.indices { rivals[i].d += v * 0.5 * dt }
        let before = rivals.count
        rivals.removeAll { carY - ($0.d - d) > size.height + 20 }
        if rivals.count < before { bonus += 3 * (before - rivals.count) }

        var crashed = false
        if invuln <= 0 {
            if abs(x - center(d)) > half(d) - 5 { crashed = true }
            for r in rivals where abs(r.d - d) < 17 && abs(center(r.d) + r.off - x) < 10.5 { crashed = true }
        }
        if crashed {
            Spark.burst(&sparks, at: CGPoint(x: x, y: carY), color: Color(hex: 0xF2C14E), count: 14)
            lives -= 1
            score = Int(d / 25) + bonus
            if lives <= 0 { return .dead }
            invuln = 1.8
            x = center(d)
            rivals.removeAll { abs($0.d - d) < 90 }
            event = .hit
        }
        score = Int(d / 25) + bonus
        return event
    }

    func draw(_ ctx: inout GraphicsContext, size: CGSize) {
        ctx.fill(Path(CGRect(x: 0, y: -40, width: size.width, height: size.height + 80)), with: .color(WatchDrift.grass))
        // Matas en la hierba, para que se note la velocidad también fuera del asfalto.
        for i in 0..<14 {
            let gx = CGFloat((i * 53 + 11) % 100) / 100 * size.width
            let gy = (CGFloat((i * 37 + 5) % 100) / 100 * (size.height + 20) + d).truncatingRemainder(dividingBy: size.height + 20) - 10
            ctx.fill(Path(ellipseIn: CGRect(x: gx - 2.5, y: gy - 1.5, width: 5, height: 3)), with: .color(.black.opacity(0.14)))
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
        ctx.fill(road, with: .color(Color(hex: 0x3A3F4B)))
        let phase = -d.truncatingRemainder(dividingBy: 12)
        for edge in [left, right] {
            ctx.stroke(edge, with: .color(.white), lineWidth: 3)
            ctx.stroke(edge, with: .color(Color(hex: 0xE0473B)), style: StrokeStyle(lineWidth: 3, dash: [6, 6], dashPhase: phase))
        }
        ctx.stroke(mid, with: .color(.white.opacity(0.55)),
                   style: StrokeStyle(lineWidth: 1.6, dash: [9, 11], dashPhase: -d.truncatingRemainder(dividingBy: 20)))

        for r in rivals {
            let y = carY - (r.d - d)
            WatchDrift.drawCar(in: &ctx, at: CGPoint(x: center(r.d) + r.off, y: y), size: Self.carSize, angle: 0, body: r.color)
        }
        if lives > 0, invuln <= 0 || Int(time * 10) % 2 == 0 {
            WatchDrift.drawCar(in: &ctx, at: CGPoint(x: x, y: carY), size: Self.carSize, angle: heading, body: Color(hex: 0xF0766B))
        }
        Spark.draw(sparks, in: &ctx)
        drawLives(lives, in: &ctx, width: size.width)
    }

    func autopilot() -> CGFloat {
        var want = center(d + 34)
        if let r = rivals.filter({ $0.d > d - 10 && $0.d - d < 75 }).min(by: { $0.d < $1.d }) {
            let rx = center(r.d) + r.off
            if abs(rx - want) < 17 { want += (r.off > 0 ? -1 : 1) * min(17, half(r.d) - 11) - r.off * 0.3 }
        }
        // Apunta el morro al punto de la carretera que tiene 34 pt por delante.
        return min(1, max(0, 0.5 + atan2(want - x, 34) / (2 * Self.maxSteer)))
    }
}

struct WatchDriftView: View {
    var body: some View { WatchArcadeStage(info: WatchDrift.info, world: DriftWorld()) }
}

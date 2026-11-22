//
//  WatchSafeView.swift — Quizzy Watch
//  Caja fuerte: la Corona gira el dial (sin topes). Hay que encontrar el número de cada pasador:
//  la marca de arriba se va encendiendo al acercarse (a 4 números ya se nota) y al llegar el reloj
//  da un toque distinto (`ArcadeEvent.notch`). Quedarse quieto encima 0,35 s fija el pasador; el
//  siguiente está hacia el OTRO lado (lo dice la flecha del centro). Con todos, la caja se abre.
//  Contra reloj: 30 s, y cada caja abierta devuelve tiempo. Las cajas van teniendo más pasadores
//  (3 → 6). Puntos: 1 por pasador, 5 por caja.
//  La pista visual existe a propósito: no se puede depender solo de una háptica que el simulador
//  no deja probar. Bucle y pantallas: `WatchArcadeStage`.
//

import SwiftUI

enum WatchSafe {
    static var info: ArcadeInfo {
        ArcadeInfo(id: "safe", title: AppLanguage.text("Caja fuerte", "Safe"),
                   hint: AppLanguage.text("Gira y nota el clic", "Turn, feel the click"), color: Color(hex: 0xF2C14E))
    }
    static let gold = Color(hex: 0xF2C14E)
    static let ticks = 40

    /// Dial con sus rayas; `pos` = número que queda bajo la marca de arriba.
    static func drawDial(in ctx: inout GraphicsContext, center c: CGPoint, radius r: CGFloat, pos: CGFloat, numbers: Bool) {
        ctx.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)), with: .color(Color(hex: 0x2B303B)))
        ctx.stroke(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)), with: .color(Color(hex: 0x8D97A8)), lineWidth: max(1, r * 0.06))
        for i in 0..<ticks {
            let a = (CGFloat(i) - pos) * 2 * .pi / CGFloat(ticks) - .pi / 2
            let long = i % 5 == 0
            if !numbers && !long { continue }
            let r0 = r * (long ? 0.80 : 0.87), r1 = r * 0.95
            var line = Path()
            line.move(to: CGPoint(x: c.x + cos(a) * r0, y: c.y + sin(a) * r0))
            line.addLine(to: CGPoint(x: c.x + cos(a) * r1, y: c.y + sin(a) * r1))
            ctx.stroke(line, with: .color(.white.opacity(long ? 0.9 : 0.45)), lineWidth: long ? 1.4 : 0.8)
            if numbers, i % 10 == 0 {
                ctx.draw(Text("\(i)").font(.system(size: r * 0.2, weight: .bold, design: .rounded)).foregroundColor(.white.opacity(0.85)),
                         at: CGPoint(x: c.x + cos(a) * r * 0.64, y: c.y + sin(a) * r * 0.64))
            }
        }
        let hub = r * 0.42
        ctx.fill(Path(ellipseIn: CGRect(x: c.x - hub, y: c.y - hub, width: hub * 2, height: hub * 2)), with: .color(Color(hex: 0x4A5263)))
    }
}

final class SafeWorld: ArcadeWorld {
    static var crownWraps: Bool { true }
    static let dwellTime: CGFloat = 0.35
    static let startTime: CGFloat = 30, maxTime: CGFloat = 45
    /// Números del dial por recorrido completo de la Corona (0…1): una vuelta de dial.
    static let ticksPerSpan = CGFloat(WatchSafe.ticks)

    private var size: CGSize = .zero
    private var pos: CGFloat = 0              // posición del dial, en números, sin acotar
    private var lastInput: CGFloat?
    private var target = 0
    private var dir: CGFloat = 1              // hacia dónde está el pasador actual (+1 = números crecientes)
    private var pins = 3, set = 0
    private var dwell: CGFloat = 0
    private var inNotch = false
    private var timeLeft = SafeWorld.startTime
    private var opened = 0
    private var openFlash: CGFloat = 0
    private var pinFlash: CGFloat = 0
    private var over = false
    private(set) var score = 0

    func reset(size: CGSize) {
        self.size = size
        pos = 0; lastInput = nil; pins = 3; set = 0; dwell = 0; inNotch = false
        timeLeft = Self.startTime; opened = 0; openFlash = 0; pinFlash = 0; over = false; score = 0
        dir = Bool.random() ? 1 : -1
        pickTarget()
    }

    func resize(_ size: CGSize) { self.size = size }

    private func pickTarget() {
        let n = CGFloat(WatchSafe.ticks)
        let from = (pos.rounded()).truncatingRemainder(dividingBy: n)
        let raw = from + dir * CGFloat(Int.random(in: 6...17))
        target = Int((raw.truncatingRemainder(dividingBy: n) + n).truncatingRemainder(dividingBy: n))
    }

    /// Distancia con signo (en números) del dial al objetivo, por el camino corto.
    private var offset: CGFloat {
        let n = CGFloat(WatchSafe.ticks)
        var d = (CGFloat(target) - pos).truncatingRemainder(dividingBy: n)
        if d > n / 2 { d -= n }
        if d < -n / 2 { d += n }
        return d
    }

    func step(dt: CGFloat, input: CGFloat) -> ArcadeEvent {
        guard size.width > 0, !over else { return .none }
        var event = ArcadeEvent.none
        if let last = lastInput {
            var delta = input - last
            if delta > 0.5 { delta -= 1 }
            if delta < -0.5 { delta += 1 }
            pos += delta * Self.ticksPerSpan
        }
        lastInput = input
        openFlash = max(0, openFlash - dt)
        pinFlash = max(0, pinFlash - dt)

        timeLeft -= dt
        if timeLeft <= 0 { timeLeft = 0; over = true; return .dead }

        let on = abs(offset) < 0.5
        if on, !inNotch { event = .notch }
        inNotch = on
        dwell = on ? dwell + dt : 0
        if dwell >= Self.dwellTime {
            dwell = 0; inNotch = false
            set += 1; score += 1; pinFlash = 0.3
            event = .bonus
            if set >= pins {
                opened += 1; score += 5
                timeLeft = min(Self.maxTime, timeLeft + max(5, 9 - CGFloat(opened) * 0.5))
                pins = min(3 + opened / 2, 6); set = 0
                openFlash = 0.7
            }
            dir = -dir
            pickTarget()
        }
        return event
    }

    func draw(_ ctx: inout GraphicsContext, size: CGSize) {
        let c = CGPoint(x: size.width / 2, y: size.height / 2 + 4)
        let r = min(size.width * 0.37, (size.height - 78) / 2)
        WatchSafe.drawDial(in: &ctx, center: c, radius: r, pos: pos, numbers: true)
        if openFlash > 0 {
            ctx.stroke(Path(ellipseIn: CGRect(x: c.x - r - 3, y: c.y - r - 3, width: r * 2 + 6, height: r * 2 + 6)),
                       with: .color(Color(hex: 0x6FD08C).opacity(min(1, openFlash * 2))), lineWidth: 4)
        }

        // Marca fija de arriba: se enciende al acercarse y se pone verde en la muesca.
        let near = max(0, 1 - abs(offset) / 4)
        let on = abs(offset) < 0.5
        let top = CGPoint(x: c.x, y: c.y - r - 2)
        var mark = Path()
        mark.move(to: CGPoint(x: top.x, y: top.y + 7)); mark.addLine(to: CGPoint(x: top.x - 6, y: top.y - 4))
        mark.addLine(to: CGPoint(x: top.x + 6, y: top.y - 4)); mark.closeSubpath()
        if near > 0 {
            let glow = 7 + near * 7
            ctx.fill(Path(ellipseIn: CGRect(x: top.x - glow, y: top.y - glow + 1, width: glow * 2, height: glow * 2)),
                     with: .color((on ? Color(hex: 0x6FD08C) : WatchSafe.gold).opacity(0.12 + near * 0.3)))
        }
        ctx.fill(mark, with: .color(on ? Color(hex: 0x6FD08C) : Color(white: 0.55 + near * 0.45).opacity(1)))
        if near > 0, !on { ctx.fill(mark, with: .color(WatchSafe.gold.opacity(near))) }

        // Centro: flecha del sentido y, encima de la muesca, el anillo que se va cerrando.
        let hub = r * 0.42
        ctx.draw(Text(dir > 0 ? "↺" : "↻").font(.system(size: hub * 1.25, weight: .heavy, design: .rounded))
            .foregroundColor(.white.opacity(0.9)), at: c)
        if dwell > 0 {
            var ring = Path()
            ring.addArc(center: c, radius: hub - 2, startAngle: .degrees(-90),
                        endAngle: .degrees(-90 + 360 * Double(min(1, dwell / Self.dwellTime))), clockwise: false)
            ctx.stroke(ring, with: .color(Color(hex: 0x6FD08C)), style: StrokeStyle(lineWidth: 3, lineCap: .round))
        }

        // Pasadores y tiempo, bajo el dial (lejos de las esquinas redondas).
        let pinsY = c.y + r + 11
        for i in 0..<pins {
            let x = c.x + (CGFloat(i) - CGFloat(pins - 1) / 2) * 11
            let rect = CGRect(x: x - 3.5, y: pinsY - 3.5, width: 7, height: 7)
            if i < set {
                ctx.fill(Path(ellipseIn: rect), with: .color(WatchSafe.gold))
            } else {
                ctx.stroke(Path(ellipseIn: rect), with: .color(.white.opacity(0.5)), lineWidth: 1)
            }
        }
        let barW = size.width - 76, barY = pinsY + 11
        ctx.fill(Path(roundedRect: CGRect(x: 38, y: barY, width: barW, height: 4), cornerRadius: 2), with: .color(.white.opacity(0.15)))
        let frac = min(1, timeLeft / Self.startTime)
        ctx.fill(Path(roundedRect: CGRect(x: 38, y: barY, width: barW * frac, height: 4), cornerRadius: 2),
                 with: .color(timeLeft < 8 ? Color(hex: 0xF0766B) : WatchSafe.gold))
    }

    func autopilot() -> CGFloat { (lastInput ?? 0.5) + offset / Self.ticksPerSpan }
}

struct WatchSafeView: View {
    var body: some View { WatchArcadeStage(info: WatchSafe.info, world: SafeWorld()) }
}

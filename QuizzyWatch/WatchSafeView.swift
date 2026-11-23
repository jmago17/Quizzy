//
//  WatchSafeView.swift — Quizzy Watch
//  Caja fuerte: se abre A TACTO. La Corona gira el dial (sin topes) y el reloj da un clic en cada
//  número; en el número de la clave el clic es más grave (`ArcadeEvent.notch`). No hay ninguna
//  pista visual de dónde está (Josu, 2026-11-23: «que sea solo háptico»). Al notarlo, se toca la
//  pantalla para fijar el pasador; tocar en otro número cuesta 3 s. El siguiente pasador está
//  hacia el OTRO lado (la flecha del pomo dice hacia dónde girar). Con todos, la caja se abre.
//  Contra reloj: 30 s (el aro dorado), y cada caja abierta devuelve tiempo. Las cajas van
//  teniendo más pasadores (3 → 6). Puntos: 1 por pasador, 5 por caja.
//  Los clics propios sustituyen a los del sistema (`crownHaptics = false`): así hay exactamente
//  uno por número. Si se pasa por la clave girando rápido, el clic grave suena igual.
//  Bucle y pantallas: `WatchArcadeStage`.
//

import SwiftUI

enum WatchSafe {
    static var info: ArcadeInfo {
        ArcadeInfo(id: "safe", title: AppLanguage.text("Caja fuerte", "Safe"),
                   hint: AppLanguage.text("Gira; toca en el clic grave", "Turn; tap on the deep click"), color: Color(hex: 0xF2C14E))
    }
    static let gold = Color(hex: 0xF2C14E)
    static let green = Color(hex: 0x6FD08C)
    static let steelTop = Color(hex: 0x39414F), steelBottom = Color(hex: 0x1D222B)
    static let ticks = 40

    private static func circle(_ c: CGPoint, _ r: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
    }

    /// Dial de caja fuerte: bisel metálico, esfera con rayas y números que giran, y pomo con
    /// estrías. `pos` = número que queda bajo la marca de arriba. `detail` = con números (el
    /// icono de la portada va sin ellos).
    static func drawDial(in ctx: inout GraphicsContext, center c: CGPoint, radius r: CGFloat, pos: CGFloat, detail: Bool) {
        // Bisel: aro claro arriba y oscuro abajo, como metal iluminado desde arriba.
        ctx.fill(circle(CGPoint(x: c.x, y: c.y + r * 0.05), r * 1.04), with: .color(.black.opacity(0.45)))
        ctx.fill(circle(c, r), with: .linearGradient(Gradient(colors: [Color(hex: 0xD5DBE6), Color(hex: 0x6B7484)]),
                                                     startPoint: CGPoint(x: c.x, y: c.y - r), endPoint: CGPoint(x: c.x, y: c.y + r)))
        let face = r * 0.9
        ctx.fill(circle(c, face), with: .radialGradient(Gradient(colors: [Color(hex: 0x2A303B), Color(hex: 0x12151B)]),
                                                        center: c, startRadius: face * 0.2, endRadius: face))
        for i in 0..<ticks {
            let a = (CGFloat(i) - pos) * 2 * .pi / CGFloat(ticks) - .pi / 2
            let long = i % 5 == 0
            if !detail && !long { continue }
            let r0 = face * (long ? 0.83 : 0.9), r1 = face * 0.97
            var line = Path()
            line.move(to: CGPoint(x: c.x + cos(a) * r0, y: c.y + sin(a) * r0))
            line.addLine(to: CGPoint(x: c.x + cos(a) * r1, y: c.y + sin(a) * r1))
            ctx.stroke(line, with: .color(.white.opacity(long ? 0.95 : 0.5)), lineWidth: long ? 1.5 : 0.8)
            if detail, long {
                ctx.draw(Text("\(i)").font(.system(size: r * 0.17, weight: .bold, design: .rounded)).foregroundColor(.white.opacity(0.9)),
                         at: CGPoint(x: c.x + cos(a) * face * 0.69, y: c.y + sin(a) * face * 0.69))
            }
        }
        // Pomo: disco metálico con estrías que giran con el dial.
        let knob = r * 0.46
        ctx.fill(circle(CGPoint(x: c.x, y: c.y + knob * 0.1), knob * 1.06), with: .color(.black.opacity(0.5)))
        ctx.fill(circle(c, knob), with: .linearGradient(Gradient(colors: [Color(hex: 0xC3CAD6), Color(hex: 0x566070)]),
                                                        startPoint: CGPoint(x: c.x, y: c.y - knob), endPoint: CGPoint(x: c.x, y: c.y + knob)))
        let grooves = detail ? 20 : 10
        for k in 0..<grooves {
            let a = (CGFloat(k) / CGFloat(grooves) - pos / CGFloat(ticks)) * 2 * .pi
            var g = Path()
            g.move(to: CGPoint(x: c.x + cos(a) * knob * 0.8, y: c.y + sin(a) * knob * 0.8))
            g.addLine(to: CGPoint(x: c.x + cos(a) * knob * 0.98, y: c.y + sin(a) * knob * 0.98))
            ctx.stroke(g, with: .color(.black.opacity(0.4)), lineWidth: 1)
        }
        ctx.fill(circle(c, knob * 0.72), with: .linearGradient(Gradient(colors: [Color(hex: 0x7C8696), Color(hex: 0xAEB6C3)]),
                                                               startPoint: CGPoint(x: c.x, y: c.y - knob), endPoint: CGPoint(x: c.x, y: c.y + knob)))
    }
}

final class SafeWorld: ArcadeWorld {
    static var crownWraps: Bool { true }
    static var crownHaptics: Bool { false }
    static let startTime: CGFloat = 30, maxTime: CGFloat = 45
    static let wrongCost: CGFloat = 3
    /// Números del dial por recorrido completo de la Corona (0…1). Con 24, una vuelta de dial pide
    /// algo más de un recorrido y medio: los clics quedan separados y no se pisan.
    static let ticksPerSpan: CGFloat = 24

    private var size: CGSize = .zero
    private var pos: CGFloat = 0              // posición del dial, en números, sin acotar
    private var lastInput: CGFloat?
    private var lastIndex = 0                 // número (redondeado, sin acotar) del fotograma anterior
    private var target = 0
    private var dir: CGFloat = 1              // hacia dónde está el pasador actual (+1 = números crecientes)
    private var pins = 3, set = 0
    private var timeLeft = SafeWorld.startTime
    private var opened = 0
    private var openFlash: CGFloat = 0
    private var wrongFlash: CGFloat = 0
    private var pinFlash: CGFloat = 0
    private var queued = ArcadeEvent.none     // lo que pidió `tap()`, para devolverlo en el siguiente paso
    private var clock: CGFloat = 0
    private var over = false
    private(set) var score = 0

    func reset(size: CGSize) {
        self.size = size
        pos = 0; lastInput = nil; lastIndex = 0; pins = 3; set = 0
        timeLeft = Self.startTime; opened = 0; openFlash = 0; wrongFlash = 0; pinFlash = 0
        queued = .none; clock = 0; over = false; score = 0
        dir = Bool.random() ? 1 : -1
        pickTarget()
    }

    func resize(_ size: CGSize) { self.size = size }

    private static func wrap(_ index: Int) -> Int { ((index % WatchSafe.ticks) + WatchSafe.ticks) % WatchSafe.ticks }
    private var index: Int { Int(pos.rounded()) }

    private func pickTarget() {
        target = Self.wrap(index + Int(dir) * Int.random(in: 6...16))
    }

    /// Distancia con signo (en números) del dial a la clave, por el camino corto.
    private var offset: CGFloat {
        let n = CGFloat(WatchSafe.ticks)
        var d = (CGFloat(target) - pos).truncatingRemainder(dividingBy: n)
        if d > n / 2 { d -= n }
        if d < -n / 2 { d += n }
        return d
    }

    func tap() {
        guard !over, size.width > 0 else { return }
        if Self.wrap(index) == target {
            set += 1; score += 1; pinFlash = 0.35
            queued = .success
            if set >= pins {
                opened += 1; score += 5
                timeLeft = min(Self.maxTime, timeLeft + max(5, 9 - CGFloat(opened) * 0.5))
                pins = min(3 + opened / 2, 6); set = 0
                openFlash = 0.8
            }
            dir = -dir
            pickTarget()
        } else {
            timeLeft = max(0, timeLeft - Self.wrongCost)
            wrongFlash = 0.4
            queued = .hit
        }
    }

    func step(dt: CGFloat, input: CGFloat) -> ArcadeEvent {
        guard size.width > 0, !over else { return .none }
        var event = queued
        queued = .none
        clock += dt
        if let last = lastInput {
            var delta = input - last
            if delta > 0.5 { delta -= 1 }
            if delta < -0.5 { delta += 1 }
            pos += delta * Self.ticksPerSpan
        }
        lastInput = input
        openFlash = max(0, openFlash - dt)
        wrongFlash = max(0, wrongFlash - dt)
        pinFlash = max(0, pinFlash - dt)

        timeLeft -= dt
        if timeLeft <= 0 { timeLeft = 0; over = true; return .dead }

        // Un clic por número. Si en este paso se ha pasado por la clave (aunque sea de largo), el grave.
        let now = index
        if now != lastIndex {
            let step = now > lastIndex ? 1 : -1
            var crossed = false
            var i = lastIndex
            while i != now { i += step; if Self.wrap(i) == target { crossed = true } }
            lastIndex = now
            if event == .none { event = crossed ? .notch : .detent }
        }
        return event
    }

    func draw(_ ctx: inout GraphicsContext, size: CGSize) {
        // Puerta de acero: degradado, cepillado horizontal, marco y remaches.
        let door = CGRect(x: 0, y: -30, width: size.width, height: size.height + 60)
        ctx.fill(Path(door), with: .linearGradient(Gradient(colors: [WatchSafe.steelTop, WatchSafe.steelBottom]),
                                                   startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))
        var brushed = Path()
        for k in 0..<Int(size.height / 5) {
            let y = CGFloat(k) * 5 + CGFloat((k * 37) % 3)
            brushed.move(to: CGPoint(x: CGFloat((k * 53) % 40), y: y))
            brushed.addLine(to: CGPoint(x: size.width - CGFloat((k * 31) % 40), y: y))
        }
        ctx.stroke(brushed, with: .color(.white.opacity(0.035)), lineWidth: 1)
        let c = CGPoint(x: size.width / 2, y: size.height / 2 + 5)
        let r = min(size.width * 0.37, (size.height - 74) / 2)
        let shake = wrongFlash > 0 ? sin(wrongFlash * 60) * 2.5 * (wrongFlash / 0.4) : 0
        // Panel hundido alrededor del dial.
        let panel = CGRect(x: c.x - r - 16, y: c.y - r - 16, width: r * 2 + 32, height: r * 2 + 44)
        ctx.fill(Path(roundedRect: panel, cornerRadius: 18), with: .color(.black.opacity(0.22)))
        ctx.stroke(Path(roundedRect: panel, cornerRadius: 18), with: .color(.white.opacity(0.10)), lineWidth: 1)
        for (dx, dy) in [(-1.0, -1.0), (1.0, -1.0), (-1.0, 1.0), (1.0, 1.0)] as [(CGFloat, CGFloat)] {
            let p = CGPoint(x: panel.midX + dx * (panel.width / 2 - 8), y: panel.midY + dy * (panel.height / 2 - 8))
            ctx.fill(Path(ellipseIn: CGRect(x: p.x - 2.6, y: p.y - 2.6, width: 5.2, height: 5.2)),
                     with: .linearGradient(Gradient(colors: [Color(hex: 0xC3CAD6), Color(hex: 0x566070)]),
                                           startPoint: CGPoint(x: p.x, y: p.y - 3), endPoint: CGPoint(x: p.x, y: p.y + 3)))
        }

        // Tiempo: aro dorado alrededor del dial, que se va consumiendo.
        let ringR = r + 6
        ctx.stroke(Path(ellipseIn: CGRect(x: c.x - ringR, y: c.y - ringR, width: ringR * 2, height: ringR * 2)),
                   with: .color(.black.opacity(0.4)), lineWidth: 3.5)
        var ring = Path()
        ring.addArc(center: c, radius: ringR, startAngle: .degrees(-90),
                    endAngle: .degrees(-90 + 360 * Double(min(1, timeLeft / Self.startTime))), clockwise: false)
        let ringColor = wrongFlash > 0 ? Color(hex: 0xF0766B) : (openFlash > 0 ? WatchSafe.green : (timeLeft < 8 ? Color(hex: 0xF0766B) : WatchSafe.gold))
        ctx.stroke(ring, with: .color(ringColor), style: StrokeStyle(lineWidth: 3.5, lineCap: .round))

        var dial = ctx
        dial.translateBy(x: shake, y: 0)
        WatchSafe.drawDial(in: &dial, center: c, radius: r, pos: pos, detail: true)

        // Marca fija: no cambia nunca (la clave se nota, no se ve).
        let top = CGPoint(x: c.x + shake, y: c.y - r * 0.9)
        var mark = Path()
        mark.move(to: CGPoint(x: top.x, y: top.y + 9)); mark.addLine(to: CGPoint(x: top.x - 5, y: top.y - 1))
        mark.addLine(to: CGPoint(x: top.x + 5, y: top.y - 1)); mark.closeSubpath()
        ctx.fill(mark, with: .color(Color(hex: 0xF0766B)))
        ctx.stroke(mark, with: .color(.black.opacity(0.5)), lineWidth: 0.8)

        // Flecha del pomo: hacia dónde girar el dial para el pasador que toca.
        let knob = r * 0.46
        let a0: CGFloat = -.pi / 2 - dir * 0.9, a1: CGFloat = -.pi / 2 + dir * 0.9   // dir > 0: el dial gira a izquierdas
        let pulse = 0.65 + 0.35 * sin(clock * 4)
        var arrow = Path()
        arrow.addArc(center: CGPoint(x: c.x + shake, y: c.y), radius: knob * 0.42, startAngle: .radians(Double(a1)), endAngle: .radians(Double(a0)), clockwise: dir > 0)
        let tip = CGPoint(x: c.x + shake + cos(a0) * knob * 0.42, y: c.y + sin(a0) * knob * 0.42)
        let tangent = a0 - dir * .pi / 2
        arrow.move(to: CGPoint(x: tip.x + cos(tangent + 2.5) * 5, y: tip.y + sin(tangent + 2.5) * 5))
        arrow.addLine(to: tip)
        arrow.addLine(to: CGPoint(x: tip.x + cos(tangent - 2.5) * 5, y: tip.y + sin(tangent - 2.5) * 5))
        ctx.stroke(arrow, with: .color(Color(hex: 0x1D222B).opacity(pulse)), style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))

        // Pasadores: pilotos bajo el dial.
        let pinsY = c.y + r + 17
        for i in 0..<pins {
            let x = c.x + (CGFloat(i) - CGFloat(pins - 1) / 2) * 12
            let rect = CGRect(x: x - 4, y: pinsY - 4, width: 8, height: 8)
            ctx.fill(Path(ellipseIn: rect.insetBy(dx: -1.2, dy: -1.2)), with: .color(.black.opacity(0.5)))
            if i < set {
                let fresh = i == set - 1 && pinFlash > 0
                if fresh { ctx.fill(Path(ellipseIn: rect.insetBy(dx: -4, dy: -4)), with: .color(WatchSafe.green.opacity(0.35))) }
                ctx.fill(Path(ellipseIn: rect), with: .color(WatchSafe.green))
                ctx.fill(Path(ellipseIn: CGRect(x: x - 2.4, y: pinsY - 2.8, width: 2.4, height: 1.8)), with: .color(.white.opacity(0.7)))
            } else {
                ctx.fill(Path(ellipseIn: rect), with: .color(Color(hex: 0x3A4250)))
            }
        }
        if openFlash > 0 {
            ctx.draw(Text(AppLanguage.text("¡Abierta!", "Open!")).font(.system(size: 17, weight: .black, design: .rounded))
                .foregroundColor(WatchSafe.green.opacity(Double(min(1, openFlash * 2.5)))), at: CGPoint(x: c.x, y: c.y - r - 14 - (0.8 - openFlash) * 8))
        } else if wrongFlash > 0 {
            ctx.draw(Text("−\(Int(Self.wrongCost)) s").font(.system(size: 15, weight: .black, design: .rounded))
                .foregroundColor(Color(hex: 0xF0766B).opacity(Double(min(1, wrongFlash * 4)))), at: CGPoint(x: c.x, y: c.y - r - 14))
        }
    }

    /// El piloto va a la clave y, al llegar, toca.
    func autopilot() -> CGFloat {
        if Self.wrap(index) == target, abs(offset) < 0.2 { tap() }
        return (lastInput ?? 0.5) + offset / Self.ticksPerSpan
    }
}

struct WatchSafeView: View {
    var body: some View { WatchArcadeStage(info: WatchSafe.info, world: SafeWorld()) }
}

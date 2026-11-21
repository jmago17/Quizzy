//
//  WatchLeaksView.swift — Quizzy Watch
//  Goteras: la tubería del techo gotea por cuatro juntas. La Corona mueve al fontanero, que
//  recoge las gotas con un cubo en el que caben 3. Para vaciarlo hay que ir a uno de los bidones
//  de los extremos. Una gota que llega al suelo, o que cae en el cubo lleno, cuesta una vida (3).
//  Las gotas avisan: crecen en la junta antes de soltarse. Con el tiempo caen más y más rápido.
//  Puntos: 1 por gota recogida; al vaciar, 2 / 5 / 9 según lleve 1 / 2 / 3 (compensa llenarlo).
//  Dibujos propios (formas en Canvas). Bucle y pantallas: `WatchArcadeStage`.
//

import SwiftUI

enum WatchLeaks {
    static var info: ArcadeInfo {
        ArcadeInfo(id: "leaks", title: AppLanguage.text("Goteras", "Leaks"),
                   hint: AppLanguage.text("Gira la Corona", "Turn the Crown"), color: Color(hex: 0x6FB7F2))
    }
    static let water = Color(hex: 0x6FB7F2)

    static func drawDrop(in ctx: inout GraphicsContext, at c: CGPoint, size s: CGFloat) {
        var drop = Path()
        drop.move(to: CGPoint(x: c.x, y: c.y - s))
        drop.addQuadCurve(to: CGPoint(x: c.x + s * 0.6, y: c.y + s * 0.25), control: CGPoint(x: c.x + s * 0.55, y: c.y - s * 0.2))
        drop.addArc(center: CGPoint(x: c.x, y: c.y + s * 0.25), radius: s * 0.6, startAngle: .zero, endAngle: .degrees(180), clockwise: false)
        drop.addQuadCurve(to: CGPoint(x: c.x, y: c.y - s), control: CGPoint(x: c.x - s * 0.55, y: c.y - s * 0.2))
        ctx.fill(drop, with: .color(water))
        ctx.fill(Path(ellipseIn: CGRect(x: c.x - s * 0.3, y: c.y, width: s * 0.22, height: s * 0.3)), with: .color(.white.opacity(0.7)))
    }

    /// Fontanero con casco y el cubo en alto. `fill` = gotas en el cubo (0…3).
    static func drawPlumber(in ctx: inout GraphicsContext, feet: CGPoint, fill: Int, alarm: Bool) {
        let suit = Color(hex: 0x4F6FB8), skin = Color(hex: 0xEBCFA8), helmet = Color(hex: 0xF2C14E)
        func rect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ r: CGFloat, _ c: Color) {
            ctx.fill(Path(roundedRect: CGRect(x: feet.x + x - w / 2, y: feet.y + y, width: w, height: h), cornerRadius: r), with: .color(c))
        }
        rect(-3, -6, 3.4, 6, 1.2, suit); rect(3, -6, 3.4, 6, 1.2, suit)          // piernas
        rect(0, -14, 10, 9, 3, suit)                                              // cuerpo
        rect(-6.5, -21, 2.6, 9, 1.3, skin); rect(6.5, -21, 2.6, 9, 1.3, skin)     // brazos en alto
        ctx.fill(Path(ellipseIn: CGRect(x: feet.x - 4, y: feet.y - 21, width: 8, height: 8)), with: .color(skin))
        rect(0, -22.5, 9.5, 4, 2, helmet)
        // Cubo: trapecio, con el agua por tercios.
        let top = feet.y - 33
        var bucket = Path()
        bucket.move(to: CGPoint(x: feet.x - 9, y: top)); bucket.addLine(to: CGPoint(x: feet.x + 9, y: top))
        bucket.addLine(to: CGPoint(x: feet.x + 6.5, y: top + 12)); bucket.addLine(to: CGPoint(x: feet.x - 6.5, y: top + 12))
        bucket.closeSubpath()
        ctx.fill(bucket, with: .color(Color(hex: 0x8D97A8)))
        if fill > 0 {
            let h = 12 * CGFloat(min(3, fill)) / 3
            var g = ctx
            g.clip(to: bucket)
            g.fill(Path(CGRect(x: feet.x - 9, y: top + 12 - h, width: 18, height: h)), with: .color(alarm ? Color(hex: 0xF0766B) : water))
        }
        ctx.stroke(bucket, with: .color(.white.opacity(0.5)), lineWidth: 0.8)
    }
}

final class LeakWorld: ArcadeWorld {
    struct Drop { var col: Int; var y: CGFloat; var grow: CGFloat = 0 }
    struct Puddle { var x: CGFloat; var life: CGFloat }
    static let capacity = 3
    private static let pipeY: CGFloat = 20
    private static let columns: [CGFloat] = [0.24, 0.41, 0.59, 0.76]

    private var size: CGSize = .zero
    private var drops: [Drop] = []
    private var puddles: [Puddle] = []
    private var sparks: [Spark] = []
    private var px: CGFloat = 0
    private var fill = 0
    private var lives = 3
    private var time: CGFloat = 0
    private var spawnT: CGFloat = 1
    private var pour: CGFloat = 0, pourLeft = true
    private(set) var score = 0

    // El lienzo llega hasta el borde inferior y las esquinas de la pantalla son redondas: con el
    // suelo a 6 pt del fondo, los bidones (que están justo en las esquinas) salían cortados.
    private var floorY: CGFloat { size.height - 24 }
    private static let barrelInset: CGFloat = 15
    private var bucketTop: CGFloat { floorY - 33 }
    private func x(_ col: Int) -> CGFloat { size.width * Self.columns[col] }
    private var atBarrel: Bool { px < Self.barrelInset + 9 || px > size.width - Self.barrelInset - 9 }

    func reset(size: CGSize) {
        self.size = size
        drops = []; puddles = []; sparks = []
        px = size.width / 2; fill = 0; lives = 3; time = 0; score = 0; spawnT = 1; pour = 0
    }

    func resize(_ size: CGSize) { self.size = size }

    func step(dt: CGFloat, input: CGFloat) -> ArcadeEvent {
        guard size.width > 0, lives > 0 else { return .none }
        var event = ArcadeEvent.none
        time += dt
        px = Self.barrelInset + 2 + input * (size.width - 2 * Self.barrelInset - 4)
        pour = max(0, pour - dt)
        Spark.step(&sparks, dt: dt)
        for i in puddles.indices { puddles[i].life -= dt }
        puddles.removeAll { $0.life <= 0 }

        // Vaciar el cubo en un bidón.
        if fill > 0, atBarrel {
            score += [0, 2, 5, 9][min(fill, 3)]
            fill = 0; pour = 0.45; pourLeft = px < size.width / 2
            event = .bonus
        }

        // Gotas nuevas: nunca dos formándose en la misma junta, y pocas a la vez al principio.
        spawnT -= dt
        if spawnT <= 0 {
            spawnT = max(0.75, 1.9 - time * 0.02) * CGFloat.random(in: 0.75...1.25)
            let free = Self.columns.indices.filter { c in !drops.contains { $0.col == c && $0.grow < 1 } }
            if drops.count < (time < 25 ? 2 : 3), let col = free.randomElement() {
                drops.append(Drop(col: col, y: Self.pipeY + 5))
            }
        }

        let speed = min(130, 60 + time * 1.0)
        var lost: CGFloat?
        for i in drops.indices.reversed() {
            if drops[i].grow < 1 { drops[i].grow += dt / 0.75; continue }
            let before = drops[i].y
            drops[i].y += speed * dt
            let dx = x(drops[i].col)
            if before < bucketTop + 6, drops[i].y >= bucketTop, abs(dx - px) < 11 {
                drops.remove(at: i)
                if fill < Self.capacity {
                    fill += 1; score += 1
                    Spark.burst(&sparks, at: CGPoint(x: px, y: bucketTop), color: WatchLeaks.water, count: 3)
                    if event == .none { event = .bonus }
                } else {
                    lost = px   // cubo lleno: se derrama
                }
            } else if drops[i].y >= floorY {
                drops.remove(at: i)
                lost = dx
            }
        }
        if let at = lost {
            puddles.append(Puddle(x: at, life: 1.6))
            Spark.burst(&sparks, at: CGPoint(x: at, y: floorY - 2), color: WatchLeaks.water, count: 10)
            lives -= 1
            drops.removeAll()        // respiro tras el fallo
            spawnT = 1.2
            if lives <= 0 { return .dead }
            event = .hit
        }
        return event
    }

    func draw(_ ctx: inout GraphicsContext, size: CGSize) {
        // Suelo y charcos.
        ctx.fill(Path(CGRect(x: 0, y: floorY, width: size.width, height: size.height - floorY)), with: .color(Color(hex: 0x3A4254)))
        for p in puddles {
            ctx.fill(Path(ellipseIn: CGRect(x: p.x - 13, y: floorY - 2.5, width: 26, height: 5)), with: .color(WatchLeaks.water.opacity(min(1, p.life))))
        }
        // Tubería con sus juntas.
        ctx.fill(Path(roundedRect: CGRect(x: 44, y: Self.pipeY - 4, width: size.width - 88, height: 7), cornerRadius: 3.5), with: .color(Color(hex: 0x8D97A8)))
        ctx.fill(Path(CGRect(x: 46, y: Self.pipeY - 3, width: size.width - 92, height: 1.5)), with: .color(.white.opacity(0.35)))
        for c in Self.columns.indices {
            ctx.fill(Path(roundedRect: CGRect(x: x(c) - 4, y: Self.pipeY - 5.5, width: 8, height: 10), cornerRadius: 2), with: .color(Color(hex: 0x5E687A)))
        }
        // Bidones en los extremos.
        for (bx, left) in [(Self.barrelInset, true), (size.width - Self.barrelInset, false)] as [(CGFloat, Bool)] {
            let rect = CGRect(x: bx - 8, y: floorY - 20, width: 16, height: 20)
            ctx.fill(Path(roundedRect: rect, cornerRadius: 3), with: .color(Color(hex: 0xB9773E)))
            ctx.fill(Path(CGRect(x: rect.minX, y: rect.minY + 5, width: 16, height: 1.6)), with: .color(Color(hex: 0x6E4322)))
            ctx.fill(Path(CGRect(x: rect.minX, y: rect.maxY - 6.5, width: 16, height: 1.6)), with: .color(Color(hex: 0x6E4322)))
            ctx.fill(Path(ellipseIn: CGRect(x: rect.minX + 2, y: rect.minY - 1.5, width: 12, height: 4)), with: .color(WatchLeaks.water))
            if pour > 0, left == pourLeft {
                ctx.draw(Text("+").font(.system(size: 13, weight: .black, design: .rounded)).foregroundColor(WatchLeaks.water),
                         at: CGPoint(x: bx, y: rect.minY - 10 - (0.45 - pour) * 20))
            }
        }
        for d in drops {
            let dx = x(d.col)
            if d.grow < 1 {
                WatchLeaks.drawDrop(in: &ctx, at: CGPoint(x: dx, y: Self.pipeY + 5 + d.grow * 3), size: 2 + 3.5 * d.grow)
            } else {
                WatchLeaks.drawDrop(in: &ctx, at: CGPoint(x: dx, y: d.y), size: 5.5)
            }
        }
        if lives > 0 {
            // Cubo lleno: el agua parpadea en rojo para avisar de que hay que vaciar.
            WatchLeaks.drawPlumber(in: &ctx, feet: CGPoint(x: px, y: floorY), fill: fill, alarm: fill >= Self.capacity && Int(time * 6) % 2 == 0)
        }
        Spark.draw(sparks, in: &ctx)
        drawLives(lives, in: &ctx, width: size.width)
    }

    func autopilot() -> CGFloat {
        let falling = drops.filter { $0.grow >= 1 }.max { $0.y < $1.y }
        // Lleno: a vaciar. Con algo y sin gotas en el aire: también.
        if fill >= Self.capacity || (fill > 0 && falling == nil) { return px < size.width / 2 ? 0 : 1 }
        guard let d = falling ?? drops.first else { return 0.5 }
        return (x(d.col) - Self.barrelInset - 2) / max(1, size.width - 2 * Self.barrelInset - 4)
    }
}

struct WatchLeaksView: View {
    var body: some View { WatchArcadeStage(info: WatchLeaks.info, world: LeakWorld()) }
}

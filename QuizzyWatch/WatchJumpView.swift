//
//  WatchJumpView.swift — Quizzy Watch
//  Brinco: saltador vertical sin fin, solo en el reloj. Un quokka rebota solo de rama en rama;
//  el jugador solo decide hacia dónde: la Corona lo mueve de lado a lado (salir por un borde =
//  entrar por el otro). Alternativa: arrastrar el dedo. Puntos = altura; caerse = fin.
//  Ramas: hoja (normal), azul (se mueve), seca (aguanta un salto) y flor (rebote largo).
//  Todo se pinta en un Canvas; el estado de la partida es una clase fuera de SwiftUI (`JumpWorld`)
//  que avanza con el reloj de `TimelineView`, para no invalidar vistas 60 veces por segundo.
//

import SwiftUI

enum WatchJump {
    static let bestKey = "watch.jump.best"
    static let color = Color(hex: 0xF28FB5)
    static var title: String { AppLanguage.text("Brinco", "Hop") }
}

// MARK: - Mascota

/// El quokka, dibujado con formas (sin imágenes). `feet` = punto de apoyo; `size` ≈ ancho del cuerpo.
enum Quokka {
    static func draw(in ctx: inout GraphicsContext, feet: CGPoint, size s: CGFloat, stretch: CGFloat = 1) {
        var g = ctx
        g.translateBy(x: feet.x, y: feet.y)
        g.scaleBy(x: 1 / stretch.squareRoot(), y: stretch)

        let fur = Color(hex: 0xB07E52), furDark = Color(hex: 0x8C6240), cream = Color(hex: 0xEBCFA8)
        let dark = Color(hex: 0x3A2A22)
        func oval(_ cx: CGFloat, _ cy: CGFloat, _ w: CGFloat, _ h: CGFloat, _ color: Color) {
            g.fill(Path(ellipseIn: CGRect(x: (cx - w / 2) * s, y: (cy - h / 2) * s, width: w * s, height: h * s)), with: .color(color))
        }
        oval(-0.40, -0.14, 0.34, 0.13, furDark)            // cola
        oval(-0.19, -0.05, 0.28, 0.12, furDark)            // patas
        oval(0.19, -0.05, 0.28, 0.12, furDark)
        oval(0, -0.36, 0.76, 0.66, fur)                    // cuerpo
        oval(0, -0.30, 0.44, 0.44, cream)                  // barriga
        oval(-0.31, -0.40, 0.14, 0.24, furDark)            // brazos
        oval(0.31, -0.40, 0.14, 0.24, furDark)
        oval(-0.24, -1.03, 0.24, 0.24, fur)                // orejas
        oval(0.24, -1.03, 0.24, 0.24, fur)
        oval(-0.24, -1.03, 0.12, 0.12, Color(hex: 0xE9A6A0))
        oval(0.24, -1.03, 0.12, 0.12, Color(hex: 0xE9A6A0))
        oval(0, -0.79, 0.68, 0.56, fur)                    // cabeza
        oval(0, -0.70, 0.38, 0.27, cream)                  // hocico
        oval(-0.25, -0.71, 0.11, 0.08, Color(hex: 0xF09A9A).opacity(0.7)) // mofletes
        oval(0.25, -0.71, 0.11, 0.08, Color(hex: 0xF09A9A).opacity(0.7))
        oval(-0.15, -0.85, 0.09, 0.10, dark)               // ojos
        oval(0.15, -0.85, 0.09, 0.10, dark)
        oval(-0.14, -0.87, 0.03, 0.03, .white)
        oval(0.16, -0.87, 0.03, 0.03, .white)
        oval(0, -0.76, 0.12, 0.08, dark)                   // nariz
        var smile = Path()                                  // la sonrisa del quokka
        smile.move(to: CGPoint(x: -0.10 * s, y: -0.68 * s))
        smile.addQuadCurve(to: CGPoint(x: 0.10 * s, y: -0.68 * s), control: CGPoint(x: 0, y: -0.58 * s))
        g.stroke(smile, with: .color(dark), style: StrokeStyle(lineWidth: max(0.8, s * 0.035), lineCap: .round))
    }
}

// MARK: - Mundo

/// Estado y física de una partida. Coordenadas de mundo: x hacia la derecha, y hacia ARRIBA.
final class JumpWorld {
    enum Kind { case leaf, moving, fragile }
    struct Platform {
        var x: CGFloat          // centro
        var y: CGFloat          // cara superior
        var w: CGFloat
        var kind: Kind
        var vx: CGFloat = 0
        var spring = false
        var broken = false
        var springKick: CGFloat = 0   // 1 → 0 tras usar la flor (animación)
    }
    enum Event { case none, bounce, spring, dead }

    static let gravity: CGFloat = 720
    static let jumpSpeed: CGFloat = 318      // ≈ 70 pt de altura
    static let springSpeed: CGFloat = 540    // ≈ 200 pt
    static let playerSize: CGFloat = 26

    private(set) var size: CGSize = .zero
    private(set) var platforms: [Platform] = []
    var px: CGFloat = 0
    private(set) var py: CGFloat = 0         // pies
    private(set) var vy: CGFloat = 0
    private(set) var camY: CGFloat = 0       // y de mundo del borde inferior de la pantalla
    private(set) var maxHeight: CGFloat = 0
    private(set) var squash: CGFloat = 0
    private(set) var lastLandedY: CGFloat = 0
    private var topY: CGFloat = 0
    private var rng = SystemRandomNumberGenerator()
    var lastDate: Date?

    var score: Int { Int(maxHeight / 10) }
    var stretch: CGFloat { 1 + max(-0.5, min(1, vy / Self.jumpSpeed)) * 0.12 - squash * 0.22 }

    func reset(size: CGSize) {
        self.size = size
        platforms = [Platform(x: size.width / 2, y: 26, w: 64, kind: .leaf)]
        px = size.width / 2; py = 26; vy = 0
        camY = 0; maxHeight = 0; squash = 0; topY = 26; lastLandedY = 26
        lastDate = nil
        fill()
    }

    func start() { vy = Self.jumpSpeed; lastDate = nil }
    /// Cambio de tamaño del lienzo a mitad de partida: no reinicia.
    func resize(_ size: CGSize) { self.size = size }

    private func fill() {
        while topY < camY + size.height + 80 {
            let d = min(1, topY / 4500)   // dificultad 0…1 con la altura
            topY += CGFloat.random(in: (26 + 10 * d)...(44 + 22 * d), using: &rng)   // siempre < 70 (alcanzable)
            let w: CGFloat = 44 - 12 * d
            var p = Platform(x: CGFloat.random(in: (w / 2 + 4)...(size.width - w / 2 - 4), using: &rng), y: topY, w: w, kind: .leaf)
            let roll = Double.random(in: 0..<1, using: &rng)
            if roll < 0.10 + 0.22 * d {
                p.kind = .moving
                p.vx = CGFloat.random(in: 28...(40 + 30 * d), using: &rng) * (Bool.random(using: &rng) ? 1 : -1)
            } else if roll < 0.16 + 0.40 * d {
                p.kind = .fragile
            } else if Double.random(in: 0..<1, using: &rng) < 0.09 {
                p.spring = true
            }
            platforms.append(p)
        }
    }

    func step(dt: CGFloat) -> Event {
        guard size.width > 0 else { return .none }
        var event = Event.none
        for i in platforms.indices {
            if platforms[i].broken { platforms[i].y -= 220 * dt; continue }
            platforms[i].springKick = max(0, platforms[i].springKick - dt * 4)
            guard platforms[i].kind == .moving else { continue }
            platforms[i].x += platforms[i].vx * dt
            let half = platforms[i].w / 2
            if platforms[i].x < half + 2 { platforms[i].x = half + 2; platforms[i].vx = abs(platforms[i].vx) }
            if platforms[i].x > size.width - half - 2 { platforms[i].x = size.width - half - 2; platforms[i].vx = -abs(platforms[i].vx) }
        }
        squash = max(0, squash - dt * 5)
        vy -= Self.gravity * dt
        var newY = py + vy * dt
        if vy < 0 {
            // Aterriza si los pies cruzan la cara superior de una rama en este paso.
            for i in platforms.indices where !platforms[i].broken {
                let p = platforms[i]
                guard py >= p.y, newY <= p.y, abs(px - p.x) < p.w / 2 + Self.playerSize * 0.22 else { continue }
                newY = p.y
                lastLandedY = p.y
                squash = 1
                if p.spring {
                    vy = Self.springSpeed; platforms[i].springKick = 1; event = .spring
                } else {
                    vy = Self.jumpSpeed; event = .bounce
                }
                if p.kind == .fragile { platforms[i].broken = true }
                break
            }
        }
        py = newY
        maxHeight = max(maxHeight, py - 26)
        camY = max(camY, py - size.height * 0.52)
        platforms.removeAll { $0.y < camY - 30 }
        fill()
        return py < camY - 12 ? .dead : event
    }

    #if DEBUG
    /// Piloto automático para capturas (QW_JUMP_DEMO=1): apunta a la siguiente rama alcanzable.
    func autopilotTarget() -> CGFloat {
        let next = platforms.filter { !$0.broken && $0.y > lastLandedY + 4 && $0.y - lastLandedY < 66 }.min { $0.y < $1.y }
        let stay = platforms.filter { !$0.broken && abs($0.y - lastLandedY) < 2 }.first
        return (next ?? stay)?.x ?? px
    }
    #endif
}

// MARK: - Vista

struct WatchJumpView: View {
    private enum Phase { case ready, playing, over }

    @State private var world = JumpWorld()
    @State private var phase = Phase.ready
    @State private var crown = 0.5            // 0…1 = posición horizontal; da la vuelta por los bordes
    @State private var dragStart: Double?
    @State private var score = 0
    @State private var record = false
    @State private var redraw = 0
    @AppStorage(WatchJump.bestKey, store: PuzzleProgress.shared.defaults) private var best = 0
    @Environment(\.scenePhase) private var scene
    @FocusState private var crownFocus: Bool

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation(paused: phase != .playing || scene != .active)) { timeline in
                // El Canvas TIENE que capturar la fecha: SwiftUI compara lo que captura el cierre y, si es
                // idéntico al del fotograma anterior, no repinta. Sin esto la física corría a 60 pasos/s
                // y la pantalla solo se actualizaba al cambiar el marcador (medido: 0 dibujados/s).
                let frame = timeline.date
                Canvas { ctx, size in
                    _ = (redraw, frame)
                    #if DEBUG
                    Self.probe.draws += 1
                    #endif
                    draw(&ctx, size: size)
                }
                .onChange(of: timeline.date) { _, now in tick(now, width: geo.size.width) }
            }
            .overlay { overlay }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 4)
                .onChanged { v in
                    let start = dragStart ?? crown
                    dragStart = start
                    let raw = start + Double(v.translation.width / max(1, geo.size.width))
                    crown = raw - raw.rounded(.down)
                }
                .onEnded { _ in dragStart = nil })
            .onTapGesture { if phase == .ready { begin() } }
            .onAppear { world.reset(size: geo.size); crown = 0.5; redraw += 1; crownFocus = true; demoStart() }
            .onChange(of: geo.size) { _, new in
                if phase == .playing { world.resize(new) } else { world.reset(size: new); redraw += 1 }
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .navigationTitle(phase == .ready ? WatchJump.title : "\(score)")
        .focusable()
        .focused($crownFocus)
        .digitalCrownRotation($crown, from: 0, through: 1, sensitivity: .low, isContinuous: true, isHapticFeedbackEnabled: false)
        .onChange(of: scene) { _, new in if new != .active { world.lastDate = nil } }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(WatchJump.title)
        .accessibilityValue(AppLanguage.text("\(score) puntos", "\(score) points"))
    }

    @ViewBuilder private var overlay: some View {
        switch phase {
        case .playing:
            EmptyView()
        case .ready:
            VStack(spacing: 2) {
                Label(AppLanguage.text("Gira la Corona", "Turn the Crown"), systemImage: "digitalcrown.horizontal.arrow.clockwise")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                Text(AppLanguage.text("Toca para empezar", "Tap to start"))
                    .font(.caption2).foregroundStyle(WTheme.inkSecondary)
            }
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(WTheme.surface.opacity(0.9), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .allowsHitTesting(false)
        case .over:
            VStack(spacing: 4) {
                Text("\(score)").font(.system(size: 32, weight: .heavy, design: .rounded)).foregroundStyle(WatchJump.color)
                Text(record ? AppLanguage.text("¡Nuevo récord!", "New best!") : AppLanguage.text("Récord: \(best)", "Best: \(best)"))
                    .font(.footnote).foregroundStyle(record ? WTheme.success : WTheme.inkSecondary)
                Button(AppLanguage.text("Otra vez", "Again")) { world.reset(size: world.size); crown = 0.5; begin() }
                    .tint(WatchJump.color)
            }
            .padding(10)
            .background(WTheme.surface.opacity(0.94), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .padding(.horizontal, 14)
        }
    }

    // MARK: Bucle

    private func begin() {
        score = 0; record = false
        world.start()
        phase = .playing
        crownFocus = true
    }

    private func tick(_ now: Date, width: CGFloat) {
        guard phase == .playing else { return }
        #if DEBUG
        Self.probe.tick(now)
        #endif
        defer { world.lastDate = now }
        guard let last = world.lastDate else { return }
        let dt = CGFloat(min(1.0 / 20, max(0, now.timeIntervalSince(last))))
        #if DEBUG
        if Self.demo {
            let dx = world.autopilotTarget() - world.px
            crown = Double((world.px + max(-240 * dt, min(240 * dt, dx))) / max(1, width))
        }
        #endif
        world.px = CGFloat(crown) * width
        switch world.step(dt: dt) {
        case .none, .bounce: break
        case .spring: WHaptics.tick()
        case .dead: finish()
        }
        if world.score != score { score = world.score }
    }

    private func finish() {
        phase = .over
        record = score > best
        if record { best = score; WHaptics.success() } else { WHaptics.error() }
    }

    #if DEBUG
    private static let demo = ProcessInfo.processInfo.environment["QW_JUMP_DEMO"] == "1"
    #endif
    #if DEBUG
    /// Medidor (QW_JUMP_FPS=1): imprime cada segundo cuántos pasos de física y cuántos dibujados hubo.
    final class Probe {
        var ticks = 0, draws = 0, mark: Date?
        let on = ProcessInfo.processInfo.environment["QW_JUMP_FPS"] == "1"
        func tick(_ now: Date) {
            guard on else { return }
            ticks += 1
            if mark == nil { mark = now }
            if now.timeIntervalSince(mark!) >= 1 { print("QWFPS ticks=\(ticks) draws=\(draws)"); ticks = 0; draws = 0; mark = now }
        }
    }
    static let probe = Probe()
    #endif
    private func demoStart() {
        #if DEBUG
        if (Self.demo || Self.probe.on), phase == .ready { begin() }
        #endif
    }

    // MARK: Dibujo

    private func draw(_ ctx: inout GraphicsContext, size: CGSize) {
        let w = world
        func sy(_ worldY: CGFloat) -> CGFloat { size.height - (worldY - w.camY) }

        // Estrellas con paralaje (posiciones fijas por índice).
        for i in 0..<22 {
            let x = CGFloat((i * 73 + 11) % 100) / 100 * size.width
            let base = CGFloat((i * 131 + 37) % 100) / 100 * size.height
            let depth: CGFloat = i % 3 == 0 ? 0.30 : 0.14
            let y = (base + w.camY * depth).truncatingRemainder(dividingBy: size.height)
            let r: CGFloat = i % 3 == 0 ? 1.1 : 0.7
            ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                     with: .color(.white.opacity(i % 3 == 0 ? 0.55 : 0.3)))
        }

        for p in w.platforms {
            let top = sy(p.y)
            guard top > -12, top < size.height + 12 else { continue }
            let rect = CGRect(x: p.x - p.w / 2, y: top, width: p.w, height: 7)
            let fill: Color
            switch p.kind {
            case .leaf: fill = Color(hex: 0x6FC27A)
            case .moving: fill = Color(hex: 0x8FC2F2)
            case .fragile: fill = Color(hex: 0xC9A27A)
            }
            let shape = Path(roundedRect: rect, cornerRadius: 3.5)
            ctx.fill(shape, with: .color(fill.opacity(p.broken ? 0.45 : 1)))
            ctx.fill(Path(roundedRect: CGRect(x: rect.minX + 3, y: rect.minY + 1, width: rect.width - 6, height: 1.5), cornerRadius: 1),
                     with: .color(.white.opacity(0.35)))
            if p.kind == .fragile {
                // Grieta: avisa de que solo aguanta un salto.
                var crack = Path()
                crack.move(to: CGPoint(x: rect.midX - 3, y: rect.minY))
                crack.addLine(to: CGPoint(x: rect.midX + 1, y: rect.midY))
                crack.addLine(to: CGPoint(x: rect.midX - 2, y: rect.maxY))
                ctx.stroke(crack, with: .color(Color(hex: 0x5A4030)), lineWidth: 1.2)
            }
            if p.spring {
                // Flor: rebote largo. Se aplasta un instante al usarla.
                let h: CGFloat = 7 - 3 * p.springKick
                ctx.fill(Path(CGRect(x: p.x - 0.75, y: top - h + 2, width: 1.5, height: h - 2)), with: .color(Color(hex: 0x4E9A5A)))
                for k in 0..<5 {
                    let a = CGFloat(k) / 5 * 2 * .pi
                    ctx.fill(Path(ellipseIn: CGRect(x: p.x + cos(a) * 2.6 - 2, y: top - h + sin(a) * 2.6 - 2, width: 4, height: 4)),
                             with: .color(WatchJump.color))
                }
                ctx.fill(Path(ellipseIn: CGRect(x: p.x - 1.6, y: top - h - 1.6, width: 3.2, height: 3.2)), with: .color(Color(hex: 0xF2D45C)))
            }
        }

        // El quokka (y su copia al otro lado cuando asoma por un borde).
        let s = JumpWorld.playerSize
        let feetY = sy(w.py)
        for dx in [0, -size.width, size.width] {
            let x = w.px + dx
            guard x > -s, x < size.width + s else { continue }
            Quokka.draw(in: &ctx, feet: CGPoint(x: x, y: feetY), size: s, stretch: w.stretch)
        }
    }
}

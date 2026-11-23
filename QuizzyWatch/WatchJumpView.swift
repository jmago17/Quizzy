//
//  WatchJumpView.swift — Quizzy Watch
//  Brinco: saltador vertical sin fin, solo en el reloj. Un pulpo rebota solo de roca en roca;
//  el jugador solo decide hacia dónde: la Corona lo mueve de lado a lado (salir por un borde =
//  entrar por el otro). Alternativa: arrastrar el dedo. Puntos = altura (+5 por cangrejo); caerse = fin.
//  Apoyos: alga (normal), azul (se mueve), arena (aguanta un salto) y corriente de agua (chorro: salto largo).
//  Malos: cangrejos que pasean por algunos apoyos. Caerles encima los aplasta; tocarlos de lado
//  o desde abajo aturde al pulpo, que ya no se agarra a nada y cae.
//  Todo se pinta en un Canvas; el estado de la partida es una clase fuera de SwiftUI (`JumpWorld`)
//  que avanza con el reloj de `TimelineView`, para no invalidar vistas 60 veces por segundo.
//

import SwiftUI

enum WatchJump {
    static let bestKey = "watch.jump.best"
    static let color = Color(hex: 0xF28FB5)
    static var title: String { AppLanguage.text("Brinco", "Hop") }
}

// MARK: - Mascota y malos

/// El pulpo, dibujado con formas (sin imágenes). `feet` = punto de apoyo; `size` ≈ ancho de la cabeza.
/// Los tentáculos son la animación del salto: `pose` 1 = subiendo (juntos y estirados hacia abajo,
/// como un chorro), −1 = cayendo (abiertos y con las puntas hacia arriba, de paracaídas);
/// `squash` 1 = recién apoyado (aplastados y abiertos sobre la roca). `time` les da un vaivén.
enum Octopus {
    static func draw(in ctx: inout GraphicsContext, feet: CGPoint, size s: CGFloat, stretch: CGFloat = 1,
                     pose: CGFloat = -0.15, squash: CGFloat = 0, time: CGFloat = 0, hurt: Bool = false) {
        var g = ctx
        g.translateBy(x: feet.x, y: feet.y)
        let skin = Color(hex: 0xF28FB5), skinDark = Color(hex: 0xD9689A), dark = Color(hex: 0x3A2233)
        func mix(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat { a + (b - a) * t }

        // Tentáculos (6), detrás de la cabeza.
        let fall = (1 - max(-1, min(1, pose))) / 2          // 0 subiendo … 1 cayendo
        let spread = mix(mix(0.13, 0.66, fall), 0.74, squash)
        let tipY = mix(mix(0.04, -0.26, fall), 0, squash)
        let bendY = mix(mix(-0.20, 0.03, fall), 0.0, squash)
        for i in 0..<6 {
            let u = (CGFloat(i) - 2.5) / 2.5
            let sway = sin(time * 9 + CGFloat(i) * 1.3) * 0.05 * (1 - squash)
            // Los de fuera se abren más y suben más la punta al caer.
            let tip = CGPoint(x: (u * spread + sway) * s, y: (tipY - abs(u) * 0.10 * fall * (1 - squash)) * s)
            var t = Path()
            t.move(to: CGPoint(x: u * 0.27 * s, y: -0.44 * s))
            t.addQuadCurve(to: tip, control: CGPoint(x: (u * spread * 0.95 - sway) * s, y: bendY * s))
            g.stroke(t, with: .color(i % 2 == 0 ? skinDark : skin), style: StrokeStyle(lineWidth: s * 0.13, lineCap: .round))
        }

        // Cabeza: se estira al subir y se aplasta al apoyar.
        var h = g
        h.translateBy(x: 0, y: -0.40 * s)
        h.scaleBy(x: 1 / stretch.squareRoot(), y: stretch)
        func oval(_ cx: CGFloat, _ cy: CGFloat, _ w: CGFloat, _ hh: CGFloat, _ color: Color) {
            h.fill(Path(ellipseIn: CGRect(x: (cx - w / 2) * s, y: (cy - hh / 2) * s, width: w * s, height: hh * s)), with: .color(color))
        }
        oval(0, -0.36, 0.86, 0.80, skin)
        oval(-0.16, -0.58, 0.26, 0.16, .white.opacity(0.28))            // brillo
        oval(-0.30, -0.20, 0.13, 0.09, Color(hex: 0xF0766B).opacity(0.75))   // mofletes
        oval(0.30, -0.20, 0.13, 0.09, Color(hex: 0xF0766B).opacity(0.75))
        if hurt {
            for side in [-1.0, 1.0] as [CGFloat] {                       // ojos en X
                var x = Path()
                x.move(to: CGPoint(x: (side * 0.17 - 0.06) * s, y: -0.38 * s)); x.addLine(to: CGPoint(x: (side * 0.17 + 0.06) * s, y: -0.26 * s))
                x.move(to: CGPoint(x: (side * 0.17 + 0.06) * s, y: -0.38 * s)); x.addLine(to: CGPoint(x: (side * 0.17 - 0.06) * s, y: -0.26 * s))
                h.stroke(x, with: .color(dark), style: StrokeStyle(lineWidth: max(1, s * 0.05), lineCap: .round))
            }
        } else {
            oval(-0.17, -0.32, 0.19, 0.22, .white)
            oval(0.17, -0.32, 0.19, 0.22, .white)
            let look = max(-1, min(1, pose)) * -0.03                     // mira hacia donde va
            oval(-0.16, -0.31 + look, 0.10, 0.12, dark)
            oval(0.18, -0.31 + look, 0.10, 0.12, dark)
            oval(-0.14, -0.34 + look, 0.035, 0.035, .white)
            oval(0.20, -0.34 + look, 0.035, 0.035, .white)
        }
        var smile = Path()
        smile.move(to: CGPoint(x: -0.07 * s, y: -0.16 * s))
        smile.addQuadCurve(to: CGPoint(x: 0.07 * s, y: -0.16 * s), control: CGPoint(x: 0, y: (hurt ? -0.22 : -0.09) * s))
        h.stroke(smile, with: .color(dark), style: StrokeStyle(lineWidth: max(0.8, s * 0.035), lineCap: .round))
    }
}

/// El cangrejo. `base` = punto de apoyo (centro, abajo); `size` = ancho del caparazón.
enum Crab {
    static func draw(in ctx: inout GraphicsContext, base: CGPoint, size s: CGFloat, phase: CGFloat) {
        let shell = Color(hex: 0xE8553F), shellDark = Color(hex: 0xB93A2B), dark = Color(hex: 0x2A1614)
        let step = phase.truncatingRemainder(dividingBy: 1) < 0.5
        for side in [-1.0, 1.0] as [CGFloat] {
            for k in 0..<3 {                                             // patas que alternan
                let lift: CGFloat = (k % 2 == 0) == step ? 0 : s * 0.08
                var leg = Path()
                leg.move(to: CGPoint(x: base.x + side * s * (0.22 + CGFloat(k) * 0.10), y: base.y - s * 0.28))
                leg.addLine(to: CGPoint(x: base.x + side * s * (0.42 + CGFloat(k) * 0.12), y: base.y - lift))
                ctx.stroke(leg, with: .color(shellDark), style: StrokeStyle(lineWidth: max(1, s * 0.08), lineCap: .round))
            }
            // Pinza levantada, con la muesca.
            let claw = CGPoint(x: base.x + side * s * 0.62, y: base.y - s * (0.62 + (step ? 0.05 : 0)))
            var arm = Path()
            arm.move(to: CGPoint(x: base.x + side * s * 0.36, y: base.y - s * 0.38)); arm.addLine(to: claw)
            ctx.stroke(arm, with: .color(shellDark), style: StrokeStyle(lineWidth: max(1, s * 0.10), lineCap: .round))
            ctx.fill(Path(ellipseIn: CGRect(x: claw.x - s * 0.17, y: claw.y - s * 0.17, width: s * 0.34, height: s * 0.30)), with: .color(shell))
            var notch = Path()
            notch.move(to: claw); notch.addLine(to: CGPoint(x: claw.x + side * s * 0.10, y: claw.y - s * 0.20))
            ctx.stroke(notch, with: .color(dark), lineWidth: max(0.8, s * 0.06))
            // Ojo con pedúnculo.
            let eye = CGPoint(x: base.x + side * s * 0.16, y: base.y - s * 0.74)
            var stalk = Path()
            stalk.move(to: CGPoint(x: eye.x, y: base.y - s * 0.5)); stalk.addLine(to: eye)
            ctx.stroke(stalk, with: .color(shellDark), lineWidth: max(1, s * 0.07))
            ctx.fill(Path(ellipseIn: CGRect(x: eye.x - s * 0.09, y: eye.y - s * 0.09, width: s * 0.18, height: s * 0.18)), with: .color(.white))
            ctx.fill(Path(ellipseIn: CGRect(x: eye.x - s * 0.04, y: eye.y - s * 0.04, width: s * 0.09, height: s * 0.09)), with: .color(dark))
        }
        ctx.fill(Path(ellipseIn: CGRect(x: base.x - s * 0.5, y: base.y - s * 0.62, width: s, height: s * 0.52)), with: .color(shell))
        ctx.fill(Path(ellipseIn: CGRect(x: base.x - s * 0.3, y: base.y - s * 0.57, width: s * 0.4, height: s * 0.12)), with: .color(.white.opacity(0.25)))
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
        var springKick: CGFloat = 0   // 1 → 0 tras usar la corriente (animación)
        var crab: CGFloat?            // cangrejo: desplazamiento respecto al centro del apoyo
        var crabDir: CGFloat = 1
    }
    enum Event { case none, bounce, spring, stomp, hit, dead }

    static let gravity: CGFloat = 720
    static let jumpSpeed: CGFloat = 318      // ≈ 70 pt de altura
    static let springSpeed: CGFloat = 540    // ≈ 200 pt
    static let playerSize: CGFloat = 26
    static let crabSize: CGFloat = 15
    #if DEBUG
    /// QW_JUMP_CRABS=1 (capturas): cangrejos desde el principio y en casi la mitad de los apoyos.
    private static let manyCrabs = ProcessInfo.processInfo.environment["QW_JUMP_CRABS"] == "1"
    static var crabsFrom: CGFloat { manyCrabs ? 60 : 700 }
    static var crabBase: Double { manyCrabs ? 0.45 : 0.05 }
    #else
    static let crabsFrom: CGFloat = 700
    static let crabBase = 0.05
    #endif

    private(set) var size: CGSize = .zero
    private(set) var platforms: [Platform] = []
    var px: CGFloat = 0
    private(set) var py: CGFloat = 0         // pies
    private(set) var vy: CGFloat = 0
    private(set) var camY: CGFloat = 0       // y de mundo del borde inferior de la pantalla
    private(set) var maxHeight: CGFloat = 0
    private(set) var squash: CGFloat = 0
    private(set) var lastLandedY: CGFloat = 0
    private(set) var time: CGFloat = 0
    private(set) var hurt = false            // aturdido por un cangrejo: ya no se apoya en nada
    private(set) var sparks: [Spark] = []    // en coordenadas (x, −y de mundo)
    private var bonus = 0
    private var topY: CGFloat = 0
    private var rng = SystemRandomNumberGenerator()
    var lastDate: Date?

    var score: Int { Int(maxHeight / 10) + bonus }
    var pose: CGFloat { max(-1, min(1, vy / Self.jumpSpeed)) }
    var stretch: CGFloat { 1 + max(-0.5, min(1, vy / Self.jumpSpeed)) * 0.12 - squash * 0.22 }

    func reset(size: CGSize) {
        self.size = size
        platforms = [Platform(x: size.width / 2, y: 26, w: 64, kind: .leaf)]
        px = size.width / 2; py = 26; vy = 0
        camY = 0; maxHeight = 0; squash = 0; topY = 26; lastLandedY = 26
        time = 0; hurt = false; sparks = []; bonus = 0
        lastDate = nil
        fill()
    }

    func start() { vy = Self.jumpSpeed; lastDate = nil }
    /// Cambio de tamaño del lienzo a mitad de partida: no reinicia.
    func resize(_ size: CGSize) { self.size = size }

    private func fill() {
        while topY < camY + size.height + 80 {
            // Dificultad 0…1 con la altura. Hasta el 2026-11-23 llegaba a 1 en 4500 pt (450 puntos) y
            // «se ponía difícil muy pronto»: ahora tarda 14 000 pt y además entra despacio (curva
            // cuadrática al principio). Los primeros 500 pt son solo algas anchas, para coger el ritmo.
            let t = min(1, max(0, topY - 500) / 13500)
            let d = t * t * (3 - 2 * t)
            topY += CGFloat.random(in: (24 + 12 * d)...(38 + 28 * d), using: &rng)   // siempre < 70 (alcanzable)
            let w: CGFloat = 50 - 18 * d
            var p = Platform(x: CGFloat.random(in: (w / 2 + 4)...(size.width - w / 2 - 4), using: &rng), y: topY, w: w, kind: .leaf)
            let roll = Double.random(in: 0..<1, using: &rng)
            if topY > 500, roll < 0.05 + 0.27 * d {
                p.kind = .moving
                p.vx = CGFloat.random(in: 28...(40 + 30 * d), using: &rng) * (Bool.random(using: &rng) ? 1 : -1)
            } else if topY > 900, roll < 0.08 + 0.48 * d {
                p.kind = .fragile
            } else if Double.random(in: 0..<1, using: &rng) < 0.09 {
                p.spring = true
            } else if topY > Self.crabsFrom, Double.random(in: 0..<1, using: &rng) < Self.crabBase + 0.17 * d {
                // Cangrejo: solo en apoyos firmes y sin corriente, y nunca en los primeros saltos.
                p.crab = 0
                p.crabDir = Bool.random(using: &rng) ? 1 : -1
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
            if let off = platforms[i].crab {
                let reach = max(0, platforms[i].w / 2 - 6)
                var x = off + platforms[i].crabDir * 14 * dt
                if abs(x) > reach { x = reach * platforms[i].crabDir; platforms[i].crabDir *= -1 }
                platforms[i].crab = x
            }
            guard platforms[i].kind == .moving else { continue }
            platforms[i].x += platforms[i].vx * dt
            let half = platforms[i].w / 2
            if platforms[i].x < half + 2 { platforms[i].x = half + 2; platforms[i].vx = abs(platforms[i].vx) }
            if platforms[i].x > size.width - half - 2 { platforms[i].x = size.width - half - 2; platforms[i].vx = -abs(platforms[i].vx) }
        }
        time += dt
        Spark.step(&sparks, dt: dt)
        squash = max(0, squash - dt * 5)
        vy -= Self.gravity * dt
        var newY = py + vy * dt
        // Cangrejos: caerle encima lo aplasta (y rebota); tocarlo de otro modo aturde.
        if !hurt {
            let ch = Self.crabSize * 0.7
            for i in platforms.indices where !platforms[i].broken {
                guard let off = platforms[i].crab else { continue }
                let p = platforms[i], cx = p.x + off
                guard abs(px - cx) < Self.crabSize * 0.5 + Self.playerSize * 0.24 else { continue }
                if vy < 0, py >= p.y + ch * 0.5, newY <= p.y + ch {
                    platforms[i].crab = nil
                    Spark.burst(&sparks, at: CGPoint(x: cx, y: -(p.y + ch * 0.5)), color: Color(hex: 0xE8553F), count: 8)
                    newY = p.y + ch; vy = Self.jumpSpeed * 1.08; squash = 1; lastLandedY = p.y
                    bonus += 5; event = .stomp
                } else if newY < p.y + ch, newY + Self.playerSize * 0.8 > p.y {
                    hurt = true; vy = min(vy, 0) - 40; event = .hit
                }
                break
            }
        }
        if vy < 0, !hurt, event != .stomp {
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
        guard let goal = next ?? stay else { return px }
        // Con cangrejo: mientras sube se aparta (no atravesarlo desde abajo); al caer, va a por él.
        if let off = goal.crab, goal.y > lastLandedY + 4 {
            let cx = goal.x + off
            return vy > 0 && py < goal.y + 14 ? cx + (cx < size.width / 2 ? 30 : -30) : cx
        }
        return goal.x
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
                    if phase == .playing {
                        // Igual que en `WatchArcadeStage`: jugando, el marcador va en el lienzo (bajo la
                        // hora) y el lienzo sube a ocupar la franja del título.
                        ctx.draw(Text("\(world.score)").font(.system(size: 14, weight: .heavy, design: .rounded))
                            .foregroundColor(.white.opacity(0.9)), at: CGPoint(x: size.width - 8, y: ArcadeHUD.y), anchor: .trailing)
                    }
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
        .padding(.top, phase == .playing ? -ArcadeHUD.titleBand : 0)
        .ignoresSafeArea(edges: .bottom)
        .navigationTitle(phase == .playing ? "" : (phase == .ready ? WatchJump.title : "\(score)"))
        .focusable()
        .focused($crownFocus)
        .digitalCrownRotation(ArcadeHUD.crown($crown), from: 0, through: ArcadeHUD.crownSpan, sensitivity: .low, isContinuous: true, isHapticFeedbackEnabled: true)
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
        case .spring, .stomp: WHaptics.tick()
        case .hit: WHaptics.warning()
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

        // Fondo del mar: claridad arriba, rayos de luz y columnas de algas lejanas con paralaje.
        ctx.fill(Path(CGRect(x: 0, y: -40, width: size.width, height: size.height + 80)),
                 with: .linearGradient(Gradient(colors: [.clear, Color(hex: 0x061E2B).opacity(0.75)]),
                                       startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))
        for k in 0..<3 {
            let x0 = size.width * (0.3 + CGFloat(k) * 0.3) + sin(w.time * 0.4 + CGFloat(k)) * 6
            var ray = Path()
            ray.move(to: CGPoint(x: x0, y: -40)); ray.addLine(to: CGPoint(x: x0 + 18, y: -40))
            ray.addLine(to: CGPoint(x: x0 - 30, y: size.height)); ray.addLine(to: CGPoint(x: x0 - 60, y: size.height)); ray.closeSubpath()
            ctx.fill(ray, with: .linearGradient(Gradient(colors: [.white.opacity(0.07), .white.opacity(0)]),
                                                startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))
        }
        for k in 0..<5 {
            let span = size.height + 120
            let x = CGFloat((k * 59 + 17) % 100) / 100 * size.width
            let top = (CGFloat((k * 83 + 41) % 100) / 100 * span + w.camY * 0.22).truncatingRemainder(dividingBy: span) - 60
            let sway = sin(w.time * 1.1 + CGFloat(k) * 1.9) * 4
            var kelp = Path()
            kelp.move(to: CGPoint(x: x - 3, y: top + 64))
            kelp.addQuadCurve(to: CGPoint(x: x + sway, y: top), control: CGPoint(x: x - 8 - sway * 0.4, y: top + 32))
            kelp.addQuadCurve(to: CGPoint(x: x + 3, y: top + 64), control: CGPoint(x: x + 8 + sway * 0.6, y: top + 32))
            ctx.fill(kelp, with: .color(Color(hex: 0x1C6A5A).opacity(0.35)))
        }
        // Burbujas con paralaje (posiciones fijas por índice).
        for i in 0..<18 {
            let x = CGFloat((i * 73 + 11) % 100) / 100 * size.width + sin(w.time * 1.5 + CGFloat(i)) * 2
            let base = CGFloat((i * 131 + 37) % 100) / 100 * size.height
            let depth: CGFloat = i % 3 == 0 ? 0.30 : 0.14
            let y = (base + w.camY * depth).truncatingRemainder(dividingBy: size.height)
            let r: CGFloat = i % 3 == 0 ? 2.4 : 1.4
            ctx.stroke(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                       with: .color(Color(hex: 0xBFE6FF).opacity(i % 3 == 0 ? 0.45 : 0.28)), lineWidth: 0.8)
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
                // Corriente de agua (antes una anémona, que no se entendía): un chorro que sube
                // desde el apoyo. Rayas que ascienden, puntas de flecha y una boca en el alga.
                let jet = Color(hex: 0x9FE3FF)
                let boost = 1 + p.springKick * 0.6
                ctx.fill(Path(roundedRect: CGRect(x: p.x - 7, y: top - 1.5, width: 14, height: 3), cornerRadius: 1.5), with: .color(jet))
                for k in 0..<3 {
                    let lx = p.x + CGFloat(k - 1) * 4.5
                    let phase = (w.time * 1.6 * boost + CGFloat(k) * 0.37).truncatingRemainder(dividingBy: 1)
                    let y0 = top - 3 - phase * 22, len: CGFloat = 7
                    var streak = Path()
                    streak.move(to: CGPoint(x: lx, y: y0))
                    streak.addLine(to: CGPoint(x: lx + sin(w.time * 5 + CGFloat(k)) * 0.8, y: y0 - len))
                    ctx.stroke(streak, with: .color(jet.opacity(0.9 * (1 - phase))), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
                }
                for k in 0..<2 {
                    let phase = (w.time * 1.1 * boost + CGFloat(k) * 0.5).truncatingRemainder(dividingBy: 1)
                    let ay = top - 8 - phase * 20
                    var arrow = Path()
                    arrow.move(to: CGPoint(x: p.x - 4, y: ay + 3)); arrow.addLine(to: CGPoint(x: p.x, y: ay - 1)); arrow.addLine(to: CGPoint(x: p.x + 4, y: ay + 3))
                    ctx.stroke(arrow, with: .color(.white.opacity(0.85 * (1 - phase))), style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                }
            }
        }

        for p in w.platforms where !p.broken {
            guard let off = p.crab else { continue }
            let top = sy(p.y)
            guard top > -20, top < size.height + 20 else { continue }
            Crab.draw(in: &ctx, base: CGPoint(x: p.x + off, y: top), size: JumpWorld.crabSize, phase: w.time * 3)
        }
        var fx = ctx
        fx.translateBy(x: 0, y: size.height + w.camY)
        Spark.draw(w.sparks, in: &fx)

        // El pulpo (y su copia al otro lado cuando asoma por un borde).
        let s = JumpWorld.playerSize
        let feetY = sy(w.py)
        for dx in [0, -size.width, size.width] {
            let x = w.px + dx
            guard x > -s, x < size.width + s else { continue }
            Octopus.draw(in: &ctx, feet: CGPoint(x: x, y: feetY), size: s, stretch: w.stretch,
                         pose: w.pose, squash: w.squash, time: w.time, hurt: w.hurt)
        }
    }
}

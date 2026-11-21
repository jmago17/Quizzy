//
//  WatchArcade.swift — Quizzy Watch
//  Base común de los juegos de acción del reloj que se manejan con la Corona (Marcianitos y
//  Escuadrón; Brinco es anterior y lleva su propio bucle en `WatchJumpView`).
//
//  Un juego = una clase `ArcadeWorld` (estado + física + dibujo, fuera de SwiftUI) dentro de
//  `WatchArcadeStage`, que pone el bucle (`TimelineView` + `Canvas`), la Corona (0…1 = posición
//  horizontal; también vale arrastrar el dedo), las pantallas de inicio/fin y el récord.
//
//  OJO (fallo real de Brinco, 2026-11-21): el cierre del `Canvas` TIENE que capturar la fecha del
//  fotograma. Si captura lo mismo que en el anterior, SwiftUI no repinta y el juego «va a tirones»
//  aunque la física corra a 60 pasos/s. Se comprueba con QW_FPS=1 (imprime pasos y dibujados/s).
//

import SwiftUI

enum ArcadeEvent { case none, bonus, hit, dead }

protocol ArcadeWorld: AnyObject {
    var score: Int { get }
    func reset(size: CGSize)
    /// El lienzo cambió de tamaño a mitad de partida (p. ej. al asentarse la barra): no reinicia.
    func resize(_ size: CGSize)
    /// `input` = posición pedida por el jugador, 0 (izquierda) … 1 (derecha).
    func step(dt: CGFloat, input: CGFloat) -> ArcadeEvent
    func draw(_ ctx: inout GraphicsContext, size: CGSize)
    /// Solo para capturas y medidas (QW_DEMO=1): a dónde iría un jugador, 0…1.
    func autopilot() -> CGFloat
}

struct ArcadeInfo {
    let id: String
    let title: String
    let hint: String
    let color: Color
    var bestKey: String { "watch.\(id).best" }
}

// MARK: - Chispas (explosiones)

struct Spark {
    var p: CGPoint
    var v: CGVector
    var life: CGFloat
    var color: Color

    static func burst(_ sparks: inout [Spark], at p: CGPoint, color: Color, count: Int = 9) {
        for _ in 0..<count {
            let a = CGFloat.random(in: 0..<(2 * .pi)), s = CGFloat.random(in: 30...95)
            sparks.append(Spark(p: p, v: CGVector(dx: cos(a) * s, dy: sin(a) * s), life: CGFloat.random(in: 0.25...0.55), color: color))
        }
        if sparks.count > 90 { sparks.removeFirst(sparks.count - 90) }
    }

    static func step(_ sparks: inout [Spark], dt: CGFloat) {
        for i in sparks.indices {
            sparks[i].p.x += sparks[i].v.dx * dt
            sparks[i].p.y += sparks[i].v.dy * dt
            sparks[i].life -= dt
        }
        sparks.removeAll { $0.life <= 0 }
    }

    static func draw(_ sparks: [Spark], in ctx: inout GraphicsContext) {
        for s in sparks {
            let r = 1 + s.life * 3
            ctx.fill(Path(ellipseIn: CGRect(x: s.p.x - r, y: s.p.y - r, width: r * 2, height: r * 2)),
                     with: .color(s.color.opacity(min(1, s.life * 3))))
        }
    }
}

/// Vidas: corazones pequeños arriba a la izquierda del lienzo.
func drawLives(_ lives: Int, in ctx: inout GraphicsContext) {
    for i in 0..<max(0, lives) {
        let x = 9 + CGFloat(i) * 11, y: CGFloat = 8
        var heart = Path()
        heart.move(to: CGPoint(x: x, y: y + 4))
        heart.addCurve(to: CGPoint(x: x, y: y - 2), control1: CGPoint(x: x - 7, y: y), control2: CGPoint(x: x - 3, y: y - 6))
        heart.addCurve(to: CGPoint(x: x, y: y + 4), control1: CGPoint(x: x + 3, y: y - 6), control2: CGPoint(x: x + 7, y: y))
        ctx.fill(heart, with: .color(Color(hex: 0xF0766B)))
    }
}

// MARK: - Medidor (DEBUG)

#if DEBUG
/// QW_FPS=1: arranca la partida sola (sin piloto) e imprime cada segundo pasos de física y dibujados.
/// QW_DEMO=1: además juega el piloto automático (para capturas).
final class ArcadeProbe {
    static let shared = ArcadeProbe()
    let fps = ProcessInfo.processInfo.environment["QW_FPS"] == "1"
    let demo = ProcessInfo.processInfo.environment["QW_DEMO"] == "1"
    var ticks = 0, draws = 0, mark: Date?
    func tick(_ now: Date) {
        guard fps else { return }
        ticks += 1
        if mark == nil { mark = now }
        if now.timeIntervalSince(mark!) >= 1 { print("QWFPS ticks=\(ticks) draws=\(draws)"); ticks = 0; draws = 0; mark = now }
    }
}
#endif

private final class FrameClock { var last: Date? }

// MARK: - Escenario

struct WatchArcadeStage<World: ArcadeWorld>: View {
    private enum Phase { case ready, playing, over }

    let info: ArcadeInfo
    @State private var world: World
    @State private var clock = FrameClock()
    @State private var phase = Phase.ready
    @State private var crown = 0.5
    @State private var dragStart: Double?
    @State private var score = 0
    @State private var record = false
    @State private var redraw = 0
    @AppStorage private var best: Int
    @Environment(\.scenePhase) private var scene
    @FocusState private var crownFocus: Bool

    init(info: ArcadeInfo, world: @autoclosure @escaping () -> World) {
        self.info = info
        _world = State(wrappedValue: world())
        _best = AppStorage(wrappedValue: 0, info.bestKey, store: PuzzleProgress.shared.defaults)
    }

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation(paused: phase != .playing || scene != .active)) { timeline in
                let frame = timeline.date   // ver la nota de cabecera: sin esto no se repinta
                Canvas { ctx, size in
                    _ = (redraw, frame)
                    #if DEBUG
                    ArcadeProbe.shared.draws += 1
                    #endif
                    world.draw(&ctx, size: size)
                }
                .onChange(of: timeline.date) { _, now in tick(now) }
            }
            .overlay { overlay }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 4)
                .onChanged { v in
                    let start = dragStart ?? crown
                    dragStart = start
                    crown = min(1, max(0, start + Double(v.translation.width / max(1, geo.size.width))))
                }
                .onEnded { _ in dragStart = nil })
            .onTapGesture { if phase == .ready { begin() } }
            .onAppear {
                geoSize = geo.size
                world.reset(size: geo.size); redraw += 1; crownFocus = true
                #if DEBUG
                if ArcadeProbe.shared.fps || ArcadeProbe.shared.demo { begin() }
                #endif
            }
            .onChange(of: geo.size) { _, new in
                geoSize = new
                // Jugando no se reinicia, pero el mundo tiene que conocer el tamaño real: si no, la
                // nave se coloca respecto a un alto antiguo y queda fuera de pantalla (visto en captura).
                if phase == .playing { world.resize(new) } else { world.reset(size: new); redraw += 1 }
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .navigationTitle(phase == .ready ? info.title : "\(score)")
        .focusable()
        .focused($crownFocus)
        .digitalCrownRotation($crown, from: 0, through: 1, sensitivity: .medium, isContinuous: false, isHapticFeedbackEnabled: false)
        .onChange(of: scene) { _, new in if new != .active { clock.last = nil } }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(info.title)
        .accessibilityValue(AppLanguage.text("\(score) puntos", "\(score) points"))
    }

    @ViewBuilder private var overlay: some View {
        switch phase {
        case .playing:
            EmptyView()
        case .ready:
            VStack(spacing: 2) {
                Label(info.hint, systemImage: "digitalcrown.horizontal.arrow.clockwise")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                Text(AppLanguage.text("Toca para empezar", "Tap to start"))
                    .font(.caption2).foregroundStyle(WTheme.inkSecondary)
            }
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(WTheme.surface.opacity(0.9), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .allowsHitTesting(false)
        case .over:
            VStack(spacing: 4) {
                Text("\(score)").font(.system(size: 32, weight: .heavy, design: .rounded)).foregroundStyle(info.color)
                Text(record ? AppLanguage.text("¡Nuevo récord!", "New best!") : AppLanguage.text("Récord: \(best)", "Best: \(best)"))
                    .font(.footnote).foregroundStyle(record ? WTheme.success : WTheme.inkSecondary)
                Button(AppLanguage.text("Otra vez", "Again")) { world.reset(size: geoSize); begin() }
                    .tint(info.color)
            }
            .padding(10)
            .background(WTheme.surface.opacity(0.94), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .padding(.horizontal, 14)
        }
    }

    @State private var geoSize: CGSize = .zero

    private func begin() {
        score = 0; record = false
        clock.last = nil
        phase = .playing
        crownFocus = true
    }

    private func tick(_ now: Date) {
        guard phase == .playing else { return }
        #if DEBUG
        ArcadeProbe.shared.tick(now)
        #endif
        defer { clock.last = now }
        guard let last = clock.last else { return }
        let dt = CGFloat(min(1.0 / 20, max(0, now.timeIntervalSince(last))))
        #if DEBUG
        if ArcadeProbe.shared.demo {
            let want = Double(world.autopilot())
            crown = min(1, max(0, crown + max(-1.8 * Double(dt), min(1.8 * Double(dt), want - crown))))
        }
        #endif
        switch world.step(dt: dt, input: CGFloat(crown)) {
        case .none: break
        case .bonus: WHaptics.tick()
        case .hit: WHaptics.warning()
        case .dead:
            phase = .over
            if score < world.score { score = world.score }
            record = score > best
            if record { best = score; WHaptics.success() } else { WHaptics.error() }
        }
        if world.score != score { score = world.score }
    }
}

//
//  SquadronGame.swift — Quizzy (iPhone / iPad)
//  Escuadrón en el iPhone. El juego (enemigos, jefes, zonas, cañones, premios) es `SkyWorld`, el
//  MISMO motor del reloj (`QuizzyWatch/WatchPlanesView.swift`, compartido por `project.yml`). Aquí
//  solo va lo propio del iPhone:
//   · Campo lógico: el mundo está pensado en puntos de reloj (~190 de ancho). Se juega en un campo
//     de 200 pt lógicos de ancho (más alto que el del reloj) y el lienzo se escala. En apaisado y
//     en iPad el campo se limita a 320 de ancho y queda centrado entre dos bandas.
//   · Control: arrastre RELATIVO (el avión se mueve lo que se mueve el dedo, esté donde esté: así el
//     dedo no lo tapa) en las dos direcciones. Un toque corto = tonel.
//   · Marcador, vidas y barra de triple disparo pintados aquí, bajo la zona segura.
//  OJO: el cierre del `Canvas` captura la fecha del fotograma (ver nota de `WatchArcade.swift`).
//

import SwiftUI

extension Color {
    /// El motor compartido con el reloj usa colores `0xRRGGBB`.
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }
}

enum Squadron {
    static let bestKey = "arcade.planes.best"
    static var title: String { WatchPlanes.info.title }
    static var color: Color { WatchPlanes.info.color }
    static var blurb: String { AppLanguage.text("Arrastra para volar, toca para hacer un tonel", "Drag to fly, tap to barrel roll") }
}

/// Campo de juego dentro de la pantalla: escala y tamaño lógico.
private struct SquadronField: Equatable {
    var full: CGSize = .zero
    var scale: CGFloat = 1
    var logical: CGSize = .zero
    var originX: CGFloat = 0
    var safe = EdgeInsets()

    init() {}
    init(full: CGSize, safe: EdgeInsets) {
        self.full = full
        self.safe = safe
        guard full.width > 0, full.height > 0 else { return }
        scale = min(full.width / 200, full.height / 300)
        let w = min(320, full.width / scale)
        logical = CGSize(width: w, height: full.height / scale)
        originX = (full.width - w * scale) / 2
    }
    /// Fila del marcador, en puntos de pantalla.
    var hudY: CGFloat { safe.top + 24 }
}

/// Estado del dedo, fuera de SwiftUI: cambia en cada evento y no debe reconstruir la vista.
private final class SquadronControl {
    var x: CGFloat = 0.5, y: CGFloat = 1          // posición pedida, 0…1 en cada eje
    /// Dedo en pantalla (puntos de la vista) y si ya se ha movido: un toque corto no arrastra el avión.
    var finger: CGPoint?
    var moved = false
    var touchBegan: Date?
    var last: Date?
}

struct SquadronGame: View {
    private enum Phase { case ready, playing, paused, over }

    @State private var world = SkyWorld()
    @State private var control = SquadronControl()
    @State private var field = SquadronField()
    @State private var phase = Phase.ready
    @State private var score = 0
    @State private var record = false
    @State private var redraw = 0
    @AppStorage(Squadron.bestKey, store: PuzzleProgress.shared.defaults) private var best = 0
    @Environment(\.scenePhase) private var scene
    @Environment(\.dismiss) private var dismiss

    #if DEBUG
    /// NR_DEMO=1: arranca sola y vuela el piloto automático (capturas y medida de dibujados/s).
    private let demo = ProcessInfo.processInfo.environment["NR_DEMO"] == "1"
    #endif

    var body: some View {
        GeometryReader { geo in
            let layout = SquadronField(
                full: CGSize(width: geo.size.width + geo.safeAreaInsets.leading + geo.safeAreaInsets.trailing,
                             height: geo.size.height + geo.safeAreaInsets.top + geo.safeAreaInsets.bottom),
                safe: geo.safeAreaInsets)
            TimelineView(.animation(paused: phase != .playing || scene != .active)) { timeline in
                let frame = timeline.date
                Canvas { ctx, size in
                    _ = (redraw, frame)
                    #if DEBUG
                    ArcadeProbe.shared.draws += 1
                    #endif
                    draw(&ctx, size: size)
                }
                .onChange(of: timeline.date) { _, now in tick(now) }
            }
            .contentShape(Rectangle())
            .gesture(drag)
            .overlay(alignment: .topLeading) { buttons }
            .overlay { panel }
            .ignoresSafeArea()
            .onAppear { apply(layout, restart: true) }
            .onChange(of: layout) { _, new in apply(new, restart: phase == .ready || phase == .over) }
        }
        .background(WatchPlanes.band.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .defersSystemGestures(on: .all)
        .onChange(of: scene) { _, new in
            if new != .active {
                control.last = nil
                if phase == .playing { phase = .paused }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Squadron.title)
        .accessibilityValue(AppLanguage.text("\(score) puntos", "\(score) points"))
    }

    // MARK: Campo

    private func apply(_ layout: SquadronField, restart: Bool) {
        field = layout
        guard layout.logical.width > 0 else { return }
        world.free2D = true
        world.swingRolls = false
        world.drawsHUD = false
        world.spawnScale = 0.7
        world.topInset = (layout.safe.top + 44) / layout.scale
        world.bottomInset = max(26, (layout.safe.bottom + 34) / layout.scale)
        if restart {
            world.reset(size: layout.logical)
            if phase == .over { phase = .ready }
        } else {
            world.resize(layout.logical)
        }
        redraw += 1
        #if DEBUG
        if demo || ArcadeProbe.shared.fps, phase == .ready { begin() }
        #endif
    }

    // MARK: Dibujo

    private func draw(_ ctx: inout GraphicsContext, size: CGSize) {
        guard field.logical.width > 0 else { return }
        var g = ctx
        g.clip(to: Path(CGRect(x: field.originX, y: 0, width: field.logical.width * field.scale, height: size.height)))
        g.translateBy(x: field.originX, y: 0)
        g.scaleBy(x: field.scale, y: field.scale)
        world.showsBanners = phase == .playing
        world.draw(&g, size: field.logical)

        guard phase == .playing || phase == .paused else { return }
        // Marcador (junto al botón de salir), vidas (junto al de pausa) y barra de la «P».
        let y = field.hudY, left = field.safe.leading + 68, right = size.width - field.safe.trailing - 68
        ctx.draw(Text("\(world.score)").font(.system(size: 24, weight: .heavy, design: .rounded)).foregroundColor(.white),
                 at: CGPoint(x: left, y: y), anchor: .leading)
        if world.power > 0 {
            ctx.fill(Path(roundedRect: CGRect(x: left, y: y + 17, width: 70, height: 5), cornerRadius: 2.5), with: .color(.black.opacity(0.3)))
            ctx.fill(Path(roundedRect: CGRect(x: left, y: y + 17, width: 70 * world.power / 10, height: 5), cornerRadius: 2.5), with: .color(Squadron.color))
        }
        for i in 0..<max(0, world.lives) {
            let x = right - CGFloat(i) * 24 - 10, s: CGFloat = 2.1
            var heart = Path()
            heart.move(to: CGPoint(x: x, y: y + 4 * s))
            heart.addCurve(to: CGPoint(x: x, y: y - 2 * s), control1: CGPoint(x: x - 7 * s, y: y), control2: CGPoint(x: x - 3 * s, y: y - 6 * s))
            heart.addCurve(to: CGPoint(x: x, y: y + 4 * s), control1: CGPoint(x: x + 3 * s, y: y - 6 * s), control2: CGPoint(x: x + 7 * s, y: y))
            ctx.fill(heart, with: .color(Color(hex: 0xF0766B)))
        }
    }

    // MARK: Botones y paneles

    @ViewBuilder private var buttons: some View {
        HStack {
            glassButton("chevron.left", label: AppLanguage.text("Salir", "Exit")) { dismiss() }
            Spacer()
            if phase == .playing {
                glassButton("pause.fill", label: AppLanguage.text("Pausa", "Pause")) { phase = .paused }
            }
        }
        .padding(.leading, field.safe.leading + 14)
        .padding(.trailing, field.safe.trailing + 14)
        .padding(.top, field.hudY - 20)
    }

    private func glassButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .glassEffect(.clear.interactive(), in: .circle)
                .frame(width: 48, height: 48)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    @ViewBuilder private var panel: some View {
        switch phase {
        case .playing:
            EmptyView()
        case .ready:
            VStack(spacing: PZSpace.sm) {
                Text(Squadron.title).font(.system(size: 34, weight: .black, design: .rounded)).foregroundStyle(Squadron.color)
                Label(AppLanguage.text("Arrastra para volar", "Drag to fly"), systemImage: "hand.draw.fill")
                Label(AppLanguage.text("Toca para hacer un tonel", "Tap to barrel roll"), systemImage: "arrow.triangle.2.circlepath")
                Text(AppLanguage.text("Toca para empezar", "Tap to start"))
                    .font(PZFont.caption).foregroundStyle(PZColor.inkSecondary).padding(.top, PZSpace.xs)
                if best > 0 {
                    Text(AppLanguage.text("Récord: \(best)", "Best: \(best)")).font(PZFont.caption).foregroundStyle(PZColor.inkSecondary)
                }
            }
            .font(.system(size: 16, weight: .semibold, design: .rounded))
            .foregroundStyle(PZColor.ink)
            .padding(PZSpace.xl)
            .background(PZColor.surface.opacity(0.92), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .padding(PZSpace.xl)
            .allowsHitTesting(false)
        case .paused:
            card {
                Text(AppLanguage.text("Pausa", "Paused")).font(.system(size: 28, weight: .heavy, design: .rounded)).foregroundStyle(PZColor.ink)
                Button(AppLanguage.text("Seguir", "Resume")) { control.last = nil; phase = .playing }
                    .buttonStyle(.borderedProminent).tint(Squadron.color).foregroundStyle(.black)
                Button(AppLanguage.text("Salir", "Exit")) { dismiss() }.tint(PZColor.inkSecondary)
            }
        case .over:
            card {
                Text("\(score)").font(.system(size: 56, weight: .heavy, design: .rounded)).foregroundStyle(Squadron.color)
                Text(record ? AppLanguage.text("¡Nuevo récord!", "New best!") : AppLanguage.text("Récord: \(best)", "Best: \(best)"))
                    .font(PZFont.body).foregroundStyle(record ? PZColor.success : PZColor.inkSecondary)
                Button(AppLanguage.text("Otra vez", "Again")) { world.reset(size: field.logical); begin() }
                    .buttonStyle(.borderedProminent).tint(Squadron.color).foregroundStyle(.black)
                Button(AppLanguage.text("Salir", "Exit")) { dismiss() }.tint(PZColor.inkSecondary)
            }
        }
    }

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(spacing: PZSpace.md, content: content)
            .font(.system(size: 17, weight: .bold, design: .rounded))
            .padding(PZSpace.xl)
            .frame(minWidth: 220)
            .background(PZColor.surface.opacity(0.95), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    // MARK: Dedo

    private var drag: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { v in
                guard phase == .playing, field.logical.width > 0 else { return }
                if control.touchBegan == nil { control.touchBegan = v.time; control.moved = false }
                if hypot(v.translation.width, v.translation.height) >= 10 { control.moved = true }
                control.finger = v.location
            }
            .onEnded { v in
                let began = control.touchBegan
                control.finger = nil; control.moved = false; control.touchBegan = nil
                switch phase {
                case .ready: begin()
                case .playing:
                    // Toque corto y sin moverse = tonel.
                    if hypot(v.translation.width, v.translation.height) < 10, let began, v.time.timeIntervalSince(began) < 0.3 {
                        world.requestRoll()
                    }
                case .paused, .over: break
                }
            }
    }

    /// Distancia, en puntos de pantalla, a la que el avión vuela por delante del dedo para que no lo tape.
    private static let lead: CGFloat = 76

    /// Lleva el avión hacia el punto que queda por delante del dedo, rápido pero sin teletransportarlo.
    private func follow(_ now: Date, dt: CGFloat) {
        guard let finger = control.finger, let began = control.touchBegan, field.logical.width > 0,
              control.moved || now.timeIntervalSince(began) > 0.18 else { return }
        let hi = field.logical.height - world.bottomInset
        let lo = min(hi, max(world.topInset + 110, field.logical.height * 0.42))
        let spanX = max(1, field.logical.width - 34), spanY = max(1, hi - lo)
        let wantX = min(1, max(0, ((finger.x - field.originX) / field.scale - 17) / spanX))
        let wantY = min(1, max(0, ((finger.y - Self.lead) / field.scale - lo) / spanY))
        let reach = 2000 * dt / field.scale          // puntos lógicos que puede recorrer en este fotograma
        control.x += max(-reach / spanX, min(reach / spanX, wantX - control.x))
        control.y += max(-reach / spanY, min(reach / spanY, wantY - control.y))
    }

    // MARK: Bucle

    private func begin() {
        score = 0; record = false
        control.x = 0.5; control.y = 1; control.last = nil
        control.finger = nil; control.moved = false; control.touchBegan = nil
        phase = .playing
    }

    private func tick(_ now: Date) {
        guard phase == .playing else { return }
        #if DEBUG
        ArcadeProbe.shared.tick(now)
        #endif
        defer { control.last = now }
        guard let last = control.last else { return }
        let dt = CGFloat(min(1.0 / 20, max(0, now.timeIntervalSince(last))))
        #if DEBUG
        if demo {
            let want = world.autopilot()
            control.x = min(1, max(0, control.x + max(-1.8 * dt, min(1.8 * dt, want - control.x))))
        }
        #endif
        follow(now, dt: dt)
        world.inputY = control.y
        switch world.step(dt: dt, input: control.x) {
        case .none, .detent, .notch, .success: break
        case .bonus: PZHaptics.tick()
        case .hit: PZHaptics.warning()
        case .dead:
            phase = .over
            score = world.score
            record = score > best
            if record { best = score; PZHaptics.success() } else { PZHaptics.error() }
        }
        if world.score != score { score = world.score }
    }
}

#if os(iOS)
//
//  PZResultSheet.swift — News Raider
//  Shared end-of-game sheet. Replaces the generic .alert in all five games.
//

import SwiftUI
import MetalKit

extension Notification.Name {
    static let pzOpenNextGame = Notification.Name("newsraider.puzzles.openNextGame")
    static let pzNewSameGame = Notification.Name("newsraider.puzzles.newSameGame")
}

/// Acción de navegación pedida desde una hoja de resultado. Se lanza cuando la hoja
/// YA se ha cerrado (onDisappear), no tras un retraso fijo: cambiar la ruta del hub
/// mientras la hoja aún se está descartando hace que la navegación se pierda o
/// deje una pantalla vacía, y el tiempo de cierre varía según el dispositivo.
@MainActor enum PZPendingNav {
    private static var pending: (name: Notification.Name, raw: String)?
    static func request(_ name: Notification.Name, _ raw: String) {
        pending = (name, raw)
        // Red de seguridad: si onDisappear no llegara, la acción se ejecuta igualmente.
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            flush()
        }
    }
    static func flush() {
        guard let p = pending else { return }
        pending = nil
        NotificationCenter.default.post(name: p.name, object: p.raw)
    }
}

struct PZResult: Identifiable {
    let id = UUID()
    let kind: PuzzleKind
    let didWin: Bool
    let headline: String
    let detail: String?
    let metrics: [(label: String, value: String)]
    let shareText: String
}

struct PZResultSheet: View {
    @AppStorage(AppLanguage.storageKey) private var languageSelection = "system"
    let result: PZResult
    var onNext: ((PuzzleKind) -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false
    /// Dispara la onda expansiva (shader `pzShockwave`) una vez al aparecer, si se ha ganado.
    @State private var wave = 0

    private var next: PuzzleKind? {
        PuzzleProgress.shared.nextPending(after: result.kind)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: PZSpace.lg) {
                badge
                VStack(spacing: PZSpace.sm) {
                    Text(result.headline)
                        .font(PZFont.display)
                        .foregroundStyle(PZColor.ink)
                        .multilineTextAlignment(.center)
                    if let d = result.detail {
                        Text(d)
                            .font(PZFont.body)
                            .foregroundStyle(PZColor.inkSecondary)
                            .multilineTextAlignment(.center)
                    }
                }
                if !result.metrics.isEmpty { metricsRow }
                actions
            }
            .padding(.horizontal, PZSpace.xl)
            .padding(.top, PZSpace.lg)
            .padding(.bottom, PZSpace.xxl)
            .keyframeAnimator(initialValue: 0.0, trigger: wave) { content, t in
                let badgeY = PZSpace.lg + 44
                content.visualEffect { c, proxy in
                    c.layerEffect(ShaderLibrary.pzShockwave(.float2(proxy.size.width / 2, badgeY), .float(t),
                                                            .float(650), .float(12)),
                                  maxSampleOffset: CGSize(width: 16, height: 16),
                                  isEnabled: t > 0.001 && t < 1.15)
                }
            } keyframes: { _ in
                MoveKeyframe(0.0)
                LinearKeyframe(1.2, duration: 1.2)
            }
        }
        .onDisappear { PZPendingNav.flush() }
        .presentationDetents([.medium, .large])
        .presentationCornerRadius(PZRadius.sheet)
        .presentationDragIndicator(.visible)
        .presentationBackground { LiquidCanvasBackground() }
        .onAppear {
            appeared = true
            guard result.didWin else { return }
            PZHaptics.win()
            guard !reduceMotion else { return }
            PZFireworks.launch(tint: UIColor(PZ.color(result.kind)))
            wave += 1
        }
    }

    @ViewBuilder private var badge: some View {
        Group {
            if result.didWin {
                // Medalla con volumen y brillo metálico (shader `pzShine`) que barre cada 2,4 s.
                TimelineView(.animation(paused: reduceMotion)) { timeline in
                    let t = timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1000)
                    Image(systemName: result.kind.symbol)
                        .font(.system(size: 38, weight: .bold))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.3), radius: 0, y: 1)
                        .frame(width: 88, height: 88)
                        .pzVolume(PZ.color(result.kind), glow: true, circle: true)
                        .compositingGroup()
                        .colorEffect(ShaderLibrary.pzShine(.float2(88, 88), .float(t), .float(2.4)),
                                     isEnabled: !reduceMotion)
                }
            } else {
                PZWashBadge(color: PZColor.inkSecondary, size: 88) {
                    Image(systemName: "clock.badge.xmark")
                        .font(.system(size: 38, weight: .bold))
                }
            }
        }
        .scaleEffect(appeared || reduceMotion ? 1 : 0.6)
        .animation(reduceMotion ? nil : .bouncy(duration: 0.55), value: appeared)
        .accessibilityHidden(true)
    }

    private var metricsRow: some View {
        HStack(spacing: 0) {
            ForEach(Array(result.metrics.enumerated()), id: \.offset) { i, m in
                if i > 0 {
                    Rectangle().fill(PZColor.hairline).frame(width: 1, height: 34)
                }
                VStack(spacing: PZSpace.xxs) {
                    Text(m.value)
                        .font(PZFont.metric)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text(m.label).pzLabelStyle()
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .combine)
            }
        }
        .padding(.vertical, PZSpace.md)
        .background(PZColor.fill, in: PZRadius.rect(PZRadius.card))
    }

    private var actions: some View {
        VStack(spacing: PZSpace.sm) {
            ShareLink(item: result.shareText) {
                Label(AppLanguage.text("Compartir resultado", "Share result"), systemImage: "square.and.arrow.up")
                    .pzPill(PZ.color(result.kind), wide: true)
            }
            .buttonStyle(.plain)

            Button {
                PZPendingNav.request(.pzNewSameGame, result.kind.rawValue)
                dismiss()
            } label: {
                Label(AppLanguage.text("Jugar otro \(result.kind.title)", "Play another \(result.kind.title)"), systemImage: "arrow.clockwise")
                    .pzPill(PZ.color(result.kind), wide: true)
            }
            .buttonStyle(.plain)

            if let next {
                Button {
                    if let onNext {
                        dismiss()
                        onNext(next)
                    } else {
                        // Result sheets live inside each game, while the hub owns
                        // the navigation destination. The hub is asked to replace the
                        // current game once this sheet has finished dismissing.
                        PZPendingNav.request(.pzOpenNextGame, next.rawValue)
                        dismiss()
                    }
                } label: {
                    Label(AppLanguage.text("Siguiente: \(next.title)", "Next: \(next.title)"), systemImage: "arrow.right")
                        .pzPill(PZColor.ink, wide: true)
                }
                .buttonStyle(.plain)
            }

        }
    }
}

// MARK: - Metal celebration (purpurina metálica + chispas)
//
// 2026-11-16: antes era confeti multicolor plano. Ahora los colores salen del color del juego (más blanco y
// oro), la mezcla es aditiva (las chispas brillan y se suman) y los "papelitos" son escamas metálicas que
// destellan al girar (brillo según el ángulo).
//
// Shown once, briefly, over the result sheet whenever a game is won. A tiny
// GPU particle system rather than a stack of animated SwiftUI views, so a
// few hundred pieces of confetti and firework sparks cost one draw call
// instead of hundreds of view updates.

private let pzCelebrationShaderSource = """
#include <metal_stdlib>
using namespace metal;

struct Particle {
    float4 color;
    float2 position;
    float rotation;
    float size;
    float kind;
};

struct Uniforms {
    float2 viewSize;
};

struct VertexOut {
    float4 position [[position]];
    float pointSize [[point_size]];
    float4 color;
    float rotation;
    float kind;
};

vertex VertexOut pz_particle_vertex(uint vertexID [[vertex_id]],
                                     constant Particle *particles [[buffer(0)]],
                                     constant Uniforms &uniforms [[buffer(1)]]) {
    Particle p = particles[vertexID];
    float2 ndc = (p.position / uniforms.viewSize) * 2.0 - 1.0;
    ndc.y = -ndc.y;

    VertexOut out;
    out.position = float4(ndc, 0.0, 1.0);
    out.pointSize = p.size;
    out.color = p.color;
    out.rotation = p.rotation;
    out.kind = p.kind;
    return out;
}

fragment float4 pz_particle_fragment(VertexOut in [[stage_in]],
                                      float2 pointCoord [[point_coord]]) {
    float2 c = pointCoord - float2(0.5);
    if (in.kind > 0.5) {
        // Chispa: núcleo casi blanco y halo del color.
        float d = length(c);
        float alpha = smoothstep(0.5, 0.0, d);
        float core = smoothstep(0.18, 0.0, d);
        return float4(mix(in.color.rgb, float3(1.0), core), in.color.a * alpha);
    } else {
        // Escama metálica: rombo fino que destella cuando su "cara" mira a la luz.
        float s = sin(in.rotation), co = cos(in.rotation);
        float2 r = float2(co * c.x - s * c.y, s * c.x + co * c.y);
        float edge = abs(r.x) * 1.6 + abs(r.y) * 0.9;
        float alpha = 1.0 - smoothstep(0.38, 0.48, edge);
        float glint = pow(abs(cos(in.rotation * 1.7)), 6.0);
        float3 rgb = in.color.rgb * (0.35 + 0.65 * abs(sin(in.rotation))) + glint * 0.9;
        return float4(rgb, in.color.a * alpha);
    }
}
"""

private struct PZGPUParticle {
    var color: SIMD4<Float>
    var position: SIMD2<Float>
    var rotation: Float
    var size: Float
    var kind: Float
}

private struct PZUniforms {
    var viewSize: SIMD2<Float>
}

private struct PZSimParticle {
    var position: SIMD2<Double>
    var velocity: SIMD2<Double>
    var color: SIMD4<Float>
    var size: Float
    var baseSize: Float
    var age: Double = 0
    var maxLife: Double
    /// Freno por fotograma a 60 fps (1 = sin rozamiento).
    var drag: Double
    /// Multiplicador de gravedad (el sauce cae más).
    var gravity: Double
    var role: Role
    /// Probabilidad por fotograma de soltar una brasa detrás (estela).
    var emberRate: Double = 0
    var crackle = false
    var alpha: Float = 1
    /// Para cohetes: altura (y en píxeles) a la que estallan, y el patrón.
    var burstY: Double = 0
    var pattern: PZShell = .peony

    enum Role { case rocket, spark, ember, flash }
}

enum PZShell: CaseIterable { case peony, ring, willow }

// MARK: - Fuegos artificiales a pantalla completa (2026-11-18)
//
// Antes: confeti dentro de la hoja de resultado (solo se veía en la carta). Ahora una UIWindow propia,
// transparente y sin toques (pasan a la app), por encima de todo — hoja incluida — con un MTKView:
// cohetes que suben con estela y estallan en esfera, anillo o sauce dorado, con el color del juego.

@MainActor enum PZFireworks {
    private static var window: UIWindow?
    private static var coordinator: PZCelebrationCoordinator?

    static func launch(tint: UIColor, duration: TimeInterval = 4.6) {
        guard window == nil,
              let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive }) else { return }
        let w = PZPassthroughWindow(windowScene: scene)
        w.frame = scene.coordinateSpace.bounds
        w.windowLevel = .alert + 1
        w.backgroundColor = .clear
        w.isUserInteractionEnabled = false

        let view = MTKView(frame: w.bounds)
        view.isOpaque = false
        view.backgroundColor = .clear
        (view.layer as? CAMetalLayer)?.isOpaque = false
        view.enableSetNeedsDisplay = false
        view.preferredFramesPerSecond = 60
        view.isUserInteractionEnabled = false
        view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        let c = PZCelebrationCoordinator(tint: tint)
        c.attach(to: view)
        view.delegate = c

        let vc = UIViewController()
        vc.view = view
        w.rootViewController = vc
        w.isHidden = false
        window = w
        coordinator = c

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(duration))
            UIView.animate(withDuration: 0.35, animations: { w.alpha = 0 }) { _ in
                (w.rootViewController?.view as? MTKView)?.isPaused = true
                w.isHidden = true
                window = nil
                coordinator = nil
            }
        }
    }
}

/// Ventana que nunca se queda con un toque: todo cae a la app de debajo.
private final class PZPassthroughWindow: UIWindow {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? { nil }
}

final class PZCelebrationCoordinator: NSObject, MTKViewDelegate {
    private var device: MTLDevice!
    private var queue: MTLCommandQueue!
    private var pipeline: MTLRenderPipelineState?
    private var particleBuffer: MTLBuffer!
    private var uniformBuffer: MTLBuffer!
    private let maxParticles = 2400

    private var particles: [PZSimParticle] = []
    private var viewSize = CGSize(width: 1170, height: 2532)
    /// Píxeles por punto: la simulación trabaja en píxeles del drawable.
    private var scale: Double = 3
    private var lastTime: CFTimeInterval = CACurrentMediaTime()
    private var elapsed: CFTimeInterval = 0
    private var launched = 0
    /// Cuándo sale cada cohete (s). Primero una salva de tres, luego goteo y un final doble.
    private let launchTimes: [CFTimeInterval] = [0.0, 0.12, 0.28, 0.75, 1.1, 1.45, 1.8, 2.15, 2.5, 2.55]
    private let shellColors: [SIMD4<Float>]
    private let gold = SIMD4<Float>(1.0, 0.78, 0.36, 1)
    private let white = SIMD4<Float>(1, 0.97, 0.92, 1)

    /// Paleta a partir del color del juego: el color, una versión clara, oro y blanco.
    init(tint: UIColor) {
        var r: CGFloat = 1, g: CGFloat = 1, b: CGFloat = 1, a: CGFloat = 1
        tint.resolvedColor(with: UITraitCollection(userInterfaceStyle: .dark)).getRed(&r, green: &g, blue: &b, alpha: &a)
        let base = SIMD3<Float>(Float(r), Float(g), Float(b))
        func c(_ v: SIMD3<Float>) -> SIMD4<Float> { SIMD4(min(v.x, 1), min(v.y, 1), min(v.z, 1), 1) }
        let light = base + (SIMD3<Float>(repeating: 1) - base) * 0.45
        // Complementario suave para que no todo sea del mismo tono.
        let accent = SIMD3<Float>(1, 1, 1) - base * 0.6
        shellColors = [c(base), c(light), c(base), c(accent), c(SIMD3(1.0, 0.82, 0.38))]
        super.init()
    }

    func attach(to view: MTKView) {
        guard let device = view.device ?? MTLCreateSystemDefaultDevice() else { return }
        self.device = device
        view.device = device
        queue = device.makeCommandQueue()
        view.clearColor = MTLClearColorMake(0, 0, 0, 0)
        buildPipeline(colorFormat: view.colorPixelFormat)
        particleBuffer = device.makeBuffer(length: MemoryLayout<PZGPUParticle>.stride * maxParticles,
                                            options: .storageModeShared)
        uniformBuffer = device.makeBuffer(length: MemoryLayout<PZUniforms>.stride,
                                           options: .storageModeShared)
        let s = view.contentScaleFactor > 0 ? view.contentScaleFactor : UIScreen.main.scale
        if view.bounds.width > 0 {
            viewSize = CGSize(width: view.bounds.width * s, height: view.bounds.height * s)
        }
    }

    private func buildPipeline(colorFormat: MTLPixelFormat) {
        guard let device else { return }
        do {
            let library = try device.makeLibrary(source: pzCelebrationShaderSource, options: nil)
            let desc = MTLRenderPipelineDescriptor()
            desc.vertexFunction = library.makeFunction(name: "pz_particle_vertex")
            desc.fragmentFunction = library.makeFunction(name: "pz_particle_fragment")
            desc.colorAttachments[0].pixelFormat = colorFormat
            desc.colorAttachments[0].isBlendingEnabled = true
            desc.colorAttachments[0].rgbBlendOperation = .add
            desc.colorAttachments[0].alphaBlendOperation = .add
            desc.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
            desc.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
            desc.colorAttachments[0].destinationRGBBlendFactor = .one   // aditiva: brillo
            desc.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
            pipeline = try device.makeRenderPipelineState(descriptor: desc)
        } catch {
            pipeline = nil
        }
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        viewSize = size
    }

    func draw(in view: MTKView) {
        guard let pipeline, let particleBuffer, let uniformBuffer,
              let drawable = view.currentDrawable,
              let rpd = view.currentRenderPassDescriptor else { return }

        scale = Double(view.contentScaleFactor)
        let now = CACurrentMediaTime()
        let dt = min(now - lastTime, 1.0 / 30.0)
        lastTime = now
        elapsed += dt

        update(dt: dt)

        var uniforms = PZUniforms(viewSize: SIMD2<Float>(Float(viewSize.width), Float(viewSize.height)))
        memcpy(uniformBuffer.contents(), &uniforms, MemoryLayout<PZUniforms>.stride)

        let count = min(particles.count, maxParticles)
        let ptr = particleBuffer.contents().bindMemory(to: PZGPUParticle.self, capacity: maxParticles)
        for i in 0..<count {
            let p = particles[i]
            ptr[i] = PZGPUParticle(
                color: SIMD4<Float>(p.color.x, p.color.y, p.color.z, p.color.w * p.alpha),
                position: SIMD2<Float>(Float(p.position.x), Float(p.position.y)),
                rotation: 0,
                size: p.size,
                kind: 1)
        }

        guard let commandBuffer = queue.makeCommandBuffer(),
              let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: rpd) else { return }
        encoder.setRenderPipelineState(pipeline)
        encoder.setVertexBuffer(particleBuffer, offset: 0, index: 0)
        encoder.setVertexBuffer(uniformBuffer, offset: 0, index: 1)
        if count > 0 {
            encoder.drawPrimitives(type: .point, vertexStart: 0, vertexCount: count)
        }
        encoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    // MARK: Simulación

    private func update(dt: CFTimeInterval) {
        while launched < launchTimes.count, elapsed >= launchTimes[launched] {
            launchRocket(index: launched)
            launched += 1
        }

        let g = 240.0 * scale
        var spawned: [PZSimParticle] = []
        for i in particles.indices {
            var p = particles[i]
            p.velocity.y += g * p.gravity * dt
            p.velocity *= pow(p.drag, dt * 60)
            p.position += p.velocity * dt
            p.age += dt
            let f = p.age / p.maxLife

            switch p.role {
            case .rocket:
                // Estela: brasas cortas que se quedan atrás.
                for _ in 0..<2 {
                    spawned.append(ember(at: p.position, color: gold, life: 0.35, size: 3.5))
                }
                // Estalla al llegar a su altura o cuando deja de subir.
                if p.position.y <= p.burstY || p.velocity.y > -30 * scale {
                    spawned.append(contentsOf: explode(at: p.position, pattern: p.pattern, color: p.color))
                    p.age = p.maxLife
                }
            case .spark:
                if p.emberRate > 0, Double.random(in: 0..<1) < p.emberRate {
                    spawned.append(ember(at: p.position, color: p.color, life: 0.45, size: Float(p.size) / Float(scale) * 0.45))
                }
                p.size = p.baseSize * Float(1 - 0.55 * f)
                var a: Float = f < 0.55 ? 1 : Float(max(0, 1 - (f - 0.55) / 0.45))
                if p.crackle, f > 0.5 { a *= Float.random(in: 0.15...1) }   // centelleo final
                p.alpha = a
            case .ember:
                p.size = p.baseSize * Float(1 - 0.7 * f)
                p.alpha = Float(max(0, 1 - f)) * 0.8
            case .flash:
                p.size = p.baseSize * Float(1 + f)
                p.alpha = Float(max(0, 1 - f))
            }
            particles[i] = p
        }

        particles.removeAll { $0.age >= $0.maxLife || $0.position.y > viewSize.height + 40 * scale }
        let room = maxParticles - particles.count
        if room > 0 { particles.append(contentsOf: spawned.prefix(room)) }
    }

    private func launchRocket(index: Int) {
        let w = viewSize.width, h = viewSize.height
        // Repartidos de lado a lado; el final doble sale de los dos extremos.
        let lanes: [Double] = [0.5, 0.2, 0.8, 0.35, 0.68, 0.15, 0.55, 0.85, 0.3, 0.72]
        let x = w * (lanes[index % lanes.count] + Double.random(in: -0.05...0.05))
        let burstY = h * Double.random(in: 0.14...0.42)
        let rise = h + 20 * scale - burstY
        let g = 240.0 * scale * 0.35
        // Velocidad para llegar a la altura de estallido en ~0,7 s (antes subían ~2 s: demasiada espera).
        let t = Double.random(in: 0.55...0.8)
        let vy = -(rise / t + 0.5 * g * t)
        let pattern: PZShell = index == 0 ? .peony : (index >= launchTimes.count - 2 ? .willow : PZShell.allCases.randomElement()!)
        particles.append(PZSimParticle(
            position: SIMD2(x, h + 20 * scale),
            velocity: SIMD2(Double.random(in: -30...30) * scale, vy),
            color: shellColors[index % shellColors.count],
            size: Float(6 * scale), baseSize: Float(6 * scale),
            maxLife: 3, drag: 1, gravity: 0.35, role: .rocket,
            burstY: burstY, pattern: pattern))
    }

    private func explode(at center: SIMD2<Double>, pattern: PZShell, color: SIMD4<Float>) -> [PZSimParticle] {
        var out: [PZSimParticle] = []
        // Destello del estallido.
        out.append(PZSimParticle(position: center, velocity: .zero, color: white,
                                 size: Float(70 * scale), baseSize: Float(70 * scale),
                                 maxLife: 0.18, drag: 1, gravity: 0, role: .flash))
        let crackle = Bool.random()
        switch pattern {
        case .peony:
            let n = 110
            for _ in 0..<n {
                let a = Double.random(in: 0..<(2 * .pi))
                let v = Double.random(in: 0.75...1.0) * 330 * scale
                let col = Double.random(in: 0..<1) < 0.15 ? white : color
                out.append(spark(center, a, v, col, life: Double.random(in: 1.1...1.6), drag: 0.955,
                                 gravity: 0.5, size: Double.random(in: 7...11), emberRate: 0.12, crackle: crackle))
            }
        case .ring:
            let n = 72
            let tilt = Double.random(in: 0.45...0.8)          // anillo visto en perspectiva
            let spin = Double.random(in: 0..<(.pi))
            for k in 0..<n {
                let a = Double(k) / Double(n) * 2 * .pi
                var d = SIMD2(cos(a), sin(a) * tilt)
                d = SIMD2(d.x * cos(spin) - d.y * sin(spin), d.x * sin(spin) + d.y * cos(spin))
                let v = 300 * scale
                out.append(spark(center, 0, v, color, dir: d, life: 1.3, drag: 0.955, gravity: 0.45,
                                 size: 9, emberRate: 0.08, crackle: false))
            }
            // Núcleo blanco pequeño en el centro del anillo.
            for _ in 0..<24 {
                let a = Double.random(in: 0..<(2 * .pi))
                out.append(spark(center, a, Double.random(in: 40...110) * scale, white, life: 0.9, drag: 0.94,
                                 gravity: 0.4, size: 6, emberRate: 0, crackle: true))
            }
        case .willow:
            // Sauce dorado: chispas lentas, largas, que caen como lluvia dejando rastro.
            for _ in 0..<90 {
                let a = Double.random(in: 0..<(2 * .pi))
                let v = Double.random(in: 0.6...1.0) * 260 * scale
                out.append(spark(center, a, v, gold, life: Double.random(in: 1.8...2.4), drag: 0.94,
                                 gravity: 1.0, size: Double.random(in: 6...9), emberRate: 0.35, crackle: true))
            }
        }
        return out
    }

    private func spark(_ c: SIMD2<Double>, _ angle: Double, _ speed: Double, _ color: SIMD4<Float>,
                       dir: SIMD2<Double>? = nil, life: Double, drag: Double, gravity: Double,
                       size: Double, emberRate: Double, crackle: Bool) -> PZSimParticle {
        let d = dir ?? SIMD2(cos(angle), sin(angle))
        let s = Float(size * scale)
        var p = PZSimParticle(position: c, velocity: d * speed, color: color, size: s, baseSize: s,
                              maxLife: life, drag: drag, gravity: gravity, role: .spark)
        p.emberRate = emberRate
        p.crackle = crackle
        return p
    }

    private func ember(at pos: SIMD2<Double>, color: SIMD4<Float>, life: Double, size: Float) -> PZSimParticle {
        let s = size * Float(scale)
        return PZSimParticle(position: pos,
                             velocity: SIMD2(Double.random(in: -12...12), Double.random(in: -6...18)) * scale,
                             color: color, size: s, baseSize: s,
                             maxLife: life * Double.random(in: 0.7...1.1), drag: 0.9, gravity: 0.25, role: .ember)
    }
}
#endif

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
    @State private var showCelebration = false
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
        .overlay {
            if showCelebration {
                PZCelebrationView(tint: UIColor(PZ.color(result.kind)))
                    .allowsHitTesting(false)
                    .ignoresSafeArea()
                    .transition(.opacity)
            }
        }
        .onAppear {
            appeared = true
            guard result.didWin else { return }
            PZHaptics.win()
            guard !reduceMotion else { return }
            showCelebration = true
            wave += 1
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(2.6))
                showCelebration = false
            }
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
    var rotation: Double
    var angularVelocity: Double
    var age: Double
    var maxLife: Double
    var kind: Float
    var phase: Double
    var alpha: Float = 1
}

/// Thin UIViewRepresentable wrapper around an `MTKView`; all simulation and
/// drawing lives in `PZCelebrationCoordinator`.
struct PZCelebrationView: UIViewRepresentable {
    var tint: UIColor = .white
    func makeCoordinator() -> PZCelebrationCoordinator { PZCelebrationCoordinator(tint: tint) }

    func makeUIView(context: Context) -> MTKView {
        let view = MTKView()
        view.isOpaque = false
        view.backgroundColor = .clear
        (view.layer as? CAMetalLayer)?.isOpaque = false
        view.enableSetNeedsDisplay = false
        view.isPaused = false
        view.preferredFramesPerSecond = 60
        context.coordinator.attach(to: view)
        view.delegate = context.coordinator
        return view
    }

    func updateUIView(_ uiView: MTKView, context: Context) {}
}

final class PZCelebrationCoordinator: NSObject, MTKViewDelegate {
    private var device: MTLDevice!
    private var queue: MTLCommandQueue!
    private var pipeline: MTLRenderPipelineState?
    private var particleBuffer: MTLBuffer!
    private var uniformBuffer: MTLBuffer!
    private let maxParticles = 480

    private var particles: [PZSimParticle] = []
    private var viewSize = CGSize(width: 390, height: 844)
    private var lastTime: CFTimeInterval = CACurrentMediaTime()
    private var elapsed: CFTimeInterval = 0
    private var nextConfettiSpawn: CFTimeInterval = 0
    private var burstsFired = 0
    private let burstTimes: [CFTimeInterval] = [0.0, 0.22, 0.42]
    private let confettiColors: [SIMD4<Float>]
    private let sparkColors: [SIMD4<Float>]

    /// Paleta a partir del color del juego: tonos del color, blanco y oro.
    init(tint: UIColor) {
        var r: CGFloat = 1, g: CGFloat = 1, b: CGFloat = 1, a: CGFloat = 1
        tint.resolvedColor(with: UITraitCollection(userInterfaceStyle: .dark)).getRed(&r, green: &g, blue: &b, alpha: &a)
        let base = SIMD3<Float>(Float(r), Float(g), Float(b))
        func c(_ v: SIMD3<Float>) -> SIMD4<Float> { SIMD4(min(v.x, 1), min(v.y, 1), min(v.z, 1), 1) }
        let light = base + (SIMD3<Float>(repeating: 1) - base) * 0.45
        let deep = base * 0.75
        let gold = SIMD3<Float>(1.0, 0.82, 0.38)
        confettiColors = [c(base), c(light), c(deep), c(gold), c(SIMD3(0.92, 0.94, 1.0))]
        sparkColors = [c(light), c(base), c(gold), c(SIMD3(1, 1, 1))]
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
                rotation: Float(p.rotation),
                size: p.size,
                kind: p.kind)
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

    private func update(dt: CFTimeInterval) {
        while burstsFired < burstTimes.count, elapsed >= burstTimes[burstsFired] {
            spawnBurst()
            burstsFired += 1
        }
        if elapsed < 1.3, particles.count < maxParticles {
            nextConfettiSpawn -= dt
            if nextConfettiSpawn <= 0 {
                spawnConfetti(count: 5)
                nextConfettiSpawn = 0.05
            }
        }

        let gravity = 620.0
        for i in particles.indices {
            particles[i].velocity.y += gravity * dt
            if particles[i].kind > 0.5 {
                particles[i].velocity *= pow(0.985, dt * 60)
            } else {
                particles[i].position.x += sin(elapsed * 3 + particles[i].phase) * 26 * dt
                particles[i].velocity *= pow(0.995, dt * 60)
            }
            particles[i].position += particles[i].velocity * dt
            particles[i].rotation += particles[i].angularVelocity * dt
            particles[i].age += dt
        }

        particles.removeAll { $0.age >= $0.maxLife || $0.position.y > viewSize.height + 60 }
        for i in particles.indices {
            let f = particles[i].age / particles[i].maxLife
            particles[i].alpha = f < 0.75 ? 1 : Float(max(0, 1 - (f - 0.75) / 0.25))
        }
    }

    private func spawnBurst() {
        let cx = Double.random(in: viewSize.width * 0.25...viewSize.width * 0.75)
        let cy = Double.random(in: viewSize.height * 0.18...viewSize.height * 0.42)
        for _ in 0..<56 {
            let angle = Double.random(in: 0..<(2 * .pi))
            let speed = Double.random(in: 220...520)
            particles.append(PZSimParticle(
                position: SIMD2(cx, cy),
                velocity: SIMD2(cos(angle) * speed, sin(angle) * speed),
                color: sparkColors.randomElement()!,
                size: Float.random(in: 6...11),
                rotation: 0,
                angularVelocity: 0,
                age: 0,
                maxLife: Double.random(in: 0.9...1.35),
                kind: 1,
                phase: 0))
        }
    }

    private func spawnConfetti(count: Int) {
        for _ in 0..<count {
            let x = Double.random(in: 0...viewSize.width)
            particles.append(PZSimParticle(
                position: SIMD2(x, -20),
                velocity: SIMD2(Double.random(in: -40...40), Double.random(in: 80...200)),
                color: confettiColors.randomElement()!,
                size: Float.random(in: 8...14),
                rotation: Double.random(in: 0..<(2 * .pi)),
                angularVelocity: Double.random(in: -6...6),
                age: 0,
                maxLife: Double.random(in: 2.0...2.8),
                kind: 0,
                phase: Double.random(in: 0..<(2 * .pi))))
        }
    }
}
#endif

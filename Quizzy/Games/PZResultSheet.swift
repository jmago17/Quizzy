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
        }
        .presentationDetents([.medium, .large])
        .presentationCornerRadius(PZRadius.sheet)
        .presentationDragIndicator(.visible)
        .presentationBackground { LiquidCanvasBackground() }
        .overlay {
            if showCelebration {
                PZCelebrationView()
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
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(2.6))
                showCelebration = false
            }
        }
    }

    private var badge: some View {
        PZWashBadge(color: result.didWin ? PZ.color(result.kind) : PZColor.inkSecondary,
                    size: 88) {
            Image(systemName: result.didWin ? result.kind.symbol : "clock.badge.xmark")
                .font(.system(size: 38, weight: .bold))
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
                dismiss()
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(250))
                    NotificationCenter.default.post(
                        name: .pzNewSameGame,
                        object: result.kind.rawValue
                    )
                }
            } label: {
                Label(AppLanguage.text("Jugar otro \(result.kind.title)", "Play another \(result.kind.title)"), systemImage: "arrow.clockwise")
                    .pzPill(PZ.color(result.kind), wide: true)
            }
            .buttonStyle(.plain)

            if let next {
                Button {
                    dismiss()
                    if let onNext {
                        onNext(next)
                    } else {
                        // Result sheets live inside each game, while the hub owns
                        // the navigation destination. Ask the hub to replace the
                        // current game after this sheet starts dismissing.
                        Task { @MainActor in
                            try? await Task.sleep(for: .milliseconds(250))
                            NotificationCenter.default.post(
                                name: .pzOpenNextGame,
                                object: next.rawValue
                            )
                        }
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

// MARK: - Metal celebration (confetti + fireworks)
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
        float d = length(c);
        float alpha = smoothstep(0.5, 0.05, d);
        return float4(in.color.rgb, in.color.a * alpha);
    } else {
        float s = sin(in.rotation), co = cos(in.rotation);
        float2 r = float2(co * c.x - s * c.y, s * c.x + co * c.y);
        float edge = max(abs(r.x), abs(r.y));
        float alpha = 1.0 - smoothstep(0.36, 0.46, edge);
        return float4(in.color.rgb, in.color.a * alpha);
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

private enum PZCelebrationPalette {
    static let confetti: [SIMD4<Float>] = [
        SIMD4(0.85, 0.20, 0.32, 1),
        SIMD4(0.98, 0.75, 0.18, 1),
        SIMD4(0.20, 0.55, 0.85, 1),
        SIMD4(0.32, 0.72, 0.48, 1),
        SIMD4(0.62, 0.38, 0.85, 1),
        SIMD4(0.98, 0.55, 0.20, 1),
    ]
    static let sparks: [SIMD4<Float>] = [
        SIMD4(1.0, 0.85, 0.35, 1),
        SIMD4(1.0, 0.55, 0.35, 1),
        SIMD4(0.55, 0.85, 1.0, 1),
        SIMD4(0.95, 0.35, 0.55, 1),
        SIMD4(0.75, 1.0, 0.55, 1),
    ]
}

/// Thin UIViewRepresentable wrapper around an `MTKView`; all simulation and
/// drawing lives in `PZCelebrationCoordinator`.
struct PZCelebrationView: UIViewRepresentable {
    func makeCoordinator() -> PZCelebrationCoordinator { PZCelebrationCoordinator() }

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
            desc.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
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
                color: PZCelebrationPalette.sparks.randomElement()!,
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
                color: PZCelebrationPalette.confetti.randomElement()!,
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

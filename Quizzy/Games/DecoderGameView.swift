#if os(iOS)
//
//  DecoderGameView.swift — Kaffa
//  Decoder (edición «radio de espía», 2026-11-27): un receptor de campaña dibujado
//  en SwiftUI. DISEÑO PROPIO: sustituye al aparato anterior, que estaba medido
//  sobre la foto de un producto real y no se podía publicar. Caja de acero gris
//  con tornillos, antena telescópica y dos lámparas de modo en la tapa (ámbar =
//  Diario/Práctica, azul = Infinito); panel de baquelita con 7 filas de 4
//  VÁLVULAS redondas y un medidor de señal de 4 barras por fila; dial de
//  frecuencias color crema con los colores en juego; contador ámbar, pulsador
//  de pista y un dial negro moleteado. Las reglas NO han cambiado.
//
//  Controls (2026-11-10, docs/decoder-knob-controls-20261110.md):
//   - The two LID LAMPS are the mode buttons: amber = Diario/Práctica, blue = Infinito.
//   - The KNOB does everything else. Turn = change the colour previewed IN the
//     selected key of the current row; short tap = place it; hold (~0.5 s,
//     without turning) = submit the row. In Infinito with no game in progress
//     it is the LEVEL selector (turn = level on the red counter, tap = start).
//   - There are no Submit / Clear / Next buttons and no mode picker.
//   - The black band is passive: it shows the colours in play, or the SOLUTION
//     after a loss.
//   - The lip under each played key is OFF by default (2026-11-10). The HINT
//     button lights the lips of the LAST submitted row only (green = right
//     slot, white = other slot, off = not in the code; DecoderGame.revealHint)
//     and the reveal is persisted. The 2x2 pilots are always visible.
//   - Infinito: the board keeps 7 rows; rows beyond the level's attempt budget
//     (DecoderInfinite.maxAttempts) are drawn switched off.
//
//  Rules, scoring, knob maths and persistence live in DecoderCore.swift (shared
//  with watchOS). This file only SURFACES them: it never decides legality.
//
//  Two modes share this one screen:
//   - Entry game (Diario when it is today's puzzle, otherwise Práctica): the
//     original game, ids/keys/stats untouched.
//   - Infinito: its own persistent ladder (DecoderInfiniteStore). It never
//     writes PuzzleProgress, daily results, streaks or timings.
//
//  HDR: lit key centres use Color.exposureAdjust (real linear-light boost) plus
//  allowedDynamicRange(.high). On displays without headroom the system shows
//  the plain SDR colour. The effect is static (no flashing) and can be turned
//  off from the toolbar menu.
//

import SwiftUI
import UIKit
import CoreHaptics
import Combine

// MARK: - Colour bridge

extension DecoderColor {
    /// Appearance-aware colour (kept for other callers).
    var swiftUI: Color {
        Color(uiColor: UIColor { trait in
            let hex = trait.userInterfaceStyle == .dark ? self.hex.dark : self.hex.light
            return UIColor(red: CGFloat((hex >> 16) & 0xFF) / 255,
                           green: CGFloat((hex >> 8) & 0xFF) / 255,
                           blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
        })
    }
    /// The device's LEDs sit on a black panel in both appearances, so they always
    /// use the bright hue (explicit sRGB, which is what exposureAdjust expects).
    var ledColor: Color {
        let h = hex.dark
        return Color(.sRGB, red: Double((h >> 16) & 0xFF) / 255, green: Double((h >> 8) & 0xFF) / 255,
                     blue: Double(h & 0xFF) / 255, opacity: 1)
    }
    var ink: Color { prefersDarkInk ? Color(red: 0.08, green: 0.08, blue: 0.10) : .white }
    var localizedName: String { name(spanish: AppLanguage.current == .spanish) }
}

func decoderName(_ index: Int?) -> String {
    guard let index, let color = DecoderColor(rawValue: index) else {
        return AppLanguage.text("vacía", "empty")
    }
    return "\(color.localizedName) \(color.number)"
}

private func feedbackSpeech(_ f: DecoderFeedback) -> String {
    AppLanguage.text("\(f.exact) en su casilla, \(f.misplaced) en otra casilla",
                     "\(f.exact) in the right slot, \(f.misplaced) in a different slot")
}

private func hintSpeech(_ hint: DecoderSlotHint) -> String {
    switch hint {
    case .exact:   return AppLanguage.text("en su casilla", "right slot")
    case .present: return AppLanguage.text("en otra casilla", "in another slot")
    case .absent:  return AppLanguage.text("no está en el código", "not in the code")
    }
}

// MARK: - Haptics (local to Decoder, foreground only)

/// Never touches `PZHaptics`. Switch: `decoder.haptics.enabled` (default on).
///
/// Patterns come from `DecoderHapticRecipe` (pure data, bounds asserted by the
/// Tests/Decoder harness) and are played with CoreHaptics: haptics-only engine
/// (`playsHapticsOnly`, no audio session), created lazily on first use, with
/// auto-shutdown plus an explicit shutdown shortly after the pattern ends.
/// Every new cue cancels the previous one, so nothing ever stacks. If CoreHaptics
/// is unsupported or fails, the same events are replayed with UIKit
/// `.heavy`/`.rigid` impacts (bounded, cancellable). On iPad/Simulator nothing
/// is felt either way; this class never simulates it nor asks for permissions.
@MainActor
final class DecoderHaptics {
    static let shared = DecoderHaptics()
    static let enabledKey = "decoder.haptics.enabled"

    private let heavy = UIImpactFeedbackGenerator(style: .heavy)
    private let rigid = UIImpactFeedbackGenerator(style: .rigid)
    private var throttle = DecoderHapticThrottle(minInterval: DecoderHapticRecipe.wheelMinInterval)
    private var engine: CHHapticEngine?
    private var engineToken = UUID()
    private var player: CHHapticPatternPlayer?
    private var shutdownTask: Task<Void, Never>?
    private var fallbackTask: Task<Void, Never>?
    private var coreFailures = 0

    var isEnabled: Bool { UserDefaults.standard.object(forKey: Self.enabledKey) as? Bool ?? true }
    /// False on iPad and Simulator: the toggle stays usable but nothing is felt.
    var hardwareSupported: Bool { CHHapticEngine.capabilitiesForHardware().supportsHaptics }
    private var canPlay: Bool { isEnabled && UIApplication.shared.applicationState == .active }

    /// Only warms the UIKit fallback; the CoreHaptics engine stays lazy.
    func prepare() {
        coreFailures = 0
        guard canPlay else { return }
        rigid.prepare()
    }

    /// Cuts everything now: running pattern, fallback sequence, engine.
    func stop() {
        shutdownTask?.cancel(); shutdownTask = nil
        fallbackTask?.cancel(); fallbackTask = nil
        throttle.reset()
        tearDownEngine()
    }

    // MARK: Cues

    /// One click per detent crossed, throttled so a fast spin cannot buzz.
    func detent() {
        guard canPlay, throttle.allow(at: ProcessInfo.processInfo.systemUptime) else { return }
        play(.detent)
    }
    func place() { play(.place) }
    func slot() { play(.slot) }
    func clear() { play(.clear) }
    /// Key press, then the aggregate result: hard pulse = exact, light = misplaced.
    func submit(_ feedback: DecoderFeedback) { play(.submit(exact: feedback.exact, misplaced: feedback.misplaced)) }
    /// A colour the rules forbid: double knock + buzz, unlike place or incomplete.
    func reject() { play(.reject) }
    func warning() { play(.warning) }
    func error() { play(.error) }
    func win() { play(.win) }
    func loss() { play(.loss) }

    // MARK: Playback

    private func play(_ cue: DecoderHapticCue) {
        guard canPlay else { return }
        let events = DecoderHapticRecipe.events(for: cue)
        guard !events.isEmpty else { return }
        cancelCurrent()
        let length = events.map(\.end).max() ?? 0
        if hardwareSupported, coreFailures < 3, playCore(events) {
            scheduleShutdown(after: length + 0.35)
        } else {
            playFallback(events)
        }
    }

    /// Replaces whatever is playing. Never leaves two patterns alive.
    private func cancelCurrent() {
        shutdownTask?.cancel(); shutdownTask = nil
        fallbackTask?.cancel(); fallbackTask = nil
        if let player { try? player.stop(atTime: CHHapticTimeImmediate) }
        player = nil
    }

    private func playCore(_ events: [DecoderHapticEvent]) -> Bool {
        do {
            let engine = try ensureEngine()
            let core = events.map { e -> CHHapticEvent in
                let params = [CHHapticEventParameter(parameterID: .hapticIntensity, value: Float(e.intensity)),
                              CHHapticEventParameter(parameterID: .hapticSharpness, value: Float(e.sharpness))]
                return e.isContinuous
                    ? CHHapticEvent(eventType: .hapticContinuous, parameters: params, relativeTime: e.time, duration: e.duration)
                    : CHHapticEvent(eventType: .hapticTransient, parameters: params, relativeTime: e.time)
            }
            let pattern = try CHHapticPattern(events: core, parameters: [])
            let newPlayer = try engine.makePlayer(with: pattern)
            try engine.start()
            try newPlayer.start(atTime: CHHapticTimeImmediate)
            player = newPlayer
            coreFailures = 0
            return true
        } catch {
            coreFailures += 1
            tearDownEngine()        // next cue builds a fresh engine (or falls back)
            return false
        }
    }

    private func ensureEngine() throws -> CHHapticEngine {
        if let engine { return engine }
        let created = try CHHapticEngine()
        let token = UUID()
        engineToken = token
        created.playsHapticsOnly = true          // no audio, no AVAudioSession interference
        created.isAutoShutdownEnabled = true
        created.stoppedHandler = { [weak self] _ in
            Task { @MainActor in self?.engineLost(token: token) }
        }
        created.resetHandler = { [weak self] in
            Task { @MainActor in self?.engineLost(token: token) }
        }
        engine = created
        return created
    }

    /// Interruption, system reset, idle auto-shutdown: drop the engine; the next
    /// cue recreates it lazily. Nothing is restarted behind the player's back.
    private func engineLost(token: UUID) {
        guard token == engineToken else { return } // stale callback from a discarded engine
        engineToken = UUID()
        cancelCurrent()
        player = nil
        engine?.stoppedHandler = { _ in }
        engine?.resetHandler = {}
        engine = nil
    }

    private func tearDownEngine() {
        engineToken = UUID() // invalidate already-enqueued stopped/reset callbacks
        if let player { try? player.stop(atTime: CHHapticTimeImmediate) }
        player = nil
        guard let engine else { return }
        engine.stoppedHandler = { _ in }
        engine.resetHandler = {}
        engine.stop(completionHandler: nil)
        self.engine = nil
    }

    private func scheduleShutdown(after seconds: Double) {
        shutdownTask = Task { @MainActor [weak self] in
            do { try await Task.sleep(for: .milliseconds(Int(seconds * 1000))) } catch { return }
            self?.tearDownEngine()
        }
    }

    /// UIKit fallback: same events as impacts (.heavy for strong, .rigid for the
    /// rest), at most one per 40 ms slot, one cancellable task, finite.
    private func playFallback(_ events: [DecoderHapticEvent]) {
        var steps: [(time: Double, intensity: Double)] = []
        for e in events {
            if let last = steps.last, e.time - last.time < 0.04 {
                if e.intensity > last.intensity { steps[steps.count - 1].intensity = e.intensity }
            } else {
                steps.append((e.time, e.intensity))
            }
        }
        steps = Array(steps.prefix(DecoderHapticRecipe.maxEvents))
        func fire(_ intensity: Double) {
            let gen = intensity >= 0.75 ? heavy : rigid
            gen.impactOccurred(intensity: CGFloat(min(max(intensity, 0.3), 1)))
        }
        guard let first = steps.first else { return }
        fire(first.intensity)
        let rest = Array(steps.dropFirst())
        guard !rest.isEmpty else { return }
        fallbackTask = Task { @MainActor [weak self] in
            var elapsed = first.time
            for step in rest {
                let wait = step.time - elapsed
                if wait > 0 { do { try await Task.sleep(for: .milliseconds(Int(wait * 1000))) } catch { return } }
                guard let self, !Task.isCancelled, self.canPlay else { return }
                elapsed = step.time
                let gen = step.intensity >= 0.75 ? self.heavy : self.rigid
                gen.impactOccurred(intensity: CGFloat(min(max(step.intensity, 0.3), 1)))
            }
        }
    }
}

// MARK: - HDR plumbing

private struct DecoderHDRKey: EnvironmentKey { static let defaultValue = true }
private extension EnvironmentValues {
    var decoderHDREnabled: Bool {
        get { self[DecoderHDRKey.self] }
        set { self[DecoderHDRKey.self] = newValue }
    }
}

/// Luminous centres. `stops` is a real exposure boost in the linear light
/// domain (Color.exposureAdjust multiplies by 2^stops), kept in 1.0...1.5 and
/// STATIC: nothing here animates the light level, so nothing can flash.
private enum DecoderLED {
    static let history = 1.0       // rows already played
    static let draft = 1.3         // the row being composed
    static let knob = 1.5          // the colour under the knob
    static let pilot = 1.25
    static let hint = 1.3          // the lit lip under a played key
    static let counter = 1.2
    static let antenna = 1.4

    static func color(_ base: Color, stops: Double, hdr: Bool) -> Color {
        hdr ? base.exposureAdjust(min(max(stops, 0), 1.5)) : base
    }
    static func rgb(_ hex: UInt32) -> Color {
        Color(.sRGB, red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255,
              blue: Double(hex & 0xFF) / 255, opacity: 1)
    }
    static let pilotGreen = rgb(0x3CE06A)
    static let pilotWhite = rgb(0xF4F6F8)
    static let counterRed = rgb(0xFFA733)   // ámbar de válvula (el nombre se queda por las llamadas)
}

private extension View {
    /// Asks the system to render this view with HDR headroom when enabled.
    @ViewBuilder func ledRange(_ on: Bool) -> some View {
        if on { self.allowedDynamicRange(.high) } else { self }
    }
}

// MARK: - Materials

private enum DM {
    static let caseTop     = Color(light: "4A545E", dark: "3A434C")   // acero gris azulado
    static let caseBottom  = Color(light: "2E353D", dark: "232930")
    static let caseEdgeHi  = Color(light: "8A96A2", dark: "6B7783")
    static let caseEdgeLo  = Color(light: "14181C", dark: "0E1114")
    static let panel       = Color(light: "1B1714", dark: "14110F")   // baquelita
    static let rail        = Color(light: "0C0A09", dark: "070605")
    static let handle      = Color(light: "17191C", dark: "0E0F11")
    static let chrome      = Color(light: "C9D0D6", dark: "AEB6BD")
    static let cream       = Color(light: "E9DEC2", dark: "DCCFAE")   // dial de frecuencias
    static let creamInk    = Color(light: "3A2E1E", dark: "33281A")
    static let amber       = Color(light: "FFB36B", dark: "FFB36B")
    static let printed     = Color(light: "E6DCC4", dark: "E6DCC4")   // serigrafía sobre la caja
    static let plate       = Color(white: 0.07)                        // dark status plate
    static let plateInk    = Color(white: 0.93)
    static let lampDaily   = Color(red: 1.0, green: 0.66, blue: 0.16)
    static let lampInfinite = Color(red: 0.20, green: 0.72, blue: 1.0)
}

// MARK: - Geometry (unidades propias: el cuerpo mide 626 de ancho; todo va multiplicado por s)

private struct DeviceMetrics {
    let s: CGFloat
    /// How far the black band sticks out past the green body, on EACH side.
    let overhang: CGFloat

    /// `width` is everything the screen margins allow. The body is made
    /// narrower than that so the band can overhang both sides and still end
    /// exactly at the margins (no clipping, no horizontal scroll).
    init(width: CGFloat) {
        let o: CGFloat = 0        // el dial ya no sobresale de la caja
        overhang = o
        s = max(0.25, (width - 2 * o) / 626)
    }

    var bodyW: CGFloat { 626 * s }
    var stripW: CGFloat { panelW }
    var panelW: CGFloat { 545 * s }
    var panelLeft: CGFloat { 40.5 * s }   // panel centrado en la caja
    /// One row pitch for ALL rows (active, solved, empty). Never below 44 pt.
    var pitch: CGFloat { max(82 * s, 44) }
    var keyW: CGFloat { 42 * s }
    var keyH: CGFloat { 60 * s }
    /// Column pitch from the measured centres 167 / 258 / 348 / 439.
    var cellW: CGFloat { 90.67 * s }
    var leadW: CGFloat { 29.67 * s }
    var pilotAreaW: CGFloat { panelW - leadW - 4 * cellW }
    var rowsTop: CGFloat { 29 * s }
    var rowsBottom: CGFloat { 53 * s }
    var panelH: CGFloat { rowsTop + CGFloat(DecoderRules.maxAttempts) * pitch + rowsBottom }
    var stripH: CGFloat { max(49 * s, 44) }
    var bodyTopPad: CGFloat { 36 * s }
    var knobD: CGFloat { max(112 * s, 88) }
    var knobBox: CGFloat { knobD + 30 }
    var bottomH: CGFloat { max(164 * s, knobBox + 6) }
    var corner: CGFloat { 16 * s }
}

// MARK: - Keys, pilots, counter

/// Una VÁLVULA: zócalo redondo, ampolla de vidrio que se enciende con el color y,
/// debajo, un piloto pequeño (la pista de esa casilla). El marco lo fija quien
/// la usa; selección y destello se dibujan DENTRO, así que nunca cambia de tamaño.
private struct DeviceKey: View {
    let width: CGFloat
    let height: CGFloat
    let color: Int?
    var stops: Double = DecoderLED.history
    var selected = false
    var flash = false
    var dimmed = false
    /// The colour under the knob, shown in the selected key but NOT placed yet.
    var preview = false
    /// The previewed colour already sits in another slot: it cannot be placed.
    var rejected = false
    /// Played rows only: what the pilot under the valve says about this slot.
    var hint: DecoderSlotHint? = nil
    @Environment(\.decoderHDREnabled) private var hdr
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiate

    private var d: CGFloat { min(width * 1.12, height * 0.76) }

    var body: some View {
        let c = color.flatMap { DecoderColor(rawValue: $0) }
        ZStack {
            // Zócalo: aro metálico y fondo oscuro.
            Circle().fill(LinearGradient(colors: [Color(white: 0.42), Color(white: 0.16)], startPoint: .top, endPoint: .bottom))
                .frame(width: d, height: d)
            Circle().fill(Color(white: 0.05)).frame(width: d * 0.84, height: d * 0.84)
            bulb(c)
            if selected { Circle().strokeBorder(DM.amber, lineWidth: 2.5).frame(width: d + 5, height: d + 5) }
            if flash { Circle().strokeBorder(Color.white, lineWidth: 2.5).frame(width: d + 5, height: d + 5) }
        }
        .offset(y: -height * 0.07)
        .overlay(alignment: .bottom) { pilot }
        .frame(width: width, height: height)
        .accessibilityHidden(true)
    }

    /// Piloto bajo la válvula. En filas jugadas es la pista de esa casilla:
    /// verde = en su sitio, blanco = en otra casilla, apagado = no está. Con
    /// «Diferenciar sin color» el blanco lleva un punto negro en el centro.
    @ViewBuilder private var pilot: some View {
        let r = max(4, height * 0.10)
        Group {
            switch hint {
            case .some(.exact):
                Circle().fill(DecoderLED.color(DecoderLED.pilotGreen, stops: DecoderLED.hint, hdr: hdr))
                    .frame(width: r, height: r)
                    .shadow(color: DecoderLED.pilotGreen.opacity(0.55), radius: r * 0.7)
                    .ledRange(hdr)
            case .some(.present):
                Circle().fill(DecoderLED.color(DecoderLED.pilotWhite, stops: DecoderLED.hint, hdr: hdr))
                    .frame(width: r, height: r)
                    .overlay { if differentiate { Circle().fill(Color(white: 0.1)).frame(width: r * 0.4, height: r * 0.4) } }
                    .shadow(color: Color.white.opacity(0.40), radius: r * 0.7)
                    .ledRange(hdr)
            default:
                Circle().fill(Color.white.opacity(0.13)).frame(width: r * 0.7, height: r * 0.7)
            }
        }
        .frame(width: r, height: r)
    }

    @ViewBuilder private func bulb(_ c: DecoderColor?) -> some View {
        let g = d * 0.70
        if let c {
            Circle()
                .fill(DecoderLED.color(c.ledColor, stops: stops, hdr: hdr))
                .overlay(Circle().fill(RadialGradient(colors: [Color.white.opacity(0.45), Color.clear],
                                                      center: UnitPoint(x: 0.34, y: 0.28), startRadius: 0, endRadius: g * 0.42)))
                .frame(width: g, height: g)
                .opacity(dimmed ? 0.35 : 1)
                .shadow(color: c.ledColor.opacity(dimmed ? 0.10 : 0.5), radius: d * 0.14)   // halo SDR; el HDR viene de exposureAdjust
                .ledRange(hdr)
                .overlay {
                    // Aún sin colocar: un aro discontinuo lo marca como vista previa.
                    if preview {
                        Circle().strokeBorder(Color.white.opacity(0.9), style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
                    }
                }
                .overlay {
                    // Rechazado (ya está en otra casilla): tachado, para no depender del atenuado.
                    if rejected {
                        Capsule().fill(Color.white.opacity(0.9))
                            .frame(width: 2, height: g * 1.05)
                            .rotationEffect(.degrees(45))
                    }
                }
                .overlay {
                    if differentiate {
                        Text("\(c.number)")
                            .font(.system(size: g * 0.56, weight: .heavy, design: .rounded))
                            .foregroundStyle(c.ink)
                    }
                }
        } else {
            // Apagada: vidrio oscuro con el filamento.
            Circle().fill(RadialGradient(colors: [Color(white: 0.16), Color(white: 0.07)], center: .center, startRadius: 0, endRadius: g * 0.5))
                .overlay(Capsule().fill(Color.white.opacity(0.10)).frame(width: g * 0.34, height: 1.5))
                .overlay(Circle().strokeBorder(Color.white.opacity(0.06), lineWidth: 1))
                .frame(width: g, height: g)
        }
    }
}

/// Medidor de señal: 4 barras de altura creciente. Verde = color en su casilla,
/// blanco = color en otra casilla, apagada = nada. El orden NO indica casilla
/// (primero las verdes, luego las blancas).
private struct DevicePilots: View {
    let diameter: CGFloat
    let feedback: DecoderFeedback?
    @Environment(\.decoderHDREnabled) private var hdr
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiate

    var body: some View {
        let kinds = Self.kinds(feedback)
        HStack(alignment: .bottom, spacing: diameter * 0.30) {
            ForEach(0..<4, id: \.self) { i in pilot(kinds[i], height: diameter * (0.9 + 0.42 * CGFloat(i))) }
        }
        .accessibilityHidden(true)
    }

    /// 0 off, 1 white, 2 green.
    static func kinds(_ f: DecoderFeedback?) -> [Int] {
        guard let f else { return [0, 0, 0, 0] }
        let exact = min(max(f.exact, 0), DecoderRules.slots)
        let misplaced = min(max(f.misplaced, 0), DecoderRules.slots - exact)
        return Array(repeating: 2, count: exact) + Array(repeating: 1, count: misplaced)
            + Array(repeating: 0, count: DecoderRules.slots - exact - misplaced)
    }

    @ViewBuilder private func pilot(_ kind: Int, height: CGFloat) -> some View {
        let w = diameter * 0.52
        let bar = RoundedRectangle(cornerRadius: w * 0.3, style: .continuous)
        switch kind {
        case 2:
            bar.fill(DecoderLED.color(DecoderLED.pilotGreen, stops: DecoderLED.pilot, hdr: hdr))
                .frame(width: w, height: height)
                .shadow(color: DecoderLED.pilotGreen.opacity(0.5), radius: diameter * 0.25)
                .ledRange(hdr)
        case 1:
            bar.fill(DecoderLED.color(DecoderLED.pilotWhite, stops: DecoderLED.pilot, hdr: hdr))
                .overlay { if differentiate { Rectangle().fill(Color.black.opacity(0.8)).frame(height: max(1.5, height * 0.14)) } }
                .frame(width: w, height: height)
                .shadow(color: Color.white.opacity(0.35), radius: diameter * 0.2)
                .ledRange(hdr)
        default:
            bar.fill(Color(white: 0.03))
                .overlay(bar.strokeBorder(Color.white.opacity(0.12), lineWidth: 1))
                .frame(width: w, height: height)
        }
    }
}

/// Seven-segment digit drawn as vector polygons (no fonts, no assets).
private struct SegmentShape: Shape {
    let index: Int           // 0 a(top) 1 b(top-right) 2 c(bottom-right) 3 d(bottom) 4 e(bottom-left) 5 f(top-left) 6 g(middle)
    let thickness: CGFloat

    func path(in rect: CGRect) -> Path {
        let t = thickness, w = rect.width, h = rect.height, gap: CGFloat = 1.2
        var p = Path()
        func horizontal(y: CGFloat) {
            let x0 = t / 2 + gap, x1 = w - t / 2 - gap
            p.addLines([CGPoint(x: x0, y: y), CGPoint(x: x0 + t / 2, y: y - t / 2), CGPoint(x: x1 - t / 2, y: y - t / 2),
                        CGPoint(x: x1, y: y), CGPoint(x: x1 - t / 2, y: y + t / 2), CGPoint(x: x0 + t / 2, y: y + t / 2)])
            p.closeSubpath()
        }
        func vertical(x: CGFloat, y0: CGFloat, y1: CGFloat) {
            p.addLines([CGPoint(x: x, y: y0), CGPoint(x: x + t / 2, y: y0 + t / 2), CGPoint(x: x + t / 2, y: y1 - t / 2),
                        CGPoint(x: x, y: y1), CGPoint(x: x - t / 2, y: y1 - t / 2), CGPoint(x: x - t / 2, y: y0 + t / 2)])
            p.closeSubpath()
        }
        let upper0 = t / 2 + gap, upper1 = h / 2 - gap
        let lower0 = h / 2 + gap, lower1 = h - t / 2 - gap
        switch index {
        case 0: horizontal(y: t / 2)
        case 1: vertical(x: w - t / 2, y0: upper0, y1: upper1)
        case 2: vertical(x: w - t / 2, y0: lower0, y1: lower1)
        case 3: horizontal(y: h - t / 2)
        case 4: vertical(x: t / 2, y0: lower0, y1: lower1)
        case 5: vertical(x: t / 2, y0: upper0, y1: upper1)
        default: horizontal(y: h / 2)
        }
        return p
    }
}

private struct SevenSegmentDigit: View {
    let digit: Int
    let width: CGFloat
    let height: CGFloat
    let on: Color
    let off: Color

    /// a b c d e f g
    static func mask(_ digit: Int) -> [Bool] {
        switch min(max(digit, 0), 9) {
        case 0: return [true, true, true, true, true, true, false]
        case 1: return [false, true, true, false, false, false, false]
        case 2: return [true, true, false, true, true, false, true]
        case 3: return [true, true, true, true, false, false, true]
        case 4: return [false, true, true, false, false, true, true]
        case 5: return [true, false, true, true, false, true, true]
        case 6: return [true, false, true, true, true, true, true]
        case 7: return [true, true, true, false, false, false, false]
        case 8: return [true, true, true, true, true, true, true]
        default: return [true, true, true, true, false, true, true]
        }
    }

    var body: some View {
        let lit = Self.mask(digit)
        ZStack {
            ForEach(0..<7, id: \.self) { i in
                SegmentShape(index: i, thickness: width * 0.22).fill(lit[i] ? on : off)
            }
        }
        .frame(width: width, height: height)
    }
}

/// Contador ámbar de 3 cifras en su ventanilla redondeada, con su rótulo serigrafiado.
private struct DeviceCounter: View {
    let m: DeviceMetrics
    let value: Int
    let caption: String
    /// Extra VoiceOver value (current mode and level), since no caption prints it.
    var speech: String = ""
    @Environment(\.decoderHDREnabled) private var hdr

    var body: some View {
        let v = max(value, 0)
        let digits = DecoderCounter.digits(v)
        let compression = min(1, 3 / CGFloat(digits.count))
        let w = 46 * m.s * compression, h = 80 * m.s
        VStack(spacing: 4) {
            HStack(spacing: 7 * m.s * compression) {
                ForEach(digits.indices, id: \.self) { i in
                    SevenSegmentDigit(digit: digits[i], width: w, height: h,
                                      on: DecoderLED.color(DecoderLED.counterRed, stops: DecoderLED.counter, hdr: hdr),
                                      off: DecoderLED.counterRed.opacity(0.10))
                }
            }
            .padding(.horizontal, 22 * m.s).padding(.vertical, 10 * m.s)
            .background(Capsule(style: .continuous).fill(Color(red: 0.07, green: 0.045, blue: 0.02)))
            .overlay(Capsule(style: .continuous).strokeBorder(LinearGradient(colors: [DM.chrome, DM.chrome.opacity(0.35)], startPoint: .top, endPoint: .bottom), lineWidth: 2))
            .ledRange(hdr)
            Text(caption)
                .font(.caption2.weight(.heavy)).tracking(1.5)
                .foregroundStyle(DM.printed)
                .lineLimit(1).minimumScaleFactor(0.6)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(caption.capitalized + " \(v)")
        .accessibilityValue(speech)
        .accessibilityIdentifier("decoder.counter")
    }
}

// MARK: - Knob

/// Dial negro moleteado con faldón crema: el ÚNICO control además de las válvulas y las lámparas de modo.
/// ONE DragGesture owns its three inputs, so they cannot fight each other:
///  - TURN (a drag around the hub): `position` moves one detent at a time.
///  - SHORT TAP (a touch that neither turns nor is held): `onPress`.
///  - HOLD (~0.5 s without turning): `onLongPress`, fired once, while the finger
///    is still down. After it fires the rest of that touch is inert.
/// A touch that has turned can never become a hold or a tap, and a hold that
/// fired can never become a tap. Its face stays orange: what it selects is
/// shown on the board (colour preview) or on the red counter (level).
///
/// The same knob serves two roles (`role` only tells it when the meaning of
/// `position` changed, so it re-seats without spinning):
///  - colours: `detents` = colour count, no `range` (it wraps), dots shown.
///  - level selector: fixed detents per turn, `range` = 1...best (hard stops).
private struct DecoderKnobView: View {
    @Binding var position: Int
    /// Detents per full turn.
    let detents: Int
    /// Hard stops. nil = free spinning.
    var range: ClosedRange<Int>? = nil
    let role: Int
    let diameter: CGFloat
    var showDots = true
    let enabled: Bool
    let label: String
    let value: String
    let hint: String
    /// VoiceOver name of the custom action that does what a HOLD does (or, when
    /// there is no hold handler, what a tap does).
    let holdActionName: String
    var onDetent: () -> Void = {}
    var onTouchStart: () -> Void = {}
    var onPress: () -> Void = {}
    var onLongPress: (() -> Void)? = nil
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static let holdSeconds = 0.5
    /// Net degrees (and points) the finger must travel before a touch is a turn.
    static let turnDegrees = 4.0
    static let turnPoints: CGFloat = 6
    /// A finger that wanders this far without turning is not holding still.
    static let holdSlop: CGFloat = 12

    @State private var rotation: Double = 0          // degrees clockwise = position * step
    @State private var dragging = false
    @State private var lastAngle: Double = 0
    @State private var travelled: Double = 0         // NET signed degrees: jitter cancels out
    @State private var turned = false
    @State private var holdFired = false
    @State private var holdTask: Task<Void, Never>?
    @State private var seatedRole: Int?
    /// True only while a finger is down; the system resets it when the gesture
    /// ends OR is cancelled, so a cancelled touch can never fire a late hold.
    @GestureState private var touching = false

    private var step: Double { DecoderWheel.step(count: detents) }
    private var box: CGFloat { diameter + 30 }
    private var selectedDetent: Int { DecoderWheel.wrap(position, count: detents) }

    private func clamped(_ k: Int) -> Int {
        guard let range else { return k }
        return min(max(k, range.lowerBound), range.upperBound)
    }

    var body: some View {
        ZStack {
            if showDots { detentDots }
            knobBody
                .rotationEffect(.degrees(displayRotation))
        }
        .frame(width: box, height: box)
        .contentShape(Circle())
        .gesture(drag)
        .opacity(enabled ? 1 : 0.55)
        .onAppear { rotation = Double(position) * step; seatedRole = role }
        .onDisappear { cancelHold() }
        .onChange(of: position) { _, _ in
            // A role change re-seats without animation (see below).
            if !dragging && seatedRole == role { snap() }
        }
        .onChange(of: detents) { _, _ in if seatedRole == role { snap() } }
        .onChange(of: role) { _, new in
            seatedRole = new
            rotation = Double(position) * step       // new meaning of `position`: no spin
        }
        .onChange(of: touching) { _, now in
            guard !now else { return }
            cancelHold()
            // If the gesture was CANCELLED there is no onEnded: tidy up after it.
            // (Deferred one hop so a normal onEnded always runs first.)
            Task { @MainActor in
                if dragging && !touching { dragging = false; snap() }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(value)
        .accessibilityHint(hint)
        .accessibilityAddTraits(.isButton)
        .accessibilityAdjustableAction { direction in
            guard enabled else { return }
            let before = position
            switch direction {
            case .increment: position = clamped(position + 1)
            case .decrement: position = clamped(position - 1)
            @unknown default: break
            }
            if position != before { onDetent() }
        }
        .accessibilityAction { if enabled { onPress() } }
        .accessibilityAction(named: holdActionName) {
            guard enabled else { return }
            if let onLongPress { onLongPress() } else { onPress() }
        }
        .accessibilityIdentifier("decoder.hub")
    }

    private var detentDots: some View {
        ZStack {
            ForEach(0..<detents, id: \.self) { i in
                Circle()
                    .fill(i == selectedDetent ? DM.amber : DM.printed.opacity(0.45))
                    .frame(width: i == selectedDetent ? 7 : 5, height: i == selectedDetent ? 7 : 5)
                    .offset(y: -(diameter / 2 + 10))
                    .rotationEffect(.degrees(Double(i) * step))
            }
        }
        .accessibilityHidden(true)
    }

    private var knobBody: some View {
        ZStack {
            // Faldón crema con escala, como el dial de sintonía de un receptor.
            Circle().fill(LinearGradient(colors: [DM.cream, DM.cream.opacity(0.78)], startPoint: .top, endPoint: .bottom))
                .frame(width: diameter, height: diameter)
                .shadow(color: .black.opacity(0.45), radius: 5, y: 3)
            ForEach(0..<24, id: \.self) { i in
                Capsule().fill(DM.creamInk.opacity(i % 3 == 0 ? 0.75 : 0.4))
                    .frame(width: max(1, diameter * 0.014), height: diameter * (i % 3 == 0 ? 0.075 : 0.045))
                    .offset(y: -diameter * 0.445)
                    .rotationEffect(.degrees(Double(i) * 15))
            }
            // Cuerpo de baquelita, moleteado fino.
            Circle().fill(LinearGradient(colors: [Color(white: 0.20), Color(white: 0.05)], startPoint: .top, endPoint: .bottom))
                .frame(width: diameter * 0.78, height: diameter * 0.78)
            ForEach(0..<48, id: \.self) { i in
                Capsule().fill(Color.white.opacity(0.13))
                    .frame(width: max(1, diameter * 0.012), height: diameter * 0.07)
                    .offset(y: -diameter * 0.345)
                    .rotationEffect(.degrees(Double(i) * 7.5))
            }
            Circle().fill(LinearGradient(colors: [Color(white: 0.16), Color(white: 0.09)], startPoint: .top, endPoint: .bottom))
                .frame(width: diameter * 0.60, height: diameter * 0.60)
                .overlay(Circle().strokeBorder(Color.white.opacity(0.10), lineWidth: 1))
            // Tapa cromada y aguja crema.
            Circle().fill(LinearGradient(colors: [DM.chrome, DM.chrome.opacity(0.45)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: diameter * 0.20, height: diameter * 0.20)
            Capsule().fill(DM.cream)
                .frame(width: max(3, diameter * 0.045), height: diameter * 0.17)
                .offset(y: -diameter * 0.275)
        }
        .frame(width: diameter, height: diameter)
    }

    /// While dragging, the knob lags the finger between detents and clicks over
    /// at each boundary (the lag is dropped under Reduce Motion).
    private var displayRotation: Double {
        guard dragging, !reduceMotion else { return rotation }
        let p = rotation / step
        let nearest = p.rounded()
        return (nearest + 0.55 * (p - nearest)) * step
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .updating($touching) { _, state, _ in state = true }
            .onChanged { value in
                guard enabled else { return }
                let dx = Double(value.location.x - box / 2), dy = Double(value.location.y - box / 2)
                let radial = (dx * dx + dy * dy).squareRoot()
                let angle = DecoderWheel.angle(dx: dx, dy: dy)
                if !dragging {
                    dragging = true
                    turned = false; holdFired = false
                    rotation = Double(position) * step
                    lastAngle = angle; travelled = 0
                    onTouchStart()
                    armHold()
                    return
                }
                // A recognised hold consumed this touch: nothing else can happen.
                guard !holdFired else { return }
                let moved = max(abs(value.translation.width), abs(value.translation.height))
                if moved > Self.holdSlop { cancelHold() }
                // Near the hub the angle is noise: such touches can push, not turn.
                guard radial > Double(diameter) * 0.14 else { lastAngle = angle; return }
                let delta = DecoderWheel.shortestDelta(from: lastAngle, to: angle)
                lastAngle = angle
                if !turned {
                    travelled += delta
                    // A push is not a spin: it takes a real, net movement to turn.
                    guard abs(travelled) > Self.turnDegrees, moved > Self.turnPoints else { return }
                    turned = true
                    cancelHold()                         // a turn can NEVER become a submit
                }
                rotation += delta
                var next = DecoderWheel.resolve(position: rotation / step, current: position)
                let stop = clamped(next)
                if stop != next {                        // against a hard stop: no wind-up
                    next = stop
                    rotation = Double(stop) * step
                }
                if next != position { position = next; onDetent() }
            }
            .onEnded { _ in
                guard dragging else { return }
                dragging = false
                cancelHold()
                let tapped = !turned && !holdFired
                snap()
                if tapped { onPress() }
            }
    }

    /// Starts the hold timer at touch-down. It fires only if, half a second
    /// later, the same finger is still down and has not turned.
    private func armHold() {
        cancelHold()
        guard onLongPress != nil else { return }
        holdTask = Task { @MainActor in
            do { try await Task.sleep(for: .milliseconds(Int(Self.holdSeconds * 1000))) } catch { return }
            guard touching, dragging, !turned, !holdFired else { return }
            holdFired = true
            onLongPress?()
        }
    }

    private func cancelHold() {
        holdTask?.cancel()
        holdTask = nil
    }

    private func snap() {
        let target = Double(position) * step
        if reduceMotion { rotation = target }
        else { withAnimation(.spring(response: 0.28, dampingFraction: 0.62)) { rotation = target } }
    }
}

/// Antena telescópica: tres tramos cromados cada vez más finos y una bolita en la punta.
private struct DeviceAerial: View {
    let length: CGFloat
    var body: some View {
        VStack(spacing: 0) {
            Circle().fill(DM.chrome).frame(width: 6, height: 6)
            Capsule().fill(DM.chrome.opacity(0.85)).frame(width: 2, height: length * 0.36)
            Capsule().fill(DM.chrome.opacity(0.9)).frame(width: 3.2, height: length * 0.32)
            Capsule().fill(DM.chrome).frame(width: 4.6, height: length * 0.28)
        }
        .accessibilityHidden(true)
    }
}

/// Tornillo de cabeza ranurada (decoración de la caja).
private struct DeviceScrew: View {
    let size: CGFloat
    let turn: Double
    var body: some View {
        ZStack {
            Circle().fill(LinearGradient(colors: [DM.chrome, DM.chrome.opacity(0.4)], startPoint: .top, endPoint: .bottom))
            Capsule().fill(Color.black.opacity(0.55)).frame(width: size * 0.74, height: max(1, size * 0.14)).rotationEffect(.degrees(turn))
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

// MARK: - Mode lamps

/// The drawing of one antenna light. Its light state is ONLY the mode: it never
/// depends on the current row, on a guess being complete or on the result. The
/// Button that makes it tappable (and its VoiceOver wording) lives in
/// `DecoderGameView.modeButton`.
private struct DeviceModeLamp: View {
    let base: Color
    let isLit: Bool
    let tilt: Double
    let size: CGFloat
    @Environment(\.decoderHDREnabled) private var hdr

    var body: some View {
        // Lámpara de joya: aro cromado, vidrio abombado. `tilt` ya no se usa.
        ZStack {
            Circle().fill(LinearGradient(colors: [DM.chrome, DM.chrome.opacity(0.35)], startPoint: .top, endPoint: .bottom))
                .shadow(color: .black.opacity(0.45), radius: 2, y: 2)
            Circle().fill(Color(white: 0.06)).padding(size * 0.11)
            if isLit {
                Circle().fill(DecoderLED.color(base, stops: DecoderLED.antenna, hdr: hdr))
                    .overlay(Circle().fill(RadialGradient(colors: [.white.opacity(0.55), .clear], center: UnitPoint(x: 0.35, y: 0.3),
                                                          startRadius: 0, endRadius: size * 0.3)))
                    .padding(size * 0.16)
                    .shadow(color: base.opacity(0.55), radius: 6)
                    .ledRange(hdr)
            } else {
                Circle().fill(base.opacity(0.14)).padding(size * 0.16)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// Pulsador de PISTA: redondo, con aro cromado y una bombilla. The lamp glows amber while there is a hidden row it can
/// reveal; once pressed (or with nothing to reveal) it is dark. The touch
/// target is never smaller than 44 pt.
private struct DeviceHintButton: View {
    let size: CGFloat
    let ready: Bool
    let caption: String
    @Environment(\.decoderHDREnabled) private var hdr

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle().fill(LinearGradient(colors: [DM.chrome, DM.chrome.opacity(0.35)], startPoint: .top, endPoint: .bottom))
                    .shadow(color: .black.opacity(0.40), radius: 2, y: 2)
                Circle().fill(LinearGradient(colors: [Color(white: 0.20), Color(white: 0.08)], startPoint: .top, endPoint: .bottom))
                    .padding(size * 0.10)
                Image(systemName: ready ? "lightbulb.fill" : "lightbulb")
                    .font(.system(size: size * 0.42, weight: .semibold))
                    .foregroundStyle(ready ? DecoderLED.color(DM.amber, stops: DecoderLED.hint, hdr: hdr) : Color.white.opacity(0.30))
                    .shadow(color: ready ? DM.amber.opacity(0.55) : .clear, radius: size * 0.12)
                    .ledRange(hdr && ready)
            }
            .frame(width: size, height: size)
            Text(caption)
                .font(.caption2.weight(.heavy)).tracking(1.5)
                .foregroundStyle(DM.printed)
                .lineLimit(1).minimumScaleFactor(0.6)
        }
        .frame(minWidth: 44, minHeight: 44)
        .contentShape(Rectangle())
    }
}

/// One passive light of the black band (a colour in play, or a solution slot).
private struct StripLight: View {
    let color: DecoderColor
    let width: CGFloat
    let height: CGFloat
    @Environment(\.decoderHDREnabled) private var hdr
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiate

    var body: some View {
        Circle()
            .fill(DecoderLED.color(color.ledColor, stops: DecoderLED.history, hdr: hdr))
            .overlay(Circle().strokeBorder(DM.creamInk.opacity(0.65), lineWidth: 1.5))
            .frame(width: min(max(width, 10), height), height: min(max(width, 10), height))
            .ledRange(hdr)
            .overlay {
                if differentiate {
                    Text("\(color.number)")
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .foregroundStyle(color.ink)
                }
            }
    }
}

// MARK: - Game view

private struct DecoderPlay {
    var game: DecoderGame
    var draft: DecoderDraft
    var wheel: Int
    var elapsed: Int
}

struct DecoderGameView: View {
    private enum Mode: Hashable { case entry, infinite }
    /// What the knob does right now.
    ///  - color: a game is being played (turn = colour, tap = place, hold = submit).
    ///  - level: Infinito with no game in progress (turn = level, tap = start).
    ///  - idle:  a finished Diario/Práctica game: the knob does nothing.
    private enum KnobRole: Int { case color, level, idle }

    @AppStorage(AppLanguage.storageKey) private var languageSelection = "system"
    @AppStorage(DecoderHaptics.enabledKey) private var hapticsOn = true
    @AppStorage("decoder.hdr.enabled") private var hdrOn = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject private var progress = PuzzleProgress.shared

    let initial: DecoderGame
    @State private var mode: Mode = .entry
    @State private var entry: DecoderPlay
    @State private var infRound = DecoderInfiniteRound.fresh(level: 1, serial: 0, seed: 1)   // placeholder until loaded
    @State private var infLevel = 1
    @State private var infBest = 1
    @State private var infLoaded = false
    /// Infinito only: the knob is the level selector (no game in progress).
    /// View state, not stored: a round that was started but has no colour yet
    /// would otherwise look "not begun" and trap the knob in the selector.
    @State private var pickingLevel = false
    @State private var pickLevel = 1
    #if DEBUG
    @State private var previewInfiniteDefaults: UserDefaults?
    #endif
    @State private var result: PZResult?
    @State private var shake: CGFloat = 0
    @State private var loaded = false
    /// Transient warning (incomplete row, repeated colour...). Shown in the black
    /// band for a few seconds, as on the Watch, and always announced.
    @State private var notice: String?
    @State private var noticeTask: Task<Void, Never>?
    @State private var flashSlot: Int?
    @State private var flashTask: Task<Void, Never>?
    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    init(game: DecoderGame) {
        self.initial = game
        _entry = State(initialValue: DecoderPlay(game: game, draft: DecoderDraft(colorCount: game.colorCount), wheel: 0, elapsed: 0))
    }

    // MARK: Active-mode accessors (nonmutating: they write @State)

    private var game: DecoderGame {
        get { mode == .entry ? entry.game : infRound.game }
        nonmutating set { if mode == .entry { entry.game = newValue } else { infRound.game = newValue } }
    }
    private var draft: DecoderDraft {
        get { mode == .entry ? entry.draft : infRound.draft }
        nonmutating set { if mode == .entry { entry.draft = newValue } else { infRound.draft = newValue } }
    }
    private var wheel: Int {
        get { mode == .entry ? entry.wheel : infRound.wheel }
        nonmutating set { if mode == .entry { entry.wheel = newValue } else { infRound.wheel = newValue } }
    }
    private var elapsed: Int {
        get { mode == .entry ? entry.elapsed : infRound.elapsed }
        nonmutating set { if mode == .entry { entry.elapsed = newValue } else { infRound.elapsed = newValue } }
    }

    private var store: DecoderStore { DecoderStore(defaults: progress.defaults) }
    private var infStore: DecoderInfiniteStore {
        #if DEBUG
        if let defaults = previewInfiniteDefaults { return DecoderInfiniteStore(defaults: defaults) }
        #endif
        return DecoderInfiniteStore(defaults: progress.defaults)
    }
    private var haptics: DecoderHaptics { .shared }
    private var colorCount: Int { game.colorCount }
    private var wheelColor: Int { DecoderWheel.wrap(wheel, count: colorCount) }
    private var knobRole: KnobRole {
        if mode == .infinite && (pickingLevel || game.isFinished) { return .level }
        return game.isFinished ? .idle : .color
    }
    /// colour -> slot already holding it (excluding the slot being edited).
    private var blocked: [Int: Int] {
        var map: [Int: Int] = [:]
        for color in 0..<colorCount { if let slot = draft.holder(of: color) { map[color] = slot } }
        return map
    }

    private var entryIsDaily: Bool {
        let base = initial.id.hasPrefix("en-") ? String(initial.id.dropFirst(3)) : initial.id
        return base == DecoderGame.idPrefix + "\(PuzzleSeed.daily(kind: .decoder))"
    }
    private var entryTitle: String {
        entryIsDaily ? AppLanguage.text("Diario", "Daily") : AppLanguage.text("Práctica", "Practice")
    }
    private var ruleLine: String {
        AppLanguage.text("4 colores distintos de \(colorCount) · no se repiten · \(game.maxAttempts) intentos",
                         "4 different colours of \(colorCount) · no repeats · \(game.maxAttempts) attempts")
    }
    /// Short mode/level description for VoiceOver (antennas and counter).
    private var modeSpeech: String {
        if mode == .entry {
            return entryIsDaily
                ? AppLanguage.text("Diario, el mismo código para todos hoy", "Daily, the same code for everyone today")
                : AppLanguage.text("Práctica, partida suelta", "Practice, a loose game")
        }
        if knobRole == .level {
            return AppLanguage.text("Infinito, eligiendo nivel \(pickLevel) de \(infBest)", "Infinite, choosing level \(pickLevel) of \(infBest)")
        }
        return AppLanguage.text("Infinito, nivel \(infRound.level), \(colorCount) colores, \(game.maxAttempts) intentos, máximo desbloqueado \(infBest)",
                                "Infinite, level \(infRound.level), \(colorCount) colours, \(game.maxAttempts) attempts, highest unlocked \(infBest)")
    }
    /// What used to be printed above and below the device. It now lives in the
    /// "Ahora" section of the "?" sheet (rules), so the device can fill the screen.
    private var nowLines: [String] {
        // While picking a level, contextLine already gives that level's colours
        // and attempts; ruleLine would describe the round that just ended.
        knobRole == .level ? [contextLine, controlsLine] : [contextLine, ruleLine, controlsLine]
    }
    private var contextLine: String {
        if mode == .entry {
            return entryIsDaily
                ? AppLanguage.text("Diario · el mismo código para todos hoy", "Daily · the same code for everyone today")
                : AppLanguage.text("Práctica · partida suelta, no es el reto de hoy", "Practice · a loose game, not today's puzzle")
        }
        if knobRole == .level {
            let n = DecoderInfinite.colorCount(level: pickLevel)
            let a = DecoderInfinite.maxAttempts(level: pickLevel)
            return AppLanguage.text("Infinito · elige nivel con el mando (1–\(infBest)) · nivel \(pickLevel): \(n) colores, \(a) intentos",
                                    "Infinite · choose a level with the knob (1–\(infBest)) · level \(pickLevel): \(n) colours, \(a) attempts")
        }
        return AppLanguage.text("Infinito · nivel \(infRound.level) · \(colorCount) colores · máximo desbloqueado \(infBest)",
                                "Infinite · level \(infRound.level) · \(colorCount) colours · highest unlocked \(infBest)")
    }
    /// How the device is driven now that it has no buttons (always visible).
    private var controlsLine: String {
        switch knobRole {
        case .color:
            return AppLanguage.text("Mando: girar = color · tocar = colocar · mantener = enviar",
                                    "Knob: turn = colour · tap = place · hold = submit")
        case .level:
            return AppLanguage.text("Mando: girar = nivel · tocar = empezar con código nuevo",
                                    "Knob: turn = level · tap = start with a new code")
        case .idle:
            return AppLanguage.text("Partida terminada · la lámpara azul abre Infinito",
                                    "Game over · the blue lamp opens Infinite")
        }
    }

    var body: some View {
        let _ = languageSelection
        GeometryReader { geo in
            // Everything the screen margins allow. The body is narrower than this
            // (DeviceMetrics) so the black band can overhang it on both sides.
            let width = min(max(geo.size.width - 2 * PZSpace.screenH, 240), 560)
            ScrollView {
                VStack(spacing: PZSpace.md) {
                    // No captions above or below the device (2026-11-12): mode,
                    // level, rules and controls are in the "?" sheet ("Ahora");
                    // warnings flash in the black band and are announced.
                    device(DeviceMetrics(width: width))
                    if game.isFinished { finishedPlate }
                }
                .frame(width: width)
                .frame(maxWidth: .infinity)
                .padding(.vertical, PZSpace.sm)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .environment(\.decoderHDREnabled, hdrOn)
        // Fondo con el resplandor del juego. El aparato ya tiene su propio relieve
        // (carcasa, teclas, LEDs): no se le añade pzVolume para no duplicarlo.
        .background(PZGameBackdrop(color: PZ.decoder))
        .navigationTitle("Decoder")
        .navigationBarTitleDisplayMode(.inline)
        // No bar material on this screen: back, title, "?" and options sit
        // directly on the canvas (they keep their own system contrast).
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Toggle(isOn: $hapticsOn) {
                        Label(AppLanguage.text("Hápticos de Decoder", "Decoder haptics"), systemImage: "hand.tap")
                    }
                    Toggle(isOn: $hdrOn) {
                        Label(AppLanguage.text("Luces HDR", "HDR lights"), systemImage: "sun.max")
                    }
                    if !haptics.hardwareSupported {
                        Text(AppLanguage.text("Este dispositivo no tiene motor háptico.", "This device has no haptic engine."))
                    }
                    Text(AppLanguage.text("HDR solo se ve en pantallas compatibles; en el resto, los colores son normales.",
                                          "HDR only shows on capable displays; elsewhere the colours are plain."))
                } label: { Image(systemName: "ellipsis.circle") }
                .accessibilityLabel(AppLanguage.text("Opciones de Decoder", "Decoder options"))
                .accessibilityIdentifier("decoder.options")
            }
        }
        .pzRules(.decoder, now: nowLines)
        .sheet(item: $result) { PZResultSheet(result: $0) }
        .onAppear { restore(); haptics.prepare() }
        .onDisappear { haptics.stop(); flashTask?.cancel(); noticeTask?.cancel(); persistAll() }
        .onReceive(tick) { _ in
            guard knobRole == .color, scenePhase == .active else { return }   // no clock while choosing a level
            elapsed += 1
            if elapsed % 5 == 0 { persistActive() }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { haptics.stop(); persistAll() }
        }
        .onChange(of: hapticsOn) { _, on in
            if !on { haptics.stop() }      // cut a running pattern immediately
        }
        .onChange(of: mode) { old, new in
            haptics.stop()
            flashTask?.cancel(); flashSlot = nil
            setNotice(nil)
            if old == .entry { progress.setElapsed(entry.game.id, entry.elapsed) }
            if old == .infinite { saveInfinite() }
            if new == .infinite { ensureInfinite() }
            haptics.slot()                 // the antenna click (after the stop above, so it is not cut)
        }
    }

    // MARK: Mode (the antennas)

    /// The only way to change mode. Everything else (saving the mode being left,
    /// loading Infinito) hangs off `.onChange(of: mode)`.
    private func selectMode(_ target: Mode) {
        guard target != mode else { return }
        mode = target                      // the click is played in .onChange(of: mode)
        announce(target == .entry ? entryTitle : AppLanguage.text("Infinito", "Infinite"))
    }

    /// One antenna: a mode LIGHT (lit only for the active mode) that is also the
    /// mode BUTTON. The touch area is an upright square of at least 52 pt around
    /// the tilted cap.
    private func modeButton(_ target: Mode, base: Color, tilt: Double, size: CGFloat) -> some View {
        let lit = mode == target
        let title = target == .entry ? entryTitle : AppLanguage.text("Infinito", "Infinite")
        let side = max(size, 44) + 8
        return Button { selectMode(target) } label: {
            DeviceModeLamp(base: base, isLit: lit, tilt: tilt, size: size)
                .frame(width: side, height: side)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(target == .entry
            ? AppLanguage.text("Lámpara ámbar: modo \(title)", "Amber lamp: \(title) mode")
            : AppLanguage.text("Lámpara azul: modo \(title)", "Blue lamp: \(title) mode"))
        .accessibilityValue(lit ? AppLanguage.text("encendido", "on") + ". " + modeSpeech : AppLanguage.text("apagado", "off"))
        .accessibilityHint(lit
            ? AppLanguage.text("Es el modo actual", "This is the current mode")
            : AppLanguage.text("Toca dos veces para cambiar a este modo", "Double-tap to switch to this mode"))
        .accessibilityAddTraits(lit ? .isSelected : [])
        .accessibilityIdentifier(target == .entry ? "decoder.mode.light.entry" : "decoder.mode.light.infinite")
    }

    // MARK: Device

    private func device(_ m: DeviceMetrics) -> some View {
        VStack(spacing: -8) {
            handle(m)
            bodyShell(m)
        }
        .frame(width: m.bodyW)
    }

    /// Tapa del receptor: asa de cuero, las dos lámparas de modo (siempre hay
    /// exactamente una encendida, también con la partida acabada) y la antena.
    private func handle(_ m: DeviceMetrics) -> some View {
        let lamp = min(58, max(44, m.bodyW * 0.11))
        let height = max(92, m.bodyW * 0.22)
        let lidH: CGFloat = 26
        return ZStack {
            // Antena, a la derecha, inclinada hacia fuera.
            DeviceAerial(length: height - 8)
                .rotationEffect(.degrees(9), anchor: .bottom)
                .position(x: m.bodyW * 0.90, y: (height - 8) / 2 + 2)
            // Asa: correa con dos anclajes.
            Capsule(style: .continuous)
                .strokeBorder(Color(red: 0.36, green: 0.22, blue: 0.12), lineWidth: 7)
                .frame(width: m.bodyW * 0.30, height: lidH * 2.1)
                .position(x: m.bodyW / 2, y: height - lidH - 2)
            // Tapa.
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(LinearGradient(colors: [DM.caseEdgeHi.opacity(0.9), DM.caseTop], startPoint: .top, endPoint: .bottom))
                .frame(width: m.bodyW * 0.94, height: lidH)
                .position(x: m.bodyW / 2, y: height - lidH / 2)
                .accessibilityHidden(true)
            ForEach([0.38, 0.62], id: \.self) { x in
                RoundedRectangle(cornerRadius: 2).fill(DM.chrome.opacity(0.8))
                    .frame(width: 12, height: 9)
                    .position(x: m.bodyW * x, y: height - lidH + 1)
                    .accessibilityHidden(true)
            }
            modeButton(.entry, base: DM.lampDaily, tilt: 0, size: lamp)
                .position(x: m.bodyW * 0.16, y: height - lidH - lamp * 0.30)
            modeButton(.infinite, base: DM.lampInfinite, tilt: 0, size: lamp)
                .position(x: m.bodyW * 0.72, y: height - lidH - lamp * 0.30)
        }
        .frame(width: m.bodyW, height: height)
    }

    private func bodyShell(_ m: DeviceMetrics) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Color.clear.frame(height: m.bodyTopPad)
            panel(m).padding(.leading, m.panelLeft)
            // The band is WIDER than the body. Laid out in a body-wide frame, it
            // is centred and overflows `overhang` on each side, ending exactly at
            // the screen margins (see DeviceMetrics): nothing clips or scrolls.
            strip(m).padding(.leading, m.panelLeft).padding(.top, 9 * m.s)
            bottomZone(m)
        }
        .frame(width: m.bodyW, alignment: .leading)
        .background {
            let shape = RoundedRectangle(cornerRadius: m.corner, style: .continuous)
            let screw = max(7, 15 * m.s), inset = max(8, 17 * m.s)
            ZStack {
                shape.fill(LinearGradient(colors: [DM.caseTop, DM.caseBottom], startPoint: .top, endPoint: .bottom))
                shape.strokeBorder(LinearGradient(colors: [DM.caseEdgeHi, DM.caseEdgeLo], startPoint: .top, endPoint: .bottom), lineWidth: 2)
                // Un tornillo en cada esquina.
                VStack {
                    HStack { DeviceScrew(size: screw, turn: 25); Spacer(); DeviceScrew(size: screw, turn: -40) }
                    Spacer()
                    HStack { DeviceScrew(size: screw, turn: 70); Spacer(); DeviceScrew(size: screw, turn: 10) }
                }
                .padding(inset)
            }
            .shadow(color: .black.opacity(0.30), radius: 12, x: 0, y: 8)
        }
    }

    /// Black panel: 7 rows of IDENTICAL frame + a darker result rail.
    private func panel(_ m: DeviceMetrics) -> some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 12 * m.s + 2, style: .continuous).fill(DM.panel)
            RoundedRectangle(cornerRadius: 9 * m.s + 2, style: .continuous).fill(DM.rail)
                .frame(width: m.panelW - (m.leadW + 4 * m.cellW) - 8 * m.s, height: m.panelH - 16 * m.s)
                .offset(x: m.leadW + 4 * m.cellW, y: 8 * m.s)
            VStack(spacing: 0) {
                Color.clear.frame(height: m.rowsTop)
                ForEach(0..<DecoderRules.maxAttempts, id: \.self) { row in boardRow(row, m) }
                Color.clear.frame(height: m.rowsBottom)
            }
        }
        .frame(width: m.panelW, height: m.panelH)
        .overlay(RoundedRectangle(cornerRadius: 12 * m.s + 2, style: .continuous).strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
    }

    /// One board row. Solved, active and empty rows are the SAME frame: the only
    /// difference is what is lit inside it.
    @ViewBuilder private func boardRow(_ row: Int, _ m: DeviceMetrics) -> some View {
        let isCurrent = !game.isFinished && row == game.attemptsUsed
        let isDone = row < game.guesses.count
        // Rows beyond this game's budget (Infinito 31+) stay on the board, off.
        let usable = row < game.maxAttempts
        HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(isCurrent ? DM.amber : Color.white.opacity(isDone ? 0.18 : 0.07))
                .frame(width: 4, height: m.keyH * 0.34)
                .frame(width: m.leadW, height: m.pitch)
                .accessibilityHidden(true)
            ForEach(0..<DecoderRules.slots, id: \.self) { slot in
                cell(row: row, slot: slot, m: m, isCurrent: isCurrent, isDone: isDone)
            }
            DevicePilots(diameter: max(9, 22 * m.s), feedback: isDone ? game.feedbacks[row] : nil)
                .frame(width: m.pilotAreaW, height: m.pitch)
        }
        .opacity(usable ? 1 : 0.28)
        .frame(width: m.panelW, height: m.pitch)
        .modifier(ShakeEffect(animatableData: isCurrent ? shake : 0))
        .accessibilityElement(children: isCurrent ? .contain : .ignore)
        .accessibilityLabel(rowLabel(row))
    }

    @ViewBuilder private func cell(row: Int, slot: Int, m: DeviceMetrics, isCurrent: Bool, isDone: Bool) -> some View {
        if isCurrent {
            let isSelected = draft.selected == slot
            let placed = draft.slots[slot]
            // LIVE PREVIEW: the selected key of the current row shows the colour
            // under the knob before it is placed. `taken` = the slot that already
            // holds that colour (then the preview is dimmed and struck through).
            let previewing = isSelected && knobRole == .color
            let taken = previewing ? blocked[wheelColor] : nil
            Button { selectSlot(slot) } label: {
                DeviceKey(width: m.keyW, height: m.keyH, color: previewing ? wheelColor : placed, stops: DecoderLED.draft,
                          selected: isSelected, flash: flashSlot == slot,
                          dimmed: taken != nil,
                          preview: previewing && placed != wheelColor,
                          rejected: taken != nil)
                    .frame(width: m.cellW, height: m.pitch)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(knobRole != .color)
            .accessibilityLabel(AppLanguage.text("Casilla \(slot + 1): ", "Slot \(slot + 1): ") + decoderName(placed))
            .accessibilityValue(previewValue(previewing: previewing, placed: placed, taken: taken))
            .accessibilityHint(isSelected ? "" : AppLanguage.text("Toca dos veces para seleccionarla", "Double-tap to select it"))
            .accessibilityAddTraits(isSelected ? .isSelected : [])
            .accessibilityAction(named: AppLanguage.text("Vaciar casilla", "Empty slot")) { clearSlot(slot) }
            .accessibilityIdentifier("decoder.slot.\(slot)")
        } else {
            DeviceKey(width: m.keyW, height: m.keyH, color: isDone ? game.guesses[row][slot] : nil, stops: DecoderLED.history,
                      hint: isDone ? slotHint(row: row, slot: slot) : nil)
                .frame(width: m.cellW, height: m.pitch)
        }
    }

    /// Hint for one key of a played row (computed by the core, never here).
    /// nil unless the player revealed that row with the hint button: the lip
    /// stays off and VoiceOver does not read it.
    private func slotHint(row: Int, slot: Int) -> DecoderSlotHint? {
        guard let all = game.visibleSlotHints(row: row), all.indices.contains(slot) else { return nil }
        return all[slot]
    }

    private func previewValue(previewing: Bool, placed: Int?, taken: Int?) -> String {
        guard previewing, placed != wheelColor else { return "" }
        if let taken {
            return AppLanguage.text("Vista previa: \(decoderName(wheelColor)), ya está en la casilla \(taken + 1), no se puede colocar",
                                    "Preview: \(decoderName(wheelColor)), already in slot \(taken + 1), cannot be placed")
        }
        return AppLanguage.text("Vista previa: \(decoderName(wheelColor))", "Preview: \(decoderName(wheelColor))")
    }

    private func rowLabel(_ row: Int) -> String {
        guard row < game.guesses.count else {
            if row >= game.maxAttempts {
                return AppLanguage.text("Intento \(row + 1), no disponible en este nivel", "Attempt \(row + 1), not available on this level")
            }
            return row == game.attemptsUsed && !game.isFinished
                ? AppLanguage.text("Intento \(row + 1), en curso", "Attempt \(row + 1), in progress")
                : AppLanguage.text("Intento \(row + 1), sin usar", "Attempt \(row + 1), unused")
        }
        // Each key WITH its own hint, then the totals.
        let keys = (0..<DecoderRules.slots).map { slot -> String in
            let name = decoderName(game.guesses[row][slot])
            guard let hint = slotHint(row: row, slot: slot) else { return name }
            return name + " " + hintSpeech(hint)
        }
        return AppLanguage.text("Intento \(row + 1): ", "Attempt \(row + 1): ")
            + keys.joined(separator: "; ")
            + ". " + feedbackSpeech(game.feedbacks[row])
    }

    /// Black band under the panel, WIDER than the green body. It is passive (no
    /// taps, no selection highlight): it shows the colours in play in this game,
    /// or, once the game is LOST, the solution (the 4 colours of the code, in
    /// order, after a small key glyph). Decoder/Kaffa mark on the right.
    private func strip(_ m: DeviceMetrics) -> some View {
        let lost = game.status == .lost && game.isPlayable
        let shown: [DecoderColor] = lost
            ? game.secret.compactMap { DecoderColor(rawValue: $0) }
            : DecoderColor.palette(count: colorCount)
        let region = m.stripW * 0.58
        let cellWidth = min(region / CGFloat(max(shown.count, 1)), 34)
        let names = shown.map { "\($0.localizedName) \($0.number)" }.joined(separator: ", ")
        let bandSpeech = lost
            ? AppLanguage.text("Solución, en orden: \(names)", "Solution, in order: \(names)")
            : AppLanguage.text("Colores activos en esta partida: \(names)", "Colours in play in this game: \(names)")
        return HStack(spacing: 0) {
            if let notice {
                // A warning takes the whole band for a few seconds (as on the Watch).
                Text(notice)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color(red: 0.62, green: 0.13, blue: 0.08))
                    .multilineTextAlignment(.center)
                    .lineLimit(2).minimumScaleFactor(0.7)
                    .frame(maxWidth: .infinity)
                    .transition(.opacity)
            } else {
                if lost {
                    Image(systemName: "key.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(DM.creamInk)
                        .frame(width: 18)
                }
                ForEach(Array(shown.enumerated()), id: \.offset) { _, c in
                    StripLight(color: c, width: min(lost ? 24 : 20, cellWidth - 4), height: 18)
                        .frame(width: cellWidth, height: m.stripH)
                }
                Spacer(minLength: 4)
                VStack(alignment: .trailing, spacing: 0) {
                    Text("DECODER").font(.system(size: 11, weight: .heavy, design: .monospaced)).tracking(1.6)
                        .foregroundStyle(DM.creamInk)
                    Text("Kuizzy · MHz").font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .foregroundStyle(DM.creamInk.opacity(0.65))
                }
                .lineLimit(1).minimumScaleFactor(0.6)
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: notice)
        .padding(.horizontal, 10)
        .frame(width: m.stripW, height: m.stripH)
        .background {
            // Cristal del dial: crema retroiluminado con la escala de frecuencias arriba.
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(LinearGradient(colors: [DM.cream, DM.cream.opacity(0.82)], startPoint: .top, endPoint: .bottom))
                .overlay(alignment: .top) {
                    HStack(spacing: 0) {
                        ForEach(0..<41, id: \.self) { i in
                            Rectangle().fill(DM.creamInk.opacity(i % 5 == 0 ? 0.6 : 0.3))
                                .frame(width: 1, height: i % 5 == 0 ? 7 : 4)
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                    }
                    .padding(.horizontal, 6)
                }
                .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(Color.black.opacity(0.55), lineWidth: 2))
        }
        .shadow(color: .black.opacity(0.35), radius: 3, y: 2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(notice.map { $0 + ". " + bandSpeech } ?? bandSpeech)
        .accessibilityIdentifier(notice != nil ? "decoder.notice" : (lost ? "decoder.strip.solution" : "decoder.strip.colors"))
    }

    private func bottomZone(_ m: DeviceMetrics) -> some View {
        let role = knobRole
        return HStack(alignment: .center, spacing: 0) {
            DeviceCounter(m: m,
                          value: mode == .entry ? game.attemptsUsed : (role == .level ? pickLevel : infRound.level),
                          caption: mode == .entry ? AppLanguage.text("INTENTOS", "ATTEMPTS") : AppLanguage.text("NIVEL", "LEVEL"),
                          speech: modeSpeech)
                .padding(.leading, m.panelLeft + 8 * m.s)
            Spacer(minLength: 4)
            hintButton(m)
            Spacer(minLength: 4)
            knob(m, role: role)
                .padding(.trailing, 28 * m.s)
        }
        .frame(width: m.bodyW, height: m.bottomH)
    }

    /// The HINT button: lights the lips of the LAST submitted row (core rule)
    /// and persists the reveal. Always visible, in every mode.
    private func hintButton(_ m: DeviceMetrics) -> some View {
        let ready = knobRole == .color && game.canRevealHint
        return Button { revealHint() } label: {
            DeviceHintButton(size: max(54 * m.s, 44), ready: ready, caption: AppLanguage.text("PISTA", "HINT"))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(AppLanguage.text("Pista", "Hint"))
        .accessibilityValue(ready ? "" : AppLanguage.text("No disponible", "Not available"))
        .accessibilityHint(AppLanguage.text("Enciende los pilotos del último intento enviado", "Lights the pilots of the last submitted attempt"))
        .accessibilityIdentifier("decoder.hint")
    }

    /// ONE knob instance for every role (stable identity: a touch that is still
    /// down when the role changes stays inert instead of becoming a new tap).
    private func knob(_ m: DeviceMetrics, role: KnobRole) -> some View {
        let picking = role == .level
        let taken = blocked[wheelColor]
        let colourValue = taken.map {
            decoderName(wheelColor) + AppLanguage.text(". Ya está en la casilla \($0 + 1); no se puede repetir.",
                                                       ". Already in slot \($0 + 1); colours cannot repeat.")
        } ?? decoderName(wheelColor)
        return DecoderKnobView(
            position: picking
                ? Binding(get: { pickLevel }, set: { pickLevel = DecoderInfinite.clampPick($0, best: infBest) })
                : Binding(get: { wheel }, set: { wheel = $0 }),
            detents: picking ? DecoderRules.maxColors : colorCount,
            range: picking ? 1...max(1, infBest) : nil,
            role: role.rawValue,
            diameter: m.knobD,
            showDots: !picking,
            enabled: role != .idle,
            label: picking ? AppLanguage.text("Mando: selector de nivel", "Knob: level selector")
                           : AppLanguage.text("Mando de color", "Colour knob"),
            value: picking ? AppLanguage.text("Nivel \(pickLevel) de \(infBest), \(DecoderInfinite.colorCount(level: pickLevel)) colores, \(DecoderInfinite.maxAttempts(level: pickLevel)) intentos",
                                              "Level \(pickLevel) of \(infBest), \(DecoderInfinite.colorCount(level: pickLevel)) colours, \(DecoderInfinite.maxAttempts(level: pickLevel)) attempts")
                           : (role == .idle ? AppLanguage.text("Partida terminada", "Game over") : colourValue),
            hint: picking
                ? AppLanguage.text("Desliza arriba o abajo para cambiar de nivel. Toca dos veces para empezarlo con un código nuevo.",
                                   "Swipe up or down to change level. Double-tap to start it with a new code.")
                : AppLanguage.text("Desliza arriba o abajo para cambiar de color. Toca dos veces para colocarlo. Mantén pulsado para enviar el intento.",
                                   "Swipe up or down to change colour. Double-tap to place it. Touch and hold to submit the attempt."),
            holdActionName: picking ? AppLanguage.text("Empezar nivel", "Start level")
                                    : AppLanguage.text("Enviar intento", "Submit attempt"),
            onDetent: { haptics.detent() },
            onTouchStart: { haptics.prepare() },
            onPress: { if picking { startPickedLevel() } else { place(wheelColor) } },
            // HOLD = submit, only while a game is being played. With no hold
            // handler (level selector) a long touch is just a tap.
            onLongPress: role == .color ? { submit() } : nil)
    }

    // MARK: Status + finished

    /// Text only. There is no "next / retry / new game" button: in Infinito the
    /// knob picks and starts the level; a finished Diario/Práctica game stays as
    /// it is. After a loss the solution is in the black band.
    private var finishedPlate: some View {
        Text(finishedText)
            .font(.system(.body, design: .monospaced).weight(.bold))
            .foregroundStyle(DM.plateInk)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12).padding(.vertical, 9)
            .background(DM.plate, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .accessibilityIdentifier("decoder.finished")
    }

    private var finishedText: String {
        if mode == .entry {
            return game.status == .won
                ? AppLanguage.text("¡Código descifrado en \(game.attemptsUsed)!", "Code cracked in \(game.attemptsUsed)!")
                : AppLanguage.text("Sin intentos. La solución está en la franja negra.", "Out of attempts. The solution is in the black band.")
        }
        return game.status == .won
            ? AppLanguage.text("¡Nivel \(infRound.level) superado en \(game.attemptsUsed)! Elige nivel con el mando.",
                               "Level \(infRound.level) cleared in \(game.attemptsUsed)! Choose a level with the knob.")
            : AppLanguage.text("Sin intentos en el nivel \(infRound.level). La solución está en la franja negra. Tu máximo (\(infBest)) no baja.",
                               "Out of attempts on level \(infRound.level). The solution is in the black band. Your highest (\(infBest)) never goes down.")
    }

    // MARK: Actions

    /// Tapping a key of the current row selects it. If it already holds a colour
    /// the knob moves to that colour, so the preview starts as what is there.
    private func selectSlot(_ slot: Int) {
        guard knobRole == .color else { return }
        var d = draft; d.select(slot); draft = d
        if let held = d.slots[slot] {
            wheel = DecoderWheel.nearest(current: wheel, target: held, count: colorCount)
        }
        haptics.slot()
        persistActive()
    }

    /// The ONLY path that writes a colour into the draft. The core decides
    /// whether it is legal; here a refusal becomes visible, spoken and felt.
    private func place(_ color: Int) {
        guard knobRole == .color else { return }
        switch draft.place(color) {      // computed property: get, mutate, set back
        case .placed, .unchanged:
            haptics.place()
            setNotice(nil)
            persistActive()
        case .duplicate(let c, let slot):
            reject(color: c, heldBy: slot)
        case .invalid:
            haptics.error()
        }
    }

    private func reject(color: Int, heldBy slot: Int) {
        haptics.reject()
        let text = AppLanguage.text("\(decoderName(color)) ya está en la casilla \(slot + 1). Los colores no se repiten.",
                                    "\(decoderName(color)) is already in slot \(slot + 1). Colours can't repeat.")
        setNotice(text)
        announce(text)
        if !reduceMotion { withAnimation(.linear(duration: 0.4)) { shake += 1 } }
        flashSlot = slot
        flashTask?.cancel()
        flashTask = Task { @MainActor in
            do { try await Task.sleep(for: .milliseconds(900)) } catch { return }
            flashSlot = nil
        }
    }

    /// Shows a warning in the black band and clears it after a few seconds.
    /// Callers announce it to VoiceOver (`announce`) at the same time.
    private func setNotice(_ text: String?) {
        noticeTask?.cancel()
        notice = text
        guard text != nil else { return }
        noticeTask = Task { @MainActor in
            do { try await Task.sleep(for: .seconds(Self.noticeSeconds)) } catch { return }
            notice = nil
        }
    }
    private static let noticeSeconds = 3.5

    /// Accessibility action "Vaciar casilla" on the keys of the current row.
    /// (Sighted play needs no clear: select the key and place another colour.)
    private func clearSlot(_ slot: Int) {
        guard knobRole == .color else { return }
        var d = draft; d.select(slot); d.clearSelected(); draft = d
        haptics.clear()
        setNotice(nil)
        announce(AppLanguage.text("Casilla \(slot + 1) vacía", "Slot \(slot + 1) empty"))
        persistActive()
    }

    /// HOLD on the knob (or the VoiceOver action "Enviar intento"). Every path
    /// is felt the moment the hold is recognised: the submit pattern, win/loss,
    /// or the warning when the row is not complete.
    private func submit() {
        guard knobRole == .color else { return }
        guard let code = draft.code else {
            haptics.warning()
            if !reduceMotion { withAnimation(.linear(duration: 0.4)) { shake += 1 } }
            let text = AppLanguage.text("Faltan casillas: llena las 4 antes de mantener pulsado el mando",
                                        "Slots missing: fill all 4 before holding the knob")
            setNotice(text)
            announce(text)
            return
        }
        var next = game
        guard case .accepted(let feedback) = next.submit(code) else { haptics.error(); return }
        game = next
        var d = draft; d.reset(); draft = d
        setNotice(nil)
        if mode == .entry {
            store.save(next)
            if next.isFinished {
                haptics.stop()
                finish()
            } else {
                haptics.submit(feedback)
                announce(AppLanguage.text("Intento \(next.attemptsUsed): ", "Attempt \(next.attemptsUsed): ") + feedbackSpeech(feedback))
            }
        } else {
            submitInfinite(next, feedback: feedback)
        }
    }

    /// Pressing HINT. The core decides what is revealed (last row only, once).
    private func revealHint() {
        guard knobRole == .color else { haptics.warning(); return }
        var next = game
        switch next.revealHint() {
        case .revealed(let row):
            game = next
            if mode == .entry { store.save(next) } else { saveInfinite() }
            haptics.place()
            setNotice(nil)
            let keys = (0..<DecoderRules.slots).map { slot -> String in
                let name = decoderName(next.guesses[row][slot])
                guard let hint = next.visibleSlotHints(row: row)?[slot] else { return name }
                return name + " " + hintSpeech(hint)
            }
            announce(AppLanguage.text("Pista del intento \(row + 1): ", "Hint for attempt \(row + 1): ") + keys.joined(separator: "; "))
        case .alreadyRevealed(let row):
            haptics.warning()
            let text = AppLanguage.text("La pista del intento \(row + 1) ya está encendida", "The hint for attempt \(row + 1) is already on")
            setNotice(text); announce(text)
        case .noRow:
            haptics.warning()
            let text = AppLanguage.text("Envía un intento antes de pedir pista", "Submit an attempt before asking for a hint")
            setNotice(text); announce(text)
        case .finished:
            haptics.warning()
        }
    }

    // MARK: Entry game (Diario / Práctica)

    private func restore() {
        guard !loaded else { return }
        loaded = true
        let restored = store.load(id: initial.id, secret: initial.secret)
        entry.game = restored
        entry.draft = DecoderDraft(colorCount: restored.colorCount)
        entry.elapsed = progress.elapsed(initial.id)
        #if DEBUG
        applyFixture()
        #endif
        if restored.isFinished { settleSilently() }
        #if DEBUG
        configureInfinitePreview()
        #endif
    }

    /// Terminal state reached while playing: record once, then celebrate/console.
    private func finish() {
        let first = settleSilently()
        if game.status == .won { haptics.win() } else { haptics.loss() }
        let stats = store.stats
        let used = game.attemptsUsed
        let time = PuzzleTiming.clock(TimeInterval(elapsed))
        let rows = game.feedbacks.map { f in
            String(repeating: "●", count: f.exact) + String(repeating: "○", count: f.misplaced)
                + String(repeating: "·", count: DecoderRules.slots - f.exact - f.misplaced)
        }.joined(separator: "\n")
        let solution = game.secret.map { decoderName($0) }.joined(separator: " · ")
        let won = game.status == .won
        result = PZResult(
            kind: .decoder, didWin: won,
            headline: won ? AppLanguage.text("¡Código descifrado!", "Code cracked!") : AppLanguage.text("Sin intentos", "Out of attempts"),
            detail: won
                ? AppLanguage.text("Lo has resuelto en \(used) de \(game.maxAttempts) intentos.", "You solved it in \(used) of \(game.maxAttempts) attempts.")
                : AppLanguage.text("El código era: \(solution).", "The code was: \(solution)."),
            metrics: [(AppLanguage.text("Intentos", "Attempts"), "\(used)/\(game.maxAttempts)"),
                      (AppLanguage.text("Tiempo", "Time"), time),
                      (AppLanguage.text("Victorias", "Wins"), "\(stats.wins)/\(stats.played)")],
            shareText: "Decoder \(won ? "\(used)" : "X")/\(game.maxAttempts)\n\(rows)")
        _ = first
        announce(won ? AppLanguage.text("Código descifrado", "Code cracked")
                     : AppLanguage.text("Sin intentos. El código era ", "Out of attempts. The code was ") + solution)
    }

    /// Idempotent bookkeeping shared by live finishes and restored terminal games.
    /// ENTRY GAME ONLY: Infinite never reaches PuzzleProgress.
    @discardableResult private func settleSilently() -> Bool {
        let g = entry.game
        let first = store.recordResultIfNew(g)
        if g.status == .won {
            progress.setElapsed(g.id, entry.elapsed)
            progress.recordTime(TimeInterval(max(5, entry.elapsed)), kind: .decoder, puzzleID: g.id)
            progress.markDone(g.id)
            progress.noteDayIfComplete()
        } else {
            progress.setElapsed(g.id, entry.elapsed)
        }
        return first
    }

    // MARK: Infinito

    /// Loads the stored ladder the first time Infinito is shown.
    private func ensureInfinite() {
        guard !infLoaded else { return }
        infLoaded = true
        adopt(infStore.load())
    }

    /// Takes the stored state as the truth and decides what the knob is: the
    /// level selector whenever no game is in progress (round over, or never
    /// begun), proposing the stored level (next after a win, same after a loss).
    private func adopt(_ session: DecoderInfiniteSession) {
        infRound = session.round
        infLevel = session.level
        infBest = session.best
        pickingLevel = session.round.isIdle
        pickLevel = DecoderInfinite.clampPick(session.level, best: session.best)
    }

    /// Writes the active round through the guarded store. The stored state wins
    /// if this view turns out to be stale.
    @discardableResult private func commitInfinite() -> DecoderInfiniteSaveOutcome {
        let saved = infStore.save(infRound)
        switch saved.outcome {
        case .saved:
            break
        case .cleared:
            infRound.isCleared = true
            infLevel = saved.session.level
            infBest = saved.session.best
        case .stale:
            adopt(saved.session)
        }
        return saved.outcome
    }

    /// The round just ended: the knob becomes the level selector, proposing the
    /// next level after a win (never beyond the best) and the same after a loss.
    private func openLevelSelector() {
        pickLevel = DecoderInfinite.clampPick(infLevel, best: infBest)
        pickingLevel = true
    }

    /// Autosave of a round in progress (never for finished/cleared rounds).
    private func saveInfinite() {
        guard infLoaded, !infRound.isCleared, !infRound.game.isFinished else { return }
        commitInfinite()
    }

    private func submitInfinite(_ next: DecoderGame, feedback: DecoderFeedback) {
        let outcome = commitInfinite()
        if outcome == .stale {
            haptics.warning()
            let text = AppLanguage.text("Este reto ya no es el actual; se ha recuperado el estado guardado.",
                                        "That round is no longer current; the saved state was restored.")
            setNotice(text); announce(text)
            return
        }
        if outcome == .cleared {
            haptics.stop()
            haptics.win()
            openLevelSelector()
            announce(AppLanguage.text("Nivel \(infRound.level) superado. Elige nivel con el mando.",
                                      "Level \(infRound.level) cleared. Choose a level with the knob."))
        } else if infRound.game.status == .lost {
            haptics.stop()
            haptics.loss()
            openLevelSelector()
            let solution = infRound.game.secret.map { decoderName($0) }.joined(separator: ", ")
            announce(AppLanguage.text("Sin intentos. La solución era \(solution). Elige nivel con el mando.",
                                      "Out of attempts. The solution was \(solution). Choose a level with the knob."))
        } else {
            haptics.submit(feedback)
            announce(AppLanguage.text("Intento \(next.attemptsUsed): ", "Attempt \(next.attemptsUsed): ") + feedbackSpeech(feedback))
        }
    }

    /// TAP on the knob while it is the level selector: starts the level shown on
    /// the counter with a NEW code. The store refuses it unless the round on
    /// screen is the stored one, no game is in progress and the level is
    /// unlocked; a refusal just resyncs with what is stored.
    private func startPickedLevel() {
        guard mode == .infinite, knobRole == .level else { return }
        flashTask?.cancel(); flashSlot = nil
        let target = DecoderInfinite.clampPick(pickLevel, best: infBest)
        if let session = infStore.start(level: target, expectedID: infRound.id) {
            adopt(session)
            pickingLevel = false                 // this round has been begun: the knob is colours now
            haptics.place()
            announce(AppLanguage.text("Nivel \(session.round.level), \(session.round.game.colorCount) colores, \(session.round.game.maxAttempts) intentos, código nuevo",
                                      "Level \(session.round.level), \(session.round.game.colorCount) colours, \(session.round.game.maxAttempts) attempts, new code"))
            setNotice(nil)
        } else {
            haptics.warning()
            adopt(infStore.load())
            let text = AppLanguage.text("No se pudo empezar ese nivel; se ha recuperado el estado guardado.",
                                        "That level could not be started; the saved state was restored.")
            setNotice(text); announce(text)
        }
    }

    // MARK: Persistence helpers

    private func persistActive() {
        if mode == .entry { progress.setElapsed(entry.game.id, entry.elapsed) }
        else { saveInfinite() }
    }

    private func persistAll() {
        progress.setElapsed(entry.game.id, entry.elapsed)
        saveInfinite()
    }

    private func announce(_ text: String) {
        UIAccessibility.post(notification: .announcement, argument: text)
    }

    #if DEBUG
    /// UI-only test fixture, accepted ONLY by the DEBUG games preview. A private
    /// suite keeps fake levels/guesses entirely away from real Infinite progress.
    private func configureInfinitePreview() {
        let env = ProcessInfo.processInfo.environment
        guard ["games", "decoder"].contains(env["GRID_PREVIEW"] ?? ""),
              let rawLevel = env["NR_DECODER_INFINITE_LEVEL"], let parsed = Int(rawLevel) else { return }
        let level = DecoderInfinite.clampLevel(parsed)
        let token = String((env["NR_DECODER_PREVIEW_TOKEN"] ?? "preview").filter {
            $0.isLetter || $0.isNumber || $0 == "-"
        }.prefix(40))
        guard let defaults = UserDefaults(suiteName: "kaffa.decoder.ui-preview.\(token).\(level)") else { return }
        previewInfiniteDefaults = defaults
        if defaults.object(forKey: DecoderInfiniteStore.key) == nil {
            defaults.set(["level": level], forKey: DecoderInfiniteStore.key)
        }
        let store = DecoderInfiniteStore(defaults: defaults)
        var session = store.load()
        if env["NR_DECODER_INFINITE_FIXTURE"] == "mid", session.round.game.guesses.isEmpty {
            var round = session.round
            for guess in DecoderGame.fixtureGuesses("mid", secret: round.game.secret, colors: round.game.colorCount) {
                round.game.submit(guess)
            }
            session = store.save(round).session
        }
        adopt(session)
        // NR_DECODER_INFINITE_FIXTURE=start: skip the level selector (as if the
        // knob had been tapped) so the colour-knob state can be captured.
        if env["NR_DECODER_INFINITE_FIXTURE"] == "start" { pickingLevel = false }
        infLoaded = true
        mode = .infinite
    }

    /// Verification aid (screenshots/UI tests): NR_DECODER_FIXTURE=mid|win|lose|dup
    /// (+ NR_DECODER_REVEAL=1 to reveal the hint of the last row).
    /// Plays real, legal guesses through the real rules; only applies to an untouched
    /// ENTRY board. `dup` also pre-fills slots 0 and 1 and tries to place a repeated
    /// colour, so the refusal state can be captured.
    private func applyFixture() {
        guard let name = ProcessInfo.processInfo.environment["NR_DECODER_FIXTURE"] else { return }
        var g = entry.game
        // NR_DECODER_REVEAL=1: same core call as the HINT button (capture of the lit state).
        let reveal = ProcessInfo.processInfo.environment["NR_DECODER_REVEAL"] == "1"
        guard g.guesses.isEmpty || reveal else { return }
        if g.guesses.isEmpty {
            for row in DecoderGame.fixtureGuesses(name == "dup" ? "mid" : name, secret: g.secret, colors: g.colorCount) { g.submit(row) }
        }
        if reveal { g.revealHint() }
        entry.game = g
        store.save(g)
        if name == "dup" && !g.isFinished {
            var d = entry.draft
            d.place(0); d.place(3)
            entry.draft = d
            entry.wheel = 0
            place(0)       // refused: red is already in slot 1
        }
    }
    #endif
}
#endif

#if os(iOS)
//
//  PuzzleDesignSystem.swift — News Raider
//  Shared visual tokens. Born in the Juegos tab, now the single source of
//  truth for the whole app so no screen invents its own spacing, radii,
//  type ramp or palette.
//

import SwiftUI
import UIKit

// MARK: - Hardware keyboard

/// UIKit first-responder bridge for custom game boards. `onKeyPress` only
/// fires while SwiftUI's focus engine happens to keep the board focused; on
/// iPad a tapped Button commonly takes that focus. This responder stays in
/// the UIKit responder chain, so letters from a physical keyboard keep
/// reaching custom boards after touch interaction.
struct PZHardwareKey {
    let input: String
    let unmodifiedInput: String
    let modifiers: UIKeyModifierFlags
}

struct PZHardwareKeyCapture: UIViewRepresentable {
    let onKey: (PZHardwareKey) -> Bool

    func makeUIView(context: Context) -> KeyView {
        let view = KeyView()
        view.onKey = onKey
        return view
    }

    func updateUIView(_ uiView: KeyView, context: Context) {
        uiView.onKey = onKey
        uiView.claimFirstResponder()
    }

    final class KeyView: UIView {
        var onKey: ((PZHardwareKey) -> Bool)?

        override var canBecomeFirstResponder: Bool { true }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            claimFirstResponder()
        }

        func claimFirstResponder() {
            guard window != nil, !isFirstResponder else { return }
            DispatchQueue.main.async { [weak self] in
                guard let self, self.window != nil else { return }
                _ = self.becomeFirstResponder()
            }
        }

        override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
            var unhandled = Set<UIPress>()
            for press in presses {
                guard let key = press.key else {
                    unhandled.insert(press)
                    continue
                }
                let handled = onKey?(PZHardwareKey(
                    input: key.characters,
                    unmodifiedInput: key.charactersIgnoringModifiers,
                    modifiers: key.modifierFlags
                )) ?? false
                if !handled { unhandled.insert(press) }
            }
            if !unhandled.isEmpty { super.pressesBegan(unhandled, with: event) }
        }
    }
}

// MARK: - Spacing (4pt scale)

enum PZSpace {
    static let xxs: CGFloat = 2
    static let xs:  CGFloat = 4
    static let sm:  CGFloat = 8
    static let md:  CGFloat = 12
    static let lg:  CGFloat = 16
    static let xl:  CGFloat = 24
    static let xxl: CGFloat = 32
    static let screenH: CGFloat = 20
    static let cardPad: CGFloat = 16
    /// Gap between paragraphs of a long read.
    static let paragraph: CGFloat = 14
    /// Extra leading inside a serif paragraph, so body copy breathes like
    /// print instead of stacking at the system's UI leading.
    static let lead: CGFloat = 5
}

// MARK: - Radii

enum PZRadius {
    static let chip:  CGFloat = 10
    static let tile:  CGFloat = 14
    static let card:  CGFloat = 22
    static let hero:  CGFloat = 26
    static let sheet: CGFloat = 28
    static func rect(_ r: CGFloat) -> RoundedRectangle {
        RoundedRectangle(cornerRadius: r, style: .continuous)
    }
}

// MARK: - Type ramp
//
// Diseño «Noche» (docs/DISENO.md): sans del sistema en todo; el peso hace el
// trabajo que antes hacía la serif. Estilos relativos, así que siguen
// Dynamic Type.

enum PZFont {
    static let hero    = Font.largeTitle.weight(.bold)
    static let display = Font.title.weight(.bold)
    static let title   = Font.title3.weight(.semibold)
    static let section = Font.title3.weight(.bold)
    static let metric  = Font.system(.title2, design: .rounded).weight(.semibold)
    static let body    = Font.body
    static let chip    = Font.subheadline.weight(.semibold)
    static let label   = Font.caption.weight(.semibold)
    static let caption = Font.caption
    static let badge   = Font.caption2.weight(.bold)
    static let action  = Font.headline

    static let headline = Font.title2.weight(.bold)
    static let cardTitle = Font.headline
    static let rowTitle  = Font.callout.weight(.semibold)
    static let summary   = Font.subheadline
    static let lede = Font.body
    static let articleLead = Font.title3
    static let article     = Font.body
    static let articleTitle = Font.title.weight(.bold)
    static let footnote = Font.footnote
}

extension View {
    /// Uppercase eyebrow label with tracking. Reserved for eyebrows and dates.
    func pzLabelStyle() -> some View {
        self.font(PZFont.label)
            .textCase(.uppercase)
            .kerning(1.2)
            .foregroundStyle(PZColor.inkSecondary)
    }

    /// Same eyebrow, tinted — used where the label carries the section accent.
    func pzEyebrowStyle(_ color: Color = PZColor.accent) -> some View {
        self.font(PZFont.label)
            .textCase(.uppercase)
            .kerning(1.2)
            .foregroundStyle(color)
    }

    /// Tarjeta: superficie marina con borde de 1 pt, sin sombra.
    func pzCard(_ radius: CGFloat = PZRadius.card, fill: Color = PZColor.surface) -> some View {
        self.frame(maxWidth: .infinity, alignment: .leading)
            .background(fill)
            .clipShape(PZRadius.rect(radius))
            .overlay { PZRadius.rect(radius).stroke(PZColor.hairline, lineWidth: 1) }
    }

    /// The app's one action shape: accent label on an 8% wash inside a 1pt
    /// accent hairline. Never a saturated fill, so a button reads as a stamp on
    /// the paper rather than as chrome borrowed from another app.
    func pzPill(_ color: Color = PZColor.accent, wide: Bool = false) -> some View {
        self.font(PZFont.chip)
            .foregroundStyle(color)
            .padding(.horizontal, PZSpace.lg)
            .padding(.vertical, PZSpace.md - 2)
            .frame(maxWidth: wide ? .infinity : nil)
            .background(PZColor.wash(color), in: Capsule())
            .overlay { Capsule().strokeBorder(color.opacity(0.45), lineWidth: 1) }
    }

    /// La acción principal de una pantalla: cápsula rellena en azul claro.
    /// Una sola por pantalla; las demás usan `pzPill`.
    func pzPrimaryPill() -> some View {
        self.font(PZFont.action)
            .foregroundStyle(PZColor.onAccent)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 50)
            .background(PZColor.accent, in: Capsule())
    }
}

/// Insignia en cápsula con texto en mayúsculas: lavado y borde de su color.
/// Lleva siempre texto, así que el estado no depende solo del color.
struct PZCapsuleBadge: View {
    let text: String
    var color: Color = PZColor.accent

    var body: some View {
        Text(text)
            .font(PZFont.badge)
            .kerning(1.2)
            .textCase(.uppercase)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(PZColor.wash(color), in: Capsule())
            .overlay { Capsule().strokeBorder(color.opacity(0.55), lineWidth: 1) }
    }
}

/// 3pt rule that tops an editorial card — the accent appears as a line, never
/// as a saturated fill behind the copy.
struct PZAccentRule: View {
    var color: Color = PZColor.accent
    var body: some View {
        Rectangle().fill(color).frame(height: 3)
    }
}

/// 1pt hairline. The app's only divider: `Divider()` picks up the system's
/// blue-grey separator, which reads cold against the warm paper.
struct PZRule: View {
    var color: Color = PZColor.hairline
    var body: some View {
        Rectangle().fill(color).frame(height: 1)
    }
}

/// Glyph or numeral in accent on an 8% wash disc, ringed with a 1pt hairline.
/// The single badge shape for section marks, briefing ordinals and game icons.
struct PZWashBadge<Content: View>: View {
    var color: Color = PZColor.accent
    var size: CGFloat = 32
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .foregroundStyle(color)
            .frame(width: size, height: size)
            .background(PZColor.wash(color), in: Circle())
            .overlay { Circle().strokeBorder(color.opacity(0.25), lineWidth: 1) }
    }
}

// MARK: - Colour
//
// Diseño «Noche» (docs/DISENO.md): una sola apariencia, oscura. Los valores
// coinciden con `MurdokuTheme` para que toda la app sea la misma mesa de juego.
// El color señala (icono, insignia, marca); el azul claro es la acción principal.

enum PZColor {
    static var canvas: Color { LiquidDesign.canvas }
    static let surface  = Color(light: "1B2233", dark: "1B2233")
    static let fill     = Color(light: "242C40", dark: "242C40")
    static let hairline = Color(light: "2C3650", dark: "2C3650")
    static let ink          = Color(light: "F4F6FB", dark: "F4F6FB")
    static let inkSecondary = Color(light: "8E97AB", dark: "8E97AB")
    /// Non-text furniture only (chevrons, disabled marks) — below AA on purpose.
    static let inkTertiary  = Color(light: "5E6880", dark: "5E6880")

    /// Acción principal. Contraste con `onAccent`: 9,8:1.
    static let accent = Color(light: "8FC2F2", dark: "8FC2F2")
    static let onAccent = Color(light: "10141D", dark: "10141D")
    static var accentWash: Color { wash(accent) }
    /// Lavado de cualquier tinta. 14 %: sobre marino, menos no se distingue.
    static func wash(_ color: Color) -> Color { color.opacity(0.14) }

    static let success  = Color(light: "5FD0B0", dark: "5FD0B0")
    static let warning  = Color(light: "F2B95C", dark: "F2B95C")
    static let danger   = Color(light: "F0766B", dark: "F0766B")

    /// Wordle states — `present` is deliberately darker than `correct`
    /// so the two stay separable in greyscale.
    static let wCorrect = Color(light: "2F5D50", dark: "4C8877")
    static let wPresent = Color(light: "B26A1F", dark: "D3913F")
    static let wAbsent  = Color(light: "B8B5AE", dark: "4A4A50")
}

// MARK: - Section inks
//
// One ink per news section, in the same desaturated print register as the
// puzzle accents (`PZ`). A section ink only ever appears as an eyebrow, a 3pt
// rule, a badge glyph or an 8% wash — never as a filled band behind copy.
// Every value clears 4.5:1 against `PZColor.surface` in its own appearance.

enum PZSection {
    private static let inks: [String: Color] = [
        "España":                      Color(light: "A8342A", dark: "E08072"),
        "Unión Europea":               Color(light: "2C4A7C", dark: "8FB0E0"),
        "Irán y Oriente Medio":        Color(light: "8A5A2B", dark: "C79A63"),
        "Ucrania":                     Color(light: "7A6A1F", dark: "C4B267"),
        "Mundo":                       Color(light: "2F5D50", dark: "6FA593"),
        "Beasain, Goierri y Gipuzkoa": Color(light: "4A3F7A", dark: "9E93D6"),
        "Deportes":                    Color(light: "B2591F", dark: "E09055"),
        "Economía":                    Color(light: "1F5F73", dark: "5FA3B8"),
        "Sucesos":                     Color(light: "7C2D3E", dark: "C97C8D"),
        "Comics":                      Color(light: "8A3A6B", dark: "C983AF"),
    ]

    /// Ink for a section id. "all", "General" and anything unmapped fall back
    /// to the house accent, so a new RSS category degrades quietly.
    static func color(_ id: String) -> Color { inks[id] ?? PZColor.accent }
}

extension Color {
    /// Hex pair so the palette reads the same as the design tokens.
    init(light: String, dark: String) {
        self.init(uiColor: UIColor { trait in
            UIColor(hex: trait.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

extension UIColor {
    convenience init(hex: String) {
        var value: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&value)
        self.init(red:   CGFloat((value & 0xFF0000) >> 16) / 255,
                  green: CGFloat((value & 0x00FF00) >> 8) / 255,
                  blue:  CGFloat(value & 0x0000FF) / 255,
                  alpha: 1)
    }
}

// MARK: - Navigation chrome

enum PZChrome {
    /// Serif navigation titles in ink, so the bar belongs to the same
    /// publication as the content under it. Applied once at launch; only the
    /// text attributes are touched, the (Liquid Glass) backgrounds stay
    /// whatever the system gives us.
    static func applyNavigationAppearance() {
        let bar = UINavigationBar.appearance()
        func styled(_ appearance: UINavigationBarAppearance) -> UINavigationBarAppearance {
            appearance.largeTitleTextAttributes = [
                .font: serif(.largeTitle, weight: .bold),
                .foregroundColor: UIColor(PZColor.ink),
            ]
            appearance.titleTextAttributes = [
                .font: serif(.headline, weight: .semibold),
                .foregroundColor: UIColor(PZColor.ink),
            ]
            return appearance
        }
        bar.standardAppearance = styled(bar.standardAppearance)
        bar.scrollEdgeAppearance = styled(bar.scrollEdgeAppearance ?? {
            let a = UINavigationBarAppearance()
            a.configureWithTransparentBackground()
            return a
        }())
        bar.compactAppearance = bar.compactAppearance.map(styled)
    }

    /// New York at the default size for `style`, still scaled by UIFontMetrics
    /// so navigation titles keep following Dynamic Type.
    private static func serif(_ style: UIFont.TextStyle, weight: UIFont.Weight) -> UIFont {
        let base = UIFont.preferredFont(forTextStyle: style,
                                        compatibleWith: UITraitCollection(preferredContentSizeCategory: .large))
        let system = UIFont.systemFont(ofSize: base.pointSize, weight: weight)
        guard let descriptor = system.fontDescriptor.withDesign(.serif) else { return system }
        return UIFontMetrics(forTextStyle: style)
            .scaledFont(for: UIFont(descriptor: descriptor, size: base.pointSize))
    }
}

// MARK: - Animation

enum PZAnim {
    static let toast   = Animation.spring(duration: 0.28)
    static let reveal  = Animation.snappy(duration: 0.35)
    static let shuffle = Animation.snappy(duration: 0.45)
    static let fill    = Animation.spring(response: 0.4, dampingFraction: 0.8)
}

// MARK: - Haptics

enum PZHaptics {
    static func tick()    { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func warning() { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
    static func error()   { UINotificationFeedbackGenerator().notificationOccurred(.error) }
    static func win() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        Task {
            try? await Task.sleep(nanoseconds: 180_000_000)
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
    }
}

// MARK: - Stat

/// Label over value, used in game status bars.
struct PZStat: View {
    let label: String
    let value: String
    var alignment: HorizontalAlignment = .leading

    var body: some View {
        VStack(alignment: alignment, spacing: PZSpace.xxs) {
            Text(label).pzLabelStyle()
            Text(value)
                .font(PZFont.metric)
                .monospacedDigit()
                .foregroundStyle(PZColor.ink)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}

// MARK: - Shake

/// Horizontal shake used to reject an invalid guess.
struct ShakeEffect: GeometryEffect {
    var animatableData: CGFloat
    var shakes: CGFloat = 3
    var amplitude: CGFloat = 8

    func effectValue(size: CGSize) -> ProjectionTransform {
        let offset = amplitude * sin(animatableData * .pi * shakes * 2)
        return ProjectionTransform(CGAffineTransform(translationX: offset, y: 0))
    }
}

// MARK: - Hint button

/// Shared hint affordance: a bulb that reveals part of the solution and adds
/// a time penalty. Every game routes its own "give me something" action
/// through here so the cost and the wording stay identical across the tab.
struct PZHintButton: View {
    @AppStorage(AppLanguage.storageKey) private var languageSelection = "system"
    /// Seconds added to the clock each time a hint is taken.
    static let penalty = 120

    let kind: PuzzleKind
    var isAvailable: Bool = true
    var used: Int = 0
    let action: () -> Void

    @State private var confirming = false

    var body: some View {
        Button {
            guard isAvailable else { return }
            confirming = true
        } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: isAvailable ? "lightbulb.fill" : "lightbulb")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(isAvailable ? PZ.color(kind) : PZColor.inkTertiary)
                    .frame(width: 40, height: 40)
                    .background(isAvailable ? PZColor.wash(PZ.color(kind)) : .clear, in: Circle())
                if used > 0 {
                    Text("\(used)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(3)
                        .background(PZColor.danger, in: Circle())
                        .offset(x: 3, y: -1)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(!isAvailable)
        .accessibilityLabel(AppLanguage.text("Pista", "Hint"))
        .accessibilityHint(isAvailable
                           ? AppLanguage.text("Revela parte de la solución y suma dos minutos", "Reveals part of the solution and adds two minutes")
                           : AppLanguage.text("No queda nada que revelar", "Nothing left to reveal"))
        .confirmationDialog(AppLanguage.text("¿Usar una pista?", "Use a hint?"),
                            isPresented: $confirming, titleVisibility: .visible) {
            Button(AppLanguage.text("Revelar (+2 min)", "Reveal (+2 min)")) {
                action()
                PZHaptics.warning()
            }
            Button(AppLanguage.text("Cancelar", "Cancel"), role: .cancel) { }
        } message: {
            Text(AppLanguage.text("Se revelará parte de la solución y se sumarán 2 minutos a tu tiempo.", "Part of the solution will be revealed and 2 minutes added to your time."))
        }
    }
}

// MARK: - Definitions

/// Wraps the system dictionary. iOS ships `UIReferenceLibraryViewController`,
/// so looking a word up needs no bundled data and no network — but it is a
/// *lookup*, not a corpus: you can ask about a term, you cannot enumerate it.
/// That is why the puzzles keep their own word lists for generating and
/// validating, and use this only to explain a word once it has been solved.
struct PZDefinitionView: View {
    let term: String
    var body: some View {
        if AppLanguage.current == .english {
            VStack(alignment: .leading, spacing: PZSpace.md) {
                Text(term.capitalized).font(PZFont.title)
                Text(EnglishPuzzleLexicon.cluePairs.first { $0.0 == term.uppercased() }?.1
                     ?? "No definition is included for this word.")
            }
            .padding(PZSpace.xl)
            .presentationDetents([.medium])
        } else {
            PZSystemDefinitionView(term: term)
        }
    }
}

private struct PZSystemDefinitionView: UIViewControllerRepresentable {
    let term: String

    func makeUIViewController(context: Context) -> UIReferenceLibraryViewController {
        UIReferenceLibraryViewController(term: term)
    }

    func updateUIViewController(_ controller: UIReferenceLibraryViewController,
                                context: Context) {}
}

/// Identifiable wrapper so a word can drive `.sheet(item:)`. Conforming
/// `String` itself would leak a dubious global conformance into the module.
struct PZDefinitionTerm: Identifiable, Equatable {
    let word: String
    var id: String { word }
}

enum PZDictionary {
    /// Whether the system can define this word. Returns false when the user has
    /// no Spanish dictionary installed, which is why callers must treat a
    /// missing definition as normal rather than as an error.
    static func hasDefinition(for term: String) -> Bool {
        if AppLanguage.current == .english {
            return EnglishPuzzleLexicon.cluePairs.contains { $0.0 == term.uppercased() }
        }
        return UIReferenceLibraryViewController
            .dictionaryHasDefinition(forTerm: term.lowercased())
    }
}

/// Tappable solved word that opens its dictionary entry. Falls back to plain
/// text when the system has nothing to show, so the affordance never lies.
struct PZDefinableWord: View {
    @AppStorage(AppLanguage.storageKey) private var languageSelection = "system"
    let word: String
    var font: Font = PZFont.chip
    var tint: Color = PZColor.ink

    @State private var showsDefinition = false

    private var isDefinable: Bool { PZDictionary.hasDefinition(for: word) }

    var body: some View {
        Group {
            if isDefinable {
                Button { showsDefinition = true } label: {
                    HStack(spacing: 4) {
                        Text(word.lowercased())
                            .font(font)
                            .foregroundStyle(tint)
                        Image(systemName: "character.book.closed")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(tint.opacity(0.55))
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(word)
                .accessibilityHint(AppLanguage.text("Toca para ver la definición", "Tap to see the definition"))
            } else {
                Text(word.lowercased())
                    .font(font)
                    .foregroundStyle(tint)
            }
        }
        .sheet(isPresented: $showsDefinition) {
            PZDefinitionView(term: word.lowercased())
                .ignoresSafeArea()
        }
    }
}

/// Horizontal shake, used to reject an answer. `shakes` is animatable, so
/// bumping it by one replays the wobble — even for the same wrong word.
struct PZShake: GeometryEffect {
    var shakes: Int

    var animatableData: CGFloat {
        get { CGFloat(shakes) }
        set { shakes = Int(newValue) }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(
            CGAffineTransform(translationX: sin(CGFloat(shakes) * .pi * 4) * 8, y: 0))
    }
}
#endif

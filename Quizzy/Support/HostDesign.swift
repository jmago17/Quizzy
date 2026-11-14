import SwiftUI
import UIKit

// Equivalentes locales mínimos de los símbolos de Kaffa que usan los juegos
// (Shared/Views/NewDesign/LiquidDesignTokens.swift y PortadaHeader.swift, 944663d).
// Mismos nombres para no tocar el código de los juegos; sin sincronización,
// ajustes de apariencia ni localización .xcstrings. La fase 2 (rediseño) puede
// reemplazar este fichero entero.

enum LiquidDesign {
    static var canvas: Color { Color(uiColor: .systemGroupedBackground) }

    static func appBackground(_ scheme: ColorScheme) -> Color { canvas }

    /// En Kaffa el acento editorial es el AccentColor del catálogo.
    static func beanAccent(_ scheme: ColorScheme) -> Color { Color.accentColor }

    static func hairline(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 0x38/255, green: 0x35/255, blue: 0x2F/255)
                        : Color(red: 0xDE/255, green: 0xD9/255, blue: 0xD1/255)
    }
}

private struct LiquidSerifModifier: ViewModifier {
    @ScaledMetric private var size: CGFloat
    private let weight: Font.Weight
    private let italic: Bool

    init(size: CGFloat, weight: Font.Weight, relativeTo textStyle: Font.TextStyle, italic: Bool) {
        _size = ScaledMetric(wrappedValue: size, relativeTo: textStyle)
        self.weight = weight
        self.italic = italic
    }

    func body(content: Content) -> some View {
        let font = Font.system(size: size, weight: weight, design: .serif)
        content.font(italic ? font.italic() : font)
    }
}

extension View {
    func liquidSerif(_ size: CGFloat, weight: Font.Weight = .bold,
                     relativeTo textStyle: Font.TextStyle = .body, italic: Bool = false) -> some View {
        modifier(LiquidSerifModifier(size: size, weight: weight, relativeTo: textStyle, italic: italic))
    }
}

struct LiquidHairline: View {
    var opacity: Double = 1
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Rectangle()
            .fill(LiquidDesign.hairline(colorScheme).opacity(opacity))
            .frame(height: 1)
            .accessibilityHidden(true)
    }
}

/// Fondo de la app: el mismo lienzo teñido de Kaffa (base + degradado + brillo).
struct LiquidCanvasBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let bean = LiquidDesign.beanAccent(colorScheme)
        ZStack {
            LiquidDesign.appBackground(colorScheme)
            LinearGradient(
                colors: colorScheme == .dark
                    ? [bean.opacity(0.30), .clear, bean.opacity(0.16)]
                    : [bean.opacity(0.22), .clear, bean.opacity(0.14)],
                startPoint: .topLeading, endPoint: .bottomTrailing)
            RadialGradient(
                colors: [Color.white.opacity(colorScheme == .dark ? 0.08 : 0.55), .clear],
                center: .top, startRadius: 0, endRadius: 460)
        }
        .ignoresSafeArea()
    }
}

/// Cabecera serif de la raíz (título + saludo + detalle). Versión de Kaffa sin
/// estado de sincronización de iCloud.
struct PortadaHeader: View {
    @AppStorage(AppLanguage.storageKey) private var appLanguageSelection = "system"
    let title: LocalizedStringKey
    var userName: String = ""
    var horizontalPadding: CGFloat = 20
    var topPadding: CGFloat = 8
    var bottomPadding: CGFloat = 4
    var detail: String? = nil

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let _ = appLanguageSelection
        VStack(alignment: .leading, spacing: 4) {
            Rectangle()
                .fill(LiquidDesign.beanAccent(colorScheme))
                .frame(width: 34, height: 3)
                .clipShape(Capsule())
                .padding(.bottom, 6)
                .accessibilityHidden(true)
            Text(title)
                .liquidSerif(34, weight: .heavy, relativeTo: .largeTitle)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(eyebrowText)
                .liquidSerif(15, weight: .medium, relativeTo: .subheadline, italic: true)
                .foregroundStyle(.secondary)
            LiquidHairline()
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, horizontalPadding)
        .padding(.top, topPadding)
        .padding(.bottom, bottomPadding)
    }

    private var eyebrowText: String {
        let name = userName.trimmingCharacters(in: .whitespacesAndNewlines)
        let greeting = greetingForCurrentHour()
        let salutation = name.isEmpty ? greeting : "\(greeting), \(name)"
        if let detail, !detail.isEmpty { return "\(salutation) · \(detail)" }
        return salutation
    }

    private func greetingForCurrentHour() -> String {
        switch Calendar.current.component(.hour, from: Date()) {
        case 5..<12:  return AppLanguage.text("Buenos días", "Good morning")
        case 12..<21: return AppLanguage.text("Buenas tardes", "Good afternoon")
        default:      return AppLanguage.text("Buenas noches", "Good evening")
        }
    }
}

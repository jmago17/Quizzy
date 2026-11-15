import SwiftUI
import UIKit

// Anfitrión de los juegos: los símbolos que el código heredado de Kaffa espera
// (`LiquidDesign`, `LiquidCanvasBackground`, `liquidSerif`, `PortadaHeader`),
// con los mismos nombres pero ya en el diseño «Noche» de Quizzy
// (docs/DISENO.md): fondo marino liso y sans del sistema.

enum LiquidDesign {
    static var canvas: Color { Color(uiColor: UIColor(hex: "12151F")) }

    static func appBackground(_ scheme: ColorScheme) -> Color { canvas }

    static func beanAccent(_ scheme: ColorScheme) -> Color { PZColor.accent }

    static func hairline(_ scheme: ColorScheme) -> Color { PZColor.hairline }
}

private struct LiquidSerifModifier: ViewModifier {
    @ScaledMetric private var size: CGFloat
    private let weight: Font.Weight

    init(size: CGFloat, weight: Font.Weight, relativeTo textStyle: Font.TextStyle) {
        _size = ScaledMetric(wrappedValue: size, relativeTo: textStyle)
        self.weight = weight
    }

    func body(content: Content) -> some View {
        content.font(Font.system(size: size, weight: weight))
    }
}

extension View {
    /// Conserva el nombre de Kaffa; en Quizzy es sans del sistema y nunca cursiva.
    func liquidSerif(_ size: CGFloat, weight: Font.Weight = .bold,
                     relativeTo textStyle: Font.TextStyle = .body, italic: Bool = false) -> some View {
        modifier(LiquidSerifModifier(size: size, weight: weight, relativeTo: textStyle))
    }
}

struct LiquidHairline: View {
    var opacity: Double = 1

    var body: some View {
        Rectangle()
            .fill(PZColor.hairline.opacity(opacity))
            .frame(height: 1)
            .accessibilityHidden(true)
    }
}

/// Fondo de la app: marino liso, sin degradados.
struct LiquidCanvasBackground: View {
    var body: some View {
        LiquidDesign.canvas.ignoresSafeArea()
    }
}

/// Cabecera de la portada: título en heavy y, debajo, saludo y detalle en gris.
/// Sin barra de acento ni raya.
struct PortadaHeader: View {
    @AppStorage(AppLanguage.storageKey) private var appLanguageSelection = "system"
    let title: LocalizedStringKey
    var userName: String = ""
    var horizontalPadding: CGFloat = 20
    var topPadding: CGFloat = 8
    var bottomPadding: CGFloat = 4
    var detail: String? = nil

    var body: some View {
        let _ = appLanguageSelection
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .liquidSerif(34, weight: .heavy, relativeTo: .largeTitle)
                .foregroundStyle(PZColor.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(eyebrowText)
                .font(.subheadline)
                .foregroundStyle(PZColor.inkSecondary)
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

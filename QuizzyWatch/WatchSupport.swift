//
//  WatchSupport.swift — Quizzy Watch
//  Tokens, hápticos y piezas comunes de los juegos del reloj.
//  Colores = los de «Noche» (PuzzleDesignSystem / PuzzlesScreen), copiados como hex porque
//  aquellos ficheros dependen de UIKit y no se compilan en watchOS.
//

import SwiftUI
import Combine
import WatchKit

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }
}

enum WTheme {
    static let canvas = Color(hex: 0x12151F)
    static let surface = Color(hex: 0x1B2233)
    static let fill = Color(hex: 0x242C40)
    static let hairline = Color(hex: 0x2C3650)
    static let ink = Color(hex: 0xF4F6FB)
    static let inkSecondary = Color(hex: 0x8E97AB)
    static let inkTertiary = Color(hex: 0x5E6880)
    static let success = Color(hex: 0x5FD0B0)
    static let warning = Color(hex: 0xF2B95C)
    static let danger = Color(hex: 0xF0766B)
    static let wCorrect = Color(hex: 0x4C8877)
    static let wPresent = Color(hex: 0xD3913F)
    static let wAbsent = Color(hex: 0x4A4A50)

    static func color(_ kind: PuzzleKind) -> Color {
        switch kind {
        case .quartiles: return Color(hex: 0xD9604F)
        case .maze:      return Color(hex: 0x8377C0)
        case .wordle:    return Color(hex: 0x9BAA63)
        case .anygram:   return Color(hex: 0x3FD3C6)
        case .decoder:   return Color(hex: 0xD18A5E)
        default:         return Color(hex: 0x8FC2F2)
        }
    }
}

enum WHaptics {
    static func tick() { WKInterfaceDevice.current().play(.click) }
    static func success() { WKInterfaceDevice.current().play(.success) }
    static func error() { WKInterfaceDevice.current().play(.failure) }
    static func warning() { WKInterfaceDevice.current().play(.retry) }
    static func notch() { WKInterfaceDevice.current().play(.start) }
}

/// Ficha con el «volumen» de la app: degradado, brillo arriba y sombra corta.
struct WTile<Content: View>: View {
    var fill: Color = WTheme.fill
    var stroke: Color = WTheme.hairline
    var radius: CGFloat = 6
    @ViewBuilder var content: Content

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(LinearGradient(colors: [fill.opacity(1), fill.opacity(0.78)], startPoint: .top, endPoint: .bottom))
                    .overlay(alignment: .top) {
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .stroke(Color.white.opacity(0.10), lineWidth: 1)
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: radius, style: .continuous).stroke(stroke, lineWidth: 0.5)
                    }
                    .shadow(color: .black.opacity(0.35), radius: 1.5, y: 1)
            }
    }
}

/// Cronómetro de partida: suma segundos mientras la vista está activa y guarda cada 5 s,
/// con las mismas claves que el iPhone (`PuzzleProgress.elapsed`).
struct WClock: ViewModifier {
    let puzzleID: String
    let running: Bool
    @Binding var elapsed: Int
    @Environment(\.scenePhase) private var phase
    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    func body(content: Content) -> some View {
        content.onReceive(tick) { _ in
            guard running, phase == .active else { return }
            elapsed += 1
            if elapsed % 5 == 0 { PuzzleProgress.shared.setElapsed(puzzleID, elapsed) }
        }
    }
}

extension View {
    func wClock(_ id: String, running: Bool, elapsed: Binding<Int>) -> some View {
        modifier(WClock(puzzleID: id, running: running, elapsed: elapsed))
    }
}

/// Aviso corto que se borra solo (equivalente pequeño de `PZToast`).
struct WNotice: Equatable {
    enum Kind { case info, success, error }
    var text: String
    var kind: Kind
    var color: Color {
        switch kind {
        case .info: return WTheme.inkSecondary
        case .success: return WTheme.success
        case .error: return WTheme.danger
        }
    }
}

struct WNoticeText: View {
    @Binding var notice: WNotice?
    var body: some View {
        Text(notice?.text ?? " ")
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundStyle(notice?.color ?? .clear)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .task(id: notice) {
                guard notice != nil else { return }
                try? await Task.sleep(for: .seconds(2.2))
                notice = nil
            }
    }
}

/// Bloque de fin de partida: titular, detalle y "Otro".
struct WResultPanel: View {
    let kind: PuzzleKind
    let won: Bool
    let headline: String
    let detail: String
    let onAnother: () -> Void

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: won ? "checkmark.seal.fill" : "xmark.seal.fill")
                .font(.system(size: 30))
                .foregroundStyle(won ? WTheme.color(kind) : WTheme.danger)
            Text(headline).font(.system(.headline, design: .rounded)).multilineTextAlignment(.center)
            Text(detail).font(.footnote).foregroundStyle(WTheme.inkSecondary).multilineTextAlignment(.center)
            Button(AppLanguage.text("Jugar otro", "Play another"), action: onAnother)
                .tint(WTheme.color(kind))
                .padding(.top, 2)
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(WTheme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

func wTime(_ seconds: Int) -> String { PuzzleTiming.clock(TimeInterval(seconds)) }

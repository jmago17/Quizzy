#if os(iOS)
//
//  MurdokuCaseUI.swift — Quizzy
//  Tema y piezas sin estado de la pantalla de Murdoku (fase 2, rediseño).
//  La mecánica sigue en `MurdokuGame` (MurdleGame.swift); aquí solo hay
//  colores, medidas y vistas que reciben valores.
//

import SwiftUI

/// Único sitio para ajustar colores y medidas de Murdoku. La pantalla usa
/// siempre esta paleta oscura, sea cual sea la apariencia del sistema.
enum MurdokuTheme {
    private static func hex(_ value: String) -> Color { Color(uiColor: UIColor(hex: value)) }

    // Superficies
    static let background = hex("12151F")
    static let card = hex("1B2233")
    static let cardBorder = hex("2C3650")
    static let hairline = hex("2A3247")
    static let controlTrack = hex("1E2433")
    static let controlOn = hex("4B5265")
    static let disabledFill = hex("2A3040")

    // Texto
    static let text = hex("F4F6FB")
    static let textMuted = hex("8E97AB")
    static let onAccent = hex("10141D")

    // Acentos
    static let accent = hex("8FC2F2")
    static let coral = hex("F0766B")
    static let mark = hex("E0738C")
    static let badge = hex("5FD0B0")

    // Tablero
    static let boardGap = hex("1F2634")
    static let boardBorder = hex("B9C3D6")
    static let roomDivider = hex("AEBBD2")
    static let roomLabelFill = hex("1A1F2B")
    static let roomLabelText = hex("B4BED1")
    static let furnitureTint = hex("A9B8D0")
    static let furnitureLift = Color.white.opacity(0.13)
    static let focusLine = hex("C9DBF5")
    static let avatarPaper = hex("F4EEE2")
    static let rooms = ["3F5A4C", "3F5068", "4B4265", "5C5040", "5E4150"].map(hex)
    static let suspects = ["F2B95C", "5FD0B0", "8DB7F5", "B3A1F7", "F2798B"].map(hex)

    // Medidas
    static let twoColumnMinWidth: CGFloat = 900
    static let leftColumnFraction: CGFloat = 0.47
    static let columnGap: CGFloat = 56
    static let screenPadding: CGFloat = 16
    static let screenPaddingWide: CGFloat = 36
    static let sectionGap: CGFloat = 20
    static let controlGap: CGFloat = 12
    /// Alto que se reserva bajo el tablero (segmentado, fichas, botón, ayuda)
    /// para que en horizontal quepa todo sin desplazarse.
    static let controlsReserve: CGFloat = 300
    static let boardMaxSide: CGFloat = 560
    static let boardRadius: CGFloat = 14
    static let boardBorderWidth: CGFloat = 3
    static let cellGap: CGFloat = 2
    static let cellRadius: CGFloat = 2
    static let roomDividerWidth: CGFloat = 1.5
    static let cardRadius: CGFloat = 22
    static let cardPadding: CGFloat = 18
    static let chipRadius: CGFloat = 14
    static let minTarget: CGFloat = 44
    static let checkButtonHeight: CGFloat = 56
    static let stampAngle: Double = -5
}

/// Tarjeta oscura con borde fino.
struct MurdokuCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: MurdokuTheme.cardRadius, style: .continuous)
        content
            .padding(MurdokuTheme.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(MurdokuTheme.card, in: shape)
            .overlay { shape.strokeBorder(MurdokuTheme.cardBorder, lineWidth: 1) }
    }
}

/// El retrato que ya tenía el juego, dentro de un cuadrado redondeado con
/// el borde del color del sospechoso.
struct MurdokuAvatarTile: View {
    let index: Int
    let color: Color
    let size: CGFloat

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: size * 0.26, style: .continuous)
        MurdokuCharacterPortrait(index: index, framed: false)
            .environment(\.colorScheme, .light)
            .scaleEffect(size / 44 * 0.9)
            .frame(width: size, height: size)
            .background(MurdokuTheme.avatarPaper)
            .clipShape(shape)
            .overlay { shape.strokeBorder(color, lineWidth: max(1.5, size * 0.065)) }
            .accessibilityHidden(true)
    }
}

/// Insignia en cápsula (dificultad, «FUE»).
struct MurdokuBadge: View {
    let text: String
    var systemImage: String?
    var color: Color = MurdokuTheme.badge

    var body: some View {
        HStack(spacing: 5) {
            if let systemImage { Image(systemName: systemImage) }
            Text(text).tracking(1.2)
        }
        .font(.caption.weight(.bold))
        .foregroundStyle(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(color.opacity(0.12), in: Capsule())
        .overlay { Capsule().strokeBorder(color.opacity(0.65), lineWidth: 1) }
    }
}

/// Datos de la hoja «Caso cerrado»; los prepara `MurdokuGame`.
struct MurdokuClosedCase {
    let english: Bool
    let title: String
    let phrase: String
    let culprit: String
    let culpritIndex: Int
    let culpritColor: Color
    let culpritLines: [(icon: String, text: String)]
    let summary: [(icon: String, text: String)]
    let shareText: String
}

struct MurdokuClosedSheet: View {
    let model: MurdokuClosedCase

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var stamped = false
    @State private var showCelebration = false

    private func t(_ es: String, _ en: String) -> String { model.english ? en : es }
    private var next: PuzzleKind? { PuzzleProgress.shared.nextPending(after: .murdoku) }

    var body: some View {
        // Si cabe, la hoja se ajusta al contenido (iPad); si no, se desplaza.
        ViewThatFits(in: .vertical) {
            content
            ScrollView { content }.scrollIndicators(.hidden)
        }
        .environment(\.colorScheme, .dark)
        .presentationSizing(.form.fitted(horizontal: false, vertical: true))
        .presentationBackground(MurdokuTheme.background)
        .presentationCornerRadius(32)
        .overlay {
            if showCelebration {
                PZCelebrationView()
                    .allowsHitTesting(false)
                    .ignoresSafeArea()
                    .transition(.opacity)
            }
        }
        .onAppear {
            PZHaptics.win()
            if reduceMotion {
                stamped = true
                return
            }
            withAnimation(.spring(duration: 0.45, bounce: 0.35).delay(0.2)) { stamped = true }
            showCelebration = true
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(2.6))
                showCelebration = false
            }
        }
    }

    private var content: some View {
            VStack(spacing: 20) {
                Text(t("Caso cerrado", "Case closed"))
                    .font(.headline)
                    .foregroundStyle(MurdokuTheme.text)
                    .padding(.top, 4)
                stamp
                VStack(spacing: 10) {
                    Text(model.title)
                        .font(.title.weight(.semibold))
                        .foregroundStyle(MurdokuTheme.text)
                        .multilineTextAlignment(.center)
                        .accessibilityAddTraits(.isHeader)
                    Text(model.phrase)
                        .font(.body)
                        .foregroundStyle(MurdokuTheme.textMuted)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                culpritCard
                summaryCard
                actions
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 24)
            .frame(maxWidth: 620)
            .frame(maxWidth: .infinity)
    }

    private var stamp: some View {
        Text(t("CASO CERRADO", "CASE CLOSED"))
            .font(.title3.weight(.heavy))
            .tracking(3)
            .foregroundStyle(MurdokuTheme.coral)
            .padding(.horizontal, 22)
            .padding(.vertical, 10)
            .overlay {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(MurdokuTheme.coral, lineWidth: 3)
            }
            .rotationEffect(.degrees(MurdokuTheme.stampAngle))
            .scaleEffect(stamped ? 1 : 1.7)
            .opacity(stamped ? 1 : 0)
            .padding(.vertical, 10)
            .accessibilityHidden(true)
    }

    private var culpritCard: some View {
        MurdokuCard {
            VStack(alignment: .leading, spacing: 12) {
                MurdokuBadge(text: t("FUE", "IT WAS"), systemImage: "magnifyingglass", color: MurdokuTheme.coral)
                HStack(spacing: 12) {
                    MurdokuAvatarTile(index: model.culpritIndex, color: model.culpritColor, size: 56)
                    Text(model.culprit)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(model.culpritColor)
                }
                ForEach(Array(model.culpritLines.enumerated()), id: \.offset) { _, line in
                    Label(line.text, systemImage: line.icon)
                        .font(.subheadline)
                        .foregroundStyle(MurdokuTheme.textMuted)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var summaryCard: some View {
        MurdokuCard {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(model.summary.enumerated()), id: \.offset) { _, line in
                    Label(line.text, systemImage: line.icon)
                        .font(.body)
                        .foregroundStyle(MurdokuTheme.text)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var actions: some View {
        VStack(spacing: 6) {
            Button {
                PZPendingNav.request(.pzNewSameGame, PuzzleKind.murdoku.rawValue)
                dismiss()
            } label: {
                VStack(spacing: 2) {
                    Text(t("Siguiente caso", "Next case")).font(.title3.weight(.medium))
                    Text(t("Nuevo Murdoku", "New Murdoku")).font(.footnote)
                }
                .foregroundStyle(MurdokuTheme.onAccent)
                .frame(maxWidth: .infinity, minHeight: 64)
                .background(MurdokuTheme.accent, in: Capsule())
            }
            .buttonStyle(.plain)

            HStack(spacing: 8) {
                ShareLink(item: model.shareText) {
                    Label(t("Compartir resultado", "Share result"), systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity, minHeight: MurdokuTheme.minTarget)
                }
                if let next {
                    Button {
                        PZPendingNav.request(.pzOpenNextGame, next.rawValue)
                        dismiss()
                    } label: {
                        Label(t("Siguiente: \(next.title)", "Next: \(next.title)"), systemImage: "arrow.right")
                            .frame(maxWidth: .infinity, minHeight: MurdokuTheme.minTarget)
                    }
                }
            }
            .font(.subheadline.weight(.medium))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .foregroundStyle(MurdokuTheme.accent)
            .buttonStyle(.plain)
        }
        .onDisappear { PZPendingNav.flush() }
    }
}
#endif

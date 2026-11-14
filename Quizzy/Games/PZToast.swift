#if os(iOS)
//
//  PZToast.swift — News Raider
//  One semantic toast for every game (was duplicated byte-for-byte).
//

import SwiftUI

struct PZToast: Equatable, Identifiable {
    enum Kind { case success, error, info }
    let id = UUID()
    let text: String
    let kind: Kind

    var symbol: String {
        switch kind {
        case .success: return "checkmark.circle.fill"
        case .error:   return "xmark.circle.fill"
        case .info:    return "info.circle.fill"
        }
    }
    var tint: Color {
        switch kind {
        case .success: return PZColor.success
        case .error:   return PZColor.danger
        case .info:    return PZColor.inkSecondary
        }
    }
    static func == (a: PZToast, b: PZToast) -> Bool { a.id == b.id }
}

private struct PZToastModifier: ViewModifier {
    @Binding var toast: PZToast?
    @State private var task: Task<Void, Never>?

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if let t = toast {
                    HStack(spacing: PZSpace.sm) {
                        Image(systemName: t.symbol).foregroundStyle(t.tint)
                        Text(t.text).font(PZFont.chip).foregroundStyle(PZColor.ink)
                    }
                    .padding(.horizontal, PZSpace.lg)
                    .padding(.vertical, PZSpace.md)
                    .background(.regularMaterial, in: Capsule())
                    .overlay(Capsule().stroke(t.tint.opacity(0.25), lineWidth: 1))
                    .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
                    .padding(.bottom, PZSpace.sm)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .accessibilityAddTraits(.isStaticText)
                }
            }
            .animation(PZAnim.toast, value: toast)
            .onChange(of: toast) { _, new in
                task?.cancel()
                guard let new else { return }
                // Errors linger slightly longer than confirmations.
                let ns: UInt64 = new.kind == .error ? 1_600_000_000 : 1_300_000_000
                task = Task {
                    try? await Task.sleep(nanoseconds: ns)
                    guard !Task.isCancelled else { return }
                    await MainActor.run { if toast?.id == new.id { toast = nil } }
                }
                AccessibilityNotification.Announcement(new.text).post()
            }
    }
}

extension View {
    /// Unified semantic toast for all puzzle games.
    func pzToast(_ toast: Binding<PZToast?>) -> some View {
        modifier(PZToastModifier(toast: toast))
    }
}
#endif

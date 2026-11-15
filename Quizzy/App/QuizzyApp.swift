import SwiftUI

/// Quizzy: los juegos de Kaffa como app independiente.
/// Diseño «Noche» (docs/DISENO.md): una sola apariencia, oscura.
@main
struct QuizzyApp: App {
    @AppStorage(AppLanguage.storageKey) private var languageSelection = "system"
    @State private var showingSettings = false

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                PuzzlesScreen(onExit: nil, topBar: nil, headerAccessory: AnyView(settingsButton))
            }
            .sheet(isPresented: $showingSettings) { QuizzySettingsView() }
            .environment(\.locale, AppLanguage.resolve(languageSelection).locale)
            .tint(PZColor.accent)
            .preferredColorScheme(.dark)
        }
    }

    private var settingsButton: some View {
        Button { showingSettings = true } label: {
            Image(systemName: "gearshape")
                .font(.body.weight(.semibold))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .accessibilityLabel(AppLanguage.text("Ajustes", "Settings"))
    }
}

import SwiftUI

/// Quizzy: los juegos de Kaffa como app independiente (fase 1, extracción).
/// La raíz es la misma PuzzlesScreen de Kaffa, sin barra de colecciones.
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
        }
    }

    private var settingsButton: some View {
        Button { showingSettings = true } label: { Image(systemName: "gearshape") }
            .accessibilityLabel(AppLanguage.text("Ajustes", "Settings"))
    }
}

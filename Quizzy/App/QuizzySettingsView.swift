import SwiftUI

/// Ajustes locales de los juegos. Mismas claves de UserDefaults que usaba Kaffa
/// (`appLanguage`, `decoder.haptics.enabled`, `decoder.hdr.enabled`).
struct QuizzySettingsView: View {
    @AppStorage(AppLanguage.storageKey) private var languageSelection = "system"
    @AppStorage(DecoderHaptics.enabledKey) private var decoderHaptics = true
    @AppStorage("decoder.hdr.enabled") private var decoderHDR = true
    @Environment(\.dismiss) private var dismiss
    @State private var confirmingReset = false

    var body: some View {
        NavigationStack {
            Form {
                Section(AppLanguage.text("Idioma de los juegos", "Games language")) {
                    Picker(AppLanguage.text("Idioma", "Language"), selection: $languageSelection) {
                        Text(AppLanguage.text("Sistema", "System")).tag("system")
                        Text("Español").tag("es")
                        Text("English").tag("en")
                    }
                }
                Section("Decoder") {
                    Toggle(AppLanguage.text("Hápticos", "Haptics"), isOn: $decoderHaptics)
                    Toggle(AppLanguage.text("Luces HDR", "HDR lights"), isOn: $decoderHDR)
                }
                Section {
                    Button(AppLanguage.text("Borrar progreso y estadísticas", "Clear progress and statistics"),
                           systemImage: "trash", role: .destructive) { confirmingReset = true }
                } footer: {
                    Text(AppLanguage.text("Todo se guarda solo en este dispositivo.", "Everything is stored on this device only."))
                }
            }
            .navigationTitle(AppLanguage.text("Ajustes", "Settings"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(AppLanguage.text("Hecho", "Done")) { dismiss() }
                }
            }
            .confirmationDialog(AppLanguage.text("¿Borrar todo el progreso?", "Clear all progress?"),
                                isPresented: $confirmingReset, titleVisibility: .visible) {
                Button(AppLanguage.text("Borrar", "Clear"), role: .destructive) {
                    PuzzleProgress.shared.resetAllProgress()
                }
            }
        }
    }
}

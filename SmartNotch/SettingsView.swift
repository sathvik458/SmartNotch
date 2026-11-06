import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState

    private let models = [
        "gemini-2.5-flash-lite",
        "gemini-2.5-flash",
        "gemini-2.5-pro",
        "gemini-2.0-flash",
        "gemini-2.0-flash-lite",
        "gemini-flash-latest"
    ]

    var body: some View {
        Form {
            Section("Gemini") {
                SecureField("API key", text: $appState.geminiAPIKey)
                    .textFieldStyle(.roundedBorder)
                Picker("Model", selection: $appState.modelID) {
                    ForEach(models, id: \.self) { Text($0).tag($0) }
                }
            }
            Section("System prompt") {
                TextEditor(text: $appState.systemPrompt)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 110)
            }
            Section("Languages") {
                Picker("Answer", selection: $appState.answerLanguage) {
                    ForEach(["Japanese + Romaji + English", "Japanese", "English", "Romaji"], id: \.self) { Text($0).tag($0) }
                }
                Picker("Spoken language", selection: $appState.speechLocale) {
                    Text("English").tag("en-US")
                    Text("Japanese").tag("ja-JP")
                }
            }
            Section("Screen context") {
                Toggle("Include screen with questions this session", isOn: $appState.includeScreen)
                Text("Each question sends one screenshot of the display containing the pointer to Google Gemini. Screen Recording permission is required. Turn off for private content.")
                    .font(.caption)
            }
            Section("Shortcut") {
                Text("Press **⌃⌥ + Space** to start recording, press again to send.\n**⌃⌥ + R** restarts a new recording.\n**Click the ↻ button** on the chip to refresh.")
                    .foregroundStyle(.secondary)
            }
            Section("Privacy") {
                Label("Screen-sharing visibility depends on macOS and the capture app.",
                      systemImage: "eye.slash")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .frame(width: 460)
    }
}

#if DEBUG && !COMMAND_LINE_BUILD
#Preview {
    SettingsView().environmentObject(AppState())
}
#endif

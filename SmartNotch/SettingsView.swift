import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState

    private let models = [
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
            Section("Shortcut") {
                Text("**⌃⌥ + Space** — toggle voice capture (tap to record, tap to send).\n**⌃⌥ + Q** — rapid mode: 1–3 line answer.\n**⌃⌥ + R** — refresh: cancel current, start new recording.\n**↻ button** on the chip does the same as Refresh.")
                    .foregroundStyle(.secondary)
            }
            Section("Privacy") {
                Label("Overlay is invisible to screen-sharing (Zoom, Meet, Teams).",
                      systemImage: "eye.slash")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .frame(width: 460)
    }
}

#Preview {
    SettingsView().environmentObject(AppState())
}

import Foundation
import Combine

@MainActor
final class AppState: ObservableObject {
    enum Mode: Equatable {
        case idle
        case listening
        case transcribing
        case thinking
        case answering
        case error(String)
    }

    @Published var mode: Mode = .idle
    @Published var transcript: String = ""
    @Published var answer: String = ""
    @Published var typedQuery: String = ""
    @Published var showTypingField: Bool = false

    // Persisted via Keychain
    @Published var geminiAPIKey: String = KeychainStore.read(key: "gemini_api_key") ?? "" {
        didSet {
            KeychainStore.write(key: "gemini_api_key", value: geminiAPIKey)
            if !geminiAPIKey.isEmpty, case .error = mode {
                answer = ""
                transcript = ""
                mode = .idle
            }
        }
    }

    @Published var modelID: String = UserDefaults.standard.string(forKey: "gemini_model") ?? "gemini-2.0-flash" {
        didSet { UserDefaults.standard.set(modelID, forKey: "gemini_model") }
    }

    @Published var systemPrompt: String = UserDefaults.standard.string(forKey: "system_prompt") ??
        "You are SmartNotch, a calm assistant living just below a Mac's display notch. Be tight and direct, no preamble, no markdown headings. For simple questions answer in 1–2 sentences. For how/why/explain/code/algorithm questions, you may use up to 8 short lines — one idea per line, plain prose, no bullets unless truly necessary. If math, lead with the answer." {
        didSet { UserDefaults.standard.set(systemPrompt, forKey: "system_prompt") }
    }

    func reset() {
        transcript = ""
        answer = ""
        mode = .idle
    }
}

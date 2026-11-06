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

    @Published var modelID: String = UserDefaults.standard.string(forKey: "gemini_model") ?? "gemini-2.5-flash" {
        didSet { UserDefaults.standard.set(modelID, forKey: "gemini_model") }
    }

    @Published var answerLanguage = UserDefaults.standard.string(forKey: "answer_language") ?? "Japanese + Romaji + English" {
        didSet { UserDefaults.standard.set(answerLanguage, forKey: "answer_language") }
    }

    @Published var speechLocale = UserDefaults.standard.string(forKey: "speech_locale") ?? "en-US" {
        didSet { UserDefaults.standard.set(speechLocale, forKey: "speech_locale") }
    }

    @Published var includeScreen = false

    @Published var systemPrompt: String = UserDefaults.standard.string(forKey: "system_prompt") ??
        "You are SmartNotch, a coding assistant that lives under a Mac notch.\nYour output is shown DIRECTLY to a software engineer. Follow these rules absolutely:\n• Output ONLY the answer. No preamble. No \"Let me think\". No \"Wait\". No \"Sure!\".\n• Never narrate your reasoning. Never write \"Line 1:\", \"Step 1:\" unless the user asked for steps.\n• Code: wrap in a single ```lang ... ``` fenced block. Idiomatic, complete, compilable. Minimal comments.\n• Explanations: write 2–6 short sentences in plain prose. Use a blank line between paragraphs.\n• Get programming-language, library, framework, and algorithm names EXACTLY right.\n• Always end with a period. Never stop mid-sentence." {
        didSet { UserDefaults.standard.set(systemPrompt, forKey: "system_prompt") }
    }

    func reset() {
        transcript = ""
        answer = ""
        mode = .idle
    }
}

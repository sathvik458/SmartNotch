import Foundation

/// Streams answers from Google's Generative Language API
/// (`streamGenerateContent` with `alt=sse`). Supports a pure-text prompt
/// or a multimodal prompt that includes an inline audio attachment so we
/// can fall back to audio when local STT fails.
final class GeminiClient {
    enum ClientError: LocalizedError {
        case missingKey
        case http(Int, String)
        case decoding
        var errorDescription: String? {
            switch self {
            case .missingKey: return "No Gemini API key set."
            case .http(let s, let body): return "Gemini HTTP \(s): \(body)"
            case .decoding: return "Could not decode Gemini stream."
            }
        }
    }

    private let appState: AppState
    init(appState: AppState) { self.appState = appState }

    func streamAnswer(prompt: String, audioFile: URL?, onDelta: @escaping (String) -> Void) async throws {
        let key = await MainActor.run { appState.geminiAPIKey }
        let model = await MainActor.run { appState.modelID }
        let sysPrompt = await MainActor.run { appState.systemPrompt }
        guard !key.isEmpty else { throw ClientError.missingKey }

        let endpoint = "https://generativelanguage.googleapis.com/v1beta/models/\(model):streamGenerateContent?alt=sse&key=\(key)"
        guard let url = URL(string: endpoint) else { throw ClientError.decoding }

        var parts: [[String: Any]] = [["text": prompt]]
        if let audioFile, let data = try? Data(contentsOf: audioFile) {
            parts.append([
                "inline_data": [
                    "mime_type": "audio/mp4",
                    "data": data.base64EncodedString()
                ]
            ])
        }

        // Suppress thinking-token leakage on Gemini 2.5 models — without this,
        // the model often pours its scratchpad ("Wait, let me reconsider…",
        // "Line 1: …") straight into the answer stream.
        var generationConfig: [String: Any] = [
            "temperature": 0.3,
            "maxOutputTokens": 1500
        ]
        if model.contains("2.5") {
            generationConfig["thinkingConfig"] = ["thinkingBudget": 0]
        }

        let body: [String: Any] = [
            "system_instruction": ["parts": [["text": sysPrompt]]],
            "contents": [["role": "user", "parts": parts]],
            "generationConfig": generationConfig
        ]

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (stream, response) = try await URLSession.shared.bytes(for: req)
        guard let http = response as? HTTPURLResponse else { throw ClientError.decoding }
        if http.statusCode != 200 {
            var collected = ""
            for try await line in stream.lines { collected += line + "\n" }
            throw ClientError.http(http.statusCode, collected)
        }

        for try await line in stream.lines {
            // SSE format: "data: { ... }"
            guard line.hasPrefix("data: ") else { continue }
            let payload = String(line.dropFirst(6))
            if payload == "[DONE]" { break }
            guard let data = payload.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let candidates = json["candidates"] as? [[String: Any]],
                  let content = candidates.first?["content"] as? [String: Any],
                  let parts = content["parts"] as? [[String: Any]] else { continue }
            for p in parts {
                if let text = p["text"] as? String { onDelta(text) }
            }
        }
    }
}

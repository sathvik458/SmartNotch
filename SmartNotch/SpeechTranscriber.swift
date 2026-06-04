import Foundation
import Speech
import AVFoundation

/// On-device Apple Speech, biased toward CS/coding vocabulary so the
/// live partial caption looks sensible. The authoritative transcript still
/// comes from Gemini's multimodal audio path inside the controller.
final class SpeechTranscriber: NSObject {
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private let engine = AVAudioEngine()

    /// Words/phrases that get extra acoustic weight while we listen.
    /// SFSpeechRecognizer caps this around ~100; keep it focused.
    private static let csVocabulary: [String] = [
        // languages
        "Python", "JavaScript", "TypeScript", "Java", "Kotlin", "Swift",
        "Rust", "Go", "Golang", "C++", "C#", "Ruby", "Scala", "Haskell",
        "SQL", "Bash", "Zsh", "PHP", "Dart", "Solidity",
        // web / frameworks
        "React", "Vue", "Angular", "Svelte", "Next.js", "Node.js",
        "Django", "Flask", "FastAPI", "Rails", "Express", "Tailwind",
        // CS concepts
        "algorithm", "recursion", "iteration", "Big O", "binary search",
        "quicksort", "mergesort", "bubble sort", "heap sort",
        "linked list", "hash map", "hash table", "binary tree", "B-tree",
        "graph", "DFS", "BFS", "Dijkstra", "dynamic programming",
        "memoization", "trie", "stack", "queue", "deque",
        // systems / infra
        "API", "REST", "GraphQL", "gRPC", "WebSocket", "TCP", "UDP", "HTTP",
        "Kubernetes", "Docker", "container", "microservice", "monolith",
        "Redis", "PostgreSQL", "MySQL", "MongoDB", "DynamoDB", "Cassandra",
        "Kafka", "RabbitMQ", "Lambda", "S3", "EC2", "CloudFront",
        // tools
        "Git", "GitHub", "GitLab", "Linux", "macOS", "Xcode", "Vim",
        "npm", "yarn", "pnpm", "pip", "cargo", "Maven", "Gradle",
        // ML / AI
        "GPU", "CUDA", "tensor", "transformer", "embedding", "attention",
        "gradient descent", "backpropagation", "neural network",
        "PyTorch", "TensorFlow", "LLM", "RAG", "fine-tune", "inference",
        // patterns / paradigms
        "polymorphism", "encapsulation", "inheritance", "interface",
        "closure", "lambda", "async", "await", "concurrency", "thread",
        "mutex", "semaphore", "deadlock", "race condition",
        "OOP", "SOLID", "MVC", "MVVM", "dependency injection"
    ]

    func start(onPartial: @escaping (String) -> Void) {
        SFSpeechRecognizer.requestAuthorization { _ in }

        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults = true
        req.contextualStrings = Self.csVocabulary
        if #available(macOS 13.0, *) {
            req.requiresOnDeviceRecognition = false   // server-side is more accurate
            req.addsPunctuation = true
        }
        // Hint that the user is dictating a technical question.
        if #available(macOS 13.0, *) {
            req.taskHint = .dictation
        }
        self.request = req

        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buf, _ in
            self?.request?.append(buf)
        }

        engine.prepare()
        do { try engine.start() } catch {
            NSLog("SmartNotch: engine error \(error)")
            return
        }

        guard let recognizer, recognizer.isAvailable else { return }
        task = recognizer.recognitionTask(with: req) { result, _ in
            if let result {
                onPartial(result.bestTranscription.formattedString)
            }
        }
    }

    func stop() {
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.finish()
        task = nil
        request = nil
    }
}

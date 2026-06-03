import Foundation
import Speech
import AVFoundation

/// On-device Apple Speech for ultra-low-latency partial transcripts.
/// Streams partials via the callback while audio is captured separately
/// for the Gemini fallback path.
final class SpeechTranscriber: NSObject {
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private let engine = AVAudioEngine()

    func start(onPartial: @escaping (String) -> Void) {
        SFSpeechRecognizer.requestAuthorization { _ in }

        request = SFSpeechAudioBufferRecognitionRequest()
        request?.shouldReportPartialResults = true
        if #available(macOS 13.0, *) {
            request?.requiresOnDeviceRecognition = true
            request?.addsPunctuation = true
        }

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

        guard let recognizer, recognizer.isAvailable, let request else { return }
        task = recognizer.recognitionTask(with: request) { result, _ in
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

import Foundation
import AVFoundation

/// Records raw PCM from the default input and writes it to a temp `.m4a`
/// file so we can fall back to sending audio bytes to Gemini if the on-device
/// speech recognizer fails.
final class AudioRecorder: NSObject {
    private var recorder: AVAudioRecorder?
    private var url: URL?

    func start() {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("smartnotch-\(UUID().uuidString).m4a")
        self.url = tmp
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 16000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue
        ]
        do {
            recorder = try AVAudioRecorder(url: tmp, settings: settings)
            recorder?.prepareToRecord()
            recorder?.record()
        } catch {
            NSLog("SmartNotch: recorder error \(error)")
        }
    }

    func stop(_ done: @escaping (URL?) -> Void) {
        recorder?.stop()
        let u = url
        recorder = nil
        url = nil
        done(u)
    }
}

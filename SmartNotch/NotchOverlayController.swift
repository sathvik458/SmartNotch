import AppKit
import SwiftUI
import Combine

@MainActor
final class NotchOverlayController: NSObject {
    private let appState: AppState
    private var window: NSPanel!
    private var hostingView: NSHostingView<NotchOverlayView>!
    private var transcriber: SpeechTranscriber!
    private var recorder: AudioRecorder!
    private var gemini: GeminiClient!
    private var streamTask: Task<Void, Never>?
    private var dismissTask: Task<Void, Never>?

    init(appState: AppState) {
        self.appState = appState
        super.init()
        self.transcriber = SpeechTranscriber()
        self.recorder = AudioRecorder()
        self.gemini = GeminiClient(appState: appState)
    }

    // MARK: - Window

    func installWindow() {
        let style: NSWindow.StyleMask = [.borderless, .nonactivatingPanel]
        let panel = KeyablePanel(contentRect: .zero,
                                 styleMask: style,
                                 backing: .buffered,
                                 defer: false)

        panel.level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()) - 1)
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary,
                                    .stationary, .ignoresCycle]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.isMovable = false
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.sharingType = .none   // ← invisible to screen capture

        let view = NotchOverlayView(
            appState: appState,
            onSubmitText: { [weak self] q in self?.submitTextQuery(q) },
            onRefresh:    { [weak self] in self?.refreshVoiceCapture() }
        )
        let host = NSHostingView(rootView: view)
        host.frame = NSRect(x: 0, y: 0, width: 520, height: 380)
        panel.contentView = host
        self.hostingView = host
        self.window = panel

        positionUnderNotch()
        panel.orderFrontRegardless()

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(screenChanged),
                                               name: NSApplication.didChangeScreenParametersNotification,
                                               object: nil)
    }

    @objc private func screenChanged() { positionUnderNotch() }

    private func positionUnderNotch() {
        guard let screen = NSScreen.main else { return }
        let visibleWidth: CGFloat = 520
        let height: CGFloat = 280
        let topInset = screen.safeAreaInsets.top
        let topOfScreen = screen.frame.maxY
        let y = topOfScreen - topInset - height - 6
        let x = screen.frame.midX - visibleWidth / 2
        window.setFrame(NSRect(x: x, y: y, width: visibleWidth, height: height), display: true)
    }

    // MARK: - Voice flow (toggle)

    func toggleVoiceCapture() {
        switch appState.mode {
        case .listening:
            finishVoiceCapture()
        case .idle, .error, .answering:
            startVoiceCapture()
        case .transcribing, .thinking:
            // Mid-network; treat as a fresh restart.
            refreshVoiceCapture()
        }
    }

    func refreshVoiceCapture() {
        cancelEverything()
        startVoiceCapture()
    }

    private func startVoiceCapture() {
        guard !appState.geminiAPIKey.isEmpty else {
            appState.mode = .error("Add a Gemini API key in Settings (⌘,).")
            return
        }
        cancelEverything(showError: false)
        appState.reset()
        appState.mode = .listening
        appState.showTypingField = false

        transcriber.start { [weak self] partial in
            DispatchQueue.main.async { self?.appState.transcript = partial }
        }
        recorder.start()
    }

    private func finishVoiceCapture() {
        guard case .listening = appState.mode else { return }
        appState.mode = .transcribing
        transcriber.stop()
        recorder.stop { [weak self] audioURL in
            guard let self = self else { return }
            Task { @MainActor in
                // Authoritative path: send the audio itself to Gemini. Gemini's
                // multimodal audio model is far more accurate on technical
                // vocabulary than Apple's general-purpose dictation, which we
                // were only using for the live partial caption.
                if let url = audioURL {
                    let prompt = """
                    The user just asked the following question by voice. The audio is attached.
                    They are a software engineer / CS student. Transcribe their question                     accurately (technical terms, programming languages, library names,                     algorithm names, framework names — get these RIGHT), then answer it.
                    Reply with ONLY the answer (no preamble, no echo of the transcript).
                    """
                    self.streamTask = Task { await self.askGemini(prompt: prompt, audio: url) }
                } else {
                    self.appState.mode = .error("No audio captured. Check the mic permission.")
                }
            }
        }
    }

    /// Cancels recording, transcription, and any in-flight Gemini stream.
    private func cancelEverything(showError: Bool = false) {
        streamTask?.cancel()
        streamTask = nil
        dismissTask?.cancel()
        dismissTask = nil
        transcriber.stop()
        recorder.stop { _ in }
        if showError == false { appState.reset() }
    }

    // MARK: - Text mode

    func openTextMode() {
        cancelEverything()
        appState.reset()
        appState.showTypingField = true
        appState.mode = .idle
        window.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            self?.window.makeKey()
        }
    }

    private func submitTextQuery(_ q: String) {
        let trimmed = q.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        appState.transcript = trimmed
        appState.showTypingField = false
        streamTask = Task { await askGemini(prompt: trimmed, audio: nil) }
    }

    // MARK: - Gemini

    private func askGemini(prompt: String, audio: URL?) async {
        appState.mode = .thinking
        appState.answer = ""
        do {
            try Task.checkCancellation()
            try await gemini.streamAnswer(prompt: prompt, audioFile: audio) { delta in
                Task { @MainActor in
                    if case .thinking = self.appState.mode { self.appState.mode = .answering }
                    self.appState.answer += delta
                }
            }
            try Task.checkCancellation()
            await MainActor.run { self.appState.mode = .idle }
            scheduleAutoDismiss()
        } catch is CancellationError {
            // Refresh / new query — silent.
        } catch {
            await MainActor.run { self.appState.mode = .error(error.localizedDescription) }
        }
    }

    private func scheduleAutoDismiss() {
        dismissTask?.cancel()
        dismissTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 20_000_000_000) // 20s
            await MainActor.run {
                guard let self = self else { return }
                if self.appState.mode == .idle && !self.appState.showTypingField {
                    self.appState.reset()
                }
            }
        }
    }
}

final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

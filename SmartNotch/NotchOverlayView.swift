import SwiftUI

struct NotchOverlayView: View {
    @ObservedObject var appState: AppState
    var onSubmitText: (String) -> Void
    var onRefresh: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            chip
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var chip: some View {
        HStack(alignment: .top, spacing: 10) {
            indicator
                .frame(width: 18, height: 18)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                if appState.showTypingField {
                    typingField
                } else {
                    if !headline.isEmpty {
                        Text(headline)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.85))
                            .lineLimit(2)
                    }
                    answerBody
                }
            }
            Spacer(minLength: 4)

            refreshButton
                .padding(.top, 2)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: 500, maxHeight: 260, alignment: .top)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.black.opacity(0.85))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(.white.opacity(0.08), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.4), radius: 16, x: 0, y: 6)
        )
        .opacity(visible ? 1 : 0)
        .scaleEffect(visible ? 1 : 0.94, anchor: .top)
        .animation(.spring(response: 0.32, dampingFraction: 0.82), value: appState.mode)
        .animation(.easeInOut(duration: 0.15), value: appState.showTypingField)
    }

    // MARK: - Answer area (scrollable, auto-follows the streaming tail)

    @ViewBuilder
    private var answerBody: some View {
        let text = subtitle
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                Text(text)
                    .font(.system(size: 13))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .id("answer-tail")
            }
            .frame(maxHeight: 220)
            .onChange(of: text) { _, _ in
                withAnimation(.linear(duration: 0.12)) {
                    proxy.scrollTo("answer-tail", anchor: .bottom)
                }
            }
        }
    }


    // MARK: - Refresh button

    @ViewBuilder
    private var refreshButton: some View {
        if showRefreshButton {
            Button(action: onRefresh) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white.opacity(0.85))
                    .frame(width: 22, height: 22)
                    .background(Circle().fill(.white.opacity(0.10)))
            }
            .buttonStyle(.plain)
            .help("Refresh — new recording (⌃⌥R)")
        }
    }

    private var showRefreshButton: Bool {
        if appState.showTypingField { return false }
        switch appState.mode {
        case .idle: return !appState.answer.isEmpty
        case .listening, .transcribing, .thinking, .answering, .error:
            return true
        }
    }

    // MARK: - Visibility

    private var visible: Bool {
        if appState.showTypingField { return true }
        switch appState.mode {
        case .idle: return !appState.answer.isEmpty
        default: return true
        }
    }

    // MARK: - Indicator

    @ViewBuilder
    private var indicator: some View {
        switch appState.mode {
        case .listening:
            PulseDot(color: .red)
        case .transcribing, .thinking:
            ProgressView().controlSize(.small).tint(.white)
        case .answering:
            Image(systemName: "sparkles")
                .foregroundStyle(.white)
        case .error:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
        case .idle:
            Image(systemName: "sparkles")
                .foregroundStyle(.white.opacity(0.7))
        }
    }

    private var headline: String {
        switch appState.mode {
        case .listening: return "Listening…"
        case .transcribing: return "Transcribing…"
        case .thinking: return "Thinking…"
        case .answering: return appState.transcript
        case .idle: return appState.transcript
        case .error: return "Error"
        }
    }

    private var subtitle: String {
        switch appState.mode {
        case .listening:
            return appState.transcript.isEmpty ? "Hold Fn + Space and speak." : appState.transcript
        case .transcribing, .thinking:
            return appState.transcript.isEmpty ? "…" : appState.transcript
        case .answering, .idle:
            return appState.answer
        case .error(let msg):
            return msg
        }
    }

    private var typingField: some View {
        HStack(spacing: 6) {
            Image(systemName: "chevron.right")
                .foregroundStyle(.white.opacity(0.55))
                .font(.system(size: 11, weight: .bold))
            TypingField(text: $appState.typedQuery, onSubmit: {
                let q = appState.typedQuery
                appState.typedQuery = ""
                onSubmitText(q)
            })
            .frame(height: 22)
        }
    }
}

// MARK: - Pulse dot

private struct PulseDot: View {
    let color: Color
    @State private var on = false
    var body: some View {
        ZStack {
            Circle().fill(color.opacity(0.35)).scaleEffect(on ? 1.6 : 0.9)
            Circle().fill(color).frame(width: 8, height: 8)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { on = true }
        }
    }
}

// MARK: - NSTextField wrapper

private struct TypingField: NSViewRepresentable {
    @Binding var text: String
    var onSubmit: () -> Void

    func makeNSView(context: Context) -> NSTextField {
        let tf = NSTextField()
        tf.isBezeled = false
        tf.drawsBackground = false
        tf.focusRingType = .none
        tf.textColor = .white
        tf.font = NSFont.systemFont(ofSize: 13)
        tf.placeholderString = "Type a question…"
        tf.delegate = context.coordinator
        tf.target = context.coordinator
        tf.action = #selector(Coordinator.commit(_:))
        DispatchQueue.main.async { tf.window?.makeFirstResponder(tf) }
        return tf
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        if nsView.stringValue != text { nsView.stringValue = text }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        let parent: TypingField
        init(_ p: TypingField) { parent = p }
        func controlTextDidChange(_ obj: Notification) {
            if let tf = obj.object as? NSTextField { parent.text = tf.stringValue }
        }
        @objc func commit(_ sender: NSTextField) {
            parent.text = sender.stringValue
            parent.onSubmit()
        }
    }
}

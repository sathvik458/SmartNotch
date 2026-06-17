import SwiftUI

/// Splits a markdown-ish answer into prose + fenced-code segments
/// and renders each in the appropriate style. Streaming-safe — recomputes
/// on every token without flicker because Text identities are deterministic.
struct AnswerRenderer: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(segments(text).enumerated()), id: \.offset) { _, seg in
                switch seg {
                case .prose(let s):
                    Text(s)
                        .font(.system(size: 13))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.leading)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                case .code(let lang, let body):
                    CodeBlockView(language: lang, code: body)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Parsing

    private enum Segment {
        case prose(String)
        case code(language: String, body: String)
    }

    private func segments(_ raw: String) -> [Segment] {
        // Find pairs of triple-backticks. Whatever is between them is code;
        // everything else is prose. Handles a half-open block while streaming.
        var out: [Segment] = []
        var i = raw.startIndex
        let fence = "```"
        while let open = raw.range(of: fence, range: i..<raw.endIndex) {
            // prose chunk before the opener
            if open.lowerBound > i {
                let s = String(raw[i..<open.lowerBound])
                let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { out.append(.prose(s)) }
            }
            // language tag = rest of line after ```
            let afterOpen = open.upperBound
            let lineEnd = raw[afterOpen...].firstIndex(of: "\n") ?? raw.endIndex
            let lang = String(raw[afterOpen..<lineEnd]).trimmingCharacters(in: .whitespaces)
            let bodyStart = (lineEnd == raw.endIndex) ? lineEnd : raw.index(after: lineEnd)

            if let close = raw.range(of: fence, range: bodyStart..<raw.endIndex) {
                let body = String(raw[bodyStart..<close.lowerBound])
                out.append(.code(language: lang, body: body))
                i = close.upperBound
            } else {
                // Stream is still mid-block — show what we have so far.
                let body = String(raw[bodyStart..<raw.endIndex])
                out.append(.code(language: lang, body: body))
                return out
            }
        }
        if i < raw.endIndex {
            let s = String(raw[i..<raw.endIndex])
            let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { out.append(.prose(s)) }
        }
        return out
    }
}

// MARK: - Code block

private struct CodeBlockView: View {
    let language: String
    let code: String
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                if !language.isEmpty {
                    Text(language.lowercased())
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.55))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Capsule().fill(.white.opacity(0.08)))
                }
                Spacer()
                Button(action: copy) {
                    Image(systemName: copied ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white.opacity(0.7))
                }
                .buttonStyle(.plain)
                .help("Copy code")
            }
            ScrollView(.horizontal, showsIndicators: false) {
                Text(code.trimmingCharacters(in: CharacterSet.newlines))
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(Color(red: 0.94, green: 0.95, blue: 0.98))
                    .textSelection(.enabled)
                    .padding(8)
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(red: 0.07, green: 0.08, blue: 0.10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(.white.opacity(0.06), lineWidth: 1)
                )
        )
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func copy() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(code, forType: .string)
        copied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { copied = false }
    }
}

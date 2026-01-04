import SwiftUI
import PocketMeshServices

/// Reusable chat input bar with configurable styling
struct ChatInputBar: View {
    @Binding var text: String
    @FocusState.Binding var isFocused: Bool
    let placeholder: String
    let accentColor: Color
    let maxCharacters: Int
    let onSend: () -> Void

    private var byteCount: Int {
        text.utf8.count
    }

    private var isOverLimit: Bool {
        byteCount > maxCharacters
    }

    private var shouldShowByteCount: Bool {
        // Show when within 20 bytes of limit or over limit
        byteCount >= maxCharacters - 20
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            textField
            sendButtonWithCounter
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .inputBarBackground()
    }

    private var textField: some View {
        TextField(placeholder, text: $text, axis: .vertical)
            .textFieldStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .textFieldBackground()
            .lineLimit(1...5)
            .focused($isFocused)
            .accessibilityLabel("Message input")
            .accessibilityHint("Type your message here")
    }

    private var sendButtonWithCounter: some View {
        VStack(spacing: 4) {
            sendButton
            if shouldShowByteCount {
                characterCountLabel
            }
        }
    }

    private var characterCountLabel: some View {
        Text("\(byteCount)/\(maxCharacters)")
            .font(.caption2)
            .monospacedDigit()
            .foregroundStyle(isOverLimit ? .red : .secondary)
            .accessibilityLabel("\(byteCount) of \(maxCharacters) bytes")
    }

    @ViewBuilder
    private var sendButton: some View {
        let button = Button("Send", systemImage: "arrow.up.circle.fill", action: onSend)
            .labelStyle(.iconOnly)
            .font(.title2)
            .foregroundStyle(canSend ? accentColor : .secondary)
            .disabled(!canSend)
            .accessibilityLabel(sendAccessibilityLabel)
            .accessibilityHint(sendAccessibilityHint)

        if #available(iOS 26.0, *) {
            button.buttonStyle(.glass)
        } else {
            button
        }
    }

    private var sendAccessibilityLabel: String {
        if isOverLimit {
            return "Message too long"
        } else {
            return "Send message"
        }
    }

    private var sendAccessibilityHint: String {
        if isOverLimit {
            return "Remove \(byteCount - maxCharacters) bytes to send"
        } else if canSend {
            return "Tap to send your message"
        } else {
            return "Type a message first"
        }
    }

    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isOverLimit
    }
}

// MARK: - Platform-Conditional Styling

private extension View {
    @ViewBuilder
    func textFieldBackground() -> some View {
        if #available(iOS 26.0, *) {
            // Liquid Glass with interactive touch response, rounded rect for multi-line support
            self.glassEffect(.regular.interactive(), in: .rect(cornerRadius: 20))
        } else {
            self
                .background(.quaternary)
                .clipShape(.rect(cornerRadius: 20))
        }
    }

    @ViewBuilder
    func inputBarBackground() -> some View {
        if #available(iOS 26.0, *) {
            // No background on iOS 26 - let glass effect on text field show through
            self
        } else {
            self.background(.bar)
        }
    }
}

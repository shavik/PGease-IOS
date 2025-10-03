import SwiftUI

struct ChatView: View {
    @State private var messageText = ""
    @State private var messages: [ChatMessage] = [
        ChatMessage(text: "Welcome to the chat! How can I help you today?", isFromUser: false, timestamp: Date()),
        ChatMessage(text: "Hi! I have a question about my room service.", isFromUser: true, timestamp: Date()),
        ChatMessage(text: "I'd be happy to help with your room service inquiry. What do you need?", isFromUser: false, timestamp: Date())
    ]

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Messages List
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(messages) { message in
                                MessageBubble(message: message)
                                    .id(message.id)
                            }
                        }
                        .padding()
                    }
                    .onChange(of: messages.count) { _ in
                        if let lastMessage = messages.last {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                }

                // Message Input
                MessageInputView(messageText: $messageText) {
                    sendMessage()
                }
            }
            .navigationTitle("Support Chat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: clearChat) {
                        Image(systemName: "trash")
                    }
                }
            }
        }
    }

    private func sendMessage() {
        guard !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        let newMessage = ChatMessage(
            text: messageText,
            isFromUser: true,
            timestamp: Date()
        )

        messages.append(newMessage)
        messageText = ""

        // Simulate response after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            let responses = [
                "Thank you for your message. I'll look into that for you.",
                "I understand your concern. Let me check the system for you.",
                "That's a great question! Here's what I can tell you...",
                "I'll need to escalate this to our management team.",
                "I can help you with that. Let me provide you with the details."
            ]

            let response = ChatMessage(
                text: responses.randomElement() ?? "I'm here to help!",
                isFromUser: false,
                timestamp: Date()
            )

            messages.append(response)
        }
    }

    private func clearChat() {
        messages.removeAll()
        messages.append(ChatMessage(
            text: "Chat cleared. How can I help you today?",
            isFromUser: false,
            timestamp: Date()
        ))
    }
}

struct ChatMessage: Identifiable {
    let id = UUID()
    let text: String
    let isFromUser: Bool
    let timestamp: Date
}

struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.isFromUser {
                Spacer(minLength: 50)

                VStack(alignment: .trailing, spacing: 4) {
                    Text(message.text)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(18)
                        .cornerRadius(4, corners: .bottomRight)

                    Text(formatTime(message.timestamp))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .top, spacing: 8) {
                        // Support avatar
                        Image(systemName: "person.circle.fill")
                            .font(.title2)
                            .foregroundColor(.blue)

                        Text(message.text)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color(.systemGray6))
                            .foregroundColor(.primary)
                            .cornerRadius(18)
                            .cornerRadius(4, corners: .bottomLeft)
                    }

                    Text(formatTime(message.timestamp))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.leading, 40)
                }

                Spacer(minLength: 50)
            }
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct MessageInputView: View {
    @Binding var messageText: String
    let onSend: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            TextField("Type a message...", text: $messageText, axis: .vertical)
                .textFieldStyle(PlainTextFieldStyle())
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color(.systemGray6))
                .cornerRadius(20)
                .lineLimit(1...4)

            Button(action: onSend) {
                Image(systemName: "paperplane.fill")
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray : Color.blue)
                    .cornerRadius(20)
            }
            .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding()
        .background(Color(.systemBackground))
    }
}

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

#Preview {
    ChatView()
}

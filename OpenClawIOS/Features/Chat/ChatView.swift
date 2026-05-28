import SwiftUI

struct ChatView: View {
    static let screenTitle = "Operator Chat"

    @Environment(GatewayOperatorStore.self) private var gatewayStore
    @State private var draftMessage = ""

    var body: some View {
        VStack(spacing: 0) {
            if !self.gatewayStore.sessions.isEmpty {
                Picker("Session", selection: sessionSelection) {
                    ForEach(self.gatewayStore.sessions) { session in
                        Text(session.title).tag(Optional(session.key))
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 8)
            }

            sessionControlsRow

            if let selectedSession = self.selectedSessionTitle {
                HStack {
                    Label(selectedSession, systemImage: "rectangle.and.pencil.and.ellipsis")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.secondary)

                    Spacer()
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }

            if let errorMessage = self.gatewayStore.lastErrorMessage {
                HStack {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote)
                        .foregroundStyle(.orange)

                    Spacer()
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }

            if self.gatewayStore.transcript.isEmpty {
                ContentUnavailableView(
                    "No Messages Yet",
                    systemImage: "bubble.left.and.bubble.right",
                    description: Text("Connect to a gateway session to start chatting from the iPhone dashboard."))
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(self.gatewayStore.transcript) { message in
                            messageBubble(for: message)
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle(Self.screenTitle)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu("Session Actions", systemImage: "ellipsis.circle") {
                    Button("Abort Current Run") {
                        Task {
                            try? await self.gatewayStore.abortCurrentRun()
                        }
                    }
                    .disabled(self.gatewayStore.selectedSessionKey == nil)

                    Button("Compact Session") {
                        Task {
                            try? await self.gatewayStore.compactCurrentSession()
                        }
                    }
                    .disabled(self.gatewayStore.selectedSessionKey == nil)

                    Button("Reset Session", role: .destructive) {
                        Task {
                            try? await self.gatewayStore.resetCurrentSession()
                        }
                    }
                    .disabled(self.gatewayStore.selectedSessionKey == nil)
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            composer
        }
    }

    private var sessionSelection: Binding<String?> {
        Binding(
            get: { self.gatewayStore.selectedSessionKey },
            set: { newValue in
                guard let newValue else { return }

                Task {
                    try? await self.gatewayStore.selectSession(newValue)
                }
            })
    }

    private var sessionControlsRow: some View {
        HStack(spacing: 12) {
            Picker("Model", selection: Bindable(self.gatewayStore).selectedModel) {
                Text("Default").tag(Optional<String>(nil))
                Text("claude-sonnet").tag(Optional("claude-sonnet"))
                Text("claude-opus").tag(Optional("claude-opus"))
                Text("gpt-4o").tag(Optional("gpt-4o"))
            }
            .pickerStyle(.menu)

            Picker("Thinking", selection: Bindable(self.gatewayStore).selectedThinking) {
                Text("Low").tag("low")
                Text("Medium").tag("medium")
                Text("High").tag("high")
            }
            .pickerStyle(.menu)

            Spacer()

            Button {
                Task {
                    try? await self.gatewayStore.patchCurrentSession(
                        model: self.gatewayStore.selectedModel,
                        thinking: self.gatewayStore.selectedThinking
                    )
                }
            } label: {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
            .buttonStyle(.plain)
            .disabled(self.gatewayStore.selectedSessionKey == nil)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(.horizontal)
    }

    private func messageBubble(for message: GatewayChatMessage) -> some View {
        VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 6) {
            Text(message.role == .user ? "You" : "OpenClaw")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(message.text)
                .frame(
                    maxWidth: .infinity,
                    alignment: message.role == .user ? .trailing : .leading)
                .padding()
                .background(
                    message.role == .user ? Color.accentColor.opacity(0.16) : Color(.secondarySystemBackground),
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
    }

    private var composer: some View {
        HStack(spacing: 12) {
            TextField("Send an instruction", text: self.$draftMessage, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...4)

            Button("Send") {
                let outgoingMessage = self.draftMessage

                Task {
                    do {
                        try await self.gatewayStore.sendMessage(outgoingMessage)
                        self.draftMessage = ""
                    } catch {}
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(self.sendDisabled)
        }
        .padding()
        .background(.ultraThinMaterial)
    }

    private var sendDisabled: Bool {
        self.draftMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || self.gatewayStore.selectedSessionKey == nil
            || self.gatewayStore.isSendingMessage
    }

    private var selectedSessionTitle: String? {
        guard let sessionKey = self.gatewayStore.selectedSessionKey else { return nil }
        return self.gatewayStore.sessions.first(where: { $0.key == sessionKey })?.title
    }
}

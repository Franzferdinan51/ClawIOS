import SwiftUI

struct ChatView: View {
    static let screenTitle = "Operator Chat"

    @Environment(GatewayOperatorStore.self) private var gatewayStore
    @State private var draftMessage = ""
    @State private var scrollToBottom = false

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
                    Image(systemName: "rectangle.and.pencil.and.ellipsis")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Text(selectedSession)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.bottom, 4)
            }

            errorBanner

            if self.gatewayStore.transcript.isEmpty {
                emptyState
            } else {
                messageList
            }
        }
        .navigationTitle(Self.screenTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .safeAreaInset(edge: .bottom) {
            composer
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var errorBanner: some View {
        if let errorMessage = self.gatewayStore.lastErrorMessage {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.orange)
                Spacer()
                Button {
                    self.gatewayStore.clearError()
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 6)
            .background(Color.orange.opacity(0.08))
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Messages", systemImage: "bubble.left.and.bubble.right")
        } description: {
            Text("Connect to a gateway session to start chatting from the iPhone dashboard.")
        } actions: {
            Button("Refresh") {
                Task { try? await self.gatewayStore.refreshDashboard() }
            }
            .buttonStyle(.bordered)
        }
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    ForEach(self.gatewayStore.transcript) { message in
                        messageBubble(for: message)
                            .id(message.id)
                    }

                    if self.gatewayStore.isAgentRunning {
                        typingIndicator
                            .id("typing")
                    }
                }
                .padding()
            }
            .onChange(of: self.gatewayStore.transcript.count) { _, _ in
                if let last = self.gatewayStore.transcript.last {
                    withAnimation {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
            .onChange(of: self.gatewayStore.isAgentRunning) { _, running in
                if running, let last = self.gatewayStore.transcript.last {
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            }
        }
    }

    private func messageBubble(for message: GatewayChatMessage) -> some View {
        HStack(alignment: .top, spacing: 0) {
            if message.role == .user {
                Spacer(minLength: 60)
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(message.role == .user ? "You" : "OpenClaw")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(message.role == .user ? OpenClawTheme.primary : .secondary)
                }

                Text(message.text)
                    .font(.subheadline)
                    .foregroundStyle(message.role == .user ? .primary : .secondary)
                    .frame(
                        maxWidth: 280,
                        alignment: message.role == .user ? .trailing : .leading)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        message.role == .user
                            ? OpenClawTheme.primary.opacity(0.15)
                            : Color(.secondarySystemBackground),
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }

            if message.role != .user {
                Spacer(minLength: 60)
            }
        }
    }

    private var typingIndicator: some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("OpenClaw")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text("thinking...")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                HStack(spacing: 4) {
                    ForEach(0..<3) { i in
                        Circle()
                            .fill(OpenClawTheme.primary.opacity(0.6))
                            .frame(width: 6, height: 6)
                            .opacity(0.4 + Double(i) * 0.3)
                    }
                    Text("thinking...")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer(minLength: 60)
        }
    }

    private var sessionControlsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                Picker("Model", selection: Bindable(self.gatewayStore).selectedModel) {
                    Text("Default").tag(Optional<String>(nil))
                    Text("claude-sonnet").tag(Optional("claude-sonnet"))
                    Text("claude-opus").tag(Optional("claude-opus"))
                    Text("gpt-4o").tag(Optional("gpt-4o"))
                }
                .pickerStyle(.menu)
                .tint(OpenClawTheme.primary)

                Picker("Thinking", selection: Bindable(self.gatewayStore).selectedThinking) {
                    Text("Low").tag("low")
                    Text("Medium").tag("medium")
                    Text("High").tag("high")
                }
                .pickerStyle(.menu)
                .tint(OpenClawTheme.primary)

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
        }
        .background(Color(.secondarySystemBackground).opacity(0.5))
    }

    private var composer: some View {
        VStack(spacing: 8) {
            if self.gatewayStore.isSendingMessage {
                HStack(spacing: 6) {
                    ProgressView()
                        .scaleEffect(0.6)
                    Text("Sending...")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal)
            }

            HStack(spacing: 12) {
                TextField("Send an instruction...", text: self.$draftMessage, axis: .vertical)
                    .textFieldStyle(.plain)
                    .padding(12)
                    .background(Color(.tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .lineLimit(1...4)

                Button {
                    let outgoingMessage = self.draftMessage
                    Task {
                        do {
                            try await self.gatewayStore.sendMessage(outgoingMessage)
                            self.draftMessage = ""
                        } catch {
                            self.gatewayStore.lastErrorMessage = error.localizedDescription
                        }
                    }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundStyle(self.sendDisabled ? .gray : OpenClawTheme.primary)
                }
                .buttonStyle(.plain)
                .disabled(self.sendDisabled)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button {
                    Task { try? await self.gatewayStore.abortCurrentRun() }
                } label: {
                    Label("Abort Current Run", systemImage: "stop.circle")
                }
                .disabled(self.gatewayStore.selectedSessionKey == nil)

                Button {
                    Task { try? await self.gatewayStore.compactCurrentSession() }
                } label: {
                    Label("Compact Session", systemImage: "rectangle.3.group")
                }
                .disabled(self.gatewayStore.selectedSessionKey == nil)

                Divider()

                Button(role: .destructive) {
                    Task { try? await self.gatewayStore.resetCurrentSession() }
                } label: {
                    Label("Reset Session", systemImage: "arrow.counterclockwise")
                }
                .disabled(self.gatewayStore.selectedSessionKey == nil)
            } label: {
                Image(systemName: "ellipsis.circle")
                    .foregroundStyle(OpenClawTheme.primary)
            }
        }
    }

    // MARK: - Helpers

    private var sessionSelection: Binding<String?> {
        Binding(
            get: { self.gatewayStore.selectedSessionKey },
            set: { newValue in
                guard let newValue else { return }
                Task { try? await self.gatewayStore.selectSession(newValue) }
            })
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


import SwiftUI

struct HomeView: View {
    static let screenTitle = "Gateway Overview"

    @Environment(AppSessionModel.self) private var sessionModel
    @Environment(GatewayOperatorStore.self) private var gatewayStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                gatewayCard
                summaryCards
                recentSessionsCard
                activeTranscriptCard
                agentActivityCard
                quickActions
            }
            .padding()
        }
        .navigationTitle(Self.screenTitle)
    }

    private var gatewayCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Gateway", systemImage: "bolt.horizontal.circle.fill")
                .font(.headline)

            Text(self.sessionModel.gatewayEndpointInput)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Label(self.connectionLabel, systemImage: "dot.radiowaves.left.and.right")
                .font(.subheadline.weight(.medium))

            if let selectedSessionTitle = self.selectedSessionTitle {
                Label(selectedSessionTitle, systemImage: "bubble.left.and.bubble.right")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if let errorMessage = self.gatewayStore.lastErrorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote)
                    .foregroundStyle(.orange)
            } else {
                Text(self.sessionModel.gatewayConnectionSummary)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var summaryCards: some View {
        HStack(spacing: 12) {
            summaryCard(
                title: "Chats",
                value: "\(self.gatewayStore.sessions.count)",
                symbol: "bubble.left.and.bubble.right.fill")
            summaryCard(
                title: "Nodes",
                value: "\(self.gatewayStore.nodes.count)",
                symbol: "desktopcomputer")
        }
    }

    private func summaryCard(title: String, value: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: symbol)
                .font(.title3)
            Text(value)
                .font(.system(size: 28, weight: .semibold, design: .rounded))
            Text(title)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.headline)

            HStack {
                Button("Open Operator Chat") {
                    self.sessionModel.selectedTab = .chat
                }
                .buttonStyle(.borderedProminent)

                Button("Refresh Gateway") {
                    Task {
                        try? await self.gatewayStore.refreshDashboard()
                    }
                }
                .buttonStyle(.bordered)
            }

            HStack {
                Button("Inspect Nodes") {
                    self.sessionModel.selectedTab = .nodes
                }
                .buttonStyle(.bordered)

                Button("Device Status") {
                    self.sessionModel.selectedTab = .device
                }
                .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var recentSessionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Sessions")
                .font(.headline)

            if self.gatewayStore.sessions.isEmpty {
                Text("Connect to your gateway to load recent sessions.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(self.gatewayStore.sessions.prefix(3))) { session in
                    Button {
                        self.sessionModel.selectedTab = .chat
                        Task {
                            try? await self.gatewayStore.selectSession(session.key)
                        }
                    } label: {
                        HStack(alignment: .top, spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(session.title)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)

                                Text(session.key)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }

                            Spacer()

                            if session.key == self.gatewayStore.selectedSessionKey {
                                Text("Active")
                                    .font(.caption.weight(.semibold))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color.accentColor.opacity(0.14), in: Capsule())
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var activeTranscriptCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Active Chat")
                .font(.headline)

            if let latestMessage = self.gatewayStore.transcript.last {
                Text(self.selectedSessionTitle ?? "Selected Session")
                    .font(.subheadline.weight(.semibold))

                Text(latestMessage.text)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(4)
            } else {
                Text("Choose a session to preview the latest conversation turn.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var agentActivityCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Agent Activity")
                    .font(.headline)
                Spacer()
                if self.gatewayStore.isAgentRunning {
                    ProgressView()
                        .scaleEffect(0.7)
                }
            }

            if self.gatewayStore.isAgentRunning {
                HStack(spacing: 8) {
                    Circle()
                        .fill(.green)
                        .frame(width: 8, height: 8)
                    Text("Agent is thinking...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            if let activity = self.gatewayStore.lastAgentActivity {
                Text(activity)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            } else {
                Text("No recent agent activity. Start a chat to see agent events here.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var connectionLabel: String {
        switch self.gatewayStore.connectionState {
        case .disconnected:
            return "Disconnected"
        case .connecting:
            return "Connecting"
        case .connected:
            return "Connected"
        }
    }

    private var selectedSessionTitle: String? {
        guard let sessionKey = self.gatewayStore.selectedSessionKey else { return nil }
        return self.gatewayStore.sessions.first(where: { $0.key == sessionKey })?.title
    }
}

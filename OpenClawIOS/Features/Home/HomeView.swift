import SwiftUI

struct HomeView: View {
    static let screenTitle = "Gateway Overview"

    @Environment(AppSessionModel.self) private var sessionModel
    @Environment(GatewayOperatorStore.self) private var gatewayStore

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
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
        .navigationBarTitleDisplayMode(.large)
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Gateway Card

    private var gatewayCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "bolt.horizontal.circle.fill")
                    .font(.title2)
                    .foregroundStyle(OpenClawTheme.primary)
                Text("Gateway")
                    .font(.headline)
                Spacer()
                connectionBadge
            }

            Text(self.sessionModel.gatewayEndpointInput)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)

            if let selectedTitle = self.selectedSessionTitle {
                Divider()
                HStack {
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .font(.caption)
                        .foregroundStyle(OpenClawTheme.primary)
                    Text(selectedTitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if let errorMessage = self.gatewayStore.lastErrorMessage {
                Divider()
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .lineLimit(2)
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var connectionBadge: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(connectionColor)
                .frame(width: 8, height: 8)
            Text(connectionLabel)
                .font(.caption.weight(.semibold))
                .foregroundStyle(connectionColor)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(connectionColor.opacity(0.12), in: Capsule())
    }

    // MARK: - Summary Cards

    private var summaryCards: some View {
        HStack(spacing: 12) {
            summaryCard(
                title: "Sessions",
                value: "\(self.gatewayStore.sessions.count)",
                symbol: "bubble.left.and.bubble.right.fill",
                color: OpenClawTheme.primary)
            summaryCard(
                title: "Nodes",
                value: "\(self.gatewayStore.nodes.count)",
                symbol: "desktopcomputer",
                color: .blue)
        }
    }

    private func summaryCard(title: String, value: String, symbol: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: symbol)
                    .font(.title3)
                    .foregroundStyle(color)
                Spacer()
            }

            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)

            Text(title)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Recent Sessions

    private var recentSessionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Sessions")
                    .font(.headline)
                Spacer()
                if self.gatewayStore.sessions.count > 3 {
                    Button("See all") {
                        self.sessionModel.selectedTab = .chat
                    }
                    .font(.caption)
                }
            }

            if self.gatewayStore.sessions.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "wifi.slash")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    Text("Connect to your gateway to load sessions.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            } else {
                ForEach(Array(self.gatewayStore.sessions.prefix(3))) { session in
                    sessionRow(session)
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func sessionRow(_ session: GatewaySessionSummary) -> some View {
        Button {
            self.sessionModel.selectedTab = .chat
            Task { try? await self.gatewayStore.selectSession(session.key) }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "bubble.left.and.bubble.right")
                    .font(.body)
                    .foregroundStyle(OpenClawTheme.primary)
                    .frame(width: 28, height: 28)
                    .background(OpenClawTheme.primary.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 2) {
                    Text(session.title)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                    Text(session.key)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                if session.key == self.gatewayStore.selectedSessionKey {
                    Text("Active")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(OpenClawTheme.primary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(OpenClawTheme.primary.opacity(0.12), in: Capsule())
                } else {
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Active Chat Preview

    private var activeTranscriptCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Active Chat")
                .font(.headline)

            if let latestMessage = self.gatewayStore.transcript.last {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: latestMessage.role == .user ? "person.fill" : "pawprint.fill")
                        .font(.caption)
                        .foregroundStyle(latestMessage.role == .user ? OpenClawTheme.primary : .secondary)
                        .frame(width: 24, height: 24)
                        .background((latestMessage.role == .user ? OpenClawTheme.primary : Color.secondary).opacity(0.12), in: Circle())

                    VStack(alignment: .leading, spacing: 4) {
                        Text(latestMessage.role == .user ? "You" : "OpenClaw")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        Text(latestMessage.text)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                            .lineLimit(3)
                    }
                }

                Button("Continue in Chat") {
                    self.sessionModel.selectedTab = .chat
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(OpenClawTheme.primary)
            } else {
                HStack(spacing: 10) {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    Text("Choose a session to preview the latest conversation turn.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Agent Activity

    private var agentActivityCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Agent")
                    .font(.headline)
                Spacer()
                agentBadge
            }

            if self.gatewayStore.isAgentRunning {
                HStack(spacing: 8) {
                    ForEach(0..<3) { i in
                        Circle()
                            .fill(OpenClawTheme.primary)
                            .frame(width: 6, height: 6)
                            .opacity(0.3 + Double(i) * 0.3)
                    }
                    Text("Processing...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if let activity = self.gatewayStore.lastAgentActivity {
                Text(activity)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            } else {
                Text("No recent agent activity. Start a chat to see agent events here.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var agentBadge: some View {
        HStack(spacing: 4) {
            if self.gatewayStore.isAgentRunning {
                ProgressView()
                    .scaleEffect(0.5)
            }
            Circle()
                .fill(self.gatewayStore.isAgentRunning ? .green : .gray)
                .frame(width: 6, height: 6)
            Text(self.gatewayStore.isAgentRunning ? "Running" : "Idle")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Quick Actions

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.headline)

            HStack(spacing: 12) {
                Button {
                    self.sessionModel.selectedTab = .chat
                } label: {
                    Label("Chat", systemImage: "bubble.left.and.bubble.right.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(OpenClawTheme.primary)

                Button {
                    Task { try? await self.gatewayStore.refreshDashboard() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }

            HStack(spacing: 12) {
                Button {
                    self.sessionModel.selectedTab = .nodes
                } label: {
                    Label("Nodes", systemImage: "desktopcomputer")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button {
                    self.sessionModel.selectedTab = .device
                } label: {
                    Label("Device", systemImage: "iphone")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Helpers

    private var connectionLabel: String {
        switch self.gatewayStore.connectionState {
        case .disconnected: return "Disconnected"
        case .connecting: return "Connecting"
        case .connected: return "Connected"
        }
    }

    private var connectionColor: Color {
        switch self.gatewayStore.connectionState {
        case .disconnected: return .gray
        case .connecting: return .yellow
        case .connected: return .green
        }
    }

    private var selectedSessionTitle: String? {
        guard let sessionKey = self.gatewayStore.selectedSessionKey else { return nil }
        return self.gatewayStore.sessions.first(where: { $0.key == sessionKey })?.title
    }
}
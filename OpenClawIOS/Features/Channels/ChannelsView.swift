import SwiftUI

struct ChannelsView: View {
    static let screenTitle = "Channels"

    @Environment(GatewayOperatorStore.self) private var gatewayStore
    @State private var isRefreshing = false

    var body: some View {
        Group {
            if gatewayStore.channels.isEmpty {
                ContentUnavailableView(
                    "No Channels",
                    systemImage: "bubble.left.and.bubble.right",
                    description: Text("Connect a gateway to see your messaging channels (WhatsApp, Telegram, Slack, Discord, and more).")
                )
            } else {
                List {
                    ForEach(gatewayStore.channels) { channel in
                        ChannelRow(channel: channel) {
                            Task {
                                try? await self.gatewayStore.toggleChannel(channel)
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle(Self.screenTitle)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task {
                        isRefreshing = true
                        try? await self.gatewayStore.refreshChannels()
                        isRefreshing = false
                    }
                } label: {
                    if isRefreshing {
                        ProgressView()
                            .scaleEffect(0.7)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
        .task {
            try? await self.gatewayStore.refreshChannels()
        }
    }
}

struct ChannelRow: View {
    let channel: GatewayChannel
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            // Platform icon
            Image(systemName: platformIcon(channel.platform))
                .font(.title2)
                .foregroundStyle(platformColor(channel.platform))
                .frame(width: 36, height: 36)
                .background(platformColor(channel.platform).opacity(0.12), in: RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 4) {
                Text(channel.name)
                    .font(.subheadline.weight(.semibold))

                HStack(spacing: 6) {
                    Circle()
                        .fill(statusColor(channel.status))
                        .frame(width: 7, height: 7)
                    Text(channel.status.rawValue.capitalized)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if channel.messageCount > 0 {
                        Text("•")
                            .foregroundStyle(.secondary)
                        Text("\(channel.messageCount) messages")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { channel.enabled },
                set: { _ in onToggle() }
            ))
            .labelsHidden()
        }
        .padding(.vertical, 8)
    }

    private func platformIcon(_ platform: String) -> String {
        switch platform.lowercased() {
        case "whatsapp": return "bubble.left.fill"
        case "telegram": return "paperplane.fill"
        case "slack": return "number"
        case "discord": return "gamecontroller.fill"
        case "signal": return "lock.fill"
        case "imessage", "messages": return "message.fill"
        case "irc": return "terminal.fill"
        case "microsoftteams", "teams": return "person.3.fill"
        case "matrix": return "grid.fill"
        case "email": return "envelope.fill"
        case "web": return "globe"
        default: return "bubble.left.and.bubble.right"
        }
    }

    private func platformColor(_ platform: String) -> Color {
        switch platform.lowercased() {
        case "whatsapp": return Color(hex: "25D366")
        case "telegram": return Color(hex: "26A5E4")
        case "slack": return Color(hex: "4A154B")
        case "discord": return Color(hex: "5865F2")
        case "signal": return Color(hex: "3A76F0")
        case "imessage", "messages": return Color(hex: "007AFF")
        case "irc": return Color(hex: "FF6600")
        case "microsoftteams", "teams": return Color(hex: "6264A7")
        case "matrix": return Color(hex: "0AC18E")
        case "email": return Color(hex: "EA4335")
        default: return OpenClawTheme.primary
        }
    }

    private func statusColor(_ status: GatewayChannel.ChannelStatus) -> Color {
        switch status {
        case .connected: return .green
        case .connecting: return .yellow
        case .disconnected: return .gray
        case .error: return .red
        }
    }
}
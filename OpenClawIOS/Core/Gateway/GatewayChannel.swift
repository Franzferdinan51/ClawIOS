import Foundation

/// Represents a messaging platform channel connected to the gateway.
struct GatewayChannel: Identifiable {
    let id: String
    let name: String
    let platform: String  // "whatsapp", "telegram", "slack", "discord", etc.
    let status: ChannelStatus
    let enabled: Bool
    let configuredAt: Date?
    let messageCount: Int

    enum ChannelStatus: String {
        case connected
        case disconnected
        case connecting
        case error
    }
}
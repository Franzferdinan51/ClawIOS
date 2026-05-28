import Foundation

private let gatewayChannelLabels: [String: String] = [
    "discord": "Discord",
    "email": "Email",
    "imessage": "iMessage",
    "matrix": "Matrix",
    "signal": "Signal",
    "slack": "Slack",
    "sms": "SMS",
    "telegram": "Telegram",
    "whatsapp": "WhatsApp",
]

func resolveGatewaySessionTitle(key: String, preferredTitle: String?) -> String {
    if let preferredTitle = preferredTitle?.trimmingCharacters(in: .whitespacesAndNewlines), !preferredTitle.isEmpty {
        return preferredTitle
    }

    if key == "main" || key == "agent:main:main" {
        return "Main Session"
    }

    if key.contains(":subagent:") {
        return "Subagent"
    }

    let lowercasedKey = key.lowercased()
    if lowercasedKey.hasPrefix("cron:") || lowercasedKey.contains(":cron:") {
        return "Cron Job"
    }

    if let match = key.firstMatch(of: /^agent:[^:]+:([^:]+):direct:(.+)$/) {
        let channel = String(match.output.1)
        let identifier = String(match.output.2)
        return "\(labelForGatewayChannel(channel)) - \(identifier)"
    }

    if let match = key.firstMatch(of: /^agent:[^:]+:([^:]+):group:(.+)$/) {
        let channel = String(match.output.1)
        return "\(labelForGatewayChannel(channel)) Group"
    }

    return key
}

private func labelForGatewayChannel(_ rawValue: String) -> String {
    if let label = gatewayChannelLabels[rawValue.lowercased()] {
        return label
    }

    guard let firstCharacter = rawValue.first else {
        return rawValue
    }

    return String(firstCharacter).uppercased() + rawValue.dropFirst()
}

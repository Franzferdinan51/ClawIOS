import Foundation

struct GatewaySessionSummary: Codable, Equatable, Identifiable {
    var key: String
    var title: String

    var id: String { self.key }
}

enum GatewayChatRole: String, Codable {
    case user
    case assistant

    init(openClawRole: String) {
        switch openClawRole.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "user":
            self = .user
        default:
            self = .assistant
        }
    }
}

struct GatewayChatMessage: Codable, Equatable, Identifiable {
    var id: String
    var role: GatewayChatRole
    var text: String
}

struct GatewayNodeSummary: Codable, Equatable, Identifiable {
    var id: String
    var name: String
    var capabilityNames: [String]
}

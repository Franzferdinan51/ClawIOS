import Foundation

final class MockGatewayOperatorService: GatewayOperatorService, @unchecked Sendable {
    var sessions: [GatewaySessionSummary]
    var nodes: [GatewayNodeSummary]
    var history: [String: [GatewayChatMessage]]

    init(
        sessions: [GatewaySessionSummary] = [],
        nodes: [GatewayNodeSummary] = [],
        history: [String: [GatewayChatMessage]] = [:]
    ) {
        self.sessions = sessions
        self.nodes = nodes
        self.history = history
    }

    func connect() async throws {}

    func listSessions() async throws -> [GatewaySessionSummary] {
        self.sessions
    }

    func listNodes() async throws -> [GatewayNodeSummary] {
        self.nodes
    }

    func chatHistory(sessionKey: String) async throws -> [GatewayChatMessage] {
        self.history[sessionKey, default: []]
    }

    func sendMessage(sessionKey: String, text: String) async throws -> GatewayChatMessage {
        let message = GatewayChatMessage(id: UUID().uuidString, role: .user, text: text)
        let reply = GatewayChatMessage(
            id: UUID().uuidString,
            role: .assistant,
            text: "Mock gateway heard: \(text)")
        self.history[sessionKey, default: []].append(message)
        self.history[sessionKey, default: []].append(reply)
        return message
    }

    func abort(sessionKey: String) async throws {}

    func resetSession(sessionKey: String) async throws {
        self.history[sessionKey] = []
    }

    func compactSession(sessionKey: String) async throws {
        let latest = self.history[sessionKey, default: []].suffix(1)
        self.history[sessionKey] = Array(latest)
    }

    func patchSession(sessionKey: String, model: String?, thinking: String?) async throws {}

    func listChannels() async throws -> [GatewayChannel] { [] }

    func toggleChannel(id: String, enabled: Bool) async throws {}
}

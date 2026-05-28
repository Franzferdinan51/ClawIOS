import Foundation

protocol GatewayOperatorService {
    func connect() async throws
    func listSessions() async throws -> [GatewaySessionSummary]
    func listNodes() async throws -> [GatewayNodeSummary]
    func chatHistory(sessionKey: String) async throws -> [GatewayChatMessage]
    func sendMessage(sessionKey: String, text: String) async throws -> GatewayChatMessage
    func abort(sessionKey: String) async throws
    func resetSession(sessionKey: String) async throws
    func compactSession(sessionKey: String) async throws
    func patchSession(sessionKey: String, model: String?, thinking: String?) async throws
    func listChannels() async throws -> [GatewayChannel]
    func toggleChannel(id: String, enabled: Bool) async throws
}

final class LiveGatewayOperatorService: GatewayOperatorService {
    private let transport: GatewayTransport
    private let configurationProvider: () throws -> GatewayConnectionConfiguration
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(
        transport: GatewayTransport,
        configurationProvider: @escaping () throws -> GatewayConnectionConfiguration
    ) {
        self.transport = transport
        self.configurationProvider = configurationProvider
    }

    func connect() async throws {
        try await self.transport.connect(configuration: try self.configurationProvider())
    }

    func listSessions() async throws -> [GatewaySessionSummary] {
        try await self.connect()
        let data = try await self.transport.request(method: "sessions.list", paramsJSON: "{}", timeoutSeconds: 15)
        let response = try self.decoder.decode(LiveGatewaySessionsResponse.self, from: data)
        return response.sessions.map {
            GatewaySessionSummary(
                key: $0.key,
                title: $0.displayTitle)
        }
    }

    func listNodes() async throws -> [GatewayNodeSummary] {
        try await self.connect()
        let data = try await self.transport.request(method: "node.list", paramsJSON: "{}", timeoutSeconds: 15)
        let response = try self.decoder.decode(LiveGatewayNodesResponse.self, from: data)
        return response.nodes.map {
            GatewayNodeSummary(
                id: $0.nodeId,
                name: $0.displayName?.nilIfBlank ?? $0.nodeId,
                capabilityNames: $0.caps ?? [])
        }
    }

    func chatHistory(sessionKey: String) async throws -> [GatewayChatMessage] {
        try await self.connect()
        let params = try self.jsonString(["sessionKey": sessionKey])
        let data = try await self.transport.request(method: "chat.history", paramsJSON: params, timeoutSeconds: 15)
        let response = try self.decoder.decode(LiveGatewayHistoryResponse.self, from: data)
        return response.messages?.enumerated().compactMap { index, message -> GatewayChatMessage? in
            guard let text = message.text.nilIfBlank else { return nil }
            return GatewayChatMessage(
                id: "\(sessionKey):\(index)",
                role: GatewayChatRole(openClawRole: message.role),
                text: text)
        } ?? []
    }

    func sendMessage(sessionKey: String, text: String) async throws -> GatewayChatMessage {
        try await self.connect()
        let params = try self.jsonString([
            "sessionKey": sessionKey,
            "message": text,
            "thinking": "low",
            "timeoutMs": 30000,
            "idempotencyKey": UUID().uuidString,
        ])
        _ = try await self.transport.request(method: "chat.send", paramsJSON: params, timeoutSeconds: 35)
        return GatewayChatMessage(id: UUID().uuidString, role: .user, text: text)
    }

    func abort(sessionKey: String) async throws {
        try await self.connect()
        let params = try self.jsonString(["sessionKey": sessionKey])
        _ = try await self.transport.request(method: "chat.abort", paramsJSON: params, timeoutSeconds: 10)
    }

    func resetSession(sessionKey: String) async throws {
        try await self.connect()
        let params = try self.jsonString(["key": sessionKey])
        _ = try await self.transport.request(method: "sessions.reset", paramsJSON: params, timeoutSeconds: 10)
    }

    func compactSession(sessionKey: String) async throws {
        try await self.connect()
        let params = try self.jsonString(["key": sessionKey])
        _ = try await self.transport.request(method: "sessions.compact", paramsJSON: params, timeoutSeconds: 10)
    }

    func patchSession(sessionKey: String, model: String?, thinking: String?) async throws {
        try await self.connect()
        var params: [String: Any] = ["key": sessionKey]
        if let model {
            params["model"] = model
        }
        if let thinking {
            params["thinking"] = thinking
        }
        let jsonParams = try self.jsonString(params)
        _ = try await self.transport.request(method: "sessions.patch", paramsJSON: jsonParams, timeoutSeconds: 10)
    }

    func listChannels() async throws -> [GatewayChannel] {
        try await self.connect()
        let data = try await self.transport.request(method: "channels.list", paramsJSON: "{}", timeoutSeconds: 15)
        let response = try self.decoder.decode(LiveGatewayChannelsResponse.self, from: data)
        return response.channels.map { ch in
            GatewayChannel(
                id: ch.channelId,
                name: ch.displayName ?? ch.channelId,
                platform: ch.platform ?? "unknown",
                status: GatewayChannel.ChannelStatus(rawValue: ch.status ?? "disconnected") ?? .disconnected,
                enabled: ch.enabled ?? false,
                configuredAt: ch.configuredAt,
                messageCount: ch.messageCount ?? 0)
        }
    }

    func toggleChannel(id: String, enabled: Bool) async throws {
        try await self.connect()
        let params = try self.jsonString(["channelId": id, "enabled": enabled])
        _ = try await self.transport.request(method: "channels.toggle", paramsJSON: params, timeoutSeconds: 10)
    }

    private func jsonString(_ object: [String: Any]) throws -> String {
        let data = try JSONSerialization.data(withJSONObject: object)
        guard let string = String(data: data, encoding: .utf8) else {
            throw GatewayTransportError.invalidResponse("Unable to encode request JSON.")
        }
        return string
    }
}

private struct LiveGatewaySessionsResponse: Decodable {
    let sessions: [LiveGatewaySession]
}

private struct LiveGatewaySession: Decodable {
    let key: String
    let displayName: String?
    let subject: String?
    let room: String?
    let space: String?
    let surface: String?

    var displayTitle: String {
        resolveGatewaySessionTitle(
            key: self.key,
            preferredTitle: self.displayName?.nilIfBlank
                ?? self.subject?.nilIfBlank
                ?? self.room?.nilIfBlank
                ?? self.space?.nilIfBlank
                ?? self.surface?.nilIfBlank)
    }
}

private struct LiveGatewayNodesResponse: Decodable {
    let nodes: [LiveGatewayNode]
}

private struct LiveGatewayNode: Decodable {
    let nodeId: String
    let displayName: String?
    let caps: [String]?
}

private struct LiveGatewayHistoryResponse: Decodable {
    let sessionKey: String
    let messages: [LiveGatewayHistoryMessage]?
}

private struct LiveGatewayHistoryMessage: Decodable {
    let role: String
    let content: LiveGatewayHistoryContent

    var text: String {
        self.content.text
    }
}

private enum LiveGatewayHistoryContent: Decodable {
    case string(String)
    case parts([LiveGatewayHistoryPart])

    var text: String {
        switch self {
        case let .string(value):
            return value
        case let .parts(parts):
            return parts
                .compactMap { $0.text?.nilIfBlank ?? $0.thinking?.nilIfBlank }
                .joined(separator: "\n")
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let text = try? container.decode(String.self) {
            self = .string(text)
            return
        }

        self = .parts(try container.decode([LiveGatewayHistoryPart].self))
    }
}

private struct LiveGatewayHistoryPart: Decodable {
    let type: String?
    let text: String?
    let thinking: String?
}

private struct LiveGatewayChannelsResponse: Decodable {
    let channels: [LiveGatewayChannel]
}

private struct LiveGatewayChannel: Decodable {
    let channelId: String
    let displayName: String?
    let platform: String?
    let status: String?
    let enabled: Bool?
    let configuredAt: Date?
    let messageCount: Int?
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = self.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

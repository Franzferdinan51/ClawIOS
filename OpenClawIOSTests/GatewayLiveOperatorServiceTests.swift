import XCTest
@testable import OpenClawIOS

final class GatewayLiveOperatorServiceTests: XCTestCase {
    func test_connectUsesCurrentGatewayConfiguration() async throws {
        let transport = RecordingGatewayTransport()
        let endpoint = try GatewayEndpoint(userInput: "https://demo.openclaw.ai:18789")
        let service = LiveGatewayOperatorService(
            transport: transport,
            configurationProvider: {
                GatewayConnectionConfiguration(
                    endpoint: endpoint,
                    credentials: .token("demo-token"))
            })

        try await service.connect()

        let configuration = await transport.lastConnectionConfiguration
        XCTAssertEqual(configuration?.endpoint.httpBaseURL.absoluteString, "https://demo.openclaw.ai:18789")
        XCTAssertEqual(configuration?.credentials, .token("demo-token"))
    }

    func test_listSessionsMapsDashboardTitlesWithFallbacks() async throws {
        let transport = RecordingGatewayTransport()
        await transport.setStubbedResponse(
            try Self.jsonData([
            "sessions": [
                [
                    "key": "agent:main",
                    "displayName": "Main Chat"
                ],
                [
                    "key": "agent:ops",
                    "subject": "Ops Room"
                ],
                [
                    "key": "agent:main:main"
                ]
            ]
        ]),
            for: "sessions.list")
        let service = try self.makeService(transport: transport)

        let sessions = try await service.listSessions()

        XCTAssertEqual(
            sessions,
            [
                .init(key: "agent:main", title: "Main Chat"),
                .init(key: "agent:ops", title: "Ops Room"),
                .init(key: "agent:main:main", title: "Main Session")
            ])
    }

    func test_listNodesMapsNodeListPayload() async throws {
        let transport = RecordingGatewayTransport()
        await transport.setStubbedResponse(
            try Self.jsonData([
            "nodes": [
                [
                    "nodeId": "ios-1",
                    "displayName": "Desk iPhone",
                    "caps": ["camera", "voice"]
                ]
            ]
        ]),
            for: "node.list")
        let service = try self.makeService(transport: transport)

        let nodes = try await service.listNodes()

        XCTAssertEqual(
            nodes,
            [
                .init(id: "ios-1", name: "Desk iPhone", capabilityNames: ["camera", "voice"])
            ])
    }

    func test_chatHistoryMapsStringAndStructuredContentToTranscript() async throws {
        let transport = RecordingGatewayTransport()
        await transport.setStubbedResponse(
            try Self.jsonData([
            "sessionKey": "agent:main",
            "messages": [
                [
                    "role": "assistant",
                    "content": "Hello there"
                ],
                [
                    "role": "user",
                    "content": [
                        [
                            "type": "text",
                            "text": "Ping"
                        ]
                    ]
                ]
            ]
        ]),
            for: "chat.history")
        let service = try self.makeService(transport: transport)

        let history = try await service.chatHistory(sessionKey: "agent:main")

        XCTAssertEqual(
            history,
            [
                .init(id: "agent:main:0", role: .assistant, text: "Hello there"),
                .init(id: "agent:main:1", role: .user, text: "Ping")
            ])
    }

    func test_resetAndCompactSessionsForwardGatewayMethods() async throws {
        let transport = RecordingGatewayTransport()
        let service = try self.makeService(transport: transport)

        try await service.resetSession(sessionKey: "agent:main")
        try await service.compactSession(sessionKey: "agent:main")

        let methods = await transport.requestedMethods
        XCTAssertEqual(methods, ["sessions.reset", "sessions.compact"])
    }

    func test_patchSessionSendsModelAndThinkingParams() async throws {
        let transport = RecordingGatewayTransport()
        let service = try self.makeService(transport: transport)

        try await service.patchSession(sessionKey: "agent:main", model: "claude-opus", thinking: "high")

        let methods = await transport.requestedMethods
        XCTAssertEqual(methods, ["sessions.patch"])

        let params = await transport.lastRequestParams
        XCTAssertTrue(params?.contains("\"model\":\"claude-opus\"") ?? false)
        XCTAssertTrue(params?.contains("\"thinking\":\"high\"") ?? false)
    }

    func test_listChannelsMapsChannelPayload() async throws {
        let transport = RecordingGatewayTransport()
        await transport.setStubbedResponse(
            try Self.jsonData([
            "channels": [
                [
                    "channelId": "wa-1",
                    "displayName": "WhatsApp",
                    "platform": "whatsapp",
                    "status": "connected",
                    "enabled": true,
                    "messageCount": 42
                ],
                [
                    "channelId": "tg-1",
                    "displayName": "Telegram",
                    "platform": "telegram",
                    "status": "disconnected",
                    "enabled": false,
                    "messageCount": 0
                ]
            ]
        ]),
            for: "channels.list")
        let service = try self.makeService(transport: transport)

        let channels = try await service.listChannels()

        XCTAssertEqual(channels.count, 2)
        XCTAssertEqual(channels[0].id, "wa-1")
        XCTAssertEqual(channels[0].name, "WhatsApp")
        XCTAssertEqual(channels[0].platform, "whatsapp")
        XCTAssertEqual(channels[0].status, .connected)
        XCTAssertEqual(channels[0].enabled, true)
        XCTAssertEqual(channels[0].messageCount, 42)
        XCTAssertEqual(channels[1].status, .disconnected)
        XCTAssertEqual(channels[1].enabled, false)
    }

    func test_toggleChannelSendsChannelIdAndEnabled() async throws {
        let transport = RecordingGatewayTransport()
        let service = try self.makeService(transport: transport)

        try await service.toggleChannel(id: "wa-1", enabled: false)

        let methods = await transport.requestedMethods
        XCTAssertEqual(methods, ["channels.toggle"])

        let params = await transport.lastRequestParams
        XCTAssertTrue(params?.contains("\"channelId\":\"wa-1\"") ?? false)
        XCTAssertTrue(params?.contains("\"enabled\":false") ?? false)
    }

    private func makeService(transport: RecordingGatewayTransport) throws -> LiveGatewayOperatorService {
        let endpoint = try GatewayEndpoint(userInput: "https://demo.openclaw.ai:18789")
        return LiveGatewayOperatorService(
            transport: transport,
            configurationProvider: {
                GatewayConnectionConfiguration(
                    endpoint: endpoint,
                    credentials: .token("demo-token"))
            })
    }

    private static func jsonData(_ object: Any) throws -> Data {
        try JSONSerialization.data(withJSONObject: object)
    }
}

private actor RecordingGatewayTransport: GatewayTransport {
    var lastConnectionConfiguration: GatewayConnectionConfiguration?
    var stubbedResponses: [String: Data] = [:]
    var requestedMethods: [String] = []
    var lastRequestParams: String?

    func setStubbedResponse(_ data: Data, for method: String) {
        self.stubbedResponses[method] = data
    }

    func connect(configuration: GatewayConnectionConfiguration) async throws {
        self.lastConnectionConfiguration = configuration
    }

    func disconnect() async {}

    func request(method: String, paramsJSON: String?, timeoutSeconds: Int) async throws -> Data {
        self.requestedMethods.append(method)
        self.lastRequestParams = paramsJSON
        return self.stubbedResponses[method] ?? Data("{}".utf8)
    }
}

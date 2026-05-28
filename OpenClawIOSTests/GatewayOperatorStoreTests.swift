import XCTest
@testable import OpenClawIOS

@MainActor
final class GatewayOperatorStoreTests: XCTestCase {
    func test_connectLoadsSessionsAndNodesFromService() async throws {
        let service = MockGatewayOperatorService(
            sessions: [.init(key: "agent:main", title: "Main")],
            nodes: [.init(id: "ios-node", name: "iPhone", capabilityNames: ["screen", "talk"])]
        )
        let store = GatewayOperatorStore(service: service)

        try await store.connect()

        XCTAssertEqual(store.connectionState, .connected)
        XCTAssertEqual(store.sessions.map(\.key), ["agent:main"])
        XCTAssertEqual(store.nodes.map(\.id), ["ios-node"])
    }

    func test_selectSessionLoadsTranscriptHistory() async throws {
        let service = MockGatewayOperatorService(
            sessions: [.init(key: "agent:main", title: "Main")],
            history: [
                "agent:main": [
                    .init(id: "m1", role: .user, text: "hello"),
                    .init(id: "m2", role: .assistant, text: "hi")
                ]
            ]
        )
        let store = GatewayOperatorStore(service: service)

        try await store.connect()
        try await store.selectSession("agent:main")

        XCTAssertEqual(store.transcript.map(\.text), ["hello", "hi"])
    }

    func test_bootstrapConnectsAndSelectsFirstSession() async {
        let service = MockGatewayOperatorService(
            sessions: [.init(key: "agent:main", title: "Main")],
            history: [
                "agent:main": [
                    .init(id: "m1", role: .assistant, text: "ready")
                ]
            ])
        let store = GatewayOperatorStore(service: service)

        await store.bootstrap()

        XCTAssertEqual(store.connectionState, .connected)
        XCTAssertEqual(store.selectedSessionKey, "agent:main")
        XCTAssertEqual(store.transcript.map(\.text), ["ready"])
    }

    func test_sendMessageReloadsTranscriptWithMockAssistantReply() async throws {
        let service = MockGatewayOperatorService(
            sessions: [.init(key: "agent:main", title: "Main")],
            history: [
                "agent:main": [
                    .init(id: "m1", role: .assistant, text: "ready")
                ]
            ])
        let store = GatewayOperatorStore(service: service)

        try await store.connect()
        try await store.selectSession("agent:main")
        try await store.sendMessage("list nodes")

        XCTAssertEqual(
            store.transcript.map(\.text),
            [
                "ready",
                "list nodes",
                "Mock gateway heard: list nodes"
            ])
    }

    func test_resetSessionReloadsHistoryToEmptyState() async throws {
        let service = MockGatewayOperatorService(
            sessions: [.init(key: "agent:main", title: "Main")],
            history: [
                "agent:main": [
                    .init(id: "m1", role: .assistant, text: "ready")
                ]
            ])
        let store = GatewayOperatorStore(service: service)

        try await store.connect()
        try await store.selectSession("agent:main")
        try await store.resetCurrentSession()

        XCTAssertEqual(store.transcript, [])
    }

    func test_compactSessionKeepsLatestTranscriptEntry() async throws {
        let service = MockGatewayOperatorService(
            sessions: [.init(key: "agent:main", title: "Main")],
            history: [
                "agent:main": [
                    .init(id: "m1", role: .assistant, text: "old"),
                    .init(id: "m2", role: .user, text: "newest")
                ]
            ])
        let store = GatewayOperatorStore(service: service)

        try await store.connect()
        try await store.selectSession("agent:main")
        try await store.compactCurrentSession()

        XCTAssertEqual(store.transcript.map(\.text), ["newest"])
    }

    func test_disconnectResetsAllState() async throws {
        let service = MockGatewayOperatorService(
            sessions: [.init(key: "agent:main", title: "Main")],
            nodes: [.init(id: "node1", name: "Test Node", capabilityNames: ["device"])])
        let store = GatewayOperatorStore(service: service)

        try await store.connect()
        try await store.selectSession("agent:main")
        XCTAssertEqual(store.connectionState, .connected)
        XCTAssertNotNil(store.selectedSessionKey)

        store.disconnect()

        XCTAssertEqual(store.connectionState, .disconnected)
        XCTAssertEqual(store.sessions, [])
        XCTAssertEqual(store.nodes, [])
        XCTAssertNil(store.selectedSessionKey)
        XCTAssertEqual(store.transcript, [])
        XCTAssertNil(store.lastErrorMessage)
    }

    func test_clearErrorRemovesErrorMessage() async throws {
        let service = MockGatewayOperatorService(
            sessions: [.init(key: "agent:main", title: "Main")])
        let store = GatewayOperatorStore(service: service)

        try await store.connect()
        store.lastErrorMessage = "Some error"

        store.clearError()

        XCTAssertNil(store.lastErrorMessage)
    }

    func test_patchSessionUpdatesModelAndThinking() async throws {
        let service = MockGatewayOperatorService(
            sessions: [.init(key: "agent:main", title: "Main")])
        let store = GatewayOperatorStore(service: service)

        try await store.connect()
        try await store.selectSession("agent:main")

        try await store.patchCurrentSession(model: "claude-opus", thinking: "high")

        XCTAssertEqual(store.selectedModel, "claude-opus")
        XCTAssertEqual(store.selectedThinking, "high")
    }
}

import XCTest
@testable import OpenClawIOS

final class DebugViewModelTests: XCTestCase {
    func test_canSendRequiresMethodAndSession() {
        let store = GatewayOperatorStore(service: MockGatewayOperatorService(sessions: []))
        let vm = DebugViewModel(store: store)

        XCTAssertFalse(vm.canSend) // no method, no session

        vm.rpcMethod = "sessions.list"
        XCTAssertFalse(vm.canSend) // no session

        store.selectedSessionKey = "agent:main"
        XCTAssertTrue(vm.canSend) // has method + session
    }

    func test_sendRPCSetsLoadingState() async throws {
        let store = GatewayOperatorStore(service: MockGatewayOperatorService(sessions: []))
        let vm = DebugViewModel(store: store)
        store.selectedSessionKey = "agent:main"

        XCTAssertFalse(vm.isLoading)

        // sendRPC with mock transport will fail but sets isLoading
        await vm.sendRPC()

        XCTAssertFalse(vm.isLoading)
        // rpcError should be set since no transport connected
        XCTAssertFalse(vm.rpcError.isEmpty)
    }

    func test_clearResetsAllFields() {
        let store = GatewayOperatorStore(service: MockGatewayOperatorService(sessions: []))
        let vm = DebugViewModel(store: store)

        vm.rpcMethod = "sessions.list"
        vm.rpcParams = "{\"key\":\"agent:main\"}"
        vm.rpcResult = "{\"sessions\":[]}"
        vm.rpcError = "some error"

        vm.clear()

        XCTAssertTrue(vm.rpcMethod.isEmpty)
        XCTAssertEqual(vm.rpcParams, "{}")
        XCTAssertTrue(vm.rpcResult.isEmpty)
        XCTAssertTrue(vm.rpcError.isEmpty)
    }
}
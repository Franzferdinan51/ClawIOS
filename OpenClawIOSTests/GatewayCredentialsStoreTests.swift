import XCTest
@testable import OpenClawIOS

final class GatewayCredentialsStoreTests: XCTestCase {
    func test_roundTripsTokenCredentials() throws {
        let store = GatewayCredentialsStore(storage: InMemoryCredentialStorage())
        let endpoint = try GatewayEndpoint(userInput: "http://127.0.0.1:18789")
        try store.save(.token("secret-token"), for: endpoint)
        XCTAssertEqual(try store.load(for: endpoint), .token("secret-token"))
    }

    func test_roundTripsPasswordCredentials() throws {
        let store = GatewayCredentialsStore(storage: InMemoryCredentialStorage())
        let endpoint = try GatewayEndpoint(userInput: "http://127.0.0.1:18789")
        try store.save(.password("hunter2"), for: endpoint)
        XCTAssertEqual(try store.load(for: endpoint), .password("hunter2"))
    }

    func test_loadReturnsNilForUnsetCredentials() throws {
        let store = GatewayCredentialsStore(storage: InMemoryCredentialStorage())
        let endpoint = try GatewayEndpoint(userInput: "http://127.0.0.1:18789")
        XCTAssertNil(try store.load(for: endpoint))
    }
}

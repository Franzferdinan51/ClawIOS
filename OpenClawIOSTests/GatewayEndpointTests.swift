import XCTest
@testable import OpenClawIOS

final class GatewayEndpointTests: XCTestCase {
    func test_normalizesHTTPGatewayURLAndBuildsWebSocketEndpoint() throws {
        let endpoint = try GatewayEndpoint(userInput: "https://demo.openclaw.ai:18789/")
        XCTAssertEqual(endpoint.httpBaseURL.absoluteString, "https://demo.openclaw.ai:18789")
        XCTAssertEqual(endpoint.webSocketURL.absoluteString, "wss://demo.openclaw.ai:18789")
    }

    func test_rejectsUnsupportedScheme() {
        XCTAssertThrowsError(try GatewayEndpoint(userInput: "ftp://demo.openclaw.ai"))
    }

    func test_acceptsHTTPUrl() throws {
        let endpoint = try GatewayEndpoint(userInput: "http://192.168.1.1:18789")
        XCTAssertEqual(endpoint.httpBaseURL.scheme, "http")
        XCTAssertEqual(endpoint.webSocketURL.scheme, "ws")
    }

    func test_acceptsLocalhost() throws {
        let endpoint = try GatewayEndpoint(userInput: "http://localhost:18789")
        XCTAssertEqual(endpoint.httpBaseURL.host, "localhost")
    }

    func test_acceptsLocalhostWithHttps() throws {
        let endpoint = try GatewayEndpoint(userInput: "https://localhost:18789")
        XCTAssertEqual(endpoint.httpBaseURL.scheme, "https")
        XCTAssertEqual(endpoint.webSocketURL.scheme, "wss")
    }

    func test_endpointEquality() throws {
        let a = try GatewayEndpoint(userInput: "http://127.0.0.1:18789")
        let b = try GatewayEndpoint(userInput: "http://127.0.0.1:18789")
        let c = try GatewayEndpoint(userInput: "http://127.0.0.1:18790")
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }

    func test_userInputTrailingSlashIsStripped() throws {
        let endpoint = try GatewayEndpoint(userInput: "http://127.0.0.1:18789/")
        XCTAssertFalse(endpoint.httpBaseURL.absoluteString.hasSuffix("/"))
    }
}

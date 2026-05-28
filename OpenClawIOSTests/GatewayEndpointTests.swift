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
}

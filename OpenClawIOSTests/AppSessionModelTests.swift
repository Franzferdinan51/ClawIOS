import XCTest
@testable import OpenClawIOS

final class AppSessionModelTests: XCTestCase {
    func test_defaultValuesAreCorrect() {
        let model = AppSessionModel()

        XCTAssertEqual(model.selectedTab, .home)
        XCTAssertEqual(model.gatewayEndpointInput, "http://127.0.0.1:18789")
        XCTAssertEqual(model.gatewayConnectionSummary, "Disconnected")
        XCTAssertEqual(model.gatewayTokenInput, "")
        XCTAssertEqual(model.tailscaleApiKey, "")
    }

    func test_selectedTabCanBeChanged() {
        let model = AppSessionModel()

        model.selectedTab = .chat
        XCTAssertEqual(model.selectedTab, .chat)

        model.selectedTab = .settings
        XCTAssertEqual(model.selectedTab, .settings)
    }

    func test_gatewayEndpointInputCanBeUpdated() {
        let model = AppSessionModel()

        model.gatewayEndpointInput = "http://192.168.1.100:18789"
        XCTAssertEqual(model.gatewayEndpointInput, "http://192.168.1.100:18789")

        model.gatewayEndpointInput = "https://openclaw.ts.net:18789"
        XCTAssertEqual(model.gatewayEndpointInput, "https://openclaw.ts.net:18789")
    }

    func test_gatewayTokenInputCanBeUpdated() {
        let model = AppSessionModel()

        model.gatewayTokenInput = "my-secret-token"
        XCTAssertEqual(model.gatewayTokenInput, "my-secret-token")
    }

    func test_tailscaleApiKeyCanBeUpdated() {
        let model = AppSessionModel()

        model.tailscaleApiKey = "tskey-koclat-ABC123"
        XCTAssertEqual(model.tailscaleApiKey, "tskey-koclat-ABC123")
    }

    func test_gatewayConnectionSummaryCanBeUpdated() {
        let model = AppSessionModel()

        model.gatewayConnectionSummary = "Connected to openclaw.ts.net"
        XCTAssertEqual(model.gatewayConnectionSummary, "Connected to openclaw.ts.net")

        model.gatewayConnectionSummary = "Unauthorized"
        XCTAssertEqual(model.gatewayConnectionSummary, "Unauthorized")
    }
}
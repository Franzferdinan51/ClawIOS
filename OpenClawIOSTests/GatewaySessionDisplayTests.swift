import XCTest
@testable import OpenClawIOS

final class GatewaySessionDisplayTests: XCTestCase {
    func test_resolvesMainSessionName() {
        XCTAssertEqual(resolveGatewaySessionTitle(key: "agent:main:main", preferredTitle: nil), "Main Session")
    }

    func test_resolvesDirectMessageFallback() {
        XCTAssertEqual(
            resolveGatewaySessionTitle(
                key: "agent:ops:discord:direct:duckets",
                preferredTitle: nil),
            "Discord - duckets")
    }

    func test_resolvesGroupFallback() {
        XCTAssertEqual(
            resolveGatewaySessionTitle(
                key: "agent:ops:telegram:group:family-room",
                preferredTitle: nil),
            "Telegram Group")
    }

    func test_prefersSuppliedDisplayTitle() {
        XCTAssertEqual(
            resolveGatewaySessionTitle(
                key: "agent:ops:discord:direct:duckets",
                preferredTitle: "Ops Room"),
            "Ops Room")
    }
}

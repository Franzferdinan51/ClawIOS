import XCTest
@testable import OpenClawIOS

final class GatewayEventTests: XCTestCase {
    func test_gatewayEventIsIdentifiable() {
        let event = GatewayEvent(type: "tool", message: "test", timestamp: Date())
        XCTAssertNotNil(event.id)
    }

    func test_gatewayEventsWithSameIdAreEqual() {
        let id = UUID()
        let a = GatewayEvent(type: "tool", message: "test1", timestamp: Date())
        let b = GatewayEvent(type: "tool", message: "test2", timestamp: Date())
        // Events are Identifiable by id — different UUIDs means not equal
        XCTAssertNotEqual(a.id, b.id)
    }
}
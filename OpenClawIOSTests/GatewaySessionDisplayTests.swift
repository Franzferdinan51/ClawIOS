import XCTest
@testable import OpenClawIOS

final class GatewaySessionDisplayTests: XCTestCase {
    func test_resolvesMainSessionName() {
        XCTAssertEqual(resolveGatewaySessionTitle(key: "agent:main:main", preferredTitle: nil), "Main Session")
    }

    func test_resolvesDirectMessageFallback() {
        XCTAssertEqual(
            resolveGatewaySessionTitle(key: "agent:ops:discord:direct:duckets", preferredTitle: nil),
            "Discord - duckets")
    }

    func test_resolvesGroupFallback() {
        XCTAssertEqual(
            resolveGatewaySessionTitle(key: "agent:ops:telegram:group:family-room", preferredTitle: nil),
            "Telegram Group")
    }

    func test_prefersSuppliedDisplayTitle() {
        XCTAssertEqual(
            resolveGatewaySessionTitle(key: "agent:ops:discord:direct:duckets", preferredTitle: "Ops Room"),
            "Ops Room")
    }

    func test_prefersSuppliedDisplayTitleEvenIfEmpty() {
        XCTAssertEqual(
            resolveGatewaySessionTitle(key: "agent:main:main", preferredTitle: ""),
            "Main Session")
    }

    func test_resolvesCronJobKey() {
        XCTAssertEqual(
            resolveGatewaySessionTitle(key: "cron:daily-report", preferredTitle: nil),
            "Cron Job")
        XCTAssertEqual(
            resolveGatewaySessionTitle(key: "agent:ops:slack:cron:reminder", preferredTitle: nil),
            "Cron Job")
    }

    func test_resolvesSubagent() {
        XCTAssertEqual(
            resolveGatewaySessionTitle(key: "agent:subagent:worker-1", preferredTitle: nil),
            "Subagent")
    }

    func test_channelLabelsCapitalize() {
        XCTAssertEqual(resolveGatewaySessionTitle(key: "agent:main:whatsapp:direct:jane", preferredTitle: nil), "WhatsApp - jane")
        XCTAssertEqual(resolveGatewaySessionTitle(key: "agent:main:slack:group:engineering", preferredTitle: nil), "Slack Group")
        XCTAssertEqual(resolveGatewaySessionTitle(key: "agent:main:telegram:group:devs", preferredTitle: nil), "Telegram Group")
        XCTAssertEqual(resolveGatewaySessionTitle(key: "agent:main:imessage:direct:bob", preferredTitle: nil), "iMessage - bob")
    }

    func test_unknownChannelCapitalizesFirstLetter() {
        XCTAssertEqual(
            resolveGatewaySessionTitle(key: "agent:custom:unknown:direct:user", preferredTitle: nil),
            "Unknown - user")
    }
}
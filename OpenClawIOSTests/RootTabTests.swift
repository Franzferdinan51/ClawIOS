import XCTest
@testable import OpenClawIOS

final class RootTabTests: XCTestCase {
    func test_rootTabLabelsMatchApprovedPhaseOneNavigation() {
        XCTAssertEqual(
            RootTab.allCases.map(\.title),
            ["Home", "Chat", "Nodes", "Device", "Channels", "Activity", "Debug", "Settings"])
    }

    func test_featureScreensExposePhaseOneTitles() {
        XCTAssertEqual(HomeView.screenTitle, "Gateway Overview")
        XCTAssertEqual(ChatView.screenTitle, "Operator Chat")
        XCTAssertEqual(NodesView.screenTitle, "Nodes")
        XCTAssertEqual(DeviceView.screenTitle, "This iPhone")
        XCTAssertEqual(ActivityView.screenTitle, "Activity")
        XCTAssertEqual(DebugView.screenTitle, "Debug")
        XCTAssertEqual(ChannelsView.screenTitle, "Channels")
        XCTAssertEqual(SettingsView.screenTitle, "Gateway Settings")
    }
}

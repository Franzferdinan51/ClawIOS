import XCTest
@testable import OpenClawIOS

final class RootTabTests: XCTestCase {
    func test_rootTabLabelsMatchApprovedPhaseOneNavigation() {
        XCTAssertEqual(
            RootTab.allCases.map(\.title),
            ["Home", "Chat", "Nodes", "Device", "Channels", "Activity", "Settings"])
    }

    func test_featureScreensExposePhaseOneTitles() {
        XCTAssertEqual(HomeView.screenTitle, "Gateway Overview")
        XCTAssertEqual(ChatView.screenTitle, "Operator Chat")
        XCTAssertEqual(NodesView.screenTitle, "Nodes")
        XCTAssertEqual(DeviceView.screenTitle, "This iPhone")
        XCTAssertEqual(SettingsView.screenTitle, "Gateway Settings")
    }
}

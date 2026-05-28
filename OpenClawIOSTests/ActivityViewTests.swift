import XCTest
@testable import OpenClawIOS

final class ActivityViewTests: XCTestCase {
    func test_activityViewHasCorrectScreenTitle() {
        XCTAssertEqual(ActivityView.screenTitle, "Activity")
    }
}
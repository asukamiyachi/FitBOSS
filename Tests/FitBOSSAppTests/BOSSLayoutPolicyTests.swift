import XCTest
@testable import FitBOSSApp

final class BOSSLayoutPolicyTests: XCTestCase {
    func testMinimumWindowKeepsTrainingActionsInCompactMode() {
        // App minimum window: 820×540; a visible sidebar leaves a narrower detail pane.
        XCTAssertTrue(BOSSLayoutPolicy.compactTraining(detailWidth: 820 - 170))
        XCTAssertTrue(BOSSLayoutPolicy.compactTraining(detailWidth: 769))
        XCTAssertFalse(BOSSLayoutPolicy.compactTraining(detailWidth: 770))
        XCTAssertFalse(BOSSLayoutPolicy.compactTraining(detailWidth: 1100))
    }

    func testCompactPreviewHeightIsBoundedForShortAndTallWindows() {
        XCTAssertEqual(BOSSLayoutPolicy.compactCameraHeight(windowHeight: 540), 243, accuracy: 0.001)
        XCTAssertEqual(BOSSLayoutPolicy.compactCameraHeight(windowHeight: 360), 220, accuracy: 0.001)
        XCTAssertEqual(BOSSLayoutPolicy.compactCameraHeight(windowHeight: 1200), 320, accuracy: 0.001)
    }
}

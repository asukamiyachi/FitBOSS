import XCTest
import SwiftUI
import FitBOSSCore
@testable import FitBOSSApp

/// Offline render smoke tests; no camera, real user storage, or cloud calls.
/// These test view construction at target sizes, not keyboard or pixel-perfect clipping.
final class BOSSRenderTests: XCTestCase {
    @MainActor func testHomeAndBattleRenderAtTargetSizesAndAppearances() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let history = WorkoutHistoryStore(persistence: WorkoutHistoryPersistence(fileURL: directory.appendingPathComponent("history.json")))
        let online = OnlineService()
        for size in [CGSize(width: 820, height: 540), CGSize(width: 1200, height: 760), CGSize(width: 1600, height: 1000)] {
            for scheme in [ColorScheme.light, .dark] {
                do {
                    let home = BOSSHomeScreen(historyStore: history, online: online, startWorkout: {}, openCalendar: {}, openBattles: {}, openTeam: {})
                    let battle = BOSSBattleScreen(online: online, openAccount: {}, openTeam: {}, startWorkout: {})
                    for page in [AnyView(home), AnyView(battle)] {
                        let renderer = ImageRenderer(content: page
                            .environment(\.colorScheme, scheme)
                            .frame(width: size.width - 210, height: size.height - 52))
                        XCTAssertNotNil(renderer.cgImage, "\(size) \(scheme)")
                    }
                }
            }
        }
    }
}

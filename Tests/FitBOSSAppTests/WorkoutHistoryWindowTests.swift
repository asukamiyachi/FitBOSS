import Foundation
import XCTest
import FitBOSSCore
@testable import FitBOSSApp

final class WorkoutHistoryWindowTests: XCTestCase {
    @MainActor func testWindowsPreserveEachOthersSessionsAndRestDays() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let persistence = WorkoutHistoryPersistence(fileURL: directory.appendingPathComponent("history.json"))
        let shared = WorkoutHistoryStore(persistence: persistence)
        let firstWindow = ContentView(workoutHistory: shared)
        let secondWindow = ContentView(workoutHistory: shared)
        XCTAssertTrue(firstWindow.workoutHistory.recordPushUps(3))
        XCTAssertTrue(secondWindow.workoutHistory.recordPushUps(5))
        let restDay = WorkoutDay.key(for: Date().addingTimeInterval(-86400))
        XCTAssertTrue(firstWindow.workoutHistory.setRest(on: restDay, enabled: true))
        XCTAssertEqual(secondWindow.workoutHistory.history.sessions.map(\.repetitions), [3, 5])
        XCTAssertTrue(secondWindow.workoutHistory.history.restDateKeys.contains(restDay))
        XCTAssertEqual(try persistence.load(), shared.history)
        let id = try XCTUnwrap(firstWindow.workoutHistory.history.sessions.first?.id)
        XCTAssertTrue(secondWindow.workoutHistory.removeSession(id))
        XCTAssertEqual(firstWindow.workoutHistory.history.sessions.map(\.repetitions), [5])
        XCTAssertEqual(try persistence.load(), shared.history)
    }
}

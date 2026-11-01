import XCTest
@testable import FitBOSSCore

final class WorkoutHistoryTests: XCTestCase {
    private func date(_ key: String) -> Date { WorkoutDay.date(for: key)! }

    func testSessionDeduplicatesAndRestConflictsResolve() {
        var h = WorkoutHistory()
        let id = UUID()
        let now = date("2026-11-05")
        XCTAssertTrue(h.setRest(on: "2026-11-03", enabled: true, now: now))
        XCTAssertTrue(h.addPushUps(15, at: date("2026-11-03"), id: id))
        XCTAssertFalse(h.restDateKeys.contains("2026-11-03"))
        XCTAssertFalse(h.addPushUps(15, at: date("2026-11-03"), id: id))
        XCTAssertFalse(h.addPushUps(0, at: now))
        XCTAssertFalse(h.setRest(on: "2026-11-03", enabled: true, now: now))
        XCTAssertTrue(h.removeSession(id: id))
        XCTAssertFalse(h.removeSession(id: id))
    }

    func testRestDaysAndStreak() {
        var h = WorkoutHistory()
        let now = date("2026-11-04").addingTimeInterval(3600)
        XCTAssertTrue(h.addPushUps(4, at: date("2026-11-01")))
        XCTAssertTrue(h.setRest(on: "2026-11-02", enabled: true, now: now))
        XCTAssertTrue(h.setRest(on: "2026-11-03", enabled: true, now: now))
        XCTAssertTrue(h.addPushUps(5, at: date("2026-11-04")))
        XCTAssertEqual(h.currentWorkoutStreak(asOf: now), 2)
        XCTAssertFalse(h.setRest(on: "2026-11-05", enabled: true, now: now))
        XCTAssertFalse(h.setRest(on: "2026-02-31", enabled: true, now: now))
        XCTAssertTrue(h.setRest(on: "2026-10-31", enabled: true, now: now))
        XCTAssertTrue(h.setRest(on: "2026-10-30", enabled: true, now: now))
        XCTAssertTrue(h.addPushUps(3, at: date("2026-10-29")))
        XCTAssertEqual(h.currentWorkoutStreak(asOf: now), 3)
    }

    func testUnfinishedTodayDoesNotBreakStreak() {
        var h = WorkoutHistory()
        XCTAssertTrue(h.addPushUps(10, at: date("2026-11-03")))
        XCTAssertEqual(h.currentWorkoutStreak(asOf: date("2026-11-04")), 1)
    }

    func testJSTBoundaryAndCodable() throws {
        let f = ISO8601DateFormatter()
        let a = try XCTUnwrap(f.date(from: "2026-11-01T14:59:59Z"))
        let b = try XCTUnwrap(f.date(from: "2026-11-01T15:00:00Z"))
        XCTAssertEqual(WorkoutDay.key(for: a), "2026-11-01")
        XCTAssertEqual(WorkoutDay.key(for: b), "2026-11-02")
        var h = WorkoutHistory()
        XCTAssertTrue(h.addPushUps(12, at: b))
        let copy = try JSONDecoder().decode(WorkoutHistory.self, from: JSONEncoder().encode(h))
        XCTAssertEqual(h, copy)
    }

    func testHistoryDisplayUsesJSTAtMidnightBoundary() throws {
        let iso = ISO8601DateFormatter()
        let before = try XCTUnwrap(iso.date(from: "2026-11-01T14:59:59Z"))
        let after = try XCTUnwrap(iso.date(from: "2026-11-01T15:00:00Z"))

        XCTAssertEqual(WorkoutDay.key(for: before), "2026-11-01")
        XCTAssertEqual(WorkoutDay.key(for: after), "2026-11-02")
        XCTAssertEqual(WorkoutDay.monthTitle(for: after), "2026年11月")
        XCTAssertEqual(WorkoutDay.dateTitle(for: before), "2026年11月1日")
        XCTAssertEqual(WorkoutDay.dateTitle(for: after), "2026年11月2日")
        XCTAssertEqual(WorkoutDay.timeTitle(for: before), "23:59")
        XCTAssertEqual(WorkoutDay.timeTitle(for: after), "00:00")
        XCTAssertEqual(WorkoutDay.dateTimeTitle(for: before), "2026/11/01 23:59")
        XCTAssertEqual(WorkoutDay.dateTimeTitle(for: after), "2026/11/02 00:00")
    }

    func testOfflineElapsed() {
        XCTAssertEqual(OfflineElapsed.text(since: nil), "最終接続時刻は不明")
        let t = date("2026-11-03")
        XCTAssertEqual(OfflineElapsed.text(since: t.addingTimeInterval(-3600), now: t), "1時間前")
        XCTAssertEqual(OfflineElapsed.text(since: t.addingTimeInterval(-86400), now: t), "1日前")
    }
}

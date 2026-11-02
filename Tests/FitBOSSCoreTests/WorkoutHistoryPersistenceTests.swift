import Foundation
import XCTest
@testable import FitBOSSCore

final class WorkoutHistoryPersistenceTests: XCTestCase {
    private let legacyKey = "fitboss.localWorkoutHistory.v1"

    private func temporaryFolder() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("FitBOSS-HistoryTests-" + UUID().uuidString, isDirectory: true)
    }

    private func temporaryDefaults() -> (UserDefaults, String) {
        let name = "FitBOSS-HistoryTests-" + UUID().uuidString
        return (UserDefaults(suiteName: name)!, name)
    }

    func testAtomicFileSaveAndReload() throws {
        let folder = temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let storage = WorkoutHistoryPersistence(fileURL: folder.appendingPathComponent("nested/history.json"))

        XCTAssertEqual(try storage.load(), WorkoutHistory())
        var first = WorkoutHistory()
        XCTAssertTrue(first.addPushUps(12, at: WorkoutDay.date(for: "2026-11-01")!))
        try storage.save(first)
        XCTAssertEqual(try storage.load(), first)

        var second = first
        XCTAssertTrue(second.setRest(on: "2026-11-02", enabled: true, now: WorkoutDay.date(for: "2026-11-03")!))
        try storage.save(second)
        XCTAssertEqual(try storage.load(), second)
        XCTAssertEqual(try JSONDecoder().decode(WorkoutHistory.self, from: Data(contentsOf: storage.fileURL)), second)
    }

    func testCorruptedFileIsNotSilentlyReplaced() throws {
        let folder = temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let file = folder.appendingPathComponent("history.json")
        let badData = Data("not valid workout history".utf8)
        try badData.write(to: file)

        let (defaults, suite) = temporaryDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(try JSONEncoder().encode(WorkoutHistory()), forKey: legacyKey)
        let storage = WorkoutHistoryPersistence(fileURL: file, legacyDefaults: defaults)

        XCTAssertThrowsError(try storage.load())
        XCTAssertEqual(try Data(contentsOf: file), badData)
        XCTAssertNotNil(defaults.data(forKey: legacyKey))
    }

    func testMigrationPreservesOldHistoryThenRemovesLegacyCopy() throws {
        let folder = temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let (defaults, suite) = temporaryDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        var oldHistory = WorkoutHistory()
        XCTAssertTrue(oldHistory.addPushUps(6, at: WorkoutDay.date(for: "2026-11-01")!))
        defaults.set(try JSONEncoder().encode(oldHistory), forKey: legacyKey)
        let storage = WorkoutHistoryPersistence(
            fileURL: folder.appendingPathComponent("nested/history.json"),
            legacyDefaults: defaults
        )
        XCTAssertEqual(try storage.load(), oldHistory)
        XCTAssertNil(defaults.data(forKey: legacyKey))
        XCTAssertEqual(try storage.load(), oldHistory)
    }

    func testFailedMigrationKeepsLegacyData() throws {
        let folder = temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let blocker = folder.appendingPathComponent("not-a-directory")
        try Data("blocker".utf8).write(to: blocker)

        let (defaults, suite) = temporaryDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        let oldData = try JSONEncoder().encode(WorkoutHistory())
        defaults.set(oldData, forKey: legacyKey)

        let storage = WorkoutHistoryPersistence(
            fileURL: blocker.appendingPathComponent("history.json"),
            legacyDefaults: defaults
        )
        XCTAssertThrowsError(try storage.load())
        XCTAssertEqual(defaults.data(forKey: legacyKey), oldData)
    }

    func testInvalidLegacyHistoryDoesNotCreateNewFile() throws {
        let folder = temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let (defaults, suite) = temporaryDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(Data("{bad json}".utf8), forKey: legacyKey)

        let storage = WorkoutHistoryPersistence(
            fileURL: folder.appendingPathComponent("history.json"),
            legacyDefaults: defaults
        )
        XCTAssertThrowsError(try storage.load())
        XCTAssertFalse(FileManager.default.fileExists(atPath: storage.fileURL.path))
        XCTAssertNotNil(defaults.data(forKey: legacyKey))
    }
}

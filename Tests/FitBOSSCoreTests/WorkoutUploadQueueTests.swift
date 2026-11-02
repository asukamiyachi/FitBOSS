import XCTest
@testable import FitBOSSCore

final class WorkoutUploadQueueTests: XCTestCase {
    func testRestartAccountBindingAndAcknowledgment() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("queue.json"), id = UUID()
        var queue = WorkoutUploadQueue()
        queue.enqueue(id, uid: "alice", teamID: "a")
        queue.enqueue(id, uid: "bob", teamID: "b")
        try queue.save(to: url)
        var restored = try WorkoutUploadQueue.load(from: url)
        XCTAssertTrue(restored.contains(id, uid: "alice", teamID: "a"))
        XCTAssertFalse(restored.contains(id, uid: "bob", teamID: "a"))
        XCTAssertFalse(restored.contains(id, uid: "alice", teamID: "b"))
        restored.remove(id)
        try restored.save(to: url)
        XCTAssertTrue(try WorkoutUploadQueue.load(from: url).entries.isEmpty)
    }
    func testCorruptQueueAndWriteFailureDoNotOverwriteFile() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("queue.json")
        let bytes = Data("corrupt".utf8)
        try bytes.write(to: url)
        XCTAssertThrowsError(try WorkoutUploadQueue.load(from: url))
        XCTAssertThrowsError(try WorkoutUploadQueue().save(to: url.appendingPathComponent("child")))
        XCTAssertEqual(try Data(contentsOf: url), bytes)
    }
}

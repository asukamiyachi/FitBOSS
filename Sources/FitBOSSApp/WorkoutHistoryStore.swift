import Combine
import FitBOSSCore
import Foundation

/// On-device first. No Firebase SDK, camera data or cloud writes are used here.
final class WorkoutHistoryStore: ObservableObject {
    @Published private(set) var history: WorkoutHistory
    @Published private(set) var storageError: String?

    private let persistence: WorkoutHistoryPersistence?
    private var queueURL: URL?
    private var queue = WorkoutUploadQueue()

    init(persistence: WorkoutHistoryPersistence? = nil) {
        do {
            let storage = try persistence ?? WorkoutHistoryPersistence.appStorage()
            let saved = try storage.load()
            self.persistence = storage
            self.history = saved
        } catch {
            self.persistence = nil
            self.history = WorkoutHistory()
            self.storageError = "運動記録を読み込めないか、旧データを移行できません。元のデータを保護するため保存を停止しています。"
        }
        do {
            if let persistence = self.persistence {
                let url = persistence.fileURL.deletingLastPathComponent().appendingPathComponent("workout-upload-queue-v2.json")
                queue = try WorkoutUploadQueue.load(from: url)
                queueURL = url
            }
        } catch {
            storageError = "送信待ち記録を読み込めません。元データを保護するため保存を停止しています。"
        }
    }

    func enqueue(sessionID: UUID, uid: String, teamId: String) {
        guard storageError == nil, history.sessions.contains(where: { $0.id == sessionID }) else { return }
        var next = queue
        next.enqueue(sessionID, uid: uid, teamID: teamId)
        persistQueue(next)
    }

    func markSynced(sessionID: UUID, uid: String, teamId: String) {
        guard queue.contains(sessionID, uid: uid, teamID: teamId) else { return }
        var next = queue
        next.remove(sessionID)
        persistQueue(next)
    }

    func pendingSessions(uid: String, for teamId: String) -> [SavedWorkout] {
        history.sessions.filter { queue.contains($0.id, uid: uid, teamID: teamId) }
    }

    private func persistQueue(_ next: WorkoutUploadQueue) {
        guard storageError == nil, let queueURL else { return }
        do { try next.save(to: queueURL); queue = next }
        catch { storageError = "送信待ち記録を保存できません。元の記録を保持しています。" }
    }

    /// Returns false when no positive-count exercise exists or storage is not safe to overwrite.
    @discardableResult
    func recordPushUps(_ count: Int, date: Date = Date()) -> Bool {
        guard storageError == nil else { return false }
        var next = history
        guard next.addPushUps(count, at: date) else { return false }
        return save(next)
    }

    @discardableResult
    func setRest(on dayKey: String, enabled: Bool) -> Bool {
        guard storageError == nil else { return false }
        var next = history
        guard next.setRest(on: dayKey, enabled: enabled) else { return false }
        return save(next)
    }

    @discardableResult
    func removeSession(_ id: UUID) -> Bool {
        guard storageError == nil else { return false }
        var next = history
        guard next.removeSession(id: id) else { return false }
        let removed = save(next)
        if removed {
            var nextQueue = queue
            nextQueue.remove(id)
            persistQueue(nextQueue)
        }
        return removed
    }

    private func save(_ updated: WorkoutHistory) -> Bool {
        guard let persistence else { return false }
        do {
            try persistence.save(updated)
            history = updated
            return true
        } catch {
            // Keep the previous in-memory history and on-disk file unchanged.
            storageError = "運動記録を保存できませんでした。元の記録を保持し、これ以上の保存を停止しました。"
            return false
        }
    }
}

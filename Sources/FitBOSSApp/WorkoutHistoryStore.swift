import Combine
import FitBOSSCore
import Foundation

/// On-device first. No Firebase SDK, camera data or cloud writes are used here.
final class WorkoutHistoryStore: ObservableObject {
    @Published private(set) var history: WorkoutHistory
    @Published private(set) var storageError: String?

    private let persistence: WorkoutHistoryPersistence?

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
        return save(next)
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

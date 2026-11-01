import Combine
import FitBOSSCore
import Foundation

/// On-device first. No Firebase SDK, camera data or cloud writes are used here.
final class WorkoutHistoryStore: ObservableObject {
    @Published private(set) var history: WorkoutHistory
    @Published private(set) var storageError: String?

    private let defaults: UserDefaults
    private let storageKey = "fitboss.localWorkoutHistory.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: storageKey) {
            do {
                history = try JSONDecoder().decode(WorkoutHistory.self, from: data)
            } catch {
                history = WorkoutHistory()
                storageError = "保存済みの運動記録を読み込めません。データを上書きしないため保存を停止しています。"
            }
        } else {
            history = WorkoutHistory()
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
        do {
            let data = try JSONEncoder().encode(updated)
            defaults.set(data, forKey: storageKey)
            history = updated
            return true
        } catch {
            storageError = "運動記録の保存に失敗しました。"
            return false
        }
    }
}

import Foundation

/// Saves only workout summaries (never camera frames) in Application Support.
public struct WorkoutHistoryPersistence {
    public let fileURL: URL
    private let legacyDefaults: UserDefaults?
    private let legacyKey: String

    public init(
        fileURL: URL,
        legacyDefaults: UserDefaults? = nil,
        legacyKey: String = "fitboss.localWorkoutHistory.v1"
    ) {
        self.fileURL = fileURL
        self.legacyDefaults = legacyDefaults
        self.legacyKey = legacyKey
    }

    public static func appStorage() throws -> WorkoutHistoryPersistence {
        let support = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let url = support.appendingPathComponent("FitBOSS", isDirectory: true)
            .appendingPathComponent("workout-history-v1.json")
        return WorkoutHistoryPersistence(fileURL: url, legacyDefaults: .standard)
    }

    /// Never replace unreadable data with an empty history.
    /// An old UserDefaults record is removed only after the new file is written successfully.
    public func load() throws -> WorkoutHistory {
        if FileManager.default.fileExists(atPath: fileURL.path) {
            let data = try Data(contentsOf: fileURL)
            return try JSONDecoder().decode(WorkoutHistory.self, from: data)
        }

        if let oldData = legacyDefaults?.data(forKey: legacyKey) {
            let history = try JSONDecoder().decode(WorkoutHistory.self, from: oldData)
            try save(history)
            legacyDefaults?.removeObject(forKey: legacyKey)
            return history
        }

        return WorkoutHistory()
    }

    /// Atomic replacement preserves the previous file when encoding or writing fails.
    /// Unlike UserDefaults.set, this API reports filesystem errors to its caller.
    public func save(_ history: WorkoutHistory) throws {
        let data = try JSONEncoder().encode(history)
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: fileURL, options: .atomic)
    }
}

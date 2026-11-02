import Foundation

public enum WorkoutDay {
    public static let timeZone = TimeZone(identifier: "Asia/Tokyo")!
    public static var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = timeZone
        c.firstWeekday = 2
        return c
    }
    public static func key(for date: Date) -> String {
        let p = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", p.year!, p.month!, p.day!)
    }
    public static func date(for key: String) -> Date? {
        let p = key.split(separator: "-", omittingEmptySubsequences: false)
        guard p.count == 3, p[0].count == 4, p[1].count == 2, p[2].count == 2,
              let y = Int(p[0]), let m = Int(p[1]), let d = Int(p[2]),
              (1...12).contains(m), (1...31).contains(d),
              let date = calendar.date(from: DateComponents(timeZone: timeZone, year: y, month: m, day: d)),
              self.key(for: date) == key else { return nil }
        return date
    }

    /// All history labels follow the same JST day boundary as date keys,
    /// even if the Mac uses another display time zone.
    public static func monthTitle(for date: Date) -> String {
        formatter("yyyy年M月").string(from: date)
    }

    public static func dateTitle(for date: Date) -> String {
        formatter("yyyy年M月d日").string(from: date)
    }

    public static func timeTitle(for date: Date) -> String {
        formatter("HH:mm").string(from: date)
    }

    public static func dateTimeTitle(for date: Date) -> String {
        formatter("yyyy/MM/dd HH:mm").string(from: date)
    }

    private static func formatter(_ format: String) -> DateFormatter {
        let f = DateFormatter()
        f.calendar = calendar
        f.timeZone = timeZone
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = format
        return f
    }
}

public struct SavedWorkout: Codable, Identifiable, Equatable {
    public let id: UUID
    public let exerciseID: String
    public let repetitions: Int
    public let completedAt: Date
    public init(id: UUID = UUID(), exerciseID: String = "push_up", repetitions: Int, completedAt: Date = Date()) {
        self.id = id
        self.exerciseID = exerciseID
        self.repetitions = repetitions
        self.completedAt = completedAt
    }
    public var dateKey: String { WorkoutDay.key(for: completedAt) }
}

public struct WorkoutHistory: Codable, Equatable {
    public private(set) var sessions: [SavedWorkout]
    public private(set) var restDateKeys: Set<String>
    public init(sessions: [SavedWorkout] = [], restDateKeys: Set<String> = []) {
        self.sessions = sessions
        self.restDateKeys = restDateKeys
    }
    @discardableResult
    public mutating func addPushUps(_ repetitions: Int, at date: Date = Date(), id: UUID = UUID()) -> Bool {
        guard (1...10_000).contains(repetitions), !sessions.contains(where: { $0.id == id }) else { return false }
        sessions.append(SavedWorkout(id: id, repetitions: repetitions, completedAt: date))
        restDateKeys.remove(WorkoutDay.key(for: date))
        return true
    }
    @discardableResult
    public mutating func removeSession(id: UUID) -> Bool {
        let previous = sessions.count
        sessions.removeAll { $0.id == id }
        return sessions.count != previous
    }
    @discardableResult
    public mutating func setRest(on key: String, enabled: Bool, now: Date = Date()) -> Bool {
        guard let day = WorkoutDay.date(for: key),
              day <= WorkoutDay.calendar.startOfDay(for: now) else { return false }
        if enabled {
            guard !sessions.contains(where: { $0.dateKey == key }) else { return false }
            restDateKeys.insert(key)
        } else {
            restDateKeys.remove(key)
        }
        return true
    }
    public func sessions(on key: String) -> [SavedWorkout] {
        sessions.filter { $0.dateKey == key }.sorted { $0.completedAt > $1.completedAt }
    }
    public var completedDays: Set<String> { Set(sessions.map(\.dateKey)) }
    /// Rest days (up to two consecutively) bridge exercise days without increasing the score.
    /// Missing an unfinished current day does not break yesterday's streak.
    public func currentWorkoutStreak(asOf now: Date = Date()) -> Int {
        let cal = WorkoutDay.calendar
        let active = completedDays
        var day = cal.startOfDay(for: now)
        var score = 0
        var rests = 0
        for i in 0..<3650 {
            let key = WorkoutDay.key(for: day)
            if active.contains(key) { score += 1; rests = 0 }
            else if restDateKeys.contains(key) { rests += 1; if rests > 2 { break } }
            else if i != 0 { break }
            guard let prev = cal.date(byAdding: .day, value: -1, to: day) else { break }
            day = prev
        }
        return score
    }
}

public enum OfflineElapsed {
    public static func text(since: Date?, now: Date = Date()) -> String {
        guard let since else { return "最終接続時刻は不明" }
        let seconds = max(0, now.timeIntervalSince(since))
        if seconds < 60 { return "1分未満前" }
        if seconds < 3600 { return "\(Int(seconds / 60))分前" }
        if seconds < 86400 { return "\(Int(seconds / 3600))時間前" }
        return "\(Int(seconds / 86400))日前"
    }
}

import Foundation
public struct TeamPresence: Identifiable, Equatable {
    public let uid: String
    public let online: Bool
    public let lastOfflineAt: Date?
    public var id: String { uid }
    public init(uid: String, online: Bool, lastOfflineAt: Date?) {
        self.uid = uid; self.online = online; self.lastOfflineAt = lastOfflineAt
    }
    public func label(asOf date: Date = Date()) -> String {
        if online { return "オンライン" }
        return "オフライン（\(OfflineElapsed.text(since: lastOfflineAt, now: date))）"
    }
}
public struct TeamRank: Identifiable, Equatable {
    public let uid: String
    public let participationDays: Int
    public var id: String { uid }
    public init(uid: String, participationDays: Int) {
        self.uid = uid; self.participationDays = participationDays
    }
}

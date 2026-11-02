import Foundation

/// Only explicit completions while signed in and in a team enter this queue.
/// Account and team binding prevents a later account from claiming old sessions.
public struct WorkoutUploadQueue: Codable, Equatable {
    public struct Destination: Codable, Equatable {
        public let uid: String
        public let teamID: String
    }
    public private(set) var entries: [String: Destination] = [:]
    public init() {}
    public mutating func enqueue(_ sessionID: UUID, uid: String, teamID: String) {
        guard entries[sessionID.uuidString] == nil else { return }
        entries[sessionID.uuidString] = Destination(uid: uid, teamID: teamID)
    }
    public func contains(_ sessionID: UUID, uid: String, teamID: String) -> Bool {
        entries[sessionID.uuidString] == Destination(uid: uid, teamID: teamID)
    }
    public mutating func remove(_ sessionID: UUID) { entries.removeValue(forKey: sessionID.uuidString) }
    public static func load(from url: URL) throws -> Self {
        guard FileManager.default.fileExists(atPath: url.path) else { return Self() }
        return try JSONDecoder().decode(Self.self, from: Data(contentsOf: url))
    }
    public func save(to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(self).write(to: url, options: .atomic)
    }
}

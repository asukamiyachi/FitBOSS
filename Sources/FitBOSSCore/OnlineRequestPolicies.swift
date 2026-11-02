import Foundation

/// Tracks overlapping mutating requests without treating read-only refreshes as UI work.
public struct OnlineMutationTracker {
    private var inFlight: Set<UUID> = []
    public init() {}
    public var isWorking: Bool { !inFlight.isEmpty }
    @discardableResult
    public mutating func begin() -> UUID {
        let token = UUID()
        inFlight.insert(token)
        return token
    }
    public mutating func end(_ token: UUID) {
        inFlight.remove(token)
    }
}

public enum OnlineRequestPolicies {
    public static let teamRefreshInterval: TimeInterval = 180

    /// Background or unrelated screens must never refresh the expensive team overview.
    public static func shouldRefreshTeam(
        appIsActive: Bool, teamScreenVisible: Bool, signedIn: Bool, hasTeam: Bool
    ) -> Bool {
        appIsActive && teamScreenVisible && signedIn && hasTeam
    }

    /// Only an authoritative team overview permission denial for the same session
    /// means that a previously selected team is no longer accessible.
    public static func shouldClearTeamSelection(
        operation: String, permissionDenied: Bool,
        requestUID: String?, currentUID: String?,
        requestTeamID: String?, currentTeamID: String?
    ) -> Bool {
        operation == "getTeamOverview" && permissionDenied &&
        requestUID != nil && requestUID == currentUID &&
        requestTeamID != nil && requestTeamID == currentTeamID
    }
}

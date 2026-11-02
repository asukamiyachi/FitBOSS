import XCTest
@testable import FitBOSSCore

final class OnlineRequestPoliciesTests: XCTestCase {
    func testOverlappingMutationsCannotReenableUIAfterOneCompletion() {
        var tracker = OnlineMutationTracker()
        let create = tracker.begin()
        let leave = tracker.begin()
        XCTAssertTrue(tracker.isWorking)
        tracker.end(create)
        XCTAssertTrue(tracker.isWorking, "A second mutation is still in flight")
        tracker.end(create) // Duplicate callback must not affect another request.
        XCTAssertTrue(tracker.isWorking)
        tracker.end(leave)
        XCTAssertFalse(tracker.isWorking)
    }

    func testReadOnlyRefreshDoesNotBlockMutations() {
        var tracker = OnlineMutationTracker()
        XCTAssertFalse(tracker.isWorking)
        let mutation = tracker.begin()
        XCTAssertTrue(tracker.isWorking)
        tracker.end(mutation)
        XCTAssertFalse(tracker.isWorking)
    }

    func testTeamRefreshOnlyWhenForegroundAndVisible() {
        let p = OnlineRequestPolicies.self
        XCTAssertEqual(p.teamRefreshInterval, 180)
        XCTAssertTrue(p.shouldRefreshTeam(appIsActive: true, teamScreenVisible: true, signedIn: true, hasTeam: true))
        XCTAssertFalse(p.shouldRefreshTeam(appIsActive: false, teamScreenVisible: true, signedIn: true, hasTeam: true))
        XCTAssertFalse(p.shouldRefreshTeam(appIsActive: true, teamScreenVisible: false, signedIn: true, hasTeam: true))
        XCTAssertFalse(p.shouldRefreshTeam(appIsActive: true, teamScreenVisible: true, signedIn: false, hasTeam: true))
        XCTAssertFalse(p.shouldRefreshTeam(appIsActive: true, teamScreenVisible: true, signedIn: true, hasTeam: false))
    }

    func testRevokedTeamOnlyClearsSameSessionsAuthoritativeOverviewFailure() {
        let p = OnlineRequestPolicies.self
        func shouldClear(_ operation: String, _ denied: Bool, _ requestUID: String?, _ currentUID: String?, _ requestTeam: String?, _ currentTeam: String?) -> Bool {
            p.shouldClearTeamSelection(
                operation: operation, permissionDenied: denied,
                requestUID: requestUID, currentUID: currentUID,
                requestTeamID: requestTeam, currentTeamID: currentTeam
            )
        }
        XCTAssertTrue(shouldClear("getTeamOverview", true, "alice", "alice", "team1", "team1"))
        XCTAssertFalse(shouldClear("getTeamOverview", false, "alice", "alice", "team1", "team1"), "Network/transient failures must not remove membership")
        XCTAssertFalse(shouldClear("getRoomProgress", true, "alice", "alice", "team1", "team1"), "Room authorization is not team membership")
        XCTAssertFalse(shouldClear("getTeamOverview", true, "alice", "bob", "team1", "team1"), "Old user response")
        XCTAssertFalse(shouldClear("getTeamOverview", true, "alice", "alice", "team1", "team2"), "Old team response")
        XCTAssertFalse(shouldClear("getTeamOverview", true, nil, nil, "team1", "team1"))
        XCTAssertFalse(shouldClear("getTeamOverview", true, "alice", "alice", nil, nil))
    }
}

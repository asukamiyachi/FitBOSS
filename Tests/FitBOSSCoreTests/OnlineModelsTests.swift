import XCTest
@testable import FitBOSSCore

final class OnlineModelsTests: XCTestCase {
    func testLastOfflineAndUnknownTime() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        XCTAssertEqual(TeamPresence(uid:"a",online:true,lastOfflineAt:now.addingTimeInterval(-60)).label(asOf:now),"オンライン")
        XCTAssertEqual(TeamPresence(uid:"a",online:false,lastOfflineAt:nil).label(asOf:now),"オフライン（最終接続時刻は不明）")
        XCTAssertEqual(TeamPresence(uid:"a",online:false,lastOfflineAt:now.addingTimeInterval(-3600)).label(asOf:now),"オフライン（1時間前）")
    }
    func testTeamRankingModelIsValueOnly() {
        let rank=TeamRank(uid:"member",participationDays:3)
        XCTAssertEqual(rank.id,"member")
        XCTAssertEqual(rank.participationDays,3)
    }
}

import Foundation

/// Derived presentation only. Server authorization and persistence remain authoritative.
enum BOSSPresentation {
    enum BattleAvailability: Equatable {
        case offline, signedOut, noTeam, ready
        var message: String {
            switch self {
            case .offline: "このビルドではオンライン機能を利用できません。ローカル練習は利用できます。"
            case .signedOut: "対戦にはGoogleログインが必要です。"
            case .noTeam: "対戦にはチームへの参加が必要です。"
            case .ready: "招待制ルームを作成・参加できます。サーバー接続は操作の応答をご確認ください。"
            }
        }
        var actionTitle: String {
            switch self { case .offline: "ローカル練習へ"; case .signedOut: "アカウントへ"; case .noTeam: "チームへ"; case .ready: "ルームを作成・参加" }
        }
    }
    static func battleAvailability(configured: Bool, signedIn: Bool, hasTeam: Bool) -> BattleAvailability {
        if !configured { return .offline }
        if !signedIn { return .signedOut }
        return hasTeam ? .ready : .noTeam
    }
    static func saveUnavailableReason(count: Int, storageError: String?) -> String? {
        if let storageError { return "保存できません：\(storageError)" }
        return count > 0 ? nil : "1回以上計測すると「完了して記録」が使えます。"
    }
}

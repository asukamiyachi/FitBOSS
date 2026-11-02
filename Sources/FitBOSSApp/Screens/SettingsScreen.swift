import SwiftUI

// Settings: current auth status and user-facing privacy disclosures.
struct SettingsScreen: View {
    @ObservedObject var online: OnlineService
    var body: some View {
        ScreenLayout(title: "設定", subtitle: "認証とプライバシー") {
            InformationPanel(title: "Googleアカウント", icon: "person.crop.circle") {
                if online.signedIn {
                    Text("Googleで認証済み").foregroundStyle(.green)
                    if let uid = online.uid { Text("UID：\(uid)").textSelection(.enabled) }
                    Button("ログアウト") { online.signOut() }
                        .disabled(online.isWorking)
                } else {
                    Text(online.configured ? "ログインしていません。" : "Firebase SDKまたはGoogleService-Info.plistが未設定です。")
                        .foregroundStyle(.secondary)
                    Button("Googleでログイン") { online.signIn() }
                        .buttonStyle(.borderedProminent)
                        .disabled(!online.configured || online.isWorking)
                }
                if let error = online.errorMessage {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }
            InformationPanel(title: "プライバシー", icon: "hand.raised.fill") {
                Label("カメラ映像と関節座標はこのMacで処理", systemImage: "checkmark.shield")
                Label("Google認証が必要なチーム・対戦はサーバーで権限を検証", systemImage: "lock.shield")
                Label("所属チームのメンバーには接続状態とオフライン経過時間が見えます", systemImage: "person.3")
                Label("ログイン・チーム参加中の運動完了時は回数と日時をFirebaseに送信します", systemImage: "arrow.up.doc")
                Label("カメラ映像・関節情報は送信しません", systemImage: "video.slash")
                Text("公開・非公開の切り替えは提供しません。チームに参加する前に共有内容を確認してください。")
                    .font(.caption).foregroundStyle(.secondary)
            }
            InformationPanel(title: "計測について", icon: "info.circle") {
                Text("腕立てのカウントは2Dの姿勢推定による試験値です。運動フォームや運動強度の正確さを保証しません。")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

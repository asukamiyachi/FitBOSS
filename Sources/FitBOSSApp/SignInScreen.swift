import SwiftUI
#if FITBOSS_FIREBASE_ENABLED
import GoogleSignInSwift
#endif

/// Optional account entry. Local practice always remains available.
struct SignInScreen: View {
    @ObservedObject var online: OnlineService
    let continueLocally: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(online.signedIn ? "Googleログインが完了しました" : "仲間との運動を、ここから。")
                        .font(.largeTitle.bold())
                        .accessibilityAddTraits(.isHeader)
                    Text(online.signedIn ? "Googleアカウントでログインしています。" : "Googleでログインして、チームへの参加やオンライン対戦を始めましょう。")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Divider()
                if online.signedIn {
                    Label("Googleログイン済み", systemImage: "checkmark.circle.fill")
                        .font(.headline).foregroundStyle(BOSSTheme.mint)
                    if let name = online.displayName, !name.isEmpty { Text(name).font(.title2.weight(.semibold)) }
                    if let email = online.accountEmail { Text(email).font(.callout).textSelection(.enabled) }
                    LabeledContent("Realtime Database", value: online.databaseStatus)
                        .font(.callout)
                    Text("チーム・対戦機能にはサーバーの準備も必要です。")
                        .font(.callout).foregroundStyle(.secondary)
                    Button("ホームへ進む", action: continueLocally)
                        .buttonStyle(.borderedProminent).controlSize(.large)
                    Button("ログアウト", action: online.signOut)
                        .disabled(online.isSigningIn)
                } else {
                    VStack(alignment: .leading, spacing: 16) {
                        #if FITBOSS_FIREBASE_ENABLED
                        GoogleSignInButton(
                            scheme: colorScheme == .dark ? .dark : .light,
                            style: .wide,
                            state: online.isSigningIn || !online.configured ? .disabled : .normal,
                            action: online.signIn
                        )
                        .frame(width: 240, height: 44)
                        .accessibilityLabel("Googleでログイン")
                        .accessibilityHint("ブラウザでGoogleアカウントを選択します")
                        #else
                        Button("Googleでログイン", action: online.signIn)
                            .controlSize(.large).disabled(true)
                        #endif
                        if online.isSigningIn {
                            HStack(spacing: 10) {
                                ProgressView().controlSize(.small)
                                Text("ブラウザでログインを完了してください。")
                            }
                            .accessibilityElement(children: .combine)
                        } else {
                            Text("ブラウザでGoogleアカウントを選択します。")
                                .font(.callout).foregroundStyle(.secondary)
                        }
                        if !online.configured {
                            Label("オンライン接続の設定を準備中です。ローカル練習は利用できます。", systemImage: "info.circle")
                                .font(.callout).foregroundStyle(.secondary)
                        }

                    }
                }
                if let message = online.signInMessage ?? online.errorMessage {
                    Label(message, systemImage: "info.circle")
                        .font(.callout).fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                }
                VStack(alignment: .leading, spacing: 14) {
                    Label("映像と関節座標は、このMacの中だけで処理します。", systemImage: "video.slash")
                    Label("チーム参加中は、メンバー間で接続状態と最終オフラインからの経過時間を共有します。", systemImage: "person.2")
                    Text("ログインだけではチームに参加しません。共有内容は、チーム参加前にも確認できます。")
                        .font(.callout).foregroundStyle(.secondary)
                }
                .fixedSize(horizontal: false, vertical: true)
                if !online.signedIn {
                    Divider()
                    Button("ログインせずにローカル練習へ", action: continueLocally)
                        .controlSize(.large)
                    Text("カメラでの計測と、このMacへの運動記録の保存が使えます。")
                        .font(.callout).foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: 580, alignment: .leading)
            .padding(36)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .background(BOSSTheme.canvas)
        .foregroundStyle(BOSSTheme.primary)
        .navigationTitle(online.signedIn ? "アカウント" : "ログイン")
    }
}

import SwiftUI

// Team: membership, presence and participation ranking.
struct TeamScreen: View {
    @ObservedObject var online: OnlineService
    @State private var invitationCode = ""
    @State private var newTeamName = ""
    @State private var rankingPeriod = "week"
    private var canUseOnline: Bool { online.configured && online.signedIn && !online.isWorking }

    var body: some View {
        ScreenLayout(title: "チーム", subtitle: "招待制のチーム。接続状態とオフライン経過時間をメンバー間で共有します。") {
            if !online.configured {
                BOSSInlineNotice(message: "このビルドではオンライン機能を利用できません。ローカル練習は利用できます。", symbol: "wifi.slash", tint: BOSSTheme.warning)
            } else if !online.signedIn {
                BOSSInlineNotice(message: "チームの作成・参加には、アカウント画面からGoogleログインが必要です。", symbol: "person.crop.circle", tint: BOSSTheme.warning)
            }
            if online.isWorking { ProgressView("処理中…") }
            if let error = online.errorMessage {
                BOSSInlineNotice(message: error, symbol: "exclamationmark.triangle.fill", tint: BOSSTheme.error)
            }
            InformationPanel(title: "チームを作成・参加", icon: "person.badge.plus") {
                Text("参加中はチームメンバーに「オンライン」または最後にオフラインになった時刻からの経過時間が見えます。公開・非公開切り替えはありません。チームを抜けると相互のアクセスが無効になります。")
                    .font(.caption).foregroundStyle(.secondary)
                if let id = online.teamId {
                    Text("参加中：\(id)").textSelection(.enabled)
                    if let code = online.teamInviteCode {
                        LabeledContent("チーム招待コード", value: code)
                    }
                    Button("チームから退出") { online.leaveTeam() }
                        .disabled(!canUseOnline)
                    Text("オーナーの退出は現在未対応です。")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    TextField("新しいチーム名", text: $newTeamName)
                        .textFieldStyle(.roundedBorder).frame(maxWidth: 370)
                    Button("チームを作成") { online.createTeam(name: newTeamName) }
                        .disabled(!canUseOnline || newTeamName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    Divider()
                    TextField("チーム招待コード", text: $invitationCode)
                        .textFieldStyle(.roundedBorder).frame(maxWidth: 370)
                    Button("招待コードで参加") { online.joinTeam(code: invitationCode) }
                        .disabled(!canUseOnline || invitationCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            InformationPanel(title: "メンバーの接続状況", icon: "circle.dotted.circle") {
                if online.members.isEmpty {
                    Text("チーム参加・サーバー接続後に表示します。").foregroundStyle(.secondary)
                }
                ForEach(online.members) { member in
                    HStack {
                        Text(member.uid == online.uid ? "自分" : "メンバー \(member.uid.prefix(8))")
                        Spacer()
                        TimelineView(.periodic(from: .now, by: 60)) { timeline in
                            Text(member.label(asOf: timeline.date))
                                .foregroundStyle(member.online ? BOSSTheme.mint : BOSSTheme.muted)
                        }
                    }
                }
                Text("接続状態はFitBOSSアプリの通信状態であり、運動中・端末の電源状態・現在地ではありません。")
                    .font(.caption).foregroundStyle(.secondary)
            }
            InformationPanel(title: "チーム内ランキング", icon: "chart.bar.xaxis") {
                Picker("集計期間", selection: $rankingPeriod) {
                    Text("今週").tag("week")
                    Text("今月").tag("month")
                }
                .pickerStyle(.segmented).frame(maxWidth: 260)
                .onChange(of: rankingPeriod) { _, next in online.loadTeam(period: next) }
                if online.ranking.isEmpty {
                    Text("集計可能な記録はありません。").foregroundStyle(.secondary)
                }
                ForEach(Array(online.ranking.indices), id: \.self) { index in
                    HStack {
                        Text("\(index + 1)位")
                            .font(.subheadline.monospacedDigit())
                        Text(online.ranking[index].uid == online.uid ? "自分" : "メンバー \(online.ranking[index].uid.prefix(8))")
                        Spacer()
                        Text("\(online.ranking[index].participationDays)日").monospacedDigit()
                    }
                }
                Text("運動に参加した日数を集計します。1日に複数回運動しても1日分、休息日は減点しません。動作の正確さを保証するランキングではありません。")
                    .font(.caption).foregroundStyle(.secondary)
                Button("最新の情報に更新") { online.loadTeam(period: rankingPeriod) }
                    .disabled(!canUseOnline || online.teamId == nil)
            }
        }
    }
}

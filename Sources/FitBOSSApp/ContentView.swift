import SwiftUI
import FitBOSSCore

// Local practice remains available independently of optional online authentication.
private enum FitBOSSPage: String, CaseIterable, Identifiable {
    case account, home, workout, history, battles, team, achievements, settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .account: "ログイン・アカウント"
        case .home: "ホーム"
        case .workout: "トレーニング"
        case .history: "履歴カレンダー"
        case .battles: "対戦"
        case .team: "チーム"
        case .achievements: "実績"
        case .settings: "設定"
        }
    }

    var symbol: String {
        switch self {
        case .account: "person.crop.circle"
        case .home: "house.fill"
        case .workout: "figure.strengthtraining.traditional"
        case .history: "calendar"
        case .battles: "bolt.fill"
        case .team: "person.3.fill"
        case .achievements: "medal.fill"
        case .settings: "gearshape.fill"
        }
    }
}

struct ContentView: View {
    @State private var selection: FitBOSSPage? = .account
    @StateObject private var online = OnlineService()
    @ObservedObject var workoutHistory: WorkoutHistoryStore

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Section {
                    ForEach([
                        FitBOSSPage.home, .workout, .history, .battles,
                        .team, .achievements, .settings
                    ]) { page in
                        Label(page.title, systemImage: page.symbol)
                            .tag(page)
                    }
                } header: {
                    Label("FitBOSS", systemImage: "bolt.heart.fill")
                        .font(.headline.bold())
                }
                Section("アカウント") {
                    Label(FitBOSSPage.account.title, systemImage: FitBOSSPage.account.symbol)
                        .tag(FitBOSSPage.account)
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("FitBOSS")
            .navigationSplitViewColumnWidth(min: 170, ideal: 210, max: 260)
        } detail: {
            switch selection ?? .home {
            case .account:
                SignInScreen(online: online, continueLocally: { selection = .home })
            case .home:
                BOSSHomeScreen(
                    historyStore: workoutHistory,
                    online: online,
                    startWorkout: { selection = .workout },
                    openCalendar: { selection = .history },
                    openBattles: { selection = .battles },
                    openTeam: { selection = .team }
                )
            case .workout:
                WorkoutCameraView(historyStore: workoutHistory, online: online)
            case .history:
                WorkoutCalendarView(store: workoutHistory)
            case .battles:
                BOSSBattleScreen(online: online)
            case .team:
                TeamScreen(online: online)
            case .achievements:
                AchievementsScreen()
            case .settings:
                SettingsScreen(online: online)
            }
        }
        .navigationSplitViewStyle(.balanced)
        .tint(BOSSTheme.violet)
        .onReceive(Timer.publish(every: 3, on: .main, in: .common).autoconnect()) { _ in
            if selection == .battles, NSApp.isActive, online.signedIn,
               ["waiting", "active"].contains(online.roomPhase ?? "") {
                online.refreshRoomProgress()
            }
        }
        .onChange(of: online.teamId) { _ in uploadPendingWorkouts() }
        .onChange(of: selection) { _, page in
            if OnlineRequestPolicies.shouldRefreshTeam(
                appIsActive: NSApp.isActive, teamScreenVisible: page == .team,
                signedIn: online.signedIn, hasTeam: online.teamId != nil
            ) {
                online.loadTeam()
            }
        }
        .onReceive(Timer.publish(every: OnlineRequestPolicies.teamRefreshInterval, on: .main, in: .common).autoconnect()) { _ in
            guard NSApp.isActive, online.signedIn, online.teamId != nil else { return }
            if OnlineRequestPolicies.shouldRefreshTeam(
                appIsActive: true, teamScreenVisible: selection == .team,
                signedIn: online.signedIn, hasTeam: true
            ) {
                online.loadTeam()
            }
            // Retry only previously queued uploads. No periodic team reads on unrelated screens.
            uploadPendingWorkouts()
        }
    }

    private func uploadPendingWorkouts() {
        guard online.signedIn, let uid = online.uid, let teamId = online.teamId else { return }
        for session in workoutHistory.pendingSessions(uid: uid, for: teamId).prefix(5) {
            online.submitWorkout(session) {
                workoutHistory.markSynced(sessionID: session.id, uid: uid, teamId: teamId)
            }
        }
    }
}

private struct ScreenLayout<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(title).font(.largeTitle.bold())
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                content
            }
            .frame(maxWidth: 1040, alignment: .leading)
            .padding(28)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .navigationTitle(title)
    }
}

private struct StatisticCard: View {
    let title: String
    let value: String
    let detail: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .monospacedDigit()
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 118, alignment: .topLeading)
        .padding(16)
        .background(Color.secondary.opacity(0.09), in: RoundedRectangle(cornerRadius: 14))
    }
}

private struct InformationPanel<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(title, systemImage: icon)
                .font(.title3.weight(.semibold))
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 16))
    }
}

private struct TeamScreen: View {
    @ObservedObject var online: OnlineService
    @State private var invitationCode = ""
    @State private var newTeamName = ""
    @State private var rankingPeriod = "week"
    private var canUseOnline: Bool { online.configured && online.signedIn && !online.isWorking }

    var body: some View {
        ScreenLayout(title: "チーム", subtitle: "招待制のチーム。接続状態とオフライン経過時間をメンバー間で共有します。") {
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
                                .foregroundStyle(member.online ? Color.green : Color.secondary)
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

private struct BadgeDefinition: Identifiable {
    let title: String
    let description: String
    let symbol: String
    var id: String { title }
}

private struct AchievementsScreen: View {
    private let badges: [BadgeDefinition] = [
        .init(title: "はじめの一歩", description: "初回トレーニング完了", symbol: "figure.walk"),
        .init(title: "チームメイト", description: "チームに初参加", symbol: "person.3.fill"),
        .init(title: "初対戦", description: "初めてのオンライン対戦", symbol: "bolt.fill"),
        .init(title: "自分のペース", description: "休息も大切にする継続記録", symbol: "heart.text.square")
    ]

    var body: some View {
        ScreenLayout(
            title: "バッジ・実績",
            subtitle: "努力の積み重ねを可視化します。過度な運動を競う設計にはしません。"
        ) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 14)], spacing: 14) {
                ForEach(badges) { badge in
                    VStack(alignment: .leading, spacing: 12) {
                        Image(systemName: badge.symbol)
                            .font(.system(size: 32))
                            .foregroundStyle(.secondary)
                            .frame(height: 44)
                        Text(badge.title).font(.headline)
                        Text(badge.description)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Label("未獲得", systemImage: "lock.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 144, alignment: .topLeading)
                    .padding(20)
                    .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
                }
            }
            Text("バッジの判定・保存は今後実装します。現段階で実際に獲得できるバッジはありません。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct SettingsScreen: View {
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

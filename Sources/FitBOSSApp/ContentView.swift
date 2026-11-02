import SwiftUI
import FitBOSSCore

// This shell is intentionally independent of Firebase and exercise scoring.
// Online actions remain unavailable until authentication and access rules exist.
private enum FitBOSSPage: String, CaseIterable, Identifiable {
    case home, workout, history, battles, team, achievements, settings

    var id: String { rawValue }

    var title: String {
        switch self {
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
    @State private var selection: FitBOSSPage? = .home
    @StateObject private var online = OnlineService()
    @StateObject private var workoutHistory = WorkoutHistoryStore()

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Section("メニュー") {
                    ForEach(FitBOSSPage.allCases) { page in
                        Label(page.title, systemImage: page.symbol)
                            .tag(page)
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("FitBOSS")
            .navigationSplitViewColumnWidth(min: 170, ideal: 210, max: 260)
        } detail: {
            switch selection ?? .home {
            case .home:
                HomeScreen(
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
                BattleScreen(online: online)
            case .team:
                TeamScreen(online: online)
            case .achievements:
                AchievementsScreen()
            case .settings:
                SettingsScreen(online: online)
            }
        }
        .navigationSplitViewStyle(.balanced)
        .onReceive(Timer.publish(every: 3, on: .main, in: .common).autoconnect()) { _ in
            if selection == .battles, NSApp.isActive, online.signedIn,
               ["waiting", "active"].contains(online.roomPhase ?? "") {
                online.refreshRoomProgress()
            }
        }
        .onChange(of: online.teamId) { _ in uploadPendingWorkouts() }
        .onReceive(Timer.publish(every: 30, on: .main, in: .common).autoconnect()) { _ in
            if online.signedIn && online.teamId != nil {
                online.loadTeam()
                uploadPendingWorkouts()
            }
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

private struct HomeScreen: View {
    @ObservedObject var historyStore: WorkoutHistoryStore
    @ObservedObject var online: OnlineService
    let startWorkout: () -> Void
    let openCalendar: () -> Void
    let openBattles: () -> Void
    let openTeam: () -> Void

    private var latestSessions: [FitBOSSCore.SavedWorkout] {
        Array(historyStore.history.sessions.sorted { $0.completedAt > $1.completedAt }.prefix(3))
    }

    var body: some View {
        ScreenLayout(
            title: "ホーム",
            subtitle: "自分のペースで運動し、仲間と進捗を共有しよう。"
        ) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 200), spacing: 12)], spacing: 12) {
                StatisticCard(
                    title: "継続記録",
                    value: historyStore.history.sessions.isEmpty ? "—" : "\(historyStore.history.currentWorkoutStreak())日",
                    detail: "運動日数のみ／休息日最大2日で継続",
                    icon: "calendar"
                )
                StatisticCard(title: "対戦記録", value: "—", detail: "対戦履歴の連携後に表示", icon: "bolt.fill")
                StatisticCard(title: "チーム", value: online.teamId == nil ? "未参加" : "参加中", detail: online.signedIn ? "チーム内のみ共有" : "Googleログインが必要", icon: "person.3")
                StatisticCard(title: "獲得バッジ", value: "—", detail: "達成条件の実装後に表示", icon: "medal")
            }

            InformationPanel(title: "さっそく始める", icon: "play.circle.fill") {
                Text("カメラで腕立て伏せの回数を試験計測できます。映像や関節データは外部に送信しません。")
                    .foregroundStyle(.secondary)
                HStack(spacing: 12) {
                    Button(action: startWorkout) {
                        Label("トレーニングを開始", systemImage: "play.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    Button(action: openBattles) {
                        Label("オンライン対戦", systemImage: "bolt.fill")
                    }
                    Button(action: openTeam) {
                        Label("チームに参加", systemImage: "person.3.fill")
                    }
                }
            }

            InformationPanel(title: "最近の活動", icon: "clock.arrow.circlepath") {
                if latestSessions.isEmpty {
                    Text("まだ保存された運動記録はありません。").foregroundStyle(.secondary)
                } else {
                    ForEach(latestSessions) { workout in
                        HStack {
                            Text("腕立て伏せ \(workout.repetitions) 回")
                            Spacer()
                            Text(WorkoutDay.dateTimeTitle(for: workout.completedAt))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                Button("運動履歴カレンダーを見る", action: openCalendar)
                Text(online.signedIn && online.teamId != nil
                     ? "履歴はこのMacに保存。チーム参加中に完了した運動の回数・日時はFirebaseへ自動送信します。通信失敗時は再送待ちになります。"
                     : "履歴はこのMacに保存。Googleログインとチーム参加後に完了した運動は、回数・日時がFirebaseへ送信されます。")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if let error = historyStore.storageError {
                Label(error, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.red)
            }
        }
    }
}

private struct BattleScreen: View {
    @ObservedObject var online: OnlineService
    @State private var roomCode = ""
    @State private var invitees: Set<String> = []

    private var isReady: Bool { online.configured && online.signedIn && online.teamId != nil && !online.isWorking }
    private var teamInvitees: [TeamPresence] {
        online.members.filter { $0.uid != online.uid }
    }

    var body: some View {
        ScreenLayout(
            title: "オンライン対戦",
            subtitle: "チーム内の招待制ルーム。最大6人、カメラ映像は共有しません。"
        ) {
            InformationPanel(title: "ルームに参加", icon: "person.2.wave.2") {
                TextField("対戦の招待コード", text: $roomCode)
                    .textFieldStyle(.roundedBorder).frame(maxWidth: 390)
                    .disabled(!isReady)
                Button("参加する") { online.joinRoom(code: roomCode) }
                    .buttonStyle(.borderedProminent)
                    .disabled(!isReady || roomCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            InformationPanel(title: "新しいルーム", icon: "plus.circle") {
                Text("招待するチームメンバーを選択（最大5人）。本人を含め6人まで参加可能です。")
                    .foregroundStyle(.secondary)
                if teamInvitees.isEmpty {
                    Text("他のチームメンバーがいません。")
                        .foregroundStyle(.secondary)
                }
                ForEach(teamInvitees) { member in
                    Toggle("メンバー \(member.uid.prefix(8))", isOn: Binding(
                        get: { invitees.contains(member.uid) },
                        set: { enabled in
                            if enabled && invitees.count < 5 { invitees.insert(member.uid) }
                            if !enabled { invitees.remove(member.uid) }
                        }
                    ))
                    .disabled(!isReady)
                }
                Button("ルームを作成") {
                    online.createRoom(invitedUids: Array(invitees))
                }
                .disabled(!isReady)
                if let code = online.roomInviteCode {
                    LabeledContent("新しいルームの招待コード", value: code)
                    Text("コードは招待したメンバーにだけ共有してください。")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            InformationPanel(title: "現在のルーム", icon: "bolt.fill") {
                if let id = online.roomId {
                    Text("ルームID：\(id)")
                        .textSelection(.enabled)
                    Text("状態：\(online.roomPhase ?? "取得中")")
                    HStack {
                        Button("対戦開始") { online.startRoom() }
                            .disabled(!isReady || online.roomPhase != "waiting")
                        Button("対戦終了") { online.finishRoom() }
                            .disabled(!isReady || !["waiting","active"].contains(online.roomPhase ?? ""))
                        Button("進捗を更新") { online.refreshRoomProgress() }
                            .disabled(!isReady)
                    }
                    ForEach(online.roomProgress, id: \.uid) { item in
                        HStack {
                            Text("メンバー \(item.uid.prefix(8))")
                            Spacer()
                            Text("\(item.repetitions) 回（暫定）")
                        }
                    }
                    Text("計測数は各端末から送信した暫定値です。動画や関節座標は送信しません。")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    Text("まだ参加中の対戦ルームはありません。")
                        .foregroundStyle(.secondary)
                }
            }
            InformationPanel(title: "対戦履歴・再戦", icon: "arrow.clockwise") {
                if online.pastRooms.isEmpty {
                    Text("終了済みの対戦履歴はありません。").foregroundStyle(.secondary)
                }
                ForEach(online.pastRooms, id: \.roomId) { record in
                    HStack {
                        Text("対戦 \(record.roomId.prefix(8))・\(record.participantCount)人")
                        Spacer()
                        Button("再戦") { online.rematch(roomId: record.roomId) }
                            .disabled(!isReady)
                    }
                }
                Text("再戦は同じメンバーを新しく招待します。自動参加やスコアの引き継ぎはありません。")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if !online.configured {
                Label("Firebase SDK・アプリ設定またはサーバーの準備が必要です。", systemImage: "lock.fill")
                    .foregroundStyle(.secondary)
            }
        }
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

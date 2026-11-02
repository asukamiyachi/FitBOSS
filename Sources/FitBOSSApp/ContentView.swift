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
        .onChange(of: online.teamId) { _, _ in uploadPendingWorkouts() }
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

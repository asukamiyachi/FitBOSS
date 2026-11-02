import SwiftUI
import FitBOSSCore

// Home: local history, exercise streak and entry points.
struct HomeScreen: View {
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

import FitBOSSCore
import SwiftUI

/// The dashboard never fabricates streaks, badges, members, or online results.
struct BOSSHomeScreen: View {
    @ObservedObject var historyStore: WorkoutHistoryStore
    @ObservedObject var online: OnlineService
    let startWorkout: () -> Void
    let openCalendar: () -> Void
    let openBattles: () -> Void
    let openTeam: () -> Void

    private var latestSessions: [SavedWorkout] {
        Array(historyStore.history.sessions.sorted { $0.completedAt > $1.completedAt }.prefix(3))
    }

    var body: some View {
        BOSSPage(title: "ホーム", subtitle: "今日も自分のペースで。カメラで運動を記録しよう。") {
            hero

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: 3), spacing: 14) {
                BOSSStatCard(
                    title: "継続記録",
                    value: historyStore.history.sessions.isEmpty ? "—" : "\(historyStore.history.currentWorkoutStreak())日",
                    detail: "休息日を大切にする運動日数",
                    symbol: "flame.fill",
                    accent: BOSSTheme.warning
                )
                BOSSStatCard(
                    title: "保存した腕立て伏せ", value: "\(historyStore.history.sessions.reduce(0) { $0 + $1.repetitions })回",
                    detail: "このMacの保存済み記録の合計", symbol: "figure.strengthtraining.traditional", accent: BOSSTheme.blue
                )
                BOSSStatCard(
                    title: "最近の運動", value: latestSessions.first.map { "\($0.repetitions)回" } ?? "未記録",
                    detail: latestSessions.first.map { WorkoutDay.dateTimeTitle(for: $0.completedAt) } ?? "自分のペースで始めましょう",
                    symbol: "clock", accent: BOSSTheme.violet
                )
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 310), spacing: 16)], spacing: 16) {
                BOSSPanel(title: "最近の活動", symbol: "clock.arrow.circlepath") {
                    if latestSessions.isEmpty {
                        VStack(alignment: .leading, spacing: 9) {
                            Label("まだ運動記録はありません", systemImage: "calendar.badge.plus")
                                .foregroundStyle(BOSSTheme.muted)
                            Text("トレーニングを終えたら「完了して記録」で保存できます。")
                                .font(.caption)
                                .foregroundStyle(BOSSTheme.muted)
                        }
                        .frame(maxWidth: .infinity, minHeight: 124, alignment: .leading)
                    } else {
                        ForEach(latestSessions) { workout in
                            HStack(spacing: 12) {
                                Image(systemName: "figure.strengthtraining.traditional")
                                    .font(.title3)
                                    .foregroundStyle(BOSSTheme.blue)
                                    .frame(width: 38, height: 38)
                                    .background(BOSSTheme.blue.opacity(0.13), in: RoundedRectangle(cornerRadius: 10))
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("腕立て伏せ")
                                        .font(.subheadline.weight(.semibold))
                                    Text(WorkoutDay.dateTimeTitle(for: workout.completedAt))
                                        .font(.caption)
                                        .foregroundStyle(BOSSTheme.muted)
                                }
                                Spacer()
                                Text("\(workout.repetitions)回")
                                    .font(.headline.monospacedDigit())
                                    .foregroundStyle(BOSSTheme.blue)
                            }
                            .accessibilityElement(children: .combine)
                            if workout.id != latestSessions.last?.id {
                                Divider().overlay(BOSSTheme.border)
                            }
                        }
                    }
                    Button(action: openCalendar) {
                        Label("履歴カレンダーを開く", systemImage: "calendar")
                    }
                    .buttonStyle(BOSSSecondaryButtonStyle())
                }

                BOSSPanel(title: "プライバシーと利用状況", symbol: "lock.shield") {
                    Label {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("カメラ映像はこのMacの中だけ")
                                .font(.subheadline.weight(.semibold))
                            Text("映像と関節座標は保存・アップロードしません。")
                                .font(.caption)
                                .foregroundStyle(BOSSTheme.muted)
                        }
                    } icon: {
                        Image(systemName: "checkmark.shield.fill").foregroundStyle(BOSSTheme.mint)
                    }
                    Divider().overlay(BOSSTheme.border)
                    Label {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(online.signedIn && online.teamId != nil ? "完了記録はオンライン送信の対象" : "オンライン機能は任意")
                                .font(.subheadline.weight(.semibold))
                            Text(online.signedIn && online.teamId != nil
                                 ? "運動完了時に回数・日時が送信対象となります。サーバー未稼働時は再送待ちです。"
                                 : "チーム参加中に完了した運動の回数・日時は、設定済みのサーバーに送信されます。")
                                .font(.caption)
                                .foregroundStyle(BOSSTheme.muted)
                        }
                    } icon: {
                        Image(systemName: "person.3.sequence.fill").foregroundStyle(BOSSTheme.blue)
                    }
                    Button(action: openTeam) {
                        Label("チーム画面へ", systemImage: "arrow.right")
                    }
                    .buttonStyle(BOSSSecondaryButtonStyle())
                }
            }

            Text("準備中：バッジ・公式ランキング。実績や勝敗はまだ表示しません。")
                .font(.caption).foregroundStyle(BOSSTheme.muted)
            if let error = historyStore.storageError {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(BOSSTheme.warning)
                    .padding(12)
                    .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private var hero: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 23).fill(BOSSTheme.elevated)
            VStack(alignment: .leading, spacing: 16) {
                BOSSPill(text: "CAMERA TRAINING", symbol: "camera.fill", tint: BOSSTheme.mint)
                Text("腕立て伏せを計測")
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .foregroundStyle(BOSSTheme.primary)
                Text("Apple Visionで動きを検出。無理のないペースで回数を記録できます。")
                    .font(.subheadline)
                    .foregroundStyle(BOSSTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 520, alignment: .leading)

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) { heroActions }
                    VStack(spacing: 10) { heroActions }
                }
                .frame(maxWidth: 610)
            }
            .padding(26)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .fixedSize(horizontal: false, vertical: true)
        .overlay(RoundedRectangle(cornerRadius: 23).strokeBorder(BOSSTheme.blue.opacity(0.55)))

    }

    @ViewBuilder
    private var heroActions: some View {
        Button(action: startWorkout) {
            Label("トレーニングを開始", systemImage: "play.fill")
        }
        .buttonStyle(BOSSPrimaryButtonStyle())
        .frame(minWidth: 230)
        Button(action: openBattles) {
            Label("対戦を見る", systemImage: "bolt.fill")
        }
        .buttonStyle(BOSSSecondaryButtonStyle())
        .frame(minWidth: 125)
    }
}
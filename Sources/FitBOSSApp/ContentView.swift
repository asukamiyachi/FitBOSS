import SwiftUI

// This shell is intentionally independent of Firebase and exercise scoring.
// Online actions remain unavailable until authentication and access rules exist.
private enum FitBOSSPage: String, CaseIterable, Identifiable {
    case home, workout, battles, team, achievements, settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: "ホーム"
        case .workout: "トレーニング"
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
        case .battles: "bolt.fill"
        case .team: "person.3.fill"
        case .achievements: "medal.fill"
        case .settings: "gearshape.fill"
        }
    }
}

struct ContentView: View {
    @State private var selection: FitBOSSPage? = .home

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
                    startWorkout: { selection = .workout },
                    openBattles: { selection = .battles },
                    openTeam: { selection = .team }
                )
            case .workout:
                WorkoutCameraView()
            case .battles:
                BattleScreen()
            case .team:
                TeamScreen()
            case .achievements:
                AchievementsScreen()
            case .settings:
                SettingsScreen()
            }
        }
        .navigationSplitViewStyle(.balanced)
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
    let startWorkout: () -> Void
    let openBattles: () -> Void
    let openTeam: () -> Void

    var body: some View {
        ScreenLayout(
            title: "ホーム",
            subtitle: "自分のペースで運動し、仲間と進捗を共有しよう。"
        ) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 200), spacing: 12)], spacing: 12) {
                StatisticCard(title: "継続記録", value: "—", detail: "履歴の保存後に表示", icon: "calendar")
                StatisticCard(title: "対戦記録", value: "—", detail: "対戦履歴の連携後に表示", icon: "bolt.fill")
                StatisticCard(title: "チーム", value: "未参加", detail: "Googleログイン連携後に参加", icon: "person.3")
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
                Text("まだ保存された記録はありません。")
                    .foregroundStyle(.secondary)
                Text("今はカメラ計測の実験段階です。履歴・連続記録・同期は今後接続します。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text("休息日を含めて無理なく続けられる記録の仕組みを設計中です。")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}

private struct BattleScreen: View {
    @State private var roomCode = ""

    var body: some View {
        ScreenLayout(
            title: "オンライン対戦",
            subtitle: "同じ種目・条件で、最大6人のリアルタイム対戦を計画しています。"
        ) {
            InformationPanel(title: "ルームに参加", icon: "person.2.wave.2") {
                TextField("招待コードを入力", text: $roomCode)
                    .disabled(true)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 360)
                Button("ルームに参加") {}
                    .buttonStyle(.borderedProminent)
                    .disabled(true)
                Label("準備中：Google認証・ルーム入室の安全な処理は未接続です。", systemImage: "lock.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            InformationPanel(title: "ルームを作成", icon: "plus.circle") {
                Text("友達を招待して、一緒に運動するための部屋を作ります。")
                    .foregroundStyle(.secondary)
                Button("新しいルームを作成") {}
                    .disabled(true)
                Text("定員は6人。映像は共有せず、必要な進捗数値だけを同期する予定です。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            InformationPanel(title: "対戦記録", icon: "list.bullet.rectangle") {
                Text("対戦履歴はまだありません。")
                    .foregroundStyle(.secondary)
                Text("参加した対戦・種目・結果を、オンライン機能完成後に表示します。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct TeamScreen: View {
    @State private var invitationCode = ""

    var body: some View {
        ScreenLayout(
            title: "チーム",
            subtitle: "仲間の活動状況を共有する、招待制のチーム機能です。"
        ) {
            InformationPanel(title: "チームに参加", icon: "person.badge.plus") {
                TextField("チームの招待コード", text: $invitationCode)
                    .disabled(true)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 360)
                Button("参加する") {}
                    .buttonStyle(.borderedProminent)
                    .disabled(true)
                Label("準備中：ログイン・招待コード検証・チーム権限の実装が必要です。", systemImage: "lock.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            InformationPanel(title: "メンバーのオンライン状況", icon: "circle.dotted.circle") {
                Text("まだチームに参加していません。")
                    .foregroundStyle(.secondary)
                Text("「オンライン」はアプリの接続状態です。運動中かどうかは示しません。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            InformationPanel(title: "チームランキング", icon: "chart.bar.xaxis") {
                Text("チームの記録はまだありません。")
                    .foregroundStyle(.secondary)
                Text("種目ごとに参加・達成状況を比較する予定です。休息日を不利に扱わない方針です。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
    var body: some View {
        ScreenLayout(
            title: "設定",
            subtitle: "アカウントとデータの扱いを確認できます。"
        ) {
            InformationPanel(title: "アカウント", icon: "person.crop.circle") {
                Text("Googleログイン")
                    .font(.headline)
                Label("未接続：Firebase SDKとログイン画面はこれから実装します。", systemImage: "lock")
                    .foregroundStyle(.secondary)
                Button("Googleでログイン") {}
                    .disabled(true)
            }

            InformationPanel(title: "プライバシー", icon: "hand.raised.fill") {
                Label("カメラ映像・関節座標は端末内で処理", systemImage: "checkmark.shield")
                Label("個人練習の結果は終了時のみ同期する予定", systemImage: "arrow.triangle.2.circlepath")
                Label("オンライン表示の公開設定は今後実装", systemImage: "person.crop.circle.badge.questionmark")
            }

            InformationPanel(title: "計測について", icon: "info.circle") {
                Text("腕立てのカウントは2Dの姿勢推定による試験判定です。フォームや運動強度の正確さを保証するものではありません。")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

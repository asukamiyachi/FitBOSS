import SwiftUI

// Badges remain explanatory placeholders until an awards engine exists.
private struct BadgeDefinition: Identifiable {
    let title: String
    let description: String
    let symbol: String
    var id: String { title }
}

struct AchievementsScreen: View {
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
            BOSSInlineNotice(message: "バッジ機能は準備中です。以下は構想であり、現在の達成状況を示しません。", symbol: "clock")
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
                        Label("準備中", systemImage: "clock")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 144, alignment: .topLeading)
                    .padding(20)
                    .background(BOSSTheme.surface, in: RoundedRectangle(cornerRadius: 16))
                }
            }
            Text("バッジの判定・保存は今後実装します。現段階で実際に獲得できるバッジはありません。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

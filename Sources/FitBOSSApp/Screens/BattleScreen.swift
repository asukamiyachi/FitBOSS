import SwiftUI

// Battle: room management, invitees and provisional progress.
struct BattleScreen: View {
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

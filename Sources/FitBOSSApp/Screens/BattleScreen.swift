import AppKit
import FitBOSSCore
import SwiftUI

/// Shows only real room state returned by OnlineService; no fabricated opponents or scores.
struct BOSSBattleScreen: View {
    @ObservedObject var online: OnlineService
    @State private var roomCode = ""
    @State private var invitees: Set<String> = []

    private var isReady: Bool {
        online.configured && online.signedIn && online.teamId != nil && !online.isWorking
    }
    private var teamInvitees: [TeamPresence] {
        online.members.filter { $0.uid != online.uid }
    }
    private var largestCount: Int {
        max(1, online.roomProgress.map(\.repetitions).max() ?? 1)
    }

    var body: some View {
        BOSSPage(title: "対戦", subtitle: "仲間と記録を共有する、招待制ルーム。最大6人まで。") {
            entryPanel

            if !online.configured {
                Label("このビルドではオンライン機能を利用できません。ローカル練習は使えます。", systemImage: "wifi.slash")
                    .font(.subheadline)
                    .foregroundStyle(.orange)
            } else if !online.signedIn {
                Label("対戦にはGoogleログインが必要です。", systemImage: "person.crop.circle")
                    .font(.subheadline)
                    .foregroundStyle(.orange)
            } else if online.teamId == nil {
                Label("対戦にはチームへの参加が必要です。", systemImage: "person.3")
                    .font(.subheadline)
                    .foregroundStyle(.orange)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 310), spacing: 16)], spacing: 16) {
                if online.roomId == nil {
                    createPanel
                    roomPanel
                } else {
                    roomPanel
                    createPanel
                }
                historyPanel
                statusPanel
            }
        }
        .onChange(of: online.uid) { _, _ in
            invitees.removeAll()
            roomCode = ""
        }
        .onChange(of: online.teamId) { _, _ in
            invitees.removeAll()
            roomCode = ""
        }
        .onChange(of: online.members.map(\.uid)) { _, ids in
            invitees.formIntersection(Set(ids))
        }
    }

    private var roomPanel: some View {
        BOSSPanel(title: "現在の対戦ルーム", symbol: "bolt.fill") {
            if let roomId = online.roomId {
                HStack {
                    BOSSPill(
                        text: phaseLabel,
                        symbol: online.roomPhase == "active" ? "bolt.fill" : "clock",
                        tint: online.roomPhase == "active" ? BOSSTheme.mint : BOSSTheme.blue
                    )
                    Spacer()
                    Text("\(online.roomProgress.count)/6人表示")
                        .font(.caption)
                        .foregroundStyle(BOSSTheme.muted)
                }
                Text("ルームID")
                    .font(.caption)
                    .foregroundStyle(BOSSTheme.muted)
                Text(roomId)
                    .font(.caption.monospaced())
                    .foregroundStyle(.white)
                    .textSelection(.enabled)
                    .lineLimit(2)
                if let inviteCode = online.roomInviteCode {
                    HStack(spacing: 10) {
                        Text("招待コード: \(inviteCode)")
                            .font(.subheadline.monospaced())
                            .textSelection(.enabled)
                        Spacer()
                        Button {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(inviteCode, forType: .string)
                        } label: {
                            Label("コピー", systemImage: "doc.on.doc")
                        }
                        .buttonStyle(.borderless)
                    }
                }
                if online.roomProgress.isEmpty {
                    emptyState("対戦の進捗はまだありません", "参加後、ルームの進捗を更新すると表示されます。", "chart.bar.xaxis")
                } else {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("各メンバーの暫定カウント")
                            .font(.subheadline.weight(.semibold))
                        ForEach(online.roomProgress) { participant in
                            VStack(alignment: .leading, spacing: 7) {
                                HStack {
                                    Text(participant.uid == online.uid ? "自分" : "メンバー \(participant.uid.prefix(8))")
                                    Spacer()
                                    Text("\(participant.repetitions)回")
                                        .font(.headline.monospacedDigit())
                                }
                                GeometryReader { proxy in
                                    Capsule().fill(.white.opacity(0.10))
                                        .overlay(alignment: .leading) {
                                            Capsule()
                                                .fill(BOSSTheme.action)
                                                .frame(width: proxy.size.width * CGFloat(participant.repetitions) / CGFloat(largestCount))
                                        }
                                }
                                .frame(height: 9)
                                .accessibilityHidden(true)
                            }
                        }
                        Text("棒の長さは表示中の最大値との相対比です。運動フォームの正確さを示すものではありません。")
                            .font(.caption2)
                            .foregroundStyle(BOSSTheme.muted)
                    }
                }
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 9) { roomActions }
                    VStack(spacing: 9) { roomActions }
                }
            } else {
                emptyState("まだ参加中のルームはありません", "ログインし、同じチームのメンバーを招待してください。", "person.2.slash")
            }
        }
    }

    private var createPanel: some View {
        BOSSPanel(title: "ルームを作る・参加する", symbol: "person.2.badge.plus") {
            Text("チームのメンバーを招待して、新しい腕立て伏せルームを作成できます。")
                .font(.subheadline)
                .foregroundStyle(BOSSTheme.muted)
            if teamInvitees.isEmpty {
                Text("招待可能なメンバーはまだ表示されていません。")
                    .font(.caption)
                    .foregroundStyle(BOSSTheme.muted)
            } else {
                VStack(alignment: .leading, spacing: 9) {
                    Text("招待するメンバー（最大5人）")
                        .font(.caption.weight(.semibold))
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
                }
            }

            Button {
                online.createRoom(invitedUids: Array(invitees))
            } label: {
                Label("ルームを作成", systemImage: "plus.circle.fill")
            }
            .buttonStyle(BOSSPrimaryButtonStyle())
            .disabled(!isReady)

            Divider().overlay(.white.opacity(0.14))
            TextField("招待コードを入力", text: $roomCode)
                .textFieldStyle(.roundedBorder)
                .disabled(!isReady)
                .accessibilityLabel("対戦ルーム招待コード")
            Button {
                online.joinRoom(code: roomCode.trimmingCharacters(in: .whitespacesAndNewlines))
            } label: {
                Label("招待コードで参加", systemImage: "link")
            }
            .buttonStyle(BOSSSecondaryButtonStyle())
            .disabled(!isReady || roomCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    private var historyPanel: some View {
        BOSSPanel(title: "最近のルーム履歴", symbol: "clock.arrow.circlepath") {
            if online.pastRooms.isEmpty {
                emptyState("まだルーム履歴はありません", "終了した対戦ルームがある場合に表示します。", "clock")
            } else {
                ForEach(online.pastRooms) { record in
                    HStack(spacing: 12) {
                        Image(systemName: "bolt.shield")
                            .foregroundStyle(BOSSTheme.violet)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("ルーム \(record.roomId.prefix(8))")
                                .font(.subheadline.weight(.semibold))
                            Text("参加者 \(record.participantCount)人")
                                .font(.caption)
                                .foregroundStyle(BOSSTheme.muted)
                        }
                        Spacer()
                        Button("再戦") { online.rematch(roomId: record.roomId) }
                            .disabled(!isReady)
                    }
                }
            }
            Text("再戦では新しい招待ルームを作成し、元の参加者に自動参加させません。")
                .font(.caption)
                .foregroundStyle(BOSSTheme.muted)
        }
    }

    private var statusPanel: some View {
        BOSSPanel(title: "オンライン機能について", symbol: "lock.shield") {
            statusRow("Googleログイン", symbol: "person.crop.circle",
                      description: online.signedIn ? "認証済み" : "ログインが必要です。")
            Divider().overlay(.white.opacity(0.14))
            statusRow("チーム参加", symbol: "person.3",
                      description: online.teamId != nil ? "チーム選択中" : "先にチームに参加してください。")
            Divider().overlay(.white.opacity(0.14))
            statusRow("共有する情報", symbol: "chart.bar",
                      description: "回数などの暫定進捗。映像や関節座標は送信しません。")
            Divider().overlay(.white.opacity(0.14))
            statusRow("サーバーの状態", symbol: "server.rack",
                      description: "対戦用Cloud Functionsは未デプロイです。現在は開発用UIです。")
            if let message = online.errorMessage {
                Label(message, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
    }

    private var phaseLabel: String {
        switch online.roomPhase {
        case "waiting": "待機中"
        case "active": "対戦中"
        case "finished": "終了"
        default: "状態確認中"
        }
    }

    private var entryPanel: some View {
        BOSSPanel {
            HStack(alignment: .center, spacing: 18) {
                Image(systemName: "bolt.shield.fill")
                    .font(.system(size: 37, weight: .medium))
                    .foregroundStyle(BOSSTheme.blue)
                    .frame(width: 68, height: 68)
                    .background(BOSSTheme.blue.opacity(0.13), in: RoundedRectangle(cornerRadius: 17))
                VStack(alignment: .leading, spacing: 10) {
                    Text("オンライン対戦")
                        .font(.system(size: 23, weight: .bold, design: .rounded))
                    Text("チームメンバー限定・最大6人の招待制")
                        .font(.subheadline)
                        .foregroundStyle(BOSSTheme.muted)
                    HStack(spacing: 8) {
                        BOSSPill(text: online.signedIn ? "Google認証済み" : "要ログイン",
                                 symbol: online.signedIn ? "checkmark.circle.fill" : "lock",
                                 tint: online.signedIn ? BOSSTheme.mint : .orange)
                        BOSSPill(text: online.teamId != nil ? "チーム選択中" : "未参加",
                                 symbol: "person.3.fill", tint: BOSSTheme.violet)
                    }
                }
                Spacer(minLength: 0)
            }
            Text("β開発中：Cloud Functionsは未デプロイのため、作成・参加操作は現在の実環境では利用できません。")
                .font(.caption)
                .foregroundStyle(BOSSTheme.muted)
        }
    }

    @ViewBuilder
    private var roomActions: some View {
        Button("対戦開始") { online.startRoom() }
            .disabled(!isReady || online.roomPhase != "waiting")
            .buttonStyle(BOSSPrimaryButtonStyle())
        Button("対戦終了") { online.finishRoom() }
            .disabled(!isReady || !["waiting", "active"].contains(online.roomPhase ?? ""))
            .buttonStyle(BOSSSecondaryButtonStyle())
        Button {
            online.refreshRoomProgress()
        } label: {
            Label("更新", systemImage: "arrow.clockwise")
        }
        .disabled(!isReady)
        .buttonStyle(BOSSSecondaryButtonStyle())
    }

    private func emptyState(_ title: String, _ description: String, _ symbol: String) -> some View {
        VStack(spacing: 9) {
            Image(systemName: symbol).font(.system(size: 31)).foregroundStyle(BOSSTheme.blue)
            Text(title).font(.headline)
            Text(description).font(.caption).foregroundStyle(BOSSTheme.muted).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 156)
    }

    private func statusRow(_ title: String, symbol: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .frame(width: 22)
                .foregroundStyle(BOSSTheme.blue)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(description).font(.caption).foregroundStyle(BOSSTheme.muted)
            }
        }
    }
}
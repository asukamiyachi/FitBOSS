import AVFoundation
import FitBOSSCore
import SwiftUI

/// Neon presentation around the existing experimental, on-device camera pipeline.
/// Camera permission, exercise evaluation, history persistence and upload behavior are unchanged.
struct WorkoutCameraView: View {
    @ObservedObject var historyStore: WorkoutHistoryStore
    @ObservedObject var online: OnlineService
    @StateObject private var camera = CameraManager()
    @State private var completionMessage: String?
    @State private var lastSavedCount: Int?

    private var phaseText: String {
        switch camera.result.phase {
        case .searching: "姿勢を認識中"
        case .ready: "開始姿勢を検出"
        case .lowering: "肘を曲げた状態を追跡"
        case .rising: "動作を追跡中"
        }
    }

    var body: some View {
        GeometryReader { window in
            BOSSPage(title: "トレーニング", subtitle: "カメラで腕立て伏せを計測。自分のペースで進めましょう。") {
                if BOSSLayoutPolicy.compactTraining(detailWidth: window.size.width) {
                    // At 820×540, save/start controls must be visible above the camera.
                    compactControls
                    cameraPanel(height: BOSSLayoutPolicy.compactCameraHeight(windowHeight: window.size.height))
                } else {
                    HStack(alignment: .top, spacing: 16) {
                        cameraPanel(height: 442)
                            .frame(minWidth: 430, maxWidth: .infinity)
                        controlPanel.frame(width: 272)
                    }
                }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 310), spacing: 16)], spacing: 16) {
                BOSSPanel(title: "今回の計測", symbol: "chart.xyaxis.line") {
                    HStack(spacing: 18) {
                        VStack(alignment: .leading, spacing: 7) {
                            Text("現在の回数")
                                .font(.caption)
                                .foregroundStyle(BOSSTheme.muted)
                            Text("\(camera.result.value)回")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .monospacedDigit()
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 7) {
                            Text("記録の状態")
                                .font(.caption)
                                .foregroundStyle(BOSSTheme.muted)
                            Text(lastSavedCount.map { "\($0)回を保存済み" } ?? "まだ保存していません")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(lastSavedCount == nil ? BOSSTheme.muted : BOSSTheme.mint)
                        }
                    }
                    if let message = completionMessage {
                        Label(message, systemImage: lastSavedCount == nil ? "info.circle" : "checkmark.circle")
                            .font(.caption)
                            .foregroundStyle(lastSavedCount == nil ? .orange : BOSSTheme.mint)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if let error = historyStore.storageError {
                        Label(error, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                            .font(.caption)
                    }
                }

                BOSSPanel(title: "プライバシーと計測の注意", symbol: "hand.raised") {
                    Label("映像と関節座標はこのMac内で処理", systemImage: "checkmark.shield")
                        .font(.subheadline)
                    Text("映像を録画・保存・送信することはありません。腕立てのカウントは2D姿勢推定による試験値で、フォームの正確さは保証しません。")
                        .font(.caption)
                        .foregroundStyle(BOSSTheme.muted)
                    Divider().overlay(.white.opacity(0.15))
                    Text(online.signedIn && online.teamId != nil
                        ? "チーム参加中は「完了して記録」で回数・日時がFirebaseへの送信対象になります。通信できない場合は再送待ちです。"
                        : "ローカル練習ではこのMacに保存します。Googleログインしてチームに参加した後の完了記録は、回数・日時がオンライン送信対象です。")
                        .font(.caption)
                        .foregroundStyle(BOSSTheme.muted)
                }
            }

            BOSSPanel(title: "診断情報", symbol: "waveform.path.ecg") {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 18) { diagnostics }
                    VStack(alignment: .leading, spacing: 12) { diagnostics }
                }
            }
            }
        }
        .onAppear { camera.requestAndStart() }
        .onDisappear { camera.stop() }
        .onReceive(camera.$result) { result in
            online.sendRoomProgress(result.value)
        }
    }

    private func cameraPanel(height: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            Color.black
            CameraPreview(session: camera.session, pose: camera.pose)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityHidden(true)
            VStack {
                HStack {
                    BOSSPill(
                        text: camera.isRunning ? "計測中" : camera.isStarting ? "カメラ起動中" : "停止中",
                        symbol: camera.isRunning ? "circle.fill" : "video.slash",
                        tint: camera.isRunning ? BOSSTheme.mint : .orange
                    )
                    Spacer(minLength: 8)
                    Text(phaseText)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .background(.black.opacity(0.7), in: Capsule())
                }
                Spacer()
                VStack(spacing: 3) {
                    Text("\(camera.result.value)")
                        .font(.system(size: 90, weight: .black, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .accessibilityLabel("腕立て伏せの計測回数")
                        .accessibilityValue("\(camera.result.value)回")
                    Text("回 · 腕立て伏せ")
                        .font(.subheadline.weight(.bold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background {
                    LinearGradient(colors: [.clear, .black.opacity(0.82)],
                                   startPoint: .top, endPoint: .bottom)
                }
                Text("動作は試験判定です。無理なく休息を取りましょう。")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.84))
                    .padding(.bottom, 5)
            }
            .padding(16)
            if let error = camera.errorMessage {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.white)
                    .padding(12)
                    .background(.red.opacity(0.85), in: RoundedRectangle(cornerRadius: 11))
                    .padding(16)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }
        }
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20)
            .strokeBorder(BOSSTheme.blue.opacity(0.65), lineWidth: 1.5))
        .shadow(color: BOSSTheme.blue.opacity(0.15), radius: 16, y: 5)
    }

    private var controlPanel: some View {
        BOSSPanel(title: "トレーニング操作", symbol: "slider.horizontal.3") {
            VStack(alignment: .leading, spacing: 11) {
                Text("トレーニング種目")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(BOSSTheme.muted)
                selectedExercise("腕立て伏せ", icon: "figure.strengthtraining.traditional")
                comingExercise("スクワット", icon: "figure.strengthtraining.functional")
                comingExercise("プランク", icon: "figure.core.training")

                Text("カメラ")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(BOSSTheme.muted)
                    .padding(.top, 7)
                cameraPicker
                cameraToggleButton
                resetButton
                saveButton
                    .padding(.top, 6)
            }
        }
    }

    private var compactControls: some View {
        BOSSPanel {
            HStack(spacing: 9) {
                saveButton
                cameraToggleButton
            }
            HStack(spacing: 9) {
                cameraPicker
                    .frame(minWidth: 0, maxWidth: .infinity)
                resetButton
                    .frame(maxWidth: 190)
            }
            Text("現在の種目：腕立て伏せ · その他の種目は準備中")
                .font(.caption)
                .foregroundStyle(BOSSTheme.muted)
            if let message = completionMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(lastSavedCount == nil ? .orange : BOSSTheme.mint)
            }
            if let error = historyStore.storageError {
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
    }

    private var cameraPicker: some View {
        Picker("カメラを選択", selection: Binding(
            get: { camera.selectedDeviceID },
            set: { camera.selectCamera(id: $0) }
        )) {
            if camera.devices.isEmpty {
                Text("カメラを検索中").tag("")
            }
            ForEach(camera.devices) { device in
                Text(device.name).tag(device.id)
            }
        }
        .labelsHidden()
        .disabled(camera.isStarting || camera.devices.isEmpty)
        .accessibilityLabel("カメラを選択")
    }

    private var cameraToggleButton: some View {
        Button {
            if camera.isRunning {
                camera.stop()
            } else {
                completionMessage = nil
                lastSavedCount = nil
                camera.requestAndStart()
            }
        } label: {
            Label(camera.isRunning ? "カメラを停止" : "カメラを開始",
                  systemImage: camera.isRunning ? "stop.fill" : "video.fill")
        }
        .buttonStyle(BOSSSecondaryButtonStyle())
        .disabled(camera.isStarting)
    }

    private var resetButton: some View {
        Button {
            completionMessage = nil
            lastSavedCount = nil
            camera.resetCounter()
        } label: {
            Label("カウントをリセット", systemImage: "arrow.counterclockwise")
        }
        .buttonStyle(BOSSSecondaryButtonStyle())
    }

    private var saveButton: some View {
        Button(action: saveWorkout) {
            Label("完了して記録", systemImage: "checkmark.circle.fill")
        }
        .buttonStyle(BOSSPrimaryButtonStyle())
        .disabled(camera.result.value <= 0 || historyStore.storageError != nil)
        .accessibilityHint(camera.result.value <= 0 ? "1回以上の計測で有効になります" :
            "運動をローカル保存し、チーム参加中は記録の概要を送信します")
    }

    private func selectedExercise(_ text: String, icon: String) -> some View {
        HStack {
            Label(text, systemImage: icon)
            Spacer()
            Image(systemName: "checkmark.circle.fill")
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(.white)
        .padding(12)
        .background(BOSSTheme.violet.opacity(0.25), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(BOSSTheme.violet))
    }

    private func comingExercise(_ text: String, icon: String) -> some View {
        HStack {
            Label(text, systemImage: icon)
            Spacer()
            Text("準備中").font(.caption)
        }
        .font(.subheadline)
        .foregroundStyle(BOSSTheme.muted)
        .padding(12)
        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var diagnostics: some View {
        Label(camera.isRunning ? "カメラ：動作中" : "カメラ：停止中",
              systemImage: "video.fill")
            .foregroundStyle(camera.isRunning ? BOSSTheme.mint : BOSSTheme.muted)
        Label(phaseText, systemImage: "figure.strengthtraining.traditional")
            .foregroundStyle(BOSSTheme.muted)
        Text("肘角度：\(camera.result.angleDegrees.map { String(format: "%.0f°", $0) } ?? "—")")
            .foregroundStyle(BOSSTheme.muted)
        Text("認識信頼度：\(Int(camera.result.confidence * 100))%（参考値）")
            .foregroundStyle(BOSSTheme.muted)
    }

    private func saveWorkout() {
        let count = camera.result.value
        let previousIDs = Set(historyStore.history.sessions.map { $0.id })
        if historyStore.recordPushUps(count) {
            if let session = historyStore.history.sessions.first(where: { !previousIDs.contains($0.id) }),
               let teamId = online.teamId, let uid = online.uid {
                historyStore.enqueue(sessionID: session.id, uid: uid, teamId: teamId)
                online.submitWorkout(session) {
                    historyStore.markSynced(sessionID: session.id, uid: uid, teamId: teamId)
                }
            }
            camera.stop()
            camera.resetCounter()
            lastSavedCount = count
            completionMessage = "腕立て伏せ \(count) 回をこのMacに保存しました。"
        } else {
            lastSavedCount = nil
            completionMessage = historyStore.storageError ?? "保存できませんでした。1回以上計測してください。"
        }
    }
}
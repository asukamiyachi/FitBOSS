import AVFoundation
import FitBOSSCore
import SwiftUI

/// Local-only experimental camera view; its capture lifetime is scoped to the training page.
struct WorkoutCameraView: View {
    @ObservedObject var historyStore: WorkoutHistoryStore
    @ObservedObject var online: OnlineService
    @StateObject private var camera = CameraManager()
    @State private var completionMessage: String?

    private var phaseText: String {
        switch camera.result.phase {
        case .searching: "姿勢を認識中 — カメラに上半身を映してください"
        case .ready: "開始姿勢を検出"
        case .lowering: "肘を曲げた状態を検出中"
        case .rising: "動作を追跡中"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                Text("トレーニング").font(.title2.bold())
                Text("Camera Lab").font(.subheadline).foregroundStyle(.secondary)
                Spacer()
                if !camera.devices.isEmpty {
                    Picker("カメラ", selection: Binding(
                        get: { camera.selectedDeviceID },
                        set: { camera.selectCamera(id: $0) }
                    )) {
                        ForEach(camera.devices) { device in
                            Text(device.name).tag(device.id)
                        }
                    }
                    .frame(maxWidth: 270)
                }
                Button(camera.isRunning ? "停止" : "カメラ開始") {
                    if camera.isRunning { camera.stop() }
                    else { camera.requestAndStart() }
                }
                .disabled(camera.isStarting)
                Button("カウントリセット") {
                    completionMessage = nil
                    camera.resetCounter()
                }
                Button("完了して記録") {
                    let count = camera.result.value
                    let previousIDs = Set(historyStore.history.sessions.map { $0.id })
                    if historyStore.recordPushUps(count) {
                        if let session = historyStore.history.sessions.first(where: { !previousIDs.contains($0.id) }),
                           let teamId = online.teamId {
                            historyStore.enqueue(sessionID: session.id, teamId: teamId)
                            online.submitWorkout(session) {
                                historyStore.markSynced(sessionID: session.id, teamId: teamId)
                            }
                        }
                        camera.stop()
                        camera.resetCounter()
                        completionMessage = "腕立て伏せ \(count) 回をこのMacに保存しました。"
                    } else {
                        completionMessage = historyStore.storageError ?? "保存できませんでした。1回以上計測してください。"
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(camera.result.value <= 0 || historyStore.storageError != nil)
            }
            .padding(18)
            if let message = completionMessage {
                Text(message)
                    .font(.caption).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 18).padding(.vertical, 5)
            }
            Divider()
            ZStack(alignment: .topLeading) {
                Color.black
                CameraPreview(session: camera.session, pose: camera.pose)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                VStack(alignment: .leading, spacing: 8) {
                    Text("PUSH-UP / EXPERIMENTAL").font(.caption.bold()).tracking(1)
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text("\(camera.result.value)").font(.system(size: 86, weight: .bold, design: .rounded)).monospacedDigit()
                        Text("回").font(.title3)
                    }
                    Text(phaseText).font(.headline)
                    Text("肘角度: \(camera.result.angleDegrees.map { String(format: "%.0f°", $0) } ?? "—")")
                    Text("信頼度: \(Int(camera.result.confidence * 100))%")
                    Text("2D試験判定・フォームの正確さは保証されません")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                .foregroundStyle(.white)
                .padding(22)
                .background(.black.opacity(0.70), in: RoundedRectangle(cornerRadius: 16))
                .padding(24)
                if let message = camera.errorMessage {
                    Text(message)
                        .foregroundStyle(.white)
                        .padding(12)
                        .background(.red.opacity(0.85), in: RoundedRectangle(cornerRadius: 10))
                        .padding()
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                }
            }
        }
        .navigationTitle("トレーニング")
        .onAppear { camera.requestAndStart() }
        .onDisappear { camera.stop() }
        .onReceive(camera.$result) { result in
            online.sendRoomProgress(result.value)
        }
    }
}

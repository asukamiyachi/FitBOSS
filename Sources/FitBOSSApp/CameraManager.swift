import AVFoundation
import Combine
import Foundation
import FitBOSSCore

struct CameraOption: Identifiable {
    let id: String
    let name: String
}

/// Runs Vision serially and throttles inference independently from the preview.
private final class FrameProcessor: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    let detector = VisionPoseDetector()
    var onPose: ((PoseDetection, Double, Int) -> Void)?
    private var lastInference = -Double.infinity
    private var lastRevision: Int?
    private let stateLock = NSLock()
    private var revision = 0
    private var captureClock: CMClock?

    func setRevision(_ revision: Int) {
        stateLock.withLock { self.revision = revision }
    }

    func setStream(revision: Int, clock: CMClock) {
        stateLock.withLock { self.revision = revision; captureClock = clock }
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let now = ProcessInfo.processInfo.systemUptime
        let (revision, clock) = stateLock.withLock { (self.revision, captureClock) }
        guard let clock else { return }
        if lastRevision != revision {
            lastInference = -Double.infinity
            lastRevision = revision
        }
        guard now - lastInference >= 1.0 / 12.0 else { return }
        lastInference = now
        // Apple's capture timestamps use session.synchronizationClock. Convert
        // into the host clock used by the main-thread stream-boundary fence.
        let time = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        guard time.isNumeric else { return }
        let hostTime = CMSyncConvertTime(time, from: clock, to: CMClockGetHostTimeClock())
        let capturedAt = CMTimeGetSeconds(hostTime)
        guard capturedAt.isFinite else { return }
        onPose?(detector.detect(sampleBuffer, timestamp: capturedAt), capturedAt, revision)
    }
}

final class CameraManager: NSObject, ObservableObject {
    let session = AVCaptureSession()

    @Published private(set) var devices: [CameraOption] = []
    @Published private(set) var selectedDeviceID = ""
    @Published private(set) var pose: PoseFrame?
    @Published private(set) var result: ExerciseResult
    @Published private(set) var isRunning = false
    @Published private(set) var isStarting = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var trackingMessage = "肩・肘・手首が映るよう、カメラを側面寄りに置いてください。"

    private let sessionQueue = DispatchQueue(label: "fitboss.camera.session", qos: .userInitiated)
    private let processingQueue = DispatchQueue(label: "fitboss.camera.vision", qos: .userInitiated)
    private let processor = FrameProcessor()
    private let output = AVCaptureVideoDataOutput()
    private var outputAttached = false
    // Main-thread revision invalidates late permission prompts and camera start completions.
    private var requestRevision = 0
    private var recognition = CameraRecognitionState()

    override init() {
        self.result = CameraRecognitionState().result
        super.init()
        processor.onPose = { [weak self] detection, capturedAt, revision in
            DispatchQueue.main.async { [weak self] in
                guard let self, self.isRunning && !self.isStarting else { return }
                guard self.recognition.consume(detection.frame, capturedAt: capturedAt, revision: revision) else { return }
                self.pose = detection.frame
                self.result = self.recognition.result
                self.updateTrackingMessage(detection.failure)
            }
        }
    }

    func requestAndStart() {
        guard !isRunning && !isStarting else { return }
        requestRevision &+= 1
        let revision = requestRevision
        isStarting = true
        errorMessage = nil
        invalidateRecognition()
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureAndStart(revision: revision)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async { [weak self] in
                    guard let self, self.requestRevision == revision else { return }
                    if granted {
                        self.configureAndStart(revision: revision)
                    } else {
                        self.isStarting = false
                        self.errorMessage = "カメラへのアクセスが許可されていません。システム設定で許可してください。"
                    }
                }
            }
        case .denied, .restricted:
            isStarting = false
            errorMessage = "カメラへのアクセスが許可されていません。システム設定 → プライバシーとセキュリティ → カメラを確認してください。"
        @unknown default:
            isStarting = false
            errorMessage = "カメラの権限を確認できませんでした。"
        }
    }

    func selectCamera(id: String) {
        guard selectedDeviceID != id else { return }
        selectedDeviceID = id
        guard isRunning || isStarting else { return }
        requestRevision &+= 1
        let revision = requestRevision
        isStarting = true
        isRunning = false
        invalidateRecognition()
        configureAndStart(revision: revision)
    }

    func resetCounter() {
        invalidateRecognition(resetCount: true)
    }

    func stop() {
        requestRevision &+= 1
        isStarting = false
        isRunning = false
        invalidateRecognition()
        sessionQueue.async {
            if self.session.isRunning { self.session.stopRunning() }
        }
    }

    private func invalidateRecognition(resetCount: Bool = false, captureClock: CMClock? = nil) {
        let now = CMTimeGetSeconds(CMClockGetTime(CMClockGetHostTimeClock()))
        recognition.invalidate(at: now, resetCount: resetCount)
        if let captureClock {
            processor.setStream(revision: recognition.revision, clock: captureClock)
        } else {
            processor.setRevision(recognition.revision)
        }
        pose = nil
        result = recognition.result
        trackingMessage = "追跡をリセットしました。肩・肘・手首を画面に入れてください。"
    }

    private func updateTrackingMessage(_ failure: PoseDetectionFailure?) {
        if let failure {
            switch failure {
            case .noImage: trackingMessage = "カメラの映像を取得できません。"
            case .noPerson: trackingMessage = "姿勢を検出できません。肩・肘・手首を画面に入れてください。"
            case .visionError: trackingMessage = "姿勢解析に失敗しました。続く場合はカメラを再開してください。"
            }
            return
        }
        switch recognition.diagnostic {
        case .noPose, .missingJoints:
            trackingMessage = "肩・肘・手首の追跡が途切れました。側面寄りで3点を映してください。"
        case .lowConfidence:
            trackingMessage = "姿勢が不鮮明です。明るさと肩・肘・手首の映り方を確認してください。"
        case .invalidGeometry:
            trackingMessage = "肘角度を取得できません。カメラの位置を確認してください。"
        case .invalidTimestamp, .trackingInterrupted, .armChanged:
            trackingMessage = "追跡が中断しました。腕を伸ばした状態から再開してください。"
        case .invalidConfiguration:
            trackingMessage = "認識設定を確認できません。計測を停止してください。"
        case .recovering:
            trackingMessage = "同じ腕の追跡を再確認しています。"
        case .stabilizing:
            trackingMessage = "肩・肘・手首を映し、腕を伸ばした状態から始めてください。"
        case .ready:
            trackingMessage = "計測準備完了。無理のないペースで動いてください。"
        case .lowering:
            trackingMessage = "曲げた状態を検出しています。疲れたら休息を優先してください。"
        case .counted:
            trackingMessage = "1回を数えました。"
        }
    }

    private func availableDevices() -> [AVCaptureDevice] {
        AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .external, .continuityCamera],
            mediaType: .video,
            position: .unspecified
        ).devices
    }

    private func configureAndStart(revision: Int) {
        errorMessage = nil
        let cameraID = selectedDeviceID
        sessionQueue.async {
            let cameras = self.availableDevices()
            guard let device = cameras.first(where: { $0.uniqueID == cameraID }) ?? cameras.first else {
                DispatchQueue.main.async {
                    guard self.requestRevision == revision else { return }
                    self.isStarting = false
                    self.isRunning = false
                    self.devices = []
                    self.selectedDeviceID = ""
                    self.errorMessage = "利用できるカメラがありません。外部カメラやContinuity Cameraを確認してください。"
                }
                return
            }

            do {
                // Create the replacement input *before* touching the working session.
                let newInput = try AVCaptureDeviceInput(device: device)
                self.session.beginConfiguration()
                let oldInputs = self.session.inputs
                for input in oldInputs { self.session.removeInput(input) }

                var configurationError: Error?
                if self.session.canAddInput(newInput) {
                    self.session.addInput(newInput)
                    if !self.outputAttached {
                        if self.session.canAddOutput(self.output) {
                            self.output.alwaysDiscardsLateVideoFrames = true
                            self.session.addOutput(self.output)
                            self.output.setSampleBufferDelegate(self.processor, queue: self.processingQueue)
                            self.outputAttached = true
                        } else {
                            configurationError = CameraError.cannotAddOutput
                        }
                    }
                } else {
                    configurationError = CameraError.cannotAddInput
                }
                if configurationError != nil {
                    // Keep the previous camera usable when switching fails.
                    self.session.inputs.forEach { self.session.removeInput($0) }
                    for input in oldInputs where self.session.canAddInput(input) {
                        self.session.addInput(input)
                    }
                } else if let connection = self.output.connection(with: .video),
                          connection.isVideoMirroringSupported {
                    connection.automaticallyAdjustsVideoMirroring = false
                    connection.isVideoMirrored = false
                }
                self.session.commitConfiguration()
                if let error = configurationError { throw error }

                if !self.session.isRunning { self.session.startRunning() }
                let running = self.session.isRunning
                let clock = self.session.synchronizationClock
                if running && clock == nil { self.session.stopRunning() }
                DispatchQueue.main.async {
                    guard self.requestRevision == revision else { return }
                    // A second fence excludes buffers produced by the previous
                    // camera DURING configuration, even if inference finishes later.
                    self.invalidateRecognition(captureClock: clock)
                    self.devices = cameras.map { CameraOption(id: $0.uniqueID, name: $0.localizedName) }
                    self.selectedDeviceID = device.uniqueID
                    self.isStarting = false
                    self.isRunning = running && clock != nil
                    self.errorMessage = !running ? "カメラを開始できませんでした。"
                        : (clock == nil ? "カメラの時刻を取得できません。停止して再開してください。" : nil)
                }
            } catch {
                let running = self.session.isRunning
                let clock = self.session.synchronizationClock
                if running && clock == nil { self.session.stopRunning() }
                // Restore the picker to the camera that actually remains attached.
                let activeDeviceID = self.session.inputs
                    .compactMap { ($0 as? AVCaptureDeviceInput)?.device.uniqueID }
                    .first ?? ""
                DispatchQueue.main.async {
                    guard self.requestRevision == revision else { return }
                    self.invalidateRecognition(captureClock: clock)
                    self.isStarting = false
                    self.isRunning = running && clock != nil
                    self.selectedDeviceID = activeDeviceID
                    self.errorMessage = "カメラ初期化エラー: \(error.localizedDescription)"
                }
            }
        }
    }

    private enum CameraError: LocalizedError {
        case cannotAddInput, cannotAddOutput
        var errorDescription: String? {
            switch self {
            case .cannotAddInput: "カメラ入力を追加できません。"
            case .cannotAddOutput: "映像出力を追加できません。"
            }
        }
    }
}

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
    var onPose: ((PoseFrame?) -> Void)?
    private var lastInference = -Double.infinity

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastInference >= 1.0 / 12.0 else { return }
        lastInference = now
        onPose?(detector.detect(sampleBuffer, timestamp: now))
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

    private let sessionQueue = DispatchQueue(label: "fitboss.camera.session", qos: .userInitiated)
    private let processingQueue = DispatchQueue(label: "fitboss.camera.vision", qos: .userInitiated)
    private let processor = FrameProcessor()
    private let output = AVCaptureVideoDataOutput()
    private var outputAttached = false
    // Main-thread revision invalidates late permission prompts and camera start completions.
    private var requestRevision = 0
    private var evaluator = PushUpEvaluator()

    override init() {
        var initial = PushUpEvaluator()
        self.result = initial.process(nil)
        super.init()
        processor.onPose = { [weak self] pose in
            DispatchQueue.main.async { [weak self] in
                guard let self, self.isRunning && !self.isStarting else { return }
                self.consume(pose)
            }
        }
    }

    func requestAndStart() {
        guard !isRunning && !isStarting else { return }
        requestRevision &+= 1
        let revision = requestRevision
        isStarting = true
        errorMessage = nil
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
        consume(nil) // Do not continue a partial repetition across camera changes.
        configureAndStart(revision: revision)
    }

    func resetCounter() {
        evaluator.reset()
        result = evaluator.process(nil)
    }

    func stop() {
        requestRevision &+= 1
        isStarting = false
        isRunning = false
        consume(nil) // Immediately invalidate delayed Vision callbacks.
        sessionQueue.async {
            if self.session.isRunning { self.session.stopRunning() }
        }
    }

    private func consume(_ nextPose: PoseFrame?) {
        pose = nextPose
        result = evaluator.process(nextPose)
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
                DispatchQueue.main.async {
                    guard self.requestRevision == revision else { return }
                    self.devices = cameras.map { CameraOption(id: $0.uniqueID, name: $0.localizedName) }
                    self.selectedDeviceID = device.uniqueID
                    self.isStarting = false
                    self.isRunning = running
                    self.errorMessage = running ? nil : "カメラを開始できませんでした。"
                }
            } catch {
                let running = self.session.isRunning
                // Restore the picker to the camera that actually remains attached.
                let activeDeviceID = self.session.inputs
                    .compactMap { ($0 as? AVCaptureDeviceInput)?.device.uniqueID }
                    .first ?? ""
                DispatchQueue.main.async {
                    guard self.requestRevision == revision else { return }
                    self.isStarting = false
                    self.isRunning = running
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

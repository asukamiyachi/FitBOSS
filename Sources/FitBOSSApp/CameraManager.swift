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
    @Published private(set) var errorMessage: String?

    private let sessionQueue = DispatchQueue(label: "fitboss.camera.session", qos: .userInitiated)
    private let processingQueue = DispatchQueue(label: "fitboss.camera.vision", qos: .userInitiated)
    private let processor = FrameProcessor()
    private let output = AVCaptureVideoDataOutput()
    private var outputAttached = false
    private var evaluator = PushUpEvaluator()

    override init() {
        var initial = PushUpEvaluator()
        self.result = initial.process(nil)
        super.init()
        processor.onPose = { [weak self] pose in
            DispatchQueue.main.async { [weak self] in self?.consume(pose) }
        }
    }

    func requestAndStart() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureAndStart()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted { self?.configureAndStart() }
                    else { self?.errorMessage = "カメラへのアクセスが許可されていません。システム設定で許可してください。" }
                }
            }
        case .denied, .restricted:
            errorMessage = "カメラへのアクセスが許可されていません。システム設定 → プライバシーとセキュリティ → カメラを確認してください。"
        @unknown default:
            errorMessage = "カメラの権限を確認できませんでした。"
        }
    }

    func selectCamera(id: String) {
        selectedDeviceID = id
        if isRunning { configureAndStart() }
    }

    func resetCounter() {
        evaluator.reset()
        result = evaluator.process(nil)
    }

    func stop() {
        sessionQueue.async {
            if self.session.isRunning { self.session.stopRunning() }
            DispatchQueue.main.async {
                self.isRunning = false
                self.consume(nil)
            }
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

    private func configureAndStart() {
        errorMessage = nil
        let cameraID = selectedDeviceID
        sessionQueue.async {
            let cameras = self.availableDevices()
            guard let device = cameras.first(where: { $0.uniqueID == cameraID }) ?? cameras.first else {
                DispatchQueue.main.async {
                    self.devices = []
                    self.errorMessage = "利用できるカメラがありません。外部カメラやContinuity Cameraを確認してください。"
                }
                return
            }

            self.session.beginConfiguration()
            self.session.sessionPreset = .hd1280x720
            self.session.inputs.forEach { self.session.removeInput($0) }
            do {
                let input = try AVCaptureDeviceInput(device: device)
                guard self.session.canAddInput(input) else { throw CameraError.cannotAddInput }
                self.session.addInput(input)
                if !self.outputAttached {
                    self.output.alwaysDiscardsLateVideoFrames = true
                    self.output.setSampleBufferDelegate(self.processor, queue: self.processingQueue)
                    guard self.session.canAddOutput(self.output) else { throw CameraError.cannotAddOutput }
                    self.session.addOutput(self.output)
                    self.outputAttached = true
                }
                if let connection = self.output.connection(with: .video), connection.isVideoMirroringSupported {
                    connection.isVideoMirrored = false
                }
                self.session.commitConfiguration()
                if !self.session.isRunning { self.session.startRunning() }
                DispatchQueue.main.async {
                    self.devices = cameras.map { CameraOption(id: $0.uniqueID, name: $0.localizedName) }
                    self.selectedDeviceID = device.uniqueID
                    self.isRunning = self.session.isRunning
                    self.errorMessage = self.session.isRunning ? nil : "カメラを開始できませんでした。"
                }
            } catch {
                self.session.commitConfiguration()
                DispatchQueue.main.async {
                    self.isRunning = false
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

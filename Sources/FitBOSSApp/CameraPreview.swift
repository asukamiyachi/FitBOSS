import AppKit
import AVFoundation
import FitBOSSCore
import SwiftUI

struct CameraPreview: NSViewRepresentable {
    let session: AVCaptureSession
    let pose: PoseFrame?

    func makeNSView(context: Context) -> PosePreviewView {
        PosePreviewView(session: session)
    }

    func updateNSView(_ nsView: PosePreviewView, context: Context) {
        nsView.updatePose(pose)
    }
}

final class PosePreviewView: NSView {
    private let preview: AVCaptureVideoPreviewLayer
    private let overlay = CAShapeLayer()
    private var lastPose: PoseFrame?

    private let bones: [(BodyJoint, BodyJoint)] = [
        (.leftShoulder, .leftElbow), (.leftElbow, .leftWrist),
        (.rightShoulder, .rightElbow), (.rightElbow, .rightWrist),
        (.leftShoulder, .leftHip), (.rightShoulder, .rightHip),
        (.leftHip, .leftKnee), (.rightHip, .rightKnee),
        (.leftKnee, .leftAnkle), (.rightKnee, .rightAnkle),
        (.leftShoulder, .rightShoulder), (.leftHip, .rightHip)
    ]

    init(session: AVCaptureSession) {
        self.preview = AVCaptureVideoPreviewLayer(session: session)
        super.init(frame: .zero)
        wantsLayer = true
        preview.videoGravity = .resizeAspect
        overlay.lineWidth = 4
        overlay.strokeColor = NSColor.systemMint.cgColor
        overlay.fillColor = NSColor.clear.cgColor
        overlay.lineCap = .round
        layer?.addSublayer(preview)
        preview.addSublayer(overlay)
    }

    required init?(coder: NSCoder) { fatalError("Use init(session:)") }

    override func layout() {
        super.layout()
        preview.frame = bounds
        overlay.frame = preview.bounds
        redraw()
    }

    func updatePose(_ pose: PoseFrame?) {
        lastPose = pose
        redraw()
    }

    private func redraw() {
        guard let pose = lastPose else {
            overlay.path = nil
            return
        }
        let path = CGMutablePath()
        for (first, second) in bones {
            guard let a = pose[first], let b = pose[second],
                  a.confidence >= 0.5, b.confidence >= 0.5 else { continue }
            // Vision: bottom-left origin; capture device: top-left origin.
            let p1 = preview.layerPointConverted(fromCaptureDevicePoint: CGPoint(x: a.x, y: 1 - a.y))
            let p2 = preview.layerPointConverted(fromCaptureDevicePoint: CGPoint(x: b.x, y: 1 - b.y))
            path.move(to: p1)
            path.addLine(to: p2)
        }
        overlay.path = path
    }
}

import AVFoundation
import Foundation
import Vision
import FitBOSSCore

/// The only component that knows about Vision. All frames stay on-device.
final class VisionPoseDetector {
    private let joints: [(BodyJoint, VNHumanBodyPoseObservation.JointName)] = [
        (.leftShoulder, .leftShoulder), (.rightShoulder, .rightShoulder),
        (.leftElbow, .leftElbow), (.rightElbow, .rightElbow),
        (.leftWrist, .leftWrist), (.rightWrist, .rightWrist),
        (.leftHip, .leftHip), (.rightHip, .rightHip),
        (.leftKnee, .leftKnee), (.rightKnee, .rightKnee),
        (.leftAnkle, .leftAnkle), (.rightAnkle, .rightAnkle)
    ]

    func detect(_ sampleBuffer: CMSampleBuffer, timestamp: TimeInterval) -> PoseFrame? {
        guard let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return nil }
        let request = VNDetectHumanBodyPoseRequest()
        let handler = VNImageRequestHandler(cvPixelBuffer: buffer, orientation: .up, options: [:])
        do {
            try handler.perform([request])
            guard let observation = request.results?.first else { return nil }
            var mapped: [BodyJoint: Landmark] = [:]
            for (joint, name) in joints {
                guard let point = try? observation.recognizedPoint(name),
                      point.confidence > 0 else { continue }
                mapped[joint] = Landmark(
                    x: Double(point.location.x),
                    y: Double(point.location.y),
                    confidence: Double(point.confidence)
                )
            }
            return mapped.isEmpty ? nil : PoseFrame(timestamp: timestamp, joints: mapped)
        } catch {
            return nil
        }
    }
}

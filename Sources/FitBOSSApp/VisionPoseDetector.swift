import AVFoundation
import Foundation
import Vision
import FitBOSSCore

enum PoseDetectionFailure { case noImage, noPerson, visionError }

struct PoseDetection {
    let frame: PoseFrame?
    let failure: PoseDetectionFailure?
}

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

    func detect(_ sampleBuffer: CMSampleBuffer, timestamp: TimeInterval) -> PoseDetection {
        guard let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return PoseDetection(frame: nil, failure: .noImage)
        }
        let request = VNDetectHumanBodyPoseRequest()
        let handler = VNImageRequestHandler(cvPixelBuffer: buffer, orientation: .up, options: [:])
        do {
            try handler.perform([request])
            guard let observation = request.results?.first else {
                return PoseDetection(frame: nil, failure: .noPerson)
            }
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
            let aspectRatio = Double(CVPixelBufferGetWidth(buffer)) / Double(CVPixelBufferGetHeight(buffer))
            return PoseDetection(frame: PoseFrame(timestamp: timestamp, joints: mapped,
                                                 imageAspectRatio: aspectRatio), failure: nil)
        } catch {
            return PoseDetection(frame: nil, failure: .visionError)
        }
    }
}

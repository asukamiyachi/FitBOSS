import Foundation

/// Experimental 2D elbow-angle counter, NOT a medically validated form evaluator.
/// Thresholds are provisional and must be calibrated with real camera recordings.
/// In particular, a front-on camera can distort 2D elbow angles.
public struct PushUpEvaluator: ExerciseEvaluator {
    public let exerciseID = "push_up"
    public let unit: ExerciseUnit = .repetitions

    public var upAngle: Double = 155
    public var downAngle: Double = 105
    public var minimumConfidence: Double = 0.50
    public var minimumRepDuration: TimeInterval = 0.25
    public var maximumFrameGap: TimeInterval = 0.70

    private enum Position { case waiting, up, down }
    private var position: Position = .waiting
    private var upFrames = 0
    private var downFrames = 0
    private var downAt: TimeInterval?
    private var lastTimestamp: TimeInterval?
    private var repetitions = 0

    public init() {}

    public mutating func reset() {
        position = .waiting
        upFrames = 0
        downFrames = 0
        downAt = nil
        lastTimestamp = nil
        repetitions = 0
    }

    public mutating func process(_ frame: PoseFrame?) -> ExerciseResult {
        guard let frame, let sample = bestArm(in: frame) else {
            abandonPartialRep()
            return report(.searching, angle: nil, confidence: 0)
        }
        if let previous = lastTimestamp,
           frame.timestamp <= previous || frame.timestamp - previous > maximumFrameGap {
            abandonPartialRep()
        }
        lastTimestamp = frame.timestamp

        switch position {
        case .waiting:
            upFrames = sample.angle >= upAngle ? upFrames + 1 : 0
            if upFrames >= 2 {
                position = .up
                upFrames = 0
            }
        case .up:
            downFrames = sample.angle <= downAngle ? downFrames + 1 : 0
            if downFrames >= 2 {
                position = .down
                downAt = frame.timestamp
                downFrames = 0
            }
        case .down:
            upFrames = sample.angle >= upAngle ? upFrames + 1 : 0
            if upFrames >= 2 {
                if let downAt, frame.timestamp - downAt >= minimumRepDuration {
                    repetitions += 1
                }
                position = .up
                downAt = nil
                upFrames = 0
            }
        }
        let phase: TrackingPhase
        switch position {
        case .waiting: phase = .searching
        case .up: phase = .ready
        case .down: phase = .lowering
        }
        return report(phase, angle: sample.angle, confidence: sample.confidence)
    }

    private mutating func abandonPartialRep() {
        position = .waiting
        upFrames = 0
        downFrames = 0
        downAt = nil
        lastTimestamp = nil
    }

    private func report(_ phase: TrackingPhase, angle: Double?, confidence: Double) -> ExerciseResult {
        ExerciseResult(exerciseID: exerciseID, unit: unit, value: repetitions, phase: phase, angleDegrees: angle, confidence: confidence)
    }

    private func bestArm(in frame: PoseFrame) -> (angle: Double, confidence: Double)? {
        let arms: [(BodyJoint, BodyJoint, BodyJoint)] = [
            (.leftShoulder, .leftElbow, .leftWrist),
            (.rightShoulder, .rightElbow, .rightWrist)
        ]
        return arms.compactMap { a, b, c -> (angle: Double, confidence: Double)? in
            guard let shoulder = frame[a], let elbow = frame[b], let wrist = frame[c] else { return nil }
            let confidence = min(shoulder.confidence, elbow.confidence, wrist.confidence)
            guard confidence >= minimumConfidence, let angle = Self.angle(shoulder, elbow, wrist) else { return nil }
            return (angle, confidence)
        }.max(by: { $0.confidence < $1.confidence })
    }

    public static func angle(_ a: Landmark, _ vertex: Landmark, _ c: Landmark) -> Double? {
        let ux = a.x - vertex.x, uy = a.y - vertex.y
        let vx = c.x - vertex.x, vy = c.y - vertex.y
        let denominator = hypot(ux, uy) * hypot(vx, vy)
        guard denominator > 1e-8 else { return nil }
        let cosine = max(-1, min(1, (ux * vx + uy * vy) / denominator))
        return acos(cosine) * 180 / .pi
    }
}

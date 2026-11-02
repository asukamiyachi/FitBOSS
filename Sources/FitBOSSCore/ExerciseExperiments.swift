import Foundation

public enum LocalExercise: String, CaseIterable, Identifiable, Sendable {
    case pushUp = "腕立て伏せ", squat = "スクワット", plank = "プランク"
    public var id: String { rawValue }
}

/// Experimental knee-angle counter; it reuses the arm-independent cycle logic.
public struct SquatEvaluator: ExerciseEvaluator {
    public let exerciseID = "squat"
    public let unit: ExerciseUnit = .repetitions
    private var counter = PushUpEvaluator()
    public var diagnostic: PushUpDiagnostic { counter.diagnostic }
    public init() {}
    public mutating func reset() { counter.reset() }
    public mutating func interruptTracking() -> ExerciseResult { convert(counter.interruptTracking()) }
    public mutating func process(_ frame: PoseFrame?) -> ExerciseResult {
        guard let frame else { return convert(counter.process(nil)) }
        var joints: [BodyJoint: Landmark] = [:]
        for (from, to) in [(BodyJoint.leftHip, BodyJoint.leftShoulder), (.leftKnee, .leftElbow), (.leftAnkle, .leftWrist), (.rightHip, .rightShoulder), (.rightKnee, .rightElbow), (.rightAnkle, .rightWrist)] {
            joints[to] = frame[from]
        }
        return convert(counter.process(PoseFrame(timestamp: frame.timestamp, joints: joints, imageAspectRatio: frame.imageAspectRatio)))
    }
    private func convert(_ value: ExerciseResult) -> ExerciseResult {
        ExerciseResult(exerciseID: exerciseID, unit: unit, value: value.value, phase: value.phase, angleDegrees: value.angleDegrees, confidence: value.confidence)
    }
}

/// Local experimental timer, not a form or health assessment.
public struct PlankEvaluator: ExerciseEvaluator {
    public let exerciseID = "plank"
    public let unit: ExerciseUnit = .seconds
    private var elapsed: Double = 0
    private var previous: TimeInterval?
    private var trackedShoulder: BodyJoint?
    public private(set) var diagnostic: PushUpDiagnostic = .noPose
    public init() {}
    public mutating func reset() { elapsed = 0; previous = nil; trackedShoulder = nil; diagnostic = .noPose }
    public mutating func interruptTracking() -> ExerciseResult {
        previous = nil; trackedShoulder = nil; diagnostic = .trackingInterrupted
        return report(.searching, nil, 0)
    }
    public mutating func process(_ frame: PoseFrame?) -> ExerciseResult {
        guard let frame else { previous = nil; trackedShoulder = nil; diagnostic = .noPose; return report(.searching, nil, 0) }
        guard frame.timestamp.isFinite, frame.timestamp >= 0 else { previous = nil; trackedShoulder = nil; diagnostic = .invalidTimestamp; return report(.searching, nil, 0) }
        if let previous, frame.timestamp <= previous || frame.timestamp - previous > 0.7 {
            self.previous = nil; trackedShoulder = nil; diagnostic = .invalidTimestamp; return report(.searching, nil, 0)
        }
        for (s, h, k) in [(BodyJoint.leftShoulder, BodyJoint.leftHip, BodyJoint.leftKnee), (.rightShoulder, .rightHip, .rightKnee)] {
            guard trackedShoulder == nil || trackedShoulder == s else { continue }
            guard let shoulder = frame[s], let hip = frame[h], let knee = frame[k] else { continue }
            guard [shoulder, hip, knee].allSatisfy({ $0.confidence.isFinite && (0.5...1).contains($0.confidence) }) else { continue }
            let confidence = min(shoulder.confidence, hip.confidence, knee.confidence)
            guard confidence.isFinite, confidence >= 0.5, confidence <= 1,
                  let angle = PushUpEvaluator.angle(shoulder, hip, knee, imageAspectRatio: frame.imageAspectRatio) else { continue }
            let dx = abs((shoulder.x - hip.x) * frame.imageAspectRatio)
            let dy = abs(shoulder.y - hip.y)
            guard angle >= 150, dx > dy else { previous = nil; trackedShoulder = nil; diagnostic = .stabilizing; return report(.searching, angle, confidence) }
            if let previous { elapsed += frame.timestamp - previous }
            previous = frame.timestamp; trackedShoulder = s; diagnostic = .ready
            return report(.ready, angle, confidence)
        }
        previous = nil; trackedShoulder = nil; diagnostic = .missingJoints
        return report(.searching, nil, 0)
    }
    private func report(_ phase: TrackingPhase, _ angle: Double?, _ confidence: Double) -> ExerciseResult {
        ExerciseResult(exerciseID: exerciseID, unit: unit, value: Int(elapsed), phase: phase, angleDegrees: angle, confidence: confidence)
    }
}

import Foundation

/// Coordinates are normalized into [0, 1], origin at the bottom-left of the image.
public struct Landmark: Equatable, Sendable {
    public let x: Double
    public let y: Double
    public let confidence: Double

    public init(x: Double, y: Double, confidence: Double) {
        self.x = x
        self.y = y
        self.confidence = confidence
    }
}

public enum BodyJoint: String, CaseIterable, Hashable, Sendable {
    case leftShoulder, rightShoulder, leftElbow, rightElbow
    case leftWrist, rightWrist, leftHip, rightHip
    case leftKnee, rightKnee, leftAnkle, rightAnkle
}

public struct PoseFrame: Sendable {
    /// Monotonic time, e.g. ProcessInfo.processInfo.systemUptime.
    public let timestamp: TimeInterval
    public let joints: [BodyJoint: Landmark]

    public init(timestamp: TimeInterval, joints: [BodyJoint: Landmark]) {
        self.timestamp = timestamp
        self.joints = joints
    }

    public subscript(_ joint: BodyJoint) -> Landmark? { joints[joint] }
}

public enum ExerciseUnit: String, Sendable { case repetitions, seconds }

public enum TrackingPhase: String, Sendable {
    case searching, ready, lowering, rising
}

public struct ExerciseResult: Sendable {
    public let exerciseID: String
    public let unit: ExerciseUnit
    public let value: Int
    public let phase: TrackingPhase
    public let angleDegrees: Double?
    public let confidence: Double

    public init(exerciseID: String, unit: ExerciseUnit, value: Int, phase: TrackingPhase, angleDegrees: Double?, confidence: Double) {
        self.exerciseID = exerciseID
        self.unit = unit
        self.value = value
        self.phase = phase
        self.angleDegrees = angleDegrees
        self.confidence = confidence
    }
}

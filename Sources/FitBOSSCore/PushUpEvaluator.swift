import Foundation

/// Diagnostic reasons, independent of UI, cameras, persistence and networking.
public enum PushUpDiagnostic: String, Error, Sendable {
    case noPose, missingJoints, lowConfidence, invalidGeometry, invalidTimestamp
    case invalidConfiguration, stabilizing, recovering, trackingInterrupted, armChanged
    case ready, lowering, counted
}

/// Experimental 2D elbow-angle counter; not a form or medical assessment.
public struct PushUpEvaluator: ExerciseEvaluator {
    public let exerciseID = "push_up"
    public let unit: ExerciseUnit = .repetitions

    public var upAngle: Double = 155
    public var downAngle: Double = 105
    public var minimumConfidence: Double = 0.50
    public var minimumRepDuration: TimeInterval = 0.25
    public var maximumFrameGap: TimeInterval = 0.70
    /// Two observations AND this dwell time are required at an endpoint.
    /// 80ms approximates the existing two-frame rule at the nominal 12fps.
    public var minimumStableDuration: TimeInterval = 0.08
    /// Resume only the SAME arm and SAME endpoint, re-observed stably.
    public var maximumTrackingInterruption: TimeInterval = 0.25
    public private(set) var diagnostic: PushUpDiagnostic = .noPose

    private enum Position { case waiting, up, down }
    private var position: Position = .waiting
    private var dwellStart: TimeInterval?
    private var dwellFrames = 0
    private var recoveryStart: TimeInterval?
    private var recoveryFrames = 0
    private var interrupted = false
    private var downAt: TimeInterval?
    private var lastTimestamp: TimeInterval?
    private var lastValidTimestamp: TimeInterval?
    private var repetitions = 0
    private var trackedArm: BodyJoint?
    // Numerical tolerance (1 microsecond), not a relaxed motion threshold.
    private static let timeEpsilon = 1e-6

    public init() {}

    public mutating func reset() {
        interruptTracking()
        repetitions = 0
        diagnostic = .noPose
    }

    /// Hard boundary for camera changes, stop/restart and counter reset.
    /// Unlike a missing detection, a new capture stream never resumes a cycle.
    @discardableResult
    public mutating func interruptTracking() -> ExerciseResult {
        position = .waiting
        clearDwell()
        recoveryStart = nil
        recoveryFrames = 0
        interrupted = false
        downAt = nil
        lastTimestamp = nil
        lastValidTimestamp = nil
        trackedArm = nil
        diagnostic = .trackingInterrupted
        return report(.searching)
    }

    public mutating func process(_ frame: PoseFrame?) -> ExerciseResult {
        guard validConfiguration else {
            interruptTracking()
            diagnostic = .invalidConfiguration
            return report(.searching)
        }
        guard let frame else {
            loseObservation(.noPose)
            return report(.searching)
        }
        guard frame.timestamp.isFinite, frame.timestamp >= 0 else {
            interruptTracking()
            diagnostic = .invalidTimestamp
            return report(.searching)
        }
        if let previous = lastTimestamp {
            if frame.timestamp <= previous {
                interruptTracking()
                // Reject duplicates/backwards time instead of using it to arm a rep.
                lastTimestamp = frame.timestamp
                diagnostic = .invalidTimestamp
                return report(.searching)
            }
            if frame.timestamp - previous > maximumFrameGap + Self.timeEpsilon {
                // A fresh, finite frame can start a NEW baseline after a long gap.
                interruptTracking()
            }
        }
        lastTimestamp = frame.timestamp
        let selection = selectArm(in: frame)
        guard let sample = selection.sample else {
            if selection.reason == .armChanged || (trackedArm != nil && lastValidTimestamp.map {
                frame.timestamp - $0 > maximumTrackingInterruption + Self.timeEpsilon
            } == true) {
                interruptTracking()
                lastTimestamp = frame.timestamp
                diagnostic = .armChanged
            } else { loseObservation(selection.reason) }
            return report(.searching)
        }

        if interrupted {
            let sameEndpoint = position == .up ? sample.angle >= upAngle : sample.angle <= downAngle
            if let last = lastValidTimestamp,
               frame.timestamp - last <= maximumTrackingInterruption + Self.timeEpsilon,
               sameEndpoint {
                if recoveryStart == nil { recoveryStart = frame.timestamp }
                recoveryFrames += 1
                lastValidTimestamp = frame.timestamp
                diagnostic = .recovering
                if recoveryFrames >= 2, let recoveryStart,
                   frame.timestamp - recoveryStart + Self.timeEpsilon >= minimumStableDuration {
                    interrupted = false
                    self.recoveryStart = nil
                    recoveryFrames = 0
                    diagnostic = position == .up ? .ready : .lowering
                }
                // Never make a count or a phase transition on a recovery sample.
                return report(interrupted ? .searching : phase, sample: sample)
            }
            // Motion across an unseen endpoint cannot supply a missing transition.
            interruptTracking()
            lastTimestamp = frame.timestamp
        }
        trackedArm = sample.arm
        lastValidTimestamp = frame.timestamp
        diagnostic = position == .waiting ? .stabilizing : (position == .up ? .ready : .lowering)
        let atEndpoint = position == .up ? sample.angle <= downAngle : sample.angle >= upAngle
        if stable(atEndpoint, at: frame.timestamp) {
            switch position {
            case .waiting:
                position = .up
                diagnostic = .ready
            case .up:
                position = .down
                downAt = frame.timestamp
                diagnostic = .lowering
            case .down:
                if let downAt, frame.timestamp - downAt + Self.timeEpsilon >= minimumRepDuration {
                    repetitions += 1
                    diagnostic = .counted
                } else {
                    diagnostic = .ready
                }
                position = .up
                downAt = nil
            }
            clearDwell()
        }
        return report(phase, sample: sample)
    }

    private var validConfiguration: Bool {
        [upAngle, downAngle, minimumConfidence, minimumRepDuration, maximumFrameGap,
         minimumStableDuration, maximumTrackingInterruption].allSatisfy(\.isFinite)
        && downAngle >= 0 && upAngle <= 180 && downAngle < upAngle
        && (0...1).contains(minimumConfidence) && minimumRepDuration >= 0
        && maximumFrameGap > 0 && minimumStableDuration >= 0
        && maximumTrackingInterruption >= 0 && maximumTrackingInterruption <= maximumFrameGap
    }

    private var phase: TrackingPhase {
        switch position {
        case .waiting: .searching
        case .up: .ready
        case .down: .lowering
        }
    }

    private mutating func clearDwell() { dwellStart = nil; dwellFrames = 0 }

    private mutating func stable(_ matches: Bool, at timestamp: TimeInterval) -> Bool {
        guard matches else { clearDwell(); return false }
        if dwellStart == nil { dwellStart = timestamp }
        dwellFrames += 1
        guard let dwellStart else { return false }
        return dwellFrames >= 2 && timestamp - dwellStart + Self.timeEpsilon >= minimumStableDuration
    }

    private mutating func loseObservation(_ reason: PushUpDiagnostic) {
        clearDwell()
        recoveryStart = nil
        recoveryFrames = 0
        interrupted = position != .waiting
        diagnostic = reason
    }

    private struct ArmSample {
        let arm: BodyJoint
        let angle: Double
        let confidence: Double
    }

    private func report(_ phase: TrackingPhase, sample: ArmSample? = nil) -> ExerciseResult {
        ExerciseResult(exerciseID: exerciseID, unit: unit, value: repetitions, phase: phase,
                       angleDegrees: sample?.angle, confidence: sample?.confidence ?? 0)
    }

    private func selectArm(in frame: PoseFrame) -> (sample: ArmSample?, reason: PushUpDiagnostic) {
        let arms: [(BodyJoint, BodyJoint, BodyJoint)] = [
            (.leftShoulder, .leftElbow, .leftWrist), (.rightShoulder, .rightElbow, .rightWrist)
        ]
        let candidates: [(BodyJoint, Result<ArmSample, PushUpDiagnostic>)] = arms.map { a, b, c in
            guard let shoulder = frame[a], let elbow = frame[b], let wrist = frame[c] else {
                return (b, .failure(.missingJoints))
            }
            let points = [shoulder, elbow, wrist]
            guard points.allSatisfy({ $0.confidence.isFinite && (0...1).contains($0.confidence) }) else {
                return (b, .failure(.lowConfidence))
            }
            let confidence = points.map(\.confidence).min() ?? 0
            guard confidence >= minimumConfidence else { return (b, .failure(.lowConfidence)) }
            guard let angle = Self.angle(shoulder, elbow, wrist, imageAspectRatio: frame.imageAspectRatio) else {
                return (b, .failure(.invalidGeometry))
            }
            return (b, .success(ArmSample(arm: b, angle: angle, confidence: confidence)))
        }
        if let trackedArm, let chosen = candidates.first(where: { $0.0 == trackedArm }) {
            switch chosen.1 {
            case .success(let sample): return (sample, .ready)
            case .failure(let reason):
                // Another visible arm is not a switch. Keep the chosen arm locked
                // while the bounded same-endpoint recovery policy runs.
                return (nil, reason)
            }
        }
        let available = candidates.compactMap { try? $0.1.get() }
        if let sample = available.max(by: { $0.confidence < $1.confidence }) { return (sample, .ready) }
        // Prefer a complete arm's confidence/geometry reason over an absent arm.
        let reasons = candidates.compactMap { item -> PushUpDiagnostic? in
            if case .failure(let reason) = item.1 { return reason }; return nil
        }
        return (nil, reasons.first(where: { $0 != .missingJoints }) ?? .missingJoints)
    }

    public static func angle(_ a: Landmark, _ vertex: Landmark, _ c: Landmark, imageAspectRatio: Double = 1) -> Double? {
        guard imageAspectRatio.isFinite, imageAspectRatio > 0,
              [a, vertex, c].allSatisfy({ $0.x.isFinite && $0.y.isFinite }) else { return nil }
        let ux = (a.x - vertex.x) * imageAspectRatio, uy = a.y - vertex.y
        let vx = (c.x - vertex.x) * imageAspectRatio, vy = c.y - vertex.y
        let denominator = hypot(ux, uy) * hypot(vx, vy)
        guard denominator.isFinite, denominator > 1e-8 else { return nil }
        let cosine = (ux * vx + uy * vy) / denominator
        guard cosine.isFinite else { return nil }
        return acos(max(-1, min(1, cosine))) * 180 / .pi
    }
}

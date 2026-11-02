import Foundation
import FitBOSSCore

/// Main-thread state. Capture/inference results carry the revision they began in.
/// A capture-time fence also rejects an old buffer dequeued after a camera change.
struct CameraRecognitionState {
    private var evaluator = PushUpEvaluator()
    private var squat = SquatEvaluator()
    private var plank = PlankEvaluator()
    private(set) var exercise: LocalExercise = .pushUp
    private(set) var revision = 0
    private var earliestCaptureTime = -Double.infinity
    private(set) var result: ExerciseResult
    var diagnostic: PushUpDiagnostic {
        switch exercise { case .pushUp: evaluator.diagnostic; case .squat: squat.diagnostic; case .plank: plank.diagnostic }
    }

    init() { result = evaluator.process(nil) }

    mutating func select(_ exercise: LocalExercise, at timestamp: TimeInterval) {
        self.exercise = exercise
        invalidate(at: timestamp, resetCount: true)
    }

    mutating func invalidate(at timestamp: TimeInterval, resetCount: Bool = false) {
        revision &+= 1
        earliestCaptureTime = timestamp
        switch exercise {
        case .pushUp:
            if resetCount { evaluator.reset(); result = evaluator.process(nil) }
            else { result = evaluator.interruptTracking() }
        case .squat:
            if resetCount { squat.reset(); result = squat.process(nil) }
            else { result = squat.interruptTracking() }
        case .plank:
            if resetCount { plank.reset(); result = plank.process(nil) }
            else { result = plank.interruptTracking() }
        }
    }

    @discardableResult
    mutating func consume(_ pose: PoseFrame?, capturedAt: TimeInterval, revision: Int,
                          invalidTimestamp: Bool = false) -> Bool {
        guard revision == self.revision, capturedAt.isFinite,
              capturedAt >= earliestCaptureTime else { return false }
        switch exercise {
        case .pushUp: result = invalidTimestamp ? evaluator.interruptTracking() : evaluator.process(pose)
        case .squat: result = invalidTimestamp ? squat.interruptTracking() : squat.process(pose)
        case .plank: result = invalidTimestamp ? plank.interruptTracking() : plank.process(pose)
        }
        return true
    }
}

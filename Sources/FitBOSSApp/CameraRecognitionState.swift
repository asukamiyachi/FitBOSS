import Foundation
import FitBOSSCore

/// Main-thread state. Capture/inference results carry the revision they began in.
/// A capture-time fence also rejects an old buffer dequeued after a camera change.
struct CameraRecognitionState {
    private var evaluator = PushUpEvaluator()
    private(set) var revision = 0
    private var earliestCaptureTime = -Double.infinity
    private(set) var result: ExerciseResult
    var diagnostic: PushUpDiagnostic { evaluator.diagnostic }

    init() { result = evaluator.process(nil) }

    mutating func invalidate(at timestamp: TimeInterval, resetCount: Bool = false) {
        revision &+= 1
        earliestCaptureTime = timestamp
        if resetCount {
            evaluator.reset()
            result = evaluator.process(nil)
        } else {
            result = evaluator.interruptTracking()
        }
    }

    @discardableResult
    mutating func consume(_ pose: PoseFrame?, capturedAt: TimeInterval, revision: Int) -> Bool {
        guard revision == self.revision, capturedAt.isFinite,
              capturedAt >= earliestCaptureTime else { return false }
        result = evaluator.process(pose)
        return true
    }
}

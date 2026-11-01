/// A pure, exercise-specific analyzer. Later evaluators can return repetitions or hold seconds.
/// Camera capture, UI, local persistence, and remote synchronization live outside this protocol.
public protocol ExerciseEvaluator {
    var exerciseID: String { get }
    var unit: ExerciseUnit { get }
    mutating func process(_ frame: PoseFrame?) -> ExerciseResult
    mutating func reset()
}

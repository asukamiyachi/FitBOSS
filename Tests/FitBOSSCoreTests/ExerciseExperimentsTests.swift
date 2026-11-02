import XCTest
@testable import FitBOSSCore

final class ExerciseExperimentsTests: XCTestCase {
    func squatFrame(_ degrees: Double, _ time: Double) -> PoseFrame {
        let r = degrees * .pi / 180
        return PoseFrame(timestamp: time, joints: [
            .leftHip: Landmark(x: 0.5, y: 0.8, confidence: 0.9),
            .leftKnee: Landmark(x: 0.5, y: 0.5, confidence: 0.9),
            .leftAnkle: Landmark(x: 0.5 + sin(r)*0.3, y: 0.5 + cos(r)*0.3, confidence: 0.9)])
    }
    func plankFrame(_ time: Double, confidence: Double = 0.9) -> PoseFrame {
        PoseFrame(timestamp: time, joints: [
            .leftShoulder: Landmark(x:0.2,y:0.5,confidence:confidence),
            .leftHip: Landmark(x:0.5,y:0.5,confidence:confidence),
            .leftKnee: Landmark(x:0.8,y:0.5,confidence:confidence)])
    }
    func testSquatCountsFullCycleAndRejectsPartial() {
        var full = SquatEvaluator()
        for (i, angle) in [170.0,170,135,100,95,125,165,170].enumerated() { _ = full.process(squatFrame(angle, Double(i)*0.1)) }
        XCTAssertEqual(full.process(squatFrame(170,0.9)).value,1)
        var partial = SquatEvaluator()
        for (i, angle) in [170.0,170,135,120,135,170,170].enumerated() { _ = partial.process(squatFrame(angle, Double(i)*0.1)) }
        XCTAssertEqual(partial.process(nil).value,0)
    }
    func testPlankDoesNotCountTrackingGapsOrInvalidTime() {
        var timer = PlankEvaluator()
        for t in [0.0,0.5,1.0] { _ = timer.process(plankFrame(t)) }
        XCTAssertEqual(timer.process(plankFrame(1.1)).value,1)
        _ = timer.process(nil)
        XCTAssertEqual(timer.process(plankFrame(5.0)).value,1)
        _ = timer.process(plankFrame(.nan))
        XCTAssertEqual(timer.process(plankFrame(8.0)).value,1)
        timer.reset()
        XCTAssertEqual(timer.process(nil).value,0)
    }
    func testPlankRejectsLowConfidenceAndUprightPose() {
        var timer = PlankEvaluator()
        XCTAssertEqual(timer.process(plankFrame(0,confidence:0.1)).phase,.searching)
        let upright = PoseFrame(timestamp:1, joints:[.leftShoulder:Landmark(x:0.5,y:0.8,confidence:1),.leftHip:Landmark(x:0.5,y:0.5,confidence:1),.leftKnee:Landmark(x:0.5,y:0.2,confidence:1)])
        XCTAssertEqual(timer.process(upright).phase,.searching)
        XCTAssertEqual(timer.process(upright).value,0)
    }
    func testPlankDoesNotBridgeTrackingLossAcrossBodySides() {
        var timer = PlankEvaluator()
        _ = timer.process(plankFrame(0))
        _ = timer.process(plankFrame(0.5))
        _ = timer.process(plankFrame(1))
        func right(_ time: Double) -> PoseFrame {
            PoseFrame(timestamp:time,joints:[.rightShoulder:Landmark(x:0.2,y:0.5,confidence:1),.rightHip:Landmark(x:0.5,y:0.5,confidence:1),.rightKnee:Landmark(x:0.8,y:0.5,confidence:1)])
        }
        XCTAssertEqual(timer.process(right(1.5)).phase,.searching)
        XCTAssertEqual(timer.process(right(2)).value,1)
        XCTAssertEqual(timer.process(right(2.5)).value,1)
        XCTAssertEqual(timer.process(right(3)).value,2)
    }
}

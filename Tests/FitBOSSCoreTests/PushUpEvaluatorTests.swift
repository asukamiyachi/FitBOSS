import XCTest
@testable import FitBOSSCore

final class PushUpEvaluatorTests: XCTestCase {
    private func frame(_ angle: Double, _ t: Double, confidence: Double = 0.99) -> PoseFrame {
        let rad = angle * Double.pi / 180
        return PoseFrame(timestamp: t, joints: [
            .leftShoulder: Landmark(x: 0.5, y: 0.8, confidence: confidence),
            .leftElbow: Landmark(x: 0.5, y: 0.5, confidence: confidence),
            .leftWrist: Landmark(x: 0.5 + sin(rad) * 0.3, y: 0.5 + cos(rad) * 0.3, confidence: confidence)
        ])
    }

    func testOneCompleteRepCountsOnce() {
        var counter = PushUpEvaluator()
        let angles: [Double] = [170, 170, 135, 100, 95, 125, 165, 170, 170]
        let results = angles.enumerated().map { i, angle in counter.process(frame(angle, Double(i) * 0.1)) }
        XCTAssertEqual(results.last?.value, 1)
    }

    func testShallowMotionDoesNotCount() {
        var counter = PushUpEvaluator()
        let angles: [Double] = [170, 170, 130, 120, 130, 170, 170]
        for (i, angle) in angles.enumerated() { _ = counter.process(frame(angle, Double(i) * 0.1)) }
        XCTAssertEqual(counter.process(frame(170, 0.9)).value, 0)
    }

    func testInsufficientConfidenceCannotCount() {
        var counter = PushUpEvaluator()
        for (i, angle) in [170.0, 170, 90, 90, 170, 170].enumerated() {
            _ = counter.process(frame(angle, Double(i) * 0.1, confidence: 0.2))
        }
        XCTAssertEqual(counter.process(nil).value, 0)
    }

    func testTrackingLossDiscardsPartialRep() {
        var counter = PushUpEvaluator()
        for (i, angle) in [170.0, 170, 90, 90].enumerated() {
            _ = counter.process(frame(angle, Double(i) * 0.1))
        }
        _ = counter.process(nil)
        _ = counter.process(frame(170, 0.5))
        XCTAssertEqual(counter.process(frame(170, 0.6)).value, 0)
    }

    func testResetClearsCount() {
        var counter = PushUpEvaluator()
        for (i, angle) in [170.0, 170, 90, 90, 170, 170].enumerated() {
            _ = counter.process(frame(angle, Double(i) * 0.1))
        }
        counter.reset()
        XCTAssertEqual(counter.process(frame(170, 1.0)).value, 0)
    }

    func testAngleGeometry() {
        let a = Landmark(x: 1, y: 0, confidence: 1)
        let b = Landmark(x: 0, y: 0, confidence: 1)
        let c = Landmark(x: 0, y: 1, confidence: 1)
        XCTAssertEqual(PushUpEvaluator.angle(a, b, c) ?? 0, 90, accuracy: 0.0001)
    }

    private func dualFrame(_ left: Double?, _ right: Double?, _ t: Double,
                           leftConfidence: Double = 0.9, rightConfidence: Double = 0.9) -> PoseFrame {
        var joints: [BodyJoint: Landmark] = [:]
        if let left {
            let rad = left * .pi / 180
            joints[.leftShoulder] = Landmark(x: 0.3, y: 0.8, confidence: leftConfidence)
            joints[.leftElbow] = Landmark(x: 0.3, y: 0.5, confidence: leftConfidence)
            joints[.leftWrist] = Landmark(x: 0.3 + sin(rad) * 0.3, y: 0.5 + cos(rad) * 0.3, confidence: leftConfidence)
        }
        if let right {
            let rad = right * .pi / 180
            joints[.rightShoulder] = Landmark(x: 0.7, y: 0.8, confidence: rightConfidence)
            joints[.rightElbow] = Landmark(x: 0.7, y: 0.5, confidence: rightConfidence)
            joints[.rightWrist] = Landmark(x: 0.7 + sin(rad) * 0.3, y: 0.5 + cos(rad) * 0.3, confidence: rightConfidence)
        }
        return PoseFrame(timestamp: t, joints: joints)
    }

    func testArmSelectionDoesNotSwitchMidCycle() {
        var counter = PushUpEvaluator()
        _ = counter.process(dualFrame(170, 90, 0, leftConfidence: 0.99, rightConfidence: 0.70))
        _ = counter.process(dualFrame(170, 90, 0.1, leftConfidence: 0.99, rightConfidence: 0.70))
        _ = counter.process(dualFrame(170, 90, 0.2, leftConfidence: 0.70, rightConfidence: 0.99))
        _ = counter.process(dualFrame(170, 90, 0.3, leftConfidence: 0.70, rightConfidence: 0.99))
        _ = counter.process(dualFrame(170, 90, 0.7, leftConfidence: 0.99, rightConfidence: 0.70))
        XCTAssertEqual(counter.process(dualFrame(170, 90, 0.8, leftConfidence: 0.99, rightConfidence: 0.70)).value, 0)
    }

    func testTrackedArmDisappearsCancelsPartialRep() {
        var counter = PushUpEvaluator()
        _ = counter.process(dualFrame(170, nil, 0))
        _ = counter.process(dualFrame(170, nil, 0.1))
        _ = counter.process(dualFrame(90, nil, 0.2))
        _ = counter.process(dualFrame(90, nil, 0.3))
        _ = counter.process(dualFrame(nil, 170, 0.4))
        _ = counter.process(dualFrame(170, nil, 0.5))
        XCTAssertEqual(counter.process(dualFrame(170, nil, 0.6)).value, 0)
    }

    func testLongFrameGapCannotCompletePartialRep() {
        var counter = PushUpEvaluator()
        for (i, angle) in [170.0, 170, 90, 90].enumerated() {
            _ = counter.process(frame(angle, Double(i) * 0.1))
        }
        _ = counter.process(frame(170, 2.0))
        XCTAssertEqual(counter.process(frame(170, 2.1)).value, 0)
    }
}

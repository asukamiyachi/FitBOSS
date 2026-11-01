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
}

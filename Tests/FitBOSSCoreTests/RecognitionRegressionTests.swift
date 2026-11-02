import XCTest
@testable import FitBOSSCore

final class RecognitionRegressionTests: XCTestCase {
    func testPermanentlyLostArmCanBeReacquiredWithoutCompletingOldRep() {
        var evaluator = PushUpEvaluator()
        for sample in RecognitionFixtures.samples([170,170,95,95]) { _ = evaluator.process(sample.frame) }
        for (offset, angle) in [170.0,170,170,170,170,135,95,95,125,170,170].enumerated() {
            let sample = RecognitionFixtures.Sample(time:0.4 + Double(offset)*0.1, angle:angle, rightArm:true)
            _ = evaluator.process(sample.frame)
        }
        XCTAssertEqual(evaluator.process(RecognitionFixtures.Sample(time:1.5,angle:170,rightArm:true).frame).value,1)
    }
    func testBriefTrackedArmLossRecoversWhenOtherArmIsVisible() {
        var evaluator = PushUpEvaluator()
        let angles = [170.0,170,135,100,95,95,95,95,125,165,170,170]
        var result = evaluator.process(nil)
        for (index, angle) in angles.enumerated() {
            let time = Double(index) * 0.1
            let left = RecognitionFixtures.Sample(time:time, angle:angle, confidence:index == 5 ? 0.2 : 0.99).frame!
            let right = RecognitionFixtures.Sample(time:time, angle:angle, confidence:0.7, rightArm:true).frame!
            result = evaluator.process(PoseFrame(timestamp:time, joints:left.joints.merging(right.joints) { first, _ in first }))
        }
        XCTAssertEqual(result.value, 1)
    }
    func testSyntheticCorpusCountsAndOneToOneEventTiming() {
        for trial in RecognitionFixtures.trials {
            var evaluator = PushUpEvaluator(), previous = 0
            var unmatched = trial.truth
            for sample in trial.samples {
                let result = evaluator.process(sample.frame)
                if result.value > previous {
                    let match = unmatched.firstIndex { sample.time >= $0 - 1e-9 && sample.time - $0 <= 0.450 + 1e-9 }
                    XCTAssertNotNil(match, "Unexpected/late count: \(trial.name)")
                    if let match { unmatched.remove(at: match) }
                }
                previous = result.value
            }
            XCTAssertEqual(previous, trial.truth.count, trial.name)
            XCTAssertTrue(unmatched.isEmpty, "Missed events: \(trial.name)")
        }
    }

    func testNormalCycleAtTwelveFPSAndVariableCadences() {
        for step in [1.0 / 12.0, 0.1, 0.2, 0.3] {
            var evaluator = PushUpEvaluator()
            var result = evaluator.process(nil)
            for sample in RecognitionFixtures.samples([170,170,135,100,95,125,165,170,170], step: step) {
                result = evaluator.process(sample.frame)
            }
            XCTAssertEqual(result.value, 1, "step=\(step)")
        }
    }

    func testMissingObservationDoesNotAccumulateEndpointDwell() {
        var evaluator = PushUpEvaluator()
        _ = evaluator.process(RecognitionFixtures.Sample(time: 0, angle: 170).frame)
        _ = evaluator.process(nil)
        _ = evaluator.process(RecognitionFixtures.Sample(time: 0.1, angle: 170).frame)
        XCTAssertEqual(evaluator.process(RecognitionFixtures.Sample(time: 0.11, angle: 170).frame).phase, .searching)
        XCTAssertEqual(evaluator.process(RecognitionFixtures.Sample(time: 0.20, angle: 170).frame).phase, .ready)
    }

    func testRecoveryMustBeConsecutiveAtSameEndpoint() {
        var evaluator = PushUpEvaluator()
        let signal: [Double?] = [170,170,95,95,nil,95,135,95,170,170]
        for sample in RecognitionFixtures.samples(signal) { _ = evaluator.process(sample.frame) }
        XCTAssertEqual(evaluator.process(RecognitionFixtures.Sample(time: 1.1, angle: 170).frame).value, 0)
    }

    func testShortTrackingGraceIsBoundedAndDoesNotBorrowAnotherArm() {
        var evaluator = PushUpEvaluator()
        for sample in RecognitionFixtures.samples([170,170,95,95]) { _ = evaluator.process(sample.frame) }
        _ = evaluator.process(nil)
        _ = evaluator.process(RecognitionFixtures.Sample(time:0.6,angle:95).frame)
        _ = evaluator.process(RecognitionFixtures.Sample(time:0.7,angle:95).frame)
        _ = evaluator.process(RecognitionFixtures.Sample(time:0.9,angle:170).frame)
        XCTAssertEqual(evaluator.process(RecognitionFixtures.Sample(time:1.0,angle:170).frame).value, 0)
    }

    func testHardCameraBoundaryDiscardsPartialRepAndPreservesCompletedCount() {
        var evaluator = PushUpEvaluator()
        for sample in RecognitionFixtures.samples([170,170,95,95,125,165,170]) { _ = evaluator.process(sample.frame) }
        XCTAssertEqual(evaluator.interruptTracking().value, 1)
        for sample in RecognitionFixtures.samples([170,170,95,95]) { _ = evaluator.process(sample.frame) }
        XCTAssertEqual(evaluator.interruptTracking().value, 1)
        _ = evaluator.process(RecognitionFixtures.Sample(time: 0.5, angle: 170).frame)
        XCTAssertEqual(evaluator.process(RecognitionFixtures.Sample(time: 0.6, angle: 170).frame).value, 1)
        evaluator.reset()
        XCTAssertEqual(evaluator.process(nil).value, 0)
    }

    func testNonfiniteTimestampsCancelPartialRep() {
        for invalid in [Double.nan, .infinity, -.infinity, -1] {
            var evaluator = PushUpEvaluator()
            for sample in RecognitionFixtures.samples([170,170,95,95]) { _ = evaluator.process(sample.frame) }
            _ = evaluator.process(RecognitionFixtures.Sample(time:invalid,angle:170).frame)
            XCTAssertEqual(evaluator.diagnostic, .invalidTimestamp)
            _ = evaluator.process(RecognitionFixtures.Sample(time:0.6,angle:170).frame)
            XCTAssertEqual(evaluator.process(RecognitionFixtures.Sample(time:0.7,angle:170).frame).value, 0)
        }
    }

    func testEachRequiredJointNeedsFiniteSufficientConfidence() {
        let joints: [BodyJoint] = [.leftShoulder,.leftElbow,.leftWrist]
        for joint in joints {
            for confidence in [0.2, Double.nan, .infinity, -1, 2] {
                var evaluator = PushUpEvaluator()
                var points = RecognitionFixtures.Sample(time:0,angle:170).frame!.joints
                let original = points[joint]!
                points[joint] = Landmark(x:original.x,y:original.y,confidence:confidence)
                _ = evaluator.process(PoseFrame(timestamp:0,joints:points))
                XCTAssertEqual(evaluator.diagnostic, .lowConfidence)
                XCTAssertEqual(evaluator.process(nil).value, 0)
            }
        }
    }

    func testNonfiniteAndDegenerateGeometryIsRejected() {
        let origin = Landmark(x:0,y:0,confidence:1)
        for value in [Double.nan, .infinity, -.infinity] {
            XCTAssertNil(PushUpEvaluator.angle(Landmark(x:value,y:1,confidence:1),origin,Landmark(x:1,y:0,confidence:1)))
        }
        XCTAssertNil(PushUpEvaluator.angle(origin,origin,origin))
    }

    func testElbowAngleIsInvariantToRigidRotationAndMirroring() {
        // Geometry only; this does NOT verify a camera's Vision orientation.
        let a = Landmark(x:0.5,y:0.8,confidence:1)
        let b = Landmark(x:0.5,y:0.5,confidence:1)
        let c = Landmark(x:0.8,y:0.5,confidence:1)
        for transform in [
            { (p: Landmark) in Landmark(x:1-p.x,y:p.y,confidence:1) },
            { (p: Landmark) in Landmark(x:1-p.y,y:p.x,confidence:1) }
        ] {
            XCTAssertEqual(PushUpEvaluator.angle(transform(a),transform(b),transform(c)) ?? -1, 90, accuracy:1e-6)
        }
    }

    func testInvalidConfigurationFailsClosed() {
        var evaluator = PushUpEvaluator()
        evaluator.minimumStableDuration = .nan
        XCTAssertEqual(evaluator.process(RecognitionFixtures.Sample(time:0,angle:170).frame).value,0)
        XCTAssertEqual(evaluator.diagnostic,.invalidConfiguration)
    }

    func testMinimumRepDurationStillRejectsFastReturn() {
        var evaluator = PushUpEvaluator()
        for sample in RecognitionFixtures.samples([170,170,95,95,170,170]) { _ = evaluator.process(sample.frame) }
        XCTAssertEqual(evaluator.process(RecognitionFixtures.Sample(time:0.6,angle:170).frame).value,0)
        XCTAssertEqual(evaluator.diagnostic,.ready)
    }

    func testFreshRepAfterLongGapDoesNotRequireExtraStartingFrame() {
        var evaluator = PushUpEvaluator()
        _ = evaluator.process(RecognitionFixtures.Sample(time:0,angle:95).frame)
        var result = evaluator.process(nil)
        for sample in RecognitionFixtures.samples([170,170,135,95,95,125,170,170]) {
            result = evaluator.process(RecognitionFixtures.Sample(time:sample.time+2,angle:sample.angle).frame)
        }
        XCTAssertEqual(result.value,1)
    }

    func testDurationBoundaryAtLargeMonotonicUptime() {
        var evaluator = PushUpEvaluator()
        var result = evaluator.process(nil)
        for sample in RecognitionFixtures.samples([170,170,135,100,95,125,165,170,170], step:1.0/12.0) {
            result = evaluator.process(RecognitionFixtures.Sample(time:sample.time+100_000_000,angle:sample.angle).frame)
        }
        XCTAssertEqual(result.value,1)
    }

    func testImageAspectRatioRestoresKnownAngleAndPreservesOverlayPoints() throws {
        for ratio in [16.0/9.0,4.0/3.0,3.0/4.0,1] {
            let frame = try XCTUnwrap(RecognitionFixtures.Sample(time:0,angle:100,aspectRatio:ratio).frame)
            let a = try XCTUnwrap(frame[.leftShoulder]), b = try XCTUnwrap(frame[.leftElbow])
            let c = try XCTUnwrap(frame[.leftWrist])
            XCTAssertEqual(PushUpEvaluator.angle(a,b,c,imageAspectRatio:ratio) ?? -1,100,accuracy:1e-6)
            XCTAssertEqual(frame.joints[.leftWrist],c)
        }
    }

    func testInvalidAspectRatioFailsClosed() {
        let points = RecognitionFixtures.Sample(time:0,angle:170).frame!.joints
        for ratio in [Double.nan,.infinity,0,-1] {
            var evaluator = PushUpEvaluator()
            _ = evaluator.process(PoseFrame(timestamp:0,joints:points,imageAspectRatio:ratio))
            XCTAssertEqual(evaluator.diagnostic,.invalidGeometry)
        }
    }
}

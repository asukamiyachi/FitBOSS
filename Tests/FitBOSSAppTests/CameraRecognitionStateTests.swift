import XCTest
import FitBOSSCore
@testable import FitBOSSApp

final class CameraRecognitionStateTests: XCTestCase {
    func testExerciseSwitchResetsValueAndRejectsOldFrames() {
        var state = CameraRecognitionState()
        let old = state.revision
        state.select(.squat, at: 1)
        XCTAssertEqual(state.result.exerciseID, "squat")
        XCTAssertFalse(state.consume(frame(170,at:1.1),capturedAt:1.1,revision:old))
        state.select(.plank, at: 2)
        XCTAssertEqual(state.result.exerciseID, "plank")
        XCTAssertEqual(state.result.unit, .seconds)
        XCTAssertEqual(state.result.value, 0)
    }
    private func frame(_ angle: Double, at time: Double) -> PoseFrame {
        let radians = angle * .pi / 180
        return PoseFrame(timestamp:time,joints:[
            .leftShoulder:Landmark(x:0.5,y:0.8,confidence:0.99),
            .leftElbow:Landmark(x:0.5,y:0.5,confidence:0.99),
            .leftWrist:Landmark(x:0.5+sin(radians)*0.3,y:0.5+cos(radians)*0.3,confidence:0.99)])
    }

    func testCameraChangeRejectsOldInferenceAndOldQueuedBuffer() {
        var state = CameraRecognitionState()
        let old = state.revision
        for (i, angle) in [170.0,170,95,95].enumerated() {
            let time = Double(i)*0.1
            XCTAssertTrue(state.consume(frame(angle,at:time),capturedAt:time,revision:old))
        }
        state.invalidate(at:0.35)
        let configuring = state.revision
        state.invalidate(at:0.5) // configuration completed; old camera may have run until here
        XCTAssertFalse(state.consume(frame(170,at:0.6),capturedAt:0.6,revision:old))
        XCTAssertFalse(state.consume(frame(170,at:0.6),capturedAt:0.6,revision:configuring))
        XCTAssertFalse(state.consume(frame(170,at:0.3),capturedAt:0.3,revision:state.revision))
        XCTAssertFalse(state.consume(frame(170,at:0.4),capturedAt:0.4,revision:state.revision))
        for time in [0.6,0.7] {
            XCTAssertTrue(state.consume(frame(170,at:time),capturedAt:time,revision:state.revision))
        }
        XCTAssertEqual(state.result.value,0)
    }

    func testResetAndStopRestartRejectDelayedFramesWithoutErasingSavedCounts() {
        var state = CameraRecognitionState()
        for (i, angle) in [170.0,170,95,95,125,165,170].enumerated() {
            let time = Double(i)*0.1
            state.consume(frame(angle,at:time),capturedAt:time,revision:state.revision)
        }
        XCTAssertEqual(state.result.value,1)
        let beforeStop = state.revision
        state.invalidate(at:0.8)
        XCTAssertEqual(state.result.value,1)
        state.invalidate(at:0.9)
        XCTAssertFalse(state.consume(frame(170,at:1),capturedAt:1,revision:beforeStop))
        let beforeReset = state.revision
        state.invalidate(at:1.1,resetCount:true)
        XCTAssertFalse(state.consume(frame(170,at:1.2),capturedAt:1.2,revision:beforeReset))
        XCTAssertEqual(state.result.value,0)
    }

    func testNonfiniteCaptureTimeIsRejected() {
        var state = CameraRecognitionState()
        for time in [Double.nan,.infinity,-.infinity] {
            XCTAssertFalse(state.consume(frame(170,at:time),capturedAt:time,revision:state.revision))
        }
        XCTAssertEqual(state.result.value,0)
    }

    func testInvalidCaptureTimestampNotificationHardCancelsPartialRep() {
        var state = CameraRecognitionState()
        for (i, angle) in [170.0,170,95,95].enumerated() {
            let time=Double(i)*0.1
            state.consume(frame(angle,at:time),capturedAt:time,revision:state.revision)
        }
        XCTAssertTrue(state.consume(nil,capturedAt:0.4,revision:state.revision,invalidTimestamp:true))
        for time in [0.6,0.7] { state.consume(frame(170,at:time),capturedAt:time,revision:state.revision) }
        XCTAssertEqual(state.result.value,0)
    }
}

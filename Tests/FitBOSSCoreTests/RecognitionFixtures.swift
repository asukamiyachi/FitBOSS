import Foundation
#if !RECOGNITION_REPLAY
import FitBOSSCore
#endif

/// Hand-authored signals, never captured people or exported Vision landmarks.
enum RecognitionFixtures {
    struct Sample {
        let time: Double
        let angle: Double?
        var confidence: Double = 0.99
        var rightArm = false
        var missingWrist = false
        var aspectRatio: Double = 1

        var frame: PoseFrame? {
            guard let angle else { return nil }
            let radians = angle * .pi / 180
            var joints: [BodyJoint: Landmark] = [
                rightArm ? .rightShoulder : .leftShoulder: Landmark(x: 0.5, y: 0.8, confidence: confidence),
                rightArm ? .rightElbow : .leftElbow: Landmark(x: 0.5, y: 0.5, confidence: confidence)
            ]
            if !missingWrist {
                joints[rightArm ? .rightWrist : .leftWrist] = Landmark(
                    x: 0.5 + sin(radians) * 0.3 / aspectRatio,
                    y: 0.5 + cos(radians) * 0.3, confidence: confidence)
            }
            #if RECOGNITION_LEGACY_MODEL
            // The baseline capture/evaluator had no aspect metadata. Give it
            // the identical normalized points; only its old API is adapted.
            return PoseFrame(timestamp: time, joints: joints)
            #else
            return PoseFrame(timestamp: time, joints: joints, imageAspectRatio: aspectRatio)
            #endif
        }
    }

    struct Trial {
        let name: String
        let samples: [Sample]
        /// First observed full extension after each hand-authored complete movement.
        let truth: [Double]
    }

    static func samples(_ angles: [Double?], step: Double = 0.1, right: Bool = false) -> [Sample] {
        angles.enumerated().map { Sample(time: Double($0.offset) * step, angle: $0.element, rightArm: right) }
    }

    static let trials: [Trial] = {
        let normal: [Double?] = [170, 170, 135, 100, 95, 125, 165, 170, 170]
        let interrupted: [Double?] = [170, 170, 135, 100, 95, nil, 95, 95, 125, 165, 170, 170]
        var low = samples(interrupted)
        low[5] = Sample(time: 0.5, angle: 95, confidence: 0.2)
        var missing = samples(interrupted)
        missing[5] = Sample(time: 0.5, angle: 95, missingWrist: true)
        let variedTimes = [0.0, 0.09, 0.19, 0.30, 0.42, 0.56, 0.70, 0.81, 0.93]
        return [
            Trial(name: "normal-left", samples: samples(normal), truth: [0.6]),
            Trial(name: "normal-right", samples: samples(normal, right: true), truth: [0.6]),
            Trial(name: "twelve-fps-duration-boundary", samples: samples(normal, step: 1.0/12.0), truth: [0.5]),
            Trial(name: "landscape-16x9", samples: samples(normal).map { Sample(time:$0.time,angle:$0.angle,aspectRatio:16.0/9.0) }, truth:[0.6]),
            Trial(name: "portrait-3x4", samples: samples(normal).map { Sample(time:$0.time,angle:$0.angle,aspectRatio:3.0/4.0) }, truth:[0.6]),
            Trial(name: "slow", samples: samples(normal, step: 0.3), truth: [1.8]),
            Trial(name: "variable-cadence", samples: zip(variedTimes, normal).map { Sample(time: $0.0, angle: $0.1) }, truth: [0.70]),
            Trial(name: "two-reps", samples: samples([170,170,135,100,95,125,165,170,170,135,100,95,125,165,170,170]), truth: [0.6,1.3]),
            Trial(name: "static-up", samples: samples(Array(repeating: 170, count: 20)), truth: []),
            Trial(name: "static-down", samples: samples(Array(repeating: 95, count: 20)), truth: []),
            Trial(name: "partial", samples: samples([170,170,130,120,130,170,170]), truth: []),
            Trial(name: "near-threshold", samples: samples([170,170,150,152,148,154,150,170,170]), truth: []),
            Trial(name: "single-down-spike", samples: samples([170,170,90,170,170,170]), truth: []),
            Trial(name: "single-up-spike", samples: samples([170,170,95,95,95,170,95,95]), truth: []),
            Trial(name: "dense-two-frame-noise", samples: zip([0.0,0.1,0.2,0.21,0.5,0.6], [170.0,170,90,90,170,170]).map { Sample(time: $0.0, angle: $0.1) }, truth: []),
            Trial(name: "short-nil-same-arm", samples: samples(interrupted), truth: [0.9]),
            Trial(name: "short-low-confidence", samples: low, truth: [0.9]),
            Trial(name: "short-missing-wrist", samples: missing, truth: [0.9]),
            Trial(name: "loss-across-transition", samples: samples([170,170,95,95,nil,170,170,170]), truth: []),
            Trial(name: "different-arm-on-recovery", samples: [Sample(time:0,angle:170),Sample(time:0.1,angle:170),Sample(time:0.2,angle:95),Sample(time:0.3,angle:95),Sample(time:0.4,angle:170,rightArm:true),Sample(time:0.5,angle:170),Sample(time:0.6,angle:170)], truth: []),
            Trial(name: "long-gap", samples: [Sample(time:0,angle:170),Sample(time:0.1,angle:170),Sample(time:0.2,angle:95),Sample(time:0.3,angle:95),Sample(time:2,angle:170),Sample(time:2.1,angle:170)], truth: []),
            Trial(name: "nan-timestamp", samples: [Sample(time:0,angle:170),Sample(time:0.1,angle:170),Sample(time:0.2,angle:95),Sample(time:0.3,angle:95),Sample(time:.nan,angle:170),Sample(time:0.7,angle:170)], truth: []),
            Trial(name: "duplicate-timestamp", samples: [Sample(time:0,angle:170),Sample(time:0.1,angle:170),Sample(time:0.2,angle:95),Sample(time:0.3,angle:95),Sample(time:0.3,angle:95),Sample(time:0.6,angle:170),Sample(time:0.7,angle:170)], truth: []),
            Trial(name: "reversed-timestamp", samples: [Sample(time:0,angle:170),Sample(time:0.1,angle:170),Sample(time:0.2,angle:95),Sample(time:0.3,angle:95),Sample(time:0.15,angle:95),Sample(time:0.6,angle:170),Sample(time:0.7,angle:170)], truth: []),
            Trial(name: "low-confidence-only", samples: samples(normal).map { Sample(time:$0.time,angle:$0.angle,confidence:0.2) }, truth: []),
            Trial(name: "no-person", samples: samples(Array(repeating:nil,count:20)), truth: [])
        ]
    }()
}

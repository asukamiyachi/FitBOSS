# Camera/pose foundation architecture

## Current scope (phase 0)

- **FitBOSSApp / SwiftUI:** resizeable, native full-screen-capable macOS window, experiment HUD and camera selector.
- **CameraManager / AVFoundation:** camera permission, start/stop, external/built-in camera selection, frame delivery on a serial inference queue.
- **VisionPoseDetector:** 2D body landmarks from Apple's on-device `VNDetectHumanBodyPoseRequest`. No video storage, streaming or upload.
- **CameraPreview:** native preview layer plus joint skeleton. Vision bottom-left coordinates are converted to camera top-left coordinates.
- **FitBOSSCore:** UI- and framework-independent models, `ExerciseEvaluator` protocol, experimental `PushUpEvaluator` with hysteresis.
- **Tests:** synthetic joint-angle traces, no physical camera needed.

## Data flow

`AVCaptureSession → AVCaptureVideoDataOutput → VisionPoseDetector → PoseFrame → ExerciseEvaluator → ExerciseResult → SwiftUI`

The preview stays in AVFoundation and is not rebuilt from inferred frames. Inference is capped at about 12fps to reduce load and is best-effort.

## Planned separate tracks (NOT implemented)

1. **Recognition lab:** calibrated thresholds, 3D/2D comparison, occlusion handling, hold timers, sit-up/squat evaluators, captured test fixtures only with explicit consent.
2. **Game/UI:** independent module consuming immutable exercise results; no dependency in FitBOSSCore.
3. **Online:** explicit account/team/match model, privacy controls, abuse controls, server validation, daily boundaries and synchronization, added only after agreed design.

The ExerciseEvaluator protocol supports both `repetitions` and `seconds`; hold activities can be implemented later without coupling the camera to the game or Firebase. No Firebase dependency is added yet.

## Known limitations

- This prototype uses *2D single-arm* elbow angle without body alignment validation; it can miscount under oblique/front views, occlusion, or arm-side switching.
- 155°/105° thresholds, 0.25s minimum duration and two-frame debounce are provisional, not calibrated. It is **not** a form or medical assessment tool.
- Tracking loss discards the partial repetition, not previously completed counts.
- View/capture orientation and overlay alignment need real-camera testing, especially Continuity Camera and mirrored sources.
- No local history, authentication, network or game functionality.

## Review corrections (2026-11-02)

- Ignore delayed frame callbacks as soon as camera capture stops or the input changes. Pending permissions and configuration completions use a main-thread revision guard.
- On camera input changes, create the replacement input before removing the old input and restore the previous input if the replacement cannot be attached.
- Keep one elbow/arm selected through a partial repetition; drop incomplete repetitions when the tracked arm disappears or frame timestamps jump.
- Additional synthetic tests cover confidence-driven arm switching, tracked-arm dropout, and long frame gaps. These are core tests; **macOS compilation and live camera behavior remain unverified**.
- The preview-layer point conversion uses an Apple API that accounts for video gravity. Image rotation, front-camera mirroring, and Continuity Camera still need real-hardware validation.

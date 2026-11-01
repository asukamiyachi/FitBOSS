# Camera and push-up evaluator experiment plan

## Setup

1. On macOS 14+, run `./Scripts/build-app.sh`, then `open .build/FitBOSS.app`.
2. Grant camera access. If declined, enable it in System Settings > Privacy & Security > Camera.
3. Select built-in, USB or Continuity Camera if present.
4. Use a stable camera position. Check that the shoulders, elbows and wrists are continuously visible; a side view is recommended for this **2D** prototype.
5. Open the standard macOS green window control to enter full-screen mode.
6. Use comfortable movements and stop if you have discomfort; do not overexert for the sake of a score.

## Record for each short trial

| Field | Example / definition |
|---|---|
| camera | device name and built-in/external |
| view | side / oblique / front |
| lighting | bright / moderate / low |
| expected | manually observed completed reps |
| detected | app's rep count |
| false positives | rep counted without a full corresponding movement |
| false negatives | valid rep not counted |
| tracking dropout | approximate number of interruptions |
| overlay match | aligned / offset / mirrored / rotated |
| notes | reason for failure; avoid recording identifying images |

Test normal speed, slow movement, partial elbow bends, temporary occlusion and loss of camera permission. Repeat under multiple camera angles. Never infer accuracy from synthetic unit tests alone.

## Initial acceptance targets (NOT measured)

- Repeatable access to camera with recoverable denied-permission UI.
- Landmarks overlay aligns with shoulders/elbows/wrists in live frames.
- No count for deliberate partial bends or low-confidence frames.
- Target manual-vs-app count difference ≤1 over a 10-repetition *comfortable* controlled trial, then collect multiple trials before changing thresholds.
- No video stored or uploaded.

## Build and test status

- Linux can compile/test only platform-independent `FitBOSSCore` with `swift test`.
- macOS frameworks, actual capture, permissions, preview, full-screen and code signing require Xcode/macOS testing.

#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
# Optional source root permits the SAME harness/fixtures to run against the base.
# The temporary executable and all synthetic coordinates are local and disposable.
SOURCE_ROOT="${1:-.}"
TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp/}fitboss-recognition.XXXXXXXX")"
trap 'rm -rf "$TEMP_DIR"' EXIT
swiftc -O -D RECOGNITION_REPLAY \
  "$SOURCE_ROOT/Sources/FitBOSSCore/PoseModels.swift" \
  "$SOURCE_ROOT/Sources/FitBOSSCore/ExerciseEvaluator.swift" \
  "$SOURCE_ROOT/Sources/FitBOSSCore/PushUpEvaluator.swift" \
  Tests/FitBOSSCoreTests/RecognitionFixtures.swift Evaluation/RecognitionReplay.swift \
  -o "$TEMP_DIR/replay"
"$TEMP_DIR/replay"

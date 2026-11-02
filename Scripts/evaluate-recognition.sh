#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
# Optional source root permits the SAME harness/fixtures to run against the base.
# The temporary executable and all synthetic coordinates are local and disposable.
SOURCE_ROOT="${1:-.}"
MODEL_FLAGS=(-D RECOGNITION_REPLAY)
if [[ "${2:-}" == "--legacy-model" ]]; then MODEL_FLAGS+=(-D RECOGNITION_LEGACY_MODEL); fi
TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp/}fitboss-recognition.XXXXXXXX")"
trap 'rm -rf "$TEMP_DIR"' EXIT
swiftc -O "${MODEL_FLAGS[@]}" \
  "$SOURCE_ROOT/Sources/FitBOSSCore/PoseModels.swift" \
  "$SOURCE_ROOT/Sources/FitBOSSCore/ExerciseEvaluator.swift" \
  "$SOURCE_ROOT/Sources/FitBOSSCore/PushUpEvaluator.swift" \
  Tests/FitBOSSCoreTests/RecognitionFixtures.swift Evaluation/RecognitionReplay.swift \
  -o "$TEMP_DIR/replay"
"$TEMP_DIR/replay"

#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

REAL_ENABLED="${ROSS_ENABLE_REAL_LOCAL_INFERENCE:-0}"
RUNTIME_MODE="${ROSS_LOCAL_RUNTIME:-}"
MODEL_PATH="${ROSS_LOCAL_MODEL_PATH:-}"

echo "Ross local inference smoke"
echo "Repository: ${ROOT_DIR}"
echo "Real local inference flag: ${REAL_ENABLED}"
echo "Requested runtime mode: ${RUNTIME_MODE:-not_set}"

if [[ -n "${MODEL_PATH}" && -e "${MODEL_PATH}" ]]; then
  echo "Developer model artifact present: yes"
else
  echo "Developer model artifact present: no"
fi

echo
echo "Running deterministic local extraction baseline..."
(
  cd "${ROOT_DIR}/core/rust"
  cargo test
)

echo
echo "Running Android JVM regression smoke..."
(
  cd "${ROOT_DIR}/android"
  ./gradlew :app:testDebugUnitTest
)

echo
if [[ "${REAL_ENABLED}" == "1" && -n "${MODEL_PATH}" && -e "${MODEL_PATH}" ]]; then
  echo "Real local inference is configured for manual QA."
  if [[ "${RUNTIME_MODE}" == "mediapipe_llm" ]]; then
    cat <<'EOF'
Android manual hints:
- Build the debug APK: cd /Users/amanpandey/projects/ross/android && ./gradlew :app:assembleDebug
- Follow docs/ANDROID_REAL_INFERENCE_QA.md for the app-private import flow and technical-details checks.
- Confirm that the last invocation runtime shows mediapipe_llm before claiming a real run.
EOF
  elif [[ "${RUNTIME_MODE}" == "apple_foundation_models" || "${RUNTIME_MODE}" == "gemma_local_runtime" ]]; then
    cat <<'EOF'
iOS manual hints:
- Open /Users/amanpandey/projects/ross-gemma4/ios/Ross.xcodeproj in Xcode on a compatible device.
- Follow docs/MANUAL_LOCAL_INFERENCE_QA.md for the explicit opt-in flow and technical-details checks.
- For Gemma GGUF smoke, add --local-model-smoke to the scheme arguments and set:
  ROSS_ENABLE_REAL_LOCAL_INFERENCE=1
  ROSS_LOCAL_RUNTIME=gemma_local_runtime
  ROSS_LOCAL_MODEL_PATH=<app-readable absolute GGUF path>
- Confirm the app logs ROSS_LOCAL_MODEL_SMOKE_PASS before claiming a real run.
- The pass now requires English, Bengali, and Hindi source-grounded answers plus the general cautious answer.
- Treat source_grounded=false, bengali_grounded=false, or hindi_grounded=false as a failed proof.
- Check bengali_native_model and hindi_native_model. false means the product answer used Ross's source-preserving fallback; true is required to claim native multilingual model behavior.
EOF
  else
    echo "Manual real-runtime smoke is configured, but the runtime mode is not one of the documented manual QA paths."
  fi
else
  echo "Manual real model smoke skipped."
  echo "Set ROSS_ENABLE_REAL_LOCAL_INFERENCE=1, provide ROSS_LOCAL_RUNTIME, and point ROSS_LOCAL_MODEL_PATH at a developer-supplied local artifact to run the optional device QA flow."
fi

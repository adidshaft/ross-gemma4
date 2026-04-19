#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ANDROID_DIR="${ROOT_DIR}/android"
APK_PATH="${ANDROID_DIR}/app/build/outputs/apk/debug/app-debug.apk"
PACKAGE_NAME="com.ross.android"
ACTIVITY_NAME="com.ross.android.MainActivity"

echo "Ross Android real inference smoke"
echo "Repo: ${ROOT_DIR}"

if ! command -v adb >/dev/null 2>&1; then
  echo "Skipping: adb is not installed or not on PATH."
  exit 0
fi

echo
echo "Connected devices:"
adb devices -l

PHYSICAL_DEVICES=()
while IFS= read -r device_serial; do
  if [[ -n "${device_serial}" ]]; then
    PHYSICAL_DEVICES+=("${device_serial}")
  fi
done < <(
  adb devices -l | awk '
    NR > 1 && $2 == "device" {
      line = tolower($0)
      if (line !~ /emulator|sdk_gphone|generic|ranchu|goldfish/) {
        print $1
      }
    }
  '
)

if [[ "${#PHYSICAL_DEVICES[@]}" -eq 0 ]]; then
  echo
  echo "Skipping: no physical Android device is connected."
  exit 0
fi

DEVICE_SERIAL="${PHYSICAL_DEVICES[0]}"
REAL_FLAG="${ROSS_ENABLE_REAL_LOCAL_INFERENCE:-0}"
RUNTIME_MODE="${ROSS_LOCAL_RUNTIME:-}"
MODEL_PATH="${ROSS_LOCAL_MODEL_PATH:-}"
MODEL_PATH_BASENAME="$(basename "${MODEL_PATH:-missing}")"
MODEL_PUSH_SOURCE="${ROSS_LOCAL_MODEL_PUSH_SOURCE:-}"

if [[ "${REAL_FLAG}" != "1" ]]; then
  echo
  echo "Skipping: set ROSS_ENABLE_REAL_LOCAL_INFERENCE=1 to run the real-runtime smoke path."
  exit 0
fi

if [[ "${RUNTIME_MODE}" != "mediapipe_llm" ]]; then
  echo
  echo "Skipping: set ROSS_LOCAL_RUNTIME=mediapipe_llm for the Android MediaPipe smoke path."
  exit 0
fi

if [[ -z "${MODEL_PATH}" ]]; then
  echo
  echo "Skipping: set ROSS_LOCAL_MODEL_PATH to the developer-provided model location used by the app."
  exit 0
fi

echo
echo "Using physical device: ${DEVICE_SERIAL}"
echo "Real runtime flag: enabled"
echo "Requested runtime mode: mediapipe_llm"
echo "Configured model path: ${MODEL_PATH_BASENAME}"

if [[ -n "${MODEL_PUSH_SOURCE}" ]]; then
  if [[ ! -f "${MODEL_PUSH_SOURCE}" ]]; then
    echo "Skipping: ROSS_LOCAL_MODEL_PUSH_SOURCE was set but the file does not exist."
    exit 0
  fi

  echo "Developer model push source: configured"
else
  echo "Developer model push source: not configured"
fi

echo
echo "Building debug APK..."
(
  cd "${ANDROID_DIR}"
  ./gradlew :app:assembleDebug
)

echo
if [[ -n "${MODEL_PUSH_SOURCE}" ]]; then
  TMP_TARGET="/data/local/tmp/${MODEL_PATH_BASENAME}"
  echo "Pushing model artifact to temporary device staging..."
  adb -s "${DEVICE_SERIAL}" push "${MODEL_PUSH_SOURCE}" "${TMP_TARGET}" >/dev/null

  if [[ "${MODEL_PATH}" = /* ]]; then
    echo "Copying staged model artifact to the configured absolute device path..."
    adb -s "${DEVICE_SERIAL}" shell "mkdir -p \"$(dirname "${MODEL_PATH}")\" && cp \"${TMP_TARGET}\" \"${MODEL_PATH}\"" >/dev/null
  else
    echo "Copying staged model artifact into Ross app-private storage..."
    adb -s "${DEVICE_SERIAL}" shell "run-as ${PACKAGE_NAME} mkdir -p \"files/ross-alpha/$(dirname "${MODEL_PATH}")\"" >/dev/null
    adb -s "${DEVICE_SERIAL}" shell "run-as ${PACKAGE_NAME} sh -c 'cat \"${TMP_TARGET}\" > \"files/ross-alpha/${MODEL_PATH}\"'" >/dev/null
  fi
fi

echo "APK ready: ${APK_PATH}"
echo
echo "Next commands:"
echo "  adb -s ${DEVICE_SERIAL} install -r \"${APK_PATH}\""
echo "  adb -s ${DEVICE_SERIAL} shell am start -n ${PACKAGE_NAME}/${ACTIVITY_NAME}"
echo
echo "Manual QA checklist:"
echo "  1. Open Settings > Private AI > Technical details."
echo "  2. Confirm Runtime mode is mediapipe_llm."
echo "  3. Confirm Local runtime is available."
echo "  4. Confirm Fallback active is no."
echo "  5. Run 'Run local inference smoke' from Technical details."
echo "  6. Confirm runtime used is mediapipe_llm and unsupported accepted is 0."
echo "  7. Confirm no raw prompt text or source text appears in logs."
echo
echo "This script never commits a model file and does not print case text or prompt text."

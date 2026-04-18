#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

ANDROID_LOCAL_ONLY=(
  "$ROOT_DIR/android/app/src/main/kotlin/com/ross/android/casework"
  "$ROOT_DIR/android/app/src/main/kotlin/com/ross/android/core/model"
)

IOS_LOCAL_ONLY=(
  "$ROOT_DIR/ios/Ross/Services/CaseRepository.swift"
  "$ROOT_DIR/ios/Ross/Services/LocalRuntimeService.swift"
  "$ROOT_DIR/ios/Ross/Services/SettingsStore.swift"
)

if rg -n "Fastify|Retrofit|OkHttp|HttpURLConnection|HttpClient" "${ANDROID_LOCAL_ONLY[@]}" >/dev/null 2>&1; then
  echo "Boundary violation: Android local-only modules reference network constructs."
  exit 1
fi

if rg -n "URLSession|Fastify|http://|https://|NWConnection|Alamofire" "${IOS_LOCAL_ONLY[@]}" >/dev/null 2>&1; then
  echo "Boundary violation: iOS local-only services reference network constructs."
  exit 1
fi

echo "Boundary scan passed."

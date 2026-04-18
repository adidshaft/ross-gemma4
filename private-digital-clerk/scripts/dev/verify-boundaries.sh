#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

if rg -n "Network|Http|Fastify|URLSession|Retrofit|OkHttp" "$ROOT_DIR/android/app/src/main/kotlin/com/privatedigitalclerk/android/casevault" >/dev/null 2>&1; then
  echo "Boundary violation: Android casevault references network constructs."
  exit 1
fi

if rg -n "publicSearch|network|URLSession|Fastify|http" "$ROOT_DIR/ios/PrivateDigitalClerk/Services/CaseVault" >/dev/null 2>&1; then
  echo "Boundary violation: iOS CaseVault references network constructs."
  exit 1
fi

echo "Boundary scan passed."


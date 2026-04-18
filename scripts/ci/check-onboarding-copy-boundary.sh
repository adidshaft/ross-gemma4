#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TECH_PATTERNS='Gemma|Gemma 4 E4B Q4|Gemma 4 E4B Q4|Gemma 4 E2B Q4|Gemma 4 Q4|Core ML|quantized|4B|NPU'
TARGETS=(
  "$ROOT_DIR/android"
  "$ROOT_DIR/ios"
)

for target in "${TARGETS[@]}"; do
  if [[ ! -d "$target" ]]; then
    continue
  fi

  if rg -n "$TECH_PATTERNS" "$target" \
    -g '*Onboarding*' \
    -g '*PracticeSetup*' \
    -g '*DeviceCheck*' \
    -g '*PrivateAIIntro*' \
    -g '*PrivateAIPackSelection*' \
    -g '*DownloadConsent*' \
    >/dev/null 2>&1; then
    echo "Technical model terminology leaked into onboarding flow files under $target"
    exit 1
  fi
done

echo "Onboarding copy boundary check passed."

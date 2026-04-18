#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

for pattern in "firebase-analytics" "mixpanel" "amplitude" "sentry" "crashlytics" "posthog"; do
  if rg -n "$pattern" "$ROOT_DIR" >/dev/null 2>&1; then
    echo "Disallowed analytics reference found for pattern: $pattern"
    exit 1
  fi
done

echo "No disallowed analytics SDK references found."


#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

COMMON_EXCLUDES=(
  --glob '!docs/**'
  --glob '!README.md'
  --glob '!android/README.md'
  --glob '!ios/README.md'
  --glob '!shared/constants/technicalModelRegistry.json'
  --glob '!scripts/ci/check-no-cloud-llm.sh'
)

STRICT_GEMINI_EXCLUDES=(
  --glob '!backend/src/public_search_proxy/service.ts'
  --glob '!backend/src/security/env.ts'
  --glob '!backend/tests/public-law-gemini.test.ts'
  --glob '!backend/tests/runtime-env.test.ts'
  --glob '!backend/.env.example'
)

for pattern in "openai" "anthropic" "claude" "gemini.googleapis" "api.openai.com" "generativelanguage.googleapis.com" "x-goog-api-key" "GEMINI_API_KEY"; do
  if [[ "$pattern" == "generativelanguage.googleapis.com" || "$pattern" == "x-goog-api-key" || "$pattern" == "GEMINI_API_KEY" ]]; then
    if rg \
      "${COMMON_EXCLUDES[@]}" \
      "${STRICT_GEMINI_EXCLUDES[@]}" \
      -n "$pattern" "$ROOT_DIR" >/dev/null 2>&1; then
      echo "Disallowed cloud LLM reference found for pattern: $pattern"
      exit 1
    fi
  elif rg \
    "${COMMON_EXCLUDES[@]}" \
    -n "$pattern" "$ROOT_DIR" >/dev/null 2>&1; then
    echo "Disallowed cloud LLM reference found for pattern: $pattern"
    exit 1
  fi
done

echo "No disallowed cloud LLM dependencies found."

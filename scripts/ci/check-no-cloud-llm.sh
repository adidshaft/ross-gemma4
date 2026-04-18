#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

for pattern in "openai" "anthropic" "claude" "gemini.googleapis" "api.openai.com"; do
  if rg \
    --glob '!docs/**' \
    --glob '!README.md' \
    --glob '!shared/constants/technicalModelRegistry.json' \
    --glob '!scripts/ci/check-no-cloud-llm.sh' \
    -n "$pattern" "$ROOT_DIR" >/dev/null 2>&1; then
    echo "Disallowed cloud LLM reference found for pattern: $pattern"
    exit 1
  fi
done

echo "No disallowed cloud LLM dependencies found."

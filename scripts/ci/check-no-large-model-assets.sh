#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LIMIT_BYTES=$((50 * 1024 * 1024))

while IFS= read -r -d '' file; do
  size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file")
  if [[ "$size" -gt "$LIMIT_BYTES" ]]; then
    echo "Large bundled asset exceeds threshold: $file ($size bytes)"
    exit 1
  fi
done < <(find "$ROOT_DIR" \( -name "*.bin" -o -name "*.gguf" -o -name "*.onnx" -o -name "*.tflite" -o -name "*.mlmodelc" -o -name "*.model" \) -print0)

echo "No oversized bundled model assets found."

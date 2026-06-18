#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SIM_SMOKE="$ROOT_DIR/scripts/ios-simulator-local-model-smoke.sh"

run_expect_exit_2() {
  local description="$1"
  shift
  set +e
  "$@" >/tmp/ross-runtime-preflight.out 2>&1
  local rc=$?
  set -e
  if [[ "$rc" -ne 2 ]]; then
    echo "❌ FAIL: $description expected exit 2, got $rc" >&2
    cat /tmp/ross-runtime-preflight.out >&2 || true
    return 1
  fi
}

tmpdir="$(mktemp -d /tmp/ross-runtime-preflight.XXXXXX)"
trap 'rm -rf "$tmpdir" /tmp/ross-runtime-preflight.out' EXIT

malformed_mlx="$tmpdir/malformed-mlx"
mkdir -p "$malformed_mlx"
printf '{}' >"$malformed_mlx/config.json"
run_expect_exit_2 \
  "malformed MLX directory" \
  "$SIM_SMOKE" --runtime mlx --model "$malformed_mlx"

gguf_as_mlx="$tmpdir/wrong-runtime.gguf"
printf 'gguf' >"$gguf_as_mlx"
run_expect_exit_2 \
  "GGUF file passed as MLX" \
  "$SIM_SMOKE" --runtime mlx --model "$gguf_as_mlx"

coreml_file="$tmpdir/foundation-adapter.mlmodelc"
printf 'adapter' >"$coreml_file"
run_expect_exit_2 \
  "system_model artifact with adapter path" \
  "$SIM_SMOKE" --runtime coreml --artifact-kind system_model --model "$coreml_file"

run_expect_exit_2 \
  "adapter artifact with system-model sentinel" \
  "$SIM_SMOKE" --runtime coreml --artifact-kind foundation_adapter --model system-model

echo "iOS runtime smoke preflight tests: PASS"

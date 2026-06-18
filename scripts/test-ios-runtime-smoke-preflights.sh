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

run_expect_exit_2 \
  "tiny GGUF primary model placeholder" \
  "$SIM_SMOKE" --runtime gguf --model "$gguf_as_mlx"

usable_mlx="$tmpdir/usable-mlx"
mkdir -p "$usable_mlx"
printf '{}' >"$usable_mlx/config.json"
printf '{}' >"$usable_mlx/tokenizer.json"
printf 'weights' >"$usable_mlx/model.safetensors"

main_gguf="$tmpdir/main.gguf"
python3 - "$main_gguf" <<'PY'
import pathlib
import sys
pathlib.Path(sys.argv[1]).write_bytes(b"GGUF" + (b"\0" * 1000000))
PY

large_non_gguf="$tmpdir/large-non-gguf.gguf"
python3 - "$large_non_gguf" <<'PY'
import pathlib
import sys
pathlib.Path(sys.argv[1]).write_bytes(b"NOPE" + (b"\0" * 1000000))
PY

run_expect_exit_2 \
  "large non-GGUF primary model placeholder" \
  "$SIM_SMOKE" --runtime gguf --model "$large_non_gguf"

run_expect_exit_2 \
  "MLX directory passed as GGUF draft proof" \
  "$SIM_SMOKE" --runtime gguf --model "$main_gguf" --draft-model "$usable_mlx" --require-draft-acceleration

run_expect_exit_2 \
  "tiny GGUF draft model placeholder" \
  "$SIM_SMOKE" --runtime gguf --model "$main_gguf" --draft-model "$gguf_as_mlx" --require-draft-acceleration

run_expect_exit_2 \
  "large non-GGUF draft model placeholder" \
  "$SIM_SMOKE" --runtime gguf --model "$main_gguf" --draft-model "$large_non_gguf" --require-draft-acceleration

run_expect_exit_2 \
  "GGUF file passed as MLX draft proof" \
  "$SIM_SMOKE" --runtime mlx --model "$usable_mlx" --draft-model "$gguf_as_mlx" --require-draft-acceleration

run_expect_exit_2 \
  "CoreAI draft proof requested" \
  "$SIM_SMOKE" --runtime coreai --draft-model "$gguf_as_mlx" --require-draft-acceleration

coreml_file="$tmpdir/foundation-adapter.mlmodelc"
printf 'adapter' >"$coreml_file"
run_expect_exit_2 \
  "system_model artifact with adapter path" \
  "$SIM_SMOKE" --runtime coreml --artifact-kind system_model --model "$coreml_file"

run_expect_exit_2 \
  "adapter artifact with system-model sentinel" \
  "$SIM_SMOKE" --runtime coreml --artifact-kind foundation_adapter --model system-model

run_expect_exit_2 \
  "adapter artifact with system URL sentinel" \
  "$SIM_SMOKE" --runtime coreml --artifact-kind foundation_adapter --model system://apple-foundation-models

echo "iOS runtime smoke preflight tests: PASS"

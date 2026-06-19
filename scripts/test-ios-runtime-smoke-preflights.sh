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

run_expect_exit_2 \
  "unsupported simulator smoke profile" \
  "$SIM_SMOKE" --runtime gguf --model "$tmpdir/main.gguf" --smoke-profile typo

run_expect_exit_2 \
  "invalid simulator stage timeout" \
  "$SIM_SMOKE" --runtime gguf --model "$tmpdir/main.gguf" --stage-timeout nope

run_expect_exit_2 \
  "invalid simulator launch timeout" \
  "$SIM_SMOKE" --runtime gguf --model "$tmpdir/main.gguf" --launch-timeout nope

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

empty_weight_mlx="$tmpdir/empty-weight-mlx"
mkdir -p "$empty_weight_mlx"
printf '{}' >"$empty_weight_mlx/config.json"
printf '{}' >"$empty_weight_mlx/tokenizer.json"
: >"$empty_weight_mlx/model.safetensors"
run_expect_exit_2 \
  "empty MLX weights" \
  "$SIM_SMOKE" --runtime mlx --model "$empty_weight_mlx"

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

empty_coreml_dir="$tmpdir/empty-foundation-adapter.mlmodelc"
mkdir -p "$empty_coreml_dir"
run_expect_exit_2 \
  "empty CoreAI adapter directory" \
  "$SIM_SMOKE" --runtime coreml --artifact-kind foundation_adapter --model "$empty_coreml_dir"

empty_coreml_file="$tmpdir/empty-foundation-adapter.mlmodel"
: > "$empty_coreml_file"
run_expect_exit_2 \
  "empty CoreAI adapter file" \
  "$SIM_SMOKE" --runtime coreml --artifact-kind foundation_adapter --model "$empty_coreml_file"

run_expect_exit_2 \
  "GGUF file passed as CoreAI adapter" \
  "$SIM_SMOKE" --runtime coreml --artifact-kind coreml_model --model "$main_gguf"

run_expect_exit_2 \
  "MLX directory passed as CoreAI adapter" \
  "$SIM_SMOKE" --runtime coreml --artifact-kind foundation_adapter --model "$usable_mlx"

coreml_file="$tmpdir/foundation-adapter.mlmodelc"
mkdir -p "$coreml_file"
printf 'adapter' >"$coreml_file/model.bin"
run_expect_exit_2 \
  "system_model artifact with adapter path" \
  "$SIM_SMOKE" --runtime coreml --artifact-kind system_model --model "$coreml_file"

run_expect_exit_2 \
  "adapter artifact with system-model sentinel" \
  "$SIM_SMOKE" --runtime coreml --artifact-kind foundation_adapter --model system-model

run_expect_exit_2 \
  "adapter artifact with system URL sentinel" \
  "$SIM_SMOKE" --runtime coreml --artifact-kind foundation_adapter --model system://apple-foundation-models

preflight_expect_ok() {
  local description="$1"
  local expected="$2"
  shift 2
  "$@" >/tmp/ross-runtime-preflight.out 2>&1
  if ! grep -q "$expected" /tmp/ross-runtime-preflight.out; then
    echo "❌ FAIL: $description did not emit expected preflight marker: $expected" >&2
    cat /tmp/ross-runtime-preflight.out >&2 || true
    return 1
  fi
}

preflight_expect_ok \
  "CoreAI system URL sentinel" \
  "ROSS_SIMULATOR_SMOKE_PREFLIGHT_OK runtime=apple_foundation_models artifact_kind=system_model model_path_type=system model_path=system://apple-foundation-models" \
  "$SIM_SMOKE" --runtime coreml --artifact-kind system_model --model system://apple-foundation-models --preflight-only

preflight_expect_ok \
  "CoreAI non-empty adapter directory" \
  "ROSS_SIMULATOR_SMOKE_PREFLIGHT_OK runtime=apple_foundation_models artifact_kind=foundation_adapter model_path_type=directory" \
  "$SIM_SMOKE" --runtime coreml --artifact-kind foundation_adapter --model "$coreml_file" --preflight-only

echo "iOS runtime smoke preflight tests: PASS"

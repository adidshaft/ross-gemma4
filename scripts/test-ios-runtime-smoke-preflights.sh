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
fake_bin="$tmpdir/bin"
mkdir -p "$fake_bin"

cat >"$fake_bin/xcrun" <<'SH'
#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" != "simctl" ]]; then
  echo "fake xcrun only supports simctl" >&2
  exit 2
fi
shift

if [[ "${1:-}" != "launch" ]]; then
  echo "fake simctl only supports launch" >&2
  exit 2
fi

if [[ -z "${FAKE_SIMCTL_PROCESS_LOG:-}" ]]; then
  echo "missing FAKE_SIMCTL_PROCESS_LOG" >&2
  exit 2
fi
if [[ -n "${FAKE_SIMCTL_SLEEP:-}" ]]; then
  sleep "$FAKE_SIMCTL_SLEEP"
  exit 0
fi
cat "$FAKE_SIMCTL_PROCESS_LOG"
SH
chmod +x "$fake_bin/xcrun"

run_expect_exit_2 \
  "unsupported simulator smoke profile" \
  "$SIM_SMOKE" --runtime gguf --model "$tmpdir/main.gguf" --smoke-profile typo

run_expect_exit_2 \
  "invalid simulator stage timeout" \
  "$SIM_SMOKE" --runtime gguf --model "$tmpdir/main.gguf" --stage-timeout nope

run_expect_exit_2 \
  "invalid simulator launch timeout" \
  "$SIM_SMOKE" --runtime gguf --model "$tmpdir/main.gguf" --launch-timeout nope

run_expect_exit_2 \
  "invalid simulator physical memory" \
  "$SIM_SMOKE" --runtime gguf --model "$tmpdir/main.gguf" --physical-memory-bytes nope

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

safetensors_as_mlx="$tmpdir/wrong-runtime.safetensors"
printf 'weights' >"$safetensors_as_mlx"
run_expect_exit_2 \
  "safetensors file passed as MLX" \
  "$SIM_SMOKE" --runtime mlx --model "$safetensors_as_mlx"

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
  "simulator draft proof without MTP profile" \
  "$SIM_SMOKE" --runtime gguf --model "$main_gguf" --draft-model "$main_gguf" --require-draft-acceleration --smoke-profile quick

run_expect_exit_2 \
  "simulator draft proof with draft disabled" \
  "$SIM_SMOKE" --runtime gguf --model "$main_gguf" --draft-model "$main_gguf" --require-draft-acceleration --disable-draft --smoke-profile mtp_quick

run_expect_exit_2 \
  "MLX directory passed as GGUF draft proof" \
  "$SIM_SMOKE" --runtime gguf --model "$main_gguf" --draft-model "$usable_mlx" --require-draft-acceleration

run_expect_exit_2 \
  "tiny GGUF draft model placeholder" \
  "$SIM_SMOKE" --runtime gguf --model "$main_gguf" --draft-model "$gguf_as_mlx" --require-draft-acceleration

run_expect_exit_2 \
  "large non-GGUF draft model placeholder" \
  "$SIM_SMOKE" --runtime gguf --model "$main_gguf" --draft-model "$large_non_gguf" --require-draft-acceleration

gemma2_main_gguf="$tmpdir/gemma-2-2b-it-Q4_K_M.gguf"
gemma12b_draft_gguf="$tmpdir/mtp-gemma-4-12b-it.gguf"
printf 'GGUF' > "$gemma2_main_gguf"
truncate -s 1000004 "$gemma2_main_gguf"
printf 'GGUF' > "$gemma12b_draft_gguf"
truncate -s 1000004 "$gemma12b_draft_gguf"
run_expect_exit_2 \
  "mismatched 2B primary with 12B MTP draft" \
  "$SIM_SMOKE" --runtime gguf --model "$gemma2_main_gguf" --draft-model "$gemma12b_draft_gguf" --require-draft-acceleration --smoke-profile mtp_quick

e4b_main_gguf="$tmpdir/gemma-4-E4B-it-UD-Q4_K_XL.gguf"
e4b_draft_gguf="$tmpdir/mtp-gemma-4-E4B-it.gguf"
printf 'GGUF' > "$e4b_main_gguf"
truncate -s 5130000000 "$e4b_main_gguf"
printf 'GGUF' > "$e4b_draft_gguf"
truncate -s 79000000 "$e4b_draft_gguf"
run_expect_exit_2 \
  "memory-blocked E4B simulator MTP proof" \
  "$SIM_SMOKE" --runtime gguf --model "$e4b_main_gguf" --draft-model "$e4b_draft_gguf" --require-draft-acceleration --smoke-profile mtp_quick --physical-memory-bytes 7200000000

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

txt_coreml_file="$tmpdir/not-a-coreml-adapter.txt"
printf 'adapter' >"$txt_coreml_file"
run_expect_exit_2 \
  "non-CoreML path shape passed as CoreML adapter" \
  "$SIM_SMOKE" --runtime coreml --artifact-kind coreml_model --model "$txt_coreml_file"

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
  "GGUF model file" \
  "ROSS_SIMULATOR_SMOKE_PREFLIGHT_OK runtime=gemma_local_runtime artifact_kind=local_model_artifact model_path_type=file" \
  "$SIM_SMOKE" --runtime gguf --model "$main_gguf" --preflight-only

preflight_expect_ok \
  "GGUF quick_low_context smoke profile" \
  "ROSS_SIMULATOR_SMOKE_PREFLIGHT_OK runtime=gemma_local_runtime artifact_kind=local_model_artifact model_path_type=file" \
  "$SIM_SMOKE" --runtime gguf --model "$main_gguf" --smoke-profile quick_low_context --preflight-only

preflight_expect_ok \
  "MLX usable directory" \
  "ROSS_SIMULATOR_SMOKE_PREFLIGHT_OK runtime=mlx_swift_lm artifact_kind=mlx_directory model_path_type=directory" \
  "$SIM_SMOKE" --runtime mlx --model "$usable_mlx" --preflight-only

preflight_expect_ok \
  "GGUF MTP draft file" \
  "draft_model_path_type=file draft_model=mtp-gemma-4-E4B-it.gguf draft_tokens=2" \
  "$SIM_SMOKE" --runtime gguf --model "$e4b_main_gguf" --draft-model "$e4b_draft_gguf" --draft-tokens 2 --require-draft-acceleration --smoke-profile mtp_quick --preflight-only

usable_mlx_draft="$tmpdir/usable-mlx-draft"
mkdir -p "$usable_mlx_draft"
printf '{}' >"$usable_mlx_draft/config.json"
printf '{}' >"$usable_mlx_draft/tokenizer.json"
printf 'weights' >"$usable_mlx_draft/model.safetensors"
preflight_expect_ok \
  "MLX draft directory" \
  "draft_model_path_type=directory draft_model=usable-mlx-draft draft_tokens=2" \
  "$SIM_SMOKE" --runtime mlx --model "$usable_mlx" --draft-model "$usable_mlx_draft" --draft-tokens 2 --require-draft-acceleration --smoke-profile mtp_quick --preflight-only

preflight_expect_ok \
  "CoreAI system URL sentinel" \
  "ROSS_SIMULATOR_SMOKE_PREFLIGHT_OK runtime=apple_foundation_models artifact_kind=system_model model_path_type=system model_path=system://apple-foundation-models" \
  "$SIM_SMOKE" --runtime coreml --artifact-kind system_model --model system://apple-foundation-models --preflight-only

preflight_expect_ok \
  "CoreAI non-empty adapter directory" \
  "ROSS_SIMULATOR_SMOKE_PREFLIGHT_OK runtime=apple_foundation_models artifact_kind=foundation_adapter model_path_type=directory" \
  "$SIM_SMOKE" --runtime coreml --artifact-kind foundation_adapter --model "$coreml_file" --preflight-only

run_process_guard_expect_exit_1() {
  local description="$1"
  local expected="$2"
  local process_log="$3"
  shift 3
  set +e
  PATH="$fake_bin:$PATH" \
    FAKE_SIMCTL_PROCESS_LOG="$process_log" \
    "$@" >/tmp/ross-runtime-preflight.out 2>&1
  local rc=$?
  set -e
  if [[ "$rc" -ne 1 ]]; then
    echo "❌ FAIL: $description expected exit 1, got $rc" >&2
    cat /tmp/ross-runtime-preflight.out >&2 || true
    return 1
  fi
  if ! grep -q "$expected" /tmp/ross-runtime-preflight.out; then
    echo "❌ FAIL: $description did not emit expected message: $expected" >&2
    cat /tmp/ross-runtime-preflight.out >&2 || true
    return 1
  fi
}

run_process_guard_expect_exit_0() {
  local description="$1"
  local expected="$2"
  local process_log="$3"
  shift 3
  set +e
  PATH="$fake_bin:$PATH" \
    FAKE_SIMCTL_PROCESS_LOG="$process_log" \
    "$@" >/tmp/ross-runtime-preflight.out 2>&1
  local rc=$?
  set -e
  if [[ "$rc" -ne 0 ]]; then
    echo "❌ FAIL: $description expected exit 0, got $rc" >&2
    cat /tmp/ross-runtime-preflight.out >&2 || true
    return 1
  fi
  if ! grep -q "$expected" /tmp/ross-runtime-preflight.out; then
    echo "❌ FAIL: $description did not emit expected message: $expected" >&2
    cat /tmp/ross-runtime-preflight.out >&2 || true
    return 1
  fi
}

run_process_guard_expect_timeout() {
  local description="$1"
  local process_log="$2"
  shift 2
  set +e
  PATH="$fake_bin:$PATH" \
    FAKE_SIMCTL_PROCESS_LOG="$process_log" \
    FAKE_SIMCTL_SLEEP=2 \
    "$@" >/tmp/ross-runtime-preflight.out 2>&1
  local rc=$?
  set -e
  if [[ "$rc" -ne 1 ]]; then
    echo "❌ FAIL: $description expected exit 1, got $rc" >&2
    cat /tmp/ross-runtime-preflight.out >&2 || true
    return 1
  fi
  if ! grep -q "reason=helper_timeout" /tmp/ross-runtime-preflight.out ||
     ! grep -q "ROSS_SMOKE_FAILURE_SUMMARY" /tmp/ross-runtime-preflight.out; then
    echo "❌ FAIL: $description did not emit timeout guard and failure summary." >&2
    cat /tmp/ross-runtime-preflight.out >&2 || true
    return 1
  fi
}

cat >"$tmpdir/simulator-silent-hang.log" <<'EOF'
EOF
run_process_guard_expect_timeout \
  "simulator silent launch timeout" \
  "$tmpdir/simulator-silent-hang.log" \
  "$SIM_SMOKE" --runtime gguf --model "$main_gguf" --smoke-profile quick --launch-timeout 1

cat >"$tmpdir/simulator-sparse-pass-stage-done.log" <<EOF
ROSS_RUNTIME_IDENTITY provider=AlphaLlamaCppProvider requested_runtime=gemma_local_runtime actual_runtime=gemma_local_runtime pack_runtime=gemma_local_runtime model_format=gguf checksum_verified=true artifact_path_type=file artifact_path=$(basename "$main_gguf") acceleration=standard draft_tokens=nil draft_model=nil draft_model_path_type=nil draft_status=no_draft_configured draft_error_detail=no_draft_configured runtime_error_detail=nil context_tokens=4096 gpu_offload=n_gpu_layers:0 fallback=none available=true error=nil
ROSS_LOCAL_MODEL_SMOKE_BENCHMARK_MATRIX profile=quick cases=english_source_bound_document_qa,english_open_no_document_query stages=source:document_qa:en:source_refs_required:max_tokens=192,general:open_query:en:no_source_refs:max_tokens=192
ROSS_LOCAL_MODEL_SMOKE_STAGE_DONE stage=source duration_ms=100 schema_valid=true error=nil runtime_error_detail=nil source_input_tokens=120 source_output_tokens=32 source_token_speed=11.0 source_first_token_ms=900 source_measured_tokens=true source_acceleration=standard source_draft_tokens=nil source_draft_model=nil source_runtime_error_detail=nil
ROSS_LOCAL_MODEL_SMOKE_STAGE_DONE stage=general duration_ms=100 schema_valid=true error=nil runtime_error_detail=nil general_input_tokens=80 general_output_tokens=24 general_token_speed=10.5 general_first_token_ms=850 general_measured_tokens=true general_acceleration=standard general_draft_tokens=nil general_draft_model=nil general_runtime_error_detail=nil
ROSS_LOCAL_MODEL_SMOKE_PASS runtime=gemma_local_runtime requested_runtime=gemma_local_runtime profile=quick elapsed=10.00s source_refs=1 source_native_model=true general_native_model=true
EOF
run_process_guard_expect_exit_0 \
  "simulator sparse pass uses stage-done benchmark metrics" \
  "ROSS_SMOKE_BENCHMARK_SUMMARY" \
  "$tmpdir/simulator-sparse-pass-stage-done.log" \
  "$SIM_SMOKE" --runtime gguf --model "$main_gguf" --smoke-profile quick --launch-timeout 5
if ! grep -q "source_token_speed=11.0" /tmp/ross-runtime-preflight.out ||
   ! grep -q "general_token_speed=10.5" /tmp/ross-runtime-preflight.out; then
  echo "❌ FAIL: simulator sparse pass summary did not preserve stage-done token metrics." >&2
  cat /tmp/ross-runtime-preflight.out >&2 || true
  exit 1
fi

cat >"$tmpdir/simulator-mlx-wrong-artifact.log" <<'EOF'
ROSS_RUNTIME_IDENTITY provider=AlphaMLXLocalProvider requested_runtime=mlx_swift_lm actual_runtime=mlx_swift_lm pack_runtime=mlx_swift_lm model_format=mlx_directory checksum_verified=true artifact_path_type=directory artifact_path=other-mlx-model acceleration=standard draft_tokens=nil draft_model=nil draft_model_path_type=nil draft_status=no_draft_configured context_tokens=12288 gpu_offload=mlx_default fallback=none available=true error=nil
ROSS_LOCAL_MODEL_SMOKE_BENCHMARK_MATRIX profile=quick cases=english_source_bound_document_qa,english_open_no_document_query stages=source:document_qa:en:source_refs_required:max_tokens=192,general:open_query:en:no_source_refs:max_tokens=192
ROSS_LOCAL_MODEL_SMOKE_PASS runtime=mlx_swift_lm requested_runtime=mlx_swift_lm profile=quick elapsed=10.00s source_input_tokens=120 source_output_tokens=32 source_token_speed=11.0 source_first_token_ms=900 source_measured_tokens=true source_refs=1 source_native_model=true general_input_tokens=80 general_output_tokens=24 general_token_speed=10.5 general_first_token_ms=850 general_measured_tokens=true general_native_model=true
EOF
run_process_guard_expect_exit_1 \
  "simulator MLX request rejects wrong artifact identity" \
  "runtime_identity_artifact_path_mismatch" \
  "$tmpdir/simulator-mlx-wrong-artifact.log" \
  "$SIM_SMOKE" --runtime mlx --model "$usable_mlx" --smoke-profile quick --launch-timeout 5

cat >"$tmpdir/simulator-coreai-wrong-artifact.log" <<'EOF'
ROSS_RUNTIME_IDENTITY provider=AlphaFoundationModelsLocalProvider requested_runtime=apple_foundation_models actual_runtime=apple_foundation_models pack_runtime=apple_foundation_models model_format=foundation_adapter checksum_verified=true artifact_path_type=directory artifact_path=other-adapter.mlmodelc acceleration=standard draft_tokens=nil draft_model=nil draft_model_path_type=nil draft_status=not_supported context_tokens=4096 gpu_offload=foundation_default fallback=none available=true error=nil
ROSS_LOCAL_MODEL_SMOKE_BENCHMARK_MATRIX profile=quick cases=english_source_bound_document_qa,english_open_no_document_query stages=source:document_qa:en:source_refs_required:max_tokens=192,general:open_query:en:no_source_refs:max_tokens=192
ROSS_LOCAL_MODEL_SMOKE_PASS runtime=apple_foundation_models requested_runtime=apple_foundation_models profile=quick elapsed=10.00s source_input_tokens=120 source_output_tokens=32 source_token_speed=11.0 source_first_token_ms=900 source_measured_tokens=true source_refs=1 source_native_model=true general_input_tokens=80 general_output_tokens=24 general_token_speed=10.5 general_first_token_ms=850 general_measured_tokens=true general_native_model=true
EOF
run_process_guard_expect_exit_1 \
  "simulator CoreAI request rejects wrong artifact identity" \
  "runtime_identity_artifact_path_mismatch" \
  "$tmpdir/simulator-coreai-wrong-artifact.log" \
  "$SIM_SMOKE" --runtime coreml --artifact-kind foundation_adapter --model "$coreml_file" --smoke-profile quick --launch-timeout 5

echo "iOS runtime smoke preflight tests: PASS"

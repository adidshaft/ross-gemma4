#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEVICE_SMOKE="$ROOT_DIR/scripts/ios-device-installed-pack-smoke.sh"

tmpdir="$(mktemp -d /tmp/ross-device-installed-preflight.XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT

fake_bin="$tmpdir/bin"
fake_device_root="$tmpdir/fake-device"
mkdir -p "$fake_bin" "$fake_device_root/Library/Application Support/RossAlpha/model-packs"

cat >"$fake_bin/xcrun" <<'SH'
#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" != "devicectl" ]]; then
  echo "fake xcrun only supports devicectl" >&2
  exit 2
fi
shift

if [[ "${1:-}" != "device" ]]; then
  echo "fake devicectl only supports device" >&2
  exit 2
fi
shift

command="${1:-}"
shift || true

case "$command" in
  copy)
    direction="${1:-}"
    shift || true
    source=""
    destination=""
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --source)
          source="${2:-}"
          shift 2
          ;;
        --destination)
          destination="${2:-}"
          shift 2
          ;;
        *)
          shift
          ;;
      esac
    done
    case "$direction" in
      to)
        echo "Path: $FAKE_DEVICE_ROOT/$destination"
        ;;
      from)
        mkdir -p "$(dirname "$destination")"
        cp "$FAKE_DEVICE_ROOT/$source" "$destination"
        ;;
      *)
        echo "fake copy direction unsupported: $direction" >&2
        exit 2
        ;;
    esac
    ;;
  info)
    subcommand="${1:-}"
    shift || true
    if [[ "$subcommand" != "files" ]]; then
      echo "fake info only supports files" >&2
      exit 2
    fi
    json_output=""
    search=""
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --json-output)
          json_output="${2:-}"
          shift 2
          ;;
        --search)
          search="${2:-}"
          shift 2
          ;;
        *)
          shift
          ;;
      esac
    done
    if [[ -z "$json_output" ]]; then
      echo "missing --json-output" >&2
      exit 2
    fi
    python3 - "$FAKE_DEVICE_ROOT" "$json_output" "$search" <<'PY'
import json
import pathlib
import sys

root = pathlib.Path(sys.argv[1]) / "Library/Application Support/RossAlpha"
search = sys.argv[3]
files = []
for path in sorted(root.rglob("*")):
    if search and search not in path.name:
        continue
    if path.is_file() or path.is_dir():
        files.append({"relativePath": str(path.relative_to(root))})
pathlib.Path(sys.argv[2]).write_text(json.dumps({"result": {"files": files}}))
PY
    ;;
  process)
    if [[ -n "${FAKE_DEVICECTL_PROCESS_LOG:-}" ]]; then
      cat "$FAKE_DEVICECTL_PROCESS_LOG"
      exit 0
    fi
    echo "fake devicectl process launch should not be reached by preflight rejection" >&2
    exit 99
    ;;
  *)
    echo "fake devicectl command unsupported: $command" >&2
    exit 2
    ;;
esac
SH
chmod +x "$fake_bin/xcrun"

write_manifest() {
  local payload="$1"
  rm -rf "$fake_device_root/Library/Application Support/RossAlpha/model-packs"
  mkdir -p "$fake_device_root/Library/Application Support/RossAlpha/model-packs/quick"
  printf '%s\n' "$payload" >"$fake_device_root/Library/Application Support/RossAlpha/model-packs/quick/test.manifest.json"
}

run_expect_exit_1() {
  local description="$1"
  local expected="$2"
  shift 2
  set +e
  PATH="$fake_bin:$PATH" FAKE_DEVICE_ROOT="$fake_device_root" "$@" >"$tmpdir/out.txt" 2>&1
  local rc=$?
  set -e
  if [[ "$rc" -ne 1 ]]; then
    echo "FAIL: $description expected exit 1, got $rc" >&2
    cat "$tmpdir/out.txt" >&2 || true
    return 1
  fi
  if ! grep -q "$expected" "$tmpdir/out.txt"; then
    echo "FAIL: $description did not emit expected message: $expected" >&2
    cat "$tmpdir/out.txt" >&2 || true
    return 1
  fi
}

run_expect_exit_2() {
  local description="$1"
  local expected="$2"
  shift 2
  set +e
  PATH="$fake_bin:$PATH" FAKE_DEVICE_ROOT="$fake_device_root" "$@" >"$tmpdir/out.txt" 2>&1
  local rc=$?
  set -e
  if [[ "$rc" -ne 2 ]]; then
    echo "FAIL: $description expected exit 2, got $rc" >&2
    cat "$tmpdir/out.txt" >&2 || true
    return 1
  fi
  if ! grep -q "$expected" "$tmpdir/out.txt"; then
    echo "FAIL: $description did not emit expected message: $expected" >&2
    cat "$tmpdir/out.txt" >&2 || true
    return 1
  fi
}

run_process_guard_expect_exit_1() {
  local description="$1"
  local expected="$2"
  local process_log="$3"
  shift 3
  set +e
  PATH="$fake_bin:$PATH" \
    FAKE_DEVICE_ROOT="$fake_device_root" \
    FAKE_DEVICECTL_PROCESS_LOG="$process_log" \
    "$@" >"$tmpdir/out.txt" 2>&1
  local rc=$?
  set -e
  if [[ "$rc" -ne 1 ]]; then
    echo "FAIL: $description expected exit 1, got $rc" >&2
    cat "$tmpdir/out.txt" >&2 || true
    return 1
  fi
  if ! grep -q "$expected" "$tmpdir/out.txt"; then
    echo "FAIL: $description did not emit expected message: $expected" >&2
    cat "$tmpdir/out.txt" >&2 || true
    return 1
  fi
}

base_command=("$DEVICE_SMOKE" --device fake-device --tier quickStart)

run_expect_exit_2 \
  "unsupported installed-pack smoke profile" \
  "Unsupported smoke profile" \
  "${base_command[@]}" --runtime gguf --smoke-profile typo

run_expect_exit_2 \
  "nonnumeric installed-pack stage timeout" \
  "Stage timeout must be a positive integer" \
  "${base_command[@]}" --runtime gguf --stage-timeout nope

run_expect_exit_2 \
  "zero installed-pack stage timeout" \
  "Stage timeout must be a positive integer" \
  "${base_command[@]}" --runtime gguf --stage-timeout 0

run_expect_exit_2 \
  "nonnumeric installed-pack launch timeout" \
  "Launch timeout must be a positive integer" \
  "${base_command[@]}" --runtime gguf --launch-timeout nope

run_expect_exit_2 \
  "zero installed-pack launch timeout" \
  "Launch timeout must be a positive integer" \
  "${base_command[@]}" --runtime gguf --launch-timeout 0

run_expect_exit_2 \
  "nonnumeric installed-pack physical memory" \
  "Physical memory bytes must be a positive integer" \
  "${base_command[@]}" --runtime gguf --physical-memory-bytes nope

run_expect_exit_2 \
  "installed-pack draft proof without MTP profile" \
  "Draft acceleration proof requires --smoke-profile mtp_quick" \
  "${base_command[@]}" --runtime gguf --require-draft-acceleration --smoke-profile quick

run_expect_exit_2 \
  "installed-pack draft proof with draft disabled" \
  "Draft acceleration proof cannot be combined with --disable-draft" \
  "${base_command[@]}" --runtime gguf --require-draft-acceleration --disable-draft --smoke-profile mtp_quick

write_manifest '{
  "packId": "tiny-gguf",
  "tier": "quick_start",
  "fileName": "tiny.gguf",
  "relativePath": "model-packs/quick/tiny.gguf",
  "checksumSha256": "a",
  "bytes": 4,
  "artifactKind": "local_model_artifact",
  "runtimeMode": "gemma_local_runtime",
  "developmentOnly": false,
  "verifiedAt": "2026-06-19T00:00:00Z"
}'
run_expect_exit_1 "tiny GGUF installed manifest" "implausibly small artifact" "${base_command[@]}" --runtime gguf

write_manifest '{
  "packId": "tiny-mtp",
  "tier": "quick_start",
  "fileName": "main.gguf",
  "relativePath": "model-packs/quick/main.gguf",
  "checksumSha256": "a",
  "bytes": 2000000,
  "artifactKind": "local_model_artifact",
  "runtimeMode": "gemma_local_runtime",
  "developmentOnly": false,
  "draftArtifact": {
    "fileName": "draft.gguf",
    "relativePath": "model-packs/quick/draft.gguf",
    "checksumSha256": "b",
    "bytes": 4,
    "artifactKind": "local_model_artifact",
    "draftTokens": 2
  },
  "verifiedAt": "2026-06-19T00:00:00Z"
}'
run_expect_exit_1 "tiny MTP draft installed manifest" "implausibly small draft artifact" "${base_command[@]}" --runtime gguf --require-draft-acceleration --smoke-profile mtp_quick

write_manifest '{
  "packId": "missing-primary",
  "tier": "quick_start",
  "fileName": "main.gguf",
  "relativePath": "model-packs/quick/main.gguf",
  "checksumSha256": "a",
  "bytes": 2000000,
  "artifactKind": "local_model_artifact",
  "runtimeMode": "gemma_local_runtime",
  "developmentOnly": false,
  "verifiedAt": "2026-06-19T00:00:00Z"
}'
run_expect_exit_1 "missing installed primary artifact" "Installed artifact file is missing" "${base_command[@]}" --runtime gguf

write_manifest '{
  "packId": "missing-draft",
  "tier": "quick_start",
  "fileName": "main.gguf",
  "relativePath": "model-packs/quick/main.gguf",
  "checksumSha256": "a",
  "bytes": 2000000,
  "artifactKind": "local_model_artifact",
  "runtimeMode": "gemma_local_runtime",
  "developmentOnly": false,
  "draftArtifact": {
    "fileName": "draft.gguf",
    "relativePath": "model-packs/quick/draft.gguf",
    "checksumSha256": "b",
    "bytes": 2000000,
    "artifactKind": "local_model_artifact",
    "draftTokens": 2
  },
  "verifiedAt": "2026-06-19T00:00:00Z"
}'
python3 - "$fake_device_root/Library/Application Support/RossAlpha/model-packs/quick/main.gguf" <<'PY'
import pathlib
import sys
pathlib.Path(sys.argv[1]).write_bytes(b"GGUF" + (b"\0" * 2_000_000))
PY
run_expect_exit_1 "missing installed draft artifact" "Installed draft artifact file is missing" "${base_command[@]}" --runtime gguf --require-draft-acceleration --smoke-profile mtp_quick

write_manifest '{
  "packId": "memory-blocked-e4b-mtp",
  "tier": "quick_start",
  "fileName": "gemma-4-E4B-it-UD-Q4_K_XL.gguf",
  "relativePath": "model-packs/quick/gemma-4-E4B-it-UD-Q4_K_XL.gguf",
  "checksumSha256": "a",
  "bytes": 5130000000,
  "artifactKind": "local_model_artifact",
  "runtimeMode": "gemma_local_runtime",
  "developmentOnly": false,
  "draftArtifact": {
    "fileName": "mtp-gemma-4-E4B-it.gguf",
    "relativePath": "model-packs/quick/mtp-gemma-4-E4B-it.gguf",
    "checksumSha256": "b",
    "bytes": 79000000,
    "artifactKind": "local_model_artifact",
    "draftTokens": 2
  },
  "verifiedAt": "2026-06-19T00:00:00Z"
}'
python3 - "$fake_device_root/Library/Application Support/RossAlpha/model-packs/quick/gemma-4-E4B-it-UD-Q4_K_XL.gguf" \
  "$fake_device_root/Library/Application Support/RossAlpha/model-packs/quick/mtp-gemma-4-E4B-it.gguf" <<'PY'
import pathlib
import sys
for raw_path in sys.argv[1:]:
    pathlib.Path(raw_path).write_bytes(b"GGUF" + (b"\0" * 2_000_000))
PY
run_expect_exit_1 \
  "memory-blocked E4B MTP installed manifest" \
  "exceeds the constrained E4B draft memory budget" \
  "${base_command[@]}" --runtime gguf --require-draft-acceleration --smoke-profile mtp_quick --physical-memory-bytes 7200000000

write_manifest '{
  "packId": "tiny-mlx",
  "tier": "quick_start",
  "fileName": "mlx-model",
  "relativePath": "model-packs/quick/mlx-model",
  "checksumSha256": "a",
  "bytes": 0,
  "artifactKind": "mlx_directory",
  "runtimeMode": "mlx_swift_lm",
  "developmentOnly": false,
  "verifiedAt": "2026-06-19T00:00:00Z"
}'
run_expect_exit_1 "tiny MLX installed manifest" "implausibly small artifact" "${base_command[@]}" --runtime mlx

write_manifest '{
  "packId": "malformed-mlx",
  "tier": "quick_start",
  "fileName": "mlx-model",
  "relativePath": "model-packs/quick/mlx-model",
  "checksumSha256": "a",
  "bytes": 2000000,
  "artifactKind": "mlx_directory",
  "runtimeMode": "mlx_swift_lm",
  "developmentOnly": false,
  "verifiedAt": "2026-06-19T00:00:00Z"
}'
mkdir -p "$fake_device_root/Library/Application Support/RossAlpha/model-packs/quick/mlx-model"
printf '{}' >"$fake_device_root/Library/Application Support/RossAlpha/model-packs/quick/mlx-model/config.json"
printf '{}' >"$fake_device_root/Library/Application Support/RossAlpha/model-packs/quick/mlx-model/tokenizer.json"
run_expect_exit_1 "malformed installed MLX directory" "Installed MLX artifact directory is missing required files" "${base_command[@]}" --runtime mlx

write_manifest '{
  "packId": "malformed-mlx-draft",
  "tier": "quick_start",
  "fileName": "mlx-model",
  "relativePath": "model-packs/quick/mlx-model",
  "checksumSha256": "a",
  "bytes": 2000000,
  "artifactKind": "mlx_directory",
  "runtimeMode": "mlx_swift_lm",
  "developmentOnly": false,
  "draftArtifact": {
    "fileName": "mlx-draft",
    "relativePath": "model-packs/quick/mlx-draft",
    "checksumSha256": "b",
    "bytes": 2000000,
    "artifactKind": "mlx_directory",
    "draftTokens": 2
  },
  "verifiedAt": "2026-06-19T00:00:00Z"
}'
mkdir -p "$fake_device_root/Library/Application Support/RossAlpha/model-packs/quick/mlx-model"
printf '{}' >"$fake_device_root/Library/Application Support/RossAlpha/model-packs/quick/mlx-model/config.json"
printf '{}' >"$fake_device_root/Library/Application Support/RossAlpha/model-packs/quick/mlx-model/tokenizer.json"
printf 'weights' >"$fake_device_root/Library/Application Support/RossAlpha/model-packs/quick/mlx-model/model.safetensors"
mkdir -p "$fake_device_root/Library/Application Support/RossAlpha/model-packs/quick/mlx-draft"
printf '{}' >"$fake_device_root/Library/Application Support/RossAlpha/model-packs/quick/mlx-draft/config.json"
printf '{}' >"$fake_device_root/Library/Application Support/RossAlpha/model-packs/quick/mlx-draft/tokenizer.json"
run_expect_exit_1 "malformed installed MLX draft directory" "Installed MLX draft artifact directory is missing required files" "${base_command[@]}" --runtime mlx --require-draft-acceleration --smoke-profile mtp_quick

write_manifest '{
  "packId": "empty-coreml",
  "tier": "quick_start",
  "fileName": "adapter.mlmodelc",
  "relativePath": "model-packs/quick/adapter.mlmodelc",
  "checksumSha256": "a",
  "bytes": 0,
  "artifactKind": "coreml_model",
  "runtimeMode": "apple_foundation_models",
  "developmentOnly": false,
  "verifiedAt": "2026-06-19T00:00:00Z"
}'
run_expect_exit_1 "empty CoreAI adapter installed manifest" "empty artifact" "${base_command[@]}" --runtime coreml

write_manifest '{
  "packId": "foreign-coreml",
  "tier": "quick_start",
  "fileName": "adapter.gguf",
  "relativePath": "model-packs/quick/adapter.gguf",
  "checksumSha256": "a",
  "bytes": 2000000,
  "artifactKind": "coreml_model",
  "runtimeMode": "apple_foundation_models",
  "developmentOnly": false,
  "verifiedAt": "2026-06-19T00:00:00Z"
}'
run_expect_exit_1 "foreign CoreAI adapter installed manifest" "foreign model artifact" "${base_command[@]}" --runtime coreml

write_manifest '{
  "packId": "quick-device-proof",
  "tier": "quick_start",
  "fileName": "main.gguf",
  "relativePath": "model-packs/quick/main.gguf",
  "checksumSha256": "a",
  "bytes": 2000000,
  "artifactKind": "local_model_artifact",
  "runtimeMode": "gemma_local_runtime",
  "developmentOnly": false,
  "verifiedAt": "2026-06-19T00:00:00Z"
}'
run_expect_exit_1 \
  "seeded device-proof pack excluded by default" \
  "Only seeded device-proof manifests matched" \
  "${base_command[@]}" --runtime gguf

write_manifest '{
  "packId": "silent-installed-pack",
  "tier": "quick_start",
  "fileName": "main.gguf",
  "relativePath": "model-packs/quick/main.gguf",
  "checksumSha256": "a",
  "bytes": 2000000,
  "artifactKind": "local_model_artifact",
  "runtimeMode": "gemma_local_runtime",
  "developmentOnly": false,
  "verifiedAt": "2026-06-19T00:00:00Z"
}'
python3 - "$fake_device_root/Library/Application Support/RossAlpha/model-packs/quick/main.gguf" <<'PY'
import pathlib
import sys
pathlib.Path(sys.argv[1]).write_bytes(b"GGUF" + (b"\0" * 2_000_000))
PY
cat >"$tmpdir/silent-installed-pack.log" <<'EOF'
Ross launched without emitting smoke terminal markers.
EOF
run_process_guard_expect_exit_1 \
  "installed-pack smoke rejects silent successful launch" \
  "no_terminal_smoke_marker" \
  "$tmpdir/silent-installed-pack.log" \
  "${base_command[@]}" --runtime gguf --smoke-profile quick

write_manifest '{
  "packId": "mtp-stage-fallback",
  "tier": "quick_start",
  "fileName": "main.gguf",
  "relativePath": "model-packs/quick/main.gguf",
  "checksumSha256": "a",
  "bytes": 2000000,
  "artifactKind": "local_model_artifact",
  "runtimeMode": "gemma_local_runtime",
  "developmentOnly": false,
  "draftArtifact": {
    "fileName": "draft.gguf",
    "relativePath": "model-packs/quick/draft.gguf",
    "checksumSha256": "b",
    "bytes": 2000000,
    "artifactKind": "local_model_artifact",
    "draftTokens": 2
  },
  "verifiedAt": "2026-06-19T00:00:00Z"
}'
python3 - "$fake_device_root/Library/Application Support/RossAlpha/model-packs/quick/main.gguf" \
  "$fake_device_root/Library/Application Support/RossAlpha/model-packs/quick/draft.gguf" <<'PY'
import pathlib
import sys
for raw_path in sys.argv[1:]:
    pathlib.Path(raw_path).write_bytes(b"GGUF" + (b"\0" * 2_000_000))
PY
cat >"$tmpdir/mtp-stage-fallback.log" <<'EOF'
ROSS_RUNTIME_IDENTITY provider=AlphaLlamaCppProvider requested_runtime=gemma_local_runtime actual_runtime=gemma_local_runtime pack_runtime=gemma_local_runtime model_format=gguf checksum_verified=true artifact_path_type=file artifact_path=main.gguf acceleration=draftModelSpeculative draft_tokens=2 draft_model=draft.gguf draft_model_path_type=file draft_status=active context_tokens=1024 gpu_offload=n_gpu_layers:0 fallback=none available=true error=nil
ROSS_LOCAL_MODEL_SMOKE_BENCHMARK_MATRIX profile=mtp_quick cases=english_source_bound_document_qa_low_token,english_open_no_document_query_low_token stages=source:document_qa:en:source_refs_required:max_tokens=24,general:open_query:en:no_source_refs:max_tokens=24
ROSS_LOCAL_MODEL_SMOKE_PASS runtime=gemma_local_runtime requested_runtime=gemma_local_runtime profile=mtp_quick elapsed=10.00s source_input_tokens=120 source_output_tokens=8 source_token_speed=11.0 source_first_token_ms=900 source_measured_tokens=true source_refs=1 source_native_model=true source_acceleration=draftModelSpeculative source_draft_tokens=2 source_draft_model=draft.gguf general_input_tokens=80 general_output_tokens=6 general_token_speed=10.5 general_first_token_ms=850 general_measured_tokens=true general_native_model=true general_acceleration=standard general_draft_tokens=nil general_draft_model=nil
EOF
run_process_guard_expect_exit_1 \
  "installed MTP stage fallback guard" \
  "benchmark_draft_stage_mismatch" \
  "$tmpdir/mtp-stage-fallback.log" \
  "${base_command[@]}" --runtime gguf --require-draft-acceleration --smoke-profile mtp_quick

write_manifest '{
  "packId": "mlx-gguf-identity",
  "tier": "quick_start",
  "fileName": "mlx-model",
  "relativePath": "model-packs/quick/mlx-model",
  "checksumSha256": "a",
  "bytes": 2000000,
  "artifactKind": "mlx_directory",
  "runtimeMode": "mlx_swift_lm",
  "developmentOnly": false,
  "verifiedAt": "2026-06-19T00:00:00Z"
}'
mkdir -p "$fake_device_root/Library/Application Support/RossAlpha/model-packs/quick/mlx-model"
printf '{}' >"$fake_device_root/Library/Application Support/RossAlpha/model-packs/quick/mlx-model/config.json"
printf '{}' >"$fake_device_root/Library/Application Support/RossAlpha/model-packs/quick/mlx-model/tokenizer.json"
printf 'weights' >"$fake_device_root/Library/Application Support/RossAlpha/model-packs/quick/mlx-model/model.safetensors"
cat >"$tmpdir/mlx-gguf-identity.log" <<'EOF'
ROSS_RUNTIME_IDENTITY provider=AlphaLlamaCppProvider requested_runtime=mlx_swift_lm actual_runtime=gemma_local_runtime pack_runtime=gemma_local_runtime model_format=gguf checksum_verified=true artifact_path_type=file artifact_path=model.gguf acceleration=standard draft_tokens=nil draft_model=nil draft_model_path_type=nil draft_status=no_draft_configured context_tokens=4096 gpu_offload=n_gpu_layers:0 fallback=none available=true error=nil
ROSS_LOCAL_MODEL_SMOKE_BENCHMARK_MATRIX profile=quick cases=english_source_bound_document_qa,english_open_no_document_query stages=source:document_qa:en:source_refs_required:max_tokens=192,general:open_query:en:no_source_refs:max_tokens=192
ROSS_LOCAL_MODEL_SMOKE_PASS runtime=gemma_local_runtime requested_runtime=mlx_swift_lm profile=quick elapsed=10.00s source_input_tokens=120 source_output_tokens=32 source_token_speed=11.0 source_first_token_ms=900 source_measured_tokens=true source_refs=1 source_native_model=true general_input_tokens=80 general_output_tokens=24 general_token_speed=10.5 general_first_token_ms=850 general_measured_tokens=true general_native_model=true
EOF
run_process_guard_expect_exit_1 \
  "installed MLX request rejects GGUF identity" \
  "runtime_identity_mismatch" \
  "$tmpdir/mlx-gguf-identity.log" \
  "${base_command[@]}" --runtime mlx --smoke-profile quick

write_manifest '{
  "packId": "coreai-gguf-identity",
  "tier": "quick_start",
  "fileName": "adapter.mlmodelc",
  "relativePath": "model-packs/quick/adapter.mlmodelc",
  "checksumSha256": "a",
  "bytes": 128,
  "artifactKind": "coreml_model",
  "runtimeMode": "apple_foundation_models",
  "developmentOnly": false,
  "verifiedAt": "2026-06-19T00:00:00Z"
}'
mkdir -p "$fake_device_root/Library/Application Support/RossAlpha/model-packs/quick/adapter.mlmodelc"
printf 'adapter' >"$fake_device_root/Library/Application Support/RossAlpha/model-packs/quick/adapter.mlmodelc/coremldata.bin"
cat >"$tmpdir/coreai-gguf-identity.log" <<'EOF'
ROSS_RUNTIME_IDENTITY provider=AlphaLlamaCppProvider requested_runtime=apple_foundation_models actual_runtime=gemma_local_runtime pack_runtime=gemma_local_runtime model_format=gguf checksum_verified=true artifact_path_type=file artifact_path=model.gguf acceleration=standard draft_tokens=nil draft_model=nil draft_model_path_type=nil draft_status=no_draft_configured context_tokens=4096 gpu_offload=n_gpu_layers:0 fallback=none available=true error=nil
ROSS_LOCAL_MODEL_SMOKE_BENCHMARK_MATRIX profile=quick cases=english_source_bound_document_qa,english_open_no_document_query stages=source:document_qa:en:source_refs_required:max_tokens=192,general:open_query:en:no_source_refs:max_tokens=192
ROSS_LOCAL_MODEL_SMOKE_PASS runtime=gemma_local_runtime requested_runtime=apple_foundation_models profile=quick elapsed=10.00s source_input_tokens=120 source_output_tokens=32 source_token_speed=11.0 source_first_token_ms=900 source_measured_tokens=true source_refs=1 source_native_model=true general_input_tokens=80 general_output_tokens=24 general_token_speed=10.5 general_first_token_ms=850 general_measured_tokens=true general_native_model=true
EOF
run_process_guard_expect_exit_1 \
  "installed CoreAI request rejects GGUF identity" \
  "runtime_identity_mismatch" \
  "$tmpdir/coreai-gguf-identity.log" \
  "${base_command[@]}" --runtime coreml --smoke-profile quick

echo "iOS device installed-pack preflight tests: PASS"

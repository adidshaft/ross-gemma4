#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEVICE_SMOKE="$ROOT_DIR/scripts/ios-device-gguf-smoke.sh"

tmpdir="$(mktemp -d /tmp/ross-device-gguf-preflight.XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT

fake_bin="$tmpdir/bin"
fake_device_root="$tmpdir/fake-device"
copy_log="$tmpdir/copy.log"
env_log="$tmpdir/env.log"
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
    sources=()
    destination=""
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --source)
          sources+=("${2:-}")
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
    if [[ "$direction" != "to" ]]; then
      echo "fake copy direction unsupported: $direction" >&2
      exit 2
    fi
    mkdir -p "$FAKE_DEVICE_ROOT/$destination"
    for source in "${sources[@]}"; do
      if [[ -f "$source" ]]; then
        cp "$source" "$FAKE_DEVICE_ROOT/$destination/"
      fi
      printf 'COPY_TO %s %s\n' "$(basename "$source")" "$destination" >>"$FAKE_COPY_LOG"
    done
    if [[ "${#sources[@]}" -eq 1 ]]; then
      echo "Path: $FAKE_DEVICE_ROOT/$destination"
    else
      echo "Path: $FAKE_DEVICE_ROOT/$destination/"
    fi
    ;;
  process)
    printf 'DEVICE_MODEL_PATH=%s\n' "${DEVICECTL_CHILD_ROSS_LOCAL_MODEL_PATH:-}" >>"$FAKE_ENV_LOG"
    artifact="$(basename "${DEVICECTL_CHILD_ROSS_LOCAL_MODEL_PATH:-model.gguf}")"
    cat <<EOF
Launched application with com.ross.ios bundle identifier.
ROSS_RUNTIME_IDENTITY provider=AlphaLlamaCppProvider requested_runtime=gemma_local_runtime actual_runtime=gemma_local_runtime pack_runtime=gemma_local_runtime model_format=local_model_artifact checksum_verified=true artifact_path_type=file artifact_path=$artifact acceleration=standard draft_tokens=nil draft_model=nil draft_model_path_type=nil draft_status=no_draft_configured draft_error_detail=no_draft_configured runtime_error_detail=nil context_tokens=4096 gpu_offload=n_gpu_layers:0 fallback=none available=true
ROSS_LOCAL_MODEL_SMOKE_BENCHMARK_MATRIX profile=full cases=english_source_bound_document_qa,english_open_no_document_query,bengali_source_bound_document_qa,hindi_source_bound_document_qa,tamil_source_bound_document_qa,telugu_source_bound_document_qa stages=source:document_qa:en:source_refs_required:max_tokens=192,general:open_query:en:no_source_refs:max_tokens=192,bengali:document_qa:bn:source_refs_required:max_tokens=192,hindi:document_qa:hi:source_refs_required:max_tokens=192,tamil:document_qa:ta:source_refs_required:max_tokens=192,telugu:document_qa:te:source_refs_required:max_tokens=192
ROSS_LOCAL_MODEL_SMOKE_PASS runtime=gemma_local_runtime requested_runtime=gemma_local_runtime tier=quick_start profile=full elapsed=10.00s source_input_tokens=10 source_output_tokens=5 source_token_speed=10.0 source_first_token_ms=100 source_measured_tokens=true source_acceleration=standard source_draft_tokens=nil source_draft_model=nil source_refs=1 source_native_model=true general_input_tokens=10 general_output_tokens=5 general_token_speed=10.0 general_first_token_ms=100 general_measured_tokens=true general_acceleration=standard general_draft_tokens=nil general_draft_model=nil general_native_model=true bengali_input_tokens=10 bengali_output_tokens=5 bengali_token_speed=10.0 bengali_first_token_ms=100 bengali_measured_tokens=true bengali_acceleration=standard bengali_draft_tokens=nil bengali_draft_model=nil bengali_source_refs=1 bengali_native_model=true hindi_input_tokens=10 hindi_output_tokens=5 hindi_token_speed=10.0 hindi_first_token_ms=100 hindi_measured_tokens=true hindi_acceleration=standard hindi_draft_tokens=nil hindi_draft_model=nil hindi_source_refs=1 hindi_native_model=true tamil_input_tokens=10 tamil_output_tokens=5 tamil_token_speed=10.0 tamil_first_token_ms=100 tamil_measured_tokens=true tamil_acceleration=standard tamil_draft_tokens=nil tamil_draft_model=nil tamil_source_refs=1 tamil_native_model=true telugu_input_tokens=10 telugu_output_tokens=5 telugu_token_speed=10.0 telugu_first_token_ms=100 telugu_measured_tokens=true telugu_acceleration=standard telugu_draft_tokens=nil telugu_draft_model=nil telugu_source_refs=1 telugu_native_model=true
EOF
    ;;
  *)
    echo "fake devicectl command unsupported: $command" >&2
    exit 2
    ;;
esac
SH
chmod +x "$fake_bin/xcrun"

set +e
printf 'not gguf\n' >"$tmpdir/not-a-model.bin"
bash "$DEVICE_SMOKE" --device fake-device --model "$tmpdir/not-a-model.bin" >"$tmpdir/non-gguf.out" 2>&1
rc=$?
set -e
if [[ "$rc" -ne 2 ]]; then
  echo "FAIL: non-GGUF model should exit 2, got $rc" >&2
  cat "$tmpdir/non-gguf.out" >&2 || true
  exit 1
fi
if ! grep -q "GGUF device smoke requires a .gguf model file" "$tmpdir/non-gguf.out"; then
  echo "FAIL: existing non-GGUF model did not hit the extension guard." >&2
  cat "$tmpdir/non-gguf.out" >&2 || true
  exit 1
fi

printf 'fake gguf bytes\n' >"$tmpdir/model.gguf"
PATH="$fake_bin:$PATH" \
  FAKE_DEVICE_ROOT="$fake_device_root" \
  FAKE_COPY_LOG="$copy_log" \
  FAKE_ENV_LOG="$env_log" \
  bash "$DEVICE_SMOKE" \
    --device fake-device \
    --bundle-id com.ross.ios \
    --model "$tmpdir/model.gguf" \
    --tier quickStart \
    --pack-id unit-pack \
    --stage-timeout 5 \
    >"$tmpdir/gguf.out" 2>&1

if ! grep -q "ROSS_SMOKE_BENCHMARK_SUMMARY" "$tmpdir/gguf.out"; then
  echo "FAIL: fake GGUF smoke did not emit benchmark summary." >&2
  cat "$tmpdir/gguf.out" >&2 || true
  exit 1
fi

device_model_path="$(sed -n 's/^DEVICE_MODEL_PATH=//p' "$env_log" | head -n 1)"
device_model_name="$(basename "$device_model_path")"
if [[ "$device_model_name" == "model.gguf" ]]; then
  echo "FAIL: GGUF helper reused the source basename instead of a run-scoped seed filename." >&2
  exit 1
fi
if [[ "$device_model_name" != unit-pack-*.gguf ]]; then
  echo "FAIL: GGUF helper did not create the expected pack/checksum/run-scoped filename: $device_model_name" >&2
  exit 1
fi

model_copy_line="$(grep -n "COPY_TO $device_model_name " "$copy_log" | cut -d: -f1 | head -n 1)"
manifest_name="${device_model_name%.*}.manifest.json"
manifest_copy_line="$(grep -n "COPY_TO $manifest_name " "$copy_log" | cut -d: -f1 | head -n 1)"
if [[ -z "$model_copy_line" || -z "$manifest_copy_line" || "$model_copy_line" -ge "$manifest_copy_line" ]]; then
  echo "FAIL: GGUF helper must copy the model before publishing its manifest." >&2
  cat "$copy_log" >&2 || true
  exit 1
fi

manifest_path="$fake_device_root/Library/Application Support/RossAlpha/model-packs/quick_start/$manifest_name"
python3 - "$manifest_path" "$device_model_name" <<'PY'
import json
import pathlib
import sys

manifest = json.loads(pathlib.Path(sys.argv[1]).read_text())
device_model_name = sys.argv[2]
if manifest.get("tier") != "quick_start":
    raise SystemExit(f"manifest tier mismatch: {manifest.get('tier')}")
if manifest.get("fileName") != device_model_name:
    raise SystemExit(f"manifest fileName mismatch: {manifest.get('fileName')}")
if manifest.get("relativePath") != f"model-packs/quick_start/{device_model_name}":
    raise SystemExit(f"manifest relativePath mismatch: {manifest.get('relativePath')}")
PY

echo "iOS device GGUF smoke guard tests: PASS"

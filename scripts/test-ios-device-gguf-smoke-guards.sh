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
    remove_existing="false"
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
        --remove-existing-content)
          remove_existing="${2:-false}"
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
    if [[ "$remove_existing" == "true" ]]; then
      rm -rf "$FAKE_DEVICE_ROOT/$destination"
    fi
    mkdir -p "$FAKE_DEVICE_ROOT/$destination"
    for source in "${sources[@]}"; do
      source_basename="$(basename "$source")"
      if [[ -n "${FAKE_MODEL_COPY_DELAY:-}" ]] && {
        [[ "$source_basename" == *.gguf ]] || find "$source" -maxdepth 1 -name '*.gguf' -print -quit | grep -q .
      }; then
        sleep "$FAKE_MODEL_COPY_DELAY"
      fi
      if [[ -f "$source" ]]; then
        cp "$source" "$FAKE_DEVICE_ROOT/$destination/"
      elif [[ -d "$source" ]]; then
        cp -R "$source"/. "$FAKE_DEVICE_ROOT/$destination/"
      fi
      printf 'COPY_TO %s %s\n' "$source_basename" "$destination" >>"$FAKE_COPY_LOG"
    done
    if [[ "${#sources[@]}" -eq 1 ]]; then
      echo "Path: $FAKE_DEVICE_ROOT/$destination"
    else
      echo "Path: $FAKE_DEVICE_ROOT/$destination/"
    fi
    ;;
  process)
    printf 'DEVICE_MODEL_PATH=%s\n' "${DEVICECTL_CHILD_ROSS_LOCAL_MODEL_PATH:-}" >>"$FAKE_ENV_LOG"
    printf 'DRAFT_MODEL_PATH=%s\n' "${DEVICECTL_CHILD_ROSS_LOCAL_DRAFT_MODEL_PATH:-}" >>"$FAKE_ENV_LOG"
    printf 'DRAFT_MODEL_TOKENS=%s\n' "${DEVICECTL_CHILD_ROSS_LOCAL_DRAFT_MODEL_TOKENS:-}" >>"$FAKE_ENV_LOG"
    printf 'SMOKE_PROFILE=%s\n' "${DEVICECTL_CHILD_ROSS_LOCAL_MODEL_SMOKE_PROFILE:-}" >>"$FAKE_ENV_LOG"
    printf 'REQUIRE_DRAFT=%s\n' "${DEVICECTL_CHILD_ROSS_LOCAL_MODEL_SMOKE_REQUIRE_DRAFT_ACCELERATION:-}" >>"$FAKE_ENV_LOG"
    artifact="$(basename "${DEVICECTL_CHILD_ROSS_LOCAL_MODEL_PATH:-model.gguf}")"
    if [[ -n "${FAKE_IDENTITY_ARTIFACT:-}" ]]; then
      artifact="$FAKE_IDENTITY_ARTIFACT"
    fi
    smoke_profile="${DEVICECTL_CHILD_ROSS_LOCAL_MODEL_SMOKE_PROFILE:-full}"
    if [[ "${DEVICECTL_CHILD_ROSS_LOCAL_MODEL_SMOKE_REQUIRE_DRAFT_ACCELERATION:-}" == "1" ]]; then
      draft_artifact="$(basename "${DEVICECTL_CHILD_ROSS_LOCAL_DRAFT_MODEL_PATH:-draft.gguf}")"
      draft_tokens="${DEVICECTL_CHILD_ROSS_LOCAL_DRAFT_MODEL_TOKENS:-2}"
      cat <<EOF
Launched application with com.ross.ios bundle identifier.
ROSS_RUNTIME_IDENTITY provider=AlphaLlamaCppProvider requested_runtime=gemma_local_runtime actual_runtime=gemma_local_runtime pack_runtime=gemma_local_runtime model_format=local_model_artifact checksum_verified=true artifact_path_type=file artifact_path=$artifact acceleration=draftModelSpeculative draft_tokens=$draft_tokens draft_model=$draft_artifact draft_model_path_type=file draft_status=active draft_error_detail=configured_acceleration=draftModelSpeculative runtime_error_detail=nil context_tokens=1024 gpu_offload=n_gpu_layers:0 fallback=none available=true
ROSS_LOCAL_MODEL_SMOKE_BENCHMARK_MATRIX profile=$smoke_profile cases=english_source_bound_document_qa_low_token,english_open_no_document_query_low_token stages=source:document_qa:en:source_refs_required:max_tokens=24,general:open_query:en:no_source_refs:max_tokens=24
ROSS_LOCAL_MODEL_SMOKE_STAGE_DONE stage=source duration_ms=100 schema_valid=true error=nil runtime_error_detail=nil source_input_tokens=10 source_output_tokens=5 source_token_speed=10.0 source_first_token_ms=100 source_measured_tokens=true source_acceleration=draftModelSpeculative source_draft_tokens=$draft_tokens source_draft_model=$draft_artifact source_draft_attempted=4 source_draft_accepted=2 source_draft_failure=nil source_runtime_error_detail=nil
ROSS_LOCAL_MODEL_SMOKE_STAGE_DONE stage=general duration_ms=100 schema_valid=true error=nil runtime_error_detail=nil general_input_tokens=10 general_output_tokens=5 general_token_speed=10.0 general_first_token_ms=100 general_measured_tokens=true general_acceleration=draftModelSpeculative general_draft_tokens=$draft_tokens general_draft_model=$draft_artifact general_draft_attempted=4 general_draft_accepted=2 general_draft_failure=nil general_runtime_error_detail=nil
ROSS_LOCAL_MODEL_SMOKE_PASS runtime=gemma_local_runtime requested_runtime=gemma_local_runtime tier=quick_start profile=$smoke_profile elapsed=10.00s source_refs=1 source_native_model=true general_native_model=true
EOF
      exit 0
    fi
    cat <<EOF
Launched application with com.ross.ios bundle identifier.
ROSS_RUNTIME_IDENTITY provider=AlphaLlamaCppProvider requested_runtime=gemma_local_runtime actual_runtime=gemma_local_runtime pack_runtime=gemma_local_runtime model_format=local_model_artifact checksum_verified=true artifact_path_type=file artifact_path=$artifact acceleration=standard draft_tokens=nil draft_model=nil draft_model_path_type=nil draft_status=no_draft_configured draft_error_detail=no_draft_configured runtime_error_detail=nil context_tokens=4096 gpu_offload=n_gpu_layers:0 fallback=none available=true
ROSS_LOCAL_MODEL_SMOKE_BENCHMARK_MATRIX profile=$smoke_profile cases=english_source_bound_document_qa,english_open_no_document_query,bengali_source_bound_document_qa,hindi_source_bound_document_qa,tamil_source_bound_document_qa,telugu_source_bound_document_qa stages=source:document_qa:en:source_refs_required:max_tokens=192,general:open_query:en:no_source_refs:max_tokens=192,bengali:document_qa:bn:source_refs_required:max_tokens=192,hindi:document_qa:hi:source_refs_required:max_tokens=192,tamil:document_qa:ta:source_refs_required:max_tokens=192,telugu:document_qa:te:source_refs_required:max_tokens=192
ROSS_LOCAL_MODEL_SMOKE_STAGE_DONE stage=source duration_ms=100 schema_valid=true error=nil runtime_error_detail=nil source_input_tokens=10 source_output_tokens=5 source_token_speed=10.0 source_first_token_ms=100 source_measured_tokens=true source_acceleration=standard source_draft_tokens=nil source_draft_model=nil source_runtime_error_detail=nil
ROSS_LOCAL_MODEL_SMOKE_STAGE_DONE stage=general duration_ms=100 schema_valid=true error=nil runtime_error_detail=nil general_input_tokens=10 general_output_tokens=5 general_token_speed=10.0 general_first_token_ms=100 general_measured_tokens=true general_acceleration=standard general_draft_tokens=nil general_draft_model=nil general_runtime_error_detail=nil
ROSS_LOCAL_MODEL_SMOKE_STAGE_DONE stage=bengali duration_ms=100 schema_valid=true error=nil runtime_error_detail=nil bengali_input_tokens=10 bengali_output_tokens=5 bengali_token_speed=10.0 bengali_first_token_ms=100 bengali_measured_tokens=true bengali_acceleration=standard bengali_draft_tokens=nil bengali_draft_model=nil bengali_runtime_error_detail=nil
ROSS_LOCAL_MODEL_SMOKE_STAGE_DONE stage=hindi duration_ms=100 schema_valid=true error=nil runtime_error_detail=nil hindi_input_tokens=10 hindi_output_tokens=5 hindi_token_speed=10.0 hindi_first_token_ms=100 hindi_measured_tokens=true hindi_acceleration=standard hindi_draft_tokens=nil hindi_draft_model=nil hindi_runtime_error_detail=nil
ROSS_LOCAL_MODEL_SMOKE_STAGE_DONE stage=tamil duration_ms=100 schema_valid=true error=nil runtime_error_detail=nil tamil_input_tokens=10 tamil_output_tokens=5 tamil_token_speed=10.0 tamil_first_token_ms=100 tamil_measured_tokens=true tamil_acceleration=standard tamil_draft_tokens=nil tamil_draft_model=nil tamil_runtime_error_detail=nil
ROSS_LOCAL_MODEL_SMOKE_STAGE_DONE stage=telugu duration_ms=100 schema_valid=true error=nil runtime_error_detail=nil telugu_input_tokens=10 telugu_output_tokens=5 telugu_token_speed=10.0 telugu_first_token_ms=100 telugu_measured_tokens=true telugu_acceleration=standard telugu_draft_tokens=nil telugu_draft_model=nil telugu_runtime_error_detail=nil
ROSS_LOCAL_MODEL_SMOKE_PASS runtime=gemma_local_runtime requested_runtime=gemma_local_runtime tier=quick_start profile=$smoke_profile elapsed=10.00s source_refs=1 source_native_model=true general_native_model=true bengali_source_refs=1 bengali_native_model=true hindi_source_refs=1 hindi_native_model=true tamil_source_refs=1 tamil_native_model=true telugu_source_refs=1 telugu_native_model=true
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
set +e
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
rc=$?
set -e
if [[ "$rc" -ne 0 ]]; then
  echo "FAIL: fake GGUF smoke should exit 0, got $rc" >&2
  cat "$tmpdir/gguf.out" >&2 || true
  exit 1
fi

if ! grep -q "ROSS_SMOKE_BENCHMARK_SUMMARY" "$tmpdir/gguf.out"; then
  echo "FAIL: fake GGUF smoke did not emit benchmark summary." >&2
  cat "$tmpdir/gguf.out" >&2 || true
  exit 1
fi

rm -f "$copy_log" "$env_log"
set +e
PATH="$fake_bin:$PATH" \
  FAKE_DEVICE_ROOT="$fake_device_root" \
  FAKE_COPY_LOG="$copy_log" \
  FAKE_ENV_LOG="$env_log" \
  bash "$DEVICE_SMOKE" \
    --device fake-device \
    --bundle-id com.ross.ios \
    --model "$tmpdir/model.gguf" \
    --tier quickStart \
    --pack-id unit-pack-low-context \
    --smoke-profile quick_low_context \
    --stage-timeout 5 \
    >"$tmpdir/gguf-quick-low-context.out" 2>&1
rc=$?
set -e
if [[ "$rc" -ne 0 ]]; then
  echo "FAIL: fake GGUF quick_low_context smoke should exit 0, got $rc" >&2
  cat "$tmpdir/gguf-quick-low-context.out" >&2 || true
  exit 1
fi
if ! grep -q '^SMOKE_PROFILE=quick_low_context$' "$env_log"; then
  echo "FAIL: GGUF helper did not pass quick_low_context launch environment." >&2
  cat "$env_log" >&2 || true
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

manifest_name="${device_model_name%.*}.manifest.json"
if ! grep -q "COPY_TO quick_start Library/Application Support/RossAlpha/model-packs/quick_start" "$copy_log"; then
  echo "FAIL: GGUF helper must publish the quick_start tier as a directory copy." >&2
  cat "$copy_log" >&2 || true
  exit 1
fi

seeded_tier_path="$fake_device_root/Library/Application Support/RossAlpha/model-packs/quick_start"
if [[ ! -d "$seeded_tier_path" ]]; then
  echo "FAIL: GGUF helper did not create quick_start as a device directory." >&2
  exit 1
fi
if [[ ! -f "$seeded_tier_path/$device_model_name" || ! -f "$seeded_tier_path/$manifest_name" ]]; then
  echo "FAIL: GGUF helper did not seed both model and manifest into quick_start." >&2
  find "$seeded_tier_path" -maxdepth 1 -type f -print >&2 || true
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

set +e
PATH="$fake_bin:$PATH" \
  FAKE_DEVICE_ROOT="$fake_device_root" \
  FAKE_COPY_LOG="$copy_log" \
  FAKE_ENV_LOG="$env_log" \
  FAKE_IDENTITY_ARTIFACT="different-installed-model.gguf" \
  bash "$DEVICE_SMOKE" \
    --device fake-device \
    --bundle-id com.ross.ios \
    --model "$tmpdir/model.gguf" \
    --tier quickStart \
    --pack-id unit-pack \
    --stage-timeout 5 \
    >"$tmpdir/gguf-mismatch.out" 2>&1
rc=$?
set -e
if [[ "$rc" -ne 1 ]]; then
  echo "FAIL: mismatched GGUF runtime identity artifact should exit 1, got $rc" >&2
  cat "$tmpdir/gguf-mismatch.out" >&2 || true
  exit 1
fi
if ! grep -q "runtime_identity_artifact_path_mismatch" "$tmpdir/gguf-mismatch.out"; then
  echo "FAIL: mismatched GGUF runtime identity artifact did not hit exact artifact guard." >&2
  cat "$tmpdir/gguf-mismatch.out" >&2 || true
  exit 1
fi

set +e
bash "$DEVICE_SMOKE" \
  --device fake-device \
  --model "$tmpdir/model.gguf" \
  --draft-model "$tmpdir/model.gguf" \
  --require-draft-acceleration \
  --smoke-profile quick \
  >"$tmpdir/gguf-draft-non-mtp.out" 2>&1
rc=$?
set -e
if [[ "$rc" -ne 2 ]]; then
  echo "FAIL: requiring draft acceleration with a non-MTP profile should exit 2, got $rc" >&2
  cat "$tmpdir/gguf-draft-non-mtp.out" >&2 || true
  exit 1
fi
if ! grep -q "Draft acceleration proof requires --smoke-profile mtp_quick" "$tmpdir/gguf-draft-non-mtp.out"; then
  echo "FAIL: non-MTP draft proof did not report the profile guard." >&2
  cat "$tmpdir/gguf-draft-non-mtp.out" >&2 || true
  exit 1
fi

set +e
bash "$DEVICE_SMOKE" \
  --device fake-device \
  --model "$tmpdir/model.gguf" \
  --require-draft-acceleration \
  --smoke-profile mtp_quick \
  >"$tmpdir/gguf-draft-missing.out" 2>&1
rc=$?
set -e
if [[ "$rc" -ne 2 ]]; then
  echo "FAIL: requiring draft acceleration without --draft-model should exit 2, got $rc" >&2
  cat "$tmpdir/gguf-draft-missing.out" >&2 || true
  exit 1
fi
if ! grep -q "requires --draft-model" "$tmpdir/gguf-draft-missing.out"; then
  echo "FAIL: missing draft model did not report the draft-model guard." >&2
  cat "$tmpdir/gguf-draft-missing.out" >&2 || true
  exit 1
fi

printf 'fake draft bytes\n' >"$tmpdir/draft.bin"
set +e
bash "$DEVICE_SMOKE" \
  --device fake-device \
  --model "$tmpdir/model.gguf" \
  --draft-model "$tmpdir/draft.bin" \
  --require-draft-acceleration \
  --smoke-profile mtp_quick \
  >"$tmpdir/gguf-draft-non-gguf.out" 2>&1
rc=$?
set -e
if [[ "$rc" -ne 2 ]]; then
  echo "FAIL: non-GGUF draft model should exit 2, got $rc" >&2
  cat "$tmpdir/gguf-draft-non-gguf.out" >&2 || true
  exit 1
fi
if ! grep -q "requires a .gguf draft model file" "$tmpdir/gguf-draft-non-gguf.out"; then
  echo "FAIL: non-GGUF draft did not hit the extension guard." >&2
  cat "$tmpdir/gguf-draft-non-gguf.out" >&2 || true
  exit 1
fi

printf 'fake draft gguf bytes\n' >"$tmpdir/draft.gguf"
rm -f "$copy_log" "$env_log"
set +e
PATH="$fake_bin:$PATH" \
  FAKE_DEVICE_ROOT="$fake_device_root" \
  FAKE_COPY_LOG="$copy_log" \
  FAKE_ENV_LOG="$env_log" \
  bash "$DEVICE_SMOKE" \
    --device fake-device \
    --bundle-id com.ross.ios \
    --model "$tmpdir/model.gguf" \
    --draft-model "$tmpdir/draft.gguf" \
    --draft-tokens 2 \
    --tier quickStart \
    --pack-id unit-pack-mtp \
    --smoke-profile mtp_quick \
    --require-draft-acceleration \
    --stage-timeout 5 \
    >"$tmpdir/gguf-draft.out" 2>&1
rc=$?
set -e
if [[ "$rc" -ne 0 ]]; then
  echo "FAIL: fake GGUF MTP draft smoke should exit 0, got $rc" >&2
  cat "$tmpdir/gguf-draft.out" >&2 || true
  exit 1
fi
if ! grep -q "ROSS_SMOKE_BENCHMARK_SUMMARY" "$tmpdir/gguf-draft.out"; then
  echo "FAIL: fake GGUF MTP draft smoke did not emit benchmark summary." >&2
  cat "$tmpdir/gguf-draft.out" >&2 || true
  exit 1
fi
if ! grep -q "matrix_profile=mtp_quick" "$tmpdir/gguf-draft.out" ||
   ! grep -q "source_acceleration=draftModelSpeculative" "$tmpdir/gguf-draft.out" ||
   ! grep -q "general_acceleration=draftModelSpeculative" "$tmpdir/gguf-draft.out" ||
   ! grep -q "source_draft_accepted=2" "$tmpdir/gguf-draft.out" ||
   ! grep -q "general_draft_accepted=2" "$tmpdir/gguf-draft.out"; then
  echo "FAIL: fake GGUF MTP draft summary did not preserve profile and draft-stage metrics." >&2
  cat "$tmpdir/gguf-draft.out" >&2 || true
  exit 1
fi

draft_device_path="$(sed -n 's/^DRAFT_MODEL_PATH=//p' "$env_log" | head -n 1)"
draft_device_name="$(basename "$draft_device_path")"
if [[ "$draft_device_name" != unit-pack-mtp-draft-*.gguf ]]; then
  echo "FAIL: GGUF helper did not create the expected run-scoped draft filename: $draft_device_name" >&2
  exit 1
fi
if ! grep -q '^DRAFT_MODEL_TOKENS=2$' "$env_log" ||
   ! grep -q '^SMOKE_PROFILE=mtp_quick$' "$env_log" ||
   ! grep -q '^REQUIRE_DRAFT=1$' "$env_log"; then
  echo "FAIL: GGUF helper did not pass draft proof launch environment." >&2
  cat "$env_log" >&2 || true
  exit 1
fi

draft_device_model_path="$(sed -n 's/^DEVICE_MODEL_PATH=//p' "$env_log" | head -n 1)"
draft_primary_name="$(basename "$draft_device_model_path")"
draft_manifest_name="${draft_primary_name%.*}.manifest.json"
draft_manifest_path="$fake_device_root/Library/Application Support/RossAlpha/model-packs/quick_start/$draft_manifest_name"
python3 - "$draft_manifest_path" "$draft_device_name" <<'PY'
import json
import pathlib
import sys

manifest = json.loads(pathlib.Path(sys.argv[1]).read_text())
draft_name = sys.argv[2]
draft = manifest.get("draftArtifact") or {}
if draft.get("fileName") != draft_name:
    raise SystemExit(f"draft fileName mismatch: {draft.get('fileName')}")
if draft.get("relativePath") != f"model-packs/quick_start/{draft_name}":
    raise SystemExit(f"draft relativePath mismatch: {draft.get('relativePath')}")
if draft.get("artifactKind") != "local_model_artifact":
    raise SystemExit(f"draft artifactKind mismatch: {draft.get('artifactKind')}")
if draft.get("draftTokens") != 2:
    raise SystemExit(f"draftTokens mismatch: {draft.get('draftTokens')}")
PY

set +e
PATH="$fake_bin:$PATH" \
  FAKE_DEVICE_ROOT="$fake_device_root" \
  FAKE_COPY_LOG="$copy_log" \
  FAKE_ENV_LOG="$env_log" \
  FAKE_MODEL_COPY_DELAY=2 \
  bash "$DEVICE_SMOKE" \
    --device fake-device \
    --bundle-id com.ross.ios \
    --model "$tmpdir/model.gguf" \
    --tier quickStart \
    --pack-id unit-pack \
    --stage-timeout 5 \
    --copy-timeout 1 \
    >"$tmpdir/gguf-copy-timeout.out" 2>&1
rc=$?
set -e
if [[ "$rc" -ne 1 ]]; then
  echo "FAIL: stalled GGUF model copy should exit 1, got $rc" >&2
  cat "$tmpdir/gguf-copy-timeout.out" >&2 || true
  exit 1
fi
if ! grep -q "pack_directory_copy timed out after 1s" "$tmpdir/gguf-copy-timeout.out"; then
  echo "FAIL: stalled GGUF model copy did not report the bounded copy timeout." >&2
  cat "$tmpdir/gguf-copy-timeout.out" >&2 || true
  exit 1
fi

echo "iOS device GGUF smoke guard tests: PASS"

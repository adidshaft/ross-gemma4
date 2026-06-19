#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  cat <<'EOF'
Usage:
  scripts/ios-device-gguf-smoke.sh --device <udid> --model <path-to-gguf> [options]

Options:
  --device <udid>         Physical iPhone UDID accepted by devicectl.
  --model <path>          Local GGUF file to seed into the app container.
  --bundle-id <id>        App bundle identifier. Default: com.ross.ios
  --tier <tier>           quickStart | caseAssociate | seniorDraftingSupport
                          Default: quickStart
  --pack-id <id>          Logical pack id written into the seeded manifest.
                          Default: <model-basename>-device-proof
  --stage-timeout <sec>   Per-stage smoke timeout. Default: 45
  --copy-timeout <sec>    Per-copy devicectl timeout. Default: 300

This helper:
  1. Seeds the GGUF file plus a manifest into RossAlpha/model-packs/<tier>
  2. Resolves the app container root using a tiny probe copy
  3. Launches Ross with --local-model-smoke against the seeded GGUF path
  4. Exits 0 only after a ROSS_LOCAL_MODEL_SMOKE_PASS line appears
EOF
}

device_id=""
model_path=""
bundle_id="com.ross.ios"
tier="quickStart"
pack_id=""
stage_timeout="45"
copy_timeout="300"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --device)
      device_id="${2:-}"
      shift 2
      ;;
    --model)
      model_path="${2:-}"
      shift 2
      ;;
    --bundle-id)
      bundle_id="${2:-}"
      shift 2
      ;;
    --tier)
      tier="${2:-}"
      shift 2
      ;;
    --pack-id)
      pack_id="${2:-}"
      shift 2
      ;;
    --stage-timeout)
      stage_timeout="${2:-}"
      shift 2
      ;;
    --copy-timeout)
      copy_timeout="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ -z "$device_id" || -z "$model_path" ]]; then
  usage >&2
  exit 2
fi

if [[ ! -f "$model_path" ]]; then
  echo "Model file not found: $model_path" >&2
  exit 2
fi

if [[ -z "$copy_timeout" || "$copy_timeout" == *[!0-9]* || "$copy_timeout" -le 0 ]]; then
  echo "Copy timeout must be a positive integer number of seconds." >&2
  exit 2
fi

case "$tier" in
  quickStart|caseAssociate|seniorDraftingSupport)
    ;;
  *)
    echo "Unsupported tier: $tier" >&2
    exit 2
    ;;
esac

case "$tier" in
  quickStart)
    canonical_tier="quick_start"
    ;;
  caseAssociate)
    canonical_tier="case_associate"
    ;;
  seniorDraftingSupport)
    canonical_tier="senior_drafting_support"
    ;;
esac

model_basename="$(basename "$model_path")"
model_basename_lower="$(printf '%s' "$model_basename" | tr '[:upper:]' '[:lower:]')"
case "$model_basename_lower" in
  *.gguf)
    ;;
  *)
    echo "GGUF device smoke requires a .gguf model file: $model_path" >&2
    exit 2
    ;;
esac

if ! command -v xcrun >/dev/null 2>&1; then
  echo "xcrun is required." >&2
  exit 2
fi

if [[ -z "$pack_id" ]]; then
  pack_id="${model_basename%.*}-device-proof"
fi

checksum="$(shasum -a 256 "$model_path" | awk '{print $1}')"
bytes="$(wc -c < "$model_path" | tr -d '[:space:]')"
verified_at="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
run_id="$(date -u +"%Y%m%dT%H%M%SZ")"
safe_pack_id="$(printf '%s' "$pack_id" | tr -c 'A-Za-z0-9._-' '-')"
seed_model_basename="${safe_pack_id}-${checksum:0:12}-${run_id}.gguf"
manifest_basename="${seed_model_basename%.*}.manifest.json"

tmpdir="$(mktemp -d /tmp/ross-ios-device-gguf-smoke.XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT

run_devicectl_copy_with_timeout() {
  local description="$1"
  local output_file="$2"
  shift 2

  : > "$output_file"
  set +e
  "$@" > "$output_file" 2>&1 &
  local pid=$!
  local elapsed=0
  local rc=0
  while kill -0 "$pid" 2>/dev/null; do
    if [[ "$elapsed" -ge "$copy_timeout" ]]; then
      kill "$pid" 2>/dev/null || true
      sleep 1
      kill -9 "$pid" 2>/dev/null || true
      wait "$pid" 2>/dev/null
      set -e
      echo "GGUF device smoke $description timed out after ${copy_timeout}s." >&2
      cat "$output_file" >&2 || true
      exit 1
    fi
    sleep 1
    elapsed=$((elapsed + 1))
  done
  wait "$pid"
  rc=$?
  set -e

  if [[ "$rc" -ne 0 ]]; then
    echo "GGUF device smoke $description failed with exit code $rc." >&2
    cat "$output_file" >&2 || true
    exit "$rc"
  fi
}

probe_dir="$tmpdir/Library/Application Support/RossAlpha"
seed_dir="$tmpdir/$canonical_tier"
mkdir -p "$probe_dir" "$seed_dir"

probe_file="$probe_dir/.device-proof-probe"
printf 'ross-device-proof\n' > "$probe_file"
cp "$model_path" "$seed_dir/$seed_model_basename"

cat > "$seed_dir/$manifest_basename" <<EOF
{
  "packId": "$pack_id",
  "tier": "$canonical_tier",
  "fileName": "$seed_model_basename",
  "relativePath": "model-packs/$canonical_tier/$seed_model_basename",
  "checksumSha256": "$checksum",
  "bytes": $bytes,
  "artifactKind": "local_model_artifact",
  "runtimeMode": "gemma_local_runtime",
  "developmentOnly": false,
  "verifiedAt": "$verified_at"
}
EOF

probe_output="$tmpdir/probe-copy.txt"
run_devicectl_copy_with_timeout "probe_copy" "$probe_output" \
  xcrun devicectl device copy to \
  --device "$device_id" \
  --domain-type appDataContainer \
  --domain-identifier "$bundle_id" \
  --source "$probe_file" \
  --destination 'Library/Application Support/RossAlpha/.device-proof-probe'

probe_device_path="$(sed -n 's/^Path: //p' "$probe_output" | head -n 1)"
if [[ -z "$probe_device_path" ]]; then
  echo "Could not resolve the app container root from devicectl output." >&2
  cat "$probe_output" >&2
  exit 1
fi

container_root="${probe_device_path%/Library/Application Support/RossAlpha/.device-proof-probe}"
relative_model_path="model-packs/$canonical_tier/$seed_model_basename"
device_model_path="$container_root/Library/Application Support/RossAlpha/$relative_model_path"

echo "Resolved app container root: $container_root"
echo "Seeding model to: $device_model_path"
echo "Publishing tier directory with manifest: $canonical_tier"

run_devicectl_copy_with_timeout "pack_directory_copy" "$tmpdir/pack-directory-copy.txt" \
  xcrun devicectl device copy to \
  --device "$device_id" \
  --domain-type appDataContainer \
  --domain-identifier "$bundle_id" \
  --source "$seed_dir" \
  --destination "Library/Application Support/RossAlpha/model-packs/$canonical_tier" \
  --remove-existing-content true

python3 - "$device_id" "$bundle_id" "$relative_model_path" "$checksum" "$stage_timeout" "$SCRIPT_DIR" <<'PY'
import os
import re
import signal
import subprocess
import sys

sys.path.insert(0, sys.argv[-1])
from ross_smoke_summary import (
    MissingBenchmarkMatrixError,
    METRICS,
    STAGE_AUX_METRICS,
    STAGES,
    benchmark_summary_line,
    failure_summary_line,
    parse_fields,
    runtime_identity_artifact_error,
    runtime_identity_availability_error,
    runtime_identity_resource_error,
)

device_id, bundle_id, device_model_path, checksum, stage_timeout = sys.argv[1:-1]

env = os.environ.copy()
env.update(
    {
        "DEVICECTL_CHILD_ROSS_ENABLE_REAL_LOCAL_INFERENCE": "1",
        "DEVICECTL_CHILD_ROSS_LOCAL_RUNTIME": "gemma_local_runtime",
        "DEVICECTL_CHILD_ROSS_LOCAL_MODEL_PATH": device_model_path,
        "DEVICECTL_CHILD_ROSS_LOCAL_MODEL_CHECKSUM": checksum,
        "DEVICECTL_CHILD_ROSS_LOCAL_MODEL_KIND": "gguf",
        "DEVICECTL_CHILD_ROSS_LOCAL_MODEL_SMOKE_STAGE_TIMEOUT_SECONDS": stage_timeout,
    }
)

command = [
    "xcrun",
    "devicectl",
    "device",
    "process",
    "launch",
    "--device",
    device_id,
    "--terminate-existing",
    "--console",
    bundle_id,
    "--local-model-smoke",
]

pass_re = re.compile(r"ROSS_LOCAL_MODEL_SMOKE_PASS\b")
fail_re = re.compile(r"ROSS_LOCAL_MODEL_SMOKE_FAIL\b")
identity_re = re.compile(r"^ROSS_RUNTIME_IDENTITY\b")
matrix_re = re.compile(r"^ROSS_LOCAL_MODEL_SMOKE_BENCHMARK_MATRIX\b")
stage_done_re = re.compile(r"^ROSS_LOCAL_MODEL_SMOKE_STAGE_DONE\b")
def print_benchmark_summary(identity, pass_fields, matrix_fields):
    print(benchmark_summary_line(identity, pass_fields, matrix_fields))

def validate_identity_guard(identity, *, require_identity):
    if identity is None:
        if require_identity:
            print("ROSS_SMOKE_GUARD_FAIL reason=missing_runtime_identity", file=sys.stderr)
            sys.exit(1)
        return

    actual_runtime = identity.get("actual_runtime")
    requested_runtime = identity.get("requested_runtime")
    if actual_runtime != "gemma_local_runtime" or requested_runtime not in ("gemma_local_runtime", "nil"):
        print(
            "ROSS_SMOKE_GUARD_FAIL "
            "reason=runtime_identity_mismatch requested=gemma_local_runtime "
            f"identity_requested={requested_runtime} actual={actual_runtime}",
            file=sys.stderr,
        )
        sys.exit(1)
    pack_runtime = identity.get("pack_runtime")
    if pack_runtime not in (None, "nil", actual_runtime):
        print(
            "ROSS_SMOKE_GUARD_FAIL "
            "reason=pack_runtime_mismatch requested=gemma_local_runtime "
            f"pack_runtime={pack_runtime} actual={actual_runtime}",
            file=sys.stderr,
        )
        sys.exit(1)

    if require_identity:
        if pack_runtime in (None, "nil", ""):
            print(
                "ROSS_SMOKE_GUARD_FAIL "
                "reason=pack_runtime_missing requested=gemma_local_runtime "
                f"actual={actual_runtime}",
                file=sys.stderr,
            )
            sys.exit(1)

        availability_error = runtime_identity_availability_error(identity)
        if availability_error:
            print(
                "ROSS_SMOKE_GUARD_FAIL "
                "reason=runtime_identity_unavailable requested=gemma_local_runtime "
                f"{availability_error}",
                file=sys.stderr,
            )
            sys.exit(1)

        artifact_error = runtime_identity_artifact_error(identity, "gemma_local_runtime")
        if artifact_error:
            print(
                "ROSS_SMOKE_GUARD_FAIL "
                "reason=runtime_identity_artifact_mismatch requested=gemma_local_runtime "
                f"{artifact_error}",
                file=sys.stderr,
            )
            sys.exit(1)

        resource_error = runtime_identity_resource_error(identity)
        if resource_error:
            print(
                "ROSS_SMOKE_GUARD_FAIL "
                "reason=runtime_identity_resource_missing requested=gemma_local_runtime "
                f"{resource_error}",
                file=sys.stderr,
            )
            sys.exit(1)

        expected_artifact_name = os.path.basename(device_model_path)
        identity_artifact_name = os.path.basename(identity.get("artifact_path") or "")
        if identity_artifact_name != expected_artifact_name:
            print(
                "ROSS_SMOKE_GUARD_FAIL "
                "reason=runtime_identity_artifact_path_mismatch requested=gemma_local_runtime "
                f"expected_artifact={expected_artifact_name} identity_artifact={identity_artifact_name or 'nil'}",
                file=sys.stderr,
            )
            sys.exit(1)

outcome = None
identity = None
matrix_fields = None
pass_fields = None
fail_fields = None
completed_stage_fields = {}
process = subprocess.Popen(
    command,
    stdout=subprocess.PIPE,
    stderr=subprocess.STDOUT,
    text=True,
    env=env,
    bufsize=1,
)

try:
    assert process.stdout is not None
    for raw_line in process.stdout:
        line = raw_line.rstrip("\n")
        print(line)
        if identity_re.search(line):
            identity = parse_fields(line)
        if matrix_re.search(line):
            matrix_fields = parse_fields(line)
        if stage_done_re.search(line):
            stage_fields = parse_fields(line)
            for stage in STAGES:
                for metric in METRICS + STAGE_AUX_METRICS:
                    key = f"{stage}_{metric}"
                    if key in stage_fields:
                        completed_stage_fields[key] = stage_fields[key]
        if pass_re.search(line):
            outcome = "pass"
            pass_fields = {
                **completed_stage_fields,
                **parse_fields(line),
            }
            process.send_signal(signal.SIGINT)
            break
        if fail_re.search(line):
            outcome = "fail"
            fail_fields = {
                **completed_stage_fields,
                **parse_fields(line),
            }
            process.send_signal(signal.SIGINT)
            break
finally:
    try:
        process.wait(timeout=15)
    except subprocess.TimeoutExpired:
        process.kill()
        process.wait(timeout=5)

if outcome == "pass":
    validate_identity_guard(identity, require_identity=True)
    if pass_fields is not None:
        try:
            print_benchmark_summary(identity, pass_fields, matrix_fields)
        except MissingBenchmarkMatrixError as error:
            print(f"ROSS_SMOKE_GUARD_FAIL reason={error}", file=sys.stderr)
            sys.exit(1)
    sys.exit(0)

if outcome == "fail":
    validate_identity_guard(identity, require_identity=False)
    print(failure_summary_line(identity, fail_fields, matrix_fields))
    sys.exit(1)

sys.exit(process.returncode or 1)
PY

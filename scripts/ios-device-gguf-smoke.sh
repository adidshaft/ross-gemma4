#!/usr/bin/env bash
set -euo pipefail

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

case "$tier" in
  quickStart|caseAssociate|seniorDraftingSupport)
    ;;
  *)
    echo "Unsupported tier: $tier" >&2
    exit 2
    ;;
esac

if ! command -v xcrun >/dev/null 2>&1; then
  echo "xcrun is required." >&2
  exit 2
fi

model_basename="$(basename "$model_path")"
manifest_basename="${model_basename%.*}.manifest.json"
if [[ -z "$pack_id" ]]; then
  pack_id="${model_basename%.*}-device-proof"
fi

checksum="$(shasum -a 256 "$model_path" | awk '{print $1}')"
bytes="$(wc -c < "$model_path" | tr -d '[:space:]')"
verified_at="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

tmpdir="$(mktemp -d /tmp/ross-ios-device-gguf-smoke.XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT

probe_dir="$tmpdir/Library/Application Support/RossAlpha"
seed_dir="$probe_dir/model-packs/$tier"
mkdir -p "$seed_dir"

probe_file="$probe_dir/.device-proof-probe"
printf 'ross-device-proof\n' > "$probe_file"
cp "$model_path" "$seed_dir/$model_basename"

cat > "$seed_dir/$manifest_basename" <<EOF
{
  "packId": "$pack_id",
  "tier": "$tier",
  "fileName": "$model_basename",
  "relativePath": "model-packs/$tier/$model_basename",
  "checksumSha256": "$checksum",
  "bytes": $bytes,
  "artifactKind": "local_model_artifact",
  "runtimeMode": "gemma_local_runtime",
  "developmentOnly": false,
  "verifiedAt": "$verified_at"
}
EOF

probe_output="$tmpdir/probe-copy.txt"
xcrun devicectl device copy to \
  --device "$device_id" \
  --domain-type appDataContainer \
  --domain-identifier "$bundle_id" \
  --source "$probe_file" \
  --destination 'Library/Application Support/RossAlpha/.device-proof-probe' \
  > "$probe_output"

probe_device_path="$(sed -n 's/^Path: //p' "$probe_output" | head -n 1)"
if [[ -z "$probe_device_path" ]]; then
  echo "Could not resolve the app container root from devicectl output." >&2
  cat "$probe_output" >&2
  exit 1
fi

container_root="${probe_device_path%/Library/Application Support/RossAlpha/.device-proof-probe}"
device_model_path="$container_root/Library/Application Support/RossAlpha/model-packs/$tier/$model_basename"

echo "Resolved app container root: $container_root"
echo "Seeding model to: $device_model_path"

xcrun devicectl device copy to \
  --device "$device_id" \
  --domain-type appDataContainer \
  --domain-identifier "$bundle_id" \
  --source "$seed_dir/$model_basename" \
  --source "$seed_dir/$manifest_basename" \
  --destination "Library/Application Support/RossAlpha/model-packs/$tier/" \
  > /dev/null

python3 - "$device_id" "$bundle_id" "$device_model_path" "$checksum" "$stage_timeout" <<'PY'
import os
import re
import signal
import subprocess
import sys

device_id, bundle_id, device_model_path, checksum, stage_timeout = sys.argv[1:]

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

def parse_fields(line, skip_prefix=True):
    fields = {}
    chunks = line.split()[1:] if skip_prefix else line.split()
    for chunk in chunks:
        if "=" not in chunk:
            continue
        key, value = chunk.split("=", 1)
        fields[key] = value
    return fields

def summary_value(fields, key):
    value = fields.get(key)
    return value if value not in (None, "") else "nil"

def print_benchmark_summary(identity, pass_fields):
    stages = [
        "source",
        "general",
        "bengali",
        "hindi",
        "tamil",
        "telugu",
    ]
    summary = {
        "runtime": summary_value(identity, "actual_runtime"),
        "requested_runtime": summary_value(identity, "requested_runtime"),
        "model_format": summary_value(identity, "model_format"),
        "artifact_path_type": summary_value(identity, "artifact_path_type"),
        "acceleration": summary_value(identity, "acceleration"),
        "draft_tokens": summary_value(identity, "draft_tokens"),
        "draft_model": summary_value(identity, "draft_model"),
        "draft_status": summary_value(identity, "draft_status"),
        "profile": summary_value(pass_fields, "profile"),
        "elapsed": summary_value(pass_fields, "elapsed"),
    }
    for stage in stages:
        for metric in [
            "input_tokens",
            "output_tokens",
            "token_speed",
            "first_token_ms",
            "measured_tokens",
        ]:
            key = f"{stage}_{metric}"
            if key in pass_fields:
                summary[key] = pass_fields[key]

    line = " ".join(f"{key}={value}" for key, value in summary.items())
    print(f"ROSS_SMOKE_BENCHMARK_SUMMARY {line}")

def validate_identity_guard(identity, *, require_identity):
    if identity is None:
        if require_identity:
            print("ROSS_SMOKE_GUARD_FAIL reason=missing_runtime_identity", file=sys.stderr)
            sys.exit(1)
        return

    actual_runtime = identity.get("actual_runtime")
    if actual_runtime != "gemma_local_runtime":
        print(
            f"ROSS_SMOKE_GUARD_FAIL reason=runtime_identity_mismatch requested=gemma_local_runtime actual={actual_runtime}",
            file=sys.stderr,
        )
        sys.exit(1)

outcome = None
identity = None
pass_fields = None
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
        if pass_re.search(line):
            outcome = "pass"
            pass_fields = parse_fields(line)
            process.send_signal(signal.SIGINT)
            break
        if fail_re.search(line):
            outcome = "fail"
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
        print_benchmark_summary(identity, pass_fields)
    sys.exit(0)

if outcome == "fail":
    validate_identity_guard(identity, require_identity=False)
    sys.exit(1)

sys.exit(process.returncode or 1)
PY

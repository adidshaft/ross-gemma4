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

outcome = None
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
        if pass_re.search(line):
            outcome = "pass"
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
    sys.exit(0)

if outcome == "fail":
    sys.exit(1)

sys.exit(process.returncode or 1)
PY

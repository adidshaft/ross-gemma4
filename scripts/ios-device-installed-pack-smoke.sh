#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  scripts/ios-device-installed-pack-smoke.sh --device <udid> [options]

Options:
  --device <udid>         Physical iPhone UDID accepted by devicectl.
  --bundle-id <id>        App bundle identifier. Default: com.ross.ios
  --tier <tier>           quickStart | caseAssociate | seniorDraftingSupport | flash
  --pack-id <id>          Exact installed pack id to target.
  --runtime <mode>        gguf | mlx | coreai | gemma_local_runtime | mlx_swift_lm | apple_foundation_models
  --stage-timeout <sec>   Per-stage smoke timeout. Default: 45
  --list-only             Only list installed manifest-backed packs from the device.
  --allow-device-proof-pack
                          Allow packs whose id ends with -device-proof. By default
                          these seeded proof packs are excluded from real client-download smoke selection.

This helper:
  1. Resolves the Ross app container on the cabled device
  2. Copies installed model-pack manifests out of app-private storage
  3. Selects one installed pack by pack id / tier / runtime (or the only match)
  4. Launches Ross with --local-model-smoke against that installed on-device artifact
EOF
}

device_id=""
bundle_id="com.ross.ios"
selected_tier=""
selected_pack_id=""
selected_runtime=""
stage_timeout="45"
list_only="0"
allow_device_proof_pack="0"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --device)
      device_id="${2:-}"
      shift 2
      ;;
    --bundle-id)
      bundle_id="${2:-}"
      shift 2
      ;;
    --tier)
      selected_tier="${2:-}"
      shift 2
      ;;
    --pack-id)
      selected_pack_id="${2:-}"
      shift 2
      ;;
    --runtime)
      selected_runtime="${2:-}"
      shift 2
      ;;
    --stage-timeout)
      stage_timeout="${2:-}"
      shift 2
      ;;
    --list-only)
      list_only="1"
      shift 1
      ;;
    --allow-device-proof-pack)
      allow_device_proof_pack="1"
      shift 1
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

if [[ -z "$device_id" ]]; then
  usage >&2
  exit 2
fi

if ! command -v xcrun >/dev/null 2>&1; then
  echo "xcrun is required." >&2
  exit 2
fi

tmpdir="$(mktemp -d /tmp/ross-ios-device-installed-pack-smoke.XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT

probe_dir="$tmpdir/probe"
mkdir -p "$probe_dir/Library/Application Support/RossAlpha"
probe_file="$probe_dir/Library/Application Support/RossAlpha/.device-proof-probe"
printf 'ross-device-proof\n' > "$probe_file"

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
echo "Resolved app container root: $container_root"

file_listing_json="$tmpdir/model-pack-files.json"
xcrun devicectl device info files \
  --device "$device_id" \
  --domain-type appDataContainer \
  --domain-identifier "$bundle_id" \
  --subdirectory 'Library/Application Support/RossAlpha' \
  --search manifest.json \
  --json-output "$file_listing_json" \
  > /dev/null

manifest_paths_file="$tmpdir/manifest-paths.txt"
python3 - "$file_listing_json" "$manifest_paths_file" <<'PY'
import json
import sys

payload = json.loads(open(sys.argv[1]).read())
paths = [
    file_entry.get("relativePath", "")
    for file_entry in payload.get("result", {}).get("files", [])
    if file_entry.get("relativePath", "").endswith(".manifest.json")
]
with open(sys.argv[2], "w") as handle:
    for path in sorted(set(paths)):
        if path:
            handle.write(path + "\n")
PY

if [[ ! -s "$manifest_paths_file" ]]; then
  echo "No manifest-backed model packs were listed from the device." >&2
  exit 1
fi

copied_model_packs="$tmpdir/model-packs"
while IFS= read -r manifest_relative_path; do
  [[ -n "$manifest_relative_path" ]] || continue
  target_path="$copied_model_packs/$manifest_relative_path"
  mkdir -p "$(dirname "$target_path")"
  xcrun devicectl device copy from \
    --device "$device_id" \
    --domain-type appDataContainer \
    --domain-identifier "$bundle_id" \
    --source "Library/Application Support/RossAlpha/$manifest_relative_path" \
    --destination "$target_path" \
    > /dev/null
done < "$manifest_paths_file"

selection_json="$tmpdir/selected-pack.json"
python3 - "$copied_model_packs" "$selection_json" "$list_only" "$allow_device_proof_pack" "$selected_tier" "$selected_pack_id" "$selected_runtime" <<'PY'
import json
import sys
from pathlib import Path

copied_root = Path(sys.argv[1])
selection_json = Path(sys.argv[2])
list_only = sys.argv[3] == "1"
allow_device_proof_pack = sys.argv[4] == "1"
selected_tier = sys.argv[5].strip()
selected_pack_id = sys.argv[6].strip()
selected_runtime = sys.argv[7].strip()

tier_aliases = {
    "flash": "flash",
    "quickStart": "quick_start",
    "quick_start": "quick_start",
    "caseAssociate": "case_associate",
    "case_associate": "case_associate",
    "seniorDraftingSupport": "senior_drafting_support",
    "senior_drafting_support": "senior_drafting_support",
}
runtime_aliases = {
    "gguf": "gemma_local_runtime",
    "gemma_local_runtime": "gemma_local_runtime",
    "mlx": "mlx_swift_lm",
    "mlx_swift_lm": "mlx_swift_lm",
    "coreai": "apple_foundation_models",
    "apple_foundation_models": "apple_foundation_models",
}

def normalize_tier(value: str) -> str:
    if not value:
        return ""
    return tier_aliases.get(value, value)

def normalize_runtime(value: str) -> str:
    if not value:
        return ""
    return runtime_aliases.get(value, value)

normalized_tier = normalize_tier(selected_tier)
normalized_runtime = normalize_runtime(selected_runtime)

records = []
for manifest_path in copied_root.rglob("*.manifest.json"):
    try:
        payload = json.loads(manifest_path.read_text())
    except Exception:
        continue
    records.append({
        "packId": payload.get("packId"),
        "tier": payload.get("tier"),
        "fileName": payload.get("fileName"),
        "relativePath": payload.get("relativePath"),
        "checksumSha256": payload.get("checksumSha256"),
        "bytes": payload.get("bytes"),
        "artifactKind": payload.get("artifactKind"),
        "runtimeMode": payload.get("runtimeMode"),
        "developmentOnly": bool(payload.get("developmentOnly")),
        "verifiedAt": payload.get("verifiedAt"),
        "draftArtifact": payload.get("draftArtifact"),
        "manifestPath": str(manifest_path),
    })

records.sort(key=lambda item: (item.get("tier") or "", item.get("packId") or "", item.get("fileName") or ""))

if not records:
    print("No installed manifest-backed model packs were found in RossAlpha/model-packs.", file=sys.stderr)
    sys.exit(1)

print("Installed manifest-backed model packs:")
for index, record in enumerate(records, start=1):
    size_gb = f"{(record.get('bytes') or 0) / 1_000_000_000:.2f} GB"
    dev_suffix = " dev" if record.get("developmentOnly") else ""
    seeded_suffix = " seeded-device-proof" if (record.get("packId") or "").endswith("-device-proof") else ""
    draft = record.get("draftArtifact") or {}
    draft_suffix = f" draft={draft.get('fileName')}" if draft.get("fileName") else ""
    print(
        f"  [{index}] tier={record.get('tier')} pack={record.get('packId')} runtime={record.get('runtimeMode')} "
        f"file={record.get('fileName')} size={size_gb}{dev_suffix}{seeded_suffix}{draft_suffix}"
    )

if list_only:
    sys.exit(0)

matches = []
excluded_device_proof_matches = []
for record in records:
    record_tier = normalize_tier(record.get("tier") or "")
    record_runtime = normalize_runtime(record.get("runtimeMode") or "")
    if normalized_tier and record_tier != normalized_tier:
        continue
    if selected_pack_id and record.get("packId") != selected_pack_id:
        continue
    if normalized_runtime and record_runtime != normalized_runtime:
        continue
    if not allow_device_proof_pack and (record.get("packId") or "").endswith("-device-proof"):
        excluded_device_proof_matches.append(record)
        continue
    matches.append(record)

if not matches:
    if excluded_device_proof_matches:
        print("Only seeded device-proof manifests matched the requested selectors. Real client-download proof is still missing on this device unless you pass --allow-device-proof-pack.", file=sys.stderr)
        for record in excluded_device_proof_matches:
            print(
                f"  tier={record.get('tier')} pack={record.get('packId')} runtime={record.get('runtimeMode')} file={record.get('fileName')}",
                file=sys.stderr,
            )
        sys.exit(1)
    print("No installed pack matched the requested selectors.", file=sys.stderr)
    sys.exit(1)

if len(matches) > 1:
    print("Multiple installed packs matched the requested selectors. Re-run with --pack-id for an exact choice.", file=sys.stderr)
    for record in matches:
        print(
            f"  tier={record.get('tier')} pack={record.get('packId')} runtime={record.get('runtimeMode')} file={record.get('fileName')}",
            file=sys.stderr,
        )
    sys.exit(1)

selection_json.write_text(json.dumps(matches[0], indent=2))
print(f"Selected pack: {matches[0]['packId']} ({matches[0]['tier']} / {matches[0]['runtimeMode']})")
PY

if [[ "$list_only" == "1" ]]; then
  exit 0
fi

selected_pack_id="$(python3 - "$selection_json" <<'PY'
import json
import sys
print(json.loads(open(sys.argv[1]).read())["packId"])
PY
)"
selected_tier_raw="$(python3 - "$selection_json" <<'PY'
import json
import sys
print(json.loads(open(sys.argv[1]).read())["tier"])
PY
)"
selected_runtime_raw="$(python3 - "$selection_json" <<'PY'
import json
import sys
print(json.loads(open(sys.argv[1]).read())["runtimeMode"])
PY
)"
selected_relative_path="$(python3 - "$selection_json" <<'PY'
import json
import sys
print(json.loads(open(sys.argv[1]).read())["relativePath"])
PY
)"
selected_checksum="$(python3 - "$selection_json" <<'PY'
import json
import sys
print(json.loads(open(sys.argv[1]).read())["checksumSha256"])
PY
)"
selected_artifact_kind="$(python3 - "$selection_json" <<'PY'
import json
import sys
print(json.loads(open(sys.argv[1]).read())["artifactKind"])
PY
)"
selected_draft_relative_path="$(python3 - "$selection_json" <<'PY'
import json
import sys
draft = json.loads(open(sys.argv[1]).read()).get("draftArtifact") or {}
print(draft.get("relativePath", ""))
PY
)"
selected_draft_tokens="$(python3 - "$selection_json" <<'PY'
import json
import sys
draft = json.loads(open(sys.argv[1]).read()).get("draftArtifact") or {}
value = draft.get("draftTokens")
print("" if value is None else value)
PY
)"

device_model_path="$container_root/Library/Application Support/RossAlpha/$selected_relative_path"
device_draft_path=""
if [[ -n "$selected_draft_relative_path" ]]; then
  device_draft_path="$container_root/Library/Application Support/RossAlpha/$selected_draft_relative_path"
fi

echo "Using installed pack path: $device_model_path"
if [[ -n "$device_draft_path" ]]; then
  echo "Using installed draft path: $device_draft_path"
fi

python3 - "$device_id" "$bundle_id" "$device_model_path" "$selected_checksum" "$selected_artifact_kind" "$selected_runtime_raw" "$selected_tier_raw" "$selected_pack_id" "$device_draft_path" "$selected_draft_tokens" "$stage_timeout" <<'PY'
import os
import re
import signal
import subprocess
import sys

(
    device_id,
    bundle_id,
    device_model_path,
    checksum,
    artifact_kind,
    runtime_mode,
    tier_raw,
    pack_id,
    draft_model_path,
    draft_model_tokens,
    stage_timeout,
) = sys.argv[1:]

env = os.environ.copy()
env.update(
    {
        "DEVICECTL_CHILD_ROSS_ENABLE_REAL_LOCAL_INFERENCE": "1",
        "DEVICECTL_CHILD_ROSS_LOCAL_RUNTIME": runtime_mode,
        "DEVICECTL_CHILD_ROSS_LOCAL_MODEL_PATH": device_model_path,
        "DEVICECTL_CHILD_ROSS_LOCAL_MODEL_CHECKSUM": checksum,
        "DEVICECTL_CHILD_ROSS_LOCAL_MODEL_KIND": artifact_kind,
        "DEVICECTL_CHILD_ROSS_LOCAL_MODEL_TIER": tier_raw,
        "DEVICECTL_CHILD_ROSS_LOCAL_MODEL_PACK_ID": pack_id,
        "DEVICECTL_CHILD_ROSS_LOCAL_MODEL_SMOKE_STAGE_TIMEOUT_SECONDS": stage_timeout,
    }
)
if draft_model_path:
    env["DEVICECTL_CHILD_ROSS_LOCAL_DRAFT_MODEL_PATH"] = draft_model_path
if draft_model_tokens:
    env["DEVICECTL_CHILD_ROSS_LOCAL_DRAFT_MODEL_TOKENS"] = draft_model_tokens

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

#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  cat <<'EOF'
Usage:
  scripts/ios-device-installed-pack-smoke.sh --device <udid> [options]

Options:
  --device <udid>         Physical iPhone UDID accepted by devicectl.
  --bundle-id <id>        App bundle identifier. Default: com.ross.ios
  --tier <tier>           quickStart | caseAssociate | seniorDraftingSupport | flash
  --pack-id <id>          Exact installed pack id to target.
  --runtime <mode>        gguf | mlx | coreai | coreml | gemma_local_runtime | mlx_swift_lm | apple_foundation_models
  --stage-timeout <sec>   Per-stage smoke timeout. Default: 45
  --launch-timeout <sec>  Overall helper timeout while waiting for a smoke marker. Default: 300
  --physical-memory-bytes <bytes>
                          Optional device memory used for pre-launch MTP memory-fit gating.
  --smoke-profile <mode>  full | quick | mtp | mtp-quick | mtp_quick. Default: full
  --disable-draft         Force standard acceleration even if the installed pack
                          has a usable draft companion.
  --require-draft-acceleration
                          Fail unless the app reports active draft speculative
                          acceleration with draft_status=active and draft metadata. Use for MTP proof.
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
launch_timeout="300"
physical_memory_bytes=""
smoke_profile="full"
disable_draft="0"
require_draft_acceleration="0"
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
    --launch-timeout)
      launch_timeout="${2:-}"
      shift 2
      ;;
    --physical-memory-bytes)
      physical_memory_bytes="${2:-}"
      shift 2
      ;;
    --smoke-profile)
      smoke_profile="${2:-}"
      shift 2
      ;;
    --disable-draft)
      disable_draft="1"
      shift 1
      ;;
    --require-draft-acceleration)
      require_draft_acceleration="1"
      shift 1
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

case "$smoke_profile" in
  full|quick|mtp|mtp-quick|mtp_quick)
    ;;
  *)
    echo "Unsupported smoke profile: $smoke_profile" >&2
    usage >&2
    exit 2
    ;;
esac

if [[ -z "$stage_timeout" || "$stage_timeout" == *[!0-9]* || "$stage_timeout" -le 0 ]]; then
  echo "Stage timeout must be a positive integer number of seconds." >&2
  exit 2
fi

if [[ -z "$launch_timeout" || "$launch_timeout" == *[!0-9]* || "$launch_timeout" -le 0 ]]; then
  echo "Launch timeout must be a positive integer number of seconds." >&2
  exit 2
fi

if [[ -n "$physical_memory_bytes" && ( "$physical_memory_bytes" == *[!0-9]* || "$physical_memory_bytes" -le 0 ) ]]; then
  echo "Physical memory bytes must be a positive integer." >&2
  exit 2
fi

if [[ "$require_draft_acceleration" == "1" ]]; then
  if [[ "$disable_draft" == "1" ]]; then
    echo "Draft acceleration proof cannot be combined with --disable-draft." >&2
    exit 2
  fi
  case "$smoke_profile" in
    mtp|mtp-quick|mtp_quick)
      ;;
    *)
      echo "Draft acceleration proof requires --smoke-profile mtp_quick/mtp-quick/mtp so MTP validation stays low-token and low-context." >&2
      exit 2
      ;;
  esac
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
    "coreml": "apple_foundation_models",
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
selected_bytes="$(python3 - "$selection_json" <<'PY'
import json
import sys
value = json.loads(open(sys.argv[1]).read()).get("bytes")
print("" if value is None else value)
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
selected_draft_artifact_kind="$(python3 - "$selection_json" <<'PY'
import json
import sys
draft = json.loads(open(sys.argv[1]).read()).get("draftArtifact") or {}
print(draft.get("artifactKind", ""))
PY
)"
selected_draft_bytes="$(python3 - "$selection_json" <<'PY'
import json
import sys
draft = json.loads(open(sys.argv[1]).read()).get("draftArtifact") or {}
value = draft.get("bytes")
print("" if value is None else value)
PY
)"

python3 - "$selected_runtime_raw" "$selected_artifact_kind" "$selected_relative_path" "$selected_bytes" <<'PY'
import sys

runtime = (sys.argv[1] or "").strip()
artifact_kind = (sys.argv[2] or "").strip()
relative_path = (sys.argv[3] or "").strip()
raw_bytes = (sys.argv[4] or "").strip()
try:
    artifact_bytes = int(raw_bytes) if raw_bytes else 0
except ValueError:
    artifact_bytes = 0

allowed_artifact_kinds = {
    "gemma_local_runtime": {"local_model_artifact", "gguf", "gguf_model"},
    "mlx_swift_lm": {"mlx_directory"},
    "apple_foundation_models": {"system_model", "foundation_adapter", "coreai_adapter", "coreml_model"},
}

allowed = allowed_artifact_kinds.get(runtime)
if allowed is not None and artifact_kind not in allowed:
    print(
        "Selected manifest has an incompatible artifact kind for the requested runtime: "
        f"runtime={runtime} artifactKind={artifact_kind} relativePath={relative_path}",
        file=sys.stderr,
    )
    sys.exit(1)

if runtime == "gemma_local_runtime":
    if not relative_path.lower().endswith(".gguf"):
        print(
            "Selected GGUF manifest points at a non-GGUF artifact: "
            f"relativePath={relative_path}",
            file=sys.stderr,
        )
        sys.exit(1)
    if artifact_bytes <= 1_000_000:
        print(
            "Selected GGUF manifest reports an implausibly small artifact for device smoke: "
            f"bytes={artifact_bytes} relativePath={relative_path}",
            file=sys.stderr,
        )
        sys.exit(1)

if runtime == "apple_foundation_models":
    uses_system_sentinel = relative_path == "system-model" or relative_path.startswith("system://")
    if artifact_kind == "system_model" and not uses_system_sentinel:
        print(
            "Selected CoreAI/CoreML manifest uses artifactKind=system_model only with system-model/system:// paths: "
            f"relativePath={relative_path}",
            file=sys.stderr,
        )
        sys.exit(1)
    if artifact_kind != "system_model" and uses_system_sentinel:
        print(
            "Selected CoreAI/CoreML adapter manifest points at the system model sentinel: "
            f"artifactKind={artifact_kind} relativePath={relative_path}",
            file=sys.stderr,
        )
        sys.exit(1)
    if artifact_kind != "system_model" and relative_path.lower().endswith((".gguf", ".safetensors", ".bin")):
        print(
            "Selected CoreAI/CoreML adapter manifest points at a foreign model artifact: "
            f"artifactKind={artifact_kind} relativePath={relative_path}",
            file=sys.stderr,
        )
        sys.exit(1)
    if artifact_kind != "system_model" and artifact_bytes <= 0:
        print(
            "Selected CoreAI/CoreML adapter manifest reports an empty artifact for device smoke: "
            f"artifactKind={artifact_kind} bytes={artifact_bytes} relativePath={relative_path}",
            file=sys.stderr,
        )
        sys.exit(1)

if runtime == "mlx_swift_lm" and relative_path.lower().endswith((".gguf", ".bin")):
    print(
        "Selected MLX manifest points at a file-like model artifact instead of an MLX directory: "
        f"relativePath={relative_path}",
        file=sys.stderr,
    )
    sys.exit(1)

if runtime == "mlx_swift_lm" and artifact_bytes <= 1_000_000:
    print(
        "Selected MLX manifest reports an implausibly small artifact for device smoke: "
        f"bytes={artifact_bytes} relativePath={relative_path}",
        file=sys.stderr,
    )
    sys.exit(1)
PY

if [[ "$require_draft_acceleration" == "1" ]]; then
  if [[ "$selected_runtime_raw" == "apple_foundation_models" ]]; then
    echo "Draft acceleration proof is only supported for GGUF/MLX installed packs, not apple_foundation_models." >&2
    echo "Selected pack: $selected_pack_id runtime=$selected_runtime_raw tier=$selected_tier_raw" >&2
    exit 1
  fi

  if [[ -z "$selected_draft_relative_path" ]]; then
    echo "Draft acceleration proof requires the selected installed manifest to include draftArtifact.relativePath." >&2
    echo "Selected pack: $selected_pack_id runtime=$selected_runtime_raw tier=$selected_tier_raw" >&2
    exit 1
  fi

  python3 - "$selected_runtime_raw" "$selected_draft_artifact_kind" "$selected_draft_relative_path" "$selected_draft_bytes" "$selected_pack_id" "$selected_tier_raw" <<'PY'
import sys

runtime = (sys.argv[1] or "").strip()
draft_artifact_kind = (sys.argv[2] or "").strip()
draft_relative_path = (sys.argv[3] or "").strip()
raw_draft_bytes = (sys.argv[4] or "").strip()
pack_id = (sys.argv[5] or "").strip()
tier = (sys.argv[6] or "").strip()
try:
    draft_bytes = int(raw_draft_bytes) if raw_draft_bytes else 0
except ValueError:
    draft_bytes = 0

allowed_draft_kinds = {
    "gemma_local_runtime": {"local_model_artifact", "gguf", "gguf_model"},
    "mlx_swift_lm": {"mlx_directory"},
}

allowed = allowed_draft_kinds.get(runtime)
if allowed is None:
    print(
        "Draft acceleration proof is only supported for GGUF/MLX installed packs: "
        f"runtime={runtime} pack={pack_id} tier={tier}",
        file=sys.stderr,
    )
    sys.exit(1)

if draft_artifact_kind not in allowed:
    print(
        "Selected manifest has an incompatible draft artifact kind for draft acceleration proof: "
        f"runtime={runtime} draftArtifact.artifactKind={draft_artifact_kind or 'nil'} "
        f"draftArtifact.relativePath={draft_relative_path} pack={pack_id} tier={tier}",
        file=sys.stderr,
    )
    sys.exit(1)

if runtime == "mlx_swift_lm" and draft_relative_path.lower().endswith((".gguf", ".bin")):
    print(
        "Selected MLX manifest points its draft companion at a file-like artifact instead of an MLX directory: "
        f"draftArtifact.relativePath={draft_relative_path} pack={pack_id} tier={tier}",
        file=sys.stderr,
    )
    sys.exit(1)

if runtime == "mlx_swift_lm" and draft_bytes <= 1_000_000:
    print(
        "Selected MLX manifest reports an implausibly small draft artifact for device smoke: "
        f"draftArtifact.bytes={draft_bytes} draftArtifact.relativePath={draft_relative_path} pack={pack_id} tier={tier}",
        file=sys.stderr,
    )
    sys.exit(1)

if runtime == "gemma_local_runtime" and not draft_relative_path.lower().endswith(".gguf"):
    print(
        "Selected GGUF/MTP manifest points its draft companion at a non-GGUF artifact: "
        f"draftArtifact.relativePath={draft_relative_path} pack={pack_id} tier={tier}",
        file=sys.stderr,
    )
    sys.exit(1)

if runtime == "gemma_local_runtime" and draft_bytes <= 1_000_000:
    print(
        "Selected GGUF/MTP manifest reports an implausibly small draft artifact for device smoke: "
        f"draftArtifact.bytes={draft_bytes} draftArtifact.relativePath={draft_relative_path} pack={pack_id} tier={tier}",
        file=sys.stderr,
    )
    sys.exit(1)
PY

  if [[ -n "$physical_memory_bytes" && "$selected_runtime_raw" == "gemma_local_runtime" ]]; then
    python3 - "$selected_relative_path" "$selected_bytes" "$selected_draft_relative_path" "$selected_draft_bytes" "$physical_memory_bytes" "$selected_pack_id" "$selected_tier_raw" <<'PY'
import sys

primary_path = (sys.argv[1] or "").strip()
draft_path = (sys.argv[3] or "").strip()
pack_id = (sys.argv[6] or "").strip()
tier = (sys.argv[7] or "").strip()
try:
    primary_bytes = int(sys.argv[2])
    draft_bytes = int(sys.argv[4])
    physical_memory = int(sys.argv[5])
except ValueError:
    sys.exit(0)

constrained_e4b_memory_ceiling = 8_500_000_000
constrained_e4b_draft_artifact_budget_ratio = 0.72
is_e4b = "e4b" in primary_path.lower()
if not is_e4b or physical_memory >= constrained_e4b_memory_ceiling:
    sys.exit(0)

max_combined_bytes = int(physical_memory * constrained_e4b_draft_artifact_budget_ratio)
if primary_bytes + draft_bytes > max_combined_bytes:
    print(
        "Selected GGUF/MTP manifest exceeds the constrained E4B draft memory budget for device smoke: "
        f"main_bytes={primary_bytes} draft_bytes={draft_bytes} "
        f"max_combined_bytes={max_combined_bytes} physical_memory={physical_memory} "
        f"primary={primary_path} draft={draft_path} pack={pack_id} tier={tier}",
        file=sys.stderr,
    )
    sys.exit(1)
PY
  fi
fi

device_model_path="$container_root/Library/Application Support/RossAlpha/$selected_relative_path"
device_draft_path=""
if [[ -n "$selected_draft_relative_path" ]]; then
  device_draft_path="$container_root/Library/Application Support/RossAlpha/$selected_draft_relative_path"
fi

device_relative_path_exists() {
  local relative_path="$1"
  local search_name
  search_name="$(basename "$relative_path")"
  local existence_json="$tmpdir/existence-$(printf '%s' "$relative_path" | tr '/ ' '__').json"

  xcrun devicectl device info files \
    --device "$device_id" \
    --domain-type appDataContainer \
    --domain-identifier "$bundle_id" \
    --subdirectory 'Library/Application Support/RossAlpha' \
    --search "$search_name" \
    --json-output "$existence_json" \
    > /dev/null

  python3 - "$existence_json" "$relative_path" <<'PY'
import json
import sys

payload = json.loads(open(sys.argv[1]).read())
target = sys.argv[2].strip().strip("/")
for file_entry in payload.get("result", {}).get("files", []):
    relative = (file_entry.get("relativePath") or "").strip().strip("/")
    if relative == target or relative.startswith(target + "/"):
        sys.exit(0)
sys.exit(1)
PY
}

device_relative_directory_has_named_file() {
  local relative_path="$1"
  local search_name="$2"
  local existence_json="$tmpdir/dir-file-$(printf '%s-%s' "$relative_path" "$search_name" | tr '/ ' '__').json"

  xcrun devicectl device info files \
    --device "$device_id" \
    --domain-type appDataContainer \
    --domain-identifier "$bundle_id" \
    --subdirectory 'Library/Application Support/RossAlpha' \
    --search "$search_name" \
    --json-output "$existence_json" \
    > /dev/null

  python3 - "$existence_json" "$relative_path" "$search_name" <<'PY'
import json
import sys

payload = json.loads(open(sys.argv[1]).read())
target = sys.argv[2].strip().strip("/")
search_name = sys.argv[3]
for file_entry in payload.get("result", {}).get("files", []):
    relative = (file_entry.get("relativePath") or "").strip().strip("/")
    if relative.startswith(target + "/") and relative.endswith("/" + search_name):
        sys.exit(0)
sys.exit(1)
PY
}

device_relative_directory_has_suffix_file() {
  local relative_path="$1"
  local suffix="$2"
  local existence_json="$tmpdir/dir-suffix-$(printf '%s-%s' "$relative_path" "$suffix" | tr '/ ' '__').json"

  xcrun devicectl device info files \
    --device "$device_id" \
    --domain-type appDataContainer \
    --domain-identifier "$bundle_id" \
    --subdirectory 'Library/Application Support/RossAlpha' \
    --search "$suffix" \
    --json-output "$existence_json" \
    > /dev/null

  python3 - "$existence_json" "$relative_path" "$suffix" <<'PY'
import json
import sys

payload = json.loads(open(sys.argv[1]).read())
target = sys.argv[2].strip().strip("/")
suffix = sys.argv[3]
for file_entry in payload.get("result", {}).get("files", []):
    relative = (file_entry.get("relativePath") or "").strip().strip("/")
    if relative.startswith(target + "/") and relative.endswith(suffix):
        sys.exit(0)
sys.exit(1)
PY
}

device_mlx_directory_looks_usable() {
  local relative_path="$1"
  device_relative_directory_has_named_file "$relative_path" "config.json" || return 1

  if ! device_relative_directory_has_named_file "$relative_path" "tokenizer.json" &&
     ! device_relative_directory_has_named_file "$relative_path" "tokenizer.model" &&
     ! device_relative_directory_has_named_file "$relative_path" "tokenizer_config.json"; then
    return 1
  fi

  device_relative_directory_has_suffix_file "$relative_path" ".safetensors" ||
    device_relative_directory_has_suffix_file "$relative_path" ".safetensors.index.json"
}

if [[ "$selected_artifact_kind" != "system_model" ]] && ! device_relative_path_exists "$selected_relative_path"; then
  echo "Installed artifact file is missing from the app container: $device_model_path" >&2
  echo "Selected pack: $selected_pack_id runtime=$selected_runtime_raw tier=$selected_tier_raw" >&2
  exit 1
fi

if [[ "$selected_runtime_raw" == "mlx_swift_lm" ]] && ! device_mlx_directory_looks_usable "$selected_relative_path"; then
  echo "Installed MLX artifact directory is missing required files: config.json, tokenizer metadata, and safetensors weights/index under $device_model_path" >&2
  echo "Selected pack: $selected_pack_id runtime=$selected_runtime_raw tier=$selected_tier_raw" >&2
  exit 1
fi

if [[ -n "$device_draft_path" ]] && ! device_relative_path_exists "$selected_draft_relative_path"; then
  echo "Installed draft artifact file is missing from the app container: $device_draft_path" >&2
  echo "Selected pack: $selected_pack_id runtime=$selected_runtime_raw tier=$selected_tier_raw" >&2
  exit 1
fi

if [[ "$require_draft_acceleration" == "1" && "$selected_runtime_raw" == "mlx_swift_lm" ]] &&
   ! device_mlx_directory_looks_usable "$selected_draft_relative_path"; then
  echo "Installed MLX draft artifact directory is missing required files: config.json, tokenizer metadata, and safetensors weights/index under $device_draft_path" >&2
  echo "Selected pack: $selected_pack_id runtime=$selected_runtime_raw tier=$selected_tier_raw" >&2
  exit 1
fi

echo "Using installed pack path: $device_model_path"
if [[ -n "$device_draft_path" ]]; then
  echo "Using installed draft path: $device_draft_path"
fi

python3 - "$device_id" "$bundle_id" "$device_model_path" "$selected_checksum" "$selected_artifact_kind" "$selected_runtime_raw" "$selected_tier_raw" "$selected_pack_id" "$device_draft_path" "$selected_draft_tokens" "$stage_timeout" "$launch_timeout" "$smoke_profile" "$disable_draft" "$require_draft_acceleration" "$SCRIPT_DIR" <<'PY'
import os
import re
import signal
import select
import subprocess
import sys
import time

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
    runtime_identity_draft_artifact_error,
    runtime_identity_resource_error,
)

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
    launch_timeout,
    smoke_profile,
    disable_draft,
    require_draft_acceleration,
) = sys.argv[1:-1]

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
        "DEVICECTL_CHILD_ROSS_LOCAL_MODEL_SMOKE_PROFILE": smoke_profile,
    }
)
if draft_model_path:
    env["DEVICECTL_CHILD_ROSS_LOCAL_DRAFT_MODEL_PATH"] = draft_model_path
if draft_model_tokens:
    env["DEVICECTL_CHILD_ROSS_LOCAL_DRAFT_MODEL_TOKENS"] = draft_model_tokens
if disable_draft == "1":
    env["DEVICECTL_CHILD_ROSS_LOCAL_DISABLE_DRAFT_ACCELERATION"] = "1"
if require_draft_acceleration == "1":
    env["DEVICECTL_CHILD_ROSS_LOCAL_MODEL_SMOKE_REQUIRE_DRAFT_ACCELERATION"] = "1"

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
    if actual_runtime != runtime_mode or requested_runtime not in (runtime_mode, "nil"):
        print(
            "ROSS_SMOKE_GUARD_FAIL "
            f"reason=runtime_identity_mismatch requested={runtime_mode} "
            f"identity_requested={requested_runtime} actual={actual_runtime}",
            file=sys.stderr,
        )
        sys.exit(1)
    pack_runtime = identity.get("pack_runtime")
    if pack_runtime not in (None, "nil", actual_runtime):
        print(
            "ROSS_SMOKE_GUARD_FAIL "
            f"reason=pack_runtime_mismatch requested={runtime_mode} "
            f"pack_runtime={pack_runtime} actual={actual_runtime}",
            file=sys.stderr,
        )
        sys.exit(1)

    if require_identity:
        if pack_runtime in (None, "nil", ""):
            print(
                "ROSS_SMOKE_GUARD_FAIL "
                f"reason=pack_runtime_missing requested={runtime_mode} actual={actual_runtime}",
                file=sys.stderr,
            )
            sys.exit(1)

        availability_error = runtime_identity_availability_error(identity)
        if availability_error:
            print(
                "ROSS_SMOKE_GUARD_FAIL "
                f"reason=runtime_identity_unavailable requested={runtime_mode} "
                f"{availability_error}",
                file=sys.stderr,
            )
            sys.exit(1)

        artifact_error = runtime_identity_artifact_error(identity, runtime_mode)
        if artifact_error:
            print(
                "ROSS_SMOKE_GUARD_FAIL "
                f"reason=runtime_identity_artifact_mismatch requested={runtime_mode} "
                f"{artifact_error}",
                file=sys.stderr,
            )
            sys.exit(1)

        resource_error = runtime_identity_resource_error(identity)
        if resource_error:
            print(
                "ROSS_SMOKE_GUARD_FAIL "
                f"reason=runtime_identity_resource_missing requested={runtime_mode} "
                f"{resource_error}",
                file=sys.stderr,
            )
            sys.exit(1)

        expected_artifact = (
            "system-model"
            if artifact_kind == "system_model"
            else os.path.basename(device_model_path.rstrip("/"))
        )
        identity_artifact = identity.get("artifact_path") or ""
        if artifact_kind == "system_model":
            if identity_artifact != "system-model" and not identity_artifact.startswith("system://"):
                print(
                    "ROSS_SMOKE_GUARD_FAIL "
                    f"reason=runtime_identity_artifact_path_mismatch requested={runtime_mode} "
                    f"expected_artifact=system-model identity_artifact={identity_artifact or 'nil'}",
                    file=sys.stderr,
                )
                sys.exit(1)
        elif os.path.basename(identity_artifact.rstrip("/")) != expected_artifact:
            print(
                "ROSS_SMOKE_GUARD_FAIL "
                f"reason=runtime_identity_artifact_path_mismatch requested={runtime_mode} "
                f"expected_artifact={expected_artifact} "
                f"identity_artifact={os.path.basename(identity_artifact.rstrip('/')) or 'nil'}",
                file=sys.stderr,
            )
            sys.exit(1)

    if require_draft_acceleration == "1":
        acceleration = identity.get("acceleration")
        draft_tokens = identity.get("draft_tokens")
        draft_model = identity.get("draft_model")
        draft_model_path_type = identity.get("draft_model_path_type")
        draft_status = identity.get("draft_status")
        draft_artifact_error = runtime_identity_draft_artifact_error(identity, runtime_mode)
        if acceleration != "draftModelSpeculative" or draft_artifact_error:
            print(
                "ROSS_SMOKE_GUARD_FAIL reason=draft_acceleration_inactive "
                f"acceleration={acceleration} draft_tokens={draft_tokens} "
                f"draft_model={draft_model} draft_model_path_type={draft_model_path_type} "
                f"draft_status={draft_status} draft_artifact_error={draft_artifact_error or 'nil'}",
                file=sys.stderr,
            )
            sys.exit(1)

outcome = None
identity = None
matrix_fields = None
pass_fields = None
fail_fields = None
completed_stage_fields = {}
deadline = time.time() + max(float(launch_timeout), 1.0)
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
    while True:
        if time.time() > deadline:
            outcome = "timeout"
            print(f"ROSS_SMOKE_GUARD_FAIL reason=helper_timeout timeout={launch_timeout}", flush=True)
            fail_fields = {
                "runtime": runtime_mode,
                "requested_runtime": runtime_mode,
                "profile": smoke_profile,
                "stage": "helper_timeout",
                "error": "helper_timeout",
                **completed_stage_fields,
            }
            process.kill()
            break
        ready, _, _ = select.select([process.stdout], [], [], 0.2)
        if not ready:
            if process.poll() is not None:
                break
            continue
        raw_line = process.stdout.readline()
        if raw_line == "":
            if process.poll() is not None:
                break
            continue
        line = raw_line.rstrip("\n")
        print(line, flush=True)
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
            pass_fields = parse_fields(line)
            process.send_signal(signal.SIGINT)
            break
        if fail_re.search(line):
            outcome = "fail"
            fail_fields = parse_fields(line)
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
if outcome == "timeout":
    validate_identity_guard(identity, require_identity=False)
    print(failure_summary_line(identity, fail_fields, matrix_fields))
    sys.exit(1)
print(f"ROSS_SMOKE_GUARD_FAIL reason=no_terminal_smoke_marker outcome={outcome}", file=sys.stderr)
sys.exit(process.returncode or 1)
PY

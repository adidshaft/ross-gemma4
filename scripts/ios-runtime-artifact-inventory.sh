#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

usage() {
  cat <<'EOF'
Usage:
  scripts/ios-runtime-artifact-inventory.sh [--search-root <path>]... [--installed-root <path>]... [--physical-memory-bytes <bytes>]

Scans local filesystem paths for benchmarkable iOS runtime artifacts without
launching Simulator, devicectl, or the app. Results are advisory preflight
evidence only; generation proof still requires a guarded smoke pass.

Use --installed-root with either a RossAlpha support root or its model-packs
directory to inspect manifest-backed installed packs before a device smoke.
Use --physical-memory-bytes to apply advisory installed MTP memory-fit checks
that mirror the app's constrained E4B draft activation policy.
EOF
}

search_roots=()
installed_roots=()
physical_memory_bytes=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --search-root)
      search_roots+=("${2:-}")
      shift 2
      ;;
    --installed-root)
      installed_roots+=("${2:-}")
      shift 2
      ;;
    --physical-memory-bytes)
      physical_memory_bytes="${2:-}"
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

if [[ -n "$physical_memory_bytes" && ( "$physical_memory_bytes" == *[!0-9]* || "$physical_memory_bytes" -le 0 ) ]]; then
  echo "Physical memory bytes must be a positive integer." >&2
  exit 2
fi

if [[ "${#search_roots[@]}" -eq 0 ]]; then
  search_roots=(
    "$ROOT_DIR/artifacts"
    "$HOME/model-artifacts"
  )
fi

file_size_bytes() {
  stat -f%z "$1" 2>/dev/null || stat -c%s "$1" 2>/dev/null || echo 0
}

gguf_file_looks_usable() {
  local file="$1"
  [[ -f "$file" ]] || return 1
  local size
  size="$(file_size_bytes "$file")"
  [[ "$size" =~ ^[0-9]+$ ]] || return 1
  [[ "$size" -gt 1000000 ]] || return 1
  [[ "$(LC_ALL=C dd if="$file" bs=4 count=1 2>/dev/null)" == "GGUF" ]]
}

gguf_path_is_draft_like() {
  local path="$1"
  local lower_path
  lower_path="$(printf '%s' "$path" | tr '[:upper:]' '[:lower:]')"
  case "$lower_path" in
    *mtp*|*draft*|*assistant*)
      return 0
      ;;
  esac
  return 1
}

mlx_path_is_draft_like() {
  local path="$1"
  local lower_path
  lower_path="$(printf '%s' "$path" | tr '[:upper:]' '[:lower:]')"
  case "$lower_path" in
    *mtp*|*draft*|*assistant*)
      return 0
      ;;
  esac
  return 1
}

mlx_directory_looks_usable() {
  local directory="$1"
  [[ -d "$directory" ]] || return 1
  [[ -f "$directory/config.json" ]] || return 1

  if [[ ! -f "$directory/tokenizer.json" && ! -f "$directory/tokenizer.model" && ! -f "$directory/tokenizer_config.json" ]]; then
    return 1
  fi

  find "$directory" -maxdepth 3 -type f \( -name '*.safetensors' -o -name '*.safetensors.index.json' \) -size +0c -print -quit | grep -q .
}

coreai_adapter_looks_usable() {
  local path="$1"
  local lower_path
  lower_path="$(printf '%s' "$path" | tr '[:upper:]' '[:lower:]')"
  case "$lower_path" in
    *.gguf|*.safetensors|*.bin)
      return 1
      ;;
  esac
  if [[ -f "$path" ]]; then
    local size
    size="$(file_size_bytes "$path")"
    [[ "$size" =~ ^[0-9]+$ ]] || return 1
    [[ "$size" -gt 0 ]]
    return
  fi

  [[ -d "$path" ]] || return 1
  if [[ -f "$path/config.json" ]] &&
     find "$path" -maxdepth 3 -type f \( -name '*.safetensors' -o -name '*.safetensors.index.json' \) -size +0c -print -quit 2>/dev/null | grep -q .; then
    return 1
  fi
  find "$path" -type f -size +0c -print -quit 2>/dev/null | grep -q .
}

first_usable_gguf=""
first_draft_like_gguf=""
first_usable_mlx=""
first_draft_like_mlx=""
first_coreai_adapter=""

for root in "${search_roots[@]}"; do
  [[ -n "$root" && -e "$root" ]] || continue

  while IFS= read -r gguf_path; do
    if gguf_file_looks_usable "$gguf_path"; then
      if gguf_path_is_draft_like "$gguf_path"; then
        [[ -n "$first_draft_like_gguf" ]] || first_draft_like_gguf="$gguf_path"
      else
        [[ -n "$first_usable_gguf" ]] || first_usable_gguf="$gguf_path"
      fi
    fi
  done < <(find "$root" -maxdepth 5 -type f -name '*.gguf' -print 2>/dev/null)

  while IFS= read -r config_path; do
    candidate_dir="$(dirname "$config_path")"
    if mlx_directory_looks_usable "$candidate_dir"; then
      if mlx_path_is_draft_like "$candidate_dir"; then
        [[ -n "$first_draft_like_mlx" ]] || first_draft_like_mlx="$candidate_dir"
      else
        [[ -n "$first_usable_mlx" ]] || first_usable_mlx="$candidate_dir"
      fi
    fi
  done < <(find "$root" -maxdepth 5 -type f -name config.json -print 2>/dev/null)

  while IFS= read -r adapter_path; do
    if coreai_adapter_looks_usable "$adapter_path"; then
      [[ -n "$first_coreai_adapter" ]] || first_coreai_adapter="$adapter_path"
    fi
  done < <(find "$root" -maxdepth 5 \( -type d \( -name '*.mlmodelc' -o -name '*.mlpackage' \) -o -type f \( -name '*.mlmodel' -o -name '*.mlpackage' \) \) -print 2>/dev/null)
done

print_present_or_missing() {
  local lane="$1"
  local path="$2"
  local present_reason="$3"
  local missing_reason="$4"

  if [[ -n "$path" ]]; then
    printf 'ROSS_RUNTIME_ARTIFACT_INVENTORY lane=%s status=present path=%q reason=%s\n' "$lane" "$path" "$present_reason"
  else
    printf 'ROSS_RUNTIME_ARTIFACT_INVENTORY lane=%s status=missing path=nil reason=%s\n' "$lane" "$missing_reason"
  fi
}

print_present_or_missing \
  "gguf" \
  "$first_usable_gguf" \
  "usable_primary_gguf_file" \
  "no_primary_gguf_file_with_header_and_size_over_1mb"

print_present_or_missing \
  "mtp_draft" \
  "$first_draft_like_gguf" \
  "draft_like_gguf_candidate" \
  "no_draft_like_gguf_filename_found"

print_present_or_missing \
  "mlx" \
  "$first_usable_mlx" \
  "usable_mlx_directory" \
  "no_directory_with_config_tokenizer_and_safetensors"

print_present_or_missing \
  "mlx_draft" \
  "$first_draft_like_mlx" \
  "draft_like_mlx_directory" \
  "no_draft_like_mlx_directory_found"

print_present_or_missing \
  "coreai_adapter" \
  "$first_coreai_adapter" \
  "coreai_adapter_candidate" \
  "no_mlmodel_or_mlmodelc_adapter_found"

printf 'ROSS_RUNTIME_ARTIFACT_INVENTORY lane=coreai_system status=unknown path=system-model reason=requires_os_runtime_availability_and_generation_smoke runtime=apple_foundation_models artifact_kind=system_model preflight_hint=simulator_system_model_preflight\n'

python3 - "$ROOT_DIR/ios/Ross/AlphaFoundation/AlphaRossModel.swift" "$ROOT_DIR/ios/Ross/AlphaFoundation/AlphaRossModel+PrivateAI.swift" <<'PY'
import re
import shlex
import sys

catalog_path = sys.argv[1]
private_ai_path = sys.argv[2]

def q(value: str) -> str:
    return shlex.quote(value)

try:
    source = open(catalog_path, encoding="utf-8").read()
except OSError:
    sys.exit(0)

artifact_pattern = re.compile(
    r"(?P<tier>\.\w+):\s*AlphaAssistantModelArtifact\((?P<body>.*?)(?=\n\s*\.\w+:\s*AlphaAssistantModelArtifact\(|\n\])",
    re.DOTALL,
)

def field(body: str, name: str) -> str | None:
    match = re.search(rf"{re.escape(name)}:\s*\"([^\"]+)\"", body)
    return match.group(1) if match else None

def enum_field(body: str, name: str) -> str | None:
    match = re.search(rf"{re.escape(name)}:\s*\.([A-Za-z0-9_]+)", body)
    return match.group(1) if match else None

def int_field(body: str, name: str) -> str | None:
    match = re.search(rf"{re.escape(name)}:\s*([0-9_]+)", body)
    return match.group(1).replace("_", "") if match else None

def hf_repo_id(url: str) -> str:
    match = re.search(r"huggingface\.co/([^/]+/[^/?#]+)", url)
    return match.group(1) if match else "unknown"

for artifact_match in artifact_pattern.finditer(source):
    body = artifact_match.group("body")
    draft_index = body.find("draftArtifact: AlphaAssistantDraftArtifactDescriptor(")
    if draft_index < 0:
        continue
    draft_body = body[draft_index:]
    tier = enum_field(body, "tier") or artifact_match.group("tier").lstrip(".")
    pack = field(body, "packId") or "unknown"
    runtime = enum_field(body, "runtimeMode") or "llamaCppGguf"
    draft_file = field(draft_body, "fileName") or "unknown"
    draft_url = field(draft_body, "downloadURLString") or "nil"
    draft_bytes = int_field(draft_body, "sizeBytes") or "nil"
    draft_checksum = field(draft_body, "checksumSha256") or "nil"
    draft_kind = field(draft_body, "artifactKind") or "nil"
    print(
        "ROSS_RUNTIME_ARTIFACT_INVENTORY "
        f"lane=catalog_mtp_draft status=expected path={q(draft_url)} "
        "reason=configured_catalog_draft "
        f"tier={q(tier)} pack={q(pack)} runtime={q(runtime)} file={q(draft_file)} "
        f"artifact_kind={q(draft_kind)} bytes={q(draft_bytes)} checksum={q(draft_checksum)}"
    )

try:
    private_ai_source = open(private_ai_path, encoding="utf-8").read()
except OSError:
    private_ai_source = ""

download_descriptor_pattern = re.compile(
    r"AlphaAssistantDownloadDescriptor\((?P<body>.*?)(?=\n\))",
    re.DOTALL,
)

for descriptor_match in download_descriptor_pattern.finditer(private_ai_source):
    body = descriptor_match.group("body")
    runtime = enum_field(body, "runtimeMode")
    artifact_kind = field(body, "artifactKind")
    if runtime != "mlxSwiftLm" or artifact_kind != "mlx_directory":
        continue
    pack = field(body, "packId") or "unknown"
    tier = enum_field(body, "tier") or "unknown"
    file_name = field(body, "fileName") or "unknown"
    url = field(body, "downloadURLString") or "nil"
    bytes_value = int_field(body, "sizeBytes") or "nil"
    checksum = field(body, "checksumSha256") or "nil"
    lane = "catalog_mlx_draft" if "assistant" in pack.lower() or "assistant" in file_name.lower() else "catalog_mlx"
    reason = "configured_catalog_mlx_draft" if lane == "catalog_mlx_draft" else "configured_catalog_mlx"
    repo_id = hf_repo_id(url)
    target_dir = f"~/model-artifacts/{file_name}"
    print(
        "ROSS_RUNTIME_ARTIFACT_INVENTORY "
        f"lane={lane} status=expected path={q(url)} "
        f"reason={reason} "
        f"tier={q(tier)} pack={q(pack)} runtime={q(runtime)} file={q(file_name)} "
        f"artifact_kind={q(artifact_kind)} bytes={q(bytes_value)} checksum={q(checksum)} "
        f"repo={q(repo_id)} target_dir={q(target_dir)} acquisition_hint=hf_download_mlx_directory "
        "preflight_hint=simulator_mlx_directory_preflight"
    )
PY

if [[ "${#installed_roots[@]}" -gt 0 ]]; then
for installed_root in "${installed_roots[@]}"; do
  [[ -n "$installed_root" && -e "$installed_root" ]] || {
    printf 'ROSS_RUNTIME_ARTIFACT_INVENTORY lane=installed_packs status=missing path=%q reason=installed_root_not_found\n' "$installed_root"
    continue
  }

  python3 - "$installed_root" "$physical_memory_bytes" <<'PY'
import json
import hashlib
import pathlib
import shlex
import sys

raw_root = pathlib.Path(sys.argv[1]).expanduser()
physical_memory_bytes = int(sys.argv[2]) if len(sys.argv) > 2 and sys.argv[2] else None
model_packs_root = raw_root if raw_root.name == "model-packs" else raw_root / "model-packs"
support_root = model_packs_root.parent
constrained_e4b_memory_ceiling = 8_500_000_000
constrained_e4b_draft_artifact_budget_ratio = 0.72

def q(value: str) -> str:
    return shlex.quote(value)

def emit(lane: str, status: str, path: str, reason: str, **fields: object) -> None:
    extras = " ".join(f"{key}={q(str(value))}" for key, value in fields.items() if value is not None)
    line = f"ROSS_RUNTIME_ARTIFACT_INVENTORY lane={lane} status={status} path={q(path)} reason={reason}"
    if extras:
        line += f" {extras}"
    print(line)

def artifact_exists(relative_path: str, runtime: str, artifact_kind: str) -> bool:
    if not relative_path:
        return False
    if artifact_kind == "system_model" and (relative_path == "system-model" or relative_path.startswith("system://")):
        return True
    candidate = support_root / relative_path
    return candidate.exists()

def file_size(path: pathlib.Path) -> int:
    try:
        return path.stat().st_size
    except OSError:
        return 0

def manifest_size(value: object) -> int | None:
    try:
        parsed = int(value)
    except (TypeError, ValueError):
        return None
    return parsed if parsed > 0 else None

def artifact_size_bytes(relative_path: str, artifact_kind: str, declared_bytes: object) -> int | None:
    if artifact_kind == "system_model" and (relative_path == "system-model" or relative_path.startswith("system://")):
        return manifest_size(declared_bytes)
    candidate = support_root / relative_path
    size = file_size(candidate)
    return size if size > 0 else manifest_size(declared_bytes)

def archive_profile_hint(*values: object) -> str:
    text = " ".join(str(value or "") for value in values).lower()
    if "26b-a4b" in text:
        return "gemma26bA4b"
    if "12b" in text:
        return "gemma12b"
    if "e4b" in text:
        return "e4b"
    if "e2b" in text:
        return "flash"
    return "unknown"

def mtp_memory_policy(
    runtime: str,
    primary_relative_path: str,
    primary_file_name: object,
    primary_bytes: object,
    draft_relative_path: str,
    draft_file_name: object,
    draft_bytes: object,
) -> tuple[bool, str, dict[str, object]]:
    if runtime != "gemma_local_runtime" or physical_memory_bytes is None:
        return True, "manifest_draft_memory_policy_not_checked", {}
    if physical_memory_bytes >= constrained_e4b_memory_ceiling:
        return True, "manifest_draft_memory_policy_not_constrained", {"physical_memory": physical_memory_bytes}
    if archive_profile_hint(primary_relative_path, primary_file_name) != "e4b":
        return True, "manifest_draft_memory_policy_non_e4b", {"physical_memory": physical_memory_bytes}

    main_bytes = artifact_size_bytes(primary_relative_path, "local_model_artifact", primary_bytes)
    candidate_draft_bytes = artifact_size_bytes(draft_relative_path, "local_model_artifact", draft_bytes)
    if main_bytes is None or candidate_draft_bytes is None:
        return True, "manifest_draft_memory_policy_unknown_sizes", {"physical_memory": physical_memory_bytes}
    max_combined_bytes = int(physical_memory_bytes * constrained_e4b_draft_artifact_budget_ratio)
    allowed = main_bytes + candidate_draft_bytes <= max_combined_bytes
    reason = "manifest_draft_memory_policy_reachable" if allowed else "manifest_draft_memory_policy_blocked"
    return allowed, reason, {
        "physical_memory": physical_memory_bytes,
        "main_bytes": main_bytes,
        "draft_bytes": candidate_draft_bytes,
        "max_combined_bytes": max_combined_bytes,
    }

def normalized_sha256(value: object) -> str:
    text = str(value or "").strip().lower()
    if len(text) == 64 and all(character in "0123456789abcdef" for character in text):
        return text
    return ""

def file_sha256(path: pathlib.Path) -> str | None:
    if not path.is_file():
        return None
    digest = hashlib.sha256()
    try:
        with path.open("rb") as handle:
            for chunk in iter(lambda: handle.read(1024 * 1024), b""):
                digest.update(chunk)
    except OSError:
        return None
    return digest.hexdigest()

def gguf_file_looks_usable(path: pathlib.Path) -> bool:
    if not path.is_file() or file_size(path) <= 1_000_000:
        return False
    try:
        return path.open("rb").read(4) == b"GGUF"
    except OSError:
        return False

def mlx_directory_looks_usable(path: pathlib.Path) -> bool:
    if not path.is_dir() or not (path / "config.json").is_file():
        return False
    if not any((path / name).is_file() for name in ("tokenizer.json", "tokenizer.model", "tokenizer_config.json")):
        return False
    return any(file_size(path) > 0 for path in path.glob("**/*.safetensors")) or any(
        file_size(path) > 0 for path in path.glob("**/*.safetensors.index.json")
    )

def coreai_adapter_looks_usable(path: pathlib.Path) -> bool:
    lower_path = str(path).lower()
    if lower_path.endswith((".gguf", ".safetensors", ".bin")):
        return False
    if path.is_file():
        return file_size(path) > 0
    if not path.is_dir():
        return False
    if (path / "config.json").is_file() and (
        any(file_size(child) > 0 for child in path.glob("**/*.safetensors"))
        or any(file_size(child) > 0 for child in path.glob("**/*.safetensors.index.json"))
    ):
        return False
    return any(child.is_file() and file_size(child) > 0 for child in path.rglob("*"))

def artifact_looks_usable(relative_path: str, runtime: str, artifact_kind: str) -> bool:
    if artifact_kind == "system_model" and (relative_path == "system-model" or relative_path.startswith("system://")):
        return True
    candidate = support_root / relative_path
    if runtime == "gemma_local_runtime":
        return gguf_file_looks_usable(candidate)
    if runtime == "mlx_swift_lm":
        return mlx_directory_looks_usable(candidate)
    if runtime == "apple_foundation_models":
        return coreai_adapter_looks_usable(candidate)
    return candidate.exists()

def artifact_checksum_status(relative_path: str, artifact_kind: str, expected_checksum: object) -> str:
    expected = normalized_sha256(expected_checksum)
    if not expected:
        return "not_checked"
    if artifact_kind == "system_model" and (relative_path == "system-model" or relative_path.startswith("system://")):
        return "not_applicable"
    candidate = support_root / relative_path
    actual = file_sha256(candidate)
    if actual is None:
        return "not_checked"
    return "match" if actual == expected else "mismatch"

def expected_path_type(relative_path: str, artifact_kind: str) -> str:
    if artifact_kind == "system_model" and (relative_path == "system-model" or relative_path.startswith("system://")):
        return "system"
    return "file_or_directory"

def runtime_lane(runtime: str) -> str:
    if runtime == "gemma_local_runtime":
        return "installed_gguf"
    if runtime == "mlx_swift_lm":
        return "installed_mlx"
    if runtime == "apple_foundation_models":
        return "installed_coreai"
    return "installed_unknown"

def compatible_primary(runtime: str, artifact_kind: str, relative_path: str) -> tuple[bool, str]:
    lower_path = relative_path.lower()
    if runtime == "gemma_local_runtime":
        if artifact_kind not in {"local_model_artifact", "gguf", "gguf_model"}:
            return False, "manifest_incompatible_artifact_kind"
        if not lower_path.endswith(".gguf"):
            return False, "manifest_non_gguf_primary"
    elif runtime == "mlx_swift_lm":
        if artifact_kind != "mlx_directory":
            return False, "manifest_incompatible_artifact_kind"
        if lower_path.endswith((".gguf", ".bin")):
            return False, "manifest_file_like_mlx_primary"
    elif runtime == "apple_foundation_models":
        if artifact_kind == "system_model":
            if relative_path != "system-model" and not relative_path.startswith("system://"):
                return False, "manifest_invalid_system_model_sentinel"
        elif artifact_kind not in {"foundation_adapter", "coreai_adapter", "coreml_model"}:
            return False, "manifest_incompatible_artifact_kind"
        elif lower_path.endswith((".gguf", ".safetensors", ".bin")):
            return False, "manifest_foreign_coreai_adapter"
    return True, "manifest_primary_compatible"

def compatible_draft(runtime: str, artifact_kind: str, relative_path: str) -> tuple[bool, str]:
    lower_path = relative_path.lower()
    if runtime == "gemma_local_runtime":
        if artifact_kind not in {"local_model_artifact", "gguf", "gguf_model"}:
            return False, "manifest_incompatible_draft_artifact_kind"
        if not lower_path.endswith(".gguf"):
            return False, "manifest_non_gguf_draft"
    elif runtime == "mlx_swift_lm":
        if artifact_kind != "mlx_directory":
            return False, "manifest_incompatible_draft_artifact_kind"
        if lower_path.endswith((".gguf", ".bin")):
            return False, "manifest_file_like_mlx_draft"
    else:
        return False, "manifest_runtime_does_not_support_draft"
    return True, "manifest_draft_compatible"

if not model_packs_root.exists():
    emit("installed_packs", "missing", str(model_packs_root), "model_packs_root_not_found")
    sys.exit(0)

manifest_paths = sorted(model_packs_root.rglob("*.manifest.json"))
if not manifest_paths:
    emit("installed_packs", "missing", str(model_packs_root), "no_installed_pack_manifests")
    sys.exit(0)

emit("installed_packs", "present", str(model_packs_root), "manifest_root_found", count=len(manifest_paths))

for manifest_path in manifest_paths:
    try:
        payload = json.loads(manifest_path.read_text())
    except Exception:
        emit("installed_manifest", "missing", str(manifest_path), "manifest_json_unreadable")
        continue

    runtime = str(payload.get("runtimeMode") or "")
    artifact_kind = str(payload.get("artifactKind") or "local_model_artifact")
    relative_path = str(payload.get("relativePath") or "")
    pack_id = str(payload.get("packId") or "")
    tier = str(payload.get("tier") or "")
    bytes_value = payload.get("bytes")
    lane = runtime_lane(runtime)
    primary_ok, primary_reason = compatible_primary(runtime, artifact_kind, relative_path)
    primary_exists = artifact_exists(relative_path, runtime, artifact_kind)
    primary_usable = primary_exists and artifact_looks_usable(relative_path, runtime, artifact_kind)
    primary_checksum_status = artifact_checksum_status(relative_path, artifact_kind, payload.get("checksumSha256"))
    status = "present" if primary_ok and primary_usable and primary_checksum_status != "mismatch" else "missing"
    reason = primary_reason if not primary_ok else (
        "manifest_primary_checksum_mismatch" if primary_usable and primary_checksum_status == "mismatch"
        else
        "manifest_primary_reachable" if primary_usable
        else "manifest_primary_unusable_artifact" if primary_exists
        else "manifest_primary_file_missing"
    )
    emit(
        lane,
        status,
        relative_path or str(manifest_path),
        reason,
        pack=pack_id,
        tier=tier,
        runtime=runtime,
        artifact_kind=artifact_kind,
        bytes=bytes_value,
        checksum_status=primary_checksum_status,
        path_type=expected_path_type(relative_path, artifact_kind),
    )

    draft = payload.get("draftArtifact") or {}
    if runtime not in {"gemma_local_runtime", "mlx_swift_lm"}:
        continue

    draft_relative_path = str(draft.get("relativePath") or "")
    if not draft_relative_path:
        emit(
            "installed_mtp_draft" if runtime == "gemma_local_runtime" else "installed_mlx_draft",
            "missing",
            str(manifest_path),
            "manifest_missing_draft_artifact",
            pack=pack_id,
            tier=tier,
            runtime=runtime,
        )
        continue

    draft_kind = str(draft.get("artifactKind") or artifact_kind)
    draft_ok, draft_reason = compatible_draft(runtime, draft_kind, draft_relative_path)
    draft_exists = artifact_exists(draft_relative_path, runtime, draft_kind)
    draft_usable = draft_exists and artifact_looks_usable(draft_relative_path, runtime, draft_kind)
    draft_checksum_status = artifact_checksum_status(draft_relative_path, draft_kind, draft.get("checksumSha256"))
    memory_ok, memory_reason, memory_fields = mtp_memory_policy(
        runtime,
        relative_path,
        payload.get("fileName"),
        bytes_value,
        draft_relative_path,
        draft.get("fileName"),
        draft.get("bytes"),
    )
    draft_status = "present" if draft_ok and draft_usable and draft_checksum_status != "mismatch" and memory_ok else "missing"
    draft_final_reason = draft_reason if not draft_ok else (
        "manifest_draft_checksum_mismatch" if draft_usable and draft_checksum_status == "mismatch"
        else
        memory_reason if draft_usable and not memory_ok
        else
        "manifest_draft_reachable" if draft_usable
        else "manifest_draft_unusable_artifact" if draft_exists
        else "manifest_draft_file_missing"
    )
    emit(
        "installed_mtp_draft" if runtime == "gemma_local_runtime" else "installed_mlx_draft",
        draft_status,
        draft_relative_path,
        draft_final_reason,
        pack=pack_id,
        tier=tier,
        runtime=runtime,
        artifact_kind=draft_kind,
        bytes=draft.get("bytes"),
        checksum_status=draft_checksum_status,
        draft_tokens=draft.get("draftTokens"),
        **memory_fields,
    )
PY
done
fi

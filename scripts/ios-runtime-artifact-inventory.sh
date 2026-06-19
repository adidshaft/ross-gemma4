#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

usage() {
  cat <<'EOF'
Usage:
  scripts/ios-runtime-artifact-inventory.sh [--search-root <path>]...

Scans local filesystem paths for benchmarkable iOS runtime artifacts without
launching Simulator, devicectl, or the app. Results are advisory preflight
evidence only; generation proof still requires a guarded smoke pass.
EOF
}

search_roots=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --search-root)
      search_roots+=("${2:-}")
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

mlx_directory_looks_usable() {
  local directory="$1"
  [[ -d "$directory" ]] || return 1
  [[ -f "$directory/config.json" ]] || return 1

  if [[ ! -f "$directory/tokenizer.json" && ! -f "$directory/tokenizer.model" && ! -f "$directory/tokenizer_config.json" ]]; then
    return 1
  fi

  find "$directory" -maxdepth 3 -type f \( -name '*.safetensors' -o -name '*.safetensors.index.json' \) -print -quit | grep -q .
}

first_usable_gguf=""
first_draft_like_gguf=""
first_usable_mlx=""
first_coreai_adapter=""

for root in "${search_roots[@]}"; do
  [[ -n "$root" && -e "$root" ]] || continue

  while IFS= read -r gguf_path; do
    if gguf_file_looks_usable "$gguf_path"; then
      [[ -n "$first_usable_gguf" ]] || first_usable_gguf="$gguf_path"
      lower_path="$(printf '%s' "$gguf_path" | tr '[:upper:]' '[:lower:]')"
      case "$lower_path" in
        *mtp*|*draft*|*assistant*)
          [[ -n "$first_draft_like_gguf" ]] || first_draft_like_gguf="$gguf_path"
          ;;
      esac
    fi
  done < <(find "$root" -maxdepth 5 -type f -name '*.gguf' -print 2>/dev/null)

  while IFS= read -r config_path; do
    candidate_dir="$(dirname "$config_path")"
    if mlx_directory_looks_usable "$candidate_dir"; then
      [[ -n "$first_usable_mlx" ]] || first_usable_mlx="$candidate_dir"
    fi
  done < <(find "$root" -maxdepth 5 -type f -name config.json -print 2>/dev/null)

  while IFS= read -r adapter_path; do
    [[ -n "$first_coreai_adapter" ]] || first_coreai_adapter="$adapter_path"
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
  "usable_gguf_file" \
  "no_gguf_file_with_header_and_size_over_1mb"

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
  "coreai_adapter" \
  "$first_coreai_adapter" \
  "coreai_adapter_candidate" \
  "no_mlmodel_or_mlmodelc_adapter_found"

printf 'ROSS_RUNTIME_ARTIFACT_INVENTORY lane=coreai_system status=unknown path=system-model reason=requires_os_runtime_availability_and_generation_smoke\n'

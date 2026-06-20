#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  scripts/ios-morning-runtime-checkpoint-plan.sh [options]

Options:
  --device <device>     CoreDevice identifier, device name, DNS name, or UDID for printed devicectl commands. Default: DEVICE
  --bundle-id <id>      App bundle identifier. Default: com.ross.ios
  --gguf-model <path>   Local GGUF baseline artifact. Default: artifacts/gemma-2-2b-it-Q4_K_M.gguf
  --installed-root <p>  Optional RossAlpha support root/model-packs root used for dry-run inventory gating
  --physical-memory-bytes <bytes>
                       Optional device memory used for dry-run MTP memory-fit gating
  --tier <tier>         Runtime tier for short smokes. Default: quickStart
  --stage-timeout <s>   Per-stage timeout for printed commands. Default: 45

This script is dry-run only. It never calls devicectl, simctl, or launches the app.
EOF
}

device_id="DEVICE"
bundle_id="com.ross.ios"
gguf_model="artifacts/gemma-2-2b-it-Q4_K_M.gguf"
tier="quickStart"
stage_timeout="45"
installed_root=""
physical_memory_bytes=""

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
    --gguf-model)
      gguf_model="${2:-}"
      shift 2
      ;;
    --installed-root)
      installed_root="${2:-}"
      shift 2
      ;;
    --physical-memory-bytes)
      physical_memory_bytes="${2:-}"
      shift 2
      ;;
    --tier)
      tier="${2:-}"
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

if [[ -z "$stage_timeout" || "$stage_timeout" == *[!0-9]* || "$stage_timeout" -le 0 ]]; then
  echo "Stage timeout must be a positive integer number of seconds." >&2
  exit 2
fi

if [[ -n "$physical_memory_bytes" && ( "$physical_memory_bytes" == *[!0-9]* || "$physical_memory_bytes" -le 0 ) ]]; then
  echo "Physical memory bytes must be a positive integer." >&2
  exit 2
fi

quote_args() {
  local arg
  for arg in "$@"; do
    printf ' %q' "$arg"
  done
  printf '\n'
}

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

inventory_output=""
if [[ -n "$installed_root" ]]; then
  inventory_args=(scripts/ios-runtime-artifact-inventory.sh --search-root /dev/null --installed-root "$installed_root")
  if [[ -n "$physical_memory_bytes" ]]; then
    inventory_args+=(--physical-memory-bytes "$physical_memory_bytes")
  fi
  inventory_output="$("${inventory_args[@]}")"
fi

inventory_tier_pattern() {
  local requested_tier="$1"
  case "$requested_tier" in
    quickStart|quick_start)
      printf '(quickStart|quick_start)'
      ;;
    caseAssociate|case_associate)
      printf '(caseAssociate|case_associate)'
      ;;
    seniorDraftingSupport|senior_drafting_support)
      printf '(seniorDraftingSupport|senior_drafting_support)'
      ;;
    *)
      printf '%s' "$requested_tier"
      ;;
  esac
}

inventory_has_present_lane() {
  local lane="$1"
  local requested_tier="${2:-$tier}"
  local tier_pattern
  tier_pattern="$(inventory_tier_pattern "$requested_tier")"
  [[ -n "$inventory_output" ]] || return 0
  grep -Eq "lane=${lane} status=present .*tier=${tier_pattern}( |$)" <<<"$inventory_output"
}

inventory_present_pack_ids_for_lane() {
  local lane="$1"
  local requested_tier="${2:-$tier}"
  local tier_pattern
  tier_pattern="$(inventory_tier_pattern "$requested_tier")"
  [[ -n "$inventory_output" ]] || return 0
  grep -E "lane=${lane} status=present .*tier=${tier_pattern}( |$)" <<<"$inventory_output" |
    sed -nE 's/.* pack=([^ ]+).*/\1/p'
}

inventory_unique_present_pack_id_for_lane() {
  local lane="$1"
  local requested_tier="${2:-$tier}"
  [[ -n "$inventory_output" ]] || return 1
  local pack_ids
  pack_ids="$(inventory_present_pack_ids_for_lane "$lane" "$requested_tier" | sort -u)"
  local pack_count
  pack_count="$(printf '%s\n' "$pack_ids" | awk 'NF { count++ } END { print count + 0 }')"
  [[ "$pack_count" -eq 1 ]] || return 1
  printf '%s\n' "$pack_ids"
}

inventory_present_mtp_pair_count() {
  local requested_tier="${1:-$tier}"
  [[ -n "$inventory_output" ]] || {
    echo 0
    return 0
  }
  local pack_id
  local count=0
  while IFS= read -r pack_id; do
    [[ -n "$pack_id" ]] || continue
    if inventory_present_pack_ids_for_lane "installed_mtp_draft" "$requested_tier" |
      grep -Fxq "$pack_id"; then
      count=$((count + 1))
    fi
  done < <(inventory_present_pack_ids_for_lane "installed_gguf" "$requested_tier" | sort -u)
  echo "$count"
}

inventory_has_present_mtp_pair() {
  local requested_tier="${1:-$tier}"
  [[ -n "$inventory_output" ]] || return 0
  local pack_id
  while IFS= read -r pack_id; do
    [[ -n "$pack_id" ]] || continue
    if inventory_present_pack_ids_for_lane "installed_mtp_draft" "$requested_tier" |
      grep -Fxq "$pack_id"; then
      return 0
    fi
  done < <(inventory_present_pack_ids_for_lane "installed_gguf" "$requested_tier")
  return 1
}

inventory_present_mtp_pair_pack_id() {
  local requested_tier="${1:-$tier}"
  [[ -n "$inventory_output" ]] || return 0
  [[ "$(inventory_present_mtp_pair_count "$requested_tier")" -eq 1 ]] || return 1
  local pack_id
  while IFS= read -r pack_id; do
    [[ -n "$pack_id" ]] || continue
    if inventory_present_pack_ids_for_lane "installed_mtp_draft" "$requested_tier" |
      grep -Fxq "$pack_id"; then
      printf '%s\n' "$pack_id"
      return 0
    fi
  done < <(inventory_present_pack_ids_for_lane "installed_gguf" "$requested_tier")
  return 1
}

inventory_skip_reason() {
  local lane="$1"
  local requested_tier="${2:-$tier}"
  local tier_pattern
  tier_pattern="$(inventory_tier_pattern "$requested_tier")"
  [[ -n "$inventory_output" ]] || return 1
  grep -E "lane=${lane} status=missing .*tier=${tier_pattern}( |$)" <<<"$inventory_output" |
    head -n 1 |
    sed -E 's/.* reason=([^ ]+).*/\1/'
}

inventory_skip_detail_line() {
  local lane="$1"
  local requested_tier="${2:-$tier}"
  local reason="${3:-}"
  local tier_pattern
  tier_pattern="$(inventory_tier_pattern "$requested_tier")"
  [[ -n "$inventory_output" && -n "$reason" ]] || return 1
  grep -E "lane=${lane} status=missing .*reason=${reason} .*tier=${tier_pattern}( |$)" <<<"$inventory_output" |
    head -n 1
}

print_skip() {
  local label="$1"
  local reason="$2"
  printf '%s:\n' "$label"
  printf '   SKIP reason=%s\n' "$reason"
}

print_command() {
  local label="$1"
  shift
  printf '%s:\n' "$label"
  quote_args "$@"
}

print_fetch_plan_command() {
  local label="$1"
  if [[ -n "$physical_memory_bytes" ]]; then
    print_command \
      "$label" \
      scripts/ios-runtime-artifact-fetch-plan.sh \
      --tier "$tier" \
      --target-root "$HOME/model-artifacts" \
      --physical-memory-bytes "$physical_memory_bytes"
  else
    print_command \
      "$label" \
      scripts/ios-runtime-artifact-fetch-plan.sh \
      --tier "$tier" \
      --target-root "$HOME/model-artifacts"
  fi
}

print_installed_pack_command() {
  local label="$1"
  shift
  if [[ -n "$physical_memory_bytes" ]]; then
    print_command "$label" "$@" --physical-memory-bytes "$physical_memory_bytes"
  else
    print_command "$label" "$@"
  fi
}

print_installed_runtime_command() {
  local label="$1"
  local runtime="$2"
  local profile="$3"
  local pack_id="${4:-}"
  shift 4
  if [[ -n "$pack_id" ]]; then
    print_installed_pack_command \
      "$label" \
      scripts/ios-device-installed-pack-smoke.sh \
      --device "$device_id" \
      --bundle-id "$bundle_id" \
      --runtime "$runtime" \
      --tier "$tier" \
      --pack-id "$pack_id" \
      --smoke-profile "$profile" \
      --stage-timeout "$stage_timeout" \
      "$@"
  else
    print_installed_pack_command \
      "$label" \
      scripts/ios-device-installed-pack-smoke.sh \
      --device "$device_id" \
      --bundle-id "$bundle_id" \
      --runtime "$runtime" \
      --tier "$tier" \
      --smoke-profile "$profile" \
      --stage-timeout "$stage_timeout" \
      "$@"
  fi
}

echo "ROSS_MORNING_RUNTIME_CHECKPOINT_PLAN dry_run=true device=${device_id} bundle_id=${bundle_id} tier=${tier}"
if [[ -n "$installed_root" ]]; then
  echo "Inventory gate: installed_root=${installed_root}"
  if [[ -n "$physical_memory_bytes" ]]; then
    echo "Inventory MTP memory gate: physical_memory_bytes=${physical_memory_bytes}"
  fi
else
  echo "Inventory gate: not provided; runtime commands are templates until installed-pack inventory proves matching artifacts for the requested tier."
fi
echo
echo "Order: list installed packs first, run GGUF/MTP as short smokes, then run installed MLX/CoreAI with the full varied document/query matrix when available. GGUF baseline uses quick_low_context so it keeps the quick two-case matrix while reducing llama.cpp context/batch pressure. Stop on memory pressure, thermal issues, instability, or fallback."
echo "Pre-device sanity: use scripts/ios-simulator-local-model-smoke.sh --preflight-only for any local GGUF/MLX/CoreAI artifact or system:// sentinel you plan to reference; this emits ROSS_SIMULATOR_SMOKE_PREFLIGHT_OK without launching Simulator or touching the cabled iPhone."
echo "Full matrix cases: English source-bound document QA, Bengali source-bound document QA, Hindi source-bound document QA, Tamil source-bound document QA, Telugu source-bound document QA, and English open no-document query."
echo

print_fetch_plan_command \
  "0. Plan/download missing local runtime artifacts before any device work"

print_command \
  "1. List installed manifest-backed packs without launching inference" \
  scripts/ios-device-installed-pack-smoke.sh \
  --device "$device_id" \
  --bundle-id "$bundle_id" \
  --list-only

if gguf_file_looks_usable "$gguf_model" && ! gguf_path_is_draft_like "$gguf_model"; then
  print_command \
    "2. GGUF baseline seeded quick smoke" \
    scripts/ios-device-gguf-smoke.sh \
    --device "$device_id" \
    --bundle-id "$bundle_id" \
    --model "$gguf_model" \
    --tier "$tier" \
    --smoke-profile quick_low_context \
    --stage-timeout "$stage_timeout"
else
  echo "2. GGUF baseline seeded quick smoke:"
  if [[ -f "$gguf_model" ]] && gguf_path_is_draft_like "$gguf_model"; then
    echo "   SKIP reason=local_gguf_is_draft_like model=${gguf_model}"
  else
    echo "   SKIP reason=missing_or_invalid_primary_gguf model=${gguf_model}"
  fi
fi

if mtp_pair_pack_id="$(inventory_present_mtp_pair_pack_id "$tier")"; then
  if [[ -n "$inventory_output" ]]; then
    print_installed_runtime_command \
      "3. MTP low-token proof from installed GGUF pack" \
      gguf \
      mtp_quick \
      "$mtp_pair_pack_id" \
      --require-draft-acceleration
  else
    print_installed_runtime_command \
      "3. MTP low-token proof from installed GGUF pack" \
      gguf \
      mtp_quick \
      "" \
      --require-draft-acceleration
  fi
else
  mtp_skip_reason="$(inventory_skip_reason "installed_gguf" "$tier" ||
    inventory_skip_reason "installed_mtp_draft" "$tier" ||
    if [[ -n "$inventory_output" && "$(inventory_present_mtp_pair_count "$tier")" -gt 1 ]]; then
      echo multiple_installed_mtp_pairs_for_tier
    else
      false
    fi ||
    if inventory_has_present_lane "installed_gguf" "$tier" &&
       inventory_has_present_lane "installed_mtp_draft" "$tier"; then
      echo missing_installed_mtp_primary_draft_pair_for_tier
    else
      echo missing_installed_mtp_primary_or_draft_for_tier
    fi)"
  print_skip \
    "3. MTP low-token proof from installed GGUF pack" \
    "$mtp_skip_reason"
  if mtp_skip_detail="$(inventory_skip_detail_line "installed_mtp_draft" "$tier" "$mtp_skip_reason")"; then
    printf '   DETAIL %s\n' "$mtp_skip_detail"
  fi
fi

if inventory_has_present_lane "installed_mlx" "$tier"; then
  if [[ -n "$inventory_output" ]]; then
    if mlx_pack_id="$(inventory_unique_present_pack_id_for_lane "installed_mlx" "$tier")"; then
      print_installed_runtime_command \
        "4. MLX identity and varied document/query full smoke if installed MLX artifact exists" \
        mlx \
        full \
        "$mlx_pack_id"
    else
      print_skip \
        "4. MLX identity and varied document/query full smoke if installed MLX artifact exists" \
        "multiple_installed_mlx_for_tier"
    fi
  else
    print_installed_runtime_command \
      "4. MLX identity and varied document/query full smoke if installed MLX artifact exists" \
      mlx \
      full \
      ""
  fi
else
  print_skip \
    "4. MLX identity and varied document/query full smoke if installed MLX artifact exists" \
    "$(inventory_skip_reason "installed_mlx" "$tier" || echo missing_installed_mlx_for_tier)"
fi

if inventory_has_present_lane "installed_coreai" "$tier"; then
  if [[ -n "$inventory_output" ]]; then
    if coreai_pack_id="$(inventory_unique_present_pack_id_for_lane "installed_coreai" "$tier")"; then
      print_installed_runtime_command \
        "5. CoreAI/CoreML/Foundation varied document/query full smoke if available" \
        coreai \
        full \
        "$coreai_pack_id"
    else
      print_skip \
        "5. CoreAI/CoreML/Foundation varied document/query full smoke if available" \
        "multiple_installed_coreai_for_tier"
    fi
  else
    print_installed_runtime_command \
      "5. CoreAI/CoreML/Foundation varied document/query full smoke if available" \
      coreai \
      full \
      ""
  fi
else
  print_skip \
    "5. CoreAI/CoreML/Foundation varied document/query full smoke if available" \
    "$(inventory_skip_reason "installed_coreai" "$tier" || echo missing_installed_coreai_for_tier)"
fi

echo
echo "Evidence rule: record only ROSS_SMOKE_BENCHMARK_SUMMARY rows whose ROSS_RUNTIME_IDENTITY requested/actual runtime, provider, artifact shape, positive context_tokens, gpu_offload evidence, matrix cases, per-stage token/speed metrics, native-model markers, and source refs for source-bound stages match the requested lane. For MTP, draft_status must be active, not draft_output_degenerate, draft_model must be a .gguf label, and every benchmark matrix stage must report matching *_acceleration=draftModelSpeculative, *_draft_tokens, *_draft_model, plus positive *_draft_attempted and *_draft_accepted fields."
echo "Manual UI evidence: when validating a visible answer, open the hidden Answer Details affordance (info button or long-press menu) and record Tokens processed, Token speed, runtime, preferred runtime, and fallback status without surfacing those metrics in the main response."

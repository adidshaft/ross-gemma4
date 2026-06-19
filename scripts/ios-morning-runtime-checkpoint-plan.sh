#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  scripts/ios-morning-runtime-checkpoint-plan.sh [options]

Options:
  --device <udid>       Device UDID placeholder for printed commands. Default: DEVICE_UDID
  --bundle-id <id>      App bundle identifier. Default: com.ross.ios
  --gguf-model <path>   Local GGUF baseline artifact. Default: artifacts/gemma-2-2b-it-Q4_K_M.gguf
  --installed-root <p>  Optional RossAlpha support root/model-packs root used for dry-run inventory gating
  --tier <tier>         Runtime tier for short smokes. Default: quickStart
  --stage-timeout <s>   Per-stage timeout for printed commands. Default: 45

This script is dry-run only. It never calls devicectl, simctl, or launches the app.
EOF
}

device_id="DEVICE_UDID"
bundle_id="com.ross.ios"
gguf_model="artifacts/gemma-2-2b-it-Q4_K_M.gguf"
tier="quickStart"
stage_timeout="45"
installed_root=""

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

quote_args() {
  local arg
  for arg in "$@"; do
    printf ' %q' "$arg"
  done
  printf '\n'
}

inventory_output=""
if [[ -n "$installed_root" ]]; then
  inventory_output="$(scripts/ios-runtime-artifact-inventory.sh --search-root /dev/null --installed-root "$installed_root")"
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

echo "ROSS_MORNING_RUNTIME_CHECKPOINT_PLAN dry_run=true device=${device_id} bundle_id=${bundle_id} tier=${tier}"
if [[ -n "$installed_root" ]]; then
  echo "Inventory gate: installed_root=${installed_root}"
else
  echo "Inventory gate: not provided; runtime commands are templates until installed-pack inventory proves matching artifacts for the requested tier."
fi
echo
echo "Order: list installed packs first, run GGUF/MTP as short smokes, then run installed MLX/CoreAI with the full varied document/query matrix when available. Stop on memory pressure, thermal issues, instability, or fallback."
echo "Pre-device sanity: use scripts/ios-simulator-local-model-smoke.sh --preflight-only for any local GGUF/MLX/CoreAI artifact or system:// sentinel you plan to reference; this emits ROSS_SIMULATOR_SMOKE_PREFLIGHT_OK without launching Simulator or touching the cabled iPhone."
echo "Full matrix cases: English source-bound document QA, Bengali source-bound document QA, Hindi source-bound document QA, Tamil source-bound document QA, Telugu source-bound document QA, and English open no-document query."
echo

print_command \
  "1. List installed manifest-backed packs without launching inference" \
  scripts/ios-device-installed-pack-smoke.sh \
  --device "$device_id" \
  --bundle-id "$bundle_id" \
  --list-only

if [[ -f "$gguf_model" ]]; then
  print_command \
    "2. GGUF baseline seeded quick smoke" \
    scripts/ios-device-gguf-smoke.sh \
    --device "$device_id" \
    --bundle-id "$bundle_id" \
    --model "$gguf_model" \
    --tier "$tier" \
    --stage-timeout "$stage_timeout"
else
  echo "2. GGUF baseline seeded quick smoke:"
  echo "   SKIP reason=missing_local_gguf model=${gguf_model}"
fi

if inventory_has_present_lane "installed_gguf" "$tier" &&
   inventory_has_present_lane "installed_mtp_draft" "$tier"; then
  print_command \
    "3. MTP low-token proof from installed GGUF pack" \
    scripts/ios-device-installed-pack-smoke.sh \
    --device "$device_id" \
    --bundle-id "$bundle_id" \
    --runtime gguf \
    --tier "$tier" \
    --smoke-profile mtp_quick \
    --stage-timeout "$stage_timeout" \
    --require-draft-acceleration
else
  mtp_skip_reason="$(inventory_skip_reason "installed_gguf" "$tier" ||
    inventory_skip_reason "installed_mtp_draft" "$tier" ||
    echo missing_installed_mtp_primary_or_draft_for_tier)"
  print_skip \
    "3. MTP low-token proof from installed GGUF pack" \
    "$mtp_skip_reason"
fi

if inventory_has_present_lane "installed_mlx" "$tier"; then
  print_command \
    "4. MLX identity and varied document/query full smoke if installed MLX artifact exists" \
    scripts/ios-device-installed-pack-smoke.sh \
    --device "$device_id" \
    --bundle-id "$bundle_id" \
    --runtime mlx \
    --tier "$tier" \
    --smoke-profile full \
    --stage-timeout "$stage_timeout"
else
  print_skip \
    "4. MLX identity and varied document/query full smoke if installed MLX artifact exists" \
    "$(inventory_skip_reason "installed_mlx" "$tier" || echo missing_installed_mlx_for_tier)"
fi

if inventory_has_present_lane "installed_coreai" "$tier"; then
  print_command \
    "5. CoreAI/CoreML/Foundation varied document/query full smoke if available" \
    scripts/ios-device-installed-pack-smoke.sh \
    --device "$device_id" \
    --bundle-id "$bundle_id" \
    --runtime coreai \
    --tier "$tier" \
    --smoke-profile full \
    --stage-timeout "$stage_timeout"
else
  print_skip \
    "5. CoreAI/CoreML/Foundation varied document/query full smoke if available" \
    "$(inventory_skip_reason "installed_coreai" "$tier" || echo missing_installed_coreai_for_tier)"
fi

echo
echo "Evidence rule: record only ROSS_SMOKE_BENCHMARK_SUMMARY rows whose ROSS_RUNTIME_IDENTITY requested/actual runtime, provider, artifact shape, positive context_tokens, gpu_offload evidence, matrix cases, per-stage token/speed metrics, native-model markers, and source refs for source-bound stages match the requested lane. For MTP, draft_status must be active, not draft_output_degenerate, draft_model must be a .gguf label, and every benchmark matrix stage must report matching *_acceleration=draftModelSpeculative, *_draft_tokens, and *_draft_model fields."

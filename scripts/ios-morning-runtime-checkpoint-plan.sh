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

quote_args() {
  local arg
  for arg in "$@"; do
    printf ' %q' "$arg"
  done
  printf '\n'
}

print_command() {
  local label="$1"
  shift
  printf '%s:\n' "$label"
  quote_args "$@"
}

echo "ROSS_MORNING_RUNTIME_CHECKPOINT_PLAN dry_run=true device=${device_id} bundle_id=${bundle_id} tier=${tier}"
echo
echo "Order: list installed packs first, then run only short smokes. Stop on memory pressure, thermal issues, instability, or fallback."
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

print_command \
  "4. MLX identity and generation quick smoke if installed MLX artifact exists" \
  scripts/ios-device-installed-pack-smoke.sh \
  --device "$device_id" \
  --bundle-id "$bundle_id" \
  --runtime mlx \
  --tier "$tier" \
  --smoke-profile quick \
  --stage-timeout "$stage_timeout"

print_command \
  "5. CoreAI/CoreML/Foundation quick smoke if available" \
  scripts/ios-device-installed-pack-smoke.sh \
  --device "$device_id" \
  --bundle-id "$bundle_id" \
  --runtime coreai \
  --tier "$tier" \
  --smoke-profile quick \
  --stage-timeout "$stage_timeout"

echo
echo "Evidence rule: record only ROSS_SMOKE_BENCHMARK_SUMMARY rows whose ROSS_RUNTIME_IDENTITY requested/actual runtime, artifact shape, matrix cases, and draft fields match the requested lane."

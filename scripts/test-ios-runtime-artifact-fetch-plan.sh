#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FETCH_PLAN="$ROOT_DIR/scripts/ios-runtime-artifact-fetch-plan.sh"

tmpdir="$(mktemp -d /tmp/ross-runtime-fetch-plan.XXXXXX)"
trap 'rm -rf "$tmpdir" /tmp/ross-runtime-fetch-plan.out' EXIT

set +e
"$FETCH_PLAN" --tier typo > /tmp/ross-runtime-fetch-plan.out 2>&1
bad_tier_rc=$?
set -e
if [[ "$bad_tier_rc" -ne 2 ]]; then
  echo "Expected unsupported tier to exit 2" >&2
  cat /tmp/ross-runtime-fetch-plan.out >&2 || true
  exit 1
fi
grep -q "Unsupported tier: typo" /tmp/ross-runtime-fetch-plan.out

ROSS_RUNTIME_ARTIFACT_FETCH_DOWNLOADER_STATUS=missing \
  "$FETCH_PLAN" --tier quickStart --target-root "$tmpdir/downloads" --search-root "$tmpdir/empty" > /tmp/ross-runtime-fetch-plan.out
grep -q "ROSS_RUNTIME_ARTIFACT_FETCH_PLAN dry_run=true tier=quickStart .*downloader_status=missing" /tmp/ross-runtime-fetch-plan.out
grep -q "lane=downloader status=missing action=install .*command='python3 -m venv $tmpdir/downloads/.hf-venv && $tmpdir/downloads/.hf-venv/bin/python -m pip install --upgrade pip huggingface_hub'" /tmp/ross-runtime-fetch-plan.out
grep -q "lane=mlx status=missing action=download .*repo=mlx-community/gemma-4-E4B-it-qat-4bit .*target_dir=$tmpdir/downloads/gemma-4-E4B-it-qat-4bit .*command='hf download mlx-community/gemma-4-E4B-it-qat-4bit --local-dir $tmpdir/downloads/gemma-4-E4B-it-qat-4bit'" /tmp/ross-runtime-fetch-plan.out
grep -q "lane=mlx status=missing action=preflight_after_download .*--runtime mlx .*--preflight-only" /tmp/ross-runtime-fetch-plan.out
grep -q "lane=mlx_draft status=missing action=download .*repo=mlx-community/gemma-4-E4B-it-qat-assistant-6bit" /tmp/ross-runtime-fetch-plan.out
grep -q "lane=coreai_system status=unknown action=preflight .*system://apple-foundation-models" /tmp/ross-runtime-fetch-plan.out

ROSS_RUNTIME_ARTIFACT_FETCH_DOWNLOADER_STATUS=hf_cli \
  "$FETCH_PLAN" --tier quickStart --target-root "$tmpdir/downloads" --search-root "$tmpdir/empty" > /tmp/ross-runtime-fetch-plan.out
grep -q "ROSS_RUNTIME_ARTIFACT_FETCH_PLAN dry_run=true tier=quickStart .*downloader_status=hf_cli" /tmp/ross-runtime-fetch-plan.out
if grep -q "lane=downloader status=missing" /tmp/ross-runtime-fetch-plan.out; then
  echo "Did not expect downloader install row when hf_cli is forced available." >&2
  cat /tmp/ross-runtime-fetch-plan.out >&2
  exit 1
fi

mkdir -p "$tmpdir/downloads/.hf-venv/bin"
printf '#!/usr/bin/env bash\nexit 0\n' > "$tmpdir/downloads/.hf-venv/bin/hf"
chmod +x "$tmpdir/downloads/.hf-venv/bin/hf"
"$FETCH_PLAN" --tier quickStart --target-root "$tmpdir/downloads" --search-root "$tmpdir/empty" > /tmp/ross-runtime-fetch-plan.out
grep -q "ROSS_RUNTIME_ARTIFACT_FETCH_PLAN dry_run=true tier=quickStart .*downloader_status=target_root_venv" /tmp/ross-runtime-fetch-plan.out
grep -q "lane=mlx status=missing action=download .*command='$tmpdir/downloads/.hf-venv/bin/hf download mlx-community/gemma-4-E4B-it-qat-4bit --local-dir $tmpdir/downloads/gemma-4-E4B-it-qat-4bit'" /tmp/ross-runtime-fetch-plan.out

mlx_draft_dir="$tmpdir/draft-only/gemma-4-E4B-it-qat-assistant-6bit"
mkdir -p "$mlx_draft_dir"
printf '{}' > "$mlx_draft_dir/config.json"
printf '{}' > "$mlx_draft_dir/tokenizer.json"
printf 'weights' > "$mlx_draft_dir/model.safetensors"
ROSS_RUNTIME_ARTIFACT_FETCH_DOWNLOADER_STATUS=hf_cli \
  "$FETCH_PLAN" --tier quickStart --target-root "$tmpdir/downloads" --search-root "$tmpdir/draft-only" > /tmp/ross-runtime-fetch-plan.out
grep -q "lane=mlx status=missing action=download .*repo=mlx-community/gemma-4-E4B-it-qat-4bit" /tmp/ross-runtime-fetch-plan.out
grep -q "lane=mlx_draft status=present action=waiting_for_primary .*path=$mlx_draft_dir" /tmp/ross-runtime-fetch-plan.out
if grep -q "lane=mlx_draft status=missing action=download" /tmp/ross-runtime-fetch-plan.out; then
  echo "Did not expect MLX draft download row when a local draft-like MLX directory is already present." >&2
  cat /tmp/ross-runtime-fetch-plan.out >&2
  exit 1
fi

mlx_dir="$tmpdir/usable-mlx"
mkdir -p "$mlx_dir"
printf '{}' > "$mlx_dir/config.json"
printf '{}' > "$mlx_dir/tokenizer.json"
printf 'weights' > "$mlx_dir/model.safetensors"

coreai_dir="$tmpdir/foundation-adapter.mlmodelc"
mkdir -p "$coreai_dir"
printf 'adapter' > "$coreai_dir/model.bin"

ROSS_RUNTIME_ARTIFACT_FETCH_DOWNLOADER_STATUS=hf_cli \
  "$FETCH_PLAN" --tier quickStart --target-root "$tmpdir/downloads" --search-root "$tmpdir" > /tmp/ross-runtime-fetch-plan.out
grep -q "lane=mlx status=present action=preflight .*path=$mlx_dir .*--runtime mlx .*--model $mlx_dir .*--preflight-only" /tmp/ross-runtime-fetch-plan.out
grep -q "lane=mlx_draft status=present action=preflight_pair .*path=$mlx_draft_dir .*--draft-model $mlx_draft_dir .*--require-draft-acceleration .*--smoke-profile mtp_quick .*--preflight-only" /tmp/ross-runtime-fetch-plan.out
grep -q "lane=coreai_adapter status=present action=preflight .*path=$coreai_dir .*--runtime coreml .*--artifact-kind foundation_adapter .*--model $coreai_dir .*--preflight-only" /tmp/ross-runtime-fetch-plan.out

echo "iOS runtime artifact fetch plan tests: PASS"

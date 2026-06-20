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

set +e
"$FETCH_PLAN" --tier quickStart --physical-memory-bytes nope > /tmp/ross-runtime-fetch-plan.out 2>&1
bad_memory_rc=$?
set -e
if [[ "$bad_memory_rc" -ne 2 ]]; then
  echo "Expected invalid physical memory to exit 2" >&2
  cat /tmp/ross-runtime-fetch-plan.out >&2 || true
  exit 1
fi
grep -q "Physical memory bytes must be a positive integer" /tmp/ross-runtime-fetch-plan.out

ROSS_RUNTIME_ARTIFACT_FETCH_DOWNLOADER_STATUS=missing \
  "$FETCH_PLAN" --tier quickStart --target-root "$tmpdir/downloads" --search-root "$tmpdir/empty" > /tmp/ross-runtime-fetch-plan.out
grep -q "ROSS_RUNTIME_ARTIFACT_FETCH_PLAN dry_run=true tier=quickStart .*downloader_status=missing .*physical_memory_bytes=nil" /tmp/ross-runtime-fetch-plan.out
grep -q "lane=downloader status=missing action=install .*command='python3 -m venv $tmpdir/downloads/.hf-venv && $tmpdir/downloads/.hf-venv/bin/python -m pip install --upgrade pip huggingface_hub'" /tmp/ross-runtime-fetch-plan.out
grep -q "lane=gguf status=missing action=download .*repo=unsloth/gemma-4-E4B-it-GGUF .*target_file=$tmpdir/downloads/gemma-4-E4B-it-UD-Q4_K_XL.gguf .*checksum=30d1e7949597a3446726064e80b876fd1b5cba4aa6eec53d27afa420e731fb36" /tmp/ross-runtime-fetch-plan.out
grep -q "lane=gguf status=missing action=preflight_after_download .*--runtime gguf .*--model $tmpdir/downloads/gemma-4-E4B-it-UD-Q4_K_XL.gguf .*--smoke-profile quick_low_context .*--preflight-only" /tmp/ross-runtime-fetch-plan.out
grep -q "lane=mtp_draft status=missing action=download .*repo=unsloth/gemma-4-E4B-it-GGUF .*target_file=$tmpdir/downloads/mtp-gemma-4-E4B-it.gguf .*checksum=b6a723115efa510d3b3215db1e26790dae84cd08c2134a764f3d194f1f0c3376" /tmp/ross-runtime-fetch-plan.out
grep -q "lane=mtp_draft status=missing action=preflight_pair_after_download .*--draft-model $tmpdir/downloads/mtp-gemma-4-E4B-it.gguf .*--require-draft-acceleration .*--smoke-profile mtp_quick .*--preflight-only" /tmp/ross-runtime-fetch-plan.out
grep -q "lane=mlx status=blocked action=await_compatible_archive .*repo=mlx-community/gemma-4-E4B-it-qat-4bit .*target_dir=$tmpdir/downloads/gemma-4-E4B-it-qat-4bit .*reason=catalog_primary_not_release_ready .*compatibility_hint=runtime_requires_supported_text_mlx_archive" /tmp/ross-runtime-fetch-plan.out
if grep -q "lane=mlx status=missing action=download .*repo=mlx-community/gemma-4-E4B-it-qat-4bit" /tmp/ross-runtime-fetch-plan.out; then
  echo "Did not expect download command for non-release-ready bundled MLX primary." >&2
  cat /tmp/ross-runtime-fetch-plan.out >&2
  exit 1
fi
grep -q "lane=mlx_draft status=blocked action=waiting_for_primary .*repo=mlx-community/gemma-4-E4B-it-qat-assistant-6bit .*target_dir=$tmpdir/downloads/gemma-4-E4B-it-qat-assistant-6bit .*reason=missing_compatible_mlx_primary .*compatibility_hint=runtime_requires_supported_text_mlx_archive" /tmp/ross-runtime-fetch-plan.out
if grep -q "lane=mlx_draft status=missing action=download .*repo=mlx-community/gemma-4-E4B-it-qat-assistant-6bit" /tmp/ross-runtime-fetch-plan.out; then
  echo "Did not expect standalone MLX draft download while compatible primary MLX is blocked." >&2
  cat /tmp/ross-runtime-fetch-plan.out >&2
  exit 1
fi
if grep -q "lane=mlx_draft status=missing action=preflight_after_download" /tmp/ross-runtime-fetch-plan.out; then
  echo "Did not expect standalone MLX draft preflight when no compatible primary MLX is available." >&2
  cat /tmp/ross-runtime-fetch-plan.out >&2
  exit 1
fi
grep -q "lane=coreai_system status=unknown action=preflight .*system://apple-foundation-models" /tmp/ross-runtime-fetch-plan.out
grep -q "lane=coreai_adapter status=missing action=await_adapter .*reason=no_mlmodel_or_mlmodelc_adapter_found .*compatibility_hint=requires_nonempty_foundation_or_coreml_adapter_not_gguf_or_mlx .*accepted_artifact_kinds=foundation_adapter,coreai_adapter,coreml_model .*accepted_path_shapes=.bundle,.mlmodel,.mlmodelc,.mlpackage .*system_model_hint=use_coreai_system_lane_for_system-model_or_system_url" /tmp/ross-runtime-fetch-plan.out

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
grep -q "lane=mlx status=blocked action=await_compatible_archive .*repo=mlx-community/gemma-4-E4B-it-qat-4bit" /tmp/ross-runtime-fetch-plan.out

wrong_tier_root="$tmpdir/wrong-tier"
mkdir -p "$wrong_tier_root"
python3 - "$wrong_tier_root/gemma-4-12b-it-UD-Q4_K_XL.gguf" "$wrong_tier_root/mtp-gemma-4-12b-it.gguf" <<'PY'
import pathlib
import sys
for raw_path in sys.argv[1:]:
    pathlib.Path(raw_path).write_bytes(b"GGUF" + (b"\0" * 1000000))
PY
ROSS_RUNTIME_ARTIFACT_FETCH_DOWNLOADER_STATUS=hf_cli \
  "$FETCH_PLAN" --tier quickStart --target-root "$tmpdir/downloads" --search-root "$wrong_tier_root" > /tmp/ross-runtime-fetch-plan.out
grep -q "lane=gguf status=missing action=download .*target_file=$tmpdir/downloads/gemma-4-E4B-it-UD-Q4_K_XL.gguf" /tmp/ross-runtime-fetch-plan.out
grep -q "lane=mtp_draft status=missing action=download .*target_file=$tmpdir/downloads/mtp-gemma-4-E4B-it.gguf" /tmp/ross-runtime-fetch-plan.out
if grep -q "lane=mtp_draft status=present action=preflight_pair .*path=$wrong_tier_root/mtp-gemma-4-12b-it.gguf" /tmp/ross-runtime-fetch-plan.out; then
  echo "Did not expect wrong-tier 12B draft to satisfy Quick Start E4B MTP plan." >&2
  cat /tmp/ross-runtime-fetch-plan.out >&2
  exit 1
fi

exact_bad_root="$tmpdir/exact-bad-downloads"
mkdir -p "$exact_bad_root"
python3 - "$exact_bad_root/gemma-4-E4B-it-UD-Q4_K_XL.gguf" "$exact_bad_root/mtp-gemma-4-E4B-it.gguf" <<'PY'
import pathlib
import sys
for raw_path in sys.argv[1:]:
    pathlib.Path(raw_path).write_bytes(b"GGUF" + (b"\0" * 1000001))
PY
ROSS_RUNTIME_ARTIFACT_FETCH_DOWNLOADER_STATUS=hf_cli \
  "$FETCH_PLAN" --tier quickStart --target-root "$exact_bad_root" --search-root "$tmpdir/empty" > /tmp/ross-runtime-fetch-plan.out
grep -q "lane=gguf status=missing action=download .*target_file=$exact_bad_root/gemma-4-E4B-it-UD-Q4_K_XL.gguf .*local_unusable_path=$exact_bad_root/gemma-4-E4B-it-UD-Q4_K_XL.gguf .*local_unusable_reason=size_mismatch" /tmp/ross-runtime-fetch-plan.out
grep -q "lane=mtp_draft status=missing action=download .*target_file=$exact_bad_root/mtp-gemma-4-E4B-it.gguf .*local_unusable_path=$exact_bad_root/mtp-gemma-4-E4B-it.gguf .*local_unusable_reason=size_mismatch" /tmp/ross-runtime-fetch-plan.out

quick_gguf_root="$tmpdir/quick-gguf"
mkdir -p "$quick_gguf_root"
python3 - "$quick_gguf_root/gemma-4-E4B-it-UD-Q4_K_XL.gguf" "$quick_gguf_root/mtp-gemma-4-E4B-it.gguf" <<'PY'
import pathlib
import sys
for raw_path in sys.argv[1:]:
    pathlib.Path(raw_path).write_bytes(b"GGUF" + (b"\0" * 1000000))
PY
ROSS_RUNTIME_ARTIFACT_FETCH_DOWNLOADER_STATUS=hf_cli \
  "$FETCH_PLAN" --tier quickStart --target-root "$tmpdir/downloads" --search-root "$quick_gguf_root" --physical-memory-bytes 7200000000 > /tmp/ross-runtime-fetch-plan.out
grep -q "ROSS_RUNTIME_ARTIFACT_FETCH_PLAN dry_run=true tier=quickStart .*physical_memory_bytes=7200000000" /tmp/ross-runtime-fetch-plan.out
grep -q "lane=gguf status=present action=preflight .*path=$quick_gguf_root/gemma-4-E4B-it-UD-Q4_K_XL.gguf .*--smoke-profile quick_low_context .*--preflight-only" /tmp/ross-runtime-fetch-plan.out
grep -q "lane=gguf status=present action=preflight .*--physical-memory-bytes 7200000000 .*--preflight-only" /tmp/ross-runtime-fetch-plan.out
grep -q "lane=mtp_draft status=present action=preflight_pair .*path=$quick_gguf_root/mtp-gemma-4-E4B-it.gguf .*--draft-tokens 2 .*--require-draft-acceleration .*--smoke-profile mtp_quick .*--physical-memory-bytes 7200000000 .*--preflight-only" /tmp/ross-runtime-fetch-plan.out

memory_blocked_root="$tmpdir/local-memory-blocked"
mkdir -p "$memory_blocked_root"
printf 'GGUF' > "$memory_blocked_root/gemma-4-E4B-it-UD-Q4_K_XL.gguf"
truncate -s 5126304928 "$memory_blocked_root/gemma-4-E4B-it-UD-Q4_K_XL.gguf"
printf 'GGUF' > "$memory_blocked_root/mtp-gemma-4-E4B-it.gguf"
truncate -s 98653248 "$memory_blocked_root/mtp-gemma-4-E4B-it.gguf"
ROSS_RUNTIME_ARTIFACT_FETCH_DOWNLOADER_STATUS=hf_cli \
  "$FETCH_PLAN" --tier quickStart --target-root "$tmpdir/downloads" --search-root "$memory_blocked_root" --physical-memory-bytes 7200000000 > /tmp/ross-runtime-fetch-plan.out
grep -q "lane=gguf status=present action=preflight .*path=$memory_blocked_root/gemma-4-E4B-it-UD-Q4_K_XL.gguf" /tmp/ross-runtime-fetch-plan.out
grep -q "lane=mtp_draft status=blocked action=memory_policy_blocked .*path=$memory_blocked_root/mtp-gemma-4-E4B-it.gguf .*reason=local_draft_memory_policy_blocked .*physical_memory=7200000000 .*main_bytes=5126304928 .*draft_bytes=98653248 .*max_combined_bytes=5184000000" /tmp/ross-runtime-fetch-plan.out
if grep -q "lane=mtp_draft status=present action=preflight_pair .*path=$memory_blocked_root/mtp-gemma-4-E4B-it.gguf" /tmp/ross-runtime-fetch-plan.out; then
  echo "Did not expect memory-blocked local E4B MTP pair to print a present preflight row." >&2
  cat /tmp/ross-runtime-fetch-plan.out >&2
  exit 1
fi

mlx_draft_dir="$tmpdir/draft-only/gemma-4-E4B-it-qat-assistant-6bit"
mkdir -p "$mlx_draft_dir"
printf '{}' > "$mlx_draft_dir/config.json"
printf '{}' > "$mlx_draft_dir/tokenizer.json"
printf 'weights' > "$mlx_draft_dir/model.safetensors"
ROSS_RUNTIME_ARTIFACT_FETCH_DOWNLOADER_STATUS=hf_cli \
  "$FETCH_PLAN" --tier quickStart --target-root "$tmpdir/downloads" --search-root "$tmpdir/draft-only" > /tmp/ross-runtime-fetch-plan.out
grep -q "lane=mlx status=blocked action=await_compatible_archive .*repo=mlx-community/gemma-4-E4B-it-qat-4bit" /tmp/ross-runtime-fetch-plan.out
grep -q "lane=mlx_draft status=present action=waiting_for_primary .*path=$mlx_draft_dir .*reason=missing_compatible_mlx_primary" /tmp/ross-runtime-fetch-plan.out
if grep -q "lane=mlx_draft status=missing action=download" /tmp/ross-runtime-fetch-plan.out; then
  echo "Did not expect MLX draft download row when a local draft-like MLX directory is already present." >&2
  cat /tmp/ross-runtime-fetch-plan.out >&2
  exit 1
fi

unsupported_mlx_root="$tmpdir/unsupported-mlx"
unsupported_mlx_primary="$unsupported_mlx_root/gemma-4-E4B-it-qat-4bit"
unsupported_mlx_draft="$unsupported_mlx_root/gemma-4-E4B-it-qat-assistant-6bit"
mkdir -p "$unsupported_mlx_primary" "$unsupported_mlx_draft"
python3 - "$unsupported_mlx_primary" "$unsupported_mlx_draft" <<'PY'
import json
import pathlib
import sys

primary = pathlib.Path(sys.argv[1])
draft = pathlib.Path(sys.argv[2])
for directory in (primary, draft):
    (directory / "tokenizer.json").write_text("{}")
    (directory / "model.safetensors").write_text("weights")
    (directory / "config.json").write_text(json.dumps({
        "model_type": "gemma4",
        "architectures": ["Gemma4ForConditionalGeneration"],
        "vision_config": {},
    }))
PY
ROSS_RUNTIME_ARTIFACT_FETCH_DOWNLOADER_STATUS=hf_cli \
  "$FETCH_PLAN" --tier quickStart --target-root "$tmpdir/downloads" --search-root "$unsupported_mlx_root" > /tmp/ross-runtime-fetch-plan.out
grep -q "lane=mlx status=blocked action=await_compatible_archive .*reason=catalog_primary_not_release_ready .*local_unsupported_path=$unsupported_mlx_primary .*local_unsupported_reason=unsupported_gemma4_multimodal" /tmp/ross-runtime-fetch-plan.out
grep -q "lane=mlx_draft status=blocked action=waiting_for_primary .*reason=missing_compatible_mlx_primary .*local_unsupported_primary_path=$unsupported_mlx_primary .*local_unsupported_primary_reason=unsupported_gemma4_multimodal .*local_unsupported_draft_path=$unsupported_mlx_draft .*local_unsupported_draft_reason=unsupported_gemma4_multimodal" /tmp/ross-runtime-fetch-plan.out
grep -q "lane=mlx status=blocked action=await_compatible_archive .*local_catalog_status=size_mismatch .*local_catalog_path=$unsupported_mlx_primary .*local_catalog_bytes=.*local_catalog_checksum=" /tmp/ross-runtime-fetch-plan.out
grep -q "lane=mlx_draft status=blocked action=waiting_for_primary .*primary_local_catalog_status=size_mismatch .*primary_local_catalog_path=$unsupported_mlx_primary .*draft_local_catalog_status=size_mismatch .*draft_local_catalog_path=$unsupported_mlx_draft" /tmp/ross-runtime-fetch-plan.out
ROSS_RUNTIME_ARTIFACT_FETCH_DOWNLOADER_STATUS=hf_cli \
  "$FETCH_PLAN" --tier caseAssociate --target-root "$tmpdir/downloads" --search-root "$unsupported_mlx_root" > /tmp/ross-runtime-fetch-plan.out
grep -q "lane=mlx status=blocked action=await_compatible_archive .*repo=mlx-community/gemma-4-12B-it-qat-4bit .*reason=catalog_primary_not_release_ready" /tmp/ross-runtime-fetch-plan.out
if grep -q "local_unsupported_path=$unsupported_mlx_primary\\|local_unsupported_primary_path=$unsupported_mlx_primary\\|local_unsupported_draft_path=$unsupported_mlx_draft" /tmp/ross-runtime-fetch-plan.out; then
  echo "Did not expect Case Associate MLX plan to reuse Quick Start unsupported artifact breadcrumbs." >&2
  cat /tmp/ross-runtime-fetch-plan.out >&2
  exit 1
fi

primary_only_mlx_dir="$tmpdir/primary-only/usable-mlx"
mkdir -p "$primary_only_mlx_dir"
printf '{}' > "$primary_only_mlx_dir/config.json"
printf '{}' > "$primary_only_mlx_dir/tokenizer.json"
printf 'weights' > "$primary_only_mlx_dir/model.safetensors"
ROSS_RUNTIME_ARTIFACT_FETCH_DOWNLOADER_STATUS=hf_cli \
  "$FETCH_PLAN" --tier quickStart --target-root "$tmpdir/downloads" --search-root "$tmpdir/primary-only" > /tmp/ross-runtime-fetch-plan.out
grep -q "lane=mlx status=present action=preflight .*path=$primary_only_mlx_dir .*--runtime mlx .*--model $primary_only_mlx_dir .*--preflight-only" /tmp/ross-runtime-fetch-plan.out
grep -q "lane=mlx_draft status=missing action=download .*repo=mlx-community/gemma-4-E4B-it-qat-assistant-6bit .*target_dir=$tmpdir/downloads/gemma-4-E4B-it-qat-assistant-6bit" /tmp/ross-runtime-fetch-plan.out
grep -q "lane=mlx_draft status=missing action=preflight_pair_after_download .*target_dir=$tmpdir/downloads/gemma-4-E4B-it-qat-assistant-6bit .*--runtime mlx .*--model $primary_only_mlx_dir .*--draft-model $tmpdir/downloads/gemma-4-E4B-it-qat-assistant-6bit .*--require-draft-acceleration .*--smoke-profile mtp_quick .*--preflight-only" /tmp/ross-runtime-fetch-plan.out
if grep -q "lane=mlx_draft status=missing action=preflight_after_download" /tmp/ross-runtime-fetch-plan.out; then
  echo "Did not expect primary-present MLX draft plan to use standalone draft preflight." >&2
  cat /tmp/ross-runtime-fetch-plan.out >&2
  exit 1
fi

final_root="$tmpdir/final-usable"
mlx_dir="$final_root/usable-mlx"
mkdir -p "$mlx_dir"
printf '{}' > "$mlx_dir/config.json"
printf '{}' > "$mlx_dir/tokenizer.json"
printf 'weights' > "$mlx_dir/model.safetensors"

final_mlx_draft_dir="$final_root/gemma-4-E4B-it-qat-assistant-6bit"
mkdir -p "$final_mlx_draft_dir"
printf '{}' > "$final_mlx_draft_dir/config.json"
printf '{}' > "$final_mlx_draft_dir/tokenizer.json"
printf 'weights' > "$final_mlx_draft_dir/model.safetensors"

coreai_dir="$final_root/foundation-adapter.mlmodelc"
mkdir -p "$coreai_dir"
printf 'adapter' > "$coreai_dir/model.bin"

ROSS_RUNTIME_ARTIFACT_FETCH_DOWNLOADER_STATUS=hf_cli \
  "$FETCH_PLAN" --tier quickStart --target-root "$tmpdir/downloads" --search-root "$final_root" > /tmp/ross-runtime-fetch-plan.out
grep -q "lane=mlx status=present action=preflight .*path=$mlx_dir .*--runtime mlx .*--model $mlx_dir .*--preflight-only" /tmp/ross-runtime-fetch-plan.out
grep -q "lane=mlx_draft status=present action=preflight_pair .*path=$final_mlx_draft_dir .*--draft-model $final_mlx_draft_dir .*--require-draft-acceleration .*--smoke-profile mtp_quick .*--preflight-only" /tmp/ross-runtime-fetch-plan.out
grep -q "lane=coreai_adapter status=present action=preflight .*path=$coreai_dir .*--runtime coreml .*--artifact-kind foundation_adapter .*--model $coreai_dir .*--preflight-only" /tmp/ross-runtime-fetch-plan.out

echo "iOS runtime artifact fetch plan tests: PASS"

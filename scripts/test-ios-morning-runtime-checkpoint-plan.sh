#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLAN="$ROOT_DIR/scripts/ios-morning-runtime-checkpoint-plan.sh"

tmpdir="$(mktemp -d /tmp/ross-morning-plan.XXXXXX)"
trap 'rm -rf "$tmpdir" /tmp/ross-morning-plan.out' EXIT

run_expect_exit_2() {
  local description="$1"
  local expected="$2"
  shift 2
  set +e
  "$@" > /tmp/ross-morning-plan.out 2>&1
  local rc=$?
  set -e
  if [[ "$rc" -ne 2 ]]; then
    echo "FAIL: $description expected exit 2, got $rc" >&2
    cat /tmp/ross-morning-plan.out >&2 || true
    return 1
  fi
  if ! grep -q "$expected" /tmp/ross-morning-plan.out; then
    echo "FAIL: $description did not emit expected message: $expected" >&2
    cat /tmp/ross-morning-plan.out >&2 || true
    return 1
  fi
}

run_expect_exit_2 \
  "nonnumeric morning stage timeout" \
  "Stage timeout must be a positive integer" \
  "$PLAN" --device TEST_DEVICE --stage-timeout nope

run_expect_exit_2 \
  "zero morning stage timeout" \
  "Stage timeout must be a positive integer" \
  "$PLAN" --device TEST_DEVICE --stage-timeout 0

run_expect_exit_2 \
  "nonnumeric morning physical memory" \
  "Physical memory bytes must be a positive integer" \
  "$PLAN" --device TEST_DEVICE --physical-memory-bytes nope

"$PLAN" --help > /tmp/ross-morning-plan.out
grep -q "CoreDevice identifier, device name, DNS name, or UDID" /tmp/ross-morning-plan.out

"$PLAN" --device TEST_DEVICE > /tmp/ross-morning-plan.out
grep -q "Inventory gate: not provided; runtime commands are templates until installed-pack inventory proves matching artifacts for the requested tier." /tmp/ross-morning-plan.out
grep -q "0. Plan/download missing local runtime artifacts before any device work" /tmp/ross-morning-plan.out
grep -q "scripts/ios-runtime-artifact-fetch-plan.sh --tier quickStart --target-root" /tmp/ross-morning-plan.out
grep -q "MTP low-token proof" /tmp/ross-morning-plan.out
grep -q -- "--runtime gguf" /tmp/ross-morning-plan.out
grep -q -- "--runtime mlx" /tmp/ross-morning-plan.out
grep -q -- "--runtime coreai" /tmp/ross-morning-plan.out
grep -q "not draft_output_degenerate" /tmp/ross-morning-plan.out
grep -q "provider" /tmp/ross-morning-plan.out
grep -q "positive context_tokens" /tmp/ross-morning-plan.out
grep -q "gpu_offload evidence" /tmp/ross-morning-plan.out
grep -q "per-stage token/speed metrics" /tmp/ross-morning-plan.out
grep -q "native-model markers" /tmp/ross-morning-plan.out
grep -q "source refs for source-bound stages" /tmp/ross-morning-plan.out
grep -q "positive .*_draft_attempted and .*_draft_accepted" /tmp/ross-morning-plan.out
grep -q "Manual UI evidence: when validating a visible answer, open the hidden Answer Details affordance" /tmp/ross-morning-plan.out
grep -q "Tokens processed, Token speed, runtime, preferred runtime, and fallback status" /tmp/ross-morning-plan.out
grep -q -- "--preflight-only" /tmp/ross-morning-plan.out
grep -q "ROSS_SIMULATOR_SMOKE_PREFLIGHT_OK" /tmp/ross-morning-plan.out
grep -q "without launching Simulator or touching the cabled iPhone" /tmp/ross-morning-plan.out
grep -q "Full matrix cases: English source-bound document QA, Bengali source-bound document QA, Hindi source-bound document QA, Tamil source-bound document QA, Telugu source-bound document QA, and English open no-document query." /tmp/ross-morning-plan.out
if grep -q -- "--pack-id ''" /tmp/ross-morning-plan.out; then
  echo "Template morning plan must not print an empty exact pack selector" >&2
  cat /tmp/ross-morning-plan.out >&2
  exit 1
fi

tiny_gguf="$tmpdir/tiny-primary.gguf"
printf 'GGUF' > "$tiny_gguf"
"$PLAN" --device TEST_DEVICE --gguf-model "$tiny_gguf" > /tmp/ross-morning-plan.out
grep -q "2. GGUF baseline seeded quick smoke:" /tmp/ross-morning-plan.out
grep -q "SKIP reason=missing_or_invalid_primary_gguf model=$tiny_gguf" /tmp/ross-morning-plan.out
if grep -q "scripts/ios-device-gguf-smoke.sh" /tmp/ross-morning-plan.out; then
  echo "Expected tiny local GGUF to suppress baseline device smoke command" >&2
  cat /tmp/ross-morning-plan.out >&2
  exit 1
fi

draft_like_gguf="$tmpdir/mtp-gemma-4-12b-it.gguf"
python3 - "$draft_like_gguf" <<'PY'
import pathlib
import sys
pathlib.Path(sys.argv[1]).write_bytes(b"GGUF" + (b"\0" * 1000000))
PY
"$PLAN" --device TEST_DEVICE --gguf-model "$draft_like_gguf" > /tmp/ross-morning-plan.out
grep -q "2. GGUF baseline seeded quick smoke:" /tmp/ross-morning-plan.out
grep -q "SKIP reason=local_gguf_is_draft_like model=$draft_like_gguf" /tmp/ross-morning-plan.out
if grep -q "scripts/ios-device-gguf-smoke.sh" /tmp/ross-morning-plan.out; then
  echo "Expected draft-like local GGUF to suppress baseline device smoke command" >&2
  cat /tmp/ross-morning-plan.out >&2
  exit 1
fi

primary_gguf="$tmpdir/gemma-4-e4b-primary.gguf"
python3 - "$primary_gguf" <<'PY'
import pathlib
import sys
pathlib.Path(sys.argv[1]).write_bytes(b"GGUF" + (b"\0" * 1000000))
PY
"$PLAN" --device TEST_DEVICE --gguf-model "$primary_gguf" > /tmp/ross-morning-plan.out
grep -q "2. GGUF baseline seeded quick smoke:" /tmp/ross-morning-plan.out
grep -q "scripts/ios-device-gguf-smoke.sh" /tmp/ross-morning-plan.out
grep -q -- "--model $primary_gguf" /tmp/ross-morning-plan.out

support_root="$tmpdir/RossAlpha"
packs_root="$support_root/model-packs"
mkdir -p "$packs_root/quickStart"

python3 - "$support_root" <<'PY'
import json
import pathlib
import sys

support = pathlib.Path(sys.argv[1])
packs = support / "model-packs"

(packs / "quickStart" / "main.gguf").write_bytes(b"GGUF" + (b"\0" * 1_000_000))

(packs / "quickStart" / "quick.manifest.json").write_text(json.dumps({
    "packId": "quick-no-draft",
    "tier": "quick_start",
    "fileName": "main.gguf",
    "relativePath": "model-packs/quickStart/main.gguf",
    "checksumSha256": "abc",
    "bytes": 1_000_001,
    "artifactKind": "local_model_artifact",
    "runtimeMode": "gemma_local_runtime",
    "developmentOnly": False,
    "verifiedAt": "2026-06-19T00:00:00Z",
}))
PY

"$PLAN" --device TEST_DEVICE --installed-root "$support_root" > /tmp/ross-morning-plan.out
grep -q "Inventory gate: installed_root=$support_root" /tmp/ross-morning-plan.out
grep -q "3. MTP low-token proof" /tmp/ross-morning-plan.out
grep -q "SKIP reason=manifest_missing_draft_artifact" /tmp/ross-morning-plan.out
grep -q "4. MLX identity and varied document/query full smoke" /tmp/ross-morning-plan.out
grep -q "SKIP reason=missing_installed_mlx" /tmp/ross-morning-plan.out
grep -q "5. CoreAI/CoreML/Foundation varied document/query full smoke" /tmp/ross-morning-plan.out
grep -q "SKIP reason=missing_installed_coreai" /tmp/ross-morning-plan.out

wrong_tier_support_root="$tmpdir/RossAlphaWrongTier"
wrong_tier_packs_root="$wrong_tier_support_root/model-packs"
mkdir -p "$wrong_tier_packs_root/caseAssociate" "$wrong_tier_packs_root/mlx/gemma-mlx" "$wrong_tier_packs_root/coreai"
printf 'GGUF%*s' 1000000 '' > "$wrong_tier_packs_root/caseAssociate/main.gguf"
printf 'GGUF%*s' 1000000 '' > "$wrong_tier_packs_root/caseAssociate/draft.gguf"
printf '{}' > "$wrong_tier_packs_root/mlx/gemma-mlx/config.json"
printf '{}' > "$wrong_tier_packs_root/mlx/gemma-mlx/tokenizer.json"
printf 'weights' > "$wrong_tier_packs_root/mlx/gemma-mlx/model.safetensors"
python3 - "$wrong_tier_support_root" <<'PY'
import json
import pathlib
import sys

support = pathlib.Path(sys.argv[1])
packs = support / "model-packs"

(packs / "caseAssociate" / "case.manifest.json").write_text(json.dumps({
    "packId": "case-mtp",
    "tier": "case_associate",
    "fileName": "main.gguf",
    "relativePath": "model-packs/caseAssociate/main.gguf",
    "checksumSha256": "abc",
    "bytes": 1_000_001,
    "artifactKind": "local_model_artifact",
    "runtimeMode": "gemma_local_runtime",
    "developmentOnly": False,
    "draftArtifact": {
        "fileName": "draft.gguf",
        "relativePath": "model-packs/caseAssociate/draft.gguf",
        "checksumSha256": "def",
        "bytes": 1_000_001,
        "artifactKind": "local_model_artifact",
        "draftTokens": 2,
    },
    "verifiedAt": "2026-06-19T00:00:00Z",
}))

(packs / "mlx" / "mlx.manifest.json").write_text(json.dumps({
    "packId": "case-mlx",
    "tier": "case_associate",
    "fileName": "gemma-mlx",
    "relativePath": "model-packs/mlx/gemma-mlx",
    "checksumSha256": "abc",
    "bytes": 1_000_001,
    "artifactKind": "mlx_directory",
    "runtimeMode": "mlx_swift_lm",
    "developmentOnly": False,
    "verifiedAt": "2026-06-19T00:00:00Z",
}))

(packs / "coreai" / "coreai.manifest.json").write_text(json.dumps({
    "packId": "case-coreai",
    "tier": "case_associate",
    "fileName": "system-model",
    "relativePath": "system-model",
    "checksumSha256": "system",
    "bytes": 0,
    "artifactKind": "system_model",
    "runtimeMode": "apple_foundation_models",
    "developmentOnly": False,
    "verifiedAt": "2026-06-19T00:00:00Z",
}))
PY

"$PLAN" --device TEST_DEVICE --installed-root "$wrong_tier_support_root" --tier quickStart > /tmp/ross-morning-plan.out
grep -q "SKIP reason=missing_installed_mtp_primary_or_draft_for_tier" /tmp/ross-morning-plan.out
grep -q "SKIP reason=missing_installed_mlx_for_tier" /tmp/ross-morning-plan.out
grep -q "SKIP reason=missing_installed_coreai_for_tier" /tmp/ross-morning-plan.out
if grep -q -- "--require-draft-acceleration" /tmp/ross-morning-plan.out ||
   grep -q -- "--runtime mlx" /tmp/ross-morning-plan.out ||
   grep -q -- "--runtime coreai" /tmp/ross-morning-plan.out; then
  echo "Expected wrong-tier inventory to skip runtime lanes for quickStart" >&2
  cat /tmp/ross-morning-plan.out >&2
  exit 1
fi

multi_pack_support_root="$tmpdir/RossAlphaMultiPack"
multi_pack_packs_root="$multi_pack_support_root/model-packs"
mkdir -p "$multi_pack_packs_root/quickStartA" "$multi_pack_packs_root/quickStartB" \
  "$multi_pack_packs_root/mlxA/gemma-mlx" "$multi_pack_packs_root/mlxB/gemma-mlx" \
  "$multi_pack_packs_root/coreaiA" "$multi_pack_packs_root/coreaiB"
printf 'GGUF%*s' 1000000 '' > "$multi_pack_packs_root/quickStartA/main.gguf"
printf 'GGUF%*s' 1000000 '' > "$multi_pack_packs_root/quickStartA/draft.gguf"
printf 'GGUF%*s' 1000000 '' > "$multi_pack_packs_root/quickStartB/main.gguf"
printf 'GGUF%*s' 1000000 '' > "$multi_pack_packs_root/quickStartB/draft.gguf"
for mlx_dir in "$multi_pack_packs_root/mlxA/gemma-mlx" "$multi_pack_packs_root/mlxB/gemma-mlx"; do
  printf '{}' > "$mlx_dir/config.json"
  printf '{}' > "$mlx_dir/tokenizer.json"
  printf 'weights' > "$mlx_dir/model.safetensors"
done
python3 - "$multi_pack_support_root" <<'PY'
import json
import pathlib
import sys

support = pathlib.Path(sys.argv[1])
packs = support / "model-packs"

for suffix in ("A", "B"):
    (packs / f"quickStart{suffix}" / f"quick-{suffix}.manifest.json").write_text(json.dumps({
        "packId": f"quick-mtp-{suffix.lower()}",
        "tier": "quick_start",
        "fileName": "main.gguf",
        "relativePath": f"model-packs/quickStart{suffix}/main.gguf",
        "checksumSha256": f"abc-{suffix}",
        "bytes": 1_000_001,
        "artifactKind": "local_model_artifact",
        "runtimeMode": "gemma_local_runtime",
        "developmentOnly": False,
        "draftArtifact": {
            "fileName": "draft.gguf",
            "relativePath": f"model-packs/quickStart{suffix}/draft.gguf",
            "checksumSha256": f"def-{suffix}",
            "bytes": 1_000_001,
            "artifactKind": "local_model_artifact",
            "draftTokens": 2,
        },
        "verifiedAt": "2026-06-19T00:00:00Z",
    }))

    (packs / f"mlx{suffix}" / f"mlx-{suffix}.manifest.json").write_text(json.dumps({
        "packId": f"mlx-pack-{suffix.lower()}",
        "tier": "quick_start",
        "fileName": "gemma-mlx",
        "relativePath": f"model-packs/mlx{suffix}/gemma-mlx",
        "checksumSha256": f"mlx-{suffix}",
        "bytes": 1_000_001,
        "artifactKind": "mlx_directory",
        "runtimeMode": "mlx_swift_lm",
        "developmentOnly": False,
        "verifiedAt": "2026-06-19T00:00:00Z",
    }))

    (packs / f"coreai{suffix}" / f"coreai-{suffix}.manifest.json").write_text(json.dumps({
        "packId": f"coreai-system-{suffix.lower()}",
        "tier": "quick_start",
        "fileName": "system-model",
        "relativePath": "system-model",
        "checksumSha256": "system",
        "bytes": 0,
        "artifactKind": "system_model",
        "runtimeMode": "apple_foundation_models",
        "developmentOnly": False,
        "verifiedAt": "2026-06-19T00:00:00Z",
    }))
PY

"$PLAN" --device TEST_DEVICE --installed-root "$multi_pack_support_root" --tier quickStart > /tmp/ross-morning-plan.out
grep -q "SKIP reason=multiple_installed_mtp_pairs_for_tier" /tmp/ross-morning-plan.out
grep -q "SKIP reason=multiple_installed_mlx_for_tier" /tmp/ross-morning-plan.out
grep -q "SKIP reason=multiple_installed_coreai_for_tier" /tmp/ross-morning-plan.out
if grep -q -- "--require-draft-acceleration" /tmp/ross-morning-plan.out ||
   grep -q -- "--runtime mlx" /tmp/ross-morning-plan.out ||
   grep -q -- "--runtime coreai" /tmp/ross-morning-plan.out; then
  echo "Expected multi-pack inventory to skip ambiguous runtime lanes for quickStart" >&2
  cat /tmp/ross-morning-plan.out >&2
  exit 1
fi

broken_mtp_support_root="$tmpdir/RossAlphaBrokenMTP"
broken_mtp_packs_root="$broken_mtp_support_root/model-packs"
mkdir -p "$broken_mtp_packs_root/quickStart"
printf 'GGUF' > "$broken_mtp_packs_root/quickStart/main.gguf"
printf 'GGUF%*s' 1000000 '' > "$broken_mtp_packs_root/quickStart/draft.gguf"
python3 - "$broken_mtp_support_root" <<'PY'
import json
import pathlib
import sys

support = pathlib.Path(sys.argv[1])
packs = support / "model-packs"

(packs / "quickStart" / "broken-primary.manifest.json").write_text(json.dumps({
    "packId": "broken-mtp-primary",
    "tier": "quick_start",
    "fileName": "main.gguf",
    "relativePath": "model-packs/quickStart/main.gguf",
    "checksumSha256": "abc",
    "bytes": 4,
    "artifactKind": "local_model_artifact",
    "runtimeMode": "gemma_local_runtime",
    "developmentOnly": False,
    "draftArtifact": {
        "fileName": "draft.gguf",
        "relativePath": "model-packs/quickStart/draft.gguf",
        "checksumSha256": "def",
        "bytes": 1_000_001,
        "artifactKind": "local_model_artifact",
        "draftTokens": 2,
    },
    "verifiedAt": "2026-06-19T00:00:00Z",
}))
PY

"$PLAN" --device TEST_DEVICE --installed-root "$broken_mtp_support_root" --tier quickStart > /tmp/ross-morning-plan.out
grep -q "SKIP reason=manifest_primary_unusable_artifact" /tmp/ross-morning-plan.out
if grep -q -- "--require-draft-acceleration" /tmp/ross-morning-plan.out; then
  echo "Expected broken installed GGUF primary to suppress MTP proof command even with reachable draft" >&2
  cat /tmp/ross-morning-plan.out >&2
  exit 1
fi

split_mtp_support_root="$tmpdir/RossAlphaSplitMTP"
split_mtp_packs_root="$split_mtp_support_root/model-packs"
mkdir -p "$split_mtp_packs_root/goodPrimary" "$split_mtp_packs_root/brokenDraftPack"
printf 'GGUF%*s' 1000000 '' > "$split_mtp_packs_root/goodPrimary/main.gguf"
printf 'NOPE' > "$split_mtp_packs_root/brokenDraftPack/main.gguf"
printf 'GGUF%*s' 1000000 '' > "$split_mtp_packs_root/brokenDraftPack/draft.gguf"
python3 - "$split_mtp_support_root" <<'PY'
import json
import pathlib
import sys

support = pathlib.Path(sys.argv[1])
packs = support / "model-packs"

(packs / "goodPrimary" / "good-primary.manifest.json").write_text(json.dumps({
    "packId": "good-primary-no-draft",
    "tier": "quick_start",
    "fileName": "main.gguf",
    "relativePath": "model-packs/goodPrimary/main.gguf",
    "checksumSha256": "abc",
    "bytes": 1_000_001,
    "artifactKind": "local_model_artifact",
    "runtimeMode": "gemma_local_runtime",
    "developmentOnly": False,
    "verifiedAt": "2026-06-19T00:00:00Z",
}))

(packs / "brokenDraftPack" / "broken-primary-with-draft.manifest.json").write_text(json.dumps({
    "packId": "broken-primary-with-draft",
    "tier": "quick_start",
    "fileName": "main.gguf",
    "relativePath": "model-packs/brokenDraftPack/main.gguf",
    "checksumSha256": "abc",
    "bytes": 4,
    "artifactKind": "local_model_artifact",
    "runtimeMode": "gemma_local_runtime",
    "developmentOnly": False,
    "draftArtifact": {
        "fileName": "draft.gguf",
        "relativePath": "model-packs/brokenDraftPack/draft.gguf",
        "checksumSha256": "def",
        "bytes": 1_000_001,
        "artifactKind": "local_model_artifact",
        "draftTokens": 2,
    },
    "verifiedAt": "2026-06-19T00:00:00Z",
}))
PY

"$PLAN" --device TEST_DEVICE --installed-root "$split_mtp_support_root" --tier quickStart > /tmp/ross-morning-plan.out
grep -q "SKIP reason=manifest_primary_unusable_artifact" /tmp/ross-morning-plan.out
if grep -q -- "--require-draft-acceleration" /tmp/ross-morning-plan.out; then
  echo "Expected split-pack MTP evidence to suppress MTP proof command" >&2
  cat /tmp/ross-morning-plan.out >&2
  exit 1
fi

memory_blocked_support_root="$tmpdir/RossAlphaMemoryBlockedMTP"
memory_blocked_packs_root="$memory_blocked_support_root/model-packs"
mkdir -p "$memory_blocked_packs_root/quickStart"
printf 'GGUF' > "$memory_blocked_packs_root/quickStart/gemma-4-E4B-it-UD-Q4_K_XL.gguf"
truncate -s 5130000000 "$memory_blocked_packs_root/quickStart/gemma-4-E4B-it-UD-Q4_K_XL.gguf"
printf 'GGUF' > "$memory_blocked_packs_root/quickStart/mtp-gemma-4-E4B-it.gguf"
truncate -s 79000000 "$memory_blocked_packs_root/quickStart/mtp-gemma-4-E4B-it.gguf"
python3 - "$memory_blocked_support_root" <<'PY'
import json
import pathlib
import sys

support = pathlib.Path(sys.argv[1])
packs = support / "model-packs"

(packs / "quickStart" / "memory-blocked.manifest.json").write_text(json.dumps({
    "packId": "quick-e4b-memory-blocked",
    "tier": "quick_start",
    "fileName": "gemma-4-E4B-it-UD-Q4_K_XL.gguf",
    "relativePath": "model-packs/quickStart/gemma-4-E4B-it-UD-Q4_K_XL.gguf",
    "checksumSha256": "abc",
    "bytes": 5_130_000_000,
    "artifactKind": "local_model_artifact",
    "runtimeMode": "gemma_local_runtime",
    "developmentOnly": False,
    "draftArtifact": {
        "fileName": "mtp-gemma-4-E4B-it.gguf",
        "relativePath": "model-packs/quickStart/mtp-gemma-4-E4B-it.gguf",
        "checksumSha256": "def",
        "bytes": 79_000_000,
        "artifactKind": "local_model_artifact",
        "draftTokens": 2,
    },
    "verifiedAt": "2026-06-19T00:00:00Z",
}))
PY

"$PLAN" --device TEST_DEVICE --installed-root "$memory_blocked_support_root" --tier quickStart --physical-memory-bytes 7200000000 > /tmp/ross-morning-plan.out
grep -q "Inventory MTP memory gate: physical_memory_bytes=7200000000" /tmp/ross-morning-plan.out
grep -q "SKIP reason=manifest_draft_memory_policy_blocked" /tmp/ross-morning-plan.out
if grep -q -- "--require-draft-acceleration" /tmp/ross-morning-plan.out; then
  echo "Expected memory-blocked E4B MTP pair to suppress MTP proof command" >&2
  cat /tmp/ross-morning-plan.out >&2
  exit 1
fi

unsupported_mlx_support_root="$tmpdir/RossAlphaUnsupportedMLX"
unsupported_mlx_packs_root="$unsupported_mlx_support_root/model-packs"
mkdir -p "$unsupported_mlx_packs_root/mlx/gemma-4-E4B-it-qat-4bit"
printf '{}' > "$unsupported_mlx_packs_root/mlx/gemma-4-E4B-it-qat-4bit/tokenizer.json"
printf 'weights' > "$unsupported_mlx_packs_root/mlx/gemma-4-E4B-it-qat-4bit/model.safetensors"
python3 - "$unsupported_mlx_support_root" <<'PY'
import json
import pathlib
import sys

support = pathlib.Path(sys.argv[1])
packs = support / "model-packs"
mlx_dir = packs / "mlx" / "gemma-4-E4B-it-qat-4bit"
(mlx_dir / "config.json").write_text(json.dumps({
    "model_type": "gemma4",
    "architectures": ["Gemma4ForConditionalGeneration"],
    "vision_config": {},
}))

(packs / "mlx" / "mlx.manifest.json").write_text(json.dumps({
    "packId": "quick-unsupported-mlx",
    "tier": "quick_start",
    "fileName": "gemma-4-E4B-it-qat-4bit",
    "relativePath": "model-packs/mlx/gemma-4-E4B-it-qat-4bit",
    "checksumSha256": "abc",
    "bytes": 1_000_001,
    "artifactKind": "mlx_directory",
    "runtimeMode": "mlx_swift_lm",
    "developmentOnly": False,
    "verifiedAt": "2026-06-19T00:00:00Z",
}))
PY

"$PLAN" --device TEST_DEVICE --installed-root "$unsupported_mlx_support_root" --tier quickStart > /tmp/ross-morning-plan.out
grep -q "4. MLX identity and varied document/query full smoke" /tmp/ross-morning-plan.out
grep -q "SKIP reason=unsupported_gemma4_multimodal" /tmp/ross-morning-plan.out
if grep -q -- "--runtime mlx" /tmp/ross-morning-plan.out; then
  echo "Expected unsupported installed MLX archive to suppress MLX device smoke command" >&2
  cat /tmp/ross-morning-plan.out >&2
  exit 1
fi

mkdir -p "$packs_root/mlx/gemma-mlx"
printf '{}' > "$packs_root/mlx/gemma-mlx/config.json"
printf '{}' > "$packs_root/mlx/gemma-mlx/tokenizer.json"
printf 'weights' > "$packs_root/mlx/gemma-mlx/model.safetensors"
printf 'GGUF%*s' 1000000 '' > "$packs_root/quickStart/draft.gguf"

python3 - "$support_root" <<'PY'
import json
import pathlib
import sys

support = pathlib.Path(sys.argv[1])
packs = support / "model-packs"

(packs / "quickStart" / "quick.manifest.json").write_text(json.dumps({
    "packId": "quick-mtp",
    "tier": "quick_start",
    "fileName": "main.gguf",
    "relativePath": "model-packs/quickStart/main.gguf",
    "checksumSha256": "abc",
    "bytes": 1_000_001,
    "artifactKind": "local_model_artifact",
    "runtimeMode": "gemma_local_runtime",
    "developmentOnly": False,
    "draftArtifact": {
        "fileName": "draft.gguf",
        "relativePath": "model-packs/quickStart/draft.gguf",
        "checksumSha256": "def",
        "bytes": 1_000_001,
        "artifactKind": "local_model_artifact",
        "draftTokens": 2,
    },
    "verifiedAt": "2026-06-19T00:00:00Z",
}))

(packs / "mlx" / "mlx.manifest.json").write_text(json.dumps({
    "packId": "mlx-pack",
    "tier": "quick_start",
    "fileName": "gemma-mlx",
    "relativePath": "model-packs/mlx/gemma-mlx",
    "checksumSha256": "abc",
    "bytes": 1_000_001,
    "artifactKind": "mlx_directory",
    "runtimeMode": "mlx_swift_lm",
    "developmentOnly": False,
    "verifiedAt": "2026-06-19T00:00:00Z",
}))

(packs / "coreai" / "coreai.manifest.json").parent.mkdir(parents=True, exist_ok=True)
(packs / "coreai" / "coreai.manifest.json").write_text(json.dumps({
    "packId": "coreai-system",
    "tier": "quick_start",
    "fileName": "system-model",
    "relativePath": "system-model",
    "checksumSha256": "system",
    "bytes": 0,
    "artifactKind": "system_model",
    "runtimeMode": "apple_foundation_models",
    "developmentOnly": False,
    "verifiedAt": "2026-06-19T00:00:00Z",
}))
PY

"$PLAN" --device TEST_DEVICE --installed-root "$support_root" > /tmp/ross-morning-plan.out
grep -q -- "--runtime gguf" /tmp/ross-morning-plan.out
grep -q -- "--require-draft-acceleration" /tmp/ross-morning-plan.out
grep -q -- "--runtime mlx" /tmp/ross-morning-plan.out
grep -q -- "--runtime coreai" /tmp/ross-morning-plan.out
grep -q -- "--pack-id quick-mtp" /tmp/ross-morning-plan.out
grep -q -- "--pack-id mlx-pack" /tmp/ross-morning-plan.out
grep -q -- "--pack-id coreai-system" /tmp/ross-morning-plan.out
grep -q -- "--smoke-profile quick_low_context" /tmp/ross-morning-plan.out
if [[ "$(grep -c -- "--smoke-profile full" /tmp/ross-morning-plan.out)" -ne 2 ]]; then
  echo "Expected MLX and CoreAI ready lanes to request the full varied profile" >&2
  cat /tmp/ross-morning-plan.out >&2
  exit 1
fi
grep -q -- "--smoke-profile mtp_quick" /tmp/ross-morning-plan.out
if grep -q -- "--allow-device-proof-pack" /tmp/ross-morning-plan.out; then
  echo "Morning MTP proof plan must not allow seeded device-proof packs" >&2
  cat /tmp/ross-morning-plan.out >&2
  exit 1
fi
if grep -q "SKIP reason=" /tmp/ross-morning-plan.out; then
  echo "Expected ready inventory plan to avoid runtime SKIP lines" >&2
  cat /tmp/ross-morning-plan.out >&2
  exit 1
fi

"$PLAN" --device TEST_DEVICE --installed-root "$support_root" --physical-memory-bytes 12000000000 > /tmp/ross-morning-plan.out
grep -q "Inventory MTP memory gate: physical_memory_bytes=12000000000" /tmp/ross-morning-plan.out
grep -q "scripts/ios-runtime-artifact-fetch-plan.sh --tier quickStart .*--physical-memory-bytes 12000000000" /tmp/ross-morning-plan.out
if [[ "$(grep -c -- "--physical-memory-bytes 12000000000" /tmp/ross-morning-plan.out)" -ne 4 ]]; then
  echo "Expected ready installed-pack runtime commands to preserve physical memory guard" >&2
  cat /tmp/ross-morning-plan.out >&2
  exit 1
fi
grep -q -- "--runtime gguf --tier quickStart --pack-id quick-mtp --smoke-profile mtp_quick --stage-timeout 45 --require-draft-acceleration --physical-memory-bytes 12000000000" /tmp/ross-morning-plan.out
grep -q -- "--runtime mlx --tier quickStart --pack-id mlx-pack --smoke-profile full --stage-timeout 45 --physical-memory-bytes 12000000000" /tmp/ross-morning-plan.out
grep -q -- "--runtime coreai --tier quickStart --pack-id coreai-system --smoke-profile full --stage-timeout 45 --physical-memory-bytes 12000000000" /tmp/ross-morning-plan.out

echo "iOS morning runtime checkpoint plan tests: PASS"

#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLAN="$ROOT_DIR/scripts/ios-morning-runtime-checkpoint-plan.sh"

tmpdir="$(mktemp -d /tmp/ross-morning-plan.XXXXXX)"
trap 'rm -rf "$tmpdir" /tmp/ross-morning-plan.out' EXIT

"$PLAN" --device TEST_DEVICE > /tmp/ross-morning-plan.out
grep -q "Inventory gate: not provided; runtime commands are templates until installed-pack inventory proves matching artifacts for the requested tier." /tmp/ross-morning-plan.out
grep -q "MTP low-token proof" /tmp/ross-morning-plan.out
grep -q -- "--runtime gguf" /tmp/ross-morning-plan.out
grep -q -- "--runtime mlx" /tmp/ross-morning-plan.out
grep -q -- "--runtime coreai" /tmp/ross-morning-plan.out
grep -q "not draft_output_degenerate" /tmp/ross-morning-plan.out
grep -q "per-stage token/speed metrics" /tmp/ross-morning-plan.out
grep -q "native-model markers" /tmp/ross-morning-plan.out
grep -q "source refs for source-bound stages" /tmp/ross-morning-plan.out
grep -q -- "--preflight-only" /tmp/ross-morning-plan.out
grep -q "ROSS_SIMULATOR_SMOKE_PREFLIGHT_OK" /tmp/ross-morning-plan.out
grep -q "without launching Simulator or touching the cabled iPhone" /tmp/ross-morning-plan.out
grep -q "Full matrix cases: English source-bound document QA, Bengali source-bound document QA, Hindi source-bound document QA, Tamil source-bound document QA, Telugu source-bound document QA, and English open no-document query." /tmp/ross-morning-plan.out

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

echo "iOS morning runtime checkpoint plan tests: PASS"

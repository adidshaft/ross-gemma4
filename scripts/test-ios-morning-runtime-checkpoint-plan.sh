#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLAN="$ROOT_DIR/scripts/ios-morning-runtime-checkpoint-plan.sh"

tmpdir="$(mktemp -d /tmp/ross-morning-plan.XXXXXX)"
trap 'rm -rf "$tmpdir" /tmp/ross-morning-plan.out' EXIT

"$PLAN" --device TEST_DEVICE > /tmp/ross-morning-plan.out
grep -q "MTP low-token proof" /tmp/ross-morning-plan.out
grep -q -- "--runtime gguf" /tmp/ross-morning-plan.out
grep -q -- "--runtime mlx" /tmp/ross-morning-plan.out
grep -q -- "--runtime coreai" /tmp/ross-morning-plan.out

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
    "tier": "quickStart",
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
grep -q "4. MLX identity" /tmp/ross-morning-plan.out
grep -q "SKIP reason=missing_installed_mlx" /tmp/ross-morning-plan.out
grep -q "5. CoreAI" /tmp/ross-morning-plan.out
grep -q "SKIP reason=missing_installed_coreai" /tmp/ross-morning-plan.out

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
    "tier": "quickStart",
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
    "tier": "quickStart",
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
    "tier": "quickStart",
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
if grep -q "SKIP reason=" /tmp/ross-morning-plan.out; then
  echo "Expected ready inventory plan to avoid runtime SKIP lines" >&2
  cat /tmp/ross-morning-plan.out >&2
  exit 1
fi

echo "iOS morning runtime checkpoint plan tests: PASS"

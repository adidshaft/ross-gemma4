#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INVENTORY="$ROOT_DIR/scripts/ios-runtime-artifact-inventory.sh"

tmpdir="$(mktemp -d /tmp/ross-runtime-inventory.XXXXXX)"
trap 'rm -rf "$tmpdir" /tmp/ross-runtime-inventory.out' EXIT

"$INVENTORY" --search-root "$tmpdir" > /tmp/ross-runtime-inventory.out
grep -q "lane=gguf status=missing" /tmp/ross-runtime-inventory.out
grep -q "lane=mtp_draft status=missing" /tmp/ross-runtime-inventory.out
grep -q "lane=mlx status=missing" /tmp/ross-runtime-inventory.out
grep -q "lane=coreai_adapter status=missing" /tmp/ross-runtime-inventory.out
grep -q "lane=coreai_system status=unknown path=system-model" /tmp/ross-runtime-inventory.out
grep -q "lane=catalog_mtp_draft status=expected .*tier=quickStart .*file=mtp-gemma-4-E4B-it.gguf" /tmp/ross-runtime-inventory.out
grep -q "lane=catalog_mtp_draft status=expected .*tier=caseAssociate .*file=mtp-gemma-4-12b-it.gguf" /tmp/ross-runtime-inventory.out
grep -q "lane=catalog_mtp_draft status=expected .*tier=caseAssociate .*checksum=145db9094bc0f85f1701e255a2ed216dcc9800fc8bc8631ad00905b456bd451b" /tmp/ross-runtime-inventory.out

python3 - "$tmpdir/main.gguf" "$tmpdir/gemma-draft.gguf" <<'PY'
import pathlib
import sys
for raw_path in sys.argv[1:]:
    pathlib.Path(raw_path).write_bytes(b"GGUF" + (b"\0" * 1000000))
PY

mlx_dir="$tmpdir/model.mlx"
mkdir -p "$mlx_dir"
printf '{}' > "$mlx_dir/config.json"
printf '{}' > "$mlx_dir/tokenizer.json"
printf 'weights' > "$mlx_dir/model.safetensors"

mkdir -p "$tmpdir/foundation-adapter.mlmodelc"

"$INVENTORY" --search-root "$tmpdir" > /tmp/ross-runtime-inventory.out
grep -q "lane=gguf status=present" /tmp/ross-runtime-inventory.out
grep -q "lane=mtp_draft status=present" /tmp/ross-runtime-inventory.out
grep -q "lane=mlx status=present" /tmp/ross-runtime-inventory.out
grep -q "lane=coreai_adapter status=present" /tmp/ross-runtime-inventory.out

tiny="$tmpdir/tiny-draft.gguf"
printf 'GGUF' > "$tiny"
rm -f "$tmpdir/gemma-draft.gguf"
"$INVENTORY" --search-root "$tmpdir" > /tmp/ross-runtime-inventory.out
grep -q "lane=mtp_draft status=missing" /tmp/ross-runtime-inventory.out

support_root="$tmpdir/RossAlpha"
packs_root="$support_root/model-packs"
mkdir -p "$packs_root/quickStart" "$packs_root/caseAssociate" "$packs_root/mlx" "$packs_root/coreai"
python3 - "$support_root" <<'PY'
import json
import pathlib
import sys

support = pathlib.Path(sys.argv[1])
packs = support / "model-packs"

def write(path, payload):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload))

(packs / "quickStart" / "main.gguf").write_bytes(b"GGUF" + (b"\0" * 1000000))
(packs / "quickStart" / "draft.gguf").write_bytes(b"GGUF" + (b"\0" * 1000000))
(packs / "caseAssociate" / "main.gguf").write_bytes(b"GGUF" + (b"\0" * 1000000))

mlx_dir = packs / "mlx" / "gemma-mlx"
mlx_dir.mkdir(parents=True, exist_ok=True)
(mlx_dir / "config.json").write_text("{}")
(mlx_dir / "tokenizer.json").write_text("{}")
(mlx_dir / "model.safetensors").write_text("weights")

write(
    packs / "quickStart" / "quick.manifest.json",
    {
        "packId": "quick-mtp",
        "tier": "quickStart",
        "fileName": "main.gguf",
        "relativePath": "model-packs/quickStart/main.gguf",
        "checksumSha256": "abc",
        "bytes": 1000001,
        "artifactKind": "local_model_artifact",
        "runtimeMode": "gemma_local_runtime",
        "developmentOnly": False,
        "draftArtifact": {
            "fileName": "draft.gguf",
            "relativePath": "model-packs/quickStart/draft.gguf",
            "checksumSha256": "def",
            "bytes": 1000001,
            "artifactKind": "local_model_artifact",
            "draftTokens": 2,
        },
        "verifiedAt": "2026-06-19T00:00:00Z",
    },
)
write(
    packs / "caseAssociate" / "case.manifest.json",
    {
        "packId": "case-no-draft",
        "tier": "caseAssociate",
        "fileName": "main.gguf",
        "relativePath": "model-packs/caseAssociate/main.gguf",
        "checksumSha256": "abc",
        "bytes": 1000001,
        "artifactKind": "local_model_artifact",
        "runtimeMode": "gemma_local_runtime",
        "developmentOnly": False,
        "verifiedAt": "2026-06-19T00:00:00Z",
    },
)
write(
    packs / "mlx" / "mlx.manifest.json",
    {
        "packId": "mlx-pack",
        "tier": "quickStart",
        "fileName": "gemma-mlx",
        "relativePath": "model-packs/mlx/gemma-mlx",
        "checksumSha256": "abc",
        "bytes": 1000001,
        "artifactKind": "mlx_directory",
        "runtimeMode": "mlx_swift_lm",
        "developmentOnly": False,
        "draftArtifact": {
            "fileName": "missing-draft",
            "relativePath": "model-packs/mlx/missing-draft",
            "checksumSha256": "def",
            "bytes": 1000001,
            "artifactKind": "mlx_directory",
            "draftTokens": 2,
        },
        "verifiedAt": "2026-06-19T00:00:00Z",
    },
)
write(
    packs / "coreai" / "coreai.manifest.json",
    {
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
    },
)
PY

"$INVENTORY" --search-root "$tmpdir/empty-search-root" --installed-root "$support_root" > /tmp/ross-runtime-inventory.out
grep -q "lane=installed_packs status=present" /tmp/ross-runtime-inventory.out
grep -q "lane=installed_gguf status=present .*pack=quick-mtp" /tmp/ross-runtime-inventory.out
grep -q "lane=installed_mtp_draft status=present .*reason=manifest_draft_reachable .*pack=quick-mtp" /tmp/ross-runtime-inventory.out
grep -q "lane=installed_mtp_draft status=missing .*reason=manifest_missing_draft_artifact .*pack=case-no-draft" /tmp/ross-runtime-inventory.out
grep -q "lane=installed_mlx status=present .*pack=mlx-pack" /tmp/ross-runtime-inventory.out
grep -q "lane=installed_mlx_draft status=missing .*reason=manifest_draft_file_missing .*pack=mlx-pack" /tmp/ross-runtime-inventory.out
grep -q "lane=installed_coreai status=present .*path_type=system" /tmp/ross-runtime-inventory.out

bad_support_root="$tmpdir/RossAlphaBad"
bad_packs_root="$bad_support_root/model-packs"
mkdir -p "$bad_packs_root/quickStart" "$bad_packs_root/mlx/bad-mlx"
printf 'GGUF' > "$bad_packs_root/quickStart/main.gguf"
printf 'GGUF' > "$bad_packs_root/quickStart/draft.gguf"
printf '{}' > "$bad_packs_root/mlx/bad-mlx/config.json"
python3 - "$bad_support_root" <<'PY'
import json
import pathlib
import sys

support = pathlib.Path(sys.argv[1])
packs = support / "model-packs"

(packs / "quickStart" / "bad.manifest.json").write_text(json.dumps({
    "packId": "bad-mtp",
    "tier": "quickStart",
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
        "bytes": 4,
        "artifactKind": "local_model_artifact",
        "draftTokens": 2,
    },
    "verifiedAt": "2026-06-19T00:00:00Z",
}))

(packs / "mlx" / "bad.manifest.json").write_text(json.dumps({
    "packId": "bad-mlx",
    "tier": "quickStart",
    "fileName": "bad-mlx",
    "relativePath": "model-packs/mlx/bad-mlx",
    "checksumSha256": "abc",
    "bytes": 10,
    "artifactKind": "mlx_directory",
    "runtimeMode": "mlx_swift_lm",
    "developmentOnly": False,
    "verifiedAt": "2026-06-19T00:00:00Z",
}))
PY

"$INVENTORY" --search-root "$tmpdir/empty-search-root" --installed-root "$bad_support_root" > /tmp/ross-runtime-inventory.out
grep -q "lane=installed_gguf status=missing .*reason=manifest_primary_unusable_artifact .*pack=bad-mtp" /tmp/ross-runtime-inventory.out
grep -q "lane=installed_mtp_draft status=missing .*reason=manifest_draft_unusable_artifact .*pack=bad-mtp" /tmp/ross-runtime-inventory.out
grep -q "lane=installed_mlx status=missing .*reason=manifest_primary_unusable_artifact .*pack=bad-mlx" /tmp/ross-runtime-inventory.out

echo "iOS runtime artifact inventory tests: PASS"

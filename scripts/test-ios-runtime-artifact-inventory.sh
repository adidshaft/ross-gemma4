#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INVENTORY="$ROOT_DIR/scripts/ios-runtime-artifact-inventory.sh"

tmpdir="$(mktemp -d /tmp/ross-runtime-inventory.XXXXXX)"
trap 'rm -rf "$tmpdir" /tmp/ross-runtime-inventory.out' EXIT

set +e
"$INVENTORY" --physical-memory-bytes nope > /tmp/ross-runtime-inventory.out 2>&1
invalid_memory_rc=$?
set -e
if [[ "$invalid_memory_rc" -ne 2 ]]; then
  echo "Expected invalid physical memory inventory argument to exit 2" >&2
  cat /tmp/ross-runtime-inventory.out >&2 || true
  exit 1
fi
grep -q "Physical memory bytes must be a positive integer" /tmp/ross-runtime-inventory.out

"$INVENTORY" --search-root "$tmpdir" > /tmp/ross-runtime-inventory.out
grep -q "lane=gguf status=missing" /tmp/ross-runtime-inventory.out
grep -q "lane=mtp_draft status=missing" /tmp/ross-runtime-inventory.out
grep -q "lane=mlx status=missing" /tmp/ross-runtime-inventory.out
grep -q "lane=mlx_draft status=missing" /tmp/ross-runtime-inventory.out
grep -q "lane=coreai_adapter status=missing" /tmp/ross-runtime-inventory.out
grep -q "lane=coreai_system status=unknown path=system-model .*runtime=apple_foundation_models .*artifact_kind=system_model .*preflight_hint=simulator_system_model_preflight" /tmp/ross-runtime-inventory.out
grep -q "lane=catalog_mtp_draft status=expected .*tier=quickStart .*file=mtp-gemma-4-E4B-it.gguf" /tmp/ross-runtime-inventory.out
grep -q "lane=catalog_mtp_draft status=expected .*tier=caseAssociate .*file=mtp-gemma-4-12b-it.gguf" /tmp/ross-runtime-inventory.out
grep -q "lane=catalog_mtp_draft status=expected .*tier=caseAssociate .*checksum=145db9094bc0f85f1701e255a2ed216dcc9800fc8bc8631ad00905b456bd451b" /tmp/ross-runtime-inventory.out
grep -q "lane=catalog_mlx status=expected .*tier=quickStart .*pack=gemma-4-e4b-mlx .*file=gemma-4-E4B-it-qat-4bit" /tmp/ross-runtime-inventory.out
grep -q "lane=catalog_mlx_draft status=expected .*tier=quickStart .*pack=gemma-4-e4b-mlx-assistant .*file=gemma-4-E4B-it-qat-assistant-6bit" /tmp/ross-runtime-inventory.out
grep -q "lane=catalog_mlx status=expected .*tier=caseAssociate .*pack=gemma-4-12b-mlx .*file=gemma-4-12B-it-qat-4bit" /tmp/ross-runtime-inventory.out
grep -q "lane=catalog_mlx_draft status=expected .*tier=caseAssociate .*pack=gemma-4-12b-mlx-assistant .*file=gemma-4-12B-it-qat-assistant-4bit" /tmp/ross-runtime-inventory.out
grep -q "lane=catalog_mlx status=expected .*tier=quickStart .*checksum=2da1fd6bb6401c3ef116ac921dca88f73e4901a80ab10a4e8b21563412dbe23c" /tmp/ross-runtime-inventory.out
grep -q "lane=catalog_mlx status=expected .*repo=mlx-community/gemma-4-E4B-it-qat-4bit .*target_dir='~/model-artifacts/gemma-4-E4B-it-qat-4bit' .*acquisition_hint=hf_download_mlx_directory .*preflight_hint=simulator_mlx_directory_preflight" /tmp/ross-runtime-inventory.out
grep -q "lane=catalog_mlx_draft status=expected .*repo=mlx-community/gemma-4-E4B-it-qat-assistant-6bit .*target_dir='~/model-artifacts/gemma-4-E4B-it-qat-assistant-6bit' .*acquisition_hint=hf_download_mlx_directory" /tmp/ross-runtime-inventory.out

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
: > "$mlx_dir/model.safetensors"

mkdir -p "$tmpdir/foundation-adapter.mlmodelc"

"$INVENTORY" --search-root "$tmpdir" > /tmp/ross-runtime-inventory.out
grep -q "lane=gguf status=present" /tmp/ross-runtime-inventory.out
grep -q "lane=mtp_draft status=present" /tmp/ross-runtime-inventory.out
grep -q "lane=mlx status=missing" /tmp/ross-runtime-inventory.out

printf 'weights' > "$mlx_dir/model.safetensors"
"$INVENTORY" --search-root "$tmpdir" > /tmp/ross-runtime-inventory.out
grep -q "lane=mlx status=present" /tmp/ross-runtime-inventory.out
grep -q "lane=mlx_draft status=missing" /tmp/ross-runtime-inventory.out
grep -q "lane=coreai_adapter status=missing" /tmp/ross-runtime-inventory.out

mlx_draft_only_root="$tmpdir/mlx-draft-only"
mlx_draft_dir="$mlx_draft_only_root/gemma-4-E4B-it-qat-assistant-6bit"
mkdir -p "$mlx_draft_dir"
printf '{}' > "$mlx_draft_dir/config.json"
printf '{}' > "$mlx_draft_dir/tokenizer.json"
printf 'weights' > "$mlx_draft_dir/model.safetensors"
"$INVENTORY" --search-root "$mlx_draft_only_root" > /tmp/ross-runtime-inventory.out
grep -q "lane=mlx status=missing .*reason=no_directory_with_config_tokenizer_and_safetensors" /tmp/ross-runtime-inventory.out
grep -q "lane=mlx_draft status=present .*path=.*gemma-4-E4B-it-qat-assistant-6bit .*reason=draft_like_mlx_directory" /tmp/ross-runtime-inventory.out

printf 'adapter' > "$tmpdir/foundation-adapter.mlmodelc/model.bin"

"$INVENTORY" --search-root "$tmpdir" > /tmp/ross-runtime-inventory.out
grep -q "lane=coreai_adapter status=present" /tmp/ross-runtime-inventory.out

tiny="$tmpdir/tiny-draft.gguf"
printf 'GGUF' > "$tiny"
rm -f "$tmpdir/gemma-draft.gguf"
"$INVENTORY" --search-root "$tmpdir" > /tmp/ross-runtime-inventory.out
grep -q "lane=mtp_draft status=missing" /tmp/ross-runtime-inventory.out

draft_only_root="$tmpdir/draft-only"
mkdir -p "$draft_only_root"
python3 - "$draft_only_root/mtp-gemma-4-12b-it.gguf" <<'PY'
import pathlib
import sys
pathlib.Path(sys.argv[1]).write_bytes(b"GGUF" + (b"\0" * 1000000))
PY
"$INVENTORY" --search-root "$draft_only_root" > /tmp/ross-runtime-inventory.out
grep -q "lane=gguf status=missing .*reason=no_primary_gguf_file_with_header_and_size_over_1mb" /tmp/ross-runtime-inventory.out
grep -q "lane=mtp_draft status=present .*path=.*mtp-gemma-4-12b-it.gguf" /tmp/ross-runtime-inventory.out

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

memory_blocked_support_root="$tmpdir/RossAlphaMemoryBlocked"
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
    "tier": "quickStart",
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

"$INVENTORY" --search-root "$tmpdir/empty-search-root" --installed-root "$memory_blocked_support_root" --physical-memory-bytes 7200000000 > /tmp/ross-runtime-inventory.out
grep -q "lane=installed_gguf status=present .*pack=quick-e4b-memory-blocked" /tmp/ross-runtime-inventory.out
grep -q "lane=installed_mtp_draft status=missing .*reason=manifest_draft_memory_policy_blocked .*pack=quick-e4b-memory-blocked" /tmp/ross-runtime-inventory.out
grep -q "physical_memory=7200000000" /tmp/ross-runtime-inventory.out
grep -q "main_bytes=5130000000" /tmp/ross-runtime-inventory.out
grep -q "draft_bytes=79000000" /tmp/ross-runtime-inventory.out
grep -q "max_combined_bytes=5184000000" /tmp/ross-runtime-inventory.out

"$INVENTORY" --search-root "$tmpdir/empty-search-root" --installed-root "$memory_blocked_support_root" --physical-memory-bytes 12000000000 > /tmp/ross-runtime-inventory.out
grep -q "lane=installed_mtp_draft status=present .*reason=manifest_draft_reachable .*pack=quick-e4b-memory-blocked" /tmp/ross-runtime-inventory.out

bad_support_root="$tmpdir/RossAlphaBad"
bad_packs_root="$bad_support_root/model-packs"
mkdir -p "$bad_packs_root/quickStart" "$bad_packs_root/mlx/bad-mlx"
mkdir -p "$bad_packs_root/coreai/empty-adapter.mlmodelc"
printf 'GGUF' > "$bad_packs_root/quickStart/main.gguf"
printf 'GGUF' > "$bad_packs_root/quickStart/draft.gguf"
python3 - "$bad_packs_root/quickStart/checksum-main.gguf" "$bad_packs_root/quickStart/checksum-draft.gguf" <<'PY'
import pathlib
import sys
for raw_path in sys.argv[1:]:
    pathlib.Path(raw_path).write_bytes(b"GGUF" + (b"\0" * 1000000))
PY
python3 - "$bad_packs_root/coreai/foreign-adapter.gguf" <<'PY'
import pathlib
import sys
pathlib.Path(sys.argv[1]).write_bytes(b"GGUF" + (b"\0" * 1000000))
PY
printf '{}' > "$bad_packs_root/mlx/bad-mlx/config.json"
printf '{}' > "$bad_packs_root/mlx/bad-mlx/tokenizer.json"
: > "$bad_packs_root/mlx/bad-mlx/model.safetensors"
python3 - "$bad_support_root" <<'PY'
import json
import pathlib
import hashlib
import sys

support = pathlib.Path(sys.argv[1])
packs = support / "model-packs"
wrong_checksum = hashlib.sha256(b"not the installed artifact").hexdigest()

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

(packs / "coreai" / "bad.manifest.json").parent.mkdir(parents=True, exist_ok=True)
(packs / "coreai" / "bad.manifest.json").write_text(json.dumps({
    "packId": "bad-coreai",
    "tier": "quickStart",
    "fileName": "empty-adapter.mlmodelc",
    "relativePath": "model-packs/coreai/empty-adapter.mlmodelc",
    "checksumSha256": "abc",
    "bytes": 0,
    "artifactKind": "coreml_model",
    "runtimeMode": "apple_foundation_models",
    "developmentOnly": False,
    "verifiedAt": "2026-06-19T00:00:00Z",
}))

(packs / "coreai" / "foreign.manifest.json").write_text(json.dumps({
    "packId": "foreign-coreai",
    "tier": "quickStart",
    "fileName": "foreign-adapter.gguf",
    "relativePath": "model-packs/coreai/foreign-adapter.gguf",
    "checksumSha256": "abc",
    "bytes": 1000004,
    "artifactKind": "coreml_model",
    "runtimeMode": "apple_foundation_models",
    "developmentOnly": False,
    "verifiedAt": "2026-06-19T00:00:00Z",
}))

(packs / "quickStart" / "checksum.manifest.json").write_text(json.dumps({
    "packId": "checksum-mismatch",
    "tier": "quickStart",
    "fileName": "checksum-main.gguf",
    "relativePath": "model-packs/quickStart/checksum-main.gguf",
    "checksumSha256": wrong_checksum,
    "bytes": 1000004,
    "artifactKind": "local_model_artifact",
    "runtimeMode": "gemma_local_runtime",
    "developmentOnly": False,
    "draftArtifact": {
        "fileName": "checksum-draft.gguf",
        "relativePath": "model-packs/quickStart/checksum-draft.gguf",
        "checksumSha256": wrong_checksum,
        "bytes": 1000004,
        "artifactKind": "local_model_artifact",
        "draftTokens": 2,
    },
    "verifiedAt": "2026-06-19T00:00:00Z",
}))
PY

"$INVENTORY" --search-root "$tmpdir/empty-search-root" --installed-root "$bad_support_root" > /tmp/ross-runtime-inventory.out
grep -q "lane=installed_gguf status=missing .*reason=manifest_primary_unusable_artifact .*pack=bad-mtp" /tmp/ross-runtime-inventory.out
grep -q "lane=installed_mtp_draft status=missing .*reason=manifest_draft_unusable_artifact .*pack=bad-mtp" /tmp/ross-runtime-inventory.out
grep -q "lane=installed_gguf status=missing .*reason=manifest_primary_checksum_mismatch .*pack=checksum-mismatch .*checksum_status=mismatch" /tmp/ross-runtime-inventory.out
grep -q "lane=installed_mtp_draft status=missing .*reason=manifest_draft_checksum_mismatch .*pack=checksum-mismatch .*checksum_status=mismatch" /tmp/ross-runtime-inventory.out
grep -q "lane=installed_mlx status=missing .*reason=manifest_primary_unusable_artifact .*pack=bad-mlx" /tmp/ross-runtime-inventory.out
grep -q "lane=installed_coreai status=missing .*reason=manifest_primary_unusable_artifact .*pack=bad-coreai" /tmp/ross-runtime-inventory.out
grep -q "lane=installed_coreai status=missing .*reason=manifest_foreign_coreai_adapter .*pack=foreign-coreai" /tmp/ross-runtime-inventory.out

echo "iOS runtime artifact inventory tests: PASS"

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

echo "iOS runtime artifact inventory tests: PASS"

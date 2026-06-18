#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEVICE_SMOKE="$ROOT_DIR/scripts/ios-device-installed-pack-smoke.sh"

tmpdir="$(mktemp -d /tmp/ross-device-installed-preflight.XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT

fake_bin="$tmpdir/bin"
fake_device_root="$tmpdir/fake-device"
mkdir -p "$fake_bin" "$fake_device_root/Library/Application Support/RossAlpha/model-packs"

cat >"$fake_bin/xcrun" <<'SH'
#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" != "devicectl" ]]; then
  echo "fake xcrun only supports devicectl" >&2
  exit 2
fi
shift

if [[ "${1:-}" != "device" ]]; then
  echo "fake devicectl only supports device" >&2
  exit 2
fi
shift

command="${1:-}"
shift || true

case "$command" in
  copy)
    direction="${1:-}"
    shift || true
    source=""
    destination=""
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --source)
          source="${2:-}"
          shift 2
          ;;
        --destination)
          destination="${2:-}"
          shift 2
          ;;
        *)
          shift
          ;;
      esac
    done
    case "$direction" in
      to)
        echo "Path: $FAKE_DEVICE_ROOT/$destination"
        ;;
      from)
        mkdir -p "$(dirname "$destination")"
        cp "$FAKE_DEVICE_ROOT/$source" "$destination"
        ;;
      *)
        echo "fake copy direction unsupported: $direction" >&2
        exit 2
        ;;
    esac
    ;;
  info)
    subcommand="${1:-}"
    shift || true
    if [[ "$subcommand" != "files" ]]; then
      echo "fake info only supports files" >&2
      exit 2
    fi
    json_output=""
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --json-output)
          json_output="${2:-}"
          shift 2
          ;;
        *)
          shift
          ;;
      esac
    done
    if [[ -z "$json_output" ]]; then
      echo "missing --json-output" >&2
      exit 2
    fi
    python3 - "$FAKE_DEVICE_ROOT" "$json_output" <<'PY'
import json
import pathlib
import sys

root = pathlib.Path(sys.argv[1]) / "Library/Application Support/RossAlpha"
files = []
for manifest in sorted(root.rglob("*.manifest.json")):
    files.append({"relativePath": str(manifest.relative_to(root))})
pathlib.Path(sys.argv[2]).write_text(json.dumps({"result": {"files": files}}))
PY
    ;;
  process)
    echo "fake devicectl process launch should not be reached by preflight rejection" >&2
    exit 99
    ;;
  *)
    echo "fake devicectl command unsupported: $command" >&2
    exit 2
    ;;
esac
SH
chmod +x "$fake_bin/xcrun"

write_manifest() {
  local payload="$1"
  rm -rf "$fake_device_root/Library/Application Support/RossAlpha/model-packs"
  mkdir -p "$fake_device_root/Library/Application Support/RossAlpha/model-packs/quick"
  printf '%s\n' "$payload" >"$fake_device_root/Library/Application Support/RossAlpha/model-packs/quick/test.manifest.json"
}

run_expect_exit_1() {
  local description="$1"
  local expected="$2"
  shift 2
  set +e
  PATH="$fake_bin:$PATH" FAKE_DEVICE_ROOT="$fake_device_root" "$@" >"$tmpdir/out.txt" 2>&1
  local rc=$?
  set -e
  if [[ "$rc" -ne 1 ]]; then
    echo "FAIL: $description expected exit 1, got $rc" >&2
    cat "$tmpdir/out.txt" >&2 || true
    return 1
  fi
  if ! grep -q "$expected" "$tmpdir/out.txt"; then
    echo "FAIL: $description did not emit expected message: $expected" >&2
    cat "$tmpdir/out.txt" >&2 || true
    return 1
  fi
}

base_command=("$DEVICE_SMOKE" --device fake-device --tier quickStart)

write_manifest '{
  "packId": "tiny-gguf",
  "tier": "quick_start",
  "fileName": "tiny.gguf",
  "relativePath": "model-packs/quick/tiny.gguf",
  "checksumSha256": "a",
  "bytes": 4,
  "artifactKind": "local_model_artifact",
  "runtimeMode": "gemma_local_runtime",
  "developmentOnly": false,
  "verifiedAt": "2026-06-19T00:00:00Z"
}'
run_expect_exit_1 "tiny GGUF installed manifest" "implausibly small artifact" "${base_command[@]}" --runtime gguf

write_manifest '{
  "packId": "tiny-mtp",
  "tier": "quick_start",
  "fileName": "main.gguf",
  "relativePath": "model-packs/quick/main.gguf",
  "checksumSha256": "a",
  "bytes": 2000000,
  "artifactKind": "local_model_artifact",
  "runtimeMode": "gemma_local_runtime",
  "developmentOnly": false,
  "draftArtifact": {
    "fileName": "draft.gguf",
    "relativePath": "model-packs/quick/draft.gguf",
    "checksumSha256": "b",
    "bytes": 4,
    "artifactKind": "local_model_artifact",
    "draftTokens": 2
  },
  "verifiedAt": "2026-06-19T00:00:00Z"
}'
run_expect_exit_1 "tiny MTP draft installed manifest" "implausibly small draft artifact" "${base_command[@]}" --runtime gguf --require-draft-acceleration

write_manifest '{
  "packId": "tiny-mlx",
  "tier": "quick_start",
  "fileName": "mlx-model",
  "relativePath": "model-packs/quick/mlx-model",
  "checksumSha256": "a",
  "bytes": 0,
  "artifactKind": "mlx_directory",
  "runtimeMode": "mlx_swift_lm",
  "developmentOnly": false,
  "verifiedAt": "2026-06-19T00:00:00Z"
}'
run_expect_exit_1 "tiny MLX installed manifest" "implausibly small artifact" "${base_command[@]}" --runtime mlx

write_manifest '{
  "packId": "empty-coreml",
  "tier": "quick_start",
  "fileName": "adapter.mlmodelc",
  "relativePath": "model-packs/quick/adapter.mlmodelc",
  "checksumSha256": "a",
  "bytes": 0,
  "artifactKind": "coreml_model",
  "runtimeMode": "apple_foundation_models",
  "developmentOnly": false,
  "verifiedAt": "2026-06-19T00:00:00Z"
}'
run_expect_exit_1 "empty CoreAI adapter installed manifest" "empty artifact" "${base_command[@]}" --runtime coreml

echo "iOS device installed-pack preflight tests: PASS"

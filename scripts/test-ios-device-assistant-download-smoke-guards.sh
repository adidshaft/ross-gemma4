#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ASSISTANT_SMOKE="$ROOT_DIR/scripts/ios-device-assistant-download-smoke.sh"

tmpdir="$(mktemp -d /tmp/ross-assistant-download-smoke.XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT

fake_bin="$tmpdir/bin"
mkdir -p "$fake_bin"

cat >"$fake_bin/xcrun" <<'SH'
#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" != "devicectl" ]]; then
  echo "fake xcrun only supports devicectl" >&2
  exit 2
fi

case "${FAKE_ASSISTANT_DOWNLOAD_LOG:-valid}" in
  missing_identity)
    echo "ROSS_ASSISTANT_DOWNLOAD_SMOKE_PASS elapsed=1.00s tier=quick_start runtime=mlx_swift_lm pack=mlx-pack install_path=model-packs/mlx checksum=true"
    ;;
  gguf_identity)
    echo "ROSS_RUNTIME_IDENTITY provider=AlphaLlamaCppProvider requested_runtime=mlx_swift_lm actual_runtime=gemma_local_runtime pack_runtime=gemma_local_runtime model_format=local_model_artifact artifact_path_type=file artifact_path=model.gguf acceleration=standard draft_tokens=nil draft_model=nil draft_model_path_type=nil draft_status=no_draft_configured fallback=none available=true error=nil"
    echo "ROSS_ASSISTANT_DOWNLOAD_SMOKE_PASS elapsed=1.00s tier=quick_start runtime=mlx_swift_lm pack=mlx-pack install_path=model-packs/mlx checksum=true"
    ;;
  unavailable_identity)
    echo "ROSS_RUNTIME_IDENTITY provider=AlphaMLXLocalProvider requested_runtime=mlx_swift_lm actual_runtime=mlx_swift_lm pack_runtime=mlx_swift_lm model_format=mlx_directory artifact_path_type=directory artifact_path=mlx-model acceleration=standard draft_tokens=nil draft_model=nil draft_model_path_type=nil draft_status=no_draft_configured fallback=none available=false error=missing_mlx_artifact"
    echo "ROSS_ASSISTANT_DOWNLOAD_SMOKE_PASS elapsed=1.00s tier=quick_start runtime=mlx_swift_lm pack=mlx-pack install_path=model-packs/mlx checksum=true"
    ;;
  fail_missing_identity)
    echo "ROSS_ASSISTANT_DOWNLOAD_SMOKE_FAIL missing_job elapsed=1.00s"
    ;;
  fail_gguf_identity)
    echo "ROSS_RUNTIME_IDENTITY provider=AlphaLlamaCppProvider requested_runtime=mlx_swift_lm actual_runtime=gemma_local_runtime pack_runtime=gemma_local_runtime model_format=local_model_artifact artifact_path_type=file artifact_path=model.gguf acceleration=standard draft_tokens=nil draft_model=nil draft_model_path_type=nil draft_status=no_draft_configured fallback=none available=true error=nil"
    echo "ROSS_ASSISTANT_DOWNLOAD_SMOKE_FAIL missing_job elapsed=1.00s"
    ;;
  valid)
    echo "ROSS_RUNTIME_IDENTITY provider=AlphaMLXLocalProvider requested_runtime=mlx_swift_lm actual_runtime=mlx_swift_lm pack_runtime=mlx_swift_lm model_format=mlx_directory artifact_path_type=directory artifact_path=mlx-model acceleration=standard draft_tokens=nil draft_model=nil draft_model_path_type=nil draft_status=no_draft_configured fallback=none available=true error=nil"
    echo "ROSS_ASSISTANT_DOWNLOAD_SMOKE_PASS elapsed=1.00s tier=quick_start runtime=mlx_swift_lm pack=mlx-pack install_path=model-packs/mlx checksum=true"
    ;;
  *)
    echo "unknown FAKE_ASSISTANT_DOWNLOAD_LOG=$FAKE_ASSISTANT_DOWNLOAD_LOG" >&2
    exit 2
    ;;
esac
SH
chmod +x "$fake_bin/xcrun"

run_expect_exit_1() {
  local description="$1"
  local expected="$2"
  shift 2
  set +e
  PATH="$fake_bin:$PATH" "$@" >"$tmpdir/out.txt" 2>&1
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

run_expect_exit_0() {
  local description="$1"
  shift
  set +e
  PATH="$fake_bin:$PATH" "$@" >"$tmpdir/out.txt" 2>&1
  local rc=$?
  set -e
  if [[ "$rc" -ne 0 ]]; then
    echo "FAIL: $description expected exit 0, got $rc" >&2
    cat "$tmpdir/out.txt" >&2 || true
    return 1
  fi
}

base_command=("$ASSISTANT_SMOKE" --device fake-device --tier quickStart --runtime mlx --wait-seconds 1)

run_expect_exit_1 \
  "assistant download pass without runtime identity" \
  "missing_runtime_identity" \
  env FAKE_ASSISTANT_DOWNLOAD_LOG=missing_identity "${base_command[@]}"

run_expect_exit_1 \
  "assistant download pass with GGUF identity for MLX request" \
  "runtime_identity_mismatch" \
  env FAKE_ASSISTANT_DOWNLOAD_LOG=gguf_identity "${base_command[@]}"

run_expect_exit_1 \
  "assistant download pass with unavailable runtime identity" \
  "runtime_identity_unavailable" \
  env FAKE_ASSISTANT_DOWNLOAD_LOG=unavailable_identity "${base_command[@]}"

run_expect_exit_1 \
  "assistant download failure without runtime identity" \
  "missing_runtime_identity_on_failure" \
  env FAKE_ASSISTANT_DOWNLOAD_LOG=fail_missing_identity "${base_command[@]}"

run_expect_exit_1 \
  "assistant download failure with GGUF identity for MLX request" \
  "runtime_identity_mismatch_on_failure" \
  env FAKE_ASSISTANT_DOWNLOAD_LOG=fail_gguf_identity "${base_command[@]}"

run_expect_exit_0 \
  "assistant download pass with matching MLX identity" \
  env FAKE_ASSISTANT_DOWNLOAD_LOG=valid "${base_command[@]}"

echo "iOS assistant-download smoke guard tests: PASS"

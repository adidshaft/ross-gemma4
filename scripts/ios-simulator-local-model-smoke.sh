#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  cat <<'EOF'
Usage:
  scripts/ios-simulator-local-model-smoke.sh --runtime <mode> [options]

Options:
  --runtime <mode>        gguf | mlx | coreai | coreml | gemma_local_runtime | mlx_swift_lm | apple_foundation_models
  --model <path>          Local model artifact path. Required for GGUF/MLX. Optional for CoreAI/CoreML.
  --simulator <id|name>   Simulator target accepted by simctl. Default: booted
  --bundle-id <id>        App bundle identifier. Default: com.ross.ios
  --artifact-kind <kind>  Override smoke artifact kind.
  --tier <tier>           quickStart | caseAssociate | seniorDraftingSupport. Default: quickStart
  --pack-id <id>          Logical pack id for the debug smoke pack.
  --smoke-profile <mode>  quick | full | mtp-quick | source-only. Default: quick
  --stage-timeout <sec>   Per-stage smoke timeout. Default: 60
  --launch-timeout <sec>  Overall helper timeout. Default: 240
  --draft-model <path>    Draft model artifact/directory for MTP or MLX speculative decoding.
  --draft-tokens <count>  Draft token count to request.
  --disable-draft         Force standard acceleration.
  --require-draft-acceleration
                          Fail unless identity reports draftModelSpeculative with active draft_status and draft metadata.

This helper runs only on Simulator. It does not seed or use a physical iPhone.
It exits 0 only when the app emits ROSS_LOCAL_MODEL_SMOKE_PASS and the
ROSS_RUNTIME_IDENTITY line proves that requested_runtime == actual_runtime.
EOF
}

runtime=""
model_path=""
simulator="booted"
bundle_id="com.ross.ios"
artifact_kind=""
tier="quickStart"
pack_id=""
smoke_profile="quick"
stage_timeout="60"
launch_timeout="240"
draft_model_path=""
draft_tokens=""
disable_draft="0"
require_draft_acceleration="0"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --runtime)
      runtime="${2:-}"
      shift 2
      ;;
    --model)
      model_path="${2:-}"
      shift 2
      ;;
    --simulator)
      simulator="${2:-}"
      shift 2
      ;;
    --bundle-id)
      bundle_id="${2:-}"
      shift 2
      ;;
    --artifact-kind)
      artifact_kind="${2:-}"
      shift 2
      ;;
    --tier)
      tier="${2:-}"
      shift 2
      ;;
    --pack-id)
      pack_id="${2:-}"
      shift 2
      ;;
    --smoke-profile)
      smoke_profile="${2:-}"
      shift 2
      ;;
    --stage-timeout)
      stage_timeout="${2:-}"
      shift 2
      ;;
    --launch-timeout)
      launch_timeout="${2:-}"
      shift 2
      ;;
    --draft-model)
      draft_model_path="${2:-}"
      shift 2
      ;;
    --draft-tokens)
      draft_tokens="${2:-}"
      shift 2
      ;;
    --disable-draft)
      disable_draft="1"
      shift
      ;;
    --require-draft-acceleration)
      require_draft_acceleration="1"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ -z "$runtime" ]]; then
  usage >&2
  exit 2
fi

case "$smoke_profile" in
  quick|full|mtp|mtp-quick|mtp_quick|source|source-only)
    ;;
  *)
    echo "Unsupported smoke profile: $smoke_profile" >&2
    usage >&2
    exit 2
    ;;
esac

if ! command -v xcrun >/dev/null 2>&1; then
  echo "xcrun is required." >&2
  exit 2
fi

case "$runtime" in
  gguf|gemma_local_runtime)
    normalized_runtime="gemma_local_runtime"
    default_artifact_kind="local_model_artifact"
    ;;
  mlx|mlx_swift_lm)
    normalized_runtime="mlx_swift_lm"
    default_artifact_kind="mlx_directory"
    ;;
  coreai|coreml|apple_foundation_models)
    normalized_runtime="apple_foundation_models"
    default_artifact_kind="system_model"
    ;;
  *)
    echo "Unsupported runtime: $runtime" >&2
    exit 2
    ;;
esac

case "$tier" in
  quickStart|caseAssociate|seniorDraftingSupport)
    ;;
  *)
    echo "Unsupported tier: $tier" >&2
    exit 2
    ;;
esac

if [[ -z "$artifact_kind" ]]; then
  artifact_kind="$default_artifact_kind"
fi

if [[ -z "$model_path" && "$normalized_runtime" == "apple_foundation_models" ]]; then
  model_path="system-model"
fi

if [[ -z "$model_path" ]]; then
  echo "--model is required for runtime $runtime" >&2
  exit 2
fi

mlx_directory_looks_usable() {
  local directory="$1"
  [[ -d "$directory" ]] || return 1
  [[ -f "$directory/config.json" ]] || return 1

  if [[ ! -f "$directory/tokenizer.json" && ! -f "$directory/tokenizer.model" && ! -f "$directory/tokenizer_config.json" ]]; then
    return 1
  fi

  find "$directory" -type f \( -name '*.safetensors' -o -name '*.safetensors.index.json' \) -print -quit | grep -q .
}

file_size_bytes() {
  stat -f%z "$1" 2>/dev/null || stat -c%s "$1" 2>/dev/null || echo 0
}

gguf_file_looks_usable() {
  local file="$1"
  [[ -f "$file" ]] || return 1
  local size
  size="$(file_size_bytes "$file")"
  [[ "$size" =~ ^[0-9]+$ ]] || return 1
  [[ "$size" -gt 1000000 ]] || return 1
  [[ "$(LC_ALL=C dd if="$file" bs=4 count=1 2>/dev/null)" == "GGUF" ]]
}

case "$normalized_runtime" in
  gemma_local_runtime)
    case "$artifact_kind" in
      local_model_artifact|gguf|gguf_model)
        ;;
      *)
        echo "GGUF simulator smoke requires a GGUF/local artifact kind, got: $artifact_kind" >&2
        exit 2
        ;;
    esac
    if [[ ! -f "$model_path" ]]; then
      echo "GGUF model file not found: $model_path" >&2
      exit 2
    fi
    if ! gguf_file_looks_usable "$model_path"; then
      echo "GGUF simulator smoke requires a real GGUF model file with GGUF header and size larger than 1 MB, got: $model_path" >&2
      exit 2
    fi
    ;;
  mlx_swift_lm)
    if [[ "$artifact_kind" != "mlx_directory" ]]; then
      echo "MLX simulator smoke requires artifactKind=mlx_directory, got: $artifact_kind" >&2
      exit 2
    fi
    lower_model_path="$(printf '%s' "$model_path" | tr '[:upper:]' '[:lower:]')"
    case "$lower_model_path" in
      *.gguf|*.bin)
        echo "MLX simulator smoke requires an MLX directory, not a GGUF/bin file: $model_path" >&2
        exit 2
        ;;
    esac
    if [[ ! -d "$model_path" ]]; then
      echo "MLX model directory not found: $model_path" >&2
      exit 2
    fi
    if ! mlx_directory_looks_usable "$model_path"; then
      echo "MLX simulator smoke requires a directory with config.json, tokenizer metadata, and safetensors weights or index: $model_path" >&2
      exit 2
    fi
    ;;
  apple_foundation_models)
    case "$artifact_kind" in
      system_model|foundation_adapter|coreai_adapter|coreml_model)
        ;;
      *)
        echo "CoreAI/CoreML simulator smoke requires a system/foundation/CoreAI/CoreML artifact kind, got: $artifact_kind" >&2
        exit 2
        ;;
    esac
    coreai_system_model_path=0
    if [[ "$model_path" == "system-model" || "$model_path" == system://* ]]; then
      coreai_system_model_path=1
    fi
    if [[ "$artifact_kind" == "system_model" && "$coreai_system_model_path" != "1" ]]; then
      echo "CoreAI/CoreML simulator smoke uses artifactKind=system_model only with model path system-model/system://, got: $model_path" >&2
      exit 2
    fi
    if [[ "$artifact_kind" != "system_model" && "$coreai_system_model_path" == "1" ]]; then
      echo "CoreAI/CoreML adapter smoke requires an adapter path, not system-model/system://, for artifactKind=$artifact_kind" >&2
      exit 2
    fi
    if [[ "$coreai_system_model_path" != "1" && ! -e "$model_path" ]]; then
      echo "CoreAI/CoreML adapter path not found: $model_path" >&2
      exit 2
    fi
    ;;
esac

if [[ -n "$draft_model_path" && ! -e "$draft_model_path" ]]; then
  echo "Draft model path not found: $draft_model_path" >&2
  exit 2
fi

if [[ "$require_draft_acceleration" == "1" && "$normalized_runtime" == "apple_foundation_models" ]]; then
  echo "Draft acceleration proof is only supported for GGUF/MLX simulator smokes, not apple_foundation_models." >&2
  exit 2
fi

if [[ "$require_draft_acceleration" == "1" && -z "$draft_model_path" ]]; then
  echo "Draft acceleration proof requires --draft-model so identity cannot pass with draft_model=nil." >&2
  exit 2
fi

if [[ -n "$draft_model_path" ]]; then
  case "$normalized_runtime" in
    gemma_local_runtime)
      lower_draft_model_path="$(printf '%s' "$draft_model_path" | tr '[:upper:]' '[:lower:]')"
      if [[ ! -f "$draft_model_path" || "$lower_draft_model_path" != *.gguf ]]; then
        echo "GGUF/MTP simulator draft proof requires a GGUF draft file, got: $draft_model_path" >&2
        exit 2
      fi
      if ! gguf_file_looks_usable "$draft_model_path"; then
        echo "GGUF/MTP simulator draft proof requires a real GGUF draft file with GGUF header and size larger than 1 MB, got: $draft_model_path" >&2
        exit 2
      fi
      ;;
    mlx_swift_lm)
      lower_draft_model_path="$(printf '%s' "$draft_model_path" | tr '[:upper:]' '[:lower:]')"
      case "$lower_draft_model_path" in
        *.gguf|*.bin)
          echo "MLX simulator draft proof requires an MLX draft directory, not a GGUF/bin file: $draft_model_path" >&2
          exit 2
          ;;
      esac
      if [[ ! -d "$draft_model_path" ]]; then
        echo "MLX simulator draft proof requires an MLX draft directory: $draft_model_path" >&2
        exit 2
      fi
      if ! mlx_directory_looks_usable "$draft_model_path"; then
        echo "MLX simulator draft proof requires a usable MLX draft directory with config.json, tokenizer metadata, and safetensors weights or index: $draft_model_path" >&2
        exit 2
      fi
      ;;
  esac
fi

if [[ -z "$pack_id" ]]; then
  if [[ "$model_path" == "system-model" ]]; then
    pack_id="simulator-system-model-smoke"
  else
    pack_id="$(basename "$model_path")-simulator-smoke"
  fi
fi

if [[ -f "$model_path" ]]; then
  checksum="$(shasum -a 256 "$model_path" | awk '{print $1}')"
else
  checksum="debug-local-model-unverified"
fi

python3 - "$simulator" "$bundle_id" "$normalized_runtime" "$model_path" "$checksum" "$artifact_kind" "$tier" "$pack_id" "$draft_model_path" "$draft_tokens" "$stage_timeout" "$smoke_profile" "$disable_draft" "$require_draft_acceleration" "$launch_timeout" "$SCRIPT_DIR" <<'PY'
import os
import re
import signal
import subprocess
import sys
import time

sys.path.insert(0, sys.argv[-1])
from ross_smoke_summary import (
    MissingBenchmarkMatrixError,
    benchmark_summary_line,
    failure_summary_line,
    parse_fields,
    runtime_identity_artifact_error,
    runtime_identity_availability_error,
    runtime_identity_draft_artifact_error,
)

(
    simulator,
    bundle_id,
    runtime,
    model_path,
    checksum,
    artifact_kind,
    tier,
    pack_id,
    draft_model_path,
    draft_tokens,
    stage_timeout,
    smoke_profile,
    disable_draft,
    require_draft_acceleration,
    launch_timeout,
) = sys.argv[1:-1]

env = os.environ.copy()
env.update(
    {
        "SIMCTL_CHILD_ROSS_ENABLE_REAL_LOCAL_INFERENCE": "1",
        "SIMCTL_CHILD_ROSS_LOCAL_RUNTIME": runtime,
        "SIMCTL_CHILD_ROSS_LOCAL_MODEL_PATH": model_path,
        "SIMCTL_CHILD_ROSS_LOCAL_MODEL_CHECKSUM": checksum,
        "SIMCTL_CHILD_ROSS_LOCAL_MODEL_KIND": artifact_kind,
        "SIMCTL_CHILD_ROSS_LOCAL_MODEL_TIER": tier,
        "SIMCTL_CHILD_ROSS_LOCAL_MODEL_PACK_ID": pack_id,
        "SIMCTL_CHILD_ROSS_LOCAL_MODEL_SMOKE_STAGE_TIMEOUT_SECONDS": stage_timeout,
        "SIMCTL_CHILD_ROSS_LOCAL_MODEL_SMOKE_PROFILE": smoke_profile,
    }
)
if draft_model_path:
    env["SIMCTL_CHILD_ROSS_LOCAL_DRAFT_MODEL_PATH"] = draft_model_path
if draft_tokens:
    env["SIMCTL_CHILD_ROSS_LOCAL_DRAFT_MODEL_TOKENS"] = draft_tokens
if disable_draft == "1":
    env["SIMCTL_CHILD_ROSS_LOCAL_DISABLE_DRAFT_ACCELERATION"] = "1"
if require_draft_acceleration == "1":
    env["SIMCTL_CHILD_ROSS_LOCAL_MODEL_SMOKE_REQUIRE_DRAFT_ACCELERATION"] = "1"

command = [
    "xcrun",
    "simctl",
    "launch",
    "--terminate-running-process",
    "--console",
    simulator,
    bundle_id,
    "--local-model-smoke",
]

pass_re = re.compile(r"\bROSS_LOCAL_MODEL_SMOKE_PASS\b")
fail_re = re.compile(r"\bROSS_LOCAL_MODEL_SMOKE_FAIL\b")
identity_re = re.compile(r"\bROSS_RUNTIME_IDENTITY\b")
matrix_re = re.compile(r"\bROSS_LOCAL_MODEL_SMOKE_BENCHMARK_MATRIX\b")

def print_benchmark_summary(identity, pass_fields, matrix_fields):
    print(benchmark_summary_line(identity, pass_fields, matrix_fields))


def validate_identity_guard(identity, *, require_identity):
    if identity is None:
        if require_identity:
            print("ROSS_SMOKE_GUARD_FAIL reason=missing_runtime_identity", file=sys.stderr)
            sys.exit(1)
        return

    actual_runtime = identity.get("actual_runtime")
    requested_runtime = identity.get("requested_runtime")
    if actual_runtime != runtime or requested_runtime not in (runtime, "nil"):
        print(
            "ROSS_SMOKE_GUARD_FAIL "
            f"reason=runtime_identity_mismatch requested={runtime} "
            f"identity_requested={requested_runtime} actual={actual_runtime}",
            file=sys.stderr,
        )
        sys.exit(1)

    if require_identity:
        availability_error = runtime_identity_availability_error(identity)
        if availability_error:
            print(
                "ROSS_SMOKE_GUARD_FAIL "
                f"reason=runtime_identity_unavailable requested={runtime} "
                f"{availability_error}",
                file=sys.stderr,
            )
            sys.exit(1)

        artifact_error = runtime_identity_artifact_error(identity, runtime)
        if artifact_error:
            print(
                "ROSS_SMOKE_GUARD_FAIL "
                f"reason=runtime_identity_artifact_mismatch requested={runtime} "
                f"{artifact_error}",
                file=sys.stderr,
            )
            sys.exit(1)

    if require_draft_acceleration == "1":
        acceleration = identity.get("acceleration")
        draft_tokens_value = identity.get("draft_tokens")
        draft_model_value = identity.get("draft_model")
        draft_model_path_type = identity.get("draft_model_path_type")
        draft_status = identity.get("draft_status")
        draft_artifact_error = runtime_identity_draft_artifact_error(identity, runtime)
        if acceleration != "draftModelSpeculative" or draft_artifact_error:
            print(
                "ROSS_SMOKE_GUARD_FAIL "
                f"reason=draft_acceleration_inactive acceleration={acceleration} "
                f"draft_tokens={draft_tokens_value} draft_model={draft_model_value} "
                f"draft_model_path_type={draft_model_path_type} draft_status={draft_status} "
                f"draft_artifact_error={draft_artifact_error or 'nil'}",
                file=sys.stderr,
            )
            sys.exit(1)


identity = None
matrix_fields = None
pass_fields = None
fail_fields = None
outcome = None
deadline = time.time() + max(float(launch_timeout), 1.0)
process = subprocess.Popen(
    command,
    stdout=subprocess.PIPE,
    stderr=subprocess.STDOUT,
    text=True,
    env=env,
    bufsize=1,
)

try:
    assert process.stdout is not None
    for raw_line in process.stdout:
        line = raw_line.rstrip("\n")
        print(line, flush=True)
        if identity_re.search(line):
            identity = parse_fields(line)
        if matrix_re.search(line):
            matrix_fields = parse_fields(line)
        if pass_re.search(line):
            outcome = "pass"
            pass_fields = parse_fields(line)
            try:
                process.send_signal(signal.SIGINT)
            except ProcessLookupError:
                pass
            break
        if fail_re.search(line):
            outcome = "fail"
            fail_fields = parse_fields(line)
            try:
                process.send_signal(signal.SIGINT)
            except ProcessLookupError:
                pass
            break
        if time.time() > deadline:
            outcome = "timeout"
            print(f"ROSS_SMOKE_GUARD_FAIL reason=helper_timeout timeout={launch_timeout}", flush=True)
            process.kill()
            break
finally:
    try:
        process.wait(timeout=15)
    except subprocess.TimeoutExpired:
        process.kill()
        process.wait(timeout=5)

if outcome == "pass" and pass_fields is not None:
    validate_identity_guard(identity, require_identity=True)
    try:
        print_benchmark_summary(identity, pass_fields, matrix_fields)
    except MissingBenchmarkMatrixError as error:
        print(f"ROSS_SMOKE_GUARD_FAIL reason={error}", file=sys.stderr)
        sys.exit(1)
    sys.exit(0)

if outcome == "fail":
    validate_identity_guard(identity, require_identity=False)
    print(failure_summary_line(identity, fail_fields, matrix_fields))
    sys.exit(1)

print(f"ROSS_SMOKE_GUARD_FAIL reason=no_terminal_smoke_marker outcome={outcome}", file=sys.stderr)
sys.exit(1)
PY

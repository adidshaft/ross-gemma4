#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  scripts/ios-device-assistant-download-smoke.sh --device <udid> --tier <tier> [options]

Options:
  --device <udid>         Physical iPhone UDID accepted by devicectl.
  --bundle-id <id>        App bundle identifier. Default: com.ross.ios
  --tier <tier>           quickStart | caseAssociate | seniorDraftingSupport | flash
  --runtime <mode>        auto | mlx | gguf | coreai. Default: auto
  --mobile-allowed        Allow the download flow to run without Wi-Fi-only gating.
  --force-refresh         Force a fresh download instead of reusing an installed matching pack.
  --wait-seconds <sec>    App-side smoke wait budget. Default: 900

This helper:
  1. Launches Ross in assistant-download smoke mode on the cabled device
  2. Streams structured download progress logs from the app
  3. Exits 0 only after a ROSS_ASSISTANT_DOWNLOAD_SMOKE_PASS line appears
EOF
}

device_id=""
bundle_id="com.ross.ios"
selected_tier=""
selected_runtime="auto"
mobile_allowed="0"
force_refresh="0"
wait_seconds="900"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --device)
      device_id="${2:-}"
      shift 2
      ;;
    --bundle-id)
      bundle_id="${2:-}"
      shift 2
      ;;
    --tier)
      selected_tier="${2:-}"
      shift 2
      ;;
    --runtime)
      selected_runtime="${2:-}"
      shift 2
      ;;
    --mobile-allowed)
      mobile_allowed="1"
      shift 1
      ;;
    --force-refresh)
      force_refresh="1"
      shift 1
      ;;
    --wait-seconds)
      wait_seconds="${2:-}"
      shift 2
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

if [[ -z "$device_id" || -z "$selected_tier" ]]; then
  usage >&2
  exit 2
fi

python3 - "$device_id" "$bundle_id" "$selected_tier" "$selected_runtime" "$mobile_allowed" "$force_refresh" "$wait_seconds" <<'PY'
import os
import re
import signal
import subprocess
import sys

(
    device_id,
    bundle_id,
    selected_tier,
    selected_runtime,
    mobile_allowed,
    force_refresh,
    wait_seconds,
) = sys.argv[1:]

env = os.environ.copy()
env.update(
    {
        "DEVICECTL_CHILD_ROSS_ASSISTANT_DOWNLOAD_SMOKE_TIER": selected_tier,
        "DEVICECTL_CHILD_ROSS_ASSISTANT_DOWNLOAD_SMOKE_MOBILE_ALLOWED": "1" if mobile_allowed == "1" else "0",
        "DEVICECTL_CHILD_ROSS_ASSISTANT_DOWNLOAD_SMOKE_FORCE_REFRESH": "1" if force_refresh == "1" else "0",
        "DEVICECTL_CHILD_ROSS_ASSISTANT_DOWNLOAD_SMOKE_WAIT_SECONDS": wait_seconds,
    }
)
if selected_runtime != "auto":
    env["DEVICECTL_CHILD_ROSS_ASSISTANT_DOWNLOAD_SMOKE_RUNTIME"] = selected_runtime

command = [
    "xcrun",
    "devicectl",
    "device",
    "process",
    "launch",
    "--device",
    device_id,
    "--terminate-existing",
    "--console",
    bundle_id,
    "--assistant-download-smoke",
]

pass_re = re.compile(r"ROSS_ASSISTANT_DOWNLOAD_SMOKE_PASS\b")
fail_re = re.compile(r"ROSS_ASSISTANT_DOWNLOAD_SMOKE_FAIL\b")

outcome = None
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
        print(line)
        if pass_re.search(line):
            outcome = "pass"
            process.send_signal(signal.SIGINT)
            break
        if fail_re.search(line):
            outcome = "fail"
            process.send_signal(signal.SIGINT)
            break
finally:
    try:
        process.wait(timeout=15)
    except subprocess.TimeoutExpired:
        process.kill()
        process.wait(timeout=5)

if outcome == "pass":
    sys.exit(0)
if outcome == "fail":
    sys.exit(1)
sys.exit(process.returncode or 1)
PY

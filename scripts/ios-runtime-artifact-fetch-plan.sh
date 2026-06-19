#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INVENTORY="$ROOT_DIR/scripts/ios-runtime-artifact-inventory.sh"

usage() {
  cat <<'EOF'
Usage:
  scripts/ios-runtime-artifact-fetch-plan.sh [options]

Options:
  --tier <tier>          Runtime tier to plan. Default: quickStart
  --target-root <path>   Local model artifact root for download commands. Default: ~/model-artifacts
  --search-root <path>   Additional local artifact root to inspect before printing downloads.

Dry-run only. Prints artifact acquisition and simulator preflight commands for
MLX/CoreAI readiness without launching Simulator, devicectl, or the app.
EOF
}

tier="quickStart"
target_root="$HOME/model-artifacts"
search_roots=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --tier)
      tier="${2:-}"
      shift 2
      ;;
    --target-root)
      target_root="${2:-}"
      shift 2
      ;;
    --search-root)
      search_roots+=("${2:-}")
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

case "$tier" in
  quickStart|quick_start|caseAssociate|case_associate|seniorDraftingSupport|senior_drafting_support)
    ;;
  *)
    echo "Unsupported tier: $tier" >&2
    exit 2
    ;;
esac

if [[ -z "$target_root" ]]; then
  echo "Target root must not be empty." >&2
  exit 2
fi

quote_args() {
  local arg
  for arg in "$@"; do
    printf ' %q' "$arg"
  done
  printf '\n'
}

inventory_args=("$INVENTORY")
if [[ "${#search_roots[@]}" -gt 0 ]]; then
  for root in "${search_roots[@]}"; do
    inventory_args+=(--search-root "$root")
  done
fi

inventory_output="$("${inventory_args[@]}")"

venv_hf="$target_root/.hf-venv/bin/hf"
venv_python="$target_root/.hf-venv/bin/python"
downloader_status="${ROSS_RUNTIME_ARTIFACT_FETCH_DOWNLOADER_STATUS:-}"
downloader_command="${ROSS_RUNTIME_ARTIFACT_FETCH_DOWNLOADER_COMMAND:-}"
if [[ -z "$downloader_status" ]]; then
  if command -v hf >/dev/null 2>&1; then
    downloader_status="hf_cli"
    downloader_command="hf"
  elif [[ -x "$venv_hf" ]]; then
    downloader_status="target_root_venv"
    downloader_command="$venv_hf"
  else
    downloader_status="missing"
  fi
fi
if [[ -z "$downloader_command" && "$downloader_status" == "hf_cli" ]]; then
  downloader_command="hf"
fi
if [[ -z "$downloader_command" && "$downloader_status" == "target_root_venv" ]]; then
  downloader_command="$venv_hf"
fi

ROSS_RUNTIME_ARTIFACT_INVENTORY_OUTPUT="$inventory_output" \
ROSS_RUNTIME_ARTIFACT_FETCH_DOWNLOADER_STATUS="$downloader_status" \
ROSS_RUNTIME_ARTIFACT_FETCH_DOWNLOADER_COMMAND="$downloader_command" \
ROSS_RUNTIME_ARTIFACT_FETCH_VENV_PYTHON="$venv_python" \
python3 - "$tier" "$target_root" "$ROOT_DIR" <<'PY'
import os
import pathlib
import shlex
import sys

tier = sys.argv[1]
target_root = pathlib.Path(sys.argv[2]).expanduser()
root_dir = pathlib.Path(sys.argv[3])
raw_inventory = os.environ.get("ROSS_RUNTIME_ARTIFACT_INVENTORY_OUTPUT", "").splitlines()
downloader_status = os.environ.get("ROSS_RUNTIME_ARTIFACT_FETCH_DOWNLOADER_STATUS", "missing")
downloader_command = os.environ.get("ROSS_RUNTIME_ARTIFACT_FETCH_DOWNLOADER_COMMAND", "")
venv_python = os.environ.get("ROSS_RUNTIME_ARTIFACT_FETCH_VENV_PYTHON", "")

tier_aliases = {
    "quickStart": {"quickStart", "quick_start"},
    "quick_start": {"quickStart", "quick_start"},
    "caseAssociate": {"caseAssociate", "case_associate"},
    "case_associate": {"caseAssociate", "case_associate"},
    "seniorDraftingSupport": {"seniorDraftingSupport", "senior_drafting_support"},
    "senior_drafting_support": {"seniorDraftingSupport", "senior_drafting_support"},
}
accepted_tiers = tier_aliases.get(tier, {tier})

def parse_line(line: str) -> dict[str, str]:
    if not line.startswith("ROSS_RUNTIME_ARTIFACT_INVENTORY "):
        return {}
    fields: dict[str, str] = {}
    for token in shlex.split(line[len("ROSS_RUNTIME_ARTIFACT_INVENTORY "):]):
        if "=" not in token:
            continue
        key, value = token.split("=", 1)
        fields[key] = value
    return fields

rows = [row for row in (parse_line(line) for line in raw_inventory) if row]

def q(value: object) -> str:
    return shlex.quote(str(value))

def command(*args: object) -> str:
    return " ".join(shlex.quote(str(arg)) for arg in args)

def row_tier_matches(row: dict[str, str]) -> bool:
    return row.get("tier") in accepted_tiers

def emit(lane: str, status: str, action: str, **fields: object) -> None:
    extras = " ".join(f"{key}={q(value)}" for key, value in fields.items() if value is not None)
    line = f"ROSS_RUNTIME_ARTIFACT_FETCH_PLAN lane={lane} status={status} action={action}"
    if extras:
        line += f" {extras}"
    print(line)

print(
    f"ROSS_RUNTIME_ARTIFACT_FETCH_PLAN dry_run=true tier={q(tier)} "
    f"target_root={q(target_root)} downloader_status={q(downloader_status)}"
)

if downloader_status == "missing":
    emit(
        "downloader",
        "missing",
        "install",
        command=f"python3 -m venv {shlex.quote(str(target_root / '.hf-venv'))} && "
        f"{shlex.quote(str(target_root / '.hf-venv/bin/python'))} -m pip install --upgrade pip huggingface_hub",
    )

present_mlx = next((row for row in rows if row.get("lane") == "mlx" and row.get("status") == "present"), None)
present_mlx_draft = next((row for row in rows if row.get("lane") == "mlx_draft" and row.get("status") == "present"), None)
if present_mlx:
    model_path = present_mlx.get("path", "")
    emit(
        "mlx",
        "present",
        "preflight",
        path=model_path,
        command=command(
            root_dir / "scripts/ios-simulator-local-model-smoke.sh",
            "--runtime", "mlx",
            "--model", model_path,
            "--preflight-only",
        ),
    )
    if present_mlx_draft:
        emit(
            "mlx_draft",
            "present",
            "preflight_pair",
            path=present_mlx_draft.get("path", ""),
            command=command(
                root_dir / "scripts/ios-simulator-local-model-smoke.sh",
                "--runtime", "mlx",
                "--model", model_path,
                "--draft-model", present_mlx_draft.get("path", ""),
                "--draft-tokens", 2,
                "--require-draft-acceleration",
                "--smoke-profile", "mtp_quick",
                "--preflight-only",
            ),
        )
else:
    catalog_rows = [
        row for row in rows
        if row.get("lane") in {"catalog_mlx", "catalog_mlx_draft"}
        and row.get("status") == "expected"
        and row_tier_matches(row)
    ]
    for row in catalog_rows:
        file_name = row.get("file") or pathlib.PurePosixPath(row.get("path", "mlx-model")).name
        target_dir = target_root / file_name
        lane = "mlx_draft" if row.get("lane") == "catalog_mlx_draft" else "mlx"
        repo = row.get("repo", "unknown")
        if lane == "mlx_draft" and present_mlx_draft:
            emit(
                lane,
                "present",
                "waiting_for_primary",
                path=present_mlx_draft.get("path", ""),
            )
            continue
        emit(
            lane,
            "missing",
            "download",
            repo=repo,
            target_dir=target_dir,
            bytes=row.get("bytes"),
            checksum=row.get("checksum"),
            command=f"{downloader_command or 'hf'} download {shlex.quote(repo)} --local-dir {shlex.quote(str(target_dir))}",
        )
        emit(
            lane,
            "missing",
            "preflight_after_download",
            target_dir=target_dir,
            command=command(
                root_dir / "scripts/ios-simulator-local-model-smoke.sh",
                "--runtime", "mlx",
                "--model", target_dir,
                "--preflight-only",
            ),
        )

coreai_system = next((row for row in rows if row.get("lane") == "coreai_system"), None)
if coreai_system:
    emit(
        "coreai_system",
        coreai_system.get("status", "unknown"),
        "preflight",
        path="system://apple-foundation-models",
        command=command(
            root_dir / "scripts/ios-simulator-local-model-smoke.sh",
            "--runtime", "coreml",
            "--artifact-kind", "system_model",
            "--model", "system://apple-foundation-models",
            "--preflight-only",
        ),
    )

coreai_adapter = next((row for row in rows if row.get("lane") == "coreai_adapter" and row.get("status") == "present"), None)
if coreai_adapter:
    adapter_path = coreai_adapter.get("path", "")
    emit(
        "coreai_adapter",
        "present",
        "preflight",
        path=adapter_path,
        command=command(
            root_dir / "scripts/ios-simulator-local-model-smoke.sh",
            "--runtime", "coreml",
            "--artifact-kind", "foundation_adapter",
            "--model", adapter_path,
            "--preflight-only",
        ),
    )
PY

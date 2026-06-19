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
  --physical-memory-bytes <bytes>
                         Optional target memory used for MTP preflight memory-fit gating.

Dry-run only. Prints artifact acquisition and simulator preflight commands for
GGUF/MTP, MLX, and CoreAI readiness without launching Simulator, devicectl,
or the app.
EOF
}

tier="quickStart"
target_root="$HOME/model-artifacts"
search_roots=()
physical_memory_bytes=""

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
    --physical-memory-bytes)
      physical_memory_bytes="${2:-}"
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

if [[ -n "$physical_memory_bytes" && ( "$physical_memory_bytes" == *[!0-9]* || "$physical_memory_bytes" -le 0 ) ]]; then
  echo "Physical memory bytes must be a positive integer." >&2
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
if [[ -n "$physical_memory_bytes" ]]; then
  inventory_args+=(--physical-memory-bytes "$physical_memory_bytes")
fi
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
ROSS_RUNTIME_ARTIFACT_FETCH_PHYSICAL_MEMORY_BYTES="$physical_memory_bytes" \
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
physical_memory_bytes = os.environ.get("ROSS_RUNTIME_ARTIFACT_FETCH_PHYSICAL_MEMORY_BYTES", "").strip()

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
    f"target_root={q(target_root)} downloader_status={q(downloader_status)} "
    f"physical_memory_bytes={q(physical_memory_bytes or 'nil')}"
)

def maybe_physical_memory_args() -> list[str]:
    return ["--physical-memory-bytes", physical_memory_bytes] if physical_memory_bytes else []

if downloader_status == "missing":
    emit(
        "downloader",
        "missing",
        "install",
        command=f"python3 -m venv {shlex.quote(str(target_root / '.hf-venv'))} && "
        f"{shlex.quote(str(target_root / '.hf-venv/bin/python'))} -m pip install --upgrade pip huggingface_hub",
    )

present_gguf_candidates = [row for row in rows if row.get("lane") == "gguf" and row.get("status") == "present"]
present_mtp_draft_candidates = [row for row in rows if row.get("lane") == "mtp_draft" and row.get("status") == "present"]
catalog_gguf = next(
    (
        row for row in rows
        if row.get("lane") == "catalog_gguf"
        and row.get("status") == "expected"
        and row_tier_matches(row)
    ),
    None,
)
catalog_mtp_draft = next(
    (
        row for row in rows
        if row.get("lane") == "catalog_mtp_draft"
        and row.get("status") == "expected"
        and row_tier_matches(row)
    ),
    None,
)

if catalog_gguf:
    primary_file = catalog_gguf.get("file") or pathlib.PurePosixPath(catalog_gguf.get("path", "model.gguf")).name
    expected_primary_path = target_root / primary_file
    present_gguf = next(
        (
            row for row in present_gguf_candidates
            if pathlib.PurePath(row.get("path", "")).name == primary_file
        ),
        None,
    )
    primary_path = present_gguf.get("path", "") if present_gguf else str(expected_primary_path)
    if present_gguf:
        emit(
            "gguf",
            "present",
            "preflight",
            path=primary_path,
            command=command(
                root_dir / "scripts/ios-simulator-local-model-smoke.sh",
                "--runtime", "gguf",
                "--model", primary_path,
                "--smoke-profile", "quick_low_context",
                *maybe_physical_memory_args(),
                "--preflight-only",
            ),
        )
    else:
        repo = catalog_gguf.get("repo", "unknown")
        emit(
            "gguf",
            "missing",
            "download",
            repo=repo,
            target_file=expected_primary_path,
            bytes=catalog_gguf.get("bytes"),
            checksum=catalog_gguf.get("checksum"),
            command=f"{downloader_command or 'hf'} download {shlex.quote(repo)} {shlex.quote(primary_file)} --local-dir {shlex.quote(str(target_root))}",
        )
        emit(
            "gguf",
            "missing",
            "preflight_after_download",
            target_file=expected_primary_path,
            command=command(
                root_dir / "scripts/ios-simulator-local-model-smoke.sh",
                "--runtime", "gguf",
                "--model", expected_primary_path,
                "--smoke-profile", "quick_low_context",
                *maybe_physical_memory_args(),
                "--preflight-only",
            ),
        )

    if catalog_mtp_draft:
        draft_file = catalog_mtp_draft.get("file") or pathlib.PurePosixPath(catalog_mtp_draft.get("path", "draft.gguf")).name
        expected_draft_path = target_root / draft_file
        present_mtp_draft = next(
            (
                row for row in present_mtp_draft_candidates
                if pathlib.PurePath(row.get("path", "")).name == draft_file
            ),
            None,
        )
        draft_path = present_mtp_draft.get("path", "") if present_mtp_draft else str(expected_draft_path)
        if present_mtp_draft:
            emit(
                "mtp_draft",
                "present",
                "waiting_for_primary" if not present_gguf else "preflight_pair",
                path=draft_path,
                command=command(
                    root_dir / "scripts/ios-simulator-local-model-smoke.sh",
                    "--runtime", "gguf",
                    "--model", primary_path,
                    "--draft-model", draft_path,
                    "--draft-tokens", 2,
                    "--require-draft-acceleration",
                    "--smoke-profile", "mtp_quick",
                    *maybe_physical_memory_args(),
                    "--preflight-only",
                ) if present_gguf else None,
            )
        else:
            repo = catalog_mtp_draft.get("repo", "unknown")
            emit(
                "mtp_draft",
                "missing",
                "download",
                repo=repo,
                target_file=expected_draft_path,
                bytes=catalog_mtp_draft.get("bytes"),
                checksum=catalog_mtp_draft.get("checksum"),
                command=f"{downloader_command or 'hf'} download {shlex.quote(repo)} {shlex.quote(draft_file)} --local-dir {shlex.quote(str(target_root))}",
            )
            emit(
                "mtp_draft",
                "missing",
                "preflight_pair_after_download",
                target_file=expected_draft_path,
                command=command(
                    root_dir / "scripts/ios-simulator-local-model-smoke.sh",
                    "--runtime", "gguf",
                    "--model", primary_path,
                    "--draft-model", expected_draft_path,
                    "--draft-tokens", 2,
                    "--require-draft-acceleration",
                    "--smoke-profile", "mtp_quick",
                    *maybe_physical_memory_args(),
                    "--preflight-only",
                ),
            )

present_mlx = next((row for row in rows if row.get("lane") == "mlx" and row.get("status") == "present"), None)
present_mlx_draft = next((row for row in rows if row.get("lane") == "mlx_draft" and row.get("status") == "present"), None)
catalog_mlx_draft = next(
    (
        row for row in rows
        if row.get("lane") == "catalog_mlx_draft"
        and row.get("status") == "expected"
        and row_tier_matches(row)
    ),
    None,
)
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
    elif catalog_mlx_draft:
        file_name = catalog_mlx_draft.get("file") or pathlib.PurePosixPath(catalog_mlx_draft.get("path", "mlx-draft")).name
        target_dir = target_root / file_name
        repo = catalog_mlx_draft.get("repo", "unknown")
        emit(
            "mlx_draft",
            "missing",
            "download",
            repo=repo,
            target_dir=target_dir,
            bytes=catalog_mlx_draft.get("bytes"),
            checksum=catalog_mlx_draft.get("checksum"),
            command=f"{downloader_command or 'hf'} download {shlex.quote(repo)} --local-dir {shlex.quote(str(target_dir))}",
        )
        emit(
            "mlx_draft",
            "missing",
            "preflight_pair_after_download",
            target_dir=target_dir,
            command=command(
                root_dir / "scripts/ios-simulator-local-model-smoke.sh",
                "--runtime", "mlx",
                "--model", model_path,
                "--draft-model", target_dir,
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
        if lane == "mlx" and row.get("release_ready") == "false":
            emit(
                lane,
                "blocked",
                "await_compatible_archive",
                repo=repo,
                target_dir=target_dir,
                reason="catalog_primary_not_release_ready",
                compatibility_hint="runtime_requires_supported_text_mlx_archive",
            )
            continue
        if lane == "mlx_draft" and present_mlx_draft:
            emit(
                lane,
                "present",
                "waiting_for_primary",
                path=present_mlx_draft.get("path", ""),
                reason="missing_compatible_mlx_primary",
            )
            continue
        if lane == "mlx_draft":
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
                "waiting_for_primary_after_download",
                target_dir=target_dir,
                reason="missing_compatible_mlx_primary",
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

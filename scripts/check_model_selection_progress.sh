#!/usr/bin/env bash
set -euo pipefail
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"; cd "$REPO_DIR"

usage() {
  echo "Usage: $0 --run_dir <results/.../run_id> [--tail <n>]" >&2
  exit 1
}

RUN_DIR=""
TAIL_N="8"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --run_dir) RUN_DIR="$2"; shift 2 ;;
    --tail) TAIL_N="$2"; shift 2 ;;
    *) echo "Unknown arg: $1"; usage ;;
  esac
done

if [[ -z "$RUN_DIR" ]]; then
  usage
fi

Rscript scripts/model_selection_status.R --run_dir "$RUN_DIR" --tail "$TAIL_N"

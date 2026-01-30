#!/usr/bin/env bash
set -euo pipefail
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"; cd "$REPO_DIR"

usage() {
  echo "Usage: $0 --slug <dataset_slug> --spec <model_selection_spec> [--out_dir <path>] [--overwrite] [--dry_run]" >&2
  exit 1
}

SLUG=""
SPEC=""
OUT_DIR=""
OVERWRITE=""
DRY_RUN=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --slug) SLUG="$2"; shift 2 ;;
    --spec) SPEC="$2"; shift 2 ;;
    --out_dir) OUT_DIR="$2"; shift 2 ;;
    --overwrite) OVERWRITE="--overwrite"; shift ;;
    --dry_run|--dry-run) DRY_RUN="--dry_run"; shift ;;
    *) echo "Unknown arg: $1"; usage ;;
  esac
done

if [[ -z "$SLUG" || -z "$SPEC" ]]; then
  usage
fi

CMD=(Rscript scripts/model_selection_run.R --slug "$SLUG" --spec "$SPEC")
if [[ -n "$OUT_DIR" ]]; then CMD+=(--out_dir "$OUT_DIR"); fi
if [[ -n "$OVERWRITE" ]]; then CMD+=(--overwrite); fi
if [[ -n "$DRY_RUN" ]]; then CMD+=(--dry_run); fi

"${CMD[@]}"

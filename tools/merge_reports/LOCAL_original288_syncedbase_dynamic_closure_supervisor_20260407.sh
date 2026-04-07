#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$REPO_ROOT"

LOG_DIR="$REPO_ROOT/tools/merge_reports/full288_original288_syncedbase_dynamic_closure_20260407"
mkdir -p "$LOG_DIR"

exec bash "$REPO_ROOT/tools/merge_reports/LOCAL_original288_syncedbase_dynamic_closure_launch_20260407.sh" "$@" \
  2>&1 | tee "$LOG_DIR/supervisor.log"

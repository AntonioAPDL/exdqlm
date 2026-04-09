#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$REPO_ROOT"

LOG_DIR="$REPO_ROOT/tools/merge_reports/static_bqrgal_aligned_20260408"
mkdir -p "$LOG_DIR"

exec bash "$REPO_ROOT/tools/merge_reports/LOCAL_static_bqrgal_aligned_launch_20260408.sh" "$@" \
  2>&1 | tee "$LOG_DIR/supervisor.log"

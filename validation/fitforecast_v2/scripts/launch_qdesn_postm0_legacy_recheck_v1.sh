#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="${1:-$(git rev-parse --show-toplevel)}"
RUN_ID="${RUN_ID:-qdesn_postm0_legacy_recheck_v1_$(date +%Y%m%d_%H%M%S)}"
RUN_TAG="${RUN_TAG:-qdesn-postm0-legacy-recheck-v1-$(date +%Y%m%d_%H%M%S)__git-$(git -C "$REPO_ROOT" rev-parse --short HEAD)}"
SESSION="${SESSION:-ffv2_postm0_legacy_recheck_v1_$(date +%Y%m%d_%H%M%S)}"
WORKERS="${WORKERS:-20}"
MAX_LOAD="${MAX_LOAD:-52}"
MIN_MEMORY_GB="${MIN_MEMORY_GB:-64}"
MIN_DISK_GB="${MIN_DISK_GB:-80}"
POLL_SECONDS="${POLL_SECONDS:-300}"
HEARTBEAT_SECONDS="${HEARTBEAT_SECONDS:-1800}"
MAX_IDLE_CPU_PERCENT="${MAX_IDLE_CPU_PERCENT:-20}"
STATE_ROOT="$REPO_ROOT/reports/shared_fitforecast_v2_orchestration/$RUN_ID"
STDOUT_LOG="$STATE_ROOT/pipeline.stdout.log"
mkdir -p "$STATE_ROOT"

tmux new-session -d -s "$SESSION" \
  "cd '$REPO_ROOT' && WORKERS='$WORKERS' MAX_LOAD='$MAX_LOAD' MIN_MEMORY_GB='$MIN_MEMORY_GB' MIN_DISK_GB='$MIN_DISK_GB' POLL_SECONDS='$POLL_SECONDS' HEARTBEAT_SECONDS='$HEARTBEAT_SECONDS' MAX_IDLE_CPU_PERCENT='$MAX_IDLE_CPU_PERCENT' validation/fitforecast_v2/scripts/run_qdesn_postm0_legacy_recheck_v1_pipeline.sh '$REPO_ROOT' '$RUN_ID' '$RUN_TAG' > '$STDOUT_LOG' 2>&1"

printf 'session=%s\nrun_id=%s\nrun_tag=%s\nworkers=%s\nmax_load=%s\nmin_memory_gb=%s\nmin_disk_gb=%s\nstate_root=%s\nstdout_log=%s\n' \
  "$SESSION" "$RUN_ID" "$RUN_TAG" "$WORKERS" "$MAX_LOAD" \
  "$MIN_MEMORY_GB" "$MIN_DISK_GB" "$STATE_ROOT" "$STDOUT_LOG"

#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="${1:-$(git rev-parse --show-toplevel)}"
RUN_ID="${2:?RUN_ID is required}"
RUN_TAG="${3:?RUN_TAG is required}"
WORKERS="${WORKERS:-3}"
MAX_LOAD="${MAX_LOAD:-52}"
MIN_MEMORY_GB="${MIN_MEMORY_GB:-64}"
MIN_DISK_GB="${MIN_DISK_GB:-80}"
POLL_SECONDS="${POLL_SECONDS:-300}"
HEARTBEAT_SECONDS="${HEARTBEAT_SECONDS:-1800}"
MAX_IDLE_CPU_PERCENT="${MAX_IDLE_CPU_PERCENT:-20}"
SESSION="${SESSION:-ffv2_postm0_forecast_confirmation_$(date +%Y%m%d_%H%M%S)}"
STATE_ROOT="$REPO_ROOT/reports/shared_fitforecast_v2_orchestration/$RUN_ID"
STDOUT_LOG="$STATE_ROOT/forecast_first_confirmation.stdout.log"
mkdir -p "$STATE_ROOT"
printf '\n[%s] launch_attempt session=%s stage=forecast_first_confirmation\n' \
  "$(date --iso-8601=seconds)" "$SESSION" >> "$STDOUT_LOG"
tmux new-session -d -s "$SESSION" \
  "cd '$REPO_ROOT' && QDESN_PLRV1_FORECAST_CONFIRMATION_APPROVED=true WORKERS='$WORKERS' MAX_LOAD='$MAX_LOAD' MIN_MEMORY_GB='$MIN_MEMORY_GB' MIN_DISK_GB='$MIN_DISK_GB' POLL_SECONDS='$POLL_SECONDS' HEARTBEAT_SECONDS='$HEARTBEAT_SECONDS' MAX_IDLE_CPU_PERCENT='$MAX_IDLE_CPU_PERCENT' validation/fitforecast_v2/scripts/run_qdesn_postm0_legacy_recheck_v1_confirmation.sh '$REPO_ROOT' '$RUN_ID' '$RUN_TAG' >> '$STDOUT_LOG' 2>&1"
printf '%s\n' \
  "session=$SESSION" \
  "run_id=$RUN_ID" \
  "run_tag=$RUN_TAG" \
  "stage=forecast_first_confirmation" \
  "workers=$WORKERS" \
  "state_root=$STATE_ROOT" \
  "stdout_log=$STDOUT_LOG"

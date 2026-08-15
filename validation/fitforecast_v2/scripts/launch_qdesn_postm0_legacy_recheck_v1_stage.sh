#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="${1:-$(git rev-parse --show-toplevel)}"
RUN_ID="${2:?RUN_ID is required}"
RUN_TAG="${3:?RUN_TAG is required}"
STAGE="${4:?STAGE is required: tier_a_replication or tier_a_sealed}"
WORKERS="${WORKERS:-20}"
MAX_LOAD="${MAX_LOAD:-52}"
MIN_MEMORY_GB="${MIN_MEMORY_GB:-64}"
MIN_DISK_GB="${MIN_DISK_GB:-80}"
POLL_SECONDS="${POLL_SECONDS:-300}"
HEARTBEAT_SECONDS="${HEARTBEAT_SECONDS:-1800}"
MAX_IDLE_CPU_PERCENT="${MAX_IDLE_CPU_PERCENT:-20}"

case "$STAGE" in
  tier_a_replication|tier_a_sealed) ;;
  *) echo "Unsupported stage: $STAGE" >&2; exit 2 ;;
esac

SESSION="${SESSION:-ffv2_postm0_legacy_recheck_v1_${STAGE}_$(date +%Y%m%d_%H%M%S)}"
STATE_ROOT="$REPO_ROOT/reports/shared_fitforecast_v2_orchestration/$RUN_ID"
STDOUT_LOG="$STATE_ROOT/${STAGE}.stdout.log"
mkdir -p "$STATE_ROOT"
printf '\n[%s] launch_attempt session=%s stage=%s\n' \
  "$(date --iso-8601=seconds)" "$SESSION" "$STAGE" >> "$STDOUT_LOG"

tmux new-session -d -s "$SESSION" \
  "cd '$REPO_ROOT' && WORKERS='$WORKERS' MAX_LOAD='$MAX_LOAD' MIN_MEMORY_GB='$MIN_MEMORY_GB' MIN_DISK_GB='$MIN_DISK_GB' POLL_SECONDS='$POLL_SECONDS' HEARTBEAT_SECONDS='$HEARTBEAT_SECONDS' MAX_IDLE_CPU_PERCENT='$MAX_IDLE_CPU_PERCENT' validation/fitforecast_v2/scripts/run_qdesn_postm0_legacy_recheck_v1_stage.sh '$REPO_ROOT' '$RUN_ID' '$RUN_TAG' '$STAGE' >> '$STDOUT_LOG' 2>&1"

printf 'session=%s\nrun_id=%s\nrun_tag=%s\nstage=%s\nworkers=%s\nstate_root=%s\nstdout_log=%s\n' \
  "$SESSION" "$RUN_ID" "$RUN_TAG" "$STAGE" "$WORKERS" "$STATE_ROOT" \
  "$STDOUT_LOG"

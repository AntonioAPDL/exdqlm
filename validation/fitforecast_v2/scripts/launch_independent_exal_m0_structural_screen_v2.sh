#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="${1:-$(git rev-parse --show-toplevel)}"
STAMP="$(date +%Y%m%d_%H%M%S)"
RUN_ID="${2:-independent_exal_m0_structural_screen_v2_${STAMP}}"
SESSION="${3:-ffv2_ind_exal_m0_struct_v2_${STAMP}}"
RUN_TAG="${4:-ind-exal-m0-struct-v2-${STAMP}__git-$(git -C "$REPO_ROOT" rev-parse --short HEAD)}"
WORKERS="${WORKERS:-20}"
MAX_LOAD="${MAX_LOAD:-52}"
MIN_MEMORY_GB="${MIN_MEMORY_GB:-64}"
MIN_DISK_GB="${MIN_DISK_GB:-80}"
MAX_IDLE_CPU_PERCENT="${MAX_IDLE_CPU_PERCENT:-20}"
POLL_SECONDS="${POLL_SECONDS:-300}"
HEARTBEAT_SECONDS="${HEARTBEAT_SECONDS:-1800}"
cd "$REPO_ROOT"
EXPECTED_BRANCH="validation/independent-exal-m0-structural-screen-v2-1.0.0"
if [[ "$(git branch --show-current)" != "$EXPECTED_BRANCH" ]]; then
  echo "Launch refused outside $EXPECTED_BRANCH" >&2; exit 2
fi
if [[ -n "$(git status --porcelain)" ]]; then
  echo "Launch refused from a dirty worktree." >&2; git status --short >&2; exit 2
fi
if ! git rev-parse --abbrev-ref '@{upstream}' >/dev/null 2>&1; then
  echo "Launch refused without an upstream." >&2; exit 2
fi
read -r BEHIND AHEAD < <(git rev-list --left-right --count '@{upstream}...HEAD')
if [[ "$BEHIND" -ne 0 || "$AHEAD" -ne 0 ]]; then
  echo "Launch refused: upstream mismatch (behind=$BEHIND ahead=$AHEAD)." >&2; exit 2
fi
if [[ "$WORKERS" -lt 1 || "$WORKERS" -gt 20 ]]; then
  echo "WORKERS must be between 1 and 20." >&2; exit 2
fi
if tmux has-session -t "$SESSION" 2>/dev/null; then
  echo "tmux session already exists: $SESSION" >&2; exit 2
fi
STATE_ROOT="reports/shared_fitforecast_v2_orchestration/${RUN_ID}"
mkdir -p "$STATE_ROOT"
STDOUT_LOG="$STATE_ROOT/pipeline.stdout.log"
PIPELINE="validation/fitforecast_v2/scripts/run_independent_exal_m0_structural_screen_v2_pipeline.sh"
printf '%s\n' "$SESSION" > "$STATE_ROOT/tmux_session.txt"
printf '%s\n' "$RUN_ID" > "$STATE_ROOT/run_id.txt"
printf '%s\n' "$RUN_TAG" > "$STATE_ROOT/run_tag.txt"
printf '%s\n' "$(git rev-parse HEAD)" > "$STATE_ROOT/launch_commit.txt"
printf 'WORKERS=%s\nMAX_LOAD=%s\nMIN_MEMORY_GB=%s\nMIN_DISK_GB=%s\nMAX_IDLE_CPU_PERCENT=%s\nPOLL_SECONDS=%s\nHEARTBEAT_SECONDS=%s\n' \
  "$WORKERS" "$MAX_LOAD" "$MIN_MEMORY_GB" "$MIN_DISK_GB" \
  "$MAX_IDLE_CPU_PERCENT" "$POLL_SECONDS" "$HEARTBEAT_SECONDS" \
  > "$STATE_ROOT/launcher_resources.env"
tmux new-session -d -s "$SESSION" \
  "cd '$REPO_ROOT' && exec env WORKERS='$WORKERS' MAX_LOAD='$MAX_LOAD' MIN_MEMORY_GB='$MIN_MEMORY_GB' MIN_DISK_GB='$MIN_DISK_GB' MAX_IDLE_CPU_PERCENT='$MAX_IDLE_CPU_PERCENT' POLL_SECONDS='$POLL_SECONDS' HEARTBEAT_SECONDS='$HEARTBEAT_SECONDS' bash '$PIPELINE' '$REPO_ROOT' '$RUN_ID' '$RUN_TAG' > '$STDOUT_LOG' 2>&1"
sleep 2
if ! tmux has-session -t "$SESSION" 2>/dev/null; then
  echo "Pipeline exited during startup; inspect $STDOUT_LOG" >&2; exit 3
fi
printf 'session=%s\nrun_id=%s\nrun_tag=%s\nworkers=%s\nstate_root=%s\nstdout_log=%s\n' \
  "$SESSION" "$RUN_ID" "$RUN_TAG" "$WORKERS" "$STATE_ROOT" "$STDOUT_LOG"

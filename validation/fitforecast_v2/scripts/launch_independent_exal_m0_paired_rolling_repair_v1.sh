#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

R_SCRIPT="${R_SCRIPT:-/data/jaguir26/local/opt/R/4.6.0/bin/Rscript}"
MODE="smoke"
WORKERS="2"
RUN_TAG=""
MATERIALIZATION_ROOT="${MATERIALIZATION_ROOT:-$REPO_ROOT/reports/shared_fitforecast_v2_orchestration/independent_exal_m0_paired_rolling_repair_v1_materialization}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode) MODE="$2"; shift 2 ;;
    --workers) WORKERS="$2"; shift 2 ;;
    --run-tag) RUN_TAG="$2"; shift 2 ;;
    --materialization-root) MATERIALIZATION_ROOT="$2"; shift 2 ;;
    *) printf 'Unknown argument: %s\n' "$1" >&2; exit 2 ;;
  esac
done

if [[ "$MODE" != "smoke" && "$MODE" != "calibration" ]]; then
  printf '%s\n' '--mode must be smoke or calibration' >&2
  exit 2
fi
if ! [[ "$WORKERS" =~ ^[1-9][0-9]*$ ]]; then
  printf '%s\n' '--workers must be a positive integer' >&2
  exit 2
fi
if [[ "$MODE" == "calibration" ]]; then
  if [[ "${QDESN_PAIRED_REPAIR_APPROVAL:-}" != "YES" ]]; then
    printf '%s\n' 'Calibration is gated. Set QDESN_PAIRED_REPAIR_APPROVAL=YES only after explicit approval.' >&2
    exit 3
  fi
  if (( WORKERS > 20 )); then
    printf '%s\n' 'Calibration workers may not exceed the predeclared 20-core cap.' >&2
    exit 3
  fi
fi

PLAN_NAME="${MODE}_plan.csv"
PLAN_PATH="$MATERIALIZATION_ROOT/$PLAN_NAME"
if [[ ! -f "$PLAN_PATH" ]]; then
  printf 'Missing plan: %s\n' "$PLAN_PATH" >&2
  exit 4
fi
if [[ -z "$RUN_TAG" ]]; then
  RUN_TAG="ind-exal-m0-paired-rolling-repair-v1-${MODE}-$(date +%Y%m%d_%H%M%S)"
fi

STATE_ROOT="$REPO_ROOT/reports/shared_fitforecast_v2_orchestration/$RUN_TAG"
mkdir -p "$STATE_ROOT/logs"
printf '%s\n' "$RUN_TAG" > "$STATE_ROOT/run_tag.txt"
printf '%s\n' "$MODE" > "$STATE_ROOT/mode.txt"
printf '%s\n' "$WORKERS" > "$STATE_ROOT/workers.txt"
git rev-parse HEAD > "$STATE_ROOT/launch_commit.txt"

"$R_SCRIPT" validation/fitforecast_v2/scripts/verify_independent_exal_m0_paired_rolling_repair_v1.R \
  --materialization-root "$MATERIALIZATION_ROOT" \
  --plan "$PLAN_NAME" \
  --output "$STATE_ROOT/prelaunch_verification.json" \
  > "$STATE_ROOT/prelaunch_verification.log" 2>&1

CONFIG_LIST="$STATE_ROOT/config_paths.txt"
"$R_SCRIPT" -e 'x <- read.csv(commandArgs(TRUE)[1], stringsAsFactors = FALSE); cat(x$config_path, sep = "\n")' \
  "$PLAN_PATH" > "$CONFIG_LIST"

export REPO_ROOT R_SCRIPT RUN_TAG STATE_ROOT
run_one() {
  local config="$1"
  local job_id
  job_id="$(basename "$config" .json)"
  "$R_SCRIPT" validation/fitforecast_v2/scripts/run_independent_exal_m0_structural_screen_v2_chain.R \
    --repo-root "$REPO_ROOT" --config "$config" --run-tag "$RUN_TAG" \
    > "$STATE_ROOT/logs/${job_id}.log" 2>&1
}
export -f run_one

set +e
xargs -r -n 1 -P "$WORKERS" bash -c 'run_one "$1"' _ < "$CONFIG_LIST"
launch_status=$?
set -e

set +e
"$R_SCRIPT" validation/fitforecast_v2/scripts/verify_independent_exal_m0_paired_rolling_repair_v1.R \
  --materialization-root "$MATERIALIZATION_ROOT" \
  --plan "$PLAN_NAME" --run-tag "$RUN_TAG" \
  --output "$STATE_ROOT/runtime_verification.json" \
  > "$STATE_ROOT/runtime_verification.log" 2>&1
verify_status=$?
set -e

if (( launch_status != 0 || verify_status != 0 )); then
  printf 'run_tag=%s mode=%s status=FAIL launch_status=%d verify_status=%d\n' \
    "$RUN_TAG" "$MODE" "$launch_status" "$verify_status"
  exit 1
fi

if [[ "$MODE" == "calibration" ]]; then
  "$R_SCRIPT" validation/fitforecast_v2/scripts/closeout_independent_exal_m0_paired_rolling_repair_v1.R \
    --materialization-root "$MATERIALIZATION_ROOT" --run-tag "$RUN_TAG" \
    --output-root "$STATE_ROOT/paired_closeout" \
    > "$STATE_ROOT/paired_closeout.log" 2>&1
fi
printf 'run_tag=%s mode=%s status=PASS jobs=%s\n' \
  "$RUN_TAG" "$MODE" "$(wc -l < "$CONFIG_LIST")"

#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="${1:-$(git rev-parse --show-toplevel)}"
RUN_ID="${2:?RUN_ID is required}"
RUN_TAG="${3:?RUN_TAG is required}"
RECOVERY_NAME="${4:-adaptive_recovery_selector_v3}"
R_SCRIPT="${R_SCRIPT:-/data/jaguir26/local/opt/R/4.6.0/bin/Rscript}"
WORKERS="${WORKERS:-16}"
EXPECTED_BRANCH="validation/independent-exal-m0-structural-screen-v2-1.0.0"
STATE_ROOT="$REPO_ROOT/reports/shared_fitforecast_v2_orchestration/$RUN_ID"
MATERIALIZATION_ROOT="$STATE_ROOT/materialization"
WAVE2_ROOT="$STATE_ROOT/adaptive"
WAVE3_ROOT="$STATE_ROOT/adaptive_recovery_selector_v2"
ADAPTIVE_ROOT="$STATE_ROOT/$RECOVERY_NAME"
STATUS_CSV="$STATE_ROOT/stage_status.csv"
CURRENT_STAGE="$STATE_ROOT/current_stage.txt"
WORKER="validation/fitforecast_v2/scripts/run_independent_exal_m0_structural_screen_v2_chain.R"
VERIFY="validation/fitforecast_v2/scripts/verify_independent_exal_m0_structural_screen_v2.R"
ADVANCE="validation/fitforecast_v2/scripts/advance_independent_exal_m0_structural_screen_v2.R"
LOCK_FILE="$REPO_ROOT/reports/shared_fitforecast_v2_orchestration/independent_exal_m0_structural_screen_v2.lock"
ATTEMPT_ID="$(date +%Y%m%d_%H%M%S)"

cd "$REPO_ROOT"
[[ "$(git branch --show-current)" == "$EXPECTED_BRANCH" ]] || { echo "Wrong branch" >&2; exit 3; }
[[ -z "$(git status --porcelain)" ]] || { echo "Recovery requires a clean worktree" >&2; exit 3; }
read -r BEHIND AHEAD < <(git rev-list --left-right --count '@{upstream}...HEAD')
[[ "$BEHIND" -eq 0 && "$AHEAD" -eq 0 ]] || { echo "Recovery requires synchronized HEAD" >&2; exit 3; }
[[ "$WORKERS" -ge 1 && "$WORKERS" -le 20 ]] || { echo "WORKERS must be 1..20" >&2; exit 3; }
[[ "$(cat "$STATE_ROOT/run_tag.txt")" == "$RUN_TAG" ]] || { echo "Run tag mismatch" >&2; exit 3; }
for path in "$MATERIALIZATION_ROOT" "$WAVE2_ROOT/wave2_plan.csv" "$WAVE3_ROOT/wave3_plan.csv"; do
  [[ -e "$path" ]] || { echo "Missing recovery evidence: $path" >&2; exit 3; }
done

exec 9>"$LOCK_FILE"
flock -n 9 || { echo "Another structural-screen pipeline is active" >&2; exit 3; }
export OMP_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 MKL_NUM_THREADS=1
export VECLIB_MAXIMUM_THREADS=1 NUMEXPR_NUM_THREADS=1 RCPP_PARALLEL_NUM_THREADS=1
mkdir -p "$ADAPTIVE_ROOT"
record_status() { printf '%s,%s,%s,%s\n' "$(date --iso-8601=seconds)" "$1" "$2" "${3//,/;}" >> "$STATUS_CSV"; }
set_stage() { printf '%s\n' "$1" > "$CURRENT_STAGE"; }

set_stage wave3_to_sealed_recovery_preflight
for spec in \
  "smoke:$MATERIALIZATION_ROOT/smoke_plan.csv" \
  "calibration:$MATERIALIZATION_ROOT/calibration_plan.csv" \
  "wave1:$MATERIALIZATION_ROOT/wave1_plan.csv" \
  "wave2:$WAVE2_ROOT/wave2_plan.csv" \
  "wave3:$WAVE3_ROOT/wave3_plan.csv"; do
  stage="${spec%%:*}"; plan="${spec#*:}"
  "$R_SCRIPT" "$VERIFY" --repo-root "$REPO_ROOT" --materialization-root "$MATERIALIZATION_ROOT" \
    --stage "$stage" --plan "$plan" --run-tag "$RUN_TAG" \
    --output "$STATE_ROOT/${stage}_presealed_recovery_${ATTEMPT_ID}.json" \
    > "$STATE_ROOT/${stage}_presealed_recovery_${ATTEMPT_ID}.log" 2>&1
done
"$R_SCRIPT" -e 'paths <- commandArgs(TRUE); x <- lapply(paths, jsonlite::read_json, simplifyVector=TRUE); expected <- vapply(x, function(z) as.integer(z$runtime_summary$expected), integer(1)); success <- vapply(x, function(z) as.integer(z$runtime_summary$success), integer(1)); stopifnot(sum(expected)==354L, identical(expected, success), all(vapply(x, function(z) identical(z$decision, "PASS"), logical(1))))' \
  "$STATE_ROOT/smoke_presealed_recovery_${ATTEMPT_ID}.json" \
  "$STATE_ROOT/calibration_presealed_recovery_${ATTEMPT_ID}.json" \
  "$STATE_ROOT/wave1_presealed_recovery_${ATTEMPT_ID}.json" \
  "$STATE_ROOT/wave2_presealed_recovery_${ATTEMPT_ID}.json" \
  "$STATE_ROOT/wave3_presealed_recovery_${ATTEMPT_ID}.json" \
  > "$STATE_ROOT/prior_354_root_gate_${ATTEMPT_ID}.log" 2>&1
record_status wave3_to_sealed_recovery_preflight COMPLETED "354 prior roots preserved;wave2 and wave3 reverified"

set_stage recovery_tests
"$R_SCRIPT" -e 'pkgload::load_all(".", quiet=TRUE); stopifnot(as.character(packageVersion("exdqlm")) == "1.0.0"); testthat::test_file("validation/fitforecast_v2/tests/testthat/test-independent-exal-m0-structural-screen-v2.R", reporter="summary", stop_on_failure=TRUE, stop_on_warning=TRUE)' \
  > "$STATE_ROOT/presealed_recovery_tests_${ATTEMPT_ID}.log" 2>&1
record_status recovery_tests COMPLETED "canonical profile and multi-root recovery contracts pass"

set_stage advance_wave3_recovery
"$R_SCRIPT" "$ADVANCE" --repo-root "$REPO_ROOT" --from wave3 --run-tag "$RUN_TAG" \
  --materialization-root "$MATERIALIZATION_ROOT" \
  --prior-adaptive-root "$WAVE3_ROOT" --prior-adaptive-root "$WAVE2_ROOT" \
  --output-root "$ADAPTIVE_ROOT" > "$STATE_ROOT/advance_after_wave3_recovery_${ATTEMPT_ID}.log" 2>&1
"$R_SCRIPT" "$VERIFY" --repo-root "$REPO_ROOT" --materialization-root "$MATERIALIZATION_ROOT" \
  --stage sealed --plan "$ADAPTIVE_ROOT/sealed_plan.csv" \
  --output "$STATE_ROOT/sealed_plan_verification_${ATTEMPT_ID}.json" \
  > "$STATE_ROOT/sealed_plan_verification_${ATTEMPT_ID}.log" 2>&1
record_status advance_wave3 RECOVERY_COMPLETED "76-job sealed plan materialized from preserved wave2/wave3 evidence"

set_stage sealed
CONFIG_LIST="$STATE_ROOT/sealed_configs_recovery_${ATTEMPT_ID}.txt"
WORKER_LOG="$STATE_ROOT/sealed_workers_recovery_${ATTEMPT_ID}.log"
"$R_SCRIPT" -e 'x <- read.csv(commandArgs(TRUE)[1], check.names=FALSE); stopifnot(nrow(x)==76L); writeLines(x$config_path)' \
  "$ADAPTIVE_ROOT/sealed_plan.csv" > "$CONFIG_LIST"
record_status sealed RECOVERY_STARTED "jobs=76;parallelism=${WORKERS};threads_per_job=1"
set +e
xargs -r -n 1 -P "$WORKERS" "$R_SCRIPT" "$WORKER" --repo-root "$REPO_ROOT" \
  --run-tag "$RUN_TAG" --config < "$CONFIG_LIST" > "$WORKER_LOG" 2>&1
RC="$?"
set -e
[[ "$RC" -eq 0 ]] || { record_status sealed RECOVERY_FAILED "worker_exit=${RC}"; exit "$RC"; }
"$R_SCRIPT" "$VERIFY" --repo-root "$REPO_ROOT" --materialization-root "$MATERIALIZATION_ROOT" \
  --stage sealed --plan "$ADAPTIVE_ROOT/sealed_plan.csv" --run-tag "$RUN_TAG" \
  --output "$STATE_ROOT/sealed_verification_recovery_${ATTEMPT_ID}.json" \
  > "$STATE_ROOT/sealed_verification_recovery_${ATTEMPT_ID}.log" 2>&1
record_status sealed RECOVERY_COMPLETED "jobs=76;finite_storage_light=all"

set_stage sealed_closeout
"$R_SCRIPT" "$ADVANCE" --repo-root "$REPO_ROOT" --from sealed --run-tag "$RUN_TAG" \
  --materialization-root "$MATERIALIZATION_ROOT" \
  --prior-adaptive-root "$ADAPTIVE_ROOT" --prior-adaptive-root "$WAVE3_ROOT" \
  --prior-adaptive-root "$WAVE2_ROOT" --output-root "$ADAPTIVE_ROOT" \
  > "$STATE_ROOT/advance_after_sealed_recovery_${ATTEMPT_ID}.log" 2>&1
"$R_SCRIPT" -e 'x <- read.csv(commandArgs(TRUE)[1], check.names=FALSE); stopifnot(nrow(x)==21L, all(!x$launch_approved))' \
  "$ADAPTIVE_ROOT/canonical_confirmation_plan.csv" \
  > "$STATE_ROOT/confirmation_block_gate_${ATTEMPT_ID}.log" 2>&1
set_stage complete
record_status complete RECOVERY_COMPLETED "430 automated roots closed;21 confirmation jobs blocked;article unchanged"
printf 'Structural screen v2 sealed recovery complete: %s\n' "$RUN_TAG"

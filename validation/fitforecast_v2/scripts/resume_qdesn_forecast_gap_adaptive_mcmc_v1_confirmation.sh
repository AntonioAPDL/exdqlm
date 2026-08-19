#!/usr/bin/env bash
set -Eeuo pipefail

REPO_ROOT="${1:-$(git rev-parse --show-toplevel)}"
RUN_ID="${2:?RUN_ID is required}"
RUN_TAG="${3:?RUN_TAG is required}"
R_SCRIPT="${R_SCRIPT:-/data/jaguir26/local/opt/R/4.6.0/bin/Rscript}"
WORKERS="${WORKERS:-20}"
MAX_LOAD="${MAX_LOAD:-52}"
MIN_MEMORY_GB="${MIN_MEMORY_GB:-64}"
MIN_DISK_GB="${MIN_DISK_GB:-80}"
MAX_IDLE_CPU_PERCENT="${MAX_IDLE_CPU_PERCENT:-20}"
POLL_SECONDS="${POLL_SECONDS:-300}"
HEARTBEAT_SECONDS="${HEARTBEAT_SECONDS:-1800}"
EXPECTED_CONFIRMATION_JOBS="${EXPECTED_CONFIRMATION_JOBS:-24}"
PREFLIGHT_ONLY="${QDESN_FGAV1_CONFIRMATION_PREFLIGHT_ONLY:-false}"

[[ "${QDESN_FGAV1_CONFIRMATION_RESUME_APPROVED:-false}" == "true" ]] || {
  echo "Explicit confirmation-resume approval is required." >&2
  exit 3
}
[[ "$WORKERS" -ge 1 && "$WORKERS" -le 20 ]] || {
  echo "WORKERS must be between 1 and 20." >&2
  exit 3
}

cd "$REPO_ROOT"
EXPECTED_BRANCH="validation/qdesn-forecast-gap-adaptive-mcmc-v1-1.0.0"
STATE_ROOT="$REPO_ROOT/reports/shared_fitforecast_v2_orchestration/$RUN_ID"
MATERIALIZATION_ROOT="$STATE_ROOT/materialization"
ADAPTIVE_ROOT="$STATE_ROOT/adaptive"
CONFIRMATION_ROOT="$STATE_ROOT/confirmation"
PLAN="$CONFIRMATION_ROOT/confirmation_plan.csv"
MANIFEST="$CONFIRMATION_ROOT/confirmation_materialization_manifest.json"
RUN_ENV="$STATE_ROOT/run_tags.env"
STATUS_CSV="$STATE_ROOT/stage_status.csv"
HEARTBEAT_CSV="$STATE_ROOT/heartbeat.csv"
CURRENT_STAGE="$STATE_ROOT/current_stage.txt"
WORKER="validation/fitforecast_v2/scripts/run_qdesn_forecast_gap_adaptive_mcmc_v1_chain.R"
VERIFY="validation/fitforecast_v2/scripts/verify_qdesn_forecast_gap_adaptive_mcmc_v1.R"
CONFIRM_VERIFY="validation/fitforecast_v2/scripts/verify_qdesn_forecast_gap_adaptive_mcmc_v1_confirmation.R"
CLOSEOUT="validation/fitforecast_v2/scripts/closeout_qdesn_forecast_gap_adaptive_mcmc_v1_confirmation.R"
HEALTH="validation/fitforecast_v2/scripts/healthcheck_qdesn_forecast_gap_adaptive_mcmc_v1.R"
LOCK_FILE="$REPO_ROOT/reports/shared_fitforecast_v2_orchestration/qdesn_forecast_gap_adaptive_mcmc_v1.lock"
ATTEMPT_ID="$(date +%Y%m%d_%H%M%S)"

for path in "$STATE_ROOT" "$MATERIALIZATION_ROOT" "$ADAPTIVE_ROOT" \
  "$CONFIRMATION_ROOT" "$PLAN" "$MANIFEST" "$RUN_ENV" "$STATUS_CSV"; do
  [[ -e "$path" ]] || { echo "Missing recovery evidence: $path" >&2; exit 3; }
done

env_value() {
  awk -F= -v key="$1" '$1 == key {sub(/^[^=]*=/, ""); print; exit}' "$RUN_ENV"
}
PARENT_RUN_ID="$(env_value RUN_ID)"
PARENT_RUN_TAG="$(env_value RUN_TAG)"
PARENT_COMMIT="$(env_value GIT_COMMIT)"
[[ "$PARENT_RUN_ID" == "$RUN_ID" ]] || { echo "Run ID mismatch." >&2; exit 3; }
[[ "$PARENT_RUN_TAG" == "$RUN_TAG" ]] || { echo "Run tag mismatch." >&2; exit 3; }
git cat-file -e "${PARENT_COMMIT}^{commit}" 2>/dev/null || {
  echo "Original campaign commit is unavailable: $PARENT_COMMIT" >&2
  exit 3
}

[[ "$(git branch --show-current)" == "$EXPECTED_BRANCH" ]] || {
  echo "Recovery refused outside $EXPECTED_BRANCH" >&2
  exit 3
}
[[ -z "$(git status --porcelain)" ]] || {
  echo "Recovery requires a clean worktree." >&2
  exit 3
}
git rev-parse --abbrev-ref '@{upstream}' >/dev/null 2>&1 || {
  echo "Recovery requires an upstream." >&2
  exit 3
}
read -r BEHIND AHEAD < <(git rev-list --left-right --count '@{upstream}...HEAD')
[[ "$BEHIND" -eq 0 && "$AHEAD" -eq 0 ]] || {
  echo "Recovery requires synchronized HEAD (behind=$BEHIND ahead=$AHEAD)." >&2
  exit 3
}
git merge-base --is-ancestor "$PARENT_COMMIT" HEAD || {
  echo "Recovery HEAD does not descend from the original campaign commit." >&2
  exit 3
}

IMMUTABLE_SCIENTIFIC_PATHS=(
  config/validation/qdesn_dynamic_fitforecast_v2_500obs_forecast_gap_adaptive_mcmc_v1_sources.yaml
  config/validation/qdesn_dynamic_fitforecast_v2_500obs_forecast_gap_adaptive_mcmc_v1_target_cells.csv
  config/validation/qdesn_dynamic_fitforecast_v2_500obs_forecast_gap_adaptive_mcmc_v1_metric_role_ledger.csv
  config/validation/qdesn_dynamic_fitforecast_v2_500obs_forecast_gap_adaptive_mcmc_v1_history_signature_ledger.csv
  config/validation/qdesn_dynamic_fitforecast_v2_500obs_forecast_gap_adaptive_mcmc_v1_evidence_source_manifest.csv
  config/validation/qdesn_dynamic_fitforecast_v2_500obs_forecast_gap_adaptive_mcmc_v1_parent_controls.csv
  config/validation/qdesn_dynamic_fitforecast_v2_500obs_forecast_gap_adaptive_mcmc_v1_candidate_profiles.csv
  config/validation/qdesn_dynamic_fitforecast_v2_500obs_forecast_gap_adaptive_mcmc_v1_source_seed_contract.csv
  config/validation/qdesn_dynamic_fitforecast_v2_500obs_forecast_gap_adaptive_mcmc_v1_frozen_parent_requests
  validation/fitforecast_v2/R/qdesn_forecast_gap_adaptive_mcmc_v1.R
  validation/fitforecast_v2/scripts/run_qdesn_forecast_gap_adaptive_mcmc_v1_chain.R
  validation/fitforecast_v2/scripts/advance_qdesn_forecast_gap_adaptive_mcmc_v1.R
  validation/fitforecast_v2/scripts/materialize_qdesn_forecast_gap_adaptive_mcmc_v1_confirmation.R
  validation/fitforecast_v2/scripts/closeout_qdesn_forecast_gap_adaptive_mcmc_v1_confirmation.R
)
git diff --quiet "$PARENT_COMMIT" HEAD -- "${IMMUTABLE_SCIENTIFIC_PATHS[@]}" || {
  echo "Scientific configuration or estimator code changed after the parent campaign." >&2
  git diff --name-only "$PARENT_COMMIT" HEAD -- "${IMMUTABLE_SCIENTIFIC_PATHS[@]}" >&2
  exit 3
}

mkdir -p "$STATE_ROOT"
[[ -s "$HEARTBEAT_CSV" ]] || {
  printf 'timestamp,stage,load1,available_memory_gb,available_disk_gb,idle_cpu_count\n' \
    > "$HEARTBEAT_CSV"
}
record_status() {
  printf '%s,%s,%s,%s\n' "$(date --iso-8601=seconds)" "$1" "$2" "${3//,/;}" \
    >> "$STATUS_CSV"
}
set_stage() { printf '%s\n' "$1" > "$CURRENT_STAGE"; }
resource_values() {
  local load memory disk cpu_count idle
  load="$(awk '{print $1}' /proc/loadavg)"
  memory="$(awk '/MemAvailable:/ {print $2/1048576}' /proc/meminfo)"
  disk="$(df -Pk "$REPO_ROOT" | awk 'NR == 2 {print $4/1048576}')"
  cpu_count="$(getconf _NPROCESSORS_ONLN)"
  idle="$(ps -eLo psr=,pcpu= 2>/dev/null | awk -v n="$cpu_count" \
    -v limit="$MAX_IDLE_CPU_PERCENT" '
      {used[$1+0]+=$2+0}
      END {for (i=0; i<n; i++) if ((used[i]+0) <= limit) count++; print count+0}
    ')"
  printf '%.2f %.1f %.1f %d\n' "$load" "$memory" "$disk" "$idle"
}
write_heartbeat() {
  local values stage
  values="$(resource_values)"
  stage="$(cat "$CURRENT_STAGE" 2>/dev/null || printf initializing)"
  printf '%s,%s,%s\n' "$(date --iso-8601=seconds)" "$stage" "${values// /,}" \
    >> "$HEARTBEAT_CSV"
}
heartbeat_loop() { while true; do write_heartbeat; sleep "$HEARTBEAT_SECONDS"; done; }
wait_for_resources() {
  while true; do
    local values load memory disk idle
    values="$(resource_values)"
    read -r load memory disk idle <<< "$values"
    write_heartbeat
    if awk -v l="$load" -v m="$memory" -v d="$disk" -v i="$idle" \
      -v ml="$MAX_LOAD" -v mm="$MIN_MEMORY_GB" -v md="$MIN_DISK_GB" \
      -v w="$WORKERS" \
      'BEGIN {exit !((l <= ml) && (m >= mm) && (d >= md) && (i >= w))}'; then
      record_status confirmation_resume_resource_gate PASS \
        "load=${load};memory_gb=${memory};disk_gb=${disk};idle_cpus=${idle}"
      return 0
    fi
    record_status confirmation_resume_resource_gate WAIT \
      "load=${load};memory_gb=${memory};disk_gb=${disk};idle_cpus=${idle};workers=${WORKERS}"
    sleep "$POLL_SECONDS"
  done
}
select_idle_cpus() {
  local cpu_count
  cpu_count="$(getconf _NPROCESSORS_ONLN)"
  ps -eLo psr=,pcpu= 2>/dev/null | awk -v n="$cpu_count" \
    '{used[$1+0]+=$2+0} END {for (i=0; i<n; i++) printf "%d %.6f\n", i, used[i]+0}' |
    sort -k2,2n -k1,1n |
    awk -v workers="$WORKERS" -v limit="$MAX_IDLE_CPU_PERCENT" \
      '$2 <= limit && selected < workers {print $1; selected++}' |
    paste -sd, -
}

exec 9>"$LOCK_FILE"
flock -n 9 || { echo "Another forecast-gap adaptive pipeline is active." >&2; exit 3; }
export OMP_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 MKL_NUM_THREADS=1
export VECLIB_MAXIMUM_THREADS=1 NUMEXPR_NUM_THREADS=1 RCPP_PARALLEL_NUM_THREADS=1
export QDESN_FGAV1_MATERIALIZATION_ROOT="$MATERIALIZATION_ROOT"
heartbeat_loop &
HEARTBEAT_PID="$!"
cleanup() {
  if kill -0 "$HEARTBEAT_PID" 2>/dev/null; then
    kill "$HEARTBEAT_PID" 2>/dev/null || true
    wait "$HEARTBEAT_PID" 2>/dev/null || true
  fi
}
on_error() {
  local rc="$?" stage
  set +e
  stage="$(cat "$CURRENT_STAGE" 2>/dev/null || printf confirmation_resume_unknown)"
  record_status "$stage" RECOVERY_FAILED "pipeline_exit=${rc};attempt=${ATTEMPT_ID}"
  exit "$rc"
}
trap cleanup EXIT INT TERM
trap on_error ERR

RECOVERY_COMMIT="$(git rev-parse HEAD)"
set_stage confirmation_resume_preflight
record_status confirmation_resume_preflight STARTED \
  "attempt=${ATTEMPT_ID};parent_commit=${PARENT_COMMIT};recovery_commit=${RECOVERY_COMMIT}"

for spec in \
  "smoke:$MATERIALIZATION_ROOT/smoke_plan.csv" \
  "calibration:$MATERIALIZATION_ROOT/calibration_plan.csv" \
  "discovery:$MATERIALIZATION_ROOT/discovery_plan.csv" \
  "replication:$ADAPTIVE_ROOT/replication_plan.csv" \
  "sealed:$ADAPTIVE_ROOT/sealed_plan.csv"; do
  stage_name="${spec%%:*}"
  stage_plan="${spec#*:}"
  "$R_SCRIPT" "$VERIFY" --repo-root "$REPO_ROOT" \
    --materialization-root "$MATERIALIZATION_ROOT" --stage "$stage_name" \
    --plan "$stage_plan" --run-tag "$RUN_TAG" \
    --output "$STATE_ROOT/${stage_name}_confirmation_resume_${ATTEMPT_ID}.json" \
    > "$STATE_ROOT/${stage_name}_confirmation_resume_${ATTEMPT_ID}.log" 2>&1
done
"$R_SCRIPT" -e '
  paths <- commandArgs(TRUE)
  x <- lapply(paths, jsonlite::read_json, simplifyVector = TRUE)
  expected <- c(2L, 8L, 184L, 64L, 96L)
  observed <- vapply(x, function(z) as.integer(z$runtime_rows), integer(1L))
  decisions <- vapply(x, function(z) identical(z$decision, "PASS"), logical(1L))
  stopifnot(identical(observed, expected), all(decisions), sum(observed) == 354L)
' \
  "$STATE_ROOT/smoke_confirmation_resume_${ATTEMPT_ID}.json" \
  "$STATE_ROOT/calibration_confirmation_resume_${ATTEMPT_ID}.json" \
  "$STATE_ROOT/discovery_confirmation_resume_${ATTEMPT_ID}.json" \
  "$STATE_ROOT/replication_confirmation_resume_${ATTEMPT_ID}.json" \
  "$STATE_ROOT/sealed_confirmation_resume_${ATTEMPT_ID}.json" \
  > "$STATE_ROOT/prior_354_root_confirmation_resume_gate_${ATTEMPT_ID}.log" 2>&1

"$R_SCRIPT" "$CONFIRM_VERIFY" --repo-root "$REPO_ROOT" --state-root "$STATE_ROOT" \
  --run-tag "$RUN_TAG" \
  --output "$STATE_ROOT/confirmation_resume_preflight_verification_${ATTEMPT_ID}.json" \
  > "$STATE_ROOT/confirmation_resume_preflight_verification_${ATTEMPT_ID}.log" 2>&1

CONFIG_LIST="$STATE_ROOT/confirmation_configs_resume_${ATTEMPT_ID}.txt"
"$R_SCRIPT" -e '
  x <- read.csv(commandArgs(TRUE)[1L], check.names = FALSE)
  stopifnot(nrow(x) > 0L, !anyDuplicated(x$job_id), all(file.exists(x$config_path)))
  writeLines(x$config_path)
' "$PLAN" > "$CONFIG_LIST"
JOBS="$(wc -l < "$CONFIG_LIST")"
MANIFEST_JOBS="$("$R_SCRIPT" -e '
  x <- jsonlite::read_json(commandArgs(TRUE)[1L], simplifyVector = TRUE)
  cat(as.integer(x$confirmation_jobs))
' "$MANIFEST")"
[[ "$JOBS" -eq "$MANIFEST_JOBS" && "$JOBS" -eq "$EXPECTED_CONFIRMATION_JOBS" ]] || {
  echo "Confirmation cardinality mismatch: plan=$JOBS manifest=$MANIFEST_JOBS expected=$EXPECTED_CONFIRMATION_JOBS" >&2
  exit 3
}

PROVENANCE="$STATE_ROOT/confirmation_resume_provenance_${ATTEMPT_ID}.json"
"$R_SCRIPT" -e '
  a <- commandArgs(TRUE)
  jsonlite::write_json(list(
    schema_version = "qdesn_forecast_gap_adaptive_mcmc_v1_confirmation_resume_v1",
    generated_at = as.character(Sys.time()), run_id = a[[1L]], run_tag = a[[2L]],
    parent_scientific_commit = a[[3L]], recovery_commit = a[[4L]],
    preserved_successful_jobs = 354L, confirmation_jobs = as.integer(a[[5L]]),
    confirmation_plan_path = normalizePath(a[[6L]], winslash = "/"),
    confirmation_plan_sha256 = digest::digest(file = a[[6L]], algo = "sha256"),
    rematerialized = FALSE, earlier_stages_rerun = FALSE,
    same_run_tag_used_for_job_continuity = TRUE
  ), a[[7L]], auto_unbox = TRUE, pretty = TRUE)
' "$RUN_ID" "$RUN_TAG" "$PARENT_COMMIT" "$RECOVERY_COMMIT" "$JOBS" "$PLAN" "$PROVENANCE"
record_status confirmation_resume_preflight COMPLETED \
  "354 prior roots reverified;${JOBS} immutable confirmation jobs;manifest and source hashes pass"

set_stage confirmation_resume_tests
"$R_SCRIPT" -e '
  pkgload::load_all(".", quiet = TRUE)
  stopifnot(as.character(packageVersion("exdqlm")) == "1.0.0")
  testthat::test_file(
    "validation/fitforecast_v2/tests/testthat/test-qdesn-forecast-gap-adaptive-mcmc-v1.R",
    reporter = "summary", stop_on_failure = TRUE, stop_on_warning = TRUE
  )
' > "$STATE_ROOT/confirmation_resume_tests_${ATTEMPT_ID}.log" 2>&1
record_status confirmation_resume_tests COMPLETED \
  "portable row count;lineage;confirmation-only recovery contracts pass"

if [[ "$PREFLIGHT_ONLY" == "true" ]]; then
  set_stage confirmation_resume_ready
  record_status confirmation_resume_ready PREFLIGHT_COMPLETED \
    "354 prior roots and ${JOBS} confirmation jobs verified;no workers launched"
  printf 'Forecast-gap confirmation recovery preflight passed: %s\n' "$RUN_TAG"
  exit 0
fi

set_stage confirmation_resume_resource_gate
wait_for_resources
CPU_SET="${CPU_SET:-$(select_idle_cpus)}"
CPU_COUNT="$(tr ',' '\n' <<< "$CPU_SET" | sed '/^$/d' | wc -l)"
[[ "$CPU_COUNT" -eq "$WORKERS" ]] || {
  record_status confirmation_resume_cpu_selection FAILED \
    "expected=${WORKERS};found=${CPU_COUNT};cpus=${CPU_SET}"
  exit 3
}
record_status confirmation_resume_cpu_selection COMPLETED \
  "workers=${WORKERS};threads=1;cpus=${CPU_SET}"

PARALLELISM="$WORKERS"
[[ "$JOBS" -lt "$PARALLELISM" ]] && PARALLELISM="$JOBS"
set_stage confirmation
record_status confirmation RECOVERY_STARTED \
  "jobs=${JOBS};parallelism=${PARALLELISM};5000+20000;same_run_tag;attempt=${ATTEMPT_ID}"
WORKER_LOG="$STATE_ROOT/confirmation_workers_resume_${ATTEMPT_ID}.log"
set +e
taskset -c "$CPU_SET" xargs -r -n 1 -P "$PARALLELISM" \
  "$R_SCRIPT" "$WORKER" --repo-root "$REPO_ROOT" --run-tag "$RUN_TAG" --config \
  < "$CONFIG_LIST" > "$WORKER_LOG" 2>&1
RC="$?"
set -e
printf '%s\n' "$RC" > "$STATE_ROOT/confirmation_worker_exit_code.txt"
"$R_SCRIPT" "$HEALTH" --repo-root "$REPO_ROOT" --run-tag "$RUN_TAG" \
  --plan "$PLAN" --output "$STATE_ROOT/confirmation_health.csv" \
  > "$STATE_ROOT/confirmation_health.log" 2>&1 || true
if [[ "$RC" -ne 0 ]]; then
  record_status confirmation RECOVERY_FAILED \
    "worker_exit=${RC};same_run_tag_resumes_matching_successes"
  exit "$RC"
fi

"$R_SCRIPT" "$CONFIRM_VERIFY" --repo-root "$REPO_ROOT" --state-root "$STATE_ROOT" \
  --run-tag "$RUN_TAG" --runtime true \
  --output "$STATE_ROOT/confirmation_verification.json" \
  > "$STATE_ROOT/confirmation_verification.log" 2>&1
record_status confirmation RECOVERY_COMPLETED \
  "${JOBS}/${JOBS} finite;storage-light;config-matched"

set_stage confirmation_closeout
"$R_SCRIPT" "$CLOSEOUT" --repo-root "$REPO_ROOT" --state-root "$STATE_ROOT" \
  --run-tag "$RUN_TAG" > "$STATE_ROOT/confirmation_closeout.log" 2>&1
"$R_SCRIPT" -e '
  a <- commandArgs(TRUE)
  close <- jsonlite::read_json(a[[1L]], simplifyVector = TRUE)
  verify <- jsonlite::read_json(a[[2L]], simplifyVector = TRUE)
  binary_count <- length(list.files(
    a[[3L]], pattern = "[.](rds|rda|RData)$", recursive = TRUE,
    full.names = TRUE, ignore.case = TRUE
  ))
  jsonlite::write_json(list(
    schema_version = "qdesn_forecast_gap_adaptive_mcmc_v1_recovery_closeout_v1",
    generated_at = as.character(Sys.time()), run_tag = a[[4L]],
    parent_scientific_commit = a[[5L]], recovery_commit = a[[6L]],
    prior_jobs_preserved = 354L, confirmation_jobs_completed = 24L,
    verification_decision = verify$decision, scientific_decision = close$decision,
    promoted_metrics = as.integer(close$promoted_metrics),
    diagnostics_used_as_promotion_veto = FALSE,
    fitted_model_binary_payloads = binary_count,
    integration_status = "READY_FOR_INTEGRATION"
  ), a[[7L]], auto_unbox = TRUE, pretty = TRUE)
' "$CONFIRMATION_ROOT/confirmation_closeout.json" \
  "$STATE_ROOT/confirmation_verification.json" \
  "$REPO_ROOT/results/qdesn_mcmc_validation/qdesn_dynamic_fitforecast_v2_500obs_forecast_gap_adaptive_mcmc_v1/$RUN_TAG" \
  "$RUN_TAG" "$PARENT_COMMIT" "$RECOVERY_COMMIT" \
  "$STATE_ROOT/confirmation_resume_closeout_${ATTEMPT_ID}.json"
record_status confirmation_closeout RECOVERY_COMPLETED \
  "metric-specific strict-mean promotion ledger;diagnostics descriptive;article unchanged"
set_stage complete
write_heartbeat
record_status complete RECOVERY_COMPLETED \
  "378/378 scientific jobs closed;integration handoff ready;article update manual"
printf 'Forecast-gap adaptive MCMC v1 confirmation recovery complete: %s\n' "$RUN_TAG"

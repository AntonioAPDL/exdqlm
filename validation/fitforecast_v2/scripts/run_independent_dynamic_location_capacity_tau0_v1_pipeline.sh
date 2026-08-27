#!/usr/bin/env bash
set -euo pipefail

REPO="${1:-$(git rev-parse --show-toplevel)}"
RUN_ID="${2:-independent_dynamic_location_capacity_tau0_v1_$(date +%Y%m%d_%H%M%S)}"
RUN_TAG="${3:-independent-dynamic-location-capacity-tau0-v1-$(date +%Y%m%d_%H%M%S)__git-$(git -C "$REPO" rev-parse --short HEAD)}"
R="${R_SCRIPT:-/data/jaguir26/local/opt/R/4.6.0/bin/Rscript}"
WORKERS="${WORKERS:-20}"
POLL_SECONDS="${POLL_SECONDS:-300}"
MIN_MEMORY_GB="${MIN_MEMORY_GB:-64}"
MIN_DISK_GB="${MIN_DISK_GB:-80}"
MAX_CORE_LOAD="${MAX_CORE_LOAD:-20}"
EXPECTED_BRANCH="validation/independent-dynamic-location-capacity-tau0-v1-1.0.0"

cd "$REPO"
test "$(git branch --show-current)" = "$EXPECTED_BRANCH"
test -z "$(git status --porcelain)"
test "$(git rev-list --left-right --count '@{upstream}...HEAD')" = $'0\t0'

STATE="$REPO/reports/shared_fitforecast_v2_orchestration/$RUN_ID"
MAT="$STATE/materialization"
mkdir -p "$STATE" "$MAT"
exec 9>"$REPO/reports/shared_fitforecast_v2_orchestration/independent_dynamic_location_capacity_tau0_v1.lock"
flock -n 9
STATUS="$STATE/stage_status.csv"
HEARTBEAT="$STATE/heartbeat.csv"
printf 'timestamp,stage,status,detail\n' > "$STATUS"
printf 'timestamp,stage,load1,memory_gb,disk_gb,idle_cpus\n' > "$HEARTBEAT"

export OMP_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 MKL_NUM_THREADS=1
export VECLIB_MAXIMUM_THREADS=1 NUMEXPR_NUM_THREADS=1
export RCPP_PARALLEL_NUM_THREADS=1

record() {
  local stage="$1" status="$2" detail="${3:-}"
  printf '%s,%s,%s,%s\n' "$(date --iso-8601=seconds)" "$stage" "$status" \
    "${detail//,/;}" >> "$STATUS"
  printf '%s\n' "$stage" > "$STATE/current_stage.txt"
}

available_cpus() {
  local n
  n="$(getconf _NPROCESSORS_ONLN)"
  ps -eLo psr=,pcpu= | awk -v n="$n" -v cap="$MAX_CORE_LOAD" '
    { usage[$1 + 0] += $2 }
    END {
      for (i = 0; i < n; i++) if ((usage[i] + 0) <= cap) print i
    }
  '
}

resource_snapshot() {
  local idle
  idle="$(available_cpus | wc -l)"
  printf '%s %.1f %.1f %s' \
    "$(awk '{print $1}' /proc/loadavg)" \
    "$(awk '/MemAvailable/{print $2/1048576}' /proc/meminfo)" \
    "$(df -Pk "$REPO" | awk 'NR==2{print $4/1048576}')" \
    "$idle"
}

wait_for_resources() {
  local required="$1" load mem disk idle
  while true; do
    read -r load mem disk idle <<< "$(resource_snapshot)"
    printf '%s,%s,%s,%s,%s,%s\n' "$(date --iso-8601=seconds)" resource_gate \
      "$load" "$mem" "$disk" "$idle" >> "$HEARTBEAT"
    if awk -v i="$idle" -v m="$mem" -v d="$disk" -v ri="$required" \
      -v rm="$MIN_MEMORY_GB" -v rd="$MIN_DISK_GB" \
      'BEGIN{exit !((i>=ri)&&(m>=rm)&&(d>=rd))}'; then
      return 0
    fi
    record resource_gate WAIT \
      "required_idle=$required;idle=$idle;memory_gb=$mem;disk_gb=$disk"
    sleep "$POLL_SECONDS"
  done
}

run_stage() {
  local stage="$1" plan="$2" requested_workers="$3"
  local jobs workers assignment_tsv assignment_csv
  jobs="$(($(wc -l < "$plan") - 1))"
  workers="$requested_workers"
  if ((workers > jobs)); then workers="$jobs"; fi
  wait_for_resources "$workers"
  mapfile -t cpu_ids < <(available_cpus | head -n "$workers")
  if ((${#cpu_ids[@]} != workers)); then
    record "$stage" FAIL "could_not_reserve_$workers_cpus"
    return 1
  fi
  assignment_tsv="$STATE/${stage}_assignments.tsv"
  assignment_csv="$STATE/${stage}_cpu_assignment.csv"
  "$R" -e 'x<-read.csv(commandArgs(TRUE)[1],check.names=FALSE);write.table(x[,c("job_id","config_path")],row.names=FALSE,col.names=FALSE,quote=FALSE,sep="\t")' \
    "$plan" > "$assignment_tsv"
  printf 'job_id,config_path,cpu_id,worker_id\n' > "$assignment_csv"
  for ((worker = 0; worker < workers; worker++)); do
    : > "$STATE/${stage}_worker_${worker}.tsv"
  done
  local index=0 job_id config_path worker cpu_id
  while IFS=$'\t' read -r job_id config_path; do
    worker=$((index % workers))
    cpu_id="${cpu_ids[$worker]}"
    printf '%s\t%s\n' "$job_id" "$config_path" >> \
      "$STATE/${stage}_worker_${worker}.tsv"
    printf '%s,%s,%s,%s\n' "$job_id" "$config_path" "$cpu_id" "$worker" >> \
      "$assignment_csv"
    index=$((index + 1))
  done < "$assignment_tsv"
  record "$stage" STARTED \
    "jobs=$jobs;workers=$workers;cpus=$(IFS=:; echo "${cpu_ids[*]}")"
  pids=()
  for ((worker = 0; worker < workers; worker++)); do
    cpu_id="${cpu_ids[$worker]}"
    (
      worker_status=0
      while IFS=$'\t' read -r job_id config_path; do
        taskset -c "$cpu_id" "$R" \
          validation/fitforecast_v2/scripts/run_independent_dynamic_location_capacity_tau0_v1_chain.R \
          --repo-root "$REPO" --run-tag "$RUN_TAG" --config "$config_path" \
          >> "$STATE/${stage}_worker_${worker}.log" 2>&1 || worker_status=1
      done < "$STATE/${stage}_worker_${worker}.tsv"
      exit "$worker_status"
    ) &
    pids+=("$!")
  done
  worker_failure=0
  for pid in "${pids[@]}"; do
    wait "$pid" || worker_failure=1
  done
  verification_status=0
  "$R" validation/fitforecast_v2/scripts/verify_independent_dynamic_location_capacity_tau0_v1.R \
    --repo-root "$REPO" --materialization-root "$MAT" --stage "$stage" \
    --plan "$plan" --run-tag "$RUN_TAG" \
    --output "$STATE/${stage}_verification.json" \
    > "$STATE/${stage}_verification.log" 2>&1 || verification_status=1
  if ((worker_failure != 0 || verification_status != 0)); then
    record "$stage" FAIL \
      "worker_failure=$worker_failure;verification_failure=$verification_status"
    return 1
  fi
  record "$stage" COMPLETED "jobs=$jobs"
}

cat > "$STATE/run_tags.env" <<EOF
RUN_ID=$RUN_ID
RUN_TAG=$RUN_TAG
GIT_COMMIT=$(git rev-parse HEAD)
GIT_BRANCH=$(git branch --show-current)
WORKERS=$WORKERS
THREADS_PER_JOB=1
SCIENTIFIC_LANE=independent_single_quantile_qdesn_dqlm_validation
ARTICLE_UPDATE_AUTOMATIC=FALSE
EOF

record materialize STARTED frozen_v9_v10_authorities
"$R" validation/fitforecast_v2/scripts/materialize_independent_dynamic_location_capacity_tau0_v1.R \
  --repo-root "$REPO" --output-root "$MAT" > "$STATE/materialize.log" 2>&1
"$R" validation/fitforecast_v2/scripts/verify_independent_dynamic_location_capacity_tau0_v1.R \
  --repo-root "$REPO" --materialization-root "$MAT" --stage static \
  --output "$STATE/static_verification.json" > "$STATE/static_verification.log" 2>&1
record materialize COMPLETED "smoke=2;screen=64"

run_stage smoke "$MAT/smoke_plan.csv" 2
run_stage screen "$MAT/screen_plan.csv" "$WORKERS"
record closeout STARTED discovery_metric_specific
"$R" validation/fitforecast_v2/scripts/closeout_independent_dynamic_location_capacity_tau0_v1.R \
  --repo-root "$REPO" --run-tag "$RUN_TAG" --materialization-root "$MAT" \
  --output-root "$STATE/closeout" > "$STATE/closeout.log" 2>&1
record closeout COMPLETED "promotion_requires_matched_replication_and_confirmation"
record pipeline COMPLETED "article_update_not_authorized"

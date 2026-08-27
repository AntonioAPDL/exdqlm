#!/usr/bin/env bash
set -euo pipefail

REPO="${1:-$(git rev-parse --show-toplevel)}"
RUN_ID="${2:?run id required}"
RUN_TAG="${3:?run tag required}"
R="${R_SCRIPT:-/data/jaguir26/local/opt/R/4.6.0/bin/Rscript}"
EXPECTED_BRANCH="validation/independent-location-orthogonalized-tau0-v2-1.0.0"

cd "$REPO"
test "$(git branch --show-current)" = "$EXPECTED_BRANCH"
test -z "$(git status --porcelain)"
test "$(git rev-list --left-right --count '@{upstream}...HEAD')" = $'0\t0'

STATE="$REPO/reports/shared_fitforecast_v2_orchestration/$RUN_ID"
MAT="$STATE/materialization"
CLOSEOUT="$STATE/closeout"
mkdir -p "$STATE" "$MAT" "$CLOSEOUT"
exec 9>"$REPO/reports/shared_fitforecast_v2_orchestration/independent_location_orthogonalized_tau0_v2_interval_replay.lock"
flock -n 9

export OMP_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 MKL_NUM_THREADS=1
export VECLIB_MAXIMUM_THREADS=1 NUMEXPR_NUM_THREADS=1
export RCPP_PARALLEL_NUM_THREADS=1

printf 'timestamp,stage,status,detail\n' > "$STATE/stage_status.csv"
record() {
  printf '%s,%s,%s,%s\n' "$(date --iso-8601=seconds)" "$1" "$2" "${3:-}" \
    >> "$STATE/stage_status.csv"
}

record materialize STARTED
"$R" validation/fitforecast_v2/scripts/materialize_independent_location_orthogonalized_tau0_v2_interval_replay.R \
  --repo-root "$REPO" --output-root "$MAT" --run-id "$RUN_ID" \
  --run-tag "$RUN_TAG" > "$STATE/materialize.log" 2>&1
record materialize COMPLETED jobs=3

mapfile -t CPU_IDS < <(
  n="$(getconf _NPROCESSORS_ONLN)"
  ps -eLo psr=,pcpu= | awk -v n="$n" '
    { usage[$1 + 0] += $2 }
    END { for (i = 0; i < n; i++) if ((usage[i] + 0) <= 20) print i }
  ' | head -n 3
)
if ((${#CPU_IDS[@]} != 3)); then
  record resource_gate FAIL fewer_than_3_idle_cores
  exit 1
fi
MEM_GB="$(awk '/MemAvailable/{print $2/1048576}' /proc/meminfo)"
DISK_GB="$(df -Pk "$REPO" | awk 'NR==2{print $4/1048576}')"
if ! awk -v m="$MEM_GB" -v d="$DISK_GB" 'BEGIN{exit !((m>=48)&&(d>=60))}'; then
  record resource_gate FAIL "memory_gb=$MEM_GB;disk_gb=$DISK_GB"
  exit 1
fi
printf 'job_id,config_path,cpu_id\n' > "$STATE/cpu_assignment.csv"

"$R" -e 'x<-read.csv(commandArgs(TRUE)[1],check.names=FALSE);write.table(x[,c("job_id","config_path")],row.names=FALSE,col.names=FALSE,quote=FALSE,sep="\t")' \
  "$MAT/replay_plan.csv" > "$STATE/assignments.tsv"

record interval_replay STARTED "jobs=3;draws_per_chain=1000"
pids=()
i=0
while IFS=$'\t' read -r job_id config_path; do
  cpu="${CPU_IDS[$i]}"
  printf '%s,%s,%s\n' "$job_id" "$config_path" "$cpu" \
    >> "$STATE/cpu_assignment.csv"
  taskset -c "$cpu" "$R" \
    validation/fitforecast_v2/scripts/run_independent_location_orthogonalized_tau0_v2_chain.R \
    --repo-root "$REPO" --run-tag "$RUN_TAG" --config "$config_path" \
    > "$STATE/chain_$((i + 1)).log" 2>&1 &
  pids+=("$!")
  i=$((i + 1))
done < "$STATE/assignments.tsv"

failure=0
for pid in "${pids[@]}"; do wait "$pid" || failure=1; done
if ((failure)); then
  record interval_replay FAIL worker_failure
  exit 1
fi
record interval_replay COMPLETED jobs=3

record verify STARTED
"$R" validation/fitforecast_v2/scripts/verify_independent_location_orthogonalized_tau0_v2_interval_replay.R \
  --repo-root "$REPO" --materialization-root "$MAT" \
  --closeout-root "$CLOSEOUT" --run-tag "$RUN_TAG" \
  > "$STATE/verify.log" 2>&1
record verify COMPLETED precision_gate_pass
record pipeline COMPLETED promotion_tooling_may_proceed

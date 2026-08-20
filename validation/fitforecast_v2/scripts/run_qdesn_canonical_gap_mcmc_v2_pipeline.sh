#!/usr/bin/env bash
set -euo pipefail
REPO="${1:-$(git rev-parse --show-toplevel)}"; RUN_ID="${2:-qdesn_canonical_gap_v2_$(date +%Y%m%d_%H%M%S)}"
RUN_TAG="${3:-qdesn-canonical-gap-v2-$(date +%Y%m%d_%H%M%S)__git-$(git -C "$REPO" rev-parse --short HEAD)}"
R="${R_SCRIPT:-/data/jaguir26/local/opt/R/4.6.0/bin/Rscript}"; WORKERS="${WORKERS:-20}"; MIN_IDLE="${MIN_IDLE_CPUS:-$WORKERS}"
POLL="${POLL_SECONDS:-300}"; MIN_MEM="${MIN_MEMORY_GB:-64}"; MIN_DISK="${MIN_DISK_GB:-80}"
cd "$REPO"; test "$(git branch --show-current)" = "validation/qdesn-canonical-gap-mcmc-v2-1.0.0"
test -z "$(git status --porcelain)"; test "$(git rev-list --left-right --count '@{upstream}...HEAD')" = $'0\t0'
STATE="$REPO/reports/shared_fitforecast_v2_orchestration/$RUN_ID"; MAT="$STATE/materialization"; ADAPT="$MAT/adaptive"
mkdir -p "$STATE" "$MAT" "$ADAPT"; exec 9>"$REPO/reports/shared_fitforecast_v2_orchestration/qdesn_canonical_gap_mcmc_v2.lock"; flock -n 9
STATUS="$STATE/stage_status.csv"; HEART="$STATE/heartbeat.csv"; printf 'timestamp,stage,status,detail\n' > "$STATUS"; printf 'timestamp,stage,load1,memory_gb,disk_gb,idle_cpus\n' > "$HEART"
export OMP_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 MKL_NUM_THREADS=1 VECLIB_MAXIMUM_THREADS=1 NUMEXPR_NUM_THREADS=1 RCPP_PARALLEL_NUM_THREADS=1
record(){ printf '%s,%s,%s,%s\n' "$(date --iso-8601=seconds)" "$1" "$2" "${3//,/;}" >> "$STATUS"; printf '%s\n' "$1" > "$STATE/current_stage.txt"; }
resources(){ local n; n=$(getconf _NPROCESSORS_ONLN); local idle; idle=$(ps -eLo psr=,pcpu= | awk -v n="$n" '{u[$1+0]+=$2}END{for(i=0;i<n;i++)if((u[i]+0)<=20)c++;print c+0}'); printf '%s %.1f %.1f %s' "$(awk '{print $1}' /proc/loadavg)" "$(awk '/MemAvailable/{print $2/1048576}' /proc/meminfo)" "$(df -Pk "$REPO"|awk 'NR==2{print $4/1048576}')" "$idle"; }
gate(){ while true; do read -r load mem disk idle <<< "$(resources)"; printf '%s,%s,%s,%s,%s,%s\n' "$(date --iso-8601=seconds)" resource_gate "$load" "$mem" "$disk" "$idle" >> "$HEART"; if awk -v i="$idle" -v m="$mem" -v d="$disk" -v mi="$MIN_IDLE" -v mm="$MIN_MEM" -v md="$MIN_DISK" 'BEGIN{exit !((i>=mi)&&(m>=mm)&&(d>=md))}';then return;fi;record resource_gate WAIT "idle=$idle;memory=$mem;disk=$disk";sleep "$POLL";done; }
run_stage(){ local stage="$1" plan="$2"; gate; local jobs parallel; jobs=$(($(wc -l < "$plan")-1)); parallel=$WORKERS;((parallel>jobs))&&parallel=$jobs;record "$stage" STARTED "jobs=$jobs;parallel=$parallel"; "$R" -e 'x<-read.csv(commandArgs(TRUE)[1],check.names=FALSE);writeLines(x$config_path)' "$plan" | xargs -r -n1 -P "$parallel" "$R" validation/fitforecast_v2/scripts/run_qdesn_canonical_gap_mcmc_v2_chain.R --repo-root "$REPO" --run-tag "$RUN_TAG" --config > "$STATE/${stage}_workers.log" 2>&1; "$R" validation/fitforecast_v2/scripts/verify_qdesn_canonical_gap_mcmc_v2.R --repo-root "$REPO" --materialization-root "$MAT" --stage "$stage" --plan "$plan" --run-tag "$RUN_TAG" --output "$STATE/${stage}_verification.json" > "$STATE/${stage}_verification.log" 2>&1;record "$stage" COMPLETED "jobs=$jobs"; }
cat > "$STATE/run_tags.env" <<EOF
RUN_ID=$RUN_ID
RUN_TAG=$RUN_TAG
GIT_COMMIT=$(git rev-parse HEAD)
WORKERS=$WORKERS
THREADS_PER_JOB=1
CANONICAL_SCREEN=TRUE
ARTICLE_UPDATE_AUTOMATIC=FALSE
EOF
record materialize STARTED canonical_article_sources
"$R" validation/fitforecast_v2/scripts/materialize_qdesn_canonical_gap_mcmc_v2.R --output-root "$MAT" > "$STATE/materialize.log" 2>&1
"$R" validation/fitforecast_v2/scripts/verify_qdesn_canonical_gap_mcmc_v2.R --materialization-root "$MAT" --stage static --output "$STATE/static_verification.json" > "$STATE/static_verification.log" 2>&1
record materialize COMPLETED "smoke=2;calibration=4;screen=128"
run_stage smoke "$MAT/smoke_plan.csv"; run_stage calibration "$MAT/calibration_plan.csv"; run_stage screen "$MAT/screen_plan.csv"
"$R" validation/fitforecast_v2/scripts/advance_qdesn_canonical_gap_mcmc_v2.R --from screen --run-tag "$RUN_TAG" --materialization-root "$MAT" --output-root "$ADAPT" > "$STATE/advance_screen.log" 2>&1
run_stage refine "$MAT/refine_plan.csv"
"$R" validation/fitforecast_v2/scripts/advance_qdesn_canonical_gap_mcmc_v2.R --from refine --run-tag "$RUN_TAG" --materialization-root "$MAT" --output-root "$ADAPT" > "$STATE/advance_refine.log" 2>&1
if [[ $(wc -l < "$MAT/confirmation_plan.csv") -gt 1 ]]; then run_stage confirmation "$MAT/confirmation_plan.csv"; "$R" validation/fitforecast_v2/scripts/advance_qdesn_canonical_gap_mcmc_v2.R --from confirmation --run-tag "$RUN_TAG" --materialization-root "$MAT" --output-root "$ADAPT" > "$STATE/closeout.log" 2>&1; fi
record pipeline COMPLETED "article_promotion_requires_separate_audit"

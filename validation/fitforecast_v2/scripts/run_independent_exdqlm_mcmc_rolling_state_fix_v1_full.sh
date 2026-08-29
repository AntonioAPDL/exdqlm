#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HARNESS_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
REPO_ROOT="$(cd "${HARNESS_ROOT}/../.." && pwd)"
EXPECTED_BRANCH="validation/independent-exdqlm-mcmc-rolling-state-fix-v1-1.0.0"
EXPECTED_UPSTREAM="origin/${EXPECTED_BRANCH}"
SENTINEL_RUN_ID="independent_exdqlm_mcmc_rolling_state_fix_v1_sentinel_20260829_022824"
WORKERS="${WORKERS:-20}"
MIN_MEMORY_GB="${MIN_MEMORY_GB:-64}"
MIN_DISK_GB="${MIN_DISK_GB:-100}"
MAX_LOAD="${MAX_LOAD:-40}"
POLL_SECONDS="${POLL_SECONDS:-300}"
HEARTBEAT_SECONDS="${HEARTBEAT_SECONDS:-300}"
R_SCRIPT="${R_SCRIPT:-/data/jaguir26/local/opt/R/4.6.0/bin/Rscript}"

TASK_TRACKER="${REPO_ROOT}/validation/fitforecast_v2/local_trackers/independent_exdqlm_mcmc_rolling_state_fix_v1"
R_LIBRARY="${TASK_TRACKER}/Rlib"
TARBALL="${TASK_TRACKER}/package/exdqlm_1.1.1.tar.gz"
EXPECTED_TARBALL_SHA="3f3ed643ded7602fd62357d7f62024ca9071e0096214456650ed2de79722443e"
GIT_SHA="$(git -C "${REPO_ROOT}" rev-parse HEAD)"
GIT_SHORT="$(git -C "${REPO_ROOT}" rev-parse --short HEAD)"
RUN_ID="${RUN_ID:-independent_exdqlm_mcmc_rolling_state_fix_v1_full_$(date +%Y%m%d_%H%M%S)__git-${GIT_SHORT}}"
RUN_ROOT="${REPO_ROOT}/results/qdesn_mcmc_validation/qdesn_dqlm_500obs_independent_exdqlm_mcmc_rolling_state_fix_v1/${RUN_ID}"
STATE_ROOT="${REPO_ROOT}/reports/shared_fitforecast_v2_orchestration/${RUN_ID}"
PIPELINE_LOG="${STATE_ROOT}/pipeline.stdout.log"
LOCK_FILE="${REPO_ROOT}/reports/shared_fitforecast_v2_orchestration/independent_exdqlm_mcmc_rolling_state_fix_v1_full.lock"

export R_LIBS_USER="${R_LIBRARY}"
export OMP_NUM_THREADS=1
export OMP_THREAD_LIMIT=1
export OMP_DYNAMIC=FALSE
export OPENBLAS_NUM_THREADS=1
export MKL_NUM_THREADS=1
export BLIS_NUM_THREADS=1
export VECLIB_MAXIMUM_THREADS=1
export NUMEXPR_NUM_THREADS=1
export RCPP_PARALLEL_NUM_THREADS=1

branch="$(git -C "${REPO_ROOT}" branch --show-current)"
if [[ "${branch}" != "${EXPECTED_BRANCH}" ]]; then
  echo "Refusing unexpected branch: ${branch}" >&2
  exit 2
fi
if [[ -n "$(git -C "${REPO_ROOT}" status --short)" ]]; then
  echo "Refusing a dirty scientific worktree." >&2
  exit 2
fi
upstream="$(git -C "${REPO_ROOT}" rev-parse --abbrev-ref --symbolic-full-name '@{u}')"
if [[ "${upstream}" != "${EXPECTED_UPSTREAM}" ]]; then
  echo "Refusing unexpected upstream: ${upstream}" >&2
  exit 2
fi
read -r behind ahead < <(
  git -C "${REPO_ROOT}" rev-list --left-right --count '@{u}...HEAD'
)
if [[ "${behind}" -ne 0 || "${ahead}" -ne 0 ]]; then
  echo "Refusing an unsynchronized scientific branch: behind=${behind} ahead=${ahead}" >&2
  exit 2
fi
if [[ "${WORKERS}" -lt 1 || "${WORKERS}" -gt 20 ]]; then
  echo "WORKERS must be between 1 and 20." >&2
  exit 2
fi
if [[ ! -x "${R_SCRIPT}" || ! -f "${TARBALL}" || ! -d "${R_LIBRARY}/exdqlm" ]]; then
  echo "The task-local R/exdqlm 1.1.1 runtime is incomplete." >&2
  exit 2
fi
observed_sha="$(sha256sum "${TARBALL}" | awk '{print $1}')"
if [[ "${observed_sha}" != "${EXPECTED_TARBALL_SHA}" ]]; then
  echo "CRAN exdqlm 1.1.1 tarball hash mismatch." >&2
  exit 2
fi
if [[ -e "${RUN_ROOT}" || -e "${STATE_ROOT}" ]]; then
  echo "Refusing a pre-existing full-confirmation run ID: ${RUN_ID}" >&2
  exit 2
fi

mkdir -p "${STATE_ROOT}"
exec 9>"${LOCK_FILE}"
if ! flock -n 9; then
  echo "Another rolling-state full confirmation holds ${LOCK_FILE}." >&2
  exit 2
fi
exec > >(tee -a "${PIPELINE_LOG}") 2>&1

STATUS_CSV="${STATE_ROOT}/stage_status.csv"
HEARTBEAT_CSV="${STATE_ROOT}/heartbeat.csv"
CURRENT_STAGE="${STATE_ROOT}/current_stage.txt"
printf 'timestamp,stage,status,detail\n' > "${STATUS_CSV}"
printf 'timestamp,stage,load1,available_memory_gb,available_disk_gb\n' > "${HEARTBEAT_CSV}"
printf 'status=RUNNING run_id=%s started_at=%s\n' \
  "${RUN_ID}" "$(date --iso-8601=seconds)" > "${STATE_ROOT}/pipeline.status"

record_status() {
  local stage="$1" status="$2" detail="$3"
  printf '%s,%s,%s,%s\n' "$(date --iso-8601=seconds)" "${stage}" "${status}" \
    "${detail//,/;}" >> "${STATUS_CSV}"
}

resource_values() {
  local load1 memory_kb disk_kb
  load1="$(awk '{print $1}' /proc/loadavg)"
  memory_kb="$(awk '/MemAvailable:/ {print $2}' /proc/meminfo)"
  disk_kb="$(df -Pk "${REPO_ROOT}" | awk 'NR==2 {print $4}')"
  awk -v load="${load1}" -v memory="${memory_kb}" -v disk="${disk_kb}" \
    'BEGIN {printf "%.2f %.1f %.1f", load, memory/1048576, disk/1048576}'
}

write_heartbeat() {
  local values stage
  values="$(resource_values)"
  stage="$(cat "${CURRENT_STAGE}" 2>/dev/null || printf 'initializing')"
  printf '%s,%s,%s\n' "$(date --iso-8601=seconds)" "${stage}" "${values// /,}" \
    >> "${HEARTBEAT_CSV}"
}

heartbeat_loop() {
  while true; do
    write_heartbeat
    sleep "${HEARTBEAT_SECONDS}"
  done
}

failure_trap() {
  local rc=$?
  if [[ -n "${HEARTBEAT_PID:-}" ]] && kill -0 "${HEARTBEAT_PID}" 2>/dev/null; then
    kill "${HEARTBEAT_PID}" 2>/dev/null || true
    wait "${HEARTBEAT_PID}" 2>/dev/null || true
  fi
  if [[ ${rc} -ne 0 ]]; then
    printf 'status=FAILED run_id=%s exit_code=%d ended_at=%s\n' \
      "${RUN_ID}" "${rc}" "$(date --iso-8601=seconds)" \
      > "${STATE_ROOT}/pipeline.status"
  fi
}
trap failure_trap EXIT INT TERM

wait_for_resources() {
  while true; do
    local values load memory disk
    values="$(resource_values)"
    read -r load memory disk <<< "${values}"
    write_heartbeat
    if awk -v load="${load}" -v memory="${memory}" -v disk="${disk}" \
      -v max_load="${MAX_LOAD}" -v min_memory="${MIN_MEMORY_GB}" \
      -v min_disk="${MIN_DISK_GB}" \
      'BEGIN {exit !((load <= max_load) && (memory >= min_memory) && (disk >= min_disk))}'; then
      record_status "resource_gate" "PASS" \
        "load=${load};memory_gb=${memory};disk_gb=${disk}"
      return 0
    fi
    record_status "resource_gate" "WAIT" \
      "load=${load};memory_gb=${memory};disk_gb=${disk}"
    sleep "${POLL_SECONDS}"
  done
}

select_idle_cpus() {
  local count
  count="$(getconf _NPROCESSORS_ONLN)"
  ps -eLo psr=,pcpu= 2>/dev/null | awk -v n="${count}" '
    {cpu=$1+0; used[cpu]+=$2+0}
    END {for (i=0; i<n; i++) printf "%d %.6f\n", i, used[i]+0}
  ' | sort -k2,2n -k1,1n | awk -v workers="${WORKERS}" \
    'NR <= workers {print $1}' | paste -sd, -
}

printf 'initializing\n' > "${CURRENT_STAGE}"
heartbeat_loop &
HEARTBEAT_PID=$!

printf 'sentinel_gate\n' > "${CURRENT_STAGE}"
SENTINEL_CLOSEOUT="${REPO_ROOT}/results/qdesn_mcmc_validation/qdesn_dqlm_500obs_independent_exdqlm_mcmc_rolling_state_fix_v1/${SENTINEL_RUN_ID}/closeout/closeout.json"
if [[ ! -f "${SENTINEL_CLOSEOUT}" ]]; then
  echo "The successful sentinel closeout is missing." >&2
  exit 3
fi
sentinel_decision="$(jq -r '.decision' "${SENTINEL_CLOSEOUT}")"
if [[ "${sentinel_decision}" != \
      "SENTINEL_PASS_PROCEED_TO_FULL_27_JOB_CONFIRMATION" ]]; then
  echo "The sentinel does not authorize full confirmation." >&2
  exit 3
fi
SENTINEL_COMPARISON="$(jq -r '.comparison_path' "${SENTINEL_CLOSEOUT}")"
SENTINEL_CHECKS="$(jq -r '.checks_path' "${SENTINEL_CLOSEOUT}")"
if [[ "$(sha256sum "${SENTINEL_COMPARISON}" | awk '{print $1}')" != \
      "$(jq -r '.comparison_sha256' "${SENTINEL_CLOSEOUT}")" || \
      "$(sha256sum "${SENTINEL_CHECKS}" | awk '{print $1}')" != \
      "$(jq -r '.checks_sha256' "${SENTINEL_CLOSEOUT}")" ]]; then
  echo "The sentinel evidence hash verification failed." >&2
  exit 3
fi
record_status "sentinel_gate" "PASS" "decision=${sentinel_decision};checks=8/8"

printf 'resource_gate\n' > "${CURRENT_STAGE}"
wait_for_resources
CPU_SET="${CPU_SET:-$(select_idle_cpus)}"
CPU_COUNT="$(tr ',' '\n' <<< "${CPU_SET}" | sed '/^$/d' | wc -l)"
if [[ "${CPU_COUNT}" -ne "${WORKERS}" ]]; then
  echo "Expected ${WORKERS} selected CPUs; found ${CPU_COUNT}: ${CPU_SET}" >&2
  exit 3
fi
record_status "cpu_selection" "PASS" \
  "workers=${WORKERS};threads_per_fit=1;cpus=${CPU_SET}"

cat > "${STATE_ROOT}/run_contract.env" <<EOF
RUN_ID=${RUN_ID}
WORKTREE=${REPO_ROOT}
BRANCH=${branch}
UPSTREAM=${upstream}
GIT_COMMIT=${GIT_SHA}
PACKAGE_VERSION=1.1.1
PACKAGE_REPOSITORY=CRAN
PACKAGE_TARBALL_SHA256=${EXPECTED_TARBALL_SHA}
SENTINEL_RUN_ID=${SENTINEL_RUN_ID}
TOTAL_JOBS=27
TOTAL_CELLS=9
CHAINS_PER_CELL=3
WORKERS=${WORKERS}
THREADS_PER_FIT=1
CPU_SET=${CPU_SET}
ARTICLE_UPDATE_AUTOMATIC=FALSE
SHARED_VALIDATION_UPDATE_AUTOMATIC=FALSE
EOF

printf 'materialization\n' > "${CURRENT_STAGE}"
record_status "materialization" "STARTED" "run_id=${RUN_ID};mode=full"
"${R_SCRIPT}" \
  "${SCRIPT_DIR}/materialize_independent_exdqlm_mcmc_rolling_state_fix_v1.R" \
  --repo-root "${REPO_ROOT}" --run-id "${RUN_ID}" --mode full
MANIFEST="${RUN_ROOT}/manifests/job_manifest.csv"
materialized_jobs="$(( $(wc -l < "${MANIFEST}") - 1 ))"
if [[ "${materialized_jobs}" -ne 27 ]]; then
  echo "Full materialization produced ${materialized_jobs}, not 27, jobs." >&2
  exit 3
fi
record_status "materialization" "PASS" "jobs=27;scientific_contract_equal=27"

printf 'launcher_dry_run\n' > "${CURRENT_STAGE}"
record_status "launcher_dry_run" "STARTED" "manifest=${MANIFEST}"
"${R_SCRIPT}" "${SCRIPT_DIR}/launch_exdqlm_dynamic_fitforecast_v2_validation.R" \
  --manifest "${MANIFEST}" --phase mcmc_tt500 --workers "${WORKERS}" --dry-run \
  > "${STATE_ROOT}/launcher_dry_run.log" 2>&1
record_status "launcher_dry_run" "PASS" "selected_rows=27;compute=FALSE"

printf 'full_confirmation\n' > "${CURRENT_STAGE}"
record_status "full_confirmation" "STARTED" \
  "jobs=27;workers=${WORKERS};threads_per_fit=1"
taskset -c "${CPU_SET}" env EXDQLM_FFV2_LAUNCH_APPROVED=true \
  "${R_SCRIPT}" "${SCRIPT_DIR}/launch_exdqlm_dynamic_fitforecast_v2_validation.R" \
  --manifest "${MANIFEST}" --phase mcmc_tt500 --workers "${WORKERS}"
record_status "full_confirmation" "PASS" "launcher_exit=0"

printf 'closeout\n' > "${CURRENT_STAGE}"
record_status "closeout" "STARTED" "three-chain aggregation and evidence audit"
"${R_SCRIPT}" \
  "${SCRIPT_DIR}/closeout_independent_exdqlm_mcmc_rolling_state_fix_v1_full.R" \
  --repo-root "${REPO_ROOT}" --manifest "${MANIFEST}"
record_status "closeout" "PASS" "27/27 jobs;9/9 cells;candidate block frozen"

printf 'diagnostics\n' > "${CURRENT_STAGE}"
record_status "diagnostics" "STARTED" "ignored review packet"
"${R_SCRIPT}" \
  "${SCRIPT_DIR}/build_independent_exdqlm_mcmc_rolling_state_fix_v1_diagnostics.R" \
  --repo-root "${REPO_ROOT}" --closeout-root "${RUN_ROOT}/closeout" \
  --output-root "${STATE_ROOT}/diagnostics"
record_status "diagnostics" "PASS" "packet generated;article untouched"

printf 'storage_audit\n' > "${CURRENT_STAGE}"
find "${RUN_ROOT}" -type f \
  \( -iname '*.rds' -o -iname '*.rda' -o -iname '*.rdata' \) \
  -printf '%s\t%p\n' | sort -nr > "${STATE_ROOT}/heavy_binary_audit.tsv"
if [[ -s "${STATE_ROOT}/heavy_binary_audit.tsv" ]]; then
  echo "Forbidden fitted-model binary payloads remain after closeout." >&2
  exit 4
fi
record_status "storage_audit" "PASS" "fitted_model_binaries=0"

printf 'pipeline_complete\n' > "${CURRENT_STAGE}"
write_heartbeat
record_status "pipeline_complete" "PASS" \
  "ready_for_integration;article_shared_overleaf_untouched"
printf 'status=SUCCESS run_id=%s ended_at=%s\n' \
  "${RUN_ID}" "$(date --iso-8601=seconds)" > "${STATE_ROOT}/pipeline.status"
kill "${HEARTBEAT_PID}" 2>/dev/null || true
wait "${HEARTBEAT_PID}" 2>/dev/null || true
HEARTBEAT_PID=""
trap - EXIT INT TERM
echo "FULL_CONFIRMATION_COMPLETE run_id=${RUN_ID}"

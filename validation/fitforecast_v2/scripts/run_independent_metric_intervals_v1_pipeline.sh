#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HARNESS_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
REPO_ROOT="$(cd "${HARNESS_ROOT}/../.." && pwd)"
RUN_ID="${RUN_ID:-independent_metric_intervals_v1_$(date +%Y%m%d_%H%M%S)}"
WORKERS="${WORKERS:-20}"
STATE_ROOT="${STATE_ROOT:-${REPO_ROOT}/reports/shared_fitforecast_v2_orchestration/${RUN_ID}}"
PIPELINE_LOG="${STATE_ROOT}/pipeline.stdout.log"

# Apply numerical-library limits before R initializes its thread pools.
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
if [[ "${branch}" != "validation/independent-metric-intervals-v1-1.0.0" ]]; then
  echo "Refusing to run from unexpected branch: ${branch}" >&2
  exit 2
fi
if [[ -n "$(git -C "${REPO_ROOT}" status --short)" ]]; then
  echo "Refusing to run from a dirty scientific worktree." >&2
  exit 2
fi

if [[ ! -f "${STATE_ROOT}/manifests/job_plan.csv" ]]; then
  if [[ -e "${STATE_ROOT}" ]]; then
    echo "Refusing to materialize into an existing incomplete run root: ${STATE_ROOT}" >&2
    exit 2
  fi
  Rscript "${SCRIPT_DIR}/materialize_independent_metric_intervals_v1.R" \
    --repo-root "${REPO_ROOT}" --run-id "${RUN_ID}" --state-root "${STATE_ROOT}" \
    --workers "${WORKERS}"
fi

exec > >(tee -a "${PIPELINE_LOG}") 2>&1

on_error() {
  local code=$?
  printf 'status=FAIL exit=%s ended_at=%s\n' "${code}" "$(date --iso-8601=seconds)" > "${STATE_ROOT}/pipeline.status"
  exit "${code}"
}
trap on_error ERR

printf 'status=RUNNING run_id=%s started_at=%s\n' "${RUN_ID}" "$(date --iso-8601=seconds)" > "${STATE_ROOT}/pipeline.status"
Rscript "${SCRIPT_DIR}/verify_independent_metric_intervals_v1_plan.R" \
  --state-root "${STATE_ROOT}"
IMI_V1_LAUNCH_APPROVED=true Rscript "${SCRIPT_DIR}/orchestrate_independent_metric_intervals_v1.R" \
  --repo-root "${REPO_ROOT}" --state-root "${STATE_ROOT}" --workers "${WORKERS}"
Rscript "${SCRIPT_DIR}/closeout_independent_metric_intervals_v1.R" \
  --repo-root "${REPO_ROOT}" --state-root "${STATE_ROOT}"
printf 'status=SUCCESS run_id=%s ended_at=%s\n' "${RUN_ID}" "$(date --iso-8601=seconds)" > "${STATE_ROOT}/pipeline.status"
echo "pipeline complete: ${STATE_ROOT}"

#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HARNESS_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
REPO_ROOT="$(cd "${HARNESS_ROOT}/../.." && pwd)"
EXPECTED_BRANCH="validation/independent-exdqlm-mcmc-rolling-state-fix-v1-1.0.0"
EXPECTED_UPSTREAM="origin/${EXPECTED_BRANCH}"
RUN_ID="${RUN_ID:-independent_exdqlm_mcmc_rolling_state_fix_v1_sentinel_$(date +%Y%m%d_%H%M%S)}"
TASK_TRACKER="${REPO_ROOT}/validation/fitforecast_v2/local_trackers/independent_exdqlm_mcmc_rolling_state_fix_v1"
R_LIBRARY="${TASK_TRACKER}/Rlib"
TARBALL="${TASK_TRACKER}/package/exdqlm_1.1.1.tar.gz"
EXPECTED_TARBALL_SHA="3f3ed643ded7602fd62357d7f62024ca9071e0096214456650ed2de79722443e"
RUN_ROOT="${REPO_ROOT}/results/qdesn_mcmc_validation/qdesn_dqlm_500obs_independent_exdqlm_mcmc_rolling_state_fix_v1/${RUN_ID}"
STATE_ROOT="${REPO_ROOT}/reports/shared_fitforecast_v2_orchestration/${RUN_ID}"
PIPELINE_LOG="${STATE_ROOT}/pipeline.stdout.log"

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
if [[ "$(git -C "${REPO_ROOT}" rev-parse HEAD)" != \
      "$(git -C "${REPO_ROOT}" rev-parse '@{u}')" ]]; then
  echo "Refusing an unsynchronized scientific branch." >&2
  exit 2
fi
if [[ ! -f "${TARBALL}" || ! -d "${R_LIBRARY}/exdqlm" ]]; then
  echo "Task-local CRAN exdqlm 1.1.1 is unavailable." >&2
  exit 2
fi
observed_sha="$(sha256sum "${TARBALL}" | awk '{print $1}')"
if [[ "${observed_sha}" != "${EXPECTED_TARBALL_SHA}" ]]; then
  echo "CRAN tarball hash mismatch." >&2
  exit 2
fi
if [[ -e "${RUN_ROOT}" || -e "${STATE_ROOT}" ]]; then
  echo "Refusing a pre-existing sentinel run ID: ${RUN_ID}" >&2
  exit 2
fi

mkdir -p "${STATE_ROOT}"
exec > >(tee -a "${PIPELINE_LOG}") 2>&1
printf 'status=RUNNING run_id=%s started_at=%s\n' "${RUN_ID}" "$(date --iso-8601=seconds)" \
  > "${STATE_ROOT}/pipeline.status"

record_failure() {
  rc=$?
  if [[ ${rc} -ne 0 ]]; then
    printf 'status=FAILED run_id=%s exit_code=%d ended_at=%s\n' \
      "${RUN_ID}" "${rc}" "$(date --iso-8601=seconds)" \
      > "${STATE_ROOT}/pipeline.status"
  fi
}
trap record_failure EXIT

Rscript "${SCRIPT_DIR}/materialize_independent_exdqlm_mcmc_rolling_state_fix_v1.R" \
  --repo-root "${REPO_ROOT}" --run-id "${RUN_ID}" --mode sentinel
MANIFEST="${RUN_ROOT}/manifests/job_manifest.csv"
EXDQLM_FFV2_LAUNCH_APPROVED=true Rscript \
  "${SCRIPT_DIR}/launch_exdqlm_dynamic_fitforecast_v2_validation.R" \
  --manifest "${MANIFEST}" --phase mcmc_tt500 --workers 3
Rscript "${SCRIPT_DIR}/summarize_independent_exdqlm_mcmc_rolling_state_fix_v1.R" \
  --manifest "${MANIFEST}"
printf 'status=SUCCESS run_id=%s ended_at=%s\n' "${RUN_ID}" "$(date --iso-8601=seconds)" \
  > "${STATE_ROOT}/pipeline.status"
trap - EXIT
echo "SENTINEL_COMPLETE run_id=${RUN_ID}"

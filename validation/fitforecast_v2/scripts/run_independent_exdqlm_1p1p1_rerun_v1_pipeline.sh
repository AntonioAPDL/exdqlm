#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HARNESS_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
REPO_ROOT="$(cd "${HARNESS_ROOT}/../.." && pwd)"
EXPECTED_BRANCH="validation/independent-qdesn-exdqlm-1.1.1-rerun-20260827"
PACKAGE_COMMIT="6dba6f2863705e0e90f0ce19e0c75d106d022a52"
PACKAGE_VERSION="1.1.1"
AUTHORITY_ID="qdesn_dqlm_500obs_trainonly_article_v11_location_orthogonalized_20260827"
CAMPAIGN_SCHEMA="independent_qdesn_exdqlm_1p1p1_rerun_v1"
CAMPAIGN_STAGE="qdesn_dqlm_500obs_independent_exdqlm_1p1p1_rerun_v1"
SEED_LEDGER="${REPO_ROOT}/config/validation/independent_qdesn_exdqlm_1p1p1_rerun_v1_seed_ledger.csv"
TASK_TRACKER="${REPO_ROOT}/validation/fitforecast_v2/local_trackers/independent_qdesn_exdqlm_1p1p1_rerun_20260827"
PACKAGE_TARBALL="${PACKAGE_TARBALL:-${TASK_TRACKER}/package/exdqlm_1.1.1.tar.gz}"
PACKAGE_BUILD_MANIFEST="${PACKAGE_BUILD_MANIFEST:-${TASK_TRACKER}/package/package_build_manifest.json}"
R_LIBRARY="${R_LIBRARY:-${TASK_TRACKER}/Rlib}"
SMOKE="${SMOKE:-false}"
if [[ "${SMOKE}" == "true" ]]; then
  WORKERS="${WORKERS:-4}"
  RUN_ID="${RUN_ID:-independent_qdesn_exdqlm_1p1p1_rerun_v1_smoke_$(date +%Y%m%d_%H%M%S)}"
else
  WORKERS="${WORKERS:-16}"
  RUN_ID="${RUN_ID:-independent_qdesn_exdqlm_1p1p1_rerun_v1_$(date +%Y%m%d_%H%M%S)}"
fi
STATE_ROOT="${STATE_ROOT:-${REPO_ROOT}/reports/shared_fitforecast_v2_orchestration/${RUN_ID}}"
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
head="$(git -C "${REPO_ROOT}" rev-parse HEAD)"
upstream="$(git -C "${REPO_ROOT}" rev-parse --abbrev-ref --symbolic-full-name '@{u}')"
upstream_head="$(git -C "${REPO_ROOT}" rev-parse '@{u}')"
if [[ "${branch}" != "${EXPECTED_BRANCH}" ]]; then
  echo "Refusing unexpected branch: ${branch}" >&2
  exit 2
fi
if [[ -n "$(git -C "${REPO_ROOT}" status --short)" ]]; then
  echo "Refusing a dirty scientific worktree." >&2
  exit 2
fi
if [[ "${head}" != "${upstream_head}" ]]; then
  echo "Refusing an unpushed or divergent branch: HEAD=${head} upstream=${upstream_head}" >&2
  exit 2
fi
if ! git -C "${REPO_ROOT}" merge-base --is-ancestor "${PACKAGE_COMMIT}" HEAD; then
  echo "Required exdqlm 1.1.1 source commit is not an ancestor of HEAD." >&2
  exit 2
fi
observed_version="$(Rscript -e "cat(read.dcf(file.path('${REPO_ROOT}', 'DESCRIPTION'))[1L, 'Version'])")"
if [[ "${observed_version}" != "${PACKAGE_VERSION}" ]]; then
  echo "DESCRIPTION does not report exdqlm ${PACKAGE_VERSION}." >&2
  exit 2
fi
if [[ ! -f "${PACKAGE_TARBALL}" || ! -f "${PACKAGE_BUILD_MANIFEST}" ||
      ! -d "${R_LIBRARY}/exdqlm" ]]; then
  echo "Pinned task-local tarball, build manifest, or installed library is missing." >&2
  exit 2
fi

package_sha256="$(sha256sum "${PACKAGE_TARBALL}" | awk '{print $1}')"
build_head="$(Rscript --vanilla -e 'x <- jsonlite::fromJSON(commandArgs(TRUE)[[1L]]); cat(x$git_commit)' "${PACKAGE_BUILD_MANIFEST}")"
build_sha256="$(Rscript --vanilla -e 'x <- jsonlite::fromJSON(commandArgs(TRUE)[[1L]]); cat(x$tarball_sha256)' "${PACKAGE_BUILD_MANIFEST}")"
if [[ "${build_head}" != "${head}" || "${build_sha256}" != "${package_sha256}" ]]; then
  echo "Pinned package build manifest does not match HEAD and tarball." >&2
  exit 2
fi
mkdir -p "${STATE_ROOT}" "${STATE_ROOT}/manifests"
exec 9>"${REPO_ROOT}/reports/shared_fitforecast_v2_orchestration/independent_qdesn_exdqlm_1p1p1_rerun_v1.lock"
if ! flock -n 9; then
  echo "Another exdqlm 1.1.1 independent-validation pipeline holds the lock." >&2
  exit 2
fi
exec > >(tee -a "${PIPELINE_LOG}") 2>&1

on_error() {
  local code=$?
  printf 'status=FAIL exit=%s run_id=%s head=%s ended_at=%s\n' \
    "${code}" "${RUN_ID}" "${head}" "$(date --iso-8601=seconds)" > "${STATE_ROOT}/pipeline.status"
  exit "${code}"
}
trap on_error ERR

printf 'status=RUNNING run_id=%s head=%s upstream=%s package_sha256=%s started_at=%s\n' \
  "${RUN_ID}" "${head}" "${upstream}" "${package_sha256}" \
  "$(date --iso-8601=seconds)" > "${STATE_ROOT}/pipeline.status"

Rscript "${SCRIPT_DIR}/preflight_independent_exdqlm_1p1p1_rerun_v1.R" \
  --repo-root "${REPO_ROOT}" --state-root "${STATE_ROOT}/preflight" \
  --tarball "${PACKAGE_TARBALL}" --build-manifest "${PACKAGE_BUILD_MANIFEST}"

materialize_args=(
  --repo-root "${REPO_ROOT}"
  --run-id "${RUN_ID}"
  --state-root "${STATE_ROOT}"
  --workers "${WORKERS}"
  --schema "${CAMPAIGN_SCHEMA}"
  --stage "${CAMPAIGN_STAGE}"
  --authority-id "${AUTHORITY_ID}"
  --package-version "${PACKAGE_VERSION}"
  --package-source-commit "${PACKAGE_COMMIT}"
  --package-tarball-sha256 "${package_sha256}"
  --seed-ledger "${SEED_LEDGER}"
)
if [[ "${SMOKE}" == "true" ]]; then
  materialize_args+=(--smoke true)
fi
if [[ ! -f "${STATE_ROOT}/manifests/job_plan.csv" ]]; then
  Rscript "${SCRIPT_DIR}/materialize_independent_metric_intervals_v1.R" \
    "${materialize_args[@]}"
fi

Rscript "${SCRIPT_DIR}/verify_independent_metric_intervals_v1_plan.R" \
  --state-root "${STATE_ROOT}"
IMI_V1_LAUNCH_APPROVED=true Rscript \
  "${SCRIPT_DIR}/orchestrate_independent_metric_intervals_v1.R" \
  --repo-root "${REPO_ROOT}" --state-root "${STATE_ROOT}" --workers "${WORKERS}"
Rscript "${SCRIPT_DIR}/closeout_independent_metric_intervals_v1.R" \
  --repo-root "${REPO_ROOT}" --state-root "${STATE_ROOT}"

if [[ "${SMOKE}" != "true" ]]; then
  Rscript "${SCRIPT_DIR}/build_independent_exdqlm_1p1p1_diagnostic_packet_v1.R" \
    --repo-root "${REPO_ROOT}" --state-root "${STATE_ROOT}"
fi

printf 'status=SUCCESS run_id=%s head=%s package_sha256=%s ended_at=%s\n' \
  "${RUN_ID}" "${head}" "${package_sha256}" "$(date --iso-8601=seconds)" \
  > "${STATE_ROOT}/pipeline.status"
echo "pipeline complete: ${STATE_ROOT}"

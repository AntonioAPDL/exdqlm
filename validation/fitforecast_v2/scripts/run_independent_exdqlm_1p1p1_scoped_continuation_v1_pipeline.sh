#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HARNESS_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
REPO_ROOT="$(cd "${HARNESS_ROOT}/../.." && pwd)"
EXPECTED_BRANCH="validation/independent-qdesn-exdqlm-1.1.1-rerun-20260827"
PACKAGE_COMMIT="6dba6f2863705e0e90f0ce19e0c75d106d022a52"
PACKAGE_VERSION="1.1.1"
PARENT_RUN_ID="${PARENT_RUN_ID:-independent_qdesn_exdqlm_1p1p1_rerun_v1_20260828_000419}"
PARENT_STATE_ROOT="${PARENT_STATE_ROOT:-${REPO_ROOT}/reports/shared_fitforecast_v2_orchestration/${PARENT_RUN_ID}}"
RUN_ID="${RUN_ID:-independent_exdqlm_1p1p1_scoped_v1_$(date +%Y%m%d_%H%M%S)}"
STATE_ROOT="${STATE_ROOT:-${REPO_ROOT}/reports/shared_fitforecast_v2_orchestration/${RUN_ID}}"
WORKERS="${WORKERS:-16}"
TASK_TRACKER="${REPO_ROOT}/validation/fitforecast_v2/local_trackers/independent_qdesn_exdqlm_1p1p1_rerun_20260827"
PACKAGE_TARBALL="${PACKAGE_TARBALL:-${TASK_TRACKER}/package/exdqlm_1.1.1.tar.gz}"
PACKAGE_BUILD_MANIFEST="${PACKAGE_BUILD_MANIFEST:-${TASK_TRACKER}/package/package_build_manifest.json}"
R_LIBRARY="${R_LIBRARY:-${TASK_TRACKER}/Rlib}"
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
  echo "Refusing an unpushed or divergent scientific branch." >&2
  exit 2
fi
if [[ ! -d "${PARENT_STATE_ROOT}" || ! -f "${PARENT_STATE_ROOT}/manifests/job_plan.csv" ]]; then
  echo "The frozen parent campaign is unavailable: ${PARENT_STATE_ROOT}" >&2
  exit 2
fi
if [[ -e "${STATE_ROOT}" ]]; then
  echo "Refusing a pre-existing scoped state root: ${STATE_ROOT}" >&2
  exit 2
fi
if [[ ! -f "${PACKAGE_TARBALL}" || ! -f "${PACKAGE_BUILD_MANIFEST}" ||
      ! -d "${R_LIBRARY}/exdqlm" ]]; then
  echo "The pinned exdqlm 1.1.1 package environment is incomplete." >&2
  exit 2
fi
if ! git -C "${REPO_ROOT}" merge-base --is-ancestor "${PACKAGE_COMMIT}" HEAD; then
  echo "The required exdqlm 1.1.1 source commit is not an ancestor of HEAD." >&2
  exit 2
fi

package_sha256="$(sha256sum "${PACKAGE_TARBALL}" | awk '{print $1}')"
build_head="$(Rscript --vanilla -e 'x <- jsonlite::fromJSON(commandArgs(TRUE)[[1L]]); cat(x$git_commit)' "${PACKAGE_BUILD_MANIFEST}")"
build_sha256="$(Rscript --vanilla -e 'x <- jsonlite::fromJSON(commandArgs(TRUE)[[1L]]); cat(x$tarball_sha256)' "${PACKAGE_BUILD_MANIFEST}")"
parent_sha256="$(Rscript --vanilla -e 'x <- jsonlite::fromJSON(commandArgs(TRUE)[[1L]]); cat(x$package_tarball_sha256)' "${PARENT_STATE_ROOT}/manifests/materialization_manifest.json")"
if [[ "${build_sha256}" != "${package_sha256}" ||
      "${parent_sha256}" != "${package_sha256}" ]]; then
  echo "The task-local package tarball does not match the frozen parent campaign." >&2
  exit 2
fi
if ! git -C "${REPO_ROOT}" merge-base --is-ancestor "${build_head}" HEAD; then
  echo "The frozen package build commit is not an ancestor of the scoped launcher." >&2
  exit 2
fi
mapfile -t post_build_changes < <(git -C "${REPO_ROOT}" diff --name-only "${build_head}..HEAD")
for changed_path in "${post_build_changes[@]}"; do
  if [[ "${changed_path}" != validation/fitforecast_v2/* ]]; then
    echo "A package-affecting path changed after the frozen build: ${changed_path}" >&2
    exit 2
  fi
done
observed_version="$(Rscript -e 'cat(as.character(packageVersion("exdqlm")))')"
if [[ "${observed_version}" != "${PACKAGE_VERSION}" ]]; then
  echo "The scoped R library does not load exdqlm ${PACKAGE_VERSION}." >&2
  exit 2
fi

mkdir -p "${STATE_ROOT}/manifests"
exec 9>"${REPO_ROOT}/reports/shared_fitforecast_v2_orchestration/independent_exdqlm_1p1p1_scoped_v1.lock"
if ! flock -n 9; then
  echo "Another scoped exDQLM continuation holds the launch lock." >&2
  exit 2
fi
exec > >(tee -a "${PIPELINE_LOG}") 2>&1

write_terminal_status() {
  local state="$1"
  local code="$2"
  printf 'status=%s exit=%s run_id=%s head=%s package_build_head=%s ended_at=%s\n' \
    "${state}" "${code}" "${RUN_ID}" "${head}" "${build_head}" \
    "$(date --iso-8601=seconds)" > "${STATE_ROOT}/pipeline.status"
}
on_error() {
  local code=$?
  write_terminal_status "FAIL" "${code}"
  exit "${code}"
}
on_interrupt() {
  write_terminal_status "INTERRUPTED" 130
  exit 130
}
trap on_error ERR
trap on_interrupt INT TERM

printf 'status=RUNNING run_id=%s head=%s package_build_head=%s package_sha256=%s parent_run_id=%s started_at=%s\n' \
  "${RUN_ID}" "${head}" "${build_head}" "${package_sha256}" "${PARENT_RUN_ID}" \
  "$(date --iso-8601=seconds)" > "${STATE_ROOT}/pipeline.status"

Rscript "${SCRIPT_DIR}/preflight_independent_exdqlm_1p1p1_rerun_v1.R" \
  --repo-root "${REPO_ROOT}" --state-root "${STATE_ROOT}/preflight" \
  --tarball "${PACKAGE_TARBALL}" --build-manifest "${PACKAGE_BUILD_MANIFEST}"

Rscript "${SCRIPT_DIR}/prepare_independent_exdqlm_1p1p1_scoped_continuation_v1.R" \
  --repo-root "${REPO_ROOT}" --parent-state-root "${PARENT_STATE_ROOT}" \
  --state-root "${STATE_ROOT}" --run-id "${RUN_ID}"

Rscript "${SCRIPT_DIR}/verify_independent_exdqlm_1p1p1_scoped_continuation_v1.R" \
  --state-root "${STATE_ROOT}"

IMI_V1_LAUNCH_APPROVED=true Rscript \
  "${SCRIPT_DIR}/orchestrate_independent_metric_intervals_v1.R" \
  --repo-root "${REPO_ROOT}" --state-root "${STATE_ROOT}" --workers "${WORKERS}"

Rscript "${SCRIPT_DIR}/closeout_independent_exdqlm_1p1p1_scoped_continuation_v1.R" \
  --repo-root "${REPO_ROOT}" --state-root "${STATE_ROOT}"

Rscript "${SCRIPT_DIR}/build_independent_exdqlm_1p1p1_scoped_diagnostic_packet_v1.R" \
  --state-root "${STATE_ROOT}"

write_terminal_status "SUCCESS" 0
echo "scoped exDQLM 1.1.1 continuation complete: ${STATE_ROOT}"

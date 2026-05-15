#!/usr/bin/env bash
set -euo pipefail

RUN_TAG=""
MANIFEST="config/validation/qdesn_rhs_stageM_repair_manifest.yaml"
MAX_ATTEMPTS=4
SLEEP_SECONDS=15
NO_PLOTS=1
QUIET=0

usage() {
  cat <<'EOF'
Usage: scripts/run_qdesn_rhs_stageM_repair_supervisor.sh [options]

Options:
  --run-tag <tag>         Run tag for analysis/results roots.
  --manifest <path>       Stage-M repair manifest YAML (default: config/validation/qdesn_rhs_stageM_repair_manifest.yaml).
  --max-attempts <n>      Maximum relaunch attempts before failing (default: 4).
  --sleep-seconds <n>     Sleep between failed attempts (default: 15).
  --no-plots              Disable plot generation (default: enabled).
  --with-plots            Enable plot generation.
  --quiet                 Pass --quiet to the underlying runner.
  --help                  Print this help.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --run-tag)
      RUN_TAG="${2:-}"
      shift 2
      ;;
    --manifest)
      MANIFEST="${2:-}"
      shift 2
      ;;
    --max-attempts)
      MAX_ATTEMPTS="${2:-}"
      shift 2
      ;;
    --sleep-seconds)
      SLEEP_SECONDS="${2:-}"
      shift 2
      ;;
    --no-plots)
      NO_PLOTS=1
      shift
      ;;
    --with-plots)
      NO_PLOTS=0
      shift
      ;;
    --quiet)
      QUIET=1
      shift
      ;;
    --help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 2
      ;;
  esac
done

if [[ -z "${RUN_TAG}" ]]; then
  RUN_TAG="stageMrepair-supervised-$(date +%Y%m%d-%H%M%S)__git-$(git rev-parse --short HEAD)"
fi

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "${REPO_ROOT}"

ANALYSIS_ROOT="${REPO_ROOT}/reports/qdesn_mcmc_validation/rhs_stageM_repair_wave/${RUN_TAG}"
RESULTS_ROOT="${REPO_ROOT}/results/qdesn_mcmc_validation/rhs_stageM_repair_wave/${RUN_TAG}"
LOG_DIR="${ANALYSIS_ROOT}/logs"
STATUS_CSV="${LOG_DIR}/supervisor_attempt_status.csv"
mkdir -p "${LOG_DIR}" "${ANALYSIS_ROOT}/manifest" "${ANALYSIS_ROOT}/tables" "${ANALYSIS_ROOT}/config" "${RESULTS_ROOT}"

if [[ ! -f "${STATUS_CSV}" ]]; then
  echo "attempt,timestamp_utc,exit_code,final_manifest_present,mr2_summary_present,mr3_summary_present,runner_log" > "${STATUS_CSV}"
fi

FINAL_MANIFEST="${ANALYSIS_ROOT}/manifest/stageM_repair_manifest.json"
MR2_SUMMARY="${ANALYSIS_ROOT}/tables/mr2_canary_summary.csv"
MR3_SUMMARY="${ANALYSIS_ROOT}/tables/mr3_full_summary.csv"

if [[ -f "${FINAL_MANIFEST}" ]]; then
  echo "[stageM-supervisor] Final manifest already present: ${FINAL_MANIFEST}"
  exit 0
fi

attempt=1
while [[ "${attempt}" -le "${MAX_ATTEMPTS}" ]]; do
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  stamp="$(date +%Y%m%d-%H%M%S)"
  runner_log="${LOG_DIR}/runner_attempt${attempt}_${stamp}.log"

  cmd=(Rscript scripts/run_qdesn_rhs_stageM_repair_wave.R
    --manifest "${MANIFEST}"
    --run-tag "${RUN_TAG}"
    --analysis-root "${ANALYSIS_ROOT}"
    --results-root "${RESULTS_ROOT}")
  if [[ "${NO_PLOTS}" -eq 1 ]]; then
    cmd+=(--no-plots)
  fi
  if [[ "${QUIET}" -eq 1 ]]; then
    cmd+=(--quiet)
  fi

  echo "[stageM-supervisor] attempt=${attempt}/${MAX_ATTEMPTS} run_tag=${RUN_TAG}" | tee -a "${runner_log}"
  echo "[stageM-supervisor] command: ${cmd[*]}" | tee -a "${runner_log}"

  set +e
  "${cmd[@]}" >> "${runner_log}" 2>&1
  exit_code=$?
  set -e

  final_manifest_present=0
  mr2_summary_present=0
  mr3_summary_present=0
  [[ -f "${FINAL_MANIFEST}" ]] && final_manifest_present=1
  [[ -f "${MR2_SUMMARY}" ]] && mr2_summary_present=1
  [[ -f "${MR3_SUMMARY}" ]] && mr3_summary_present=1

  echo "${attempt},${ts},${exit_code},${final_manifest_present},${mr2_summary_present},${mr3_summary_present},${runner_log}" >> "${STATUS_CSV}"

  if [[ "${final_manifest_present}" -eq 1 ]]; then
    echo "[stageM-supervisor] SUCCESS: final manifest written: ${FINAL_MANIFEST}" | tee -a "${runner_log}"
    exit 0
  fi

  if [[ "${attempt}" -lt "${MAX_ATTEMPTS}" ]]; then
    echo "[stageM-supervisor] attempt ${attempt} ended without final manifest; sleeping ${SLEEP_SECONDS}s before retry." | tee -a "${runner_log}"
    sleep "${SLEEP_SECONDS}"
  fi

  attempt=$((attempt + 1))
done

echo "[stageM-supervisor] FAILED after ${MAX_ATTEMPTS} attempts without final manifest: ${FINAL_MANIFEST}" >&2
exit 1

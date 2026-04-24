#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  scripts/cleanup_qdesn_validation_rds_payloads.sh [--execute] [--run-label LABEL] [--allow-live-sessions]

Purpose:
  Remove heavy, reproducible QDESN validation binary payloads after a validation
  campaign has been closed and summarized.

Defaults:
  - Dry run only. No files are deleted unless --execute is supplied.
  - Protects source dataset surfaces, tracked package data, configs, docs, code,
    CSV summaries, logs, figures, and manifests.
  - Targets only validation fit payloads that are safe to discard after closeout:
      results/qdesn_mcmc_validation/**/models/forecast_objects.rds
      results/qdesn_mcmc_validation/**/models/rhs_trace.rds
      results/qdesn_mcmc_validation/**/models/timing_summary.rds
      reports/qdesn_mcmc_validation/**/models/forecast_objects.rds
      reports/qdesn_mcmc_validation/**/models/rhs_trace.rds
      reports/qdesn_mcmc_validation/**/models/timing_summary.rds
  - Inventories .RData/.rdata files under results/reports, but blocks execute
    mode if any are found because those require manual review.

Safety:
  - Execute mode refuses to run while live qdesn tmux/Rscript sessions exist
    unless --allow-live-sessions is supplied.
  - The script never deletes data/*.rda or source-surface sim_output.rds files.

Outputs:
  reports/qdesn_mcmc_validation/storage_cleanup/<run-label>/
EOF
}

RUN_MODE="dry_run"
RUN_LABEL=""
ALLOW_LIVE_SESSIONS="false"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --execute)
      RUN_MODE="execute"
      shift
      ;;
    --run-label)
      RUN_LABEL="${2:-}"
      shift 2
      ;;
    --allow-live-sessions)
      ALLOW_LIVE_SESSIONS="true"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${REPO_ROOT}"

if [[ -z "${RUN_LABEL}" ]]; then
  RUN_LABEL="qdesn_validation_rds_payload_cleanup_$(date +%Y%m%d-%H%M%S)"
fi

OUT_DIR="${REPO_ROOT}/reports/qdesn_mcmc_validation/storage_cleanup/${RUN_LABEL}"
mkdir -p "${OUT_DIR}"

DELETE_MANIFEST="${OUT_DIR}/payload_files_to_delete.tsv"
PROTECT_MANIFEST="${OUT_DIR}/protected_binary_inventory.tsv"
REVIEW_MANIFEST="${OUT_DIR}/manual_review_binary_inventory.tsv"
SUMMARY_MD="${OUT_DIR}/cleanup_summary.md"
FILESYSTEM_BEFORE="${OUT_DIR}/filesystem_before.txt"
FILESYSTEM_AFTER="${OUT_DIR}/filesystem_after.txt"
GIT_STATUS="${OUT_DIR}/git_status_before.txt"
TMUX_STATUS="${OUT_DIR}/tmux_status_before.txt"
PROCESS_STATUS="${OUT_DIR}/qdesn_process_status_before.txt"
RUN_META="${OUT_DIR}/run_metadata.txt"

human_gb() {
  awk -v bytes="$1" 'BEGIN { printf "%.2f", bytes/1024/1024/1024 }'
}

capture_filesystem() {
  local target="$1"
  {
    echo "timestamp=$(date --iso-8601=seconds)"
    echo
    df -h /home /
    echo
    echo "--- du -sh results/qdesn_mcmc_validation reports/qdesn_mcmc_validation ---"
    du -sh results/qdesn_mcmc_validation reports/qdesn_mcmc_validation 2>/dev/null || true
    echo
    echo "--- largest qdesn validation result roots ---"
    find results/qdesn_mcmc_validation -mindepth 1 -maxdepth 2 -type d -exec du -sh {} + 2>/dev/null \
      | sort -hr \
      | sed -n '1,80p' || true
  } > "${target}"
}

{
  echo "timestamp=$(date --iso-8601=seconds)"
  echo "pwd=${REPO_ROOT}"
  echo "git_head=$(git rev-parse HEAD)"
  echo "git_branch=$(git rev-parse --abbrev-ref HEAD)"
  echo "mode=${RUN_MODE}"
  echo "run_label=${RUN_LABEL}"
  echo "allow_live_sessions=${ALLOW_LIVE_SESSIONS}"
} > "${RUN_META}"

capture_filesystem "${FILESYSTEM_BEFORE}"
git status --short > "${GIT_STATUS}"
tmux ls > "${TMUX_STATUS}" 2>&1 || true
pgrep -af 'qdesn|run_qdesn_dynamic_exdqlm_crossstudy|launch_qdesn_dynamic_exdqlm_crossstudy' \
  > "${PROCESS_STATUS}" 2>&1 || true

FREE_BEFORE_BYTES="$(df -B1 /home | awk 'NR==2 {print $4}')"

printf "path\tkind\tbytes\tgb\tmtime\n" > "${DELETE_MANIFEST}"
DELETE_COUNT=0
DELETE_BYTES=0

add_delete_candidate() {
  local path="$1"
  local kind="$2"
  [[ -f "${path}" ]] || return 0
  local bytes
  local mtime
  bytes="$(stat -c '%s' "${path}")"
  mtime="$(stat -c '%y' "${path}")"
  printf "%s\t%s\t%s\t%s\t%s\n" "${path}" "${kind}" "${bytes}" "$(human_gb "${bytes}")" "${mtime}" >> "${DELETE_MANIFEST}"
  DELETE_COUNT=$((DELETE_COUNT + 1))
  DELETE_BYTES=$((DELETE_BYTES + bytes))
}

while IFS= read -r path; do
  add_delete_candidate "${path}" "forecast_objects"
done < <(find results/qdesn_mcmc_validation reports/qdesn_mcmc_validation -type f -path '*/models/forecast_objects.rds' | sort)

while IFS= read -r path; do
  add_delete_candidate "${path}" "rhs_trace"
done < <(find results/qdesn_mcmc_validation reports/qdesn_mcmc_validation -type f -path '*/models/rhs_trace.rds' | sort)

while IFS= read -r path; do
  add_delete_candidate "${path}" "timing_summary"
done < <(find results/qdesn_mcmc_validation reports/qdesn_mcmc_validation -type f -path '*/models/timing_summary.rds' | sort)

printf "path\tkind\tbytes\tgb\tmtime\n" > "${PROTECT_MANIFEST}"
PROTECT_COUNT=0
PROTECT_BYTES=0

add_protected_file() {
  local path="$1"
  local kind="$2"
  [[ -f "${path}" ]] || return 0
  local bytes
  local mtime
  bytes="$(stat -c '%s' "${path}")"
  mtime="$(stat -c '%y' "${path}")"
  printf "%s\t%s\t%s\t%s\t%s\n" "${path}" "${kind}" "${bytes}" "$(human_gb "${bytes}")" "${mtime}" >> "${PROTECT_MANIFEST}"
  PROTECT_COUNT=$((PROTECT_COUNT + 1))
  PROTECT_BYTES=$((PROTECT_BYTES + bytes))
}

while IFS= read -r path; do
  add_protected_file "${path}" "package_data_rda"
done < <(find data -maxdepth 1 -type f -name '*.rda' | sort)

while IFS= read -r path; do
  add_protected_file "${path}" "source_surface_sim_output"
done < <(find results/qdesn_mcmc_validation -type f -path '*_sources/*' -name 'sim_output.rds' | sort)

printf "path\tkind\tbytes\tgb\tmtime\n" > "${REVIEW_MANIFEST}"
REVIEW_COUNT=0
REVIEW_BYTES=0

add_review_file() {
  local path="$1"
  local kind="$2"
  [[ -f "${path}" ]] || return 0
  local bytes
  local mtime
  bytes="$(stat -c '%s' "${path}")"
  mtime="$(stat -c '%y' "${path}")"
  printf "%s\t%s\t%s\t%s\t%s\n" "${path}" "${kind}" "${bytes}" "$(human_gb "${bytes}")" "${mtime}" >> "${REVIEW_MANIFEST}"
  REVIEW_COUNT=$((REVIEW_COUNT + 1))
  REVIEW_BYTES=$((REVIEW_BYTES + bytes))
}

while IFS= read -r path; do
  add_review_file "${path}" "rdata_manual_review"
done < <(find results reports -type f \( -name '*.RData' -o -name '*.rdata' \) | sort)

LIVE_QDESN_TMUX="$(
  awk -F: '/^qdesn_/ {print $1}' "${TMUX_STATUS}" 2>/dev/null || true
)"
LIVE_QDESN_PROCS="$(
  grep -E 'run_qdesn_dynamic_exdqlm_crossstudy|launch_qdesn_dynamic_exdqlm_crossstudy' "${PROCESS_STATUS}" 2>/dev/null \
    | grep -v 'pgrep -af' || true
)"

EXECUTION_BLOCKED="false"
BLOCK_REASON=""

if [[ "${RUN_MODE}" == "execute" ]] && [[ "${ALLOW_LIVE_SESSIONS}" != "true" ]] && [[ -n "${LIVE_QDESN_TMUX}${LIVE_QDESN_PROCS}" ]]; then
  EXECUTION_BLOCKED="true"
  BLOCK_REASON="Live qdesn tmux/Rscript sessions detected. Re-run after they stop or pass --allow-live-sessions."
fi

if [[ "${RUN_MODE}" == "execute" ]] && [[ "${REVIEW_COUNT}" -gt 0 ]]; then
  EXECUTION_BLOCKED="true"
  BLOCK_REASON="Manual-review .RData/.rdata files were found under results/reports. This script does not delete them automatically."
fi

DELETED_COUNT=0
DELETED_BYTES=0
if [[ "${RUN_MODE}" == "execute" ]] && [[ "${EXECUTION_BLOCKED}" != "true" ]]; then
  while IFS=$'\t' read -r path _kind bytes _gb _mtime; do
    [[ "${path}" == "path" ]] && continue
    [[ -f "${path}" ]] || continue
    rm -f "${path}"
    DELETED_COUNT=$((DELETED_COUNT + 1))
    DELETED_BYTES=$((DELETED_BYTES + bytes))
  done < "${DELETE_MANIFEST}"
fi

capture_filesystem "${FILESYSTEM_AFTER}"
FREE_AFTER_BYTES="$(df -B1 /home | awk 'NR==2 {print $4}')"
FREE_DELTA_BYTES=$((FREE_AFTER_BYTES - FREE_BEFORE_BYTES))

{
  echo "# QDESN Validation RDS Payload Cleanup"
  echo
  echo "- Run label: \`${RUN_LABEL}\`"
  echo "- Requested mode: \`${RUN_MODE}\`"
  echo "- Effective execution blocked: \`${EXECUTION_BLOCKED}\`"
  if [[ -n "${BLOCK_REASON}" ]]; then
    echo "- Block reason: ${BLOCK_REASON}"
  fi
  echo "- Git head: \`$(git rev-parse --short HEAD)\`"
  echo "- Git branch: \`$(git rev-parse --abbrev-ref HEAD)\`"
  echo "- Delete candidates: \`${DELETE_COUNT}\`"
  echo "- Delete candidate footprint: \`$(human_gb "${DELETE_BYTES}") GiB\`"
  echo "- Deleted files: \`${DELETED_COUNT}\`"
  echo "- Deleted file footprint: \`$(human_gb "${DELETED_BYTES}") GiB\`"
  echo "- Free-space delta observed on /home: \`$(human_gb "${FREE_DELTA_BYTES}") GiB\`"
  echo "- Protected binary files: \`${PROTECT_COUNT}\`"
  echo "- Protected binary footprint: \`$(human_gb "${PROTECT_BYTES}") GiB\`"
  echo "- Manual-review .RData/.rdata files: \`${REVIEW_COUNT}\`"
  echo "- Manual-review .RData/.rdata footprint: \`$(human_gb "${REVIEW_BYTES}") GiB\`"
  echo
  echo "## Target Policy"
  echo
  echo "Deleted payloads are validation fit artifacts that can be regenerated from"
  echo "the checked-in configs, source datasets, seeds, and runner scripts. The"
  echo "script intentionally preserves source-surface \`sim_output.rds\` files,"
  echo "package \`.rda\` files, summaries, reports, figures, manifests, and logs."
  echo
  echo "## Manifests"
  echo
  echo "- \`payload_files_to_delete.tsv\`"
  echo "- \`protected_binary_inventory.tsv\`"
  echo "- \`manual_review_binary_inventory.tsv\`"
  echo "- \`filesystem_before.txt\`"
  echo "- \`filesystem_after.txt\`"
  echo "- \`git_status_before.txt\`"
  echo "- \`tmux_status_before.txt\`"
  echo "- \`qdesn_process_status_before.txt\`"
} > "${SUMMARY_MD}"

cat "${SUMMARY_MD}"

if [[ "${RUN_MODE}" == "execute" ]] && [[ "${EXECUTION_BLOCKED}" == "true" ]]; then
  exit 2
fi

#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  scripts/cleanup_qdesn_pre_p90_validation_outputs.sh [--execute] [--run-label LABEL] [--keep-validation-dir NAME] [--allow-live-sessions]

Purpose:
  Prepare or execute a cleanup of legacy qdesn validation-study result trees created
  before the current p90 steeper-trend relaunch.

Defaults:
  - Dry run only. No files are deleted unless --execute is supplied.
  - Protects the current relaunch validation tree:
      dynamic_exdqlm_crossstudy_p90_steepertrend_validation
  - Protects all *_sources directories under results/qdesn_mcmc_validation
  - Protects tracked package data under data/*.rda

Safety:
  - In execute mode, the script refuses to delete anything while live qdesn tmux
    sessions exist unless --allow-live-sessions is supplied.

Outputs:
  reports/qdesn_mcmc_validation/storage_cleanup/<run-label>/
EOF
}

RUN_MODE="dry_run"
RUN_LABEL=""
KEEP_VALIDATION_DIR="dynamic_exdqlm_crossstudy_p90_steepertrend_validation"
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
    --keep-validation-dir)
      KEEP_VALIDATION_DIR="${2:-}"
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
  RUN_LABEL="qdesn_pre_p90_validation_output_cleanup_$(date +%Y%m%d-%H%M%S)"
fi

OUT_DIR="${REPO_ROOT}/reports/qdesn_mcmc_validation/storage_cleanup/${RUN_LABEL}"
mkdir -p "${OUT_DIR}"

DELETE_MANIFEST="${OUT_DIR}/validation_dirs_to_delete.tsv"
PROTECT_MANIFEST="${OUT_DIR}/protected_paths.tsv"
PACKAGE_RDA_MANIFEST="${OUT_DIR}/package_rda_inventory.tsv"
TARGETED_RDA_MANIFEST="${OUT_DIR}/targeted_rda_inventory.tsv"
TOP_BINARY_MANIFEST="${OUT_DIR}/target_binary_inventory_top200.tsv"
SUMMARY_MD="${OUT_DIR}/cleanup_summary.md"
FILESYSTEM_BEFORE="${OUT_DIR}/filesystem_before.txt"
FILESYSTEM_AFTER="${OUT_DIR}/filesystem_after.txt"
GIT_STATUS="${OUT_DIR}/git_status_before.txt"
TMUX_STATUS="${OUT_DIR}/tmux_status_before.txt"
RUN_META="${OUT_DIR}/run_metadata.txt"

human_gb() {
  awk -v bytes="$1" 'BEGIN { printf "%.2f", bytes/1024/1024/1024 }'
}

capture_state() {
  local target="$1"
  {
    echo "timestamp=$(date --iso-8601=seconds)"
    echo "pwd=${REPO_ROOT}"
    echo "git_head=$(git rev-parse HEAD)"
    echo "git_branch=$(git rev-parse --abbrev-ref HEAD)"
    echo "mode=${RUN_MODE}"
    echo "run_label=${RUN_LABEL}"
    echo "keep_validation_dir=${KEEP_VALIDATION_DIR}"
    echo "allow_live_sessions=${ALLOW_LIVE_SESSIONS}"
  } > "${RUN_META}"

  df -h /home / > "${target}"
  printf '\n--- du -sh results/qdesn_mcmc_validation/* ---\n' >> "${target}"
  du -sh results/qdesn_mcmc_validation/* 2>/dev/null | sort -hr >> "${target}" || true
}

capture_state "${FILESYSTEM_BEFORE}"
git status --short > "${GIT_STATUS}"
tmux ls > "${TMUX_STATUS}" 2>&1 || true

FREE_BEFORE_BYTES="$(df -B1 /home | awk 'NR==2 {print $4}')"

printf "path\tbytes\tgb\n" > "${PACKAGE_RDA_MANIFEST}"
PACKAGE_RDA_COUNT=0
while IFS= read -r path; do
  [[ -n "${path}" ]] || continue
  bytes="$(stat -c '%s' "${path}")"
  printf "%s\t%s\t%s\n" "${path}" "${bytes}" "$(human_gb "${bytes}")" >> "${PACKAGE_RDA_MANIFEST}"
  PACKAGE_RDA_COUNT=$((PACKAGE_RDA_COUNT + 1))
done < <(find data -maxdepth 1 -type f -name '*.rda' | sort)

printf "path\tbytes\tgb\n" > "${TARGETED_RDA_MANIFEST}"
TARGETED_RDA_COUNT=0
while IFS= read -r path; do
  [[ -n "${path}" ]] || continue
  bytes="$(stat -c '%s' "${path}")"
  printf "%s\t%s\t%s\n" "${path}" "${bytes}" "$(human_gb "${bytes}")" >> "${TARGETED_RDA_MANIFEST}"
  TARGETED_RDA_COUNT=$((TARGETED_RDA_COUNT + 1))
done < <(
  find results/qdesn_mcmc_validation \
    -path "results/qdesn_mcmc_validation/${KEEP_VALIDATION_DIR}" -prune -o \
    -path 'results/qdesn_mcmc_validation/*_sources' -prune -o \
    -type f \( -name '*.rda' -o -name '*.RData' \) -print | sort
)

mapfile -t ALL_VALIDATION_DIRS < <(
  find results/qdesn_mcmc_validation -mindepth 1 -maxdepth 1 -type d -name '*_validation' -printf '%P\n' | sort
)

mapfile -t SOURCE_DIRS < <(
  find results/qdesn_mcmc_validation -mindepth 1 -maxdepth 1 -type d -name '*_sources' -printf '%P\n' | sort
)

printf "path\tkind\tbytes\tgb\n" > "${PROTECT_MANIFEST}"
PROTECT_COUNT=0
PROTECT_BYTES=0

protect_path() {
  local rel_path="$1"
  local kind="$2"
  local abs_path="results/qdesn_mcmc_validation/${rel_path}"
  [[ -d "${abs_path}" ]] || return 0
  local bytes
  bytes="$(du -sB1 "${abs_path}" | awk '{print $1}')"
  printf "%s\t%s\t%s\t%s\n" "${abs_path}" "${kind}" "${bytes}" "$(human_gb "${bytes}")" >> "${PROTECT_MANIFEST}"
  PROTECT_COUNT=$((PROTECT_COUNT + 1))
  PROTECT_BYTES=$((PROTECT_BYTES + bytes))
}

protect_path "${KEEP_VALIDATION_DIR}" "current_validation"
for rel_dir in "${SOURCE_DIRS[@]}"; do
  protect_path "${rel_dir}" "source_surface"
done

printf "path\tbytes\tgb\n" > "${DELETE_MANIFEST}"
DELETE_COUNT=0
DELETE_BYTES=0

for rel_dir in "${ALL_VALIDATION_DIRS[@]}"; do
  if [[ "${rel_dir}" == "${KEEP_VALIDATION_DIR}" ]]; then
    continue
  fi

  abs_path="results/qdesn_mcmc_validation/${rel_dir}"
  bytes="$(du -sB1 "${abs_path}" | awk '{print $1}')"
  printf "%s\t%s\t%s\n" "${abs_path}" "${bytes}" "$(human_gb "${bytes}")" >> "${DELETE_MANIFEST}"
  DELETE_COUNT=$((DELETE_COUNT + 1))
  DELETE_BYTES=$((DELETE_BYTES + bytes))
done

find results/qdesn_mcmc_validation \
  -path "results/qdesn_mcmc_validation/${KEEP_VALIDATION_DIR}" -prune -o \
  -path 'results/qdesn_mcmc_validation/*_sources' -prune -o \
  -type f \( -name '*.rds' -o -name '*.rda' -o -name '*.RData' \) -printf '%s\t%p\n' \
  | sort -nr | sed -n '1,200p' > "${TOP_BINARY_MANIFEST}" || true

TOP_BINARY_COUNT="$(wc -l < "${TOP_BINARY_MANIFEST}" | tr -d ' ')"
TOP_BINARY_BYTES="$(
  awk -F '\t' '{sum += $1} END {print sum + 0}' "${TOP_BINARY_MANIFEST}"
)"

LIVE_QDESN_SESSIONS="$(
  awk -F: '/^qdesn_/ {print $1}' "${TMUX_STATUS}" 2>/dev/null || true
)"

EXECUTION_BLOCKED="false"
BLOCK_REASON=""

if [[ "${RUN_MODE}" == "execute" ]] && [[ "${ALLOW_LIVE_SESSIONS}" != "true" ]] && [[ -n "${LIVE_QDESN_SESSIONS}" ]]; then
  EXECUTION_BLOCKED="true"
  BLOCK_REASON="Live qdesn tmux sessions detected. Re-run without live sessions or explicitly pass --allow-live-sessions."
fi

if [[ "${RUN_MODE}" == "execute" ]] && [[ "${TARGETED_RDA_COUNT}" -gt 0 ]]; then
  EXECUTION_BLOCKED="true"
  BLOCK_REASON="Targeted delete surface contains .rda/.RData files. This cleanup script never deletes .rda/.RData outputs."
fi

if [[ "${RUN_MODE}" == "execute" ]] && [[ "${EXECUTION_BLOCKED}" != "true" ]]; then
  while IFS=$'\t' read -r rel_path _ _; do
    [[ "${rel_path}" == "path" ]] && continue
    rm -rf "${rel_path}"
  done < "${DELETE_MANIFEST}"
fi

capture_state "${FILESYSTEM_AFTER}"
FREE_AFTER_BYTES="$(df -B1 /home | awk 'NR==2 {print $4}')"
FREE_DELTA_BYTES=$((FREE_AFTER_BYTES - FREE_BEFORE_BYTES))

{
  echo "# QDESN Pre-p90 Validation Output Cleanup"
  echo
  echo "- Run label: \`${RUN_LABEL}\`"
  echo "- Requested mode: \`${RUN_MODE}\`"
  echo "- Effective execution blocked: \`${EXECUTION_BLOCKED}\`"
  if [[ -n "${BLOCK_REASON}" ]]; then
    echo "- Block reason: ${BLOCK_REASON}"
  fi
  echo "- Protected current validation dir: \`results/qdesn_mcmc_validation/${KEEP_VALIDATION_DIR}\`"
  echo "- Protected source dirs: \`${#SOURCE_DIRS[@]}\`"
  echo "- Tracked package data \`.rda\` files: \`${PACKAGE_RDA_COUNT}\`"
  echo "- Generated validation \`.rda/.RData\` files outside protected surfaces: \`${TARGETED_RDA_COUNT}\`"
  echo "- Legacy validation dirs targeted for full deletion: \`${DELETE_COUNT}\`"
  echo "- Targeted delete footprint: \`$(human_gb "${DELETE_BYTES}") GB\`"
  echo "- Top-200 targeted binary files inventoried: \`${TOP_BINARY_COUNT}\`"
  echo "- Footprint of top-200 targeted binary files: \`$(human_gb "${TOP_BINARY_BYTES}") GB\`"
  echo "- Protected footprint: \`$(human_gb "${PROTECT_BYTES}") GB\`"
  echo "- Free space before cleanup: \`$(human_gb "${FREE_BEFORE_BYTES}") GB\`"
  echo "- Free space after cleanup: \`$(human_gb "${FREE_AFTER_BYTES}") GB\`"
  echo "- Observed free-space gain: \`$(human_gb "${FREE_DELTA_BYTES}") GB\`"
  echo
  echo "Artifacts:"
  echo "- [validation_dirs_to_delete.tsv](${DELETE_MANIFEST#${REPO_ROOT}/})"
  echo "- [protected_paths.tsv](${PROTECT_MANIFEST#${REPO_ROOT}/})"
  echo "- [package_rda_inventory.tsv](${PACKAGE_RDA_MANIFEST#${REPO_ROOT}/})"
  echo "- [targeted_rda_inventory.tsv](${TARGETED_RDA_MANIFEST#${REPO_ROOT}/})"
  echo "- [target_binary_inventory_top200.tsv](${TOP_BINARY_MANIFEST#${REPO_ROOT}/})"
  echo "- [filesystem_before.txt](${FILESYSTEM_BEFORE#${REPO_ROOT}/})"
  echo "- [filesystem_after.txt](${FILESYSTEM_AFTER#${REPO_ROOT}/})"
  echo "- [git_status_before.txt](${GIT_STATUS#${REPO_ROOT}/})"
  echo "- [tmux_status_before.txt](${TMUX_STATUS#${REPO_ROOT}/})"
  echo
  echo "Interpretation:"
  echo "- There are no generated validation-study \`.rda\` outputs to purge in this repo tree right now."
  echo "- The space-heavy legacy launch outputs are stored primarily as \`.rds\` binaries inside old \`*_validation\` result trees."
  echo "- Even in execute mode, this script refuses to delete any targeted \`.rda/.RData\` file."
  echo "- This workflow is therefore aimed at old validation result trees and binary \`.rds\` outputs, not package data."
  echo
  if [[ "${RUN_MODE}" == "execute" ]] && [[ "${EXECUTION_BLOCKED}" != "true" ]]; then
    echo "Execution result: cleanup was executed."
  elif [[ "${RUN_MODE}" == "execute" ]] && [[ "${EXECUTION_BLOCKED}" == "true" ]]; then
    echo "Execution result: execute mode was blocked; no files were deleted."
  else
    echo "Execution result: dry run only. No files were deleted."
  fi
} > "${SUMMARY_MD}"

echo "Wrote cleanup artifacts to ${OUT_DIR}"

if [[ "${RUN_MODE}" == "execute" ]] && [[ "${EXECUTION_BLOCKED}" == "true" ]]; then
  exit 2
fi

#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  scripts/cleanup_qdesn_validation_storage.sh [--execute] [--run-label LABEL]

Modes:
  default     Dry run. Materializes cleanup manifests without deleting anything.
  --execute   Execute the documented cleanup.

Outputs:
  reports/qdesn_mcmc_validation/storage_cleanup/<run-label>/
EOF
}

RUN_MODE="dry_run"
RUN_LABEL=""

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
  RUN_LABEL="qdesn_validation_storage_cleanup_$(date +%Y%m%d-%H%M%S)"
fi

OUT_DIR="${REPO_ROOT}/reports/qdesn_mcmc_validation/storage_cleanup/${RUN_LABEL}"
mkdir -p "${OUT_DIR}"

DELETE_DIRS=(
  "results/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_effective_w300_fail_closure_wave"
  "results/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_effective_w300_final_residual_wave"
  "results/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_fail_closure_wave"
  "results/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_final_residual_wave"
  "results/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_normalized_multiseed_validation"
  "results/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_rhs_long_mcmc_wave"
  "results/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_rowfaithful_multiseed_validation"
  "results/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_validation"
  "results/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_effective_w300_postdraw_validation"
  "results/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_final_fail_closure_wave"
  "results/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_fit_fail_closure_wave"
  "results/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_residual_fail_closure_wave"
  "results/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_validation"
)

PRUNE_DIRS=(
  "results/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_tau050_refreshed_main_validation"
  "results/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_v2_validation"
  "results/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_v3_matrix_validation"
)

DELETE_MANIFEST="${OUT_DIR}/directories_to_delete.tsv"
PRUNE_MANIFEST="${OUT_DIR}/forecast_objects_to_prune.tsv"
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
  } > "${RUN_META}"

  df -h /home / > "${target}"
  printf '\n--- du -sh results/qdesn_mcmc_validation/* ---\n' >> "${target}"
  du -sh results/qdesn_mcmc_validation/* 2>/dev/null | sort -hr >> "${target}" || true
}

capture_state "${FILESYSTEM_BEFORE}"
git status --short > "${GIT_STATUS}"
tmux ls > "${TMUX_STATUS}" 2>&1 || true

FREE_BEFORE_BYTES="$(df -B1 /home | awk 'NR==2 {print $4}')"

printf "path\tbytes\tgb\n" > "${DELETE_MANIFEST}"
DELETE_BYTES=0
DELETE_COUNT=0
for rel_path in "${DELETE_DIRS[@]}"; do
  if [[ -d "${rel_path}" ]]; then
    bytes="$(du -sB1 "${rel_path}" | awk '{print $1}')"
    printf "%s\t%s\t%s\n" "${rel_path}" "${bytes}" "$(human_gb "${bytes}")" >> "${DELETE_MANIFEST}"
    DELETE_BYTES=$((DELETE_BYTES + bytes))
    DELETE_COUNT=$((DELETE_COUNT + 1))
  fi
done

printf "path\tbytes\tgb\n" > "${PRUNE_MANIFEST}"
PRUNE_BYTES=0
PRUNE_COUNT=0
while IFS=$'\t' read -r bytes rel_path; do
  [[ -n "${rel_path}" ]] || continue
  printf "%s\t%s\t%s\n" "${rel_path}" "${bytes}" "$(human_gb "${bytes}")" >> "${PRUNE_MANIFEST}"
  PRUNE_BYTES=$((PRUNE_BYTES + bytes))
  PRUNE_COUNT=$((PRUNE_COUNT + 1))
done < <(
  find "${PRUNE_DIRS[@]}" -type f -name 'forecast_objects.rds' -printf '%s\t%p\n' 2>/dev/null | sort -nr
)

TOTAL_BYTES=$((DELETE_BYTES + PRUNE_BYTES))

if [[ "${RUN_MODE}" == "execute" ]]; then
  while IFS=$'\t' read -r rel_path _ _; do
    [[ "${rel_path}" == "path" ]] && continue
    rm -rf "${rel_path}"
  done < "${DELETE_MANIFEST}"

  while IFS=$'\t' read -r rel_path _ _; do
    [[ "${rel_path}" == "path" ]] && continue
    rm -f "${rel_path}"
  done < "${PRUNE_MANIFEST}"
fi

capture_state "${FILESYSTEM_AFTER}"
FREE_AFTER_BYTES="$(df -B1 /home | awk 'NR==2 {print $4}')"
FREE_DELTA_BYTES=$((FREE_AFTER_BYTES - FREE_BEFORE_BYTES))

{
  echo "# QDESN Validation Storage Cleanup"
  echo
  echo "- Run label: \`${RUN_LABEL}\`"
  echo "- Mode: \`${RUN_MODE}\`"
  echo "- Repo: \`${REPO_ROOT}\`"
  echo "- Git head: \`$(git rev-parse HEAD)\`"
  echo "- Directory trees targeted for full deletion: \`${DELETE_COUNT}\`"
  echo "- Full-delete footprint: \`$(human_gb "${DELETE_BYTES}") GB\`"
  echo "- Large forecast object files targeted for pruning: \`${PRUNE_COUNT}\`"
  echo "- Forecast-object pruning footprint: \`$(human_gb "${PRUNE_BYTES}") GB\`"
  echo "- Total targeted footprint: \`$(human_gb "${TOTAL_BYTES}") GB\`"
  echo "- Free space before cleanup: \`$(human_gb "${FREE_BEFORE_BYTES}") GB\`"
  echo "- Free space after cleanup: \`$(human_gb "${FREE_AFTER_BYTES}") GB\`"
  echo "- Observed free-space gain: \`$(human_gb "${FREE_DELTA_BYTES}") GB\`"
  echo
  echo "Artifacts:"
  echo "- [directories_to_delete.tsv](${DELETE_MANIFEST#${REPO_ROOT}/})"
  echo "- [forecast_objects_to_prune.tsv](${PRUNE_MANIFEST#${REPO_ROOT}/})"
  echo "- [filesystem_before.txt](${FILESYSTEM_BEFORE#${REPO_ROOT}/})"
  echo "- [filesystem_after.txt](${FILESYSTEM_AFTER#${REPO_ROOT}/})"
  echo "- [git_status_before.txt](${GIT_STATUS#${REPO_ROOT}/})"
  echo "- [tmux_status_before.txt](${TMUX_STATUS#${REPO_ROOT}/})"
  echo
  if [[ "${RUN_MODE}" == "execute" ]]; then
    echo "Execution result: cleanup was executed."
  else
    echo "Execution result: dry run only. No files were deleted."
  fi
} > "${SUMMARY_MD}"

echo "Wrote cleanup artifacts to ${OUT_DIR}"

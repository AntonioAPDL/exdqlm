#!/usr/bin/env bash
set -euo pipefail

action="${1:-help}"
if [[ $# -gt 0 ]]; then
  shift
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/../.." && pwd)"

export REFRESHED288_RUN_TAG="${REFRESHED288_RUN_TAG:-20260507_p90_dynamic72_qdesn_comparable_fresh_v1}"
export REFRESHED288_VARIANT_TAG="${REFRESHED288_VARIANT_TAG:-p90_dynamic72_qdesn_comparable_fresh_v1}"
export REFRESHED288_RETENTION_MODE="${REFRESHED288_RETENTION_MODE:-comparison_plus_plot}"
export REFRESHED288_DYNAMIC_USE_FULL_ROOT="${REFRESHED288_DYNAMIC_USE_FULL_ROOT:-false}"
export REFRESHED288_WRITE_PREDICTIVE_QUANTILE_GRID="${REFRESHED288_WRITE_PREDICTIVE_QUANTILE_GRID:-false}"
export REFRESHED288_PATH_REWRITE_FROM="${REFRESHED288_PATH_REWRITE_FROM:-/home/jaguir26/local/src}"
export REFRESHED288_PATH_REWRITE_TO="${REFRESHED288_PATH_REWRITE_TO:-/data/jaguir26/local/src}"

export R_LIBS_USER="${R_LIBS_USER:-/data/jaguir26/R/local_libs}"
export OMP_NUM_THREADS="${OMP_NUM_THREADS:-1}"
export OPENBLAS_NUM_THREADS="${OPENBLAS_NUM_THREADS:-1}"
export MKL_NUM_THREADS="${MKL_NUM_THREADS:-1}"

export SMOKE_DYNAMIC_VB_WORKERS="${SMOKE_DYNAMIC_VB_WORKERS:-12}"
export SMOKE_DYNAMIC_MCMC_WORKERS="${SMOKE_DYNAMIC_MCMC_WORKERS:-4}"
export FULL_DYNAMIC_VB_WORKERS="${FULL_DYNAMIC_VB_WORKERS:-16}"
export FULL_DYNAMIC_MCMC_WORKERS="${FULL_DYNAMIC_MCMC_WORKERS:-4}"

run_root="$repo_root/tools/merge_reports/full288_refreshed288_${REFRESHED288_RUN_TAG//[^A-Za-z0-9_-]/_}"
fresh_registry="$repo_root/tools/merge_reports/LOCAL_refreshed288_dataset_registry_${REFRESHED288_RUN_TAG//[^A-Za-z0-9_-]/_}.csv"
fresh_full_manifest="$repo_root/tools/merge_reports/LOCAL_refreshed288_full_manifest_${REFRESHED288_RUN_TAG//[^A-Za-z0-9_-]/_}.csv"
fresh_micro_manifest="$repo_root/tools/merge_reports/LOCAL_refreshed288_micro_smoke_manifest_${REFRESHED288_RUN_TAG//[^A-Za-z0-9_-]/_}.csv"
report_dir="$repo_root/reports/static_exal_tuning_20260507"
qdesn_source_root="/data/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/results/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_p90_steepertrend_main_sources/dlm_constV_p90_m0amp_highnoise_steepertrend_v1"
delegate="$script_dir/LOCAL_refreshed288_launch_20260429_dynamic72_qdesn_comparable_v1.sh"
run_row_script="$script_dir/LOCAL_refreshed288_run_row_20260422_p90_full288.R"
evaluate_script="$script_dir/LOCAL_refreshed288_evaluate_20260422_p90_full288.R"
report_script="$script_dir/LOCAL_refreshed288_report_20260422_p90_full288.R"
stage_manifest_script="$script_dir/LOCAL_refreshed288_stage_manifest_20260508.R"
micro_smoke_workers="${MICRO_SMOKE_WORKERS:-2}"
stage_dynamic_vb_workers="${STAGE_DYNAMIC_VB_WORKERS:-4}"
stage_mcmc_tt500_workers="${STAGE_MCMC_TT500_WORKERS:-2}"
stage_mcmc_tt5000_workers="${STAGE_MCMC_TT5000_WORKERS:-1}"

require_fresh_prepare_ok() {
  if [[ -e "$run_root" && "${REFRESHED288_ALLOW_PREPARE_OVERWRITE:-false}" != "true" ]]; then
    cat >&2 <<EOF
Refusing to prepare because the fresh run root already exists:
  $run_root

Set REFRESHED288_ALLOW_PREPARE_OVERWRITE=true only after manually reviewing the
existing run root and deciding it is safe for the prepare script to recreate it.
EOF
    exit 1
  fi
}

require_launch_approval() {
  if [[ "${REFRESHED288_LAUNCH_APPROVED:-false}" != "true" ]]; then
    cat >&2 <<EOF
Refusing to launch compute for action '$action'.

This fresh dynamic72 wrapper requires explicit approval:
  export REFRESHED288_LAUNCH_APPROVED=true

Run preflight/source-inventory/verify/storage checks first and only set this
after the relaunch is approved.
EOF
    exit 1
  fi
}

write_micro_smoke_manifest() {
  (cd "$repo_root" && Rscript "$script_dir/LOCAL_refreshed288_micro_smoke_manifest_20260507.R" \
    --run-tag="$REFRESHED288_RUN_TAG" \
    --manifest="$fresh_full_manifest" \
    --out="$fresh_micro_manifest")
}

micro_smoke_row_ids() {
  write_micro_smoke_manifest >/dev/null
  (cd "$repo_root" && Rscript -e "m <- read.csv('$fresh_micro_manifest', stringsAsFactors = FALSE, check.names = FALSE); cat(m\$row_id, sep = '\n')")
}

micro_smoke_row_ids_for_inference() {
  local inference="$1"
  write_micro_smoke_manifest >/dev/null
  (cd "$repo_root" && Rscript -e "m <- read.csv('$fresh_micro_manifest', stringsAsFactors = FALSE, check.names = FALSE); m <- m[m\$inference == '$inference', , drop = FALSE]; cat(m\$row_id, sep = '\n')")
}

evaluate_full_manifest() {
  (cd "$repo_root" && Rscript "$evaluate_script" --manifest="$fresh_full_manifest")
  (cd "$repo_root" && Rscript "$report_script" --manifest="$fresh_full_manifest")
}

stage_manifest_path() {
  local stage="$1"
  printf '%s\n' "$repo_root/tools/merge_reports/LOCAL_refreshed288_stage_${stage}_manifest_${REFRESHED288_RUN_TAG//[^A-Za-z0-9_-]/_}.csv"
}

write_stage_manifest() {
  local stage="$1"
  (cd "$repo_root" && Rscript "$stage_manifest_script" \
    --run-tag="$REFRESHED288_RUN_TAG" \
    --stage="$stage" \
    --manifest="$fresh_full_manifest" \
    --out="$(stage_manifest_path "$stage")")
}

stage_row_ids() {
  local stage="$1"
  write_stage_manifest "$stage" >/dev/null
  local stage_manifest
  stage_manifest="$(stage_manifest_path "$stage")"
  (cd "$repo_root" && Rscript -e "m <- read.csv('$stage_manifest', stringsAsFactors = FALSE, check.names = FALSE); if (nrow(m)) cat(m\$row_id, sep = '\n')")
}

print_stage_plan() {
  local stage="$1"
  write_stage_manifest "$stage"
  local stage_manifest
  stage_manifest="$(stage_manifest_path "$stage")"
  (cd "$repo_root" && Rscript -e "m <- read.csv('$stage_manifest', stringsAsFactors = FALSE, check.names = FALSE); cols <- intersect(c('row_id','phase','family','tau_label','fit_size','model','inference','row_status_current','retention_mode'), names(m)); if (nrow(m)) print(m[, cols, drop = FALSE], row.names = FALSE) else cat('No pending rows for stage: $stage\n')")
}

run_stage() {
  local stage="$1"
  local workers="$2"
  require_launch_approval
  evaluate_full_manifest
  mapfile -t row_ids < <(stage_row_ids "$stage")
  if [[ "${#row_ids[@]}" -eq 0 ]]; then
    echo "stage=$stage pending_rows=0"
    return 0
  fi
  echo "stage=$stage workers=$workers rows=${#row_ids[@]}"
  printf '%s\n' "${row_ids[@]}" | xargs -P "$workers" -I{} bash -lc "cd '$repo_root' && Rscript '$run_row_script' --manifest='$fresh_full_manifest' --row_id={}"
  evaluate_full_manifest
}

case "$action" in
  stage-dynamic-vb-plan)
    print_stage_plan dynamic-vb
    ;;
  stage-mcmc-tt500-plan)
    print_stage_plan mcmc-tt500
    ;;
  stage-mcmc-tt5000-plan)
    print_stage_plan mcmc-tt5000
    ;;
  stage-dynamic-vb-dry-run)
    write_stage_manifest dynamic-vb
    (cd "$repo_root" && Rscript -e "m <- read.csv('$(stage_manifest_path dynamic-vb)', stringsAsFactors = FALSE, check.names = FALSE); cat(sprintf('Rscript %s --manifest=%s --row_id=%s\n', '$run_row_script', '$fresh_full_manifest', m\$row_id), sep = '')")
    ;;
  stage-mcmc-tt500-dry-run)
    write_stage_manifest mcmc-tt500
    (cd "$repo_root" && Rscript -e "m <- read.csv('$(stage_manifest_path mcmc-tt500)', stringsAsFactors = FALSE, check.names = FALSE); cat(sprintf('Rscript %s --manifest=%s --row_id=%s\n', '$run_row_script', '$fresh_full_manifest', m\$row_id), sep = '')")
    ;;
  stage-mcmc-tt5000-dry-run)
    write_stage_manifest mcmc-tt5000
    (cd "$repo_root" && Rscript -e "m <- read.csv('$(stage_manifest_path mcmc-tt5000)', stringsAsFactors = FALSE, check.names = FALSE); cat(sprintf('Rscript %s --manifest=%s --row_id=%s\n', '$run_row_script', '$fresh_full_manifest', m\$row_id), sep = '')")
    ;;
  stage-dynamic-vb)
    run_stage dynamic-vb "$stage_dynamic_vb_workers"
    ;;
  stage-mcmc-tt500)
    run_stage mcmc-tt500 "$stage_mcmc_tt500_workers"
    ;;
  stage-mcmc-tt5000)
    run_stage mcmc-tt5000 "$stage_mcmc_tt5000_workers"
    ;;
  micro-smoke-plan)
    write_micro_smoke_manifest
    (cd "$repo_root" && Rscript -e "m <- read.csv('$fresh_micro_manifest', stringsAsFactors = FALSE, check.names = FALSE); print(m[, c('row_id','phase','family','tau_label','fit_size','model','inference','retention_mode')], row.names = FALSE)")
    ;;
  micro-smoke-dry-run)
    write_micro_smoke_manifest
    (cd "$repo_root" && Rscript -e "m <- read.csv('$fresh_micro_manifest', stringsAsFactors = FALSE, check.names = FALSE); cat(sprintf('Rscript %s --manifest=%s --row_id=%s\n', '$run_row_script', '$fresh_full_manifest', m\$row_id), sep = '')")
    ;;
  micro-smoke)
    require_launch_approval
    write_micro_smoke_manifest
    evaluate_full_manifest
    for inference in vb mcmc; do
      mapfile -t row_ids < <(micro_smoke_row_ids_for_inference "$inference")
      if [[ "${#row_ids[@]}" -gt 0 ]]; then
        echo "micro_smoke_inference=$inference workers=$micro_smoke_workers rows=${#row_ids[@]}"
        printf '%s\n' "${row_ids[@]}" | xargs -P "$micro_smoke_workers" -I{} bash -lc "cd '$repo_root' && Rscript '$run_row_script' --manifest='$fresh_full_manifest' --row_id={}"
        evaluate_full_manifest
      fi
    done
    evaluate_full_manifest
    ;;
  source-inventory)
    (cd "$repo_root" && Rscript "$script_dir/LOCAL_refreshed288_dynamic72_source_inventory_20260507.R" \
      --run-tag="$REFRESHED288_RUN_TAG" \
      --registry="${fresh_registry}" \
      --fallback-registry="$repo_root/tools/merge_reports/LOCAL_refreshed288_dataset_registry_20260429_p90_dynamic72_qdesn_comparable_v2_timeorigin.csv" \
      --qdesn-source-root="$qdesn_source_root" \
      --report-dir="$report_dir" \
      "$@")
    ;;
  preflight)
    (cd "$repo_root" && Rscript "$script_dir/LOCAL_refreshed288_prelaunch_guard_20260507.R" \
      --run-tag="$REFRESHED288_RUN_TAG" \
      --registry="$fresh_registry" \
      --manifest="$fresh_full_manifest" \
      --require-manifest=false \
      "$@")
    ;;
  prepare)
    require_fresh_prepare_ok
    "$delegate" prepare "$@"
    ;;
  verify-windows)
    (cd "$repo_root" && Rscript "$script_dir/LOCAL_refreshed288_verify_qdesn_dynamic_windows_20260429.R" \
      --repo-root="$repo_root" \
      --run-tag="$REFRESHED288_RUN_TAG" \
      --registry="$fresh_registry" \
      --qdesn-source-root="$qdesn_source_root" \
      --report-dir="$report_dir" \
      "$@")
    ;;
  verify-time-origin)
    (cd "$repo_root" && Rscript "$script_dir/LOCAL_refreshed288_verify_dynamic_time_origin_20260429.R" \
      --repo-root="$repo_root" \
      --run-tag="$REFRESHED288_RUN_TAG" \
      --registry="$fresh_registry" \
      --report-dir="$report_dir" \
      "$@")
    ;;
  storage-audit)
    (cd "$repo_root" && Rscript "$script_dir/LOCAL_refreshed288_storage_audit_20260507.R" \
      --run-tag="$REFRESHED288_RUN_TAG" \
      --run-root="$run_root" \
      --report-dir="$report_dir" \
      "$@")
    ;;
  shared-interface)
    (cd "$repo_root" && Rscript "$script_dir/LOCAL_refreshed288_shared_interface_20260507.R" \
      --run-tag="$REFRESHED288_RUN_TAG" \
      --manifest="$fresh_full_manifest" \
      "$@")
    ;;
  smoke|full)
    require_launch_approval
    "$delegate" "$action" "$@"
    ;;
  health-smoke|health-full)
    "$delegate" "$action" "$@"
    ;;
  help|--help|-h)
    cat <<EOF
Usage: $(basename "$0") <action>

Prelaunch/support actions:
  micro-smoke-plan    Write/print the 8-row high-risk Laplace micro-smoke manifest.
  micro-smoke-dry-run Print row commands for the 8-row micro-smoke, without compute.
  source-inventory    Build the 18-row shared source-window inventory.
  preflight           Check path, manifest, retention, and stale-root guards.
  prepare             Prepare fresh manifests/configs, guarded against overwrite.
  verify-windows      Compare exDQLM canonical windows to Q-DESN staged tails.
  verify-time-origin  Verify source-index time-origin alignment.
  storage-audit       Audit compact retention and retained binary payloads.
  shared-interface    Export the comparison-ready shared interface table.
  stage-dynamic-vb-plan       Pending dynamic VB rows, excluding completed rows.
  stage-mcmc-tt500-plan       Pending dynamic MCMC TT500 rows, excluding completed rows.
  stage-mcmc-tt5000-plan      Pending dynamic MCMC TT5000 rows, excluding completed rows.
  stage-dynamic-vb-dry-run    Print dynamic VB row commands, without compute.
  stage-mcmc-tt500-dry-run    Print dynamic MCMC TT500 row commands, without compute.
  stage-mcmc-tt5000-dry-run   Print dynamic MCMC TT5000 row commands, without compute.

Launch actions, still requiring explicit human approval:
  micro-smoke
  stage-dynamic-vb
  stage-mcmc-tt500
  stage-mcmc-tt5000
  smoke
  full
  health-smoke
  health-full

Fresh run tag:
  $REFRESHED288_RUN_TAG
EOF
    ;;
  *)
    echo "Unknown action: $action" >&2
    "$0" help >&2
    exit 1
    ;;
esac

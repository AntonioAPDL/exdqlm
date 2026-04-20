#!/usr/bin/env bash
set -euo pipefail

action="launch-confirm"
if [[ $# -gt 0 && "${1#--}" == "$1" ]]; then
  action="$1"
  shift
fi

dry_run=0
prepare_first=1
force_flag=()
workers_confirm=1
workers_spread=2
run_tag_override=""
variant_tag_override=""
source_run_tag="20260417_canonical_v1"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      dry_run=1
      ;;
    --no-prepare)
      prepare_first=0
      ;;
    --force)
      force_flag=(--force)
      ;;
    --workers-confirm=*)
      workers_confirm="${1#*=}"
      ;;
    --workers-spread=*)
      workers_spread="${1#*=}"
      ;;
    --run-tag=*)
      run_tag_override="${1#*=}"
      ;;
    --variant-tag=*)
      variant_tag_override="${1#*=}"
      ;;
    --source-run-tag=*)
      source_run_tag="${1#*=}"
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
  shift
done

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/../.." && pwd)"
if [[ -n "$run_tag_override" ]]; then
  export REFRESHED288_RUN_TAG="$run_tag_override"
fi
if [[ -n "$variant_tag_override" ]]; then
  export REFRESHED288_VARIANT_TAG="$variant_tag_override"
fi

resolved_tag="${REFRESHED288_RUN_TAG:-20260420_exdqlm_tt5000_recovery_v1}"
resolved_tag="${resolved_tag//[^A-Za-z0-9_-]/_}"

prepare_script="$script_dir/LOCAL_refreshed288_prepare_exdqlm_tt5000_recovery_20260420.R"
evaluate_script="$script_dir/LOCAL_refreshed288_evaluate_20260416.R"
report_script="$script_dir/LOCAL_refreshed288_refresh_comparison_20260416.R"
run_row_script="$script_dir/LOCAL_refreshed288_run_row_20260416.R"
manifest_path="$repo_root/tools/merge_reports/LOCAL_refreshed288_exdqlm_tt5000_recovery_manifest_${resolved_tag}.csv"
status_path="$repo_root/tools/merge_reports/LOCAL_refreshed288_exdqlm_tt5000_recovery_manifest_status_${resolved_tag}.csv"
phase_path="$repo_root/tools/merge_reports/LOCAL_refreshed288_exdqlm_tt5000_recovery_phase_summary_${resolved_tag}.csv"
method_path="$repo_root/tools/merge_reports/LOCAL_refreshed288_exdqlm_tt5000_recovery_method_summary_${resolved_tag}.csv"
report_path="$repo_root/reports/static_exal_tuning_${resolved_tag:0:8}/refreshed288_exdqlm_tt5000_recovery_status_${resolved_tag}.md"

run_prepare() {
  (cd "$repo_root" && Rscript "$prepare_script" --source_run_tag="$source_run_tag")
}

run_eval_and_report() {
  (cd "$repo_root" && Rscript "$evaluate_script" \
    --manifest="$manifest_path" \
    --status_out="$status_path" \
    --phase_out="$phase_path" \
    --method_out="$method_path")
  (cd "$repo_root" && Rscript "$report_script" \
    --manifest="$manifest_path" \
    --status="$status_path" \
    --phase="$phase_path" \
    --method="$method_path" \
    --report="$report_path")
}

row_ids_for_phase() {
  local phase="$1"
  (cd "$repo_root" && Rscript -e "m <- read.csv('$manifest_path', stringsAsFactors = FALSE, check.names = FALSE); x <- m\$row_id[m\$phase == '$phase']; if (length(x)) cat(x, sep = '\n')")
}

launch_phase() {
  local phase="$1"
  local workers="$2"
  mapfile -t row_ids < <(row_ids_for_phase "$phase")
  if [[ "${#row_ids[@]}" -eq 0 ]]; then
    return 0
  fi

  echo "phase=$phase workers=$workers rows=${#row_ids[@]}"
  if [[ "$dry_run" -eq 1 ]]; then
    printf 'Rscript %s --manifest=%s --row_id=<row_id> %s\n' "$run_row_script" "$manifest_path" "${force_flag[*]-}"
    return 0
  fi

  printf '%s\n' "${row_ids[@]}" | xargs -P "$workers" -I{} bash -lc "cd '$repo_root' && Rscript '$run_row_script' --manifest='$manifest_path' --row_id={} ${force_flag[*]-}"
  run_eval_and_report
}

case "$action" in
  prepare)
    run_prepare
    run_eval_and_report
    ;;
  evaluate)
    run_eval_and_report
    ;;
  dry-run)
    dry_run=1
    if [[ "$prepare_first" -eq 1 ]]; then
      run_prepare
    fi
    run_eval_and_report
    for phase in confirm_row8_arm_D confirm_row16_arm_B confirm_row16_arm_D spread_remaining_arm_D; do
      if [[ "$phase" == "spread_remaining_arm_D" ]]; then
        launch_phase "$phase" "$workers_spread"
      else
        launch_phase "$phase" "$workers_confirm"
      fi
    done
    ;;
  launch-confirm)
    if [[ "$prepare_first" -eq 1 ]]; then
      run_prepare
    fi
    run_eval_and_report
    for phase in confirm_row8_arm_D confirm_row16_arm_B confirm_row16_arm_D; do
      launch_phase "$phase" "$workers_confirm"
    done
    ;;
  launch-spread)
    if [[ "$prepare_first" -eq 1 ]]; then
      run_prepare
      run_eval_and_report
    fi
    launch_phase "spread_remaining_arm_D" "$workers_spread"
    ;;
  launch-all)
    if [[ "$prepare_first" -eq 1 ]]; then
      run_prepare
    fi
    run_eval_and_report
    for phase in confirm_row8_arm_D confirm_row16_arm_B confirm_row16_arm_D; do
      launch_phase "$phase" "$workers_confirm"
    done
    launch_phase "spread_remaining_arm_D" "$workers_spread"
    ;;
  *)
    echo "Unknown action: $action" >&2
    exit 1
    ;;
esac

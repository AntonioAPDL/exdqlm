#!/usr/bin/env bash
set -euo pipefail

action="launch"
if [[ $# -gt 0 && "${1#--}" == "$1" ]]; then
  action="$1"
  shift
fi

dry_run=0
prepare_first=1
force_flag=()
workers_runtime_vb=1
workers_runtime_mcmc=2
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
    --workers-runtime-vb=*)
      workers_runtime_vb="${1#*=}"
      ;;
    --workers-runtime-mcmc=*)
      workers_runtime_mcmc="${1#*=}"
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

resolved_tag="${REFRESHED288_RUN_TAG:-20260418_runtimefail_v1}"
resolved_tag="${resolved_tag//[^A-Za-z0-9_-]/_}"

prepare_script="$script_dir/LOCAL_refreshed288_prepare_runtime_failures_20260418.R"
evaluate_script="$script_dir/LOCAL_refreshed288_evaluate_20260416.R"
report_script="$script_dir/LOCAL_refreshed288_refresh_comparison_20260416.R"
run_row_script="$script_dir/LOCAL_refreshed288_run_row_20260416.R"
manifest_path="$repo_root/tools/merge_reports/LOCAL_refreshed288_full_manifest_${resolved_tag}.csv"
status_path="$repo_root/tools/merge_reports/LOCAL_refreshed288_runtime_failure_manifest_status_${resolved_tag}.csv"
phase_path="$repo_root/tools/merge_reports/LOCAL_refreshed288_runtime_failure_phase_summary_${resolved_tag}.csv"
method_path="$repo_root/tools/merge_reports/LOCAL_refreshed288_runtime_failure_method_summary_${resolved_tag}.csv"
report_path="$repo_root/reports/static_exal_tuning_${resolved_tag:0:8}/refreshed288_runtime_failure_status_${resolved_tag}.md"

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

worker_count_for_phase() {
  case "$1" in
    runtime_vb_primary) echo "$workers_runtime_vb" ;;
    runtime_mcmc_pilot|runtime_mcmc_full) echo "$workers_runtime_mcmc" ;;
    *) echo "1" ;;
  esac
}

row_ids_for_phase() {
  local phase="$1"
  (cd "$repo_root" && Rscript -e "m <- read.csv('$manifest_path', stringsAsFactors = FALSE, check.names = FALSE); x <- m\$row_id[m\$phase == '$phase']; if (length(x)) cat(x, sep = '\n')")
}

launch_phase() {
  local phase="$1"
  local workers
  workers="$(worker_count_for_phase "$phase")"
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
    for phase in runtime_vb_primary runtime_mcmc_pilot runtime_mcmc_full; do
      launch_phase "$phase"
    done
    ;;
  launch)
    if [[ "$prepare_first" -eq 1 ]]; then
      run_prepare
    fi
    run_eval_and_report
    for phase in runtime_vb_primary runtime_mcmc_pilot runtime_mcmc_full; do
      launch_phase "$phase"
    done
    ;;
  *)
    echo "Unknown action: $action" >&2
    exit 1
    ;;
esac

#!/usr/bin/env bash
set -euo pipefail

action="launch"
if [[ $# -gt 0 && "${1#--}" == "$1" ]]; then
  action="$1"
  shift
fi

manifest_kind="smoke"
dry_run=0
prepare_first=1
force_flag=()
workers_static_vb=8
workers_dynamic_vb=6
workers_static_mcmc=4
workers_dynamic_mcmc=3
run_tag_override=""
variant_tag_override=""
phase_filter=""
status_filter=""
outcome_filter=""
filter_mode="all"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --manifest-kind=*)
      manifest_kind="${1#*=}"
      ;;
    --manifest-kind)
      manifest_kind="$2"
      shift
      ;;
    --dry-run)
      dry_run=1
      ;;
    --no-prepare)
      prepare_first=0
      ;;
    --force)
      force_flag=(--force)
      ;;
    --workers-static-vb=*)
      workers_static_vb="${1#*=}"
      ;;
    --workers-dynamic-vb=*)
      workers_dynamic_vb="${1#*=}"
      ;;
    --workers-static-mcmc=*)
      workers_static_mcmc="${1#*=}"
      ;;
    --workers-dynamic-mcmc=*)
      workers_dynamic_mcmc="${1#*=}"
      ;;
    --run-tag=*)
      run_tag_override="${1#*=}"
      ;;
    --variant-tag=*)
      variant_tag_override="${1#*=}"
      ;;
    --phase-filter=*)
      phase_filter="${1#*=}"
      ;;
    --phase-filter)
      phase_filter="$2"
      shift
      ;;
    --status-filter=*)
      status_filter="${1#*=}"
      ;;
    --status-filter)
      status_filter="$2"
      shift
      ;;
    --outcome-filter=*)
      outcome_filter="${1#*=}"
      ;;
    --outcome-filter)
      outcome_filter="$2"
      shift
      ;;
    --filter-mode=*)
      filter_mode="${1#*=}"
      ;;
    --filter-mode)
      filter_mode="$2"
      shift
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
  shift
done

if [[ "$manifest_kind" != "smoke" && "$manifest_kind" != "full" ]]; then
  echo "manifest kind must be smoke or full" >&2
  exit 1
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/../.." && pwd)"
if [[ -n "$run_tag_override" ]]; then
  export REFRESHED288_RUN_TAG="$run_tag_override"
fi
if [[ -n "$variant_tag_override" ]]; then
  export REFRESHED288_VARIANT_TAG="$variant_tag_override"
fi
prepare_script="$script_dir/LOCAL_refreshed288_prepare_20260422_p90_full288.R"
evaluate_script="$script_dir/LOCAL_refreshed288_evaluate_20260422_p90_full288.R"
report_script="$script_dir/LOCAL_refreshed288_report_20260422_p90_full288.R"
run_row_script="$script_dir/LOCAL_refreshed288_run_row_20260422_p90_full288.R"
resolved_tag="${REFRESHED288_RUN_TAG:-20260422_p90_full288_baseline_v1}"
resolved_tag="${resolved_tag//[^A-Za-z0-9_-]/_}"
manifest_path="$repo_root/tools/merge_reports/LOCAL_refreshed288_${manifest_kind}_manifest_${resolved_tag}.csv"

run_prepare() {
  (cd "$repo_root" && Rscript "$prepare_script")
}

run_eval_and_report() {
  (cd "$repo_root" && Rscript "$evaluate_script" --manifest="$manifest_path")
  (cd "$repo_root" && Rscript "$report_script" --manifest="$manifest_path")
}

worker_count_for_phase() {
  case "$1" in
    *_static_vb) echo "$workers_static_vb" ;;
    *_dynamic_vb) echo "$workers_dynamic_vb" ;;
    *_static_mcmc) echo "$workers_static_mcmc" ;;
    *_dynamic_mcmc) echo "$workers_dynamic_mcmc" ;;
    *) echo "1" ;;
  esac
}

row_ids_for_phase() {
  local phase="$1"
  local status_arg="$status_filter"
  local outcome_arg="$outcome_filter"
  local filter_mode_arg="$filter_mode"
  (cd "$repo_root" && Rscript -e "source('tools/merge_reports/LOCAL_refreshed288_helpers_20260422_p90_full288.R'); ids <- select_row_ids_for_launch_refreshed288('$manifest_path', phase_filter = '$phase', status_filter = '$status_arg', outcome_filter = '$outcome_arg', filter_mode = '$filter_mode_arg'); if (length(ids)) cat(ids, sep = '\n')")
}

selected_phases() {
  if [[ -n "$phase_filter" ]]; then
    tr ',' '\n' <<< "$phase_filter" | sed '/^[[:space:]]*$/d'
  else
    printf '%s\n' \
      "${manifest_kind}_static_vb" \
      "${manifest_kind}_dynamic_vb" \
      "${manifest_kind}_static_mcmc" \
      "${manifest_kind}_dynamic_mcmc"
  fi
}

launch_phase() {
  local phase="$1"
  local workers
  workers="$(worker_count_for_phase "$phase")"
  mapfile -t row_ids < <(row_ids_for_phase "$phase")
  if [[ "${#row_ids[@]}" -eq 0 ]]; then
    return 0
  fi

  echo "phase=$phase workers=$workers rows=${#row_ids[@]} status_filter=${status_filter:-all} outcome_filter=${outcome_filter:-all} filter_mode=$filter_mode"
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
  report)
    (cd "$repo_root" && Rscript "$report_script" --manifest="$manifest_path")
    ;;
  dry-run)
    dry_run=1
    if [[ "$prepare_first" -eq 1 ]]; then
      run_prepare
    fi
    run_eval_and_report
    while IFS= read -r phase; do
      launch_phase "$phase"
    done < <(selected_phases)
    ;;
  launch)
    if [[ "$prepare_first" -eq 1 ]]; then
      run_prepare
    fi
    run_eval_and_report
    while IFS= read -r phase; do
      launch_phase "$phase"
    done < <(selected_phases)
    ;;
  *)
    echo "Unknown action: $action" >&2
    exit 1
    ;;
esac

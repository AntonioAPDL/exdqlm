#!/usr/bin/env bash
set -euo pipefail

run_tag="${REFRESHED288_RUN_TAG:-20260422_p90_full288_baseline_v1}"
manifest_kind="full"
workers_dynamic_mcmc="4"
session=""
phase_filter="full_dynamic_mcmc"
status_filter="running,not_started,failed_runtime"
outcome_filter="FAIL"
filter_mode="any"
log_label="relaunch_dynamic_mcmc_recovery_memory_only_vbinit_20260424"
vb_init_cache_mode="memory_only"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --run-tag=*)
      run_tag="${1#*=}"
      ;;
    --manifest-kind=*)
      manifest_kind="${1#*=}"
      ;;
    --workers-dynamic-mcmc=*)
      workers_dynamic_mcmc="${1#*=}"
      ;;
    --session=*)
      session="${1#*=}"
      ;;
    --phase-filter=*)
      phase_filter="${1#*=}"
      ;;
    --status-filter=*)
      status_filter="${1#*=}"
      ;;
    --outcome-filter=*)
      outcome_filter="${1#*=}"
      ;;
    --filter-mode=*)
      filter_mode="${1#*=}"
      ;;
    --log-label=*)
      log_label="${1#*=}"
      ;;
    --vb-init-cache=*)
      vb_init_cache_mode="${1#*=}"
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
  shift
done

run_tag="${run_tag//[^A-Za-z0-9_-]/_}"
if [[ -z "$session" ]]; then
  session="refreshed288_${run_tag}_dynamic_mcmc_recovery_memory_only_vbinit"
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/../.." && pwd)"
launch_script="$script_dir/LOCAL_refreshed288_launch_20260422_p90_full288.sh"
log_path="$repo_root/reports/static_exal_tuning_${run_tag:0:8}/refreshed288_p90_full288_${log_label}_${run_tag}.log"

mkdir -p "$(dirname "$log_path")"
export REFRESHED288_RUN_TAG="$run_tag"
export REFRESHED288_MCMC_VB_INIT_CACHE="$vb_init_cache_mode"

if tmux has-session -t "$session" 2>/dev/null; then
  echo "tmux session already exists: $session" >&2
  exit 1
fi

tmux new-session -d -s "$session" \
  "cd '$repo_root' && REFRESHED288_MCMC_VB_INIT_CACHE='$vb_init_cache_mode' '$launch_script' launch --manifest-kind='$manifest_kind' --run-tag='$run_tag' --no-prepare --force --workers-dynamic-mcmc='$workers_dynamic_mcmc' --phase-filter='$phase_filter' --status-filter='$status_filter' --outcome-filter='$outcome_filter' --filter-mode='$filter_mode' > '$log_path' 2>&1"

echo "session=$session"
echo "run_tag=$run_tag"
echo "manifest_kind=$manifest_kind"
echo "workers_dynamic_mcmc=$workers_dynamic_mcmc"
echo "status_filter=$status_filter"
echo "outcome_filter=$outcome_filter"
echo "filter_mode=$filter_mode"
echo "vb_init_for_mcmc=true"
echo "vb_init_cache=$vb_init_cache_mode"
echo "log_path=$log_path"

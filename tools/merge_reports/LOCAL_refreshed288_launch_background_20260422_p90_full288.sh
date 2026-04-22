#!/usr/bin/env bash
set -euo pipefail

run_tag="${REFRESHED288_RUN_TAG:-20260422_p90_full288_baseline_v1}"
manifest_kind="full"
session=""
workers_static_vb="8"
workers_dynamic_vb="6"
workers_static_mcmc="4"
workers_dynamic_mcmc="3"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --run-tag=*)
      run_tag="${1#*=}"
      ;;
    --manifest-kind=*)
      manifest_kind="${1#*=}"
      ;;
    --session=*)
      session="${1#*=}"
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
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
  shift
done

run_tag="${run_tag//[^A-Za-z0-9_-]/_}"
if [[ -z "$session" ]]; then
  session="refreshed288_${run_tag}"
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/../.." && pwd)"
launch_script="$script_dir/LOCAL_refreshed288_launch_20260422_p90_full288.sh"
log_path="$repo_root/reports/static_exal_tuning_${run_tag:0:8}/refreshed288_p90_full288_launch_${run_tag}.log"

mkdir -p "$(dirname "$log_path")"
export REFRESHED288_RUN_TAG="$run_tag"

if tmux has-session -t "$session" 2>/dev/null; then
  echo "tmux session already exists: $session" >&2
  exit 1
fi

tmux new-session -d -s "$session" \
  "cd '$repo_root' && '$launch_script' launch --manifest-kind='$manifest_kind' --workers-static-vb='$workers_static_vb' --workers-dynamic-vb='$workers_dynamic_vb' --workers-static-mcmc='$workers_static_mcmc' --workers-dynamic-mcmc='$workers_dynamic_mcmc' --run-tag='$run_tag' 2>&1 | tee '$log_path'"

echo "session=$session"
echo "run_tag=$run_tag"
echo "manifest_kind=$manifest_kind"
echo "log_path=$log_path"

#!/usr/bin/env bash
set -euo pipefail

if ! command -v tmux >/dev/null 2>&1; then
  echo "tmux is required but not available" >&2
  exit 1
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root_default="$(cd "${script_dir}/../.." && pwd)"
repo_root="${EXDQLM_REPO_ROOT:-${repo_root_default}}"

if [[ ! -d "${repo_root}/.git" ]]; then
  echo "Invalid EXDQLM repo root: ${repo_root}" >&2
  echo "Set EXDQLM_REPO_ROOT to a valid exdqlm worktree path." >&2
  exit 1
fi

cd "$repo_root"

stamp="$(date '+%Y%m%d_%H%M%S')"
launch_manifest="tools/merge_reports/20260310_family_qspec_batch_launch_${stamp}.tsv"
printf "session\tscope\tfit_size\tprior\tlog\tcmd\n" > "$launch_manifest"

launch_session() {
  local session="$1"
  local scope="$2"
  local fit_size="$3"
  local prior="$4"
  local log="$5"
  local cmd="$6"

  tmux new-session -d -s "$session" "cd \"$repo_root\" && $cmd > \"$log\" 2>&1"
  printf "%s\t%s\t%s\t%s\t%s\t%s\n" "$session" "$scope" "$fit_size" "$prior" "$log" "$cmd" >> "$launch_manifest"
}

launch_session "qsp_sp100_${stamp}"  "static_paper"   "100"  "ridge" "tools/merge_reports/qsp_sp100_${stamp}.log"  "bash tools/merge_reports/20260310_run_family_qspec_static_batch.sh paper 100"
launch_session "qsp_sp1k_${stamp}"   "static_paper"   "1000" "ridge" "tools/merge_reports/qsp_sp1k_${stamp}.log"   "bash tools/merge_reports/20260310_run_family_qspec_static_batch.sh paper 1000"
launch_session "qsp_ss100r_${stamp}" "static_shrink"  "100"  "ridge" "tools/merge_reports/qsp_ss100r_${stamp}.log" "bash tools/merge_reports/20260310_run_family_qspec_static_batch.sh shrink 100 ridge"
launch_session "qsp_ss100h_${stamp}" "static_shrink"  "100"  "rhs"   "tools/merge_reports/qsp_ss100h_${stamp}.log" "bash tools/merge_reports/20260310_run_family_qspec_static_batch.sh shrink 100 rhs"
launch_session "qsp_ss1kr_${stamp}"  "static_shrink"  "1000" "ridge" "tools/merge_reports/qsp_ss1kr_${stamp}.log"  "bash tools/merge_reports/20260310_run_family_qspec_static_batch.sh shrink 1000 ridge"
launch_session "qsp_ss1kh_${stamp}"  "static_shrink"  "1000" "rhs"   "tools/merge_reports/qsp_ss1kh_${stamp}.log"  "bash tools/merge_reports/20260310_run_family_qspec_static_batch.sh shrink 1000 rhs"
launch_session "qsp_dy500_${stamp}"  "dynamic"        "500"  ""      "tools/merge_reports/qsp_dy500_${stamp}.log"  "bash tools/merge_reports/20260310_run_family_qspec_dynamic_batch.sh 500"
launch_session "qsp_dy5k_${stamp}"   "dynamic"        "5000" ""      "tools/merge_reports/qsp_dy5k_${stamp}.log"   "bash tools/merge_reports/20260310_run_family_qspec_dynamic_batch.sh 5000"

echo "Launched family qspec validation batches."
echo "Manifest: ${launch_manifest}"

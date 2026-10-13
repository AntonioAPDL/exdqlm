#!/usr/bin/env bash
set -euo pipefail

repo_root=$(git rev-parse --show-toplevel)
branch=$(git -C "$repo_root" branch --show-current)
[[ "$branch" == "validation/independent-qdesn-cellwise-refinement-v2-20260929" ]] || {
  printf 'FATAL: wrong branch: %s\n' "$branch" >&2
  exit 1
}
[[ -z $(git -C "$repo_root" status --porcelain) ]] || {
  printf 'FATAL: worktree is dirty\n' >&2
  exit 1
}
upstream=$(git -C "$repo_root" rev-parse --abbrev-ref --symbolic-full-name '@{upstream}')
read -r behind ahead < <(git -C "$repo_root" rev-list --left-right --count "$upstream...HEAD")
[[ "$behind" -eq 0 && "$ahead" -eq 0 ]] || {
  printf 'FATAL: branch divergence behind=%s ahead=%s\n' "$behind" "$ahead" >&2
  exit 1
}

workers=${WORKERS:-15}
cpu_list=${CPU_LIST:-32,33,34,35,36,37,38,39,40,41,42,43,44,45,46}
stamp=$(date +%Y%m%d_%H%M%S)
short_head=$(git -C "$repo_root" rev-parse --short=10 HEAD)
run_root=${RUN_ROOT:-$repo_root/validation/fitforecast_v2/local_trackers/independent_qdesn_cellwise_refinement_v2_${stamp}__git-${short_head}}
session=${TMUX_SESSION:-iqcr_v2_${stamp}}
pipeline="$repo_root/validation/fitforecast_v2/scripts/run_independent_qdesn_cellwise_refinement_v2_pipeline.sh"
stdout="$run_root/pipeline.stdout.log"
mkdir -p "$run_root"

cat > "$run_root/launch_environment.txt" <<EOF
launched_at=$(date --iso-8601=seconds)
host=$(hostname)
repo_root=$repo_root
branch=$branch
head=$(git -C "$repo_root" rev-parse HEAD)
upstream=$upstream
workers=$workers
cpu_list=$cpu_list
load=$(cat /proc/loadavg)
available_memory_kb=$(awk '/MemAvailable:/ {print $2}' /proc/meminfo)
available_disk_kb=$(df -Pk /data | awk 'NR==2 {print $4}')
EOF

tmux new-session -d -s "$session" \
  "cd '$repo_root' && REPO_ROOT='$repo_root' RUN_ROOT='$run_root' WORKERS='$workers' CPU_LIST='$cpu_list' '$pipeline' > '$stdout' 2>&1"
printf 'session=%s\nrun_root=%s\nstdout=%s\nworkers=%s\ncpu_list=%s\n' \
  "$session" "$run_root" "$stdout" "$workers" "$cpu_list"

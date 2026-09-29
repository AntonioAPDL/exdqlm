#!/usr/bin/env bash
set -euo pipefail

repo_root=$(git rev-parse --show-toplevel)
closeout="$repo_root/validation/fitforecast_v2/promotions/independent_qdesn_representation_screen_v1_stage1_closeout_20260929/stage1_closeout.json"
[[ ! -f "$closeout" ]] || {
  printf 'FATAL: campaign is frozen by %s\n' "$closeout" >&2
  exit 1
}
branch=$(git -C "$repo_root" branch --show-current)
[[ "$branch" == "validation/independent-qdesn-representation-screen-v1-20260929" ]] || {
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

stamp=$(date +%Y%m%d_%H%M%S)
short_head=$(git -C "$repo_root" rev-parse --short=10 HEAD)
run_root=${RUN_ROOT:-$repo_root/validation/fitforecast_v2/local_trackers/independent_qdesn_representation_screen_v1_${stamp}__git-${short_head}}
session=${TMUX_SESSION:-iqrs_v1_${stamp}}
pipeline="$repo_root/validation/fitforecast_v2/scripts/run_independent_qdesn_representation_screen_v1_pipeline.sh"
stdout="$run_root/pipeline.stdout.log"
mkdir -p "$run_root"

tmux new-session -d -s "$session" \
  "cd '$repo_root' && REPO_ROOT='$repo_root' RUN_ROOT='$run_root' WORKERS=15 CPU_SET=32-46 '$pipeline' > '$stdout' 2>&1"
printf 'session=%s\nrun_root=%s\nstdout=%s\nworkers=15\ncpu_set=32-46\n' \
  "$session" "$run_root" "$stdout"

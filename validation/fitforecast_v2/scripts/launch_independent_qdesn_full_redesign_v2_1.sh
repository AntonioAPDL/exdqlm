#!/usr/bin/env bash
set -euo pipefail

repo_root=$(git rev-parse --show-toplevel)
expected_branch="validation/independent-qdesn-full-redesign-v2-20260925"
pipeline="$repo_root/validation/fitforecast_v2/scripts/run_independent_qdesn_full_redesign_v2_pipeline.sh"
workers=15

branch=$(git -C "$repo_root" branch --show-current)
[[ "$branch" == "$expected_branch" ]] || {
  printf 'Expected branch %s, observed %s.\n' "$expected_branch" "$branch" >&2
  exit 1
}
[[ -z $(git -C "$repo_root" status --porcelain) ]] || {
  printf 'The dedicated validation worktree must be clean.\n' >&2
  exit 1
}
upstream=$(git -C "$repo_root" rev-parse --abbrev-ref \
  --symbolic-full-name '@{upstream}')
read -r behind ahead < <(
  git -C "$repo_root" rev-list --left-right --count "$upstream...HEAD"
)
[[ "$behind" -eq 0 && "$ahead" -eq 0 ]] || {
  printf 'Branch divergence is behind=%s ahead=%s.\n' "$behind" "$ahead" >&2
  exit 1
}

stamp=$(date +%Y%m%d_%H%M%S)
short_head=$(git -C "$repo_root" rev-parse --short=9 HEAD)
session="iqfr21_${stamp}"
run_root="$repo_root/validation/fitforecast_v2/local_trackers/independent_qdesn_full_redesign_v2_1_${stamp}__git-${short_head}"
controller_log="${run_root}.controller.log"
receipt="${run_root}.launch.txt"

if tmux has-session -t "$session" 2>/dev/null; then
  printf 'Refusing to reuse tmux session %s.\n' "$session" >&2
  exit 1
fi
[[ ! -e "$run_root" && ! -e "$controller_log" && ! -e "$receipt" ]] || {
  printf 'Refusing to overwrite an existing v2.1 launch path.\n' >&2
  exit 1
}

printf -v command 'cd %q && exec %q --run-root %q --workers %q > %q 2>&1' \
  "$repo_root" "$pipeline" "$run_root" "$workers" "$controller_log"
tmux new-session -d -s "$session" "$command"

printf '%s\n' \
  "protocol=independent_qdesn_full_redesign_v2_1" \
  "created_at=$(date --iso-8601=seconds)" \
  "repo_root=$repo_root" \
  "branch=$branch" \
  "upstream=$upstream" \
  "head=$(git -C "$repo_root" rev-parse HEAD)" \
  "workers=$workers" \
  "threads_per_worker=1" \
  "tmux_session=$session" \
  "run_root=$run_root" \
  "controller_log=$controller_log" > "$receipt"

printf 'session=%s\nrun_root=%s\ncontroller_log=%s\nreceipt=%s\n' \
  "$session" "$run_root" "$controller_log" "$receipt"

#!/usr/bin/env bash
set -euo pipefail

usage() {
  printf 'Usage: %s --run-root PATH\n' "$0" >&2
}

run_root=""
while (($#)); do
  case "$1" in
    --run-root)
      run_root=${2:-}
      shift 2
      ;;
    *)
      usage
      exit 2
      ;;
  esac
done
[[ -n "$run_root" ]] || { usage; exit 2; }

repo_root=$(git rev-parse --show-toplevel)
run_root=$(realpath -e "$run_root")
manager="$repo_root/validation/fitforecast_v2/scripts/manage_independent_qdesn_full_redesign_v2.R"
pipeline="$repo_root/validation/fitforecast_v2/scripts/run_independent_qdesn_full_redesign_v2_pipeline.sh"
rscript=${RSCRIPT:-$(command -v Rscript)}
workers=15

stamp=$(date +%Y%m%d_%H%M%S)
session="iqfr21_resume_${stamp}"
controller_log="${run_root}.resume_${stamp}.controller.log"
receipt="${run_root}.resume_${stamp}.launch.txt"

tmux has-session -t "$session" 2>/dev/null && {
  printf 'Refusing to reuse tmux session %s.\n' "$session" >&2
  exit 1
}
[[ ! -e "$controller_log" && ! -e "$receipt" ]] || {
  printf 'Refusing to overwrite resume evidence.\n' >&2
  exit 1
}

"$rscript" --vanilla "$manager" --action authorize_resume \
  --run-root "$run_root"

printf -v command 'cd %q && exec %q --run-root %q --workers %q > %q 2>&1' \
  "$repo_root" "$pipeline" "$run_root" "$workers" "$controller_log"
tmux new-session -d -s "$session" "$command"

printf '%s\n' \
  "protocol=independent_qdesn_full_redesign_v2_1" \
  "mode=authorized_checkpoint_resume" \
  "created_at=$(date --iso-8601=seconds)" \
  "repo_root=$repo_root" \
  "head=$(git -C "$repo_root" rev-parse HEAD)" \
  "workers=$workers" \
  "threads_per_worker=1" \
  "tmux_session=$session" \
  "run_root=$run_root" \
  "controller_log=$controller_log" > "$receipt"

printf 'session=%s\nrun_root=%s\ncontroller_log=%s\nreceipt=%s\n' \
  "$session" "$run_root" "$controller_log" "$receipt"

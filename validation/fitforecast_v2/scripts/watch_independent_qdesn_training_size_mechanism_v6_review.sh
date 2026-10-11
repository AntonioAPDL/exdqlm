#!/usr/bin/env bash
set -euo pipefail

review_repo=$(realpath "$1")
run=$(realpath "$2")
output=$3
poll_seconds=${4:-300}
rscript=${RSCRIPT:-/data/jaguir26/local/opt/R/4.6.0/bin/Rscript}
review_script="$review_repo/validation/fitforecast_v2/scripts/review_independent_qdesn_training_size_mechanism_v6.R"
control="${output}.watch"
mkdir -p "$control"

exec 9>"$control/watcher.lock"
flock -n 9 || { printf 'Another final-review watcher owns this output.\n' >&2; exit 1; }

review_head=$(git -C "$review_repo" rev-parse HEAD)
campaign_head=$($rscript -e \
  'cat(jsonlite::read_json(file.path(commandArgs(TRUE)[1], "campaign.json"), simplifyVector=TRUE)$head)' \
  "$run")
library=$($rscript -e \
  'cat(jsonlite::read_json(file.path(commandArgs(TRUE)[1], "campaign.json"), simplifyVector=TRUE)$library)' \
  "$run")
export R_LIBS_USER="$library"

printf '%s\n' "$$" > "$control/watcher.pid"
printf '%s\n' "$review_head" > "$control/review_head"
printf '%s\n' "$campaign_head" > "$control/campaign_head"

status() {
  printf '%s\t%s\t%s\n' "$1" "$(date -u +%FT%TZ)" "$2" \
    > "$control/status.tmp.$$"
  mv "$control/status.tmp.$$" "$control/status"
}

while [[ ! -f "$run/closeout.json" ]]; do
  current_review=$(git -C "$review_repo" rev-parse HEAD)
  current_campaign=$($rscript -e \
    'cat(jsonlite::read_json(file.path(commandArgs(TRUE)[1], "campaign.json"), simplifyVector=TRUE)$head)' \
    "$run")
  [[ "$current_review" == "$review_head" ]] || {
    status BLOCKED review_head_changed
    exit 1
  }
  [[ "$current_campaign" == "$campaign_head" ]] || {
    status BLOCKED campaign_head_changed
    exit 1
  }
  [[ -z "$(git -C "$review_repo" status --porcelain)" ]] || {
    status BLOCKED review_worktree_dirty
    exit 1
  }
  scheduler_state=$(cut -f1 "$run/control/scheduler.status" 2>/dev/null || true)
  case "$scheduler_state" in
    PAUSED*|FAILED*|BLOCKED*)
      status BLOCKED "scheduler_state=$scheduler_state"
      exit 1
      ;;
  esac
  status WAITING "scheduler_state=${scheduler_state:-unknown};poll_seconds=$poll_seconds"
  sleep "$poll_seconds"
done

status FINALIZING closeout_detected
[[ ! -e "$output" ]] || {
  status BLOCKED output_already_exists
  exit 1
}
"$rscript" "$review_script" "$review_repo" "$run" "$output" final \
  > "$control/final_review.log" 2>&1
status COMPLETE "review=$output"

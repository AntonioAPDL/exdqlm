#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
out_dir="$repo_root/tools/merge_reports"
session="wave8-resume-chain-20260403"
interval="120"
max_checks="720"
state_file="$out_dir/LOCAL_static_exal_wave8_live_monitor_state_20260403.txt"

for arg in "$@"; do
  case "$arg" in
    --session=*) session="${arg#*=}" ;;
    --interval=*) interval="${arg#*=}" ;;
    --max-checks=*) max_checks="${arg#*=}" ;;
    --state-file=*) state_file="${arg#*=}" ;;
    *) ;;
  esac
done

snapshot() {
  Rscript - <<'RS'
out_dir <- "tools/merge_reports"
sched_path <- file.path(out_dir, "LOCAL_static_exal_wave8_transfer_schedule_20260403.csv")
if (!file.exists(sched_path)) {
  cat("SUMMARY done=0 missing=0 pass=0 warn=0 fail=0 latest_mtime=NA latest_file=NA\n")
  quit(status=0)
}
sched <- read.csv(sched_path, stringsAsFactors=FALSE, check.names=FALSE)
sched$case_id <- paste0(gsub("^.*/results/", "results/", sched$run_root), "::exal")
summ_files <- Sys.glob(file.path(out_dir, "LOCAL_static_case_health_summary_wave8_transfer_*.csv"))
if (!length(summ_files)) {
  cat("SUMMARY done=0 missing=", nrow(sched), " pass=0 warn=0 fail=0 latest_mtime=NA latest_file=NA\n", sep="")
  quit(status=0)
}
latest_file <- summ_files[order(file.info(summ_files)$mtime, decreasing=TRUE)][1]
latest_mtime <- format(file.info(latest_file)$mtime, "%Y-%m-%d %H:%M:%S %Z")
summ_list <- lapply(summ_files, function(p) {
  x <- tryCatch(read.csv(p, stringsAsFactors=FALSE, check.names=FALSE), error=function(e) NULL)
  if (is.null(x)) return(NULL)
  x
})
summ <- if (length(summ_list)) do.call(rbind, summ_list) else data.frame()
if (!nrow(summ)) {
  cat("SUMMARY done=0 missing=", nrow(sched), " pass=0 warn=0 fail=0 latest_mtime=", latest_mtime,
      " latest_file=", latest_file, "\n", sep="")
  quit(status=0)
}

summ <- summ[summ$variant_tag %in% unique(sched$variant_tag), , drop=FALSE]
key <- unique(sched[, c("stage","candidate_id","variant_tag","row_id","case_id")])
merged <- merge(key, summ[, c("case_id","variant_tag","gate_overall")], by=c("case_id","variant_tag"), all.x=TRUE)
merged$gate_overall[is.na(merged$gate_overall)] <- "MISSING"

stages <- unique(merged$stage)
tab <- data.frame()
for (st in stages) {
  sub <- merged[merged$stage==st, , drop=FALSE]
  total <- nrow(sub)
  done <- sum(sub$gate_overall != "MISSING")
  pass <- sum(sub$gate_overall=="PASS")
  warn <- sum(sub$gate_overall=="WARN")
  fail <- sum(sub$gate_overall=="FAIL")
  missing <- sum(sub$gate_overall=="MISSING")
  cand <- length(unique(sub$candidate_id))
  tab <- rbind(tab, data.frame(stage=st, candidates=cand, total=total, done=done, missing=missing, PASS=pass, WARN=warn, FAIL=fail))
}
tab <- tab[order(tab$stage), ]

overall <- list(
  done = sum(tab$done),
  missing = sum(tab$missing),
  pass = sum(tab$PASS),
  warn = sum(tab$WARN),
  fail = sum(tab$FAIL)
)

cat(sprintf("SUMMARY done=%d missing=%d pass=%d warn=%d fail=%d latest_mtime=%s latest_file=%s\n",
            overall$done, overall$missing, overall$pass, overall$warn, overall$fail,
            latest_mtime, latest_file))
print(tab, row.names=FALSE)
RS
}

latest_row_log_heartbeat() {
  local latest_line
  latest_line="$(find "$out_dir" -maxdepth 1 -type f -name 'LOCAL_static_exal_wave8_*_resume.log' -printf '%T@ %p\n' 2>/dev/null | sort -nr | head -n1 || true)"
  if [[ -z "$latest_line" ]]; then
    echo "NA|NA"
    return 0
  fi
  local latest_epoch latest_path now_epoch age_sec
  latest_epoch="${latest_line%% *}"
  latest_path="${latest_line#* }"
  now_epoch="$(date +%s)"
  age_sec=$(( now_epoch - ${latest_epoch%.*} ))
  echo "${age_sec}|${latest_path}"
}

prev_done="NA"
stagnant=0
check=0

while true; do
  check=$((check + 1))
  ts="$(date '+%Y-%m-%d %H:%M:%S %Z')"
  echo "=== wave8 monitor ${ts} (check ${check}) ==="

  session_state="NOT_RUNNING"
  if tmux has-session -t "$session" 2>/dev/null; then
    session_state="RUNNING"
  fi
  runner_count="$( { pgrep -af 'LOCAL_static_exal_case_runner_20260323.R' 2>/dev/null || true; } | wc -l | tr -d ' ' )"
  if [[ -z "$runner_count" ]]; then
    runner_count="0"
  fi
  heartbeat="$(latest_row_log_heartbeat)"
  latest_row_log_age_sec="${heartbeat%%|*}"
  latest_row_log_path="${heartbeat#*|}"

  echo "tmux_session=${session_state} runner_processes=${runner_count} latest_row_log_age_sec=${latest_row_log_age_sec} latest_row_log_path=${latest_row_log_path}"

  output="$(snapshot)"
  echo "$output"

  summary_line="$(echo "$output" | awk '/^SUMMARY /{print; exit}')"
  done_now="$(echo "$summary_line" | awk -F' ' '{for(i=1;i<=NF;i++){if($i ~ /^done=/){sub("done=","",$i); print $i; exit}}}')"
  missing_now="$(echo "$summary_line" | awk -F' ' '{for(i=1;i<=NF;i++){if($i ~ /^missing=/){sub("missing=","",$i); print $i; exit}}}')"

  if [[ -n "$done_now" && "$done_now" == "$prev_done" ]]; then
    stagnant=$((stagnant + 1))
  else
    stagnant=0
  fi
  prev_done="$done_now"

  if [[ -n "$missing_now" && "$missing_now" == "0" ]]; then
    echo "All missing rows completed. Exiting monitor."
    exit 0
  fi

  if [[ "$session_state" != "RUNNING" && "${runner_count:-0}" == "0" ]]; then
    echo "Warning: no active tmux session or runner processes detected while missing rows remain."
  fi

  if [[ "$stagnant" -ge 3 ]]; then
    if [[ "${runner_count:-0}" == "0" ]]; then
      echo "Warning: no progress detected for 3 consecutive checks and no runner processes are active."
    elif [[ "$latest_row_log_age_sec" == "NA" ]]; then
      echo "Warning: no progress detected for 3 consecutive checks and no row-log heartbeat is available."
    elif [[ "$latest_row_log_age_sec" -gt $(( interval * 2 )) ]]; then
      echo "Warning: no progress detected for 3 consecutive checks and active row logs have been quiet for ${latest_row_log_age_sec}s."
    else
      echo "Notice: summary counts are unchanged, but active row logs were updated ${latest_row_log_age_sec}s ago; long rows still appear to be progressing."
    fi
  fi

  echo ""
  if [[ "$check" -ge "$max_checks" ]]; then
    echo "Max checks reached; exiting monitor."
    exit 0
  fi
  sleep "$interval"
done

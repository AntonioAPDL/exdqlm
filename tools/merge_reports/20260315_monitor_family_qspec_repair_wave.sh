#!/usr/bin/env bash
set -euo pipefail

repo_root="$(pwd)"
state_dir="/home/jaguir26/local/state/exdqlm/family_qspec_repair_v1"
interval_sec=600
snapshots=3

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo-root)
      repo_root="$2"
      shift 2
      ;;
    --state-dir)
      state_dir="$2"
      shift 2
      ;;
    --interval-sec)
      interval_sec="$2"
      shift 2
      ;;
    --snapshots)
      snapshots="$2"
      shift 2
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

repo_root="$(cd "$repo_root" && pwd)"
state_dir="$(cd "$state_dir" && pwd)"
interval_sec="$(printf '%s' "$interval_sec" | sed 's/[^0-9].*$//')"
snapshots="$(printf '%s' "$snapshots" | sed 's/[^0-9].*$//')"
[[ -n "$interval_sec" ]] || interval_sec=600
[[ -n "$snapshots" ]] || snapshots=3
if (( interval_sec < 1 )); then interval_sec=600; fi
if (( snapshots < 1 )); then snapshots=3; fi

queue_dir="${state_dir}/queue"
queue_tsv="${queue_dir}/20260314_family_qspec_repair_queue.tsv"
queue_summary_tsv="${queue_dir}/20260314_family_qspec_repair_queue_summary.tsv"
task_events_tsv="${state_dir}/task_events.tsv"
locks_dir="${state_dir}/locks"
worker_log_dir="${state_dir}/worker_logs"
monitor_dir="${state_dir}/monitor"
snapshot_tsv="${monitor_dir}/repair_wave_tail_snapshots.tsv"
summary_md="${monitor_dir}/repair_wave_latest_summary.md"

mkdir -p "$monitor_dir"

if [[ ! -f "$queue_tsv" ]]; then
  echo "Missing queue TSV: $queue_tsv" >&2
  exit 1
fi

if [[ ! -f "$snapshot_tsv" ]]; then
  printf 'timestamp\tsnapshot_index\tactive_lock_count\ttask_id\tunit_type\troot_kind\tfamily\ttau\tfit_size\tprior\tmodel\tworker_pid\tr_pid\telapsed_s\tcpu_pct\trss_mb\tstage\titer\ttotal_iter\tprogress_pct\taccept_rate\tlast_log_line\n' > "$snapshot_tsv"
fi

field_from_queue() {
  local task_id="$1"
  local field_name="$2"
  awk -F'\t' -v task_id="$task_id" -v field="$field_name" '
    NR == 1 {
      for (i = 1; i <= NF; i++) idx[$i] = i
      next
    }
    $idx["task_id"] == task_id {
      print $idx[field]
      exit
    }
  ' "$queue_tsv"
}

last_nonempty_line() {
  local path="$1"
  if [[ ! -f "$path" ]]; then
    return 0
  fi
  awk 'NF { line = $0 } END { if (line != "") print line }' "$path"
}

last_iter_record() {
  local path="$1"
  if [[ ! -f "$path" ]]; then
    return 0
  fi
  awk '
    /burn-in iteration [0-9]+, acceptance rate / || /MCMC iteration [0-9]+, acceptance rate / {
      line = $0
    }
    END {
      if (line != "") print line
    }
  ' "$path"
}

parse_iter_record() {
  local record="$1"
  local stage="na"
  local iter="NA"
  local accept="NA"
  if [[ "$record" =~ burn-in[[:space:]]iteration[[:space:]]([0-9]+),[[:space:]]acceptance[[:space:]]rate[[:space:]]([0-9.]+) ]]; then
    stage="burn"
    iter="${BASH_REMATCH[1]}"
    accept="${BASH_REMATCH[2]}"
  elif [[ "$record" =~ MCMC[[:space:]]iteration[[:space:]]([0-9]+),[[:space:]]acceptance[[:space:]]rate[[:space:]]([0-9.]+) ]]; then
    stage="mcmc"
    iter="${BASH_REMATCH[1]}"
    accept="${BASH_REMATCH[2]}"
  fi
  printf '%s\t%s\t%s\n' "$stage" "$iter" "$accept"
}

parse_total_iter() {
  local path="$1"
  local total="NA"
  if [[ ! -f "$path" ]]; then
    printf '%s\n' "$total"
    return 0
  fi
  local line
  line="$(awk '
    /MCMC\(burn=[0-9]+,n=[0-9]+/ || /resume mcmc config \| burn=[0-9]+ \| keep=[0-9]+/ {
      cfg = $0
    }
    END {
      if (cfg != "") print cfg
    }
  ' "$path")"
  if [[ "$line" =~ MCMC\(burn=([0-9]+),n=([0-9]+) ]]; then
    total="$(( ${BASH_REMATCH[1]} + ${BASH_REMATCH[2]} ))"
  elif [[ "$line" =~ burn=([0-9]+)[[:space:]]+\|[[:space:]]keep=([0-9]+) ]]; then
    total="$(( ${BASH_REMATCH[1]} + ${BASH_REMATCH[2]} ))"
  fi
  printf '%s\n' "$total"
}

latest_count_for_event() {
  local event_name="$1"
  if [[ ! -f "$task_events_tsv" ]]; then
    printf '0\n'
    return 0
  fi
  awk -F'\t' -v event="$event_name" 'NR > 1 && $4 == event { c++ } END { print c + 0 }' "$task_events_tsv"
}

write_summary() {
  local timestamp="$1"
  local snapshot_index="$2"
  {
    printf '# Repair Wave Monitor\n\n'
    printf -- '- timestamp: `%s`\n' "$timestamp"
    printf -- '- snapshot_index: `%s`\n' "$snapshot_index"
    printf -- '- active_locks: `%s`\n' "$(find "$locks_dir" -mindepth 1 -maxdepth 1 -type d | wc -l)"
    printf -- '- event_counts: `START=%s`, `DONE=%s`, `FAILED=%s`\n' \
      "$(latest_count_for_event START)" \
      "$(latest_count_for_event DONE)" \
      "$(latest_count_for_event FAILED)"
    printf '\n## Queue Summary\n\n'
    if [[ -f "$queue_summary_tsv" ]]; then
      awk -F'\t' '
        NR == 1 { print "| unit_type | state | launch_ready | count |"; print "|---|---|---:|---:|"; next }
        { printf "| %s | %s | %s | %s |\n", $1, $2, $3, $4 }
      ' "$queue_summary_tsv"
    else
      printf '_queue summary unavailable_\n'
    fi
    printf '\n## Active Tasks\n\n'
    printf '| task_id | stage | iter / total | cpu | rss_mb | last_log |\n'
    printf '|---|---|---:|---:|---:|---|\n'
    while IFS=$'\t' read -r snapshot_time snap_idx active_count task_id unit_type root_kind family tau fit_size prior model worker_pid r_pid elapsed_s cpu_pct rss_mb stage iter total_iter progress_pct accept_rate last_log_line; do
      [[ "$snapshot_time" == "$timestamp" ]] || continue
      [[ -n "$task_id" ]] || continue
      printf '| %s | %s | %s / %s | %s | %s | %s |\n' \
        "$task_id" "$stage" "$iter" "$total_iter" "$cpu_pct" "$rss_mb" "$last_log_line"
    done < "$snapshot_tsv"
  } > "$summary_md"
}

capture_snapshot() {
  local snapshot_index="$1"
  local timestamp
  timestamp="$(date '+%Y-%m-%d %H:%M:%S %Z')"
  local active_lock_count
  active_lock_count="$(find "$locks_dir" -mindepth 1 -maxdepth 1 -type d | wc -l)"

  mapfile -t task_ids < <(find "$locks_dir" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort)
  if (( ${#task_ids[@]} == 0 )); then
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
      "$timestamp" "$snapshot_index" "$active_lock_count" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" >> "$snapshot_tsv"
  fi

  for task_id in "${task_ids[@]}"; do
    local unit_type root_kind family tau fit_size prior model
    unit_type="$(field_from_queue "$task_id" "unit_type")"
    root_kind="$(field_from_queue "$task_id" "root_kind")"
    family="$(field_from_queue "$task_id" "family")"
    tau="$(field_from_queue "$task_id" "tau")"
    fit_size="$(field_from_queue "$task_id" "fit_size")"
    prior="$(field_from_queue "$task_id" "prior")"
    model="$(field_from_queue "$task_id" "model")"

    local worker_pid r_pid target_pid elapsed_s cpu_pct rss_mb
    worker_pid="$(cat "$locks_dir/$task_id/pid" 2>/dev/null || true)"
    r_pid="$(pgrep -P "$worker_pid" R 2>/dev/null | head -n 1 || true)"
    target_pid="${r_pid:-$worker_pid}"
    elapsed_s="$(ps -p "$target_pid" -o etimes= --no-headers 2>/dev/null | awk '{print $1}')"
    cpu_pct="$(ps -p "$target_pid" -o pcpu= --no-headers 2>/dev/null | awk '{print $1}')"
    rss_mb="$(ps -p "$target_pid" -o rss= --no-headers 2>/dev/null | awk '{printf "%.1f", $1/1024}')"
    elapsed_s="${elapsed_s:-NA}"
    cpu_pct="${cpu_pct:-NA}"
    rss_mb="${rss_mb:-NA}"

    local log_path iter_record stage iter accept_rate total_iter progress_pct last_log_line
    log_path="${worker_log_dir}/${task_id}.log"
    iter_record="$(last_iter_record "$log_path")"
    IFS=$'\t' read -r stage iter accept_rate <<< "$(parse_iter_record "$iter_record")"
    total_iter="$(parse_total_iter "$log_path")"
    progress_pct="NA"
    if [[ "$iter" != "NA" && "$total_iter" != "NA" && "$total_iter" != "0" ]]; then
      progress_pct="$(awk -v i="$iter" -v t="$total_iter" 'BEGIN { printf "%.1f", 100 * i / t }')"
    fi
    last_log_line="$(last_nonempty_line "$log_path" | tr '\t' ' ' | sed 's/[[:space:]]\+/ /g' | cut -c1-220)"
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
      "$timestamp" "$snapshot_index" "$active_lock_count" "$task_id" "$unit_type" "$root_kind" "$family" "$tau" "$fit_size" "$prior" "$model" \
      "${worker_pid:-NA}" "${r_pid:-NA}" "$elapsed_s" "$cpu_pct" "$rss_mb" "$stage" "$iter" "$total_iter" "$progress_pct" "$accept_rate" "$last_log_line" \
      >> "$snapshot_tsv"
  done

  write_summary "$timestamp" "$snapshot_index"
  echo "$timestamp | snapshot ${snapshot_index}/${snapshots} captured | active_locks=${active_lock_count}"
}

for ((i = 1; i <= snapshots; i++)); do
  capture_snapshot "$i"
  if (( i < snapshots )); then
    sleep "$interval_sec"
  fi
done

echo "Monitor complete. Latest summary: $summary_md"

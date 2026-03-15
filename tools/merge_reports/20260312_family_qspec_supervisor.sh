#!/usr/bin/env bash
set -euo pipefail

repo_root="$(pwd)"
state_dir="/home/jaguir26/local/state/exdqlm/family_qspec_v2"
slot_budget=30
poll_sec=20
mode="dry_run"
queue_builder_script="tools/merge_reports/20260312_build_family_qspec_runtime_queue.R"
queue_tsv=""
queue_summary_tsv=""
worker_script="tools/merge_reports/20260312_family_qspec_worker.sh"

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
    --slot-budget)
      slot_budget="$2"
      shift 2
      ;;
    --queue-builder-script)
      queue_builder_script="$2"
      shift 2
      ;;
    --queue-tsv)
      queue_tsv="$2"
      shift 2
      ;;
    --queue-summary-tsv)
      queue_summary_tsv="$2"
      shift 2
      ;;
    --worker-script)
      worker_script="$2"
      shift 2
      ;;
    --poll-sec)
      poll_sec="$2"
      shift 2
      ;;
    --launch)
      mode="launch"
      shift
      ;;
    --dry-run|--status)
      mode="dry_run"
      shift
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

repo_root="$(cd "$repo_root" && pwd)"
mkdir -p "$state_dir/locks" "$state_dir/worker_logs"
queue_tsv="${queue_tsv:-${repo_root}/tools/merge_reports/20260312_family_qspec_runtime_queue.tsv}"
queue_summary_tsv="${queue_summary_tsv:-${repo_root}/tools/merge_reports/20260312_family_qspec_runtime_queue_summary.tsv}"
launch_registry="${state_dir}/launch_registry.tsv"
if [[ "$queue_builder_script" = /* ]]; then
  queue_builder_abs="$queue_builder_script"
else
  queue_builder_abs="${repo_root}/${queue_builder_script}"
fi
if [[ "$worker_script" = /* ]]; then
  worker_script_abs="$worker_script"
else
  worker_script_abs="${repo_root}/${worker_script}"
fi

if [[ ! -f "$queue_builder_abs" ]]; then
  echo "Queue builder script not found: $queue_builder_abs" >&2
  exit 1
fi
if [[ ! -f "$worker_script_abs" ]]; then
  echo "Worker script not found: $worker_script_abs" >&2
  exit 1
fi

log_registry() {
  local session_name="$1"
  local task_id="$2"
  local unit_type="$3"
  local now
  now="$(date '+%Y-%m-%d %H:%M:%S')"
  (
    flock 9
    if [[ ! -f "$launch_registry" ]]; then
      printf 'timestamp\tsession_name\ttask_id\tunit_type\n' > "$launch_registry"
    fi
    printf '%s\t%s\t%s\t%s\n' "$now" "$session_name" "$task_id" "$unit_type" >> "$launch_registry"
  ) 9>"${state_dir}/launch_registry.lock"
}

rebuild_queue() {
  if [[ "$queue_builder_script" == "tools/merge_reports/20260312_build_family_qspec_runtime_queue.R" ]]; then
    (cd "$repo_root" && Rscript tools/merge_reports/20260312_build_family_qspec_reusable_state_audit.R "$repo_root" >/dev/null)
  fi
  (cd "$repo_root" && Rscript "$queue_builder_abs" "$repo_root" "$state_dir" >/dev/null)
}

reap_stale_locks() {
  shopt -s nullglob
  for lock_dir in "$state_dir"/locks/*; do
    [[ -d "$lock_dir" ]] || continue
    pid=""
    if [[ -f "$lock_dir/pid" ]]; then
      pid="$(< "$lock_dir/pid")"
    fi
    if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
      continue
    fi
    session_name=""
    if [[ -f "$lock_dir/session_name" ]]; then
      session_name="$(< "$lock_dir/session_name")"
    fi
    if [[ -n "$session_name" ]] && tmux has-session -t "$session_name" 2>/dev/null; then
      continue
    fi
    rm -rf "$lock_dir"
  done
  shopt -u nullglob
}

count_running_slots() {
  find "$state_dir/locks" -mindepth 1 -maxdepth 1 -type d | wc -l
}

count_ready_unlocked() {
  awk -F'\t' '
    NR==1 { for (i = 1; i <= NF; i++) idx[$i] = i; next }
    $idx["launch_ready"] == "TRUE" { print $idx["task_id"] }
  ' "$queue_tsv" | while IFS= read -r task_id; do
    [[ -n "$task_id" ]] || continue
    [[ -d "$state_dir/locks/${task_id}" ]] && continue
    printf '.'
  done | wc -c
}

print_status() {
  echo "queue_summary=$(basename "$queue_summary_tsv")"
  sed -n '1,40p' "$queue_summary_tsv"
  echo
  echo "active_locks=$(count_running_slots) slot_budget=${slot_budget}"
  echo "ready_head:"
  awk -F'\t' '
    NR==1 { print; next }
    $12 == "TRUE" { print; count++; if (count >= 12) exit }
  ' "$queue_tsv"
}

select_next_ready_task() {
  awk -F'\t' '
    NR==1 { for (i = 1; i <= NF; i++) idx[$i] = i; next }
    $idx["launch_ready"] == "TRUE" { print $idx["task_id"] "\t" $idx["unit_type"]; }
  ' "$queue_tsv" | while IFS=$'\t' read -r task_id unit_type; do
    [[ -n "$task_id" ]] || continue
    if [[ -d "$state_dir/locks/${task_id}" ]]; then
      continue
    fi
    printf '%s\t%s\n' "$task_id" "$unit_type"
    return 0
  done
  return 1
}

launch_task() {
  local task_id="$1"
  local unit_type="$2"
  local short_type
  short_type="$(echo "$unit_type" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/_/g')"
  local stamp
  stamp="$(date '+%Y%m%d_%H%M%S')"
  local short_id
  short_id="$(printf '%s' "$task_id" | cksum | awk '{print $1}')"
  local session_name="fqv2_${short_type}_${stamp}_${short_id}"
  local lock_dir="${state_dir}/locks/${task_id}"
  mkdir "$lock_dir"
  printf '%s\n' "$session_name" > "$lock_dir/session_name"
  (
    cd "$repo_root"
    nohup setsid "$worker_script_abs" "$repo_root" "$state_dir" "$task_id" "$session_name" "$queue_tsv" >/dev/null 2>&1 < /dev/null &
    printf '%s\n' "$!" > "$lock_dir/pid"
    printf '%s\n' "$!" > "$lock_dir/pgid"
  )
  log_registry "$session_name" "$task_id" "$unit_type"
}

rebuild_queue
reap_stale_locks
print_status

if [[ "$mode" == "dry_run" ]]; then
  exit 0
fi

while true; do
  rebuild_queue
  reap_stale_locks
  active_slots="$(count_running_slots)"

  while [[ "$active_slots" -lt "$slot_budget" ]]; do
    next_task="$(select_next_ready_task || true)"
    if [[ -z "$next_task" ]]; then
      break
    fi
    IFS=$'\t' read -r task_id unit_type <<< "$next_task"
    launch_task "$task_id" "$unit_type"
    active_slots=$((active_slots + 1))
  done

  rebuild_queue
  reap_stale_locks
  active_slots="$(count_running_slots)"
  ready_unlocked="$(count_ready_unlocked)"
  echo "$(date '+%Y-%m-%d %H:%M:%S') | active_slots=${active_slots} ready_unlocked=${ready_unlocked}"
  if [[ "$active_slots" -eq 0 && "$ready_unlocked" -eq 0 ]]; then
    break
  fi
  sleep "$poll_sec"
done

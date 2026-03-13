#!/usr/bin/env bash
set -euo pipefail

repo_root="$(pwd)"
state_dir="/home/jaguir26/local/state/exdqlm/family_qspec_v2"
slot_budget=30
poll_sec=20
mode="dry_run"

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
queue_tsv="${repo_root}/tools/merge_reports/20260312_family_qspec_runtime_queue.tsv"
queue_summary_tsv="${repo_root}/tools/merge_reports/20260312_family_qspec_runtime_queue_summary.tsv"
launch_registry="${state_dir}/launch_registry.tsv"

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
  (cd "$repo_root" && Rscript tools/merge_reports/20260312_build_family_qspec_reusable_state_audit.R "$repo_root" >/dev/null)
  (cd "$repo_root" && Rscript tools/merge_reports/20260312_build_family_qspec_runtime_queue.R "$repo_root" >/dev/null)
}

reap_stale_locks() {
  shopt -s nullglob
  for lock_dir in "$state_dir"/locks/*; do
    [[ -d "$lock_dir" ]] || continue
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
  tmux new-session -d -s "$session_name" "cd '$repo_root' && tools/merge_reports/20260312_family_qspec_worker.sh '$repo_root' '$state_dir' '$task_id' '$session_name'"
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
  ready_count="$(awk -F'\t' 'NR>1 && $12 == "TRUE" {c++} END {print c+0}' "$queue_tsv")"
  echo "$(date '+%Y-%m-%d %H:%M:%S') | active_slots=${active_slots} ready_count=${ready_count}"
  if [[ "$active_slots" -eq 0 && "$ready_count" -eq 0 ]]; then
    break
  fi
  sleep "$poll_sec"
done

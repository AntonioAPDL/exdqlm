#!/usr/bin/env bash
set -euo pipefail

repo_root="$(pwd)"
state_dir="/home/jaguir26/local/state/exdqlm/family_qspec_repair_v1"
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
queue_dir="${state_dir}/queue"
queue_tsv="${queue_dir}/20260314_family_qspec_repair_queue.tsv"
queue_summary_tsv="${queue_dir}/20260314_family_qspec_repair_queue_summary.tsv"

mode_arg="--dry-run"
if [[ "$mode" == "launch" ]]; then
  mode_arg="--launch"
fi

exec "${repo_root}/tools/merge_reports/20260312_family_qspec_supervisor.sh" \
  --repo-root "$repo_root" \
  --state-dir "$state_dir" \
  --slot-budget "$slot_budget" \
  --poll-sec "$poll_sec" \
  --queue-builder-script "tools/merge_reports/20260314_build_family_qspec_repair_queue.R" \
  --queue-tsv "$queue_tsv" \
  --queue-summary-tsv "$queue_summary_tsv" \
  "$mode_arg"

#!/usr/bin/env bash
set -euo pipefail

repo_root="${1:-$(pwd)}"
ledger_tsv="${repo_root}/tools/merge_reports/20260312_family_qspec_stop_ledger.tsv"
result_tsv="${repo_root}/tools/merge_reports/20260312_family_qspec_stop_results.tsv"

descendants() {
  local pid="$1"
  local kids
  kids="$(pgrep -P "$pid" || true)"
  for kid in $kids; do
    echo "$kid"
    descendants "$kid"
  done
}

printf 'session_name\tpane_pid\tlog_path\tcurrent_root_hint\tlast_log_line\tdescendant_pids\n' > "$ledger_tsv"

while IFS=$'\t' read -r session_name pane_id pane_pid pane_current_command pane_start_command; do
  [[ -n "$session_name" ]] || continue
  log_path="$(printf '%s\n' "$pane_start_command" | sed -n "s/.*> '\([^']*\.log\)'.*/\1/p")"
  current_root_hint=""
  last_log_line=""
  if [[ -n "$log_path" && -f "$log_path" ]]; then
    last_log_line="$(tail -n 1 "$log_path" | tr '\t' ' ')"
    if [[ "$session_name" == mqsp_jr_* ]]; then
      case "$session_name" in
        mqsp_jr_rsp100_*) current_root_hint='static_paper|gausmix|0.25|100|paper' ;;
        mqsp_jr_rsp1k_*) current_root_hint='static_paper|gausmix|0.25|1000|paper' ;;
        mqsp_jr_rss100h_*) current_root_hint='static_shrink|gausmix|0.25|100|rhs' ;;
        mqsp_jr_rss100r_*) current_root_hint='static_shrink|gausmix|0.25|100|ridge' ;;
        mqsp_jr_rss1kh_*) current_root_hint='static_shrink|gausmix|0.25|1000|rhs' ;;
        mqsp_jr_rss1kr_*) current_root_hint='static_shrink|gausmix|0.25|1000|ridge' ;;
        *) current_root_hint='resume_session_unmapped' ;;
      esac
    else
      current_root_hint="$(grep 'CASE start key=' "$log_path" | tail -n 1 | sed -n 's/.*CASE start key=\([^ ]*\).*/\1/p')"
    fi
  fi
  desc_pids="$(descendants "$pane_pid" | tr '\n' ',' | sed 's/,$//')"
  printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$session_name" "$pane_pid" "$log_path" "$current_root_hint" "$last_log_line" "$desc_pids" >> "$ledger_tsv"
done < <(tmux list-panes -a -F '#{session_name}	#{pane_id}	#{pane_pid}	#{pane_current_command}	#{pane_start_command}' 2>/dev/null | grep '^mqsp' || true)

printf 'session_name\tstatus\tnote\n' > "$result_tsv"
while IFS=$'\t' read -r session_name pane_pid log_path current_root_hint last_log_line desc_pids; do
  [[ "$session_name" == "session_name" ]] && continue
  tmux kill-session -t "$session_name" 2>/dev/null || true
  printf '%s\t%s\t%s\n' "$session_name" "tmux_killed" "$current_root_hint" >> "$result_tsv"
  IFS=',' read -r -a pid_arr <<< "$desc_pids"
  for pid in "${pid_arr[@]}"; do
    [[ -n "$pid" ]] || continue
    if kill -0 "$pid" 2>/dev/null; then
      kill "$pid" 2>/dev/null || true
    fi
  done
done < "$ledger_tsv"

sleep 2
while IFS=$'\t' read -r session_name pane_pid log_path current_root_hint last_log_line desc_pids; do
  [[ "$session_name" == "session_name" ]] && continue
  IFS=',' read -r -a pid_arr <<< "$desc_pids"
  for pid in "${pid_arr[@]}"; do
    [[ -n "$pid" ]] || continue
    if kill -0 "$pid" 2>/dev/null; then
      kill -9 "$pid" 2>/dev/null || true
    fi
  done
done < "$ledger_tsv"

echo "Wrote:"
echo "$ledger_tsv"
echo "$result_tsv"

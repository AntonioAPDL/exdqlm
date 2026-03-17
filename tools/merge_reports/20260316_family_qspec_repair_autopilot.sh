#!/usr/bin/env bash
set -euo pipefail

repo_root="$(pwd)"
state_dir="/home/jaguir26/local/state/exdqlm/family_qspec_repair_wave_20260316_200910"
slot_budget=25
poll_sec=20
monitor_sec=300
closeout_jobs=8
run_closeout=true

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
    --monitor-sec)
      monitor_sec="$2"
      shift 2
      ;;
    --closeout-jobs)
      closeout_jobs="$2"
      shift 2
      ;;
    --no-closeout)
      run_closeout=false
      shift
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

repo_root="$(cd "$repo_root" && pwd)"
state_dir="$(cd "$state_dir" && pwd)"
slot_budget="$(printf '%s' "$slot_budget" | sed 's/[^0-9].*$//')"
poll_sec="$(printf '%s' "$poll_sec" | sed 's/[^0-9].*$//')"
monitor_sec="$(printf '%s' "$monitor_sec" | sed 's/[^0-9].*$//')"
closeout_jobs="$(printf '%s' "$closeout_jobs" | sed 's/[^0-9].*$//')"
[[ -n "$slot_budget" ]] || slot_budget=25
[[ -n "$poll_sec" ]] || poll_sec=20
[[ -n "$monitor_sec" ]] || monitor_sec=300
[[ -n "$closeout_jobs" ]] || closeout_jobs=8
if (( slot_budget < 1 )); then slot_budget=25; fi
if (( poll_sec < 1 )); then poll_sec=20; fi
if (( monitor_sec < 5 )); then monitor_sec=300; fi
if (( closeout_jobs < 1 )); then closeout_jobs=1; fi

queue_dir="${state_dir}/queue"
queue_tsv="${queue_dir}/20260315_family_qspec_second_wave_queue.tsv"
queue_summary_tsv="${queue_dir}/20260315_family_qspec_second_wave_queue_summary.tsv"
locks_dir="${state_dir}/locks"
autopilot_dir="${state_dir}/autopilot"
autopilot_log="${autopilot_dir}/autopilot.log"
supervisor_log="${autopilot_dir}/supervisor.log"
status_tsv="${autopilot_dir}/autopilot_status.tsv"
pid_file="${autopilot_dir}/supervisor.pid"
final_summary="${autopilot_dir}/final_closeout_summary.md"

mkdir -p "$autopilot_dir" "$queue_dir" "$locks_dir"

log() {
  local line
  line="$(date '+%Y-%m-%d %H:%M:%S') | $*"
  echo "$line"
  echo "$line" >> "$autopilot_log"
}

expected_status_header='timestamp	active_locks	running_tasks	ready_unlocked	failed_tasks	supervisor_state	note'
if [[ ! -f "$status_tsv" ]]; then
  printf '%s\n' "$expected_status_header" > "$status_tsv"
else
  current_header="$(head -n 1 "$status_tsv" || true)"
  if [[ "$current_header" != "$expected_status_header" ]]; then
    tmp_status="${status_tsv}.tmp"
    printf '%s\n' "$expected_status_header" > "$tmp_status"
    awk -F'\t' '
      NR == 1 { next }
      NF >= 6 {
        # Backward compatibility with old 6-column format:
        # timestamp active_locks ready_unlocked failed_tasks supervisor_state note
        if (NF == 6) {
          printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\n", $1, $2, "NA", $3, $4, $5, $6
        } else {
          printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\n", $1, $2, $3, $4, $5, $6, $7
        }
      }
    ' "$status_tsv" >> "$tmp_status"
    mv "$tmp_status" "$status_tsv"
  fi
fi

supervisor_running() {
  if [[ ! -f "$pid_file" ]]; then
    return 1
  fi
  local pid
  pid="$(cat "$pid_file" 2>/dev/null || true)"
  [[ -n "$pid" ]] || return 1
  if ! kill -0 "$pid" 2>/dev/null; then
    return 1
  fi
  local args
  args="$(ps -p "$pid" -o args= 2>/dev/null || true)"
  if [[ "$args" == *"20260315_family_qspec_second_wave_supervisor.sh"* ]]; then
    return 0
  fi
  if [[ "$args" == *"20260312_family_qspec_supervisor.sh"* && "$args" == *"$state_dir"* ]]; then
    return 0
  fi
  return 1
}

start_supervisor() {
  nohup "${repo_root}/tools/merge_reports/20260315_family_qspec_second_wave_supervisor.sh" \
    --repo-root "$repo_root" \
    --state-dir "$state_dir" \
    --slot-budget "$slot_budget" \
    --poll-sec "$poll_sec" \
    --launch \
    >> "$supervisor_log" 2>&1 &
  local pid="$!"
  printf '%s\n' "$pid" > "$pid_file"
  log "started supervisor pid=${pid}"
}

refresh_queue() {
  (
    cd "$repo_root"
    Rscript tools/merge_reports/20260315_build_family_qspec_second_wave_decision.R "$repo_root" >/dev/null
    Rscript tools/merge_reports/20260315_build_family_qspec_second_wave_queue.R "$repo_root" "$state_dir" >/dev/null
  )
}

count_active_locks() {
  find "$locks_dir" -mindepth 1 -maxdepth 1 -type d | wc -l
}

count_ready_unlocked() {
  if [[ ! -f "$queue_tsv" ]]; then
    printf '0\n'
    return 0
  fi
  awk -F'\t' '
    NR == 1 { for (i = 1; i <= NF; i++) idx[$i] = i; next }
    $idx["launch_ready"] == "TRUE" { print $idx["task_id"] }
  ' "$queue_tsv" | while IFS= read -r task_id; do
    [[ -n "$task_id" ]] || continue
    [[ -d "$locks_dir/$task_id" ]] && continue
    printf '.'
  done | wc -c
}

count_failed_tasks() {
  if [[ ! -f "$queue_tsv" ]]; then
    printf '0\n'
    return 0
  fi
  awk -F'\t' '
    NR == 1 { for (i = 1; i <= NF; i++) idx[$i] = i; next }
    $idx["state"] == "failed" { c++ }
    END { print c + 0 }
  ' "$queue_tsv"
}

count_running_tasks() {
  if [[ ! -f "$queue_tsv" ]]; then
    printf '0\n'
    return 0
  fi
  awk -F'\t' '
    NR == 1 { for (i = 1; i <= NF; i++) idx[$i] = i; next }
    $idx["state"] == "running" { c++ }
    END { print c + 0 }
  ' "$queue_tsv"
}

run_full_refresh() {
  log "closeout: rebuilding signoff views (force)"
  (
    cd "$repo_root"
    # shellcheck disable=SC1091
    source tools/merge_reports/20260315_family_qspec_signoff_policy_second_wave.env
    EXDQLM_FQSG_REBUILD_JOBS="$closeout_jobs" \
      Rscript tools/merge_reports/20260314_build_family_qspec_signoff_views.R "$repo_root" --force
  )

  log "closeout: rebuilding dynamic root reviews"
  awk -F'\t' 'NR > 1 && $2 == "dynamic" { print $10 }' "${repo_root}/tools/merge_reports/20260312_family_qspec_root_catalog.tsv" \
    | while IFS= read -r run_root_rel; do
      [[ -n "$run_root_rel" ]] || continue
      Rscript "${repo_root}/tools/merge_reports/20260314_dynamic_vb_mcmc_report.R" "${repo_root}/${run_root_rel}"
    done

  log "closeout: rebuilding static root reviews"
  awk -F'\t' 'NR > 1 && $2 != "dynamic" { print $10 }' "${repo_root}/tools/merge_reports/20260312_family_qspec_root_catalog.tsv" \
    | while IFS= read -r run_root_rel; do
      [[ -n "$run_root_rel" ]] || continue
      EXDQLM_STATIC_RUN_ROOT="${repo_root}/${run_root_rel}" \
        Rscript "${repo_root}/tools/merge_reports/20260305_static_vb_mcmc_report.R"
    done

  log "closeout: rebuilding prior comparisons"
  awk -F'\t' 'NR > 1 && $2 == "prior_compare" { print $5 "\t" $6 "\t" $10 "\t" $11 }' "${repo_root}/tools/merge_reports/20260312_family_qspec_comparison_barriers.tsv" \
    | while IFS=$'\t' read -r tau fit_size prepared_root compare_root; do
      prepared_abs="${repo_root}/${prepared_root}"
      out_root_abs="${repo_root}/${compare_root}"
      ridge_run_root="${prepared_abs}/validation_shrink_ridge_tt${fit_size}"
      rhs_run_root="${prepared_abs}/validation_shrink_rhs_tt${fit_size}"
      EXDQLM_STATIC_SHRINK_SIM_PATH="${prepared_abs}/sim_output.rds" \
      EXDQLM_STATIC_SHRINK_RIDGE_RUN_ROOT="$ridge_run_root" \
      EXDQLM_STATIC_SHRINK_RHS_RUN_ROOT="$rhs_run_root" \
      EXDQLM_STATIC_SHRINK_TAUS="$tau" \
      EXDQLM_STATIC_SHRINK_OUT_ROOT="$out_root_abs" \
        Rscript "${repo_root}/tools/merge_reports/20260308_static_shrinkage_compare_report.R"
    done

  log "closeout: rebuilding campaign and global aggregates"
  awk -F'\t' 'NR > 1 && $2 == "campaign_review" { print $1 }' "${repo_root}/tools/merge_reports/20260312_family_qspec_comparison_barriers.tsv" \
    | while IFS= read -r task_id; do
      Rscript "${repo_root}/tools/merge_reports/20260312_family_qspec_campaign_aggregate.R" "$task_id" "$repo_root"
    done
  awk -F'\t' 'NR > 1 && $2 == "global_summary" { print $1 }' "${repo_root}/tools/merge_reports/20260312_family_qspec_comparison_barriers.tsv" \
    | while IFS= read -r task_id; do
      Rscript "${repo_root}/tools/merge_reports/20260312_family_qspec_campaign_aggregate.R" "$task_id" "$repo_root"
    done

  log "closeout: rebuilding scientific snapshot and deltas"
  (
    cd "$repo_root"
    Rscript tools/merge_reports/20260314_build_family_qspec_scientific_snapshot.R "$repo_root"
    Rscript tools/merge_reports/20260315_analyze_family_qspec_post_repair_delta.R "$repo_root"
    Rscript tools/merge_reports/20260315_analyze_family_qspec_threshold_rescue.R "$repo_root"
  )
}

build_final_summary() {
  local now pass warn fail eligible unhealthy alg model roots_full roots_any
  local delta_fail delta_eligible
  local signoff_tsv="${repo_root}/tools/merge_reports/20260314_family_qspec_signoff_summary.tsv"
  local delta_tsv="${repo_root}/tools/merge_reports/20260315_family_qspec_post_repair_signoff_delta.tsv"
  now="$(date '+%Y-%m-%d %H:%M:%S %Z')"

  pass="$(awk -F'\t' 'NR==1{for(i=1;i<=NF;i++)if($i=="method_fit_pass_count")c=i;next} NR==2{print $c}' "$signoff_tsv")"
  warn="$(awk -F'\t' 'NR==1{for(i=1;i<=NF;i++)if($i=="method_fit_warn_count")c=i;next} NR==2{print $c}' "$signoff_tsv")"
  fail="$(awk -F'\t' 'NR==1{for(i=1;i<=NF;i++)if($i=="method_fit_fail_count")c=i;next} NR==2{print $c}' "$signoff_tsv")"
  eligible="$(awk -F'\t' 'NR==1{for(i=1;i<=NF;i++)if($i=="method_fit_eligible_count")c=i;next} NR==2{print $c}' "$signoff_tsv")"
  unhealthy="$(awk -F'\t' 'NR==1{for(i=1;i<=NF;i++)if($i=="unhealthy_target_count")c=i;next} NR==2{print $c}' "$signoff_tsv")"
  alg="$(awk -F'\t' 'NR==1{for(i=1;i<=NF;i++)if($i=="algorithm_pair_eligible_count")c=i;next} NR==2{print $c}' "$signoff_tsv")"
  model="$(awk -F'\t' 'NR==1{for(i=1;i<=NF;i++)if($i=="model_pair_eligible_count")c=i;next} NR==2{print $c}' "$signoff_tsv")"
  roots_full="$(awk -F'\t' 'NR==1{for(i=1;i<=NF;i++)if($i=="root_full_eligible_count")c=i;next} NR==2{print $c}' "$signoff_tsv")"
  roots_any="$(awk -F'\t' 'NR==1{for(i=1;i<=NF;i++)if($i=="root_any_eligible_count")c=i;next} NR==2{print $c}' "$signoff_tsv")"

  delta_fail="$(awk -F'\t' '$1=="method_fit_fail_count"{print $4}' "$delta_tsv")"
  delta_eligible="$(awk -F'\t' '$1=="method_fit_eligible_count"{print $4}' "$delta_tsv")"

  {
    echo "# Family-QSpec Repair Autopilot Closeout"
    echo
    echo "- generated_at: \`${now}\`"
    echo "- state_dir: \`${state_dir}\`"
    echo
    echo "## Final Signoff"
    echo
    echo "- pass: \`${pass}\`"
    echo "- warn: \`${warn}\`"
    echo "- fail: \`${fail}\`"
    echo "- comparison_eligible: \`${eligible}\`"
    echo "- unhealthy_targets: \`${unhealthy}\`"
    echo "- algorithm_pair_eligible: \`${alg}\`"
    echo "- model_pair_eligible: \`${model}\`"
    echo "- root_full_eligible: \`${roots_full}\`"
    echo "- root_any_eligible: \`${roots_any}\`"
    echo
    echo "## Delta vs Baseline"
    echo
    echo "- method_fit_fail_count_delta: \`${delta_fail}\`"
    echo "- method_fit_eligible_count_delta: \`${delta_eligible}\`"
  } > "$final_summary"
}

log "autopilot started | state_dir=${state_dir} | slot_budget=${slot_budget} | monitor_sec=${monitor_sec}"
refresh_queue

if ! supervisor_running; then
  start_supervisor
else
  log "supervisor already running"
fi

while true; do
  refresh_queue
  active_locks="$(count_active_locks)"
  running_tasks="$(count_running_tasks)"
  ready_unlocked="$(count_ready_unlocked)"
  failed_tasks="$(count_failed_tasks)"

  supervisor_state="stopped"
  if supervisor_running; then
    supervisor_state="running"
  else
    if (( active_locks > 0 || ready_unlocked > 0 )); then
      start_supervisor
      supervisor_state="restarted"
    fi
  fi

  now="$(date '+%Y-%m-%d %H:%M:%S')"
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$now" "$active_locks" "$running_tasks" "$ready_unlocked" "$failed_tasks" "$supervisor_state" "poll" >> "$status_tsv"
  log "poll | active_locks=${active_locks} running_tasks=${running_tasks} ready_unlocked=${ready_unlocked} failed_tasks=${failed_tasks} supervisor=${supervisor_state}"

  if (( active_locks == 0 && running_tasks == 0 && ready_unlocked == 0 )); then
    break
  fi
  sleep "$monitor_sec"
done

log "queue drained"

if [[ "$run_closeout" == "true" ]]; then
  run_full_refresh
  build_final_summary
  log "closeout complete | summary=${final_summary}"
else
  log "closeout skipped by flag"
fi

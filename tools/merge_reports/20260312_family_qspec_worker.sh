#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 4 || $# -gt 5 ]]; then
  echo "Usage: $0 <repo_root> <state_dir> <task_id> <session_name> [queue_tsv]" >&2
  exit 1
fi

repo_root="$1"
state_dir="$2"
task_id="$3"
session_name="$4"
queue_tsv="${5:-${repo_root}/tools/merge_reports/20260312_family_qspec_runtime_queue.tsv}"
log_dir="${state_dir}/worker_logs"
lock_dir="${state_dir}/locks/${task_id}"
log_path="${log_dir}/${task_id}.log"

mkdir -p "$log_dir" "$state_dir"
exec > >(tee -a "$log_path") 2>&1

export OMP_NUM_THREADS=1
export OPENBLAS_NUM_THREADS=1
export MKL_NUM_THREADS=1
export VECLIB_MAXIMUM_THREADS=1
export NUMEXPR_NUM_THREADS=1
export EXDQLM_STATIC_PIPELINE_CORES=1
export EXDQLM_STATIC_RESUME_CORES=1
export EXDQLM_PIPELINE_CORES=1
export EXDQLM_DYNAMIC_RESUME_CORES=1
export EXDQLM_MCMC_BURN="${EXDQLM_MCMC_BURN:-${EXDQLM_DYNAMIC_MCMC_BURN:-500}}"
export EXDQLM_MCMC_N="${EXDQLM_MCMC_N:-${EXDQLM_DYNAMIC_MCMC_N:-1000}}"
export EXDQLM_STATIC_MCMC_BURN="${EXDQLM_STATIC_MCMC_BURN:-${EXDQLM_MCMC_BURN:-500}}"
export EXDQLM_STATIC_MCMC_N="${EXDQLM_STATIC_MCMC_N:-${EXDQLM_MCMC_N:-1000}}"
export EXDQLM_DYNAMIC_MCMC_BURN="${EXDQLM_DYNAMIC_MCMC_BURN:-${EXDQLM_MCMC_BURN:-500}}"
export EXDQLM_DYNAMIC_MCMC_N="${EXDQLM_DYNAMIC_MCMC_N:-${EXDQLM_MCMC_N:-1000}}"
export EXDQLM_STATIC_MCMC_VERBOSE="${EXDQLM_STATIC_MCMC_VERBOSE:-true}"
export EXDQLM_DYNAMIC_MCMC_VERBOSE="${EXDQLM_DYNAMIC_MCMC_VERBOSE:-true}"
export EXDQLM_STATIC_MCMC_TRACE_DIAGNOSTICS="${EXDQLM_STATIC_MCMC_TRACE_DIAGNOSTICS:-true}"
export EXDQLM_DYNAMIC_MCMC_TRACE_DIAGNOSTICS="${EXDQLM_DYNAMIC_MCMC_TRACE_DIAGNOSTICS:-true}"
export EXDQLM_STATIC_MCMC_TRACE_EVERY="${EXDQLM_STATIC_MCMC_TRACE_EVERY:-25}"
export EXDQLM_DYNAMIC_MCMC_TRACE_EVERY="${EXDQLM_DYNAMIC_MCMC_TRACE_EVERY:-25}"
export EXDQLM_MCMC_PROGRESS_EVERY="${EXDQLM_MCMC_PROGRESS_EVERY:-10}"
export EXDQLM_WORKER_HEARTBEAT_SEC="${EXDQLM_WORKER_HEARTBEAT_SEC:-60}"

task_succeeded=0
task_signal=""
child_pid=""
heartbeat_pid=""

append_event() {
  local event="$1"
  local note="$2"
  local now
  now="$(date '+%Y-%m-%d %H:%M:%S')"
  (
    flock 9
    if [[ ! -f "${state_dir}/task_events.tsv" ]]; then
      printf 'timestamp\ttask_id\tsession_name\tevent\tnote\n' > "${state_dir}/task_events.tsv"
    fi
    printf '%s\t%s\t%s\t%s\t%s\n' "$now" "$task_id" "$session_name" "$event" "$note" >> "${state_dir}/task_events.tsv"
  ) 9>"${state_dir}/task_events.lock"
}

cleanup() {
  local rc=$?
  if [[ -n "${heartbeat_pid}" ]] && kill -0 "${heartbeat_pid}" 2>/dev/null; then
    kill "${heartbeat_pid}" 2>/dev/null || true
    wait "${heartbeat_pid}" 2>/dev/null || true
  fi
  if [[ "${task_succeeded}" -eq 1 ]]; then
    append_event "DONE" "worker completed successfully"
  elif [[ -n "${task_signal}" ]]; then
    append_event "FAILED" "worker interrupted by ${task_signal} rc=${rc}"
  else
    append_event "FAILED" "worker exited with rc=${rc}"
  fi
  rm -rf "$lock_dir"
}
trap cleanup EXIT
trap 'task_signal="HUP"; exit 129' HUP
trap 'task_signal="INT"; exit 130' INT
trap 'task_signal="TERM"; exit 143' TERM

row="$(awk -F'\t' -v task_id="$task_id" '
  NR==1 { for (i = 1; i <= NF; i++) idx[$i] = i; next }
  $idx["task_id"] == task_id { print; exit }
' "$queue_tsv")"
if [[ -z "$row" ]]; then
  echo "Task not found in queue: $task_id" >&2
  exit 1
fi

IFS=$'\t' read -r task_id unit_type root_id barrier_id root_kind family tau fit_size prior model state launch_ready launch_mode slot_cost priority prepared_root run_root script_ref notes <<< "$row"
append_event "START" "unit_type=${unit_type} launch_mode=${launch_mode}"

echo "worker task_id=${task_id} unit_type=${unit_type} root_kind=${root_kind} family=${family} tau=${tau} fit_size=${fit_size} prior=${prior} model=${model} launch_mode=${launch_mode}"

prepared_abs=""
run_root_abs=""
if [[ -n "$prepared_root" && "$prepared_root" != "NA" ]]; then
  prepared_abs="${repo_root}/${prepared_root}"
fi
if [[ -n "$run_root" && "$run_root" != "NA" ]]; then
  run_root_abs="${repo_root}/${run_root}"
fi

status_tail_file=""
if [[ "$unit_type" == "model_path" ]]; then
  tau_status="$(printf '%s' "$tau" | sed 's/\\./p/g')"
  status_tail_file="${run_root_abs}/logs/${model}_tau_${tau_status}.status.tsv"
fi

start_heartbeat() {
  local pid="$1"
  local interval
  interval="$(printf '%s' "${EXDQLM_WORKER_HEARTBEAT_SEC:-60}" | sed 's/[^0-9].*$//')"
  [[ -n "$interval" ]] || interval=60
  if (( interval < 5 )); then
    interval=5
  fi
  (
    while kill -0 "$pid" 2>/dev/null; do
      stamp=""
      elapsed=""
      cpu=""
      rss_kb=""
      status_tail=""
      stamp="$(date '+%Y-%m-%d %H:%M:%S')"
      elapsed="$(ps -p "$pid" -o etimes= 2>/dev/null | awk '{print $1}')"
      cpu="$(ps -p "$pid" -o pcpu= 2>/dev/null | awk '{print $1}')"
      rss_kb="$(ps -p "$pid" -o rss= 2>/dev/null | awk '{print $1}')"
      status_tail=""
      if [[ -n "$status_tail_file" && -f "$status_tail_file" ]]; then
        status_tail="$(tail -n 1 "$status_tail_file" | tr '\t' ' ')"
      fi
      printf '%s | worker heartbeat | task_id=%s | pid=%s | elapsed_s=%s | cpu=%s | rss_mb=%.1f' \
        "$stamp" "$task_id" "$pid" "${elapsed:-NA}" "${cpu:-NA}" \
        "$(awk -v kb="${rss_kb:-0}" 'BEGIN{printf "%.1f", kb/1024}')" 
      if [[ -n "$status_tail" ]]; then
        printf ' | status_tail=%s' "$status_tail"
      fi
      printf '\n'
      sleep "$interval"
    done
  ) &
  heartbeat_pid="$!"
}

run_and_watch() {
  "$@" &
  child_pid="$!"
  start_heartbeat "$child_pid"
  wait "$child_pid"
}

case "$unit_type" in
  model_path)
    mkdir -p "$run_root_abs"
    if [[ "$root_kind" == "dynamic" ]]; then
      if [[ "$launch_mode" == "resume_mcmc_from_vb" ]]; then
        run_and_watch env \
          EXDQLM_DYNAMIC_RUN_CONFIG="${run_root_abs}/tables/run_config.rds" \
          EXDQLM_DYNAMIC_RESUME_MODELS="$model" \
          nice -n 10 Rscript "${repo_root}/tools/merge_reports/20260305_resume_dynamic_mcmc_from_vb.R"
      else
        run_and_watch env \
          EXDQLM_DYNAMIC_SIM_PATH="${prepared_abs}/sim_output.rds" \
          EXDQLM_PIPELINE_TT="$fit_size" \
          EXDQLM_DYNAMIC_PIPELINE_TAU="$tau" \
          EXDQLM_DYNAMIC_PIPELINE_MODELS="$model" \
          EXDQLM_DYNAMIC_OUT_ROOT="$run_root_abs" \
          EXDQLM_DYNAMIC_PIPELINE_LABEL="${session_name}" \
          nice -n 10 Rscript "${repo_root}/tools/merge_reports/20260305_vb_then_mcmc_pipeline.R"
      fi
    else
      prior_use="$prior"
      if [[ "$root_kind" == "static_paper" ]]; then
        prior_use="ridge"
      fi
      if [[ "$launch_mode" == "resume_mcmc_from_vb" ]]; then
        run_and_watch env \
          EXDQLM_STATIC_RUN_CONFIG="${run_root_abs}/tables/run_config.rds" \
          EXDQLM_STATIC_BETA_PRIOR="$prior_use" \
          EXDQLM_STATIC_ENFORCE_PRIOR_MATCH="true" \
          EXDQLM_STATIC_RESUME_MODELS="$model" \
          nice -n 10 Rscript "${repo_root}/tools/merge_reports/20260305_resume_static_mcmc_from_vb.R"
      else
        run_and_watch env \
          EXDQLM_STATIC_SIM_PATH="${prepared_abs}/sim_output.rds" \
          EXDQLM_STATIC_PIPELINE_TT="$fit_size" \
          EXDQLM_STATIC_PIPELINE_TAU="$tau" \
          EXDQLM_STATIC_PIPELINE_MODELS="$model" \
          EXDQLM_STATIC_BETA_PRIOR="$prior_use" \
          EXDQLM_STATIC_ENFORCE_PRIOR_MATCH="true" \
          EXDQLM_STATIC_OUT_ROOT="$run_root_abs" \
          EXDQLM_STATIC_PIPELINE_LABEL="${session_name}" \
          nice -n 10 Rscript "${repo_root}/tools/merge_reports/20260305_static_vb_then_mcmc_pipeline.R"
      fi
    fi
    ;;
  root_postprocess)
    if [[ "$root_kind" == "dynamic" ]]; then
      run_and_watch env EXDQLM_DYNAMIC_RUN_ROOT="$run_root_abs" nice -n 10 Rscript "${repo_root}/tools/merge_reports/20260305_postprocess_from_existing_fits.R"
    else
      run_and_watch env EXDQLM_STATIC_RUN_ROOT="$run_root_abs" nice -n 10 Rscript "${repo_root}/tools/merge_reports/20260305_static_postprocess_from_existing_fits.R"
    fi
    ;;
  root_signoff)
    run_and_watch nice -n 10 Rscript "${repo_root}/tools/merge_reports/20260314_family_qspec_root_signoff.R" "$run_root_abs" "$repo_root"
    ;;
  root_review)
    if [[ "$root_kind" == "dynamic" ]]; then
      run_and_watch nice -n 10 Rscript "${repo_root}/tools/merge_reports/20260314_dynamic_vb_mcmc_report.R" "$run_root_abs"
    else
      run_and_watch env EXDQLM_STATIC_RUN_ROOT="$run_root_abs" nice -n 10 Rscript "${repo_root}/tools/merge_reports/20260305_static_vb_mcmc_report.R"
    fi
    ;;
  prior_compare)
    compare_out_root="$run_root_abs"
    ridge_run_root="${repo_root}/${prepared_root}/validation_shrink_ridge_tt${fit_size}"
    rhs_run_root="${repo_root}/${prepared_root}/validation_shrink_rhs_tt${fit_size}"
    run_and_watch env \
      EXDQLM_STATIC_SHRINK_SIM_PATH="${prepared_abs}/sim_output.rds" \
      EXDQLM_STATIC_SHRINK_RIDGE_RUN_ROOT="$ridge_run_root" \
      EXDQLM_STATIC_SHRINK_RHS_RUN_ROOT="$rhs_run_root" \
      EXDQLM_STATIC_SHRINK_TAUS="$tau" \
      EXDQLM_STATIC_SHRINK_OUT_ROOT="$compare_out_root" \
      nice -n 10 Rscript "${repo_root}/tools/merge_reports/20260308_static_shrinkage_compare_report.R"
    ;;
  campaign_review|global_summary)
    run_and_watch nice -n 10 Rscript "${repo_root}/tools/merge_reports/20260312_family_qspec_campaign_aggregate.R" "$task_id" "$repo_root"
    ;;
  *)
    echo "Unsupported unit_type: $unit_type" >&2
    exit 1
    ;;
esac

Rscript "${repo_root}/tools/merge_reports/20260312_verify_family_qspec_task_completion.R" "$repo_root" "$task_id"
echo "post-run verification passed for ${task_id}"
task_succeeded=1

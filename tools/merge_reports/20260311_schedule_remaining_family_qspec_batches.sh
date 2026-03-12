#!/usr/bin/env bash
set -euo pipefail

repo_root="/data/muscat_data/jaguir26/exdqlm__wt__0.3.0-cpp"
cd "$repo_root"

stamp="$(date '+%Y%m%d_%H%M%S')"
master_log="tools/merge_reports/family_qspec_remaining_queue_${stamp}.log"
manifest="tools/merge_reports/family_qspec_remaining_queue_${stamp}.tsv"
status_tsv="tools/merge_reports/family_qspec_remaining_queue_status_${stamp}.tsv"

max_load="${FAMILY_QSPEC_QUEUE_MAX_LOAD:-96}"
poll_seconds="${FAMILY_QSPEC_QUEUE_POLL_SECONDS:-300}"

static_pipeline_cores="${EXDQLM_STATIC_PIPELINE_CORES:-4}"
static_resume_cores="${EXDQLM_STATIC_RESUME_CORES:-4}"
dynamic_pipeline_cores="${EXDQLM_PIPELINE_CORES:-2}"
dynamic_resume_cores="${EXDQLM_DYNAMIC_RESUME_CORES:-2}"

queue_labels=(
  "static_paper_tt100"
  "static_paper_tt1000"
  "static_shrink_ridge_tt100"
  "static_shrink_rhs_tt100"
  "static_shrink_ridge_tt1000"
  "static_shrink_rhs_tt1000"
  "dynamic_tt500"
  "dynamic_tt5000"
)

queue_cmds=(
  "bash tools/merge_reports/20260310_resume_family_qspec_static_batch.sh paper 100"
  "bash tools/merge_reports/20260310_resume_family_qspec_static_batch.sh paper 1000"
  "bash tools/merge_reports/20260310_resume_family_qspec_static_batch.sh shrink 100 ridge"
  "bash tools/merge_reports/20260310_resume_family_qspec_static_batch.sh shrink 100 rhs"
  "bash tools/merge_reports/20260310_resume_family_qspec_static_batch.sh shrink 1000 ridge"
  "bash tools/merge_reports/20260310_resume_family_qspec_static_batch.sh shrink 1000 rhs"
  "bash tools/merge_reports/20260310_resume_family_qspec_dynamic_batch.sh 500"
  "bash tools/merge_reports/20260310_resume_family_qspec_dynamic_batch.sh 5000"
)

queue_logs=(
  "tools/merge_reports/family_qspec_queue_static_paper_tt100_${stamp}.log"
  "tools/merge_reports/family_qspec_queue_static_paper_tt1000_${stamp}.log"
  "tools/merge_reports/family_qspec_queue_static_shrink_ridge_tt100_${stamp}.log"
  "tools/merge_reports/family_qspec_queue_static_shrink_rhs_tt100_${stamp}.log"
  "tools/merge_reports/family_qspec_queue_static_shrink_ridge_tt1000_${stamp}.log"
  "tools/merge_reports/family_qspec_queue_static_shrink_rhs_tt1000_${stamp}.log"
  "tools/merge_reports/family_qspec_queue_dynamic_tt500_${stamp}.log"
  "tools/merge_reports/family_qspec_queue_dynamic_tt5000_${stamp}.log"
)

log_master() {
  printf '%s | %s\n' "$(date '+%F %T')" "$*" | tee -a "$master_log"
}

append_status() {
  printf '%s\t%s\t%s\t%s\n' "$(date '+%F %T')" "$1" "$2" "$3" >> "$status_tsv"
}

active_qsp_sessions() {
  tmux list-sessions -F '#S' 2>/dev/null | awk '/^qsp_/ {print}'
}

load_below_cap() {
  local one_min
  one_min="$(awk '{print $1}' /proc/loadavg)"
  awk -v load="$one_min" -v cap="$max_load" 'BEGIN { exit !(load + 0 <= cap + 0) }'
}

wait_for_headroom() {
  while true; do
    local sessions
    sessions="$(active_qsp_sessions || true)"
    if [[ -z "${sessions}" ]] && load_below_cap; then
      log_master "headroom ready: no active qsp sessions and load <= ${max_load}"
      return 0
    fi

    local session_count
    session_count="$(printf '%s\n' "${sessions}" | sed '/^$/d' | wc -l)"
    log_master "waiting: active_qsp_sessions=${session_count} max_load=${max_load} current_load=$(awk '{print $1}' /proc/loadavg)"
    if [[ -n "${sessions}" ]]; then
      printf '%s\n' "${sessions}" | sed 's/^/  - /' | tee -a "$master_log"
    fi
    sleep "${poll_seconds}"
  done
}

printf 'order\tlabel\tlog\tcmd\n' > "$manifest"
printf 'timestamp\tlabel\tstage\tnote\n' > "$status_tsv"
for i in "${!queue_labels[@]}"; do
  printf '%s\t%s\t%s\t%s\n' "$((i + 1))" "${queue_labels[$i]}" "${queue_logs[$i]}" "${queue_cmds[$i]}" >> "$manifest"
done

log_master "queue start"
log_master "manifest=${manifest}"
log_master "status_tsv=${status_tsv}"
log_master "core caps: static_pipeline=${static_pipeline_cores} static_resume=${static_resume_cores} dynamic_pipeline=${dynamic_pipeline_cores} dynamic_resume=${dynamic_resume_cores}"

wait_for_headroom

for i in "${!queue_labels[@]}"; do
  label="${queue_labels[$i]}"
  cmd="${queue_cmds[$i]}"
  item_log="${queue_logs[$i]}"

  append_status "${label}" "START" "${item_log}"
  log_master "running ${label} -> ${cmd}"

  if env \
    OMP_NUM_THREADS=1 \
    OPENBLAS_NUM_THREADS=1 \
    MKL_NUM_THREADS=1 \
    VECLIB_MAXIMUM_THREADS=1 \
    NUMEXPR_NUM_THREADS=1 \
    EXDQLM_STATIC_PIPELINE_CORES="${static_pipeline_cores}" \
    EXDQLM_STATIC_RESUME_CORES="${static_resume_cores}" \
    EXDQLM_PIPELINE_CORES="${dynamic_pipeline_cores}" \
    EXDQLM_DYNAMIC_RESUME_CORES="${dynamic_resume_cores}" \
    nice -n 10 bash -lc "cd '$repo_root' && ${cmd}" > "${item_log}" 2>&1; then
    append_status "${label}" "DONE" "${item_log}"
    log_master "done ${label}"
  else
    append_status "${label}" "FAILED" "${item_log}"
    log_master "failed ${label}; see ${item_log}"
    exit 1
  fi
done

log_master "queue complete"

#!/usr/bin/env bash
set -uo pipefail

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

stage="qdesn_dynamic_fitforecast_v2_tt500_mcmc_vb_candidate_full_confirmation"
defaults="config/validation/${stage}_defaults.yaml"
grid="config/validation/${stage}_grid.csv"

small_label="normal025_al_mcvbc015"
small_spec="qdesn__normal__0p25__tt500__rhs_ns__mcmc__al__f4b36d511fd66d"

large_label="normal005_exal_mcvbc058"
large_spec="qdesn__normal__0p05__tt500__rhs_ns__mcmc__exal__c2c2db8dd29f9e"

git_short="$(git rev-parse --short HEAD)"
git_sha="$(git rev-parse HEAD)"
git_branch="$(git branch --show-current)"
stamp="${QDESN_REMAINDER_STAMP:-$(date +%Y%m%d-%H%M%S)}"
manager_tag="qdesn-tt500-mcmc-vbcandidate-remainder-${stamp}__git-${git_short}"
log_root="reports/qdesn_mcmc_validation/${stage}/orchestration_background/${manager_tag}"
mkdir -p "${log_root}/logs" "${log_root}/manifest"
manager_log="${log_root}/logs/remainder_manager.log"

memory_gate_gib="${QDESN_REMAINDER_LARGE_MEM_GATE_GIB:-80}"
load_gate="${QDESN_REMAINDER_LARGE_LOAD_GATE:-60}"
gate_sleep_seconds="${QDESN_REMAINDER_GATE_SLEEP_SECONDS:-1800}"
dry_run="${QDESN_REMAINDER_DRY_RUN:-false}"

log() {
  printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S %Z')" "$*" | tee -a "$manager_log"
}

shell_join() {
  local out="" arg
  for arg in "$@"; do
    printf -v out '%s %q' "$out" "$arg"
  done
  printf '%s\n' "${out# }"
}

mem_available_gib() {
  awk '/MemAvailable/ { printf "%.1f", $2 / 1048576 }' /proc/meminfo
}

load_one() {
  awk '{ print $1 }' /proc/loadavg
}

float_ge() {
  awk -v x="$1" -v y="$2" 'BEGIN { exit !((x + 0) >= (y + 0)) }'
}

float_le() {
  awk -v x="$1" -v y="$2" 'BEGIN { exit !((x + 0) <= (y + 0)) }'
}

write_manifest() {
  cat > "${log_root}/manifest/remainder_resume_manifest.txt" <<EOF
manager_tag=${manager_tag}
stage=${stage}
git_branch=${git_branch}
git_sha=${git_sha}
defaults=${defaults}
grid=${grid}
small_label=${small_label}
small_spec=${small_spec}
large_label=${large_label}
large_spec=${large_spec}
memory_gate_gib=${memory_gate_gib}
load_gate=${load_gate}
gate_sleep_seconds=${gate_sleep_seconds}
dry_run=${dry_run}
policy=fresh_run_tags_workers1_static_scheduler_no_overwrite
EOF
}

build_cmd() {
  local run_tag="$1"
  local spec_id="$2"
  printf '%s\0' \
    Rscript \
    scripts/run_qdesn_dynamic_exdqlm_crossstudy_validation.R \
    --defaults "$defaults" \
    --grid "$grid" \
    --methods mcmc \
    --likelihoods al,exal \
    --fit-sizes 500 \
    --priors rhs_ns \
    --scheduler static \
    --allow-grid-subset \
    --workers 1 \
    --no-plots \
    --batch full \
    --run-tag "$run_tag" \
    --spec-ids "$spec_id" \
    --stream-child-stdout
}

run_spec() {
  local label="$1"
  local spec_id="$2"
  local run_tag="qdesn-tt500-mcmc-vbcandidate-remainder-${label}-${stamp}__git-${git_short}"
  local cmd_file="${log_root}/logs/${label}_command.txt"
  local stdout_log="${log_root}/logs/${label}.stdout.log"
  local status_file="${log_root}/manifest/${label}_exit_status.txt"

  mapfile -d '' cmd < <(build_cmd "$run_tag" "$spec_id")
  shell_join "${cmd[@]}" > "$cmd_file"

  log "starting ${label}: ${spec_id}"
  log "run_tag ${run_tag}"
  log "command ${cmd_file}"
  log "stdout ${stdout_log}"

  if [[ "$dry_run" == "true" ]]; then
    echo "DRY_RUN" > "$status_file"
    log "dry-run: command not executed for ${label}"
    return 0
  fi

  "${cmd[@]}" > "$stdout_log" 2>&1
  local status=$?
  echo "$status" > "$status_file"
  if [[ "$status" -eq 0 ]]; then
    log "completed ${label} with status 0"
  else
    log "completed ${label} with nonzero status ${status}; see ${stdout_log}"
  fi
  return "$status"
}

wait_for_large_gate() {
  if [[ "$dry_run" == "true" ]]; then
    log "dry-run: skipping large-root resource gate"
    return 0
  fi
  while true; do
    local mem_gib load
    mem_gib="$(mem_available_gib)"
    load="$(load_one)"
    if float_ge "$mem_gib" "$memory_gate_gib" && float_le "$load" "$load_gate"; then
      log "large-root gate passed: MemAvailable=${mem_gib}GiB, load1=${load}"
      return 0
    fi
    log "large-root gate waiting: MemAvailable=${mem_gib}GiB < ${memory_gate_gib}GiB or load1=${load} > ${load_gate}; sleeping ${gate_sleep_seconds}s"
    sleep "$gate_sleep_seconds"
  done
}

write_manifest
log "Q-DESN MCMC VB-candidate remainder manager started"
log "repo ${repo_root}"
log "branch ${git_branch}; sha ${git_sha}"
log "git_dirty_count $(git status --porcelain | wc -l | tr -d ' ')"

small_status=0
large_status=0

run_spec "$small_label" "$small_spec"
small_status=$?

wait_for_large_gate
run_spec "$large_label" "$large_spec"
large_status=$?

cat > "${log_root}/manifest/remainder_resume_exit_summary.txt" <<EOF
small_status=${small_status}
large_status=${large_status}
finished_at=$(date '+%Y-%m-%d %H:%M:%S %Z')
EOF

if [[ "$small_status" -ne 0 || "$large_status" -ne 0 ]]; then
  log "remainder manager finished with nonzero child status: small=${small_status}, large=${large_status}"
  exit 1
fi

log "remainder manager finished successfully"

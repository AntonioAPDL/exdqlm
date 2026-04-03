#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
out_dir="$repo_root/tools/merge_reports"
prepare_script="$out_dir/LOCAL_static_exal_wave8_transfer_resume_prepare_20260403.R"
resume_launch="$out_dir/LOCAL_static_exal_wave8_transfer_resume_launch_20260403.sh"

parallel_jobs="6"
max_passes="6"
stagnant_limit="2"
log_path="$out_dir/LOCAL_static_exal_wave8_resume_supervisor_20260403.log"

for arg in "$@"; do
  case "$arg" in
    --parallel-jobs=*) parallel_jobs="${arg#*=}" ;;
    --max-passes=*) max_passes="${arg#*=}" ;;
    --stagnant-limit=*) stagnant_limit="${arg#*=}" ;;
    --log-path=*) log_path="${arg#*=}" ;;
    *) ;;
  esac
done

if [[ ! -f "$prepare_script" ]]; then
  echo "resume prepare script missing: $prepare_script" >&2
  exit 2
fi
if [[ ! -f "$resume_launch" ]]; then
  echo "resume launch script missing: $resume_launch" >&2
  exit 2
fi

mkdir -p "$(dirname "$log_path")"
touch "$log_path"
exec >> "$log_path" 2>&1

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S %Z')] $*"
}

compute_missing() {
  local stage="$1"
  local rows_tsv
  rows_tsv="$(mktemp "/tmp/exdqlm_wave8_${stage}_resume_rows_XXXX.tsv")"
  trap 'rm -f "$rows_tsv"' RETURN
  Rscript "$prepare_script" --stage="$stage" --out="$rows_tsv" >/dev/null 2>&1 || true
  if [[ -s "$rows_tsv" ]]; then
    wc -l < "$rows_tsv" | tr -d ' '
  else
    echo "0"
  fi
}

run_stage() {
  local stage="$1"
  local pass=0
  local stagnant=0
  local prev_missing="NA"

  while true; do
    pass=$((pass + 1))
    local missing
    missing="$(compute_missing "$stage")"
    log "[wave8-supervisor] stage=${stage} pass=${pass} missing=${missing}"

    if [[ "$missing" == "0" ]]; then
      log "[wave8-supervisor] stage=${stage} complete"
      return 0
    fi

    if [[ "$prev_missing" == "$missing" ]]; then
      stagnant=$((stagnant + 1))
    else
      stagnant=0
    fi
    prev_missing="$missing"

    if [[ "$stagnant" -ge "$stagnant_limit" ]]; then
      log "[wave8-supervisor] stage=${stage} stalled (missing=${missing})"
      return 0
    fi

    if [[ "$pass" -gt "$max_passes" ]]; then
      log "[wave8-supervisor] stage=${stage} reached max passes (${max_passes})"
      return 0
    fi

    log "[wave8-supervisor] launching stage=${stage} pass=${pass}"
    bash "$resume_launch" --stage="$stage" --parallel-jobs="$parallel_jobs" || true
  done
}

log "[wave8-supervisor] start parallel_jobs=${parallel_jobs} max_passes=${max_passes} stagnant_limit=${stagnant_limit}"
run_stage "guard8"
run_stage "mix12_transfer"
log "[wave8-supervisor] finished"

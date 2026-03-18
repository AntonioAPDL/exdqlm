#!/usr/bin/env bash
set -euo pipefail

repo_root="$(pwd)"
state_dir="/home/jaguir26/local/state/exdqlm/family_qspec_vb_debug_v1"
slot_budget=5
poll_sec=20
mode="dry_run"
targets_tsv="tools/merge_reports/20260315_family_qspec_second_wave_vb_debug_targets.tsv"
queue_prefix="20260317_family_qspec_vb_debug_wave"
tuning_env_rel="tools/merge_reports/20260317_family_qspec_vb_debug_tuning.env"

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
    --targets-tsv)
      targets_tsv="$2"
      shift 2
      ;;
    --queue-prefix)
      queue_prefix="$2"
      shift 2
      ;;
    --tuning-env)
      tuning_env_rel="$2"
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
if [[ "$targets_tsv" = /* ]]; then
  targets_tsv_abs="$targets_tsv"
else
  targets_tsv_abs="${repo_root}/${targets_tsv}"
fi
if [[ ! -f "$targets_tsv_abs" ]]; then
  echo "Targets TSV not found: $targets_tsv_abs" >&2
  exit 1
fi
tuning_env_abs="$tuning_env_rel"
if [[ "$tuning_env_abs" != /* ]]; then
  tuning_env_abs="${repo_root}/${tuning_env_abs}"
fi
if [[ ! -f "$tuning_env_abs" ]]; then
  echo "Tuning env file not found: $tuning_env_abs" >&2
  exit 1
fi

# shellcheck disable=SC1091
source "${repo_root}/tools/merge_reports/20260315_family_qspec_signoff_policy_second_wave.env"
# shellcheck disable=SC1091
source "$tuning_env_abs"

export EXDQLM_RESUME_OVERWRITE=true
export EXDQLM_DYNAMIC_RESUME_OVERWRITE=true
export EXDQLM_STATIC_RESUME_OVERWRITE=true
export EXDQLM_STATIC_ENFORCE_PRIOR_MATCH=true

queue_dir="${state_dir}/queue"
queue_tsv="${queue_dir}/${queue_prefix}_queue.tsv"
queue_summary_tsv="${queue_dir}/${queue_prefix}_queue_summary.tsv"
mkdir -p "$queue_dir"

mode_arg="--dry-run"
if [[ "$mode" == "launch" ]]; then
  mode_arg="--launch"
fi

exec env \
  EXDQLM_FQ_REPAIR_TARGETS_TSV="$targets_tsv_abs" \
  EXDQLM_FQ_REPAIR_QUEUE_PREFIX="$queue_prefix" \
  EXDQLM_FQ_REPAIR_FORCE_LAUNCH_MODE="fresh_vb_then_mcmc" \
  EXDQLM_FQ_REPAIR_NOTE_PREFIX="vb_debug_wave" \
  "${repo_root}/tools/merge_reports/20260312_family_qspec_supervisor.sh" \
    --repo-root "$repo_root" \
    --state-dir "$state_dir" \
    --slot-budget "$slot_budget" \
    --poll-sec "$poll_sec" \
    --queue-builder-script "tools/merge_reports/20260314_build_family_qspec_repair_queue.R" \
    --queue-tsv "$queue_tsv" \
    --queue-summary-tsv "$queue_summary_tsv" \
    "$mode_arg"

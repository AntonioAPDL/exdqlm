#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
out_dir="$repo_root/tools/merge_reports"
prepare_script="$out_dir/LOCAL_static_exal_wave8_transfer_resume_prepare_20260403.R"
runner="$out_dir/LOCAL_static_exal_case_runner_20260323.R"

stage="guard8"
parallel_jobs="6"
force="0"
keep_going="1"
n_burn="1500"
n_mcmc="5000"
thin="1"
trace_every="50"
progress_every="50"
mh_proposal="laplace_rw"
mh_adapt="true"
slice_width="0.12"
slice_max_steps="80"
init_mode="baseline_last"

for arg in "$@"; do
  case "$arg" in
    --stage=*) stage="${arg#*=}" ;;
    --parallel-jobs=*) parallel_jobs="${arg#*=}" ;;
    --force) force="1" ;;
    --stop-on-error) keep_going="0" ;;
    --n-burn=*) n_burn="${arg#*=}" ;;
    --n-mcmc=*) n_mcmc="${arg#*=}" ;;
    --thin=*) thin="${arg#*=}" ;;
    --trace-every=*) trace_every="${arg#*=}" ;;
    --progress-every=*) progress_every="${arg#*=}" ;;
    --mh-proposal=*) mh_proposal="${arg#*=}" ;;
    --mh-adapt=*) mh_adapt="${arg#*=}" ;;
    --slice-width=*) slice_width="${arg#*=}" ;;
    --slice-max-steps=*) slice_max_steps="${arg#*=}" ;;
    --init-mode=*) init_mode="${arg#*=}" ;;
    *) ;;
  esac
done

if [[ ! -f "$prepare_script" ]]; then
  echo "resume prepare script missing: $prepare_script" >&2
  exit 2
fi
if [[ ! -f "$runner" ]]; then
  echo "runner missing: $runner" >&2
  exit 2
fi

rows_tsv="$out_dir/LOCAL_static_exal_wave8_${stage}_resume_rows_20260403.tsv"
Rscript "$prepare_script" --stage="$stage" --out="$rows_tsv"

if [[ ! -s "$rows_tsv" ]]; then
  echo "no resume rows for stage ${stage}"
  exit 0
fi

manifest="$out_dir/LOCAL_static_exal_wave8_${stage}_resume_manifest_$(date '+%Y%m%d_%H%M%S')_${RANDOM}_$$.csv"
fail_log="$out_dir/LOCAL_static_exal_wave8_${stage}_resume_failures_$(date '+%Y%m%d_%H%M%S')_${RANDOM}_$$.log"
echo "ts,stage,row_id,run_root,root_kind,family,tt,tau_label,variant_tag,gamma_substeps,p_global_eta_jump,global_eta_jump_scale,seed,log_path" > "$manifest"

export runner out_dir n_burn n_mcmc thin trace_every progress_every mh_proposal mh_adapt slice_width slice_max_steps init_mode force keep_going fail_log

run_one() {
  local stage="$1"
  local row_id="$2"
  local run_root="$3"
  local root_kind="$4"
  local family="$5"
  local tt="$6"
  local tau_label="$7"
  local variant_tag="$8"
  local gamma_substeps="$9"
  local p_global_eta_jump="${10}"
  local global_eta_jump_scale="${11}"
  local seed="${12}"

  local log_path="$out_dir/LOCAL_static_exal_wave8_${stage}_${variant_tag}_row${row_id}_resume.log"
  local cmd=(Rscript "$runner"
    --queue_id="${row_id}"
    --priority_label="${stage}"
    --family_scope="${root_kind}"
    --model="exal"
    --family="${family}"
    --tt="${tt}"
    --tau="${tau_label}"
    --run_root="${run_root}"
    --variant_tag="${variant_tag}"
    --seed="${seed}"
    --n_burn="${n_burn}"
    --n_mcmc="${n_mcmc}"
    --thin="${thin}"
    --trace_every="${trace_every}"
    --progress_every="${progress_every}"
    --mh_proposal="${mh_proposal}"
    --mh_adapt="${mh_adapt}"
    --slice_width="${slice_width}"
    --slice_max_steps="${slice_max_steps}"
    --gamma_substeps="${gamma_substeps}"
    --p_global_eta_jump="${p_global_eta_jump}"
    --global_eta_jump_scale="${global_eta_jump_scale}"
    --init_mode="${init_mode}"
  )
  if [[ "$force" == "1" ]]; then
    cmd+=(--force)
  fi

  local rc=0
  OMP_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 MKL_NUM_THREADS=1 \
    VECLIB_MAXIMUM_THREADS=1 NUMEXPR_NUM_THREADS=1 \
    "${cmd[@]}" > "$log_path" 2>&1 || rc=$?

  if [[ "$rc" -ne 0 ]]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S'),${stage},${row_id},${variant_tag},rc=${rc},log=${log_path}" >> "$fail_log"
    if [[ "$keep_going" == "0" ]]; then
      return "$rc"
    fi
    rc=0
  fi

  echo "$(date '+%Y-%m-%d %H:%M:%S'),${stage},${row_id},${run_root},${root_kind},${family},${tt},${tau_label},${variant_tag},${gamma_substeps},${p_global_eta_jump},${global_eta_jump_scale},${seed},${log_path}" >> "$manifest"
  return "$rc"
}
export -f run_one

set +e
xargs -P "$parallel_jobs" -n 12 bash -c 'run_one "$@"' _ < "$rows_tsv"
xargs_rc=$?
set -e

if [[ "$xargs_rc" -ne 0 && "$keep_going" == "0" ]]; then
  echo "resume launch aborted due to non-zero exit (rc=$xargs_rc)"
  exit "$xargs_rc"
fi

echo "manifest: $manifest"
echo "fail_log: $fail_log"

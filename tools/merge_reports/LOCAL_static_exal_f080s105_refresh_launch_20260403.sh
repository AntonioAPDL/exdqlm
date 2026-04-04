#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
out_dir="$repo_root/tools/merge_reports"
prepare_script="$out_dir/LOCAL_static_exal_f080s105_refresh_prepare_20260403.R"
evaluate_script="$out_dir/LOCAL_static_exal_f080s105_refresh_evaluate_20260403.R"
runner="$out_dir/LOCAL_static_exal_case_runner_20260323.R"
rows_tsv="$out_dir/LOCAL_static_exal_f080s105_refresh_rows_20260403.tsv"

mode="launch"
parallel_jobs="6"
force="0"
keep_going="1"
scope_filter=""
row_filter=""
n_burn="2000"
n_mcmc="1000"
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
    --mode=*) mode="${arg#*=}" ;;
    --parallel-jobs=*) parallel_jobs="${arg#*=}" ;;
    --force) force="1" ;;
    --stop-on-error) keep_going="0" ;;
    --scope=*) scope_filter="${arg#*=}" ;;
    --row-ids=*) row_filter="${arg#*=}" ;;
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

if [[ ! -f "$prepare_script" || ! -f "$evaluate_script" || ! -f "$runner" ]]; then
  echo "required script missing" >&2
  exit 2
fi

if [[ "$mode" == "prepare" ]]; then
  Rscript "$prepare_script"
  exit 0
fi

Rscript "$prepare_script" >/dev/null

if [[ "$mode" == "evaluate" ]]; then
  Rscript "$evaluate_script"
  exit 0
fi

if [[ ! -s "$rows_tsv" ]]; then
  echo "rows TSV missing or empty: $rows_tsv" >&2
  exit 2
fi

launch_rows_tsv="$(mktemp "/tmp/exdqlm_static_f080s105_refresh_rows_XXXX.tsv")"
trap 'rm -f "$launch_rows_tsv"' EXIT

awk -F'\t' -v scope_filter="$scope_filter" -v row_filter="$row_filter" '
  BEGIN {
    split(row_filter, tmp, ",")
    for (i in tmp) {
      if (tmp[i] != "") wanted_row[tmp[i]] = 1
    }
  }
  {
    keep = 1
    if (scope_filter != "" && $1 != scope_filter) keep = 0
    if (row_filter != "" && !($2 in wanted_row)) keep = 0
    if (keep) print $0
  }
' "$rows_tsv" > "$launch_rows_tsv"

if [[ ! -s "$launch_rows_tsv" ]]; then
  echo "no rows selected for launch" >&2
  exit 0
fi

manifest="$out_dir/LOCAL_static_exal_f080s105_refresh_manifest_$(date '+%Y%m%d_%H%M%S')_${RANDOM}_$$.csv"
fail_log="$out_dir/LOCAL_static_exal_f080s105_refresh_failures_$(date '+%Y%m%d_%H%M%S')_${RANDOM}_$$.log"
manifest_lock="${manifest}.lock"
fail_log_lock="${fail_log}.lock"
echo "ts,scope_label,row_id,run_root,root_kind,family,tt,tau_label,variant_tag,gamma_substeps,p_global_eta_jump,global_eta_jump_scale,seed,mcmc_base_path,run_config_path,prior_template_path,beta_prior_override,candidate_refresh_path,runner_rc,log_path" > "$manifest"

export runner out_dir n_burn n_mcmc thin trace_every progress_every mh_proposal mh_adapt slice_width slice_max_steps init_mode force keep_going fail_log manifest manifest_lock fail_log_lock

append_manifest() {
  local line="$1"
  {
    flock 9
    printf '%s\n' "$line" >> "$manifest"
  } 9>>"$manifest_lock"
}

append_fail_log() {
  local line="$1"
  {
    flock 9
    printf '%s\n' "$line" >> "$fail_log"
  } 9>>"$fail_log_lock"
}

run_one() {
  local scope_label="$1"
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
  local mcmc_base_path="${13}"
  local run_config_path="${14}"
  local prior_template_path="${15}"
  local beta_prior_override="${16}"
  local candidate_refresh_path="${17}"

  local log_path="$out_dir/LOCAL_static_exal_f080s105_refresh_${scope_label}_${variant_tag}_row${row_id}.log"
  local cmd=(Rscript "$runner"
    --queue_id="${row_id}"
    --priority_label="${scope_label}"
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
    --mcmc_base_path="${mcmc_base_path}"
    --run_config_path="${run_config_path}"
    --prior_template_path="${prior_template_path}"
    --beta_prior_override="${beta_prior_override}"
    --candidate_path="${candidate_refresh_path}"
  )
  if [[ "$force" == "1" ]]; then
    cmd+=(--force)
  fi

  local rc=0
  OMP_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 MKL_NUM_THREADS=1 \
    VECLIB_MAXIMUM_THREADS=1 NUMEXPR_NUM_THREADS=1 \
    "${cmd[@]}" > "$log_path" 2>&1 || rc=$?

  if [[ "$rc" -ne 0 ]]; then
    append_fail_log "$(date '+%Y-%m-%d %H:%M:%S'),${scope_label},${row_id},${variant_tag},rc=${rc},log=${log_path}"
    if [[ "$keep_going" == "0" ]]; then
      append_manifest "$(date '+%Y-%m-%d %H:%M:%S'),${scope_label},${row_id},${run_root},${root_kind},${family},${tt},${tau_label},${variant_tag},${gamma_substeps},${p_global_eta_jump},${global_eta_jump_scale},${seed},${mcmc_base_path},${run_config_path},${prior_template_path},${beta_prior_override},${candidate_refresh_path},${rc},${log_path}"
      return "$rc"
    fi
  fi

  append_manifest "$(date '+%Y-%m-%d %H:%M:%S'),${scope_label},${row_id},${run_root},${root_kind},${family},${tt},${tau_label},${variant_tag},${gamma_substeps},${p_global_eta_jump},${global_eta_jump_scale},${seed},${mcmc_base_path},${run_config_path},${prior_template_path},${beta_prior_override},${candidate_refresh_path},${rc},${log_path}"
  if [[ "$keep_going" == "1" ]]; then
    rc=0
  fi
  return "$rc"
}
export -f run_one append_manifest append_fail_log

set +e
xargs -P "$parallel_jobs" -n 17 bash -c 'run_one "$@"' _ < "$launch_rows_tsv"
xargs_rc=$?
set -e

if [[ "$xargs_rc" -ne 0 && "$keep_going" == "0" ]]; then
  echo "static refresh launch aborted due to non-zero exit (rc=$xargs_rc)"
  exit "$xargs_rc"
fi

echo "manifest: $manifest"
echo "fail_log: $fail_log"
Rscript "$evaluate_script"

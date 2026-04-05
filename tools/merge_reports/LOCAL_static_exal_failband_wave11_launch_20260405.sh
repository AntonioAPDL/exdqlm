#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
out_dir="$repo_root/tools/merge_reports"
prepare_script="$out_dir/LOCAL_static_exal_failband_wave11_prepare_20260405.R"
evaluate_script="$out_dir/LOCAL_static_exal_failband_wave11_evaluate_20260405.R"
runner="$out_dir/LOCAL_static_exal_case_runner_20260323.R"
rows_tsv="$out_dir/LOCAL_static_exal_failband_wave11_rows_20260405.tsv"

mode="launch"
parallel_jobs="4"
force="0"
keep_going="1"
stage_filter=""
trace_every="50"
progress_every="50"

for arg in "$@"; do
  case "$arg" in
    --mode=*) mode="${arg#*=}" ;;
    --parallel-jobs=*) parallel_jobs="${arg#*=}" ;;
    --stage=*) stage_filter="${arg#*=}" ;;
    --force) force="1" ;;
    --stop-on-error) keep_going="0" ;;
    --trace-every=*) trace_every="${arg#*=}" ;;
    --progress-every=*) progress_every="${arg#*=}" ;;
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
  Rscript "$evaluate_script" ${stage_filter:+--stage="$stage_filter"}
  exit 0
fi

extract_summary_field() {
  local summary_line="$1"
  local field_name="$2"
  awk -v key="${field_name}=" '
    {
      for (i = 1; i <= NF; i++) {
        if (index($i, key) == 1) {
          sub(key, "", $i)
          print $i
          exit
        }
      }
    }
  ' <<<"$summary_line"
}

if [[ ! -s "$rows_tsv" ]]; then
  echo "rows TSV missing or empty: $rows_tsv" >&2
  exit 2
fi

launch_rows_tsv="$(mktemp "/tmp/exdqlm_static_failband_wave11_rows_XXXX.tsv")"
trap 'rm -f "$launch_rows_tsv"' EXIT

awk -F'\t' -v stage_filter="$stage_filter" '
  BEGIN {
    split(stage_filter, tmp_s, ",")
    for (i in tmp_s) if (tmp_s[i] != "") wanted_stage[tmp_s[i]] = 1
  }
  {
    keep = 1
    if (stage_filter != "" && !($1 in wanted_stage)) keep = 0
    if (keep) print $0
  }
' "$rows_tsv" > "$launch_rows_tsv"

if [[ ! -s "$launch_rows_tsv" ]]; then
  echo "no rows selected for launch" >&2
  exit 0
fi

manifest="$out_dir/LOCAL_static_exal_failband_wave11_manifest_$(date '+%Y%m%d_%H%M%S')_${RANDOM}_$$.csv"
fail_log="$out_dir/LOCAL_static_exal_failband_wave11_failures_$(date '+%Y%m%d_%H%M%S')_${RANDOM}_$$.log"
manifest_lock="${manifest}.lock"
fail_log_lock="${fail_log}.lock"
echo "ts,stage,candidate_id,geometry_candidate,scope_label,row_id,run_root,root_kind,family,tt,tau_label,variant_tag,gamma_substeps,p_global_eta_jump,global_eta_jump_scale,seed,n_burn,n_mcmc,thin,mh_proposal,mh_adapt,slice_width,slice_max_steps,init_mode,mcmc_base_path,run_config_path,prior_template_path,beta_prior_override,candidate_path,runner_rc,log_path" > "$manifest"

export runner out_dir trace_every progress_every force keep_going fail_log manifest manifest_lock fail_log_lock

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
  local stage="$1"
  local candidate_id="$2"
  local geometry_candidate="$3"
  local scope_label="$4"
  local row_id="$5"
  local run_root="$6"
  local root_kind="$7"
  local family="$8"
  local tt="$9"
  local tau_label="${10}"
  local variant_tag="${11}"
  local gamma_substeps="${12}"
  local p_global_eta_jump="${13}"
  local global_eta_jump_scale="${14}"
  local seed="${15}"
  local mcmc_base_path="${16}"
  local run_config_path="${17}"
  local prior_template_path="${18}"
  local beta_prior_override="${19}"
  local n_burn="${20}"
  local n_mcmc="${21}"
  local thin="${22}"
  local mh_proposal="${23}"
  local mh_adapt="${24}"
  local slice_width="${25}"
  local slice_max_steps="${26}"
  local init_mode="${27}"
  local candidate_path="${28}"

  local log_path="$out_dir/LOCAL_static_exal_failband_wave11_${candidate_id}_${scope_label}_row${row_id}.log"
  local cmd=(Rscript "$runner"
    --queue_id="${row_id}"
    --priority_label="${stage}_${candidate_id}"
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
    --candidate_path="${candidate_path}"
  )
  if [[ "$force" == "1" ]]; then
    cmd+=(--force)
  fi

  local rc=0
  OMP_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 MKL_NUM_THREADS=1 \
    VECLIB_MAXIMUM_THREADS=1 NUMEXPR_NUM_THREADS=1 \
    "${cmd[@]}" > "$log_path" 2>&1 || rc=$?

  if [[ "$rc" -ne 0 ]]; then
    append_fail_log "$(date '+%Y-%m-%d %H:%M:%S'),${candidate_id},${geometry_candidate},${scope_label},${row_id},${variant_tag},rc=${rc},log=${log_path}"
    if [[ "$keep_going" == "0" ]]; then
      append_manifest "$(date '+%Y-%m-%d %H:%M:%S'),${stage},${candidate_id},${geometry_candidate},${scope_label},${row_id},${run_root},${root_kind},${family},${tt},${tau_label},${variant_tag},${gamma_substeps},${p_global_eta_jump},${global_eta_jump_scale},${seed},${n_burn},${n_mcmc},${thin},${mh_proposal},${mh_adapt},${slice_width},${slice_max_steps},${init_mode},${mcmc_base_path},${run_config_path},${prior_template_path},${beta_prior_override},${candidate_path},${rc},${log_path}"
      return "$rc"
    fi
  fi

  append_manifest "$(date '+%Y-%m-%d %H:%M:%S'),${stage},${candidate_id},${geometry_candidate},${scope_label},${row_id},${run_root},${root_kind},${family},${tt},${tau_label},${variant_tag},${gamma_substeps},${p_global_eta_jump},${global_eta_jump_scale},${seed},${n_burn},${n_mcmc},${thin},${mh_proposal},${mh_adapt},${slice_width},${slice_max_steps},${init_mode},${mcmc_base_path},${run_config_path},${prior_template_path},${beta_prior_override},${candidate_path},${rc},${log_path}"
  if [[ "$keep_going" == "1" ]]; then
    rc=0
  fi
  return "$rc"
}
export -f run_one append_manifest append_fail_log

set +e
xargs -P "$parallel_jobs" -n 28 bash -c 'run_one "$@"' _ < "$launch_rows_tsv"
xargs_rc=$?
set -e

if [[ "$xargs_rc" -ne 0 && "$keep_going" == "0" ]]; then
  echo "failband wave-11 launch aborted due to non-zero exit (rc=$xargs_rc)"
  exit "$xargs_rc"
fi

echo "manifest: $manifest"
echo "fail_log: $fail_log"
eval_output="$(Rscript "$evaluate_script" ${stage_filter:+--stage="$stage_filter"})"
printf '%s\n' "$eval_output"

summary_line="$(printf '%s\n' "$eval_output" | awk '/^SUMMARY /{print; exit}')"
missing_now="$(extract_summary_field "$summary_line" "missing")"

if [[ -z "${missing_now:-}" ]]; then
  echo "unable to parse evaluator summary for static failband wave-11" >&2
  exit 4
fi

if [[ "${missing_now}" != "0" ]]; then
  echo "static failband wave-11 stage is incomplete: ${missing_now} rows remain MISSING after launch" >&2
  exit 5
fi

#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "Usage: $0 <launch_manifest_tsv> <batch_label>" >&2
  exit 1
fi

manifest="$1"
batch_label="$2"

if [[ ! -f "$manifest" ]]; then
  echo "Launch manifest not found: $manifest" >&2
  exit 1
fi

repo_root="$(pwd)"
if [[ ! -f "$repo_root/DESCRIPTION" ]]; then
  echo "Run this script from exdqlm repo root." >&2
  exit 1
fi

export OMP_NUM_THREADS="${OMP_NUM_THREADS:-1}"
export OPENBLAS_NUM_THREADS="${OPENBLAS_NUM_THREADS:-1}"
export MKL_NUM_THREADS="${MKL_NUM_THREADS:-1}"
export VECLIB_MAXIMUM_THREADS="${VECLIB_MAXIMUM_THREADS:-1}"
export NUMEXPR_NUM_THREADS="${NUMEXPR_NUM_THREADS:-1}"
export EXDQLM_STATIC_PIPELINE_CORES="${EXDQLM_STATIC_PIPELINE_CORES:-2}"
export EXDQLM_STATIC_RESUME_CORES="${EXDQLM_STATIC_RESUME_CORES:-2}"
export EXDQLM_PIPELINE_CORES="${EXDQLM_PIPELINE_CORES:-2}"
export EXDQLM_DYNAMIC_RESUME_CORES="${EXDQLM_DYNAMIC_RESUME_CORES:-2}"

stamp="$(date '+%Y%m%d_%H%M%S')"
batch_manifest="tools/merge_reports/20260312_muscat_batch_${batch_label}_${stamp}.tsv"
printf "batch\tkey\tkind\tfamily\ttau\ttt\tprior\trun_root\taction\tstatus\tstart_ts\tend_ts\tnote\n" > "$batch_manifest"

echo "START $(date '+%F %T') batch=$batch_label manifest=$manifest"
echo "batch_manifest=$batch_manifest"

is_complete_static() {
  local run_root="$1"
  local tau_tag="$2"
  local vb_al="${run_root}/fits/vb/vb_al_tau_${tau_tag}_fit.rds"
  local vb_exal="${run_root}/fits/vb/vb_exal_tau_${tau_tag}_fit.rds"
  local mcmc_al="${run_root}/fits/mcmc/mcmc_al_tau_${tau_tag}_fit.rds"
  local mcmc_exal="${run_root}/fits/mcmc/mcmc_exal_tau_${tau_tag}_fit.rds"
  local metrics="${run_root}/tables/metrics_summary.csv"
  [[ -f "$vb_al" && -f "$vb_exal" && -f "$mcmc_al" && -f "$mcmc_exal" && -f "$metrics" ]]
}

is_complete_dynamic() {
  local run_root="$1"
  local tau_tag="$2"
  local vb_dqlm="${run_root}/fits/vb/vb_dqlm_tau_${tau_tag}_fit.rds"
  local vb_exdqlm="${run_root}/fits/vb/vb_exdqlm_tau_${tau_tag}_fit.rds"
  local mcmc_dqlm="${run_root}/fits/mcmc/mcmc_dqlm_tau_${tau_tag}_fit.rds"
  local mcmc_exdqlm="${run_root}/fits/mcmc/mcmc_exdqlm_tau_${tau_tag}_fit.rds"
  local metrics="${run_root}/tables/metrics_summary.csv"
  [[ -f "$vb_dqlm" && -f "$vb_exdqlm" && -f "$mcmc_dqlm" && -f "$mcmc_exdqlm" && -f "$metrics" ]]
}

awk -F'\t' -v batch="$batch_label" '
  NR==1 {
    for (i=1; i<=NF; i++) idx[$i]=i
    next
  }
  $idx["batch_label"] == batch && $idx["launch_on_muscat_now"] == "TRUE" {
    print $idx["key"] "\t" $idx["kind"] "\t" $idx["family"] "\t" $idx["tau"] "\t" \
          $idx["tt"] "\t" $idx["prior"] "\t" $idx["prepared_root"] "\t" $idx["run_root"] "\t" \
          $idx["global_state"]
  }
' "$manifest" | while IFS=$'\t' read -r key kind family tau tt prior prepared_root run_root global_state; do
  start_ts="$(date --iso-8601=seconds)"
  end_ts=""
  action=""
  status=""
  note=""
  tau_tag="${tau/./p}"

  echo "CASE start key=$key kind=$kind family=$family tau=$tau tt=$tt prior=$prior state=$global_state"

  if [[ ! -f "${prepared_root}/sim_output.rds" ]]; then
    echo "Missing prepared sim input: ${prepared_root}/sim_output.rds" >&2
    exit 1
  fi

  mkdir -p "$run_root"
  config="${run_root}/tables/run_config.rds"

  if [[ "$kind" == "static_paper" || "$kind" == "static_shrink" ]]; then
    if is_complete_static "$run_root" "$tau_tag"; then
      action="skip"
      status="complete"
      note="already complete on muscat"
    elif [[ -f "$config" ]]; then
      action="resume"
      if [[ ! -f "${run_root}/fits/mcmc/mcmc_al_tau_${tau_tag}_fit.rds" || ! -f "${run_root}/fits/mcmc/mcmc_exal_tau_${tau_tag}_fit.rds" ]]; then
        env EXDQLM_STATIC_RUN_CONFIG="$config" \
          nice -n 10 Rscript tools/merge_reports/20260305_resume_static_mcmc_from_vb.R
      fi
      env EXDQLM_STATIC_RUN_ROOT="$run_root" \
        nice -n 10 Rscript tools/merge_reports/20260305_static_postprocess_from_existing_fits.R
      env EXDQLM_STATIC_RUN_ROOT="$run_root" \
        nice -n 10 Rscript tools/merge_reports/20260305_static_vb_mcmc_report.R
      status="resumed_done"
      note="resumed existing partial root"
    else
      action="fresh"
      prior_use="$prior"
      if [[ "$kind" == "static_paper" ]]; then
        prior_use="ridge"
      fi
      env \
        EXDQLM_STATIC_SIM_PATH="${prepared_root}/sim_output.rds" \
        EXDQLM_STATIC_PIPELINE_TT="$tt" \
        EXDQLM_STATIC_PIPELINE_TAU="$tau" \
        EXDQLM_STATIC_BETA_PRIOR="$prior_use" \
        EXDQLM_STATIC_OUT_ROOT="$run_root" \
        EXDQLM_STATIC_PIPELINE_LABEL="muscat_${batch_label}" \
        nice -n 10 Rscript tools/merge_reports/20260305_static_vb_then_mcmc_pipeline.R
      env EXDQLM_STATIC_RUN_ROOT="$run_root" \
        nice -n 10 Rscript tools/merge_reports/20260305_static_postprocess_from_existing_fits.R
      env EXDQLM_STATIC_RUN_ROOT="$run_root" \
        nice -n 10 Rscript tools/merge_reports/20260305_static_vb_mcmc_report.R
      status="fresh_done"
      note="fresh run completed"
    fi
  else
    if is_complete_dynamic "$run_root" "$tau_tag"; then
      action="skip"
      status="complete"
      note="already complete on muscat"
    elif [[ -f "$config" ]]; then
      action="resume"
      if [[ ! -f "${run_root}/fits/mcmc/mcmc_dqlm_tau_${tau_tag}_fit.rds" || ! -f "${run_root}/fits/mcmc/mcmc_exdqlm_tau_${tau_tag}_fit.rds" ]]; then
        env EXDQLM_DYNAMIC_RUN_CONFIG="$config" \
          nice -n 10 Rscript tools/merge_reports/20260305_resume_dynamic_mcmc_from_vb.R
      fi
      env EXDQLM_DYNAMIC_RUN_ROOT="$run_root" \
        nice -n 10 Rscript tools/merge_reports/20260305_postprocess_from_existing_fits.R
      status="resumed_done"
      note="resumed existing partial root"
    else
      action="fresh"
      env \
        EXDQLM_DYNAMIC_SIM_PATH="${prepared_root}/sim_output.rds" \
        EXDQLM_PIPELINE_TT="$tt" \
        EXDQLM_DYNAMIC_PIPELINE_TAU="$tau" \
        EXDQLM_DYNAMIC_OUT_ROOT="$run_root" \
        EXDQLM_DYNAMIC_PIPELINE_LABEL="muscat_${batch_label}" \
        nice -n 10 Rscript tools/merge_reports/20260305_vb_then_mcmc_pipeline.R
      env EXDQLM_DYNAMIC_RUN_ROOT="$run_root" \
        nice -n 10 Rscript tools/merge_reports/20260305_postprocess_from_existing_fits.R
      status="fresh_done"
      note="fresh run completed"
    fi
  fi

  end_ts="$(date --iso-8601=seconds)"
  printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n" \
    "$batch_label" "$key" "$kind" "$family" "$tau" "$tt" "$prior" "$run_root" \
    "$action" "$status" "$start_ts" "$end_ts" "$note" >> "$batch_manifest"

  echo "CASE done key=$key action=$action status=$status"
done

echo "END $(date '+%F %T') batch=$batch_label"

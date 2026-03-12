#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <fit_size>" >&2
  exit 1
fi

fit_size="$1"
root="results/function_testing_20260309_dynamic_dlm_family_qspec/dlm_constV_smallW"

if [[ ! "$fit_size" =~ ^[0-9]+$ ]]; then
  echo "fit_size must be an integer" >&2
  exit 1
fi

mapfile -t prep_roots < <(find "$root" -type d -name "fit_input_lastTT${fit_size}" | sort)
if [[ ${#prep_roots[@]} -eq 0 ]]; then
  echo "No prepared dynamic fit inputs found for fit_size=$fit_size under $root" >&2
  exit 1
fi

stamp="$(date '+%Y%m%d_%H%M%S')"
manifest="tools/merge_reports/dynamic_family_resume_tt${fit_size}_${stamp}.tsv"
printf "family\ttau\tprepared_root\trun_root\taction\tstatus\n" > "$manifest"

echo "START $(date '+%F %T') dynamic_family_resume_tt${fit_size}"

for prep_root in "${prep_roots[@]}"; do
  tau_dir="$(dirname "$prep_root")"
  family="$(basename "$(dirname "$tau_dir")")"
  tau_tag="$(basename "$tau_dir")"
  tau_fs="${tau_tag#tau_}"
  tau_val="${tau_fs/p/.}"
  run_root="${prep_root}/validation_dynamic_tt${fit_size}"
  config="${run_root}/tables/run_config.rds"

  vb_dqlm="${run_root}/fits/vb/vb_dqlm_tau_${tau_fs}_fit.rds"
  vb_exdqlm="${run_root}/fits/vb/vb_exdqlm_tau_${tau_fs}_fit.rds"
  mcmc_dqlm="${run_root}/fits/mcmc/mcmc_dqlm_tau_${tau_fs}_fit.rds"
  mcmc_exdqlm="${run_root}/fits/mcmc/mcmc_exdqlm_tau_${tau_fs}_fit.rds"
  final_metrics="${run_root}/tables/metrics_summary.csv"

  action="skip"
  status="complete"

  echo "CASE family=${family} tau=${tau_val} fit_size=${fit_size} root=${run_root} $(date '+%F %T')"

  if [[ -f "$final_metrics" && -f "$vb_dqlm" && -f "$vb_exdqlm" && -f "$mcmc_dqlm" && -f "$mcmc_exdqlm" ]]; then
    :
  elif [[ -f "$config" ]]; then
    action="resume"
    if [[ ! -f "$mcmc_dqlm" || ! -f "$mcmc_exdqlm" ]]; then
      EXDQLM_DYNAMIC_RUN_CONFIG="$config" \
      Rscript tools/merge_reports/20260305_resume_dynamic_mcmc_from_vb.R
    fi
    EXDQLM_DYNAMIC_RUN_ROOT="$run_root" \
    Rscript tools/merge_reports/20260305_postprocess_from_existing_fits.R
    status="resumed"
  else
    action="fresh"
    EXDQLM_DYNAMIC_SIM_PATH="${prep_root}/sim_output.rds" \
    EXDQLM_PIPELINE_TT="${fit_size}" \
    EXDQLM_DYNAMIC_PIPELINE_TAU="${tau_val}" \
    EXDQLM_DYNAMIC_OUT_ROOT="${run_root}" \
    EXDQLM_DYNAMIC_PIPELINE_LABEL="familyqspec_dynamic_tt${fit_size}" \
    Rscript tools/merge_reports/20260305_vb_then_mcmc_pipeline.R
    EXDQLM_DYNAMIC_RUN_ROOT="$run_root" \
    Rscript tools/merge_reports/20260305_postprocess_from_existing_fits.R
    status="fresh_done"
  fi

  printf "%s\t%s\t%s\t%s\t%s\t%s\n" \
    "$family" "$tau_val" "$prep_root" "$run_root" "$action" "$status" >> "$manifest"
done

echo "END $(date '+%F %T') dynamic_family_resume_tt${fit_size}"
echo "Manifest: ${manifest}"

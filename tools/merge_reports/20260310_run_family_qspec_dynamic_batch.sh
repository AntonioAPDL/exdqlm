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
manifest="tools/merge_reports/dynamic_family_tt${fit_size}_${stamp}.tsv"
printf "family\ttau\tprepared_root\trun_root\tlog\n" > "$manifest"

echo "START $(date '+%F %T') dynamic_family_tt${fit_size}"

for prep_root in "${prep_roots[@]}"; do
  tau_dir="$(dirname "$prep_root")"
  family="$(basename "$(dirname "$tau_dir")")"
  tau_tag="$(basename "$tau_dir")"
  tau_val="${tau_tag#tau_}"
  tau_val="${tau_val/p/.}"

  run_root="${prep_root}/validation_dynamic_tt${fit_size}"
  run_log="${run_root}/logs/master.log"
  mkdir -p "$run_root"

  printf "%s\t%s\t%s\t%s\t%s\n" \
    "$family" "$tau_val" "$prep_root" "$run_root" "$run_log" >> "$manifest"

  echo "RUN family=${family} tau=${tau_val} fit_size=${fit_size} root=${run_root} $(date '+%F %T')"

  EXDQLM_DYNAMIC_SIM_PATH="${prep_root}/sim_output.rds" \
  EXDQLM_PIPELINE_TT="${fit_size}" \
  EXDQLM_DYNAMIC_PIPELINE_TAU="${tau_val}" \
  EXDQLM_DYNAMIC_OUT_ROOT="${run_root}" \
  EXDQLM_DYNAMIC_PIPELINE_LABEL="familyqspec_dynamic_tt${fit_size}" \
  Rscript tools/merge_reports/20260305_vb_then_mcmc_pipeline.R

  echo "DONE family=${family} tau=${tau_val} fit_size=${fit_size} $(date '+%F %T')"
done

echo "END $(date '+%F %T') dynamic_family_tt${fit_size}"
echo "Manifest: ${manifest}"

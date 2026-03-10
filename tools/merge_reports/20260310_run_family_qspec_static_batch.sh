#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 2 || $# -gt 3 ]]; then
  echo "Usage: $0 <paper|shrink> <fit_size> [ridge|rhs]" >&2
  exit 1
fi

kind="$1"
fit_size="$2"
prior="${3:-ridge}"

case "$kind" in
  paper)
    root="results/function_testing_20260309_static_paper_family_qspec"
    mode_tag="paper"
    prior="ridge"
    ;;
  shrink)
    root="results/function_testing_20260309_static_shrinkage_family_qspec"
    mode_tag="shrink_${prior}"
    if [[ "$prior" != "ridge" && "$prior" != "rhs" ]]; then
      echo "Static shrink batch requires prior=ridge|rhs" >&2
      exit 1
    fi
    ;;
  *)
    echo "Unknown static family kind: $kind" >&2
    exit 1
    ;;
esac

if [[ ! "$fit_size" =~ ^[0-9]+$ ]]; then
  echo "fit_size must be an integer" >&2
  exit 1
fi

mapfile -t prep_roots < <(find "$root" -type d -name "fit_input_subsample_tt${fit_size}_x01_sorted" | sort)
if [[ ${#prep_roots[@]} -eq 0 ]]; then
  echo "No prepared static fit inputs found for kind=$kind fit_size=$fit_size under $root" >&2
  exit 1
fi

stamp="$(date '+%Y%m%d_%H%M%S')"
manifest="tools/merge_reports/static_${mode_tag}_tt${fit_size}_${stamp}.tsv"
printf "family\ttau\tprepared_root\trun_root\tlog\n" > "$manifest"

echo "START $(date '+%F %T') static_${mode_tag}_tt${fit_size}"

for prep_root in "${prep_roots[@]}"; do
  tau_dir="$(dirname "$prep_root")"
  family="$(basename "$(dirname "$tau_dir")")"
  tau_tag="$(basename "$tau_dir")"
  tau_val="${tau_tag#tau_}"
  tau_val="${tau_val/p/.}"

  run_root="${prep_root}/validation_${mode_tag}_tt${fit_size}"
  run_log="${run_root}/logs/master.log"
  mkdir -p "$run_root"

  printf "%s\t%s\t%s\t%s\t%s\n" \
    "$family" "$tau_val" "$prep_root" "$run_root" "$run_log" >> "$manifest"

  echo "RUN family=${family} tau=${tau_val} fit_size=${fit_size} prior=${prior} root=${run_root} $(date '+%F %T')"

  EXDQLM_STATIC_SIM_PATH="${prep_root}/sim_output.rds" \
  EXDQLM_STATIC_PIPELINE_TT="${fit_size}" \
  EXDQLM_STATIC_PIPELINE_TAU="${tau_val}" \
  EXDQLM_STATIC_BETA_PRIOR="${prior}" \
  EXDQLM_STATIC_OUT_ROOT="${run_root}" \
  EXDQLM_STATIC_PIPELINE_LABEL="familyqspec_${mode_tag}_tt${fit_size}" \
  Rscript tools/merge_reports/20260305_static_vb_then_mcmc_pipeline.R

  echo "DONE family=${family} tau=${tau_val} fit_size=${fit_size} prior=${prior} $(date '+%F %T')"
done

echo "END $(date '+%F %T') static_${mode_tag}_tt${fit_size}"
echo "Manifest: ${manifest}"

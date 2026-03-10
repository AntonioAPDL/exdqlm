#!/usr/bin/env bash
set -euo pipefail
ROOT="results/function_testing_20260309_dynamic_dlm_family_qspec"
FAMILIES=(normal laplace gausmix loggpd)
TAUS=(0.05 0.25 0.50)
mkdir -p "$ROOT"
echo "START $(date '+%F %T') dynamic_family_qspec"
for family in "${FAMILIES[@]}"; do
  for tau in "${TAUS[@]}"; do
    tau_tag=$(printf '%.2f' "$tau" | sed 's/\./p/g')
    out_dir="$ROOT/dlm_constV_smallW/$family/tau_${tau_tag}"
    echo "GEN family=$family tau=$tau out_dir=$out_dir $(date '+%F %T')"
    EXDQLM_DYNAMIC_FAMILY="$family" \
    EXDQLM_TARGET_TAU="$tau" \
    EXDQLM_DYNAMIC_FAMILY_OUT_ROOT="$ROOT" \
    Rscript tools/merge_reports/20260309_generate_dynamic_family_qspec.R
    Rscript tools/merge_reports/20260308_validate_quantile_specific_dynamic_sim.R "$out_dir/sim_output.rds" | tee "$out_dir/validation.txt"
    echo "DONE family=$family tau=$tau $(date '+%F %T')"
  done
done
echo "END $(date '+%F %T') dynamic_family_qspec"

#!/usr/bin/env bash
set -euo pipefail
ROOT="results/function_testing_20260309_static_shrinkage_family_qspec"
FAMILIES=(normal laplace gausmix)
TAUS=(0.05 0.25 0.95)
mkdir -p "$ROOT"
echo "START $(date '+%F %T') static_shrinkage_family_qspec"
for family in "${FAMILIES[@]}"; do
  for tau in "${TAUS[@]}"; do
    tau_tag=$(printf '%.2f' "$tau" | sed 's/\./p/g')
    out_dir="$ROOT/$family/tau_${tau_tag}"
    echo "GEN family=$family tau=$tau out_dir=$out_dir $(date '+%F %T')"
    EXDQLM_STATIC_SHRINK_FAMILY="$family" \
    EXDQLM_TARGET_TAU="$tau" \
    EXDQLM_STATIC_SHRINK_FAMILY_OUT_ROOT="$ROOT" \
    Rscript tools/merge_reports/20260309_generate_static_shrinkage_family_qspec.R
    EXDQLM_STATIC_SIM_PATH="$out_dir/sim_output.rds" \
    EXDQLM_STATIC_SIM_VALIDATION_OUT="$out_dir/validation.csv" \
    Rscript tools/merge_reports/20260308_validate_quantile_specific_static_sim.R
    echo "DONE family=$family tau=$tau $(date '+%F %T')"
  done
done
echo "END $(date '+%F %T') static_shrinkage_family_qspec"

#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$repo_root"

catalog="tools/merge_reports/20260312_family_qspec_root_catalog.tsv"
if [[ ! -f "$catalog" ]]; then
  echo "Missing root catalog: $catalog" >&2
  exit 1
fi

log="tools/merge_reports/20260312_family_qspec_prepared_input_generation.log"
: > "$log"

log_msg() {
  printf '%s | %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" | tee -a "$log"
}

declare -A generated_base=()

while IFS=$'\t' read -r root_id root_kind family tau fit_axis fit_size fit_label prior prepared_root rest; do
  [[ "$root_id" == "root_id" ]] && continue
  if [[ -d "$prepared_root" && -f "$prepared_root/sim_output.rds" ]]; then
    continue
  fi
  key="${root_kind}|${family}|${tau}"

  if [[ -z "${generated_base[$key]:-}" ]]; then
    log_msg "prepare start kind=$root_kind family=$family tau=$tau"
    case "$root_kind" in
      static_paper)
        EXDQLM_STATIC_PAPER_FAMILY="$family" \
        EXDQLM_TARGET_TAU="$tau" \
        EXDQLM_STATIC_PAPER_FAMILY_OUT_ROOT="results/function_testing_20260309_static_paper_family_qspec" \
        Rscript tools/merge_reports/20260309_generate_static_paper_family_qspec.R >> "$log" 2>&1
        ;;
      static_shrink)
        EXDQLM_STATIC_SHRINK_FAMILY="$family" \
        EXDQLM_TARGET_TAU="$tau" \
        EXDQLM_STATIC_SHRINK_FAMILY_OUT_ROOT="results/function_testing_20260309_static_shrinkage_family_qspec" \
        Rscript tools/merge_reports/20260309_generate_static_shrinkage_family_qspec.R >> "$log" 2>&1
        ;;
      dynamic)
        EXDQLM_DYNAMIC_FAMILY="$family" \
        EXDQLM_TARGET_TAU="$tau" \
        EXDQLM_DYNAMIC_FAMILY_FIT_T_LIST="500,5000" \
        EXDQLM_DYNAMIC_FAMILY_OUT_ROOT="results/function_testing_20260309_dynamic_dlm_family_qspec" \
        Rscript tools/merge_reports/20260309_generate_dynamic_family_qspec.R >> "$log" 2>&1
        ;;
      *)
        echo "Unknown root_kind: $root_kind" >&2
        exit 1
        ;;
    esac
    generated_base[$key]=1
    log_msg "prepare done kind=$root_kind family=$family tau=$tau"
  fi

  if [[ "$root_kind" == "static_paper" || "$root_kind" == "static_shrink" ]]; then
    if [[ ! -f "$prepared_root/sim_output.rds" ]]; then
      base_root="$(dirname "$prepared_root")"
      log_msg "materialize static prepared_root=$prepared_root fit_size=$fit_size"
      Rscript tools/merge_reports/20260312_materialize_static_family_qspec_subsample.R \
        "$base_root" \
        "$prepared_root" \
        "$fit_size" >> "$log" 2>&1
    fi
  fi
done < "$catalog"

log_msg "prepared-input generation pass complete"

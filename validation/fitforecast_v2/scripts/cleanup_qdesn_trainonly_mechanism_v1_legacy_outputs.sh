#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: cleanup_qdesn_trainonly_mechanism_v1_legacy_outputs.sh [--dry-run|--execute]

Audits and optionally removes duplicate, regenerable path/progress CSVs from
the superseded origin-7000 and origin-8000 Q-DESN development campaigns.
Dry-run is the default. No source objects, scalar metrics, diagnostics, logs,
manifests, promotion records, or origin-9000 artifacts are eligible.
EOF
}

mode="dry-run"
case "${1:-}" in
  ""|--dry-run) mode="dry-run" ;;
  --execute) mode="execute" ;;
  -h|--help) usage; exit 0 ;;
  *) usage >&2; exit 2 ;;
esac

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo_root="$(git -C "${script_dir}" rev-parse --show-toplevel)"
shared_root="/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0"
evidence_dir="${repo_root}/validation/fitforecast_v2/docs/qdesn_trainonly_mechanism_v1_cleanup_20260805"
classification_csv="${evidence_dir}/legacy_cleanup_classification.csv"
dry_run_csv="${evidence_dir}/legacy_cleanup_dry_run.csv"
removed_csv="${evidence_dir}/legacy_cleanup_removed.csv"
summary_md="${evidence_dir}/legacy_cleanup_summary.md"

legacy_result_roots=(
  "${shared_root}/results/qdesn_mcmc_validation/qdesn_dynamic_fitforecast_v2_500obs_mcmc_nested_cellwise_v1_origin7000"
  "${shared_root}/results/qdesn_mcmc_validation/qdesn_dynamic_fitforecast_v2_500obs_mcmc_nested_cellwise_v1_origin8000"
)
legacy_report_roots=(
  "${shared_root}/reports/qdesn_mcmc_validation/qdesn_dynamic_fitforecast_v2_500obs_mcmc_nested_cellwise_v1_origin7000"
  "${shared_root}/reports/qdesn_mcmc_validation/qdesn_dynamic_fitforecast_v2_500obs_mcmc_nested_cellwise_v1_origin8000"
)
protected_paths=(
  "${shared_root}/results/qdesn_mcmc_validation/qdesn_dynamic_fitforecast_v2_500obs_mcmc_nested_final_origin9000_v1"
  "${shared_root}/reports/qdesn_mcmc_validation/qdesn_dynamic_fitforecast_v2_500obs_mcmc_nested_final_origin9000_v1"
  "${shared_root}/results/qdesn_mcmc_validation/dynamic_fitforecast_v2_qdesn_sources_nested_final_origin9000_period90_m90_w300"
  "${shared_root}/validation/fitforecast_v2/promotions/qdesn_500obs_mcmc_nested_cellwise_v1_closeout_20260730"
  "${repo_root}/results/qdesn_mcmc_validation/qdesn_dynamic_fitforecast_v2_500obs_trainonly_mechanism_v1"
  "${repo_root}/reports/qdesn_mcmc_validation/qdesn_dynamic_fitforecast_v2_500obs_trainonly_mechanism_v1"
)
result_names=(
  progress_trace.csv
  fit_quantile_path_holdout.csv
  forecast_rolling_origin_paths.csv
  fit_quantile_path_train.csv
  q_true.csv
  observed.csv
)
report_names=(campaign_progress_trace_long.csv)

mkdir -p "${evidence_dir}"
tmp_candidates="$(mktemp)"
trap 'rm -f "${tmp_candidates}"' EXIT

csv_quote() {
  local value=${1//\"/\"\"}
  printf '"%s"' "${value}"
}

dir_bytes() {
  if [[ -e "$1" ]]; then
    du -sb -- "$1" | awk '{print $1}'
  else
    printf '0\n'
  fi
}

assert_no_active_reference() {
  local root needle pid args
  local hits=()
  for root in "${legacy_result_roots[@]}" "${legacy_report_roots[@]}"; do
    needle="$(basename "${root}")"
    while read -r pid args; do
      [[ -n "${pid}" ]] || continue
      [[ "${pid}" == "$$" || "${pid}" == "${PPID}" ]] && continue
      [[ "${args}" == *"$(basename "${BASH_SOURCE[0]}")"* ]] && continue
      if [[ "${args}" == *"${needle}"* ]]; then
        hits+=("pid=${pid} root=${needle} command=${args}")
      fi
    done < <(ps -eo pid=,args=)
  done
  if ((${#hits[@]} > 0)); then
    printf 'Refusing cleanup: active process references a legacy root.\n' >&2
    printf '%s\n' "${hits[@]}" >&2
    exit 3
  fi
}

is_allowed_candidate() {
  local path=$1 canonical root name allowed_root=0 allowed_name=0
  canonical="$(realpath -e -- "${path}")"
  for root in "${legacy_result_roots[@]}" "${legacy_report_roots[@]}"; do
    if [[ "${canonical}" == "${root}/"* ]]; then
      allowed_root=1
      break
    fi
  done
  name="$(basename "${canonical}")"
  for allowed in "${result_names[@]}" "${report_names[@]}"; do
    if [[ "${name}" == "${allowed}" ]]; then
      allowed_name=1
      break
    fi
  done
  [[ ${allowed_root} -eq 1 && ${allowed_name} -eq 1 && -f "${canonical}" ]]
}

for root in "${legacy_result_roots[@]}"; do
  [[ -d "${root}" ]] || { printf 'Missing expected legacy result root: %s\n' "${root}" >&2; exit 4; }
  find "${root}" -type f \( \
    -name 'progress_trace.csv' -o \
    -name 'fit_quantile_path_holdout.csv' -o \
    -name 'forecast_rolling_origin_paths.csv' -o \
    -name 'fit_quantile_path_train.csv' -o \
    -name 'q_true.csv' -o \
    -name 'observed.csv' \
  \) -print
done | LC_ALL=C sort -u > "${tmp_candidates}"

for root in "${legacy_report_roots[@]}"; do
  [[ -d "${root}" ]] || { printf 'Missing expected legacy report root: %s\n' "${root}" >&2; exit 4; }
  find "${root}" -type f -name 'campaign_progress_trace_long.csv' -print
done | LC_ALL=C sort -u >> "${tmp_candidates}"
LC_ALL=C sort -u -o "${tmp_candidates}" "${tmp_candidates}"

candidate_count=0
candidate_bytes=0
while IFS= read -r path; do
  [[ -n "${path}" ]] || continue
  is_allowed_candidate "${path}" || { printf 'Unsafe candidate rejected: %s\n' "${path}" >&2; exit 5; }
  size=$(stat -c '%s' -- "${path}")
  candidate_count=$((candidate_count + 1))
  candidate_bytes=$((candidate_bytes + size))
done < "${tmp_candidates}"

if [[ -s "${removed_csv}" ]]; then
  if [[ "${candidate_count}" -eq 0 ]]; then
    printf 'Cleanup already completed; preserving the existing evidence ledger: %s\n' "${removed_csv}"
    exit 0
  fi
  printf 'Refusing to overwrite an existing removal ledger while new candidates exist: %s\n' "${removed_csv}" >&2
  exit 7
fi

timestamp_utc="$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
{
  printf 'path,project_task_ownership,size_bytes,classification,reason,action\n'
  for path in "${protected_paths[@]}"; do
    printf '%s,%s,%s,%s,%s,%s\n' \
      "$(csv_quote "${path}")" \
      "$(csv_quote 'independent Q-DESN fit+forecast validation')" \
      "$(dir_bytes "${path}")" \
      "$(csv_quote 'authoritative/promoted or active/current')" \
      "$(csv_quote 'current campaign, final origin-9000 evidence, or tracked closeout')" \
      "$(csv_quote 'keep')"
  done
  for path in "${legacy_result_roots[@]}" "${legacy_report_roots[@]}"; do
    printf '%s,%s,%s,%s,%s,%s\n' \
      "$(csv_quote "${path}")" \
      "$(csv_quote 'independent Q-DESN fit+forecast validation')" \
      "$(dir_bytes "${path}")" \
      "$(csv_quote 'old regenerable heavy artifact')" \
      "$(csv_quote 'only whitelisted duplicate path/progress CSVs are eligible; compact evidence remains')" \
      "$(csv_quote 'delete selected files')"
  done
} > "${classification_csv}"

{
  printf 'path,size_bytes,sha256,classification,reason,planned_action,audit_time_utc\n'
  while IFS= read -r path; do
    [[ -n "${path}" ]] || continue
    size=$(stat -c '%s' -- "${path}")
    digest=$(sha256sum -- "${path}" | awk '{print $1}')
    printf '%s,%s,%s,%s,%s,%s,%s\n' \
      "$(csv_quote "${path}")" \
      "${size}" \
      "${digest}" \
      "$(csv_quote 'old regenerable heavy artifact')" \
      "$(csv_quote 'duplicate dense path/progress output; compact metrics, diagnostics, status, logs, and manifests retained')" \
      "$(csv_quote 'delete')" \
      "${timestamp_utc}"
  done < "${tmp_candidates}"
} > "${dry_run_csv}"

removed_count=0
removed_bytes=0
if [[ "${mode}" == "execute" ]]; then
  assert_no_active_reference
  printf 'path,size_bytes,sha256,removed_time_utc\n' > "${removed_csv}"
  while IFS= read -r path; do
    [[ -n "${path}" ]] || continue
    is_allowed_candidate "${path}" || { printf 'Unsafe execute candidate rejected: %s\n' "${path}" >&2; exit 5; }
    size=$(stat -c '%s' -- "${path}")
    digest=$(sha256sum -- "${path}" | awk '{print $1}')
    rm -f -- "${path}"
    [[ ! -e "${path}" ]] || { printf 'Removal failed: %s\n' "${path}" >&2; exit 6; }
    removed_count=$((removed_count + 1))
    removed_bytes=$((removed_bytes + size))
    printf '%s,%s,%s,%s\n' \
      "$(csv_quote "${path}")" "${size}" "${digest}" "$(date -u +'%Y-%m-%dT%H:%M:%SZ')" \
      >> "${removed_csv}"
  done < "${tmp_candidates}"
fi

remaining_candidates=0
for root in "${legacy_result_roots[@]}"; do
  remaining_candidates=$((remaining_candidates + $(find "${root}" -type f \( \
    -name 'progress_trace.csv' -o \
    -name 'fit_quantile_path_holdout.csv' -o \
    -name 'forecast_rolling_origin_paths.csv' -o \
    -name 'fit_quantile_path_train.csv' -o \
    -name 'q_true.csv' -o \
    -name 'observed.csv' \
  \) | wc -l)))
done
for root in "${legacy_report_roots[@]}"; do
  remaining_candidates=$((remaining_candidates + $(find "${root}" -type f -name 'campaign_progress_trace_long.csv' | wc -l)))
done

disk_line="$(df -h /data | tail -n 1)"
{
  printf '# Q-DESN train-only mechanism v1 legacy-output cleanup\n\n'
  printf -- '- Audit time (UTC): `%s`\n' "${timestamp_utc}"
  printf -- '- Mode: `%s`\n' "${mode}"
  printf -- '- Scoped owner: independent single-quantile Q-DESN fit+forecast validation\n'
  printf -- '- Candidate files: `%d`\n' "${candidate_count}"
  printf -- '- Candidate bytes: `%d` (`%.3f GiB`)\n' "${candidate_bytes}" "$(awk -v b="${candidate_bytes}" 'BEGIN {print b/1024/1024/1024}')"
  printf -- '- Removed files: `%d`\n' "${removed_count}"
  printf -- '- Removed bytes: `%d` (`%.3f GiB`)\n' "${removed_bytes}" "$(awk -v b="${removed_bytes}" 'BEGIN {print b/1024/1024/1024}')"
  printf -- '- Remaining eligible files after this invocation: `%d`\n' "${remaining_candidates}"
  printf -- '- Disk after invocation: `%s`\n\n' "${disk_line}"
  printf '## Scope guard\n\n'
  printf 'Only seven whitelisted duplicate CSV basenames below the exact origin-7000/origin-8000 legacy roots were eligible. '
  printf 'Source objects, final origin-9000 evidence, scalar metrics, lead summaries, chain diagnostics, statuses, failures, logs, manifests, promotion records, and current campaign files were retained.\n\n'
  printf '## Evidence\n\n'
  printf -- '- Classification: `legacy_cleanup_classification.csv`\n'
  printf -- '- Candidate manifest: `legacy_cleanup_dry_run.csv`\n'
  if [[ "${mode}" == "execute" ]]; then
    printf -- '- Removal ledger: `legacy_cleanup_removed.csv`\n'
  fi
} > "${summary_md}"

printf 'mode=%s candidates=%d candidate_bytes=%d removed=%d removed_bytes=%d remaining=%d\n' \
  "${mode}" "${candidate_count}" "${candidate_bytes}" "${removed_count}" "${removed_bytes}" "${remaining_candidates}"
printf 'classification=%s\ndry_run=%s\nsummary=%s\n' \
  "${classification_csv}" "${dry_run_csv}" "${summary_md}"
if [[ "${mode}" == "execute" ]]; then
  printf 'removed=%s\n' "${removed_csv}"
fi

#!/usr/bin/env bash
set -euo pipefail

action="${1:-help}"
if [[ $# -gt 0 ]]; then
  shift
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/../.." && pwd)"

run_tag="${REFRESHED288_RUN_TAG:-20260429_p90_dynamic72_qdesn_comparable_v1}"
variant_tag="${REFRESHED288_VARIANT_TAG:-p90_dynamic72_qdesn_comparable_v1}"

launcher="$script_dir/LOCAL_refreshed288_launch_20260422_p90_full288.sh"
healthcheck="$script_dir/LOCAL_refreshed288_healthcheck_20260422_p90_full288.sh"
verifier="$script_dir/LOCAL_refreshed288_verify_qdesn_dynamic_windows_20260429.R"

export OMP_NUM_THREADS="${OMP_NUM_THREADS:-1}"
export OPENBLAS_NUM_THREADS="${OPENBLAS_NUM_THREADS:-1}"
export MKL_NUM_THREADS="${MKL_NUM_THREADS:-1}"

smoke_dynamic_vb_workers="${SMOKE_DYNAMIC_VB_WORKERS:-12}"
smoke_dynamic_mcmc_workers="${SMOKE_DYNAMIC_MCMC_WORKERS:-8}"
full_dynamic_vb_workers="${FULL_DYNAMIC_VB_WORKERS:-16}"
full_dynamic_mcmc_workers="${FULL_DYNAMIC_MCMC_WORKERS:-8}"

manifest_path() {
  local kind="$1"
  printf '%s/tools/merge_reports/LOCAL_refreshed288_%s_manifest_%s.csv\n' "$repo_root" "$kind" "$run_tag"
}

print_dynamic_health() {
  local kind="$1"
  local manifest
  manifest="$(manifest_path "$kind")"
  if [[ ! -f "$manifest" ]]; then
    echo "manifest not found: $manifest" >&2
    return 1
  fi
  (cd "$repo_root" && Rscript -e "
manifest <- read.csv('$manifest', stringsAsFactors = FALSE, check.names = FALSE)
dynamic <- manifest[manifest\$block == 'dynamic', , drop = FALSE]
read_status <- function(path) {
  if (!file.exists(path)) return(data.frame(status = 'not_started', gate_overall = 'MISSING', error = NA_character_, runtime_sec = NA_real_))
  read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
}
rows <- lapply(seq_len(nrow(dynamic)), function(i) {
  st <- read_status(dynamic\$row_status_path[i])
  data.frame(
    row_id = dynamic\$row_id[i],
    phase = dynamic\$phase[i],
    family = dynamic\$family[i],
    tau_label = dynamic\$tau_label[i],
    fit_size = dynamic\$fit_size[i],
    model = dynamic\$model[i],
    inference = dynamic\$inference[i],
    status = st\$status[1],
    gate = if ('gate_overall' %in% names(st)) st\$gate_overall[1] else 'MISSING',
    runtime_sec = if ('runtime_sec' %in% names(st)) st\$runtime_sec[1] else NA_real_,
    error = if ('error' %in% names(st)) st\$error[1] else NA_character_,
    stringsAsFactors = FALSE
  )
})
out <- do.call(rbind, rows)
cat('dynamic_rows=', nrow(out), '\\n', sep = '')
print(as.data.frame.matrix(table(out\$phase, out\$status)), row.names = TRUE)
gate_fail <- !is.na(out\$gate) & out\$gate == 'FAIL'
error_flag <- !is.na(out\$error) & nzchar(out\$error)
gate_fail[is.na(gate_fail)] <- FALSE
error_flag[is.na(error_flag)] <- FALSE
failures <- out[out\$status %in% c('failed_runtime') | gate_fail | error_flag, , drop = FALSE]
if (nrow(failures)) {
  cat('\\nfailures_or_errors:\\n')
  print(failures[, c('row_id','phase','family','tau_label','fit_size','model','inference','status','gate','error')], row.names = FALSE)
} else {
  cat('\\nfailures_or_errors: none\\n')
}
")
}

case "$action" in
  verify-windows)
    (cd "$repo_root" && Rscript "$verifier" --run-tag="$run_tag")
    ;;
  prepare)
    "$launcher" prepare \
      --run-tag="$run_tag" \
      --variant-tag="$variant_tag"
    ;;
  smoke)
    "$launcher" launch \
      --manifest-kind=smoke \
      --no-prepare \
      --run-tag="$run_tag" \
      --variant-tag="$variant_tag" \
      --phase-filter=smoke_dynamic_vb,smoke_dynamic_mcmc \
      --workers-dynamic-vb="$smoke_dynamic_vb_workers" \
      --workers-dynamic-mcmc="$smoke_dynamic_mcmc_workers" \
      "$@"
    ;;
  full)
    "$launcher" launch \
      --manifest-kind=full \
      --no-prepare \
      --run-tag="$run_tag" \
      --variant-tag="$variant_tag" \
      --phase-filter=full_dynamic_vb,full_dynamic_mcmc \
      --workers-dynamic-vb="$full_dynamic_vb_workers" \
      --workers-dynamic-mcmc="$full_dynamic_mcmc_workers" \
      "$@"
    ;;
  health-smoke)
    "$healthcheck" --manifest-kind=smoke --run-tag="$run_tag"
    print_dynamic_health smoke
    ;;
  health-full)
    "$healthcheck" --manifest-kind=full --run-tag="$run_tag"
    print_dynamic_health full
    ;;
  help|--help|-h)
    cat <<EOF
Usage: $(basename "$0") <action>

Actions:
  verify-windows  Verify 18 canonical validation windows against Q-DESN effective tails.
  prepare         Prepare manifests and run contract for $run_tag.
  smoke           Launch dynamic-only smoke phases.
  full            Launch dynamic-only full phases.
  health-smoke    Evaluate smoke manifest and print dynamic-only status.
  health-full     Evaluate full manifest and print dynamic-only status.

Worker env overrides:
  SMOKE_DYNAMIC_VB_WORKERS=$smoke_dynamic_vb_workers
  SMOKE_DYNAMIC_MCMC_WORKERS=$smoke_dynamic_mcmc_workers
  FULL_DYNAMIC_VB_WORKERS=$full_dynamic_vb_workers
  FULL_DYNAMIC_MCMC_WORKERS=$full_dynamic_mcmc_workers
EOF
    ;;
  *)
    echo "Unknown action: $action" >&2
    "$0" help >&2
    exit 1
    ;;
esac

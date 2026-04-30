#!/usr/bin/env bash
set -euo pipefail

action="${1:-help}"
if [[ $# -gt 0 ]]; then
  shift
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/../.." && pwd)"

export REFRESHED288_RUN_TAG="${REFRESHED288_RUN_TAG:-20260430_p90_dynamic72_qdesn_comparable_v4_laplace_repair}"
export REFRESHED288_VARIANT_TAG="${REFRESHED288_VARIANT_TAG:-p90_dynamic72_qdesn_comparable_v4_laplace_repair}"

export OMP_NUM_THREADS="${OMP_NUM_THREADS:-1}"
export OPENBLAS_NUM_THREADS="${OPENBLAS_NUM_THREADS:-1}"
export MKL_NUM_THREADS="${MKL_NUM_THREADS:-1}"

export SMOKE_DYNAMIC_VB_WORKERS="${SMOKE_DYNAMIC_VB_WORKERS:-12}"
export SMOKE_DYNAMIC_MCMC_WORKERS="${SMOKE_DYNAMIC_MCMC_WORKERS:-3}"
export FULL_DYNAMIC_VB_WORKERS="${FULL_DYNAMIC_VB_WORKERS:-24}"
export FULL_DYNAMIC_MCMC_WORKERS="${FULL_DYNAMIC_MCMC_WORKERS:-12}"

base_wrapper="$script_dir/LOCAL_refreshed288_launch_20260429_dynamic72_qdesn_comparable_v1.sh"
overlay_script="$script_dir/LOCAL_refreshed288_apply_dynamic72_repair_overlay_20260430.R"
run_row_script="$script_dir/LOCAL_refreshed288_run_row_20260422_p90_full288.R"
evaluate_script="$script_dir/LOCAL_refreshed288_evaluate_20260422_p90_full288.R"
report_script="$script_dir/LOCAL_refreshed288_report_20260422_p90_full288.R"

apply_overlay() {
  (cd "$repo_root" && Rscript "$overlay_script" \
    --run-tag="$REFRESHED288_RUN_TAG" \
    --variant-tag="$REFRESHED288_VARIANT_TAG" \
    --overlay-profile=laplace_rw_refresh_v2)
}

case "$action" in
  prepare)
    "$base_wrapper" prepare "$@"
    apply_overlay
    "$base_wrapper" health-smoke
    ;;
  apply-overlay)
    apply_overlay
    ;;
  verify-windows|health-smoke|health-full)
    "$base_wrapper" "$action" "$@"
    ;;
  smoke-repair)
    manifest="$repo_root/tools/merge_reports/LOCAL_refreshed288_smoke_manifest_${REFRESHED288_RUN_TAG}.csv"
    if [[ ! -f "$manifest" ]]; then
      echo "Missing v4 smoke manifest: $manifest" >&2
      echo "Run: $(basename "$0") prepare" >&2
      exit 1
    fi
    printf '%s\n' 20 44 68 | xargs -P "$SMOKE_DYNAMIC_MCMC_WORKERS" -I{} \
      bash -lc "cd '$repo_root' && Rscript '$run_row_script' --manifest='$manifest' --row_id={} --force"
    (cd "$repo_root" && Rscript "$evaluate_script" --manifest="$manifest")
    (cd "$repo_root" && Rscript "$report_script" --manifest="$manifest")
    ;;
  smoke)
    "$base_wrapper" smoke "$@"
    ;;
  full)
    "$base_wrapper" full "$@"
    ;;
  help|--help|-h)
    cat <<EOF
Usage: $(basename "$0") <action>

Actions:
  prepare        Prepare v4 manifests, apply the Laplace-RW repair overlay, and refresh smoke health.
  apply-overlay  Re-apply the repair overlay to existing v4 smoke/full configs.
  verify-windows Verify canonical dynamic windows against Q-DESN effective tails.
  smoke-repair   Force-run only repaired smoke_dynamic_mcmc rows 20, 44, and 68.
  smoke          Launch all dynamic smoke phases for this v4 tag.
  full           Launch full dynamic phases for this v4 tag.
  health-smoke   Refresh and print smoke health.
  health-full    Refresh and print full health.

Default workers:
  SMOKE_DYNAMIC_VB_WORKERS=$SMOKE_DYNAMIC_VB_WORKERS
  SMOKE_DYNAMIC_MCMC_WORKERS=$SMOKE_DYNAMIC_MCMC_WORKERS
  FULL_DYNAMIC_VB_WORKERS=$FULL_DYNAMIC_VB_WORKERS
  FULL_DYNAMIC_MCMC_WORKERS=$FULL_DYNAMIC_MCMC_WORKERS

Threading:
  OMP_NUM_THREADS=$OMP_NUM_THREADS
  OPENBLAS_NUM_THREADS=$OPENBLAS_NUM_THREADS
  MKL_NUM_THREADS=$MKL_NUM_THREADS
EOF
    ;;
  *)
    echo "Unknown action: $action" >&2
    "$0" help >&2
    exit 1
    ;;
esac

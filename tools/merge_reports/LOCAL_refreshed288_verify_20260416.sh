#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/../.." && pwd)"
resolved_tag="${REFRESHED288_RUN_TAG:-20260416}"
resolved_tag="${resolved_tag//[^A-Za-z0-9_-]/_}"

cd "$repo_root"

Rscript tools/merge_reports/LOCAL_refreshed288_prepare_20260416.R

Rscript tools/merge_reports/LOCAL_refreshed288_evaluate_20260416.R \
  --manifest="tools/merge_reports/LOCAL_refreshed288_full_manifest_${resolved_tag}.csv"
Rscript tools/merge_reports/LOCAL_refreshed288_evaluate_20260416.R \
  --manifest="tools/merge_reports/LOCAL_refreshed288_smoke_manifest_${resolved_tag}.csv"

Rscript tools/merge_reports/LOCAL_refreshed288_refresh_comparison_20260416.R \
  --manifest="tools/merge_reports/LOCAL_refreshed288_full_manifest_${resolved_tag}.csv"
Rscript tools/merge_reports/LOCAL_refreshed288_refresh_comparison_20260416.R \
  --manifest="tools/merge_reports/LOCAL_refreshed288_smoke_manifest_${resolved_tag}.csv"

tools/merge_reports/LOCAL_refreshed288_launch_20260416.sh dry-run --manifest-kind=smoke --no-prepare
tools/merge_reports/LOCAL_refreshed288_launch_20260416.sh dry-run --manifest-kind=full --no-prepare

Rscript -e 'filter <- paste(c(
  "dlm-df-smoother-regression",
  "dqlm-reduced-paths",
  "dqlm-vb-sim-smoke",
  "dynamic-dqlm-mcmc-regression",
  "ffbs-indexing-parity",
  "mcmc-backend-routing",
  "mcmc-dynamic-strict-parity",
  "static-diagnostics",
  "static-p025-stability",
  "static-vb-mcmc-pipeline-report-smoke",
  "transfer-mcmc-wrapper",
  "vb-mcmc-convergence-controls"
), collapse = "|"); testthat::test_local(".", reporter = testthat::SummaryReporter$new(), filter = filter);'

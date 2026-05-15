#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

mkdir -p logs/benchmarks

latest_run_dir() {
  local experiment_name="$1"
  find results/benchmarks/qdesn_synth -maxdepth 1 -type d -name "${experiment_name}__*" | sort | tail -n 1
}

eligible_count() {
  local run_dir="$1"
  Rscript --vanilla -e '
    args <- commandArgs(trailingOnly = TRUE)
    run_dir <- args[[1L]]
    files <- c(
      file.path(run_dir, "tables", "model_selection_summary.rds"),
      file.path(run_dir, "tables", "selection_checkpoint__tourism_monthly__global__summary.rds")
    )
    files <- files[file.exists(files)]
    if (!length(files)) {
      cat("0\n")
      quit(status = 0L)
    }
    x <- readRDS(files[[1L]])
    if (!("eligible" %in% names(x))) {
      cat("0\n")
      quit(status = 0L)
    }
    cat(sum(isTRUE(x$eligible) | x$eligible %in% TRUE, na.rm = TRUE), "\n")
  ' "$run_dir"
}

run_stage_allow_failure() {
  local config_path="$1"
  local experiment_name="$2"
  local stamp
  local stage_log
  local exit_code
  local run_dir

  stamp="$(date +%Y%m%d-%H%M%S)"
  stage_log="logs/benchmarks/${experiment_name}__${stamp}.log"

  echo "[tourism_prescreen] starting $config_path"
  echo "[tourism_prescreen] log: $stage_log"

  set +e
  OPENBLAS_NUM_THREADS=1 \
  OMP_NUM_THREADS=1 \
  MKL_NUM_THREADS=1 \
  VECLIB_MAXIMUM_THREADS=1 \
  NUMEXPR_NUM_THREADS=1 \
    Rscript --vanilla scripts/benchmark_qdesn_run.R --config "$config_path" 2>&1 | tee "$stage_log"
  exit_code=${PIPESTATUS[0]}
  set -e

  run_dir="$(latest_run_dir "$experiment_name")"
  echo "[tourism_prescreen] run_dir: ${run_dir:-<none>}"
  echo "[tourism_prescreen] exit_code: $exit_code"

  STAGE_RUN_DIR="$run_dir"
  STAGE_EXIT_CODE="$exit_code"
  STAGE_LOG="$stage_log"
}

run_stage_allow_failure \
  "config/benchmarks/qdesn_synth_prescreen_tourism_batch1.yaml" \
  "qdesn_synth_prescreen_tourism_batch1"

batch1_run_dir="$STAGE_RUN_DIR"
batch1_eligible="$(eligible_count "$batch1_run_dir")"
echo "[tourism_prescreen] batch1 eligible_count: $batch1_eligible"

if [[ "$batch1_eligible" =~ ^[1-9][0-9]*$ ]]; then
  echo "[tourism_prescreen] batch1 produced eligible candidates; stopping before batch2."
  exit 0
fi

run_stage_allow_failure \
  "config/benchmarks/qdesn_synth_prescreen_tourism_batch2.yaml" \
  "qdesn_synth_prescreen_tourism_batch2"

batch2_run_dir="$STAGE_RUN_DIR"
batch2_eligible="$(eligible_count "$batch2_run_dir")"
echo "[tourism_prescreen] batch2 eligible_count: $batch2_eligible"

if [[ "$batch2_eligible" =~ ^[1-9][0-9]*$ ]]; then
  echo "[tourism_prescreen] batch2 produced eligible candidates."
  exit 0
fi

run_stage_allow_failure \
  "config/benchmarks/qdesn_synth_prescreen_tourism_batch3.yaml" \
  "qdesn_synth_prescreen_tourism_batch3"

batch3_run_dir="$STAGE_RUN_DIR"
batch3_eligible="$(eligible_count "$batch3_run_dir")"
echo "[tourism_prescreen] batch3 eligible_count: $batch3_eligible"

if [[ "$batch3_eligible" =~ ^[1-9][0-9]*$ ]]; then
  echo "[tourism_prescreen] batch3 produced eligible candidates."
  exit 0
fi

echo "[tourism_prescreen] no eligible candidates in tourism prescreen batches 1, 2, or 3." >&2
exit 1

#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

mkdir -p logs/benchmarks

run_stage() {
  local config_path="$1"
  local experiment_name
  local stamp
  local stage_log
  local run_dir

  experiment_name="$(awk '/^  experiment_name:/{print $2; exit}' "$config_path")"
  if [[ -z "$experiment_name" ]]; then
    echo "Could not read experiment_name from $config_path" >&2
    return 1
  fi

  stamp="$(date +%Y%m%d-%H%M%S)"
  stage_log="logs/benchmarks/${experiment_name}__${stamp}.log"

  echo "[benchmark_qdesn_sequence] starting $config_path"
  echo "[benchmark_qdesn_sequence] log: $stage_log"
  OPENBLAS_NUM_THREADS=1 \
  OMP_NUM_THREADS=1 \
  MKL_NUM_THREADS=1 \
  VECLIB_MAXIMUM_THREADS=1 \
  NUMEXPR_NUM_THREADS=1 \
    Rscript --vanilla scripts/benchmark_qdesn_run.R --config "$config_path" 2>&1 | tee "$stage_log"

  run_dir="$(find results/benchmarks/qdesn_synth -maxdepth 1 -type d -name "${experiment_name}__*" | sort | tail -n 1)"
  if [[ -z "$run_dir" || ! -d "$run_dir/tables" ]]; then
    echo "[benchmark_qdesn_sequence] run did not produce tables for $experiment_name" >&2
    return 1
  fi

  echo "[benchmark_qdesn_sequence] report: $run_dir"
  OPENBLAS_NUM_THREADS=1 \
  OMP_NUM_THREADS=1 \
  MKL_NUM_THREADS=1 \
  VECLIB_MAXIMUM_THREADS=1 \
  NUMEXPR_NUM_THREADS=1 \
    Rscript --vanilla scripts/benchmark_qdesn_report.R --run_dir "$run_dir" 2>&1 | tee -a "$stage_log"
}

case "${1:-all}" in
  check)
    run_stage "config/benchmarks/qdesn_synth_check.yaml"
    ;;
  check_ridge)
    run_stage "config/benchmarks/qdesn_synth_check_ridge.yaml"
    ;;
  check_ridge_routed)
    run_stage "config/benchmarks/qdesn_synth_check_ridge_routed.yaml"
    ;;
  dev)
    run_stage "config/benchmarks/qdesn_synth_dev.yaml"
    ;;
  dev_ridge_routed)
    run_stage "config/benchmarks/qdesn_synth_dev_ridge_routed.yaml"
    ;;
  monthly_ridge_routed)
    run_stage "config/benchmarks/qdesn_synth_monthly_ridge_routed.yaml"
    ;;
  monthly_ridge_bias)
    run_stage "config/benchmarks/qdesn_synth_monthly_ridge_bias.yaml"
    ;;
  monthly_ridge_affine)
    run_stage "config/benchmarks/qdesn_synth_monthly_ridge_affine.yaml"
    ;;
  candidate_debug)
    run_stage "config/benchmarks/qdesn_synth_candidate_debug.yaml"
    ;;
  tourism_prescreen1)
    run_stage "config/benchmarks/qdesn_synth_prescreen_tourism_batch1.yaml"
    ;;
  tourism_prescreen2)
    run_stage "config/benchmarks/qdesn_synth_prescreen_tourism_batch2.yaml"
    ;;
  tourism_prescreen3)
    run_stage "config/benchmarks/qdesn_synth_prescreen_tourism_batch3.yaml"
    ;;
  tourism_shoulder_debug)
    run_stage "config/benchmarks/qdesn_synth_tourism_shoulder_debug.yaml"
    ;;
  tourism_shoulder_followup)
    run_stage "config/benchmarks/qdesn_synth_tourism_shoulder_followup.yaml"
    ;;
  tourism_shoulder_scale_control)
    run_stage "config/benchmarks/qdesn_synth_tourism_shoulder_scale_control.yaml"
    ;;
  tourism_one_step_audit)
    run_stage "config/benchmarks/qdesn_synth_tourism_one_step_audit.yaml"
    ;;
  tourism_one_step_tau_refine)
    run_stage "config/benchmarks/qdesn_synth_tourism_one_step_tau_refine.yaml"
    ;;
  tourism_one_step_readout_refine)
    run_stage "config/benchmarks/qdesn_synth_tourism_one_step_readout_refine.yaml"
    ;;
  tourism_one_step_ridge_full_ladder)
    run_stage "config/benchmarks/qdesn_synth_tourism_one_step_ridge_full_ladder.yaml"
    ;;
  m4_one_step_ridge_full_ladder)
    run_stage "config/benchmarks/qdesn_synth_m4_one_step_ridge_full_ladder.yaml"
    ;;
  m4_short_one_step_ridge)
    run_stage "config/benchmarks/qdesn_synth_m4_short_one_step_ridge.yaml"
    ;;
  m4_prescreen1)
    run_stage "config/benchmarks/qdesn_synth_prescreen_m4_batch1.yaml"
    ;;
  full)
    run_stage "config/benchmarks/qdesn_synth.yaml"
    ;;
  all)
    run_stage "config/benchmarks/qdesn_synth_check.yaml"
    run_stage "config/benchmarks/qdesn_synth_dev.yaml"
    ;;
  *)
    echo "Usage: scripts/benchmark_qdesn_sequence.sh [check|check_ridge|check_ridge_routed|candidate_debug|tourism_prescreen1|tourism_prescreen2|tourism_prescreen3|tourism_shoulder_debug|tourism_shoulder_followup|tourism_shoulder_scale_control|tourism_one_step_audit|tourism_one_step_tau_refine|tourism_one_step_readout_refine|tourism_one_step_ridge_full_ladder|m4_one_step_ridge_full_ladder|m4_short_one_step_ridge|m4_prescreen1|dev|dev_ridge_routed|monthly_ridge_routed|monthly_ridge_bias|monthly_ridge_affine|full|all]" >&2
    exit 1
    ;;
esac

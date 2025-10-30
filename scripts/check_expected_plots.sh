#!/usr/bin/env bash
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

must_pngs=(
  # per-p (0.05 / 0.5 / 0.95)
  "forecast_mu_band_p=0.05.png" "forecast_mu_band_p=0.5.png"  "forecast_mu_band_p=0.95.png"
  "forecast_emp_q_vs_true_p=0.05.png" "forecast_emp_q_vs_true_p=0.5.png" "forecast_emp_q_vs_true_p=0.95.png"
  # synth vs true use 3-decimal labels
  "forecast_synth_vs_true_p=0.050.png" "forecast_synth_vs_true_p=0.500.png" "forecast_synth_vs_true_p=0.950.png"
  "forecast_obs_with_95_band.png"
  "train_synth_vs_true_p=0.050.png" "train_synth_vs_true_p=0.500.png" "train_synth_vs_true_p=0.950.png"
  "train_obs_with_95_band.png"
  "rolling_cov_mu_train_W=365.png" "rolling_cov_mu_forecast_W=365.png"
  "rolling_cov_qhat_train_W=365.png" "rolling_cov_qhat_forecast_W=365.png"
  "rolling_cov_qsynth_train_W=365.png" "rolling_cov_qsynth_forecast_W=365.png"
  "pit_train.png" "pit_forecast.png"
)
must_csvs=(
  "calibration_mu_table.csv"
  "calibration_qhat_table.csv"
  "calibration_qsynth_table.csv"
  "scores_forecast_series.csv"
  "scores_train_series.csv"
  "scores_summary.csv"
)
must_rds=("forecast_objects.rds")

check_one() {
  local slug="$1"
  local base="results/sim_suite_dlm/${slug}/latest"
  local miss=0
  echo -e "\n== ${slug} =="
  for f in "${must_pngs[@]}"; do
    [[ -f "${base}/figs/$f" ]] || { echo "  MISSING PNG: $f"; ((miss++)); }
  done
  for f in "${must_csvs[@]}"; do
    [[ -f "${base}/tables/$f" ]] || { echo "  MISSING CSV: $f"; ((miss++)); }
  done
  for f in "${must_rds[@]}"; do
    [[ -f "${base}/models/$f" ]] || { echo "  MISSING RDS: $f"; ((miss++)); }
  done
  [[ $miss -eq 0 ]] && echo "  ✓ All expected artifacts present." || echo "  ⚠ Missing $miss artifacts."
}

for s in dlm_ar1V dlm_constV_bigW dlm_constV_smallW; do
  check_one "$s"
done
echo

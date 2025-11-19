#!/usr/bin/env bash
set -Eeuo pipefail

BASE="/data/muscat_data/jaguir26/exdqlm/results/sim_suite_dlm"

# Scenarios to inspect
SCENARIOS=(dlm_ar1V dlm_constV_bigW dlm_constV_smallW)

for scen in "${SCENARIOS[@]}"; do
  runs_dir="$BASE/$scen/runs"

  echo "=== $scen ==="

  if [[ ! -d "$runs_dir" ]]; then
    echo "  ⚠️  Runs directory not found: $runs_dir (skipping)"
    echo
    continue
  fi

  # Best-so-far trackers
  best_train_crps=""
  best_train_run=""
  best_train_path=""

  best_fore_crps=""
  best_fore_run=""
  best_fore_path=""

  shopt -s nullglob
  run_paths=("$runs_dir"/*)
  shopt -u nullglob

  if (( ${#run_paths[@]} == 0 )); then
    echo "  ⚠️  No run subfolders under: $runs_dir"
    echo
    continue
  fi

  for run in "${run_paths[@]}"; do
    [[ -d "$run" ]] || continue

    csv="$run/tables/scores_summary.csv"
    if [[ ! -f "$csv" ]]; then
      # Uncomment if you want verbose warnings:
      # echo "  (no scores_summary.csv in $(basename "$run"), skipping)"
      continue
    fi

    # Extract CRPS_mean for train and forecast
    train_crps=$(awk -F, 'NR>1 && $1=="train"{print $2; exit}' "$csv" || true)
    forecast_crps=$(awk -F, 'NR>1 && $1=="forecast"{print $2; exit}' "$csv" || true)

    # Update best train CRPS
    if [[ -n "${train_crps:-}" ]]; then
      if [[ -z "$best_train_crps" ]] || awk "BEGIN{exit !($train_crps < $best_train_crps)}"; then
        best_train_crps="$train_crps"
        best_train_run="$(basename "$run")"
        best_train_path="$run"
      fi
    fi

    # Update best forecast CRPS
    if [[ -n "${forecast_crps:-}" ]]; then
      if [[ -z "$best_fore_crps" ]] || awk "BEGIN{exit !($forecast_crps < $best_fore_crps)}"; then
        best_fore_crps="$forecast_crps"
        best_fore_run="$(basename "$run")"
        best_fore_path="$run"
      fi
    fi
  done

  if [[ -n "$best_train_run" ]]; then
    echo "  Best TRAIN run   : $best_train_run"
    echo "    CRPS_mean      : $best_train_crps"
    echo "    Full path      : $best_train_path"
  else
    echo "  Best TRAIN run   : <none found>"
  fi

  if [[ -n "$best_fore_run" ]]; then
    echo "  Best FORECAST run: $best_fore_run"
    echo "    CRPS_mean      : $best_fore_crps"
    echo "    Full path      : $best_fore_path"
  else
    echo "  Best FORECAST run: <none found>"
  fi

  echo
done

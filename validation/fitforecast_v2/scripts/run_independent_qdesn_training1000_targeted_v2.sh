#!/usr/bin/env bash
set -euo pipefail
repo=$(realpath "$1")
export IQT12_CLI="$repo/validation/fitforecast_v2/scripts/independent_qdesn_training1000_targeted_v2.R"
export IQT12_STAGES="cost quantile_A quantile_B bridge final_vb final_warm final_mcmc"
export IQT12_CPU_BUDGET_SECONDS=1440000
exec bash "$repo/validation/fitforecast_v2/scripts/run_independent_qdesn_training1000_v1.sh" "$repo" "$2"

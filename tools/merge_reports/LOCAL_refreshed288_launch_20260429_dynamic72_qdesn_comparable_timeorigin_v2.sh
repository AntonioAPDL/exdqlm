#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

export REFRESHED288_RUN_TAG="${REFRESHED288_RUN_TAG:-20260429_p90_dynamic72_qdesn_comparable_v2_timeorigin}"
export REFRESHED288_VARIANT_TAG="${REFRESHED288_VARIANT_TAG:-p90_dynamic72_qdesn_comparable_v2_timeorigin}"

# The v2 relaunch keeps VB parallelism high but starts MCMC more conservatively
# while we verify the source-index time-origin fix on the expensive TT5000 rows.
export SMOKE_DYNAMIC_VB_WORKERS="${SMOKE_DYNAMIC_VB_WORKERS:-12}"
export SMOKE_DYNAMIC_MCMC_WORKERS="${SMOKE_DYNAMIC_MCMC_WORKERS:-4}"
export FULL_DYNAMIC_VB_WORKERS="${FULL_DYNAMIC_VB_WORKERS:-16}"
export FULL_DYNAMIC_MCMC_WORKERS="${FULL_DYNAMIC_MCMC_WORKERS:-4}"

exec "$script_dir/LOCAL_refreshed288_launch_20260429_dynamic72_qdesn_comparable_v1.sh" "$@"

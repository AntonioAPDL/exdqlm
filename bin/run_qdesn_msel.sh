#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

export OMP_NUM_THREADS="${OMP_NUM_THREADS:-1}"
export MKL_NUM_THREADS="${MKL_NUM_THREADS:-1}"
export OPENBLAS_NUM_THREADS="${OPENBLAS_NUM_THREADS:-1}"
export VECLIB_MAXIMUM_THREADS="${VECLIB_MAXIMUM_THREADS:-1}"
export BLAS_NUM_THREADS="${BLAS_NUM_THREADS:-1}"

STAGE="${STAGE:-coarse}"
PARALLEL="${PARALLEL:-TRUE}"

DEFAULT_WORKERS="$(( $(nproc 2>/dev/null || getconf _NPROCESSORS_ONLN || echo 2) - 1 ))"
[[ $DEFAULT_WORKERS -lt 1 ]] && DEFAULT_WORKERS=1
WORKERS="${WORKERS:-$DEFAULT_WORKERS}"
[[ $WORKERS -lt 1 ]] && WORKERS=1

DATA="${DATA:-}"
PLOT="${PLOT:-FALSE}"
KEEP="${KEEP:-TRUE}"
PROGRESS_EVERY="${PROGRESS_EVERY:-1}"
GRID="${GRID:-default}"
LIMIT_SPECS="${LIMIT_SPECS:-}"
GRID_SEED="${GRID_SEED:-42}"
SEEDS="${SEEDS:-42,101}"

ARGS=( "--stage=${STAGE}" "--parallel=${PARALLEL}" "--workers=${WORKERS}"
       "--plot=${PLOT}" "--keep_artifacts=${KEEP}" "--progress_every=${PROGRESS_EVERY}"
       "--grid=${GRID}" "--grid_seed=${GRID_SEED}" "--seeds=${SEEDS}" )
[[ -n "${LIMIT_SPECS}" ]] && ARGS+=( "--limit_specs=${LIMIT_SPECS}" )
[[ -n "${DATA}" ]] && ARGS+=( "--data=${DATA}" )

mkdir -p logs
LOG="logs/run_${STAGE}_$(date +%F_%H%M).log"
echo "Launching selector (stage=${STAGE}, workers=${WORKERS}) — logging to ${LOG}"

cleanup() {
  echo ">> Cleanup: terminating R workers..."
  # Try graceful first
  pkill -u "$USER" -TERM -f 'parallel:::.workRSOCK|slaveRSOCK' || true
  sleep 1
  # Then force anything left
  pkill -u "$USER" -KILL -f 'parallel:::.workRSOCK|slaveRSOCK' || true
}
trap cleanup INT TERM

# Do NOT 'exec'—we want the trap to still run
Rscript scripts/driver_model_selection.R "${ARGS[@]}" 2>&1 | tee "${LOG}"
trap - INT TERM

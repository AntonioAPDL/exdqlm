#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

# --- sanity: tmux available ---
if ! command -v tmux >/dev/null 2>&1; then
  echo "ERROR: tmux not found in PATH. Install tmux and retry." >&2
  exit 1
fi

# --- single-thread defaults for any BLAS on the launcher side too ---
export OMP_NUM_THREADS="${OMP_NUM_THREADS:-1}"
export MKL_NUM_THREADS="${MKL_NUM_THREADS:-1}"
export OPENBLAS_NUM_THREADS="${OPENBLAS_NUM_THREADS:-1}"
export VECLIB_MAXIMUM_THREADS="${VECLIB_MAXIMUM_THREADS:-1}"
export BLAS_NUM_THREADS="${BLAS_NUM_THREADS:-1}"

# --- knobs (env overridable) ---
SESSION="${SESSION:-qdesn-msel}"
WIN_NAME_PREFIX="msel"
STAMP="$(date +%Y%m%d_%H%M%S)"
WIN_NAME="${WIN_NAME_PREFIX}-${STAMP}"

# These flow into bin/run_qdesn_msel.sh via env
STAGE="${STAGE:-coarse}"
PARALLEL="${PARALLEL:-TRUE}"
# If WORKERS is unset, run_qdesn_msel.sh computes a good default from nproc - RESERVE_CORES
WORKERS="${WORKERS:-}"
RESERVE_CORES="${RESERVE_CORES:-2}"
DATA="${DATA:-}"
PLOT="${PLOT:-FALSE}"
KEEP="${KEEP:-TRUE}"
PROGRESS_EVERY="${PROGRESS_EVERY:-1}"
GRID="${GRID:-default}"
LIMIT_SPECS="${LIMIT_SPECS:-}"
GRID_SEED="${GRID_SEED:-42}"
SEEDS="${SEEDS:-42,101}"

# Build the command we’ll run inside tmux
# (quote values so spaces in DATA path, etc. are safe)
RUN_CMD=$'bash -lc '\''
STAGE='"'"'"${STAGE}"'"'"' \
PARALLEL='"'"'"${PARALLEL}"'"'"' \
'"$( [[ -n "${WORKERS}" ]] && printf "WORKERS='%s' " "${WORKERS}" )$"' \
RESERVE_CORES='"'"'"${RESERVE_CORES}"'"'"' \
DATA='"'"'"${DATA}"'"'"' \
PLOT='"'"'"${PLOT}"'"'"' \
KEEP='"'"'"${KEEP}"'"'"' \
PROGRESS_EVERY='"'"'"${PROGRESS_EVERY}"'"'"' \
GRID='"'"'"${GRID}"'"'"' \
LIMIT_SPECS='"'"'"${LIMIT_SPECS}"'"'"' \
GRID_SEED='"'"'"${GRID_SEED}"'"'"' \
SEEDS='"'"'"${SEEDS}"'"'"' \
./bin/run_qdesn_msel.sh
'\'''

# Create or reuse session
if tmux has-session -t "${SESSION}" 2>/dev/null; then
  # session exists: create a new window
  tmux new-window -t "${SESSION}" -n "${WIN_NAME}"
else
  # create a new detached session with first window
  tmux new-session -d -s "${SESSION}" -n "${WIN_NAME}"
  # keep windows open on exit so you can inspect after finish
  tmux set-option -t "${SESSION}" remain-on-exit on >/dev/null
fi

# Send the command to the new window
tmux send-keys -t "${SESSION}:${WIN_NAME}" "${RUN_CMD}" C-m

echo "Launched in tmux session: ${SESSION}, window: ${WIN_NAME}"
echo "Attach:   tmux attach -t ${SESSION}"
echo "Detach:   Ctrl-b then d"
echo "Logs:     tail -f logs/run_${STAGE}_\$(ls -t logs/run_${STAGE}_*.log | head -n1)"

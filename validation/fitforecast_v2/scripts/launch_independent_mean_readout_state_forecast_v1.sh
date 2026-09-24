#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
WORKERS=8
SCHEDULER="load_balanced"
BACKGROUND=false
RESUME=false
RUN_ID=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --workers) WORKERS="$2"; shift 2 ;;
    --scheduler) SCHEDULER="$2"; shift 2 ;;
    --background) BACKGROUND=true; shift ;;
    --resume) RESUME=true; shift ;;
    --run-id) RUN_ID="$2"; shift 2 ;;
    --repo-root) REPO_ROOT="$2"; shift 2 ;;
    *) echo "Unknown argument: $1" >&2; exit 2 ;;
  esac
done

cd "$REPO_ROOT"
EXPECTED_BRANCH="validation/independent-fixed-state-forecast-plan-20260924"
SESSION="ind_qdesn_mean_readout_state_v1_8core"
if [[ "$(hostname -f)" != "muscat.be.ucsc.edu" ]]; then
  echo "Launch refused: execution host must be muscat.be.ucsc.edu." >&2
  exit 2
fi
if [[ "$WORKERS" -ne 8 || "$SCHEDULER" != "load_balanced" ]]; then
  echo "Launch refused: fixed contract is eight load-balanced workers." >&2
  exit 2
fi
if [[ "$(git branch --show-current)" != "$EXPECTED_BRANCH" ]]; then
  echo "Launch refused outside $EXPECTED_BRANCH." >&2
  exit 2
fi
if [[ -n "$(git status --porcelain)" ]]; then
  echo "Launch refused from a dirty worktree." >&2
  git status --short >&2
  exit 2
fi
if ! git rev-parse --abbrev-ref '@{upstream}' >/dev/null 2>&1; then
  echo "Launch refused without an upstream." >&2
  exit 2
fi
read -r BEHIND AHEAD < <(git rev-list --left-right --count '@{upstream}...HEAD')
if [[ "$BEHIND" -ne 0 || "$AHEAD" -ne 0 ]]; then
  echo "Launch refused: upstream mismatch (behind=$BEHIND ahead=$AHEAD)." >&2
  exit 2
fi
if tmux has-session -t "$SESSION" 2>/dev/null; then
  echo "Launch refused: tmux session already exists: $SESSION" >&2
  exit 2
fi
if pgrep -af 'orchestrate_independent_mean_readout_state_forecast_v1[.]R' >/dev/null; then
  echo "Launch refused: an existing campaign controller is active." >&2
  exit 2
fi

CORES="$(getconf _NPROCESSORS_ONLN)"
MEM_KIB="$(awk '/^MemAvailable:/ {print $2}' /proc/meminfo)"
DISK_KIB="$(df -Pk /data | awk 'NR==2 {print $4}')"
if [[ "$CORES" -lt 8 || "$MEM_KIB" -lt $((64 * 1024 * 1024)) ||
      "$DISK_KIB" -lt $((50 * 1024 * 1024)) ]]; then
  echo "Launch refused by resource gate: cores=$CORES mem_kib=$MEM_KIB disk_kib=$DISK_KIB" >&2
  exit 2
fi

mapfile -t CPU_IDS < <(
  for cpu in $(seq 0 $((CORES - 1))); do
    usage="$(ps -eLo psr=,pcpu= | awk -v c="$cpu" '$1 == c {s += $2} END {printf "%.6f", s + 0}')"
    printf '%s %s\n' "$usage" "$cpu"
  done | sort -n -k1,1 -k2,2 | head -n 8 | awk '{print $2}'
)
if [[ "${#CPU_IDS[@]}" -ne 8 ]]; then
  echo "Launch refused: could not select eight CPU IDs." >&2
  exit 2
fi
CPU_CSV="$(IFS=,; echo "${CPU_IDS[*]}")"

export OMP_NUM_THREADS=1
export OMP_THREAD_LIMIT=1
export OPENBLAS_NUM_THREADS=1
export MKL_NUM_THREADS=1
export BLIS_NUM_THREADS=1
export VECLIB_MAXIMUM_THREADS=1
export NUMEXPR_NUM_THREADS=1
export RCPP_PARALLEL_NUM_THREADS=1
export IMRS_V1_LAUNCH_APPROVED=true

STAMP="$(date +%Y%m%d_%H%M%S)"
if [[ -z "$RUN_ID" ]]; then
  RUN_ID="independent_mean_readout_state_forecast_v1_${STAMP}"
fi
STATE_ROOT="$REPO_ROOT/reports/shared_fitforecast_v2_orchestration/$RUN_ID"
if [[ -d "$STATE_ROOT" && "$RESUME" != true ]]; then
  echo "Launch refused: run root exists without --resume: $STATE_ROOT" >&2
  exit 2
fi
PREFLIGHT_TMP="$(mktemp /tmp/imrs_v1_preflight_XXXXXX.log)"
MATERIALIZE_TMP="$(mktemp /tmp/imrs_v1_materialize_XXXXXX.log)"
trap 'rm -f "$PREFLIGHT_TMP" "$MATERIALIZE_TMP"' EXIT
Rscript -e '
  pkgload::load_all(".", quiet=TRUE)
  testthat::test_file("tests/testthat/test-qdesn-mean-readout-state-forecast.R", reporter="summary", stop_on_failure=TRUE)
  testthat::test_file("tests/testthat/test-qdesn-forecast-recursion-diagnostic.R", reporter="summary", stop_on_failure=TRUE)
  harness_root <- normalizePath("validation/fitforecast_v2")
  source(file.path(harness_root, "R", "utils.R"))
  ffv2_source_all(harness_root)
  testthat::test_file("validation/fitforecast_v2/tests/testthat/test-independent-mean-readout-state-forecast-v1.R", reporter="summary", stop_on_failure=TRUE)
' >"$PREFLIGHT_TMP" 2>&1

MATERIALIZER="validation/fitforecast_v2/scripts/materialize_independent_mean_readout_state_forecast_v1.R"
if [[ ! -f "$STATE_ROOT/manifests/materialization_manifest.json" ]]; then
  if [[ -d "$STATE_ROOT" && -n "$(find "$STATE_ROOT" -mindepth 1 -maxdepth 1 -print -quit)" ]]; then
    echo "Launch refused: nonempty resume root lacks a materialization manifest." >&2
    exit 2
  fi
  Rscript "$MATERIALIZER" --repo-root "$REPO_ROOT" --run-id "$RUN_ID" \
    --state-root "$STATE_ROOT" >"$MATERIALIZE_TMP" 2>&1
fi
mkdir -p "$STATE_ROOT/logs" "$STATE_ROOT/manifests"
PREFLIGHT_LOG="$STATE_ROOT/logs/preflight_tests.log"
mv "$PREFLIGHT_TMP" "$PREFLIGHT_LOG"
if [[ -s "$MATERIALIZE_TMP" ]]; then
  mv "$MATERIALIZE_TMP" "$STATE_ROOT/logs/materialization.log"
fi

Rscript - "$STATE_ROOT" "$CPU_CSV" "$CORES" "$MEM_KIB" "$DISK_KIB" \
  "$PREFLIGHT_LOG" <<'RSCRIPT'
args <- commandArgs(TRUE)
state_root <- args[[1L]]
payload <- list(
  schema_version = "independent_mean_readout_state_forecast_v1",
  checked_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"),
  host = Sys.info()[["nodename"]],
  branch = system("git branch --show-current", intern = TRUE),
  git_commit = system("git rev-parse HEAD", intern = TRUE),
  upstream = system("git rev-parse @{upstream}", intern = TRUE),
  workers = 8L, threads_per_worker = 1L,
  cpu_ids = as.integer(strsplit(args[[2L]], ",", fixed = TRUE)[[1L]]),
  logical_cores = as.integer(args[[3L]]),
  memory_available_kib = as.numeric(args[[4L]]),
  disk_available_kib = as.numeric(args[[5L]]),
  thread_environment = as.list(Sys.getenv(c(
    "OMP_NUM_THREADS", "OMP_THREAD_LIMIT", "OPENBLAS_NUM_THREADS",
    "MKL_NUM_THREADS", "BLIS_NUM_THREADS", "VECLIB_MAXIMUM_THREADS",
    "NUMEXPR_NUM_THREADS",
    "RCPP_PARALLEL_NUM_THREADS"
  ))),
  preflight_test_log = normalizePath(args[[6L]], winslash = "/", mustWork = TRUE),
  preflight_test_log_sha256 = digest::digest(
    file = args[[6L]], algo = "sha256", serialize = FALSE
  )
)
jsonlite::write_json(
  payload, file.path(state_root, "manifests", "launch_preflight.json"),
  auto_unbox = TRUE, pretty = TRUE, digits = NA
)
RSCRIPT

ORCHESTRATOR="validation/fitforecast_v2/scripts/orchestrate_independent_mean_readout_state_forecast_v1.R"
STDOUT_LOG="$STATE_ROOT/logs/orchestration.stdout.log"
COMMAND="cd '$REPO_ROOT' && exec env OMP_NUM_THREADS=1 OMP_THREAD_LIMIT=1 OPENBLAS_NUM_THREADS=1 MKL_NUM_THREADS=1 BLIS_NUM_THREADS=1 VECLIB_MAXIMUM_THREADS=1 NUMEXPR_NUM_THREADS=1 RCPP_PARALLEL_NUM_THREADS=1 IMRS_V1_LAUNCH_APPROVED=true Rscript '$ORCHESTRATOR' --repo-root '$REPO_ROOT' --state-root '$STATE_ROOT' --workers 8 --cpu-ids '$CPU_CSV' --approved true > '$STDOUT_LOG' 2>&1"
printf '%s\n' "$COMMAND" >"$STATE_ROOT/manifests/launch_command.txt"
printf '%s\n' "$SESSION" >"$STATE_ROOT/manifests/tmux_session.txt"

if [[ "$BACKGROUND" == true ]]; then
  tmux new-session -d -s "$SESSION" "$COMMAND"
  sleep 3
  if ! tmux has-session -t "$SESSION" 2>/dev/null; then
    echo "Controller exited during startup; inspect $STDOUT_LOG" >&2
    exit 3
  fi
else
  bash -lc "$COMMAND"
fi

Rscript validation/fitforecast_v2/scripts/healthcheck_independent_mean_readout_state_forecast_v1.R \
  --state-root "$STATE_ROOT" || true
printf 'session=%s\nrun_id=%s\nworkers=%s\ncpu_ids=%s\nstate_root=%s\nstdout_log=%s\n' \
  "$SESSION" "$RUN_ID" "$WORKERS" "$CPU_CSV" "$STATE_ROOT" "$STDOUT_LOG"

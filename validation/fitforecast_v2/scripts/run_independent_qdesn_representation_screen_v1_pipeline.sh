#!/usr/bin/env bash
set -euo pipefail

repo_root=${REPO_ROOT:?REPO_ROOT is required}
run_root=${RUN_ROOT:?RUN_ROOT is required}
workers=${WORKERS:-15}
cpu_set=${CPU_SET:-32-46}
rscript=${RSCRIPT:-$(command -v Rscript)}
manager="$repo_root/validation/fitforecast_v2/scripts/manage_independent_qdesn_representation_screen_v1.R"
worker="$repo_root/validation/fitforecast_v2/scripts/run_independent_qdesn_representation_screen_v1_job.R"
preflight="$repo_root/validation/fitforecast_v2/scripts/preflight_independent_qdesn_representation_screen_v1.R"

export OMP_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 MKL_NUM_THREADS=1
export VECLIB_MAXIMUM_THREADS=1 NUMEXPR_NUM_THREADS=1
export RCPP_PARALLEL_NUM_THREADS=1

fail() { printf 'FATAL: %s\n' "$*" >&2; exit 1; }
branch=$(git -C "$repo_root" branch --show-current)
[[ "$branch" == "validation/independent-qdesn-representation-screen-v1-20260929" ]] ||
  fail "wrong branch: $branch"
[[ -z $(git -C "$repo_root" status --porcelain) ]] || fail "worktree is dirty"
upstream=$(git -C "$repo_root" rev-parse --abbrev-ref --symbolic-full-name '@{upstream}')
read -r behind ahead < <(git -C "$repo_root" rev-list --left-right --count "$upstream...HEAD")
[[ "$behind" -eq 0 && "$ahead" -eq 0 ]] ||
  fail "branch divergence behind=$behind ahead=$ahead"

load_one=$(cut -d' ' -f1 /proc/loadavg)
available_mem_gb=$(awk '/MemAvailable:/ {printf "%d", $2/1024/1024}' /proc/meminfo)
available_disk_gb=$(df -Pk /data | awk 'NR==2 {printf "%d", $4/1024/1024}')
awk -v x="$load_one" 'BEGIN {exit !(x < 48)}' || fail "load gate: $load_one"
((available_mem_gb >= 96)) || fail "memory gate: ${available_mem_gb} GiB"
((available_disk_gb >= 240)) || fail "disk gate: ${available_disk_gb} GiB"

mkdir -p "$run_root"
lock="$run_root/.pipeline_lock"
if ! mkdir "$lock" 2>/dev/null; then
  old_pid=$(cat "$lock/pid" 2>/dev/null || true)
  [[ "$old_pid" =~ ^[0-9]+$ && -d /proc/$old_pid ]] &&
    fail "active pipeline lock PID $old_pid"
  rm -rf "$lock"
  mkdir "$lock"
fi
printf '%s\n' "$$" > "$lock/pid"
trap 'rm -rf "$lock"' EXIT

if [[ ! -f "$run_root/plans/ridge_screen.csv" ]]; then
  "$rscript" --vanilla "$manager" --action materialize --run-root "$run_root"
fi
"$rscript" --vanilla "$preflight" --run-root "$run_root"

run_configs() {
  local stage=$1
  shift
  local -a configs=("$@")
  ((${#configs[@]})) || return 0
  mkdir -p "$run_root/logs/$stage"
  export repo_root run_root stage rscript worker cpu_set
  printf '%s\0' "${configs[@]}" | xargs -0 -n1 -P "$workers" bash -c '
    cfg=$1
    id=$(basename "$cfg" .json)
    taskset -c "$cpu_set" "$rscript" --vanilla "$worker" --config "$cfg" \
      > "$run_root/logs/$stage/$id.log" 2>&1
  ' _
}

pending_stage() {
  "$rscript" --vanilla "$manager" --action pending \
    --run-root "$run_root" --stage "$1"
}

run_stage() {
  local stage=$1
  local canary_mode=${2:-one}
  mapfile -t pending < <(pending_stage "$stage")
  printf 'stage=%s planned=%s pending=%s\n' "$stage" \
    "$(awk 'END {print NR-1}' "$run_root/plans/$stage.csv")" "${#pending[@]}"
  if ((${#pending[@]})); then
    local -a canaries=("${pending[0]}")
    if [[ "$canary_mode" == "likelihoods" ]]; then
      mapfile -t canaries < <("$rscript" --vanilla - \
        "$run_root/plans/$stage.csv" <<'RS'
args <- commandArgs(trailingOnly = TRUE)
x <- read.csv(args[[1]], stringsAsFactors = FALSE)
idx <- vapply(c("al", "exal"), function(z) which(x$likelihood_family == z)[1L],
              integer(1L))
cat(paste0(x$config_path[unique(idx)], "\n"), sep = "")
RS
      )
    fi
    run_configs "$stage" "${canaries[@]}"
    "$rscript" --vanilla - "${canaries[@]}" <<'RS'
args <- commandArgs(trailingOnly = TRUE)
for (path in args) {
  cfg <- jsonlite::read_json(path, simplifyVector = TRUE)
  status <- jsonlite::read_json(cfg$status_path, simplifyVector = TRUE)
  stopifnot(identical(status$status, "SUCCESS"), file.exists(cfg$result_path))
  observed <- unname(tools::sha256sum(cfg$result_path))
  stopifnot(identical(observed, status$result_sha256))
}
cat("PRODUCTION_CANARY_PASS\n")
RS
    mapfile -t pending < <(pending_stage "$stage")
  fi
  run_configs "$stage" "${pending[@]}"
  mapfile -t remaining < <(pending_stage "$stage")
  ((${#remaining[@]} == 0)) || fail "$stage has ${#remaining[@]} unfinished jobs"
  "$rscript" --vanilla "$manager" --action health --run-root "$run_root"
}

run_stage ridge_screen
[[ -f "$run_root/plans/rhs_screen.csv" ]] ||
  "$rscript" --vanilla "$manager" --action rhs --run-root "$run_root"
run_stage rhs_screen
[[ -f "$run_root/plans/quantile_vb.csv" ]] ||
  "$rscript" --vanilla "$manager" --action quantile --run-root "$run_root"
run_stage quantile_vb
[[ -f "$run_root/plans/mcmc_pilot.csv" ]] ||
  "$rscript" --vanilla "$manager" --action mcmc_pilot --run-root "$run_root"
run_stage mcmc_pilot likelihoods
[[ -f "$run_root/plans/replication.csv" ]] ||
  "$rscript" --vanilla "$manager" --action replication --run-root "$run_root"
run_stage replication likelihoods
[[ -f "$run_root/plans/confirmation.csv" ]] ||
  "$rscript" --vanilla "$manager" --action confirmation --run-root "$run_root"
run_stage confirmation likelihoods
"$rscript" --vanilla "$manager" --action verify --complete true --run-root "$run_root"
"$rscript" --vanilla "$manager" --action closeout --run-root "$run_root"
printf 'pipeline_complete run_root=%s\n' "$run_root"

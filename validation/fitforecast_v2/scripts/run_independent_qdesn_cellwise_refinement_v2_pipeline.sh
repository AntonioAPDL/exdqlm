#!/usr/bin/env bash
set -euo pipefail

repo_root=${REPO_ROOT:?REPO_ROOT is required}
run_root=${RUN_ROOT:?RUN_ROOT is required}
workers=${WORKERS:-15}
cpu_list=${CPU_LIST:?CPU_LIST is required as a comma-separated list}
rscript=${RSCRIPT:-$(command -v Rscript)}
manager="$repo_root/validation/fitforecast_v2/scripts/manage_independent_qdesn_cellwise_refinement_v2.R"
worker="$repo_root/validation/fitforecast_v2/scripts/run_independent_qdesn_cellwise_refinement_v2_job.R"
preflight="$repo_root/validation/fitforecast_v2/scripts/preflight_independent_qdesn_cellwise_refinement_v2.R"

export OMP_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 MKL_NUM_THREADS=1
export VECLIB_MAXIMUM_THREADS=1 NUMEXPR_NUM_THREADS=1
export RCPP_PARALLEL_NUM_THREADS=1 IQCR_V2_CPU_LIST="$cpu_list"

fail() { printf 'FATAL: %s\n' "$*" >&2; exit 1; }

branch=$(git -C "$repo_root" branch --show-current)
[[ "$branch" == "validation/independent-qdesn-cellwise-refinement-v2-20260929" ]] ||
  fail "wrong branch: $branch"
[[ -z $(git -C "$repo_root" status --porcelain) ]] || fail "worktree is dirty"
upstream=$(git -C "$repo_root" rev-parse --abbrev-ref --symbolic-full-name '@{upstream}')
read -r behind ahead < <(git -C "$repo_root" rev-list --left-right --count "$upstream...HEAD")
[[ "$behind" -eq 0 && "$ahead" -eq 0 ]] ||
  fail "branch divergence behind=$behind ahead=$ahead"

IFS=',' read -r -a cpus <<< "$cpu_list"
[[ ${#cpus[@]} -eq "$workers" ]] ||
  fail "CPU_LIST has ${#cpus[@]} entries; WORKERS=$workers"
[[ $(printf '%s\n' "${cpus[@]}" | sort -nu | wc -l) -eq "$workers" ]] ||
  fail "CPU_LIST must contain $workers unique CPUs"
for cpu in "${cpus[@]}"; do
  [[ "$cpu" =~ ^[0-9]+$ ]] || fail "invalid CPU token: $cpu"
  ((cpu >= 0 && cpu < $(nproc))) || fail "CPU outside host range: $cpu"
done

load_one=$(cut -d' ' -f1 /proc/loadavg)
available_mem_gb=$(awk '/MemAvailable:/ {printf "%d", $2/1024/1024}' /proc/meminfo)
available_disk_gb=$(df -Pk /data | awk 'NR==2 {printf "%d", $4/1024/1024}')
awk -v x="$load_one" 'BEGIN {exit !(x < 56)}' || fail "load gate: $load_one"
((available_mem_gb >= 72)) || fail "memory gate: ${available_mem_gb} GiB"
((available_disk_gb >= 200)) || fail "disk gate: ${available_disk_gb} GiB"

mkdir -p "$run_root"
lock="$run_root/.pipeline_lock"
if ! mkdir "$lock" 2>/dev/null; then
  old_pid=$(cat "$lock/pid" 2>/dev/null || true)
  [[ "$old_pid" =~ ^[0-9]+$ && -d /proc/$old_pid ]] &&
    fail "active pipeline lock PID $old_pid"
  rm -f "$lock/pid"
  rmdir "$lock" 2>/dev/null || fail "stale lock contains unexpected files"
  mkdir "$lock"
fi
printf '%s\n' "$$" > "$lock/pid"
trap 'rm -f "$lock/pid"; rmdir "$lock" 2>/dev/null || true' EXIT

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
  export repo_root run_root stage rscript worker cpu_list
  printf '%s\0' "${configs[@]}" | xargs -0 -n1 -P "$workers" \
    --process-slot-var=IQCR_SLOT bash -c '
      cfg=$1
      id=$(basename "$cfg" .json)
      IFS="," read -r -a cpus <<< "$cpu_list"
      cpu=${cpus[$IQCR_SLOT]}
      taskset -c "$cpu" "$rscript" --vanilla "$worker" --config "$cfg" \
        > "$run_root/logs/$stage/$id.log" 2>&1
    ' _
}

pending_stage() {
  "$rscript" --vanilla "$manager" --action pending \
    --run-root "$run_root" --stage "$1"
}

verify_canaries() {
  "$rscript" --vanilla - "$@" <<'RS'
args <- commandArgs(trailingOnly = TRUE)
for (path in args) {
  cfg <- jsonlite::read_json(path, simplifyVector = TRUE)
  status <- jsonlite::read_json(cfg$status_path, simplifyVector = TRUE)
  stopifnot(identical(status$status, "SUCCESS"), file.exists(cfg$result_path))
  stopifnot(identical(unname(tools::sha256sum(cfg$result_path)),
                      status$result_sha256))
}
cat("PRODUCTION_CANARY_PASS\n")
RS
}

likelihood_canaries() {
  "$rscript" --vanilla - "$1" <<'RS'
args <- commandArgs(trailingOnly = TRUE)
x <- read.csv(args[[1]], stringsAsFactors = FALSE)
idx <- vapply(c("al", "exal"), function(z) {
  match(z, x$likelihood_family)
}, integer(1L))
stopifnot(!anyNA(idx))
cat(paste0(x$config_path[unique(idx)], "\n"), sep = "")
RS
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
      mapfile -t canaries < <(likelihood_canaries "$run_root/plans/$stage.csv")
      local -a unfinished_canaries=()
      for cfg in "${canaries[@]}"; do
        status=$("$rscript" --vanilla - "$cfg" <<'RS'
cfg <- jsonlite::read_json(commandArgs(trailingOnly = TRUE)[[1]],
                           simplifyVector = TRUE)
if (!file.exists(cfg$status_path)) cat("pending\n") else {
  z <- jsonlite::read_json(cfg$status_path, simplifyVector = TRUE)
  cat(if (identical(z$status, "SUCCESS")) "success\n" else "pending\n")
}
RS
        )
        [[ "$status" == "success" ]] || unfinished_canaries+=("$cfg")
      done
      canaries=("${unfinished_canaries[@]}")
    fi
    if ((${#canaries[@]})); then
      run_configs "$stage" "${canaries[@]}"
      verify_canaries "${canaries[@]}"
    fi
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
[[ -f "$run_root/plans/rhs_refinement.csv" ]] ||
  "$rscript" --vanilla "$manager" --action rhs_refinement --run-root "$run_root"
run_stage rhs_refinement
[[ -f "$run_root/plans/quantile_bridge.csv" ]] ||
  "$rscript" --vanilla "$manager" --action quantile_bridge --run-root "$run_root"
run_stage quantile_bridge
[[ -f "$run_root/plans/quantile_refinement.csv" ]] ||
  "$rscript" --vanilla "$manager" --action quantile_refinement --run-root "$run_root"
run_stage quantile_refinement
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

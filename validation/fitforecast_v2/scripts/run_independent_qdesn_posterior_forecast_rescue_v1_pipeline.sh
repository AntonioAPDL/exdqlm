#!/usr/bin/env bash
set -euo pipefail

run_root=""
workers=15
while (($#)); do
  case "$1" in
    --run-root) run_root=${2:-}; shift 2 ;;
    --workers) workers=${2:-}; shift 2 ;;
    *) printf 'Unknown argument: %s\n' "$1" >&2; exit 2 ;;
  esac
done
if [[ -z "$run_root" || "$workers" -ne 15 ]]; then
  printf 'Usage: %s --run-root PATH --workers 15\n' "$0" >&2
  exit 2
fi

repo_root=$(git rev-parse --show-toplevel)
run_root=$(realpath -m "$run_root")
expected_branch="validation/independent-qdesn-posterior-forecast-rescue-v1-20260928"
manager="$repo_root/validation/fitforecast_v2/scripts/manage_independent_qdesn_posterior_forecast_rescue_v1.R"
worker="$repo_root/validation/fitforecast_v2/scripts/run_independent_qdesn_posterior_forecast_rescue_v1_job.R"
preflight="$repo_root/validation/fitforecast_v2/scripts/preflight_independent_qdesn_posterior_forecast_rescue_v1.R"
rscript=${RSCRIPT:-$(command -v Rscript)}

export OMP_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 MKL_NUM_THREADS=1
export VECLIB_MAXIMUM_THREADS=1 NUMEXPR_NUM_THREADS=1 RCPP_PARALLEL_NUM_THREADS=1

fail() { printf 'FATAL: %s\n' "$*" >&2; exit 1; }
branch=$(git -C "$repo_root" branch --show-current)
[[ "$branch" == "$expected_branch" ]] || fail "wrong branch: $branch"
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

if [[ ! -f "$run_root/plans/posterior_screen.csv" ]]; then
  "$rscript" --vanilla "$manager" --action materialize --run-root "$run_root"
fi
"$rscript" --vanilla "$preflight" --run-root "$run_root"

run_configs() {
  local stage=$1
  shift
  local -a configs=("$@")
  ((${#configs[@]})) || return 0
  mkdir -p "$run_root/logs/$stage"
  export repo_root run_root stage rscript worker
  printf '%s\0' "${configs[@]}" | xargs -0 -n1 -P "$workers" bash -c '
    cfg=$1
    id=$(basename "$cfg" .json)
    "$rscript" --vanilla "$worker" --config "$cfg" \
      > "$run_root/logs/$stage/$id.log" 2>&1
  ' _
}

run_stage() {
  local stage=$1
  local plan="$run_root/plans/$stage.csv"
  [[ -f "$plan" ]] || fail "missing plan: $plan"
  mapfile -t pending < <(
    "$rscript" --vanilla "$manager" --action pending \
      --run-root "$run_root" --stage "$stage"
  )
  printf 'stage=%s planned=%s pending=%s\n' "$stage" \
    "$(awk 'END {print NR-1}' "$plan")" "${#pending[@]}"
  if [[ "$stage" == "posterior_screen" && ${#pending[@]} -gt 0 ]]; then
    pending_file="$run_root/status/${stage}_pending_before_canary.txt"
    printf '%s\n' "${pending[@]}" > "$pending_file"
    mapfile -t canaries < <("$rscript" --vanilla - "$plan" "$pending_file" <<'RS'
args <- commandArgs(trailingOnly = TRUE)
x <- read.csv(args[[1]], stringsAsFactors = FALSE)
pending <- readLines(args[[2]], warn = FALSE)
x <- x[x$config_path %in% pending, , drop = FALSE]
likelihoods <- intersect(c("al", "exal"), unique(x$likelihood_family))
i <- vapply(likelihoods, function(likelihood) {
  which(x$likelihood_family == likelihood)[[1L]]
}, integer(1L))
cat(paste0(x$config_path[unique(i)], "\n"), sep = "")
RS
    )
    run_configs "$stage" "${canaries[@]}"
    "$rscript" --vanilla - "${canaries[@]}" <<'RS'
args <- commandArgs(trailingOnly = TRUE)
stopifnot(length(args) >= 1L, length(args) <= 2L)
for (config_path in args) {
  cfg <- jsonlite::read_json(config_path, simplifyVector = TRUE)
  status <- jsonlite::read_json(cfg$status_path, simplifyVector = TRUE)
  stopifnot(identical(status$status, "SUCCESS"), file.exists(cfg$result_path))
  observed_hash <- digest::digest(
    file = cfg$result_path, algo = "sha256", serialize = FALSE
  )
  stopifnot(identical(observed_hash, status$result_sha256))
  result <- read.csv(cfg$result_path, stringsAsFactors = FALSE,
                     check.names = FALSE)
  metric_fields <- grep(
    "^(fit|forecast)_(qtrue|check).+_(mean|lower|upper)$",
    names(result), value = TRUE
  )
  stopifnot(
    nrow(result) == 1L,
    identical(result$estimator, "mean_readout_state_recursive"),
    result$forecast_origins == 171L,
    result$forecast_pairs == 5130L,
    length(metric_fields) == 18L,
    all(is.finite(as.numeric(result[1L, metric_fields])))
  )
  if (identical(result$likelihood_family, "exal")) {
    stopifnot(identical(
      result$core_update_mode, "m0_v_collapsed_support_logit"
    ))
  }
}
cat("CANARY_CONTRACT_PASS\n")
RS
    mapfile -t pending < <(
      "$rscript" --vanilla "$manager" --action pending \
        --run-root "$run_root" --stage "$stage"
    )
  fi
  run_configs "$stage" "${pending[@]}"
  mapfile -t remaining < <(
    "$rscript" --vanilla "$manager" --action pending \
      --run-root "$run_root" --stage "$stage"
  )
  ((${#remaining[@]} == 0)) || fail "$stage has ${#remaining[@]} unfinished jobs"
  "$rscript" --vanilla "$manager" --action health --run-root "$run_root"
}

run_stage posterior_screen
if [[ ! -f "$run_root/plans/replication.csv" ]]; then
  "$rscript" --vanilla "$manager" --action replication --run-root "$run_root"
fi
run_stage replication
if [[ ! -f "$run_root/plans/confirmation.csv" ]]; then
  "$rscript" --vanilla "$manager" --action confirmation --run-root "$run_root"
fi
run_stage confirmation
"$rscript" --vanilla "$manager" --action verify --run-root "$run_root"
"$rscript" --vanilla "$manager" --action closeout --run-root "$run_root"
printf 'pipeline_complete run_root=%s\n' "$run_root"

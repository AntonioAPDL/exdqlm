#!/usr/bin/env bash
set -euo pipefail

repo_root=${REPO_ROOT:?REPO_ROOT is required}
run_root=${RUN_ROOT:?RUN_ROOT is required}
workers=${WORKERS:-15}
cpu_list=${CPU_LIST:-32,33,34,35,36,37,38,39,40,41,42,43,44,45,46}
rscript=${RSCRIPT:-/data/jaguir26/local/opt/R/4.6.0/bin/Rscript}
worker="$repo_root/validation/fitforecast_v2/scripts/run_independent_qdesn_corrected_forecast_v3_job.R"
audit="$repo_root/validation/fitforecast_v2/scripts/audit_independent_qdesn_corrected_forecast_v3_canary.R"
plan="$run_root/plans/forecast_canary.csv"
decision="$run_root/summaries/operator_smoke_decision.json"
lock="$run_root/.forecast_canary_lock"

gate=$("$rscript" --vanilla -e '
  x <- jsonlite::read_json(commandArgs(TRUE)[1], simplifyVector = TRUE)
  cat(as.character(x$decision))
' "$decision")
if [[ "$gate" != "PASS_UNLOCK_FORECAST_CANARY" ]]; then
  printf 'Operator-smoke gate is not open: %s\n' "$gate" >&2
  exit 1
fi
if [[ -e "$lock" ]]; then
  printf 'Forecast-canary lock already exists: %s\n' "$lock" >&2
  exit 1
fi
mkdir -p "$lock"
printf '%s\n' "$$" > "$lock/pid"
cleanup() { rm -rf "$lock"; }
trap cleanup EXIT INT TERM

export OMP_NUM_THREADS=1
export OPENBLAS_NUM_THREADS=1
export MKL_NUM_THREADS=1
export VECLIB_MAXIMUM_THREADS=1
export NUMEXPR_NUM_THREADS=1

IFS=',' read -r -a cpus <<< "$cpu_list"
if (( ${#cpus[@]} < workers )); then
  printf 'CPU_LIST provides %d CPUs for %d workers.\n' "${#cpus[@]}" "$workers" >&2
  exit 1
fi

mapfile -t configs < <("$rscript" --vanilla -e '
  x <- read.csv(commandArgs(TRUE)[1], check.names = FALSE)
  sha <- function(path) unname(tools::sha256sum(path))
  for (i in seq_len(nrow(x))) {
    done <- FALSE
    if (file.exists(x$status_path[[i]])) {
      payload <- tryCatch(
        jsonlite::read_json(x$status_path[[i]], simplifyVector = TRUE),
        error = function(e) NULL
      )
      if (!is.null(payload) && identical(toupper(payload$status), "SUCCESS") &&
          identical(as.character(payload$config_sha256),
                    sha(x$config_path[[i]]))) {
        artifact_paths <- unlist(payload$artifact_paths, use.names = TRUE)
        artifact_hashes <- unlist(payload$artifact_sha256, use.names = TRUE)
        done <- length(artifact_paths) > 0L &&
          setequal(names(artifact_paths), names(artifact_hashes)) &&
          all(file.exists(artifact_paths)) &&
          all(vapply(names(artifact_paths), function(name) {
            identical(sha(artifact_paths[[name]]), artifact_hashes[[name]])
          }, logical(1L)))
      }
    }
    if (!done) cat(x$config_path[[i]], "\n", sep = "")
  }
' "$plan")

if (( ${#configs[@]} > 0 )); then
  printf '%s\0' "${configs[@]}" | xargs -0 -n1 -P "$workers" \
    --process-slot-var=IQCF_SLOT bash -c '
      repo_root=$1
      run_root=$2
      rscript=$3
      worker=$4
      cpu_csv=$5
      cfg=$6
      IFS="," read -r -a cpus <<< "$cpu_csv"
      cpu=${cpus[$IQCF_SLOT]}
      id=$(basename "$cfg" .json)
      taskset -c "$cpu" "$rscript" --vanilla "$worker" --config "$cfg" \
        > "$run_root/logs/forecast_canary/$id.log" 2>&1
    ' _ "$repo_root" "$run_root" "$rscript" "$worker" "$cpu_list"
fi

"$rscript" --vanilla "$audit" --run-root "$run_root"

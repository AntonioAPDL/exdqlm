#!/usr/bin/env bash
set -euo pipefail

repo_root=${REPO_ROOT:?REPO_ROOT is required}
run_root=${RUN_ROOT:?RUN_ROOT is required}
stage=${STAGE:?STAGE is required}
workers=${WORKERS:-15}
cpu_list=${CPU_LIST:?CPU_LIST is required}
rscript=${RSCRIPT:-/data/jaguir26/local/opt/R/4.6.0/bin/Rscript}
qdesn_worker="$repo_root/validation/fitforecast_v2/scripts/run_independent_qdesn_corrected_broad_v4_job.R"
comparator_worker="$repo_root/validation/fitforecast_v2/scripts/run_exdqlm_dynamic_fitforecast_v2_row.R"
audit="$repo_root/validation/fitforecast_v2/scripts/audit_independent_qdesn_corrected_broad_v4.R"
plan="$run_root/plans/$stage.csv"
lock="$run_root/.$stage.lock"

case "$stage" in
  operator_smoke) ;;
  development_comparator)
    decision="$run_root/summaries/operator_smoke_decision.json"
    gate=$($rscript --vanilla -e '
      x <- jsonlite::read_json(commandArgs(TRUE)[1], simplifyVector = TRUE)
      cat(as.character(x$decision))
    ' "$decision")
    [[ "$gate" == "PASS_UNLOCK_BROAD_SCREEN" ]] || {
      printf 'Operator-smoke gate is not open: %s\n' "$gate" >&2
      exit 1
    }
    ;;
  broad_screen)
    decision="$run_root/summaries/operator_smoke_decision.json"
    gate=$($rscript --vanilla -e '
      x <- jsonlite::read_json(commandArgs(TRUE)[1], simplifyVector = TRUE)
      cat(as.character(x$decision))
    ' "$decision")
    [[ "$gate" == "PASS_UNLOCK_BROAD_SCREEN" ]] || {
      printf 'Operator-smoke gate is not open: %s\n' "$gate" >&2
      exit 1
    }
    comparator_decision="$run_root/summaries/development_comparator_decision.json"
    comparator_gate=$($rscript --vanilla -e '
      x <- jsonlite::read_json(commandArgs(TRUE)[1], simplifyVector = TRUE)
      cat(as.character(x$decision))
    ' "$comparator_decision")
    [[ "$comparator_gate" == "PASS_MATCHED_COMPARATORS_COMPLETE" ]] || {
      printf 'Matched-comparator gate is not open: %s\n' "$comparator_gate" >&2
      exit 1
    }
    ;;
  adaptive_refinement)
    decision="$run_root/summaries/broad_decision.json"
    gate=$($rscript --vanilla -e '
      x <- jsonlite::read_json(commandArgs(TRUE)[1], simplifyVector = TRUE)
      cat(as.character(x$decision))
    ' "$decision")
    [[ "$gate" == "PASS_READY_FOR_ADAPTIVE_REFINEMENT" ]] || {
      printf 'Broad gate is not open: %s\n' "$gate" >&2
      exit 1
    }
    ;;
  *) printf 'Unsupported stage: %s\n' "$stage" >&2; exit 1 ;;
esac

[[ -f "$plan" ]] || { printf 'Missing plan: %s\n' "$plan" >&2; exit 1; }
[[ ! -e "$lock" ]] || { printf 'Stage lock already exists: %s\n' "$lock" >&2; exit 1; }
mkdir -p "$run_root/logs/$stage"
mkdir -p "$lock"
printf '%s\n' "$$" > "$lock/pid"
cleanup() { rm -rf "$lock"; }
trap cleanup EXIT INT TERM

export OMP_NUM_THREADS=1
export OPENBLAS_NUM_THREADS=1
export MKL_NUM_THREADS=1
export VECLIB_MAXIMUM_THREADS=1
export NUMEXPR_NUM_THREADS=1
export RCPP_PARALLEL_NUM_THREADS=1

IFS=',' read -r -a cpus <<< "$cpu_list"
if (( ${#cpus[@]} < workers )); then
  printf 'CPU_LIST provides %d CPUs for %d workers.\n' "${#cpus[@]}" "$workers" >&2
  exit 1
fi

mapfile -t configs < <($rscript --vanilla -e '
  x <- read.csv(commandArgs(TRUE)[1], check.names = FALSE)
  stage <- commandArgs(TRUE)[2]
  sha <- function(path) unname(tools::sha256sum(path))
  for (i in seq_len(nrow(x))) {
    done <- FALSE
    if (file.exists(x$status_path[[i]])) {
      if (identical(stage, "development_comparator")) {
        payload <- tryCatch(
          read.csv(x$status_path[[i]], check.names = FALSE),
          error = function(e) NULL
        )
        done <- !is.null(payload) && nrow(payload) > 0L &&
          identical(tolower(tail(payload$status, 1L)), "done") &&
          identical(sha(x$config_path[[i]]), x$config_sha256[[i]]) &&
          file.exists(x$result_path[[i]])
      } else {
        payload <- tryCatch(
          jsonlite::read_json(x$status_path[[i]], simplifyVector = TRUE),
          error = function(e) NULL
        )
        if (!is.null(payload) && identical(toupper(payload$status), "SUCCESS") &&
            identical(as.character(payload$config_sha256), sha(x$config_path[[i]]))) {
          paths <- unlist(payload$artifact_paths, use.names = TRUE)
          hashes <- unlist(payload$artifact_sha256, use.names = TRUE)
          done <- length(paths) > 0L && setequal(names(paths), names(hashes)) &&
            all(file.exists(paths)) && all(vapply(names(paths), function(name) {
              identical(sha(paths[[name]]), hashes[[name]])
            }, logical(1L)))
        }
      }
    }
    if (!done) cat(x$config_path[[i]], "\n", sep = "")
  }
' "$plan" "$stage")

if (( ${#configs[@]} > 0 )); then
  printf '%s\0' "${configs[@]}" | xargs -0 -n1 -P "$workers" \
    --process-slot-var=IQCB_SLOT bash -c '
      repo_root=$1
      run_root=$2
      stage=$3
      rscript=$4
      qdesn_worker=$5
      comparator_worker=$6
      cpu_csv=$7
      cfg=$8
      IFS="," read -r -a cpus <<< "$cpu_csv"
      cpu=${cpus[$IQCB_SLOT]}
      id=$(basename "$cfg" .json)
      if [[ "$stage" == "development_comparator" ]]; then
        taskset -c "$cpu" "$rscript" --vanilla "$comparator_worker" \
          --row-config "$cfg" > "$run_root/logs/$stage/$id.log" 2>&1
      else
        taskset -c "$cpu" "$rscript" --vanilla "$qdesn_worker" --config "$cfg" \
          > "$run_root/logs/$stage/$id.log" 2>&1
      fi
    ' _ "$repo_root" "$run_root" "$stage" "$rscript" "$qdesn_worker" \
      "$comparator_worker" "$cpu_list"
fi

if [[ "$stage" == "operator_smoke" || "$stage" == "development_comparator" || \
      "$stage" == "broad_screen" ]]; then
  "$rscript" --vanilla "$audit" --repo-root "$repo_root" \
    --run-root "$run_root" --stage "$stage"
fi

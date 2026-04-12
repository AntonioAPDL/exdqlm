#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$REPO_ROOT"

OUT_DIR="$REPO_ROOT/tools/merge_reports"
TAG="original288_exactspec_multiseed_relaunch_20260412"
PREPARE_ONLY="0"
DRY_RUN="0"
SKIP_PREPARE="0"
FORCE="0"

for arg in "$@"; do
  case "$arg" in
    --tag=*) TAG="${arg#*=}" ;;
    --prepare-only=*) PREPARE_ONLY="${arg#*=}" ;;
    --dry-run=*) DRY_RUN="${arg#*=}" ;;
    --skip-prepare=*) SKIP_PREPARE="${arg#*=}" ;;
    --force=*) FORCE="${arg#*=}" ;;
    *) echo "Unknown arg: $arg" >&2; exit 1 ;;
  esac
done

PATHS_R='source("tools/merge_reports/LOCAL_original288_exactspec_multiseed_helpers_20260412.R"); x<-paths_original288_exactspec_multiseed(); cat(x$smoke_manifest,"\n",x$full_manifest,"\n",x$smoke_manifest_status,"\n",x$full_manifest_status,"\n",x$smoke_phase_summary,"\n",x$full_phase_summary,"\n",x$smoke_seed_ranking,"\n",x$full_seed_ranking,"\n",x$smoke_selected,"\n",x$full_selected,"\n",x$comparison_report,"\n", sep="")'
mapfile -t PATHS < <(Rscript -e "$PATHS_R")
SMOKE_MANIFEST="${PATHS[0]}"
FULL_MANIFEST="${PATHS[1]}"
SMOKE_STATUS="${PATHS[2]}"
FULL_STATUS="${PATHS[3]}"
SMOKE_PHASE_SUMMARY="${PATHS[4]}"
FULL_PHASE_SUMMARY="${PATHS[5]}"
SMOKE_RANKING="${PATHS[6]}"
FULL_RANKING="${PATHS[7]}"
SMOKE_SELECTED="${PATHS[8]}"
FULL_SELECTED="${PATHS[9]}"
COMPARISON_REPORT="${PATHS[10]}"

RUN_DIR="$OUT_DIR/full288_${TAG}"
LOG_DIR="$RUN_DIR/logs"
CONSOLE_LOG="$OUT_DIR/LOCAL_original288_exactspec_multiseed_launcher_console_20260412.log"
mkdir -p "$LOG_DIR"

export OMP_NUM_THREADS=1
export OPENBLAS_NUM_THREADS=1
export MKL_NUM_THREADS=1

phase_cap() {
  case "$1" in
    full_static_mcmc) echo 4 ;;
    full_static_vb) echo 8 ;;
    full_dynamic_vb) echo 6 ;;
    full_dynamic_mcmc) echo 3 ;;
    *) echo 2 ;;
  esac
}

phase_names_from_manifest() {
  local manifest="$1"
  Rscript -e "m<-read.csv('$manifest', stringsAsFactors=FALSE); p<-unique(m[order(m\$phase_order), 'phase']); cat(p, sep='\n')"
}

evaluate_manifest() {
  local manifest="$1"
  local status="$2"
  local phase_summary="$3"
  Rscript "$OUT_DIR/LOCAL_original288_exactspec_multiseed_evaluate_20260412.R" \
    --manifest="$manifest" \
    --status_out="$status" \
    --phase_out="$phase_summary"
}

reduce_manifest() {
  local status="$1"
  local ranking="$2"
  local selected="$3"
  Rscript "$OUT_DIR/LOCAL_original288_exactspec_multiseed_reduce_20260412.R" \
    --status="$status" \
    --ranking_out="$ranking" \
    --selected_out="$selected"
}

assert_manifest_complete() {
  local manifest="$1"
  local status="$2"
  Rscript -e "m<-read.csv('$manifest', stringsAsFactors=FALSE); s<-read.csv('$status', stringsAsFactors=FALSE); expected<-nrow(m); done<-sum(s\$gate_current!='MISSING'); if (done != expected) stop(sprintf('manifest completion mismatch: done=%d expected=%d', done, expected))"
}

assert_selected_count() {
  local manifest="$1"
  local selected="$2"
  Rscript -e "m<-read.csv('$manifest', stringsAsFactors=FALSE); s<-read.csv('$selected', stringsAsFactors=FALSE); expected<-length(unique(m\$base_row_id)); if (nrow(s) != expected) stop(sprintf('selected rows %d != expected %d', nrow(s), expected))"
}

run_phase() {
  local manifest="$1"
  local phase_name="$2"
  local ids_file="$RUN_DIR/${phase_name}_ids.txt"
  local max_parallel
  max_parallel="$(phase_cap "$phase_name")"

  Rscript -e "m<-read.csv('$manifest', stringsAsFactors=FALSE); m<-m[m\$phase=='$phase_name' & !m\$missing_inputs, , drop=FALSE]; writeLines(as.character(m\$row_id), '$ids_file')"

  if [[ ! -s "$ids_file" ]]; then
    echo "[exactspec-multiseed] no rows for $phase_name"
    return 0
  fi

  echo "[exactspec-multiseed] launching $phase_name with max_parallel=$max_parallel"
  if [[ "$DRY_RUN" == "1" ]]; then
    cat "$ids_file"
  else
    set +e
    xargs -a "$ids_file" -P "$max_parallel" -I{} bash -lc '
      id="$1"
      repo_root="$2"
      manifest="$3"
      tag="$4"
      force="$5"
      log_dir="$6"
      phase_name="$7"
      log="$log_dir/${phase_name}_row_${id}.log"
      cd "$repo_root"
      Rscript tools/merge_reports/LOCAL_original288_exactspec_multiseed_run_row_20260412.R \
        --manifest="$manifest" \
        --row_id="$id" \
        --tag="$tag" \
        --force="$force" > "$log" 2>&1
    ' _ {} "$REPO_ROOT" "$manifest" "$TAG" "$FORCE" "$LOG_DIR" "$phase_name"
    local phase_rc=$?
    set -e
    echo "[exactspec-multiseed] $phase_name xargs exit_code=$phase_rc"
  fi
}

echo "[exactspec-multiseed] repo_root=$REPO_ROOT" | tee "$CONSOLE_LOG"
echo "[exactspec-multiseed] tag=$TAG" | tee -a "$CONSOLE_LOG"

if [[ "$SKIP_PREPARE" != "1" ]]; then
  echo "[exactspec-multiseed] prepare manifests" | tee -a "$CONSOLE_LOG"
  Rscript "$OUT_DIR/LOCAL_original288_exactspec_multiseed_prepare_20260412.R" | tee -a "$CONSOLE_LOG"
else
  echo "[exactspec-multiseed] skip prepare requested" | tee -a "$CONSOLE_LOG"
fi

echo "[exactspec-multiseed] initial smoke evaluate" | tee -a "$CONSOLE_LOG"
evaluate_manifest "$SMOKE_MANIFEST" "$SMOKE_STATUS" "$SMOKE_PHASE_SUMMARY" | tee -a "$CONSOLE_LOG"

if [[ "$PREPARE_ONLY" == "1" ]]; then
  echo "[exactspec-multiseed] prepare-only complete" | tee -a "$CONSOLE_LOG"
  exit 0
fi

while IFS= read -r phase_name; do
  [[ -z "$phase_name" ]] && continue
  run_phase "$SMOKE_MANIFEST" "$phase_name" | tee -a "$CONSOLE_LOG"
  evaluate_manifest "$SMOKE_MANIFEST" "$SMOKE_STATUS" "$SMOKE_PHASE_SUMMARY" | tee -a "$CONSOLE_LOG"
done < <(phase_names_from_manifest "$SMOKE_MANIFEST")

if [[ "$DRY_RUN" != "1" ]]; then
  assert_manifest_complete "$SMOKE_MANIFEST" "$SMOKE_STATUS"
  reduce_manifest "$SMOKE_STATUS" "$SMOKE_RANKING" "$SMOKE_SELECTED" | tee -a "$CONSOLE_LOG"
  assert_selected_count "$SMOKE_MANIFEST" "$SMOKE_SELECTED"
fi

while IFS= read -r phase_name; do
  [[ -z "$phase_name" ]] && continue
  run_phase "$FULL_MANIFEST" "$phase_name" | tee -a "$CONSOLE_LOG"
  evaluate_manifest "$FULL_MANIFEST" "$FULL_STATUS" "$FULL_PHASE_SUMMARY" | tee -a "$CONSOLE_LOG"
done < <(phase_names_from_manifest "$FULL_MANIFEST")

if [[ "$DRY_RUN" != "1" ]]; then
  assert_manifest_complete "$FULL_MANIFEST" "$FULL_STATUS"
  reduce_manifest "$FULL_STATUS" "$FULL_RANKING" "$FULL_SELECTED" | tee -a "$CONSOLE_LOG"
  assert_selected_count "$FULL_MANIFEST" "$FULL_SELECTED"
  Rscript "$OUT_DIR/LOCAL_original288_exactspec_multiseed_refresh_comparison_20260412.R" | tee -a "$CONSOLE_LOG"
fi

echo "[exactspec-multiseed] comparison_report=$COMPARISON_REPORT" | tee -a "$CONSOLE_LOG"
echo "[exactspec-multiseed] done" | tee -a "$CONSOLE_LOG"

#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$REPO_ROOT"

OUT_DIR="$REPO_ROOT/tools/merge_reports"
TAG="original288_normalized_multiseed_relaunch_20260411"
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

PATHS_R='p<-source("tools/merge_reports/LOCAL_original288_normalized_multiseed_helpers_20260411.R"); x<-paths_original288_normalized_multiseed(); cat(x$pilot_manifest,"\n",x$full_manifest,"\n",x$pilot_manifest_status,"\n",x$full_manifest_status,"\n",x$pilot_phase_summary,"\n",x$full_phase_summary,"\n",x$pilot_seed_ranking,"\n",x$full_seed_ranking,"\n",x$pilot_selected,"\n",x$full_selected,"\n",x$comparison_report,"\n", sep="")'
mapfile -t PATHS < <(Rscript -e "$PATHS_R")
PILOT_MANIFEST="${PATHS[0]}"
FULL_MANIFEST="${PATHS[1]}"
PILOT_STATUS="${PATHS[2]}"
FULL_STATUS="${PATHS[3]}"
PILOT_PHASE_SUMMARY="${PATHS[4]}"
FULL_PHASE_SUMMARY="${PATHS[5]}"
PILOT_RANKING="${PATHS[6]}"
FULL_RANKING="${PATHS[7]}"
PILOT_SELECTED="${PATHS[8]}"
FULL_SELECTED="${PATHS[9]}"
COMPARISON_REPORT="${PATHS[10]}"

RUN_DIR="$OUT_DIR/full288_${TAG}"
LOG_DIR="$RUN_DIR/logs"
mkdir -p "$LOG_DIR"

export OMP_NUM_THREADS=1
export OPENBLAS_NUM_THREADS=1
export MKL_NUM_THREADS=1

phase_cap() {
  case "$1" in
    pilot_static_mcmc|full_static_mcmc) echo 4 ;;
    pilot_static_vb|full_static_vb) echo 8 ;;
    pilot_dynamic_vb|full_dynamic_vb) echo 6 ;;
    pilot_dynamic_mcmc|full_dynamic_mcmc) echo 3 ;;
    *) echo 2 ;;
  esac
}

evaluate_manifest() {
  local manifest="$1"
  local status="$2"
  local phase_summary="$3"
  Rscript "$OUT_DIR/LOCAL_original288_normalized_multiseed_evaluate_20260411.R" \
    --manifest="$manifest" \
    --status_out="$status" \
    --phase_out="$phase_summary"
}

reduce_manifest() {
  local status="$1"
  local ranking="$2"
  local selected="$3"
  Rscript "$OUT_DIR/LOCAL_original288_normalized_multiseed_reduce_20260411.R" \
    --status="$status" \
    --ranking_out="$ranking" \
    --selected_out="$selected"
}

run_phase() {
  local manifest="$1"
  local phase_name="$2"
  local ids_file="$RUN_DIR/${phase_name}_ids.txt"
  local max_parallel
  max_parallel="$(phase_cap "$phase_name")"

  Rscript -e "m<-read.csv('$manifest', stringsAsFactors=FALSE); m<-m[m\$phase=='$phase_name' & !m\$missing_inputs, , drop=FALSE]; writeLines(as.character(m\$row_id), '$ids_file')"

  if [[ ! -s "$ids_file" ]]; then
    echo "[normalized-multiseed] no rows for $phase_name"
    return 0
  fi

  echo "[normalized-multiseed] launching $phase_name with max_parallel=$max_parallel"
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
      Rscript tools/merge_reports/LOCAL_original288_normalized_multiseed_run_row_20260411.R \
        --manifest="$manifest" \
        --row_id="$id" \
        --tag="$tag" \
        --force="$force" > "$log" 2>&1
    ' _ {} "$REPO_ROOT" "$manifest" "$TAG" "$FORCE" "$LOG_DIR" "$phase_name"
    local phase_rc=$?
    set -e
    echo "[normalized-multiseed] $phase_name xargs exit_code=$phase_rc"
  fi
}

echo "[normalized-multiseed] repo_root=$REPO_ROOT"
echo "[normalized-multiseed] tag=$TAG"

if [[ "$SKIP_PREPARE" != "1" ]]; then
  echo "[normalized-multiseed] prepare manifests"
  Rscript "$OUT_DIR/LOCAL_original288_normalized_multiseed_prepare_20260411.R"
else
  echo "[normalized-multiseed] skip prepare requested"
fi

echo "[normalized-multiseed] initial pilot evaluate"
evaluate_manifest "$PILOT_MANIFEST" "$PILOT_STATUS" "$PILOT_PHASE_SUMMARY"

if [[ "$PREPARE_ONLY" == "1" ]]; then
  echo "[normalized-multiseed] prepare-only complete"
  exit 0
fi

for phase_name in pilot_static_mcmc pilot_static_vb pilot_dynamic_vb pilot_dynamic_mcmc; do
  run_phase "$PILOT_MANIFEST" "$phase_name"
  evaluate_manifest "$PILOT_MANIFEST" "$PILOT_STATUS" "$PILOT_PHASE_SUMMARY"
done

if [[ "$DRY_RUN" != "1" ]]; then
  reduce_manifest "$PILOT_STATUS" "$PILOT_RANKING" "$PILOT_SELECTED"
  Rscript -e "m<-read.csv('$PILOT_MANIFEST', stringsAsFactors=FALSE); s<-read.csv('$PILOT_SELECTED', stringsAsFactors=FALSE); expected<-length(unique(m\$base_row_id)); if (nrow(s) != expected) stop(sprintf('pilot selected rows %d != expected %d', nrow(s), expected))"
fi

for phase_name in full_static_mcmc full_static_vb full_dynamic_vb full_dynamic_mcmc; do
  run_phase "$FULL_MANIFEST" "$phase_name"
  evaluate_manifest "$FULL_MANIFEST" "$FULL_STATUS" "$FULL_PHASE_SUMMARY"
done

if [[ "$DRY_RUN" != "1" ]]; then
  reduce_manifest "$FULL_STATUS" "$FULL_RANKING" "$FULL_SELECTED"
  Rscript -e "m<-read.csv('$FULL_MANIFEST', stringsAsFactors=FALSE); s<-read.csv('$FULL_SELECTED', stringsAsFactors=FALSE); expected<-length(unique(m\$base_row_id)); if (nrow(s) != expected) stop(sprintf('full selected rows %d != expected %d', nrow(s), expected))"
  Rscript "$OUT_DIR/LOCAL_original288_normalized_multiseed_refresh_comparison_20260411.R"
fi

echo "[normalized-multiseed] comparison_report=$COMPARISON_REPORT"
echo "[normalized-multiseed] done"

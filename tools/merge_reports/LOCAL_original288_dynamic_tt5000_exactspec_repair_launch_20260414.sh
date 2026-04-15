#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$REPO_ROOT"

OUT_DIR="$REPO_ROOT/tools/merge_reports"
TAG="original288_dynamic_tt5000_exactspec_repair_20260414"
PREPARE_ONLY="0"
DRY_RUN="0"
SKIP_PREPARE="0"
FORCE="0"
MAX_PHASE1="3"
MAX_PHASE2="2"

for arg in "$@"; do
  case "$arg" in
    --tag=*) TAG="${arg#*=}" ;;
    --prepare-only=*) PREPARE_ONLY="${arg#*=}" ;;
    --dry-run=*) DRY_RUN="${arg#*=}" ;;
    --skip-prepare=*) SKIP_PREPARE="${arg#*=}" ;;
    --force=*) FORCE="${arg#*=}" ;;
    --max-phase1=*) MAX_PHASE1="${arg#*=}" ;;
    --max-phase2=*) MAX_PHASE2="${arg#*=}" ;;
    *) echo "Unknown arg: $arg" >&2; exit 1 ;;
  esac
done

PATHS_R='source("tools/merge_reports/LOCAL_original288_dynamic_tt5000_exactspec_repair_helpers_20260414.R"); x<-paths_original288_dynamic_tt5000_exactspec_repair(); cat(x$phase1_manifest,"\n",x$phase2_manifest,"\n",x$full_manifest,"\n",x$phase1_manifest_status,"\n",x$phase2_manifest_status,"\n",x$full_manifest_status,"\n",x$phase1_phase_summary,"\n",x$phase2_phase_summary,"\n",x$full_phase_summary,"\n",x$full_seed_ranking,"\n",x$full_selected,"\n",x$comparison_report,"\n", sep="")'
mapfile -t PATHS < <(Rscript -e "$PATHS_R")
PHASE1_MANIFEST="${PATHS[0]}"
PHASE2_MANIFEST="${PATHS[1]}"
FULL_MANIFEST="${PATHS[2]}"
PHASE1_STATUS="${PATHS[3]}"
PHASE2_STATUS="${PATHS[4]}"
FULL_STATUS="${PATHS[5]}"
PHASE1_PHASE_SUMMARY="${PATHS[6]}"
PHASE2_PHASE_SUMMARY="${PATHS[7]}"
FULL_PHASE_SUMMARY="${PATHS[8]}"
FULL_RANKING="${PATHS[9]}"
FULL_SELECTED="${PATHS[10]}"
COMPARISON_REPORT="${PATHS[11]}"

RUN_DIR="$OUT_DIR/full288_${TAG}"
LOG_DIR="$RUN_DIR/logs"
CONSOLE_LOG="$OUT_DIR/LOCAL_original288_dynamic_tt5000_exactspec_repair_launcher_console_20260414.log"
mkdir -p "$LOG_DIR"

export OMP_NUM_THREADS=1
export OPENBLAS_NUM_THREADS=1
export MKL_NUM_THREADS=1

evaluate_manifest() {
  local manifest="$1"
  local status="$2"
  local phase_summary="$3"
  Rscript "$OUT_DIR/LOCAL_original288_dynamic_tt5000_exactspec_repair_evaluate_20260414.R" \
    --manifest="$manifest" \
    --status_out="$status" \
    --phase_out="$phase_summary"
}

reduce_manifest() {
  local status="$1"
  local ranking="$2"
  local selected="$3"
  Rscript "$OUT_DIR/LOCAL_original288_dynamic_tt5000_exactspec_repair_reduce_20260414.R" \
    --status="$status" \
    --ranking_out="$ranking" \
    --selected_out="$selected"
}

assert_manifest_complete() {
  local manifest="$1"
  local status="$2"
  Rscript -e "m<-read.csv('$manifest', stringsAsFactors=FALSE); s<-read.csv('$status', stringsAsFactors=FALSE); if (nrow(m) == 0L) quit(save='no', status=0); expected<-nrow(m); done<-sum(s\$gate_current!='MISSING'); if (done != expected) stop(sprintf('manifest completion mismatch: done=%d expected=%d', done, expected))"
}

run_manifest_rows() {
  local manifest="$1"
  local phase_name="$2"
  local max_parallel="$3"
  local ids_file="$RUN_DIR/${phase_name}_ids.txt"

  Rscript -e "m<-read.csv('$manifest', stringsAsFactors=FALSE); if (nrow(m)==0L) { writeLines(character(), '$ids_file'); quit(save='no', status=0) }; m<-m[m\$phase=='$phase_name' & !m\$missing_inputs, , drop=FALSE]; writeLines(as.character(m\$row_id), '$ids_file')"

  if [[ ! -s "$ids_file" ]]; then
    echo "[dynamic-tt5000-exact-repair] no rows for $phase_name"
    return 0
  fi

  echo "[dynamic-tt5000-exact-repair] launching $phase_name with max_parallel=$max_parallel"
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
      Rscript tools/merge_reports/LOCAL_original288_dynamic_tt5000_exactspec_repair_run_row_20260414.R \
        --manifest="$manifest" \
        --row_id="$id" \
        --tag="$tag" \
        --force="$force" > "$log" 2>&1
    ' _ {} "$REPO_ROOT" "$manifest" "$TAG" "$FORCE" "$LOG_DIR" "$phase_name"
    local phase_rc=$?
    set -e
    echo "[dynamic-tt5000-exact-repair] $phase_name xargs exit_code=$phase_rc"
  fi
}

echo "[dynamic-tt5000-exact-repair] repo_root=$REPO_ROOT" | tee "$CONSOLE_LOG"
echo "[dynamic-tt5000-exact-repair] tag=$TAG" | tee -a "$CONSOLE_LOG"

if [[ "$SKIP_PREPARE" != "1" ]]; then
  echo "[dynamic-tt5000-exact-repair] prepare manifests" | tee -a "$CONSOLE_LOG"
  Rscript "$OUT_DIR/LOCAL_original288_dynamic_tt5000_exactspec_repair_prepare_20260414.R" | tee -a "$CONSOLE_LOG"
else
  echo "[dynamic-tt5000-exact-repair] skip prepare requested" | tee -a "$CONSOLE_LOG"
fi

evaluate_manifest "$PHASE1_MANIFEST" "$PHASE1_STATUS" "$PHASE1_PHASE_SUMMARY" | tee -a "$CONSOLE_LOG"

if [[ "$PREPARE_ONLY" == "1" ]]; then
  echo "[dynamic-tt5000-exact-repair] prepare-only complete" | tee -a "$CONSOLE_LOG"
  exit 0
fi

run_manifest_rows "$PHASE1_MANIFEST" "phase1_dynamic_tt5000_exact_replay" "$MAX_PHASE1" | tee -a "$CONSOLE_LOG"
evaluate_manifest "$PHASE1_MANIFEST" "$PHASE1_STATUS" "$PHASE1_PHASE_SUMMARY" | tee -a "$CONSOLE_LOG"

if [[ "$DRY_RUN" != "1" ]]; then
  assert_manifest_complete "$PHASE1_MANIFEST" "$PHASE1_STATUS"
  reduce_manifest "$PHASE1_STATUS" "$FULL_RANKING" "$FULL_SELECTED" | tee -a "$CONSOLE_LOG"
else
  echo "[dynamic-tt5000-exact-repair] dry-run complete after phase1 preview" | tee -a "$CONSOLE_LOG"
  exit 0
fi

echo "[dynamic-tt5000-exact-repair] build phase2 manifest" | tee -a "$CONSOLE_LOG"
Rscript "$OUT_DIR/LOCAL_original288_dynamic_tt5000_exactspec_repair_build_phase2_20260414.R" | tee -a "$CONSOLE_LOG"

evaluate_manifest "$FULL_MANIFEST" "$FULL_STATUS" "$FULL_PHASE_SUMMARY" | tee -a "$CONSOLE_LOG"

if [[ -f "$PHASE2_MANIFEST" ]] && [[ "$(Rscript -e "m<-read.csv('$PHASE2_MANIFEST', stringsAsFactors=FALSE); cat(nrow(m))")" != "0" ]]; then
  evaluate_manifest "$PHASE2_MANIFEST" "$PHASE2_STATUS" "$PHASE2_PHASE_SUMMARY" | tee -a "$CONSOLE_LOG"
  run_manifest_rows "$PHASE2_MANIFEST" "phase2_dynamic_tt5000_historical_repair" "$MAX_PHASE2" | tee -a "$CONSOLE_LOG"
  evaluate_manifest "$PHASE2_MANIFEST" "$PHASE2_STATUS" "$PHASE2_PHASE_SUMMARY" | tee -a "$CONSOLE_LOG"
fi

if [[ "$DRY_RUN" != "1" ]]; then
  evaluate_manifest "$FULL_MANIFEST" "$FULL_STATUS" "$FULL_PHASE_SUMMARY" | tee -a "$CONSOLE_LOG"
  assert_manifest_complete "$FULL_MANIFEST" "$FULL_STATUS"
  reduce_manifest "$FULL_STATUS" "$FULL_RANKING" "$FULL_SELECTED" | tee -a "$CONSOLE_LOG"
  Rscript "$OUT_DIR/LOCAL_original288_dynamic_tt5000_exactspec_repair_refresh_comparison_20260414.R" | tee -a "$CONSOLE_LOG"
fi

echo "[dynamic-tt5000-exact-repair] comparison_report=$COMPARISON_REPORT" | tee -a "$CONSOLE_LOG"
echo "[dynamic-tt5000-exact-repair] done" | tee -a "$CONSOLE_LOG"

#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$REPO_ROOT"

OUT_DIR="$REPO_ROOT/tools/merge_reports"
TAG="original288_syncedbase_dynamic_restored_closure_20260410"
MANIFEST="$OUT_DIR/LOCAL_original288_syncedbase_dynamic_restored_closure_manifest_20260410.csv"
PHASE="all"
MAX_REFINE=""
FORCE="0"
PREPARE_ONLY="0"
DRY_RUN="0"
SKIP_PREPARE="0"

for arg in "$@"; do
  case "$arg" in
    --tag=*) TAG="${arg#*=}" ;;
    --manifest=*) MANIFEST="${arg#*=}" ;;
    --phase=*) PHASE="${arg#*=}" ;;
    --max-refine=*) MAX_REFINE="${arg#*=}" ;;
    --force=*) FORCE="${arg#*=}" ;;
    --prepare-only=*) PREPARE_ONLY="${arg#*=}" ;;
    --dry-run=*) DRY_RUN="${arg#*=}" ;;
    --skip-prepare=*) SKIP_PREPARE="${arg#*=}" ;;
    *) echo "Unknown arg: $arg" >&2; exit 1 ;;
  esac
done

NPROC="$(nproc)"
if [[ -z "$MAX_REFINE" ]]; then
  MAX_REFINE="$(( NPROC > 10 ? 4 : (NPROC > 5 ? 3 : 2) ))"
fi

RUN_DIR="$OUT_DIR/full288_${TAG}"
LOG_DIR="$RUN_DIR/logs"

echo "[dynamic-restored-closure] repo_root=$REPO_ROOT"
echo "[dynamic-restored-closure] tag=$TAG"
echo "[dynamic-restored-closure] manifest=$MANIFEST"
echo "[dynamic-restored-closure] phase=$PHASE"
echo "[dynamic-restored-closure] max_refine=$MAX_REFINE force=$FORCE"

if [[ "$SKIP_PREPARE" != "1" ]]; then
  echo "[dynamic-restored-closure] prepare manifest"
  Rscript "$OUT_DIR/LOCAL_original288_syncedbase_dynamic_restored_closure_prepare_20260410.R"
else
  echo "[dynamic-restored-closure] skip prepare requested"
fi

mkdir -p "$LOG_DIR"

echo "[dynamic-restored-closure] prelaunch evaluate"
Rscript "$OUT_DIR/LOCAL_original288_syncedbase_dynamic_restored_closure_evaluate_20260410.R" --manifest="$MANIFEST" --tag="$TAG"

if [[ "$PREPARE_ONLY" == "1" ]]; then
  echo "[dynamic-restored-closure] prepare-only complete"
  exit 0
fi

export OMP_NUM_THREADS=1
export OPENBLAS_NUM_THREADS=1
export MKL_NUM_THREADS=1

run_phase() {
  local phase_name="$1"
  local max_parallel="$2"
  local ids_file="$RUN_DIR/${phase_name}_ids.txt"

  Rscript -e "m<-read.csv('$MANIFEST', stringsAsFactors=FALSE); m<-m[m\$phase=='$phase_name' & !m\$missing_inputs, , drop=FALSE]; writeLines(as.character(m\$row_id), '$ids_file')"

  if [[ ! -s "$ids_file" ]]; then
    echo "[dynamic-restored-closure] no rows for $phase_name"
    return 0
  fi

  echo "[dynamic-restored-closure] launching $phase_name with max_parallel=$max_parallel"
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
      Rscript tools/merge_reports/LOCAL_full288_case_runner_20260327.R --manifest="$manifest" --row_id="$id" --tag="$tag" --force="$force" > "$log" 2>&1
    ' _ {} "$REPO_ROOT" "$MANIFEST" "$TAG" "$FORCE" "$LOG_DIR" "$phase_name"
    local phase_rc=$?
    set -e
    echo "[dynamic-restored-closure] $phase_name xargs exit_code=$phase_rc"
  fi

  Rscript "$OUT_DIR/LOCAL_original288_syncedbase_dynamic_restored_closure_evaluate_20260410.R" --manifest="$MANIFEST" --tag="$TAG"

  if [[ "$DRY_RUN" != "1" ]]; then
    Rscript -e "s<-read.csv('$OUT_DIR/LOCAL_original288_syncedbase_dynamic_restored_closure_manifest_status_20260410.csv', stringsAsFactors=FALSE); d<-s[s\$phase=='$phase_name', , drop=FALSE]; if (sum(d\$gate_current=='MISSING') > 0L) { quit(save='no', status=1) }"
  fi
}

if [[ "$PHASE" == "all" || "$PHASE" == "phase1_dynamic_reinforcement" ]]; then
  run_phase "phase1_dynamic_reinforcement" "$MAX_REFINE"
fi
if [[ "$PHASE" == "all" || "$PHASE" == "phase2_dynamic_broad_repair" ]]; then
  run_phase "phase2_dynamic_broad_repair" "$MAX_REFINE"
fi

echo "[dynamic-restored-closure] final evaluate"
Rscript "$OUT_DIR/LOCAL_original288_syncedbase_dynamic_restored_closure_evaluate_20260410.R" --manifest="$MANIFEST" --tag="$TAG"
echo "[dynamic-restored-closure] done"

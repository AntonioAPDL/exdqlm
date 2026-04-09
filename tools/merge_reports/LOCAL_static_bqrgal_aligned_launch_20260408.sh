#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$REPO_ROOT"

OUT_DIR="$REPO_ROOT/tools/merge_reports"
TAG="static_bqrgal_aligned_20260408"
MANIFEST="$OUT_DIR/LOCAL_static_bqrgal_aligned_manifest_20260408.csv"
PHASE="all"
FORCE="0"
PREPARE_ONLY="0"
DRY_RUN="0"
SKIP_PREPARE="0"
MAX_PARALLEL=""

for arg in "$@"; do
  case "$arg" in
    --tag=*) TAG="${arg#*=}" ;;
    --manifest=*) MANIFEST="${arg#*=}" ;;
    --phase=*) PHASE="${arg#*=}" ;;
    --force=*) FORCE="${arg#*=}" ;;
    --prepare-only=*) PREPARE_ONLY="${arg#*=}" ;;
    --dry-run=*) DRY_RUN="${arg#*=}" ;;
    --skip-prepare=*) SKIP_PREPARE="${arg#*=}" ;;
    --max-parallel=*) MAX_PARALLEL="${arg#*=}" ;;
    *) echo "Unknown arg: $arg" >&2; exit 1 ;;
  esac
done

NPROC="$(nproc)"
if [[ -z "$MAX_PARALLEL" ]]; then
  if [[ "$NPROC" -ge 32 ]]; then
    MAX_PARALLEL="8"
  elif [[ "$NPROC" -ge 16 ]]; then
    MAX_PARALLEL="6"
  elif [[ "$NPROC" -ge 8 ]]; then
    MAX_PARALLEL="4"
  else
    MAX_PARALLEL="2"
  fi
fi

RUN_DIR="$OUT_DIR/${TAG}"
LOG_DIR="$RUN_DIR/logs"

echo "[static-bqrgal-aligned] repo_root=$REPO_ROOT"
echo "[static-bqrgal-aligned] tag=$TAG"
echo "[static-bqrgal-aligned] manifest=$MANIFEST"
echo "[static-bqrgal-aligned] phase=$PHASE"
echo "[static-bqrgal-aligned] max_parallel=$MAX_PARALLEL force=$FORCE"

if [[ "$SKIP_PREPARE" != "1" ]]; then
  echo "[static-bqrgal-aligned] prepare benchmark"
  Rscript "$OUT_DIR/LOCAL_static_bqrgal_aligned_prepare_20260408.R"
else
  echo "[static-bqrgal-aligned] skip prepare requested"
fi

mkdir -p "$LOG_DIR"

echo "[static-bqrgal-aligned] prelaunch evaluate"
Rscript "$OUT_DIR/LOCAL_static_bqrgal_aligned_evaluate_20260408.R" --manifest="$MANIFEST"

if [[ "$PREPARE_ONLY" == "1" ]]; then
  echo "[static-bqrgal-aligned] prepare-only complete"
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
    echo "[static-bqrgal-aligned] no rows for $phase_name"
    return 0
  fi

  echo "[static-bqrgal-aligned] launching $phase_name with max_parallel=$max_parallel"
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
      Rscript tools/merge_reports/LOCAL_static_bqrgal_aligned_run_row_20260408.R --manifest="$manifest" --row_id="$id" --tag="$tag" --force="$force" > "$log" 2>&1
    ' _ {} "$REPO_ROOT" "$MANIFEST" "$TAG" "$FORCE" "$LOG_DIR" "$phase_name"
    local phase_rc=$?
    set -e
    echo "[static-bqrgal-aligned] $phase_name xargs exit_code=$phase_rc"
  fi

  Rscript "$OUT_DIR/LOCAL_static_bqrgal_aligned_evaluate_20260408.R" --manifest="$MANIFEST"
}

if [[ "$PHASE" == "all" || "$PHASE" == "phase1_paper_matched_core" ]]; then
  run_phase "phase1_paper_matched_core" "$MAX_PARALLEL"
fi

if [[ "$PHASE" == "all" || "$PHASE" == "phase2_extension_n1000" ]]; then
  run_phase "phase2_extension_n1000" "$MAX_PARALLEL"
fi

echo "[static-bqrgal-aligned] final evaluate"
Rscript "$OUT_DIR/LOCAL_static_bqrgal_aligned_evaluate_20260408.R" --manifest="$MANIFEST"
echo "[static-bqrgal-aligned] done"

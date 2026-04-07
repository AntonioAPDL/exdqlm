#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$REPO_ROOT"

OUT_DIR="$REPO_ROOT/tools/merge_reports"
TAG="original288_syncedbase_residual_repair_20260407"
MANIFEST="$OUT_DIR/LOCAL_original288_syncedbase_residual_manifest_20260407.csv"
PHASE="all"
MAX_STATIC_AL=""
MAX_STATIC_EXAL=""
MAX_DYNAMIC=""
FORCE="0"
PREPARE_ONLY="0"
DRY_RUN="0"
SKIP_PREPARE="0"

for arg in "$@"; do
  case "$arg" in
    --tag=*) TAG="${arg#*=}" ;;
    --manifest=*) MANIFEST="${arg#*=}" ;;
    --phase=*) PHASE="${arg#*=}" ;;
    --max-static-al=*) MAX_STATIC_AL="${arg#*=}" ;;
    --max-static-exal=*) MAX_STATIC_EXAL="${arg#*=}" ;;
    --max-dynamic=*) MAX_DYNAMIC="${arg#*=}" ;;
    --force=*) FORCE="${arg#*=}" ;;
    --prepare-only=*) PREPARE_ONLY="${arg#*=}" ;;
    --dry-run=*) DRY_RUN="${arg#*=}" ;;
    --skip-prepare=*) SKIP_PREPARE="${arg#*=}" ;;
    *) echo "Unknown arg: $arg" >&2; exit 1 ;;
  esac
done

NPROC="$(nproc)"
if [[ -z "$MAX_STATIC_AL" ]]; then
  MAX_STATIC_AL="$(( NPROC > 12 ? 12 : (NPROC > 2 ? NPROC-2 : 1) ))"
fi
if [[ -z "$MAX_STATIC_EXAL" ]]; then
  MAX_STATIC_EXAL="$(( NPROC > 10 ? 10 : (NPROC > 2 ? NPROC-2 : 1) ))"
fi
if [[ -z "$MAX_DYNAMIC" ]]; then
  MAX_DYNAMIC="$(( NPROC > 4 ? 4 : (NPROC > 1 ? NPROC-1 : 1) ))"
fi

RUN_DIR="$OUT_DIR/full288_${TAG}"
LOG_DIR="$RUN_DIR/logs"

echo "[residual-repair] repo_root=$REPO_ROOT"
echo "[residual-repair] tag=$TAG"
echo "[residual-repair] manifest=$MANIFEST"
echo "[residual-repair] phase=$PHASE"
echo "[residual-repair] max_static_al=$MAX_STATIC_AL max_static_exal=$MAX_STATIC_EXAL max_dynamic=$MAX_DYNAMIC force=$FORCE"

if [[ "$SKIP_PREPARE" != "1" ]]; then
  echo "[residual-repair] prepare manifest"
  Rscript "$OUT_DIR/LOCAL_original288_syncedbase_residual_repair_prepare_20260407.R"
else
  echo "[residual-repair] skip prepare requested"
fi

mkdir -p "$LOG_DIR"

echo "[residual-repair] prelaunch evaluate"
Rscript "$OUT_DIR/LOCAL_original288_syncedbase_residual_repair_evaluate_20260407.R" --manifest="$MANIFEST" --tag="$TAG"

if [[ "$PREPARE_ONLY" == "1" ]]; then
  echo "[residual-repair] prepare-only complete"
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
    echo "[residual-repair] no rows for $phase_name"
    return 0
  fi

  echo "[residual-repair] launching $phase_name with max_parallel=$max_parallel"
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
    echo "[residual-repair] $phase_name xargs exit_code=$phase_rc"
  fi

  Rscript "$OUT_DIR/LOCAL_original288_syncedbase_residual_repair_evaluate_20260407.R" --manifest="$MANIFEST" --tag="$TAG"

  if [[ "$DRY_RUN" != "1" ]]; then
    Rscript -e "s<-read.csv('$OUT_DIR/LOCAL_original288_syncedbase_residual_manifest_status_20260407.csv', stringsAsFactors=FALSE); d<-s[s\$phase=='$phase_name', , drop=FALSE]; if (sum(d\$gate_current=='MISSING') > 0L) { quit(save='no', status=1) }"
  fi
}

if [[ "$PHASE" == "all" || "$PHASE" == "phase1_static_al_mcmc_bugfix" ]]; then
  run_phase "phase1_static_al_mcmc_bugfix" "$MAX_STATIC_AL"
fi
if [[ "$PHASE" == "all" || "$PHASE" == "phase2_static_exal_mcmc_exact" ]]; then
  run_phase "phase2_static_exal_mcmc_exact" "$MAX_STATIC_EXAL"
fi
if [[ "$PHASE" == "all" || "$PHASE" == "phase3_dynamic_exdqlm_mcmc_exact" ]]; then
  run_phase "phase3_dynamic_exdqlm_mcmc_exact" "$MAX_DYNAMIC"
fi

echo "[residual-repair] final evaluate"
Rscript "$OUT_DIR/LOCAL_original288_syncedbase_residual_repair_evaluate_20260407.R" --manifest="$MANIFEST" --tag="$TAG"
echo "[residual-repair] done"

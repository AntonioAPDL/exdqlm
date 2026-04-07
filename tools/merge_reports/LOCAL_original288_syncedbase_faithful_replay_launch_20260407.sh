#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$REPO_ROOT"

OUT_DIR="$REPO_ROOT/tools/merge_reports"
TAG="original288_syncedbase_faithful_replay_20260407"
MANIFEST="$OUT_DIR/LOCAL_original288_syncedbase_faithful_replay_manifest_20260407.csv"
PHASE="all"
MAX_VB=""
MAX_STATIC_PAPER_MCMC=""
MAX_STATIC_SHRINK_RIDGE_MCMC=""
MAX_STATIC_SHRINK_RHSNS_MCMC=""
MAX_DYNAMIC_MCMC=""
FORCE="0"
PREPARE_ONLY="0"
DRY_RUN="0"
SKIP_PREPARE="0"

for arg in "$@"; do
  case "$arg" in
    --tag=*) TAG="${arg#*=}" ;;
    --manifest=*) MANIFEST="${arg#*=}" ;;
    --phase=*) PHASE="${arg#*=}" ;;
    --max-vb=*) MAX_VB="${arg#*=}" ;;
    --max-static-paper-mcmc=*) MAX_STATIC_PAPER_MCMC="${arg#*=}" ;;
    --max-static-shrink-ridge-mcmc=*) MAX_STATIC_SHRINK_RIDGE_MCMC="${arg#*=}" ;;
    --max-static-shrink-rhsns-mcmc=*) MAX_STATIC_SHRINK_RHSNS_MCMC="${arg#*=}" ;;
    --max-dynamic-mcmc=*) MAX_DYNAMIC_MCMC="${arg#*=}" ;;
    --force=*) FORCE="${arg#*=}" ;;
    --prepare-only=*) PREPARE_ONLY="${arg#*=}" ;;
    --dry-run=*) DRY_RUN="${arg#*=}" ;;
    --skip-prepare=*) SKIP_PREPARE="${arg#*=}" ;;
    *) echo "Unknown arg: $arg" >&2; exit 1 ;;
  esac
done

NPROC="$(nproc)"
if [[ -z "$MAX_VB" ]]; then
  MAX_VB="$(( NPROC > 24 ? 24 : (NPROC > 2 ? NPROC-2 : 1) ))"
fi
if [[ -z "$MAX_STATIC_PAPER_MCMC" ]]; then
  MAX_STATIC_PAPER_MCMC="$(( NPROC > 8 ? 8 : (NPROC > 2 ? NPROC-2 : 1) ))"
fi
if [[ -z "$MAX_STATIC_SHRINK_RIDGE_MCMC" ]]; then
  MAX_STATIC_SHRINK_RIDGE_MCMC="$(( NPROC > 8 ? 8 : (NPROC > 2 ? NPROC-2 : 1) ))"
fi
if [[ -z "$MAX_STATIC_SHRINK_RHSNS_MCMC" ]]; then
  MAX_STATIC_SHRINK_RHSNS_MCMC="$(( NPROC > 8 ? 8 : (NPROC > 2 ? NPROC-2 : 1) ))"
fi
if [[ -z "$MAX_DYNAMIC_MCMC" ]]; then
  MAX_DYNAMIC_MCMC="$(( NPROC > 8 ? 8 : (NPROC > 2 ? NPROC-2 : 1) ))"
fi

RUN_DIR="$OUT_DIR/full288_${TAG}"
LOG_DIR="$RUN_DIR/logs"
mkdir -p "$LOG_DIR"

echo "[faithful-replay] repo_root=$REPO_ROOT"
echo "[faithful-replay] tag=$TAG"
echo "[faithful-replay] manifest=$MANIFEST"
echo "[faithful-replay] phase=$PHASE"
echo "[faithful-replay] max_vb=$MAX_VB max_static_paper_mcmc=$MAX_STATIC_PAPER_MCMC max_static_shrink_ridge_mcmc=$MAX_STATIC_SHRINK_RIDGE_MCMC max_static_shrink_rhsns_mcmc=$MAX_STATIC_SHRINK_RHSNS_MCMC max_dynamic_mcmc=$MAX_DYNAMIC_MCMC force=$FORCE"

if [[ "$SKIP_PREPARE" != "1" ]]; then
  echo "[faithful-replay] prepare manifest"
  Rscript "$OUT_DIR/LOCAL_original288_syncedbase_faithful_replay_prepare_20260407.R"
else
  echo "[faithful-replay] skip prepare requested"
fi

echo "[faithful-replay] prelaunch evaluate"
Rscript "$OUT_DIR/LOCAL_original288_syncedbase_faithful_replay_evaluate_20260407.R" --manifest="$MANIFEST" --tag="$TAG"

if [[ "$PREPARE_ONLY" == "1" ]]; then
  echo "[faithful-replay] prepare-only complete"
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
    echo "[faithful-replay] no rows for $phase_name"
    return 0
  fi

  echo "[faithful-replay] launching $phase_name with max_parallel=$max_parallel"
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
    echo "[faithful-replay] $phase_name xargs exit_code=$phase_rc"
  fi

  Rscript "$OUT_DIR/LOCAL_original288_syncedbase_faithful_replay_evaluate_20260407.R" --manifest="$MANIFEST" --tag="$TAG"

  if [[ "$DRY_RUN" != "1" ]]; then
    Rscript -e "s<-read.csv('$OUT_DIR/LOCAL_original288_syncedbase_faithful_replay_manifest_status_20260407.csv', stringsAsFactors=FALSE); d<-s[s\$phase=='$phase_name', , drop=FALSE]; if (sum(d\$gate_current=='MISSING') > 0L) { quit(save='no', status=1) }"
  fi
}

if [[ "$PHASE" == "all" || "$PHASE" == "phase1_vb_all" ]]; then
  run_phase "phase1_vb_all" "$MAX_VB"
fi
if [[ "$PHASE" == "all" || "$PHASE" == "phase2_static_paper_mcmc" ]]; then
  run_phase "phase2_static_paper_mcmc" "$MAX_STATIC_PAPER_MCMC"
fi
if [[ "$PHASE" == "all" || "$PHASE" == "phase3_static_shrink_ridge_mcmc" ]]; then
  run_phase "phase3_static_shrink_ridge_mcmc" "$MAX_STATIC_SHRINK_RIDGE_MCMC"
fi
if [[ "$PHASE" == "all" || "$PHASE" == "phase4_static_shrink_rhsns_mcmc" ]]; then
  run_phase "phase4_static_shrink_rhsns_mcmc" "$MAX_STATIC_SHRINK_RHSNS_MCMC"
fi
if [[ "$PHASE" == "all" || "$PHASE" == "phase5_dynamic_mcmc" ]]; then
  run_phase "phase5_dynamic_mcmc" "$MAX_DYNAMIC_MCMC"
fi

echo "[faithful-replay] final evaluate"
Rscript "$OUT_DIR/LOCAL_original288_syncedbase_faithful_replay_evaluate_20260407.R" --manifest="$MANIFEST" --tag="$TAG"
echo "[faithful-replay] done"

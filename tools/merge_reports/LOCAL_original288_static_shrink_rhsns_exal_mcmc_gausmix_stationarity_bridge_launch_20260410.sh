#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$REPO_ROOT"

OUT_DIR="$REPO_ROOT/tools/merge_reports"
TAG="original288_static_shrink_rhsns_exal_mcmc_gausmix_stationarity_bridge_20260410"
MANIFEST="$OUT_DIR/LOCAL_original288_static_shrink_rhsns_exal_mcmc_gausmix_stationarity_bridge_manifest_20260410.csv"
PHASE="all"
MAX_MCMC=""
FORCE="0"
PREPARE_ONLY="0"
DRY_RUN="0"
SKIP_PREPARE="0"

for arg in "$@"; do
  case "$arg" in
    --tag=*) TAG="${arg#*=}" ;;
    --manifest=*) MANIFEST="${arg#*=}" ;;
    --phase=*) PHASE="${arg#*=}" ;;
    --max-mcmc=*) MAX_MCMC="${arg#*=}" ;;
    --force=*) FORCE="${arg#*=}" ;;
    --prepare-only=*) PREPARE_ONLY="${arg#*=}" ;;
    --dry-run=*) DRY_RUN="${arg#*=}" ;;
    --skip-prepare=*) SKIP_PREPARE="${arg#*=}" ;;
    *) echo "Unknown arg: $arg" >&2; exit 1 ;;
  esac
done

if [[ -z "$MAX_MCMC" ]]; then
  MAX_MCMC="4"
fi

RUN_DIR="$OUT_DIR/full288_${TAG}"
LOG_DIR="$RUN_DIR/logs"

echo "[rhsns-exal-gausmix-stationarity-bridge] repo_root=$REPO_ROOT"
echo "[rhsns-exal-gausmix-stationarity-bridge] tag=$TAG"
echo "[rhsns-exal-gausmix-stationarity-bridge] manifest=$MANIFEST"
echo "[rhsns-exal-gausmix-stationarity-bridge] phase=$PHASE"
echo "[rhsns-exal-gausmix-stationarity-bridge] max_mcmc=$MAX_MCMC force=$FORCE"

if [[ "$SKIP_PREPARE" != "1" ]]; then
  echo "[rhsns-exal-gausmix-stationarity-bridge] prepare manifest"
  Rscript "$OUT_DIR/LOCAL_original288_static_shrink_rhsns_exal_mcmc_gausmix_stationarity_bridge_prepare_20260410.R"
else
  echo "[rhsns-exal-gausmix-stationarity-bridge] skip prepare requested"
fi

mkdir -p "$LOG_DIR"

echo "[rhsns-exal-gausmix-stationarity-bridge] prelaunch evaluate"
Rscript "$OUT_DIR/LOCAL_original288_static_shrink_rhsns_exal_mcmc_gausmix_stationarity_bridge_evaluate_20260410.R" --manifest="$MANIFEST" --tag="$TAG"

if [[ "$PREPARE_ONLY" == "1" ]]; then
  echo "[rhsns-exal-gausmix-stationarity-bridge] prepare-only complete"
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
    echo "[rhsns-exal-gausmix-stationarity-bridge] no rows for $phase_name"
    return 0
  fi

  echo "[rhsns-exal-gausmix-stationarity-bridge] launching $phase_name with max_parallel=$max_parallel"
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
      Rscript tools/merge_reports/LOCAL_original288_static_shrink_rhsns_exal_mcmc_repair_run_row_20260410.R --manifest="$manifest" --row_id="$id" --tag="$tag" --force="$force" > "$log" 2>&1
    ' _ {} "$REPO_ROOT" "$MANIFEST" "$TAG" "$FORCE" "$LOG_DIR" "$phase_name"
    local phase_rc=$?
    set -e
    echo "[rhsns-exal-gausmix-stationarity-bridge] $phase_name xargs exit_code=$phase_rc"
  fi

  Rscript "$OUT_DIR/LOCAL_original288_static_shrink_rhsns_exal_mcmc_gausmix_stationarity_bridge_evaluate_20260410.R" --manifest="$MANIFEST" --tag="$TAG"

  if [[ "$DRY_RUN" != "1" ]]; then
    Rscript -e "s<-read.csv('$OUT_DIR/LOCAL_original288_static_shrink_rhsns_exal_mcmc_gausmix_stationarity_bridge_manifest_status_20260410.csv', stringsAsFactors=FALSE); d<-s[s\$phase=='$phase_name', , drop=FALSE]; if (sum(d\$gate_current=='MISSING') > 0L) { quit(save='no', status=1) }"
  fi
}

for phase_name in \
  phase1_static_shrink_rhsns_exal_mcmc_gausmix_burn_bridge \
  phase2_static_shrink_rhsns_exal_mcmc_gausmix_vb_bridge \
  phase3_static_shrink_rhsns_exal_mcmc_gausmix_newkernels; do
  if [[ "$PHASE" == "all" || "$PHASE" == "$phase_name" ]]; then
    run_phase "$phase_name" "$MAX_MCMC"
  fi
done

echo "[rhsns-exal-gausmix-stationarity-bridge] final evaluate"
Rscript "$OUT_DIR/LOCAL_original288_static_shrink_rhsns_exal_mcmc_gausmix_stationarity_bridge_evaluate_20260410.R" --manifest="$MANIFEST" --tag="$TAG"
echo "[rhsns-exal-gausmix-stationarity-bridge] done"

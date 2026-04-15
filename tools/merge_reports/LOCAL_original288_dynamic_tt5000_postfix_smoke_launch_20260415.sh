#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$REPO_ROOT"

PREPARE_ONLY="0"
DRY_RUN="0"
SKIP_PREPARE="0"
FORCE="0"
MAX_PARALLEL="2"

for arg in "$@"; do
  case "$arg" in
    --prepare-only=*) PREPARE_ONLY="${arg#*=}" ;;
    --dry-run=*) DRY_RUN="${arg#*=}" ;;
    --skip-prepare=*) SKIP_PREPARE="${arg#*=}" ;;
    --force=*) FORCE="${arg#*=}" ;;
    --max-parallel=*) MAX_PARALLEL="${arg#*=}" ;;
    *) echo "Unknown arg: $arg" >&2; exit 1 ;;
  esac
done

PATHS_R='source("tools/merge_reports/LOCAL_original288_dynamic_tt5000_postfix_smoke_helpers_20260415.R"); x<-paths_original288_dynamic_tt5000_postfix_smoke(); cat(x$manifest,"\n",x$manifest_status,"\n",x$phase_summary,"\n",x$console_log,"\n",x$logs_dir,"\n", sep="")'
mapfile -t PATHS < <(Rscript -e "$PATHS_R")
MANIFEST="${PATHS[0]}"
STATUS_OUT="${PATHS[1]}"
PHASE_OUT="${PATHS[2]}"
CONSOLE_LOG="${PATHS[3]}"
LOG_DIR="${PATHS[4]}"

mkdir -p "$LOG_DIR"

evaluate_manifest() {
  Rscript tools/merge_reports/LOCAL_original288_dynamic_tt5000_exactspec_repair_evaluate_20260414.R \
    --manifest="$MANIFEST" \
    --status_out="$STATUS_OUT" \
    --phase_out="$PHASE_OUT"
}

echo "[dynamic-tt5000-postfix-smoke] repo_root=$REPO_ROOT" | tee "$CONSOLE_LOG"

if [[ "$SKIP_PREPARE" != "1" ]]; then
  echo "[dynamic-tt5000-postfix-smoke] prepare manifest" | tee -a "$CONSOLE_LOG"
  Rscript tools/merge_reports/LOCAL_original288_dynamic_tt5000_postfix_smoke_prepare_20260415.R | tee -a "$CONSOLE_LOG"
else
  echo "[dynamic-tt5000-postfix-smoke] skip prepare requested" | tee -a "$CONSOLE_LOG"
fi

evaluate_manifest | tee -a "$CONSOLE_LOG"

if [[ "$PREPARE_ONLY" == "1" ]]; then
  echo "[dynamic-tt5000-postfix-smoke] prepare-only complete" | tee -a "$CONSOLE_LOG"
  exit 0
fi

IDS_FILE="${LOG_DIR}/postfix_smoke_ids.txt"
Rscript -e "m<-read.csv('$MANIFEST', stringsAsFactors=FALSE); writeLines(as.character(m\$row_id), '$IDS_FILE')"

if [[ "$DRY_RUN" == "1" ]]; then
  echo "[dynamic-tt5000-postfix-smoke] dry-run row ids" | tee -a "$CONSOLE_LOG"
  cat "$IDS_FILE" | tee -a "$CONSOLE_LOG"
  exit 0
fi

set +e
xargs -a "$IDS_FILE" -P "$MAX_PARALLEL" -I{} bash -lc '
  id="$1"
  repo_root="$2"
  manifest="$3"
  force="$4"
  log_dir="$5"
  log="$log_dir/row_${id}.log"
  cd "$repo_root"
  Rscript tools/merge_reports/LOCAL_original288_dynamic_tt5000_exactspec_repair_run_row_20260414.R \
    --manifest="$manifest" \
    --row_id="$id" \
    --tag="original288_dynamic_tt5000_postfix_smoke_20260415" \
    --force="$force" > "$log" 2>&1
' _ {} "$REPO_ROOT" "$MANIFEST" "$FORCE" "$LOG_DIR"
rc=$?
set -e
echo "[dynamic-tt5000-postfix-smoke] xargs exit_code=$rc" | tee -a "$CONSOLE_LOG"

evaluate_manifest | tee -a "$CONSOLE_LOG"
echo "[dynamic-tt5000-postfix-smoke] done" | tee -a "$CONSOLE_LOG"

#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
out_dir="$repo_root/tools/merge_reports"

prepare_script="$out_dir/LOCAL_original288_dynamic_tail7_rw_prepare_20260406.R"
evaluate_script="$out_dir/LOCAL_original288_dynamic_tail7_rw_evaluate_20260406.R"
select_script="$out_dir/LOCAL_original288_dynamic_tail7_rw_select_20260406.R"
case_runner="$out_dir/LOCAL_full288_case_runner_20260327.R"
manifest_csv="$out_dir/LOCAL_original288_dynamic_tail7_rw_manifest_20260406.csv"
tag="original288_dynamic_tail7_rw_20260406"

mode="launch"
max_anchor="5"
max_short="4"
max_long="3"
dry_run="0"

for arg in "$@"; do
  case "$arg" in
    --mode=*) mode="${arg#*=}" ;;
    --max-anchor=*) max_anchor="${arg#*=}" ;;
    --max-short=*) max_short="${arg#*=}" ;;
    --max-long=*) max_long="${arg#*=}" ;;
    --dry-run) dry_run="1" ;;
    *) echo "Unknown arg: $arg" >&2; exit 1 ;;
  esac
done

if [[ ! -f "$prepare_script" || ! -f "$evaluate_script" || ! -f "$select_script" || ! -f "$case_runner" ]]; then
  echo "required script missing" >&2
  exit 2
fi

run_dir="$out_dir/full288_${tag}"
log_dir="$run_dir/logs"
tele_dir="$run_dir/telemetry"
id_dir="$run_dir/ids"
mkdir -p "$log_dir" "$tele_dir" "$id_dir"

phase_force() {
  case "$1" in
    anchor7_rw_joint) echo "1" ;;
    tt500_rw_refresh4) echo "1" ;;
    tt5000_rw_joint_long3) echo "1" ;;
    *) echo "1" ;;
  esac
}

phase_parallel() {
  case "$1" in
    anchor7_rw_joint) echo "$max_anchor" ;;
    tt500_rw_refresh4) echo "$max_short" ;;
    tt5000_rw_joint_long3) echo "$max_long" ;;
    *) echo "1" ;;
  esac
}

build_ids() {
  local phase="$1"
  local ids_path="$2"
  Rscript -e "m<-read.csv('$manifest_csv', stringsAsFactors=FALSE); m<-m[m\$phase=='$phase' & !m\$missing_inputs, , drop=FALSE]; writeLines(as.character(m\$row_id), '$ids_path')"
}

run_phase() {
  local phase="$1"
  local ids_path="$id_dir/${phase}_ids.txt"
  local force
  local parallel
  local rc
  local eval_out
  local summary_line
  local missing_now

  force="$(phase_force "$phase")"
  parallel="$(phase_parallel "$phase")"

  build_ids "$phase" "$ids_path"
  if [[ ! -s "$ids_path" ]]; then
    echo "[original288-dynamic-tail7-rw] phase=$phase has no runnable rows"
    return 0
  fi

  echo "[original288-dynamic-tail7-rw] phase=$phase parallel=$parallel force=$force"

  if [[ "$dry_run" == "1" ]]; then
    echo "[original288-dynamic-tail7-rw] dry-run ids for phase=$phase"
    cat "$ids_path"
    return 0
  fi

  set +e
  xargs -a "$ids_path" -P "$parallel" -I{} bash -lc '
    id="{}"
    log="'"$log_dir"'/row_${id}.log"
    tele="'"$tele_dir"'/row_${id}.csv"
    Rscript "'"$case_runner"'" \
      --manifest="'"$manifest_csv"'" \
      --row_id="$id" \
      --tag="'"$tag"'" \
      --force="'"$force"'" \
      --telemetry-path="$tele" > "$log" 2>&1
  '
  rc=$?
  set -e
  echo "[original288-dynamic-tail7-rw] phase=$phase xargs_exit=$rc"

  eval_out="$(Rscript "$evaluate_script" --phase="$phase" 2>&1)"
  echo "$eval_out"
  summary_line="$(echo "$eval_out" | awk '/^SUMMARY /{print; exit}')"
  missing_now="$(echo "$summary_line" | awk -F' ' '{for(i=1;i<=NF;i++){if($i ~ /^missing=/){sub("missing=","",$i); print $i; exit}}}')"
  if [[ "${missing_now:-1}" != "0" ]]; then
    echo "[original288-dynamic-tail7-rw] phase=$phase finished with missing rows=$missing_now" >&2
    return 1
  fi
  return 0
}

Rscript "$prepare_script"

if [[ "$mode" == "prepare" ]]; then
  exit 0
fi

if [[ "$mode" == "evaluate" ]]; then
  Rscript "$evaluate_script"
  exit 0
fi

if [[ "$mode" == "select" ]]; then
  Rscript "$select_script"
  exit 0
fi

run_phase anchor7_rw_joint
run_phase tt500_rw_refresh4
run_phase tt5000_rw_joint_long3

Rscript "$evaluate_script"
Rscript "$select_script"

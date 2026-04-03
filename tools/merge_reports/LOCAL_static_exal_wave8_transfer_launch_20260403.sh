#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
out_dir="$repo_root/tools/merge_reports"
prepare_script="$out_dir/LOCAL_static_exal_wave8_transfer_prepare_20260403.R"
score_script="$out_dir/LOCAL_static_exal_wave8_transfer_score_20260403.R"
runner="$out_dir/LOCAL_static_exal_case_runner_20260323.R"

mode="launch"
parallel_jobs="6"
force="0"
stage_filter=""
n_burn="1500"
n_mcmc="5000"
thin="1"
trace_every="50"
progress_every="50"
mh_proposal="laplace_rw"
mh_adapt="true"
slice_width="0.12"
slice_max_steps="80"
init_mode="baseline_last"

for arg in "$@"; do
  case "$arg" in
    --mode=*) mode="${arg#*=}" ;;
    --parallel-jobs=*) parallel_jobs="${arg#*=}" ;;
    --force) force="1" ;;
    --stage=*) stage_filter="${arg#*=}" ;;
    --n-burn=*) n_burn="${arg#*=}" ;;
    --n-mcmc=*) n_mcmc="${arg#*=}" ;;
    --thin=*) thin="${arg#*=}" ;;
    --trace-every=*) trace_every="${arg#*=}" ;;
    --progress-every=*) progress_every="${arg#*=}" ;;
    --mh-proposal=*) mh_proposal="${arg#*=}" ;;
    --mh-adapt=*) mh_adapt="${arg#*=}" ;;
    --slice-width=*) slice_width="${arg#*=}" ;;
    --slice-max-steps=*) slice_max_steps="${arg#*=}" ;;
    --init-mode=*) init_mode="${arg#*=}" ;;
    *) ;;
  esac
done

if [[ "$mode" == "prepare" ]]; then
  Rscript "$prepare_script"
  exit 0
fi

schedule_csv="$out_dir/LOCAL_static_exal_wave8_transfer_schedule_20260403.csv"
config_csv="$out_dir/LOCAL_static_exal_wave8_transfer_config_20260403.csv"

if [[ ! -f "$schedule_csv" || ! -f "$config_csv" ]]; then
  Rscript "$prepare_script"
fi

if [[ "$mode" == "score" ]]; then
  if [[ -z "$stage_filter" ]]; then
    echo "score mode requires --stage=<transfer6|guard8|mix12_transfer>" >&2
    exit 2
  fi
  Rscript "$score_script" --stage="$stage_filter"
  exit 0
fi

if [[ ! -f "$runner" ]]; then
  echo "runner missing: $runner" >&2
  exit 2
fi

run_stage() {
  local stage="$1"
  local topk="${2:-0}"

  if [[ -n "$stage_filter" && "$stage_filter" != "$stage" ]]; then
    return 0
  fi

  local candidates_csv="$config_csv"
  if [[ "$stage" != "transfer6" ]]; then
    candidates_csv="$(ls -1t "$out_dir"/LOCAL_static_exal_wave8_"${prev_stage}"_topk_*.csv 2>/dev/null | head -n 1 || true)"
    if [[ -z "$candidates_csv" || ! -f "$candidates_csv" ]]; then
      echo "missing topk for ${prev_stage}; cannot proceed to ${stage}" >&2
      exit 2
    fi
  fi

  local rows_tsv
  rows_tsv="$(mktemp "/tmp/exdqlm_wave8_${stage}_rows_XXXX.tsv")"
  trap 'rm -f "$rows_tsv"' EXIT

  Rscript - "$schedule_csv" "$candidates_csv" "$stage" > "$rows_tsv" <<'RS'
args <- commandArgs(trailingOnly = TRUE)
schedule_csv <- args[[1]]
candidates_csv <- args[[2]]
stage <- args[[3]]

schedule <- read.csv(schedule_csv, stringsAsFactors = FALSE, check.names = FALSE)
cand <- read.csv(candidates_csv, stringsAsFactors = FALSE, check.names = FALSE)

if (!nrow(schedule)) quit(save = "no", status = 0)
if (!nrow(cand)) quit(save = "no", status = 0)

schedule <- schedule[schedule$stage == stage, , drop = FALSE]
if (!nrow(schedule)) quit(save = "no", status = 0)

schedule <- schedule[schedule$candidate_id %in% cand$candidate_id, , drop = FALSE]
if (!nrow(schedule)) quit(save = "no", status = 0)

for (i in seq_len(nrow(schedule))) {
  r <- schedule[i, , drop = FALSE]
  cat(paste(
    stage,
    r$row_id,
    r$run_root,
    r$root_kind,
    r$family,
    r$tt,
    r$tau_label,
    r$variant_tag,
    r$gamma_substeps,
    r$p_global_eta_jump,
    r$global_eta_jump_scale,
    r$seed,
    sep = "\t"
  ), "\n", sep = "")
}
RS

  if [[ ! -s "$rows_tsv" ]]; then
    echo "no rows found for stage ${stage}" >&2
    return 0
  fi

  local manifest="$out_dir/LOCAL_static_exal_wave8_${stage}_manifest_$(date '+%Y%m%d_%H%M%S')_${RANDOM}_$$.csv"
  echo "ts,stage,row_id,run_root,root_kind,family,tt,tau_label,variant_tag,gamma_substeps,p_global_eta_jump,global_eta_jump_scale,seed,log_path" > "$manifest"

  export runner out_dir n_burn n_mcmc thin trace_every progress_every mh_proposal mh_adapt slice_width slice_max_steps init_mode force

  run_one() {
    local stage="$1"
    local row_id="$2"
    local run_root="$3"
    local root_kind="$4"
    local family="$5"
    local tt="$6"
    local tau_label="$7"
    local variant_tag="$8"
    local gamma_substeps="$9"
    local p_global_eta_jump="${10}"
    local global_eta_jump_scale="${11}"
    local seed="${12}"

    local log_path="$out_dir/LOCAL_static_exal_wave8_${stage}_${variant_tag}_row${row_id}.log"
    local cmd=(Rscript "$runner"
      --queue_id="${row_id}"
      --priority_label="${stage}"
      --family_scope="${root_kind}"
      --model="exal"
      --family="${family}"
      --tt="${tt}"
      --tau="${tau_label}"
      --run_root="${run_root}"
      --variant_tag="${variant_tag}"
      --seed="${seed}"
      --n_burn="${n_burn}"
      --n_mcmc="${n_mcmc}"
      --thin="${thin}"
      --trace_every="${trace_every}"
      --progress_every="${progress_every}"
      --mh_proposal="${mh_proposal}"
      --mh_adapt="${mh_adapt}"
      --slice_width="${slice_width}"
      --slice_max_steps="${slice_max_steps}"
      --gamma_substeps="${gamma_substeps}"
      --p_global_eta_jump="${p_global_eta_jump}"
      --global_eta_jump_scale="${global_eta_jump_scale}"
      --init_mode="${init_mode}"
    )
    if [[ "$force" == "1" ]]; then
      cmd+=(--force)
    fi

    OMP_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 MKL_NUM_THREADS=1 \
      VECLIB_MAXIMUM_THREADS=1 NUMEXPR_NUM_THREADS=1 \
      "${cmd[@]}" > "$log_path" 2>&1

    echo "$(date '+%Y-%m-%d %H:%M:%S'),${stage},${row_id},${run_root},${root_kind},${family},${tt},${tau_label},${variant_tag},${gamma_substeps},${p_global_eta_jump},${global_eta_jump_scale},${seed},${log_path}" >> "$manifest"
  }
  export -f run_one

  xargs -P "$parallel_jobs" -n 12 bash -c 'run_one "$@"' _ < "$rows_tsv"

  echo "manifest: $manifest"
  Rscript "$score_script" --stage="$stage" --top-k="$topk"
}

prev_stage=""
run_stage "transfer6" "4"
prev_stage="transfer6"
run_stage "guard8" "3"
prev_stage="guard8"
run_stage "mix12_transfer" "0"

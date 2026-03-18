#!/usr/bin/env bash
set -euo pipefail

repo_root="$(pwd)"
state_root="/home/jaguir26/local/state/exdqlm"
run_tag="$(date '+%Y%m%d_%H%M%S')"
poll_sec=20
jobs=8
tuning_env_rel="tools/merge_reports/20260318_family_qspec_vb_debug_tuning_tt5000_direct_commit.env"
unhealthy_targets_rel="tools/merge_reports/20260314_family_qspec_unhealthy_targets.tsv"
canary_root_id="root__dynamic__laplace__tau_0p05__lasttt_5000"
second_root_id="root__dynamic__gausmix__tau_0p05__lasttt_5000"
target_inference="vb"
target_model="exdqlm"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo-root)
      repo_root="$2"
      shift 2
      ;;
    --state-root)
      state_root="$2"
      shift 2
      ;;
    --run-tag)
      run_tag="$2"
      shift 2
      ;;
    --poll-sec)
      poll_sec="$2"
      shift 2
      ;;
    --jobs)
      jobs="$2"
      shift 2
      ;;
    --tuning-env)
      tuning_env_rel="$2"
      shift 2
      ;;
    --unhealthy-targets)
      unhealthy_targets_rel="$2"
      shift 2
      ;;
    --canary-root-id)
      canary_root_id="$2"
      shift 2
      ;;
    --second-root-id)
      second_root_id="$2"
      shift 2
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

repo_root="$(cd "$repo_root" && pwd)"
state_root="$(cd "$state_root" && pwd)"

resolve_path() {
  local path="$1"
  if [[ "$path" = /* ]]; then
    printf '%s\n' "$path"
  else
    printf '%s\n' "${repo_root}/${path}"
  fi
}

tuning_env_abs="$(resolve_path "$tuning_env_rel")"
unhealthy_targets_abs="$(resolve_path "$unhealthy_targets_rel")"

if [[ ! -f "$tuning_env_abs" ]]; then
  echo "Missing tuning env: $tuning_env_abs" >&2
  exit 1
fi
if [[ ! -f "$unhealthy_targets_abs" ]]; then
  echo "Missing unhealthy targets TSV: $unhealthy_targets_abs" >&2
  exit 1
fi

wave_dir="${state_root}/family_qspec_vb_debug_residual_${run_tag}"
canary_state_dir="${wave_dir}/state_canary"
second_state_dir="${wave_dir}/state_second"
mkdir -p "$wave_dir" "$canary_state_dir" "$second_state_dir"

log_file="${wave_dir}/orchestrator.log"
status_tsv="${wave_dir}/status.tsv"
summary_md="${wave_dir}/summary.md"

echo -e "timestamp\tphase\tstatus\tnote" > "$status_tsv"

log() {
  local line
  line="$(date '+%Y-%m-%d %H:%M:%S') | $*"
  echo "$line" | tee -a "$log_file"
}

mark() {
  local phase="$1"
  local status="$2"
  local note="$3"
  printf '%s\t%s\t%s\t%s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$phase" "$status" "$note" >> "$status_tsv"
}

copy_tree() {
  local src="$1"
  local dst="$2"
  mkdir -p "$dst"
  if command -v rsync >/dev/null 2>&1; then
    rsync -a --delete "${src}/" "${dst}/"
  else
    rm -rf "$dst"
    mkdir -p "$dst"
    cp -a "${src}/." "$dst/"
  fi
}

build_target_file() {
  local out_tsv="$1"
  local root_id="$2"
  Rscript -e '
args <- commandArgs(trailingOnly = TRUE)
in_path <- args[[1L]]
out_path <- args[[2L]]
root_id <- args[[3L]]
inference <- args[[4L]]
model <- args[[5L]]
df <- read.delim(in_path, sep = "\t", stringsAsFactors = FALSE, check.names = FALSE)
sub <- df[df$root_id == root_id & df$inference == inference & df$model == model, , drop = FALSE]
if (!nrow(sub)) stop(sprintf("No rows for root_id=%s inference=%s model=%s", root_id, inference, model), call. = FALSE)
write.table(sub, out_path, sep = "\t", row.names = FALSE, quote = FALSE)
' "$unhealthy_targets_abs" "$out_tsv" "$root_id" "$target_inference" "$target_model"
}

extract_target_run_root() {
  local targets_tsv="$1"
  Rscript -e '
args <- commandArgs(trailingOnly = TRUE)
path <- args[[1L]]
df <- read.delim(path, sep = "\t", stringsAsFactors = FALSE, check.names = FALSE)
if (!("run_root" %in% names(df))) stop("Target TSV missing run_root column", call. = FALSE)
if (!nrow(df)) stop("Target TSV has zero rows", call. = FALSE)
val <- as.character(df$run_root[[1L]])
if (!nzchar(val) || identical(val, "NA")) stop("run_root is empty/NA in target TSV", call. = FALSE)
cat(val)
' "$targets_tsv"
}

snapshot_run_root() {
  local run_root_rel="$1"
  local label="$2"
  local run_root_abs="${repo_root}/${run_root_rel}"
  local snapshot_dir="${wave_dir}/baseline/run_root_snapshots/${label}"
  if [[ ! -d "$run_root_abs" ]]; then
    log "snapshot ${label}: missing run_root ${run_root_abs}"
    return 1
  fi
  copy_tree "$run_root_abs" "$snapshot_dir"
  log "snapshot ${label}: ${run_root_abs} -> ${snapshot_dir}"
}

restore_run_root() {
  local run_root_rel="$1"
  local label="$2"
  local run_root_abs="${repo_root}/${run_root_rel}"
  local snapshot_dir="${wave_dir}/baseline/run_root_snapshots/${label}"
  if [[ ! -d "$snapshot_dir" ]]; then
    log "restore ${label}: missing snapshot ${snapshot_dir}"
    return 1
  fi
  mkdir -p "$run_root_abs"
  copy_tree "$snapshot_dir" "$run_root_abs"
  log "restore ${label}: ${snapshot_dir} -> ${run_root_abs}"
}

rebuild_signoff() {
  log "rebuild_signoff: start"
  (
    cd "$repo_root"
    # shellcheck disable=SC1091
    source tools/merge_reports/20260315_family_qspec_signoff_policy_second_wave.env
    EXDQLM_FQSG_REBUILD_JOBS="$jobs" \
      Rscript tools/merge_reports/20260314_build_family_qspec_signoff_views.R "$repo_root" --force
    Rscript tools/merge_reports/20260314_build_family_qspec_scientific_snapshot.R "$repo_root"
    Rscript tools/merge_reports/20260315_analyze_family_qspec_post_repair_delta.R "$repo_root"
  )
  log "rebuild_signoff: done"
}

signoff_grade_for() {
  local root_id="$1"
  Rscript -e '
args <- commandArgs(trailingOnly = TRUE)
path <- args[[1L]]
root_id <- args[[2L]]
inference <- args[[3L]]
model <- args[[4L]]
df <- read.delim(path, sep = "\t", stringsAsFactors = FALSE, check.names = FALSE)
sub <- df[df$root_id == root_id & df$inference == inference & df$model == model, , drop = FALSE]
if (!nrow(sub)) stop("Target row missing in method signoff.", call. = FALSE)
cat(sub$signoff_grade[[1L]], "\t", sub$signoff_reason[[1L]], "\t", sub$comparison_eligible[[1L]], "\n", sep = "")
' "${repo_root}/tools/merge_reports/20260314_family_qspec_method_signoff.tsv" "$root_id" "$target_inference" "$target_model"
}

evaluate_no_regression() {
  local root_id="$1"
  local model="$2"
  local baseline_file="$3"
  local current_file="$4"
  Rscript -e '
args <- commandArgs(trailingOnly = TRUE)
root_id <- args[[1L]]
model <- args[[2L]]
baseline_file <- args[[3L]]
current_file <- args[[4L]]
grade_rank <- function(x) {
  x <- as.character(x)
  if (identical(x, "PASS")) return(3L)
  if (identical(x, "WARN")) return(2L)
  if (identical(x, "FAIL")) return(1L)
  0L
}
b <- read.delim(baseline_file, sep = "\t", stringsAsFactors = FALSE, check.names = FALSE)
c <- read.delim(current_file, sep = "\t", stringsAsFactors = FALSE, check.names = FALSE)
b <- b[b$root_id == root_id & b$model == model, , drop = FALSE]
c <- c[c$root_id == root_id & c$model == model, , drop = FALSE]
if (!nrow(b)) {
  cat("FALSE\tno_baseline_rows\n", sep = "")
  quit(save = "no", status = 0)
}
regressed <- FALSE
details <- character(0)
for (inf in unique(as.character(b$inference))) {
  br <- b[b$inference == inf, , drop = FALSE]
  cr <- c[c$inference == inf, , drop = FALSE]
  if (!nrow(cr)) {
    regressed <- TRUE
    details <- c(details, sprintf("%s missing_current_row", inf))
    next
  }
  b_grade <- as.character(br$signoff_grade[[1L]])
  c_grade <- as.character(cr$signoff_grade[[1L]])
  b_elig <- isTRUE(as.logical(br$comparison_eligible[[1L]]))
  c_elig <- isTRUE(as.logical(cr$comparison_eligible[[1L]]))
  if (grade_rank(c_grade) < grade_rank(b_grade)) {
    regressed <- TRUE
    details <- c(details, sprintf("%s grade %s->%s", inf, b_grade, c_grade))
  }
  if (b_elig && !c_elig) {
    regressed <- TRUE
    details <- c(details, sprintf("%s eligible TRUE->FALSE", inf))
  }
}
if (!length(details)) details <- "no_regression_detected"
cat(ifelse(regressed, "TRUE", "FALSE"), "\t", paste(details, collapse = " | "), "\n", sep = "")
' "$root_id" "$model" "$baseline_file" "$current_file"
}

evaluate_vb_tail_progress() {
  local root_id="$1"
  local model="$2"
  local baseline_file="$3"
  local current_file="$4"
  Rscript -e '
args <- commandArgs(trailingOnly = TRUE)
root_id <- args[[1L]]
model <- args[[2L]]
baseline_file <- args[[3L]]
current_file <- args[[4L]]
grade_rank <- function(x) {
  x <- as.character(x)
  if (identical(x, "PASS")) return(3L)
  if (identical(x, "WARN")) return(2L)
  if (identical(x, "FAIL")) return(1L)
  0L
}
core_tail <- function(row) {
  vals <- suppressWarnings(as.numeric(c(
    row$vb_sigma_tail_rel_range[[1L]],
    row$vb_gamma_tail_rel_range[[1L]],
    row$vb_s_tail_rel_range[[1L]]
  )))
  vals <- vals[is.finite(vals)]
  if (!length(vals)) return(NA_real_)
  max(vals)
}
leq <- function(cur, base) {
  if (!is.finite(base)) return(is.finite(cur))
  if (!is.finite(cur)) return(FALSE)
  cur <= base
}
strict_lt <- function(cur, base) {
  if (!is.finite(base) || !is.finite(cur)) return(FALSE)
  cur < (base - 1e-12)
}
b <- read.delim(baseline_file, sep = "\t", stringsAsFactors = FALSE, check.names = FALSE)
c <- read.delim(current_file, sep = "\t", stringsAsFactors = FALSE, check.names = FALSE)
b <- b[b$root_id == root_id & b$model == model & b$inference == "vb", , drop = FALSE]
c <- c[c$root_id == root_id & c$model == model & c$inference == "vb", , drop = FALSE]
if (!nrow(b) || !nrow(c)) {
  cat("FALSE\tmissing_vb_row\n", sep = "")
  quit(save = "no", status = 0)
}
b <- b[1L, , drop = FALSE]
c <- c[1L, , drop = FALSE]
cur_warn_or_better <- grade_rank(c$signoff_grade[[1L]]) >= 2L
base_core <- core_tail(b)
cur_core <- core_tail(c)
base_state <- suppressWarnings(as.numeric(b$vb_delta_state_last[[1L]]))
cur_state <- suppressWarnings(as.numeric(c$vb_delta_state_last[[1L]]))
core_ok <- leq(cur_core, base_core)
state_ok <- leq(cur_state, base_state)
improved <- core_ok && state_ok && (strict_lt(cur_core, base_core) || strict_lt(cur_state, base_state))
pass <- isTRUE(cur_warn_or_better) && isTRUE(improved)
detail <- sprintf(
  "current_grade=%s base_core=%s cur_core=%s base_delta_state=%s cur_delta_state=%s cur_warn_or_better=%s improved=%s",
  as.character(c$signoff_grade[[1L]]),
  format(base_core, scientific = TRUE),
  format(cur_core, scientific = TRUE),
  format(base_state, scientific = TRUE),
  format(cur_state, scientific = TRUE),
  ifelse(cur_warn_or_better, "TRUE", "FALSE"),
  ifelse(improved, "TRUE", "FALSE")
)
cat(ifelse(pass, "TRUE", "FALSE"), "\t", detail, "\n", sep = "")
' "$root_id" "$model" "$baseline_file" "$current_file"
}

launch_wave() {
  local phase="$1"
  local targets_tsv="$2"
  local phase_state_dir="$3"
  local queue_prefix="$4"
  log "${phase}: launch start"
  mark "$phase" "RUNNING" "state_dir=${phase_state_dir}"
  (
    cd "$repo_root"
    tools/merge_reports/20260317_family_qspec_vb_debug_supervisor.sh \
      --repo-root "$repo_root" \
      --state-dir "$phase_state_dir" \
      --targets-tsv "$targets_tsv" \
      --queue-prefix "$queue_prefix" \
      --tuning-env "$tuning_env_abs" \
      --slot-budget 1 \
      --poll-sec "$poll_sec" \
      --launch
  ) | tee -a "$log_file"
  mark "$phase" "DONE" "state_dir=${phase_state_dir}"
  log "${phase}: launch done"
}

write_blocked_summary() {
  local block_phase="$1"
  local block_reason="$2"
  local canary_grade="$3"
  local canary_eligible="$4"
  local canary_reason="$5"
  local canary_regressed="$6"
  local canary_regression_detail="$7"
  local canary_vb_ok="$8"
  local canary_vb_detail="$9"
  {
    echo "# VB Debug Residual Wave Summary"
    echo
    echo "- wave_dir: \`${wave_dir}\`"
    echo "- tuning_env: \`${tuning_env_abs}\`"
    echo "- canary_root: \`${canary_root_id}\`"
    echo "- canary_grade: \`${canary_grade}\`"
    echo "- canary_comparison_eligible: \`${canary_eligible}\`"
    echo "- canary_reason: \`${canary_reason}\`"
    echo "- canary_no_regression: \`$([[ \"${canary_regressed}\" == \"TRUE\" ]] && echo FALSE || echo TRUE)\`"
    echo "- canary_no_regression_detail: \`${canary_regression_detail}\`"
    echo "- canary_vb_warn_plus_and_tail_improved: \`${canary_vb_ok}\`"
    echo "- canary_vb_quality_detail: \`${canary_vb_detail}\`"
    echo "- stop_phase: \`${block_phase}\`"
    echo "- stop_reason: \`${block_reason}\`"
    echo "- second_stage: \`not_launched_due_to_canary_gate\`"
  } > "$summary_md"
}

baseline_dir="${wave_dir}/baseline"
mkdir -p "$baseline_dir"
cp -f "${repo_root}/tools/merge_reports/20260314_family_qspec_method_signoff.tsv" "${baseline_dir}/20260314_family_qspec_method_signoff.tsv"
cp -f "${repo_root}/tools/merge_reports/20260314_family_qspec_signoff_summary.tsv" "${baseline_dir}/20260314_family_qspec_signoff_summary.tsv"

baseline_method_file="${baseline_dir}/20260314_family_qspec_method_signoff.tsv"
current_method_file="${repo_root}/tools/merge_reports/20260314_family_qspec_method_signoff.tsv"

canary_targets_tsv="${wave_dir}/canary_targets.tsv"
second_targets_tsv="${wave_dir}/second_targets.tsv"
build_target_file "$canary_targets_tsv" "$canary_root_id"
build_target_file "$second_targets_tsv" "$second_root_id"

canary_run_root_rel="$(extract_target_run_root "$canary_targets_tsv")"
second_run_root_rel="$(extract_target_run_root "$second_targets_tsv")"

snapshot_run_root "$canary_run_root_rel" "canary_before"
snapshot_run_root "$second_run_root_rel" "second_before"

mark "setup" "DONE" "wave_dir=${wave_dir}"
log "setup: wave_dir=${wave_dir}"
log "setup: tuning_env=${tuning_env_abs}"
log "setup: canary_root=${canary_root_id} run_root=${canary_run_root_rel}"
log "setup: second_root=${second_root_id} run_root=${second_run_root_rel}"

launch_wave "canary" "$canary_targets_tsv" "$canary_state_dir" "20260317_family_qspec_vb_residual_canary"
rebuild_signoff

canary_status="$(signoff_grade_for "$canary_root_id")"
canary_grade="$(printf '%s' "$canary_status" | awk -F'\t' '{print $1}')"
canary_reason="$(printf '%s' "$canary_status" | awk -F'\t' '{print $2}')"
canary_eligible="$(printf '%s' "$canary_status" | awk -F'\t' '{print $3}')"

canary_regression="$(evaluate_no_regression "$canary_root_id" "$target_model" "$baseline_method_file" "$current_method_file")"
canary_regressed="$(printf '%s' "$canary_regression" | awk -F'\t' '{print $1}')"
canary_regression_detail="$(printf '%s' "$canary_regression" | awk -F'\t' '{print $2}')"

canary_vb_eval="$(evaluate_vb_tail_progress "$canary_root_id" "$target_model" "$baseline_method_file" "$current_method_file")"
canary_vb_ok="$(printf '%s' "$canary_vb_eval" | awk -F'\t' '{print $1}')"
canary_vb_detail="$(printf '%s' "$canary_vb_eval" | awk -F'\t' '{print $2}')"

log "canary: signoff_grade=${canary_grade} comparison_eligible=${canary_eligible} reason=${canary_reason}"
log "canary: no_regression=$([[ "$canary_regressed" == "TRUE" ]] && echo FALSE || echo TRUE) detail=${canary_regression_detail}"
log "canary: vb_warn_plus_and_tail_improved=${canary_vb_ok} detail=${canary_vb_detail}"

if [[ "$canary_regressed" == "TRUE" ]]; then
  log "canary_gate: regression detected; restoring canary run_root snapshot"
  restore_run_root "$canary_run_root_rel" "canary_before"
  rebuild_signoff
  mark "canary_gate" "BLOCKED" "reason=regression_rollback"
  write_blocked_summary "canary_gate" "regression_rollback" "$canary_grade" "$canary_eligible" "$canary_reason" "$canary_regressed" "$canary_regression_detail" "$canary_vb_ok" "$canary_vb_detail"
  exit 2
fi

if [[ "$canary_vb_ok" != "TRUE" ]]; then
  log "canary_gate: VB quality gate failed; restoring canary run_root snapshot"
  restore_run_root "$canary_run_root_rel" "canary_before"
  rebuild_signoff
  mark "canary_gate" "BLOCKED" "reason=vb_quality_gate_rollback"
  write_blocked_summary "canary_gate" "vb_quality_gate_rollback" "$canary_grade" "$canary_eligible" "$canary_reason" "$canary_regressed" "$canary_regression_detail" "$canary_vb_ok" "$canary_vb_detail"
  exit 2
fi

if [[ "$canary_grade" == "FAIL" ]]; then
  log "canary_gate: signoff remained FAIL; restoring canary run_root snapshot"
  restore_run_root "$canary_run_root_rel" "canary_before"
  rebuild_signoff
  mark "canary_gate" "BLOCKED" "reason=signoff_fail_rollback"
  write_blocked_summary "canary_gate" "signoff_fail_rollback" "$canary_grade" "$canary_eligible" "$canary_reason" "$canary_regressed" "$canary_regression_detail" "$canary_vb_ok" "$canary_vb_detail"
  exit 2
fi

mark "canary_gate" "PASSED" "grade=${canary_grade}"

launch_wave "second" "$second_targets_tsv" "$second_state_dir" "20260317_family_qspec_vb_residual_second"
rebuild_signoff

second_status="$(signoff_grade_for "$second_root_id")"
second_grade="$(printf '%s' "$second_status" | awk -F'\t' '{print $1}')"
second_reason="$(printf '%s' "$second_status" | awk -F'\t' '{print $2}')"
second_eligible="$(printf '%s' "$second_status" | awk -F'\t' '{print $3}')"

second_regression="$(evaluate_no_regression "$second_root_id" "$target_model" "$baseline_method_file" "$current_method_file")"
second_regressed="$(printf '%s' "$second_regression" | awk -F'\t' '{print $1}')"
second_regression_detail="$(printf '%s' "$second_regression" | awk -F'\t' '{print $2}')"

second_vb_eval="$(evaluate_vb_tail_progress "$second_root_id" "$target_model" "$baseline_method_file" "$current_method_file")"
second_vb_ok="$(printf '%s' "$second_vb_eval" | awk -F'\t' '{print $1}')"
second_vb_detail="$(printf '%s' "$second_vb_eval" | awk -F'\t' '{print $2}')"

log "second: signoff_grade=${second_grade} comparison_eligible=${second_eligible} reason=${second_reason}"
log "second: no_regression=$([[ "$second_regressed" == "TRUE" ]] && echo FALSE || echo TRUE) detail=${second_regression_detail}"
log "second: vb_warn_plus_and_tail_improved=${second_vb_ok} detail=${second_vb_detail}"

if [[ "$second_regressed" == "TRUE" || "$second_vb_ok" != "TRUE" || "$second_grade" == "FAIL" ]]; then
  log "second_gate: failed policy gate; restoring second run_root snapshot"
  restore_run_root "$second_run_root_rel" "second_before"
  rebuild_signoff
  mark "second_gate" "BLOCKED" "reason=rollback_after_gate_fail"
  {
    echo "# VB Debug Residual Wave Summary"
    echo
    echo "- wave_dir: \`${wave_dir}\`"
    echo "- tuning_env: \`${tuning_env_abs}\`"
    echo "- canary_root: \`${canary_root_id}\`"
    echo "- canary_grade: \`${canary_grade}\`"
    echo "- canary_comparison_eligible: \`${canary_eligible}\`"
    echo "- canary_reason: \`${canary_reason}\`"
    echo "- canary_no_regression: \`$([[ \"${canary_regressed}\" == \"TRUE\" ]] && echo FALSE || echo TRUE)\`"
    echo "- canary_vb_warn_plus_and_tail_improved: \`${canary_vb_ok}\`"
    echo "- second_root: \`${second_root_id}\`"
    echo "- second_grade_before_rollback: \`${second_grade}\`"
    echo "- second_comparison_eligible_before_rollback: \`${second_eligible}\`"
    echo "- second_reason_before_rollback: \`${second_reason}\`"
    echo "- second_no_regression: \`$([[ \"${second_regressed}\" == \"TRUE\" ]] && echo FALSE || echo TRUE)\`"
    echo "- second_no_regression_detail: \`${second_regression_detail}\`"
    echo "- second_vb_warn_plus_and_tail_improved: \`${second_vb_ok}\`"
    echo "- second_vb_quality_detail: \`${second_vb_detail}\`"
    echo "- second_stage: \`rolled_back_due_to_gate_fail\`"
  } > "$summary_md"
  exit 2
fi

out_prefix="20260317_family_qspec_targeted_effect_residual_micro_wave_${run_tag}"
(
  cd "$repo_root"
  Rscript tools/merge_reports/20260317_analyze_family_qspec_targeted_effect.R \
    "$repo_root" \
    "${baseline_dir}/20260314_family_qspec_method_signoff.tsv" \
    "$out_prefix"
)

current_signoff_summary="${repo_root}/tools/merge_reports/20260314_family_qspec_signoff_summary.tsv"
current_fail="$(awk -F'\t' 'NR==1{for(i=1;i<=NF;i++)if($i=="method_fit_fail_count")c=i;next} NR==2{print $c}' "$current_signoff_summary")"
current_eligible="$(awk -F'\t' 'NR==1{for(i=1;i<=NF;i++)if($i=="method_fit_eligible_count")c=i;next} NR==2{print $c}' "$current_signoff_summary")"
current_unhealthy="$(awk -F'\t' 'NR==1{for(i=1;i<=NF;i++)if($i=="unhealthy_target_count")c=i;next} NR==2{print $c}' "$current_signoff_summary")"

{
  echo "# VB Debug Residual Wave Summary"
  echo
  echo "- wave_dir: \`${wave_dir}\`"
  echo "- tuning_env: \`${tuning_env_abs}\`"
  echo "- canary_root: \`${canary_root_id}\`"
  echo "- canary_grade: \`${canary_grade}\`"
  echo "- canary_comparison_eligible: \`${canary_eligible}\`"
  echo "- canary_reason: \`${canary_reason}\`"
  echo "- canary_no_regression: \`$([[ \"${canary_regressed}\" == \"TRUE\" ]] && echo FALSE || echo TRUE)\`"
  echo "- canary_no_regression_detail: \`${canary_regression_detail}\`"
  echo "- canary_vb_warn_plus_and_tail_improved: \`${canary_vb_ok}\`"
  echo "- canary_vb_quality_detail: \`${canary_vb_detail}\`"
  echo "- second_root: \`${second_root_id}\`"
  echo "- second_grade: \`${second_grade}\`"
  echo "- second_comparison_eligible: \`${second_eligible}\`"
  echo "- second_reason: \`${second_reason}\`"
  echo "- second_no_regression: \`$([[ \"${second_regressed}\" == \"TRUE\" ]] && echo FALSE || echo TRUE)\`"
  echo "- second_no_regression_detail: \`${second_regression_detail}\`"
  echo "- second_vb_warn_plus_and_tail_improved: \`${second_vb_ok}\`"
  echo "- second_vb_quality_detail: \`${second_vb_detail}\`"
  echo "- current_method_fail_count: \`${current_fail}\`"
  echo "- current_method_eligible_count: \`${current_eligible}\`"
  echo "- current_unhealthy_target_count: \`${current_unhealthy}\`"
  echo "- targeted_effect_prefix: \`${out_prefix}\`"
  echo "- targeted_effect_summary: \`tools/merge_reports/${out_prefix}_summary.tsv\`"
} > "$summary_md"

mark "complete" "DONE" "summary=${summary_md}"
log "complete: summary=${summary_md}"

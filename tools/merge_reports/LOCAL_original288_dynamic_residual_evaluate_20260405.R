#!/usr/bin/env Rscript

options(stringsAsFactors = FALSE)

source("tools/merge_reports/LOCAL_original288_dynamic_residual_helpers_20260405.R")

phase_filter <- ""
for (arg in commandArgs(trailingOnly = TRUE)) {
  if (grepl("^--phase=", arg)) {
    phase_filter <- sub("^--phase=", "", arg)
  }
}

paths <- paths_dynamic_residual_original288()
status <- read_dynamic_residual_status_original288()

if (!nrow(status)) {
  stop("dynamic residual manifest status is empty")
}

status$gate_overall[is.na(status$gate_overall) | !nzchar(status$gate_overall)] <- "MISSING"
status$gate_rank <- gate_rank_dynamic_residual_original288(status$gate_overall)
status$baseline_gate_rank <- gate_rank_dynamic_residual_original288(status$baseline_gate_overall)
status$candidate_preference_rank <- candidate_preference_rank_dynamic_residual_original288(status$phase)
status$done_flag <- status$state %in% c("done", "skipped_existing", "failed_runtime", "input_missing")
if (!("block" %in% names(status))) status$block <- status$root_kind
if (!("health_csv" %in% names(status))) status$health_csv <- NA_character_

status <- status[order(status$row_id), , drop = FALSE]
write.csv(status, paths$manifest_status, row.names = FALSE, na = "")

phase_summary <- do.call(rbind, lapply(split(status, status$phase), function(df) {
  data.frame(
    phase = df$phase[1],
    total = nrow(df),
    done = sum(df$gate_overall != "MISSING"),
    missing = sum(df$gate_overall == "MISSING"),
    PASS = sum(df$gate_overall == "PASS"),
    WARN = sum(df$gate_overall == "WARN"),
    FAIL = sum(df$gate_overall == "FAIL"),
    resolved = sum(df$gate_overall %in% c("PASS", "WARN")),
    stringsAsFactors = FALSE
  )
}))
phase_summary <- phase_summary[order(dynamic_residual_phase_order_original288[phase_summary$phase]), , drop = FALSE]
write.csv(phase_summary, paths$phase_summary, row.names = FALSE, na = "")

config_summary <- do.call(rbind, lapply(split(status, paste(status$phase, status$config_id, sep = "\r")), function(df) {
  data.frame(
    phase = df$phase[1],
    config_id = df$config_id[1],
    total = nrow(df),
    done = sum(df$gate_overall != "MISSING"),
    missing = sum(df$gate_overall == "MISSING"),
    PASS = sum(df$gate_overall == "PASS"),
    WARN = sum(df$gate_overall == "WARN"),
    FAIL = sum(df$gate_overall == "FAIL"),
    resolved = sum(df$gate_overall %in% c("PASS", "WARN")),
    stringsAsFactors = FALSE
  )
}))
config_summary <- config_summary[order(dynamic_residual_phase_order_original288[config_summary$phase], config_summary$config_id), , drop = FALSE]
write.csv(config_summary, paths$config_summary, row.names = FALSE, na = "")

case_best <- do.call(rbind, lapply(split(status, status$original_case_key), function(df) {
  ord <- order(
    -df$gate_rank,
    -df$candidate_preference_rank,
    df$runtime_sec,
    df$config_id,
    df$candidate_variant_tag
  )
  best <- df[ord[1], , drop = FALSE]
  data.frame(
    original_case_key = best$original_case_key,
    block = best$block,
    root_kind = best$root_kind,
    family = best$family,
    tau = best$tau_label,
    fit_size = best$fit_size,
    prior_semantics = best$prior,
    model = best$model,
    inference = best$inference,
    baseline_gate_overall = best$baseline_gate_overall,
    best_phase = best$phase,
    best_config_id = best$config_id,
    best_candidate_variant_tag = best$candidate_variant_tag,
    best_candidate_fit_path = best$candidate_fit_path,
    best_health_csv = if ("health_csv" %in% names(best)) best$health_csv else NA_character_,
    best_gate_overall = best$gate_overall,
    best_healthy = best$healthy,
    best_runtime_sec = best$runtime_sec,
    best_status = best$state,
    promote_recommend = best$gate_rank > best$baseline_gate_rank && best$gate_overall %in% c("PASS", "WARN"),
    improvement_over_baseline = best$gate_rank > best$baseline_gate_rank,
    stringsAsFactors = FALSE
  )
}))
case_best <- case_best[order(case_best$family, case_best$tau, case_best$fit_size, case_best$model, case_best$inference), , drop = FALSE]
write.csv(case_best, paths$case_best, row.names = FALSE, na = "")

unresolved_after_run <- subset(case_best, !(best_gate_overall %in% c("PASS", "WARN")))
write.csv(unresolved_after_run, paths$unresolved_after_run, row.names = FALSE, na = "")

view <- status
view_label <- "all"
if (nzchar(phase_filter)) {
  wanted <- unlist(strsplit(phase_filter, ",", fixed = TRUE), use.names = FALSE)
  wanted <- wanted[nzchar(wanted)]
  view <- status[status$phase %in% wanted, , drop = FALSE]
  view_label <- phase_filter
}
if (!nrow(view)) {
  stop("dynamic residual evaluate filter matched no rows")
}

latest_mtime <- "NA"
latest_file <- "NA"
existing <- view$health_csv[file.exists(view$health_csv)]
if (length(existing)) {
  latest_file <- existing[order(file.info(existing)$mtime, decreasing = TRUE)][1]
  latest_mtime <- format(file.info(latest_file)$mtime, "%Y-%m-%d %H:%M:%S %Z")
}

cat(sprintf(
  "SUMMARY phase=%s done=%d missing=%d pass=%d warn=%d fail=%d latest_mtime=%s latest_file=%s\n",
  view_label,
  sum(view$gate_overall != "MISSING"),
  sum(view$gate_overall == "MISSING"),
  sum(view$gate_overall == "PASS"),
  sum(view$gate_overall == "WARN"),
  sum(view$gate_overall == "FAIL"),
  latest_mtime,
  latest_file
))

cat("PHASE_SUMMARY\n")
print(phase_summary, row.names = FALSE)

cat("CONFIG_SUMMARY\n")
print(config_summary, row.names = FALSE)

cat("CASE_BEST\n")
print(case_best[, c(
  "family", "tau", "fit_size", "model", "inference",
  "baseline_gate_overall", "best_phase", "best_config_id",
  "best_candidate_variant_tag", "best_gate_overall", "promote_recommend"
)], row.names = FALSE)

cat("UNRESOLVED_AFTER_RUN\n")
if (nrow(unresolved_after_run)) {
  print(unresolved_after_run[, c(
    "family", "tau", "fit_size", "model", "inference",
    "baseline_gate_overall", "best_phase", "best_config_id",
    "best_candidate_variant_tag", "best_gate_overall"
  )], row.names = FALSE)
} else {
  cat("none\n")
}

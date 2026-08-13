#!/usr/bin/env Rscript

suppressPackageStartupMessages(requireNamespace("jsonlite", quietly = TRUE))
args <- commandArgs(trailingOnly = TRUE)
arg <- function(flag, default = NULL) { i <- which(args == flag); if (!length(i) || i[[1L]] >= length(args)) default else args[[i[[1L]] + 1L]] }
repo_root <- normalizePath(arg("--repo-root", system("git rev-parse --show-toplevel", intern = TRUE)), winslash = "/", mustWork = TRUE)
state_root <- normalizePath(arg("--state-root"), winslash = "/", mustWork = TRUE)
run_tag <- arg("--run-tag")
setwd(repo_root)
source(file.path(repo_root, "validation", "fitforecast_v2", "R", "qdesn_lower_tail_cellwise_mcmc_v1.R"))
out <- file.path(state_root, "confirmation")
plan <- qdesn_ssv2_read_csv(file.path(out, "confirmation_plan.csv"))
rows <- do.call(rbind, lapply(seq_len(nrow(plan)), function(i) {
  root <- qdesn_ltcv1_job_root(repo_root, run_tag, plan$job_id[[i]])
  status <- qdesn_ssv2_read_json(file.path(root, "job_status.json"))
  values <- qdesn_ltcv1_metric_values(root)
  data.frame(target_cell_id = plan$target_cell_id[[i]], metric = plan$metric[[i]],
    candidate_id = plan$candidate_id[[i]], chain_id = plan$chain_id[[i]],
    value = values[[plan$metric[[i]]]], current_value = plan$current_value[[i]],
    ratio = values[[plan$metric[[i]]]] / plan$current_value[[i]], status = status$status,
    signoff_path = file.path(root, "signoff_summary.csv"), stringsAsFactors = FALSE)
}))
qdesn_ssv2_write_csv(rows, file.path(out, "confirmation_chain_metrics.csv"))
summary <- do.call(rbind, lapply(split(rows, paste(rows$target_cell_id, rows$metric)), function(x) {
  data.frame(target_cell_id = x$target_cell_id[[1L]], metric = x$metric[[1L]],
    candidate_id = x$candidate_id[[1L]], chains = nrow(x), current_value = x$current_value[[1L]],
    mean_value = mean(x$value), median_value = median(x$value), min_value = min(x$value),
    max_value = max(x$value), mean_ratio = mean(x$ratio), median_ratio = median(x$ratio),
    chains_improved = sum(x$ratio < 1), all_finite = all(is.finite(x$value)),
    all_success = all(x$status == "SUCCESS"),
    promote = all(is.finite(x$value)) && all(x$status == "SUCCESS") &&
      mean(x$value) < x$current_value[[1L]] && median(x$value) < x$current_value[[1L]],
    stringsAsFactors = FALSE)
}))
summary$decision <- ifelse(summary$promote, "PROMOTE_METRIC_GAIN", "RETAIN_V6")
qdesn_ssv2_write_csv(summary, file.path(out, "confirmation_promotion_ledger.csv"))
qdesn_ssv2_write_json(list(
  schema_version = "qdesn_lower_tail_cellwise_mcmc_v1_confirmation_closeout_v1",
  generated_at = as.character(Sys.time()), run_tag = run_tag,
  decision = if (any(summary$promote)) "CONFIRMED_GAINS_READY_FOR_MANUAL_PROMOTION" else "NO_CONFIRMED_GAIN_RETAIN_V6",
  promoted_metrics = sum(summary$promote), article_update_automatic = FALSE,
  promotion_ledger_path = file.path(out, "confirmation_promotion_ledger.csv"),
  promotion_ledger_sha256 = qdesn_ssv2_sha256(file.path(out, "confirmation_promotion_ledger.csv"))
), file.path(out, "confirmation_closeout.json"))
print(summary, row.names = FALSE)

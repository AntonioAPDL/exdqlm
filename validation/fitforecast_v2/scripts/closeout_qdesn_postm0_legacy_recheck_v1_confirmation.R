#!/usr/bin/env Rscript

suppressPackageStartupMessages(requireNamespace("jsonlite", quietly = TRUE))
args <- commandArgs(trailingOnly = TRUE)
arg <- function(flag, default = NULL) {
  i <- which(args == flag)
  if (!length(i) || i[[1L]] >= length(args)) default else args[[i[[1L]] + 1L]]
}
repo_root <- normalizePath(arg("--repo-root", system("git rev-parse --show-toplevel", intern = TRUE)),
                           winslash = "/", mustWork = TRUE)
state_root <- normalizePath(arg("--state-root"), winslash = "/", mustWork = TRUE)
run_tag <- arg("--run-tag")
setwd(repo_root)
source(file.path(repo_root, "validation", "fitforecast_v2", "R",
                 "qdesn_postm0_legacy_recheck_v1.R"))
out <- file.path(state_root, "forecast_first_confirmation")
plan <- qdesn_ssv2_read_csv(file.path(out, "confirmation_plan.csv"))
rows <- vector("list", nrow(plan))
lead_rows <- vector("list", nrow(plan))
for (i in seq_len(nrow(plan))) {
  root <- qdesn_plrv1_job_root(repo_root, run_tag, plan$job_id[[i]])
  status <- qdesn_ssv2_read_json(file.path(root, "job_status.json"))
  values <- qdesn_ltcv1_metric_values(root)
  signoff_path <- file.path(root, "signoff_summary.csv")
  signoff <- qdesn_ssv2_read_csv(signoff_path)
  rows[[i]] <- data.frame(
    target_cell_id = plan$target_cell_id[[i]], metric = plan$metric[[i]],
    candidate_id = plan$candidate_id[[i]], chain_id = plan$chain_id[[i]],
    value = values[[plan$metric[[i]]]], current_value = plan$current_value[[i]],
    ratio = values[[plan$metric[[i]]]] / plan$current_value[[i]],
    fit_qtrue_rmse = values[["fit_qtrue_rmse"]],
    forecast_qtrue_mae_H1000 = values[["forecast_qtrue_mae_H1000"]],
    forecast_check_loss_H1000 = values[["forecast_check_loss_H1000"]],
    status = status$status, signoff_grade = signoff$signoff_grade[[1L]],
    signoff_reason = signoff$signoff_reason[[1L]],
    signoff_used_as_promotion_gate = FALSE,
    job_root = root, stringsAsFactors = FALSE
  )
  lead <- qdesn_ssv2_read_csv(file.path(root, "tables", "forecast_lead_metrics.csv"))
  lead$target_cell_id <- plan$target_cell_id[[i]]
  lead$candidate_id <- plan$candidate_id[[i]]
  lead$chain_id <- plan$chain_id[[i]]
  lead_rows[[i]] <- lead
}
chain_metrics <- do.call(rbind, rows)
lead_metrics <- do.call(rbind, lead_rows)
qdesn_ssv2_write_csv(chain_metrics, file.path(out, "confirmation_chain_metrics.csv"))
qdesn_ssv2_write_csv(lead_metrics, file.path(out, "confirmation_lead_metrics.csv"))
decision <- qdesn_plrv1_forecast_first_decision(chain_metrics)
qdesn_ssv2_write_csv(decision, file.path(out, "confirmation_promotion_ledger.csv"))

evidence_paths <- c(
  file.path(out, "confirmation_plan.csv"),
  file.path(out, "confirmation_materialization_manifest.json"),
  file.path(out, "canonical_source_registry.csv"),
  file.path(out, "canonical_window_registry.csv"),
  file.path(out, "confirmation_chain_metrics.csv"),
  file.path(out, "confirmation_lead_metrics.csv"),
  file.path(out, "confirmation_promotion_ledger.csv"),
  file.path(state_root, "forecast_first_confirmation_verification.json"),
  file.path(state_root, "forecast_first_confirmation_verification_runtime.csv")
)
for (root in chain_metrics$job_root) {
  evidence_paths <- c(evidence_paths,
    file.path(root, "job_status.json"), file.path(root, "fit_summary_row.csv"),
    file.path(root, "signoff_summary.csv"),
    file.path(root, "tables", "forecast_lead_metrics.csv"),
    file.path(root, "manifest", "output_retention.json"))
}
evidence_paths <- unique(normalizePath(evidence_paths, winslash = "/", mustWork = TRUE))
artifact_manifest <- data.frame(
  relative_path = vapply(evidence_paths, qdesn_ssv2_rel, character(1L),
                         repo_root = repo_root),
  bytes = as.numeric(file.info(evidence_paths)$size),
  sha256 = vapply(evidence_paths, qdesn_ssv2_sha256, character(1L)),
  stringsAsFactors = FALSE
)
manifest_path <- qdesn_ssv2_write_csv(
  artifact_manifest, file.path(out, "confirmation_artifact_manifest.csv")
)
binary <- list.files(
  c(out, chain_metrics$job_root), pattern = "[.](rds|rda|RData)$",
  recursive = TRUE, full.names = TRUE, ignore.case = TRUE
)
if (length(binary)) stop("Unexpected fitted-model binary payloads remain.")
closeout_path <- file.path(out, "confirmation_closeout.json")
qdesn_ssv2_write_json(list(
  schema_version = "qdesn_postm0_forecast_first_confirmation_closeout_v1",
  generated_at = as.character(Sys.time()), run_tag = run_tag,
  decision = if (isTRUE(decision$promote[[1L]])) {
    "CONFIRMED_FORECAST_GAIN_READY_FOR_METRIC_SPECIFIC_PROMOTION"
  } else {
    "NO_CANONICAL_FORECAST_GAIN_RETAIN_V6"
  },
  promoted_metrics = as.integer(decision$promote[[1L]]),
  promotion_primary_metric = "forecast_qtrue_mae_H1000",
  diagnostics_used_as_promotion_gate = FALSE,
  diagnostics_retained_as_descriptive_evidence = TRUE,
  article_update_automatic = FALSE,
  promotion_ledger_path = file.path(out, "confirmation_promotion_ledger.csv"),
  promotion_ledger_sha256 = qdesn_ssv2_sha256(file.path(out, "confirmation_promotion_ledger.csv")),
  artifact_manifest_path = manifest_path,
  artifact_manifest_sha256 = qdesn_ssv2_sha256(manifest_path),
  fitted_model_binary_payloads = 0L
), closeout_path)
print(decision, row.names = FALSE)

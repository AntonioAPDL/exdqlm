#!/usr/bin/env Rscript

cmd_args0 <- commandArgs(FALSE)
file_arg <- grep("^--file=", cmd_args0, value = TRUE)
this_file <- if (length(file_arg)) sub("^--file=", "", file_arg[[1L]]) else
  "validation/fitforecast_v2/scripts/promote_independent_metric_intervals_v1.R"
harness_root <- normalizePath(file.path(dirname(this_file), ".."), winslash = "/", mustWork = TRUE)
source(file.path(harness_root, "R", "utils.R"))
ffv2_source_all(harness_root)

args <- ffv2_parse_args()
repo_root <- normalizePath(args$`repo-root` %||% ffv2_repo_root(), winslash = "/", mustWork = TRUE)
state_root <- normalizePath(args$`state-root` %||% "", winslash = "/", mustWork = TRUE)
promotion_id <- as.character(args$`promotion-id` %||%
  "qdesn_dqlm_500obs_metric_intervals_v10_20260824")
if (!grepl("^[a-z0-9][a-z0-9_-]+$", promotion_id)) {
  stop("The promotion id is not portable.", call. = FALSE)
}

pipeline_status <- readLines(file.path(state_root, "pipeline.status"), warn = FALSE)
if (!length(pipeline_status) ||
    !grepl("^status=SUCCESS([[:space:]]|$)", pipeline_status[[1L]])) {
  stop("The production pipeline is not complete.", call. = FALSE)
}
closeout_root <- file.path(state_root, "closeout")
handoff <- ffv2_read_json(file.path(closeout_root, "integration_handoff.json"))
checks <- ffv2_read_csv(file.path(closeout_root, "closeout_checks.csv"))
if (!identical(as.character(handoff$status), "READY_FOR_INTEGRATION") ||
    nrow(checks) != 11L || !all(as.logical(checks$pass))) {
  stop("The closeout does not satisfy the frozen publication gates.", call. = FALSE)
}

promotion_root <- file.path(
  repo_root, "validation", "fitforecast_v2", "promotions", promotion_id
)
ffv2_ensure_dir(promotion_root)
selected <- c(
  "qdesn_dqlm_500obs_metric_intervals_v10_interface.csv",
  "source_interval_summary.csv",
  "article_metric_role_intervals.csv",
  "mcmc_metric_diagnostics.csv",
  "job_artifact_audit.csv",
  "closeout_checks.csv",
  "article_asset_manifest.csv"
)
source_paths <- file.path(closeout_root, selected)
if (any(!file.exists(source_paths))) {
  stop("A required compact closeout artifact is missing.", call. = FALSE)
}
destination_paths <- file.path(promotion_root, selected)
copied <- file.copy(source_paths, destination_paths, overwrite = TRUE, copy.mode = TRUE)
if (!all(copied)) stop("A compact closeout artifact could not be frozen.", call. = FALSE)

asset_source <- file.path(closeout_root, "article_assets")
asset_destination <- file.path(promotion_root, "article_assets")
ffv2_ensure_dir(asset_destination)
asset_names <- sort(list.files(asset_source, full.names = FALSE))
if (length(asset_names) != 9L) stop("The article packet must contain nine assets.", call. = FALSE)
asset_copied <- file.copy(
  file.path(asset_source, asset_names), file.path(asset_destination, asset_names),
  overwrite = TRUE, copy.mode = TRUE
)
if (!all(asset_copied)) stop("An article asset could not be frozen.", call. = FALSE)

relative_files <- c(selected, file.path("article_assets", asset_names))
frozen_paths <- file.path(promotion_root, relative_files)
ledger <- data.frame(
  relative_path = relative_files,
  bytes = as.numeric(file.info(frozen_paths)$size),
  sha256 = vapply(frozen_paths, ffv2_file_sha256, character(1L)),
  stringsAsFactors = FALSE
)
ledger_path <- ffv2_write_csv(ledger, file.path(promotion_root, "promotion_file_ledger.csv"))

source_summary <- ffv2_read_csv(file.path(promotion_root, "source_interval_summary.csv"))
diagnostics <- ffv2_read_csv(file.path(promotion_root, "mcmc_metric_diagnostics.csv"))
interface <- ffv2_read_csv(file.path(
  promotion_root, "qdesn_dqlm_500obs_metric_intervals_v10_interface.csv"
))
manifest <- list(
  schema_version = "independent_metric_intervals_v1_promotion",
  status = "READY_FOR_INTEGRATION",
  promotion_id = promotion_id,
  generated_at = as.character(handoff$generated_at),
  run_id = as.character(handoff$run_id),
  rollback_authority = as.character(handoff$rollback_authority),
  estimator_id = as.character(handoff$estimator_id),
  scientific_execution_commit = as.character(handoff$git_commit),
  promotion_implementation_commit = system("git rev-parse HEAD", intern = TRUE),
  jobs = as.integer(handoff$jobs),
  sources = length(unique(source_summary$replay_id)),
  source_metric_rows = nrow(source_summary),
  metric_roles = as.integer(handoff$metric_roles),
  interface_rows = nrow(interface),
  vb_rows = sum(interface$inference == "vb"),
  mcmc_rows = sum(interface$inference == "mcmc"),
  mcmc_diagnostic_pass_rows = sum(diagnostics$diagnostic_grade == "PASS"),
  mcmc_diagnostic_warn_rows = sum(diagnostics$diagnostic_grade == "WARN"),
  article_assets = length(asset_names),
  heavy_binary_count = 0L,
  compact_payload_bytes = sum(ledger$bytes),
  file_ledger = "promotion_file_ledger.csv",
  file_ledger_sha256 = ffv2_file_sha256(ledger_path),
  article_write_performed = FALSE,
  integration_owner = "ARTICLE_QDESN_INTEGRATION"
)
ffv2_write_json(manifest, file.path(promotion_root, "promotion_manifest.json"))
cat(sprintf("promotion=%s files=%d bytes=%d status=READY_FOR_INTEGRATION\n",
            promotion_id, nrow(ledger), sum(ledger$bytes)))

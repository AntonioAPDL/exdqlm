#!/usr/bin/env Rscript

cmd_args0 <- commandArgs(FALSE)
file_arg <- grep("^--file=", cmd_args0, value = TRUE)
this_file <- if (length(file_arg)) {
  sub("^--file=", "", file_arg[[1L]])
} else {
  "validation/fitforecast_v2/scripts/materialize_exdqlm_dqlm_c13_mcmc_500obs_handoff.R"
}
harness_root <- normalizePath(file.path(dirname(this_file), ".."), winslash = "/", mustWork = TRUE)
source(file.path(harness_root, "R", "utils.R"))
ffv2_source_all(harness_root)

args <- ffv2_parse_args()
run_tag <- args$`run-tag` %||% ffv2_c13_mcmc_default_run_tag()
promotion_id <- args$`promotion-id` %||% ffv2_c13_mcmc_default_promotion_id()
default_run_root <- file.path(ffv2_repo_root(), "validation/fitforecast_v2/runs", run_tag)
manifest_path <- args$manifest %||% file.path(default_run_root, "manifests", "row_manifest.csv")
interface_path <- args$interface %||% file.path(default_run_root, "interfaces", "exdqlm_dqlm_dynamic_fitforecast_v2_shared_interface.csv")
out_dir <- args$`out-dir` %||% file.path(ffv2_harness_root(), "promotions", promotion_id)

manifest <- ffv2_read_csv(normalizePath(manifest_path, winslash = "/", mustWork = TRUE))
if (!file.exists(interface_path)) {
  interface <- ffv2_export_shared_interface(manifest, interface_path)
} else {
  interface <- ffv2_read_csv(interface_path)
}
rows <- ffv2_c13_mcmc_interface_rows(interface)
issues <- ffv2_validate_c13_mcmc_interface(rows)
if (length(issues)) {
  stop(sprintf("Refusing to materialize incomplete c13 MCMC handoff: %s", paste(issues, collapse = " | ")),
       call. = FALSE)
}
summary <- ffv2_c13_mcmc_cell_summary(rows)
if (nrow(summary) != 18L) stop("Expected 18 summary rows before promotion.", call. = FALSE)

git <- ffv2_git_info()
summary$promotion_id <- promotion_id
summary$promotion_status <- "authoritative_article_facing_after_complete_audit"
summary$diagnostic_qualification <- "diagnostic_qualified_current_best_c13_mcmc"
summary$model_family <- "exdqlm_dqlm"
summary$model_key <- paste0(summary$model_variant, "_c13_mcmc")
summary$inference <- "mcmc"
summary$method <- "mcmc"
summary$fit_size <- 500L
summary$effective_fit_size <- 500L
summary$comparison_eligible <- TRUE
summary$fit_check_loss <- summary$fit_check
summary$forecast_qtrue_mae_lead_weighted <- summary$forecast_qtrue_mae
summary$forecast_qtrue_rmse_lead_weighted <- summary$forecast_qtrue_rmse
summary$forecast_check_loss_lead_weighted <- summary$forecast_check
summary$runtime_hours <- summary$runtime_sec_total / 3600
summary$validation_commit_at_materialization <- git$head
summary$validation_run_commit <- summary$validation_commit
summary$source_registry_hash_name <- "sha256"
summary$source_registry_hash_value <- ffv2_shared_source_registry_hash_value()

summary <- summary[, c(
  "promotion_id", "promotion_status", "diagnostic_qualification",
  "model_family", "model_variant", "model_key", "inference", "method",
  "family", "tau", "fit_size", "effective_fit_size",
  "candidate_id", "calibration_id", "status", "health_gate", "signoff_grade",
  "comparison_eligible", "fit_qtrue_rmse", "fit_check_loss",
  "forecast_qtrue_mae_lead_weighted", "forecast_qtrue_rmse_lead_weighted",
  "forecast_check_loss_lead_weighted", "runtime_sec_total", "runtime_hours",
  "n_leads", "n_origins_scored_total", "max_lead_configured",
  "origin_stride", "forecast_protocol", "state_update_method",
  "train_start_source_index", "train_end_source_index",
  "forecast_origin_source_index", "forecast_block_start_source_index",
  "forecast_block_end_source_index", "source_registry_hash_name",
  "source_registry_hash_value", "validation_branch",
  "validation_commit_at_materialization", "validation_run_commit",
  "package_version", "run_tag"
), drop = FALSE]

source_paths <- data.frame(
  source_id = c("row_manifest", "shared_interface", "source_registry", "runtime_metadata"),
  path = c(
    normalizePath(manifest_path, winslash = "/", mustWork = TRUE),
    normalizePath(interface_path, winslash = "/", mustWork = TRUE),
    normalizePath(file.path(unique(manifest$run_root)[[1L]], "manifests", "source_registry.csv"), winslash = "/", mustWork = TRUE),
    normalizePath(file.path(unique(manifest$run_root)[[1L]], "manifests", "runtime_metadata.json"), winslash = "/", mustWork = TRUE)
  ),
  stringsAsFactors = FALSE
)
source_paths$sha256 <- vapply(source_paths$path, ffv2_file_sha256, character(1))

ffv2_ensure_dir(out_dir)
summary_path <- file.path(out_dir, paste0(promotion_id, "_summary.csv"))
sources_path <- file.path(out_dir, paste0(promotion_id, "_sources.csv"))
manifest_out <- file.path(out_dir, paste0(promotion_id, "_manifest.json"))
readme_path <- file.path(out_dir, "README.md")
ffv2_write_csv(summary, summary_path)
ffv2_write_csv(source_paths, sources_path)
ffv2_write_json(
  list(
    promotion_id = promotion_id,
    promotion_status = "authoritative_article_facing_after_complete_audit",
    generated_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"),
    validation_worktree = git$repo_root,
    validation_branch = git$branch,
    validation_commit_at_materialization = git$head,
    run_tag = run_tag,
    candidate_id = ffv2_c13_mcmc_candidate_id(),
    expected_cells = 18L,
    expected_lead_rows = 540L,
    observed_cells = nrow(summary),
    observed_lead_rows = nrow(rows),
    source_registry_hash_value = ffv2_shared_source_registry_hash_value(),
    summary_path = normalizePath(summary_path, winslash = "/", mustWork = TRUE),
    summary_sha256 = ffv2_file_sha256(summary_path),
    sources_path = normalizePath(sources_path, winslash = "/", mustWork = TRUE),
    sources_sha256 = ffv2_file_sha256(sources_path)
  ),
  manifest_out
)
writeLines(c(
  "# exDQLM/DQLM c13 MCMC 500-Observation Handoff",
  "",
  "This promotion directory is created only after the c13 MCMC refresh has a complete done/PASS grid: 18 model/family/quantile cells and 30 rolling-origin lead rows per cell.",
  "",
  paste0("- promotion id: `", promotion_id, "`"),
  paste0("- run tag: `", run_tag, "`"),
  paste0("- candidate id: `", ffv2_c13_mcmc_candidate_id(), "`"),
  paste0("- summary: `", basename(summary_path), "`"),
  paste0("- sources: `", basename(sources_path), "`"),
  paste0("- manifest: `", basename(manifest_out), "`"),
  "",
  "Article integration rule: replace only exDQLM/DQLM MCMC 500-observation rows with this handoff. Do not mix this handoff with older historical exDQLM/DQLM MCMC rows unless the table explicitly labels the evidence status."
), readme_path)

cat("materialized exDQLM/DQLM c13 MCMC handoff\n")
cat(sprintf("promotion_id: %s\n", promotion_id))
cat(sprintf("summary: %s\n", summary_path))
cat(sprintf("sources: %s\n", sources_path))
cat(sprintf("manifest: %s\n", manifest_out))
cat(sprintf("readme: %s\n", readme_path))

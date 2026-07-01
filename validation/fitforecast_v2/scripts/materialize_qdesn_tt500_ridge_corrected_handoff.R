#!/usr/bin/env Rscript

`%||%` <- function(lhs, rhs) {
  if (is.null(lhs) || !length(lhs) || is.na(lhs[[1L]]) || !nzchar(as.character(lhs[[1L]]))) rhs else lhs
}

script_arg <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1L] %||% "")
if (!nzchar(script_arg)) {
  stop("Could not locate script path from Rscript command arguments.", call. = FALSE)
}
repo_root <- normalizePath(file.path(dirname(normalizePath(script_arg, mustWork = TRUE)), "..", "..", ".."), winslash = "/", mustWork = TRUE)
if (!file.exists(file.path(repo_root, "DESCRIPTION"))) {
  stop("Could not locate repository root from script path.", call. = FALSE)
}

sha256_file <- function(path) {
  path <- normalizePath(path, winslash = "/", mustWork = TRUE)
  unname(tools::sha256sum(path))
}

read_csv_strict <- function(path) {
  read.csv(normalizePath(path, winslash = "/", mustWork = TRUE), check.names = FALSE, stringsAsFactors = FALSE)
}

write_csv_stable <- function(x, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  write.csv(x, path, row.names = FALSE, na = "", quote = TRUE)
}

git_value <- function(args) {
  out <- tryCatch(
    system2("git", c("-C", repo_root, args), stdout = TRUE, stderr = TRUE),
    error = function(e) NA_character_
  )
  if (!length(out)) NA_character_ else out[[1L]]
}

weighted_mean <- function(x, w) {
  x <- as.numeric(x)
  w <- as.numeric(w)
  ok <- is.finite(x) & is.finite(w) & w > 0
  if (!any(ok)) return(NA_real_)
  sum(x[ok] * w[ok]) / sum(w[ok])
}

stage_stub <- "qdesn_dynamic_fitforecast_v2_tt500_ridge_corrected_desn"
run_prefix <- "qdesn-tt500-ridge-corrected-desn-fullseq-20260701025854__git-d45abc6"
campaign_stamps <- list(
  vb = "20260701-032353__git-d45abc6",
  mcmc = "20260701-033130__git-d45abc6"
)
run_roots <- list(
  vb_al = file.path(repo_root, "reports/qdesn_mcmc_validation", stage_stub, paste0(run_prefix, "-vb-al-full"), campaign_stamps$vb),
  vb_exal = file.path(repo_root, "reports/qdesn_mcmc_validation", stage_stub, paste0(run_prefix, "-vb-exal-full"), campaign_stamps$vb),
  mcmc_al = file.path(repo_root, "reports/qdesn_mcmc_validation", stage_stub, paste0(run_prefix, "-mcmc-al-full"), campaign_stamps$mcmc),
  mcmc_exal = file.path(repo_root, "reports/qdesn_mcmc_validation", stage_stub, paste0(run_prefix, "-mcmc-exal-full"), campaign_stamps$mcmc)
)
result_roots <- list(
  vb_al = sub("/reports/", "/results/", run_roots$vb_al, fixed = TRUE),
  vb_exal = sub("/reports/", "/results/", run_roots$vb_exal, fixed = TRUE),
  mcmc_al = sub("/reports/", "/results/", run_roots$mcmc_al, fixed = TRUE),
  mcmc_exal = sub("/reports/", "/results/", run_roots$mcmc_exal, fixed = TRUE)
)
summary_paths <- vapply(run_roots, function(root) file.path(root, "tables", "campaign_fit_summary.csv"), character(1))
if (!all(file.exists(summary_paths))) {
  stop(sprintf("Missing campaign fit summary paths: %s", paste(summary_paths[!file.exists(summary_paths)], collapse = ", ")), call. = FALSE)
}

source_files <- data.frame(
  source_id = c(names(summary_paths), "orchestrator_manifest", "orchestrator_log"),
  path = c(
    normalizePath(summary_paths, winslash = "/", mustWork = TRUE),
    normalizePath(file.path(repo_root, "reports/qdesn_mcmc_validation", stage_stub, "orchestrators/qdesn-tt500-ridge-corrected-desn-orchestrator-20260701-025900__git-d45abc6/manifest/orchestrator_manifest.json"), winslash = "/", mustWork = TRUE),
    normalizePath(file.path(repo_root, "reports/qdesn_mcmc_validation", stage_stub, "orchestrators/qdesn-tt500-ridge-corrected-desn-orchestrator-20260701-025900__git-d45abc6/logs/detach_all.log"), winslash = "/", mustWork = TRUE)
  ),
  stringsAsFactors = FALSE
)
source_files$observed_sha256 <- vapply(source_files$path, sha256_file, character(1))
source_files$hash_verified <- TRUE

fits <- do.call(rbind, lapply(names(summary_paths), function(id) {
  x <- read_csv_strict(summary_paths[[id]])
  x$source_selection <- id
  x$source_run_tag <- paste0(run_prefix, "-", gsub("_", "-", id))
  x$source_campaign_stamp <- if (grepl("^vb", id)) campaign_stamps$vb else campaign_stamps$mcmc
  x$source_report_root <- normalizePath(run_roots[[id]], winslash = "/", mustWork = TRUE)
  x$source_results_root <- normalizePath(result_roots[[id]], winslash = "/", mustWork = TRUE)
  x
}))

if (nrow(fits) != 36L ||
    !all(fits$status == "SUCCESS") ||
    !all(fits$prior == "ridge") ||
    !all(as.integer(fits$fit_size) == 500L)) {
  stop("Ridge corrected handoff expected exactly 36 successful TT500 ridge rows.", call. = FALSE)
}

lead_metrics <- lapply(seq_len(nrow(fits)), function(ii) {
  path <- fits$forecast_lead_metrics_path[[ii]]
  lead <- read_csv_strict(path)
  if (nrow(lead) != 30L ||
      !identical(sort(as.integer(lead$forecast_lead)), 1:30) ||
      any(as.integer(lead$origin_stride) != 30L) ||
      any(as.integer(lead$max_lead_configured) != 30L) ||
      any(lead$forecast_protocol != "rolling_origin_no_refit_state_update") ||
      any(as.logical(lead$refit_per_origin)) ||
      any(as.logical(lead$synthesis_enabled)) ||
      sum(as.integer(lead$n_origins_scored)) != 1000L) {
    stop(sprintf("Lead metrics violate contract for %s", fits$spec_id[[ii]]), call. = FALSE)
  }
  data.frame(
    n_leads = nrow(lead),
    n_origins_scored_total = sum(as.integer(lead$n_origins_scored)),
    forecast_max_lead_configured = as.integer(lead$max_lead_configured[[1L]]),
    forecast_origin_stride = as.integer(lead$origin_stride[[1L]]),
    forecast_protocol = as.character(lead$forecast_protocol[[1L]]),
    forecast_qtrue_mae_lead_weighted = weighted_mean(lead$forecast_qtrue_mae, lead$n_origins_scored),
    forecast_qtrue_rmse_lead_weighted = weighted_mean(lead$forecast_qtrue_rmse, lead$n_origins_scored),
    forecast_pinball_mean_lead_weighted = weighted_mean(lead$forecast_pinball_mean, lead$n_origins_scored),
    forecast_lead_metrics_path = normalizePath(path, winslash = "/", mustWork = TRUE),
    forecast_lead_metrics_sha256 = sha256_file(path),
    stringsAsFactors = FALSE
  )
})
lead_metrics <- do.call(rbind, lead_metrics)

desc <- read.dcf(file.path(repo_root, "DESCRIPTION"))
package_version <- unname(desc[1L, "Version"])
validation_branch <- git_value(c("branch", "--show-current"))
validation_commit <- git_value(c("rev-parse", "HEAD"))

summary <- data.frame(
  promotion_id = "qdesn_tt500_ridge_corrected_candidate_20260701",
  promotion_status = "candidate_partial_diagnostic_clean",
  diagnostic_qualification = ifelse(fits$signoff_grade == "PASS", "diagnostic_pass", "diagnostic_debt"),
  source_selection = fits$source_selection,
  source_run_tag = fits$source_run_tag,
  source_campaign_stamp = fits$source_campaign_stamp,
  source_report_root = fits$source_report_root,
  source_results_root = fits$source_results_root,
  root_id = fits$root_id,
  spec_id = fits$spec_id,
  model_family = "qdesn",
  model_variant = "ridge",
  model_key = paste("qdesn", fits$likelihood_family, "ridge", sep = "_"),
  qdesn_likelihood = fits$likelihood_family,
  inference = fits$method,
  method = fits$method,
  likelihood_family = fits$likelihood_family,
  prior = fits$prior,
  family = fits$family,
  tau = as.numeric(fits$tau),
  fit_size = as.integer(fits$fit_size),
  effective_fit_size = as.integer(fits$effective_fit_size),
  screening_profile_id = fits$screening_profile_id,
  status = fits$status,
  signoff_grade = fits$signoff_grade,
  signoff_reason = fits$signoff_reason,
  comparison_eligible = fits$comparison_eligible,
  fit_qtrue_rmse = as.numeric(fits$train_point_qtrue_rmse),
  fit_qtrue_mae = as.numeric(fits$train_qtrue_mae),
  fit_pinball_mean = as.numeric(fits$train_point_pinball_tau),
  forecast_qtrue_mae_lead_weighted = lead_metrics$forecast_qtrue_mae_lead_weighted,
  forecast_qtrue_rmse_lead_weighted = lead_metrics$forecast_qtrue_rmse_lead_weighted,
  forecast_pinball_mean_lead_weighted = lead_metrics$forecast_pinball_mean_lead_weighted,
  runtime_sec_total = as.numeric(fits$total_stage_seconds %||% fits$runtime_sec),
  runtime_hours = as.numeric(fits$total_stage_seconds %||% fits$runtime_sec) / 3600,
  n_leads = lead_metrics$n_leads,
  n_origins_scored_total = lead_metrics$n_origins_scored_total,
  forecast_max_lead_configured = lead_metrics$forecast_max_lead_configured,
  forecast_origin_stride = lead_metrics$forecast_origin_stride,
  forecast_protocol = lead_metrics$forecast_protocol,
  train_start_source_index = 8501L,
  train_end_source_index = 9000L,
  forecast_origin_source_index = 9000L,
  forecast_block_start_source_index = 9001L,
  forecast_block_end_source_index = 10000L,
  validation_branch = validation_branch,
  validation_commit_at_materialization = validation_commit,
  validation_run_commit = "d45abc6",
  package_version = package_version,
  source_registry_hash_name = "000__bundle_manifest.json.sha256",
  source_registry_hash_value = "edddb56fc2b30e49ac99fdd08b53dad468ed53e05d0fe1fe16426ee9d9ffe275",
  forecast_lead_metrics_path = lead_metrics$forecast_lead_metrics_path,
  forecast_lead_metrics_sha256 = lead_metrics$forecast_lead_metrics_sha256,
  stringsAsFactors = FALSE
)

out_dir <- file.path(repo_root, "validation/fitforecast_v2/promotions/qdesn_tt500_ridge_corrected_candidate_20260701")
summary_path <- file.path(out_dir, "qdesn_tt500_ridge_corrected_candidate_summary.csv")
sources_path <- file.path(out_dir, "qdesn_tt500_ridge_corrected_candidate_sources.csv")
manifest_path <- file.path(out_dir, "qdesn_tt500_ridge_corrected_candidate_manifest.json")
readme_path <- file.path(out_dir, "README.md")

write_csv_stable(summary, summary_path)
write_csv_stable(source_files, sources_path)
summary_sha <- sha256_file(summary_path)
sources_sha <- sha256_file(sources_path)

manifest <- list(
  promotion_id = "qdesn_tt500_ridge_corrected_candidate_20260701",
  promotion_status = "candidate_partial_diagnostic_clean",
  diagnostic_qualification = "VB and MCMC AL diagnostic-clean enough for candidate promotion; MCMC exAL has unresolved high-autocorrelation debt.",
  materializer = "validation/fitforecast_v2/scripts/materialize_qdesn_tt500_ridge_corrected_handoff.R",
  validation_branch = validation_branch,
  validation_commit_at_materialization = validation_commit,
  package_version = package_version,
  source_registry_hash_name = "000__bundle_manifest.json.sha256",
  source_registry_hash_value = "edddb56fc2b30e49ac99fdd08b53dad468ed53e05d0fe1fe16426ee9d9ffe275",
  rolling_origin_contract = list(
    fit_size = 500,
    train_start_source_index = 8501,
    train_end_source_index = 9000,
    forecast_origin_source_index = 9000,
    forecast_block_start_source_index = 9001,
    forecast_block_end_source_index = 10000,
    max_lead_configured = 30,
    origin_stride = 30,
    forecast_protocol = "rolling_origin_no_refit_state_update",
    synthesis_enabled = FALSE
  ),
  selected_rows = nrow(summary),
  signoff_counts = as.list(table(summary$signoff_grade)),
  group_counts = as.list(table(paste(summary$method, summary$likelihood_family, summary$signoff_grade, sep = "_"))),
  artifacts = list(
    summary_csv = list(path = normalizePath(summary_path, winslash = "/", mustWork = TRUE), sha256 = summary_sha),
    sources_csv = list(path = normalizePath(sources_path, winslash = "/", mustWork = TRUE), sha256 = sources_sha)
  ),
  source_files = source_files[, c("source_id", "path", "observed_sha256", "hash_verified")]
)
jsonlite::write_json(manifest, manifest_path, auto_unbox = TRUE, pretty = TRUE, dataframe = "rows")
manifest_sha <- sha256_file(manifest_path)

readme_lines <- c(
  "# Q-DESN TT500 Ridge Corrected Candidate",
  "",
  "This directory materializes the July 1, 2026 Q-DESN TT500 ridge corrected-DESN relaunch as a compact, article-facing candidate artifact.",
  "",
  "Promotion status: `candidate_partial_diagnostic_clean`.",
  "",
  "Execution is complete and storage-light. VB ridge and MCMC AL ridge are candidate-promotable. MCMC exAL ridge is retained with explicit diagnostic debt because four rows remain `FAIL` for high autocorrelation and four rows remain `WARN`.",
  "",
  sprintf("- Summary CSV: `%s`", basename(summary_path)),
  sprintf("- Summary SHA-256: `%s`", summary_sha),
  sprintf("- Source CSV: `%s`", basename(sources_path)),
  sprintf("- Source CSV SHA-256: `%s`", sources_sha),
  sprintf("- Manifest: `%s`", basename(manifest_path)),
  sprintf("- Manifest SHA-256: `%s`", manifest_sha),
  "",
  "The forecast protocol is rolling-origin, no-refit, observed-lag state update with `Hmax = 30` and origin stride `30` over source indices `9001:10000`."
)
writeLines(readme_lines, readme_path, useBytes = TRUE)

cat("Q-DESN TT500 ridge corrected candidate handoff materialized: PASS\n")
cat(sprintf("summary: %s\n", normalizePath(summary_path, winslash = "/", mustWork = TRUE)))
cat(sprintf("summary_sha256: %s\n", summary_sha))
cat(sprintf("manifest: %s\n", normalizePath(manifest_path, winslash = "/", mustWork = TRUE)))
cat(sprintf("manifest_sha256: %s\n", manifest_sha))

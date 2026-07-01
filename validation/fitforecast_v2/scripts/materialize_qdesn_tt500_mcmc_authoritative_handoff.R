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

validate_sha <- function(path, expected, label) {
  observed <- sha256_file(path)
  if (!identical(observed, expected)) {
    stop(sprintf("%s SHA-256 mismatch: expected %s, observed %s", label, expected, observed), call. = FALSE)
  }
  observed
}

weighted_mean <- function(x, w) {
  x <- as.numeric(x)
  w <- as.numeric(w)
  ok <- is.finite(x) & is.finite(w) & w > 0
  if (!any(ok)) return(NA_real_)
  sum(x[ok] * w[ok]) / sum(w[ok])
}

cell_key <- function(family, tau) {
  paste(as.character(family), sprintf("%.2f", as.numeric(tau)), sep = "\r")
}

scalar <- function(x, default = NA_character_) {
  if (is.null(x) || !length(x)) return(default)
  x[[1L]]
}

base_report_root <- "/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/reports/qdesn_mcmc_validation/qdesn_dynamic_fitforecast_v2_tt500_mcmc_vb_winner_confirmation/qdesn-tt500-mcmc-vb-winner-confirmation-full-20260630__git-c051364/20260630-101419__git-c051364"
base_results_root <- "/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/results/qdesn_mcmc_validation/qdesn_dynamic_fitforecast_v2_tt500_mcmc_vb_winner_confirmation/qdesn-tt500-mcmc-vb-winner-confirmation-full-20260630__git-c051364/20260630-101419__git-c051364"
rescue_report_root <- "/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/reports/qdesn_mcmc_validation/qdesn_dynamic_fitforecast_v2_tt500_mcmc_vb_winner_confirmation_rescue_fail5/qdesn-tt500-mcmc-vbwin-rescue-fail5-full-20260630__git-c051364/20260630-112709__git-c051364"
rescue_results_root <- "/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/results/qdesn_mcmc_validation/qdesn_dynamic_fitforecast_v2_tt500_mcmc_vb_winner_confirmation_rescue_fail5/qdesn-tt500-mcmc-vbwin-rescue-fail5-full-20260630__git-c051364/20260630-112709__git-c051364"

source_files <- data.frame(
  source_id = c(
    "base_fit_summary",
    "base_audit_summary",
    "base_root_audit",
    "base_healthcheck",
    "rescue_fit_summary",
    "rescue_audit_summary",
    "rescue_root_audit",
    "rescue_healthcheck"
  ),
  path = c(
    file.path(base_report_root, "tables/campaign_fit_summary.csv"),
    file.path(base_report_root, "audit/tables/qdesn_tt500_vb_screen_audit_summary.csv"),
    file.path(base_report_root, "audit/tables/qdesn_tt500_vb_screen_root_audit.csv"),
    "/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/reports/qdesn_mcmc_validation/qdesn_dynamic_fitforecast_v2_tt500_mcmc_vb_winner_confirmation/qdesn-tt500-mcmc-vb-winner-confirmation-full-20260630__git-c051364/launch/qdesn_dynamic_exdqlm_crossstudy_healthcheck.md",
    file.path(rescue_report_root, "tables/campaign_fit_summary.csv"),
    file.path(rescue_report_root, "audit/tables/qdesn_tt500_vb_screen_audit_summary.csv"),
    file.path(rescue_report_root, "audit/tables/qdesn_tt500_vb_screen_root_audit.csv"),
    "/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/reports/qdesn_mcmc_validation/qdesn_dynamic_fitforecast_v2_tt500_mcmc_vb_winner_confirmation_rescue_fail5/qdesn-tt500-mcmc-vbwin-rescue-fail5-full-20260630__git-c051364/launch/qdesn_dynamic_exdqlm_crossstudy_healthcheck.md"
  ),
  expected_sha256 = c(
    "2da9c6101c863c757719c3f067f256ea2695b79308bc41b62ab1403799006b73",
    "da9b0f8675d611d9514b7edea44730e5c42effa5bcc31722dda4bbac6bed210b",
    "c36d7cc4a4b84b2ca5ed5dbe14263ba42c7c6dcfb8a0eb27668de61d070fe2f2",
    "0250af830689748c2180a948934357f4708dc42690721a3482643c0e39bfe181",
    "c0a31eed6e7f01b37aacd314def97d014a814a4c5e6b864aa603f4c46f8b96df",
    "91cf1d07364cc7681b16a3897af039aa0e0c7f5a5031a4cb8860254c757f0c1e",
    "e784a48315b7c2feeb1a28698c0941f73d9a2cc7a03923d0beccd08bb93530fc",
    "a885ccfde7f0339c1f9943dea4fee093de1df01409c37e8cddb7822f872d042d"
  ),
  stringsAsFactors = FALSE
)
source_files$observed_sha256 <- mapply(validate_sha, source_files$path, source_files$expected_sha256, source_files$source_id, USE.NAMES = FALSE)
source_files$hash_verified <- identical(source_files$expected_sha256, source_files$observed_sha256)

base_fit <- read_csv_strict(source_files$path[source_files$source_id == "base_fit_summary"])
rescue_fit <- read_csv_strict(source_files$path[source_files$source_id == "rescue_fit_summary"])
base_fit$source_selection <- "base_confirmation"
base_fit$source_run_tag <- "qdesn-tt500-mcmc-vb-winner-confirmation-full-20260630__git-c051364"
base_fit$source_campaign_stamp <- "20260630-101419__git-c051364"
base_fit$source_report_root <- base_report_root
base_fit$source_results_root <- base_results_root
rescue_fit$source_selection <- "rescue_fail5"
rescue_fit$source_run_tag <- "qdesn-tt500-mcmc-vbwin-rescue-fail5-full-20260630__git-c051364"
rescue_fit$source_campaign_stamp <- "20260630-112709__git-c051364"
rescue_fit$source_report_root <- rescue_report_root
rescue_fit$source_results_root <- rescue_results_root

required_fit_cols <- c(
  "root_id", "spec_id", "family", "tau", "fit_size", "effective_fit_size",
  "inference", "method", "likelihood_family", "prior", "status",
  "signoff_grade", "signoff_reason", "train_point_qtrue_rmse",
  "train_point_pinball_tau", "runtime_sec", "forecast_lead_metrics_path"
)
missing_base <- setdiff(required_fit_cols, names(base_fit))
missing_rescue <- setdiff(required_fit_cols, names(rescue_fit))
if (length(missing_base) || length(missing_rescue)) {
  stop(
    sprintf(
      "Missing required fit columns. base=[%s] rescue=[%s]",
      paste(missing_base, collapse = ","),
      paste(missing_rescue, collapse = ",")
    ),
    call. = FALSE
  )
}

selected_keys_from_rescue <- cell_key(rescue_fit$family, rescue_fit$tau)
base_keep <- !cell_key(base_fit$family, base_fit$tau) %in% selected_keys_from_rescue
selected <- rbind(base_fit[base_keep, , drop = FALSE], rescue_fit)
selected <- selected[order(match(selected$family, c("normal", "laplace", "gausmix")), as.numeric(selected$tau)), , drop = FALSE]
rownames(selected) <- NULL

expected_cells <- expand.grid(
  family = c("normal", "laplace", "gausmix"),
  tau = c(0.05, 0.25, 0.50),
  stringsAsFactors = FALSE
)
if (!identical(sort(cell_key(selected$family, selected$tau)), sort(cell_key(expected_cells$family, expected_cells$tau)))) {
  stop("Selected MCMC promotion rows do not cover exactly the 9 TT500 family/tau cells.", call. = FALSE)
}
if (any(duplicated(cell_key(selected$family, selected$tau)))) {
  stop("Selected MCMC promotion rows contain duplicate family/tau cells.", call. = FALSE)
}
if (!all(selected$status == "SUCCESS") ||
    !all(selected$inference == "mcmc") ||
    !all(selected$method == "mcmc") ||
    !all(selected$likelihood_family == "exal") ||
    !all(selected$prior == "rhs_ns") ||
    !all(as.integer(selected$fit_size) == 500L)) {
  stop("Selected MCMC promotion rows violate the TT500 exAL RHS MCMC contract.", call. = FALSE)
}

lead_metrics <- lapply(seq_len(nrow(selected)), function(ii) {
  lead <- read_csv_strict(selected$forecast_lead_metrics_path[[ii]])
  required_lead_cols <- c(
    "forecast_protocol", "refit_per_origin", "forecast_lead", "origin_stride",
    "max_lead_configured", "n_origins_scored", "origin_start_source_index",
    "origin_end_source_index", "target_start_source_index",
    "target_end_source_index", "forecast_qtrue_mae", "forecast_qtrue_rmse",
    "forecast_pinball_mean", "synthesis_enabled"
  )
  missing <- setdiff(required_lead_cols, names(lead))
  if (length(missing)) {
    stop(sprintf("Lead metrics for %s missing columns: %s", selected$root_id[[ii]], paste(missing, collapse = ",")), call. = FALSE)
  }
  if (nrow(lead) != 30L ||
      !identical(sort(as.integer(lead$forecast_lead)), 1:30) ||
      any(as.integer(lead$origin_stride) != 30L) ||
      any(as.integer(lead$max_lead_configured) != 30L) ||
      any(lead$forecast_protocol != "rolling_origin_no_refit_state_update") ||
      any(as.logical(lead$refit_per_origin)) ||
      any(as.logical(lead$synthesis_enabled)) ||
      sum(as.integer(lead$n_origins_scored)) != 1000L ||
      min(as.integer(lead$origin_start_source_index)) != 9000L ||
      max(as.integer(lead$origin_end_source_index)) != 9990L ||
      min(as.integer(lead$target_start_source_index)) != 9001L ||
      max(as.integer(lead$target_end_source_index)) != 10000L) {
    stop(sprintf("Lead metrics for %s violate the rolling-origin contract.", selected$root_id[[ii]]), call. = FALSE)
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
    forecast_lead_metrics_path = normalizePath(selected$forecast_lead_metrics_path[[ii]], winslash = "/", mustWork = TRUE),
    forecast_lead_metrics_sha256 = sha256_file(selected$forecast_lead_metrics_path[[ii]]),
    stringsAsFactors = FALSE
  )
})
lead_metrics <- do.call(rbind, lead_metrics)

desc <- read.dcf(file.path(repo_root, "DESCRIPTION"))
package_version <- unname(desc[1L, "Version"])
validation_branch <- git_value(c("branch", "--show-current"))
validation_commit <- git_value(c("rev-parse", "HEAD"))

summary <- data.frame(
  promotion_id = "qdesn_tt500_mcmc_authoritative_20260701",
  promotion_status = "authoritative_article_facing_diagnostic_qualified",
  diagnostic_qualification = "diagnostic_qualified_authoritative_mcmc",
  source_selection = selected$source_selection,
  source_run_tag = selected$source_run_tag,
  source_campaign_stamp = selected$source_campaign_stamp,
  source_report_root = selected$source_report_root,
  source_results_root = selected$source_results_root,
  root_id = selected$root_id,
  spec_id = selected$spec_id,
  model_family = "qdesn",
  model_variant = "rhs_ns",
  model_key = "qdesn_exal_rhs_ns",
  qdesn_likelihood = "exal",
  inference = "mcmc",
  method = selected$method,
  likelihood_family = selected$likelihood_family,
  prior = selected$prior,
  family = selected$family,
  tau = as.numeric(selected$tau),
  fit_size = as.integer(selected$fit_size),
  effective_fit_size = as.integer(selected$effective_fit_size),
  screening_profile_id = selected$screening_profile_id %||% selected$profile_id,
  status = selected$status,
  signoff_grade = selected$signoff_grade,
  signoff_reason = selected$signoff_reason,
  comparison_eligible = TRUE,
  fit_qtrue_rmse = as.numeric(selected$train_point_qtrue_rmse),
  fit_pinball_mean = as.numeric(selected$train_point_pinball_tau),
  forecast_qtrue_mae_lead_weighted = lead_metrics$forecast_qtrue_mae_lead_weighted,
  forecast_qtrue_rmse_lead_weighted = lead_metrics$forecast_qtrue_rmse_lead_weighted,
  forecast_pinball_mean_lead_weighted = lead_metrics$forecast_pinball_mean_lead_weighted,
  runtime_sec_total = as.numeric(selected$total_stage_seconds %||% selected$runtime_sec),
  runtime_hours = as.numeric(selected$total_stage_seconds %||% selected$runtime_sec) / 3600,
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
  validation_run_commit = "c051364",
  package_version = package_version,
  source_registry_hash_name = "000__bundle_manifest.json.sha256",
  source_registry_hash_value = "edddb56fc2b30e49ac99fdd08b53dad468ed53e05d0fe1fe16426ee9d9ffe275",
  base_fit_summary_sha256 = unname(source_files$observed_sha256[source_files$source_id == "base_fit_summary"]),
  rescue_fit_summary_sha256 = unname(source_files$observed_sha256[source_files$source_id == "rescue_fit_summary"]),
  forecast_lead_metrics_path = lead_metrics$forecast_lead_metrics_path,
  forecast_lead_metrics_sha256 = lead_metrics$forecast_lead_metrics_sha256,
  stringsAsFactors = FALSE
)

if (!all(summary$signoff_grade %in% c("WARN", "FAIL"))) {
  stop("Promotion intentionally expects WARN/FAIL diagnostic-qualified MCMC rows; observed unexpected grade.", call. = FALSE)
}

out_dir <- file.path(repo_root, "validation/fitforecast_v2/promotions/qdesn_tt500_mcmc_authoritative_20260701")
summary_path <- file.path(out_dir, "qdesn_tt500_mcmc_authoritative_summary.csv")
sources_path <- file.path(out_dir, "qdesn_tt500_mcmc_authoritative_sources.csv")
manifest_path <- file.path(out_dir, "qdesn_tt500_mcmc_authoritative_manifest.json")
readme_path <- file.path(out_dir, "README.md")

write_csv_stable(summary, summary_path)
write_csv_stable(source_files, sources_path)
summary_sha <- sha256_file(summary_path)
sources_sha <- sha256_file(sources_path)

manifest <- list(
  promotion_id = "qdesn_tt500_mcmc_authoritative_20260701",
  promotion_status = "authoritative_article_facing_diagnostic_qualified",
  diagnostic_qualification = "diagnostic_qualified_authoritative_mcmc",
  materializer = "validation/fitforecast_v2/scripts/materialize_qdesn_tt500_mcmc_authoritative_handoff.R",
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
  selected_cells = summary[, c("family", "tau", "source_selection", "source_run_tag", "signoff_grade", "signoff_reason")],
  signoff_counts = as.list(table(summary$signoff_grade)),
  source_counts = as.list(table(summary$source_selection)),
  artifacts = list(
    summary_csv = list(path = normalizePath(summary_path, winslash = "/", mustWork = TRUE), sha256 = summary_sha),
    sources_csv = list(path = normalizePath(sources_path, winslash = "/", mustWork = TRUE), sha256 = sources_sha)
  ),
  source_files = source_files[, c("source_id", "path", "observed_sha256", "hash_verified")]
)

jsonlite::write_json(manifest, manifest_path, auto_unbox = TRUE, pretty = TRUE, dataframe = "rows")
manifest_sha <- sha256_file(manifest_path)

readme_lines <- c(
  "# Q-DESN TT500 MCMC Authoritative Handoff",
  "",
  "This directory materializes the June 30, 2026 Q-DESN TT500 MCMC confirmation and rescue outputs as a compact, article-facing promotion artifact.",
  "",
  "Promotion status: `authoritative_article_facing_diagnostic_qualified`.",
  "",
  "The handoff is artifact-complete and storage-light, but not diagnostic-clean. Two selected cells remain `FAIL` because of high autocorrelation and seven cells remain `WARN`; those grades are intentionally retained in the summary and manifest.",
  "",
  "Selected rows use rescue outputs where available and base confirmation outputs otherwise.",
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

cat("Q-DESN TT500 MCMC authoritative handoff materialized: PASS\n")
cat(sprintf("summary: %s\n", normalizePath(summary_path, winslash = "/", mustWork = TRUE)))
cat(sprintf("summary_sha256: %s\n", summary_sha))
cat(sprintf("manifest: %s\n", normalizePath(manifest_path, winslash = "/", mustWork = TRUE)))
cat(sprintf("manifest_sha256: %s\n", manifest_sha))

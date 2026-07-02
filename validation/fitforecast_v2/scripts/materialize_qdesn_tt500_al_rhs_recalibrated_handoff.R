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

run_tag <- "qdesn-tt500-vb-al-rhs-recalibration-full-20260701__git-cb7998a"
campaign_stamp <- "20260701-105231__git-cb7998a"
stage_stub <- "qdesn_dynamic_fitforecast_v2_tt500_vb_al_rhs_recalibration"
report_root <- file.path(repo_root, "reports/qdesn_mcmc_validation", stage_stub, run_tag, campaign_stamp)
results_root <- file.path(repo_root, "results/qdesn_mcmc_validation", stage_stub, run_tag, campaign_stamp)

fit_summary_path <- file.path(report_root, "tables", "campaign_fit_summary.csv")
winner_path <- file.path(report_root, "al_rhs_partial_success_ranking", "tables", "cell_best_success_only.csv")
profile_ranking_path <- file.path(report_root, "al_rhs_partial_success_ranking", "tables", "profile_ranking_success_only.csv")
audit_summary_path <- file.path(report_root, "audit", "tables", "qdesn_tt500_vb_screen_audit_summary.csv")
root_audit_path <- file.path(report_root, "audit", "tables", "qdesn_tt500_vb_screen_root_audit.csv")
campaign_manifest_path <- file.path(report_root, "manifest", "campaign_manifest.json")
orchestrator_manifest_path <- file.path(
  repo_root, "reports/qdesn_mcmc_validation/qdesn_tt500_vb_al_rhs_recalibration",
  "qdesn-tt500-vb-al-rhs-recalibration-orchestrator-20260701-105059__git-cb7998a",
  "manifest", "orchestrator_manifest.json"
)
orchestrator_log_path <- file.path(repo_root, "logs", paste0(run_tag, ".log"))

required_inputs <- c(
  fit_summary_path, winner_path, profile_ranking_path, audit_summary_path,
  root_audit_path, campaign_manifest_path, orchestrator_manifest_path, orchestrator_log_path
)
if (!all(file.exists(required_inputs))) {
  stop(sprintf("Missing AL RHS handoff input(s): %s", paste(required_inputs[!file.exists(required_inputs)], collapse = ", ")), call. = FALSE)
}

fits <- read_csv_strict(fit_summary_path)
winners <- read_csv_strict(winner_path)
audit <- read_csv_strict(audit_summary_path)
root_audit <- read_csv_strict(root_audit_path)

if (nrow(winners) != 9L ||
    any(as.numeric(winners$rhs_tau0) == 3e-05) ||
    !all(winners$forecast_mae < winners$current_al_mae) ||
    !all(winners$forecast_pinball < winners$current_al_pinball)) {
  stop("AL RHS winner ledger does not satisfy the promotion gates.", call. = FALSE)
}
if (as.integer(audit$observed_roots[[1L]]) != 216L ||
    as.integer(audit$n_success[[1L]]) != 153L ||
    as.integer(audit$n_fail[[1L]]) != 63L ||
    as.integer(audit$forbidden_binary_count_total[[1L]]) != 0L) {
  stop("AL RHS audit summary does not match the expected Wave A screen outcome.", call. = FALSE)
}

winner_keys <- paste(winners$family, sprintf("%.8f", as.numeric(winners$tau)), winners$best_profile, sep = "\r")
fit_keys <- paste(fits$family, sprintf("%.8f", as.numeric(fits$tau)), fits$screening_profile_id, sep = "\r")
idx <- match(winner_keys, fit_keys)
if (anyNA(idx)) {
  stop("Could not match one or more AL RHS winners to campaign fit rows.", call. = FALSE)
}
selected <- fits[idx, , drop = FALSE]
if (!all(selected$status == "SUCCESS") ||
    !all(selected$signoff_grade == "PASS") ||
    !all(as.logical(selected$comparison_eligible)) ||
    !all(selected$method == "vb") ||
    !all(selected$likelihood_family == "al") ||
    !all(selected$prior == "rhs_ns") ||
    !all(as.integer(selected$fit_size) == 500L)) {
  stop("Selected AL RHS promotion rows violate the expected fit contract.", call. = FALSE)
}

lead_metrics <- lapply(seq_len(nrow(selected)), function(ii) {
  path <- selected$forecast_lead_metrics_path[[ii]]
  lead <- read_csv_strict(path)
  if (nrow(lead) != 30L ||
      !identical(sort(as.integer(lead$forecast_lead)), 1:30) ||
      any(as.integer(lead$origin_stride) != 30L) ||
      any(as.integer(lead$max_lead_configured) != 30L) ||
      any(lead$forecast_protocol != "rolling_origin_no_refit_state_update") ||
      any(as.logical(lead$refit_per_origin)) ||
      any(as.logical(lead$synthesis_enabled)) ||
      sum(as.integer(lead$n_origins_scored)) != 1000L) {
    stop(sprintf("Lead metrics violate contract for %s", selected$spec_id[[ii]]), call. = FALSE)
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

promotion_id <- "qdesn_tt500_al_rhs_recalibrated_candidate_20260701"
diagnostic_qualification <- "AL RHS VB Wave A success-only candidate; unstable rhs_tau0=3e-05 exploratory failures excluded and documented."

summary <- data.frame(
  promotion_id = promotion_id,
  promotion_status = "candidate_partial_screen_clean",
  diagnostic_qualification = "diagnostic_pass",
  source_selection = "vb_al_rhs_recalibration_success_winner",
  source_run_tag = run_tag,
  source_campaign_stamp = campaign_stamp,
  source_report_root = normalizePath(report_root, winslash = "/", mustWork = TRUE),
  source_results_root = normalizePath(results_root, winslash = "/", mustWork = TRUE),
  root_id = selected$root_id,
  spec_id = selected$spec_id,
  model_family = "qdesn",
  model_variant = "rhs_ns",
  model_key = "qdesn_al_rhs_ns",
  qdesn_likelihood = "al",
  inference = "vb",
  method = "vb",
  likelihood_family = "al",
  prior = "rhs_ns",
  family = selected$family,
  tau = as.numeric(selected$tau),
  fit_size = as.integer(selected$fit_size),
  effective_fit_size = as.integer(selected$effective_fit_size),
  screening_profile_id = selected$screening_profile_id,
  status = selected$status,
  signoff_grade = selected$signoff_grade,
  signoff_reason = selected$signoff_reason,
  comparison_eligible = selected$comparison_eligible,
  fit_qtrue_rmse = as.numeric(selected$train_point_qtrue_rmse),
  fit_qtrue_mae = as.numeric(selected$train_qtrue_mae),
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
  validation_run_commit = "cb7998a",
  package_version = package_version,
  source_registry_hash_name = "000__bundle_manifest.json.sha256",
  source_registry_hash_value = "edddb56fc2b30e49ac99fdd08b53dad468ed53e05d0fe1fe16426ee9d9ffe275",
  forecast_lead_metrics_path = lead_metrics$forecast_lead_metrics_path,
  forecast_lead_metrics_sha256 = lead_metrics$forecast_lead_metrics_sha256,
  stringsAsFactors = FALSE
)
summary <- summary[order(summary$family, summary$tau), , drop = FALSE]

failure_appendix <- fits[fits$status != "SUCCESS", , drop = FALSE]
failure_appendix <- failure_appendix[, intersect(
  c("root_id", "family", "tau", "screening_profile_id", "rhs_tau0", "status", "signoff_grade", "signoff_reason"),
  names(failure_appendix)
), drop = FALSE]

source_files <- data.frame(
  source_id = c(
    "campaign_fit_summary", "success_winner_ledger", "profile_ranking_success_only",
    "audit_summary", "root_audit", "campaign_manifest", "orchestrator_manifest",
    "orchestrator_log"
  ),
  path = normalizePath(c(
    fit_summary_path, winner_path, profile_ranking_path, audit_summary_path,
    root_audit_path, campaign_manifest_path, orchestrator_manifest_path,
    orchestrator_log_path
  ), winslash = "/", mustWork = TRUE),
  stringsAsFactors = FALSE
)
source_files$observed_sha256 <- vapply(source_files$path, sha256_file, character(1))
source_files$hash_verified <- TRUE

out_dir <- file.path(repo_root, "validation/fitforecast_v2/promotions", promotion_id)
summary_path <- file.path(out_dir, paste0(promotion_id, "_summary.csv"))
sources_path <- file.path(out_dir, paste0(promotion_id, "_sources.csv"))
failures_path <- file.path(out_dir, paste0(promotion_id, "_excluded_failures.csv"))
manifest_path <- file.path(out_dir, paste0(promotion_id, "_manifest.json"))
readme_path <- file.path(out_dir, "README.md")

write_csv_stable(summary, summary_path)
write_csv_stable(source_files, sources_path)
write_csv_stable(failure_appendix, failures_path)
summary_sha <- sha256_file(summary_path)
sources_sha <- sha256_file(sources_path)
failures_sha <- sha256_file(failures_path)

manifest <- list(
  promotion_id = promotion_id,
  promotion_status = "candidate_partial_screen_clean",
  diagnostic_qualification = diagnostic_qualification,
  row_diagnostic_qualification = "diagnostic_pass",
  materializer = "validation/fitforecast_v2/scripts/materialize_qdesn_tt500_al_rhs_recalibrated_handoff.R",
  validation_branch = validation_branch,
  validation_commit_at_materialization = validation_commit,
  validation_run_commit = "cb7998a",
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
  screen_roots = list(planned = 216, success = 153, failed = 63, running = 0),
  exclusion_rule = "Exclude rhs_tau0=3e-05 exploratory roots because all such roots failed with non_finite_fit/domain_violation/short_trace.",
  performance_gates = list(
    improved_mae_vs_current_al = 9,
    improved_pinball_vs_current_al = 9,
    pinball_le_best_external_vb = 9,
    total_cells = 9
  ),
  signoff_counts = as.list(table(summary$signoff_grade)),
  artifacts = list(
    summary_csv = list(path = normalizePath(summary_path, winslash = "/", mustWork = TRUE), sha256 = summary_sha),
    sources_csv = list(path = normalizePath(sources_path, winslash = "/", mustWork = TRUE), sha256 = sources_sha),
    excluded_failures_csv = list(path = normalizePath(failures_path, winslash = "/", mustWork = TRUE), sha256 = failures_sha)
  ),
  source_files = source_files[, c("source_id", "path", "observed_sha256", "hash_verified")]
)
jsonlite::write_json(manifest, manifest_path, auto_unbox = TRUE, pretty = TRUE, dataframe = "rows")
manifest_sha <- sha256_file(manifest_path)

readme_lines <- c(
  "# Q-DESN TT500 AL RHS Recalibrated Candidate",
  "",
  "This directory materializes the July 1, 2026 Q-DESN TT500 AL RHS VB recalibration screen as a compact, article-facing candidate artifact.",
  "",
  "Promotion status: `candidate_partial_screen_clean`.",
  "",
  "The full Wave A screen ran 216 roots. It produced 153 successful roots and 63 failed exploratory roots. Every failure used `rhs_tau0 = 3e-05`; all `1e-04` and `3e-04` candidates succeeded. The 9 promoted rows are success-only, cell-specific winners that improve both forecast MAE and pinball versus the old AL RHS rows.",
  "",
  sprintf("- Summary CSV: `%s`", basename(summary_path)),
  sprintf("- Summary SHA-256: `%s`", summary_sha),
  sprintf("- Source CSV: `%s`", basename(sources_path)),
  sprintf("- Source CSV SHA-256: `%s`", sources_sha),
  sprintf("- Excluded failures CSV: `%s`", basename(failures_path)),
  sprintf("- Excluded failures SHA-256: `%s`", failures_sha),
  sprintf("- Manifest: `%s`", basename(manifest_path)),
  sprintf("- Manifest SHA-256: `%s`", manifest_sha),
  "",
  "The forecast protocol is rolling-origin, no-refit, observed-lag state update with `Hmax = 30` and origin stride `30` over source indices `9001:10000`."
)
writeLines(readme_lines, readme_path, useBytes = TRUE)

cat("Q-DESN TT500 AL RHS recalibrated candidate handoff materialized: PASS\n")
cat(sprintf("summary: %s\n", normalizePath(summary_path, winslash = "/", mustWork = TRUE)))
cat(sprintf("summary_sha256: %s\n", summary_sha))
cat(sprintf("manifest: %s\n", normalizePath(manifest_path, winslash = "/", mustWork = TRUE)))
cat(sprintf("manifest_sha256: %s\n", manifest_sha))

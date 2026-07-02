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
  utils::read.csv(normalizePath(path, winslash = "/", mustWork = TRUE), check.names = FALSE, stringsAsFactors = FALSE)
}

write_csv_stable <- function(x, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(x, path, row.names = FALSE, na = "", quote = TRUE)
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

assert_file_hash <- function(path, expected_sha256, label) {
  path <- normalizePath(path, winslash = "/", mustWork = TRUE)
  observed <- sha256_file(path)
  if (!identical(observed, expected_sha256)) {
    stop(
      sprintf(
        "%s hash mismatch:\n  path: %s\n  expected: %s\n  observed: %s",
        label, path, expected_sha256, observed
      ),
      call. = FALSE
    )
  }
  path
}

stage_stub <- "qdesn_dynamic_fitforecast_v2_tt500_mcmc_al_rhs_recalibration"
run_tag <- "qdesn-tt500-mcmc-al-rhs-recalibration-full-20260702__git-ffe3388"
campaign_stamp <- "20260702-032753__git-ffe3388"
run_stub_root <- file.path(repo_root, "reports/qdesn_mcmc_validation", stage_stub, run_tag)
report_root <- file.path(run_stub_root, campaign_stamp)
results_root <- sub("/reports/", "/results/", report_root, fixed = TRUE)

source_specs <- data.frame(
  source_id = c(
    "campaign_fit_summary", "campaign_completed", "campaign_manifest",
    "campaign_summary_manifest", "audit_summary", "audit_root",
    "audit_manifest", "preflight_manifest", "healthcheck"
  ),
  path = file.path(
    c(
      report_root, report_root, report_root, report_root, report_root,
      report_root, report_root, run_stub_root, run_stub_root
    ),
    c(
      "tables/campaign_fit_summary.csv",
      "manifest/campaign_completed.json",
      "manifest/campaign_manifest.json",
      "manifest/campaign_summary_manifest.json",
      "audit/tables/qdesn_tt500_vb_screen_audit_summary.csv",
      "audit/tables/qdesn_tt500_vb_screen_root_audit.csv",
      "audit/manifest/qdesn_tt500_vb_screen_audit_manifest.json",
      "launch/qdesn_dynamic_exdqlm_crossstudy_preflight_manifest.json",
      "launch/qdesn_dynamic_exdqlm_crossstudy_healthcheck.md"
    )
  ),
  expected_sha256 = c(
    "6c6ed171a392151cac33e90574fcd326f9ef23b91e2e0b81cfc74d23a9267585",
    "095d9dbbda4282eef0bba32baa64363cb3985202877fada95318c6a39b2c2e95",
    "837ac13f990d3a33c361a04d77b83d5aa61cae7011eeee8b18bb1b5ad83885a8",
    "a6cc6256259840a725b2336dfbb4322b89a7132e7d9be94eb1f97286c1f77d65",
    "cb9a66fabbe01d348e83e0ca4695a5044dd56a5132aeaacf33da3ace8e9382e3",
    "9d238e39412fc73e0ac30af94f77fda51d3fc73c5697f216d83ef6cc57170ad5",
    "6724ebbccdf3e91638d5be9b2e9f705cc3121e70716dd25ca00d5926f05a4026",
    "6f2764aa95097c4a11a42e1cf794d4433ea2c588d427f6872025b362e0f1b6d9",
    "4b9d273c845a9c4a97240f098ca43689483c1aaf6838e0890465479c3454f2df"
  ),
  stringsAsFactors = FALSE
)
source_specs$path <- vapply(
  seq_len(nrow(source_specs)),
  function(ii) assert_file_hash(source_specs$path[[ii]], source_specs$expected_sha256[[ii]], source_specs$source_id[[ii]]),
  character(1)
)
source_specs$observed_sha256 <- vapply(source_specs$path, sha256_file, character(1))
source_specs$hash_verified <- source_specs$observed_sha256 == source_specs$expected_sha256

fits <- read_csv_strict(source_specs$path[source_specs$source_id == "campaign_fit_summary"])
audit <- read_csv_strict(source_specs$path[source_specs$source_id == "audit_summary"])
root_audit <- read_csv_strict(source_specs$path[source_specs$source_id == "audit_root"])

if (nrow(audit) != 1L ||
    as.integer(audit$expected_roots[[1L]]) != 9L ||
    as.integer(audit$observed_roots[[1L]]) != 9L ||
    as.integer(audit$n_success[[1L]]) != 9L ||
    as.integer(audit$n_running[[1L]]) != 0L ||
    as.integer(audit$n_fail[[1L]]) != 0L ||
    as.integer(audit$n_success_lead_pass[[1L]]) != 9L ||
    as.integer(audit$n_success_rolling_pass[[1L]]) != 9L ||
    as.integer(audit$n_success_storage_light_pass[[1L]]) != 9L ||
    as.integer(audit$forbidden_binary_count_total[[1L]]) != 0L ||
    !isTRUE(as.logical(audit$strict_ready[[1L]]))) {
  stop("AL RHS MCMC recalibration audit summary is not strict-ready.", call. = FALSE)
}

if (nrow(root_audit) != 9L ||
    any(as.character(root_audit$root_status) != "SUCCESS") ||
    any(as.character(root_audit$method_status) != "SUCCESS") ||
    any(as.character(root_audit$method_dir_name) != "mcmc_al") ||
    any(as.integer(root_audit$lead_metrics_rows) != 30L) ||
    any(as.integer(root_audit$rolling_paths_rows) != 1000L) ||
    any(as.integer(root_audit$forbidden_binary_count) != 0L) ||
    any(!as.logical(root_audit$lead_metrics_pass)) ||
    any(!as.logical(root_audit$rolling_paths_pass)) ||
    any(!as.logical(root_audit$storage_light_pass))) {
  stop("AL RHS MCMC recalibration root audit violates the root-level contract.", call. = FALSE)
}

forbidden_binary_paths <- list.files(
  results_root,
  pattern = "\\.(rds|rda|RData)$",
  recursive = TRUE,
  full.names = TRUE,
  ignore.case = TRUE
)
if (length(forbidden_binary_paths)) {
  stop(
    sprintf("Forbidden binary payload(s) retained under results root: %s", paste(forbidden_binary_paths, collapse = ", ")),
    call. = FALSE
  )
}

expected_families <- c("gausmix", "laplace", "normal")
expected_tau <- c(0.05, 0.25, 0.5)
expected_keys <- as.vector(outer(expected_families, sprintf("%.8f", expected_tau), paste, sep = "\r"))
observed_keys <- paste(as.character(fits$family), sprintf("%.8f", as.numeric(fits$tau)), sep = "\r")
if (nrow(fits) != 9L ||
    !setequal(observed_keys, expected_keys) ||
    any(as.character(fits$status) != "SUCCESS") ||
    any(as.character(fits$method) != "mcmc") ||
    any(as.character(fits$inference) != "mcmc") ||
    any(as.character(fits$likelihood_family) != "al") ||
    any(as.character(fits$prior) != "rhs_ns") ||
    any(as.integer(fits$fit_size) != 500L) ||
    any(as.integer(fits$effective_fit_size) != 500L) ||
    any(!(as.character(fits$signoff_grade) %in% c("PASS", "WARN"))) ||
    any(as.character(fits$signoff_grade) == "FAIL") ||
    any(!as.logical(fits$comparison_eligible))) {
  stop("AL RHS MCMC recalibration fit summary violates the promotion contract.", call. = FALSE)
}

lead_metrics <- lapply(seq_len(nrow(fits)), function(ii) {
  path <- fits$forecast_lead_metrics_path[[ii]]
  lead <- read_csv_strict(path)
  if (nrow(lead) != 30L ||
      !identical(sort(as.integer(lead$forecast_lead)), 1:30) ||
      any(as.integer(lead$origin_stride) != 30L) ||
      any(as.integer(lead$max_lead_configured) != 30L) ||
      any(as.character(lead$forecast_protocol) != "rolling_origin_no_refit_state_update") ||
      any(as.logical(lead$refit_per_origin)) ||
      any(as.logical(lead$synthesis_enabled)) ||
      sum(as.integer(lead$n_origins_scored)) != 1000L ||
      min(as.integer(lead$origin_start_source_index)) != 9000L ||
      max(as.integer(lead$origin_end_source_index)) != 9990L ||
      min(as.integer(lead$target_start_source_index)) != 9001L ||
      max(as.integer(lead$target_end_source_index)) != 10000L ||
      any(as.character(lead$lead_export_target_scale) != "original")) {
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

promotion_id <- "qdesn_tt500_mcmc_al_rhs_recalibrated_authoritative_20260702"
diagnostic_qualification <- "diagnostic_qualified_authoritative_mcmc_al_rhs_recalibrated"

runtime_sec_total <- as.numeric(fits$total_stage_seconds %||% fits$runtime_sec)
summary <- data.frame(
  promotion_id = promotion_id,
  promotion_status = "authoritative_article_facing_diagnostic_qualified",
  diagnostic_qualification = diagnostic_qualification,
  source_selection = "mcmc_al_rhs_recalibrated_vb_winners",
  source_run_tag = run_tag,
  source_campaign_stamp = campaign_stamp,
  source_report_root = normalizePath(report_root, winslash = "/", mustWork = TRUE),
  source_results_root = normalizePath(results_root, winslash = "/", mustWork = TRUE),
  root_id = fits$root_id,
  spec_id = fits$spec_id,
  model_family = "qdesn",
  model_variant = "rhs_ns",
  model_key = "qdesn_al_rhs_ns",
  qdesn_likelihood = "al",
  inference = "mcmc",
  method = "mcmc",
  likelihood_family = "al",
  prior = "rhs_ns",
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
  fit_qtrue_mae = as.numeric(fits$train_point_qtrue_mae),
  fit_pinball_mean = as.numeric(fits$train_point_pinball_tau),
  forecast_qtrue_mae_lead_weighted = lead_metrics$forecast_qtrue_mae_lead_weighted,
  forecast_qtrue_rmse_lead_weighted = lead_metrics$forecast_qtrue_rmse_lead_weighted,
  forecast_pinball_mean_lead_weighted = lead_metrics$forecast_pinball_mean_lead_weighted,
  runtime_sec_total = runtime_sec_total,
  runtime_hours = runtime_sec_total / 3600,
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
  validation_run_commit = "ffe3388",
  package_version = package_version,
  source_registry_hash_name = "000__bundle_manifest.json.sha256",
  source_registry_hash_value = "edddb56fc2b30e49ac99fdd08b53dad468ed53e05d0fe1fe16426ee9d9ffe275",
  forecast_lead_metrics_path = lead_metrics$forecast_lead_metrics_path,
  forecast_lead_metrics_sha256 = lead_metrics$forecast_lead_metrics_sha256,
  stringsAsFactors = FALSE
)
summary <- summary[order(summary$family, summary$tau), , drop = FALSE]

out_dir <- file.path(repo_root, "validation/fitforecast_v2/promotions", promotion_id)
summary_path <- file.path(out_dir, paste0(promotion_id, "_summary.csv"))
sources_path <- file.path(out_dir, paste0(promotion_id, "_sources.csv"))
manifest_path <- file.path(out_dir, paste0(promotion_id, "_manifest.json"))
readme_path <- file.path(out_dir, "README.md")

write_csv_stable(summary, summary_path)
write_csv_stable(source_specs, sources_path)
summary_sha <- sha256_file(summary_path)
sources_sha <- sha256_file(sources_path)

manifest <- list(
  promotion_id = promotion_id,
  promotion_status = "authoritative_article_facing_diagnostic_qualified",
  diagnostic_qualification = diagnostic_qualification,
  source_selection = "mcmc_al_rhs_recalibrated_vb_winners",
  materializer = "validation/fitforecast_v2/scripts/materialize_qdesn_tt500_mcmc_al_rhs_recalibrated_handoff.R",
  validation_branch = validation_branch,
  validation_commit_at_materialization = validation_commit,
  validation_run_commit = "ffe3388",
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
    synthesis_enabled = FALSE,
    refit_per_origin = FALSE,
    n_origins_scored_total_per_row = 1000
  ),
  run_evidence = list(
    run_tag = run_tag,
    campaign_stamp = campaign_stamp,
    report_root = normalizePath(report_root, winslash = "/", mustWork = TRUE),
    results_root = normalizePath(results_root, winslash = "/", mustWork = TRUE),
    audit_expected_roots = as.integer(audit$expected_roots[[1L]]),
    audit_observed_roots = as.integer(audit$observed_roots[[1L]]),
    audit_success = as.integer(audit$n_success[[1L]]),
    audit_fail = as.integer(audit$n_fail[[1L]]),
    audit_running = as.integer(audit$n_running[[1L]]),
    strict_ready = isTRUE(as.logical(audit$strict_ready[[1L]])),
    forbidden_binary_count_total = as.integer(audit$forbidden_binary_count_total[[1L]])
  ),
  selected_rows = nrow(summary),
  signoff_counts = as.list(table(summary$signoff_grade)),
  accepted_signoff_grades = c("PASS", "WARN"),
  storage_policy = list(
    storage_light_pass = TRUE,
    forbidden_binary_count = length(forbidden_binary_paths),
    routine_success_payload_retention = "no .rds/.rda/.RData payload retention under results root"
  ),
  artifacts = list(
    summary_csv = list(path = normalizePath(summary_path, winslash = "/", mustWork = TRUE), sha256 = summary_sha),
    sources_csv = list(path = normalizePath(sources_path, winslash = "/", mustWork = TRUE), sha256 = sources_sha)
  ),
  source_files = source_specs[, c("source_id", "path", "observed_sha256", "hash_verified")]
)
jsonlite::write_json(manifest, manifest_path, auto_unbox = TRUE, pretty = TRUE, dataframe = "rows")
manifest_sha <- sha256_file(manifest_path)

readme_lines <- c(
  "# Q-DESN TT500 MCMC AL RHS Recalibrated Authoritative Handoff",
  "",
  "This directory materializes the July 2, 2026 Q-DESN AL RHS MCMC recalibration run as the article-facing TT500 AL RHS MCMC handoff.",
  "",
  "Promotion status: `authoritative_article_facing_diagnostic_qualified`.",
  sprintf("Diagnostic qualification: `%s`.", diagnostic_qualification),
  "",
  "The source run completed all nine family/quantile cells. One row is `PASS`; eight rows are `WARN` with `chain_marginal_but_usable`. The warnings are preserved in the summary rather than hidden.",
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

cat("Q-DESN TT500 MCMC AL RHS recalibrated authoritative handoff materialized: PASS\n")
cat(sprintf("summary: %s\n", normalizePath(summary_path, winslash = "/", mustWork = TRUE)))
cat(sprintf("summary_sha256: %s\n", summary_sha))
cat(sprintf("manifest: %s\n", normalizePath(manifest_path, winslash = "/", mustWork = TRUE)))
cat(sprintf("manifest_sha256: %s\n", manifest_sha))

#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  required <- c("jsonlite", "yaml")
  missing <- setdiff(required, rownames(installed.packages()))
  if (length(missing)) {
    stop(sprintf("Missing required package(s): %s", paste(missing, collapse = ", ")), call. = FALSE)
  }
})

args <- commandArgs(trailingOnly = TRUE)
get_arg <- function(flag, default = NULL) {
  index <- which(args == flag)
  if (!length(index) || index[[1L]] >= length(args)) return(default)
  args[[index[[1L]] + 1L]]
}
`%||%` <- function(a, b) if (is.null(a) || !length(a)) b else a

repo_root <- normalizePath(
  system("git rev-parse --show-toplevel", intern = TRUE),
  winslash = "/",
  mustWork = TRUE
)
setwd(repo_root)
resolve_path <- function(path, must_work = TRUE) {
  path <- as.character(path %||% "")[1L]
  if (!nzchar(trimws(path))) return(NULL)
  if (!grepl("^(/|~)", path)) path <- file.path(repo_root, path)
  normalizePath(path, winslash = "/", mustWork = isTRUE(must_work))
}
read_csv <- function(path) {
  utils::read.csv(resolve_path(path), check.names = FALSE, stringsAsFactors = FALSE)
}
write_csv <- function(value, path) {
  path <- resolve_path(path, must_work = FALSE)
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(value, path, row.names = FALSE, na = "")
  normalizePath(path, winslash = "/", mustWork = TRUE)
}
write_json <- function(value, path) {
  path <- resolve_path(path, must_work = FALSE)
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  jsonlite::write_json(
    value,
    path,
    pretty = TRUE,
    auto_unbox = TRUE,
    null = "null",
    digits = NA
  )
  normalizePath(path, winslash = "/", mustWork = TRUE)
}
sha256_file <- function(path) unname(tools::sha256sum(resolve_path(path)))
num <- function(x) suppressWarnings(as.numeric(x))
as_bool <- function(x) {
  if (is.logical(x)) return(x)
  toupper(trimws(as.character(x))) %in% c("TRUE", "T", "1", "YES")
}
resolve_campaign_root <- function(run_root, child) {
  run_root <- resolve_path(run_root, must_work = FALSE)
  if (!dir.exists(run_root)) return(run_root)
  if (dir.exists(file.path(run_root, child))) return(run_root)
  children <- sort(list.dirs(run_root, recursive = FALSE, full.names = TRUE), decreasing = TRUE)
  for (candidate in children) {
    if (dir.exists(file.path(candidate, child))) return(candidate)
  }
  run_root
}

stage <- "qdesn_dynamic_fitforecast_v2_tt500_mcmc_external_coherent_confirmation_v1"
expected_spec_id <- "qdesn__laplace__0p25__tt500__rhs_ns__mcmc__exal__020293d289bcb0"
expected_root_id <- paste0(
  "root__dynamic__dlm_constV_p90_m0amp_highnoise_steepertrend_v2_TTmain10000_fitforecast",
  "__laplace__tau_0p25__lasttt_500__qdesn_rhs_ns__profile_mgv3_16_exal_local"
)
run_tag <- as.character(get_arg("--run-tag", ""))[1L]
if (!nzchar(trimws(run_tag))) stop("--run-tag is required.", call. = FALSE)
stamp <- as.character(get_arg("--stamp", format(Sys.Date(), "%Y%m%d")))[1L]
defaults_path <- resolve_path(file.path("config", "validation", paste0(stage, "_defaults.yaml")))
grid_path <- resolve_path(file.path("config", "validation", paste0(stage, "_grid.csv")))
defaults <- yaml::read_yaml(defaults_path)
grid <- read_csv(grid_path)
if (nrow(grid) != 1L || grid$root_id[[1L]] != expected_root_id) {
  stop("Confirmation grid is not the one exact expected root.", call. = FALSE)
}
prelaunch_root <- resolve_path(file.path(
  "validation", "fitforecast_v2", "promotions",
  "qdesn_tt500_mcmc_external_coherent_confirmation_v1_prelaunch_20260727"
))
screening_candidate_path <- file.path(prelaunch_root, "selected_coherent_external_candidate.csv")
benchmark_contract_path <- file.path(prelaunch_root, "external_confirmation_contract.csv")
screen <- read_csv(screening_candidate_path)
contract <- read_csv(benchmark_contract_path)

outer_results_root <- file.path(repo_root, defaults$campaign$results_root, run_tag)
outer_report_root <- file.path(repo_root, defaults$campaign$reports_root, run_tag)
results_root <- resolve_campaign_root(outer_results_root, "roots")
report_root <- resolve_campaign_root(outer_report_root, "tables")
progress_path <- file.path(report_root, "tables", "campaign_progress.csv")
fit_path <- file.path(report_root, "tables", "campaign_fit_summary.csv")
completed_path <- file.path(report_root, "manifest", "campaign_completed.json")
progress <- read_csv(progress_path)
fit <- read_csv(fit_path)
completed <- jsonlite::read_json(completed_path, simplifyVector = TRUE)

if (nrow(progress) != 1L ||
    progress$root_id[[1L]] != expected_root_id ||
    progress$root_status[[1L]] != "SUCCESS" ||
    nrow(fit) != 1L ||
    fit$root_id[[1L]] != expected_root_id ||
    fit$spec_id[[1L]] != expected_spec_id ||
    as.integer(completed$n_roots) != 1L ||
    as.integer(completed$n_fits) != 1L) {
  stop("Confirmation campaign is not one exact completed successful root and fit.", call. = FALSE)
}

horizon_path <- sub(
  "forecast_lead_metrics[.]csv$",
  "forecast_horizon_summary.csv",
  as.character(fit$forecast_lead_metrics_path[[1L]])
)
horizon <- read_csv(horizon_path)
h1000 <- horizon[num(horizon$horizon) == 1000, , drop = FALSE]
if (nrow(h1000) != 1L) stop("Confirmation is missing one H=1000 forecast summary.", call. = FALSE)

root_manifest_path <- file.path(results_root, "roots", expected_root_id, "manifest", "root_manifest.json")
root_manifest <- jsonlite::read_json(root_manifest_path, simplifyVector = TRUE)
fit_request_path <- file.path(
  results_root, "roots", expected_root_id, "fits", "mcmc_exal", "fit_request.json"
)
fit_request <- jsonlite::read_json(fit_request_path, simplifyVector = TRUE)
window_ok <- identical(as.integer(root_manifest$train_start_source_index), 8501L) &&
  identical(as.integer(root_manifest$train_end_source_index), 9000L) &&
  identical(as.integer(root_manifest$forecast_start_source_index), 9001L) &&
  identical(as.integer(root_manifest$forecast_end_source_index), 10000L)

metrics <- data.frame(
  metric = contract$metric,
  confirmation_value = c(
    num(fit$train_qtrue_rmse[[1L]]),
    num(h1000$qtrue_mae[[1L]]),
    num(h1000$pinball_tau[[1L]])
  ),
  screening_value = num(contract$screening_value),
  internal_mixed_envelope = num(contract$internal_mixed_envelope),
  external_best = num(contract$external_best),
  stringsAsFactors = FALSE
)
metrics$ratio_to_screening <- metrics$confirmation_value / metrics$screening_value
metrics$ratio_to_internal_mixed_envelope <- metrics$confirmation_value /
  metrics$internal_mixed_envelope
metrics$ratio_to_external_best <- metrics$confirmation_value / metrics$external_best
metrics$external_gate <- metrics$ratio_to_external_best <= 1.05
metrics$screening_stability_gate <- metrics$ratio_to_screening <= 1.10
metrics$finite_gate <- is.finite(metrics$confirmation_value)

source_hash <- unique(as.character(screen$source_registry_hash_value))
fit_source_hash <- as.character(
  root_manifest$study_contract$confirmation_contract$source_registry_hash
)
source_hash_ok <- length(source_hash) == 1L &&
  length(fit_source_hash) == 1L &&
  identical(source_hash, fit_source_hash)

source_file_contract <- data.frame(
  role = c("series_wide", "selection_indices", "sim_output"),
  expected_path = c(
    as.character(grid$source_series_wide_path[[1L]]),
    as.character(grid$source_selection_indices_path[[1L]]),
    as.character(grid$source_sim_path[[1L]])
  ),
  expected_sha256 = c(
    as.character(grid$source_series_wide_sha256[[1L]]),
    as.character(grid$source_selection_indices_sha256[[1L]]),
    as.character(grid$source_sim_sha256[[1L]])
  ),
  request_path = c(
    as.character(fit_request$root_spec$source_series_wide_path),
    as.character(fit_request$root_spec$source_selection_indices_path),
    as.character(fit_request$root_spec$source_sim_path)
  ),
  request_sha256 = c(
    as.character(fit_request$root_spec$source_series_wide_sha256),
    as.character(fit_request$root_spec$source_selection_indices_sha256),
    as.character(fit_request$root_spec$source_sim_sha256)
  ),
  stringsAsFactors = FALSE
)
source_file_contract$path_contract_ok <- source_file_contract$expected_path ==
  source_file_contract$request_path
source_file_contract$recorded_hash_ok <- source_file_contract$expected_sha256 ==
  source_file_contract$request_sha256
source_file_contract$file_exists <- file.exists(source_file_contract$expected_path)
source_file_contract$observed_sha256 <- vapply(
  source_file_contract$expected_path,
  function(path) if (file.exists(path)) sha256_file(path) else NA_character_,
  character(1L)
)
source_file_contract$on_disk_hash_ok <- source_file_contract$expected_sha256 ==
  source_file_contract$observed_sha256
source_file_hashes_ok <- all(source_file_contract$path_contract_ok) &&
  all(source_file_contract$recorded_hash_ok) &&
  all(source_file_contract$file_exists) &&
  all(source_file_contract$on_disk_hash_ok)

all_files <- list.files(results_root, recursive = TRUE, full.names = TRUE)
heavy <- all_files[grepl("[.](rds|rda|RData)$", all_files, ignore.case = TRUE)]
storage <- if (length(heavy)) {
  info <- file.info(heavy)
  data.frame(
    path = normalizePath(heavy, winslash = "/", mustWork = TRUE),
    bytes = as.numeric(info$size),
    disposition = "unexpected_confirmation_payload",
    stringsAsFactors = FALSE
  )
} else {
  data.frame(path = character(), bytes = numeric(), disposition = character())
}

execution_ok <- fit$status[[1L]] == "SUCCESS" &&
  as_bool(fit$finite_ok[[1L]]) &&
  as_bool(fit$domain_ok[[1L]])
metric_gate <- all(metrics$finite_gate) &&
  all(metrics$external_gate) &&
  all(metrics$screening_stability_gate)
storage_ok <- nrow(storage) == 0L
confirmation_pass <- execution_ok &&
  metric_gate &&
  source_hash_ok &&
  source_file_hashes_ok &&
  window_ok &&
  storage_ok
decision <- if (confirmation_pass) {
  "ELIGIBLE_FOR_SCIENTIFIC_PROMOTION_PENDING_ARTICLE_REVIEW"
} else {
  "HOLD_CONFIRMATION_FAILED_ONE_OR_MORE_GATES"
}

out_root <- resolve_path(
  get_arg(
    "--out-root",
    file.path(
      "validation", "fitforecast_v2", "promotions",
      paste0("qdesn_tt500_mcmc_external_coherent_confirmation_v1_closeout_", stamp)
    )
  ),
  must_work = FALSE
)
dir.create(out_root, recursive = TRUE, showWarnings = FALSE)
metrics_path <- write_csv(metrics, file.path(out_root, "confirmation_metric_comparison.csv"))
storage_path <- write_csv(storage, file.path(out_root, "storage_audit.csv"))
source_file_contract_path <- write_csv(
  source_file_contract,
  file.path(out_root, "source_file_hash_audit.csv")
)
result_row <- fit
result_row$forecast_qtrue_mae_H1000 <- num(h1000$qtrue_mae[[1L]])
result_row$forecast_check_loss_H1000 <- num(h1000$pinball_tau[[1L]])
result_row$confirmation_decision <- decision
result_path <- write_csv(result_row, file.path(out_root, "confirmed_candidate.csv"))
summary <- data.frame(
  run_tag = run_tag,
  root_id = expected_root_id,
  spec_id = expected_spec_id,
  execution_ok = execution_ok,
  source_hash_ok = source_hash_ok,
  source_file_hashes_ok = source_file_hashes_ok,
  source_window_ok = window_ok,
  storage_light_ok = storage_ok,
  all_external_metrics_within_1p05 = all(metrics$external_gate),
  all_metrics_stable_within_1p10 = all(metrics$screening_stability_gate),
  signoff_grade = as.character(fit$signoff_grade[[1L]]),
  signoff_reason = as.character(fit$signoff_reason[[1L]]),
  decision = decision,
  article_updated = FALSE,
  stringsAsFactors = FALSE
)
summary_path <- write_csv(summary, file.path(out_root, "confirmation_summary.csv"))

source_files <- c(
  defaults = defaults_path,
  grid = grid_path,
  screening_candidate = screening_candidate_path,
  benchmark_contract = benchmark_contract_path,
  progress = progress_path,
  fit = fit_path,
  completed = completed_path,
  h1000 = horizon_path,
  root_manifest = root_manifest_path,
  fit_request = fit_request_path
)
source_manifest <- data.frame(
  role = names(source_files),
  path = vapply(source_files, resolve_path, character(1L)),
  sha256 = vapply(source_files, sha256_file, character(1L)),
  stringsAsFactors = FALSE
)
source_manifest_path <- write_csv(source_manifest, file.path(out_root, "source_manifest.csv"))
output_files <- c(
  metrics = metrics_path,
  result = result_path,
  summary = summary_path,
  storage = storage_path,
  source_file_hash_audit = source_file_contract_path,
  source_manifest = source_manifest_path
)
file_manifest <- data.frame(
  role = names(output_files),
  path = unname(output_files),
  sha256 = vapply(output_files, sha256_file, character(1L)),
  stringsAsFactors = FALSE
)
file_manifest_path <- write_csv(file_manifest, file.path(out_root, "file_manifest.csv"))
manifest <- list(
  generated_at = as.character(Sys.time()),
  run_tag = run_tag,
  stage = stage,
  git_branch = trimws(system("git branch --show-current", intern = TRUE)),
  git_commit = trimws(system("git rev-parse HEAD", intern = TRUE)),
  results_root = results_root,
  report_root = report_root,
  source_registry_hash = source_hash,
  gates = as.list(summary[1L, , drop = FALSE]),
  decision = decision,
  article_gate = if (confirmation_pass) {
    "manual_article_review_required"
  } else {
    "closed"
  },
  source_manifest = source_manifest,
  file_manifest_path = file_manifest_path
)
manifest_path <- write_json(manifest, file.path(out_root, "confirmation_manifest.json"))

cat(sprintf("run_tag: %s\n", run_tag))
cat(sprintf("decision: %s\n", decision))
cat(sprintf("external_gate: %s\n", all(metrics$external_gate)))
cat(sprintf("screening_stability_gate: %s\n", all(metrics$screening_stability_gate)))
cat(sprintf("source_file_hashes_ok: %s\n", source_file_hashes_ok))
cat(sprintf("storage_light_ok: %s\n", storage_ok))
cat(sprintf("manifest: %s\n", manifest_path))

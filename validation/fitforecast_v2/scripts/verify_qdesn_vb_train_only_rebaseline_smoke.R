#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  if (!requireNamespace("jsonlite", quietly = TRUE)) stop("Package `jsonlite` is required.")
})
args <- commandArgs(trailingOnly = TRUE)
get_arg <- function(flag, default = NULL) {
  index <- which(args == flag)
  if (!length(index) || index[[1L]] >= length(args)) return(default)
  args[[index[[1L]] + 1L]]
}
`%||%` <- function(x, y) if (is.null(x) || !length(x)) y else x
as_bool <- function(x) {
  if (is.logical(x)) return(x)
  toupper(trimws(as.character(x))) %in% c("TRUE", "T", "YES", "Y", "1")
}
repo_root <- normalizePath(system("git rev-parse --show-toplevel", intern = TRUE),
                           winslash = "/", mustWork = TRUE)
setwd(repo_root)
resolve_path <- function(path, must_work = TRUE) {
  if (!grepl("^/", path)) path <- file.path(repo_root, path)
  normalizePath(path, winslash = "/", mustWork = isTRUE(must_work))
}
read_csv <- function(path) utils::read.csv(resolve_path(path), check.names = FALSE,
                                            stringsAsFactors = FALSE)
write_csv <- function(value, path) {
  path <- resolve_path(path, FALSE)
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(value, path, row.names = FALSE, na = "")
  path
}

stage <- "qdesn_dynamic_fitforecast_v2_500obs_vb_trainonly_rebaseline_v1"
stub <- file.path("config", "validation", stage)
run_tag <- as.character(get_arg("--run-tag", ""))[1L]
if (!nzchar(run_tag)) stop("--run-tag is required.", call. = FALSE)
output_root <- resolve_path(get_arg("--output-root",
  file.path("reports", "shared_fitforecast_v2_orchestration", "vb_trainonly_smoke_audit")),
  FALSE)
dir.create(output_root, recursive = TRUE, showWarnings = FALSE)
targets <- read_csv(paste0(stub, "_smoke_target_spec_ids.csv"))
grid <- read_csv(paste0(stub, "_smoke_grid.csv"))
materialization <- jsonlite::read_json(
  resolve_path(paste0(stub, "_materialization_manifest.json")), simplifyVector = TRUE
)
expected_hash <- as.character(materialization$source_registry_hash_value)
expected_preproc_hash <- as.character(
  materialization$preprocessing$preprocessing_fit_row_indices_sha256
)
run_root <- resolve_path(file.path(
  "results", "qdesn_mcmc_validation", paste0(stage, "_smoke"), run_tag
), FALSE)
if (!dir.exists(run_root)) stop(sprintf("Smoke run root is missing: %s", run_root), call. = FALSE)
requests <- list.files(run_root, pattern = "^fit_request[.]json$", recursive = TRUE,
                       full.names = TRUE)
rows <- lapply(requests, function(path) {
  request <- jsonlite::read_json(path, simplifyVector = TRUE)
  method_dir <- dirname(path)
  summary_path <- file.path(method_dir, "fit_summary_row.csv")
  horizon_path <- file.path(method_dir, "tables", "forecast_horizon_summary.csv")
  manifest_path <- file.path(method_dir, "manifest", "run_manifest.json")
  summary <- if (file.exists(summary_path)) utils::read.csv(summary_path, check.names = FALSE) else data.frame()
  horizon <- if (file.exists(horizon_path)) utils::read.csv(horizon_path, check.names = FALSE) else data.frame()
  manifest <- if (file.exists(manifest_path)) jsonlite::read_json(manifest_path, simplifyVector = TRUE) else list()
  preprocessing <- manifest$preprocessing %||% list()
  root <- request$root_spec %||% list()
  h100 <- horizon[as.integer(horizon$horizon) == 100L, , drop = FALSE]
  h1000 <- horizon[as.integer(horizon$horizon) == 1000L, , drop = FALSE]
  data.frame(
    spec_id = as.character(request$spec_id %||% NA_character_),
    root_id = as.character(root$root_id %||% NA_character_),
    likelihood_family = as.character(root$likelihood_family %||% NA_character_),
    fit_summary_present = nrow(summary) == 1L,
    horizons_present = nrow(h100) == 1L && nrow(h1000) == 1L,
    metrics_finite = nrow(summary) == 1L && nrow(h100) == 1L && nrow(h1000) == 1L &&
      all(is.finite(c(as.numeric(summary$train_qtrue_rmse[[1L]]),
                      as.numeric(h100$qtrue_mae[[1L]]), as.numeric(h100$pinball_tau[[1L]]),
                      as.numeric(h1000$qtrue_mae[[1L]]), as.numeric(h1000$pinball_tau[[1L]])))),
    preprocessing_scope = as.character(preprocessing$scope %||% NA_character_),
    fit_row_start = as.integer(preprocessing$fit_row_start %||% NA_integer_),
    fit_row_end = as.integer(preprocessing$fit_row_end %||% NA_integer_),
    fit_row_count = as.integer(preprocessing$fit_row_count %||% NA_integer_),
    fit_row_hash = as.character(preprocessing$fit_row_indices_sha256 %||% NA_character_),
    heldout_y = as_bool(preprocessing$heldout_response_used_for_scaling %||% NA),
    heldout_x = as_bool(preprocessing$heldout_covariates_used_for_scaling %||% NA),
    source_hash = as.character(request$study_contract$source_registry_hash_value %||%
                                 root$source_registry_hash_value %||% NA_character_),
    train_start = as.integer(root$train_start_source_index %||% NA_integer_),
    train_end = as.integer(root$train_end_source_index %||% NA_integer_),
    forecast_start = as.integer(root$forecast_start_source_index %||% NA_integer_),
    forecast_end = as.integer(root$forecast_end_source_index %||% NA_integer_),
    vb_max_iter = as.integer(request$config$inference$vb$max_iter %||% NA_integer_),
    vb_min_iter = as.integer(request$config$inference$vb$min_iter_elbo %||% NA_integer_),
    vb_n_samp_xi = as.integer(request$config$inference$vb$n_samp_xi %||% NA_integer_),
    observed_seed = as.integer(root$seed %||% NA_integer_),
    observed_desn_seed = as.integer(request$config$desn$seed %||% NA_integer_),
    observed_synthesis_seed = as.integer(request$config$synthesis$seed %||% NA_integer_),
    stringsAsFactors = FALSE
  )
})
observed <- if (length(rows)) do.call(rbind, rows) else data.frame()
expected <- grid[, c("root_id", "seed", "desn_seed", "synthesis_seed")]
names(expected)[-1L] <- paste0("expected_", names(expected)[-1L])
audit <- merge(observed, expected, by = "root_id", all = TRUE, sort = FALSE)
if (nrow(audit)) {
  audit$seed_match <- with(audit, observed_seed == expected_seed &
    observed_desn_seed == expected_desn_seed &
    observed_synthesis_seed == expected_synthesis_seed)
  audit$preprocessing_match <- with(audit, preprocessing_scope == "train_only" &
    fit_row_start == 1L & fit_row_end == 890L & fit_row_count == 890L &
    fit_row_hash == expected_preproc_hash & !heldout_y & !heldout_x)
  audit$source_match <- with(audit, source_hash == expected_hash &
    train_start == 8501L & train_end == 9000L &
    forecast_start == 9001L & forecast_end == 10000L)
  audit$budget_match <- with(audit, vb_max_iter == 5L & vb_min_iter == 2L & vb_n_samp_xi == 20L)
}
binaries <- list.files(run_root, pattern = "[.](rds|rda|RData)$", recursive = TRUE,
                       full.names = TRUE, ignore.case = TRUE)
pass <- nrow(audit) == 2L && setequal(targets$spec_id, observed$spec_id) &&
  all(audit$fit_summary_present) && all(audit$horizons_present) &&
  all(audit$metrics_finite) && all(audit$seed_match) &&
  all(audit$preprocessing_match) && all(audit$source_match) &&
  all(audit$budget_match) && !length(binaries)
audit_path <- write_csv(audit, file.path(output_root, "smoke_execution_audit.csv"))
jsonlite::write_json(list(
  generated_at = as.character(Sys.time()), run_tag = run_tag,
  expected_specs = 2L, observed_requests = nrow(observed),
  binary_payloads = length(binaries), audit_path = audit_path,
  decision = if (pass) "PASS" else "FAIL"
), file.path(output_root, "smoke_gate.json"), pretty = TRUE, auto_unbox = TRUE,
null = "null")
cat(sprintf("VB train-only smoke: %s (%d/2 requests; %d binaries)\n",
            if (pass) "PASS" else "FAIL", nrow(observed), length(binaries)))
if (!pass) stop("VB train-only rebaseline smoke failed.", call. = FALSE)

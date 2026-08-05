#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  if (!requireNamespace("jsonlite", quietly = TRUE)) {
    stop("Package `jsonlite` is required.", call. = FALSE)
  }
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

repo_root <- normalizePath(
  system("git rev-parse --show-toplevel", intern = TRUE),
  winslash = "/",
  mustWork = TRUE
)
setwd(repo_root)
resolve_path <- function(path, must_work = TRUE) {
  path <- as.character(path)[1L]
  if (!grepl("^/", path)) path <- file.path(repo_root, path)
  normalizePath(path, winslash = "/", mustWork = isTRUE(must_work))
}
read_csv <- function(path) {
  utils::read.csv(resolve_path(path), check.names = FALSE, stringsAsFactors = FALSE)
}
write_csv <- function(value, path) {
  path <- resolve_path(path, FALSE)
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(value, path, row.names = FALSE, na = "")
  path
}

stage <- "qdesn_dynamic_fitforecast_v2_500obs_trainonly_rebaseline_v1"
stub <- file.path("config", "validation", stage)
run_tag <- as.character(get_arg("--run-tag", ""))[1L]
if (!nzchar(run_tag)) stop("--run-tag is required.", call. = FALSE)
output_root <- resolve_path(get_arg(
  "--output-root",
  file.path("reports", "shared_fitforecast_v2_orchestration", "trainonly_smoke_audit")
), FALSE)
dir.create(output_root, recursive = TRUE, showWarnings = FALSE)

targets <- read_csv(paste0(stub, "_smoke_target_spec_ids.csv"))
grid <- read_csv(paste0(stub, "_smoke_grid.csv"))
materialization <- jsonlite::read_json(
  resolve_path(paste0(stub, "_materialization_manifest.json")),
  simplifyVector = TRUE
)
expected_hash <- as.character(materialization$source_registry_hash_value)
expected_preproc_hash <- as.character(
  materialization$preprocessing$preprocessing_fit_row_indices_sha256
)
if (nrow(targets) != 2L || nrow(grid) != 2L ||
    !setequal(targets$likelihood_family, c("al", "exal"))) {
  stop("Smoke configuration is not the frozen two-root AL/exAL contract.", call. = FALSE)
}

run_root <- resolve_path(file.path(
  "results", "qdesn_mcmc_validation", paste0(stage, "_smoke"), run_tag
), FALSE)
if (!dir.exists(run_root)) stop(sprintf("Smoke run root is missing: %s", run_root), call. = FALSE)
requests <- list.files(
  run_root, pattern = "^fit_request[.]json$", recursive = TRUE, full.names = TRUE
)

rows <- lapply(requests, function(path) {
  request <- jsonlite::read_json(path, simplifyVector = TRUE)
  method_dir <- dirname(path)
  summary_path <- file.path(method_dir, "fit_summary_row.csv")
  horizon_path <- file.path(method_dir, "tables", "forecast_horizon_summary.csv")
  manifest_path <- file.path(method_dir, "manifest", "run_manifest.json")
  summary <- if (file.exists(summary_path)) {
    utils::read.csv(summary_path, check.names = FALSE, stringsAsFactors = FALSE)
  } else data.frame()
  horizon <- if (file.exists(horizon_path)) {
    utils::read.csv(horizon_path, check.names = FALSE, stringsAsFactors = FALSE)
  } else data.frame()
  run_manifest <- if (file.exists(manifest_path)) {
    jsonlite::read_json(manifest_path, simplifyVector = TRUE)
  } else list()
  preprocessing <- run_manifest$preprocessing %||% list()
  h100 <- horizon[as.integer(horizon$horizon) == 100L, , drop = FALSE]
  h1000 <- horizon[as.integer(horizon$horizon) == 1000L, , drop = FALSE]
  root <- request$root_spec %||% list()
  data.frame(
    spec_id = as.character(request$spec_id %||% NA_character_),
    root_id = as.character(root$root_id %||% NA_character_),
    screening_profile_id = as.character(root$screening_profile_id %||% NA_character_),
    family = as.character(root$source_family %||% NA_character_),
    tau = as.numeric(root$tau %||% NA_real_),
    likelihood_family = as.character(root$likelihood_family %||% NA_character_),
    fit_summary_present = nrow(summary) == 1L,
    horizon_h100_present = nrow(h100) == 1L,
    horizon_h1000_present = nrow(h1000) == 1L,
    metric_values_finite = nrow(summary) == 1L && nrow(h100) == 1L && nrow(h1000) == 1L &&
      all(is.finite(c(
        as.numeric(summary$train_qtrue_rmse[[1L]]),
        as.numeric(h100$qtrue_mae[[1L]]),
        as.numeric(h100$pinball_tau[[1L]]),
        as.numeric(h1000$qtrue_mae[[1L]]),
        as.numeric(h1000$pinball_tau[[1L]])
      ))),
    preprocessing_scope = as.character(preprocessing$scope %||% NA_character_),
    preprocessing_fit_row_start = as.integer(preprocessing$fit_row_start %||% NA_integer_),
    preprocessing_fit_row_end = as.integer(preprocessing$fit_row_end %||% NA_integer_),
    preprocessing_fit_row_count = as.integer(preprocessing$fit_row_count %||% NA_integer_),
    preprocessing_fit_row_indices_sha256 = as.character(
      preprocessing$fit_row_indices_sha256 %||% NA_character_
    ),
    heldout_response_used = as_bool(
      preprocessing$heldout_response_used_for_scaling %||% NA
    ),
    heldout_covariates_used = as_bool(
      preprocessing$heldout_covariates_used_for_scaling %||% NA
    ),
    source_registry_hash = as.character(
      root$source_registry_hash_value %||% expected_hash
    ),
    train_start_source_index = as.integer(root$train_start_source_index %||% NA_integer_),
    train_end_source_index = as.integer(root$train_end_source_index %||% NA_integer_),
    forecast_start_source_index = as.integer(root$forecast_start_source_index %||% NA_integer_),
    forecast_end_source_index = as.integer(root$forecast_end_source_index %||% NA_integer_),
    mcmc_n_burn = as.integer(request$config$inference$mcmc$n_burn %||% NA_integer_),
    mcmc_n_mcmc = as.integer(request$config$inference$mcmc$n_mcmc %||% NA_integer_),
    observed_desn_seed = as.integer(request$config$desn$seed %||% NA_integer_),
    observed_mcmc_seed = as.integer(
      request$config$inference$mcmc$control$seed %||% NA_integer_
    ),
    observed_mcmc_rng_seed = as.integer(
      request$config$inference$mcmc$control$rng_seed %||% NA_integer_
    ),
    observed_vb_warm_start_seed = as.integer(
      request$config$inference$mcmc$vb_warm_start_seed %||% NA_integer_
    ),
    observed_synthesis_seed = as.integer(request$config$synthesis$seed %||% NA_integer_),
    request_path = normalizePath(path, winslash = "/", mustWork = TRUE),
    stringsAsFactors = FALSE
  )
})
observed <- if (length(rows)) do.call(rbind, rows) else data.frame()

expected <- grid[, c(
  "root_id", "screening_profile_id", "desn_seed", "mcmc_seed",
  "mcmc_rng_seed", "vb_warm_start_seed", "synthesis_seed"
), drop = FALSE]
names(expected)[-(1:2)] <- paste0("expected_", names(expected)[-(1:2)])
audit <- merge(
  observed, expected, by = c("root_id", "screening_profile_id"),
  all = TRUE, sort = FALSE
)
if (nrow(audit)) {
  audit$seed_contract_match <- with(audit,
    observed_desn_seed == expected_desn_seed &
      observed_mcmc_seed == expected_mcmc_seed &
      observed_mcmc_rng_seed == expected_mcmc_rng_seed &
      observed_vb_warm_start_seed == expected_vb_warm_start_seed &
      observed_synthesis_seed == expected_synthesis_seed
  )
  audit$preprocessing_contract_match <- with(audit,
    preprocessing_scope == "train_only" &
      preprocessing_fit_row_start == 1L &
      preprocessing_fit_row_end == 890L &
      preprocessing_fit_row_count == 890L &
      preprocessing_fit_row_indices_sha256 == expected_preproc_hash &
      !heldout_response_used & !heldout_covariates_used
  )
  audit$source_contract_match <- with(audit,
    source_registry_hash == expected_hash &
      train_start_source_index == 8501L & train_end_source_index == 9000L &
      forecast_start_source_index == 9001L & forecast_end_source_index == 10000L
  )
  audit$budget_contract_match <- with(audit, mcmc_n_burn == 4L & mcmc_n_mcmc == 4L)
}

binaries <- list.files(
  run_root, pattern = "[.](rds|rda|RData)$", recursive = TRUE,
  full.names = TRUE, ignore.case = TRUE
)
expected_ids <- unique(as.character(targets$spec_id))
observed_ids <- if (nrow(observed)) unique(as.character(observed$spec_id)) else character()
pass <- nrow(audit) == 2L && setequal(expected_ids, observed_ids) &&
  all(audit$fit_summary_present %in% TRUE) &&
  all(audit$horizon_h100_present %in% TRUE) &&
  all(audit$horizon_h1000_present %in% TRUE) &&
  all(audit$metric_values_finite %in% TRUE) &&
  all(audit$seed_contract_match %in% TRUE) &&
  all(audit$preprocessing_contract_match %in% TRUE) &&
  all(audit$source_contract_match %in% TRUE) &&
  all(audit$budget_contract_match %in% TRUE) && !length(binaries)

audit_path <- write_csv(audit, file.path(output_root, "smoke_execution_audit.csv"))
gate_path <- file.path(output_root, "smoke_gate.json")
jsonlite::write_json(list(
  generated_at = as.character(Sys.time()),
  run_tag = run_tag,
  expected_specs = 2L,
  observed_requests = nrow(observed),
  observed_complete_metrics = if (nrow(audit)) sum(audit$metric_values_finite %in% TRUE) else 0L,
  train_only_provenance_passes = if (nrow(audit)) {
    sum(audit$preprocessing_contract_match %in% TRUE)
  } else 0L,
  source_contract_passes = if (nrow(audit)) sum(audit$source_contract_match %in% TRUE) else 0L,
  seed_contract_passes = if (nrow(audit)) sum(audit$seed_contract_match %in% TRUE) else 0L,
  binary_payloads = length(binaries),
  audit_path = audit_path,
  decision = if (pass) "PASS" else "FAIL"
), gate_path, pretty = TRUE, auto_unbox = TRUE, null = "null")
cat(sprintf(
  "train-only smoke: %s (%d/2 requests; %d/2 complete metrics; %d binaries)\n",
  if (pass) "PASS" else "FAIL",
  nrow(observed),
  if (nrow(audit)) sum(audit$metric_values_finite %in% TRUE) else 0L,
  length(binaries)
))
if (!pass) stop("Train-only rebaseline smoke failed.", call. = FALSE)

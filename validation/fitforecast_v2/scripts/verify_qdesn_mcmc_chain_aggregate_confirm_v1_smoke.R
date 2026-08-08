#!/usr/bin/env Rscript

suppressPackageStartupMessages(requireNamespace("jsonlite", quietly = TRUE))

args <- commandArgs(trailingOnly = TRUE)
get_arg <- function(flag, default = NULL) {
  index <- which(args == flag)
  if (!length(index) || index[[1L]] >= length(args)) return(default)
  args[[index[[1L]] + 1L]]
}
`%||%` <- function(x, y) if (is.null(x) || !length(x)) y else x
repo_root <- normalizePath(
  system("git rev-parse --show-toplevel", intern = TRUE),
  winslash = "/", mustWork = TRUE
)
setwd(repo_root)
read_csv <- function(path) {
  utils::read.csv(path, check.names = FALSE, stringsAsFactors = FALSE)
}
stage <- "qdesn_dynamic_fitforecast_v2_500obs_mcmc_chain_aggregate_confirm_v1"
stub <- file.path("config", "validation", stage)
run_tag <- as.character(get_arg("--run-tag", ""))[1L]
if (!nzchar(run_tag)) stop("--run-tag is required.", call. = FALSE)
output_root <- normalizePath(get_arg(
  "--output-root",
  file.path("reports", "shared_fitforecast_v2_orchestration", "chain_aggregate_smoke_audit")
), winslash = "/", mustWork = FALSE)
dir.create(output_root, recursive = TRUE, showWarnings = FALSE)
grid <- read_csv(paste0(stub, "_smoke_grid.csv"))
targets <- read_csv(paste0(stub, "_smoke_target_spec_ids.csv"))
run_root <- normalizePath(file.path(
  "results", "qdesn_mcmc_validation", paste0(stage, "_smoke"), run_tag
), winslash = "/", mustWork = FALSE)
if (!dir.exists(run_root)) stop(sprintf("Smoke run root is missing: %s", run_root), call. = FALSE)

request_paths <- list.files(
  run_root, pattern = "^fit_request[.]json$", recursive = TRUE, full.names = TRUE
)
request_rows <- lapply(request_paths, function(path) {
  request <- jsonlite::read_json(path, simplifyVector = TRUE)
  data.frame(
    spec_id = as.character(request$spec_id %||% NA_character_),
    root_id = as.character(request$root_spec$root_id %||% NA_character_),
    screening_profile_id = as.character(
      request$root_spec$screening_profile_id %||% NA_character_
    ),
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
    observed_synthesis_seed = as.integer(
      request$config$synthesis$seed %||% NA_integer_
    ),
    observed_registry_hash = as.character(
      request$study_contract$source_registry_hash_value %||% NA_character_
    ),
    observed_n_burn = as.integer(
      request$config$inference$mcmc$n_burn %||% NA_integer_
    ),
    observed_n_mcmc = as.integer(
      request$config$inference$mcmc$n_mcmc %||% NA_integer_
    ),
    stringsAsFactors = FALSE
  )
})
observed <- if (length(request_rows)) do.call(rbind, request_rows) else data.frame()
expected <- grid[, c(
  "root_id", "screening_profile_id", "desn_seed", "mcmc_seed",
  "mcmc_rng_seed", "vb_warm_start_seed", "synthesis_seed",
  "source_registry_hash_value"
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
  audit$registry_hash_match <- with(
    audit, observed_registry_hash == expected_source_registry_hash_value
  )
  audit$smoke_budget_match <- with(
    audit, observed_n_burn == 4L & observed_n_mcmc == 4L
  )
}
fit_paths <- list.files(
  run_root, pattern = "^fit_summary_row[.]csv$", recursive = TRUE, full.names = TRUE
)
horizon_paths <- list.files(
  run_root, pattern = "^forecast_horizon_summary[.]csv$", recursive = TRUE,
  full.names = TRUE
)
metric_complete <- vapply(fit_paths, function(path) {
  fit <- tryCatch(read_csv(path), error = function(e) data.frame())
  horizon_path <- file.path(dirname(path), "tables", "forecast_horizon_summary.csv")
  horizon <- tryCatch(read_csv(horizon_path), error = function(e) data.frame())
  h1000 <- if (nrow(horizon)) {
    which(suppressWarnings(as.integer(horizon$horizon)) == 1000L |
            as.character(horizon$window) == "forecast_H1000")
  } else integer()
  nrow(fit) && length(h1000) &&
    is.finite(suppressWarnings(as.numeric(fit$train_qtrue_rmse[[1L]]))) &&
    is.finite(suppressWarnings(as.numeric(horizon$qtrue_mae[h1000[[1L]]]))) &&
    is.finite(suppressWarnings(as.numeric(horizon$pinball_tau[h1000[[1L]]])))
}, logical(1L))
binaries <- list.files(
  run_root, pattern = "[.](rds|rda|RData)$", recursive = TRUE,
  full.names = TRUE, ignore.case = TRUE
)
expected_ids <- unique(as.character(targets$spec_id))
observed_ids <- if (nrow(observed)) unique(as.character(observed$spec_id)) else character()
pass <- nrow(grid) == 2L && nrow(targets) == 2L && nrow(audit) == 2L &&
  setequal(expected_ids, observed_ids) && length(fit_paths) == 2L &&
  length(horizon_paths) == 2L && all(metric_complete) &&
  identical(sort(unique(targets$likelihood_family)), c("al", "exal")) &&
  all(audit$seed_contract_match %in% TRUE) &&
  all(audit$registry_hash_match %in% TRUE) &&
  all(audit$smoke_budget_match %in% TRUE) && !length(binaries)
utils::write.csv(
  audit, file.path(output_root, "smoke_execution_audit.csv"),
  row.names = FALSE, na = ""
)
jsonlite::write_json(list(
  generated_at = as.character(Sys.time()),
  run_tag = run_tag,
  expected_specs = 2L,
  observed_requests = nrow(observed),
  observed_fit_summaries = length(fit_paths),
  observed_horizon_summaries = length(horizon_paths),
  finite_metric_specs = sum(metric_complete),
  binary_payloads = length(binaries),
  diagnostic_status_used_as_filter = FALSE,
  decision = if (pass) "PASS" else "FAIL"
), file.path(output_root, "smoke_gate.json"), pretty = TRUE,
auto_unbox = TRUE, null = "null")
cat(sprintf("smoke: %s (%d/2 requests; %d/2 finite summaries)\n",
            if (pass) "PASS" else "FAIL", nrow(observed), sum(metric_complete)))
if (!pass) stop("Chain-aggregate confirmation smoke failed.", call. = FALSE)

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
resolve_path <- function(path, must_work = TRUE) {
  if (!grepl("^/", path)) path <- file.path(repo_root, path)
  normalizePath(path, winslash = "/", mustWork = isTRUE(must_work))
}
read_csv <- function(path) {
  utils::read.csv(resolve_path(path), check.names = FALSE, stringsAsFactors = FALSE)
}

stage <- "qdesn_dynamic_fitforecast_v2_500obs_alpha_rho_confirmation_v1"
run_tag <- as.character(get_arg("--run-tag", ""))[1L]
if (!nzchar(run_tag)) stop("--run-tag is required.", call. = FALSE)
output_root <- resolve_path(get_arg("--output-root", file.path(
  "reports", "shared_fitforecast_v2_orchestration", "smoke_audit"
)), FALSE)
dir.create(output_root, recursive = TRUE, showWarnings = FALSE)
stub <- file.path("config", "validation", stage)
grid <- read_csv(paste0(stub, "_smoke_grid.csv"))
targets <- read_csv(paste0(stub, "_smoke_target_spec_ids.csv"))
run_root <- resolve_path(file.path(
  "results", "qdesn_mcmc_validation", paste0(stage, "_smoke"), run_tag
), FALSE)
if (!dir.exists(run_root)) stop(sprintf("Smoke run root is missing: %s", run_root), call. = FALSE)

requests <- list.files(
  run_root, pattern = "^fit_request[.]json$", recursive = TRUE, full.names = TRUE
)
rows <- lapply(requests, function(path) {
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
      request$study_contract$alpha_rho_confirmation_v1$source_registry_hash_value %||%
        request$root_spec$source_registry_hash_value %||% NA_character_
    ),
    path = normalizePath(path, winslash = "/", mustWork = TRUE),
    stringsAsFactors = FALSE
  )
})
observed <- if (length(rows)) do.call(rbind, rows) else data.frame()
expected_fields <- c(
  "root_id", "screening_profile_id", "desn_seed", "mcmc_seed",
  "mcmc_rng_seed", "vb_warm_start_seed", "synthesis_seed",
  "source_registry_hash_value"
)
expected <- grid[, expected_fields, drop = FALSE]
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
}
fit_rows <- list.files(
  run_root, pattern = "^fit_summary_row[.]csv$", recursive = TRUE, full.names = TRUE
)
binaries <- list.files(
  run_root, pattern = "[.](rds|rda|RData)$", recursive = TRUE,
  full.names = TRUE, ignore.case = TRUE
)
expected_ids <- unique(as.character(targets$spec_id))
observed_ids <- if (nrow(observed)) unique(as.character(observed$spec_id)) else character()
pass <- nrow(grid) == 4L && nrow(targets) == 4L && nrow(audit) == 4L &&
  setequal(expected_ids, observed_ids) && length(fit_rows) == 4L &&
  all(audit$seed_contract_match %in% TRUE) &&
  all(audit$registry_hash_match %in% TRUE) &&
  !length(binaries)
utils::write.csv(audit, file.path(output_root, "smoke_execution_audit.csv"),
                 row.names = FALSE, na = "")
jsonlite::write_json(list(
  generated_at = as.character(Sys.time()),
  run_tag = run_tag,
  expected_specs = 4L,
  observed_requests = nrow(observed),
  observed_fit_summaries = length(fit_rows),
  seed_contract_passes = if (nrow(audit)) sum(audit$seed_contract_match) else 0L,
  registry_hash_passes = if (nrow(audit)) sum(audit$registry_hash_match) else 0L,
  binary_payloads = length(binaries),
  decision = if (pass) "PASS" else "FAIL"
), file.path(output_root, "smoke_gate.json"), pretty = TRUE,
auto_unbox = TRUE, null = "null")
cat(sprintf("smoke: %s (%d/4 requests; %d/4 fit summaries)\n",
            if (pass) "PASS" else "FAIL", nrow(observed), length(fit_rows)))
if (!pass) stop("Confirmation smoke failed.", call. = FALSE)

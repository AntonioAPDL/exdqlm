#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  required <- c("jsonlite", "yaml")
  missing <- setdiff(required, rownames(installed.packages()))
  if (length(missing)) stop(sprintf("Missing package(s): %s", paste(missing, collapse = ", ")), call. = FALSE)
})

args <- commandArgs(trailingOnly = TRUE)
get_arg <- function(flag, default = NULL) {
  idx <- which(args == flag)
  if (!length(idx) || idx[[1L]] >= length(args)) return(default)
  args[[idx[[1L]] + 1L]]
}
`%||%` <- function(x, y) if (is.null(x) || !length(x)) y else x

repo_root <- normalizePath(system("git rev-parse --show-toplevel", intern = TRUE), winslash = "/", mustWork = TRUE)
setwd(repo_root)
source(file.path(repo_root, "validation", "fitforecast_v2", "R", "qdesn_alpha_rho_topology_v1.R"))
source(file.path(repo_root, "validation", "fitforecast_v2", "R", "qdesn_alpha_rho_seedrepair_v1.R"))
resolve_path <- function(path, must_work = TRUE) {
  path <- as.character(path)[1L]
  if (!grepl("^/", path)) path <- file.path(repo_root, path)
  normalizePath(path, winslash = "/", mustWork = isTRUE(must_work))
}
write_csv <- function(x, path) {
  path <- resolve_path(path, FALSE)
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(x, path, row.names = FALSE, na = "")
  normalizePath(path, winslash = "/", mustWork = TRUE)
}
write_json <- function(x, path) {
  path <- resolve_path(path, FALSE)
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  jsonlite::write_json(x, path, pretty = TRUE, auto_unbox = TRUE, null = "null", digits = NA)
  normalizePath(path, winslash = "/", mustWork = TRUE)
}

stage <- "qdesn_dynamic_fitforecast_v2_500obs_alpha_rho_seedrepair_v1"
stub <- file.path("config", "validation", stage)
run_tag <- as.character(get_arg("--run-tag", ""))[1L]
if (!nzchar(run_tag)) stop("--run-tag is required.", call. = FALSE)
output_root <- resolve_path(get_arg("--output-root", file.path(
  "reports", "qdesn_mcmc_validation", paste0(stage, "_smoke"), run_tag, "seed_contract_audit"
)), FALSE)
dir.create(output_root, recursive = TRUE, showWarnings = FALSE)

defaults <- yaml::read_yaml(resolve_path(paste0(stub, "_smoke_defaults.yaml")))
profiles <- utils::read.csv(resolve_path(paste0(stub, "_smoke_profiles.csv")), check.names = FALSE, stringsAsFactors = FALSE)
grid <- utils::read.csv(resolve_path(paste0(stub, "_smoke_grid.csv")), check.names = FALSE, stringsAsFactors = FALSE)
run_root <- resolve_path(file.path(defaults$campaign$results_root, run_tag), FALSE)
requests <- list.files(run_root, pattern = "^fit_request[.]json$", recursive = TRUE, full.names = TRUE)
if (length(requests) != 2L) stop(sprintf("Expected two smoke fit requests; found %d.", length(requests)), call. = FALSE)

profile_seed <- stats::setNames(as.integer(profiles$seed), profiles$screening_profile_id)
grid_lookup <- grid[match(profiles$screening_profile_id, grid$screening_profile_id), , drop = FALSE]
rows <- lapply(requests, function(path) {
  x <- jsonlite::read_json(path, simplifyVector = TRUE)
  id <- as.character(x$root_spec$screening_profile_id)
  method_dir <- dirname(path)
  quantile_path <- file.path(method_dir, "tables", "fit_quantile_path_train.csv")
  data.frame(
    screening_profile_id = id,
    expected_desn_seed = as.integer(profile_seed[[id]]),
    observed_root_desn_seed = as.integer(x$root_spec$desn_seed %||% NA_integer_),
    observed_config_desn_seed = as.integer(x$config$desn$seed %||% NA_integer_),
    observed_mcmc_seed = as.integer(x$config$inference$mcmc$control$seed %||% NA_integer_),
    observed_mcmc_rng_seed = as.integer(x$config$inference$mcmc$control$rng_seed %||% NA_integer_),
    observed_vb_warm_start_seed = as.integer(x$config$inference$mcmc$vb_warm_start_seed %||% NA_integer_),
    fit_request_path = normalizePath(path, winslash = "/", mustWork = TRUE),
    fit_request_sha256 = unname(tools::sha256sum(path)),
    fit_quantile_path = if (file.exists(quantile_path)) normalizePath(quantile_path, winslash = "/", mustWork = TRUE) else NA_character_,
    fit_quantile_path_sha256 = if (file.exists(quantile_path)) unname(tools::sha256sum(quantile_path)) else NA_character_,
    stringsAsFactors = FALSE
  )
})
audit <- do.call(rbind, rows)
audit <- audit[match(profiles$screening_profile_id, audit$screening_profile_id), , drop = FALSE]
topology <- qdesn_arsr1_topology_audit(profiles)
audit <- merge(audit, topology[, c(
  "screening_profile_id", "recurrent_mask_sha256", "input_mask_sha256",
  "recurrent_value_sha256", "input_value_sha256"
), drop = FALSE], by = "screening_profile_id", all.x = TRUE, sort = FALSE)
audit_path <- write_csv(audit, file.path(output_root, "seed_smoke_audit.csv"))

binary_paths <- list.files(run_root, pattern = "[.](rds|rda|RData)$", recursive = TRUE, full.names = TRUE, ignore.case = TRUE)
checks <- c(
  two_requests = nrow(audit) == 2L,
  request_seed_match = all(audit$expected_desn_seed == audit$observed_root_desn_seed & audit$expected_desn_seed == audit$observed_config_desn_seed),
  distinct_reservoir_seeds = length(unique(audit$observed_config_desn_seed)) == 2L,
  paired_mcmc_seed = length(unique(audit$observed_mcmc_seed)) == 1L,
  paired_mcmc_rng_seed = length(unique(audit$observed_mcmc_rng_seed)) == 1L,
  paired_vb_warm_start_seed = length(unique(audit$observed_vb_warm_start_seed)) == 1L,
  distinct_recurrent_topology = length(unique(audit$recurrent_value_sha256)) == 2L,
  distinct_input_topology = length(unique(audit$input_value_sha256)) == 2L,
  distinct_fit_paths = all(!is.na(audit$fit_quantile_path_sha256)) && length(unique(audit$fit_quantile_path_sha256)) == 2L,
  storage_light = length(binary_paths) == 0L
)
status <- if (all(checks)) "PASS" else "FAIL"
gate_path <- write_json(list(
  generated_at = as.character(Sys.time()),
  stage = stage,
  run_tag = run_tag,
  status = status,
  checks = as.list(checks),
  audit_path = audit_path,
  unexpected_binary_payloads = length(binary_paths)
), file.path(output_root, "seed_smoke_gate.json"))
if (!identical(status, "PASS")) {
  failed <- names(checks)[!checks]
  stop(sprintf("Executable seed smoke failed: %s", paste(failed, collapse = ", ")), call. = FALSE)
}
cat(sprintf("Seed smoke: PASS\nAudit: %s\nGate: %s\n", audit_path, gate_path))

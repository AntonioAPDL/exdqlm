#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  required <- c("jsonlite", "yaml")
  missing <- setdiff(required, rownames(installed.packages()))
  if (length(missing)) {
    stop(sprintf("Missing package(s): %s", paste(missing, collapse = ", ")), call. = FALSE)
  }
})

args <- commandArgs(trailingOnly = TRUE)
get_arg <- function(flag, default = NULL) {
  index <- which(args == flag)
  if (!length(index) || index[[1L]] >= length(args)) return(default)
  args[[index[[1L]] + 1L]]
}
as_bool <- function(x) {
  if (is.logical(x)) return(x)
  toupper(trimws(as.character(x))) %in% c("TRUE", "T", "YES", "Y", "1")
}

repo_root <- normalizePath(
  system("git rev-parse --show-toplevel", intern = TRUE),
  winslash = "/", mustWork = TRUE
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

stage <- "qdesn_dynamic_fitforecast_v2_500obs_trainonly_rebaseline_v1"
stub <- file.path("config", "validation", stage)
defaults <- yaml::read_yaml(resolve_path(paste0(stub, "_defaults.yaml")))
grid <- read_csv(paste0(stub, "_grid.csv"))
targets <- read_csv(paste0(stub, "_target_spec_ids.csv"))
profiles <- read_csv(paste0(stub, "_profiles.csv"))
metrics <- read_csv(paste0(stub, "_legacy_metric_contract.csv"))
smoke_targets <- read_csv(paste0(stub, "_smoke_target_spec_ids.csv"))
source_audit <- read_csv(paste0(stub, "_source_file_hash_audit.csv"))
staged_audit <- read_csv(paste0(stub, "_staged_source_hash_audit.csv"))
request_audit <- read_csv(paste0(stub, "_source_fit_request_audit.csv"))
generated <- read_csv(paste0(stub, "_generated_file_manifest.csv"))
materialization <- jsonlite::read_json(
  resolve_path(paste0(stub, "_materialization_manifest.json")),
  simplifyVector = TRUE
)
expected_count <- as.integer(materialization$counts$full_specs)
expected_hash <- as.character(materialization$source_registry_hash_value)

generated$present <- file.exists(generated$path)
generated$observed_sha256 <- vapply(generated$path, function(path) {
  if (file.exists(path)) unname(tools::sha256sum(path)) else NA_character_
}, character(1L))
generated$hash_match <- generated$present & generated$sha256 == generated$observed_sha256
source_recheck <- vapply(seq_len(nrow(source_audit)), function(i) {
  path <- source_audit$path[[i]]
  file.exists(path) && identical(
    unname(tools::sha256sum(path)), as.character(source_audit$expected_sha256[[i]])
  )
}, logical(1L))
staged_recheck <- vapply(seq_len(nrow(staged_audit)), function(i) {
  path <- staged_audit$path[[i]]
  file.exists(path) && identical(
    unname(tools::sha256sum(path)), as.character(staged_audit$expected_sha256[[i]])
  )
}, logical(1L))
request_recheck <- vapply(seq_len(nrow(request_audit)), function(i) {
  path <- request_audit$source_fit_request_path[[i]]
  file.exists(path) && identical(
    unname(tools::sha256sum(path)), as.character(request_audit$source_fit_request_sha256[[i]])
  )
}, logical(1L))

active_files <- unique(c(
  generated$path,
  resolve_path(paste0(stub, "_materialization_manifest.json"))
))
active_text <- paste(unlist(lapply(active_files, function(path) {
  if (file.exists(path)) readLines(path, warn = FALSE) else character()
}), use.names = FALSE), collapse = "\n")

checks <- c(
  package_version_1_0_0 = identical(
    as.character(read.dcf(file.path(repo_root, "DESCRIPTION"))[1L, "Version"]), "1.0.0"
  ),
  expected_design_count = expected_count >= 18L && nrow(grid) == expected_count &&
    nrow(targets) == expected_count && nrow(profiles) == expected_count,
  metric_contract_complete = nrow(metrics) == 54L &&
    length(unique(metrics$cell_id)) == 18L,
  smoke_contract_complete = nrow(smoke_targets) == 2L &&
    setequal(smoke_targets$likelihood_family, c("al", "exal")),
  unique_roots_and_specs = !anyDuplicated(grid$root_id) &&
    !anyDuplicated(targets$spec_id),
  registry_identity = all(grid$source_registry_hash_value == expected_hash),
  source_files_verified = all(source_recheck),
  staged_files_verified = all(staged_recheck),
  source_requests_verified = all(request_recheck),
  generated_files_verified = all(generated$hash_match),
  train_only_scope = identical(defaults$preproc$fit_scope, "train_only") &&
    identical(defaults$study_contract$preprocessing$scope, "train_only"),
  heldout_excluded = !as_bool(
    defaults$study_contract$preprocessing$heldout_response_used_for_scaling
  ) && !as_bool(defaults$study_contract$preprocessing$heldout_covariates_used_for_scaling),
  source_windows = all(grid$train_start_source_index == 8501L) &&
    all(grid$train_end_source_index == 9000L) &&
    all(grid$forecast_start_source_index == 9001L) &&
    all(grid$forecast_end_source_index == 10000L),
  full_budget = as.integer(defaults$study_contract$budget$mcmc_n_burn) == 5000L &&
    as.integer(defaults$study_contract$budget$mcmc_n_mcmc) == 20000L,
  storage_light = !defaults$pipeline$outputs$keep_draws &&
    !defaults$pipeline$outputs$keep_mcmc_vb_init &&
    !defaults$pipeline$outputs$save_forecast_objects &&
    !defaults$pipeline$outputs$retain_full_rds_on_failure,
  no_stale_home_paths = !grepl("/home/jaguir26/local/src", active_text, fixed = TRUE)
)
pass <- all(checks)
output <- as.character(get_arg("--output", ""))[1L]
if (nzchar(output)) {
  output <- resolve_path(output, FALSE)
  dir.create(dirname(output), recursive = TRUE, showWarnings = FALSE)
  jsonlite::write_json(list(
    generated_at = as.character(Sys.time()),
    stage = stage,
    source_registry_hash_value = expected_hash,
    expected_specs = expected_count,
    checks = as.list(checks),
    decision = if (pass) "PASS" else "FAIL"
  ), output, pretty = TRUE, auto_unbox = TRUE, null = "null")
}
cat(sprintf(
  "train-only contract: %s (%d/%d checks; %d specs; %d source files)\n",
  if (pass) "PASS" else "FAIL", sum(checks), length(checks),
  expected_count, nrow(source_audit)
))
if (!pass) {
  cat("failed checks:\n")
  cat(paste0("- ", names(checks)[!checks], collapse = "\n"), "\n")
  stop("Train-only rebaseline contract verification failed.", call. = FALSE)
}

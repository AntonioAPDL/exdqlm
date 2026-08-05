#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  required <- c("jsonlite", "yaml")
  missing <- setdiff(required, rownames(installed.packages()))
  if (length(missing)) stop(sprintf("Missing package(s): %s", paste(missing, collapse = ", ")),
                            call. = FALSE)
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
repo_root <- normalizePath(system("git rev-parse --show-toplevel", intern = TRUE),
                           winslash = "/", mustWork = TRUE)
setwd(repo_root)
resolve_path <- function(path, must_work = TRUE) {
  if (!grepl("^/", path)) path <- file.path(repo_root, path)
  normalizePath(path, winslash = "/", mustWork = isTRUE(must_work))
}
read_csv <- function(path) utils::read.csv(resolve_path(path), check.names = FALSE,
                                            stringsAsFactors = FALSE)

stage <- "qdesn_dynamic_fitforecast_v2_500obs_vb_trainonly_rebaseline_v1"
stub <- file.path("config", "validation", stage)
defaults <- yaml::read_yaml(resolve_path(paste0(stub, "_defaults.yaml")))
grid <- read_csv(paste0(stub, "_grid.csv"))
targets <- read_csv(paste0(stub, "_target_spec_ids.csv"))
profiles <- read_csv(paste0(stub, "_profiles.csv"))
candidates <- read_csv(paste0(stub, "_candidate_contract.csv"))
smoke_targets <- read_csv(paste0(stub, "_smoke_target_spec_ids.csv"))
source_audit <- read_csv(paste0(stub, "_source_file_hash_audit.csv"))
staged_audit <- read_csv(paste0(stub, "_staged_source_hash_audit.csv"))
request_audit <- read_csv(paste0(stub, "_source_fit_request_audit.csv"))
generated <- read_csv(paste0(stub, "_generated_file_manifest.csv"))
materialization <- jsonlite::read_json(
  resolve_path(paste0(stub, "_materialization_manifest.json")), simplifyVector = TRUE
)
expected_hash <- as.character(materialization$source_registry_hash_value)

generated$present <- file.exists(generated$path)
generated$observed_sha256 <- vapply(generated$path, function(path) {
  if (file.exists(path)) unname(tools::sha256sum(path)) else NA_character_
}, character(1L))
generated$hash_match <- generated$present & generated$sha256 == generated$observed_sha256
hash_recheck <- function(table, path_col = "path", hash_col = "expected_sha256") {
  vapply(seq_len(nrow(table)), function(i) {
    path <- table[[path_col]][[i]]
    file.exists(path) && identical(unname(tools::sha256sum(path)),
                                   as.character(table[[hash_col]][[i]]))
  }, logical(1L))
}

active_files <- unique(c(generated$path,
                         resolve_path(paste0(stub, "_materialization_manifest.json"))))
active_text <- paste(unlist(lapply(active_files, function(path) {
  if (file.exists(path)) readLines(path, warn = FALSE) else character()
}), use.names = FALSE), collapse = "\n")

checks <- c(
  package_version_1_0_0 = identical(
    as.character(read.dcf(file.path(repo_root, "DESCRIPTION"))[1L, "Version"]), "1.0.0"
  ),
  exact_design_count = nrow(grid) == 18L && nrow(targets) == 18L &&
    nrow(profiles) == 18L && nrow(candidates) == 18L,
  one_design_per_cell = length(unique(paste(profiles$model_variant, profiles$family,
                                            sprintf("%.8f", profiles$tau)))) == 18L,
  methods_and_likelihoods = identical(defaults$execution$methods, "vb") &&
    setequal(defaults$execution$likelihood_families, c("al", "exal")) &&
    all(targets$method == "vb") &&
    all(targets$likelihood_family == targets$likelihood_target),
  smoke_contract = nrow(smoke_targets) == 2L &&
    setequal(smoke_targets$likelihood_family, c("al", "exal")),
  unique_roots_and_specs = !anyDuplicated(grid$root_id) && !anyDuplicated(targets$spec_id),
  registry_identity = all(grid$source_registry_hash_value == expected_hash),
  source_files_verified = all(hash_recheck(source_audit)),
  staged_files_verified = all(hash_recheck(staged_audit)),
  source_requests_verified = all(hash_recheck(
    request_audit, "source_fit_request_path", "source_fit_request_sha256"
  )),
  generated_files_verified = all(generated$hash_match),
  train_only_scope = identical(defaults$preproc$fit_scope, "train_only") &&
    identical(defaults$study_contract$preprocessing$scope, "train_only"),
  heldout_excluded = !as_bool(defaults$study_contract$preprocessing$heldout_response_used_for_scaling) &&
    !as_bool(defaults$study_contract$preprocessing$heldout_covariates_used_for_scaling),
  source_windows = all(grid$train_start_source_index == 8501L) &&
    all(grid$train_end_source_index == 9000L) &&
    all(grid$forecast_start_source_index == 9001L) &&
    all(grid$forecast_end_source_index == 10000L),
  full_vb_budget = as.integer(defaults$study_contract$budget$vb_max_iter) == 150L &&
    as.integer(defaults$study_contract$budget$vb_min_iter_elbo) == 40L &&
    as.integer(defaults$study_contract$budget$vb_n_samp_xi) == 500L &&
    all(profiles$source_vb_max_iter == 150L) &&
    all(profiles$source_vb_min_iter_elbo == 40L) &&
    all(profiles$source_vb_n_samp_xi == 500L),
  storage_light = !defaults$pipeline$outputs$keep_draws &&
    !defaults$pipeline$outputs$keep_mcmc_vb_init &&
    !defaults$pipeline$outputs$save_forecast_objects &&
    !defaults$pipeline$outputs$retain_full_rds_on_failure &&
    !defaults$pipeline$inference$vb$diagnostics$rhs_trace &&
    !defaults$pipeline$inference$vb$diagnostics$rhs_deep,
  no_stale_home_paths = !grepl("/home/jaguir26/local/src", active_text, fixed = TRUE)
)
pass <- all(checks)
output <- as.character(get_arg("--output", ""))[1L]
if (nzchar(output)) {
  output <- resolve_path(output, FALSE)
  dir.create(dirname(output), recursive = TRUE, showWarnings = FALSE)
  jsonlite::write_json(list(
    generated_at = as.character(Sys.time()), stage = stage,
    source_registry_hash_value = expected_hash, expected_specs = 18L,
    checks = as.list(checks), decision = if (pass) "PASS" else "FAIL"
  ), output, pretty = TRUE, auto_unbox = TRUE, null = "null")
}
cat(sprintf("VB train-only contract: %s (%d/%d checks; 18 specs)\n",
            if (pass) "PASS" else "FAIL", sum(checks), length(checks)))
if (!pass) {
  cat("failed checks:\n", paste0("- ", names(checks)[!checks], collapse = "\n"), "\n")
  stop("VB train-only rebaseline contract verification failed.", call. = FALSE)
}

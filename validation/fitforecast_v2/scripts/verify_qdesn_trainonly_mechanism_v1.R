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
as_bool <- function(x) isTRUE(x) || toupper(trimws(as.character(x)[1L])) %in% c("TRUE", "T", "1", "YES")

repo_root <- normalizePath(system("git rev-parse --show-toplevel", intern = TRUE), winslash = "/", mustWork = TRUE)
setwd(repo_root)
resolve_path <- function(path, must_work = TRUE) {
  path <- as.character(path)[1L]
  if (!grepl("^/", path)) path <- file.path(repo_root, path)
  normalizePath(path, winslash = "/", mustWork = isTRUE(must_work))
}
read_csv <- function(path) utils::read.csv(resolve_path(path), check.names = FALSE, stringsAsFactors = FALSE)
sha256 <- function(path) unname(tools::sha256sum(resolve_path(path)))

stage <- "qdesn_dynamic_fitforecast_v2_500obs_trainonly_mechanism_v1"
stub <- file.path("config", "validation", stage)
manifest_path <- resolve_path(paste0(stub, "_materialization_manifest.json"))
manifest <- jsonlite::read_json(manifest_path, simplifyVector = TRUE)
bundle_index <- read_csv(paste0(stub, "_bundle_index.csv"))
profiles <- read_csv(paste0(stub, "_profiles.csv"))
assignments <- read_csv(paste0(stub, "_cell_assignments.csv"))
topology <- read_csv(paste0(stub, "_topology_audit.csv"))
targets <- read_csv(paste0(stub, "_target_cells.csv"))
novelty <- read_csv(paste0(stub, "_nonrepeat_ledger.csv"))
generated <- read_csv(paste0(stub, "_generated_file_manifest.csv"))

generated$present <- file.exists(generated$path)
generated$observed_sha256 <- vapply(generated$path, function(path) {
  if (file.exists(path)) unname(tools::sha256sum(path)) else NA_character_
}, character(1L))
generated$hash_match <- generated$present & generated$sha256 == generated$observed_sha256

bundle_checks <- list()
active_paths <- c(manifest_path, generated$path)
all_source_scenarios <- character()
for (i in seq_len(nrow(bundle_index))) {
  b <- bundle_index[i, , drop = FALSE]
  bundle_id <- as.character(b$bundle_id[[1L]])
  defaults <- yaml::read_yaml(resolve_path(b$defaults_path[[1L]]))
  grid <- read_csv(b$grid_path[[1L]])
  specs <- read_csv(b$target_specs_path[[1L]])
  bundle_profiles <- read_csv(paste0(stub, "_", bundle_id, "_profiles.csv"))
  expected <- as.integer(b$expected_specs[[1L]])
  expected_input <- if (bundle_id == "raw") "raw_y_lags" else "dlm_decomp_lags"
  expected_builder <- switch(bundle_id, raw = "raw_y_lags", c12 = "component_lags", c123 = "component_lags", sr = "state_resid_y")
  expected_h <- if (bundle_id == "c123") 1:3 else 1:2
  observed_h <- as.integer(unlist(defaults$deterministic_features$harmonics, use.names = FALSE))
  all_source_scenarios <- c(all_source_scenarios, as.character(grid$source_scenario))
  bundle_checks[[bundle_id]] <- c(
    expected_count = nrow(grid) == expected && nrow(specs) == expected,
    unique_roots_specs = !anyDuplicated(grid$root_id) && !anyDuplicated(specs$spec_id),
    exact_likelihood = all(as.character(specs$likelihood_family) == as.character(specs$likelihood_target)),
    profile_count = nrow(bundle_profiles) * 3L == expected,
    source_replicates = length(unique(grid$source_scenario)) == 3L,
    train_window = all(grid$train_start_source_index == 8501L) && all(grid$train_end_source_index == 9000L),
    forecast_window = all(grid$forecast_start_source_index == 9001L) && all(grid$forecast_end_source_index == 10000L),
    train_only = identical(defaults$preproc$fit_scope, "train_only") &&
      identical(defaults$study_contract$preprocessing$scope, "train_only") &&
      !as_bool(defaults$study_contract$preprocessing$heldout_response_used_for_scaling) &&
      !as_bool(defaults$study_contract$preprocessing$heldout_covariates_used_for_scaling),
    input_mode = identical(defaults$pipeline$readout$input_mode, expected_input),
    decomposition_state = identical(as_bool(defaults$pipeline$decomposition$enabled), bundle_id != "raw"),
    decomposition_builder = bundle_id == "raw" || identical(defaults$pipeline$decomposition$input_builder, expected_builder),
    harmonic_contract = identical(observed_h, expected_h),
    explicit_guard = bundle_id == "raw" || as_bool(defaults$pipeline$validation_guardrails$allow_dlm_decomp_lags),
    discovery_budget = as.integer(defaults$pipeline$inference$mcmc$n_burn) == 1000L &&
      as.integer(defaults$pipeline$inference$mcmc$n_mcmc) == 3000L &&
      as.integer(defaults$pipeline$inference$mcmc$progress_every) == 50L,
    vb_warm_start = as_bool(defaults$pipeline$inference$mcmc$init_from_vb) &&
      as.integer(defaults$pipeline$inference$mcmc$vb_warm_start_control$max_iter) == 150L,
    storage_light = !as_bool(defaults$pipeline$outputs$keep_draws) &&
      !as_bool(defaults$pipeline$outputs$keep_mcmc_vb_init) &&
      !as_bool(defaults$pipeline$outputs$save_forecast_objects) &&
      !as_bool(defaults$pipeline$outputs$retain_full_rds_on_failure),
    allowed_specs_exact = setequal(as.character(defaults$execution$allowed_fit_spec_ids), as.character(specs$spec_id))
  )
  active_paths <- c(active_paths, b$defaults_path[[1L]], b$grid_path[[1L]], b$target_specs_path[[1L]])
}
bundle_check_vector <- unlist(bundle_checks, use.names = TRUE)

active_text <- paste(unlist(lapply(unique(active_paths), function(path) {
  path <- resolve_path(path, FALSE)
  if (file.exists(path)) readLines(path, warn = FALSE) else character()
}), use.names = FALSE), collapse = "\n")
source_registry_path <- as.character(manifest$source_registry_path)
source_registry_match <- file.exists(source_registry_path) &&
  identical(unname(tools::sha256sum(source_registry_path)), as.character(manifest$source_registry_sha256))

checks <- c(
  package_version_1_0_0 = identical(as.character(read.dcf(file.path(repo_root, "DESCRIPTION"))[1L, "Version"]), "1.0.0"),
  overall_count = as.integer(manifest$counts$total_specs) == 90L && sum(bundle_index$expected_specs) == 90L,
  target_contract = nrow(targets) == 3L && sum(as.logical(targets$primary_target)) == 2L,
  profile_contract = nrow(profiles) == 30L && nrow(assignments) == 30L,
  topology_contract = nrow(topology) == 30L && all(as.logical(topology$total_topology_valid[topology$arm_code != "parent_exact"])),
  paired_seed_contract = setequal(unique(as.integer(profiles$paired_reservoir_seed)), c(910001L, 910002L)),
  source_registry_verified = source_registry_match,
  generated_files_verified = all(generated$hash_match),
  nonrepeat_ledger_complete = nrow(novelty) == length(unique(paste(profiles$target_cell_id, profiles$bundle_id, profiles$arm_code, sep = "\r"))) &&
    all(nzchar(novelty$repeat_disposition)),
  no_stale_home_paths = !grepl("/home/jaguir26/local/src", active_text, fixed = TRUE),
  article_source_excluded = all(grepl("^dlm_constV_p90_trainonly_mech_dev0[123]_TTmain10000_fitforecast$", unique(all_source_scenarios))),
  bundle_check_vector
)

pass <- all(checks)
output <- as.character(get_arg("--output", ""))[1L]
if (nzchar(output)) {
  output <- resolve_path(output, FALSE)
  dir.create(dirname(output), recursive = TRUE, showWarnings = FALSE)
  jsonlite::write_json(list(
    generated_at = as.character(Sys.time()),
    stage = stage,
    source_registry_sha256 = as.character(manifest$source_registry_sha256),
    expected_specs = 90L,
    checks = as.list(checks),
    decision = if (pass) "PASS" else "FAIL"
  ), output, pretty = TRUE, auto_unbox = TRUE, null = "null")
}

cat(sprintf("train-only mechanism contract: %s (%d/%d checks; 90 specs)\n", if (pass) "PASS" else "FAIL", sum(checks), length(checks)))
if (!pass) {
  cat("failed checks:\n")
  cat(paste0("- ", names(checks)[!checks], collapse = "\n"), "\n")
  stop("Train-only mechanism v1 contract verification failed.", call. = FALSE)
}

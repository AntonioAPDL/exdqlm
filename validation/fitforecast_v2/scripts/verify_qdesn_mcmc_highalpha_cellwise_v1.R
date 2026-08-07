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
repo_root <- normalizePath(system("git rev-parse --show-toplevel", intern = TRUE), winslash = "/", mustWork = TRUE)
setwd(repo_root)
stage <- "qdesn_dynamic_fitforecast_v2_500obs_mcmc_highalpha_cellwise_v1"
stub <- file.path("config", "validation", stage)
must_exist <- c(
  paste0(stub, "_materialization_manifest.json"),
  paste0(stub, "_phase_index.csv"),
  paste0(stub, "_target_cells.csv"),
  paste0(stub, "_authoritative_parent_profiles.csv"),
  paste0(stub, "_authoritative_metric_sources.csv"),
  paste0(stub, "_topology_audit.csv"),
  paste0(stub, "_nonrepeat_ledger.csv"),
  paste0(stub, "_wave1_defaults.yaml"),
  paste0(stub, "_wave1_grid.csv"),
  paste0(stub, "_wave1_target_spec_ids.csv"),
  paste0(stub, "_wave2_universe_defaults.yaml"),
  paste0(stub, "_wave2_universe_target_spec_ids.csv")
)
missing <- must_exist[!file.exists(must_exist)]
if (length(missing)) stop(sprintf("Missing materialized contract: %s", paste(missing, collapse = ", ")), call. = FALSE)

read_csv <- function(path) utils::read.csv(path, check.names = FALSE, stringsAsFactors = FALSE)
phase_index <- read_csv(paste0(stub, "_phase_index.csv"))
targets <- read_csv(paste0(stub, "_target_cells.csv"))
parents <- read_csv(paste0(stub, "_authoritative_parent_profiles.csv"))
topology <- read_csv(paste0(stub, "_topology_audit.csv"))
wave1_profiles <- read_csv(paste0(stub, "_wave1_profiles.csv"))
wave1_specs <- read_csv(paste0(stub, "_wave1_target_spec_ids.csv"))
wave2_profiles <- read_csv(paste0(stub, "_wave2_universe_profiles.csv"))
wave2_specs <- read_csv(paste0(stub, "_wave2_universe_target_spec_ids.csv"))
wave1_defaults <- yaml::read_yaml(paste0(stub, "_wave1_defaults.yaml"))
wave2_defaults <- yaml::read_yaml(paste0(stub, "_wave2_universe_defaults.yaml"))
manifest <- jsonlite::read_json(paste0(stub, "_materialization_manifest.json"), simplifyVector = TRUE)

checks <- list(
  package_version = identical(as.character(read.dcf("DESCRIPTION")[1L, "Version"]), "1.0.0"),
  authority_hash = identical(
    unname(tools::sha256sum(manifest$authority_interface_path)),
    "dff814fab1e920c10760645ac9e8d37dfa7f33ae2afba34ee8ed2a5509f4952a"
  ),
  authority_source_identity = identical(
    unique(as.character(targets$source_registry_hash_value)),
    "edddb56fc2b30e49ac99fdd08b53dad468ed53e05d0fe1fe16426ee9d9ffe275"
  ),
  corrected_train_only = identical(unique(as.character(targets$preprocessing_scope)), "train_only"),
  unresolved_cells = nrow(targets) == 11L,
  wave1_cells = sum(targets$launch_wave == "wave1") == 4L,
  wave2_cells = sum(targets$launch_wave == "wave2_universe") == 7L,
  wave1_profiles = nrow(wave1_profiles) == 124L,
  wave1_specs = nrow(wave1_specs) == 372L && !anyDuplicated(wave1_specs$spec_id),
  wave2_profiles = nrow(wave2_profiles) == 252L,
  wave2_specs = nrow(wave2_specs) == 756L && !anyDuplicated(wave2_specs$spec_id),
  wave1_workers = identical(as.integer(wave1_defaults$runtime$workers), 20L),
  wave1_threads = identical(as.integer(wave1_defaults$runtime$threads), 1L),
  screening_budget = identical(as.integer(wave1_defaults$pipeline$inference$mcmc$n_burn), 1000L) &&
    identical(as.integer(wave1_defaults$pipeline$inference$mcmc$n_mcmc), 3000L),
  progress_cadence = identical(as.integer(wave1_defaults$pipeline$inference$mcmc$progress_every), 50L),
  storage_light = !isTRUE(wave1_defaults$pipeline$outputs$keep_draws) &&
    !isTRUE(wave1_defaults$pipeline$outputs$keep_mcmc_vb_init) &&
    !isTRUE(wave1_defaults$pipeline$outputs$save_forecast_objects) &&
    !isTRUE(wave1_defaults$pipeline$outputs$retain_full_rds_on_failure),
  no_inert_search_profiles = all(as.logical(topology$candidate_topology_valid)),
  wave1_approved = isTRUE(phase_index$launch_approved[phase_index$phase == "wave1"]),
  wave2_gated = !isTRUE(phase_index$launch_approved[phase_index$phase == "wave2_universe"]),
  no_home_src_paths = !any(grepl("/home/jaguir26/local/src", unlist(list(
    wave1_defaults, wave2_defaults, parents, manifest
  )), fixed = TRUE)),
  source_windows = all(read_csv(manifest$source_window_audit_path)$status == "PASS")
)
check_table <- data.frame(
  check = names(checks),
  passed = as.logical(unlist(checks, use.names = FALSE)),
  stringsAsFactors = FALSE
)
output <- get_arg("--output", file.path("reports", "qdesn_mcmc_validation", stage, "contract_verification.json"))
dir.create(dirname(output), recursive = TRUE, showWarnings = FALSE)
jsonlite::write_json(list(
  generated_at = as.character(Sys.time()),
  passed = all(check_table$passed),
  checks = check_table,
  wave1_specs = nrow(wave1_specs),
  wave2_universe_specs = nrow(wave2_specs),
  wave1_workers = 20L,
  threads_per_worker = 1L,
  article_update_allowed = FALSE
), output, pretty = TRUE, auto_unbox = TRUE, null = "null")
print(check_table, row.names = FALSE)
if (!all(check_table$passed)) {
  stop(sprintf("Contract verification failed: %s", paste(check_table$check[!check_table$passed], collapse = ", ")), call. = FALSE)
}
cat(sprintf("Contract verification passed: %s\n", normalizePath(output, winslash = "/", mustWork = TRUE)))

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
stage <- "qdesn_dynamic_fitforecast_v2_500obs_mcmc_dynamic_seedrepair_v1"
stub <- file.path("config", "validation", stage)
paths <- list(
  manifest = paste0(stub, "_materialization_manifest.json"),
  targets = paste0(stub, "_target_cells.csv"),
  parents = paste0(stub, "_authoritative_parent_profiles.csv"),
  seeds = paste0(stub, "_dynamic_seed_contract.csv"),
  seed_search = paste0(stub, "_dynamic_seed_search_audit.csv"),
  profiles = paste0(stub, "_profiles.csv"),
  topology = paste0(stub, "_topology_audit.csv"),
  defaults = paste0(stub, "_discovery_defaults.yaml"),
  grid = paste0(stub, "_discovery_grid.csv"),
  specs = paste0(stub, "_discovery_target_spec_ids.csv"),
  seed_execution = paste0(stub, "_seed_execution_contract.csv"),
  nonrepeat = paste0(stub, "_nonrepeat_ledger.csv"),
  source_continuity = file.path(
    "reports", "qdesn_mcmc_validation", stage, "materialization",
    "source_identity_continuity_audit.csv"
  )
)
missing <- unlist(paths)[!file.exists(unlist(paths))]
if (length(missing)) stop(sprintf("Missing materialized contract: %s", paste(missing, collapse = ", ")), call. = FALSE)

read_csv <- function(path) utils::read.csv(path, check.names = FALSE, stringsAsFactors = FALSE)
manifest <- jsonlite::read_json(paths$manifest, simplifyVector = TRUE)
targets <- read_csv(paths$targets)
parents <- read_csv(paths$parents)
seeds <- read_csv(paths$seeds)
seed_search <- read_csv(paths$seed_search)
profiles <- read_csv(paths$profiles)
topology <- read_csv(paths$topology)
defaults <- yaml::read_yaml(paths$defaults)
grid <- read_csv(paths$grid)
specs <- read_csv(paths$specs)
seed_execution <- read_csv(paths$seed_execution)
nonrepeat <- read_csv(paths$nonrepeat)
source_continuity <- read_csv(paths$source_continuity)

profile_roles <- table(profiles$comparison_role)
searched_topology <- topology[topology$comparison_role != "authority_parent", , drop = FALSE]
authority_topology <- topology[topology$comparison_role == "authority_parent", , drop = FALSE]
source_cfg <- yaml::read_yaml(paste0(stub, "_source_replicates.yaml"))
all_active_seeds_first <- seeds$seed == c(900124L, 900126L, 900132L)

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
  exact_target_cells = identical(sort(as.character(targets$target_cell_id)), sort(c("al_normal_t0p25", "exal_normal_t0p25"))),
  target_metric = all(parents$target_metrics == "forecast_qtrue_mae_H1000"),
  frozen_structure = all(parents$D == 1L & parents$n_each == 6L & parents$m == 1L &
    parents$alpha == 0.00075 & parents$rho == 0.35 & parents$pi_w == 0.0025 &
    parents$pi_in == 0.05 & parents$rhs_tau0 == 3e-4 & parents$seed == 123L),
  profile_count = nrow(profiles) == 80L,
  profile_roles = identical(as.integer(profile_roles[c("authority_parent", "candidate", "dynamic_parent")]), c(2L, 72L, 6L)),
  dynamic_seed_count = nrow(seeds) == 3L && length(unique(seeds$seed)) == 3L,
  dynamic_seed_rule = all(seeds$dynamic_input_nnz > 0L) && all(all_active_seeds_first),
  seed_search_outcome_blind = all(!seed_search$selection_valid[seed_search$seed < 900124L]) &&
    identical(which(seed_search$selection_valid)[1:3], match(seeds$seed, seed_search$seed)),
  authority_defect_reproduced = nrow(authority_topology) == 2L && all(authority_topology$dynamic_input_nnz == 0L),
  search_dynamic_input_active = nrow(searched_topology) == 78L && all(searched_topology$dynamic_input_nnz > 0L),
  topology_mask_invariant = all(searched_topology$topology_invariant_within_seed),
  alpha_probe_state_distinct = all(searched_topology$probe_state_unique_within_seed),
  topology_contract_named = identical(unique(as.character(profiles$topology_contract_version)), "dynamic_input_excludes_bias_v1"),
  discovery_grid_count = nrow(grid) == 240L,
  discovery_spec_count = nrow(specs) == 240L && !anyDuplicated(specs$spec_id),
  likelihood_filter = all(specs$likelihood_family == specs$likelihood_target),
  seed_execution = nrow(seed_execution) == 240L && all(seed_execution$status == "PASS"),
  source_windows = all(grid$train_start_source_index == 8501L) &&
    all(grid$train_end_source_index == 9000L) &&
    all(grid$forecast_start_source_index == 9001L) &&
    all(grid$forecast_end_source_index == 10000L),
  rolling_contract = identical(as.integer(defaults$study_contract$rolling_origin$max_lead_configured), 30L) &&
    identical(as.integer(defaults$study_contract$rolling_origin$origin_stride), 30L) &&
    identical(as.integer(defaults$pipeline$forecast$horizon), 30L),
  workers = identical(as.integer(defaults$runtime$workers), 20L) &&
    identical(as.integer(defaults$runtime$threads), 1L),
  screening_budget = identical(as.integer(defaults$pipeline$inference$mcmc$n_burn), 1000L) &&
    identical(as.integer(defaults$pipeline$inference$mcmc$n_mcmc), 3000L),
  progress_cadence = identical(as.integer(defaults$pipeline$inference$mcmc$progress_every), 50L),
  vb_initialization = isTRUE(defaults$pipeline$inference$mcmc$init_from_vb),
  storage_light = !isTRUE(defaults$pipeline$outputs$keep_draws) &&
    !isTRUE(defaults$pipeline$outputs$keep_mcmc_vb_init) &&
    !isTRUE(defaults$pipeline$outputs$save_forecast_objects) &&
    !isTRUE(defaults$pipeline$outputs$retain_full_rds_on_failure),
  source_contract = identical(as.integer(source_cfg$generation$TT_warmup), 2000L) &&
    identical(as.integer(source_cfg$generation$TT_main), 10000L) &&
    identical(as.integer(source_cfg$generation$TT_total), 12000L) &&
    identical(as.character(source_cfg$generation$families), "normal") &&
    identical(as.numeric(source_cfg$generation$taus), 0.25),
  source_identity_continuity = nrow(source_continuity) == 4L &&
    all(source_continuity$all_hashes_and_scenario_match),
  nonrepeat_ledger = nrow(nonrepeat) == 28L && all(nzchar(nonrepeat$repeat_disposition)),
  no_home_src_paths = !any(grepl("/home/jaguir26/local/src", unlist(manifest), fixed = TRUE)) &&
    !any(grepl("/home/jaguir26/local/src", unlist(defaults), fixed = TRUE))
)

rows <- data.frame(check = names(checks), passed = unlist(checks, use.names = FALSE), stringsAsFactors = FALSE)
passed <- all(rows$passed)
output <- get_arg("--output", file.path("reports", "qdesn_mcmc_validation", stage, "contract_verification.json"))
dir.create(dirname(output), recursive = TRUE, showWarnings = FALSE)
jsonlite::write_json(list(
  generated_at = as.character(Sys.time()),
  passed = passed,
  checks = rows,
  target_cells = 2L,
  profiles = nrow(profiles),
  discovery_specs = nrow(specs),
  dynamic_seeds = as.list(as.integer(seeds$seed)),
  workers = 20L,
  threads_per_worker = 1L,
  article_update_allowed = FALSE,
  full_confirmation_automatic = FALSE
), output, pretty = TRUE, auto_unbox = TRUE, digits = NA)
if (!passed) {
  print(rows[!rows$passed, , drop = FALSE])
  stop("Dynamic seed-repair contract verification failed.", call. = FALSE)
}
cat(sprintf("PASS: %d checks; %d profiles; %d discovery specs.\n", nrow(rows), nrow(profiles), nrow(specs)))

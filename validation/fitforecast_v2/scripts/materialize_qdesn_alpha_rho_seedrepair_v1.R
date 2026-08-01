#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  required <- c("digest", "jsonlite", "pkgload", "yaml")
  missing <- setdiff(required, rownames(installed.packages()))
  if (length(missing)) stop(sprintf("Missing package(s): %s", paste(missing, collapse = ", ")), call. = FALSE)
})

args <- commandArgs(trailingOnly = TRUE)
get_arg <- function(flag, default = NULL) {
  idx <- which(args == flag)
  if (!length(idx) || idx[[1L]] >= length(args)) return(default)
  args[[idx[[1L]] + 1L]]
}
has_flag <- function(flag) any(args == flag)
`%||%` <- function(x, y) if (is.null(x) || !length(x)) y else x

repo_root <- normalizePath(system("git rev-parse --show-toplevel", intern = TRUE), winslash = "/", mustWork = TRUE)
setwd(repo_root)
pkgload::load_all(repo_root, quiet = TRUE)
source(file.path(repo_root, "validation", "fitforecast_v2", "R", "qdesn_alpha_rho_topology_v1.R"))
source(file.path(repo_root, "validation", "fitforecast_v2", "R", "qdesn_alpha_rho_cellwise_v2.R"))
source(file.path(repo_root, "validation", "fitforecast_v2", "R", "qdesn_alpha_rho_seedrepair_v1.R"))

resolve_path <- function(path, must_work = TRUE) {
  path <- as.character(path)[1L]
  if (!grepl("^/", path)) path <- file.path(repo_root, path)
  normalizePath(path, winslash = "/", mustWork = isTRUE(must_work))
}
read_csv <- function(path) utils::read.csv(resolve_path(path), check.names = FALSE, stringsAsFactors = FALSE)
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
sha256 <- function(path) unname(tools::sha256sum(resolve_path(path)))
tau_key <- function(x) sprintf("%.8f", as.numeric(x))

description <- read.dcf(file.path(repo_root, "DESCRIPTION"))
if (!identical(as.character(description[1L, "Package"]), "exdqlm") ||
    !identical(as.character(description[1L, "Version"]), "1.0.0")) {
  stop("Alpha/rho seed repair requires the exdqlm 1.0.0 baseline.", call. = FALSE)
}

workers <- suppressWarnings(as.integer(get_arg("--workers", "8")))
if (!is.finite(workers) || workers < 1L) workers <- 8L
workers <- min(workers, 12L)
refresh_staged <- has_flag("--refresh-grid")
historical_run_id <- get_arg("--historical-run-id", "qdesn_alpha_rho_cellwise_v2_20260801_011245")
historical_state_root <- resolve_path(file.path(
  "reports", "shared_fitforecast_v2_orchestration", historical_run_id
))

old_stage <- "qdesn_dynamic_fitforecast_v2_500obs_alpha_rho_cellwise_v2"
old_stub <- file.path("config", "validation", old_stage)
stage <- "qdesn_dynamic_fitforecast_v2_500obs_alpha_rho_seedrepair_v1"
stub <- file.path("config", "validation", stage)
evidence_root <- file.path("reports", "qdesn_mcmc_validation", stage, "materialization")

old_profiles <- read_csv(paste0(old_stub, "_profiles.csv"))
old_profiles$comparison_role <- "candidate"
parents <- read_csv(paste0(old_stub, "_parent_profiles.csv"))
selected_path <- file.path(historical_state_root, "coarse_audit", "coarse_selected_candidates.csv")
coarse_paired_path <- file.path(historical_state_root, "coarse_audit", "coarse_paired_metrics.csv")
selected <- read_csv(selected_path)
if (nrow(selected) != 13L) stop(sprintf("Expected 13 historical selected candidates; found %d.", nrow(selected)), call. = FALSE)

replicate_audit <- qdesn_arsr1_validate_replicate_separation(old_profiles, stop_on_fail = TRUE)
plan <- qdesn_arsr1_build_repair_plan(old_profiles, parents, selected, actual_seed = 123L)
if (nrow(plan$excluded) != 2L || !all(plan$excluded$target_cell_id == "exal_laplace_t0p25")) {
  stop("The historical actual-seed topology exclusion set is not the expected two Laplace p=0.25 controls.", call. = FALSE)
}

profiles_path <- write_csv(plan$profiles, paste0(stub, "_profiles.csv"))
assignments_path <- write_csv(plan$assignments, paste0(stub, "_cell_assignments.csv"))
validity_path <- write_csv(plan$validity, paste0(stub, "_historical_actual_seed_candidate_validity.csv"))
excluded_path <- write_csv(plan$excluded, paste0(stub, "_excluded_candidates.csv"))
replicate_audit_path <- write_csv(replicate_audit, paste0(stub, "_declared_replicate_seed_audit.csv"))
repair_topology <- qdesn_arsr1_topology_audit(plan$profiles)
repair_topology_path <- write_csv(repair_topology, paste0(stub, "_topology_audit.csv"))

# Forensic audit of the immutable completed campaign. This records what ran; it
# does not alter its configs, manifests, or result directories.
run_tags_path <- file.path(historical_state_root, "run_tags.env")
run_tags <- readLines(run_tags_path, warn = FALSE)
env_value <- function(name) {
  line <- run_tags[startsWith(run_tags, paste0(name, "="))]
  if (!length(line)) stop(sprintf("Missing %s in %s.", name, run_tags_path), call. = FALSE)
  sub(paste0("^", name, "="), "", line[[1L]])
}
historical_defaults <- yaml::read_yaml(resolve_path(paste0(old_stub, "_coarse_defaults.yaml")))
coarse_run_tag <- env_value("COARSE_RUN_TAG")
refinement_run_tag <- env_value("REFINEMENT_RUN_TAG")
coarse_root <- resolve_path(file.path(historical_defaults$campaign$results_root, coarse_run_tag))
refinement_defaults <- yaml::read_yaml(file.path(historical_state_root, "coarse_audit", "refinement_defaults.yaml"))
refinement_root <- resolve_path(file.path(refinement_defaults$campaign$results_root, refinement_run_tag))
profile_seed_map <- stats::setNames(as.integer(old_profiles$seed), old_profiles$screening_profile_id)
scan_requests <- function(run_root, phase) {
  paths <- list.files(run_root, pattern = "^fit_request[.]json$", recursive = TRUE, full.names = TRUE)
  rows <- lapply(paths, function(path) {
    x <- jsonlite::read_json(path, simplifyVector = TRUE)
    id <- as.character(x$root_spec$screening_profile_id %||% NA_character_)
    expected <- unname(profile_seed_map[id])
    data.frame(
      phase = phase,
      spec_id = as.character(x$spec_id %||% NA_character_),
      root_id = as.character(x$root_spec$root_id %||% NA_character_),
      screening_profile_id = id,
      expected_profile_seed = as.integer(expected),
      observed_root_seed = as.integer(x$root_spec$seed %||% NA_integer_),
      observed_root_desn_seed = as.integer(x$root_spec$desn_seed %||% NA_integer_),
      observed_config_desn_seed = as.integer(x$config$desn$seed %||% NA_integer_),
      seed_contract_match = is.finite(expected) && identical(as.integer(x$config$desn$seed), as.integer(expected)),
      fit_request_path = normalizePath(path, winslash = "/", mustWork = TRUE),
      fit_request_sha256 = unname(tools::sha256sum(path)),
      stringsAsFactors = FALSE
    )
  })
  if (length(rows)) do.call(rbind, rows) else data.frame(stringsAsFactors = FALSE)
}
historical_request_audit <- rbind(
  scan_requests(coarse_root, "coarse"),
  scan_requests(refinement_root, "refinement")
)
historical_request_audit_path <- write_csv(
  historical_request_audit,
  file.path(evidence_root, "historical_fit_request_seed_audit.csv")
)
historical_bad <- sum(!historical_request_audit$seed_contract_match)
if (nrow(historical_request_audit) != 309L || historical_bad < 1L ||
    length(unique(historical_request_audit$observed_config_desn_seed)) != 1L ||
    unique(historical_request_audit$observed_config_desn_seed) != 123L) {
  stop("Historical request audit did not reproduce the diagnosed 309-root seed defect.", call. = FALSE)
}
classification_path <- write_json(list(
  generated_at = as.character(Sys.time()),
  historical_run_id = historical_run_id,
  classification = "COMPLETE_WITH_REFINEMENT_SEED_CONTRACT_FAILURE",
  scientific_roots_complete = nrow(historical_request_audit),
  seed_contract_mismatches = historical_bad,
  observed_desn_seeds = unique(historical_request_audit$observed_config_desn_seed),
  interpretation = paste(
    "Coarse evidence remains usable as a paired seed-123 screen.",
    "The refinement cannot establish a second-reservoir replication and is not promotable."
  ),
  remediation_stage = stage
), file.path(evidence_root, "historical_campaign_classification.json"))

defaults <- historical_defaults
defaults$campaign <- list(
  name = stage,
  results_root = file.path("results", "qdesn_mcmc_validation", stage),
  reports_root = file.path("reports", "qdesn_mcmc_validation", stage)
)
defaults$execution$methods <- "mcmc"
defaults$execution$likelihood_families <- as.list(c("al", "exal"))
defaults$execution$allowed_fit_spec_ids <- NULL
defaults$execution$seed_policy <- list(mode = "shared", base_seed = 123L)
defaults$runtime$threads <- 1L
defaults$runtime$campaign_workers <- workers
defaults$runtime$workers <- workers
defaults$runtime$root_scheduler <- "load_balanced"
defaults$pipeline$outputs$keep_draws <- FALSE
defaults$pipeline$outputs$keep_mcmc_vb_init <- FALSE
defaults$pipeline$outputs$save_forecast_objects <- FALSE
defaults$pipeline$outputs$save_compact_fit_paths <- TRUE
defaults$pipeline$outputs$save_metric_summaries <- TRUE
defaults$pipeline$outputs$retain_full_rds_on_failure <- FALSE
defaults$screening_profiles <- list(
  enabled = TRUE,
  csv = sub(paste0("^", repo_root, "/?"), "", profiles_path),
  cell_assignments_csv = sub(paste0("^", repo_root, "/?"), "", assignments_path),
  priors = "rhs_ns",
  design = "Corrected second-reservoir replication of 11 valid cell-specific candidates plus five exact parents.",
  execution_grid_policy = "cell_specific_subset_grid_with_explicit_desn_seed",
  canonical_profile_count = nrow(plan$profiles),
  canonical_dataset_cell_count = 18L,
  canonical_qdesn_root_count = nrow(plan$profiles) * 18L,
  selected_assignment_root_count = 48L
)
defaults$reference_contract$expected_qdesn_roots <- nrow(plan$profiles) * 18L
defaults$reference_contract$expected_selected_qdesn_roots <- 48L
defaults$study_contract$id <- paste0(stage, "_2026_08_01")
defaults$study_contract$description <- paste(
  "Independent Q-DESN/exQ-DESN RHS alpha/rho seed-contract repair.",
  "Every candidate is paired to its exact parent on the same source, reservoir seed, and sampler seed."
)
defaults$study_contract$active_phase <- "corrected_second_reservoir"
defaults$study_contract$screening_policy <- list(
  unit = "candidate_or_parent_by_source_on_corrected_second_reservoir",
  target_cells = 5L,
  candidate_profiles = 11L,
  parent_profiles = 5L,
  source_replicates = 3L,
  expected_specs = 48L,
  comparison_policy = "paired_candidate_to_exact_parent_same_source_desn_seed_and_sampler_seed",
  selection_policy = "per_cell_objective_specific_no_global_winner",
  article_policy = "no_article_update_without_later_full_budget_frozen_source_confirmation"
)
defaults$study_contract$alpha_rho_seedrepair_v1 <- list(
  historical_run_id = historical_run_id,
  historical_classification_path = classification_path,
  historical_request_audit_path = historical_request_audit_path,
  historical_coarse_paired_metrics_path = coarse_paired_path,
  historical_coarse_paired_metrics_sha256 = sha256(coarse_paired_path),
  selected_candidates_path = selected_path,
  selected_candidates_sha256 = sha256(selected_path),
  actual_seed_candidate_validity_path = validity_path,
  excluded_candidates_path = excluded_path,
  seed_contract = paste(
    "grid.seed is a run-level seed; grid.desn_seed equals screening_profiles.seed;",
    "candidate and exact parent share MCMC, VB-warm-start, and synthesis seeds within each source cell"
  )
)

defaults_path <- resolve_path(paste0(stub, "_defaults.yaml"), FALSE)
yaml::write_yaml(defaults, defaults_path)
defaults_loaded <- exdqlm:::qdesn_dynamic_crossstudy_load_defaults(defaults_path)
canonical_grid <- exdqlm:::qdesn_dynamic_crossstudy_build_grid(
  defaults_loaded, refresh_materialized = refresh_staged, verbose = TRUE
)
exdqlm:::qdesn_dynamic_crossstudy_validate_grid(canonical_grid, defaults_loaded)

lookup_cols <- c(
  "screening_profile_id", "target_cell_id", "target_role", "likelihood_target",
  "target_family", "target_tau", "parent_profile_id", "candidate_id",
  "comparison_role", "search_id", "search_dimension", "topology_mode",
  "reservoir_replicate", "source_candidate_profile_id", "seed_contract_version"
)
lookup <- plan$profiles[, lookup_cols, drop = FALSE]
grid_key <- paste(canonical_grid$screening_profile_id, canonical_grid$source_family, tau_key(canonical_grid$tau), sep = "\r")
target_key <- paste(lookup$screening_profile_id, lookup$target_family, tau_key(lookup$target_tau), sep = "\r")
grid <- canonical_grid[grid_key %in% target_key, , drop = FALSE]
grid <- merge(grid, lookup, by = "screening_profile_id", all.x = TRUE, sort = FALSE)
grid <- qdesn_arsr1_assign_sampler_seeds(grid)
grid <- grid[order(grid$target_cell_id, grid$comparison_role, grid$candidate_id, grid$source_scenario), , drop = FALSE]
if (nrow(grid) != 48L || anyNA(grid$likelihood_target)) {
  stop(sprintf("Expected 48 seed-repair roots; found %d.", nrow(grid)), call. = FALSE)
}
seed_contract <- qdesn_arsr1_seed_contract_audit(grid, plan$profiles, stop_on_fail = TRUE)
grid_path <- write_csv(grid, paste0(stub, "_grid.csv"))
seed_contract_path <- write_csv(seed_contract, paste0(stub, "_seed_contract_audit.csv"))

atomic <- exdqlm:::qdesn_dynamic_fitforecast_atomic_spec_grid(
  grid, defaults = defaults_loaded, methods = "mcmc", likelihood_families = c("al", "exal")
)
atomic <- merge(
  atomic,
  lookup[, c("screening_profile_id", "target_cell_id", "candidate_id", "comparison_role", "likelihood_target"), drop = FALSE],
  by = "screening_profile_id", all.x = TRUE, sort = FALSE
)
target_specs <- atomic[atomic$likelihood_family == atomic$likelihood_target, , drop = FALSE]
target_specs <- target_specs[order(target_specs$target_cell_id, target_specs$comparison_role, target_specs$candidate_id, target_specs$root_id), , drop = FALSE]
if (nrow(target_specs) != 48L || anyDuplicated(target_specs$spec_id)) {
  stop(sprintf("Expected 48 unique target specs; found %d.", nrow(target_specs)), call. = FALSE)
}
target_specs_path <- write_csv(target_specs, paste0(stub, "_target_spec_ids.csv"))
defaults$execution$allowed_fit_spec_ids <- as.list(as.character(target_specs$spec_id))
defaults$study_contract$budget <- list(
  posterior_metric_draws = 100L,
  vb_sampling_nd_draws = 100L,
  vb_synthesis_n_samp = 100L,
  mcmc_n_burn = 1000L,
  mcmc_n_mcmc = 3000L,
  mcmc_thin = 1L
)
yaml::write_yaml(defaults, defaults_path)

# Two-root executable smoke: the same AL candidate under its declared first and
# second reservoirs, with all other run-level seeds paired.
smoke_candidate <- "arv2_al_normal_t0p05_full_alpha_rho_safeguard_p04"
smoke_profiles <- old_profiles[
  old_profiles$candidate_id == smoke_candidate & old_profiles$reservoir_replicate %in% c(1L, 2L),
  , drop = FALSE
]
if (nrow(smoke_profiles) != 2L) stop("Could not resolve two reservoir profiles for the seed smoke.", call. = FALSE)
smoke_profiles$source_candidate_profile_id <- smoke_profiles$screening_profile_id
smoke_profiles$screening_profile_id <- paste0("arsr1_smoke_", c("seed1", "seed2"))
smoke_profiles$screening_stage <- "mcmc_alpha_rho_seedrepair_v1_smoke"
smoke_profiles$screening_wave <- "alpha_rho_seedrepair_v1_smoke_2026_08_01"
smoke_profiles$comparison_role <- "seed_smoke"
smoke_profiles$seed_contract_version <- "screening_profile_desn_seed_v1"
smoke_profiles_path <- write_csv(smoke_profiles, paste0(stub, "_smoke_profiles.csv"))

smoke_defaults <- defaults
smoke_defaults$campaign$name <- paste0(stage, "_smoke")
smoke_defaults$campaign$results_root <- file.path("results", "qdesn_mcmc_validation", paste0(stage, "_smoke"))
smoke_defaults$campaign$reports_root <- file.path("reports", "qdesn_mcmc_validation", paste0(stage, "_smoke"))
smoke_defaults$screening_profiles$csv <- sub(paste0("^", repo_root, "/?"), "", smoke_profiles_path)
smoke_defaults$screening_profiles$cell_assignments_csv <- NULL
smoke_defaults$screening_profiles$canonical_profile_count <- 2L
smoke_defaults$screening_profiles$canonical_qdesn_root_count <- 36L
smoke_defaults$screening_profiles$selected_assignment_root_count <- 2L
smoke_defaults$reference_contract$expected_qdesn_roots <- 36L
smoke_defaults$reference_contract$expected_selected_qdesn_roots <- 2L
smoke_defaults$study_contract$id <- paste0(stage, "_seed_smoke_2026_08_01")
smoke_defaults$study_contract$active_phase <- "two_reservoir_executable_smoke"
smoke_defaults$pipeline$inference$mcmc$n_burn <- 4L
smoke_defaults$pipeline$inference$mcmc$n_mcmc <- 4L
smoke_defaults$pipeline$inference$mcmc$thin <- 1L
smoke_defaults$pipeline$inference$mcmc$progress_every <- 1L
smoke_defaults$pipeline$inference$mcmc$prior_overrides$rhs_ns$n_burn <- 4L
smoke_defaults$pipeline$inference$mcmc$prior_overrides$rhs_ns$n_mcmc <- 4L
smoke_defaults$pipeline$inference$mcmc$prior_overrides$rhs_ns$progress_every <- 1L
smoke_defaults$study_contract$budget <- list(
  posterior_metric_draws = 4L,
  vb_sampling_nd_draws = 4L,
  vb_synthesis_n_samp = 4L,
  mcmc_n_burn = 4L,
  mcmc_n_mcmc = 4L,
  mcmc_thin = 1L
)
smoke_defaults$metrics$posterior_metric_draws <- 4L
smoke_defaults$pipeline$sampling$nd_draws <- 4L
smoke_defaults$pipeline$synthesis$n_samp <- 4L
smoke_defaults$execution$allowed_fit_spec_ids <- NULL
smoke_defaults_path <- resolve_path(paste0(stub, "_smoke_defaults.yaml"), FALSE)
yaml::write_yaml(smoke_defaults, smoke_defaults_path)
smoke_loaded <- exdqlm:::qdesn_dynamic_crossstudy_load_defaults(smoke_defaults_path)
smoke_canonical <- exdqlm:::qdesn_dynamic_crossstudy_build_grid(smoke_loaded, refresh_materialized = FALSE, verbose = FALSE)
smoke_source <- sort(unique(as.character(smoke_canonical$source_scenario)))[[1L]]
smoke_grid <- smoke_canonical[
  smoke_canonical$screening_profile_id %in% smoke_profiles$screening_profile_id &
    smoke_canonical$source_family == "normal" & abs(smoke_canonical$tau - 0.05) < 1e-12 &
    smoke_canonical$source_scenario == smoke_source,
  , drop = FALSE
]
smoke_lookup <- smoke_profiles[, c(
  "screening_profile_id", "target_cell_id", "target_role", "likelihood_target",
  "target_family", "target_tau", "parent_profile_id", "candidate_id",
  "comparison_role", "reservoir_replicate", "source_candidate_profile_id", "seed_contract_version"
), drop = FALSE]
smoke_grid <- merge(smoke_grid, smoke_lookup, by = "screening_profile_id", all.x = TRUE, sort = FALSE)
smoke_grid <- qdesn_arsr1_assign_sampler_seeds(smoke_grid)
if (nrow(smoke_grid) != 2L || length(unique(smoke_grid$desn_seed)) != 2L) {
  stop("The executable seed smoke did not materialize two distinct reservoir seeds.", call. = FALSE)
}
smoke_seed_contract <- qdesn_arsr1_seed_contract_audit(smoke_grid, smoke_profiles, stop_on_fail = TRUE)
smoke_grid_path <- write_csv(smoke_grid, paste0(stub, "_smoke_grid.csv"))
smoke_seed_contract_path <- write_csv(smoke_seed_contract, paste0(stub, "_smoke_seed_contract_audit.csv"))
smoke_atomic <- exdqlm:::qdesn_dynamic_fitforecast_atomic_spec_grid(
  smoke_grid, defaults = smoke_loaded, methods = "mcmc", likelihood_families = c("al", "exal")
)
smoke_specs <- smoke_atomic[smoke_atomic$likelihood_family == "al", , drop = FALSE]
if (nrow(smoke_specs) != 2L || anyDuplicated(smoke_specs$spec_id)) stop("Seed-smoke spec construction failed.", call. = FALSE)
smoke_specs_path <- write_csv(smoke_specs, paste0(stub, "_smoke_target_spec_ids.csv"))
smoke_defaults$execution$allowed_fit_spec_ids <- as.list(as.character(smoke_specs$spec_id))
yaml::write_yaml(smoke_defaults, smoke_defaults_path)

manifest <- list(
  generated_at = as.character(Sys.time()),
  stage = stage,
  package_version = as.character(description[1L, "Version"]),
  git_branch = trimws(system("git branch --show-current", intern = TRUE)),
  git_commit = trimws(system("git rev-parse HEAD", intern = TRUE)),
  historical_run = list(
    run_id = historical_run_id,
    classification = "COMPLETE_WITH_REFINEMENT_SEED_CONTRACT_FAILURE",
    completed_fit_requests = nrow(historical_request_audit),
    seed_contract_mismatches = historical_bad,
    classification_path = classification_path,
    request_audit_path = historical_request_audit_path
  ),
  source_registry_path = historical_defaults$study_contract$alpha_rho_cellwise_v2$frozen_source_registry_path,
  source_registry_sha256 = historical_defaults$study_contract$alpha_rho_cellwise_v2$frozen_source_registry_sha256,
  profiles_path = profiles_path,
  profiles_sha256 = sha256(profiles_path),
  assignments_path = assignments_path,
  assignments_sha256 = sha256(assignments_path),
  grid_path = grid_path,
  grid_sha256 = sha256(grid_path),
  target_specs_path = target_specs_path,
  target_specs_sha256 = sha256(target_specs_path),
  defaults_path = defaults_path,
  defaults_sha256 = sha256(defaults_path),
  seed_contract_audit_path = seed_contract_path,
  seed_contract_audit_sha256 = sha256(seed_contract_path),
  historical_actual_seed_candidate_validity_path = validity_path,
  excluded_candidates_path = excluded_path,
  repair_topology_audit_path = repair_topology_path,
  smoke = list(
    profiles_path = smoke_profiles_path,
    defaults_path = smoke_defaults_path,
    grid_path = smoke_grid_path,
    target_specs_path = smoke_specs_path,
    seed_contract_audit_path = smoke_seed_contract_path,
    expected_specs = 2L
  ),
  counts = list(
    retained_candidates = 11L,
    excluded_candidates = 2L,
    exact_parent_controls = 5L,
    source_replicates = 3L,
    expected_full_specs = 48L
  ),
  launch_state = "materialized_not_launched"
)
manifest_path <- write_json(manifest, paste0(stub, "_materialization_manifest.json"))

cat(sprintf("Materialization manifest: %s\n", manifest_path))
cat(sprintf("Historical classification: COMPLETE_WITH_REFINEMENT_SEED_CONTRACT_FAILURE (%d/%d mismatches)\n", historical_bad, nrow(historical_request_audit)))
cat(sprintf("Repair profiles: %d candidates + %d exact parents\n", sum(plan$profiles$comparison_role == "candidate"), sum(plan$profiles$comparison_role == "parent_exact")))
cat(sprintf("Executable smoke specs: %d\n", nrow(smoke_specs)))
cat(sprintf("Full repair specs: %d\n", nrow(target_specs)))

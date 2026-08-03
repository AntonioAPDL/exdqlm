#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  required <- c("jsonlite", "pkgload", "yaml")
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
has_flag <- function(flag) any(args == flag)
`%||%` <- function(x, y) if (is.null(x) || !length(x)) y else x

repo_root <- normalizePath(
  system("git rev-parse --show-toplevel", intern = TRUE),
  winslash = "/",
  mustWork = TRUE
)
setwd(repo_root)
pkgload::load_all(repo_root, quiet = TRUE)
source(file.path(
  repo_root, "validation", "fitforecast_v2", "R",
  "qdesn_alpha_rho_confirmation_v1.R"
))

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
  normalizePath(path, winslash = "/", mustWork = TRUE)
}
write_json <- function(value, path) {
  path <- resolve_path(path, FALSE)
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  jsonlite::write_json(
    value, path, pretty = TRUE, auto_unbox = TRUE, null = "null", digits = NA
  )
  normalizePath(path, winslash = "/", mustWork = TRUE)
}
sha256 <- function(path) unname(tools::sha256sum(resolve_path(path)))
tau_key <- function(x) sprintf("%.8f", as.numeric(x))
as_bool <- function(x) {
  if (is.logical(x)) return(x)
  toupper(trimws(as.character(x))) %in% c("TRUE", "T", "1", "YES")
}

description <- read.dcf(file.path(repo_root, "DESCRIPTION"))
if (!identical(as.character(description[1L, "Package"]), "exdqlm") ||
    !identical(as.character(description[1L, "Version"]), "1.0.0")) {
  stop("Alpha/rho confirmation requires the exdqlm 1.0.0 baseline.", call. = FALSE)
}

stage <- "qdesn_dynamic_fitforecast_v2_500obs_alpha_rho_confirmation_v1"
stub <- file.path("config", "validation", stage)
base_defaults_path <- file.path(
  "config", "validation",
  "qdesn_dynamic_fitforecast_v2_tt500_mcmc_external_coherent_confirmation_v1_defaults.yaml"
)
cellwise_stub <- file.path(
  "config", "validation",
  "qdesn_dynamic_fitforecast_v2_500obs_alpha_rho_cellwise_v2"
)
handoff_path <- file.path(
  "validation", "fitforecast_v2", "docs",
  "qdesn_500obs_mcmc_alpha_rho_seedrepair_v1_full_budget_handoff_20260801.csv"
)
seed_gate_path <- file.path(
  "reports", "shared_fitforecast_v2_orchestration",
  "qdesn_alpha_rho_seedrepair_v1_20260801_192732", "audit",
  "seedrepair_gate.json"
)
article_envelope_path <- file.path(
  "validation", "fitforecast_v2", "promotions",
  "qdesn_dqlm_500obs_mcmc_metric_envelope_20260727",
  "qdesn_dqlm_500obs_mcmc_metric_envelope_20260727_article_envelope.csv"
)
canonical_registry_path <- get_arg(
  "--source-registry",
  paste0(
    "/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/",
    "validation/fitforecast_v2/runs/",
    "20260704_exdqlm_dqlm_c13_mcmc_500obs_refresh_v2/manifests/source_registry.csv"
  )
)
expected_registry_hash <- paste0(
  "edddb56fc2b30e49ac99fdd08b53dad468ed53e05d0fe1fe16426ee9d9ffe275"
)
expected_scenario <- paste0(
  "dlm_constV_p90_m0amp_highnoise_steepertrend_v2_",
  "TTmain10000_fitforecast"
)
workers <- suppressWarnings(as.integer(get_arg("--workers", "8")))
if (!is.finite(workers) || workers < 1L) workers <- 8L
workers <- min(workers, 8L)
refresh_materialized <- has_flag("--refresh-materialized")

handoff <- read_csv(handoff_path)
profiles_source <- read_csv(paste0(cellwise_stub, "_profiles.csv"))
parents_source <- read_csv(paste0(cellwise_stub, "_parent_profiles.csv"))
seed_gate <- jsonlite::read_json(resolve_path(seed_gate_path), simplifyVector = TRUE)
article_envelope <- read_csv(article_envelope_path)
canonical_registry <- read_csv(canonical_registry_path)
if (!identical(as.character(seed_gate$decision), "FULL_BUDGET_HANDOFF_PREPARED") ||
    as.integer(seed_gate$full_budget_handoff_count) != 2L) {
  stop("Seed-repair evidence does not authorize the two-root-set confirmation handoff.", call. = FALSE)
}
if (any(as.character(article_envelope$source_registry_hash_value) != expected_registry_hash)) {
  stop("The current article envelope does not use the frozen shared registry hash.", call. = FALSE)
}

plan <- qdesn_arfc1_build_plan(profiles_source, parents_source, handoff)
profiles_path <- write_csv(plan$profiles, paste0(stub, "_profiles.csv"))
assignments_path <- write_csv(plan$assignments, paste0(stub, "_cell_assignments.csv"))
cell_plan_path <- write_csv(plan$cell_plan, paste0(stub, "_cell_plan.csv"))

registry <- canonical_registry[
  canonical_registry$scenario_id == expected_scenario &
    canonical_registry$fit_size == 500L &
    paste(canonical_registry$family, tau_key(canonical_registry$tau), sep = "\r") %in%
      paste(plan$cell_plan$family, tau_key(plan$cell_plan$tau), sep = "\r"),
  ,
  drop = FALSE
]
if (nrow(registry) != 2L ||
    any(!as_bool(registry$source_present)) ||
    !setequal(registry$family, c("gausmix", "laplace")) ||
    !setequal(as.numeric(registry$tau), c(0.25, 0.05)) ||
    any(as.integer(registry$TT_warmup) != 2000L) ||
    any(as.integer(registry$TT_main) != 10000L) ||
    any(as.integer(registry$TT_total) != 12000L) ||
    any(as.integer(registry$train_start_source_index) != 8501L) ||
    any(as.integer(registry$train_end_source_index) != 9000L) ||
    any(as.integer(registry$forecast_origin_source_index) != 9000L) ||
    any(as.integer(registry$forecast_start_source_index) != 9001L) ||
    any(as.integer(registry$forecast_end_source_index) != 10000L) ||
    any(as.integer(registry$max_lead_configured) != 30L) ||
    any(as.integer(registry$origin_stride) != 30L) ||
    any(as_bool(registry$refit_per_origin))) {
  stop("The selected frozen source-registry rows violate the confirmation protocol.", call. = FALSE)
}
source_roles <- c("series_wide", "true_quantile_grid", "sim_output", "meta")
source_path_cols <- paste0(source_roles, "_path")
source_hash_cols <- paste0(source_roles, "_sha256")
source_file_rows <- lapply(seq_len(nrow(registry)), function(i) {
  do.call(rbind, lapply(seq_along(source_roles), function(j) {
    path <- as.character(registry[[source_path_cols[[j]]]][[i]])
    expected <- as.character(registry[[source_hash_cols[[j]]]][[i]])
    data.frame(
      source_cell_id = registry$source_cell_id[[i]],
      role = source_roles[[j]],
      path = path,
      expected_sha256 = expected,
      file_exists = file.exists(path),
      observed_sha256 = if (file.exists(path)) unname(tools::sha256sum(path)) else NA_character_,
      stringsAsFactors = FALSE
    )
  }))
})
source_file_audit <- do.call(rbind, source_file_rows)
source_file_audit$hash_match <- with(
  source_file_audit,
  file_exists & expected_sha256 == observed_sha256
)
if (!all(source_file_audit$hash_match)) {
  stop("One or more canonical source files fail their frozen SHA-256 contract.", call. = FALSE)
}
source_registry_path <- write_csv(registry, paste0(stub, "_source_registry.csv"))
source_file_audit_path <- write_csv(
  source_file_audit, paste0(stub, "_source_file_hash_audit.csv")
)

defaults <- yaml::read_yaml(resolve_path(base_defaults_path))
defaults$campaign <- list(
  name = stage,
  results_root = file.path("results", "qdesn_mcmc_validation", stage),
  reports_root = file.path("reports", "qdesn_mcmc_validation", stage)
)
defaults$execution$methods <- "mcmc"
defaults$execution$likelihood_families <- "exal"
defaults$execution$allowed_fit_spec_ids <- NULL
defaults$execution$seed_policy <- list(mode = "shared", base_seed = 123L)
defaults$runtime$threads <- 1L
defaults$runtime$campaign_workers <- workers
defaults$runtime$workers <- workers
defaults$runtime$root_scheduler <- "load_balanced"
defaults$multiseed <- list(
  enabled = FALSE,
  mcmc_seed_reps = 1L,
  parallel_seed_workers = 1L,
  selection_metric = "paired_candidate_parent_confirmation",
  prune_nonwinning_heavy_outputs = TRUE
)
defaults$pipeline$outputs$keep_draws <- FALSE
defaults$pipeline$outputs$keep_mcmc_vb_init <- FALSE
defaults$pipeline$outputs$save_forecast_objects <- FALSE
defaults$pipeline$outputs$save_compact_fit_paths <- TRUE
defaults$pipeline$outputs$save_metric_summaries <- TRUE
defaults$pipeline$outputs$retain_full_rds_on_failure <- FALSE
defaults$pipeline$outputs$retention_profile <- "storage_light_confirmation"
defaults$pipeline$inference$mcmc$n_burn <- 5000L
defaults$pipeline$inference$mcmc$n_mcmc <- 20000L
defaults$pipeline$inference$mcmc$thin <- 1L
defaults$pipeline$inference$mcmc$progress_every <- 50L
defaults$pipeline$inference$mcmc$prior_overrides$rhs_ns$n_burn <- 5000L
defaults$pipeline$inference$mcmc$prior_overrides$rhs_ns$n_mcmc <- 20000L
defaults$pipeline$inference$mcmc$prior_overrides$rhs_ns$progress_every <- 50L
defaults$pipeline$sampling$nd_draws <- 200L
defaults$pipeline$synthesis$n_samp <- 200L
defaults$metrics$posterior_metric_draws <- 200L
defaults$screening_profiles <- list(
  enabled = TRUE,
  csv = sub(paste0("^", repo_root, "/?"), "", profiles_path),
  cell_assignments_csv = sub(paste0("^", repo_root, "/?"), "", assignments_path),
  priors = "rhs_ns",
  design = paste(
    "Eight explicit full-budget roots: two cells by candidate/parent by two",
    "frozen reservoir realizations. Generic multiseed expansion is forbidden."
  ),
  execution_grid_policy = "eight_explicit_paired_roots",
  canonical_profile_count = 8L,
  canonical_dataset_cell_count = 9L,
  canonical_qdesn_root_count = 72L,
  selected_assignment_root_count = 8L
)
defaults$reference_contract$expected_unique_dataset_cells <- 9L
defaults$reference_contract$expected_qdesn_roots <- 72L
defaults$reference_contract$expected_priors <- "rhs_ns"
defaults$reference_contract$expected_selected_qdesn_roots <- 8L
defaults$study_contract$id <- paste0(stage, "_2026_08_03")
defaults$study_contract$description <- paste(
  "Full-budget frozen-source confirmation of two objective-specific alpha/rho",
  "candidates against exact parents. This does not modify exdqlm 1.0.0 core inference."
)
defaults$study_contract$budget <- list(
  posterior_metric_draws = 200L,
  vb_sampling_nd_draws = 200L,
  vb_synthesis_n_samp = 200L,
  mcmc_n_burn = 5000L,
  mcmc_n_mcmc = 20000L,
  mcmc_thin = 1L
)
defaults$study_contract$screening_policy <- list(
  unit = "cell_by_reservoir_candidate_parent_pair",
  target_cells = 2L,
  reservoir_replicates = 2L,
  expected_specs = 8L,
  comparison_policy = "paired_same_source_reservoir_and_sampler_seeds",
  selection_policy = "objective_specific_no_global_winner",
  diagnostic_policy = "reported_not_metric_suppressing",
  article_policy = "manual_metricwise_review_after_closeout_only"
)
defaults$study_contract$alpha_rho_confirmation_v1 <- list(
  seedrepair_gate_path = resolve_path(seed_gate_path),
  seedrepair_gate_sha256 = sha256(seed_gate_path),
  handoff_path = resolve_path(handoff_path),
  handoff_sha256 = sha256(handoff_path),
  source_registry_identity_field = "source_registry_hash_value",
  source_registry_hash_value = expected_registry_hash,
  canonical_registry_path = resolve_path(canonical_registry_path),
  canonical_registry_sha256 = sha256(canonical_registry_path),
  frozen_registry_snapshot_path = source_registry_path,
  frozen_registry_snapshot_sha256 = sha256(source_registry_path),
  source_file_hash_audit_path = source_file_audit_path,
  article_envelope_path = resolve_path(article_envelope_path),
  article_envelope_sha256 = sha256(article_envelope_path),
  generic_multiseed_forbidden = TRUE,
  confirmation_status = "materialized_not_launched"
)
defaults_path <- resolve_path(paste0(stub, "_defaults.yaml"), FALSE)
yaml::write_yaml(defaults, defaults_path)

loaded <- exdqlm:::qdesn_dynamic_crossstudy_load_defaults(defaults_path)
canonical_grid <- exdqlm:::qdesn_dynamic_crossstudy_build_grid(
  loaded,
  refresh_materialized = refresh_materialized,
  verbose = TRUE
)
exdqlm:::qdesn_dynamic_crossstudy_validate_grid(canonical_grid, loaded)
grid_key <- paste(
  canonical_grid$screening_profile_id,
  canonical_grid$source_family,
  tau_key(canonical_grid$tau),
  sep = "\r"
)
target_key <- paste(
  plan$profiles$screening_profile_id,
  plan$profiles$target_family,
  tau_key(plan$profiles$target_tau),
  sep = "\r"
)
grid <- canonical_grid[
  grid_key %in% target_key & canonical_grid$source_scenario == expected_scenario,
  ,
  drop = FALSE
]
lookup_fields <- c(
  "screening_profile_id", "target_cell_id", "target_role", "likelihood_target",
  "target_family", "target_tau", "parent_profile_id", "candidate_id",
  "comparison_role", "reservoir_replicate", "confirmation_pair_id",
  "source_screening_profile_id", "search_id", "search_dimension",
  "search_priority", "topology_mode"
)
lookup <- plan$profiles[, lookup_fields, drop = FALSE]
lookup_index <- match(grid$screening_profile_id, lookup$screening_profile_id)
for (field in setdiff(lookup_fields, "screening_profile_id")) {
  grid[[field]] <- lookup[[field]][lookup_index]
}
grid$source_registry_hash_value <- expected_registry_hash
grid <- qdesn_arfc1_assign_execution_seeds(grid, plan$profiles)
grid <- grid[order(
  grid$target_cell_id, grid$reservoir_replicate, grid$comparison_role
), , drop = FALSE]
if (nrow(grid) != 8L || anyNA(grid$target_cell_id) || anyDuplicated(grid$root_id) ||
    any(as.integer(grid$train_start_source_index) != 8501L) ||
    any(as.integer(grid$train_end_source_index) != 9000L) ||
    any(as.integer(grid$forecast_start_source_index) != 9001L) ||
    any(as.integer(grid$forecast_end_source_index) != 10000L)) {
  stop(sprintf("Expected eight exact frozen-source grid rows; found %d.", nrow(grid)), call. = FALSE)
}
staged_roles <- c("source_series_wide", "source_selection_indices", "source_sim")
staged_audit <- do.call(rbind, lapply(seq_len(nrow(grid)), function(i) {
  do.call(rbind, lapply(staged_roles, function(role) {
    path <- as.character(grid[[paste0(role, "_path")]][[i]])
    expected <- as.character(grid[[paste0(role, "_sha256")]][[i]])
    data.frame(
      root_id = grid$root_id[[i]], role = role, path = path,
      expected_sha256 = expected, file_exists = file.exists(path),
      observed_sha256 = if (file.exists(path)) unname(tools::sha256sum(path)) else NA_character_,
      stringsAsFactors = FALSE
    )
  }))
}))
staged_audit$hash_match <- with(
  staged_audit, file_exists & expected_sha256 == observed_sha256
)
if (!all(staged_audit$hash_match)) {
  stop("One or more staged fit/forecast source files fail SHA-256 verification.", call. = FALSE)
}
seed_audit <- qdesn_arfc1_seed_contract_audit(grid, plan$profiles, TRUE)
grid_path <- write_csv(grid, paste0(stub, "_grid.csv"))
seed_audit_path <- write_csv(seed_audit, paste0(stub, "_seed_contract_audit.csv"))
staged_audit_path <- write_csv(staged_audit, paste0(stub, "_staged_source_hash_audit.csv"))

atomic <- exdqlm:::qdesn_dynamic_fitforecast_atomic_spec_grid(
  grid, defaults = loaded, methods = "mcmc", likelihood_families = "exal"
)
atomic_index <- match(atomic$root_id, grid$root_id)
for (field in c(
  "target_cell_id", "comparison_role", "reservoir_replicate",
  "confirmation_pair_id", "candidate_id", "likelihood_target"
)) {
  atomic[[field]] <- grid[[field]][atomic_index]
}
target_specs <- atomic[atomic$likelihood_family == atomic$likelihood_target, , drop = FALSE]
target_specs <- target_specs[order(
  target_specs$target_cell_id,
  target_specs$reservoir_replicate,
  target_specs$comparison_role
), , drop = FALSE]
if (nrow(target_specs) != 8L || anyDuplicated(target_specs$spec_id)) {
  stop(sprintf("Expected eight unique MCMC/exAL specs; found %d.", nrow(target_specs)), call. = FALSE)
}
target_specs_path <- write_csv(target_specs, paste0(stub, "_target_spec_ids.csv"))
defaults$execution$allowed_fit_spec_ids <- as.list(as.character(target_specs$spec_id))
yaml::write_yaml(defaults, defaults_path)

smoke_grid <- grid[
  grid$reservoir_replicate == 1L,
  ,
  drop = FALSE
]
smoke_specs <- target_specs[target_specs$root_id %in% smoke_grid$root_id, , drop = FALSE]
if (nrow(smoke_grid) != 4L || nrow(smoke_specs) != 4L ||
    any(table(smoke_grid$confirmation_pair_id) != 2L)) {
  stop("The executable smoke is not four paired first-reservoir roots.", call. = FALSE)
}
smoke_defaults <- defaults
smoke_defaults$campaign$name <- paste0(stage, "_smoke")
smoke_defaults$campaign$results_root <- file.path(
  "results", "qdesn_mcmc_validation", paste0(stage, "_smoke")
)
smoke_defaults$campaign$reports_root <- file.path(
  "reports", "qdesn_mcmc_validation", paste0(stage, "_smoke")
)
smoke_defaults$execution$allowed_fit_spec_ids <- as.list(as.character(smoke_specs$spec_id))
smoke_defaults$runtime$campaign_workers <- 4L
smoke_defaults$runtime$workers <- 4L
smoke_defaults$reference_contract$expected_selected_qdesn_roots <- 4L
smoke_defaults$screening_profiles$selected_assignment_root_count <- 4L
smoke_defaults$pipeline$inference$mcmc$n_burn <- 4L
smoke_defaults$pipeline$inference$mcmc$n_mcmc <- 4L
smoke_defaults$pipeline$inference$mcmc$thin <- 1L
smoke_defaults$pipeline$inference$mcmc$progress_every <- 1L
smoke_defaults$pipeline$inference$mcmc$prior_overrides$rhs_ns$n_burn <- 4L
smoke_defaults$pipeline$inference$mcmc$prior_overrides$rhs_ns$n_mcmc <- 4L
smoke_defaults$pipeline$inference$mcmc$prior_overrides$rhs_ns$progress_every <- 1L
smoke_defaults$pipeline$sampling$nd_draws <- 4L
smoke_defaults$pipeline$synthesis$n_samp <- 4L
smoke_defaults$metrics$posterior_metric_draws <- 4L
smoke_defaults$study_contract$budget <- list(
  posterior_metric_draws = 4L,
  vb_sampling_nd_draws = 4L,
  vb_synthesis_n_samp = 4L,
  mcmc_n_burn = 4L,
  mcmc_n_mcmc = 4L,
  mcmc_thin = 1L
)
smoke_defaults$study_contract$alpha_rho_confirmation_v1$confirmation_status <-
  "executable_smoke"
smoke_defaults_path <- resolve_path(paste0(stub, "_smoke_defaults.yaml"), FALSE)
yaml::write_yaml(smoke_defaults, smoke_defaults_path)
smoke_grid_path <- write_csv(smoke_grid, paste0(stub, "_smoke_grid.csv"))
smoke_specs_path <- write_csv(smoke_specs, paste0(stub, "_smoke_target_spec_ids.csv"))

article_context <- article_envelope[
  article_envelope$family %in% c("gausmix", "laplace") &
    abs(article_envelope$tau - ifelse(
      article_envelope$family == "gausmix", 0.25, 0.05
    )) <= 1e-12,
  ,
  drop = FALSE
]
article_context_path <- write_csv(
  article_context, paste0(stub, "_current_article_metric_context.csv")
)
contract <- data.frame(
  target_cell_id = c("exal_gausmix_t0p25", "exal_laplace_t0p05"),
  primary_objective = c("forecast_transport", "fit_recovery"),
  primary_ratio_gate = c(0.95, 0.98),
  companion_median_ratio_max = c(1.05, 1.05),
  individual_ratio_max = c(1.20, 1.20),
  candidate_parent_pairing = "same_source_reservoir_and_sampler_seeds",
  article_update_automatic = FALSE,
  stringsAsFactors = FALSE
)
contract_path <- write_csv(contract, paste0(stub, "_confirmation_contract.csv"))

source_files <- c(
  helper = file.path(
    "validation", "fitforecast_v2", "R", "qdesn_alpha_rho_confirmation_v1.R"
  ),
  base_defaults = base_defaults_path,
  handoff = handoff_path,
  seed_gate = seed_gate_path,
  cellwise_profiles = paste0(cellwise_stub, "_profiles.csv"),
  parent_profiles = paste0(cellwise_stub, "_parent_profiles.csv"),
  article_envelope = article_envelope_path,
  canonical_registry = canonical_registry_path
)
source_manifest <- data.frame(
  role = names(source_files),
  path = vapply(source_files, resolve_path, character(1L)),
  sha256 = vapply(source_files, sha256, character(1L)),
  stringsAsFactors = FALSE
)
source_manifest_path <- write_csv(
  source_manifest, paste0(stub, "_source_manifest.csv")
)
generated_files <- c(
  profiles = profiles_path,
  assignments = assignments_path,
  cell_plan = cell_plan_path,
  defaults = defaults_path,
  grid = grid_path,
  target_specs = target_specs_path,
  seed_audit = seed_audit_path,
  source_registry = source_registry_path,
  source_file_audit = source_file_audit_path,
  staged_source_audit = staged_audit_path,
  smoke_defaults = smoke_defaults_path,
  smoke_grid = smoke_grid_path,
  smoke_specs = smoke_specs_path,
  article_context = article_context_path,
  confirmation_contract = contract_path,
  source_manifest = source_manifest_path
)
generated_manifest <- data.frame(
  role = names(generated_files),
  path = unname(generated_files),
  sha256 = vapply(generated_files, sha256, character(1L)),
  stringsAsFactors = FALSE
)
generated_manifest_path <- write_csv(
  generated_manifest, paste0(stub, "_generated_file_manifest.csv")
)
manifest <- list(
  generated_at = as.character(Sys.time()),
  stage = stage,
  package_version = as.character(description[1L, "Version"]),
  git_branch = trimws(system("git branch --show-current", intern = TRUE)),
  git_commit = trimws(system("git rev-parse HEAD", intern = TRUE)),
  source_registry_identity_field = "source_registry_hash_value",
  source_registry_hash_value = expected_registry_hash,
  source_registry_path = source_registry_path,
  source_registry_sha256 = sha256(source_registry_path),
  source_file_hashes_verified = all(source_file_audit$hash_match),
  staged_source_hashes_verified = all(staged_audit$hash_match),
  seed_contract_verified = all(seed_audit$status == "PASS"),
  counts = list(
    target_cells = 2L,
    reservoir_replicates = 2L,
    candidate_roots = 4L,
    parent_roots = 4L,
    full_specs = 8L,
    smoke_specs = 4L
  ),
  budget = list(n_burn = 5000L, n_mcmc = 20000L, metric_draws = 200L),
  rolling_origin = list(
    forecast_origin_source_index = 9000L,
    forecast_block = c(9001L, 10000L),
    max_lead = 30L,
    origin_stride = 30L,
    refit_per_origin = FALSE
  ),
  generic_multiseed_enabled = FALSE,
  article_update_automatic = FALSE,
  launch_status = "materialized_not_launched",
  generated_file_manifest_path = generated_manifest_path
)
manifest_path <- write_json(
  manifest, paste0(stub, "_materialization_manifest.json")
)

cat(sprintf("Materialization manifest: %s\n", manifest_path))
cat(sprintf("Frozen registry hash: %s\n", expected_registry_hash))
cat(sprintf("Full confirmation specs: %d\n", nrow(target_specs)))
cat(sprintf("Executable smoke specs: %d\n", nrow(smoke_specs)))
cat("Generic multiseed: disabled\n")

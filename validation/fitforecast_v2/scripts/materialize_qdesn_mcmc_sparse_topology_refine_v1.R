#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  required <- c("digest", "jsonlite", "pkgload", "yaml")
  missing <- setdiff(required, rownames(installed.packages()))
  if (length(missing)) stop(sprintf("Missing package(s): %s", paste(missing, collapse = ", ")), call. = FALSE)
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
  winslash = "/", mustWork = TRUE
)
setwd(repo_root)
pkgload::load_all(repo_root, quiet = TRUE)
source(file.path(repo_root, "validation", "fitforecast_v2", "R", "qdesn_alpha_rho_topology_v1.R"))
source(file.path(repo_root, "validation", "fitforecast_v2", "R", "qdesn_mcmc_highalpha_cellwise_v1.R"))
source(file.path(repo_root, "validation", "fitforecast_v2", "R", "qdesn_mcmc_dynamic_seedrepair_v1.R"))
source(file.path(repo_root, "validation", "fitforecast_v2", "R", "qdesn_mcmc_sparse_topology_refine_v1.R"))

resolve_path <- function(path, must_work = TRUE) {
  path <- as.character(path)[1L]
  if (!grepl("^/", path)) path <- file.path(repo_root, path)
  normalizePath(path, winslash = "/", mustWork = isTRUE(must_work))
}
rel_path <- function(path) {
  path <- resolve_path(path, FALSE)
  prefix <- paste0("^", gsub("([].[^$*+?{}|()\\\\])", "\\\\\\1", repo_root), "/?")
  sub(prefix, "", path)
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
  jsonlite::write_json(value, path, pretty = TRUE, auto_unbox = TRUE, null = "null", digits = NA)
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
  stop("Sparse topology refinement requires exdqlm 1.0.0.", call. = FALSE)
}

workers <- suppressWarnings(as.integer(get_arg("--workers", "20"))[1L])
if (!is.finite(workers) || workers != 20L) {
  stop("The confirmation contract requires exactly 20 workers.", call. = FALSE)
}
refresh_materialized <- !has_flag("--no-staged-refresh")
stage <- "qdesn_dynamic_fitforecast_v2_500obs_mcmc_sparse_topology_refine_v1"
stub <- file.path("config", "validation", stage)
interface_path <- file.path(
  "validation", "fitforecast_v2", "promotions",
  "qdesn_dqlm_500obs_trainonly_article_v2_20260807",
  "qdesn_dqlm_500obs_trainonly_article_v2_20260807_interface.csv"
)
expected_interface_sha256 <- "d412434bb3546cb3e3c4f03d633b30d0e64125948bbe3ac55ef230c0f1c56a53"
expected_registry_hash <- "edddb56fc2b30e49ac99fdd08b53dad468ed53e05d0fe1fe16426ee9d9ffe275"
expected_scenario <- paste0(
  "dlm_constV_p90_m0amp_highnoise_steepertrend_v2_",
  "TTmain10000_fitforecast"
)
canonical_registry_path <- get_arg(
  "--source-registry",
  paste0(
    "/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0/",
    "validation/fitforecast_v2/runs/",
    "20260704_exdqlm_dqlm_c13_mcmc_500obs_refresh_v2/manifests/source_registry.csv"
  )
)
base_defaults_path <- file.path(
  "config", "validation",
  "qdesn_dynamic_fitforecast_v2_tt500_mcmc_external_coherent_confirmation_v1_defaults.yaml"
)

if (!identical(sha256(interface_path), expected_interface_sha256)) {
  stop(sprintf("Authoritative interface hash mismatch: %s.", sha256(interface_path)), call. = FALSE)
}
interface <- read_csv(interface_path)
canonical_registry <- read_csv(canonical_registry_path)
plan <- qdesn_strv1_build_plan(interface_path, repo_root)
topology_audit <- qdesn_strv1_topology_audit(plan$profiles)
profiles_path <- write_csv(plan$profiles, paste0(stub, "_profiles.csv"))
assignments_path <- write_csv(plan$assignments, paste0(stub, "_cell_assignments.csv"))
pair_map_path <- write_csv(plan$pair_map, paste0(stub, "_pair_map.csv"))
base_designs_path <- write_csv(plan$base_designs, paste0(stub, "_base_designs.csv"))
topology_audit_path <- write_csv(topology_audit, paste0(stub, "_topology_audit.csv"))
topology_seed_path <- write_csv(
  plan$topology$selected, paste0(stub, "_topology_seed_contract.csv")
)
topology_search_path <- write_csv(
  plan$topology$search_audit, paste0(stub, "_topology_seed_search_audit.csv")
)
interaction_design_path <- write_csv(
  rbind(
    cbind(likelihood_target = "al", qdesn_strv1_interaction_design("al")),
    cbind(likelihood_target = "exal", qdesn_strv1_interaction_design("exal"))
  ), paste0(stub, "_interaction_design.csv")
)

registry <- canonical_registry[
  canonical_registry$scenario_id == expected_scenario &
    canonical_registry$family == "normal" &
    abs(as.numeric(canonical_registry$tau) - 0.25) <= 1e-12 &
    as.integer(canonical_registry$fit_size) == 500L,
  , drop = FALSE
]
if (nrow(registry) != 1L || !as_bool(registry$source_present) ||
    as.integer(registry$TT_warmup) != 2000L ||
    as.integer(registry$TT_main) != 10000L ||
    as.integer(registry$TT_total) != 12000L ||
    as.integer(registry$train_start_source_index) != 8501L ||
    as.integer(registry$train_end_source_index) != 9000L ||
    as.integer(registry$forecast_origin_source_index) != 9000L ||
    as.integer(registry$forecast_start_source_index) != 9001L ||
    as.integer(registry$forecast_end_source_index) != 10000L ||
    as.integer(registry$max_lead_configured) != 30L ||
    as.integer(registry$origin_stride) != 30L ||
    as_bool(registry$refit_per_origin)) {
  stop("The frozen Normal p=0.25 source row violates the confirmation protocol.", call. = FALSE)
}
source_roles <- c("series_wide", "true_quantile_grid", "sim_output", "meta")
source_file_audit <- do.call(rbind, lapply(source_roles, function(role) {
  path <- as.character(registry[[paste0(role, "_path")]][[1L]])
  expected <- as.character(registry[[paste0(role, "_sha256")]][[1L]])
  data.frame(
    role = role,
    path = path,
    expected_sha256 = expected,
    file_exists = file.exists(path),
    observed_sha256 = if (file.exists(path)) unname(tools::sha256sum(path)) else NA_character_,
    stringsAsFactors = FALSE
  )
}))
source_file_audit$hash_match <- with(
  source_file_audit, file_exists & expected_sha256 == observed_sha256
)
if (!all(source_file_audit$hash_match)) stop("A frozen source file failed SHA-256 verification.", call. = FALSE)
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
defaults$execution$likelihood_families <- as.list(c("al", "exal"))
defaults$execution$allowed_fit_spec_ids <- NULL
defaults$execution$seed_policy <- list(mode = "explicit_per_profile", base_seed = 951001L)
defaults$source_materialization$dynamic_root <- "/data/jaguir26/local/src/shared_dynamic_fit_forecast_validation/sources"
defaults$source_materialization$staged_root <- file.path(
  "results", "qdesn_mcmc_validation", "dynamic_fitforecast_v2_qdesn_sources_period90_m90_w300"
)
defaults$source_materialization$scenarios <- expected_scenario
defaults$source_materialization$families <- as.list("normal")
defaults$source_materialization$taus <- as.list(0.25)
defaults$reference$dynamic_root <- defaults$source_materialization$dynamic_root
defaults$reference_contract <- list(
  root_kind = "dynamic",
  scenarios = expected_scenario,
  families = as.list("normal"),
  taus = as.list(0.25),
  fit_sizes = 500L,
  expected_unique_dataset_cells = 1L,
  expected_qdesn_roots = 168L,
  expected_priors = "rhs_ns",
  expected_selected_qdesn_roots = 168L
)
defaults$screening_profiles <- list(
  enabled = TRUE,
  csv = rel_path(profiles_path),
  cell_assignments_csv = rel_path(assignments_path),
  priors = "rhs_ns",
  design = paste(
    "Two target likelihoods over six outcome-blind sparse reservoirs,",
    "six purposeful alpha/rho interactions, exact matched parents, and two sampler replicates."
  ),
  execution_grid_policy = "168_explicit_source_matched_full_budget_roots",
  canonical_profile_count = 168L,
  canonical_dataset_cell_count = 1L,
  canonical_qdesn_root_count = 168L,
  selected_assignment_root_count = 168L
)
defaults$study_contract$core_lane <- FALSE
defaults$study_contract$id <- paste0(stage, "_2026_08_07")
defaults$study_contract$description <- paste(
  "Full-budget frozen-source refinement of Q-DESN/exQ-DESN alpha/rho",
  "interactions under exact one-to-three-edge sparse recurrent topologies."
)
defaults$study_contract$source_registry_identity_field <- "source_registry_hash_value"
defaults$study_contract$source_registry_hash_value <- expected_registry_hash
defaults$study_contract$authoritative_interface_path <- resolve_path(interface_path)
defaults$study_contract$authoritative_interface_sha256 <- expected_interface_sha256
defaults$study_contract$sparse_topology_refine_v1 <- list(
  source_registry_hash_value = expected_registry_hash,
  source_registry_snapshot_path = source_registry_path,
  source_registry_snapshot_sha256 = sha256(source_registry_path),
  topology_seed_contract_path = topology_seed_path,
  topology_seed_contract_sha256 = sha256(topology_seed_path),
  topology_search_audit_path = topology_search_path,
  topology_search_audit_sha256 = sha256(topology_search_path),
  interaction_design_path = interaction_design_path,
  interaction_design_sha256 = sha256(interaction_design_path),
  pair_map_path = pair_map_path,
  pair_map_sha256 = sha256(pair_map_path),
  promotion_tolerance = 1e-10,
  diagnostic_policy = "retain_but_never_filter_finite_metrics",
  article_update_automatic = FALSE
)
defaults$study_contract$rolling_origin <- list(
  forecast_origin_source_index = 9000L,
  forecast_block_start_source_index = 9001L,
  forecast_block_end_source_index = 10000L,
  max_lead_configured = 30L,
  origin_stride = 30L,
  no_refit = TRUE,
  observed_lag_state_update = TRUE
)
defaults$study_contract$budget <- list(
  posterior_metric_draws = 200L,
  vb_sampling_nd_draws = 200L,
  vb_synthesis_n_samp = 200L,
  mcmc_n_burn = 5000L,
  mcmc_n_mcmc = 20000L,
  mcmc_thin = 1L
)
defaults$study_contract$selection_policy <- list(
  unit = "model_family_metric_specific_envelope",
  target_cells = 2L,
  sparse_topologies_per_cell = 6L,
  interaction_points_per_topology = 6L,
  base_candidate_designs = 72L,
  unique_parent_controls = 12L,
  sampler_replicates = 2L,
  expected_specs = 168L,
  comparison_policy = "same_source_same_reservoir_same_sampler_seed",
  promotion_policy = "strict_raw_metric_improvement_regardless_of_diagnostic_grade",
  promotion_tolerance = 1e-10,
  no_global_specification = TRUE,
  article_policy = "write_promotion_ready_preview_only"
)
defaults$runtime$threads <- 1L
defaults$runtime$campaign_workers <- 20L
defaults$runtime$workers <- 20L
defaults$runtime$root_scheduler <- "load_balanced"
defaults$diagnostics$fit_runtime$stream_child_stdout <- TRUE
defaults$diagnostics$fit_runtime$timeout_seconds <- 604800L
defaults$diagnostics$fit_runtime$timeout_kill_after_seconds <- 60L
defaults$metrics$posterior_metric_draws <- 200L
defaults$pipeline$sampling$nd_draws <- 200L
defaults$pipeline$synthesis$n_samp <- 200L
defaults$pipeline$inference$mcmc$n_burn <- 5000L
defaults$pipeline$inference$mcmc$n_mcmc <- 20000L
defaults$pipeline$inference$mcmc$thin <- 1L
defaults$pipeline$inference$mcmc$progress_every <- 50L
defaults$pipeline$inference$mcmc$init_from_vb <- TRUE
defaults$pipeline$inference$mcmc$vb_warm_start_control$max_iter <- 150L
defaults$pipeline$inference$mcmc$vb_warm_start_control$min_iter_elbo <- 40L
defaults$pipeline$inference$mcmc$vb_warm_start_control$n_samp_xi <- 500L
defaults$pipeline$inference$mcmc$prior_overrides$rhs_ns$n_burn <- 5000L
defaults$pipeline$inference$mcmc$prior_overrides$rhs_ns$n_mcmc <- 20000L
defaults$pipeline$inference$mcmc$prior_overrides$rhs_ns$progress_every <- 50L
defaults$pipeline$outputs$keep_draws <- FALSE
defaults$pipeline$outputs$keep_mcmc_vb_init <- FALSE
defaults$pipeline$outputs$save_forecast_objects <- FALSE
defaults$pipeline$outputs$save_compact_fit_paths <- TRUE
defaults$pipeline$outputs$save_metric_summaries <- TRUE
defaults$pipeline$outputs$retain_full_rds_on_failure <- FALSE
defaults$pipeline$outputs$retention_profile <- "storage_light_sparse_topology_refine_v1"

defaults_path <- resolve_path(paste0(stub, "_defaults.yaml"), FALSE)
yaml::write_yaml(defaults, defaults_path)
loaded <- exdqlm:::qdesn_dynamic_crossstudy_load_defaults(defaults_path)
canonical_grid <- exdqlm:::qdesn_dynamic_crossstudy_build_grid(
  loaded, refresh_materialized = refresh_materialized, verbose = TRUE
)
exdqlm:::qdesn_dynamic_crossstudy_validate_grid(canonical_grid, loaded)

lookup_fields <- c(
  "screening_profile_id", "source_screening_profile_id", "confirmation_design_id",
  "target_cell_id", "target_metrics", "likelihood_target", "target_family",
  "target_tau", "comparison_role", "control_key", "selection_tier",
  "selection_role", "reservoir_replicate", "sampler_replicate",
  "sampler_pair_id", "mcmc_seed", "mcmc_rng_seed", "vb_warm_start_seed",
  "synthesis_seed", "D", "n_each", "m", "alpha", "rho", "pi_w",
  "pi_in", "rhs_tau0", "topology_class", "recurrent_edges_target"
)
lookup <- plan$profiles[, lookup_fields, drop = FALSE]
grid_key <- paste(
  canonical_grid$screening_profile_id,
  canonical_grid$source_family,
  tau_key(canonical_grid$tau), sep = "\r"
)
target_key <- paste(
  lookup$screening_profile_id, lookup$target_family,
  tau_key(lookup$target_tau), sep = "\r"
)
grid <- canonical_grid[
  grid_key %in% target_key & canonical_grid$source_scenario == expected_scenario,
  , drop = FALSE
]
lookup_index <- match(grid$screening_profile_id, lookup$screening_profile_id)
for (field in setdiff(lookup_fields, "screening_profile_id")) {
  grid[[field]] <- lookup[[field]][lookup_index]
}
grid$source_registry_hash_value <- expected_registry_hash
grid <- qdesn_strv1_assign_execution_seeds(grid, plan$profiles)
grid <- grid[order(
  grid$target_cell_id, grid$control_key, grid$sampler_replicate,
  grid$comparison_role, grid$confirmation_design_id
), , drop = FALSE]
if (nrow(grid) != 168L || anyNA(grid$target_cell_id) || anyDuplicated(grid$root_id) ||
    any(as.integer(grid$train_start_source_index) != 8501L) ||
    any(as.integer(grid$train_end_source_index) != 9000L) ||
    any(as.integer(grid$forecast_start_source_index) != 9001L) ||
    any(as.integer(grid$forecast_end_source_index) != 10000L)) {
  stop(sprintf("Expected 168 exact frozen-source grid rows; found %d.", nrow(grid)), call. = FALSE)
}
seed_audit <- qdesn_strv1_seed_contract_audit(grid, plan$profiles, TRUE)
grid_path <- write_csv(grid, paste0(stub, "_grid.csv"))
seed_audit_path <- write_csv(seed_audit, paste0(stub, "_seed_contract_audit.csv"))

atomic <- exdqlm:::qdesn_dynamic_fitforecast_atomic_spec_grid(
  grid, defaults = loaded, methods = "mcmc", likelihood_families = c("al", "exal")
)
atomic_index <- match(atomic$root_id, grid$root_id)
for (field in c(
  "target_cell_id", "likelihood_target", "confirmation_design_id",
  "comparison_role", "control_key", "sampler_replicate", "sampler_pair_id",
  "topology_class", "recurrent_edges_target"
)) {
  atomic[[field]] <- grid[[field]][atomic_index]
}
target_specs <- atomic[
  atomic$likelihood_family == atomic$likelihood_target, , drop = FALSE
]
target_specs <- target_specs[order(
  target_specs$target_cell_id, target_specs$control_key,
  target_specs$sampler_replicate, target_specs$comparison_role,
  target_specs$confirmation_design_id
), , drop = FALSE]
if (nrow(target_specs) != 168L || anyDuplicated(target_specs$spec_id)) {
  stop(sprintf("Expected 168 unique target specs; found %d.", nrow(target_specs)), call. = FALSE)
}
target_specs_path <- write_csv(target_specs, paste0(stub, "_target_spec_ids.csv"))
loaded$execution$allowed_fit_spec_ids <- as.list(as.character(target_specs$spec_id))
yaml::write_yaml(loaded, defaults_path)

smoke_candidate <- plan$profiles[
  plan$profiles$likelihood_target == "al" &
    plan$profiles$topology_class == "w01" &
    plan$profiles$arm_code == "p01" &
    plan$profiles$sampler_replicate == 1L, , drop = FALSE
]
smoke_parent <- plan$profiles[
  plan$profiles$control_key == smoke_candidate$control_key[[1L]] &
    plan$profiles$sampler_replicate == 1L &
    plan$profiles$comparison_role == "matched_sparse_parent", , drop = FALSE
]
smoke_exal <- plan$profiles[
  plan$profiles$likelihood_target == "exal" &
    plan$profiles$topology_class == "w03" &
    plan$profiles$arm_code == "p03" &
    plan$profiles$sampler_replicate == 1L &
    plan$profiles$reservoir_replicate == 1L, , drop = FALSE
]
smoke_profiles <- rbind(smoke_candidate[1L, , drop = FALSE],
                        smoke_parent[1L, , drop = FALSE],
                        smoke_exal[1L, , drop = FALSE])
smoke_grid <- grid[grid$screening_profile_id %in% smoke_profiles$screening_profile_id, , drop = FALSE]
smoke_specs <- target_specs[target_specs$root_id %in% smoke_grid$root_id, , drop = FALSE]
if (nrow(smoke_grid) != 3L || nrow(smoke_specs) != 3L) {
  stop("The smoke contract is not one AL pair plus one exAL candidate.", call. = FALSE)
}
smoke_defaults <- loaded
smoke_defaults$campaign$name <- paste0(stage, "_smoke")
smoke_defaults$campaign$results_root <- file.path(
  "results", "qdesn_mcmc_validation", paste0(stage, "_smoke")
)
smoke_defaults$campaign$reports_root <- file.path(
  "reports", "qdesn_mcmc_validation", paste0(stage, "_smoke")
)
smoke_defaults$execution$allowed_fit_spec_ids <- as.list(as.character(smoke_specs$spec_id))
smoke_defaults$runtime$campaign_workers <- 3L
smoke_defaults$runtime$workers <- 3L
smoke_defaults$reference_contract$expected_selected_qdesn_roots <- 3L
smoke_defaults$screening_profiles$selected_assignment_root_count <- 3L
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
  posterior_metric_draws = 4L, vb_sampling_nd_draws = 4L,
  vb_synthesis_n_samp = 4L, mcmc_n_burn = 4L,
  mcmc_n_mcmc = 4L, mcmc_thin = 1L
)
smoke_defaults_path <- resolve_path(paste0(stub, "_smoke_defaults.yaml"), FALSE)
yaml::write_yaml(smoke_defaults, smoke_defaults_path)
smoke_grid_path <- write_csv(smoke_grid, paste0(stub, "_smoke_grid.csv"))
smoke_specs_path <- write_csv(smoke_specs, paste0(stub, "_smoke_target_spec_ids.csv"))

article_context <- interface[
  interface$inference == "mcmc" & interface$family == "normal" &
    abs(as.numeric(interface$tau) - 0.25) <= 1e-12 &
    interface$model_variant %in% c("qdesn_al_rhs_ns", "qdesn_exal_rhs_ns"),
  , drop = FALSE
]
if (nrow(article_context) != 2L) stop("Could not recover both current article cells.", call. = FALSE)
article_context_path <- write_csv(
  article_context, paste0(stub, "_current_article_metric_context.csv")
)
promotion_contract <- data.frame(
  model_variant = c("qdesn_al_rhs_ns", "qdesn_exal_rhs_ns"),
  target_cell_id = c("al_normal_t0p25", "exal_normal_t0p25"),
  family = "normal",
  tau = 0.25,
  selection_unit = "metric",
  improvement_tolerance = 1e-10,
  status_filter = FALSE,
  source_registry_hash_value = expected_registry_hash,
  mcmc_n_burn = 5000L,
  mcmc_n_mcmc = 20000L,
  stringsAsFactors = FALSE
)
promotion_contract_path <- write_csv(
  promotion_contract, paste0(stub, "_promotion_contract.csv")
)

generated_files <- c(
  profiles = profiles_path,
  assignments = assignments_path,
  pair_map = pair_map_path,
  base_designs = base_designs_path,
  topology_audit = topology_audit_path,
  topology_seed_contract = topology_seed_path,
  topology_seed_search = topology_search_path,
  interaction_design = interaction_design_path,
  source_registry = source_registry_path,
  source_file_audit = source_file_audit_path,
  defaults = defaults_path,
  grid = grid_path,
  seed_audit = seed_audit_path,
  target_specs = target_specs_path,
  smoke_defaults = smoke_defaults_path,
  smoke_grid = smoke_grid_path,
  smoke_specs = smoke_specs_path,
  article_context = article_context_path,
  promotion_contract = promotion_contract_path
)
generated_manifest <- data.frame(
  role = names(generated_files),
  path = vapply(unname(generated_files), resolve_path, character(1L)),
  sha256 = vapply(unname(generated_files), sha256, character(1L)),
  stringsAsFactors = FALSE
)
generated_manifest_path <- write_csv(
  generated_manifest, paste0(stub, "_generated_file_manifest.csv")
)
manifest <- list(
  protocol_frozen_at_utc = "2026-08-07T16:00:00Z",
  stage = stage,
  package_version = as.character(description[1L, "Version"]),
  implementation_parent_commit = "b2e0472631e8f57ca61e51a4e697de733c9ec1e8",
  authority_interface_path = resolve_path(interface_path),
  authority_interface_sha256 = expected_interface_sha256,
  source_registry_identity_field = "source_registry_hash_value",
  source_registry_hash_value = expected_registry_hash,
  source_registry_path = source_registry_path,
  source_registry_sha256 = sha256(source_registry_path),
  source_files_verified = all(source_file_audit$hash_match),
  topology_seed_contract_path = topology_seed_path,
  topology_seed_contract_sha256 = sha256(topology_seed_path),
  topology_search_audit_path = topology_search_path,
  topology_search_audit_sha256 = sha256(topology_search_path),
  interaction_design_path = interaction_design_path,
  interaction_design_sha256 = sha256(interaction_design_path),
  topology_audit_path = topology_audit_path,
  pair_map_path = pair_map_path,
  defaults_path = defaults_path,
  grid_path = grid_path,
  target_specs_path = target_specs_path,
  generated_file_manifest_path = generated_manifest_path,
  counts = list(
    candidate_designs = 72L,
    unique_parent_controls = 12L,
    sampler_replicates = 2L,
    candidate_specs = 144L,
    parent_specs = 24L,
    full_specs = 168L,
    smoke_specs = 3L
  ),
  budget = list(n_burn = 5000L, n_mcmc = 20000L, metric_draws = 200L),
  rolling_origin = list(
    forecast_origin_source_index = 9000L,
    forecast_block = c(9001L, 10000L),
    max_lead = 30L,
    origin_stride = 30L,
    refit_per_origin = FALSE
  ),
  execution = list(workers = 20L, threads_per_fit = 1L),
  metric_promotion_policy = "strictly_lower_finite_value_status_agnostic",
  article_update_automatic = FALSE,
  launch_status = "materialized_not_launched"
)
manifest_path <- write_json(
  manifest, paste0(stub, "_materialization_manifest.json")
)

cat(sprintf("Materialization manifest: %s\n", manifest_path))
cat(sprintf("Frozen registry hash: %s\n", expected_registry_hash))
cat(sprintf("Candidate designs: 72; reusable controls: 12; sampler replicates: 2\n"))
cat(sprintf("Full confirmation specs: %d\n", nrow(target_specs)))
cat(sprintf("Executable smoke specs: %d\n", nrow(smoke_specs)))

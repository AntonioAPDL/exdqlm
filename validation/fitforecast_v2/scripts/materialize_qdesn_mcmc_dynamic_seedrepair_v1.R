#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  required <- c("digest", "jsonlite", "pkgload", "yaml")
  missing <- setdiff(required, rownames(installed.packages()))
  if (length(missing)) stop(sprintf("Missing package(s): %s", paste(missing, collapse = ", ")), call. = FALSE)
  invisible(lapply(required, require, character.only = TRUE))
})

args <- commandArgs(trailingOnly = TRUE)
has_flag <- function(flag) any(args == flag)
get_arg <- function(flag, default = NULL) {
  idx <- which(args == flag)
  if (!length(idx) || idx[[1L]] >= length(args)) return(default)
  args[[idx[[1L]] + 1L]]
}
`%||%` <- function(x, y) if (is.null(x) || !length(x)) y else x

repo_root <- normalizePath(system("git rev-parse --show-toplevel", intern = TRUE), winslash = "/", mustWork = TRUE)
setwd(repo_root)
pkgload::load_all(repo_root, quiet = TRUE)
source(file.path(repo_root, "validation", "fitforecast_v2", "R", "qdesn_alpha_rho_topology_v1.R"))
source(file.path(repo_root, "validation", "fitforecast_v2", "R", "qdesn_mcmc_highalpha_cellwise_v1.R"))
source(file.path(repo_root, "validation", "fitforecast_v2", "R", "qdesn_mcmc_dynamic_seedrepair_v1.R"))

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
  stop("Dynamic seed-repair v1 requires exdqlm 1.0.0.", call. = FALSE)
}

workers <- suppressWarnings(as.integer(get_arg("--workers", "20"))[1L])
if (!is.finite(workers) || workers != 20L) stop("The campaign contract requires exactly 20 workers.", call. = FALSE)
refresh_sources <- !has_flag("--no-source-refresh")
refresh_staged <- !has_flag("--no-staged-refresh")

stage <- "qdesn_dynamic_fitforecast_v2_500obs_mcmc_dynamic_seedrepair_v1"
stub <- file.path("config", "validation", stage)
source_config_path <- resolve_path(paste0(stub, "_source_replicates.yaml"))
interface_path <- resolve_path(file.path(
  "validation", "fitforecast_v2", "promotions",
  "qdesn_dqlm_500obs_trainonly_article_v1_20260805",
  "qdesn_dqlm_500obs_trainonly_article_v1_20260805_interface.csv"
))
expected_interface_sha256 <- "dff814fab1e920c10760645ac9e8d37dfa7f33ae2afba34ee8ed2a5509f4952a"
if (!identical(sha256(interface_path), expected_interface_sha256)) {
  stop(sprintf("Authoritative interface hash mismatch: %s", sha256(interface_path)), call. = FALSE)
}
base_defaults_path <- resolve_path(get_arg(
  "--base-defaults",
  file.path("config", "validation", "qdesn_dynamic_fitforecast_v2_500obs_trainonly_rebaseline_v1_defaults.yaml")
))

source_cfg <- yaml::read_yaml(source_config_path)
generation_cfg <- source_cfg$generation %||% list()
replicates <- source_cfg$replicates %||% list()
roles <- vapply(replicates, function(x) as.character(x$role), character(1L))
if (length(replicates) != 4L || sum(roles == "discovery") != 3L || sum(roles == "sealed_holdout") != 1L) {
  stop("Source contract requires three discovery trajectories and one sealed holdout.", call. = FALSE)
}
if (!identical(as.character(generation_cfg$families), "normal") ||
    !identical(as.numeric(generation_cfg$taus), 0.25)) {
  stop("Dynamic seed-repair sources must contain only Normal p=0.25.", call. = FALSE)
}
seed_table <- do.call(rbind, lapply(replicates, function(replicate) {
  do.call(rbind, lapply(names(replicate$seeds), function(family) {
    data.frame(
      replicate_id = as.character(replicate$replicate_id),
      role = as.character(replicate$role),
      scenario_id = as.character(replicate$scenario_id),
      family = family,
      latent_seed = as.integer(replicate$seeds[[family]]$latent),
      noise_seed = as.integer(replicate$seeds[[family]]$noise),
      stringsAsFactors = FALSE
    )
  }))
}))
if (anyDuplicated(c(seed_table$latent_seed, seed_table$noise_seed))) stop("Every DGP seed must be unique.", call. = FALSE)

source_root_rows <- list()
source_slice_rows <- list()
for (replicate in replicates) {
  family_profiles <- generation_cfg$family_profiles
  for (family in names(family_profiles)) family_profiles[[family]]$seeds <- replicate$seeds[[family]]
  manifest <- list(
    meta = list(
      study_id = source_cfg$meta$study_id,
      scenario_id = replicate$scenario_id,
      notes = sprintf("Dynamic seed-repair %s trajectory %s.", replicate$role, replicate$replicate_id)
    ),
    generation = utils::modifyList(generation_cfg, list(family_profiles = family_profiles)),
    qdesn_materialization = list(staged_root = file.path(
      "results", "qdesn_mcmc_validation", stage, "source_windows", replicate$scenario_id
    ))
  )
  generated <- exdqlm:::qdesn_dynamic_candidate_generate_bundle(
    manifest = manifest, repo_root = repo_root, refresh = refresh_sources, verbose = TRUE
  )
  roots <- generated$root_inventory
  roots$replicate_id <- as.character(replicate$replicate_id)
  roots$source_role <- as.character(replicate$role)
  slices <- generated$slice_inventory
  slices$replicate_id <- as.character(replicate$replicate_id)
  slices$source_role <- as.character(replicate$role)
  source_root_rows[[length(source_root_rows) + 1L]] <- roots
  source_slice_rows[[length(source_slice_rows) + 1L]] <- slices
}
source_roots <- do.call(rbind, source_root_rows)
source_slices <- do.call(rbind, source_slice_rows)
source_roots <- source_roots[order(source_roots$source_role, source_roots$replicate_id), , drop = FALSE]
source_slices <- source_slices[order(source_slices$source_role, source_slices$replicate_id), , drop = FALSE]

expected_source_hashes <- do.call(rbind, lapply(source_cfg$source_identity_contract$expected, function(x) {
  data.frame(
    replicate_id = as.character(x$replicate_id),
    expected_scenario_id = as.character(x$scenario_id),
    expected_series_wide_sha256 = as.character(x$series_wide_sha256),
    expected_series_long_sha256 = as.character(x$series_long_sha256),
    expected_true_quantile_grid_sha256 = as.character(x$true_quantile_grid_sha256),
    expected_sim_output_sha256 = as.character(x$sim_output_sha256),
    stringsAsFactors = FALSE
  )
}))
observed_source_hashes <- source_roots[
  source_roots$family == "normal" & abs(source_roots$tau - 0.25) < 1e-12,
  c(
    "replicate_id", "scenario", "series_wide_sha256", "series_long_sha256",
    "true_quantile_grid_sha256", "sim_output_sha256"
  ),
  drop = FALSE
]
observed_source_hashes <- observed_source_hashes[
  match(expected_source_hashes$replicate_id, observed_source_hashes$replicate_id), , drop = FALSE
]
source_continuity_audit <- cbind(expected_source_hashes, observed_source_hashes[, -1L, drop = FALSE])
names(source_continuity_audit)[names(source_continuity_audit) == "scenario"] <- "observed_scenario_id"
for (field in c("series_wide_sha256", "series_long_sha256", "true_quantile_grid_sha256", "sim_output_sha256")) {
  source_continuity_audit[[paste0("observed_", field)]] <- source_continuity_audit[[field]]
  source_continuity_audit[[field]] <- NULL
  source_continuity_audit[[paste0(field, "_match")]] <-
    source_continuity_audit[[paste0("expected_", field)]] == source_continuity_audit[[paste0("observed_", field)]]
}
source_continuity_audit$scenario_id_match <-
  source_continuity_audit$expected_scenario_id == source_continuity_audit$observed_scenario_id
match_columns <- grep("_match$", names(source_continuity_audit), value = TRUE)
source_continuity_audit$all_hashes_and_scenario_match <- apply(
  source_continuity_audit[, match_columns, drop = FALSE], 1L, function(x) all(x %in% TRUE)
)
if (nrow(source_continuity_audit) != 4L || any(!source_continuity_audit$all_hashes_and_scenario_match)) {
  stop("Generated source trajectories do not match the frozen high-alpha source hashes.", call. = FALSE)
}

evidence_root <- file.path("reports", "qdesn_mcmc_validation", stage, "materialization")
source_registry_path <- write_csv(source_roots, file.path(evidence_root, "source_registry_all.csv"))
source_slice_registry_path <- write_csv(source_slices, file.path(evidence_root, "source_slice_registry_all.csv"))
discovery_registry_path <- write_csv(
  source_roots[source_roots$source_role == "discovery", , drop = FALSE],
  file.path(evidence_root, "source_registry_discovery.csv")
)
sealed_registry_path <- write_csv(
  source_roots[source_roots$source_role == "sealed_holdout", , drop = FALSE],
  file.path(evidence_root, "source_registry_sealed_holdout.csv")
)
source_continuity_path <- write_csv(
  source_continuity_audit, file.path(evidence_root, "source_identity_continuity_audit.csv")
)
source_seed_contract_path <- write_csv(seed_table, paste0(stub, "_source_seed_contract.csv"))

plan <- qdesn_dsr1_build_plan(interface_path, repo_root)
topology_audit <- qdesn_dsr1_topology_audit(plan$profiles)
parents_path <- write_csv(plan$parents, paste0(stub, "_authoritative_parent_profiles.csv"))
targets_path <- write_csv(plan$authority$targets, paste0(stub, "_target_cells.csv"))
metric_sources_path <- write_csv(plan$metric_sources, paste0(stub, "_authoritative_metric_sources.csv"))
seed_contract_path <- write_csv(plan$seed_contract, paste0(stub, "_dynamic_seed_contract.csv"))
seed_search_path <- write_csv(plan$seed_search_audit, paste0(stub, "_dynamic_seed_search_audit.csv"))
design_path <- write_csv(plan$designs, paste0(stub, "_alpha_design.csv"))
profiles_path <- write_csv(plan$profiles, paste0(stub, "_profiles.csv"))
assignments_path <- write_csv(plan$assignments, paste0(stub, "_cell_assignments.csv"))
topology_audit_path <- write_csv(topology_audit, paste0(stub, "_topology_audit.csv"))

nonrepeat <- unique(plan$profiles[, c(
  "target_cell_id", "candidate_id", "arm_code", "comparison_role", "alpha", "rho",
  "pi_w", "pi_in", "rhs_tau0", "D", "n_each", "m", "seed_selection_rule"
), drop = FALSE])
nonrepeat$prior_wave1_overlap <- nonrepeat$comparison_role == "candidate" &
  nonrepeat$alpha %in% c(0.40, 0.50, 0.60, 0.70, 0.80, 0.90, 0.95, 0.99)
nonrepeat$repeat_disposition <- ifelse(
  nonrepeat$comparison_role == "authority_parent",
  "intentional_frozen_authority_control",
  ifelse(
    nonrepeat$comparison_role == "dynamic_parent",
    "required_same_seed_parent_control",
    ifelse(
      nonrepeat$prior_wave1_overlap,
      "required_replay_under_corrected_dynamic_seed_contract",
      "new_cell_specific_alpha_point_under_corrected_dynamic_seed_contract"
    )
  )
)
nonrepeat_path <- write_csv(nonrepeat, paste0(stub, "_nonrepeat_ledger.csv"))

base_defaults <- yaml::read_yaml(base_defaults_path)
if (!identical(base_defaults$preproc$fit_scope, "train_only") ||
    !identical(base_defaults$study_contract$preprocessing$scope, "train_only")) {
  stop("Base defaults are not the corrected train-only protocol.", call. = FALSE)
}
discovery_replicates <- replicates[roles == "discovery"]
discovery_scenarios <- vapply(discovery_replicates, function(x) as.character(x$scenario_id), character(1L))
dynamic_root <- as.character(generation_cfg$output_parent)
staged_root <- file.path("results", "qdesn_mcmc_validation", stage, "source_windows")
expected_specs <- nrow(plan$profiles) * length(discovery_scenarios)
if (expected_specs != 240L) stop(sprintf("Expected 240 discovery specs; found %d.", expected_specs), call. = FALSE)

defaults <- base_defaults
defaults$campaign <- list(
  name = paste0(stage, "_discovery"),
  results_root = file.path("results", "qdesn_mcmc_validation", paste0(stage, "_discovery")),
  reports_root = file.path("reports", "qdesn_mcmc_validation", paste0(stage, "_discovery"))
)
defaults$grid$source_mode <- "materialized_source_inputs"
defaults$execution$methods <- "mcmc"
defaults$execution$likelihood_families <- as.list(c("al", "exal"))
defaults$execution$allowed_fit_spec_ids <- NULL
defaults$execution$seed_policy <- list(mode = "shared", base_seed = 910001L)
defaults$source_materialization <- list(
  dynamic_root = dynamic_root,
  staged_root = staged_root,
  enforce_effective_train_size = TRUE,
  train_end_source_index = 9000L,
  forecast_origin_source_index = 9000L,
  forecast_horizon = 1000L,
  scenarios = as.list(discovery_scenarios),
  families = as.list("normal"),
  taus = as.list(0.25),
  windows = list(list(
    effective_fit_size = 500L,
    source_total_size = 1890L,
    source_dir_name = "fit_input_effTT500_totalTT1890_trainEnd9000_H1000_m90_w300_period90",
    label = "effTT500_totalTT1890_trainEnd9000_H1000_m90_w300_period90"
  ))
)
defaults$reference$dynamic_root <- dynamic_root
defaults$reference_contract <- list(
  root_kind = "dynamic",
  scenarios = as.list(discovery_scenarios),
  families = as.list("normal"),
  taus = as.list(0.25),
  fit_sizes = 500L,
  expected_unique_dataset_cells = 3L,
  expected_qdesn_roots = expected_specs,
  expected_priors = "rhs_ns",
  expected_selected_qdesn_roots = expected_specs
)
defaults$screening_profiles <- list(
  enabled = TRUE,
  csv = rel_path(profiles_path),
  cell_assignments_csv = rel_path(assignments_path),
  priors = "rhs_ns",
  design = "Normal p=0.25 MCMC alpha replay on three outcome-blind dynamically active reservoir seeds.",
  execution_grid_policy = "cell_specific_subset_grid_with_explicit_desn_and_sampler_seeds",
  canonical_profile_count = nrow(plan$profiles),
  canonical_dataset_cell_count = 3L,
  canonical_qdesn_root_count = expected_specs,
  selected_assignment_root_count = expected_specs
)
defaults$study_contract$core_lane <- FALSE
defaults$study_contract$id <- paste0(stage, "_2026_08_07")
defaults$study_contract$description <- paste(
  "Independent Q-DESN/exQ-DESN RHS MCMC dynamic seed-repair discovery.",
  "D/n/m/rho/pi/tau0/readout remain frozen; only alpha and outcome-blind dynamic reservoir seed vary."
)
defaults$study_contract$source_registry_identity_field <- "development_source_registry_sha256"
defaults$study_contract$development_source_registry_sha256 <- sha256(discovery_registry_path)
defaults$study_contract$development_source_registry_path <- discovery_registry_path
defaults$study_contract$sealed_holdout_registry_sha256 <- sha256(sealed_registry_path)
defaults$study_contract$sealed_holdout_registry_path <- sealed_registry_path
defaults$study_contract$authoritative_interface_path <- interface_path
defaults$study_contract$authoritative_interface_sha256 <- expected_interface_sha256
defaults$study_contract$topology_contract <- list(
  version = "dynamic_input_excludes_bias_v1",
  dynamic_input_definition = "sum(Win[, -1] != 0)",
  search_seed_rule = plan$seed_contract$selection_rule[[1L]],
  dynamic_seed_contract_path = seed_contract_path,
  topology_audit_path = topology_audit_path,
  probe_state_policy = "every alpha point must have a distinct deterministic probe-state hash within reservoir seed"
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
  posterior_metric_draws = 100L, vb_sampling_nd_draws = 100L,
  vb_synthesis_n_samp = 100L, mcmc_n_burn = 1000L,
  mcmc_n_mcmc = 3000L, mcmc_thin = 1L
)
defaults$study_contract$selection_policy <- list(
  unit = "target_cell_by_source_replicate_by_dynamic_reservoir_seed",
  within_seed_comparison = "candidate_to_dynamic_parent_same_source_desn_seed_and_sampler_seed",
  authority_comparison = "candidate_to_frozen_authority_parent_same_source_and_sampler_seed",
  target_gate = "median target ratio <= 0.98 in both comparisons",
  companion_gate = "median non-target ratios <= 1.05 in both comparisons",
  stability_gate = "q90 target ratio <= 1.10 in both comparisons",
  direction_gate = "target ratio <= 1 in at least six of nine pairs and at least two of three reservoir seeds",
  status_policy = "retain status and finite metrics; diagnostics do not silently exclude metric rows",
  article_policy = "no article update from screening-budget evidence"
)
defaults$study_contract$confirmation_budget <- list(
  posterior_metric_draws = 200L, mcmc_n_burn = 5000L,
  mcmc_n_mcmc = 20000L, mcmc_thin = 1L,
  required_before_article_promotion = TRUE
)
defaults$runtime$threads <- 1L
defaults$runtime$campaign_workers <- 20L
defaults$runtime$workers <- 20L
defaults$runtime$root_scheduler <- "load_balanced"
defaults$diagnostics$fit_runtime$stream_child_stdout <- TRUE
defaults$diagnostics$fit_runtime$timeout_seconds <- 43200L
defaults$diagnostics$fit_runtime$timeout_kill_after_seconds <- 60L
defaults$metrics$posterior_metric_draws <- 100L
defaults$pipeline$sampling$nd_draws <- 100L
defaults$pipeline$synthesis$n_samp <- 100L
defaults$pipeline$inference$mcmc$n_burn <- 1000L
defaults$pipeline$inference$mcmc$n_mcmc <- 3000L
defaults$pipeline$inference$mcmc$thin <- 1L
defaults$pipeline$inference$mcmc$progress_every <- 50L
defaults$pipeline$inference$mcmc$init_from_vb <- TRUE
defaults$pipeline$inference$mcmc$vb_warm_start_control$max_iter <- 150L
defaults$pipeline$inference$mcmc$vb_warm_start_control$min_iter_elbo <- 40L
defaults$pipeline$inference$mcmc$vb_warm_start_control$n_samp_xi <- 500L
defaults$pipeline$inference$mcmc$prior_overrides$rhs_ns$n_burn <- 1000L
defaults$pipeline$inference$mcmc$prior_overrides$rhs_ns$n_mcmc <- 3000L
defaults$pipeline$inference$mcmc$prior_overrides$rhs_ns$progress_every <- 50L
defaults$pipeline$outputs$keep_draws <- FALSE
defaults$pipeline$outputs$keep_mcmc_vb_init <- FALSE
defaults$pipeline$outputs$save_forecast_objects <- FALSE
defaults$pipeline$outputs$save_compact_fit_paths <- TRUE
defaults$pipeline$outputs$save_metric_summaries <- TRUE
defaults$pipeline$outputs$retain_full_rds_on_failure <- FALSE
defaults$pipeline$outputs$retention_profile <- "storage_light_dynamic_seedrepair_v1"
defaults$smoke <- list(
  scenario = discovery_scenarios[[1L]], family = "normal", tau = 0.25,
  fit_sizes = 500L, priors = as.list("rhs_ns"),
  screening_profile_ids = as.list(plan$profiles$screening_profile_id[
    which(plan$profiles$comparison_role == "candidate")[[1L]]
  ]),
  max_roots = 1L,
  budget = list(
    posterior_metric_draws = 4L, vb_sampling_nd_draws = 4L,
    vb_synthesis_n_samp = 4L, mcmc_n_burn = 4L,
    mcmc_n_mcmc = 4L, mcmc_thin = 1L
  ),
  pipeline = list(inference = list(mcmc = list(
    n_burn = 4L, n_mcmc = 4L, thin = 1L, progress_every = 1L,
    init_from_vb = TRUE,
    vb_warm_start_control = list(max_iter = 5L, min_iter_elbo = 2L, n_samp_xi = 10L)
  )))
)

defaults_path <- resolve_path(paste0(stub, "_discovery_defaults.yaml"), FALSE)
yaml::write_yaml(defaults, defaults_path)
loaded <- exdqlm:::qdesn_dynamic_crossstudy_load_defaults(defaults_path)
canonical <- exdqlm:::qdesn_dynamic_crossstudy_build_grid(
  loaded, refresh_materialized = refresh_staged, verbose = TRUE
)
exdqlm:::qdesn_dynamic_crossstudy_validate_grid(canonical, loaded)
lookup_cols <- c(
  "screening_profile_id", "target_cell_id", "target_metrics", "likelihood_target",
  "target_family", "target_tau", "parent_profile_id", "parent_candidate_id",
  "candidate_id", "arm_code", "design_role", "topology_search_mode",
  "topology_mode", "reservoir_replicate", "paired_reservoir_seed",
  "comparison_role", "seed_selection_rule", "topology_contract_version"
)
lookup <- plan$profiles[, lookup_cols, drop = FALSE]
grid_key <- paste(canonical$screening_profile_id, canonical$source_family, tau_key(canonical$tau), sep = "\r")
target_key <- paste(lookup$screening_profile_id, lookup$target_family, tau_key(lookup$target_tau), sep = "\r")
grid <- canonical[grid_key %in% target_key, , drop = FALSE]
grid <- merge(grid, lookup, by = "screening_profile_id", all.x = TRUE, sort = FALSE)
grid <- qdesn_dsr1_assign_sampler_seeds(grid)
grid <- grid[order(
  grid$target_cell_id, grid$comparison_role, grid$candidate_id,
  grid$reservoir_replicate, grid$source_scenario
), , drop = FALSE]
if (nrow(grid) != expected_specs || anyNA(grid$likelihood_target)) {
  stop(sprintf("Expected %d selected roots; found %d.", expected_specs, nrow(grid)), call. = FALSE)
}
seed_execution <- qdesn_dsr1_seed_execution_audit(grid, plan$profiles, stop_on_fail = TRUE)
grid_path <- write_csv(grid, paste0(stub, "_discovery_grid.csv"))
seed_execution_path <- write_csv(seed_execution, paste0(stub, "_seed_execution_contract.csv"))

atomic <- exdqlm:::qdesn_dynamic_fitforecast_atomic_spec_grid(
  grid, defaults = loaded, methods = "mcmc", likelihood_families = c("al", "exal")
)
atomic <- merge(
  atomic,
  lookup[, c("screening_profile_id", "likelihood_target", "target_cell_id", "candidate_id", "comparison_role"), drop = FALSE],
  by = "screening_profile_id", all.x = TRUE, sort = FALSE
)
target_specs <- atomic[atomic$likelihood_family == atomic$likelihood_target, , drop = FALSE]
target_specs <- target_specs[order(target_specs$target_cell_id, target_specs$candidate_id, target_specs$root_id), , drop = FALSE]
if (nrow(target_specs) != expected_specs || anyDuplicated(target_specs$spec_id)) {
  stop(sprintf("Expected %d unique target specs; found %d.", expected_specs, nrow(target_specs)), call. = FALSE)
}
target_specs_path <- write_csv(target_specs, paste0(stub, "_discovery_target_spec_ids.csv"))
loaded$execution$allowed_fit_spec_ids <- as.list(as.character(target_specs$spec_id))
yaml::write_yaml(loaded, defaults_path)

source_window_audit <- exdqlm:::qdesn_dynamic_fitforecast_verify_source_windows(
  file.path(resolve_path(staged_root), "materialized_source_inventory.csv"),
  expected_train_end = 9000L, expected_forecast_end = 10000L, stop_on_fail = TRUE
)
source_window_audit_path <- write_csv(source_window_audit, file.path(evidence_root, "source_window_audit.csv"))

generated_paths <- unique(c(
  source_config_path, interface_path, base_defaults_path, source_seed_contract_path,
  source_registry_path, source_slice_registry_path, discovery_registry_path, sealed_registry_path,
  source_continuity_path,
  parents_path, targets_path, metric_sources_path, seed_contract_path, seed_search_path,
  design_path, profiles_path, assignments_path, topology_audit_path, nonrepeat_path,
  defaults_path, grid_path, seed_execution_path, target_specs_path, source_window_audit_path
))
generated_paths <- normalizePath(generated_paths, winslash = "/", mustWork = TRUE)
generated_manifest <- data.frame(
  path = generated_paths,
  relative_path = vapply(generated_paths, rel_path, character(1L)),
  bytes = as.numeric(file.info(generated_paths)$size),
  sha256 = vapply(generated_paths, sha256, character(1L)),
  stringsAsFactors = FALSE
)
generated_manifest_path <- write_csv(generated_manifest, paste0(stub, "_generated_file_manifest.csv"))

manifest <- list(
  protocol_frozen_at_utc = "2026-08-07T00:00:00Z",
  stage = stage,
  package_version = as.character(description[1L, "Version"]),
  implementation_parent_commit = "823c6d6142a5bdf109c819cf5e4cef11c0bc7c4b",
  materializer_script_path = resolve_path(
    file.path("validation", "fitforecast_v2", "scripts", "materialize_qdesn_mcmc_dynamic_seedrepair_v1.R")
  ),
  materializer_script_sha256 = sha256(
    file.path("validation", "fitforecast_v2", "scripts", "materialize_qdesn_mcmc_dynamic_seedrepair_v1.R")
  ),
  authority_interface_path = interface_path,
  authority_interface_sha256 = expected_interface_sha256,
  authority_source_registry_identity = unique(plan$authority$targets$source_registry_hash_value),
  source_config_path = source_config_path,
  source_config_sha256 = sha256(source_config_path),
  discovery_source_registry_path = discovery_registry_path,
  discovery_source_registry_sha256 = sha256(discovery_registry_path),
  sealed_holdout_registry_path = sealed_registry_path,
  sealed_holdout_registry_sha256 = sha256(sealed_registry_path),
  source_identity_continuity_path = source_continuity_path,
  source_identity_continuity_sha256 = sha256(source_continuity_path),
  source_slice_registry_path = source_slice_registry_path,
  source_window_audit_path = source_window_audit_path,
  parent_profiles_path = parents_path,
  target_cells_path = targets_path,
  dynamic_seed_contract_path = seed_contract_path,
  dynamic_seed_search_audit_path = seed_search_path,
  topology_audit_path = topology_audit_path,
  nonrepeat_ledger_path = nonrepeat_path,
  profiles_path = profiles_path,
  assignments_path = assignments_path,
  defaults_path = defaults_path,
  grid_path = grid_path,
  target_specs_path = target_specs_path,
  seed_execution_contract_path = seed_execution_path,
  generated_file_manifest_path = generated_manifest_path,
  counts = list(
    target_cells = 2L,
    discovery_sources = 3L,
    sealed_sources = 1L,
    dynamic_reservoir_seeds = 3L,
    authority_parent_profiles = 2L,
    dynamic_parent_profiles = 6L,
    candidate_profiles = 72L,
    discovery_profiles = 80L,
    discovery_specs = 240L
  ),
  launch_policy = list(
    discovery = "approved_after_tests_smoke_and_clean_pushed_branch",
    full_confirmation = "requires_dual_discovery_gate_and_explicit_followup",
    article = "unchanged_until_full_budget_confirmation"
  ),
  article_state = "unchanged_screening_not_article_evidence"
)
manifest_path <- write_json(manifest, paste0(stub, "_materialization_manifest.json"))

cat(sprintf("Materialization manifest: %s\n", manifest_path))
cat(sprintf("Authority interface: %s (sha256=%s)\n", interface_path, expected_interface_sha256))
cat(sprintf("Discovery registry: %s (sha256=%s)\n", discovery_registry_path, sha256(discovery_registry_path)))
cat(sprintf("Sealed registry: %s (sha256=%s)\n", sealed_registry_path, sha256(sealed_registry_path)))
cat(sprintf("Dynamic seeds: %s\n", paste(plan$seed_contract$seed, collapse = ", ")))
cat(sprintf("Discovery: %d profiles, %d specs, 20 workers\n", nrow(plan$profiles), expected_specs))

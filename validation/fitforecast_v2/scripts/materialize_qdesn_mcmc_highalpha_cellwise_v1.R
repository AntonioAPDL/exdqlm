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
  stop("High-alpha cellwise v1 requires exdqlm 1.0.0.", call. = FALSE)
}

stage_stub <- "qdesn_dynamic_fitforecast_v2_500obs_mcmc_highalpha_cellwise_v1"
config_stub <- file.path("config", "validation", stage_stub)
source_config_path <- resolve_path(paste0(config_stub, "_source_replicates.yaml"))
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
workers <- suppressWarnings(as.integer(get_arg("--workers", "20"))[1L])
if (!is.finite(workers) || workers != 20L) {
  stop("This campaign contract requires exactly 20 workers.", call. = FALSE)
}
refresh_sources <- !has_flag("--no-source-refresh")
refresh_staged <- !has_flag("--no-staged-refresh")

source_cfg <- yaml::read_yaml(source_config_path)
generation_cfg <- source_cfg$generation %||% list()
replicates <- source_cfg$replicates %||% list()
roles <- vapply(replicates, function(x) as.character(x$role), character(1L))
if (length(replicates) != 4L || sum(roles == "discovery") != 3L || sum(roles == "sealed_holdout") != 1L) {
  stop("Source contract requires three discovery replicates and one sealed holdout.", call. = FALSE)
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
if (anyDuplicated(c(seed_table$latent_seed, seed_table$noise_seed))) {
  stop("Every DGP seed must be unique.", call. = FALSE)
}

source_root_rows <- list()
source_slice_rows <- list()
for (replicate in replicates) {
  family_profiles <- generation_cfg$family_profiles
  for (family in names(family_profiles)) family_profiles[[family]]$seeds <- replicate$seeds[[family]]
  manifest <- list(
    meta = list(
      study_id = source_cfg$meta$study_id,
      scenario_id = replicate$scenario_id,
      notes = sprintf("High-alpha %s trajectory %s.", replicate$role, replicate$replicate_id)
    ),
    generation = utils::modifyList(generation_cfg, list(family_profiles = family_profiles)),
    qdesn_materialization = list(
      staged_root = file.path(
        "results", "qdesn_mcmc_validation", stage_stub, "source_windows", replicate$scenario_id
      )
    )
  )
  generated <- exdqlm:::qdesn_dynamic_candidate_generate_bundle(
    manifest = manifest,
    repo_root = repo_root,
    refresh = refresh_sources,
    verbose = TRUE
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
source_roots <- source_roots[order(source_roots$source_role, source_roots$replicate_id, source_roots$family, source_roots$tau), , drop = FALSE]
source_slices <- source_slices[order(source_slices$source_role, source_slices$replicate_id, source_slices$family, source_slices$tau), , drop = FALSE]

evidence_root <- file.path("reports", "qdesn_mcmc_validation", stage_stub, "materialization")
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
seed_contract_path <- write_csv(seed_table, paste0(config_stub, "_source_seed_contract.csv"))

plan <- qdesn_hacv1_build_plan(interface_path)
topology_audit <- qdesn_hacv1_topology_audit(plan$profiles)
parents_path <- write_csv(plan$parents, paste0(config_stub, "_authoritative_parent_profiles.csv"))
targets_path <- write_csv(plan$authority$targets, paste0(config_stub, "_target_cells.csv"))
metric_sources_path <- write_csv(plan$metric_sources, paste0(config_stub, "_authoritative_metric_sources.csv"))
topology_classes_path <- write_csv(plan$topology_classes, paste0(config_stub, "_topology_classes.csv"))
alpha_rho_path <- write_csv(plan$alpha_rho_design, paste0(config_stub, "_alpha_rho_design.csv"))
alpha_only_path <- write_csv(plan$alpha_only_design, paste0(config_stub, "_alpha_only_design.csv"))
profiles_path <- write_csv(plan$profiles, paste0(config_stub, "_profiles.csv"))
assignments_path <- write_csv(plan$assignments, paste0(config_stub, "_cell_assignments.csv"))
topology_audit_path <- write_csv(topology_audit, paste0(config_stub, "_topology_audit.csv"))

novelty <- unique(plan$profiles[, c(
  "target_cell_id", "launch_wave", "candidate_id", "arm_code", "design_role",
  "topology_search_mode", "topology_mode", "alpha", "rho", "pi_w", "pi_in",
  "rhs_tau0", "D", "n_each", "m"
), drop = FALSE])
novelty$nominal_historical_bridge <- grepl("historical_bridge", novelty$design_role)
novelty$exact_historical_repeat <- FALSE
novelty$repeat_disposition <- ifelse(
  novelty$arm_code == "parent_exact",
  "intentional_exact_authority_control_on_fresh_sources",
  ifelse(
    novelty$nominal_historical_bridge,
    "intentional_alpha_bridge_but_new_source_and_corrected_train_only_protocol",
    "new_high_alpha_current_protocol_candidate"
  )
)
novelty_path <- write_csv(novelty, paste0(config_stub, "_nonrepeat_ledger.csv"))

base_defaults <- yaml::read_yaml(base_defaults_path)
if (!identical(base_defaults$preproc$fit_scope, "train_only") ||
    !identical(base_defaults$study_contract$preprocessing$scope, "train_only")) {
  stop("Base defaults are not the corrected train-only protocol.", call. = FALSE)
}
discovery_replicates <- replicates[roles == "discovery"]
discovery_scenarios <- vapply(discovery_replicates, function(x) as.character(x$scenario_id), character(1L))
contract_families <- sort(unique(plan$assignments$family))
contract_taus <- sort(unique(plan$assignments$tau))
dynamic_root <- as.character(generation_cfg$output_parent)
staged_root <- file.path("results", "qdesn_mcmc_validation", stage_stub, "source_windows")

generated_paths <- c(
  source_config_path, interface_path, base_defaults_path, seed_contract_path,
  source_registry_path, source_slice_registry_path, discovery_registry_path,
  sealed_registry_path, parents_path, targets_path, metric_sources_path,
  topology_classes_path, alpha_rho_path, alpha_only_path, profiles_path,
  assignments_path, topology_audit_path, novelty_path
)
phase_rows <- list()
for (phase in c("wave1", "wave2_universe")) {
  phase_profiles <- plan$profiles[plan$profiles$launch_wave == phase, , drop = FALSE]
  phase_assignments <- plan$assignments[plan$assignments$launch_wave == phase, , drop = FALSE]
  expected_specs <- nrow(phase_profiles) * length(discovery_scenarios)
  phase_stub <- paste(stage_stub, phase, sep = "_")
  phase_profiles_path <- write_csv(phase_profiles, paste0(config_stub, "_", phase, "_profiles.csv"))
  phase_assignments_path <- write_csv(phase_assignments, paste0(config_stub, "_", phase, "_cell_assignments.csv"))

  defaults <- base_defaults
  defaults$campaign <- list(
    name = phase_stub,
    results_root = file.path("results", "qdesn_mcmc_validation", phase_stub),
    reports_root = file.path("reports", "qdesn_mcmc_validation", phase_stub)
  )
  defaults$grid$source_mode <- "materialized_source_inputs"
  defaults$execution$methods <- "mcmc"
  defaults$execution$likelihood_families <- as.list(c("al", "exal"))
  defaults$execution$allowed_fit_spec_ids <- NULL
  defaults$execution$seed_policy <- list(mode = "shared", base_seed = 1806001L)
  defaults$source_materialization <- list(
    dynamic_root = dynamic_root,
    staged_root = staged_root,
    enforce_effective_train_size = TRUE,
    train_end_source_index = 9000L,
    forecast_origin_source_index = 9000L,
    forecast_horizon = 1000L,
    scenarios = as.list(discovery_scenarios),
    families = as.list(contract_families),
    taus = as.list(contract_taus),
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
    families = as.list(contract_families),
    taus = as.list(contract_taus),
    fit_sizes = 500L,
    expected_unique_dataset_cells = length(discovery_scenarios) *
      length(contract_families) * length(contract_taus),
    expected_qdesn_roots = nrow(phase_profiles) * length(discovery_scenarios) *
      length(contract_families) * length(contract_taus),
    expected_priors = "rhs_ns",
    expected_selected_qdesn_roots = expected_specs
  )
  defaults$screening_profiles <- list(
    enabled = TRUE,
    csv = rel_path(phase_profiles_path),
    cell_assignments_csv = rel_path(phase_assignments_path),
    priors = "rhs_ns",
    design = sprintf("Case-specific topology-aware high-alpha MCMC %s.", phase),
    execution_grid_policy = "cell_specific_subset_grid",
    canonical_profile_count = nrow(phase_profiles),
    canonical_dataset_cell_count = defaults$reference_contract$expected_unique_dataset_cells,
    canonical_qdesn_root_count = defaults$reference_contract$expected_qdesn_roots,
    selected_assignment_root_count = expected_specs
  )
  defaults$study_contract$core_lane <- FALSE
  defaults$study_contract$id <- paste0(phase_stub, "_2026_08_06")
  defaults$study_contract$description <- paste(
    "Case-specific independent Q-DESN/exQ-DESN RHS high-alpha MCMC calibration.",
    "Exact authoritative D/n/m/tau0/readout settings are held fixed; rho is varied only when realized recurrence is active."
  )
  defaults$study_contract$source_registry_identity_field <- "development_source_registry_sha256"
  defaults$study_contract$development_source_registry_sha256 <- sha256(discovery_registry_path)
  defaults$study_contract$development_source_registry_path <- discovery_registry_path
  defaults$study_contract$sealed_holdout_registry_sha256 <- sha256(sealed_registry_path)
  defaults$study_contract$sealed_holdout_registry_path <- sealed_registry_path
  defaults$study_contract$authoritative_interface_path <- interface_path
  defaults$study_contract$authoritative_interface_sha256 <- expected_interface_sha256
  defaults$study_contract$budget <- list(
    posterior_metric_draws = 100L,
    vb_sampling_nd_draws = 100L,
    vb_synthesis_n_samp = 100L,
    mcmc_n_burn = 1000L,
    mcmc_n_mcmc = 3000L,
    mcmc_thin = 1L
  )
  defaults$study_contract$selection_policy <- list(
    unit = "target_cell_by_source_replicate_by_reservoir_seed",
    comparison_policy = "paired_to_exact_authoritative_parent_on_same_source_and_reservoir_seed",
    selection_policy = "per_cell_only_no_global_winner",
    target_gate = "median target metric ratio <= 0.98",
    companion_gate = "median non-target metric ratio <= 1.05",
    stability_gate = "q90 target metric ratio <= 1.10",
    status_policy = "retain status and finite metrics; never hide failures",
    article_policy = "no article update from screening budget"
  )
  defaults$study_contract$confirmation_budget <- list(
    posterior_metric_draws = 200L,
    mcmc_n_burn = 5000L,
    mcmc_n_mcmc = 20000L,
    mcmc_thin = 1L,
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
  defaults$pipeline$outputs$retention_profile <- "storage_light_highalpha_cellwise_v1"
  defaults$smoke <- list(
    scenario = discovery_scenarios[[1L]],
    family = as.character(phase_assignments$family[[1L]]),
    tau = as.numeric(phase_assignments$tau[[1L]]),
    fit_sizes = 500L,
    priors = as.list("rhs_ns"),
    screening_profile_ids = as.list(as.character(phase_profiles$screening_profile_id[[1L]])),
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

  defaults_path <- resolve_path(paste0(config_stub, "_", phase, "_defaults.yaml"), FALSE)
  yaml::write_yaml(defaults, defaults_path)
  loaded <- exdqlm:::qdesn_dynamic_crossstudy_load_defaults(defaults_path)
  canonical <- exdqlm:::qdesn_dynamic_crossstudy_build_grid(
    loaded,
    refresh_materialized = isTRUE(refresh_staged && phase == "wave1"),
    verbose = TRUE
  )
  exdqlm:::qdesn_dynamic_crossstudy_validate_grid(canonical, loaded)
  lookup <- phase_profiles[, c(
    "screening_profile_id", "target_cell_id", "target_metrics", "likelihood_target",
    "target_family", "target_tau", "parent_profile_id", "parent_candidate_id",
    "candidate_id", "arm_code", "design_role", "topology_search_mode",
    "topology_mode", "reservoir_replicate", "paired_reservoir_seed", "launch_wave"
  ), drop = FALSE]
  grid_key <- paste(canonical$screening_profile_id, canonical$source_family, tau_key(canonical$tau), sep = "\r")
  target_key <- paste(lookup$screening_profile_id, lookup$target_family, tau_key(lookup$target_tau), sep = "\r")
  selected <- canonical[grid_key %in% target_key, , drop = FALSE]
  selected <- merge(selected, lookup, by = "screening_profile_id", all.x = TRUE, sort = FALSE)
  selected <- selected[order(
    selected$target_cell_id, selected$candidate_id, selected$reservoir_replicate,
    selected$source_scenario
  ), , drop = FALSE]
  if (nrow(selected) != expected_specs || anyNA(selected$likelihood_target)) {
    stop(sprintf("%s expected %d selected roots; found %d.", phase, expected_specs, nrow(selected)), call. = FALSE)
  }
  grid_path <- write_csv(selected, paste0(config_stub, "_", phase, "_grid.csv"))
  atomic <- exdqlm:::qdesn_dynamic_fitforecast_atomic_spec_grid(
    selected, defaults = loaded, methods = "mcmc", likelihood_families = c("al", "exal")
  )
  atomic <- merge(
    atomic,
    lookup[, c("screening_profile_id", "likelihood_target", "target_cell_id", "candidate_id", "arm_code", "reservoir_replicate"), drop = FALSE],
    by = "screening_profile_id", all.x = TRUE, sort = FALSE
  )
  target_specs <- atomic[atomic$likelihood_family == atomic$likelihood_target, , drop = FALSE]
  target_specs <- target_specs[order(target_specs$target_cell_id, target_specs$candidate_id, target_specs$root_id), , drop = FALSE]
  if (nrow(target_specs) != expected_specs || anyDuplicated(target_specs$spec_id)) {
    stop(sprintf("%s expected %d unique specs; found %d.", phase, expected_specs, nrow(target_specs)), call. = FALSE)
  }
  target_specs_path <- write_csv(target_specs, paste0(config_stub, "_", phase, "_target_spec_ids.csv"))
  loaded$execution$allowed_fit_spec_ids <- as.list(as.character(target_specs$spec_id))
  yaml::write_yaml(loaded, defaults_path)
  phase_manifest <- list(
    generated_at = as.character(Sys.time()),
    stage_stub = phase_stub,
    phase = phase,
    package_version = as.character(description[1L, "Version"]),
    materialization_base_commit = trimws(system("git rev-parse HEAD", intern = TRUE)),
    authority_interface_path = interface_path,
    authority_interface_sha256 = expected_interface_sha256,
    discovery_source_registry_path = discovery_registry_path,
    discovery_source_registry_sha256 = sha256(discovery_registry_path),
    sealed_holdout_registry_path = sealed_registry_path,
    sealed_holdout_registry_sha256 = sha256(sealed_registry_path),
    profiles_path = phase_profiles_path,
    assignments_path = phase_assignments_path,
    defaults_path = defaults_path,
    grid_path = grid_path,
    target_specs_path = target_specs_path,
    expected_specs = expected_specs,
    workers = 20L,
    threads_per_worker = 1L,
    launch_state = if (phase == "wave1") "ready_for_gated_launch" else "materialized_not_approved"
  )
  phase_manifest_path <- write_json(phase_manifest, paste0(config_stub, "_", phase, "_materialization_manifest.json"))
  phase_rows[[phase]] <- data.frame(
    phase = phase,
    target_cells = length(unique(phase_profiles$target_cell_id)),
    profiles = nrow(phase_profiles),
    expected_specs = expected_specs,
    defaults_path = defaults_path,
    grid_path = grid_path,
    target_specs_path = target_specs_path,
    manifest_path = phase_manifest_path,
    launch_approved = phase == "wave1",
    stringsAsFactors = FALSE
  )
  generated_paths <- c(
    generated_paths, phase_profiles_path, phase_assignments_path,
    defaults_path, grid_path, target_specs_path, phase_manifest_path
  )
}

phase_index <- do.call(rbind, phase_rows)
phase_index_path <- write_csv(phase_index, paste0(config_stub, "_phase_index.csv"))
source_window_audit <- exdqlm:::qdesn_dynamic_fitforecast_verify_source_windows(
  file.path(resolve_path(staged_root), "materialized_source_inventory.csv"),
  expected_train_end = 9000L,
  expected_forecast_end = 10000L,
  stop_on_fail = TRUE
)
source_window_audit_path <- write_csv(source_window_audit, file.path(evidence_root, "source_window_audit.csv"))
generated_paths <- c(generated_paths, phase_index_path, source_window_audit_path)

generated_paths <- unique(normalizePath(generated_paths, winslash = "/", mustWork = TRUE))
generated_manifest <- data.frame(
  path = generated_paths,
  relative_path = vapply(generated_paths, rel_path, character(1L)),
  bytes = as.numeric(file.info(generated_paths)$size),
  sha256 = vapply(generated_paths, sha256, character(1L)),
  stringsAsFactors = FALSE
)
generated_manifest_path <- write_csv(generated_manifest, paste0(config_stub, "_generated_file_manifest.csv"))

manifest <- list(
  generated_at = as.character(Sys.time()),
  stage_stub = stage_stub,
  package_version = as.character(description[1L, "Version"]),
  materialization_base_commit = trimws(system("git rev-parse HEAD", intern = TRUE)),
  authority_interface_path = interface_path,
  authority_interface_sha256 = expected_interface_sha256,
  authority_source_registry_identity = unique(plan$authority$targets$source_registry_hash_value),
  source_config_path = source_config_path,
  source_config_sha256 = sha256(source_config_path),
  source_registry_path = source_registry_path,
  source_registry_sha256 = sha256(source_registry_path),
  discovery_source_registry_path = discovery_registry_path,
  discovery_source_registry_sha256 = sha256(discovery_registry_path),
  sealed_holdout_registry_path = sealed_registry_path,
  sealed_holdout_registry_sha256 = sha256(sealed_registry_path),
  source_slice_registry_path = source_slice_registry_path,
  source_window_audit_path = source_window_audit_path,
  target_cells_path = targets_path,
  parent_profiles_path = parents_path,
  metric_sources_path = metric_sources_path,
  topology_classes_path = topology_classes_path,
  topology_audit_path = topology_audit_path,
  nonrepeat_ledger_path = novelty_path,
  phase_index_path = phase_index_path,
  generated_file_manifest_path = generated_manifest_path,
  counts = list(
    unresolved_cells = nrow(plan$parents),
    wave1_cells = sum(plan$parents$launch_wave == "wave1"),
    wave2_cells = sum(plan$parents$launch_wave == "wave2_universe"),
    discovery_sources = sum(roles == "discovery"),
    sealed_sources = sum(roles == "sealed_holdout"),
    profiles = nrow(plan$profiles),
    wave1_specs = phase_index$expected_specs[phase_index$phase == "wave1"],
    wave2_universe_specs = phase_index$expected_specs[phase_index$phase == "wave2_universe"]
  ),
  launch_policy = list(
    wave1 = "approved_after_tests_smoke_and_clean_pushed_branch",
    wave2 = "requires_wave1_mechanism_gate_and_explicit_followup",
    full_confirmation = "requires_per_cell_winner_gate_and_explicit_followup"
  ),
  article_state = "unchanged_screening_not_article_evidence"
)
manifest_path <- write_json(manifest, paste0(config_stub, "_materialization_manifest.json"))

cat(sprintf("Materialization manifest: %s\n", manifest_path))
cat(sprintf("Authority interface: %s (sha256=%s)\n", interface_path, expected_interface_sha256))
cat(sprintf("Discovery registry: %s (sha256=%s)\n", discovery_registry_path, sha256(discovery_registry_path)))
cat(sprintf("Sealed registry: %s (sha256=%s)\n", sealed_registry_path, sha256(sealed_registry_path)))
cat(sprintf("Wave 1: %d profiles, %d specs, 20 workers\n",
  phase_index$profiles[phase_index$phase == "wave1"],
  phase_index$expected_specs[phase_index$phase == "wave1"]))
cat(sprintf("Wave 2 universe: %d profiles, %d specs, not launch-approved\n",
  phase_index$profiles[phase_index$phase == "wave2_universe"],
  phase_index$expected_specs[phase_index$phase == "wave2_universe"]))

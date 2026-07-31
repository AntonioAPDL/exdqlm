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

resolve_path <- function(path, must_work = TRUE) {
  path <- as.character(path)[1L]
  if (!grepl("^/", path)) path <- file.path(repo_root, path)
  normalizePath(path, winslash = "/", mustWork = isTRUE(must_work))
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
  stop("Alpha/rho topology v1 requires the exdqlm 1.0.0 baseline.", call. = FALSE)
}

stage_stub <- "qdesn_dynamic_fitforecast_v2_500obs_alpha_rho_topology_v1"
config_stub <- file.path("config", "validation", stage_stub)
source_config_path <- resolve_path(paste0(config_stub, "_source_replicates.yaml"))
base_defaults_path <- resolve_path(get_arg(
  "--base-defaults",
  file.path("config", "validation", "qdesn_dynamic_fitforecast_v2_tt500_mcmc_newhypothesis_v1_defaults.yaml")
))
workers <- suppressWarnings(as.integer(get_arg("--workers", "16")))
if (!is.finite(workers) || workers < 1L) workers <- 16L
workers <- min(workers, 20L)
refresh_sources <- !has_flag("--no-source-refresh")
refresh_staged <- !has_flag("--no-staged-refresh")

source_cfg <- yaml::read_yaml(source_config_path)
generation_cfg <- source_cfg$generation %||% list()
replicates <- source_cfg$replicates %||% list()
if (length(replicates) != 3L) stop("Source contract requires exactly three development replicates.", call. = FALSE)

source_root_rows <- list()
source_slice_rows <- list()
for (replicate in replicates) {
  family_profiles <- generation_cfg$family_profiles
  for (family in names(family_profiles)) {
    family_profiles[[family]]$seeds <- replicate$seeds[[family]]
  }
  manifest <- list(
    meta = list(
      study_id = source_cfg$meta$study_id,
      scenario_id = replicate$scenario_id,
      notes = sprintf(
        "Deterministic alpha/rho topology v1 development source replicate %s; not article-facing.",
        replicate$replicate_id
      )
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
  slices <- generated$slice_inventory
  slices$replicate_id <- as.character(replicate$replicate_id)
  source_root_rows[[length(source_root_rows) + 1L]] <- roots
  source_slice_rows[[length(source_slice_rows) + 1L]] <- slices
}
source_roots <- do.call(rbind, source_root_rows)
source_slices <- do.call(rbind, source_slice_rows)
source_roots <- source_roots[order(source_roots$replicate_id, source_roots$family, source_roots$tau), , drop = FALSE]
source_slices <- source_slices[order(source_slices$replicate_id, source_slices$family, source_slices$tau), , drop = FALSE]

evidence_root <- file.path("reports", "qdesn_mcmc_validation", stage_stub, "materialization")
source_registry_path <- write_csv(source_roots, file.path(evidence_root, "source_registry.csv"))
source_slice_registry_path <- write_csv(source_slices, file.path(evidence_root, "source_slice_registry.csv"))
source_registry_hash <- sha256(source_registry_path)

plan <- qdesn_arv1_build_plan(repo_root)
profiles_path <- write_csv(plan$profiles, paste0(config_stub, "_profiles.csv"))
assignments_path <- write_csv(plan$assignments, paste0(config_stub, "_cell_assignments.csv"))
arms_path <- write_csv(plan$arms, paste0(config_stub, "_arm_design.csv"))
parents_path <- write_csv(plan$parents, paste0(config_stub, "_parent_profiles.csv"))
topology_audit <- qdesn_arv1_topology_audit(plan$profiles)
topology_audit_path <- write_csv(topology_audit, paste0(config_stub, "_topology_audit.csv"))

defaults <- yaml::read_yaml(base_defaults_path)
scenario_ids <- vapply(replicates, function(x) as.character(x$scenario_id), character(1L))
families <- sort(unique(plan$assignments$family))
taus <- sort(unique(as.numeric(plan$assignments$tau)))
dynamic_root <- as.character(generation_cfg$output_parent)
staged_root <- file.path("results", "qdesn_mcmc_validation", stage_stub, "source_windows")

defaults$campaign <- list(
  name = stage_stub,
  results_root = file.path("results", "qdesn_mcmc_validation", stage_stub),
  reports_root = file.path("reports", "qdesn_mcmc_validation", stage_stub)
)
defaults$grid$source_mode <- "materialized_source_inputs"
defaults$execution$methods <- "mcmc"
defaults$execution$likelihood_families <- as.list(c("al", "exal"))
defaults$execution$allowed_fit_spec_ids <- NULL
defaults$execution$seed_policy <- list(mode = "shared", base_seed = 41000L)
defaults$study_contract$core_lane <- FALSE
defaults$study_contract$id <- paste0(stage_stub, "_2026_07_31")
defaults$study_contract$description <- paste(
  "Independent Q-DESN/exQ-DESN RHS topology and broad alpha/rho mechanism screen.",
  "Selection uses three deterministic development trajectories and two reservoir replicates.",
  "The frozen article trajectory is excluded until full-budget confirmation."
)
defaults$study_contract$budget <- list(
  posterior_metric_draws = 100L,
  vb_sampling_nd_draws = 100L,
  vb_synthesis_n_samp = 100L,
  mcmc_n_burn = 1000L,
  mcmc_n_mcmc = 3000L,
  mcmc_thin = 1L
)
defaults$study_contract$mcmc$require_init_from_vb <- TRUE
defaults$study_contract$screening_policy <- list(
  unit = "likelihood_family_tau_cell_by_source_and_reservoir_replicate",
  target_cells = nrow(plan$parents),
  mechanism_arms_per_cell = 4L,
  broad_alpha_rho_arms_per_cell = 32L,
  source_replicates = 3L,
  reservoir_replicates = 2L,
  comparison_policy = "paired_to_parent_exact_with_status_retained",
  selection_policy = "per_cell_only_no_global_winner",
  article_policy = "no_article_update_without_full_budget_frozen_source_confirmation"
)
defaults$study_contract$confirmation_budget <- list(
  mcmc_n_burn = 5000L,
  mcmc_n_mcmc = 20000L,
  mcmc_thin = 1L,
  source = "frozen_article_protocol_source",
  required_before_article_promotion = TRUE
)
defaults$study_contract$alpha_rho_topology_v1 <- list(
  alpha_levels = as.list(qdesn_arv1_alpha_levels()),
  rho_levels = as.list(qdesn_arv1_rho_levels()),
  broad_design = "24 deterministic transformed-space maximin points plus 8 boundary/interaction points",
  topology_controls = as.list(c("parent_exact", "recurrence_only", "input_only", "full_topology")),
  repaired_recurrent_expected_indegree = 4,
  repaired_input_expected_indegree_floor = 2,
  source_registry_path = source_registry_path,
  source_registry_sha256 = source_registry_hash
)

defaults$source_materialization <- list(
  dynamic_root = dynamic_root,
  staged_root = staged_root,
  enforce_effective_train_size = TRUE,
  train_end_source_index = 9000L,
  forecast_origin_source_index = 9000L,
  forecast_horizon = 1000L,
  scenarios = as.list(scenario_ids),
  families = as.list(families),
  taus = as.list(taus),
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
  scenarios = as.list(scenario_ids),
  families = as.list(families),
  taus = as.list(taus),
  fit_sizes = 500L,
  expected_unique_dataset_cells = length(scenario_ids) * length(families) * length(taus),
  expected_qdesn_roots = nrow(plan$profiles) * length(scenario_ids) * length(families) * length(taus),
  expected_priors = "rhs_ns",
  expected_selected_qdesn_roots = 1080L
)
defaults$screening_profiles <- list(
  enabled = TRUE,
  csv = sub(paste0("^", repo_root, "/?"), "", profiles_path),
  cell_assignments_csv = sub(paste0("^", repo_root, "/?"), "", assignments_path),
  priors = "rhs_ns",
  design = "Five case-specific parents x 36 arms x two reservoir seeds; selected on three independent development sources.",
  execution_grid_policy = "cell_specific_subset_grid",
  canonical_profile_count = nrow(plan$profiles),
  canonical_dataset_cell_count = length(scenario_ids) * length(families) * length(taus),
  canonical_qdesn_root_count = nrow(plan$profiles) * length(scenario_ids) * length(families) * length(taus),
  selected_assignment_root_count = 1080L
)
defaults$pilot$source_scenario <- scenario_ids[[1L]]
defaults$pilot$source_family <- plan$assignments$family[[1L]]
defaults$pilot$tau <- plan$assignments$tau[[1L]]
defaults$pilot$fit_size <- 500L
defaults$pilot$effective_fit_size <- 500L
defaults$pilot$source_total_size <- 1890L
defaults$pilot$beta_prior_type <- "rhs_ns"
defaults$runtime$threads <- 1L
defaults$runtime$campaign_workers <- workers
defaults$runtime$workers <- workers
defaults$runtime$root_scheduler <- "load_balanced"
defaults$diagnostics$fit_runtime$stream_child_stdout <- TRUE
defaults$diagnostics$fit_runtime$timeout_seconds <- 7200L
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
defaults$multiseed <- list(
  enabled = FALSE,
  mcmc_seed_reps = 1L,
  parallel_seed_workers = 1L,
  selection_metric = "paired_development_source_metrics",
  prune_nonwinning_heavy_outputs = TRUE
)

defaults_path <- resolve_path(paste0(config_stub, "_defaults.yaml"), FALSE)
yaml::write_yaml(defaults, defaults_path)
defaults_loaded <- exdqlm:::qdesn_dynamic_crossstudy_load_defaults(defaults_path)
canonical_grid <- exdqlm:::qdesn_dynamic_crossstudy_build_grid(
  defaults_loaded,
  refresh_materialized = refresh_staged,
  verbose = TRUE
)
exdqlm:::qdesn_dynamic_crossstudy_validate_grid(canonical_grid, defaults_loaded)

profile_lookup <- plan$profiles[, c(
  "screening_profile_id", "target_cell_id", "target_role", "likelihood_target",
  "target_family", "target_tau", "parent_profile_id", "arm_index", "arm_code",
  "arm_class", "topology_mode", "reservoir_replicate"
), drop = FALSE]
grid_key <- paste(canonical_grid$screening_profile_id, canonical_grid$source_family, tau_key(canonical_grid$tau), sep = "\r")
target_key <- paste(profile_lookup$screening_profile_id, profile_lookup$target_family, tau_key(profile_lookup$target_tau), sep = "\r")
selected_grid <- canonical_grid[grid_key %in% target_key, , drop = FALSE]
selected_grid <- merge(selected_grid, profile_lookup, by = "screening_profile_id", all.x = TRUE, sort = FALSE)
selected_grid <- selected_grid[order(
  selected_grid$target_cell_id,
  selected_grid$arm_index,
  selected_grid$reservoir_replicate,
  selected_grid$source_scenario
), , drop = FALSE]
if (nrow(selected_grid) != 1080L || anyNA(selected_grid$likelihood_target)) {
  stop(sprintf("Expected 1080 selected roots; found %d.", nrow(selected_grid)), call. = FALSE)
}

grid_path <- write_csv(selected_grid, paste0(config_stub, "_grid.csv"))
mechanism_grid <- selected_grid[selected_grid$arm_class == "mechanism_control", , drop = FALSE]
broad_grid <- selected_grid[selected_grid$arm_class != "mechanism_control", , drop = FALSE]
mechanism_grid_path <- write_csv(mechanism_grid, paste0(config_stub, "_mechanism_grid.csv"))
broad_grid_path <- write_csv(broad_grid, paste0(config_stub, "_broad_grid.csv"))

atomic <- exdqlm:::qdesn_dynamic_fitforecast_atomic_spec_grid(
  selected_grid,
  defaults = defaults_loaded,
  methods = "mcmc",
  likelihood_families = c("al", "exal")
)
atomic <- merge(
  atomic,
  profile_lookup[, c("screening_profile_id", "likelihood_target", "target_cell_id", "arm_code", "arm_class", "reservoir_replicate"), drop = FALSE],
  by = "screening_profile_id",
  all.x = TRUE,
  sort = FALSE
)
target_specs <- atomic[atomic$likelihood_family == atomic$likelihood_target, , drop = FALSE]
target_specs <- target_specs[order(target_specs$target_cell_id, target_specs$arm_class, target_specs$arm_code, target_specs$reservoir_replicate, target_specs$root_id), , drop = FALSE]
if (nrow(target_specs) != 1080L || anyDuplicated(target_specs$spec_id)) {
  stop(sprintf("Expected 1080 unique target specs; found %d.", nrow(target_specs)), call. = FALSE)
}
target_specs_path <- write_csv(target_specs, paste0(config_stub, "_target_spec_ids.csv"))
mechanism_specs <- target_specs[target_specs$arm_class == "mechanism_control", , drop = FALSE]
broad_specs <- target_specs[target_specs$arm_class != "mechanism_control", , drop = FALSE]
mechanism_specs_path <- write_csv(mechanism_specs, paste0(config_stub, "_mechanism_target_spec_ids.csv"))
broad_specs_path <- write_csv(broad_specs, paste0(config_stub, "_broad_target_spec_ids.csv"))
if (nrow(mechanism_specs) != 120L || nrow(broad_specs) != 960L) {
  stop(sprintf("Phase counts are wrong: mechanism=%d broad=%d.", nrow(mechanism_specs), nrow(broad_specs)), call. = FALSE)
}

expanded_assignments <- merge(
  selected_grid[, c("screening_profile_id", "source_scenario", "root_id"), drop = FALSE],
  plan$assignments,
  by = "screening_profile_id",
  all.x = TRUE,
  sort = FALSE
)
expanded_assignments <- expanded_assignments[order(expanded_assignments$target_cell_id, expanded_assignments$arm_index, expanded_assignments$reservoir_replicate, expanded_assignments$source_scenario), , drop = FALSE]
expanded_assignments_path <- write_csv(expanded_assignments, paste0(config_stub, "_expanded_assignments.csv"))

write_phase_defaults <- function(phase, phase_specs, phase_profiles, phase_grid_path) {
  phase_defaults <- defaults
  phase_defaults$campaign$name <- paste(stage_stub, phase, sep = "_")
  phase_defaults$campaign$results_root <- file.path("results", "qdesn_mcmc_validation", paste(stage_stub, phase, sep = "_"))
  phase_defaults$campaign$reports_root <- file.path("reports", "qdesn_mcmc_validation", paste(stage_stub, phase, sep = "_"))
  phase_defaults$execution$allowed_fit_spec_ids <- as.list(as.character(phase_specs$spec_id))
  phase_defaults$reference_contract$expected_selected_qdesn_roots <- nrow(phase_grid_path)
  phase_defaults$screening_profiles$selected_assignment_root_count <- nrow(phase_grid_path)
  phase_defaults$study_contract$id <- paste(stage_stub, phase, "2026_07_31", sep = "_")
  phase_defaults$study_contract$active_phase <- phase
  phase_defaults$smoke <- list(
    scenario = scenario_ids[[1L]],
    family = as.character(phase_profiles$target_family[[1L]]),
    tau = as.numeric(phase_profiles$target_tau[[1L]]),
    fit_sizes = 500L,
    priors = as.list("rhs_ns"),
    screening_profile_ids = as.list(as.character(phase_profiles$screening_profile_id[[1L]])),
    max_roots = 1L,
    budget = list(
      posterior_metric_draws = 4L,
      vb_sampling_nd_draws = 4L,
      vb_synthesis_n_samp = 4L,
      mcmc_n_burn = 4L,
      mcmc_n_mcmc = 4L,
      mcmc_thin = 1L
    ),
    pipeline = list(inference = list(mcmc = list(
      n_burn = 4L,
      n_mcmc = 4L,
      thin = 1L,
      progress_every = 1L,
      init_from_vb = TRUE
    )))
  )
  out <- paste0(config_stub, "_", phase, "_defaults.yaml")
  yaml::write_yaml(phase_defaults, resolve_path(out, FALSE))
  resolve_path(out)
}

mechanism_defaults_path <- write_phase_defaults(
  "mechanism", mechanism_specs,
  plan$profiles[plan$profiles$arm_class == "mechanism_control", , drop = FALSE],
  mechanism_grid
)
broad_defaults_path <- write_phase_defaults(
  "broad", broad_specs,
  plan$profiles[plan$profiles$arm_class != "mechanism_control", , drop = FALSE],
  broad_grid
)

source_window_audit <- exdqlm:::qdesn_dynamic_fitforecast_verify_source_windows(
  file.path(resolve_path(staged_root), "materialized_source_inventory.csv"),
  expected_train_end = 9000L,
  expected_forecast_end = 10000L,
  stop_on_fail = TRUE
)
source_window_audit_path <- write_csv(source_window_audit, file.path(evidence_root, "source_window_audit.csv"))

manifest <- list(
  generated_at = as.character(Sys.time()),
  stage_stub = stage_stub,
  package_version = as.character(description[1L, "Version"]),
  git_branch = trimws(system("git branch --show-current", intern = TRUE)),
  git_commit = trimws(system("git rev-parse HEAD", intern = TRUE)),
  source_config_path = source_config_path,
  source_config_sha256 = sha256(source_config_path),
  source_registry_path = source_registry_path,
  source_registry_sha256 = source_registry_hash,
  source_slice_registry_path = source_slice_registry_path,
  source_window_audit_path = source_window_audit_path,
  profiles_path = profiles_path,
  profiles_sha256 = sha256(profiles_path),
  assignments_path = assignments_path,
  expanded_assignments_path = expanded_assignments_path,
  arm_design_path = arms_path,
  parent_profiles_path = parents_path,
  topology_audit_path = topology_audit_path,
  topology_audit_sha256 = sha256(topology_audit_path),
  full_defaults_path = defaults_path,
  full_grid_path = grid_path,
  target_specs_path = target_specs_path,
  mechanism = list(
    defaults_path = mechanism_defaults_path,
    grid_path = mechanism_grid_path,
    target_specs_path = mechanism_specs_path,
    expected_specs = nrow(mechanism_specs)
  ),
  broad = list(
    defaults_path = broad_defaults_path,
    grid_path = broad_grid_path,
    target_specs_path = broad_specs_path,
    expected_specs = nrow(broad_specs)
  ),
  counts = list(
    target_cells = nrow(plan$parents),
    arms = nrow(plan$arms),
    profiles = nrow(plan$profiles),
    source_replicates = length(scenario_ids),
    mechanism_specs = nrow(mechanism_specs),
    broad_specs = nrow(broad_specs),
    total_specs = nrow(target_specs)
  ),
  launch_state = "materialized_not_launched"
)
manifest_path <- write_json(manifest, paste0(config_stub, "_materialization_manifest.json"))

cat(sprintf("Materialization manifest: %s\n", manifest_path))
cat(sprintf("Source registry: %s (sha256=%s)\n", source_registry_path, source_registry_hash))
cat(sprintf("Mechanism specs: %d\n", nrow(mechanism_specs)))
cat(sprintf("Broad specs: %d\n", nrow(broad_specs)))
cat(sprintf("Topology-valid broad profiles: %d/%d\n", sum(topology_audit$total_topology_valid[topology_audit$arm_class != "mechanism_control"]), sum(topology_audit$arm_class != "mechanism_control")))

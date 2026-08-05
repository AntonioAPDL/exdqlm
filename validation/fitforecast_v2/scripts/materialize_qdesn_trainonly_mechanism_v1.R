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
source(file.path(repo_root, "validation", "fitforecast_v2", "R", "qdesn_trainonly_mechanism_v1.R"))

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
  stop("Train-only mechanism v1 requires the exdqlm 1.0.0 baseline.", call. = FALSE)
}

stage_stub <- "qdesn_dynamic_fitforecast_v2_500obs_trainonly_mechanism_v1"
config_stub <- file.path("config", "validation", stage_stub)
source_config_path <- resolve_path(paste0(config_stub, "_source_replicates.yaml"))
base_defaults_path <- resolve_path(get_arg(
  "--base-defaults",
  file.path("config", "validation", "qdesn_dynamic_fitforecast_v2_500obs_trainonly_rebaseline_v1_defaults.yaml")
))
workers <- suppressWarnings(as.integer(get_arg("--workers", "16"))[1L])
if (!is.finite(workers) || workers < 1L) workers <- 16L
workers <- min(workers, 16L)
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
      notes = sprintf("Train-only mechanism development trajectory %s; never article-facing without confirmation.", replicate$replicate_id)
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

plan <- qdesn_tmv1_build_plan(repo_root)
all_profiles_path <- write_csv(plan$profiles, paste0(config_stub, "_profiles.csv"))
all_assignments_path <- write_csv(plan$assignments, paste0(config_stub, "_cell_assignments.csv"))
parents_path <- write_csv(plan$parents, paste0(config_stub, "_parent_profiles.csv"))
targets_path <- write_csv(plan$targets, paste0(config_stub, "_target_cells.csv"))
bundles_path <- write_csv(plan$bundles, paste0(config_stub, "_bundle_contract.csv"))
topology_audit <- qdesn_tmv1_topology_audit(plan$profiles)
topology_audit_path <- write_csv(topology_audit, paste0(config_stub, "_topology_audit.csv"))

novelty <- unique(plan$profiles[, c(
  "target_cell_id", "bundle_id", "arm_code", "arm_class", "topology_mode", "D", "n_each", "m",
  "alpha", "rho", "pi_w", "pi_in", "rhs_tau0"
), drop = FALSE])
novelty$historical_scalar_repeat_expected <- novelty$arm_code == "parent_exact"
novelty$novel_current_protocol_axis <- ifelse(
  novelty$arm_code == "parent_exact",
  "fresh_source_and_paired_seed_control",
  ifelse(
    novelty$bundle_id == "raw",
    "corrected_train_only_plus_active_topology",
    "corrected_train_only_plus_active_topology_plus_decomposition_input"
  )
)
novelty$repeat_disposition <- ifelse(
  novelty$arm_code == "parent_exact",
  "intentional_paired_control",
  "not_a_repeat_of_prior_scalar_only_screen"
)
novelty_path <- write_csv(novelty, paste0(config_stub, "_nonrepeat_ledger.csv"))

base_defaults <- yaml::read_yaml(base_defaults_path)
if (!identical(base_defaults$preproc$fit_scope, "train_only") ||
    !identical(base_defaults$study_contract$preprocessing$scope, "train_only")) {
  stop("Base defaults are not the corrected train-only protocol.", call. = FALSE)
}
scenario_ids <- vapply(replicates, function(x) as.character(x$scenario_id), character(1L))
families <- sort(unique(plan$assignments$family))
taus <- sort(unique(as.numeric(plan$assignments$tau)))
dynamic_root <- as.character(generation_cfg$output_parent)
staged_root <- file.path("results", "qdesn_mcmc_validation", stage_stub, "source_windows")

bundle_rows <- list()
generated_paths <- c(
  source_config_path, source_registry_path, source_slice_registry_path,
  all_profiles_path, all_assignments_path, parents_path, targets_path,
  bundles_path, topology_audit_path, novelty_path
)

for (bundle_i in seq_len(nrow(plan$bundles))) {
  bundle <- plan$bundles[bundle_i, , drop = FALSE]
  bundle_id <- as.character(bundle$bundle_id[[1L]])
  bundle_profiles <- plan$profiles[plan$profiles$bundle_id == bundle_id, , drop = FALSE]
  bundle_assignments <- plan$assignments[plan$assignments$bundle_id == bundle_id, , drop = FALSE]
  expected_specs <- as.integer(bundle$expected_specs[[1L]])
  bundle_stub <- paste(stage_stub, bundle_id, sep = "_")
  profiles_path <- write_csv(bundle_profiles, paste0(config_stub, "_", bundle_id, "_profiles.csv"))
  assignments_path <- write_csv(bundle_assignments, paste0(config_stub, "_", bundle_id, "_cell_assignments.csv"))

  defaults <- base_defaults
  defaults$campaign <- list(
    name = bundle_stub,
    results_root = file.path("results", "qdesn_mcmc_validation", bundle_stub),
    reports_root = file.path("reports", "qdesn_mcmc_validation", bundle_stub)
  )
  defaults$grid$source_mode <- "materialized_source_inputs"
  defaults$execution$methods <- "mcmc"
  defaults$execution$likelihood_families <- as.list(c("al", "exal"))
  defaults$execution$allowed_fit_spec_ids <- NULL
  defaults$execution$seed_policy <- list(mode = "shared", base_seed = 950001L)
  defaults$study_contract$core_lane <- FALSE
  defaults$study_contract$id <- paste0(bundle_stub, "_2026_08_05")
  defaults$study_contract$description <- paste(
    "Paired independent Q-DESN RHS train-only mechanism discovery campaign.",
    "Development sources are fresh and the article source is excluded.",
    "The experiment tests mechanism changes rather than another broad scalar hyperparameter surface."
  )
  defaults$study_contract$source_registry_identity_field <- "development_source_registry_sha256"
  defaults$study_contract$development_source_registry_sha256 <- source_registry_hash
  defaults$study_contract$development_source_registry_path <- source_registry_path
  defaults$study_contract$budget <- list(
    posterior_metric_draws = 100L,
    vb_sampling_nd_draws = 100L,
    vb_synthesis_n_samp = 100L,
    mcmc_n_burn = 1000L,
    mcmc_n_mcmc = 3000L,
    mcmc_thin = 1L
  )
  defaults$study_contract$mcmc <- defaults$study_contract$mcmc %||% list()
  defaults$study_contract$mcmc$require_init_from_vb <- TRUE
  defaults$study_contract$selection_policy <- list(
    unit = "target_cell_by_source_replicate_by_reservoir_seed",
    comparison_policy = "paired_to_parent_exact_on_the_same_source_and_reservoir_seed",
    selection_policy = "per_cell_only_no_global_winner",
    primary_gate = "median_target_metric_improvement_at_least_2pct_and_no_companion_median_regression_over_5pct",
    stability_gate = "worst_q90_candidate_parent_ratio_at_most_1p10",
    status_policy = "retain_status_and_finite_metrics;never_hide_failures",
    article_policy = "no_article_update_without_full_budget_confirmation_on_frozen_and_fresh_sources"
  )
  defaults$study_contract$confirmation_budget <- list(
    posterior_metric_draws = 200L,
    mcmc_n_burn = 5000L,
    mcmc_n_mcmc = 20000L,
    mcmc_thin = 1L,
    required_before_article_promotion = TRUE
  )
  defaults$study_contract$mechanism <- list(
    bundle_id = bundle_id,
    input_mode = as.character(bundle$input_mode[[1L]]),
    input_builder = as.character(bundle$input_builder[[1L]]),
    harmonics = as.list(as.integer(strsplit(bundle$harmonics[[1L]], ",", fixed = TRUE)[[1L]])),
    expected_specs = expected_specs
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
    expected_qdesn_roots = nrow(bundle_profiles) * length(scenario_ids) * length(families) * length(taus),
    expected_priors = "rhs_ns",
    expected_selected_qdesn_roots = expected_specs
  )
  defaults$screening_profiles <- list(
    enabled = TRUE,
    csv = rel_path(profiles_path),
    cell_assignments_csv = rel_path(assignments_path),
    priors = "rhs_ns",
    design = sprintf("Train-only mechanism v1 bundle %s with paired source/reservoir controls.", bundle_id),
    execution_grid_policy = "cell_specific_subset_grid",
    canonical_profile_count = nrow(bundle_profiles),
    canonical_dataset_cell_count = length(scenario_ids) * length(families) * length(taus),
    canonical_qdesn_root_count = nrow(bundle_profiles) * length(scenario_ids) * length(families) * length(taus),
    selected_assignment_root_count = expected_specs
  )
  defaults$pilot$source_scenario <- scenario_ids[[1L]]
  defaults$pilot$source_family <- bundle_assignments$family[[1L]]
  defaults$pilot$tau <- bundle_assignments$tau[[1L]]
  defaults$pilot$fit_size <- 500L
  defaults$pilot$effective_fit_size <- 500L
  defaults$pilot$source_total_size <- 1890L
  defaults$pilot$beta_prior_type <- "rhs_ns"
  defaults$runtime$threads <- 1L
  defaults$runtime$campaign_workers <- workers
  defaults$runtime$workers <- workers
  defaults$runtime$root_scheduler <- "load_balanced"
  defaults$diagnostics$fit_runtime$stream_child_stdout <- TRUE
  defaults$diagnostics$fit_runtime$timeout_seconds <- 21600L
  defaults$diagnostics$fit_runtime$timeout_kill_after_seconds <- 60L
  defaults$metrics$posterior_metric_draws <- 100L
  defaults$pipeline$readout$input_mode <- as.character(bundle$input_mode[[1L]])
  defaults$pipeline$decomposition <- qdesn_tmv1_decomposition(bundle_id)
  defaults$pipeline$validation_guardrails <- defaults$pipeline$validation_guardrails %||% list()
  defaults$pipeline$validation_guardrails$allow_dlm_decomp_lags <- bundle_id != "raw"
  defaults$pipeline$validation_guardrails$allow_dlm_decomp_lags_reason <- if (bundle_id == "raw") {
    "raw paired control"
  } else {
    "explicit independent-validation mechanism discovery bundle"
  }
  harmonics <- as.integer(strsplit(bundle$harmonics[[1L]], ",", fixed = TRUE)[[1L]])
  defaults$deterministic_features$enabled <- TRUE
  defaults$deterministic_features$period <- 90L
  defaults$deterministic_features$harmonics <- as.list(harmonics)
  defaults$deterministic_features$include_trend <- TRUE
  defaults$deterministic_features$prefix <- "period90"
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
  defaults$pipeline$outputs$retention_profile <- "storage_light_trainonly_mechanism_v1"
  defaults$multiseed <- list(
    enabled = FALSE,
    mcmc_seed_reps = 1L,
    parallel_seed_workers = 1L,
    selection_metric = "paired_development_source_metrics",
    prune_nonwinning_heavy_outputs = TRUE
  )
  defaults$smoke <- list(
    scenario = scenario_ids[[1L]],
    family = as.character(bundle_assignments$family[[1L]]),
    tau = as.numeric(bundle_assignments$tau[[1L]]),
    fit_sizes = 500L,
    priors = as.list("rhs_ns"),
    screening_profile_ids = as.list(as.character(bundle_profiles$screening_profile_id[[1L]])),
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
      n_burn = 4L, n_mcmc = 4L, thin = 1L, progress_every = 1L, init_from_vb = TRUE,
      vb_warm_start_control = list(max_iter = 5L, min_iter_elbo = 2L, n_samp_xi = 10L)
    )))
  )

  defaults_path <- resolve_path(paste0(config_stub, "_", bundle_id, "_defaults.yaml"), FALSE)
  yaml::write_yaml(defaults, defaults_path)
  loaded <- exdqlm:::qdesn_dynamic_crossstudy_load_defaults(defaults_path)
  canonical <- exdqlm:::qdesn_dynamic_crossstudy_build_grid(
    loaded,
    refresh_materialized = isTRUE(refresh_staged && bundle_i == 1L),
    verbose = TRUE
  )
  exdqlm:::qdesn_dynamic_crossstudy_validate_grid(canonical, loaded)

  lookup <- bundle_profiles[, c(
    "screening_profile_id", "target_cell_id", "target_role", "primary_target",
    "target_family", "target_tau", "likelihood_target", "parent_profile_id",
    "bundle_id", "arm_code", "arm_class", "topology_mode", "reservoir_replicate",
    "paired_reservoir_seed"
  ), drop = FALSE]
  grid_key <- paste(canonical$screening_profile_id, canonical$source_family, tau_key(canonical$tau), sep = "\r")
  target_key <- paste(lookup$screening_profile_id, lookup$target_family, tau_key(lookup$target_tau), sep = "\r")
  selected <- canonical[grid_key %in% target_key, , drop = FALSE]
  selected <- merge(selected, lookup, by = "screening_profile_id", all.x = TRUE, sort = FALSE)
  selected <- selected[order(
    selected$target_cell_id, selected$arm_code, selected$reservoir_replicate,
    selected$source_scenario
  ), , drop = FALSE]
  if (nrow(selected) != expected_specs || anyNA(selected$likelihood_target)) {
    stop(sprintf("Bundle %s expected %d selected roots; found %d.", bundle_id, expected_specs, nrow(selected)), call. = FALSE)
  }
  grid_path <- write_csv(selected, paste0(config_stub, "_", bundle_id, "_grid.csv"))

  atomic <- exdqlm:::qdesn_dynamic_fitforecast_atomic_spec_grid(
    selected, defaults = loaded, methods = "mcmc", likelihood_families = c("al", "exal")
  )
  atomic <- merge(
    atomic,
    lookup[, c("screening_profile_id", "likelihood_target", "target_cell_id", "bundle_id", "arm_code", "reservoir_replicate"), drop = FALSE],
    by = "screening_profile_id", all.x = TRUE, sort = FALSE
  )
  target_specs <- atomic[atomic$likelihood_family == atomic$likelihood_target, , drop = FALSE]
  target_specs <- target_specs[order(
    target_specs$target_cell_id, target_specs$arm_code,
    target_specs$reservoir_replicate, target_specs$root_id
  ), , drop = FALSE]
  if (nrow(target_specs) != expected_specs || anyDuplicated(target_specs$spec_id)) {
    stop(sprintf("Bundle %s expected %d unique target specs; found %d.", bundle_id, expected_specs, nrow(target_specs)), call. = FALSE)
  }
  target_specs_path <- write_csv(target_specs, paste0(config_stub, "_", bundle_id, "_target_spec_ids.csv"))
  loaded$execution$allowed_fit_spec_ids <- as.list(as.character(target_specs$spec_id))
  yaml::write_yaml(loaded, defaults_path)

  bundle_manifest <- list(
    generated_at = as.character(Sys.time()),
    stage_stub = bundle_stub,
    bundle_id = bundle_id,
    package_version = as.character(description[1L, "Version"]),
    git_branch = trimws(system("git branch --show-current", intern = TRUE)),
    git_commit = trimws(system("git rev-parse HEAD", intern = TRUE)),
    source_registry_path = source_registry_path,
    source_registry_sha256 = source_registry_hash,
    profiles_path = profiles_path,
    assignments_path = assignments_path,
    defaults_path = defaults_path,
    grid_path = grid_path,
    target_specs_path = target_specs_path,
    expected_specs = expected_specs,
    launch_state = "materialized_not_launched"
  )
  manifest_path <- write_json(bundle_manifest, paste0(config_stub, "_", bundle_id, "_materialization_manifest.json"))
  generated_paths <- c(generated_paths, profiles_path, assignments_path, defaults_path, grid_path, target_specs_path, manifest_path)
  bundle_rows[[bundle_i]] <- data.frame(
    bundle_id = bundle_id,
    bundle_order = as.integer(bundle$bundle_order[[1L]]),
    input_mode = as.character(bundle$input_mode[[1L]]),
    input_builder = as.character(bundle$input_builder[[1L]]),
    harmonics = as.character(bundle$harmonics[[1L]]),
    expected_specs = expected_specs,
    defaults_path = defaults_path,
    grid_path = grid_path,
    target_specs_path = target_specs_path,
    manifest_path = manifest_path,
    stringsAsFactors = FALSE
  )
}

bundle_index <- do.call(rbind, bundle_rows)
bundle_index_path <- write_csv(bundle_index, paste0(config_stub, "_bundle_index.csv"))
generated_paths <- c(generated_paths, bundle_index_path)
source_window_audit <- exdqlm:::qdesn_dynamic_fitforecast_verify_source_windows(
  file.path(resolve_path(staged_root), "materialized_source_inventory.csv"),
  expected_train_end = 9000L,
  expected_forecast_end = 10000L,
  stop_on_fail = TRUE
)
source_window_audit_path <- write_csv(source_window_audit, file.path(evidence_root, "source_window_audit.csv"))
generated_paths <- c(generated_paths, source_window_audit_path)

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
  git_branch = trimws(system("git branch --show-current", intern = TRUE)),
  git_commit = trimws(system("git rev-parse HEAD", intern = TRUE)),
  git_dirty_at_materialization = length(system("git status --porcelain", intern = TRUE)) > 0L,
  source_config_path = source_config_path,
  source_config_sha256 = sha256(source_config_path),
  source_registry_path = source_registry_path,
  source_registry_sha256 = source_registry_hash,
  source_slice_registry_path = source_slice_registry_path,
  source_window_audit_path = source_window_audit_path,
  profiles_path = all_profiles_path,
  assignments_path = all_assignments_path,
  parent_profiles_path = parents_path,
  target_cells_path = targets_path,
  bundle_contract_path = bundles_path,
  bundle_index_path = bundle_index_path,
  topology_audit_path = topology_audit_path,
  nonrepeat_ledger_path = novelty_path,
  generated_file_manifest_path = generated_manifest_path,
  counts = list(
    target_cells = nrow(plan$targets),
    priority_cells = sum(plan$targets$primary_target),
    negative_controls = sum(!plan$targets$primary_target),
    source_replicates = length(scenario_ids),
    reservoir_replicates = 2L,
    profiles = nrow(plan$profiles),
    bundles = nrow(plan$bundles),
    total_specs = sum(bundle_index$expected_specs)
  ),
  launch_state = "materialized_not_launched",
  article_state = "unchanged_pending_full_budget_confirmation"
)
manifest_path <- write_json(manifest, paste0(config_stub, "_materialization_manifest.json"))

cat(sprintf("Materialization manifest: %s\n", manifest_path))
cat(sprintf("Development source registry: %s (sha256=%s)\n", source_registry_path, source_registry_hash))
cat(sprintf("Bundles: %s\n", paste(sprintf("%s=%d", bundle_index$bundle_id, bundle_index$expected_specs), collapse = ", ")))
cat(sprintf("Total target specs: %d\n", sum(bundle_index$expected_specs)))
cat(sprintf("Active-topology profiles: %d/%d valid\n", sum(topology_audit$total_topology_valid[topology_audit$arm_code != "parent_exact"]), sum(topology_audit$arm_code != "parent_exact")))

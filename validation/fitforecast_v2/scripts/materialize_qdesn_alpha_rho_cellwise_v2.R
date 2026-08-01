#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  required <- c("jsonlite", "pkgload", "yaml")
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
source(file.path(repo_root, "validation", "fitforecast_v2", "R", "qdesn_alpha_rho_cellwise_v2.R"))

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
  stop("Alpha/rho cellwise v2 requires the exdqlm 1.0.0 baseline.", call. = FALSE)
}

stage_stub <- "qdesn_dynamic_fitforecast_v2_500obs_alpha_rho_cellwise_v2"
config_stub <- file.path("config", "validation", stage_stub)
workers <- suppressWarnings(as.integer(get_arg("--workers", "8")))
if (!is.finite(workers) || workers < 1L) workers <- 8L
workers <- min(workers, 12L)
refresh_staged <- has_flag("--refresh-grid")

v1_worktree <- resolve_path(get_arg(
  "--v1-worktree",
  "/data/jaguir26/local/src/exdqlm__wt__qdesn_alpha_rho_topology_v1_1p0p0"
))
v1_stage_stub <- "qdesn_dynamic_fitforecast_v2_500obs_alpha_rho_topology_v1"
v1_config_stub <- file.path(v1_worktree, "config", "validation", v1_stage_stub)
v1_source_registry <- file.path(
  v1_worktree, "reports", "qdesn_mcmc_validation", v1_stage_stub,
  "materialization", "source_registry.csv"
)
v1_source_slice_registry <- file.path(
  v1_worktree, "reports", "qdesn_mcmc_validation", v1_stage_stub,
  "materialization", "source_slice_registry.csv"
)
v1_staged_root <- file.path(
  v1_worktree, "results", "qdesn_mcmc_validation", v1_stage_stub, "source_windows"
)
v1_dynamic_root <- file.path(
  v1_worktree, "results", "qdesn_mcmc_validation", v1_stage_stub, "source_replicates"
)
v1_baseline_metrics <- file.path(
  v1_worktree, "reports", "shared_fitforecast_v2_orchestration",
  "qdesn_alpha_rho_topology_v1_20260731_190255", "mechanism_audit", "mechanism_metrics.csv"
)
v1_manifest <- paste0(v1_config_stub, "_materialization_manifest.json")
required_v1 <- c(
  v1_source_registry, v1_source_slice_registry, v1_staged_root,
  v1_dynamic_root, v1_baseline_metrics, v1_manifest
)
missing_v1 <- required_v1[!file.exists(required_v1) & !dir.exists(required_v1)]
if (length(missing_v1)) {
  stop(sprintf("Missing frozen v1 evidence: %s", paste(missing_v1, collapse = ", ")), call. = FALSE)
}
expected_source_hash <- "07e5f3b11cccd01c5c69ba8ff4794d4d28f583b9c5e8aba8b9dbc953fe862444"
observed_source_hash <- unname(tools::sha256sum(v1_source_registry))
if (!identical(observed_source_hash, expected_source_hash)) {
  stop(sprintf("Frozen source registry hash mismatch: %s", observed_source_hash), call. = FALSE)
}

source_registry <- utils::read.csv(v1_source_registry, check.names = FALSE, stringsAsFactors = FALSE)
scenario_ids <- sort(unique(as.character(source_registry$scenario_id %||% source_registry$scenario)))
if (length(scenario_ids) != 3L) stop("The v2 design requires the three frozen development scenarios.", call. = FALSE)

plan <- qdesn_arv2_build_plan(repo_root)
topology_audit <- qdesn_arv2_topology_audit(plan$profiles)
profiles_path <- write_csv(plan$profiles, paste0(config_stub, "_profiles.csv"))
assignments_path <- write_csv(plan$assignments, paste0(config_stub, "_cell_assignments.csv"))
designs_path <- write_csv(plan$designs, paste0(config_stub, "_candidate_design.csv"))
search_map_path <- write_csv(plan$search_map, paste0(config_stub, "_search_map.csv"))
parents_path <- write_csv(plan$parents, paste0(config_stub, "_parent_profiles.csv"))
topology_audit_path <- write_csv(topology_audit, paste0(config_stub, "_topology_audit.csv"))

# Resolve only actually executed historical MCMC profiles. Unexecuted catalog rows
# are deliberately not treated as prior experiments.
history_index_path <- resolve_path(paste0(config_stub, "_executed_mcmc_profile_index.csv"))
history_index <- utils::read.csv(history_index_path, check.names = FALSE, stringsAsFactors = FALSE)
profile_catalogs <- list.files(file.path(repo_root, "config", "validation"), pattern = "profiles[.]csv$", full.names = TRUE)
profile_catalogs <- profile_catalogs[basename(profile_catalogs) != basename(profiles_path)]
signature_cols <- c(
  "screening_profile_id", "D", "n_each", "n_tilde_each", "m", "alpha", "rho",
  "pi_w", "pi_in", "washout", "add_bias", "seed", "readout_y_lags",
  "reservoir_lags", "rhs_tau0"
)
history_rows <- list()
for (catalog in profile_catalogs) {
  x <- tryCatch(utils::read.csv(catalog, check.names = FALSE, stringsAsFactors = FALSE), error = function(e) NULL)
  if (is.null(x) || !"screening_profile_id" %in% names(x)) next
  x <- x[x$screening_profile_id %in% history_index$screening_profile_id, , drop = FALSE]
  if (!nrow(x)) next
  for (nm in setdiff(signature_cols, names(x))) x[[nm]] <- NA
  x <- x[, signature_cols, drop = FALSE]
  x$profile_catalog_path <- normalizePath(catalog, winslash = "/", mustWork = TRUE)
  history_rows[[length(history_rows) + 1L]] <- x
}
history_profiles <- if (length(history_rows)) do.call(rbind, history_rows) else data.frame(stringsAsFactors = FALSE)
history_resolved <- merge(history_index, history_profiles, by = "screening_profile_id", all.x = TRUE, sort = FALSE)
history_resolution_path <- write_csv(history_resolved, paste0(config_stub, "_executed_profile_resolution_audit.csv"))
unresolved_history <- history_index[!history_index$screening_profile_id %in% history_profiles$screening_profile_id, , drop = FALSE]
unresolved_history_path <- write_csv(unresolved_history, paste0(config_stub, "_executed_profile_unresolved.csv"))

signature <- function(x, family_col, tau_col, likelihood_col) {
  numeric_cols <- c(
    "D", "n_each", "n_tilde_each", "m", "alpha", "rho", "pi_w", "pi_in",
    "washout", "seed", "readout_y_lags", "reservoir_lags", "rhs_tau0"
  )
  parts <- lapply(numeric_cols, function(nm) sprintf("%.12g", suppressWarnings(as.numeric(x[[nm]]))))
  parts <- c(
    list(as.character(x[[family_col]]), tau_key(x[[tau_col]]), as.character(x[[likelihood_col]])),
    parts,
    list(tolower(as.character(x$add_bias)))
  )
  do.call(paste, c(parts, sep = "\r"))
}
history_complete <- history_resolved[stats::complete.cases(history_resolved[, c("D", "n_each", "m", "alpha", "rho", "pi_w", "pi_in", "seed")]), , drop = FALSE]
history_signatures <- if (nrow(history_complete)) signature(history_complete, "family", "tau", "likelihood_target") else character()
candidate_signatures <- signature(plan$profiles, "target_family", "target_tau", "likelihood_target")
overlap <- plan$profiles[candidate_signatures %in% history_signatures, c(
  "screening_profile_id", "candidate_id", "target_cell_id", "reservoir_replicate",
  "alpha", "rho", "pi_w", "pi_in", "seed"
), drop = FALSE]
history_overlap_path <- write_csv(overlap, paste0(config_stub, "_executed_profile_overlap_audit.csv"))
if (nrow(overlap)) {
  stop(sprintf("The v2 design repeats %d executed historical profiles; see %s.", nrow(overlap), history_overlap_path), call. = FALSE)
}

base_defaults_path <- resolve_path(get_arg("--base-defaults", paste0(v1_config_stub, "_mechanism_defaults.yaml")))
defaults <- yaml::read_yaml(base_defaults_path)
defaults$campaign <- list(
  name = stage_stub,
  results_root = file.path("results", "qdesn_mcmc_validation", stage_stub),
  reports_root = file.path("reports", "qdesn_mcmc_validation", stage_stub)
)
defaults$execution$methods <- "mcmc"
defaults$execution$likelihood_families <- as.list(c("al", "exal"))
defaults$execution$allowed_fit_spec_ids <- NULL
defaults$execution$seed_policy <- list(mode = "shared", base_seed = 42000L)
defaults$source_materialization$dynamic_root <- v1_dynamic_root
defaults$source_materialization$staged_root <- v1_staged_root
defaults$source_materialization$scenarios <- as.list(scenario_ids)
defaults$source_materialization$families <- as.list(sort(unique(plan$assignments$family)))
defaults$source_materialization$taus <- as.list(sort(unique(plan$assignments$tau)))
defaults$reference$dynamic_root <- v1_dynamic_root
defaults$reference_contract$scenarios <- as.list(scenario_ids)
defaults$reference_contract$families <- as.list(sort(unique(plan$assignments$family)))
defaults$reference_contract$taus <- as.list(sort(unique(plan$assignments$tau)))
defaults$reference_contract$expected_unique_dataset_cells <- 18L
defaults$reference_contract$expected_qdesn_roots <- nrow(plan$profiles) * 18L
defaults$reference_contract$expected_selected_qdesn_roots <- 540L
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
  design = "Topology-informed per-cell alpha-only or alpha/rho coarse search with adaptive second-reservoir confirmation.",
  execution_grid_policy = "cell_specific_subset_grid",
  canonical_profile_count = nrow(plan$profiles),
  canonical_dataset_cell_count = 18L,
  canonical_qdesn_root_count = nrow(plan$profiles) * 18L,
  selected_assignment_root_count = 540L
)
defaults$study_contract$id <- paste0(stage_stub, "_2026_08_01")
defaults$study_contract$description <- paste(
  "Independent Q-DESN/exQ-DESN RHS topology-informed alpha/rho MCMC screen.",
  "The coarse phase uses one reservoir seed and three development trajectories;",
  "at most four objective-specific candidates per cell advance to a second reservoir seed."
)
defaults$study_contract$screening_policy <- list(
  unit = "likelihood_family_tau_cell_by_source_and_reservoir_replicate",
  target_cells = 5L,
  candidate_designs = 90L,
  coarse_source_replicates = 3L,
  coarse_reservoir_replicates = 1L,
  coarse_expected_specs = 270L,
  refinement_max_candidates_per_cell = 4L,
  refinement_max_specs = 60L,
  comparison_policy = "paired_to_frozen_v1_parent_exact_with_status_retained",
  selection_policy = "per_cell_objective_specific_no_global_winner",
  article_policy = "no_article_update_without_full_budget_frozen_source_confirmation"
)
defaults$study_contract$alpha_rho_cellwise_v2 <- list(
  predecessor_run_id = "qdesn_alpha_rho_topology_v1_20260731_190255",
  predecessor_decision = "STOP_NO_MECHANISM_SIGNAL",
  frozen_source_registry_path = v1_source_registry,
  frozen_source_registry_sha256 = observed_source_hash,
  frozen_baseline_metrics_path = v1_baseline_metrics,
  frozen_baseline_metrics_sha256 = unname(tools::sha256sum(v1_baseline_metrics)),
  search_map_path = search_map_path,
  historical_execution_index_path = history_index_path,
  exact_executed_profile_overlap_count = nrow(overlap),
  alpha_only_rule = "rho is held at the parent value whenever recurrence is inert or rho is not identifiable consistently across reservoir seeds",
  alpha_rho_rule = "two-dimensional search is used only when the realized recurrent matrix is active"
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
  "target_family", "target_tau", "parent_profile_id", "candidate_id", "search_id",
  "search_dimension", "search_priority", "topology_mode", "point_index",
  "reservoir_replicate", "launch_phase"
), drop = FALSE]
grid_key <- paste(canonical_grid$screening_profile_id, canonical_grid$source_family, tau_key(canonical_grid$tau), sep = "\r")
target_key <- paste(profile_lookup$screening_profile_id, profile_lookup$target_family, tau_key(profile_lookup$target_tau), sep = "\r")
selected_grid <- canonical_grid[grid_key %in% target_key, , drop = FALSE]
selected_grid <- merge(selected_grid, profile_lookup, by = "screening_profile_id", all.x = TRUE, sort = FALSE)
selected_grid <- selected_grid[order(
  selected_grid$launch_phase, selected_grid$target_cell_id, selected_grid$candidate_id,
  selected_grid$reservoir_replicate, selected_grid$source_scenario
), , drop = FALSE]
if (nrow(selected_grid) != 540L || anyNA(selected_grid$likelihood_target)) {
  stop(sprintf("Expected 540 selected roots; found %d.", nrow(selected_grid)), call. = FALSE)
}
grid_path <- write_csv(selected_grid, paste0(config_stub, "_grid.csv"))
coarse_grid <- selected_grid[selected_grid$launch_phase == "coarse", , drop = FALSE]
refinement_grid <- selected_grid[selected_grid$launch_phase == "refinement_universe", , drop = FALSE]
coarse_grid_path <- write_csv(coarse_grid, paste0(config_stub, "_coarse_grid.csv"))
refinement_grid_path <- write_csv(refinement_grid, paste0(config_stub, "_refinement_universe_grid.csv"))

atomic <- exdqlm:::qdesn_dynamic_fitforecast_atomic_spec_grid(
  selected_grid,
  defaults = defaults_loaded,
  methods = "mcmc",
  likelihood_families = c("al", "exal")
)
atomic <- merge(
  atomic,
  profile_lookup[, c(
    "screening_profile_id", "likelihood_target", "target_cell_id", "candidate_id",
    "search_id", "search_dimension", "topology_mode", "reservoir_replicate", "launch_phase"
  ), drop = FALSE],
  by = "screening_profile_id", all.x = TRUE, sort = FALSE
)
target_specs <- atomic[atomic$likelihood_family == atomic$likelihood_target, , drop = FALSE]
target_specs <- target_specs[order(target_specs$launch_phase, target_specs$target_cell_id, target_specs$candidate_id, target_specs$root_id), , drop = FALSE]
if (nrow(target_specs) != 540L || anyDuplicated(target_specs$spec_id)) {
  stop(sprintf("Expected 540 unique target specs; found %d.", nrow(target_specs)), call. = FALSE)
}
target_specs_path <- write_csv(target_specs, paste0(config_stub, "_target_spec_ids.csv"))
coarse_specs <- target_specs[target_specs$launch_phase == "coarse", , drop = FALSE]
refinement_specs <- target_specs[target_specs$launch_phase == "refinement_universe", , drop = FALSE]
coarse_specs_path <- write_csv(coarse_specs, paste0(config_stub, "_coarse_target_spec_ids.csv"))
refinement_specs_path <- write_csv(refinement_specs, paste0(config_stub, "_refinement_universe_target_spec_ids.csv"))
if (nrow(coarse_specs) != 270L || nrow(refinement_specs) != 270L) {
  stop(sprintf("Phase counts are wrong: coarse=%d refinement_universe=%d.", nrow(coarse_specs), nrow(refinement_specs)), call. = FALSE)
}

write_phase_defaults <- function(phase, phase_specs, phase_profiles, phase_grid) {
  phase_defaults <- defaults
  phase_defaults$campaign$name <- paste(stage_stub, phase, sep = "_")
  phase_defaults$campaign$results_root <- file.path("results", "qdesn_mcmc_validation", paste(stage_stub, phase, sep = "_"))
  phase_defaults$campaign$reports_root <- file.path("reports", "qdesn_mcmc_validation", paste(stage_stub, phase, sep = "_"))
  phase_defaults$execution$allowed_fit_spec_ids <- as.list(as.character(phase_specs$spec_id))
  phase_defaults$reference_contract$expected_selected_qdesn_roots <- nrow(phase_grid)
  phase_defaults$screening_profiles$selected_assignment_root_count <- nrow(phase_grid)
  phase_defaults$study_contract$id <- paste(stage_stub, phase, "2026_08_01", sep = "_")
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
      n_burn = 4L, n_mcmc = 4L, thin = 1L,
      progress_every = 1L, init_from_vb = TRUE
    )))
  )
  out <- paste0(config_stub, "_", phase, "_defaults.yaml")
  yaml::write_yaml(phase_defaults, resolve_path(out, FALSE))
  resolve_path(out)
}
coarse_defaults_path <- write_phase_defaults(
  "coarse", coarse_specs,
  plan$profiles[plan$profiles$launch_phase == "coarse", , drop = FALSE],
  coarse_grid
)
refinement_universe_defaults_path <- write_phase_defaults(
  "refinement_universe", refinement_specs,
  plan$profiles[plan$profiles$launch_phase == "refinement_universe", , drop = FALSE],
  refinement_grid
)

source_window_audit <- exdqlm:::qdesn_dynamic_fitforecast_verify_source_windows(
  file.path(v1_staged_root, "materialized_source_inventory.csv"),
  expected_train_end = 9000L,
  expected_forecast_end = 10000L,
  stop_on_fail = TRUE
)
evidence_root <- file.path("reports", "qdesn_mcmc_validation", stage_stub, "materialization")
source_window_audit_path <- write_csv(source_window_audit, file.path(evidence_root, "source_window_audit.csv"))

manifest <- list(
  generated_at = as.character(Sys.time()),
  stage_stub = stage_stub,
  package_version = as.character(description[1L, "Version"]),
  git_branch = trimws(system("git branch --show-current", intern = TRUE)),
  git_commit = trimws(system("git rev-parse HEAD", intern = TRUE)),
  predecessor = list(
    worktree = v1_worktree,
    manifest_path = v1_manifest,
    manifest_sha256 = unname(tools::sha256sum(v1_manifest)),
    baseline_metrics_path = v1_baseline_metrics,
    baseline_metrics_sha256 = unname(tools::sha256sum(v1_baseline_metrics)),
    decision = "STOP_NO_MECHANISM_SIGNAL"
  ),
  source_registry_path = v1_source_registry,
  source_registry_sha256 = observed_source_hash,
  source_slice_registry_path = v1_source_slice_registry,
  source_window_audit_path = source_window_audit_path,
  profiles_path = profiles_path,
  profiles_sha256 = sha256(profiles_path),
  assignments_path = assignments_path,
  candidate_design_path = designs_path,
  search_map_path = search_map_path,
  parent_profiles_path = parents_path,
  topology_audit_path = topology_audit_path,
  topology_audit_sha256 = sha256(topology_audit_path),
  history = list(
    executed_profile_index_path = history_index_path,
    executed_profile_index_sha256 = sha256(history_index_path),
    resolution_audit_path = history_resolution_path,
    unresolved_profile_path = unresolved_history_path,
    unresolved_profile_count = nrow(unresolved_history),
    overlap_audit_path = history_overlap_path,
    exact_overlap_count = nrow(overlap)
  ),
  full_defaults_path = defaults_path,
  full_grid_path = grid_path,
  target_specs_path = target_specs_path,
  coarse = list(
    defaults_path = coarse_defaults_path,
    grid_path = coarse_grid_path,
    target_specs_path = coarse_specs_path,
    candidate_designs = 90L,
    expected_specs = nrow(coarse_specs)
  ),
  refinement_universe = list(
    defaults_path = refinement_universe_defaults_path,
    grid_path = refinement_grid_path,
    target_specs_path = refinement_specs_path,
    candidate_designs = 90L,
    maximum_selected_candidates = 20L,
    maximum_expected_specs = 60L
  ),
  counts = list(
    target_cells = 5L,
    search_paths = nrow(plan$search_map),
    candidate_designs = nrow(plan$designs),
    profiles = nrow(plan$profiles),
    coarse_specs = nrow(coarse_specs),
    refinement_universe_specs = nrow(refinement_specs)
  ),
  launch_state = "materialized_not_launched"
)
manifest_path <- write_json(manifest, paste0(config_stub, "_materialization_manifest.json"))

cat(sprintf("Materialization manifest: %s\n", manifest_path))
cat(sprintf("Frozen source registry: %s (sha256=%s)\n", v1_source_registry, observed_source_hash))
cat(sprintf("Candidate designs: %d\n", nrow(plan$designs)))
cat(sprintf("Coarse specs: %d\n", nrow(coarse_specs)))
cat(sprintf("Refinement universe: %d specs; dynamic cap: 60\n", nrow(refinement_specs)))
cat(sprintf("Executed-profile overlaps: %d\n", nrow(overlap)))

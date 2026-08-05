#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  required <- c("digest", "jsonlite", "pkgload", "yaml")
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
`%||%` <- function(x, y) if (is.null(x) || !length(x)) y else x

repo_root <- normalizePath(
  system("git rev-parse --show-toplevel", intern = TRUE),
  winslash = "/",
  mustWork = TRUE
)
setwd(repo_root)
pkgload::load_all(repo_root, quiet = TRUE)
source(file.path(
  repo_root,
  "validation", "fitforecast_v2", "R", "qdesn_train_only_rebaseline_v1.R"
))

resolve_path <- function(path, must_work = TRUE) {
  path <- as.character(path)[1L]
  if (!grepl("^/", path)) path <- file.path(repo_root, path)
  normalizePath(path, winslash = "/", mustWork = isTRUE(must_work))
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
as_bool <- function(x) {
  if (is.logical(x)) return(x)
  toupper(trimws(as.character(x))) %in% c("TRUE", "T", "YES", "Y", "1")
}
tau_key <- function(x) sprintf("%.8f", as.numeric(x))

description <- read.dcf(file.path(repo_root, "DESCRIPTION"))
if (!identical(as.character(description[1L, "Package"]), "exdqlm") ||
    !identical(as.character(description[1L, "Version"]), "1.0.0")) {
  stop("Train-only rebaseline requires exdqlm 1.0.0.", call. = FALSE)
}

stage <- "qdesn_dynamic_fitforecast_v2_500obs_trainonly_rebaseline_v1"
stub <- file.path("config", "validation", stage)
expected_registry_hash <- "edddb56fc2b30e49ac99fdd08b53dad468ed53e05d0fe1fe16426ee9d9ffe275"
expected_scenario <- "dlm_constV_p90_m0amp_highnoise_steepertrend_v2_TTmain10000_fitforecast"
workers <- suppressWarnings(as.integer(get_arg("--workers", "16")))
if (!is.finite(workers) || workers < 1L || workers > 24L) {
  stop("`--workers` must be between 1 and 24.", call. = FALSE)
}

shared_root <- normalizePath(
  get_arg("--shared-root", "/data/jaguir26/local/src/exdqlm__wt__shared_fitforecast_v2_1p0p0"),
  winslash = "/",
  mustWork = TRUE
)
alpha_root <- normalizePath(
  get_arg("--alpha-root", "/data/jaguir26/local/src/exdqlm__wt__qdesn_alpha_rho_cellwise_v2_1p0p0"),
  winslash = "/",
  mustWork = TRUE
)
search_roots <- c(shared_root, alpha_root)

article_envelope_path <- file.path(
  shared_root,
  "validation", "fitforecast_v2", "promotions",
  "qdesn_dqlm_500obs_mcmc_metric_envelope_20260804",
  "qdesn_dqlm_500obs_mcmc_metric_envelope_20260804_article_envelope.csv"
)
canonical_registry_path <- file.path(
  shared_root,
  "validation", "fitforecast_v2", "runs",
  "20260704_exdqlm_dqlm_c13_mcmc_500obs_refresh_v2",
  "manifests", "source_registry.csv"
)
staged_source_root <- file.path(
  shared_root,
  "results", "qdesn_mcmc_validation",
  "dynamic_fitforecast_v2_qdesn_sources_period90_m90_w300"
)
staged_inventory_path <- file.path(staged_source_root, "materialized_source_inventory.csv")
base_defaults_path <- file.path(
  "config", "validation",
  "qdesn_dynamic_fitforecast_v2_tt500_mcmc_external_coherent_confirmation_v1_defaults.yaml"
)
for (path in c(
  article_envelope_path,
  canonical_registry_path,
  staged_inventory_path,
  resolve_path(base_defaults_path)
)) {
  if (!file.exists(path)) stop(sprintf("Required input is missing: %s", path), call. = FALSE)
}

article_envelope <- utils::read.csv(article_envelope_path, check.names = FALSE, stringsAsFactors = FALSE)
if (any(as.character(article_envelope$source_registry_hash_value) != expected_registry_hash)) {
  stop("Article envelope source-registry identity is not frozen v2.", call. = FALSE)
}
metric_contract <- qdesn_tor1_metric_contract(article_envelope)
candidate_contract <- metric_contract[!duplicated(metric_contract$candidate_key), c(
  "candidate_key", "model_variant", "family", "tau", "fit_size",
  "likelihood_target", "legacy_candidate_id", "legacy_run_tag",
  "source_registry_hash_value"
), drop = FALSE]
candidate_contract <- candidate_contract[order(
  candidate_contract$model_variant,
  candidate_contract$family,
  candidate_contract$tau,
  candidate_contract$legacy_candidate_id
), , drop = FALSE]
rownames(candidate_contract) <- NULL
candidate_count <- nrow(candidate_contract)
if (candidate_count < 18L || candidate_count > nrow(metric_contract)) {
  stop(sprintf(
    "Distinct metric-source design count is outside [18, 54]: %d.",
    candidate_count
  ), call. = FALSE)
}

profiles <- qdesn_tor1_extract_candidate_profiles(
  candidate_contract,
  search_roots = search_roots,
  expected_registry_hash = expected_registry_hash
)
profile_index <- match(metric_contract$candidate_key, profiles$candidate_key)
if (anyNA(profile_index)) stop("Metric/profile contract join failed.", call. = FALSE)
metric_contract$screening_profile_id <- profiles$screening_profile_id[profile_index]

profile_columns <- c(
  "screening_profile_id", "screening_stage", "screening_wave", "profile_role",
  "enabled", "D", "n_each", "n_tilde_each", "m", "alpha", "rho", "pi_w",
  "pi_in", "washout", "add_bias", "seed", "readout_y_lags", "reservoir_lags",
  "rhs_tau0", "dimension_p_estimate", "p_over_n_tt500", "x_feature_count",
  "target_cells", "model_variant", "target_family", "target_tau",
  "likelihood_target", "legacy_candidate_id", "legacy_run_tag",
  "legacy_profile_id", "source_fit_request_path", "source_fit_request_sha256",
  "source_effective_desn_seed", "source_root_seed", "source_mcmc_seed",
  "source_mcmc_rng_seed", "source_vb_warm_start_seed", "source_synthesis_seed",
  "source_registry_hash_value", "candidate_key"
)
profiles_path <- write_csv(profiles[, profile_columns, drop = FALSE], paste0(stub, "_profiles.csv"))
metric_contract_path <- write_csv(metric_contract, paste0(stub, "_legacy_metric_contract.csv"))
candidate_contract_path <- write_csv(profiles, paste0(stub, "_candidate_contract.csv"))

assignments <- data.frame(
  assignment_key = profiles$candidate_key,
  assignment_id = sprintf("tor1_%03d", seq_len(nrow(profiles))),
  family = profiles$target_family,
  tau = profiles$target_tau,
  likelihood_target = profiles$likelihood_target,
  cell_status = "current_metric_source_design_rebaseline",
  priority_rank = ave(seq_len(nrow(profiles)), paste(
    profiles$model_variant, profiles$target_family, tau_key(profiles$target_tau)
  ), FUN = seq_along),
  target_profile_rank = ave(seq_len(nrow(profiles)), paste(
    profiles$model_variant, profiles$target_family, tau_key(profiles$target_tau)
  ), FUN = seq_along),
  screening_profile_id = profiles$screening_profile_id,
  source_profile = profiles$legacy_profile_id,
  candidate_source = "authoritative_20260804_metric_envelope",
  selection_reason = "distinct_design_supplies_at_least_one_current_article_metric",
  source_path = profiles$source_fit_request_path,
  root_id = NA_character_,
  stringsAsFactors = FALSE
)
assignments_path <- write_csv(assignments, paste0(stub, "_cell_assignments.csv"))

canonical_registry <- utils::read.csv(canonical_registry_path, check.names = FALSE, stringsAsFactors = FALSE)
registry <- canonical_registry[
  canonical_registry$scenario_id == expected_scenario &
    canonical_registry$fit_size == 500L &
    canonical_registry$family %in% c("gausmix", "laplace", "normal") &
    as.numeric(canonical_registry$tau) %in% c(0.05, 0.25, 0.50),
  , drop = FALSE
]
if (nrow(registry) != 9L || any(!as_bool(registry$source_present)) ||
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
  stop("Canonical source-registry rows violate the rebaseline protocol.", call. = FALSE)
}

source_roles <- c("series_wide", "true_quantile_grid", "sim_output", "meta")
source_file_audit <- do.call(rbind, lapply(seq_len(nrow(registry)), function(i) {
  do.call(rbind, lapply(source_roles, function(role) {
    path <- as.character(registry[[paste0(role, "_path")]][[i]])
    expected <- as.character(registry[[paste0(role, "_sha256")]][[i]])
    data.frame(
      source_cell_id = registry$source_cell_id[[i]],
      role = role,
      path = path,
      expected_sha256 = expected,
      file_exists = file.exists(path),
      observed_sha256 = if (file.exists(path)) unname(tools::sha256sum(path)) else NA_character_,
      stringsAsFactors = FALSE
    )
  }))
}))
source_file_audit$hash_match <- with(
  source_file_audit,
  file_exists & expected_sha256 == observed_sha256
)
if (!all(source_file_audit$hash_match)) {
  stop("One or more frozen source files fail SHA-256 verification.", call. = FALSE)
}
source_registry_path <- write_csv(registry, paste0(stub, "_source_registry.csv"))
source_file_audit_path <- write_csv(source_file_audit, paste0(stub, "_source_file_hash_audit.csv"))

defaults <- yaml::read_yaml(resolve_path(base_defaults_path))
defaults$campaign <- list(
  name = stage,
  results_root = file.path("results", "qdesn_mcmc_validation", stage),
  reports_root = file.path("reports", "qdesn_mcmc_validation", stage)
)
defaults$execution$methods <- "mcmc"
defaults$execution$likelihood_families <- c("al", "exal")
defaults$execution$allowed_fit_spec_ids <- NULL
defaults$execution$seed_policy <- list(mode = "shared", base_seed = 810000L)
defaults$runtime$threads <- 1L
defaults$runtime$campaign_workers <- workers
defaults$runtime$workers <- workers
defaults$runtime$root_scheduler <- "load_balanced"
defaults$source_materialization$staged_root <- staged_source_root
defaults$source_materialization$families <- c("gausmix", "laplace", "normal")
defaults$source_materialization$taus <- c(0.05, 0.25, 0.50)
defaults$reference_contract$expected_unique_dataset_cells <- 9L
defaults$reference_contract$expected_qdesn_roots <- candidate_count * 9L
defaults$reference_contract$expected_selected_qdesn_roots <- candidate_count
defaults$reference_contract$expected_priors <- "rhs_ns"
defaults$screening_profiles <- list(
  enabled = TRUE,
  csv = sub(paste0("^", repo_root, "/?"), "", profiles_path),
  cell_assignments_csv = sub(paste0("^", repo_root, "/?"), "", assignments_path),
  priors = "rhs_ns",
  design = paste(
    sprintf("%d distinct current metric-source designs, each re-estimated under", candidate_count),
    "training-only preprocessing with a fresh deterministic sampler seed bundle."
  ),
  execution_grid_policy = "exact_current_metric_source_design_subset",
  canonical_profile_count = candidate_count,
  canonical_dataset_cell_count = 9L,
  canonical_qdesn_root_count = candidate_count * 9L,
  selected_assignment_root_count = candidate_count,
  dimension_gate = list(primary_p_over_n_max = 1.0, exploratory_p_over_n_max = 1.0)
)
defaults$multiseed <- list(
  enabled = FALSE,
  mcmc_seed_reps = 1L,
  parallel_seed_workers = 1L,
  selection_metric = "corrected_protocol_metric_envelope",
  prune_nonwinning_heavy_outputs = TRUE
)
defaults$preproc <- list(scale_y = TRUE, scale_x = TRUE, fit_scope = "train_only")
defaults$pipeline$outputs$keep_draws <- FALSE
defaults$pipeline$outputs$keep_mcmc_vb_init <- FALSE
defaults$pipeline$outputs$save_forecast_objects <- FALSE
defaults$pipeline$outputs$save_compact_fit_paths <- TRUE
defaults$pipeline$outputs$save_metric_summaries <- TRUE
defaults$pipeline$outputs$retain_full_rds_on_failure <- FALSE
defaults$pipeline$outputs$retention_profile <- "storage_light_trainonly_rebaseline"
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
defaults$paths$rewrite_home_local_src_to_repo_root <- FALSE
defaults$study_contract <- list(
  core_lane = TRUE,
  id = paste0(stage, "_2026_08_04"),
  description = paste(
    "Corrected-protocol MCMC rebaseline of every distinct Q-DESN design supplying",
    "the 2026-08-04 article metric envelope. Preprocessing is fitted only on rows",
    "available through the forecast origin; held-out responses and covariates are excluded."
  ),
  package_version = "1.0.0",
  source_registry_identity_field = "source_registry_hash_value",
  source_registry_hash_value = expected_registry_hash,
  source_registry_path = source_registry_path,
  source_registry_sha256 = sha256(source_registry_path),
  preprocessing = list(
    scope = "train_only",
    analysis_input_rows = c(1L, 1890L),
    preprocessing_fit_rows = c(1L, 890L),
    preprocessing_fit_row_indices_sha256 = digest::digest(1:890, algo = "sha256"),
    corresponding_source_rows = c(8111L, 9000L),
    effective_target_fit_window = c(8501L, 9000L),
    forecast_block = c(9001L, 10000L),
    heldout_response_used_for_scaling = FALSE,
    heldout_covariates_used_for_scaling = FALSE
  ),
  budget = list(
    posterior_metric_draws = 200L,
    mcmc_n_burn = 5000L,
    mcmc_n_mcmc = 20000L,
    mcmc_thin = 1L
  ),
  selection_policy = list(
    unit = "distinct_current_metric_source_design",
    legacy_metric_source_rows = 54L,
    distinct_designs = candidate_count,
    article_update_automatic = FALSE,
    legacy_qdesn_metrics_valid_after_repair = FALSE,
    corrected_complete_rebaseline_required = TRUE
  )
)

defaults_path <- resolve_path(paste0(stub, "_defaults.yaml"), FALSE)
yaml::write_yaml(defaults, defaults_path)
loaded <- exdqlm:::qdesn_dynamic_crossstudy_load_defaults(defaults_path)
canonical_grid <- exdqlm:::qdesn_dynamic_crossstudy_build_grid(
  loaded,
  refresh_materialized = FALSE,
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
  profiles$screening_profile_id,
  profiles$target_family,
  tau_key(profiles$target_tau),
  sep = "\r"
)
grid <- canonical_grid[grid_key %in% target_key & canonical_grid$source_scenario == expected_scenario, , drop = FALSE]
grid <- qdesn_tor1_assign_fresh_seeds(grid, profiles)
grid <- grid[grid$likelihood_target == ifelse(grid$model_variant == "qdesn_al_rhs_ns", "al", "exal"), , drop = FALSE]
grid <- grid[order(grid$model_variant, grid$source_family, grid$tau, grid$screening_profile_id), , drop = FALSE]
if (nrow(grid) != candidate_count || anyDuplicated(grid$root_id) || anyNA(grid$legacy_candidate_id) ||
    any(as.integer(grid$train_start_source_index) != 8501L) ||
    any(as.integer(grid$train_end_source_index) != 9000L) ||
    any(as.integer(grid$forecast_start_source_index) != 9001L) ||
    any(as.integer(grid$forecast_end_source_index) != 10000L)) {
  stop(sprintf(
    "Expected %d exact corrected-protocol roots; found %d.",
    candidate_count,
    nrow(grid)
  ), call. = FALSE)
}

staged_roles <- c("source_series_wide", "source_selection_indices", "source_sim")
staged_audit <- do.call(rbind, lapply(seq_len(nrow(grid)), function(i) {
  do.call(rbind, lapply(staged_roles, function(role) {
    path <- as.character(grid[[paste0(role, "_path")]][[i]])
    expected <- as.character(grid[[paste0(role, "_sha256")]][[i]])
    data.frame(
      root_id = grid$root_id[[i]],
      role = role,
      path = path,
      expected_sha256 = expected,
      file_exists = file.exists(path),
      observed_sha256 = if (file.exists(path)) unname(tools::sha256sum(path)) else NA_character_,
      stringsAsFactors = FALSE
    )
  }))
}))
staged_audit$hash_match <- with(staged_audit, file_exists & expected_sha256 == observed_sha256)
if (!all(staged_audit$hash_match)) {
  stop("One or more staged source files fail SHA-256 verification.", call. = FALSE)
}

assignments$root_id <- grid$root_id[match(assignments$screening_profile_id, grid$screening_profile_id)]
assignments_path <- write_csv(assignments, paste0(stub, "_cell_assignments.csv"))
grid_path <- write_csv(grid, paste0(stub, "_grid.csv"))
staged_audit_path <- write_csv(staged_audit, paste0(stub, "_staged_source_hash_audit.csv"))

atomic <- exdqlm:::qdesn_dynamic_fitforecast_atomic_spec_grid(
  grid,
  defaults = loaded,
  methods = "mcmc",
  likelihood_families = c("al", "exal")
)
atomic_index <- match(atomic$root_id, grid$root_id)
for (field in c(
  "legacy_candidate_id", "legacy_run_tag", "model_variant", "likelihood_target",
  "source_fit_request_path", "source_fit_request_sha256", "desn_seed", "mcmc_seed",
  "mcmc_rng_seed", "vb_warm_start_seed", "synthesis_seed",
  "source_registry_hash_value"
)) {
  atomic[[field]] <- grid[[field]][atomic_index]
}
target_specs <- atomic[atomic$likelihood_family == atomic$likelihood_target, , drop = FALSE]
target_specs <- target_specs[order(
  target_specs$model_variant,
  target_specs$family,
  target_specs$tau,
  target_specs$screening_profile_id
), , drop = FALSE]
if (nrow(target_specs) != candidate_count || anyDuplicated(target_specs$spec_id)) {
  stop(sprintf(
    "Expected %d unique MCMC target specs; found %d.",
    candidate_count,
    nrow(target_specs)
  ), call. = FALSE)
}
target_specs_path <- write_csv(target_specs, paste0(stub, "_target_spec_ids.csv"))
defaults$execution$allowed_fit_spec_ids <- as.list(as.character(target_specs$spec_id))
yaml::write_yaml(defaults, defaults_path)

smoke_profile_ids <- unlist(lapply(c("al", "exal"), function(likelihood) {
  subset <- profiles[profiles$likelihood_target == likelihood, , drop = FALSE]
  subset$screening_profile_id[[which.max(subset$dimension_p_estimate)]]
}), use.names = FALSE)
smoke_grid <- grid[grid$screening_profile_id %in% smoke_profile_ids, , drop = FALSE]
smoke_specs <- target_specs[target_specs$screening_profile_id %in% smoke_profile_ids, , drop = FALSE]
if (nrow(smoke_grid) != 2L || nrow(smoke_specs) != 2L ||
    !setequal(smoke_specs$likelihood_family, c("al", "exal"))) {
  stop("Smoke contract must contain one AL and one exAL corrected-protocol root.", call. = FALSE)
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
smoke_defaults$runtime$campaign_workers <- 2L
smoke_defaults$runtime$workers <- 2L
smoke_defaults$reference_contract$expected_selected_qdesn_roots <- 2L
smoke_defaults$screening_profiles$selected_assignment_root_count <- 2L
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
  mcmc_n_burn = 4L,
  mcmc_n_mcmc = 4L,
  mcmc_thin = 1L
)
smoke_defaults$study_contract$selection_policy$stage <- "executable_smoke"
smoke_defaults_path <- resolve_path(paste0(stub, "_smoke_defaults.yaml"), FALSE)
yaml::write_yaml(smoke_defaults, smoke_defaults_path)
smoke_grid_path <- write_csv(smoke_grid, paste0(stub, "_smoke_grid.csv"))
smoke_specs_path <- write_csv(smoke_specs, paste0(stub, "_smoke_target_spec_ids.csv"))

request_audit <- profiles[, c(
  "screening_profile_id", "legacy_candidate_id", "legacy_run_tag",
  "source_fit_request_path", "source_fit_request_sha256"
), drop = FALSE]
request_audit$file_exists <- file.exists(request_audit$source_fit_request_path)
request_audit$observed_sha256 <- vapply(
  request_audit$source_fit_request_path,
  function(path) if (file.exists(path)) unname(tools::sha256sum(path)) else NA_character_,
  character(1L)
)
request_audit$hash_match <- with(
  request_audit,
  file_exists & source_fit_request_sha256 == observed_sha256
)
if (!all(request_audit$hash_match)) stop("Source fit-request audit failed.", call. = FALSE)
request_audit_path <- write_csv(request_audit, paste0(stub, "_source_fit_request_audit.csv"))

generated_files <- c(
  profiles = profiles_path,
  assignments = assignments_path,
  legacy_metric_contract = metric_contract_path,
  candidate_contract = candidate_contract_path,
  defaults = defaults_path,
  grid = grid_path,
  target_specs = target_specs_path,
  smoke_defaults = smoke_defaults_path,
  smoke_grid = smoke_grid_path,
  smoke_specs = smoke_specs_path,
  source_registry = source_registry_path,
  source_file_audit = source_file_audit_path,
  staged_source_audit = staged_audit_path,
  source_fit_request_audit = request_audit_path
)
generated_manifest <- data.frame(
  role = names(generated_files),
  path = unname(generated_files),
  sha256 = vapply(generated_files, sha256, character(1L)),
  stringsAsFactors = FALSE
)
generated_manifest_path <- write_csv(generated_manifest, paste0(stub, "_generated_file_manifest.csv"))
manifest <- list(
  generated_at = as.character(Sys.time()),
  stage = stage,
  package_version = as.character(description[1L, "Version"]),
  git_branch = trimws(system("git branch --show-current", intern = TRUE)),
  git_commit = trimws(system("git rev-parse HEAD", intern = TRUE)),
  source_registry_identity_field = "source_registry_hash_value",
  source_registry_hash_value = expected_registry_hash,
  canonical_registry_path = canonical_registry_path,
  canonical_registry_file_sha256 = unname(tools::sha256sum(canonical_registry_path)),
  source_files_verified = all(source_file_audit$hash_match),
  staged_source_files_verified = all(staged_audit$hash_match),
  source_fit_requests_verified = all(request_audit$hash_match),
  preprocessing = defaults$study_contract$preprocessing,
  counts = list(
    article_qdesn_rows = 18L,
    legacy_metric_source_rows = 54L,
    distinct_designs = candidate_count,
    full_specs = candidate_count,
    smoke_specs = 2L
  ),
  budget = defaults$study_contract$budget,
  storage_policy = list(
    retention_profile = "storage_light_trainonly_rebaseline",
    successful_binary_payloads_allowed = FALSE,
    failure_binary_payloads_allowed = FALSE
  ),
  article_update_automatic = FALSE,
  launch_status = "materialized_not_launched",
  generated_file_manifest_path = generated_manifest_path
)
manifest_path <- write_json(manifest, paste0(stub, "_materialization_manifest.json"))

cat(sprintf("Materialization manifest: %s\n", manifest_path))
cat(sprintf("Frozen registry identity: %s\n", expected_registry_hash))
cat(sprintf("Legacy metric-source rows: %d\n", nrow(metric_contract)))
cat(sprintf("Distinct corrected-protocol designs: %d\n", nrow(target_specs)))
cat(sprintf("Executable smoke specs: %d\n", nrow(smoke_specs)))

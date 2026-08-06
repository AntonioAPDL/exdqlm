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
source(file.path(repo_root, "validation", "fitforecast_v2", "R", "qdesn_trainonly_followup_v1.R"))

resolve_path <- function(path, must_work = TRUE) {
  path <- as.character(path)[1L]
  if (!grepl("^/", path)) path <- file.path(repo_root, path)
  normalizePath(path, winslash = "/", mustWork = isTRUE(must_work))
}
rel_path <- function(path) {
  p <- resolve_path(path, FALSE)
  prefix <- paste0("^", gsub("([].[^$*+?{}|()\\\\])", "\\\\\\1", repo_root), "/?")
  sub(prefix, "", p)
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

description <- read.dcf(file.path(repo_root, "DESCRIPTION"))
if (!identical(as.character(description[1L, "Version"]), "1.0.0")) {
  stop("Train-only follow-up v1 requires exdqlm 1.0.0.", call. = FALSE)
}
qdesn_tfv1_validate_plan()

stage <- qdesn_tfv1_stage()
stub <- file.path("config", "validation", stage)
source_cfg_path <- paste0(stub, "_source_replicates.yaml")
base_defaults_path <- resolve_path(get_arg(
  "--base-defaults",
  file.path("config", "validation", "qdesn_dynamic_fitforecast_v2_500obs_trainonly_rebaseline_v1_defaults.yaml")
))
mechanism_root <- resolve_path(get_arg(
  "--mechanism-root",
  "/data/jaguir26/local/src/exdqlm__wt__qdesn_trainonly_mechanism_v1_1p0p0"
))
workers <- suppressWarnings(as.integer(get_arg("--workers", "24"))[1L])
if (!is.finite(workers) || workers < 1L) workers <- 24L
workers <- min(workers, 24L)
refresh_source <- !has_flag("--no-source-refresh")

source_cfg <- yaml::read_yaml(source_cfg_path)
generation <- source_cfg$generation
replicate <- source_cfg$replicates[[1L]]
family_profiles <- generation$family_profiles
family_profiles$normal$seeds <- replicate$seeds$normal
source_manifest <- list(
  meta = list(
    study_id = source_cfg$meta$study_id,
    scenario_id = replicate$scenario_id,
    notes = "Untouched train-only confirmation source; excluded from mechanism discovery."
  ),
  generation = utils::modifyList(generation, list(family_profiles = family_profiles)),
  qdesn_materialization = list(
    staged_root = file.path("results", "qdesn_mcmc_validation", stage, "source_windows")
  )
)
generated <- exdqlm:::qdesn_dynamic_candidate_generate_bundle(
  manifest = source_manifest,
  repo_root = repo_root,
  refresh = refresh_source,
  verbose = TRUE
)
evidence_root <- file.path("reports", "qdesn_mcmc_validation", stage, "materialization")
dev04_registry_path <- write_csv(generated$root_inventory, file.path(evidence_root, "dev04_source_registry.csv"))
dev04_slice_registry_path <- write_csv(generated$slice_inventory, file.path(evidence_root, "dev04_source_slice_registry.csv"))
dev04_registry_sha <- sha256(dev04_registry_path)

profiles <- qdesn_tfv1_build_profiles()
profiles_path <- write_csv(profiles, paste0(stub, "_profiles.csv"))
bundles <- qdesn_tfv1_bundle_contract()
bundles_path <- write_csv(bundles, paste0(stub, "_bundle_contract.csv"))
sources <- qdesn_tfv1_source_contract()
sources_path <- write_csv(sources, paste0(stub, "_source_contract.csv"))

canonical_registry_path <- resolve_path(file.path(
  "config", "validation", "qdesn_dynamic_fitforecast_v2_500obs_trainonly_rebaseline_v1_source_registry.csv"
))
canonical_registry <- utils::read.csv(canonical_registry_path, check.names = FALSE, stringsAsFactors = FALSE)
article_identity <- "edddb56fc2b30e49ac99fdd08b53dad468ed53e05d0fe1fe16426ee9d9ffe275"
development_identity <- "af83f8704ca330a7d0fb7296c2cd8c4f9bf42b09c79851e2c75303de88a8b1e9"
mechanism_source_registry_path <- file.path(
  mechanism_root, "reports", "qdesn_mcmc_validation",
  "qdesn_dynamic_fitforecast_v2_500obs_trainonly_mechanism_v1", "materialization", "source_registry.csv"
)
if (!file.exists(mechanism_source_registry_path) || sha256(mechanism_source_registry_path) != development_identity) {
  stop("Completed mechanism development registry is missing or has changed.", call. = FALSE)
}

base_defaults <- yaml::read_yaml(base_defaults_path)
if (!identical(base_defaults$preproc$fit_scope, "train_only")) {
  stop("Base defaults do not implement train-only preprocessing.", call. = FALSE)
}

configure_defaults <- function(bundle, profile_path, assignment_path) {
  d <- base_defaults
  bundle_id <- as.character(bundle$bundle_id[[1L]])
  experiment <- as.character(bundle$experiment[[1L]])
  source_role <- as.character(bundle$source_role[[1L]])
  d$campaign <- list(
    name = paste(stage, bundle_id, sep = "_"),
    results_root = file.path("results", "qdesn_mcmc_validation", paste(stage, bundle_id, sep = "_")),
    reports_root = file.path("reports", "qdesn_mcmc_validation", paste(stage, bundle_id, sep = "_"))
  )
  d$execution$methods <- "mcmc"
  d$execution$likelihood_families <- as.list(as.character(bundle$likelihood_target[[1L]]))
  d$execution$allowed_fit_spec_ids <- NULL
  d$execution$seed_policy <- list(mode = "shared", base_seed = 970001L)
  d$study_contract$core_lane <- FALSE
  d$study_contract$id <- paste0(stage, "_", bundle_id, "_2026_08_05")
  d$study_contract$description <- if (experiment == "al_confirmation") {
    sprintf("Full-budget paired confirmation on the %s source; no automatic article promotion.", source_role)
  } else {
    "Short-budget exAL gamma-sigma sampler diagnostic with DESN and RHS prior frozen."
  }
  d$study_contract$source_registry_identity_field <- "row_specific_source_registry_hash_value"
  d$study_contract$source_registry_hash_value <- switch(
    source_role,
    frozen_article = article_identity,
    untouched_confirmation = dev04_registry_sha,
    development = development_identity,
    stop(sprintf("Unsupported source role: %s", source_role), call. = FALSE)
  )
  d$study_contract$package_version <- "1.0.0"
  d$study_contract$budget <- list(
    posterior_metric_draws = if (experiment == "al_confirmation") 200L else 100L,
    mcmc_n_burn = as.integer(bundle$n_burn[[1L]]),
    mcmc_n_mcmc = as.integer(bundle$n_mcmc[[1L]]),
    mcmc_thin = 1L
  )
  d$study_contract$selection_policy <- list(
    selection_unit = "cell_by_source_by_reservoir_seed",
    article_policy = "no_update_before_explicit_closeout_gate",
    status_policy = "retain_finite_metrics_and_diagnostics_without_status_masking",
    al_promotion_gate = "forecast_mae_ratio_le_0p95_on_all_and_article;fit_and_check_ratio_le_1p05;q90_le_1p10",
    exal_selection_gate = "gamma_sigma_ess_per_second_and_acf_first;metrics_second;full_budget_confirmation_required"
  )
  d$runtime$threads <- 1L
  d$runtime$campaign_workers <- workers
  d$runtime$workers <- workers
  d$runtime$root_scheduler <- "load_balanced"
  d$diagnostics$fit_runtime$stream_child_stdout <- TRUE
  d$diagnostics$fit_runtime$timeout_seconds <- 43200L
  d$diagnostics$fit_runtime$timeout_kill_after_seconds <- 60L
  d$metrics$posterior_metric_draws <- if (experiment == "al_confirmation") 200L else 100L
  d$pipeline$readout$input_mode <- as.character(bundle$input_mode[[1L]])
  d$pipeline$decomposition <- qdesn_tfv1_decomposition(bundle_id)
  d$pipeline$validation_guardrails$allow_dlm_decomp_lags <- startsWith(bundle_id, "al_sr")
  d$pipeline$validation_guardrails$allow_dlm_decomp_lags_reason <- if (startsWith(bundle_id, "al_sr")) {
    "predeclared full-budget state-residual confirmation"
  } else "raw-input follow-up"
  d$pipeline$inference$mcmc$n_burn <- as.integer(bundle$n_burn[[1L]])
  d$pipeline$inference$mcmc$n_mcmc <- as.integer(bundle$n_mcmc[[1L]])
  d$pipeline$inference$mcmc$thin <- 1L
  d$pipeline$inference$mcmc$progress_every <- 50L
  d$pipeline$inference$mcmc$init_from_vb <- TRUE
  d$pipeline$inference$mcmc$vb_warm_start_control$max_iter <- 150L
  d$pipeline$inference$mcmc$vb_warm_start_control$min_iter_elbo <- 40L
  d$pipeline$inference$mcmc$vb_warm_start_control$n_samp_xi <- 500L
  sampler <- qdesn_tfv1_sampler_control(bundle_id)
  rhs <- d$pipeline$inference$mcmc$prior_overrides$rhs_ns
  rhs$n_burn <- as.integer(bundle$n_burn[[1L]])
  rhs$n_mcmc <- as.integer(bundle$n_mcmc[[1L]])
  rhs$progress_every <- 50L
  rhs$slice <- utils::modifyList(rhs$slice %||% list(), sampler$slice)
  rhs$multi_start <- sampler$multi_start
  d$pipeline$inference$mcmc$prior_overrides$rhs_ns <- rhs
  d$pipeline$outputs$keep_draws <- FALSE
  d$pipeline$outputs$keep_mcmc_vb_init <- FALSE
  d$pipeline$outputs$save_forecast_objects <- FALSE
  d$pipeline$outputs$save_compact_fit_paths <- TRUE
  d$pipeline$outputs$save_metric_summaries <- TRUE
  d$pipeline$outputs$retain_full_rds_on_failure <- FALSE
  d$pipeline$outputs$retention_profile <- "storage_light_trainonly_followup_v1"
  d$screening_profiles <- list(
    enabled = TRUE,
    csv = rel_path(profile_path),
    cell_assignments_csv = rel_path(assignment_path),
    priors = "rhs_ns",
    design = paste("Train-only follow-up v1", bundle_id),
    execution_grid_policy = "cell_specific_subset_grid"
  )
  d$smoke <- list(
    family = as.character(bundle$family[[1L]]), tau = as.numeric(bundle$tau[[1L]]),
    fit_sizes = 500L, priors = as.list("rhs_ns"), max_roots = 1L,
    budget = list(posterior_metric_draws = 4L, vb_sampling_nd_draws = 4L,
                  vb_synthesis_n_samp = 4L, mcmc_n_burn = 4L, mcmc_n_mcmc = 4L, mcmc_thin = 1L),
    pipeline = list(inference = list(mcmc = list(
      n_burn = 4L, n_mcmc = 4L, thin = 1L, progress_every = 1L,
      init_from_vb = TRUE,
      vb_warm_start_control = list(max_iter = 5L, min_iter_elbo = 2L, n_samp_xi = 10L)
    )))
  )
  d
}

set_source <- function(d, dynamic_root, staged_root, scenarios, family, tau) {
  d$source_materialization$dynamic_root <- dynamic_root
  d$source_materialization$staged_root <- staged_root
  d$source_materialization$scenarios <- as.list(scenarios)
  d$source_materialization$families <- as.list(family)
  d$source_materialization$taus <- as.list(tau)
  d$reference$dynamic_root <- dynamic_root
  d$reference_contract$scenarios <- as.list(scenarios)
  d$reference_contract$families <- as.list(family)
  d$reference_contract$taus <- as.list(tau)
  d$reference_contract$fit_sizes <- 500L
  d$reference_contract$expected_unique_dataset_cells <- length(scenarios)
  d$reference_contract$expected_qdesn_roots <- length(scenarios)
  d$reference_contract$expected_selected_qdesn_roots <- length(scenarios)
  d$pilot$source_scenario <- scenarios[[1L]]
  d$pilot$source_family <- family
  d$pilot$tau <- tau
  d
}

generated_paths <- c(source_cfg_path, dev04_registry_path, dev04_slice_registry_path,
                     profiles_path, bundles_path, sources_path)
bundle_rows <- list()
for (i in seq_len(nrow(bundles))) {
  b <- bundles[i, , drop = FALSE]
  bundle_id <- as.character(b$bundle_id[[1L]])
  p <- profiles[profiles$bundle_id == bundle_id, , drop = FALSE]
  assignments <- data.frame(
    assignment_key = paste(p$screening_profile_id, p$target_family, qdesn_tfv1_tau_key(p$target_tau), sep = "\r"),
    family = p$target_family, tau = p$target_tau, likelihood_target = p$likelihood_target,
    screening_profile_id = p$screening_profile_id, target_cell_id = p$target_cell_id,
    bundle_id = p$bundle_id, arm_code = p$arm_code,
    source_role = p$source_role, reservoir_replicate = p$reservoir_replicate,
    stringsAsFactors = FALSE
  )
  p_path <- write_csv(p, paste0(stub, "_", bundle_id, "_profiles.csv"))
  a_path <- write_csv(assignments, paste0(stub, "_", bundle_id, "_cell_assignments.csv"))
  d <- configure_defaults(b, p_path, a_path)
  bundle_source_role <- as.character(b$source_role[[1L]])
  d$smoke$scenario <- switch(
    bundle_source_role,
    frozen_article = "dlm_constV_p90_m0amp_highnoise_steepertrend_v2_TTmain10000_fitforecast",
    untouched_confirmation = replicate$scenario_id,
    development = "dlm_constV_p90_trainonly_mech_dev01_TTmain10000_fitforecast",
    stop(sprintf("Unsupported source role: %s", bundle_source_role), call. = FALSE)
  )
  d$smoke$screening_profile_ids <- as.list(as.character(p$screening_profile_id[[1L]]))
  tmp_defaults <- paste0(stub, "_", bundle_id, "_defaults.yaml")
  grids <- list()
  if (as.character(b$experiment[[1L]]) == "al_confirmation") {
    if (bundle_source_role == "frozen_article") {
      d <- set_source(
        d,
        as.character(base_defaults$source_materialization$dynamic_root),
        as.character(base_defaults$source_materialization$staged_root),
        "dlm_constV_p90_m0amp_highnoise_steepertrend_v2_TTmain10000_fitforecast",
        "normal", 0.05
      )
      refresh_bundle_source <- FALSE
    } else if (bundle_source_role == "untouched_confirmation") {
      d <- set_source(
        d, as.character(generation$output_parent),
        file.path("results", "qdesn_mcmc_validation", stage, "source_windows"),
        replicate$scenario_id, "normal", 0.05
      )
      refresh_bundle_source <- bundle_id == "al_raw_dev04"
    } else {
      stop(sprintf("Unexpected AL source role: %s", bundle_source_role), call. = FALSE)
    }
    yaml::write_yaml(d, tmp_defaults)
    grids[[1L]] <- exdqlm:::qdesn_dynamic_crossstudy_build_grid(
      exdqlm:::qdesn_dynamic_crossstudy_load_defaults(tmp_defaults),
      refresh_materialized = refresh_bundle_source, verbose = TRUE
    )
  } else {
    mechanism_defaults <- yaml::read_yaml(file.path(
      mechanism_root, "config", "validation",
      "qdesn_dynamic_fitforecast_v2_500obs_trainonly_mechanism_v1_raw_defaults.yaml"
    ))
    mechanism_dynamic_root <- as.character(mechanism_defaults$source_materialization$dynamic_root)
    mechanism_staged_root <- as.character(mechanism_defaults$source_materialization$staged_root)
    if (!grepl("^/", mechanism_dynamic_root)) mechanism_dynamic_root <- file.path(mechanism_root, mechanism_dynamic_root)
    if (!grepl("^/", mechanism_staged_root)) mechanism_staged_root <- file.path(mechanism_root, mechanism_staged_root)
    d <- set_source(
      d, mechanism_dynamic_root, mechanism_staged_root,
      c("dlm_constV_p90_trainonly_mech_dev01_TTmain10000_fitforecast",
        "dlm_constV_p90_trainonly_mech_dev02_TTmain10000_fitforecast",
        "dlm_constV_p90_trainonly_mech_dev03_TTmain10000_fitforecast"),
      "gausmix", 0.25
    )
    yaml::write_yaml(d, tmp_defaults)
    grids[[1L]] <- exdqlm:::qdesn_dynamic_crossstudy_build_grid(
      exdqlm:::qdesn_dynamic_crossstudy_load_defaults(tmp_defaults),
      refresh_materialized = FALSE, verbose = TRUE
    )
  }
  grid <- do.call(rbind, grids)
  key <- paste(grid$screening_profile_id, grid$source_family, qdesn_tfv1_tau_key(grid$tau), sep = "\r")
  target_key <- paste(p$screening_profile_id, p$target_family, qdesn_tfv1_tau_key(p$target_tau), sep = "\r")
  grid <- grid[key %in% target_key, , drop = FALSE]
  lookup <- p[, c("screening_profile_id", "target_cell_id", "target_role", "primary_target",
                  "target_family", "target_tau", "likelihood_target", "bundle_id", "arm_code",
                  "experiment", "source_role", "reservoir_replicate", "paired_reservoir_seed"), drop = FALSE]
  grid <- merge(grid, lookup, by = "screening_profile_id", all.x = TRUE, sort = FALSE)
  grid$source_registry_hash_value <- ifelse(
    grid$source_scenario == "dlm_constV_p90_m0amp_highnoise_steepertrend_v2_TTmain10000_fitforecast",
    article_identity,
    ifelse(grid$source_scenario == replicate$scenario_id, dev04_registry_sha, development_identity)
  )
  grid$source_registry_role <- ifelse(
    grid$source_scenario == "dlm_constV_p90_m0amp_highnoise_steepertrend_v2_TTmain10000_fitforecast",
    "frozen_article", ifelse(grid$source_scenario == replicate$scenario_id, "untouched_confirmation", "development")
  )
  grid <- grid[order(grid$source_scenario, grid$arm_code, grid$reservoir_replicate), , drop = FALSE]
  if (nrow(grid) != as.integer(b$expected_specs[[1L]])) {
    stop(sprintf("Bundle %s expected %d roots; found %d.", bundle_id, b$expected_specs[[1L]], nrow(grid)), call. = FALSE)
  }
  grid_path <- write_csv(grid, paste0(stub, "_", bundle_id, "_grid.csv"))
  final_scenarios <- unique(as.character(grid$source_scenario))
  d$source_materialization$scenarios <- as.list(final_scenarios)
  d$reference_contract$scenarios <- as.list(final_scenarios)
  d$reference_contract$expected_unique_dataset_cells <- length(final_scenarios)
  d$reference_contract$expected_qdesn_roots <- nrow(grid)
  d$screening_profiles$canonical_profile_count <- nrow(p)
  d$screening_profiles$selected_assignment_root_count <- nrow(grid)
  d$reference_contract$expected_selected_qdesn_roots <- nrow(grid)
  yaml::write_yaml(d, tmp_defaults)
  loaded <- exdqlm:::qdesn_dynamic_crossstudy_load_defaults(tmp_defaults)
  exdqlm:::qdesn_dynamic_crossstudy_validate_grid(grid, loaded)
  atomic <- exdqlm:::qdesn_dynamic_fitforecast_atomic_spec_grid(
    grid, defaults = loaded, methods = "mcmc", likelihood_families = as.character(b$likelihood_target[[1L]])
  )
  target_specs <- atomic[atomic$likelihood_family == as.character(b$likelihood_target[[1L]]), , drop = FALSE]
  if (nrow(target_specs) != nrow(grid) || anyDuplicated(target_specs$spec_id)) {
    stop(sprintf("Bundle %s atomic spec contract failed.", bundle_id), call. = FALSE)
  }
  specs_path <- write_csv(target_specs, paste0(stub, "_", bundle_id, "_target_spec_ids.csv"))
  loaded$execution$allowed_fit_spec_ids <- as.list(as.character(target_specs$spec_id))
  yaml::write_yaml(loaded, tmp_defaults)
  manifest <- list(
    generated_at = as.character(Sys.time()), bundle_id = bundle_id,
    experiment = as.character(b$experiment[[1L]]), expected_specs = nrow(grid),
    package_version = "1.0.0", git_branch = trimws(system("git branch --show-current", intern = TRUE)),
    git_commit = trimws(system("git rev-parse HEAD", intern = TRUE)),
    profiles_path = p_path, assignments_path = a_path, defaults_path = resolve_path(tmp_defaults),
    grid_path = grid_path, target_specs_path = specs_path,
    launch_state = "materialized_not_launched", article_state = "unchanged"
  )
  manifest_path <- write_json(manifest, paste0(stub, "_", bundle_id, "_materialization_manifest.json"))
  bundle_rows[[i]] <- data.frame(
    bundle_id = bundle_id, experiment = as.character(b$experiment[[1L]]),
    expected_specs = nrow(grid), defaults_path = resolve_path(tmp_defaults), grid_path = grid_path,
    target_specs_path = specs_path, manifest_path = manifest_path, stringsAsFactors = FALSE
  )
  generated_paths <- c(generated_paths, p_path, a_path, resolve_path(tmp_defaults), grid_path, specs_path, manifest_path)
}

bundle_index <- do.call(rbind, bundle_rows)
bundle_index_path <- write_csv(bundle_index, paste0(stub, "_bundle_index.csv"))
generated_paths <- unique(c(generated_paths, bundle_index_path))
file_manifest <- data.frame(
  path = normalizePath(generated_paths, winslash = "/", mustWork = TRUE),
  bytes = as.numeric(file.info(generated_paths)$size),
  sha256 = vapply(generated_paths, sha256, character(1L)), stringsAsFactors = FALSE
)
file_manifest_path <- write_csv(file_manifest, paste0(stub, "_generated_file_manifest.csv"))
main_manifest <- list(
  generated_at = as.character(Sys.time()), stage = stage, package_version = "1.0.0",
  git_branch = trimws(system("git branch --show-current", intern = TRUE)),
  git_commit = trimws(system("git rev-parse HEAD", intern = TRUE)),
  source_contract_path = sources_path,
  canonical_source_registry_path = canonical_registry_path,
  canonical_source_registry_file_sha256 = sha256(canonical_registry_path),
  canonical_source_registry_identity = article_identity,
  development_source_registry_path = mechanism_source_registry_path,
  development_source_registry_sha256 = development_identity,
  dev04_source_registry_path = dev04_registry_path,
  dev04_source_registry_sha256 = dev04_registry_sha,
  bundle_index_path = bundle_index_path,
  generated_file_manifest_path = file_manifest_path,
  counts = list(qdesn_roots = sum(bundle_index$expected_specs), structured_comparator_roots = 4L,
                al_confirmation_roots = 18L, exal_sampler_diagnostic_roots = 18L),
  launch_state = "materialized_not_launched", article_state = "unchanged_pending_closeout"
)
manifest_path <- write_json(main_manifest, paste0(stub, "_materialization_manifest.json"))
cat(sprintf("Materialization manifest: %s\n", manifest_path))
cat(sprintf("Q-DESN roots: %d\n", sum(bundle_index$expected_specs)))
cat(sprintf("dev04 source registry: %s (sha256=%s)\n", dev04_registry_path, dev04_registry_sha))

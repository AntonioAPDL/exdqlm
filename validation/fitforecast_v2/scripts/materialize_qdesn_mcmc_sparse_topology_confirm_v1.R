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

repo_root <- normalizePath(
  system("git rev-parse --show-toplevel", intern = TRUE),
  winslash = "/", mustWork = TRUE
)
setwd(repo_root)
pkgload::load_all(repo_root, quiet = TRUE)
source(file.path(
  repo_root, "validation", "fitforecast_v2", "R",
  "qdesn_alpha_rho_topology_v1.R"
))
source(file.path(
  repo_root, "validation", "fitforecast_v2", "R",
  "qdesn_mcmc_sparse_topology_refine_v1.R"
))

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
  jsonlite::write_json(
    value, path, pretty = TRUE, auto_unbox = TRUE, null = "null", digits = NA
  )
  normalizePath(path, winslash = "/", mustWork = TRUE)
}
sha256 <- function(path) unname(tools::sha256sum(resolve_path(path)))
tau_key <- function(x) sprintf("%.8f", as.numeric(x))
as_bool <- function(x) {
  if (is.logical(x)) return(!is.na(x) & x)
  toupper(trimws(as.character(x))) %in% c("TRUE", "T", "1", "YES")
}

description <- read.dcf(file.path(repo_root, "DESCRIPTION"))
if (!identical(as.character(description[1L, "Package"]), "exdqlm") ||
    !identical(as.character(description[1L, "Version"]), "1.0.0")) {
  stop("Sparse-topology confirmation requires exdqlm 1.0.0.", call. = FALSE)
}

workers <- suppressWarnings(as.integer(get_arg("--workers", "20"))[1L])
if (!is.finite(workers) || workers != 20L) {
  stop("The confirmation contract requires exactly 20 workers.", call. = FALSE)
}
refresh_materialized <- !has_flag("--no-staged-refresh")
stage <- "qdesn_dynamic_fitforecast_v2_500obs_mcmc_sparse_topology_confirm_v1"
stub <- file.path("config", "validation", stage)
source_stage <- "qdesn_dynamic_fitforecast_v2_500obs_mcmc_sparse_topology_refine_v1"
source_stub <- file.path("config", "validation", source_stage)
authority_path <- file.path(
  "validation", "fitforecast_v2", "promotions",
  "qdesn_dqlm_500obs_trainonly_article_v3_20260807",
  "qdesn_dqlm_500obs_trainonly_article_v3_20260807_interface.csv"
)
expected_authority_sha256 <- "90744fae79f8af79c6e844e5862c90330ea14d9bbd2df69f630440887fed1393"
expected_registry_hash <- "edddb56fc2b30e49ac99fdd08b53dad468ed53e05d0fe1fe16426ee9d9ffe275"
frozen_inputs <- c(
  source_profiles = paste0(source_stub, "_profiles.csv"),
  source_defaults = paste0(source_stub, "_defaults.yaml"),
  source_registry = paste0(source_stub, "_source_registry.csv"),
  source_file_audit = paste0(source_stub, "_source_file_hash_audit.csv"),
  authority_interface = authority_path
)
expected_input_hashes <- c(
  source_profiles = "68f5e08baeeb473e27ee1674dedda13a2533e41fe340258aa6ed64d2c08f4c51",
  source_defaults = "8266959fbcae60637e6c18e9b773cad2adda4562b4cd55e2df17c1de71500df4",
  source_registry = "7556ebddc65a5a1702fe532399380eb61de836934bd8f0f7f4149f5e5feddba1",
  source_file_audit = "6974021cc9e06094d92cdf0588bb3d97c5531f4ed49581ca034b24ba8169a8b2",
  authority_interface = expected_authority_sha256
)
observed_input_hashes <- vapply(frozen_inputs, sha256, character(1L))
if (!identical(unname(observed_input_hashes), unname(expected_input_hashes))) {
  bad <- names(frozen_inputs)[observed_input_hashes != expected_input_hashes]
  stop(sprintf("Frozen confirmation input hash mismatch: %s", paste(bad, collapse = ", ")),
       call. = FALSE)
}

source_profiles <- read_csv(frozen_inputs[["source_profiles"]])
source_ids <- c(
  "strv1_al_w01_seed910010_parent",
  "strv1_al_w01_seed910020_parent",
  "strv1_al_w01_seed910020_p04",
  "strv1_exal_w01_seed910010_parent",
  "strv1_exal_w01_seed910010_p02",
  "strv1_exal_w03_seed1110003_parent",
  "strv1_exal_w03_seed1110003_p05"
)
base <- source_profiles[
  source_profiles$base_design_id %in% source_ids &
    as.integer(source_profiles$sampler_replicate) == 1L,
  , drop = FALSE
]
base <- base[match(source_ids, base$base_design_id), , drop = FALSE]
if (nrow(base) != 7L || anyNA(base$base_design_id) || anyDuplicated(base$base_design_id)) {
  stop("Could not recover the seven exact sparse-topology designs.", call. = FALSE)
}
base$replication_source_profile_id <- base$screening_profile_id
base$source_base_design_id <- base$base_design_id
base$replication_purpose <- c(
  "AL promoted check-loss parent control",
  "AL matched parent for the fit-and-MAE candidate",
  "AL promoted fit-and-MAE candidate",
  "exAL promoted fit parent and matched p02 control",
  "exAL promoted forecast-MAE candidate",
  "exAL matched parent for the p05 check-loss candidate",
  "exAL promoted forecast-check candidate"
)

profiles <- do.call(rbind, lapply(seq_len(nrow(base)), function(i) {
  do.call(rbind, lapply(3:5, function(rep_id) {
    row <- base[i, , drop = FALSE]
    new_base <- sub("^strv1_", "strc1_", row$base_design_id)
    row$screening_profile_id <- sprintf("%s_r%02d", new_base, rep_id)
    row$base_design_id <- new_base
    row$confirmation_design_id <- new_base
    row$sampler_replicate <- as.integer(rep_id)
    row$screening_stage <- "mcmc_sparse_topology_confirm_v1"
    row$screening_wave <- "sparse_topology_repeatability_2026_08_07"
    row$launch_phase <- "full_budget_repeatability_confirmation"
    row$candidate_source <- "sparse_topology_refine_v1_promoted_metric_source"
    row$selection_reason <- paste(
      "Exact v3 promoted metric source or its source-matched sparse parent;",
      "three fresh sampler replicates test repeatability without changing the design."
    )
    row
  }))
}))
rownames(profiles) <- NULL
profiles$control_key <- paste(
  profiles$target_cell_id, profiles$topology_class, profiles$seed, sep = "::"
)
profiles$sampler_pair_id <- paste(
  profiles$control_key, sprintf("r%02d", profiles$sampler_replicate), sep = "::"
)
pair_levels <- sort(unique(profiles$sampler_pair_id))
pair_index <- match(profiles$sampler_pair_id, pair_levels)
profiles$mcmc_seed <- as.integer(971000L + pair_index)
profiles$mcmc_rng_seed <- as.integer(972000L + pair_index)
profiles$vb_warm_start_seed <- as.integer(973000L + pair_index)
profiles$synthesis_seed <- as.integer(974000L + pair_index)

parents <- profiles[profiles$comparison_role == "matched_sparse_parent", , drop = FALSE]
candidates <- profiles[profiles$comparison_role == "candidate", , drop = FALSE]
parent_index <- match(candidates$sampler_pair_id, parents$sampler_pair_id)
if (nrow(candidates) != 9L || anyNA(parent_index)) {
  stop("The three candidate designs do not have nine exact fresh parent pairs.", call. = FALSE)
}
pair_map <- data.frame(
  pair_id = paste(candidates$screening_profile_id,
                  parents$screening_profile_id[parent_index], sep = "::vs::"),
  target_cell_id = candidates$target_cell_id,
  likelihood_target = candidates$likelihood_target,
  confirmation_design_id = candidates$confirmation_design_id,
  source_base_design_id = candidates$source_base_design_id,
  topology_class = candidates$topology_class,
  desn_seed = candidates$seed,
  sampler_replicate = candidates$sampler_replicate,
  sampler_pair_id = candidates$sampler_pair_id,
  candidate_profile_id = candidates$screening_profile_id,
  parent_profile_id = parents$screening_profile_id[parent_index],
  stringsAsFactors = FALSE
)
assignments <- data.frame(
  assignment_id = sprintf("strc1_%02d", seq_len(nrow(profiles))),
  family = profiles$target_family,
  tau = profiles$target_tau,
  likelihood_target = profiles$likelihood_target,
  target_cell_id = profiles$target_cell_id,
  screening_profile_id = profiles$screening_profile_id,
  source_base_design_id = profiles$source_base_design_id,
  comparison_role = profiles$comparison_role,
  topology_class = profiles$topology_class,
  paired_reservoir_seed = profiles$seed,
  sampler_replicate = profiles$sampler_replicate,
  sampler_pair_id = profiles$sampler_pair_id,
  launch_status = "prepared_not_launched",
  stringsAsFactors = FALSE
)
selected_designs <- unique(profiles[, c(
  "base_design_id", "source_base_design_id", "replication_source_profile_id",
  "target_cell_id", "likelihood_target", "comparison_role",
  "replication_purpose", "D", "n_each", "m", "alpha", "rho", "pi_w",
  "pi_in", "rhs_tau0", "seed", "topology_class", "recurrent_edges_target"
), drop = FALSE])
selected_designs <- selected_designs[order(
  selected_designs$target_cell_id, selected_designs$source_base_design_id
), , drop = FALSE]
if (nrow(profiles) != 21L || nrow(assignments) != 21L || nrow(pair_map) != 9L ||
    nrow(selected_designs) != 7L || anyDuplicated(profiles$screening_profile_id)) {
  stop("The 21-fit sparse-topology confirmation profile contract failed.", call. = FALSE)
}

topology_audit <- qdesn_strv1_topology_audit(profiles)
profiles_path <- write_csv(profiles, paste0(stub, "_profiles.csv"))
assignments_path <- write_csv(assignments, paste0(stub, "_cell_assignments.csv"))
pair_map_path <- write_csv(pair_map, paste0(stub, "_pair_map.csv"))
selected_designs_path <- write_csv(selected_designs, paste0(stub, "_selected_designs.csv"))
topology_audit_path <- write_csv(topology_audit, paste0(stub, "_topology_audit.csv"))

registry <- read_csv(frozen_inputs[["source_registry"]])
source_file_audit <- read_csv(frozen_inputs[["source_file_audit"]])
if (nrow(registry) != 1L || !all(as_bool(source_file_audit$hash_match)) ||
    registry$TT_warmup != 2000L || registry$TT_main != 10000L ||
    registry$TT_total != 12000L || registry$train_start_source_index != 8501L ||
    registry$train_end_source_index != 9000L ||
    registry$forecast_origin_source_index != 9000L ||
    registry$forecast_start_source_index != 9001L ||
    registry$forecast_end_source_index != 10000L ||
    registry$max_lead_configured != 30L || registry$origin_stride != 30L ||
    as_bool(registry$refit_per_origin)) {
  stop("The frozen source registry violates the 500-observation protocol.", call. = FALSE)
}
source_registry_path <- write_csv(registry, paste0(stub, "_source_registry.csv"))
source_file_audit_path <- write_csv(
  source_file_audit, paste0(stub, "_source_file_hash_audit.csv")
)

defaults <- yaml::read_yaml(resolve_path(frozen_inputs[["source_defaults"]]))
defaults$campaign <- list(
  name = stage,
  results_root = file.path("results", "qdesn_mcmc_validation", stage),
  reports_root = file.path("reports", "qdesn_mcmc_validation", stage)
)
defaults$execution$methods <- "mcmc"
defaults$execution$likelihood_families <- as.list(c("al", "exal"))
defaults$execution$allowed_fit_spec_ids <- NULL
defaults$execution$seed_policy <- list(mode = "explicit_per_profile", base_seed = 971001L)
defaults$reference_contract$expected_qdesn_roots <- 21L
defaults$reference_contract$expected_selected_qdesn_roots <- 21L
defaults$screening_profiles$csv <- rel_path(profiles_path)
defaults$screening_profiles$cell_assignments_csv <- rel_path(assignments_path)
defaults$screening_profiles$design <- paste(
  "Seven exact promoted or matched-parent sparse designs, each evaluated with",
  "three fresh full-budget sampler replicates."
)
defaults$screening_profiles$execution_grid_policy <- "21_exact_design_repeatability_roots"
defaults$screening_profiles$canonical_profile_count <- 21L
defaults$screening_profiles$canonical_qdesn_root_count <- 21L
defaults$screening_profiles$selected_assignment_root_count <- 21L
defaults$study_contract$id <- paste0(stage, "_2026_08_07")
defaults$study_contract$description <- paste(
  "Fresh-replicate confirmation of the exact Normal p=0.25 sparse-topology",
  "designs responsible for the v3 article metric envelope."
)
defaults$study_contract$authoritative_interface_path <- resolve_path(authority_path)
defaults$study_contract$authoritative_interface_sha256 <- expected_authority_sha256
defaults$study_contract$sparse_topology_confirm_v1 <- list(
  source_campaign_stage = source_stage,
  source_profiles_path = resolve_path(frozen_inputs[["source_profiles"]]),
  source_profiles_sha256 = observed_input_hashes[["source_profiles"]],
  selected_designs_path = selected_designs_path,
  selected_designs_sha256 = sha256(selected_designs_path),
  pair_map_path = pair_map_path,
  pair_map_sha256 = sha256(pair_map_path),
  fresh_sampler_replicates = as.list(3:5),
  replication_rule = "at_least_two_of_three_fresh_replicates_below_frozen_authority",
  diagnostic_policy = "retain_but_never_filter_finite_metrics",
  article_update_automatic = FALSE
)
defaults$study_contract$selection_policy <- list(
  unit = "exact_design_fresh_replication",
  target_cells = 2L,
  unique_designs = 7L,
  candidate_designs = 3L,
  matched_parent_designs = 4L,
  sampler_replicates = 3L,
  expected_specs = 21L,
  exact_candidate_parent_pairs = 9L,
  promotion_policy = "strict_raw_metric_improvement_regardless_of_diagnostic_grade",
  promotion_tolerance = 1e-10,
  article_policy = "manual_review_only"
)
defaults$runtime$threads <- 1L
defaults$runtime$campaign_workers <- 20L
defaults$runtime$workers <- 20L
defaults$runtime$root_scheduler <- "load_balanced"
defaults$pipeline$outputs$retention_profile <- "storage_light_sparse_topology_confirm_v1"
defaults_path <- resolve_path(paste0(stub, "_defaults.yaml"), FALSE)
yaml::write_yaml(defaults, defaults_path)

loaded <- exdqlm:::qdesn_dynamic_crossstudy_load_defaults(defaults_path)
canonical_grid <- exdqlm:::qdesn_dynamic_crossstudy_build_grid(
  loaded, refresh_materialized = refresh_materialized, verbose = TRUE
)
exdqlm:::qdesn_dynamic_crossstudy_validate_grid(canonical_grid, loaded)
lookup_fields <- c(
  "screening_profile_id", "source_screening_profile_id",
  "replication_source_profile_id", "source_base_design_id",
  "confirmation_design_id", "target_cell_id", "target_metrics",
  "likelihood_target", "target_family", "target_tau", "comparison_role",
  "control_key", "selection_tier", "selection_role", "reservoir_replicate",
  "sampler_replicate", "sampler_pair_id", "mcmc_seed", "mcmc_rng_seed",
  "vb_warm_start_seed", "synthesis_seed", "D", "n_each", "m", "alpha",
  "rho", "pi_w", "pi_in", "rhs_tau0", "topology_class",
  "recurrent_edges_target", "replication_purpose"
)
lookup <- profiles[, lookup_fields, drop = FALSE]
grid_key <- paste(canonical_grid$screening_profile_id,
                  canonical_grid$source_family, tau_key(canonical_grid$tau), sep = "\r")
target_key <- paste(lookup$screening_profile_id,
                    lookup$target_family, tau_key(lookup$target_tau), sep = "\r")
grid <- canonical_grid[grid_key %in% target_key, , drop = FALSE]
index <- match(grid$screening_profile_id, lookup$screening_profile_id)
for (field in setdiff(lookup_fields, "screening_profile_id")) {
  grid[[field]] <- lookup[[field]][index]
}
grid$source_registry_hash_value <- expected_registry_hash
grid <- qdesn_strv1_assign_execution_seeds(grid, profiles)
grid <- grid[order(
  grid$target_cell_id, grid$control_key, grid$sampler_replicate,
  grid$comparison_role, grid$confirmation_design_id
), , drop = FALSE]
if (nrow(grid) != 21L || anyNA(grid$target_cell_id) || anyDuplicated(grid$root_id) ||
    any(grid$train_start_source_index != 8501L) ||
    any(grid$train_end_source_index != 9000L) ||
    any(grid$forecast_start_source_index != 9001L) ||
    any(grid$forecast_end_source_index != 10000L)) {
  stop(sprintf("Expected 21 exact frozen-source grid rows; found %d.", nrow(grid)),
       call. = FALSE)
}
seed_audit <- qdesn_strv1_seed_contract_audit(grid, profiles, TRUE)
grid_path <- write_csv(grid, paste0(stub, "_grid.csv"))
seed_audit_path <- write_csv(seed_audit, paste0(stub, "_seed_contract_audit.csv"))

atomic <- exdqlm:::qdesn_dynamic_fitforecast_atomic_spec_grid(
  grid, defaults = loaded, methods = "mcmc", likelihood_families = c("al", "exal")
)
atomic_index <- match(atomic$root_id, grid$root_id)
for (field in c(
  "target_cell_id", "likelihood_target", "confirmation_design_id",
  "source_base_design_id", "comparison_role", "control_key",
  "sampler_replicate", "sampler_pair_id", "topology_class",
  "recurrent_edges_target"
)) {
  atomic[[field]] <- grid[[field]][atomic_index]
}
target_specs <- atomic[
  atomic$likelihood_family == atomic$likelihood_target, , drop = FALSE
]
target_specs <- target_specs[order(
  target_specs$target_cell_id, target_specs$control_key,
  target_specs$sampler_replicate, target_specs$comparison_role
), , drop = FALSE]
if (nrow(target_specs) != 21L || anyDuplicated(target_specs$spec_id)) {
  stop(sprintf("Expected 21 unique target specs; found %d.", nrow(target_specs)),
       call. = FALSE)
}
target_specs_path <- write_csv(target_specs, paste0(stub, "_target_spec_ids.csv"))
loaded$execution$allowed_fit_spec_ids <- as.list(as.character(target_specs$spec_id))
yaml::write_yaml(loaded, defaults_path)

al_candidate <- profiles[
  profiles$source_base_design_id == "strv1_al_w01_seed910020_p04" &
    profiles$sampler_replicate == 3L, , drop = FALSE
]
al_parent <- profiles[
  profiles$source_base_design_id == "strv1_al_w01_seed910020_parent" &
    profiles$sampler_replicate == 3L, , drop = FALSE
]
exal_candidate <- profiles[
  profiles$source_base_design_id == "strv1_exal_w01_seed910010_p02" &
    profiles$sampler_replicate == 3L, , drop = FALSE
]
smoke_profiles <- rbind(al_candidate, al_parent, exal_candidate)
smoke_grid <- grid[grid$screening_profile_id %in% smoke_profiles$screening_profile_id,
                   , drop = FALSE]
smoke_specs <- target_specs[target_specs$root_id %in% smoke_grid$root_id, , drop = FALSE]
if (nrow(smoke_grid) != 3L || nrow(smoke_specs) != 3L) {
  stop("Smoke contract must contain one AL pair and one exAL candidate.", call. = FALSE)
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

authority <- read_csv(authority_path)
article_context <- authority[
  authority$inference == "mcmc" & authority$family == "normal" &
    abs(as.numeric(authority$tau) - 0.25) <= 1e-12 &
    authority$model_variant %in% c("qdesn_al_rhs_ns", "qdesn_exal_rhs_ns"),
  , drop = FALSE
]
if (nrow(article_context) != 2L) {
  stop("Could not recover both v3 article authority cells.", call. = FALSE)
}
article_context_path <- write_csv(
  article_context, paste0(stub, "_current_article_metric_context.csv")
)
promotion_contract <- data.frame(
  model_variant = c("qdesn_al_rhs_ns", "qdesn_exal_rhs_ns"),
  target_cell_id = c("al_normal_t0p25", "exal_normal_t0p25"),
  family = "normal", tau = 0.25,
  metrics = "fit_qtrue_rmse|forecast_qtrue_mae_H1000|forecast_check_loss_H1000",
  fresh_replicates = 3L,
  minimum_replicates_below_authority = 2L,
  median_must_improve = TRUE,
  improvement_tolerance = 1e-10,
  status_filter = FALSE,
  source_registry_hash_value = expected_registry_hash,
  mcmc_n_burn = 5000L,
  mcmc_n_mcmc = 20000L,
  article_update_automatic = FALSE,
  stringsAsFactors = FALSE
)
promotion_contract_path <- write_csv(
  promotion_contract, paste0(stub, "_promotion_contract.csv")
)

generated_files <- c(
  profiles = profiles_path,
  assignments = assignments_path,
  pair_map = pair_map_path,
  selected_designs = selected_designs_path,
  topology_audit = topology_audit_path,
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
frozen_input_manifest <- data.frame(
  role = names(frozen_inputs),
  path = vapply(unname(frozen_inputs), resolve_path, character(1L)),
  expected_sha256 = unname(expected_input_hashes),
  observed_sha256 = unname(observed_input_hashes),
  hash_match = unname(expected_input_hashes == observed_input_hashes),
  stringsAsFactors = FALSE
)
frozen_input_manifest_path <- write_csv(
  frozen_input_manifest, paste0(stub, "_frozen_input_manifest.csv")
)
manifest <- list(
  protocol_frozen_at_utc = "2026-08-07T22:15:00Z",
  stage = stage,
  package_version = as.character(description[1L, "Version"]),
  implementation_parent_commit = "acfa0b4a4b989cd3722ebdde378a9f6b47401652",
  authority_interface_path = resolve_path(authority_path),
  authority_interface_sha256 = expected_authority_sha256,
  source_registry_identity_field = "source_registry_hash_value",
  source_registry_hash_value = expected_registry_hash,
  source_registry_path = source_registry_path,
  source_files_verified = all(as_bool(source_file_audit$hash_match)),
  selected_designs_path = selected_designs_path,
  pair_map_path = pair_map_path,
  defaults_path = defaults_path,
  grid_path = grid_path,
  target_specs_path = target_specs_path,
  generated_file_manifest_path = generated_manifest_path,
  frozen_input_manifest_path = frozen_input_manifest_path,
  counts = list(
    unique_designs = 7L,
    candidate_designs = 3L,
    matched_parent_designs = 4L,
    fresh_sampler_replicates = 3L,
    full_specs = 21L,
    exact_pairs = 9L,
    smoke_specs = 3L
  ),
  budget = list(n_burn = 5000L, n_mcmc = 20000L, metric_draws = 200L),
  rolling_origin = list(
    forecast_origin_source_index = 9000L,
    forecast_block = c(9001L, 10000L),
    max_lead = 30L, origin_stride = 30L, refit_per_origin = FALSE
  ),
  execution = list(workers = 20L, threads_per_fit = 1L),
  replication_rule = "at_least_two_of_three_and_fresh_median_below_v3_authority",
  metric_selection_status_agnostic = TRUE,
  article_update_automatic = FALSE,
  launch_status = "materialized_not_launched"
)
manifest_path <- write_json(
  manifest, paste0(stub, "_materialization_manifest.json")
)

cat(sprintf("Materialization manifest: %s\n", manifest_path))
cat(sprintf("Authority interface SHA-256: %s\n", expected_authority_sha256))
cat("Unique designs: 7; fresh replicates: 3; exact pairs: 9\n")
cat(sprintf("Full confirmation specs: %d\n", nrow(target_specs)))
cat(sprintf("Executable smoke specs: %d\n", nrow(smoke_specs)))

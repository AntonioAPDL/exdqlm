#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  required <- c("jsonlite", "pkgload", "yaml")
  missing <- setdiff(required, rownames(installed.packages()))
  if (length(missing)) {
    stop(
      sprintf("Missing required package(s): %s", paste(missing, collapse = ", ")),
      call. = FALSE
    )
  }
})

args <- commandArgs(trailingOnly = TRUE)
get_arg <- function(flag, default = NULL) {
  index <- which(args == flag)
  if (!length(index) || index[[1L]] >= length(args)) return(default)
  args[[index[[1L]] + 1L]]
}
has_flag <- function(flag) any(args == flag)
`%||%` <- function(a, b) if (is.null(a) || !length(a)) b else a

repo_root <- normalizePath(
  system("git rev-parse --show-toplevel", intern = TRUE),
  winslash = "/",
  mustWork = TRUE
)
setwd(repo_root)
pkgload::load_all(repo_root, quiet = TRUE)

resolve_path <- function(path, must_work = TRUE) {
  path <- as.character(path %||% "")[1L]
  if (!grepl("^/", path)) path <- file.path(repo_root, path)
  normalizePath(path, winslash = "/", mustWork = isTRUE(must_work))
}
read_csv <- function(path) {
  utils::read.csv(resolve_path(path), check.names = FALSE, stringsAsFactors = FALSE)
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
  jsonlite::write_json(
    x, path, pretty = TRUE, auto_unbox = TRUE, null = "null", digits = NA
  )
  normalizePath(path, winslash = "/", mustWork = TRUE)
}
sha256 <- function(path) unname(tools::sha256sum(resolve_path(path)))
fmt_tau <- function(x) exdqlm:::.qdesn_dynamic_fitforecast_tau_key(as.numeric(x))
as_bool <- function(x) {
  if (is.logical(x)) return(x)
  toupper(trimws(as.character(x))) %in% c("TRUE", "T", "1", "YES")
}
num <- function(x) suppressWarnings(as.numeric(x))
cell_key <- function(model, family, tau) {
  paste(model, family, sprintf("%.8f", num(tau)), sep = "|")
}
design_key <- function(model, family, tau, role) {
  paste(cell_key(model, family, tau), role, sep = "|")
}

workers <- suppressWarnings(as.integer(get_arg("--workers", "8"))[1L])
if (!is.finite(workers) || workers < 1L) workers <- 8L
workers <- min(workers, 8L)
refresh_materialized <- has_flag("--refresh-materialized")

source_hash <- "edddb56fc2b30e49ac99fdd08b53dad468ed53e05d0fe1fe16426ee9d9ffe275"
origin <- 9000L
stage <- "qdesn_dynamic_fitforecast_v2_500obs_mcmc_nested_final_origin9000_v1"
design_id <- "qdesn_500obs_mcmc_nested_final_origin9000_v1_design_20260730"
design_root <- file.path("validation", "fitforecast_v2", "promotions", design_id)
discovery_id <- "qdesn_500obs_mcmc_nested_cellwise_v1_design_20260729"
discovery_root <- file.path("validation", "fitforecast_v2", "promotions", discovery_id)
closeout_id <- "qdesn_500obs_mcmc_nested_cellwise_v1_closeout_20260730"
closeout_root <- file.path("validation", "fitforecast_v2", "promotions", closeout_id)
envelope_id <- "qdesn_dqlm_500obs_mcmc_metric_envelope_20260727"
envelope_root <- file.path("validation", "fitforecast_v2", "promotions", envelope_id)

paths <- c(
  discovery_profiles = file.path(
    discovery_root, paste0(discovery_id, "_candidate_profiles.csv")
  ),
  discovery_assignments = file.path(
    discovery_root, paste0(discovery_id, "_candidate_assignments.csv")
  ),
  discovery_manifest = file.path(discovery_root, paste0(discovery_id, "_manifest.json")),
  closeout_manifest = file.path(closeout_root, paste0(closeout_id, "_manifest.json")),
  handoff = file.path(closeout_root, "final_origin_confirmation_handoff.csv"),
  replicated_seeds = file.path(closeout_root, "replicated_seed_metrics.csv"),
  parent_context = file.path(closeout_root, "final_origin_parent_context.csv"),
  external_envelope = file.path(
    envelope_root, paste0(envelope_id, "_article_envelope.csv")
  ),
  base_defaults = file.path(
    "config", "validation",
    "qdesn_dynamic_fitforecast_v2_500obs_mcmc_nested_cellwise_v1_origin8000_base_defaults.yaml"
  ),
  documentation = file.path(
    "validation", "fitforecast_v2", "docs",
    "QDESN_500OBS_MCMC_NESTED_FINAL_ORIGIN_V1_2026-07-30.md"
  )
)
paths <- vapply(paths, resolve_path, character(1L))

description <- read.dcf(resolve_path("DESCRIPTION"))
if (description[1L, "Package"] != "exdqlm" ||
    description[1L, "Version"] != "1.0.0") {
  stop("Final-origin confirmation requires exdqlm 1.0.0.", call. = FALSE)
}

discovery_manifest <- jsonlite::read_json(
  paths[["discovery_manifest"]], simplifyVector = TRUE
)
closeout_manifest <- jsonlite::read_json(
  paths[["closeout_manifest"]], simplifyVector = TRUE
)
if (discovery_manifest$source_registry_hash_value != source_hash ||
    closeout_manifest$source_registry_hash_value != source_hash ||
    as.integer(closeout_manifest$observed_terminal_roots) != 720L ||
    as.integer(closeout_manifest$observed_seed_rows) != 1440L ||
    as.integer(closeout_manifest$selected_cells) != 4L) {
  stop("The corrected nested discovery closeout is not frozen and complete.", call. = FALSE)
}

profiles_all <- read_csv(paths[["discovery_profiles"]])
assignments_all <- read_csv(paths[["discovery_assignments"]])
handoff <- read_csv(paths[["handoff"]])
seeds <- read_csv(paths[["replicated_seeds"]])
parent_context <- read_csv(paths[["parent_context"]])
external_envelope <- read_csv(paths[["external_envelope"]])
handoff$likelihood_target <- ifelse(
  grepl("exal", handoff$model_variant, fixed = TRUE), "exal", "al"
)
handoff$cell_key <- cell_key(handoff$model_variant, handoff$family, handoff$tau)
handoff$design_key <- design_key(
  handoff$model_variant, handoff$family, handoff$tau, handoff$design_role
)
if (nrow(handoff) != 4L || anyDuplicated(handoff$cell_key) ||
    !all(as_bool(handoff$selected_for_final_origin_confirmation))) {
  stop("Expected four unique selected discovery cells.", call. = FALSE)
}

joined <- merge(
  assignments_all,
  profiles_all,
  by = "screening_profile_id",
  suffixes = c(".assignment", ".profile")
)
joined$model_variant <- ifelse(
  joined$likelihood_target == "exal", "qdesn_exal_rhs_ns", "qdesn_al_rhs_ns"
)
joined$cell_key <- cell_key(joined$model_variant, joined$family, joined$tau)
joined$design_key <- design_key(
  joined$model_variant, joined$family, joined$tau, joined$profile_role
)
selected_joined <- joined[joined$design_key %in% handoff$design_key, , drop = FALSE]
if (nrow(selected_joined) != 8L ||
    anyDuplicated(selected_joined$screening_profile_id) ||
    !all(table(selected_joined$cell_key) == 2L) ||
    !setequal(selected_joined$reservoir_seed_rep.profile, 1:2)) {
  stop("Could not recover exactly two frozen reservoir profiles per handoff cell.", call. = FALSE)
}

seeds$cell_key <- cell_key(seeds$model_variant, seeds$family, seeds$tau)
seeds$design_key <- design_key(
  seeds$model_variant, seeds$family, seeds$tau, seeds$profile_role
)
origin_rows <- list()
for (index in seq_len(nrow(handoff))) {
  for (view_origin in c(7000L, 8000L)) {
    subset <- seeds[
      seeds$cell_key == handoff$cell_key[[index]] &
        seeds$calibration_origin_source_index == view_origin,
      ,
      drop = FALSE
    ]
    candidate <- subset[subset$design_key == handoff$design_key[[index]], , drop = FALSE]
    anchors <- subset[subset$repeat_class == "declared_anchor_control", , drop = FALSE]
    anchor_designs <- split(anchors, anchors$design_key)
    anchor_metrics <- do.call(rbind, lapply(anchor_designs, function(x) {
      data.frame(
        fit = median(num(x$train_qtrue_rmse), na.rm = TRUE),
        forecast = median(num(x$forecast_qtrue_mae_H1000), na.rm = TRUE),
        check = median(num(x$forecast_check_loss_H1000), na.rm = TRUE)
      )
    }))
    origin_rows[[length(origin_rows) + 1L]] <- data.frame(
      model_variant = handoff$model_variant[[index]],
      family = handoff$family[[index]],
      tau = num(handoff$tau[[index]]),
      design_role = handoff$design_role[[index]],
      calibration_origin_source_index = view_origin,
      fit_ratio_to_best_anchor = median(num(candidate$train_qtrue_rmse), na.rm = TRUE) /
        min(anchor_metrics$fit),
      forecast_mae_ratio_to_best_anchor =
        median(num(candidate$forecast_qtrue_mae_H1000), na.rm = TRUE) /
          min(anchor_metrics$forecast),
      forecast_check_ratio_to_best_anchor =
        median(num(candidate$forecast_check_loss_H1000), na.rm = TRUE) /
          min(anchor_metrics$check),
      stringsAsFactors = FALSE
    )
  }
}
origin_stability <- exdqlm:::.qdesn_validation_bind_rows(origin_rows)
stability_by_cell <- do.call(rbind, lapply(
  split(origin_stability, cell_key(
    origin_stability$model_variant,
    origin_stability$family,
    origin_stability$tau
  )),
  function(x) {
    primary_gap <- handoff$primary_gap[
      handoff$cell_key == cell_key(x$model_variant[[1L]], x$family[[1L]], x$tau[[1L]])
    ][[1L]]
    primary_directional <- if (primary_gap == "fit") {
      all(x$fit_ratio_to_best_anchor < 1)
    } else {
      all(
        x$forecast_mae_ratio_to_best_anchor < 1 |
          x$forecast_check_ratio_to_best_anchor < 1
      )
    }
    data.frame(
      model_variant = x$model_variant[[1L]],
      family = x$family[[1L]],
      tau = x$tau[[1L]],
      design_role = x$design_role[[1L]],
      primary_gap = primary_gap,
      max_origin_fit_ratio = max(x$fit_ratio_to_best_anchor),
      max_origin_forecast_mae_ratio = max(x$forecast_mae_ratio_to_best_anchor),
      max_origin_forecast_check_ratio = max(x$forecast_check_ratio_to_best_anchor),
      originwise_primary_directional_improvement = primary_directional,
      originwise_no_material_regression = max(
        x$fit_ratio_to_best_anchor,
        x$forecast_mae_ratio_to_best_anchor,
        x$forecast_check_ratio_to_best_anchor
      ) <= 1.05,
      stringsAsFactors = FALSE
    )
  }
))
stability_by_cell$confirmation_role <- ifelse(
  stability_by_cell$originwise_primary_directional_improvement &
    stability_by_cell$originwise_no_material_regression,
  "primary_confirmation",
  "instability_sentinel"
)
if (sum(stability_by_cell$confirmation_role == "primary_confirmation") != 3L ||
    sum(stability_by_cell$confirmation_role == "instability_sentinel") != 1L) {
  stop("Expected three robust confirmations and one instability sentinel.", call. = FALSE)
}

profiles <- profiles_all[
  match(selected_joined$screening_profile_id, profiles_all$screening_profile_id),
  ,
  drop = FALSE
]
assignments <- assignments_all[
  match(selected_joined$screening_profile_id, assignments_all$screening_profile_id),
  ,
  drop = FALSE
]
class_key <- cell_key(
  ifelse(assignments$likelihood_target == "exal", "qdesn_exal_rhs_ns", "qdesn_al_rhs_ns"),
  assignments$family,
  assignments$tau
)
class_lookup <- stats::setNames(
  stability_by_cell$confirmation_role,
  cell_key(stability_by_cell$model_variant, stability_by_cell$family, stability_by_cell$tau)
)
assignments$confirmation_role <- unname(class_lookup[class_key])
assignments$launch_status <- "prepared_final_origin_confirmation"
profiles$confirmation_role <- assignments$confirmation_role[
  match(profiles$screening_profile_id, assignments$screening_profile_id)
]
profiles$screening_stage <- "mcmc_nested_final_origin9000_v1"
profiles$screening_wave <- "mcmc_nested_final_origin9000_v1_2026_07_30"

cell_plan <- handoff[, c(
  "model_variant", "family", "tau", "fit_size", "likelihood_target",
  "primary_gap", "design_role"
)]
cell_plan$priority <- seq_len(nrow(cell_plan))
cell_plan$target_cell_id <- handoff$cell_key
cell_plan$cell_status <- "final_origin_confirmation"
cell_plan$target_profiles <- vapply(seq_len(nrow(cell_plan)), function(index) {
  paste(
    assignments$screening_profile_id[
      assignments$family == cell_plan$family[[index]] &
        abs(num(assignments$tau) - num(cell_plan$tau[[index]])) < 1e-12 &
        assignments$likelihood_target == cell_plan$likelihood_target[[index]]
    ],
    collapse = ","
  )
}, character(1L))
plan <- list(
  profiles = profiles,
  assignments = assignments,
  cell_plan = cell_plan,
  manifest = list(
    generated_at = as.character(Sys.time()),
    stage = stage,
    design_id = design_id,
    source_closeout_id = closeout_id,
    source_registry_hash_value = source_hash,
    n_cells = 4L,
    n_profiles = 8L,
    reservoir_seed_reps = 2L,
    mcmc_seed_reps = 2L
  )
)

base_defaults_out <- file.path(
  "config", "validation", paste0(stage, "_base_defaults.yaml")
)
defaults_out <- file.path("config", "validation", paste0(stage, "_defaults.yaml"))
profiles_out <- file.path("config", "validation", paste0(stage, "_profiles.csv"))
assignments_out <- file.path(
  "config", "validation", paste0(stage, "_cell_assignments.csv")
)
grid_out <- file.path("config", "validation", paste0(stage, "_grid.csv"))
target_specs_out <- file.path(
  "config", "validation", paste0(stage, "_target_spec_ids.csv")
)
materialization_manifest_out <- file.path(
  "config", "validation", paste0(stage, "_materialization_manifest.json")
)

base <- yaml::read_yaml(paths[["base_defaults"]])
base$source_materialization$staged_root <- file.path(
  "results", "qdesn_mcmc_validation",
  "dynamic_fitforecast_v2_qdesn_sources_nested_final_origin9000_period90_m90_w300"
)
base$source_materialization$train_end_source_index <- origin
base$source_materialization$forecast_origin_source_index <- origin
label <- "effTT500_totalTT1890_trainEnd9000_H1000_m90_w300_period90"
base$source_materialization$windows[[1L]]$source_dir_name <- paste0("fit_input_", label)
base$source_materialization$windows[[1L]]$label <- label
yaml::write_yaml(base, base_defaults_out)

exdqlm:::qdesn_dynamic_fitforecast_materialize_forecast_targeted_stage(
  plan = plan,
  base_defaults_path = base_defaults_out,
  profiles_out = profiles_out,
  assignments_out = assignments_out,
  defaults_out = defaults_out,
  grid_out = grid_out,
  workers = workers,
  refresh_grid = TRUE,
  refresh_materialized = refresh_materialized,
  stage_stub = stage,
  stage_desc = "Q-DESN/exQ-DESN nested final-origin confirmation at source origin 9000.",
  stage = "mcmc_nested_final_origin9000_v1",
  priors = "rhs_ns"
)

defaults <- yaml::read_yaml(defaults_out)
grid <- read_csv(grid_out)
if (nrow(grid) != 8L ||
    any(as.integer(grid$train_start_source_index) != 8501L) ||
    any(as.integer(grid$train_end_source_index) != 9000L) ||
    any(as.integer(grid$forecast_start_source_index) != 9001L) ||
    any(as.integer(grid$forecast_end_source_index) != 10000L)) {
  stop("Final-origin source-window materialization failed.", call. = FALSE)
}
spec_grid <- exdqlm:::qdesn_dynamic_fitforecast_atomic_spec_grid(
  grid,
  defaults,
  methods = "mcmc",
  likelihood_families = c("al", "exal")
)
assignments_local <- read_csv(assignments_out)
assignments_local$target_key <- paste(
  assignments_local$screening_profile_id,
  assignments_local$family,
  fmt_tau(assignments_local$tau),
  assignments_local$likelihood_target,
  sep = "|"
)
spec_grid$target_key <- paste(
  spec_grid$screening_profile_id,
  spec_grid$family,
  fmt_tau(spec_grid$tau),
  spec_grid$likelihood_family,
  sep = "|"
)
target_specs <- merge(
  assignments_local, spec_grid, by = "target_key", all.x = TRUE, sort = FALSE
)
if (nrow(target_specs) != 8L ||
    any(is.na(target_specs$spec_id)) ||
    anyDuplicated(target_specs$spec_id)) {
  stop("Final-origin confirmation did not produce eight unique atomic specs.", call. = FALSE)
}
write_csv(target_specs, target_specs_out)

defaults$campaign$name <- stage
defaults$campaign$results_root <- file.path("results", "qdesn_mcmc_validation", stage)
defaults$campaign$reports_root <- file.path("reports", "qdesn_mcmc_validation", stage)
defaults$execution$methods <- "mcmc"
defaults$execution$likelihood_families <- as.list(c("al", "exal"))
defaults$execution$allowed_fit_spec_ids <- as.list(as.character(target_specs$spec_id))
defaults$study_contract$id <- paste0(stage, "_2026_07_30")
defaults$study_contract$description <- paste(
  "Full-budget confirmation at the untouched source origin 9000 of four",
  "cell-specific designs selected from replicated origins 7000 and 8000."
)
defaults$study_contract$source_registry_hash_value <- source_hash
defaults$study_contract$budget$posterior_metric_draws <- 200L
defaults$study_contract$budget$mcmc_n_burn <- 5000L
defaults$study_contract$budget$mcmc_n_mcmc <- 20000L
defaults$study_contract$budget$mcmc_thin <- 1L
defaults$study_contract$confirmation_contract <- list(
  source_closeout_id = closeout_id,
  final_origin_source_index = 9000L,
  final_train_window = as.list(c(8501L, 9000L)),
  final_forecast_block = as.list(c(9001L, 10000L)),
  selected_cells = 4L,
  selected_roots = 8L,
  mcmc_seed_reps = 2L,
  planned_chain_fits = 16L,
  primary_confirmations = 3L,
  instability_sentinels = 1L,
  discovery_stability_ratio_max = 1.10,
  parent_no_material_regression_ratio_max = 1.05,
  external_competitive_ratio_max = 1.05,
  diagnostic_grade_is_reported_not_metric_suppressing = TRUE,
  article_update_is_automatic = FALSE
)
defaults$reference_contract$expected_selected_qdesn_roots <- 8L
defaults$screening_profiles$csv <- profiles_out
defaults$screening_profiles$cell_assignments_csv <- assignments_out
defaults$screening_profiles$canonical_profile_count <- 8L
defaults$screening_profiles$selected_assignment_root_count <- 8L
defaults$screening_profiles$design <- paste(
  "Eight exact final-origin roots: two frozen reservoir seeds for each of",
  "four cell-specific discovery winners."
)
defaults$runtime$threads <- 1L
defaults$runtime$workers <- workers
defaults$runtime$campaign_workers <- workers
defaults$runtime$root_scheduler <- "load_balanced"
defaults$metrics$posterior_metric_draws <- 200L
defaults$pipeline$sampling$nd_draws <- 200L
defaults$pipeline$synthesis$n_samp <- 200L
defaults$pipeline$inference$mcmc$n_burn <- 5000L
defaults$pipeline$inference$mcmc$n_mcmc <- 20000L
defaults$pipeline$inference$mcmc$thin <- 1L
defaults$pipeline$inference$mcmc$progress_every <- 50L
defaults$pipeline$inference$mcmc$init_from_vb <- TRUE
defaults$pipeline$inference$mcmc$prior_overrides$rhs_ns$n_burn <- 5000L
defaults$pipeline$inference$mcmc$prior_overrides$rhs_ns$n_mcmc <- 20000L
defaults$pipeline$inference$mcmc$prior_overrides$rhs_ns$progress_every <- 50L
defaults$pipeline$outputs$keep_draws <- FALSE
defaults$pipeline$outputs$keep_mcmc_vb_init <- FALSE
defaults$pipeline$outputs$save_forecast_objects <- FALSE
defaults$pipeline$outputs$save_compact_fit_paths <- TRUE
defaults$pipeline$outputs$save_metric_summaries <- TRUE
defaults$pipeline$outputs$retain_full_rds_on_failure <- FALSE
defaults$pipeline$outputs$retention_profile <- "storage_light_final_confirmation"
defaults$multiseed$enabled <- TRUE
defaults$multiseed$mcmc_seed_reps <- 2L
defaults$multiseed$parallel_seed_workers <- 1L
defaults$multiseed$selection_metric <- "train_qtrue_rmse"
defaults$multiseed$prune_nonwinning_heavy_outputs <- TRUE
defaults$multiseed$prune_rel_paths <- as.list(c(
  "models/forecast_objects.rds",
  "models/rhs_trace.rds",
  "models/timing_summary.rds"
))
smoke_index <- which(assignments_local$confirmation_role == "primary_confirmation")[[1L]]
defaults$smoke$family <- assignments_local$family[[smoke_index]]
defaults$smoke$tau <- num(assignments_local$tau[[smoke_index]])
defaults$smoke$fit_sizes <- 500L
defaults$smoke$priors <- as.list("rhs_ns")
defaults$smoke$max_roots <- 1L
defaults$smoke$screening_profile_ids <- as.list(
  assignments_local$screening_profile_id[[smoke_index]]
)
defaults$smoke$budget$mcmc_n_burn <- 4L
defaults$smoke$budget$mcmc_n_mcmc <- 4L
defaults$smoke$budget$mcmc_thin <- 1L
defaults$smoke$pipeline$inference$mcmc$n_burn <- 4L
defaults$smoke$pipeline$inference$mcmc$n_mcmc <- 4L
defaults$smoke$pipeline$inference$mcmc$thin <- 1L
defaults$smoke$pipeline$inference$mcmc$progress_every <- 1L
yaml::write_yaml(defaults, defaults_out)

origin_stability_path <- write_csv(
  origin_stability, file.path(design_root, "originwise_stability_audit.csv")
)
stability_summary_path <- write_csv(
  stability_by_cell, file.path(design_root, "originwise_stability_summary.csv")
)
selected_profiles_path <- write_csv(
  profiles, file.path(design_root, "selected_profiles.csv")
)
selected_assignments_path <- write_csv(
  assignments_local, file.path(design_root, "selected_assignments.csv")
)
contract <- data.frame(
  design_id = design_id,
  stage = stage,
  source_registry_hash_value = source_hash,
  source_closeout_id = closeout_id,
  final_origin_source_index = 9000L,
  train_start_source_index = 8501L,
  train_end_source_index = 9000L,
  forecast_start_source_index = 9001L,
  forecast_end_source_index = 10000L,
  selected_cells = 4L,
  selected_roots = 8L,
  reservoir_seed_reps = 2L,
  mcmc_seed_reps = 2L,
  planned_chain_fits = 16L,
  mcmc_n_burn = 5000L,
  mcmc_n_mcmc = 20000L,
  posterior_metric_draws = 200L,
  workers_cap = workers,
  article_update_policy = "manual_after_final_closeout_only",
  stringsAsFactors = FALSE
)
contract_path <- write_csv(contract, file.path(design_root, "confirmation_contract.csv"))

source_manifest <- data.frame(
  role = names(paths),
  path = unname(paths),
  sha256 = vapply(unname(paths), sha256, character(1L)),
  stringsAsFactors = FALSE
)
source_manifest_path <- write_csv(
  source_manifest, file.path(design_root, "source_manifest.csv")
)
tracked_paths <- c(
  base_defaults_out, defaults_out, profiles_out, assignments_out, grid_out,
  target_specs_out, paths[["documentation"]],
  "validation/fitforecast_v2/scripts/materialize_qdesn_mcmc_nested_final_origin_20260730.R",
  "scripts/orchestrate_qdesn_500obs_mcmc_nested_final_origin_v1.R",
  "scripts/closeout_qdesn_500obs_mcmc_nested_final_origin_v1.R",
  "validation/fitforecast_v2/tests/testthat/test-qdesn-mcmc-nested-final-origin-v1.R",
  origin_stability_path, stability_summary_path, selected_profiles_path,
  selected_assignments_path, contract_path, source_manifest_path
)
tracked_paths <- unique(vapply(tracked_paths, resolve_path, character(1L)))
file_manifest <- data.frame(
  path = tracked_paths,
  size_bytes = file.info(tracked_paths)$size,
  sha256 = vapply(tracked_paths, sha256, character(1L)),
  stringsAsFactors = FALSE
)
file_manifest_path <- write_csv(
  file_manifest, file.path(design_root, "file_manifest.csv")
)
manifest <- list(
  generated_at = as.character(Sys.time()),
  design_id = design_id,
  stage = stage,
  source_registry_hash_value = source_hash,
  source_closeout_id = closeout_id,
  selected_cells = 4L,
  selected_roots = 8L,
  planned_chain_fits = 16L,
  primary_confirmations = 3L,
  instability_sentinels = 1L,
  origin = 9000L,
  file_manifest = file_manifest_path,
  source_manifest = source_manifest_path,
  article_update_policy = "manual_after_final_closeout_only"
)
manifest_path <- write_json(
  manifest, file.path(design_root, paste0(design_id, "_manifest.json"))
)
write_json(
  list(
    generated_at = as.character(Sys.time()),
    stage = stage,
    design_id = design_id,
    source_registry_hash_value = source_hash,
    defaults_path = resolve_path(defaults_out),
    grid_path = resolve_path(grid_out),
    target_specs_path = resolve_path(target_specs_out),
    selected_roots = 8L,
    planned_chain_fits = 16L,
    design_manifest = manifest_path
  ),
  materialization_manifest_out
)

heavy <- list.files(
  design_root,
  pattern = "[.](rds|rda|RData)$|__design[.]rds$",
  recursive = TRUE,
  full.names = TRUE,
  ignore.case = TRUE
)
if (length(heavy)) {
  stop("Forbidden heavy payload found in the final-confirmation design root.", call. = FALSE)
}

cat(sprintf("design_root: %s\n", resolve_path(design_root)))
cat(sprintf("design_manifest: %s\n", manifest_path))
cat("selected_cells: 4\n")
cat("selected_roots: 8\n")
cat("planned_chain_fits: 16\n")
cat("primary_confirmations: 3\n")
cat("instability_sentinels: 1\n")

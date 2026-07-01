#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  req <- c("jsonlite", "pkgload", "yaml")
  need <- setdiff(req, rownames(installed.packages()))
  if (length(need)) install.packages(need, repos = "https://cloud.r-project.org")
  invisible(lapply(req, require, character.only = TRUE))
})

args <- commandArgs(trailingOnly = TRUE)
get_arg <- function(flag, default = NULL) {
  idx <- which(args == flag)
  if (!length(idx)) return(default)
  idx <- idx[[1L]]
  if (idx >= length(args)) return(default)
  args[[idx + 1L]]
}
has_flag <- function(flag) any(args == flag)
`%||%` <- function(a, b) if (is.null(a)) b else a

repo_root <- tryCatch(
  normalizePath(system("git rev-parse --show-toplevel", intern = TRUE), winslash = "/", mustWork = TRUE),
  error = function(...) normalizePath(".", winslash = "/", mustWork = TRUE)
)
setwd(repo_root)
pkgload::load_all(repo_root, quiet = TRUE)

resolve_path <- function(path, must_work = TRUE) {
  raw <- as.character(path %||% "")[1L]
  if (!nzchar(trimws(raw))) return(NULL)
  if (!grepl("^(/|~)", raw)) raw <- file.path(repo_root, raw)
  normalizePath(raw, winslash = "/", mustWork = isTRUE(must_work))
}
int_arg <- function(flag, default) {
  val <- suppressWarnings(as.integer(get_arg(flag, as.character(default)))[1L])
  if (is.finite(val)) val else as.integer(default)
}

stage_file <- "qdesn_dynamic_fitforecast_v2_tt500_ridge_corrected_desn"
screening_wave <- as.character(get_arg("--screening-wave", paste0("ridge_corrected_desn_", format(Sys.Date(), "%Y_%m_%d"))))[1L]
workers <- int_arg("--workers", 18L)
refresh_grid <- !has_flag("--no-refresh-grid")
refresh_materialized <- has_flag("--refresh-materialized")

base_defaults_path <- resolve_path(
  get_arg("--base-defaults", file.path("config", "validation", "qdesn_dynamic_fitforecast_v2_tt500_vb_stage4_remaining_cells_transfer_defaults.yaml")),
  must_work = TRUE
)
source_profile_paths <- vapply(
  c(
    get_arg("--stage3-profiles", file.path("config", "validation", "qdesn_dynamic_fitforecast_v2_tt500_vb_stage3_forecast_bias_rescue_profiles.csv")),
    get_arg("--stage4a-profiles", file.path("config", "validation", "qdesn_dynamic_fitforecast_v2_tt500_vb_stage4_remaining_cells_transfer_profiles.csv")),
    get_arg("--stage4b-profiles", file.path("config", "validation", "qdesn_dynamic_fitforecast_v2_tt500_vb_stage4b_gausmix005_pinball_refinement_profiles.csv"))
  ),
  resolve_path,
  must_work = TRUE,
  FUN.VALUE = character(1)
)
winners_out <- resolve_path(get_arg("--winners-out", file.path("config", "validation", paste0(stage_file, "_winners.csv"))), must_work = FALSE)
profiles_out <- resolve_path(get_arg("--profiles-out", file.path("config", "validation", paste0(stage_file, "_profiles.csv"))), must_work = FALSE)
assignments_out <- resolve_path(get_arg("--assignments-out", file.path("config", "validation", paste0(stage_file, "_cell_assignments.csv"))), must_work = FALSE)
defaults_out <- resolve_path(get_arg("--defaults-out", file.path("config", "validation", paste0(stage_file, "_defaults.yaml"))), must_work = FALSE)
grid_out <- resolve_path(get_arg("--grid-out", file.path("config", "validation", paste0(stage_file, "_grid.csv"))), must_work = FALSE)
manifest_path <- resolve_path(get_arg("--manifest-out", file.path("config", "validation", paste0(stage_file, "_materialization_manifest.json"))), must_work = FALSE)
diagnostic_out <- resolve_path(get_arg("--diagnostic-out", file.path("reports", "qdesn_mcmc_validation", stage_file, "materialization_diagnostics")), must_work = FALSE)

winner_rows <- data.frame(
  family = c("gausmix", "gausmix", "gausmix", "laplace", "laplace", "laplace", "normal", "normal", "normal"),
  tau = c(0.05, 0.25, 0.50, 0.05, 0.25, 0.50, 0.05, 0.25, 0.50),
  screening_profile_id = c(
    "tt500vb_f3_d2_n20_a0p05_r0p6_m15_lag15_rl0_pw0p03_pin0p3",
    "tt500vb_f3_d1_n30_a0p02_r0p45_m15_lag15_rl0_pw0p03_pin0p3",
    "tt500vb_f3_d1_n30_a0p03_r0p5_m15_lag15_rl0_pw0p03_pin0p3",
    "tt500vb_f3_d1_n30_a0p02_r0p45_m15_lag15_rl0_pw0p03_pin0p3",
    "tt500vb_f3_d1_n30_a0p02_r0p45_m15_lag15_rl0_pw0p03_pin0p3",
    "tt500vb_f3_d1_n30_a0p02_r0p45_m15_lag15_rl0_pw0p03_pin0p3",
    "tt500vb_f3_d1_n30_a0p02_r0p45_m15_lag15_rl0_pw0p03_pin0p3",
    "tt500vb_f3_d1_n30_a0p02_r0p45_m15_lag15_rl0_pw0p03_pin0p3",
    "tt500vb_f3_d1_n30_a0p02_r0p45_m15_lag15_rl0_pw0p03_pin0p3"
  ),
  selection_source = c("stage4b", "stage3_article_promoted", "stage4a", "stage4a", "stage4a", "stage4a", "stage4a", "stage3_article_promoted", "stage3_article_promoted"),
  cell_status = c("extreme_hard", "confirmed_vb_promoted", "confirmed_vb_promoted", "confirmed_vb_promoted", "confirmed_vb_promoted", "confirmed_vb_promoted", "confirmed_vb_promoted", "confirmed_vb_promoted", "confirmed_vb_promoted"),
  stringsAsFactors = FALSE
)
winner_rows$priority_rank <- seq_len(nrow(winner_rows))
winner_rows$target_profile_rank <- 1L
winner_rows$assignment_id <- sprintf("ridge_corrected_cell_%04d", seq_len(nrow(winner_rows)))
winner_rows$assignment_key <- paste(
  winner_rows$screening_profile_id,
  winner_rows$family,
  exdqlm:::.qdesn_dynamic_fitforecast_tau_key(winner_rows$tau),
  sep = "\r"
)

source_profiles <- exdqlm:::.qdesn_validation_bind_rows(lapply(source_profile_paths, function(path) {
  utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
}))
profile_ids <- unique(winner_rows$screening_profile_id)
profiles <- source_profiles[match(profile_ids, as.character(source_profiles$screening_profile_id)), , drop = FALSE]
missing_profiles <- profile_ids[is.na(match(profile_ids, as.character(source_profiles$screening_profile_id)))]
if (length(missing_profiles)) {
  stop(sprintf("Missing corrected DESN profile(s): %s", paste(missing_profiles, collapse = ", ")), call. = FALSE)
}
profiles$enabled <- TRUE
profiles$screening_stage <- "ridge_corrected_desn"
profiles$screening_wave <- screening_wave
profiles$profile_role <- "ridge_corrected_desn_relaunch"
rownames(profiles) <- NULL

cell_plan <- winner_rows[, c("family", "tau", "cell_status", "priority_rank", "screening_profile_id", "selection_source"), drop = FALSE]
cell_plan$target_profiles <- cell_plan$screening_profile_id
cell_plan$bottleneck_metric <- ifelse(cell_plan$family == "gausmix" & abs(cell_plan$tau - 0.05) < 1e-8, "legacy_ridge_extreme_pathology", "legacy_ridge_pathology")
cell_plan$primary_worst_ratio_vs_baseline <- NA_real_

assignments <- winner_rows[, c(
  "assignment_key", "family", "tau", "cell_status", "priority_rank",
  "target_profile_rank", "screening_profile_id", "selection_source",
  "assignment_id"
), drop = FALSE]
assignments$source_profile <- assignments$selection_source
assignments$source_worst_ratio <- NA_real_
assignments$bottleneck_metric <- cell_plan$bottleneck_metric
assignments <- assignments[, c(
  "assignment_key", "family", "tau", "cell_status", "priority_rank",
  "target_profile_rank", "screening_profile_id", "source_profile",
  "source_worst_ratio", "bottleneck_metric", "assignment_id"
), drop = FALSE]

plan <- list(
  profiles = profiles,
  assignments = assignments,
  cell_plan = cell_plan,
  manifest = list(
    generated_at = as.character(Sys.time()),
    stage = stage_file,
    n_winner_cells = nrow(winner_rows),
    n_profiles = nrow(profiles),
    prior = "ridge",
    screening_wave = screening_wave,
    source_profile_paths = as.list(source_profile_paths)
  )
)

diag_tables <- file.path(diagnostic_out, "tables")
diag_summary <- file.path(diagnostic_out, "summary")
diag_manifest <- file.path(diagnostic_out, "manifest")
dir.create(diag_tables, recursive = TRUE, showWarnings = FALSE)
dir.create(diag_summary, recursive = TRUE, showWarnings = FALSE)
dir.create(diag_manifest, recursive = TRUE, showWarnings = FALSE)

exdqlm:::.qdesn_validation_write_df(winner_rows, winners_out)
exdqlm:::.qdesn_validation_write_df(winner_rows, file.path(diag_tables, "qdesn_tt500_ridge_corrected_desn_winners.csv"))

mat <- exdqlm:::qdesn_dynamic_fitforecast_materialize_forecast_targeted_stage(
  plan = plan,
  base_defaults_path = base_defaults_path,
  profiles_out = profiles_out,
  assignments_out = assignments_out,
  defaults_out = defaults_out,
  grid_out = grid_out,
  workers = workers,
  refresh_grid = refresh_grid,
  refresh_materialized = refresh_materialized,
  stage_stub = stage_file,
  stage_desc = "Q-DESN TT500 ridge relaunch using the corrected per-cell DESN profile map.",
  stage = "ridge_corrected_desn",
  priors = "ridge"
)

defaults <- yaml::read_yaml(defaults_out)
defaults$campaign$name <- stage_file
defaults$campaign$results_root <- file.path("results", "qdesn_mcmc_validation", stage_file)
defaults$campaign$reports_root <- file.path("reports", "qdesn_mcmc_validation", stage_file)
defaults$execution$methods <- c("vb", "mcmc")
defaults$execution$likelihood_families <- c("al", "exal")
defaults$study_contract$id <- paste0(stage_file, "_", format(Sys.Date(), "%Y_%m_%d"))
defaults$study_contract$description <- "Q-DESN TT500 ridge relaunch using corrected per-cell DESN profiles, shared v2 sources, one-core workers, storage-light outputs, and explicit promotion gates."
defaults$study_contract$budget$posterior_metric_draws <- 200L
defaults$study_contract$budget$vb_sampling_nd_draws <- 200L
defaults$study_contract$budget$vb_synthesis_n_samp <- 200L
defaults$study_contract$budget$mcmc_n_burn <- 5000L
defaults$study_contract$budget$mcmc_n_mcmc <- 20000L
defaults$study_contract$budget$mcmc_thin <- 1L
defaults$reference_contract$expected_unique_dataset_cells <- 9L
defaults$reference_contract$expected_qdesn_roots <- 27L
defaults$reference_contract$expected_selected_qdesn_roots <- 9L
defaults$reference_contract$expected_priors <- "ridge"
defaults$screening_profiles$canonical_profile_count <- nrow(profiles)
defaults$screening_profiles$canonical_qdesn_root_count <- 27L
defaults$screening_profiles$selected_assignment_root_count <- 9L
defaults$screening_profiles$priors <- "ridge"
defaults$screening_profiles$design <- sprintf(
  "Q-DESN TT500 ridge relaunch from frozen corrected per-cell DESN profiles. Profiles: %d; selected assignments: 9; prior: ridge.",
  nrow(profiles)
)
defaults$runtime$threads <- 1L
defaults$runtime$campaign_workers <- workers
defaults$runtime$workers <- workers
defaults$runtime$root_scheduler <- "load_balanced"
defaults$smoke$scenario <- "dlm_constV_p90_m0amp_highnoise_steepertrend_v2_TTmain10000_fitforecast"
defaults$smoke$family <- "gausmix"
defaults$smoke$tau <- 0.05
defaults$smoke$fit_sizes <- 500L
defaults$smoke$priors <- "ridge"
defaults$smoke$max_roots <- 1L
defaults$pilot$beta_prior_type <- "ridge"
defaults$pipeline$inference$vb$max_iter <- 150L
defaults$pipeline$inference$vb$min_iter_elbo <- 40L
defaults$pipeline$inference$vb$n_samp_xi <- 500L
defaults$pipeline$inference$vb$progress_every <- 50L
defaults$pipeline$inference$vb$prior_overrides$ridge$max_iter <- 150L
defaults$pipeline$inference$vb$prior_overrides$ridge$min_iter_elbo <- 40L
defaults$pipeline$inference$vb$prior_overrides$ridge$n_samp_xi <- 500L
defaults$pipeline$inference$mcmc$n_burn <- 5000L
defaults$pipeline$inference$mcmc$n_mcmc <- 20000L
defaults$pipeline$inference$mcmc$thin <- 1L
defaults$pipeline$inference$mcmc$progress_every <- 50L
defaults$pipeline$inference$mcmc$init_from_vb <- TRUE
defaults$pipeline$inference$mcmc$prior_overrides$ridge$n_burn <- 5000L
defaults$pipeline$inference$mcmc$prior_overrides$ridge$n_mcmc <- 20000L
defaults$pipeline$inference$mcmc$prior_overrides$ridge$progress_every <- 50L
defaults$pipeline$inference$mcmc$vb_warm_start_control$progress_every <- 50L
defaults$multiseed <- list(
  enabled = FALSE,
  mcmc_seed_reps = 1L,
  parallel_seed_workers = 1L,
  selection_metric = "forecast_pinball_mean",
  prune_nonwinning_heavy_outputs = TRUE
)
defaults$pipeline$outputs$keep_draws <- FALSE
defaults$pipeline$outputs$save_forecast_objects <- FALSE
defaults$pipeline$outputs$save_compact_fit_paths <- TRUE
defaults$pipeline$outputs$retain_full_rds_on_failure <- FALSE
yaml::write_yaml(defaults, defaults_out)

grid <- if (file.exists(grid_out)) utils::read.csv(grid_out, stringsAsFactors = FALSE, check.names = FALSE) else data.frame()
if (nrow(grid) != 9L) stop(sprintf("Expected 9 generated ridge corrected grid rows; observed %d.", nrow(grid)), call. = FALSE)
if (!identical(sort(unique(as.character(grid$beta_prior_type))), "ridge")) {
  stop("Generated ridge corrected grid does not contain exactly beta_prior_type = 'ridge'.", call. = FALSE)
}
if (any(grepl("/home/jaguir26/local/src", as.matrix(grid), fixed = TRUE))) {
  stop("Generated ridge corrected grid contains stale /home/jaguir26/local/src paths.", call. = FALSE)
}
if (!all(as.integer(grid$train_start_source_index) == 8501L) ||
    !all(as.integer(grid$train_end_source_index) == 9000L) ||
    !all(as.integer(grid$forecast_start_source_index) == 9001L) ||
    !all(as.integer(grid$forecast_end_source_index) == 10000L)) {
  stop("Generated ridge corrected grid does not match the TT500 v2 source-window contract.", call. = FALSE)
}
assignments_after <- utils::read.csv(assignments_out, stringsAsFactors = FALSE, check.names = FALSE)
if (nrow(assignments_after) != 9L || any(is.na(assignments_after$root_id)) || any(!nzchar(assignments_after$root_id))) {
  stop("Ridge corrected assignment materialization did not produce exactly 9 concrete root IDs.", call. = FALSE)
}

summary_lines <- c(
  "# Q-DESN TT500 Ridge Corrected DESN Materialization",
  "",
  sprintf("- generated_at: `%s`", as.character(Sys.time())),
  sprintf("- stage_file: `%s`", stage_file),
  sprintf("- prior: `%s`", "ridge"),
  sprintf("- base_defaults_path: `%s`", base_defaults_path),
  sprintf("- winners: `%s`", winners_out),
  sprintf("- profiles: `%s`", profiles_out),
  sprintf("- assignments: `%s`", assignments_out),
  sprintf("- defaults: `%s`", defaults_out),
  sprintf("- grid: `%s`", grid_out),
  sprintf("- manifest: `%s`", manifest_path),
  sprintf("- workers: `%d`", workers),
  sprintf("- n_profiles: `%d`", nrow(profiles)),
  sprintf("- n_assignments: `%d`", nrow(assignments_after)),
  sprintf("- n_grid_rows: `%d`", nrow(grid)),
  "",
  "This materialization freezes the nine Q-DESN TT500 ridge roots that reuse the corrected per-cell DESN profile map.",
  "It is intended to replace only the stale Article-facing ridge lanes after smoke, pilot, full run, and promotion audits pass."
)
exdqlm:::.qdesn_validation_write_lines(file.path(diag_summary, "qdesn_tt500_ridge_corrected_desn.md"), summary_lines)

manifest <- list(
  generated_at = as.character(Sys.time()),
  stage = stage_file,
  prior = "ridge",
  base_defaults_path = base_defaults_path,
  outputs = list(
    winners = winners_out,
    profiles = profiles_out,
    assignments = assignments_out,
    defaults = defaults_out,
    grid = grid_out,
    diagnostics = diagnostic_out
  ),
  source_profile_paths = as.list(source_profile_paths),
  workers = workers,
  refresh_grid = refresh_grid,
  refresh_materialized = refresh_materialized,
  n_profiles = nrow(profiles),
  n_assignments = nrow(assignments_after),
  n_grid_rows = nrow(grid),
  grid_summary = list(
    source_scenarios = as.list(sort(unique(as.character(grid$source_scenario)))),
    families = as.list(sort(unique(as.character(grid$source_family)))),
    taus = as.list(sort(unique(as.numeric(grid$tau)))),
    priors = as.list(sort(unique(as.character(grid$beta_prior_type)))),
    train_start_source_index = unique(as.integer(grid$train_start_source_index)),
    train_end_source_index = unique(as.integer(grid$train_end_source_index)),
    forecast_start_source_index = unique(as.integer(grid$forecast_start_source_index)),
    forecast_end_source_index = unique(as.integer(grid$forecast_end_source_index))
  ),
  materialized = mat
)
jsonlite::write_json(manifest, manifest_path, pretty = TRUE, auto_unbox = TRUE, null = "null")
jsonlite::write_json(manifest, file.path(diag_manifest, "qdesn_tt500_ridge_corrected_desn_manifest.json"), pretty = TRUE, auto_unbox = TRUE, null = "null")

cat(sprintf("ridge_corrected_defaults: %s\n", defaults_out))
cat(sprintf("ridge_corrected_grid: %s\n", grid_out))
cat(sprintf("ridge_corrected_manifest: %s\n", manifest_path))
cat(sprintf("ridge_corrected_roots: %d\n", nrow(grid)))

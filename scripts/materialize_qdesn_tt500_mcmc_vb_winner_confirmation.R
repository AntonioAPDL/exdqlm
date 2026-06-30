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

stage_file <- "qdesn_dynamic_fitforecast_v2_tt500_mcmc_vb_winner_confirmation"
screening_wave <- as.character(get_arg("--screening-wave", paste0("mcmc_vb_winner_confirmation_", format(Sys.Date(), "%Y_%m_%d"))))[1L]
workers <- int_arg("--workers", 9L)
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
winner_rows$assignment_id <- sprintf("mcmc_vbwin_cell_%04d", seq_len(nrow(winner_rows)))
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
  stop(sprintf("Missing winner profile(s): %s", paste(missing_profiles, collapse = ", ")), call. = FALSE)
}
profiles$enabled <- TRUE
profiles$screening_stage <- "mcmc_vb_winner_confirmation"
profiles$screening_wave <- screening_wave
profiles$profile_role <- "mcmc_confirmation_winner"
rownames(profiles) <- NULL

cell_plan <- winner_rows[, c("family", "tau", "cell_status", "priority_rank", "screening_profile_id", "selection_source"), drop = FALSE]
cell_plan$target_profiles <- cell_plan$screening_profile_id
cell_plan$bottleneck_metric <- ifelse(cell_plan$family == "gausmix" & abs(cell_plan$tau - 0.05) < 1e-8, "forecast_pinball", "promoted_vb_winner")
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
exdqlm:::.qdesn_validation_write_df(winner_rows, file.path(diag_tables, "qdesn_tt500_mcmc_vb_winner_confirmation_winners.csv"))

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
  stage_desc = "Q-DESN TT500 MCMC confirmation of the frozen per-cell VB winner set.",
  stage = "mcmc_vb_winner_confirmation"
)

defaults <- yaml::read_yaml(defaults_out)
defaults$campaign$name <- stage_file
defaults$campaign$results_root <- file.path("results", "qdesn_mcmc_validation", stage_file)
defaults$campaign$reports_root <- file.path("reports", "qdesn_mcmc_validation", stage_file)
defaults$execution$methods <- "mcmc"
defaults$execution$likelihood_families <- "exal"
defaults$study_contract$id <- paste0(stage_file, "_", format(Sys.Date(), "%Y_%m_%d"))
defaults$study_contract$description <- "Q-DESN TT500 MCMC confirmation of the frozen Article-facing per-cell VB winner set. This lane is reproducible, storage-light, and article-facing only after strict audit."
defaults$study_contract$budget$posterior_metric_draws <- 200L
defaults$study_contract$budget$vb_sampling_nd_draws <- 200L
defaults$study_contract$budget$vb_synthesis_n_samp <- 200L
defaults$study_contract$budget$mcmc_n_burn <- 5000L
defaults$study_contract$budget$mcmc_n_mcmc <- 20000L
defaults$study_contract$budget$mcmc_thin <- 1L
defaults$reference_contract$expected_unique_dataset_cells <- 9L
defaults$reference_contract$expected_qdesn_roots <- 27L
defaults$reference_contract$expected_selected_qdesn_roots <- 9L
defaults$screening_profiles$canonical_profile_count <- nrow(profiles)
defaults$screening_profiles$canonical_qdesn_root_count <- 27L
defaults$screening_profiles$selected_assignment_root_count <- 9L
defaults$screening_profiles$design <- sprintf(
  "Q-DESN TT500 MCMC confirmation of frozen per-cell VB winners. Profiles: %d; selected assignments: 9.",
  nrow(profiles)
)
defaults$runtime$threads <- 1L
defaults$runtime$campaign_workers <- workers
defaults$runtime$workers <- workers
defaults$runtime$root_scheduler <- "load_balanced"
defaults$smoke$family <- "gausmix"
defaults$smoke$tau <- 0.05
defaults$smoke$max_roots <- 1L
defaults$pipeline$inference$mcmc$n_burn <- 5000L
defaults$pipeline$inference$mcmc$n_mcmc <- 20000L
defaults$pipeline$inference$mcmc$thin <- 1L
defaults$pipeline$inference$mcmc$progress_every <- 50L
defaults$pipeline$inference$mcmc$init_from_vb <- TRUE
defaults$pipeline$inference$mcmc$prior_overrides$rhs_ns$n_burn <- 5000L
defaults$pipeline$inference$mcmc$prior_overrides$rhs_ns$n_mcmc <- 20000L
defaults$pipeline$inference$mcmc$prior_overrides$rhs_ns$progress_every <- 50L
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
if (nrow(grid) != 9L) stop(sprintf("Expected 9 generated MCMC winner grid rows; observed %d.", nrow(grid)), call. = FALSE)
assignments_after <- utils::read.csv(assignments_out, stringsAsFactors = FALSE, check.names = FALSE)
if (nrow(assignments_after) != 9L || any(is.na(assignments_after$root_id)) || any(!nzchar(assignments_after$root_id))) {
  stop("Assignment materialization did not produce exactly 9 concrete root IDs.", call. = FALSE)
}

summary_lines <- c(
  "# Q-DESN TT500 MCMC VB-Winner Confirmation Materialization",
  "",
  sprintf("- generated_at: `%s`", as.character(Sys.time())),
  sprintf("- stage_file: `%s`", stage_file),
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
  "This materialization freezes the nine Article-facing Q-DESN exAL RHS VB winner roots for MCMC confirmation."
)
exdqlm:::.qdesn_validation_write_lines(file.path(diag_summary, "qdesn_tt500_mcmc_vb_winner_confirmation.md"), summary_lines)

manifest <- list(
  generated_at = as.character(Sys.time()),
  stage = stage_file,
  base_defaults_path = base_defaults_path,
  outputs = list(
    winners = winners_out,
    profiles = profiles_out,
    assignments = assignments_out,
    defaults = defaults_out,
    grid = grid_out,
    diagnostics = diagnostic_out
  ),
  materialized = mat,
  n_profiles = nrow(profiles),
  n_assignments = nrow(assignments_after),
  n_grid_rows = nrow(grid),
  roots = as.list(as.character(assignments_after$root_id)),
  file_manifest = exdqlm:::qdesn_validation_file_manifest(c(
    winners_out, profiles_out, assignments_out, defaults_out, grid_out,
    file.path(diag_summary, "qdesn_tt500_mcmc_vb_winner_confirmation.md")
  ))
)
exdqlm:::.qdesn_validation_write_json(file.path(diag_manifest, "qdesn_tt500_mcmc_vb_winner_confirmation_manifest.json"), manifest)
exdqlm:::.qdesn_validation_write_json(manifest_path, manifest)

cat(sprintf("winners: %s\n", winners_out))
cat(sprintf("profiles: %s\n", profiles_out))
cat(sprintf("assignments: %s\n", assignments_out))
cat(sprintf("defaults: %s\n", defaults_out))
cat(sprintf("grid: %s\n", grid_out))
cat(sprintf("manifest: %s\n", manifest_path))
cat(sprintf("n_profiles: %d\n", nrow(profiles)))
cat(sprintf("n_assignments: %d\n", nrow(assignments_after)))
cat(sprintf("n_grid_rows: %d\n", nrow(grid)))

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
tau_key <- function(x) sprintf("%.8f", as.numeric(x))

stage_file <- "qdesn_dynamic_fitforecast_v2_tt500_mcmc_al_rhs_recalibration"
screening_wave <- as.character(get_arg("--screening-wave", paste0("mcmc_al_rhs_recalibration_", format(Sys.Date(), "%Y_%m_%d"))))[1L]
workers <- min(int_arg("--workers", 9L), 9L)
refresh_grid <- !has_flag("--no-refresh-grid")
refresh_materialized <- has_flag("--refresh-materialized")

promotion_summary_path <- resolve_path(
  get_arg(
    "--promotion-summary",
    file.path(
      "validation", "fitforecast_v2", "promotions",
      "qdesn_tt500_al_rhs_recalibrated_candidate_20260701",
      "qdesn_tt500_al_rhs_recalibrated_candidate_20260701_summary.csv"
    )
  ),
  must_work = TRUE
)
source_profiles_path <- resolve_path(
  get_arg("--source-profiles", file.path("config", "validation", "qdesn_dynamic_fitforecast_v2_tt500_vb_al_rhs_recalibration_profiles.csv")),
  must_work = TRUE
)
base_defaults_path <- resolve_path(
  get_arg("--base-defaults", file.path("config", "validation", "qdesn_dynamic_fitforecast_v2_tt500_mcmc_vb_winner_confirmation_defaults.yaml")),
  must_work = TRUE
)
winners_out <- resolve_path(get_arg("--winners-out", file.path("config", "validation", paste0(stage_file, "_winners.csv"))), must_work = FALSE)
profiles_out <- resolve_path(get_arg("--profiles-out", file.path("config", "validation", paste0(stage_file, "_profiles.csv"))), must_work = FALSE)
assignments_out <- resolve_path(get_arg("--assignments-out", file.path("config", "validation", paste0(stage_file, "_cell_assignments.csv"))), must_work = FALSE)
defaults_out <- resolve_path(get_arg("--defaults-out", file.path("config", "validation", paste0(stage_file, "_defaults.yaml"))), must_work = FALSE)
grid_out <- resolve_path(get_arg("--grid-out", file.path("config", "validation", paste0(stage_file, "_grid.csv"))), must_work = FALSE)
manifest_path <- resolve_path(get_arg("--manifest-out", file.path("config", "validation", paste0(stage_file, "_materialization_manifest.json"))), must_work = FALSE)
diagnostic_out <- resolve_path(get_arg("--diagnostic-out", file.path("reports", "qdesn_mcmc_validation", stage_file, "materialization_diagnostics")), must_work = FALSE)

promotion <- utils::read.csv(promotion_summary_path, stringsAsFactors = FALSE, check.names = FALSE)
profiles_src <- utils::read.csv(source_profiles_path, stringsAsFactors = FALSE, check.names = FALSE)
required_promotion <- c(
  "family", "tau", "screening_profile_id", "model_key", "inference", "method",
  "qdesn_likelihood", "prior", "status", "signoff_grade", "diagnostic_qualification",
  "fit_size", "source_registry_hash_value"
)
missing_promotion <- setdiff(required_promotion, names(promotion))
if (length(missing_promotion)) {
  stop(sprintf("Promotion summary missing column(s): %s", paste(missing_promotion, collapse = ", ")), call. = FALSE)
}
if (nrow(promotion) != 9L ||
    any(as.character(promotion$model_key) != "qdesn_al_rhs_ns") ||
    any(as.character(promotion$inference) != "vb") ||
    any(as.character(promotion$method) != "vb") ||
    any(as.character(promotion$qdesn_likelihood) != "al") ||
    any(as.character(promotion$prior) != "rhs_ns") ||
    any(as.character(promotion$status) != "SUCCESS") ||
    any(as.character(promotion$signoff_grade) != "PASS") ||
    any(as.character(promotion$diagnostic_qualification) != "diagnostic_pass") ||
    any(as.integer(promotion$fit_size) != 500L)) {
  stop("AL RHS promotion summary does not satisfy the expected nine-row VB winner contract.", call. = FALSE)
}

winner_rows <- promotion[order(promotion$family, as.numeric(promotion$tau)), , drop = FALSE]
winner_rows$priority_rank <- seq_len(nrow(winner_rows))
winner_rows$target_profile_rank <- 1L
winner_rows$cell_status <- "vb_recalibrated_pass"
winner_rows$selection_source <- "qdesn_tt500_al_rhs_recalibrated_candidate_20260701"
winner_rows$assignment_id <- sprintf("mcmc_alrhs_cell_%04d", seq_len(nrow(winner_rows)))
winner_rows$assignment_key <- paste(winner_rows$screening_profile_id, winner_rows$family, tau_key(winner_rows$tau), sep = "\r")

profile_ids <- unique(as.character(winner_rows$screening_profile_id))
idx <- match(profile_ids, as.character(profiles_src$screening_profile_id))
if (anyNA(idx)) {
  stop(sprintf("Missing AL RHS source profile(s): %s", paste(profile_ids[is.na(idx)], collapse = ", ")), call. = FALSE)
}
profiles <- profiles_src[idx, , drop = FALSE]
profiles$enabled <- TRUE
profiles$screening_stage <- "mcmc_al_rhs_recalibration"
profiles$screening_wave <- screening_wave
profiles$profile_role <- "mcmc_al_rhs_from_recalibrated_vb_winner"
profiles$target_cells <- paste(paste(winner_rows$family, sprintf("%.2f", as.numeric(winner_rows$tau)), sep = ":"), collapse = ";")
profiles$target_cell_statuses <- "vb_recalibrated_pass"
rownames(profiles) <- NULL
if ("rhs_tau0" %in% names(profiles) && any(as.numeric(profiles$rhs_tau0) == 3e-05)) {
  stop("Refusing to promote unstable rhs_tau0=3e-05 profile(s) into MCMC repair.", call. = FALSE)
}

profile_contract_cols <- intersect(
  c(
    "screening_profile_id", "D", "n_each", "n_tilde_each", "m",
    "alpha", "rho", "pi_w", "pi_in", "washout", "add_bias", "seed",
    "readout_y_lags", "reservoir_lags", "rhs_tau0",
    "dimension_p_estimate", "p_over_n_tt500"
  ),
  names(profiles_src)
)
profile_contract <- profiles_src[, profile_contract_cols, drop = FALSE]
winner_rows <- merge(
  winner_rows,
  profile_contract,
  by = "screening_profile_id",
  all.x = TRUE,
  sort = FALSE
)
winner_rows <- winner_rows[order(winner_rows$family, as.numeric(winner_rows$tau)), , drop = FALSE]
if ("rhs_tau0" %in% names(winner_rows) && any(as.numeric(winner_rows$rhs_tau0) == 3e-05, na.rm = TRUE)) {
  stop("Refusing to write an unstable rhs_tau0=3e-05 winner row into MCMC repair.", call. = FALSE)
}

cell_plan <- winner_rows[, c("family", "tau", "cell_status", "priority_rank", "screening_profile_id", "selection_source"), drop = FALSE]
cell_plan$target_profiles <- cell_plan$screening_profile_id
cell_plan$bottleneck_metric <- "article_pathology_repair"
cell_plan$primary_worst_ratio_vs_baseline <- NA_real_

assignments <- winner_rows[, c(
  "assignment_key", "family", "tau", "cell_status", "priority_rank",
  "target_profile_rank", "screening_profile_id", "selection_source", "assignment_id"
), drop = FALSE]
assignments$source_profile <- assignments$selection_source
assignments$source_worst_ratio <- NA_real_
assignments$bottleneck_metric <- "article_pathology_repair"
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
    promotion_summary_path = promotion_summary_path,
    source_profiles_path = source_profiles_path
  )
)

diag_tables <- file.path(diagnostic_out, "tables")
diag_summary <- file.path(diagnostic_out, "summary")
diag_manifest <- file.path(diagnostic_out, "manifest")
dir.create(diag_tables, recursive = TRUE, showWarnings = FALSE)
dir.create(diag_summary, recursive = TRUE, showWarnings = FALSE)
dir.create(diag_manifest, recursive = TRUE, showWarnings = FALSE)

exdqlm:::.qdesn_validation_write_df(winner_rows, winners_out)
exdqlm:::.qdesn_validation_write_df(winner_rows, file.path(diag_tables, "qdesn_tt500_mcmc_al_rhs_recalibration_winners.csv"))

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
  stage_desc = "Q-DESN TT500 MCMC AL RHS repair using the frozen recalibrated AL RHS VB winners.",
  stage = "mcmc_al_rhs_recalibration"
)

defaults <- yaml::read_yaml(defaults_out)
defaults$campaign$name <- stage_file
defaults$campaign$results_root <- file.path("results", "qdesn_mcmc_validation", stage_file)
defaults$campaign$reports_root <- file.path("reports", "qdesn_mcmc_validation", stage_file)
defaults$execution$methods <- "mcmc"
defaults$execution$likelihood_families <- "al"
defaults$study_contract$id <- paste0(stage_file, "_", format(Sys.Date(), "%Y_%m_%d"))
defaults$study_contract$description <- "Q-DESN TT500 MCMC AL RHS repair launched from the article-facing recalibrated AL RHS VB winner profiles."
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
  "Q-DESN TT500 MCMC AL RHS repair from recalibrated AL RHS VB winners. Profiles: %d; selected assignments: 9.",
  nrow(profiles)
)
defaults$runtime$threads <- 1L
defaults$runtime$campaign_workers <- workers
defaults$runtime$workers <- workers
defaults$runtime$root_scheduler <- "load_balanced"
defaults$smoke$family <- as.character(winner_rows$family[[1L]])
defaults$smoke$tau <- as.numeric(winner_rows$tau[[1L]])
defaults$smoke$max_roots <- 1L
defaults$pipeline$inference$mcmc$n_burn <- 5000L
defaults$pipeline$inference$mcmc$n_mcmc <- 20000L
defaults$pipeline$inference$mcmc$thin <- 1L
defaults$pipeline$inference$mcmc$progress_every <- 50L
defaults$pipeline$inference$mcmc$init_from_vb <- TRUE
defaults$pipeline$inference$mcmc$prior_overrides$rhs_ns$n_burn <- 5000L
defaults$pipeline$inference$mcmc$prior_overrides$rhs_ns$n_mcmc <- 20000L
defaults$pipeline$inference$mcmc$prior_overrides$rhs_ns$progress_every <- 50L
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

grid <- utils::read.csv(grid_out, stringsAsFactors = FALSE, check.names = FALSE)
assignments_after <- utils::read.csv(assignments_out, stringsAsFactors = FALSE, check.names = FALSE)
if (nrow(grid) != 9L || nrow(assignments_after) != 9L) {
  stop(sprintf("Expected 9 AL RHS MCMC repair grid/assignment rows; observed grid=%d assignments=%d.", nrow(grid), nrow(assignments_after)), call. = FALSE)
}
if (any(is.na(assignments_after$root_id)) || any(!nzchar(assignments_after$root_id))) {
  stop("Assignment materialization did not produce concrete root IDs.", call. = FALSE)
}

summary_lines <- c(
  "# Q-DESN TT500 MCMC AL RHS Recalibration Materialization",
  "",
  sprintf("- generated_at: `%s`", as.character(Sys.time())),
  sprintf("- stage_file: `%s`", stage_file),
  sprintf("- promotion_summary: `%s`", promotion_summary_path),
  sprintf("- base_defaults_path: `%s`", base_defaults_path),
  sprintf("- winners: `%s`", winners_out),
  sprintf("- profiles: `%s`", profiles_out),
  sprintf("- assignments: `%s`", assignments_out),
  sprintf("- defaults: `%s`", defaults_out),
  sprintf("- grid: `%s`", grid_out),
  sprintf("- workers: `%d`", workers),
  sprintf("- n_profiles: `%d`", nrow(profiles)),
  sprintf("- n_assignments: `%d`", nrow(assignments_after)),
  "",
  "This materialization freezes exactly nine Q-DESN AL RHS MCMC repair roots from the already-promoted recalibrated AL RHS VB winners."
)
summary_path <- file.path(diag_summary, "qdesn_tt500_mcmc_al_rhs_recalibration.md")
exdqlm:::.qdesn_validation_write_lines(summary_path, summary_lines)

manifest <- list(
  generated_at = as.character(Sys.time()),
  stage = stage_file,
  promotion_summary_path = promotion_summary_path,
  source_profiles_path = source_profiles_path,
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
    promotion_summary_path, source_profiles_path, winners_out, profiles_out,
    assignments_out, defaults_out, grid_out, summary_path
  ))
)
exdqlm:::.qdesn_validation_write_json(file.path(diag_manifest, "qdesn_tt500_mcmc_al_rhs_recalibration_manifest.json"), manifest)
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

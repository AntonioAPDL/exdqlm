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
split_csv_arg <- function(x) {
  x <- as.character(x %||% "")[1L]
  if (!nzchar(trimws(x))) return(character(0))
  trimws(strsplit(x, ",", fixed = TRUE)[[1L]])
}

stage_file <- "qdesn_dynamic_fitforecast_v2_tt500_vb_stage4_remaining_cells_transfer"
article_summary_path <- resolve_path(
  get_arg("--article-summary", "/data/jaguir26/local/src/Article-Q-DESN/tables/qdesn_validation_tt500_final_summary.csv"),
  must_work = TRUE
)
source_profiles_path <- resolve_path(
  get_arg("--source-profiles", file.path("config", "validation", "qdesn_dynamic_fitforecast_v2_tt500_vb_stage3_forecast_bias_rescue_profiles.csv")),
  must_work = TRUE
)
base_defaults_path <- resolve_path(
  get_arg("--base-defaults", file.path("config", "validation", "qdesn_dynamic_fitforecast_v2_tt500_vb_stage3_forecast_bias_rescue_defaults.yaml")),
  must_work = TRUE
)
profiles_out <- resolve_path(
  get_arg("--profiles-out", file.path("config", "validation", paste0(stage_file, "_profiles.csv"))),
  must_work = FALSE
)
assignments_out <- resolve_path(
  get_arg("--assignments-out", file.path("config", "validation", paste0(stage_file, "_cell_assignments.csv"))),
  must_work = FALSE
)
defaults_out <- resolve_path(
  get_arg("--defaults-out", file.path("config", "validation", paste0(stage_file, "_defaults.yaml"))),
  must_work = FALSE
)
grid_out <- resolve_path(
  get_arg("--grid-out", file.path("config", "validation", paste0(stage_file, "_grid.csv"))),
  must_work = FALSE
)
diagnostic_out <- resolve_path(
  get_arg("--diagnostic-out", file.path("reports", "qdesn_mcmc_validation", stage_file, "materialization_diagnostics")),
  must_work = FALSE
)
manifest_path <- resolve_path(
  get_arg("--manifest-out", file.path("config", "validation", paste0(stage_file, "_materialization_manifest.json"))),
  must_work = FALSE
)

workers <- int_arg("--workers", 12L)
refresh_grid <- !has_flag("--no-refresh-grid")
refresh_materialized <- has_flag("--refresh-materialized")
include_sentinels <- has_flag("--include-sentinels")
screening_wave <- as.character(get_arg("--screening-wave", paste0("stage4_transfer_", format(Sys.Date(), "%Y_%m_%d"))))[1L]
transfer_profile_ids <- split_csv_arg(get_arg(
  "--transfer-profile-ids",
  paste(c(
    "tt500vb_f3_d1_n30_a0p02_r0p45_m15_lag15_rl0_pw0p03_pin0p3",
    "tt500vb_f3_d1_n30_a0p03_r0p5_m15_lag15_rl0_pw0p03_pin0p3"
  ), collapse = ",")
))

plan <- exdqlm:::qdesn_dynamic_fitforecast_stage4_transfer_profile_plan(
  article_summary_path = article_summary_path,
  source_profiles_path = source_profiles_path,
  transfer_profile_ids = transfer_profile_ids,
  screening_wave = screening_wave,
  include_sentinels = include_sentinels
)

diag_tables <- file.path(diagnostic_out, "tables")
diag_summary <- file.path(diagnostic_out, "summary")
diag_manifest <- file.path(diagnostic_out, "manifest")
dir.create(diag_tables, recursive = TRUE, showWarnings = FALSE)
dir.create(diag_summary, recursive = TRUE, showWarnings = FALSE)
dir.create(diag_manifest, recursive = TRUE, showWarnings = FALSE)

diagnostic_paths <- list(
  article_cell_audit = file.path(diag_tables, "qdesn_tt500_vb_stage4_article_cell_audit.csv"),
  cell_plan = file.path(diag_tables, "qdesn_tt500_vb_stage4_transfer_cell_plan.csv"),
  selected_profiles = file.path(diag_tables, "qdesn_tt500_vb_stage4_transfer_profiles.csv"),
  cell_assignments = file.path(diag_tables, "qdesn_tt500_vb_stage4_transfer_cell_assignments.csv"),
  summary = file.path(diag_summary, "qdesn_tt500_vb_stage4_remaining_cells_transfer.md"),
  manifest = file.path(diag_manifest, "qdesn_tt500_vb_stage4_remaining_cells_transfer_manifest.json")
)
exdqlm:::.qdesn_validation_write_df(plan$all_article_cells, diagnostic_paths$article_cell_audit)
exdqlm:::.qdesn_validation_write_df(plan$cell_plan, diagnostic_paths$cell_plan)
exdqlm:::.qdesn_validation_write_df(plan$profiles, diagnostic_paths$selected_profiles)
exdqlm:::.qdesn_validation_write_df(plan$assignments, diagnostic_paths$cell_assignments)

cell_display <- plan$cell_plan[, intersect(
  c(
    "priority_rank", "family", "tau", "cell_status", "target_profiles",
    "primary_worst_ratio_vs_baseline", "forecast_mae_ratio_vs_best_vb_baseline",
    "forecast_pinball_ratio_vs_best_vb_baseline", "fit_rmse_ratio_vs_best_vb_baseline",
    "fit_pinball_ratio_vs_best_vb_baseline", "bottleneck_metric"
  ),
  names(plan$cell_plan)
), drop = FALSE]
profile_display <- plan$profiles[, intersect(
  c("transfer_profile_rank", "screening_profile_id", "D", "n_each", "alpha", "rho", "m", "readout_y_lags", "reservoir_lags", "pi_w", "pi_in", "p_over_n_tt500"),
  names(plan$profiles)
), drop = FALSE]
summary_lines <- c(
  "# Q-DESN TT500 VB Stage 4A Remaining-Cell Transfer",
  "",
  sprintf("- generated_at: `%s`", as.character(Sys.time())),
  sprintf("- article_summary_path: `%s`", article_summary_path),
  sprintf("- source_profiles_path: `%s`", source_profiles_path),
  sprintf("- base_defaults_path: `%s`", base_defaults_path),
  sprintf("- workers: `%d`", as.integer(workers)),
  sprintf("- include_sentinels: `%s`", if (isTRUE(include_sentinels)) "TRUE" else "FALSE"),
  sprintf("- target_cells: `%d`", nrow(plan$cell_plan)),
  sprintf("- transfer_profiles: `%d`", nrow(plan$profiles)),
  sprintf("- selected cell-profile assignments: `%d`", nrow(plan$assignments)),
  "",
  "This lane transfers the compact Stage 3 winning profile pair to unresolved Article TT500 VB cells before any broader screen. Article promotion still requires a completed strict audit and explicit table regeneration.",
  "",
  "## Target Cells",
  exdqlm:::.qdesn_validation_df_to_markdown(cell_display),
  "",
  "## Transfer Profiles",
  exdqlm:::.qdesn_validation_df_to_markdown(profile_display),
  "",
  sprintf("- profiles: `%s`", profiles_out),
  sprintf("- assignments: `%s`", assignments_out),
  sprintf("- defaults: `%s`", defaults_out),
  sprintf("- grid: `%s`", grid_out),
  sprintf("- manifest: `%s`", manifest_path)
)
exdqlm:::.qdesn_validation_write_lines(diagnostic_paths$summary, summary_lines)

materialized <- exdqlm:::qdesn_dynamic_fitforecast_materialize_forecast_targeted_stage(
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
  stage_desc = "Q-DESN TT500 VB Stage 4A transfer of compact Stage 3 winners to unresolved article TT500 cells.",
  stage = "stage4_remaining_cells_transfer"
)

file_manifest <- exdqlm:::qdesn_validation_file_manifest(c(
  article_summary_path,
  source_profiles_path,
  base_defaults_path,
  profiles_out,
  assignments_out,
  defaults_out,
  grid_out,
  diagnostic_paths$article_cell_audit,
  diagnostic_paths$cell_plan,
  diagnostic_paths$selected_profiles,
  diagnostic_paths$cell_assignments,
  diagnostic_paths$summary
))
manifest <- list(
  generated_at = as.character(Sys.time()),
  article_summary_path = article_summary_path,
  source_profiles_path = source_profiles_path,
  base_defaults_path = base_defaults_path,
  diagnostic_output_paths = diagnostic_paths,
  plan = plan$manifest,
  materialized = materialized,
  file_manifest = file_manifest,
  screening_wave = screening_wave,
  include_sentinels = include_sentinels,
  refresh_grid = refresh_grid,
  refresh_materialized = refresh_materialized
)
exdqlm:::.qdesn_validation_write_json(diagnostic_paths$manifest, manifest)
exdqlm:::.qdesn_validation_write_json(manifest_path, manifest)

cat(sprintf("diagnostics: %s\n", diagnostic_out))
cat(sprintf("profiles: %s\n", profiles_out))
cat(sprintf("assignments: %s\n", assignments_out))
cat(sprintf("defaults: %s\n", defaults_out))
cat(sprintf("grid: %s\n", grid_out))
cat(sprintf("manifest: %s\n", manifest_path))
cat(sprintf("n_profiles: %d\n", as.integer(materialized$n_profiles)))
cat(sprintf("n_assignments: %d\n", as.integer(materialized$n_assignments)))
cat(sprintf("n_grid_rows: %d\n", as.integer(materialized$n_grid_rows)))
cat(sprintf("expected_qdesn_roots: %d\n", as.integer(materialized$expected_qdesn_roots)))

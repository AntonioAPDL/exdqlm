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
num_arg <- function(flag, default) {
  val <- suppressWarnings(as.numeric(get_arg(flag, as.character(default)))[1L])
  if (is.finite(val)) val else as.numeric(default)
}

default_report_root <- file.path(
  "reports", "qdesn_mcmc_validation", "qdesn_dynamic_fitforecast_v2_tt500_vb_dominance",
  "qdesn-tt500-vb-dominance-period90-broad-leadfix-20260626__git-f700322",
  "20260626-013231__git-f700322"
)
report_root <- resolve_path(get_arg("--report-root", default_report_root), must_work = TRUE)
cell_summary_path <- resolve_path(
  get_arg("--cell-summary", file.path(report_root, "tables", "qdesn_tt500_vb_dominance_cell_summary.csv")),
  must_work = TRUE
)
profile_ranking_path <- resolve_path(
  get_arg("--profile-ranking", file.path(report_root, "tables", "qdesn_tt500_vb_dominance_profile_ranking.csv")),
  must_work = TRUE
)
base_defaults_path <- resolve_path(
  get_arg("--base-defaults", file.path("config", "validation", "qdesn_dynamic_fitforecast_v2_tt500_vb_dominance_defaults.yaml")),
  must_work = TRUE
)
stage_file <- "qdesn_dynamic_fitforecast_v2_tt500_vb_dominance_targeted_refinement"
profiles_out <- resolve_path(
  get_arg("--profiles-out", file.path("config", "validation", paste0(stage_file, "_profiles.csv"))),
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
  get_arg("--diagnostic-out", file.path(report_root, "diagnostics", "qdesn_tt500_vb_targeted_refinement")),
  must_work = FALSE
)

top_n_per_cell <- int_arg("--top-n-per-cell", 3L)
max_profiles <- int_arg("--max-profiles", 120L)
workers <- int_arg("--workers", 20L)
max_p_over_n <- num_arg("--max-p-over-n", 0.50)
refresh_grid <- !has_flag("--no-refresh-grid")
refresh_materialized <- has_flag("--refresh-materialized")

diag <- exdqlm:::qdesn_dynamic_fitforecast_write_dominance_diagnostics(
  report_root = report_root,
  cell_summary_path = cell_summary_path,
  profile_ranking_path = profile_ranking_path,
  out_dir = diagnostic_out,
  top_n_per_cell = top_n_per_cell
)
profiles <- exdqlm:::qdesn_dynamic_fitforecast_targeted_refinement_profiles(
  cell_summary_path = cell_summary_path,
  top_n_per_cell = top_n_per_cell,
  screening_wave = paste0("targeted_refinement_", format(Sys.Date(), "%Y_%m_%d")),
  max_p_over_n = max_p_over_n,
  max_profiles = max_profiles
)
materialized <- exdqlm:::qdesn_dynamic_fitforecast_materialize_followup_stage(
  stage = "refinement",
  profiles = profiles,
  base_defaults_path = base_defaults_path,
  profiles_out = profiles_out,
  defaults_out = defaults_out,
  grid_out = grid_out,
  workers = workers,
  refresh_grid = refresh_grid,
  refresh_materialized = refresh_materialized
)
manifest <- list(
  generated_at = as.character(Sys.time()),
  report_root = report_root,
  cell_summary_path = cell_summary_path,
  profile_ranking_path = profile_ranking_path,
  diagnostic_output_paths = diag$output_paths,
  materialized = materialized,
  top_n_per_cell = top_n_per_cell,
  max_profiles = max_profiles,
  max_p_over_n = max_p_over_n
)
manifest_path <- file.path(dirname(profiles_out), paste0(stage_file, "_materialization_manifest.json"))
exdqlm:::.qdesn_validation_write_json(manifest_path, manifest)

cat(sprintf("diagnostics: %s\n", diagnostic_out))
cat(sprintf("profiles: %s\n", profiles_out))
cat(sprintf("defaults: %s\n", defaults_out))
cat(sprintf("grid: %s\n", grid_out))
cat(sprintf("manifest: %s\n", manifest_path))
cat(sprintf("n_profiles: %d\n", as.integer(materialized$n_profiles)))
cat(sprintf("n_grid_rows: %d\n", as.integer(materialized$n_grid_rows)))
cat(sprintf("expected_qdesn_roots: %d\n", as.integer(materialized$expected_qdesn_roots)))

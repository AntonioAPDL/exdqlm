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
  "reports", "qdesn_mcmc_validation", "qdesn_dynamic_fitforecast_v2_tt500_vb_rhs_optimization",
  "qdesn-tt500-vb-rhs-optimization-full-20260704__git-65fbf35",
  "20260704-091641__git-65fbf35"
)
stage_file <- as.character(get_arg(
  "--stage-file",
  "qdesn_dynamic_fitforecast_v2_tt500_vb_rhs_fitaware_refinement"
))[1L]
stage_name <- as.character(get_arg("--stage-name", "rhs_fitaware_refinement"))[1L]
stage_desc <- as.character(get_arg(
  "--stage-desc",
  "Q-DESN 500-observation VB RHS fit-aware refinement over current weak fit/forecast cells."
))[1L]

report_root <- resolve_path(get_arg("--report-root", default_report_root), must_work = TRUE)
cell_summary_path <- resolve_path(
  get_arg("--cell-summary", file.path(report_root, "tables", "qdesn_tt500_vb_dominance_cell_summary.csv")),
  must_work = TRUE
)
source_profiles_path <- resolve_path(
  get_arg("--source-profiles", file.path("config", "validation", "qdesn_dynamic_fitforecast_v2_tt500_vb_rhs_optimization_profiles.csv")),
  must_work = TRUE
)
base_defaults_path <- resolve_path(
  get_arg("--base-defaults", file.path("config", "validation", "qdesn_dynamic_fitforecast_v2_tt500_vb_rhs_optimization_defaults.yaml")),
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
  get_arg("--diagnostic-out", file.path(report_root, "diagnostics", "qdesn_tt500_vb_rhs_fitaware_refinement")),
  must_work = FALSE
)
manifest_path <- resolve_path(
  get_arg("--manifest-out", file.path("config", "validation", paste0(stage_file, "_materialization_manifest.json"))),
  must_work = FALSE
)

workers <- int_arg("--workers", 20L)
max_p_over_n <- num_arg("--max-p-over-n", 0.50)
refresh_grid <- !has_flag("--no-refresh-grid")
refresh_materialized <- has_flag("--refresh-materialized")
screening_wave <- as.character(get_arg("--screening-wave", paste0("rhs_fitaware_", format(Sys.Date(), "%Y_%m_%d"))))[1L]

plan <- exdqlm:::qdesn_dynamic_fitforecast_forecast_targeted_profile_plan(
  cell_summary_path = cell_summary_path,
  source_profiles_path = source_profiles_path,
  screening_wave = screening_wave,
  max_p_over_n = max_p_over_n
)
stage_column <- paste0("vb_", stage_name)
for (nm in intersect(c("profiles", "assignments", "candidate_ledger"), names(plan))) {
  if (is.data.frame(plan[[nm]]) && "screening_stage" %in% names(plan[[nm]])) {
    plan[[nm]]$screening_stage <- stage_column
  }
}

diag_tables <- file.path(diagnostic_out, "tables")
diag_summary <- file.path(diagnostic_out, "summary")
diag_manifest <- file.path(diagnostic_out, "manifest")
dir.create(diag_tables, recursive = TRUE, showWarnings = FALSE)
dir.create(diag_summary, recursive = TRUE, showWarnings = FALSE)
dir.create(diag_manifest, recursive = TRUE, showWarnings = FALSE)

diagnostic_paths <- list(
  cell_plan = file.path(diag_tables, "qdesn_tt500_vb_rhs_fitaware_cell_plan.csv"),
  candidate_ledger = file.path(diag_tables, "qdesn_tt500_vb_rhs_fitaware_candidate_ledger.csv"),
  selected_profiles = file.path(diag_tables, "qdesn_tt500_vb_rhs_fitaware_selected_profiles.csv"),
  cell_assignments = file.path(diag_tables, "qdesn_tt500_vb_rhs_fitaware_cell_assignments.csv"),
  summary = file.path(diag_summary, "qdesn_tt500_vb_rhs_fitaware_refinement.md"),
  manifest = file.path(diag_manifest, "qdesn_tt500_vb_rhs_fitaware_refinement_manifest.json")
)
exdqlm:::.qdesn_validation_write_df(plan$cell_plan, diagnostic_paths$cell_plan)
exdqlm:::.qdesn_validation_write_df(plan$candidate_ledger, diagnostic_paths$candidate_ledger)
exdqlm:::.qdesn_validation_write_df(plan$profiles, diagnostic_paths$selected_profiles)
exdqlm:::.qdesn_validation_write_df(plan$assignments, diagnostic_paths$cell_assignments)

cell_display <- plan$cell_plan[, intersect(
  c(
    "priority_rank", "family", "tau", "cell_status", "target_profiles",
    "current_best_profile", "current_best_worst_ratio", "current_best_forecast_mae_ratio",
    "current_best_forecast_pinball_ratio", "current_best_fit_rmse_ratio",
    "current_best_fit_pinball_ratio", "bottleneck_metric"
  ),
  names(plan$cell_plan)
), drop = FALSE]
summary_lines <- c(
  "# Q-DESN 500-Observation VB RHS Fit-Aware Refinement Materialization",
  "",
  sprintf("- generated_at: `%s`", as.character(Sys.time())),
  sprintf("- source_report_root: `%s`", report_root),
  sprintf("- cell_summary_path: `%s`", cell_summary_path),
  sprintf("- source_profiles_path: `%s`", source_profiles_path),
  sprintf("- base_defaults_path: `%s`", base_defaults_path),
  sprintf("- max_p_over_n: `%s`", format(max_p_over_n, trim = TRUE)),
  sprintf("- workers: `%d`", as.integer(workers)),
  sprintf("- cells: `%d`", nrow(plan$cell_plan)),
  sprintf("- unique_profiles: `%d`", nrow(plan$profiles)),
  sprintf("- cell_profile_assignments: `%d`", nrow(plan$assignments)),
  "",
  "This lane is intentionally fit-aware: the current Q-DESN RHS VB screen is technically clean, but the limiting metric is usually fit RMSE rather than forecast check loss. The plan therefore keeps cell-specific anchors and probes nearby compact reservoirs while retaining the same rolling-origin source contract.",
  "",
  "## Cell Plan",
  exdqlm:::.qdesn_validation_df_to_markdown(cell_display),
  "",
  sprintf("- selected_profiles: `%s`", profiles_out),
  sprintf("- cell_assignments: `%s`", assignments_out),
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
  stage_desc = stage_desc,
  stage = stage_name,
  priors = "rhs_ns"
)

choose_smoke_assignment <- function(plan) {
  assignments <- plan$assignments[order(plan$assignments$priority_rank, plan$assignments$target_profile_rank), , drop = FALSE]
  assignments[1L, , drop = FALSE]
}
smoke_assignment <- choose_smoke_assignment(plan)
defaults <- yaml::read_yaml(defaults_out)
defaults$smoke <- defaults$smoke %||% list()
defaults$smoke$family <- as.character(smoke_assignment$family[[1L]])
defaults$smoke$tau <- as.numeric(smoke_assignment$tau[[1L]])
defaults$smoke$fit_sizes <- 500L
defaults$smoke$priors <- as.list("rhs_ns")
defaults$smoke$max_roots <- 1L
defaults$smoke$screening_profile_ids <- as.list(as.character(smoke_assignment$screening_profile_id[[1L]]))
defaults$smoke$fitaware_refinement_smoke_cell_status <- as.character(smoke_assignment$cell_status[[1L]])
defaults$smoke$fitfirst_followup_smoke_profile_role <- NULL
yaml::write_yaml(defaults, defaults_out)

file_manifest <- exdqlm:::qdesn_validation_file_manifest(c(
  cell_summary_path,
  source_profiles_path,
  base_defaults_path,
  profiles_out,
  assignments_out,
  defaults_out,
  grid_out,
  diagnostic_paths$cell_plan,
  diagnostic_paths$candidate_ledger,
  diagnostic_paths$selected_profiles,
  diagnostic_paths$cell_assignments,
  diagnostic_paths$summary
))
manifest <- list(
  generated_at = as.character(Sys.time()),
  source_report_root = report_root,
  cell_summary_path = cell_summary_path,
  source_profiles_path = source_profiles_path,
  base_defaults_path = base_defaults_path,
  diagnostic_output_paths = diagnostic_paths,
  plan = plan$manifest,
  materialized = materialized,
  file_manifest = file_manifest,
  screening_wave = screening_wave,
  max_p_over_n = max_p_over_n,
  refresh_grid = refresh_grid,
  refresh_materialized = refresh_materialized,
  promotion_policy = "screening-only; promote only if a cell-level audit shows fit RMSE and forecast check improve without storage-light regressions"
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

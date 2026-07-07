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

stage_file <- "qdesn_dynamic_fitforecast_v2_tt500_vb_rhs_fitforecast_rescue"
default_report_root <- file.path(
  "reports", "qdesn_mcmc_validation", "qdesn_dynamic_fitforecast_v2_tt500_vb_rhs_fitbalanced_broad",
  "qdesn-vb-rhs-fitbalanced-broad-20260706-140332__git-4a4975c",
  "20260706-140543__git-4a4975c"
)
report_root <- resolve_path(get_arg("--report-root", default_report_root), must_work = TRUE)
fit_summary_path <- resolve_path(
  get_arg("--fit-summary", file.path(report_root, "tables", "qdesn_tt500_vb_screen_fit_forecast_summary.csv")),
  must_work = TRUE
)
baseline_path <- resolve_path(get_arg(
  "--baseline",
  "/data/jaguir26/local/src/Article-Q-DESN__wt__main_validation_tables/tables/qdesn_validation_tt500_final_summary.csv"
), must_work = TRUE)
base_defaults_path <- resolve_path(
  get_arg("--base-defaults", file.path("config", "validation", "qdesn_dynamic_fitforecast_v2_tt500_vb_rhs_fitbalanced_broad_defaults.yaml")),
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
manifest_path <- resolve_path(
  get_arg("--manifest-out", file.path("config", "validation", paste0(stage_file, "_materialization_manifest.json"))),
  must_work = FALSE
)
diagnostic_out <- resolve_path(
  get_arg("--diagnostic-out", file.path("reports", "qdesn_mcmc_validation", stage_file, "materialization_diagnostics")),
  must_work = FALSE
)

workers <- int_arg("--workers", 24L)
max_profiles_per_cell <- int_arg("--max-profiles-per-cell", 32L)
max_p_over_n <- num_arg("--max-p-over-n", 0.35)
refresh_grid <- !has_flag("--no-refresh-grid")
refresh_materialized <- has_flag("--refresh-materialized")
screening_wave <- as.character(get_arg("--screening-wave", paste0("rhs_fitforecast_rescue_", format(Sys.Date(), "%Y_%m_%d"))))[1L]

plan <- exdqlm:::qdesn_dynamic_fitforecast_rhs_fitforecast_rescue_plan(
  fit_forecast_summary_path = fit_summary_path,
  baseline_path = baseline_path,
  screening_wave = screening_wave,
  fit_size = 500L,
  max_p_over_n = max_p_over_n,
  max_profiles_per_cell = max_profiles_per_cell
)

diag_tables <- file.path(diagnostic_out, "tables")
diag_summary <- file.path(diagnostic_out, "summary")
diag_manifest <- file.path(diagnostic_out, "manifest")
dir.create(diag_tables, recursive = TRUE, showWarnings = FALSE)
dir.create(diag_summary, recursive = TRUE, showWarnings = FALSE)
dir.create(diag_manifest, recursive = TRUE, showWarnings = FALSE)
diagnostic_paths <- list(
  cell_plan = file.path(diag_tables, "qdesn_tt500_vb_rhs_fitforecast_rescue_cell_plan.csv"),
  candidate_ledger = file.path(diag_tables, "qdesn_tt500_vb_rhs_fitforecast_rescue_candidate_ledger.csv"),
  selected_profiles = file.path(diag_tables, "qdesn_tt500_vb_rhs_fitforecast_rescue_profiles.csv"),
  cell_assignments = file.path(diag_tables, "qdesn_tt500_vb_rhs_fitforecast_rescue_cell_assignments.csv"),
  baseline_targets = file.path(diag_tables, "qdesn_tt500_vb_rhs_fitforecast_rescue_baseline_targets.csv"),
  summary = file.path(diag_summary, "qdesn_tt500_vb_rhs_fitforecast_rescue.md"),
  manifest = file.path(diag_manifest, "qdesn_tt500_vb_rhs_fitforecast_rescue_manifest.json")
)
exdqlm:::.qdesn_validation_write_df(plan$cell_plan, diagnostic_paths$cell_plan)
exdqlm:::.qdesn_validation_write_df(plan$candidate_ledger, diagnostic_paths$candidate_ledger)
exdqlm:::.qdesn_validation_write_df(plan$profiles, diagnostic_paths$selected_profiles)
exdqlm:::.qdesn_validation_write_df(plan$assignments, diagnostic_paths$cell_assignments)
exdqlm:::.qdesn_validation_write_df(plan$baseline_targets, diagnostic_paths$baseline_targets)

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
  stage_desc = "Q-DESN 500-observation VB RHS fit+forecast rescue screen over hard family x tau cells.",
  stage = "rhs_fitforecast_rescue",
  priors = "rhs_ns"
)

defaults <- yaml::read_yaml(defaults_out)
defaults$execution <- defaults$execution %||% list()
defaults$execution$methods <- "vb"
defaults$execution$likelihood_families <- c("al", "exal")
defaults$reference_contract$expected_selected_qdesn_roots <- as.integer(materialized$expected_qdesn_roots)
defaults$screening_profiles$selected_assignment_root_count <- as.integer(materialized$expected_qdesn_roots)
defaults$screening_profiles$design <- sprintf(
  "Q-DESN RHS VB fit+forecast rescue. Profiles: %d; selected roots: %d; likelihoods per root: AL and exAL.",
  nrow(plan$profiles),
  as.integer(materialized$expected_qdesn_roots)
)
defaults$study_contract$description <- paste(
  "Q-DESN RHS VB fit+forecast rescue screen for the 500-observation simulation validation.",
  "The stage is cell-specific, uses the completed fit-balanced broad screen as diagnostics,",
  "targets fit RMSE bottlenecks and normal-family edge forecast MAE gaps,",
  "and remains screening-only until explicit freeze/signoff."
)
defaults$screening_profiles$fitforecast_rescue_design <- list(
  source_report_root = report_root,
  source_fit_summary_path = fit_summary_path,
  baseline_path = baseline_path,
  max_profiles_per_cell = as.integer(max_profiles_per_cell),
  max_p_over_n = as.numeric(max_p_over_n),
  tau0_policy = "primary 1e-4; limited 3e-4 robustness; exclude failed 3e-5 surface",
  launch_policy = "do not run full compute without explicit human launch approval"
)
yaml::write_yaml(defaults, defaults_out)

cell_display <- plan$cell_plan[, intersect(
  c(
    "priority_rank", "family", "tau", "cell_status", "target_profiles",
    "current_best_worst_ratio", "current_best_forecast_mae_ratio",
    "current_best_forecast_pinball_ratio", "current_best_fit_rmse_ratio",
    "current_best_fit_pinball_ratio", "bottleneck_metric",
    "best_fit_rmse_profile", "best_forecast_mae_profile"
  ),
  names(plan$cell_plan)
), drop = FALSE]
profile_display <- plan$profiles[, intersect(
  c(
    "fitforecast_rescue_profile_rank", "screening_profile_id", "profile_role",
    "D", "n_each", "alpha", "rho", "m", "readout_y_lags", "pi_w", "pi_in",
    "rhs_tau0", "dimension_p_estimate", "p_over_n_tt500", "target_cells",
    "target_source_metrics"
  ),
  names(plan$profiles)
), drop = FALSE]
summary_lines <- c(
  "# Q-DESN 500-Observation VB RHS Fit+Forecast Rescue Materialization",
  "",
  sprintf("- generated_at: `%s`", as.character(Sys.time())),
  sprintf("- source_report_root: `%s`", report_root),
  sprintf("- fit_summary_path: `%s`", fit_summary_path),
  sprintf("- baseline_path: `%s`", baseline_path),
  sprintf("- base_defaults_path: `%s`", base_defaults_path),
  sprintf("- workers: `%d`", as.integer(workers)),
  sprintf("- max_profiles_per_cell: `%d`", as.integer(max_profiles_per_cell)),
  sprintf("- max_p_over_n: `%s`", format(max_p_over_n, trim = TRUE)),
  sprintf("- cells: `%d`", nrow(plan$cell_plan)),
  sprintf("- unique_profiles: `%d`", nrow(plan$profiles)),
  sprintf("- selected_roots: `%d`", as.integer(materialized$expected_qdesn_roots)),
  sprintf("- expected_vb_fits_if_AL_and_exAL: `%d`", as.integer(materialized$expected_qdesn_roots) * 2L),
  "",
  "## Diagnosis",
  "",
  "The completed broad screen shows useful forecast behavior but no all-primary dominance because fit RMSE remains above the current best DQLM/exDQLM VB baseline in every cell. The rescue stage therefore uses cell-specific compact reservoirs, keeps the strongest anchors, excludes the unstable `tau0=3e-5` surface, and adds only a small `tau0=3e-4` robustness probe.",
  "",
  "## Cell Plan",
  exdqlm:::.qdesn_validation_df_to_markdown(cell_display),
  "",
  "## Selected Profile Registry",
  exdqlm:::.qdesn_validation_df_to_markdown(profile_display),
  "",
  sprintf("- profiles: `%s`", profiles_out),
  sprintf("- assignments: `%s`", assignments_out),
  sprintf("- defaults: `%s`", defaults_out),
  sprintf("- grid: `%s`", grid_out),
  sprintf("- manifest: `%s`", manifest_path)
)
exdqlm:::.qdesn_validation_write_lines(diagnostic_paths$summary, summary_lines)

file_manifest <- exdqlm:::qdesn_validation_file_manifest(c(
  fit_summary_path,
  baseline_path,
  base_defaults_path,
  profiles_out,
  assignments_out,
  defaults_out,
  grid_out,
  diagnostic_paths$cell_plan,
  diagnostic_paths$candidate_ledger,
  diagnostic_paths$selected_profiles,
  diagnostic_paths$cell_assignments,
  diagnostic_paths$baseline_targets,
  diagnostic_paths$summary
))
manifest <- list(
  generated_at = as.character(Sys.time()),
  repo_root = repo_root,
  git_sha = trimws(system("git rev-parse HEAD", intern = TRUE)),
  git_branch = trimws(system("git rev-parse --abbrev-ref HEAD", intern = TRUE)),
  git_dirty = length(system("git status --porcelain", intern = TRUE)) > 0L,
  source_report_root = report_root,
  fit_summary_path = fit_summary_path,
  baseline_path = baseline_path,
  base_defaults_path = base_defaults_path,
  diagnostic_output_paths = diagnostic_paths,
  plan = plan$manifest,
  materialized = materialized,
  file_manifest = file_manifest,
  screening_wave = screening_wave,
  max_p_over_n = max_p_over_n,
  max_profiles_per_cell = max_profiles_per_cell,
  refresh_grid = refresh_grid,
  refresh_materialized = refresh_materialized,
  launch_gate = "materialized only; no model compute launched by this script"
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
cat(sprintf("expected_vb_fits_if_al_exal: %d\n", as.integer(materialized$expected_qdesn_roots) * 2L))

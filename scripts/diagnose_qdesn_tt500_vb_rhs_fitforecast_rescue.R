#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  req <- c("jsonlite", "pkgload")
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

default_report_root <- file.path(
  "reports", "qdesn_mcmc_validation", "qdesn_dynamic_fitforecast_v2_tt500_vb_rhs_fitforecast_rescue",
  "qdesn-vb-rhs-fitforecast-rescue-20260707-144646__git-438a156",
  "20260707-144724__git-438a156"
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
output_root <- resolve_path(
  get_arg("--output-root", file.path("reports", "qdesn_mcmc_validation", "qdesn_dynamic_fitforecast_v2_tt500_vb_rhs_fitfirst_followup", "posthoc_diagnostics")),
  must_work = FALSE
)

diag <- exdqlm:::qdesn_dynamic_fitforecast_rhs_fitfirst_diagnostics(
  fit_forecast_summary_path = fit_summary_path,
  baseline_path = baseline_path,
  fit_size = 500L
)

tables_dir <- file.path(output_root, "tables")
summary_dir <- file.path(output_root, "summary")
manifest_dir <- file.path(output_root, "manifest")
dir.create(tables_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(summary_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(manifest_dir, recursive = TRUE, showWarnings = FALSE)

paths <- list(
  cell_bottlenecks = file.path(tables_dir, "qdesn_tt500_vb_rhs_fitfirst_cell_bottlenecks.csv"),
  likelihood_bottlenecks = file.path(tables_dir, "qdesn_tt500_vb_rhs_fitfirst_likelihood_bottlenecks.csv"),
  parameter_effects = file.path(tables_dir, "qdesn_tt500_vb_rhs_fitfirst_parameter_effects.csv"),
  promotion_decision = file.path(tables_dir, "qdesn_tt500_vb_rhs_fitfirst_promotion_decision.csv"),
  baseline_targets = file.path(tables_dir, "qdesn_tt500_vb_rhs_fitfirst_baseline_targets.csv"),
  manifest = file.path(manifest_dir, "qdesn_tt500_vb_rhs_fitfirst_diagnostics_manifest.json"),
  summary = file.path(summary_dir, "qdesn_tt500_vb_rhs_fitfirst_diagnostics.md")
)
exdqlm:::.qdesn_validation_write_df(diag$cell_bottlenecks, paths$cell_bottlenecks)
exdqlm:::.qdesn_validation_write_df(diag$likelihood_bottlenecks, paths$likelihood_bottlenecks)
exdqlm:::.qdesn_validation_write_df(diag$parameter_effects, paths$parameter_effects)
exdqlm:::.qdesn_validation_write_df(diag$promotion_decision, paths$promotion_decision)
exdqlm:::.qdesn_validation_write_df(diag$baseline_targets, paths$baseline_targets)

cell_display <- diag$cell_bottlenecks[, intersect(
  c(
    "family", "tau", "n_profiles", "any_beats_all_primary",
    "n_fit_rmse_wins", "n_forecast_mae_wins",
    "min_fit_rmse_ratio", "min_fit_check_ratio",
    "min_forecast_mae_ratio", "min_forecast_check_ratio",
    "best_joint_max_ratio", "best_fit_rmse_profile", "recommendation"
  ),
  names(diag$cell_bottlenecks)
), drop = FALSE]
likelihood_display <- diag$likelihood_bottlenecks[, intersect(
  c(
    "family", "tau", "likelihood_family", "n_profiles",
    "best_fit_rmse_ratio", "best_fit_check_ratio",
    "best_forecast_mae_ratio", "best_forecast_check_ratio",
    "best_joint_max_ratio", "best_fit_rmse_profile"
  ),
  names(diag$likelihood_bottlenecks)
), drop = FALSE]
summary_lines <- c(
  "# Q-DESN 500-Observation VB RHS Fit-First Diagnosis",
  "",
  sprintf("- generated_at: `%s`", as.character(Sys.time())),
  sprintf("- report_root: `%s`", report_root),
  sprintf("- fit_summary_path: `%s`", fit_summary_path),
  sprintf("- baseline_path: `%s`", baseline_path),
  sprintf("- output_root: `%s`", output_root),
  "",
  "## Promotion Decision",
  "",
  exdqlm:::.qdesn_validation_df_to_markdown(diag$promotion_decision),
  "",
  "## Cell Bottlenecks",
  "",
  exdqlm:::.qdesn_validation_df_to_markdown(cell_display),
  "",
  "## Likelihood-Level Bottlenecks",
  "",
  exdqlm:::.qdesn_validation_df_to_markdown(likelihood_display),
  "",
  "## Interpretation",
  "",
  "The completed RHS VB fit+forecast rescue is usable as candidate-selection evidence, not as an article-facing replacement. Forecast metrics improved in several cells, but fit RMSE remains the limiting metric for promotion and MCMC spending. The next stage should therefore be a smaller fit-first VB screen with explicit launch gates."
)
exdqlm:::.qdesn_validation_write_lines(paths$summary, summary_lines)

manifest <- diag$manifest
manifest$output_paths <- paths
manifest$repo_root <- repo_root
manifest$git_sha <- trimws(system("git rev-parse HEAD", intern = TRUE))
manifest$git_branch <- trimws(system("git rev-parse --abbrev-ref HEAD", intern = TRUE))
manifest$git_dirty <- length(system("git status --porcelain", intern = TRUE)) > 0L
exdqlm:::.qdesn_validation_write_json(paths$manifest, manifest)

cat(sprintf("output_root: %s\n", output_root))
cat(sprintf("summary: %s\n", paths$summary))
cat(sprintf("manifest: %s\n", paths$manifest))
cat(sprintf("cells: %d\n", nrow(diag$cell_bottlenecks)))
cat(sprintf("promote_to_article: %s\n", isTRUE(diag$promotion_decision$promote_to_article[[1L]])))
cat(sprintf("launch_mcmc_from_this_screen: %s\n", isTRUE(diag$promotion_decision$launch_mcmc_from_this_screen[[1L]])))

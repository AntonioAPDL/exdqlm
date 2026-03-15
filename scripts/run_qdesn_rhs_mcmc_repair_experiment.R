#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  req <- c("pkgload", "yaml")
  need <- setdiff(req, rownames(installed.packages()))
  if (length(need)) install.packages(need, repos = "https://cloud.r-project.org")
  invisible(lapply(req, require, character.only = TRUE))
})

args <- commandArgs(trailingOnly = TRUE)
has_flag <- function(flag) any(args == flag)
get_arg <- function(flag, default = NULL) {
  idx <- which(args == flag)
  if (length(idx) && idx < length(args)) args[idx + 1L] else default
}

repo_root <- tryCatch(
  normalizePath(system("git rev-parse --show-toplevel", intern = TRUE), winslash = "/", mustWork = TRUE),
  error = function(...) normalizePath(".", winslash = "/", mustWork = TRUE)
)
setwd(repo_root)
pkgload::load_all(repo_root, quiet = TRUE)

experiment_id <- get_arg("--experiment-id", NULL)
run_order <- get_arg("--run-order", NULL)
matrix_path <- get_arg("--matrix", file.path("config", "validation", "qdesn_rhs_mcmc_repair_matrix.csv"))
profiles_path <- get_arg("--profiles", file.path("config", "validation", "qdesn_rhs_mcmc_repair_profiles.yaml"))
results_root <- get_arg("--results-root", NULL)
reports_root <- get_arg("--reports-root", NULL)

resolved <- exdqlm:::qdesn_rhs_mcmc_repair_resolve_experiment(
  experiment_id = experiment_id,
  run_order = if (is.null(run_order)) NULL else as.integer(run_order)[1L],
  matrix_path = matrix_path,
  profiles_path = profiles_path,
  repo_root = repo_root
)

if (!isTRUE(resolved$executable)) {
  stop(sprintf(
    "Experiment '%s' is not directly executable yet. Blockers: %s",
    as.character(resolved$row$experiment_id)[1L],
    paste(resolved$blockers, collapse = ", ")
  ), call. = FALSE)
}

tmp_defaults <- tempfile(pattern = paste0(as.character(resolved$row$experiment_id)[1L], "-"), fileext = ".yaml")
yaml::write_yaml(resolved$defaults, tmp_defaults)

res <- exdqlm:::qdesn_validation_run_campaign(
  grid_path = resolved$grid_path,
  defaults = resolved$defaults,
  defaults_path = tmp_defaults,
  results_root = results_root,
  report_root = reports_root,
  create_plots = !has_flag("--no-plots"),
  verbose = !has_flag("--quiet")
)

file.copy(tmp_defaults, file.path(res$report_root, "manifest", "materialized_defaults.yaml"), overwrite = TRUE)
exdqlm:::.qdesn_validation_write_json(file.path(res$report_root, "manifest", "repair_experiment_manifest.json"), list(
  experiment_id = as.character(resolved$row$experiment_id)[1L],
  run_order = as.integer(resolved$row$run_order)[1L],
  stage = as.character(resolved$row$stage)[1L],
  matrix_path = resolved$matrix_path,
  profiles_path = resolved$profiles_path,
  grid_path = resolved$grid_path,
  defaults_source = resolved$defaults_path,
  report_root = normalizePath(res$report_root, winslash = "/", mustWork = TRUE),
  results_root = normalizePath(res$results_root, winslash = "/", mustWork = TRUE),
  generated_at = as.character(Sys.time())
))

cat(sprintf("Experiment: %s\n", as.character(resolved$row$experiment_id)[1L]))
cat(sprintf("Results root: %s\n", res$results_root))
cat(sprintf("Report root: %s\n", res$report_root))

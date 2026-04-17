#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  req <- c("yaml")
  need <- setdiff(req, rownames(installed.packages()))
  if (length(need)) install.packages(need, repos = "https://cloud.r-project.org")
  invisible(lapply(req, require, character.only = TRUE))
})

args <- commandArgs(trailingOnly = TRUE)
get_arg <- function(flag, default = NULL) {
  idx <- which(args == flag)
  if (length(idx) && idx < length(args)) args[idx + 1L] else default
}
has_flag <- function(flag) any(args == flag)
`%||%` <- function(a, b) if (is.null(a)) b else a

repo_root <- tryCatch(
  normalizePath(system("git rev-parse --show-toplevel", intern = TRUE), winslash = "/", mustWork = TRUE),
  error = function(...) normalizePath(".", winslash = "/", mustWork = TRUE)
)
setwd(repo_root)

phase <- match.arg(
  as.character(get_arg("--phase", "smoke"))[1L],
  c("smoke", "vb", "mcmc_ridge", "mcmc_rhsns_tt500", "mcmc_rhsns_tt5000", "full")
)

defaults_path <- file.path(
  "config",
  "validation",
  "qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_defaults.yaml"
)
phase_grid_map <- list(
  smoke = file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_smoke_grid.csv"),
  vb = file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_grid.csv"),
  mcmc_ridge = file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_mcmc_ridge_grid.csv"),
  mcmc_rhsns_tt500 = file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_mcmc_rhsns_tt500_grid.csv"),
  mcmc_rhsns_tt5000 = file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_mcmc_rhsns_tt5000_grid.csv"),
  full = file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_grid.csv")
)
phase_methods_map <- list(
  smoke = "vb,mcmc",
  vb = "vb",
  mcmc_ridge = "mcmc",
  mcmc_rhsns_tt500 = "mcmc",
  mcmc_rhsns_tt5000 = "mcmc",
  full = "vb,mcmc"
)
phase_workers_map <- list(
  smoke = 2L,
  vb = 6L,
  mcmc_ridge = 3L,
  mcmc_rhsns_tt500 = 3L,
  mcmc_rhsns_tt5000 = 2L,
  full = 3L
)
phase_is_subset <- phase %in% c("smoke", "mcmc_ridge", "mcmc_rhsns_tt500", "mcmc_rhsns_tt5000")

materialize_status <- system2(
  "Rscript",
  file.path("scripts", "materialize_qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_grid.R"),
  stdout = "",
  stderr = ""
)
if (!identical(as.integer(materialize_status), 0L)) {
  quit(status = as.integer(materialize_status), save = "no")
}

workers <- suppressWarnings(as.integer(get_arg("--workers", NA_character_))[1L])
if (!is.finite(workers) || workers < 1L) {
  workers <- as.integer(phase_workers_map[[phase]])[1L]
}

grid_path <- phase_grid_map[[phase]]
methods_arg <- phase_methods_map[[phase]]
git_sha <- trimws(system("git rev-parse --short HEAD", intern = TRUE))
run_tag <- as.character(get_arg(
  "--run-tag",
  sprintf("qdesn-dynamic-exdqlm-crossstudy-tau050-%s-%s__git-%s", phase, format(Sys.time(), "%Y%m%d-%H%M%S"), git_sha)
))[1L]

child_args <- c(
  "--defaults", defaults_path,
  "--grid", grid_path,
  "--methods", methods_arg,
  "--workers", as.character(workers),
  "--batch", "full",
  "--run-tag", run_tag
)
if (has_flag("--prepare-only")) child_args <- c(child_args, "--prepare-only")
if (has_flag("--refresh-grid")) child_args <- c(child_args, "--refresh-grid")
if (isTRUE(phase_is_subset) || has_flag("--allow-grid-subset")) child_args <- c(child_args, "--allow-grid-subset")
if (has_flag("--no-plots")) child_args <- c(child_args, "--no-plots")
if (has_flag("--quiet")) child_args <- c(child_args, "--quiet")

target_script <- if (has_flag("--prepare-only")) {
  file.path("scripts", "run_qdesn_dynamic_exdqlm_crossstudy_validation.R")
} else {
  file.path("scripts", "launch_qdesn_dynamic_exdqlm_crossstudy_validation.R")
}

status <- system2("Rscript", c(target_script, child_args), stdout = "", stderr = "")
quit(status = as.integer(status), save = "no")

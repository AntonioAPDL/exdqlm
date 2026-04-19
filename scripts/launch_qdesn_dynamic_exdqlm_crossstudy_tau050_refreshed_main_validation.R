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
  c(
    "smoke",
    "vb",
    "mcmc_ridge",
    "mcmc_rhsns_tt500",
    "mcmc_rhsns_tt5000",
    "failed_mcmc_al",
    "failed_mcmc_exal",
    "remaining_failed_mcmc_al_v2_canary",
    "remaining_failed_mcmc_exal_v2_canary",
    "remaining_failed_mcmc_al_v2_residual",
    "remaining_failed_mcmc_exal_v2_residual",
    "remaining_failed_mcmc_al_v2",
    "remaining_failed_mcmc_exal_v2",
    "full"
  )
)

phase_defaults_map <- list(
  smoke = file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_defaults.yaml"),
  vb = file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_defaults.yaml"),
  mcmc_ridge = file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_defaults.yaml"),
  mcmc_rhsns_tt500 = file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_defaults.yaml"),
  mcmc_rhsns_tt5000 = file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_defaults.yaml"),
  failed_mcmc_al = file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_defaults.yaml"),
  failed_mcmc_exal = file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_defaults.yaml"),
  remaining_failed_mcmc_al_v2_canary = file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_v2_defaults.yaml"),
  remaining_failed_mcmc_exal_v2_canary = file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_v2_defaults.yaml"),
  remaining_failed_mcmc_al_v2_residual = file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_v2_defaults.yaml"),
  remaining_failed_mcmc_exal_v2_residual = file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_v2_defaults.yaml"),
  remaining_failed_mcmc_al_v2 = file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_v2_defaults.yaml"),
  remaining_failed_mcmc_exal_v2 = file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_v2_defaults.yaml"),
  full = file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_defaults.yaml")
)
phase_grid_map <- list(
  smoke = file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_smoke_grid.csv"),
  vb = file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_grid.csv"),
  mcmc_ridge = file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_mcmc_ridge_grid.csv"),
  mcmc_rhsns_tt500 = file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_mcmc_rhsns_tt500_grid.csv"),
  mcmc_rhsns_tt5000 = file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_mcmc_rhsns_tt5000_grid.csv"),
  failed_mcmc_al = file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_failed_mcmc_al_grid.csv"),
  failed_mcmc_exal = file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_failed_mcmc_exal_grid.csv"),
  remaining_failed_mcmc_al_v2_canary = file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_al_v2_canary_grid.csv"),
  remaining_failed_mcmc_exal_v2_canary = file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_exal_v2_canary_grid.csv"),
  remaining_failed_mcmc_al_v2_residual = file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_al_v2_residual_grid.csv"),
  remaining_failed_mcmc_exal_v2_residual = file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_exal_v2_residual_grid.csv"),
  remaining_failed_mcmc_al_v2 = file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_al_v2_grid.csv"),
  remaining_failed_mcmc_exal_v2 = file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_exal_v2_grid.csv"),
  full = file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_grid.csv")
)
phase_methods_map <- list(
  smoke = "vb,mcmc",
  vb = "vb",
  mcmc_ridge = "mcmc",
  mcmc_rhsns_tt500 = "mcmc",
  mcmc_rhsns_tt5000 = "mcmc",
  failed_mcmc_al = "mcmc",
  failed_mcmc_exal = "mcmc",
  remaining_failed_mcmc_al_v2_canary = "mcmc",
  remaining_failed_mcmc_exal_v2_canary = "mcmc",
  remaining_failed_mcmc_al_v2_residual = "mcmc",
  remaining_failed_mcmc_exal_v2_residual = "mcmc",
  remaining_failed_mcmc_al_v2 = "mcmc",
  remaining_failed_mcmc_exal_v2 = "mcmc",
  full = "vb,mcmc"
)
phase_likelihoods_map <- list(
  smoke = NULL,
  vb = NULL,
  mcmc_ridge = NULL,
  mcmc_rhsns_tt500 = NULL,
  mcmc_rhsns_tt5000 = NULL,
  failed_mcmc_al = "al",
  failed_mcmc_exal = "exal",
  remaining_failed_mcmc_al_v2_canary = "al",
  remaining_failed_mcmc_exal_v2_canary = "exal",
  remaining_failed_mcmc_al_v2_residual = "al",
  remaining_failed_mcmc_exal_v2_residual = "exal",
  remaining_failed_mcmc_al_v2 = "al",
  remaining_failed_mcmc_exal_v2 = "exal",
  full = NULL
)
phase_workers_map <- list(
  smoke = 2L,
  vb = 6L,
  mcmc_ridge = 3L,
  mcmc_rhsns_tt500 = 3L,
  mcmc_rhsns_tt5000 = 2L,
  failed_mcmc_al = 3L,
  failed_mcmc_exal = 3L,
  remaining_failed_mcmc_al_v2_canary = 2L,
  remaining_failed_mcmc_exal_v2_canary = 2L,
  remaining_failed_mcmc_al_v2_residual = 3L,
  remaining_failed_mcmc_exal_v2_residual = 3L,
  remaining_failed_mcmc_al_v2 = 3L,
  remaining_failed_mcmc_exal_v2 = 3L,
  full = 3L
)
phase_is_subset <- phase %in% c(
  "smoke",
  "mcmc_ridge",
  "mcmc_rhsns_tt500",
  "mcmc_rhsns_tt5000",
  "failed_mcmc_al",
  "failed_mcmc_exal",
  "remaining_failed_mcmc_al_v2_canary",
  "remaining_failed_mcmc_exal_v2_canary",
  "remaining_failed_mcmc_al_v2_residual",
  "remaining_failed_mcmc_exal_v2_residual",
  "remaining_failed_mcmc_al_v2",
  "remaining_failed_mcmc_exal_v2"
)
phase_materializer_map <- list(
  smoke = file.path("scripts", "materialize_qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_grid.R"),
  vb = file.path("scripts", "materialize_qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_grid.R"),
  mcmc_ridge = file.path("scripts", "materialize_qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_grid.R"),
  mcmc_rhsns_tt500 = file.path("scripts", "materialize_qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_grid.R"),
  mcmc_rhsns_tt5000 = file.path("scripts", "materialize_qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_grid.R"),
  failed_mcmc_al = file.path("scripts", "materialize_qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_grid.R"),
  failed_mcmc_exal = file.path("scripts", "materialize_qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_grid.R"),
  remaining_failed_mcmc_al_v2_canary = file.path("scripts", "materialize_qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_v2_grids.R"),
  remaining_failed_mcmc_exal_v2_canary = file.path("scripts", "materialize_qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_v2_grids.R"),
  remaining_failed_mcmc_al_v2_residual = file.path("scripts", "materialize_qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_v2_grids.R"),
  remaining_failed_mcmc_exal_v2_residual = file.path("scripts", "materialize_qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_v2_grids.R"),
  remaining_failed_mcmc_al_v2 = file.path("scripts", "materialize_qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_v2_grids.R"),
  remaining_failed_mcmc_exal_v2 = file.path("scripts", "materialize_qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_v2_grids.R"),
  full = file.path("scripts", "materialize_qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_grid.R")
)

defaults_path <- phase_defaults_map[[phase]]
materialize_status <- system2(
  "Rscript",
  phase_materializer_map[[phase]],
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
likelihoods_arg <- phase_likelihoods_map[[phase]]
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
if (nzchar(trimws(as.character(likelihoods_arg %||% "")[1L]))) {
  child_args <- c(child_args, "--likelihoods", as.character(likelihoods_arg)[1L])
}
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

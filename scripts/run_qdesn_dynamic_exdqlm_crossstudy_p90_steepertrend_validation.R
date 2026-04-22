#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
get_arg <- function(flag, default = NULL) {
  idx <- which(args == flag)
  if (length(idx) && idx < length(args)) args[idx + 1L] else default
}
`%||%` <- function(a, b) if (is.null(a)) b else a
has_flag <- function(flag) any(args == flag)

repo_root <- tryCatch(
  normalizePath(system("git rev-parse --show-toplevel", intern = TRUE), winslash = "/", mustWork = TRUE),
  error = function(...) normalizePath(".", winslash = "/", mustWork = TRUE)
)
setwd(repo_root)

phase <- match.arg(
  as.character(get_arg("--phase", "ridge_full"))[1L],
  c(
    "smoke",
    "ridge_vb",
    "mcmc_ridge_tt500",
    "mcmc_ridge_tt5000",
    "ridge_full",
    "rhsns_vb",
    "mcmc_rhsns_tt500",
    "mcmc_rhsns_tt5000",
    "rhsns_full",
    "full"
  )
)

defaults_path <- file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_p90_steepertrend_defaults.yaml")
phase_grid_map <- list(
  smoke = file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_p90_steepertrend_smoke_grid.csv"),
  ridge_vb = file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_p90_steepertrend_ridge_full_grid.csv"),
  mcmc_ridge_tt500 = file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_p90_steepertrend_mcmc_ridge_tt500_grid.csv"),
  mcmc_ridge_tt5000 = file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_p90_steepertrend_mcmc_ridge_tt5000_grid.csv"),
  ridge_full = file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_p90_steepertrend_ridge_full_grid.csv"),
  rhsns_vb = file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_p90_steepertrend_rhsns_full_grid.csv"),
  mcmc_rhsns_tt500 = file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_p90_steepertrend_mcmc_rhsns_tt500_grid.csv"),
  mcmc_rhsns_tt5000 = file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_p90_steepertrend_mcmc_rhsns_tt5000_grid.csv"),
  rhsns_full = file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_p90_steepertrend_rhsns_full_grid.csv"),
  full = file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_p90_steepertrend_full_grid.csv")
)
phase_methods_map <- list(
  smoke = "vb,mcmc",
  ridge_vb = "vb",
  mcmc_ridge_tt500 = "mcmc",
  mcmc_ridge_tt5000 = "mcmc",
  ridge_full = "vb,mcmc",
  rhsns_vb = "vb",
  mcmc_rhsns_tt500 = "mcmc",
  mcmc_rhsns_tt5000 = "mcmc",
  rhsns_full = "vb,mcmc",
  full = "vb,mcmc"
)
batch <- if (identical(phase, "smoke")) "smoke" else "full"
phase_slug <- gsub("_", "-", phase, fixed = TRUE)

default_run_tag <- function(phase_slug) {
  git_sha <- tryCatch(
    trimws(system("git rev-parse --short HEAD", intern = TRUE)),
    error = function(...) "nogit"
  )
  timestamp <- format(Sys.time(), "%Y%m%d-%H%M%S")
  sprintf(
    "qdesn-dynamic-p90-steepertrend-%s-%s__git-%s",
    phase_slug,
    timestamp,
    git_sha
  )
}

child_args <- args
if (!any(child_args == "--defaults")) child_args <- c(child_args, "--defaults", defaults_path)
if (!any(child_args == "--grid")) child_args <- c(child_args, "--grid", phase_grid_map[[phase]])
if (!any(child_args == "--methods")) child_args <- c(child_args, "--methods", phase_methods_map[[phase]])
if (!any(child_args == "--batch")) child_args <- c(child_args, "--batch", batch)
if (!any(child_args == "--allow-grid-subset") && !identical(phase, "full")) child_args <- c(child_args, "--allow-grid-subset")
if (!has_flag("--run-tag")) child_args <- c(child_args, "--run-tag", default_run_tag(phase_slug))

status <- system2(
  "Rscript",
  c(file.path("scripts", "run_qdesn_dynamic_exdqlm_crossstudy_validation.R"), child_args),
  stdout = "",
  stderr = ""
)
quit(status = as.integer(status), save = "no")

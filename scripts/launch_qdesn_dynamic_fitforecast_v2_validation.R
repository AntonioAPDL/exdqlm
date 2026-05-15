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
  idx <- idx[1L]
  if (is.na(idx) || idx >= length(args)) return(default)
  args[idx + 1L]
}

repo_root <- tryCatch(
  normalizePath(system("git rev-parse --show-toplevel", intern = TRUE), winslash = "/", mustWork = TRUE),
  error = function(...) normalizePath(".", winslash = "/", mustWork = TRUE)
)
setwd(repo_root)
pkgload::load_all(repo_root, quiet = TRUE)
runtime_snapshot <- exdqlm:::qdesn_validation_assert_runtime(repo_root = repo_root)

phase <- match.arg(
  as.character(get_arg("--phase", "smoke"))[1L],
  c("smoke", "vb_full", "mcmc_tt500", "mcmc_tt5000", "full")
)

runner_rel <- file.path("scripts", "run_qdesn_dynamic_exdqlm_crossstudy_validation.R")
defaults_rel <- file.path("config", "validation", "qdesn_dynamic_fitforecast_v2_storage_light_defaults.yaml")
grid_rel <- file.path("config", "validation", "qdesn_dynamic_fitforecast_v2_full_grid.csv")
git_sha <- trimws(system("git rev-parse --short HEAD", intern = TRUE))
phase_plan <- exdqlm:::qdesn_dynamic_fitforecast_phase_plan(phase)
phase_tag <- phase_plan$phase_tag
batch <- phase_plan$batch
run_tag <- as.character(get_arg(
  "--run-tag",
  sprintf("qdesn-dynamic-fitforecast-v2-%s-%s__git-%s", phase_tag, format(Sys.time(), "%Y%m%d-%H%M%S"), git_sha)
))[1L]

requested_session_name <- as.character(get_arg("--tmux-session", ""))[1L]
session_name <- if (nzchar(trimws(requested_session_name))) {
  requested_session_name
} else {
  sprintf("qdesn_ff_v2_%s", gsub("[^0-9]", "", format(Sys.time(), "%m%d_%H%M%S")))
}

methods <- phase_plan$methods
fit_sizes <- paste(as.integer(phase_plan$fit_sizes), collapse = ",")

child_args <- args
if (!any(child_args == "--defaults")) child_args <- c(child_args, "--defaults", defaults_rel)
if (!any(child_args == "--grid")) child_args <- c(child_args, "--grid", grid_rel)
if (!any(child_args == "--methods")) child_args <- c(child_args, "--methods", methods)
if (nzchar(fit_sizes) && !any(child_args == "--fit-sizes")) child_args <- c(child_args, "--fit-sizes", fit_sizes)
if (!any(child_args == "--batch")) child_args <- c(child_args, "--batch", batch)
if (!any(child_args == "--run-tag")) child_args <- c(child_args, "--run-tag", run_tag)
if (!any(child_args == "--allow-grid-subset") && isTRUE(phase_plan$allow_grid_subset_default)) child_args <- c(child_args, "--allow-grid-subset")

status <- system2(
  runtime_snapshot$rscript,
  c(
    file.path("scripts", "launch_qdesn_dynamic_exdqlm_crossstudy_validation.R"),
    "--runner", runner_rel,
    "--defaults", defaults_rel,
    "--batch", batch,
    "--tmux-session", session_name,
    child_args
  ),
  stdout = "",
  stderr = ""
)
quit(status = as.integer(status), save = "no")

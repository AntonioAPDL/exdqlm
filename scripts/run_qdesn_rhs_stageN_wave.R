#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  req <- c("pkgload")
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

manifest <- normalizePath(
  get_arg("--manifest", file.path("config", "validation", "qdesn_rhs_stageN_manifest.yaml")),
  winslash = "/",
  mustWork = TRUE
)

stamp <- format(Sys.time(), "%Y%m%d-%H%M%S")
git_sha <- exdqlm:::.qdesn_validation_git_sha()
run_tag <- as.character(get_arg("--run-tag", paste0("stageNrepair-", stamp, "__git-", git_sha)))[1L]

create_plots <- !has_flag("--no-plots")
quiet <- has_flag("--quiet")
no_resume <- has_flag("--no-resume")

analysis_root <- normalizePath(
  get_arg("--analysis-root", file.path("reports", "qdesn_mcmc_validation", "rhs_stageM_repair_wave", run_tag)),
  winslash = "/",
  mustWork = FALSE
)
results_root <- normalizePath(
  get_arg("--results-root", file.path("results", "qdesn_mcmc_validation", "rhs_stageM_repair_wave", run_tag)),
  winslash = "/",
  mustWork = FALSE
)

cmd <- c(
  "scripts/run_qdesn_rhs_stageM_repair_wave.R",
  "--manifest", manifest,
  "--run-tag", run_tag,
  "--analysis-root", analysis_root,
  "--results-root", results_root
)
if (!create_plots) cmd <- c(cmd, "--no-plots")
if (quiet) cmd <- c(cmd, "--quiet")
if (no_resume) cmd <- c(cmd, "--no-resume")

status <- system2(command = "Rscript", args = cmd)
quit(status = status)

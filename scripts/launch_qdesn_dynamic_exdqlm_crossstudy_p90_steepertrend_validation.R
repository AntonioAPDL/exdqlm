#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  req <- c("jsonlite")
  need <- setdiff(req, rownames(installed.packages()))
  if (length(need)) install.packages(need, repos = "https://cloud.r-project.org")
  invisible(lapply(req, require, character.only = TRUE))
})

args <- commandArgs(trailingOnly = TRUE)
get_arg <- function(flag, default = NULL) {
  idx <- which(args == flag)
  if (length(idx) && idx < length(args)) args[idx + 1L] else default
}
`%||%` <- function(a, b) if (is.null(a)) b else a

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

runner_rel <- file.path("scripts", "run_qdesn_dynamic_exdqlm_crossstudy_p90_steepertrend_validation.R")
runner_path <- normalizePath(file.path(repo_root, runner_rel), winslash = "/", mustWork = TRUE)
git_sha <- trimws(system("git rev-parse --short HEAD", intern = TRUE))
phase_tag <- gsub("_", "-", phase, fixed = TRUE)
run_tag <- as.character(get_arg(
  "--run-tag",
  sprintf("qdesn-dynamic-p90-steepertrend-%s-%s__git-%s", phase_tag, format(Sys.time(), "%Y%m%d-%H%M%S"), git_sha)
))[1L]

requested_session_name <- as.character(get_arg("--tmux-session", ""))[1L]
session_name <- if (nzchar(trimws(requested_session_name))) {
  requested_session_name
} else {
  sprintf("qdesn_p90_%s", gsub("[^0-9]", "", format(Sys.time(), "%m%d_%H%M%S")))
}

child_args <- args
if (!any(child_args == "--phase")) child_args <- c(child_args, "--phase", phase)
if (!any(child_args == "--run-tag")) child_args <- c(child_args, "--run-tag", run_tag)

status <- system2(
  "Rscript",
  c(
    file.path("scripts", "launch_qdesn_dynamic_exdqlm_crossstudy_validation.R"),
    "--defaults", file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_p90_steepertrend_defaults.yaml"),
    "--tmux-session", session_name,
    child_args
  ),
  stdout = "",
  stderr = ""
)
quit(status = as.integer(status), save = "no")


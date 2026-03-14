#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  req <- c("pkgload")
  need <- setdiff(req, rownames(installed.packages()))
  if (length(need)) install.packages(need, repos = "https://cloud.r-project.org")
  invisible(lapply(req, require, character.only = TRUE))
})

`%||%` <- function(a, b) if (is.null(a)) b else a

args <- commandArgs(trailingOnly = TRUE)
get_arg <- function(flag, default = NULL) {
  idx <- which(args == flag)
  if (length(idx) && idx < length(args)) args[idx + 1L] else default
}
has_flag <- function(flag) any(args == flag)

repo_root <- tryCatch(
  normalizePath(system("git rev-parse --show-toplevel", intern = TRUE), winslash = "/", mustWork = TRUE),
  error = function(...) normalizePath(".", winslash = "/", mustWork = TRUE)
)
setwd(repo_root)
pkgload::load_all(repo_root, quiet = TRUE)

defaults_path <- get_arg("--defaults", file.path("config", "validation", "qdesn_mcmc_pilot_defaults.yaml"))
defaults <- exdqlm:::qdesn_validation_load_defaults(defaults_path)

root_spec <- list(
  scenario = get_arg("--scenario", defaults$pilot$scenario %||% "toy_sine_small"),
  tau = as.numeric(get_arg("--tau", as.character(defaults$pilot$tau %||% 0.25))),
  beta_prior_type = get_arg("--prior", "ridge"),
  seed = as.integer(get_arg("--seed", as.character(defaults$pilot$seed %||% 123L))),
  reservoir_profile = get_arg("--reservoir", defaults$pilot$reservoir_profile %||% "tiny_d1_n8")
)

output_root <- normalizePath(
  get_arg("--output-root", file.path("results", "qdesn_mcmc_validation", "manual_root_run")),
  winslash = "/",
  mustWork = FALSE
)

res <- exdqlm:::qdesn_validation_run_root(
  root_spec = root_spec,
  defaults = defaults,
  output_root = output_root,
  create_plots = !has_flag("--no-plots"),
  verbose = !has_flag("--quiet")
)

cat(sprintf("Root dir: %s\n", res$root_dir))
cat(sprintf("Root status: %s\n", res$root_status))

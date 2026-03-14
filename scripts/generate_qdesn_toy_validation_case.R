#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  req <- c("pkgload", "yaml", "jsonlite")
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

repo_root <- tryCatch(
  normalizePath(system("git rev-parse --show-toplevel", intern = TRUE), winslash = "/", mustWork = TRUE),
  error = function(...) normalizePath(".", winslash = "/", mustWork = TRUE)
)
setwd(repo_root)
pkgload::load_all(repo_root, quiet = TRUE)

defaults_path <- get_arg("--defaults", file.path("config", "validation", "qdesn_mcmc_pilot_defaults.yaml"))
defaults <- exdqlm:::qdesn_validation_load_defaults(defaults_path)

scenario <- get_arg("--scenario", defaults$pilot$scenario %||% "toy_sine_small")
seed <- as.integer(get_arg("--seed", as.character(defaults$pilot$seed %||% 123L)))
out_dir <- normalizePath(
  get_arg("--out-dir", file.path("reports", "qdesn_mcmc_validation", "toy_preview", paste0(scenario, "_seed", seed))),
  winslash = "/",
  mustWork = FALSE
)
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

scenario_cfg <- ((defaults$toy %||% list())$scenarios %||% list())[[scenario]]
toy_obj <- exdqlm:::qdesn_validation_generate_toy_series(
  scenario = scenario,
  seed = seed,
  scenario_cfg = scenario_cfg
)

utils::write.csv(toy_obj$long, file.path(out_dir, "series_long.csv"), row.names = FALSE)
utils::write.csv(toy_obj$wide, file.path(out_dir, "series_wide.csv"), row.names = FALSE)
utils::write.csv(toy_obj$split, file.path(out_dir, "split_summary.csv"), row.names = FALSE)
jsonlite::write_json(toy_obj$meta, file.path(out_dir, "toy_meta.json"), pretty = TRUE, auto_unbox = TRUE)

cat(sprintf("Toy case written to %s\n", out_dir))

#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
repo_root <- tryCatch(
  normalizePath(system("git rev-parse --show-toplevel", intern = TRUE), winslash = "/", mustWork = TRUE),
  error = function(...) normalizePath(".", winslash = "/", mustWork = TRUE)
)
setwd(repo_root)

script_path <- file.path(repo_root, "scripts", "healthcheck_qdesn_dynamic_exdqlm_crossstudy_fit_fail_closure_wave.R")
manifest_path <- file.path(
  "config",
  "validation",
  "qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_rhs_long_mcmc_wave_manifest.yaml"
)

status <- system2(
  "Rscript",
  c(script_path, "--manifest", manifest_path, args),
  stdout = "",
  stderr = ""
)
quit(status = as.integer(status), save = "no")

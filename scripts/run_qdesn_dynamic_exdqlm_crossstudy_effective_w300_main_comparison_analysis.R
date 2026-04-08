#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)

repo_root <- tryCatch(
  normalizePath(system("git rev-parse --show-toplevel", intern = TRUE), winslash = "/", mustWork = TRUE),
  error = function(...) normalizePath(".", winslash = "/", mustWork = TRUE)
)

script <- file.path(repo_root, "scripts", "run_qdesn_dynamic_exdqlm_crossstudy_main_comparison_analysis.R")

base_args <- c(
  "--manifest", file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_effective_w300_main_comparison_analysis_manifest.yaml"),
  "--defaults", file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_defaults.yaml"),
  "--grid", file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_grid.csv")
)

status <- system2("Rscript", c(script, base_args, args))
quit(save = "no", status = status)

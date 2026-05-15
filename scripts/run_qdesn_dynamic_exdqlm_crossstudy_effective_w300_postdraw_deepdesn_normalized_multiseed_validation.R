#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
script_file <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1L])
repo_root <- normalizePath(file.path(dirname(normalizePath(script_file, winslash = "/", mustWork = TRUE)), ".."), winslash = "/", mustWork = TRUE)
setwd(repo_root)

script_path <- file.path(repo_root, "scripts", "run_qdesn_dynamic_exdqlm_crossstudy_validation.R")
defaults_path <- file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_normalized_multiseed_defaults.yaml")
grid_path <- file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_grid.csv")

status <- system2(
  "Rscript",
  c(script_path, "--defaults", defaults_path, "--grid", grid_path, args),
  stdout = "",
  stderr = ""
)
quit(status = as.integer(status), save = "no")

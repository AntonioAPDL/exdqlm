#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
repo_root <- tryCatch(
  {
    script_file <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1L])
    normalizePath(file.path(dirname(normalizePath(script_file, winslash = "/", mustWork = TRUE)), ".."), winslash = "/", mustWork = TRUE)
  },
  error = function(...) normalizePath(system("git rev-parse --show-toplevel", intern = TRUE), winslash = "/", mustWork = TRUE)
)
setwd(repo_root)

status <- system2(
  "Rscript",
  c(
    file.path("scripts", "materialize_qdesn_dynamic_exdqlm_crossstudy_grid.R"),
    "--defaults",
    file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_defaults.yaml"),
    "--output",
    file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_grid.csv"),
    args
  ),
  stdout = "",
  stderr = ""
)
quit(status = as.integer(status), save = "no")

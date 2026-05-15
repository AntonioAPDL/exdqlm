#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)

repo_root <- tryCatch(
  normalizePath(system("git rev-parse --show-toplevel", intern = TRUE), winslash = "/", mustWork = TRUE),
  error = function(...) normalizePath(".", winslash = "/", mustWork = TRUE)
)

main_script <- file.path(
  repo_root,
  "scripts",
  "run_qdesn_dynamic_exdqlm_crossstudy_final_analysis_pack.R"
)

base_args <- c(
  "--manifest", file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_final_analysis_pack_manifest.yaml")
)

status <- system2("Rscript", c(main_script, base_args, args))
quit(save = "no", status = status)

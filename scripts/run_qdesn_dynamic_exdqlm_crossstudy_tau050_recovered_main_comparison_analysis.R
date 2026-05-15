#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)

repo_root <- tryCatch(
  normalizePath(system("git rev-parse --show-toplevel", intern = TRUE), winslash = "/", mustWork = TRUE),
  error = function(...) normalizePath(".", winslash = "/", mustWork = TRUE)
)

materializer <- file.path(
  repo_root,
  "scripts",
  "materialize_qdesn_dynamic_exdqlm_crossstudy_tau050_recovered_main_comparison_overrides.R"
)
main_script <- file.path(
  repo_root,
  "scripts",
  "run_qdesn_dynamic_exdqlm_crossstudy_main_comparison_analysis.R"
)

status <- system2("Rscript", c(materializer))
if (!identical(as.integer(status), 0L)) {
  quit(save = "no", status = status)
}

base_args <- c(
  "--manifest", file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_recovered_main_comparison_analysis_manifest.yaml"),
  "--defaults", file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_defaults.yaml"),
  "--grid", file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_grid.csv")
)

status <- system2("Rscript", c(main_script, base_args, args))
quit(save = "no", status = status)

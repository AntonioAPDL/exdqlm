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

materialize_script <- file.path(
  repo_root,
  "scripts",
  "materialize_qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_rowfaithful_multiseed_replay.R"
)
healthcheck_script <- file.path(repo_root, "scripts", "healthcheck_qdesn_dynamic_exdqlm_crossstudy_validation.R")
manifest_path <- file.path(
  "config",
  "validation",
  "qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_rowfaithful_multiseed_replay_manifest.yaml"
)
defaults_path <- file.path(
  "config",
  "validation",
  "qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_rowfaithful_multiseed_defaults.yaml"
)

materialize_status <- system2(
  "Rscript",
  c(materialize_script, "--manifest", manifest_path, "--no-summary"),
  stdout = "",
  stderr = ""
)
if (!identical(as.integer(materialize_status), 0L)) {
  quit(status = as.integer(materialize_status), save = "no")
}

status <- system2(
  "Rscript",
  c(healthcheck_script, "--defaults", defaults_path, args),
  stdout = "",
  stderr = ""
)
quit(status = as.integer(status), save = "no")

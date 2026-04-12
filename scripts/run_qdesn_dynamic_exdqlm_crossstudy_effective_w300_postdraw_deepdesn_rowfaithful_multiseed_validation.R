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

has_flag <- function(flag) any(args == flag)
add_arg_if_missing <- function(args, flag, value) {
  if (any(args == flag)) return(args)
  c(args, flag, value)
}

materialize_script <- file.path(
  repo_root,
  "scripts",
  "materialize_qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_rowfaithful_multiseed_replay.R"
)
run_script <- file.path(repo_root, "scripts", "run_qdesn_dynamic_exdqlm_crossstudy_validation.R")
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
grid_path <- file.path(
  "config",
  "validation",
  "qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_deepdesn_grid.csv"
)

materialize_status <- system2(
  "Rscript",
  c(materialize_script, "--manifest", manifest_path),
  stdout = "",
  stderr = ""
)
if (!identical(as.integer(materialize_status), 0L)) {
  quit(status = as.integer(materialize_status), save = "no")
}

git_sha <- trimws(system("git rev-parse --short HEAD", intern = TRUE))
default_run_tag <- sprintf(
  "qdesn-dynamic-exdqlm-crossstudy-deepdesn-rowfaithseed-%s__git-%s",
  format(Sys.time(), "%Y%m%d-%H%M%S"),
  git_sha
)
child_args <- args
child_args <- add_arg_if_missing(child_args, "--run-tag", default_run_tag)

status <- system2(
  "Rscript",
  c(run_script, "--defaults", defaults_path, "--grid", grid_path, child_args),
  stdout = "",
  stderr = ""
)
quit(status = as.integer(status), save = "no")

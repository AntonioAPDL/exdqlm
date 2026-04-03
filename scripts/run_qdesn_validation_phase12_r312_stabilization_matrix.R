#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)

repo_root <- tryCatch(
  normalizePath(system("git rev-parse --show-toplevel", intern = TRUE), winslash = "/", mustWork = TRUE),
  error = function(...) normalizePath(".", winslash = "/", mustWork = TRUE)
)

default_manifest <- file.path(
  repo_root,
  "config",
  "validation",
  "qdesn_validation_phase12_r312_stabilization_matrix_manifest.yaml"
)

if (!any(args == "--manifest")) {
  args <- c("--manifest", default_manifest, args)
}

target <- file.path(repo_root, "scripts", "run_qdesn_validation_phase3_family_b_screen.R")

status <- system2("Rscript", c(target, args))

quit(status = status)

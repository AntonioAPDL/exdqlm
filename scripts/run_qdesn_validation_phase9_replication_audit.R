#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)

repo_root <- tryCatch(
  normalizePath(system("git rev-parse --show-toplevel", intern = TRUE), winslash = "/", mustWork = TRUE),
  error = function(...) normalizePath(".", winslash = "/", mustWork = TRUE)
)

target <- file.path(repo_root, "scripts", "run_qdesn_exal_kernel_screen.R")

status <- system2("Rscript", c(target, args))

quit(status = status)

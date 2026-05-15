#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
get_arg <- function(flag, default = NULL) {
  idx <- which(args == flag)
  if (!length(idx)) return(default)
  idx <- idx[1L]
  if (is.na(idx) || idx >= length(args)) return(default)
  args[idx + 1L]
}

repo_root <- tryCatch(
  normalizePath(system("git rev-parse --show-toplevel", intern = TRUE), winslash = "/", mustWork = TRUE),
  error = function(...) normalizePath(".", winslash = "/", mustWork = TRUE)
)
setwd(repo_root)

child_args <- args
if (!any(child_args == "--defaults")) {
  child_args <- c(
    child_args,
    "--defaults",
    file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_p90_steepertrend_defaults.yaml")
  )
}

status <- system2(
  "Rscript",
  c(file.path("scripts", "healthcheck_qdesn_dynamic_exdqlm_crossstudy_validation.R"), child_args),
  stdout = "",
  stderr = ""
)
quit(status = as.integer(status), save = "no")

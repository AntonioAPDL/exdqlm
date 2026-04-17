#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
get_arg <- function(flag, default = NULL) {
  idx <- which(args == flag)
  if (length(idx) && idx < length(args)) args[idx + 1L] else default
}

repo_root <- tryCatch(
  {
    script_file <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1L])
    normalizePath(file.path(dirname(normalizePath(script_file, winslash = "/", mustWork = TRUE)), ".."), winslash = "/", mustWork = TRUE)
  },
  error = function(...) normalizePath(system("git rev-parse --show-toplevel", intern = TRUE), winslash = "/", mustWork = TRUE)
)
setwd(repo_root)

phase <- match.arg(
  as.character(get_arg("--phase", "full"))[1L],
  c("smoke", "vb", "mcmc_ridge", "mcmc_rhsns_tt500", "mcmc_rhsns_tt5000", "full")
)

phase_grid_map <- list(
  smoke = file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_smoke_grid.csv"),
  vb = file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_grid.csv"),
  mcmc_ridge = file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_mcmc_ridge_grid.csv"),
  mcmc_rhsns_tt500 = file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_mcmc_rhsns_tt500_grid.csv"),
  mcmc_rhsns_tt5000 = file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_mcmc_rhsns_tt5000_grid.csv"),
  full = file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_grid.csv")
)

pass_args <- character(0)
skip_next <- FALSE
for (i in seq_along(args)) {
  if (isTRUE(skip_next)) {
    skip_next <- FALSE
    next
  }
  if (identical(args[[i]], "--phase")) {
    skip_next <- TRUE
    next
  }
  pass_args <- c(pass_args, args[[i]])
}

status <- system2(
  "Rscript",
  c(
    file.path("scripts", "healthcheck_qdesn_dynamic_exdqlm_crossstudy_validation.R"),
    "--defaults",
    file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_refreshed_main_defaults.yaml"),
    "--grid",
    phase_grid_map[[phase]],
    pass_args
  ),
  stdout = "",
  stderr = ""
)
quit(status = as.integer(status), save = "no")

#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
value_after <- function(flag, default = NULL) {
  i <- match(flag, args)
  if (is.na(i) || i == length(args)) return(default)
  args[[i + 1L]]
}

config_path <- value_after("--config")
if (is.null(config_path)) stop("Usage: --config <job.json>", call. = FALSE)

repo_root <- normalizePath(
  system("git rev-parse --show-toplevel", intern = TRUE),
  winslash = "/", mustWork = TRUE
)
Sys.setenv(
  OMP_NUM_THREADS = "1", OPENBLAS_NUM_THREADS = "1",
  MKL_NUM_THREADS = "1", VECLIB_MAXIMUM_THREADS = "1",
  NUMEXPR_NUM_THREADS = "1", RCPP_PARALLEL_NUM_THREADS = "1"
)
suppressPackageStartupMessages(pkgload::load_all(repo_root, quiet = TRUE))
source(file.path(
  repo_root, "validation", "fitforecast_v2", "R",
  "independent_qdesn_full_redesign_v2.R"
))
source(file.path(
  repo_root, "validation", "fitforecast_v2", "R",
  "independent_qdesn_full_redesign_v2_runtime.R"
))

cfg <- iqfr_v2_read_json(config_path)
stage <- as.character(cfg$stage)
if (stage %in% c("normal_initial", "normal_adaptive", "normal_full")) {
  iqfr_v2_normal_job(config_path)
} else if (identical(stage, "quantile_vb")) {
  iqfr_v2_quantile_vb_job(config_path)
} else if (stage %in% c("mcmc_pilot", "mcmc_confirmation")) {
  iqfr_v2_mcmc_job(config_path)
} else {
  stop("Unsupported redesigned-validation job stage: ", stage, call. = FALSE)
}

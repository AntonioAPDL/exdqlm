#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
index <- match("--config", args)
if (is.na(index) || index == length(args)) {
  stop("Usage: --config JOB_CONFIG.json", call. = FALSE)
}
config_path <- normalizePath(args[[index + 1L]], winslash = "/",
                             mustWork = TRUE)
repo_root <- normalizePath(
  system("git rev-parse --show-toplevel", intern = TRUE),
  winslash = "/", mustWork = TRUE
)
Sys.setenv(
  OMP_NUM_THREADS = "1", OPENBLAS_NUM_THREADS = "1", MKL_NUM_THREADS = "1",
  VECLIB_MAXIMUM_THREADS = "1", NUMEXPR_NUM_THREADS = "1",
  RCPP_PARALLEL_NUM_THREADS = "1"
)
suppressPackageStartupMessages(pkgload::load_all(repo_root, quiet = TRUE))
source(file.path(repo_root, "validation", "fitforecast_v2", "R",
                 "independent_qdesn_full_redesign_v2.R"))
source(file.path(repo_root, "validation", "fitforecast_v2", "R",
                 "independent_qdesn_full_redesign_v2_runtime.R"))
source(file.path(repo_root, "validation", "fitforecast_v2", "R",
                 "independent_qdesn_representation_screen_v1.R"))
source(file.path(repo_root, "validation", "fitforecast_v2", "R",
                 "independent_qdesn_representation_screen_v1_runtime.R"))

cfg <- iqfr_v2_read_json(config_path)
materialization <- iqfr_v2_read_json(file.path(
  cfg$run_root, "manifests", "materialization.json"
))
environment <- iqfr_v2_read_json(file.path(
  cfg$run_root, "manifests", "environment.json"
))
observed_head <- system2("git", c("-C", repo_root, "rev-parse", "HEAD"),
                         stdout = TRUE)
observed_protocol_sha <- iqfr_v2_sha256(file.path(repo_root,
                                                   iqrs_v1_protocol_relpath))
source_version <- as.character(read.dcf(
  file.path(repo_root, "DESCRIPTION"), fields = "Version"
)[[1L]])
loaded_version <- as.character(utils::packageVersion("exdqlm"))
if (!identical(source_version, "1.1.1") ||
    !identical(loaded_version, "1.1.1") ||
    !identical(as.character(materialization$git$head), observed_head) ||
    !identical(as.character(environment$git_head), observed_head) ||
    !identical(as.character(cfg$protocol_sha256), observed_protocol_sha)) {
  stop("Representation-screen worker provenance contract failed.",
       call. = FALSE)
}

stage <- as.character(cfg$stage)
if (stage %in% c("ridge_screen", "rhs_screen")) {
  iqrs_v1_normal_job(config_path)
} else if (identical(stage, "quantile_vb")) {
  iqrs_v1_quantile_vb_job(config_path)
} else if (stage %in% c("mcmc_pilot", "mcmc_confirmation")) {
  iqfr_v2_mcmc_job(config_path)
} else {
  stop("Unsupported representation-screen stage: ", stage, call. = FALSE)
}

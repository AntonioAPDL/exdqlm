#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
i <- match("--config", args)
if (is.na(i) || i == length(args)) stop("Usage: --config PATH", call. = FALSE)
config_path <- args[[i + 1L]]
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
                 "independent_qdesn_posterior_forecast_rescue_v1.R"))

cfg <- iqfr_v2_read_json(config_path)
protocol <- iqpfr_v1_read_protocol(repo_root)
materialization <- iqfr_v2_read_json(file.path(
  cfg$run_root, "manifests", "materialization.json"
))
environment <- iqfr_v2_read_json(file.path(
  cfg$run_root, "manifests", "environment.json"
))
head <- system2("git", c("-C", repo_root, "rev-parse", "HEAD"), stdout = TRUE)
branch <- system2("git", c("-C", repo_root, "branch", "--show-current"),
                  stdout = TRUE)
loaded_version <- as.character(utils::packageVersion("exdqlm"))
source_version <- as.character(read.dcf(
  file.path(repo_root, "DESCRIPTION"), fields = "Version"
)[[1L]])
if (!identical(branch, iqpfr_v1_expected_branch) ||
    !identical(head, as.character(materialization$git$head)) ||
    !identical(head, as.character(environment$git_head)) ||
    !identical(loaded_version, as.character(protocol$scope$package_version)) ||
    !identical(source_version, as.character(protocol$scope$package_version)) ||
    !identical(iqfr_v2_sha256(file.path(repo_root, iqpfr_v1_protocol_relpath)),
               as.character(cfg$protocol_sha256))) {
  stop("Posterior-rescue worker provenance contract failed.", call. = FALSE)
}
iqfr_v2_mcmc_job(config_path)

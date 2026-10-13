#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
index <- match("--config", args)
if (is.na(index) || index == length(args)) stop("--config is required.",
                                                call. = FALSE)
config_path <- normalizePath(args[[index + 1L]], winslash = "/", mustWork = TRUE)
cfg <- jsonlite::read_json(config_path, simplifyVector = TRUE)
repo_root <- normalizePath(cfg$repo_root, winslash = "/", mustWork = TRUE)
Sys.setenv(
  OMP_NUM_THREADS = "1", OPENBLAS_NUM_THREADS = "1", MKL_NUM_THREADS = "1",
  VECLIB_MAXIMUM_THREADS = "1", NUMEXPR_NUM_THREADS = "1",
  RCPP_PARALLEL_NUM_THREADS = "1"
)
suppressPackageStartupMessages(pkgload::load_all(repo_root, quiet = TRUE))
for (path in c(
  "independent_qdesn_full_redesign_v2.R",
  "independent_qdesn_full_redesign_v2_runtime.R",
  "independent_qdesn_cellwise_refinement_v2_superseded_closeout.R",
  "independent_qdesn_corrected_forecast_v3.R",
  "independent_qdesn_corrected_forecast_v3_campaign.R",
  "independent_qdesn_corrected_broad_v4.R"
)) source(file.path(repo_root, "validation", "fitforecast_v2", "R", path))

environment <- iqfr_v2_read_json(file.path(
  cfg$run_root, "manifests", "environment.json"
))
observed_head <- system2("git", c("-C", repo_root, "rev-parse", "HEAD"),
                         stdout = TRUE)
source_version <- as.character(read.dcf(
  file.path(repo_root, "DESCRIPTION"), fields = "Version"
)[[1L]])
loaded_version <- as.character(utils::packageVersion("exdqlm"))
checks <- c(
  schema = identical(as.character(cfg$schema_version), iqcb_v4_schema),
  source_version = identical(source_version, "1.1.1"),
  loaded_version = identical(loaded_version, "1.1.1"),
  head = identical(as.character(environment$head), observed_head),
  protocol = identical(cfg$protocol_sha256, iqfr_v2_sha256(file.path(
    repo_root, iqcb_v4_protocol_relpath
  )))
)
if (any(!checks)) {
  stop("Corrected-broad v4 worker provenance contract failed: ",
       paste(names(checks)[!checks], collapse = ", "), call. = FALSE)
}
iqcf_v3_run_job(config_path)

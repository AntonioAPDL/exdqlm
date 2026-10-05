#!/usr/bin/env Rscript
args <- commandArgs(TRUE)
repo <- normalizePath(args[1]); mode <- args[2]
setwd(repo)
Sys.setenv(OMP_NUM_THREADS = "1", OPENBLAS_NUM_THREADS = "1", MKL_NUM_THREADS = "1",
  VECLIB_MAXIMUM_THREADS = "1", RCPP_PARALLEL_NUM_THREADS = "1")
suppressPackageStartupMessages(pkgload::load_all(repo, quiet = TRUE, compile = FALSE))
source("validation/fitforecast_v2/R/independent_qdesn_targeted_forecast_v11.R")
iqtf_v11_source(repo)
stopifnot(as.character(packageVersion("exdqlm")) == "1.1.1")
switch(mode,
  materialize = iqtf_v11_materialize(repo, args[3], args[4], args[5], args[6]),
  worker = iqtf_v11_worker(args[3]),
  advance = iqtf_v11_advance(repo, args[3], args[4]),
  dispatch = {
    run <- args[3]; stage <- args[4]
    for (f in c("source_hashes.csv", "materialization_hashes.csv")) iqtf_v11_verify(file.path(run, f))
    iqtf_v11_verify(file.path(run, "plans", paste0(stage, "__hashes.csv")))
    p <- read.csv(file.path(run, "plans", paste0(stage, ".csv")))
    stopifnot(!anyDuplicated(p$job_id), !anyDuplicated(p$config_path),
      !anyDuplicated(p$status_path), all(grepl("^[A-Za-z0-9_-]+$", p$job_id)),
      !any(file.exists(p$status_path)))
    if (nrow(p)) cat(paste(p$job_id, p$config_path, sep = "\t"), sep = "\n")
  },
  health = cat(jsonlite::toJSON(iqtf_v11_health(args[3]), pretty = TRUE, auto_unbox = TRUE), "\n"),
  closeout = iqtf_v11_closeout(args[3]),
  stop("Unknown targeted forecast command."))

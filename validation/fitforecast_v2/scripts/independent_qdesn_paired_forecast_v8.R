#!/usr/bin/env Rscript
args <- commandArgs(TRUE)
repo <- normalizePath(args[1]); action <- args[2]; root <- args[3]
setwd(repo)
Sys.setenv(OMP_NUM_THREADS = "1", OPENBLAS_NUM_THREADS = "1", MKL_NUM_THREADS = "1")
suppressPackageStartupMessages(pkgload::load_all(repo, quiet = TRUE, compile = FALSE))
source("validation/fitforecast_v2/R/independent_qdesn_paired_forecast_v8.R")
iqps_v8_source(repo)
switch(action,
  materialize = iqps_v8_materialize(repo, args[4], root, args[5], args[6]),
  worker = iqps_v8_worker(root), cost_gate = iqps_v8_cost_gate(root),
  replay_gate = iqps_v8_replay_gate(root), audit = iqps_v8_audit(root),
  health = print(iqps_v8_health(root), row.names = FALSE), stop("Unknown action."))

#!/usr/bin/env Rscript
args <- commandArgs(TRUE)
repo <- normalizePath(args[1]); action <- args[2]; root <- args[3]
setwd(repo)
Sys.setenv(OMP_NUM_THREADS = "1", OPENBLAS_NUM_THREADS = "1", MKL_NUM_THREADS = "1")
suppressPackageStartupMessages(pkgload::load_all(repo, quiet = TRUE, compile = FALSE))
source("validation/fitforecast_v2/R/independent_qdesn_mcmc_bridge_v9.R")
iqmb_v9_source(repo)
switch(action,
  materialize = iqmb_v9_materialize(repo, args[4], root, args[5], args[6]),
  worker = iqmb_v9_worker(root),
  cost_gate = print(iqmb_v9_cost_gate(root)),
  pilot_gate = print(iqmb_v9_pilot_gate(root)),
  audit = iqmb_v9_audit(root),
  health = print(iqmb_v9_health(root)),
  stop("Unknown v9 action."))

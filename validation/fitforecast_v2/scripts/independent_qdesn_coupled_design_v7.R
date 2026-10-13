#!/usr/bin/env Rscript
args <- commandArgs(TRUE)
if (length(args) < 3L) stop("Usage: REPO ACTION TARGET [V6_RUN]")
repo <- normalizePath(args[1]); action <- args[2]; target <- args[3]
setwd(repo)
Sys.setenv(OMP_NUM_THREADS = "1", OPENBLAS_NUM_THREADS = "1", MKL_NUM_THREADS = "1")
source("validation/fitforecast_v2/R/independent_qdesn_coupled_design_v7.R")
iqdr_v7_source(repo)
if (action %in% c("materialize", "worker")) {
  suppressPackageStartupMessages(pkgload::load_all(repo, quiet = TRUE, compile = FALSE))
  stopifnot(as.character(packageVersion("exdqlm")) == "1.1.1")
}
switch(action,
  materialize = {stopifnot(length(args) == 4L); iqdr_v7_materialize(repo, normalizePath(args[4]), target)},
  worker = iqdr_v7_worker(normalizePath(target)),
  health = print(iqdr_v7_health(normalizePath(target)), row.names = FALSE),
  `cost-gate` = print(iqdr_v7_cost_gate(normalizePath(target)), row.names = FALSE),
  audit = iqdr_v7_audit(normalizePath(target)),
  stop("Unknown action: ", action))

#!/usr/bin/env Rscript
args <- commandArgs(TRUE)
if (length(args) < 3L) stop("Usage: REPO ACTION TARGET [V5_RUN]")
repo <- normalizePath(args[1]); action <- args[2]; target <- args[3]
setwd(repo)
Sys.setenv(OMP_NUM_THREADS = "1", OPENBLAS_NUM_THREADS = "1", MKL_NUM_THREADS = "1")
source("validation/fitforecast_v2/R/independent_qdesn_coupled_tau_v6.R")
iqct_v6_source(repo)
if (action %in% c("materialize", "worker", "wide-benchmark")) {
  suppressPackageStartupMessages(pkgload::load_all(repo, quiet = TRUE, compile = FALSE))
  stopifnot(as.character(packageVersion("exdqlm")) == "1.1.1")
}
switch(action,
  materialize = { stopifnot(length(args) == 4L); iqct_v6_materialize(repo, normalizePath(args[4]), target) },
  worker = iqct_v6_worker(normalizePath(target)),
  health = print(iqct_v6_health(normalizePath(target)), row.names = FALSE),
  `replay-gate` = iqct_v6_replay_gate(normalizePath(target)),
  audit = iqct_v6_audit(normalizePath(target)),
  `wide-benchmark` = iqct_v6_wide_benchmark(normalizePath(target)),
  stop("Unknown action: ", action))

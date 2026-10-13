#!/usr/bin/env Rscript
args <- commandArgs(TRUE)
if (length(args) < 3L) stop("Usage: Rscript independent_qdesn_beta_solver_v5.R REPO ACTION RUN_OR_CONFIG [V4_RUN]")
repo <- normalizePath(args[1]); action <- args[2]; target <- args[3]
setwd(repo)
Sys.setenv(OMP_NUM_THREADS = "1", OPENBLAS_NUM_THREADS = "1", MKL_NUM_THREADS = "1")
source(file.path(repo, "validation/fitforecast_v2/R/independent_qdesn_beta_solver_v5.R"))
iqbs_v5_source(repo)
if (action %in% c("materialize", "worker")) {
  suppressPackageStartupMessages(pkgload::load_all(repo, quiet = TRUE, compile = FALSE))
  stopifnot(as.character(packageVersion("exdqlm")) == "1.1.1")
}
switch(action,
  freeze = {
    stopifnot(length(args) == 4L)
    evidence <- file.path(repo, "validation/fitforecast_v2/local_trackers/beta_solver_v5_closeout_20261001")
    stopifnot(file.exists(file.path(evidence, "stop_finished_at.txt")),
      file.info(file.path(evidence, "workers_after_stop.txt"))$size == 0)
    iqbs_v5_freeze_v4(normalizePath(args[4]), target)
  },
  materialize = { stopifnot(length(args) == 4L); iqbs_v5_materialize(repo, normalizePath(args[4]), target) },
  worker = iqbs_v5_worker(normalizePath(target)),
  health = print(iqbs_v5_health(normalizePath(target)), row.names = FALSE),
  audit = { if (!isTRUE(iqbs_v5_audit(normalizePath(target)))) quit(status = 2L) },
  stop("Unknown action: ", action))

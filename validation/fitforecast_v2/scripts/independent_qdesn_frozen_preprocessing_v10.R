#!/usr/bin/env Rscript
args <- commandArgs(TRUE)
repo <- normalizePath(args[1]);mode <- args[2]
setwd(repo)
Sys.setenv(OMP_NUM_THREADS="1",OPENBLAS_NUM_THREADS="1",MKL_NUM_THREADS="1",
  VECLIB_MAXIMUM_THREADS="1",RCPP_PARALLEL_NUM_THREADS="1")
suppressPackageStartupMessages(pkgload::load_all(repo,quiet=TRUE,compile=FALSE))
source("validation/fitforecast_v2/R/independent_qdesn_frozen_preprocessing_v10.R")
iqfp_v10_source(repo)
if(mode!="health")trace("exal_mcmc_fit",tracer=quote(stop("MCMC refitting is forbidden in the v10 replay.")),
  where=asNamespace("exdqlm"),print=FALSE)
switch(mode,
  preflight=print(iqfp_v10_preflight(repo,args[3],args[4])),
  materialize=print(iqfp_v10_materialize(repo,args[3],args[4],args[5],args[6])),
  worker=iqfp_v10_worker(args[3]),
  io_smoke=iqfp_v10_io_smoke(repo,args[3],args[4]),
  health=cat(jsonlite::toJSON(iqfp_v10_health(args[3]),pretty=TRUE,auto_unbox=TRUE),"\n"),
  closeout=iqfp_v10_closeout(args[3]),
  stop("Unknown v10 command."))

#!/usr/bin/env Rscript
args <- commandArgs(trailingOnly = TRUE)
stopifnot(length(args) >= 4L)
command <- args[1L]; repo <- normalizePath(args[2L], mustWork = TRUE)
for (file in c("independent_qdesn_training1000_runtime_v1.R",
    "independent_qdesn_training1000_campaign_v1.R", "independent_qdesn_sentinel_mechanism_v1.R",
    "independent_qdesn_training_size_mechanism_v6.R", "independent_qdesn_gausmix_conditioning_v7.R",
    "independent_qdesn_forecast_uncertainty_v8.R", "independent_qdesn_rhs_uncertainty_v9.R",
    "independent_qdesn_layerwise_readout_v10.R", "independent_qdesn_fresh_dgp_v11.R",
    "independent_qdesn_dynamic_location_v12.R", "independent_qdesn_readout_memory_v13.R",
    "independent_qdesn_readout_memory_v13_closeout.R"))
  source(file.path(repo, "validation/fitforecast_v2/R", file))
if (command == "create") {
  stopifnot(length(args) == 5L)
  irm13_closeout_create(repo, args[3L], args[4L], args[5L])
  cat("v13 closed; no article replacement and no new jobs authorized\n")
} else if (command == "verify") {
  stopifnot(length(args) == 4L)
  irm13_closeout_verify(args[3L], args[4L]); cat("v13 closeout and evidence verified\n")
} else stop("Unknown closeout command: ", command)

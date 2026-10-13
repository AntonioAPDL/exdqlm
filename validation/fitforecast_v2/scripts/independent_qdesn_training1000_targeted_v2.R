args <- commandArgs(trailingOnly = TRUE)
stopifnot(length(args) >= 2L)
action <- args[1]; repo <- normalizePath(args[2], mustWork = TRUE)
source(file.path(repo, "validation/fitforecast_v2/R/independent_qdesn_training1000_runtime_v1.R"))
source(file.path(repo, "validation/fitforecast_v2/R/independent_qdesn_training1000_campaign_v1.R"))
source(file.path(repo, "validation/fitforecast_v2/R/independent_qdesn_training1000_targeted_v2.R"))
if (action == "materialize") {
  stopifnot(length(args) == 5L)
  invisible(iqt12t_materialize(repo, args[3], args[4],
    file.path(repo, "validation/fitforecast_v2/local_trackers/training1000_exdqlm112_runtime/Rlib"), args[5]))
} else if (action == "advance") {
  result <- iqt12t_advance(args[3], args[4])
  if (result == "COMPLETE_NO_MCMC_DEVELOPMENT_FORECAST_GAIN") {
    iqt12_json(list(status = result, final_block_scored = FALSE, article_changed = FALSE),
      file.path(args[3], "early_complete.json"))
  }
  cat(result, "\n")
} else {
  source(file.path(repo, "validation/fitforecast_v2/scripts/independent_qdesn_training1000_v1.R"))
}

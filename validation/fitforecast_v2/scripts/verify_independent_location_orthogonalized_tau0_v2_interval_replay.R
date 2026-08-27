#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
arg <- function(flag, default = NULL) {
  i <- which(args == flag)
  if (!length(i) || i[[1L]] >= length(args)) default else args[[i[[1L]] + 1L]]
}
repo <- normalizePath(
  arg("--repo-root", system("git rev-parse --show-toplevel", intern = TRUE)),
  winslash = "/", mustWork = TRUE
)
setwd(repo)
source(file.path(repo, "validation", "fitforecast_v2", "R", "utils.R"))
source(file.path(
  repo, "validation", "fitforecast_v2", "R",
  "independent_location_orthogonalized_tau0_v2.R"
))
source(file.path(
  repo, "validation", "fitforecast_v2", "R",
  "independent_location_orthogonalized_tau0_v2_promotion.R"
))
source(file.path(
  repo, "validation", "fitforecast_v2", "R",
  "independent_location_orthogonalized_tau0_v2_interval_replay.R"
))
result <- idolv2r_verify_runtime(
  repo, output_root = arg("--materialization-root"),
  closeout_root = arg("--closeout-root"), run_tag = arg("--run-tag")
)
cat(sprintf(
  "INTERVAL_REPLAY_VERIFY_PASS chains=%d draws=%d decision=%s\n",
  nrow(result$runtime), result$decision$total_metric_draws,
  result$decision$interval_precision_decision
))

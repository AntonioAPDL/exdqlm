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
result <- idolv2r_materialize(
  repo, output_root = arg("--output-root"),
  run_id = arg("--run-id"), run_tag = arg("--run-tag")
)
cat(sprintf(
  "INTERVAL_REPLAY_MATERIALIZED jobs=%d draws_per_chain=%d\n",
  nrow(result$plan), idolv2r_draws_per_chain
))

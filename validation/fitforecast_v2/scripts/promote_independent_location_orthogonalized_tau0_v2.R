#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
repo_arg <- grep("^--repo-root=", args, value = TRUE)
repo <- if (length(repo_arg)) sub("^--repo-root=", "", repo_arg[[1L]]) else
  system("git rev-parse --show-toplevel", intern = TRUE)
repo <- normalizePath(repo, winslash = "/", mustWork = TRUE)
setwd(repo)
source(file.path(repo, "validation", "fitforecast_v2", "R", "utils.R"))
source(file.path(
  repo, "validation", "fitforecast_v2", "R",
  "independent_location_orthogonalized_tau0_v2_promotion.R"
))
result <- idolp_v2_materialize(repo)
cat(sprintf(
  paste0(
    "PROMOTION_READY point=%s interval=%s audit=%s ",
    "metrics=%d interval_decision=%s\n"
  ),
  idolp_v2_point_id, idolp_v2_interval_id, idolp_v2_audit_id,
  nrow(result$evidence$promoted), result$sensitivity$decision
))

#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  if (!requireNamespace("jsonlite", quietly = TRUE)) stop("jsonlite is required.")
})
args <- commandArgs(trailingOnly = TRUE)
get_arg <- function(flag, default = NULL) {
  i <- which(args == flag)
  if (!length(i) || i[[1L]] >= length(args)) return(default)
  args[[i[[1L]] + 1L]]
}
repo_root <- normalizePath(get_arg(
  "--repo-root", system("git rev-parse --show-toplevel", intern = TRUE)
), winslash = "/", mustWork = TRUE)
setwd(repo_root)
source(file.path(repo_root, "validation", "fitforecast_v2", "R",
                 "qdesn_tierb_cellwise_mcmc_v1.R"))
state_root <- normalizePath(get_arg("--state-root"), winslash = "/", mustWork = TRUE)
output <- normalizePath(get_arg(
  "--output", file.path(state_root, "replication_handoff_verification.json")
), winslash = "/", mustWork = FALSE)
materialization_root <- file.path(state_root, "materialization")
adaptive_root <- file.path(state_root, "adaptive")

gate <- qdesn_ssv2_read_csv(file.path(adaptive_root, "tier_b_discovery_gate.csv"))
advance <- qdesn_ssv2_read_json(file.path(
  adaptive_root, "advance_after_tier_b_discovery.json"
))
ranking <- qdesn_ssv2_read_csv(file.path(
  adaptive_root, "tier_b_replication_ranking.csv"
))
plan <- qdesn_ssv2_read_csv(file.path(adaptive_root, "tier_b_replication_plan.csv"))
targets <- qdesn_ssv2_read_csv(file.path(
  repo_root, "config", "validation",
  paste0(qdesn_tbcv1_stage, "_target_cells.csv")
))
targets <- targets[targets$tier == "B", , drop = FALSE]

jobs <- lapply(plan$config_path, qdesn_ssv2_read_json)
job_checks <- vapply(seq_along(jobs), function(i) {
  job <- jobs[[i]]
  row <- plan[i, , drop = FALSE]
  identical(as.character(job$job_id), as.character(row$job_id)) &&
    identical(as.character(job$stage), "tier_b_replication") &&
    identical(as.character(job$source_id), "dev19") &&
    identical(as.character(job$reservoir_seed_id), "r02") &&
    identical(as.character(job$source_registry_hash_value), qdesn_ssv2_registry_hash) &&
    identical(as.character(job$study_contract$package_version), "1.0.0") &&
    identical(as.integer(job$study_contract$train_window), c(8501L, 9000L)) &&
    identical(as.integer(job$study_contract$forecast_window), c(9001L, 10000L)) &&
    identical(as.integer(job$study_contract$max_lead), 30L) &&
    identical(as.integer(job$study_contract$origin_stride), 30L) &&
    identical(as.integer(job$config$inference$mcmc$n_burn), 1000L) &&
    identical(as.integer(job$config$inference$mcmc$n_mcmc), 3000L) &&
    identical(as.integer(job$config$cpp$postpred_threads), 1L) &&
    !isTRUE(job$config$outputs$keep_draws) &&
    !isTRUE(job$config$outputs$keep_mcmc_vb_init) &&
    !isTRUE(job$config$outputs$save_forecast_objects) &&
    !isTRUE(job$config$outputs$retain_full_rds_on_failure) &&
    identical(qdesn_ssv2_sha256(row$config_path), as.character(row$config_sha256))
}, logical(1L))

candidate_sets_match <- all(vapply(targets$target_cell_id, function(cell_id) {
  expected <- c(
    ranking$candidate_id[ranking$target_cell_id == cell_id],
    paste0("tbcv1_", cell_id, "_parent")
  )
  actual <- plan$candidate_id[plan$target_cell_id == cell_id]
  setequal(actual, expected) && length(actual) == 4L && !anyDuplicated(actual)
}, logical(1L)))

checks <- c(
  discovery_gate = nrow(gate) == 1L && isTRUE(gate$gate_pass[[1L]]) &&
    gate$complete_artifact_jobs[[1L]] == 108L && gate$failed_jobs[[1L]] == 0L &&
    gate$missing_jobs[[1L]] == 0L,
  advancement = identical(as.character(advance$decision),
                          "advance_to_tier_b_replication"),
  target_cells = nrow(targets) == 4L && length(unique(plan$target_cell_id)) == 4L,
  ranking = nrow(ranking) == 12L && all(table(ranking$target_cell_id) == 3L) &&
    all(table(ranking$rank) == 4L),
  plan_shape = nrow(plan) == 16L && all(table(plan$target_cell_id) == 4L),
  paired_source = identical(unique(plan$source_id), "dev19") &&
    identical(unique(plan$source_role), "replication"),
  independent_reservoir = identical(unique(plan$reservoir_seed_id), "r02"),
  candidate_sets = candidate_sets_match,
  config_paths = !anyDuplicated(plan$config_path) && all(file.exists(plan$config_path)),
  config_hashes = all(job_checks),
  branch = identical(system("git branch --show-current", intern = TRUE),
                     qdesn_tbcv1_branch)
)
result <- list(
  schema_version = "qdesn_tierb_cellwise_mcmc_v1_replication_handoff_v1",
  generated_at = as.character(Sys.time()),
  decision = if (all(checks)) "PASS" else "FAIL",
  checks = as.list(checks),
  discovery_jobs = 108L,
  replication_jobs = nrow(plan),
  replication_source = unique(plan$source_id),
  reservoir_seed_id = unique(plan$reservoir_seed_id),
  plan_sha256 = qdesn_ssv2_sha256(file.path(
    adaptive_root, "tier_b_replication_plan.csv"
  ))
)
qdesn_ssv2_write_json(result, output)
cat(sprintf("replication_handoff decision=%s checks=%d jobs=%d output=%s\n",
            result$decision, length(checks), nrow(plan), output))
if (!all(checks)) {
  stop(sprintf("Replication handoff failed: %s",
               paste(names(checks)[!checks], collapse = ", ")), call. = FALSE)
}

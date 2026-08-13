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
  "--output", file.path(state_root, "tier_b_sealed_handoff_verification.json")
), winslash = "/", mustWork = FALSE)
adaptive_root <- file.path(state_root, "adaptive")

gate <- qdesn_ssv2_read_csv(file.path(adaptive_root, "tier_b_replication_gate.csv"))
advance <- qdesn_ssv2_read_json(file.path(
  adaptive_root, "advance_after_tier_b_replication.json"
))
ranking <- qdesn_ssv2_read_csv(file.path(adaptive_root, "tier_b_sealed_ranking.csv"))
plan_path <- file.path(adaptive_root, "tier_b_sealed_plan.csv")
plan <- qdesn_ssv2_read_csv(plan_path)
targets <- qdesn_ssv2_read_csv(file.path(
  repo_root, "config", "validation", paste0(qdesn_tbcv1_stage, "_target_cells.csv")
))
targets <- targets[targets$tier == "B", , drop = FALSE]
run_env <- readLines(file.path(state_root, "run_tags.env"), warn = FALSE)
design_commit <- sub("^GIT_COMMIT=", "", run_env[grepl("^GIT_COMMIT=", run_env)])
execution_commit <- system("git rev-parse HEAD", intern = TRUE)

jobs <- lapply(plan$config_path, qdesn_ssv2_read_json)
job_checks <- vapply(seq_along(jobs), function(i) {
  job <- jobs[[i]]
  row <- plan[i, , drop = FALSE]
  likelihood <- as.character(job$likelihood_target)
  identical(as.character(job$job_id), as.character(row$job_id)) &&
    identical(as.character(job$stage), "tier_b_sealed") &&
    job$source_id %in% c("dev20", "dev21", "dev22", "dev23") &&
    identical(as.character(job$source_role), "sealed_holdout") &&
    identical(as.character(job$reservoir_seed_id), "r03") &&
    identical(as.character(job$source_registry_hash_value), qdesn_ssv2_registry_hash) &&
    identical(as.character(job$study_contract$package_version), "1.0.0") &&
    identical(as.integer(job$study_contract$train_window), c(8501L, 9000L)) &&
    identical(as.integer(job$study_contract$forecast_window), c(9001L, 10000L)) &&
    identical(as.integer(job$study_contract$max_lead), 30L) &&
    identical(as.integer(job$study_contract$origin_stride), 30L) &&
    !isTRUE(job$config$metrics$rolling_origin$refit_per_origin) &&
    identical(as.integer(job$config$inference$mcmc$n_burn), 1000L) &&
    identical(as.integer(job$config$inference$mcmc$n_mcmc), 3000L) &&
    identical(as.integer(job$config$cpp$postpred_threads), 1L) &&
    identical(likelihood, "al") && !identical(
      as.character(job$config$inference$mcmc$slice$core_update_mode),
      qdesn_ssv2_method_id
    ) &&
    !isTRUE(job$config$outputs$keep_draws) &&
    !isTRUE(job$config$outputs$keep_mcmc_vb_init) &&
    !isTRUE(job$config$outputs$save_forecast_objects) &&
    !isTRUE(job$config$outputs$retain_full_rds_on_failure) &&
    !isTRUE(job$study_contract$posterior_recycled_as_prior) &&
    file.exists(job$observed_path) &&
    identical(qdesn_ssv2_sha256(job$observed_path), job$observed_sha256) &&
    identical(qdesn_ssv2_sha256(row$config_path), as.character(row$config_sha256))
}, logical(1L))

candidate_sets_match <- all(vapply(targets$target_cell_id, function(cell_id) {
  expected <- c(
    ranking$candidate_id[ranking$target_cell_id == cell_id],
    paste0("tbcv1_", cell_id, "_parent")
  )
  all(vapply(c("dev20", "dev21", "dev22", "dev23"), function(source_id) {
    actual <- plan$candidate_id[
      plan$target_cell_id == cell_id & plan$source_id == source_id
    ]
    setequal(actual, expected) && length(actual) == 3L && !anyDuplicated(actual)
  }, logical(1L)))
}, logical(1L)))

ancestor_status <- system2(
  "git", c("merge-base", "--is-ancestor", design_commit, execution_commit),
  stdout = FALSE, stderr = FALSE
)
changed_paths <- system2(
  "git", c("diff", "--name-only", paste0(design_commit, "..", execution_commit)),
  stdout = TRUE
)
allowed_changes <- grepl(
  paste0(
    "^validation/fitforecast_v2/(docs/QDESN_TIERB_CELLWISE_MCMC_V1_",
    "PROTOCOL_2026-08-13[.]md|scripts/.*qdesn_tierb_cellwise_mcmc_v1.*|",
    "tests/testthat/test-qdesn-tierb-cellwise-mcmc-v1[.]R)$"
  ),
  changed_paths
)

checks <- c(
  replication_gate = nrow(gate) == 1L && isTRUE(gate$gate_pass[[1L]]) &&
    gate$complete_artifact_jobs[[1L]] == 16L && gate$failed_jobs[[1L]] == 0L &&
    gate$missing_jobs[[1L]] == 0L,
  advancement = identical(as.character(advance$decision), "advance_to_tier_b_sealed"),
  target_cells = nrow(targets) == 4L && length(unique(plan$target_cell_id)) == 4L,
  ranking = nrow(ranking) == 8L && all(table(ranking$target_cell_id) == 2L) &&
    all(table(ranking$rank) == 4L),
  plan_shape = nrow(plan) == 48L && all(table(plan$target_cell_id) == 12L) &&
    all(table(plan$target_cell_id, plan$source_id) == 3L),
  sealed_sources = setequal(unique(plan$source_id), c(
    "dev20", "dev21", "dev22", "dev23"
  )) && identical(unique(plan$source_role), "sealed_holdout"),
  independent_reservoir = identical(unique(plan$reservoir_seed_id), "r03"),
  candidate_sets = candidate_sets_match,
  config_paths = !anyDuplicated(plan$config_path) && all(file.exists(plan$config_path)),
  job_contracts = all(job_checks),
  design_ancestor = length(design_commit) == 1L && nzchar(design_commit) &&
    ancestor_status == 0L,
  computational_kernel_unchanged = !length(changed_paths) || all(allowed_changes),
  branch = identical(system("git branch --show-current", intern = TRUE),
                     qdesn_tbcv1_branch)
)
result <- list(
  schema_version = "qdesn_tierb_cellwise_mcmc_v1_sealed_handoff_v1",
  generated_at = as.character(Sys.time()),
  decision = if (all(checks)) "PASS" else "FAIL",
  checks = as.list(checks),
  campaign_design_commit = design_commit,
  execution_commit = execution_commit,
  changed_paths_since_design = as.list(changed_paths),
  sealed_jobs = nrow(plan),
  sealed_sources = as.list(sort(unique(plan$source_id))),
  reservoir_seed_id = unique(plan$reservoir_seed_id),
  plan_sha256 = qdesn_ssv2_sha256(plan_path),
  canonical_source_registry_hash_value = qdesn_ssv2_registry_hash,
  article_update_automatic = FALSE,
  canonical_confirmation_launch_automatic = FALSE
)
qdesn_ssv2_write_json(result, output)
cat(sprintf("sealed_handoff decision=%s checks=%d jobs=%d output=%s\n",
            result$decision, length(checks), nrow(plan), output))
if (!all(checks)) {
  stop(sprintf("Sealed handoff failed: %s",
               paste(names(checks)[!checks], collapse = ", ")), call. = FALSE)
}

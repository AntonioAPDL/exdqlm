#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  if (!requireNamespace("jsonlite", quietly = TRUE)) {
    stop("Missing package: jsonlite", call. = FALSE)
  }
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
                 "independent_exal_m0_structural_screen_v2.R"))

materialization_root <- normalizePath(get_arg(
  "--materialization-root",
  file.path(repo_root, "reports", "shared_fitforecast_v2_orchestration",
            "independent_exal_m0_paired_rolling_repair_v1_materialization")
), winslash = "/", mustWork = TRUE)
plan_name <- as.character(get_arg("--plan", "smoke_plan.csv"))[1L]
run_tag <- as.character(get_arg("--run-tag", ""))[1L]
output_path <- get_arg(
  "--output",
  file.path(materialization_root, sub("[.]csv$", "_verification.json", plan_name))
)
if (!grepl("^/", output_path)) output_path <- file.path(repo_root, output_path)

manifest_path <- file.path(materialization_root, "materialization_manifest.json")
manifest <- qdesn_ssv2_read_json(manifest_path)
plan_path <- file.path(materialization_root, plan_name)
plan <- qdesn_ssv2_read_csv(plan_path)
manifest_plan <- if (identical(plan_name, "smoke_plan.csv")) {
  manifest$outputs$smoke_plan
} else if (identical(plan_name, "calibration_plan.csv")) {
  manifest$outputs$calibration_plan
} else {
  stop("--plan must be smoke_plan.csv or calibration_plan.csv.", call. = FALSE)
}

static_rows <- lapply(seq_len(nrow(plan)), function(i) {
  row <- plan[i, , drop = FALSE]
  config_path <- as.character(row$config_path[[1L]])
  job <- qdesn_ssv2_read_json(config_path)
  source_series <- qdesn_ssv2_read_csv(job$root_spec$source_series_wide_path)
  checks <- c(
    config_exists = file.exists(config_path),
    config_hash = identical(qdesn_ssv2_sha256(config_path), row$config_sha256[[1L]]),
    job_id = identical(as.character(job$job_id), row$job_id[[1L]]),
    method = identical(as.character(job$inference_method_id),
                       "M0_v_collapsed_support_logit"),
    seed_mode = identical(as.character(job$seed_contract_mode),
                          "paired_target_cell_panel_independent_of_source_and_candidate"),
    reservoir_id = identical(as.character(job$reservoir_seed_id),
                             row$reservoir_seed_id[[1L]]),
    reservoir_seed = identical(as.integer(job$reservoir_seed),
                               as.integer(row$reservoir_seed[[1L]])),
    source_index_column = "source_index" %in% names(source_series),
    local_t_column = "t" %in% names(source_series),
    local_global_rows = all(c("source_index", "t") %in% names(source_series)) &&
      identical(as.integer(source_series$t), seq_len(nrow(source_series))) &&
      identical(as.integer(source_series$source_index),
                as.integer(job$root_spec$raw_start_source_index):10000L),
    train_window = identical(as.integer(c(
      job$root_spec$train_start_source_index,
      job$root_spec$train_end_source_index
    )), c(8501L, 9000L)),
    forecast_window = identical(as.integer(c(
      job$root_spec$forecast_start_source_index,
      job$root_spec$forecast_end_source_index
    )), c(9001L, 10000L)),
    max_lead = identical(as.integer(
      job$config$metrics$rolling_origin$max_lead_configured
    ), 30L),
    stride = identical(as.integer(
      job$config$metrics$rolling_origin$origin_stride
    ), 30L),
    no_refit = !isTRUE(job$config$metrics$rolling_origin$refit_per_origin),
    required_export = isTRUE(job$config$metrics$rolling_origin$require_lead_export),
    one_thread = identical(as.integer(job$config$cpp$postpred_threads), 1L),
    no_draw_retention = !isTRUE(job$config$outputs$keep_draws),
    no_forecast_objects = !isTRUE(job$config$outputs$save_forecast_objects),
    no_failure_payload = !isTRUE(job$config$outputs$retain_full_rds_on_failure),
    no_auto_promotion = !isTRUE(job$study_contract$article_promotion_automatic)
  )
  checks[is.na(checks)] <- FALSE
  data.frame(
    job_id = row$job_id[[1L]],
    target_cell_id = row$target_cell_id[[1L]],
    candidate_role = row$candidate_role[[1L]],
    source_id = row$source_id[[1L]],
    reservoir_seed_id = row$reservoir_seed_id[[1L]],
    decision = if (all(checks)) "PASS" else "FAIL",
    failed_checks = paste(names(checks)[!checks], collapse = ";"),
    stringsAsFactors = FALSE
  )
})
static <- do.call(rbind, static_rows)

pair_key <- paste(plan$target_cell_id, plan$source_id, plan$reservoir_seed_id,
                  sep = "|")
pair_groups <- split(plan, pair_key)
pair_rows <- lapply(names(pair_groups), function(key) {
  x <- pair_groups[[key]]
  checks <- c(
    two_designs = nrow(x) == 2L,
    roles = identical(sort(x$candidate_role),
                      sort(c("current_anchor", "prior_screen_finalist"))),
    shared_source = length(unique(x$source_id)) == 1L,
    shared_reservoir_seed = length(unique(x$reservoir_seed)) == 1L,
    distinct_mcmc_seed = length(unique(x$mcmc_seed)) == 2L
  )
  checks[is.na(checks)] <- FALSE
  data.frame(
    pair_key = key,
    decision = if (all(checks)) "PASS" else "FAIL",
    failed_checks = paste(names(checks)[!checks], collapse = ";"),
    stringsAsFactors = FALSE
  )
})
pairs <- do.call(rbind, pair_rows)

runtime <- data.frame()
if (nzchar(run_tag)) {
  runtime_rows <- lapply(seq_len(nrow(plan)), function(i) {
    row <- plan[i, , drop = FALSE]
    job_root <- qdesn_ssv2_job_root(repo_root, run_tag, row$job_id[[1L]])
    status_path <- file.path(job_root, "job_status.json")
    status <- if (file.exists(status_path)) {
      tryCatch(qdesn_ssv2_read_json(status_path), error = function(e) NULL)
    } else NULL
    rolling <- qdesn_ssv2_rolling_artifact_audit(job_root)
    checks <- c(
      status_file = !is.null(status),
      status_success = !is.null(status) && identical(as.character(status$status), "SUCCESS"),
      config_hash = !is.null(status) && identical(
        as.character(status$config_sha256), row$config_sha256[[1L]]
      ),
      objective_finite = !is.null(status) && is.finite(as.numeric(status$objective_value)),
      rolling_contract = identical(rolling$decision, "PASS"),
      no_binary_payloads = !length(list.files(
        job_root, pattern = "[.](rds|rda|RData)$", recursive = TRUE,
        full.names = TRUE, ignore.case = TRUE
      ))
    )
    checks[is.na(checks)] <- FALSE
    data.frame(
      job_id = row$job_id[[1L]],
      target_cell_id = row$target_cell_id[[1L]],
      candidate_role = row$candidate_role[[1L]],
      source_id = row$source_id[[1L]],
      reservoir_seed_id = row$reservoir_seed_id[[1L]],
      status = if (is.null(status)) "MISSING" else as.character(status$status),
      objective_metric = row$objective_metric[[1L]],
      objective_value = if (is.null(status)) NA_real_ else as.numeric(status$objective_value),
      rolling_mae = rolling$forecast_qtrue_mae,
      rolling_check = rolling$forecast_check_loss,
      decision = if (all(checks)) "PASS" else "FAIL",
      failed_checks = paste(names(checks)[!checks], collapse = ";"),
      stringsAsFactors = FALSE
    )
  })
  runtime <- do.call(rbind, runtime_rows)
  qdesn_ssv2_write_csv(runtime, sub("[.]json$", "_runtime.csv", output_path))
}

materialization_binaries <- list.files(
  materialization_root, pattern = "[.](rds|rda|RData)$", recursive = TRUE,
  full.names = TRUE, ignore.case = TRUE
)
checks <- c(
  manifest_plan_hash = identical(qdesn_ssv2_sha256(plan_path),
                                 as.character(manifest_plan$sha256)),
  manifest_method = identical(as.character(manifest$method_id),
                              "M0_v_collapsed_support_logit"),
  manifest_registry = identical(as.character(manifest$source_registry_hash_value),
                                qdesn_ssv2_registry_hash),
  selection_metrics = identical(
    sort(unlist(manifest$selection_contract$metrics, use.names = FALSE)),
    sort(c(
      "fit_qtrue_rmse", "forecast_qtrue_mae_H1000",
      "forecast_check_loss_H1000"
    ))
  ),
  selection_no_minimum_effect = identical(
    as.numeric(manifest$selection_contract$minimum_effect_threshold), 0
  ) && isTRUE(
    manifest$selection_contract$promote_every_paired_consistent_metric_gain
  ),
  selection_requires_six_pairs = identical(
    as.integer(manifest$selection_contract$paired_blocks_required), 6L
  ) && identical(
    as.integer(manifest$selection_contract$pair_wins_required), 4L
  ),
  no_automatic_article_promotion = !isTRUE(
    manifest$selection_contract$article_promotion_automatic
  ),
  static_jobs = nrow(static) == nrow(plan) && all(static$decision == "PASS"),
  paired_groups = all(pairs$decision == "PASS"),
  materialization_storage_light = !length(materialization_binaries),
  runtime = !nzchar(run_tag) ||
    (nrow(runtime) == nrow(plan) && all(runtime$decision == "PASS"))
)
checks[is.na(checks)] <- FALSE
decision <- if (all(checks)) "PASS" else "FAIL"
qdesn_ssv2_write_csv(static, sub("[.]json$", "_static.csv", output_path))
qdesn_ssv2_write_csv(pairs, sub("[.]json$", "_pairs.csv", output_path))
qdesn_ssv2_write_json(list(
  generated_at = as.character(Sys.time()),
  decision = decision,
  mode = if (nzchar(run_tag)) "runtime" else "static",
  plan = list(path = plan_path, sha256 = qdesn_ssv2_sha256(plan_path), rows = nrow(plan)),
  run_tag = if (nzchar(run_tag)) run_tag else NULL,
  static_pass = sum(static$decision == "PASS"),
  paired_groups_pass = sum(pairs$decision == "PASS"),
  runtime_pass = if (nzchar(run_tag)) sum(runtime$decision == "PASS") else NULL,
  materialization_binary_payloads = as.list(materialization_binaries),
  checks = as.list(checks)
), output_path)
cat(sprintf(
  "decision=%s mode=%s jobs=%d static_pass=%d paired_groups_pass=%d runtime_pass=%s\n",
  decision, if (nzchar(run_tag)) "runtime" else "static", nrow(plan),
  sum(static$decision == "PASS"), sum(pairs$decision == "PASS"),
  if (nzchar(run_tag)) as.character(sum(runtime$decision == "PASS")) else "NA"
))
quit(save = "no", status = if (decision == "PASS") 0L else 1L)

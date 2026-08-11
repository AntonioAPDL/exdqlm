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

run_tag <- as.character(get_arg("--run-tag", ""))[1L]
if (!nzchar(run_tag)) stop("--run-tag is required.", call. = FALSE)
materialization_root <- normalizePath(get_arg(
  "--materialization-root",
  file.path(repo_root, "reports", "shared_fitforecast_v2_orchestration",
            "independent_exal_m0_paired_rolling_repair_v1_materialization")
), winslash = "/", mustWork = TRUE)
output_root <- normalizePath(get_arg(
  "--output-root",
  file.path(repo_root, "reports", "shared_fitforecast_v2_orchestration", run_tag,
            "paired_closeout")
), winslash = "/", mustWork = FALSE)
dir.create(output_root, recursive = TRUE, showWarnings = FALSE)

plan_path <- file.path(materialization_root, "calibration_plan.csv")
profiles_path <- file.path(materialization_root, "paired_candidate_profiles.csv")
targets_path <- file.path(materialization_root, "corrected_target_contract.csv")
plan <- qdesn_ssv2_read_csv(plan_path)
profiles <- qdesn_ssv2_read_csv(profiles_path)
targets <- qdesn_ssv2_read_csv(targets_path)

result_rows <- lapply(seq_len(nrow(plan)), function(i) {
  row <- plan[i, , drop = FALSE]
  job_root <- qdesn_ssv2_job_root(repo_root, run_tag, row$job_id[[1L]])
  status_path <- file.path(job_root, "job_status.json")
  status <- if (file.exists(status_path)) {
    tryCatch(qdesn_ssv2_read_json(status_path), error = function(e) NULL)
  } else NULL
  rolling <- qdesn_ssv2_rolling_artifact_audit(job_root)
  data.frame(
    job_id = row$job_id[[1L]],
    target_cell_id = row$target_cell_id[[1L]],
    candidate_id = row$candidate_id[[1L]],
    candidate_role = row$candidate_role[[1L]],
    source_id = row$source_id[[1L]],
    reservoir_seed_id = row$reservoir_seed_id[[1L]],
    objective_metric = row$objective_metric[[1L]],
    status = if (is.null(status)) "MISSING" else as.character(status$status),
    objective_value = if (is.null(status)) NA_real_ else as.numeric(status$objective_value),
    rolling_decision = rolling$decision,
    rolling_mae = rolling$forecast_qtrue_mae,
    rolling_check = rolling$forecast_check_loss,
    fit_rmse = qdesn_ssv2_metric_value(job_root, "fit_qtrue_rmse"),
    binary_payloads = length(list.files(
      job_root, pattern = "[.](rds|rda|RData)$", recursive = TRUE,
      full.names = TRUE, ignore.case = TRUE
    )),
    status_path = normalizePath(status_path, winslash = "/", mustWork = FALSE),
    stringsAsFactors = FALSE
  )
})
results <- do.call(rbind, result_rows)
results_path <- qdesn_ssv2_write_csv(
  results, file.path(output_root, "calibration_job_evidence.csv")
)

complete <- nrow(results) == nrow(plan) &&
  all(results$status == "SUCCESS") &&
  all(results$rolling_decision == "PASS") &&
  all(is.finite(results$objective_value)) &&
  !any(results$binary_payloads)
if (!complete) {
  qdesn_ssv2_write_json(list(
    generated_at = as.character(Sys.time()),
    decision = "INCOMPLETE_BLOCK_CLOSEOUT",
    run_tag = run_tag,
    jobs_expected = nrow(plan),
    jobs_success = sum(results$status == "SUCCESS"),
    rolling_pass = sum(results$rolling_decision == "PASS"),
    finite_objectives = sum(is.finite(results$objective_value)),
    binary_payloads = sum(results$binary_payloads),
    evidence = list(path = results_path, sha256 = qdesn_ssv2_sha256(results_path)),
    article_promotion_automatic = FALSE
  ), file.path(output_root, "paired_closeout_manifest.json"))
  stop("Calibration is incomplete; paired closeout is blocked.", call. = FALSE)
}

metric_columns <- c(
  fit_qtrue_rmse = "fit_rmse",
  forecast_qtrue_mae_H1000 = "rolling_mae",
  forecast_check_loss_H1000 = "rolling_check"
)
metric_results <- do.call(rbind, lapply(names(metric_columns), function(metric) {
  out <- results
  out$metric <- metric
  out$metric_value <- as.numeric(out[[metric_columns[[metric]]]])
  out
}))
metric_results_path <- qdesn_ssv2_write_csv(
  metric_results, file.path(output_root, "calibration_metric_evidence.csv")
)
if (any(!is.finite(metric_results$metric_value))) {
  stop("At least one required calibration metric is not finite.", call. = FALSE)
}

pair_keys <- unique(metric_results[c(
  "target_cell_id", "source_id", "reservoir_seed_id", "metric"
)])
pair_rows <- lapply(seq_len(nrow(pair_keys)), function(i) {
  key <- pair_keys[i, , drop = FALSE]
  x <- metric_results[
    metric_results$target_cell_id == key$target_cell_id &
      metric_results$source_id == key$source_id &
      metric_results$reservoir_seed_id == key$reservoir_seed_id &
      metric_results$metric == key$metric,
    , drop = FALSE
  ]
  anchor <- x[x$candidate_role == "current_anchor", , drop = FALSE]
  finalist <- x[x$candidate_role == "prior_screen_finalist", , drop = FALSE]
  if (nrow(anchor) != 1L || nrow(finalist) != 1L) {
    stop("A paired block does not contain exactly one anchor and finalist.", call. = FALSE)
  }
  delta <- finalist$metric_value[[1L]] - anchor$metric_value[[1L]]
  data.frame(
    target_cell_id = key$target_cell_id,
    source_id = key$source_id,
    reservoir_seed_id = key$reservoir_seed_id,
    metric = key$metric,
    is_primary_objective = identical(
      key$metric[[1L]], anchor$objective_metric[[1L]]
    ),
    anchor_candidate_id = anchor$candidate_id[[1L]],
    finalist_candidate_id = finalist$candidate_id[[1L]],
    anchor_value = anchor$metric_value[[1L]],
    finalist_value = finalist$metric_value[[1L]],
    finalist_minus_anchor = delta,
    finalist_improvement_pct = 100 * (anchor$metric_value[[1L]] -
      finalist$metric_value[[1L]]) / anchor$metric_value[[1L]],
    finalist_pair_win = delta < 0,
    stringsAsFactors = FALSE
  )
})
pairs <- do.call(rbind, pair_rows)
pairs_path <- qdesn_ssv2_write_csv(pairs, file.path(output_root, "paired_contrasts.csv"))

summary_key <- paste(pairs$target_cell_id, pairs$metric, sep = "|")
summary_rows <- lapply(split(pairs, summary_key), function(x) {
  target <- targets[targets$target_cell_id == x$target_cell_id[[1L]], , drop = FALSE]
  mean_anchor <- mean(x$anchor_value)
  mean_finalist <- mean(x$finalist_value)
  mean_delta <- mean(x$finalist_minus_anchor)
  median_delta <- stats::median(x$finalist_minus_anchor)
  wins <- sum(x$finalist_pair_win)
  eligible <- nrow(x) == 6L && mean_delta < 0 && median_delta < 0 && wins >= 4L
  data.frame(
    target_cell_id = x$target_cell_id[[1L]],
    metric = x$metric[[1L]],
    is_primary_objective = x$is_primary_objective[[1L]],
    anchor_candidate_id = x$anchor_candidate_id[[1L]],
    finalist_candidate_id = x$finalist_candidate_id[[1L]],
    paired_blocks = nrow(x),
    finalist_pair_wins = wins,
    anchor_mean = mean_anchor,
    finalist_mean = mean_finalist,
    mean_paired_delta = mean_delta,
    median_paired_delta = median_delta,
    mean_improvement_pct = 100 * (mean_anchor - mean_finalist) / mean_anchor,
    current_article_value = if (x$is_primary_objective[[1L]]) {
      target$current_value[[1L]]
    } else NA_real_,
    comparator_value = if (x$is_primary_objective[[1L]]) {
      target$comparator_value[[1L]]
    } else NA_real_,
    minimum_effect_threshold = 0,
    selection_rule = "six_complete_pairs_mean_lt_zero_median_lt_zero_wins_ge_four",
    decision = if (eligible) {
      "ELIGIBLE_FOR_CANONICAL_FULL_BUDGET_CONFIRMATION"
    } else {
      "RETAIN_CURRENT_ANCHOR"
    },
    article_promotion_automatic = FALSE,
    stringsAsFactors = FALSE
  )
})
metric_summary <- do.call(rbind, summary_rows)
metric_summary <- metric_summary[
  order(metric_summary$decision, metric_summary$target_cell_id,
        -metric_summary$mean_improvement_pct),
  , drop = FALSE
]
metric_summary_path <- qdesn_ssv2_write_csv(
  metric_summary, file.path(output_root, "paired_metric_selection_ledger.csv")
)

summary <- metric_summary[metric_summary$is_primary_objective, , drop = FALSE]
names(summary)[names(summary) == "metric"] <- "objective_metric"
summary_path <- qdesn_ssv2_write_csv(
  summary, file.path(output_root, "paired_selection_ledger.csv")
)

eligible_metrics <- metric_summary[
  metric_summary$decision == "ELIGIBLE_FOR_CANONICAL_FULL_BUDGET_CONFIRMATION",
  , drop = FALSE
]
eligible_ids <- unique(eligible_metrics$finalist_candidate_id)
confirmation <- profiles[profiles$candidate_id %in% eligible_ids, , drop = FALSE]
confirmation$selected_metrics <- rep(NA_character_, nrow(confirmation))
confirmation$selected_metric_count <- rep(0L, nrow(confirmation))
if (nrow(confirmation)) {
  selected_metric_map <- tapply(
    eligible_metrics$metric, eligible_metrics$target_cell_id,
    function(x) paste(sort(unique(x)), collapse = ";")
  )
  confirmation$selected_metrics <- unname(
    selected_metric_map[confirmation$target_cell_id]
  )
  confirmation$selected_metric_count <- lengths(strsplit(
    confirmation$selected_metrics, ";", fixed = TRUE
  ))
}
confirmation$selection_run_tag <- rep(run_tag, nrow(confirmation))
confirmation$selection_ledger_path <- rep(metric_summary_path, nrow(confirmation))
confirmation$selection_ledger_sha256 <- rep(
  qdesn_ssv2_sha256(metric_summary_path), nrow(confirmation)
)
confirmation$confirmation_state <- rep(
  "SELECTED_NOT_MATERIALIZED_NOT_LAUNCHED", nrow(confirmation)
)
confirmation$article_promotion_automatic <- rep(FALSE, nrow(confirmation))
confirmation_path <- qdesn_ssv2_write_csv(
  confirmation, file.path(output_root, "canonical_confirmation_profiles.csv")
)

manifest_path <- qdesn_ssv2_write_json(list(
  generated_at = as.character(Sys.time()),
  decision = "PAIRED_CALIBRATION_CLOSED_MANUAL_CONFIRMATION_REQUIRED",
  run_tag = run_tag,
  jobs = nrow(results),
  paired_blocks = nrow(unique(pairs[c(
    "target_cell_id", "source_id", "reservoir_seed_id"
  )])),
  paired_metric_blocks = nrow(pairs),
  target_cells = length(unique(metric_summary$target_cell_id)),
  metric_cells = nrow(metric_summary),
  eligible_target_cells = length(unique(eligible_metrics$target_cell_id)),
  eligible_metric_cells = nrow(eligible_metrics),
  selection_rule = list(
    paired_blocks_required = 6L,
    mean_delta_below_zero = TRUE,
    median_delta_below_zero = TRUE,
    pair_wins_required = 4L,
    minimum_effect_threshold = 0,
    every_paired_consistent_metric_gain_advances = TRUE
  ),
  outputs = list(
    evidence = list(path = results_path, sha256 = qdesn_ssv2_sha256(results_path)),
    metric_evidence = list(
      path = metric_results_path, sha256 = qdesn_ssv2_sha256(metric_results_path)
    ),
    contrasts = list(path = pairs_path, sha256 = qdesn_ssv2_sha256(pairs_path)),
    primary_selection = list(
      path = summary_path, sha256 = qdesn_ssv2_sha256(summary_path)
    ),
    metric_selection = list(
      path = metric_summary_path, sha256 = qdesn_ssv2_sha256(metric_summary_path)
    ),
    confirmation_profiles = list(
      path = confirmation_path, sha256 = qdesn_ssv2_sha256(confirmation_path),
      rows = nrow(confirmation)
    )
  ),
  article_promotion_automatic = FALSE,
  canonical_confirmation_automatic = FALSE
), file.path(output_root, "paired_closeout_manifest.json"))
cat(sprintf(
  paste0("decision=PAIRED_CALIBRATION_CLOSED jobs=%d paired_blocks=%d ",
         "metric_cells=%d eligible_metrics=%d eligible_cells=%d manifest=%s\n"),
  nrow(results), nrow(pairs) / length(metric_columns), nrow(metric_summary),
  nrow(eligible_metrics), nrow(confirmation), manifest_path
))

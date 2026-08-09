#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  required <- c("jsonlite", "coda")
  missing <- required[!vapply(required, requireNamespace, logical(1L), quietly = TRUE)]
  if (length(missing)) stop(sprintf("Missing packages: %s", paste(missing, collapse = ", ")))
})

args <- commandArgs(trailingOnly = TRUE)
get_arg <- function(flag, default = NULL) {
  index <- which(args == flag)
  if (!length(index) || index[[1L]] >= length(args)) return(default)
  args[[index[[1L]] + 1L]]
}
repo_root <- normalizePath(
  system("git rev-parse --show-toplevel", intern = TRUE),
  winslash = "/", mustWork = TRUE
)
setwd(repo_root)
source(file.path(
  repo_root, "validation", "fitforecast_v2", "R",
  "independent_exal_m0_relaunch_v1.R"
))

run_tag <- as.character(get_arg("--run-tag", ""))[1L]
if (!nzchar(run_tag)) stop("--run-tag is required.", call. = FALSE)
output_arg <- get_arg(
  "--output-root",
  file.path("reports", "shared_fitforecast_v2_orchestration", run_tag, "closeout")
)
output_root <- if (grepl("^/", output_arg)) output_arg else file.path(repo_root, output_arg)
dir.create(output_root, recursive = TRUE, showWarnings = FALSE)

stub <- qdesn_m0v1_config_stub(repo_root)
anchors <- qdesn_m0v1_read_csv(paste0(stub, "_anchor_registry.csv"))
metric_contract <- qdesn_m0v1_read_csv(paste0(stub, "_metric_contract.csv"))
plan <- qdesn_m0v1_read_csv(paste0(stub, "_full_chain_plan.csv"))
runtime <- qdesn_m0v1_scan_jobs(repo_root, run_tag, plan)
qdesn_m0v1_write_csv(runtime, file.path(output_root, "full_runtime_audit.csv"))
if (nrow(runtime) != 45L || !all(runtime$status == "SUCCESS")) {
  qdesn_m0v1_write_json(list(
    generated_at = as.character(Sys.time()), run_tag = run_tag,
    expected_jobs = 45L, successful_jobs = sum(runtime$status == "SUCCESS"),
    failed_jobs = sum(runtime$status == "FAIL"),
    incomplete_jobs = sum(!runtime$status %in% c("SUCCESS", "FAIL")),
    decision = "INCOMPLETE"
  ), file.path(output_root, "closeout_gate.json"))
  stop("Full closeout requires 45 successful chain jobs.", call. = FALSE)
}

aligned_mean_path <- function(paths, type = c("fit", "forecast")) {
  type <- match.arg(type)
  frames <- lapply(paths, qdesn_m0v1_read_csv)
  if (type == "fit") {
    frames <- lapply(frames, function(x) {
      keep <- if ("effective_train" %in% names(x)) {
        as.logical(x$effective_train)
      } else x$source_index >= 8501L & x$source_index <= 9000L
      x[keep & x$source_index >= 8501L & x$source_index <= 9000L, , drop = FALSE]
    })
    keys <- lapply(frames, function(x) as.character(x$source_index))
    value_name <- "q_pred"
  } else {
    keys <- lapply(frames, function(x) paste(
      x$origin_sequence_id, x$forecast_lead, x$target_source_index, sep = "::"
    ))
    value_name <- "qhat"
  }
  reference_key <- keys[[1L]]
  if (any(vapply(keys, function(x) !identical(x, reference_key), logical(1L)))) {
    stop(sprintf("Chain %s paths are not aligned.", type), call. = FALSE)
  }
  values <- do.call(cbind, lapply(frames, function(x) as.numeric(x[[value_name]])))
  base <- frames[[1L]]
  base[[paste0(value_name, "_pooled")]] <- rowMeans(values)
  base[[paste0(value_name, "_chain_sd")]] <- apply(values, 1L, stats::sd)
  base
}

diagnostic_rows <- list()
metric_rows <- list()
path_rows <- list()
d <- 0L
m <- 0L
p <- 0L

for (a in seq_len(nrow(anchors))) {
  anchor_id <- anchors$anchor_id[[a]]
  anchor_plan <- plan[plan$anchor_id == anchor_id, , drop = FALSE]
  if (nrow(anchor_plan) != 3L) {
    stop(sprintf("Anchor %s does not have exactly three full chains.", anchor_id),
         call. = FALSE)
  }
  job_roots <- vapply(
    anchor_plan$job_id, qdesn_m0v1_job_root, character(1L),
    repo_root = repo_root, run_tag = run_tag
  )
  traces <- lapply(file.path(job_roots, "progress_trace.csv"), qdesn_m0v1_read_csv)
  parameters <- c("gamma", "sigma", "beta_norm", "rhs_tau", "rhs_c2", "rhs_lambda_mean")
  parameters <- parameters[vapply(parameters, function(x) {
    all(vapply(traces, function(y) x %in% names(y), logical(1L)))
  }, logical(1L))]
  anchor_diag <- list()
  for (parameter in parameters) {
    chains <- lapply(traces, function(x) as.numeric(x[[parameter]]))
    d <- d + 1L
    row <- data.frame(
      anchor_id = anchor_id,
      candidate_id = anchors$candidate_id[[a]],
      family = anchors$family[[a]],
      tau = anchors$tau[[a]],
      parameter = parameter,
      chains = 3L,
      draws_per_chain = min(vapply(chains, length, integer(1L))),
      rank_split_rhat = qdesn_m0v1_rank_split_rhat(chains),
      folded_rank_split_rhat = qdesn_m0v1_rank_split_rhat(chains, folded = TRUE),
      bulk_ess = qdesn_m0v1_effective_size(chains),
      tail_ess = qdesn_m0v1_tail_effective_size(chains),
      stringsAsFactors = FALSE
    )
    row$max_rhat <- max(row$rank_split_rhat, row$folded_rank_split_rhat,
                        na.rm = TRUE)
    row$mcse_over_sd <- if (is.finite(row$bulk_ess) && row$bulk_ess > 0) {
      1 / sqrt(row$bulk_ess)
    } else NA_real_
    row$diagnostic_grade <- if (
      is.finite(row$max_rhat) && row$max_rhat <= 1.01 &&
        is.finite(row$bulk_ess) && row$bulk_ess >= 400 &&
        is.finite(row$tail_ess) && row$tail_ess >= 400
    ) "PASS" else if (
      is.finite(row$max_rhat) && row$max_rhat <= 1.05 &&
        is.finite(row$bulk_ess) && row$bulk_ess >= 100 &&
        is.finite(row$tail_ess) && row$tail_ess >= 100
    ) "WARN" else "FAIL"
    diagnostic_rows[[d]] <- row
    anchor_diag[[length(anchor_diag) + 1L]] <- row
  }

  fit_paths <- file.path(job_roots, "tables", "fit_quantile_path_train.csv")
  forecast_paths <- file.path(job_roots, "tables", "forecast_rolling_origin_paths.csv")
  pooled_fit <- aligned_mean_path(fit_paths, "fit")
  pooled_forecast <- aligned_mean_path(forecast_paths, "forecast")
  tau <- as.numeric(anchors$tau[[a]])
  fit_rmse <- sqrt(mean((pooled_fit$q_pred_pooled - pooled_fit$q_true)^2))
  forecast_mae <- mean(abs(pooled_forecast$qhat_pooled - pooled_forecast$q_true))
  forecast_check <- mean(
    (tau - as.numeric(pooled_forecast$y < pooled_forecast$qhat_pooled)) *
      (pooled_forecast$y - pooled_forecast$qhat_pooled)
  )
  h100 <- pooled_forecast$target_source_index >= 9001L &
    pooled_forecast$target_source_index <= 9100L
  forecast_mae_h100 <- mean(abs(
    pooled_forecast$qhat_pooled[h100] - pooled_forecast$q_true[h100]
  ))
  forecast_check_h100 <- mean(
    (tau - as.numeric(pooled_forecast$y[h100] < pooled_forecast$qhat_pooled[h100])) *
      (pooled_forecast$y[h100] - pooled_forecast$qhat_pooled[h100])
  )
  diag_df <- do.call(rbind, anchor_diag)
  anchor_grade <- if (any(diag_df$diagnostic_grade == "FAIL")) "FAIL" else if (
    any(diag_df$diagnostic_grade == "WARN")
  ) "WARN" else "PASS"
  m <- m + 1L
  metric_rows[[m]] <- data.frame(
    anchor_id = anchor_id,
    candidate_id = anchors$candidate_id[[a]],
    family = anchors$family[[a]],
    tau = tau,
    metric_roles = anchors$metric_roles[[a]],
    chains = 3L,
    retained_draws_total = sum(vapply(traces, nrow, integer(1L))),
    fit_qtrue_rmse = fit_rmse,
    forecast_qtrue_mae_H100 = forecast_mae_h100,
    forecast_check_loss_H100 = forecast_check_h100,
    forecast_qtrue_mae_H1000 = forecast_mae,
    forecast_check_loss_H1000 = forecast_check,
    fit_path_max_chain_sd = max(pooled_fit$q_pred_chain_sd, na.rm = TRUE),
    forecast_path_max_chain_sd = max(pooled_forecast$qhat_chain_sd, na.rm = TRUE),
    diagnostic_grade = anchor_grade,
    diagnostic_status_used_as_metric_filter = FALSE,
    stringsAsFactors = FALSE
  )
  p <- p + 1L
  path_rows[[p]] <- data.frame(
    anchor_id = anchor_id,
    family = anchors$family[[a]], tau = tau,
    path = c("fit", "forecast"),
    rows = c(nrow(pooled_fit), nrow(pooled_forecast)),
    max_chain_sd = c(max(pooled_fit$q_pred_chain_sd, na.rm = TRUE),
                     max(pooled_forecast$qhat_chain_sd, na.rm = TRUE)),
    mean_chain_sd = c(mean(pooled_fit$q_pred_chain_sd, na.rm = TRUE),
                      mean(pooled_forecast$qhat_chain_sd, na.rm = TRUE)),
    stringsAsFactors = FALSE
  )
}

diagnostics <- do.call(rbind, diagnostic_rows)
anchor_metrics <- do.call(rbind, metric_rows)
path_agreement <- do.call(rbind, path_rows)
qdesn_m0v1_write_csv(diagnostics, file.path(output_root, "cross_chain_diagnostics.csv"))
qdesn_m0v1_write_csv(anchor_metrics, file.path(output_root, "pooled_anchor_metrics.csv"))
qdesn_m0v1_write_csv(path_agreement, file.path(output_root, "chain_path_agreement.csv"))

role_column <- c(
  fit_qtrue_rmse = "fit_qtrue_rmse",
  forecast_qtrue_mae_H1000 = "forecast_qtrue_mae_H1000",
  forecast_check_loss_H1000 = "forecast_check_loss_H1000"
)
comparison <- metric_contract
comparison$m0_value <- vapply(seq_len(nrow(comparison)), function(i) {
  row <- anchor_metrics[anchor_metrics$anchor_id == comparison$anchor_id[[i]], , drop = FALSE]
  as.numeric(row[[role_column[[comparison$metric_role[[i]]]]]][[1L]])
}, numeric(1L))
comparison$ratio_m0_to_current <- comparison$m0_value / comparison$current_value
comparison$metric_improves_current <- is.finite(comparison$m0_value) &
  comparison$m0_value < comparison$current_value - 1e-10
comparison$diagnostic_grade <- anchor_metrics$diagnostic_grade[
  match(comparison$anchor_id, anchor_metrics$anchor_id)
]
comparison$promotion_candidate <- comparison$metric_improves_current
comparison$promotion_requires_manual_review <- comparison$metric_improves_current
comparison$article_update_automatic <- FALSE
comparison$diagnostic_status_used_as_metric_filter <- FALSE
qdesn_m0v1_write_csv(comparison, file.path(output_root, "metric_comparison.csv"))
qdesn_m0v1_write_csv(
  comparison[comparison$promotion_candidate, , drop = FALSE],
  file.path(output_root, "manual_promotion_candidates.csv")
)

for (job_id in plan$job_id) {
  qdesn_m0v1_compact_progress(file.path(
    qdesn_m0v1_job_root(repo_root, run_tag, job_id), "progress_trace.csv"
  ), stride = 50L)
}
binary_paths <- list.files(
  file.path(repo_root, "results", "qdesn_mcmc_validation", qdesn_m0v1_stage, run_tag),
  pattern = "[.](rds|rda|RData)$", recursive = TRUE,
  full.names = TRUE, ignore.case = TRUE
)
storage_audit <- data.frame(
  run_tag = run_tag,
  binary_payload_count = length(binary_paths),
  binary_payload_bytes = if (length(binary_paths)) sum(file.info(binary_paths)$size) else 0,
  storage_policy_pass = length(binary_paths) == 0L,
  stringsAsFactors = FALSE
)
qdesn_m0v1_write_csv(storage_audit, file.path(output_root, "storage_audit.csv"))

outputs <- list.files(output_root, full.names = TRUE)
outputs <- outputs[basename(outputs) != "file_manifest.csv"]
output_manifest <- data.frame(
  path = vapply(outputs, qdesn_m0v1_rel, character(1L), repo_root = repo_root),
  bytes = as.numeric(file.info(outputs)$size),
  sha256 = vapply(outputs, qdesn_m0v1_sha256, character(1L)),
  stringsAsFactors = FALSE
)
qdesn_m0v1_write_csv(output_manifest, file.path(output_root, "file_manifest.csv"))

decision <- if (length(binary_paths)) "FAIL_STORAGE" else "COMPLETE_REVIEW_REQUIRED"
qdesn_m0v1_write_json(list(
  generated_at = as.character(Sys.time()),
  run_tag = run_tag,
  stage = qdesn_m0v1_stage,
  expected_chains = 45L,
  successful_chains = 45L,
  anchors = 15L,
  metric_occurrences = 27L,
  metrics_improved = sum(comparison$metric_improves_current),
  diagnostic_grade_counts = as.list(table(anchor_metrics$diagnostic_grade)),
  storage_policy_pass = length(binary_paths) == 0L,
  diagnostic_status_used_as_metric_filter = FALSE,
  automatic_promotion = FALSE,
  article_updated = FALSE,
  decision = decision
), file.path(output_root, "closeout_gate.json"))

cat(sprintf(
  "closeout: 45/45 chains; %d/27 metric roles improved; storage=%s; article untouched\n",
  sum(comparison$metric_improves_current),
  if (length(binary_paths)) "FAIL" else "PASS"
))
if (length(binary_paths)) stop("Closeout storage policy failed.", call. = FALSE)

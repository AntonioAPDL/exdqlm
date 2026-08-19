#!/usr/bin/env Rscript

suppressPackageStartupMessages(requireNamespace("jsonlite", quietly = TRUE))
args <- commandArgs(trailingOnly = TRUE)
arg <- function(flag, default = NULL) {
  i <- which(args == flag)
  if (!length(i) || i[[1L]] >= length(args)) default else args[[i[[1L]] + 1L]]
}
repo_root <- normalizePath(
  arg("--repo-root", system("git rev-parse --show-toplevel", intern = TRUE)),
  winslash = "/", mustWork = TRUE
)
state_root <- normalizePath(arg("--state-root"), winslash = "/", mustWork = TRUE)
run_tag <- arg("--run-tag")
setwd(repo_root)
source(file.path(repo_root, "validation", "fitforecast_v2", "R",
                 "qdesn_forecast_gap_adaptive_mcmc_v1.R"))
out <- file.path(state_root, "confirmation")
plan <- qdesn_ssv2_read_csv(file.path(out, "confirmation_plan.csv"))
metric_map <- qdesn_ssv2_read_csv(file.path(out, "confirmation_metric_map.csv"))

empty_chain <- data.frame(
  target_cell_id = character(), metric = character(), candidate_id = character(),
  chain_id = integer(), value = numeric(), current_value = numeric(),
  ratio = numeric(), status = character(), diagnostic_status = character(),
  signoff_path = character(), stringsAsFactors = FALSE
)
rows <- list()
k <- 0L
if (nrow(metric_map)) {
  for (i in seq_len(nrow(metric_map))) {
    role <- metric_map[i, , drop = FALSE]
    jobs <- plan[
      plan$target_cell_id == role$target_cell_id &
        plan$candidate_id == role$candidate_id,
      , drop = FALSE
    ]
    if (nrow(jobs) != 3L) stop("Each canonical metric role requires three chains.")
    for (j in seq_len(nrow(jobs))) {
      root <- qdesn_fgav1_job_root(repo_root, run_tag, jobs$job_id[[j]])
      status <- qdesn_ssv2_read_json(file.path(root, "job_status.json"))
      values <- qdesn_fgav1_metric_values(root)
      signoff_path <- file.path(root, "signoff_summary.csv")
      signoff <- if (file.exists(signoff_path)) qdesn_ssv2_read_csv(signoff_path) else
        data.frame(overall_status = "MISSING")
      value <- values[[role$metric[[1L]]]]
      k <- k + 1L
      rows[[k]] <- data.frame(
        target_cell_id = role$target_cell_id, metric = role$metric,
        candidate_id = role$candidate_id, chain_id = jobs$chain_id[[j]],
        value = value, current_value = role$current_value,
        ratio = value / role$current_value,
        status = as.character(status$status),
        diagnostic_status = as.character(signoff$overall_status[[1L]] %||% "MISSING"),
        signoff_path = signoff_path, stringsAsFactors = FALSE
      )
    }
  }
}
chain_metrics <- if (length(rows)) do.call(rbind, rows) else empty_chain
chain_path <- qdesn_ssv2_write_csv(
  chain_metrics, file.path(out, "confirmation_chain_metrics.csv")
)

empty_summary <- data.frame(
  target_cell_id = character(), metric = character(), candidate_id = character(),
  chains = integer(), current_value = numeric(), mean_value = numeric(),
  median_value = numeric(), min_value = numeric(), max_value = numeric(),
  mean_ratio = numeric(), median_ratio = numeric(), chains_improved = integer(),
  all_finite = logical(), all_success = logical(), diagnostics = character(),
  promote = logical(), decision = character(), stringsAsFactors = FALSE
)
if (nrow(chain_metrics)) {
  groups <- split(chain_metrics, paste(
    chain_metrics$target_cell_id, chain_metrics$metric, sep = "\r"
  ))
  summary <- do.call(rbind, lapply(groups, function(x) {
    promote <- nrow(x) == 3L && all(is.finite(x$value)) &&
      all(x$status == "SUCCESS") && mean(x$value) < x$current_value[[1L]]
    data.frame(
      target_cell_id = x$target_cell_id[[1L]], metric = x$metric[[1L]],
      candidate_id = x$candidate_id[[1L]], chains = nrow(x),
      current_value = x$current_value[[1L]], mean_value = mean(x$value),
      median_value = stats::median(x$value), min_value = min(x$value),
      max_value = max(x$value), mean_ratio = mean(x$ratio),
      median_ratio = stats::median(x$ratio), chains_improved = sum(x$ratio < 1),
      all_finite = all(is.finite(x$value)), all_success = all(x$status == "SUCCESS"),
      diagnostics = paste(sort(unique(x$diagnostic_status)), collapse = ";"),
      promote = promote,
      decision = if (promote) "PROMOTE_STRICT_FORECAST_GAIN" else "RETAIN_V7",
      stringsAsFactors = FALSE
    )
  }))
} else {
  summary <- empty_summary
}
promotion_path <- qdesn_ssv2_write_csv(
  summary, file.path(out, "confirmation_promotion_ledger.csv")
)
decision <- if (nrow(summary) && any(summary$promote)) {
  "CONFIRMED_FORECAST_GAINS_READY_FOR_INTEGRATION"
} else {
  "NO_CONFIRMED_GAIN_RETAIN_V7"
}
qdesn_ssv2_write_json(list(
  schema_version = "qdesn_forecast_gap_adaptive_mcmc_v1_confirmation_closeout_v1",
  generated_at = as.character(Sys.time()), run_tag = run_tag,
  decision = decision, promoted_metrics = sum(summary$promote),
  promotion_rule = "three finite successful chains and strict arithmetic-mean gain",
  diagnostics_used_as_promotion_veto = FALSE,
  article_update_automatic = FALSE,
  chain_metrics_path = chain_path,
  chain_metrics_sha256 = qdesn_ssv2_sha256(chain_path),
  promotion_ledger_path = promotion_path,
  promotion_ledger_sha256 = qdesn_ssv2_sha256(promotion_path)
), file.path(out, "confirmation_closeout.json"))
print(summary, row.names = FALSE)

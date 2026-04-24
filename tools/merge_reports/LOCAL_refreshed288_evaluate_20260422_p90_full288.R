#!/usr/bin/env Rscript

options(stringsAsFactors = FALSE)

source("tools/merge_reports/LOCAL_refreshed288_helpers_20260422_p90_full288.R")

args <- parse_args_refreshed288(commandArgs(trailingOnly = TRUE))
repo_root <- normalizePath(".", winslash = "/", mustWork = TRUE)
setwd(repo_root)
paths <- paths_refreshed288()

manifest_path <- safe_chr_refreshed288(args$manifest, paths$full_manifest)
manifest_kind <- if (grepl("smoke_manifest", basename(manifest_path), fixed = TRUE)) "smoke" else "full"
status_out <- safe_chr_refreshed288(args$status_out, if (identical(manifest_kind, "smoke")) paths$smoke_manifest_status else paths$full_manifest_status)
phase_out <- safe_chr_refreshed288(args$phase_out, if (identical(manifest_kind, "smoke")) paths$smoke_phase_summary else paths$full_phase_summary)
method_out <- safe_chr_refreshed288(args$method_out, if (identical(manifest_kind, "smoke")) paths$smoke_method_summary else paths$full_method_summary)

manifest <- utils::read.csv(manifest_path, stringsAsFactors = FALSE, check.names = FALSE)

status_rows <- vector("list", nrow(manifest))
for (i in seq_len(nrow(manifest))) {
  row <- manifest[i, , drop = FALSE]
  row_csv <- safe_read_csv_refreshed288(row$row_status_path, stringsAsFactors = FALSE, check.names = FALSE)
  metrics_csv <- safe_read_csv_refreshed288(row$metrics_path, stringsAsFactors = FALSE, check.names = FALSE)

  status_current <- if (!is.null(row_csv) && nrow(row_csv)) {
    safe_chr_refreshed288(row_csv$status[1], "not_started")
  } else {
    "not_started"
  }
  gate_current <- if (identical(status_current, "running") || identical(status_current, "not_started")) {
    "MISSING"
  } else if (!is.null(row_csv) && nrow(row_csv)) {
    safe_chr_refreshed288(row_csv$gate_overall[1], if (identical(status_current, "failed_runtime")) "FAIL" else "MISSING")
  } else {
    "MISSING"
  }
  healthy_current <- if (!is.null(row_csv) && nrow(row_csv) && !(status_current %in% c("running", "not_started"))) {
    isTRUE(row_csv$healthy[1])
  } else {
    FALSE
  }
  error_current <- if (!is.null(row_csv) && nrow(row_csv)) {
    safe_chr_refreshed288(row_csv$error[1], NA_character_)
  } else {
    NA_character_
  }
  runtime_sec_current <- if (!is.null(metrics_csv) && nrow(metrics_csv)) {
    safe_num_refreshed288(metrics_csv$runtime_sec[1], NA_real_)
  } else if (!is.null(row_csv) && nrow(row_csv)) {
    safe_num_refreshed288(row_csv$runtime_sec[1], NA_real_)
  } else {
    NA_real_
  }

  status_rows[[i]] <- data.frame(
    row_id = row$row_id,
    base_row_id = row$base_row_id,
    original_case_key = row$original_case_key,
    phase = row$phase,
    phase_order = row$phase_order,
    block = row$block,
    root_kind = row$root_kind,
    family = row$family,
    tau = row$tau,
    tau_label = row$tau_label,
    fit_size = row$fit_size,
    prior_semantics = row$prior_semantics,
    model = row$model,
    inference = row$inference,
    method_profile_id = row$method_profile_id,
    seed = row$seed,
    status_current = status_current,
    error_current = error_current,
    gate_current = gate_current,
    healthy_current = healthy_current,
    runtime_sec_current = runtime_sec_current,
    crps_metric = if (!is.null(metrics_csv) && nrow(metrics_csv)) safe_num_refreshed288(metrics_csv$crps_metric[1], NA_real_) else NA_real_,
    primary_accuracy_metric = if (!is.null(metrics_csv) && nrow(metrics_csv)) safe_num_refreshed288(metrics_csv$primary_accuracy_metric[1], NA_real_) else NA_real_,
    q_rmse_metric = if (!is.null(metrics_csv) && nrow(metrics_csv)) safe_num_refreshed288(metrics_csv$q_rmse_metric[1], NA_real_) else NA_real_,
    coverage95_metric = if (!is.null(metrics_csv) && nrow(metrics_csv)) safe_num_refreshed288(metrics_csv$coverage95_metric[1], NA_real_) else NA_real_,
    coverage95_gap_metric = if (!is.null(metrics_csv) && nrow(metrics_csv)) safe_num_refreshed288(metrics_csv$coverage95_gap_metric[1], NA_real_) else NA_real_,
    mean_ci_width_metric = if (!is.null(metrics_csv) && nrow(metrics_csv)) safe_num_refreshed288(metrics_csv$mean_ci_width_metric[1], NA_real_) else NA_real_,
    cie_metric = if (!is.null(metrics_csv) && nrow(metrics_csv)) safe_num_refreshed288(metrics_csv$cie_metric[1], NA_real_) else NA_real_,
    beta_rmse_mean_metric = if (!is.null(metrics_csv) && nrow(metrics_csv)) safe_num_refreshed288(metrics_csv$beta_rmse_mean_metric[1], NA_real_) else NA_real_,
    beta_coverage_gap_metric = if (!is.null(metrics_csv) && nrow(metrics_csv)) safe_num_refreshed288(metrics_csv$beta_coverage_gap_metric[1], NA_real_) else NA_real_,
    metric_source = if (!is.null(metrics_csv) && nrow(metrics_csv)) safe_chr_refreshed288(metrics_csv$metric_source[1], NA_character_) else NA_character_,
    metric_error = if (!is.null(metrics_csv) && nrow(metrics_csv)) safe_chr_refreshed288(metrics_csv$metric_error[1], NA_character_) else NA_character_,
    stringsAsFactors = FALSE
  )
}

status_df <- do.call(rbind, status_rows)
status_df <- status_df[order(status_df$phase_order, status_df$row_id), , drop = FALSE]
write_csv_atomic_refreshed288(status_df, status_out, row.names = FALSE)

phase_summary <- summarize_status_refreshed288(status_df, "phase")
phase_order_lookup <- stats::aggregate(phase_order ~ phase, data = manifest[, c("phase", "phase_order"), drop = FALSE], FUN = min)
phase_summary <- merge(phase_summary, phase_order_lookup, by = "phase", all.x = TRUE, sort = FALSE)
if (any(!is.finite(phase_summary$phase_order))) {
  phase_summary$phase_order[!is.finite(phase_summary$phase_order)] <- seq_len(sum(!is.finite(phase_summary$phase_order))) + max(c(0, phase_summary$phase_order[is.finite(phase_summary$phase_order)]))
}
phase_summary <- phase_summary[order(phase_summary$phase_order), , drop = FALSE]
write_csv_atomic_refreshed288(
  phase_summary[, c("phase", "total", "completed", "running", "not_started", "pass", "warn", "fail", "healthy", "pct_completed", "pct_active_or_done")],
  phase_out,
  row.names = FALSE
)

method_summary <- summarize_status_refreshed288(
  status_df,
  c("root_kind", "prior_semantics", "model", "inference")
)
method_summary <- method_summary[order(method_summary$root_kind, method_summary$prior_semantics, method_summary$model, method_summary$inference), , drop = FALSE]
write_csv_atomic_refreshed288(method_summary, method_out, row.names = FALSE)

cat(sprintf(
  "SUMMARY total=%d completed=%d running=%d not_started=%d pass=%d warn=%d fail=%d healthy=%d pct_completed=%.1f pct_active_or_done=%.1f\n",
  nrow(status_df),
  sum(status_df$status_current %in% c("done", "skipped_existing", "failed_runtime")),
  sum(status_df$status_current == "running"),
  sum(status_df$status_current == "not_started"),
  sum(status_df$gate_current == "PASS"),
  sum(status_df$gate_current == "WARN"),
  sum(status_df$gate_current == "FAIL"),
  sum(status_df$healthy_current),
  100 * sum(status_df$status_current %in% c("done", "skipped_existing", "failed_runtime")) / nrow(status_df),
  100 * sum(status_df$status_current != "not_started") / nrow(status_df)
))

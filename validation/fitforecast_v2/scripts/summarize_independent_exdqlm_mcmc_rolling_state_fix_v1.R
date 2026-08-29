#!/usr/bin/env Rscript

cmd_args0 <- commandArgs(FALSE)
file_arg <- grep("^--file=", cmd_args0, value = TRUE)
this_file <- if (length(file_arg)) sub("^--file=", "", file_arg[[1L]]) else
  "validation/fitforecast_v2/scripts/summarize_independent_exdqlm_mcmc_rolling_state_fix_v1.R"
harness_root <- normalizePath(file.path(dirname(this_file), ".."), winslash = "/",
                              mustWork = TRUE)
source(file.path(harness_root, "R", "utils.R"))
ffv2_source_all(harness_root)

args <- ffv2_parse_args()
manifest_path <- normalizePath(args$manifest %||% "", winslash = "/", mustWork = TRUE)
manifest <- ffv2_read_csv(manifest_path)
rows <- vector("list", nrow(manifest))
for (i in seq_len(nrow(manifest))) {
  config <- ffv2_read_json(manifest$row_config_path[[i]])
  status <- ffv2_read_csv(config$row_status_path)
  if (!identical(as.character(status$status[[1L]]), "done")) {
    stop(sprintf("Incomplete sentinel row: %s", manifest$source_job_id[[i]]), call. = FALSE)
  }
  current <- ffv2_read_csv(config$row_metrics_path)
  historical_config <- ffv2_read_json(config$source_config_path)
  historical <- ffv2_read_csv(historical_config$row_metrics_path)
  current_path <- ffv2_read_csv(config$forecast_path_summary_path)
  historical_path <- ffv2_read_csv(historical_config$forecast_path_summary_path)
  current_first <- current_path[current_path$origin_sequence_id == 1L, , drop = FALSE]
  historical_first <- historical_path[historical_path$origin_sequence_id == 1L, , drop = FALSE]
  rows[[i]] <- data.frame(
    family = config$family,
    tau = config$tau,
    chain_id = config$chain_id,
    historical_fit_rmse = historical$fit_q_rmse,
    corrected_fit_rmse = current$fit_q_rmse,
    fit_rmse_change = current$fit_q_rmse - historical$fit_q_rmse,
    historical_forecast_mae = historical$forecast_h1000_q_mae,
    corrected_forecast_mae = current$forecast_h1000_q_mae,
    forecast_mae_change = current$forecast_h1000_q_mae - historical$forecast_h1000_q_mae,
    forecast_mae_ratio = current$forecast_h1000_q_mae / historical$forecast_h1000_q_mae,
    historical_forecast_check = historical$forecast_h1000_pinball_mean,
    corrected_forecast_check = current$forecast_h1000_pinball_mean,
    forecast_check_change = current$forecast_h1000_pinball_mean - historical$forecast_h1000_pinball_mean,
    historical_first_origin_mae = mean(historical_first$abs_q_error),
    corrected_first_origin_mae = mean(current_first$abs_q_error),
    first_origin_mae_change = mean(current_first$abs_q_error) -
      mean(historical_first$abs_q_error),
    state_update_method = unique(current_path$state_update_method),
    health_gate = status$health_gate,
    stringsAsFactors = FALSE
  )
}
summary <- ffv2_bind_rows(rows)
out_dir <- file.path(dirname(dirname(manifest_path)), "closeout")
ffv2_ensure_dir(out_dir)
summary_path <- ffv2_write_csv(summary, file.path(out_dir, "paired_metric_comparison.csv"))
lower <- summary$tau < 0.5
control <- summary$tau == 0.5
checks <- c(
  all_complete = nrow(summary) == nrow(manifest),
  state_method_exact = all(
    summary$state_update_method == ffv2_exdqlm_mcmc_predictive_state_update_method()
  ),
  no_heavy_binaries = !any(grepl(
    "[.](rds|rda|RData)$",
    list.files(dirname(dirname(manifest_path)), recursive = TRUE),
    ignore.case = TRUE
  )),
  lower_tail_mae_improves = all(summary$forecast_mae_change[lower] < 0),
  lower_tail_material_gain = all(summary$forecast_mae_ratio[lower] < 0.75),
  median_control_no_material_regression = all(summary$forecast_mae_ratio[control] < 1.20),
  fit_invariant = all(abs(summary$fit_rmse_change) < 0.05),
  first_origin_invariant = all(abs(summary$first_origin_mae_change) < 0.10)
)
checks_path <- ffv2_write_csv(
  data.frame(check = names(checks), pass = unname(checks), stringsAsFactors = FALSE),
  file.path(out_dir, "sentinel_checks.csv")
)
decision <- if (all(checks)) "SENTINEL_PASS_PROCEED_TO_FULL_27_JOB_CONFIRMATION" else
  "SENTINEL_REVIEW_DO_NOT_LAUNCH_FULL"
ffv2_write_json(list(
  schema_version = iems_v1_schema,
  generated_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"),
  decision = decision,
  checks_pass = sum(checks),
  checks_total = length(checks),
  comparison_path = summary_path,
  comparison_sha256 = ffv2_file_sha256(summary_path),
  checks_path = checks_path,
  checks_sha256 = ffv2_file_sha256(checks_path),
  article_write_performed = FALSE
), file.path(out_dir, "closeout.json"))
print(summary)
cat(sprintf("DECISION=%s checks=%d/%d\n", decision, sum(checks), length(checks)))
if (!all(checks)) quit(status = 2L)

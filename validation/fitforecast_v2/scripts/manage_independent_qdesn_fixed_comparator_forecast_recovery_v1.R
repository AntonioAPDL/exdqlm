#!/usr/bin/env Rscript

cmd_args0 <- commandArgs(FALSE)
file_arg <- grep("^--file=", cmd_args0, value = TRUE)
this_file <- if (length(file_arg)) sub("^--file=", "", file_arg[[1L]]) else
  "validation/fitforecast_v2/scripts/manage_independent_qdesn_fixed_comparator_forecast_recovery_v1.R"
harness_root <- normalizePath(file.path(dirname(this_file), ".."), winslash = "/",
                              mustWork = TRUE)
source(file.path(harness_root, "R", "utils.R"))
ffv2_source_all(harness_root)

args <- ffv2_parse_args()
action <- as.character(args$action %||% "")[[1L]]
run_root <- ffv2_resolve_path(args$`run-root` %||% "", must_work = FALSE)
source_run_root <- ffv2_resolve_path(
  args$`source-run-root` %||% "", must_work = TRUE
)
repo_root <- ffv2_repo_root()

if (identical(action, "materialize")) {
  tarball <- ffv2_resolve_path(args$tarball %||% "", must_work = TRUE)
  out <- iqfcr_v1_materialize(repo_root, source_run_root, run_root, tarball)
  cat(sprintf("MATERIALIZED_RECOVERY jobs=%d manifest=%s\n",
              nrow(out$manifest), out$preflight$recovery_manifest_path))
} else if (identical(action, "health")) {
  out <- iqfc_v1_health(run_root)
  print(out$summary, row.names = FALSE)
  cat(sprintf(
    "HEALTH total=%d done=%d running=%d failed=%d remaining=%d\n",
    out$total, out$done, out$running, out$failed, out$remaining
  ))
  health_root <- ffv2_ensure_dir(file.path(run_root, "health"))
  iqfc_v1_write_csv(out$jobs, file.path(health_root, "job_health.csv"))
  ffv2_write_json(list(
    schema_version = iqfcr_v1_schema,
    generated_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"),
    total = out$total, done = out$done, running = out$running,
    failed = out$failed, remaining = out$remaining,
    summary = split(out$summary, seq_len(nrow(out$summary)))
  ), file.path(health_root, "health_report.json"))
} else if (identical(action, "closeout")) {
  out <- iqfcr_v1_closeout(repo_root, source_run_root, run_root)
  cat(sprintf("CLOSEOUT status=%s path=%s cleanup_candidates=%s\n",
              out$closeout$status, out$closeout_path, out$cleanup_path))
} else {
  stop("--action must be materialize, health, or closeout.", call. = FALSE)
}

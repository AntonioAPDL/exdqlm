#!/usr/bin/env Rscript

cmd_args0 <- commandArgs(FALSE)
file_arg <- grep("^--file=", cmd_args0, value = TRUE)
this_file <- if (length(file_arg)) sub("^--file=", "", file_arg[[1L]]) else "validation/fitforecast_v2/scripts/healthcheck_exdqlm_dynamic_fitforecast_v2_validation.R"
harness_root <- normalizePath(file.path(dirname(this_file), ".."), winslash = "/", mustWork = TRUE)
source(file.path(harness_root, "R", "utils.R"))
ffv2_source_all(harness_root)

args <- ffv2_parse_args()
manifest_path <- args$manifest %||% NULL
if (is.null(manifest_path)) {
  defaults <- ffv2_load_defaults(args$defaults %||% ffv2_default_defaults_path())
  run_root <- ffv2_resolve_path(file.path(defaults$study$results_root, defaults$study$run_tag), must_work = TRUE)
  manifest_path <- file.path(run_root, "manifests", "row_manifest.csv")
}
manifest <- ffv2_read_csv(manifest_path)
run_root <- unique(manifest$run_root)[[1L]]
counts <- ffv2_status_counts(manifest)
defaults_for_stale <- tryCatch(ffv2_load_defaults(args$defaults %||% ffv2_default_defaults_path()), error = function(e) list())
stale_seconds <- ffv2_as_int1(
  args$`healthcheck-stale-seconds` %||%
    (defaults_for_stale$runtime %||% list())$healthcheck_stale_seconds,
  1800L
)
telemetry <- ffv2_telemetry_summary(manifest, stale_seconds = stale_seconds)
health_files <- manifest$row_health_path[file.exists(manifest$row_health_path)]
health <- ffv2_bind_rows(lapply(health_files, ffv2_read_csv))
storage <- ffv2_storage_audit(run_root)
interface_path <- file.path(run_root, "interfaces", "exdqlm_dqlm_dynamic_fitforecast_v2_shared_interface.csv")
interface <- ffv2_export_shared_interface(manifest, interface_path)

status_counts_path <- ffv2_write_csv(counts, file.path(run_root, "manifests", "status_counts.csv"))
telemetry_summary_path <- ffv2_write_csv(telemetry, file.path(run_root, "manifests", "telemetry_summary.csv"))
storage_audit_path <- ffv2_write_csv(storage, file.path(run_root, "storage", "storage_audit.csv"))

cat("exDQLM/DQLM dynamic fit+forecast v2 healthcheck\n")
cat(sprintf("run_root: %s\n", run_root))
cat("status_counts:\n")
print(counts)
if (nrow(health)) {
  cat("health_gates:\n")
  print(table(health$gate, useNA = "ifany"))
}
if (nrow(telemetry)) {
  cat("telemetry_states:\n")
  print(table(telemetry$telemetry_state, useNA = "ifany"))
  active <- telemetry[telemetry$telemetry_state %in% c("progressing", "stalled"), , drop = FALSE]
  if (nrow(active)) {
    cat("active_rows:\n")
    print(active[, c("row_id", "row_key", "inference", "stage", "substage",
                     "current_iter", "total_iter", "percent_complete",
                     "heartbeat_age_seconds", "telemetry_state")])
  }
}
cat("storage:\n")
print(storage[, c("status", "n_files", "total_bytes", "forbidden_payloads", "forbidden_bytes")])
cat(sprintf("status_counts_csv: %s\n", status_counts_path))
cat(sprintf("telemetry_summary_csv: %s\n", telemetry_summary_path))
cat(sprintf("storage_audit_csv: %s\n", storage_audit_path))
cat(sprintf("shared_interface_rows: %d\n", nrow(interface)))
cat(sprintf("shared_interface: %s\n", interface_path))

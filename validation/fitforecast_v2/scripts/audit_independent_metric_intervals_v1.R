#!/usr/bin/env Rscript

cmd_args0 <- commandArgs(FALSE)
file_arg <- grep("^--file=", cmd_args0, value = TRUE)
this_file <- if (length(file_arg)) sub("^--file=", "", file_arg[[1L]]) else
  "validation/fitforecast_v2/scripts/audit_independent_metric_intervals_v1.R"
harness_root <- normalizePath(file.path(dirname(this_file), ".."), winslash = "/", mustWork = TRUE)
source(file.path(harness_root, "R", "utils.R"))
ffv2_source_all(harness_root)

args <- ffv2_parse_args()
repo_root <- normalizePath(args$`repo-root` %||% ffv2_repo_root(), winslash = "/", mustWork = TRUE)
output_root <- args$`output-root` %||% file.path(
  repo_root, "config", "validation", "independent_metric_intervals_v1_audit"
)
dir.create(output_root, recursive = TRUE, showWarnings = FALSE)
audit <- imi_v1_static_audit(repo_root)
ffv2_write_csv(audit$metric_roles, file.path(output_root, "metric_role_ledger.csv"))
ffv2_write_csv(audit$source_registry, file.path(output_root, "source_replay_registry.csv"))
ffv2_write_csv(audit$request_catalog, file.path(output_root, "request_catalog.csv"))
ffv2_write_csv(audit$checks, file.path(output_root, "static_audit.csv"))
manifest <- list(
  schema_version = imi_v1_schema,
  generated_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"),
  authority_id = imi_v1_authority_id,
  authority_interface_path = imi_v1_relpath(imi_v1_authority_interface_path(repo_root), repo_root),
  authority_interface_sha256 = ffv2_file_sha256(imi_v1_authority_interface_path(repo_root)),
  authority_manifest_path = imi_v1_relpath(imi_v1_authority_manifest_path(repo_root), repo_root),
  authority_manifest_sha256 = ffv2_file_sha256(imi_v1_authority_manifest_path(repo_root)),
  article_rows = nrow(audit$interface),
  metric_roles = nrow(audit$metric_roles),
  source_identities = nrow(audit$source_registry),
  planned_jobs = sum(audit$source_registry$planned_chains),
  checks_pass = sum(audit$checks$pass),
  checks_total = nrow(audit$checks),
  files = data.frame(
    role = c("metric_role_ledger", "source_replay_registry", "request_catalog", "static_audit"),
    path = c("metric_role_ledger.csv", "source_replay_registry.csv", "request_catalog.csv", "static_audit.csv"),
    stringsAsFactors = FALSE
  )
)
ffv2_write_json(manifest, file.path(output_root, "audit_manifest.json"))
cat(sprintf("checks=%d/%d sources=%d jobs=%d unresolved=%d\n",
            sum(audit$checks$pass), nrow(audit$checks), nrow(audit$source_registry),
            sum(audit$source_registry$planned_chains),
            sum(audit$source_registry$request_resolution == "UNRESOLVED", na.rm = TRUE)))
if (!all(audit$checks$pass)) {
  print(audit$checks[!audit$checks$pass, , drop = FALSE])
  quit(save = "no", status = 1L)
}

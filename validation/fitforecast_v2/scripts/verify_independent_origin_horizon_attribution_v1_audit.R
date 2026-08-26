#!/usr/bin/env Rscript

cmd_args0 <- commandArgs(FALSE)
file_arg <- grep("^--file=", cmd_args0, value = TRUE)
this_file <- if (length(file_arg)) sub("^--file=", "", file_arg[[1L]]) else
  "validation/fitforecast_v2/scripts/verify_independent_origin_horizon_attribution_v1_audit.R"
harness_root <- normalizePath(file.path(dirname(this_file), ".."), winslash = "/",
                              mustWork = TRUE)
source(file.path(harness_root, "R", "utils.R"))
ffv2_source_all(harness_root)

args <- ffv2_parse_args()
repo_root <- normalizePath(args$`repo-root` %||% ffv2_repo_root(), winslash = "/",
                           mustWork = TRUE)
audit_root <- normalizePath(
  args$`audit-root` %||% file.path(
    repo_root, "validation", "fitforecast_v2", "audits",
    "independent_origin_horizon_attribution_v1_20260826"
  ), winslash = "/", mustWork = TRUE
)
manifest_path <- file.path(audit_root, "audit_manifest.json")
ledger_path <- file.path(audit_root, "artifact_manifest.csv")
manifest <- ffv2_read_json(manifest_path)
ledger <- ffv2_read_csv(ledger_path)
paths <- file.path(audit_root, ledger$portable_path)
present <- file.exists(paths)
actual <- rep(NA_character_, length(paths))
actual[present] <- vapply(paths[present], ffv2_file_sha256, character(1L))
decision <- ffv2_read_json(file.path(audit_root, "decision_manifest.json"))
verification <- ffv2_read_json(file.path(audit_root, "closeout_verification.json"))
checks <- data.frame(
  check = c("schema", "manifest_hash", "artifact_count", "assets_present",
            "asset_hashes", "decision", "verification", "no_absolute_paths",
            "no_heavy_binaries"),
  pass = c(
    identical(as.character(manifest$schema_version), imoh_v1_schema),
    identical(ffv2_file_sha256(ledger_path),
              as.character(manifest$artifact_manifest_sha256)),
    nrow(ledger) == as.integer(manifest$artifact_count),
    all(present),
    identical(unname(actual), unname(as.character(ledger$sha256))),
    identical(as.character(decision$decision),
              "ATTRIBUTION_COMPLETE_NO_TAU0_CAUSAL_PILOT_AUTHORIZED") &&
      !isTRUE(decision$article_update_authorized) &&
      !isTRUE(decision$automatic_tau0_launch_authorized),
    identical(as.character(verification$status), "PASS") &&
      identical(ffv2_file_sha256(file.path(audit_root, "decision_manifest.json")),
                as.character(verification$decision_sha256)),
    !any(startsWith(ledger$source_relative_path, "/")) &&
      !any(startsWith(ledger$portable_path, "/")),
    !any(grepl("[.](rds|rda|RData)$", paths, ignore.case = TRUE))
  ), stringsAsFactors = FALSE
)
status <- if (all(checks$pass)) "PASS" else "FAIL"
cat(sprintf("status=%s checks=%d failed=%d artifacts=%d bytes=%d\n", status,
            nrow(checks), sum(!checks$pass), nrow(ledger), sum(ledger$bytes)))
if (!all(checks$pass)) {
  print(checks[!checks$pass, , drop = FALSE], row.names = FALSE)
  quit(save = "no", status = 1L)
}

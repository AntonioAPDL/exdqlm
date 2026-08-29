#!/usr/bin/env Rscript

cmd_args0 <- commandArgs(FALSE)
file_arg <- grep("^--file=", cmd_args0, value = TRUE)
this_file <- if (length(file_arg)) sub("^--file=", "", file_arg[[1L]]) else
  "validation/fitforecast_v2/scripts/verify_independent_dgp_oracle_reference_v1.R"
harness_root <- normalizePath(file.path(dirname(this_file), ".."), winslash = "/", mustWork = TRUE)
source(file.path(harness_root, "R", "utils.R"))
ffv2_source_all(harness_root)

args <- ffv2_parse_args()
repo_root <- normalizePath(args$`repo-root` %||% ffv2_repo_root(), winslash = "/", mustWork = TRUE)
source_root <- args$`source-root` %||% idor_v1_default_source_root()
output_root <- args$`output-root` %||% file.path(
  repo_root,
  "validation",
  "fitforecast_v2",
  "promotions",
  "independent_dgp_oracle_reference_v1_20260828"
)
output_root <- normalizePath(output_root, winslash = "/", mustWork = TRUE)

manifest <- ffv2_read_json(file.path(output_root, "manifest.json"))
artifact_manifest <- ffv2_read_csv(file.path(output_root, "artifact_manifest.csv"))
checks <- list(
  schema = identical(as.character(manifest$schema_version), idor_v1_schema),
  scenario = identical(as.character(manifest$scenario_id), idor_v1_scenario),
  no_refits = identical(manifest$model_refits_required, FALSE),
  no_metric_changes = identical(manifest$article_metric_values_changed, FALSE),
  manifest_checks = identical(as.integer(manifest$checks_passed),
                              as.integer(manifest$checks_total)),
  artifact_rows = nrow(artifact_manifest) == 7L
)

for (i in seq_len(nrow(artifact_manifest))) {
  path <- file.path(repo_root, artifact_manifest$path[[i]])
  key <- paste0("artifact_", artifact_manifest$artifact_id[[i]])
  checks[[key]] <- file.exists(path) && identical(
    ffv2_file_sha256(path),
    as.character(artifact_manifest$sha256[[i]])
  )
}
for (key in names(manifest$code_paths)) {
  path <- file.path(repo_root, as.character(manifest$code_paths[[key]]))
  checks[[paste0("code_", key)]] <- file.exists(path) && identical(
    ffv2_file_sha256(path),
    as.character(manifest$code_sha256[[key]])
  )
}

rebuilt <- idor_v1_build(source_root)
frozen_ledger <- ffv2_read_csv(file.path(output_root, "oracle_reference_ledger.csv"))
frozen_sources <- ffv2_read_csv(file.path(output_root, "source_registry.csv"))
checks$rebuilt_checks <- all(rebuilt$checks$pass)
checks$ledger_reproduced <- isTRUE(all.equal(
  rebuilt$reference_ledger,
  frozen_ledger,
  tolerance = 1e-12,
  check.attributes = FALSE
))
checks$sources_reproduced <- isTRUE(all.equal(
  rebuilt$source_registry,
  frozen_sources,
  tolerance = 1e-12,
  check.attributes = FALSE
))
checks$storage_light <- !length(list.files(
  output_root,
  pattern = "[.](rds|rda|RData)$",
  recursive = TRUE,
  ignore.case = TRUE
))

audit <- data.frame(
  check_id = names(checks),
  pass = unlist(checks, use.names = FALSE),
  stringsAsFactors = FALSE
)
if (!all(audit$pass)) {
  stop(sprintf(
    "Oracle-reference verification failed: %s",
    paste(audit$check_id[!audit$pass], collapse = ", ")
  ), call. = FALSE)
}
cat(sprintf("INDEPENDENT_DGP_ORACLE_REFERENCE_V1_VERIFIED %d/%d\n",
            sum(audit$pass), nrow(audit)))

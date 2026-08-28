#!/usr/bin/env Rscript

cmd_args0 <- commandArgs(FALSE)
file_arg <- grep("^--file=", cmd_args0, value = TRUE)
this_file <- if (length(file_arg)) sub("^--file=", "", file_arg[[1L]]) else
  "validation/fitforecast_v2/scripts/verify_independent_exdqlm_1p1p1_scoped_integration_v2.R"
harness_root <- normalizePath(file.path(dirname(this_file), ".."), winslash = "/",
                              mustWork = TRUE)
source(file.path(harness_root, "R", "utils.R"))
ffv2_source_all(harness_root)

args <- ffv2_parse_args()
repo_root <- normalizePath(args$`repo-root` %||% ffv2_repo_root(), winslash = "/",
                           mustWork = TRUE)
root <- normalizePath(
  args$`promotion-root` %||% i111s_promotion_root(repo_root),
  winslash = "/", mustWork = TRUE
)
ledger <- ffv2_read_csv(file.path(root, "output_file_manifest.csv"))
paths <- file.path(root, ledger$relative_path)
point <- ffv2_read_csv(file.path(
  root, "candidate_point_interface_exdqlm_only_replacement.csv"
))
interval <- ffv2_read_csv(file.path(
  root, "candidate_interval_roles_exdqlm_only_replacement.csv"
))
invariance <- ffv2_read_csv(file.path(root, "non_exdqlm_interval_invariance_ledger.csv"))
handoff <- ffv2_read_json(file.path(root, "integration_handoff.json"))
point_hash <- ffv2_file_sha256(file.path(root, "source_point_metric_summary.csv"))
interval_hash <- ffv2_file_sha256(file.path(root, "source_interval_summary.csv"))
exdqlm_point <- point$model_variant == "exdqlm"
exdqlm_interval <- interval$model_variant == "exdqlm"
checks <- c(
  manifest_paths_exist = all(file.exists(paths)),
  manifest_sizes_match = all(as.numeric(file.info(paths)$size) == ledger$bytes),
  manifest_hashes_match = all(
    vapply(paths, ffv2_file_sha256, character(1L)) == ledger$sha256
  ),
  handoff_ready = identical(as.character(handoff$status), "READY_FOR_INTEGRATION"),
  package_version_1p1p1 = identical(as.character(handoff$package_version), "1.1.1"),
  package_commit_exact = identical(
    as.character(handoff$package_source_commit), i111_package_source_commit
  ),
  point_rows_72 = nrow(point) == 72L,
  point_exdqlm_rows_18 = sum(exdqlm_point) == 18L,
  point_estimator_separated = all(
    point$metric_estimator_contract[exdqlm_point] == i111s_point_estimator_id
  ),
  point_source_hashes = all(vapply(
    c("fit_source_sha256", "forecast_mae_source_sha256",
      "forecast_check_source_sha256"),
    function(field) all(point[[field]][exdqlm_point] == point_hash), logical(1L)
  )),
  interval_rows_216 = nrow(interval) == 216L,
  interval_exdqlm_roles_54 = sum(exdqlm_interval) == 54L,
  interval_estimator_separated = all(
    interval$estimator_id[exdqlm_interval] == i111s_interval_estimator_id
  ),
  interval_source_hashes = all(
    interval$source_sha256[exdqlm_interval] == interval_hash
  ),
  inherited_interval_rows_162 = sum(invariance$inherited_role) == 162L,
  inherited_interval_rows_invariant = all(
    invariance$unchanged[invariance$inherited_role]
  ),
  no_heavy_binaries = !any(grepl("[.](rds|rda|RData)$", paths, ignore.case = TRUE)),
  no_article_write = isFALSE(handoff$article_write_performed),
  integration_owner_exact = identical(
    as.character(handoff$integration_owner), "ARTICLE_QDESN_INTEGRATION"
  )
)
if (!all(checks)) {
  stop(sprintf("Frozen integration verification failed: %s",
               paste(names(checks)[!checks], collapse = ", ")), call. = FALSE)
}
cat(sprintf("INTEGRATION_PACKET_VERIFIED checks=%d packet=%s\n",
            length(checks), root))

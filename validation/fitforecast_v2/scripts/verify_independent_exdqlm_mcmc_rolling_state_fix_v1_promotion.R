#!/usr/bin/env Rscript

cmd_args0 <- commandArgs(FALSE)
file_arg <- grep("^--file=", cmd_args0, value = TRUE)
this_file <- if (length(file_arg)) sub("^--file=", "", file_arg[[1L]]) else
  "validation/fitforecast_v2/scripts/verify_independent_exdqlm_mcmc_rolling_state_fix_v1_promotion.R"
harness_root <- normalizePath(file.path(dirname(this_file), ".."), winslash = "/",
                              mustWork = TRUE)
source(file.path(harness_root, "R", "utils.R"))
ffv2_source_all(harness_root)

args <- ffv2_parse_args()
repo_root <- normalizePath(args$`repo-root` %||% ffv2_repo_root(), winslash = "/",
                           mustWork = TRUE)
root <- normalizePath(
  args$`promotion-root` %||% iems_v1_frozen_promotion_root(repo_root),
  winslash = "/", mustWork = TRUE
)
manifest <- ffv2_read_csv(file.path(root, "artifact_manifest.csv"))
paths <- file.path(root, manifest$relative_path)
point <- ffv2_read_csv(file.path(
  root, "scientific", "candidate_point_exdqlm_mcmc_rows.csv"
))
interval <- ffv2_read_csv(file.path(
  root, "scientific", "candidate_interval_exdqlm_mcmc_roles.csv"
))
chains <- ffv2_read_csv(file.path(root, "scientific", "chain_metric_comparison.csv"))
metric_diagnostics <- ffv2_read_csv(file.path(
  root, "scientific", "mcmc_metric_diagnostics.csv"
))
confirmation_checks <- ffv2_read_csv(file.path(
  root, "scientific", "full_confirmation_checks.csv"
))
frozen_checks <- ffv2_read_csv(file.path(root, "promotion_checks.csv"))
replacement <- ffv2_read_csv(file.path(root, "replacement_contract.csv"))
handoff <- ffv2_read_json(file.path(root, "integration_handoff.json"))

checks <- c(
  manifest_paths_exist = all(file.exists(paths)),
  manifest_sizes_match = all(as.numeric(file.info(paths)$size) == manifest$bytes),
  manifest_hashes_match = all(
    vapply(paths, ffv2_file_sha256, character(1L)) == manifest$sha256
  ),
  iems_v1_promotion_contract_checks(
    point, interval, chains, metric_diagnostics, confirmation_checks
  ),
  frozen_checks_pass = nrow(frozen_checks) == 19L &&
    all(as.logical(frozen_checks$pass)),
  replacement_surfaces_2 = nrow(replacement) == 2L &&
    identical(sort(replacement$replacement_rows), c(9L, 27L)),
  replacement_policy_exact = all(
    replacement$replacement_policy ==
      "replace_complete_exdqlm_mcmc_block_preserve_all_non_exdqlm_rows"
  ),
  handoff_ready = identical(as.character(handoff$status), "READY_FOR_INTEGRATION"),
  handoff_decision_exact = identical(
    as.character(handoff$scientific_decision),
    "READY_FOR_INTEGRATION_REPLACE_COMPLETE_EXDQLM_MCMC_BLOCK"
  ),
  handoff_point_hash = identical(
    as.character(handoff$point_candidate_sha256),
    ffv2_file_sha256(file.path(
      root, "scientific", "candidate_point_exdqlm_mcmc_rows.csv"
    ))
  ),
  handoff_interval_hash = identical(
    as.character(handoff$interval_candidate_sha256),
    ffv2_file_sha256(file.path(
      root, "scientific", "candidate_interval_exdqlm_mcmc_roles.csv"
    ))
  ),
  handoff_package_cran_1p1p1 =
    identical(as.character(handoff$package_version), "1.1.1") &&
      identical(as.character(handoff$package_repository), "CRAN") &&
      identical(as.character(handoff$package_tarball_sha256),
                iems_v1_cran_tarball_sha256),
  integration_owner_exact = identical(
    as.character(handoff$integration_owner), "ARTICLE_QDESN_INTEGRATION"
  ),
  no_cross_lane_writes = isFALSE(handoff$article_write_performed) &&
    isFALSE(handoff$shared_validation_merge_performed) &&
    isFALSE(handoff$overleaf_write_performed),
  no_heavy_binaries = !any(grepl(
    "[.](rds|rda|RData)$", paths, ignore.case = TRUE
  ))
)
if (!all(checks)) {
  stop(sprintf("Promotion packet verification failed: %s",
               paste(names(checks)[!checks], collapse = ", ")), call. = FALSE)
}
cat(sprintf(
  "PROMOTION_PACKET_VERIFIED checks=%d packet=%s decision=%s\n",
  length(checks), root, handoff$scientific_decision
))

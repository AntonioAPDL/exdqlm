#!/usr/bin/env Rscript

cmd_args0 <- commandArgs(FALSE)
file_arg <- grep("^--file=", cmd_args0, value = TRUE)
this_file <- if (length(file_arg)) sub("^--file=", "", file_arg[[1L]]) else
  "validation/fitforecast_v2/scripts/verify_independent_mean_readout_state_forecast_v1.R"
harness_root <- normalizePath(file.path(dirname(this_file), ".."), winslash = "/",
                              mustWork = TRUE)
source(file.path(harness_root, "R", "utils.R"))
ffv2_source_all(harness_root)

args <- ffv2_parse_args()
state_root <- normalizePath(args$`state-root` %||% "", winslash = "/",
                            mustWork = TRUE)
repo_root <- normalizePath(ffv2_repo_root(), winslash = "/", mustWork = TRUE)
defaults <- yaml::read_yaml(file.path(
  repo_root, "config", "validation",
  "independent_mean_readout_state_forecast_v1", "campaign_defaults.yaml"
))
compatibility_policy <- imrs_v1_historical_compatibility_policy(
  defaults$historical_authority_compatibility
)
materialization_manifest <- imrs_v1_read_json(file.path(
  state_root, "manifests", "materialization_manifest.json"
))
execution_package_version <- as.character(
  materialization_manifest$execution_package_version
)
fit_plan <- ffv2_read_csv(file.path(state_root, "manifests", "fit_plan.csv"))
forecast_plan <- ffv2_read_csv(
  file.path(state_root, "manifests", "forecast_plan.csv")
)
role_map <- ffv2_read_csv(file.path(state_root, "manifests", "role_map.csv"))
materialized <- ffv2_read_csv(
  file.path(state_root, "manifests", "materialized_artifacts.csv")
)
closeout <- imrs_v1_read_json(file.path(state_root, "closeout", "closeout_manifest.json"))
closeout_artifacts <- ffv2_read_csv(closeout$artifact_manifest_path)
recovery_amendment <- materialization_manifest$recovery_amendment %||% NULL
recovery_amendment_pass <- if (is.null(recovery_amendment)) {
  TRUE
} else {
  record_path <- normalizePath(
    recovery_amendment$record_path, winslash = "/", mustWork = TRUE
  )
  record <- imrs_v1_read_json(record_path)
  identical(
    ffv2_file_sha256(record_path), as.character(recovery_amendment$record_sha256)
  ) && identical(
    as.character(record$recovery_id),
    as.character(recovery_amendment$recovery_id)
  ) && identical(
    ffv2_file_sha256(record$original_manifest_copy),
    as.character(recovery_amendment$original_materialization_manifest_sha256)
  ) && identical(
    ffv2_file_sha256(record$original_artifact_copy),
    as.character(recovery_amendment$original_artifact_manifest_sha256)
  )
}
role_comparison <- ffv2_read_csv(
  file.path(state_root, "closeout", "role_level_comparison.csv")
)
source_intervals <- ffv2_read_csv(
  file.path(state_root, "closeout", "source_interval_ledger.csv")
)
parity <- ffv2_read_csv(
  file.path(state_root, "closeout", "native_artifact_consistency.csv")
)
native_authority <- ffv2_read_csv(
  file.path(
    state_root, "closeout", "historical_native_authority_compatibility.csv"
  )
)
native_authority <- imrs_v1_complete_compatibility_fields(native_authority)
native_authority_source_pool <- ffv2_read_csv(file.path(
  state_root, "closeout",
  "historical_native_authority_source_pool_compatibility.csv"
))
native_authority_decisions <- lapply(fit_plan$job_id, function(id) {
  rows <- native_authority[native_authority$fit_job_id == id, , drop = FALSE]
  imrs_v1_fit_compatibility_decision(
    rows, fit_plan$inference[match(id, fit_plan$job_id)]
  )
})
innovation_pairing <- ffv2_read_csv(
  file.path(state_root, "closeout", "innovation_pairing_ledger.csv")
)
posterior_alignment <- ffv2_read_csv(file.path(
  state_root, "closeout", "native_posterior_alignment_ledger.csv"
))
primary_pairing <- innovation_pairing[
  innovation_pairing$stream == "primary", , drop = FALSE
]
alignment_counts <- table(posterior_alignment$fit_job_id)
pairing_counts <- stats::setNames(
  as.integer(primary_pairing$selected_draw_count), primary_pairing$fit_job_id
)

fit_success <- vapply(seq_len(nrow(fit_plan)), function(i) {
  imrs_v1_status_success(
    state_root, "fit", fit_plan$job_id[[i]], fit_plan$config_sha256[[i]]
  )
}, logical(1L))
forecast_success <- vapply(seq_len(nrow(forecast_plan)), function(i) {
  imrs_v1_status_success(
    state_root, "forecast", forecast_plan$forecast_id[[i]],
    forecast_plan$config_sha256[[i]]
  )
}, logical(1L))
materialized_hashes <- vapply(
  materialized$path, ffv2_file_sha256, character(1L)
)
closeout_hashes <- vapply(
  closeout_artifacts$path, ffv2_file_sha256, character(1L)
)
heavy <- list.files(
  state_root, pattern = "[.](rds|rda|RData)$", recursive = TRUE,
  full.names = TRUE, ignore.case = TRUE
)
checks <- c(
  fit_plan_rows = nrow(fit_plan) == 96L,
  forecast_plan_rows = nrow(forecast_plan) == 46L,
  role_map_rows = nrow(role_map) == 72L,
  source_identities = length(unique(role_map$source_id)) == 44L,
  fits_success = all(fit_success),
  forecasts_success = all(forecast_success),
  materialized_hashes = all(materialized_hashes == materialized$sha256),
  recovery_amendment = isTRUE(recovery_amendment_pass),
  closeout_hashes = all(closeout_hashes == closeout_artifacts$sha256),
  role_comparison_rows = nrow(role_comparison) == 72L,
  source_interval_rows = nrow(source_intervals) == 44L * 2L * 2L,
  metrics_finite = all(vapply(
    role_comparison[vapply(role_comparison, is.numeric, logical(1L))],
    function(x) all(is.finite(x)), logical(1L)
  )),
  native_artifact_consistency = all(parity$pass) &&
    max(parity$max_abs_difference) <= imrs_v1_tolerance,
  historical_native_authority_compatibility =
    nrow(native_authority) == compatibility_policy$familywise_comparisons &&
    all(vapply(
      native_authority_decisions, `[[`, logical(1L), "accepted"
    )) &&
    all(native_authority$row_count_pass) &&
    all(native_authority$finite_contract) &&
    all(native_authority$policy_schema_version ==
          compatibility_policy$schema_version) &&
    all(native_authority$authority_package_version ==
          compatibility_policy$source_package_version) &&
    all(native_authority$current_package_version ==
          execution_package_version),
  historical_native_authority_source_pool =
    nrow(native_authority_source_pool) ==
      compatibility_policy$metrics_per_fit * nrow(forecast_plan) &&
    all(native_authority_source_pool$pass) &&
    all(native_authority_source_pool$row_count_pass) &&
    all(native_authority_source_pool$finite_contract),
  posterior_draw_alignment =
    setequal(names(alignment_counts), fit_plan$job_id) &&
    setequal(names(pairing_counts), fit_plan$job_id) &&
    identical(
      as.integer(alignment_counts[fit_plan$job_id]),
      as.integer(pairing_counts[fit_plan$job_id])
    ) &&
    all(posterior_alignment$selected_position ==
          posterior_alignment$native_position) &&
    all(vapply(split(
      posterior_alignment$posterior_original_draw_index,
      posterior_alignment$fit_job_id
    ), function(x) !anyNA(x) && !anyDuplicated(x), logical(1L))),
  innovation_pairing = nrow(primary_pairing) == nrow(fit_plan) &&
    !anyDuplicated(primary_pairing$fit_job_id) &&
    setequal(primary_pairing$fit_job_id, fit_plan$job_id) &&
    all(primary_pairing$tail_seed_offset == 31L) &&
    all(primary_pairing$tail_seed - primary_pairing$full_seed == 31L) &&
    all(primary_pairing$complete_origin_count == 33L) &&
    all(primary_pairing$tail_origin_count == 1L),
  valid_decision = as.character(closeout$decision) %in% c(
    "ACCEPT_MEAN_READOUT_STATE_FOR_FULL_QDESN_SURFACE",
    "RETAIN_NATIVE_QDESN_FORECAST_RECURSION",
    "BLOCKED_PROVENANCE_OR_IMPLEMENTATION_FAILURE"
  ),
  no_heavy_binaries = length(heavy) == 0L
)
report <- list(
  schema_version = imrs_v1_schema,
  verified_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"),
  pass = all(checks), checks = as.list(checks),
  failed_checks = names(checks)[!checks],
  decision = closeout$decision,
  fit_jobs = sum(fit_success), forecast_jobs = sum(forecast_success),
  role_rows = nrow(role_comparison), heavy_binary_files = length(heavy)
)
report_path <- file.path(state_root, "closeout", "verification_report.json")
imrs_v1_atomic_write_json(report, report_path)
cat(sprintf(
  "VERIFY_%s fits=%d/96 forecasts=%d/46 roles=%d/72 heavy=%d failed=%s\n",
  if (all(checks)) "PASS" else "FAIL", sum(fit_success),
  sum(forecast_success), nrow(role_comparison), length(heavy),
  paste(names(checks)[!checks], collapse = ",")
))
quit(save = "no", status = if (all(checks)) 0L else 1L)

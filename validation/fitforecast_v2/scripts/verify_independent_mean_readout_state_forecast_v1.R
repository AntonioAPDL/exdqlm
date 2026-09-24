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
  file.path(state_root, "closeout", "historical_native_authority_parity.csv")
)
innovation_pairing <- ffv2_read_csv(
  file.path(state_root, "closeout", "innovation_pairing_ledger.csv")
)
primary_pairing <- innovation_pairing[
  innovation_pairing$stream == "primary", , drop = FALSE
]

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
  closeout_hashes = all(closeout_hashes == closeout_artifacts$sha256),
  role_comparison_rows = nrow(role_comparison) == 72L,
  source_interval_rows = nrow(source_intervals) == 44L * 2L * 2L,
  metrics_finite = all(vapply(
    role_comparison[vapply(role_comparison, is.numeric, logical(1L))],
    function(x) all(is.finite(x)), logical(1L)
  )),
  native_artifact_consistency = all(parity$pass) &&
    max(parity$max_abs_difference) <= imrs_v1_tolerance,
  historical_native_authority = nrow(native_authority) == 2L * nrow(fit_plan) &&
    all(native_authority$pass) &&
    max(native_authority$max_abs_difference) <= imrs_v1_tolerance,
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

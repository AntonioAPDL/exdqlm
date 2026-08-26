#!/usr/bin/env Rscript

cmd_args0 <- commandArgs(FALSE)
file_arg <- grep("^--file=", cmd_args0, value = TRUE)
this_file <- if (length(file_arg)) sub("^--file=", "", file_arg[[1L]]) else
  "validation/fitforecast_v2/scripts/verify_independent_origin_horizon_attribution_v1_closeout.R"
harness_root <- normalizePath(file.path(dirname(this_file), ".."), winslash = "/",
                              mustWork = TRUE)
source(file.path(harness_root, "R", "utils.R"))
ffv2_source_all(harness_root)

args <- ffv2_parse_args()
state_root <- normalizePath(args$`state-root` %||% "", winslash = "/", mustWork = TRUE)
closeout_root <- file.path(state_root, "closeout")
decision_path <- file.path(closeout_root, "decision_manifest.json")
decision <- ffv2_read_json(decision_path)
plan <- ffv2_read_csv(file.path(state_root, "manifests", "job_plan.csv"))
plan_verification <- ffv2_read_json(
  file.path(state_root, "manifests", "plan_verification.json")
)
health <- ffv2_read_json(file.path(state_root, "health", "health_current.json"))

asset_files <- c(
  status = "job_artifact_audit.csv",
  group_summary = "pooled_group_summary.csv",
  variance = "pooled_variance_decomposition.csv",
  covariance_lag = "pooled_covariance_lag_summary.csv",
  target = "pooled_target_summary.csv",
  path_structure = "chain_path_structure.csv",
  parameter_signal = "rhs_parameter_signal.csv",
  all_parameter_signal = "all_parameter_signal.csv",
  diagnosis = "cell_mechanism_diagnosis.csv",
  cpu_assignment = "cpu_assignment_audit.csv",
  reconstruction = "reconstruction_audit.csv",
  storage = "storage_audit.csv",
  checks = "closeout_checks.csv",
  lead_figure = file.path("figures", "lead_risk_profiles.pdf"),
  origin_figure = file.path("figures", "origin_risk_profiles.pdf"),
  dispersion_heatmap = file.path("figures", "origin_lead_dispersion_heatmap.pdf"),
  error_heatmap = file.path("figures", "origin_lead_error_heatmap.pdf"),
  correlation_decay_figure = file.path("figures", "origin_lead_correlation_decay.pdf"),
  report = "scientific_closeout.md"
)
asset_paths <- file.path(closeout_root, unname(asset_files))
names(asset_paths) <- names(asset_files)
expected_hashes <- unlist(decision$output_hashes, use.names = TRUE)
actual_hashes <- setNames(rep(NA_character_, length(asset_paths)), names(asset_paths))
present <- file.exists(asset_paths)
actual_hashes[present] <- vapply(asset_paths[present], ffv2_file_sha256, character(1L))

checks <- ffv2_read_csv(asset_paths[["checks"]])
checks$pass <- vapply(checks$pass, ffv2_truthy, logical(1L))
status <- ffv2_read_csv(asset_paths[["status"]])
diagnosis <- ffv2_read_csv(asset_paths[["diagnosis"]])
group_summary <- ffv2_read_csv(asset_paths[["group_summary"]])
covariance_lag <- ffv2_read_csv(asset_paths[["covariance_lag"]])
cpu_assignment <- ffv2_read_csv(asset_paths[["cpu_assignment"]])
storage <- ffv2_read_csv(asset_paths[["storage"]])

heavy <- unique(unlist(lapply(unique(plan$job_root), function(root) {
  if (!dir.exists(root)) return(character(0))
  list.files(root, pattern = "[.](rds|rda|RData)$", recursive = TRUE,
             full.names = TRUE, ignore.case = TRUE)
}), use.names = FALSE))
pdf_paths <- asset_paths[grepl("[.]pdf$", asset_paths)]
pdf_headers <- vapply(pdf_paths, function(path) {
  if (!file.exists(path)) return("")
  rawToChar(readBin(path, what = "raw", n = 4L))
}, character(1L))

verification <- data.frame(
  check = c(
    "decision_complete_no_tau0", "jobs_21_of_21", "asset_key_contract",
    "all_assets_present", "all_asset_hashes_match", "all_closeout_checks_pass",
    "plan_verification_pass", "health_complete", "seven_unique_diagnoses",
    "diagnosis_decision_consistent", "group_summary_shape",
    "covariance_lag_shape", "unique_effective_cores", "storage_light",
    "no_heavy_binaries", "pdf_headers_valid"
  ),
  pass = c(
    identical(as.character(decision$decision),
              "ATTRIBUTION_COMPLETE_NO_TAU0_CAUSAL_PILOT_AUTHORIZED") &&
      !isTRUE(decision$automatic_tau0_launch_authorized) &&
      !isTRUE(decision$article_update_authorized),
    as.integer(decision$jobs_completed) == 21L &&
      as.integer(decision$jobs_planned) == 21L && nrow(status) == 21L &&
      all(status$status == "SUCCESS"),
    setequal(names(expected_hashes), names(asset_paths)),
    all(present),
    setequal(names(expected_hashes), names(actual_hashes)) &&
      identical(unname(expected_hashes[names(actual_hashes)]),
                unname(actual_hashes)),
    nrow(checks) == 16L && all(checks$pass),
    identical(as.character(plan_verification$status), "PASS") &&
      !length(plan_verification$failed_checks),
    isTRUE(health$all_complete) && as.integer(health$completed) == 21L &&
      as.integer(health$remaining) == 0L,
    nrow(diagnosis) == 7L && anyDuplicated(diagnosis$replay_id) == 0L,
    !any(vapply(diagnosis$tau0_causal_pilot_eligible, ffv2_truthy, logical(1L))) &&
      all(nzchar(diagnosis$recommended_next_action)),
    nrow(group_summary) == 3948L && all(group_summary$n_chains == 3L),
    nrow(covariance_lag) == 1946L && all(covariance_lag$n_chains == 3L) &&
      all(is.finite(covariance_lag$chain_mean_mean_correlation)),
    nrow(cpu_assignment) == 15L &&
      !anyDuplicated(as.integer(cpu_assignment$effective_cpu_id)),
    nrow(storage) == 1L && as.integer(storage$heavy_binary_count) == 0L &&
      as.numeric(storage$maximum_job_bytes) <= 100 * 1024^2,
    length(heavy) == 0L,
    length(pdf_headers) == 5L && all(pdf_headers == "%PDF")
  ), stringsAsFactors = FALSE
)

verification_path <- ffv2_write_csv(
  verification, file.path(closeout_root, "closeout_verification.csv")
)
result <- list(
  schema_version = imoh_v1_schema,
  generated_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"),
  status = if (all(verification$pass)) "PASS" else "FAIL",
  checks = nrow(verification), failed_checks = verification$check[!verification$pass],
  decision_sha256 = ffv2_file_sha256(decision_path),
  verification_sha256 = ffv2_file_sha256(verification_path)
)
ffv2_write_json(result, file.path(closeout_root, "closeout_verification.json"))
cat(sprintf("status=%s checks=%d failed=%d decision=%s\n", result$status,
            nrow(verification), sum(!verification$pass), decision$decision))
if (!all(verification$pass)) quit(save = "no", status = 1L)

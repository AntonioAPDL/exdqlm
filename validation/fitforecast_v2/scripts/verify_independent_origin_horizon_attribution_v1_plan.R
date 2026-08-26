#!/usr/bin/env Rscript

cmd_args0 <- commandArgs(FALSE)
file_arg <- grep("^--file=", cmd_args0, value = TRUE)
this_file <- if (length(file_arg)) sub("^--file=", "", file_arg[[1L]]) else
  "validation/fitforecast_v2/scripts/verify_independent_origin_horizon_attribution_v1_plan.R"
harness_root <- normalizePath(file.path(dirname(this_file), ".."), winslash = "/",
                              mustWork = TRUE)
source(file.path(harness_root, "R", "utils.R"))
ffv2_source_all(harness_root)

args <- ffv2_parse_args()
state_root <- normalizePath(args$`state-root` %||% "", winslash = "/", mustWork = TRUE)
plan <- ffv2_read_csv(file.path(state_root, "manifests", "job_plan.csv"))
manifest <- ffv2_read_json(file.path(state_root, "manifests", "materialization_manifest.json"))
phase <- as.character(manifest$phase)
expected_sources <- if (phase == "pilot") 2L else 7L
expected_jobs <- expected_sources * 3L
configs <- lapply(plan$config_path, ffv2_read_json)
all_text <- as.character(unlist(configs, use.names = FALSE))
checks <- data.frame(
  check = c("expected_jobs", "expected_sources", "three_chains", "qdesn_mcmc_only",
            "config_hashes", "attribution_required", "dispersion_required",
            "case_specific_frozen", "storage_light", "all1000_and_balanced990",
            "no_stale_home_paths", "no_existing_heavy_binaries"),
  pass = c(
    nrow(plan) == expected_jobs,
    length(unique(plan$replay_id)) == expected_sources,
    all(table(plan$replay_id) == 3L),
    all(plan$engine == "qdesn" & plan$inference == "mcmc"),
    identical(unname(vapply(plan$config_path, ffv2_file_sha256, character(1L))),
              unname(as.character(plan$config_sha256))),
    all(vapply(configs, function(x) {
      isTRUE(x$config$metrics$posterior_metric_intervals$origin_horizon_attribution$enabled) &&
        isTRUE(x$config$metrics$posterior_metric_intervals$origin_horizon_attribution$required)
    }, logical(1L))),
    all(vapply(configs, function(x) {
      isTRUE(x$config$metrics$posterior_metric_intervals$dispersion_diagnostic$enabled) &&
        isTRUE(x$config$metrics$posterior_metric_intervals$dispersion_diagnostic$required)
    }, logical(1L))),
    all(vapply(configs, function(x) {
      isTRUE(x$study_contract$origin_horizon_attribution$case_specific_design_frozen)
    }, logical(1L))),
    all(vapply(configs, function(x) {
      identical(x$config$outputs$retention_profile, "storage_light") &&
        !isTRUE(x$config$outputs$save_forecast_objects)
    }, logical(1L))),
    all(vapply(configs, function(x) {
      identical(as.integer(x$study_contract$origin_horizon_attribution$complete_target_scope),
                1000L) &&
        identical(as.integer(x$study_contract$origin_horizon_attribution$balanced_sensitivity_scope),
                  990L)
    }, logical(1L))),
    !any(startsWith(all_text, "/home/jaguir26/local/src")),
    !any(vapply(unique(plan$job_root), function(root) {
      dir.exists(root) && length(list.files(root, pattern = "[.](rds|rda|RData)$",
                                            recursive = TRUE, ignore.case = TRUE)) > 0L
    }, logical(1L)))
  ), stringsAsFactors = FALSE
)
path <- ffv2_write_csv(checks, file.path(state_root, "manifests", "plan_verification.csv"))
result <- list(
  schema_version = imoh_v1_schema,
  generated_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"),
  phase = phase, status = if (all(checks$pass)) "PASS" else "FAIL",
  checks = nrow(checks), failed_checks = as.character(checks$check[!checks$pass]),
  checks_sha256 = ffv2_file_sha256(path)
)
ffv2_write_json(result, file.path(state_root, "manifests", "plan_verification.json"))
cat(sprintf("phase=%s status=%s checks=%d failed=%d\n", phase, result$status,
            nrow(checks), sum(!checks$pass)))
if (!all(checks$pass)) quit(save = "no", status = 1L)

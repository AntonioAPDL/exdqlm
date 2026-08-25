#!/usr/bin/env Rscript

cmd_args0 <- commandArgs(FALSE)
file_arg <- grep("^--file=", cmd_args0, value = TRUE)
this_file <- if (length(file_arg)) sub("^--file=", "", file_arg[[1L]]) else
  "validation/fitforecast_v2/scripts/verify_independent_interval_dispersion_diagnostic_v1_plan.R"
harness_root <- normalizePath(file.path(dirname(this_file), ".."), winslash = "/", mustWork = TRUE)
source(file.path(harness_root, "R", "utils.R"))
ffv2_source_all(harness_root)

args <- ffv2_parse_args()
state_root <- normalizePath(args$`state-root` %||% "", winslash = "/", mustWork = TRUE)
plan <- ffv2_read_csv(file.path(state_root, "manifests", "job_plan.csv"))
selection <- ffv2_read_csv(file.path(state_root, "manifests", "sentinel_sources.csv"))
configs <- lapply(plan$config_path, ffv2_read_json)
config_hashes <- vapply(plan$config_path, ffv2_file_sha256, character(1L))
dispersion_enabled <- vapply(configs, function(x) {
  isTRUE(x$config$metrics$posterior_metric_intervals$dispersion_diagnostic$enabled) &&
    isTRUE(x$config$metrics$posterior_metric_intervals$dispersion_diagnostic$required) &&
    isTRUE(x$config$metrics$posterior_metric_intervals$dispersion_diagnostic$recursion_counterfactual)
}, logical(1L))
coupling_enabled <- vapply(configs, function(x) {
  isTRUE(x$config$metrics$posterior_metric_intervals$coupling_sensitivity$enabled)
}, logical(1L))
exal_m0 <- vapply(seq_along(configs), function(i) {
  plan$model_variant[[i]] != "qdesn_exal_rhs_ns" ||
    identical(as.character(configs[[i]]$config$inference$mcmc$slice$core_update_mode),
              "m0_v_collapsed_support_logit")
}, logical(1L))
all_text <- as.character(unlist(configs, use.names = FALSE))
checks <- data.frame(
  check = c("jobs_21", "sources_7", "three_chains_per_source", "qdesn_mcmc_only",
            "selection_identity", "config_hashes_match", "dispersion_required_all",
            "coupling_enabled_all", "exal_uses_exact_m0", "case_specific_design_frozen",
            "storage_light_all", "no_stale_home_paths", "no_existing_heavy_binaries"),
  pass = c(
    nrow(plan) == 21L,
    length(unique(plan$replay_id)) == 7L && nrow(selection) == 7L,
    all(table(plan$replay_id) == 3L),
    all(plan$engine == "qdesn" & plan$inference == "mcmc"),
    setequal(unique(plan$replay_id), selection$replay_id),
    identical(unname(config_hashes), unname(as.character(plan$config_sha256))),
    all(dispersion_enabled),
    all(coupling_enabled),
    all(exal_m0),
    all(vapply(configs, function(x) isTRUE(x$study_contract$dispersion_diagnostic$case_specific_design_frozen), logical(1L))),
    all(vapply(configs, function(x) identical(as.character(x$config$outputs$retention_profile), "storage_light") &&
      !isTRUE(x$config$outputs$save_forecast_objects), logical(1L))),
    !any(startsWith(all_text, "/home/jaguir26/local/src")),
    !any(vapply(unique(plan$job_root), function(root) {
      dir.exists(root) && length(list.files(root, pattern = "[.](rds|rda|RData)$",
                                            recursive = TRUE, ignore.case = TRUE)) > 0L
    }, logical(1L)))
  ),
  stringsAsFactors = FALSE
)
path <- ffv2_write_csv(checks, file.path(state_root, "manifests", "plan_verification.csv"))
manifest <- list(
  schema_version = imid_v1_schema,
  generated_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"),
  status = if (all(checks$pass)) "PASS" else "FAIL",
  checks = nrow(checks),
  failed_checks = as.character(checks$check[!checks$pass]),
  checks_sha256 = ffv2_file_sha256(path)
)
ffv2_write_json(manifest, file.path(state_root, "manifests", "plan_verification.json"))
cat(sprintf("status=%s checks=%d failed=%d\n", manifest$status, nrow(checks), sum(!checks$pass)))
if (!all(checks$pass)) quit(save = "no", status = 1L)

#!/usr/bin/env Rscript

cmd_args0 <- commandArgs(FALSE)
file_arg <- grep("^--file=", cmd_args0, value = TRUE)
this_file <- if (length(file_arg)) sub("^--file=", "", file_arg[[1L]]) else
  "validation/fitforecast_v2/scripts/verify_independent_metric_interval_coupling_pilot_v1_plan.R"
harness_root <- normalizePath(file.path(dirname(this_file), ".."), winslash = "/", mustWork = TRUE)
source(file.path(harness_root, "R", "utils.R"))
ffv2_source_all(harness_root)

args <- ffv2_parse_args()
state_root <- normalizePath(args$`state-root` %||% "", winslash = "/", mustWork = TRUE)
plan <- ffv2_read_csv(file.path(state_root, "manifests", "job_plan.csv"))
selection <- ffv2_read_csv(file.path(state_root, "manifests", "pilot_sources.csv"))
configs <- lapply(plan$config_path, ffv2_read_json)

config_hashes <- vapply(plan$config_path, ffv2_file_sha256, character(1L))
coupling_enabled <- vapply(seq_along(configs), function(i) {
  cfg <- configs[[i]]
  if (plan$engine[[i]] == "qdesn") {
    isTRUE(cfg$config$metrics$posterior_metric_intervals$coupling_sensitivity$enabled)
  } else isTRUE(cfg$metric_intervals$coupling_sensitivity$enabled)
}, logical(1L))
exal_m0 <- vapply(seq_along(configs), function(i) {
  if (plan$engine[[i]] != "qdesn" || plan$model_variant[[i]] != "qdesn_exal_rhs_ns") {
    return(TRUE)
  }
  identical(as.character(configs[[i]]$config$inference$mcmc$slice$core_update_mode),
            "m0_v_collapsed_support_logit")
}, logical(1L))
all_text <- unlist(lapply(configs, function(x) unlist(x, use.names = FALSE)), use.names = FALSE)
all_text <- as.character(all_text[is.character(all_text)])
checks <- data.frame(
  check = c("jobs_33", "sources_11", "three_chains_per_source", "qdesn_jobs_21",
            "dqlm_jobs_12", "two_cells_only", "config_hashes_match",
            "coupling_enabled_all", "exal_uses_m0", "unique_cpu_ids_available",
            "no_stale_home_paths", "no_existing_heavy_binaries"),
  pass = c(
    nrow(plan) == 33L,
    length(unique(plan$replay_id)) == 11L && nrow(selection) == 11L,
    all(table(plan$replay_id) == 3L),
    sum(plan$engine == "qdesn") == 21L,
    sum(plan$engine == "dqlm") == 12L,
    setequal(unique(paste(plan$family, plan$tau)), c("normal 0.25", "gausmix 0.05")),
    identical(config_hashes, as.character(plan$config_sha256)),
    all(coupling_enabled),
    all(exal_m0),
    length(unique(plan$cpu_id)) >= 1L,
    !any(startsWith(all_text, "/home/jaguir26/local/src")),
    !any(vapply(unique(plan$job_root), function(root) {
      length(list.files(root, pattern = "[.](rds|rda|RData)$", recursive = TRUE,
                        ignore.case = TRUE)) > 0L
    }, logical(1L)))
  ),
  stringsAsFactors = FALSE
)
out_path <- ffv2_write_csv(checks, file.path(state_root, "manifests", "plan_verification.csv"))
manifest <- list(
  schema_version = imic_v1_schema,
  generated_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"),
  status = if (all(checks$pass)) "PASS" else "FAIL",
  checks = nrow(checks),
  failed_checks = as.character(checks$check[!checks$pass]),
  checks_sha256 = ffv2_file_sha256(out_path)
)
ffv2_write_json(manifest, file.path(state_root, "manifests", "plan_verification.json"))
cat(sprintf("status=%s checks=%d failed=%d\n", manifest$status, nrow(checks),
            sum(!checks$pass)))
if (!all(checks$pass)) quit(save = "no", status = 1L)

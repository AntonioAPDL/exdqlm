#!/usr/bin/env Rscript
cmd <- commandArgs(FALSE); file_arg <- grep("^--file=", cmd, value = TRUE)
this_file <- if (length(file_arg)) sub("^--file=", "", file_arg[[1L]]) else
  "validation/fitforecast_v2/scripts/verify_independent_common_shift_intervention_v1_plan.R"
harness_root <- normalizePath(file.path(dirname(this_file), ".."), mustWork = TRUE)
source(file.path(harness_root, "R", "utils.R")); ffv2_source_all(harness_root)
args <- ffv2_parse_args(); state_root <- normalizePath(args$`state-root`, mustWork = TRUE)
plan <- ffv2_read_csv(file.path(state_root, "manifests", "job_plan.csv"))
configs <- lapply(plan$config_path, ffv2_read_json)
checks <- data.frame(
  check = c("six_jobs", "two_sources", "three_chains", "frozen_cells", "config_hashes",
            "intervention_required", "no_tau0_change", "storage_light", "unique_cpus",
            "no_article_promotion", "no_stale_home_paths"),
  pass = c(
    nrow(plan) == 6L, setequal(unique(plan$replay_id), icsi_v1_sources),
    all(table(plan$replay_id) == 3L),
    all(plan$family == "normal" & plan$tau == 0.05 & plan$inference == "mcmc"),
    identical(unname(vapply(plan$config_path, ffv2_file_sha256, character(1L))),
              unname(as.character(plan$config_sha256))),
    all(vapply(configs, function(x) isTRUE(x$config$metrics$posterior_metric_intervals$
      common_shift_intervention$enabled) && isTRUE(x$config$metrics$
      posterior_metric_intervals$common_shift_intervention$required), logical(1L))),
    all(vapply(configs, function(x) isTRUE(x$study_contract$common_shift_intervention$
      no_tau0_change), logical(1L))),
    all(vapply(configs, function(x) identical(x$config$outputs$retention_profile,
      "storage_light") && !isTRUE(x$config$outputs$save_forecast_objects), logical(1L))),
    !anyDuplicated(plan$cpu_id),
    all(vapply(configs, function(x) isTRUE(x$study_contract$common_shift_intervention$
      no_article_promotion), logical(1L))),
    !any(startsWith(as.character(unlist(configs, use.names = FALSE)),
                    "/home/jaguir26/local/src"))
  ), stringsAsFactors = FALSE)
ffv2_write_csv(checks, file.path(state_root, "manifests", "plan_verification.csv"))
cat(sprintf("status=%s checks=%d failed=%d\n",
            if (all(checks$pass)) "PASS" else "FAIL", nrow(checks), sum(!checks$pass)))
if (!all(checks$pass)) quit(save = "no", status = 1L)

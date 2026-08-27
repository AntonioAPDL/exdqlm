#!/usr/bin/env Rscript
cmd <- commandArgs(FALSE); file_arg <- grep("^--file=", cmd, value = TRUE)
this_file <- if (length(file_arg)) sub("^--file=", "", file_arg[[1L]]) else
  "validation/fitforecast_v2/scripts/closeout_independent_common_shift_intervention_v1.R"
harness_root <- normalizePath(file.path(dirname(this_file), ".."), mustWork = TRUE)
source(file.path(harness_root, "R", "utils.R")); ffv2_source_all(harness_root)
args <- ffv2_parse_args(); state_root <- normalizePath(args$`state-root`, mustWork = TRUE)
health <- ffv2_read_json(file.path(state_root, "health", "health_current.json"))
if (!isTRUE(health$all_complete) || health$failed != 0L) stop("Campaign is incomplete.")
effects <- icsi_v1_pool_effects(state_root); result <- icsi_v1_decide(effects)
closeout <- file.path(state_root, "closeout"); ffv2_ensure_dir(closeout)
effects_path <- ffv2_write_csv(effects, file.path(closeout, "chain_intervention_effects.csv"))
pooled_path <- ffv2_write_csv(result$pooled, file.path(closeout, "pooled_intervention_effects.csv"))
decision_path <- ffv2_write_csv(result$decision, file.path(closeout, "cell_decisions.csv"))
heavy <- list.files(unique(dirname(dirname(ffv2_read_csv(file.path(state_root,
  "manifests", "job_plan.csv"))$job_root))), pattern = "[.](rds|rda|RData)$",
  recursive = TRUE, full.names = TRUE, ignore.case = TRUE)
decision <- list(
  schema_version = icsi_v1_schema, generated_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"),
  decision = if (any(result$decision$location_bias_gate))
    "AUTHORIZE_MATCHED_LOCATION_DESIGN_INTERVENTION" else
    "NO_CAUSAL_LOCATION_INTERVENTION_RETAIN_AUTHORITY",
  jobs_completed = health$completed, jobs_planned = health$planned,
  cells = nrow(result$decision), heavy_binary_count = length(heavy),
  article_update_authorized = FALSE, tau0_launch_authorized = FALSE,
  next_stage_automatic_launch_authorized = FALSE,
  output_hashes = list(effects = ffv2_file_sha256(effects_path),
                       pooled = ffv2_file_sha256(pooled_path),
                       cells = ffv2_file_sha256(decision_path)))
ffv2_write_json(decision, file.path(closeout, "decision_manifest.json"))
cat(sprintf("decision=%s jobs=%d/%d cells=%d\n", decision$decision,
            decision$jobs_completed, decision$jobs_planned, decision$cells))

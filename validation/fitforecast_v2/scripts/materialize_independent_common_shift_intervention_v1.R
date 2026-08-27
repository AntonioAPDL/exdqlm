#!/usr/bin/env Rscript

cmd <- commandArgs(FALSE)
file_arg <- grep("^--file=", cmd, value = TRUE)
this_file <- if (length(file_arg)) sub("^--file=", "", file_arg[[1L]]) else
  "validation/fitforecast_v2/scripts/materialize_independent_common_shift_intervention_v1.R"
harness_root <- normalizePath(file.path(dirname(this_file), ".."), winslash = "/",
                              mustWork = TRUE)
source(file.path(harness_root, "R", "utils.R"))
ffv2_source_all(harness_root)
args <- ffv2_parse_args()
repo_root <- normalizePath(args$`repo-root` %||% ffv2_repo_root(), winslash = "/",
                           mustWork = TRUE)
source_state <- normalizePath(args$`source-state` %||% "", winslash = "/",
                              mustWork = TRUE)
run_id <- as.character(args$`run-id` %||% "")[[1L]]
cpu_ids <- as.integer(strsplit(as.character(args$`cpu-list` %||% ""), ",",
                               fixed = TRUE)[[1L]])
if (!nzchar(run_id) || length(cpu_ids) < 6L || any(!is.finite(cpu_ids)) ||
    anyDuplicated(cpu_ids)) stop("A run id and six unique CPUs are required.", call. = FALSE)
state_root <- file.path(repo_root, "reports", "shared_fitforecast_v2_orchestration", run_id)
result_root <- file.path(repo_root, "results", "qdesn_mcmc_validation", icsi_v1_stage, run_id)
if (dir.exists(state_root) || dir.exists(result_root)) stop("Run roots already exist.", call. = FALSE)
source_plan <- ffv2_read_csv(file.path(source_state, "manifests", "job_plan.csv"))
selected <- source_plan[source_plan$replay_id %in% icsi_v1_sources, , drop = FALSE]
if (nrow(selected) != 6L || any(table(selected$replay_id) != 3L)) {
  stop("Frozen source state does not contain both three-chain cells.", call. = FALSE)
}
ffv2_ensure_dir(file.path(state_root, "configs"))
ffv2_ensure_dir(result_root)
source_inputs <- file.path(source_state, "sources")
if (!isTRUE(file.copy(source_inputs, state_root, recursive = TRUE, copy.mode = TRUE))) {
  stop("Could not stage frozen source inputs.", call. = FALSE)
}
old_run_id <- basename(source_state)
rows <- vector("list", nrow(selected))
for (i in seq_len(nrow(selected))) {
  old <- selected[i, , drop = FALSE]
  config <- imid_v1_recursive_replace(ffv2_read_json(old$config_path[[1L]]),
    setNames(c(repo_root, run_id), c(dirname(dirname(dirname(source_state))), old_run_id)))
  config$schema_version <- icsi_v1_schema
  config$run_id <- run_id
  config$job_root <- file.path(result_root, "jobs", old$job_id[[1L]])
  config$config$metrics$posterior_metric_intervals$common_shift_intervention <- list(
    enabled = TRUE, required = TRUE, schema_version = icsi_v1_schema
  )
  config$study_contract$common_shift_intervention <- list(
    diagnostic_only = TRUE, authoritative_specification_frozen = TRUE,
    seeds_frozen = TRUE, no_tau0_change = TRUE, no_article_promotion = TRUE,
    full_forecast_draw_matrix_retention = FALSE,
    common_mode_variance_ratio_gate = 0.75,
    oracle_location_mean_ratio_gate = 0.90
  )
  path <- file.path(state_root, "configs", paste0(old$job_id[[1L]], ".json"))
  ffv2_write_json(config, path)
  rows[[i]] <- data.frame(
    job_id = old$job_id[[1L]], engine = "qdesn", replay_id = old$replay_id[[1L]],
    source_identity = old$source_identity[[1L]], model_variant = old$model_variant[[1L]],
    family = old$family[[1L]], tau = old$tau[[1L]], inference = "mcmc",
    chain_id = old$chain_id[[1L]], sentinel_role = old$sentinel_role[[1L]],
    campaign_phase = "causal_diagnostic", config_path = normalizePath(path),
    config_sha256 = ffv2_file_sha256(path), job_root = config$job_root,
    expected_draws = 4000L, cpu_id = cpu_ids[[i]], status = "PENDING",
    stringsAsFactors = FALSE
  )
}
plan <- do.call(rbind, rows)
plan_path <- ffv2_write_csv(plan, file.path(state_root, "manifests", "job_plan.csv"))
ffv2_write_json(list(
  schema_version = icsi_v1_schema, run_id = run_id,
  generated_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"),
  git_commit = system2("git", c("-C", repo_root, "rev-parse", "HEAD"), stdout = TRUE)[[1L]],
  source_state = source_state, source_state_run_id = old_run_id,
  selected_sources = 2L, planned_jobs = 6L, newly_materialized_jobs = 6L,
  cpu_ids = cpu_ids[seq_len(6L)], plan_path = plan_path,
  plan_sha256 = ffv2_file_sha256(plan_path), fitted_model_binary_retention = FALSE,
  article_update_authorized = FALSE, tau0_launch_authorized = FALSE
), file.path(state_root, "manifests", "materialization_manifest.json"))
cat(sprintf("state_root=%s jobs=6 sources=2\n", state_root))

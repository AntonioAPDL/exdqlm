#!/usr/bin/env Rscript

cmd_args0 <- commandArgs(FALSE)
file_arg <- grep("^--file=", cmd_args0, value = TRUE)
this_file <- if (length(file_arg)) sub("^--file=", "", file_arg[[1L]]) else
  "validation/fitforecast_v2/scripts/materialize_independent_metric_interval_coupling_pilot_v1.R"
harness_root <- normalizePath(file.path(dirname(this_file), ".."), winslash = "/", mustWork = TRUE)
source(file.path(harness_root, "R", "utils.R"))
ffv2_source_all(harness_root)

args <- ffv2_parse_args()
repo_root <- normalizePath(args$`repo-root` %||% ffv2_repo_root(), winslash = "/", mustWork = TRUE)
source_repo <- normalizePath(args$`source-repo` %||% "", winslash = "/", mustWork = TRUE)
run_id <- as.character(args$`run-id` %||% "")[1L]
cpu_ids <- as.integer(strsplit(as.character(args$`cpu-list` %||% ""), ",", fixed = TRUE)[[1L]])
if (!nzchar(run_id) || any(!is.finite(cpu_ids)) || length(cpu_ids) < 1L || anyDuplicated(cpu_ids)) {
  stop("--run-id and a unique numeric --cpu-list are required.", call. = FALSE)
}

source_state <- file.path(source_repo, "reports", "shared_fitforecast_v2_orchestration",
                          imic_v1_production_run_id)
state_root <- file.path(repo_root, "reports", "shared_fitforecast_v2_orchestration", run_id)
result_root <- file.path(repo_root, "results", "qdesn_mcmc_validation",
                         imic_v1_pilot_stage, run_id)
if (!dir.exists(source_state) || dir.exists(state_root) || dir.exists(result_root)) {
  stop("Frozen source state must exist and new pilot state/result roots must not exist.",
       call. = FALSE)
}

selection <- imic_v1_read_selection(repo_root)
promotion_dir <- imic_v1_promotion_dir(repo_root)
job_audit <- ffv2_read_csv(file.path(promotion_dir, "job_artifact_audit.csv"))
selected_jobs <- job_audit[job_audit$replay_id %in% selection$replay_id, , drop = FALSE]
selected_jobs <- selected_jobs[selected_jobs$chain_id %in% 1:3, , drop = FALSE]
if (nrow(selected_jobs) != 33L || anyDuplicated(selected_jobs$job_id) ||
    any(table(selected_jobs$replay_id) != 3L)) {
  stop("Pilot authority must resolve to 11 replay ids and 33 three-chain jobs.", call. = FALSE)
}

ffv2_ensure_dir(state_root)
ffv2_ensure_dir(result_root)
source_input_root <- file.path(source_state, "sources")
if (dir.exists(source_input_root)) {
  copied <- file.copy(source_input_root, state_root, recursive = TRUE, copy.mode = TRUE)
  if (!isTRUE(copied)) stop("Could not stage frozen Q-DESN source inputs.", call. = FALSE)
}

replacements <- setNames(c(repo_root, run_id), c(source_repo, imic_v1_production_run_id))
plan_rows <- list()
for (i in seq_len(nrow(selected_jobs))) {
  authority <- selected_jobs[i, , drop = FALSE]
  job_id <- as.character(authority$job_id[[1L]])
  status_path <- file.path(source_state, "status", paste0(job_id, ".json"))
  status <- ffv2_read_json(status_path)
  if (!identical(as.character(status$status), "SUCCESS")) {
    stop(sprintf("Frozen source status is not SUCCESS: %s", job_id), call. = FALSE)
  }
  source_config_path <- normalizePath(status$config_path, winslash = "/", mustWork = TRUE)
  config <- ffv2_read_json(source_config_path)
  config <- imic_v1_recursive_replace(config, replacements)
  coupling_seed <- imi_v1_seed("metric_coupling_pilot_v1", authority$replay_id[[1L]],
                               authority$chain_id[[1L]])
  if (authority$engine[[1L]] == "qdesn") {
    config$run_id <- run_id
    config$job_root <- file.path(result_root, "jobs", job_id)
    config$root_spec$root_id <- job_id
    config$config$metrics$posterior_metric_intervals$coupling_sensitivity <- list(
      enabled = TRUE,
      seed = coupling_seed,
      modes = c("native_aligned", "origin_independent_permutation"),
      decision_contract = "paired_marginal_coupling_sensitivity_v1"
    )
    config$study_contract$coupling_sensitivity <- list(
      enabled = TRUE,
      primary = "native_aligned",
      alternative = "origin_independent_permutation",
      no_hyperparameter_reselection = TRUE
    )
    config_path <- file.path(state_root, "configs", paste0(job_id, ".json"))
    if (!identical(ffv2_file_sha256(config$source_request_path),
                   as.character(config$source_request_sha256))) {
      stop(sprintf("Rewritten source request hash mismatch: %s", job_id), call. = FALSE)
    }
    if (!identical(ffv2_file_sha256(config$observed_path),
                   as.character(config$observed_sha256)) ||
        !identical(ffv2_file_sha256(config$source_series_path),
                   as.character(config$source_series_sha256))) {
      stop(sprintf("Rewritten Q-DESN source hash mismatch: %s", job_id), call. = FALSE)
    }
  } else {
    config$run_tag <- sub(imic_v1_production_run_id, run_id, config$run_tag, fixed = TRUE)
    config$run_root <- file.path(result_root, "dqlm", basename(config$run_root))
    path_fields <- c(
      "row_manifest_path", "row_config_path", "row_status_path", "row_health_path",
      "row_metrics_path", "fit_path_summary_path", "forecast_path_summary_path",
      "row_progress_path", "row_heartbeat_path", "forecast_lead_metrics_path",
      "artifact_manifest_path", "fit_handoff_path", "fit_handoff_manifest_path",
      "vb_init_handoff_path", "vb_init_handoff_manifest_path", "log_path",
      "metric_draws_path", "metric_interval_summary_path", "metric_interval_manifest_path"
    )
    old_run_root <- dirname(dirname(config$row_config_path))
    for (field in path_fields) {
      if (!is.null(config[[field]])) {
        suffix <- substring(config[[field]], nchar(old_run_root) + 2L)
        config[[field]] <- file.path(config$run_root, suffix)
      }
    }
    row_key <- as.character(config$row_key)
    config$repo_root <- repo_root
    config$harness_root <- file.path(repo_root, "validation", "fitforecast_v2")
    config$defaults_path <- file.path(config$harness_root, "config",
                                      "exdqlm_dynamic_fitforecast_v2_defaults.yaml")
    config$metric_intervals$coupling_sensitivity <- list(
      enabled = TRUE,
      seed = coupling_seed,
      modes = c("origin_independent", "common_marginal_rank"),
      decision_contract = "paired_marginal_coupling_sensitivity_v1"
    )
    config$metric_coupling_draws_path <- file.path(
      config$run_root, "metric_coupling_draws", paste0(row_key, "_metric_coupling_draws.csv.gz")
    )
    config$metric_coupling_summary_path <- file.path(
      config$run_root, "metric_coupling_summaries",
      paste0(row_key, "_metric_coupling_summary.csv")
    )
    config$metric_coupling_manifest_path <- file.path(
      config$run_root, "metric_coupling_manifests",
      paste0(row_key, "_metric_coupling_manifest.json")
    )
    config$row_config_path <- file.path(config$run_root, "configs",
                                        paste0(row_key, "_config.json"))
    config_path <- config$row_config_path
    config$source_replay_id <- as.character(authority$replay_id[[1L]])
    config$chain_id <- as.integer(authority$chain_id[[1L]])
  }
  ffv2_write_json(config, config_path)
  plan_rows[[i]] <- data.frame(
    job_id = job_id,
    engine = as.character(authority$engine[[1L]]),
    replay_id = as.character(authority$replay_id[[1L]]),
    source_identity = as.character(authority$replay_id[[1L]]),
    model_variant = as.character(authority$model_variant[[1L]]),
    family = as.character(authority$family[[1L]]),
    tau = as.numeric(authority$tau[[1L]]),
    inference = "mcmc",
    chain_id = as.integer(authority$chain_id[[1L]]),
    config_path = normalizePath(config_path, winslash = "/", mustWork = TRUE),
    config_sha256 = ffv2_file_sha256(config_path),
    job_root = if (authority$engine[[1L]] == "qdesn") config$job_root else config$run_root,
    expected_draws = 4000L,
    cpu_id = cpu_ids[((i - 1L) %% length(cpu_ids)) + 1L],
    status = "PENDING",
    stringsAsFactors = FALSE
  )
}

plan <- do.call(rbind, plan_rows)
plan <- plan[order(plan$engine, plan$replay_id, plan$chain_id), , drop = FALSE]
plan_path <- ffv2_write_csv(plan, file.path(state_root, "manifests", "job_plan.csv"))
selection_copy <- ffv2_write_csv(selection,
                                 file.path(state_root, "manifests", "pilot_sources.csv"))
manifest <- list(
  schema_version = imic_v1_schema,
  run_id = run_id,
  generated_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"),
  git_commit = system2("git", c("-C", repo_root, "rev-parse", "HEAD"), stdout = TRUE)[[1L]],
  source_run_id = imic_v1_production_run_id,
  source_repo_head = system2("git", c("-C", source_repo, "rev-parse", "HEAD"),
                             stdout = TRUE)[[1L]],
  selected_sources = length(unique(plan$replay_id)),
  planned_jobs = nrow(plan),
  qdesn_jobs = sum(plan$engine == "qdesn"),
  dqlm_jobs = sum(plan$engine == "dqlm"),
  cpu_ids = sort(unique(plan$cpu_id)),
  plan_path = plan_path,
  plan_sha256 = ffv2_file_sha256(plan_path),
  selection_sha256 = ffv2_file_sha256(selection_copy),
  fitted_model_binary_retention = FALSE
)
ffv2_write_json(manifest, file.path(state_root, "manifests", "materialization_manifest.json"))
cat(sprintf("state_root=%s jobs=%d sources=%d qdesn=%d dqlm=%d cpus=%s\n",
            state_root, nrow(plan), length(unique(plan$replay_id)),
            sum(plan$engine == "qdesn"), sum(plan$engine == "dqlm"),
            paste(sort(unique(plan$cpu_id)), collapse = ",")))

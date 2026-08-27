#!/usr/bin/env Rscript

cmd_args0 <- commandArgs(FALSE)
file_arg <- grep("^--file=", cmd_args0, value = TRUE)
this_file <- if (length(file_arg)) sub("^--file=", "", file_arg[[1L]]) else
  "validation/fitforecast_v2/scripts/materialize_independent_interval_dispersion_diagnostic_v1.R"
harness_root <- normalizePath(file.path(dirname(this_file), ".."), winslash = "/", mustWork = TRUE)
source(file.path(harness_root, "R", "utils.R"))
ffv2_source_all(harness_root)

args <- ffv2_parse_args()
repo_root <- normalizePath(args$`repo-root` %||% ffv2_repo_root(), winslash = "/", mustWork = TRUE)
source_repo <- normalizePath(args$`source-repo` %||% "", winslash = "/", mustWork = TRUE)
run_id <- as.character(args$`run-id` %||% "")[1L]
cpu_ids <- as.integer(strsplit(as.character(args$`cpu-list` %||% ""), ",", fixed = TRUE)[[1L]])
if (!nzchar(run_id) || any(!is.finite(cpu_ids)) || length(cpu_ids) < 1L ||
    anyDuplicated(cpu_ids)) {
  stop("--run-id and a unique numeric --cpu-list are required.", call. = FALSE)
}

source_state <- file.path(source_repo, "reports", "shared_fitforecast_v2_orchestration",
                          imid_v1_production_run_id)
state_root <- file.path(repo_root, "reports", "shared_fitforecast_v2_orchestration", run_id)
result_root <- file.path(repo_root, "results", "qdesn_mcmc_validation",
                         imid_v1_stage, run_id)
if (!dir.exists(source_state) || dir.exists(state_root) || dir.exists(result_root)) {
  stop("Frozen source state must exist and new diagnostic roots must not exist.",
       call. = FALSE)
}

selection <- imid_v1_read_selection(repo_root)
audit <- ffv2_read_csv(file.path(imid_v1_promotion_dir(repo_root), "job_artifact_audit.csv"))
selected <- audit[audit$replay_id %in% selection$replay_id & audit$chain_id %in% 1:3,
                  , drop = FALSE]
selected <- merge(
  selected,
  selection[c("replay_id", "sentinel_role", "source_candidate_id", "rationale")],
  by = "replay_id", all.x = TRUE, sort = FALSE, suffixes = c("", "_selected")
)
if (nrow(selected) != 21L || anyDuplicated(selected$job_id) ||
    any(table(selected$replay_id) != 3L) || any(selected$engine != "qdesn") ||
    any(selected$inference != "mcmc")) {
  stop("Sentinel authority must resolve to seven Q-DESN replay ids and 21 chains.",
       call. = FALSE)
}

ffv2_ensure_dir(state_root)
ffv2_ensure_dir(result_root)
source_input_root <- file.path(source_state, "sources")
if (!dir.exists(source_input_root) ||
    !isTRUE(file.copy(source_input_root, state_root, recursive = TRUE, copy.mode = TRUE))) {
  stop("Could not stage the frozen source inputs.", call. = FALSE)
}

replacements <- setNames(c(repo_root, run_id), c(source_repo, imid_v1_production_run_id))
plan_rows <- vector("list", nrow(selected))
for (i in seq_len(nrow(selected))) {
  authority <- selected[i, , drop = FALSE]
  job_id <- as.character(authority$job_id[[1L]])
  source_status <- ffv2_read_json(file.path(source_state, "status", paste0(job_id, ".json")))
  if (!identical(as.character(source_status$status), "SUCCESS")) {
    stop(sprintf("Frozen source status is not SUCCESS: %s", job_id), call. = FALSE)
  }
  source_config_path <- normalizePath(source_status$config_path, winslash = "/", mustWork = TRUE)
  config <- imid_v1_recursive_replace(ffv2_read_json(source_config_path), replacements)
  if (!identical(as.character(config$source_candidate_id),
                 as.character(authority$source_candidate_id[[1L]]))) {
    stop(sprintf("Sentinel candidate identity mismatch: %s", job_id), call. = FALSE)
  }
  config$schema_version <- imid_v1_schema
  config$run_id <- run_id
  config$job_root <- file.path(result_root, "jobs", job_id)
  config$root_spec$root_id <- job_id
  config$config$outputs$keep_draws <- TRUE
  config$config$outputs$retention_profile <- "storage_light"
  config$config$outputs$save_forecast_objects <- FALSE
  config$config$outputs$save_compact_fit_paths <- TRUE
  config$config$outputs$retain_full_rds_on_failure <- FALSE
  coupling_seed <- imi_v1_seed("interval_dispersion_coupling_v1", authority$replay_id[[1L]],
                               authority$chain_id[[1L]])
  config$config$metrics$posterior_metric_intervals$coupling_sensitivity <- list(
    enabled = TRUE,
    seed = coupling_seed,
    modes = c("native_aligned", "origin_independent_permutation"),
    decision_contract = "paired_marginal_coupling_sensitivity_v1"
  )
  config$config$metrics$posterior_metric_intervals$dispersion_diagnostic <- list(
    enabled = TRUE,
    required = TRUE,
    recursion_counterfactual = TRUE,
    schema_version = imid_v1_schema
  )
  config$study_contract$dispersion_diagnostic <- list(
    primary_estimator_unchanged = TRUE,
    primary_recursion = "posterior_predictive",
    counterfactual_recursion = "conditional_mean_plugin",
    counterfactual_is_diagnostic_only = TRUE,
    case_specific_design_frozen = TRUE,
    no_hyperparameter_reselection = TRUE,
    no_article_promotion = TRUE
  )
  config_path <- file.path(state_root, "configs", paste0(job_id, ".json"))
  if (!identical(ffv2_file_sha256(config$source_request_path),
                 as.character(config$source_request_sha256)) ||
      !identical(ffv2_file_sha256(config$observed_path),
                 as.character(config$observed_sha256)) ||
      !identical(ffv2_file_sha256(config$source_series_path),
                 as.character(config$source_series_sha256))) {
    stop(sprintf("Rewritten source hash mismatch: %s", job_id), call. = FALSE)
  }
  ffv2_write_json(config, config_path)
  plan_rows[[i]] <- data.frame(
    job_id = job_id,
    engine = "qdesn",
    replay_id = as.character(authority$replay_id[[1L]]),
    source_identity = as.character(authority$replay_id[[1L]]),
    model_variant = as.character(authority$model_variant[[1L]]),
    family = as.character(authority$family[[1L]]),
    tau = as.numeric(authority$tau[[1L]]),
    inference = "mcmc",
    chain_id = as.integer(authority$chain_id[[1L]]),
    sentinel_role = as.character(authority$sentinel_role[[1L]]),
    config_path = normalizePath(config_path, winslash = "/", mustWork = TRUE),
    config_sha256 = ffv2_file_sha256(config_path),
    job_root = config$job_root,
    expected_draws = imid_v1_draws,
    cpu_id = cpu_ids[((i - 1L) %% length(cpu_ids)) + 1L],
    status = "PENDING",
    stringsAsFactors = FALSE
  )
}

plan <- do.call(rbind, plan_rows)
plan <- plan[order(plan$replay_id, plan$chain_id), , drop = FALSE]
plan_path <- ffv2_write_csv(plan, file.path(state_root, "manifests", "job_plan.csv"))
selection_copy <- ffv2_write_csv(selection,
                                 file.path(state_root, "manifests", "sentinel_sources.csv"))
manifest <- list(
  schema_version = imid_v1_schema,
  run_id = run_id,
  generated_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"),
  git_commit = system2("git", c("-C", repo_root, "rev-parse", "HEAD"), stdout = TRUE)[[1L]],
  source_run_id = imid_v1_production_run_id,
  source_repo = source_repo,
  source_repo_head = system2("git", c("-C", source_repo, "rev-parse", "HEAD"),
                             stdout = TRUE)[[1L]],
  selected_sources = length(unique(plan$replay_id)),
  planned_jobs = nrow(plan),
  cpu_ids = sort(unique(plan$cpu_id)),
  plan_path = plan_path,
  plan_sha256 = ffv2_file_sha256(plan_path),
  selection_sha256 = ffv2_file_sha256(selection_copy),
  fitted_model_binary_retention = FALSE,
  article_update_authorized = FALSE
)
ffv2_write_json(manifest, file.path(state_root, "manifests", "materialization_manifest.json"))
cat(sprintf("state_root=%s jobs=%d sources=%d cpus=%s\n", state_root, nrow(plan),
            length(unique(plan$replay_id)), paste(sort(unique(plan$cpu_id)), collapse = ",")))

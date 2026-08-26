#!/usr/bin/env Rscript

cmd_args0 <- commandArgs(FALSE)
file_arg <- grep("^--file=", cmd_args0, value = TRUE)
this_file <- if (length(file_arg)) sub("^--file=", "", file_arg[[1L]]) else
  "validation/fitforecast_v2/scripts/materialize_independent_origin_horizon_attribution_v1.R"
harness_root <- normalizePath(file.path(dirname(this_file), ".."), winslash = "/",
                              mustWork = TRUE)
source(file.path(harness_root, "R", "utils.R"))
ffv2_source_all(harness_root)

args <- ffv2_parse_args()
repo_root <- normalizePath(args$`repo-root` %||% ffv2_repo_root(), winslash = "/",
                           mustWork = TRUE)
source_repo <- normalizePath(args$`source-repo` %||% "", winslash = "/",
                             mustWork = TRUE)
source_run_id <- as.character(args$`source-run-id` %||% imoh_v1_source_run_id)[1L]
run_id <- as.character(args$`run-id` %||% "")[[1L]]
phase <- match.arg(as.character(args$phase %||% "pilot")[[1L]], c("pilot", "full"))
cpu_ids <- as.integer(strsplit(as.character(args$`cpu-list` %||% ""), ",",
                               fixed = TRUE)[[1L]])
if (!nzchar(run_id) || any(!is.finite(cpu_ids)) || !length(cpu_ids) ||
    anyDuplicated(cpu_ids)) {
  stop("--run-id and a unique numeric --cpu-list are required.", call. = FALSE)
}

source_state <- file.path(source_repo, "reports", "shared_fitforecast_v2_orchestration",
                          source_run_id)
state_root <- file.path(repo_root, "reports", "shared_fitforecast_v2_orchestration", run_id)
result_root <- file.path(repo_root, "results", "qdesn_mcmc_validation",
                         imoh_v1_stage, run_id)
if (!dir.exists(source_state) || dir.exists(state_root) || dir.exists(result_root)) {
  stop("Frozen source state must exist and new attribution roots must not exist.",
       call. = FALSE)
}

selection <- imoh_v1_read_selection(repo_root)
if (phase == "pilot") selection <- selection[selection$pilot_selected, , drop = FALSE]
source_plan <- ffv2_read_csv(file.path(source_state, "manifests", "job_plan.csv"))
selected <- source_plan[source_plan$replay_id %in% selection$replay_id, , drop = FALSE]
selected <- merge(selected, selection, by = c("replay_id", "model_variant", "family",
                                               "tau", "sentinel_role"),
                  all.x = TRUE, sort = FALSE, suffixes = c("", "_selected"))
expected_jobs <- nrow(selection) * 3L
if (nrow(selected) != expected_jobs || anyDuplicated(selected$job_id) ||
    any(table(selected$replay_id) != 3L)) {
  stop("Frozen source plan does not resolve the selected three-chain sources.",
       call. = FALSE)
}

ffv2_ensure_dir(state_root)
ffv2_ensure_dir(result_root)
source_input_root <- file.path(source_state, "sources")
if (!dir.exists(source_input_root) ||
    !isTRUE(file.copy(source_input_root, state_root, recursive = TRUE, copy.mode = TRUE))) {
  stop("Could not stage frozen source inputs.", call. = FALSE)
}

replacements <- setNames(c(repo_root, run_id), c(source_repo, source_run_id))
plan_rows <- vector("list", nrow(selected))
for (i in seq_len(nrow(selected))) {
  authority <- selected[i, , drop = FALSE]
  source_config_path <- normalizePath(authority$config_path[[1L]], winslash = "/",
                                      mustWork = TRUE)
  config <- imid_v1_recursive_replace(ffv2_read_json(source_config_path), replacements)
  if (!identical(as.character(config$source_candidate_id),
                 as.character(authority$source_candidate_id[[1L]]))) {
    stop(sprintf("Candidate identity mismatch: %s", authority$job_id[[1L]]),
         call. = FALSE)
  }
  config$schema_version <- imoh_v1_schema
  config$run_id <- run_id
  config$job_root <- file.path(result_root, "jobs", authority$job_id[[1L]])
  config$root_spec$root_id <- authority$job_id[[1L]]
  config$config$outputs$keep_draws <- TRUE
  config$config$outputs$retention_profile <- "storage_light"
  config$config$outputs$save_forecast_objects <- FALSE
  config$config$outputs$save_compact_fit_paths <- TRUE
  config$config$outputs$retain_full_rds_on_failure <- FALSE
  config$config$metrics$posterior_metric_intervals$origin_horizon_attribution <- list(
    enabled = TRUE,
    required = TRUE,
    balanced_complete_origins = TRUE,
    schema_version = imoh_v1_schema
  )
  config$study_contract$origin_horizon_attribution <- list(
    phase = phase,
    primary_metric_unchanged = TRUE,
    primary_recursion = "posterior_predictive",
    complete_target_scope = 1000L,
    balanced_sensitivity_scope = 990L,
    exact_group_reconstruction_tolerance = imoh_v1_reconstruction_tolerance,
    case_specific_design_frozen = TRUE,
    no_hyperparameter_reselection = TRUE,
    no_article_promotion = TRUE,
    no_automatic_tau0_launch = TRUE,
    full_forecast_draw_matrix_retention = FALSE
  )
  config_path <- file.path(state_root, "configs", paste0(authority$job_id[[1L]], ".json"))
  for (pair in list(
    c("source_request_path", "source_request_sha256"),
    c("observed_path", "observed_sha256"),
    c("source_series_path", "source_series_sha256")
  )) {
    if (!identical(ffv2_file_sha256(config[[pair[[1L]]]]),
                   as.character(config[[pair[[2L]]]]))) {
      stop(sprintf("Rewritten source hash mismatch: %s", authority$job_id[[1L]]),
           call. = FALSE)
    }
  }
  ffv2_write_json(config, config_path)
  plan_rows[[i]] <- data.frame(
    job_id = authority$job_id[[1L]], engine = "qdesn",
    replay_id = authority$replay_id[[1L]], source_identity = authority$source_identity[[1L]],
    model_variant = authority$model_variant[[1L]], family = authority$family[[1L]],
    tau = authority$tau[[1L]], inference = "mcmc",
    chain_id = as.integer(authority$chain_id[[1L]]),
    sentinel_role = authority$sentinel_role[[1L]], campaign_phase = phase,
    config_path = normalizePath(config_path, winslash = "/", mustWork = TRUE),
    config_sha256 = ffv2_file_sha256(config_path), job_root = config$job_root,
    expected_draws = imoh_v1_draws,
    cpu_id = cpu_ids[((i - 1L) %% length(cpu_ids)) + 1L], status = "PENDING",
    stringsAsFactors = FALSE
  )
}

plan <- do.call(rbind, plan_rows)
plan <- plan[order(plan$replay_id, plan$chain_id), , drop = FALSE]
plan_path <- ffv2_write_csv(plan, file.path(state_root, "manifests", "job_plan.csv"))
selection_path <- ffv2_write_csv(selection,
                                 file.path(state_root, "manifests", "sentinel_sources.csv"))
protocol <- data.frame(
  scope = c("authoritative_all_targets", "balanced_complete_origins"),
  target_start = 9001L, target_end = c(10000L, 9990L),
  target_count = c(1000L, 990L), origin_count = c(34L, 33L),
  origin_stride = 30L, maximum_lead = 30L,
  truncated_origin_included = c(TRUE, FALSE),
  scientific_role = c("article_metric_identity", "diagnostic_sensitivity_only"),
  stringsAsFactors = FALSE
)
protocol_path <- ffv2_write_csv(
  protocol, file.path(state_root, "manifests", "evaluation_protocol.csv")
)
manifest <- list(
  schema_version = imoh_v1_schema, run_id = run_id, phase = phase,
  generated_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"),
  git_commit = system2("git", c("-C", repo_root, "rev-parse", "HEAD"), stdout = TRUE)[[1L]],
  source_run_id = source_run_id, source_repo = source_repo,
  source_repo_head = system2("git", c("-C", source_repo, "rev-parse", "HEAD"),
                             stdout = TRUE)[[1L]],
  selected_sources = length(unique(plan$replay_id)), planned_jobs = nrow(plan),
  cpu_ids = sort(unique(plan$cpu_id)), plan_path = plan_path,
  plan_sha256 = ffv2_file_sha256(plan_path),
  selection_sha256 = ffv2_file_sha256(selection_path),
  protocol_sha256 = ffv2_file_sha256(protocol_path),
  fitted_model_binary_retention = FALSE, article_update_authorized = FALSE,
  tau0_launch_authorized = FALSE
)
ffv2_write_json(manifest, file.path(state_root, "manifests", "materialization_manifest.json"))
cat(sprintf("state_root=%s phase=%s jobs=%d sources=%d cpus=%s\n", state_root, phase,
            nrow(plan), length(unique(plan$replay_id)),
            paste(sort(unique(plan$cpu_id)), collapse = ",")))

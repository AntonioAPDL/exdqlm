#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  required <- c("jsonlite", "coda")
  missing <- required[!vapply(required, requireNamespace, logical(1L), quietly = TRUE)]
  if (length(missing)) stop(sprintf("Missing packages: %s", paste(missing, collapse = ", ")))
})

args <- commandArgs(trailingOnly = TRUE)
get_arg <- function(flag, default = NULL) {
  index <- which(args == flag)
  if (!length(index) || index[[1L]] >= length(args)) return(default)
  args[[index[[1L]] + 1L]]
}

repo_root <- normalizePath(
  system("git rev-parse --show-toplevel", intern = TRUE),
  winslash = "/", mustWork = TRUE
)
setwd(repo_root)
source(file.path(
  repo_root, "validation", "fitforecast_v2", "R",
  "independent_exal_m0_relaunch_v1.R"
))

budget <- tolower(as.character(get_arg("--budget", "static"))[1L])
run_tag <- as.character(get_arg("--run-tag", ""))[1L]
output_arg <- get_arg("--output", file.path(
  "reports", "shared_fitforecast_v2_orchestration",
  "independent_exal_m0_relaunch_v1_verification.json"
))
output_path <- if (grepl("^/", output_arg)) output_arg else file.path(repo_root, output_arg)
dir.create(dirname(output_path), recursive = TRUE, showWarnings = FALSE)

stub <- qdesn_m0v1_config_stub(repo_root)
authority_path <- qdesn_m0v1_authority_path(repo_root)
anchors <- qdesn_m0v1_read_csv(paste0(stub, "_anchor_registry.csv"))
metrics <- qdesn_m0v1_read_csv(paste0(stub, "_metric_contract.csv"))
plan <- qdesn_m0v1_read_csv(paste0(stub, "_chain_plan.csv"))
manifest <- qdesn_m0v1_read_csv(paste0(stub, "_file_manifest.csv"))
materialization <- qdesn_m0v1_read_json(paste0(stub, "_materialization_manifest.json"))

resolve_repo_path <- function(path) {
  if (grepl("^/", path)) path else file.path(repo_root, path)
}
bool <- function(x) isTRUE(x) || identical(x, TRUE)

manifest_audit <- do.call(rbind, lapply(seq_len(nrow(manifest)), function(i) {
  path <- resolve_repo_path(manifest$path[[i]])
  data.frame(
    path = manifest$path[[i]],
    exists = file.exists(path),
    expected_sha256 = manifest$sha256[[i]],
    observed_sha256 = qdesn_m0v1_sha256(path),
    hash_match = identical(qdesn_m0v1_sha256(path), manifest$sha256[[i]]),
    stringsAsFactors = FALSE
  )
}))

config_audit <- do.call(rbind, lapply(seq_len(nrow(plan)), function(i) {
  config_path <- resolve_repo_path(plan$config_path[[i]])
  observed_path <- resolve_repo_path(plan$observed_path[[i]])
  source_request_path <- resolve_repo_path(plan$source_request_path[[i]])
  job <- qdesn_m0v1_read_json(config_path)
  source_request <- qdesn_m0v1_read_json(source_request_path)
  cfg <- job$config
  same_frozen_model <- identical(cfg$desn, source_request$config$desn) &&
    identical(cfg$split, source_request$config$split) &&
    identical(cfg$columns, source_request$config$columns) &&
    identical(cfg$lags, source_request$config$lags) &&
    identical(cfg$preproc, source_request$config$preproc) &&
    identical(cfg$readout, source_request$config$readout) &&
    identical(cfg$forecast, source_request$config$forecast) &&
    identical(cfg$inference$mcmc$priors, source_request$config$inference$mcmc$priors)
  data.frame(
    job_id = plan$job_id[[i]],
    budget = plan$budget[[i]],
    config_hash_match = identical(qdesn_m0v1_sha256(config_path),
                                  plan$config_sha256[[i]]),
    observed_hash_match = identical(qdesn_m0v1_sha256(observed_path),
                                    plan$observed_sha256[[i]]),
    source_request_hash_match = identical(qdesn_m0v1_sha256(source_request_path),
                                          plan$source_request_sha256[[i]]),
    candidate_match = identical(as.character(job$candidate_id),
                                 as.character(plan$candidate_id[[i]])),
    source_registry_match = identical(
      as.character(job$source_registry_hash_value), qdesn_m0v1_registry_hash
    ),
    model_data_prior_frozen = same_frozen_model,
    exal_mcmc_only = identical(tolower(as.character(cfg$inference$method)), "mcmc") &&
      identical(tolower(as.character(cfg$inference$likelihood_family)), "exal"),
    m0_mode = identical(as.character(cfg$inference$mcmc$slice$core_update_mode),
                        qdesn_m0v1_method_id),
    m0_width = identical(as.numeric(cfg$inference$mcmc$slice$width_gamma), 4),
    one_core_pass = identical(as.integer(cfg$inference$mcmc$slice$core_extra_passes), 0L),
    budget_match = identical(as.integer(cfg$inference$mcmc$n_burn),
                             as.integer(plan$n_burn[[i]])) &&
      identical(as.integer(cfg$inference$mcmc$n_mcmc),
                as.integer(plan$n_mcmc[[i]])) &&
      identical(as.integer(cfg$inference$mcmc$thin),
                as.integer(plan$thin[[i]])),
    storage_light = !isTRUE(cfg$outputs$keep_draws) &&
      !isTRUE(cfg$outputs$save_forecast_objects) &&
      !isTRUE(cfg$outputs$retain_full_rds_on_failure) &&
      isTRUE(cfg$outputs$save_compact_fit_paths),
    threads_one = identical(as.integer(cfg$cpp$postpred_threads), 1L),
    stringsAsFactors = FALSE
  )
}))

static_pass <- identical(qdesn_m0v1_sha256(authority_path),
                         qdesn_m0v1_authority_sha256) &&
  nrow(anchors) == 15L && nrow(metrics) == 27L && nrow(plan) == 60L &&
  sum(plan$budget == "smoke") == 6L &&
  sum(plan$budget == "canary") == 9L &&
  sum(plan$budget == "full") == 45L &&
  identical(as.character(materialization$method_id),
            "M0_v_collapsed_support_logit") &&
  all(manifest_audit$exists & manifest_audit$hash_match) &&
  all(vapply(config_audit[, setdiff(names(config_audit), c("job_id", "budget")), drop = FALSE],
             function(x) all(x %in% TRUE), logical(1L)))

audit_dir <- dirname(output_path)
qdesn_m0v1_write_csv(manifest_audit, file.path(audit_dir, "manifest_hash_audit.csv"))
qdesn_m0v1_write_csv(config_audit, file.path(audit_dir, "resolved_config_audit.csv"))

run_pass <- TRUE
runtime_summary <- NULL
diagnostic_rows <- data.frame(stringsAsFactors = FALSE)
if (budget %in% c("smoke", "canary", "full")) {
  if (!nzchar(run_tag)) stop("--run-tag is required for runtime verification.", call. = FALSE)
  budget_plan <- plan[plan$budget == budget, , drop = FALSE]
  runtime <- qdesn_m0v1_scan_jobs(repo_root, run_tag, budget_plan)
  metric_ok <- logical(nrow(runtime))
  method_ok <- logical(nrow(runtime))
  rolling_path_ok <- logical(nrow(runtime))
  lead_metrics_ok <- logical(nrow(runtime))
  retention_ok <- logical(nrow(runtime))
  binary_count <- integer(nrow(runtime))
  for (i in seq_len(nrow(runtime))) {
    job_root <- qdesn_m0v1_job_root(repo_root, run_tag, runtime$job_id[[i]])
    fit_path <- file.path(job_root, "fit_summary_row.csv")
    horizon_path <- file.path(job_root, "tables", "forecast_horizon_summary.csv")
    rolling_path <- file.path(job_root, "tables", "forecast_rolling_origin_paths.csv")
    lead_metrics_path <- file.path(job_root, "tables", "forecast_lead_metrics.csv")
    retention_path <- file.path(job_root, "manifest", "output_retention.json")
    request_path <- file.path(job_root, "fit_request.json")
    fit <- tryCatch(qdesn_m0v1_read_csv(fit_path), error = function(e) data.frame())
    horizon <- tryCatch(qdesn_m0v1_read_csv(horizon_path), error = function(e) data.frame())
    rolling <- tryCatch(qdesn_m0v1_read_csv(rolling_path), error = function(e) data.frame())
    lead_metrics <- tryCatch(qdesn_m0v1_read_csv(lead_metrics_path), error = function(e) data.frame())
    retention <- tryCatch(qdesn_m0v1_read_json(retention_path), error = function(e) NULL)
    request <- tryCatch(qdesn_m0v1_read_json(request_path), error = function(e) NULL)
    idx <- if (nrow(horizon)) which(
      suppressWarnings(as.integer(horizon$horizon)) == 1000L |
        as.character(horizon$window) == "forecast_H1000"
    ) else integer()
    metric_ok[[i]] <- nrow(fit) > 0L && length(idx) > 0L &&
      is.finite(as.numeric(fit$train_qtrue_rmse[[1L]])) &&
      is.finite(as.numeric(horizon$qtrue_mae[[idx[[1L]]]])) &&
      is.finite(as.numeric(horizon$pinball_tau[[idx[[1L]]]]))
    method_ok[[i]] <- !is.null(request) && identical(
      as.character(request$config$inference$mcmc$slice$core_update_mode),
      qdesn_m0v1_method_id
    )
    rolling_path_ok[[i]] <- nrow(rolling) == 1000L &&
      identical(sort(unique(as.integer(rolling$forecast_lead))), 1:30) &&
      all(as.integer(rolling$target_source_index) >= 9001L) &&
      all(as.integer(rolling$target_source_index) <= 10000L) &&
      all(is.finite(as.numeric(rolling$qhat)))
    lead_metrics_ok[[i]] <- nrow(lead_metrics) == 30L &&
      identical(sort(unique(as.integer(lead_metrics$forecast_lead))), 1:30) &&
      all(is.finite(as.numeric(lead_metrics$forecast_qtrue_mae))) &&
      all(is.finite(as.numeric(lead_metrics$forecast_pinball_mean)))
    retention_ok[[i]] <- !is.null(retention) &&
      identical(as.character(retention$forecast_rolling_origin_status), "PASS") &&
      identical(as.integer(retention$forecast_rolling_origin_rows), 1000L) &&
      identical(as.integer(retention$forecast_lead_metrics_rows), 30L) &&
      isTRUE(retention$rolling_origin_ready_for_pruning) &&
      !isTRUE(retention$forecast_objects_exists_after)
    binary_count[[i]] <- length(list.files(
      job_root, pattern = "[.](rds|rda|RData)$", recursive = TRUE,
      full.names = TRUE, ignore.case = TRUE
    ))
  }
  runtime$finite_metrics <- metric_ok
  runtime$m0_method_verified <- method_ok
  runtime$rolling_path_verified <- rolling_path_ok
  runtime$lead_metrics_verified <- lead_metrics_ok
  runtime$retention_verified <- retention_ok
  runtime$binary_payloads <- binary_count
  qdesn_m0v1_write_csv(runtime, file.path(audit_dir, paste0(budget, "_runtime_audit.csv")))
  run_pass <- nrow(runtime) == nrow(budget_plan) &&
    all(runtime$status == "SUCCESS") && all(metric_ok) && all(method_ok) &&
    all(rolling_path_ok) && all(lead_metrics_ok) && all(retention_ok) &&
    all(binary_count == 0L)

  if (budget %in% c("canary", "full")) {
    diagnostic_list <- list()
    d <- 0L
    for (anchor_id in unique(budget_plan$anchor_id)) {
      anchor_plan <- budget_plan[budget_plan$anchor_id == anchor_id, , drop = FALSE]
      traces <- lapply(anchor_plan$job_id, function(job_id) {
        qdesn_m0v1_read_csv(file.path(
          qdesn_m0v1_job_root(repo_root, run_tag, job_id), "progress_trace.csv"
        ))
      })
      for (parameter in c("gamma", "sigma")) {
        chains <- lapply(traces, function(x) as.numeric(x[[parameter]]))
        d <- d + 1L
        diagnostic_list[[d]] <- data.frame(
          anchor_id = anchor_id,
          parameter = parameter,
          chains = length(chains),
          draws_per_chain = min(vapply(chains, length, integer(1L))),
          rank_split_rhat = qdesn_m0v1_rank_split_rhat(chains),
          folded_rank_split_rhat = qdesn_m0v1_rank_split_rhat(chains, folded = TRUE),
          bulk_ess = qdesn_m0v1_effective_size(chains),
          tail_ess = qdesn_m0v1_tail_effective_size(chains),
          stringsAsFactors = FALSE
        )
      }
    }
    diagnostic_rows <- do.call(rbind, diagnostic_list)
    diagnostic_rows$max_rhat <- pmax(
      diagnostic_rows$rank_split_rhat,
      diagnostic_rows$folded_rank_split_rhat,
      na.rm = TRUE
    )
    diagnostic_rows$canary_gate_pass <- with(
      diagnostic_rows,
      is.finite(max_rhat) & max_rhat <= 1.25 &
        is.finite(bulk_ess) & bulk_ess >= 50 &
        is.finite(tail_ess) & tail_ess >= 25
    )
    qdesn_m0v1_write_csv(
      diagnostic_rows, file.path(audit_dir, paste0(budget, "_chain_diagnostics.csv"))
    )
    if (identical(budget, "canary")) {
      run_pass <- run_pass && all(diagnostic_rows$canary_gate_pass %in% TRUE)
    }
  }
  runtime_summary <- list(
    expected_jobs = nrow(budget_plan),
    successful_jobs = sum(runtime$status == "SUCCESS"),
    failed_jobs = sum(runtime$status == "FAIL"),
    running_jobs = sum(runtime$status == "RUNNING"),
    planned_jobs = sum(runtime$status == "PLANNED"),
    finite_metric_jobs = sum(metric_ok),
    rolling_path_jobs = sum(rolling_path_ok),
    lead_metric_jobs = sum(lead_metrics_ok),
    retention_verified_jobs = sum(retention_ok),
    binary_payloads = sum(binary_count)
  )
}

decision <- if (static_pass && run_pass) "PASS" else "FAIL"
qdesn_m0v1_write_json(list(
  generated_at = as.character(Sys.time()),
  stage = qdesn_m0v1_stage,
  budget = budget,
  run_tag = if (nzchar(run_tag)) run_tag else NULL,
  static_contract_pass = static_pass,
  runtime_contract_pass = run_pass,
  runtime = runtime_summary,
  diagnostic_rows = nrow(diagnostic_rows),
  diagnostic_status_used_as_metric_filter = FALSE,
  decision = decision
), output_path)

cat(sprintf("verification budget=%s decision=%s\n", budget, decision))
if (!identical(decision, "PASS")) {
  stop("Independent exAL M0 relaunch verification failed.", call. = FALSE)
}

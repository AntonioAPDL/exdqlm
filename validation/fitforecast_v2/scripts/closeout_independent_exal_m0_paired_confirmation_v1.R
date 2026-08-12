#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  if (!requireNamespace("jsonlite", quietly = TRUE)) {
    stop("jsonlite is required.", call. = FALSE)
  }
})

args <- commandArgs(trailingOnly = TRUE)
get_arg <- function(flag, default = NULL) {
  i <- which(args == flag)
  if (!length(i) || i[[1L]] >= length(args)) return(default)
  args[[i[[1L]] + 1L]]
}
repo_root <- normalizePath(get_arg(
  "--repo-root", system("git rev-parse --show-toplevel", intern = TRUE)
), winslash = "/", mustWork = TRUE)
setwd(repo_root)
source(file.path(repo_root, "validation", "fitforecast_v2", "R",
                 "independent_exal_m0_structural_screen_v2.R"))

materialization_root <- normalizePath(get_arg("--materialization-root"),
                                      winslash = "/", mustWork = TRUE)
output_root <- normalizePath(get_arg("--output-root"), winslash = "/",
                             mustWork = FALSE)
run_tag <- as.character(get_arg("--run-tag", ""))[1L]
if (!nzchar(run_tag)) stop("--run-tag is required.", call. = FALSE)
dir.create(output_root, recursive = TRUE, showWarnings = FALSE)

run_env_path <- normalizePath(
  get_arg("--run-env", file.path(dirname(output_root), "run.env")),
  winslash = "/", mustWork = TRUE
)
run_env_lines <- readLines(run_env_path, warn = FALSE)
run_env <- setNames(
  sub("^[^=]+=(.*)$", "\\1", run_env_lines),
  sub("^([^=]+)=.*$", "\\1", run_env_lines)
)
required_run_env <- c("RUN_ID", "RUN_TAG", "GIT_COMMIT")
if (!all(required_run_env %in% names(run_env)) ||
    !identical(unname(run_env[["RUN_TAG"]]), run_tag) ||
    !grepl("^[0-9a-f]{40}$", unname(run_env[["GIT_COMMIT"]]))) {
  stop("The immutable execution identity in run.env is missing or malformed.",
       call. = FALSE)
}
execution_commit <- unname(run_env[["GIT_COMMIT"]])
closeout_commit <- system("git rev-parse HEAD", intern = TRUE)

plan_path <- file.path(materialization_root, "confirmation_plan.csv")
materialization_manifest_path <- file.path(materialization_root,
                                           "materialization_manifest.json")
plan <- qdesn_ssv2_read_csv(plan_path)
materialization_manifest <- qdesn_ssv2_read_json(materialization_manifest_path)
contract <- qdesn_ssv2_read_json(materialization_manifest$contract$path)
handoff_root <- dirname(materialization_manifest$sealed_handoff$manifest_path)
baseline_path <- file.path(handoff_root, "article_metric_baseline.csv")
baseline <- qdesn_ssv2_read_csv(baseline_path)
metrics <- as.character(contract$promotion_contract$metrics)
if (nrow(plan) != 6L || nrow(baseline) != 6L ||
    !identical(sort(unique(plan$target_cell_id)),
               sort(unique(baseline$target_cell_id)))) {
  stop("Confirmation plan and frozen article baseline are not aligned.", call. = FALSE)
}

chain_rows <- list()
k <- 0L
for (i in seq_len(nrow(plan))) {
  root <- qdesn_ssv2_job_root(repo_root, run_tag, plan$job_id[[i]])
  status_path <- file.path(root, "job_status.json")
  status <- if (file.exists(status_path)) qdesn_ssv2_read_json(status_path) else
    list(status = "MISSING")
  fit_request_path <- file.path(root, "fit_request.json")
  fit_request <- if (file.exists(fit_request_path)) {
    qdesn_ssv2_read_json(fit_request_path)
  } else list()
  job_started_path <- file.path(root, "job_started.json")
  job_started <- if (file.exists(job_started_path)) {
    qdesn_ssv2_read_json(job_started_path)
  } else list()
  request_execution_commit <- as.character(
    fit_request$execution$launch_commit %||% ""
  )[1L]
  started_execution_commit <- as.character(job_started$git_commit %||% "")[1L]
  if (!identical(request_execution_commit, execution_commit) ||
      !identical(started_execution_commit, execution_commit)) {
    stop(sprintf("Execution commit mismatch for %s.", plan$job_id[[i]]),
         call. = FALSE)
  }
  signoff_path <- file.path(root, "signoff_summary.csv")
  signoff <- if (file.exists(signoff_path)) qdesn_ssv2_read_csv(signoff_path) else
    data.frame()
  signoff_fields <- intersect(c("signoff_grade", "status", "decision"), names(signoff))
  signoff_grade <- if (length(signoff_fields) && nrow(signoff)) {
    as.character(signoff[[signoff_fields[[1L]]]][[1L]])
  } else NA_character_
  rolling_audit <- qdesn_ssv2_rolling_artifact_audit(root)
  binary_paths <- list.files(
    root, pattern = "[.](rds|rda|RData)$", recursive = TRUE,
    full.names = TRUE, ignore.case = TRUE
  )
  for (metric in metrics) {
    source_path <- if (metric == "fit_qtrue_rmse") {
      file.path(root, "fit_summary_row.csv")
    } else {
      file.path(root, "tables", "forecast_rolling_origin_paths.csv")
    }
    k <- k + 1L
    chain_rows[[k]] <- data.frame(
      run_tag = run_tag, job_id = plan$job_id[[i]],
      target_cell_id = plan$target_cell_id[[i]], family = plan$family[[i]],
      tau = plan$tau[[i]], candidate_id = plan$candidate_id[[i]],
      chain_id = plan$chain_id[[i]], reservoir_seed = plan$reservoir_seed[[i]],
      mcmc_seed = plan$mcmc_seed[[i]], metric = metric,
      metric_value = qdesn_ssv2_metric_value(
        root, metric, require_rolling = grepl("^forecast_", metric)
      ),
      status = as.character(status$status %||% "MISSING"),
      signoff_grade = signoff_grade,
      rolling_artifact_status = rolling_audit$decision,
      elapsed_seconds = as.numeric(status$elapsed_seconds %||% NA_real_),
      source_path = normalizePath(source_path, winslash = "/", mustWork = FALSE),
      source_sha256 = qdesn_ssv2_sha256(source_path),
      config_path = plan$config_path[[i]],
      config_sha256 = plan$config_sha256[[i]],
      execution_commit = request_execution_commit,
      binary_payloads = length(binary_paths),
      stringsAsFactors = FALSE
    )
  }
}
chains <- do.call(rbind, chain_rows)
chain_path <- qdesn_ssv2_write_csv(
  chains, file.path(output_root, "confirmation_chain_metric_evidence.csv")
)

group_key <- interaction(chains$target_cell_id, chains$candidate_id, chains$metric,
                         drop = TRUE, lex.order = TRUE)
metric_summaries <- lapply(split(chains, group_key), function(x) {
  baseline_row <- baseline[
    baseline$target_cell_id == x$target_cell_id[[1L]] &
      baseline$metric == x$metric[[1L]], , drop = FALSE
  ]
  if (nrow(baseline_row) != 1L) {
    stop(sprintf("Missing article baseline for %s/%s.",
                 x$target_cell_id[[1L]], x$metric[[1L]]), call. = FALSE)
  }
  values <- x$metric_value
  current <- as.numeric(baseline_row$current_article_value[[1L]])
  mean_value <- mean(values)
  median_value <- stats::median(values)
  successful <- sum(x$status == "SUCCESS")
  finite <- sum(is.finite(values))
  artifact_pass <- if (grepl("^forecast_", x$metric[[1L]])) {
    all(x$rolling_artifact_status == "PASS")
  } else TRUE
  eligible <- nrow(x) == 3L && successful == 3L && finite == 3L &&
    all(x$binary_payloads == 0L) && artifact_pass &&
    mean_value < current && median_value < current
  data.frame(
    target_cell_id = x$target_cell_id[[1L]], family = x$family[[1L]],
    tau = x$tau[[1L]], candidate_id = x$candidate_id[[1L]],
    metric = x$metric[[1L]], chains = nrow(x), successful_chains = successful,
    finite_chains = finite, chain_mean = mean_value,
    chain_median = median_value, chain_sd = stats::sd(values),
    chain_min = min(values), chain_max = max(values),
    current_article_value = current,
    absolute_gain = current - mean_value,
    relative_gain_pct = 100 * (current - mean_value) / current,
    chains_improving_current = sum(values < current),
    rolling_artifact_pass = artifact_pass,
    binary_payloads = sum(x$binary_payloads),
    diagnostic_grades = paste(sort(unique(na.omit(x$signoff_grade))), collapse = ";"),
    mean_below_current = mean_value < current,
    median_below_current = median_value < current,
    manual_metric_promotion_eligible = eligible,
    decision = if (eligible) "PROMOTION_READY_MANUAL_REVIEW" else
      "RETAIN_CURRENT_ARTICLE_METRIC",
    article_promotion_automatic = FALSE,
    stringsAsFactors = FALSE
  )
})
metric_summary <- do.call(rbind, metric_summaries)
metric_summary <- metric_summary[order(
  metric_summary$family, metric_summary$tau, match(metric_summary$metric, metrics)
), , drop = FALSE]
metric_summary_path <- qdesn_ssv2_write_csv(
  metric_summary, file.path(output_root, "confirmation_metric_summary.csv")
)

patch_rows <- baseline
patch_rows$confirmation_candidate_id <- NA_character_
patch_rows$confirmation_run_tag <- NA_character_
patch_rows$confirmation_chain_mean <- NA_real_
patch_rows$confirmation_chain_median <- NA_real_
patch_rows$confirmation_relative_gain_pct <- NA_real_
patch_rows$proposed_article_value <- patch_rows$current_article_value
patch_rows$promotion_decision <- "RETAIN_CURRENT_ARTICLE_METRIC"
for (i in seq_len(nrow(patch_rows))) {
  result <- metric_summary[
    metric_summary$target_cell_id == patch_rows$target_cell_id[[i]] &
      metric_summary$metric == patch_rows$metric[[i]], , drop = FALSE
  ]
  patch_rows$confirmation_candidate_id[[i]] <- result$candidate_id[[1L]]
  patch_rows$confirmation_run_tag[[i]] <- run_tag
  patch_rows$confirmation_chain_mean[[i]] <- result$chain_mean[[1L]]
  patch_rows$confirmation_chain_median[[i]] <- result$chain_median[[1L]]
  patch_rows$confirmation_relative_gain_pct[[i]] <- result$relative_gain_pct[[1L]]
  if (isTRUE(result$manual_metric_promotion_eligible[[1L]])) {
    patch_rows$proposed_article_value[[i]] <- result$chain_mean[[1L]]
    patch_rows$promotion_decision[[i]] <- "PROMOTION_READY_MANUAL_REVIEW"
  }
}
patch_path <- qdesn_ssv2_write_csv(
  patch_rows, file.path(output_root, "article_metric_patch_review.csv")
)

cell_summary <- do.call(rbind, lapply(
  split(metric_summary, metric_summary$target_cell_id), function(x) {
    data.frame(
      target_cell_id = x$target_cell_id[[1L]], family = x$family[[1L]],
      tau = x$tau[[1L]], candidate_id = x$candidate_id[[1L]],
      metrics_evaluated = nrow(x),
      metrics_promotion_ready = sum(x$manual_metric_promotion_eligible),
      promotion_ready_metrics = paste(
        x$metric[x$manual_metric_promotion_eligible], collapse = ";"
      ),
      decision = if (any(x$manual_metric_promotion_eligible)) {
        "AT_LEAST_ONE_METRIC_READY_FOR_MANUAL_PROMOTION"
      } else "NO_CONFIRMED_METRIC_GAIN",
      stringsAsFactors = FALSE
    )
  }
))
cell_summary_path <- qdesn_ssv2_write_csv(
  cell_summary, file.path(output_root, "confirmation_cell_summary.csv")
)

outputs <- c(
  chain_metric_evidence = chain_path,
  metric_summary = metric_summary_path,
  article_metric_patch_review = patch_path,
  cell_summary = cell_summary_path
)
manifest_path <- qdesn_ssv2_write_json(list(
  generated_at = as.character(Sys.time()), run_tag = run_tag,
  decision = if (any(metric_summary$manual_metric_promotion_eligible)) {
    "CONFIRMATION_COMPLETE_METRIC_PROMOTION_REVIEW_REQUIRED"
  } else "CONFIRMATION_COMPLETE_RETAIN_CURRENT_ARTICLE_METRICS",
  package_version = "1.0.0", method_id = "M0_v_collapsed_support_logit",
  validation_branch = system("git branch --show-current", intern = TRUE),
  validation_commit = execution_commit,
  execution_commit = execution_commit,
  closeout_commit = closeout_commit,
  execution_identity_source = "run.env_six_job_started_and_six_fit_requests",
  all_job_execution_commits_match = all(chains$execution_commit == execution_commit),
  source_registry_hash_value = qdesn_ssv2_registry_hash,
  jobs = nrow(plan), chains = length(unique(chains$job_id)),
  chain_metric_rows = nrow(chains), metric_cells = nrow(metric_summary),
  promotion_ready_metric_cells = sum(metric_summary$manual_metric_promotion_eligible),
  promotion_ready_metrics = as.list(paste0(
    metric_summary$target_cell_id[metric_summary$manual_metric_promotion_eligible],
    "/",
    metric_summary$metric[metric_summary$manual_metric_promotion_eligible]
  )),
  promotion_contract = contract$promotion_contract,
  diagnostic_policy = "reported_but_not_used_as_metric_veto",
  article_update_automatic = FALSE,
  article_update_performed = FALSE,
  storage = list(
    routine_binary_payloads = sum(chains$binary_payloads[!duplicated(chains$job_id)]),
    policy = contract$storage_policy
  ),
  evidence = list(
    confirmation_plan = list(path = plan_path, sha256 = qdesn_ssv2_sha256(plan_path)),
    materialization_manifest = list(
      path = materialization_manifest_path,
      sha256 = qdesn_ssv2_sha256(materialization_manifest_path)
    ),
    run_env = list(path = run_env_path, sha256 = qdesn_ssv2_sha256(run_env_path)),
    sealed_handoff_manifest = materialization_manifest$sealed_handoff,
    article_metric_baseline = list(path = baseline_path,
                                   sha256 = qdesn_ssv2_sha256(baseline_path))
  ),
  outputs = lapply(outputs, function(path) {
    list(path = path, sha256 = qdesn_ssv2_sha256(path))
  }),
  next_gate = "manual_scientific_review_before_article_promotion"
), file.path(output_root, "paired_confirmation_closeout_manifest.json"))

cat(sprintf(
  paste0("confirmation_jobs=%d metric_cells=%d promotion_ready=%d ",
         "article_unchanged=TRUE manifest=%s\n"),
  nrow(plan), nrow(metric_summary),
  sum(metric_summary$manual_metric_promotion_eligible), manifest_path
))

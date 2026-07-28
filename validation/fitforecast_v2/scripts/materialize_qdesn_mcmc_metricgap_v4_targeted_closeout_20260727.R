#!/usr/bin/env Rscript

options(stringsAsFactors = FALSE)

script_arg <- grep("^--file=", commandArgs(FALSE), value = TRUE)[1L]
script_path <- if (!is.na(script_arg)) {
  normalizePath(sub("^--file=", "", script_arg), winslash = "/", mustWork = TRUE)
} else {
  normalizePath(file.path(
    "validation", "fitforecast_v2", "scripts",
    "materialize_qdesn_mcmc_metricgap_v4_targeted_closeout_20260727.R"
  ), winslash = "/", mustWork = TRUE)
}
repo_root <- normalizePath(
  file.path(dirname(script_path), "..", "..", ".."),
  winslash = "/",
  mustWork = TRUE
)

read_csv <- function(path) {
  if (!file.exists(path)) stop(sprintf("Missing input: %s", path), call. = FALSE)
  utils::read.csv(path, check.names = FALSE, stringsAsFactors = FALSE)
}
write_csv <- function(value, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(value, path, row.names = FALSE, na = "")
  normalizePath(path, winslash = "/", mustWork = TRUE)
}
write_json <- function(value, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  jsonlite::write_json(value, path, pretty = TRUE, auto_unbox = TRUE, null = "null", digits = NA)
  normalizePath(path, winslash = "/", mustWork = TRUE)
}
sha256 <- function(path) unname(tools::sha256sum(path)[[1L]])
num <- function(x) suppressWarnings(as.numeric(x))
as_bool <- function(x) {
  if (is.logical(x)) return(x)
  toupper(trimws(as.character(x))) %in% c("TRUE", "T", "1", "YES")
}
git_value <- function(args) {
  value <- system2("git", c("-C", repo_root, args), stdout = TRUE)
  if (!length(value)) NA_character_ else value[[1L]]
}
cell_key <- function(model_variant, family, tau, fit_size = 500L) {
  paste(model_variant, family, sprintf("%.8f", num(tau)), as.integer(fit_size), sep = "\r")
}
metric_label <- function(metric) {
  switch(
    metric,
    fit_qtrue_rmse = "fit",
    forecast_qtrue_mae_H1000 = "forecast_mae",
    forecast_check_loss_H1000 = "forecast_check",
    stop(sprintf("Unknown metric: %s", metric), call. = FALSE)
  )
}

date_stamp <- "20260727"
promotion_id <- paste0("qdesn_tt500_mcmc_metricgap_v4_targeted_closeout_", date_stamp)
parent_id <- "qdesn_dqlm_500obs_mcmc_metric_envelope_20260727"
stage <- "qdesn_dynamic_fitforecast_v2_tt500_mcmc_metricgap_v4_targeted"
run_tag <- "qdesn-tt500-mcmc-metricgap-v4-targeted-full-20260727__git-4f42747"
stamp <- "20260727-145445__git-4f42747"
source_hash_expected <- "edddb56fc2b30e49ac99fdd08b53dad468ed53e05d0fe1fe16426ee9d9ffe275"

promotion_root <- file.path(repo_root, "validation", "fitforecast_v2", "promotions", promotion_id)
parent_root <- file.path(repo_root, "validation", "fitforecast_v2", "promotions", parent_id)
report_root <- file.path(repo_root, "reports", "qdesn_mcmc_validation", stage, run_tag, stamp)
results_root <- file.path(repo_root, "results", "qdesn_mcmc_validation", stage, run_tag, stamp)
roots_root <- file.path(results_root, "roots")

target_specs_path <- file.path(repo_root, "config", "validation", paste0(stage, "_target_spec_ids.csv"))
materialization_manifest_path <- file.path(
  repo_root, "config", "validation", paste0(stage, "_materialization_manifest.json")
)
parent_all_path <- file.path(parent_root, paste0(parent_id, "_all_candidates.csv"))
parent_envelope_path <- file.path(parent_root, paste0(parent_id, "_article_envelope.csv"))
parent_handoff_path <- file.path(parent_root, paste0(parent_id, "_targeted_screening_handoff.csv"))
parent_manifest_path <- file.path(parent_root, paste0(parent_id, "_manifest.json"))
campaign_completed_path <- file.path(report_root, "manifest", "campaign_completed.json")
campaign_summary_path <- file.path(report_root, "summary", "qdesn_dynamic_crossstudy_summary.md")
campaign_progress_path <- file.path(report_root, "tables", "campaign_progress.csv")
campaign_root_status_mix_path <- file.path(report_root, "tables", "campaign_root_status_mix.csv")
campaign_fit_summary_path <- file.path(report_root, "tables", "campaign_fit_summary.csv")

description <- read.dcf(file.path(repo_root, "DESCRIPTION"))
if (!identical(as.character(description[1L, "Package"]), "exdqlm") ||
    !identical(as.character(description[1L, "Version"]), "1.0.0")) {
  stop("v4 closeout requires the exdqlm 1.0.0 worktree.", call. = FALSE)
}

git_branch_before <- git_value(c("branch", "--show-current"))
git_commit_before <- git_value(c("rev-parse", "HEAD"))
tracked_dirty_before <- length(system2(
  "git", c("-C", repo_root, "diff", "--name-only"), stdout = TRUE
)) > 0L || length(system2(
  "git", c("-C", repo_root, "diff", "--cached", "--name-only"), stdout = TRUE
)) > 0L
untracked_before <- system2(
  "git", c("-C", repo_root, "ls-files", "--others", "--exclude-standard"),
  stdout = TRUE
)

parent_all <- read_csv(parent_all_path)
parent_envelope <- read_csv(parent_envelope_path)
parent_handoff <- read_csv(parent_handoff_path)
target_specs <- read_csv(target_specs_path)
campaign_progress <- read_csv(campaign_progress_path)
root_status_mix <- read_csv(campaign_root_status_mix_path)
fit_summary <- read_csv(campaign_fit_summary_path)
parent_manifest <- jsonlite::read_json(parent_manifest_path, simplifyVector = TRUE)
materialization_manifest <- jsonlite::read_json(materialization_manifest_path, simplifyVector = TRUE)
campaign_completed <- jsonlite::read_json(campaign_completed_path, simplifyVector = TRUE)

standard_columns <- c(
  "model_variant", "family", "tau", "fit_size", "candidate_id", "spec_id",
  "fit_qtrue_rmse", "forecast_qtrue_mae_H1000", "forecast_check_loss_H1000",
  "status", "signoff_grade", "comparison_eligible", "run_tag",
  "source_key", "source_path", "source_table_sha256",
  "source_registry_hash_value"
)
missing_parent <- setdiff(standard_columns, names(parent_all))
if (length(missing_parent)) {
  stop(sprintf(
    "Parent candidate ledger missing column(s): %s",
    paste(missing_parent, collapse = ", ")
  ), call. = FALSE)
}
if (nrow(parent_envelope) != 36L ||
    nrow(unique(parent_envelope[c("model_variant", "family", "tau", "fit_size")])) != 36L) {
  stop("Parent metric envelope no longer has the frozen 36-cell structure.", call. = FALSE)
}
registry_hash <- unique(as.character(parent_envelope$source_registry_hash_value))
if (length(registry_hash) != 1L ||
    registry_hash != source_hash_expected ||
    registry_hash != as.character(parent_manifest$source_registry_hash_value)) {
  stop("Parent source-registry hash is not the expected frozen v2 hash.", call. = FALSE)
}

if (!identical(materialization_manifest$source_registry_hash, source_hash_expected) ||
    !identical(materialization_manifest$launch_status, "prepared_not_launched")) {
  stop("v4 materialization manifest no longer matches the staged launch contract.", call. = FALSE)
}
if (as.integer(campaign_completed$n_roots) != 75L ||
    as.integer(campaign_completed$n_fits) != 75L ||
    !identical(campaign_completed$recommendation, "COMPARISON_READY_WITH_DOCUMENTED_DYNAMIC_FAIL_BAND")) {
  stop("v4 campaign completion manifest does not certify 75 completed fits.", call. = FALSE)
}
if (nrow(root_status_mix) != 1L ||
    root_status_mix$root_status[[1L]] != "SUCCESS" ||
    as.integer(root_status_mix$n[[1L]]) != 75L) {
  stop("v4 campaign root status mix is not 75 SUCCESS roots.", call. = FALSE)
}
if (nrow(fit_summary) != 75L || nrow(target_specs) != 75L ||
    nrow(campaign_progress) != 75L) {
  stop("v4 closeout expected exactly 75 target, progress, and fit rows.", call. = FALSE)
}

target_specs$target_family <- target_specs[[if ("family.x" %in% names(target_specs)) "family.x" else "family"]]
target_specs$target_tau <- num(target_specs[[if ("tau.x" %in% names(target_specs)) "tau.x" else "tau"]])
target_specs$target_profile <- target_specs[[if ("screening_profile_id.x" %in% names(target_specs)) "screening_profile_id.x" else "screening_profile_id"]]
target_specs$model_variant <- paste0("qdesn_", target_specs$likelihood_target, "_rhs_ns")
target_specs$target_cell_key <- cell_key(
  target_specs$model_variant,
  target_specs$target_family,
  target_specs$target_tau,
  500L
)
if (length(unique(target_specs$target_cell_key)) != 15L ||
    any(table(target_specs$target_cell_key) != 5L)) {
  stop("v4 target specs are not five candidates for each of 15 cells.", call. = FALSE)
}

forecast_files <- list.files(
  roots_root,
  pattern = "forecast_horizon_summary[.]csv$",
  recursive = TRUE,
  full.names = TRUE
)
if (length(forecast_files) != 75L) {
  stop(sprintf("Expected 75 forecast summaries, found %d.", length(forecast_files)), call. = FALSE)
}
forecast_summary <- do.call(rbind, lapply(forecast_files, function(path) {
  value <- read_csv(path)
  value$forecast_source_path <- normalizePath(path, winslash = "/", mustWork = TRUE)
  value$forecast_source_sha256 <- sha256(path)
  value
}))
forecast_h1000 <- forecast_summary[
  forecast_summary$window == "forecast_H1000" | as.integer(forecast_summary$horizon) == 1000L,
  ,
  drop = FALSE
]
if (nrow(forecast_h1000) != 75L ||
    any(as.integer(forecast_h1000$source_index_first) != 9001L) ||
    any(as.integer(forecast_h1000$source_index_last) != 10000L)) {
  stop("v4 forecast summaries do not provide one H1000 row per root.", call. = FALSE)
}

fit_summary$model_variant <- paste0("qdesn_", fit_summary$model, "_rhs_ns")
v4 <- merge(
  fit_summary,
  forecast_h1000[c(
    "root_id", "qtrue_mae", "qtrue_rmse", "pinball_tau", "coverage",
    "forecast_source_path", "forecast_source_sha256"
  )],
  by = "root_id",
  all.x = TRUE
)
target_keep <- c(
  "root_id", "likelihood_target", "candidate_source", "selection_reason",
  "primary_gap", "current_worst_ratio", "fit_ratio_to_external_best",
  "forecast_mae_ratio_to_external_best", "forecast_check_ratio_to_external_best",
  "model_variant", "target_profile", "target_cell_key"
)
v4 <- merge(v4, target_specs[target_keep], by = c("root_id", "model_variant"), all.x = TRUE)
if (nrow(v4) != 75L || any(is.na(v4$primary_gap))) {
  stop("Could not join every v4 result back to its target-spec row.", call. = FALSE)
}
v4$candidate_id <- v4$screening_profile_id
v4$source_registry_hash_value <- registry_hash
v4$fit_qtrue_rmse <- num(v4$train_qtrue_rmse)
v4$forecast_qtrue_mae_H1000 <- num(v4$qtrue_mae)
v4$forecast_check_loss_H1000 <- num(v4$pinball_tau)
v4$comparison_eligible <- "STATUS_AGNOSTIC"
v4$run_tag <- run_tag
v4$source_key <- "qdesn_metricgap_v4_targeted_mcmc_screen"
v4$fit_source_path <- normalizePath(campaign_fit_summary_path, winslash = "/", mustWork = TRUE)
v4$fit_source_sha256 <- sha256(campaign_fit_summary_path)

candidate_metrics_columns <- c(
  "model_variant", "family", "tau", "fit_size", "candidate_id", "spec_id",
  "root_id", "screening_profile_id", "profile_role", "candidate_source",
  "selection_reason", "primary_gap", "rhs_tau0", "readout_y_lags",
  "reservoir_lags", "dimension_p_estimate", "p_over_n_tt500", "runtime_sec",
  "status", "finite_ok", "domain_ok", "signoff_grade", "signoff_reason",
  "fit_qtrue_rmse", "forecast_qtrue_mae_H1000", "forecast_check_loss_H1000",
  "train_qtrue_mae", "train_pinball_tau", "holdout_qtrue_rmse",
  "holdout_qtrue_mae", "coverage", "fit_source_path", "fit_source_sha256",
  "forecast_source_path", "forecast_source_sha256", "run_tag",
  "source_registry_hash_value"
)
candidate_metrics_path <- write_csv(
  v4[intersect(candidate_metrics_columns, names(v4))],
  file.path(promotion_root, paste0(promotion_id, "_v4_candidate_metrics.csv"))
)
candidate_metrics_sha <- sha256(candidate_metrics_path)
v4_standard <- v4[, setdiff(standard_columns, c("source_path", "source_table_sha256")), drop = FALSE]
v4_standard$source_path <- candidate_metrics_path
v4_standard$source_table_sha256 <- candidate_metrics_sha
v4_standard <- v4_standard[standard_columns]

combined_candidates <- rbind(parent_all[standard_columns], v4_standard[standard_columns])
if (nrow(combined_candidates) != nrow(parent_all) + 75L) {
  stop("Combined candidate ledger does not add exactly 75 v4 rows.", call. = FALSE)
}
combined_path <- write_csv(
  combined_candidates,
  file.path(promotion_root, paste0(promotion_id, "_combined_candidate_ledger.csv"))
)

metric_columns <- c("fit_qtrue_rmse", "forecast_qtrue_mae_H1000", "forecast_check_loss_H1000")
keys <- cell_key(
  combined_candidates$model_variant,
  combined_candidates$family,
  combined_candidates$tau,
  combined_candidates$fit_size
)
metric_winner_rows <- list()
for (key in sort(unique(keys))) {
  block <- combined_candidates[keys == key, , drop = FALSE]
  for (metric in metric_columns) {
    pick <- block[order(num(block[[metric]]), block$run_tag, block$candidate_id, na.last = TRUE), , drop = FALSE][1L, , drop = FALSE]
    pick$metric_name <- metric
    pick$metric_role <- metric_label(metric)
    pick$metric_value <- num(pick[[metric]])
    metric_winner_rows[[length(metric_winner_rows) + 1L]] <- pick
  }
}
metric_winners <- do.call(rbind, metric_winner_rows)

winner_keys <- cell_key(
  metric_winners$model_variant,
  metric_winners$family,
  metric_winners$tau,
  metric_winners$fit_size
)
envelope_rows <- lapply(sort(unique(winner_keys)), function(key) {
  block <- metric_winners[winner_keys == key, , drop = FALSE]
  pick <- function(metric) {
    block[block$metric_name == metric, , drop = FALSE][1L, , drop = FALSE]
  }
  fit <- pick("fit_qtrue_rmse")
  mae <- pick("forecast_qtrue_mae_H1000")
  check <- pick("forecast_check_loss_H1000")
  grades <- c(fit$signoff_grade, mae$signoff_grade, check$signoff_grade)
  grade <- if ("FAIL" %in% grades) "FAIL" else if ("WARN" %in% grades) "WARN" else "PASS"
  mixed <- length(unique(c(fit$candidate_id, mae$candidate_id, check$candidate_id))) > 1L
  data.frame(
    model_variant = fit$model_variant,
    family = fit$family,
    tau = fit$tau,
    fit_size = fit$fit_size,
    comparison_eligible = "STATUS_AGNOSTIC",
    status = "SUCCESS",
    signoff_grade = grade,
    metric_source_mixed = ifelse(mixed, "TRUE", "FALSE"),
    fit_qtrue_rmse = fit$metric_value,
    forecast_qtrue_mae_H1000 = mae$metric_value,
    forecast_check_loss_H1000 = check$metric_value,
    fit_source_candidate_id = fit$candidate_id,
    fit_source_run_tag = fit$run_tag,
    fit_source_signoff_grade = fit$signoff_grade,
    fit_source_status = fit$status,
    fit_source_path = fit$source_path,
    fit_source_sha256 = fit$source_table_sha256,
    forecast_mae_source_candidate_id = mae$candidate_id,
    forecast_mae_source_run_tag = mae$run_tag,
    forecast_mae_source_signoff_grade = mae$signoff_grade,
    forecast_mae_source_status = mae$status,
    forecast_mae_source_path = mae$source_path,
    forecast_mae_source_sha256 = mae$source_table_sha256,
    forecast_check_source_candidate_id = check$candidate_id,
    forecast_check_source_run_tag = check$run_tag,
    forecast_check_source_signoff_grade = check$signoff_grade,
    forecast_check_source_status = check$status,
    forecast_check_source_path = check$source_path,
    forecast_check_source_sha256 = check$source_table_sha256,
    source_key = "status_agnostic_metricwise_calibrated_envelope_after_mgv4",
    source_promotion_id = promotion_id,
    source_table_sha256 = paste(sort(unique(c(
      fit$source_table_sha256,
      mae$source_table_sha256,
      check$source_table_sha256
    ))), collapse = ";"),
    source_registry_hash_value = registry_hash,
    stringsAsFactors = FALSE
  )
})
refreshed_envelope <- do.call(rbind, envelope_rows)
refreshed_envelope <- refreshed_envelope[
  order(refreshed_envelope$model_variant, refreshed_envelope$family, refreshed_envelope$tau),
  ,
  drop = FALSE
]
if (nrow(refreshed_envelope) != 36L ||
    nrow(unique(refreshed_envelope[c("model_variant", "family", "tau", "fit_size")])) != 36L) {
  stop("Refreshed metric envelope is not complete.", call. = FALSE)
}

parent_envelope <- parent_envelope[
  order(parent_envelope$model_variant, parent_envelope$family, parent_envelope$tau),
  ,
  drop = FALSE
]
metric_promotions <- do.call(rbind, lapply(seq_len(nrow(refreshed_envelope)), function(index) {
  current <- refreshed_envelope[index, , drop = FALSE]
  previous <- parent_envelope[index, , drop = FALSE]
  rows <- lapply(metric_columns, function(metric) {
    source_prefix <- switch(
      metric,
      fit_qtrue_rmse = "fit",
      forecast_qtrue_mae_H1000 = "forecast_mae",
      forecast_check_loss_H1000 = "forecast_check"
    )
    previous_value <- num(previous[[metric]])
    refreshed_value <- num(current[[metric]])
    data.frame(
      model_variant = current$model_variant,
      family = current$family,
      tau = current$tau,
      fit_size = current$fit_size,
      metric = metric,
      metric_role = metric_label(metric),
      previous_value = previous_value,
      refreshed_value = refreshed_value,
      improvement = previous_value - refreshed_value,
      improvement_pct = 100 * (1 - refreshed_value / previous_value),
      changed = refreshed_value < previous_value,
      previous_candidate_id = previous[[paste0(source_prefix, "_source_candidate_id")]],
      refreshed_candidate_id = current[[paste0(source_prefix, "_source_candidate_id")]],
      previous_run_tag = previous[[paste0(source_prefix, "_source_run_tag")]],
      refreshed_run_tag = current[[paste0(source_prefix, "_source_run_tag")]],
      refreshed_signoff_grade = current[[paste0(source_prefix, "_source_signoff_grade")]],
      refreshed_source_path = current[[paste0(source_prefix, "_source_path")]],
      refreshed_source_sha256 = current[[paste0(source_prefix, "_source_sha256")]],
      source_registry_hash_value = registry_hash,
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}))
metric_promotions <- metric_promotions[metric_promotions$changed, , drop = FALSE]
metric_promotions <- metric_promotions[
  order(metric_promotions$model_variant, metric_promotions$family, metric_promotions$tau, metric_promotions$metric),
  ,
  drop = FALSE
]
if (nrow(metric_promotions) != 7L) {
  stop(sprintf("Expected 7 v4 metric-wise promotions, found %d.", nrow(metric_promotions)), call. = FALSE)
}

target_join <- merge(
  v4,
  parent_handoff[c(
    "model_variant", "family", "tau", "fit_size",
    "fit_qtrue_rmse", "forecast_qtrue_mae_H1000", "forecast_check_loss_H1000",
    "external_best_fit_rmse", "external_best_forecast_mae", "external_best_forecast_check"
  )],
  by = c("model_variant", "family", "tau", "fit_size"),
  all.x = TRUE,
  suffixes = c("", "_parent")
)
target_join$target_previous_value <- ifelse(
  target_join$primary_gap == "fit",
  num(target_join$fit_qtrue_rmse_parent),
  ifelse(
    target_join$primary_gap == "forecast_mae",
    num(target_join$forecast_qtrue_mae_H1000_parent),
    num(target_join$forecast_check_loss_H1000_parent)
  )
)
target_join$target_new_value <- ifelse(
  target_join$primary_gap == "fit",
  num(target_join$fit_qtrue_rmse),
  ifelse(
    target_join$primary_gap == "forecast_mae",
    num(target_join$forecast_qtrue_mae_H1000),
    num(target_join$forecast_check_loss_H1000)
  )
)
target_join$target_improvement <- target_join$target_previous_value - target_join$target_new_value
target_join$target_improvement_pct <- 100 * (1 - target_join$target_new_value / target_join$target_previous_value)
target_join$new_fit_ratio_to_external_best <- num(target_join$fit_qtrue_rmse) / num(target_join$external_best_fit_rmse)
target_join$new_forecast_mae_ratio_to_external_best <- num(target_join$forecast_qtrue_mae_H1000) / num(target_join$external_best_forecast_mae)
target_join$new_forecast_check_ratio_to_external_best <- num(target_join$forecast_check_loss_H1000) / num(target_join$external_best_forecast_check)
target_join$new_worst_ratio_to_external_best <- do.call(pmax, c(
  target_join[c(
    "new_fit_ratio_to_external_best",
    "new_forecast_mae_ratio_to_external_best",
    "new_forecast_check_ratio_to_external_best"
  )],
  na.rm = TRUE
))

target_keys <- cell_key(target_join$model_variant, target_join$family, target_join$tau, target_join$fit_size)
target_best <- do.call(rbind, lapply(sort(unique(target_keys)), function(key) {
  block <- target_join[target_keys == key, , drop = FALSE]
  block[order(block$target_new_value, block$new_worst_ratio_to_external_best, block$root_id), , drop = FALSE][1L, , drop = FALSE]
}))
target_best$target_improved <- target_best$target_new_value < target_best$target_previous_value
if (sum(target_best$target_improved) != 6L) {
  stop(sprintf("Expected 6 v4 target-cell improvements, found %d.", sum(target_best$target_improved)), call. = FALSE)
}

target_best_path <- write_csv(
  target_best[intersect(c(
    "model_variant", "family", "tau", "fit_size", "candidate_id", "spec_id",
    "root_id", "screening_profile_id", "candidate_source", "primary_gap",
    "signoff_grade", "status", "rhs_tau0", "readout_y_lags",
    "reservoir_lags", "dimension_p_estimate", "p_over_n_tt500",
    "target_previous_value", "target_new_value", "target_improvement",
    "target_improvement_pct", "target_improved", "current_worst_ratio",
    "new_worst_ratio_to_external_best", "new_fit_ratio_to_external_best",
    "new_forecast_mae_ratio_to_external_best",
    "new_forecast_check_ratio_to_external_best", "fit_qtrue_rmse",
    "forecast_qtrue_mae_H1000", "forecast_check_loss_H1000", "runtime_sec",
    "signoff_reason", "run_tag", "source_registry_hash_value"
  ), names(target_best))],
  file.path(promotion_root, paste0(promotion_id, "_target_cell_best.csv"))
)

target_promotions <- target_best[target_best$target_improved, , drop = FALSE]
target_promotions_path <- write_csv(
  target_promotions[intersect(c(
    "model_variant", "family", "tau", "fit_size", "candidate_id", "spec_id",
    "root_id", "screening_profile_id", "primary_gap", "signoff_grade",
    "target_previous_value", "target_new_value", "target_improvement",
    "target_improvement_pct", "new_worst_ratio_to_external_best",
    "fit_qtrue_rmse", "forecast_qtrue_mae_H1000",
    "forecast_check_loss_H1000", "run_tag", "source_registry_hash_value"
  ), names(target_promotions))],
  file.path(promotion_root, paste0(promotion_id, "_target_metric_promotions.csv"))
)

refreshed_handoff <- merge(
  parent_handoff,
  refreshed_envelope[c(
    "model_variant", "family", "tau", "fit_size",
    "fit_qtrue_rmse", "forecast_qtrue_mae_H1000", "forecast_check_loss_H1000",
    "signoff_grade", "metric_source_mixed",
    "fit_source_candidate_id", "forecast_mae_source_candidate_id",
    "forecast_check_source_candidate_id"
  )],
  by = c("model_variant", "family", "tau", "fit_size"),
  all.x = TRUE,
  suffixes = c("_previous", "_refreshed")
)
refreshed_handoff$fit_ratio_refreshed <- num(refreshed_handoff$fit_qtrue_rmse_refreshed) /
  num(refreshed_handoff$external_best_fit_rmse)
refreshed_handoff$forecast_mae_ratio_refreshed <- num(refreshed_handoff$forecast_qtrue_mae_H1000_refreshed) /
  num(refreshed_handoff$external_best_forecast_mae)
refreshed_handoff$forecast_check_ratio_refreshed <- num(refreshed_handoff$forecast_check_loss_H1000_refreshed) /
  num(refreshed_handoff$external_best_forecast_check)
refreshed_handoff$worst_ratio_refreshed <- do.call(pmax, c(
  refreshed_handoff[c(
    "fit_ratio_refreshed",
    "forecast_mae_ratio_refreshed",
    "forecast_check_ratio_refreshed"
  )],
  na.rm = TRUE
))
refreshed_handoff$primary_remaining_gap <- ifelse(
  refreshed_handoff$fit_ratio_refreshed >= refreshed_handoff$forecast_mae_ratio_refreshed &
    refreshed_handoff$fit_ratio_refreshed >= refreshed_handoff$forecast_check_ratio_refreshed,
  "fit",
  ifelse(
    refreshed_handoff$forecast_mae_ratio_refreshed >= refreshed_handoff$forecast_check_ratio_refreshed,
    "forecast_mae",
    "forecast_check"
  )
)
refreshed_handoff$metricgap_v4_status <- ifelse(
  cell_key(refreshed_handoff$model_variant, refreshed_handoff$family, refreshed_handoff$tau, refreshed_handoff$fit_size) %in%
    target_best$target_cell_key[target_best$target_improved],
  "improved_by_v4",
  "not_improved_by_v4"
)
refreshed_handoff$recommended_next_axis <- ifelse(
  refreshed_handoff$primary_remaining_gap == "fit",
  "fit-first redesign: broaden reservoir memory/capacity with stronger shrinkage and multi-seed confirmation",
  ifelse(
    refreshed_handoff$primary_remaining_gap == "forecast_mae",
    "forecast-first redesign: stabilize rolling-origin dynamics, vary memory/rho/alpha jointly, and keep fit guardrails",
    "check-loss redesign: quantile-loss calibration with likelihood/tail sensitivity and conservative shrinkage"
  )
)
unresolved <- refreshed_handoff[
  refreshed_handoff$worst_ratio_refreshed > 1.10 &
    refreshed_handoff$model_variant %in% c("qdesn_al_rhs_ns", "qdesn_exal_rhs_ns"),
  ,
  drop = FALSE
]
unresolved <- unresolved[
  order(-unresolved$worst_ratio_refreshed, unresolved$model_variant, unresolved$family, unresolved$tau),
  ,
  drop = FALSE
]
next_screen <- unresolved
next_screen$next_screen_role <- "case_specific_post_v4_mcmc_redesign"
next_screen$launch_status <- "not_prepared_not_launched"
next_screen$next_budget_recommendation <- "screening MCMC first; promote only metric-wise gains, then full confirmation for coherent article claims"

metric_winners_path <- write_csv(
  metric_winners,
  file.path(promotion_root, paste0(promotion_id, "_metric_winners.csv"))
)
metric_promotions_path <- write_csv(
  metric_promotions,
  file.path(promotion_root, paste0(promotion_id, "_metricwise_promotions.csv"))
)
refreshed_envelope_path <- write_csv(
  refreshed_envelope,
  file.path(promotion_root, paste0(promotion_id, "_refreshed_article_envelope.csv"))
)
unresolved_path <- write_csv(
  unresolved,
  file.path(promotion_root, paste0(promotion_id, "_unresolved_cells.csv"))
)
next_screen_path <- write_csv(
  next_screen,
  file.path(promotion_root, paste0(promotion_id, "_next_screen_handoff.csv"))
)

heavy <- list.files(
  c(file.path(repo_root, "results", "qdesn_mcmc_validation", stage),
    file.path(repo_root, "reports", "qdesn_mcmc_validation", stage)),
  pattern = "[.](rds|rda|RData)$|__design[.]rds$",
  recursive = TRUE,
  full.names = TRUE,
  ignore.case = TRUE
)
storage_audit <- data.frame(
  path_pattern = c(
    file.path("results/qdesn_mcmc_validation", stage),
    file.path("reports/qdesn_mcmc_validation", stage)
  ),
  project_task_ownership = "independent_qdesn_dqlm_validation_metricgap_v4",
  checked_for = ".rds/.rda/.RData/__design.rds",
  heavy_files_found = length(heavy),
  action = ifelse(length(heavy), "defer_manual_review", "keep_no_cleanup_needed"),
  stringsAsFactors = FALSE
)
storage_audit_path <- write_csv(
  storage_audit,
  file.path(promotion_root, paste0(promotion_id, "_storage_audit.csv"))
)

execution_audit <- data.frame(
  run_tag = run_tag,
  stage = stage,
  report_root = normalizePath(report_root, winslash = "/", mustWork = TRUE),
  results_root = normalizePath(results_root, winslash = "/", mustWork = TRUE),
  planned_roots = nrow(target_specs),
  campaign_progress_rows = nrow(campaign_progress),
  fit_summary_rows = nrow(fit_summary),
  forecast_h1000_rows = nrow(forecast_h1000),
  root_success = as.integer(root_status_mix$n[[1L]]),
  root_failed = 0L,
  target_cells = length(unique(target_specs$target_cell_key)),
  target_cell_improvements = sum(target_best$target_improved),
  metricwise_promotions = nrow(metric_promotions),
  refreshed_envelope_rows = nrow(refreshed_envelope),
  unresolved_cells = nrow(unresolved),
  source_registry_hash_value = registry_hash,
  storage_heavy_files_found = length(heavy),
  stringsAsFactors = FALSE
)
execution_audit_path <- write_csv(
  execution_audit,
  file.path(promotion_root, paste0(promotion_id, "_execution_audit.csv"))
)

source_paths <- c(
  parent_all = parent_all_path,
  parent_envelope = parent_envelope_path,
  parent_handoff = parent_handoff_path,
  parent_manifest = parent_manifest_path,
  v4_target_specs = target_specs_path,
  v4_materialization_manifest = materialization_manifest_path,
  v4_campaign_completed = campaign_completed_path,
  v4_campaign_summary = campaign_summary_path,
  v4_campaign_progress = campaign_progress_path,
  v4_root_status_mix = campaign_root_status_mix_path,
  v4_campaign_fit_summary = campaign_fit_summary_path
)
source_manifest <- data.frame(
  source_id = names(source_paths),
  path = vapply(source_paths, normalizePath, character(1L), winslash = "/", mustWork = TRUE),
  sha256 = vapply(source_paths, sha256, character(1L)),
  stringsAsFactors = FALSE
)
source_manifest_path <- write_csv(source_manifest, file.path(promotion_root, "source_manifest.csv"))

outputs <- c(
  candidate_metrics_path, combined_path, metric_winners_path, metric_promotions_path,
  refreshed_envelope_path, target_best_path, target_promotions_path,
  unresolved_path, next_screen_path, storage_audit_path, execution_audit_path,
  source_manifest_path
)
file_manifest <- data.frame(
  path = outputs,
  sha256 = vapply(outputs, sha256, character(1L)),
  stringsAsFactors = FALSE
)
file_manifest_path <- write_csv(file_manifest, file.path(promotion_root, "file_manifest.csv"))

summary <- data.frame(
  promotion_id = promotion_id,
  parent_promotion_id = parent_id,
  run_tag = run_tag,
  stage = stage,
  planned_roots = nrow(target_specs),
  completed_roots = as.integer(root_status_mix$n[[1L]]),
  failed_roots = 0L,
  target_cells = length(unique(target_specs$target_cell_key)),
  target_cell_improvements = sum(target_best$target_improved),
  metricwise_promotions = nrow(metric_promotions),
  metricwise_promotion_cells = length(unique(cell_key(
    metric_promotions$model_variant,
    metric_promotions$family,
    metric_promotions$tau,
    metric_promotions$fit_size
  ))),
  refreshed_envelope_rows = nrow(refreshed_envelope),
  unresolved_cells = nrow(unresolved),
  storage_heavy_files_found = length(heavy),
  recommendation = "promote_metricwise_gains_only_and_plan_case_specific_post_v4_redesign",
  article_update_decision = "do_not_update_article_until_user_requests_surgical_refresh",
  source_registry_hash_value = registry_hash,
  stringsAsFactors = FALSE
)
summary_path <- write_csv(summary, file.path(promotion_root, paste0(promotion_id, "_summary.csv")))

manifest <- list(
  promotion_id = promotion_id,
  generated_at = as.character(Sys.time()),
  validation_branch = git_branch_before,
  validation_commit_at_materialization = git_commit_before,
  tracked_source_dirty_before_materialization = tracked_dirty_before,
  untracked_before_materialization = unname(untracked_before),
  package_version = "1.0.0",
  source_registry_hash_name = "sha256",
  source_registry_hash_value = registry_hash,
  parent_promotion_id = parent_id,
  stage = stage,
  run_tag = run_tag,
  campaign_stamp = stamp,
  campaign_completed = TRUE,
  selection_unit = "model_variant x family x tau x metric",
  selection_rule = "status-agnostic metric-wise minimum; retain signoff grade and source hashes",
  n_v4_candidates = nrow(v4),
  n_combined_candidates = nrow(combined_candidates),
  n_target_cells = length(unique(target_specs$target_cell_key)),
  n_target_cell_improvements = sum(target_best$target_improved),
  n_metricwise_promotions = nrow(metric_promotions),
  n_metricwise_promotion_cells = length(unique(cell_key(
    metric_promotions$model_variant,
    metric_promotions$family,
    metric_promotions$tau,
    metric_promotions$fit_size
  ))),
  n_refreshed_envelope_rows = nrow(refreshed_envelope),
  n_unresolved_cells = nrow(unresolved),
  storage_heavy_files_found = length(heavy),
  article_integration_status = "not_applied_in_this_closeout",
  source_manifest = source_manifest,
  files = lapply(
    seq_len(nrow(file_manifest)),
    function(index) as.list(file_manifest[index, , drop = FALSE])
  )
)
manifest_path <- write_json(
  manifest,
  file.path(promotion_root, paste0(promotion_id, "_manifest.json"))
)

readme <- c(
  "# Q-DESN MCMC Metric-Gap v4 Targeted Closeout",
  "",
  sprintf("- Promotion id: `%s`", promotion_id),
  sprintf("- Parent metric envelope: `%s`", parent_id),
  sprintf("- Run tag: `%s`", run_tag),
  sprintf("- Validation branch: `%s`", git_branch_before),
  sprintf("- Materialization commit: `%s`", git_commit_before),
  sprintf("- Source registry SHA-256: `%s`", registry_hash),
  sprintf("- Completed roots: `%d/%d`", as.integer(root_status_mix$n[[1L]]), nrow(target_specs)),
  sprintf("- Target cells: `%d`", length(unique(target_specs$target_cell_key))),
  sprintf("- Target-cell improvements: `%d`", sum(target_best$target_improved)),
  sprintf("- Metric-wise envelope promotions: `%d` across `%d` cells",
          nrow(metric_promotions),
          length(unique(cell_key(metric_promotions$model_variant, metric_promotions$family, metric_promotions$tau, metric_promotions$fit_size)))),
  sprintf("- Refreshed envelope rows: `%d/36`", nrow(refreshed_envelope)),
  sprintf("- Unresolved post-v4 cells: `%d`", nrow(unresolved)),
  sprintf("- Heavy payloads retained in v4 trees: `%d`", length(heavy)),
  "",
  "## Decision",
  "",
  "The v4 targeted MCMC run completed cleanly and is storage-light. The closeout",
  "uses the requested status-agnostic metric policy: metric improvements are",
  "eligible even when a candidate has WARN or FAIL signoff, but the signoff grade",
  "is retained in every table. This run produced six improved target cells and",
  "seven metric-wise envelope updates. Non-improving v4 candidates are kept as",
  "diagnostic evidence only and do not replace earlier envelope entries.",
  "",
  "## Main Artifacts",
  "",
  sprintf("- V4 candidate metrics: `%s`", basename(candidate_metrics_path)),
  sprintf("- Target-cell winners: `%s`", basename(target_best_path)),
  sprintf("- Target metric promotions: `%s`", basename(target_promotions_path)),
  sprintf("- Metric-wise promotions: `%s`", basename(metric_promotions_path)),
  sprintf("- Refreshed article envelope candidate: `%s`", basename(refreshed_envelope_path)),
  sprintf("- Unresolved cells: `%s`", basename(unresolved_path)),
  sprintf("- Next-screen handoff: `%s`", basename(next_screen_path)),
  sprintf("- Manifest: `%s`", basename(manifest_path)),
  "",
  "## Next Scientific Move",
  "",
  "Use the unresolved-cell handoff as a diagnostic/candidate-selection table, not",
  "as a launch file. The next design should be case-specific and should break away",
  "from repeating the same tradeoff surface: fit-dominated cells need fit-first",
  "capacity/memory redesign with stronger shrinkage and multi-seed confirmation;",
  "forecast-dominated cells need rolling-origin stability and joint memory/rho/alpha",
  "redesign with fit guardrails."
)
writeLines(readme, file.path(promotion_root, "README.md"), useBytes = TRUE)

cat(sprintf("promotion_root: %s\n", normalizePath(promotion_root, winslash = "/", mustWork = TRUE)))
cat(sprintf("completed_roots: %d/%d\n", as.integer(root_status_mix$n[[1L]]), nrow(target_specs)))
cat(sprintf("target_cell_improvements: %d\n", sum(target_best$target_improved)))
cat(sprintf("metricwise_promotions: %d\n", nrow(metric_promotions)))
cat(sprintf("refreshed_envelope_rows: %d\n", nrow(refreshed_envelope)))
cat(sprintf("unresolved_cells: %d\n", nrow(unresolved)))
cat(sprintf("storage_heavy_files_found: %d\n", length(heavy)))

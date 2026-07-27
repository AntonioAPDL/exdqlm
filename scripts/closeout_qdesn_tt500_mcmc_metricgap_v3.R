#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  if (!requireNamespace("jsonlite", quietly = TRUE)) {
    stop("Package `jsonlite` is required.", call. = FALSE)
  }
})

args <- commandArgs(trailingOnly = TRUE)
get_arg <- function(flag, default = NULL) {
  index <- which(args == flag)
  if (!length(index) || index[[1L]] >= length(args)) return(default)
  args[[index[[1L]] + 1L]]
}
`%||%` <- function(a, b) if (is.null(a) || !length(a)) b else a

repo_root <- normalizePath(
  system("git rev-parse --show-toplevel", intern = TRUE),
  winslash = "/",
  mustWork = TRUE
)
setwd(repo_root)

resolve_path <- function(path, must_work = TRUE) {
  path <- as.character(path %||% "")[1L]
  if (!nzchar(trimws(path))) return(NULL)
  if (!grepl("^(/|~)", path)) path <- file.path(repo_root, path)
  normalizePath(path, winslash = "/", mustWork = isTRUE(must_work))
}
read_csv <- function(path) {
  utils::read.csv(resolve_path(path), check.names = FALSE, stringsAsFactors = FALSE)
}
write_csv <- function(value, path) {
  path <- resolve_path(path, must_work = FALSE)
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(value, path, row.names = FALSE, na = "")
  normalizePath(path, winslash = "/", mustWork = TRUE)
}
write_json <- function(value, path) {
  path <- resolve_path(path, must_work = FALSE)
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  jsonlite::write_json(
    value,
    path,
    pretty = TRUE,
    auto_unbox = TRUE,
    null = "null",
    digits = NA
  )
  normalizePath(path, winslash = "/", mustWork = TRUE)
}
sha256_file <- function(path) unname(tools::sha256sum(resolve_path(path)))
num <- function(x) suppressWarnings(as.numeric(x))
tau_key <- function(x) sprintf("%.8f", num(x))
as_bool <- function(x) toupper(trimws(as.character(x))) %in% c("TRUE", "T", "1", "YES")

source_stage <- "qdesn_dynamic_fitforecast_v2_tt500_mcmc_metricgap_v3"
repair_stage <- paste0(source_stage, "_tau0_repair")
original_report_root <- resolve_path(get_arg(
  "--original-report-root",
  file.path(
    "reports", "qdesn_mcmc_validation", source_stage,
    "qdesn-tt500-mcmc-metricgap-v3-full-20260726__git-fa5dca4",
    "20260726-193528__git-fa5dca4"
  )
))
repair_report_root <- resolve_path(get_arg("--repair-report-root", NULL))
if (is.null(repair_report_root)) {
  stop("Closeout requires --repair-report-root for one completed 25-spec repair campaign.", call. = FALSE)
}
stamp <- as.character(get_arg("--stamp", format(Sys.Date(), "%Y%m%d")))[1L]
closeout_id <- paste0("qdesn_tt500_mcmc_metricgap_v3_combined_closeout_", stamp)
output_root <- resolve_path(get_arg(
  "--output-root",
  file.path("validation", "fitforecast_v2", "promotions", closeout_id)
), must_work = FALSE)

original_targets_path <- resolve_path(file.path(
  "config", "validation", paste0(source_stage, "_target_spec_ids.csv")
))
repair_targets_path <- resolve_path(file.path(
  "config", "validation", paste0(repair_stage, "_target_spec_ids.csv")
))
handoff_path <- resolve_path(file.path(
  "validation", "fitforecast_v2", "promotions",
  "qdesn_dqlm_500obs_mcmc_metric_envelope_20260726",
  "qdesn_dqlm_500obs_mcmc_metric_envelope_20260726_targeted_screening_handoff.csv"
))

campaign_paths <- function(root) {
  c(
    fit = file.path(root, "tables", "campaign_fit_summary.csv"),
    progress = file.path(root, "tables", "campaign_progress.csv"),
    completed = file.path(root, "manifest", "campaign_completed.json")
  )
}
read_campaign <- function(root) {
  paths <- campaign_paths(root)
  invisible(lapply(paths, resolve_path))
  list(
    paths = paths,
    fit = read_csv(paths[["fit"]]),
    progress = read_csv(paths[["progress"]]),
    completed = jsonlite::read_json(paths[["completed"]], simplifyVector = TRUE)
  )
}
original <- read_campaign(original_report_root)
repair <- read_campaign(repair_report_root)
original_targets <- read_csv(original_targets_path)
repair_targets <- read_csv(repair_targets_path)
handoff <- read_csv(handoff_path)

if (nrow(original$progress) != 80L ||
    sum(original$progress$root_status == "SUCCESS") != 55L ||
    sum(original$progress$root_status == "FAIL") != 25L ||
    nrow(original$fit) != 80L ||
    anyDuplicated(original$fit$root_id) ||
    !setequal(original$fit$root_id, original$progress$root_id)) {
  stop(
    paste(
      "Original campaign no longer has the audited 80 attempted / 80 metric-row",
      "/ 55 successful / 25 failed structure."
    ),
    call. = FALSE
  )
}
if (nrow(repair$progress) != 25L ||
    !all(repair$progress$root_status == "SUCCESS") ||
    nrow(repair$fit) != 25L ||
    as.integer(repair$completed$n_roots) != 25L ||
    as.integer(repair$completed$n_fits) != 25L) {
  stop("Repair campaign is not a complete 25-root / 25-fit success.", call. = FALSE)
}
if (nrow(original_targets) != 80L ||
    nrow(repair_targets) != 25L ||
    !all(abs(num(repair_targets$rhs_tau0) - 3e-5) <= 1e-12)) {
  stop("Original or repair target-spec contract is invalid.", call. = FALSE)
}
original_failed <- as.character(
  original$progress$root_id[original$progress$root_status == "FAIL"]
)
if (!setequal(original_failed, repair_targets$root_id) ||
    !setequal(repair$progress$root_id, repair_targets$root_id)) {
  stop("Repair campaign does not exactly replace the original 25-root failure set.", call. = FALSE)
}

original_successful_root_ids <- as.character(
  original$progress$root_id[original$progress$root_status == "SUCCESS"]
)
original$fit <- original$fit[
  match(original_successful_root_ids, original$fit$root_id),
  ,
  drop = FALSE
]
if (nrow(original$fit) != 55L ||
    anyNA(original$fit$root_id) ||
    !setequal(original$fit$root_id, original_successful_root_ids)) {
  stop("Could not isolate the 55 original successful metric rows.", call. = FALSE)
}

original$fit$evidence_source <- "original_metricgap_v3_success"
repair$fit$evidence_source <- "tau0_transport_repair_success"
common_columns <- union(names(original$fit), names(repair$fit))
pad_columns <- function(value, columns) {
  missing <- setdiff(columns, names(value))
  for (column in missing) value[[column]] <- NA
  value[, columns, drop = FALSE]
}
candidates <- rbind(
  pad_columns(original$fit, common_columns),
  pad_columns(repair$fit, common_columns)
)
if (nrow(candidates) != 80L ||
    anyDuplicated(candidates$root_id) ||
    anyDuplicated(candidates$spec_id) ||
    !setequal(candidates$spec_id, original_targets$spec_id)) {
  stop("Combined evidence is not one unique metric-complete row for each frozen 80-spec target.", call. = FALSE)
}

extract_h1000 <- function(path) {
  horizon_path <- sub(
    "forecast_lead_metrics[.]csv$",
    "forecast_horizon_summary.csv",
    as.character(path)
  )
  horizon <- read_csv(horizon_path)
  horizon <- horizon[num(horizon$horizon) == 1000, , drop = FALSE]
  if (nrow(horizon) != 1L) {
    stop(sprintf("Expected one H=1000 row at %s.", horizon_path), call. = FALSE)
  }
  data.frame(
    root_id = as.character(horizon$root_id),
    forecast_qtrue_mae_H1000 = num(horizon$qtrue_mae),
    forecast_qtrue_rmse_H1000 = num(horizon$qtrue_rmse),
    forecast_check_loss_H1000 = num(horizon$pinball_tau),
    forecast_horizon_summary_path = normalizePath(
      horizon_path,
      winslash = "/",
      mustWork = TRUE
    ),
    stringsAsFactors = FALSE
  )
}
h1000 <- do.call(rbind, lapply(candidates$forecast_lead_metrics_path, extract_h1000))
candidates <- merge(candidates, h1000, by = "root_id", all.x = TRUE, sort = FALSE)
candidates$model_variant <- ifelse(
  candidates$likelihood_family == "al",
  "qdesn_al_rhs_ns",
  "qdesn_exal_rhs_ns"
)
candidates$fit_qtrue_rmse <- num(candidates$train_qtrue_rmse)
candidates$fit_check_loss <- num(candidates$train_pinball_tau)

handoff_columns <- c(
  "model_variant", "family", "tau", "fit_qtrue_rmse",
  "forecast_qtrue_mae_H1000", "forecast_check_loss_H1000",
  "external_best_fit_rmse", "external_best_forecast_mae",
  "external_best_forecast_check", "primary_gap", "priority",
  "source_registry_hash_value", "metric_source_mixed",
  "fit_source_candidate_id", "fit_source_run_tag",
  "forecast_mae_source_candidate_id", "forecast_mae_source_run_tag",
  "forecast_check_source_candidate_id", "forecast_check_source_run_tag"
)
missing_handoff <- setdiff(handoff_columns, names(handoff))
if (length(missing_handoff)) {
  stop(sprintf("Metric-envelope handoff is missing: %s", paste(missing_handoff, collapse = ", ")), call. = FALSE)
}
baseline <- handoff[, handoff_columns, drop = FALSE]
names(baseline)[names(baseline) == "fit_qtrue_rmse"] <- "current_fit_qtrue_rmse"
names(baseline)[names(baseline) == "forecast_qtrue_mae_H1000"] <-
  "current_forecast_qtrue_mae_H1000"
names(baseline)[names(baseline) == "forecast_check_loss_H1000"] <-
  "current_forecast_check_loss_H1000"
candidates <- merge(
  candidates,
  baseline,
  by = c("model_variant", "family", "tau"),
  all.x = TRUE,
  sort = FALSE
)
if (nrow(candidates) != 80L ||
    any(!is.finite(num(candidates$current_fit_qtrue_rmse)))) {
  stop("Could not attach one frozen metric-envelope baseline to every candidate.", call. = FALSE)
}

candidates$fit_ratio_to_current <- candidates$fit_qtrue_rmse /
  num(candidates$current_fit_qtrue_rmse)
candidates$forecast_mae_ratio_to_current <- candidates$forecast_qtrue_mae_H1000 /
  num(candidates$current_forecast_qtrue_mae_H1000)
candidates$forecast_check_ratio_to_current <- candidates$forecast_check_loss_H1000 /
  num(candidates$current_forecast_check_loss_H1000)
candidates$fit_ratio_to_external_best <- candidates$fit_qtrue_rmse /
  num(candidates$external_best_fit_rmse)
candidates$forecast_mae_ratio_to_external_best <- candidates$forecast_qtrue_mae_H1000 /
  num(candidates$external_best_forecast_mae)
candidates$forecast_check_ratio_to_external_best <- candidates$forecast_check_loss_H1000 /
  num(candidates$external_best_forecast_check)
candidates$worst_ratio_to_current <- pmax(
  candidates$fit_ratio_to_current,
  candidates$forecast_mae_ratio_to_current,
  candidates$forecast_check_ratio_to_current
)
candidates$worst_ratio_to_external_best <- pmax(
  candidates$fit_ratio_to_external_best,
  candidates$forecast_mae_ratio_to_external_best,
  candidates$forecast_check_ratio_to_external_best
)
candidates$primary_ratio_to_current <- ifelse(
  candidates$primary_gap == "fit",
  candidates$fit_ratio_to_current,
  ifelse(
    candidates$primary_gap == "forecast_mae",
    candidates$forecast_mae_ratio_to_current,
    candidates$forecast_check_ratio_to_current
  )
)
candidates$primary_improvement_pct <- 100 * (1 - candidates$primary_ratio_to_current)
candidates$all_three_no_regression <- candidates$fit_ratio_to_current <= 1 &
  candidates$forecast_mae_ratio_to_current <= 1 &
  candidates$forecast_check_ratio_to_current <= 1
candidates$confirmation_tolerance_gate <- candidates$primary_ratio_to_current <= 0.995 &
  candidates$fit_ratio_to_current <= 1.01 &
  candidates$forecast_mae_ratio_to_current <= 1.01 &
  candidates$forecast_check_ratio_to_current <= 1.01
candidates$diagnostic_grade_rank <- match(
  candidates$signoff_grade,
  c("PASS", "WARN", "FAIL")
)
candidates$execution_complete <- candidates$status == "SUCCESS" &
  as_bool(candidates$finite_ok) &
  as_bool(candidates$domain_ok)

cell_key <- paste(
  candidates$model_variant,
  candidates$family,
  tau_key(candidates$tau),
  sep = "\r"
)
groups <- split(candidates, cell_key)
pareto_flag <- function(value) {
  metrics <- as.matrix(value[, c(
    "fit_qtrue_rmse", "forecast_qtrue_mae_H1000", "forecast_check_loss_H1000"
  )])
  vapply(seq_len(nrow(metrics)), function(i) {
    !any(vapply(seq_len(nrow(metrics)), function(j) {
      j != i && all(metrics[j, ] <= metrics[i, ]) && any(metrics[j, ] < metrics[i, ])
    }, logical(1L)))
  }, logical(1L))
}
rank_group <- function(value) {
  value$pareto_optimal <- pareto_flag(value)
  value <- value[order(
    !value$confirmation_tolerance_gate,
    value$primary_ratio_to_current,
    value$worst_ratio_to_current,
    value$diagnostic_grade_rank,
    value$spec_id
  ), , drop = FALSE]
  value$cell_rank <- seq_len(nrow(value))
  value
}
ranked <- do.call(rbind, lapply(groups, rank_group))
rownames(ranked) <- NULL
cell_winners <- ranked[ranked$cell_rank == 1L, , drop = FALSE]
if (length(groups) != 16L || nrow(cell_winners) != 16L) {
  stop("Expected five candidates in each of 16 family/tau/likelihood cells.", call. = FALSE)
}
cell_winners$confirmation_disposition <- ifelse(
  cell_winners$confirmation_tolerance_gate,
  "promote_to_full_mcmc_confirmation",
  "hold_and_redesign_cell"
)
confirmation_handoff <- cell_winners[
  cell_winners$confirmation_tolerance_gate,
  ,
  drop = FALSE
]
unresolved <- cell_winners[
  !cell_winners$confirmation_tolerance_gate,
  ,
  drop = FALSE
]
pareto <- ranked[ranked$pareto_optimal, , drop = FALSE]

closest_balanced <- do.call(rbind, lapply(groups, function(value) {
  value <- value[order(
    value$worst_ratio_to_current,
    value$primary_ratio_to_current,
    value$diagnostic_grade_rank,
    value$spec_id
  ), , drop = FALSE]
  value[1L, , drop = FALSE]
}))
rownames(closest_balanced) <- NULL
ratio_columns <- c(
  "fit_ratio_to_current",
  "forecast_mae_ratio_to_current",
  "forecast_check_ratio_to_current"
)
ratio_labels <- c("fit", "forecast_mae", "forecast_check")
closest_balanced$largest_regression_metric <- ratio_labels[
  max.col(as.matrix(closest_balanced[, ratio_columns, drop = FALSE]), ties.method = "first")
]

metricwise <- do.call(rbind, lapply(groups, function(value) {
  metric_columns <- c(
    "fit_qtrue_rmse",
    "forecast_qtrue_mae_H1000",
    "forecast_check_loss_H1000"
  )
  best_indices <- vapply(
    metric_columns,
    function(column) which.min(num(value[[column]])),
    integer(1L)
  )
  data.frame(
    model_variant = value$model_variant[[1L]],
    family = value$family[[1L]],
    tau = num(value$tau)[1L],
    metric = metric_columns,
    current_value = c(
      num(value$current_fit_qtrue_rmse)[1L],
      num(value$current_forecast_qtrue_mae_H1000)[1L],
      num(value$current_forecast_check_loss_H1000)[1L]
    ),
    best_candidate_value = vapply(
      seq_along(metric_columns),
      function(index) num(value[[metric_columns[[index]]]])[best_indices[[index]]],
      numeric(1L)
    ),
    best_candidate_root_id = value$root_id[best_indices],
    best_candidate_spec_id = value$spec_id[best_indices],
    best_candidate_profile_id = value$screening_profile_id[best_indices],
    best_candidate_evidence_source = value$evidence_source[best_indices],
    best_candidate_status = value$status[best_indices],
    best_candidate_signoff_grade = value$signoff_grade[best_indices],
    stringsAsFactors = FALSE
  )
}))
metricwise$improvement_pct <- 100 *
  (metricwise$current_value - metricwise$best_candidate_value) /
  metricwise$current_value

execution_audit <- data.frame(
  evidence_source = c(
    "original_metricgap_v3_success",
    "original_metricgap_v3_transport_failure",
    "tau0_transport_repair_success",
    "combined_metric_complete"
  ),
  n_roots = c(55L, 25L, 25L, 80L),
  disposition = c(
    "preserve_and_consume",
    "replace_only_with_exact_repair_specs",
    "consume_after_complete_campaign_gate",
    "rank_cell_by_cell"
  ),
  stringsAsFactors = FALSE
)

campaign_to_results <- function(path) {
  sub("/reports/", "/results/", normalizePath(path, winslash = "/", mustWork = TRUE), fixed = TRUE)
}
result_roots <- c(
  original = campaign_to_results(original_report_root),
  repair = campaign_to_results(repair_report_root)
)
heavy <- unlist(lapply(result_roots, function(root) {
  if (!dir.exists(root)) return(character())
  files <- list.files(root, recursive = TRUE, full.names = TRUE)
  files[grepl("[.](rds|rda|RData)$", files, ignore.case = TRUE)]
}), use.names = FALSE)
storage_audit <- if (length(heavy)) {
  info <- file.info(heavy)
  data.frame(
    path = normalizePath(heavy, winslash = "/", mustWork = TRUE),
    bytes = as.numeric(info$size),
    action = "defer_no_cleanup_performed",
    stringsAsFactors = FALSE
  )
} else {
  data.frame(path = character(), bytes = numeric(), action = character())
}

dir.create(output_root, recursive = TRUE, showWarnings = FALSE)
paths <- c(
  all_candidates = write_csv(ranked, file.path(output_root, paste0(closeout_id, "_all_candidates.csv"))),
  cell_winners = write_csv(cell_winners, file.path(output_root, paste0(closeout_id, "_cell_winners.csv"))),
  closest_balanced = write_csv(
    closest_balanced,
    file.path(output_root, paste0(closeout_id, "_closest_balanced_candidates.csv"))
  ),
  pareto = write_csv(pareto, file.path(output_root, paste0(closeout_id, "_pareto_candidates.csv"))),
  metricwise = write_csv(metricwise, file.path(output_root, paste0(closeout_id, "_metricwise_gains.csv"))),
  confirmation_handoff = write_csv(
    confirmation_handoff,
    file.path(output_root, paste0(closeout_id, "_full_confirmation_handoff.csv"))
  ),
  unresolved = write_csv(unresolved, file.path(output_root, paste0(closeout_id, "_unresolved_cells.csv"))),
  execution_audit = write_csv(
    execution_audit,
    file.path(output_root, paste0(closeout_id, "_execution_audit.csv"))
  ),
  storage_audit = write_csv(
    storage_audit,
    file.path(output_root, paste0(closeout_id, "_storage_audit.csv"))
  )
)

source_files <- c(
  original_fit = original$paths[["fit"]],
  original_progress = original$paths[["progress"]],
  original_completed = original$paths[["completed"]],
  repair_fit = repair$paths[["fit"]],
  repair_progress = repair$paths[["progress"]],
  repair_completed = repair$paths[["completed"]],
  original_targets = original_targets_path,
  repair_targets = repair_targets_path,
  metric_envelope_handoff = handoff_path
)
source_manifest <- data.frame(
  role = names(source_files),
  path = vapply(source_files, resolve_path, character(1L)),
  sha256 = vapply(source_files, sha256_file, character(1L)),
  stringsAsFactors = FALSE
)
source_manifest_path <- write_csv(source_manifest, file.path(output_root, "source_manifest.csv"))
paths <- c(paths, source_manifest = source_manifest_path)

recommendation <- if (nrow(confirmation_handoff) == 16L) {
  "READY_FOR_PER_CELL_FULL_MCMC_CONFIRMATION"
} else if (nrow(confirmation_handoff) > 0L) {
  "PARTIAL_CONFIRMATION_HANDOFF_REDESIGN_REMAINING_CELLS"
} else {
  "NO_CONFIRMATION_HANDOFF_REDESIGN_ALL_CELLS"
}
summary <- data.frame(
  closeout_id = closeout_id,
  original_successes_preserved = 55L,
  transport_failures_repaired = 25L,
  combined_candidates = nrow(ranked),
  targeted_cells = nrow(cell_winners),
  mixed_metric_envelope_cells = length(unique(paste(
    candidates$model_variant[as_bool(candidates$metric_source_mixed)],
    candidates$family[as_bool(candidates$metric_source_mixed)],
    tau_key(candidates$tau[as_bool(candidates$metric_source_mixed)]),
    sep = "\r"
  ))),
  primary_metric_improved_cells = sum(cell_winners$primary_ratio_to_current < 1),
  metricwise_improved_metrics = sum(metricwise$improvement_pct > 0),
  metricwise_improvement_candidates = length(unique(
    metricwise$best_candidate_spec_id[metricwise$improvement_pct > 0]
  )),
  all_three_no_regression_cells = sum(cell_winners$all_three_no_regression),
  closest_balanced_within_five_pct_cells = sum(closest_balanced$worst_ratio_to_current <= 1.05),
  full_confirmation_handoff_cells = nrow(confirmation_handoff),
  unresolved_cells = nrow(unresolved),
  unexpected_heavy_artifacts = nrow(storage_audit),
  recommendation = recommendation,
  article_update_ready = FALSE,
  stringsAsFactors = FALSE
)
summary_path <- write_csv(summary, file.path(output_root, paste0(closeout_id, "_summary.csv")))
paths <- c(paths, summary = summary_path)

readme <- c(
  "# Q-DESN MCMC Metric-Gap v3 Combined Closeout",
  "",
  sprintf("- generated_at: `%s`", as.character(Sys.time())),
  sprintf("- recommendation: `%s`", recommendation),
  "- scope: independent Q-DESN/exQ-DESN validation only",
  "- article status: unchanged; reduced-budget screening cannot be article-facing",
  "",
  "## Evidence",
  "",
  "- The original campaign contributes its 55 metric-complete successful roots.",
  "- The repair contributes exactly the 25 roots invalidated by JSON precision loss.",
  "- The combined ledger contains one row for every frozen 80-spec target.",
  "- No original successful root was recomputed or overwritten.",
  "",
  "## Selection",
  "",
  "- Ranking is family-, quantile-, and likelihood-specific; there is no global DESN winner.",
  "- Diagnostic grades are retained but do not suppress metric evidence at screening budget.",
  sprintf(
    "- The frozen comparator is a mixed-source metric envelope in %d of %d targeted cells.",
    summary$mixed_metric_envelope_cells,
    summary$targeted_cells
  ),
  "- A full-confirmation handoff requires at least 0.5% primary-metric improvement and no",
  "  fit RMSE, H=1000 forecast MAE, or H=1000 forecast check-loss regression above 1%.",
  "- Full confirmation remains a separate 5,000 burn-in + 20,000 sample approval gate.",
  "",
  sprintf("- targeted cells: `%d`", nrow(cell_winners)),
  sprintf("- primary-metric improved cells: `%d`", sum(cell_winners$primary_ratio_to_current < 1)),
  sprintf("- individually improved metrics: `%d`", summary$metricwise_improved_metrics),
  sprintf("- unique candidates behind those gains: `%d`", summary$metricwise_improvement_candidates),
  sprintf("- all-three no-regression cells: `%d`", sum(cell_winners$all_three_no_regression)),
  sprintf(
    "- closest-balanced candidates within 5%% of the full envelope: `%d`",
    summary$closest_balanced_within_five_pct_cells
  ),
  sprintf("- confirmation handoff cells: `%d`", nrow(confirmation_handoff)),
  sprintf("- unresolved cells: `%d`", nrow(unresolved)),
  sprintf("- unexpected heavy artifacts: `%d`", nrow(storage_audit))
)
readme_path <- file.path(output_root, "README.md")
writeLines(readme, readme_path, useBytes = TRUE)
readme_path <- normalizePath(readme_path, winslash = "/", mustWork = TRUE)
paths <- c(paths, readme = readme_path)

file_manifest <- data.frame(
  role = names(paths),
  path = unname(paths),
  sha256 = vapply(paths, sha256_file, character(1L)),
  stringsAsFactors = FALSE
)
file_manifest_path <- write_csv(file_manifest, file.path(output_root, "file_manifest.csv"))
manifest <- list(
  closeout_id = closeout_id,
  generated_at = as.character(Sys.time()),
  git_branch = trimws(system("git branch --show-current", intern = TRUE)),
  git_commit = trimws(system("git rev-parse HEAD", intern = TRUE)),
  original_report_root = original_report_root,
  repair_report_root = repair_report_root,
  source_registry_hash = unique(candidates$source_registry_hash_value),
  selection_policy = list(
    unit = "family_tau_likelihood",
    global_winner = FALSE,
    status_agnostic_screening_metrics = TRUE,
    diagnostics_retained = TRUE,
    primary_improvement_minimum = 0.005,
    secondary_metric_regression_tolerance = 0.01
  ),
  summary = as.list(summary[1L, , drop = FALSE]),
  source_manifest = source_manifest,
  file_manifest_path = file_manifest_path,
  article_gate = "closed_pending_full_budget_per_cell_confirmation"
)
manifest_path <- write_json(
  manifest,
  file.path(output_root, paste0(closeout_id, "_manifest.json"))
)

cat(sprintf("closeout_id: %s\n", closeout_id))
cat(sprintf("combined_candidates: %d\n", nrow(ranked)))
cat(sprintf("full_confirmation_handoff_cells: %d\n", nrow(confirmation_handoff)))
cat(sprintf("unresolved_cells: %d\n", nrow(unresolved)))
cat(sprintf("recommendation: %s\n", recommendation))
cat(sprintf("manifest: %s\n", manifest_path))

#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  required <- c("jsonlite", "yaml")
  missing <- setdiff(required, rownames(installed.packages()))
  if (length(missing)) stop(sprintf("Missing package(s): %s", paste(missing, collapse = ", ")), call. = FALSE)
})

args <- commandArgs(trailingOnly = TRUE)
get_arg <- function(flag, default = NULL) {
  idx <- which(args == flag)
  if (!length(idx) || idx[[1L]] >= length(args)) return(default)
  args[[idx[[1L]] + 1L]]
}
`%||%` <- function(x, y) if (is.null(x) || !length(x)) y else x

repo_root <- normalizePath(system("git rev-parse --show-toplevel", intern = TRUE), winslash = "/", mustWork = TRUE)
setwd(repo_root)
source(file.path(repo_root, "validation", "fitforecast_v2", "R", "qdesn_alpha_rho_cellwise_v2.R"))
resolve_path <- function(path, must_work = TRUE) {
  path <- as.character(path)[1L]
  if (!grepl("^/", path)) path <- file.path(repo_root, path)
  normalizePath(path, winslash = "/", mustWork = isTRUE(must_work))
}
read_csv <- function(path) utils::read.csv(resolve_path(path), check.names = FALSE, stringsAsFactors = FALSE)
write_csv <- function(x, path) {
  path <- resolve_path(path, FALSE)
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(x, path, row.names = FALSE, na = "")
  normalizePath(path, winslash = "/", mustWork = TRUE)
}
write_json <- function(x, path) {
  path <- resolve_path(path, FALSE)
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  jsonlite::write_json(x, path, pretty = TRUE, auto_unbox = TRUE, null = "null", digits = NA)
  normalizePath(path, winslash = "/", mustWork = TRUE)
}
finite_median <- function(x) {
  x <- as.numeric(x); x <- x[is.finite(x)]
  if (length(x)) stats::median(x) else NA_real_
}
finite_q90 <- function(x) {
  x <- as.numeric(x); x <- x[is.finite(x)]
  if (length(x)) unname(stats::quantile(x, 0.90, names = FALSE, type = 8)) else NA_real_
}

stage_stub <- "qdesn_dynamic_fitforecast_v2_500obs_alpha_rho_cellwise_v2"
config_stub <- file.path("config", "validation", stage_stub)
phase <- tolower(as.character(get_arg("--phase", "coarse"))[1L])
if (!phase %in% c("coarse", "refinement")) stop("--phase must be coarse or refinement.", call. = FALSE)
run_tag <- as.character(get_arg("--run-tag", ""))[1L]
if (!nzchar(run_tag)) stop("--run-tag is required.", call. = FALSE)
coarse_audit_root <- as.character(get_arg("--coarse-audit-root", ""))[1L]

profiles <- read_csv(paste0(config_stub, "_profiles.csv"))
manifest <- jsonlite::read_json(resolve_path(paste0(config_stub, "_materialization_manifest.json")), simplifyVector = TRUE)
baseline_metrics <- read_csv(manifest$predecessor$baseline_metrics_path)
baseline_metrics <- baseline_metrics[baseline_metrics$arm_code == "parent_exact", , drop = FALSE]
baseline_keep <- c(
  "target_cell_id", "source_scenario", "reservoir_replicate",
  "metric_fit_rmse", "metric_forecast_mae", "metric_forecast_check", "spec_id"
)
baseline_metrics <- baseline_metrics[, baseline_keep, drop = FALSE]
names(baseline_metrics) <- sub("^metric_", "baseline_", names(baseline_metrics))
names(baseline_metrics)[names(baseline_metrics) == "spec_id"] <- "baseline_spec_id"

if (phase == "coarse") {
  defaults_path <- resolve_path(paste0(config_stub, "_coarse_defaults.yaml"))
  specs_path <- resolve_path(paste0(config_stub, "_coarse_target_spec_ids.csv"))
} else {
  if (!nzchar(coarse_audit_root)) stop("Refinement audit requires --coarse-audit-root.", call. = FALSE)
  coarse_audit_root <- resolve_path(coarse_audit_root)
  defaults_path <- file.path(coarse_audit_root, "refinement_defaults.yaml")
  specs_path <- file.path(coarse_audit_root, "refinement_target_spec_ids.csv")
}
defaults <- yaml::read_yaml(defaults_path)
expected <- read_csv(specs_path)
run_root <- resolve_path(file.path(defaults$campaign$results_root, run_tag), FALSE)
if (!dir.exists(run_root)) stop(sprintf("Run root does not exist: %s", run_root), call. = FALSE)
output_root <- resolve_path(get_arg(
  "--output-root",
  file.path("reports", "qdesn_mcmc_validation", paste0(stage_stub, "_", phase), run_tag, "cellwise_audit")
), FALSE)
dir.create(output_root, recursive = TRUE, showWarnings = FALSE)

fit_paths <- list.files(run_root, pattern = "^fit_summary_row[.]csv$", recursive = TRUE, full.names = TRUE)
fit_rows <- lapply(fit_paths, function(path) {
  row <- tryCatch(utils::read.csv(path, check.names = FALSE, stringsAsFactors = FALSE), error = function(e) NULL)
  if (is.null(row) || !nrow(row)) return(NULL)
  row <- row[1L, , drop = FALSE]
  method_dir <- dirname(path)
  horizon_path <- file.path(method_dir, "tables", "forecast_horizon_summary.csv")
  horizon <- if (file.exists(horizon_path)) {
    tryCatch(utils::read.csv(horizon_path, check.names = FALSE, stringsAsFactors = FALSE), error = function(e) NULL)
  } else NULL
  h1000 <- if (!is.null(horizon) && nrow(horizon)) {
    pick <- which(as.integer(horizon$horizon) == 1000L | as.character(horizon$window) == "forecast_H1000")
    if (length(pick)) horizon[pick[[1L]], , drop = FALSE] else NULL
  } else NULL
  row$fit_summary_path <- normalizePath(path, winslash = "/", mustWork = TRUE)
  row$fit_summary_sha256 <- unname(tools::sha256sum(path))
  row$forecast_horizon_path <- if (file.exists(horizon_path)) normalizePath(horizon_path, winslash = "/", mustWork = TRUE) else NA_character_
  row$forecast_horizon_sha256 <- if (file.exists(horizon_path)) unname(tools::sha256sum(horizon_path)) else NA_character_
  row$metric_fit_rmse <- suppressWarnings(as.numeric(row$train_qtrue_rmse[[1L]] %||% NA_real_))
  row$metric_forecast_mae <- if (!is.null(h1000)) suppressWarnings(as.numeric(h1000$qtrue_mae[[1L]])) else NA_real_
  row$metric_forecast_check <- if (!is.null(h1000)) suppressWarnings(as.numeric(h1000$pinball_tau[[1L]])) else NA_real_
  row$metric_complete <- all(is.finite(c(row$metric_fit_rmse, row$metric_forecast_mae, row$metric_forecast_check)))
  row
})
fit_rows <- Filter(Negate(is.null), fit_rows)
metrics <- if (length(fit_rows)) do.call(rbind, fit_rows) else data.frame(stringsAsFactors = FALSE)
profile_cols <- c(
  "screening_profile_id", "candidate_id", "target_cell_id", "target_role",
  "likelihood_target", "target_family", "target_tau", "parent_profile_id",
  "search_id", "search_dimension", "search_priority", "topology_mode",
  "reservoir_replicate", "alpha", "rho", "pi_w", "pi_in", "seed"
)
if (nrow(metrics)) {
  metrics <- merge(metrics, profiles[, profile_cols, drop = FALSE], by = "screening_profile_id", all.x = TRUE, sort = FALSE)
  if (!"source_scenario" %in% names(metrics) && "scenario" %in% names(metrics)) {
    metrics$source_scenario <- as.character(metrics$scenario)
  }
  metrics <- metrics[!duplicated(metrics$spec_id), , drop = FALSE]
}
expected_ids <- unique(as.character(expected$spec_id))
observed_ids <- if (nrow(metrics)) unique(as.character(metrics$spec_id)) else character()
missing_ids <- setdiff(expected_ids, observed_ids)
unexpected_ids <- setdiff(observed_ids, expected_ids)
write_csv(data.frame(spec_id = missing_ids), file.path(output_root, "missing_spec_ids.csv"))
write_csv(data.frame(spec_id = unexpected_ids), file.path(output_root, "unexpected_spec_ids.csv"))
metrics_path <- write_csv(metrics, file.path(output_root, paste0(phase, "_metrics.csv")))
phase_metrics <- metrics

if (phase == "refinement") {
  coarse_metrics <- read_csv(file.path(coarse_audit_root, "coarse_metrics.csv"))
  candidate_ids <- unique(as.character(expected$candidate_id))
  coarse_metrics <- coarse_metrics[coarse_metrics$candidate_id %in% candidate_ids, , drop = FALSE]
  metrics <- rbind(coarse_metrics[, intersect(names(coarse_metrics), names(metrics)), drop = FALSE], metrics[, intersect(names(coarse_metrics), names(metrics)), drop = FALSE])
  metrics_path <- write_csv(metrics, file.path(output_root, "refinement_combined_metrics.csv"))
}

paired <- merge(
  metrics, baseline_metrics,
  by = c("target_cell_id", "source_scenario", "reservoir_replicate"),
  all.x = TRUE, sort = FALSE
)
ratio <- function(x, y) ifelse(is.finite(x) & is.finite(y) & y > 0, x / y, NA_real_)
paired$fit_ratio <- ratio(paired$metric_fit_rmse, paired$baseline_fit_rmse)
paired$forecast_mae_ratio <- ratio(paired$metric_forecast_mae, paired$baseline_forecast_mae)
paired$forecast_check_ratio <- ratio(paired$metric_forecast_check, paired$baseline_forecast_check)
paired$pair_complete <- is.finite(paired$fit_ratio) & is.finite(paired$forecast_mae_ratio) & is.finite(paired$forecast_check_ratio)
paired_path <- write_csv(paired, file.path(output_root, paste0(phase, "_paired_metrics.csv")))

groups <- split(seq_len(nrow(paired)), paste(paired$target_cell_id, paired$candidate_id, sep = "\r"))
aggregate_rows <- lapply(groups, function(idx) {
  x <- paired[idx, , drop = FALSE]
  med <- c(
    fit = finite_median(x$fit_ratio),
    forecast_mae = finite_median(x$forecast_mae_ratio),
    forecast_check = finite_median(x$forecast_check_ratio)
  )
  q90 <- c(
    fit = finite_q90(x$fit_ratio),
    forecast_mae = finite_q90(x$forecast_mae_ratio),
    forecast_check = finite_q90(x$forecast_check_ratio)
  )
  data.frame(
    target_cell_id = x$target_cell_id[[1L]],
    target_role = x$target_role[[1L]],
    likelihood_target = x$likelihood_target[[1L]],
    target_family = x$target_family[[1L]],
    target_tau = as.numeric(x$target_tau[[1L]]),
    candidate_id = x$candidate_id[[1L]],
    search_id = x$search_id[[1L]],
    search_dimension = x$search_dimension[[1L]],
    search_priority = x$search_priority[[1L]],
    topology_mode = x$topology_mode[[1L]],
    alpha = as.numeric(x$alpha[[1L]]),
    rho = as.numeric(x$rho[[1L]]),
    pi_w = as.numeric(x$pi_w[[1L]]),
    pi_in = as.numeric(x$pi_in[[1L]]),
    n_expected_pairs = if (phase == "coarse") 3L else 6L,
    n_complete_pairs = sum(x$pair_complete, na.rm = TRUE),
    median_fit_ratio = med[["fit"]],
    median_forecast_mae_ratio = med[["forecast_mae"]],
    median_forecast_check_ratio = med[["forecast_check"]],
    worst_median_ratio = if (all(is.finite(med))) max(med) else NA_real_,
    mean_median_ratio = if (all(is.finite(med))) mean(med) else NA_real_,
    q90_fit_ratio = q90[["fit"]],
    q90_forecast_mae_ratio = q90[["forecast_mae"]],
    q90_forecast_check_ratio = q90[["forecast_check"]],
    worst_q90_ratio = if (all(is.finite(q90))) max(q90) else NA_real_,
    stringsAsFactors = FALSE
  )
})
summary <- if (length(aggregate_rows)) do.call(rbind, aggregate_rows) else data.frame(stringsAsFactors = FALSE)
summary <- summary[order(summary$target_cell_id, summary$worst_median_ratio, summary$candidate_id), , drop = FALSE]
summary_path <- write_csv(summary, file.path(output_root, paste0(phase, "_candidate_summary.csv")))

complete_metric_specs <- if (nrow(phase_metrics)) sum(as.logical(phase_metrics$metric_complete), na.rm = TRUE) else 0L
completion_fraction <- if (length(expected_ids)) complete_metric_specs / length(expected_ids) else 0
decision <- ""
decision_reason <- ""
selected <- data.frame(stringsAsFactors = FALSE)
dynamic_paths <- list()

if (completion_fraction < 0.95) {
  decision <- "BLOCK_INCOMPLETE"
  decision_reason <- sprintf("Only %.1f%% of expected specs have complete metrics.", 100 * completion_fraction)
} else if (phase == "coarse") {
  selected <- qdesn_arv2_select_objective_candidates(summary, max_per_cell = 4L)
  if (!nrow(selected)) {
    decision <- "STOP_NO_CANDIDATE"
    decision_reason <- "No coarse candidate passed the paired per-cell guardrails."
  } else {
    universe_grid <- read_csv(paste0(config_stub, "_refinement_universe_grid.csv"))
    universe_specs <- read_csv(paste0(config_stub, "_refinement_universe_target_spec_ids.csv"))
    selected_ids <- unique(as.character(selected$candidate_id))
    refinement_grid <- universe_grid[universe_grid$candidate_id %in% selected_ids, , drop = FALSE]
    refinement_specs <- universe_specs[universe_specs$candidate_id %in% selected_ids, , drop = FALSE]
    expected_refinement <- length(selected_ids) * 3L
    if (nrow(refinement_grid) != expected_refinement || nrow(refinement_specs) != expected_refinement) {
      stop(sprintf("Dynamic refinement count mismatch: grid=%d specs=%d expected=%d.", nrow(refinement_grid), nrow(refinement_specs), expected_refinement), call. = FALSE)
    }
    selected_path <- write_csv(selected, file.path(output_root, "coarse_selected_candidates.csv"))
    refinement_grid_path <- write_csv(refinement_grid, file.path(output_root, "refinement_grid.csv"))
    refinement_specs_path <- write_csv(refinement_specs, file.path(output_root, "refinement_target_spec_ids.csv"))
    refinement_defaults <- yaml::read_yaml(resolve_path(paste0(config_stub, "_refinement_universe_defaults.yaml")))
    refinement_defaults$campaign$name <- paste0(stage_stub, "_refinement")
    refinement_defaults$campaign$results_root <- file.path("results", "qdesn_mcmc_validation", paste0(stage_stub, "_refinement"))
    refinement_defaults$campaign$reports_root <- file.path("reports", "qdesn_mcmc_validation", paste0(stage_stub, "_refinement"))
    refinement_defaults$execution$allowed_fit_spec_ids <- as.list(as.character(refinement_specs$spec_id))
    refinement_defaults$reference_contract$expected_selected_qdesn_roots <- nrow(refinement_grid)
    refinement_defaults$screening_profiles$selected_assignment_root_count <- nrow(refinement_grid)
    refinement_defaults$study_contract$active_phase <- "refinement"
    refinement_defaults$study_contract$coarse_run_tag <- run_tag
    refinement_defaults$study_contract$coarse_selected_candidates_path <- selected_path
    first_profile <- profiles[profiles$screening_profile_id == refinement_grid$screening_profile_id[[1L]], , drop = FALSE]
    refinement_defaults$smoke$scenario <- refinement_grid$source_scenario[[1L]]
    refinement_defaults$smoke$family <- first_profile$target_family[[1L]]
    refinement_defaults$smoke$tau <- as.numeric(first_profile$target_tau[[1L]])
    refinement_defaults$smoke$screening_profile_ids <- as.list(first_profile$screening_profile_id[[1L]])
    refinement_defaults_path <- file.path(output_root, "refinement_defaults.yaml")
    yaml::write_yaml(refinement_defaults, refinement_defaults_path)
    dynamic_manifest <- list(
      generated_at = as.character(Sys.time()),
      coarse_run_tag = run_tag,
      selected_candidate_count = length(selected_ids),
      selected_candidates_path = selected_path,
      selected_candidates_sha256 = unname(tools::sha256sum(selected_path)),
      refinement_defaults_path = normalizePath(refinement_defaults_path, winslash = "/", mustWork = TRUE),
      refinement_defaults_sha256 = unname(tools::sha256sum(refinement_defaults_path)),
      refinement_grid_path = refinement_grid_path,
      refinement_grid_sha256 = unname(tools::sha256sum(refinement_grid_path)),
      refinement_target_spec_ids_path = refinement_specs_path,
      refinement_target_spec_ids_sha256 = unname(tools::sha256sum(refinement_specs_path)),
      expected_specs = nrow(refinement_specs)
    )
    dynamic_manifest_path <- write_json(dynamic_manifest, file.path(output_root, "refinement_selection_manifest.json"))
    dynamic_paths <- list(
      selected_candidates_path = selected_path,
      refinement_defaults_path = normalizePath(refinement_defaults_path, winslash = "/", mustWork = TRUE),
      refinement_grid_path = refinement_grid_path,
      refinement_target_spec_ids_path = refinement_specs_path,
      refinement_selection_manifest_path = dynamic_manifest_path,
      expected_refinement_specs = nrow(refinement_specs)
    )
    decision <- "GO_REFINEMENT"
    decision_reason <- sprintf("%d objective-specific candidates across %d cells passed the coarse gate.", length(selected_ids), length(unique(selected$target_cell_id)))
  }
} else {
  eligible <- summary[
    summary$n_complete_pairs >= 5L &
      summary$worst_median_ratio <= 1.03 &
      summary$worst_q90_ratio <= 1.25 &
      pmin(summary$median_fit_ratio, summary$median_forecast_mae_ratio, summary$median_forecast_check_ratio, na.rm = TRUE) <= 0.98,
    , drop = FALSE
  ]
  if (nrow(eligible)) {
    selected <- qdesn_arv2_select_objective_candidates(eligible, max_per_cell = 4L)
    decision <- "CANDIDATES_FOR_FULL_CONFIRMATION"
    decision_reason <- sprintf("%d cell-specific candidates passed two-reservoir development confirmation.", nrow(selected))
  } else {
    decision <- "NO_REFINEMENT_CANDIDATE"
    decision_reason <- "No candidate remained competitive across both reservoir seeds."
  }
}

finalists_path <- write_csv(selected, file.path(output_root, paste0(phase, "_full_confirmation_candidates.csv")))
gate <- c(list(
  generated_at = as.character(Sys.time()),
  phase = phase,
  run_tag = run_tag,
  decision = decision,
  decision_reason = decision_reason,
  expected_specs = length(expected_ids),
  observed_fit_summaries = length(observed_ids),
  complete_metric_specs = complete_metric_specs,
  completion_fraction = completion_fraction,
  missing_specs = length(missing_ids),
  unexpected_specs = length(unexpected_ids),
  metrics_path = metrics_path,
  paired_metrics_path = paired_path,
  candidate_summary_path = summary_path,
  finalists_path = finalists_path,
  baseline_metrics_path = manifest$predecessor$baseline_metrics_path,
  baseline_metrics_sha256 = manifest$predecessor$baseline_metrics_sha256
), dynamic_paths)
gate_path <- write_json(gate, file.path(output_root, paste0(phase, "_gate.json")))

readme <- c(
  "# Q-DESN Alpha/Rho Cellwise v2 Audit",
  "",
  sprintf("- phase: `%s`", phase),
  sprintf("- run_tag: `%s`", run_tag),
  sprintf("- decision: `%s`", decision),
  sprintf("- reason: %s", decision_reason),
  sprintf("- expected specs: `%d`", length(expected_ids)),
  sprintf("- complete metric specs: `%d` (%.1f%%)", complete_metric_specs, 100 * completion_fraction),
  sprintf("- missing specs: `%d`", length(missing_ids)),
  "",
  "Candidates are paired to the exact parent on the same development source and reservoir seed.",
  "Selection is cell-specific and objective-specific; no global specification is computed.",
  "Fit RMSE and H=1000 rolling-origin forecast MAE/check loss are all minimized.",
  "No result is article-authoritative without a later full-budget frozen-source confirmation."
)
writeLines(readme, file.path(output_root, "README.md"))
cat(sprintf("Decision: %s\n", decision))
cat(sprintf("Complete metrics: %d/%d (%.1f%%)\n", complete_metric_specs, length(expected_ids), 100 * completion_fraction))
cat(sprintf("Gate: %s\n", gate_path))

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
read_env <- function(path) {
  if (!file.exists(path)) return(character())
  lines <- readLines(path, warn = FALSE)
  lines <- lines[grepl("^[A-Z0-9_]+=", lines)]
  out <- sub("^[^=]+=", "", lines)
  names(out) <- sub("=.*$", "", lines)
  out
}
finite_median <- function(x) {
  x <- as.numeric(x)
  x <- x[is.finite(x)]
  if (length(x)) stats::median(x) else NA_real_
}
finite_q90 <- function(x) {
  x <- as.numeric(x)
  x <- x[is.finite(x)]
  if (length(x)) unname(stats::quantile(x, 0.90, names = FALSE, type = 8)) else NA_real_
}
safe_ratio <- function(x, y) ifelse(is.finite(x) & is.finite(y) & y > 0, x / y, NA_real_)

stage <- "qdesn_dynamic_fitforecast_v2_500obs_mcmc_highalpha_cellwise_v1"
stub <- file.path("config", "validation", stage)
profiles <- read_csv(paste0(stub, "_wave1_profiles.csv"))
expected <- read_csv(paste0(stub, "_wave1_target_spec_ids.csv"))
defaults <- yaml::read_yaml(resolve_path(paste0(stub, "_wave1_defaults.yaml")))
state_root_arg <- as.character(get_arg("--state-root", ""))[1L]
state_root <- if (nzchar(state_root_arg)) resolve_path(state_root_arg) else NULL
env <- if (!is.null(state_root)) read_env(file.path(state_root, "run_tags.env")) else character()
run_tag <- as.character(get_arg("--run-tag", unname(env[["WAVE1_RUN_TAG"]] %||% "")))[1L]
if (!nzchar(run_tag)) stop("A Wave 1 run tag is required.", call. = FALSE)
output_root <- resolve_path(get_arg(
  "--output-root",
  if (!is.null(state_root)) file.path(state_root, "closeout") else file.path("reports", "qdesn_mcmc_validation", stage, "manual_closeout")
), FALSE)
dir.create(output_root, recursive = TRUE, showWarnings = FALSE)
run_root <- resolve_path(file.path(defaults$campaign$results_root, run_tag), FALSE)

fit_paths <- if (dir.exists(run_root)) {
  list.files(run_root, pattern = "^fit_summary_row[.]csv$", recursive = TRUE, full.names = TRUE)
} else character()
metric_rows <- lapply(fit_paths, function(path) {
  fit <- tryCatch(utils::read.csv(path, check.names = FALSE, stringsAsFactors = FALSE), error = function(e) NULL)
  if (is.null(fit) || !nrow(fit)) return(NULL)
  fit <- fit[1L, , drop = FALSE]
  horizon_path <- file.path(dirname(path), "tables", "forecast_horizon_summary.csv")
  horizon <- if (file.exists(horizon_path)) {
    tryCatch(utils::read.csv(horizon_path, check.names = FALSE, stringsAsFactors = FALSE), error = function(e) NULL)
  } else NULL
  h1000 <- NULL
  if (!is.null(horizon) && nrow(horizon)) {
    idx <- which(as.integer(horizon$horizon) == 1000L | as.character(horizon$window) == "forecast_H1000")
    if (length(idx)) h1000 <- horizon[idx[[1L]], , drop = FALSE]
  }
  fit$run_tag <- run_tag
  fit$fit_summary_path <- normalizePath(path, winslash = "/", mustWork = TRUE)
  fit$fit_summary_sha256 <- unname(tools::sha256sum(path))
  fit$forecast_horizon_path <- if (file.exists(horizon_path)) normalizePath(horizon_path, winslash = "/", mustWork = TRUE) else NA_character_
  fit$forecast_horizon_sha256 <- if (file.exists(horizon_path)) unname(tools::sha256sum(horizon_path)) else NA_character_
  fit$metric_fit_rmse <- suppressWarnings(as.numeric(fit$train_qtrue_rmse[[1L]] %||% NA_real_))
  fit$metric_forecast_mae <- if (!is.null(h1000)) suppressWarnings(as.numeric(h1000$qtrue_mae[[1L]])) else NA_real_
  fit$metric_forecast_check <- if (!is.null(h1000)) suppressWarnings(as.numeric(h1000$pinball_tau[[1L]])) else NA_real_
  fit$metric_complete <- all(is.finite(c(fit$metric_fit_rmse, fit$metric_forecast_mae, fit$metric_forecast_check)))
  fit
})
metric_rows <- Filter(Negate(is.null), metric_rows)
metrics <- if (length(metric_rows)) do.call(rbind, metric_rows) else data.frame(stringsAsFactors = FALSE)
if (nrow(metrics)) metrics <- metrics[!duplicated(metrics$spec_id), , drop = FALSE]
expected_ids <- unique(as.character(expected$spec_id))
observed_ids <- if (nrow(metrics)) unique(as.character(metrics$spec_id)) else character()
missing <- data.frame(spec_id = setdiff(expected_ids, observed_ids), stringsAsFactors = FALSE)

heavy_paths <- if (dir.exists(run_root)) {
  list.files(run_root, pattern = "[.](rds|rda|RData)$", recursive = TRUE, full.names = TRUE, ignore.case = TRUE)
} else character()
heavy <- if (length(heavy_paths)) data.frame(
  path = normalizePath(heavy_paths, winslash = "/", mustWork = TRUE),
  bytes = as.numeric(file.info(heavy_paths)$size),
  stringsAsFactors = FALSE
) else data.frame(path = character(), bytes = numeric())

profile_keep <- c(
  "screening_profile_id", "target_cell_id", "target_metrics", "likelihood_target",
  "target_family", "target_tau", "parent_profile_id", "parent_candidate_id",
  "candidate_id", "arm_code", "design_role", "topology_search_mode",
  "topology_mode", "reservoir_replicate", "paired_reservoir_seed", "D",
  "n_each", "m", "alpha", "rho", "pi_w", "pi_in", "rhs_tau0"
)
if (nrow(metrics)) {
  profile_join_keep <- c(
    "screening_profile_id",
    setdiff(profile_keep, c("screening_profile_id", names(metrics)))
  )
  metrics <- merge(
    metrics,
    profiles[, profile_join_keep, drop = FALSE],
    by = "screening_profile_id",
    all.x = TRUE,
    sort = FALSE
  )
  if (!"source_scenario" %in% names(metrics) && "scenario" %in% names(metrics)) metrics$source_scenario <- metrics$scenario
}
metrics_path <- write_csv(metrics, file.path(output_root, "wave1_metrics.csv"))
missing_path <- write_csv(missing, file.path(output_root, "missing_spec_ids.csv"))
heavy_path <- write_csv(heavy, file.path(output_root, "storage_heavy_artifact_audit.csv"))

baseline <- if (nrow(metrics)) metrics[metrics$arm_code == "parent_exact", , drop = FALSE] else metrics
baseline_keep <- c(
  "target_cell_id", "source_scenario", "reservoir_replicate",
  "metric_fit_rmse", "metric_forecast_mae", "metric_forecast_check", "spec_id"
)
baseline <- baseline[, baseline_keep, drop = FALSE]
names(baseline) <- sub("^metric_", "baseline_", names(baseline))
names(baseline)[names(baseline) == "spec_id"] <- "baseline_spec_id"
paired <- merge(
  metrics, baseline,
  by = c("target_cell_id", "source_scenario", "reservoir_replicate"),
  all.x = TRUE, sort = FALSE
)
paired$fit_ratio <- safe_ratio(paired$metric_fit_rmse, paired$baseline_fit_rmse)
paired$forecast_mae_ratio <- safe_ratio(paired$metric_forecast_mae, paired$baseline_forecast_mae)
paired$forecast_check_ratio <- safe_ratio(paired$metric_forecast_check, paired$baseline_forecast_check)
paired$pair_complete <- is.finite(paired$fit_ratio) & is.finite(paired$forecast_mae_ratio) & is.finite(paired$forecast_check_ratio)
paired_path <- write_csv(paired, file.path(output_root, "paired_candidate_parent_metrics.csv"))

group_key <- paste(paired$target_cell_id, paired$candidate_id, sep = "\r")
summary_rows <- lapply(split(seq_len(nrow(paired)), group_key), function(idx) {
  x <- paired[idx, , drop = FALSE]
  med <- c(
    fit_qtrue_rmse = finite_median(x$fit_ratio),
    forecast_qtrue_mae_H1000 = finite_median(x$forecast_mae_ratio),
    forecast_check_loss_H1000 = finite_median(x$forecast_check_ratio)
  )
  q90 <- c(
    fit_qtrue_rmse = finite_q90(x$fit_ratio),
    forecast_qtrue_mae_H1000 = finite_q90(x$forecast_mae_ratio),
    forecast_check_loss_H1000 = finite_q90(x$forecast_check_ratio)
  )
  targets <- strsplit(as.character(x$target_metrics[[1L]]), ";", fixed = TRUE)[[1L]]
  target_idx <- names(med) %in% targets
  data.frame(
    target_cell_id = x$target_cell_id[[1L]],
    target_metrics = x$target_metrics[[1L]],
    likelihood_target = x$likelihood_target[[1L]],
    target_family = x$target_family[[1L]],
    target_tau = as.numeric(x$target_tau[[1L]]),
    candidate_id = x$candidate_id[[1L]],
    arm_code = x$arm_code[[1L]],
    design_role = x$design_role[[1L]],
    topology_search_mode = x$topology_search_mode[[1L]],
    D = as.integer(x$D[[1L]]),
    n_each = as.integer(x$n_each[[1L]]),
    m = as.integer(x$m[[1L]]),
    alpha = as.numeric(x$alpha[[1L]]),
    rho = as.numeric(x$rho[[1L]]),
    pi_w = as.numeric(x$pi_w[[1L]]),
    pi_in = as.numeric(x$pi_in[[1L]]),
    rhs_tau0 = as.numeric(x$rhs_tau0[[1L]]),
    n_expected_pairs = 6L,
    n_complete_pairs = sum(x$pair_complete, na.rm = TRUE),
    median_fit_ratio = med[["fit_qtrue_rmse"]],
    median_forecast_mae_ratio = med[["forecast_qtrue_mae_H1000"]],
    median_forecast_check_ratio = med[["forecast_check_loss_H1000"]],
    worst_target_median_ratio = if (any(target_idx) && all(is.finite(med[target_idx]))) max(med[target_idx]) else NA_real_,
    worst_companion_median_ratio = if (any(!target_idx) && all(is.finite(med[!target_idx]))) max(med[!target_idx]) else NA_real_,
    mean_target_median_ratio = if (any(target_idx) && all(is.finite(med[target_idx]))) mean(med[target_idx]) else NA_real_,
    worst_target_q90_ratio = if (any(target_idx) && all(is.finite(q90[target_idx]))) max(q90[target_idx]) else NA_real_,
    stringsAsFactors = FALSE
  )
})
summary <- if (length(summary_rows)) do.call(rbind, summary_rows) else data.frame(stringsAsFactors = FALSE)
if (nrow(summary)) {
  summary$discovery_eligible <- !summary$arm_code %in% "parent_exact" &
    summary$n_complete_pairs >= 5L &
    summary$worst_target_median_ratio <= 0.98 &
    summary$worst_companion_median_ratio <= 1.05 &
    summary$worst_target_q90_ratio <= 1.10
  summary <- summary[order(
    summary$target_cell_id, !summary$discovery_eligible,
    summary$worst_target_median_ratio, summary$mean_target_median_ratio,
    summary$candidate_id
  ), , drop = FALSE]
}
summary_path <- write_csv(summary, file.path(output_root, "candidate_summary.csv"))
eligible <- if (nrow(summary)) summary[as.logical(summary$discovery_eligible), , drop = FALSE] else summary
finalists <- if (nrow(eligible)) {
  do.call(rbind, lapply(split(seq_len(nrow(eligible)), eligible$target_cell_id), function(idx) {
    x <- eligible[idx, , drop = FALSE]
    x[order(x$worst_target_median_ratio, x$mean_target_median_ratio, x$candidate_id), , drop = FALSE][seq_len(min(2L, nrow(x))), , drop = FALSE]
  }))
} else data.frame(stringsAsFactors = FALSE)
finalists_path <- write_csv(finalists, file.path(output_root, "full_budget_confirmation_candidates.csv"))

expected_total <- length(expected_ids)
complete_total <- if (nrow(metrics)) sum(as.logical(metrics$metric_complete), na.rm = TRUE) else 0L
completion_fraction <- if (expected_total) complete_total / expected_total else 0
wave1_cells <- sort(unique(profiles$target_cell_id))
covered_cells <- sort(unique(as.character(finalists$target_cell_id %||% character())))
if (completion_fraction < 1 || nrow(missing) > 0L) {
  decision <- "BLOCK_INCOMPLETE"
  reason <- sprintf("Only %d/%d Wave 1 specs have complete metrics.", complete_total, expected_total)
} else if (length(setdiff(wave1_cells, covered_cells)) == 0L) {
  decision <- "GO_FULL_CONFIRMATION_CANDIDATES"
  reason <- "Every Wave 1 cell has at least one candidate passing the paired target and stability gates."
} else if (length(covered_cells)) {
  decision <- "PARTIAL_SIGNAL_CASE_SPECIFIC_FOLLOWUP"
  reason <- sprintf("Candidates passed in %d/%d Wave 1 cells.", length(covered_cells), length(wave1_cells))
} else {
  decision <- "STOP_NO_HIGHALPHA_SIGNAL"
  reason <- "No high-alpha candidate passed the paired case-specific discovery gate."
}

gate <- list(
  generated_at = as.character(Sys.time()),
  decision = decision,
  decision_reason = reason,
  run_tag = run_tag,
  run_root = run_root,
  expected_specs = expected_total,
  complete_metric_specs = complete_total,
  completion_fraction = completion_fraction,
  missing_specs = nrow(missing),
  heavy_payloads = nrow(heavy),
  wave1_cells = as.list(wave1_cells),
  cells_with_candidate = as.list(covered_cells),
  article_update_allowed = FALSE,
  wave2_launch_allowed = identical(decision, "GO_FULL_CONFIRMATION_CANDIDATES"),
  full_confirmation_automatic = FALSE,
  next_gate = "explicit review before any Wave 2 or 5000-plus-20000 confirmation",
  metrics_path = metrics_path,
  paired_metrics_path = paired_path,
  candidate_summary_path = summary_path,
  finalists_path = finalists_path,
  storage_audit_path = heavy_path,
  missing_specs_path = missing_path
)
gate_path <- write_json(gate, file.path(output_root, "highalpha_wave1_gate.json"))
writeLines(c(
  "# Q-DESN MCMC High-Alpha Cellwise v1 Wave 1",
  "",
  sprintf("- decision: `%s`", decision),
  sprintf("- reason: %s", reason),
  sprintf("- complete target specs: `%d/%d`", complete_total, expected_total),
  sprintf("- heavy model payloads: `%d`", nrow(heavy)),
  "- article update: `not allowed from screening-budget evidence`",
  "- Wave 2/full confirmation: `never automatic`",
  "",
  "Candidates are assessed separately within each family, quantile, and likelihood cell.",
  "Every comparison is paired by fresh source trajectory and reservoir seed against the exact",
  "authoritative parent design. At least five of six pairs must be complete. Every targeted",
  "median metric must improve by at least 2%, companion medians may regress by at most 5%,",
  "and the worst targeted q90 ratio may not exceed 1.10. Diagnostic status is retained but",
  "does not silently remove finite metric evidence."
), file.path(output_root, "README.md"))

cat(sprintf("Decision: %s\n", decision))
cat(sprintf("Complete metrics: %d/%d (%.1f%%)\n", complete_total, expected_total, 100 * completion_fraction))
cat(sprintf("Candidate cells: %d/%d\n", length(covered_cells), length(wave1_cells)))
cat(sprintf("Gate: %s\n", gate_path))

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

stage_stub <- "qdesn_dynamic_fitforecast_v2_500obs_alpha_rho_topology_v1"
phase <- tolower(as.character(get_arg("--phase", "mechanism"))[1L])
if (!phase %in% c("mechanism", "broad")) stop("--phase must be mechanism or broad.", call. = FALSE)
run_tag <- as.character(get_arg("--run-tag", ""))[1L]
if (!nzchar(run_tag)) stop("--run-tag is required.", call. = FALSE)
config_stub <- file.path("config", "validation", stage_stub)
defaults_path <- resolve_path(paste0(config_stub, "_", phase, "_defaults.yaml"))
profiles_path <- resolve_path(paste0(config_stub, "_profiles.csv"))
specs_path <- resolve_path(paste0(config_stub, "_", phase, "_target_spec_ids.csv"))
defaults <- yaml::read_yaml(defaults_path)
profiles <- read_csv(profiles_path)
expected <- read_csv(specs_path)
run_root <- resolve_path(file.path(defaults$campaign$results_root, run_tag), FALSE)
if (!dir.exists(run_root)) stop(sprintf("Run root does not exist: %s", run_root), call. = FALSE)

output_root <- resolve_path(get_arg(
  "--output-root",
  file.path("reports", "qdesn_mcmc_validation", paste0(stage_stub, "_", phase), run_tag, "alpha_rho_topology_audit")
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
  } else {
    NULL
  }
  h1000 <- if (!is.null(horizon) && nrow(horizon)) {
    pick <- which(as.integer(horizon$horizon) == 1000L | as.character(horizon$window) == "forecast_H1000")
    if (length(pick)) horizon[pick[[1L]], , drop = FALSE] else NULL
  } else {
    NULL
  }
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
  "screening_profile_id", "target_cell_id", "target_role", "likelihood_target",
  "target_family", "target_tau", "parent_profile_id", "arm_index", "arm_code",
  "arm_class", "topology_mode", "reservoir_replicate", "alpha", "rho", "pi_w",
  "pi_in", "seed"
)
if (nrow(metrics)) {
  metrics <- merge(metrics, profiles[, profile_cols, drop = FALSE], by = "screening_profile_id", all.x = TRUE, sort = FALSE)
  if (!"source_scenario" %in% names(metrics) && "scenario" %in% names(metrics)) {
    metrics$source_scenario <- as.character(metrics$scenario)
  }
  metrics <- metrics[!duplicated(metrics$spec_id), , drop = FALSE]
}
expected_ids <- unique(as.character(expected$spec_id))
observed_ids <- if (nrow(metrics)) unique(as.character(metrics$spec_id)) else character(0)
missing_ids <- setdiff(expected_ids, observed_ids)
unexpected_ids <- setdiff(observed_ids, expected_ids)
missing_path <- write_csv(data.frame(spec_id = missing_ids, stringsAsFactors = FALSE), file.path(output_root, "missing_spec_ids.csv"))
unexpected_path <- write_csv(data.frame(spec_id = unexpected_ids, stringsAsFactors = FALSE), file.path(output_root, "unexpected_spec_ids.csv"))
metrics_path <- write_csv(metrics, file.path(output_root, paste0(phase, "_metrics.csv")))

baseline_path <- as.character(get_arg("--baseline-metrics", ""))[1L]
baseline_metrics <- if (phase == "mechanism") {
  metrics[metrics$arm_code == "parent_exact", , drop = FALSE]
} else {
  if (!nzchar(baseline_path)) stop("Broad audit requires --baseline-metrics from the mechanism audit.", call. = FALSE)
  base <- read_csv(baseline_path)
  base[base$arm_code == "parent_exact", , drop = FALSE]
}
baseline_keep <- c(
  "target_cell_id", "source_scenario", "reservoir_replicate",
  "metric_fit_rmse", "metric_forecast_mae", "metric_forecast_check", "spec_id"
)
baseline_metrics <- baseline_metrics[, baseline_keep, drop = FALSE]
names(baseline_metrics)[names(baseline_metrics) == "metric_fit_rmse"] <- "baseline_fit_rmse"
names(baseline_metrics)[names(baseline_metrics) == "metric_forecast_mae"] <- "baseline_forecast_mae"
names(baseline_metrics)[names(baseline_metrics) == "metric_forecast_check"] <- "baseline_forecast_check"
names(baseline_metrics)[names(baseline_metrics) == "spec_id"] <- "baseline_spec_id"

paired <- merge(
  metrics,
  baseline_metrics,
  by = c("target_cell_id", "source_scenario", "reservoir_replicate"),
  all.x = TRUE,
  sort = FALSE
)
ratio <- function(x, y) ifelse(is.finite(x) & is.finite(y) & y > 0, x / y, NA_real_)
paired$fit_ratio <- ratio(paired$metric_fit_rmse, paired$baseline_fit_rmse)
paired$forecast_mae_ratio <- ratio(paired$metric_forecast_mae, paired$baseline_forecast_mae)
paired$forecast_check_ratio <- ratio(paired$metric_forecast_check, paired$baseline_forecast_check)
paired$pair_complete <- is.finite(paired$fit_ratio) & is.finite(paired$forecast_mae_ratio) & is.finite(paired$forecast_check_ratio)
paired_path <- write_csv(paired, file.path(output_root, paste0(phase, "_paired_metrics.csv")))

group_key <- paste(paired$target_cell_id, paired$arm_code, sep = "\r")
aggregate_rows <- lapply(split(seq_len(nrow(paired)), group_key), function(idx) {
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
    arm_code = x$arm_code[[1L]],
    arm_class = x$arm_class[[1L]],
    topology_mode = x$topology_mode[[1L]],
    alpha = as.numeric(x$alpha[[1L]]),
    rho = as.numeric(x$rho[[1L]]),
    pi_w = as.numeric(x$pi_w[[1L]]),
    pi_in = as.numeric(x$pi_in[[1L]]),
    n_expected_pairs = 6L,
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
aggregate <- if (length(aggregate_rows)) do.call(rbind, aggregate_rows) else data.frame(stringsAsFactors = FALSE)
aggregate <- aggregate[order(aggregate$target_cell_id, aggregate$worst_median_ratio, aggregate$arm_code), , drop = FALSE]
aggregate_path <- write_csv(aggregate, file.path(output_root, paste0(phase, "_arm_summary.csv")))

n_metric_complete <- if (nrow(metrics)) sum(as.logical(metrics$metric_complete), na.rm = TRUE) else 0L
completion_fraction <- n_metric_complete / length(expected_ids)
decision <- ""
decision_reason <- ""
finalists <- data.frame(stringsAsFactors = FALSE)

if (phase == "mechanism") {
  repair <- aggregate[aggregate$arm_code != "parent_exact", , drop = FALSE]
  repair$signal <- repair$n_complete_pairs >= 4L &
    repair$worst_median_ratio <= 1.25 &
    pmin(repair$median_fit_ratio, repair$median_forecast_mae_ratio, repair$median_forecast_check_ratio, na.rm = TRUE) <= 0.95
  hard <- repair$target_role != "resolved_negative_control"
  signal_cells <- unique(repair$target_cell_id[hard & repair$signal])
  full <- repair[repair$arm_code == "full_topology" & hard, , drop = FALSE]
  full_signal_cells <- unique(full$target_cell_id[full$signal])
  full_not_catastrophic <- nrow(full) > 0L && all(full$n_complete_pairs >= 4L & full$worst_median_ratio <= 1.25, na.rm = TRUE)
  if (completion_fraction < 0.90) {
    decision <- "BLOCK_INCOMPLETE"
    decision_reason <- sprintf("Only %.1f%% of expected mechanism specs have complete metrics.", 100 * completion_fraction)
  } else if (length(signal_cells) >= 2L && (length(full_signal_cells) >= 1L || full_not_catastrophic)) {
    decision <- "GO_BROAD"
    decision_reason <- sprintf("Topology repair produced a >=5%% metric signal without >25%% median catastrophe in %d hard cells.", length(signal_cells))
  } else {
    decision <- "STOP_NO_MECHANISM_SIGNAL"
    decision_reason <- "The paired mechanism controls do not justify spending compute on the broad alpha/rho surface."
  }
} else {
  aggregate$confirmation_eligible <- aggregate$n_complete_pairs >= 4L &
    aggregate$worst_median_ratio <= 1.05 &
    pmin(aggregate$median_fit_ratio, aggregate$median_forecast_mae_ratio, aggregate$median_forecast_check_ratio, na.rm = TRUE) <= 0.98 &
    aggregate$worst_q90_ratio <= 1.25
  eligible <- aggregate[aggregate$confirmation_eligible, , drop = FALSE]
  if (nrow(eligible)) {
    finalists <- do.call(rbind, lapply(split(seq_len(nrow(eligible)), eligible$target_cell_id), function(idx) {
      x <- eligible[idx, , drop = FALSE]
      x <- x[order(x$worst_median_ratio, x$mean_median_ratio, x$arm_code), , drop = FALSE]
      utils::head(x, 3L)
    }))
    decision <- "CANDIDATES_FOR_FULL_CONFIRMATION"
    decision_reason <- sprintf("%d per-cell candidate arms meet the development-source confirmation gate.", nrow(finalists))
  } else if (completion_fraction < 0.90) {
    decision <- "BLOCK_INCOMPLETE"
    decision_reason <- sprintf("Only %.1f%% of expected broad specs have complete metrics.", 100 * completion_fraction)
  } else {
    decision <- "NO_BROAD_CANDIDATE"
    decision_reason <- "No broad arm jointly controls all three paired metrics strongly enough for full confirmation."
  }
}

finalists_path <- write_csv(finalists, file.path(output_root, paste0(phase, "_full_confirmation_candidates.csv")))
gate <- list(
  generated_at = as.character(Sys.time()),
  phase = phase,
  run_tag = run_tag,
  decision = decision,
  decision_reason = decision_reason,
  expected_specs = length(expected_ids),
  observed_fit_summaries = length(observed_ids),
  complete_metric_specs = n_metric_complete,
  completion_fraction = completion_fraction,
  missing_specs = length(missing_ids),
  unexpected_specs = length(unexpected_ids),
  metrics_path = metrics_path,
  paired_metrics_path = paired_path,
  arm_summary_path = aggregate_path,
  finalists_path = finalists_path,
  baseline_metrics_path = if (phase == "mechanism") metrics_path else resolve_path(baseline_path),
  missing_spec_ids_path = missing_path,
  unexpected_spec_ids_path = unexpected_path
)
gate_path <- write_json(gate, file.path(output_root, paste0(phase, "_gate.json")))

readme <- c(
  "# Q-DESN Alpha/Rho Topology v1 Audit",
  "",
  sprintf("- phase: `%s`", phase),
  sprintf("- run_tag: `%s`", run_tag),
  sprintf("- decision: `%s`", decision),
  sprintf("- reason: %s", decision_reason),
  sprintf("- expected specs: `%d`", length(expected_ids)),
  sprintf("- observed fit summaries: `%d`", length(observed_ids)),
  sprintf("- complete metric specs: `%d` (%.1f%%)", n_metric_complete, 100 * completion_fraction),
  sprintf("- missing specs: `%d`", length(missing_ids)),
  "",
  "Metrics are paired by target cell, development source, and reservoir replicate.",
  "Fit RMSE is the effective training-window true-quantile RMSE. Forecast MAE and",
  "check loss use the rolling-origin H=1000 summary with Hmax=30 and stride=30.",
  "Status and signoff are retained but do not erase finite screening metrics.",
  "No screening result is article-authoritative without a full-budget frozen-source confirmation."
)
writeLines(readme, file.path(output_root, "README.md"))

cat(sprintf("Decision: %s\n", decision))
cat(sprintf("Complete metrics: %d/%d (%.1f%%)\n", n_metric_complete, length(expected_ids), 100 * completion_fraction))
cat(sprintf("Gate: %s\n", gate_path))

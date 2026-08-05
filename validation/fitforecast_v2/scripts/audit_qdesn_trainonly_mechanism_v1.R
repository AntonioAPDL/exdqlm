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
ratio <- function(x, y) ifelse(is.finite(x) & is.finite(y) & y > 0, x / y, NA_real_)

stage <- "qdesn_dynamic_fitforecast_v2_500obs_trainonly_mechanism_v1"
stub <- file.path("config", "validation", stage)
bundle_index <- read_csv(paste0(stub, "_bundle_index.csv"))
profiles <- read_csv(paste0(stub, "_profiles.csv"))
targets <- read_csv(paste0(stub, "_target_cells.csv"))

state_root_arg <- as.character(get_arg("--state-root", ""))[1L]
state_root <- if (nzchar(state_root_arg)) resolve_path(state_root_arg) else NULL
env <- if (!is.null(state_root)) read_env(file.path(state_root, "run_tags.env")) else character()
run_tag_for <- function(bundle_id) {
  flag <- paste0("--", bundle_id, "-run-tag")
  explicit <- as.character(get_arg(flag, ""))[1L]
  if (nzchar(explicit)) return(explicit)
  key <- paste0(toupper(bundle_id), "_RUN_TAG")
  value <- unname(env[[key]] %||% "")
  if (!nzchar(value)) stop(sprintf("Missing run tag for bundle %s.", bundle_id), call. = FALSE)
  value
}

output_root <- resolve_path(get_arg(
  "--output-root",
  if (!is.null(state_root)) file.path(state_root, "closeout") else file.path("reports", "qdesn_mcmc_validation", stage, "manual_closeout")
), FALSE)
dir.create(output_root, recursive = TRUE, showWarnings = FALSE)

metric_rows <- list()
missing_rows <- list()
run_inventory <- list()
heavy_rows <- list()
for (i in seq_len(nrow(bundle_index))) {
  b <- bundle_index[i, , drop = FALSE]
  bundle_id <- as.character(b$bundle_id[[1L]])
  defaults <- yaml::read_yaml(resolve_path(b$defaults_path[[1L]]))
  expected <- read_csv(b$target_specs_path[[1L]])
  run_tag <- run_tag_for(bundle_id)
  run_root <- resolve_path(file.path(defaults$campaign$results_root, run_tag), FALSE)
  fit_paths <- if (dir.exists(run_root)) {
    list.files(run_root, pattern = "^fit_summary_row[.]csv$", recursive = TRUE, full.names = TRUE)
  } else character()
  rows <- lapply(fit_paths, function(path) {
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
    fit$bundle_id <- bundle_id
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
  rows <- Filter(Negate(is.null), rows)
  observed <- if (length(rows)) do.call(rbind, rows) else data.frame(stringsAsFactors = FALSE)
  observed_ids <- if (nrow(observed)) unique(as.character(observed$spec_id)) else character()
  expected_ids <- unique(as.character(expected$spec_id))
  missing <- setdiff(expected_ids, observed_ids)
  if (length(missing)) missing_rows[[bundle_id]] <- data.frame(bundle_id = bundle_id, spec_id = missing, stringsAsFactors = FALSE)
  if (nrow(observed)) metric_rows[[bundle_id]] <- observed
  heavy <- if (dir.exists(run_root)) {
    list.files(run_root, pattern = "[.](rds|rda|RData)$", recursive = TRUE, full.names = TRUE, ignore.case = TRUE)
  } else character()
  if (length(heavy)) {
    heavy_rows[[bundle_id]] <- data.frame(
      bundle_id = bundle_id,
      path = normalizePath(heavy, winslash = "/", mustWork = TRUE),
      bytes = as.numeric(file.info(heavy)$size),
      stringsAsFactors = FALSE
    )
  }
  run_inventory[[bundle_id]] <- data.frame(
    bundle_id = bundle_id,
    run_tag = run_tag,
    run_root = run_root,
    expected_specs = length(expected_ids),
    observed_specs = length(observed_ids),
    complete_metric_specs = if (nrow(observed)) sum(as.logical(observed$metric_complete), na.rm = TRUE) else 0L,
    missing_specs = length(missing),
    heavy_payloads = length(heavy),
    stringsAsFactors = FALSE
  )
}

metrics <- if (length(metric_rows)) do.call(rbind, metric_rows) else data.frame(stringsAsFactors = FALSE)
missing <- if (length(missing_rows)) do.call(rbind, missing_rows) else data.frame(bundle_id = character(), spec_id = character())
run_inventory <- do.call(rbind, run_inventory)
heavy <- if (length(heavy_rows)) do.call(rbind, heavy_rows) else data.frame(bundle_id = character(), path = character(), bytes = numeric())

profile_keep <- c(
  "screening_profile_id", "target_cell_id", "target_role", "primary_target",
  "target_family", "target_tau", "likelihood_target", "parent_profile_id",
  "bundle_id", "arm_code", "arm_class", "topology_mode", "reservoir_replicate",
  "paired_reservoir_seed", "D", "n_each", "m", "alpha", "rho", "pi_w",
  "pi_in", "rhs_tau0"
)
if (nrow(metrics)) {
  metrics <- merge(metrics, profiles[, profile_keep, drop = FALSE], by = c("screening_profile_id", "bundle_id"), all.x = TRUE, sort = FALSE)
  metrics$rhs_tau0_effective <- as.numeric(metrics$rhs_tau0.y %||% metrics$rhs_tau0.x)
  if (!"source_scenario" %in% names(metrics) && "scenario" %in% names(metrics)) metrics$source_scenario <- metrics$scenario
  metrics <- metrics[!duplicated(metrics$spec_id), , drop = FALSE]
}
metrics_path <- write_csv(metrics, file.path(output_root, "mechanism_metrics.csv"))
missing_path <- write_csv(missing, file.path(output_root, "missing_spec_ids.csv"))
run_inventory_path <- write_csv(run_inventory, file.path(output_root, "run_inventory.csv"))
heavy_path <- write_csv(heavy, file.path(output_root, "storage_heavy_artifact_audit.csv"))

baseline <- if (nrow(metrics)) metrics[metrics$arm_code == "parent_exact", , drop = FALSE] else metrics
baseline_keep <- c(
  "target_cell_id", "source_scenario", "reservoir_replicate",
  "metric_fit_rmse", "metric_forecast_mae", "metric_forecast_check", "spec_id"
)
baseline <- baseline[, baseline_keep, drop = FALSE]
names(baseline)[names(baseline) == "metric_fit_rmse"] <- "baseline_fit_rmse"
names(baseline)[names(baseline) == "metric_forecast_mae"] <- "baseline_forecast_mae"
names(baseline)[names(baseline) == "metric_forecast_check"] <- "baseline_forecast_check"
names(baseline)[names(baseline) == "spec_id"] <- "baseline_spec_id"
paired <- merge(
  metrics, baseline,
  by = c("target_cell_id", "source_scenario", "reservoir_replicate"),
  all.x = TRUE, sort = FALSE
)
paired$fit_ratio <- ratio(paired$metric_fit_rmse, paired$baseline_fit_rmse)
paired$forecast_mae_ratio <- ratio(paired$metric_forecast_mae, paired$baseline_forecast_mae)
paired$forecast_check_ratio <- ratio(paired$metric_forecast_check, paired$baseline_forecast_check)
paired$pair_complete <- is.finite(paired$fit_ratio) & is.finite(paired$forecast_mae_ratio) & is.finite(paired$forecast_check_ratio)
paired_path <- write_csv(paired, file.path(output_root, "paired_candidate_parent_metrics.csv"))

group_key <- paste(paired$target_cell_id, paired$bundle_id, paired$arm_code, sep = "\r")
summaries <- lapply(split(seq_len(nrow(paired)), group_key), function(idx) {
  x <- paired[idx, , drop = FALSE]
  med <- c(fit = finite_median(x$fit_ratio), mae = finite_median(x$forecast_mae_ratio), check = finite_median(x$forecast_check_ratio))
  q90 <- c(fit = finite_q90(x$fit_ratio), mae = finite_q90(x$forecast_mae_ratio), check = finite_q90(x$forecast_check_ratio))
  data.frame(
    target_cell_id = x$target_cell_id[[1L]],
    target_role = x$target_role[[1L]],
    primary_target = as.logical(x$primary_target[[1L]]),
    likelihood_target = x$likelihood_target[[1L]],
    target_family = x$target_family[[1L]],
    target_tau = as.numeric(x$target_tau[[1L]]),
    bundle_id = x$bundle_id[[1L]],
    arm_code = x$arm_code[[1L]],
    arm_class = x$arm_class[[1L]],
    D = as.integer(x$D[[1L]]),
    n_each = as.integer(x$n_each[[1L]]),
    m = as.integer(x$m[[1L]]),
    alpha = as.numeric(x$alpha[[1L]]),
    rho = as.numeric(x$rho[[1L]]),
    pi_w = as.numeric(x$pi_w[[1L]]),
    pi_in = as.numeric(x$pi_in[[1L]]),
    rhs_tau0 = as.numeric(x$rhs_tau0_effective[[1L]]),
    n_expected_pairs = 6L,
    n_complete_pairs = sum(x$pair_complete, na.rm = TRUE),
    median_fit_ratio = med[["fit"]],
    median_forecast_mae_ratio = med[["mae"]],
    median_forecast_check_ratio = med[["check"]],
    best_median_ratio = if (all(is.finite(med))) min(med) else NA_real_,
    worst_median_ratio = if (all(is.finite(med))) max(med) else NA_real_,
    mean_median_ratio = if (all(is.finite(med))) mean(med) else NA_real_,
    q90_fit_ratio = q90[["fit"]],
    q90_forecast_mae_ratio = q90[["mae"]],
    q90_forecast_check_ratio = q90[["check"]],
    worst_q90_ratio = if (all(is.finite(q90))) max(q90) else NA_real_,
    stringsAsFactors = FALSE
  )
})
summary <- if (length(summaries)) do.call(rbind, summaries) else data.frame(stringsAsFactors = FALSE)
if (nrow(summary)) {
  summary$confirmation_eligible <- summary$primary_target & summary$arm_code != "parent_exact" &
    summary$n_complete_pairs == summary$n_expected_pairs &
    summary$best_median_ratio <= 0.98 & summary$worst_median_ratio <= 1.05 &
    summary$worst_q90_ratio <= 1.10
  summary <- summary[order(summary$target_cell_id, summary$worst_median_ratio, summary$mean_median_ratio, summary$arm_code), , drop = FALSE]
}
summary_path <- write_csv(summary, file.path(output_root, "arm_summary.csv"))

eligible <- if (nrow(summary)) summary[as.logical(summary$confirmation_eligible), , drop = FALSE] else summary
finalists <- if (nrow(eligible)) {
  do.call(rbind, lapply(split(seq_len(nrow(eligible)), eligible$target_cell_id), function(idx) {
    x <- eligible[idx, , drop = FALSE]
    x[order(x$worst_median_ratio, x$mean_median_ratio, x$arm_code), , drop = FALSE][1L, , drop = FALSE]
  }))
} else data.frame(stringsAsFactors = FALSE)
finalists_path <- write_csv(finalists, file.path(output_root, "full_budget_confirmation_candidates.csv"))

expected_total <- sum(run_inventory$expected_specs)
complete_total <- sum(run_inventory$complete_metric_specs)
completion_fraction <- if (expected_total) complete_total / expected_total else 0
priority_cells <- targets$target_cell_id[as.logical(targets$primary_target)]
covered_cells <- unique(as.character(finalists$target_cell_id %||% character()))
control <- summary[!as.logical(summary$primary_target) & summary$arm_code != "parent_exact", , drop = FALSE]
control_ok <- nrow(control) > 0L && any(control$n_complete_pairs == 6L & control$worst_median_ratio <= 1.10 & control$worst_q90_ratio <= 1.20)

if (completion_fraction < 1 || nrow(missing) > 0L) {
  decision <- "BLOCK_INCOMPLETE"
  reason <- sprintf("Only %d/%d target specs have complete metrics.", complete_total, expected_total)
} else if (length(setdiff(priority_cells, covered_cells)) == 0L && control_ok) {
  decision <- "CANDIDATES_FOR_FULL_BUDGET_CONFIRMATION"
  reason <- "Each priority cell has a paired mechanism winner and the solved negative control remains stable."
} else if (length(covered_cells)) {
  decision <- "PARTIAL_SIGNAL_TARGETED_FOLLOWUP"
  reason <- sprintf("Mechanism evidence produced a confirmation candidate in %d/%d priority cells.", length(intersect(priority_cells, covered_cells)), length(priority_cells))
} else {
  decision <- "NO_MECHANISM_CANDIDATE"
  reason <- "No mechanism arm passed the paired improvement and stability gates."
}

gate <- list(
  generated_at = as.character(Sys.time()),
  decision = decision,
  decision_reason = reason,
  expected_specs = expected_total,
  complete_metric_specs = complete_total,
  completion_fraction = completion_fraction,
  missing_specs = nrow(missing),
  heavy_payloads = nrow(heavy),
  priority_cells = as.list(priority_cells),
  priority_cells_with_candidate = as.list(intersect(priority_cells, covered_cells)),
  negative_control_stable = control_ok,
  article_update_allowed = FALSE,
  next_gate = "separate_full_budget_confirmation_on_frozen_article_source_and_one_untouched_fresh_source",
  metrics_path = metrics_path,
  paired_metrics_path = paired_path,
  arm_summary_path = summary_path,
  finalists_path = finalists_path,
  run_inventory_path = run_inventory_path,
  storage_audit_path = heavy_path,
  missing_specs_path = missing_path
)
gate_path <- write_json(gate, file.path(output_root, "mechanism_gate.json"))
writeLines(c(
  "# Q-DESN Train-Only Mechanism v1 Closeout",
  "",
  sprintf("- decision: `%s`", decision),
  sprintf("- reason: %s", reason),
  sprintf("- complete target specs: `%d/%d`", complete_total, expected_total),
  sprintf("- heavy binary payloads: `%d`", nrow(heavy)),
  "- article update: `not allowed from discovery evidence`",
  "",
  "All comparisons are paired by target cell, fresh source trajectory, and reservoir seed.",
  "Finite metrics are retained regardless of diagnostic grade, while status and signoff remain",
  "in the raw evidence. A candidate must improve at least one median metric by 2%, keep every",
  "median metric within 5% of its paired parent, and keep the worst q90 ratio within 10%.",
  "The frozen article source is reserved for a separate full-budget confirmation."
), file.path(output_root, "README.md"))

cat(sprintf("Decision: %s\n", decision))
cat(sprintf("Complete metrics: %d/%d (%.1f%%)\n", complete_total, expected_total, 100 * completion_fraction))
cat(sprintf("Gate: %s\n", gate_path))

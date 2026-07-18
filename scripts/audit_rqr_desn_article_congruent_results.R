#!/usr/bin/env Rscript

`%||%` <- function(x, y) if (is.null(x) || length(x) == 0L) y else x

parse_cli <- function(args) {
  out <- list()
  ii <- 1L
  while (ii <= length(args)) {
    key <- args[[ii]]
    if (!startsWith(key, "--")) stop(sprintf("Unexpected positional argument: %s", key), call. = FALSE)
    key <- sub("^--", "", key)
    value <- "true"
    if (ii < length(args) && !startsWith(args[[ii + 1L]], "--")) {
      value <- args[[ii + 1L]]
      ii <- ii + 1L
    }
    out[[key]] <- value
    ii <- ii + 1L
  }
  out
}

as_num <- function(x, default) {
  if (is.null(x)) return(default)
  out <- suppressWarnings(as.numeric(x[1L]))
  if (!is.finite(out)) stop(sprintf("Expected numeric, got: %s", x[1L]), call. = FALSE)
  out
}

repo_root <- function() {
  root <- tryCatch(system("git rev-parse --show-toplevel", intern = TRUE), error = function(e) "")
  if (!length(root) || !nzchar(root[1L])) getwd() else normalizePath(root[1L], mustWork = TRUE)
}

write_csv <- function(x, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(x, path, row.names = FALSE, na = "")
}

read_csv_required <- function(path) {
  if (!file.exists(path)) stop(sprintf("Required file missing: %s", path), call. = FALSE)
  tryCatch(
    utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE),
    error = function(e) data.frame()
  )
}

latest_run_dir <- function(root) {
  base <- file.path(root, "reports", "rqr_desn_article_congruent_simulation")
  dirs <- if (dir.exists(base)) list.dirs(base, recursive = FALSE, full.names = TRUE) else character(0)
  dirs <- dirs[grepl("^run_", basename(dirs))]
  if (!length(dirs)) stop("No article-congruent RQR-DESN run directories found.", call. = FALSE)
  dirs[order(file.info(dirs)$mtime, decreasing = TRUE)][1L]
}

mean_or_na <- function(x) {
  x <- suppressWarnings(as.numeric(x))
  if (all(is.na(x))) NA_real_ else mean(x, na.rm = TRUE)
}

all_trueish <- function(x) {
  if (!length(x)) return(FALSE)
  all(tolower(as.character(x)) %in% c("true", "t", "1", "yes"), na.rm = TRUE)
}

aggregate_metrics <- function(metrics, tol) {
  if (!nrow(metrics)) return(data.frame())
  group_cols <- c("stage_id", "family_id", "coverage_level", "method_id", "method_family", "implemented_adapter", "prior_type", "learning_rate")
  groups <- metrics[group_cols]
  for (nm in names(groups)) {
    groups[[nm]] <- as.character(groups[[nm]])
    groups[[nm]][is.na(groups[[nm]]) | !nzchar(groups[[nm]])] <- "not_applicable"
  }
  value_cols <- c("empirical_coverage", "coverage_error", "mean_width", "interval_score_mean", "endpoint_mae", "midpoint_mae", "runtime_sec")
  out <- stats::aggregate(metrics[value_cols], by = groups, FUN = mean_or_na)
  out$n_rows <- as.integer(stats::aggregate(metrics$scenario_id, by = groups, FUN = length)$x)
  flags <- stats::aggregate(metrics[c("finite_lower", "finite_upper", "ordered_intervals", "positive_mean_width")], by = groups, FUN = all_trueish)
  out <- merge(out, flags, by = group_cols, all.x = TRUE, sort = FALSE)
  out$abs_coverage_error <- abs(out$coverage_error)
  out$calibration_qualified <- is.finite(out$abs_coverage_error) & out$abs_coverage_error <= tol
  out$health_qualified <- as.logical(out$finite_lower) & as.logical(out$finite_upper) &
    as.logical(out$ordered_intervals) & as.logical(out$positive_mean_width)
  out
}

winner_table <- function(summary) {
  if (!nrow(summary)) return(data.frame())
  key <- paste(summary$stage_id, summary$family_id, summary$coverage_level, sep = "\r")
  groups <- split(summary, key)
  winners <- lapply(groups, function(df) {
    qualified <- df[df$calibration_qualified & df$health_qualified, , drop = FALSE]
    if (!nrow(qualified)) {
      row <- df[order(df$abs_coverage_error, df$interval_score_mean, na.last = TRUE), , drop = FALSE][1L, , drop = FALSE]
      row$winner_status <- "no_qualified_winner"
      row$winner_reason <- "no method satisfies the coverage tolerance and health gates"
      return(row)
    }
    row <- qualified[order(qualified$interval_score_mean, qualified$mean_width, na.last = TRUE), , drop = FALSE][1L, , drop = FALSE]
    row$winner_status <- "qualified_winner"
    row$winner_reason <- "coverage-qualified; selected by interval score with width as secondary"
    row
  })
  out <- do.call(rbind, winners)
  rownames(out) <- NULL
  out
}

preflight_gates <- function(launch, metrics, failures, statuses, mcmc, tol) {
  model_metrics <- metrics[metrics$method_id != "empirical_train_interval", , drop = FALSE]
  data.frame(
    gate = c(
      "status_rows_match_launch",
      "all_terminal",
      "failure_rows_recorded",
      "metric_rows_no_more_than_launch",
      "no_rqr_response_predictive_draws",
      "no_qdesn_pair_scalar_density_claim",
      "model_intervals_finite_ordered_positive_when_present",
      "mcmc_diagnostics_present_for_completed_mcmc"
    ),
    status = c(
      if (nrow(statuses) == nrow(launch)) "pass" else "fail",
      if (nrow(statuses) && all(statuses$status %in% c("completed", "failed"))) "pass" else "fail",
      if (nrow(failures) == sum(statuses$status == "failed", na.rm = TRUE)) "pass" else "review",
      if (nrow(metrics) <= nrow(launch)) "pass" else "fail",
      if (!nrow(metrics) || !any(tolower(as.character(metrics$rqr_response_predictive_draws)) %in% c("true", "t", "1", "yes"))) "pass" else "fail",
      if (!nrow(metrics) || !("qdesn_pair_scalar_density" %in% names(metrics)) || !any(tolower(as.character(metrics$qdesn_pair_scalar_density)) %in% c("true", "t", "1", "yes"))) "pass" else "fail",
      if (!nrow(model_metrics) || (all_trueish(model_metrics$finite_lower) && all_trueish(model_metrics$finite_upper) && all_trueish(model_metrics$ordered_intervals) && all_trueish(model_metrics$positive_mean_width))) "pass" else "fail",
      if (nrow(mcmc) || !any(launch$inference == "mcmc" & statuses$status == "completed")) "pass" else "review"
    ),
    observed = c(nrow(statuses), sum(statuses$status %in% c("completed", "failed")), nrow(failures), nrow(metrics), NA, NA, nrow(model_metrics), nrow(mcmc)),
    expected = c(nrow(launch), nrow(launch), sum(statuses$status == "failed", na.rm = TRUE), nrow(launch), 0, 0, NA, NA),
    tolerance = c(NA, NA, NA, NA, NA, NA, tol, NA)
  )
}

claim_contract <- function(launch) {
  stages <- unique(launch[, c("stage_id", "stage_family"), drop = FALSE])
  stages$allowed_claim <- ifelse(
    stages$stage_family == "fixed_design",
    "endpoint recovery and held-out interval scoring under fixed-design DGPs with oracle central interval endpoints",
    "rolling one-step held-out interval scoring on causal fixed DESN features with oracle location-scale endpoint comparisons"
  )
  stages$forbidden_claim <- ifelse(
    stages$stage_family == "fixed_design",
    "response predictive density validation, recursive response simulation, or superiority over unrun competitors",
    "response predictive density validation, recursive response simulation, or quantile-crossing improvement by RQR-DESN"
  )
  stages
}

write_json <- function(x, path) {
  esc <- function(z) gsub("\"", "\\\"", as.character(z), fixed = TRUE)
  vals <- vapply(names(x), function(nm) {
    val <- x[[nm]]
    if (is.logical(val)) val <- if (isTRUE(val)) "true" else "false"
    else if (is.numeric(val) && is.finite(val)) val <- as.character(val)
    else val <- sprintf("\"%s\"", esc(val))
    sprintf("  \"%s\": %s", esc(nm), val)
  }, character(1))
  writeLines(c("{", paste(vals, collapse = ",\n"), "}"), path)
}

main <- function(args = commandArgs(trailingOnly = TRUE)) {
  cli <- parse_cli(args)
  root <- repo_root()
  run_dir <- normalizePath(cli[["run-dir"]] %||% latest_run_dir(root), mustWork = TRUE)
  tol <- as_num(cli[["coverage-tol"]], 0.025)
  stamp <- format(Sys.time(), "%Y%m%d-%H%M%S")
  out_dir <- normalizePath(cli[["output-dir"]] %||% file.path(run_dir, sprintf("results_audit_%s", stamp)), mustWork = FALSE)
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

  launch <- read_csv_required(file.path(run_dir, "launch_manifest.csv"))
  metrics <- read_csv_required(file.path(run_dir, "interval_metrics.csv"))
  failures <- read_csv_required(file.path(run_dir, "failure_log.csv"))
  statuses <- read_csv_required(file.path(run_dir, "run_status.csv"))
  mcmc <- read_csv_required(file.path(run_dir, "mcmc_diagnostics.csv"))

  gates <- preflight_gates(launch, metrics, failures, statuses, mcmc, tol)
  summary <- aggregate_metrics(metrics, tol)
  winners <- winner_table(summary)
  missing_or_failed <- merge(
    launch[, c("scenario_id", "stage_id", "family_id", "method_id", "implemented_adapter"), drop = FALSE],
    statuses[, c("scenario_id", "status", "message"), drop = FALSE],
    by = "scenario_id",
    all.x = TRUE,
    sort = FALSE
  )
  missing_or_failed <- missing_or_failed[is.na(missing_or_failed$status) | missing_or_failed$status != "completed", , drop = FALSE]
  contract <- claim_contract(launch)
  recommendation <- if (all(gates$status != "fail") && nrow(winners) && any(winners$winner_status == "qualified_winner")) {
    "review_qualified_winners_before_article_asset_build"
  } else if (all(gates$status != "fail")) {
    "hold_article_update_until_complete_qualified_results"
  } else {
    "repair_failed_gates_before_scientific_interpretation"
  }

  write_csv(gates, file.path(out_dir, "readiness_gates.csv"))
  write_csv(summary, file.path(out_dir, "method_summary.csv"))
  write_csv(winners, file.path(out_dir, "calibration_qualified_winner_table.csv"))
  write_csv(missing_or_failed, file.path(out_dir, "failed_or_missing_methods.csv"))
  write_csv(contract, file.path(out_dir, "article_claim_contract.csv"))
  write_json(list(
    recommendation = recommendation,
    run_dir = run_dir,
    output_dir = out_dir,
    launch_rows = nrow(launch),
    metric_rows = nrow(metrics),
    failure_rows = nrow(failures),
    qualified_winner_cells = if (nrow(winners)) sum(winners$winner_status == "qualified_winner") else 0
  ), file.path(out_dir, "promotion_recommendation.json"))
  writeLines(c(
    "# RQR-DESN Article-Congruent Results Audit",
    "",
    sprintf("- run directory: `%s`", run_dir),
    sprintf("- launch rows: `%d`", nrow(launch)),
    sprintf("- metric rows: `%d`", nrow(metrics)),
    sprintf("- failure rows: `%d`", nrow(failures)),
    sprintf("- coverage tolerance: `%g`", tol),
    sprintf("- recommendation: `%s`", recommendation),
    "",
    "The audit uses coverage qualification before interval-score ranking and records no-qualified-winner cells explicitly."
  ), file.path(out_dir, "closeout.md"))
  message(sprintf("RQR-DESN article-congruent audit wrote %s", out_dir))
  invisible(out_dir)
}

if (sys.nframe() == 0L) main()

#!/usr/bin/env Rscript

`%||%` <- function(x, y) {
  if (is.null(x) || length(x) == 0L) y else x
}

parse_cli <- function(args) {
  out <- list()
  ii <- 1L
  while (ii <= length(args)) {
    key <- args[[ii]]
    if (!startsWith(key, "--")) {
      stop(sprintf("Unexpected positional argument: %s", key), call. = FALSE)
    }
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

as_num <- function(x, default = NA_real_) {
  if (is.null(x)) return(default)
  out <- suppressWarnings(as.numeric(x[1L]))
  if (!is.finite(out) && !is.na(out)) {
    stop(sprintf("Expected numeric value, got: %s", x[1L]), call. = FALSE)
  }
  out
}

as_flag <- function(x, default = FALSE) {
  if (is.null(x)) return(default)
  value <- tolower(trimws(as.character(x[1L])))
  if (value %in% c("true", "t", "1", "yes", "y")) return(TRUE)
  if (value %in% c("false", "f", "0", "no", "n")) return(FALSE)
  stop(sprintf("Cannot parse logical flag: %s", x), call. = FALSE)
}

repo_root <- function() {
  root <- tryCatch(system("git rev-parse --show-toplevel", intern = TRUE), error = function(e) "")
  if (!length(root) || !nzchar(root[1L])) getwd() else normalizePath(root[1L], mustWork = TRUE)
}

write_csv <- function(x, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(x, file = path, row.names = FALSE, na = "")
}

read_csv_required <- function(path) {
  if (!file.exists(path)) stop(sprintf("Required file is missing: %s", path), call. = FALSE)
  utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
}

clean_group_value <- function(x) {
  x <- as.character(x)
  missing <- is.na(x) | !nzchar(x)
  x[missing] <- "not_applicable"
  x
}

truthy <- function(x) {
  if (is.logical(x)) return(isTRUE(x[1L]))
  tolower(trimws(as.character(x[1L]))) %in% c("true", "t", "1", "yes", "y")
}

any_trueish <- function(x) {
  if (!length(x)) return(FALSE)
  any(vapply(x, truthy, logical(1)), na.rm = TRUE)
}

all_trueish <- function(x) {
  if (!length(x)) return(FALSE)
  all(tolower(trimws(as.character(x))) %in% c("true", "t", "1", "yes", "y"), na.rm = TRUE)
}

json_escape <- function(x) {
  x <- as.character(x)
  x <- gsub("\\\\", "\\\\\\\\", x)
  x <- gsub("\"", "\\\\\"", x)
  x <- gsub("\n", "\\\\n", x)
  x
}

json_scalar <- function(x) {
  if (length(x) == 0L || is.null(x) || is.na(x[1L])) return("null")
  if (is.logical(x)) return(if (isTRUE(x[1L])) "true" else "false")
  if (is.numeric(x) || is.integer(x)) {
    if (is.finite(x[1L])) return(as.character(x[1L]))
    return("null")
  }
  sprintf("\"%s\"", json_escape(x[1L]))
}

write_json_object <- function(x, path) {
  stopifnot(is.list(x))
  nms <- names(x)
  lines <- c("{", vapply(seq_along(x), function(ii) {
    comma <- if (ii < length(x)) "," else ""
    sprintf("  \"%s\": %s%s", json_escape(nms[[ii]]), json_scalar(x[[ii]]), comma)
  }, character(1)), "}")
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  writeLines(lines, path)
}

latest_run_dir <- function(root) {
  run_root <- file.path(root, "reports", "rqr_desn_broad_simulation")
  dirs <- if (dir.exists(run_root)) list.dirs(run_root, recursive = FALSE, full.names = TRUE) else character(0)
  dirs <- dirs[grepl("rqr_desn_broad_run_", basename(dirs), fixed = TRUE)]
  if (!length(dirs)) stop("No RQR-DESN broad run directories found.", call. = FALSE)
  dirs[order(file.info(dirs)$mtime, decreasing = TRUE)][1L]
}

required_input_files <- function() {
  c(
    "interval_metrics.csv",
    "metric_summary.csv",
    "run_status.csv",
    "failure_log.csv",
    "fit_summary.csv",
    "mcmc_diagnostics.csv",
    "vb_diagnostics.csv",
    "launch_manifest.csv",
    "dgp_manifest.csv",
    "design_manifest.csv",
    "output_hashes.csv",
    "git_state.txt"
  )
}

load_audit_inputs <- function(run_dir) {
  missing <- required_input_files()[!file.exists(file.path(run_dir, required_input_files()))]
  if (length(missing)) {
    stop(sprintf("RQR-DESN audit input is incomplete; missing: %s", paste(missing, collapse = ", ")), call. = FALSE)
  }
  list(
    run_dir = normalizePath(run_dir, mustWork = TRUE),
    interval_metrics = read_csv_required(file.path(run_dir, "interval_metrics.csv")),
    metric_summary = read_csv_required(file.path(run_dir, "metric_summary.csv")),
    run_status = read_csv_required(file.path(run_dir, "run_status.csv")),
    failure_log = read_csv_required(file.path(run_dir, "failure_log.csv")),
    fit_summary = read_csv_required(file.path(run_dir, "fit_summary.csv")),
    mcmc_diagnostics = read_csv_required(file.path(run_dir, "mcmc_diagnostics.csv")),
    vb_diagnostics = read_csv_required(file.path(run_dir, "vb_diagnostics.csv")),
    launch_manifest = read_csv_required(file.path(run_dir, "launch_manifest.csv")),
    dgp_manifest = read_csv_required(file.path(run_dir, "dgp_manifest.csv")),
    design_manifest = read_csv_required(file.path(run_dir, "design_manifest.csv")),
    output_hashes = read_csv_required(file.path(run_dir, "output_hashes.csv")),
    manifest = if (file.exists(file.path(run_dir, "manifest.csv"))) {
      read_csv_required(file.path(run_dir, "manifest.csv"))
    } else {
      data.frame(key = character(0), value = character(0), stringsAsFactors = FALSE)
    },
    git_state = paste(readLines(file.path(run_dir, "git_state.txt"), warn = FALSE), collapse = "\n")
  )
}

manifest_value <- function(inputs, key, default = NA_character_) {
  manifest <- inputs$manifest
  if (!nrow(manifest) || !all(c("key", "value") %in% names(manifest))) return(default)
  idx <- match(key, manifest$key)
  if (is.na(idx)) default else as.character(manifest$value[[idx]])
}

infer_audit_context <- function(inputs, audit_context = "auto") {
  audit_context <- as.character(audit_context %||% "auto")[1L]
  if (!identical(audit_context, "auto")) return(audit_context)
  config_id <- manifest_value(inputs, "config_id", "")
  artifact_kind <- manifest_value(inputs, "artifact_kind", "")
  if (grepl("targeted_confirmation", config_id, fixed = TRUE) ||
    grepl("targeted_confirmation", artifact_kind, fixed = TRUE)) {
    return("targeted_confirmation")
  }
  "broad_screen"
}

status_row <- function(gate, status, detail, observed = NA_real_, expected = NA_real_) {
  data.frame(
    gate = gate,
    status = status,
    detail = detail,
    observed = observed,
    expected = expected,
    stringsAsFactors = FALSE
  )
}

preflight_gates <- function(inputs) {
  metrics <- inputs$interval_metrics
  statuses <- inputs$run_status
  failures <- inputs$failure_log
  mcmc_diag <- inputs$mcmc_diagnostics
  vb_diag <- inputs$vb_diagnostics
  launch <- inputs$launch_manifest
  model_metrics <- metrics[as.character(metrics$inference) != "baseline", , drop = FALSE]

  rows <- list(
    status_row(
      "all_status_rows_completed",
      if (nrow(statuses) == nrow(launch) && all(as.character(statuses$status) == "completed")) "pass" else "fail",
      sprintf("%d run-status rows for %d launch rows", nrow(statuses), nrow(launch)),
      nrow(statuses),
      nrow(launch)
    ),
    status_row(
      "no_failure_rows",
      if (nrow(failures) == 0L) "pass" else "fail",
      sprintf("%d failure rows", nrow(failures)),
      nrow(failures),
      0
    ),
    status_row(
      "metric_rows_match_launch",
      if (nrow(metrics) == nrow(launch)) "pass" else "fail",
      sprintf("%d metric rows for %d launch rows", nrow(metrics), nrow(launch)),
      nrow(metrics),
      nrow(launch)
    ),
    status_row(
      "mcmc_diagnostic_count",
      if (nrow(mcmc_diag) == sum(as.character(launch$inference) == "mcmc")) "pass" else "fail",
      "MCMC diagnostic rows match MCMC launch rows",
      nrow(mcmc_diag),
      sum(as.character(launch$inference) == "mcmc")
    ),
    status_row(
      "vb_diagnostic_count",
      if (nrow(vb_diag) == sum(as.character(launch$inference) == "vb")) "pass" else "fail",
      "VB diagnostic rows match VB launch rows",
      nrow(vb_diag),
      sum(as.character(launch$inference) == "vb")
    ),
    status_row(
      "model_intervals_finite_ordered_positive",
      if (nrow(model_metrics) &&
        all_trueish(model_metrics$finite_lower) &&
        all_trueish(model_metrics$finite_upper) &&
        all_trueish(model_metrics$ordered_intervals) &&
        all_trueish(model_metrics$positive_mean_width)) "pass" else "fail",
      sprintf("%d non-baseline model metric rows checked", nrow(model_metrics)),
      nrow(model_metrics),
      NA_real_
    ),
    status_row(
      "no_response_predictive_contract",
      if (nrow(model_metrics) &&
        !any_trueish(model_metrics$response_likelihood) &&
        !any_trueish(model_metrics$response_predictive_draws) &&
        !any_trueish(model_metrics$recursive_response_sampling)) "pass" else "fail",
      "response likelihood, response predictive draws, and recursive response sampling remain false",
      NA_real_,
      NA_real_
    )
  )
  do.call(rbind, rows)
}

write_input_hashes <- function(run_dir, output_dir) {
  files <- file.path(run_dir, required_input_files())
  hash_df <- data.frame(
    file = basename(files),
    md5 = unname(tools::md5sum(files)),
    stringsAsFactors = FALSE
  )
  write_csv(hash_df, file.path(output_dir, "audit_input_hashes.csv"))
  hash_df
}

aggregate_mean <- function(df, group_cols, value_cols) {
  if (!nrow(df)) return(data.frame())
  groups <- df[group_cols]
  for (nm in group_cols) groups[[nm]] <- clean_group_value(groups[[nm]])
  values <- df[value_cols]
  out <- stats::aggregate(values, by = groups, FUN = function(x) {
    x <- suppressWarnings(as.numeric(x))
    if (all(is.na(x))) NA_real_ else mean(x, na.rm = TRUE)
  })
  out$n_rows <- as.integer(stats::aggregate(df[[group_cols[[1L]]]], by = groups, FUN = length)$x)
  out
}

aggregate_flags <- function(df, group_cols, flag_cols) {
  if (!nrow(df)) return(data.frame())
  groups <- df[group_cols]
  for (nm in group_cols) groups[[nm]] <- clean_group_value(groups[[nm]])
  values <- df[flag_cols]
  out <- stats::aggregate(values, by = groups, FUN = all_trueish)
  out
}

rbind_fill <- function(parts) {
  parts <- Filter(function(x) !is.null(x) && nrow(x), parts)
  if (!length(parts)) return(data.frame())
  all_names <- unique(unlist(lapply(parts, names), use.names = FALSE))
  parts <- lapply(parts, function(x) {
    missing <- setdiff(all_names, names(x))
    for (nm in missing) x[[nm]] <- NA
    x[all_names]
  })
  do.call(rbind, parts)
}

add_calibration <- function(df, green_tol, yellow_tol, orange_tol) {
  df$coverage_level_numeric <- suppressWarnings(as.numeric(df$coverage_level))
  df$coverage_error <- suppressWarnings(as.numeric(df$empirical_coverage)) - df$coverage_level_numeric
  abs_err <- abs(df$coverage_error)
  df$calibration_class <- ifelse(
    !is.finite(abs_err), "missing",
    ifelse(abs_err <= green_tol, "green",
      ifelse(abs_err <= yellow_tol, "yellow",
        ifelse(abs_err <= orange_tol, "orange", "red")
      )
    )
  )
  df
}

paired_baseline_deltas <- function(metrics) {
  key <- c("stage_id", "family_id", "replicate_id", "coverage_level")
  baseline_cols <- c(
    key,
    "scenario_id",
    "empirical_coverage",
    "mean_width",
    "interval_score_mean",
    "midpoint_mae",
    "endpoint_mae"
  )
  baseline <- metrics[as.character(metrics$inference) == "baseline", baseline_cols, drop = FALSE]
  names(baseline) <- ifelse(names(baseline) %in% key, names(baseline), paste0(names(baseline), "_baseline"))
  model <- metrics[as.character(metrics$inference) != "baseline", , drop = FALSE]
  paired <- merge(model, baseline, by = key, all.x = TRUE, sort = FALSE)
  paired$interval_score_delta <- paired$interval_score_mean - paired$interval_score_mean_baseline
  paired$interval_score_pct_improvement <- 100 * (paired$interval_score_mean_baseline - paired$interval_score_mean) /
    abs(paired$interval_score_mean_baseline)
  paired$coverage_delta_vs_baseline <- paired$empirical_coverage - paired$empirical_coverage_baseline
  paired$nominal_coverage_error <- paired$empirical_coverage - suppressWarnings(as.numeric(paired$coverage_level))
  paired$baseline_nominal_coverage_error <- paired$empirical_coverage_baseline - suppressWarnings(as.numeric(paired$coverage_level))
  paired$width_ratio_vs_baseline <- paired$mean_width / paired$mean_width_baseline
  paired$midpoint_mae_delta_vs_baseline <- paired$midpoint_mae - paired$midpoint_mae_baseline
  paired$endpoint_mae_delta_vs_baseline <- paired$endpoint_mae - paired$endpoint_mae_baseline
  paired
}

candidate_summary <- function(metrics, paired, green_tol, yellow_tol, orange_tol) {
  group_cols <- c("stage_id", "family_id", "coverage_level", "backend_id", "inference", "prior_type", "learning_rate", "design_id")
  value_cols <- c("empirical_coverage", "mean_width", "interval_score_mean", "midpoint_mae", "endpoint_mae", "runtime_sec")
  model <- metrics[as.character(metrics$inference) != "baseline", , drop = FALSE]
  summary <- aggregate_mean(model, group_cols, value_cols)
  flags <- aggregate_flags(model, group_cols, c("finite_lower", "finite_upper", "ordered_intervals", "positive_mean_width"))
  summary <- merge(summary, flags, by = group_cols, all.x = TRUE, sort = FALSE)

  delta_cols <- c(
    "interval_score_delta",
    "interval_score_pct_improvement",
    "coverage_delta_vs_baseline",
    "nominal_coverage_error",
    "baseline_nominal_coverage_error",
    "width_ratio_vs_baseline",
    "midpoint_mae_delta_vs_baseline",
    "endpoint_mae_delta_vs_baseline"
  )
  deltas <- aggregate_mean(paired, group_cols, delta_cols)
  names(deltas)[names(deltas) == "n_rows"] <- "paired_rows"
  summary <- merge(summary, deltas, by = group_cols, all.x = TRUE, sort = FALSE)
  add_calibration(summary, green_tol, yellow_tol, orange_tol)
}

baseline_summary <- function(metrics) {
  group_cols <- c("stage_id", "family_id", "coverage_level", "backend_id", "inference", "prior_type", "learning_rate", "design_id")
  value_cols <- c("empirical_coverage", "mean_width", "interval_score_mean", "midpoint_mae", "endpoint_mae", "runtime_sec")
  base <- metrics[as.character(metrics$inference) == "baseline", , drop = FALSE]
  aggregate_mean(base, group_cols, value_cols)
}

recommendation_class <- function(row) {
  if (!isTRUE(row$finite_lower) || !isTRUE(row$finite_upper) ||
    !isTRUE(row$ordered_intervals) || !isTRUE(row$positive_mean_width)) {
    return("hold_for_health_repair")
  }
  if (!is.finite(row$interval_score_delta) || row$interval_score_delta >= 0) {
    return("hold_no_baseline_improvement")
  }
  if (row$calibration_class %in% c("green", "yellow")) {
    return("promote_to_targeted_confirmation")
  }
  if (identical(row$calibration_class, "orange")) {
    return("confirmation_required_coverage_material")
  }
  "hold_for_calibration_repair"
}

winner_map <- function(candidates) {
  eligible <- candidates[as.character(candidates$inference) == "mcmc", , drop = FALSE]
  if (!nrow(eligible)) return(data.frame())
  split_key <- paste(eligible$stage_id, eligible$family_id, eligible$coverage_level, sep = "\r")
  groups <- split(eligible, split_key)
  winners <- lapply(groups, function(df) {
    df <- df[order(df$interval_score_mean, na.last = TRUE), , drop = FALSE]
    unconstrained <- df[1L, , drop = FALSE]
    cal_pool <- df[df$calibration_class %in% c("green", "yellow"), , drop = FALSE]
    selected <- if (nrow(cal_pool)) {
      cal_pool[order(cal_pool$interval_score_mean, na.last = TRUE), , drop = FALSE][1L, , drop = FALSE]
    } else {
      unconstrained
    }
    selected$unconstrained_prior_type <- unconstrained$prior_type[1L]
    selected$unconstrained_learning_rate <- unconstrained$learning_rate[1L]
    selected$unconstrained_design_id <- unconstrained$design_id[1L]
    selected$unconstrained_interval_score_mean <- unconstrained$interval_score_mean[1L]
    selected_key <- paste(selected$design_id, selected$prior_type, selected$learning_rate, sep = "\r")
    unconstrained_key <- paste(unconstrained$design_id, unconstrained$prior_type, unconstrained$learning_rate, sep = "\r")
    selected$selected_is_unconstrained_score_winner <- identical(selected_key, unconstrained_key)
    selected$recommendation_class <- vapply(seq_len(nrow(selected)), function(ii) recommendation_class(selected[ii, , drop = FALSE]), character(1))
    selected
  })
  out <- do.call(rbind, winners)
  rownames(out) <- NULL
  out
}

contextualize_winner_recommendations <- function(winners, audit_context) {
  if (!nrow(winners)) return(winners)
  if (identical(audit_context, "targeted_confirmation")) {
    promote <- as.character(winners$recommendation_class) == "promote_to_targeted_confirmation"
    winners$recommendation_class[promote] <- "confirmed_for_cautious_article_draft"
  }
  winners
}

coverage_by_replicate <- function(metrics, green_tol, yellow_tol, orange_tol) {
  out <- metrics
  out$coverage_level_numeric <- suppressWarnings(as.numeric(out$coverage_level))
  out$coverage_error <- out$empirical_coverage - out$coverage_level_numeric
  out <- add_calibration(out, green_tol, yellow_tol, orange_tol)
  out[, c(
    "scenario_id", "stage_id", "family_id", "replicate_id", "coverage_level",
    "backend_id", "inference", "prior_type", "learning_rate", "design_id",
    "empirical_coverage", "coverage_error", "calibration_class",
    "mean_width", "interval_score_mean"
  ), drop = FALSE]
}

coverage_flags <- function(candidate_df) {
  candidate_df[candidate_df$calibration_class %in% c("orange", "red", "missing"), , drop = FALSE]
}

mcmc_diagnostic_summary <- function(inputs) {
  diag <- merge(inputs$mcmc_diagnostics, inputs$launch_manifest, by = "scenario_id", all.x = TRUE, sort = FALSE, suffixes = c("", "_manifest"))
  diag$loss_finite <- is.finite(suppressWarnings(as.numeric(diag$loss_first))) &
    is.finite(suppressWarnings(as.numeric(diag$loss_last))) &
    is.finite(suppressWarnings(as.numeric(diag$loss_tail_mean)))
  diag$sentinel_chain_bool <- vapply(diag$sentinel_chain, truthy, logical(1))
  diag$rhs_expected <- as.character(diag$prior_type) == "rhs_ns"
  diag$rhs_available_bool <- vapply(diag$rhs_stats_available, truthy, logical(1))
  diag$response_likelihood_bool <- vapply(diag$response_likelihood, truthy, logical(1))
  diag$generalized_bayes_bool <- vapply(diag$generalized_bayes, truthy, logical(1))
  group_cols <- c("stage_id", "family_id", "design_id", "prior_type", "learning_rate")
  groups <- diag[group_cols]
  for (nm in group_cols) groups[[nm]] <- clean_group_value(groups[[nm]])
  summary <- stats::aggregate(
    diag[c("loss_finite", "sentinel_chain_bool", "rhs_available_bool", "response_likelihood_bool", "generalized_bayes_bool")],
    by = groups,
    FUN = function(x) mean(as.numeric(x), na.rm = TRUE)
  )
  summary$n_rows <- as.integer(stats::aggregate(diag$scenario_id, by = groups, FUN = length)$x)
  summary$loss_all_finite <- summary$loss_finite == 1
  summary$sentinel_chain_rows <- round(summary$sentinel_chain_bool * summary$n_rows)
  summary$response_likelihood_rows <- round(summary$response_likelihood_bool * summary$n_rows)
  summary$generalized_bayes_all_true <- summary$generalized_bayes_bool == 1
  summary$diagnostic_status <- ifelse(
    summary$loss_all_finite &
      summary$sentinel_chain_rows == 0L &
      summary$response_likelihood_rows == 0L &
      summary$generalized_bayes_all_true,
    "pass",
    "review"
  )
  summary
}

mcmc_diagnostic_flags <- function(summary) {
  summary[as.character(summary$diagnostic_status) != "pass", , drop = FALSE]
}

vb_sidecar_summary <- function(inputs, candidates, winners) {
  vb <- merge(inputs$vb_diagnostics, inputs$launch_manifest, by = "scenario_id", all.x = TRUE, sort = FALSE)
  vb <- merge(vb, inputs$interval_metrics, by = "scenario_id", all.x = TRUE, sort = FALSE, suffixes = c("_manifest", ""))
  group_cols <- c("stage_id", "family_id", "design_id", "coverage_level", "prior_type", "learning_rate")
  if (!nrow(vb)) {
    return(data.frame(
      stage_id = character(0),
      family_id = character(0),
      coverage_level = character(0),
      design_id = character(0),
      prior_type = character(0),
      learning_rate = character(0),
      interval_score_mean = numeric(0),
      empirical_coverage = numeric(0),
      mean_width = numeric(0),
      midpoint_mae = numeric(0),
      runtime_sec = numeric(0),
      n_rows = integer(0),
      convergence_rate = numeric(0),
      max_delta_last = numeric(0),
      best_mcmc_interval_score_mean = numeric(0),
      best_mcmc_empirical_coverage = numeric(0),
      best_mcmc_mean_width = numeric(0),
      interval_score_delta_vs_best_mcmc = numeric(0),
      width_ratio_vs_best_mcmc = numeric(0),
      caveat_label = character(0),
      stringsAsFactors = FALSE
    ))
  }
  groups <- vb[group_cols]
  for (nm in group_cols) groups[[nm]] <- clean_group_value(groups[[nm]])
  values <- vb[c("interval_score_mean", "empirical_coverage", "mean_width", "midpoint_mae", "runtime_sec")]
  summary <- stats::aggregate(values, by = groups, FUN = function(x) {
    x <- suppressWarnings(as.numeric(x))
    if (all(is.na(x))) NA_real_ else mean(x, na.rm = TRUE)
  })
  summary$n_rows <- as.integer(stats::aggregate(vb$scenario_id, by = groups, FUN = length)$x)
  summary$convergence_rate <- as.numeric(stats::aggregate(vapply(vb$converged, truthy, logical(1)), by = groups, FUN = mean)$x)
  summary$max_delta_last <- as.numeric(stats::aggregate(suppressWarnings(as.numeric(vb$delta_last)), by = groups, FUN = function(x) {
    if (all(is.na(x))) NA_real_ else max(x, na.rm = TRUE)
  })$x)
  best <- winners[, c("stage_id", "family_id", "coverage_level", "interval_score_mean", "empirical_coverage", "mean_width"), drop = FALSE]
  names(best)[names(best) %in% c("interval_score_mean", "empirical_coverage", "mean_width")] <-
    paste0("best_mcmc_", names(best)[names(best) %in% c("interval_score_mean", "empirical_coverage", "mean_width")])
  summary <- merge(summary, best, by = c("stage_id", "family_id", "coverage_level"), all.x = TRUE, sort = FALSE)
  summary$interval_score_delta_vs_best_mcmc <- summary$interval_score_mean - summary$best_mcmc_interval_score_mean
  summary$width_ratio_vs_best_mcmc <- summary$mean_width / summary$best_mcmc_mean_width
  summary$caveat_label <- ifelse(
    summary$convergence_rate < 1, "sidecar_not_primary_some_nonconvergence",
    ifelse(summary$interval_score_delta_vs_best_mcmc > 0, "sidecar_not_primary_worse_than_mcmc", "sidecar_review")
  )
  summary
}

stage_claim_contract <- function(inputs) {
  stages <- unique(inputs$launch_manifest[, c("stage_id", "family_id"), drop = FALSE])
  stages$endpoint_oracle_available <- stages$stage_id == "fixed_design_calibration"
  stages$allowed_claim <- ifelse(
    stages$endpoint_oracle_available,
    "central interval endpoint recovery and held-out interval scoring under fixed-design DGPs",
    "teacher-forced held-out interval forecast scoring for DESN readouts"
  )
  stages$forbidden_claim <- ifelse(
    stages$endpoint_oracle_available,
    "full response predictive likelihood or recursive response simulation",
    "oracle endpoint recovery, full response predictive likelihood, or recursive response simulation"
  )
  stages
}

targeted_confirmation_grid <- function(candidates, winners) {
  if (!nrow(winners)) return(data.frame())
  rows <- list()
  idx <- 1L
  for (ii in seq_len(nrow(winners))) {
    w <- winners[ii, , drop = FALSE]
    cell <- candidates[
      candidates$stage_id == w$stage_id &
        candidates$family_id == w$family_id &
        candidates$coverage_level == w$coverage_level &
        candidates$inference == "mcmc",
      ,
      drop = FALSE
    ]
    add_role <- function(row, role) {
      row$confirmation_role <- role
      row
    }
    rows[[idx]] <- add_role(w, "winner")
    idx <- idx + 1L
    cal <- cell[order(abs(cell$coverage_error), cell$interval_score_mean, na.last = TRUE), , drop = FALSE]
    if (nrow(cal)) {
      rows[[idx]] <- add_role(cal[1L, , drop = FALSE], "nearest_nominal_coverage")
      idx <- idx + 1L
    }
    score <- cell[order(cell$interval_score_mean, na.last = TRUE), , drop = FALSE]
    if (nrow(score) > 1L) {
      rows[[idx]] <- add_role(score[2L, , drop = FALSE], "score_runner_up")
      idx <- idx + 1L
    }
  }
  out <- unique(rbind_fill(rows))
  rownames(out) <- NULL
  out
}

write_vb_notes <- function(vb_summary, path) {
  converged <- if (nrow(vb_summary)) {
    sum(round(vb_summary$convergence_rate * vb_summary$n_rows), na.rm = TRUE)
  } else {
    0
  }
  total <- if (nrow(vb_summary)) sum(vb_summary$n_rows, na.rm = TRUE) else 0
  lines <- c(
    "# RQR-DESN VB Sidecar Caveats",
    "",
    sprintf("- VB grouped rows: `%d`", nrow(vb_summary)),
    sprintf("- VB scenario rows represented: `%d`", total),
    sprintf("- Approximate converged scenario rows: `%d`", converged),
    "",
    "VB uncertainty is not calibrated in this broad run. These rows are retained",
    "as sidecar diagnostics and should not be used as primary article evidence.",
    "A separate VB calibration study is required before promoting VB uncertainty",
    "claims."
  )
  writeLines(lines, path)
}

write_guardrails <- function(stage_contract, path) {
  lines <- c(
    "# RQR-DESN Article Claim Guardrails",
    "",
    "The broad results audit is package-side interval evidence. It does not by",
    "itself authorize article updates.",
    "",
    "Allowed later, after targeted confirmation:",
    "",
    "- describe RQR-DESN as an interval-readout extension;",
    "- report MCMC interval-score, coverage, width, and baseline-delta evidence;",
    "- separate fixed-design oracle endpoint recovery from dynamic held-out interval",
    "  scoring.",
    "",
    "Avoid:",
    "",
    "- calling the broad run a response predictive likelihood validation;",
    "- claiming posterior predictive response draws;",
    "- claiming recursive response simulation;",
    "- using VB as primary uncertainty evidence without a separate calibration study."
  )
  writeLines(lines, path)
}

promotion_recommendation <- function(preflight, winners, audit_context = "broad_screen") {
  clean <- all(as.character(preflight$status) == "pass")
  all_improve <- nrow(winners) > 0L && all(winners$interval_score_delta < 0, na.rm = TRUE)
  red <- sum(winners$calibration_class == "red", na.rm = TRUE)
  orange <- sum(winners$calibration_class == "orange", na.rm = TRUE)
  yellow <- sum(winners$calibration_class == "yellow", na.rm = TRUE)
  green <- sum(winners$calibration_class == "green", na.rm = TRUE)
  passed_confirmation <- clean && all_improve && red == 0L
  recommendation <- if (passed_confirmation && identical(audit_context, "targeted_confirmation")) {
    "prepare_cautious_article_or_supplement_draft"
  } else if (passed_confirmation) {
    "promote_to_targeted_confirmation"
  } else if (clean && all_improve) {
    "hold_for_calibration_repair"
  } else {
    "hold_for_audit_repair"
  }
  article_update_allowed <- FALSE
  reason <- if (identical(recommendation, "prepare_cautious_article_or_supplement_draft")) {
    "The targeted confirmation run is clean and MCMC winners beat the empirical baseline; a scoped article or supplement draft is now defensible, but automatic article edits remain blocked until explicitly requested."
  } else if (identical(recommendation, "promote_to_targeted_confirmation")) {
    "The broad run is clean and MCMC winners beat the empirical baseline, but the frozen contract blocks article promotion until targeted confirmation."
  } else {
    "The broad run needs repair or calibration review before targeted confirmation."
  }
  list(
    recommendation = recommendation,
    article_update_allowed = article_update_allowed,
    audit_context = audit_context,
    clean_preflight = clean,
    all_winners_improve_over_baseline = all_improve,
    winner_green_count = green,
    winner_yellow_count = yellow,
    winner_orange_count = orange,
    winner_red_count = red,
    reason = reason
  )
}

write_recommendation_md <- function(rec, winners, path) {
  lines <- c(
    "# RQR-DESN Broad Results Promotion Recommendation",
    "",
    sprintf("- recommendation: `%s`", rec$recommendation),
    sprintf("- article_update_allowed: `%s`", rec$article_update_allowed),
    sprintf("- audit_context: `%s`", rec$audit_context),
    sprintf("- clean_preflight: `%s`", rec$clean_preflight),
    sprintf("- all_winners_improve_over_baseline: `%s`", rec$all_winners_improve_over_baseline),
    sprintf("- winner calibration classes: green `%d`, yellow `%d`, orange `%d`, red `%d`",
      rec$winner_green_count, rec$winner_yellow_count, rec$winner_orange_count, rec$winner_red_count
    ),
    "",
    rec$reason,
    "",
    if (identical(rec$recommendation, "prepare_cautious_article_or_supplement_draft")) {
      "Next step: prepare a scoped RQR-DESN article/supplement draft and reader-facing claim audit. Do not edit article files unless explicitly requested."
    } else {
      "Next step: freeze and run targeted confirmation using the candidate grid written by this audit. Do not update the article from the broad run alone."
    },
    "",
    "## Winner Cells",
    ""
  )
  if (nrow(winners)) {
    compact <- winners[, c(
      "stage_id", "family_id", "coverage_level", "design_id", "prior_type",
      "learning_rate", "interval_score_mean", "empirical_coverage",
      "coverage_error", "mean_width", "interval_score_delta",
      "calibration_class", "recommendation_class"
    ), drop = FALSE]
    lines <- c(lines, paste(capture.output(print(compact, row.names = FALSE)), collapse = "\n"))
  }
  writeLines(lines, path)
}

run_results_audit <- function(run_dir, output_dir, green_tol = 0.05, yellow_tol = 0.075, orange_tol = 0.10, fail_on_preflight = TRUE, audit_context = "auto") {
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  inputs <- load_audit_inputs(run_dir)
  audit_context <- infer_audit_context(inputs, audit_context)
  preflight <- preflight_gates(inputs)
  write_csv(preflight, file.path(output_dir, "audit_preflight.csv"))
  input_hashes <- write_input_hashes(inputs$run_dir, output_dir)

  if (isTRUE(fail_on_preflight) && any(as.character(preflight$status) == "fail")) {
    stop("RQR-DESN results audit preflight failed; see audit_preflight.csv.", call. = FALSE)
  }

  paired <- paired_baseline_deltas(inputs$interval_metrics)
  write_csv(paired, file.path(output_dir, "paired_model_baseline_deltas.csv"))

  paired_summary <- aggregate_mean(
    paired,
    c("stage_id", "family_id", "coverage_level", "backend_id", "inference", "prior_type", "learning_rate", "design_id"),
    c(
      "interval_score_delta",
      "interval_score_pct_improvement",
      "coverage_delta_vs_baseline",
      "nominal_coverage_error",
      "baseline_nominal_coverage_error",
      "width_ratio_vs_baseline",
      "midpoint_mae_delta_vs_baseline",
      "endpoint_mae_delta_vs_baseline"
    )
  )
  write_csv(paired_summary, file.path(output_dir, "paired_delta_summary.csv"))

  candidates <- candidate_summary(inputs$interval_metrics, paired, green_tol, yellow_tol, orange_tol)
  write_csv(candidates, file.path(output_dir, "model_candidate_summary.csv"))

  base_summary <- baseline_summary(inputs$interval_metrics)
  write_csv(base_summary, file.path(output_dir, "baseline_summary.csv"))

  winners <- contextualize_winner_recommendations(winner_map(candidates), audit_context)
  write_csv(winners, file.path(output_dir, "winner_map.csv"))
  write_csv(
    winners[, c("stage_id", "family_id", "coverage_level", "calibration_class", "coverage_error", "recommendation_class"), drop = FALSE],
    file.path(output_dir, "winner_map_calibration_notes.csv")
  )

  coverage_rep <- coverage_by_replicate(inputs$interval_metrics, green_tol, yellow_tol, orange_tol)
  write_csv(coverage_rep, file.path(output_dir, "coverage_calibration_by_replicate.csv"))
  write_csv(candidates, file.path(output_dir, "coverage_calibration_summary.csv"))
  write_csv(coverage_flags(candidates), file.path(output_dir, "coverage_calibration_flags.csv"))

  mcmc_summary <- mcmc_diagnostic_summary(inputs)
  write_csv(mcmc_summary, file.path(output_dir, "mcmc_diagnostic_summary.csv"))
  write_csv(mcmc_diagnostic_flags(mcmc_summary), file.path(output_dir, "mcmc_diagnostic_flags.csv"))

  vb_summary <- vb_sidecar_summary(inputs, candidates, winners)
  write_csv(vb_summary, file.path(output_dir, "vb_sidecar_summary.csv"))
  vb_delta_cols <- c(
    "stage_id", "family_id", "design_id", "coverage_level", "interval_score_mean",
    "best_mcmc_interval_score_mean", "interval_score_delta_vs_best_mcmc",
    "mean_width", "best_mcmc_mean_width", "width_ratio_vs_best_mcmc", "caveat_label"
  )
  write_csv(vb_summary[, vb_delta_cols, drop = FALSE], file.path(output_dir, "vb_vs_mcmc_delta.csv"))
  write_vb_notes(vb_summary, file.path(output_dir, "vb_caveat_notes.md"))

  stage_contract <- stage_claim_contract(inputs)
  write_csv(stage_contract, file.path(output_dir, "stage_specific_claim_contract.csv"))
  write_guardrails(stage_contract, file.path(output_dir, "article_claim_guardrails.md"))

  confirmation_grid <- targeted_confirmation_grid(candidates, winners)
  write_csv(confirmation_grid, file.path(output_dir, "targeted_confirmation_candidate_grid.csv"))

  rec <- promotion_recommendation(preflight, winners, audit_context = audit_context)
  write_recommendation_md(rec, winners, file.path(output_dir, "promotion_recommendation.md"))
  write_json_object(rec, file.path(output_dir, "promotion_recommendation.json"))

  metadata <- list(
    created_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"),
    run_dir = inputs$run_dir,
    output_dir = normalizePath(output_dir, mustWork = FALSE),
    audit_context = audit_context,
    interval_metric_rows = nrow(inputs$interval_metrics),
    mcmc_diagnostic_rows = nrow(inputs$mcmc_diagnostics),
    vb_diagnostic_rows = nrow(inputs$vb_diagnostics),
    preflight_failures = sum(preflight$status == "fail"),
    winner_rows = nrow(winners),
    input_hash_rows = nrow(input_hashes),
    green_tolerance = green_tol,
    yellow_tolerance = yellow_tol,
    orange_tolerance = orange_tol
  )
  write_json_object(metadata, file.path(output_dir, "audit_metadata.json"))

  invisible(list(
    preflight = preflight,
    paired = paired,
    candidates = candidates,
    winners = winners,
    vb_summary = vb_summary,
    recommendation = rec
  ))
}

audit_main <- function(args = commandArgs(trailingOnly = TRUE)) {
  cli <- parse_cli(args)
  root <- repo_root()
  run_dir <- cli[["run-dir"]] %||% latest_run_dir(root)
  run_dir <- normalizePath(run_dir, mustWork = TRUE)
  stamp <- format(Sys.time(), "%Y%m%d-%H%M%S")
  output_dir <- cli[["output-dir"]] %||% file.path(
    root,
    "reports",
    "rqr_desn_broad_simulation",
    sprintf("results_audit_promotion_%s_%s", stamp, basename(run_dir))
  )
  green_tol <- as_num(cli[["green-tol"]], 0.05)
  yellow_tol <- as_num(cli[["yellow-tol"]], 0.075)
  orange_tol <- as_num(cli[["orange-tol"]], 0.10)
  fail_on_preflight <- as_flag(cli[["fail-on-preflight"]], TRUE)
  audit_context <- cli[["audit-context"]] %||% "auto"
  result <- run_results_audit(
    run_dir = run_dir,
    output_dir = output_dir,
    green_tol = green_tol,
    yellow_tol = yellow_tol,
    orange_tol = orange_tol,
    fail_on_preflight = fail_on_preflight,
    audit_context = audit_context
  )
  message(sprintf("RQR-DESN results audit wrote %d winner rows to %s", nrow(result$winners), output_dir))
  message(sprintf("Recommendation: %s", result$recommendation$recommendation))
  invisible(output_dir)
}

if (sys.nframe() == 0L) {
  audit_main()
}

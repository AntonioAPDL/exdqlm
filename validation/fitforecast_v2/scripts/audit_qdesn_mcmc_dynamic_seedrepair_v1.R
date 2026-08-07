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
  x <- as.numeric(x); x <- x[is.finite(x)]
  if (length(x)) stats::median(x) else NA_real_
}
finite_q90 <- function(x) {
  x <- as.numeric(x); x <- x[is.finite(x)]
  if (length(x)) unname(stats::quantile(x, 0.90, names = FALSE, type = 8)) else NA_real_
}
safe_ratio <- function(x, y) ifelse(is.finite(x) & is.finite(y) & y > 0, x / y, NA_real_)

stage <- "qdesn_dynamic_fitforecast_v2_500obs_mcmc_dynamic_seedrepair_v1"
stub <- file.path("config", "validation", stage)
profiles <- read_csv(paste0(stub, "_profiles.csv"))
grid <- read_csv(paste0(stub, "_discovery_grid.csv"))
expected <- read_csv(paste0(stub, "_discovery_target_spec_ids.csv"))
defaults <- yaml::read_yaml(resolve_path(paste0(stub, "_discovery_defaults.yaml")))
state_root_arg <- as.character(get_arg("--state-root", ""))[1L]
state_root <- if (nzchar(state_root_arg)) resolve_path(state_root_arg) else NULL
env <- if (!is.null(state_root)) read_env(file.path(state_root, "run_tags.env")) else character()
run_tag <- as.character(get_arg("--run-tag", unname(env[["DISCOVERY_RUN_TAG"]] %||% "")))[1L]
if (!nzchar(run_tag)) stop("A discovery run tag is required.", call. = FALSE)
output_root <- resolve_path(get_arg(
  "--output-root",
  if (!is.null(state_root)) file.path(state_root, "closeout") else
    file.path("reports", "qdesn_mcmc_validation", stage, "manual_closeout")
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
  method_dir <- dirname(path)
  horizon_path <- file.path(method_dir, "tables", "forecast_horizon_summary.csv")
  horizon <- if (file.exists(horizon_path)) {
    tryCatch(utils::read.csv(horizon_path, check.names = FALSE, stringsAsFactors = FALSE), error = function(e) NULL)
  } else NULL
  h1000 <- NULL
  if (!is.null(horizon) && nrow(horizon)) {
    idx <- which(as.integer(horizon$horizon) == 1000L | as.character(horizon$window) == "forecast_H1000")
    if (length(idx)) h1000 <- horizon[idx[[1L]], , drop = FALSE]
  }
  request_path <- file.path(method_dir, "fit_request.json")
  request <- if (file.exists(request_path)) jsonlite::read_json(request_path, simplifyVector = TRUE) else list()
  fit$run_tag <- run_tag
  fit$fit_summary_path <- normalizePath(path, winslash = "/", mustWork = TRUE)
  fit$fit_summary_sha256 <- unname(tools::sha256sum(path))
  fit$forecast_horizon_path <- if (file.exists(horizon_path)) normalizePath(horizon_path, winslash = "/", mustWork = TRUE) else NA_character_
  fit$forecast_horizon_sha256 <- if (file.exists(horizon_path)) unname(tools::sha256sum(horizon_path)) else NA_character_
  fit$fit_request_path <- if (file.exists(request_path)) normalizePath(request_path, winslash = "/", mustWork = TRUE) else NA_character_
  fit$fit_request_sha256 <- if (file.exists(request_path)) unname(tools::sha256sum(request_path)) else NA_character_
  fit$observed_desn_seed <- as.integer(request$config$desn$seed %||% NA_integer_)
  fit$observed_mcmc_seed <- as.integer(request$config$inference$mcmc$control$seed %||% NA_integer_)
  fit$observed_mcmc_rng_seed <- as.integer(request$config$inference$mcmc$control$rng_seed %||% NA_integer_)
  fit$observed_vb_warm_start_seed <- as.integer(request$config$inference$mcmc$vb_warm_start_seed %||% NA_integer_)
  fit$observed_synthesis_seed <- as.integer(request$config$synthesis$seed %||% NA_integer_)
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
unexpected <- data.frame(spec_id = setdiff(observed_ids, expected_ids), stringsAsFactors = FALSE)

heavy_paths <- if (dir.exists(run_root)) {
  list.files(run_root, pattern = "[.](rds|rda|RData)$", recursive = TRUE, full.names = TRUE, ignore.case = TRUE)
} else character()
heavy <- if (length(heavy_paths)) data.frame(
  path = normalizePath(heavy_paths, winslash = "/", mustWork = TRUE),
  bytes = as.numeric(file.info(heavy_paths)$size), stringsAsFactors = FALSE
) else data.frame(path = character(), bytes = numeric())

profile_keep <- c(
  "screening_profile_id", "target_cell_id", "target_metrics", "likelihood_target",
  "target_family", "target_tau", "parent_profile_id", "parent_candidate_id",
  "candidate_id", "arm_code", "design_role", "topology_search_mode", "topology_mode",
  "reservoir_replicate", "paired_reservoir_seed", "comparison_role", "D", "n_each",
  "m", "alpha", "rho", "pi_w", "pi_in", "rhs_tau0", "topology_contract_version"
)
if (nrow(metrics)) {
  join_keep <- c("screening_profile_id", setdiff(profile_keep, c("screening_profile_id", names(metrics))))
  metrics <- merge(metrics, profiles[, join_keep, drop = FALSE], by = "screening_profile_id", all.x = TRUE, sort = FALSE)
  if (!"source_scenario" %in% names(metrics) && "scenario" %in% names(metrics)) {
    metrics$source_scenario <- as.character(metrics$scenario)
  }
}

grid_seeds <- grid[, c(
  "root_id", "screening_profile_id", "desn_seed", "mcmc_seed", "mcmc_rng_seed",
  "vb_warm_start_seed", "synthesis_seed", "sampler_pair_id"
), drop = FALSE]
names(grid_seeds)[!names(grid_seeds) %in% c("root_id", "screening_profile_id")] <- paste0(
  "expected_", names(grid_seeds)[!names(grid_seeds) %in% c("root_id", "screening_profile_id")]
)
metrics <- merge(metrics, grid_seeds, by = c("root_id", "screening_profile_id"), all.x = TRUE, sort = FALSE)
metrics$seed_contract_match <- with(metrics,
  observed_desn_seed == expected_desn_seed &
    observed_mcmc_seed == expected_mcmc_seed &
    observed_mcmc_rng_seed == expected_mcmc_rng_seed &
    observed_vb_warm_start_seed == expected_vb_warm_start_seed &
    observed_synthesis_seed == expected_synthesis_seed
)

metrics_path <- write_csv(metrics, file.path(output_root, "discovery_metrics.csv"))
missing_path <- write_csv(missing, file.path(output_root, "missing_spec_ids.csv"))
unexpected_path <- write_csv(unexpected, file.path(output_root, "unexpected_spec_ids.csv"))
heavy_path <- write_csv(heavy, file.path(output_root, "storage_heavy_artifact_audit.csv"))
seed_audit_path <- write_csv(metrics[, c(
  "spec_id", "root_id", "screening_profile_id", "target_cell_id", "source_scenario",
  "comparison_role", "reservoir_replicate", "expected_desn_seed", "observed_desn_seed",
  "expected_mcmc_seed", "observed_mcmc_seed", "expected_mcmc_rng_seed",
  "observed_mcmc_rng_seed", "expected_vb_warm_start_seed", "observed_vb_warm_start_seed",
  "expected_synthesis_seed", "observed_synthesis_seed", "seed_contract_match",
  "fit_request_path", "fit_request_sha256"
), drop = FALSE], file.path(output_root, "executed_seed_contract_audit.csv"))

candidate <- metrics[metrics$comparison_role == "candidate", , drop = FALSE]
dynamic_parent <- metrics[metrics$comparison_role == "dynamic_parent", c(
  "target_cell_id", "source_scenario", "reservoir_replicate", "metric_fit_rmse",
  "metric_forecast_mae", "metric_forecast_check", "spec_id", "signoff_grade"
), drop = FALSE]
names(dynamic_parent) <- c(
  "target_cell_id", "source_scenario", "reservoir_replicate", "baseline_fit_rmse",
  "baseline_forecast_mae", "baseline_forecast_check", "baseline_spec_id", "baseline_signoff_grade"
)
authority_parent <- metrics[metrics$comparison_role == "authority_parent", c(
  "target_cell_id", "source_scenario", "metric_fit_rmse", "metric_forecast_mae",
  "metric_forecast_check", "spec_id", "signoff_grade"
), drop = FALSE]
names(authority_parent) <- c(
  "target_cell_id", "source_scenario", "baseline_fit_rmse", "baseline_forecast_mae",
  "baseline_forecast_check", "baseline_spec_id", "baseline_signoff_grade"
)

make_pairs <- function(parent, by, comparison) {
  out <- merge(candidate, parent, by = by, all.x = TRUE, sort = FALSE)
  out$fit_ratio <- safe_ratio(out$metric_fit_rmse, out$baseline_fit_rmse)
  out$forecast_mae_ratio <- safe_ratio(out$metric_forecast_mae, out$baseline_forecast_mae)
  out$forecast_check_ratio <- safe_ratio(out$metric_forecast_check, out$baseline_forecast_check)
  out$pair_complete <- is.finite(out$fit_ratio) & is.finite(out$forecast_mae_ratio) & is.finite(out$forecast_check_ratio)
  out$comparison <- comparison
  out
}
within_pairs <- make_pairs(
  dynamic_parent, c("target_cell_id", "source_scenario", "reservoir_replicate"), "same_dynamic_seed_parent"
)
authority_pairs <- make_pairs(
  authority_parent, c("target_cell_id", "source_scenario"), "frozen_authority_parent"
)
within_path <- write_csv(within_pairs, file.path(output_root, "paired_same_dynamic_seed_metrics.csv"))
authority_path <- write_csv(authority_pairs, file.path(output_root, "paired_frozen_authority_metrics.csv"))

summarize_pairs <- function(pairs, comparison) {
  groups <- split(seq_len(nrow(pairs)), paste(pairs$target_cell_id, pairs$candidate_id, sep = "\r"))
  rows <- lapply(groups, function(idx) {
    x <- pairs[idx, , drop = FALSE]
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
    target_ratio <- x$forecast_mae_ratio
    seed_medians <- vapply(split(target_ratio, x$reservoir_replicate), finite_median, numeric(1L))
    source_medians <- vapply(split(target_ratio, x$source_scenario), finite_median, numeric(1L))
    data.frame(
      comparison = comparison,
      target_cell_id = x$target_cell_id[[1L]],
      target_metrics = x$target_metrics[[1L]],
      likelihood_target = x$likelihood_target[[1L]],
      target_family = x$target_family[[1L]],
      target_tau = as.numeric(x$target_tau[[1L]]),
      candidate_id = x$candidate_id[[1L]],
      arm_code = x$arm_code[[1L]],
      D = as.integer(x$D[[1L]]), n_each = as.integer(x$n_each[[1L]]), m = as.integer(x$m[[1L]]),
      alpha = as.numeric(x$alpha[[1L]]), rho = as.numeric(x$rho[[1L]]),
      pi_w = as.numeric(x$pi_w[[1L]]), pi_in = as.numeric(x$pi_in[[1L]]),
      rhs_tau0 = as.numeric(x$rhs_tau0[[1L]]),
      n_expected_pairs = 9L,
      n_complete_pairs = sum(x$pair_complete, na.rm = TRUE),
      median_fit_ratio = med[["fit_qtrue_rmse"]],
      median_forecast_mae_ratio = med[["forecast_qtrue_mae_H1000"]],
      median_forecast_check_ratio = med[["forecast_check_loss_H1000"]],
      worst_target_median_ratio = max(med[target_idx]),
      worst_companion_median_ratio = max(med[!target_idx]),
      worst_target_q90_ratio = max(q90[target_idx]),
      n_target_improved_pairs = sum(is.finite(target_ratio) & target_ratio <= 1),
      n_reservoir_seeds_target_median_improved = sum(is.finite(seed_medians) & seed_medians <= 1),
      n_sources_target_median_improved = sum(is.finite(source_medians) & source_medians <= 1),
      stringsAsFactors = FALSE
    )
  })
  out <- do.call(rbind, rows)
  out$comparison_gate_pass <- out$n_complete_pairs == 9L &
    out$worst_target_median_ratio <= 0.98 &
    out$worst_companion_median_ratio <= 1.05 &
    out$worst_target_q90_ratio <= 1.10 &
    out$n_target_improved_pairs >= 6L &
    out$n_reservoir_seeds_target_median_improved >= 2L &
    out$n_sources_target_median_improved >= 2L
  out
}
within_summary <- summarize_pairs(within_pairs, "same_dynamic_seed_parent")
authority_summary <- summarize_pairs(authority_pairs, "frozen_authority_parent")
within_summary_path <- write_csv(within_summary, file.path(output_root, "same_seed_candidate_summary.csv"))
authority_summary_path <- write_csv(authority_summary, file.path(output_root, "authority_candidate_summary.csv"))

summary <- merge(
  within_summary, authority_summary,
  by = c("target_cell_id", "target_metrics", "likelihood_target", "target_family", "target_tau",
    "candidate_id", "arm_code", "D", "n_each", "m", "alpha", "rho", "pi_w", "pi_in", "rhs_tau0"),
  suffixes = c("_within", "_authority"), all = TRUE, sort = FALSE
)
summary$dual_discovery_eligible <- as.logical(summary$comparison_gate_pass_within) &
  as.logical(summary$comparison_gate_pass_authority)
summary$selection_score <- pmax(
  summary$worst_target_median_ratio_within,
  summary$worst_target_median_ratio_authority,
  na.rm = TRUE
)
summary <- summary[order(
  summary$target_cell_id, !summary$dual_discovery_eligible,
  summary$selection_score, summary$alpha, summary$candidate_id
), , drop = FALSE]
summary_path <- write_csv(summary, file.path(output_root, "dual_comparison_candidate_summary.csv"))

eligible <- summary[summary$dual_discovery_eligible %in% TRUE, , drop = FALSE]
finalists <- if (nrow(eligible)) {
  do.call(rbind, lapply(split(seq_len(nrow(eligible)), eligible$target_cell_id), function(idx) {
    x <- eligible[idx, , drop = FALSE]
    x[order(x$selection_score, x$alpha, x$candidate_id), , drop = FALSE][seq_len(min(2L, nrow(x))), , drop = FALSE]
  }))
} else summary[FALSE, , drop = FALSE]
finalists_path <- write_csv(finalists, file.path(output_root, "full_budget_confirmation_candidates.csv"))

expected_total <- length(expected_ids)
complete_total <- if (nrow(metrics)) sum(as.logical(metrics$metric_complete), na.rm = TRUE) else 0L
seed_contract_failures <- if (nrow(metrics)) sum(!(metrics$seed_contract_match %in% TRUE)) else expected_total
covered_cells <- sort(unique(as.character(finalists$target_cell_id %||% character())))
target_cells <- sort(unique(profiles$target_cell_id))
if (complete_total < expected_total || nrow(missing) || nrow(unexpected)) {
  decision <- "BLOCK_INCOMPLETE"
  reason <- sprintf("Only %d/%d expected specs have complete metrics.", complete_total, expected_total)
} else if (seed_contract_failures > 0L) {
  decision <- "BLOCK_SEED_CONTRACT"
  reason <- sprintf("Executed seed contract failed for %d fit(s).", seed_contract_failures)
} else if (nrow(heavy) > 0L) {
  decision <- "BLOCK_STORAGE_POLICY"
  reason <- sprintf("Found %d forbidden model payload(s).", nrow(heavy))
} else if (length(setdiff(target_cells, covered_cells)) == 0L) {
  decision <- "GO_FULL_CONFIRMATION_CANDIDATES"
  reason <- "Both target cells have candidates passing the same-seed and frozen-authority discovery gates."
} else if (length(covered_cells)) {
  decision <- "PARTIAL_SIGNAL_CASE_SPECIFIC_CONFIRMATION"
  reason <- sprintf("Dual-gate candidates passed in %d/%d target cells.", length(covered_cells), length(target_cells))
} else {
  decision <- "STOP_NO_DYNAMIC_SEED_ALPHA_SIGNAL"
  reason <- "No alpha candidate passed both the same-seed and frozen-authority discovery gates."
}

gate <- list(
  generated_at = as.character(Sys.time()),
  decision = decision,
  decision_reason = reason,
  run_tag = run_tag,
  run_root = run_root,
  expected_specs = expected_total,
  complete_metric_specs = complete_total,
  completion_fraction = if (expected_total) complete_total / expected_total else 0,
  missing_specs = nrow(missing),
  unexpected_specs = nrow(unexpected),
  seed_contract_failures = seed_contract_failures,
  heavy_payloads = nrow(heavy),
  target_cells = as.list(target_cells),
  cells_with_candidate = as.list(covered_cells),
  finalist_count = nrow(finalists),
  article_update_allowed = FALSE,
  full_confirmation_automatic = FALSE,
  next_gate = "explicit review before any 5000-burn plus 20000-retained confirmation",
  metrics_path = metrics_path,
  seed_audit_path = seed_audit_path,
  same_seed_pairs_path = within_path,
  authority_pairs_path = authority_path,
  same_seed_summary_path = within_summary_path,
  authority_summary_path = authority_summary_path,
  dual_summary_path = summary_path,
  finalists_path = finalists_path,
  storage_audit_path = heavy_path,
  missing_specs_path = missing_path,
  unexpected_specs_path = unexpected_path
)
gate_path <- write_json(gate, file.path(output_root, "dynamic_seedrepair_discovery_gate.json"))
writeLines(c(
  "# Q-DESN MCMC Dynamic Seed-Repair v1 Discovery",
  "",
  sprintf("- decision: `%s`", decision),
  sprintf("- reason: %s", reason),
  sprintf("- complete target specs: `%d/%d`", complete_total, expected_total),
  sprintf("- executed seed-contract failures: `%d`", seed_contract_failures),
  sprintf("- heavy model payloads: `%d`", nrow(heavy)),
  sprintf("- finalist candidates: `%d`", nrow(finalists)),
  "- article update: `not allowed from screening-budget evidence`",
  "- full confirmation: `never automatic`",
  "",
  "Candidates are selected separately within AL and exAL Normal p=0.25 cells.",
  "A candidate must pass both the same-dynamic-seed parent comparison and the frozen-authority",
  "comparison. Each comparison requires all nine pairs, at least 2% median forecast-MAE",
  "improvement, companion medians no worse than 5%, target q90 no worse than 10%, and",
  "favorable target direction in at least six pairs, two reservoir seeds, and two sources.",
  "Finite metrics remain visible regardless of diagnostic signoff, but screening evidence cannot",
  "replace an article result without a separate full-budget confirmation."
), file.path(output_root, "README.md"))

cat(sprintf("Decision: %s\n", decision))
cat(sprintf("Complete metrics: %d/%d (%.1f%%)\n", complete_total, expected_total, 100 * complete_total / expected_total))
cat(sprintf("Dual-gate candidate cells: %d/%d\n", length(covered_cells), length(target_cells)))
cat(sprintf("Finalists: %d\n", nrow(finalists)))
cat(sprintf("Gate: %s\n", gate_path))

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
ratio <- function(x, y) ifelse(is.finite(x) & is.finite(y) & y > 0, x / y, NA_real_)

stage <- "qdesn_dynamic_fitforecast_v2_500obs_alpha_rho_seedrepair_v1"
stub <- file.path("config", "validation", stage)
run_tag <- as.character(get_arg("--run-tag", ""))[1L]
if (!nzchar(run_tag)) stop("--run-tag is required.", call. = FALSE)
output_root <- resolve_path(get_arg(
  "--output-root",
  file.path("reports", "qdesn_mcmc_validation", stage, run_tag, "seedrepair_audit")
), FALSE)
dir.create(output_root, recursive = TRUE, showWarnings = FALSE)

manifest <- jsonlite::read_json(resolve_path(paste0(stub, "_materialization_manifest.json")), simplifyVector = TRUE)
defaults <- yaml::read_yaml(resolve_path(paste0(stub, "_defaults.yaml")))
profiles <- read_csv(paste0(stub, "_profiles.csv"))
grid <- read_csv(paste0(stub, "_grid.csv"))
expected <- read_csv(paste0(stub, "_target_spec_ids.csv"))
validity <- read_csv(paste0(stub, "_historical_actual_seed_candidate_validity.csv"))
coarse_paired <- read_csv(defaults$study_contract$alpha_rho_seedrepair_v1$historical_coarse_paired_metrics_path)
run_root <- resolve_path(file.path(defaults$campaign$results_root, run_tag), FALSE)
if (!dir.exists(run_root)) stop(sprintf("Run root does not exist: %s", run_root), call. = FALSE)

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
  request_path <- file.path(method_dir, "fit_request.json")
  request <- if (file.exists(request_path)) jsonlite::read_json(request_path, simplifyVector = TRUE) else list()
  row$fit_summary_path <- normalizePath(path, winslash = "/", mustWork = TRUE)
  row$fit_summary_sha256 <- unname(tools::sha256sum(path))
  row$forecast_horizon_path <- if (file.exists(horizon_path)) normalizePath(horizon_path, winslash = "/", mustWork = TRUE) else NA_character_
  row$forecast_horizon_sha256 <- if (file.exists(horizon_path)) unname(tools::sha256sum(horizon_path)) else NA_character_
  row$fit_request_path <- if (file.exists(request_path)) normalizePath(request_path, winslash = "/", mustWork = TRUE) else NA_character_
  row$fit_request_sha256 <- if (file.exists(request_path)) unname(tools::sha256sum(request_path)) else NA_character_
  row$observed_desn_seed <- as.integer(request$config$desn$seed %||% NA_integer_)
  row$observed_mcmc_seed <- as.integer(request$config$inference$mcmc$control$seed %||% NA_integer_)
  row$observed_mcmc_rng_seed <- as.integer(request$config$inference$mcmc$control$rng_seed %||% NA_integer_)
  row$observed_vb_warm_start_seed <- as.integer(request$config$inference$mcmc$vb_warm_start_seed %||% NA_integer_)
  row$observed_synthesis_seed <- as.integer(request$config$synthesis$seed %||% NA_integer_)
  row$metric_fit_rmse <- suppressWarnings(as.numeric(row$train_qtrue_rmse[[1L]] %||% NA_real_))
  row$metric_forecast_mae <- if (!is.null(h1000)) suppressWarnings(as.numeric(h1000$qtrue_mae[[1L]])) else NA_real_
  row$metric_forecast_check <- if (!is.null(h1000)) suppressWarnings(as.numeric(h1000$pinball_tau[[1L]])) else NA_real_
  row$metric_complete <- all(is.finite(c(row$metric_fit_rmse, row$metric_forecast_mae, row$metric_forecast_check)))
  row
})
fit_rows <- Filter(Negate(is.null), fit_rows)
metrics <- if (length(fit_rows)) do.call(rbind, fit_rows) else data.frame(stringsAsFactors = FALSE)
lookup <- profiles[, c(
  "screening_profile_id", "candidate_id", "target_cell_id", "target_role",
  "likelihood_target", "target_family", "target_tau", "parent_profile_id",
  "comparison_role", "search_id", "search_dimension", "search_priority",
  "topology_mode", "alpha", "rho", "pi_w", "pi_in", "seed"
), drop = FALSE]
if (nrow(metrics)) {
  metrics <- merge(metrics, lookup, by = "screening_profile_id", all.x = TRUE, sort = FALSE)
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

grid_seed <- grid[, c(
  "root_id", "screening_profile_id", "desn_seed", "mcmc_seed", "mcmc_rng_seed",
  "vb_warm_start_seed", "synthesis_seed", "sampler_pair_id"
), drop = FALSE]
names(grid_seed)[names(grid_seed) != "root_id" & names(grid_seed) != "screening_profile_id"] <- paste0(
  "expected_", names(grid_seed)[names(grid_seed) != "root_id" & names(grid_seed) != "screening_profile_id"]
)
metrics <- merge(metrics, grid_seed, by = c("root_id", "screening_profile_id"), all.x = TRUE, sort = FALSE)
metrics$seed_contract_match <- with(metrics,
  observed_desn_seed == expected_desn_seed &
    observed_mcmc_seed == expected_mcmc_seed &
    observed_mcmc_rng_seed == expected_mcmc_rng_seed &
    observed_vb_warm_start_seed == expected_vb_warm_start_seed &
    observed_synthesis_seed == expected_synthesis_seed
)
metrics_path <- write_csv(metrics, file.path(output_root, "repair_metrics.csv"))
seed_execution_audit_path <- write_csv(metrics[, c(
  "spec_id", "root_id", "screening_profile_id", "target_cell_id", "source_scenario",
  "comparison_role", "expected_desn_seed", "observed_desn_seed",
  "expected_mcmc_seed", "observed_mcmc_seed", "expected_mcmc_rng_seed",
  "observed_mcmc_rng_seed", "expected_vb_warm_start_seed",
  "observed_vb_warm_start_seed", "expected_synthesis_seed", "observed_synthesis_seed",
  "seed_contract_match", "fit_request_path", "fit_request_sha256"
), drop = FALSE], file.path(output_root, "executed_seed_contract_audit.csv"))

candidate <- metrics[metrics$comparison_role == "candidate", , drop = FALSE]
parent <- metrics[metrics$comparison_role == "parent_exact", c(
  "target_cell_id", "source_scenario", "metric_fit_rmse", "metric_forecast_mae",
  "metric_forecast_check", "spec_id", "screening_profile_id", "signoff_grade"
), drop = FALSE]
names(parent) <- c(
  "target_cell_id", "source_scenario", "baseline_fit_rmse", "baseline_forecast_mae",
  "baseline_forecast_check", "baseline_spec_id", "baseline_screening_profile_id", "baseline_signoff_grade"
)
paired_seed2 <- merge(candidate, parent, by = c("target_cell_id", "source_scenario"), all.x = TRUE, sort = FALSE)
paired_seed2$fit_ratio <- ratio(paired_seed2$metric_fit_rmse, paired_seed2$baseline_fit_rmse)
paired_seed2$forecast_mae_ratio <- ratio(paired_seed2$metric_forecast_mae, paired_seed2$baseline_forecast_mae)
paired_seed2$forecast_check_ratio <- ratio(paired_seed2$metric_forecast_check, paired_seed2$baseline_forecast_check)
paired_seed2$pair_complete <- with(paired_seed2,
  is.finite(fit_ratio) & is.finite(forecast_mae_ratio) & is.finite(forecast_check_ratio)
)
paired_seed2$replicate_label <- "corrected_profile_seed2"
paired_seed2_path <- write_csv(paired_seed2, file.path(output_root, "paired_corrected_seed2_metrics.csv"))

retained_ids <- as.character(validity$candidate_id[as.logical(validity$mechanically_valid)])
coarse <- coarse_paired[coarse_paired$candidate_id %in% retained_ids, , drop = FALSE]
coarse$replicate_label <- "historical_actual_seed123"
keep <- c(
  "target_cell_id", "target_role", "likelihood_target", "target_family", "target_tau",
  "candidate_id", "search_id", "search_dimension", "search_priority", "topology_mode",
  "alpha", "rho", "pi_w", "pi_in", "source_scenario", "metric_fit_rmse",
  "metric_forecast_mae", "metric_forecast_check", "baseline_fit_rmse",
  "baseline_forecast_mae", "baseline_forecast_check", "fit_ratio",
  "forecast_mae_ratio", "forecast_check_ratio", "pair_complete", "replicate_label",
  "signoff_grade", "comparison_eligible", "spec_id", "baseline_spec_id"
)
for (nm in setdiff(keep, names(coarse))) coarse[[nm]] <- NA
for (nm in setdiff(keep, names(paired_seed2))) paired_seed2[[nm]] <- NA
combined <- rbind(coarse[, keep, drop = FALSE], paired_seed2[, keep, drop = FALSE])
combined$replicate_index <- ifelse(combined$replicate_label == "historical_actual_seed123", 1L, 2L)
combined_path <- write_csv(combined, file.path(output_root, "paired_two_reservoir_metrics.csv"))

groups <- split(seq_len(nrow(combined)), paste(combined$target_cell_id, combined$candidate_id, sep = "\r"))
summary_rows <- lapply(groups, function(idx) {
  x <- combined[idx, , drop = FALSE]
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
    n_expected_pairs = 6L,
    n_complete_pairs = sum(x$pair_complete, na.rm = TRUE),
    n_reservoir_replicates = length(unique(x$replicate_label[x$pair_complete])),
    median_fit_ratio = med[["fit"]],
    median_forecast_mae_ratio = med[["forecast_mae"]],
    median_forecast_check_ratio = med[["forecast_check"]],
    worst_median_ratio = if (all(is.finite(med))) max(med) else NA_real_,
    mean_median_ratio = if (all(is.finite(med))) mean(med) else NA_real_,
    q90_fit_ratio = q90[["fit"]],
    q90_forecast_mae_ratio = q90[["forecast_mae"]],
    q90_forecast_check_ratio = q90[["forecast_check"]],
    worst_q90_ratio = if (all(is.finite(q90))) max(q90) else NA_real_,
    all_three_median_noninferior = all(med <= 1),
    any_median_improvement_2pct = any(med <= 0.98),
    stringsAsFactors = FALSE
  )
})
candidate_summary <- do.call(rbind, summary_rows)
candidate_summary <- candidate_summary[order(candidate_summary$target_cell_id, candidate_summary$worst_median_ratio, candidate_summary$candidate_id), , drop = FALSE]
candidate_summary_path <- write_csv(candidate_summary, file.path(output_root, "two_reservoir_candidate_summary.csv"))

eligible <- candidate_summary[
  candidate_summary$n_complete_pairs == 6L & candidate_summary$n_reservoir_replicates == 2L &
    candidate_summary$worst_median_ratio <= 1.03 & candidate_summary$worst_q90_ratio <= 1.25 &
    candidate_summary$any_median_improvement_2pct,
  , drop = FALSE
]
objective_candidates <- if (nrow(eligible)) {
  qdesn_arv2_select_objective_candidates(eligible, max_per_cell = 4L)
} else data.frame(stringsAsFactors = FALSE)
objective_candidates_path <- write_csv(objective_candidates, file.path(output_root, "objective_specific_candidates.csv"))

primary_ok <- function(x) {
  role <- as.character(x$target_role[[1L]])
  if (grepl("fit_and", role, fixed = TRUE)) {
    return(x$median_fit_ratio <= 0.98 && min(x$median_forecast_mae_ratio, x$median_forecast_check_ratio) <= 0.98)
  }
  if (grepl("fit_gap", role, fixed = TRUE)) return(x$median_fit_ratio <= 0.98)
  FALSE
}
priority_cells <- c("al_gausmix_t0p05", "al_normal_t0p05", "exal_gausmix_t0p25", "exal_laplace_t0p05")
handoff_pool <- eligible[eligible$target_cell_id %in% priority_cells, , drop = FALSE]
handoff_pool$primary_objective_pass <- vapply(seq_len(nrow(handoff_pool)), function(i) primary_ok(handoff_pool[i, , drop = FALSE]), logical(1L))
handoff_pool <- handoff_pool[handoff_pool$primary_objective_pass, , drop = FALSE]
handoff_rows <- lapply(split(seq_len(nrow(handoff_pool)), handoff_pool$target_cell_id), function(idx) {
  x <- handoff_pool[idx, , drop = FALSE]
  if (!nrow(x)) return(NULL)
  primary_score <- if (grepl("fit_and", x$target_role[[1L]], fixed = TRUE)) {
    pmax(x$median_fit_ratio, pmin(x$median_forecast_mae_ratio, x$median_forecast_check_ratio))
  } else x$median_fit_ratio
  x[order(primary_score, x$worst_median_ratio, x$worst_q90_ratio, x$candidate_id)[[1L]], , drop = FALSE]
})
handoff_rows <- Filter(Negate(is.null), handoff_rows)
handoff <- if (length(handoff_rows)) do.call(rbind, handoff_rows) else data.frame(stringsAsFactors = FALSE)
if (nrow(handoff)) {
  handoff$handoff_status <- "PREPARED_NOT_LAUNCHED"
  handoff$confirmation_budget_n_burn <- 5000L
  handoff$confirmation_budget_n_mcmc <- 20000L
  handoff$confirmation_source <- "frozen_article_protocol_source_origin9000"
  handoff$article_promotion_allowed <- FALSE
}
handoff_path <- write_csv(handoff, file.path(output_root, "full_budget_handoff.csv"))

complete_specs <- sum(as.logical(metrics$metric_complete), na.rm = TRUE)
seed_contract_passes <- sum(as.logical(metrics$seed_contract_match), na.rm = TRUE)
binary_paths <- list.files(run_root, pattern = "[.](rds|rda|RData)$", recursive = TRUE, full.names = TRUE, ignore.case = TRUE)
binary_audit <- data.frame(
  path = normalizePath(binary_paths, winslash = "/", mustWork = FALSE),
  bytes = if (length(binary_paths)) file.info(binary_paths)$size else numeric(0),
  stringsAsFactors = FALSE
)
binary_audit_path <- write_csv(binary_audit, file.path(output_root, "binary_payload_audit.csv"))

decision <- if (length(missing_ids) || length(unexpected_ids) || complete_specs != 48L || seed_contract_passes != 48L) {
  "BLOCK_INCOMPLETE_OR_SEED_CONTRACT_FAILURE"
} else if (length(binary_paths)) {
  "BLOCK_STORAGE_POLICY_FAILURE"
} else if (nrow(handoff)) {
  "FULL_BUDGET_HANDOFF_PREPARED"
} else if (nrow(objective_candidates)) {
  "DEVELOPMENT_CANDIDATES_ONLY_NO_PRIMARY_HANDOFF"
} else {
  "NO_TWO_RESERVOIR_CANDIDATE"
}
gate <- list(
  generated_at = as.character(Sys.time()),
  stage = stage,
  run_tag = run_tag,
  decision = decision,
  expected_specs = 48L,
  observed_specs = length(observed_ids),
  complete_metric_specs = complete_specs,
  seed_contract_passes = seed_contract_passes,
  missing_specs = length(missing_ids),
  unexpected_specs = length(unexpected_ids),
  binary_payloads = length(binary_paths),
  retained_candidate_count = nrow(candidate_summary),
  objective_candidate_count = nrow(objective_candidates),
  full_budget_handoff_count = nrow(handoff),
  historical_classification = "COMPLETE_WITH_REFINEMENT_SEED_CONTRACT_FAILURE",
  metrics_path = metrics_path,
  executed_seed_contract_audit_path = seed_execution_audit_path,
  corrected_seed2_pairs_path = paired_seed2_path,
  combined_two_reservoir_pairs_path = combined_path,
  candidate_summary_path = candidate_summary_path,
  objective_candidates_path = objective_candidates_path,
  full_budget_handoff_path = handoff_path,
  binary_payload_audit_path = binary_audit_path,
  article_update_allowed = FALSE
)
gate_path <- write_json(gate, file.path(output_root, "seedrepair_gate.json"))

readme <- c(
  "# Q-DESN Alpha/Rho Seed-Repair v1 Audit",
  "",
  sprintf("- run tag: `%s`", run_tag),
  sprintf("- decision: `%s`", decision),
  sprintf("- complete metrics: `%d/48`", complete_specs),
  sprintf("- executed seed-contract checks: `%d/48`", seed_contract_passes),
  sprintf("- two-reservoir candidate summaries: `%d`", nrow(candidate_summary)),
  sprintf("- full-budget handoff candidates: `%d`", nrow(handoff)),
  sprintf("- unexpected binary payloads: `%d`", length(binary_paths)),
  "",
  "The first replicate is the immutable historical seed-123 paired screen. The second",
  "replicate is the corrected declared profile seed, paired to an exact parent with the",
  "same source and run-level sampler seeds. Selection remains cell-specific; no global",
  "Q-DESN specification is selected. Article promotion remains prohibited until a later",
  "full-budget confirmation on the frozen article-protocol source."
)
writeLines(readme, file.path(output_root, "README.md"))
cat(sprintf("Decision: %s\n", decision))
cat(sprintf("Complete metrics: %d/48\n", complete_specs))
cat(sprintf("Seed-contract passes: %d/48\n", seed_contract_passes))
cat(sprintf("Full-budget handoff candidates: %d\n", nrow(handoff)))
cat(sprintf("Gate: %s\n", gate_path))

#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  if (!requireNamespace("jsonlite", quietly = TRUE)) {
    stop("Package `jsonlite` is required.", call. = FALSE)
  }
})

`%||%` <- function(lhs, rhs) {
  if (is.null(lhs) || !length(lhs) || all(is.na(lhs))) rhs else lhs
}

repo_root <- normalizePath(system("git rev-parse --show-toplevel", intern = TRUE), winslash = "/", mustWork = TRUE)
setwd(repo_root)

date_stamp <- "20260724"
stage <- "qdesn_dynamic_fitforecast_v2_tt500_mcmc_rhs_targeted_repair_v1b"
run_tag <- "qdesn-tt500-mcmc-rhsrepair-v1b-full-20260723__git-9a365dc"
campaign_stamp <- "20260723-211348__git-9a365dc"
promotion_id <- paste0("qdesn_tt500_mcmc_rhsrepair_v1b_closeout_", date_stamp)

results_root <- file.path(repo_root, "results", "qdesn_mcmc_validation", stage, run_tag, campaign_stamp)
report_root <- file.path(repo_root, "reports", "qdesn_mcmc_validation", stage, run_tag, campaign_stamp)
promotion_root <- file.path(repo_root, "validation", "fitforecast_v2", "promotions", promotion_id)
current_best_path <- file.path(
  repo_root,
  "validation", "fitforecast_v2", "promotions",
  "qdesn_dqlm_500obs_mcmc_current_best_20260723",
  "qdesn_dqlm_500obs_mcmc_current_best_clean_20260723.csv"
)

num <- function(x) suppressWarnings(as.numeric(x))
int <- function(x) suppressWarnings(as.integer(x))
bool_chr <- function(x) {
  if (is.logical(x)) return(ifelse(x, "TRUE", "FALSE"))
  toupper(trimws(as.character(x)))
}
col_or <- function(x, nm, default = NA) {
  if (nm %in% names(x)) x[[nm]] else rep(default, nrow(x))
}
fmt <- function(x, digits = 3L) {
  x <- num(x)
  ifelse(is.na(x), "", format(round(x, digits), nsmall = digits, trim = TRUE, scientific = FALSE))
}

read_csv <- function(path) {
  utils::read.csv(normalizePath(path, winslash = "/", mustWork = TRUE), check.names = FALSE, stringsAsFactors = FALSE)
}

write_csv <- function(x, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(x, path, row.names = FALSE, quote = TRUE, na = "")
  normalizePath(path, winslash = "/", mustWork = TRUE)
}

write_json <- function(x, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  jsonlite::write_json(x, path, pretty = TRUE, auto_unbox = TRUE, null = "null", digits = NA)
  normalizePath(path, winslash = "/", mustWork = TRUE)
}

sha256_file <- function(path) {
  unname(tools::sha256sum(normalizePath(path, winslash = "/", mustWork = TRUE)))
}

git_value <- function(args) {
  out <- tryCatch(system2("git", c("-C", repo_root, args), stdout = TRUE, stderr = TRUE), error = function(e) NA_character_)
  if (!length(out)) NA_character_ else out[[1L]]
}

objective <- function(fit_rmse, forecast_rmse, forecast_check) {
  num(fit_rmse) + num(forecast_rmse) + num(forecast_check)
}

if (!dir.exists(results_root)) {
  stop(sprintf("Missing v1b results root: %s", results_root), call. = FALSE)
}
if (!file.exists(current_best_path)) {
  stop(sprintf("Missing current-best comparison table: %s", current_best_path), call. = FALSE)
}

status_files <- Sys.glob(file.path(results_root, "roots", "*", "manifest", "root_status.txt"))
if (!length(status_files)) {
  stop(sprintf("No root status files found under %s", results_root), call. = FALSE)
}

attempt_inventory <- do.call(rbind, lapply(status_files, function(status_path) {
  root_dir <- dirname(dirname(status_path))
  root_id <- basename(root_dir)
  data.frame(
    root_id = root_id,
    run_tag = run_tag,
    campaign_stamp = campaign_stamp,
    root_status = trimws(paste(readLines(status_path, warn = FALSE), collapse = " ")),
    status_mtime = as.character(file.info(status_path)$mtime),
    root_dir = normalizePath(root_dir, winslash = "/", mustWork = TRUE),
    root_status_path = normalizePath(status_path, winslash = "/", mustWork = TRUE),
    stringsAsFactors = FALSE
  )
}))

read_root_fit <- function(root_dir) {
  fit_path <- file.path(root_dir, "tables", "fit_summary.csv")
  if (!file.exists(fit_path)) {
    fit_path <- Sys.glob(file.path(root_dir, "fits", "*", "fit_summary_row.csv"))[[1L]] %||% NA_character_
  }
  if (is.na(fit_path) || !file.exists(fit_path)) {
    stop(sprintf("Missing fit summary for root: %s", root_dir), call. = FALSE)
  }
  fit <- read_csv(fit_path)
  if (nrow(fit) != 1L) {
    stop(sprintf("Expected one fit summary row in %s, observed %d.", fit_path, nrow(fit)), call. = FALSE)
  }
  horizon_files <- Sys.glob(file.path(root_dir, "fits", "*", "tables", "forecast_horizon_summary.csv"))
  horizon <- if (length(horizon_files)) read_csv(horizon_files[[1L]]) else data.frame(stringsAsFactors = FALSE)
  h100 <- if (nrow(horizon)) horizon[num(horizon$horizon) == 100, , drop = FALSE] else data.frame(stringsAsFactors = FALSE)
  h1000 <- if (nrow(horizon)) horizon[num(horizon$horizon) == 1000, , drop = FALSE] else data.frame(stringsAsFactors = FALSE)
  signoff_files <- Sys.glob(file.path(root_dir, "fits", "*", "signoff_summary.csv"))
  signoff_path <- if (length(signoff_files)) normalizePath(signoff_files[[1L]], winslash = "/", mustWork = TRUE) else NA_character_
  health_files <- Sys.glob(file.path(root_dir, "fits", "*", "health_summary.csv"))
  health_path <- if (length(health_files)) normalizePath(health_files[[1L]], winslash = "/", mustWork = TRUE) else NA_character_
  data.frame(
    root_id = fit$root_id[[1L]],
    spec_id = fit$spec_id[[1L]],
    dataset_cell_id = fit$dataset_cell_id[[1L]],
    scenario = fit$scenario[[1L]],
    family = as.character(fit$family[[1L]]),
    tau = num(fit$tau[[1L]]),
    fit_size = int(fit$fit_size[[1L]]),
    effective_fit_size = int(fit$effective_fit_size[[1L]]),
    prior = as.character(fit$prior[[1L]]),
    model = as.character(fit$model[[1L]]),
    model_variant = paste0("qdesn_", as.character(fit$model[[1L]]), "_rhs_ns"),
    inference = as.character(fit$inference[[1L]]),
    candidate_id = as.character(fit$reservoir_profile[[1L]]),
    profile_role = as.character(col_or(fit, "profile_role", "")[[1L]]),
    rhs_tau0 = num(fit$rhs_tau0[[1L]]),
    readout_y_lags = int(fit$readout_y_lags[[1L]]),
    reservoir_lags = int(fit$reservoir_lags[[1L]]),
    dimension_p_estimate = int(fit$dimension_p_estimate[[1L]]),
    p_over_n_tt500 = num(fit$p_over_n_tt500[[1L]]),
    runtime_sec = num(fit$runtime_sec[[1L]]),
    iter_like = int(col_or(fit, "iter_like", NA)[[1L]]),
    status = as.character(fit$status[[1L]]),
    finite_ok = bool_chr(fit$finite_ok[[1L]]),
    domain_ok = bool_chr(fit$domain_ok[[1L]]),
    signoff_grade = as.character(fit$signoff_grade[[1L]]),
    comparison_eligible = bool_chr(fit$comparison_eligible[[1L]]),
    signoff_reason = as.character(fit$signoff_reason[[1L]]),
    stop_reason = as.character(col_or(fit, "stop_reason", "")[[1L]]),
    train_qtrue_mae = num(fit$train_qtrue_mae[[1L]]),
    train_qtrue_rmse = num(fit$train_qtrue_rmse[[1L]]),
    train_check_loss = num(fit$train_pinball_tau[[1L]]),
    holdout_qtrue_mae = num(fit$holdout_qtrue_mae[[1L]]),
    holdout_qtrue_rmse = num(fit$holdout_qtrue_rmse[[1L]]),
    holdout_check_loss = num(fit$holdout_pinball_tau[[1L]]),
    forecast_H100_qtrue_mae = if (nrow(h100)) num(h100$qtrue_mae[[1L]]) else NA_real_,
    forecast_H100_qtrue_rmse = if (nrow(h100)) num(h100$qtrue_rmse[[1L]]) else NA_real_,
    forecast_H100_check_loss = if (nrow(h100)) num(h100$pinball_tau[[1L]]) else NA_real_,
    forecast_H1000_qtrue_mae = if (nrow(h1000)) num(h1000$qtrue_mae[[1L]]) else NA_real_,
    forecast_H1000_qtrue_rmse = if (nrow(h1000)) num(h1000$qtrue_rmse[[1L]]) else NA_real_,
    forecast_H1000_check_loss = if (nrow(h1000)) num(h1000$pinball_tau[[1L]]) else NA_real_,
    decision_objective = objective(
      fit$train_qtrue_rmse[[1L]],
      if (nrow(h1000)) h1000$qtrue_rmse[[1L]] else NA_real_,
      if (nrow(h1000)) h1000$pinball_tau[[1L]] else NA_real_
    ),
    run_tag = run_tag,
    campaign_stamp = campaign_stamp,
    root_dir = normalizePath(root_dir, winslash = "/", mustWork = TRUE),
    fit_summary_path = normalizePath(fit_path, winslash = "/", mustWork = TRUE),
    signoff_summary_path = signoff_path,
    health_summary_path = health_path,
    forecast_horizon_summary_path = if (length(horizon_files)) normalizePath(horizon_files[[1L]], winslash = "/", mustWork = TRUE) else NA_character_,
    stringsAsFactors = FALSE
  )
}

fit_summary <- do.call(rbind, lapply(attempt_inventory$root_dir, read_root_fit))
fit_summary$root_status <- attempt_inventory$root_status[match(fit_summary$root_id, attempt_inventory$root_id)]

expected_roots <- 130L
if (nrow(fit_summary) != expected_roots) {
  stop(sprintf("Expected %d v1b roots, observed %d.", expected_roots, nrow(fit_summary)), call. = FALSE)
}

fit_summary$clean_comparison_pool <- fit_summary$status == "SUCCESS" &
  fit_summary$root_status == "SUCCESS" &
  fit_summary$comparison_eligible == "TRUE" &
  fit_summary$signoff_grade %in% c("PASS", "WARN")

current_best <- read_csv(current_best_path)
qdesn_current <- current_best[current_best$model_group == "qdesn", , drop = FALSE]
qdesn_current$key <- paste(qdesn_current$family, sprintf("%.8f", num(qdesn_current$tau)), qdesn_current$model_variant, sep = "__")
fit_summary$key <- paste(fit_summary$family, sprintf("%.8f", num(fit_summary$tau)), fit_summary$model_variant, sep = "__")

current_same_variant <- lapply(split(seq_len(nrow(qdesn_current)), qdesn_current$key), function(ii) {
  sub <- qdesn_current[ii, , drop = FALSE]
  sub$decision_objective <- objective(sub$fit_qtrue_rmse, sub$forecast_qtrue_rmse_H1000, sub$forecast_check_loss_H1000)
  sub[order(sub$decision_objective, sub$forecast_qtrue_mae_H1000), , drop = FALSE][1L, , drop = FALSE]
})
current_same_variant <- do.call(rbind, current_same_variant)

v1b_best <- lapply(split(seq_len(nrow(fit_summary)), fit_summary$key), function(ii) {
  sub <- fit_summary[ii, , drop = FALSE]
  clean <- sub[sub$clean_comparison_pool, , drop = FALSE]
  pool <- if (nrow(clean)) clean else sub[sub$status == "SUCCESS" & is.finite(sub$decision_objective), , drop = FALSE]
  if (!nrow(pool)) pool <- sub
  pool[order(!pool$clean_comparison_pool, pool$decision_objective, pool$forecast_H1000_qtrue_mae), , drop = FALSE][1L, , drop = FALSE]
})
v1b_best <- do.call(rbind, v1b_best)

cell_model_summary <- v1b_best
cell_model_summary$n_candidates <- vapply(cell_model_summary$key, function(k) sum(fit_summary$key == k), integer(1L))
cell_model_summary$n_success <- vapply(cell_model_summary$key, function(k) sum(fit_summary$key == k & fit_summary$status == "SUCCESS"), integer(1L))
cell_model_summary$n_failed <- vapply(cell_model_summary$key, function(k) sum(fit_summary$key == k & fit_summary$status != "SUCCESS"), integer(1L))
cell_model_summary$n_clean <- vapply(cell_model_summary$key, function(k) sum(fit_summary$key == k & fit_summary$clean_comparison_pool), integer(1L))
cell_model_summary$selection_rule <- ifelse(
  cell_model_summary$clean_comparison_pool,
  "min_objective_among_clean_v1b_rows",
  "no_clean_v1b_row_available_or_best_is_diagnostic_only"
)

comparison <- merge(
  v1b_best,
  current_same_variant,
  by = "key",
  all.x = TRUE,
  suffixes = c("_v1b", "_current")
)
comparison$family <- comparison$family_v1b
comparison$tau <- comparison$tau_v1b
comparison$model_variant <- comparison$model_variant_v1b
comparison$candidate_id <- if ("candidate_id_v1b" %in% names(comparison)) comparison$candidate_id_v1b else comparison$candidate_id
comparison$current_candidate_id <- if ("candidate_id_current" %in% names(comparison)) comparison$candidate_id_current else NA_character_
comparison$v1b_signoff_grade <- if ("signoff_grade_v1b" %in% names(comparison)) comparison$signoff_grade_v1b else comparison$signoff_grade
comparison$current_signoff_grade <- if ("signoff_grade_current" %in% names(comparison)) comparison$signoff_grade_current else NA_character_
comparison$current_objective <- if ("decision_objective_current" %in% names(comparison)) {
  num(comparison$decision_objective_current)
} else {
  objective(
    comparison$fit_qtrue_rmse,
    comparison$forecast_qtrue_rmse_H1000,
    comparison$forecast_check_loss_H1000
  )
}
comparison$v1b_objective <- if ("decision_objective_v1b" %in% names(comparison)) {
  num(comparison$decision_objective_v1b)
} else {
  num(comparison$decision_objective)
}
comparison$v1b_clean_comparison_pool <- if ("clean_comparison_pool_v1b" %in% names(comparison)) {
  comparison$clean_comparison_pool_v1b
} else {
  comparison$clean_comparison_pool
}
comparison$delta_objective <- comparison$v1b_objective - comparison$current_objective
comparison$delta_forecast_H1000_mae <- comparison$forecast_H1000_qtrue_mae - comparison$forecast_qtrue_mae_H1000
comparison$promotion_class <- ifelse(
  comparison$v1b_clean_comparison_pool & is.finite(comparison$delta_objective) & comparison$delta_objective < -1e-8,
  "diagnostic_current_best_candidate_objective_improves",
  ifelse(
    comparison$v1b_clean_comparison_pool & is.finite(comparison$delta_forecast_H1000_mae) & comparison$delta_forecast_H1000_mae < -1e-8,
    "diagnostic_forecast_mae_improvement_only",
    "no_promotion"
  )
)
comparison_out <- data.frame(
  family = comparison$family,
  tau = comparison$tau,
  model_variant = comparison$model_variant,
  v1b_candidate_id = comparison$candidate_id,
  current_candidate_id = comparison$current_candidate_id,
  v1b_status = comparison$status_v1b,
  v1b_signoff_grade = comparison$v1b_signoff_grade,
  v1b_comparison_eligible = if ("comparison_eligible_v1b" %in% names(comparison)) comparison$comparison_eligible_v1b else NA_character_,
  current_status = if ("status_current" %in% names(comparison)) comparison$status_current else NA_character_,
  current_signoff_grade = comparison$current_signoff_grade,
  current_comparison_eligible = if ("comparison_eligible_current" %in% names(comparison)) comparison$comparison_eligible_current else NA_character_,
  current_fit_rmse = comparison$fit_qtrue_rmse,
  v1b_fit_rmse = comparison$train_qtrue_rmse,
  current_H1000_mae = comparison$forecast_qtrue_mae_H1000,
  v1b_H1000_mae = comparison$forecast_H1000_qtrue_mae,
  current_H1000_rmse = comparison$forecast_qtrue_rmse_H1000,
  v1b_H1000_rmse = comparison$forecast_H1000_qtrue_rmse,
  current_H1000_check_loss = comparison$forecast_check_loss_H1000,
  v1b_H1000_check_loss = comparison$forecast_H1000_check_loss,
  current_objective = comparison$current_objective,
  v1b_objective = comparison$v1b_objective,
  delta_objective = comparison$delta_objective,
  delta_H1000_mae = comparison$delta_forecast_H1000_mae,
  promotion_class = comparison$promotion_class,
  v1b_profile_role = comparison$profile_role,
  v1b_run_tag = comparison$run_tag_v1b,
  current_run_tag = if ("run_tag_current" %in% names(comparison)) comparison$run_tag_current else NA_character_,
  v1b_root_id = comparison$root_id_v1b,
  current_root_id = if ("root_id_current" %in% names(comparison)) comparison$root_id_current else NA_character_,
  stringsAsFactors = FALSE
)
comparison_out <- comparison_out[order(comparison_out$family, comparison_out$tau, comparison_out$model_variant), , drop = FALSE]
candidate_promotions <- comparison_out[comparison_out$promotion_class != "no_promotion", , drop = FALSE]

nonpromotable <- fit_summary[!fit_summary$clean_comparison_pool, , drop = FALSE]
nonpromotable$nonpromotion_reason <- ifelse(
  nonpromotable$status != "SUCCESS" | nonpromotable$root_status != "SUCCESS",
  "root_failed_or_incomplete",
  paste0("diagnostic_ineligible__", nonpromotable$signoff_reason)
)
failed_roots <- nonpromotable[nonpromotable$nonpromotion_reason == "root_failed_or_incomplete", , drop = FALSE]

cell_failure_counts <- do.call(rbind, lapply(split(seq_len(nrow(fit_summary)), fit_summary$key), function(ii) {
  sub <- fit_summary[ii, , drop = FALSE]
  data.frame(
    family = sub$family[[1L]],
    tau = sub$tau[[1L]],
    model_variant = sub$model_variant[[1L]],
    n_candidates = nrow(sub),
    n_success = sum(sub$status == "SUCCESS"),
    n_failed = sum(sub$status != "SUCCESS"),
    n_clean = sum(sub$clean_comparison_pool),
    n_diagnostic_ineligible = sum(sub$status == "SUCCESS" & !sub$clean_comparison_pool),
    stringsAsFactors = FALSE
  )
}))

hard_cells <- comparison_out
hard_cells$key <- paste(hard_cells$family, sprintf("%.8f", num(hard_cells$tau)), hard_cells$model_variant, sep = "__")
hard_cells$issue_class <- ifelse(
  cell_failure_counts$n_clean[match(hard_cells$key, paste(cell_failure_counts$family, sprintf("%.8f", cell_failure_counts$tau), cell_failure_counts$model_variant, sep = "__"))] == 0L,
  "no_clean_v1b_candidate",
  ifelse(hard_cells$promotion_class == "no_promotion", "v1b_did_not_improve_current_best", "v1b_candidate_but_still_needs_reference_gap_review")
)
hard_cells$next_action <- ifelse(
  hard_cells$issue_class == "no_clean_v1b_candidate",
  "targeted_stability_screen_with_tau0_floor_and_multichain_smoke",
  ifelse(
    hard_cells$issue_class == "v1b_did_not_improve_current_best",
    "broaden_structure_or_hold_current_best",
    "closeout_reference_gap_before_article_promotion"
  )
)
hard_cells <- hard_cells[order(
  hard_cells$issue_class,
  hard_cells$family,
  hard_cells$tau,
  hard_cells$model_variant
), , drop = FALSE]

next_screen <- data.frame(
  priority = seq_len(nrow(hard_cells)),
  family = hard_cells$family,
  tau = hard_cells$tau,
  model_variant = hard_cells$model_variant,
  issue_class = hard_cells$issue_class,
  proposed_design_family = ifelse(
    hard_cells$issue_class == "no_clean_v1b_candidate",
    "stability_first_rhs_mcmc_repair",
    ifelse(
      hard_cells$issue_class == "v1b_did_not_improve_current_best",
      "structure_breakout_rhs_mcmc_repair",
      "confirm_reference_gap"
    )
  ),
  proposed_tau0_floor = ifelse(hard_cells$issue_class == "no_clean_v1b_candidate", 1e-4, 3e-5),
  proposed_first_smoke = TRUE,
  launch_status = "not_launched_prepared_only",
  rationale = hard_cells$next_action,
  stringsAsFactors = FALSE
)

binary_patterns <- c("\\.rds$", "\\.rda$", "\\.RData$", "\\.qs$", "\\.fst$")
all_files <- list.files(results_root, recursive = TRUE, full.names = TRUE, all.files = FALSE, no.. = TRUE)
all_files <- all_files[file.exists(all_files) & !file.info(all_files)$isdir]
heavy_files <- all_files[
  grepl(paste(binary_patterns, collapse = "|"), all_files, ignore.case = TRUE) |
    file.info(all_files)$size > 20 * 1024^2
]
storage_audit <- if (length(heavy_files)) {
  data.frame(
    path = normalizePath(heavy_files, winslash = "/", mustWork = TRUE),
    size_bytes = as.numeric(file.info(heavy_files)$size),
    classification = "unexpected_heavy_or_binary_campaign_artifact",
    action = "defer_keep",
    stringsAsFactors = FALSE
  )
} else {
  data.frame(path = character(0), size_bytes = numeric(0), classification = character(0), action = character(0), stringsAsFactors = FALSE)
}

signoff_summary <- data.frame(
  promotion_id = promotion_id,
  n_roots = nrow(fit_summary),
  n_root_success = sum(fit_summary$root_status == "SUCCESS"),
  n_root_fail = sum(fit_summary$root_status == "FAIL"),
  n_status_success = sum(fit_summary$status == "SUCCESS"),
  n_status_fail = sum(fit_summary$status != "SUCCESS"),
  n_pass = sum(fit_summary$signoff_grade == "PASS"),
  n_warn = sum(fit_summary$signoff_grade == "WARN"),
  n_fail = sum(fit_summary$signoff_grade == "FAIL"),
  n_clean_comparison_pool = sum(fit_summary$clean_comparison_pool),
  n_nonpromotable = nrow(nonpromotable),
  n_candidate_promotions = nrow(candidate_promotions),
  n_objective_improvements = sum(candidate_promotions$promotion_class == "diagnostic_current_best_candidate_objective_improves"),
  n_forecast_only_improvements = sum(candidate_promotions$promotion_class == "diagnostic_forecast_mae_improvement_only"),
  stringsAsFactors = FALSE
)

dir.create(promotion_root, recursive = TRUE, showWarnings = FALSE)
attempt_path <- write_csv(attempt_inventory[order(attempt_inventory$root_id), ], file.path(promotion_root, paste0("qdesn_tt500_mcmc_rhsrepair_v1b_attempt_inventory_", date_stamp, ".csv")))
fit_path <- write_csv(fit_summary[order(fit_summary$family, fit_summary$tau, fit_summary$model_variant, fit_summary$candidate_id), ], file.path(promotion_root, paste0("qdesn_tt500_mcmc_rhsrepair_v1b_fit_summary_", date_stamp, ".csv")))
cell_path <- write_csv(cell_model_summary[order(cell_model_summary$family, cell_model_summary$tau, cell_model_summary$model_variant), ], file.path(promotion_root, paste0("qdesn_tt500_mcmc_rhsrepair_v1b_cell_model_summary_", date_stamp, ".csv")))
comparison_path <- write_csv(comparison_out, file.path(promotion_root, paste0("qdesn_tt500_mcmc_rhsrepair_v1b_vs_current_best_", date_stamp, ".csv")))
candidate_path <- write_csv(candidate_promotions, file.path(promotion_root, paste0("qdesn_tt500_mcmc_rhsrepair_v1b_diagnostic_candidate_promotions_", date_stamp, ".csv")))
nonpromote_path <- write_csv(nonpromotable[order(nonpromotable$family, nonpromotable$tau, nonpromotable$model_variant, nonpromotable$candidate_id), ], file.path(promotion_root, paste0("qdesn_tt500_mcmc_rhsrepair_v1b_nonpromotable_roots_", date_stamp, ".csv")))
failed_path <- write_csv(failed_roots[order(failed_roots$family, failed_roots$tau, failed_roots$model_variant, failed_roots$candidate_id), ], file.path(promotion_root, paste0("qdesn_tt500_mcmc_rhsrepair_v1b_failed_roots_", date_stamp, ".csv")))
hard_path <- write_csv(hard_cells, file.path(promotion_root, paste0("qdesn_tt500_mcmc_rhsrepair_v1b_remaining_hard_cells_", date_stamp, ".csv")))
next_path <- write_csv(next_screen, file.path(promotion_root, paste0("qdesn_tt500_mcmc_rhsrepair_v1c_prelaunch_screen_plan_", date_stamp, ".csv")))
signoff_path <- write_csv(signoff_summary, file.path(promotion_root, paste0("qdesn_tt500_mcmc_rhsrepair_v1b_signoff_summary_", date_stamp, ".csv")))
storage_path <- write_csv(storage_audit, file.path(promotion_root, paste0("qdesn_tt500_mcmc_rhsrepair_v1b_storage_audit_", date_stamp, ".csv")))

source_manifest <- data.frame(
  source_key = c("v1b_results_root", "v1b_report_root", "current_best_clean_20260723"),
  path = c(normalizePath(results_root, winslash = "/", mustWork = TRUE), normalizePath(report_root, winslash = "/", mustWork = TRUE), normalizePath(current_best_path, winslash = "/", mustWork = TRUE)),
  sha256 = c(NA_character_, NA_character_, sha256_file(current_best_path)),
  role = c("campaign_results", "campaign_report", "comparison_baseline"),
  stringsAsFactors = FALSE
)
source_path <- write_csv(source_manifest, file.path(promotion_root, "source_manifest.csv"))

source_files <- c(
  attempt_path, fit_path, cell_path, comparison_path, candidate_path,
  nonpromote_path, failed_path, hard_path, next_path, signoff_path,
  storage_path, source_path
)
file_manifest <- data.frame(
  file_id = sub(paste0("_", date_stamp, ".*$"), "", basename(source_files)),
  path = source_files,
  sha256 = vapply(source_files, sha256_file, character(1L)),
  stringsAsFactors = FALSE
)
file_manifest_path <- write_csv(file_manifest, file.path(promotion_root, "file_manifest.csv"))

manifest <- list(
  promotion_id = promotion_id,
  generated_at = as.character(Sys.time()),
  repo_root = repo_root,
  git_branch = git_value(c("branch", "--show-current")),
  git_commit = git_value(c("rev-parse", "HEAD")),
  git_dirty = length(system2("git", c("-C", repo_root, "status", "--porcelain"), stdout = TRUE)) > 0L,
  stage = stage,
  run_tag = run_tag,
  campaign_stamp = campaign_stamp,
  results_root = normalizePath(results_root, winslash = "/", mustWork = TRUE),
  report_root = normalizePath(report_root, winslash = "/", mustWork = TRUE),
  current_best_path = normalizePath(current_best_path, winslash = "/", mustWork = TRUE),
  expected_roots = expected_roots,
  signoff = as.list(signoff_summary[1L, , drop = FALSE]),
  promotion_rule = "Do not replace the article-facing current-best table. Record v1b as diagnostic evidence; promote only clean PASS/WARN comparison-eligible rows that improve the current same-model variant by the registered objective or, separately, by H1000 forecast MAE only.",
  nonpromotion_rule = "Rows with failed roots, failed fit status, signoff FAIL, or comparison_eligible != TRUE are non-promotable and retained only for diagnostics.",
  next_launch_rule = "Do not launch v1c from this materializer. Use the prepared prelaunch screen plan only after a separate smoke/preflight decision.",
  files = file_manifest
)
manifest_path <- write_json(manifest, file.path(promotion_root, paste0("qdesn_tt500_mcmc_rhsrepair_v1b_closeout_manifest_", date_stamp, ".json")))

md_table <- function(x, cols, max_rows = 30L) {
  cols <- intersect(cols, names(x))
  if (!length(cols) || !nrow(x)) return(c("| none |", "|---|"))
  y <- utils::head(x[, cols, drop = FALSE], max_rows)
  out <- c(
    paste("|", paste(cols, collapse = " | "), "|"),
    paste("|", paste(rep("---", length(cols)), collapse = " | "), "|")
  )
  for (i in seq_len(nrow(y))) {
    vals <- vapply(y[i, , drop = TRUE], function(v) {
      v <- as.character(v)
      v[is.na(v)] <- ""
      gsub("\n", " ", v, fixed = TRUE)
    }, character(1L))
    out <- c(out, paste("|", paste(vals, collapse = " | "), "|"))
  }
  out
}

readme <- c(
  "# Q-DESN 500-Observation MCMC RHS Repair v1b Closeout",
  "",
  sprintf("- Promotion id: `%s`", promotion_id),
  sprintf("- Generated: `%s`", manifest$generated_at),
  sprintf("- Validation branch: `%s`", manifest$git_branch),
  sprintf("- Validation commit: `%s`", manifest$git_commit),
  sprintf("- Run tag: `%s`", run_tag),
  sprintf("- Campaign stamp: `%s`", campaign_stamp),
  "",
  "## Diagnosis",
  "",
  "The v1b run is terminal and storage-light, but it is not a wholesale article-facing replacement. It is retained as diagnostic current-best candidate evidence.",
  "",
  sprintf("- Roots: `%d / %d` terminal", nrow(fit_summary), expected_roots),
  sprintf("- Successful roots: `%d`", signoff_summary$n_root_success),
  sprintf("- Failed roots: `%d`", signoff_summary$n_root_fail),
  sprintf("- Clean comparison rows: `%d`", signoff_summary$n_clean_comparison_pool),
  sprintf("- Non-promotable rows: `%d`", signoff_summary$n_nonpromotable),
  sprintf("- Diagnostic candidate promotions: `%d`", signoff_summary$n_candidate_promotions),
  sprintf("- Objective-supported improvements: `%d`", signoff_summary$n_objective_improvements),
  sprintf("- Forecast-MAE-only improvements: `%d`", signoff_summary$n_forecast_only_improvements),
  sprintf("- Heavy/binary artifacts retained: `%d`", nrow(storage_audit)),
  "",
  "## Diagnostic Candidate Promotions",
  "",
  md_table(
    transform(
      candidate_promotions,
      tau = fmt(tau),
      v1b_objective = fmt(v1b_objective),
      current_objective = fmt(current_objective),
      delta_objective = fmt(delta_objective),
      v1b_H1000_mae = fmt(v1b_H1000_mae),
      current_H1000_mae = fmt(current_H1000_mae),
      delta_H1000_mae = fmt(delta_H1000_mae)
    ),
    c(
      "family", "tau", "model_variant", "v1b_candidate_id", "promotion_class",
      "current_objective", "v1b_objective", "delta_objective",
      "current_H1000_mae", "v1b_H1000_mae", "delta_H1000_mae"
    )
  ),
  "",
  "## Next Screen Prepared",
  "",
  "The v1c prelaunch table is prepared but not launched. It prioritizes hard cells with no clean v1b row, cells where v1b did not improve the current best, and cells where v1b improved only one forecast metric but still needs a reference-gap review.",
  "",
  md_table(transform(next_screen, tau = fmt(tau)), c("priority", "family", "tau", "model_variant", "issue_class", "proposed_design_family", "proposed_tau0_floor", "launch_status")),
  "",
  "## Files",
  "",
  sprintf("- Fit summary: `%s`", basename(fit_path)),
  sprintf("- Cell/model summary: `%s`", basename(cell_path)),
  sprintf("- v1b vs current-best comparison: `%s`", basename(comparison_path)),
  sprintf("- Diagnostic candidate promotions: `%s`", basename(candidate_path)),
  sprintf("- Non-promotable roots: `%s`", basename(nonpromote_path)),
  sprintf("- Failed roots: `%s`", basename(failed_path)),
  sprintf("- Remaining hard cells: `%s`", basename(hard_path)),
  sprintf("- v1c prelaunch screen plan: `%s`", basename(next_path)),
  sprintf("- Storage audit: `%s`", basename(storage_path)),
  sprintf("- Manifest: `%s`", basename(manifest_path))
)
writeLines(readme, file.path(promotion_root, "README.md"), useBytes = TRUE)

cat(sprintf("promotion_root: %s\n", normalizePath(promotion_root, winslash = "/", mustWork = TRUE)))
cat(sprintf("roots: %d success=%d fail=%d clean=%d nonpromotable=%d\n",
            nrow(fit_summary), signoff_summary$n_root_success,
            signoff_summary$n_root_fail, signoff_summary$n_clean_comparison_pool,
            signoff_summary$n_nonpromotable))
cat(sprintf("candidate_promotions: %d objective=%d forecast_only=%d\n",
            signoff_summary$n_candidate_promotions,
            signoff_summary$n_objective_improvements,
            signoff_summary$n_forecast_only_improvements))
cat(sprintf("next_screen_rows: %d\n", nrow(next_screen)))
cat(sprintf("storage_heavy_or_binary_count: %d\n", nrow(storage_audit)))

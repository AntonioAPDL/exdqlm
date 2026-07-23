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

stage <- "qdesn_dynamic_fitforecast_v2_tt500_mcmc_vb_candidate_full_confirmation"
expected_roots <- 72L
promotion_id <- "qdesn_tt500_mcmc_vb_candidate_closeout_20260723"

results_stage_root <- file.path(repo_root, "results", "qdesn_mcmc_validation", stage)
reports_stage_root <- file.path(repo_root, "reports", "qdesn_mcmc_validation", stage)
promotion_root <- file.path(repo_root, "validation", "fitforecast_v2", "promotions", promotion_id)

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
  jsonlite::write_json(x, path, pretty = TRUE, auto_unbox = TRUE, null = "null")
  normalizePath(path, winslash = "/", mustWork = TRUE)
}

sha256_file <- function(path) {
  unname(tools::sha256sum(normalizePath(path, winslash = "/", mustWork = TRUE)))
}

git_value <- function(args) {
  out <- tryCatch(system2("git", c("-C", repo_root, args), stdout = TRUE, stderr = TRUE), error = function(e) NA_character_)
  if (!length(out)) NA_character_ else out[[1L]]
}

num <- function(x) suppressWarnings(as.numeric(x))
bool_chr <- function(x) {
  if (is.logical(x)) return(ifelse(x, "TRUE", "FALSE"))
  toupper(trimws(as.character(x)))
}

path_parts <- function(path) strsplit(normalizePath(path, winslash = "/", mustWork = TRUE), "/", fixed = TRUE)[[1L]]

status_files <- Sys.glob(file.path(results_stage_root, "*", "*", "roots", "*", "manifest", "root_status.txt"))
if (!length(status_files)) {
  stop(sprintf("No root status files found under %s", results_stage_root), call. = FALSE)
}

attempts <- do.call(rbind, lapply(status_files, function(status_path) {
  parts <- path_parts(status_path)
  idx <- match(stage, parts)
  if (is.na(idx) || length(parts) < idx + 4L) {
    stop(sprintf("Could not parse campaign path: %s", status_path), call. = FALSE)
  }
  run_tag <- parts[[idx + 1L]]
  campaign_stamp <- parts[[idx + 2L]]
  root_id <- parts[[idx + 4L]]
  status <- trimws(paste(readLines(status_path, warn = FALSE), collapse = " "))
  root_dir <- dirname(dirname(status_path))
  data.frame(
    root_id = root_id,
    run_tag = run_tag,
    campaign_stamp = campaign_stamp,
    root_status = status,
    is_smoke = grepl("smoke", run_tag, fixed = TRUE),
    status_mtime = as.numeric(file.info(status_path)$mtime),
    root_dir = normalizePath(root_dir, winslash = "/", mustWork = TRUE),
    root_status_path = normalizePath(status_path, winslash = "/", mustWork = TRUE),
    stringsAsFactors = FALSE
  )
}))

full_attempts <- attempts[!attempts$is_smoke, , drop = FALSE]
if (!nrow(full_attempts)) stop("No non-smoke attempts found.", call. = FALSE)

status_rank <- ifelse(full_attempts$root_status == "SUCCESS", 2L, ifelse(full_attempts$root_status == "RUNNING", 1L, 0L))
full_attempts$status_rank <- status_rank
full_attempts$attempt_key <- paste(full_attempts$root_id, full_attempts$run_tag, full_attempts$campaign_stamp, sep = "\r")

preferred_rows <- lapply(split(seq_len(nrow(full_attempts)), full_attempts$root_id), function(ii) {
  sub <- full_attempts[ii, , drop = FALSE]
  sub[order(sub$status_rank, sub$status_mtime, decreasing = TRUE), , drop = FALSE][1L, , drop = FALSE]
})
preferred_attempts <- do.call(rbind, preferred_rows)
preferred_attempts$is_preferred <- TRUE

full_attempts$is_preferred <- full_attempts$attempt_key %in% preferred_attempts$attempt_key
superseded_attempts <- full_attempts[!full_attempts$is_preferred, , drop = FALSE]
superseded_attempts$superseded_by_run_tag <- vapply(superseded_attempts$root_id, function(id) {
  preferred_attempts$run_tag[match(id, preferred_attempts$root_id)]
}, character(1L))
superseded_attempts$superseded_by_campaign_stamp <- vapply(superseded_attempts$root_id, function(id) {
  preferred_attempts$campaign_stamp[match(id, preferred_attempts$root_id)]
}, character(1L))
superseded_attempts$superseded_by_status <- vapply(superseded_attempts$root_id, function(id) {
  preferred_attempts$root_status[match(id, preferred_attempts$root_id)]
}, character(1L))

if (nrow(preferred_attempts) != expected_roots) {
  stop(sprintf("Expected %d unique scientific roots, observed %d.", expected_roots, nrow(preferred_attempts)), call. = FALSE)
}
if (any(preferred_attempts$root_status != "SUCCESS")) {
  bad <- preferred_attempts[preferred_attempts$root_status != "SUCCESS", c("root_id", "run_tag", "root_status"), drop = FALSE]
  stop(sprintf("Not all preferred roots are successful:\n%s", paste(utils::capture.output(print(bad, row.names = FALSE)), collapse = "\n")), call. = FALSE)
}

read_optional_first <- function(path) {
  if (!file.exists(path)) return(data.frame(stringsAsFactors = FALSE))
  read_csv(path)
}

fit_rows <- lapply(seq_len(nrow(preferred_attempts)), function(i) {
  root_dir <- preferred_attempts$root_dir[[i]]
  fit_path <- file.path(root_dir, "tables", "fit_summary.csv")
  if (!file.exists(fit_path)) stop(sprintf("Missing fit summary: %s", fit_path), call. = FALSE)
  fit <- read_csv(fit_path)
  if (nrow(fit) != 1L) stop(sprintf("Expected one fit row in %s, observed %d.", fit_path, nrow(fit)), call. = FALSE)
  signoff_files <- Sys.glob(file.path(root_dir, "fits", "*", "signoff_summary.csv"))
  chain_files <- Sys.glob(file.path(root_dir, "fits", "*", "chain_summary.csv"))
  horizon_files <- Sys.glob(file.path(root_dir, "fits", "*", "tables", "forecast_horizon_summary.csv"))
  signoff <- if (length(signoff_files)) read_csv(signoff_files[[1L]]) else data.frame(stringsAsFactors = FALSE)
  chain <- if (length(chain_files)) read_csv(chain_files[[1L]]) else data.frame(stringsAsFactors = FALSE)
  horizon <- if (length(horizon_files)) read_csv(horizon_files[[1L]]) else data.frame(stringsAsFactors = FALSE)
  h100 <- horizon[horizon$horizon == 100, , drop = FALSE]
  h1000 <- horizon[horizon$horizon == 1000, , drop = FALSE]
  data.frame(
    root_id = fit$root_id[[1L]],
    spec_id = fit$spec_id[[1L]],
    dataset_cell_id = fit$dataset_cell_id[[1L]],
    family = as.character(fit$family[[1L]]),
    tau = num(fit$tau[[1L]]),
    fit_size = as.integer(fit$fit_size[[1L]]),
    effective_fit_size = as.integer(fit$effective_fit_size[[1L]]),
    prior = as.character(fit$prior[[1L]]),
    inference = as.character(fit$inference[[1L]]),
    model = as.character(fit$model[[1L]]),
    likelihood_family = as.character(fit$likelihood_family[[1L]]),
    reservoir_profile = as.character(fit$reservoir_profile[[1L]]),
    rhs_tau0 = num(fit$rhs_tau0[[1L]]),
    readout_y_lags = as.integer(fit$readout_y_lags[[1L]]),
    reservoir_lags = as.integer(fit$reservoir_lags[[1L]]),
    dimension_p_estimate = as.integer(fit$dimension_p_estimate[[1L]]),
    p_over_n_tt500 = num(fit$p_over_n_tt500[[1L]]),
    iter_like = as.integer(fit$iter_like[[1L]]),
    runtime_sec = num(fit$runtime_sec[[1L]]),
    status = as.character(fit$status[[1L]]),
    finite_ok = bool_chr(fit$finite_ok[[1L]]),
    domain_ok = bool_chr(fit$domain_ok[[1L]]),
    signoff_grade = as.character(fit$signoff_grade[[1L]]),
    comparison_eligible = bool_chr(fit$comparison_eligible[[1L]]),
    signoff_reason = as.character(fit$signoff_reason[[1L]]),
    stop_reason = as.character(fit$stop_reason[[1L]]),
    train_qtrue_mae = num(fit$train_qtrue_mae[[1L]]),
    train_qtrue_rmse = num(fit$train_qtrue_rmse[[1L]]),
    train_qtrue_bias = num(fit$train_qtrue_bias[[1L]]),
    train_qtrue_corr = num(fit$train_qtrue_corr[[1L]]),
    train_check_loss = num(fit$train_pinball_tau[[1L]]),
    holdout_qtrue_mae = num(fit$holdout_qtrue_mae[[1L]]),
    holdout_qtrue_rmse = num(fit$holdout_qtrue_rmse[[1L]]),
    holdout_qtrue_bias = num(fit$holdout_qtrue_bias[[1L]]),
    holdout_qtrue_corr = num(fit$holdout_qtrue_corr[[1L]]),
    holdout_check_loss = num(fit$holdout_pinball_tau[[1L]]),
    forecast_H100_qtrue_mae = if (nrow(h100)) num(h100$qtrue_mae[[1L]]) else NA_real_,
    forecast_H100_qtrue_rmse = if (nrow(h100)) num(h100$qtrue_rmse[[1L]]) else NA_real_,
    forecast_H100_check_loss = if (nrow(h100)) num(h100$pinball_tau[[1L]]) else NA_real_,
    forecast_H1000_qtrue_mae = if (nrow(h1000)) num(h1000$qtrue_mae[[1L]]) else NA_real_,
    forecast_H1000_qtrue_rmse = if (nrow(h1000)) num(h1000$qtrue_rmse[[1L]]) else NA_real_,
    forecast_H1000_check_loss = if (nrow(h1000)) num(h1000$pinball_tau[[1L]]) else NA_real_,
    mcmc_min_ess_core = if (nrow(signoff)) num(signoff$mcmc_min_ess_core[[1L]]) else NA_real_,
    mcmc_max_acf1_core = if (nrow(signoff)) num(signoff$mcmc_max_acf1_core[[1L]]) else NA_real_,
    mcmc_min_ess_rhs = if (nrow(signoff)) num(signoff$mcmc_min_ess_rhs[[1L]]) else NA_real_,
    mcmc_max_acf1_rhs = if (nrow(signoff)) num(signoff$mcmc_max_acf1_rhs[[1L]]) else NA_real_,
    chain_parameter_count = nrow(chain),
    preferred_run_tag = preferred_attempts$run_tag[[i]],
    preferred_campaign_stamp = preferred_attempts$campaign_stamp[[i]],
    root_dir = root_dir,
    fit_summary_path = normalizePath(fit_path, winslash = "/", mustWork = TRUE),
    signoff_summary_path = if (length(signoff_files)) normalizePath(signoff_files[[1L]], winslash = "/", mustWork = TRUE) else NA_character_,
    forecast_horizon_summary_path = if (length(horizon_files)) normalizePath(horizon_files[[1L]], winslash = "/", mustWork = TRUE) else NA_character_,
    stringsAsFactors = FALSE
  )
})
fit_summary <- do.call(rbind, fit_rows)

if (any(fit_summary$status != "SUCCESS") ||
    any(fit_summary$finite_ok != "TRUE") ||
    any(fit_summary$domain_ok != "TRUE") ||
    any(!fit_summary$signoff_grade %in% c("PASS", "WARN", "FAIL"))) {
  stop("Preferred fit summary violates basic status/domain/signoff contract.", call. = FALSE)
}

objective <- function(df) {
  num(df$train_qtrue_rmse) + num(df$forecast_H1000_qtrue_rmse) + num(df$forecast_H1000_check_loss)
}

cell_model_summary <- do.call(rbind, lapply(split(seq_len(nrow(fit_summary)), paste(fit_summary$family, fit_summary$tau, fit_summary$model, sep = "\r")), function(ii) {
  sub <- fit_summary[ii, , drop = FALSE]
  eligible <- sub[sub$comparison_eligible == "TRUE", , drop = FALSE]
  best_pool <- if (nrow(eligible)) eligible else sub
  best <- best_pool[order(objective(best_pool)), , drop = FALSE][1L, , drop = FALSE]
  data.frame(
    family = sub$family[[1L]],
    tau = sub$tau[[1L]],
    model = sub$model[[1L]],
    n_candidates = nrow(sub),
    n_pass = sum(sub$signoff_grade == "PASS"),
    n_warn = sum(sub$signoff_grade == "WARN"),
    n_fail = sum(sub$signoff_grade == "FAIL"),
    n_comparison_eligible = sum(sub$comparison_eligible == "TRUE"),
    best_selection_rule = if (nrow(eligible)) "min_objective_among_comparison_eligible" else "min_objective_no_comparison_eligible_available",
    best_profile = best$reservoir_profile[[1L]],
    best_signoff_grade = best$signoff_grade[[1L]],
    best_comparison_eligible = best$comparison_eligible[[1L]],
    best_train_qtrue_rmse = best$train_qtrue_rmse[[1L]],
    best_forecast_H1000_qtrue_rmse = best$forecast_H1000_qtrue_rmse[[1L]],
    best_forecast_H1000_check_loss = best$forecast_H1000_check_loss[[1L]],
    best_objective = objective(best)[[1L]],
    stringsAsFactors = FALSE
  )
}))

signoff_counts <- data.frame(
  n_roots = nrow(fit_summary),
  n_pass = sum(fit_summary$signoff_grade == "PASS"),
  n_warn = sum(fit_summary$signoff_grade == "WARN"),
  n_fail = sum(fit_summary$signoff_grade == "FAIL"),
  n_comparison_eligible = sum(fit_summary$comparison_eligible == "TRUE"),
  n_comparison_ineligible = sum(fit_summary$comparison_eligible != "TRUE"),
  stringsAsFactors = FALSE
)

strict_failures <- fit_summary[fit_summary$signoff_grade == "FAIL" | fit_summary$comparison_eligible != "TRUE", , drop = FALSE]
strict_failures <- strict_failures[order(strict_failures$family, strict_failures$tau, strict_failures$model, strict_failures$reservoir_profile), , drop = FALSE]

binary_patterns <- c("\\.rds$", "\\.rda$", "\\.RData$", "\\.qs$", "\\.fst$")
all_files <- list.files(results_stage_root, recursive = TRUE, full.names = TRUE, all.files = FALSE, no.. = TRUE)
heavy_files <- all_files[file.exists(all_files) & file.info(all_files)$isdir == FALSE]
heavy_files <- heavy_files[grepl(paste(binary_patterns, collapse = "|"), heavy_files, ignore.case = TRUE) | file.info(heavy_files)$size > 20 * 1024^2]
storage_audit <- if (length(heavy_files)) {
  data.frame(
    path = normalizePath(heavy_files, winslash = "/", mustWork = TRUE),
    size_bytes = as.numeric(file.info(heavy_files)$size),
    classification = "unexpected_heavy_or_binary_campaign_artifact",
    action = "defer_keep",
    stringsAsFactors = FALSE
  )
} else {
  data.frame(
    path = character(0),
    size_bytes = numeric(0),
    classification = character(0),
    action = character(0),
    stringsAsFactors = FALSE
  )
}

dir.create(promotion_root, recursive = TRUE, showWarnings = FALSE)
attempt_inventory_path <- write_csv(full_attempts[order(full_attempts$root_id, -full_attempts$status_rank, -full_attempts$status_mtime), ], file.path(promotion_root, "qdesn_tt500_mcmc_vb_candidate_attempt_inventory_20260723.csv"))
superseded_path <- write_csv(superseded_attempts, file.path(promotion_root, "qdesn_tt500_mcmc_vb_candidate_superseded_attempts_20260723.csv"))
fit_path <- write_csv(fit_summary[order(fit_summary$family, fit_summary$tau, fit_summary$model, fit_summary$reservoir_profile), ], file.path(promotion_root, "qdesn_tt500_mcmc_vb_candidate_authoritative_fit_summary_20260723.csv"))
cell_path <- write_csv(cell_model_summary[order(cell_model_summary$family, cell_model_summary$tau, cell_model_summary$model), ], file.path(promotion_root, "qdesn_tt500_mcmc_vb_candidate_cell_model_summary_20260723.csv"))
failure_path <- write_csv(strict_failures, file.path(promotion_root, "qdesn_tt500_mcmc_vb_candidate_strict_signoff_failures_20260723.csv"))
signoff_path <- write_csv(signoff_counts, file.path(promotion_root, "qdesn_tt500_mcmc_vb_candidate_signoff_summary_20260723.csv"))
storage_path <- write_csv(storage_audit, file.path(promotion_root, "qdesn_tt500_mcmc_vb_candidate_storage_audit_20260723.csv"))

source_files <- c(
  attempt_inventory_path, superseded_path, fit_path, cell_path,
  failure_path, signoff_path, storage_path
)
file_manifest <- data.frame(
  file_id = sub("_20260723.*$", "", basename(source_files)),
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
  results_stage_root = normalizePath(results_stage_root, winslash = "/", mustWork = TRUE),
  reports_stage_root = normalizePath(reports_stage_root, winslash = "/", mustWork = TRUE),
  expected_roots = expected_roots,
  full_attempt_count = nrow(full_attempts),
  preferred_root_count = nrow(preferred_attempts),
  preferred_success_count = sum(preferred_attempts$root_status == "SUCCESS"),
  superseded_attempt_count = nrow(superseded_attempts),
  stale_running_attempts_superseded = sum(superseded_attempts$root_status == "RUNNING" & superseded_attempts$superseded_by_status == "SUCCESS"),
  signoff = as.list(signoff_counts[1L, , drop = FALSE]),
  storage_heavy_or_binary_count = nrow(storage_audit),
  promotion_rule = "Prefer SUCCESS retry over stale/non-success attempt per root. Promote only comparison_eligible TRUE rows as clean MCMC evidence; retain FAIL rows as completed diagnostic failures.",
  files = file_manifest
)
manifest_path <- write_json(manifest, file.path(promotion_root, "qdesn_tt500_mcmc_vb_candidate_closeout_manifest_20260723.json"))

fmt_pct <- function(n, d) sprintf("%.1f%%", 100 * n / d)
readme <- c(
  "# Q-DESN 500-Observation MCMC VB-Candidate Closeout",
  "",
  sprintf("- Promotion id: `%s`", promotion_id),
  sprintf("- Generated: `%s`", manifest$generated_at),
  sprintf("- Validation branch: `%s`", manifest$git_branch),
  sprintf("- Validation commit: `%s`", manifest$git_commit),
  sprintf("- Stage: `%s`", stage),
  "",
  "## Completion",
  "",
  sprintf("- Scientific roots expected: `%d`", expected_roots),
  sprintf("- Unique preferred scientific roots: `%d`", nrow(preferred_attempts)),
  sprintf("- Preferred roots with SUCCESS: `%d / %d`", sum(preferred_attempts$root_status == "SUCCESS"), nrow(preferred_attempts)),
  sprintf("- Raw non-smoke attempts: `%d`", nrow(full_attempts)),
  sprintf("- Superseded attempts retained in inventory: `%d`", nrow(superseded_attempts)),
  sprintf("- Superseded stale RUNNING attempts: `%d`", manifest$stale_running_attempts_superseded),
  "",
  "The stale original `RUNNING` marker is not deleted. It is retained in the attempt inventory and superseded by the successful retry for the same root.",
  "",
  "## Signoff",
  "",
  sprintf("- PASS: `%d`", signoff_counts$n_pass),
  sprintf("- WARN: `%d`", signoff_counts$n_warn),
  sprintf("- FAIL: `%d`", signoff_counts$n_fail),
  sprintf("- Comparison eligible: `%d / %d` (%s)", signoff_counts$n_comparison_eligible, signoff_counts$n_roots, fmt_pct(signoff_counts$n_comparison_eligible, signoff_counts$n_roots)),
  "",
  "Rows with `comparison_eligible == TRUE` are the clean MCMC comparison pool. Rows with `signoff_grade == FAIL` are computationally complete but should not be promoted as clean winners without an explicit diagnostic caveat.",
  "",
  "## Files",
  "",
  sprintf("- Authoritative fit summary: `%s`", basename(fit_path)),
  sprintf("- Cell/model summary: `%s`", basename(cell_path)),
  sprintf("- Strict signoff failures: `%s`", basename(failure_path)),
  sprintf("- Superseded attempts: `%s`", basename(superseded_path)),
  sprintf("- Storage audit: `%s`", basename(storage_path)),
  sprintf("- Manifest: `%s`", basename(manifest_path))
)
writeLines(readme, file.path(promotion_root, "README.md"), useBytes = TRUE)

cat(sprintf("promotion_root: %s\n", normalizePath(promotion_root, winslash = "/", mustWork = TRUE)))
cat(sprintf("preferred_success: %d/%d\n", sum(preferred_attempts$root_status == "SUCCESS"), expected_roots))
cat(sprintf("signoff: PASS=%d WARN=%d FAIL=%d eligible=%d/%d\n",
            signoff_counts$n_pass, signoff_counts$n_warn, signoff_counts$n_fail,
            signoff_counts$n_comparison_eligible, signoff_counts$n_roots))
cat(sprintf("superseded_attempts: %d\n", nrow(superseded_attempts)))
cat(sprintf("storage_heavy_or_binary_count: %d\n", nrow(storage_audit)))

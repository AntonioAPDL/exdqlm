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
  if (!grepl("^/", path)) path <- file.path(repo_root, path)
  normalizePath(path, winslash = "/", mustWork = isTRUE(must_work))
}
read_csv <- function(path) utils::read.csv(resolve_path(path), check.names = FALSE, stringsAsFactors = FALSE)
write_csv <- function(x, path) {
  path <- resolve_path(path, FALSE); dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(x, path, row.names = FALSE, na = ""); normalizePath(path, winslash = "/", mustWork = TRUE)
}
write_json <- function(x, path) {
  path <- resolve_path(path, FALSE); dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  jsonlite::write_json(x, path, pretty = TRUE, auto_unbox = TRUE, null = "null", digits = NA)
  normalizePath(path, winslash = "/", mustWork = TRUE)
}
read_env <- function(path) {
  if (!file.exists(path)) return(character())
  x <- readLines(path, warn = FALSE); x <- x[grepl("^[A-Z0-9_]+=", x)]
  out <- sub("^[^=]+=", "", x); names(out) <- sub("=.*$", "", x); out
}
med <- function(x) { x <- as.numeric(x); x <- x[is.finite(x)]; if (length(x)) median(x) else NA_real_ }
q90 <- function(x) { x <- as.numeric(x); x <- x[is.finite(x)]; if (length(x)) unname(quantile(x, .9, type = 8)) else NA_real_ }
ratio <- function(x, y) ifelse(is.finite(x) & is.finite(y) & y > 0, x / y, NA_real_)

stage <- "qdesn_dynamic_fitforecast_v2_500obs_trainonly_followup_v1"
stub <- file.path("config", "validation", stage)
index <- read_csv(paste0(stub, "_bundle_index.csv"))
profiles <- read_csv(paste0(stub, "_profiles.csv"))
state_root <- resolve_path(get_arg("--state-root", stop("--state-root is required", call. = FALSE)))
output_root <- resolve_path(get_arg("--output-root", file.path(state_root, "closeout")), FALSE)
dir.create(output_root, recursive = TRUE, showWarnings = FALSE)
env <- read_env(file.path(state_root, "run_tags.env"))

metric_rows <- list(); inventory_rows <- list(); heavy_rows <- list(); missing_rows <- list()
for (i in seq_len(nrow(index))) {
  b <- index[i, , drop = FALSE]; id <- as.character(b$bundle_id[[1L]])
  tag <- unname(env[[paste0(toupper(id), "_RUN_TAG")]] %||% "")
  defaults <- yaml::read_yaml(b$defaults_path[[1L]])
  expected <- read_csv(b$target_specs_path[[1L]])
  run_root <- resolve_path(file.path(defaults$campaign$results_root, tag), FALSE)
  paths <- if (dir.exists(run_root)) list.files(run_root, "^fit_summary_row[.]csv$", recursive = TRUE, full.names = TRUE) else character()
  rows <- lapply(paths, function(path) {
    x <- tryCatch(utils::read.csv(path, check.names = FALSE, stringsAsFactors = FALSE), error = function(e) NULL)
    if (is.null(x) || !nrow(x)) return(NULL)
    x <- x[1L, , drop = FALSE]
    hp <- file.path(dirname(path), "tables", "forecast_horizon_summary.csv")
    h <- if (file.exists(hp)) tryCatch(utils::read.csv(hp, check.names = FALSE, stringsAsFactors = FALSE), error = function(e) NULL) else NULL
    h1000 <- if (!is.null(h) && nrow(h)) h[which(as.integer(h$horizon) == 1000L)[1L], , drop = FALSE] else NULL
    cp <- file.path(dirname(path), "chain_summary.csv")
    ch <- if (file.exists(cp)) tryCatch(utils::read.csv(cp, check.names = FALSE, stringsAsFactors = FALSE), error = function(e) NULL) else NULL
    healthp <- file.path(dirname(path), "health_summary.csv")
    health <- if (file.exists(healthp)) tryCatch(utils::read.csv(healthp, check.names = FALSE, stringsAsFactors = FALSE), error = function(e) NULL) else NULL
    x$bundle_id <- id; x$run_tag <- tag
    x$fit_summary_path <- normalizePath(path, winslash = "/", mustWork = TRUE)
    x$fit_summary_sha256 <- unname(tools::sha256sum(path))
    x$forecast_horizon_path <- if (file.exists(hp)) normalizePath(hp, winslash = "/", mustWork = TRUE) else NA_character_
    x$forecast_horizon_sha256 <- if (file.exists(hp)) unname(tools::sha256sum(hp)) else NA_character_
    x$metric_fit_rmse <- as.numeric(x$train_qtrue_rmse[[1L]] %||% NA_real_)
    x$metric_forecast_mae <- if (!is.null(h1000) && nrow(h1000)) as.numeric(h1000$qtrue_mae[[1L]]) else NA_real_
    x$metric_forecast_check <- if (!is.null(h1000) && nrow(h1000)) as.numeric(h1000$pinball_tau[[1L]]) else NA_real_
    get_chain <- function(par, col) {
      if (is.null(ch) || !nrow(ch) || !all(c("parameter", col) %in% names(ch))) return(NA_real_)
      z <- ch[ch$parameter == par, col, drop = TRUE]; if (length(z)) as.numeric(z[[1L]]) else NA_real_
    }
    x$gamma_ess <- get_chain("gamma", "ess"); x$sigma_ess <- get_chain("sigma", "ess")
    x$gamma_acf1 <- get_chain("gamma", "acf1"); x$sigma_acf1 <- get_chain("sigma", "acf1")
    runtime <- as.numeric(x$fit_runtime_seconds[[1L]] %||% x$runtime_sec[[1L]] %||% NA_real_)
    x$gamma_ess_per_sec <- if (is.finite(runtime) && runtime > 0) x$gamma_ess / runtime else NA_real_
    x$sigma_ess_per_sec <- if (is.finite(runtime) && runtime > 0) x$sigma_ess / runtime else NA_real_
    if (!is.null(health) && nrow(health)) {
      for (nm in intersect(c("mcmc_ess_per_second_gamma", "mcmc_ess_per_second_sigma"), names(health))) {
        target <- sub("mcmc_ess_per_second_", "", nm); x[[paste0(target, "_ess_per_sec")]] <- as.numeric(health[[nm]][[1L]])
      }
    }
    x$metric_complete <- all(is.finite(c(x$metric_fit_rmse, x$metric_forecast_mae, x$metric_forecast_check)))
    x
  })
  rows <- Filter(Negate(is.null), rows); observed <- if (length(rows)) do.call(rbind, rows) else data.frame()
  if (nrow(observed)) metric_rows[[id]] <- observed
  observed_ids <- if (nrow(observed)) unique(as.character(observed$spec_id)) else character()
  missing <- setdiff(unique(as.character(expected$spec_id)), observed_ids)
  if (length(missing)) missing_rows[[id]] <- data.frame(bundle_id = id, spec_id = missing)
  heavy <- if (dir.exists(run_root)) list.files(run_root, "[.](rds|rda|RData)$", recursive = TRUE, full.names = TRUE, ignore.case = TRUE) else character()
  if (length(heavy)) heavy_rows[[id]] <- data.frame(bundle_id = id, path = heavy, bytes = file.info(heavy)$size)
  inventory_rows[[id]] <- data.frame(
    bundle_id = id, run_tag = tag, run_root = run_root, expected = nrow(expected),
    observed = length(observed_ids), complete = if (nrow(observed)) sum(observed$metric_complete) else 0L,
    missing = length(missing), heavy = length(heavy), stringsAsFactors = FALSE
  )
}
metrics <- if (length(metric_rows)) do.call(rbind, metric_rows) else data.frame()
profile_keep <- c("screening_profile_id", "target_cell_id", "target_role", "target_family", "target_tau",
                  "likelihood_target", "bundle_id", "arm_code", "experiment", "reservoir_replicate",
                  "paired_reservoir_seed", "D", "n_each", "m", "alpha", "rho", "pi_w", "pi_in", "rhs_tau0")
if (nrow(metrics)) {
  metrics <- merge(metrics, profiles[, profile_keep], by = c("screening_profile_id", "bundle_id"), all.x = TRUE, sort = FALSE)
  if (!"source_scenario" %in% names(metrics)) metrics$source_scenario <- metrics$scenario
  metrics <- metrics[!duplicated(metrics$spec_id), , drop = FALSE]
}
inventory <- do.call(rbind, inventory_rows)
missing <- if (length(missing_rows)) do.call(rbind, missing_rows) else data.frame(bundle_id = character(), spec_id = character())
heavy <- if (length(heavy_rows)) do.call(rbind, heavy_rows) else data.frame(bundle_id = character(), path = character(), bytes = numeric())
metrics_path <- write_csv(metrics, file.path(output_root, "qdesn_metrics.csv"))
inventory_path <- write_csv(inventory, file.path(output_root, "run_inventory.csv"))
missing_path <- write_csv(missing, file.path(output_root, "missing_spec_ids.csv"))
heavy_path <- write_csv(heavy, file.path(output_root, "storage_heavy_artifact_audit.csv"))

al <- if (nrow(metrics)) metrics[metrics$experiment == "al_confirmation", , drop = FALSE] else metrics
parents <- al[al$arm_code == "parent_exact", c("source_scenario", "reservoir_replicate", "metric_fit_rmse", "metric_forecast_mae", "metric_forecast_check", "spec_id"), drop = FALSE]
names(parents)[3:6] <- c("parent_fit_rmse", "parent_forecast_mae", "parent_forecast_check", "parent_spec_id")
paired <- merge(al, parents, by = c("source_scenario", "reservoir_replicate"), all.x = TRUE, sort = FALSE)
paired$fit_ratio <- ratio(paired$metric_fit_rmse, paired$parent_fit_rmse)
paired$forecast_mae_ratio <- ratio(paired$metric_forecast_mae, paired$parent_forecast_mae)
paired$forecast_check_ratio <- ratio(paired$metric_forecast_check, paired$parent_forecast_check)
paired_path <- write_csv(paired, file.path(output_root, "al_paired_metrics.csv"))
candidate <- paired[paired$arm_code != "parent_exact", , drop = FALSE]
al_summary <- if (nrow(candidate)) do.call(rbind, lapply(split(seq_len(nrow(candidate)), candidate$arm_code), function(idx) {
  x <- candidate[idx, , drop = FALSE]; article <- grepl("m0amp_highnoise", x$source_scenario)
  data.frame(
    arm_code = x$arm_code[[1L]], expected_pairs = 6L,
    complete_pairs = sum(is.finite(x$fit_ratio) & is.finite(x$forecast_mae_ratio) & is.finite(x$forecast_check_ratio)),
    median_fit_ratio = med(x$fit_ratio), median_forecast_mae_ratio = med(x$forecast_mae_ratio),
    median_forecast_check_ratio = med(x$forecast_check_ratio), worst_q90_ratio = max(c(q90(x$fit_ratio), q90(x$forecast_mae_ratio), q90(x$forecast_check_ratio))),
    article_median_forecast_mae_ratio = med(x$forecast_mae_ratio[article]),
    article_median_fit_ratio = med(x$fit_ratio[article]), article_median_check_ratio = med(x$forecast_check_ratio[article]),
    stringsAsFactors = FALSE
  )
})) else data.frame()
if (nrow(al_summary)) al_summary$promotion_eligible <- with(al_summary,
  complete_pairs == expected_pairs & median_forecast_mae_ratio <= 0.95 & article_median_forecast_mae_ratio <= 0.95 &
  median_fit_ratio <= 1.05 & median_forecast_check_ratio <= 1.05 & article_median_fit_ratio <= 1.05 &
  article_median_check_ratio <= 1.05 & worst_q90_ratio <= 1.10)
al_summary_path <- write_csv(al_summary, file.path(output_root, "al_confirmation_summary.csv"))

exal <- if (nrow(metrics)) metrics[metrics$experiment == "exal_sampler_diagnostic", , drop = FALSE] else metrics
exal_summary <- if (nrow(exal)) do.call(rbind, lapply(split(seq_len(nrow(exal)), exal$arm_code), function(idx) {
  x <- exal[idx, , drop = FALSE]
  data.frame(
    arm_code = x$arm_code[[1L]], expected_roots = 6L, complete_roots = sum(x$metric_complete),
    median_gamma_ess_per_sec = med(x$gamma_ess_per_sec), median_sigma_ess_per_sec = med(x$sigma_ess_per_sec),
    median_min_core_ess_per_sec = med(pmin(x$gamma_ess_per_sec, x$sigma_ess_per_sec)),
    median_gamma_acf1 = med(x$gamma_acf1), median_sigma_acf1 = med(x$sigma_acf1),
    median_max_core_acf1 = med(pmax(x$gamma_acf1, x$sigma_acf1)),
    median_fit_rmse = med(x$metric_fit_rmse), median_forecast_mae = med(x$metric_forecast_mae),
    median_forecast_check = med(x$metric_forecast_check), stringsAsFactors = FALSE
  )
})) else data.frame()
if (nrow(exal_summary)) exal_summary <- exal_summary[order(-exal_summary$median_min_core_ess_per_sec, exal_summary$median_max_core_acf1), , drop = FALSE]
exal_summary_path <- write_csv(exal_summary, file.path(output_root, "exal_sampler_summary.csv"))

comparator_index_path <- file.path(state_root, "comparator_index.csv")
comp_index <- if (file.exists(comparator_index_path)) utils::read.csv(comparator_index_path, check.names = FALSE, stringsAsFactors = FALSE) else data.frame()
comp_rows <- list(); comp_heavy <- character()
if (nrow(comp_index)) for (i in seq_len(nrow(comp_index))) {
  root <- as.character(comp_index$run_root[[i]])
  paths <- if (dir.exists(file.path(root, "metrics"))) list.files(file.path(root, "metrics"), "[.]csv$", full.names = TRUE) else character()
  for (p in paths) { x <- tryCatch(utils::read.csv(p, check.names = FALSE, stringsAsFactors = FALSE), error = function(e) NULL); if (!is.null(x) && nrow(x)) { x$source_role <- comp_index$source_role[[i]]; x$metrics_path <- p; comp_rows[[length(comp_rows) + 1L]] <- x } }
  if (dir.exists(root)) comp_heavy <- c(comp_heavy, list.files(root, "[.](rds|rda|RData)$", recursive = TRUE, full.names = TRUE, ignore.case = TRUE))
}
comparators <- if (length(comp_rows)) do.call(rbind, comp_rows) else data.frame()
comparators_path <- write_csv(comparators, file.path(output_root, "structured_comparator_metrics.csv"))
comp_heavy_path <- write_csv(data.frame(path = comp_heavy, bytes = if (length(comp_heavy)) file.info(comp_heavy)$size else numeric()), file.path(output_root, "structured_comparator_heavy_artifacts.csv"))

complete <- sum(inventory$complete) == sum(inventory$expected) && nrow(missing) == 0L && nrow(comparators) == 4L
storage_ok <- nrow(heavy) == 0L && length(comp_heavy) == 0L
al_pass <- nrow(al_summary) && any(al_summary$promotion_eligible)
decision <- if (!complete) "BLOCK_INCOMPLETE" else if (!storage_ok) "BLOCK_STORAGE_POLICY" else if (al_pass) {
  "AL_CONFIRMATION_CANDIDATE_READY_FOR_EXPLICIT_PROMOTION_REVIEW"
} else "NO_AL_PROMOTION_EXAL_DIAGNOSTIC_CLOSED"
gate <- list(
  generated_at = as.character(Sys.time()), decision = decision, complete = complete,
  qdesn_complete_roots = sum(inventory$complete), qdesn_expected_roots = sum(inventory$expected),
  structured_comparator_rows = nrow(comparators), heavy_payloads = nrow(heavy) + length(comp_heavy),
  al_promotion_candidate = al_pass,
  al_selected_arm = if (al_pass) as.character(al_summary$arm_code[which(al_summary$promotion_eligible)[1L]]) else NULL,
  exal_diagnostic_selected_arm = if (nrow(exal_summary)) as.character(exal_summary$arm_code[[1L]]) else NULL,
  exal_article_ready = FALSE, article_update_allowed = FALSE,
  next_gate = if (al_pass) "explicit_human_review_then_surgical_promotion" else "freeze_evidence_and_reassess_model_or_sampler",
  evidence = list(metrics = metrics_path, inventory = inventory_path, missing = missing_path, heavy = heavy_path,
                  al_paired = paired_path, al_summary = al_summary_path, exal_summary = exal_summary_path,
                  comparators = comparators_path, comparator_heavy = comp_heavy_path)
)
gate_path <- write_json(gate, file.path(output_root, "followup_gate.json"))
writeLines(c(
  "# Q-DESN Train-Only Follow-up v1 Closeout", "",
  sprintf("- decision: `%s`", decision),
  sprintf("- Q-DESN roots complete: `%d/%d`", sum(inventory$complete), sum(inventory$expected)),
  sprintf("- structured comparator rows: `%d/4`", nrow(comparators)),
  sprintf("- unexpected heavy payloads: `%d`", nrow(heavy) + length(comp_heavy)),
  sprintf("- AL promotion candidate: `%s`", al_pass),
  "- exAL sampler evidence is diagnostic only and cannot update the article.",
  "- article update remains disabled pending explicit review."
), file.path(output_root, "README.md"))
cat(sprintf("Decision: %s\n", decision))
cat(sprintf("Gate: %s\n", gate_path))
if (!complete || !storage_ok) quit(status = 2L, save = "no")

#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  if (!requireNamespace("jsonlite", quietly = TRUE)) {
    stop("The jsonlite package is required.", call. = FALSE)
  }
})

args <- commandArgs(trailingOnly = TRUE)
get_arg <- function(flag, default = NULL) {
  idx <- which(args == flag)
  if (!length(idx)) return(default)
  idx <- idx[[1L]]
  if (idx >= length(args)) return(default)
  args[[idx + 1L]]
}

`%||%` <- function(a, b) if (is.null(a) || !length(a)) b else a

repo_root <- normalizePath(
  system2("git", c("rev-parse", "--show-toplevel"), stdout = TRUE)[[1L]],
  winslash = "/",
  mustWork = TRUE
)
setwd(repo_root)

default_run_tag <- "qdesn-dynamic-fitforecast-v2-mcmc-tt500-20260520-035319__git-d075941"
default_campaign_id <- "20260525-191523__git-d075941"
run_tag <- get_arg("--run-tag", default_run_tag)
campaign_id <- get_arg("--campaign-id", default_campaign_id)

default_results_root <- file.path(
  repo_root,
  "results/qdesn_mcmc_validation/dynamic_fitforecast_v2_validation",
  run_tag,
  campaign_id
)
default_report_root <- file.path(
  repo_root,
  "reports/qdesn_mcmc_validation/dynamic_fitforecast_v2_validation",
  run_tag,
  campaign_id
)
default_launch_root <- file.path(
  repo_root,
  "reports/qdesn_mcmc_validation/dynamic_fitforecast_v2_validation",
  run_tag,
  "launch"
)

resolve_path <- function(path, must_work = FALSE) {
  path <- as.character(path)[[1L]]
  if (!startsWith(path, "/")) path <- file.path(repo_root, path)
  normalizePath(path, winslash = "/", mustWork = must_work)
}

campaign_results_root <- resolve_path(get_arg("--campaign-results-root", default_results_root), TRUE)
campaign_report_root <- resolve_path(get_arg("--campaign-report-root", default_report_root), FALSE)
launch_root <- resolve_path(get_arg("--launch-root", default_launch_root), TRUE)
selected_atomic_specs_path <- resolve_path(
  get_arg("--selected-atomic-specs", file.path(launch_root, "selected_atomic_specs_full.csv")),
  TRUE
)
selected_grid_path <- resolve_path(
  get_arg("--selected-grid", file.path(launch_root, "selected_grid_full.csv")),
  TRUE
)
preflight_manifest_path <- resolve_path(
  get_arg("--preflight-manifest", file.path(launch_root, "qdesn_dynamic_exdqlm_crossstudy_preflight_manifest.json")),
  FALSE
)
out_dir <- resolve_path(
  get_arg("--out-dir", file.path(campaign_report_root, "provisional_progress")),
  FALSE
)
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

read_csv_or_empty <- function(path) {
  if (!file.exists(path)) return(data.frame(stringsAsFactors = FALSE))
  utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
}

first_present <- function(...) {
  vals <- list(...)
  for (val in vals) {
    if (is.null(val) || !length(val)) next
    out <- val[[1L]]
    if (!is.na(out) && nzchar(as.character(out))) return(out)
  }
  NA
}

get_col <- function(x, name, default = NA) {
  if (!nrow(x) || !name %in% names(x)) return(default)
  x[[name]][[1L]]
}

safe_sha256 <- function(path) {
  path <- as.character(path %||% "")[[1L]]
  if (!nzchar(path) || !file.exists(path)) return(NA_character_)
  unname(tools::sha256sum(path))
}

safe_mtime <- function(path) {
  path <- as.character(path %||% "")[[1L]]
  if (!nzchar(path) || !file.exists(path)) return(NA_character_)
  format(file.info(path)$mtime, "%Y-%m-%d %H:%M:%S %Z")
}

read_status <- function(path) {
  if (!file.exists(path)) return(NA_character_)
  txt <- tryCatch(readLines(path, warn = FALSE), error = function(e) character())
  if (!length(txt)) return(NA_character_)
  trimws(txt[[1L]])
}

read_last_lines <- function(path, n = 200L) {
  if (!file.exists(path)) return(character())
  txt <- tryCatch(readLines(path, warn = FALSE), error = function(e) character())
  if (!length(txt)) return(character())
  utils::tail(txt, n)
}

parse_progress <- function(path) {
  lines <- read_last_lines(path, 400L)
  if (!length(lines)) {
    return(list(stage = NA_character_, current_iter = NA_integer_,
                total_iter = NA_integer_, latest_line = NA_character_))
  }
  progress_lines <- lines[grepl("burn-in iteration|MCMC iteration|sampling iteration|posterior iteration|forecast", lines)]
  latest <- if (length(progress_lines)) utils::tail(progress_lines, 1L) else utils::tail(lines, 1L)

  if (grepl("burn-in iteration[[:space:]]+[0-9]+", latest)) {
    iter <- as.integer(sub(".*burn-in iteration[[:space:]]+([0-9]+).*", "\\1", latest))
    return(list(stage = "mcmc_burn_in", current_iter = iter,
                total_iter = 25000L, latest_line = latest))
  }
  if (grepl("(MCMC|sampling|posterior) iteration[[:space:]]+[0-9]+", latest)) {
    iter <- as.integer(sub(".*(MCMC|sampling|posterior) iteration[[:space:]]+([0-9]+).*", "\\2", latest))
    return(list(stage = "mcmc_sampling", current_iter = 5000L + iter,
                total_iter = 25000L, latest_line = latest))
  }
  if (grepl("forecast", latest, ignore.case = TRUE)) {
    return(list(stage = "forecast", current_iter = NA_integer_,
                total_iter = NA_integer_, latest_line = latest))
  }
  list(stage = NA_character_, current_iter = NA_integer_,
       total_iter = NA_integer_, latest_line = latest)
}

as_boolish <- function(x) {
  if (is.logical(x)) return(ifelse(is.na(x), NA_character_, as.character(x)))
  as.character(x)
}

preflight <- if (file.exists(preflight_manifest_path)) {
  jsonlite::read_json(preflight_manifest_path, simplifyVector = TRUE)
} else {
  list()
}
atomic_specs <- read_csv_or_empty(selected_atomic_specs_path)
selected_grid <- read_csv_or_empty(selected_grid_path)
if (!nrow(atomic_specs)) stop("No atomic specs found.", call. = FALSE)

registry_root <- "/data/jaguir26/local/src/shared_dynamic_fit_forecast_validation/sources/dlm_constV_p90_m0amp_highnoise_steepertrend_v2_TTmain10000_fitforecast"
registry_hash <- "edddb56fc2b30e49ac99fdd08b53dad468ed53e05d0fe1fe16426ee9d9ffe275"
branch <- system2("git", c("branch", "--show-current"), stdout = TRUE)[[1L]]
commit <- system2("git", c("rev-parse", "HEAD"), stdout = TRUE)[[1L]]
package_version <- as.character(read.dcf(file.path(repo_root, "DESCRIPTION"))[1L, "Version"])
generated_at <- format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")

row_for_spec <- function(spec) {
  root_id <- as.character(spec$root_id)
  likelihood_family <- as.character(spec$likelihood_family)
  fit_dir <- file.path(campaign_results_root, "roots", root_id, "fits", paste0("mcmc_", likelihood_family))
  fit_summary_path <- file.path(fit_dir, "fit_summary_row.csv")
  horizon_path <- file.path(fit_dir, "tables", "forecast_horizon_summary.csv")
  lead_metrics_path <- file.path(fit_dir, "tables", "forecast_lead_metrics.csv")
  fit_status_path <- file.path(fit_dir, "manifest", "fit_status.txt")
  retention_path <- file.path(fit_dir, "manifest", "output_retention.json")
  log_path <- file.path(fit_dir, "logs", "pipeline_child_live.log")
  fit_request_path <- file.path(fit_dir, "fit_request.json")

  fit_summary <- read_csv_or_empty(fit_summary_path)
  horizon <- read_csv_or_empty(horizon_path)
  grid <- selected_grid[selected_grid$root_id == root_id, , drop = FALSE]
  if (nrow(grid) > 1L) grid <- grid[1L, , drop = FALSE]

  h100 <- horizon[horizon$window == "forecast_H100" | horizon$horizon == 100L, , drop = FALSE]
  h1000 <- horizon[horizon$window == "forecast_H1000" | horizon$horizon == 1000L, , drop = FALSE]
  if (nrow(h100) > 1L) h100 <- h100[1L, , drop = FALSE]
  if (nrow(h1000) > 1L) h1000 <- h1000[1L, , drop = FALSE]

  fit_summary_present <- file.exists(fit_summary_path)
  horizon_present <- file.exists(horizon_path)
  fit_status <- read_status(fit_status_path)
  progress <- parse_progress(log_path)

  exal_complete <- file.exists(file.path(campaign_results_root, "roots", root_id, "fits", "mcmc_exal", "fit_summary_row.csv")) &&
    file.exists(file.path(campaign_results_root, "roots", root_id, "fits", "mcmc_exal", "tables", "forecast_horizon_summary.csv"))
  exal_running <- identical(read_status(file.path(campaign_results_root, "roots", root_id, "fits", "mcmc_exal", "manifest", "fit_status.txt")), "RUNNING")

  completion_state <- if (fit_summary_present && horizon_present) {
    "complete"
  } else if (identical(fit_status, "RUNNING")) {
    "running"
  } else if (dir.exists(fit_dir)) {
    "incomplete_existing"
  } else {
    "pending"
  }
  placeholder_reason <- switch(
    completion_state,
    complete = "metrics_available",
    running = "fit_or_forecast_running",
    incomplete_existing = "fit_directory_exists_without_complete_summary",
    pending = if (identical(likelihood_family, "al") && (isTRUE(exal_running) || !isTRUE(exal_complete))) {
      "awaiting_exal_completion_before_al"
    } else {
      "awaiting_scheduler_slot"
    }
  )

  status <- if (identical(completion_state, "complete")) {
    first_present(get_col(fit_summary, "status"), "SUCCESS")
  } else if (identical(completion_state, "running")) {
    "RUNNING"
  } else if (identical(completion_state, "pending")) {
    "PENDING_AUTOSCHEDULED"
  } else {
    "INCOMPLETE"
  }

  data.frame(
    provisional_table_version = "qdesn_tt500_atomic_progress_v1",
    provisional_generated_at = generated_at,
    is_final = FALSE,
    article_consumable = FALSE,
    article_consumption_policy = "progress_status_only_not_final_result_table",
    run_tag = run_tag,
    campaign_id = campaign_id,
    spec_id = as.character(spec$spec_id),
    root_id = root_id,
    dataset_cell_id = as.character(spec$dataset_cell_id),
    model_family = "qdesn",
    model_variant = paste0("qdesn_", as.character(spec$prior)),
    family = as.character(spec$family),
    tau = as.numeric(spec$tau),
    fit_size = as.integer(spec$fit_size),
    effective_fit_size = as.integer(first_present(get_col(grid, "effective_fit_size"), spec$fit_size)),
    prior = as.character(spec$prior),
    method = as.character(spec$method),
    inference = as.character(spec$inference),
    likelihood_family = likelihood_family,
    status = status,
    completion_state = completion_state,
    placeholder_reason = placeholder_reason,
    metrics_available = fit_summary_present && horizon_present,
    fit_summary_present = fit_summary_present,
    forecast_horizon_summary_present = horizon_present,
    fit_status = fit_status,
    progress_stage = progress$stage,
    progress_current_iter = progress$current_iter,
    progress_total_iter = progress$total_iter,
    progress_latest_line = progress$latest_line,
    log_last_modified_at = safe_mtime(log_path),
    TT_warmup = 2000L,
    TT_main = 10000L,
    TT_total = 12000L,
    train_start_source_index = as.integer(first_present(get_col(grid, "train_start_source_index"), 8501L)),
    train_end_source_index = as.integer(first_present(get_col(grid, "train_end_source_index"), 9000L)),
    forecast_origin_source_index = 9000L,
    forecast_start_source_index = as.integer(first_present(get_col(grid, "forecast_start_source_index"), 9001L)),
    forecast_end_source_index = as.integer(first_present(get_col(grid, "forecast_end_source_index"), 10000L)),
    max_lead_configured = 30L,
    origin_stride = 30L,
    source_registry_id = "dlm_constV_p90_m0amp_highnoise_steepertrend_v2_TTmain10000_fitforecast",
    source_registry_root = registry_root,
    source_registry_hash_name = "000__bundle_manifest.json.sha256",
    source_registry_hash_value = registry_hash,
    source_series_wide_path = first_present(get_col(grid, "source_series_wide_path")),
    source_series_wide_sha256 = first_present(get_col(grid, "source_series_wide_sha256")),
    source_sim_path = first_present(get_col(grid, "source_sim_path")),
    source_sim_sha256 = first_present(get_col(grid, "source_sim_sha256")),
    fit_runtime_seconds = get_col(fit_summary, "fit_runtime_seconds"),
    runtime_sec = get_col(fit_summary, "runtime_sec"),
    iter_like = get_col(fit_summary, "iter_like"),
    signoff_grade = get_col(fit_summary, "signoff_grade"),
    signoff_reason = get_col(fit_summary, "signoff_reason"),
    finite_ok = as_boolish(get_col(fit_summary, "finite_ok")),
    domain_ok = as_boolish(get_col(fit_summary, "domain_ok")),
    comparison_eligible = as_boolish(get_col(fit_summary, "comparison_eligible")),
    train_n_eval = get_col(fit_summary, "train_n_eval"),
    train_qtrue_mae = get_col(fit_summary, "train_qtrue_mae"),
    train_qtrue_rmse = get_col(fit_summary, "train_qtrue_rmse"),
    train_qtrue_bias = get_col(fit_summary, "train_qtrue_bias"),
    train_pinball_tau = get_col(fit_summary, "train_pinball_tau"),
    holdout_n_eval = get_col(fit_summary, "holdout_n_eval"),
    holdout_qtrue_mae = get_col(fit_summary, "holdout_qtrue_mae"),
    holdout_qtrue_rmse = get_col(fit_summary, "holdout_qtrue_rmse"),
    holdout_qtrue_bias = get_col(fit_summary, "holdout_qtrue_bias"),
    holdout_pinball_tau = get_col(fit_summary, "holdout_pinball_tau"),
    forecast_h100_n = get_col(h100, "n_eval"),
    forecast_h100_start_source_index = get_col(h100, "source_index_first"),
    forecast_h100_end_source_index = get_col(h100, "source_index_last"),
    forecast_h100_qtrue_mae = get_col(h100, "qtrue_mae"),
    forecast_h100_qtrue_rmse = get_col(h100, "qtrue_rmse"),
    forecast_h100_qtrue_bias = get_col(h100, "qtrue_bias"),
    forecast_h100_pinball_tau = get_col(h100, "pinball_tau"),
    forecast_h1000_n = get_col(h1000, "n_eval"),
    forecast_h1000_start_source_index = get_col(h1000, "source_index_first"),
    forecast_h1000_end_source_index = get_col(h1000, "source_index_last"),
    forecast_h1000_qtrue_mae = get_col(h1000, "qtrue_mae"),
    forecast_h1000_qtrue_rmse = get_col(h1000, "qtrue_rmse"),
    forecast_h1000_qtrue_bias = get_col(h1000, "qtrue_bias"),
    forecast_h1000_pinball_tau = get_col(h1000, "pinball_tau"),
    campaign_results_root = campaign_results_root,
    campaign_report_root = campaign_report_root,
    launch_root = launch_root,
    fit_dir = fit_dir,
    fit_request_path = if (file.exists(fit_request_path)) fit_request_path else NA_character_,
    fit_status_path = if (file.exists(fit_status_path)) fit_status_path else NA_character_,
    log_path = if (file.exists(log_path)) log_path else NA_character_,
    fit_summary_path = if (file.exists(fit_summary_path)) fit_summary_path else NA_character_,
    fit_summary_sha256 = safe_sha256(fit_summary_path),
    forecast_horizon_summary_path = if (file.exists(horizon_path)) horizon_path else NA_character_,
    forecast_horizon_summary_sha256 = safe_sha256(horizon_path),
    forecast_lead_metrics_path = if (file.exists(lead_metrics_path)) lead_metrics_path else NA_character_,
    forecast_lead_metrics_sha256 = safe_sha256(lead_metrics_path),
    artifact_retention_path = if (file.exists(retention_path)) retention_path else NA_character_,
    artifact_retention_sha256 = safe_sha256(retention_path),
    validation_repo = repo_root,
    validation_branch = branch,
    validation_commit = commit,
    package_version = package_version,
    stringsAsFactors = FALSE
  )
}

atomic_rows <- lapply(seq_len(nrow(atomic_specs)), function(i) row_for_spec(atomic_specs[i, , drop = FALSE]))
atomic_progress <- do.call(rbind, atomic_rows)
atomic_progress <- atomic_progress[order(
  atomic_progress$family,
  atomic_progress$tau,
  atomic_progress$prior,
  atomic_progress$likelihood_family
), , drop = FALSE]

state_count <- function(x, state) sum(identical(state, x) | x == state, na.rm = TRUE)
complete_total <- sum(atomic_progress$completion_state == "complete", na.rm = TRUE)
running_total <- sum(atomic_progress$completion_state == "running", na.rm = TRUE)
pending_total <- sum(atomic_progress$completion_state == "pending", na.rm = TRUE)
incomplete_total <- sum(atomic_progress$completion_state == "incomplete_existing", na.rm = TRUE)

root_rows <- lapply(split(atomic_progress, atomic_progress$root_id), function(x) {
  exal <- x[x$likelihood_family == "exal", , drop = FALSE]
  al <- x[x$likelihood_family == "al", , drop = FALSE]
  data.frame(
    provisional_table_version = "qdesn_tt500_root_progress_v1",
    provisional_generated_at = generated_at,
    is_final = FALSE,
    article_consumable = FALSE,
    run_tag = run_tag,
    campaign_id = campaign_id,
    root_id = x$root_id[[1L]],
    dataset_cell_id = x$dataset_cell_id[[1L]],
    family = x$family[[1L]],
    tau = x$tau[[1L]],
    fit_size = x$fit_size[[1L]],
    prior = x$prior[[1L]],
    atomic_specs_total = nrow(x),
    atomic_specs_complete = sum(x$completion_state == "complete", na.rm = TRUE),
    atomic_specs_running = sum(x$completion_state == "running", na.rm = TRUE),
    atomic_specs_pending = sum(x$completion_state == "pending", na.rm = TRUE),
    root_completion_state = if (all(x$completion_state == "complete")) {
      "complete"
    } else if (any(x$completion_state == "running")) {
      "running"
    } else if (any(x$completion_state == "complete")) {
      "partial_waiting"
    } else {
      "pending"
    },
    exal_state = get_col(exal, "completion_state"),
    exal_status = get_col(exal, "status"),
    exal_progress_stage = get_col(exal, "progress_stage"),
    exal_progress_current_iter = get_col(exal, "progress_current_iter"),
    exal_progress_total_iter = get_col(exal, "progress_total_iter"),
    al_state = get_col(al, "completion_state"),
    al_status = get_col(al, "status"),
    al_progress_stage = get_col(al, "progress_stage"),
    al_progress_current_iter = get_col(al, "progress_current_iter"),
    al_progress_total_iter = get_col(al, "progress_total_iter"),
    stringsAsFactors = FALSE
  )
})
root_progress <- do.call(rbind, root_rows)
root_progress <- root_progress[order(root_progress$family, root_progress$tau, root_progress$prior), , drop = FALSE]

atomic_path <- file.path(out_dir, "tt500_provisional_atomic_progress.csv")
root_path <- file.path(out_dir, "tt500_provisional_root_progress.csv")
manifest_path <- file.path(out_dir, "tt500_provisional_manifest.json")
readme_path <- file.path(out_dir, "README.md")

utils::write.csv(atomic_progress, atomic_path, row.names = FALSE, na = "")
utils::write.csv(root_progress, root_path, row.names = FALSE, na = "")

manifest <- list(
  artifact = "qdesn_tt500_provisional_progress",
  artifact_version = "v1",
  is_final = FALSE,
  article_consumable = FALSE,
  article_consumption_policy = "progress_status_only_not_final_result_table",
  generated_at = generated_at,
  run_tag = run_tag,
  campaign_id = campaign_id,
  validation_repo = repo_root,
  validation_branch = branch,
  validation_commit = commit,
  package_version = package_version,
  campaign_results_root = campaign_results_root,
  campaign_report_root = campaign_report_root,
  launch_root = launch_root,
  selected_atomic_specs_path = selected_atomic_specs_path,
  selected_atomic_specs_sha256 = safe_sha256(selected_atomic_specs_path),
  selected_grid_path = selected_grid_path,
  selected_grid_sha256 = safe_sha256(selected_grid_path),
  preflight_manifest_path = if (file.exists(preflight_manifest_path)) preflight_manifest_path else NULL,
  preflight_manifest_sha256 = safe_sha256(preflight_manifest_path),
  source_registry_root = registry_root,
  source_registry_hash_name = "000__bundle_manifest.json.sha256",
  source_registry_hash_value = registry_hash,
  source_contract = list(
    TT_warmup = 2000L,
    TT_main = 10000L,
    TT_total = 12000L,
    TT500_train_window = "8501:9000",
    forecast_origin_source_index = 9000L,
    forecast_block = "9001:10000",
    max_lead_configured = 30L,
    origin_stride = 30L
  ),
  counts = list(
    atomic_specs_total = nrow(atomic_progress),
    atomic_specs_complete = complete_total,
    atomic_specs_running = running_total,
    atomic_specs_pending = pending_total,
    atomic_specs_incomplete_existing = incomplete_total,
    root_specs_total = nrow(root_progress),
    root_specs_complete = sum(root_progress$root_completion_state == "complete", na.rm = TRUE),
    root_specs_running = sum(root_progress$root_completion_state == "running", na.rm = TRUE),
    root_specs_partial_waiting = sum(root_progress$root_completion_state == "partial_waiting", na.rm = TRUE),
    root_specs_pending = sum(root_progress$root_completion_state == "pending", na.rm = TRUE)
  ),
  outputs = list(
    atomic_progress_path = normalizePath(atomic_path, winslash = "/", mustWork = TRUE),
    atomic_progress_sha256 = safe_sha256(atomic_path),
    root_progress_path = normalizePath(root_path, winslash = "/", mustWork = TRUE),
    root_progress_sha256 = safe_sha256(root_path),
    readme_path = normalizePath(readme_path, winslash = "/", mustWork = FALSE)
  ),
  update_command = paste(
    "Rscript scripts/export_qdesn_tt500_provisional_progress_table.R",
    "--run-tag", run_tag,
    "--campaign-id", campaign_id
  ),
  note = "This is a live progress artifact. It deliberately contains placeholders and must not be consumed as a final article-facing validation interface or scientific result table."
)
jsonlite::write_json(manifest, manifest_path, auto_unbox = TRUE, pretty = TRUE, null = "null")
manifest$outputs$manifest_path <- normalizePath(manifest_path, winslash = "/", mustWork = TRUE)
jsonlite::write_json(manifest, manifest_path, auto_unbox = TRUE, pretty = TRUE, null = "null")

readme <- c(
  "# Q-DESN TT500 Provisional Progress Table",
  "",
  paste0("Generated: `", generated_at, "`"),
  "",
  "This directory is a live, storage-light progress snapshot for the Q-DESN TT500 MCMC validation campaign.",
  "It is intentionally not a final article-facing shared interface and must not be used as a scientific result table.",
  "",
  "## Files",
  "",
  paste0("- `", basename(atomic_path), "`: one row per atomic likelihood-family spec, including placeholders."),
  paste0("- `", basename(root_path), "`: one row per Q-DESN root, summarizing EXAL/AL status."),
  paste0("- `", basename(manifest_path), "`: provenance, counts, hashes, source contract, and update command."),
  "",
  "## Current Counts",
  "",
  paste0("- atomic specs: ", nrow(atomic_progress)),
  paste0("- complete: ", complete_total),
  paste0("- running: ", running_total),
  paste0("- pending: ", pending_total),
  paste0("- incomplete existing: ", incomplete_total),
  "",
  "## Update Command",
  "",
  "```sh",
  paste(
    "cd", shQuote(repo_root), "&&",
    "Rscript scripts/export_qdesn_tt500_provisional_progress_table.R",
    "--run-tag", shQuote(run_tag),
    "--campaign-id", shQuote(campaign_id)
  ),
  "```",
  "",
  "## Article Consumption Rule",
  "",
  "Article-Q-DESN may read this table only for progress, preflight, or explicitly labeled status displays.",
  "Rows have `is_final = FALSE` and `article_consumable = FALSE` by design.",
  "Final article result tables must wait for campaign closeout and the final shared fit+forecast interface export."
)
writeLines(readme, readme_path, useBytes = TRUE)

cat(sprintf("atomic_progress_rows: %d\n", nrow(atomic_progress)))
cat(sprintf("root_progress_rows: %d\n", nrow(root_progress)))
cat(sprintf("complete_atomic_specs: %d\n", complete_total))
cat(sprintf("running_atomic_specs: %d\n", running_total))
cat(sprintf("pending_atomic_specs: %d\n", pending_total))
cat(sprintf("atomic_progress_path: %s\n", normalizePath(atomic_path, winslash = "/", mustWork = TRUE)))
cat(sprintf("root_progress_path: %s\n", normalizePath(root_path, winslash = "/", mustWork = TRUE)))
cat(sprintf("manifest_path: %s\n", normalizePath(manifest_path, winslash = "/", mustWork = TRUE)))

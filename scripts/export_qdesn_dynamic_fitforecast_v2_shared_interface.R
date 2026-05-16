#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  req <- c("jsonlite", "pkgload")
  need <- setdiff(req, rownames(installed.packages()))
  if (length(need)) install.packages(need, repos = "https://cloud.r-project.org")
  invisible(lapply(req, require, character.only = TRUE))
})

args <- commandArgs(trailingOnly = TRUE)
get_arg <- function(flag, default = NULL) {
  idx <- which(args == flag)
  if (!length(idx)) return(default)
  idx <- idx[1L]
  if (is.na(idx) || idx >= length(args)) return(default)
  args[idx + 1L]
}
`%||%` <- function(a, b) if (is.null(a)) b else a

repo_root <- tryCatch(
  normalizePath(system("git rev-parse --show-toplevel", intern = TRUE), winslash = "/", mustWork = TRUE),
  error = function(...) normalizePath(".", winslash = "/", mustWork = TRUE)
)
setwd(repo_root)
pkgload::load_all(repo_root, quiet = TRUE)

resolve_path <- function(path, must_work = TRUE) {
  raw <- as.character(path %||% "")[1L]
  if (!nzchar(trimws(raw))) return(NULL)
  if (!grepl("^(/|~)", raw)) raw <- file.path(repo_root, raw)
  normalizePath(raw, winslash = "/", mustWork = isTRUE(must_work))
}

read_csv_or_empty <- function(path) {
  if (is.null(path) || !file.exists(path)) return(data.frame(stringsAsFactors = FALSE))
  utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
}

first_nonempty <- function(...) {
  vals <- list(...)
  for (val in vals) {
    if (is.null(val) || !length(val)) next
    out <- val[[1L]]
    if (!is.na(out) && nzchar(as.character(out))) return(out)
  }
  NA
}

get_col <- function(df, row, name) {
  if (!nrow(df) || !name %in% names(df)) return(NA)
  df[[name]][[row]]
}

schema_path <- resolve_path(
  get_arg("--schema", "validation/fitforecast_v2/schema/shared_fitforecast_interface_schema.csv"),
  must_work = TRUE
)
schema <- read_csv_or_empty(schema_path)
columns <- as.character(schema$column)

preflight_path <- resolve_path(get_arg("--preflight-manifest", ""), must_work = FALSE)
preflight <- if (!is.null(preflight_path) && file.exists(preflight_path)) {
  jsonlite::read_json(preflight_path, simplifyVector = TRUE)
} else {
  list()
}
selected_grid <- read_csv_or_empty(preflight$selected_grid_path %||% get_arg("--selected-grid", ""))
campaign_report_root <- resolve_path(get_arg("--campaign-report-root", ""), must_work = FALSE)
fit_summary_path <- resolve_path(
  get_arg("--fit-summary", if (!is.null(campaign_report_root)) file.path(campaign_report_root, "tables", "campaign_fit_summary.csv") else ""),
  must_work = FALSE
)
fit_summary <- read_csv_or_empty(fit_summary_path)

out_path <- resolve_path(
  get_arg("--out", if (!is.null(campaign_report_root)) {
    file.path(campaign_report_root, "interfaces", "qdesn_dynamic_fitforecast_v2_shared_interface.csv")
  } else {
    file.path("reports", "qdesn_mcmc_validation", "dynamic_fitforecast_v2_validation", "interfaces", "qdesn_dynamic_fitforecast_v2_shared_interface.csv")
  }),
  must_work = FALSE
)

branch <- trimws(system("git rev-parse --abbrev-ref HEAD", intern = TRUE))
commit <- trimws(system("git rev-parse HEAD", intern = TRUE))
pkg_version <- tryCatch(as.character(utils::packageVersion("exdqlm")), error = function(e) {
  desc <- tryCatch(utils::read.dcf(file.path(repo_root, "DESCRIPTION")), error = function(e) NULL)
  if (!is.null(desc) && "Version" %in% colnames(desc)) as.character(desc[1L, "Version"]) else NA_character_
})
registry_root <- "/data/jaguir26/local/src/shared_dynamic_fit_forecast_validation/sources/dlm_constV_p90_m0amp_highnoise_steepertrend_v2_TTmain10000_fitforecast"
registry_hash <- "edddb56fc2b30e49ac99fdd08b53dad468ed53e05d0fe1fe16426ee9d9ffe275"

rows <- vector("list", nrow(fit_summary))
for (i in seq_len(nrow(fit_summary))) {
  root_id <- as.character(first_nonempty(get_col(fit_summary, i, "root_id")))
  grid_row <- if (nrow(selected_grid) && "root_id" %in% names(selected_grid)) {
    selected_grid[as.character(selected_grid$root_id) == root_id, , drop = FALSE]
  } else {
    data.frame(stringsAsFactors = FALSE)
  }
  if (nrow(grid_row) > 1L) grid_row <- grid_row[1L, , drop = FALSE]

  row <- as.data.frame(
    as.list(stats::setNames(rep(NA_character_, length(columns)), columns)),
    stringsAsFactors = FALSE
  )
  row$validation_contract_id <- "qdesn_exdqlm_dqlm_dynamic_fitforecast_v2_shared_interface"
  row$study_id <- "qdesn_dynamic_fitforecast_v2"
  row$run_tag <- first_nonempty(preflight$run_tag, get_col(fit_summary, i, "run_tag"))
  row$model_family <- "qdesn"
  row$model_variant <- first_nonempty(get_col(fit_summary, i, "canonical_model"), get_col(grid_row, 1L, "beta_prior_type"))
  row$inference <- first_nonempty(get_col(fit_summary, i, "inference"))
  row$phase <- first_nonempty(preflight$batch, get_col(fit_summary, i, "phase"))
  row$status <- first_nonempty(get_col(fit_summary, i, "status"), get_col(fit_summary, i, "root_status"))
  row$failure_reason <- first_nonempty(get_col(fit_summary, i, "failure_reason"), get_col(fit_summary, i, "error_message"))
  row$health_gate <- first_nonempty(get_col(fit_summary, i, "health_gate"), get_col(fit_summary, i, "finite_ok"))
  row$signoff_grade <- first_nonempty(get_col(fit_summary, i, "signoff_grade"))
  row$source_registry_root <- registry_root
  row$source_registry_hash_name <- "000__bundle_manifest.json.sha256"
  row$source_registry_hash_value <- registry_hash
  row$source_cell_id <- first_nonempty(get_col(grid_row, 1L, "dataset_cell_id"))
  row$scenario_id <- first_nonempty(get_col(grid_row, 1L, "source_scenario"), get_col(fit_summary, i, "scenario"))
  row$family <- first_nonempty(get_col(grid_row, 1L, "source_family"), get_col(fit_summary, i, "family"))
  row$tau <- first_nonempty(get_col(grid_row, 1L, "tau"), get_col(fit_summary, i, "tau"))
  row$tau_label <- gsub("\\.", "p", sprintf("%.2f", as.numeric(row$tau)))
  row$fit_size <- first_nonempty(get_col(grid_row, 1L, "fit_size"), get_col(fit_summary, i, "fit_size"))
  row$effective_fit_size <- first_nonempty(get_col(grid_row, 1L, "effective_fit_size"), row$fit_size)
  row$TT_warmup <- 2000L
  row$TT_main <- 10000L
  row$TT_total <- 12000L
  row$train_start_source_index <- first_nonempty(get_col(grid_row, 1L, "train_start_source_index"))
  row$train_end_source_index <- first_nonempty(get_col(grid_row, 1L, "train_end_source_index"))
  row$forecast_origin_source_index <- 9000L
  row$forecast_start_source_index <- first_nonempty(get_col(grid_row, 1L, "forecast_start_source_index"), 9001L)
  row$forecast_end_source_index <- first_nonempty(get_col(grid_row, 1L, "forecast_end_source_index"), 10000L)
  row$forecast_h100_start_source_index <- 9001L
  row$forecast_h100_end_source_index <- 9100L
  row$forecast_h1000_start_source_index <- 9001L
  row$forecast_h1000_end_source_index <- 10000L
  row$fit_n <- first_nonempty(get_col(fit_summary, i, "train_n"), get_col(fit_summary, i, "fit_n"))
  row$fit_q_mae <- first_nonempty(get_col(fit_summary, i, "train_qtrue_mae"), get_col(fit_summary, i, "fit_q_mae"))
  row$fit_q_rmse <- first_nonempty(get_col(fit_summary, i, "train_qtrue_rmse"), get_col(fit_summary, i, "fit_q_rmse"))
  row$fit_pinball_mean <- first_nonempty(get_col(fit_summary, i, "train_pinball_tau"), get_col(fit_summary, i, "fit_pinball_mean"))
  row$runtime_sec_total <- first_nonempty(get_col(fit_summary, i, "runtime_sec"))
  row$runtime_sec <- row$runtime_sec_total
  row$row_metrics_path <- first_nonempty(fit_summary_path)
  row$fit_path_summary_path <- first_nonempty(get_col(fit_summary, i, "fit_quantile_path_train_file"))
  row$forecast_path_summary_path <- first_nonempty(get_col(fit_summary, i, "fit_quantile_path_holdout_file"))
  row$package_version <- pkg_version
  row$branch <- branch
  row$commit <- commit
  rows[[i]] <- row
}

out <- if (length(rows)) do.call(rbind, rows) else {
  empty <- data.frame(matrix(ncol = length(columns), nrow = 0L), stringsAsFactors = FALSE)
  names(empty) <- columns
  empty
}
out <- out[, columns, drop = FALSE]
dir.create(dirname(out_path), recursive = TRUE, showWarnings = FALSE)
utils::write.csv(out, out_path, row.names = FALSE)
cat(sprintf("qdesn_shared_interface_rows: %d\n", nrow(out)))
cat(sprintf("qdesn_shared_interface: %s\n", normalizePath(out_path, winslash = "/", mustWork = TRUE)))

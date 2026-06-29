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

repo_root <- tryCatch(
  normalizePath(system2("git", c("rev-parse", "--show-toplevel"), stdout = TRUE)[[1L]],
                winslash = "/", mustWork = TRUE),
  error = function(...) normalizePath(".", winslash = "/", mustWork = TRUE)
)
setwd(repo_root)

resolve_path <- function(path, must_work = TRUE) {
  raw <- as.character(path)[[1L]]
  if (!grepl("^(/|~)", raw)) raw <- file.path(repo_root, raw)
  normalizePath(raw, winslash = "/", mustWork = isTRUE(must_work))
}

read_csv <- function(path) {
  utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
}

sha256_or_na <- function(path) {
  if (!file.exists(path)) return(NA_character_)
  unname(tools::sha256sum(path))
}

stage4a_report_root <- resolve_path(get_arg(
  "--stage4a-report-root",
  "reports/qdesn_mcmc_validation/qdesn_dynamic_fitforecast_v2_tt500_vb_stage4_remaining_cells_transfer/qdesn-tt500-vb-stage4-transfer-full-20260629__git-a59c631/20260629-035305__git-a59c631"
), must_work = TRUE)
stage4b_report_root <- resolve_path(get_arg(
  "--stage4b-report-root",
  "reports/qdesn_mcmc_validation/qdesn_dynamic_fitforecast_v2_tt500_vb_stage4b_gausmix005_pinball_refinement/qdesn-tt500-vb-stage4b-gausmix005-pinball-full-20260629__git-52a1821/20260629-040813__git-52a1821"
), must_work = TRUE)
out_csv <- resolve_path(get_arg(
  "--out-csv",
  "validation/fitforecast_v2/docs/qdesn_tt500_vb_stage4_best_candidate_ledger_2026-06-29.csv"
), must_work = FALSE)
out_manifest <- resolve_path(get_arg(
  "--out-manifest",
  "validation/fitforecast_v2/docs/qdesn_tt500_vb_stage4_best_candidate_ledger_2026-06-29_manifest.json"
), must_work = FALSE)

metric_cols <- c(
  "forecast_mae_ratio_vs_best_vb_baseline",
  "forecast_pinball_ratio_vs_best_vb_baseline",
  "fit_rmse_ratio_vs_best_vb_baseline",
  "fit_pinball_ratio_vs_best_vb_baseline"
)

load_stage <- function(stage, report_root) {
  cell_path <- file.path(report_root, "tables", "qdesn_tt500_vb_dominance_cell_summary.csv")
  audit_path <- file.path(report_root, "audit", "tables", "qdesn_tt500_vb_screen_audit_summary.csv")
  if (!file.exists(cell_path)) stop("Missing dominance cell summary: ", cell_path, call. = FALSE)
  if (!file.exists(audit_path)) stop("Missing strict audit summary: ", audit_path, call. = FALSE)
  x <- read_csv(cell_path)
  audit <- read_csv(audit_path)
  missing <- setdiff(metric_cols, names(x))
  if (length(missing)) {
    stop("Dominance summary is missing columns: ", paste(missing, collapse = ", "),
         call. = FALSE)
  }
  x$stage <- stage
  x$stage_report_root <- report_root
  x$stage_cell_summary_path <- cell_path
  x$stage_cell_summary_sha256 <- sha256_or_na(cell_path)
  x$stage_strict_audit_path <- audit_path
  x$stage_strict_audit_sha256 <- sha256_or_na(audit_path)
  x$stage_strict_ready <- if ("strict_ready" %in% names(audit)) as.logical(audit$strict_ready[[1L]]) else NA
  x$stage_n_success <- if ("n_success" %in% names(audit)) audit$n_success[[1L]] else NA
  x$stage_n_fail <- if ("n_fail" %in% names(audit)) audit$n_fail[[1L]] else NA
  x$stage_forbidden_binary_count_total <-
    if ("forbidden_binary_count_total" %in% names(audit)) audit$forbidden_binary_count_total[[1L]] else NA
  x$worst_metric_ratio <- do.call(pmax, c(x[, metric_cols, drop = FALSE], na.rm = FALSE))
  x
}

combined <- rbind(
  load_stage("stage4a_remaining_cells_transfer", stage4a_report_root),
  load_stage("stage4b_gausmix005_pinball_refinement", stage4b_report_root)
)

target_keys <- c(
  "gausmix:0.05",
  "gausmix:0.50",
  "laplace:0.05",
  "laplace:0.25",
  "laplace:0.50",
  "normal:0.05"
)
combined$cell_key <- paste(combined$family, sprintf("%.2f", as.numeric(combined$tau)), sep = ":")
combined <- combined[combined$cell_key %in% target_keys, , drop = FALSE]
if (!nrow(combined)) stop("No target rows found in Stage 4 summaries.", call. = FALSE)

best <- do.call(rbind, lapply(split(combined, combined$cell_key), function(z) {
  z <- z[order(!as.logical(z$beats_all_primary_baselines), z$worst_metric_ratio,
               z$forecast_pinball_ratio_vs_best_vb_baseline), , drop = FALSE]
  z[1L, , drop = FALSE]
}))
best <- best[match(target_keys, best$cell_key), , drop = FALSE]

missing_cells <- setdiff(target_keys, best$cell_key)
if (length(missing_cells)) {
  stop("Missing target cells: ", paste(missing_cells, collapse = ", "), call. = FALSE)
}
if (!all(as.logical(best$beats_all_primary_baselines))) {
  failed <- best$cell_key[!as.logical(best$beats_all_primary_baselines)]
  stop("Some best candidates do not dominate the primary baseline: ",
       paste(failed, collapse = ", "), call. = FALSE)
}

keep <- c(
  "cell_key", "family", "tau", "stage", "screening_profile_base",
  "beats_all_primary_baselines", "worst_metric_ratio", metric_cols,
  "qdesn_runtime_sec_mean", "D", "n_each", "alpha", "rho", "m",
  "readout_y_lags", "reservoir_lags", "pi_w", "pi_in", "n_active_parameters",
  "p_over_n_tt500", "stage_strict_ready", "stage_n_success", "stage_n_fail",
  "stage_forbidden_binary_count_total", "stage_report_root",
  "stage_cell_summary_path", "stage_cell_summary_sha256",
  "stage_strict_audit_path", "stage_strict_audit_sha256"
)
keep <- intersect(keep, names(best))
best <- best[, keep, drop = FALSE]

dir.create(dirname(out_csv), recursive = TRUE, showWarnings = FALSE)
utils::write.csv(best, out_csv, row.names = FALSE, na = "")

manifest <- list(
  generated_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"),
  repo_root = repo_root,
  branch = system2("git", c("branch", "--show-current"), stdout = TRUE)[[1L]],
  purpose = paste(
    "Tracked promotion-candidate ledger for Q-DESN TT500 VB Stage 4A/4B",
    "remaining-cell repairs. This is not an Article table by itself."
  ),
  stage4a_report_root = stage4a_report_root,
  stage4b_report_root = stage4b_report_root,
  output_csv = out_csv,
  output_csv_sha256 = sha256_or_na(out_csv),
  output_manifest = out_manifest,
  target_cells = target_keys,
  n_candidates = nrow(best),
  all_candidates_dominate_primary_vb_baseline =
    all(as.logical(best$beats_all_primary_baselines)),
  storage_light_contract = "strict audits require zero forbidden binary payloads",
  article_policy = paste(
    "Candidate ledger only. Article-facing table updates require an explicit",
    "promotion step that records this ledger and source report roots."
  )
)
jsonlite::write_json(manifest, out_manifest, auto_unbox = TRUE, pretty = TRUE)

cat(sprintf("candidate_ledger: %s\n", out_csv))
cat(sprintf("candidate_ledger_sha256: %s\n", sha256_or_na(out_csv)))
cat(sprintf("manifest: %s\n", out_manifest))

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
  idx <- idx[[1L]]
  if (idx >= length(args)) return(default)
  args[[idx + 1L]]
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

article_summary_path <- resolve_path(get_arg(
  "--article-summary",
  "/data/jaguir26/local/src/Article-Q-DESN__wt__main_validation_tables/tables/qdesn_validation_tt500_final_summary.csv"
), must_work = TRUE)
out_dir <- resolve_path(get_arg(
  "--out-dir",
  file.path("reports", "qdesn_mcmc_validation", "qdesn_dynamic_fitforecast_v2_tt500_vb_al_rhs_recalibration", "audit")
), must_work = FALSE)

d <- utils::read.csv(article_summary_path, stringsAsFactors = FALSE, check.names = FALSE)
required <- c(
  "model_family", "model_variant", "qdesn_likelihood", "model_key", "inference",
  "family", "tau", "fit_size", "fit_qtrue_rmse", "fit_pinball_mean",
  "forecast_qtrue_mae_lead_weighted", "forecast_pinball_mean_lead_weighted",
  "runtime_hours", "validation_branch", "validation_commit", "article_interface_ids",
  "article_interface_sha256", "source_registry_hash_value"
)
missing <- setdiff(required, names(d))
if (length(missing)) {
  stop(sprintf("Article summary missing column(s): %s", paste(missing, collapse = ", ")), call. = FALSE)
}

d$tau <- as.numeric(d$tau)
d$fit_size <- as.integer(d$fit_size)
q_rhs <- d[
  as.character(d$model_family) == "qdesn" &
    as.character(d$model_variant) == "rhs_ns" &
    as.integer(d$fit_size) == 500L &
    as.character(d$qdesn_likelihood) %in% c("al", "exal"),
  ,
  drop = FALSE
]
if (!nrow(q_rhs)) stop("No Q-DESN RHS rows found.", call. = FALSE)

wide_key <- paste(q_rhs$family, sprintf("%.8f", q_rhs$tau), q_rhs$inference, sep = "\r")
cell_cmp <- exdqlm:::.qdesn_validation_bind_rows(lapply(split(seq_len(nrow(q_rhs)), wide_key), function(idx) {
  sub <- q_rhs[idx, , drop = FALSE]
  al <- sub[as.character(sub$qdesn_likelihood) == "al", , drop = FALSE]
  exal <- sub[as.character(sub$qdesn_likelihood) == "exal", , drop = FALSE]
  if (!nrow(al) || !nrow(exal)) return(data.frame(stringsAsFactors = FALSE))
  data.frame(
    family = as.character(al$family[[1L]]),
    tau = as.numeric(al$tau[[1L]]),
    inference = as.character(al$inference[[1L]]),
    al_fit_rmse = as.numeric(al$fit_qtrue_rmse[[1L]]),
    exal_fit_rmse = as.numeric(exal$fit_qtrue_rmse[[1L]]),
    al_forecast_mae = as.numeric(al$forecast_qtrue_mae_lead_weighted[[1L]]),
    exal_forecast_mae = as.numeric(exal$forecast_qtrue_mae_lead_weighted[[1L]]),
    al_forecast_pinball = as.numeric(al$forecast_pinball_mean_lead_weighted[[1L]]),
    exal_forecast_pinball = as.numeric(exal$forecast_pinball_mean_lead_weighted[[1L]]),
    al_runtime_hours = as.numeric(al$runtime_hours[[1L]]),
    exal_runtime_hours = as.numeric(exal$runtime_hours[[1L]]),
    al_validation_commit = as.character(al$validation_commit[[1L]]),
    exal_validation_commit = as.character(exal$validation_commit[[1L]]),
    al_interface_id = as.character(al$article_interface_ids[[1L]]),
    exal_interface_id = as.character(exal$article_interface_ids[[1L]]),
    stringsAsFactors = FALSE
  )
}))
cell_cmp$mae_ratio_al_over_exal <- cell_cmp$al_forecast_mae / cell_cmp$exal_forecast_mae
cell_cmp$pinball_ratio_al_over_exal <- cell_cmp$al_forecast_pinball / cell_cmp$exal_forecast_pinball
cell_cmp$fit_ratio_al_over_exal <- cell_cmp$al_fit_rmse / cell_cmp$exal_fit_rmse
cell_cmp$al_worse_forecast_mae <- cell_cmp$mae_ratio_al_over_exal > 1
cell_cmp <- cell_cmp[order(cell_cmp$family, cell_cmp$tau, cell_cmp$inference), , drop = FALSE]

rhs_provenance <- as.data.frame(
  table(
    likelihood = as.character(q_rhs$qdesn_likelihood),
    inference = as.character(q_rhs$inference),
    validation_commit = as.character(q_rhs$validation_commit),
    interface_id = as.character(q_rhs$article_interface_ids)
  ),
  stringsAsFactors = FALSE
)
rhs_provenance <- rhs_provenance[rhs_provenance$Freq > 0L, , drop = FALSE]
names(rhs_provenance)[names(rhs_provenance) == "Freq"] <- "n_rows"

active_home_paths <- vapply(c(article_summary_path), function(path) {
  any(grepl("/home/jaguir26/local/src", readLines(path, warn = FALSE), fixed = TRUE))
}, logical(1L))

summary <- data.frame(
  generated_at = as.character(Sys.time()),
  article_summary_path = article_summary_path,
  article_rows = nrow(d),
  qdesn_rhs_rows = nrow(q_rhs),
  qdesn_al_rhs_rows = sum(q_rhs$qdesn_likelihood == "al"),
  qdesn_exal_rhs_rows = sum(q_rhs$qdesn_likelihood == "exal"),
  rhs_comparisons = nrow(cell_cmp),
  al_worse_forecast_mae_comparisons = sum(cell_cmp$al_worse_forecast_mae, na.rm = TRUE),
  max_mae_ratio_al_over_exal = max(cell_cmp$mae_ratio_al_over_exal, na.rm = TRUE),
  min_mae_ratio_al_over_exal = min(cell_cmp$mae_ratio_al_over_exal, na.rm = TRUE),
  all_al_rows_old_base_interface = all(
    q_rhs$qdesn_likelihood != "al" |
      (q_rhs$validation_commit == "ec465f93b7b799e675c40f3a6382c7c6e9ae5727" &
         q_rhs$article_interface_ids %in% c("qdesn_vb", "qdesn_mcmc"))
  ),
  active_home_paths_in_article_summary = any(active_home_paths),
  decision = "targeted_al_rhs_vb_recalibration_required",
  stringsAsFactors = FALSE
)

dir.create(file.path(out_dir, "tables"), recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(out_dir, "summary"), recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(out_dir, "manifest"), recursive = TRUE, showWarnings = FALSE)
paths <- list(
  summary_csv = file.path(out_dir, "tables", "qdesn_tt500_al_rhs_recalibration_need_summary.csv"),
  comparisons_csv = file.path(out_dir, "tables", "qdesn_tt500_al_rhs_vs_exal_rhs_comparisons.csv"),
  provenance_csv = file.path(out_dir, "tables", "qdesn_tt500_rhs_provenance.csv"),
  report_md = file.path(out_dir, "summary", "qdesn_tt500_al_rhs_recalibration_need.md"),
  manifest_json = file.path(out_dir, "manifest", "qdesn_tt500_al_rhs_recalibration_need_manifest.json")
)
exdqlm:::.qdesn_validation_write_df(summary, paths$summary_csv)
exdqlm:::.qdesn_validation_write_df(cell_cmp, paths$comparisons_csv)
exdqlm:::.qdesn_validation_write_df(rhs_provenance, paths$provenance_csv)

display_cols <- c(
  "family", "tau", "inference", "al_forecast_mae", "exal_forecast_mae",
  "mae_ratio_al_over_exal", "al_forecast_pinball", "exal_forecast_pinball",
  "pinball_ratio_al_over_exal", "al_validation_commit", "al_interface_id"
)
report <- c(
  "# Q-DESN TT500 AL RHS Recalibration Need Audit",
  "",
  sprintf("- generated_at: `%s`", summary$generated_at[[1L]]),
  sprintf("- article_summary_path: `%s`", article_summary_path),
  sprintf("- article_rows: `%d`", summary$article_rows[[1L]]),
  sprintf("- qdesn_al_rhs_rows: `%d`", summary$qdesn_al_rhs_rows[[1L]]),
  sprintf("- qdesn_exal_rhs_rows: `%d`", summary$qdesn_exal_rhs_rows[[1L]]),
  sprintf("- al_worse_forecast_mae_comparisons: `%d / %d`", summary$al_worse_forecast_mae_comparisons[[1L]], summary$rhs_comparisons[[1L]]),
  sprintf("- all_al_rows_old_base_interface: `%s`", summary$all_al_rows_old_base_interface[[1L]]),
  sprintf("- active_home_paths_in_article_summary: `%s`", summary$active_home_paths_in_article_summary[[1L]]),
  "",
  "## Interpretation",
  "",
  "The Article table is reporting the validation artifacts faithfully. The AL RHS rows are old base-interface rows, while exAL RHS rows are later repair/promotion rows. The fair next step is a targeted VB-only AL RHS recalibration screen before any MCMC confirmation.",
  "",
  "## AL RHS vs exAL RHS",
  exdqlm:::.qdesn_validation_df_to_markdown(cell_cmp[, intersect(display_cols, names(cell_cmp)), drop = FALSE]),
  "",
  "## Provenance",
  exdqlm:::.qdesn_validation_df_to_markdown(rhs_provenance)
)
exdqlm:::.qdesn_validation_write_lines(paths$report_md, report)
manifest <- list(
  generated_at = as.character(Sys.time()),
  article_summary_path = article_summary_path,
  output_paths = paths,
  summary = summary,
  file_manifest = exdqlm:::qdesn_validation_file_manifest(c(article_summary_path, unlist(paths, use.names = FALSE)))
)
exdqlm:::.qdesn_validation_write_json(paths$manifest_json, manifest)

cat(sprintf("summary_csv: %s\n", paths$summary_csv))
cat(sprintf("comparisons_csv: %s\n", paths$comparisons_csv))
cat(sprintf("provenance_csv: %s\n", paths$provenance_csv))
cat(sprintf("report_md: %s\n", paths$report_md))
cat(sprintf("manifest_json: %s\n", paths$manifest_json))
cat(sprintf("al_worse_forecast_mae: %d/%d\n", summary$al_worse_forecast_mae_comparisons[[1L]], summary$rhs_comparisons[[1L]]))

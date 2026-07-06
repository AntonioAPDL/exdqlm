#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  if (!requireNamespace("jsonlite", quietly = TRUE)) {
    stop("Package `jsonlite` is required.", call. = FALSE)
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
`%||%` <- function(a, b) if (is.null(a)) b else a

repo_root <- normalizePath(system("git rev-parse --show-toplevel", intern = TRUE), winslash = "/", mustWork = TRUE)
setwd(repo_root)
resolve <- function(path, must_work = TRUE) {
  raw <- as.character(path)[1L]
  if (!grepl("^(/|~)", raw)) raw <- file.path(repo_root, raw)
  normalizePath(raw, winslash = "/", mustWork = isTRUE(must_work))
}
rel <- function(path) normalizePath(path, winslash = "/", mustWork = FALSE)
read_csv <- function(path) utils::read.csv(resolve(path), stringsAsFactors = FALSE, check.names = FALSE)
write_csv <- function(x, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(x, path, row.names = FALSE, na = "")
}
sha256 <- function(path) {
  path <- resolve(path)
  out <- tryCatch(system2("sha256sum", path, stdout = TRUE, stderr = TRUE), error = function(e) NA_character_)
  if (!length(out) || is.na(out[[1L]])) return(NA_character_)
  strsplit(out[[1L]], "[[:space:]]+")[[1L]][[1L]]
}
file_manifest <- function(paths) {
  paths <- unique(paths[file.exists(paths)])
  data.frame(
    path = rel(paths),
    bytes = as.numeric(file.info(paths)$size),
    sha256 = vapply(paths, sha256, character(1L)),
    stringsAsFactors = FALSE
  )
}
fmt <- function(x, digits = 3L) {
  ifelse(is.na(x), "", formatC(as.numeric(x), format = "f", digits = digits))
}
first_existing <- function(paths) {
  paths <- vapply(paths, resolve, character(1L), must_work = FALSE)
  hit <- paths[file.exists(paths)]
  if (!length(hit)) return(paths[[1L]])
  hit[[1L]]
}

out_dir <- resolve(get_arg(
  "--out-dir",
  file.path("validation", "fitforecast_v2", "promotions", "vb_targeted_refinement_evidence_20260706")
), must_work = FALSE)
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

ex_run_root <- resolve(get_arg(
  "--exdqlm-run-root",
  file.path("validation", "fitforecast_v2", "runs", "20260706_exdqlm_dqlm_vb_tau005_refinement__git-0d22ebc")
))
q_report_root <- resolve(get_arg(
  "--qdesn-report-root",
  file.path(
    "reports", "qdesn_mcmc_validation", "qdesn_dynamic_fitforecast_v2_tt500_vb_rhs_fitaware_refinement",
    "qdesn-tt500-vb-rhs-fitaware-refinement-20260706__git-42c2727",
    "20260706-024112__git-0d22ebc"
  )
))

ex_winners_path <- file.path(ex_run_root, "screen_summary", "candidate_cell_winners.csv")
ex_status_path <- file.path(ex_run_root, "manifests", "status_counts.csv")
ex_storage_path <- file.path(ex_run_root, "storage", "storage_audit.csv")
q_audit_path <- file.path(q_report_root, "audit", "tables", "qdesn_tt500_vb_screen_audit_summary.csv")
q_dominance_path <- file.path(q_report_root, "tables", "qdesn_tt500_vb_dominance_profile_ranking.csv")
q_cell_path <- file.path(q_report_root, "tables", "qdesn_tt500_vb_dominance_cell_summary.csv")
q_fit_path <- file.path(q_report_root, "tables", "qdesn_tt500_vb_screen_fit_forecast_summary.csv")

required <- c(ex_winners_path, ex_status_path, ex_storage_path, q_audit_path, q_dominance_path, q_cell_path, q_fit_path)
missing <- required[!file.exists(required)]
if (length(missing)) {
  stop(sprintf("Missing targeted VB evidence path(s): %s", paste(missing, collapse = ", ")), call. = FALSE)
}

ex_winners <- read_csv(ex_winners_path)
ex_status <- read_csv(ex_status_path)
ex_storage <- read_csv(ex_storage_path)
q_audit <- read_csv(q_audit_path)
q_dominance <- read_csv(q_dominance_path)
q_cell <- read_csv(q_cell_path)
q_fit <- read_csv(q_fit_path)

status_name_col <- intersect(c("status", "statuses"), names(ex_status))[1L]
status_count_col <- intersect(c("n", "count", "Freq"), names(ex_status))[1L]
ex_status_display <- if (!is.na(status_name_col) && !is.na(status_count_col)) {
  paste(ex_status[[status_name_col]], ex_status[[status_count_col]], sep = "=", collapse = ", ")
} else {
  paste(utils::capture.output(print(ex_status)), collapse = "; ")
}

ex_key <- paste(ex_winners$family, sprintf("%.8f", as.numeric(ex_winners$tau)), sep = "\r")
ex_pairs <- do.call(rbind, lapply(split(seq_len(nrow(ex_winners)), ex_key), function(idx) {
  sub <- ex_winners[idx, , drop = FALSE]
  d <- sub[as.character(sub$model_variant) == "dqlm", , drop = FALSE]
  e <- sub[as.character(sub$model_variant) == "exdqlm", , drop = FALSE]
  if (!nrow(d) || !nrow(e)) return(NULL)
  data.frame(
    family = d$family[[1L]],
    tau = as.numeric(d$tau[[1L]]),
    dqlm_candidate_id = d$candidate_id[[1L]],
    exdqlm_candidate_id = e$candidate_id[[1L]],
    dqlm_forecast_check_loss = as.numeric(d$forecast_check_loss[[1L]]),
    exdqlm_forecast_check_loss = as.numeric(e$forecast_check_loss[[1L]]),
    exdqlm_to_dqlm_forecast_check_ratio = as.numeric(e$forecast_check_loss[[1L]]) / as.numeric(d$forecast_check_loss[[1L]]),
    dqlm_forecast_mae = as.numeric(d$forecast_qtrue_mae[[1L]]),
    exdqlm_forecast_mae = as.numeric(e$forecast_qtrue_mae[[1L]]),
    exdqlm_to_dqlm_forecast_mae_ratio = as.numeric(e$forecast_qtrue_mae[[1L]]) / as.numeric(d$forecast_qtrue_mae[[1L]]),
    dqlm_fit_rmse = as.numeric(d$fit_qtrue_rmse[[1L]]),
    exdqlm_fit_rmse = as.numeric(e$fit_qtrue_rmse[[1L]]),
    exdqlm_to_dqlm_fit_rmse_ratio = as.numeric(e$fit_qtrue_rmse[[1L]]) / as.numeric(d$fit_qtrue_rmse[[1L]]),
    exdqlm_beats_dqlm_forecast_check = as.numeric(e$forecast_check_loss[[1L]]) < as.numeric(d$forecast_check_loss[[1L]]),
    stringsAsFactors = FALSE
  )
}))
ex_pairs <- ex_pairs[order(ex_pairs$family, ex_pairs$tau), , drop = FALSE]

metric_cols <- c(
  forecast_check = "forecast_pinball_ratio_vs_best_vb_baseline",
  forecast_mae = "forecast_mae_ratio_vs_best_vb_baseline",
  fit_rmse = "fit_rmse_ratio_vs_best_vb_baseline",
  fit_check = "fit_pinball_ratio_vs_best_vb_baseline"
)
missing_q_cols <- setdiff(c("family", "tau", "screening_profile_base", metric_cols), names(q_cell))
if (length(missing_q_cols)) {
  stop(sprintf("Q-DESN dominance cell table is missing column(s): %s", paste(missing_q_cols, collapse = ", ")), call. = FALSE)
}
q_cell$primary_worst_ratio <- do.call(pmax, c(lapply(q_cell[metric_cols], as.numeric), list(na.rm = TRUE)))

pick_cell_best <- function(df, primary_metric) {
  ord <- do.call(order, c(
    list(df$family, as.numeric(df$tau), as.numeric(df[[primary_metric]]), as.numeric(df$primary_worst_ratio)),
    lapply(df[setdiff(metric_cols, primary_metric)], as.numeric),
    list(as.character(df$screening_profile_base))
  ))
  x <- df[ord, , drop = FALSE]
  x[!duplicated(paste(x$family, sprintf("%.8f", as.numeric(x$tau)), sep = "\r")), , drop = FALSE]
}
q_best_check <- pick_cell_best(q_cell, metric_cols[["forecast_check"]])
q_best_mae <- pick_cell_best(q_cell, metric_cols[["forecast_mae"]])
q_best_fit <- pick_cell_best(q_cell, metric_cols[["fit_rmse"]])

q_problem <- q_best_check[
  as.numeric(q_best_check[[metric_cols[["fit_rmse"]]]]) > 1 |
    as.numeric(q_best_check[[metric_cols[["forecast_check"]]]]) >= 1,
  ,
  drop = FALSE
]
q_top_profiles <- utils::head(q_dominance, 40L)

ledger <- rbind(
  data.frame(
    evidence_family = "exdqlm_dqlm",
    family = ex_pairs$family,
    tau = ex_pairs$tau,
    model_or_profile = "exdqlm_vs_dqlm",
    primary_ratio = ex_pairs$exdqlm_to_dqlm_forecast_check_ratio,
    secondary_ratio = ex_pairs$exdqlm_to_dqlm_forecast_mae_ratio,
    fit_ratio = ex_pairs$exdqlm_to_dqlm_fit_rmse_ratio,
    promotion_status = ifelse(
      ex_pairs$exdqlm_to_dqlm_forecast_check_ratio <= 1 &
        ex_pairs$exdqlm_to_dqlm_forecast_mae_ratio <= 1 &
        ex_pairs$exdqlm_to_dqlm_fit_rmse_ratio <= 1,
      "candidate_ready_for_review",
      "diagnostic_not_promoted"
    ),
    reason = "tau005 targeted exDQLM/DQLM VB refinement evidence",
    stringsAsFactors = FALSE
  ),
  data.frame(
    evidence_family = "qdesn_rhs",
    family = q_best_check$family,
    tau = q_best_check$tau,
    model_or_profile = q_best_check$screening_profile_base,
    primary_ratio = q_best_check[[metric_cols[["forecast_check"]]]],
    secondary_ratio = q_best_check[[metric_cols[["forecast_mae"]]]],
    fit_ratio = q_best_check[[metric_cols[["fit_rmse"]]]],
    promotion_status = ifelse(
      q_best_check[[metric_cols[["forecast_check"]]]] < 1 &
        q_best_check[[metric_cols[["forecast_mae"]]]] < 1 &
        q_best_check[[metric_cols[["fit_rmse"]]]] < 1 &
        q_best_check[[metric_cols[["fit_check"]]]] < 1,
      "candidate_ready_for_review",
      "diagnostic_not_promoted"
    ),
    reason = "latest Q-DESN RHS fit-aware VB refinement evidence",
    stringsAsFactors = FALSE
  )
)

paths <- list(
  exdqlm_dqlm_winners = file.path(out_dir, "exdqlm_dqlm_tau005_vb_cell_winners.csv"),
  exdqlm_dqlm_ratios = file.path(out_dir, "exdqlm_dqlm_tau005_vb_cell_ratios.csv"),
  qdesn_best_check = file.path(out_dir, "qdesn_rhs_fitaware_vb_best_cells_by_check_loss.csv"),
  qdesn_best_mae = file.path(out_dir, "qdesn_rhs_fitaware_vb_best_cells_by_forecast_mae.csv"),
  qdesn_best_fit = file.path(out_dir, "qdesn_rhs_fitaware_vb_best_cells_by_fit_rmse.csv"),
  qdesn_top_profiles = file.path(out_dir, "qdesn_rhs_fitaware_vb_top_dominance_profiles.csv"),
  qdesn_audit = file.path(out_dir, "qdesn_rhs_fitaware_vb_audit_summary.csv"),
  promotion_ledger = file.path(out_dir, "promotion_decision_ledger.csv"),
  file_manifest = file.path(out_dir, "file_manifest.csv"),
  manifest = file.path(out_dir, "vb_targeted_refinement_evidence_manifest.json"),
  readme = file.path(out_dir, "README.md")
)
write_csv(ex_winners, paths$exdqlm_dqlm_winners)
write_csv(ex_pairs, paths$exdqlm_dqlm_ratios)
write_csv(q_best_check, paths$qdesn_best_check)
write_csv(q_best_mae, paths$qdesn_best_mae)
write_csv(q_best_fit, paths$qdesn_best_fit)
write_csv(q_top_profiles, paths$qdesn_top_profiles)
write_csv(q_audit, paths$qdesn_audit)
write_csv(ledger, paths$promotion_ledger)

fm <- file_manifest(c(required, unlist(paths[!names(paths) %in% c("file_manifest", "manifest", "readme")])))
write_csv(fm, paths$file_manifest)

readme <- c(
  "# Targeted VB Refinement Evidence Freeze",
  "",
  "Date: 2026-07-06",
  "",
  "## Scope",
  "",
  "This directory freezes the latest targeted VB refinement evidence for planning the next validation screen. It is diagnostic evidence, not an article-authoritative replacement table.",
  "",
  "## Evidence Roots",
  "",
  paste0("- exDQLM/DQLM tau = 0.05 refinement: `", ex_run_root, "`"),
  paste0("- Q-DESN RHS fit-aware refinement: `", q_report_root, "`"),
  paste0("- exDQLM/DQLM status counts: `", ex_status_display, "`"),
  paste0("- exDQLM/DQLM storage audit status: `", paste(unique(ex_storage$status), collapse = ","), "`"),
  paste0("- Q-DESN strict-ready flags: `", paste(unique(q_audit$strict_ready), collapse = ","), "`"),
  "",
  "## Decision Summary",
  "",
  "- exDQLM/DQLM tau = 0.05 still needs calibration: exDQLM remains worse than DQLM in at least one primary metric in each tau = 0.05 family.",
  "- Q-DESN RHS fit-aware refinement improved forecast/check behavior, but fit RMSE remains the active bottleneck; no Q-DESN RHS profile cleanly dominates all primary VB baselines.",
  "- The next Q-DESN screen should be fit-balanced and period-aware rather than only forecast-targeted.",
  "- Internal legacy column names may use `pinball`; manuscript-facing language should call the metric check loss.",
  "",
  "## exDQLM/DQLM tau = 0.05 Ratios",
  "",
  "| Family | exDQLM/DQLM check | exDQLM/DQLM MAE | exDQLM/DQLM fit RMSE |",
  "| --- | ---: | ---: | ---: |"
)
for (i in seq_len(nrow(ex_pairs))) {
  readme <- c(readme, paste0(
    "| ", ex_pairs$family[[i]],
    " | ", fmt(ex_pairs$exdqlm_to_dqlm_forecast_check_ratio[[i]]),
    " | ", fmt(ex_pairs$exdqlm_to_dqlm_forecast_mae_ratio[[i]]),
    " | ", fmt(ex_pairs$exdqlm_to_dqlm_fit_rmse_ratio[[i]]),
    " |"
  ))
}
readme <- c(
  readme,
  "",
  "## Q-DESN RHS Cells Still Failing At Least One Primary Metric",
  "",
  "| Family | Tau | Best check-loss profile | Check ratio | Forecast MAE ratio | Fit RMSE ratio |",
  "| --- | ---: | --- | ---: | ---: | ---: |"
)
for (i in seq_len(nrow(q_problem))) {
  readme <- c(readme, paste0(
    "| ", q_problem$family[[i]],
    " | ", fmt(q_problem$tau[[i]], 2L),
    " | ", q_problem$screening_profile_base[[i]],
    " | ", fmt(q_problem[[metric_cols[["forecast_check"]]]][[i]]),
    " | ", fmt(q_problem[[metric_cols[["forecast_mae"]]]][[i]]),
    " | ", fmt(q_problem[[metric_cols[["fit_rmse"]]]][[i]]),
    " |"
  ))
}
readme <- c(
  readme,
  "",
  "## Generated Files",
  "",
  paste0("- promotion ledger: `", paths$promotion_ledger, "`"),
  paste0("- exDQLM/DQLM ratios: `", paths$exdqlm_dqlm_ratios, "`"),
  paste0("- Q-DESN best check-loss cells: `", paths$qdesn_best_check, "`"),
  paste0("- Q-DESN best fit-RMSE cells: `", paths$qdesn_best_fit, "`"),
  paste0("- file manifest: `", paths$file_manifest, "`"),
  "",
  "## Next Authorized Screening",
  "",
  "1. Run a Q-DESN RHS VB fit-balanced broad screen with period-aware readout memory.",
  "2. Continue exDQLM/DQLM VB calibration separately before any broad MCMC promotion.",
  "3. Do not promote these diagnostic rows as final article evidence without an explicit freeze/signoff."
)
writeLines(readme, paths$readme)

manifest <- list(
  generated_at = as.character(Sys.time()),
  repo_root = repo_root,
  git_branch = trimws(system("git rev-parse --abbrev-ref HEAD", intern = TRUE)),
  git_sha = trimws(system("git rev-parse HEAD", intern = TRUE)),
  git_dirty = length(system("git status --porcelain", intern = TRUE)) > 0L,
  evidence = list(
    exdqlm_run_root = ex_run_root,
    qdesn_report_root = q_report_root,
    exdqlm_status_counts = ex_status,
    qdesn_audit = q_audit
  ),
  output_paths = paths,
  file_manifest = fm,
  promotion_status = "targeted_refinement_evidence_frozen_not_article_authoritative",
  blocked_promotions = list(
    exdqlm_dqlm = "tau=0.05 exDQLM remains above DQLM on at least one primary metric",
    qdesn_rhs = "latest Q-DESN RHS fit-aware VB screen still fails all-primary dominance, mainly on fit RMSE"
  )
)
jsonlite::write_json(manifest, paths$manifest, pretty = TRUE, auto_unbox = TRUE, null = "null")

cat(sprintf("freeze_dir: %s\n", out_dir))
cat(sprintf("manifest: %s\n", paths$manifest))
cat(sprintf("readme: %s\n", paths$readme))
cat(sprintf("ledger: %s\n", paths$promotion_ledger))
cat(sprintf("qdesn_problem_cells: %d\n", nrow(q_problem)))

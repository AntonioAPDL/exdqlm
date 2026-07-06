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
rel <- function(path) normalizePath(path, winslash = "/", mustWork = FALSE)
resolve <- function(path, must_work = TRUE) {
  raw <- as.character(path)[1L]
  if (!grepl("^(/|~)", raw)) raw <- file.path(repo_root, raw)
  normalizePath(raw, winslash = "/", mustWork = must_work)
}
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
fmt <- function(x, digits = 3) {
  ifelse(is.na(x), "", formatC(as.numeric(x), format = "f", digits = digits))
}

out_dir <- resolve(get_arg(
  "--out-dir",
  file.path("validation", "fitforecast_v2", "promotions", "vb_screen_completed_evidence_20260706")
), must_work = FALSE)
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

ex_run_root <- resolve(get_arg(
  "--exdqlm-run-root",
  file.path("validation", "fitforecast_v2", "runs", "20260704_exdqlm_dqlm_vb_noninferiority_screen__git-65fbf35")
))
q_report_root <- resolve(get_arg(
  "--qdesn-report-root",
  file.path(
    "reports", "qdesn_mcmc_validation", "qdesn_dynamic_fitforecast_v2_tt500_vb_rhs_optimization",
    "qdesn-tt500-vb-rhs-optimization-full-20260704__git-65fbf35",
    "20260704-091641__git-65fbf35"
  )
))

ex_winners_path <- file.path(ex_run_root, "screen_summary", "candidate_cell_winners.csv")
ex_status_path <- file.path(ex_run_root, "manifests", "status_counts.csv")
ex_storage_path <- file.path(ex_run_root, "storage", "storage_audit.csv")
q_audit_path <- file.path(q_report_root, "audit", "tables", "qdesn_tt500_vb_screen_audit_summary.csv")
q_dominance_path <- file.path(q_report_root, "tables", "qdesn_tt500_vb_dominance_profile_ranking.csv")
q_cell_path <- file.path(q_report_root, "tables", "qdesn_tt500_vb_dominance_cell_summary.csv")
q_fit_path <- file.path(q_report_root, "tables", "qdesn_tt500_vb_screen_fit_forecast_summary.csv")

required_paths <- c(ex_winners_path, ex_status_path, ex_storage_path, q_audit_path, q_dominance_path, q_cell_path, q_fit_path)
missing <- required_paths[!file.exists(required_paths)]
if (length(missing)) {
  stop(sprintf("Missing completed-screen evidence path(s): %s", paste(missing, collapse = ", ")), call. = FALSE)
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
    dqlm_forecast_check = as.numeric(d$forecast_check_loss[[1L]]),
    exdqlm_forecast_check = as.numeric(e$forecast_check_loss[[1L]]),
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

q_best <- q_cell[order(
  q_cell$family,
  as.numeric(q_cell$tau),
  as.numeric(q_cell$forecast_pinball_ratio_vs_best_vb_baseline),
  as.numeric(q_cell$forecast_mae_ratio_vs_best_vb_baseline),
  as.numeric(q_cell$fit_rmse_ratio_vs_best_vb_baseline),
  q_cell$screening_profile_base
), , drop = FALSE]
q_best <- q_best[!duplicated(paste(q_best$family, sprintf("%.8f", as.numeric(q_best$tau)), sep = "\r")), , drop = FALSE]
q_best <- q_best[, intersect(c(
  "family", "tau", "screening_profile_base", "profile_role", "D", "n_each", "alpha", "rho",
  "qdesn_forecast_mae_mean", "qdesn_forecast_pinball_mean", "qdesn_fit_rmse_mean", "qdesn_fit_pinball_mean",
  "forecast_mae_ratio_vs_best_vb_baseline", "forecast_pinball_ratio_vs_best_vb_baseline",
  "fit_rmse_ratio_vs_best_vb_baseline", "fit_pinball_ratio_vs_best_vb_baseline",
  "beats_forecast_mae_baseline", "beats_forecast_pinball_baseline",
  "beats_fit_rmse_baseline", "beats_fit_pinball_baseline", "beats_all_primary_baselines"
), names(q_best)), drop = FALSE]

top_profiles <- utils::head(q_dominance, 20L)

paths <- list(
  exdqlm_dqlm_winners = file.path(out_dir, "exdqlm_dqlm_vb_cell_winners.csv"),
  exdqlm_dqlm_ratios = file.path(out_dir, "exdqlm_dqlm_vb_cell_ratios.csv"),
  qdesn_best_cells = file.path(out_dir, "qdesn_rhs_vb_best_cells_by_forecast_check.csv"),
  qdesn_top_profiles = file.path(out_dir, "qdesn_rhs_vb_top_dominance_profiles.csv"),
  qdesn_audit = file.path(out_dir, "qdesn_rhs_vb_audit_summary.csv"),
  file_manifest = file.path(out_dir, "file_manifest.csv"),
  manifest = file.path(out_dir, "vb_screen_completed_evidence_manifest.json"),
  readme = file.path(out_dir, "README.md")
)

write_csv(ex_winners, paths$exdqlm_dqlm_winners)
write_csv(ex_pairs, paths$exdqlm_dqlm_ratios)
write_csv(q_best, paths$qdesn_best_cells)
write_csv(top_profiles, paths$qdesn_top_profiles)
write_csv(q_audit, paths$qdesn_audit)

all_manifest_paths <- c(required_paths, unlist(paths[!names(paths) %in% c("file_manifest", "manifest", "readme")]))
fm <- file_manifest(all_manifest_paths)
write_csv(fm, paths$file_manifest)

ex_low <- ex_pairs[abs(as.numeric(ex_pairs$tau) - 0.05) < 1e-8, , drop = FALSE]
q_problem <- q_best[
  as.numeric(q_best$fit_rmse_ratio_vs_best_vb_baseline) > 1 |
    as.numeric(q_best$forecast_pinball_ratio_vs_best_vb_baseline) >= 1,
  ,
  drop = FALSE
]
readme <- c(
  "# Completed VB Screening Evidence Freeze",
  "",
  "Date: 2026-07-06",
  "",
  "## Scope",
  "",
  "This freeze records the completed broad VB screens for exDQLM/DQLM and Q-DESN RHS. It is evidence for planning the next refinement, not a final article-authoritative promotion.",
  "",
  "## Completed Evidence",
  "",
  paste0("- exDQLM/DQLM run root: `", ex_run_root, "`"),
  paste0("- Q-DESN RHS report root: `", q_report_root, "`"),
  paste0("- exDQLM/DQLM completed rows: `", ex_status_display, "`"),
  paste0("- exDQLM/DQLM storage audit status: `", paste(unique(ex_storage$status), collapse = ","), "`"),
  paste0("- Q-DESN strict ready: `", paste(unique(q_audit$strict_ready), collapse = ","), "`"),
  "",
  "## Diagnostic Interpretation",
  "",
  "- exDQLM is competitive around tau = 0.25 and nearly tied around tau = 0.5, but the tau = 0.05 cells remain the targeted exDQLM/DQLM refinement problem.",
  "- Q-DESN RHS VB completed cleanly, but no profile passes all primary dominance checks; fit RMSE is the most common bottleneck.",
  "- Broad MCMC should wait until the refreshed VB evidence identifies stable, balanced candidates.",
  "",
  "## exDQLM/DQLM tau = 0.05 Ratios",
  "",
  "| Family | exDQLM/DQLM check | exDQLM/DQLM MAE | exDQLM/DQLM fit RMSE |",
  "| --- | ---: | ---: | ---: |"
)
if (nrow(ex_low)) {
  for (i in seq_len(nrow(ex_low))) {
    readme <- c(readme, paste0(
      "| ", ex_low$family[[i]],
      " | ", fmt(ex_low$exdqlm_to_dqlm_forecast_check_ratio[[i]]),
      " | ", fmt(ex_low$exdqlm_to_dqlm_forecast_mae_ratio[[i]]),
      " | ", fmt(ex_low$exdqlm_to_dqlm_fit_rmse_ratio[[i]]),
      " |"
    ))
  }
}
readme <- c(
  readme,
  "",
  "## Q-DESN Cells Requiring Fit-Aware Follow-Up",
  "",
  "| Family | Tau | Best profile | Forecast check ratio | Fit RMSE ratio |",
  "| --- | ---: | --- | ---: | ---: |"
)
if (nrow(q_problem)) {
  for (i in seq_len(nrow(q_problem))) {
    readme <- c(readme, paste0(
      "| ", q_problem$family[[i]],
      " | ", fmt(q_problem$tau[[i]], 2),
      " | ", q_problem$screening_profile_base[[i]],
      " | ", fmt(q_problem$forecast_pinball_ratio_vs_best_vb_baseline[[i]]),
      " | ", fmt(q_problem$fit_rmse_ratio_vs_best_vb_baseline[[i]]),
      " |"
    ))
  }
}
readme <- c(
  readme,
  "",
  "## Generated Files",
  "",
  paste0("- exDQLM/DQLM winners: `", paths$exdqlm_dqlm_winners, "`"),
  paste0("- exDQLM/DQLM ratios: `", paths$exdqlm_dqlm_ratios, "`"),
  paste0("- Q-DESN best cells: `", paths$qdesn_best_cells, "`"),
  paste0("- Q-DESN top profiles: `", paths$qdesn_top_profiles, "`"),
  paste0("- file manifest: `", paths$file_manifest, "`"),
  "",
  "## Next Authorized Refinements",
  "",
  "1. exDQLM/DQLM VB tau = 0.05 refinement only.",
  "2. Q-DESN RHS VB fit-aware refinement only.",
  "3. No broad MCMC until those VB refinements have completed and been audited."
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
    exdqlm_status_counts = as.list(ex_status[1L, , drop = FALSE]),
    qdesn_audit = as.list(q_audit[1L, , drop = FALSE])
  ),
  output_paths = paths,
  file_manifest = fm,
  promotion_status = "screening_evidence_frozen_not_article_authoritative",
  blocked_promotions = list(
    exdqlm_dqlm = "tau=0.05 exDQLM non-inferiority not yet achieved",
    qdesn_rhs = "no profile passes all primary fit and forecast dominance checks"
  )
)
jsonlite::write_json(manifest, paths$manifest, pretty = TRUE, auto_unbox = TRUE, null = "null")

cat(sprintf("freeze_dir: %s\n", out_dir))
cat(sprintf("manifest: %s\n", paths$manifest))
cat(sprintf("readme: %s\n", paths$readme))
cat(sprintf("exdqlm_tau005_problem_cells: %d\n", nrow(ex_low)))
cat(sprintf("qdesn_problem_cells: %d\n", nrow(q_problem)))

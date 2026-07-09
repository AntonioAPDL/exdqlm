#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)

get_arg <- function(flag, default = NULL) {
  idx <- which(args == flag)
  if (!length(idx)) return(default)
  idx <- idx[[1L]]
  if (idx >= length(args)) return(default)
  args[[idx + 1L]]
}

`%||%` <- function(a, b) if (is.null(a) || length(a) == 0L) b else a

repo_root <- tryCatch(
  normalizePath(system("git rev-parse --show-toplevel", intern = TRUE), winslash = "/", mustWork = TRUE),
  error = function(...) normalizePath(".", winslash = "/", mustWork = TRUE)
)
setwd(repo_root)

resolve_path <- function(path, must_work = TRUE) {
  raw <- as.character(path %||% "")[1L]
  if (!nzchar(trimws(raw))) return(NULL)
  if (!grepl("^(/|~)", raw)) raw <- file.path(repo_root, raw)
  normalizePath(raw, winslash = "/", mustWork = isTRUE(must_work))
}

bool_sum <- function(x) {
  if (is.null(x)) return(NA_integer_)
  y <- if (is.logical(x)) x else toupper(trimws(as.character(x))) %in% c("TRUE", "T", "1", "YES")
  sum(y, na.rm = TRUE)
}

safe_min <- function(x) {
  x <- suppressWarnings(as.numeric(x))
  x <- x[is.finite(x)]
  if (!length(x)) return(NA_real_)
  min(x)
}

safe_mean <- function(x) {
  x <- suppressWarnings(as.numeric(x))
  x <- x[is.finite(x)]
  if (!length(x)) return(NA_real_)
  mean(x)
}

write_csv <- function(x, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(x, path, row.names = FALSE, na = "")
  normalizePath(path, winslash = "/", mustWork = TRUE)
}

git_value <- function(root, ...) {
  if (is.null(root) || !dir.exists(root)) return(NA_character_)
  out <- tryCatch(
    system2("git", c("-C", root, ...), stdout = TRUE, stderr = TRUE),
    error = function(e) NA_character_
  )
  if (!length(out)) return("")
  paste(out, collapse = "\n")
}

relative_path <- function(path) {
  sub(paste0("^", gsub("([][{}()+*^$|\\\\?.])", "\\\\\\1", repo_root), "/?"), "", path)
}

screen_parts <- function(path) {
  rel <- relative_path(path)
  pieces <- strsplit(rel, "/", fixed = TRUE)[[1L]]
  idx <- match("qdesn_mcmc_validation", pieces)
  stage <- run_tag <- run_stamp <- NA_character_
  if (is.finite(idx)) {
    stage <- pieces[idx + 1L] %||% NA_character_
    run_tag <- pieces[idx + 2L] %||% NA_character_
    run_stamp <- pieces[idx + 3L] %||% NA_character_
  }
  data.frame(stage = stage, run_tag = run_tag, run_stamp = run_stamp, stringsAsFactors = FALSE)
}

summarize_dominance_file <- function(path) {
  x <- utils::read.csv(path, check.names = FALSE)
  parts <- screen_parts(path)
  info <- file.info(path)
  data.frame(
    modified_time = format(info$mtime, "%Y-%m-%d %H:%M:%S %Z"),
    stage = parts$stage,
    run_tag = parts$run_tag,
    run_stamp = parts$run_stamp,
    n_cell_rows = nrow(x),
    beat_forecast_mae = bool_sum(x$beats_forecast_mae_baseline),
    beat_forecast_check = bool_sum(x$beats_forecast_pinball_baseline),
    beat_fit_rmse = bool_sum(x$beats_fit_rmse_baseline),
    beat_fit_check = bool_sum(x$beats_fit_pinball_baseline),
    beat_all_primary = bool_sum(x$beats_all_primary_baselines),
    min_forecast_mae_ratio = safe_min(x$forecast_mae_ratio_vs_best_vb_baseline),
    min_forecast_check_ratio = safe_min(x$forecast_pinball_ratio_vs_best_vb_baseline),
    min_fit_rmse_ratio = safe_min(x$fit_rmse_ratio_vs_best_vb_baseline),
    min_fit_check_ratio = safe_min(x$fit_pinball_ratio_vs_best_vb_baseline),
    mean_runtime_sec = safe_mean(x$qdesn_runtime_sec_mean),
    dominance_cell_path = normalizePath(path, winslash = "/", mustWork = TRUE),
    is_current_rescue_v2 = grepl("rhs_fitrmse_rescue_v2", path, fixed = TRUE),
    is_recent_rhs_line = grepl("tt500_vb_rhs", path, fixed = TRUE),
    stringsAsFactors = FALSE
  )
}

best_rows_for_file <- function(path) {
  x <- utils::read.csv(path, check.names = FALSE)
  parts <- screen_parts(path)
  needed <- c(
    "forecast_mae_ratio_vs_best_vb_baseline",
    "forecast_pinball_ratio_vs_best_vb_baseline",
    "fit_rmse_ratio_vs_best_vb_baseline",
    "fit_pinball_ratio_vs_best_vb_baseline"
  )
  for (nm in needed) {
    if (!nm %in% names(x)) x[[nm]] <- NA_real_
    x[[nm]] <- suppressWarnings(as.numeric(x[[nm]]))
  }
  x$max_primary_ratio <- do.call(pmax, c(x[needed], list(na.rm = TRUE)))
  x$dominance_cell_path <- normalizePath(path, winslash = "/", mustWork = TRUE)
  x$stage <- parts$stage
  x$run_tag <- parts$run_tag
  x$run_stamp <- parts$run_stamp
  split_key <- paste(x$family, x$tau, sep = "|")
  idx <- unlist(lapply(split(seq_len(nrow(x)), split_key), function(ii) {
    ii[order(x$max_primary_ratio[ii], x$fit_rmse_ratio_vs_best_vb_baseline[ii], x$forecast_mae_ratio_vs_best_vb_baseline[ii])][1L]
  }), use.names = FALSE)
  keep <- c(
    "stage", "run_tag", "run_stamp", "family", "tau",
    "screening_profile_base", "profile_role",
    "forecast_mae_ratio_vs_best_vb_baseline",
    "forecast_pinball_ratio_vs_best_vb_baseline",
    "fit_rmse_ratio_vs_best_vb_baseline",
    "fit_pinball_ratio_vs_best_vb_baseline",
    "beats_all_primary_baselines",
    "qdesn_runtime_sec_mean", "qdesn_p_over_n_mean",
    "max_primary_ratio", "dominance_cell_path"
  )
  keep <- keep[keep %in% names(x)]
  x[idx, keep, drop = FALSE]
}

out_dir <- resolve_path(get_arg("--out-dir", "validation/fitforecast_v2/docs"), must_work = FALSE)
current_report_root <- resolve_path(get_arg(
  "--current-report-root",
  "reports/qdesn_mcmc_validation/qdesn_dynamic_fitforecast_v2_tt500_vb_rhs_fitrmse_rescue_v2/qdesn-vb-rhs-fitrmse-rescue-v2-full-20260708__git-436d44d/20260708-205541__git-436d44d"
), must_work = TRUE)
article_root <- resolve_path(get_arg("--article-root", "/data/jaguir26/local/src/Article-Q-DESN---Version-2"), must_work = FALSE)

files <- list.files(
  file.path(repo_root, "reports", "qdesn_mcmc_validation"),
  pattern = "qdesn_tt500_vb_dominance_cell_summary[.]csv$",
  recursive = TRUE,
  full.names = TRUE
)
if (!length(files)) stop("No dominance cell summary files found.", call. = FALSE)

summary <- do.call(rbind, lapply(files, summarize_dominance_file))
summary <- summary[order(summary$modified_time, summary$stage, summary$run_tag), ]

best_by_file <- do.call(rbind, lapply(files, best_rows_for_file))
best_by_file <- best_by_file[order(best_by_file$max_primary_ratio), ]

current_cell_path <- file.path(current_report_root, "tables", "qdesn_tt500_vb_dominance_cell_summary.csv")
current_profile_path <- file.path(current_report_root, "tables", "qdesn_tt500_vb_dominance_profile_ranking.csv")
current_audit_path <- file.path(current_report_root, "audit", "tables", "qdesn_tt500_vb_screen_audit_summary.csv")
current_cell <- utils::read.csv(current_cell_path, check.names = FALSE)
current_profile <- utils::read.csv(current_profile_path, check.names = FALSE)
current_audit <- utils::read.csv(current_audit_path, check.names = FALSE)

current_cell$max_primary_ratio <- do.call(pmax, c(current_cell[c(
  "forecast_mae_ratio_vs_best_vb_baseline",
  "forecast_pinball_ratio_vs_best_vb_baseline",
  "fit_rmse_ratio_vs_best_vb_baseline",
  "fit_pinball_ratio_vs_best_vb_baseline"
)], list(na.rm = TRUE)))
current_best_by_cell <- do.call(rbind, lapply(
  split(seq_len(nrow(current_cell)), paste(current_cell$family, current_cell$tau, sep = "|")),
  function(ii) current_cell[ii[order(current_cell$max_primary_ratio[ii])][1L], , drop = FALSE]
))
current_best_by_cell <- current_best_by_cell[order(current_best_by_cell$family, current_best_by_cell$tau), ]

history_csv <- write_csv(summary, file.path(out_dir, "qdesn_tt500_vb_screen_history_audit_20260708.csv"))
best_csv <- write_csv(best_by_file, file.path(out_dir, "qdesn_tt500_vb_screen_history_best_cells_20260708.csv"))
current_best_csv <- write_csv(current_best_by_cell, file.path(out_dir, "qdesn_tt500_vb_rhs_fitrmse_rescue_v2_best_cells_20260708.csv"))

current_summary <- summary[summary$is_current_rescue_v2, , drop = FALSE]
if (nrow(current_summary) != 1L) {
  current_summary <- summarize_dominance_file(current_cell_path)
}

old_success <- summary[summary$beat_all_primary > 0 & !summary$is_recent_rhs_line, , drop = FALSE]
recent_rhs <- summary[summary$is_recent_rhs_line, , drop = FALSE]

article_status <- git_value(article_root, "status", "-sb")
article_head <- git_value(article_root, "rev-parse", "HEAD")
article_origin <- git_value(article_root, "rev-parse", "origin/main")
article_remote <- git_value(article_root, "remote", "get-url", "origin")

fmt_num <- function(x, digits = 3) {
  ifelse(is.na(x), "NA", formatC(as.numeric(x), format = "f", digits = digits))
}

lines <- c(
  "# Q-DESN 500-Observation VB Screen History Audit and Rescue-v2 Closeout",
  "",
  "## Decision",
  "",
  "Close `qdesn-vb-rhs-fitrmse-rescue-v2-full-20260708__git-436d44d` as a technically successful diagnostic screen, but do not promote its candidates to MCMC and do not update article tables from this run.",
  "",
  "The screen completed cleanly and is reproducible. Scientifically, it did not solve the remaining Q-DESN RHS bottleneck: no candidate-cell row beat the DQLM/exDQLM VB baseline on fit RMSE, and no profile passed all primary dominance criteria.",
  "",
  "## Current Rescue-v2 Evidence",
  "",
  sprintf("- Report root: `%s`", normalizePath(current_report_root, winslash = "/", mustWork = TRUE)),
  sprintf("- Dominance cells: `%s`", normalizePath(current_cell_path, winslash = "/", mustWork = TRUE)),
  sprintf("- Profile ranking: `%s`", normalizePath(current_profile_path, winslash = "/", mustWork = TRUE)),
  sprintf("- Strict audit: `%s`", normalizePath(current_audit_path, winslash = "/", mustWork = TRUE)),
  sprintf("- Expected roots: `%s`", current_audit$expected_roots[[1L]]),
  sprintf("- Observed roots: `%s`", current_audit$observed_roots[[1L]]),
  sprintf("- Success roots: `%s`", current_audit$n_success[[1L]]),
  sprintf("- Failed roots: `%s`", current_audit$n_fail[[1L]]),
  sprintf("- Strict ready: `%s`", current_audit$strict_ready[[1L]]),
  sprintf("- Forbidden final binary payloads: `%s` files / `%s` bytes", current_audit$forbidden_binary_count_total[[1L]], current_audit$forbidden_binary_bytes_total[[1L]]),
  "",
  "## Rescue-v2 Dominance Counts",
  "",
  "| Criterion | Count |",
  "|---|---:|",
  sprintf("| Candidate-cell rows | %d |", nrow(current_cell)),
  sprintf("| Profiles ranked | %d |", nrow(current_profile)),
  sprintf("| Profiles with dominance_pass | %d |", bool_sum(current_profile$dominance_pass)),
  sprintf("| Beat forecast MAE baseline | %d |", bool_sum(current_cell$beats_forecast_mae_baseline)),
  sprintf("| Beat forecast check-loss baseline | %d |", bool_sum(current_cell$beats_forecast_pinball_baseline)),
  sprintf("| Beat fit RMSE baseline | %d |", bool_sum(current_cell$beats_fit_rmse_baseline)),
  sprintf("| Beat fit check-loss baseline | %d |", bool_sum(current_cell$beats_fit_pinball_baseline)),
  sprintf("| Beat all primary baselines | %d |", bool_sum(current_cell$beats_all_primary_baselines)),
  "",
  "## Best Rescue-v2 Cell Rows",
  "",
  "| Family | Tau | Best profile | Forecast MAE ratio | Forecast check ratio | Fit RMSE ratio | Fit check ratio | Max ratio |",
  "|---|---:|---|---:|---:|---:|---:|---:|"
)

for (i in seq_len(nrow(current_best_by_cell))) {
  r <- current_best_by_cell[i, ]
  lines <- c(lines, sprintf(
    "| %s | %.2f | `%s` | %s | %s | %s | %s | %s |",
    as.character(r$family), as.numeric(r$tau), as.character(r$screening_profile_base),
    fmt_num(r$forecast_mae_ratio_vs_best_vb_baseline),
    fmt_num(r$forecast_pinball_ratio_vs_best_vb_baseline),
    fmt_num(r$fit_rmse_ratio_vs_best_vb_baseline),
    fmt_num(r$fit_pinball_ratio_vs_best_vb_baseline),
    fmt_num(r$max_primary_ratio)
  ))
}

lines <- c(
  lines,
  "",
  "## Historical Screen Diagnosis",
  "",
  "The full history separates into two regimes:",
  "",
  "- Older broad/non-current screens contain some candidate-cell rows that beat all four baseline criteria. These screens used wider search surfaces and some cells reached strong dominance, but they are not the current RHS rescue line and should not be blindly promoted without a fresh protocol-specific handoff.",
  "- The recent RHS-focused line from July 4 onward is technically clean but has not produced a fit-RMSE win against the DQLM/exDQLM VB baseline. Rescue-v2 is the cleanest evidence for that failure mode.",
  "",
  "### Recent RHS-Line Summary",
  "",
  "| Stage | Run tag | Cells | Beat all | Beat fit RMSE | Min fit RMSE ratio | Min forecast MAE ratio |",
  "|---|---|---:|---:|---:|---:|---:|"
)

recent_rhs_show <- recent_rhs[order(recent_rhs$modified_time), ]
for (i in seq_len(nrow(recent_rhs_show))) {
  r <- recent_rhs_show[i, ]
  lines <- c(lines, sprintf(
    "| `%s` | `%s` | %d | %d | %d | %s | %s |",
    r$stage, r$run_tag, as.integer(r$n_cell_rows), as.integer(r$beat_all_primary),
    as.integer(r$beat_fit_rmse), fmt_num(r$min_fit_rmse_ratio), fmt_num(r$min_forecast_mae_ratio)
  ))
}

lines <- c(
  lines,
  "",
  "### Older Broad Screens With All-Criterion Wins",
  "",
  "| Stage | Run tag | Cells | Beat all | Min fit RMSE ratio | Min forecast MAE ratio |",
  "|---|---|---:|---:|---:|---:|"
)

old_show <- old_success[order(old_success$modified_time), ]
if (!nrow(old_show)) {
  lines <- c(lines, "| None | None | 0 | 0 | NA | NA |")
} else {
  for (i in seq_len(nrow(old_show))) {
    r <- old_show[i, ]
    lines <- c(lines, sprintf(
      "| `%s` | `%s` | %d | %d | %s | %s |",
      r$stage, r$run_tag, as.integer(r$n_cell_rows), as.integer(r$beat_all_primary),
      fmt_num(r$min_fit_rmse_ratio), fmt_num(r$min_forecast_mae_ratio)
    ))
  }
}

lines <- c(
  lines,
  "",
  "## Article Integration Decision",
  "",
  "Do not update the Article-Q-DESN Version-2 tables from rescue-v2. The authoritative article table bundle already points to pinned final TT500 validation assets, and rescue-v2 does not dominate those assets or the DQLM/exDQLM VB baseline.",
  "",
  sprintf("- Article root audited: `%s`", normalizePath(article_root, winslash = "/", mustWork = dir.exists(article_root))),
  sprintf("- Article remote: `%s`", article_remote),
  sprintf("- Article HEAD: `%s`", article_head),
  sprintf("- Article origin/main: `%s`", article_origin),
  sprintf("- Article status: `%s`", gsub("\n", " ; ", article_status)),
  "",
  "## Recommended Next Calibration Plan",
  "",
  "1. Treat rescue-v2 as closed evidence, not as a launch queue.",
  "2. Do not run MCMC from rescue-v2 candidates.",
  "3. Mine the older broad screens with all-criterion wins to recover their exact cell-level designs, but require a new protocol-specific handoff before promotion.",
  "4. If another Q-DESN RHS calibration is desired, build a small targeted VB handoff around the older all-criterion cells, constrained to the current frozen registry, rolling-origin contract, storage-light policy, and current article-facing metrics.",
  "5. Promote to MCMC only after a fresh VB handoff produces at least one candidate per target cell that clears fit RMSE, fit check loss, forecast MAE, and forecast check loss against the frozen DQLM/exDQLM VB baseline.",
  "",
  "## Generated Artifacts",
  "",
  sprintf("- History audit CSV: `%s`", history_csv),
  sprintf("- Historical best-cell CSV: `%s`", best_csv),
  sprintf("- Rescue-v2 best-cell CSV: `%s`", current_best_csv),
  "",
  "## Reproduction Command",
  "",
  "```bash",
  "Rscript scripts/audit_qdesn_tt500_vb_screen_history.R \\",
  "  --current-report-root reports/qdesn_mcmc_validation/qdesn_dynamic_fitforecast_v2_tt500_vb_rhs_fitrmse_rescue_v2/qdesn-vb-rhs-fitrmse-rescue-v2-full-20260708__git-436d44d/20260708-205541__git-436d44d \\",
  "  --article-root /data/jaguir26/local/src/Article-Q-DESN---Version-2 \\",
  "  --out-dir validation/fitforecast_v2/docs",
  "```"
)

closeout_path <- file.path(out_dir, "QDESN_500OBS_VB_RHS_FITRMSE_RESCUE_V2_CLOSEOUT_AND_NEXT_PLAN_2026-07-08.md")
writeLines(lines, closeout_path, useBytes = TRUE)
closeout_path <- normalizePath(closeout_path, winslash = "/", mustWork = TRUE)

cat(sprintf("history_csv: %s\n", history_csv))
cat(sprintf("best_cells_csv: %s\n", best_csv))
cat(sprintf("current_best_cells_csv: %s\n", current_best_csv))
cat(sprintf("closeout_md: %s\n", closeout_path))
cat(sprintf("current_rescue_v2 beat_all=%d beat_fit_rmse=%d strict_ready=%s\n",
            bool_sum(current_cell$beats_all_primary_baselines),
            bool_sum(current_cell$beats_fit_rmse_baseline),
            as.character(current_audit$strict_ready[[1L]])))

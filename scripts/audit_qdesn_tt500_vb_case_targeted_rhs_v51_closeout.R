#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
get_arg <- function(flag, default = NULL) {
  idx <- which(args == flag)
  if (!length(idx) || idx[[1L]] >= length(args)) return(default)
  args[[idx[[1L]] + 1L]]
}
`%||%` <- function(a, b) if (is.null(a) || !length(a)) b else a

repo_root <- normalizePath(system("git rev-parse --show-toplevel", intern = TRUE), winslash = "/", mustWork = TRUE)
setwd(repo_root)

resolve_path <- function(path, must_work = TRUE) {
  raw <- as.character(path %||% "")[1L]
  if (!nzchar(raw)) return(NULL)
  if (!grepl("^(/|~)", raw)) raw <- file.path(repo_root, raw)
  normalizePath(raw, winslash = "/", mustWork = isTRUE(must_work))
}
read_csv <- function(path) utils::read.csv(resolve_path(path), check.names = FALSE, stringsAsFactors = FALSE)
write_csv <- function(x, path) {
  path <- resolve_path(path, must_work = FALSE)
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(x, path, row.names = FALSE, na = "")
  path
}
fmt <- function(x, digits = 4) {
  x <- suppressWarnings(as.numeric(x))
  ifelse(is.finite(x), formatC(x, digits = digits, format = "fg", flag = "#"), "NA")
}
md_table <- function(x, cols = names(x), max_rows = Inf) {
  cols <- intersect(cols, names(x))
  if (!length(cols) || !nrow(x)) return(c("| none |", "|---|"))
  y <- utils::head(x[, cols, drop = FALSE], max_rows)
  out <- c(
    paste("|", paste(cols, collapse = " | "), "|"),
    paste("|", paste(rep("---", length(cols)), collapse = " | "), "|")
  )
  for (i in seq_len(nrow(y))) {
    vals <- vapply(y[i, , drop = FALSE], function(z) {
      if (is.numeric(z)) fmt(z, 5) else {
        zz <- as.character(z)
        zz[is.na(zz)] <- "NA"
        zz
      }
    }, character(1))
    out <- c(out, paste("|", paste(vals, collapse = " | "), "|"))
  }
  out
}

default_report_root <- file.path(
  "reports", "qdesn_mcmc_validation",
  "qdesn_dynamic_fitforecast_v2_tt500_vb_case_targeted_rhs_v51",
  "qdesn-vb-case-targeted-rhs-v51-full-20260713__git-a2f11f8",
  "20260713-002045__git-a2f11f8"
)
report_root <- resolve_path(get_arg("--report-root", default_report_root))
out_root <- resolve_path(get_arg(
  "--out-root",
  file.path(report_root, "posthoc_v51_closeout")
), must_work = FALSE)
doc_out <- resolve_path(get_arg(
  "--doc-out",
  "validation/fitforecast_v2/docs/QDESN_500OBS_VB_CASE_TARGETED_RHS_V51_CLOSEOUT_2026-07-13.md"
), must_work = FALSE)

audit <- read_csv(file.path(report_root, "audit", "tables", "qdesn_tt500_vb_screen_audit_summary.csv"))
cell <- read_csv(file.path(report_root, "tables", "qdesn_tt500_vb_dominance_cell_summary.csv"))
fit <- read_csv(file.path(report_root, "tables", "qdesn_tt500_vb_screen_fit_forecast_summary.csv"))
campaign_fit <- read_csv(file.path(report_root, "tables", "campaign_fit_summary.csv"))
ranking <- read_csv(file.path(report_root, "tables", "qdesn_tt500_vb_dominance_profile_ranking.csv"))

ratio_cols <- c(
  forecast_mae = "forecast_mae_ratio_vs_best_vb_baseline",
  forecast_check = "forecast_pinball_ratio_vs_best_vb_baseline",
  fit_rmse = "fit_rmse_ratio_vs_best_vb_baseline",
  fit_check = "fit_pinball_ratio_vs_best_vb_baseline"
)
for (nm in ratio_cols) cell[[nm]] <- suppressWarnings(as.numeric(cell[[nm]]))
cell$primary_worst_ratio <- do.call(pmax, c(cell[ratio_cols], list(na.rm = TRUE)))
cell$key <- paste(cell$family, sprintf("%.8f", as.numeric(cell$tau)), sep = "\r")

cell_rows <- lapply(split(seq_len(nrow(cell)), cell$key), function(idx) {
  sub <- cell[idx, , drop = FALSE]
  best <- sub[order(sub$primary_worst_ratio, sub$screening_profile_base), , drop = FALSE][1L, , drop = FALSE]
  metric_min <- vapply(ratio_cols, function(col) min(suppressWarnings(as.numeric(sub[[col]])), na.rm = TRUE), numeric(1))
  best_ratios <- vapply(ratio_cols, function(col) suppressWarnings(as.numeric(best[[col]][[1L]])), numeric(1))
  metricwise_blockers <- names(metric_min)[metric_min >= 1]
  joint_blockers <- names(best_ratios)[best_ratios >= 1]
  feasibility <- if (all(metric_min < 1)) {
    if (max(best_ratios) <= 1.05) "metricwise_feasible_joint_near"
    else "metricwise_feasible_joint_gap"
  } else if (any(metric_min >= 1.25)) {
    "metricwise_hard_infeasible_current_rhs"
  } else {
    "metricwise_near_infeasible_current_rhs"
  }
  data.frame(
    family = as.character(best$family[[1L]]),
    tau = as.numeric(best$tau[[1L]]),
    n_successful_profiles = nrow(sub),
    best_joint_profile = as.character(best$screening_profile_base[[1L]]),
    best_joint_worst_ratio = max(best_ratios, na.rm = TRUE),
    best_joint_blockers = if (length(joint_blockers)) paste(joint_blockers, collapse = ";") else "none",
    min_forecast_mae_ratio = metric_min[["forecast_mae"]],
    min_forecast_check_ratio = metric_min[["forecast_check"]],
    min_fit_rmse_ratio = metric_min[["fit_rmse"]],
    min_fit_check_ratio = metric_min[["fit_check"]],
    metricwise_blockers = if (length(metricwise_blockers)) paste(metricwise_blockers, collapse = ";") else "none",
    feasibility_class = feasibility,
    mcmc_promotion_decision = "do_not_promote",
    next_screen_recommendation = if (grepl("joint_near", feasibility)) {
      "small_bridge_only"
    } else if (grepl("joint_gap", feasibility)) {
      "bridge_or_alternative_objective"
    } else if (grepl("near_infeasible", feasibility)) {
      "only_if_new_design_axis_targets_metricwise_blocker"
    } else {
      "stop_rhs_local_retuning_change_design_family"
    },
    stringsAsFactors = FALSE
  )
})
cell_closeout <- do.call(rbind, cell_rows)
cell_closeout <- cell_closeout[order(cell_closeout$family, cell_closeout$tau), , drop = FALSE]

campaign_fit$status <- toupper(as.character(campaign_fit$status))
failed <- campaign_fit[campaign_fit$status != "SUCCESS", , drop = FALSE]
failed <- failed[, intersect(c(
  "root_id", "family", "tau", "likelihood_family", "screening_profile_id",
  "profile_role", "rhs_tau0", "status", "signoff_reason"
), names(failed)), drop = FALSE]

dominance_passes <- if ("dominance_pass" %in% names(ranking)) {
  sum(tolower(as.character(ranking$dominance_pass)) %in% c("true", "1", "t", "yes"), na.rm = TRUE)
} else {
  NA_integer_
}

dir.create(out_root, recursive = TRUE, showWarnings = FALSE)
cell_path <- write_csv(cell_closeout, file.path(out_root, "tables", "qdesn_tt500_vb_rhs_v51_cell_feasibility_closeout.csv"))
fail_path <- write_csv(failed, file.path(out_root, "tables", "qdesn_tt500_vb_rhs_v51_failed_candidates.csv"))

heavy_cmd <- sprintf(
  "find %s -type f \\( -name '*.rds' -o -name '*.rda' -o -name '*.RData' \\) -printf '%%p\\t%%s\\n'",
  shQuote(resolve_path(file.path(dirname(dirname(report_root)), "..", ".."), must_work = FALSE))
)
heavy <- tryCatch(system(heavy_cmd, intern = TRUE), error = function(...) character(0))
heavy_n <- length(heavy)
heavy_bytes <- if (heavy_n) sum(suppressWarnings(as.numeric(sub("^.*\\t", "", heavy))), na.rm = TRUE) else 0

summary_df <- data.frame(
  report_root = report_root,
  expected_roots = as.integer(audit$expected_roots[[1L]] %||% NA_integer_),
  observed_roots = as.integer(audit$observed_roots[[1L]] %||% NA_integer_),
  n_success = as.integer(audit$n_success[[1L]] %||% NA_integer_),
  n_fail = as.integer(audit$n_fail[[1L]] %||% NA_integer_),
  strict_ready = as.character(audit$strict_ready[[1L]] %||% NA_character_),
  success_contract_pass = as.character(audit$success_contract_pass[[1L]] %||% NA_character_),
  ranking_contract_pass = as.character(audit$ranking_contract_pass[[1L]] %||% NA_character_),
  dominance_passes = as.integer(dominance_passes),
  cells_metricwise_feasible = sum(grepl("^metricwise_feasible", cell_closeout$feasibility_class)),
  cells_joint_near = sum(cell_closeout$feasibility_class == "metricwise_feasible_joint_near"),
  cells_current_rhs_metricwise_infeasible = sum(grepl("infeasible", cell_closeout$feasibility_class)),
  forbidden_heavy_file_count = as.integer(heavy_n),
  forbidden_heavy_bytes = as.numeric(heavy_bytes),
  mcmc_promotion_decision = "blocked",
  stringsAsFactors = FALSE
)
summary_path <- write_csv(summary_df, file.path(out_root, "tables", "qdesn_tt500_vb_rhs_v51_closeout_summary.csv"))

lines <- c(
  "# Q-DESN RHS VB v5.1 Closeout",
  "",
  sprintf("- generated_at: `%s`", as.character(Sys.time())),
  sprintf("- report_root: `%s`", report_root),
  sprintf("- summary_csv: `%s`", summary_path),
  sprintf("- cell_feasibility_csv: `%s`", cell_path),
  sprintf("- failed_candidates_csv: `%s`", fail_path),
  "",
  "## Health",
  "",
  md_table(summary_df, c(
    "expected_roots", "observed_roots", "n_success", "n_fail", "strict_ready",
    "success_contract_pass", "ranking_contract_pass", "dominance_passes",
    "forbidden_heavy_file_count"
  )),
  "",
  "## Decision",
  "",
  "- v5.1 is mechanically closed out and strict-ready under the screening contract because failed exploratory candidates were allowed.",
  "- v5.1 has zero all-primary dominance winners and is not MCMC-promotable.",
  "- The failures are confined to three gausmix tau=0.05 candidate roots, yielding six failed VB fit rows across AL and exAL, all on the same tiny RHS tau0 surface; the current code path now preserves 3e-05 and explicitly rejects nonpositive tau0 before compute.",
  "- Article-facing tables should not be updated from v5.1 as improved evidence; it is diagnostic/negative calibration evidence.",
  "",
  "## Cell Feasibility",
  "",
  md_table(cell_closeout, c(
    "family", "tau", "best_joint_worst_ratio", "best_joint_blockers",
    "min_forecast_mae_ratio", "min_forecast_check_ratio",
    "min_fit_rmse_ratio", "min_fit_check_ratio",
    "metricwise_blockers", "feasibility_class", "next_screen_recommendation"
  )),
  "",
  "## Better Plan",
  "",
  "1. Freeze v5.1 as negative diagnostic evidence; do not promote any v5.1 row to MCMC.",
  "2. Keep the new tau0 precision guards in the dynamic grid, root-spec, and static fit-request path.",
  "3. For metricwise-feasible cells, run only small bridge screens that combine the best metric-specific profiles; do not broaden all axes at once.",
  "4. For metricwise-infeasible cells, stop local RHS-only retuning unless the next design introduces a new axis that targets the actual blocker.",
  "5. Require a fresh strict-audited all-primary VB dominance winner before MCMC promotion.",
  "6. Keep storage-light policy unchanged: metrics, compact paths, manifests, logs, and status only; no routine successful R payload retention.",
  "",
  "## Failed Candidate Rows",
  "",
  md_table(failed, names(failed), max_rows = 12)
)

summary_md <- file.path(out_root, "summary", "qdesn_tt500_vb_rhs_v51_closeout.md")
dir.create(dirname(summary_md), recursive = TRUE, showWarnings = FALSE)
writeLines(lines, summary_md, useBytes = TRUE)
dir.create(dirname(doc_out), recursive = TRUE, showWarnings = FALSE)
writeLines(lines, doc_out, useBytes = TRUE)

cat(sprintf("summary: %s\n", summary_md))
cat(sprintf("doc: %s\n", doc_out))
cat(sprintf("summary_csv: %s\n", summary_path))
cat(sprintf("cell_feasibility_csv: %s\n", cell_path))
cat(sprintf("failed_candidates_csv: %s\n", fail_path))

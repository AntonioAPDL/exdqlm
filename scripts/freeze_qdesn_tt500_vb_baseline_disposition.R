#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  req <- c("jsonlite")
  missing <- setdiff(req, rownames(installed.packages()))
  if (length(missing)) {
    stop(sprintf("Missing required package(s): %s", paste(missing, collapse = ", ")), call. = FALSE)
  }
  invisible(lapply(req, require, character.only = TRUE))
})

`%||%` <- function(a, b) if (is.null(a) || length(a) == 0L) b else a

repo_root <- normalizePath(system("git rev-parse --show-toplevel", intern = TRUE), winslash = "/", mustWork = TRUE)
setwd(repo_root)

resolve_path <- function(path, must_work = TRUE) {
  raw <- as.character(path %||% "")[1L]
  if (!nzchar(trimws(raw))) return(NULL)
  if (!grepl("^(/|~)", raw)) raw <- file.path(repo_root, raw)
  normalizePath(raw, winslash = "/", mustWork = isTRUE(must_work))
}

resolve_paths <- function(paths, must_work = TRUE) {
  vapply(paths, resolve_path, character(1L), must_work = must_work, USE.NAMES = FALSE)
}

read_csv <- function(path) utils::read.csv(resolve_path(path), stringsAsFactors = FALSE, check.names = FALSE)

write_csv <- function(x, path) {
  path <- resolve_path(path, must_work = FALSE)
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(x, path, row.names = FALSE, na = "")
  normalizePath(path, winslash = "/", mustWork = TRUE)
}

write_json <- function(x, path) {
  path <- resolve_path(path, must_work = FALSE)
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  jsonlite::write_json(x, path, pretty = TRUE, auto_unbox = TRUE, null = "null")
  normalizePath(path, winslash = "/", mustWork = TRUE)
}

sha256_file <- function(path) unname(tools::sha256sum(resolve_path(path)))

num <- function(x) suppressWarnings(as.numeric(x))

md_table <- function(df, cols = names(df), max_rows = Inf) {
  if (!nrow(df)) return("_No rows._")
  cols <- intersect(cols, names(df))
  x <- df[, cols, drop = FALSE]
  if (is.finite(max_rows) && nrow(x) > max_rows) x <- utils::head(x, max_rows)
  x[] <- lapply(x, function(col) {
    if (is.numeric(col)) {
      ifelse(is.na(col), "", format(round(col, 4), trim = TRUE, scientific = FALSE))
    } else {
      val <- as.character(col)
      val[is.na(val)] <- ""
      val
    }
  })
  header <- paste0("| ", paste(cols, collapse = " | "), " |")
  sep <- paste0("|", paste(rep("---", length(cols)), collapse = "|"), "|")
  rows <- apply(x, 1L, function(r) paste0("| ", paste(r, collapse = " | "), " |"))
  paste(c(header, sep, rows), collapse = "\n")
}

paths <- list(
  qvbm1_health = "reports/qvbm1/audit/closeout/qvbm1_decomp_guardfix_20260713_main__git-8c6eda9/tables/qvbm1_mechanism_first_health.csv",
  qvbm1_winners = "reports/qvbm1/audit/closeout/qvbm1_decomp_guardfix_20260713_main__git-8c6eda9/tables/qvbm1_mechanism_first_cell_winners.csv",
  qvbm1_comparison = "reports/qvbm1/audit/closeout/qvbm1_decomp_guardfix_20260713_main__git-8c6eda9/tables/qvbm1_mechanism_first_current_table_comparison.csv",
  qvbm1_blockers = "reports/qvbm1/audit/closeout/qvbm1_decomp_guardfix_20260713_main__git-8c6eda9/tables/qvbm1_mechanism_first_ratio_blockers.csv",
  qvbm1_manifest = "reports/qvbm1/audit/closeout/qvbm1_decomp_guardfix_20260713_main__git-8c6eda9/manifest/qvbm1_mechanism_first_closeout_manifest.json",
  qvbm2_health = "reports/qvbm2/audit/closeout/qvbm2_blocker_aware_20260714__git-33f8a87/tables/qvbm2_health.csv",
  qvbm2_ratios = "reports/qvbm2/audit/closeout/qvbm2_blocker_aware_20260714__git-33f8a87/tables/qvbm2_ratio_breakdown.csv",
  qvbm2_failures = "reports/qvbm2/audit/closeout/qvbm2_blocker_aware_20260714__git-33f8a87/tables/qvbm2_invalid_failure_ledger.csv",
  qvbm2_manifest = "reports/qvbm2/audit/closeout/qvbm2_blocker_aware_20260714__git-33f8a87/manifest/qvbm2_closeout_manifest.json",
  qvbm2p3_health = "reports/qvbm2p3/audit/closeout/qvbm2p3_safe_floor_20260715/tables/qvbm2_health.csv",
  qvbm2p3_ratios = "reports/qvbm2p3/audit/closeout/qvbm2p3_safe_floor_20260715/tables/qvbm2_ratio_breakdown.csv",
  qvbm2p3_manifest = "reports/qvbm2p3/audit/closeout/qvbm2p3_safe_floor_20260715/manifest/qvbm2_closeout_manifest.json"
)

for (nm in names(paths)) {
  if (!file.exists(resolve_path(paths[[nm]], must_work = FALSE))) {
    stop(sprintf("Required evidence path is missing: %s = %s", nm, paths[[nm]]), call. = FALSE)
  }
}

qvbm1_health <- read_csv(paths$qvbm1_health)
qvbm1_winners <- read_csv(paths$qvbm1_winners)
qvbm1_comparison <- read_csv(paths$qvbm1_comparison)
qvbm1_blockers <- read_csv(paths$qvbm1_blockers)
qvbm2_health <- read_csv(paths$qvbm2_health)
qvbm2_ratios <- read_csv(paths$qvbm2_ratios)
qvbm2_failures <- read_csv(paths$qvbm2_failures)
qvbm2p3_health <- read_csv(paths$qvbm2p3_health)
qvbm2p3_ratios <- read_csv(paths$qvbm2p3_ratios)

qvbm1_expected <- sum(num(qvbm1_health$expected_fit_roots), na.rm = TRUE)
qvbm1_success <- sum(num(qvbm1_health$n_success), na.rm = TRUE)
qvbm1_leads <- sum(num(qvbm1_health$forecast_lead_rows), na.rm = TRUE)
qvbm1_expected_leads <- sum(num(qvbm1_health$expected_forecast_lead_rows), na.rm = TRUE)
qvbm1_complete <- identical(as.integer(qvbm1_success), as.integer(qvbm1_expected)) &&
  identical(as.integer(qvbm1_leads), as.integer(qvbm1_expected_leads))
qvbm1_mcmc_promote <- sum(as.character(qvbm1_comparison$mcmc_handoff_status) == "PROMOTE_TO_MCMC_AFTER_REVIEW", na.rm = TRUE)

qvbm2_planned <- sum(num(qvbm2_health$planned_roots), na.rm = TRUE)
qvbm2_success <- sum(num(qvbm2_health$SUCCESS), na.rm = TRUE)
qvbm2_fail <- sum(num(qvbm2_health$FAIL), na.rm = TRUE)
qvbm2_remaining <- sum(num(qvbm2_health$remaining_roots), na.rm = TRUE)
qvbm2_promote_qvbm1 <- sum(tolower(as.character(qvbm2_ratios$beats_qvbm1_all4)) == "true", na.rm = TRUE)
qvbm2_promote_exdqlm <- sum(tolower(as.character(qvbm2_ratios$beats_exdqlm_all4)) == "true", na.rm = TRUE)
qvbm2_invalid_p03_only <- nrow(qvbm2_failures) == qvbm2_fail &&
  qvbm2_fail > 0 &&
  all(as.character(qvbm2_failures$failure_class) == "invalid_rhs_tau0_tiny_surface") &&
  all(as.character(qvbm2_failures$consume_policy) == "refuse")

qvbm2p3_planned <- sum(num(qvbm2p3_health$planned_roots), na.rm = TRUE)
qvbm2p3_success <- sum(num(qvbm2p3_health$SUCCESS), na.rm = TRUE)
qvbm2p3_fail <- sum(num(qvbm2p3_health$FAIL), na.rm = TRUE)
qvbm2p3_remaining <- sum(num(qvbm2p3_health$remaining_roots), na.rm = TRUE)
qvbm2p3_promote_qvbm1 <- sum(tolower(as.character(qvbm2p3_ratios$beats_qvbm1_all4)) == "true", na.rm = TRUE)
qvbm2p3_promote_exdqlm <- sum(tolower(as.character(qvbm2p3_ratios$beats_exdqlm_all4)) == "true", na.rm = TRUE)

if (!qvbm1_complete) stop("qvbm1 is not complete; refusing to freeze it as the active VB baseline.", call. = FALSE)
if (qvbm2_remaining != 0) stop("qvbm2 has remaining roots; refusing to classify it as closed.", call. = FALSE)
if (qvbm2p3_remaining != 0) stop("qvbm2p3 has remaining roots; refusing to classify it as closed.", call. = FALSE)

baseline_freeze <- data.frame(
  decision_date = "2026-07-15",
  active_vb_calibration_baseline = "qvbm1",
  baseline_role = "active_qdesn_vb_calibration_reference_not_article_facing",
  baseline_closeout = resolve_path(dirname(dirname(paths$qvbm1_health))),
  baseline_comparison_csv = resolve_path(paths$qvbm1_comparison),
  baseline_winners_csv = resolve_path(paths$qvbm1_winners),
  planned_roots = as.integer(qvbm1_expected),
  success_roots = as.integer(qvbm1_success),
  forecast_lead_rows = as.integer(qvbm1_leads),
  mcmc_promote_after_review_cells = as.integer(qvbm1_mcmc_promote),
  decision = "freeze_as_current_vb_screening_baseline_for_future_design_comparison",
  caveat = "not_promoted_to_mcmc_and_not_article_facing; use as calibration baseline only",
  stringsAsFactors = FALSE
)

screen_disposition <- data.frame(
  screen = c("qvbm1", "qvbm2", "qvbm2p3"),
  status = c("COMPLETE", "COMPLETE_WITH_REFUSED_INVALID_SURFACE", "COMPLETE"),
  role = c("ACTIVE_VB_CALIBRATION_BASELINE", "DIAGNOSTIC_ONLY", "DIAGNOSTIC_ONLY"),
  planned_roots = as.integer(c(qvbm1_expected, qvbm2_planned, qvbm2p3_planned)),
  success_roots = as.integer(c(qvbm1_success, qvbm2_success, qvbm2p3_success)),
  failed_or_refused_roots = as.integer(c(0L, qvbm2_fail, qvbm2p3_fail)),
  remaining_roots = as.integer(c(0L, qvbm2_remaining, qvbm2p3_remaining)),
  beats_qvbm1_all4_cells = as.integer(c(NA, qvbm2_promote_qvbm1, qvbm2p3_promote_qvbm1)),
  beats_exdqlm_dqlm_all4_cells = as.integer(c(NA, qvbm2_promote_exdqlm, qvbm2p3_promote_exdqlm)),
  promotion_policy = c(
    "hold_mcmc; use only as baseline for future VB design comparison",
    "do_not_promote; successful rows do not clear external all-four gate; p03 failures refused",
    "do_not_promote; p03 safe-floor repair succeeded but does not clear qvbm1/exdqlm all-four gates"
  ),
  evidence_manifest = resolve_paths(c(paths$qvbm1_manifest, paths$qvbm2_manifest, paths$qvbm2p3_manifest)),
  stringsAsFactors = FALSE
)

out_dir <- "validation/fitforecast_v2/docs"
baseline_path <- write_csv(baseline_freeze, file.path(out_dir, "qdesn_tt500_vb_active_baseline_freeze_20260715.csv"))
disposition_path <- write_csv(screen_disposition, file.path(out_dir, "qdesn_tt500_vb_screen_disposition_20260715.csv"))

manifest_path <- write_json(
  list(
    generated_at = as.character(Sys.time()),
    repo_root = repo_root,
    git_branch = system("git branch --show-current", intern = TRUE)[[1L]],
    git_sha = system("git rev-parse HEAD", intern = TRUE)[[1L]],
    purpose = "Freeze qvbm1 as the active Q-DESN VB calibration baseline and classify qvbm2/qvbm2p3 as diagnostic-only closed screens.",
    implemented_items = list(
      item_1 = "Use qvbm1 as the current Q-DESN VB baseline for future calibration comparisons.",
      item_2 = "Treat qvbm2 and qvbm2p3 as completed diagnostic screens, not MCMC promotion sources."
    ),
    active_baseline = baseline_freeze,
    screen_disposition = screen_disposition,
    evidence_paths = lapply(paths, resolve_path),
    output_paths = list(
      baseline_freeze_csv = baseline_path,
      screen_disposition_csv = disposition_path
    ),
    hashes = list(
      baseline_freeze_sha256 = sha256_file(baseline_path),
      screen_disposition_sha256 = sha256_file(disposition_path)
    )
  ),
  file.path(out_dir, "qdesn_tt500_vb_baseline_freeze_manifest_20260715.json")
)

doc_path <- resolve_path(file.path(out_dir, "QDESN_500OBS_VB_BASELINE_FREEZE_AND_DIAGNOSTIC_DISPOSITION_2026-07-15.md"), must_work = FALSE)
doc_lines <- c(
  "# Q-DESN 500-Observation VB Baseline Freeze And Diagnostic Disposition",
  "",
  sprintf("- generated_at: `%s`", as.character(Sys.time())),
  sprintf("- worktree: `%s`", repo_root),
  sprintf("- branch: `%s`", system("git branch --show-current", intern = TRUE)[[1L]]),
  sprintf("- head: `%s`", system("git rev-parse HEAD", intern = TRUE)[[1L]]),
  sprintf("- baseline_freeze_csv: `%s`", baseline_path),
  sprintf("- screen_disposition_csv: `%s`", disposition_path),
  sprintf("- manifest: `%s`", manifest_path),
  "",
  "## Scope Implemented",
  "",
  "Only items 1 and 2 from the next-step plan are implemented here.",
  "",
  "1. Freeze `qvbm1` as the active Q-DESN VB calibration baseline for future screen comparisons.",
  "2. Treat `qvbm2` and `qvbm2p3` as completed diagnostic screens, not as MCMC handoff or article-facing sources.",
  "",
  "No broad screen is launched by this artifact. No MCMC handoff is opened by this artifact. No Article-Q-DESN files are modified by this artifact.",
  "",
  "## Audit Diagnosis",
  "",
  sprintf("- `qvbm1` is complete: `%d / %d` successful roots and `%d / %d` forecast lead rows.", as.integer(qvbm1_success), as.integer(qvbm1_expected), as.integer(qvbm1_leads), as.integer(qvbm1_expected_leads)),
  sprintf("- `qvbm1` MCMC promotion cells under the conservative closeout gate: `%d`.", as.integer(qvbm1_mcmc_promote)),
  sprintf("- `qvbm2` is terminal: `%d` successes, `%d` refused failures, `%d` remaining.", as.integer(qvbm2_success), as.integer(qvbm2_fail), as.integer(qvbm2_remaining)),
  sprintf("- `qvbm2` invalid p03-only failure classification: `%s`.", if (isTRUE(qvbm2_invalid_p03_only)) "TRUE" else "FALSE"),
  sprintf("- `qvbm2` cells beating qvbm1 all four metrics: `%d`; cells beating exDQLM/DQLM all four metrics: `%d`.", as.integer(qvbm2_promote_qvbm1), as.integer(qvbm2_promote_exdqlm)),
  sprintf("- `qvbm2p3` is terminal: `%d` successes, `%d` failures, `%d` remaining.", as.integer(qvbm2p3_success), as.integer(qvbm2p3_fail), as.integer(qvbm2p3_remaining)),
  sprintf("- `qvbm2p3` cells beating qvbm1 all four metrics: `%d`; cells beating exDQLM/DQLM all four metrics: `%d`.", as.integer(qvbm2p3_promote_qvbm1), as.integer(qvbm2p3_promote_exdqlm)),
  "",
  "## Baseline Freeze",
  "",
  md_table(baseline_freeze, c("active_vb_calibration_baseline", "baseline_role", "planned_roots", "success_roots", "forecast_lead_rows", "mcmc_promote_after_review_cells", "decision", "caveat")),
  "",
  "## Screen Disposition",
  "",
  md_table(screen_disposition, c("screen", "status", "role", "planned_roots", "success_roots", "failed_or_refused_roots", "remaining_roots", "beats_qvbm1_all4_cells", "beats_exdqlm_dqlm_all4_cells", "promotion_policy")),
  "",
  "## Decision",
  "",
  "`qvbm1` is now the active Q-DESN VB calibration baseline for future design comparison. It is not promoted to MCMC and it is not article-facing.",
  "",
  "`qvbm2` and `qvbm2p3` are closed diagnostic evidence. They should not seed MCMC directly and should not replace qvbm1 in downstream comparison gates.",
  "",
  "## Next Planning Boundary",
  "",
  "The next broad screen should be planned separately. It should compare new per-cell candidates against this frozen qvbm1 baseline and the current exDQLM/DQLM VB baselines, with all-four primary metric gates before any MCMC handoff."
)
writeLines(doc_lines, doc_path, useBytes = TRUE)

cat(sprintf("baseline_freeze_csv: %s\n", baseline_path))
cat(sprintf("screen_disposition_csv: %s\n", disposition_path))
cat(sprintf("manifest: %s\n", manifest_path))
cat(sprintf("doc: %s\n", doc_path))
cat("freeze_decision=PASS\n")

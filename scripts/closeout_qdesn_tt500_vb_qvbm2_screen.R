#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  req <- c("jsonlite")
  missing <- setdiff(req, rownames(installed.packages()))
  if (length(missing)) {
    stop(sprintf("Missing required package(s): %s", paste(missing, collapse = ", ")), call. = FALSE)
  }
  invisible(lapply(req, require, character.only = TRUE))
})

args <- commandArgs(trailingOnly = TRUE)
`%||%` <- function(a, b) if (is.null(a) || length(a) == 0L) b else a

get_arg <- function(flag, default = NULL) {
  idx <- which(args == flag)
  if (!length(idx) || idx[[1L]] >= length(args)) return(default)
  args[[idx[[1L]] + 1L]]
}

repo_root <- normalizePath(system("git rev-parse --show-toplevel", intern = TRUE), winslash = "/", mustWork = TRUE)
setwd(repo_root)

resolve_path <- function(path, must_work = TRUE) {
  raw <- as.character(path %||% "")[1L]
  if (!nzchar(trimws(raw))) return(NULL)
  if (!grepl("^(/|~)", raw)) raw <- file.path(repo_root, raw)
  normalizePath(raw, winslash = "/", mustWork = isTRUE(must_work))
}

write_csv <- function(x, path) {
  path <- resolve_path(path, must_work = FALSE)
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(x, path, row.names = FALSE, na = "")
  normalizePath(path, winslash = "/", mustWork = TRUE)
}

write_lines <- function(x, path) {
  path <- resolve_path(path, must_work = FALSE)
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  writeLines(x, path, useBytes = TRUE)
  normalizePath(path, winslash = "/", mustWork = TRUE)
}

sha256_file <- function(path) {
  path <- resolve_path(path, must_work = TRUE)
  unname(tools::sha256sum(path))
}

git_value <- function(args) {
  out <- tryCatch(system2("git", args, stdout = TRUE, stderr = FALSE), error = function(e) NA_character_)
  if (!length(out)) NA_character_ else out[[1L]]
}

num <- function(x) suppressWarnings(as.numeric(x))

md_table <- function(x, cols = names(x), digits = 4L, max_rows = Inf) {
  if (is.null(x) || !nrow(x)) return(c("| empty |", "|---|", "| no rows |"))
  y <- x[, intersect(cols, names(x)), drop = FALSE]
  if (is.finite(max_rows)) y <- utils::head(y, max_rows)
  for (nm in names(y)) {
    if (is.numeric(y[[nm]])) {
      y[[nm]] <- ifelse(is.na(y[[nm]]), "", format(round(y[[nm]], digits), trim = TRUE, scientific = FALSE))
    }
    y[[nm]] <- gsub("\\|", "/", as.character(y[[nm]]))
    y[[nm]][is.na(y[[nm]])] <- ""
  }
  c(
    paste0("| ", paste(names(y), collapse = " | "), " |"),
    paste0("|", paste(rep("---", ncol(y)), collapse = "|"), "|"),
    apply(y, 1L, function(z) paste0("| ", paste(z, collapse = " | "), " |"))
  )
}

orchestrator_manifest <- resolve_path(get_arg(
  "--orchestrator-manifest",
  "reports/qvbm2/orch/qvbm2_blocker_aware_20260714__git-33f8a87/manifest/mechanism_first_orchestrator_manifest.json"
))
manifest <- jsonlite::read_json(orchestrator_manifest, simplifyVector = TRUE)
stage_label <- as.character(get_arg("--stage-label", basename(dirname(dirname(orchestrator_manifest)))))
default_out <- file.path("reports", "qvbm2", "audit", "closeout", stage_label)
out_dir <- resolve_path(get_arg("--out-dir", default_out), must_work = FALSE)
docs_report <- resolve_path(get_arg(
  "--docs-report",
  "validation/fitforecast_v2/docs/QDESN_500OBS_VB_QVBM2_CLOSEOUT_2026-07-15.md"
), must_work = FALSE)
article_summary <- resolve_path(
  get_arg("--article-summary", "/data/jaguir26/local/src/Article-Q-DESN---Version-2/tables/qdesn_validation_tt500_final_summary.csv"),
  must_work = FALSE
)

bundles <- as.data.frame(manifest$bundles, stringsAsFactors = FALSE)
steps <- as.data.frame(manifest$steps, stringsAsFactors = FALSE)
full_steps <- steps[as.character(steps$mode) == "full", , drop = FALSE]
if (!nrow(full_steps)) stop("No full run steps found in orchestrator manifest.", call. = FALSE)

bundle_meta <- merge(
  bundles,
  full_steps[, intersect(c("bundle_id", "run_tag"), names(full_steps)), drop = FALSE],
  by = "bundle_id",
  all.x = FALSE,
  sort = FALSE
)

read_status <- function(bundle_row) {
  defaults_path <- as.character(bundle_row$defaults_path[[1L]])
  run_tag <- as.character(bundle_row$run_tag[[1L]])
  code <- as.character(bundle_row$bundle_code[[1L]])
  results_root <- file.path("results", sub("^qvbm", "qvbm", strsplit(stage_label, "_")[[1L]][[1L]]), code)
  # Prefer the exact postrun gate root if it exists; otherwise derive from defaults/run tag.
  gate_root <- NA_character_
  step_idx <- which(as.character(steps$bundle_id) == as.character(bundle_row$bundle_id[[1L]]) & as.character(steps$mode) == "full")
  if (length(step_idx)) {
    prg <- steps$postrun_gate[[step_idx[[1L]]]]
    if (is.list(prg) && length(prg$run_root %||% NULL)) gate_root <- as.character(prg$run_root)
  }
  if (is.na(gate_root) || !dir.exists(gate_root)) {
    raw_root <- tryCatch({
      if (requireNamespace("yaml", quietly = TRUE)) {
        y <- yaml::read_yaml(defaults_path)
        resolve_path(file.path(y$campaign$results_root, run_tag), must_work = FALSE)
      } else {
        resolve_path(file.path(results_root, run_tag), must_work = FALSE)
      }
    }, error = function(e) resolve_path(file.path(results_root, run_tag), must_work = FALSE))
    gate_root <- raw_root
  }
  status_files <- list.files(gate_root, pattern = "^root_status[.]txt$", recursive = TRUE, full.names = TRUE)
  rows <- lapply(status_files, function(path) {
    status <- tryCatch(trimws(readLines(path, warn = FALSE)[[1L]]), error = function(e) "UNKNOWN")
    root_dir <- dirname(dirname(path))
    root_id <- basename(root_dir)
    profile <- sub("^.*__profile_", "", root_id)
    log_path <- Sys.glob(file.path(root_dir, "fits", "*", "logs", "pipeline_stdout.log"))[1L] %||% NA_character_
    err <- NA_character_
    if (!is.na(log_path) && file.exists(log_path)) {
      txt <- readLines(log_path, warn = FALSE)
      err_line <- grep("^(Error:|Execution halted|Invalid rhs_tau0)", txt, value = TRUE)
      if (length(err_line)) err <- paste(utils::tail(err_line, 2L), collapse = " | ")
    }
    data.frame(
      bundle_id = as.character(bundle_row$bundle_id[[1L]]),
      bundle_code = code,
      run_tag = run_tag,
      run_root = normalizePath(gate_root, winslash = "/", mustWork = FALSE),
      root_id = root_id,
      screening_profile_id = profile,
      profile_suffix = sub("^.*_(p[0-9]+[a-z]*)$", "\\1", profile),
      root_status = status,
      log_path = normalizePath(log_path, winslash = "/", mustWork = FALSE),
      error_signature = err,
      stringsAsFactors = FALSE
    )
  })
  if (!length(rows)) {
    return(data.frame(
      bundle_id = as.character(bundle_row$bundle_id[[1L]]),
      bundle_code = code,
      run_tag = run_tag,
      run_root = normalizePath(gate_root, winslash = "/", mustWork = FALSE),
      root_id = character(),
      stringsAsFactors = FALSE
    ))
  }
  do.call(rbind, rows)
}

status <- do.call(rbind, lapply(seq_len(nrow(bundle_meta)), function(i) read_status(bundle_meta[i, , drop = FALSE])))
if (!nrow(status)) stop("No root_status.txt files found for closeout.", call. = FALSE)

read_fit <- function(path) {
  x <- utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
  root_id <- sub("^.*/roots/([^/]+)/fits/.*$", "\\1", path)
  x$fit_summary_path <- normalizePath(path, winslash = "/", mustWork = TRUE)
  x$root_id <- as.character(x$root_id %||% root_id)
  x
}

fit_files <- unlist(lapply(unique(status$run_root), function(run_root) {
  list.files(run_root, pattern = "^fit_summary_row[.]csv$", recursive = TRUE, full.names = TRUE)
}), use.names = FALSE)
fits_all <- if (length(fit_files)) do.call(rbind, lapply(fit_files, read_fit)) else data.frame(stringsAsFactors = FALSE)
fits_all <- merge(fits_all, status[, c("root_id", "bundle_code", "run_tag", "root_status")], by = "root_id", all.x = TRUE, sort = FALSE)
fits <- fits_all[as.character(fits_all$root_status) == "SUCCESS" & as.character(fits_all$status) == "SUCCESS", , drop = FALSE]

lead_rows <- lapply(seq_len(nrow(fits)), function(i) {
  path <- as.character(fits$forecast_lead_metrics_path[[i]] %||% file.path(dirname(fits$fit_summary_path[[i]]), "tables", "forecast_lead_metrics.csv"))
  if (!file.exists(path)) return(NULL)
  x <- utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
  data.frame(
    root_id = fits$root_id[[i]],
    n_forecast_lead_rows = nrow(x),
    n_origins_scored_total_from_leads = sum(num(x$n_origins_scored), na.rm = TRUE),
    forecast_qtrue_mae_lead_mean = mean(num(x$forecast_qtrue_mae), na.rm = TRUE),
    forecast_qtrue_rmse_lead_mean = mean(num(x$forecast_qtrue_rmse), na.rm = TRUE),
    forecast_pinball_mean_lead_mean = mean(num(x$forecast_pinball_mean), na.rm = TRUE),
    forecast_coverage_error_lead_mean = mean(abs(num(x$forecast_coverage_error)), na.rm = TRUE),
    forecast_lead_metrics_path = normalizePath(path, winslash = "/", mustWork = TRUE),
    stringsAsFactors = FALSE
  )
})
lead_agg <- do.call(rbind, Filter(Negate(is.null), lead_rows))
fit_forecast <- merge(fits, lead_agg, by = "root_id", all.x = TRUE, sort = FALSE)

metrics <- c("train_qtrue_rmse", "train_pinball_tau", "forecast_qtrue_mae_lead_mean", "forecast_pinball_mean_lead_mean")
for (nm in metrics) if (nm %in% names(fit_forecast)) fit_forecast[[nm]] <- num(fit_forecast[[nm]])

health <- as.data.frame.matrix(table(status$bundle_code, status$root_status))
health$bundle_code <- rownames(health)
for (nm in c("SUCCESS", "FAIL", "RUNNING")) if (!nm %in% names(health)) health[[nm]] <- 0L
expected_by_bundle <- aggregate(root_id ~ bundle_code, status, length)
names(expected_by_bundle)[2L] <- "planned_roots"
health <- merge(expected_by_bundle, health, by = "bundle_code", all.x = TRUE, sort = FALSE)
lead_counts <- aggregate(n_forecast_lead_rows ~ bundle_code, fit_forecast, sum, na.rm = TRUE)
names(lead_counts)[2L] <- "forecast_lead_rows"
fit_counts <- aggregate(root_id ~ bundle_code, fit_forecast, length)
names(fit_counts)[2L] <- "success_fit_metric_rows"
health <- merge(merge(health, fit_counts, by = "bundle_code", all.x = TRUE), lead_counts, by = "bundle_code", all.x = TRUE)
health$success_fit_metric_rows[is.na(health$success_fit_metric_rows)] <- 0L
health$forecast_lead_rows[is.na(health$forecast_lead_rows)] <- 0L
health$terminal_roots <- health$SUCCESS + health$FAIL
health$remaining_roots <- health$planned_roots - health$terminal_roots
health$pct_terminal <- round(100 * health$terminal_roots / health$planned_roots, 1)
health$pct_success <- round(100 * health$SUCCESS / health$planned_roots, 1)

profile_status <- as.data.frame.matrix(table(status$profile_suffix, status$root_status))
profile_status$profile_suffix <- rownames(profile_status)
profile_status <- profile_status[order(profile_status$profile_suffix), c("profile_suffix", intersect(c("SUCCESS", "FAIL", "RUNNING"), names(profile_status))), drop = FALSE]

failure_ledger <- status[status$root_status != "SUCCESS", , drop = FALSE]
if (nrow(failure_ledger)) {
  failure_ledger$consume_policy <- "refuse"
  failure_ledger$failure_class <- ifelse(
    grepl("RHS_NS hypers[$]tau0 must be > 0|Invalid rhs_tau0", failure_ledger$error_signature),
    "invalid_rhs_tau0_tiny_surface",
    "runtime_failure"
  )
} else {
  failure_ledger$consume_policy <- character(0)
  failure_ledger$failure_class <- character(0)
}

ranked <- data.frame(stringsAsFactors = FALSE)
cell_winners <- data.frame(stringsAsFactors = FALSE)
if (nrow(fit_forecast)) {
  fit_forecast$cell <- paste(fit_forecast$family, sprintf("%.2f", num(fit_forecast$tau)), fit_forecast$likelihood_family, sep = "|")
  ranked <- do.call(rbind, lapply(split(fit_forecast, fit_forecast$cell), function(d) {
    for (metric in metrics) {
      best <- min(d[[metric]], na.rm = TRUE)
      d[[paste0(metric, "_ratio_to_screen_best")]] <- if (is.finite(best) && best > 0) d[[metric]] / best else NA_real_
    }
    ratio_cols <- paste0(metrics, "_ratio_to_screen_best")
    d$screen_joint_sum <- rowSums(d[, ratio_cols], na.rm = FALSE)
    d$screen_joint_worst <- apply(d[, ratio_cols], 1L, max, na.rm = FALSE)
    d <- d[order(d$screen_joint_worst, d$screen_joint_sum, d$bundle_code, d$screening_profile_id), , drop = FALSE]
    d$screen_cell_rank <- seq_len(nrow(d))
    d
  }))
  cell_winners <- ranked[ranked$screen_cell_rank == 1L, , drop = FALSE]
  cell_winners <- cell_winners[order(cell_winners$family, num(cell_winners$tau), cell_winners$likelihood_family), , drop = FALSE]
}

comparison <- data.frame(stringsAsFactors = FALSE)
ratio_breakdown <- data.frame(stringsAsFactors = FALSE)
qvbm1_path <- resolve_path(
  "reports/qvbm1/audit/closeout/qvbm1_decomp_guardfix_20260713_main__git-8c6eda9/tables/qvbm1_mechanism_first_current_table_comparison.csv",
  must_work = FALSE
)
if (nrow(cell_winners) && file.exists(qvbm1_path)) {
  q1 <- utils::read.csv(qvbm1_path, stringsAsFactors = FALSE, check.names = FALSE)
  q1$cell <- paste(q1$family, sprintf("%.2f", num(q1$tau)), q1$qdesn_likelihood, sep = "|")
  comparison <- merge(cell_winners, q1, by = "cell", all.x = TRUE, suffixes = c("_screen", "_qvbm1"), sort = FALSE)
  ratio <- function(a, b) {
    out <- num(a) / num(b)
    out[!is.finite(out)] <- NA_real_
    out
  }
  comparison$ratio_vs_qvbm1_fit_rmse <- ratio(comparison$train_qtrue_rmse, comparison$qvbm1_fit_rmse)
  comparison$ratio_vs_qvbm1_fit_check <- ratio(comparison$train_pinball_tau, comparison$qvbm1_fit_check)
  comparison$ratio_vs_qvbm1_fcst_mae <- ratio(comparison$forecast_qtrue_mae_lead_mean, comparison$qvbm1_fcst_mae)
  comparison$ratio_vs_qvbm1_fcst_check <- ratio(comparison$forecast_pinball_mean_lead_mean, comparison$qvbm1_fcst_check)
  comparison$ratio_vs_exdqlm_fit_rmse <- ratio(comparison$train_qtrue_rmse, comparison$best_exdqlm_dqlm_vb_fit_rmse)
  comparison$ratio_vs_exdqlm_fit_check <- ratio(comparison$train_pinball_tau, comparison$best_exdqlm_dqlm_vb_fit_check)
  comparison$ratio_vs_exdqlm_fcst_mae <- ratio(comparison$forecast_qtrue_mae_lead_mean, comparison$best_exdqlm_dqlm_vb_fcst_mae)
  comparison$ratio_vs_exdqlm_fcst_check <- ratio(comparison$forecast_pinball_mean_lead_mean, comparison$best_exdqlm_dqlm_vb_fcst_check)
  comparison$beats_qvbm1_all4 <- apply(comparison[, c("ratio_vs_qvbm1_fit_rmse", "ratio_vs_qvbm1_fit_check", "ratio_vs_qvbm1_fcst_mae", "ratio_vs_qvbm1_fcst_check")], 1L, function(z) all(num(z) < 1, na.rm = FALSE))
  comparison$beats_exdqlm_all4 <- apply(comparison[, c("ratio_vs_exdqlm_fit_rmse", "ratio_vs_exdqlm_fit_check", "ratio_vs_exdqlm_fcst_mae", "ratio_vs_exdqlm_fcst_check")], 1L, function(z) all(num(z) < 1, na.rm = FALSE))
  ratio_breakdown <- comparison[, intersect(c(
    "family_screen", "tau_screen", "likelihood_family", "screening_profile_id",
    "ratio_vs_qvbm1_fit_rmse", "ratio_vs_qvbm1_fit_check", "ratio_vs_qvbm1_fcst_mae", "ratio_vs_qvbm1_fcst_check",
    "ratio_vs_exdqlm_fit_rmse", "ratio_vs_exdqlm_fit_check", "ratio_vs_exdqlm_fcst_mae", "ratio_vs_exdqlm_fcst_check",
    "beats_qvbm1_all4", "beats_exdqlm_all4"
  ), names(comparison)), drop = FALSE]
}

storage_files <- unique(unlist(lapply(c(unique(status$run_root), dirname(orchestrator_manifest)), function(p) {
  if (!dir.exists(p)) character() else list.files(p, recursive = TRUE, full.names = TRUE, all.files = TRUE, no.. = TRUE)
}), use.names = FALSE))
forbidden <- storage_files[grepl("([.]rds|[.]rda|[.]RData|__design[.]rds)$", storage_files)]
storage_audit <- data.frame(
  scope = c("run_roots_and_orchestrator"),
  files_scanned = length(storage_files),
  forbidden_payloads = length(forbidden),
  forbidden_bytes = sum(file.info(forbidden)$size, na.rm = TRUE),
  status = if (length(forbidden)) "FAIL" else "PASS",
  forbidden_paths = paste(normalizePath(forbidden, winslash = "/", mustWork = FALSE), collapse = "|"),
  stringsAsFactors = FALSE
)

paths <- list(
  health = write_csv(health, file.path(out_dir, "tables", "qvbm2_health.csv")),
  profile_status = write_csv(profile_status, file.path(out_dir, "tables", "qvbm2_profile_status.csv")),
  failure_ledger = write_csv(failure_ledger, file.path(out_dir, "tables", "qvbm2_invalid_failure_ledger.csv")),
  fit_forecast = write_csv(fit_forecast, file.path(out_dir, "tables", "qvbm2_fit_forecast_summary.csv")),
  ranked = write_csv(ranked, file.path(out_dir, "tables", "qvbm2_ranked_candidates.csv")),
  cell_winners = write_csv(cell_winners, file.path(out_dir, "tables", "qvbm2_cell_winners.csv")),
  ratio_breakdown = write_csv(ratio_breakdown, file.path(out_dir, "tables", "qvbm2_ratio_breakdown.csv")),
  storage_audit = write_csv(storage_audit, file.path(out_dir, "tables", "qvbm2_storage_audit.csv"))
)

total_planned <- sum(health$planned_roots)
total_success <- sum(health$SUCCESS)
total_fail <- sum(health$FAIL)
total_remaining <- sum(health$remaining_roots)
total_leads <- sum(health$forecast_lead_rows)
storage_pass <- all(storage_audit$status == "PASS")
known_invalid_fail <- total_fail > 0 && all(failure_ledger$failure_class == "invalid_rhs_tau0_tiny_surface")
promote_n <- if (nrow(comparison)) sum(comparison$beats_qvbm1_all4 & comparison$beats_exdqlm_all4, na.rm = TRUE) else 0L

winner_display <- cell_winners[, intersect(c(
  "family", "tau", "likelihood_family", "bundle_code", "screening_profile_id", "profile_role",
  "train_qtrue_rmse", "train_pinball_tau", "forecast_qtrue_mae_lead_mean",
  "forecast_pinball_mean_lead_mean", "screen_joint_worst"
), names(cell_winners)), drop = FALSE]

summary_lines <- c(
  "# Q-DESN qvbm2 VB Blocker-Aware Closeout",
  "",
  sprintf("- generated_at: `%s`", as.character(Sys.time())),
  sprintf("- worktree: `%s`", repo_root),
  sprintf("- branch: `%s`", git_value(c("branch", "--show-current"))),
  sprintf("- head: `%s`", git_value(c("rev-parse", "HEAD"))),
  sprintf("- orchestrator_manifest: `%s`", orchestrator_manifest),
  sprintf("- article_summary_read_only: `%s`", if (file.exists(article_summary)) article_summary else "not available"),
  sprintf("- planned_roots: `%d`", total_planned),
  sprintf("- success_roots: `%d`", total_success),
  sprintf("- failed_roots: `%d`", total_fail),
  sprintf("- remaining_roots: `%d`", total_remaining),
  sprintf("- forecast_lead_rows_successes: `%d`", total_leads),
  sprintf("- storage_light_pass: `%s`", storage_pass),
  sprintf("- known_invalid_p03_failure_only: `%s`", known_invalid_fail),
  sprintf("- mcmc_promote_after_review_cells: `%d`", promote_n),
  "",
  "## Decision",
  "",
  if (total_remaining == 0L && storage_pass && known_invalid_fail) {
    "qvbm2 is operationally closed but not MCMC-promotable. The only failed roots are the p03 tiny-RHS-tau surface; they are explicitly refused and must not be consumed. Successful candidates mostly reproduce qvbm1-level evidence rather than clearing the conservative dominance gate."
  } else if (total_remaining == 0L && storage_pass && total_fail == 0L) {
    "The screen is operationally complete and storage-light. Promotion still requires the ratio gate below."
  } else {
    "The screen is not ready for promotion. Completion or storage-light checks failed."
  },
  "",
  "## Health",
  "",
  md_table(health, c("bundle_code", "planned_roots", "SUCCESS", "FAIL", "remaining_roots", "pct_terminal", "pct_success", "success_fit_metric_rows", "forecast_lead_rows")),
  "",
  "## Profile Status",
  "",
  md_table(profile_status),
  "",
  "## Invalid/Failure Ledger",
  "",
  "Rows below are refusal rows. They are evidence of a failed exploratory surface, not valid model results.",
  "",
  md_table(failure_ledger, c("bundle_code", "run_tag", "screening_profile_id", "profile_suffix", "root_status", "failure_class", "consume_policy", "error_signature"), max_rows = 20L),
  "",
  "## Best Successful Candidates",
  "",
  md_table(winner_display),
  "",
  "## Baseline Ratios",
  "",
  md_table(ratio_breakdown, digits = 3L),
  "",
  "## Storage Audit",
  "",
  md_table(storage_audit),
  "",
  "## Next Safe Step",
  "",
  "Run the p03 safe-floor repair as a separate non-authoritative screen. It should retain the p03 structural design but replace `rhs_tau0 = 3e-05` with the stable lower bound `rhs_tau0 = 1e-04`, using new root IDs and new run tags so the original refused qvbm2 p03 roots remain untouched.",
  "",
  "## Output Paths",
  "",
  sprintf("- health: `%s`", paths$health),
  sprintf("- profile_status: `%s`", paths$profile_status),
  sprintf("- failure_ledger: `%s`", paths$failure_ledger),
  sprintf("- fit_forecast: `%s`", paths$fit_forecast),
  sprintf("- ranked: `%s`", paths$ranked),
  sprintf("- cell_winners: `%s`", paths$cell_winners),
  sprintf("- ratio_breakdown: `%s`", paths$ratio_breakdown),
  sprintf("- storage_audit: `%s`", paths$storage_audit)
)

paths$summary <- write_lines(summary_lines, file.path(out_dir, "summary", "qvbm2_closeout.md"))
paths$docs_report <- write_lines(summary_lines, docs_report)

manifest_out <- list(
  generated_at = as.character(Sys.time()),
  repo_root = repo_root,
  branch = git_value(c("branch", "--show-current")),
  head = git_value(c("rev-parse", "HEAD")),
  orchestrator_manifest = orchestrator_manifest,
  totals = list(
    planned_roots = total_planned,
    success_roots = total_success,
    failed_roots = total_fail,
    remaining_roots = total_remaining,
    forecast_lead_rows_successes = total_leads,
    storage_light_pass = storage_pass,
    known_invalid_p03_failure_only = known_invalid_fail,
    mcmc_promote_after_review_cells = promote_n
  ),
  output_paths = paths,
  output_sha256 = as.list(vapply(unlist(paths), sha256_file, character(1)))
)
manifest_path <- resolve_path(file.path(out_dir, "manifest", "qvbm2_closeout_manifest.json"), must_work = FALSE)
dir.create(dirname(manifest_path), recursive = TRUE, showWarnings = FALSE)
jsonlite::write_json(manifest_out, manifest_path, pretty = TRUE, auto_unbox = TRUE, null = "null")
manifest_path <- normalizePath(manifest_path, winslash = "/", mustWork = TRUE)

cat(sprintf("summary: %s\n", paths$summary))
cat(sprintf("docs_report: %s\n", paths$docs_report))
cat(sprintf("manifest: %s\n", manifest_path))
cat(sprintf("planned=%d success=%d fail=%d remaining=%d storage_light=%s promote_cells=%d\n",
            total_planned, total_success, total_fail, total_remaining, storage_pass, promote_n))

quit(status = if (total_remaining == 0L && storage_pass) 0L else 1L, save = "no")

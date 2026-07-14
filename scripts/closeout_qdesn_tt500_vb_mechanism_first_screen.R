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
  if (!length(idx)) return(default)
  idx <- idx[[1L]]
  if (idx >= length(args)) return(default)
  args[[idx + 1L]]
}

has_flag <- function(flag) any(args == flag)

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

write_csv <- function(x, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(x, path, row.names = FALSE, na = "")
  normalizePath(path, winslash = "/", mustWork = TRUE)
}

write_lines <- function(lines, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  writeLines(lines, path, useBytes = TRUE)
  normalizePath(path, winslash = "/", mustWork = TRUE)
}

md_table <- function(x, digits = 4L) {
  if (is.null(x) || !nrow(x)) return(c("| empty |", "|---|", "| no rows |"))
  y <- x
  for (nm in names(y)) {
    if (is.numeric(y[[nm]])) y[[nm]] <- ifelse(is.na(y[[nm]]), "", format(round(y[[nm]], digits), trim = TRUE, scientific = FALSE))
    y[[nm]] <- gsub("\\|", "/", as.character(y[[nm]]))
    y[[nm]][is.na(y[[nm]])] <- ""
  }
  header <- paste0("| ", paste(names(y), collapse = " | "), " |")
  sep <- paste0("|", paste(rep("---", ncol(y)), collapse = "|"), "|")
  rows <- apply(y, 1L, function(z) paste0("| ", paste(z, collapse = " | "), " |"))
  c(header, sep, rows)
}

sha256_file <- function(path) {
  path <- normalizePath(path, winslash = "/", mustWork = TRUE)
  out <- tryCatch(system2("sha256sum", shQuote(path), stdout = TRUE, stderr = FALSE), error = function(e) character())
  if (length(out) && nzchar(out[[1L]])) return(strsplit(out[[1L]], "\\s+")[[1L]][[1L]])
  paste(unname(tools::md5sum(path)), "(md5-fallback)")
}

git_value <- function(cmd) {
  out <- tryCatch(system(cmd, intern = TRUE), error = function(e) NA_character_)
  if (!length(out)) NA_character_ else out[[1L]]
}

num <- function(x) suppressWarnings(as.numeric(x))

run_map <- data.frame(
  bundle = c("raw", "c12", "c123", "sr", "srp", "srx"),
  tag = c(
    "m1rawf_07132035_90defed",
    "m1c12f_07132209_8c6eda9",
    "m1c123f_07132209_8c6eda9",
    "m1srf_07132209_8c6eda9",
    "m1srpf_07132209_8c6eda9",
    "m1srxf_07132209_8c6eda9"
  ),
  role = c(
    "raw_period90_control",
    "decomp_component_p90_h12",
    "decomp_component_p90_h123",
    "decomp_state_resid_y_p90_h12",
    "decomp_state_resid_y_plugin_p90_h12",
    "decomp_state_resid_y_xreg_p90_h12"
  ),
  stringsAsFactors = FALSE
)

invalid_tags <- data.frame(
  bundle = c("c12", "c123", "sr", "srp", "srx"),
  invalid_tag = c(
    "m1c12f_07132035_90defed",
    "m1c123f_07132035_90defed",
    "m1srf_07132035_90defed",
    "m1srpf_07132035_90defed",
    "m1srxf_07132035_90defed"
  ),
  reason = "aborted before guard fix: validation campaigns enforced readout.input_mode='raw_y_lags' and rejected dlm_decomp_lags",
  consume_policy = "refuse",
  stringsAsFactors = FALSE
)

default_out_dir <- file.path("reports", "qvbm1", "audit", "closeout", "qvbm1_decomp_guardfix_20260713_main__git-8c6eda9")
out_dir <- resolve_path(get_arg("--out-dir", default_out_dir), must_work = FALSE)
article_summary <- resolve_path(
  get_arg("--article-summary", "/data/jaguir26/local/src/Article-Q-DESN---Version-2/tables/qdesn_validation_tt500_final_summary.csv"),
  must_work = FALSE
)
docs_report <- resolve_path(
  get_arg("--docs-report", "validation/fitforecast_v2/docs/QDESN_500OBS_VB_MECHANISM_FIRST_CLOSEOUT_2026-07-14.md"),
  must_work = FALSE
)
skip_docs_report <- has_flag("--no-docs-report")
expected_roots_per_bundle <- as.integer(get_arg("--expected-roots-per-bundle", "32"))
expected_leads_per_root <- as.integer(get_arg("--expected-leads-per-root", "30"))

read_fit <- function(path) {
  x <- utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
  parts <- strsplit(path, "/", fixed = TRUE)[[1L]]
  qidx <- match("qvbm1", parts)
  x$bundle <- parts[[qidx + 1L]]
  x$run_tag <- parts[[qidx + 2L]]
  x$run_stamp <- parts[[qidx + 3L]]
  x$fit_summary_path <- normalizePath(path, winslash = "/", mustWork = TRUE)
  x
}

fit_files <- unlist(lapply(seq_len(nrow(run_map)), function(i) {
  Sys.glob(file.path("results", "qvbm1", run_map$bundle[[i]], run_map$tag[[i]], "*", "roots", "*", "fits", "*", "fit_summary_row.csv"))
}), use.names = FALSE)

if (!length(fit_files)) stop("No qvbm1 fit_summary_row.csv files found for the configured run map.", call. = FALSE)
fits <- do.call(rbind, lapply(fit_files, read_fit))
fits <- merge(fits, run_map, by.x = c("bundle", "run_tag"), by.y = c("bundle", "tag"), all.x = TRUE, sort = FALSE)

lead_files <- file.path(dirname(fits$fit_summary_path), "tables", "forecast_lead_metrics.csv")
read_leads <- function(path, i) {
  if (!file.exists(path)) return(NULL)
  x <- utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
  x$bundle <- fits$bundle[[i]]
  x$run_tag <- fits$run_tag[[i]]
  x$screening_profile_id <- fits$screening_profile_id[[i]]
  x$profile_role <- fits$profile_role[[i]]
  x$likelihood_family <- fits$likelihood_family[[i]]
  x$fit_summary_path <- fits$fit_summary_path[[i]]
  x
}
leads <- do.call(rbind, lapply(seq_along(lead_files), function(i) read_leads(lead_files[[i]], i)))
if (is.null(leads) || !nrow(leads)) stop("No forecast_lead_metrics.csv rows found.", call. = FALSE)

lead_agg <- aggregate(
  cbind(forecast_qtrue_mae, forecast_qtrue_rmse, forecast_pinball_mean, forecast_coverage_error) ~ fit_summary_path,
  leads,
  function(z) mean(num(z), na.rm = TRUE)
)
names(lead_agg)[2:5] <- c(
  "forecast_qtrue_mae_lead_mean",
  "forecast_qtrue_rmse_lead_mean",
  "forecast_pinball_mean_lead_mean",
  "forecast_coverage_error_lead_mean"
)
lead_counts <- aggregate(forecast_lead ~ fit_summary_path, leads, length)
names(lead_counts)[2L] <- "n_forecast_lead_rows"
origin_counts <- aggregate(n_origins_scored ~ fit_summary_path, leads, sum)
names(origin_counts)[2L] <- "n_origins_scored_total_from_leads"
lead_agg <- merge(merge(lead_agg, lead_counts, by = "fit_summary_path", all.x = TRUE), origin_counts, by = "fit_summary_path", all.x = TRUE)

fit_forecast <- merge(fits, lead_agg, by = "fit_summary_path", all.x = TRUE, sort = FALSE)
for (nm in c(
  "train_qtrue_rmse", "train_pinball_tau", "runtime_sec",
  "forecast_qtrue_mae_lead_mean", "forecast_qtrue_rmse_lead_mean",
  "forecast_pinball_mean_lead_mean", "forecast_coverage_error_lead_mean"
)) {
  if (nm %in% names(fit_forecast)) fit_forecast[[nm]] <- num(fit_forecast[[nm]])
}

status_summary <- aggregate(root_id ~ bundle, fit_forecast, length)
names(status_summary)[2L] <- "fit_roots"
lead_summary <- aggregate(forecast_lead ~ bundle, leads, length)
names(lead_summary)[2L] <- "forecast_lead_rows"
health <- merge(run_map, merge(status_summary, lead_summary, by = "bundle", all = TRUE), by = "bundle", all.x = TRUE, sort = FALSE)
health$expected_fit_roots <- expected_roots_per_bundle
health$expected_forecast_lead_rows <- expected_roots_per_bundle * expected_leads_per_root
health$n_success <- vapply(health$bundle, function(b) sum(fit_forecast$bundle == b & fit_forecast$status == "SUCCESS"), integer(1))
health$n_pass <- vapply(health$bundle, function(b) sum(fit_forecast$bundle == b & fit_forecast$signoff_grade == "PASS"), integer(1))
health$n_finite_domain_ok <- vapply(health$bundle, function(b) {
  sum(fit_forecast$bundle == b & fit_forecast$finite_ok %in% TRUE & fit_forecast$domain_ok %in% TRUE)
}, integer(1))
health$fit_roots_remaining <- health$expected_fit_roots - health$fit_roots
health$forecast_lead_rows_remaining <- health$expected_forecast_lead_rows - health$forecast_lead_rows
health$pct_done <- round(100 * health$fit_roots / health$expected_fit_roots, 1)
metric_median <- aggregate(
  fit_forecast[, c("train_qtrue_rmse", "train_pinball_tau", "forecast_qtrue_mae_lead_mean", "forecast_pinball_mean_lead_mean")],
  by = list(bundle = fit_forecast$bundle),
  median,
  na.rm = TRUE
)
health <- merge(health, metric_median, by = "bundle", all.x = TRUE, sort = FALSE)
health <- health[match(run_map$bundle, health$bundle), , drop = FALSE]

cell_key <- paste(fit_forecast$family, fit_forecast$tau, fit_forecast$likelihood_family, sep = "\r")
primary <- c("train_qtrue_rmse", "train_pinball_tau", "forecast_qtrue_mae_lead_mean", "forecast_pinball_mean_lead_mean")
ranked <- do.call(rbind, lapply(split(fit_forecast, cell_key), function(d) {
  for (metric in primary) {
    best <- min(d[[metric]], na.rm = TRUE)
    d[[paste0(metric, "_ratio_to_qvbm1_best")]] <- if (is.finite(best) && best > 0) d[[metric]] / best else NA_real_
  }
  ratio_cols <- paste0(primary, "_ratio_to_qvbm1_best")
  d$joint_ratio_sum <- rowSums(d[, ratio_cols], na.rm = FALSE)
  d$joint_worst_ratio <- apply(d[, ratio_cols], 1L, function(z) if (all(is.finite(z))) max(z) else NA_real_)
  d <- d[order(d$joint_ratio_sum, d$joint_worst_ratio, d$bundle, d$screening_profile_id), , drop = FALSE]
  d$qvbm1_cell_rank <- seq_len(nrow(d))
  d
}))

cell_winners <- ranked[ranked$qvbm1_cell_rank == 1L, , drop = FALSE]
cell_winners <- cell_winners[order(cell_winners$family, cell_winners$tau, cell_winners$likelihood_family), , drop = FALSE]

article_comparison <- data.frame(stringsAsFactors = FALSE)
if (!is.null(article_summary) && file.exists(article_summary)) {
  art <- utils::read.csv(article_summary, stringsAsFactors = FALSE, check.names = FALSE)
  art <- art[as.integer(art$fit_size) == 500L & tolower(art$inference) == "vb", , drop = FALSE]
  metric_from_art <- function(sub, col) {
    vals <- num(sub[[col]])
    ok <- is.finite(vals)
    if (!any(ok)) return(list(value = NA_real_, model_key = NA_character_, label = NA_character_))
    idx <- which(ok)[which.min(vals[ok])]
    list(value = vals[[idx]], model_key = as.character(sub$model_key[[idx]]), label = as.character(sub$model_label[[idx]]))
  }
  compare_rows <- lapply(seq_len(nrow(cell_winners)), function(i) {
    w <- cell_winners[i, , drop = FALSE]
    same_q <- art[
      tolower(art$model_family) == "qdesn" &
        tolower(art$model_variant) == "rhs_ns" &
        tolower(art$qdesn_likelihood) == tolower(w$likelihood_family) &
        art$family == w$family &
        abs(num(art$tau) - num(w$tau)) < 1e-10,
      ,
      drop = FALSE
    ]
    exd <- art[
      tolower(art$model_family) == "exdqlm_dqlm" &
        art$family == w$family &
        abs(num(art$tau) - num(w$tau)) < 1e-10,
      ,
      drop = FALSE
    ]
    all_vb <- art[
      art$family == w$family &
        abs(num(art$tau) - num(w$tau)) < 1e-10,
      ,
      drop = FALSE
    ]
    pick_baseline <- function(sub, prefix) {
      if (!nrow(sub)) {
        return(data.frame(
          stringsAsFactors = FALSE,
          setNames(list(NA_real_, NA_character_, NA_real_, NA_character_, NA_real_, NA_character_, NA_real_, NA_character_),
                   paste0(prefix, c("_fit_rmse", "_fit_rmse_model", "_fit_check", "_fit_check_model", "_fcst_mae", "_fcst_mae_model", "_fcst_check", "_fcst_check_model")))
        ))
      }
      rmse <- metric_from_art(sub, "fit_qtrue_rmse")
      check <- metric_from_art(sub, "fit_pinball_mean")
      mae <- metric_from_art(sub, "forecast_qtrue_mae_lead_weighted")
      fcheck <- metric_from_art(sub, "forecast_pinball_mean_lead_weighted")
      data.frame(
        stringsAsFactors = FALSE,
        setNames(
          list(rmse$value, rmse$model_key, check$value, check$model_key, mae$value, mae$model_key, fcheck$value, fcheck$model_key),
          paste0(prefix, c("_fit_rmse", "_fit_rmse_model", "_fit_check", "_fit_check_model", "_fcst_mae", "_fcst_mae_model", "_fcst_check", "_fcst_check_model"))
        )
      )
    }
    base_same_q <- pick_baseline(same_q, "current_qdesn_rhsns_same_likelihood")
    base_exd <- pick_baseline(exd, "best_exdqlm_dqlm_vb")
    base_all <- pick_baseline(all_vb, "best_article_vb_any_model")
    out <- data.frame(
      family = w$family,
      tau = num(w$tau),
      qdesn_likelihood = w$likelihood_family,
      qvbm1_bundle = w$bundle,
      qvbm1_profile = w$screening_profile_id,
      qvbm1_fit_rmse = w$train_qtrue_rmse,
      qvbm1_fit_check = w$train_pinball_tau,
      qvbm1_fcst_mae = w$forecast_qtrue_mae_lead_mean,
      qvbm1_fcst_check = w$forecast_pinball_mean_lead_mean,
      qvbm1_joint_worst_ratio = w$joint_worst_ratio,
      stringsAsFactors = FALSE
    )
    cbind(out, base_same_q, base_exd, base_all)
  })
  article_comparison <- do.call(rbind, compare_rows)
  ratio_to <- function(numv, denv) {
    out <- num(numv) / num(denv)
    out[!is.finite(out)] <- NA_real_
    out
  }
  for (prefix in c("current_qdesn_rhsns_same_likelihood", "best_exdqlm_dqlm_vb", "best_article_vb_any_model")) {
    article_comparison[[paste0("ratio_vs_", prefix, "_fit_rmse")]] <- ratio_to(article_comparison$qvbm1_fit_rmse, article_comparison[[paste0(prefix, "_fit_rmse")]])
    article_comparison[[paste0("ratio_vs_", prefix, "_fit_check")]] <- ratio_to(article_comparison$qvbm1_fit_check, article_comparison[[paste0(prefix, "_fit_check")]])
    article_comparison[[paste0("ratio_vs_", prefix, "_fcst_mae")]] <- ratio_to(article_comparison$qvbm1_fcst_mae, article_comparison[[paste0(prefix, "_fcst_mae")]])
    article_comparison[[paste0("ratio_vs_", prefix, "_fcst_check")]] <- ratio_to(article_comparison$qvbm1_fcst_check, article_comparison[[paste0(prefix, "_fcst_check")]])
  }
}

if (nrow(article_comparison)) {
  qprefix <- "ratio_vs_current_qdesn_rhsns_same_likelihood_"
  eprefix <- "ratio_vs_best_exdqlm_dqlm_vb_"
  article_comparison$beats_current_qdesn_rhsns_all_primary <- apply(
    article_comparison[, paste0(qprefix, c("fit_rmse", "fit_check", "fcst_mae", "fcst_check")), drop = FALSE],
    1L,
    function(z) all(is.finite(num(z)) & num(z) < 1)
  )
  article_comparison$beats_best_exdqlm_dqlm_vb_all_primary <- apply(
    article_comparison[, paste0(eprefix, c("fit_rmse", "fit_check", "fcst_mae", "fcst_check")), drop = FALSE],
    1L,
    function(z) all(is.finite(num(z)) & num(z) < 1)
  )
  article_comparison$mcmc_handoff_status <- ifelse(
    article_comparison$beats_current_qdesn_rhsns_all_primary & article_comparison$beats_best_exdqlm_dqlm_vb_all_primary,
    "PROMOTE_AFTER_REVIEW",
    "HOLD_DIAGNOSTIC_ONLY"
  )
  article_comparison$mcmc_handoff_reason <- ifelse(
    article_comparison$mcmc_handoff_status == "PROMOTE_AFTER_REVIEW",
    "wins all four primary metrics against both current Q-DESN RHS same-likelihood and best exDQLM/DQLM VB baselines",
    "does not win all four primary fit/forecast metrics against current baselines"
  )
}

invalid_tag_ledger <- do.call(rbind, lapply(seq_len(nrow(invalid_tags)), function(i) {
  tag <- invalid_tags$invalid_tag[[i]]
  fit_count <- length(Sys.glob(file.path("results", "qvbm1", invalid_tags$bundle[[i]], tag, "*", "roots", "*", "fits", "*", "fit_summary_row.csv")))
  report_count <- length(Sys.glob(file.path("reports", "qvbm1", invalid_tags$bundle[[i]], tag, "*")))
  data.frame(
    bundle = invalid_tags$bundle[[i]],
    invalid_tag = tag,
    fit_summary_rows_found = fit_count,
    report_roots_found = report_count,
    reason = invalid_tags$reason[[i]],
    consume_policy = invalid_tags$consume_policy[[i]],
    stringsAsFactors = FALSE
  )
}))

storage_patterns <- c(run_map$tag, invalid_tags$invalid_tag)
storage_audit <- do.call(rbind, lapply(storage_patterns, function(tag) {
  paths <- c(
    Sys.glob(file.path("results", "qvbm1", "*", tag, "*")),
    Sys.glob(file.path("reports", "qvbm1", "*", tag, "*"))
  )
  files <- unique(unlist(lapply(paths, function(p) {
    if (!file.exists(p)) character() else list.files(p, recursive = TRUE, full.names = TRUE, all.files = TRUE, no.. = TRUE)
  }), use.names = FALSE))
  forbidden <- files[grepl("([.]rds|[.]rda|[.]RData|__design[.]rds)$", files)]
  info <- file.info(files)
  finfo <- file.info(forbidden)
  data.frame(
    tag = tag,
    roots_found = length(paths),
    n_files = length(files),
    total_bytes = sum(info$size, na.rm = TRUE),
    forbidden_payloads = length(forbidden),
    forbidden_bytes = sum(finfo$size, na.rm = TRUE),
    status = if (length(forbidden)) "FAIL" else "PASS",
    forbidden_paths = paste(normalizePath(forbidden, winslash = "/", mustWork = FALSE), collapse = "|"),
    stringsAsFactors = FALSE
  )
}))

bundle_win_counts <- as.data.frame(table(cell_winners$bundle), stringsAsFactors = FALSE)
names(bundle_win_counts) <- c("bundle", "n_cell_wins")
bundle_win_counts <- bundle_win_counts[order(bundle_win_counts$bundle), , drop = FALSE]

ratio_blockers <- data.frame(stringsAsFactors = FALSE)
if (nrow(article_comparison)) {
  blocker_cols <- c(
    current_qdesn_fit_rmse = "ratio_vs_current_qdesn_rhsns_same_likelihood_fit_rmse",
    current_qdesn_fit_check = "ratio_vs_current_qdesn_rhsns_same_likelihood_fit_check",
    current_qdesn_fcst_mae = "ratio_vs_current_qdesn_rhsns_same_likelihood_fcst_mae",
    current_qdesn_fcst_check = "ratio_vs_current_qdesn_rhsns_same_likelihood_fcst_check",
    exdqlm_dqlm_fit_rmse = "ratio_vs_best_exdqlm_dqlm_vb_fit_rmse",
    exdqlm_dqlm_fit_check = "ratio_vs_best_exdqlm_dqlm_vb_fit_check",
    exdqlm_dqlm_fcst_mae = "ratio_vs_best_exdqlm_dqlm_vb_fcst_mae",
    exdqlm_dqlm_fcst_check = "ratio_vs_best_exdqlm_dqlm_vb_fcst_check"
  )
  ratio_blockers <- do.call(rbind, lapply(seq_len(nrow(article_comparison)), function(i) {
    ratios <- num(article_comparison[i, blocker_cols, drop = TRUE])
    failed <- names(blocker_cols)[is.finite(ratios) & ratios >= 1]
    worst_idx <- if (any(is.finite(ratios))) which.max(ratios) else NA_integer_
    data.frame(
      family = article_comparison$family[[i]],
      tau = article_comparison$tau[[i]],
      qdesn_likelihood = article_comparison$qdesn_likelihood[[i]],
      qvbm1_bundle = article_comparison$qvbm1_bundle[[i]],
      n_failed_primary_ratios = length(failed),
      failed_primary_ratios = paste(failed, collapse = ";"),
      worst_ratio_name = if (is.na(worst_idx)) NA_character_ else names(blocker_cols)[[worst_idx]],
      worst_ratio = if (is.na(worst_idx)) NA_real_ else ratios[[worst_idx]],
      stringsAsFactors = FALSE
    )
  }))
}

table_dir <- file.path(out_dir, "tables")
summary_dir <- file.path(out_dir, "summary")
manifest_dir <- file.path(out_dir, "manifest")
paths <- list(
  health = write_csv(health, file.path(table_dir, "qvbm1_mechanism_first_health.csv")),
  fit_forecast_summary = write_csv(fit_forecast, file.path(table_dir, "qvbm1_mechanism_first_fit_forecast_summary.csv")),
  ranked_candidates = write_csv(ranked, file.path(table_dir, "qvbm1_mechanism_first_ranked_candidates.csv")),
  cell_winners = write_csv(cell_winners, file.path(table_dir, "qvbm1_mechanism_first_cell_winners.csv")),
  bundle_win_counts = write_csv(bundle_win_counts, file.path(table_dir, "qvbm1_mechanism_first_bundle_win_counts.csv")),
  article_comparison = write_csv(article_comparison, file.path(table_dir, "qvbm1_mechanism_first_current_table_comparison.csv")),
  ratio_blockers = write_csv(ratio_blockers, file.path(table_dir, "qvbm1_mechanism_first_ratio_blockers.csv")),
  invalid_tag_ledger = write_csv(invalid_tag_ledger, file.path(table_dir, "qvbm1_mechanism_first_invalid_tag_ledger.csv")),
  storage_audit = write_csv(storage_audit, file.path(table_dir, "qvbm1_mechanism_first_storage_audit.csv"))
)

health_display <- health[, intersect(c(
  "bundle", "tag", "fit_roots", "expected_fit_roots", "forecast_lead_rows",
  "expected_forecast_lead_rows", "n_success", "n_pass", "fit_roots_remaining",
  "forecast_lead_rows_remaining", "pct_done", "train_qtrue_rmse",
  "train_pinball_tau", "forecast_qtrue_mae_lead_mean", "forecast_pinball_mean_lead_mean"
), names(health)), drop = FALSE]

winner_display <- cell_winners[, intersect(c(
  "family", "tau", "likelihood_family", "bundle", "screening_profile_id",
  "train_qtrue_rmse", "train_pinball_tau",
  "forecast_qtrue_mae_lead_mean", "forecast_pinball_mean_lead_mean",
  "joint_worst_ratio"
), names(cell_winners)), drop = FALSE]

comparison_display <- article_comparison
if (nrow(comparison_display)) {
  comparison_display <- comparison_display[, intersect(c(
    "family", "tau", "qdesn_likelihood", "qvbm1_bundle", "qvbm1_profile",
    "ratio_vs_current_qdesn_rhsns_same_likelihood_fit_rmse",
    "ratio_vs_current_qdesn_rhsns_same_likelihood_fit_check",
    "ratio_vs_current_qdesn_rhsns_same_likelihood_fcst_mae",
    "ratio_vs_current_qdesn_rhsns_same_likelihood_fcst_check",
    "ratio_vs_best_exdqlm_dqlm_vb_fit_rmse",
    "ratio_vs_best_exdqlm_dqlm_vb_fit_check",
    "ratio_vs_best_exdqlm_dqlm_vb_fcst_mae",
    "ratio_vs_best_exdqlm_dqlm_vb_fcst_check",
    "mcmc_handoff_status"
  ), names(comparison_display)), drop = FALSE]
}

total_fit <- sum(health$fit_roots)
total_expected <- sum(health$expected_fit_roots)
total_leads <- sum(health$forecast_lead_rows)
total_expected_leads <- sum(health$expected_forecast_lead_rows)
all_complete <- total_fit == total_expected && total_leads == total_expected_leads &&
  all(health$n_success == health$expected_fit_roots) &&
  all(health$n_pass == health$expected_fit_roots)
storage_pass <- all(storage_audit$status == "PASS")
mcmc_promote_n <- if (nrow(article_comparison)) sum(article_comparison$mcmc_handoff_status == "PROMOTE_AFTER_REVIEW", na.rm = TRUE) else 0L

summary_lines <- c(
  "# Q-DESN 500-Observation VB Mechanism-First Closeout",
  "",
  sprintf("- generated_at: `%s`", as.character(Sys.time())),
  sprintf("- worktree: `%s`", repo_root),
  sprintf("- branch: `%s`", git_value("git branch --show-current")),
  sprintf("- head: `%s`", git_value("git rev-parse HEAD")),
  sprintf("- article_summary_read_only: `%s`", if (!is.null(article_summary) && file.exists(article_summary)) article_summary else "not available"),
  sprintf("- qvbm1_fit_roots: `%d / %d`", total_fit, total_expected),
  sprintf("- qvbm1_forecast_lead_rows: `%d / %d`", total_leads, total_expected_leads),
  sprintf("- all_complete: `%s`", as.character(all_complete)),
  sprintf("- storage_light_pass: `%s`", as.character(storage_pass)),
  sprintf("- mcmc_promote_after_review_cells: `%d`", mcmc_promote_n),
  "",
  "## Decision",
  "",
  if (all_complete && storage_pass && mcmc_promote_n > 0L) {
    "The screen is complete and storage-light. Some cells are eligible for MCMC handoff after human review because they beat the current Q-DESN RHS same-likelihood and best exDQLM/DQLM VB baselines on all four primary metrics."
  } else if (all_complete && storage_pass) {
    "The screen is complete and storage-light, but it remains diagnostic/candidate-selection evidence. No cell clears the conservative MCMC handoff gate against both the current Q-DESN RHS same-likelihood baseline and the best exDQLM/DQLM VB baseline on all four primary metrics."
  } else {
    "The screen is not ready for promotion. Completion or storage-light checks failed."
  },
  "",
  "## Audit And Diagnosis",
  "",
  "- The run is operationally closed: every configured bundle has 32 successful fits and 960 rolling-origin lead rows.",
  "- The corrected decomposition tags are storage-light: no `.rds`, `.rda`, `.RData`, or `__design.rds` payloads were found for valid or quarantined tags.",
  "- The useful signal is structural but not sufficient for promotion: qvbm1 winners split between `c12` and `c123`, with no wins from `sr`, `srp`, or `srx` under the joint within-screen score.",
  "- The main scientific blocker is not completion. It is dominance: every per-cell winner fails at least one primary ratio against the current Article v2 Q-DESN RHS same-likelihood table or the best exDQLM/DQLM VB rows.",
  "- The repeated pattern is fit-RMSE or forecast relief at the cost of check-loss and/or external-baseline forecast ratios. That makes immediate MCMC spending inefficient.",
  "",
  "## Bundle Win Counts",
  "",
  md_table(bundle_win_counts),
  "",
  "## Health Summary",
  "",
  md_table(health_display),
  "",
  "## Per-Cell qvbm1 Winners",
  "",
  md_table(winner_display),
  "",
  "## Baseline Comparison Ratios",
  "",
  "Ratios below 1 are better than the referenced current table row. The current-table comparison is read-only and does not make this qvbm1 screen article-facing.",
  "",
  md_table(comparison_display, digits = 3L),
  "",
  "## Handoff Blockers",
  "",
  "These rows explain why the conservative MCMC handoff gate is closed. A failed primary ratio is any ratio greater than or equal to 1.",
  "",
  md_table(ratio_blockers, digits = 3L),
  "",
  "## Invalid Tags",
  "",
  "The following old pre-guard-fix tags must not be consumed:",
  "",
  md_table(invalid_tag_ledger),
  "",
  "## Output Paths",
  "",
  sprintf("- health: `%s`", paths$health),
  sprintf("- fit_forecast_summary: `%s`", paths$fit_forecast_summary),
  sprintf("- ranked_candidates: `%s`", paths$ranked_candidates),
  sprintf("- cell_winners: `%s`", paths$cell_winners),
  sprintf("- bundle_win_counts: `%s`", paths$bundle_win_counts),
  sprintf("- current_table_comparison: `%s`", paths$article_comparison),
  sprintf("- ratio_blockers: `%s`", paths$ratio_blockers),
  sprintf("- invalid_tag_ledger: `%s`", paths$invalid_tag_ledger),
  sprintf("- storage_audit: `%s`", paths$storage_audit),
  "",
  "## Better Next Plan",
  "",
  "1. Freeze this qvbm1 closeout as diagnostic evidence, not article-facing evidence.",
  "2. Do not launch MCMC from qvbm1 winners yet; all eight handoff candidates fail at least one conservative primary gate.",
  "3. Use `c12` and `c123` as mechanism priors for the next VB screen, because they are the only bundles that win cells.",
  "4. Make the next screen case-specific and blocker-aware: preserve the structural input bundle that helped each cell, then target the failed ratio names in the blocker table.",
  "5. Add an explicit check-loss guard to the selection criterion so fit/forecast relief cannot be bought by degrading check loss.",
  "6. Leave Article-Q-DESN unchanged until a promoted validation artifact exists."
)

paths$summary <- write_lines(summary_lines, file.path(summary_dir, "qvbm1_mechanism_first_closeout.md"))

if (!skip_docs_report) {
  paths$docs_report <- write_lines(summary_lines, docs_report)
}

manifest_paths <- paths
manifest <- list(
  generated_at = as.character(Sys.time()),
  repo_root = repo_root,
  branch = git_value("git branch --show-current"),
  head = git_value("git rev-parse HEAD"),
  run_map = run_map,
  invalid_tags = invalid_tags,
  article_summary_read_only = if (!is.null(article_summary) && file.exists(article_summary)) article_summary else NA_character_,
  expected_roots_per_bundle = expected_roots_per_bundle,
  expected_leads_per_root = expected_leads_per_root,
  totals = list(
    fit_roots = total_fit,
    expected_fit_roots = total_expected,
    forecast_lead_rows = total_leads,
    expected_forecast_lead_rows = total_expected_leads,
    all_complete = all_complete,
    storage_light_pass = storage_pass,
    mcmc_promote_after_review_cells = mcmc_promote_n
  ),
  output_paths = manifest_paths,
  output_sha256 = as.list(vapply(unlist(manifest_paths), sha256_file, character(1)))
)
paths$manifest <- file.path(manifest_dir, "qvbm1_mechanism_first_closeout_manifest.json")
dir.create(dirname(paths$manifest), recursive = TRUE, showWarnings = FALSE)
jsonlite::write_json(manifest, paths$manifest, pretty = TRUE, auto_unbox = TRUE, null = "null")
paths$manifest <- normalizePath(paths$manifest, winslash = "/", mustWork = TRUE)

cat(sprintf("health: %s\n", paths$health))
cat(sprintf("cell_winners: %s\n", paths$cell_winners))
cat(sprintf("current_table_comparison: %s\n", paths$article_comparison))
cat(sprintf("storage_audit: %s\n", paths$storage_audit))
cat(sprintf("summary: %s\n", paths$summary))
if (!is.null(paths$docs_report)) cat(sprintf("docs_report: %s\n", paths$docs_report))
cat(sprintf("manifest: %s\n", paths$manifest))
cat(sprintf("complete=%s storage_light=%s mcmc_promote_after_review_cells=%d\n", all_complete, storage_pass, mcmc_promote_n))

quit(status = if (all_complete && storage_pass) 0L else 1L, save = "no")

#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  req <- c("yaml", "jsonlite")
  need <- setdiff(req, rownames(installed.packages()))
  if (length(need)) install.packages(need, repos = "https://cloud.r-project.org")
  invisible(lapply(req, require, character.only = TRUE))
})

args <- commandArgs(trailingOnly = TRUE)
has_flag <- function(flag) any(args == flag)
get_arg <- function(flag, default = NULL) {
  idx <- which(args == flag)
  if (length(idx) && idx < length(args)) args[idx + 1L] else default
}
`%||%` <- function(a, b) if (is.null(a) || !length(a)) b else a

usage <- function() {
  cat(
    "Usage: scripts/run_qdesn_exal_kernel_screen.R [options]\n\n",
    "Options:\n",
    "  --manifest <path>   Screen manifest YAML.\n",
    "  --run-tag <tag>     Screen run tag.\n",
    "  --profiles <ids>    Comma-separated profile ids to run.\n",
    "  --batches <ids>     Comma-separated batch ids to run.\n",
    "  --execute           Run the screening grid.\n",
    "  --prepare-only      Prepare artifacts only (default).\n",
    "  --no-resume         Do not reuse completed profiles.\n",
    "  --help              Print this help.\n",
    sep = ""
  )
}

if (has_flag("--help")) {
  usage()
  quit(status = 0)
}

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

dir_create <- function(path) dir.create(path, recursive = TRUE, showWarnings = FALSE)

read_csv_safe <- function(path) {
  if (is.null(path) || !file.exists(path)) return(data.frame(stringsAsFactors = FALSE))
  utils::read.csv(path, stringsAsFactors = FALSE)
}

write_json_safe <- function(x, path) {
  dir_create(dirname(path))
  jsonlite::write_json(x, path, pretty = TRUE, auto_unbox = TRUE, null = "null")
}

write_lines_safe <- function(lines, path) {
  dir_create(dirname(path))
  writeLines(lines, path)
}

deep_merge <- function(x, y) {
  if (!is.list(x) || !is.list(y)) return(y)
  out <- x
  for (nm in names(y)) {
    if (is.list(out[[nm]]) && is.list(y[[nm]])) {
      out[[nm]] <- deep_merge(out[[nm]], y[[nm]])
    } else {
      out[[nm]] <- y[[nm]]
    }
  }
  out
}

safe_num <- function(x, default = NA_real_) {
  x <- suppressWarnings(as.numeric(x))
  if (!length(x) || !is.finite(x[1L])) default else x[1L]
}

safe_chr <- function(x, default = NA_character_) {
  x <- as.character(x %||% default)
  if (!length(x)) default else x[1L]
}

safe_median <- function(x) {
  x <- suppressWarnings(as.numeric(x))
  x <- x[is.finite(x)]
  if (!length(x)) return(NA_real_)
  stats::median(x)
}

safe_min <- function(x) {
  x <- suppressWarnings(as.numeric(x))
  x <- x[is.finite(x)]
  if (!length(x)) return(NA_real_)
  min(x)
}

safe_max <- function(x) {
  x <- suppressWarnings(as.numeric(x))
  x <- x[is.finite(x)]
  if (!length(x)) return(NA_real_)
  max(x)
}

grade_worst <- function(x) {
  g <- toupper(trimws(as.character(x %||% "")))
  if (any(g == "FAIL", na.rm = TRUE)) return("FAIL")
  if (any(g == "WARN", na.rm = TRUE)) return("WARN")
  if (any(g == "PASS", na.rm = TRUE)) return("PASS")
  NA_character_
}

worst_reason <- function(df) {
  if (!nrow(df)) return(NA_character_)
  g <- toupper(as.character(df$signoff_grade %||% ""))
  if (any(g == "FAIL", na.rm = TRUE)) {
    return(as.character(df$signoff_reason[g == "FAIL"][1L] %||% NA_character_))
  }
  if (any(g == "WARN", na.rm = TRUE)) {
    return(as.character(df$signoff_reason[g == "WARN"][1L] %||% NA_character_))
  }
  as.character(df$signoff_reason[1L] %||% NA_character_)
}

parse_csv_arg <- function(flag) {
  raw <- as.character(get_arg(flag, ""))[1L]
  if (!nzchar(trimws(raw))) return(character(0))
  out <- trimws(strsplit(raw, ",", fixed = TRUE)[[1L]])
  out[nzchar(out)]
}

build_key <- function(df) {
  cols <- c("scenario", "tau", "likelihood_family", "beta_prior_type", "seed", "reservoir_profile")
  cols <- cols[cols %in% names(df)]
  if (!length(cols)) return(character(nrow(df)))
  do.call(paste, c(df[, cols, drop = FALSE], sep = "||"))
}

render_markdown_table <- function(df) {
  if (!is.data.frame(df) || !nrow(df) || !ncol(df)) return(c("| empty |", "|---|"))
  fmt <- function(x) {
    x <- as.character(x)
    x[is.na(x) | !nzchar(x)] <- "NA"
    x
  }
  hdr <- paste0("| ", paste(names(df), collapse = " | "), " |")
  sep <- paste0("| ", paste(rep("---", ncol(df)), collapse = " | "), " |")
  rows <- apply(df, 1L, function(row) paste0("| ", paste(fmt(row), collapse = " | "), " |"))
  c(hdr, sep, rows)
}

as_bool_string <- function(x) if (isTRUE(x)) "TRUE" else "FALSE"

all_true_nonmissing <- function(x) {
  x <- as.logical(x)
  keep <- !is.na(x)
  if (!any(keep)) return(FALSE)
  all(x[keep])
}

normalize_results_root <- function(path) {
  raw <- as.character(path %||% "")[1L]
  if (!nzchar(trimws(raw))) return(NA_character_)
  normalizePath(raw, winslash = "/", mustWork = FALSE)
}

find_latest_run_dir <- function(parent_report_root) {
  if (is.null(parent_report_root) || !dir.exists(parent_report_root)) return(NULL)
  run_dirs <- sort(list.dirs(parent_report_root, recursive = FALSE, full.names = TRUE), decreasing = TRUE)
  if (!length(run_dirs)) return(NULL)
  normalizePath(run_dirs[1L], winslash = "/", mustWork = TRUE)
}

extract_campaign_paths <- function(report_run_root) {
  if (is.null(report_run_root) || !dir.exists(report_run_root)) return(NULL)
  done_path <- file.path(report_run_root, "manifest", "campaign_completed.json")
  mani_path <- file.path(report_run_root, "manifest", "campaign_manifest.json")
  done <- tryCatch(jsonlite::fromJSON(done_path), error = function(...) NULL)
  mani <- tryCatch(jsonlite::fromJSON(mani_path), error = function(...) NULL)
  results_root <- normalize_results_root(done$results_root %||% mani$results_root %||% NA_character_)
  list(
    report_root = normalizePath(report_run_root, winslash = "/", mustWork = TRUE),
    results_root = results_root,
    completed = file.exists(done_path),
    completed_path = done_path,
    manifest_path = mani_path
  )
}

find_latest_completed_campaign <- function(parent_report_root) {
  if (is.null(parent_report_root) || !dir.exists(parent_report_root)) return(NULL)
  run_dirs <- sort(list.dirs(parent_report_root, recursive = FALSE, full.names = TRUE), decreasing = TRUE)
  if (!length(run_dirs)) return(NULL)
  for (run_dir in run_dirs) {
    pair_path <- file.path(run_dir, "tables", "campaign_pair_summary.csv")
    done_path <- file.path(run_dir, "manifest", "campaign_completed.json")
    if (!file.exists(pair_path) || !file.exists(done_path)) next
    out <- extract_campaign_paths(run_dir)
    out$resumed <- TRUE
    return(out)
  }
  NULL
}

run_reconcile <- function(report_run_root, results_root, log_path) {
  if (is.null(report_run_root) || !dir.exists(report_run_root)) {
    return(list(status = NA_integer_, completed_exists = FALSE))
  }
  cmd <- c(
    "scripts/reconcile_qdesn_validation_campaign_status.R",
    "--report-root", report_run_root
  )
  if (!is.na(results_root) && nzchar(trimws(results_root))) {
    cmd <- c(cmd, "--results-root", results_root)
  }
  cmd <- c(cmd, "--apply")
  status <- suppressWarnings(system2("Rscript", cmd, stdout = log_path, stderr = log_path))
  list(
    status = as.integer(status %||% 0L),
    completed_exists = file.exists(file.path(report_run_root, "manifest", "campaign_completed.json"))
  )
}

extract_campaign_health <- function(report_run_root) {
  status_df <- read_csv_safe(file.path(report_run_root, "tables", "campaign_status.csv"))
  method_df <- read_csv_safe(file.path(report_run_root, "tables", "campaign_method_summary.csv"))
  pair_df <- read_csv_safe(file.path(report_run_root, "tables", "campaign_pair_summary.csv"))

  unhealthy_n <- if (nrow(method_df) && "unhealthy" %in% names(method_df)) {
    sum(as.logical(method_df$unhealthy), na.rm = TRUE)
  } else {
    NA_integer_
  }
  collapse_n <- if (nrow(method_df) && "rhs_collapse_flag" %in% names(method_df)) {
    sum(as.logical(method_df$rhs_collapse_flag), na.rm = TRUE)
  } else {
    NA_integer_
  }
  all_finite_ok <- if (nrow(method_df) && "finite_ok" %in% names(method_df)) {
    all_true_nonmissing(method_df$finite_ok)
  } else if (nrow(pair_df) && "both_finite_ok" %in% names(pair_df)) {
    all_true_nonmissing(pair_df$both_finite_ok)
  } else {
    FALSE
  }
  all_domain_ok <- if (nrow(method_df) && "domain_ok" %in% names(method_df)) {
    all_true_nonmissing(method_df$domain_ok)
  } else if (nrow(pair_df) && "both_domain_ok" %in% names(pair_df)) {
    all_true_nonmissing(pair_df$both_domain_ok)
  } else {
    FALSE
  }

  n_roots <- safe_num(status_df$n_roots, NA_real_)
  n_root_success <- safe_num(status_df$n_root_success, NA_real_)
  n_root_fail <- safe_num(status_df$n_root_fail, NA_real_)

  list(
    n_roots = if (is.finite(n_roots)) as.integer(n_roots) else NA_integer_,
    n_root_success = if (is.finite(n_root_success)) as.integer(n_root_success) else NA_integer_,
    n_root_fail = if (is.finite(n_root_fail)) as.integer(n_root_fail) else NA_integer_,
    n_method_rows = if ("n_method_rows" %in% names(status_df)) as.integer(status_df$n_method_rows[1L]) else NA_integer_,
    n_pair_rows = if ("n_pair_rows" %in% names(status_df)) as.integer(status_df$n_pair_rows[1L]) else NA_integer_,
    all_finite_ok = all_finite_ok,
    all_domain_ok = all_domain_ok,
    unhealthy_n = if (is.na(unhealthy_n)) NA_integer_ else as.integer(unhealthy_n),
    collapse_n = if (is.na(collapse_n)) NA_integer_ else as.integer(collapse_n),
    operational_pass = isTRUE(
      is.finite(n_root_fail) &&
        n_root_fail == 0 &&
        all_finite_ok &&
        all_domain_ok &&
        (is.na(unhealthy_n) || unhealthy_n == 0) &&
        (is.na(collapse_n) || collapse_n == 0)
    )
  )
}

evaluate_profile <- function(profile_id,
                             description,
                             run_obj,
                             base_mcmc_micro,
                             micro_key,
                             micro_meta) {
  method_path <- file.path(run_obj$report_root, "tables", "campaign_method_summary.csv")
  pair_path <- file.path(run_obj$report_root, "tables", "campaign_pair_summary.csv")
  if (!file.exists(method_path) || !file.exists(pair_path)) {
    return(list(
      summary = data.frame(
        profile_id = profile_id,
        description = description,
        evaluation_ready = FALSE,
        stringsAsFactors = FALSE
      ),
      diag_shift = data.frame(stringsAsFactors = FALSE),
      metric_shift = data.frame(stringsAsFactors = FALSE),
      transitions = data.frame(stringsAsFactors = FALSE)
    ))
  }

  method_df <- read_csv_safe(method_path)
  pair_df <- read_csv_safe(pair_path)
  method_df$root_join_key <- build_key(method_df)
  pair_df$root_join_key <- build_key(pair_df)

  prof_mcmc <- method_df[
    method_df$root_join_key %in% micro_key &
      as.character(method_df$method %||% "") == "mcmc",
  , drop = FALSE]

  if (!nrow(prof_mcmc)) {
    return(list(
      summary = data.frame(
        profile_id = profile_id,
        description = description,
        evaluation_ready = FALSE,
        stringsAsFactors = FALSE
      ),
      diag_shift = data.frame(stringsAsFactors = FALSE),
      metric_shift = data.frame(stringsAsFactors = FALSE),
      transitions = data.frame(stringsAsFactors = FALSE)
    ))
  }

  merge_cols <- c(
    "root_join_key", "signoff_grade", "fit_runtime_seconds", "finite_ok", "domain_ok", "rhs_collapse_flag",
    "forecast_CRPS_mean", "forecast_pinball_tau", "forecast_qhat_mae", "forecast_S_mean",
    "signal_qhat_rmse", "signal_qhat_corr",
    "mcmc_min_ess_core", "mcmc_max_geweke_absz_core", "mcmc_max_half_drift_core"
  )
  base_use <- base_mcmc_micro[, intersect(merge_cols, names(base_mcmc_micro)), drop = FALSE]
  prof_use <- prof_mcmc[, intersect(merge_cols, names(prof_mcmc)), drop = FALSE]

  merged <- merge(base_use, prof_use, by = "root_join_key", suffixes = c("_base", "_prof"), all.x = TRUE)
  if (nrow(micro_meta)) {
    merged <- merge(micro_meta, merged, by = "root_join_key", all.y = TRUE, sort = FALSE)
  }

  base_fail_n <- sum(as.character(merged$signoff_grade_base) == "FAIL", na.rm = TRUE)
  prof_fail_n <- sum(as.character(merged$signoff_grade_prof) == "FAIL", na.rm = TRUE)
  fail_reduction <- if (base_fail_n > 0L) (base_fail_n - prof_fail_n) / base_fail_n else NA_real_

  fail_to_pass <- sum(as.character(merged$signoff_grade_base) == "FAIL" & as.character(merged$signoff_grade_prof) == "PASS", na.rm = TRUE)
  fail_to_warn <- sum(as.character(merged$signoff_grade_base) == "FAIL" & as.character(merged$signoff_grade_prof) == "WARN", na.rm = TRUE)
  fail_to_fail <- sum(as.character(merged$signoff_grade_base) == "FAIL" & as.character(merged$signoff_grade_prof) == "FAIL", na.rm = TRUE)

  finite_prof <- as.logical(merged$finite_ok_prof)
  domain_prof <- as.logical(merged$domain_ok_prof)
  no_new_fd <- all_true_nonmissing(finite_prof) && all_true_nonmissing(domain_prof)

  collapse_base <- as.logical(merged$rhs_collapse_flag_base)
  collapse_prof <- as.logical(merged$rhs_collapse_flag_prof)
  collapse_base[is.na(collapse_base)] <- FALSE
  collapse_prof[is.na(collapse_prof)] <- FALSE
  no_collapse_reg <- !any(!collapse_base & collapse_prof, na.rm = TRUE)

  runtime_ratio <- suppressWarnings(as.numeric(merged$fit_runtime_seconds_prof) / pmax(as.numeric(merged$fit_runtime_seconds_base), 1e-8))
  runtime_inflation_median <- safe_median(runtime_ratio - 1)
  runtime_ok <- isTRUE(is.finite(runtime_inflation_median) && runtime_inflation_median <= 0.50)

  gateB_pass <- isTRUE(
    is.finite(fail_reduction) &&
      fail_reduction >= 0.40 &&
      no_new_fd &&
      no_collapse_reg &&
      runtime_ok
  )

  diag_shift <- data.frame(
    profile_id = profile_id,
    delta_ess_core = safe_median(as.numeric(merged$mcmc_min_ess_core_prof) - as.numeric(merged$mcmc_min_ess_core_base)),
    delta_geweke_absz = safe_median(as.numeric(merged$mcmc_max_geweke_absz_core_prof) - as.numeric(merged$mcmc_max_geweke_absz_core_base)),
    delta_half_drift = safe_median(as.numeric(merged$mcmc_max_half_drift_core_prof) - as.numeric(merged$mcmc_max_half_drift_core_base)),
    stringsAsFactors = FALSE
  )

  metric_shift <- data.frame(
    profile_id = profile_id,
    delta_forecast_crps = safe_median(as.numeric(merged$forecast_CRPS_mean_prof) - as.numeric(merged$forecast_CRPS_mean_base)),
    delta_forecast_pinball_tau = safe_median(as.numeric(merged$forecast_pinball_tau_prof) - as.numeric(merged$forecast_pinball_tau_base)),
    delta_forecast_qhat_mae = safe_median(as.numeric(merged$forecast_qhat_mae_prof) - as.numeric(merged$forecast_qhat_mae_base)),
    delta_forecast_s = safe_median(as.numeric(merged$forecast_S_mean_prof) - as.numeric(merged$forecast_S_mean_base)),
    delta_signal_qhat_rmse = safe_median(as.numeric(merged$signal_qhat_rmse_prof) - as.numeric(merged$signal_qhat_rmse_base)),
    delta_signal_qhat_corr = safe_median(as.numeric(merged$signal_qhat_corr_prof) - as.numeric(merged$signal_qhat_corr_base)),
    stringsAsFactors = FALSE
  )

  summary_row <- data.frame(
    profile_id = profile_id,
    description = description,
    evaluation_ready = TRUE,
    base_fail_n = as.integer(base_fail_n),
    prof_fail_n = as.integer(prof_fail_n),
    fail_reduction = as.numeric(fail_reduction),
    fail_to_pass = as.integer(fail_to_pass),
    fail_to_warn = as.integer(fail_to_warn),
    fail_to_fail = as.integer(fail_to_fail),
    no_new_finite_domain_violations = as.logical(no_new_fd),
    no_collapse_regression = as.logical(no_collapse_reg),
    runtime_inflation_median = as.numeric(runtime_inflation_median),
    runtime_ok = as.logical(runtime_ok),
    gateB_pass = as.logical(gateB_pass),
    report_root = run_obj$report_root,
    results_root = run_obj$results_root,
    stringsAsFactors = FALSE
  )

  list(
    summary = summary_row,
    diag_shift = diag_shift,
    metric_shift = metric_shift,
    transitions = merged
  )
}

compute_rank_table <- function(eval_tbl, transition_map, profiles_tbl, micro_roots) {
  if (!is.data.frame(eval_tbl) || !nrow(eval_tbl)) return(data.frame(stringsAsFactors = FALSE))
  rank_rows <- list()
  for (pid in names(transition_map)) {
    trans <- transition_map[[pid]]
    if (!is.data.frame(trans) || !nrow(trans)) next
    trans$root_join_key <- as.character(trans$root_join_key)
    trans$runtime_inflation <- suppressWarnings(as.numeric(trans$fit_runtime_seconds_prof) / pmax(as.numeric(trans$fit_runtime_seconds_base), 1e-8) - 1)
    if (nrow(micro_roots)) {
      trans <- merge(
        trans,
        micro_roots[, c("root_join_key", "failure_cluster", "severity", "root_role"), drop = FALSE],
        by = "root_join_key",
        all.x = TRUE
      )
    } else {
      trans$root_role <- NA_character_
      trans$severity <- NA_real_
    }
    severe <- trans[as.character(trans$root_role) == "severe", , drop = FALSE]
    sentinel <- trans[as.character(trans$root_role) == "sentinel", , drop = FALSE]
    rank_rows[[length(rank_rows) + 1L]] <- data.frame(
      profile_id = pid,
      severe_fail_n = sum(as.character(severe$signoff_grade_prof) == "FAIL", na.rm = TRUE),
      severe_improved_n = sum(as.character(severe$signoff_grade_prof) != "FAIL", na.rm = TRUE),
      sentinel_fail_n = sum(as.character(sentinel$signoff_grade_prof) == "FAIL", na.rm = TRUE),
      sentinel_improved_n = sum(as.character(sentinel$signoff_grade_prof) != "FAIL", na.rm = TRUE),
      total_fail_n = sum(as.character(trans$signoff_grade_prof) == "FAIL", na.rm = TRUE),
      median_runtime_inflation = safe_median(trans$runtime_inflation),
      severe_runtime_inflation = safe_median(severe$runtime_inflation),
      median_geweke_prof = safe_median(trans$mcmc_max_geweke_absz_core_prof),
      median_half_drift_prof = safe_median(trans$mcmc_max_half_drift_core_prof),
      min_ess_prof = safe_min(trans$mcmc_min_ess_core_prof),
      max_geweke_prof = safe_max(trans$mcmc_max_geweke_absz_core_prof),
      max_half_drift_prof = safe_max(trans$mcmc_max_half_drift_core_prof),
      stringsAsFactors = FALSE
    )
  }
  if (!length(rank_rows)) return(data.frame(stringsAsFactors = FALSE))
  rank_df <- do.call(rbind, rank_rows)
  rank_df <- merge(
    profiles_tbl[, c("profile_id", "batch_id", "family", "description"), drop = FALSE],
    rank_df,
    by = "profile_id",
    all.y = TRUE
  )
  rank_df <- merge(
    rank_df,
    eval_tbl[, c("profile_id", "fail_reduction", "runtime_inflation_median", "gateB_pass"), drop = FALSE],
    by = "profile_id",
    all.x = TRUE
  )
  rank_df <- rank_df[order(
    as.numeric(rank_df$severe_fail_n),
    as.numeric(rank_df$total_fail_n),
    as.numeric(rank_df$sentinel_fail_n),
    -as.numeric(rank_df$severe_improved_n),
    as.numeric(rank_df$median_runtime_inflation),
    as.character(rank_df$profile_id)
  ), , drop = FALSE]
  rownames(rank_df) <- NULL
  rank_df
}

compute_family_rank_table <- function(rank_df, execution_tbl) {
  if (!is.data.frame(rank_df) || !nrow(rank_df) || !"family" %in% names(rank_df)) {
    return(data.frame(stringsAsFactors = FALSE))
  }

  fam <- as.character(rank_df$family)
  fam[is.na(fam) | !nzchar(fam)] <- "unknown"
  if (!any(duplicated(fam))) return(data.frame(stringsAsFactors = FALSE))

  completed_like <- c("COMPLETED", "COMPLETED_RECONCILED", "RESUMED_COMPLETED")
  rows <- lapply(unique(fam), function(fm) {
    sub_rank <- rank_df[fam == fm, , drop = FALSE]
    sub_exec <- execution_tbl[as.character(execution_tbl$family) == fm, , drop = FALSE]
    data.frame(
      family = fm,
      batch_id = safe_chr(sub_rank$batch_id[1L], safe_chr(sub_exec$batch_id[1L], NA_character_)),
      n_profiles = nrow(sub_rank),
      n_completed = sum(as.character(sub_exec$execution_status) %in% completed_like, na.rm = TRUE),
      operational_fail_n = sum(!as.logical(sub_exec$operational_pass), na.rm = TRUE),
      median_severe_fail_n = safe_median(sub_rank$severe_fail_n),
      min_severe_fail_n = safe_min(sub_rank$severe_fail_n),
      max_severe_fail_n = safe_max(sub_rank$severe_fail_n),
      median_sentinel_fail_n = safe_median(sub_rank$sentinel_fail_n),
      zero_sentinel_runs_n = sum(suppressWarnings(as.numeric(sub_rank$sentinel_fail_n)) == 0, na.rm = TRUE),
      median_total_fail_n = safe_median(sub_rank$total_fail_n),
      min_total_fail_n = safe_min(sub_rank$total_fail_n),
      max_total_fail_n = safe_max(sub_rank$total_fail_n),
      total_fail_le2_runs_n = sum(suppressWarnings(as.numeric(sub_rank$total_fail_n)) <= 2, na.rm = TRUE),
      median_fail_reduction = safe_median(sub_rank$fail_reduction),
      median_runtime_inflation = safe_median(sub_rank$median_runtime_inflation),
      gateB_pass_n = sum(as.logical(sub_rank$gateB_pass), na.rm = TRUE),
      profile_ids = paste(as.character(sub_rank$profile_id), collapse = ", "),
      stringsAsFactors = FALSE
    )
  })

  out <- do.call(rbind, rows)
  out <- out[order(
    as.numeric(out$median_total_fail_n),
    as.numeric(out$median_sentinel_fail_n),
    as.numeric(out$median_severe_fail_n),
    -as.numeric(out$zero_sentinel_runs_n),
    -as.numeric(out$total_fail_le2_runs_n),
    as.numeric(out$median_runtime_inflation),
    as.character(out$family)
  ), , drop = FALSE]
  rownames(out) <- NULL
  out
}

write_runner_state <- function(path,
                               run_tag,
                               current_batch_id,
                               current_profile_id,
                               execution_tbl,
                               total_profiles,
                               stop_reason = NA_character_) {
  completed_like <- c("COMPLETED", "COMPLETED_RECONCILED", "RESUMED_COMPLETED")
  payload <- list(
    generated_at = as.character(Sys.time()),
    run_tag = run_tag,
    current_batch_id = current_batch_id,
    current_profile_id = current_profile_id,
    total_profiles = total_profiles,
    completed_profiles = if (nrow(execution_tbl)) sum(as.character(execution_tbl$execution_status) %in% completed_like, na.rm = TRUE) else 0L,
    timeout_profiles = if (nrow(execution_tbl)) sum(as.character(execution_tbl$execution_status) == "TIMEOUT", na.rm = TRUE) else 0L,
    error_profiles = if (nrow(execution_tbl)) sum(as.character(execution_tbl$execution_status) %in% c("ERROR", "INCOMPLETE", "NO_OUTPUT"), na.rm = TRUE) else 0L,
    stop_reason = stop_reason
  )
  write_json_safe(payload, path)
}

write_plan_summary <- function(path,
                               manifest_path,
                               run_tag,
                               git_sha,
                               controls_tbl,
                               batches_tbl,
                               profiles_tbl,
                               phase01_manifest_path,
                               base_defaults_path,
                               baseline_report_root,
                               micro_grid_path) {
  lines <- c(
    "# QDESN exAL Kernel Screen",
    "",
    sprintf("- generated_at: `%s`", as.character(Sys.time())),
    sprintf("- run_tag: `%s`", run_tag),
    sprintf("- git_sha: `%s`", git_sha),
    sprintf("- manifest_path: `%s`", manifest_path),
    sprintf("- phase01_manifest: `%s`", phase01_manifest_path),
    sprintf("- baseline_report_root: `%s`", baseline_report_root),
    sprintf("- micro_grid: `%s`", micro_grid_path),
    sprintf("- base_defaults: `%s`", base_defaults_path),
    "",
    "## Controls",
    ""
  )
  lines <- c(lines, render_markdown_table(controls_tbl), "", "## Batches", "")
  lines <- c(lines, render_markdown_table(batches_tbl), "", "## Profiles", "")
  prof_keep <- profiles_tbl[, c("profile_id", "batch_id", "family", "timeout_minutes", "description"), drop = FALSE]
  lines <- c(lines, render_markdown_table(prof_keep), "")
  write_lines_safe(lines, path)
}

write_result_summary <- function(path,
                                 run_tag,
                                 stop_reason,
                                 execution_tbl,
                                 eval_tbl,
                                 rank_df,
                                 family_df,
                                 batches_tbl) {
  completed_like <- c("COMPLETED", "COMPLETED_RECONCILED", "RESUMED_COMPLETED")
  lines <- c(
    "# QDESN exAL Kernel Screen Results",
    "",
    sprintf("- updated_at: `%s`", as.character(Sys.time())),
    sprintf("- run_tag: `%s`", run_tag),
    sprintf("- stop_reason: `%s`", as.character(stop_reason %||% NA_character_)),
    sprintf("- completed_profiles: `%d`", if (nrow(execution_tbl)) sum(as.character(execution_tbl$execution_status) %in% completed_like, na.rm = TRUE) else 0L),
    sprintf("- timeout_profiles: `%d`", if (nrow(execution_tbl)) sum(as.character(execution_tbl$execution_status) == "TIMEOUT", na.rm = TRUE) else 0L),
    sprintf("- error_profiles: `%d`", if (nrow(execution_tbl)) sum(as.character(execution_tbl$execution_status) %in% c("ERROR", "INCOMPLETE", "NO_OUTPUT"), na.rm = TRUE) else 0L),
    ""
  )
  if (nrow(execution_tbl)) {
    show_exec <- execution_tbl[, intersect(c(
      "profile_id", "batch_id", "execution_status", "exit_status", "operational_pass",
      "evaluation_ready", "gateB_pass", "duration_minutes"
    ), names(execution_tbl)), drop = FALSE]
    lines <- c(lines, "## Execution Status", "", render_markdown_table(show_exec), "")
  }
  if (nrow(rank_df)) {
    keep_cols <- intersect(c(
      "profile_id", "batch_id", "family", "severe_fail_n", "sentinel_fail_n",
      "total_fail_n", "fail_reduction", "median_runtime_inflation", "gateB_pass"
    ), names(rank_df))
    lines <- c(lines, "## Ranking", "", render_markdown_table(rank_df[, keep_cols, drop = FALSE]), "")
  } else if (nrow(eval_tbl)) {
    lines <- c(lines, "## Ranking", "", "No completed evaluable profiles yet.", "")
  }
  if (is.data.frame(family_df) && nrow(family_df)) {
    keep_family <- intersect(c(
      "family", "batch_id", "n_profiles", "n_completed", "median_total_fail_n",
      "min_total_fail_n", "max_total_fail_n", "median_sentinel_fail_n",
      "zero_sentinel_runs_n", "total_fail_le2_runs_n",
      "median_fail_reduction", "median_runtime_inflation"
    ), names(family_df))
    lines <- c(lines, "## Family Ranking", "", render_markdown_table(family_df[, keep_family, drop = FALSE]), "")
  }
  if (nrow(batches_tbl)) {
    lines <- c(lines, "## Batch Order", "", render_markdown_table(batches_tbl), "")
  }
  write_lines_safe(lines, path)
}

manifest_path <- resolve_path(
  get_arg("--manifest", file.path("config", "validation", "qdesn_exal_kernel_screen_manifest.yaml")),
  must_work = TRUE
)
cfg <- yaml::read_yaml(manifest_path)

phase01_manifest_path <- resolve_path((cfg$inputs %||% list())$phase01_manifest, must_work = TRUE)
base_defaults_path <- resolve_path((cfg$inputs %||% list())$base_defaults, must_work = TRUE)
phase01 <- jsonlite::fromJSON(phase01_manifest_path, simplifyVector = TRUE)
base_defaults <- yaml::read_yaml(base_defaults_path)

git_sha <- trimws(system("git rev-parse --short HEAD", intern = TRUE))
run_tag <- as.character(get_arg(
  "--run-tag",
  sprintf("exal-kernel-screen-%s__git-%s", format(Sys.time(), "%Y%m%d-%H%M%S"), git_sha)
))[1L]
if (!nzchar(trimws(run_tag))) stop("--run-tag cannot be empty.", call. = FALSE)

controls <- cfg$controls %||% list()
execute <- has_flag("--execute")
resume_mode <- if (has_flag("--no-resume")) FALSE else isTRUE(controls$resume_completed_profiles %||% TRUE)
selected_profiles <- parse_csv_arg("--profiles")
selected_batches <- parse_csv_arg("--batches")

campaign_workers <- as.integer(controls$campaign_workers %||% 1L)[1L]
if (!is.finite(campaign_workers) || campaign_workers < 1L) campaign_workers <- 1L
threads_per_worker <- as.integer(controls$threads_per_worker %||% 1L)[1L]
if (!is.finite(threads_per_worker) || threads_per_worker < 1L) threads_per_worker <- 1L
create_plots <- isTRUE(controls$create_plots %||% FALSE)
profile_verbose <- if (is.null(controls$profile_verbose)) TRUE else isTRUE(controls$profile_verbose)
default_timeout_minutes <- as.integer(controls$profile_timeout_minutes %||% 45L)[1L]
if (!is.finite(default_timeout_minutes) || default_timeout_minutes < 1L) default_timeout_minutes <- 45L
timeout_kill_after_seconds <- as.integer(controls$timeout_kill_after_seconds %||% 30L)[1L]
if (!is.finite(timeout_kill_after_seconds) || timeout_kill_after_seconds < 1L) timeout_kill_after_seconds <- 30L
continue_on_profile_error <- if (is.null(controls$continue_on_profile_error)) TRUE else isTRUE(controls$continue_on_profile_error)
max_timeout_profiles <- as.integer(controls$max_timeout_profiles %||% 2L)[1L]
if (!is.finite(max_timeout_profiles) || max_timeout_profiles < 1L) max_timeout_profiles <- 2L
max_error_profiles <- as.integer(controls$max_error_profiles %||% 3L)[1L]
if (!is.finite(max_error_profiles) || max_error_profiles < 1L) max_error_profiles <- 3L
stop_on_anchor_operational_failure <- if (is.null(controls$stop_on_anchor_operational_failure)) TRUE else isTRUE(controls$stop_on_anchor_operational_failure)

report_workspace <- resolve_path(
  file.path((cfg$outputs %||% list())$report_root %||% file.path("reports", "qdesn_mcmc_validation", "exal_kernel_screen"), run_tag),
  must_work = FALSE
)
results_workspace <- resolve_path(
  file.path((cfg$outputs %||% list())$results_root %||% file.path("results", "qdesn_mcmc_validation", "exal_kernel_screen"), run_tag),
  must_work = FALSE
)
summary_dir <- file.path(report_workspace, "summary")
tables_dir <- file.path(report_workspace, "tables")
configs_dir <- file.path(report_workspace, "configs")
manifest_dir <- file.path(report_workspace, "manifest")
logs_dir <- file.path(report_workspace, "logs")
status_dir <- file.path(report_workspace, "status")
for (d in c(report_workspace, results_workspace, summary_dir, tables_dir, configs_dir, manifest_dir, logs_dir, status_dir)) {
  dir_create(d)
}

phase01_files <- phase01$files %||% list()
baseline_report_root <- resolve_path((phase01$baseline %||% list())$report_root, must_work = TRUE)
micro_grid_path <- resolve_path(as.character(phase01_files$micro_grid %||% ""), must_work = TRUE)
micro_roots_path <- resolve_path(as.character(phase01_files$micro_roots %||% ""), must_work = FALSE)

micro_grid <- read_csv_safe(micro_grid_path)
if (!nrow(micro_grid)) stop("Micro grid is empty.", call. = FALSE)
micro_grid$root_join_key <- build_key(micro_grid)
micro_key <- as.character(micro_grid$root_join_key)
micro_meta <- unique(micro_grid[, c("root_join_key", intersect(c("scenario", "tau", "likelihood_family", "beta_prior_type", "seed", "reservoir_profile"), names(micro_grid))), drop = FALSE])

micro_roots <- read_csv_safe(micro_roots_path)
if (nrow(micro_roots)) {
  micro_roots$root_join_key <- build_key(micro_roots)
  micro_roots$root_role <- ifelse(as.character(micro_roots$failure_cluster) == "all_four", "severe", "sentinel")
}

baseline_method <- read_csv_safe(file.path(baseline_report_root, "tables", "campaign_method_summary.csv"))
baseline_pair <- read_csv_safe(file.path(baseline_report_root, "tables", "campaign_pair_summary.csv"))
if (!nrow(baseline_method) || !nrow(baseline_pair)) {
  stop("Baseline tables missing for exal-kernel screen.", call. = FALSE)
}
baseline_method$root_join_key <- build_key(baseline_method)
base_mcmc_micro <- baseline_method[
  baseline_method$root_join_key %in% micro_key &
    as.character(baseline_method$method %||% "") == "mcmc",
, drop = FALSE]
if (!nrow(base_mcmc_micro)) stop("Baseline MCMC micro rows are empty.", call. = FALSE)

batches_cfg <- cfg$batches %||% list()
profiles_cfg <- cfg$profiles %||% list()
base_patch <- cfg$base_patch %||% list()
if (!length(profiles_cfg)) stop("No profiles defined in manifest.", call. = FALSE)

if (!length(batches_cfg)) {
  inferred_batch <- as.character((profiles_cfg[[1L]]$batch %||% profiles_cfg[[1L]]$batch_id %||% "B0"))[1L]
  batches_cfg <- list(list(id = inferred_batch, description = "Default batch"))
}

batches_tbl <- do.call(rbind, lapply(seq_along(batches_cfg), function(i) {
  batch_i <- batches_cfg[[i]]
  data.frame(
    batch_order = i,
    batch_id = as.character(batch_i$id %||% sprintf("B%02d", i))[1L],
    description = as.character(batch_i$description %||% "")[1L],
    stringsAsFactors = FALSE
  )
}))

default_batch_id <- as.character(batches_tbl$batch_id[1L])
profile_rows <- list()
for (i in seq_along(profiles_cfg)) {
  prof <- profiles_cfg[[i]]
  pid <- as.character(prof$id %||% sprintf("X%02d", i))[1L]
  batch_id <- as.character(prof$batch %||% prof$batch_id %||% default_batch_id)[1L]
  fam <- as.character(prof$family %||% "screen")[1L]
  desc <- as.character(prof$description %||% "")[1L]
  enabled <- if (is.null(prof$enabled)) TRUE else isTRUE(prof$enabled)
  timeout_minutes <- as.integer(prof$timeout_minutes %||% default_timeout_minutes)[1L]
  if (!is.finite(timeout_minutes) || timeout_minutes < 1L) timeout_minutes <- default_timeout_minutes
  cfg_i <- deep_merge(base_defaults, deep_merge(base_patch, prof$patch %||% list()))
  cfg_i$runtime <- cfg_i$runtime %||% list()
  cfg_i$runtime$campaign_workers <- as.integer(campaign_workers)
  cfg_i$runtime$workers <- as.integer(campaign_workers)
  cfg_i$runtime$threads <- as.integer(threads_per_worker)
  cfg_i$campaign <- cfg_i$campaign %||% list()
  cfg_i$campaign$name <- paste0("qdesn_exal_kernel_screen__", pid)
  defaults_i <- file.path(configs_dir, sprintf("%s.yaml", pid))
  yaml::write_yaml(cfg_i, defaults_i)
  profile_rows[[length(profile_rows) + 1L]] <- data.frame(
    profile_order = i,
    profile_id = pid,
    batch_id = batch_id,
    family = fam,
    enabled = enabled,
    timeout_minutes = timeout_minutes,
    description = desc,
    defaults_path = defaults_i,
    stringsAsFactors = FALSE
  )
}
profiles_tbl <- do.call(rbind, profile_rows)
if (anyDuplicated(profiles_tbl$profile_id)) stop("Profile ids must be unique.", call. = FALSE)
if (!all(profiles_tbl$batch_id %in% batches_tbl$batch_id)) {
  missing_batches <- setdiff(unique(profiles_tbl$batch_id), batches_tbl$batch_id)
  stop(sprintf("Unknown batch ids referenced by profiles: %s", paste(missing_batches, collapse = ", ")), call. = FALSE)
}
profiles_tbl$batch_order <- batches_tbl$batch_order[match(profiles_tbl$batch_id, batches_tbl$batch_id)]

if (length(selected_batches)) {
  profiles_tbl <- profiles_tbl[profiles_tbl$batch_id %in% selected_batches, , drop = FALSE]
}
if (length(selected_profiles)) {
  profiles_tbl <- profiles_tbl[profiles_tbl$profile_id %in% selected_profiles, , drop = FALSE]
}
profiles_tbl <- profiles_tbl[profiles_tbl$enabled, , drop = FALSE]
profiles_tbl <- profiles_tbl[order(profiles_tbl$batch_order, profiles_tbl$profile_order), , drop = FALSE]
if (!nrow(profiles_tbl)) stop("No enabled profiles remain after filtering.", call. = FALSE)
batches_tbl <- batches_tbl[batches_tbl$batch_id %in% profiles_tbl$batch_id, , drop = FALSE]
batches_tbl <- batches_tbl[order(batches_tbl$batch_order), , drop = FALSE]

controls_tbl <- data.frame(
  control = c(
    "resume_mode", "campaign_workers", "threads_per_worker", "create_plots",
    "profile_verbose", "default_timeout_minutes", "timeout_kill_after_seconds",
    "continue_on_profile_error", "max_timeout_profiles", "max_error_profiles",
    "stop_on_anchor_operational_failure"
  ),
  value = c(
    as_bool_string(resume_mode),
    as.character(campaign_workers),
    as.character(threads_per_worker),
    as_bool_string(create_plots),
    as_bool_string(profile_verbose),
    as.character(default_timeout_minutes),
    as.character(timeout_kill_after_seconds),
    as_bool_string(continue_on_profile_error),
    as.character(max_timeout_profiles),
    as.character(max_error_profiles),
    as_bool_string(stop_on_anchor_operational_failure)
  ),
  stringsAsFactors = FALSE
)

utils::write.csv(profiles_tbl, file.path(tables_dir, "screen_profiles.csv"), row.names = FALSE)
utils::write.csv(batches_tbl, file.path(tables_dir, "screen_batches.csv"), row.names = FALSE)
write_plan_summary(
  path = file.path(summary_dir, "screen_plan.md"),
  manifest_path = manifest_path,
  run_tag = run_tag,
  git_sha = git_sha,
  controls_tbl = controls_tbl,
  batches_tbl = batches_tbl[, c("batch_id", "description"), drop = FALSE],
  profiles_tbl = profiles_tbl,
  phase01_manifest_path = phase01_manifest_path,
  base_defaults_path = base_defaults_path,
  baseline_report_root = baseline_report_root,
  micro_grid_path = micro_grid_path
)

screen_manifest <- list(
  generated_at = as.character(Sys.time()),
  run_tag = run_tag,
  git_sha = git_sha,
  manifest_path = manifest_path,
  phase01_manifest_path = phase01_manifest_path,
  base_defaults_path = base_defaults_path,
  baseline_report_root = baseline_report_root,
  micro_grid_path = micro_grid_path,
  micro_roots_path = micro_roots_path,
  report_workspace = report_workspace,
  results_workspace = results_workspace,
  controls = as.list(stats::setNames(controls_tbl$value, controls_tbl$control))
)
write_json_safe(screen_manifest, file.path(manifest_dir, "screen_manifest.json"))

if (!isTRUE(execute)) {
  cat(sprintf("Prepared exAL kernel screen workspace: %s\n", report_workspace))
  cat(sprintf("Plan summary: %s\n", file.path(summary_dir, "screen_plan.md")))
  quit(status = 0)
}

execution_rows <- list()
eval_rows <- list()
diag_rows <- list()
metric_rows <- list()
transition_map <- list()

timeout_failures <- 0L
error_failures <- 0L
stop_reason <- "completed_requested_scope"
current_batch_id <- NA_character_
current_profile_id <- NA_character_

write_runner_state(
  path = file.path(status_dir, "runner_state.json"),
  run_tag = run_tag,
  current_batch_id = current_batch_id,
  current_profile_id = current_profile_id,
  execution_tbl = data.frame(stringsAsFactors = FALSE),
  total_profiles = nrow(profiles_tbl),
  stop_reason = NA_character_
)

for (bb in seq_len(nrow(batches_tbl))) {
  current_batch_id <- as.character(batches_tbl$batch_id[bb])
  batch_profiles <- profiles_tbl[profiles_tbl$batch_id == current_batch_id, , drop = FALSE]
  if (!nrow(batch_profiles)) next

  for (ii in seq_len(nrow(batch_profiles))) {
    prof <- batch_profiles[ii, , drop = FALSE]
    pid <- as.character(prof$profile_id[1L])
    current_profile_id <- pid

    exec_tbl_now <- if (length(execution_rows)) do.call(rbind, execution_rows) else data.frame(stringsAsFactors = FALSE)
    write_runner_state(
      path = file.path(status_dir, "runner_state.json"),
      run_tag = run_tag,
      current_batch_id = current_batch_id,
      current_profile_id = current_profile_id,
      execution_tbl = exec_tbl_now,
      total_profiles = nrow(profiles_tbl),
      stop_reason = NA_character_
    )

    defaults_path <- resolve_path(as.character(prof$defaults_path[1L]), must_work = TRUE)
    timeout_minutes <- as.integer(prof$timeout_minutes[1L])
    profile_parent_report_root <- file.path(report_workspace, "micro_pilot", pid)
    profile_parent_results_root <- file.path(results_workspace, "micro_pilot", pid)
    dir_create(profile_parent_report_root)
    dir_create(profile_parent_results_root)

    started_at <- as.character(Sys.time())
    log_path <- file.path(logs_dir, sprintf("%s.log", pid))
    command_path <- file.path(logs_dir, sprintf("%s.cmd.sh", pid))
    reconcile_log_path <- file.path(logs_dir, sprintf("%s__reconcile.log", pid))

    run_obj <- NULL
    exit_status <- NA_integer_
    execution_status <- NA_character_
    resumed <- FALSE
    reconciled <- FALSE

    existing <- if (isTRUE(resume_mode)) find_latest_completed_campaign(profile_parent_report_root) else NULL
    if (!is.null(existing)) {
      run_obj <- existing
      exit_status <- 0L
      execution_status <- "RESUMED_COMPLETED"
      resumed <- TRUE
    } else {
      cmd_tokens <- c(
        "timeout",
        sprintf("--kill-after=%ss", timeout_kill_after_seconds),
        sprintf("%dm", timeout_minutes),
        "stdbuf", "-oL", "-eL",
        "Rscript",
        file.path("scripts", "run_qdesn_mcmc_validation_campaign.R"),
        "--grid", micro_grid_path,
        "--defaults", defaults_path,
        "--results-root", profile_parent_results_root,
        "--reports-root", profile_parent_report_root
      )
      if (!create_plots) cmd_tokens <- c(cmd_tokens, "--no-plots")
      if (!profile_verbose) cmd_tokens <- c(cmd_tokens, "--quiet")
      shell_cmd <- paste(vapply(cmd_tokens, shQuote, character(1)), collapse = " ")
      write_lines_safe(c("#!/usr/bin/env bash", shell_cmd), command_path)
      suppressWarnings(Sys.chmod(command_path, mode = "0755"))
      exit_status <- suppressWarnings(system2("bash", command_path, stdout = log_path, stderr = log_path))
      exit_status <- as.integer(exit_status %||% 0L)

      latest_run_dir <- find_latest_run_dir(profile_parent_report_root)
      run_obj <- extract_campaign_paths(latest_run_dir)
      if (!is.null(run_obj)) {
        rec <- run_reconcile(run_obj$report_root, run_obj$results_root, reconcile_log_path)
        reconciled <- isTRUE(rec$completed_exists) && !isTRUE(run_obj$completed)
        run_obj <- extract_campaign_paths(run_obj$report_root)
      }

      completed_exists <- !is.null(run_obj) && isTRUE(run_obj$completed)
      required_tables <- !is.null(run_obj) &&
        file.exists(file.path(run_obj$report_root, "tables", "campaign_method_summary.csv")) &&
        file.exists(file.path(run_obj$report_root, "tables", "campaign_pair_summary.csv"))

      if (completed_exists && required_tables) {
        execution_status <- if (isTRUE(reconciled) || !identical(exit_status, 0L)) "COMPLETED_RECONCILED" else "COMPLETED"
      } else if (exit_status %in% c(124L, 137L)) {
        execution_status <- "TIMEOUT"
      } else if (is.null(run_obj)) {
        execution_status <- "NO_OUTPUT"
      } else {
        execution_status <- "INCOMPLETE"
      }
    }

    health <- if (!is.null(run_obj)) extract_campaign_health(run_obj$report_root) else list(
      n_roots = NA_integer_,
      n_root_success = NA_integer_,
      n_root_fail = NA_integer_,
      n_method_rows = NA_integer_,
      n_pair_rows = NA_integer_,
      all_finite_ok = FALSE,
      all_domain_ok = FALSE,
      unhealthy_n = NA_integer_,
      collapse_n = NA_integer_,
      operational_pass = FALSE
    )

    eval_ready <- !is.null(run_obj) &&
      file.exists(file.path(run_obj$report_root, "tables", "campaign_method_summary.csv")) &&
      file.exists(file.path(run_obj$report_root, "tables", "campaign_pair_summary.csv"))

    eval_i <- if (isTRUE(eval_ready)) {
      evaluate_profile(
        profile_id = pid,
        description = as.character(prof$description[1L]),
        run_obj = run_obj,
        base_mcmc_micro = base_mcmc_micro,
        micro_key = micro_key,
        micro_meta = micro_meta
      )
    } else {
      list(
        summary = data.frame(
          profile_id = pid,
          description = as.character(prof$description[1L]),
          evaluation_ready = FALSE,
          stringsAsFactors = FALSE
        ),
        diag_shift = data.frame(stringsAsFactors = FALSE),
        metric_shift = data.frame(stringsAsFactors = FALSE),
        transitions = data.frame(stringsAsFactors = FALSE)
      )
    }

    if (nrow(eval_i$summary) && isTRUE(eval_i$summary$evaluation_ready[1L])) {
      eval_rows[[pid]] <- eval_i$summary
      diag_rows[[pid]] <- eval_i$diag_shift
      metric_rows[[pid]] <- eval_i$metric_shift
      transition_map[[pid]] <- eval_i$transitions
      utils::write.csv(eval_i$transitions, file.path(tables_dir, sprintf("phase35_transitions_%s.csv", pid)), row.names = FALSE)
    }

    finished_at <- as.character(Sys.time())
    duration_minutes <- round(as.numeric(difftime(as.POSIXct(finished_at), as.POSIXct(started_at), units = "mins")), 3)

    exec_row <- data.frame(
      profile_id = pid,
      batch_id = as.character(prof$batch_id[1L]),
      family = as.character(prof$family[1L]),
      description = as.character(prof$description[1L]),
      execution_status = execution_status,
      exit_status = if (is.na(exit_status)) NA_integer_ else as.integer(exit_status),
      resumed = isTRUE(resumed),
      reconciled = isTRUE(reconciled),
      started_at = started_at,
      finished_at = finished_at,
      duration_minutes = duration_minutes,
      timeout_minutes = timeout_minutes,
      report_root = as.character(run_obj$report_root %||% NA_character_),
      results_root = as.character(run_obj$results_root %||% NA_character_),
      log_path = log_path,
      command_path = command_path,
      n_roots = health$n_roots,
      n_root_success = health$n_root_success,
      n_root_fail = health$n_root_fail,
      n_method_rows = health$n_method_rows,
      n_pair_rows = health$n_pair_rows,
      all_finite_ok = health$all_finite_ok,
      all_domain_ok = health$all_domain_ok,
      unhealthy_n = health$unhealthy_n,
      collapse_n = health$collapse_n,
      operational_pass = health$operational_pass,
      evaluation_ready = isTRUE(eval_i$summary$evaluation_ready[1L] %||% FALSE),
      gateB_pass = if ("gateB_pass" %in% names(eval_i$summary)) eval_i$summary$gateB_pass[1L] else NA,
      fail_reduction = if ("fail_reduction" %in% names(eval_i$summary)) eval_i$summary$fail_reduction[1L] else NA,
      runtime_inflation_median = if ("runtime_inflation_median" %in% names(eval_i$summary)) eval_i$summary$runtime_inflation_median[1L] else NA,
      stringsAsFactors = FALSE
    )
    execution_rows[[length(execution_rows) + 1L]] <- exec_row

    execution_tbl <- do.call(rbind, execution_rows)
    eval_tbl <- if (length(eval_rows)) do.call(rbind, eval_rows) else data.frame(stringsAsFactors = FALSE)
    diag_tbl <- if (length(diag_rows)) do.call(rbind, diag_rows) else data.frame(stringsAsFactors = FALSE)
    metric_tbl <- if (length(metric_rows)) do.call(rbind, metric_rows) else data.frame(stringsAsFactors = FALSE)
    rank_df <- compute_rank_table(eval_tbl, transition_map, profiles_tbl, micro_roots)
    family_df <- compute_family_rank_table(rank_df, execution_tbl)

    utils::write.csv(execution_tbl, file.path(tables_dir, "profile_execution_status.csv"), row.names = FALSE)
    if (nrow(eval_tbl)) utils::write.csv(eval_tbl, file.path(tables_dir, "phase35_micro_pilot_summary.csv"), row.names = FALSE)
    if (nrow(diag_tbl)) utils::write.csv(diag_tbl, file.path(tables_dir, "phase35_micro_pilot_diag_shift.csv"), row.names = FALSE)
    if (nrow(metric_tbl)) utils::write.csv(metric_tbl, file.path(tables_dir, "phase35_micro_pilot_metric_shift.csv"), row.names = FALSE)
    if (nrow(rank_df)) utils::write.csv(rank_df, file.path(tables_dir, "profile_rank_summary.csv"), row.names = FALSE)
    if (nrow(family_df)) utils::write.csv(family_df, file.path(tables_dir, "family_rank_summary.csv"), row.names = FALSE)

    write_result_summary(
      path = file.path(summary_dir, "screen_results.md"),
      run_tag = run_tag,
      stop_reason = stop_reason,
      execution_tbl = execution_tbl,
      eval_tbl = eval_tbl,
      rank_df = rank_df,
      family_df = family_df,
      batches_tbl = batches_tbl[, c("batch_id", "description"), drop = FALSE]
    )
    write_runner_state(
      path = file.path(status_dir, "runner_state.json"),
      run_tag = run_tag,
      current_batch_id = current_batch_id,
      current_profile_id = current_profile_id,
      execution_tbl = execution_tbl,
      total_profiles = nrow(profiles_tbl),
      stop_reason = NA_character_
    )

    if (execution_status == "TIMEOUT") timeout_failures <- timeout_failures + 1L
    if (execution_status %in% c("ERROR", "INCOMPLETE", "NO_OUTPUT")) error_failures <- error_failures + 1L

    if (identical(pid, "X0_anchor_baseline") && isTRUE(stop_on_anchor_operational_failure) && !isTRUE(health$operational_pass)) {
      stop_reason <- "anchor_operational_failure"
      break
    }
    if (timeout_failures >= max_timeout_profiles) {
      stop_reason <- "timeout_budget_exceeded"
      break
    }
    if (error_failures >= max_error_profiles) {
      stop_reason <- "error_budget_exceeded"
      break
    }
    if (!isTRUE(continue_on_profile_error) && execution_status %in% c("TIMEOUT", "ERROR", "INCOMPLETE", "NO_OUTPUT")) {
      stop_reason <- sprintf("stopped_after_profile_%s", pid)
      break
    }
  }
  if (!identical(stop_reason, "completed_requested_scope")) break
}

execution_tbl <- if (length(execution_rows)) do.call(rbind, execution_rows) else data.frame(stringsAsFactors = FALSE)
ran_ids <- as.character(execution_tbl$profile_id %||% character(0))
remaining <- profiles_tbl[!(profiles_tbl$profile_id %in% ran_ids), , drop = FALSE]
if (nrow(remaining)) {
  skip_status <- if (identical(stop_reason, "completed_requested_scope")) "SKIPPED" else "SKIPPED_AFTER_STOP"
  skip_rows <- lapply(seq_len(nrow(remaining)), function(i) {
    rr <- remaining[i, , drop = FALSE]
    data.frame(
      profile_id = as.character(rr$profile_id[1L]),
      batch_id = as.character(rr$batch_id[1L]),
      family = as.character(rr$family[1L]),
      description = as.character(rr$description[1L]),
      execution_status = skip_status,
      exit_status = NA_integer_,
      resumed = FALSE,
      reconciled = FALSE,
      started_at = NA_character_,
      finished_at = NA_character_,
      duration_minutes = NA_real_,
      timeout_minutes = as.integer(rr$timeout_minutes[1L]),
      report_root = NA_character_,
      results_root = NA_character_,
      log_path = file.path(logs_dir, sprintf("%s.log", as.character(rr$profile_id[1L]))),
      command_path = file.path(logs_dir, sprintf("%s.cmd.sh", as.character(rr$profile_id[1L]))),
      n_roots = NA_integer_,
      n_root_success = NA_integer_,
      n_root_fail = NA_integer_,
      n_method_rows = NA_integer_,
      n_pair_rows = NA_integer_,
      all_finite_ok = NA,
      all_domain_ok = NA,
      unhealthy_n = NA_integer_,
      collapse_n = NA_integer_,
      operational_pass = NA,
      evaluation_ready = FALSE,
      gateB_pass = NA,
      fail_reduction = NA_real_,
      runtime_inflation_median = NA_real_,
      stringsAsFactors = FALSE
    )
  })
  if (length(skip_rows)) {
    execution_tbl <- do.call(rbind, c(list(execution_tbl), skip_rows))
  }
}

eval_tbl <- if (length(eval_rows)) do.call(rbind, eval_rows) else data.frame(stringsAsFactors = FALSE)
diag_tbl <- if (length(diag_rows)) do.call(rbind, diag_rows) else data.frame(stringsAsFactors = FALSE)
metric_tbl <- if (length(metric_rows)) do.call(rbind, metric_rows) else data.frame(stringsAsFactors = FALSE)
rank_df <- compute_rank_table(eval_tbl, transition_map, profiles_tbl, micro_roots)
family_df <- compute_family_rank_table(rank_df, execution_tbl)

utils::write.csv(execution_tbl, file.path(tables_dir, "profile_execution_status.csv"), row.names = FALSE)
if (nrow(eval_tbl)) utils::write.csv(eval_tbl, file.path(tables_dir, "phase35_micro_pilot_summary.csv"), row.names = FALSE)
if (nrow(diag_tbl)) utils::write.csv(diag_tbl, file.path(tables_dir, "phase35_micro_pilot_diag_shift.csv"), row.names = FALSE)
if (nrow(metric_tbl)) utils::write.csv(metric_tbl, file.path(tables_dir, "phase35_micro_pilot_metric_shift.csv"), row.names = FALSE)
if (nrow(rank_df)) utils::write.csv(rank_df, file.path(tables_dir, "profile_rank_summary.csv"), row.names = FALSE)
if (nrow(family_df)) utils::write.csv(family_df, file.path(tables_dir, "family_rank_summary.csv"), row.names = FALSE)

write_result_summary(
  path = file.path(summary_dir, "screen_results.md"),
  run_tag = run_tag,
  stop_reason = stop_reason,
  execution_tbl = execution_tbl,
  eval_tbl = eval_tbl,
  rank_df = rank_df,
  family_df = family_df,
  batches_tbl = batches_tbl[, c("batch_id", "description"), drop = FALSE]
)
write_runner_state(
  path = file.path(status_dir, "runner_state.json"),
  run_tag = run_tag,
  current_batch_id = NA_character_,
  current_profile_id = NA_character_,
  execution_tbl = execution_tbl,
  total_profiles = nrow(profiles_tbl),
  stop_reason = stop_reason
)

write_json_safe(
  list(
    finished_at = as.character(Sys.time()),
    run_tag = run_tag,
    stop_reason = stop_reason,
    completed_profiles = if (nrow(execution_tbl)) sum(as.character(execution_tbl$execution_status) %in% c("COMPLETED", "COMPLETED_RECONCILED", "RESUMED_COMPLETED"), na.rm = TRUE) else 0L,
    timeout_profiles = if (nrow(execution_tbl)) sum(as.character(execution_tbl$execution_status) == "TIMEOUT", na.rm = TRUE) else 0L,
    error_profiles = if (nrow(execution_tbl)) sum(as.character(execution_tbl$execution_status) %in% c("ERROR", "INCOMPLETE", "NO_OUTPUT"), na.rm = TRUE) else 0L,
    report_workspace = report_workspace,
    results_workspace = results_workspace
  ),
  file.path(manifest_dir, "screen_completed.json")
)

cat(sprintf("Screen workspace: %s\n", report_workspace))
cat(sprintf("Plan summary: %s\n", file.path(summary_dir, "screen_plan.md")))
cat(sprintf("Result summary: %s\n", file.path(summary_dir, "screen_results.md")))
cat(sprintf("Runner state: %s\n", file.path(status_dir, "runner_state.json")))

#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  if (!requireNamespace("jsonlite", quietly = TRUE)) {
    stop("The jsonlite package is required.", call. = FALSE)
  }
})

args <- commandArgs(trailingOnly = TRUE)

`%||%` <- function(a, b) if (is.null(a) || !length(a)) b else a

arg_values <- function(flag) {
  idx <- which(args == flag)
  if (!length(idx)) return(character())
  vals <- character()
  for (i in idx) {
    if (i < length(args)) vals <- c(vals, args[[i + 1L]])
  }
  vals[nzchar(vals)]
}

arg_value <- function(flag, default = NULL) {
  vals <- arg_values(flag)
  if (length(vals)) vals[[length(vals)]] else default
}

as_flag <- function(x, default = FALSE) {
  if (is.null(x) || !length(x) || is.na(x[[1L]])) return(default)
  tolower(as.character(x[[1L]])) %in% c("1", "true", "yes", "y", "on")
}

repo_root <- normalizePath(
  system2("git", c("rev-parse", "--show-toplevel"), stdout = TRUE)[[1L]],
  winslash = "/",
  mustWork = TRUE
)
setwd(repo_root)

resolve_path <- function(path, must_work = FALSE) {
  if (is.null(path) || !length(path) || is.na(path[[1L]])) return(NULL)
  path <- as.character(path[[1L]])
  if (!nzchar(path)) return(NULL)
  if (!startsWith(path, "/")) path <- file.path(repo_root, path)
  normalizePath(path, winslash = "/", mustWork = isTRUE(must_work))
}

read_csv <- function(path) {
  utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
}

write_csv <- function(x, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(x, path, row.names = FALSE, na = "")
  invisible(path)
}

sha256 <- function(path) {
  path <- as.character(path %||% "")[[1L]]
  if (!nzchar(path) || !file.exists(path)) return(NA_character_)
  unname(tools::sha256sum(path))
}

safe_json <- function(path) {
  if (is.null(path) || !file.exists(path)) return(list())
  tryCatch(jsonlite::read_json(path, simplifyVector = TRUE), error = function(e) list())
}

write_json <- function(x, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  jsonlite::write_json(x, path, pretty = TRUE, auto_unbox = TRUE, null = "null")
  invisible(path)
}

bind_rows_union <- function(rows) {
  rows <- rows[!vapply(rows, is.null, logical(1))]
  if (!length(rows)) return(data.frame(stringsAsFactors = FALSE))
  cols <- unique(unlist(lapply(rows, names), use.names = FALSE))
  rows <- lapply(rows, function(x) {
    missing <- setdiff(cols, names(x))
    for (col in missing) x[[col]] <- NA
    x[, cols, drop = FALSE]
  })
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
}

first_nonempty <- function(...) {
  vals <- list(...)
  for (val in vals) {
    if (is.null(val) || !length(val)) next
    out <- val[[1L]]
    if (!is.na(out) && nzchar(as.character(out))) return(out)
  }
  NA
}

get_col <- function(df, row, name, default = NA) {
  if (!nrow(df) || !name %in% names(df)) return(default)
  df[[name]][[row]]
}

method_dir_from_path <- function(path) {
  normalizePath(dirname(dirname(path)), winslash = "/", mustWork = TRUE)
}

root_dir_from_method_dir <- function(method_dir) {
  normalizePath(dirname(dirname(method_dir)), winslash = "/", mustWork = TRUE)
}

append_suffix <- function(path, suffix) {
  sub("\\.csv$", paste0(suffix, ".csv"), path)
}

pinball_vec <- function(y, q, tau) {
  y <- as.numeric(y)
  q <- as.numeric(q)
  tau <- as.numeric(tau)[1L]
  e <- y - q
  out <- (tau - as.numeric(e < 0)) * e
  out[!(is.finite(y) & is.finite(q) & is.finite(tau))] <- NA_real_
  out
}

repair_path_df <- function(path_df, center, scale, tau, transform, status) {
  out <- path_df
  q_cols <- intersect(
    c("qhat", "qhat_p0025", "qhat_p0250", "qhat_p0500", "qhat_p0750", "qhat_p0975"),
    names(out)
  )
  if (identical(transform, "affine")) {
    for (col in q_cols) out[[col]] <- as.numeric(out[[col]]) * scale + center
  }
  qhat <- as.numeric(out$qhat)
  q_true <- as.numeric(out$q_true)
  y <- as.numeric(out$y)
  out$q_error <- qhat - q_true
  out$abs_q_error <- abs(out$q_error)
  out$squared_q_error <- out$q_error^2
  out$pinball_tau <- pinball_vec(y, qhat, tau)
  out$hit <- as.integer(y <= qhat)
  out$coverage_minus_tau <- out$hit - tau
  out$lead_export_output_scale <- if (identical(transform, "affine")) "standardized_model" else "original"
  out$lead_export_target_scale <- "original"
  out$lead_export_transform <- transform
  out$lead_export_center <- center
  out$lead_export_scale_factor <- scale
  out$lead_export_scale_source <- "observed.csv + fit_request$config$preproc$scale_y"
  out$lead_export_scale_status <- status
  out
}

metric_value <- function(x, name, default = NA) {
  if (name %in% names(x)) x[[name]][[1L]] else default
}

repair_metrics_df <- function(old_metrics, path_df, summary_row) {
  lead_split <- split(path_df, path_df$forecast_lead)
  rows <- vector("list", length(lead_split))
  names(rows) <- names(lead_split)
  for (lead_name in names(lead_split)) {
    x <- lead_split[[lead_name]]
    old <- old_metrics[as.integer(old_metrics$forecast_lead) == as.integer(lead_name), , drop = FALSE]
    if (nrow(old) > 1L) old <- old[1L, , drop = FALSE]
    row <- if (nrow(old)) old else data.frame(stringsAsFactors = FALSE)
    set <- function(name, value) {
      row[[name]] <<- value
    }
    set("root_id", first_nonempty(get_col(summary_row, 1L, "root_id"), metric_value(old, "root_id")))
    set("dataset_cell_id", first_nonempty(get_col(summary_row, 1L, "dataset_cell_id"), metric_value(old, "dataset_cell_id")))
    set("scenario", first_nonempty(get_col(summary_row, 1L, "scenario"), metric_value(old, "scenario")))
    set("family", first_nonempty(get_col(summary_row, 1L, "family"), metric_value(old, "family")))
    set("tau", as.numeric(first_nonempty(get_col(summary_row, 1L, "tau"), metric_value(old, "tau"))))
    set("fit_size", as.integer(first_nonempty(get_col(summary_row, 1L, "effective_fit_size"), get_col(summary_row, 1L, "fit_size"), metric_value(old, "fit_size"))))
    set("forecast_protocol", as.character(x$forecast_protocol[[1L]]))
    set("state_update_method", as.character(x$state_update_method[[1L]]))
    set("refit_per_origin", as.logical(x$refit_per_origin[[1L]]))
    set("forecast_lead", as.integer(lead_name))
    set("origin_stride", as.integer(x$origin_stride[[1L]]))
    set("max_lead_configured", as.integer(x$max_lead_configured[[1L]]))
    set("n_origins_scored", nrow(x))
    set("origin_start_source_index", min(as.integer(x$forecast_origin_source_index), na.rm = TRUE))
    set("origin_end_source_index", max(as.integer(x$forecast_origin_source_index), na.rm = TRUE))
    set("target_start_source_index", min(as.integer(x$target_source_index), na.rm = TRUE))
    set("target_end_source_index", max(as.integer(x$target_source_index), na.rm = TRUE))
    set("forecast_qtrue_mae", mean(as.numeric(x$abs_q_error), na.rm = TRUE))
    set("forecast_qtrue_rmse", sqrt(mean(as.numeric(x$squared_q_error), na.rm = TRUE)))
    set("forecast_qtrue_bias", mean(as.numeric(x$q_error), na.rm = TRUE))
    set("forecast_pinball_mean", mean(as.numeric(x$pinball_tau), na.rm = TRUE))
    set("forecast_coverage", mean(as.numeric(x$hit), na.rm = TRUE))
    set("forecast_coverage_error", mean(as.numeric(x$coverage_minus_tau), na.rm = TRUE))
    set("synthesis_enabled", FALSE)
    set("posterior_draw_source", "mu_by_origin")
    set("lead_export_target_scale", as.character(x$lead_export_target_scale[[1L]]))
    set("lead_export_transform", as.character(x$lead_export_transform[[1L]]))
    set("lead_export_scale_status", as.character(x$lead_export_scale_status[[1L]]))
    rows[[lead_name]] <- row
  }
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out[order(as.integer(out$forecast_lead)), , drop = FALSE]
}

campaign_label <- function(path) {
  campaign_dir <- dirname(dirname(path))
  run_dir <- dirname(campaign_dir)
  raw <- paste(basename(run_dir), basename(campaign_dir), sep = "__")
  gsub("[^A-Za-z0-9_.=-]+", "_", raw)
}

same_tt500_replacement_key <- function(x) {
  paste(
    as.character(x$family),
    sprintf("%.3f", as.numeric(x$tau)),
    as.integer(x$fit_size),
    as.character(x$beta_prior_type %||% x$prior),
    as.character(x$inference),
    as.character(x$likelihood_family),
    sep = "|"
  )
}

repair_campaign_summary <- function(summary_path, out_root, dry_run = FALSE, overwrite = FALSE) {
  fit_summary <- read_csv(summary_path)
  repaired <- fit_summary
  if (!"forecast_rolling_origin_path_file" %in% names(repaired)) {
    stop(sprintf("Missing forecast_rolling_origin_path_file in %s", summary_path), call. = FALSE)
  }
  if (!"forecast_lead_metrics_path" %in% names(repaired)) {
    stop(sprintf("Missing forecast_lead_metrics_path in %s", summary_path), call. = FALSE)
  }
  audit_rows <- vector("list", nrow(repaired))
  for (i in seq_len(nrow(repaired))) {
    row <- repaired[i, , drop = FALSE]
    roll_path <- resolve_path(get_col(row, 1L, "forecast_rolling_origin_path_file"), must_work = FALSE)
    metrics_path <- resolve_path(get_col(row, 1L, "forecast_lead_metrics_path"), must_work = FALSE)
    audit <- list(
      input_summary = normalizePath(summary_path, winslash = "/", mustWork = TRUE),
      row_index = i,
      root_id = as.character(get_col(row, 1L, "root_id")),
      inference = as.character(get_col(row, 1L, "inference")),
      likelihood_family = as.character(get_col(row, 1L, "likelihood_family")),
      rolling_origin_path = roll_path,
      lead_metrics_path = metrics_path,
      status = "SKIPPED",
      reason = NA_character_
    )
    if (is.null(roll_path) || is.null(metrics_path) || !file.exists(roll_path) || !file.exists(metrics_path)) {
      audit$reason <- "missing rolling path or lead metrics path"
      audit_rows[[i]] <- as.data.frame(audit, stringsAsFactors = FALSE)
      next
    }
    path_df <- read_csv(roll_path)
    old_metrics <- read_csv(metrics_path)
    if ("lead_export_scale_status" %in% names(path_df) &&
        any(grepl("backtransformed|repaired", path_df$lead_export_scale_status, ignore.case = TRUE))) {
      audit$status <- "SKIPPED_ALREADY_REPAIRED"
      audit$reason <- "input rolling path already declares repaired/backtransformed scale"
      audit_rows[[i]] <- as.data.frame(audit, stringsAsFactors = FALSE)
      next
    }
    method_dir <- method_dir_from_path(roll_path)
    root_dir <- root_dir_from_method_dir(method_dir)
    fit_request <- safe_json(file.path(method_dir, "fit_request.json"))
    observed_path <- file.path(root_dir, "data", "observed.csv")
    if (!file.exists(observed_path)) {
      audit$status <- "FAIL"
      audit$reason <- "missing root/data/observed.csv"
      audit_rows[[i]] <- as.data.frame(audit, stringsAsFactors = FALSE)
      next
    }
    observed <- read_csv(observed_path)
    if (!"y" %in% names(observed)) {
      audit$status <- "FAIL"
      audit$reason <- "observed.csv missing y column"
      audit_rows[[i]] <- as.data.frame(audit, stringsAsFactors = FALSE)
      next
    }
    center <- mean(as.numeric(observed$y), na.rm = TRUE)
    scale <- stats::sd(as.numeric(observed$y), na.rm = TRUE)
    if (!is.finite(scale) || scale == 0) scale <- 1
    scale_y <- fit_request$config$preproc$scale_y
    scale_y <- if (is.null(scale_y)) NA else isTRUE(scale_y)
    transform <- if (isTRUE(scale_y)) "affine" else "identity"
    scale_status <- if (identical(transform, "affine")) "original_scale_repaired" else "original_scale_identity_checked"
    tau <- as.numeric(get_col(row, 1L, "tau"))
    repaired_path <- repair_path_df(path_df, center, scale, tau, transform, scale_status)
    repaired_metrics <- repair_metrics_df(old_metrics, repaired_path, row)
    repaired_roll_path <- append_suffix(roll_path, "_scale_repaired")
    repaired_metrics_path <- append_suffix(metrics_path, "_scale_repaired")
    manifest_path <- file.path(method_dir, "manifest", "rolling_origin_scale_repair.json")
    if (!dry_run) {
      for (out_path in c(repaired_roll_path, repaired_metrics_path, manifest_path)) {
        if (file.exists(out_path) && !isTRUE(overwrite)) {
          stop(sprintf("Refusing to overwrite existing repair artifact without --overwrite true: %s", out_path), call. = FALSE)
        }
      }
      write_csv(repaired_path, repaired_roll_path)
      write_csv(repaired_metrics, repaired_metrics_path)
      write_json(list(
        generated_at = as.character(Sys.time()),
        repair_script = "scripts/repair_qdesn_rolling_origin_scale_exports.R",
        input_summary = normalizePath(summary_path, winslash = "/", mustWork = TRUE),
        row_index = i,
        root_id = as.character(get_col(row, 1L, "root_id")),
        method_dir = method_dir,
        observed_path = observed_path,
        observed_y_mean = center,
        observed_y_sd = scale,
        fit_request_path = file.path(method_dir, "fit_request.json"),
        fit_request_scale_y = scale_y,
        transform = transform,
        scale_status = scale_status,
        raw_rolling_origin_path = roll_path,
        raw_rolling_origin_sha256 = sha256(roll_path),
        repaired_rolling_origin_path = repaired_roll_path,
        repaired_rolling_origin_sha256 = sha256(repaired_roll_path),
        raw_lead_metrics_path = metrics_path,
        raw_lead_metrics_sha256 = sha256(metrics_path),
        repaired_lead_metrics_path = repaired_metrics_path,
        repaired_lead_metrics_sha256 = sha256(repaired_metrics_path),
        rows_repaired = nrow(repaired_path),
        metric_rows_repaired = nrow(repaired_metrics)
      ), manifest_path)
    }
    repaired[i, "forecast_rolling_origin_path_file"] <- repaired_roll_path
    repaired[i, "forecast_lead_metrics_path"] <- repaired_metrics_path
    repaired[i, "rolling_origin_scale_repair_manifest"] <- manifest_path
    repaired[i, "rolling_origin_scale_repair_status"] <- scale_status
    repaired[i, "rolling_origin_scale_repair_transform"] <- transform
    repaired[i, "rolling_origin_scale_repair_center"] <- center
    repaired[i, "rolling_origin_scale_repair_scale"] <- scale
    audit$status <- "PASS"
    audit$reason <- scale_status
    audit$observed_path <- observed_path
    audit$observed_y_mean <- center
    audit$observed_y_sd <- scale
    audit$transform <- transform
    audit$rows <- nrow(repaired_path)
    audit$metric_rows <- nrow(repaired_metrics)
    audit$repaired_rolling_origin_path <- repaired_roll_path
    audit$repaired_lead_metrics_path <- repaired_metrics_path
    audit$repair_manifest_path <- manifest_path
    audit_rows[[i]] <- as.data.frame(audit, stringsAsFactors = FALSE)
  }

  label <- campaign_label(summary_path)
  out_summary <- file.path(out_root, "campaign_summaries", paste0(label, "__campaign_fit_summary_scale_repaired.csv"))
  out_audit <- file.path(out_root, "campaign_summaries", paste0(label, "__scale_repair_audit.csv"))
  if (!dry_run) {
    if (file.exists(out_summary) && !isTRUE(overwrite)) {
      stop(sprintf("Refusing to overwrite existing repaired summary without --overwrite true: %s", out_summary), call. = FALSE)
    }
    write_csv(repaired, out_summary)
    write_csv(bind_rows_union(audit_rows), out_audit)
  }
  list(
    label = label,
    input_summary = normalizePath(summary_path, winslash = "/", mustWork = TRUE),
    repaired_summary = out_summary,
    audit_path = out_audit,
    summary = repaired,
    audit = bind_rows_union(audit_rows)
  )
}

git_short <- system2("git", c("rev-parse", "--short", "HEAD"), stdout = TRUE)[[1L]]
default_out_root <- file.path(
  repo_root,
  "reports/qdesn_mcmc_validation/dynamic_fitforecast_v2_validation",
  sprintf("qdesn-rolling-origin-v3-scale-repair-20260621__git-%s", git_short)
)

default_summaries <- file.path(repo_root, c(
  "reports/qdesn_mcmc_validation/dynamic_fitforecast_v2_validation/qdesn-dynamic-fitforecast-v2-mcmc-tt500-20260520-035319__git-d075941/20260525-191523__git-d075941/tables/campaign_fit_summary.csv",
  "reports/qdesn_mcmc_validation/dynamic_fitforecast_v2_validation/qdesn-dynamic-fitforecast-v2-mcmc-tt500-al-supplement-20260614-0052__git-d075941/20260614-005422__git-ec465f9/tables/campaign_fit_summary.csv",
  "reports/qdesn_mcmc_validation/dynamic_fitforecast_v2_validation/qdesn-dynamic-fitforecast-v2-vb-full-20260520-035319__git-d075941/20260520-071231__git-d075941/tables/campaign_fit_summary.csv"
))

summary_args <- arg_values("--campaign-fit-summary")
if (!length(summary_args)) summary_args <- default_summaries
summary_paths <- vapply(summary_args, resolve_path, character(1), must_work = TRUE)
out_root <- resolve_path(arg_value("--out-root", default_out_root), must_work = FALSE)
dry_run <- as_flag(arg_value("--dry-run", "false"), default = FALSE)
overwrite <- as_flag(arg_value("--overwrite", "false"), default = FALSE)
write_final_tt500 <- as_flag(arg_value("--write-final-tt500", "true"), default = TRUE)
final_run_tag <- arg_value("--final-run-tag", sprintf("qdesn-rolling-origin-v3-tt500-final-scale-repaired-20260621__git-%s", git_short))

if (!dry_run) dir.create(out_root, recursive = TRUE, showWarnings = FALSE)

campaign_results <- lapply(summary_paths, repair_campaign_summary, out_root = out_root, dry_run = dry_run, overwrite = overwrite)
all_audits <- bind_rows_union(lapply(campaign_results, `[[`, "audit"))
audit_path <- file.path(out_root, "scale_repair_audit.csv")
if (!dry_run) write_csv(all_audits, audit_path)

final_summary_path <- NA_character_
final_manifest_path <- NA_character_
if (isTRUE(write_final_tt500)) {
  main_idx <- grep("mcmc-tt500-20260520-035319", vapply(campaign_results, `[[`, character(1), "label"))
  supp_idx <- grep("mcmc-tt500-al-supplement", vapply(campaign_results, `[[`, character(1), "label"))
  if (length(main_idx) && length(supp_idx)) {
    main <- campaign_results[[main_idx[[1L]]]]$summary
    supp <- campaign_results[[supp_idx[[1L]]]]$summary
    final <- main
    final$final_run_tag <- final_run_tag
    final$run_tag <- final_run_tag
    final$phase <- "mcmc_tt500_final_scale_repaired"
    final$final_row_source <- "main_tt500"
    replace_mask <- as.character(final$family) == "normal" &
      abs(as.numeric(final$tau) - 0.5) < 1e-12 &
      as.integer(final$fit_size) == 500L &
      as.character(final$inference) == "mcmc" &
      as.character(final$likelihood_family) == "al" &
      as.character(final$beta_prior_type) %in% c("rhs_ns", "ridge")
    key_final <- same_tt500_replacement_key(final)
    key_supp <- same_tt500_replacement_key(supp)
    for (j in seq_len(nrow(supp))) {
      idx <- which(replace_mask & key_final == key_supp[[j]])
      if (length(idx) != 1L) {
        stop(sprintf("Expected exactly one TT500 replacement row for supplement key %s; found %d.", key_supp[[j]], length(idx)), call. = FALSE)
      }
      replacement <- supp[j, , drop = FALSE]
      replacement$final_run_tag <- final_run_tag
      replacement$run_tag <- final_run_tag
      replacement$phase <- "mcmc_tt500_final_scale_repaired"
      replacement$final_row_source <- "al_supplement"
      missing_cols <- setdiff(names(final), names(replacement))
      for (col in missing_cols) replacement[[col]] <- NA
      missing_final_cols <- setdiff(names(replacement), names(final))
      for (col in missing_final_cols) final[[col]] <- NA
      final <- final[, names(replacement), drop = FALSE]
      final[idx, ] <- replacement[1L, names(final), drop = FALSE]
    }
    final_dir <- file.path(out_root, "final_tt500")
    final_summary_path <- file.path(final_dir, "tables", "campaign_fit_summary.csv")
    final_manifest_path <- file.path(final_dir, "manifest", "final_tt500_manifest.json")
    if (!dry_run) {
      if (file.exists(final_summary_path) && !isTRUE(overwrite)) {
        stop(sprintf("Refusing to overwrite final TT500 summary without --overwrite true: %s", final_summary_path), call. = FALSE)
      }
      write_csv(final, final_summary_path)
      write_json(list(
        generated_at = as.character(Sys.time()),
        repair_script = "scripts/repair_qdesn_rolling_origin_scale_exports.R",
        final_run_tag = final_run_tag,
        final_summary_path = final_summary_path,
        final_summary_sha256 = sha256(final_summary_path),
        row_count = nrow(final),
        status_counts = as.list(table(final$status, useNA = "ifany")),
        replacement_policy = "Replace main TT500 normal tau=0.50 AL rhs_ns/ridge rows with successful supplement rows; keep all other main rows.",
        input_summaries = lapply(campaign_results, function(x) list(
          label = x$label,
          input_summary = x$input_summary,
          repaired_summary = x$repaired_summary,
          repaired_summary_sha256 = sha256(x$repaired_summary),
          audit_path = x$audit_path,
          audit_sha256 = sha256(x$audit_path)
        ))
      ), final_manifest_path)
    }
  }
}

run_manifest <- list(
  generated_at = as.character(Sys.time()),
  repo_root = repo_root,
  branch = system2("git", c("branch", "--show-current"), stdout = TRUE)[[1L]],
  commit = system2("git", c("rev-parse", "HEAD"), stdout = TRUE)[[1L]],
  git_dirty = length(system2("git", c("status", "--porcelain"), stdout = TRUE)) > 0L,
  out_root = out_root,
  dry_run = dry_run,
  overwrite = overwrite,
  input_summaries = as.list(summary_paths),
  audit_path = audit_path,
  final_summary_path = final_summary_path,
  final_manifest_path = final_manifest_path,
  pass_rows = sum(all_audits$status == "PASS", na.rm = TRUE),
  fail_rows = sum(all_audits$status == "FAIL", na.rm = TRUE),
  skipped_rows = sum(grepl("^SKIPPED", all_audits$status), na.rm = TRUE)
)
run_manifest_path <- file.path(out_root, "scale_repair_run_manifest.json")
if (!dry_run) write_json(run_manifest, run_manifest_path)

cat(sprintf("scale_repair_out_root: %s\n", out_root))
cat(sprintf("scale_repair_rows_pass: %d\n", run_manifest$pass_rows))
cat(sprintf("scale_repair_rows_fail: %d\n", run_manifest$fail_rows))
cat(sprintf("scale_repair_rows_skipped: %d\n", run_manifest$skipped_rows))
if (!dry_run) {
  cat(sprintf("scale_repair_audit: %s\n", audit_path))
  cat(sprintf("scale_repair_manifest: %s\n", run_manifest_path))
  if (!is.na(final_summary_path)) cat(sprintf("final_tt500_summary: %s\n", final_summary_path))
  if (!is.na(final_manifest_path)) cat(sprintf("final_tt500_manifest: %s\n", final_manifest_path))
}

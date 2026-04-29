#!/usr/bin/env Rscript

options(stringsAsFactors = FALSE)

source("tools/merge_reports/LOCAL_refreshed288_helpers_20260422_p90_full288.R")

args <- parse_args_refreshed288(commandArgs(trailingOnly = TRUE))
repo_root <- normalizePath(".", winslash = "/", mustWork = TRUE)
setwd(repo_root)

paths <- paths_refreshed288()
manifest_path <- safe_chr_refreshed288(args$manifest, paths$full_manifest)
status_path <- safe_chr_refreshed288(args$status, paths$full_manifest_status)
out_path <- safe_chr_refreshed288(
  args$out,
  file.path(paths$retention_audit_dir, sprintf("lightweight_summary_extraction_%s.csv", format(Sys.time(), "%Y%m%d_%H%M%S")))
)
force <- as_flag_refreshed288(args$force, FALSE)
delete_candidate_fit_after_summary <- as_flag_refreshed288(args$delete_candidate_fit_after_summary, FALSE)
delete_draw_export_after_summary <- as_flag_refreshed288(args$delete_draw_export_after_summary, FALSE)
limit <- safe_int_refreshed288(args$limit, NA_integer_)

qdesn_canonical_source_root <- safe_chr_refreshed288(
  Sys.getenv("REFRESHED288_DYNAMIC_CANONICAL_SOURCE_ROOT", unset = ""),
  ""
)
if (!nzchar(qdesn_canonical_source_root)) {
  qdesn_canonical_source_root <- "/home/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration/results/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_candidate_sources/dlm_constV_p90_m0amp_highnoise_steepertrend_v1"
}

if (!file.exists(manifest_path)) stop(sprintf("Missing manifest: %s", manifest_path), call. = FALSE)
if (requireNamespace("pkgload", quietly = TRUE)) {
  pkgload::load_all(repo_root, quiet = TRUE)
}

ensure_dir_refreshed288(paths$plot_summaries_dir)
ensure_dir_refreshed288(paths$parameter_summaries_dir)
ensure_dir_refreshed288(paths$predictive_quantile_grid_dir)
ensure_dir_refreshed288(paths$retention_audit_dir)

manifest <- utils::read.csv(manifest_path, stringsAsFactors = FALSE, check.names = FALSE)
status <- safe_read_csv_refreshed288(status_path, stringsAsFactors = FALSE, check.names = FALSE)
if (!is.null(status) && nrow(status)) {
  keep_cols <- intersect(c("row_id", "status_current", "gate_current"), names(status))
  manifest <- merge(manifest, status[, keep_cols, drop = FALSE], by = "row_id", all.x = TRUE, sort = FALSE)
}

row_tokens <- parse_csv_tokens_refreshed288(args$rows %||% args$row_id %||% "")
if (length(row_tokens)) {
  wanted <- suppressWarnings(as.integer(row_tokens))
  wanted <- wanted[is.finite(wanted)]
  manifest <- manifest[manifest$row_id %in% wanted, , drop = FALSE]
}
manifest <- manifest[order(manifest$row_id), , drop = FALSE]
if (is.finite(limit) && limit > 0L) manifest <- head(manifest, limit)

resolve_wrapped_fit_refreshed288_local <- function(obj) obj$fit %||% obj

path_or_qdesn_dynamic_path <- function(path, row) {
  if (!is.na(path) && nzchar(path) && file.exists(path)) return(path)
  if (!identical(row$block[[1]], "dynamic")) return(path)
  if (!dir.exists(qdesn_canonical_source_root)) return(path)

  family <- safe_chr_refreshed288(row$family[[1]], "")
  tau_label <- safe_chr_refreshed288(row$tau_label[[1]], "")
  fit_size <- safe_int_refreshed288(row$fit_size[[1]], NA_integer_)
  if (!nzchar(family) || !nzchar(tau_label)) return(path)

  basename_path <- basename(path)
  base_root <- file.path(qdesn_canonical_source_root, family, paste0("tau_", tau_label))
  if (!dir.exists(base_root)) return(path)

  if (basename_path %in% c("sim_output.rds", "series_wide.csv", "series_long.csv", "true_quantile_grid.csv", "meta.txt", "validation.txt")) {
    candidate <- file.path(base_root, basename_path)
    if (file.exists(candidate)) return(candidate)
  }
  if (is.finite(fit_size)) {
    window_dir <- file.path(base_root, sprintf("fit_input_lastTT%d", fit_size))
    candidate <- file.path(window_dir, basename_path)
    if (file.exists(candidate)) return(candidate)
  }
  path
}

read_dynamic_source_for_fit_length <- function(row, cfg, fit_obj, fit_n) {
  candidates <- list()

  sim_path <- path_or_qdesn_dynamic_path(cfg$sim_output_path %||% NA_character_, row)
  if (!is.na(sim_path) && nzchar(sim_path) && file.exists(sim_path)) {
    candidates[[length(candidates) + 1L]] <- list(kind = "sim_output", path = sim_path)
  }
  series_path <- path_or_qdesn_dynamic_path(cfg$series_wide_path %||% NA_character_, row)
  truth_path <- path_or_qdesn_dynamic_path(cfg$true_quantile_grid_path %||% NA_character_, row)
  if (!is.na(series_path) && nzchar(series_path) && file.exists(series_path)) {
    candidates[[length(candidates) + 1L]] <- list(kind = "window_csv", path = series_path, truth_path = truth_path)
  }

  for (cand in candidates) {
    obj <- tryCatch({
      if (identical(cand$kind, "sim_output")) {
        readRDS(cand$path)
      } else {
        build_dynamic_sim_object_refreshed288(
          series_wide_path = cand$path,
          true_quantile_grid_path = cand$truth_path,
          tau = row$tau[[1]],
          period = cfg$period %||% 90L
        )
      }
    }, error = function(e) NULL)
    if (!is.null(obj) && length(obj$y) == fit_n) {
      y_fit <- as.numeric(fit_obj$y %||% obj$y)
      y_source <- as.numeric(obj$y)
      y_delta <- suppressWarnings(max(abs(y_fit - y_source), na.rm = TRUE))
      if (!is.finite(y_delta) || y_delta > 1e-8) {
        obj$y <- y_fit
        obj$extraction_note <- sprintf("%s_y_replaced_by_fit_y_delta_%s", cand$kind, format(y_delta, digits = 6))
      } else {
        obj$extraction_note <- sprintf("%s_matched_fit_length", cand$kind)
      }
      return(obj)
    }
  }

  list(
    y = as.numeric(fit_obj$y),
    q = matrix(rep(NA_real_, fit_n), ncol = 1L),
    source_series_wide = data.frame(t = seq_len(fit_n), stringsAsFactors = FALSE),
    extraction_note = "fit_y_only_missing_source_truth"
  )
}

extract_one_row <- function(row) {
  cfg <- readRDS(row$config_path)
  cfg$plot_summary_path <- cfg$plot_summary_path %||% plot_summary_path_refreshed288(row)
  cfg$parameter_summary_path <- cfg$parameter_summary_path %||% parameter_summary_path_refreshed288(row)
  cfg$predictive_quantile_grid_path <- cfg$predictive_quantile_grid_path %||% predictive_quantile_grid_path_refreshed288(row)

  fit_exists_before <- file.exists(row$candidate_fit_path)
  draw_exists_before <- file.exists(row$draws_path)
  if (!force && file.exists(cfg$plot_summary_path) && (!identical(row$block[[1]], "static") || file.exists(cfg$parameter_summary_path))) {
    fit_deleted <- FALSE
    draw_deleted <- FALSE
    if (delete_candidate_fit_after_summary && fit_exists_before) {
      fit_deleted <- unlink(row$candidate_fit_path, force = TRUE) == 0L
    }
    if (delete_draw_export_after_summary && draw_exists_before) {
      draw_deleted <- unlink(row$draws_path, force = TRUE) == 0L
    }
    return(data.frame(
      row_id = row$row_id,
      original_case_key = row$original_case_key,
      block = row$block,
      status = "skipped_existing_summary",
      error = NA_character_,
      actual_n_obs = NA_integer_,
      expected_fit_size = row$fit_size,
      plot_summary_exists = file.exists(cfg$plot_summary_path),
      parameter_summary_exists = if (identical(row$block[[1]], "static")) file.exists(cfg$parameter_summary_path) else NA,
      fit_deleted = fit_deleted,
      draw_deleted = draw_deleted,
      stringsAsFactors = FALSE
    ))
  }
  if (!fit_exists_before) {
    return(data.frame(
      row_id = row$row_id,
      original_case_key = row$original_case_key,
      block = row$block,
      status = "missing_fit",
      error = sprintf("missing candidate fit and missing required lightweight summary: %s", row$candidate_fit_path),
      actual_n_obs = NA_integer_,
      expected_fit_size = row$fit_size,
      plot_summary_exists = file.exists(cfg$plot_summary_path),
      parameter_summary_exists = if (identical(row$block[[1]], "static")) file.exists(cfg$parameter_summary_path) else NA,
      fit_deleted = FALSE,
      draw_deleted = FALSE,
      stringsAsFactors = FALSE
    ))
  }

  wrapped <- readRDS(row$candidate_fit_path)
  fit_obj <- resolve_wrapped_fit_refreshed288_local(wrapped)

  if (identical(row$block[[1]], "dynamic")) {
    draw_all <- as.matrix(fit_obj$samp.post.pred)
    selected_indices <- select_draw_indices_refreshed288(ncol(draw_all), row$stored_posterior_draws, row$seed)
    draw_keep <- draw_all[, selected_indices, drop = FALSE]
    sim_obj <- read_dynamic_source_for_fit_length(row, cfg, fit_obj, nrow(draw_keep))
    source_index <- if (!is.null(sim_obj$source_series_wide) && "t" %in% names(sim_obj$source_series_wide)) sim_obj$source_series_wide$t else seq_len(nrow(draw_keep))
    q_true <- if (!is.null(sim_obj$q) && nrow(as.matrix(sim_obj$q)) == nrow(draw_keep)) as.numeric(as.matrix(sim_obj$q)[, 1L]) else rep(NA_real_, nrow(draw_keep))
    write_plot_summary_refreshed288(
      row = row,
      y = as.numeric(sim_obj$y),
      q_true = q_true,
      draw_mat = draw_keep,
      source_index = source_index,
      path = cfg$plot_summary_path,
      artifact_note = sim_obj$extraction_note %||% "extracted_from_existing_dynamic_fit"
    )
    actual_n_obs <- nrow(draw_keep)
    rm(draw_all, draw_keep)
  } else {
    series_wide <- if (file.exists(cfg$series_wide_path)) {
      utils::read.csv(cfg$series_wide_path, stringsAsFactors = FALSE, check.names = FALSE)
    } else {
      data.frame(row_id = seq_along(fit_obj$y), y = as.numeric(fit_obj$y), stringsAsFactors = FALSE)
    }
    coef_truth <- if (file.exists(cfg$coef_truth_path)) {
      utils::read.csv(cfg$coef_truth_path, stringsAsFactors = FALSE, check.names = FALSE)
    } else {
      NULL
    }
    design <- if (all(c("y") %in% names(series_wide)) && any(grepl("^x[0-9]+$", names(series_wide)))) {
      static_build_design_refreshed288(series_wide)
    } else {
      list(
        X = fit_obj$X,
        X_slopes = fit_obj$X[, -1L, drop = FALSE],
        y = as.numeric(fit_obj$y),
        q_truth = rep(NA_real_, length(fit_obj$y))
      )
    }
    draw_bundle <- static_predictive_draws_refreshed288(
      fit_obj = fit_obj,
      row = row,
      series_wide = series_wide,
      n_draws = row$stored_posterior_draws,
      seed = row$seed
    )
    write_plot_summary_refreshed288(
      row = row,
      y = design$y,
      q_true = design$q_truth,
      draw_mat = draw_bundle$draws,
      source_index = if ("row_id" %in% names(series_wide)) series_wide$row_id else seq_along(design$y),
      path = cfg$plot_summary_path,
      artifact_note = "extracted_from_existing_static_fit"
    )
    write_parameter_summary_refreshed288(
      row = row,
      beta_draws = draw_bundle$beta_draws,
      sigma_draws = draw_bundle$sigma_draws,
      gamma_draws = draw_bundle$gamma_draws,
      coef_truth = coef_truth,
      design = design,
      path = cfg$parameter_summary_path
    )
    actual_n_obs <- nrow(draw_bundle$draws)
    rm(draw_bundle)
  }

  plot_ok <- file.exists(cfg$plot_summary_path)
  param_ok <- if (identical(row$block[[1]], "static")) file.exists(cfg$parameter_summary_path) else NA
  fit_deleted <- FALSE
  draw_deleted <- FALSE
  if (plot_ok && (!identical(row$block[[1]], "static") || isTRUE(param_ok))) {
    if (delete_candidate_fit_after_summary) {
      fit_deleted <- unlink(row$candidate_fit_path, force = TRUE) == 0L
    }
    if (delete_draw_export_after_summary && draw_exists_before) {
      draw_deleted <- unlink(row$draws_path, force = TRUE) == 0L
    }
  }

  rm(wrapped, fit_obj)
  gc()
  data.frame(
    row_id = row$row_id,
    original_case_key = row$original_case_key,
    block = row$block,
    status = "ok",
    error = NA_character_,
    actual_n_obs = actual_n_obs,
    expected_fit_size = row$fit_size,
    plot_summary_exists = plot_ok,
    parameter_summary_exists = param_ok,
    fit_deleted = fit_deleted,
    draw_deleted = draw_deleted,
    stringsAsFactors = FALSE
  )
}

audit_rows <- vector("list", nrow(manifest))
for (i in seq_len(nrow(manifest))) {
  row <- manifest[i, , drop = FALSE]
  cat(sprintf(
    "[%s] extracting row %d/%d row_id=%d block=%s model=%s inference=%s\n",
    format(Sys.time(), "%H:%M:%S"),
    i,
    nrow(manifest),
    row$row_id,
    row$block,
    row$model,
    row$inference
  ))
  audit_rows[[i]] <- tryCatch(
    extract_one_row(row),
    error = function(e) {
      data.frame(
        row_id = row$row_id,
        original_case_key = row$original_case_key,
        block = row$block,
        status = "error",
        error = conditionMessage(e),
        actual_n_obs = NA_integer_,
        expected_fit_size = row$fit_size,
        plot_summary_exists = file.exists(plot_summary_path_refreshed288(row)),
        parameter_summary_exists = if (identical(row$block[[1]], "static")) file.exists(parameter_summary_path_refreshed288(row)) else NA,
        fit_deleted = FALSE,
        draw_deleted = FALSE,
        stringsAsFactors = FALSE
      )
    }
  )
  write_csv_atomic_refreshed288(do.call(rbind, audit_rows[seq_len(i)]), out_path, row.names = FALSE)
}

audit <- do.call(rbind, audit_rows)
write_csv_atomic_refreshed288(audit, out_path, row.names = FALSE)

cat(sprintf("Wrote lightweight extraction audit: %s\n", out_path))
cat(sprintf(
  "SUMMARY rows=%d ok=%d skipped=%d missing_fit=%d errors=%d fit_deleted=%d draw_deleted=%d\n",
  nrow(audit),
  sum(audit$status == "ok"),
  sum(audit$status == "skipped_existing_summary"),
  sum(audit$status == "missing_fit"),
  sum(audit$status == "error"),
  sum(audit$fit_deleted),
  sum(audit$draw_deleted)
))

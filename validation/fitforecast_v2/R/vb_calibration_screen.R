ffv2_default_vb_calibration_candidates_path <- function() {
  file.path(
    ffv2_harness_root(),
    "config",
    "exdqlm_dqlm_vb_calibration_screen_candidates_20260702.csv"
  )
}

ffv2_required_vb_calibration_candidate_columns <- function() {
  c(
    "candidate_id", "calibration_id", "trend_C0_scale",
    "seasonal_C0_scale", "df_value", "dim_df", "notes"
  )
}

ffv2_canonical_numeric_csv <- function(x) {
  vals <- ffv2_parse_numeric_config_value(x, default = numeric(0))
  if (!length(vals) || any(!is.finite(vals))) {
    stop("Numeric CSV value is empty or invalid.", call. = FALSE)
  }
  paste(sprintf("%.15g", vals), collapse = ",")
}

ffv2_canonical_integer_csv <- function(x) {
  vals <- as.integer(ffv2_parse_numeric_config_value(x, default = numeric(0)))
  if (!length(vals) || any(!is.finite(vals)) || any(vals <= 0L)) {
    stop("Integer CSV value is empty or invalid.", call. = FALSE)
  }
  paste(vals, collapse = ",")
}

ffv2_read_vb_calibration_candidates <- function(path = ffv2_default_vb_calibration_candidates_path()) {
  path <- normalizePath(path, winslash = "/", mustWork = TRUE)
  x <- ffv2_read_csv(path, colClasses = "character")
  missing <- setdiff(ffv2_required_vb_calibration_candidate_columns(), names(x))
  if (length(missing)) {
    stop(sprintf(
      "Candidate registry missing column(s): %s",
      paste(missing, collapse = ", ")
    ), call. = FALSE)
  }
  x <- x[, ffv2_required_vb_calibration_candidate_columns(), drop = FALSE]
  for (nm in names(x)) x[[nm]] <- trimws(as.character(x[[nm]]))
  if (!nrow(x)) stop("Candidate registry must contain at least one row.", call. = FALSE)
  if (any(!nzchar(x$candidate_id))) stop("candidate_id values must be nonempty.", call. = FALSE)
  if (any(!nzchar(x$calibration_id))) stop("calibration_id values must be nonempty.", call. = FALSE)
  if (anyDuplicated(x$candidate_id)) stop("candidate_id values must be unique.", call. = FALSE)
  if (anyDuplicated(x$calibration_id)) stop("calibration_id values must be unique.", call. = FALSE)

  x$trend_C0_scale <- suppressWarnings(as.numeric(x$trend_C0_scale))
  x$seasonal_C0_scale <- suppressWarnings(as.numeric(x$seasonal_C0_scale))
  bad_scale <- !is.finite(x$trend_C0_scale) | x$trend_C0_scale <= 0 |
    !is.finite(x$seasonal_C0_scale) | x$seasonal_C0_scale <= 0
  if (any(bad_scale)) {
    stop(sprintf(
      "Candidate C0 scales must be positive finite values: %s",
      paste(x$candidate_id[bad_scale], collapse = ", ")
    ), call. = FALSE)
  }

  for (i in seq_len(nrow(x))) {
    df <- ffv2_parse_numeric_config_value(x$df_value[[i]], default = numeric(0))
    dim_df <- as.integer(ffv2_parse_numeric_config_value(x$dim_df[[i]], default = numeric(0)))
    if (!length(df) || !length(dim_df) || length(df) != length(dim_df)) {
      stop(sprintf(
        "Candidate %s must have matching df_value and dim_df lengths.",
        x$candidate_id[[i]]
      ), call. = FALSE)
    }
    if (any(!is.finite(df)) || any(df <= 0) || any(df > 1)) {
      stop(sprintf("Candidate %s has invalid discount factors.", x$candidate_id[[i]]),
           call. = FALSE)
    }
    if (any(!is.finite(dim_df)) || any(dim_df <= 0L)) {
      stop(sprintf("Candidate %s has invalid dim_df values.", x$candidate_id[[i]]),
           call. = FALSE)
    }
    x$df_value[[i]] <- ffv2_canonical_numeric_csv(df)
    x$dim_df[[i]] <- ffv2_canonical_integer_csv(dim_df)
  }
  ffv2_stop_stale_paths(x)
  x
}

ffv2_vb_screen_defaults <- function(defaults,
                                    run_tag = NULL,
                                    stored_draws = 500L,
                                    forecast_draws = 500L,
                                    vb_max_iter = 150L,
                                    vb_n_samp = 5000L,
                                    vb_tol = 0.03) {
  if (!is.null(run_tag)) defaults$study$run_tag <- as.character(run_tag)[1L]
  defaults$source$fit_sizes <- 500L
  defaults$models$model_variants <- c("dqlm", "exdqlm")
  defaults$models$inference_methods <- "vb"
  defaults$models$latent_clock_mode <- "post_warmup_source_index"
  defaults$budget$stored_draws <- as.integer(stored_draws)[1L]
  defaults$budget$forecast_draws <- as.integer(forecast_draws)[1L]
  defaults$budget$vb$max_iter <- as.integer(vb_max_iter)[1L]
  defaults$budget$vb$n_samp <- as.integer(vb_n_samp)[1L]
  defaults$budget$vb$tol <- as.numeric(vb_tol)[1L]
  defaults$handoff <- defaults$handoff %||% list()
  defaults$handoff$fit <- TRUE
  defaults$handoff$vb_init <- TRUE
  defaults$handoff$reuse_vb_init <- TRUE
  defaults$handoff$prune_fit_on_success <- FALSE
  defaults
}

ffv2_vb_calibration_screen_subdirs <- function() {
  c(
    "configs", "rows", "health", "metrics", "fit_path_summaries",
    "forecast_path_summaries", "forecast_lead_metrics", "logs", "progress",
    "heartbeats", "artifact_manifests", "manifests", "interfaces",
    "storage", "handoff"
  )
}

ffv2_vb_screen_sentinel_flag <- function(family, tau, model_variant) {
  family <- as.character(family)
  tau <- round(as.numeric(tau), 8L)
  model_variant <- as.character(model_variant)
  (family == "normal" & abs(tau - 0.25) < 1e-8 & model_variant == "dqlm") |
    (family == "normal" & abs(tau - 0.50) < 1e-8 & model_variant %in% c("dqlm", "exdqlm")) |
    (family == "laplace" & abs(tau - 0.05) < 1e-8 & model_variant %in% c("dqlm", "exdqlm")) |
    (family == "gausmix" & abs(tau - 0.50) < 1e-8 & model_variant %in% c("dqlm", "exdqlm"))
}

ffv2_vb_screen_row_paths <- function(row, run_root, row_key) {
  row$row_config_path <- file.path(run_root, "configs", sprintf("%s_config.json", row_key))
  row$row_status_path <- file.path(run_root, "rows", sprintf("%s_status.csv", row_key))
  row$row_health_path <- file.path(run_root, "health", sprintf("%s_health.csv", row_key))
  row$row_metrics_path <- file.path(run_root, "metrics", sprintf("%s_metrics.csv", row_key))
  row$fit_path_summary_path <- file.path(run_root, "fit_path_summaries", sprintf("%s_fit_path_summary.csv", row_key))
  row$forecast_path_summary_path <- file.path(run_root, "forecast_path_summaries", sprintf("%s_forecast_path_summary.csv", row_key))
  row$row_progress_path <- file.path(run_root, "progress", sprintf("%s_progress.csv", row_key))
  row$row_heartbeat_path <- file.path(run_root, "heartbeats", sprintf("%s_heartbeat.json", row_key))
  row$forecast_lead_metrics_path <- file.path(run_root, "forecast_lead_metrics", sprintf("%s_forecast_lead_metrics.csv", row_key))
  row$artifact_manifest_path <- file.path(run_root, "artifact_manifests", sprintf("%s_artifacts.json", row_key))
  row$fit_handoff_path <- file.path(run_root, "handoff", sprintf("%s_fit_object.ffv2handoff", row_key))
  row$fit_handoff_manifest_path <- file.path(run_root, "handoff", sprintf("%s_fit_object_manifest.json", row_key))
  row$vb_init_handoff_path <- file.path(run_root, "handoff", sprintf("%s_vb_init.ffv2handoff", row_key))
  row$vb_init_handoff_manifest_path <- file.path(run_root, "handoff", sprintf("%s_vb_init_manifest.json", row_key))
  row$log_path <- file.path(run_root, "logs", sprintf("%s.log", row_key))
  row
}

ffv2_vb_screen_candidate_models <- function(defaults, candidate) {
  models <- defaults$models %||% list()
  models$calibration_id <- as.character(candidate$calibration_id[[1L]])
  models$latent_clock_mode <- "post_warmup_source_index"
  models$trend_C0_scale <- as.numeric(candidate$trend_C0_scale[[1L]])
  models$seasonal_C0_scale <- as.numeric(candidate$seasonal_C0_scale[[1L]])
  models$df_value <- ffv2_parse_numeric_config_value(candidate$df_value[[1L]], default = c(0.98, 0.98))
  models$dim_df <- as.integer(ffv2_parse_numeric_config_value(candidate$dim_df[[1L]], default = c(2L, 4L)))
  models
}

ffv2_prepare_vb_calibration_screen_manifest <- function(defaults,
                                                        registry,
                                                        candidates,
                                                        run_root = NULL,
                                                        dry_run = FALSE,
                                                        overwrite = FALSE) {
  repo_root <- ffv2_repo_root()
  if (is.null(run_root)) {
    run_root <- ffv2_resolve_path(
      file.path(defaults$study$results_root, defaults$study$run_tag),
      repo_root = repo_root,
      must_work = FALSE
    )
  } else {
    run_root <- ffv2_resolve_path(run_root, repo_root = repo_root, must_work = FALSE)
  }
  if (dir.exists(run_root) && !isTRUE(overwrite) && !isTRUE(dry_run)) {
    stop(sprintf("Run root already exists; refusing to overwrite: %s", run_root), call. = FALSE)
  }
  if (!isTRUE(dry_run)) {
    ffv2_ensure_dir(run_root)
    invisible(lapply(file.path(run_root, ffv2_vb_calibration_screen_subdirs()), ffv2_ensure_dir))
  }

  defaults <- ffv2_vb_screen_defaults(defaults, run_tag = defaults$study$run_tag)
  candidates <- as.data.frame(candidates, stringsAsFactors = FALSE)
  required <- ffv2_required_vb_calibration_candidate_columns()
  missing <- setdiff(required, names(candidates))
  if (length(missing)) {
    stop(sprintf("Candidate table missing column(s): %s", paste(missing, collapse = ", ")),
         call. = FALSE)
  }
  row_manifest_path <- file.path(run_root, "manifests", "row_manifest.csv")
  base_manifest <- ffv2_prepare_manifest(
    defaults = defaults,
    registry = registry,
    run_root = run_root,
    dry_run = TRUE,
    overwrite = TRUE
  )
  base_manifest <- base_manifest[
    as.integer(base_manifest$fit_size) == 500L &
      as.character(base_manifest$inference) == "vb" &
      as.character(base_manifest$model_variant) %in% c("dqlm", "exdqlm"),
    ,
    drop = FALSE
  ]
  if (!nrow(base_manifest)) stop("Base VB screen manifest has zero rows.", call. = FALSE)

  rows <- list()
  row_id <- 0L
  for (i in seq_len(nrow(base_manifest))) {
    base_row <- base_manifest[i, , drop = FALSE]
    base_spec_id <- as.character(base_row$spec_id[[1L]])
    for (j in seq_len(nrow(candidates))) {
      candidate <- candidates[j, , drop = FALSE]
      row_id <- row_id + 1L
      row_key <- sprintf("row_%04d", row_id)
      row <- base_row
      row$row_id <- row_id
      row$row_key <- row_key
      row$run_root <- run_root
      row$row_manifest_path <- row_manifest_path
      row$phase <- "vb_full"
      row$status <- "pending"
      row$validation_stage <- "fit-only"
      row$smoke <- FALSE
      row$pilot <- FALSE
      row$base_spec_id <- base_spec_id
      row$candidate_id <- as.character(candidate$candidate_id[[1L]])
      row$screen_stage <- "fit_only_sentinel_screen"
      row$candidate_notes <- as.character(candidate$notes[[1L]])
      row$screen_sentinel <- ffv2_vb_screen_sentinel_flag(row$family, row$tau, row$model_variant)
      row <- ffv2_vb_screen_row_paths(row, run_root, row_key)

      cfg <- as.list(row)
      cfg$repo_root <- repo_root
      cfg$harness_root <- ffv2_harness_root()
      cfg$defaults_path <- defaults$.__defaults_path__ %||% ffv2_default_defaults_path()
      cfg$runtime <- ffv2_apply_runtime_phase_defaults(defaults$runtime, smoke = FALSE)
      cfg$budget <- defaults$budget
      cfg$models <- ffv2_vb_screen_candidate_models(defaults, candidate)
      cfg$calibration_id <- cfg$models$calibration_id
      cfg$latent_clock_mode <- cfg$models$latent_clock_mode
      cfg$trend_C0_scale <- cfg$models$trend_C0_scale
      cfg$seasonal_C0_scale <- cfg$models$seasonal_C0_scale
      cfg$df_value <- as.character(candidate$df_value[[1L]])
      cfg$dim_df <- as.character(candidate$dim_df[[1L]])
      cfg$retention <- defaults$retention
      cfg$handoff <- defaults$handoff %||% list(
        fit = TRUE,
        vb_init = TRUE,
        reuse_vb_init = TRUE,
        prune_fit_on_success = FALSE
      )
      cfg$run_override_applied <- FALSE
      cfg$run_override_id <- ""
      cfg$run_override_reason <- ""
      cfg <- ffv2_sync_model_provenance(cfg)
      cfg$base_spec_id <- base_spec_id
      cfg$spec_id <- ffv2_make_spec_id(cfg, model_family = "exdqlm_dqlm")

      for (nm in c(
        "spec_id", "base_spec_id", "calibration_id", "latent_clock_mode",
        "latent_clock_start_source_index", "latent_clock_offset",
        "model_C0_scale", "trend_C0_scale", "seasonal_C0_scale", "df_value",
        "dim_df", "dynamic_model_period", "dynamic_model_harmonics",
        "model_spec_hash", "run_override_applied", "run_override_id",
        "run_override_reason"
      )) {
        row[[nm]] <- cfg[[nm]]
      }
      rows[[length(rows) + 1L]] <- row
      if (!isTRUE(dry_run)) ffv2_write_json(cfg, row$row_config_path[[1L]])
    }
  }

  manifest <- ffv2_bind_rows(rows)
  manifest <- manifest[, !duplicated(names(manifest)), drop = FALSE]
  rownames(manifest) <- NULL
  candidate_key <- paste(manifest$source_cell_id, manifest$model_variant, manifest$candidate_id, sep = "|")
  if (anyDuplicated(candidate_key)) {
    stop("Duplicate (source_cell_id, model_variant, candidate_id) rows in calibration screen manifest.",
         call. = FALSE)
  }
  if (anyDuplicated(manifest$spec_id)) stop("Duplicate spec_id values in calibration screen manifest.", call. = FALSE)
  ffv2_stop_stale_paths(manifest)

  if (!isTRUE(dry_run)) {
    verification <- ffv2_verify_source_windows(registry, stop_on_fail = TRUE)
    sentinels <- manifest[as.logical(manifest$screen_sentinel), , drop = FALSE]
    sentinel_cols <- intersect(
      c("row_id", "row_key", "candidate_id", "spec_id", "family", "tau", "fit_size", "model_variant", "inference", "phase"),
      names(sentinels)
    )
    ffv2_write_csv(registry, file.path(run_root, "manifests", "source_registry.csv"))
    ffv2_write_csv(verification, file.path(run_root, "manifests", "source_window_verification.csv"))
    ffv2_write_csv(candidates, file.path(run_root, "manifests", "candidate_registry.csv"))
    ffv2_write_csv(manifest, row_manifest_path)
    ffv2_write_csv(sentinels[, sentinel_cols, drop = FALSE], file.path(run_root, "manifests", "sentinel_rows.csv"))
    writeLines(as.character(sentinels$row_id), file.path(run_root, "manifests", "sentinel_row_ids.txt"))
    ffv2_write_json(ffv2_runtime_metadata(repo_root), file.path(run_root, "manifests", "runtime_metadata.json"))
  }
  manifest
}

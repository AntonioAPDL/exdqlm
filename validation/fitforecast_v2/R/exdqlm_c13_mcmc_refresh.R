ffv2_c13_mcmc_candidate_id <- function() {
  "c13_trend100_season1_df0995s099"
}

ffv2_c13_mcmc_default_run_tag <- function() {
  ffv2_c13_mcmc_default_full_run_tag()
}

ffv2_c13_mcmc_default_gate_run_tag <- function() {
  "20260704_exdqlm_dqlm_c13_mcmc_500obs_refresh_v2"
}

ffv2_c13_mcmc_default_full_run_tag <- function() {
  "20260704_exdqlm_dqlm_c13_mcmc_500obs_full_v2"
}

ffv2_c13_mcmc_default_promotion_id <- function() {
  "exdqlm_dqlm_c13_mcmc_500obs_authoritative_20260704"
}

ffv2_c13_mcmc_candidate <- function(candidates = NULL,
                                    candidate_id = ffv2_c13_mcmc_candidate_id()) {
  if (is.null(candidates)) {
    candidates <- ffv2_read_vb_calibration_candidates()
  }
  out <- candidates[as.character(candidates$candidate_id) == as.character(candidate_id), , drop = FALSE]
  if (nrow(out) != 1L) {
    stop(sprintf("Expected exactly one c13 candidate row for '%s'.", candidate_id), call. = FALSE)
  }
  out
}

ffv2_c13_mcmc_defaults <- function(defaults,
                                   run_tag = NULL,
                                   candidate = NULL,
                                   workers = 12L,
                                   gate_rows = TRUE) {
  candidate <- ffv2_c13_mcmc_candidate(candidate)
  if (!is.null(run_tag)) defaults$study$run_tag <- as.character(run_tag)[1L]
  defaults$source$fit_sizes <- 500L
  defaults$models <- ffv2_vb_screen_candidate_models(defaults, candidate)
  defaults$models$model_variants <- c("dqlm", "exdqlm")
  defaults$models$inference_methods <- "mcmc"
  defaults$models$latent_clock_mode <- "post_warmup_source_index"

  defaults$budget$stored_draws <- as.integer(defaults$budget$stored_draws %||% 2000L)
  defaults$budget$forecast_draws <- as.integer(defaults$budget$forecast_draws %||% 2000L)
  defaults$budget$vb$max_iter <- 150L
  defaults$budget$vb$tol <- 0.03
  defaults$budget$vb$n_samp <- 5000L
  defaults$budget$mcmc$n_burn <- 5000L
  defaults$budget$mcmc$n_mcmc <- 20000L
  defaults$budget$mcmc$thin <- 1L
  defaults$budget$mcmc$init_from_vb <- TRUE

  defaults$runtime$threads <- 1L
  defaults$runtime$progress_every <- 50L
  defaults$runtime$trace_every <- 50L
  defaults$runtime$heartbeat_seconds <- 1800L
  defaults$runtime$healthcheck_stale_seconds <- 1800L
  defaults$runtime$workers$mcmc_tt500 <- as.integer(workers)[1L]
  defaults$runtime$workers$smoke <- 1L
  defaults$runtime$workers$pilot <- 4L

  defaults$handoff <- defaults$handoff %||% list()
  defaults$handoff$fit <- TRUE
  defaults$handoff$vb_init <- TRUE
  defaults$handoff$reuse_vb_init <- TRUE
  defaults$handoff$prune_fit_on_success <- TRUE

  if (isTRUE(gate_rows)) {
    defaults$smoke$rows <- list(
      list(family = "normal", tau = 0.50, fit_size = 500L, model_variant = "dqlm", inference = "mcmc"),
      list(family = "laplace", tau = 0.05, fit_size = 500L, model_variant = "exdqlm", inference = "mcmc")
    )
    defaults$pilot$rows <- list(
      list(family = "gausmix", tau = 0.05, fit_size = 500L, model_variant = "dqlm", inference = "mcmc"),
      list(family = "laplace", tau = 0.05, fit_size = 500L, model_variant = "dqlm", inference = "mcmc"),
      list(family = "gausmix", tau = 0.50, fit_size = 500L, model_variant = "exdqlm", inference = "mcmc"),
      list(family = "normal", tau = 0.50, fit_size = 500L, model_variant = "exdqlm", inference = "mcmc")
    )
  } else {
    defaults$smoke$rows <- list()
    defaults$pilot$rows <- list()
  }
  defaults
}

ffv2_stamp_c13_mcmc_row <- function(row, candidate) {
  row$candidate_id <- as.character(candidate$candidate_id[[1L]])
  row$screen_stage <- "current_best_c13_mcmc_refresh"
  row$candidate_notes <- as.character(candidate$notes[[1L]])
  row$screen_sentinel <- FALSE
  row$calibration_id <- as.character(candidate$calibration_id[[1L]])
  row$trend_C0_scale <- as.numeric(candidate$trend_C0_scale[[1L]])
  row$seasonal_C0_scale <- as.numeric(candidate$seasonal_C0_scale[[1L]])
  row$df_value <- as.character(candidate$df_value[[1L]])
  row$dim_df <- as.character(candidate$dim_df[[1L]])
  row
}

ffv2_stamp_c13_mcmc_config <- function(config, candidate) {
  config <- ffv2_stamp_c13_mcmc_row(config, candidate)
  config$models <- ffv2_vb_screen_candidate_models(config, candidate)
  config$models$model_variants <- c("dqlm", "exdqlm")
  config$models$inference_methods <- "mcmc"
  config$run_override_applied <- isTRUE(config$run_override_applied %||% FALSE)
  config$run_override_id <- as.character(config$run_override_id %||% "")
  config$run_override_reason <- as.character(config$run_override_reason %||% "")
  ffv2_sync_model_provenance(config)
}

ffv2_prepare_c13_mcmc_refresh_manifest <- function(defaults,
                                                   registry,
                                                   candidate = NULL,
                                                   run_root = NULL,
                                                   dry_run = FALSE,
                                                   overwrite = FALSE,
                                                   workers = 12L,
                                                   gate_rows = TRUE) {
  candidate <- ffv2_c13_mcmc_candidate(candidate)
  defaults <- ffv2_c13_mcmc_defaults(defaults, candidate = candidate, workers = workers, gate_rows = gate_rows)
  manifest <- ffv2_prepare_manifest(
    defaults = defaults,
    registry = registry,
    run_root = run_root,
    dry_run = dry_run,
    overwrite = overwrite
  )
  keep <- as.integer(manifest$fit_size) == 500L &
    as.character(manifest$inference) == "mcmc" &
    as.character(manifest$model_variant) %in% c("dqlm", "exdqlm")
  manifest <- manifest[keep, , drop = FALSE]
  if (nrow(manifest) != 18L) {
    stop(sprintf("Expected 18 c13 MCMC TT500 rows; found %d.", nrow(manifest)), call. = FALSE)
  }

  for (nm in c("candidate_id", "screen_stage", "candidate_notes", "screen_sentinel")) {
    if (!nm %in% names(manifest)) manifest[[nm]] <- NA
  }

  for (i in seq_len(nrow(manifest))) {
    row <- as.list(manifest[i, , drop = FALSE])
    row <- ffv2_stamp_c13_mcmc_row(row, candidate)
    cfg <- row
    if (!isTRUE(dry_run)) {
      cfg <- ffv2_read_json(row$row_config_path[[1L]])
      cfg <- ffv2_stamp_c13_mcmc_config(cfg, candidate)
      ffv2_write_json(cfg, row$row_config_path[[1L]])
      row <- utils::modifyList(row, cfg[c(
        "candidate_id", "screen_stage", "candidate_notes", "screen_sentinel",
        "calibration_id", "latent_clock_mode", "latent_clock_start_source_index",
        "latent_clock_offset", "model_C0_scale", "trend_C0_scale",
        "seasonal_C0_scale", "df_value", "dim_df", "dynamic_model_period",
        "dynamic_model_harmonics", "model_spec_hash", "spec_id"
      )], keep.null = TRUE)
    } else {
      row <- ffv2_sync_model_provenance(row)
      row$spec_id <- ffv2_make_spec_id(row, model_family = "exdqlm_dqlm")
    }
    for (nm in names(row)) {
      if (!nm %in% names(manifest)) manifest[[nm]] <- NA
      if (length(row[[nm]]) == 1L) manifest[[nm]][[i]] <- row[[nm]]
    }
  }
  rownames(manifest) <- NULL
  ffv2_stop_stale_paths(manifest)
  if (!isTRUE(dry_run)) {
    run_root_out <- unique(manifest$run_root)[[1L]]
    ffv2_write_csv(candidate, file.path(run_root_out, "manifests", "c13_mcmc_candidate.csv"))
    smoke_flag <- as.logical(manifest$smoke %in% c(TRUE, "TRUE", "true", "1"))
    pilot_flag <- as.logical(manifest$pilot %in% c(TRUE, "TRUE", "true", "1"))
    smoke_rows <- manifest[smoke_flag, , drop = FALSE]
    pilot_rows <- manifest[pilot_flag, , drop = FALSE]
    ffv2_write_csv(smoke_rows[, intersect(c(
      "row_id", "row_key", "candidate_id", "spec_id", "family", "tau",
      "fit_size", "model_variant", "inference", "phase"
    ), names(smoke_rows)), drop = FALSE], file.path(run_root_out, "manifests", "smoke_rows.csv"))
    ffv2_write_csv(pilot_rows[, intersect(c(
      "row_id", "row_key", "candidate_id", "spec_id", "family", "tau",
      "fit_size", "model_variant", "inference", "phase"
    ), names(pilot_rows)), drop = FALSE], file.path(run_root_out, "manifests", "pilot_rows.csv"))
    writeLines(as.character(smoke_rows$row_id), file.path(run_root_out, "manifests", "smoke_row_ids.txt"))
    writeLines(as.character(pilot_rows$row_id), file.path(run_root_out, "manifests", "pilot_row_ids.txt"))
    ffv2_write_csv(manifest, unique(manifest$row_manifest_path)[[1L]])
  }
  manifest
}

ffv2_c13_mcmc_interface_rows <- function(interface) {
  interface[
    as.character(interface$model_family) == "exdqlm_dqlm" &
      as.character(interface$candidate_id) == ffv2_c13_mcmc_candidate_id() &
      as.character(interface$inference) == "mcmc" &
      as.integer(interface$fit_size) == 500L,
    ,
    drop = FALSE
  ]
}

ffv2_c13_mcmc_cell_summary <- function(rows) {
  if (!nrow(rows)) return(data.frame())
  weighted <- function(x, w) {
    x <- as.numeric(x)
    w <- as.numeric(w)
    ok <- is.finite(x) & is.finite(w) & w > 0
    if (!any(ok)) return(NA_real_)
    sum(x[ok] * w[ok]) / sum(w[ok])
  }
  key <- paste(rows$model_variant, rows$family, rows$tau, sep = "\r")
  out <- lapply(unique(key), function(kk) {
    block <- rows[key == kk, , drop = FALSE]
    data.frame(
      model_variant = as.character(block$model_variant[[1L]]),
      family = as.character(block$family[[1L]]),
      tau = as.numeric(block$tau[[1L]]),
      candidate_id = as.character(block$candidate_id[[1L]]),
      calibration_id = as.character(block$calibration_id[[1L]]),
      n_leads = length(unique(as.integer(block$forecast_lead))),
      n_origins_scored_total = sum(as.numeric(block$n_origins_scored), na.rm = TRUE),
      fit_qtrue_rmse = as.numeric(block$fit_qtrue_rmse[[1L]]),
      fit_check = as.numeric(block$fit_pinball_mean[[1L]]),
      forecast_qtrue_mae = weighted(block$forecast_qtrue_mae, block$n_origins_scored),
      forecast_qtrue_rmse = weighted(block$forecast_qtrue_rmse, block$n_origins_scored),
      forecast_check = weighted(block$forecast_pinball_mean, block$n_origins_scored),
      runtime_sec_total = as.numeric(block$runtime_sec_total[[1L]]),
      source_registry_hash_value = as.character(block$source_registry_hash_value[[1L]]),
      validation_branch = as.character(block$validation_branch[[1L]]),
      validation_commit = paste(sort(unique(as.character(block$validation_commit))), collapse = ";"),
      run_tag = as.character(block$run_tag[[1L]]),
      package_version = as.character(block$package_version[[1L]]),
      forecast_protocol = as.character(block$forecast_protocol[[1L]]),
      state_update_method = as.character(block$state_update_method[[1L]]),
      max_lead_configured = as.integer(block$max_lead_configured[[1L]]),
      origin_stride = as.integer(block$origin_stride[[1L]]),
      train_start_source_index = as.integer(block$train_start_source_index[[1L]]),
      train_end_source_index = as.integer(block$train_end_source_index[[1L]]),
      forecast_origin_source_index = as.integer(block$forecast_origin_source_index[[1L]]),
      forecast_block_start_source_index = as.integer(block$forecast_block_start_source_index[[1L]]),
      forecast_block_end_source_index = as.integer(block$forecast_block_end_source_index[[1L]]),
      status = paste(sort(unique(as.character(block$status))), collapse = ";"),
      health_gate = paste(sort(unique(as.character(block$health_gate))), collapse = ";"),
      signoff_grade = paste(sort(unique(as.character(block$signoff_grade))), collapse = ";"),
      stringsAsFactors = FALSE
    )
  })
  out <- do.call(rbind, out)
  out[order(out$family, out$tau, out$model_variant), , drop = FALSE]
}

ffv2_validate_c13_mcmc_interface <- function(rows,
                                             expected_cells = 18L,
                                             expected_leads = 30L) {
  issues <- character(0)
  if (nrow(rows) != as.integer(expected_cells) * as.integer(expected_leads)) {
    issues <- c(issues, sprintf("Expected %d lead rows; observed %d.",
                                as.integer(expected_cells) * as.integer(expected_leads), nrow(rows)))
  }
  if (nrow(rows)) {
    if (any(as.character(rows$status) != "done")) issues <- c(issues, "Not all rows have status=done.")
    if (any(as.character(rows$health_gate) != "PASS")) issues <- c(issues, "Not all rows have health_gate=PASS.")
    if (any(as.character(rows$candidate_id) != ffv2_c13_mcmc_candidate_id())) {
      issues <- c(issues, "Candidate id mismatch.")
    }
    key <- paste(rows$model_variant, rows$family, rows$tau, sep = "\r")
    if (length(unique(key)) != as.integer(expected_cells)) {
      issues <- c(issues, sprintf("Expected %d model/family/tau cells; observed %d.",
                                  as.integer(expected_cells), length(unique(key))))
    }
    for (kk in unique(key)) {
      leads <- sort(unique(as.integer(rows$forecast_lead[key == kk])))
      if (!identical(leads, seq_len(as.integer(expected_leads)))) {
        issues <- c(issues, sprintf("Incomplete lead grid for key %s.", kk))
      }
    }
    metric_cols <- c("fit_qtrue_rmse", "fit_pinball_mean", "forecast_qtrue_mae",
                     "forecast_qtrue_rmse", "forecast_pinball_mean", "runtime_sec_total",
                     "n_origins_scored")
    if (any(!is.finite(as.numeric(unlist(rows[intersect(metric_cols, names(rows))], use.names = FALSE))))) {
      issues <- c(issues, "Non-finite metric values detected.")
    }
  }
  issues
}

ffv2_c13_mcmc_expected_cells <- function() {
  out <- expand.grid(
    model_variant = c("dqlm", "exdqlm"),
    family = c("gausmix", "laplace", "normal"),
    tau = c(0.05, 0.25, 0.50),
    stringsAsFactors = FALSE
  )
  out[order(out$family, out$tau, out$model_variant), , drop = FALSE]
}

ffv2_c13_mcmc_cell_key <- function(x) {
  paste(as.character(x$model_variant), as.character(x$family),
        sprintf("%.8f", as.numeric(x$tau)), sep = "\r")
}

ffv2_c13_mcmc_missing_cells <- function(rows) {
  expected <- ffv2_c13_mcmc_expected_cells()
  observed <- if (nrow(rows)) unique(ffv2_c13_mcmc_cell_key(rows)) else character(0)
  expected[!ffv2_c13_mcmc_cell_key(expected) %in% observed, , drop = FALSE]
}

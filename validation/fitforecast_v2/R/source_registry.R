ffv2_source_paths <- function(defaults, family, tau) {
  source_root <- as.character(defaults$source$root)[1L]
  scenario <- as.character(defaults$study$scenario_id)[1L]
  tau_label <- ffv2_tau_label(tau)
  root <- file.path(source_root, scenario, family, sprintf("tau_%s", tau_label))
  list(
    source_root = root,
    series_wide_path = file.path(root, "series_wide.csv"),
    true_quantile_grid_path = file.path(root, "true_quantile_grid.csv"),
    sim_output_path = file.path(root, "sim_output.rds"),
    meta_path = file.path(root, "meta.txt"),
    tau_label = tau_label
  )
}

ffv2_parse_meta_txt <- function(path) {
  if (!file.exists(path)) return(list())
  lines <- readLines(path, warn = FALSE)
  out <- list()
  for (line in lines) {
    if (!grepl(":", line, fixed = TRUE)) next
    key <- trimws(sub(":.*$", "", line))
    val <- trimws(sub("^[^:]+:", "", line))
    out[[key]] <- val
  }
  out
}

ffv2_parse_numeric_list <- function(x, default = numeric()) {
  if (is.null(x) || is.na(x) || !nzchar(x)) return(default)
  vals <- strsplit(as.character(x), ",", fixed = TRUE)[[1L]]
  as.numeric(trimws(vals))
}

ffv2_parse_amp_phase <- function(x, default = c(0, 0)) {
  if (is.null(x) || is.na(x) || !nzchar(x)) return(default)
  vals <- strsplit(as.character(x), "@", fixed = TRUE)[[1L]]
  if (length(vals) != 2L) return(default)
  as.numeric(trimws(vals))
}

ffv2_training_window <- function(fit_size, defaults) {
  fit_size <- as.integer(fit_size)[1L]
  train_end <- as.integer(defaults$source$forecast_origin_source_index)[1L]
  data.frame(
    fit_size = fit_size,
    train_start_source_index = train_end - fit_size + 1L,
    train_end_source_index = train_end,
    stringsAsFactors = FALSE
  )
}

ffv2_expected_source_cells <- function(defaults) {
  rows <- list()
  for (family in as.character(defaults$source$families)) {
    for (tau in as.numeric(defaults$source$taus)) {
      for (fit_size in as.integer(defaults$source$fit_sizes)) {
        win <- ffv2_training_window(fit_size, defaults)
        rows[[length(rows) + 1L]] <- data.frame(
          scenario_id = as.character(defaults$study$scenario_id)[1L],
          family = family,
          tau = tau,
          tau_label = ffv2_tau_label(tau),
          fit_size = fit_size,
          train_start_source_index = win$train_start_source_index,
          train_end_source_index = win$train_end_source_index,
          forecast_origin_source_index = as.integer(defaults$source$forecast_origin_source_index)[1L],
          forecast_start_source_index = as.integer(defaults$source$forecast_start_source_index)[1L],
          forecast_end_source_index = as.integer(defaults$source$forecast_end_source_index)[1L],
          stringsAsFactors = FALSE
        )
      }
    }
  }
  ffv2_bind_rows(rows)
}

ffv2_source_hashes <- function(paths, require_sources = TRUE) {
  required <- c("series_wide_path", "true_quantile_grid_path", "meta_path")
  missing <- required[!file.exists(unlist(paths[required], use.names = FALSE))]
  if (isTRUE(require_sources) && length(missing)) {
    stop(sprintf("Missing source file(s): %s",
                 paste(unlist(paths[missing], use.names = FALSE), collapse = ", ")),
         call. = FALSE)
  }
  list(
    series_wide_sha256 = ffv2_file_sha256(paths$series_wide_path),
    true_quantile_grid_sha256 = ffv2_file_sha256(paths$true_quantile_grid_path),
    sim_output_sha256 = ffv2_file_sha256(paths$sim_output_path),
    meta_sha256 = ffv2_file_sha256(paths$meta_path)
  )
}

ffv2_collect_source_registry <- function(defaults, require_sources = TRUE) {
  expected <- ffv2_expected_source_cells(defaults)
  rows <- vector("list", nrow(expected))
  for (i in seq_len(nrow(expected))) {
    cell <- expected[i, , drop = FALSE]
    paths <- ffv2_source_paths(defaults, cell$family, cell$tau)
    meta <- ffv2_parse_meta_txt(paths$meta_path)
    hashes <- ffv2_source_hashes(paths, require_sources = require_sources)
    h1 <- ffv2_parse_amp_phase(meta$harmonic1_amp_phase %||% NA_character_)
    h2 <- ffv2_parse_amp_phase(meta$harmonic2_amp_phase %||% NA_character_)
    source_present <- file.exists(paths$series_wide_path) &&
      file.exists(paths$true_quantile_grid_path) &&
      file.exists(paths$meta_path)
    rows[[i]] <- data.frame(
      source_cell_id = sprintf(
        "%s::%s::%s::TT%d",
        cell$scenario_id, cell$family, cell$tau_label, cell$fit_size
      ),
      scenario_id = cell$scenario_id,
      family = cell$family,
      tau = cell$tau,
      tau_label = cell$tau_label,
      fit_size = cell$fit_size,
      source_present = source_present,
      source_root = paths$source_root,
      series_wide_path = paths$series_wide_path,
      true_quantile_grid_path = paths$true_quantile_grid_path,
      sim_output_path = paths$sim_output_path,
      meta_path = paths$meta_path,
      series_wide_sha256 = hashes$series_wide_sha256,
      true_quantile_grid_sha256 = hashes$true_quantile_grid_sha256,
      sim_output_sha256 = hashes$sim_output_sha256,
      meta_sha256 = hashes$meta_sha256,
      TT_total = as.integer(defaults$source$TT_total)[1L],
      TT_warmup = as.integer(defaults$source$TT_warmup)[1L],
      TT_main = as.integer(defaults$source$TT_main)[1L],
      train_start_source_index = cell$train_start_source_index,
      train_end_source_index = cell$train_end_source_index,
      forecast_origin_source_index = cell$forecast_origin_source_index,
      forecast_start_source_index = cell$forecast_start_source_index,
      forecast_end_source_index = cell$forecast_end_source_index,
      forecast_horizon_max = cell$forecast_end_source_index - cell$forecast_origin_source_index,
      period = as.integer(meta$period %||% NA_character_),
      harmonics = meta$harmonics %||% NA_character_,
      C0_scale = as.numeric(meta$C0_scale %||% NA_character_),
      level0 = as.numeric(meta$level0 %||% NA_character_),
      slope0 = as.numeric(meta$slope0 %||% NA_character_),
      harmonic1_amplitude = h1[[1L]],
      harmonic1_phase = h1[[2L]],
      harmonic2_amplitude = h2[[1L]],
      harmonic2_phase = h2[[2L]],
      state_noise_sd = meta$state_noise_sd %||% NA_character_,
      stringsAsFactors = FALSE
    )
  }
  registry <- ffv2_bind_rows(rows)
  rownames(registry) <- NULL
  ffv2_stop_stale_paths(registry)
  registry
}

ffv2_read_truth_for_tau <- function(path, tau) {
  truth <- ffv2_read_csv(path)
  if (!"source_index" %in% names(truth) && "t" %in% names(truth)) {
    truth$source_index <- as.integer(truth$t)
  }
  if (!"q_true" %in% names(truth) && "q_target" %in% names(truth)) {
    truth$q_true <- truth$q_target
  }
  if ("tau" %in% names(truth)) {
    truth <- truth[abs(as.numeric(truth$tau) - as.numeric(tau)) < 1e-8, , drop = FALSE]
  }
  truth
}

ffv2_verify_source_windows <- function(registry, stop_on_fail = TRUE) {
  rows <- vector("list", nrow(registry))
  for (i in seq_len(nrow(registry))) {
    x <- registry[i, , drop = FALSE]
    status <- "PASS"
    notes <- character()
    train_n <- NA_integer_
    forecast_n <- NA_integer_
    n_total <- NA_integer_
    if (!file.exists(x$series_wide_path)) {
      status <- "MISSING"
      notes <- c(notes, "missing series_wide_path")
    } else {
      series <- ffv2_read_csv(x$series_wide_path)
      if (!"source_index" %in% names(series) && "t" %in% names(series)) {
        series$source_index <- as.integer(series$t)
      }
      if (!all(c("source_index", "y") %in% names(series))) {
        status <- "FAIL"
        notes <- c(notes, "series_wide.csv must contain source_index/t and y")
      } else {
        idx <- as.integer(series$source_index)
        n_total <- length(idx)
        if (!identical(idx, seq_len(n_total))) {
          status <- "FAIL"
          notes <- c(notes, "source indices are not contiguous 1:n")
        }
        train_idx <- x$train_start_source_index:x$train_end_source_index
        fore_idx <- x$forecast_start_source_index:x$forecast_end_source_index
        train_n <- sum(idx %in% train_idx)
        forecast_n <- sum(idx %in% fore_idx)
        if (train_n != x$fit_size) {
          status <- "FAIL"
          notes <- c(notes, sprintf("train_n=%s expected %s", train_n, x$fit_size))
        }
        if (forecast_n != x$forecast_horizon_max) {
          status <- "FAIL"
          notes <- c(notes, sprintf("forecast_n=%s expected %s", forecast_n, x$forecast_horizon_max))
        }
      }
    }
    if (!file.exists(x$true_quantile_grid_path)) {
      status <- if (identical(status, "PASS")) "MISSING" else status
      notes <- c(notes, "missing true_quantile_grid_path")
    } else if (!identical(status, "MISSING")) {
      truth <- ffv2_read_truth_for_tau(x$true_quantile_grid_path, x$tau)
      if (!all(c("source_index", "q_true") %in% names(truth))) {
        status <- "FAIL"
        notes <- c(notes, "truth grid must contain source_index/t and q_true/q_target")
      } else {
        needed <- c(x$train_start_source_index:x$train_end_source_index,
                    x$forecast_start_source_index:x$forecast_end_source_index)
        if (!all(needed %in% as.integer(truth$source_index))) {
          status <- "FAIL"
          notes <- c(notes, "truth grid missing train or forecast source indices")
        }
      }
    }
    rows[[i]] <- data.frame(
      source_cell_id = x$source_cell_id,
      family = x$family,
      tau = x$tau,
      fit_size = x$fit_size,
      train_start_source_index = x$train_start_source_index,
      train_end_source_index = x$train_end_source_index,
      forecast_start_source_index = x$forecast_start_source_index,
      forecast_end_source_index = x$forecast_end_source_index,
      n_total = n_total,
      train_n = train_n,
      forecast_n = forecast_n,
      status = status,
      notes = paste(notes, collapse = "; "),
      stringsAsFactors = FALSE
    )
  }
  out <- ffv2_bind_rows(rows)
  if (isTRUE(stop_on_fail) && any(out$status != "PASS")) {
    stop("Source window verification failed:\n",
         paste(utils::capture.output(print(out[out$status != "PASS", , drop = FALSE])), collapse = "\n"),
         call. = FALSE)
  }
  out
}

ffv2_smoke_flag <- function(row, defaults) {
  smoke <- defaults$smoke$rows %||% list()
  any(vapply(smoke, function(x) {
    identical(as.character(x$family), as.character(row$family)) &&
      abs(as.numeric(x$tau) - as.numeric(row$tau)) < 1e-8 &&
      identical(as.integer(x$fit_size), as.integer(row$fit_size)) &&
      identical(as.character(x$model_variant), as.character(row$model_variant)) &&
      identical(as.character(x$inference), as.character(row$inference))
  }, logical(1)))
}

ffv2_manifest_phase <- function(inference, fit_size) {
  if (identical(as.character(inference), "vb")) return("vb_full")
  if (as.integer(fit_size)[1L] == 500L) return("mcmc_tt500")
  "mcmc_tt5000"
}

ffv2_prepare_manifest <- function(defaults,
                                  registry,
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

  subdirs <- c("configs", "rows", "health", "metrics", "fit_path_summaries",
               "forecast_path_summaries", "logs", "manifests", "interfaces", "storage")
  if (!isTRUE(dry_run)) {
    ffv2_ensure_dir(run_root)
    invisible(lapply(file.path(run_root, subdirs), ffv2_ensure_dir))
  }

  rows <- list()
  row_id <- 0L
  for (i in seq_len(nrow(registry))) {
    cell <- registry[i, , drop = FALSE]
    for (model_variant in as.character(defaults$models$model_variants)) {
      for (inference in as.character(defaults$models$inference_methods)) {
        row_id <- row_id + 1L
        row_key <- sprintf("row_%04d", row_id)
        row <- data.frame(
          row_id = row_id,
          row_key = row_key,
          study_id = as.character(defaults$study$id)[1L],
          run_tag = as.character(defaults$study$run_tag)[1L],
          scenario_id = cell$scenario_id,
          source_cell_id = cell$source_cell_id,
          family = cell$family,
          tau = cell$tau,
          tau_label = cell$tau_label,
          fit_size = cell$fit_size,
          model_variant = model_variant,
          inference = inference,
          phase = ffv2_manifest_phase(inference, cell$fit_size),
          dqlm_ind = identical(model_variant, "dqlm"),
          smoke = FALSE,
          status = "pending",
          run_root = run_root,
          row_config_path = file.path(run_root, "configs", sprintf("%s_config.json", row_key)),
          row_status_path = file.path(run_root, "rows", sprintf("%s_status.csv", row_key)),
          row_health_path = file.path(run_root, "health", sprintf("%s_health.csv", row_key)),
          row_metrics_path = file.path(run_root, "metrics", sprintf("%s_metrics.csv", row_key)),
          fit_path_summary_path = file.path(run_root, "fit_path_summaries", sprintf("%s_fit_path_summary.csv", row_key)),
          forecast_path_summary_path = file.path(run_root, "forecast_path_summaries", sprintf("%s_forecast_path_summary.csv", row_key)),
          log_path = file.path(run_root, "logs", sprintf("%s.log", row_key)),
          stringsAsFactors = FALSE
        )
        row$smoke <- ffv2_smoke_flag(row, defaults)
        rows[[length(rows) + 1L]] <- cbind(row, cell, stringsAsFactors = FALSE)
      }
    }
  }
  manifest <- ffv2_bind_rows(rows)
  manifest <- manifest[, !duplicated(names(manifest)), drop = FALSE]
  rownames(manifest) <- NULL
  ffv2_stop_stale_paths(manifest)

  if (!isTRUE(dry_run)) {
    for (i in seq_len(nrow(manifest))) {
      r <- manifest[i, , drop = FALSE]
      cfg <- as.list(r)
      cfg$repo_root <- repo_root
      cfg$harness_root <- ffv2_harness_root()
      cfg$defaults_path <- defaults$.__defaults_path__ %||% ffv2_default_defaults_path()
      cfg$runtime <- defaults$runtime
      cfg$budget <- defaults$budget
      cfg$models <- defaults$models
      cfg$retention <- defaults$retention
      ffv2_write_json(cfg, r$row_config_path)
    }
    ffv2_write_csv(registry, file.path(run_root, "manifests", "source_registry.csv"))
    verification <- ffv2_verify_source_windows(registry, stop_on_fail = TRUE)
    ffv2_write_csv(verification, file.path(run_root, "manifests", "source_window_verification.csv"))
    ffv2_write_csv(manifest, file.path(run_root, "manifests", "row_manifest.csv"))
    ffv2_write_json(ffv2_runtime_metadata(repo_root), file.path(run_root, "manifests", "runtime_metadata.json"))
  }
  manifest
}

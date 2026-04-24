`%||%` <- function(a, b) if (is.null(a)) b else a

.pipeline_read_json_if_exists <- function(path) {
  if (!file.exists(path)) return(NULL)
  jsonlite::fromJSON(path, simplifyVector = TRUE)
}

.pipeline_read_csv_if_exists <- function(path) {
  if (!file.exists(path)) return(NULL)
  utils::read.csv(path, stringsAsFactors = FALSE)
}

.pipeline_as_scalar <- function(x, default = NA) {
  if (is.null(x) || length(x) == 0L) return(default)
  x[[1L]]
}

.pipeline_pick_existing <- function(paths) {
  hit <- paths[file.exists(paths)]
  if (!length(hit)) return(NULL)
  hit[[1L]]
}

qdesn_prune_mcmc_vb_init_artifacts <- function(x) {
  prune_names <- c(
    "vb_init",
    "vb_init_fit",
    "vb_init_output",
    "vb_init_outputs",
    "vb_warm",
    "vb_warm_fit",
    "vb_warm_start_fit",
    "vb_warm_start_output",
    "vb_warm_start_outputs",
    "mcmc_vb_init",
    "mcmc_vb_init_fit",
    "mcmc_vb_warm_start_fit"
  )

  prune_one <- function(obj) {
    if (!is.list(obj) || is.data.frame(obj)) return(obj)
    nms <- names(obj)
    if (!is.null(nms) && length(nms)) {
      keep <- !tolower(nms) %in% prune_names
      obj <- obj[keep]
    }
    if (length(obj)) {
      obj[] <- lapply(obj, prune_one)
    }
    obj
  }

  prune_one(x)
}

.pipeline_parse_prob_from_trace_name <- function(x) {
  x <- as.character(x %||% NA_character_)[1L]
  if (is.na(x) || !nzchar(x)) return(NA_real_)
  x <- sub("^p=", "", x)
  suppressWarnings(as.numeric(x))
}

.pipeline_rhs_trace_row_to_summary <- function(trace_row, quantile_p = NA_real_, logtau_grid = numeric(0)) {
  trace_row <- as.data.frame(trace_row, stringsAsFactors = FALSE)
  if (!nrow(trace_row)) return(NULL)
  last <- trace_row[nrow(trace_row), , drop = FALSE]

  get_num <- function(col, default = NA_real_) {
    if (!(col %in% names(last))) return(default)
    out <- suppressWarnings(as.numeric(last[[col]][1L]))
    if (length(out) && is.finite(out)) out else default
  }
  get_chr <- function(col, default = NA_character_) {
    if (!(col %in% names(last))) return(default)
    out <- as.character(last[[col]][1L] %||% default)
    if (length(out)) out else default
  }

  log_tau_last <- get_num("log_tau")
  tau_last <- get_num("tau")
  if (!is.finite(log_tau_last) && is.finite(tau_last) && tau_last > 0) {
    log_tau_last <- log(tau_last)
  }
  grid_vals <- suppressWarnings(as.numeric(logtau_grid))
  grid_vals <- grid_vals[is.finite(grid_vals)]
  near_bound_flag <- FALSE
  if (is.finite(log_tau_last) && length(grid_vals)) {
    near_bound_flag <- isTRUE(abs(log_tau_last - min(grid_vals)) < 1e-3)
  }
  clip_side <- tolower(get_chr("log_tau_clip_side", ""))
  if (!near_bound_flag && nzchar(clip_side)) {
    near_bound_flag <- clip_side %in% c("lower", "lo", "left")
  }

  d_rhs <- get_num("D_rhs")
  n_small_1e4 <- get_num("n_beta_abs_lt_1e-04")
  beta_small_frac_1e4 <- if (is.finite(d_rhs) && d_rhs > 0 && is.finite(n_small_1e4)) {
    n_small_1e4 / d_rhs
  } else {
    NA_real_
  }
  E_invV_med_last <- get_num("E_invV_med", get_num("invV_med"))
  beta_l2_last <- get_num("beta_l2")

  collapse_flag_bound <- isTRUE(near_bound_flag) &&
    isTRUE(is.finite(E_invV_med_last) && E_invV_med_last > 1e8) &&
    isTRUE(is.finite(beta_l2_last) && beta_l2_last < 1e-3)
  collapse_flag_shrink <- isTRUE(is.finite(E_invV_med_last) && E_invV_med_last > 1e6) &&
    isTRUE(is.finite(beta_l2_last) && beta_l2_last < 1e-2) &&
    isTRUE(is.finite(beta_small_frac_1e4) && beta_small_frac_1e4 > 0.95)
  collapse_flag <- isTRUE(collapse_flag_bound) || isTRUE(collapse_flag_shrink)

  unhealthy_reason <- if (isTRUE(collapse_flag_shrink)) {
    "rhs_shrinkage_collapse"
  } else if (isTRUE(collapse_flag_bound)) {
    "rhs_tau_lower_bound_collapse"
  } else {
    ""
  }
  root_cause_context <- sprintf(
    "source=rhs_trace_fallback; tau=%.6g; E_invV_med=%.6g; beta_l2=%.6g; beta_small_frac_1e4=%.6g; near_bound=%s; collapse_bound=%s; collapse_shrink=%s",
    as.numeric(tau_last),
    as.numeric(E_invV_med_last),
    as.numeric(beta_l2_last),
    as.numeric(beta_small_frac_1e4),
    if (isTRUE(near_bound_flag)) "TRUE" else "FALSE",
    if (isTRUE(collapse_flag_bound)) "TRUE" else "FALSE",
    if (isTRUE(collapse_flag_shrink)) "TRUE" else "FALSE"
  )

  data.frame(
    quantile_p = as.numeric(quantile_p),
    rhs_trace_available = TRUE,
    tau_last = as.numeric(tau_last),
    log_tau_last = as.numeric(log_tau_last),
    near_bound_flag = as.logical(near_bound_flag),
    E_invV_med_last = as.numeric(E_invV_med_last),
    beta_l2_last = as.numeric(beta_l2_last),
    beta_small_frac_1e4_last = as.numeric(beta_small_frac_1e4),
    collapse_flag = as.logical(collapse_flag),
    collapse_flag_bound = as.logical(collapse_flag_bound),
    collapse_flag_shrink = as.logical(collapse_flag_shrink),
    unhealthy_flag = as.logical(collapse_flag),
    unhealthy_reason = as.character(unhealthy_reason),
    root_cause_context = as.character(root_cause_context),
    stringsAsFactors = FALSE
  )
}

.pipeline_recover_rhs_run_summary_from_artifacts <- function(out_dir) {
  rhs_trace_path <- file.path(out_dir, "models", "rhs_trace.rds")
  rhs_diag_summary_path <- file.path(out_dir, "models", "rhs_diag_summary.txt")

  if (file.exists(rhs_trace_path)) {
    rhs_trace_obj <- tryCatch(readRDS(rhs_trace_path), error = function(...) NULL)
    trace_list <- rhs_trace_obj$traces %||% NULL
    if (is.list(trace_list) && length(trace_list)) {
      rows <- lapply(seq_along(trace_list), function(i) {
        trace_entry <- trace_list[[i]]
        quantile_p <- NA_real_
        if (length(rhs_trace_obj$p_vec) >= i) {
          quantile_p <- suppressWarnings(as.numeric(rhs_trace_obj$p_vec[[i]]))
        }
        if (!is.finite(quantile_p) && !is.null(names(trace_list))) {
          quantile_p <- .pipeline_parse_prob_from_trace_name(names(trace_list)[i])
        }
        .pipeline_rhs_trace_row_to_summary(
          trace_row = trace_entry$trace %||% NULL,
          quantile_p = quantile_p,
          logtau_grid = trace_entry$logtau_grid %||% numeric(0)
        )
      })
      rows <- rows[!vapply(rows, is.null, logical(1))]
      if (length(rows)) {
        return(do.call(rbind, rows))
      }
    }
  }

  if (file.exists(rhs_diag_summary_path)) {
    lines <- readLines(rhs_diag_summary_path, warn = FALSE)
    prob_lines <- grep("^p=", lines, value = TRUE)
    if (!length(prob_lines)) prob_lines <- NA_character_
    rows <- lapply(prob_lines, function(line) {
      quantile_p <- suppressWarnings(as.numeric(sub("^p=([^ ]+).*$", "\\1", as.character(line))))
      data.frame(
        quantile_p = quantile_p,
        rhs_trace_available = TRUE,
        tau_last = NA_real_,
        log_tau_last = NA_real_,
        near_bound_flag = NA,
        E_invV_med_last = NA_real_,
        beta_l2_last = NA_real_,
        beta_small_frac_1e4_last = NA_real_,
        collapse_flag = NA,
        collapse_flag_bound = NA,
        collapse_flag_shrink = NA,
        unhealthy_flag = FALSE,
        unhealthy_reason = "",
        root_cause_context = "source=rhs_diag_summary_fallback",
        stringsAsFactors = FALSE
      )
    })
    return(do.call(rbind, rows))
  }

  NULL
}

.pipeline_score_value <- function(score_tbl, split, column) {
  if (is.null(score_tbl) || !nrow(score_tbl) || !(column %in% names(score_tbl))) {
    return(NA_real_)
  }
  if (!("split" %in% names(score_tbl))) {
    return(as.numeric(score_tbl[[column]][1L]))
  }
  idx <- which(tolower(as.character(score_tbl$split)) == tolower(split))
  if (!length(idx)) return(NA_real_)
  as.numeric(score_tbl[[column]][idx[1L]])
}

write_pipeline_timing_outputs <- function(timing_rows,
                                          tables_dir,
                                          models_dir = NULL,
                                          context = list()) {
  rows <- timing_rows
  if (is.null(rows)) {
    rows <- data.frame(
      when = character(),
      tag = character(),
      seconds = numeric(),
      stringsAsFactors = FALSE
    )
  } else {
    rows <- as.data.frame(rows, stringsAsFactors = FALSE)
  }

  if (!all(c("when", "tag", "seconds") %in% names(rows))) {
    stop("write_pipeline_timing_outputs(): timing_rows must contain when/tag/seconds columns.")
  }

  rows$when <- as.character(rows$when)
  rows$tag <- as.character(rows$tag)
  rows$seconds <- as.numeric(rows$seconds)

  total_stage_seconds <- sum(rows$seconds, na.rm = TRUE)
  max_stage_idx <- if (nrow(rows) && any(is.finite(rows$seconds))) {
    which.max(replace(rows$seconds, !is.finite(rows$seconds), -Inf))[1L]
  } else {
    NA_integer_
  }

  summary_df <- data.frame(
    created_at = as.character(Sys.time()),
    mode = as.character(.pipeline_as_scalar(context$mode, NA_character_)),
    inference_method = as.character(.pipeline_as_scalar(context$inference_method, NA_character_)),
    likelihood_family = as.character(.pipeline_as_scalar(context$likelihood_family, NA_character_)),
    beta_prior_type = as.character(.pipeline_as_scalar(context$beta_prior_type, NA_character_)),
    n_quantiles = as.integer(.pipeline_as_scalar(context$n_quantiles, NA_integer_)),
    T_use = as.integer(.pipeline_as_scalar(context$T_use, NA_integer_)),
    H_forecast = as.integer(.pipeline_as_scalar(context$H_forecast, NA_integer_)),
    total_stage_seconds = as.numeric(total_stage_seconds),
    n_timed_steps = as.integer(nrow(rows)),
    max_stage_tag = if (is.na(max_stage_idx)) NA_character_ else as.character(rows$tag[[max_stage_idx]]),
    max_stage_seconds = if (is.na(max_stage_idx)) NA_real_ else as.numeric(rows$seconds[[max_stage_idx]]),
    stringsAsFactors = FALSE
  )

  dir.create(tables_dir, recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(rows, file.path(tables_dir, "timing_breakdown.csv"), row.names = FALSE)
  utils::write.csv(summary_df, file.path(tables_dir, "timing_summary.csv"), row.names = FALSE)

  if (!is.null(models_dir)) {
    dir.create(models_dir, recursive = TRUE, showWarnings = FALSE)
    saveRDS(
      list(rows = rows, summary = summary_df, context = context),
      file.path(models_dir, "timing_summary.rds")
    )
  }

  invisible(list(rows = rows, summary = summary_df, context = context))
}

collect_pipeline_run_summary <- function(out_dir) {
  out_dir <- normalizePath(out_dir, winslash = "/", mustWork = FALSE)

  status_path <- file.path(out_dir, "manifest", "status.txt")
  runtime_json_path <- file.path(out_dir, "manifest", "runtime_summary.json")
  run_manifest_path <- file.path(out_dir, "manifest", "run_manifest.json")
  timing_summary_path <- file.path(out_dir, "tables", "timing_summary.csv")
  timing_breakdown_path <- file.path(out_dir, "tables", "timing_breakdown.csv")
  timing_rds_path <- file.path(out_dir, "models", "timing_summary.rds")
  forecast_objects_path <- file.path(out_dir, "models", "forecast_objects.rds")
  rhs_run_summary_path <- file.path(out_dir, "models", "rhs_run_summary.csv")

  status <- if (file.exists(status_path)) {
    trimws(readLines(status_path, warn = FALSE)[1L])
  } else {
    NA_character_
  }

  runtime_info <- .pipeline_read_json_if_exists(runtime_json_path)
  run_manifest <- .pipeline_read_json_if_exists(run_manifest_path)
  timing_summary <- .pipeline_read_csv_if_exists(timing_summary_path)
  timing_breakdown <- .pipeline_read_csv_if_exists(timing_breakdown_path)
  timing_rds <- if (file.exists(timing_rds_path)) readRDS(timing_rds_path) else NULL
  forecast_objects <- if (file.exists(forecast_objects_path)) readRDS(forecast_objects_path) else NULL
  rhs_run_summary <- .pipeline_read_csv_if_exists(rhs_run_summary_path)
  if (is.null(rhs_run_summary)) {
    rhs_run_summary <- .pipeline_recover_rhs_run_summary_from_artifacts(out_dir)
  }

  score_path <- .pipeline_pick_existing(c(
    file.path(out_dir, "tables", "scores_summary.csv"),
    file.path(out_dir, "tables", "metrics_summary.csv")
  ))
  score_tbl <- if (!is.null(score_path)) .pipeline_read_csv_if_exists(score_path) else NULL

  cfg <- forecast_objects$cfg %||% list()
  inference_cfg <- cfg$inference %||% list()
  beta_prior_cfg <- inference_cfg$beta_prior %||% list()
  vb_priors <- cfg$vb_priors %||% list()
  split_cfg <- cfg$split %||% list()
  forecast_cfg <- cfg$forecast %||% list()
  p_vec <- cfg$p_vec %||% numeric()
  timing_summary_resolved <- timing_summary %||% (timing_rds$summary %||% NULL)
  timing_breakdown_resolved <- timing_breakdown %||% (timing_rds$rows %||% NULL)

  timing_mode <- if (!is.null(timing_summary_resolved) &&
                     nrow(timing_summary_resolved) &&
                     "mode" %in% names(timing_summary_resolved)) {
    as.character(timing_summary_resolved$mode[1L])
  } else {
    NA_character_
  }
  timing_method <- if (!is.null(timing_summary_resolved) &&
                       nrow(timing_summary_resolved) &&
                       "inference_method" %in% names(timing_summary_resolved)) {
    as.character(timing_summary_resolved$inference_method[1L])
  } else {
    NA_character_
  }
  timing_prior <- if (!is.null(timing_summary_resolved) &&
                      nrow(timing_summary_resolved) &&
                      "beta_prior_type" %in% names(timing_summary_resolved)) {
    as.character(timing_summary_resolved$beta_prior_type[1L])
  } else {
    NA_character_
  }
  timing_family <- if (!is.null(timing_summary_resolved) &&
                       nrow(timing_summary_resolved) &&
                       "likelihood_family" %in% names(timing_summary_resolved)) {
    as.character(timing_summary_resolved$likelihood_family[1L])
  } else {
    NA_character_
  }

  method <- as.character(
    .pipeline_as_scalar(
      inference_cfg$method %||% cfg$method %||% runtime_info$inference_method %||% timing_method,
      NA_character_
    )
  )
  beta_prior_type <- as.character(
    .pipeline_as_scalar(
      beta_prior_cfg$type %||% vb_priors$beta_type %||% runtime_info$beta_prior_type %||% timing_prior,
      NA_character_
    )
  )
  likelihood_family <- as.character(
    .pipeline_as_scalar(
      inference_cfg$likelihood_family %||% cfg$likelihood_family %||% runtime_info$likelihood_family %||% timing_family,
      NA_character_
    )
  )
  mode <- as.character(
    .pipeline_as_scalar(
      cfg$pipeline$mode %||% run_manifest$dataset$mode %||% runtime_info$mode %||% timing_mode,
      NA_character_
    )
  )

  timing_total_stage_seconds <- if (!is.null(timing_summary_resolved) && nrow(timing_summary_resolved)) {
    as.numeric(timing_summary_resolved$total_stage_seconds[1L])
  } else {
    NA_real_
  }

  wall_seconds <- as.numeric(runtime_info$elapsed_seconds %||% NA_real_)
  p_count <- length(unique(as.numeric(p_vec)))
  n_timed_steps <- if (!is.null(timing_summary_resolved) && nrow(timing_summary_resolved)) {
    as.integer(timing_summary_resolved$n_timed_steps[1L])
  } else {
    NA_integer_
  }

  rhs_diag_available <- !is.null(rhs_run_summary) && nrow(rhs_run_summary) > 0L
  rhs_collapse_flag_any <- if (rhs_diag_available && "collapse_flag" %in% names(rhs_run_summary)) {
    any(as.logical(rhs_run_summary$collapse_flag), na.rm = TRUE)
  } else {
    NA
  }
  rhs_collapse_flag_bound_any <- if (rhs_diag_available && "collapse_flag_bound" %in% names(rhs_run_summary)) {
    any(as.logical(rhs_run_summary$collapse_flag_bound), na.rm = TRUE)
  } else {
    NA
  }
  rhs_collapse_flag_shrink_any <- if (rhs_diag_available && "collapse_flag_shrink" %in% names(rhs_run_summary)) {
    any(as.logical(rhs_run_summary$collapse_flag_shrink), na.rm = TRUE)
  } else {
    NA
  }
  rhs_unhealthy_any <- if (rhs_diag_available && "unhealthy_flag" %in% names(rhs_run_summary)) {
    any(as.logical(rhs_run_summary$unhealthy_flag), na.rm = TRUE)
  } else {
    isTRUE(rhs_collapse_flag_any)
  }
  rhs_focus_row <- NULL
  if (rhs_diag_available) {
    if ("unhealthy_flag" %in% names(rhs_run_summary)) {
      idx <- which(as.logical(rhs_run_summary$unhealthy_flag))
      if (length(idx)) rhs_focus_row <- rhs_run_summary[idx[1L], , drop = FALSE]
    }
    if (is.null(rhs_focus_row) && "collapse_flag" %in% names(rhs_run_summary)) {
      idx <- which(as.logical(rhs_run_summary$collapse_flag))
      if (length(idx)) rhs_focus_row <- rhs_run_summary[idx[1L], , drop = FALSE]
    }
    if (is.null(rhs_focus_row)) rhs_focus_row <- rhs_run_summary[1L, , drop = FALSE]
  }
  rhs_focus_value <- function(col, default = NA) {
    if (is.null(rhs_focus_row) || !(col %in% names(rhs_focus_row))) return(default)
    rhs_focus_row[[col]][1L]
  }

  summary_row <- data.frame(
    out_dir = out_dir,
    status = status,
    mode = mode,
    inference_method = method,
    likelihood_family = likelihood_family,
    beta_prior_type = beta_prior_type,
    p_count = as.integer(p_count),
    T_use = as.integer(.pipeline_as_scalar(split_cfg$T_use, NA_integer_)),
    n_train = as.integer(.pipeline_as_scalar(split_cfg$n_train, NA_integer_)),
    H_forecast = as.integer(.pipeline_as_scalar(split_cfg$H_forecast, NA_integer_)),
    forecast_mode = as.character(.pipeline_as_scalar(forecast_cfg$mode, NA_character_)),
    wall_seconds = wall_seconds,
    total_stage_seconds = timing_total_stage_seconds,
    n_timed_steps = n_timed_steps,
    train_CRPS_mean = .pipeline_score_value(score_tbl, "train", "CRPS_mean"),
    forecast_CRPS_mean = .pipeline_score_value(score_tbl, "forecast", "CRPS_mean"),
    train_PinballMean_mean = .pipeline_score_value(score_tbl, "train", "PinballMean_mean"),
    forecast_PinballMean_mean = .pipeline_score_value(score_tbl, "forecast", "PinballMean_mean"),
    train_S_mean = .pipeline_score_value(score_tbl, "train", "S_mean"),
    forecast_S_mean = .pipeline_score_value(score_tbl, "forecast", "S_mean"),
    rhs_diag_available = as.logical(rhs_diag_available),
    rhs_collapse_flag_any = as.logical(rhs_collapse_flag_any),
    rhs_collapse_flag_bound_any = as.logical(rhs_collapse_flag_bound_any),
    rhs_collapse_flag_shrink_any = as.logical(rhs_collapse_flag_shrink_any),
    rhs_unhealthy_any = as.logical(rhs_unhealthy_any),
    rhs_unhealthy_reason = as.character(rhs_focus_value("unhealthy_reason", NA_character_)),
    rhs_root_cause_context = as.character(rhs_focus_value("root_cause_context", NA_character_)),
    rhs_tau_last = as.numeric(rhs_focus_value("tau_last", NA_real_)),
    rhs_E_invV_med_last = as.numeric(rhs_focus_value("E_invV_med_last", NA_real_)),
    rhs_beta_l2_last = as.numeric(rhs_focus_value("beta_l2_last", NA_real_)),
    rhs_beta_small_frac_1e4_last = as.numeric(rhs_focus_value("beta_small_frac_1e4_last", NA_real_)),
    rhs_quantile_p = as.numeric(rhs_focus_value("quantile_p", NA_real_)),
    score_file = if (is.null(score_path)) NA_character_ else score_path,
    stringsAsFactors = FALSE
  )

  list(
    summary = summary_row,
    status = status,
    runtime = runtime_info,
    run_manifest = run_manifest,
    timing_summary = timing_summary_resolved,
    timing_breakdown = timing_breakdown_resolved,
    rhs_run_summary = rhs_run_summary,
    score_table = score_tbl,
    forecast_objects = forecast_objects
  )
}

collect_pipeline_run_summaries <- function(out_dirs) {
  out_dirs <- as.character(out_dirs)
  rows <- lapply(out_dirs, function(path) collect_pipeline_run_summary(path)$summary)
  rows <- rows[!vapply(rows, is.null, logical(1))]
  if (!length(rows)) {
    return(data.frame(stringsAsFactors = FALSE))
  }
  do.call(rbind, rows)
}

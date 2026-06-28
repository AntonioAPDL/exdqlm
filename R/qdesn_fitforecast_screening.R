`%||%` <- function(a, b) if (is.null(a)) b else a

qdesn_dynamic_fitforecast_screening_profile_base <- function(profile_id) {
  profile_id <- as.character(profile_id %||% NA_character_)
  out <- sub("_tau0_[^_]+$", "", profile_id)
  out[is.na(profile_id)] <- NA_character_
  out
}

qdesn_dynamic_fitforecast_parse_profile_base <- function(profile_base) {
  profile_base <- as.character(profile_base %||% NA_character_)
  rows <- lapply(profile_base, function(x) {
    empty <- data.frame(
      D = NA_integer_, n_each = NA_integer_, alpha = NA_real_, rho = NA_real_,
      m = NA_integer_, readout_y_lags = NA_integer_, reservoir_lags = NA_integer_,
      pi_w = NA_real_, pi_in = NA_real_, stringsAsFactors = FALSE
    )
    if (is.na(x) || !nzchar(x)) return(empty)
    m <- regexec(
      "^tt500vb(?:_[A-Za-z0-9]+)?_d([0-9]+)_n([0-9]+)_a([0-9]+p?[0-9]*)_r([0-9]+p?[0-9]*)(?:_m([0-9]+)_lag([0-9]+)_rl([0-9]+)_pw([0-9]+p?[0-9]*)_pin([0-9]+p?[0-9]*))?$",
      x
    )
    hit <- regmatches(x, m)[[1L]]
    if (length(hit) < 5L) {
      return(empty)
    }
    data.frame(
      D = as.integer(hit[[2L]]),
      n_each = as.integer(hit[[3L]]),
      alpha = as.numeric(gsub("p", ".", hit[[4L]], fixed = TRUE)),
      rho = as.numeric(gsub("p", ".", hit[[5L]], fixed = TRUE)),
      m = if (length(hit) >= 6L && nzchar(hit[[6L]])) as.integer(hit[[6L]]) else NA_integer_,
      readout_y_lags = if (length(hit) >= 7L && nzchar(hit[[7L]])) as.integer(hit[[7L]]) else NA_integer_,
      reservoir_lags = if (length(hit) >= 8L && nzchar(hit[[8L]])) as.integer(hit[[8L]]) else NA_integer_,
      pi_w = if (length(hit) >= 9L && nzchar(hit[[9L]])) as.numeric(gsub("p", ".", hit[[9L]], fixed = TRUE)) else NA_real_,
      pi_in = if (length(hit) >= 10L && nzchar(hit[[10L]])) as.numeric(gsub("p", ".", hit[[10L]], fixed = TRUE)) else NA_real_,
      stringsAsFactors = FALSE
    )
  })
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
}

.qdesn_dynamic_fitforecast_fill_profile_metadata <- function(df,
                                                             id_col = "screening_profile_base",
                                                             fields = c(
                                                               "D", "n_each", "alpha", "rho", "m",
                                                               "readout_y_lags", "reservoir_lags", "pi_w", "pi_in"
                                                             )) {
  if (!is.data.frame(df) || !nrow(df) || !id_col %in% names(df)) return(df)
  parsed <- qdesn_dynamic_fitforecast_parse_profile_base(df[[id_col]])
  for (nm in intersect(fields, names(parsed))) {
    if (!nm %in% names(df)) {
      df[[nm]] <- parsed[[nm]]
    } else {
      current <- df[[nm]]
      missing <- is.na(current) | (is.character(current) & !nzchar(current))
      if (any(missing)) df[[nm]][missing] <- parsed[[nm]][missing]
    }
  }
  df
}

.qdesn_dynamic_fitforecast_first_or_na <- function(df, col, default = NA) {
  if (!col %in% names(df) || !length(df[[col]])) return(default)
  df[[col]][[1L]]
}

.qdesn_dynamic_fitforecast_decimal_token <- function(x) {
  x <- format(as.numeric(x), trim = TRUE, scientific = FALSE)
  x <- sub("0+$", "", x)
  x <- sub("\\.$", "", x)
  gsub("\\.", "p", x)
}

.qdesn_dynamic_fitforecast_tau0_token <- function(x) {
  x <- as.numeric(x)[1L]
  if (!is.finite(x)) return("na")
  token <- format(x, scientific = TRUE, digits = 1L)
  token <- gsub("\\+", "", token)
  token <- gsub("-", "m", token, fixed = TRUE)
  token <- gsub("\\.", "p", token)
  token <- gsub("e", "e", token, fixed = TRUE)
  token
}

.qdesn_dynamic_fitforecast_profile_dimension <- function(D,
                                                         n_each,
                                                         n_tilde_each,
                                                         readout_y_lags = 12L,
                                                         add_bias = TRUE) {
  D <- as.integer(D)[1L]
  n_each <- as.integer(n_each)[1L]
  n_tilde_each <- as.integer(n_tilde_each)[1L]
  readout_y_lags <- as.integer(readout_y_lags)[1L]
  as.integer(D * n_each + max(0L, D - 1L) * n_tilde_each + readout_y_lags + as.integer(isTRUE(add_bias)))
}

qdesn_dynamic_fitforecast_profile_row <- function(D,
                                                  n_each,
                                                  alpha,
                                                  rho,
                                                  screening_stage,
                                                  screening_wave,
                                                  profile_role = "primary",
                                                  rhs_tau0 = 1e-4,
                                                  m = 12L,
                                                  pi_w = 0.1,
                                                  pi_in = 1.0,
                                                  washout = 300L,
                                                  add_bias = TRUE,
                                                  seed = 123L,
                                                  readout_y_lags = 12L,
                                                  reservoir_lags = 0L,
                                                  include_tau0_suffix = FALSE) {
  D <- as.integer(D)[1L]
  n_each <- as.integer(n_each)[1L]
  n_tilde_each <- if (D <= 1L) 0L else n_each
  base_id <- sprintf(
    "tt500vb_d%d_n%d_a%s_r%s",
    D,
    n_each,
    .qdesn_dynamic_fitforecast_decimal_token(alpha),
    .qdesn_dynamic_fitforecast_decimal_token(rho)
  )
  profile_id <- if (isTRUE(include_tau0_suffix)) {
    sprintf("%s_tau0_%s", base_id, .qdesn_dynamic_fitforecast_tau0_token(rhs_tau0))
  } else {
    base_id
  }
  dimension_p <- .qdesn_dynamic_fitforecast_profile_dimension(
    D = D,
    n_each = n_each,
    n_tilde_each = n_tilde_each,
    readout_y_lags = readout_y_lags,
    add_bias = add_bias
  )
  data.frame(
    screening_profile_id = profile_id,
    screening_stage = as.character(screening_stage)[1L],
    screening_wave = as.character(screening_wave)[1L],
    profile_role = as.character(profile_role)[1L],
    enabled = TRUE,
    D = D,
    n_each = n_each,
    n_tilde_each = n_tilde_each,
    m = as.integer(m)[1L],
    alpha = as.numeric(alpha)[1L],
    rho = as.numeric(rho)[1L],
    pi_w = as.numeric(pi_w)[1L],
    pi_in = as.numeric(pi_in)[1L],
    washout = as.integer(washout)[1L],
    add_bias = isTRUE(add_bias),
    seed = as.integer(seed)[1L],
    readout_y_lags = as.integer(readout_y_lags)[1L],
    reservoir_lags = as.integer(reservoir_lags)[1L],
    rhs_tau0 = as.numeric(rhs_tau0)[1L],
    dimension_p_estimate = dimension_p,
    p_over_n_tt500 = dimension_p / 500,
    stringsAsFactors = FALSE
  )
}

qdesn_dynamic_fitforecast_confirmation_profiles <- function(screening_wave = "confirmation_2026_06_25") {
  candidates <- data.frame(
    D = c(2L, 1L, 1L, 1L, 1L, 2L, 2L, 1L, 1L, 3L),
    n_each = c(30L, 50L, 70L, 30L, 50L, 50L, 50L, 30L, 50L, 30L),
    alpha = c(0.30, 0.30, 0.30, 0.30, 0.60, 0.60, 0.30, 0.10, 0.10, 0.30),
    rho = c(0.85, 0.85, 0.85, 0.85, 0.95, 0.95, 0.85, 0.70, 0.70, 0.85),
    stringsAsFactors = FALSE
  )
  rows <- lapply(seq_len(nrow(candidates)), function(i) {
    qdesn_dynamic_fitforecast_profile_row(
      D = candidates$D[[i]],
      n_each = candidates$n_each[[i]],
      alpha = candidates$alpha[[i]],
      rho = candidates$rho[[i]],
      screening_stage = "all_quantile_confirmation",
      screening_wave = screening_wave,
      profile_role = "confirmation",
      rhs_tau0 = 1e-4
    )
  })
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
}

qdesn_dynamic_fitforecast_broad_profiles <- function(screening_wave = "broad_2026_06_25") {
  depth_width <- data.frame(
    D = c(rep(1L, 5L), rep(2L, 4L), rep(3L, 2L)),
    n_each = c(20L, 30L, 40L, 50L, 70L, 20L, 30L, 40L, 50L, 20L, 30L),
    stringsAsFactors = FALSE
  )
  ar <- data.frame(
    alpha = c(0.05, 0.10, 0.20, 0.30, 0.50),
    rho = c(0.60, 0.70, 0.80, 0.85, 0.95),
    stringsAsFactors = FALSE
  )
  rows <- list()
  for (i in seq_len(nrow(depth_width))) {
    for (j in seq_len(nrow(ar))) {
      rows[[length(rows) + 1L]] <- qdesn_dynamic_fitforecast_profile_row(
        D = depth_width$D[[i]],
        n_each = depth_width$n_each[[i]],
        alpha = ar$alpha[[j]],
        rho = ar$rho[[j]],
        screening_stage = "adaptive_broad_screen",
        screening_wave = screening_wave,
        profile_role = "broad",
        rhs_tau0 = 1e-4
      )
    }
  }
  out <- do.call(rbind, rows)
  out <- out[order(out$D, out$n_each, out$alpha, out$rho), , drop = FALSE]
  rownames(out) <- NULL
  out
}

qdesn_dynamic_fitforecast_dominance_profiles <- function(screening_wave = "dominance_period90_2026_06_26",
                                                         x_feature_count = 5L) {
  depth_width <- data.frame(
    D = c(1L, 1L, 1L, 2L, 2L, 2L),
    n_each = c(20L, 30L, 50L, 20L, 30L, 50L),
    stringsAsFactors = FALSE
  )
  dynamics <- data.frame(
    alpha = c(0.05, 0.10, 0.20, 0.30),
    rho = c(0.60, 0.70, 0.80, 0.85),
    stringsAsFactors = FALSE
  )
  sparsity <- data.frame(
    profile_role = c("seasonal_sparse", "seasonal_balanced", "seasonal_input_rich"),
    pi_w = c(0.05, 0.10, 0.20),
    pi_in = c(0.30, 0.50, 0.80),
    reservoir_lags = c(0L, 1L, 1L),
    stringsAsFactors = FALSE
  )
  rows <- list()
  for (i in seq_len(nrow(depth_width))) {
    for (j in seq_len(nrow(dynamics))) {
      for (k in seq_len(nrow(sparsity))) {
        row <- qdesn_dynamic_fitforecast_profile_row(
          D = depth_width$D[[i]],
          n_each = depth_width$n_each[[i]],
          alpha = dynamics$alpha[[j]],
          rho = dynamics$rho[[j]],
          screening_stage = "vb_baseline_dominance_period90_screen",
          screening_wave = screening_wave,
          profile_role = sparsity$profile_role[[k]],
          rhs_tau0 = 1e-4,
          m = 90L,
          pi_w = sparsity$pi_w[[k]],
          pi_in = sparsity$pi_in[[k]],
          washout = 300L,
          readout_y_lags = 90L,
          reservoir_lags = sparsity$reservoir_lags[[k]]
        )
        row$x_feature_count <- as.integer(x_feature_count)[1L]
        row$dimension_p_estimate <- as.integer(row$dimension_p_estimate + row$x_feature_count)
        row$p_over_n_tt500 <- as.numeric(row$dimension_p_estimate / 500)
        row$screening_profile_id <- sprintf(
          "tt500vb_dom_d%d_n%d_a%s_r%s_m90_lag90_rl%d_pw%s_pin%s",
          as.integer(row$D),
          as.integer(row$n_each),
          .qdesn_dynamic_fitforecast_decimal_token(row$alpha),
          .qdesn_dynamic_fitforecast_decimal_token(row$rho),
          as.integer(row$reservoir_lags),
          .qdesn_dynamic_fitforecast_decimal_token(row$pi_w),
          .qdesn_dynamic_fitforecast_decimal_token(row$pi_in)
        )
        rows[[length(rows) + 1L]] <- row
      }
    }
  }
  out <- do.call(rbind, rows)
  out <- out[order(out$D, out$n_each, out$alpha, out$rho, out$profile_role), , drop = FALSE]
  rownames(out) <- NULL
  out
}

qdesn_dynamic_fitforecast_top_profiles_from_ranking <- function(ranking_path,
                                                                top_n = 5L,
                                                                screening_wave = "stability",
                                                                seed = 456L) {
  ranking_path <- .qdesn_validation_resolve_path(ranking_path, must_work = TRUE)
  ranking <- utils::read.csv(ranking_path, stringsAsFactors = FALSE)
  if (!nrow(ranking)) stop(sprintf("Profile ranking is empty: %s", ranking_path), call. = FALSE)
  if (!"screening_profile_base" %in% names(ranking)) {
    stop("Profile ranking is missing `screening_profile_base`.", call. = FALSE)
  }
  ranking <- ranking[order(as.integer(ranking$profile_rank %||% seq_len(nrow(ranking)))), , drop = FALSE]
  top <- utils::head(ranking, as.integer(top_n)[1L])
  required <- c("D", "n_each", "alpha", "rho")
  missing <- setdiff(required, names(top))
  if (length(missing)) {
    stop(sprintf("Profile ranking is missing column(s) needed for stability profiles: %s", paste(missing, collapse = ", ")), call. = FALSE)
  }
  rows <- lapply(seq_len(nrow(top)), function(i) {
    tau0_value <- if ("rhs_tau0_representative" %in% names(top)) {
      as.numeric(top$rhs_tau0_representative[[i]])
    } else {
      1e-4
    }
    row <- qdesn_dynamic_fitforecast_profile_row(
      D = top$D[[i]],
      n_each = top$n_each[[i]],
      alpha = top$alpha[[i]],
      rho = top$rho[[i]],
      screening_stage = "seed_stability_check",
      screening_wave = screening_wave,
      profile_role = "stability",
      rhs_tau0 = tau0_value
    )
    row$seed <- as.integer(seed)
    row$screening_profile_id <- paste0(row$screening_profile_id, "_seed", as.integer(seed))
    row
  })
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
}

.qdesn_dynamic_fitforecast_weighted_mean <- function(x, w = NULL) {
  x <- as.numeric(x)
  if (is.null(w)) w <- rep(1, length(x))
  w <- as.numeric(w)
  ok <- is.finite(x) & is.finite(w) & w > 0
  if (!any(ok)) return(NA_real_)
  sum(x[ok] * w[ok]) / sum(w[ok])
}

.qdesn_dynamic_fitforecast_lead_band_summary <- function(df, leads, prefix) {
  sub <- df[as.integer(df$forecast_lead) %in% as.integer(leads), , drop = FALSE]
  w <- as.numeric(sub$n_origins_scored %||% rep(1, nrow(sub)))
  data.frame(
    stats::setNames(
      list(
        nrow(sub),
        if (nrow(sub)) min(as.integer(sub$forecast_lead), na.rm = TRUE) else NA_integer_,
        if (nrow(sub)) max(as.integer(sub$forecast_lead), na.rm = TRUE) else NA_integer_,
        sum(w[is.finite(w)], na.rm = TRUE),
        .qdesn_dynamic_fitforecast_weighted_mean(sub$forecast_qtrue_mae, w),
        .qdesn_dynamic_fitforecast_weighted_mean(sub$forecast_qtrue_rmse, w),
        .qdesn_dynamic_fitforecast_weighted_mean(abs(as.numeric(sub$forecast_qtrue_bias)), w),
        .qdesn_dynamic_fitforecast_weighted_mean(sub$forecast_pinball_mean, w),
        .qdesn_dynamic_fitforecast_weighted_mean(sub$forecast_coverage, w),
        .qdesn_dynamic_fitforecast_weighted_mean(abs(as.numeric(sub$forecast_coverage_error)), w)
      ),
      paste0(prefix, c(
        "_lead_rows", "_lead_min", "_lead_max", "_origin_scores",
        "_qtrue_mae", "_qtrue_rmse", "_abs_qtrue_bias", "_pinball_mean",
        "_coverage", "_coverage_abs_error"
      ))
    ),
    stringsAsFactors = FALSE
  )
}

qdesn_dynamic_fitforecast_aggregate_lead_metrics <- function(lead_metrics) {
  if (!nrow(lead_metrics)) {
    stop("Forecast lead metrics are empty.", call. = FALSE)
  }
  required <- c(
    "forecast_lead", "n_origins_scored", "forecast_qtrue_mae",
    "forecast_qtrue_rmse", "forecast_qtrue_bias", "forecast_pinball_mean",
    "forecast_coverage", "forecast_coverage_error"
  )
  missing <- setdiff(required, names(lead_metrics))
  if (length(missing)) {
    stop(sprintf("Forecast lead metrics missing required column(s): %s", paste(missing, collapse = ", ")), call. = FALSE)
  }
  all_leads <- sort(unique(as.integer(lead_metrics$forecast_lead)))
  out <- cbind(
    .qdesn_dynamic_fitforecast_lead_band_summary(lead_metrics, all_leads, "forecast_all"),
    .qdesn_dynamic_fitforecast_lead_band_summary(lead_metrics, 1:5, "forecast_l1_5"),
    .qdesn_dynamic_fitforecast_lead_band_summary(lead_metrics, 6:15, "forecast_l6_15"),
    .qdesn_dynamic_fitforecast_lead_band_summary(lead_metrics, 16:30, "forecast_l16_30"),
    stringsAsFactors = FALSE
  )
  out$forecast_lead_metrics_rows <- nrow(lead_metrics)
  out$forecast_max_lead_observed <- max(all_leads, na.rm = TRUE)
  out$forecast_origin_stride <- as.integer(lead_metrics$origin_stride[[1L]] %||% NA_integer_)
  out$forecast_max_lead_configured <- as.integer(lead_metrics$max_lead_configured[[1L]] %||% NA_integer_)
  out$lead_export_scale_status <- as.character(lead_metrics$lead_export_scale_status[[1L]] %||% NA_character_)
  out
}

.qdesn_dynamic_fitforecast_group_summary <- function(df, group_cols, numeric_cols, extra_fun = NULL) {
  if (!nrow(df)) return(data.frame(stringsAsFactors = FALSE))
  key <- interaction(df[, group_cols, drop = FALSE], drop = TRUE, sep = "\r")
  rows <- lapply(split(seq_len(nrow(df)), key), function(idx) {
    sub <- df[idx, , drop = FALSE]
    fixed <- as.data.frame(sub[1L, group_cols, drop = FALSE], stringsAsFactors = FALSE)
    for (nm in numeric_cols) {
      if (nm %in% names(sub)) {
        fixed[[paste0(nm, "_mean")]] <- mean(as.numeric(sub[[nm]]), na.rm = TRUE)
      }
    }
    fixed$n_rows <- nrow(sub)
    if (!is.null(extra_fun)) {
      fixed <- cbind(fixed, extra_fun(sub))
    }
    fixed
  })
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
}

.qdesn_dynamic_fitforecast_robust_z <- function(x) {
  x <- as.numeric(x)
  med <- stats::median(x, na.rm = TRUE)
  scale <- stats::mad(x, center = med, constant = 1, na.rm = TRUE)
  if (!is.finite(scale) || scale <= 0) scale <- stats::sd(x, na.rm = TRUE)
  if (!is.finite(scale) || scale <= 0) scale <- 1
  (x - med) / scale
}

qdesn_dynamic_fitforecast_rank_screen <- function(fit_summary_path,
                                                  report_root = NULL,
                                                  collapse_tau0 = TRUE,
                                                  require_complete_leads = TRUE) {
  fit_summary_path <- .qdesn_validation_resolve_path(fit_summary_path, must_work = TRUE)
  fit_summary <- utils::read.csv(fit_summary_path, stringsAsFactors = FALSE)
  if (!nrow(fit_summary)) stop(sprintf("Campaign fit summary is empty: %s", fit_summary_path), call. = FALSE)
  if (!"forecast_lead_metrics_path" %in% names(fit_summary)) {
    stop("Campaign fit summary is missing `forecast_lead_metrics_path`.", call. = FALSE)
  }
  lead_paths <- as.character(fit_summary$forecast_lead_metrics_path)
  missing_leads <- is.na(lead_paths) | !nzchar(lead_paths) | !file.exists(lead_paths)
  if (any(missing_leads) && isTRUE(require_complete_leads)) {
    stop(sprintf("Missing forecast lead metrics for %d fit row(s).", sum(missing_leads)), call. = FALSE)
  }

  lead_rows <- vector("list", nrow(fit_summary))
  for (i in seq_len(nrow(fit_summary))) {
    if (missing_leads[[i]]) next
    lead_df <- utils::read.csv(lead_paths[[i]], stringsAsFactors = FALSE)
    agg <- qdesn_dynamic_fitforecast_aggregate_lead_metrics(lead_df)
    lead_rows[[i]] <- agg
  }
  lead_summary <- do.call(rbind, lead_rows[!vapply(lead_rows, is.null, logical(1L))])
  fit_kept <- fit_summary[!missing_leads, , drop = FALSE]
  fit_enriched <- cbind(fit_kept, lead_summary)
  fit_enriched$screening_profile_base <- qdesn_dynamic_fitforecast_screening_profile_base(fit_enriched$screening_profile_id)
  fit_enriched <- .qdesn_dynamic_fitforecast_fill_profile_metadata(fit_enriched)

  campaign_forecast_metric_cols <- grep(
    "^forecast_(CRPS|PinballMean|S|qhat|pinball_tau)",
    names(fit_summary),
    value = TRUE
  )
  campaign_forecast_all_missing <- if (length(campaign_forecast_metric_cols)) {
    all(vapply(fit_summary[campaign_forecast_metric_cols], function(x) all(is.na(as.numeric(x))), logical(1L)))
  } else {
    NA
  }

  numeric_cols <- c(
    "train_qtrue_mae", "train_qtrue_rmse", "train_qtrue_bias", "holdout_qtrue_mae",
    "holdout_qtrue_rmse", "holdout_qtrue_bias", "runtime_sec",
    "fit_runtime_seconds", "dimension_p_estimate", "p_over_n_tt500",
    "forecast_all_qtrue_mae", "forecast_all_qtrue_rmse", "forecast_all_abs_qtrue_bias",
    "forecast_all_pinball_mean", "forecast_all_coverage_abs_error",
    "forecast_l1_5_qtrue_mae", "forecast_l1_5_pinball_mean",
    "forecast_l6_15_qtrue_mae", "forecast_l6_15_pinball_mean",
    "forecast_l16_30_qtrue_mae", "forecast_l16_30_pinball_mean"
  )
  numeric_cols <- intersect(numeric_cols, names(fit_enriched))

  cell_group_cols <- intersect(
    c(
      "scenario", "family", "tau", "fit_size", "prior", "beta_prior_type",
      "method", "inference", "likelihood_family", "screening_profile_base"
    ),
    names(fit_enriched)
  )
  cell_summary <- .qdesn_dynamic_fitforecast_group_summary(
    fit_enriched,
    group_cols = cell_group_cols,
    numeric_cols = numeric_cols,
    extra_fun = function(sub) {
      data.frame(
        n_tau0_variants = length(unique(as.numeric(sub$rhs_tau0 %||% NA_real_))),
        tau0_values = paste(sort(unique(as.character(sub$rhs_tau0 %||% NA_character_))), collapse = ";"),
        rhs_tau0_representative = as.numeric(.qdesn_dynamic_fitforecast_first_or_na(sub, "rhs_tau0", NA_real_)),
        screening_profile_id_representative = as.character(.qdesn_dynamic_fitforecast_first_or_na(sub, "screening_profile_id", NA_character_)),
        D = as.integer(.qdesn_dynamic_fitforecast_first_or_na(sub, "D", NA_integer_)),
        n_each = as.integer(.qdesn_dynamic_fitforecast_first_or_na(sub, "n_each", NA_integer_)),
        alpha = as.numeric(.qdesn_dynamic_fitforecast_first_or_na(sub, "alpha", NA_real_)),
        rho = as.numeric(.qdesn_dynamic_fitforecast_first_or_na(sub, "rho", NA_real_)),
        m = as.integer(.qdesn_dynamic_fitforecast_first_or_na(sub, "m", NA_integer_)),
        readout_y_lags = as.integer(.qdesn_dynamic_fitforecast_first_or_na(sub, "readout_y_lags", NA_integer_)),
        reservoir_lags = as.integer(.qdesn_dynamic_fitforecast_first_or_na(sub, "reservoir_lags", NA_integer_)),
        pi_w = as.numeric(.qdesn_dynamic_fitforecast_first_or_na(sub, "pi_w", NA_real_)),
        pi_in = as.numeric(.qdesn_dynamic_fitforecast_first_or_na(sub, "pi_in", NA_real_)),
        stringsAsFactors = FALSE
      )
    }
  )

  profile_group_cols <- intersect(
    c("screening_profile_base", "fit_size", "prior", "beta_prior_type", "method", "inference", "likelihood_family"),
    names(cell_summary)
  )
  profile_numeric <- grep("_mean$", names(cell_summary), value = TRUE)
  profile_summary <- .qdesn_dynamic_fitforecast_group_summary(
    cell_summary,
    group_cols = profile_group_cols,
    numeric_cols = profile_numeric,
    extra_fun = function(sub) {
      data.frame(
        n_cells = nrow(sub),
        families = paste(sort(unique(as.character(sub$family %||% NA_character_))), collapse = ";"),
        taus = paste(sort(unique(as.character(sub$tau %||% NA_character_))), collapse = ";"),
        n_tau0_variants_max = max(as.integer(sub$n_tau0_variants %||% NA_integer_), na.rm = TRUE),
        rhs_tau0_representative = as.numeric(.qdesn_dynamic_fitforecast_first_or_na(sub, "rhs_tau0_representative", NA_real_)),
        screening_profile_id_representative = as.character(.qdesn_dynamic_fitforecast_first_or_na(sub, "screening_profile_id_representative", NA_character_)),
        D = as.integer(.qdesn_dynamic_fitforecast_first_or_na(sub, "D", NA_integer_)),
        n_each = as.integer(.qdesn_dynamic_fitforecast_first_or_na(sub, "n_each", NA_integer_)),
        alpha = as.numeric(.qdesn_dynamic_fitforecast_first_or_na(sub, "alpha", NA_real_)),
        rho = as.numeric(.qdesn_dynamic_fitforecast_first_or_na(sub, "rho", NA_real_)),
        m = as.integer(.qdesn_dynamic_fitforecast_first_or_na(sub, "m", NA_integer_)),
        readout_y_lags = as.integer(.qdesn_dynamic_fitforecast_first_or_na(sub, "readout_y_lags", NA_integer_)),
        reservoir_lags = as.integer(.qdesn_dynamic_fitforecast_first_or_na(sub, "reservoir_lags", NA_integer_)),
        pi_w = as.numeric(.qdesn_dynamic_fitforecast_first_or_na(sub, "pi_w", NA_real_)),
        pi_in = as.numeric(.qdesn_dynamic_fitforecast_first_or_na(sub, "pi_in", NA_real_)),
        stringsAsFactors = FALSE
      )
    }
  )

  score_terms <- c(
    train = "train_qtrue_mae_mean_mean",
    holdout = "holdout_qtrue_mae_mean_mean",
    forecast_all_mae = "forecast_all_qtrue_mae_mean_mean",
    forecast_all_pinball = "forecast_all_pinball_mean_mean_mean",
    forecast_short_mae = "forecast_l1_5_qtrue_mae_mean_mean",
    forecast_short_pinball = "forecast_l1_5_pinball_mean_mean_mean",
    runtime = "runtime_sec_mean_mean",
    p_over_n = "p_over_n_tt500_mean_mean"
  )
  score_weights <- c(
    train = 0.10,
    holdout = 0.20,
    forecast_all_mae = 0.25,
    forecast_all_pinball = 0.20,
    forecast_short_mae = 0.15,
    forecast_short_pinball = 0.05,
    runtime = 0.03,
    p_over_n = 0.02
  )
  score <- rep(0, nrow(profile_summary))
  weight_used <- rep(0, nrow(profile_summary))
  for (nm in names(score_terms)) {
    col <- score_terms[[nm]]
    if (!col %in% names(profile_summary)) next
    z <- .qdesn_dynamic_fitforecast_robust_z(profile_summary[[col]])
    ok <- is.finite(z)
    score[ok] <- score[ok] + score_weights[[nm]] * z[ok]
    weight_used[ok] <- weight_used[ok] + score_weights[[nm]]
  }
  score[weight_used > 0] <- score[weight_used > 0] / weight_used[weight_used > 0]
  score[weight_used <= 0] <- NA_real_
  profile_summary$rank_score_low_is_better <- score
  profile_summary$rank_score_weight_used <- weight_used
  profile_summary <- profile_summary[order(profile_summary$rank_score_low_is_better, profile_summary$screening_profile_base), , drop = FALSE]
  profile_summary$profile_rank <- seq_len(nrow(profile_summary))

  list(
    fit_summary_path = fit_summary_path,
    report_root = report_root,
    fit_forecast_summary = fit_enriched,
    profile_cell_summary = cell_summary,
    profile_ranking = profile_summary,
    manifest = list(
      generated_at = as.character(Sys.time()),
      fit_summary_path = fit_summary_path,
      report_root = report_root %||% dirname(dirname(fit_summary_path)),
      n_fit_rows = nrow(fit_summary),
      n_fit_rows_with_complete_leads = nrow(fit_enriched),
      n_profile_cells = nrow(cell_summary),
      n_ranked_profiles = nrow(profile_summary),
      collapse_tau0 = isTRUE(collapse_tau0),
      campaign_forecast_metric_cols = as.list(campaign_forecast_metric_cols),
      campaign_forecast_metric_cols_all_missing = campaign_forecast_all_missing,
      score_terms = as.list(score_terms),
      score_weights = as.list(score_weights)
    )
  )
}

qdesn_dynamic_fitforecast_write_screen_ranking <- function(fit_summary_path,
                                                           report_root = NULL,
                                                           out_dir = NULL,
                                                           top_n = 15L) {
  fit_summary_path <- .qdesn_validation_resolve_path(fit_summary_path, must_work = TRUE)
  report_root <- report_root %||% dirname(dirname(fit_summary_path))
  out_dir <- out_dir %||% report_root
  out_dir <- .qdesn_validation_resolve_path(out_dir, must_work = FALSE)
  rank_obj <- qdesn_dynamic_fitforecast_rank_screen(
    fit_summary_path = fit_summary_path,
    report_root = report_root
  )
  table_dir <- file.path(out_dir, "tables")
  summary_dir <- file.path(out_dir, "summary")
  manifest_dir <- file.path(out_dir, "manifest")
  dir.create(table_dir, recursive = TRUE, showWarnings = FALSE)
  dir.create(summary_dir, recursive = TRUE, showWarnings = FALSE)
  dir.create(manifest_dir, recursive = TRUE, showWarnings = FALSE)

  paths <- list(
    fit_forecast_summary = file.path(table_dir, "qdesn_tt500_vb_screen_fit_forecast_summary.csv"),
    profile_cell_summary = file.path(table_dir, "qdesn_tt500_vb_screen_profile_cell_summary.csv"),
    profile_ranking = file.path(table_dir, "qdesn_tt500_vb_screen_profile_ranking.csv"),
    summary = file.path(summary_dir, "qdesn_tt500_vb_screen_profile_ranking.md"),
    manifest = file.path(manifest_dir, "qdesn_tt500_vb_screen_profile_ranking_manifest.json")
  )
  .qdesn_validation_write_df(rank_obj$fit_forecast_summary, paths$fit_forecast_summary)
  .qdesn_validation_write_df(rank_obj$profile_cell_summary, paths$profile_cell_summary)
  .qdesn_validation_write_df(rank_obj$profile_ranking, paths$profile_ranking)

  top <- utils::head(rank_obj$profile_ranking, as.integer(top_n)[1L])
  display_cols <- intersect(
    c(
      "profile_rank", "screening_profile_base", "rank_score_low_is_better",
      "n_cells", "families", "taus", "D", "n_each", "alpha", "rho",
      "m", "readout_y_lags", "reservoir_lags", "pi_w", "pi_in",
      "train_qtrue_mae_mean_mean", "holdout_qtrue_mae_mean_mean",
      "forecast_all_qtrue_mae_mean_mean", "forecast_all_pinball_mean_mean_mean",
      "forecast_l1_5_qtrue_mae_mean_mean", "runtime_sec_mean_mean",
      "p_over_n_tt500_mean_mean"
    ),
    names(top)
  )
  lines <- c(
    "# Q-DESN TT500 VB Screen Ranking",
    "",
    sprintf("- generated_at: `%s`", as.character(Sys.time())),
    sprintf("- fit_summary_path: `%s`", fit_summary_path),
    sprintf("- fit_rows: `%d`", rank_obj$manifest$n_fit_rows),
    sprintf("- fit_rows_with_complete_leads: `%d`", rank_obj$manifest$n_fit_rows_with_complete_leads),
    sprintf("- ranked_profiles: `%d`", rank_obj$manifest$n_ranked_profiles),
    sprintf("- campaign_forecast_metric_cols_all_missing: `%s`", as.character(rank_obj$manifest$campaign_forecast_metric_cols_all_missing)),
    "",
    "The ranking is built from per-fit rolling-origin `forecast_lead_metrics.csv` files. Campaign-level `forecast_*` scalar columns are treated as non-authoritative for this screen.",
    "",
    "Lower `rank_score_low_is_better` is better. The score is a robust-z weighted blend of train/holdout quantile recovery, all-lead and short-lead rolling-origin forecast metrics, runtime, and dimension.",
    "",
    "## Top Profiles",
    .qdesn_validation_df_to_markdown(top[, display_cols, drop = FALSE]),
    "",
    sprintf("- fit_forecast_summary: `%s`", paths$fit_forecast_summary),
    sprintf("- profile_cell_summary: `%s`", paths$profile_cell_summary),
    sprintf("- profile_ranking: `%s`", paths$profile_ranking)
  )
  .qdesn_validation_write_lines(paths$summary, lines)
  rank_obj$manifest$output_paths <- paths
  jsonlite::write_json(rank_obj$manifest, paths$manifest, pretty = TRUE, auto_unbox = TRUE, null = "null")
  invisible(c(rank_obj, list(output_paths = paths)))
}

.qdesn_dynamic_fitforecast_metric_col <- function(df, candidates) {
  hit <- intersect(as.character(candidates), names(df))
  if (length(hit)) hit[[1L]] else NA_character_
}

.qdesn_dynamic_fitforecast_num_col <- function(df, candidates, default = NA_real_) {
  col <- .qdesn_dynamic_fitforecast_metric_col(df, candidates)
  if (!is.na(col)) return(as.numeric(df[[col]]))
  rep(default, nrow(df))
}

qdesn_dynamic_fitforecast_load_vb_baseline <- function(baseline_path,
                                                       fit_size = 500L,
                                                       families = c("gausmix", "laplace", "normal"),
                                                       taus = c(0.05, 0.25, 0.50)) {
  baseline_path <- .qdesn_validation_resolve_path(baseline_path, must_work = TRUE)
  baseline <- utils::read.csv(baseline_path, stringsAsFactors = FALSE, check.names = FALSE)
  if (!nrow(baseline)) stop(sprintf("Baseline interface is empty: %s", baseline_path), call. = FALSE)

  family_col <- .qdesn_dynamic_fitforecast_metric_col(baseline, c("family", "dynamic_family", "source_family"))
  tau_col <- .qdesn_dynamic_fitforecast_metric_col(baseline, c("tau"))
  fit_col <- .qdesn_dynamic_fitforecast_metric_col(baseline, c("fit_size", "effective_fit_size"))
  inference_col <- .qdesn_dynamic_fitforecast_metric_col(baseline, c("inference", "inference_method", "method"))
  variant_col <- .qdesn_dynamic_fitforecast_metric_col(baseline, c("model_variant", "model", "model_key"))
  model_family_col <- .qdesn_dynamic_fitforecast_metric_col(baseline, c("model_family"))
  if (any(is.na(c(family_col, tau_col, fit_col, inference_col, variant_col)))) {
    stop("Baseline interface is missing family/tau/fit/inference/model columns.", call. = FALSE)
  }

  fam <- as.character(baseline[[family_col]])
  tau <- as.numeric(baseline[[tau_col]])
  fit <- as.integer(baseline[[fit_col]])
  inf <- tolower(as.character(baseline[[inference_col]]))
  variant <- tolower(as.character(baseline[[variant_col]]))
  model_family <- if (!is.na(model_family_col)) tolower(as.character(baseline[[model_family_col]])) else variant
  keep <- fam %in% families &
    tau %in% as.numeric(taus) &
    fit == as.integer(fit_size)[1L] &
    inf %in% c("vb", "vb_ld", "ldvb", "vb--ld") &
    (variant %in% c("dqlm", "exdqlm") | model_family %in% c("dqlm", "exdqlm", "exdqlm_dqlm"))
  baseline <- baseline[keep, , drop = FALSE]
  if (!nrow(baseline)) {
    stop(sprintf("No matching DQLM/exDQLM VB baseline rows found in %s.", baseline_path), call. = FALSE)
  }
  baseline$family <- fam[keep]
  baseline$tau <- tau[keep]
  baseline$model_variant_baseline <- variant[keep]
  baseline$baseline_forecast_mae <- .qdesn_dynamic_fitforecast_num_col(
    baseline,
    c("forecast_qtrue_mae_lead_weighted", "forecast_h1000_q_mae", "forecast_all_qtrue_mae", "forecast_all_qtrue_mae_mean")
  )
  baseline$baseline_forecast_pinball <- .qdesn_dynamic_fitforecast_num_col(
    baseline,
    c("forecast_pinball_mean_lead_weighted", "forecast_h1000_pinball_mean", "forecast_all_pinball_mean", "forecast_all_pinball_mean_mean")
  )
  baseline$baseline_fit_rmse <- .qdesn_dynamic_fitforecast_num_col(
    baseline,
    c("fit_qtrue_rmse", "fit_q_rmse", "train_qtrue_rmse", "train_qtrue_rmse_mean")
  )
  baseline$baseline_fit_pinball <- .qdesn_dynamic_fitforecast_num_col(
    baseline,
    c("fit_pinball_mean", "train_pinball_tau", "train_pinball_tau_mean")
  )

  keys <- unique(baseline[, c("family", "tau"), drop = FALSE])
  rows <- lapply(seq_len(nrow(keys)), function(i) {
    sub <- baseline[baseline$family == keys$family[[i]] & baseline$tau == keys$tau[[i]], , drop = FALSE]
    pick_metric <- function(metric_col) {
      vals <- as.numeric(sub[[metric_col]])
      ok <- is.finite(vals)
      if (!any(ok)) return(list(value = NA_real_, model = NA_character_))
      idx <- which(ok)[which.min(vals[ok])]
      list(value = vals[[idx]], model = as.character(sub$model_variant_baseline[[idx]]))
    }
    mae <- pick_metric("baseline_forecast_mae")
    pin <- pick_metric("baseline_forecast_pinball")
    fit_rmse <- pick_metric("baseline_fit_rmse")
    fit_pin <- pick_metric("baseline_fit_pinball")
    data.frame(
      family = keys$family[[i]],
      tau = as.numeric(keys$tau[[i]]),
      baseline_forecast_mae = mae$value,
      baseline_forecast_mae_model = mae$model,
      baseline_forecast_pinball = pin$value,
      baseline_forecast_pinball_model = pin$model,
      baseline_fit_rmse = fit_rmse$value,
      baseline_fit_rmse_model = fit_rmse$model,
      baseline_fit_pinball = fit_pin$value,
      baseline_fit_pinball_model = fit_pin$model,
      baseline_source_path = baseline_path,
      stringsAsFactors = FALSE
    )
  })
  out <- do.call(rbind, rows)
  out <- out[order(out$family, out$tau), , drop = FALSE]
  rownames(out) <- NULL
  out
}

qdesn_dynamic_fitforecast_rank_screen_against_vb_baseline <- function(fit_forecast_summary_path,
                                                                      baseline_path,
                                                                      out_dir = NULL,
                                                                      fit_size = 500L,
                                                                      top_n = 20L) {
  fit_forecast_summary_path <- .qdesn_validation_resolve_path(fit_forecast_summary_path, must_work = TRUE)
  q <- utils::read.csv(fit_forecast_summary_path, stringsAsFactors = FALSE, check.names = FALSE)
  if (!nrow(q)) stop(sprintf("Q-DESN fit+forecast summary is empty: %s", fit_forecast_summary_path), call. = FALSE)
  q$screening_profile_base <- qdesn_dynamic_fitforecast_screening_profile_base(q$screening_profile_id)
  q <- .qdesn_dynamic_fitforecast_fill_profile_metadata(q)
  q <- q[as.integer(q$fit_size %||% fit_size) == as.integer(fit_size)[1L], , drop = FALSE]
  if (!nrow(q)) stop(sprintf("No Q-DESN rows with fit_size=%d.", as.integer(fit_size)[1L]), call. = FALSE)
  q$family <- as.character(q$family)
  q$tau <- as.numeric(q$tau)
  q$qdesn_forecast_mae <- .qdesn_dynamic_fitforecast_num_col(q, c("forecast_all_qtrue_mae", "forecast_all_qtrue_mae_mean"))
  q$qdesn_forecast_pinball <- .qdesn_dynamic_fitforecast_num_col(q, c("forecast_all_pinball_mean", "forecast_all_pinball_mean_mean"))
  q$qdesn_fit_rmse <- .qdesn_dynamic_fitforecast_num_col(q, c("train_qtrue_rmse", "train_qtrue_rmse_mean"))
  q$qdesn_fit_pinball <- .qdesn_dynamic_fitforecast_num_col(q, c("train_pinball_tau", "train_pinball_tau_mean", "fit_pinball_mean"))
  q$qdesn_runtime_sec <- .qdesn_dynamic_fitforecast_num_col(q, c("runtime_sec", "fit_runtime_seconds"))
  q$qdesn_dimension_p <- .qdesn_dynamic_fitforecast_num_col(q, c("dimension_p_estimate"))
  q$qdesn_p_over_n <- .qdesn_dynamic_fitforecast_num_col(q, c("p_over_n_tt500"))

  cell_cols <- c("screening_profile_base", "family", "tau")
  q_cell <- .qdesn_dynamic_fitforecast_group_summary(
    q,
    group_cols = cell_cols,
    numeric_cols = c(
      "qdesn_forecast_mae", "qdesn_forecast_pinball", "qdesn_fit_rmse",
      "qdesn_fit_pinball", "qdesn_runtime_sec", "qdesn_dimension_p", "qdesn_p_over_n"
    ),
    extra_fun = function(sub) {
      data.frame(
        screening_profile_id_representative = as.character(.qdesn_dynamic_fitforecast_first_or_na(sub, "screening_profile_id", NA_character_)),
        profile_role = as.character(.qdesn_dynamic_fitforecast_first_or_na(sub, "profile_role", NA_character_)),
        D = as.integer(.qdesn_dynamic_fitforecast_first_or_na(sub, "D", NA_integer_)),
        n_each = as.integer(.qdesn_dynamic_fitforecast_first_or_na(sub, "n_each", NA_integer_)),
        alpha = as.numeric(.qdesn_dynamic_fitforecast_first_or_na(sub, "alpha", NA_real_)),
        rho = as.numeric(.qdesn_dynamic_fitforecast_first_or_na(sub, "rho", NA_real_)),
        m = as.integer(.qdesn_dynamic_fitforecast_first_or_na(sub, "m", NA_integer_)),
        readout_y_lags = as.integer(.qdesn_dynamic_fitforecast_first_or_na(sub, "readout_y_lags", NA_integer_)),
        reservoir_lags = as.integer(.qdesn_dynamic_fitforecast_first_or_na(sub, "reservoir_lags", NA_integer_)),
        pi_w = as.numeric(.qdesn_dynamic_fitforecast_first_or_na(sub, "pi_w", NA_real_)),
        pi_in = as.numeric(.qdesn_dynamic_fitforecast_first_or_na(sub, "pi_in", NA_real_)),
        stringsAsFactors = FALSE
      )
    }
  )
  baseline <- qdesn_dynamic_fitforecast_load_vb_baseline(
    baseline_path = baseline_path,
    fit_size = fit_size,
    families = sort(unique(q_cell$family)),
    taus = sort(unique(q_cell$tau))
  )
  cell <- merge(q_cell, baseline, by = c("family", "tau"), all.x = TRUE, sort = FALSE)
  ratio <- function(num, den) {
    out <- as.numeric(num) / as.numeric(den)
    out[!is.finite(out)] <- NA_real_
    out
  }
  cell$forecast_mae_ratio_vs_best_vb_baseline <- ratio(cell$qdesn_forecast_mae_mean, cell$baseline_forecast_mae)
  cell$forecast_pinball_ratio_vs_best_vb_baseline <- ratio(cell$qdesn_forecast_pinball_mean, cell$baseline_forecast_pinball)
  cell$fit_rmse_ratio_vs_best_vb_baseline <- ratio(cell$qdesn_fit_rmse_mean, cell$baseline_fit_rmse)
  cell$fit_pinball_ratio_vs_best_vb_baseline <- ratio(cell$qdesn_fit_pinball_mean, cell$baseline_fit_pinball)
  cell$beats_forecast_mae_baseline <- is.finite(cell$forecast_mae_ratio_vs_best_vb_baseline) &
    cell$forecast_mae_ratio_vs_best_vb_baseline < 1
  cell$beats_forecast_pinball_baseline <- is.finite(cell$forecast_pinball_ratio_vs_best_vb_baseline) &
    cell$forecast_pinball_ratio_vs_best_vb_baseline < 1
  cell$beats_fit_rmse_baseline <- is.finite(cell$fit_rmse_ratio_vs_best_vb_baseline) &
    cell$fit_rmse_ratio_vs_best_vb_baseline < 1
  cell$beats_fit_pinball_baseline <- is.finite(cell$fit_pinball_ratio_vs_best_vb_baseline) &
    cell$fit_pinball_ratio_vs_best_vb_baseline < 1
  cell$beats_all_primary_baselines <- cell$beats_forecast_mae_baseline &
    cell$beats_forecast_pinball_baseline &
    cell$beats_fit_rmse_baseline &
    cell$beats_fit_pinball_baseline

  profile <- .qdesn_dynamic_fitforecast_group_summary(
    cell,
    group_cols = c("screening_profile_base"),
    numeric_cols = c(
      "forecast_mae_ratio_vs_best_vb_baseline",
      "forecast_pinball_ratio_vs_best_vb_baseline",
      "fit_rmse_ratio_vs_best_vb_baseline",
      "fit_pinball_ratio_vs_best_vb_baseline",
      "qdesn_runtime_sec_mean",
      "qdesn_p_over_n_mean"
    ),
    extra_fun = function(sub) {
      data.frame(
        n_cells = nrow(sub),
        n_cells_beating_forecast_mae = sum(as.logical(sub$beats_forecast_mae_baseline), na.rm = TRUE),
        n_cells_beating_forecast_pinball = sum(as.logical(sub$beats_forecast_pinball_baseline), na.rm = TRUE),
        n_cells_beating_fit_rmse = sum(as.logical(sub$beats_fit_rmse_baseline), na.rm = TRUE),
        n_cells_beating_fit_pinball = sum(as.logical(sub$beats_fit_pinball_baseline), na.rm = TRUE),
        n_cells_beating_all_primary = sum(as.logical(sub$beats_all_primary_baselines), na.rm = TRUE),
        max_forecast_mae_ratio = max(as.numeric(sub$forecast_mae_ratio_vs_best_vb_baseline), na.rm = TRUE),
        max_forecast_pinball_ratio = max(as.numeric(sub$forecast_pinball_ratio_vs_best_vb_baseline), na.rm = TRUE),
        max_fit_rmse_ratio = max(as.numeric(sub$fit_rmse_ratio_vs_best_vb_baseline), na.rm = TRUE),
        max_fit_pinball_ratio = max(as.numeric(sub$fit_pinball_ratio_vs_best_vb_baseline), na.rm = TRUE),
        families = paste(sort(unique(as.character(sub$family))), collapse = ";"),
        taus = paste(sort(unique(as.character(sub$tau))), collapse = ";"),
        profile_role = as.character(.qdesn_dynamic_fitforecast_first_or_na(sub, "profile_role", NA_character_)),
        D = as.integer(.qdesn_dynamic_fitforecast_first_or_na(sub, "D", NA_integer_)),
        n_each = as.integer(.qdesn_dynamic_fitforecast_first_or_na(sub, "n_each", NA_integer_)),
        alpha = as.numeric(.qdesn_dynamic_fitforecast_first_or_na(sub, "alpha", NA_real_)),
        rho = as.numeric(.qdesn_dynamic_fitforecast_first_or_na(sub, "rho", NA_real_)),
        m = as.integer(.qdesn_dynamic_fitforecast_first_or_na(sub, "m", NA_integer_)),
        readout_y_lags = as.integer(.qdesn_dynamic_fitforecast_first_or_na(sub, "readout_y_lags", NA_integer_)),
        reservoir_lags = as.integer(.qdesn_dynamic_fitforecast_first_or_na(sub, "reservoir_lags", NA_integer_)),
        pi_w = as.numeric(.qdesn_dynamic_fitforecast_first_or_na(sub, "pi_w", NA_real_)),
        pi_in = as.numeric(.qdesn_dynamic_fitforecast_first_or_na(sub, "pi_in", NA_real_)),
        stringsAsFactors = FALSE
      )
    }
  )
  finite_or_na <- function(x) {
    x[!is.finite(x)] <- NA_real_
    x
  }
  for (nm in c("max_forecast_mae_ratio", "max_forecast_pinball_ratio", "max_fit_rmse_ratio", "max_fit_pinball_ratio")) {
    profile[[nm]] <- finite_or_na(as.numeric(profile[[nm]]))
  }
  profile$dominance_pass <- profile$n_cells == length(unique(paste(q_cell$family, q_cell$tau, sep = "|"))) &
    profile$n_cells_beating_all_primary == profile$n_cells
  profile$dominance_score_low_is_better <- pmax(
    as.numeric(profile$max_forecast_mae_ratio),
    as.numeric(profile$max_forecast_pinball_ratio),
    as.numeric(profile$max_fit_rmse_ratio),
    as.numeric(profile$max_fit_pinball_ratio),
    na.rm = TRUE
  )
  profile <- profile[order(profile$dominance_score_low_is_better, profile$screening_profile_base), , drop = FALSE]
  profile$dominance_rank <- seq_len(nrow(profile))

  out_dir <- .qdesn_validation_resolve_path(out_dir %||% dirname(dirname(fit_forecast_summary_path)), must_work = FALSE)
  table_dir <- file.path(out_dir, "tables")
  summary_dir <- file.path(out_dir, "summary")
  manifest_dir <- file.path(out_dir, "manifest")
  dir.create(table_dir, recursive = TRUE, showWarnings = FALSE)
  dir.create(summary_dir, recursive = TRUE, showWarnings = FALSE)
  dir.create(manifest_dir, recursive = TRUE, showWarnings = FALSE)
  paths <- list(
    baseline = file.path(table_dir, "qdesn_tt500_vb_baseline_targets.csv"),
    cell_summary = file.path(table_dir, "qdesn_tt500_vb_dominance_cell_summary.csv"),
    profile_ranking = file.path(table_dir, "qdesn_tt500_vb_dominance_profile_ranking.csv"),
    summary = file.path(summary_dir, "qdesn_tt500_vb_dominance_ranking.md"),
    manifest = file.path(manifest_dir, "qdesn_tt500_vb_dominance_manifest.json")
  )
  .qdesn_validation_write_df(baseline, paths$baseline)
  .qdesn_validation_write_df(cell, paths$cell_summary)
  .qdesn_validation_write_df(profile, paths$profile_ranking)
  top <- utils::head(profile, as.integer(top_n)[1L])
  display_cols <- intersect(
    c(
      "dominance_rank", "screening_profile_base", "dominance_pass",
      "dominance_score_low_is_better", "n_cells", "n_cells_beating_all_primary",
      "n_cells_beating_forecast_mae", "n_cells_beating_forecast_pinball",
      "max_forecast_mae_ratio", "max_forecast_pinball_ratio",
      "max_fit_rmse_ratio", "max_fit_pinball_ratio", "D", "n_each", "alpha", "rho",
      "m", "readout_y_lags", "reservoir_lags", "pi_w", "pi_in",
      "profile_role", "qdesn_runtime_sec_mean_mean", "qdesn_p_over_n_mean_mean"
    ),
    names(top)
  )
  lines <- c(
    "# Q-DESN TT500 VB Dominance Ranking",
    "",
    sprintf("- generated_at: `%s`", as.character(Sys.time())),
    sprintf("- qdesn_fit_forecast_summary: `%s`", fit_forecast_summary_path),
    sprintf("- baseline_path: `%s`", .qdesn_validation_resolve_path(baseline_path, must_work = TRUE)),
    sprintf("- baseline_cells: `%d`", nrow(baseline)),
    sprintf("- qdesn_cells: `%d`", nrow(cell)),
    sprintf("- ranked_profiles: `%d`", nrow(profile)),
    "",
    "A profile passes dominance only if every family x tau cell beats the best available DQLM/exDQLM VB baseline on rolling-origin forecast MAE, rolling-origin forecast pinball, fit RMSE, and fit pinball.",
    "",
    "## Top Profiles",
    .qdesn_validation_df_to_markdown(top[, display_cols, drop = FALSE]),
    "",
    sprintf("- baseline_targets: `%s`", paths$baseline),
    sprintf("- cell_summary: `%s`", paths$cell_summary),
    sprintf("- profile_ranking: `%s`", paths$profile_ranking)
  )
  .qdesn_validation_write_lines(paths$summary, lines)
  manifest <- list(
    generated_at = as.character(Sys.time()),
    fit_forecast_summary_path = fit_forecast_summary_path,
    baseline_path = .qdesn_validation_resolve_path(baseline_path, must_work = TRUE),
    fit_size = as.integer(fit_size)[1L],
    n_baseline_cells = nrow(baseline),
    n_qdesn_cells = nrow(cell),
    n_profiles = nrow(profile),
    n_dominance_pass = sum(as.logical(profile$dominance_pass), na.rm = TRUE),
    output_paths = paths
  )
  jsonlite::write_json(manifest, paths$manifest, pretty = TRUE, auto_unbox = TRUE, null = "null")
  invisible(list(
    baseline = baseline,
    cell_summary = cell,
    profile_ranking = profile,
    manifest = manifest,
    output_paths = paths
  ))
}

.qdesn_dynamic_fitforecast_dominance_profile_id <- function(D,
                                                            n_each,
                                                            alpha,
                                                            rho,
                                                            m,
                                                            readout_y_lags,
                                                            reservoir_lags,
                                                            pi_w,
                                                            pi_in,
                                                            prefix = "tt500vb_tref") {
  sprintf(
    "%s_d%d_n%d_a%s_r%s_m%d_lag%d_rl%d_pw%s_pin%s",
    as.character(prefix)[1L],
    as.integer(D)[1L],
    as.integer(n_each)[1L],
    .qdesn_dynamic_fitforecast_decimal_token(alpha),
    .qdesn_dynamic_fitforecast_decimal_token(rho),
    as.integer(m)[1L],
    as.integer(readout_y_lags)[1L],
    as.integer(reservoir_lags)[1L],
    .qdesn_dynamic_fitforecast_decimal_token(pi_w),
    .qdesn_dynamic_fitforecast_decimal_token(pi_in)
  )
}

.qdesn_dynamic_fitforecast_primary_worst_ratio <- function(df) {
  ratio_cols <- intersect(
    c(
      "forecast_mae_ratio_vs_best_vb_baseline",
      "forecast_pinball_ratio_vs_best_vb_baseline",
      "fit_rmse_ratio_vs_best_vb_baseline",
      "fit_pinball_ratio_vs_best_vb_baseline"
    ),
    names(df)
  )
  if (!length(ratio_cols)) return(rep(NA_real_, nrow(df)))
  vals <- as.matrix(data.frame(lapply(df[ratio_cols], as.numeric), check.names = FALSE))
  out <- apply(vals, 1L, function(x) {
    x <- x[is.finite(x)]
    if (!length(x)) NA_real_ else max(x)
  })
  as.numeric(out)
}

.qdesn_dynamic_fitforecast_parse_dominance_id <- function(profile_id) {
  qdesn_dynamic_fitforecast_parse_profile_base(profile_id)
}

qdesn_dynamic_fitforecast_dominance_diagnostics <- function(cell_summary_path,
                                                            profile_ranking_path = NULL,
                                                            top_n_per_cell = 5L) {
  cell_summary_path <- .qdesn_validation_resolve_path(cell_summary_path, must_work = TRUE)
  cell <- utils::read.csv(cell_summary_path, stringsAsFactors = FALSE, check.names = FALSE)
  if (!nrow(cell)) stop(sprintf("Dominance cell summary is empty: %s", cell_summary_path), call. = FALSE)
  if (!all(c("family", "tau") %in% names(cell))) {
    stop("Dominance cell summary must contain `family` and `tau`.", call. = FALSE)
  }
  id_col <- .qdesn_dynamic_fitforecast_metric_col(cell, c("screening_profile_base", "screening_profile_id_representative"))
  if (is.na(id_col)) stop("Dominance cell summary is missing a profile identifier column.", call. = FALSE)
  cell$screening_profile_base <- as.character(cell[[id_col]])
  cell$family <- as.character(cell$family)
  cell$tau <- as.numeric(cell$tau)
  parsed <- .qdesn_dynamic_fitforecast_parse_dominance_id(cell$screening_profile_base)
  for (nm in intersect(names(parsed), c("D", "n_each", "alpha", "rho", "m", "readout_y_lags", "reservoir_lags", "pi_w", "pi_in"))) {
    if (!nm %in% names(cell)) {
      cell[[nm]] <- parsed[[nm]]
    } else {
      current <- cell[[nm]]
      missing <- is.na(current) | (is.character(current) & !nzchar(current))
      cell[[nm]][missing] <- parsed[[nm]][missing]
    }
  }
  cell$primary_worst_ratio_vs_baseline <- .qdesn_dynamic_fitforecast_primary_worst_ratio(cell)
  cell <- cell[order(cell$family, cell$tau, cell$primary_worst_ratio_vs_baseline, cell$screening_profile_base), , drop = FALSE]

  key <- paste(cell$family, cell$tau, sep = "\r")
  top_n_per_cell <- as.integer(top_n_per_cell)[1L]
  if (!is.finite(top_n_per_cell) || top_n_per_cell < 1L) top_n_per_cell <- 5L
  top <- .qdesn_validation_bind_rows(lapply(split(seq_len(nrow(cell)), key), function(idx) {
    sub <- cell[idx, , drop = FALSE]
    sub <- utils::head(sub[order(sub$primary_worst_ratio_vs_baseline, sub$screening_profile_base), , drop = FALSE], top_n_per_cell)
    sub$cell_rank <- seq_len(nrow(sub))
    sub
  }))
  top <- top[order(top$family, top$tau, top$cell_rank), , drop = FALSE]

  cell_gap <- .qdesn_validation_bind_rows(lapply(split(seq_len(nrow(cell)), key), function(idx) {
    sub <- cell[idx, , drop = FALSE]
    sub <- sub[order(sub$primary_worst_ratio_vs_baseline, sub$screening_profile_base), , drop = FALSE]
    best <- sub[1L, , drop = FALSE]
    data.frame(
      family = best$family[[1L]],
      tau = as.numeric(best$tau[[1L]]),
      n_profiles = nrow(sub),
      n_profiles_beating_all_primary = if ("beats_all_primary_baselines" %in% names(sub)) sum(as.logical(sub$beats_all_primary_baselines), na.rm = TRUE) else NA_integer_,
      best_profile = best$screening_profile_base[[1L]],
      best_primary_worst_ratio = as.numeric(best$primary_worst_ratio_vs_baseline[[1L]]),
      best_forecast_mae_ratio = as.numeric(best$forecast_mae_ratio_vs_best_vb_baseline %||% NA_real_)[1L],
      best_forecast_pinball_ratio = as.numeric(best$forecast_pinball_ratio_vs_best_vb_baseline %||% NA_real_)[1L],
      best_fit_rmse_ratio = as.numeric(best$fit_rmse_ratio_vs_best_vb_baseline %||% NA_real_)[1L],
      best_fit_pinball_ratio = as.numeric(best$fit_pinball_ratio_vs_best_vb_baseline %||% NA_real_)[1L],
      stringsAsFactors = FALSE
    )
  }))
  cell_gap <- cell_gap[order(cell_gap$family, cell_gap$tau), , drop = FALSE]

  factor_summary_one <- function(cols) {
    cols <- intersect(cols, names(cell))
    if (!length(cols)) return(data.frame(stringsAsFactors = FALSE))
    .qdesn_dynamic_fitforecast_group_summary(
      cell,
      group_cols = cols,
      numeric_cols = c("primary_worst_ratio_vs_baseline"),
      extra_fun = function(sub) {
        data.frame(
          n_cell_profiles = nrow(sub),
          n_cell_wins = sum(as.numeric(sub$primary_worst_ratio_vs_baseline) ==
                              ave(as.numeric(sub$primary_worst_ratio_vs_baseline), sub$family, sub$tau, FUN = min),
                            na.rm = TRUE),
          stringsAsFactors = FALSE
        )
      }
    )
  }
  tag_factor <- function(df, factor) {
    if (!is.data.frame(df) || !nrow(df)) return(data.frame(stringsAsFactors = FALSE))
    df$factor <- as.character(factor)[1L]
    df
  }
  factor_summary <- .qdesn_validation_bind_rows(list(
    tag_factor(factor_summary_one("D"), "D"),
    tag_factor(factor_summary_one("n_each"), "n_each"),
    tag_factor(factor_summary_one(c("alpha", "rho")), "alpha_rho"),
    tag_factor(factor_summary_one("reservoir_lags"), "reservoir_lags"),
    tag_factor(factor_summary_one(c("pi_w", "pi_in")), "sparsity")
  ))

  ranking <- data.frame(stringsAsFactors = FALSE)
  if (!is.null(profile_ranking_path) && nzchar(as.character(profile_ranking_path)[1L])) {
    profile_ranking_path <- .qdesn_validation_resolve_path(profile_ranking_path, must_work = TRUE)
    ranking <- utils::read.csv(profile_ranking_path, stringsAsFactors = FALSE, check.names = FALSE)
  }
  list(
    cell_summary_path = cell_summary_path,
    profile_ranking_path = profile_ranking_path %||% NA_character_,
    cell_summary = cell,
    top_per_cell = top,
    cell_gap_summary = cell_gap,
    factor_summary = factor_summary,
    profile_ranking = ranking
  )
}

qdesn_dynamic_fitforecast_write_dominance_diagnostics <- function(report_root = NULL,
                                                                  cell_summary_path = NULL,
                                                                  profile_ranking_path = NULL,
                                                                  out_dir = NULL,
                                                                  top_n_per_cell = 5L) {
  if (!is.null(report_root) && nzchar(as.character(report_root)[1L])) {
    report_root <- .qdesn_validation_resolve_path(report_root, must_work = FALSE)
    cell_summary_path <- cell_summary_path %||% file.path(report_root, "tables", "qdesn_tt500_vb_dominance_cell_summary.csv")
    profile_ranking_path <- profile_ranking_path %||% file.path(report_root, "tables", "qdesn_tt500_vb_dominance_profile_ranking.csv")
    out_dir <- out_dir %||% file.path(report_root, "diagnostics", "qdesn_tt500_vb_dominance")
  }
  out_dir <- .qdesn_validation_resolve_path(out_dir %||% dirname(cell_summary_path), must_work = FALSE)
  diag <- qdesn_dynamic_fitforecast_dominance_diagnostics(
    cell_summary_path = cell_summary_path,
    profile_ranking_path = profile_ranking_path,
    top_n_per_cell = top_n_per_cell
  )
  table_dir <- file.path(out_dir, "tables")
  summary_dir <- file.path(out_dir, "summary")
  manifest_dir <- file.path(out_dir, "manifest")
  .qdesn_validation_dir_create(table_dir)
  .qdesn_validation_dir_create(summary_dir)
  .qdesn_validation_dir_create(manifest_dir)
  paths <- list(
    top_per_cell = file.path(table_dir, "qdesn_tt500_vb_dominance_top_profiles_per_cell.csv"),
    cell_gap_summary = file.path(table_dir, "qdesn_tt500_vb_dominance_cell_gap_summary.csv"),
    factor_summary = file.path(table_dir, "qdesn_tt500_vb_dominance_factor_summary.csv"),
    report = file.path(summary_dir, "qdesn_tt500_vb_dominance_diagnostics.md"),
    manifest = file.path(manifest_dir, "qdesn_tt500_vb_dominance_diagnostics_manifest.json")
  )
  .qdesn_validation_write_df(diag$top_per_cell, paths$top_per_cell)
  .qdesn_validation_write_df(diag$cell_gap_summary, paths$cell_gap_summary)
  .qdesn_validation_write_df(diag$factor_summary, paths$factor_summary)
  top_cols <- intersect(
    c(
      "family", "tau", "cell_rank", "screening_profile_base",
      "primary_worst_ratio_vs_baseline", "forecast_mae_ratio_vs_best_vb_baseline",
      "forecast_pinball_ratio_vs_best_vb_baseline", "fit_rmse_ratio_vs_best_vb_baseline",
      "fit_pinball_ratio_vs_best_vb_baseline", "D", "n_each", "alpha", "rho",
      "profile_role", "qdesn_runtime_sec_mean"
    ),
    names(diag$top_per_cell)
  )
  gap_cols <- intersect(
    c("family", "tau", "n_profiles", "n_profiles_beating_all_primary", "best_profile",
      "best_primary_worst_ratio", "best_forecast_mae_ratio", "best_forecast_pinball_ratio",
      "best_fit_rmse_ratio", "best_fit_pinball_ratio"),
    names(diag$cell_gap_summary)
  )
  lines <- c(
    "# Q-DESN TT500 VB Dominance Diagnostics",
    "",
    sprintf("- generated_at: `%s`", as.character(Sys.time())),
    sprintf("- cell_summary_path: `%s`", diag$cell_summary_path),
    sprintf("- profile_ranking_path: `%s`", diag$profile_ranking_path),
    sprintf("- top_n_per_cell: `%d`", as.integer(top_n_per_cell)[1L]),
    "",
    "This diagnostic pack is cell-aware. It is intended to drive targeted VB refinement before any MCMC replacement launch.",
    "",
    "## Best Profile Per Family x Tau",
    .qdesn_validation_df_to_markdown(diag$cell_gap_summary[, gap_cols, drop = FALSE]),
    "",
    "## Top Profiles Per Cell",
    .qdesn_validation_df_to_markdown(diag$top_per_cell[, top_cols, drop = FALSE]),
    "",
    sprintf("- top_per_cell_csv: `%s`", paths$top_per_cell),
    sprintf("- cell_gap_summary_csv: `%s`", paths$cell_gap_summary),
    sprintf("- factor_summary_csv: `%s`", paths$factor_summary)
  )
  .qdesn_validation_write_lines(paths$report, lines)
  manifest <- list(
    generated_at = as.character(Sys.time()),
    top_n_per_cell = as.integer(top_n_per_cell)[1L],
    input_paths = list(
      cell_summary_path = diag$cell_summary_path,
      profile_ranking_path = diag$profile_ranking_path
    ),
    output_paths = paths,
    n_cells = nrow(diag$cell_gap_summary),
    n_top_cell_rows = nrow(diag$top_per_cell)
  )
  .qdesn_validation_write_json(paths$manifest, manifest)
  invisible(c(diag, list(output_paths = paths, manifest = manifest)))
}

qdesn_dynamic_fitforecast_targeted_refinement_profiles <- function(cell_summary_path,
                                                                   top_n_per_cell = 3L,
                                                                   screening_wave = paste0("targeted_refinement_", format(Sys.Date(), "%Y_%m_%d")),
                                                                   max_p_over_n = 0.50,
                                                                   max_profiles = 120L,
                                                                   x_feature_count = 5L,
                                                                   seed = 123L) {
  diag <- qdesn_dynamic_fitforecast_dominance_diagnostics(
    cell_summary_path = cell_summary_path,
    top_n_per_cell = top_n_per_cell
  )
  seeds <- diag$top_per_cell
  if (!nrow(seeds)) stop("No cell-level seed profiles found for targeted refinement.", call. = FALSE)

  ar_ladder <- data.frame(
    alpha = c(0.03, 0.05, 0.10, 0.20, 0.30, 0.40),
    rho = c(0.50, 0.60, 0.70, 0.80, 0.85, 0.90),
    stringsAsFactors = FALSE
  )
  sparsity <- data.frame(
    profile_role = c("targeted_sparse", "targeted_hybrid", "targeted_input_rich"),
    pi_w = c(0.05, 0.10, 0.20),
    pi_in = c(0.30, 0.80, 0.80),
    reservoir_lags = c(0L, 0L, 1L),
    stringsAsFactors = FALSE
  )
  nearest_ar <- function(alpha, rho) {
    dist <- abs(ar_ladder$alpha - as.numeric(alpha)[1L]) + abs(ar_ladder$rho - as.numeric(rho)[1L])
    idx <- unique(c(which.min(dist), pmax(1L, which.min(dist) - 1L), pmin(nrow(ar_ladder), which.min(dist) + 1L)))
    ar_ladder[idx, , drop = FALSE]
  }
  candidate_specs <- list()
  for (i in seq_len(nrow(seeds))) {
    s <- seeds[i, , drop = FALSE]
    d_vals <- unique(c(as.integer(s$D), if (as.integer(s$D) == 1L) 2L else 1L))
    n_vals <- unique(c(as.integer(s$n_each), as.integer(s$n_each) - 10L, as.integer(s$n_each) + 10L, 30L, 40L))
    n_vals <- n_vals[is.finite(n_vals) & n_vals >= 20L & n_vals <= 70L]
    ar_vals <- nearest_ar(s$alpha, s$rho)
    for (D in d_vals) {
      for (n_each in n_vals) {
        if (D >= 2L && n_each > 50L) next
        for (j in seq_len(nrow(ar_vals))) {
          for (k in seq_len(nrow(sparsity))) {
            row <- qdesn_dynamic_fitforecast_profile_row(
              D = D,
              n_each = n_each,
              alpha = ar_vals$alpha[[j]],
              rho = ar_vals$rho[[j]],
              screening_stage = "vb_dominance_targeted_refinement",
              screening_wave = screening_wave,
              profile_role = sparsity$profile_role[[k]],
              rhs_tau0 = 1e-4,
              m = 90L,
              pi_w = sparsity$pi_w[[k]],
              pi_in = sparsity$pi_in[[k]],
              washout = 300L,
              add_bias = TRUE,
              seed = seed,
              readout_y_lags = 90L,
              reservoir_lags = sparsity$reservoir_lags[[k]]
            )
            row$x_feature_count <- as.integer(x_feature_count)[1L]
            row$dimension_p_estimate <- as.integer(row$dimension_p_estimate + row$x_feature_count)
            row$p_over_n_tt500 <- as.numeric(row$dimension_p_estimate / 500)
            row$screening_profile_id <- .qdesn_dynamic_fitforecast_dominance_profile_id(
              D = row$D,
              n_each = row$n_each,
              alpha = row$alpha,
              rho = row$rho,
              m = row$m,
              readout_y_lags = row$readout_y_lags,
              reservoir_lags = row$reservoir_lags,
              pi_w = row$pi_w,
              pi_in = row$pi_in
            )
            row$targeted_source_family <- as.character(s$family)
            row$targeted_source_tau <- as.numeric(s$tau)
            row$targeted_source_rank <- as.integer(s$cell_rank)
            row$targeted_source_profile <- as.character(s$screening_profile_base)
            row$targeted_source_worst_ratio <- as.numeric(s$primary_worst_ratio_vs_baseline)
            candidate_specs[[length(candidate_specs) + 1L]] <- row
          }
        }
      }
    }
  }
  out <- .qdesn_validation_bind_rows(candidate_specs)
  if (!nrow(out)) stop("Targeted refinement produced no profiles.", call. = FALSE)
  out <- out[is.finite(as.numeric(out$p_over_n_tt500)) & as.numeric(out$p_over_n_tt500) <= as.numeric(max_p_over_n), , drop = FALSE]
  if (!nrow(out)) stop("All targeted refinement profiles were removed by the p/n gate.", call. = FALSE)
  # Deduplicate by executable profile ID while preserving a compact source-cell ledger.
  split_idx <- split(seq_len(nrow(out)), as.character(out$screening_profile_id))
  out <- .qdesn_validation_bind_rows(lapply(split_idx, function(idx) {
    sub <- out[idx, , drop = FALSE]
    row <- sub[1L, , drop = FALSE]
    row$targeted_source_cells <- paste(unique(paste(sub$targeted_source_family, sub$targeted_source_tau, sep = ":")), collapse = ";")
    row$targeted_source_profiles <- paste(unique(as.character(sub$targeted_source_profile)), collapse = ";")
    row$targeted_source_best_rank <- min(as.integer(sub$targeted_source_rank), na.rm = TRUE)
    row$targeted_source_best_worst_ratio <- min(as.numeric(sub$targeted_source_worst_ratio), na.rm = TRUE)
    row
  }))
  out <- out[order(out$targeted_source_best_worst_ratio, out$p_over_n_tt500, out$D, out$n_each, out$screening_profile_id), , drop = FALSE]
  max_profiles <- as.integer(max_profiles)[1L]
  if (is.finite(max_profiles) && max_profiles > 0L && nrow(out) > max_profiles) {
    out <- utils::head(out, max_profiles)
  }
  out$enabled <- TRUE
  rownames(out) <- NULL
  out
}

.qdesn_dynamic_fitforecast_join_profile_registry <- function(cell,
                                                            source_profiles_path = NULL) {
  if (is.null(source_profiles_path) || !nzchar(as.character(source_profiles_path)[1L])) {
    return(cell)
  }
  source_profiles_path <- .qdesn_validation_resolve_path(source_profiles_path, must_work = TRUE)
  profiles <- utils::read.csv(source_profiles_path, stringsAsFactors = FALSE, check.names = FALSE)
  if (!nrow(profiles) || !"screening_profile_id" %in% names(profiles)) return(cell)
  id_col <- .qdesn_dynamic_fitforecast_metric_col(cell, c("screening_profile_base", "screening_profile_id_representative"))
  if (is.na(id_col)) return(cell)
  match_idx <- match(as.character(cell[[id_col]]), as.character(profiles$screening_profile_id))
  registry_cols <- intersect(
    c(
      "D", "n_each", "n_tilde_each", "m", "alpha", "rho", "pi_w", "pi_in",
      "washout", "add_bias", "seed", "readout_y_lags", "reservoir_lags",
      "rhs_tau0", "dimension_p_estimate", "p_over_n_tt500", "profile_role"
    ),
    names(profiles)
  )
  for (nm in registry_cols) {
    vals <- profiles[[nm]][match_idx]
    target_col <- if (nm %in% names(cell)) nm else nm
    if (!target_col %in% names(cell)) {
      cell[[target_col]] <- vals
    } else {
      current <- cell[[target_col]]
      missing <- is.na(current) | (is.character(current) & !nzchar(current))
      cell[[target_col]][missing] <- vals[missing]
    }
  }
  cell
}

qdesn_dynamic_fitforecast_hardcell_forecast_profile_plan <- function(cell_summary_path,
                                                                    source_profiles_path = NULL,
                                                                    screening_wave = paste0("hardcell_forecast_refinement_", format(Sys.Date(), "%Y_%m_%d")),
                                                                    hard_ratio_threshold = 1.0,
                                                                    max_p_over_n = 0.50,
                                                                    max_profiles = 36L,
                                                                    x_feature_count = 5L,
                                                                    seed = 123L) {
  cell_summary_path <- .qdesn_validation_resolve_path(cell_summary_path, must_work = TRUE)
  cell <- utils::read.csv(cell_summary_path, stringsAsFactors = FALSE, check.names = FALSE)
  if (!nrow(cell)) stop(sprintf("Dominance cell summary is empty: %s", cell_summary_path), call. = FALSE)
  if (!all(c("family", "tau") %in% names(cell))) {
    stop("Dominance cell summary must contain `family` and `tau`.", call. = FALSE)
  }
  id_col <- .qdesn_dynamic_fitforecast_metric_col(cell, c("screening_profile_base", "screening_profile_id_representative"))
  if (is.na(id_col)) stop("Dominance cell summary is missing a profile identifier column.", call. = FALSE)
  cell$screening_profile_base <- as.character(cell[[id_col]])
  cell$family <- as.character(cell$family)
  cell$tau <- as.numeric(cell$tau)
  cell <- .qdesn_dynamic_fitforecast_join_profile_registry(cell, source_profiles_path)
  parsed <- .qdesn_dynamic_fitforecast_parse_dominance_id(cell$screening_profile_base)
  for (nm in intersect(names(parsed), c("D", "n_each", "alpha", "rho", "m", "readout_y_lags", "reservoir_lags", "pi_w", "pi_in"))) {
    if (!nm %in% names(cell)) {
      cell[[nm]] <- parsed[[nm]]
    } else {
      current <- cell[[nm]]
      missing <- is.na(current) | (is.character(current) & !nzchar(current))
      cell[[nm]][missing] <- parsed[[nm]][missing]
    }
  }
  cell$primary_worst_ratio_vs_baseline <- .qdesn_dynamic_fitforecast_primary_worst_ratio(cell)
  cell <- cell[order(cell$family, cell$tau, cell$primary_worst_ratio_vs_baseline, cell$screening_profile_base), , drop = FALSE]

  key <- paste(cell$family, cell$tau, sep = "\r")
  best_by_cell <- .qdesn_validation_bind_rows(lapply(split(seq_len(nrow(cell)), key), function(idx) {
    sub <- cell[idx, , drop = FALSE]
    sub <- sub[order(sub$primary_worst_ratio_vs_baseline, sub$screening_profile_base), , drop = FALSE]
    best <- sub[1L, , drop = FALSE]
    data.frame(
      family = best$family[[1L]],
      tau = as.numeric(best$tau[[1L]]),
      cell_role = if (as.numeric(best$primary_worst_ratio_vs_baseline[[1L]]) > as.numeric(hard_ratio_threshold)[1L]) "hard" else "sentinel",
      best_profile = best$screening_profile_base[[1L]],
      best_primary_worst_ratio = as.numeric(best$primary_worst_ratio_vs_baseline[[1L]]),
      best_forecast_mae_ratio = as.numeric(best$forecast_mae_ratio_vs_best_vb_baseline %||% NA_real_)[1L],
      best_forecast_pinball_ratio = as.numeric(best$forecast_pinball_ratio_vs_best_vb_baseline %||% NA_real_)[1L],
      best_fit_rmse_ratio = as.numeric(best$fit_rmse_ratio_vs_best_vb_baseline %||% NA_real_)[1L],
      best_fit_pinball_ratio = as.numeric(best$fit_pinball_ratio_vs_best_vb_baseline %||% NA_real_)[1L],
      stringsAsFactors = FALSE
    )
  }))
  best_by_cell <- best_by_cell[order(best_by_cell$cell_role != "hard", -best_by_cell$best_primary_worst_ratio, best_by_cell$family, best_by_cell$tau), , drop = FALSE]
  best_by_cell$hardcell_priority <- seq_len(nrow(best_by_cell))

  make_row <- function(D,
                       n_each,
                       alpha,
                       rho,
                       pi_w,
                       pi_in,
                       reservoir_lags,
                       profile_role,
                       source_family = NA_character_,
                       source_tau = NA_real_,
                       source_profile = NA_character_,
                       source_ratio = NA_real_,
                       source_cell_role = "structure_probe",
                       source_priority = NA_integer_) {
    row <- qdesn_dynamic_fitforecast_profile_row(
      D = D,
      n_each = n_each,
      alpha = alpha,
      rho = rho,
      screening_stage = "vb_hardcell_forecast_refinement",
      screening_wave = screening_wave,
      profile_role = profile_role,
      rhs_tau0 = 1e-4,
      m = 90L,
      pi_w = pi_w,
      pi_in = pi_in,
      washout = 300L,
      add_bias = TRUE,
      seed = seed,
      readout_y_lags = 90L,
      reservoir_lags = reservoir_lags
    )
    row$x_feature_count <- as.integer(x_feature_count)[1L]
    row$dimension_p_estimate <- as.integer(row$dimension_p_estimate + row$x_feature_count)
    row$p_over_n_tt500 <- as.numeric(row$dimension_p_estimate / 500)
    row$screening_profile_id <- .qdesn_dynamic_fitforecast_dominance_profile_id(
      D = row$D,
      n_each = row$n_each,
      alpha = row$alpha,
      rho = row$rho,
      m = row$m,
      readout_y_lags = row$readout_y_lags,
      reservoir_lags = row$reservoir_lags,
      pi_w = row$pi_w,
      pi_in = row$pi_in,
      prefix = "tt500vb_hcell"
    )
    row$hardcell_source_family <- as.character(source_family)[1L]
    row$hardcell_source_tau <- as.numeric(source_tau)[1L]
    row$hardcell_source_profile <- as.character(source_profile)[1L]
    row$hardcell_source_worst_ratio <- as.numeric(source_ratio)[1L]
    row$hardcell_source_role <- as.character(source_cell_role)[1L]
    row$hardcell_source_priority <- as.integer(source_priority)[1L]
    row
  }

  anchors <- list()
  for (i in seq_len(nrow(best_by_cell))) {
    b <- best_by_cell[i, , drop = FALSE]
    seed_row <- cell[cell$family == b$family[[1L]] & cell$tau == b$tau[[1L]] &
                       cell$screening_profile_base == b$best_profile[[1L]], , drop = FALSE]
    if (!nrow(seed_row)) next
    s <- seed_row[1L, , drop = FALSE]
    anchors[[length(anchors) + 1L]] <- make_row(
      D = s$D,
      n_each = s$n_each,
      alpha = s$alpha,
      rho = s$rho,
      pi_w = s$pi_w %||% 0.05,
      pi_in = s$pi_in %||% 0.30,
      reservoir_lags = s$reservoir_lags %||% 0L,
      profile_role = paste0("hardcell_anchor_", b$cell_role[[1L]]),
      source_family = b$family,
      source_tau = b$tau,
      source_profile = b$best_profile,
      source_ratio = b$best_primary_worst_ratio,
      source_cell_role = b$cell_role,
      source_priority = b$hardcell_priority
    )
  }

  depth_width <- data.frame(
    D = c(1L, 1L, 1L, 2L, 2L, 2L),
    n_each = c(30L, 40L, 50L, 20L, 30L, 50L),
    stringsAsFactors = FALSE
  )
  dynamics <- data.frame(
    alpha = c(0.03, 0.05, 0.10, 0.20, 0.30, 0.40),
    rho = c(0.50, 0.60, 0.70, 0.80, 0.85, 0.90),
    dynamics_priority = c(1L, 1L, 1L, 2L, 2L, 2L),
    stringsAsFactors = FALSE
  )
  sparsity <- data.frame(
    profile_role = c("hardcell_sparse", "hardcell_hybrid", "hardcell_input_rich"),
    pi_w = c(0.05, 0.10, 0.20),
    pi_in = c(0.30, 0.80, 0.80),
    reservoir_lags = c(0L, 0L, 1L),
    sparsity_priority = c(1L, 2L, 3L),
    stringsAsFactors = FALSE
  )
  probes <- list()
  for (i in seq_len(nrow(depth_width))) {
    for (j in seq_len(nrow(dynamics))) {
      for (k in seq_len(nrow(sparsity))) {
        role <- sprintf("%s_p%d%d", sparsity$profile_role[[k]], dynamics$dynamics_priority[[j]], sparsity$sparsity_priority[[k]])
        row <- make_row(
          D = depth_width$D[[i]],
          n_each = depth_width$n_each[[i]],
          alpha = dynamics$alpha[[j]],
          rho = dynamics$rho[[j]],
          pi_w = sparsity$pi_w[[k]],
          pi_in = sparsity$pi_in[[k]],
          reservoir_lags = sparsity$reservoir_lags[[k]],
          profile_role = role,
          source_cell_role = "structure_probe",
          source_priority = 999L
        )
        row$hardcell_dynamics_priority <- dynamics$dynamics_priority[[j]]
        row$hardcell_sparsity_priority <- sparsity$sparsity_priority[[k]]
        probes[[length(probes) + 1L]] <- row
      }
    }
  }

  candidates <- .qdesn_validation_bind_rows(c(anchors, probes))
  if (!nrow(candidates)) stop("Hard-cell forecast refinement produced no candidate profiles.", call. = FALSE)
  candidates <- candidates[is.finite(as.numeric(candidates$p_over_n_tt500)) &
                             as.numeric(candidates$p_over_n_tt500) <= as.numeric(max_p_over_n), , drop = FALSE]
  if (!nrow(candidates)) stop("All hard-cell refinement profiles were removed by the p/n gate.", call. = FALSE)
  candidates$hardcell_source_priority[!is.finite(candidates$hardcell_source_priority)] <- 999L
  candidates$hardcell_source_worst_ratio[!is.finite(candidates$hardcell_source_worst_ratio)] <- NA_real_

  split_idx <- split(seq_len(nrow(candidates)), as.character(candidates$screening_profile_id))
  profiles <- .qdesn_validation_bind_rows(lapply(split_idx, function(idx) {
    sub <- candidates[idx, , drop = FALSE]
    sub <- sub[order(sub$hardcell_source_priority, sub$hardcell_source_role != "hard", sub$profile_role), , drop = FALSE]
    row <- sub[1L, , drop = FALSE]
    source_family <- as.character(sub$hardcell_source_family)
    source_tau <- as.numeric(sub$hardcell_source_tau)
    cell_ok <- !is.na(source_family) & nzchar(source_family) & is.finite(source_tau)
    row$hardcell_source_cells <- paste(unique(paste(source_family[cell_ok], source_tau[cell_ok], sep = ":")), collapse = ";")
    source_profiles <- as.character(sub$hardcell_source_profile)
    profile_ok <- !is.na(source_profiles) & nzchar(source_profiles)
    row$hardcell_source_profiles <- paste(unique(source_profiles[profile_ok]), collapse = ";")
    row$hardcell_source_roles <- paste(unique(na.omit(as.character(sub$hardcell_source_role))), collapse = ";")
    finite_ratios <- as.numeric(sub$hardcell_source_worst_ratio)
    finite_ratios <- finite_ratios[is.finite(finite_ratios)]
    row$hardcell_source_best_worst_ratio <- if (length(finite_ratios)) min(finite_ratios) else NA_real_
    row$hardcell_source_max_worst_ratio <- if (length(finite_ratios)) max(finite_ratios) else NA_real_
    row
  }))
  profiles$hardcell_is_anchor <- grepl("^hardcell_anchor_", as.character(profiles$profile_role))
  profiles$hardcell_is_sparse <- as.numeric(profiles$pi_w) <= 0.05 & as.numeric(profiles$pi_in) <= 0.30 & as.integer(profiles$reservoir_lags) == 0L
  profiles$hardcell_sort_score <- ifelse(profiles$hardcell_is_anchor, 0, 10) +
    as.numeric(profiles$p_over_n_tt500) +
    ifelse(profiles$hardcell_is_sparse, 0, 1) +
    as.numeric(profiles$hardcell_source_priority) / 100
  profiles <- profiles[order(
    profiles$hardcell_sort_score,
    -as.numeric(profiles$hardcell_source_max_worst_ratio),
    profiles$D,
    profiles$n_each,
    profiles$screening_profile_id
  ), , drop = FALSE]
  max_profiles <- as.integer(max_profiles)[1L]
  if (is.finite(max_profiles) && max_profiles > 0L && nrow(profiles) > max_profiles) {
    profiles <- utils::head(profiles, max_profiles)
  }
  profiles$enabled <- TRUE
  profiles$hardcell_profile_rank <- seq_len(nrow(profiles))
  rownames(profiles) <- NULL

  list(
    cell_summary_path = cell_summary_path,
    source_profiles_path = source_profiles_path %||% NA_character_,
    cell_plan = best_by_cell,
    candidate_ledger = candidates,
    profiles = profiles,
    manifest = list(
      generated_at = as.character(Sys.time()),
      screening_wave = screening_wave,
      hard_ratio_threshold = as.numeric(hard_ratio_threshold)[1L],
      max_p_over_n = as.numeric(max_p_over_n)[1L],
      max_profiles = as.integer(max_profiles)[1L],
      n_cells = nrow(best_by_cell),
      n_hard_cells = sum(best_by_cell$cell_role == "hard"),
      n_sentinel_cells = sum(best_by_cell$cell_role != "hard"),
      n_candidate_rows = nrow(candidates),
      n_profiles = nrow(profiles),
      source_contract_note = "Profiles keep m=90/readout_y_lags=90 to match the existing frozen period90/m90/w300 source materialization."
    )
  )
}

qdesn_dynamic_fitforecast_hardcell_forecast_profiles <- function(cell_summary_path,
                                                                 source_profiles_path = NULL,
                                                                 screening_wave = paste0("hardcell_forecast_refinement_", format(Sys.Date(), "%Y_%m_%d")),
                                                                 hard_ratio_threshold = 1.0,
                                                                 max_p_over_n = 0.50,
                                                                 max_profiles = 36L,
                                                                 x_feature_count = 5L,
                                                                 seed = 123L) {
  qdesn_dynamic_fitforecast_hardcell_forecast_profile_plan(
    cell_summary_path = cell_summary_path,
    source_profiles_path = source_profiles_path,
    screening_wave = screening_wave,
    hard_ratio_threshold = hard_ratio_threshold,
    max_p_over_n = max_p_over_n,
    max_profiles = max_profiles,
    x_feature_count = x_feature_count,
    seed = seed
  )$profiles
}

.qdesn_dynamic_fitforecast_cell_status <- function(worst_ratio) {
  worst_ratio <- as.numeric(worst_ratio)
  out <- rep("unknown", length(worst_ratio))
  out[is.finite(worst_ratio) & worst_ratio < 1] <- "sentinel"
  out[is.finite(worst_ratio) & worst_ratio >= 1 & worst_ratio <= 1.15] <- "near_pass"
  out[is.finite(worst_ratio) & worst_ratio > 1.15 & worst_ratio <= 1.40] <- "hard"
  out[is.finite(worst_ratio) & worst_ratio > 1.40] <- "extreme_hard"
  out
}

.qdesn_dynamic_fitforecast_cell_target_n <- function(status) {
  status <- as.character(status)
  out <- rep(24L, length(status))
  out[status == "sentinel"] <- 4L
  out[status == "near_pass"] <- 24L
  out[status == "hard"] <- 28L
  out[status == "extreme_hard"] <- 32L
  out
}

.qdesn_dynamic_fitforecast_tau_key <- function(x) {
  sprintf("%.8f", as.numeric(x))
}

qdesn_dynamic_fitforecast_forecast_targeted_profile_plan <- function(cell_summary_path,
                                                                     source_profiles_path = NULL,
                                                                     screening_wave = paste0("forecast_targeted_", format(Sys.Date(), "%Y_%m_%d")),
                                                                     max_p_over_n = 0.50,
                                                                     x_feature_count = 5L,
                                                                     seed = 123L) {
  cell_summary_path <- .qdesn_validation_resolve_path(cell_summary_path, must_work = TRUE)
  cell <- utils::read.csv(cell_summary_path, stringsAsFactors = FALSE, check.names = FALSE)
  if (!nrow(cell)) stop(sprintf("Dominance cell summary is empty: %s", cell_summary_path), call. = FALSE)
  if (!all(c("family", "tau") %in% names(cell))) {
    stop("Dominance cell summary must contain `family` and `tau`.", call. = FALSE)
  }
  id_col <- .qdesn_dynamic_fitforecast_metric_col(cell, c("screening_profile_base", "screening_profile_id_representative"))
  if (is.na(id_col)) stop("Dominance cell summary is missing a profile identifier column.", call. = FALSE)
  cell$screening_profile_base <- as.character(cell[[id_col]])
  cell$family <- as.character(cell$family)
  cell$tau <- as.numeric(cell$tau)
  cell <- .qdesn_dynamic_fitforecast_join_profile_registry(cell, source_profiles_path)
  cell <- .qdesn_dynamic_fitforecast_fill_profile_metadata(cell)
  cell$primary_worst_ratio_vs_baseline <- .qdesn_dynamic_fitforecast_primary_worst_ratio(cell)
  cell <- cell[order(cell$family, cell$tau, cell$primary_worst_ratio_vs_baseline, cell$screening_profile_base), , drop = FALSE]

  key <- paste(cell$family, .qdesn_dynamic_fitforecast_tau_key(cell$tau), sep = "\r")
  best_by_cell <- .qdesn_validation_bind_rows(lapply(split(seq_len(nrow(cell)), key), function(idx) {
    sub <- cell[idx, , drop = FALSE]
    sub <- sub[order(sub$primary_worst_ratio_vs_baseline, sub$screening_profile_base), , drop = FALSE]
    best <- sub[1L, , drop = FALSE]
    worst <- as.numeric(best$primary_worst_ratio_vs_baseline[[1L]])
    status <- .qdesn_dynamic_fitforecast_cell_status(worst)
    data.frame(
      family = best$family[[1L]],
      tau = as.numeric(best$tau[[1L]]),
      cell_status = status,
      target_profiles = .qdesn_dynamic_fitforecast_cell_target_n(status),
      current_best_profile = best$screening_profile_base[[1L]],
      current_best_worst_ratio = worst,
      current_best_forecast_mae_ratio = as.numeric(best$forecast_mae_ratio_vs_best_vb_baseline %||% NA_real_)[1L],
      current_best_forecast_pinball_ratio = as.numeric(best$forecast_pinball_ratio_vs_best_vb_baseline %||% NA_real_)[1L],
      current_best_fit_rmse_ratio = as.numeric(best$fit_rmse_ratio_vs_best_vb_baseline %||% NA_real_)[1L],
      current_best_fit_pinball_ratio = as.numeric(best$fit_pinball_ratio_vs_best_vb_baseline %||% NA_real_)[1L],
      bottleneck_metric = names(which.max(c(
        forecast_mae = as.numeric(best$forecast_mae_ratio_vs_best_vb_baseline %||% NA_real_)[1L],
        forecast_pinball = as.numeric(best$forecast_pinball_ratio_vs_best_vb_baseline %||% NA_real_)[1L],
        fit_rmse = as.numeric(best$fit_rmse_ratio_vs_best_vb_baseline %||% NA_real_)[1L],
        fit_pinball = as.numeric(best$fit_pinball_ratio_vs_best_vb_baseline %||% NA_real_)[1L]
      )))[1L],
      stringsAsFactors = FALSE
    )
  }))
  status_order <- c(extreme_hard = 1L, hard = 2L, near_pass = 3L, sentinel = 4L, unknown = 5L)
  best_by_cell$priority <- unname(status_order[best_by_cell$cell_status])
  best_by_cell$priority[!is.finite(best_by_cell$priority)] <- 99L
  best_by_cell <- best_by_cell[order(best_by_cell$priority, -best_by_cell$current_best_worst_ratio, best_by_cell$family, best_by_cell$tau), , drop = FALSE]
  best_by_cell$priority_rank <- seq_len(nrow(best_by_cell))

  ar_by_cell <- function(family, tau, status, best_alpha, best_rho) {
    if (identical(family, "laplace") && tau >= 0.25) {
      base <- data.frame(alpha = c(0.20, 0.30, 0.40, 0.10), rho = c(0.80, 0.85, 0.90, 0.70))
    } else if (identical(family, "normal")) {
      base <- data.frame(alpha = c(0.03, 0.05, 0.10, 0.20), rho = c(0.50, 0.60, 0.70, 0.80))
    } else {
      base <- data.frame(alpha = c(0.03, 0.05, 0.10, 0.20), rho = c(0.50, 0.60, 0.70, 0.80))
    }
    anchor <- data.frame(alpha = as.numeric(best_alpha)[1L], rho = as.numeric(best_rho)[1L])
    out <- unique(rbind(anchor[is.finite(anchor$alpha) & is.finite(anchor$rho), , drop = FALSE], base))
    out$ar_priority <- seq_len(nrow(out))
    out
  }
  depth_by_cell <- function(family, tau, status, best_D, best_n) {
    base <- if (identical(family, "normal")) {
      data.frame(D = c(2L, 2L, 2L, 1L, 1L), n_each = c(30L, 40L, 50L, 30L, 50L))
    } else if (identical(family, "laplace")) {
      data.frame(D = c(1L, 2L, 1L, 2L, 1L), n_each = c(30L, 30L, 40L, 20L, 50L))
    } else {
      data.frame(D = c(1L, 2L, 2L, 1L, 1L), n_each = c(40L, 20L, 30L, 30L, 50L))
    }
    anchor <- data.frame(D = as.integer(best_D)[1L], n_each = as.integer(best_n)[1L])
    out <- unique(rbind(anchor[is.finite(anchor$D) & is.finite(anchor$n_each), , drop = FALSE], base))
    out <- out[is.finite(out$D) & is.finite(out$n_each) & out$D %in% c(1L, 2L) & out$n_each %in% c(20L, 30L, 40L, 50L), , drop = FALSE]
    out$depth_priority <- seq_len(nrow(out))
    out
  }
  sparsity_by_status <- function(status) {
    if (identical(status, "sentinel")) {
      out <- data.frame(profile_role = "forecast_targeted_sentinel_sparse", pi_w = 0.05, pi_in = 0.30, reservoir_lags = 0L)
    } else if (identical(status, "near_pass")) {
      out <- data.frame(
        profile_role = c("forecast_targeted_sparse", "forecast_targeted_light_hybrid"),
        pi_w = c(0.05, 0.10),
        pi_in = c(0.30, 0.50),
        reservoir_lags = c(0L, 0L)
      )
    } else {
      out <- data.frame(
        profile_role = c("forecast_targeted_sparse", "forecast_targeted_light_hybrid", "forecast_targeted_input_probe"),
        pi_w = c(0.05, 0.10, 0.10),
        pi_in = c(0.30, 0.50, 0.80),
        reservoir_lags = c(0L, 0L, 0L)
      )
      if (identical(status, "extreme_hard")) {
        out <- rbind(out, data.frame(
          profile_role = "forecast_targeted_reservoir_lag_probe",
          pi_w = 0.20, pi_in = 0.80, reservoir_lags = 1L
        ))
      }
    }
    out$sparsity_priority <- seq_len(nrow(out))
    out
  }
  readout_by_status <- function(status, best_m, best_lag) {
    vals <- if (identical(status, "sentinel")) c(as.integer(best_m)[1L], 60L, 90L) else c(30L, 60L, 90L)
    vals <- unique(vals[is.finite(vals) & vals > 0L & vals <= 90L])
    if (!length(vals)) vals <- c(30L, 60L, 90L)
    data.frame(m = vals, readout_y_lags = vals, readout_priority = seq_along(vals))
  }
  make_row <- function(D,
                       n_each,
                       alpha,
                       rho,
                       m,
                       readout_y_lags,
                       pi_w,
                       pi_in,
                       reservoir_lags,
                       profile_role,
                       source_family,
                       source_tau,
                       source_status,
                       source_profile,
                       source_worst_ratio,
                       ar_priority = NA_integer_,
                       depth_priority = NA_integer_,
                       readout_priority = NA_integer_,
                       sparsity_priority = NA_integer_) {
    row <- qdesn_dynamic_fitforecast_profile_row(
      D = D,
      n_each = n_each,
      alpha = alpha,
      rho = rho,
      screening_stage = "vb_forecast_targeted_screen",
      screening_wave = screening_wave,
      profile_role = profile_role,
      rhs_tau0 = 1e-4,
      m = m,
      pi_w = pi_w,
      pi_in = pi_in,
      washout = 300L,
      add_bias = TRUE,
      seed = seed,
      readout_y_lags = readout_y_lags,
      reservoir_lags = reservoir_lags
    )
    row$x_feature_count <- as.integer(x_feature_count)[1L]
    row$dimension_p_estimate <- as.integer(row$dimension_p_estimate + row$x_feature_count)
    row$p_over_n_tt500 <- as.numeric(row$dimension_p_estimate / 500)
    row$screening_profile_id <- .qdesn_dynamic_fitforecast_dominance_profile_id(
      D = row$D,
      n_each = row$n_each,
      alpha = row$alpha,
      rho = row$rho,
      m = row$m,
      readout_y_lags = row$readout_y_lags,
      reservoir_lags = row$reservoir_lags,
      pi_w = row$pi_w,
      pi_in = row$pi_in,
      prefix = "tt500vb_ftgt"
    )
    row$target_family <- as.character(source_family)[1L]
    row$target_tau <- as.numeric(source_tau)[1L]
    row$target_cell_status <- as.character(source_status)[1L]
    row$target_source_profile <- as.character(source_profile)[1L]
    row$target_source_worst_ratio <- as.numeric(source_worst_ratio)[1L]
    row$target_ar_priority <- as.integer(ar_priority)[1L]
    row$target_depth_priority <- as.integer(depth_priority)[1L]
    row$target_readout_priority <- as.integer(readout_priority)[1L]
    row$target_sparsity_priority <- as.integer(sparsity_priority)[1L]
    row
  }

  candidates <- list()
  assignments <- list()
  for (i in seq_len(nrow(best_by_cell))) {
    b <- best_by_cell[i, , drop = FALSE]
    seed_row <- cell[cell$family == b$family[[1L]] & cell$tau == b$tau[[1L]] &
                       cell$screening_profile_base == b$current_best_profile[[1L]], , drop = FALSE]
    if (!nrow(seed_row)) next
    s <- seed_row[1L, , drop = FALSE]
    ar <- ar_by_cell(b$family[[1L]], b$tau[[1L]], b$cell_status[[1L]], s$alpha, s$rho)
    depth <- depth_by_cell(b$family[[1L]], b$tau[[1L]], b$cell_status[[1L]], s$D, s$n_each)
    sparsity <- sparsity_by_status(b$cell_status[[1L]])
    readout <- readout_by_status(b$cell_status[[1L]], s$m %||% 90L, s$readout_y_lags %||% 90L)
    cell_rows <- list()
    cell_rows[[length(cell_rows) + 1L]] <- make_row(
      D = s$D, n_each = s$n_each, alpha = s$alpha, rho = s$rho,
      m = s$m %||% 90L, readout_y_lags = s$readout_y_lags %||% 90L,
      pi_w = s$pi_w %||% 0.05, pi_in = s$pi_in %||% 0.30,
      reservoir_lags = s$reservoir_lags %||% 0L,
      profile_role = paste0("forecast_targeted_anchor_", b$cell_status[[1L]]),
      source_family = b$family, source_tau = b$tau, source_status = b$cell_status,
      source_profile = b$current_best_profile, source_worst_ratio = b$current_best_worst_ratio,
      ar_priority = 0L, depth_priority = 0L, readout_priority = 0L, sparsity_priority = 0L
    )
    for (di in seq_len(nrow(depth))) {
      for (ai in seq_len(nrow(ar))) {
        for (ri in seq_len(nrow(readout))) {
          for (si in seq_len(nrow(sparsity))) {
            cell_rows[[length(cell_rows) + 1L]] <- make_row(
              D = depth$D[[di]],
              n_each = depth$n_each[[di]],
              alpha = ar$alpha[[ai]],
              rho = ar$rho[[ai]],
              m = readout$m[[ri]],
              readout_y_lags = readout$readout_y_lags[[ri]],
              pi_w = sparsity$pi_w[[si]],
              pi_in = sparsity$pi_in[[si]],
              reservoir_lags = sparsity$reservoir_lags[[si]],
              profile_role = sparsity$profile_role[[si]],
              source_family = b$family,
              source_tau = b$tau,
              source_status = b$cell_status,
              source_profile = b$current_best_profile,
              source_worst_ratio = b$current_best_worst_ratio,
              ar_priority = ar$ar_priority[[ai]],
              depth_priority = depth$depth_priority[[di]],
              readout_priority = readout$readout_priority[[ri]],
              sparsity_priority = sparsity$sparsity_priority[[si]]
            )
          }
        }
      }
    }
    cell_df <- .qdesn_validation_bind_rows(cell_rows)
    cell_df <- cell_df[is.finite(as.numeric(cell_df$p_over_n_tt500)) &
                         as.numeric(cell_df$p_over_n_tt500) <= as.numeric(max_p_over_n), , drop = FALSE]
    cell_df <- cell_df[!duplicated(as.character(cell_df$screening_profile_id)), , drop = FALSE]
    if (!nrow(cell_df)) stop(sprintf("Forecast-targeted plan produced no candidates for %s tau %.2f.", b$family, b$tau), call. = FALSE)
    cell_df$target_sort_score <- ifelse(grepl("^forecast_targeted_anchor_", cell_df$profile_role), -100, 0) +
      as.numeric(cell_df$target_readout_priority %||% 99L) +
      0.1 * as.numeric(cell_df$target_sparsity_priority %||% 99L) +
      0.01 * as.numeric(cell_df$target_ar_priority %||% 99L) +
      0.001 * as.numeric(cell_df$target_depth_priority %||% 99L) +
      as.numeric(cell_df$p_over_n_tt500)
    cell_df <- cell_df[order(cell_df$target_sort_score, cell_df$screening_profile_id), , drop = FALSE]
    keep_n <- as.integer(b$target_profiles[[1L]])
    cell_df <- utils::head(cell_df, keep_n)
    cell_df$target_cell_profile_rank <- seq_len(nrow(cell_df))
    candidates[[length(candidates) + 1L]] <- cell_df
    assignments[[length(assignments) + 1L]] <- data.frame(
      family = as.character(b$family[[1L]]),
      tau = as.numeric(b$tau[[1L]]),
      cell_status = as.character(b$cell_status[[1L]]),
      priority_rank = as.integer(b$priority_rank[[1L]]),
      target_profile_rank = as.integer(cell_df$target_cell_profile_rank),
      screening_profile_id = as.character(cell_df$screening_profile_id),
      source_profile = as.character(b$current_best_profile[[1L]]),
      source_worst_ratio = as.numeric(b$current_best_worst_ratio[[1L]]),
      bottleneck_metric = as.character(b$bottleneck_metric[[1L]]),
      stringsAsFactors = FALSE
    )
  }
  candidate_ledger <- .qdesn_validation_bind_rows(candidates)
  assignment_ledger <- .qdesn_validation_bind_rows(assignments)
  if (!nrow(candidate_ledger) || !nrow(assignment_ledger)) {
    stop("Forecast-targeted planner produced no profiles or assignments.", call. = FALSE)
  }
  split_idx <- split(seq_len(nrow(candidate_ledger)), as.character(candidate_ledger$screening_profile_id))
  profiles <- .qdesn_validation_bind_rows(lapply(split_idx, function(idx) {
    sub <- candidate_ledger[idx, , drop = FALSE]
    sub <- sub[order(sub$target_sort_score, -as.numeric(sub$target_source_worst_ratio), sub$screening_profile_id), , drop = FALSE]
    row <- sub[1L, , drop = FALSE]
    row$target_cells <- paste(unique(paste(sub$target_family, sprintf("%.2f", as.numeric(sub$target_tau)), sep = ":")), collapse = ";")
    row$target_cell_statuses <- paste(unique(as.character(sub$target_cell_status)), collapse = ";")
    row$target_source_profiles <- paste(unique(as.character(sub$target_source_profile)), collapse = ";")
    finite_ratios <- as.numeric(sub$target_source_worst_ratio)
    finite_ratios <- finite_ratios[is.finite(finite_ratios)]
    row$target_source_best_worst_ratio <- if (length(finite_ratios)) min(finite_ratios) else NA_real_
    row$target_source_max_worst_ratio <- if (length(finite_ratios)) max(finite_ratios) else NA_real_
    row
  }))
  profiles <- profiles[order(profiles$target_sort_score, profiles$screening_profile_id), , drop = FALSE]
  profiles$enabled <- TRUE
  profiles$forecast_targeted_profile_rank <- seq_len(nrow(profiles))
  rownames(profiles) <- NULL
  assignment_ledger$assignment_key <- paste(
    assignment_ledger$screening_profile_id,
    assignment_ledger$family,
    .qdesn_dynamic_fitforecast_tau_key(assignment_ledger$tau),
    sep = "\r"
  )
  if (anyDuplicated(assignment_ledger$assignment_key)) {
    assignment_ledger <- assignment_ledger[!duplicated(assignment_ledger$assignment_key), , drop = FALSE]
  }
  assignment_ledger$assignment_id <- sprintf("ftgt_cell_%04d", seq_len(nrow(assignment_ledger)))
  list(
    cell_summary_path = cell_summary_path,
    source_profiles_path = source_profiles_path %||% NA_character_,
    cell_plan = best_by_cell,
    candidate_ledger = candidate_ledger,
    profiles = profiles,
    assignments = assignment_ledger,
    manifest = list(
      generated_at = as.character(Sys.time()),
      screening_wave = screening_wave,
      max_p_over_n = as.numeric(max_p_over_n)[1L],
      n_cells = nrow(best_by_cell),
      cell_status_counts = as.list(table(best_by_cell$cell_status)),
      n_candidate_rows = nrow(candidate_ledger),
      n_profiles = nrow(profiles),
      n_assignments = nrow(assignment_ledger),
      source_contract_note = "Forecast-targeted profiles use m/readout_y_lags <= 90 so they remain compatible with the existing period90/m90/w300 source materialization."
    )
  )
}

qdesn_dynamic_fitforecast_materialize_forecast_targeted_stage <- function(plan,
                                                                         base_defaults_path,
                                                                         profiles_out,
                                                                         assignments_out,
                                                                         defaults_out,
                                                                         grid_out,
                                                                         workers = 20L,
                                                                         refresh_grid = TRUE,
                                                                         refresh_materialized = FALSE) {
  if (!is.list(plan) || !is.data.frame(plan$profiles) || !nrow(plan$profiles) ||
      !is.data.frame(plan$assignments) || !nrow(plan$assignments)) {
    stop("plan must contain non-empty `profiles` and `assignments` data frames.", call. = FALSE)
  }
  base_defaults_path <- .qdesn_validation_resolve_path(base_defaults_path, must_work = TRUE)
  profiles_out <- .qdesn_validation_resolve_path(profiles_out, must_work = FALSE)
  assignments_out <- .qdesn_validation_resolve_path(assignments_out, must_work = FALSE)
  defaults_out <- .qdesn_validation_resolve_path(defaults_out, must_work = FALSE)
  grid_out <- .qdesn_validation_resolve_path(grid_out, must_work = FALSE)
  workers <- as.integer(workers)[1L]
  if (!is.finite(workers) || workers < 1L) workers <- 20L
  stage_stub <- "qdesn_dynamic_fitforecast_v2_tt500_vb_forecast_targeted"
  stage_desc <- "Q-DESN TT500 VB cell-specific forecast-targeted screen over selected family x tau assignments."

  .qdesn_validation_write_df(plan$profiles, profiles_out)
  .qdesn_validation_write_df(plan$assignments, assignments_out)
  selected_cell_keys <- unique(paste(plan$assignments$family, .qdesn_dynamic_fitforecast_tau_key(plan$assignments$tau), sep = "\r"))
  canonical_root_count <- nrow(plan$profiles) * length(selected_cell_keys)
  defaults <- yaml::read_yaml(base_defaults_path)
  defaults$campaign <- defaults$campaign %||% list()
  defaults$campaign$name <- stage_stub
  defaults$campaign$results_root <- file.path("results", "qdesn_mcmc_validation", stage_stub)
  defaults$campaign$reports_root <- file.path("reports", "qdesn_mcmc_validation", stage_stub)
  defaults$study_contract <- defaults$study_contract %||% list()
  defaults$study_contract$id <- paste0(stage_stub, "_", format(Sys.Date(), "%Y_%m_%d"))
  defaults$study_contract$description <- paste(stage_desc, "This lane is reproducible, storage-light, VB-only, and not article-facing until explicit freeze/signoff.")
  defaults$screening_profiles <- defaults$screening_profiles %||% list()
  defaults$screening_profiles$enabled <- TRUE
  defaults$screening_profiles$csv <- sub(paste0("^", .qdesn_validation_repo_root(), "/?"), "", profiles_out)
  defaults$screening_profiles$cell_assignments_csv <- sub(paste0("^", .qdesn_validation_repo_root(), "/?"), "", assignments_out)
  defaults$screening_profiles$priors <- "rhs_ns"
  defaults$screening_profiles$design <- sprintf("%s Profiles: %d; selected cell-profile assignments: %d.", stage_desc, nrow(plan$profiles), nrow(plan$assignments))
  defaults$screening_profiles$execution_grid_policy <- "cell_specific_subset_grid"
  defaults$screening_profiles$canonical_profile_count <- nrow(plan$profiles)
  defaults$screening_profiles$canonical_dataset_cell_count <- length(selected_cell_keys)
  defaults$screening_profiles$canonical_qdesn_root_count <- canonical_root_count
  defaults$screening_profiles$selected_assignment_root_count <- nrow(plan$assignments)
  defaults$reference_contract <- defaults$reference_contract %||% list()
  defaults$reference_contract$expected_unique_dataset_cells <- length(selected_cell_keys)
  defaults$reference_contract$expected_qdesn_roots <- canonical_root_count
  defaults$reference_contract$expected_selected_qdesn_roots <- nrow(plan$assignments)
  defaults$runtime <- defaults$runtime %||% list()
  defaults$runtime$campaign_workers <- workers
  defaults$runtime$workers <- workers
  defaults$runtime$root_scheduler <- "load_balanced"
  defaults$smoke <- defaults$smoke %||% list()
  first_extreme <- plan$cell_plan[as.character(plan$cell_plan$cell_status) == "extreme_hard", , drop = FALSE]
  first_cell <- if (nrow(first_extreme)) first_extreme[1L, , drop = FALSE] else plan$cell_plan[1L, , drop = FALSE]
  defaults$smoke$family <- as.character(first_cell$family[[1L]])
  defaults$smoke$tau <- as.numeric(first_cell$tau[[1L]])
  defaults$smoke$fit_sizes <- 500L
  defaults$smoke$priors <- "rhs_ns"
  defaults$smoke$max_roots <- 1L
  .qdesn_validation_dir_create(dirname(defaults_out))
  yaml::write_yaml(defaults, defaults_out)

  canonical_grid <- data.frame(stringsAsFactors = FALSE)
  selected_grid <- data.frame(stringsAsFactors = FALSE)
  missing_assignments <- character(0)
  if (isTRUE(refresh_grid)) {
    loaded <- qdesn_dynamic_crossstudy_load_defaults(defaults_out)
    canonical_grid <- qdesn_dynamic_crossstudy_build_grid(
      defaults = loaded,
      refresh_materialized = isTRUE(refresh_materialized),
      verbose = FALSE
    )
    grid_key <- paste(
      as.character(canonical_grid$screening_profile_id),
      as.character(canonical_grid$source_family),
      .qdesn_dynamic_fitforecast_tau_key(canonical_grid$tau),
      sep = "\r"
    )
    assignment_key <- paste(
      as.character(plan$assignments$screening_profile_id),
      as.character(plan$assignments$family),
      .qdesn_dynamic_fitforecast_tau_key(plan$assignments$tau),
      sep = "\r"
    )
    selected_mask <- grid_key %in% assignment_key
    selected_grid <- canonical_grid[selected_mask, , drop = FALSE]
    selected_grid_key <- grid_key[selected_mask]
    missing_assignments <- setdiff(unique(assignment_key), unique(grid_key))
    if (length(missing_assignments)) {
      stop(sprintf("Forecast-targeted assignment(s) are absent from the canonical grid: %s", paste(missing_assignments, collapse = ", ")), call. = FALSE)
    }
    if (!nrow(selected_grid)) stop("Forecast-targeted subset grid is empty.", call. = FALSE)
    selected_order <- order(selected_grid$source_family, selected_grid$tau, selected_grid$screening_profile_id)
    selected_grid <- selected_grid[selected_order, , drop = FALSE]
    selected_grid_key <- selected_grid_key[selected_order]
    .qdesn_validation_write_df(selected_grid, grid_out)
    root_lookup <- data.frame(
      assignment_key = selected_grid_key,
      root_id = as.character(selected_grid$root_id),
      stringsAsFactors = FALSE
    )
    assignment_with_roots <- merge(plan$assignments, root_lookup, by = "assignment_key", all.x = TRUE, sort = FALSE)
    assignment_with_roots <- assignment_with_roots[order(assignment_with_roots$priority_rank, assignment_with_roots$target_profile_rank), , drop = FALSE]
    .qdesn_validation_write_df(assignment_with_roots, assignments_out)
  }
  list(
    stage = "forecast_targeted",
    stage_stub = stage_stub,
    profiles_path = profiles_out,
    assignments_path = assignments_out,
    defaults_path = defaults_out,
    grid_path = grid_out,
    n_profiles = nrow(plan$profiles),
    n_assignments = nrow(plan$assignments),
    n_canonical_grid_rows = nrow(canonical_grid),
    n_grid_rows = nrow(selected_grid),
    expected_qdesn_roots = if (nrow(selected_grid)) nrow(selected_grid) else nrow(plan$assignments),
    selected_families = sort(unique(as.character(plan$assignments$family))),
    selected_taus = sort(unique(as.numeric(plan$assignments$tau))),
    missing_assignments = as.list(missing_assignments)
  )
}

.qdesn_dynamic_fitforecast_read_csv_if_exists <- function(path) {
  path <- as.character(path %||% "")[1L]
  if (!nzchar(path) || !file.exists(path)) return(data.frame(stringsAsFactors = FALSE))
  utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
}

.qdesn_dynamic_fitforecast_status_file <- function(path) {
  path <- as.character(path %||% "")[1L]
  if (!nzchar(path) || !file.exists(path)) return("MISSING")
  value <- tryCatch(readLines(path, warn = FALSE), error = function(...) character(0))
  value <- trimws(value)
  value <- value[nzchar(value)]
  if (length(value)) value[[1L]] else "EMPTY"
}

.qdesn_dynamic_fitforecast_results_root_from_report <- function(report_root) {
  report_root <- .qdesn_validation_resolve_path(report_root, must_work = FALSE)
  for (nm in c("campaign_manifest.json", "campaign_completed.json", "campaign_summary_manifest.json")) {
    path <- file.path(report_root, "manifest", nm)
    obj <- .qdesn_validation_read_json_if_exists(path)
    if (!is.null(obj) && nzchar(as.character(obj$results_root %||% "")[1L])) {
      return(.qdesn_validation_resolve_path(obj$results_root, must_work = FALSE))
    }
  }
  NA_character_
}

qdesn_dynamic_fitforecast_audit_screen_campaign <- function(results_root = NULL,
                                                            report_root = NULL,
                                                            expected_roots = NULL,
                                                            expected_lead_rows = 30L,
                                                            expected_rolling_rows = 1000L,
                                                            expected_final_origin = 9990L,
                                                            expected_final_origin_rows = 10L,
                                                            require_rankings = FALSE,
                                                            strict = FALSE) {
  if (is.null(results_root) && !is.null(report_root)) {
    results_root <- .qdesn_dynamic_fitforecast_results_root_from_report(report_root)
  }
  if (is.null(results_root) || is.na(results_root) || !nzchar(as.character(results_root)[1L])) {
    stop("Supply results_root, or a report_root with a campaign manifest containing results_root.", call. = FALSE)
  }
  results_root <- .qdesn_validation_resolve_path(results_root, must_work = FALSE)
  report_root <- if (!is.null(report_root) && nzchar(as.character(report_root)[1L])) {
    .qdesn_validation_resolve_path(report_root, must_work = FALSE)
  } else {
    NA_character_
  }
  roots_dir <- file.path(results_root, "roots")
  root_dirs <- if (dir.exists(roots_dir)) sort(list.dirs(roots_dir, recursive = FALSE, full.names = TRUE)) else character(0)
  if (is.null(expected_roots) || !is.finite(as.numeric(expected_roots)[1L])) {
    expected_roots <- length(root_dirs)
  }
  expected_roots <- as.integer(expected_roots)[1L]

  audit_one <- function(root_dir) {
    method_dir <- file.path(root_dir, "fits", "vb_exal")
    root_status <- .qdesn_dynamic_fitforecast_status_file(file.path(root_dir, "manifest", "root_status.txt"))
    method_status <- .qdesn_dynamic_fitforecast_status_file(file.path(method_dir, "manifest", "status.txt"))
    lead_path <- file.path(method_dir, "tables", "forecast_lead_metrics.csv")
    rolling_path <- file.path(method_dir, "tables", "forecast_rolling_origin_paths.csv")
    retention_path <- file.path(method_dir, "manifest", "output_retention.json")
    retention <- .qdesn_validation_read_json_if_exists(retention_path) %||% list()

    lead_df <- .qdesn_dynamic_fitforecast_read_csv_if_exists(lead_path)
    rolling_df <- .qdesn_dynamic_fitforecast_read_csv_if_exists(rolling_path)
    forbidden <- list.files(root_dir, pattern = "[.](rds|rda|RData)$", recursive = TRUE, full.names = TRUE)
    root_success <- identical(root_status, "SUCCESS")

    lead_rows <- nrow(lead_df)
    lead_max <- if (lead_rows && "forecast_lead" %in% names(lead_df)) max(as.integer(lead_df$forecast_lead), na.rm = TRUE) else NA_integer_
    lead_origin_end <- if (lead_rows && "origin_end_source_index" %in% names(lead_df)) max(as.integer(lead_df$origin_end_source_index), na.rm = TRUE) else NA_integer_
    lead_pass <- file.exists(lead_path) &&
      identical(as.integer(lead_rows), as.integer(expected_lead_rows)) &&
      isTRUE(lead_max == as.integer(expected_lead_rows)) &&
      isTRUE(lead_origin_end == as.integer(expected_final_origin))

    rolling_rows <- nrow(rolling_df)
    rolling_origin_col <- if ("forecast_origin_source_index" %in% names(rolling_df)) as.integer(rolling_df$forecast_origin_source_index) else integer(0)
    rolling_lead_col <- if ("forecast_lead" %in% names(rolling_df)) as.integer(rolling_df$forecast_lead) else integer(0)
    final_idx <- which(rolling_origin_col == as.integer(expected_final_origin))
    final_leads <- if (length(final_idx)) rolling_lead_col[final_idx] else integer(0)
    rolling_pass <- file.exists(rolling_path) &&
      identical(as.integer(rolling_rows), as.integer(expected_rolling_rows)) &&
      length(final_idx) == as.integer(expected_final_origin_rows) &&
      length(final_leads) == as.integer(expected_final_origin_rows) &&
      identical(sort(unique(final_leads)), seq_len(as.integer(expected_final_origin_rows)))

    storage_pass <- if (root_success) {
      length(forbidden) == 0L &&
        !isTRUE(retention$forecast_objects_exists_after) &&
        isTRUE(retention$forecast_objects_pruned %||% FALSE)
    } else {
      NA
    }

    data.frame(
      root_id = basename(root_dir),
      root_dir = normalizePath(root_dir, winslash = "/", mustWork = FALSE),
      root_status = root_status,
      method_status = method_status,
      lead_metrics_exists = file.exists(lead_path),
      lead_metrics_rows = lead_rows,
      lead_metrics_max_lead = lead_max,
      lead_metrics_origin_end = lead_origin_end,
      lead_metrics_pass = isTRUE(lead_pass),
      rolling_paths_exists = file.exists(rolling_path),
      rolling_paths_rows = rolling_rows,
      rolling_origin_min = if (length(rolling_origin_col)) min(rolling_origin_col, na.rm = TRUE) else NA_integer_,
      rolling_origin_max = if (length(rolling_origin_col)) max(rolling_origin_col, na.rm = TRUE) else NA_integer_,
      rolling_unique_origins = length(unique(rolling_origin_col)),
      final_origin_rows = length(final_idx),
      final_origin_lead_min = if (length(final_leads)) min(final_leads, na.rm = TRUE) else NA_integer_,
      final_origin_lead_max = if (length(final_leads)) max(final_leads, na.rm = TRUE) else NA_integer_,
      rolling_paths_pass = isTRUE(rolling_pass),
      output_retention_exists = file.exists(retention_path),
      forecast_objects_pruned = isTRUE(retention$forecast_objects_pruned %||% FALSE),
      forecast_objects_exists_after = isTRUE(retention$forecast_objects_exists_after %||% FALSE),
      compact_error = as.character(retention$compact_error %||% NA_character_),
      forbidden_binary_count = length(forbidden),
      forbidden_binary_bytes = if (length(forbidden)) sum(file.info(forbidden)$size, na.rm = TRUE) else 0,
      storage_light_pass = if (is.na(storage_pass)) NA else isTRUE(storage_pass),
      stringsAsFactors = FALSE
    )
  }

  root_audit <- .qdesn_validation_bind_rows(lapply(root_dirs, audit_one))
  status_vec <- if (nrow(root_audit)) as.character(root_audit$root_status) else character(0)
  n_success <- sum(status_vec == "SUCCESS")
  n_running <- sum(status_vec == "RUNNING")
  n_fail <- sum(status_vec == "FAIL")
  n_terminal <- sum(status_vec %in% c("SUCCESS", "FAIL"))
  success_idx <- if (nrow(root_audit)) root_audit$root_status == "SUCCESS" else logical(0)
  rank_paths <- if (!is.na(report_root)) {
    c(
      generic = file.path(report_root, "tables", "qdesn_tt500_vb_screen_profile_ranking.csv"),
      dominance = file.path(report_root, "tables", "qdesn_tt500_vb_dominance_profile_ranking.csv")
    )
  } else {
    c(generic = NA_character_, dominance = NA_character_)
  }
  rank_exists <- vapply(rank_paths, function(path) !is.na(path) && file.exists(path), logical(1L))
  terminal_complete <- length(root_dirs) == expected_roots && n_terminal == expected_roots && n_running == 0L && n_fail == 0L
  success_contract <- if (any(success_idx)) {
    all(root_audit$lead_metrics_pass[success_idx]) &&
      all(root_audit$rolling_paths_pass[success_idx]) &&
      all(root_audit$storage_light_pass[success_idx] %in% TRUE)
  } else {
    FALSE
  }
  ranking_contract <- !isTRUE(require_rankings) || all(rank_exists)
  strict_ready <- isTRUE(terminal_complete) && isTRUE(success_contract) && isTRUE(ranking_contract)

  summary <- data.frame(
    generated_at = as.character(Sys.time()),
    results_root = normalizePath(results_root, winslash = "/", mustWork = FALSE),
    report_root = if (!is.na(report_root)) normalizePath(report_root, winslash = "/", mustWork = FALSE) else NA_character_,
    expected_roots = expected_roots,
    observed_roots = length(root_dirs),
    n_terminal = n_terminal,
    n_success = n_success,
    n_running = n_running,
    n_fail = n_fail,
    n_missing_status = sum(status_vec %in% c("MISSING", "EMPTY")),
    n_success_with_lead_metrics = if (any(success_idx)) sum(root_audit$lead_metrics_exists[success_idx]) else 0L,
    n_success_with_rolling_paths = if (any(success_idx)) sum(root_audit$rolling_paths_exists[success_idx]) else 0L,
    n_success_lead_pass = if (any(success_idx)) sum(root_audit$lead_metrics_pass[success_idx]) else 0L,
    n_success_rolling_pass = if (any(success_idx)) sum(root_audit$rolling_paths_pass[success_idx]) else 0L,
    n_success_storage_light_pass = if (any(success_idx)) sum(root_audit$storage_light_pass[success_idx] %in% TRUE) else 0L,
    forbidden_binary_count_total = if (nrow(root_audit)) sum(root_audit$forbidden_binary_count, na.rm = TRUE) else 0L,
    forbidden_binary_bytes_total = if (nrow(root_audit)) sum(root_audit$forbidden_binary_bytes, na.rm = TRUE) else 0,
    generic_ranking_exists = isTRUE(rank_exists[["generic"]]),
    dominance_ranking_exists = isTRUE(rank_exists[["dominance"]]),
    terminal_complete = isTRUE(terminal_complete),
    success_contract_pass = isTRUE(success_contract),
    ranking_contract_pass = isTRUE(ranking_contract),
    strict_ready = isTRUE(strict_ready),
    strict_requested = isTRUE(strict),
    stringsAsFactors = FALSE
  )
  summary$strict_failure_reason <- if (isTRUE(strict) && !isTRUE(strict_ready)) {
    paste(c(
      if (!isTRUE(terminal_complete)) "terminal_complete_failed" else NULL,
      if (!isTRUE(success_contract)) "success_artifact_contract_failed" else NULL,
      if (!isTRUE(ranking_contract)) "ranking_contract_failed" else NULL
    ), collapse = ";")
  } else {
    NA_character_
  }
  list(
    summary = summary,
    root_audit = root_audit,
    rank_paths = as.list(rank_paths),
    rank_exists = as.list(rank_exists)
  )
}

qdesn_dynamic_fitforecast_write_campaign_audit <- function(results_root = NULL,
                                                           report_root = NULL,
                                                           out_dir = NULL,
                                                           expected_roots = NULL,
                                                           expected_lead_rows = 30L,
                                                           expected_rolling_rows = 1000L,
                                                           expected_final_origin = 9990L,
                                                           expected_final_origin_rows = 10L,
                                                           require_rankings = FALSE,
                                                           strict = FALSE) {
  audit <- qdesn_dynamic_fitforecast_audit_screen_campaign(
    results_root = results_root,
    report_root = report_root,
    expected_roots = expected_roots,
    expected_lead_rows = expected_lead_rows,
    expected_rolling_rows = expected_rolling_rows,
    expected_final_origin = expected_final_origin,
    expected_final_origin_rows = expected_final_origin_rows,
    require_rankings = require_rankings,
    strict = strict
  )
  if (is.null(out_dir) || !nzchar(as.character(out_dir)[1L])) {
    root_for_out <- as.character(report_root %||% results_root)
    out_dir <- file.path(root_for_out, "audit")
  }
  out_dir <- .qdesn_validation_resolve_path(out_dir, must_work = FALSE)
  table_dir <- file.path(out_dir, "tables")
  summary_dir <- file.path(out_dir, "summary")
  manifest_dir <- file.path(out_dir, "manifest")
  .qdesn_validation_dir_create(table_dir)
  .qdesn_validation_dir_create(summary_dir)
  .qdesn_validation_dir_create(manifest_dir)
  paths <- list(
    summary = file.path(table_dir, "qdesn_tt500_vb_screen_audit_summary.csv"),
    root_audit = file.path(table_dir, "qdesn_tt500_vb_screen_root_audit.csv"),
    report = file.path(summary_dir, "qdesn_tt500_vb_screen_audit.md"),
    manifest = file.path(manifest_dir, "qdesn_tt500_vb_screen_audit_manifest.json")
  )
  .qdesn_validation_write_df(audit$summary, paths$summary)
  .qdesn_validation_write_df(audit$root_audit, paths$root_audit)
  display_cols <- intersect(
    c(
      "expected_roots", "observed_roots", "n_success", "n_running", "n_fail",
      "n_success_lead_pass", "n_success_rolling_pass", "n_success_storage_light_pass",
      "generic_ranking_exists", "dominance_ranking_exists", "strict_ready"
    ),
    names(audit$summary)
  )
  bad_idx <- if (nrow(audit$root_audit)) {
    as.character(audit$root_audit$root_status) == "FAIL" |
      (as.character(audit$root_audit$root_status) == "SUCCESS" &
         (!audit$root_audit$lead_metrics_pass |
           !audit$root_audit$rolling_paths_pass |
           !(audit$root_audit$storage_light_pass %in% TRUE)))
  } else {
    logical(0)
  }
  bad_roots <- audit$root_audit[bad_idx, , drop = FALSE]
  bad_cols <- intersect(
    c("root_id", "root_status", "lead_metrics_pass", "rolling_paths_pass",
      "storage_light_pass", "forbidden_binary_count", "compact_error"),
    names(bad_roots)
  )
  lines <- c(
    "# Q-DESN TT500 VB Screen Audit",
    "",
    sprintf("- generated_at: `%s`", as.character(Sys.time())),
    sprintf("- results_root: `%s`", audit$summary$results_root[[1L]]),
    sprintf("- report_root: `%s`", audit$summary$report_root[[1L]]),
    "",
    "## Summary",
    .qdesn_validation_df_to_markdown(audit$summary[, display_cols, drop = FALSE]),
    "",
    "## Non-Passing Terminal Roots",
    if (nrow(bad_roots)) {
      .qdesn_validation_df_to_markdown(utils::head(bad_roots[, bad_cols, drop = FALSE], 25L))
    } else {
      "None observed."
    },
    "",
    sprintf("- summary_csv: `%s`", paths$summary),
    sprintf("- root_audit_csv: `%s`", paths$root_audit)
  )
  .qdesn_validation_write_lines(paths$report, lines)
  manifest <- list(
    generated_at = as.character(Sys.time()),
    strict = isTRUE(strict),
    require_rankings = isTRUE(require_rankings),
    output_paths = paths,
    summary = as.list(audit$summary[1L, , drop = FALSE]),
    rank_paths = audit$rank_paths,
    rank_exists = audit$rank_exists
  )
  .qdesn_validation_write_json(paths$manifest, manifest)
  invisible(c(audit, list(output_paths = paths, manifest = manifest)))
}

qdesn_dynamic_fitforecast_prune_success_rhs_trace <- function(results_root,
                                                              dry_run = TRUE,
                                                              method_subdir = "fits/vb_exal") {
  results_root <- .qdesn_validation_resolve_path(results_root, must_work = TRUE)
  roots_dir <- file.path(results_root, "roots")
  root_dirs <- if (dir.exists(roots_dir)) sort(list.dirs(roots_dir, recursive = FALSE, full.names = TRUE)) else character(0)
  prune_one <- function(root_dir) {
    method_dir <- file.path(root_dir, method_subdir)
    root_status <- .qdesn_dynamic_fitforecast_status_file(file.path(root_dir, "manifest", "root_status.txt"))
    method_status <- .qdesn_dynamic_fitforecast_status_file(file.path(method_dir, "manifest", "status.txt"))
    rhs_path <- file.path(method_dir, "models", "rhs_trace.rds")
    rhs_summary <- file.path(method_dir, "models", "rhs_run_summary.csv")
    rhs_diag_summary <- file.path(method_dir, "models", "rhs_diag_summary.txt")
    rhs_summary_ready <- file.exists(rhs_summary) || file.exists(rhs_diag_summary)
    eligible <- identical(root_status, "SUCCESS") &&
      identical(method_status, "SUCCESS") &&
      file.exists(rhs_path) &&
      isTRUE(rhs_summary_ready)
    bytes_before <- if (file.exists(rhs_path)) file.info(rhs_path)$size[[1L]] else 0
    pruned <- FALSE
    error <- NA_character_
    if (isTRUE(eligible) && !isTRUE(dry_run)) {
      pruned <- tryCatch({
        unlink(rhs_path)
        !file.exists(rhs_path)
      }, error = function(e) {
        error <<- conditionMessage(e)
        FALSE
      })
    }
    data.frame(
      root_id = basename(root_dir),
      root_dir = normalizePath(root_dir, winslash = "/", mustWork = FALSE),
      root_status = root_status,
      method_status = method_status,
      rhs_trace_path = normalizePath(rhs_path, winslash = "/", mustWork = FALSE),
      rhs_trace_exists_before = file.exists(rhs_path) || bytes_before > 0,
      rhs_trace_summary_exists = file.exists(rhs_summary),
      rhs_trace_diag_summary_exists = file.exists(rhs_diag_summary),
      eligible = isTRUE(eligible),
      dry_run = isTRUE(dry_run),
      pruned = isTRUE(pruned),
      exists_after = file.exists(rhs_path),
      bytes_before = as.numeric(bytes_before),
      error = error,
      stringsAsFactors = FALSE
    )
  }
  rows <- .qdesn_validation_bind_rows(lapply(root_dirs, prune_one))
  summary <- data.frame(
    generated_at = as.character(Sys.time()),
    results_root = normalizePath(results_root, winslash = "/", mustWork = FALSE),
    roots = length(root_dirs),
    eligible = if (nrow(rows)) sum(rows$eligible, na.rm = TRUE) else 0L,
    pruned = if (nrow(rows)) sum(rows$pruned, na.rm = TRUE) else 0L,
    dry_run = isTRUE(dry_run),
    bytes_eligible = if (nrow(rows)) sum(rows$bytes_before[rows$eligible], na.rm = TRUE) else 0,
    stringsAsFactors = FALSE
  )
  list(summary = summary, root_cleanup = rows)
}

qdesn_dynamic_fitforecast_profiles_from_ranking <- function(ranking_path,
                                                            source_profiles_path,
                                                            top_n = 12L,
                                                            screening_stage = "dominance_refinement",
                                                            screening_wave = "dominance_refinement_2026_06_26",
                                                            profile_role = "refinement_top",
                                                            seed = NULL,
                                                            require_dominance_pass = FALSE) {
  ranking_path <- .qdesn_validation_resolve_path(ranking_path, must_work = TRUE)
  source_profiles_path <- .qdesn_validation_resolve_path(source_profiles_path, must_work = TRUE)
  ranking <- utils::read.csv(ranking_path, stringsAsFactors = FALSE, check.names = FALSE)
  profiles <- utils::read.csv(source_profiles_path, stringsAsFactors = FALSE, check.names = FALSE)
  if (!nrow(ranking)) stop(sprintf("Ranking file is empty: %s", ranking_path), call. = FALSE)
  if (!nrow(profiles)) stop(sprintf("Profile registry is empty: %s", source_profiles_path), call. = FALSE)
  if (!"screening_profile_id" %in% names(profiles)) {
    stop("Source profile registry is missing `screening_profile_id`.", call. = FALSE)
  }
  rank_id_col <- .qdesn_dynamic_fitforecast_metric_col(ranking, c("screening_profile_base", "screening_profile_id", "screening_profile_id_representative"))
  if (is.na(rank_id_col)) {
    stop("Ranking is missing a profile identifier column.", call. = FALSE)
  }
  if (isTRUE(require_dominance_pass) && "dominance_pass" %in% names(ranking)) {
    ranking <- ranking[as.logical(ranking$dominance_pass), , drop = FALSE]
    if (!nrow(ranking)) {
      stop("No ranked profiles satisfy `dominance_pass`; refusing to materialize an empty follow-up stage.", call. = FALSE)
    }
  }
  rank_col <- .qdesn_dynamic_fitforecast_metric_col(ranking, c("dominance_rank", "profile_rank"))
  if (!is.na(rank_col)) ranking <- ranking[order(as.integer(ranking[[rank_col]])), , drop = FALSE]
  ids <- unique(as.character(ranking[[rank_id_col]]))
  ids <- ids[nzchar(ids)]
  ids <- utils::head(ids, as.integer(top_n)[1L])
  out <- profiles[match(ids, as.character(profiles$screening_profile_id)), , drop = FALSE]
  missing <- ids[is.na(match(ids, as.character(profiles$screening_profile_id)))]
  if (length(missing)) {
    stop(sprintf("Ranked profile(s) are absent from source profile registry: %s", paste(missing, collapse = ", ")), call. = FALSE)
  }
  out$enabled <- TRUE
  out$screening_stage <- as.character(screening_stage)[1L]
  out$screening_wave <- as.character(screening_wave)[1L]
  out$profile_role <- as.character(profile_role)[1L]
  if (!is.null(seed)) {
    seed <- as.integer(seed)[1L]
    if (!is.finite(seed)) stop("seed must be finite when supplied.", call. = FALSE)
    out$seed <- seed
  }
  rownames(out) <- NULL
  out
}

qdesn_dynamic_fitforecast_materialize_followup_stage <- function(stage = c("refinement", "hardcell_forecast_refinement", "seed_stability", "replacement"),
                                                                 profiles,
                                                                 base_defaults_path,
                                                                 profiles_out,
                                                                 defaults_out,
                                                                 grid_out,
                                                                 workers = 20L,
                                                                 refresh_grid = TRUE,
                                                                 refresh_materialized = FALSE) {
  stage <- match.arg(stage)
  base_defaults_path <- .qdesn_validation_resolve_path(base_defaults_path, must_work = TRUE)
  profiles_out <- .qdesn_validation_resolve_path(profiles_out, must_work = FALSE)
  defaults_out <- .qdesn_validation_resolve_path(defaults_out, must_work = FALSE)
  grid_out <- .qdesn_validation_resolve_path(grid_out, must_work = FALSE)
  if (!is.data.frame(profiles) || !nrow(profiles)) stop("profiles must be a non-empty data frame.", call. = FALSE)
  workers <- as.integer(workers)[1L]
  if (!is.finite(workers) || workers < 1L) workers <- 20L
  stage_stub <- switch(
    stage,
    refinement = "qdesn_dynamic_fitforecast_v2_tt500_vb_dominance_refinement",
    hardcell_forecast_refinement = "qdesn_dynamic_fitforecast_v2_tt500_vb_hardcell_forecast_refinement",
    seed_stability = "qdesn_dynamic_fitforecast_v2_tt500_vb_dominance_seed_stability",
    replacement = "qdesn_dynamic_fitforecast_v2_tt500_vb_replacement_frozen"
  )
  stage_desc <- switch(
    stage,
    refinement = "Post-broad Q-DESN TT500 VB refinement over top dominance-screen profiles.",
    hardcell_forecast_refinement = "Q-DESN TT500 VB hard-cell forecast refinement using the completed targeted dominance screen.",
    seed_stability = "Q-DESN TT500 VB alternate-reservoir-seed stability check for dominance finalists.",
    replacement = "Frozen Q-DESN TT500 VB replacement candidate using the selected profile registry."
  )
  .qdesn_validation_write_df(profiles, profiles_out)
  defaults <- yaml::read_yaml(base_defaults_path)
  defaults$campaign <- defaults$campaign %||% list()
  defaults$campaign$name <- stage_stub
  defaults$campaign$results_root <- file.path("results", "qdesn_mcmc_validation", stage_stub)
  defaults$campaign$reports_root <- file.path("reports", "qdesn_mcmc_validation", stage_stub)
  defaults$study_contract <- defaults$study_contract %||% list()
  defaults$study_contract$id <- paste0(stage_stub, "_", format(Sys.Date(), "%Y_%m_%d"))
  defaults$study_contract$description <- paste(stage_desc, "This lane is reproducible and storage-light; article promotion requires clean-commit rerun and audit signoff.")
  defaults$screening_profiles <- defaults$screening_profiles %||% list()
  defaults$screening_profiles$enabled <- TRUE
  defaults$screening_profiles$csv <- sub(paste0("^", .qdesn_validation_repo_root(), "/?"), "", profiles_out)
  defaults$screening_profiles$priors <- "rhs_ns"
  defaults$screening_profiles$design <- sprintf("%s Profiles: %d.", stage_desc, nrow(profiles))
  defaults$reference_contract <- defaults$reference_contract %||% list()
  families <- as.character(defaults$reference_contract$families %||% c("gausmix", "laplace", "normal"))
  taus <- as.numeric(defaults$reference_contract$taus %||% c(0.05, 0.25, 0.50))
  defaults$reference_contract$taus <- taus
  defaults$source_materialization <- defaults$source_materialization %||% list()
  defaults$source_materialization$taus <- taus
  defaults$reference_contract$expected_unique_dataset_cells <- length(families) * length(taus)
  defaults$reference_contract$expected_qdesn_roots <- as.integer(nrow(profiles) * length(families) * length(taus))
  defaults$runtime <- defaults$runtime %||% list()
  defaults$runtime$campaign_workers <- workers
  defaults$runtime$workers <- workers
  defaults$runtime$root_scheduler <- "load_balanced"
  defaults$smoke <- defaults$smoke %||% list()
  defaults$smoke$max_roots <- as.integer(defaults$smoke$max_roots %||% 1L)[1L]
  if (!is.finite(defaults$smoke$max_roots) || defaults$smoke$max_roots < 1L) {
    defaults$smoke$max_roots <- 1L
  }
  .qdesn_validation_dir_create(dirname(defaults_out))
  yaml::write_yaml(defaults, defaults_out)

  grid <- data.frame(stringsAsFactors = FALSE)
  if (isTRUE(refresh_grid)) {
    loaded <- qdesn_dynamic_crossstudy_load_defaults(defaults_out)
    grid <- qdesn_dynamic_crossstudy_build_grid(
      defaults = loaded,
      refresh_materialized = isTRUE(refresh_materialized),
      verbose = FALSE
    )
    .qdesn_validation_write_df(grid, grid_out)
  }
  list(
    stage = stage,
    stage_stub = stage_stub,
    profiles_path = profiles_out,
    defaults_path = defaults_out,
    grid_path = grid_out,
    n_profiles = nrow(profiles),
    n_grid_rows = nrow(grid),
    expected_qdesn_roots = as.integer(defaults$reference_contract$expected_qdesn_roots)
  )
}

qdesn_dynamic_fitforecast_freeze_profile <- function(ranking_path,
                                                     source_profiles_path,
                                                     out_profile_path,
                                                     out_manifest_path,
                                                     allow_best_available = TRUE,
                                                     max_p_over_n = 0.50) {
  ranking_path <- .qdesn_validation_resolve_path(ranking_path, must_work = TRUE)
  source_profiles_path <- .qdesn_validation_resolve_path(source_profiles_path, must_work = TRUE)
  out_profile_path <- .qdesn_validation_resolve_path(out_profile_path, must_work = FALSE)
  out_manifest_path <- .qdesn_validation_resolve_path(out_manifest_path, must_work = FALSE)
  ranking <- utils::read.csv(ranking_path, stringsAsFactors = FALSE, check.names = FALSE)
  if (!nrow(ranking)) stop(sprintf("Ranking is empty: %s", ranking_path), call. = FALSE)
  rank_col <- .qdesn_dynamic_fitforecast_metric_col(ranking, c("dominance_rank", "profile_rank"))
  if (!is.na(rank_col)) ranking <- ranking[order(as.integer(ranking[[rank_col]])), , drop = FALSE]
  if ("qdesn_p_over_n_mean_mean" %in% names(ranking)) {
    ranking <- ranking[!is.finite(as.numeric(ranking$qdesn_p_over_n_mean_mean)) |
                         as.numeric(ranking$qdesn_p_over_n_mean_mean) <= as.numeric(max_p_over_n), , drop = FALSE]
  }
  pass_rows <- if ("dominance_pass" %in% names(ranking)) ranking[as.logical(ranking$dominance_pass), , drop = FALSE] else ranking[0L, , drop = FALSE]
  selected <- if (nrow(pass_rows)) {
    pass_rows[1L, , drop = FALSE]
  } else if (isTRUE(allow_best_available) && nrow(ranking)) {
    ranking[1L, , drop = FALSE]
  } else {
    data.frame(stringsAsFactors = FALSE)
  }
  if (!nrow(selected)) stop("No profile satisfies the freeze criteria.", call. = FALSE)
  selected_id_col <- .qdesn_dynamic_fitforecast_metric_col(selected, c("screening_profile_base", "screening_profile_id"))
  if (is.na(selected_id_col)) stop("Selected ranking row is missing a profile identifier.", call. = FALSE)
  selected_id <- as.character(selected[[selected_id_col]][[1L]])
  profiles <- utils::read.csv(source_profiles_path, stringsAsFactors = FALSE, check.names = FALSE)
  frozen <- profiles[as.character(profiles$screening_profile_id) == selected_id, , drop = FALSE]
  if (!nrow(frozen)) stop(sprintf("Selected profile is missing from source registry: %s", selected_id), call. = FALSE)
  frozen$enabled <- TRUE
  frozen$screening_stage <- "tt500_vb_replacement_frozen"
  frozen$screening_wave <- paste0("frozen_", format(Sys.Date(), "%Y_%m_%d"))
  frozen$profile_role <- "frozen_global"
  .qdesn_validation_write_df(frozen, out_profile_path)
  manifest <- list(
    generated_at = as.character(Sys.time()),
    selected_profile_id = selected_id,
    selected_from_ranking = ranking_path,
    source_profiles_path = source_profiles_path,
    out_profile_path = out_profile_path,
    allow_best_available = isTRUE(allow_best_available),
    dominance_pass = if ("dominance_pass" %in% names(selected)) isTRUE(selected$dominance_pass[[1L]]) else NA,
    selected_ranking_row = as.list(selected[1L, , drop = FALSE])
  )
  .qdesn_validation_write_json(out_manifest_path, manifest)
  invisible(list(profile = frozen, manifest = manifest))
}

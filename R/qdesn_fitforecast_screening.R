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
    m <- regexec("^tt500vb_d([0-9]+)_n([0-9]+)_a([0-9]+p?[0-9]*)_r([0-9]+p?[0-9]*)$", x)
    hit <- regmatches(x, m)[[1L]]
    if (length(hit) != 5L) {
      return(data.frame(D = NA_integer_, n_each = NA_integer_, alpha = NA_real_, rho = NA_real_))
    }
    data.frame(
      D = as.integer(hit[[2L]]),
      n_each = as.integer(hit[[3L]]),
      alpha = as.numeric(gsub("p", ".", hit[[4L]], fixed = TRUE)),
      rho = as.numeric(gsub("p", ".", hit[[5L]], fixed = TRUE)),
      stringsAsFactors = FALSE
    )
  })
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
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
  parsed_profiles <- qdesn_dynamic_fitforecast_parse_profile_base(fit_enriched$screening_profile_base)
  for (nm in c("D", "n_each", "alpha", "rho")) {
    if (!nm %in% names(fit_enriched) || all(is.na(fit_enriched[[nm]]))) {
      fit_enriched[[nm]] <- parsed_profiles[[nm]]
    }
  }

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

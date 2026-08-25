.qdesn_validation_dispersion_row_quantiles <- function(x) {
  x <- as.matrix(x)
  probs <- c(0.025, 0.5, 0.975)
  if (requireNamespace("matrixStats", quietly = TRUE)) {
    out <- matrixStats::rowQuantiles(x, probs = probs, na.rm = TRUE, type = 8)
  } else {
    out <- t(apply(x, 1L, stats::quantile, probs = probs, names = FALSE,
                   na.rm = TRUE, type = 8))
  }
  colnames(out) <- c("q025", "q500", "q975")
  out
}

.qdesn_validation_dispersion_summary_row <- function(x, metric, mode,
                                                      group_type = "all",
                                                      group_value = "all",
                                                      metric_at_mean_path = NA_real_) {
  x <- as.numeric(x)
  qs <- stats::quantile(x, c(0.025, 0.5, 0.975), names = FALSE,
                        na.rm = TRUE, type = 8)
  data.frame(
    group_type = group_type,
    group_value = as.character(group_value),
    recursion_mode = mode,
    metric = metric,
    posterior_mean = mean(x),
    posterior_sd = stats::sd(x),
    cri_lower = qs[[1L]],
    posterior_median = qs[[2L]],
    cri_upper = qs[[3L]],
    cri_width = qs[[3L]] - qs[[1L]],
    metric_at_posterior_mean_path = as.numeric(metric_at_mean_path),
    jensen_gap = mean(x) - as.numeric(metric_at_mean_path),
    n_draws = length(x),
    stringsAsFactors = FALSE
  )
}

.qdesn_validation_dispersion_skewness <- function(x) {
  x <- as.numeric(x)
  s <- stats::sd(x)
  if (!is.finite(s) || s <= 0) return(NA_real_)
  mean((x - mean(x))^3) / s^3
}

.qdesn_validation_dispersion_metric_vectors <- function(q, q_true, y, tau) {
  q <- as.matrix(q)
  list(
    forecast_mae = colMeans(abs(sweep(q, 1L, q_true, "-"))),
    forecast_check_loss = colMeans(
      .qdesn_validation_metric_check_loss(
        matrix(y, nrow = length(y), ncol = ncol(q)), q, tau
      )
    )
  )
}

.qdesn_validation_dispersion_group_rows <- function(q, q_true, y, tau, groups,
                                                     group_type, mode) {
  q <- as.matrix(q)
  levels <- unique(groups)
  rows <- vector("list", length(levels) * 2L)
  k <- 0L
  for (value in levels) {
    idx <- which(groups == value)
    vectors <- .qdesn_validation_dispersion_metric_vectors(
      q[idx, , drop = FALSE], q_true[idx], y[idx], tau
    )
    mean_path <- rowMeans(q[idx, , drop = FALSE])
    point <- c(
      forecast_mae = mean(abs(mean_path - q_true[idx])),
      forecast_check_loss = mean(
        .qdesn_validation_metric_check_loss(y[idx], mean_path, tau)
      )
    )
    for (metric in names(vectors)) {
      k <- k + 1L
      rows[[k]] <- .qdesn_validation_dispersion_summary_row(
        vectors[[metric]], metric = metric, mode = mode,
        group_type = group_type, group_value = value,
        metric_at_mean_path = point[[metric]]
      )
      rows[[k]]$n_targets <- length(idx)
    }
  }
  do.call(rbind, rows[seq_len(k)])
}

.qdesn_validation_dispersion_mean_pairwise_correlation <- function(x) {
  x <- as.matrix(x)
  centered <- sweep(x, 1L, rowMeans(x), "-")
  sds <- if (requireNamespace("matrixStats", quietly = TRUE)) {
    matrixStats::rowSds(x)
  } else apply(x, 1L, stats::sd)
  keep <- is.finite(sds) & sds > 0
  if (sum(keep) < 2L) return(NA_real_)
  z <- sweep(centered[keep, , drop = FALSE], 1L, sds[keep], "/")
  n <- nrow(z)
  (stats::var(colSums(z)) - n) / (n * (n - 1))
}

.qdesn_validation_dispersion_covariance_decomposition <- function(error,
                                                                  origin_id) {
  error <- as.matrix(error)
  origins <- unique(origin_id)
  origin_metric <- do.call(rbind, lapply(origins, function(origin) {
    colMeans(error[origin_id == origin, , drop = FALSE])
  }))
  weights <- vapply(origins, function(origin) mean(origin_id == origin), numeric(1L))
  aggregate <- as.numeric(crossprod(weights, origin_metric))
  total_var <- stats::var(aggregate)
  independent_var <- sum(weights^2 * apply(origin_metric, 1L, stats::var))
  covariance_var <- total_var - independent_var
  list(
    total_variance = total_var,
    independent_origin_variance = independent_var,
    cross_origin_covariance_variance = covariance_var,
    cross_origin_covariance_fraction = if (is.finite(total_var) && total_var > 0) {
      covariance_var / total_var
    } else NA_real_,
    n_origins = length(origins)
  )
}

.qdesn_validation_dispersion_add_rhs_parameters <- function(parameters, fit,
                                                             source_index) {
  parameters <- as.data.frame(parameters, stringsAsFactors = FALSE)
  if (!nrow(parameters)) {
    parameters <- data.frame(
      source_draw_index = as.integer(source_index),
      stringsAsFactors = FALSE
    )
  }
  source_index <- as.integer(source_index)
  candidates <- c(
    tau = "samp.tau",
    c2 = "samp.c2",
    lambda_mean = "samp.lambda_mean",
    lambda_min = "samp.lambda_min",
    lambda_max = "samp.lambda_max"
  )
  if (!is.null(fit)) {
    for (name in names(candidates)) {
      values <- as.numeric(fit[[candidates[[name]]]] %||% numeric(0))
      if (length(values) >= max(source_index) && all(source_index >= 1L)) {
        parameters[[name]] <- values[source_index]
      }
    }
  }
  parameters
}

.qdesn_validation_metric_dispersion_artifacts <- function(draws,
                                                           coupling_draws = NULL) {
  context <- attr(draws, "metric_dispersion_context")
  if (is.null(context)) {
    stop("Metric-dispersion context is absent.", call. = FALSE)
  }
  native_q <- as.matrix(context$native_q)
  plugin_q <- as.matrix(context$plugin_q)
  q_true <- as.numeric(context$q_true)
  y <- as.numeric(context$y)
  grid <- as.data.frame(context$grid, stringsAsFactors = FALSE)
  tau <- as.numeric(context$tau)[1L]
  if (nrow(native_q) != length(q_true) || ncol(native_q) != nrow(draws) ||
      any(!is.finite(native_q))) {
    stop("Native dispersion paths are incomplete or misaligned.", call. = FALSE)
  }
  if (!nrow(plugin_q) || !identical(dim(plugin_q), dim(native_q)) ||
      any(!is.finite(plugin_q))) {
    stop("Plug-in dispersion paths are incomplete or misaligned.", call. = FALSE)
  }

  native <- .qdesn_validation_dispersion_metric_vectors(native_q, q_true, y, tau)
  plugin <- .qdesn_validation_dispersion_metric_vectors(plugin_q, q_true, y, tau)
  if (max(abs(native$forecast_mae - draws$forecast_mae)) > 1e-10 ||
      max(abs(native$forecast_check_loss - draws$forecast_check_loss)) > 1e-10) {
    stop("Dispersion replay does not reproduce the primary metric draws.", call. = FALSE)
  }

  native_centered <- sweep(native_q, 1L, rowMeans(native_q), "-")
  plugin_centered <- sweep(plugin_q, 1L, rowMeans(plugin_q), "-")
  recursion_delta <- native_q - plugin_q
  draw_diag <- data.frame(
    chain_id = as.integer(draws$chain_id),
    draw_id = as.integer(draws$draw_id),
    metric_draw_index = as.integer(draws$source_draw_index),
    posterior_source_draw_index = as.integer(context$posterior_source_draw_index),
    forecast_mae_native = native$forecast_mae,
    forecast_mae_plugin = plugin$forecast_mae,
    forecast_mae_plugin_minus_native = plugin$forecast_mae - native$forecast_mae,
    forecast_check_native = native$forecast_check_loss,
    forecast_check_plugin = plugin$forecast_check_loss,
    common_shift_native = colMeans(native_centered),
    common_shift_plugin = colMeans(plugin_centered),
    oracle_bias_native = colMeans(sweep(native_q, 1L, q_true, "-")),
    oracle_bias_plugin = colMeans(sweep(plugin_q, 1L, q_true, "-")),
    recursion_delta_rmse = sqrt(colMeans(recursion_delta^2)),
    stringsAsFactors = FALSE
  )
  parameters <- .qdesn_validation_dispersion_add_rhs_parameters(
    context$draw_parameters, context$fit, context$posterior_source_draw_index
  )
  parameter_fields <- setdiff(names(parameters), "source_draw_index")
  for (field in parameter_fields) draw_diag[[field]] <- parameters[[field]]

  native_qs <- .qdesn_validation_dispersion_row_quantiles(native_q)
  plugin_qs <- .qdesn_validation_dispersion_row_quantiles(plugin_q)
  native_sd <- if (requireNamespace("matrixStats", quietly = TRUE)) {
    matrixStats::rowSds(native_q)
  } else apply(native_q, 1L, stats::sd)
  plugin_sd <- if (requireNamespace("matrixStats", quietly = TRUE)) {
    matrixStats::rowSds(plugin_q)
  } else apply(plugin_q, 1L, stats::sd)
  target <- data.frame(
    grid[c("origin_sequence_id", "forecast_origin_source_index", "forecast_lead",
           "target_source_index")],
    q_true = q_true,
    y = y,
    native_mean = rowMeans(native_q),
    native_sd = native_sd,
    native_q025 = native_qs[, "q025"],
    native_median = native_qs[, "q500"],
    native_q975 = native_qs[, "q975"],
    native_oracle_covered = q_true >= native_qs[, "q025"] & q_true <= native_qs[, "q975"],
    plugin_mean = rowMeans(plugin_q),
    plugin_sd = plugin_sd,
    plugin_q025 = plugin_qs[, "q025"],
    plugin_median = plugin_qs[, "q500"],
    plugin_q975 = plugin_qs[, "q975"],
    plugin_oracle_covered = q_true >= plugin_qs[, "q025"] & q_true <= plugin_qs[, "q975"],
    recursion_mean_shift = rowMeans(plugin_q) - rowMeans(native_q),
    recursion_sd_ratio = plugin_sd / native_sd,
    stringsAsFactors = FALSE
  )

  group_summary <- do.call(rbind, list(
    .qdesn_validation_dispersion_group_rows(
      native_q, q_true, y, tau, grid$forecast_lead, "lead", "posterior_predictive"
    ),
    .qdesn_validation_dispersion_group_rows(
      plugin_q, q_true, y, tau, grid$forecast_lead, "lead", "conditional_mean_plugin"
    ),
    .qdesn_validation_dispersion_group_rows(
      native_q, q_true, y, tau, grid$forecast_origin_source_index,
      "origin", "posterior_predictive"
    ),
    .qdesn_validation_dispersion_group_rows(
      plugin_q, q_true, y, tau, grid$forecast_origin_source_index,
      "origin", "conditional_mean_plugin"
    )
  ))
  rownames(group_summary) <- NULL

  point_native <- c(
    forecast_mae = mean(abs(rowMeans(native_q) - q_true)),
    forecast_check_loss = mean(
      .qdesn_validation_metric_check_loss(y, rowMeans(native_q), tau)
    )
  )
  point_plugin <- c(
    forecast_mae = mean(abs(rowMeans(plugin_q) - q_true)),
    forecast_check_loss = mean(
      .qdesn_validation_metric_check_loss(y, rowMeans(plugin_q), tau)
    )
  )
  overall <- do.call(rbind, list(
    .qdesn_validation_dispersion_summary_row(
      native$forecast_mae, "forecast_mae", "posterior_predictive",
      metric_at_mean_path = point_native[["forecast_mae"]]
    ),
    .qdesn_validation_dispersion_summary_row(
      plugin$forecast_mae, "forecast_mae", "conditional_mean_plugin",
      metric_at_mean_path = point_plugin[["forecast_mae"]]
    ),
    .qdesn_validation_dispersion_summary_row(
      native$forecast_check_loss, "forecast_check_loss", "posterior_predictive",
      metric_at_mean_path = point_native[["forecast_check_loss"]]
    ),
    .qdesn_validation_dispersion_summary_row(
      plugin$forecast_check_loss, "forecast_check_loss", "conditional_mean_plugin",
      metric_at_mean_path = point_plugin[["forecast_check_loss"]]
    )
  ))
  native_mae <- overall[overall$metric == "forecast_mae" &
                          overall$recursion_mode == "posterior_predictive", ]
  plugin_mae <- overall[overall$metric == "forecast_mae" &
                          overall$recursion_mode == "conditional_mean_plugin", ]
  native_cov <- .qdesn_validation_dispersion_covariance_decomposition(
    abs(sweep(native_q, 1L, q_true, "-")), grid$forecast_origin_source_index
  )
  plugin_cov <- .qdesn_validation_dispersion_covariance_decomposition(
    abs(sweep(plugin_q, 1L, q_true, "-")), grid$forecast_origin_source_index
  )
  permuted_width <- NA_real_
  if (!is.null(coupling_draws) && nrow(coupling_draws)) {
    x <- coupling_draws[
      coupling_draws$coupling_mode == "origin_independent_permutation",
      "forecast_mae", drop = TRUE
    ]
    if (length(x)) {
      qq <- stats::quantile(x, c(0.025, 0.975), names = FALSE, type = 8)
      permuted_width <- qq[[2L]] - qq[[1L]]
    }
  }
  mechanism <- data.frame(
    native_mae_mean = native_mae$posterior_mean,
    native_mae_width = native_mae$cri_width,
    plugin_mae_mean = plugin_mae$posterior_mean,
    plugin_mae_width = plugin_mae$cri_width,
    plugin_to_native_width_ratio = plugin_mae$cri_width / native_mae$cri_width,
    origin_permuted_mae_width = permuted_width,
    origin_permuted_to_native_width_ratio = permuted_width / native_mae$cri_width,
    native_mae_skewness = .qdesn_validation_dispersion_skewness(native$forecast_mae),
    plugin_mae_skewness = .qdesn_validation_dispersion_skewness(plugin$forecast_mae),
    native_mean_pairwise_path_correlation =
      .qdesn_validation_dispersion_mean_pairwise_correlation(native_q),
    plugin_mean_pairwise_path_correlation =
      .qdesn_validation_dispersion_mean_pairwise_correlation(plugin_q),
    native_cross_origin_covariance_fraction = native_cov$cross_origin_covariance_fraction,
    plugin_cross_origin_covariance_fraction = plugin_cov$cross_origin_covariance_fraction,
    recursion_delta_rmse_mean = mean(draw_diag$recursion_delta_rmse),
    native_oracle_coverage = mean(target$native_oracle_covered),
    plugin_oracle_coverage = mean(target$plugin_oracle_covered),
    same_posterior_draws = isTRUE(context$recursion_contract$same_posterior_draws),
    stringsAsFactors = FALSE
  )

  metric_fields <- c("forecast_mae_native", "forecast_mae_plugin",
                     "forecast_check_native", "forecast_check_plugin",
                     "common_shift_native", "recursion_delta_rmse")
  parameter_fields <- intersect(
    c("beta_intercept", "beta_norm", "sigma", "gamma", "tau", "c2",
      "lambda_mean", "lambda_min", "lambda_max"), names(draw_diag)
  )
  correlations <- do.call(rbind, lapply(parameter_fields, function(parameter) {
    do.call(rbind, lapply(metric_fields, function(metric) {
      x <- as.numeric(draw_diag[[parameter]])
      z <- as.numeric(draw_diag[[metric]])
      ok <- is.finite(x) & is.finite(z)
      data.frame(
        parameter = parameter,
        diagnostic = metric,
        pearson = if (sum(ok) > 2L && stats::sd(x[ok]) > 0 && stats::sd(z[ok]) > 0) {
          stats::cor(x[ok], z[ok], method = "pearson")
        } else NA_real_,
        spearman = if (sum(ok) > 2L && stats::sd(x[ok]) > 0 && stats::sd(z[ok]) > 0) {
          suppressWarnings(stats::cor(x[ok], z[ok], method = "spearman"))
        } else NA_real_,
        n = sum(ok),
        stringsAsFactors = FALSE
      )
    }))
  }))
  rownames(correlations) <- NULL
  list(
    draw_diagnostics = draw_diag,
    target_summary = target,
    group_summary = group_summary,
    overall_summary = overall,
    mechanism_summary = mechanism,
    parameter_correlations = correlations
  )
}

.qdesn_validation_write_metric_dispersion_artifacts <- function(draws,
                                                                 coupling_draws,
                                                                 summary_obj,
                                                                 root_spec,
                                                                 method_dir,
                                                                 defaults = NULL) {
  cfg <- .qdesn_validation_metric_dispersion_cfg(defaults)
  if (!isTRUE(cfg$enabled)) {
    return(list(status = "DISABLED", manifest_path = NA_character_))
  }
  artifacts <- .qdesn_validation_metric_dispersion_artifacts(draws, coupling_draws)
  table_dir <- file.path(method_dir, "tables")
  manifest_dir <- file.path(method_dir, "manifest")
  dir.create(table_dir, recursive = TRUE, showWarnings = FALSE)
  dir.create(manifest_dir, recursive = TRUE, showWarnings = FALSE)
  paths <- c(
    draw_diagnostics = file.path(table_dir, "metric_dispersion_draw_diagnostics.csv.gz"),
    target_summary = file.path(table_dir, "metric_dispersion_target_summary.csv.gz"),
    group_summary = file.path(table_dir, "metric_dispersion_group_summary.csv"),
    overall_summary = file.path(table_dir, "metric_dispersion_overall_summary.csv"),
    mechanism_summary = file.path(table_dir, "metric_dispersion_mechanism_summary.csv"),
    parameter_correlations = file.path(table_dir, "metric_dispersion_parameter_correlations.csv")
  )
  for (name in names(paths)) {
    path <- paths[[name]]
    value <- artifacts[[name]]
    if (grepl("[.]gz$", path)) {
      con <- gzfile(path, open = "wt")
      tryCatch(utils::write.csv(value, con, row.names = FALSE, na = ""),
               finally = close(con))
    } else {
      .qdesn_validation_write_df(value, path)
    }
  }
  sha <- function(path) digest::digest(file = path, algo = "sha256", serialize = FALSE)
  manifest_path <- file.path(manifest_dir, "metric_dispersion_manifest.json")
  manifest <- list(
    schema_version = cfg$schema_version,
    generated_at = as.character(Sys.time()),
    root_id = as.character(root_spec$root_id),
    status = "PASS",
    scientific_role = "mechanism_diagnostic_not_primary_estimator",
    primary_recursion = "posterior_predictive",
    counterfactual_recursion = "conditional_mean_plugin",
    primary_metric_values_unchanged = TRUE,
    artifact_paths = lapply(paths, normalizePath, winslash = "/", mustWork = TRUE),
    artifact_sha256 = lapply(paths, sha),
    artifact_rows = lapply(artifacts, nrow),
    heavy_binary_retained = FALSE
  )
  .qdesn_validation_write_json(manifest_path, manifest)
  list(
    status = "PASS",
    manifest_path = normalizePath(manifest_path, winslash = "/", mustWork = TRUE),
    manifest_sha256 = sha(manifest_path),
    paths = as.list(paths)
  )
}

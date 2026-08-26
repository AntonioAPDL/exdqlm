.qdesn_validation_metric_interval_cfg <- function(defaults = NULL) {
  metrics <- (defaults %||% list())$metrics %||% list()
  x <- metrics$posterior_metric_intervals %||% list()
  enabled <- isTRUE(x$enabled)
  draws <- as.integer(x$draws %||% metrics$posterior_metric_draws %||% 4000L)[1L]
  if (!is.finite(draws) || draws < 2L) draws <- 4000L
  list(
    enabled = enabled,
    required = isTRUE(x$required %||% enabled),
    draws = draws,
    chain_id = as.integer(x$chain_id %||% 1L)[1L],
    estimator_id = as.character(x$estimator_id %||%
      "posterior_mean_draw_metric_equal_tailed_95cri_v1")[1L]
  )
}

.qdesn_validation_metric_coupling_cfg <- function(defaults = NULL) {
  metrics <- (defaults %||% list())$metrics %||% list()
  x <- ((metrics$posterior_metric_intervals %||% list())$coupling_sensitivity %||%
          list())
  seed <- as.integer(x$seed %||% 20260824L)[1L]
  if (!is.finite(seed) || seed < 1L) seed <- 20260824L
  list(
    enabled = isTRUE(x$enabled),
    seed = seed,
    modes = as.character(x$modes %||%
      c("native_aligned", "origin_independent_permutation")),
    decision_contract = as.character(x$decision_contract %||%
      "paired_marginal_coupling_sensitivity_v1")[1L]
  )
}

.qdesn_validation_metric_dispersion_cfg <- function(defaults = NULL) {
  metrics <- (defaults %||% list())$metrics %||% list()
  x <- (((metrics$posterior_metric_intervals %||% list())$dispersion_diagnostic) %||%
          list())
  enabled <- isTRUE(x$enabled)
  list(
    enabled = enabled,
    required = isTRUE(x$required %||% enabled),
    recursion_counterfactual = isTRUE(x$recursion_counterfactual %||% TRUE),
    schema_version = as.character(x$schema_version %||%
      "independent_qdesn_metric_interval_dispersion_v1")[1L]
  )
}

.qdesn_validation_origin_horizon_cfg <- function(defaults = NULL) {
  metrics <- (defaults %||% list())$metrics %||% list()
  x <- (((metrics$posterior_metric_intervals %||% list())$
    origin_horizon_attribution) %||% list())
  enabled <- isTRUE(x$enabled)
  list(
    enabled = enabled,
    required = isTRUE(x$required %||% enabled),
    balanced_complete_origins = isTRUE(x$balanced_complete_origins %||% TRUE),
    schema_version = as.character(x$schema_version %||%
      "independent_qdesn_origin_horizon_attribution_v1")[[1L]]
  )
}

.qdesn_validation_with_seed <- function(seed, code) {
  old <- if (exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)) {
    get(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
  } else NULL
  on.exit({
    if (is.null(old)) {
      if (exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)) {
        rm(".Random.seed", envir = .GlobalEnv)
      }
    } else assign(".Random.seed", old, envir = .GlobalEnv)
  }, add = TRUE)
  set.seed(as.integer(seed)[1L])
  force(code)
}

.qdesn_validation_origin_permutation <- function(n_draws, seed, origin_source_index) {
  n_draws <- as.integer(n_draws)[1L]
  keyed_seed <- (as.double(seed) + 104729 * as.double(origin_source_index)) %%
    (.Machine$integer.max - 1)
  keyed_seed <- as.integer(keyed_seed + 1)
  .qdesn_validation_with_seed(keyed_seed, sample.int(n_draws, n_draws, replace = FALSE))
}

.qdesn_validation_even_draw_indices <- function(n_available, n_keep) {
  n_available <- as.integer(n_available)[1L]
  n_keep <- as.integer(n_keep)[1L]
  if (!is.finite(n_available) || n_available < 1L) integer(0) else if (
    !is.finite(n_keep) || n_keep >= n_available
  ) {
    seq_len(n_available)
  } else {
    unique(as.integer(round(seq(1, n_available, length.out = n_keep))))
  }
}

.qdesn_validation_metric_check_loss <- function(y, q, tau) {
  u <- y - q
  u * (tau - as.numeric(u < 0))
}

.qdesn_validation_metric_draws_from_summary <- function(summary_obj,
                                                         root_spec,
                                                         defaults = NULL) {
  cfg <- .qdesn_validation_metric_interval_cfg(defaults)
  coupling_cfg <- .qdesn_validation_metric_coupling_cfg(defaults)
  dispersion_cfg <- .qdesn_validation_metric_dispersion_cfg(defaults)
  if (!isTRUE(cfg$enabled)) return(data.frame(stringsAsFactors = FALSE))
  fits_fc <- (summary_obj$forecast_objects %||% list())$fits_fc %||% list()
  if (!length(fits_fc)) stop("Metric intervals require forecast_objects$fits_fc.", call. = FALSE)
  fit_entry <- fits_fc[[1L]]
  fit_draws <- as.matrix(fit_entry$mu_draws_tr %||% NULL)
  keep_idx <- as.integer((fit_entry$fit_train$meta %||% list())$keep_idx %||% integer(0))
  if (!length(keep_idx) || nrow(fit_draws) != length(keep_idx)) {
    if (ncol(fit_draws) == length(keep_idx)) fit_draws <- t(fit_draws)
  }
  if (!length(keep_idx) || nrow(fit_draws) != length(keep_idx)) {
    stop(sprintf(
      "Q-DESN fit metric interval contract requires aligned post-lag rows; found keep=%d draws=%d.",
      length(keep_idx), nrow(fit_draws)
    ), call. = FALSE)
  }

  forecast_full <- fit_entry$forecast_full %||% list()
  origins_local <- as.integer(forecast_full$origins %||% integer(0))
  mu_by_origin <- forecast_full$mu_by_origin %||% list()
  if (!length(origins_local) || length(mu_by_origin) != length(origins_local)) {
    stop("Q-DESN metric intervals require aligned origins and mu_by_origin.", call. = FALSE)
  }
  mu_by_origin_plugin <- forecast_full$mu_by_origin_conditional_mean_plugin %||% list()
  if (isTRUE(dispersion_cfg$enabled) && isTRUE(dispersion_cfg$recursion_counterfactual) &&
      length(mu_by_origin_plugin) != length(origins_local)) {
    stop("Enabled dispersion diagnostics require conditional-mean plug-in paths.",
         call. = FALSE)
  }
  n_available <- min(c(ncol(fit_draws), vapply(mu_by_origin, function(x) ncol(as.matrix(x)), integer(1L))))
  draw_idx <- .qdesn_validation_even_draw_indices(n_available, cfg$draws)
  if (length(draw_idx) < 2L) stop("Q-DESN metric intervals require at least two draws.", call. = FALSE)
  fit_draws <- fit_draws[, draw_idx, drop = FALSE]

  source_df <- .qdesn_validation_read_source_series(root_spec)
  if (is.null(source_df) || !nrow(source_df)) {
    stop("Q-DESN metric intervals require the staged source series.", call. = FALSE)
  }
  source_index <- if ("source_index" %in% names(source_df)) {
    as.integer(source_df$source_index)
  } else if ("t" %in% names(source_df)) {
    as.integer(source_df$t)
  } else seq_len(nrow(source_df))
  q_true <- if ("q_target" %in% names(source_df)) {
    as.numeric(source_df$q_target)
  } else if ("q_true" %in% names(source_df)) {
    as.numeric(source_df$q_true)
  } else as.numeric(source_df$mu)
  y <- as.numeric(source_df$y)
  fit_source_index <- source_index[keep_idx]
  target_fit <- fit_source_index >= as.integer(root_spec$train_start_source_index) &
    fit_source_index <= as.integer(root_spec$train_end_source_index)
  if (sum(target_fit) != 500L) {
    stop(sprintf(
      "Q-DESN fit metric interval contract requires 500 source rows in %d:%d; found %d.",
      as.integer(root_spec$train_start_source_index),
      as.integer(root_spec$train_end_source_index), sum(target_fit)
    ), call. = FALSE)
  }
  fit_draws <- fit_draws[target_fit, , drop = FALSE]
  fit_q_true <- q_true[match(fit_source_index[target_fit], source_index)]
  if (any(!is.finite(fit_q_true))) stop("Fit oracle quantiles contain non-finite values.", call. = FALSE)
  fit_rmse <- sqrt(colMeans(sweep(fit_draws, 1L, fit_q_true, "-")^2, na.rm = TRUE))

  rolling_cfg <- .qdesn_validation_rolling_origin_cfg(defaults)
  grid <- .qdesn_validation_rolling_grid(
    train_end_source_index = root_spec$train_end_source_index,
    forecast_start_source_index = root_spec$forecast_start_source_index,
    forecast_end_source_index = root_spec$forecast_end_source_index,
    hmax = rolling_cfg$max_lead_configured,
    origin_stride = rolling_cfg$origin_stride,
    forecast_protocol = rolling_cfg$forecast_protocol
  )
  if (nrow(grid) != 1000L || length(unique(grid$target_source_index)) != 1000L) {
    stop(sprintf("Rolling metric interval grid must contain 1000 unique targets; found %d rows.",
                 nrow(grid)), call. = FALSE)
  }
  local_origin <- match(as.integer(grid$forecast_origin_source_index), source_index)
  local_target <- match(as.integer(grid$target_source_index), source_index)
  if (anyNA(local_origin) || anyNA(local_target)) {
    stop("Rolling metric interval grid does not map to staged source rows.", call. = FALSE)
  }
  scale_spec <- .qdesn_validation_lead_export_scale_spec(forecast_full)
  abs_sum <- numeric(length(draw_idx))
  check_sum <- numeric(length(draw_idx))
  product_abs_sum <- if (isTRUE(coupling_cfg$enabled)) numeric(length(draw_idx)) else NULL
  product_check_sum <- if (isTRUE(coupling_cfg$enabled)) numeric(length(draw_idx)) else NULL
  product_maps <- if (isTRUE(coupling_cfg$enabled)) {
    lapply(origins_local, function(origin) {
      .qdesn_validation_origin_permutation(length(draw_idx), coupling_cfg$seed, origin)
    })
  } else NULL
  tau <- as.numeric(root_spec$tau)[1L]
  native_q <- if (isTRUE(dispersion_cfg$enabled)) {
    matrix(NA_real_, nrow = nrow(grid), ncol = length(draw_idx))
  } else NULL
  plugin_q <- if (isTRUE(dispersion_cfg$enabled) &&
                  isTRUE(dispersion_cfg$recursion_counterfactual)) {
    matrix(NA_real_, nrow = nrow(grid), ncol = length(draw_idx))
  } else NULL
  for (i in seq_len(nrow(grid))) {
    origin_pos <- match(local_origin[[i]], origins_local)
    if (is.na(origin_pos)) stop("A rolling origin is absent from mu_by_origin.", call. = FALSE)
    lead <- as.integer(grid$forecast_lead[[i]])
    mu <- as.matrix(mu_by_origin[[origin_pos]])
    if (nrow(mu) < lead || ncol(mu) < max(draw_idx)) {
      stop("A rolling-origin conditional-quantile matrix is incomplete.", call. = FALSE)
    }
    q <- as.numeric(.qdesn_validation_apply_lead_export_scale(
      matrix(mu[lead, draw_idx], nrow = 1L), scale_spec
    ))
    if (isTRUE(dispersion_cfg$enabled)) native_q[i, ] <- q
    target <- local_target[[i]]
    abs_sum <- abs_sum + abs(q - q_true[[target]])
    check_sum <- check_sum + .qdesn_validation_metric_check_loss(y[[target]], q, tau)
    if (isTRUE(coupling_cfg$enabled)) {
      product_cols <- draw_idx[product_maps[[origin_pos]]]
      q_product <- as.numeric(.qdesn_validation_apply_lead_export_scale(
        matrix(mu[lead, product_cols], nrow = 1L), scale_spec
      ))
      product_abs_sum <- product_abs_sum + abs(q_product - q_true[[target]])
      product_check_sum <- product_check_sum +
        .qdesn_validation_metric_check_loss(y[[target]], q_product, tau)
    }
    if (!is.null(plugin_q)) {
      mu_plugin <- as.matrix(mu_by_origin_plugin[[origin_pos]])
      if (nrow(mu_plugin) < lead || ncol(mu_plugin) < max(draw_idx)) {
        stop("A conditional-mean plug-in path matrix is incomplete.", call. = FALSE)
      }
      plugin_q[i, ] <- as.numeric(.qdesn_validation_apply_lead_export_scale(
        matrix(mu_plugin[lead, draw_idx], nrow = 1L), scale_spec
      ))
    }
  }
  out <- data.frame(
    chain_id = cfg$chain_id,
    draw_id = seq_along(draw_idx),
    source_draw_index = draw_idx,
    fit_rmse = fit_rmse,
    forecast_mae = abs_sum / nrow(grid),
    forecast_check_loss = check_sum / nrow(grid),
    draw_source = "mu_draws_tr+mu_by_origin",
    stringsAsFactors = FALSE
  )
  metric_matrix <- as.matrix(out[c("fit_rmse", "forecast_mae", "forecast_check_loss")])
  if (any(!is.finite(metric_matrix))) stop("Q-DESN metric draws contain non-finite values.", call. = FALSE)
  if (isTRUE(coupling_cfg$enabled)) {
    attr(out, "metric_coupling_draws") <- rbind(
      data.frame(
        chain_id = cfg$chain_id,
        draw_id = seq_along(draw_idx),
        coupling_mode = "native_aligned",
        forecast_mae = abs_sum / nrow(grid),
        forecast_check_loss = check_sum / nrow(grid),
        draw_source = "mu_by_origin_native_aligned",
        stringsAsFactors = FALSE
      ),
      data.frame(
        chain_id = cfg$chain_id,
        draw_id = seq_along(draw_idx),
        coupling_mode = "origin_independent_permutation",
        forecast_mae = product_abs_sum / nrow(grid),
        forecast_check_loss = product_check_sum / nrow(grid),
        draw_source = "mu_by_origin_origin_independent_permutation",
        stringsAsFactors = FALSE
      )
    )
  }
  if (isTRUE(dispersion_cfg$enabled)) {
    posterior_source_draw_index <- as.integer(
      forecast_full$source_draw_index %||% seq_len(n_available)
    )
    draw_parameters <- as.data.frame(
      forecast_full$draw_parameters %||% data.frame(stringsAsFactors = FALSE),
      stringsAsFactors = FALSE
    )
    attr(out, "metric_dispersion_context") <- list(
      schema_version = dispersion_cfg$schema_version,
      native_q = native_q,
      plugin_q = plugin_q,
      q_true = as.numeric(q_true[local_target]),
      y = as.numeric(y[local_target]),
      grid = grid,
      origins_local = origins_local,
      tau = tau,
      draw_parameters = if (nrow(draw_parameters) >= max(draw_idx)) {
        draw_parameters[draw_idx, , drop = FALSE]
      } else data.frame(stringsAsFactors = FALSE),
      posterior_source_draw_index = posterior_source_draw_index[draw_idx],
      fit = fit_entry$fit_train$fit %||% NULL,
      recursion_contract = forecast_full$dispersion_diagnostic_contract %||% list()
    )
  }
  out
}

.qdesn_validation_metric_interval_summary <- function(draws, method, estimator_id) {
  metrics <- c("fit_rmse", "forecast_mae", "forecast_check_loss")
  do.call(rbind, lapply(metrics, function(metric) {
    x <- as.numeric(draws[[metric]])
    qs <- stats::quantile(x, c(0.025, 0.5, 0.975), names = FALSE,
                          type = 8, na.rm = TRUE)
    data.frame(
      metric = metric,
      posterior_mean = mean(x),
      posterior_sd = stats::sd(x),
      cri_lower = qs[[1L]],
      posterior_median = qs[[2L]],
      cri_upper = qs[[3L]],
      posterior_mean_inside_cri = mean(x) >= qs[[1L]] && mean(x) <= qs[[3L]],
      interval_probability = 0.95,
      n_draws = length(x),
      n_chains = length(unique(draws$chain_id)),
      inference = method,
      interval_label = if (identical(method, "vb")) {
        "approximate_95pct_credible_interval"
      } else "95pct_credible_interval",
      estimator_id = estimator_id,
      stringsAsFactors = FALSE
    )
  }))
}

.qdesn_validation_metric_coupling_summary <- function(draws) {
  blocks <- split(draws, as.character(draws$coupling_mode))
  out <- do.call(rbind, lapply(blocks, function(block) {
    do.call(rbind, lapply(c("forecast_mae", "forecast_check_loss"), function(metric) {
      x <- as.numeric(block[[metric]])
      qs <- stats::quantile(x, c(0.025, 0.5, 0.975), names = FALSE,
                            type = 8, na.rm = TRUE)
      data.frame(
        coupling_mode = as.character(block$coupling_mode[[1L]]),
        metric = metric,
        posterior_mean = mean(x),
        posterior_sd = stats::sd(x),
        cri_lower = qs[[1L]],
        posterior_median = qs[[2L]],
        cri_upper = qs[[3L]],
        n_draws = length(x),
        n_chains = length(unique(draws$chain_id)),
        stringsAsFactors = FALSE
      )
    }))
  }))
  rownames(out) <- NULL
  out
}

.qdesn_validation_write_metric_interval_artifacts <- function(summary_obj,
                                                               root_spec,
                                                               method_dir,
                                                               defaults = NULL) {
  cfg <- .qdesn_validation_metric_interval_cfg(defaults)
  if (!isTRUE(cfg$enabled)) {
    return(list(status = "DISABLED", draws = NA_character_, summary = NA_character_,
                manifest = NA_character_, rows = 0L))
  }
  draws <- .qdesn_validation_metric_draws_from_summary(summary_obj, root_spec, defaults)
  coupling_draws <- attr(draws, "metric_coupling_draws")
  summary <- .qdesn_validation_metric_interval_summary(
    draws, method = as.character((summary_obj$summary$inference_method %||% root_spec$method %||% "mcmc")[1L]),
    estimator_id = cfg$estimator_id
  )
  if (any(summary$cri_lower > summary$posterior_median |
          summary$posterior_median > summary$cri_upper)) {
    stop("A Q-DESN metric interval does not contain its posterior median.", call. = FALSE)
  }
  draws_path <- file.path(method_dir, "tables", "metric_draws.csv.gz")
  summary_path <- file.path(method_dir, "tables", "metric_interval_summary.csv")
  manifest_path <- file.path(method_dir, "manifest", "metric_interval_manifest.json")
  coupling_draws_path <- file.path(method_dir, "tables", "metric_coupling_draws.csv.gz")
  coupling_summary_path <- file.path(method_dir, "tables", "metric_coupling_summary.csv")
  dir.create(dirname(draws_path), recursive = TRUE, showWarnings = FALSE)
  con <- gzfile(draws_path, open = "wt")
  tryCatch(
    utils::write.csv(draws, con, row.names = FALSE, na = ""),
    finally = close(con)
  )
  .qdesn_validation_write_df(summary, summary_path)
  sha <- function(path) digest::digest(file = path, algo = "sha256", serialize = FALSE)
  coupling_cfg <- .qdesn_validation_metric_coupling_cfg(defaults)
  coupling_manifest <- NULL
  if (isTRUE(coupling_cfg$enabled)) {
    if (is.null(coupling_draws) || !nrow(coupling_draws)) {
      stop("Enabled Q-DESN coupling sensitivity did not produce draws.", call. = FALSE)
    }
    coupling_summary <- .qdesn_validation_metric_coupling_summary(coupling_draws)
    con <- gzfile(coupling_draws_path, open = "wt")
    tryCatch(
      utils::write.csv(coupling_draws, con, row.names = FALSE, na = ""),
      finally = close(con)
    )
    .qdesn_validation_write_df(coupling_summary, coupling_summary_path)
    coupling_manifest <- list(
      schema_version = "independent_metric_interval_coupling_sensitivity_v1",
      modes = sort(unique(as.character(coupling_draws$coupling_mode))),
      decision_contract = coupling_cfg$decision_contract,
      metric_coupling_draws_path = normalizePath(
        coupling_draws_path, winslash = "/", mustWork = TRUE
      ),
      metric_coupling_draws_sha256 = sha(coupling_draws_path),
      metric_coupling_summary_path = normalizePath(
        coupling_summary_path, winslash = "/", mustWork = TRUE
      ),
      metric_coupling_summary_sha256 = sha(coupling_summary_path)
    )
  }
  dispersion_cfg <- .qdesn_validation_metric_dispersion_cfg(defaults)
  dispersion_manifest <- NULL
  if (isTRUE(dispersion_cfg$enabled)) {
    dispersion_manifest <- .qdesn_validation_write_metric_dispersion_artifacts(
      draws = draws,
      coupling_draws = coupling_draws,
      summary_obj = summary_obj,
      root_spec = root_spec,
      method_dir = method_dir,
      defaults = defaults
    )
    if (isTRUE(dispersion_cfg$required) &&
        !identical(as.character(dispersion_manifest$status), "PASS")) {
      stop("Required metric-dispersion diagnostics were not written.", call. = FALSE)
    }
  }
  attribution_cfg <- .qdesn_validation_origin_horizon_cfg(defaults)
  attribution_manifest <- NULL
  if (isTRUE(attribution_cfg$enabled)) {
    attribution_manifest <- .qdesn_validation_write_origin_horizon_attribution(
      draws = draws,
      method_dir = method_dir,
      defaults = defaults
    )
    if (isTRUE(attribution_cfg$required) &&
        !identical(as.character(attribution_manifest$status), "PASS")) {
      stop("Required origin-horizon attribution artifacts were not written.",
           call. = FALSE)
    }
  }
  common_shift_cfg <- .qdesn_validation_common_shift_cfg(defaults)
  common_shift_manifest <- NULL
  if (isTRUE(common_shift_cfg$enabled)) {
    common_shift_manifest <- .qdesn_validation_write_common_shift_intervention(
      draws = draws, method_dir = method_dir, defaults = defaults
    )
    if (isTRUE(common_shift_cfg$required) &&
        !identical(as.character(common_shift_manifest$status), "PASS")) {
      stop("Required common-shift intervention artifacts were not written.",
           call. = FALSE)
    }
  }
  manifest <- list(
    schema_version = "independent_metric_intervals_v1",
    generated_at = as.character(Sys.time()),
    root_id = as.character(root_spec$root_id),
    chain_id = cfg$chain_id,
    estimator_id = cfg$estimator_id,
    draw_source_contract = "conditional_quantile_not_response_predictive",
    fit_rows = 500L,
    forecast_rows = 1000L,
    metric_draws = nrow(draws),
    metric_draws_path = normalizePath(draws_path, winslash = "/", mustWork = TRUE),
    metric_draws_sha256 = sha(draws_path),
    metric_interval_summary_path = normalizePath(summary_path, winslash = "/", mustWork = TRUE),
    metric_interval_summary_sha256 = sha(summary_path),
    heavy_binary_retained = FALSE,
    coupling_sensitivity = coupling_manifest,
    dispersion_diagnostic = dispersion_manifest,
    origin_horizon_attribution = attribution_manifest,
    common_shift_intervention = common_shift_manifest
  )
  .qdesn_validation_write_json(manifest_path, manifest)
  list(
    status = "PASS",
    draws = normalizePath(draws_path, winslash = "/", mustWork = TRUE),
    summary = normalizePath(summary_path, winslash = "/", mustWork = TRUE),
    manifest = normalizePath(manifest_path, winslash = "/", mustWork = TRUE),
    rows = nrow(draws),
    coupling_draws = if (is.null(coupling_manifest)) NA_character_ else
      normalizePath(coupling_draws_path, winslash = "/", mustWork = TRUE),
    coupling_summary = if (is.null(coupling_manifest)) NA_character_ else
      normalizePath(coupling_summary_path, winslash = "/", mustWork = TRUE),
    dispersion_manifest = if (is.null(dispersion_manifest)) NA_character_ else
      as.character(dispersion_manifest$manifest_path)
  )
}

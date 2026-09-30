iqcf_v3_schema <- "independent_qdesn_corrected_forecast_v3_v1"
iqcf_v3_expected_branch <-
  "validation/independent-qdesn-corrected-forecast-v3-20260930"
iqcf_v3_protocol_relpath <- file.path(
  "config", "validation", "independent_qdesn_corrected_forecast_v3",
  "protocol_defaults.yaml"
)

iqcf_v3_read_protocol <- function(repo_root = iqfr_v2_repo_root()) {
  path <- file.path(repo_root, iqcf_v3_protocol_relpath)
  if (!file.exists(path)) stop("Missing corrected-forecast protocol: ", path,
                               call. = FALSE)
  yaml::read_yaml(path)
}

iqcf_v3_protocol_checks <- function(protocol = iqcf_v3_read_protocol()) {
  scope <- protocol$scope
  forecast <- protocol$forecast
  search <- protocol$search
  execution <- protocol$execution
  shrinkage <- protocol$shrinkage
  inference <- protocol$inference
  gates <- protocol$gates
  response_transport <- protocol$response_transport
  checks <- c(
    protocol_id = identical(protocol$protocol$id,
                            "independent_qdesn_corrected_forecast_v3"),
    lane = identical(protocol$protocol$scientific_lane,
                     "independent_single_quantile_qdesn_dqlm_validation"),
    no_article_write = !isTRUE(protocol$protocol$article_write_permitted) &&
      !isTRUE(protocol$protocol$shared_validation_merge_permitted) &&
      !isTRUE(protocol$protocol$overleaf_write_permitted),
    families = identical(as.character(scope$families),
                         c("normal", "laplace", "gausmix")),
    canary_quantile = identical(as.numeric(scope$canary_quantile), 0.5),
    likelihoods = identical(as.character(scope$likelihoods), c("al", "exal")),
    causal_forecast = isTRUE(forecast$teacher_forced_between_origins) &&
      isTRUE(forecast$recursive_within_origin) &&
      !isTRUE(forecast$future_observations_within_origin) &&
      !isTRUE(forecast$refit_per_origin),
    horizon = identical(as.integer(forecast$horizon), 30L),
    separate_estimands = identical(
      as.character(forecast$estimands),
      c("oracle_location_path", "marginal_predictive_quantile")
    ),
    inner_paths = identical(as.integer(unlist(forecast$inner_path_grid)),
                            c(64L, 128L, 256L, 512L)),
    identity_projection = identical(search$projection, "identity") &&
      isTRUE(search$dimensionality_reduction_forbidden),
    no_exogenous_lags = identical(as.integer(search$mx), 0L),
    canary_budget = identical(
      as.integer(execution$maximum_atomic_vb_fits), 72L
    ),
    no_automatic_broad_launch = !isTRUE(execution$automatic_broad_launch),
    canary_tau0_arms = identical(
      as.character(shrinkage$canary_arm_policy),
      c("dimension_reference", "source_equivalent_continuity",
        "source_equivalent_high_100")
    ) && identical(as.numeric(shrinkage$source_scale_bounds), c(3e-9, 100)) &&
      identical(shrinkage$parameterization_scale, "standardized_response") &&
      identical(as.numeric(shrinkage$slab_s2), 1),
    m0_exal = identical(
      as.character(inference$mcmc$exal_method_id),
      "m0_v_collapsed_support_logit"
    ),
    canary_baseline_gate = identical(
      as.character(gates$canary_baseline),
      "training_empirical_quantile_constant"
    ) && identical(as.numeric(gates$maximum_catastrophic_oracle_mae_ratio), 5),
    response_transport = isTRUE(response_transport$enabled) &&
      identical(response_transport$fitted_on, "internal_fitting_rows_only") &&
      identical(response_transport$center, "arithmetic_mean") &&
      identical(response_transport$scale, "sample_standard_deviation") &&
      isTRUE(response_transport$positive_affine_quantile_equivariance) &&
      isTRUE(response_transport$inverse_transform_before_scoring) &&
      !isTRUE(response_transport$future_rows_used_for_transport) &&
      identical(gates$operator_smoke_tau0_arm, "dimension_reference"),
    workers = identical(as.integer(execution$workers), 15L) &&
      identical(as.integer(execution$threads_per_worker), 1L)
  )
  data.frame(check = names(checks), pass = unname(checks),
             stringsAsFactors = FALSE)
}

iqcf_v3_assert_protocol <- function(protocol = iqcf_v3_read_protocol()) {
  checks <- iqcf_v3_protocol_checks(protocol)
  if (any(!checks$pass)) {
    stop("Corrected-forecast protocol checks failed: ",
         paste(checks$check[!checks$pass], collapse = ", "),
         call. = FALSE)
  }
  invisible(checks)
}

iqcf_v3_validate_draws <- function(draws) {
  if (!is.list(draws) || !is.matrix(draws$beta)) {
    stop("draws must contain a beta matrix.", call. = FALSE)
  }
  n <- nrow(draws$beta)
  if (n < 1L || length(draws$sigma) != n || length(draws$gamma) != n ||
      any(!is.finite(draws$beta)) || any(!is.finite(draws$sigma)) ||
      any(draws$sigma <= 0) || any(!is.finite(draws$gamma))) {
    stop("Posterior draw dimensions or values are invalid.", call. = FALSE)
  }
  invisible(n)
}

iqcf_v3_subset_draws <- function(draws, index) {
  iqcf_v3_validate_draws(draws)
  index <- as.integer(index)
  if (!length(index) || any(index < 1L | index > nrow(draws$beta))) {
    stop("Posterior draw index is invalid.", call. = FALSE)
  }
  list(
    beta = draws$beta[index, , drop = FALSE],
    sigma = as.numeric(draws$sigma)[index],
    gamma = as.numeric(draws$gamma)[index],
    source_draw_index = as.integer(
      draws$source_draw_index %||% seq_len(nrow(draws$beta))
    )[index]
  )
}

iqcf_v3_repeat_draws <- function(draws, inner_paths) {
  n <- iqcf_v3_validate_draws(draws)
  inner_paths <- as.integer(inner_paths)
  if (length(inner_paths) != 1L || !is.finite(inner_paths) || inner_paths < 1L) {
    stop("inner_paths must be a positive integer.", call. = FALSE)
  }
  index <- rep(seq_len(n), each = inner_paths)
  out <- iqcf_v3_subset_draws(draws, index)
  out$outer_draw_index <- rep(seq_len(n), each = inner_paths)
  out$inner_path_index <- rep(seq_len(inner_paths), times = n)
  out
}

iqcf_v3_make_noise_bank <- function(draws, horizon, n_origins,
                                     max_inner_paths, seed) {
  outer_draws <- iqcf_v3_validate_draws(draws)
  horizon <- as.integer(horizon)
  n_origins <- as.integer(n_origins)
  max_inner_paths <- as.integer(max_inner_paths)
  seed <- as.integer(seed)
  if (horizon < 1L || n_origins < 1L || max_inner_paths < 1L ||
      !is.finite(seed)) {
    stop("Noise-bank dimensions and seed must be positive and finite.",
         call. = FALSE)
  }
  expanded <- iqcf_v3_repeat_draws(draws, max_inner_paths)
  columns <- nrow(expanded$beta)
  set.seed(seed)
  by_origin <- vector("list", n_origins)
  for (i in seq_len(n_origins)) {
    s <- matrix(abs(stats::rnorm(horizon * columns)), nrow = horizon)
    z <- matrix(stats::rnorm(horizon * columns), nrow = horizon)
    rates <- rep(1 / expanded$sigma, each = horizon)
    v <- matrix(stats::rexp(horizon * columns, rate = rates), nrow = horizon)
    by_origin[[i]] <- list(s = s, v = v, z = z)
  }
  structure(
    list(
      by_origin = by_origin, horizon = horizon, n_origins = n_origins,
      outer_draws = outer_draws, max_inner_paths = max_inner_paths,
      seed = seed,
      source_draw_index = as.integer(
        draws$source_draw_index %||% seq_len(outer_draws)
      )
    ),
    class = "iqcf_v3_noise_bank"
  )
}

iqcf_v3_subset_noise_bank <- function(bank, inner_paths) {
  if (!inherits(bank, "iqcf_v3_noise_bank")) {
    stop("bank is not an iqcf_v3_noise_bank.", call. = FALSE)
  }
  inner_paths <- as.integer(inner_paths)
  if (inner_paths < 1L || inner_paths > bank$max_inner_paths) {
    stop("inner_paths is outside the stored noise bank.", call. = FALSE)
  }
  ids <- unlist(lapply(seq_len(bank$outer_draws), function(j) {
    (j - 1L) * bank$max_inner_paths + seq_len(inner_paths)
  }), use.names = FALSE)
  lapply(bank$by_origin, function(origin) {
    lapply(origin, function(x) x[, ids, drop = FALSE])
  })
}

iqcf_v3_matrix_by_outer_draw <- function(x, outer_draws, inner_paths,
                                          summary = c("mean", "quantile"),
                                          probability = NULL) {
  summary <- match.arg(summary)
  x <- as.matrix(x)
  if (ncol(x) != outer_draws * inner_paths) {
    stop("Nested path matrix does not match outer x inner dimensions.",
         call. = FALSE)
  }
  arr <- array(x, dim = c(nrow(x), inner_paths, outer_draws))
  if (summary == "mean") {
    out <- apply(arr, c(1L, 3L), mean)
  } else {
    if (is.null(probability) || length(probability) != 1L ||
        !is.finite(probability) || probability <= 0 || probability >= 1) {
      stop("A probability strictly between zero and one is required.",
           call. = FALSE)
    }
    out <- apply(arr, c(1L, 3L), stats::quantile,
                 probs = probability, names = FALSE, type = 8)
  }
  matrix(out, nrow = nrow(x), ncol = outer_draws)
}

iqcf_v3_nested_lattice <- function(
  object, y_all, origins, horizon, draws, probability, inner_paths,
  seed, xreg_all = NULL, noise_bank = NULL,
  include_mean_readout_state = FALSE, chunk = 256L
) {
  outer_draws <- iqcf_v3_validate_draws(draws)
  origins <- as.integer(origins)
  horizon <- as.integer(horizon)
  inner_paths <- as.integer(inner_paths)
  probability <- as.numeric(probability)
  if (!length(origins) || horizon < 1L || inner_paths < 1L ||
      length(probability) != 1L || probability <= 0 || probability >= 1) {
    stop("Invalid corrected-forecast lattice arguments.", call. = FALSE)
  }
  if (is.null(noise_bank)) {
    noise_bank <- iqcf_v3_make_noise_bank(
      draws, horizon, length(origins), inner_paths, seed
    )
  }
  if (noise_bank$horizon != horizon ||
      noise_bank$n_origins != length(origins) ||
      noise_bank$outer_draws != outer_draws ||
      !identical(as.integer(noise_bank$source_draw_index), as.integer(
        draws$source_draw_index %||% seq_len(outer_draws)
      ))) {
    stop("Noise bank does not match the forecast lattice.", call. = FALSE)
  }

  repeated <- iqcf_v3_repeat_draws(draws, inner_paths)
  noise <- iqcf_v3_subset_noise_bank(noise_bank, inner_paths)
  path <- forecast_lattice.qdesn_fit(
    object, y_all = y_all, origins = origins, H = horizon,
    nd = nrow(repeated$beta), xreg_all = xreg_all,
    keep_origin_draws = TRUE, draws = repeated,
    noise_draws_by_origin = noise, build_mix = FALSE, seed = seed,
    chunk = chunk, recursion_mode = "posterior_predictive"
  )
  zeros <- lapply(seq_along(origins), function(i) {
    z <- matrix(0, nrow = horizon, ncol = outer_draws)
    list(s = z, v = z, z = z)
  })
  plugin <- forecast_lattice.qdesn_fit(
    object, y_all = y_all, origins = origins, H = horizon,
    nd = outer_draws, xreg_all = xreg_all, keep_origin_draws = TRUE,
    draws = draws, noise_draws_by_origin = zeros, build_mix = FALSE,
    seed = seed, chunk = chunk, recursion_mode = "conditional_mean_plugin"
  )

  mean_location <- lapply(path$mu_by_origin, function(x) {
    iqcf_v3_matrix_by_outer_draw(
      x, outer_draws, inner_paths, summary = "mean"
    )
  })
  predictive_quantile <- lapply(path$yrep_by_origin, function(x) {
    iqcf_v3_matrix_by_outer_draw(
      x, outer_draws, inner_paths, summary = "quantile",
      probability = probability
    )
  })
  pooled_predictive_quantile <- lapply(path$yrep_by_origin, function(x) {
    apply(x, 1L, stats::quantile, probs = probability,
          names = FALSE, type = 8)
  })

  mean_readout <- NULL
  if (isTRUE(include_mean_readout_state)) {
    mean_readout <- lapply(seq_along(origins), function(i) {
      matrix(NA_real_, nrow = horizon, ncol = outer_draws)
    })
    for (j in seq_len(outer_draws)) {
      one_draw <- iqcf_v3_subset_draws(draws, j)
      repeated_one <- iqcf_v3_repeat_draws(one_draw, inner_paths)
      ids <- (j - 1L) * noise_bank$max_inner_paths + seq_len(inner_paths)
      one_noise <- lapply(noise_bank$by_origin, function(origin) {
        lapply(origin, function(x) x[, ids, drop = FALSE])
      })
      one <- forecast_lattice.qdesn_fit(
        object, y_all = y_all, origins = origins, H = horizon,
        nd = inner_paths, xreg_all = xreg_all, keep_origin_draws = TRUE,
        draws = repeated_one, noise_draws_by_origin = one_noise,
        build_mix = FALSE, seed = seed, chunk = chunk,
        recursion_mode = "posterior_predictive_mean_readout_state"
      )
      for (i in seq_along(origins)) {
        mean_readout[[i]][, j] <- one$mu_by_origin[[i]][, 1L]
      }
    }
  }

  structure(list(
    schema_version = iqcf_v3_schema,
    origins = origins, horizon = horizon, probability = probability,
    outer_draws = outer_draws, inner_paths = inner_paths,
    source_draw_index = as.integer(
      draws$source_draw_index %||% seq_len(outer_draws)
    ),
    oracle_location = list(
      conditional_location_plugin = plugin$mu_by_origin,
      mean_conditional_location = mean_location,
      mean_readout_state = mean_readout
    ),
    predictive_quantile_by_draw = predictive_quantile,
    pooled_predictive_quantile = pooled_predictive_quantile,
    metadata = list(
      teacher_forced_between_origins = TRUE,
      recursive_within_origin = TRUE,
      parameter_draw_static_within_path = TRUE,
      inner_innovations_propagated = TRUE,
      predictive_mixture_operator = "pooled_outer_draw_inner_path_quantile",
      quantile_type = 8L,
      noise_seed = as.integer(seed)
    )
  ), class = "iqcf_v3_nested_lattice")
}

iqcf_v3_pair_frame <- function(origins, horizon, source_offset = 8110L) {
  rows <- lapply(seq_along(origins), function(i) {
    data.frame(
      origin_index = i,
      source_origin = as.integer(origins[[i]]) + as.integer(source_offset),
      lead = seq_len(horizon),
      source_target = as.integer(origins[[i]]) + seq_len(horizon) +
        as.integer(source_offset),
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}

iqcf_v3_check_loss <- function(y, q, probability) {
  error <- y - q
  error * (probability - as.numeric(error < 0))
}

iqcf_v3_training_quantile_baseline <- function(
  source, fit_rows, origins, horizon, probability, source_offset = 8110L
) {
  required <- c("t", "y", "q_target")
  if (!all(required %in% names(source)) || length(fit_rows) != nrow(source) ||
      !any(fit_rows)) {
    stop("Baseline source or fitting rows are invalid.", call. = FALSE)
  }
  pairs <- iqcf_v3_pair_frame(origins, horizon, source_offset)
  target_index <- match(pairs$source_target, source$t)
  if (anyNA(target_index)) {
    stop("Baseline forecast targets do not align with source.", call. = FALSE)
  }
  constant <- stats::quantile(
    source$y[fit_rows], probs = probability, names = FALSE, type = 8
  )
  truth <- source$q_target[target_index]
  observed <- source$y[target_index]
  data.frame(
    estimator = "training_empirical_quantile_baseline",
    estimand = "benchmark",
    aggregation = "constant_training_empirical_quantile",
    forecast_qtrue_mae = mean(abs(constant - truth)),
    forecast_qtrue_rmse = sqrt(mean((constant - truth)^2)),
    forecast_check_loss = mean(iqcf_v3_check_loss(
      observed, constant, probability
    )),
    baseline_quantile = as.numeric(constant),
    stringsAsFactors = FALSE
  )
}

iqcf_v3_response_transport <- function(source, fit_rows) {
  if (!is.data.frame(source) || !"y" %in% names(source) ||
      length(fit_rows) != nrow(source) || !any(fit_rows)) {
    stop("Response transport source or fitting rows are invalid.", call. = FALSE)
  }
  center <- mean(source$y[fit_rows])
  scale <- stats::sd(source$y[fit_rows])
  if (!is.finite(center) || !is.finite(scale) || scale <= 1e-12) {
    stop("Response transport is nonfinite or degenerate.", call. = FALSE)
  }
  list(
    center = as.numeric(center), scale = as.numeric(scale),
    fit_row_count = sum(fit_rows),
    fit_t_start = if ("t" %in% names(source)) min(source$t[fit_rows]) else NA,
    fit_t_end = if ("t" %in% names(source)) max(source$t[fit_rows]) else NA,
    forward = function(x) (x - center) / scale,
    inverse = function(x) x * scale + center,
    method = "training_only_positive_affine_mean_sd"
  )
}

iqcf_v3_inverse_lattice <- function(lattice, transport) {
  if (!inherits(lattice, "iqcf_v3_nested_lattice") ||
      !is.list(transport) || !is.function(transport$inverse)) {
    stop("Lattice or response transport is invalid.", call. = FALSE)
  }
  transform_list <- function(x) {
    if (is.null(x)) return(NULL)
    lapply(x, transport$inverse)
  }
  lattice$oracle_location <- lapply(
    lattice$oracle_location, transform_list
  )
  lattice$predictive_quantile_by_draw <- transform_list(
    lattice$predictive_quantile_by_draw
  )
  lattice$pooled_predictive_quantile <- transform_list(
    lattice$pooled_predictive_quantile
  )
  lattice$metadata$response_transport <- list(
    method = transport$method, center = transport$center,
    scale = transport$scale, inverse_transform_applied = TRUE
  )
  lattice
}

iqcf_v3_score_nested_lattice <- function(lattice, source, source_offset = 8110L) {
  if (!inherits(lattice, "iqcf_v3_nested_lattice")) {
    stop("lattice is not a corrected-forecast lattice.", call. = FALSE)
  }
  required <- c("t", "y", "q_target")
  if (!all(required %in% names(source))) {
    stop("source must contain t, y, and q_target.", call. = FALSE)
  }
  pairs <- iqcf_v3_pair_frame(
    lattice$origins, lattice$horizon, source_offset
  )
  target_index <- match(pairs$source_target, source$t)
  if (anyNA(target_index)) stop("Forecast targets do not align with source.",
                                call. = FALSE)
  pairs$q_target <- as.numeric(source$q_target[target_index])
  pairs$observed <- as.numeric(source$y[target_index])
  probability <- lattice$probability
  outer_draws <- lattice$outer_draws

  estimator_draws <- lattice$oracle_location
  estimator_draws$mean_readout_state <-
    estimator_draws$mean_readout_state %||% NULL
  estimator_draws$predictive_quantile_by_draw <-
    lattice$predictive_quantile_by_draw
  estimator_draws <- estimator_draws[!vapply(estimator_draws, is.null,
                                              logical(1L))]

  draw_rows <- list()
  point_rows <- list()
  path_rows <- list()
  k <- 0L
  for (estimator in names(estimator_draws)) {
    matrices <- estimator_draws[[estimator]]
    flat <- do.call(rbind, matrices)
    if (!identical(dim(flat), c(nrow(pairs), outer_draws))) {
      stop("Estimator draw matrix is not aligned to forecast pairs.",
           call. = FALSE)
    }
    is_predictive <- identical(estimator, "predictive_quantile_by_draw")
    point <- rowMeans(flat)
    for (j in seq_len(outer_draws)) {
      q <- flat[, j]
      k <- k + 1L
      draw_rows[[k]] <- data.frame(
        estimator = estimator,
        estimand = if (is_predictive) "marginal_predictive_quantile" else
          "oracle_location_path",
        posterior_draw = j,
        posterior_source_draw_index = lattice$source_draw_index[[j]],
        forecast_qtrue_mae = mean(abs(q - pairs$q_target)),
        forecast_qtrue_rmse = sqrt(mean((q - pairs$q_target)^2)),
        forecast_check_loss = mean(iqcf_v3_check_loss(
          pairs$observed, q, probability
        )), stringsAsFactors = FALSE
      )
    }
    point_rows[[estimator]] <- data.frame(
      estimator = estimator,
      estimand = if (is_predictive) "marginal_predictive_quantile" else
        "oracle_location_path",
      aggregation = "posterior_mean_of_draw_specific_estimand",
      forecast_qtrue_mae = mean(abs(point - pairs$q_target)),
      forecast_qtrue_rmse = sqrt(mean((point - pairs$q_target)^2)),
      forecast_check_loss = mean(iqcf_v3_check_loss(
        pairs$observed, point, probability
      )), stringsAsFactors = FALSE
    )
    path_rows[[estimator]] <- cbind(
      pairs,
      data.frame(
        estimator = estimator,
        estimand = if (is_predictive) "marginal_predictive_quantile" else
          "oracle_location_path",
        point_prediction = point,
        posterior_sd = apply(flat, 1L, stats::sd),
        stringsAsFactors = FALSE
      )
    )
  }

  pooled <- unlist(lattice$pooled_predictive_quantile, use.names = FALSE)
  if (length(pooled) != nrow(pairs)) {
    stop("Pooled predictive quantile is not aligned to forecast pairs.",
         call. = FALSE)
  }
  point_rows$posterior_predictive_quantile_pooled <- data.frame(
    estimator = "posterior_predictive_quantile_pooled",
    estimand = "marginal_predictive_quantile",
    aggregation = "quantile_of_pooled_posterior_predictive_mixture",
    forecast_qtrue_mae = mean(abs(pooled - pairs$q_target)),
    forecast_qtrue_rmse = sqrt(mean((pooled - pairs$q_target)^2)),
    forecast_check_loss = mean(iqcf_v3_check_loss(
      pairs$observed, pooled, probability
    )), stringsAsFactors = FALSE
  )
  path_rows$posterior_predictive_quantile_pooled <- cbind(
    pairs,
    data.frame(
      estimator = "posterior_predictive_quantile_pooled",
      estimand = "marginal_predictive_quantile",
      point_prediction = pooled,
      posterior_sd = NA_real_, stringsAsFactors = FALSE
    )
  )

  paths <- do.call(rbind, path_rows)
  paths$absolute_oracle_error <- abs(paths$point_prediction - paths$q_target)
  paths$squared_oracle_error <- (paths$point_prediction - paths$q_target)^2
  paths$check_loss <- iqcf_v3_check_loss(
    paths$observed, paths$point_prediction, probability
  )
  lead_profile <- aggregate(
    cbind(absolute_oracle_error, squared_oracle_error, check_loss) ~
      estimator + estimand + lead,
    data = paths, FUN = mean
  )
  lead_profile$oracle_rmse <- sqrt(lead_profile$squared_oracle_error)
  origin_profile <- aggregate(
    cbind(absolute_oracle_error, squared_oracle_error, check_loss) ~
      estimator + estimand + source_origin,
    data = paths, FUN = mean
  )
  origin_profile$oracle_rmse <- sqrt(origin_profile$squared_oracle_error)
  list(
    point_metrics = do.call(rbind, point_rows),
    metric_draws = do.call(rbind, draw_rows),
    origin_lead = paths,
    lead_profile = lead_profile,
    origin_profile = origin_profile
  )
}

iqcf_v3_origin_block_intervals <- function(origin_lead, replicates = 1000L,
                                            seed = 1L) {
  required <- c("estimator", "source_origin", "absolute_oracle_error",
                "squared_oracle_error", "check_loss")
  if (!all(required %in% names(origin_lead))) {
    stop("origin_lead lacks required scoring columns.", call. = FALSE)
  }
  replicates <- as.integer(replicates)
  if (replicates < 100L) stop("At least 100 block replicates are required.",
                              call. = FALSE)
  set.seed(as.integer(seed))
  rows <- lapply(split(origin_lead, origin_lead$estimator), function(x) {
    origins <- unique(x$source_origin)
    samples <- replicate(replicates, {
      picked <- sample(origins, length(origins), replace = TRUE)
      pieces <- lapply(picked, function(origin) {
        x[x$source_origin == origin, , drop = FALSE]
      })
      z <- do.call(rbind, pieces)
      c(
        forecast_qtrue_mae = mean(z$absolute_oracle_error),
        forecast_qtrue_rmse = sqrt(mean(z$squared_oracle_error)),
        forecast_check_loss = mean(z$check_loss)
      )
    })
    data.frame(
      estimator = x$estimator[[1L]],
      metric = rownames(samples),
      mean = rowMeans(samples),
      lower = apply(samples, 1L, stats::quantile, probs = 0.025,
                    names = FALSE, type = 8),
      upper = apply(samples, 1L, stats::quantile, probs = 0.975,
                    names = FALSE, type = 8),
      uncertainty_unit = "forecast_origin_block",
      replicates = replicates, stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}

iqcf_v3_ar1_quantile_contract <- function(phi, innovation_sd, probability,
                                           horizon = 2L, initial = 0) {
  phi <- as.numeric(phi)
  innovation_sd <- as.numeric(innovation_sd)
  probability <- as.numeric(probability)
  horizon <- as.integer(horizon)
  if (abs(phi) >= 1 || innovation_sd <= 0 || probability <= 0 ||
      probability >= 1 || horizon < 1L) {
    stop("Invalid Gaussian AR(1) contract arguments.", call. = FALSE)
  }
  z <- stats::qnorm(probability)
  plugin <- phi^horizon * initial +
    innovation_sd * z * sum(phi^(0:(horizon - 1L)))
  marginal_sd <- innovation_sd * sqrt(sum(phi^(2 * (0:(horizon - 1L)))))
  marginal <- phi^horizon * initial + marginal_sd * z
  data.frame(
    horizon = horizon, probability = probability,
    recursive_one_step_quantile_plugin = plugin,
    marginal_predictive_quantile = marginal,
    difference = plugin - marginal, stringsAsFactors = FALSE
  )
}

iqcf_v3_tau0_reference <- function(readout_dimension, effective_sample_size,
                                    sigma, target_nonzero) {
  readout_dimension <- as.integer(readout_dimension)
  effective_sample_size <- as.numeric(effective_sample_size)
  sigma <- as.numeric(sigma)
  target_nonzero <- as.numeric(target_nonzero)
  shrinkable <- readout_dimension - 1L
  if (shrinkable < 2L || effective_sample_size <= 0 || sigma <= 0 ||
      target_nonzero <= 0 || target_nonzero >= shrinkable) {
    stop("Invalid dimension-aware tau0 inputs.", call. = FALSE)
  }
  target_nonzero / (shrinkable - target_nonzero) *
    sigma / sqrt(effective_sample_size)
}

iqcf_v3_tau0_arms <- function(reference, multipliers = c(0.1, 1, 10),
                               bounds = c(3e-9, 100)) {
  reference <- as.numeric(reference)
  multipliers <- as.numeric(multipliers)
  bounds <- as.numeric(bounds)
  if (reference <= 0 || any(multipliers <= 0) || length(bounds) != 2L ||
      bounds[[1L]] <= 0 || bounds[[2L]] <= bounds[[1L]]) {
    stop("Invalid tau0 arm inputs.", call. = FALSE)
  }
  unique(pmax(bounds[[1L]], pmin(bounds[[2L]], reference * multipliers)))
}

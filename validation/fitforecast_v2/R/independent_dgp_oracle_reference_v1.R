idor_v1_schema <- "independent_dgp_oracle_reference_v1"
idor_v1_scenario <- "dlm_constV_p90_m0amp_highnoise_steepertrend_v2_TTmain10000_fitforecast"
idor_v1_families <- c("normal", "laplace", "gausmix")
idor_v1_taus <- c(0.05, 0.25, 0.50)
idor_v1_metric_roles <- c("fit_rmse", "forecast_mae", "forecast_check")

idor_v1_default_source_root <- function() {
  Sys.getenv(
    "IND_DGP_ORACLE_SOURCE_ROOT",
    unset = file.path(
      "/data/jaguir26/local/src/shared_dynamic_fit_forecast_validation/sources",
      idor_v1_scenario
    )
  )
}

idor_v1_family_contract <- function(family) {
  family <- match.arg(as.character(family), idor_v1_families)
  switch(
    family,
    normal = list(sigma = 10),
    laplace = list(scale = 10),
    gausmix = list(
      weights = c(0.1, 0.9),
      means = c(0, 1),
      sds = c(0.5, 15)
    )
  )
}

idor_v1_tau_label <- function(tau) {
  gsub("[.]", "p", sprintf("%.2f", as.numeric(tau)), fixed = FALSE)
}

idor_v1_check_loss <- function(residual, tau) {
  residual <- as.numeric(residual)
  tau <- as.numeric(tau)[[1L]]
  residual * (tau - (residual < 0))
}

idor_v1_density <- function(x, family) {
  family <- match.arg(as.character(family), idor_v1_families)
  cfg <- idor_v1_family_contract(family)
  switch(
    family,
    normal = stats::dnorm(x, mean = 0, sd = cfg$sigma),
    laplace = exp(-abs(x) / cfg$scale) / (2 * cfg$scale),
    gausmix = cfg$weights[[1L]] * stats::dnorm(
      x, cfg$means[[1L]], cfg$sds[[1L]]
    ) + cfg$weights[[2L]] * stats::dnorm(
      x, cfg$means[[2L]], cfg$sds[[2L]]
    )
  )
}

idor_v1_cdf <- function(x, family) {
  family <- match.arg(as.character(family), idor_v1_families)
  cfg <- idor_v1_family_contract(family)
  switch(
    family,
    normal = stats::pnorm(x, mean = 0, sd = cfg$sigma),
    laplace = ifelse(
      x < 0,
      0.5 * exp(x / cfg$scale),
      1 - 0.5 * exp(-x / cfg$scale)
    ),
    gausmix = cfg$weights[[1L]] * stats::pnorm(
      x, cfg$means[[1L]], cfg$sds[[1L]]
    ) + cfg$weights[[2L]] * stats::pnorm(
      x, cfg$means[[2L]], cfg$sds[[2L]]
    )
  )
}

idor_v1_raw_quantile <- function(family, tau) {
  family <- match.arg(as.character(family), idor_v1_families)
  tau <- as.numeric(tau)[[1L]]
  cfg <- idor_v1_family_contract(family)
  if (identical(family, "normal")) {
    return(cfg$sigma * stats::qnorm(tau))
  }
  if (identical(family, "laplace")) {
    return(if (tau <= 0.5) {
      cfg$scale * log(2 * tau)
    } else {
      -cfg$scale * log(2 * (1 - tau))
    })
  }
  bound <- max(abs(cfg$means)) + 30 * max(cfg$sds)
  stats::uniroot(
    function(x) idor_v1_cdf(x, family) - tau,
    lower = -bound,
    upper = bound,
    tol = 1e-13
  )$root
}

idor_v1_normal_component_check <- function(q, mean, sd, tau) {
  a <- (q - mean) / sd
  lower <- (q - mean) * stats::pnorm(a) + sd * stats::dnorm(a)
  upper <- (mean - q) * (1 - stats::pnorm(a)) + sd * stats::dnorm(a)
  tau * upper + (1 - tau) * lower
}

idor_v1_expected_check_analytic <- function(family, tau) {
  family <- match.arg(as.character(family), idor_v1_families)
  tau <- as.numeric(tau)[[1L]]
  cfg <- idor_v1_family_contract(family)
  if (identical(family, "normal")) {
    return(cfg$sigma * stats::dnorm(stats::qnorm(tau)))
  }
  if (identical(family, "laplace")) {
    tail_probability <- min(tau, 1 - tau)
    return(cfg$scale * tail_probability * (1 - log(2 * tail_probability)))
  }
  q <- idor_v1_raw_quantile(family, tau)
  sum(vapply(seq_along(cfg$weights), function(i) {
    cfg$weights[[i]] * idor_v1_normal_component_check(
      q = q,
      mean = cfg$means[[i]],
      sd = cfg$sds[[i]],
      tau = tau
    )
  }, numeric(1L)))
}

idor_v1_expected_check_numerical <- function(family, tau) {
  family <- match.arg(as.character(family), idor_v1_families)
  tau <- as.numeric(tau)[[1L]]
  q <- idor_v1_raw_quantile(family, tau)
  lower <- stats::integrate(
    function(x) (q - x) * idor_v1_density(x, family),
    lower = -Inf,
    upper = q,
    rel.tol = 1e-11,
    abs.tol = 1e-12,
    subdivisions = 1000L
  )$value
  upper <- stats::integrate(
    function(x) (x - q) * idor_v1_density(x, family),
    lower = q,
    upper = Inf,
    rel.tol = 1e-11,
    abs.tol = 1e-12,
    subdivisions = 1000L
  )$value
  (1 - tau) * lower + tau * upper
}

idor_v1_formula <- function(metric_role, family) {
  if (metric_role %in% c("fit_rmse", "forecast_mae")) {
    return("Oracle conditional-quantile path equals the DGP path; error is exactly zero.")
  }
  switch(
    family,
    normal = "sigma * phi(Phi^{-1}(tau)), with sigma = 10",
    laplace = "b * u * {1 - log(2u)}, with b = 10 and u = min(tau, 1-tau)",
    gausmix = paste0(
      "Weighted normal partial moments at the mixture tau-quantile; ",
      "weights = (0.1,0.9), means = (0,1), sds = (0.5,15)"
    )
  )
}

idor_v1_forecast_grid <- function() {
  origins <- seq.int(9000L, 9999L, by = 30L)
  grid <- expand.grid(
    forecast_origin_source_index = origins,
    forecast_lead = seq_len(30L),
    KEEP.OUT.ATTRS = FALSE
  )
  grid$target_source_index <- with(
    grid,
    forecast_origin_source_index + forecast_lead
  )
  grid <- grid[
    grid$target_source_index >= 9001L & grid$target_source_index <= 10000L,
    ,
    drop = FALSE
  ]
  grid <- grid[order(
    grid$forecast_origin_source_index,
    grid$forecast_lead
  ), , drop = FALSE]
  grid$origin_sequence_id <- match(
    grid$forecast_origin_source_index,
    unique(grid$forecast_origin_source_index)
  )
  rownames(grid) <- NULL
  grid
}

idor_v1_series_path <- function(source_root, family, tau) {
  file.path(
    source_root,
    family,
    paste0("tau_", idor_v1_tau_label(tau)),
    "series_wide.csv"
  )
}

idor_v1_portable_series_path <- function(family, tau) {
  paste0(
    "external-workspace://shared_dynamic_fit_forecast_validation/sources/",
    idor_v1_scenario,
    "/", family,
    "/tau_", idor_v1_tau_label(tau),
    "/series_wide.csv"
  )
}

idor_v1_build <- function(source_root = idor_v1_default_source_root()) {
  source_root <- normalizePath(source_root, winslash = "/", mustWork = TRUE)
  grid <- idor_v1_forecast_grid()
  source_rows <- list()
  ledger_rows <- list()
  row_i <- 0L
  max_path_difference <- 0
  max_eps_difference <- 0

  for (family in idor_v1_families) {
    cfg <- idor_v1_family_contract(family)
    for (tau in idor_v1_taus) {
      path <- idor_v1_series_path(source_root, family, tau)
      if (!file.exists(path)) {
        stop(sprintf("Missing frozen DGP series: %s", path), call. = FALSE)
      }
      series <- utils::read.csv(path, stringsAsFactors = FALSE)
      required <- c("t", "y", "mu", "q_target", "eps")
      if (!all(required %in% names(series))) {
        stop(sprintf("DGP series is missing required columns: %s", path), call. = FALSE)
      }
      target_index <- match(grid$target_source_index, as.integer(series$t))
      if (anyNA(target_index)) {
        stop(sprintf("Forecast targets are absent from DGP series: %s", path), call. = FALSE)
      }
      forecast <- series[target_index, , drop = FALSE]
      residual <- as.numeric(forecast$y - forecast$q_target)
      expected <- idor_v1_expected_check_analytic(family, tau)
      numerical <- idor_v1_expected_check_numerical(family, tau)
      realized <- mean(idor_v1_check_loss(residual, tau))
      q_raw <- idor_v1_raw_quantile(family, tau)
      max_path_difference <- max(
        max_path_difference,
        max(abs(as.numeric(series$q_target) - as.numeric(series$mu)))
      )
      max_eps_difference <- max(
        max_eps_difference,
        max(abs(as.numeric(series$eps) - (as.numeric(series$y) - as.numeric(series$mu))))
      )
      source_rows[[length(source_rows) + 1L]] <- data.frame(
        schema_version = idor_v1_schema,
        scenario_id = idor_v1_scenario,
        family = family,
        tau = tau,
        source_series_path = idor_v1_portable_series_path(family, tau),
        source_series_sha256 = ffv2_file_sha256(path),
        source_rows = nrow(series),
        raw_quantile_shift = q_raw,
        cdf_at_raw_quantile = idor_v1_cdf(q_raw, family),
        expected_oracle_check_loss = expected,
        numerical_oracle_check_loss = numerical,
        analytic_numerical_abs_error = abs(expected - numerical),
        realized_oracle_check_loss = realized,
        realized_minus_expected = realized - expected,
        normal_sigma = if (identical(family, "normal")) cfg$sigma else NA_real_,
        laplace_scale = if (identical(family, "laplace")) cfg$scale else NA_real_,
        mixture_weights = if (identical(family, "gausmix")) {
          paste(cfg$weights, collapse = ";")
        } else "",
        mixture_means = if (identical(family, "gausmix")) {
          paste(cfg$means, collapse = ";")
        } else "",
        mixture_sds = if (identical(family, "gausmix")) {
          paste(cfg$sds, collapse = ";")
        } else "",
        stringsAsFactors = FALSE
      )

      for (metric_role in idor_v1_metric_roles) {
        row_i <- row_i + 1L
        is_check <- identical(metric_role, "forecast_check")
        ledger_rows[[row_i]] <- data.frame(
          schema_version = idor_v1_schema,
          scenario_id = idor_v1_scenario,
          family = family,
          tau = tau,
          metric_role = metric_role,
          metric_name = switch(
            metric_role,
            fit_rmse = "fit_qtrue_rmse",
            forecast_mae = "forecast_qtrue_mae_H1000",
            forecast_check = "forecast_check_loss_H1000"
          ),
          plot_reference_type = if (is_check) {
            "population_expected_dgp_oracle"
          } else {
            "exact_dgp_oracle"
          },
          plot_reference_value = if (is_check) expected else 0,
          expected_reference_value = if (is_check) expected else 0,
          realized_reference_value = if (is_check) realized else 0,
          formula = idor_v1_formula(metric_role, family),
          source_series_sha256 = ffv2_file_sha256(path),
          train_start_source_index = 8501L,
          train_end_source_index = 9000L,
          forecast_start_source_index = 9001L,
          forecast_end_source_index = 10000L,
          forecast_max_lead = 30L,
          forecast_origin_stride = 30L,
          forecast_origins = length(unique(grid$forecast_origin_source_index)),
          forecast_pairs = nrow(grid),
          stringsAsFactors = FALSE
        )
      }
    }
  }

  source_registry <- do.call(rbind, source_rows)
  reference_ledger <- do.call(rbind, ledger_rows)
  checks <- data.frame(
    check_id = c(
      "source_cells_9",
      "reference_rows_27",
      "forecast_grid_rows_1000",
      "forecast_origins_34",
      "forecast_targets_unique",
      "forecast_targets_exact_block",
      "oracle_path_equals_mu",
      "eps_equals_y_minus_mu",
      "quantile_cdf_matches_tau",
      "analytic_matches_numerical",
      "path_metric_oracles_zero",
      "check_oracles_positive_finite",
      "source_hashes_complete"
    ),
    pass = c(
      nrow(source_registry) == 9L,
      nrow(reference_ledger) == 27L,
      nrow(grid) == 1000L,
      length(unique(grid$forecast_origin_source_index)) == 34L,
      !anyDuplicated(grid$target_source_index),
      identical(sort(grid$target_source_index), 9001:10000),
      max_path_difference <= 1e-12,
      max_eps_difference <= 1e-10,
      max(abs(source_registry$cdf_at_raw_quantile - source_registry$tau)) <= 1e-10,
      max(source_registry$analytic_numerical_abs_error) <= 1e-8,
      all(reference_ledger$plot_reference_value[
        reference_ledger$metric_role != "forecast_check"
      ] == 0),
      all(is.finite(source_registry$expected_oracle_check_loss) &
            source_registry$expected_oracle_check_loss > 0),
      all(nzchar(source_registry$source_series_sha256))
    ),
    stringsAsFactors = FALSE
  )
  checks$detail <- c(
    sprintf("observed=%d", nrow(source_registry)),
    sprintf("observed=%d", nrow(reference_ledger)),
    sprintf("observed=%d", nrow(grid)),
    sprintf("observed=%d", length(unique(grid$forecast_origin_source_index))),
    sprintf("duplicates=%d", anyDuplicated(grid$target_source_index)),
    sprintf("range=%d:%d", min(grid$target_source_index), max(grid$target_source_index)),
    sprintf("max_abs_error=%.3g", max_path_difference),
    sprintf("max_abs_error=%.3g", max_eps_difference),
    sprintf(
      "max_abs_error=%.3g",
      max(abs(source_registry$cdf_at_raw_quantile - source_registry$tau))
    ),
    sprintf("max_abs_error=%.3g", max(source_registry$analytic_numerical_abs_error)),
    "fit RMSE and forecast MAE oracle values are exactly zero",
    sprintf(
      "range=%.8f:%.8f",
      min(source_registry$expected_oracle_check_loss),
      max(source_registry$expected_oracle_check_loss)
    ),
    sprintf("complete=%d/%d", sum(nzchar(source_registry$source_series_sha256)), nrow(source_registry))
  )

  list(
    source_registry = source_registry,
    reference_ledger = reference_ledger,
    forecast_grid = grid,
    checks = checks
  )
}

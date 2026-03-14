`%||%` <- function(a, b) if (is.null(a)) b else a

.qdesn_validation_or <- function(a, b) if (is.null(a)) b else a

.qdesn_validation_require_namespace <- function(pkg) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    stop(sprintf("Package '%s' is required for the Q-DESN validation framework.", pkg), call. = FALSE)
  }
}

.qdesn_validation_repo_root <- function(repo_root = NULL) {
  if (!is.null(repo_root)) {
    return(normalizePath(repo_root, winslash = "/", mustWork = TRUE))
  }
  tryCatch(
    normalizePath(system("git rev-parse --show-toplevel", intern = TRUE), winslash = "/", mustWork = TRUE),
    error = function(...) normalizePath(".", winslash = "/", mustWork = TRUE)
  )
}

.qdesn_validation_resolve_path <- function(path, repo_root = NULL, must_work = TRUE) {
  if (is.null(path) || !nzchar(path)) return(NULL)
  if (grepl("^/", path)) {
    return(normalizePath(path, winslash = "/", mustWork = must_work))
  }
  normalizePath(file.path(.qdesn_validation_repo_root(repo_root), path), winslash = "/", mustWork = must_work)
}

.qdesn_validation_dir_create <- function(path) {
  dir.create(path, recursive = TRUE, showWarnings = FALSE)
  invisible(path)
}

.qdesn_validation_write_json <- function(path, x) {
  .qdesn_validation_require_namespace("jsonlite")
  .qdesn_validation_dir_create(dirname(path))
  jsonlite::write_json(x, path, pretty = TRUE, auto_unbox = TRUE, null = "null")
  invisible(path)
}

.qdesn_validation_read_json_if_exists <- function(path) {
  .qdesn_validation_require_namespace("jsonlite")
  if (!file.exists(path)) return(NULL)
  jsonlite::fromJSON(path, simplifyVector = TRUE)
}

.qdesn_validation_write_lines <- function(path, lines) {
  .qdesn_validation_dir_create(dirname(path))
  writeLines(as.character(lines), con = path, useBytes = TRUE)
  invisible(path)
}

.qdesn_validation_prob_label <- function(x, digits = 2L) {
  gsub("\\.", "p", format(as.numeric(x)[1L], nsmall = digits, digits = digits + 2L, trim = TRUE))
}

.qdesn_validation_prob_token <- function(x) {
  sprintf("%03d", as.integer(round(as.numeric(x)[1L] * 100)))
}

.qdesn_validation_as_flag <- function(x, default = TRUE) {
  if (is.null(x) || length(x) == 0L || is.na(x[[1L]])) return(default)
  isTRUE(x)
}

.qdesn_validation_git_sha <- function(repo_root = NULL) {
  root <- .qdesn_validation_repo_root(repo_root)
  sha <- tryCatch(
    system2("git", c("-C", root, "rev-parse", "--short", "HEAD"), stdout = TRUE, stderr = FALSE),
    error = function(...) character(0)
  )
  if (!length(sha)) return(NA_character_)
  trimws(as.character(sha[[1L]]))
}

qdesn_validation_load_defaults <- function(path = file.path("config", "validation", "qdesn_mcmc_pilot_defaults.yaml"),
                                           repo_root = NULL) {
  .qdesn_validation_require_namespace("yaml")
  yaml_path <- .qdesn_validation_resolve_path(path, repo_root = repo_root, must_work = TRUE)
  out <- yaml::read_yaml(yaml_path)
  if (!is.list(out)) {
    stop("Validation defaults YAML must parse to a list.", call. = FALSE)
  }
  out
}

qdesn_validation_load_grid <- function(path = file.path("config", "validation", "qdesn_mcmc_pilot_grid.csv"),
                                       repo_root = NULL) {
  grid_path <- .qdesn_validation_resolve_path(path, repo_root = repo_root, must_work = TRUE)
  out <- utils::read.csv(grid_path, stringsAsFactors = FALSE)
  if (!nrow(out)) {
    stop("Validation grid CSV is empty.", call. = FALSE)
  }
  out
}

qdesn_validation_build_root_id <- function(root_spec) {
  sprintf(
    "scenario-%s__tau-%s__prior-%s__seed-%s__res-%s",
    as.character(root_spec$scenario)[1L],
    .qdesn_validation_prob_label(root_spec$tau),
    as.character(root_spec$beta_prior_type)[1L],
    as.integer(root_spec$seed)[1L],
    as.character(root_spec$reservoir_profile)[1L]
  )
}

qdesn_validation_enrich_root_spec <- function(root_spec, defaults) {
  pilot_cfg <- defaults$pilot %||% list()
  scenario <- as.character(root_spec$scenario %||% pilot_cfg$scenario %||% "toy_sine_small")[1L]
  tau <- as.numeric(root_spec$tau %||% pilot_cfg$tau %||% 0.25)[1L]
  beta_prior_type <- tolower(as.character(root_spec$beta_prior_type %||% pilot_cfg$beta_prior_type %||% "ridge")[1L])
  seed <- as.integer(root_spec$seed %||% pilot_cfg$seed %||% 123L)[1L]
  reservoir_profile <- as.character(root_spec$reservoir_profile %||% pilot_cfg$reservoir_profile %||% "tiny_d1_n8")[1L]
  enabled <- .qdesn_validation_as_flag(root_spec$enabled %||% pilot_cfg$enabled, default = TRUE)

  if (!beta_prior_type %in% c("ridge", "rhs")) {
    stop(sprintf("Unsupported beta_prior_type '%s'.", beta_prior_type), call. = FALSE)
  }
  if (!is.finite(tau) || tau <= 0 || tau >= 1) {
    stop("Validation tau must lie in (0, 1).", call. = FALSE)
  }
  if (!is.finite(seed)) {
    stop("Validation seed must be finite.", call. = FALSE)
  }

  out <- list(
    scenario = scenario,
    tau = tau,
    beta_prior_type = beta_prior_type,
    seed = as.integer(seed),
    reservoir_profile = reservoir_profile,
    enabled = enabled
  )
  out$root_id <- as.character(root_spec$root_id %||% qdesn_validation_build_root_id(out))[1L]
  out
}

qdesn_validation_generate_toy_series <- function(scenario = "toy_sine_small",
                                                 seed = 123L,
                                                 p_grid = seq(0.01, 0.99, by = 0.01),
                                                 scenario_cfg = list()) {
  scenario <- as.character(scenario)[1L]
  seed <- as.integer(seed)[1L]
  p_grid <- sort(unique(as.numeric(p_grid)))
  p_grid <- p_grid[is.finite(p_grid) & p_grid > 0 & p_grid < 1]
  if (!length(p_grid)) {
    stop("p_grid must contain at least one probability in (0, 1).", call. = FALSE)
  }

  T_use <- as.integer(scenario_cfg$T_use %||% 96L)[1L]
  n_train <- as.integer(scenario_cfg$n_train %||% max(2L, T_use - 18L))[1L]
  t <- seq_len(T_use)
  set.seed(seed)

  if (identical(scenario, "toy_sine_small")) {
    amplitude <- as.numeric(scenario_cfg$amplitude %||% 0.7)[1L]
    period <- as.numeric(scenario_cfg$period %||% 12)[1L]
    noise_sd <- as.numeric(scenario_cfg$noise_sd %||% 0.12)[1L]
    phase <- as.numeric(scenario_cfg$phase %||% 0)[1L]
    mu <- amplitude * sin((2 * pi * (t + phase)) / period)
    y <- as.numeric(mu + stats::rnorm(T_use, sd = noise_sd))
    q_mat <- outer(mu, stats::qnorm(p_grid) * noise_sd, "+")
    scenario_meta <- list(
      name = scenario,
      amplitude = amplitude,
      period = period,
      noise_sd = noise_sd,
      phase = phase
    )
  } else {
    stop(sprintf("Unsupported toy validation scenario '%s'.", scenario), call. = FALSE)
  }

  long <- data.frame(
    t = rep(t, each = length(p_grid)),
    p = rep(p_grid, times = T_use),
    q = as.numeric(t(q_mat)),
    y = rep(y, each = length(p_grid)),
    mu = rep(mu, each = length(p_grid)),
    stringsAsFactors = FALSE
  )

  wide <- data.frame(
    t = t,
    y = y,
    mu = mu,
    stringsAsFactors = FALSE
  )
  for (j in seq_along(p_grid)) {
    nm <- paste0("q_", .qdesn_validation_prob_token(p_grid[[j]]))
    wide[[nm]] <- q_mat[, j]
  }

  split_summary <- data.frame(
    T_use = T_use,
    n_train = n_train,
    H_forecast = as.integer(T_use - n_train),
    stringsAsFactors = FALSE
  )

  list(
    long = long,
    wide = wide,
    split = split_summary,
    meta = c(
      list(
        scenario = scenario,
        seed = seed,
        p_grid = p_grid
      ),
      scenario_meta
    )
  )
}

.qdesn_validation_reservoir_cfg <- function(defaults, profile) {
  cfg <- (defaults$reservoir_profiles %||% list())[[profile]]
  if (is.null(cfg)) {
    stop(sprintf("Reservoir profile '%s' not found in validation defaults.", profile), call. = FALSE)
  }
  n_exact <- cfg[["n", exact = TRUE]]
  if (is.null(n_exact) && !is.null(cfg[["FALSE", exact = TRUE]])) {
    cfg[["n"]] <- cfg[["FALSE", exact = TRUE]]
    cfg[["FALSE"]] <- NULL
  }
  cfg$D <- as.integer(cfg[["D", exact = TRUE]] %||% 1L)[1L]
  cfg[["n"]] <- as.integer(unlist(cfg[["n", exact = TRUE]] %||% integer(0), use.names = FALSE))
  cfg$n_tilde <- as.integer(unlist(cfg[["n_tilde", exact = TRUE]] %||% integer(0), use.names = FALSE))
  cfg$m <- as.integer(cfg[["m", exact = TRUE]] %||% 4L)[1L]
  cfg$washout <- as.integer(cfg[["washout", exact = TRUE]] %||% 4L)[1L]
  cfg
}

.qdesn_validation_scenario_cfg <- function(defaults, scenario) {
  cfg <- ((defaults$toy %||% list())$scenarios %||% list())[[scenario]]
  if (is.null(cfg)) {
    stop(sprintf("Toy scenario '%s' not found in validation defaults.", scenario), call. = FALSE)
  }
  cfg
}

qdesn_validation_build_pipeline_cfg <- function(root_spec, defaults, method = c("vb", "mcmc")) {
  method <- match.arg(method)
  pipeline_cfg <- defaults$pipeline %||% list()
  infer_cfg <- pipeline_cfg$inference %||% list()
  scenario_cfg <- .qdesn_validation_scenario_cfg(defaults, root_spec$scenario)
  reservoir_cfg <- .qdesn_validation_reservoir_cfg(defaults, root_spec$reservoir_profile)

  forecast_cfg <- modifyList(list(
    mode = "origin",
    horizon = as.integer(scenario_cfg$T_use - scenario_cfg$n_train),
    train_last_window = min(18L, as.integer(scenario_cfg$n_train)),
    fore_last_window = min(18L, as.integer(scenario_cfg$T_use - scenario_cfg$n_train))
  ), pipeline_cfg$forecast %||% list())
  if (is.null(forecast_cfg$horizon) || !is.finite(as.numeric(forecast_cfg$horizon))) {
    forecast_cfg$horizon <- as.integer(scenario_cfg$T_use - scenario_cfg$n_train)
  }

  cfg <- list(
    pipeline = list(mode = "sim", verbose = isTRUE(pipeline_cfg$verbose %||% TRUE)),
    split = list(
      use_last = TRUE,
      T_use = as.integer(scenario_cfg$T_use),
      train_n = as.integer(scenario_cfg$n_train)
    ),
    p_vec = as.numeric(root_spec$tau),
    desn = reservoir_cfg,
    readout = modifyList(list(
      include_input = TRUE,
      reservoir_lags = 1L,
      input_position = "after_reservoir"
    ), pipeline_cfg$readout %||% list()),
    sampling = modifyList(list(nd_draws = 96L, chunk = 48L), pipeline_cfg$sampling %||% list()),
    forecast = forecast_cfg,
    synthesis = modifyList(list(
      isotonic = TRUE,
      rearrange = TRUE,
      grid_M = 151L,
      n_samp = 96L,
      seed = as.integer(root_spec$seed) + 1000L
    ), pipeline_cfg$synthesis %||% list()),
    diagnostics = modifyList(list(
      calibration = FALSE,
      pit = FALSE,
      scores = TRUE,
      lead_eval = FALSE,
      fan_charts = FALSE,
      plots = FALSE
    ), pipeline_cfg$diagnostics %||% list()),
    cpp = modifyList(list(
      use_postpred = FALSE,
      postpred_omp = FALSE,
      postpred_precompute = FALSE,
      postpred_threads = 1L
    ), pipeline_cfg$cpp %||% list()),
    outputs = modifyList(list(
      save = TRUE,
      keep_draws = FALSE,
      thesis_subset = FALSE
    ), pipeline_cfg$outputs %||% list()),
    inference = list(
      method = method,
      readout_scale = isTRUE(infer_cfg$readout_scale %||% TRUE)
    )
  )

  if (identical(method, "vb")) {
    cfg$inference$vb <- modifyList(list(), infer_cfg$vb %||% list())
    cfg$inference$vb$priors <- modifyList(list(), cfg$inference$vb$priors %||% list())
    cfg$inference$vb$priors$beta <- modifyList(list(type = root_spec$beta_prior_type), cfg$inference$vb$priors$beta %||% list())
    cfg$inference$vb$priors$beta$type <- root_spec$beta_prior_type
  } else {
    cfg$inference$mcmc <- modifyList(list(), infer_cfg$mcmc %||% list())
    cfg$inference$mcmc$priors <- modifyList(list(), cfg$inference$mcmc$priors %||% list())
    cfg$inference$mcmc$priors$beta <- modifyList(list(type = root_spec$beta_prior_type), cfg$inference$mcmc$priors$beta %||% list())
    cfg$inference$mcmc$priors$beta$type <- root_spec$beta_prior_type
  }

  cfg
}

.qdesn_validation_apply_thread_caps <- function(threads = 1L) {
  n_threads <- max(1L, as.integer(threads)[1L])
  Sys.setenv(
    OMP_NUM_THREADS = as.character(n_threads),
    OPENBLAS_NUM_THREADS = as.character(n_threads),
    MKL_NUM_THREADS = as.character(n_threads),
    VECLIB_MAXIMUM_THREADS = as.character(n_threads),
    NUMEXPR_NUM_THREADS = as.character(n_threads)
  )
  invisible(n_threads)
}

.qdesn_validation_extract_fit <- function(summary_obj) {
  if (is.null(summary_obj$forecast_objects)) return(NULL)
  fits_fc <- summary_obj$forecast_objects$fits_fc %||% list()
  if (!length(fits_fc)) return(NULL)
  fit_entry <- fits_fc[[1L]]
  if (is.null(fit_entry$fit_train$fit)) return(NULL)
  fit_entry$fit_train$fit
}

.qdesn_validation_extract_forecast_df <- function(summary_obj) {
  if (is.null(summary_obj$forecast_objects)) return(NULL)
  fits_fc <- summary_obj$forecast_objects$fits_fc %||% list()
  if (!length(fits_fc)) return(NULL)
  out <- fits_fc[[1L]]$df_pred_fc %||% NULL
  if (is.null(out)) return(NULL)
  as.data.frame(out, stringsAsFactors = FALSE)
}

.qdesn_validation_safe_acf1 <- function(x) {
  x <- as.numeric(x)
  x <- x[is.finite(x)]
  if (length(x) < 3L) return(NA_real_)
  out <- tryCatch(stats::acf(x, plot = FALSE, lag.max = 1L)$acf[2L], error = function(...) NA_real_)
  as.numeric(out)
}

.qdesn_validation_safe_ess <- function(x) {
  .qdesn_validation_require_namespace("coda")
  out <- tryCatch(coda::effectiveSize(coda::as.mcmc(as.numeric(x))), error = function(...) NA_real_)
  as.numeric(out)[1L]
}

.qdesn_validation_bind_rows <- function(rows) {
  rows <- rows[!vapply(rows, is.null, logical(1))]
  if (!length(rows)) return(data.frame(stringsAsFactors = FALSE))
  cols <- unique(unlist(lapply(rows, names), use.names = FALSE))
  rows2 <- lapply(rows, function(df) {
    miss <- setdiff(cols, names(df))
    for (nm in miss) df[[nm]] <- rep(NA, nrow(df))
    df[, cols, drop = FALSE]
  })
  do.call(rbind, rows2)
}

.qdesn_validation_write_df <- function(df, path) {
  .qdesn_validation_dir_create(dirname(path))
  utils::write.csv(df, path, row.names = FALSE)
  invisible(path)
}

.qdesn_validation_method_health <- function(method, root_spec, summary_obj) {
  fit <- .qdesn_validation_extract_fit(summary_obj)
  summary_row <- summary_obj$summary
  forecast_df <- .qdesn_validation_extract_forecast_df(summary_obj)
  pinball_tau <- NA_real_
  qhat_mae <- NA_real_
  qhat_bias <- NA_real_
  if (!is.null(forecast_df) && nrow(forecast_df) &&
      all(c("q_pred", "q_true", "y") %in% names(forecast_df))) {
    err_y <- as.numeric(forecast_df$y) - as.numeric(forecast_df$q_pred)
    p0 <- as.numeric(root_spec$tau)
    pinball_tau <- mean((p0 - (err_y < 0)) * err_y, na.rm = TRUE)
    qhat_mae <- mean(abs(as.numeric(forecast_df$q_pred) - as.numeric(forecast_df$q_true)), na.rm = TRUE)
    qhat_bias <- mean(as.numeric(forecast_df$q_pred) - as.numeric(forecast_df$q_true), na.rm = TRUE)
  }
  base <- data.frame(
    root_id = root_spec$root_id,
    scenario = root_spec$scenario,
    tau = as.numeric(root_spec$tau),
    beta_prior_type = root_spec$beta_prior_type,
    seed = as.integer(root_spec$seed),
    reservoir_profile = root_spec$reservoir_profile,
    method = method,
    status = as.character(summary_row$status[1L] %||% NA_character_),
    wall_seconds = as.numeric(summary_row$wall_seconds[1L] %||% NA_real_),
    total_stage_seconds = as.numeric(summary_row$total_stage_seconds[1L] %||% NA_real_),
    forecast_CRPS_mean = as.numeric(summary_row$forecast_CRPS_mean[1L] %||% NA_real_),
    forecast_PinballMean_mean = as.numeric(summary_row$forecast_PinballMean_mean[1L] %||% NA_real_),
    forecast_S_mean = as.numeric(summary_row$forecast_S_mean[1L] %||% NA_real_),
    forecast_qhat_mae = qhat_mae,
    forecast_pinball_tau = pinball_tau,
    forecast_qhat_bias = qhat_bias,
    stringsAsFactors = FALSE
  )
  if (is.null(fit)) {
    base$fit_class <- NA_character_
    base$fit_runtime_seconds <- NA_real_
    base$finite_ok <- FALSE
    base$domain_ok <- FALSE
    return(base)
  }

  if (inherits(fit, "exal_vb")) {
    gamma_trace <- as.numeric(fit$misc$gamma_trace %||% numeric(0))
    sigma_trace <- as.numeric(fit$misc$sigma_trace %||% numeric(0))
    elbo_trace <- as.numeric(fit$misc$elbo_trace %||% numeric(0))
    beta_mean <- as.numeric(fit$qbeta$m %||% numeric(0))
    rhs_tau_trace <- as.numeric(fit$misc$rhs_tau_trace %||% numeric(0))
    rhs_c2_trace <- as.numeric(fit$misc$rhs_c2_trace %||% numeric(0))

    base$fit_class <- "exal_vb"
    base$fit_runtime_seconds <- as.numeric(fit$run.time %||% NA_real_)
    base$vb_converged <- isTRUE(fit$converged)
    base$vb_iter <- as.integer(fit$iter %||% NA_integer_)
    base$vb_gamma_last <- if (length(gamma_trace)) utils::tail(gamma_trace, 1L) else as.numeric(fit$qsiggam$gamma_mean %||% NA_real_)
    base$vb_sigma_last <- if (length(sigma_trace)) utils::tail(sigma_trace, 1L) else as.numeric(fit$qsiggam$sigma_mean %||% NA_real_)
    base$vb_elbo_last <- if (length(elbo_trace)) utils::tail(elbo_trace, 1L) else as.numeric(fit$misc$elbo %||% NA_real_)
    base$vb_beta_norm <- sqrt(sum(beta_mean * beta_mean))
    base$rhs_tau_last <- if (length(rhs_tau_trace)) utils::tail(rhs_tau_trace, 1L) else NA_real_
    base$rhs_c2_last <- if (length(rhs_c2_trace)) utils::tail(rhs_c2_trace, 1L) else NA_real_
    base$finite_ok <- all(is.finite(c(base$vb_gamma_last, base$vb_sigma_last, base$vb_beta_norm)))
    base$domain_ok <- is.finite(base$vb_sigma_last) && base$vb_sigma_last > 0
    return(base)
  }

  if (inherits(fit, "exal_mcmc")) {
    beta_draws <- as.matrix(fit$samp.beta)
    gamma_draws <- as.numeric(fit$samp.gamma)
    sigma_draws <- as.numeric(fit$samp.sigma)
    beta_norm <- sqrt(rowSums(beta_draws * beta_draws))
    tau_draws <- if (!is.null(fit$samp.tau)) as.numeric(fit$samp.tau) else numeric(0)
    c2_draws <- if (!is.null(fit$samp.c2)) as.numeric(fit$samp.c2) else numeric(0)
    lambda_mean_draws <- if (!is.null(fit$samp.lambda_mean)) as.numeric(fit$samp.lambda_mean) else numeric(0)

    base$fit_class <- "exal_mcmc"
    base$fit_runtime_seconds <- as.numeric(fit$run.time %||% NA_real_)
    base$mcmc_n_keep <- as.integer(length(gamma_draws))
    base$mcmc_gamma_mean <- if (length(gamma_draws)) mean(gamma_draws) else NA_real_
    base$mcmc_sigma_mean <- if (length(sigma_draws)) mean(sigma_draws) else NA_real_
    base$mcmc_beta_norm_mean <- if (length(beta_norm)) mean(beta_norm) else NA_real_
    base$mcmc_ess_gamma <- .qdesn_validation_safe_ess(gamma_draws)
    base$mcmc_ess_sigma <- .qdesn_validation_safe_ess(sigma_draws)
    base$mcmc_ess_beta_norm <- .qdesn_validation_safe_ess(beta_norm)
    base$mcmc_acf1_gamma <- .qdesn_validation_safe_acf1(gamma_draws)
    base$mcmc_acf1_sigma <- .qdesn_validation_safe_acf1(sigma_draws)
    base$mcmc_acf1_beta_norm <- .qdesn_validation_safe_acf1(beta_norm)
    base$mcmc_gamma_slice_steps_out_mean <- as.numeric(fit$diagnostics$gamma_slice_steps_out_mean %||% NA_real_)
    base$mcmc_gamma_slice_shrink_mean <- as.numeric(fit$diagnostics$gamma_slice_shrink_mean %||% NA_real_)
    base$rhs_tau_mean <- if (length(tau_draws)) mean(tau_draws) else NA_real_
    base$rhs_c2_mean <- if (length(c2_draws)) mean(c2_draws) else NA_real_
    base$rhs_lambda_mean <- if (length(lambda_mean_draws)) mean(lambda_mean_draws) else NA_real_
    base$finite_ok <- all(is.finite(c(base$mcmc_gamma_mean, base$mcmc_sigma_mean, base$mcmc_beta_norm_mean)))
    base$domain_ok <- all(is.finite(sigma_draws)) && all(sigma_draws > 0) &&
      all(is.finite(gamma_draws)) &&
      all(gamma_draws > fit$bounds[["L"]] & gamma_draws < fit$bounds[["U"]])
    return(base)
  }

  base$fit_class <- class(fit)[1L]
  base$fit_runtime_seconds <- NA_real_
  base$finite_ok <- FALSE
  base$domain_ok <- FALSE
  base
}

.qdesn_validation_method_fit_summary <- function(method, root_spec, cfg, summary_obj, error_message = NA_character_) {
  health <- .qdesn_validation_method_health(method, root_spec, summary_obj)
  list(
    root_id = root_spec$root_id,
    scenario = root_spec$scenario,
    tau = as.numeric(root_spec$tau),
    beta_prior_type = root_spec$beta_prior_type,
    seed = as.integer(root_spec$seed),
    reservoir_profile = root_spec$reservoir_profile,
    method = method,
    status = as.character(health$status[1L]),
    error_message = if (is.na(error_message)) NULL else as.character(error_message),
    config = cfg,
    summary = as.list(health[1L, , drop = FALSE]),
    pipeline_summary = as.list(summary_obj$summary[1L, , drop = FALSE])
  )
}

.qdesn_validation_method_progress_trace <- function(method, summary_obj) {
  fit <- .qdesn_validation_extract_fit(summary_obj)
  if (is.null(fit)) return(data.frame(stringsAsFactors = FALSE))

  if (inherits(fit, "exal_vb")) {
    n_iter <- length(fit$misc$gamma_trace %||% numeric(0))
    if (n_iter <= 0L) return(data.frame(stringsAsFactors = FALSE))
    out <- data.frame(
      method = method,
      step = seq_len(n_iter),
      gamma = as.numeric(fit$misc$gamma_trace %||% rep(NA_real_, n_iter)),
      sigma = as.numeric(fit$misc$sigma_trace %||% rep(NA_real_, n_iter)),
      elbo = as.numeric(fit$misc$elbo_trace %||% rep(NA_real_, n_iter)),
      beta_norm = sqrt(sum((as.numeric(fit$qbeta$m %||% numeric(0)))^2)),
      stringsAsFactors = FALSE
    )
    rhs_tau <- as.numeric(fit$misc$rhs_tau_trace %||% numeric(0))
    rhs_c2 <- as.numeric(fit$misc$rhs_c2_trace %||% numeric(0))
    rhs_lambda_mean <- as.numeric(fit$misc$rhs_lambda_mean_trace %||% numeric(0))
    if (length(rhs_tau) == n_iter) out$rhs_tau <- rhs_tau
    if (length(rhs_c2) == n_iter) out$rhs_c2 <- rhs_c2
    if (length(rhs_lambda_mean) == n_iter) out$rhs_lambda_mean <- rhs_lambda_mean
    return(out)
  }

  if (inherits(fit, "exal_mcmc")) {
    beta_draws <- as.matrix(fit$samp.beta)
    out <- data.frame(
      method = method,
      step = seq_len(nrow(beta_draws)),
      gamma = as.numeric(fit$samp.gamma),
      sigma = as.numeric(fit$samp.sigma),
      elbo = NA_real_,
      beta_norm = sqrt(rowSums(beta_draws * beta_draws)),
      stringsAsFactors = FALSE
    )
    rhs_tau <- if (!is.null(fit$samp.tau)) as.numeric(fit$samp.tau) else numeric(0)
    rhs_c2 <- if (!is.null(fit$samp.c2)) as.numeric(fit$samp.c2) else numeric(0)
    rhs_lambda_mean <- if (!is.null(fit$samp.lambda_mean)) as.numeric(fit$samp.lambda_mean) else numeric(0)
    if (length(rhs_tau) == nrow(out)) out$rhs_tau <- rhs_tau
    if (length(rhs_c2) == nrow(out)) out$rhs_c2 <- rhs_c2
    if (length(rhs_lambda_mean) == nrow(out)) out$rhs_lambda_mean <- rhs_lambda_mean
    return(out)
  }

  data.frame(stringsAsFactors = FALSE)
}

.qdesn_validation_mcmc_chain_summary <- function(summary_obj) {
  fit <- .qdesn_validation_extract_fit(summary_obj)
  if (is.null(fit) || !inherits(fit, "exal_mcmc")) return(data.frame(stringsAsFactors = FALSE))

  draws <- list(
    gamma = as.numeric(fit$samp.gamma),
    sigma = as.numeric(fit$samp.sigma),
    beta_norm = sqrt(rowSums(as.matrix(fit$samp.beta)^2))
  )
  if (!is.null(fit$samp.tau)) draws$tau <- as.numeric(fit$samp.tau)
  if (!is.null(fit$samp.c2)) draws$c2 <- as.numeric(fit$samp.c2)
  if (!is.null(fit$samp.lambda_mean)) draws$lambda_mean <- as.numeric(fit$samp.lambda_mean)

  rows <- lapply(names(draws), function(nm) {
    x <- as.numeric(draws[[nm]])
    data.frame(
      parameter = nm,
      mean = mean(x),
      sd = stats::sd(x),
      min = min(x),
      max = max(x),
      ess = .qdesn_validation_safe_ess(x),
      acf1 = .qdesn_validation_safe_acf1(x),
      stringsAsFactors = FALSE
    )
  })
  .qdesn_validation_bind_rows(rows)
}

.qdesn_validation_write_toy_data <- function(root_dir, toy_obj) {
  data_dir <- file.path(root_dir, "data")
  .qdesn_validation_dir_create(data_dir)
  .qdesn_validation_write_df(toy_obj$long, file.path(data_dir, "series_long.csv"))
  .qdesn_validation_write_df(toy_obj$wide, file.path(data_dir, "series_wide.csv"))
  .qdesn_validation_write_df(toy_obj$split, file.path(data_dir, "split_summary.csv"))
}

.qdesn_validation_plot_series_overview <- function(root_dir, root_spec, toy_obj) {
  .qdesn_validation_require_namespace("ggplot2")
  .qdesn_validation_require_namespace("dplyr")

  tau <- as.numeric(root_spec$tau)
  q_tau <- subset(toy_obj$long, abs(p - tau) < 1e-12, select = c("t", "q"))
  df <- data.frame(t = toy_obj$wide$t, y = toy_obj$wide$y, mu = toy_obj$wide$mu, stringsAsFactors = FALSE)
  df$q_true <- q_tau$q
  split_n <- as.integer(toy_obj$split$n_train[1L])

  p <- ggplot2::ggplot(df, ggplot2::aes(x = t)) +
    ggplot2::geom_line(ggplot2::aes(y = y, colour = "y"), linewidth = 0.6) +
    ggplot2::geom_line(ggplot2::aes(y = mu, colour = "mu"), linewidth = 0.8) +
    ggplot2::geom_line(ggplot2::aes(y = q_true, colour = "q_true"), linewidth = 0.8, linetype = 2) +
    ggplot2::geom_vline(xintercept = split_n, linetype = 3, linewidth = 0.6) +
    ggplot2::scale_colour_manual(values = c(y = "#1f2937", mu = "#0f766e", q_true = "#b45309")) +
    ggplot2::labs(
      title = sprintf("Toy Validation Series: %s", root_spec$root_id),
      subtitle = sprintf("Scenario=%s | tau=%0.2f | train/test split at t=%d", root_spec$scenario, tau, split_n),
      x = "t",
      y = "value",
      colour = NULL
    ) +
    ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(legend.position = "top")

  ggplot2::ggsave(file.path(root_dir, "plots", "series_overview.png"), p, width = 9, height = 4.5, dpi = 150)
}

.qdesn_validation_plot_forecast_compare <- function(root_dir, method_rows, forecast_rows) {
  .qdesn_validation_require_namespace("ggplot2")
  if (!nrow(forecast_rows)) return(invisible(NULL))

  p <- ggplot2::ggplot(forecast_rows, ggplot2::aes(x = h)) +
    ggplot2::geom_line(ggplot2::aes(y = q_true, colour = "true q"), linewidth = 0.8, linetype = 2) +
    ggplot2::geom_point(ggplot2::aes(y = y, colour = "y"), size = 1.2, alpha = 0.7) +
    ggplot2::geom_line(ggplot2::aes(y = q_pred, colour = method), linewidth = 0.9) +
    ggplot2::scale_colour_manual(values = c("true q" = "#111827", "y" = "#6b7280", "vb" = "#2563eb", "mcmc" = "#dc2626")) +
    ggplot2::labs(
      title = "Forecast Quantile Comparison",
      subtitle = sprintf("Methods: %s", paste(sort(unique(method_rows$method)), collapse = ", ")),
      x = "forecast horizon h",
      y = "quantile / observation",
      colour = NULL
    ) +
    ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(legend.position = "top")

  ggplot2::ggsave(file.path(root_dir, "plots", "forecast_compare.png"), p, width = 9, height = 4.5, dpi = 150)
  invisible(NULL)
}

.qdesn_validation_plot_runtime_compare <- function(root_dir, method_rows) {
  .qdesn_validation_require_namespace("ggplot2")
  if (!nrow(method_rows)) return(invisible(NULL))
  df <- rbind(
    data.frame(method = method_rows$method, metric = "wall_seconds", value = method_rows$wall_seconds, stringsAsFactors = FALSE),
    data.frame(method = method_rows$method, metric = "timed_stage_seconds", value = method_rows$total_stage_seconds, stringsAsFactors = FALSE)
  )
  p <- ggplot2::ggplot(df, ggplot2::aes(x = method, y = value, fill = method)) +
    ggplot2::geom_col(width = 0.65) +
    ggplot2::facet_wrap(~ metric, scales = "free_y") +
    ggplot2::scale_fill_manual(values = c(vb = "#2563eb", mcmc = "#dc2626")) +
    ggplot2::labs(title = "Runtime Comparison", x = NULL, y = "seconds", fill = NULL) +
    ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(legend.position = "none")
  ggplot2::ggsave(file.path(root_dir, "plots", "runtime_compare.png"), p, width = 8, height = 4.2, dpi = 150)
  invisible(NULL)
}

.qdesn_validation_plot_score_compare <- function(root_dir, method_rows) {
  .qdesn_validation_require_namespace("ggplot2")
  if (!nrow(method_rows)) return(invisible(NULL))
  df <- .qdesn_validation_bind_rows(list(
    data.frame(method = method_rows$method, metric = "forecast_CRPS_mean", value = method_rows$forecast_CRPS_mean, stringsAsFactors = FALSE),
    data.frame(method = method_rows$method, metric = "forecast_PinballMean_mean", value = method_rows$forecast_PinballMean_mean, stringsAsFactors = FALSE),
    data.frame(method = method_rows$method, metric = "forecast_S_mean", value = method_rows$forecast_S_mean, stringsAsFactors = FALSE),
    data.frame(method = method_rows$method, metric = "forecast_qhat_mae", value = method_rows$forecast_qhat_mae, stringsAsFactors = FALSE),
    data.frame(method = method_rows$method, metric = "forecast_pinball_tau", value = method_rows$forecast_pinball_tau, stringsAsFactors = FALSE)
  ))
  df <- df[is.finite(df$value), , drop = FALSE]
  if (!nrow(df)) return(invisible(NULL))
  p <- ggplot2::ggplot(df, ggplot2::aes(x = method, y = value, fill = method)) +
    ggplot2::geom_col(width = 0.65) +
    ggplot2::facet_wrap(~ metric, scales = "free_y") +
    ggplot2::scale_fill_manual(values = c(vb = "#2563eb", mcmc = "#dc2626")) +
    ggplot2::labs(title = "Forecast Score Comparison", x = NULL, y = "value", fill = NULL) +
    ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(legend.position = "none")
  ggplot2::ggsave(file.path(root_dir, "plots", "score_compare.png"), p, width = 8, height = 4.2, dpi = 150)
  invisible(NULL)
}

.qdesn_validation_plot_algorithm_progress <- function(root_dir, progress_rows) {
  .qdesn_validation_require_namespace("ggplot2")
  if (!nrow(progress_rows)) return(invisible(NULL))

  rows <- list(
    data.frame(method = progress_rows$method, step = progress_rows$step, metric = "gamma", value = progress_rows$gamma, stringsAsFactors = FALSE),
    data.frame(method = progress_rows$method, step = progress_rows$step, metric = "sigma", value = progress_rows$sigma, stringsAsFactors = FALSE),
    data.frame(method = progress_rows$method, step = progress_rows$step, metric = "beta_norm", value = progress_rows$beta_norm, stringsAsFactors = FALSE)
  )
  if ("elbo" %in% names(progress_rows) && any(is.finite(progress_rows$elbo))) {
    rows[[length(rows) + 1L]] <- data.frame(method = progress_rows$method, step = progress_rows$step, metric = "elbo", value = progress_rows$elbo, stringsAsFactors = FALSE)
  }
  df <- .qdesn_validation_bind_rows(rows)
  df <- df[is.finite(df$value), , drop = FALSE]
  if (!nrow(df)) return(invisible(NULL))

  p <- ggplot2::ggplot(df, ggplot2::aes(x = step, y = value, colour = method)) +
    ggplot2::geom_line(linewidth = 0.7) +
    ggplot2::facet_wrap(~ metric, scales = "free_y", ncol = 2) +
    ggplot2::scale_colour_manual(values = c(vb = "#2563eb", mcmc = "#dc2626")) +
    ggplot2::labs(title = "Algorithm Progress", x = "step", y = NULL, colour = NULL) +
    ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(legend.position = "top")
  ggplot2::ggsave(file.path(root_dir, "plots", "algorithm_progress.png"), p, width = 8.5, height = 6.5, dpi = 150)
  invisible(NULL)
}

.qdesn_validation_plot_rhs_progress <- function(root_dir, progress_rows) {
  .qdesn_validation_require_namespace("ggplot2")
  needed <- c("rhs_tau", "rhs_c2", "rhs_lambda_mean")
  keep <- needed[needed %in% names(progress_rows)]
  if (!length(keep)) return(invisible(NULL))
  rows <- lapply(keep, function(nm) {
    data.frame(method = progress_rows$method, step = progress_rows$step, metric = nm, value = progress_rows[[nm]], stringsAsFactors = FALSE)
  })
  df <- .qdesn_validation_bind_rows(rows)
  df <- df[is.finite(df$value), , drop = FALSE]
  if (!nrow(df)) return(invisible(NULL))

  p <- ggplot2::ggplot(df, ggplot2::aes(x = step, y = value, colour = method)) +
    ggplot2::geom_line(linewidth = 0.7) +
    ggplot2::facet_wrap(~ metric, scales = "free_y", ncol = 1) +
    ggplot2::scale_colour_manual(values = c(vb = "#2563eb", mcmc = "#dc2626")) +
    ggplot2::labs(title = "RHS Shrinkage Progress", x = "step", y = NULL, colour = NULL) +
    ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(legend.position = "top")
  ggplot2::ggsave(file.path(root_dir, "plots", "rhs_progress.png"), p, width = 7.5, height = 7, dpi = 150)
  invisible(NULL)
}

.qdesn_validation_update_method_status <- function(root_dir, method_status_rows) {
  .qdesn_validation_write_df(method_status_rows, file.path(root_dir, "manifest", "method_status.csv"))
}

.qdesn_validation_write_method_runtime <- function(method_dir, method, root_spec, run_res, status) {
  manifest_dir <- file.path(method_dir, "manifest")
  .qdesn_validation_dir_create(manifest_dir)
  .qdesn_validation_write_lines(file.path(manifest_dir, "status.txt"), status)
  .qdesn_validation_write_json(file.path(manifest_dir, "runtime_summary.json"), list(
    started_at = NA_character_,
    finished_at = as.character(Sys.time()),
    elapsed_seconds = as.numeric(run_res$elapsed_seconds %||% NA_real_),
    elapsed_minutes = as.numeric(run_res$elapsed_seconds %||% NA_real_) / 60,
    status = status,
    dataset_slug = root_spec$scenario,
    spec = paste(root_spec$root_id, method, sep = "::"),
    mode = "sim",
    inference_method = method,
    beta_prior_type = root_spec$beta_prior_type
  ))
}

.qdesn_validation_run_one_method <- function(method, root_spec, defaults, file_long, method_dir, verbose = TRUE) {
  cfg <- qdesn_validation_build_pipeline_cfg(root_spec, defaults = defaults, method = method)
  start_time <- Sys.time()
  status <- "SUCCESS"
  error_message <- NA_character_

  .qdesn_validation_dir_create(file.path(method_dir, "logs"))
  .qdesn_validation_write_json(file.path(method_dir, "fit_request.json"), list(root_spec = root_spec, method = method, config = cfg))

  run_res <- tryCatch(
    run_esn_pipeline_from_cfg(
      cfg = cfg,
      file_long = file_long,
      out_dir = method_dir,
      save_outputs = TRUE,
      verbose = FALSE
    ),
    error = function(e) {
      status <<- "FAIL"
      error_message <<- conditionMessage(e)
      NULL
    }
  )
  if (!is.null(run_res) && !identical(as.integer(run_res$status), 0L)) {
    status <- "FAIL"
    if (is.na(error_message)) {
      error_message <- sprintf("pipeline exited with status %s", as.integer(run_res$status))
    }
  }
  if (!is.null(run_res)) {
    .qdesn_validation_write_method_runtime(method_dir, method, root_spec, run_res, if (identical(status, "SUCCESS")) "SUCCESS" else "FAIL")
  }

  log_lines <- if (!is.null(run_res)) run_res$stdout else error_message
  if (length(log_lines)) {
    .qdesn_validation_write_lines(file.path(method_dir, "logs", "pipeline_stdout.log"), log_lines)
  }

  summary_obj <- NULL
  if (identical(status, "SUCCESS")) {
    summary_obj <- tryCatch(
      collect_pipeline_run_summary(method_dir),
      error = function(e) {
        status <<- "FAIL"
        error_message <<- conditionMessage(e)
        NULL
      }
    )
  }

  if (!is.null(summary_obj) && !identical(as.character(summary_obj$status), "SUCCESS")) {
    status <- as.character(summary_obj$status)
  }

  health_row <- if (!is.null(summary_obj)) {
    .qdesn_validation_method_health(method, root_spec, summary_obj)
  } else {
    data.frame(
      root_id = root_spec$root_id,
      scenario = root_spec$scenario,
      tau = as.numeric(root_spec$tau),
      beta_prior_type = root_spec$beta_prior_type,
      seed = as.integer(root_spec$seed),
      reservoir_profile = root_spec$reservoir_profile,
      method = method,
      status = status,
      fit_class = NA_character_,
      fit_runtime_seconds = NA_real_,
      finite_ok = FALSE,
      domain_ok = FALSE,
      stringsAsFactors = FALSE
    )
  }
  if (!("status" %in% names(health_row)) || is.na(health_row$status[[1L]]) || !nzchar(as.character(health_row$status[[1L]]))) {
    health_row$status <- status
  }

  fit_summary <- if (!is.null(summary_obj)) {
    .qdesn_validation_method_fit_summary(method, root_spec, cfg, summary_obj, error_message = error_message)
  } else {
    list(
      root_id = root_spec$root_id,
      scenario = root_spec$scenario,
      tau = as.numeric(root_spec$tau),
      beta_prior_type = root_spec$beta_prior_type,
      seed = as.integer(root_spec$seed),
      reservoir_profile = root_spec$reservoir_profile,
      method = method,
      status = status,
      error_message = if (is.na(error_message)) NULL else error_message,
      config = cfg
    )
  }

  .qdesn_validation_write_json(file.path(method_dir, "fit_summary.json"), fit_summary)
  .qdesn_validation_write_df(health_row, file.path(method_dir, "health_summary.csv"))

  progress_trace <- if (!is.null(summary_obj)) .qdesn_validation_method_progress_trace(method, summary_obj) else data.frame(stringsAsFactors = FALSE)
  if (nrow(progress_trace)) {
    .qdesn_validation_write_df(progress_trace, file.path(method_dir, "progress_trace.csv"))
  }
  if (identical(method, "mcmc") && !is.null(summary_obj)) {
    chain_summary <- .qdesn_validation_mcmc_chain_summary(summary_obj)
    if (nrow(chain_summary)) {
      .qdesn_validation_write_df(chain_summary, file.path(method_dir, "chain_summary.csv"))
    }
  }

  end_time <- Sys.time()
  list(
    method = method,
    status = status,
    error_message = error_message,
    cfg = cfg,
    start_time = as.character(start_time),
    end_time = as.character(end_time),
    elapsed_seconds = as.numeric(difftime(end_time, start_time, units = "secs")),
    run = run_res,
    summary = summary_obj,
    health = health_row,
    progress_trace = progress_trace,
    forecast_df = if (!is.null(summary_obj)) .qdesn_validation_extract_forecast_df(summary_obj) else data.frame(stringsAsFactors = FALSE)
  )
}

.qdesn_validation_pair_summary <- function(method_rows) {
  if (!nrow(method_rows)) return(data.frame(stringsAsFactors = FALSE))
  keys <- c("root_id", "scenario", "tau", "beta_prior_type", "seed", "reservoir_profile")
  vb <- method_rows[method_rows$method == "vb", , drop = FALSE]
  mc <- method_rows[method_rows$method == "mcmc", , drop = FALSE]
  if (!nrow(vb) || !nrow(mc)) return(data.frame(stringsAsFactors = FALSE))

  keep_vb <- c(keys, "status", "wall_seconds", "total_stage_seconds", "forecast_CRPS_mean",
               "forecast_PinballMean_mean", "forecast_S_mean", "forecast_qhat_mae",
               "forecast_pinball_tau", "forecast_qhat_bias", "fit_runtime_seconds",
               "vb_converged", "vb_iter", "vb_gamma_last", "vb_sigma_last", "vb_elbo_last", "vb_beta_norm")
  keep_mc <- c(keys, "status", "wall_seconds", "total_stage_seconds", "forecast_CRPS_mean",
               "forecast_PinballMean_mean", "forecast_S_mean", "forecast_qhat_mae",
               "forecast_pinball_tau", "forecast_qhat_bias", "fit_runtime_seconds",
               "mcmc_n_keep", "mcmc_ess_gamma", "mcmc_ess_sigma", "mcmc_ess_beta_norm",
               "mcmc_gamma_mean", "mcmc_sigma_mean", "mcmc_beta_norm_mean")
  keep_vb <- keep_vb[keep_vb %in% names(vb)]
  keep_mc <- keep_mc[keep_mc %in% names(mc)]

  vb_sub <- vb[, keep_vb, drop = FALSE]
  mc_sub <- mc[, keep_mc, drop = FALSE]
  names(vb_sub) <- c(keys, paste0("vb_", setdiff(keep_vb, keys)))
  names(mc_sub) <- c(keys, paste0("mcmc_", setdiff(keep_mc, keys)))
  out <- merge(vb_sub, mc_sub, by = keys, all = TRUE, sort = FALSE)
  if ("mcmc_wall_seconds" %in% names(out) && "vb_wall_seconds" %in% names(out)) {
    out$runtime_ratio_mcmc_vs_vb <- with(out, ifelse(is.finite(vb_wall_seconds) & vb_wall_seconds > 0, mcmc_wall_seconds / vb_wall_seconds, NA_real_))
  }
  if ("mcmc_forecast_CRPS_mean" %in% names(out) && "vb_forecast_CRPS_mean" %in% names(out)) {
    out$forecast_CRPS_delta_mcmc_minus_vb <- out$mcmc_forecast_CRPS_mean - out$vb_forecast_CRPS_mean
  }
  if ("mcmc_forecast_PinballMean_mean" %in% names(out) && "vb_forecast_PinballMean_mean" %in% names(out)) {
    out$forecast_Pinball_delta_mcmc_minus_vb <- out$mcmc_forecast_PinballMean_mean - out$vb_forecast_PinballMean_mean
  }
  if ("mcmc_forecast_S_mean" %in% names(out) && "vb_forecast_S_mean" %in% names(out)) {
    out$forecast_S_delta_mcmc_minus_vb <- out$mcmc_forecast_S_mean - out$vb_forecast_S_mean
  }
  if ("mcmc_forecast_qhat_mae" %in% names(out) && "vb_forecast_qhat_mae" %in% names(out)) {
    out$forecast_qhat_mae_delta_mcmc_minus_vb <- out$mcmc_forecast_qhat_mae - out$vb_forecast_qhat_mae
  }
  if ("mcmc_forecast_pinball_tau" %in% names(out) && "vb_forecast_pinball_tau" %in% names(out)) {
    out$forecast_pinball_tau_delta_mcmc_minus_vb <- out$mcmc_forecast_pinball_tau - out$vb_forecast_pinball_tau
  }
  out
}

.qdesn_validation_root_summary <- function(root_spec, method_rows, pair_summary) {
  status_vec <- if ("status" %in% names(method_rows)) as.character(method_rows$status) else character(0)
  status_vec[!nzchar(status_vec) | is.na(status_vec)] <- "FAIL"
  root_status <- if (nrow(method_rows) >= 2L && length(status_vec) >= 2L && all(status_vec == "SUCCESS")) "SUCCESS" else "FAIL"
  data.frame(
    root_id = root_spec$root_id,
    scenario = root_spec$scenario,
    tau = as.numeric(root_spec$tau),
    beta_prior_type = root_spec$beta_prior_type,
    seed = as.integer(root_spec$seed),
    reservoir_profile = root_spec$reservoir_profile,
    root_status = root_status,
    n_methods = nrow(method_rows),
    vb_status = if (any(method_rows$method == "vb")) as.character(method_rows$status[method_rows$method == "vb"][1L]) else NA_character_,
    mcmc_status = if (any(method_rows$method == "mcmc")) as.character(method_rows$status[method_rows$method == "mcmc"][1L]) else NA_character_,
    runtime_ratio_mcmc_vs_vb = as.numeric(pair_summary$runtime_ratio_mcmc_vs_vb[1L] %||% NA_real_),
    forecast_CRPS_delta_mcmc_minus_vb = as.numeric(pair_summary$forecast_CRPS_delta_mcmc_minus_vb[1L] %||% NA_real_),
    forecast_Pinball_delta_mcmc_minus_vb = as.numeric(pair_summary$forecast_Pinball_delta_mcmc_minus_vb[1L] %||% NA_real_),
    forecast_S_delta_mcmc_minus_vb = as.numeric(pair_summary$forecast_S_delta_mcmc_minus_vb[1L] %||% NA_real_),
    forecast_qhat_mae_delta_mcmc_minus_vb = as.numeric(pair_summary$forecast_qhat_mae_delta_mcmc_minus_vb[1L] %||% NA_real_),
    forecast_pinball_tau_delta_mcmc_minus_vb = as.numeric(pair_summary$forecast_pinball_tau_delta_mcmc_minus_vb[1L] %||% NA_real_),
    stringsAsFactors = FALSE
  )
}

qdesn_validation_run_root <- function(root_spec,
                                      defaults = NULL,
                                      defaults_path = file.path("config", "validation", "qdesn_mcmc_pilot_defaults.yaml"),
                                      output_root,
                                      create_plots = TRUE,
                                      verbose = TRUE) {
  defaults <- defaults %||% qdesn_validation_load_defaults(defaults_path)
  root_spec <- qdesn_validation_enrich_root_spec(root_spec, defaults)
  threads <- as.integer(((defaults$runtime %||% list())$threads %||% 1L)[1L])
  .qdesn_validation_apply_thread_caps(threads)

  root_dir <- file.path(output_root, root_spec$root_id)
  if (dir.exists(root_dir) && length(list.files(root_dir, all.files = TRUE, no.. = TRUE)) > 0L) {
    stop(sprintf("Validation root already exists and is not empty: %s", root_dir), call. = FALSE)
  }

  for (d in c("manifest", "config", "data", "fits", "fits/vb", "fits/mcmc", "tables", "plots")) {
    .qdesn_validation_dir_create(file.path(root_dir, d))
  }
  .qdesn_validation_write_lines(file.path(root_dir, "manifest", "root_status.txt"), "RUNNING")

  scenario_cfg <- .qdesn_validation_scenario_cfg(defaults, root_spec$scenario)
  p_grid <- as.numeric((defaults$toy %||% list())$p_grid %||% seq(0.01, 0.99, by = 0.01))
  toy_obj <- qdesn_validation_generate_toy_series(
    scenario = root_spec$scenario,
    seed = root_spec$seed,
    p_grid = p_grid,
    scenario_cfg = scenario_cfg
  )
  .qdesn_validation_write_toy_data(root_dir, toy_obj)

  root_manifest <- list(
    root_id = root_spec$root_id,
    scenario = root_spec$scenario,
    tau = as.numeric(root_spec$tau),
    beta_prior_type = root_spec$beta_prior_type,
    seed = as.integer(root_spec$seed),
    reservoir_profile = root_spec$reservoir_profile,
    git_sha = .qdesn_validation_git_sha(),
    started_at = as.character(Sys.time()),
    defaults_path = defaults_path
  )
  .qdesn_validation_write_json(file.path(root_dir, "manifest", "root_manifest.json"), root_manifest)
  .qdesn_validation_write_json(file.path(root_dir, "config", "root_config.json"), list(root_spec = root_spec, defaults = defaults))

  method_status_rows <- data.frame(stringsAsFactors = FALSE)
  results <- list()
  file_long <- file.path(root_dir, "data", "series_long.csv")

  for (method in c("vb", "mcmc")) {
    if (isTRUE(verbose)) {
      message(sprintf("[qdesn_validation_run_root] %s | %s", root_spec$root_id, method))
    }
    method_dir <- file.path(root_dir, "fits", method)
    res <- .qdesn_validation_run_one_method(method, root_spec, defaults, file_long, method_dir, verbose = verbose)
    results[[method]] <- res
    method_status_rows <- .qdesn_validation_bind_rows(list(method_status_rows, data.frame(
      root_id = root_spec$root_id,
      method = method,
      status = res$status,
      start_time = res$start_time,
      end_time = res$end_time,
      elapsed_seconds = res$elapsed_seconds,
      error_message = if (is.na(res$error_message)) "" else res$error_message,
      stringsAsFactors = FALSE
    )))
    .qdesn_validation_update_method_status(root_dir, method_status_rows)
  }

  method_rows <- .qdesn_validation_bind_rows(lapply(results, function(x) x$health))
  if (nrow(method_rows)) {
    .qdesn_validation_write_df(method_rows, file.path(root_dir, "tables", "method_compare_long.csv"))
  }

  pair_summary <- .qdesn_validation_pair_summary(method_rows)
  if (nrow(pair_summary)) {
    .qdesn_validation_write_df(pair_summary, file.path(root_dir, "tables", "method_compare_summary.csv"))
  }

  root_summary <- .qdesn_validation_root_summary(root_spec, method_rows, pair_summary)
  .qdesn_validation_write_df(root_summary, file.path(root_dir, "tables", "root_summary.csv"))

  progress_rows <- .qdesn_validation_bind_rows(lapply(results, function(x) x$progress_trace))
  if (nrow(progress_rows)) {
    .qdesn_validation_write_df(progress_rows, file.path(root_dir, "tables", "algorithm_progress_long.csv"))
  }

  forecast_rows <- .qdesn_validation_bind_rows(lapply(results, function(x) {
    df <- x$forecast_df
    if (!nrow(df)) return(NULL)
    df$method <- x$method
    df
  }))
  if (nrow(forecast_rows)) {
    .qdesn_validation_write_df(forecast_rows, file.path(root_dir, "tables", "forecast_compare_long.csv"))
  }

  if (isTRUE(create_plots)) {
    .qdesn_validation_plot_series_overview(root_dir, root_spec, toy_obj)
    .qdesn_validation_plot_forecast_compare(root_dir, method_rows, forecast_rows)
    .qdesn_validation_plot_runtime_compare(root_dir, method_rows)
    .qdesn_validation_plot_score_compare(root_dir, method_rows)
    .qdesn_validation_plot_algorithm_progress(root_dir, progress_rows)
    if (identical(root_spec$beta_prior_type, "rhs")) {
      .qdesn_validation_plot_rhs_progress(root_dir, progress_rows)
    }
  }

  root_status <- if (nrow(method_rows) >= 2L && all(as.character(method_rows$status) == "SUCCESS")) "SUCCESS" else "FAIL"
  .qdesn_validation_write_lines(file.path(root_dir, "manifest", "root_status.txt"), root_status)
  .qdesn_validation_write_json(file.path(root_dir, "manifest", "runtime_summary.json"), list(
    root_status = root_status,
    started_at = root_manifest$started_at,
    finished_at = as.character(Sys.time()),
    methods = method_status_rows
  ))

  list(
    root_dir = root_dir,
    root_spec = root_spec,
    root_status = root_status,
    method_rows = method_rows,
    pair_summary = pair_summary,
    root_summary = root_summary
  )
}

qdesn_validation_collect_campaign <- function(results_root, report_root, create_plots = TRUE) {
  .qdesn_validation_dir_create(report_root)
  .qdesn_validation_dir_create(file.path(report_root, "tables"))
  .qdesn_validation_dir_create(file.path(report_root, "plots"))

  roots_dir <- file.path(results_root, "roots")
  root_dirs <- sort(list.dirs(roots_dir, recursive = FALSE, full.names = TRUE))
  root_summary_rows <- list()
  method_rows <- list()
  pair_rows <- list()

  for (root_dir in root_dirs) {
    root_summary_path <- file.path(root_dir, "tables", "root_summary.csv")
    method_path <- file.path(root_dir, "tables", "method_compare_long.csv")
    pair_path <- file.path(root_dir, "tables", "method_compare_summary.csv")
    if (file.exists(root_summary_path)) root_summary_rows[[length(root_summary_rows) + 1L]] <- utils::read.csv(root_summary_path, stringsAsFactors = FALSE)
    if (file.exists(method_path)) method_rows[[length(method_rows) + 1L]] <- utils::read.csv(method_path, stringsAsFactors = FALSE)
    if (file.exists(pair_path)) pair_rows[[length(pair_rows) + 1L]] <- utils::read.csv(pair_path, stringsAsFactors = FALSE)
  }

  root_summary <- .qdesn_validation_bind_rows(root_summary_rows)
  method_summary <- .qdesn_validation_bind_rows(method_rows)
  pair_summary <- .qdesn_validation_bind_rows(pair_rows)

  .qdesn_validation_write_df(root_summary, file.path(report_root, "tables", "campaign_root_summary.csv"))
  .qdesn_validation_write_df(method_summary, file.path(report_root, "tables", "campaign_method_summary.csv"))
  .qdesn_validation_write_df(pair_summary, file.path(report_root, "tables", "campaign_pair_summary.csv"))

  status_vec <- if (nrow(root_summary) && "root_status" %in% names(root_summary)) as.character(root_summary$root_status) else character(0)
  campaign_status <- data.frame(
    n_roots = nrow(root_summary),
    n_root_success = sum(status_vec == "SUCCESS"),
    n_root_fail = sum(status_vec != "SUCCESS"),
    stringsAsFactors = FALSE
  )
  .qdesn_validation_write_df(campaign_status, file.path(report_root, "tables", "campaign_status.csv"))

  if (isTRUE(create_plots) && nrow(method_summary)) {
    .qdesn_validation_require_namespace("ggplot2")

    runtime_df <- method_summary[is.finite(method_summary$wall_seconds), c("beta_prior_type", "method", "wall_seconds"), drop = FALSE]
    if (nrow(runtime_df)) {
      p_runtime <- ggplot2::ggplot(runtime_df, ggplot2::aes(x = beta_prior_type, y = wall_seconds, fill = method)) +
        ggplot2::geom_col(position = "dodge", width = 0.65) +
        ggplot2::scale_fill_manual(values = c(vb = "#2563eb", mcmc = "#dc2626")) +
        ggplot2::labs(title = "Campaign Runtime by Prior", x = "beta prior", y = "wall seconds", fill = NULL) +
        ggplot2::theme_minimal(base_size = 11)
      ggplot2::ggsave(file.path(report_root, "plots", "campaign_runtime_compare.png"), p_runtime, width = 8, height = 4.5, dpi = 150)
    }

    score_long <- .qdesn_validation_bind_rows(list(
      data.frame(beta_prior_type = method_summary$beta_prior_type, method = method_summary$method, metric = "forecast_CRPS_mean", value = method_summary$forecast_CRPS_mean, stringsAsFactors = FALSE),
      data.frame(beta_prior_type = method_summary$beta_prior_type, method = method_summary$method, metric = "forecast_PinballMean_mean", value = method_summary$forecast_PinballMean_mean, stringsAsFactors = FALSE),
      data.frame(beta_prior_type = method_summary$beta_prior_type, method = method_summary$method, metric = "forecast_S_mean", value = method_summary$forecast_S_mean, stringsAsFactors = FALSE),
      data.frame(beta_prior_type = method_summary$beta_prior_type, method = method_summary$method, metric = "forecast_qhat_mae", value = method_summary$forecast_qhat_mae, stringsAsFactors = FALSE),
      data.frame(beta_prior_type = method_summary$beta_prior_type, method = method_summary$method, metric = "forecast_pinball_tau", value = method_summary$forecast_pinball_tau, stringsAsFactors = FALSE)
    ))
    score_long <- score_long[is.finite(score_long$value), , drop = FALSE]
    if (nrow(score_long)) {
      p_score <- ggplot2::ggplot(score_long, ggplot2::aes(x = beta_prior_type, y = value, fill = method)) +
        ggplot2::geom_col(position = "dodge", width = 0.65) +
        ggplot2::facet_wrap(~ metric, scales = "free_y") +
        ggplot2::scale_fill_manual(values = c(vb = "#2563eb", mcmc = "#dc2626")) +
        ggplot2::labs(title = "Campaign Forecast Score Comparison", x = "beta prior", y = "value", fill = NULL) +
        ggplot2::theme_minimal(base_size = 11)
      ggplot2::ggsave(file.path(report_root, "plots", "campaign_score_compare.png"), p_score, width = 9, height = 4.8, dpi = 150)
    }

    if (nrow(pair_summary) && "runtime_ratio_mcmc_vs_vb" %in% names(pair_summary)) {
      ratio_df <- pair_summary[is.finite(pair_summary$runtime_ratio_mcmc_vs_vb), c("beta_prior_type", "runtime_ratio_mcmc_vs_vb"), drop = FALSE]
      if (nrow(ratio_df)) {
        p_ratio <- ggplot2::ggplot(ratio_df, ggplot2::aes(x = beta_prior_type, y = runtime_ratio_mcmc_vs_vb)) +
          ggplot2::geom_col(fill = "#7c3aed", width = 0.6) +
          ggplot2::labs(title = "MCMC / VB Runtime Ratio", x = "beta prior", y = "ratio") +
          ggplot2::theme_minimal(base_size = 11)
        ggplot2::ggsave(file.path(report_root, "plots", "campaign_runtime_ratio.png"), p_ratio, width = 7, height = 4, dpi = 150)
      }
    }
  }

  invisible(list(
    root_summary = root_summary,
    method_summary = method_summary,
    pair_summary = pair_summary,
    report_root = report_root
  ))
}

qdesn_validation_run_campaign <- function(grid = NULL,
                                          defaults = NULL,
                                          grid_path = file.path("config", "validation", "qdesn_mcmc_pilot_grid.csv"),
                                          defaults_path = file.path("config", "validation", "qdesn_mcmc_pilot_defaults.yaml"),
                                          results_root = NULL,
                                          report_root = NULL,
                                          create_plots = TRUE,
                                          root_filter = NULL,
                                          verbose = TRUE) {
  defaults <- defaults %||% qdesn_validation_load_defaults(defaults_path)
  grid <- grid %||% qdesn_validation_load_grid(grid_path)

  campaign_cfg <- defaults$campaign %||% list()
  results_root <- results_root %||% .qdesn_validation_resolve_path(
    campaign_cfg$results_root %||% file.path("results", "qdesn_mcmc_validation", "pilot"),
    must_work = FALSE
  )
  report_root <- report_root %||% .qdesn_validation_resolve_path(
    campaign_cfg$reports_root %||% file.path("reports", "qdesn_mcmc_validation", "pilot"),
    must_work = FALSE
  )
  timestamp <- format(Sys.time(), "%Y%m%d-%H%M%S")
  run_stub <- sprintf("%s__git-%s", timestamp, .qdesn_validation_git_sha() %||% "unknown")
  results_run_root <- file.path(results_root, run_stub)
  report_run_root <- file.path(report_root, run_stub)

  for (d in c(results_run_root, file.path(results_run_root, "roots"), report_run_root, file.path(report_run_root, "tables"), file.path(report_run_root, "plots"), file.path(report_run_root, "manifest"))) {
    .qdesn_validation_dir_create(d)
  }
  .qdesn_validation_write_json(file.path(report_run_root, "manifest", "campaign_manifest.json"), list(
    campaign_name = campaign_cfg$name %||% "qdesn_mcmc_validation_pilot",
    started_at = as.character(Sys.time()),
    results_root = results_run_root,
    report_root = report_run_root,
    grid_path = grid_path,
    defaults_path = defaults_path,
    git_sha = .qdesn_validation_git_sha()
  ))

  root_filter <- as.character(root_filter %||% character(0))
  run_status_rows <- list()

  for (i in seq_len(nrow(grid))) {
    root_spec <- qdesn_validation_enrich_root_spec(as.list(grid[i, , drop = FALSE]), defaults)
    if (!isTRUE(root_spec$enabled)) next
    if (length(root_filter) && !(root_spec$root_id %in% root_filter)) next
    if (isTRUE(verbose)) {
      message(sprintf("[qdesn_validation_run_campaign] root %d/%d | %s", i, nrow(grid), root_spec$root_id))
    }
    res <- tryCatch(
      qdesn_validation_run_root(
        root_spec = root_spec,
        defaults = defaults,
        output_root = file.path(results_run_root, "roots"),
        create_plots = create_plots,
        verbose = verbose
      ),
      error = function(e) {
        data.frame(
          root_id = root_spec$root_id,
          scenario = root_spec$scenario,
          tau = as.numeric(root_spec$tau),
          beta_prior_type = root_spec$beta_prior_type,
          seed = as.integer(root_spec$seed),
          reservoir_profile = root_spec$reservoir_profile,
          root_status = "FAIL",
          error_message = conditionMessage(e),
          stringsAsFactors = FALSE
        )
      }
    )

    row <- if (is.data.frame(res)) {
      res
    } else {
      tmp <- res$root_summary
      tmp$error_message <- ""
      tmp
    }
    run_status_rows[[length(run_status_rows) + 1L]] <- row
    .qdesn_validation_write_df(.qdesn_validation_bind_rows(run_status_rows), file.path(report_run_root, "tables", "campaign_progress.csv"))
    qdesn_validation_collect_campaign(results_root = results_run_root, report_root = report_run_root, create_plots = create_plots)
  }

  final <- qdesn_validation_collect_campaign(results_root = results_run_root, report_root = report_run_root, create_plots = create_plots)
  .qdesn_validation_write_json(file.path(report_run_root, "manifest", "campaign_completed.json"), list(
    finished_at = as.character(Sys.time()),
    results_root = results_run_root,
    report_root = report_run_root,
    n_roots = nrow(final$root_summary),
    n_methods = nrow(final$method_summary)
  ))
  invisible(list(
    results_root = results_run_root,
    report_root = report_run_root,
    summary = final
  ))
}

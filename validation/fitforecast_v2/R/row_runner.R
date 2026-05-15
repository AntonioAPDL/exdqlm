ffv2_fit_qhat <- function(fit) {
  if (!is.null(fit$theta.out$fm) && !is.null(fit$model$FF)) {
    fm <- as.matrix(fit$theta.out$fm)
    FF <- as.matrix(fit$model$FF)
    if (ncol(FF) == 1L) FF <- matrix(rep(FF[, 1L], ncol(fm)), nrow = nrow(FF))
    return(as.numeric(colSums(FF[, seq_len(ncol(fm)), drop = FALSE] * fm)))
  }
  if (!is.null(fit$ff)) return(as.numeric(fit$ff))
  NULL
}

ffv2_post_pred_draws <- function(fit, n_rows, seed, n_draws) {
  draws <- fit$samp.post.pred
  if (is.null(draws)) {
    qhat <- ffv2_fit_qhat(fit)
    if (is.null(qhat)) stop("Fit object has neither samp.post.pred nor fitted qhat.", call. = FALSE)
    draws <- matrix(qhat, nrow = n_rows, ncol = 1L)
  }
  draws <- as.matrix(draws)
  if (nrow(draws) != n_rows && ncol(draws) == n_rows) draws <- t(draws)
  if (nrow(draws) != n_rows) {
    stop(sprintf("Posterior predictive draws have %d rows; expected %d.", nrow(draws), n_rows),
         call. = FALSE)
  }
  ffv2_select_draws(draws, n_draws = n_draws, seed = seed)
}

ffv2_fit_row <- function(config, data, model) {
  tau <- as.numeric(config$tau)
  dqlm_ind <- isTRUE(config$dqlm_ind) || identical(as.character(config$dqlm_ind), "TRUE")
  df <- as.numeric((config$models %||% list())$df_value %||% 0.98)
  dim_df <- as.integer(unlist((config$models %||% list())$dim_df %||% c(2L, 4L), use.names = FALSE))
  budget <- config$budget %||% list()
  vb_budget <- budget$vb %||% list()
  mcmc_budget <- budget$mcmc %||% list()
  vb_control <- exal_make_vb_control(
    max_iter = as.integer(vb_budget$max_iter %||% 300L),
    tol = as.numeric(vb_budget$tol %||% 0.03),
    n_samp_xi = min(1000L, as.integer(vb_budget$n_samp %||% 20000L)),
    verbose = FALSE
  )
  if (identical(as.character(config$inference), "vb")) {
    return(exdqlmLDVB(
      y = data$train$y,
      p0 = tau,
      model = model,
      df = df,
      dim.df = dim_df,
      dqlm.ind = dqlm_ind,
      fix.sigma = FALSE,
      n.samp = as.integer(vb_budget$n_samp %||% 20000L),
      vb_control = vb_control,
      verbose = FALSE
    ))
  }
  vb_init <- NULL
  if (isTRUE(mcmc_budget$init_from_vb %||% TRUE)) {
    vb_init <- exdqlmLDVB(
      y = data$train$y,
      p0 = tau,
      model = model,
      df = df,
      dim.df = dim_df,
      dqlm.ind = dqlm_ind,
      fix.sigma = FALSE,
      n.samp = max(200L, min(2000L, as.integer(vb_budget$n_samp %||% 20000L))),
      vb_control = vb_control,
      verbose = FALSE
    )
  }
  mcmc_control <- exal_make_mcmc_control(
    n_burn = as.integer(mcmc_budget$n_burn %||% 5000L),
    n_mcmc = as.integer(mcmc_budget$n_mcmc %||% 20000L),
    thin = as.integer(mcmc_budget$thin %||% 1L),
    verbose = FALSE,
    init_from_vb = isTRUE(mcmc_budget$init_from_vb %||% TRUE),
    vb_warm_start_control = vb_control
  )
  exdqlmMCMC(
    y = data$train$y,
    p0 = tau,
    model = model,
    df = df,
    dim.df = dim_df,
    dqlm.ind = dqlm_ind,
    fix.sigma = FALSE,
    n.burn = as.integer(mcmc_budget$n_burn %||% 5000L),
    n.mcmc = as.integer(mcmc_budget$n_mcmc %||% 20000L),
    init.from.vb = isTRUE(mcmc_budget$init_from_vb %||% TRUE),
    vb_init_fit = vb_init,
    mcmc_control = mcmc_control,
    verbose = FALSE,
    mh.proposal = "slice",
    trace.diagnostics = TRUE,
    trace.every = 50L
  )
}

ffv2_run_row <- function(config_path, force = FALSE) {
  config <- ffv2_read_json(config_path)
  ffv2_assert_runtime((config$runtime %||% list())$r_min_version %||% "4.6.0")
  if (file.exists(config$row_status_path) && !isTRUE(force)) {
    st <- tryCatch(ffv2_read_csv(config$row_status_path), error = function(e) NULL)
    if (!is.null(st) && nrow(st) && tail(st$status, 1L) == "done") {
      message(sprintf("Skipping completed row %s", config$row_key))
      return(invisible(st))
    }
  }
  Sys.setenv(
    OMP_NUM_THREADS = as.character((config$runtime %||% list())$threads %||% 1L),
    OPENBLAS_NUM_THREADS = as.character((config$runtime %||% list())$threads %||% 1L),
    MKL_NUM_THREADS = as.character((config$runtime %||% list())$threads %||% 1L)
  )
  started <- Sys.time()
  ffv2_write_csv(
    ffv2_status_row(config, "running", started_at = started, finished_at = started, runtime_sec = 0),
    config$row_status_path
  )
  out <- tryCatch({
    suppressPackageStartupMessages(pkgload::load_all(config$repo_root, quiet = TRUE))
    data <- ffv2_load_row_data(config)
    model <- ffv2_build_dynamic_model(config, train_n = nrow(data$train))
    fit <- ffv2_fit_row(config, data, model)
    stored_draws <- as.integer((config$budget %||% list())$stored_draws %||% 2000L)
    seed <- 100000L + as.integer(config$row_id)
    fit_draws <- ffv2_post_pred_draws(fit, nrow(data$train), seed = seed, n_draws = stored_draws)
    fit_qhat <- ffv2_fit_qhat(fit)
    if (is.null(fit_qhat)) fit_qhat <- apply(fit_draws, 1L, stats::median, na.rm = TRUE)
    future <- ffv2_make_future_model_arrays(model, as.integer(config$forecast_horizon_max))
    forecast_draws_n <- as.integer((config$budget %||% list())$forecast_draws %||% 2000L)
    forecast <- exdqlmForecast(
      start.t = nrow(data$train),
      k = as.integer(config$forecast_horizon_max),
      m1 = fit,
      fFF = future$fFF,
      fGG = future$fGG,
      plot = FALSE,
      return.draws = TRUE,
      n.samp = forecast_draws_n,
      seed = seed + 1L
    )
    forecast_draws <- ffv2_select_draws(forecast$samp.fore, n_draws = stored_draws, seed = seed + 2L)
    fit_summary <- ffv2_path_summary(
      row_df = data$train,
      draws = fit_draws,
      tau = config$tau,
      split_role = "fit_train",
      qhat_override = fit_qhat
    )
    forecast_summary <- ffv2_path_summary(
      row_df = data$forecast,
      draws = forecast_draws,
      tau = config$tau,
      split_role = "forecast",
      qhat_override = as.numeric(forecast$ff)
    )
    finished <- Sys.time()
    runtime <- ffv2_seconds(started, finished)
    health <- ffv2_health_from_outputs(config, fit_summary, forecast_summary, runtime_sec = runtime)
    metrics <- ffv2_row_metrics(
      config = config,
      fit_summary = fit_summary,
      forecast_summary = forecast_summary,
      runtime_sec = runtime,
      status = "done",
      health_gate = health$gate[[1L]]
    )
    status <- ffv2_status_row(
      config, "done", started_at = started, finished_at = finished,
      runtime_sec = runtime, health_gate = health$gate[[1L]]
    )
    ffv2_write_row_artifacts(config, health, metrics, fit_summary, forecast_summary, status)
    rm(fit, forecast, fit_draws, forecast_draws)
    gc()
    status
  }, error = function(e) {
    finished <- Sys.time()
    runtime <- ffv2_seconds(started, finished)
    health <- ffv2_health_from_outputs(config, runtime_sec = runtime, error = e)
    status <- ffv2_status_row(
      config, "failed_runtime", started_at = started, finished_at = finished,
      runtime_sec = runtime, health_gate = "FAIL", error_message = conditionMessage(e)
    )
    ffv2_write_csv(health, config$row_health_path)
    ffv2_write_csv(status, config$row_status_path)
    status
  })
  invisible(out)
}

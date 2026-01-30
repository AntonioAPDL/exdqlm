# Model selection v2 core engine (origin-mode only)

`%||%` <- function(x, alt) if (!is.null(x)) x else alt

ms_build_vb_control <- function(cfg, p0) {
  vb <- cfg$vb %||% list()
  rhs <- vb$rhs %||% list()
  diag <- vb$diagnostics %||% list()

  vb_tol_for <- function(p) if (abs(p - 0.50) < 1e-8) 1e-4 else 1e-5
  vb_tol_par_for <- vb_tol_for

  list(
    max_iter  = as.integer(vb$max_iter %||% 150L),
    min_iter_elbo = as.integer(vb$min_iter_elbo %||% 10L),
    tol       = as.numeric(vb$tol %||% vb_tol_for(p0)),
    tol_par   = as.numeric(vb$tol_par %||% vb_tol_par_for(p0)),
    n_samp_xi = as.integer(vb$n_samp_xi %||% 500L),
    verbose   = isTRUE(vb$verbose %||% FALSE),

    rhs_trace = isTRUE(diag$rhs_trace %||% FALSE),
    rhs_deep  = isTRUE(diag$rhs_deep %||% FALSE),
    rhs_trace_thresholds = diag$rhs_trace_thresholds %||% c(1e3, 1e6, 1e9),
    rhs_trace_top_k = as.integer(diag$rhs_trace_top_k %||% 20L),
    rhs_trace_eps = diag$rhs_trace_eps %||% c(1e-6, 1e-4, 1e-2),

    rhs_freeze_tau_iters = as.integer(rhs$freeze_tau_iters %||% rhs$freeze_tau_warmup_iters %||% 0L),
    rhs_update_every = as.integer(rhs$update_every %||% 1L),
    rhs_update_every_warmup = as.integer(rhs$update_every_warmup %||% 1L),
    rhs_update_every_warmup_iters = as.integer(rhs$update_every_warmup_iters %||% 0L),
    rhs_beta_presteps = as.integer(rhs$beta_presteps %||% 1L),
    rhs_beta_presteps_iters = as.integer(rhs$beta_presteps_iters %||% 0L),
    rhs_gradcheck = isTRUE(rhs$gradcheck %||% FALSE),
    rhs_gradcheck_iters = rhs$gradcheck_iters %||% c(1L, 5L),
    rhs_gradcheck_h = as.numeric(rhs$gradcheck_h %||% 1e-5),
    rhs_tau_local_tol = rhs$tau_local_tol %||% NA_real_,
    rhs_min_tau_updates = as.integer(rhs$min_tau_updates %||% 1L),
    rhs_max_tau_updates = rhs$max_tau_updates %||% NA_integer_,
    rhs_force_tau_after_warmup = isTRUE(rhs$force_tau_after_warmup %||% TRUE),
    rhs_recompute_elbo_after_tau_update = isTRUE(rhs$recompute_elbo_after_tau_update %||% TRUE)
  )
}

ms_build_beta_prior_obj <- function(cfg) {
  vb <- cfg$vb %||% list()
  priors <- vb$priors %||% list()
  beta <- priors$beta %||% list()
  beta_type <- tolower(beta$type %||% "ridge")

  if (beta_type == "rhs") {
    rhs_hypers <- beta$rhs %||% list()
    beta_prior(type = "rhs", rhs = rhs_hypers)
  } else {
    ridge_cfg <- beta$ridge %||% list()
    beta_prior(type = "ridge", ridge = list(tau2 = ridge_cfg$tau2 %||% 1e4))
  }
}

ms_fit_one_tau <- function(X_train, y_train, p0, cfg, vb_control) {
  priors <- (cfg$vb %||% list())$priors %||% list()
  gamma_mu0 <- priors$gamma_mu0 %||% NULL
  gamma_s20 <- priors$gamma_s20 %||% NULL
  sigma_a <- priors$sigma_a %||% NULL
  sigma_b <- priors$sigma_b %||% NULL

  beta_prior_obj <- ms_build_beta_prior_obj(cfg)

  fit_args <- list(
    y = y_train,
    X = X_train,
    p0 = p0,
    gamma_bounds = c(L.fn(p0), U.fn(p0)),
    a_sigma = sigma_a %||% 1,
    b_sigma = sigma_b %||% 1,
    vb_control = vb_control,
    max_iter = vb_control$max_iter,
    tol = vb_control$tol,
    tol_par = vb_control$tol_par,
    n_samp_xi = vb_control$n_samp_xi,
    verbose = vb_control$verbose,
    init = list(gamma = 0, sigma = 1),
    beta_prior_obj = beta_prior_obj
  )

  if (!is.null(gamma_mu0) && !is.null(gamma_s20)) {
    fit_args$prior_gamma_mu0 <- gamma_mu0
    fit_args$prior_gamma_s20 <- gamma_s20
    fit_args$log_prior_gamma <- function(g) {
      sum(stats::dnorm(g, mean = gamma_mu0, sd = sqrt(gamma_s20), log = TRUE))
    }
  } else {
    fit_args$log_prior_gamma <- function(g) 0
  }

  do.call(exal_ldvb_fit, fit_args)
}

ms_select_lead1_from_lattice <- function(fore_obj) {
  if (is.null(fore_obj$yrep_by_origin) || is.null(fore_obj$mu_by_origin)) return(NULL)
  origins <- fore_obj$origins
  targets <- fore_obj$targets
  nd <- ncol(fore_obj$yrep_by_origin[[1]])
  y_out <- matrix(NA_real_, nrow = length(targets), ncol = nd)
  mu_out <- matrix(NA_real_, nrow = length(targets), ncol = nd)
  origin_idx <- match(targets - 1L, origins)
  ok <- which(!is.na(origin_idx))
  for (i in ok) {
    oi <- origin_idx[i]
    y_out[i, ] <- fore_obj$yrep_by_origin[[oi]][1, ]
    mu_out[i, ] <- fore_obj$mu_by_origin[[oi]][1, ]
  }
  list(y = y_out, mu = mu_out)
}

ms_prepare_sim_bundle <- function(cfg, ds) {
  file_long <- ds$input_path
  dat_long <- read.csv(file_long) |>
    tibble::as_tibble() |>
    dplyr::mutate(t = as.integer(t), p = as.numeric(p), q = as.numeric(q),
                  y = as.numeric(y), mu = as.numeric(mu)) |>
    dplyr::arrange(t, p)

  y_full_all <- dat_long |>
    dplyr::distinct(t, y) |>
    dplyr::arrange(t)
  T_full <- nrow(y_full_all)

  split_info <- ms_resolve_split(cfg$split, T_full)
  idx_use <- split_info$idx_use
  y_full <- y_full_all[idx_use, , drop = FALSE]

  list(
    mode = "sim",
    dat_long = dat_long,
    y_full = as.numeric(y_full$y),
    y_full_df = y_full,
    T_full = T_full,
    split_info = split_info
  )
}

ms_prepare_real_bundle <- function(cfg, ds) {
  file_long <- ds$input_path
  raw <- readr::read_csv(file_long, show_col_types = FALSE)
  cols_cfg <- cfg$columns %||% list()
  y_col <- cols_cfg$y %||% "y"
  x_cols <- cols_cfg$x %||% character(0)

  if (!(y_col %in% names(raw))) stop("Target column not found: ", y_col)
  for (xn in x_cols) if (!(xn %in% names(raw))) stop("Exogenous column not found: ", xn)

  y_all <- as.numeric(raw[[y_col]])
  X_all <- if (length(x_cols)) as.matrix(raw[, x_cols, drop = FALSE]) else NULL
  T_full <- length(y_all)

  pre <- cfg$preproc %||% list()
  scale_y <- isTRUE(pre$scale_y %||% TRUE)
  scale_x <- isTRUE(pre$scale_x %||% TRUE)

  y_mean <- mean(y_all, na.rm = TRUE)
  y_sd <- stats::sd(y_all, na.rm = TRUE)
  if (!is.finite(y_sd) || y_sd == 0) y_sd <- 1

  if (scale_y) y_all <- (y_all - y_mean) / y_sd

  if (!is.null(X_all) && ncol(X_all) > 0 && scale_x) {
    X_mu <- matrix(colMeans(X_all, na.rm = TRUE), nrow = 1)
    X_sd <- apply(X_all, 2, function(v) { s <- stats::sd(v, na.rm = TRUE); if (!is.finite(s) || s == 0) 1 else s })
    X_all <- sweep(sweep(X_all, 2, X_mu, "-"), 2, X_sd, "/")
  } else {
    X_mu <- NULL
    X_sd <- NULL
  }

  bt_y <- function(z) {
    if (!scale_y) return(z)
    z * y_sd + y_mean
  }

  split_info <- ms_resolve_split(cfg$split, T_full)
  idx_use <- split_info$idx_use
  y_full <- y_all[idx_use]
  X_use <- if (!is.null(X_all)) X_all[idx_use, , drop = FALSE] else NULL

  list(
    mode = "real",
    y_full = y_full,
    X_all = X_all,
    X_use = X_use,
    T_full = T_full,
    split_info = split_info,
    bt_y = bt_y
  )
}

ms_evaluate_candidate_v2 <- function(cfg, data_bundle, stage_spec, candidate, candidate_id, stage_name, origins_override = NULL) {
  if (tolower(cfg$forecast$mode %||% "origin") != "origin") {
    stop("Model selection v2 supports only forecast.mode == 'origin'.")
  }

  p_vec_default <- cfg$p_vec %||% c(0.05, 0.50, 0.95)
  p_vec <- ms_maybe_use_default(stage_spec$p_vec, p_vec_default)
  p_vec <- as.numeric(p_vec)

  nd_draws <- as.integer(stage_spec$nd_draws %||% (cfg$sampling$nd_draws %||% 1000L))
  synth_n_samp <- as.integer(stage_spec$synth_n_samp %||% (cfg$synthesis$n_samp %||% 1000L))
  forecast_horizon <- as.integer(stage_spec$horizon %||% (cfg$forecast$horizon %||% 1L))

  cfg$p_vec <- p_vec
  cfg$sampling$nd_draws <- nd_draws
  cfg$synthesis$n_samp <- synth_n_samp
  cfg$forecast$horizon <- forecast_horizon

  if (!is.null(candidate$D)) cfg$desn$D <- candidate$D
  if (!is.null(candidate$n)) cfg$desn$n <- candidate$n
  if (!is.null(candidate$n_tilde)) cfg$desn$n_tilde <- candidate$n_tilde
  if (!is.null(candidate$m)) cfg$desn$m <- candidate$m
  if (!is.null(candidate$alpha)) cfg$desn$alpha <- candidate$alpha
  if (!is.null(candidate$rho)) cfg$desn$rho <- candidate$rho
  if (!is.null(candidate$seed) && is.finite(candidate$seed)) cfg$desn$seed <- candidate$seed

  # Align n_tilde length with D if present in base config
  if (!is.null(cfg$desn$n_tilde)) {
    Dtmp <- as.integer(cfg$desn$D %||% length(cfg$desn$n))
    if (Dtmp <= 1L) {
      cfg$desn$n_tilde <- integer(0)
    } else {
      nt <- as.integer(cfg$desn$n_tilde)
      if (length(nt) > (Dtmp - 1L)) nt <- nt[seq_len(Dtmp - 1L)]
      if (length(nt) == 1L && (Dtmp - 1L) > 1L) nt <- rep(nt, Dtmp - 1L)
      cfg$desn$n_tilde <- nt
    }
  }

  cfg <- ms_resolve_desn(cfg)

  readout_include_input <- isTRUE(cfg$readout$include_input %||% FALSE)
  readout_reservoir_lags <- as.integer(cfg$readout$reservoir_lags %||% 0L)
  readout_scale <- isTRUE(cfg$vb$readout_scale %||% FALSE)

  split_info <- data_bundle$split_info
  n_train <- split_info$n_train
  T_use <- split_info$T_use
  H_forecast <- split_info$H_forecast

  if (data_bundle$mode == "sim") {
    y_full <- data_bundle$y_full
    readout_design <- ms_build_readout_design_sim(y_full, cfg$desn, readout_include_input, readout_reservoir_lags)
    X_aug_all <- readout_design$X_aug_all
    keep_aug_abs <- readout_design$keep_aug_abs

    keep_train_abs <- keep_aug_abs[keep_aug_abs <= n_train]
    row_sel_train <- which(keep_aug_abs %in% keep_train_abs)
    X_train <- X_aug_all[row_sel_train, , drop = FALSE]
    y_train_keep <- y_full[keep_train_abs]

    idx_fc_abs <- seq.int(n_train + 1L, T_use)
    row_sel_fc <- which(keep_aug_abs %in% idx_fc_abs)
    X_fc1 <- X_aug_all[row_sel_fc, , drop = FALSE]
    y_forecast <- y_full[idx_fc_abs]

    if (isTRUE(readout_scale)) {
      scale_fit <- readout_scale_fit(X_train, has_intercept = isTRUE(cfg$desn$add_bias))
      X_train <- scale_fit$X
      X_fc1 <- readout_scale_apply(X_fc1, scale_fit$scale_info)
      readout_scale_info <- scale_fit$scale_info
    } else {
      readout_scale_info <- NULL
    }

    readout_spec <- list(
      include_input   = isTRUE(readout_include_input),
      input_position  = cfg$readout$input_position %||% "after_reservoir",
      input_lags_y    = if (isTRUE(readout_include_input)) seq_len(as.integer(cfg$desn$m)) else integer(0),
      input_lags_x    = list(),
      reservoir_lags  = as.integer(readout_reservoir_lags),
      y_lags          = integer(0),
      x_names         = character(0),
      x_lags          = list(),
      p_res           = ncol(readout_design$X_res_all),
      scale_info      = readout_scale_info
    )

    origin_info <- if (!is.null(origins_override)) origins_override else ms_build_origin_set_sim(split_info)
    origins_lead1 <- origin_info$origins_lead1
    targets <- origin_info$targets

    y_true <- y_forecast
    bt_y <- function(z) z
    xreg_all_lead1 <- NULL
    shared_fit <- readout_design$shared_fit
  } else {
    y_full <- data_bundle$y_full
    X_use <- data_bundle$X_use
    readout_design <- ms_build_readout_design_real(y_full, X_use, cfg, cfg$desn,
                                                   readout_include_input, readout_reservoir_lags, readout_scale)
    X_aug_all <- readout_design$X_aug_all
    keep_aug_abs <- readout_design$keep_aug_abs
    lag_max <- readout_design$lag_max

    washout <- as.integer(cfg$desn$washout %||% 0L)
    idx_tr_abs <- seq.int(lag_max + washout + 1L, n_train)
    idx_fc_abs <- seq.int(n_train + 1L, T_use)

    row_tr <- which(keep_aug_abs %in% idx_tr_abs)
    row_fc <- which(keep_aug_abs %in% idx_fc_abs)
    X_train <- X_aug_all[row_tr, , drop = FALSE]
    X_fc1 <- X_aug_all[row_fc, , drop = FALSE]
    y_tr_keep <- y_full[keep_aug_abs[row_tr]]
    y_fc <- y_full[idx_fc_abs]

    if (isTRUE(readout_scale)) {
      scale_fit <- readout_scale_fit(X_train, has_intercept = isTRUE(cfg$desn$add_bias))
      X_train <- scale_fit$X
      X_fc1 <- readout_scale_apply(X_fc1, scale_fit$scale_info)
      readout_scale_info <- scale_fit$scale_info
    } else {
      readout_scale_info <- NULL
    }

    x_names <- if (!is.null(X_use)) colnames(X_use) else character(0)
    x_lags_list <- list()
    if (length(x_names)) {
      x_lags_list <- rep(list(as.integer(readout_design$lags_x)), length(x_names))
      names(x_lags_list) <- x_names
    }

    readout_spec <- list(
      include_input  = isTRUE(readout_include_input),
      input_position = cfg$readout$input_position %||% "after_reservoir",
      input_lags_y   = if (isTRUE(readout_include_input)) as.integer(readout_design$lags_y) else integer(0),
      input_lags_x   = if (isTRUE(readout_include_input)) x_lags_list else list(),
      reservoir_lags = as.integer(readout_reservoir_lags),
      y_lags         = if (isTRUE(readout_include_input)) integer(0) else as.integer(readout_design$lags_y),
      x_names        = x_names,
      x_lags         = if (isTRUE(readout_include_input)) list() else x_lags_list,
      p_res          = ncol(readout_design$X_res_all),
      scale_info     = readout_scale_info
    )

    origin_info <- if (!is.null(origins_override)) origins_override else ms_build_origin_set_real(split_info, data_bundle$X_all, forecast_horizon)
    origins_lead1 <- origin_info$origins_lead1
    targets <- origin_info$targets
    xreg_all_lead1 <- origin_info$xreg_all_lead1

    y_true <- data_bundle$bt_y(y_fc)
    bt_y <- data_bundle$bt_y
    shared_fit <- readout_design$shared_fit
    y_train_keep <- y_tr_keep
  }

  if (length(targets) != H_forecast) {
    stop("Origin-mode targets length does not match H_forecast.")
  }

  vb_control <- ms_build_vb_control(cfg, p_vec[1L])

  fits_fc <- vector("list", length(p_vec))
  names(fits_fc) <- paste0("p=", p_vec)

  for (i in seq_along(p_vec)) {
    p0 <- p_vec[i]
    vb_control <- ms_build_vb_control(cfg, p0)

    fit_exal <- ms_fit_one_tau(X_train, y_train_keep, p0, cfg, vb_control)

    pred_draws <- exal_vb_posterior_draws(fit_exal, nd = nd_draws)

    fit_meta <- shared_fit$meta
    fit_meta$readout_spec <- readout_spec
    fit_q <- list(
      fit = fit_exal,
      X = X_train,
      y_fit = y_train_keep,
      reservoir = shared_fit$reservoir,
      states = shared_fit$states,
      meta = fit_meta
    )
    class(fit_q) <- "qdesn_fit"

    fore <- forecast_lattice.qdesn_fit(
      fit_q,
      y_all = y_full,
      origins = origins_lead1,
      H = 1L,
      nd = nrow(pred_draws$beta),
      xreg_all = xreg_all_lead1,
      y_obs_last = T_use,
      lead_weights = 1,
      mix_nd = nrow(pred_draws$beta),
      chunk = cfg$sampling$chunk %||% 250L,
      seed = (cfg$synthesis$seed %||% 123L) + round(1000 * p0),
      keep_origin_draws = FALSE,
      draws = pred_draws
    )

    yrep_fc_full <- bt_y(fore$mix$y)
    idx_obs <- which(fore$targets <= T_use)
    yrep_fc <- yrep_fc_full[idx_obs, , drop = FALSE]

    fits_fc[[i]] <- list(yrep_fc = yrep_fc)
  }

  draws_list <- lapply(fits_fc, function(x) x$yrep_fc)
  synth_fc <- exdqlm_synthesize_from_draws(
    draws_list,
    p_vec,
    enforce_isotonic = isTRUE(cfg$synthesis$isotonic %||% TRUE),
    rearrange = isTRUE(cfg$synthesis$rearrange %||% TRUE),
    grid_M = as.integer(cfg$synthesis$grid_M %||% 1001L),
    n_samp = synth_n_samp,
    seed = cfg$synthesis$seed %||% NULL,
    T_expected = length(y_true)
  )

  crps_fc <- ms_crps_vec(y_true, synth_fc$draws)
  crps_synth_mean <- mean(crps_fc, na.rm = TRUE)

  calcrps_mean <- NA_real_
  calcrps_max <- NA_real_
  calcrps_by_tau <- NULL

  if (isTRUE((cfg$model_selection$calcrps %||% list())$enabled)) {
    cal_rows <- lapply(seq_along(p_vec), function(i) {
      tau <- p_vec[i]
      yrep_tau <- fits_fc[[i]]$yrep_fc
      cal <- ms_calcrps_from_predictive_draws(y_true, yrep_tau, tau)
      data.frame(tau = tau, cal_crps = cal$cal_crps, stringsAsFactors = FALSE)
    })
    calcrps_by_tau <- do.call(rbind, cal_rows)
    calcrps_mean <- mean(calcrps_by_tau$cal_crps, na.rm = TRUE)
    calcrps_max <- max(calcrps_by_tau$cal_crps, na.rm = TRUE)
  }

  list(
    crps_synth_mean = crps_synth_mean,
    calcrps_mean = calcrps_mean,
    calcrps_max = calcrps_max,
    calcrps_by_tau = calcrps_by_tau,
    targets = targets,
    p_vec = p_vec,
    nd_draws = nd_draws,
    synth_n_samp = synth_n_samp,
    candidate_id = candidate_id,
    stage = stage_name
  )
}

ms_run_stage_v2 <- function(cfg, data_bundle, stage_spec, candidates, stage_idx, prev_summary = NULL) {
  stage_name <- stage_spec$name %||% paste0("stage", stage_idx)
  seeds <- stage_spec$seeds %||% c(1)

  origins_policy <- stage_spec$origins$policy %||% "all"
  origins_frac <- stage_spec$origins$frac %||% NULL
  origins_seed <- stage_spec$origins$seed %||% NULL
  origins_stride_k <- stage_spec$origins$stride_k %||% NULL

  origin_base <- if (data_bundle$mode == "real") {
    ms_build_origin_set_real(data_bundle$split_info, data_bundle$X_all, as.integer(stage_spec$horizon %||% cfg$forecast$horizon %||% 1L))
  } else {
    ms_build_origin_set_sim(data_bundle$split_info)
  }

  if (origins_policy != "all") {
    origin_base$origins_lead1 <- ms_deterministic_origin_subsample(origin_base$origins_lead1, origins_policy,
                                                                   frac = origins_frac, seed = origins_seed, stride_k = origins_stride_k)
    origin_base$origins_full <- origin_base$origins_lead1
    if (length(origin_base$origins_lead1)) {
      origin_base$targets <- seq.int(min(origin_base$origins_lead1) + 1L, max(origin_base$origins_lead1) + 1L)
    } else {
      origin_base$targets <- integer(0)
    }
  }

  origins_spec_id <- ms_origins_spec_id(origins_policy, origins_frac, origins_seed, origins_stride_k)
  weight_spec_id <- ms_weight_spec_id()
  p_vec_default <- cfg$p_vec %||% c(0.05, 0.50, 0.95)
  p_vec_stage <- ms_maybe_use_default(stage_spec$p_vec, p_vec_default)
  p_vec_id <- ms_p_vec_id(p_vec_stage)
  verify_window_id <- ms_verify_window_id(min(origin_base$targets), max(origin_base$targets), "lead1", origins_spec_id, weight_spec_id)

  rows <- list()
  cal_by_tau_rows <- list()

  for (cand_idx in seq_along(candidates)) {
    candidate <- candidates[[cand_idx]]
    candidate_id <- ms_candidate_id(candidate)

    for (seed in seeds) {
      set.seed(as.integer(seed))
      res <- ms_evaluate_candidate_v2(cfg, data_bundle, stage_spec, candidate, candidate_id, stage_name, origins_override = origin_base)

      rows[[length(rows) + 1L]] <- data.frame(
        stage = stage_name,
        candidate_idx = cand_idx,
        candidate_id = candidate_id,
        seed = seed,
        D = candidate$D %||% NA_integer_,
        n = if (!is.null(candidate$n)) paste(candidate$n, collapse = ",") else NA_character_,
        m = candidate$m %||% NA_integer_,
        alpha = candidate$alpha %||% NA_real_,
        rho = candidate$rho %||% NA_real_,
        desn_seed = candidate$seed %||% NA_real_,
        crps_synth_mean = res$crps_synth_mean,
        calcrps_mean = res$calcrps_mean,
        calcrps_max = res$calcrps_max,
        p_vec_id = p_vec_id,
        verify_window_id = verify_window_id,
        origins_spec_id = origins_spec_id,
        weight_spec_id = weight_spec_id,
        nd_draws = res$nd_draws,
        synth_n_samp = res$synth_n_samp,
        stringsAsFactors = FALSE
      )

      if (!is.null(res$calcrps_by_tau)) {
        cal_by_tau <- res$calcrps_by_tau
        cal_by_tau$stage <- stage_name
        cal_by_tau$candidate_id <- candidate_id
        cal_by_tau$candidate_idx <- cand_idx
        cal_by_tau$seed <- seed
        cal_by_tau$p_vec_id <- p_vec_id
        cal_by_tau$verify_window_id <- verify_window_id
        cal_by_tau$origins_spec_id <- origins_spec_id
        cal_by_tau$weight_spec_id <- weight_spec_id
        cal_by_tau$nd_draws <- res$nd_draws
        cal_by_tau$synth_n_samp <- res$synth_n_samp
        cal_by_tau_rows[[length(cal_by_tau_rows) + 1L]] <- cal_by_tau
      }
    }
  }

  candidates_tbl <- if (length(rows)) do.call(rbind, rows) else data.frame()
  cal_by_tau_tbl <- if (length(cal_by_tau_rows)) do.call(rbind, cal_by_tau_rows) else NULL

  summary_tbl <- candidates_tbl %>
    dplyr::group_by(candidate_id) %>
    dplyr::summarise(
      candidate_idx = dplyr::first(candidate_idx),
      stage = dplyr::first(stage),
      crps_synth_mean = mean(crps_synth_mean, na.rm = TRUE),
      calcrps_mean = mean(calcrps_mean, na.rm = TRUE),
      calcrps_max = max(calcrps_max, na.rm = TRUE),
      .groups = "drop"
    ) %>
    dplyr::arrange(crps_synth_mean)

  list(candidates = candidates_tbl, summary = summary_tbl, cal_by_tau = cal_by_tau_tbl)
}

ms_run_search_v2 <- function(cfg, data_bundle) {
  stages <- cfg$model_selection$stages %||% list()
  if (!length(stages)) stop("No stages specified for model selection.")

  all_candidates_rows <- list()
  all_cal_rows <- list()
  prev_candidates <- NULL
  prev_summary <- NULL

  for (i in seq_along(stages)) {
    stage <- stages[[i]]
    candidates <- ms_build_stage_candidates(stage, prev_candidates, prev_summary)
    if (!length(candidates)) stop("No candidates available for stage: ", stage$name %||% i)

    stage_res <- ms_run_stage_v2(cfg, data_bundle, stage, candidates, i, prev_summary)

    all_candidates_rows[[length(all_candidates_rows) + 1L]] <- stage_res$candidates
    if (!is.null(stage_res$cal_by_tau)) all_cal_rows[[length(all_cal_rows) + 1L]] <- stage_res$cal_by_tau

    prev_candidates <- candidates
    prev_summary <- stage_res$summary
  }

  candidates_tbl <- do.call(rbind, all_candidates_rows)
  cal_by_tau_tbl <- if (length(all_cal_rows)) do.call(rbind, all_cal_rows) else NULL

  summary_tbl <- candidates_tbl %>
    dplyr::group_by(candidate_id) %>
    dplyr::summarise(
      crps_synth_mean = mean(crps_synth_mean, na.rm = TRUE),
      calcrps_mean = mean(calcrps_mean, na.rm = TRUE),
      calcrps_max = max(calcrps_max, na.rm = TRUE),
      .groups = "drop"
    ) %>
    dplyr::arrange(crps_synth_mean) %>
    dplyr::mutate(rank = dplyr::row_number())

  list(candidates = candidates_tbl, summary = summary_tbl, cal_by_tau = cal_by_tau_tbl)
}

ms_write_results_v2 <- function(res, run_dir, cfg) {
  tables_dir <- file.path(run_dir, "tables")
  dir.create(tables_dir, recursive = TRUE, showWarnings = FALSE)

  readr::write_csv(res$candidates, file.path(tables_dir, "model_selection_candidates.csv"))
  readr::write_csv(res$summary, file.path(tables_dir, "model_selection_winner.csv"))

  if (!is.null(res$cal_by_tau)) {
    readr::write_csv(res$cal_by_tau, file.path(tables_dir, "calibration_by_tau.csv"))
    cal_summary <- res$cal_by_tau %>
      dplyr::group_by(candidate_id, stage) %>
      dplyr::summarise(
        cal_crps_mean = mean(cal_crps, na.rm = TRUE),
        cal_crps_max = max(cal_crps, na.rm = TRUE),
        .groups = "drop"
      )
    readr::write_csv(cal_summary, file.path(tables_dir, "calibration_summary.csv"))
  }

  best_id <- res$summary$candidate_id[1L]
  list(best_id = best_id)
}

ms_build_effective_cfg_for_best <- function(cfg, candidates_tbl, best_id) {
  best_row <- candidates_tbl %>% dplyr::filter(candidate_id == best_id) %>% dplyr::slice(1L)
  if (!nrow(best_row)) return(cfg)
  cfg
}

run_model_selection_v2 <- function(cfg, ds, run_dir) {
  mode <- tolower(cfg$pipeline$mode %||% ds$mode %||% "sim")
  cfg$pipeline$mode <- mode
  if (tolower(cfg$forecast$mode %||% "origin") != "origin") {
    stop("Model selection v2 supports only forecast.mode == 'origin'.")
  }

  data_bundle <- if (mode == "real") {
    ms_prepare_real_bundle(cfg, ds)
  } else {
    ms_prepare_sim_bundle(cfg, ds)
  }

  res <- ms_run_search_v2(cfg, data_bundle)
  out <- ms_write_results_v2(res, run_dir, cfg)

  best_row <- res$candidates %>% dplyr::filter(candidate_id == out$best_id) %>% dplyr::slice(1L)
  best_cfg <- cfg
  if (nrow(best_row)) {
    best_cfg$desn$D <- best_row$D
    if (!is.na(best_row$n)) {
      best_cfg$desn$n <- as.integer(strsplit(best_row$n, ",")[[1]])
    }
    best_cfg$desn$m <- best_row$m
    best_cfg$desn$alpha <- best_row$alpha
    best_cfg$desn$rho <- best_row$rho
    if (!is.na(best_row$desn_seed)) best_cfg$desn$seed <- best_row$desn_seed
  }

  ms_write_yaml(best_cfg, file.path(run_dir, "manifest", "model_selection_v2_best_cfg.yaml"))

  invisible(list(results = res, best_cfg = best_cfg))
}

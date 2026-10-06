iqt12_schema <- "independent_qdesn_training1000_exdqlm112_v1"
iqt12_tar_sha <- "de2de1021b0160ff13ce8ec3aa09fec47274d95f9737da125a718ffc313a49b9"
`%||%` <- function(x, y) if (is.null(x)) y else x
iqt12_read <- function(path) jsonlite::fromJSON(path, simplifyVector = TRUE,
  simplifyDataFrame = FALSE)
iqt12_json <- function(x, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  tmp <- paste0(path, ".tmp.", Sys.getpid())
  jsonlite::write_json(x, tmp, auto_unbox = TRUE, pretty = TRUE, digits = NA,
    null = "null", na = "null")
  stopifnot(file.rename(tmp, path)); path
}
iqt12_csv <- function(x, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  con <- if (grepl("[.]gz$", path)) gzfile(path, "wt") else file(path, "wt")
  on.exit(close(con)); write.csv(x, con, row.names = FALSE, na = ""); path
}
iqt12_hash <- function(paths, path) {
  paths <- sort(unique(normalizePath(paths, mustWork = TRUE)))
  iqt12_csv(data.frame(path = paths, bytes = file.info(paths)$size,
    sha256 = unname(tools::sha256sum(paths))), path)
}
iqt12_verify <- function(path) {
  m <- read.csv(path, stringsAsFactors = FALSE)
  stopifnot(nrow(m) > 0L, all(file.exists(m$path)),
    identical(unname(tools::sha256sum(m$path)), m$sha256))
  invisible(TRUE)
}

# Nominal SPD systems must not be changed by unconditional diagonal jitter.
iqt12_solve <- function(A, b = NULL, jitter = 1e-10, max_tries = 8L) {
  stopifnot(is.matrix(A), nrow(A) == ncol(A), all(is.finite(A)))
  A <- (A + t(A)) / 2
  R <- tryCatch(chol(A), error = function(e) NULL)
  if (is.null(R)) stop("Nominal beta precision is not SPD; no silent jitter or eigen clipping.")
  V <- chol2inv(R)
  x <- if (is.null(b)) NULL else backsolve(R, forwardsolve(t(R), b))
  residual <- if (is.null(x)) 0 else max(abs(A %*% x - b)) / max(1, max(abs(b)))
  if (!is.finite(residual) || residual > 1e-6) stop("Nominal beta-system residual exceeds 1e-6.")
  list(inv = V, chol = R, x = if (is.null(x)) NULL else as.numeric(x),
    method = "nominal_cholesky_triangular", jitter_eps = 0,
    nominal_residual = residual, logdet = 2 * sum(log(diag(R))))
}

iqt12_runtime <- function(repo, library) {
  .libPaths(c(normalizePath(library, mustWork = TRUE), .libPaths()))
  ns <- asNamespace("exdqlm")
  stopifnot(as.character(utils::packageVersion("exdqlm")) == "1.1.2",
    utils::packageDescription("exdqlm")$Repository == "CRAN",
    startsWith(find.package("exdqlm"), normalizePath(library)))
  options(exdqlm.use_cpp_mcmc = TRUE, exdqlm.cpp_mcmc_mode = "fast",
    exdqlm.use_cpp_postpred = FALSE)
  e <- new.env(parent = ns)
  core <- c("00_utils.R", "utils_require_fun.R", "gamma_bounds.R", "exal.R",
    "priors_beta.R", "qdesn_rhs_prior.R", "qdesn_rhs_ns_prior.R",
    "exal_inference_config.R", "exal_sigmagam_structured.R",
    "exal_mcmc_collapsed_scale_shape.R", "exal_online_state.R", "exal_online_step.R",
    "exal_ldvb_engine.R", "exal_ldvb_fit.R",
    "exal_mcmc_fit.R", "qdesn_dlm_decomposition.R", "qdesn_vb_warm_start.R",
    "qdesn_vb.R", "qdesn_normal.R")
  for (f in core) sys.source(file.path(repo, "R", f), e)
  e$L.fn <- get("L.fn", envir = ns)
  e$U.fn <- get("U.fn", envir = ns)
  e$.solve_sympd <- iqt12_solve
  environment(e$.solve_sympd) <- e
  e$.normal_desn_sym_solve <- function(P, h = NULL) .solve_sympd(P, h)
  environment(e$.normal_desn_sym_solve) <- e
  # Study engines are private; official dynamic functions keep their CRAN namespace.
  study <- c("utils.R", "atomic_specs.R", "source_registry.R", "model_builders.R", "metric_intervals_v1.R",
    "exdqlm_rolling_state.R", "independent_qdesn_full_redesign_v2_runtime.R",
    "independent_qdesn_corrected_forecast_v3.R", "independent_dgp_oracle_reference_v1.R")
  for (f in study) sys.source(file.path(repo, "validation/fitforecast_v2/R", f), e)
  e$iqt12_loaded_files <- c(file.path(repo, "R", core),
    file.path(repo, "validation/fitforecast_v2/R", study))
  e
}

iqt12_window <- function(fold, N = 1000L) {
  end <- switch(fold, A = 8500L, B = 8750L, final = 9000L,
    stop("Unknown window"))
  stopifnot(N %in% c(500L, 1000L))
  train <- seq.int(end - N + 1L, end)
  wash <- seq.int(min(train) - 500L, min(train) - 1L)
  list(fold = fold, N = N, train = train, washout = wash,
    buffer = seq.int(min(wash) - 390L, min(wash) - 1L),
    origins = if (fold == "final") seq.int(9000L, 9990L, 30L) else
      seq.int(end, end + 220L, 5L), end = if (fold == "final") 10000L else end + 250L,
    horizon = 30L)
}
iqt12_grid <- function(w) {
  do.call(rbind, lapply(w$origins, function(o) {
    h <- seq_len(min(w$horizon, w$end - o))
    data.frame(origin = o, lead = h, target = o + h)
  }))
}
iqt12_unpack <- function(x) as.integer(strsplit(as.character(x), ";", fixed = TRUE)[[1]])

iqt12_preprocess <- function(y, method) {
  center <- if (method == "median_mad") median(y) else mean(y)
  scale <- if (method == "median_mad") mad(y) else sd(y)
  stopifnot(is.finite(center), is.finite(scale), scale > 1e-12)
  list(center = center, scale = scale)
}

iqt12_step <- function(object, h, lags) {
  r <- object$reservoir; meta <- object$meta
  z <- (lags - meta$lag_center) / meta$lag_scale
  if (meta$input_bound == "tanh") z <- tanh(z / meta$input_bound_divisor)
  u <- c(meta$win_scale_bias, z * meta$win_scale_global)
  for (d in seq_len(r$D)) {
    input <- if (d == 1L) u else h[[d - 1L]]
    h[[d]] <- as.numeric((1 - r$alpha[d]) * h[[d]] + r$alpha[d] *
      tanh(r$W[[d]] %*% h[[d]] + r$Win[[d]] %*% input))
  }
  x <- c(1, h[[r$D]], unlist(head(h, -1L), use.names = FALSE))
  list(h = h, x = x)
}

iqt12_roll <- function(object, y, first, initial = 0) {
  r <- object$reservoir
  stopifnot(first > r$m, first <= length(y), all(r$Q_is_identity))
  H <- lapply(r$n, function(n) matrix(0, length(y), n))
  X <- matrix(NA_real_, length(y), sum(r$n) + 1L)
  h <- lapply(r$n, function(n) rep(initial, n))
  for (t in seq.int(first, length(y))) {
    one <- iqt12_step(object, h, y[t - seq_len(r$m)])
    h <- one$h; X[t, ] <- one$x
    for (d in seq_len(r$D)) H[[d]][t, ] <- h[[d]]
  }
  list(H = H, X = X)
}

iqt12_design <- function(e, cfg, source, last = max(cfg$window$train)) {
  w <- cfg$window; c <- cfg$candidate
  first <- min(w$buffer); y0 <- source$y[seq.int(first, last)]
  train <- w$train - first + 1L
  # Scale only: a zero-centered source intercept prior remains zero-centered.
  scale <- sd(source$y[w$train]); stopifnot(scale > 0)
  y <- y0 / scale
  prep <- iqt12_preprocess(y[seq_len(max(train))], c$center_scale)
  n <- iqt12_unpack(c$n); D <- length(n); m <- as.integer(c$m)
  args <- list(y = y, p0 = cfg$p, D = D, n = n, n_tilde = head(n, -1L),
    m = m, input_mode = "raw_y_lags", standardize_inputs = TRUE,
    input_center_scale = c$center_scale,
    input_bound = if (c$input_bound == "tanh_z_over_3") "tanh" else "none",
    input_bound_divisor = if (c$input_bound == "tanh_z_over_3") 3 else 1,
    lag_center_override = prep$center, lag_scale_override = prep$scale,
    win_scale_global = c$input_gain, win_scale_bias = 1,
    alpha = c$alpha, rho = rep(c$rho, D), act_f = "tanh", act_k = "identity",
    topology = list(mode = "exact_fanin", recurrent_indegree = rep(c$recurrent_indegree, D),
      input_fanin = c$input_fanin, interlayer_fanin = c$interlayer_fanin,
      row_normalize_inputs = TRUE), w_dist = function(n) runif(n, -1, 1),
    in_dist = function(n) runif(n, -1, 1), washout = max(train) - length(train),
    add_bias = TRUE, state_noise_sd = 0, seed = c$matrix_seed, fit_readout = FALSE)
  object <- do.call(e$qdesn_fit_vb, args)
  object$reservoir$W <- lapply(object$reservoir$W, Matrix::Matrix, sparse = TRUE)
  object$reservoir$Win <- lapply(object$reservoir$Win, Matrix::Matrix, sparse = TRUE)
  first_update <- min(w$washout) - first + 1L
  rolled <- iqt12_roll(object, y, first_update)
  alternate <- iqt12_roll(object, y[seq_len(min(train))], first_update, initial = .5)
  dependence <- max(abs(rolled$X[min(train), ] - alternate$X[min(train), ]))
  if (!is.finite(dependence)) stop("Nonfinite reservoir initialization-dependence diagnostic.")
  object$X <- rolled$X[train, , drop = FALSE]
  object$y_fit <- y[train]; object$meta$keep_idx <- train
  object$meta$drop <- min(train) - 1L
  object$states$H_all <- rolled$H
  object$states$H_tilde <- head(rolled$H, -1L)
  object$states$H_last <- tail(rolled$H, 1L)[[1]]
  stopifnot(nrow(object$X) == w$N, ncol(object$X) == sum(n) + 1L,
    all(object$reservoir$Q_is_identity), all(is.finite(object$X)))
  list(object = object, source = source, y = y, scale = scale, first = first,
    train = train, all_X = rolled$X, initialization_dependence = dependence,
    preprocessing = prep, design_hash = digest::digest(object$X, algo = "sha256"))
}

iqt12_prior <- function(e, cfg, scale) {
  rhs <- list(tau0 = cfg$candidate$tau_source / scale,
    a_zeta = 2, b_zeta = cfg$candidate$slab_source / scale^2,
    shrink_intercept = FALSE, intercept_prec = 1e-16 * scale^2, n_inner = 2L)
  prior <- e$exal_make_beta_prior(type = "rhs_ns", rhs = rhs)
  old <- prior$expected_prec
  prior$expected_prec <- function(state, p) {
    z <- old(state, p); z[1] <- rhs$intercept_prec; z
  }
  list(beta = prior, rhs = rhs, sigma = list(a = 1, b = cfg$candidate$sigma_b_source / scale))
}

iqt12_normal <- function(e, cx, cfg) {
  prior <- iqt12_prior(e, cfg, cx$scale)
  readout <- e$normal_desn_fit(cx$object$X, cx$object$y_fit,
    beta_prior_type = "rhs_ns", rhs = prior$rhs,
    omega_prior = list(a = 1, b = cfg$candidate$omega_b_source / cx$scale^2),
    control = list(max_iter = cfg$normal_iter, tol = 1e-4,
      covariance = if (ncol(cx$object$X) <= 500L) "full" else "woodbury_diagonal"))
  z <- cx$object; z$fit <- readout; class(z) <- c("qdesn_normal_fit", "qdesn_fit")
  z
}

iqt12_quantile <- function(e, cx, cfg, init = NULL) {
  prior <- iqt12_prior(e, cfg, cx$scale)
  if (cfg$engine == "mcmc" && !is.null(cfg$warm_path)) {
    stopifnot(unname(tools::sha256sum(cfg$warm_path)) == cfg$warm_sha)
    warm <- iqt12_read(cfg$warm_path)
    stopifnot(warm$design_hash == cx$design_hash)
    initial <- warm$initial
  } else {
  if (is.null(init)) {
    normal <- iqt12_normal(e, cx, cfg)
    init <- e$qdesn_normal_to_vb_init(normal, cfg$likelihood, "rhs_ns", cfg$p)
    init$beta_state <- NULL
  }
  control <- e$exal_make_vb_control(max_iter = cfg$vb_iter, tol = 1e-4,
    tol_par = 1e-4, n_samp_xi = 400L, min_iter_elbo = 10L,
    verbose = FALSE, sigmagam = e$exal_make_vb_sigmagam_control(),
    beta_covariance = list(approximation = "full", label_uncertainty = TRUE))
  set.seed(cfg$seed)
  vb <- e$exal_ldvb_fit(cx$object$y_fit, cx$object$X, cfg$p,
    gamma_bounds = c(e$L.fn(cfg$p), e$U.fn(cfg$p)), vb_control = control,
    likelihood_family = cfg$likelihood, init = init,
    al_fixed_gamma = if (cfg$likelihood == "al") 0 else NULL,
    prior_gamma = list(mu0 = 0, s20 = 10), prior_sigma = prior$sigma,
    beta_prior_obj = prior$beta)
  if (cfg$engine == "vb") return(vb)
  initial <- list(beta = as.numeric(vb$qbeta$m), sigma = vb$qsiggam$sigma_mean,
    gamma = if (cfg$likelihood == "al") 0 else vb$qsiggam$gamma_mean,
    v = vb$qv$E_v, s = vb$qs$E_s)
  }
  mc <- e$exal_make_mcmc_control(n_burn = cfg$burn, n_mcmc = cfg$retained,
    thin = 1L, init_from_vb = FALSE, verbose = TRUE, progress_every = 500L,
    store_latent_draws = FALSE, store_rhs_draws = FALSE,
    sigmagam = e$exal_make_mcmc_sigmagam_control(),
    slice = list(core_update_mode = if (cfg$likelihood == "exal")
      "m0_v_collapsed_support_logit" else "sigma_then_gamma"))
  mc$rng_seed <- cfg$seed
  mc$precision_beta <- list(enabled = TRUE, symmetrize = TRUE,
    jitter_ladder = 0, eigen_fallback = FALSE, trace = TRUE)
  fit <- e$exal_mcmc_fit(cx$object$y_fit, cx$object$X, cfg$p,
    gamma_bounds = c(e$L.fn(cfg$p), e$U.fn(cfg$p)), likelihood_family = cfg$likelihood,
    al_fixed_gamma = if (cfg$likelihood == "al") 0 else NULL,
    mcmc_control = mc, init = initial,
    prior_gamma = list(mu0 = 0, s20 = 10), prior_sigma = prior$sigma,
    beta_prior_obj = prior$beta)
  expected <- if (cfg$likelihood == "exal") "m0_v_collapsed_support_logit" else "sigma_then_gamma"
  stopifnot(fit$diagnostics$core_update_mode == expected,
    nrow(fit$samp.beta) == cfg$retained, all(is.finite(fit$samp.beta)))
  if (cfg$likelihood == "al") stopifnot(all(fit$samp.gamma == 0))
  fit
}

iqt12_draws <- function(e, fit, nd, seed) {
  set.seed(seed)
  draws <- e$exal_posterior_draws(fit, nd = nd, seed = seed)
  if (inherits(fit, "exal_vb") && identical(fit$qsiggam$factorization,
      "structured_qgamma_qsigma_given_gamma")) {
    pars <- e$.exal_sigmagam_structured_sample(fit$qsiggam, nd)
    draws$sigma <- pars$sigma; draws$gamma <- pars$gamma
    draws$sigmagam_draw_contract <- "structured_gamma_grid_conditional_GIG_sigma"
  } else draws$sigmagam_draw_contract <- if (inherits(fit, "exal_vb"))
    "AL_fixed_gamma_VB_logscale_approximation" else "retained_MCMC_pairs"
  stopifnot(all(is.finite(draws$beta)), all(is.finite(draws$sigma)), all(draws$sigma > 0))
  draws
}

iqt12_normal_forecast <- function(e, cx, cfg, object, draws) {
  w <- cfg$window; out <- list(); i <- 0L
  for (o in w$origins) {
    local <- o - cx$first + 1L; H <- min(w$horizon, w$end - o)
    index <- rep(seq_len(nrow(draws$beta)), each = cfg$inner)
    beta <- draws$beta[index, , drop = FALSE]; count <- length(index)
    h <- lapply(object$states$H_all, function(z) matrix(z[local, ], ncol = count,
      nrow = ncol(z)))
    lags <- matrix(rev(tail(cx$y[seq_len(local)], object$reservoir$m)),
      ncol = count, nrow = object$reservoir$m)
    values <- matrix(0, H, count)
    set.seed(cfg$seed + o)
    noise <- matrix(rnorm(H * count), H, count)
    noise <- sweep(noise, 2, sqrt(draws$omega2[index]), "*")
    meta <- object$meta; r <- object$reservoir
    for (lead in seq_len(H)) {
      z <- (lags - meta$lag_center) / meta$lag_scale
      if (meta$input_bound == "tanh") z <- tanh(z / meta$input_bound_divisor)
      u <- rbind(rep(meta$win_scale_bias, count), z * meta$win_scale_global)
      for (d in seq_len(r$D)) {
        input <- if (d == 1L) u else h[[d - 1L]]
        h[[d]] <- as.matrix((1 - r$alpha[d]) * h[[d]] + r$alpha[d] *
          tanh(r$W[[d]] %*% h[[d]] + r$Win[[d]] %*% input))
      }
      xx <- rbind(rep(1, count), h[[r$D]], do.call(rbind, head(h, -1L)))
      mu <- colSums(xx * t(beta)); values[lead, ] <- mu
      lags <- rbind(mu + noise[lead, ], head(lags, -1L))
    }
    means <- e$iqcf_v3_matrix_by_outer_draw(values, nrow(draws$beta), cfg$inner, "mean")
    i <- i + 1L; out[[i]] <- means * cx$scale
  }
  do.call(rbind, out)
}

iqt12_qforecast <- function(e, cx, cfg, fit, draws, progress = NULL) {
  object <- cx$object; object$fit <- fit; w <- cfg$window
  out <- plugin <- list()
  for (i in seq_along(w$origins)) {
    o <- w$origins[i]; local <- o - cx$first + 1L
    H <- min(w$horizon, w$end - o)
    bank <- e$iqcf_v3_make_noise_bank(draws, H, 1L,
      if (cfg$inner >= 128L) 256L else cfg$inner, cfg$seed + o)
    lattice <- e$iqcf_v3_nested_lattice(object, cx$y, local, H, draws,
      cfg$p, cfg$inner, seed = cfg$seed + o, noise_bank = bank,
      include_mean_readout_state = FALSE)
    out[[i]] <- lattice$oracle_location$mean_conditional_location[[1]] * cx$scale
    plugin[[i]] <- lattice$oracle_location$conditional_location_plugin[[1]] * cx$scale
    expected <- cx$all_X[local + 1L, , drop = FALSE] %*% t(draws$beta) * cx$scale
    stopifnot(max(abs(expected - out[[i]][1, , drop = FALSE])) <= 1e-6)
    if (!is.null(progress)) progress(i, length(w$origins))
  }
  list(primary = do.call(rbind, out), plugin = do.call(rbind, plugin))
}

iqt12_baseline_fit <- function(e, cfg, source) {
  base <- cfg$baseline
  base$train_start_source_index <- min(cfg$window$train)
  base$train_end_source_index <- max(cfg$window$train)
  # The current fit-start clock replaces the historical explicit fit-start index.
  base$latent_clock_start_source_index <- NULL
  if (!is.null(base$models)) base$models$latent_clock_start_source_index <- NULL
  model <- e$ffv2_build_dynamic_model(base, cfg$window$N)
  df <- as.numeric(base$models$df_value %||% .98)
  dimdf <- as.integer(base$models$dim_df %||% c(2, 4))
  if (length(df) == 1L) df <- rep(df, length(dimdf))
  control <- exdqlm::exal_make_vb_control(max_iter = cfg$vb_iter,
    tol = 1e-4, n_samp_xi = 400L, verbose = FALSE)
  set.seed(cfg$seed)
  y <- source$y[cfg$window$train]
  if (cfg$engine == "mcmc" && !is.null(cfg$warm_path)) {
    stopifnot(unname(tools::sha256sum(cfg$warm_path)) == cfg$warm_sha)
    vb <- iqt12_read(cfg$warm_path)$initial
    vb$theta.out$sm <- as.matrix(vb$theta.out$sm)
  } else vb <- exdqlm::exdqlmLDVB(y, cfg$p, model, df = df, dim.df = dimdf,
    dqlm.ind = cfg$likelihood == "al", fix.sigma = FALSE,
    n.samp = max(200L, cfg$outer), vb_control = control, verbose = FALSE)
  if (cfg$likelihood == "exal") stopifnot(
    vb$gammasig.out$factorization == "structured_qgamma_qsigma_given_gamma")
  if (cfg$engine == "vb") return(vb)
  set.seed(cfg$seed)
  fit <- exdqlm::exdqlmMCMC(y, cfg$p, model, df = df, dim.df = dimdf,
    dqlm.ind = cfg$likelihood == "al", fix.sigma = FALSE,
    n.burn = cfg$burn, n.mcmc = cfg$retained, init.from.vb = TRUE,
    vb_init_fit = vb, mh.proposal = "collapsed_slice", verbose = TRUE,
    trace.diagnostics = TRUE, verbose.every = 500L)
  if (cfg$likelihood == "exal") stopifnot(fit$mh.diagnostics$proposal == "collapsed_slice")
  stopifnot(length(fit$samp.sigma) == cfg$retained,
    dim(fit$samp.theta)[3] == cfg$retained)
  fit
}

iqt12_baseline_forecast <- function(e, cfg, source, fit, progress = NULL) {
  out <- list(); previous <- max(cfg$window$train); current <- fit
  for (i in seq_along(cfg$window$origins)) {
    o <- cfg$window$origins[i]
    if (o > previous) current <- e$ffv2_extend_theta_filtered_state(current,
      source$y[seq.int(previous + 1L, o)], method = if (cfg$engine == "mcmc")
        e$ffv2_exdqlm_mcmc_predictive_state_update_method() else
        e$ffv2_exdqlm_plugin_state_update_method())
    previous <- o; H <- min(cfg$window$horizon, cfg$window$end - o)
    future <- e$ffv2_make_future_model_arrays(current$model, H)
    fc <- exdqlm::exdqlmForecast(start.t = length(current$y), k = H, m1 = current,
      fFF = future$fFF, fGG = future$fGG, plot = FALSE,
      return.draws = TRUE, n.samp = cfg$outer, seed = cfg$seed + o)
    out[[i]] <- e$ffv2_latent_forecast_draws(fc, cfg$outer, cfg$seed + o + 100000L)
    if (!is.null(progress)) progress(i, length(cfg$window$origins))
  }
  do.call(rbind, out)
}

iqt12_scores <- function(fit, forecast, source, w, p) {
  g <- iqt12_grid(w)
  stopifnot(nrow(fit) == w$N, nrow(forecast) == nrow(g),
    ncol(fit) == ncol(forecast), all(is.finite(fit)), all(is.finite(forecast)))
  fiterr <- fit - source$q_target[w$train]
  err <- forecast - source$q_target[g$target]
  check <- function(q, y) {
    r <- y - q; colMeans(r * (p - (r < 0)))
  }
  draws <- data.frame(draw = seq_len(ncol(fit)), fit_rmse = sqrt(colMeans(fiterr^2)),
    fit_check_loss = check(fit, source$y[w$train]), forecast_mae = colMeans(abs(err)),
    forecast_rmse = sqrt(colMeans(err^2)), forecast_check_loss = check(forecast, source$y[g$target]))
  summary <- do.call(rbind, lapply(names(draws)[-1], function(k) {
    ci <- quantile(draws[[k]], c(.025, .975), names = FALSE, type = 8)
    data.frame(metric = k, mean = mean(draws[[k]]), lower = ci[1], upper = ci[2])
  }))
  profile <- cbind(g, q_mean = rowMeans(forecast), q025 = apply(forecast, 1, quantile, .025),
    q975 = apply(forecast, 1, quantile, .975), true = source$q_target[g$target],
    bias = rowMeans(err), mae = rowMeans(abs(err)),
    check_loss = rowMeans((source$y[g$target] - forecast) * (p - (source$y[g$target] < forecast))))
  list(draws = draws, summary = summary, profile = profile)
}

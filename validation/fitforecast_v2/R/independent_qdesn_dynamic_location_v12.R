idl12_schema <- "independent_qdesn_dynamic_location_v12"
idl12_arms <- c("dqlm", "static", "omega001", "omega005", "omega020")
idl12_omega <- c(dqlm = 0, static = 0, omega001 = .001,
  omega005 = .005, omega020 = .020)
idl12_stages <- c("smoke", "selection_warm", "selection",
  "confirmation_warm", "confirmation", "fresh_warm", "fresh")

idl12_compile <- function(repo, cache) {
  dir.create(cache, recursive = TRUE, showWarnings = FALSE)
  Rcpp::sourceCpp(file.path(repo, "validation/fitforecast_v2/cpp/dynamic_location_v12.cpp"),
    env = .GlobalEnv, cacheDir = cache, showOutput = FALSE, verbose = FALSE)
}

idl12_load <- function(cache) {
  # sourceCpp rewrites its index even on cache hits. Workers only read the
  # generated loader and immutable DLL, avoiding a concurrent index race.
  loader <- list.files(cache, pattern = "[.]cpp[.]R$", recursive = TRUE, full.names = TRUE)
  stopifnot(length(loader) == 1L)
  sys.source(loader, envir = .GlobalEnv)
  invisible(TRUE)
}

idl12_al_moments <- function(m, P, r, sigma, p) {
  stopifnot(length(p) == 1L, is.finite(p), p > 0, p < 1,
    all(is.finite(c(m, P, r, sigma))), all(P >= 0), all(sigma > 0))
  count <- max(length(m), length(P), length(r), length(sigma))
  m <- rep_len(m, count); P <- rep_len(P, count)
  r <- rep_len(r, count); sigma <- rep_len(sigma, count)
  result_m <- m; result_P <- P
  active <- which(P > 0)
  if (!length(active)) return(list(mean = m, variance = P))
  mm <- m[active]; vv <- P[active]; rr <- r[active]; ss <- sigma[active]
  sd <- sqrt(vv)
  # Both likelihood pieces are exponential tilts of a truncated normal.
  upper <- function(mu, threshold) {
    t <- (threshold - mu) / sd
    logmass <- pnorm(t, log.p = TRUE)
    lambda <- exp(dnorm(t, log = TRUE) - logmass)
    factor <- 1 - t * lambda - lambda^2
    tail <- t < -25
    if (any(tail)) {
      x <- -t[tail]
      lambda[tail] <- x + 1/x - 2/x^3 + 10/x^5 - 74/x^7
      factor[tail] <- 1/x^2 - 6/x^4 + 50/x^6 - 518/x^8
    }
    stopifnot(all(is.finite(lambda)), all(factor >= -1e-10))
    list(mean = mu - sd * lambda, variance = vv * pmax(factor, 0),
      logmass = logmass)
  }
  ml <- mm + vv * p / ss
  mr <- mm - vv * (1 - p) / ss
  left <- upper(ml, rr)
  mirrored <- upper(-mr, -rr)
  right <- list(mean = -mirrored$mean, variance = mirrored$variance)
  ll <- p * (mm - rr) / ss + .5 * vv * (p / ss)^2 + left$logmass
  lr <- (1 - p) * (rr - mm) / ss +
    .5 * vv * ((1 - p) / ss)^2 + mirrored$logmass
  weight <- plogis(ll - lr)
  mean <- weight * left$mean + (1 - weight) * right$mean
  variance <- weight * left$variance + (1 - weight) * right$variance +
    weight * (1 - weight) * (left$mean - right$mean)^2
  result_m[active] <- mean; result_P[active] <- variance
  stopifnot(all(is.finite(c(result_m, result_P))), all(result_P >= 0))
  list(mean = result_m, variance = result_P)
}

idl12_filter <- function(y, location, sigma, omega, initial, p, seed) {
  stopifnot(is.matrix(location), length(y) == nrow(location),
    length(initial) == ncol(location), length(sigma) == ncol(location),
    is.finite(omega), omega > 0)
  set.seed(seed)
  nd <- length(initial); m <- a <- as.numeric(initial); P <- numeric(nd)
  particles <- means <- matrix(0, length(y) + 1L, nd)
  particles[1L, ] <- means[1L, ] <- initial
  variances <- matrix(0, length(y) + 1L, nd)
  for (t in seq_along(y)) {
    R <- P + omega^2
    prediction <- a + omega * rnorm(nd)
    updated <- idl12_al_moments(m, R, y[t] - location[t, ], sigma, p)
    # Gaussian ADF transport preserves a shared outer-draw identity over time.
    a <- updated$mean + sqrt(updated$variance / R) * (prediction - m)
    m <- updated$mean; P <- updated$variance
    particles[t + 1L, ] <- a; means[t + 1L, ] <- m
    variances[t + 1L, ] <- P
  }
  list(particles = particles, means = means, variances = variances,
    contract = "frozen_training_parameters_AL_Gaussian_ADF_transport_no_parameter_reweighting")
}

idl12_fit <- function(e, cx, cfg, progress = NULL) {
  stopifnot(cfg$likelihood == "al", cfg$omega_scaled >= 0)
  if (cfg$omega_scaled == 0) return(iqt12_quantile(e, cx, cfg))
  init <- iqt12_read(cfg$warm_path)
  stopifnot(unname(tools::sha256sum(cfg$warm_path)) == cfg$warm_sha,
    identical(init$design_hash, cx$design_hash))
  X <- cx$object$X; y <- as.numeric(cx$object$y_fit)
  n <- nrow(X); k <- ncol(X); p <- cfg$p; omega <- cfg$omega_scaled
  prior <- iqt12_prior(e, cfg, cx$scale)
  sample_v <- get(".sample_gig_devroye_required", envir = e, inherits = TRUE)
  state <- e$.exal_mcmc_rhs_ns_prepare_state(prior$beta, k, list(), NULL)
  beta <- as.numeric(init$initial$beta); sigma <- init$initial$sigma
  v <- as.numeric(init$initial$v); a <- numeric(n)
  stopifnot(length(beta) == k, length(v) == n, all(v > 0))
  A <- (1 - 2*p) / (p*(1-p)); B <- 2 / (p*(1-p))
  saved <- matrix(0, cfg$outer, k); offsets <- matrix(0, n, cfg$outer)
  selected <- unique(as.integer(round(seq(1, cfg$retained, length.out = cfg$outer))))
  stopifnot(length(selected) == cfg$outer)
  trace <- matrix(0, cfg$retained, 5L,
    dimnames = list(NULL, c("sigma", "intercept", "offset_end", "tau", "slab")))
  set.seed(cfg$seed)
  start <- proc.time()[["elapsed"]]
  for (iter in seq_len(cfg$burn + cfg$retained)) {
    residual <- y - drop(X %*% beta) - a
    chi <- residual^2 / (B * sigma)
    psi <- (A^2/B + 2) / sigma
    positive <- chi > 0
    v[positive] <- as.numeric(sample_v(1L, p = .5,
      a = psi, b_vec = chi[positive], context = "dynamic_location_v12_AL_v"))
    v[!positive] <- rgamma(sum(!positive), shape = .5, rate = psi/2)
    stopifnot(all(is.finite(v)), all(v > 0))
    W <- 1 / (B * sigma * v)
    precision <- crossprod(X * sqrt(W))
    diag(precision) <- diag(precision) + e$.exal_mcmc_rhs_ns_precisions(state, k)
    beta <- e$.exal_mcmc_sample_mvnorm_prec(
      crossprod(X, W * (y - a - A*v)), precision,
      precision_beta_cfg = list(enabled = TRUE, symmetrize = TRUE,
        jitter_ladder = 0, eigen_fallback = FALSE))$draw
    a <- idl12_ffbs_cpp(y - drop(X %*% beta) - A*v, B*sigma*v, omega^2)$draw
    residual <- y - drop(X %*% beta) - a - A*v
    sigma <- 1 / rgamma(1L, shape = prior$sigma$a + 1.5*n,
      rate = prior$sigma$b + sum(residual^2/(2*B*v) + v))
    state <- e$.exal_mcmc_rhs_ns_gibbs_update(state, beta, prior$beta)$state
    stopifnot(is.finite(sigma), sigma > 0, all(is.finite(c(beta, a))))
    if (iter > cfg$burn) {
      j <- iter - cfg$burn
      trace[j, ] <- c(sigma, beta[1L], tail(a, 1L), sqrt(state$tau2), state$zeta2)
      save <- match(j, selected)
      if (!is.na(save)) { saved[save, ] <- beta; offsets[, save] <- a }
    }
    if (!is.null(progress) && (iter %% 50L == 0L || iter == cfg$burn + cfg$retained))
      progress(iter, cfg$burn + cfg$retained)
  }
  list(beta = saved, offset = offsets, sigma = trace[selected, "sigma"],
    gamma = rep(0, cfg$outer), selected = selected, trace = trace,
    elapsed = proc.time()[["elapsed"]] - start,
    target = "joint_AL_RHS_NS_static_beta_anchored_scalar_random_walk")
}

idl12_particle <- function(e, object, y, local, H, draws, noise,
                          conditioning, multiplier, offset, innovations) {
  r <- object$reservoir; meta <- object$meta; count <- nrow(draws$beta)
  stopifnot(all(r$Q_is_identity), all(draws$gamma == 0),
    identical(dim(innovations), c(as.integer(H), count)))
  h <- lapply(object$states$H_all, function(z)
    matrix(z[local, ], nrow = ncol(z), ncol = count))
  lags <- matrix(y[local - seq_len(r$m) + 1L], r$m, count)
  A <- (1-2*meta$p0)/(meta$p0*(1-meta$p0)); B <- 2/(meta$p0*(1-meta$p0))
  mu <- yrep <- matrix(0, H, count)
  for (lead in seq_len(H)) {
    offset <- offset + innovations[lead, ]
    z <- (lags - meta$lag_center) / meta$lag_scale
    if (meta$input_bound == "tanh") z <- tanh(z / meta$input_bound_divisor)
    u <- rbind(rep(meta$win_scale_bias, count), z * meta$win_scale_global)
    for (d in seq_len(r$D)) {
      input <- if (d == 1L) u else h[[d-1L]]
      h[[d]] <- as.matrix((1-r$alpha[d])*h[[d]] + r$alpha[d]*
        tanh(r$W[[d]] %*% h[[d]] + r$Win[[d]] %*% input))
    }
    x <- t(igc7_condition_apply(t(rbind(rep(1, count), h[[r$D]],
      do.call(rbind, head(h, -1L)))), conditioning)) * multiplier
    mu[lead, ] <- colSums(x * t(draws$beta)) + offset
    yrep[lead, ] <- mu[lead, ] + A*noise$v[lead, ] +
      sqrt(B*draws$sigma*noise$v[lead, ])*noise$z[lead, ]
    lags <- rbind(yrep[lead, ], head(lags, -1L))
  }
  stopifnot(all(is.finite(c(mu, yrep))))
  list(mu_draws = mu, yrep = yrep)
}

idl12_forecast <- function(e, cx, cfg, fit, progress = NULL) {
  nd <- nrow(fit$beta); w <- cfg$window; train_end <- max(w$train)
  draws <- list(beta = fit$beta, sigma = fit$sigma, gamma = fit$gamma)
  observations <- seq.int(train_end + 1L, max(w$origins))
  if (max(w$origins) == train_end) observations <- integer()
  location <- cx$all_X[observations - cx$first + 1L, , drop = FALSE] %*% t(fit$beta)
  filtered <- idl12_filter(cx$y[observations - cx$first + 1L], location,
    fit$sigma, cfg$omega_scaled, fit$offset[nrow(fit$offset), ], cfg$p, cfg$seed + 17L)
  output <- plugin <- guards <- components <- list()
  multiplier <- cx$readout_multiplier
  for (i in seq_along(w$origins)) {
    o <- w$origins[i]; local <- o - cx$first + 1L; H <- min(w$horizon, w$end-o)
    a <- filtered$particles[o - train_end + 1L, ]
    bank <- e$iqcf_v3_make_noise_bank(draws, H, 1L,
      if (cfg$inner >= 128L) 256L else cfg$inner, cfg$seed + o)
    noise <- e$iqcf_v3_subset_noise_bank(bank, cfg$inner)[[1L]]
    stopifnot(cfg$inner %% 2L == 0L)
    set.seed(cfg$seed + o + 31L)
    base <- matrix(rnorm(H * nd * cfg$inner/2L), H)
    innovations <- matrix(0, H, nd*cfg$inner)
    for (j in seq_len(nd)) {
      half <- base[, (j-1L)*cfg$inner/2L + seq_len(cfg$inner/2L), drop = FALSE]
      innovations[, (j-1L)*cfg$inner + seq_len(cfg$inner)] <-
        cbind(half, -half) * cfg$omega_scaled
    }
    means <- matrix(0, H, nd)
    batches <- split(seq_len(nd), ceiling(seq_len(nd)/max(1L, 256L %/% cfg$inner)))
    for (ids in batches) {
      columns <- unlist(lapply(ids, function(j) (j-1L)*cfg$inner + seq_len(cfg$inner)))
      subset <- e$iqcf_v3_subset_draws(draws, ids)
      repeated <- e$iqcf_v3_repeat_draws(subset, cfg$inner)
      path <- idl12_particle(e, cx$object, cx$y, local, H, repeated,
        lapply(noise, function(z) z[, columns, drop = FALSE]),
        cx$conditioning, multiplier, rep(a[ids], each = cfg$inner),
        innovations[, columns, drop = FALSE])
      means[, ids] <- e$iqcf_v3_matrix_by_outer_draw(path$mu_draws,
        length(ids), cfg$inner, "mean")
    }
    zero <- matrix(0, H, nd)
    plugin[[i]] <- idl12_particle(e, cx$object, cx$y, local, H, draws,
      list(v = zero, z = zero), cx$conditioning, multiplier, a, zero)$mu_draws * cx$scale
    output[[i]] <- means * cx$scale
    expected <- drop(cx$all_X[local+1L, , drop = FALSE] %*% t(fit$beta)) + a
    blocks <- ifu9_block_indices(cx$object$reservoir$n)
    contribution <- vapply(blocks, function(index)
      drop(cx$all_X[local+1L, index, drop = FALSE] %*% t(fit$beta[, index, drop = FALSE])),
      numeric(nd)) * cx$scale
    contribution <- cbind(contribution, dynamic_offset = a * cx$scale)
    covariance <- cov(contribution)
    components[[i]] <- data.frame(origin = o, block = colnames(contribution),
      mean = colMeans(contribution), variance_allocation = rowSums(covariance),
      full_variance = var(rowSums(contribution)))
    error <- max(abs(expected*cx$scale - output[[i]][1L, ]))
    stopifnot(error <= 1e-6)
    guards[[i]] <- data.frame(origin = o, readout_error = error, pass = TRUE)
    if (!is.null(progress)) progress(i, length(w$origins))
  }
  list(primary = do.call(rbind, output), plugin = do.call(rbind, plugin),
    guards = do.call(rbind, guards), filtered = filtered,
    components = do.call(rbind, components))
}

idl12_window <- function(fold, warm = FALSE, smoke = FALSE) {
  endpoint <- c(A = 8000L, B = 8300L, C = 8600L, FINAL = 9000L)[fold]
  stopifnot(length(endpoint) == 1L, !is.na(endpoint))
  list(N = as.integer(endpoint - 7000L), fold = fold,
    train = seq.int(7001L, endpoint), washout = 6501:7000, buffer = 6001:6500,
    origins = if (warm || smoke) as.integer(endpoint) else
      seq.int(endpoint, endpoint + if (fold == "FINAL") 990L else 210L, 30L),
    end = as.integer(endpoint + if (warm) 1L else if (smoke) 2L else
      if (fold == "FINAL") 1000L else 240L),
    horizon = if (warm) 1L else if (smoke) 2L else 30L, origin_stride = 30L)
}

idl12_phase_window <- function(w, shift) {
  stopifnot(shift %in% c(10L, 20L), length(w$origins) > 1L)
  w$origins <- w$origins + shift
  w$origins <- w$origins[w$origins < w$end]
  w
}

idl12_config <- function(state, arm, replica, fold, stage, chain = 1L) {
  cfg <- state$template
  cfg$schema <- idl12_schema; cfg$repo <- state$repo; cfg$run <- state$run
  cfg$library <- state$library; cfg$stage <- stage
  cfg$arm <- arm; cfg$replica <- replica; cfg$chain <- as.integer(chain)
  cfg$model <- if (arm == "dqlm") "baseline" else "qdesn"
  cfg$engine <- if (grepl("warm$", stage)) "vb" else "mcmc"
  cfg$window <- idl12_window(fold, cfg$engine == "vb", stage == "smoke")
  cfg$base_window <- cfg$window; cfg$rolling_window <- 0L; cfg$origin_offset <- NULL
  cfg$source_path <- state$sources[[replica]]$path
  cfg$source_sha <- state$sources[[replica]]$sha256
  cfg$layer1_scale <- 1; cfg$layer2_scale <- .25; cfg$layer3_scale <- 1
  cfg$omega_scaled <- unname(idl12_omega[arm])
  cfg$candidate$id <- substr(digest::digest(list(
    structure = cfg$candidate$structure_id, tau = cfg$candidate$tau_source,
    slab = cfg$candidate$slab_source, layer = c(1, .25, 1),
    omega = cfg$omega_scaled, version = idl12_schema), algo = "sha256"), 1, 20)
  cfg$id <- paste(stage, replica, fold, arm, paste0("c", chain), sep = "__")
  cfg$path <- file.path(state$run, "configs", paste0(cfg$id, ".json"))
  cfg$status_path <- file.path(state$run, "status", paste0(cfg$id, ".json"))
  cfg$evidence <- file.path(state$run, "evidence", cfg$id)
  cfg$seed <- as.integer(81300000L + match(replica, c("F1", "F2", paste0("N", 1:4))) *
    10000L + match(fold, c("A", "B", "C", "FINAL"))*100L + chain)
  cfg$outer <- if (cfg$engine == "vb") 4L else if (stage == "smoke") 8L else 300L
  cfg$inner <- if (cfg$engine == "vb" || stage == "smoke") 8L else 128L
  cfg$burn <- if (stage == "smoke") 20L else if (stage == "selection") 1500L else 3000L
  cfg$retained <- if (stage == "smoke") 40L else if (stage == "selection") 5000L else 10000L
  cfg$normal_iter <- if (stage == "smoke") 40L else 300L
  cfg$vb_iter <- if (stage == "smoke") 50L else 800L
  cfg$timeout <- if (stage == "smoke") 86400L else 259200L
  cfg$warm_path <- cfg$warm_sha <- NULL
  cfg$baseline$train_start_source_index <- min(cfg$window$train)
  cfg$baseline$train_end_source_index <- max(cfg$window$train)
  cfg$baseline$latent_clock_start_source_index <- NULL
  if (cfg$engine == "mcmc" && stage != "smoke") {
    warm_stage <- switch(stage, selection = "selection_warm",
      confirmation = "confirmation_warm", fresh = "fresh_warm")
    warm_id <- paste(warm_stage, replica, fold,
      if (arm == "dqlm") "dqlm" else "static", "c1", sep = "__")
    cfg$warm_path <- file.path(state$run, "evidence", warm_id, "mcmc_initializer.json")
    stopifnot(file.exists(cfg$warm_path))
    cfg$warm_sha <- unname(tools::sha256sum(cfg$warm_path))
  }
  cfg
}

idl12_sources <- function(repo, e) unique(c(ifd11_sources(repo, e),
  file.path(repo, "validation/fitforecast_v2", c(
    "R/independent_qdesn_dynamic_location_v12.R", "cpp/dynamic_location_v12.cpp",
    "scripts/independent_qdesn_dynamic_location_v12.R",
    "scripts/run_independent_qdesn_dynamic_location_v12.sh",
    "tests/test_independent_qdesn_dynamic_location_v12.R",
    "docs/INDEPENDENT_QDESN_DYNAMIC_LOCATION_V12_20261013.md"))))

idl12_materialize <- function(repo, run, parent, test_evidence) {
  stopifnot(!dir.exists(run), !length(system2("git",
    c("-C", repo, "status", "--porcelain"), stdout = TRUE)), file.exists(test_evidence))
  ifd11_verify(parent)
  old <- iqt12_read(file.path(parent, "campaign.json"))
  stopifnot(sum(ifd11_health(parent)$complete) == 26L,
    sum(ifd11_health(parent)$remaining) == 0L)
  for (dir in c("sources", "plans", "configs", "status", "evidence", "control", "review"))
    dir.create(file.path(run, dir), recursive = TRUE, showWarnings = FALSE)
  state <- list(schema = idl12_schema, repo = normalizePath(repo), run = normalizePath(run),
    library = old$library, parent = normalizePath(parent), template = old$template,
    head = system2("git", c("-C", repo, "rev-parse", "HEAD"), stdout = TRUE),
    shared_base = system2("git", c("-C", repo, "rev-parse",
      "origin/validation/shared-fitforecast-v2-1.0.0"), stdout = TRUE),
    pending_ancestry = "frozen_v11_plus_dedicated_v12_no_merge_into_shared",
    sources = list(), expected_jobs = list(smoke = 2L, selection_warm = 8L,
      selection = 20L, confirmation_warm = 4L, confirmation = 18L,
      fresh_warm = 8L, fresh = 36L), max_workers = 30L,
    selection_arms = idl12_arms, selection_replicas = c("F1", "F2"),
    decision_rule = "minimum_matched_training_only_observed_forecast_check_loss_no_diagnostic_exclusion",
    review_gate = "stop_after_30_jobs_before_confirmation",
    forecast_contract = "conditional_location_inner_mean_not_predictive_mixture_quantile",
    offset_filter = "AL_Gaussian_ADF_transport_frozen_parameters_no_reweighting",
    fresh_seeds = list(N1 = c(81411001L, 81411002L), N2 = c(81412001L, 81412002L),
      N3 = c(81413001L, 81413002L), N4 = c(81414001L, 81414002L)),
    publication = "coordinator_only_no_article_replacement_authorized")
  for (replica in c("F1", "F2")) {
    path <- file.path(run, "sources", paste0(replica, ".csv"))
    stopifnot(file.copy(old$sources[[replica]]$path, path),
      unname(tools::sha256sum(path)) == old$sources[[replica]]$sha256)
    state$sources[[replica]] <- list(path = normalizePath(path),
      sha256 = unname(tools::sha256sum(path)))
  }
  iqt12_json(state, file.path(run, "campaign.json"))
  e <- ifd11_runtime(repo, state$library)
  idl12_compile(repo, file.path(run, "control/cpp_cache"))
  env <- list(exdqlm_version = as.character(utils::packageVersion("exdqlm")),
    repository = utils::packageDescription("exdqlm")$Repository,
    package_path = find.package("exdqlm"), session = capture.output(sessionInfo()),
    numerical_threads = Sys.getenv(c("OMP_NUM_THREADS", "OPENBLAS_NUM_THREADS",
      "MKL_NUM_THREADS", "BLIS_NUM_THREADS", "RCPP_PARALLEL_NUM_THREADS")),
    RNG = RNGkind(), compiled_rng = "serial_R_controlled_no_OpenMP_in_new_helper")
  stopifnot(env$exdqlm_version == "1.1.2", env$repository == "CRAN")
  iqt12_json(env, file.path(run, "environment.json"))
  iqt12_csv(data.frame(key = c("CXX17", "CXX17FLAGS", "BLAS_LIBS", "LAPACK_LIBS", "SHLIB_OPENMP_CXXFLAGS"),
    value = vapply(c("CXX17", "CXX17FLAGS", "BLAS_LIBS", "LAPACK_LIBS", "SHLIB_OPENMP_CXXFLAGS"),
      function(key) paste(system2(file.path(R.home("bin"), "R"), c("CMD", "config", key),
        stdout = TRUE, stderr = TRUE), collapse = " "), "")),
    file.path(run, "compiler_settings.csv"))
  binaries <- list.files(file.path(run, "control/cpp_cache"), pattern = "[.]so$|[.]cpp[.]R$",
    recursive = TRUE, full.names = TRUE)
  stopifnot(length(binaries) == 2L)
  iqt12_hash(binaries, file.path(run, "compiled_helper_hashes.csv"))
  iqt12_hash(idl12_sources(repo, e), file.path(run, "source_hashes.csv"))
  iqt12_hash(list.files(file.path(state$library, "exdqlm"), recursive = TRUE,
    full.names = TRUE), file.path(run, "package_hashes.csv"))
  iqt12_hash(c(file.path(parent, c("campaign.json", "closeout.json", "closeout_manifest.csv")),
    test_evidence), file.path(run, "input_hashes.csv"))
  iqt12_hash(c(file.path(run, c("campaign.json", "environment.json", "source_hashes.csv",
    "package_hashes.csv", "input_hashes.csv", "compiler_settings.csv", "compiled_helper_hashes.csv")),
    vapply(state$sources, `[[`, "", "path")),
    file.path(run, "frozen_hashes.csv"))
  ifd11_plan(state, "smoke", lapply(c("dqlm", "omega005"), function(arm)
    idl12_config(state, arm, "F1", "A", "smoke")))
  invisible(state)
}

idl12_save_phase <- function(cfg, fit_draws, forecast, source, shift) {
  score <- iqt12_scores(fit_draws, forecast, source,
    idl12_phase_window(cfg$window, shift), cfg$p)$summary
  iqt12_csv(cbind(phase_offset = shift, score),
    file.path(cfg$evidence, paste0("phase", shift, "_summary.csv")))
}

idl12_worker <- function(path) {
  cfg <- iqt12_read(path)
  assign("iqt12_runtime_hook", ifd11_runtime, .GlobalEnv)
  iqt12_verify(file.path(cfg$run, "compiled_helper_hashes.csv"))
  idl12_load(file.path(cfg$run, "control/cpp_cache"))
  if (cfg$model == "baseline" || cfg$omega_scaled == 0 || cfg$engine == "vb") {
    # Hook the existing worker without altering its frozen fit or primary forecast.
    if (cfg$engine == "mcmc" && cfg$stage != "smoke" && cfg$model == "baseline") {
      original <- iqt12_baseline_forecast
      assign("iqt12_baseline_forecast", function(e, config, source, fit, progress = NULL) {
        result <- original(e, config, source, fit, progress)
        fd <- e$ffv2_dqlm_conditional_quantile_draws(fit, config$outer)
        for (shift in c(10L, 20L)) {
          replay <- config; replay$window <- idl12_phase_window(config$window, shift)
          idl12_save_phase(config, fd, original(e, replay, source, fit), source, shift)
        }
        result
      }, .GlobalEnv)
    }
    if (cfg$model == "qdesn") {
      assign("iqt12_design_hook", ilr10_design_hook, .GlobalEnv)
      original <- ilr10_qforecast_hook
      assign("iqt12_qforecast_hook", function(e, cx, config, fit, draws, progress = NULL) {
        result <- original(e, cx, config, fit, draws, progress)
        if (config$engine == "mcmc" && config$stage != "smoke")
          for (shift in c(10L, 20L)) {
            replay <- config; replay$window <- idl12_phase_window(config$window, shift)
            fc <- original(e, cx, replay, fit, draws)
            idl12_save_phase(config, cx$object$X %*% t(draws$beta) * cx$scale,
              fc$primary, cx$source, shift)
          }
        result
      }, .GlobalEnv)
    }
    iqt12_worker(path)
    return(invisible(TRUE))
  }
  start <- proc.time()[["elapsed"]]
  for (name in c("source", "package", "input", "frozen"))
    iqt12_verify(file.path(cfg$run, paste0(name, "_hashes.csv")))
  iqt12_verify(file.path(cfg$run, "plans", paste0(cfg$stage, "_hashes.csv")))
  stopifnot(unname(tools::sha256sum(cfg$source_path)) == cfg$source_sha,
    !file.exists(cfg$status_path))
  dir.create(cfg$evidence, recursive = TRUE, showWarnings = FALSE)
  progress <- function(phase, current = 0L, total = 0L)
    iqt12_json(list(status = "RUNNING", id = cfg$id, pid = Sys.getpid(), phase = phase,
      current = current, total = total, elapsed = proc.time()[["elapsed"]] - start), cfg$status_path)
  progress("preflight")
  tryCatch({
    e <- ifd11_runtime(cfg$repo, cfg$library)
    source <- read.csv(cfg$source_path)
    cx <- ilr10_design_hook(e, cfg, source, cfg$window$end)
    if (cfg$stage == "smoke") {
      warm_cfg <- cfg; warm_cfg$engine <- "vb"
      warm <- iqt12_quantile(e, cx, warm_cfg)
      cfg$warm_path <- file.path(cfg$evidence, "smoke_initializer.json")
      iqt12_json(list(design_hash = cx$design_hash, initial = list(
        beta = warm$qbeta$m, sigma = warm$qsiggam$sigma_mean,
        v = warm$qv$E_v, gamma = 0)), cfg$warm_path)
      cfg$warm_sha <- unname(tools::sha256sum(cfg$warm_path))
    }
    fit <- idl12_fit(e, cx, cfg, function(i, n) progress("joint_MCMC", i, n))
    fd <- (cx$object$X %*% t(fit$beta) + fit$offset) * cx$scale
    fc <- idl12_forecast(e, cx, cfg, fit, function(i, n) progress("forecast", i, n))
    if (cfg$stage != "smoke") for (shift in c(10L, 20L)) {
      replay <- cfg; replay$window <- idl12_phase_window(cfg$window, shift)
      phase <- idl12_forecast(e, cx, replay, fit)
      idl12_save_phase(cfg, fd, phase$primary, source, shift)
    }
    score <- ifd11_score_companions(fd, fc$primary, source, cfg$window, cfg$p)
    for (name in c("summary", "draws", "profile", "attribution"))
      iqt12_csv(score[[name]], file.path(cfg$evidence, switch(name,
        summary = "summary.csv", draws = "metric_draws.csv.gz",
        profile = "origin_lead.csv.gz", attribution = "covariance_attribution.csv")))
    iqt12_csv(cbind(source_index = cfg$window$train, fd),
      file.path(cfg$evidence, "fit_location_draws.csv.gz"))
    iqt12_csv(cbind(iqt12_grid(cfg$window), fc$primary),
      file.path(cfg$evidence, "forecast_location_draws.csv.gz"))
    iqt12_csv(cbind(iqt12_grid(cfg$window), fc$plugin),
      file.path(cfg$evidence, "plugin_location_draws.csv.gz"))
    iqt12_csv(data.frame(draw = seq_len(cfg$outer), iteration = fit$selected,
      sigma = fit$sigma, gamma = fit$gamma, fit$beta),
      file.path(cfg$evidence, "selected_parameters.csv.gz"))
    iqt12_csv(cbind(source_index = cfg$window$train, fit$offset * cx$scale),
      file.path(cfg$evidence, "offset_draws.csv.gz"))
    source_trace <- as.data.frame(fit$trace)
    source_trace[c("sigma", "intercept", "offset_end", "tau")] <-
      source_trace[c("sigma", "intercept", "offset_end", "tau")] * cx$scale
    source_trace$slab <- source_trace$slab * cx$scale^2
    iqt12_csv(source_trace, file.path(cfg$evidence, "nuisance_trace.csv.gz"))
    iqt12_csv(cbind(source_index = seq.int(max(cfg$window$train), max(cfg$window$origins)),
      fc$filtered$particles * cx$scale), file.path(cfg$evidence, "filtered_offset_draws.csv.gz"))
    iqt12_csv(fc$guards, file.path(cfg$evidence, "first_step_guard.csv"))
    iqt12_csv(fc$components, file.path(cfg$evidence, "origin_readout_components.csv"))
    grid <- iqt12_grid(cfg$window)
    iqt12_csv(data.frame(draw = seq_len(cfg$outer),
      observed_quantile_hit_rate = colMeans(source$y[grid$target] <= fc$primary),
      target_p = cfg$p), file.path(cfg$evidence, "observed_quantile_hit_draws.csv"))
    iqt12_json(list(target = fit$target, offset_filter = fc$filtered$contract,
      parameter_weights_updated = FALSE, omega_scaled = cfg$omega_scaled,
      omega_source = cfg$omega_scaled * cx$scale, scale = cx$scale,
      gamma_fixed = TRUE, readout_dimension = ncol(cx$object$X),
      design_hash = cx$design_hash, initialization_dependence = cx$initialization_dependence,
      ESS = lapply(as.data.frame(fit$trace), function(z) unname(coda::effectiveSize(z))),
      diagnostics_are_exclusion_gate = FALSE, fit_seconds = fit$elapsed,
      elapsed = proc.time()[["elapsed"]] - start,
      preprocessing_available_through = max(cfg$window$train)),
      file.path(cfg$evidence, "diagnostics.json"))
    files <- list.files(cfg$evidence, full.names = TRUE)
    manifest <- iqt12_hash(files, file.path(cfg$evidence, "manifest.csv"))
    iqt12_verify(manifest)
    iqt12_json(list(status = "SUCCESS", id = cfg$id, manifest = manifest,
      elapsed = proc.time()[["elapsed"]] - start, fitted_binary_payloads = 0L), cfg$status_path)
  }, error = function(err) {
    iqt12_json(list(status = "FAILED_IMPLEMENTATION", id = cfg$id,
      error = conditionMessage(err), elapsed = proc.time()[["elapsed"]] - start), cfg$status_path)
    stop(err)
  })
  invisible(TRUE)
}

idl12_health <- function(run) {
  state <- iqt12_read(file.path(run, "campaign.json"))
  expected <- unlist(state$expected_jobs)
  if (is.null(names(expected))) names(expected) <- idl12_stages
  do.call(rbind, lapply(idl12_stages, function(stage) {
    p <- ifd11_plan_status(run, stage)
    status <- if (is.null(p)) rep("GATED_NOT_MATERIALIZED", expected[[stage]]) else p$status
    stopifnot(length(status) == expected[[stage]])
    data.frame(stage = stage, planned_maximum = length(status), complete = sum(status == "SUCCESS"),
      failed = sum(grepl("^FAILED", status)), running = sum(status == "RUNNING"),
      pending = sum(status == "PENDING"), gated = sum(status == "GATED_NOT_MATERIALIZED"))
  }))
}

idl12_verify <- function(run) {
  for (name in c("source", "package", "input", "frozen"))
    iqt12_verify(file.path(run, paste0(name, "_hashes.csv")))
  if (file.exists(file.path(run, "compiled_helper_hashes.csv")))
    iqt12_verify(file.path(run, "compiled_helper_hashes.csv"))
  for (stage in idl12_stages) {
    p <- ifd11_plan_status(run, stage)
    if (is.null(p)) next
    iqt12_verify(file.path(run, "plans", paste0(stage, "_hashes.csv")))
    for (path in p$status_path[p$status == "SUCCESS"])
      iqt12_verify(iqt12_read(path)$manifest)
  }
  for (name in c("selection_review_hashes.csv", "confirmation_review_hashes.csv", "closeout_manifest.csv",
      "recovery_imports_hashes.csv"))
    if (file.exists(file.path(run, name))) iqt12_verify(file.path(run, name))
  if (file.exists(file.path(run, "fresh_extension_hashes.csv")))
    iqt12_verify(file.path(run, "fresh_extension_hashes.csv"))
  invisible(idl12_health(run))
}

idl12_summary <- function(run, stage) {
  plan <- ifd11_plan_status(run, stage)
  stopifnot(!is.null(plan), all(plan$status == "SUCCESS"))
  do.call(rbind, lapply(seq_len(nrow(plan)), function(i) {
    z <- read.csv(file.path(dirname(plan$config_path[i]), "..", "evidence", plan$id[i], "summary.csv"))
    cfg <- iqt12_read(plan$config_path[i])
    cbind(replica = cfg$replica, fold = cfg$window$fold,
      arm = cfg$arm, chain = cfg$chain, z[c("metric", "mean", "lower", "upper")])
  }))
}

idl12_selection <- function(run) {
  summary <- idl12_summary(run, "selection")
  check <- summary[summary$metric == "forecast_check_loss", ]
  stopifnot(nrow(check) == 20L, all(is.finite(check$mean)))
  rank <- aggregate(check$mean, list(arm = check$arm), mean)
  names(rank)[2L] <- "mean_forecast_check_loss"
  rank <- rank[order(rank$mean_forecast_check_loss, rank$arm), ]
  dynamic <- rank[rank$arm %in% idl12_arms[3:5], ]
  selected <- dynamic$arm[1L]
  static <- rank$mean_forecast_check_loss[rank$arm == "static"]
  gain <- dynamic$mean_forecast_check_loss[1L] < static
  paired <- merge(summary[summary$arm %in% idl12_arms[3:5], ],
    summary[summary$arm %in% c("dqlm", "static"), ],
    by = c("replica", "fold", "metric"), suffixes = c("_dynamic", "_control"))
  paired$strict_mean_gain <- paired$mean_dynamic < paired$mean_control
  paired$mean_difference <- paired$mean_dynamic - paired$mean_control
  paired$width_ratio <- (paired$upper_dynamic-paired$lower_dynamic)/
    (paired$upper_control-paired$lower_control)
  iqt12_csv(summary, file.path(run, "review/selection_summary.csv"))
  iqt12_csv(rank, file.path(run, "review/selection_ranking.csv"))
  iqt12_csv(paired, file.path(run, "review/selection_paired.csv"))
  plan <- ifd11_plan_status(run, "selection")
  phase <- list()
  for (i in seq_len(nrow(plan))) for (shift in c(10L, 20L)) {
    cfg <- iqt12_read(plan$config_path[i])
    path <- file.path(cfg$evidence, paste0("phase", shift, "_summary.csv"))
    if (!file.exists(path)) {
      # Synthetic orchestration fixtures may omit forecast-only companions.
      if (!isTRUE(iqt12_read(file.path(run, "campaign.json"))$synthetic_test_only))
        stop("Missing phase replay: ", path)
    } else phase[[length(phase)+1L]] <- cbind(replica = cfg$replica,
      fold = cfg$window$fold, arm = cfg$arm, read.csv(path))
  }
  if (length(phase)) iqt12_csv(do.call(rbind, phase), file.path(run, "review/selection_phase_summary.csv"))
  if (!isTRUE(iqt12_read(file.path(run, "campaign.json"))$synthetic_test_only))
    idl12_selection_pdf(run, plan, selected)
  decision <- list(status = "TRAINING_SELECTION_COMPLETE_REVIEW_REQUIRED", selected = selected,
    strict_check_gain_over_static = gain, selection_metric = "observed_forecast_check_loss",
    inspected_holdout_used_for_selection = FALSE, remaining_jobs_gated = 66L,
    diagnostic_exclusion_rule = FALSE, article_promotion = FALSE)
  iqt12_json(decision, file.path(run, "selection_review.json"))
  iqt12_hash(c(file.path(run, "selection_review.json"),
    list.files(file.path(run, "review"), full.names = TRUE)),
    file.path(run, "selection_review_hashes.csv"))
  invisible(decision)
}

idl12_selection_pdf <- function(run, plan, selected) {
  summaries <- list(); records <- list()
  plan <- plan[plan$arm %in% c("dqlm", "static", selected), ]
  for (i in seq_len(nrow(plan))) {
    cfg <- iqt12_read(plan$config_path[i]); source <- read.csv(cfg$source_path)
    fit <- as.matrix(read.csv(file.path(cfg$evidence, "fit_location_draws.csv.gz"))[, -1L])
    forecast <- as.matrix(read.csv(file.path(cfg$evidence, "forecast_location_draws.csv.gz"))[, -(1:3)])
    z <- ifd11_score_companions(fit, forecast, source, cfg$window, cfg$p)
    cell <- paste(cfg$replica, cfg$window$fold, sep = "_")
    summaries[[i]] <- cbind(replica = cell, arm = cfg$arm, z$summary)
    records[[paste(cell, cfg$arm, sep = "__")]] <- list(fit = fit, forecast = forecast,
      source = source, w = cfg$window, profile = z$profile)
  }
  idl12_pdf(run, "selection", records, do.call(rbind, summaries))
  invisible(TRUE)
}

idl12_advance <- function(run, stage) {
  stopifnot(stage %in% idl12_stages)
  p <- ifd11_plan_status(run, stage)
  stopifnot(!is.null(p), all(p$status == "SUCCESS"))
  idl12_verify(run)
  state <- iqt12_read(file.path(run, "campaign.json"))
  if (stage == "fresh_warm") state <- iqt12_read(file.path(run, "fresh_extension.json"))
  if (stage == "smoke") {
    configs <- unlist(lapply(c("F1", "F2"), function(replica)
      unlist(lapply(c("A", "B"), function(fold) lapply(c("dqlm", "static"),
        function(arm) idl12_config(state, arm, replica, fold, "selection_warm"))),
        recursive = FALSE)), recursive = FALSE)
    if (!file.exists(file.path(run, "plans/selection_warm.csv")))
      ifd11_plan(state, "selection_warm", configs)
  } else if (stage == "selection_warm") {
    configs <- unlist(lapply(c("F1", "F2"), function(replica)
      unlist(lapply(c("A", "B"), function(fold) lapply(idl12_arms,
        function(arm) idl12_config(state, arm, replica, fold, "selection"))),
        recursive = FALSE)), recursive = FALSE)
    if (!file.exists(file.path(run, "plans/selection.csv")))
      ifd11_plan(state, "selection", configs)
  } else if (stage == "selection") {
    if (!file.exists(file.path(run, "selection_review.json"))) idl12_selection(run)
  } else if (stage %in% c("confirmation_warm", "fresh_warm")) {
    selected <- iqt12_read(file.path(run, "selection_review.json"))$selected
    final <- if (stage == "confirmation_warm") "confirmation" else "fresh"
    replicas <- if (final == "confirmation") c("F1", "F2") else paste0("N", 1:4)
    fold <- if (final == "confirmation") "C" else "FINAL"
    configs <- unlist(lapply(replicas, function(replica)
      unlist(lapply(c("dqlm", "static", selected), function(arm) lapply(1:3,
        function(chain) idl12_config(state, arm, replica, fold, final, chain))),
        recursive = FALSE)), recursive = FALSE)
    if (!file.exists(file.path(run, "plans", paste0(final, ".csv"))))
      ifd11_plan(state, final, configs)
  } else {
    decision <- if (stage == "fresh") "closeout.json" else "confirmation_review.json"
    if (!file.exists(file.path(run, decision))) idl12_closeout_stage(run, stage)
  }
  invisible(TRUE)
}

idl12_continue <- function(run, stage) {
  stopifnot(stage %in% c("confirmation_warm", "fresh_warm"))
  idl12_verify(run)
  state <- iqt12_read(file.path(run, "campaign.json"))
  selection <- iqt12_read(file.path(run, "selection_review.json"))
  stopifnot(isTRUE(selection$strict_check_gain_over_static))
  if (stage == "fresh_warm" && !file.exists(file.path(run, "fresh_extension.json"))) {
    stopifnot(file.exists(file.path(run, "confirmation_review.json")))
    decision <- iqt12_read(file.path(run, "confirmation_review.json"))
    stopifnot(isTRUE(decision$strict_check_gain_over_static))
    helper <- ifd11_dgp_helper(state$repo)
    for (replica in paste0("N", 1:4)) {
      seed <- as.integer(state$fresh_seeds[[replica]])
      path <- file.path(run, "sources", paste0(replica, ".csv"))
      stopifnot(!file.exists(path))
      iqt12_csv(ifd11_dgp(helper, seed[1L], seed[2L])$source, path)
      state$sources[[replica]] <- list(path = path, sha256 = unname(tools::sha256sum(path)))
    }
    # The frozen campaign remains immutable; new-source authority is a hash-audited extension.
    iqt12_json(state, file.path(run, "fresh_extension.json"))
    iqt12_hash(c(file.path(run, "fresh_extension.json"),
      vapply(state$sources[paste0("N", 1:4)], `[[`, "", "path")),
      file.path(run, "fresh_extension_hashes.csv"))
  }
  if (stage == "fresh_warm" && file.exists(file.path(run, "fresh_extension.json")))
    state <- iqt12_read(file.path(run, "fresh_extension.json"))
  replicas <- if (stage == "confirmation_warm") c("F1", "F2") else paste0("N", 1:4)
  fold <- if (stage == "confirmation_warm") "C" else "FINAL"
  configs <- unlist(lapply(replicas, function(replica) lapply(c("dqlm", "static"),
    function(arm) idl12_config(state, arm, replica, fold, stage))), recursive = FALSE)
  ifd11_plan(state, stage, configs)
  invisible(TRUE)
}

idl12_closeout_stage <- function(run, stage) {
  stopifnot(stage %in% c("confirmation", "fresh"))
  state <- if (stage == "fresh") iqt12_read(file.path(run, "fresh_extension.json")) else
    iqt12_read(file.path(run, "campaign.json"))
  if (stage == "fresh") iqt12_verify(file.path(run, "fresh_extension_hashes.csv"))
  plan <- ifd11_plan_status(run, stage)
  records <- list(); summaries <- list(); attribution <- list(); chain_diagnostics <- list()
  for (replica in unique(plan$replica)) for (arm in unique(plan$arm)) {
    p <- plan[plan$replica == replica & plan$arm == arm, ]
    stopifnot(nrow(p) == 3L, all(p$status == "SUCCESS"))
    fits <- forecasts <- traces <- list()
    for (i in 1:3) {
      cfg <- iqt12_read(p$config_path[i]); source <- read.csv(cfg$source_path)
      fits[[i]] <- as.matrix(read.csv(file.path(cfg$evidence, "fit_location_draws.csv.gz"))[, -1L])
      forecasts[[i]] <- as.matrix(read.csv(file.path(cfg$evidence, "forecast_location_draws.csv.gz"))[, -(1:3)])
      traces[[i]] <- read.csv(file.path(cfg$evidence, "nuisance_trace.csv.gz"))
    }
    for (variable in intersect(c("sigma", "intercept", "offset_end", "tau", "slab"), names(traces[[1L]]))) {
      chains <- coda::mcmc.list(lapply(traces, function(trace) coda::mcmc(trace[[variable]])))
      rhat <- tryCatch(coda::gelman.diag(chains, autoburnin = FALSE)$psrf[1L, 1L],
        error = function(e) NA_real_)
      chain_diagnostics[[length(chain_diagnostics)+1L]] <- data.frame(replica = replica,
        arm = arm, variable = variable, Rhat = rhat,
        minimum_chain_ESS = min(vapply(traces, function(trace)
          unname(coda::effectiveSize(trace[[variable]])), 0)), exclusion_gate = FALSE)
    }
    fit <- do.call(cbind, fits); forecast <- do.call(cbind, forecasts)
    z <- ifd11_score_companions(fit, forecast, source, cfg$window, cfg$p)
    summaries[[length(summaries)+1L]] <- cbind(replica = replica, arm = arm, z$summary)
    attribution[[length(attribution)+1L]] <- cbind(replica = replica, arm = arm, z$attribution)
    records[[paste(replica, arm, sep = "__")]] <- list(fit = fit, forecast = forecast,
      source = source, w = cfg$window, profile = z$profile)
    iqt12_csv(z$profile, file.path(run, "review", paste0(stage, "__", replica, "__", arm, "__profile.csv.gz")))
  }
  summary <- do.call(rbind, summaries)
  iqt12_csv(summary, file.path(run, "review", paste0(stage, "_summary.csv")))
  iqt12_csv(do.call(rbind, attribution), file.path(run, "review", paste0(stage, "_covariance.csv")))
  iqt12_csv(do.call(rbind, chain_diagnostics), file.path(run, "review", paste0(stage, "_chain_diagnostics.csv")))
  selected <- iqt12_read(file.path(run, "selection_review.json"))$selected
  check <- summary[summary$metric == "forecast_check_loss", ]
  gain <- mean(check$mean[check$arm == selected]) < mean(check$mean[check$arm == "static"])
  decision <- list(status = "COMPLETE_REVIEW_REQUIRED", stage = stage,
    selected = selected, strict_check_gain_over_static = gain, diagnostics_exclusion = FALSE,
    article_changed = FALSE, pooling = "three_chains_within_replica_never_across_DGPs")
  path <- file.path(run, if (stage == "fresh") "closeout.json" else "confirmation_review.json")
  iqt12_json(decision, path)
  idl12_pdf(run, stage, records, summary)
  files <- c(path, list.files(file.path(run, "review"), full.names = TRUE))
  iqt12_hash(files, file.path(run, if (stage == "fresh") "closeout_manifest.csv" else
    "confirmation_review_hashes.csv"))
  invisible(decision)
}

idl12_pdf <- function(run, stage, records, summary) {
  arms <- unique(summary$arm)
  colors <- setNames(c("#245FA6", "#B94B45", "#247C59"), arms)
  pdf(file.path(run, "review", paste0(stage, "_dynamic_location_review.pdf")),
    width = 11.7, height = 8.3, useDingbats = FALSE)
  on.exit(dev.off())
  for (replica in unique(summary$replica)) {
    par(mfrow = c(1, 3), mar = c(4, 5, 3, 1), oma = c(0, 0, 3, 0))
    for (metric in c("fit_rmse", "forecast_mae", "forecast_check_loss")) {
      z <- summary[summary$replica == replica & summary$metric == metric, ]
      z <- z[match(arms, z$arm), ]
      plot(z$mean, 3:1, xlim = range(0, z$upper), ylim = c(.5, 3.5),
        type = "n", yaxt = "n", xlab = "Score", ylab = "", main = metric)
      axis(2, 3:1, arms, las = 1, cex.axis = .75)
      segments(z$lower, 3:1, z$upper, 3:1, col = colors, lwd = 3)
      points(z$mean, 3:1, pch = 4, col = colors, lwd = 2)
      points(z$mean_path_score, 3:1, pch = 1, col = colors)
    }
    mtext(paste(replica, "| x: mean draw score; o: mean-path score; native 95% intervals"),
      outer = TRUE, line = 1)
    for (region in c("fit", "forecast")) {
      par(mfrow = c(3, 1), mar = c(3, 4, 3, 1), oma = c(0, 0, 3, 0))
      bounds <- range(unlist(lapply(arms, function(arm) {
        z <- records[[paste(replica, arm, sep = "__")]]
        q <- z[[region]]
        c(apply(q, 1L, quantile, c(.025, .975), type = 8),
          z$source$q_target[if (region == "fit") z$w$train else iqt12_grid(z$w)$target])
      })))
      for (arm in arms) {
        z <- records[[paste(replica, arm, sep = "__")]]; q <- z[[region]]
        t <- if (region == "fit") z$w$train else iqt12_grid(z$w)$target
        ci <- t(apply(q, 1L, quantile, c(.025, .975), type = 8))
        plot(t, rowMeans(q), type = "n", ylim = bounds, xlab = "Source index",
          ylab = "Quantile location", main = arm)
        polygon(c(t, rev(t)), c(ci[, 1], rev(ci[, 2])), border = NA,
          col = adjustcolor(colors[arm], .18))
        lines(t, z$source$q_target[t], col = "black", lwd = 1.2)
        lines(t, rowMeans(q), col = colors[arm], lwd = 1.2)
      }
      mtext(paste(replica, region, "| same vertical scale; black: oracle"), outer = TRUE, line = 1)
    }
    par(mfrow = c(2, 2), mar = c(4, 4, 3, 1), oma = c(0, 0, 3, 0))
    for (by in c("origin", "lead")) for (metric in c("mae", "band_width")) {
      curves <- lapply(arms, function(arm) {
        z <- records[[paste(replica, arm, sep = "__")]]$profile
        aggregate(z[[metric]], list(position = z[[by]]), mean)
      })
      plot(range(curves[[1]]$position), range(0, unlist(lapply(curves, `[[`, "x"))),
        type = "n", xlab = by, ylab = metric)
      for (i in seq_along(arms)) lines(curves[[i]]$position, curves[[i]]$x,
        col = colors[i], lwd = 2)
      legend("topleft", arms, col = colors, lty = 1, bty = "n", cex = .7)
    }
    mtext(paste(replica, "origin/lead diagnostic profiles"), outer = TRUE, line = 1)
    par(mfrow = c(2, 3), mar = c(4, 4, 3, 1))
    for (metric in c("mae", "band_width")) {
      maximum <- max(vapply(arms, function(arm)
        max(records[[paste(replica, arm, sep = "__")]]$profile[[metric]]), 0))
      for (arm in arms) {
        z <- records[[paste(replica, arm, sep = "__")]]$profile
        origins <- sort(unique(z$origin)); surface <- matrix(NA_real_, length(origins), 30)
        surface[cbind(match(z$origin, origins), z$lead)] <- z[[metric]]
        image(origins, 1:30, surface, zlim = c(0, maximum),
          col = hcl.colors(60, "YlGnBu", rev = TRUE), xlab = "Origin", ylab = "Lead",
          main = paste(arm, metric))
        mtext(sprintf("common scale 0--%.2f", maximum), side = 3, line = .2, cex = .7)
      }
    }
  }
  invisible(TRUE)
}

idl12_replay <- function(path, inner, output) {
  cfg <- iqt12_read(path)
  stopifnot(cfg$model == "qdesn", cfg$omega_scaled > 0,
    cfg$engine == "mcmc", !dir.exists(output), inner >= 2L, inner %% 2L == 0L)
  idl12_verify(cfg$run)
  status <- iqt12_read(cfg$status_path); stopifnot(status$status == "SUCCESS")
  iqt12_verify(status$manifest)
  pars <- read.csv(file.path(cfg$evidence, "selected_parameters.csv.gz"))
  offset <- read.csv(file.path(cfg$evidence, "offset_draws.csv.gz"))
  source <- read.csv(cfg$source_path)
  e <- ifd11_runtime(cfg$repo, cfg$library)
  cx <- ilr10_design_hook(e, cfg, source, cfg$window$end)
  fit <- list(beta = as.matrix(pars[, -(1:4)]), sigma = pars$sigma,
    gamma = pars$gamma, offset = as.matrix(offset[, -1L])/cx$scale)
  cfg$inner <- as.integer(inner)
  fc <- idl12_forecast(e, cx, cfg, fit)
  fd <- (cx$object$X %*% t(fit$beta) + fit$offset)*cx$scale
  dir.create(output, recursive = TRUE)
  iqt12_csv(cbind(iqt12_grid(cfg$window), fc$primary), file.path(output, "forecast_location_draws.csv.gz"))
  iqt12_csv(ifd11_score_companions(fd, fc$primary, source, cfg$window, cfg$p)$summary,
    file.path(output, "summary.csv"))
  iqt12_json(list(input_config = path, input_sha256 = unname(tools::sha256sum(path)),
    inner = inner, fit_calls = 0L, contract = "forecast_only_replay_same_retained_outer_draws"),
    file.path(output, "replay.json"))
  iqt12_hash(list.files(output, full.names = TRUE), file.path(output, "manifest.csv"))
  invisible(TRUE)
}

idl12_import_success <- function(run, previous) {
  idl12_verify(run)
  state <- iqt12_read(file.path(run, "campaign.json"))
  old <- iqt12_read(file.path(previous, "campaign.json"))
  stopifnot(old$schema == state$schema, !any(idl12_health(run)$running > 0),
    !file.exists(file.path(run, "recovery_imports.json")))
  archive <- file.path(previous, "control/frozen_source_f94dfe13.tar")
  stopifnot(file.exists(archive), old$head == "f94dfe13bf09751aaa1f98e9ca9ae945fbb4b5ec")
  extracted <- tempfile("idl12_source_archive_"); dir.create(extracted)
  utils::untar(archive, exdir = extracted)
  sources <- read.csv(file.path(previous, "source_hashes.csv"))
  stopifnot(all(startsWith(sources$path, paste0(old$repo, "/"))))
  archived <- file.path(extracted, substring(sources$path, nchar(old$repo)+2L))
  stopifnot(identical(unname(tools::sha256sum(archived)), sources$sha256))
  for (name in c("package", "input", "frozen", "compiled_helper"))
    iqt12_verify(file.path(previous, paste0(name, "_hashes.csv")))
  old_env <- new.env(parent = .GlobalEnv)
  sys.source(file.path(extracted, "validation/fitforecast_v2/R/independent_qdesn_dynamic_location_v12.R"),
    envir = old_env)
  functions <- c("idl12_fit", "idl12_filter", "idl12_al_moments", "idl12_particle",
    "idl12_forecast", "idl12_config", "idl12_window")
  stopifnot(all(vapply(functions, function(name) identical(body(old_env[[name]]),
    body(get(name, .GlobalEnv))), TRUE)))
  imports <- list()
  for (stage in c("smoke", "selection_warm")) {
    p <- ifd11_plan_status(previous, stage)
    iqt12_verify(file.path(previous, "plans", paste0(stage, "_hashes.csv")))
    p <- p[p$status == "SUCCESS", ]
    configs <- lapply(p$config_path, function(path) {
      cfg <- iqt12_read(path)
      idl12_config(state, cfg$arm, cfg$replica, cfg$window$fold, cfg$stage, cfg$chain)
    })
    if (!file.exists(file.path(run, "plans", paste0(stage, ".csv")))) {
      if (stage == "selection_warm") idl12_advance(run, "smoke")
    }
    for (i in seq_len(nrow(p))) {
      original <- iqt12_read(p$config_path[i]); cfg <- configs[[i]]
      status <- iqt12_read(original$status_path); iqt12_verify(status$manifest)
      original_manifest <- status$manifest
      fresh_cfg <- iqt12_read(cfg$path)
      fields <- c("schema", "model", "engine", "arm", "replica", "chain", "window", "seed",
        "outer", "inner", "burn", "retained", "vb_iter", "normal_iter", "readout_conditioning",
        "candidate", "baseline", "layer1_scale", "layer2_scale", "layer3_scale", "omega_scaled")
      stopifnot(identical(original[fields], fresh_cfg[fields]), !file.exists(cfg$status_path))
      dir.create(cfg$evidence, recursive = TRUE)
      mf <- read.csv(status$manifest)
      stopifnot(all(dirname(mf$path) == original$evidence))
      destinations <- file.path(cfg$evidence, basename(mf$path))
      stopifnot(all(file.copy(mf$path, destinations)),
        identical(unname(tools::sha256sum(destinations)), mf$sha256))
      status$imported_from <- original$status_path
      status$import_source_head <- old$head
      status$manifest <- iqt12_hash(destinations, file.path(cfg$evidence, "manifest.csv"))
      iqt12_json(status, cfg$status_path)
      imports[[length(imports)+1L]] <- list(id = cfg$id, original_config = original$path,
        original_status = original$status_path, original_manifest = original_manifest,
        no_refit = TRUE, archived_source_verified = TRUE, kernels_identical = functions)
    }
  }
  iqt12_json(list(status = "LOADER_RACE_ROOT_FIX_SUCCESSFUL_EVIDENCE_REUSED",
    previous = previous, old_head = old$head, new_head = state$head,
    source_archive_sha256 = unname(tools::sha256sum(archive)), imports = imports,
    previous_startup_failures = sum(idl12_health(previous)$failed),
    discarded_results = 0L, refitted_successful_models = 0L), file.path(run, "recovery_imports.json"))
  old_paths <- unlist(lapply(imports, function(z) c(z$original_config, z$original_status,
    z$original_manifest)), use.names = FALSE)
  iqt12_hash(c(archive, old_paths, file.path(run, "recovery_imports.json")),
    file.path(run, "recovery_imports_hashes.csv"))
  invisible(idl12_health(run))
}

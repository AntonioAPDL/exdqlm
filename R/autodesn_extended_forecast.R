# Shared causal reservoir engine, frozen feature geometry, joint posterior draws.
.ext_origin_features <- function(bank, m, h) {
  res <- bank$templates[[m]]$reservoir
  D <- length(h)
  k <- .normal_desn_get_act(res$act_k)
  lower <- if (D > 1L) do.call(c, lapply(seq_len(D - 1L), function(j) {
    z <- if (isTRUE(res$Q_is_identity[j])) h[[j]] else res$Q[[j]] %*% h[[j]]
    as.numeric(k(z))
  }

  )) else numeric(0)
  as.numeric(c(h[[D]], lower))
}

.ext_new_row <- function(bank, m, p, t, raw_reservoir, history_scaled) {
  e <- bank$extension
  L <- if (length(e$readout$lags)) matrix(history_scaled[t - e$readout$lags], 1) else matrix(numeric(0), 1, 0)
  S <- if (is.na(e$periods[p])) matrix(numeric(0), 1, 0) else .ext_fourier(t, e$periods[p], e$seasonal$harmonics)
  c(1, as.vector(.ext_apply(e$lag, L)), as.vector(.autodesn_feature_apply(bank$models[[m]], matrix(raw_reservoir, 1))), as.vector(.ext_apply(e$calendar[[p]], S)))
}

#' Update observed reservoir states without refitting AutoDESN
#' @param object An augmented AutoDESN fit.
#' @param y Observed values to append, in temporal order.
#' @return Updated fit with unchanged posterior draws/weights and frozen transforms.
#' @export
autodesn_update_history <- function(object, y) {
  if (!inherits(object, "autodesn_extended_fit")) stop("This updater requires an augmented fit.", call. = FALSE)
  y <- .normal_desn_assert_response(y)
  b <- object$bank
  e <- b$extension
  if (is.null(b$templates)) stop("Observed state updates require reservoir templates.", call. = FALSE)
  old <- length(b$history)
  newz <- (y - b$preprocessing$center) / b$preprocessing$scale
  z <- c(b$history_scaled, newz)
  times <- old + seq_along(y)
  hstates <- if (is.null(e$current_states)) e$initial_states else e$current_states
  features <- vector("list", length(b$models))
  for (m in seq_along(b$models)) {
    engine <- .normal_desn_transition_engine(b$templates[[m]], "serial")
    h <- hstates[[m]]
    R <- matrix(0, length(times), b$models[[m]]$raw_d)
    for (j in seq_along(times)) {
      t <- times[j]
      step <- engine$step(h, engine$input(z[seq_len(t - 1L)]))
      h <- lapply(step$h, as.numeric)
      R[j, ] <- step$x[ - 1L]
    }

    features[[m]] <- R
    hstates[[m]] <- h
  }

  b$history <- c(b$history, y)
  b$history_scaled <- z
  e$current_states <- hstates
  e$current_origin <- length(z)
  e$last_observation_features <- features
  e$last_observation_times <- times
  b$extension <- e
  object$bank <- b
  object
}

.ext_filter_step <- function(particles, logw, residual, s2, phi, omega, offset, initial = FALSE) {
  N <- length(particles)
  u <- if (initial) stats::rnorm(N) else phi * particles + sqrt(1 - phi ^ 2) * stats::rnorm(N)
  lv <- log(s2) + offset + omega * u
  lw <- logw - .5 * (log(2 * pi) + lv + residual ^ 2 * exp( - lv))
  top <- max(lw)
  if (!is.finite(top)) stop("Volatility filter lost all finite weights.", call. = FALSE)
  normalizer <- top + log(sum(exp(lw - top)))
  w <- exp(lw - normalizer)
  ess <- 1 / sum(w ^ 2)
  if (ess < N / 2) {
    ix <- sample.int(N, N, replace = TRUE, prob = w)
    u <- u[ix]
    w[] <- 1 / N
  }

  list(particles = u, logw = log(w), ess = ess, log_increment = normalizer)
}

.ext_draw_identity <- function(fit, ids) digest::digest(list(fit$controls$target_id, fit$draws[ids, , drop = FALSE], fit$beta[ids], lapply(fit$volatility[ids], `[[`, "gamma")), algo = "sha256")

#' Conditional volatility filtering with frozen parameter weights
#' @param object Augmented SV fit, possibly updated with new observations.
#' @param draw_index Posterior static-draw indices to filter.
#' @param particles Number of state particles per static draw.
#' @param previous Previous filter, immediately preceding the last observed update.
#' @param seed Reproducible local RNG seed.
#' @return Conditional state filters; their normalization never reweights static draws.
#' @export
autodesn_filter <- function(object, draw_index, particles = 1024L, previous = NULL, seed = NULL) {
  if (!inherits(object, "autodesn_extended_fit") || object$controls$variance_control$type != "sv") stop("Supply an augmented SV fit.", call. = FALSE)
  .autodesn_integer(particles, "particles", 2L)
  ids <- unique(as.integer(draw_index))
  if (!length(ids) || anyNA(ids) || any(ids < 1 | ids > nrow(object$draws)) || any(draw_index != as.integer(draw_index))) stop("Invalid posterior draw indices.", call. = FALSE)
  b <- object$bank
  e <- b$extension
  identity <- .ext_draw_identity(object, ids)
  if (!is.null(previous)) {
    if (!identical(previous$draw_identity, identity) || !identical(previous$ids, ids) || previous$particles != particles ||
    !identical(previous$history, b$history[seq_along(previous$history)])) stop("Filter state/parameter/history mismatch.", call. = FALSE)
    times <- e$last_observation_times
    if (is.null(times) || previous$origin != min(times) - 1L) stop("Filter must immediately precede the most recent history update.", call. = FALSE)
  } else {
    if (length(b$history) != e$fit_origin) stop("Initialize the conditional filter at the fitted origin before appending observations.", call. = FALSE)
    times <- e$times
  }

  .autodesn_seed(seed, function() {
    out <- vector("list", length(ids))
    for (j in seq_along(ids)) {
      k <- ids[j]
      d <- object$draws[k, ]
      m <- d$model
      p <- d$period_index
      B <- object$beta[[k]]
      gamma <- object$volatility[[k]]$gamma
      if (is.null(previous)) {
        mu <- as.vector(.ext_design(b, m, p)$X %*% B)
        state <- list(particles = numeric(particles), logw = rep( - log(particles), particles), min_ess = particles, log_likelihood = 0)
      } else {
        state <- previous$states[[j]]
        mu <- vapply(seq_along(times), function(i) sum(.ext_new_row(b, m, p, times[i], e$last_observation_features[[m]][i, ], b$history_scaled) * B), 0)
      }

      W <- if (length(gamma)) {
        w <- .ext_fourier(times, e$periods[p], 4L)
        center <- colMeans(.ext_fourier(e$times, e$periods[p], 4L))
        as.vector(sweep(w, 2, center, "-") %*% gamma)
      } else rep(0, length(times))
      for (i in seq_along(times)) {
        next_state <- .ext_filter_step(state$particles, state$logw, b$history_scaled[times[i]] - mu[i], d$variance, d$phi, d$omega, W[i], is.null(previous) && i == 1L)
        state$particles <- next_state$particles
        state$logw <- next_state$logw
        state$min_ess <- min(state$min_ess, next_state$ess)
        state$log_likelihood <- state$log_likelihood + next_state$log_increment
      }

      out[[j]] <- state
    }

    list(states = out, ids = ids, particles = particles, draw_identity = identity, origin = length(b$history), history = b$history,
    conditioning_policy = "conditional_state_filter_frozen_static_weights", static_weights_updated = FALSE)
  }

  )
}

#' Recursive forecasts from an augmented AutoDESN posterior
#' @param object Augmented fit at its observed origin.
#' @param H Forecast horizon.
#' @param nd Number of outer parameter draws if draw_index is NULL.
#' @param seed Local RNG seed.
#' @param draw_index Explicit joint posterior draw indices.
#' @param inner_paths Innovation paths per outer draw.
#' @param innovations,volatility_innovations Optional H by total-path standard normals.
#' @param state_filter Conditional state filter for the selected static draws.
#' @param filter_particles Filter particles per static draw if initialization is needed.
#' @param ... Unknown controls are rejected.
#' @return Joint predictive paths, matching conditional means/SDs, model and period indices.
#' @export
forecast_paths.autodesn_extended_fit <- function(object, H, nd = 192L, seed = NULL, draw_index = NULL, inner_paths = 8L, innovations = NULL, volatility_innovations = NULL, state_filter = NULL, filter_particles = 1024L, ...) {
  if (length(list(...))) stop("Unknown augmented forecasting controls.", call. = FALSE)
  .autodesn_integer(H, "H")
  .autodesn_integer(nd, "nd")
  .autodesn_integer(inner_paths, "inner_paths")
  b <- object$bank
  e <- b$extension
  if (is.null(b$templates)) stop("Recursive forecasts require reservoir templates.", call. = FALSE)
  .autodesn_seed(seed, function() {
    ids <- if (is.null(draw_index)) sample.int(nrow(object$draws), nd, replace = TRUE) else draw_index
    if (!is.numeric(ids) || !length(ids) || any(!is.finite(ids) | ids != floor(ids) | ids < 1 | ids > nrow(object$draws))) stop("Invalid posterior draw indices.", call. = FALSE)
    ids <- as.integer(ids)
    N <- length(ids) * inner_paths
    which_draw <- rep(ids, each = inner_paths)
    check_noise <- function(z) {
      if (!is.matrix(z) || !identical(dim(z), c(as.integer(H), as.integer(N))) || any(!is.finite(z))) stop("Innovations must have H by total-path dimensions.", call. = FALSE)
      z
    }

    Z <- if (is.null(innovations)) matrix(stats::rnorm(H * N), H, N) else check_noise(innovations)
    sv <- object$controls$variance_control$type == "sv"
    if (sv) {
      if (is.null(state_filter)) state_filter <- autodesn_filter(object, ids, filter_particles)
      if (state_filter$origin != length(b$history) || !identical(state_filter$history, b$history) || !identical(state_filter$draw_identity, .ext_draw_identity(object, state_filter$ids)) || !all(ids %in% state_filter$ids)) stop("Forecast filter has stale states or parameters.", call. = FALSE)
      VZ <- if (is.null(volatility_innovations)) matrix(stats::rnorm(H * N), H, N) else check_noise(volatility_innovations)
    }

    Y <- MU <- SD <- matrix(NA_real_, H, N)
    model <- object$draws$model[which_draw]
    period <- object$draws$period_index[which_draw]
    # Draw terminal states in outer-draw order before grouping deterministic work.
    # This preserves RNG order and each path's joint static/state assignment.
    terminal <- numeric(N)
    if (sv) for (j in seq_along(ids)) {
      cols <- (j - 1L) * inner_paths + seq_len(inner_paths)
      f <- state_filter$states[[match(ids[j], state_filter$ids)]]
      terminal[cols] <- f$particles[sample.int(length(f$particles), inner_paths, TRUE, prob = exp(f$logw))]
    }
    groups <- split(seq_len(N), paste(model, period, sep = ":"))
    for (cols in groups) {
      selected <- which_draw[cols]
      d <- object$draws[selected, , drop = FALSE]
      m <- model[cols[1L]]
      p <- period[cols[1L]]
      B <- do.call(rbind, object$beta[selected])
      count <- length(cols)
      engine <- .normal_desn_transition_engine(b$templates[[m]], "batched")
      h0 <- if (is.null(e$current_states)) e$initial_states[[m]] else e$current_states[[m]]
      h <- lapply(h0, function(x) matrix(x, length(x), count))
      lag_count <- max(c(engine$m, e$readout$lags, 0L))
      lag <- if (lag_count) matrix(rev(tail(b$history_scaled, lag_count)), lag_count, count) else matrix(numeric(0), 0, count)
      if (sv) {
        vol <- terminal[cols]
        gamma <- do.call(rbind, lapply(object$volatility[selected], `[[`, "gamma"))
        center <- if (ncol(gamma)) colMeans(.ext_fourier(e$times, e$periods[p], 4L)) else numeric(0)
      }
      for (lead in seq_len(H)) {
        t <- length(b$history) + lead
        inp <- rbind(rep(b$templates[[m]]$meta$win_scale_bias %||% 1, count), engine$process_lags(lag[seq_len(engine$m), , drop = FALSE]) * (b$templates[[m]]$meta$win_scale_global %||% 1))
        step <- engine$step(h, inp)
        F <- .autodesn_feature_apply(b$models[[m]], t(step$x[ - 1L, , drop = FALSE]))
        L <- if (length(e$readout$lags)) t(lag[e$readout$lags, , drop = FALSE]) else matrix(numeric(0), count, 0)
        S <- if (is.na(e$periods[p])) matrix(numeric(0), 1, 0) else .ext_fourier(t, e$periods[p], e$seasonal$harmonics)
        cal <- .ext_apply(e$calendar[[p]], S)
        X <- cbind(1, .ext_apply(e$lag, L), F, matrix(rep(as.numeric(cal), each = count), count, ncol(cal)))
        mu <- rowSums(X * B)
        lv <- log(d$variance)
        if (sv) {
          vol <- d$phi * vol + sqrt(1 - d$phi ^ 2) * VZ[lead, cols]
          off <- if (ncol(gamma)) as.vector(gamma %*% as.numeric(.ext_fourier(t, e$periods[p], 4L) - center)) else 0
          lv <- lv + off + d$omega * vol
        }
        sd <- exp(lv / 2)
        y <- mu + sd * Z[lead, cols]
        if (any(!is.finite(c(mu, sd, y)))) stop("Nonfinite recursive forecast; inspect posterior/state draw.", call. = FALSE)
        Y[lead, cols] <- y
        MU[lead, cols] <- mu
        SD[lead, cols] <- sd
        if (lag_count) lag <- rbind(y, lag[seq_len(lag_count - 1L), , drop = FALSE])
        h <- step$h
      }
    }

    list(yrep = .autodesn_unscale(b, Y), mu_draws = .autodesn_unscale(b, MU), sd_draws = SD * b$preprocessing$scale,
    model = model, period_index = period, draw_index = which_draw, H = H, nd = N, n_outer = length(ids), inner_paths = inner_paths,
    outer_draw_index = rep(seq_along(ids), each = inner_paths), origin = length(b$history), recursion_mode = "posterior_predictive",
    forecast_family = "normal_recursive_augmented_autodesn", state_filter = state_filter, static_weights_updated = FALSE)
  }

  )
}

#' Fitted means for an augmented AutoDESN
#' @param object Augmented fit.
#' @param ... Reserved.
#' @return Posterior mean function on training rows.
#' @export
predict_mu.autodesn_extended_fit <- function(object, ...) {
  mu <- numeric(object$bank$n)
  N <- nrow(object$draws)
  groups <- split(seq_len(N), paste(object$draws$model, object$draws$period_index, sep = ":"))
  for (ids in groups) {
    k <- ids[1L]
    B <- colMeans(do.call(rbind, object$beta[ids]))
    mu <- mu + as.vector(.ext_design(object$bank, object$draws$model[k], object$draws$period_index[k])$X %*% B) * length(ids) / N
  }

  .autodesn_unscale(object$bank, mu)
}

#' Conditional fixed-design replication for augmented AutoDESN
#' @param object Augmented fit.
#' @param nd Number of posterior draws.
#' @param seed Local RNG seed.
#' @param ... Reserved.
#' @return Conditional means and predictive samples.
#' @export
posterior_predict.autodesn_extended_fit <- function(object, nd = 1000L, seed = NULL, ...) {
  if (length(list(...))) stop("Use forecast_paths for future augmented designs.", call. = FALSE)
  sv <- object$controls$variance_control$type == "sv"
  if (sv && !isTRUE(object$controls$variance_control$save_state_paths)) stop("SV fitted prediction requires save_state_paths=TRUE; use causal forecast_paths for forecasts.", call. = FALSE)
  .autodesn_integer(nd, "nd")
  .autodesn_seed(seed, function() {
    ids <- sample.int(nrow(object$draws), nd, TRUE)
    n <- object$bank$n
    mu <- vapply(ids, function(k) as.vector(.ext_design(object$bank, object$draws$model[k], object$draws$period_index[k])$X %*% object$beta[[k]]), numeric(n))
    sd <- matrix(rep(sqrt(object$draws$variance[ids]), each = n), n, nd)
    if (sv) for (j in seq_along(ids)) {
      k <- ids[j]
      v <- object$volatility[[k]]
      if (length(v$path) != n) stop("Missing or invalid smoothing path.", call. = FALSE)
      off <- if (length(v$gamma)) as.vector(.ext_sv_w(object$bank, object$draws$period_index[k]) %*% v$gamma) else 0
      sd[, j] <- sd[, j] * exp((off + object$draws$omega[k] * v$path) / 2)
    }

    y <- mu + matrix(stats::rnorm(length(mu)), nrow(mu)) * sd
    list(mu_draws = .autodesn_unscale(object$bank, mu), yrep = .autodesn_unscale(object$bank, y), sd_draws = sd * object$bank$preprocessing$scale, draw_index = ids, replication = "conditional_fixed_training_design", recursive_replication = FALSE)
  }

  )
}

.ext_diagnostics <- function(fits) {
  if (!all(vapply(fits, inherits, TRUE, "autodesn_extended_fit")) || length(unique(vapply(fits, function(f) f$controls$target_id, ""))) != 1L) stop("Diagnostic fits must have the same augmented target.", call. = FALSE)
  fits <- lapply(fits, function(f) {
    if (!is.null(f$trace)) f$draws <- f$trace
    f
  }

  )
  fields <- setdiff(names(fits[[1]]$draws), c("iteration", "model", "period_index"))
  fields <- fields[vapply(fields, function(nm) any(vapply(fits, function(f) stats::var(f$draws[[nm]]) > 0, TRUE)), TRUE)]
  chains <- list()
  for (nm in fields) chains[[nm]] <- lapply(fits, function(f) f$draws[[nm]])
  for (i in seq_len(ncol(fits[[1]]$probes))) chains[[paste0("fitted_probe_", i)]] <- lapply(fits, function(f) f$probes[, i])
  for (j in unique(unlist(lapply(fits, function(f) f$draws$model)))) chains[[paste0("model_", j)]] <- lapply(fits, function(f) as.numeric(f$draws$model == j))
  for (j in unique(unlist(lapply(fits, function(f) f$draws$period_index)))) chains[[paste0("period_", j)]] <- lapply(fits, function(f) as.numeric(f$draws$period_index == j))
  table <- do.call(rbind, lapply(names(chains), function(nm) {
    z <- chains[[nm]]
    data.frame(parameter = nm, rhat = .autodesn_split_rhat(z), ess_spectral = sum(.autodesn_ess(z)), mcse_batch = .autodesn_batch_mcse(z), constant = all(vapply(z, function(x) stats::var(x) == 0, TRUE)))
  }

  ))
  list(parameters = table, chains = length(fits), qualified = FALSE, qualification = "Diagnostic table only. Rank bulk/tail ESS and cross-budget/mode checks must be completed before scientific qualification.", target_id = fits[[1]]$controls$target_id)
}

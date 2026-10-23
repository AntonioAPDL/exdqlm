# Custom stress tests, not reproductions of named published benchmark datasets.
hh_kinds <- c("smooth_scale", "threshold_gjr", "switching_seasonal")
hh_transition <- matrix(c(.98, .02, .05, .95), 2L, byrow = TRUE)

# All arguments can be vectors (one per Monte Carlo trajectory).
hh_location <- function(kind, t, lag, state = 1L) {
  a <- lag[1L, ]; b <- lag[2L, ]; c <- lag[3L, ]
  switch(kind,
    smooth_scale = .35 * a + .45 * sin(1.5 * b) + .20 * c / (1 + c^2),
    threshold_gjr = ifelse(a < 0, -.20 + .45 * a + .25 * tanh(b),
                          .15 + .25 * a - .35 * tanh(b)) + .10 * sin(c),
    switching_seasonal = .35 * a + .30 * tanh(lag[12L, ]) + .55 * sin(2*pi*t/48) +
      ifelse(state == 1L, .20 * sin(b), -.20 * tanh(a*b) + .30 * cos(2*pi*t/24)),
    stop("Unknown DGP"))
}
hh_scale <- function(kind, t, lag, state = 1L, variance = 1) {
  a <- lag[1L, ]
  switch(kind,
    smooth_scale = .16 + .75 * plogis(3 * (abs(a) - .55)) + .18 * (.5 + .5*sin(2*pi*t/36)),
    threshold_gjr = sqrt(variance),
    switching_seasonal = ifelse(state == 1L, .22 + .08*abs(tanh(a)),
                                .85 + .30*abs(tanh(a/2))),
    stop("Unknown DGP"))
}
hh_gjr_step <- function(error, variance) .03 + .06*error^2 + .12*error^2*(error < 0) + .85*variance
hh_lags <- function(history, N = 1L) {
  x <- rev(tail(c(rep(0, 12L), history), 12L))
  matrix(x, 12L, N)
}
hh_shift <- function(lag, y) rbind(y, lag[1:11, , drop = FALSE])

hh_simulate <- function(kind, n, seed) {
  stopifnot(kind %in% hh_kinds, n > 0)
  # Independent streams keep every observed prefix invariant to requested length.
  z <- .autodesn_seed(seed + 1L, function() rnorm(n))
  u <- .autodesn_seed(seed + 2L, function() runif(n))
  state <- .autodesn_seed(seed + 3L, function() ifelse(runif(1) < 5/7, 1L, 2L))
  y <- mu <- sd <- numeric(n); regimes <- integer(n)
  lag <- hh_lags(numeric()); variance <- 1; error <- 0
  for (t in seq_len(n)) {
    if (kind == "threshold_gjr") variance <- hh_gjr_step(error, variance)
    if (kind == "switching_seasonal") state <- ifelse(u[t] < hh_transition[state, 1L], 1L, 2L)
    mu[t] <- hh_location(kind, t, lag, state)
    sd[t] <- hh_scale(kind, t, lag, state, variance)
    error <- sd[t] * z[t]; y[t] <- mu[t] + error
    regimes[t] <- if (kind == "switching_seasonal") state else NA_integer_
    lag <- hh_shift(lag, y[t])
  }
  list(kind = kind, y = y, mu = mu, sd = sd, state = regimes, seed = seed)
}

hh_logmean <- function(x) { m <- max(x); m + log(mean(exp(x - m))) }
hh_components <- function(kind, t, lag, variance, probability) {
  if (kind == "switching_seasonal") {
    pr <- as.numeric(probability %*% hh_transition)
    mu <- vapply(1:2, function(s) hh_location(kind, t, lag, s), numeric(1))
    sd <- vapply(1:2, function(s) hh_scale(kind, t, lag, s), numeric(1))
  } else {
    pr <- 1; mu <- hh_location(kind, t, lag); sd <- hh_scale(kind, t, lag, variance = variance)
  }
  mean <- sum(pr*mu)
  list(probability = pr, mu = mu, sd = sd, mean = mean,
       predictive_sd = sqrt(sum(pr*(sd^2 + mu^2)) - mean^2))
}
# Known-parameter observation filter. No latent-state argument exists.
hh_filter <- function(kind, history) {
  lag <- hh_lags(numeric()); variance <- 1; error <- 0; probability <- c(5/7, 2/7)
  means <- scales <- numeric(length(history)); weights <- matrix(NA_real_, length(history), 2L)
  for (t in seq_along(history)) {
    if (kind == "threshold_gjr") variance <- hh_gjr_step(error, variance)
    component <- hh_components(kind, t, lag, variance, probability)
    means[t] <- component$mean; scales[t] <- component$predictive_sd
    if (kind == "switching_seasonal") {
      logw <- log(component$probability) + dnorm(history[t], component$mu, component$sd, log = TRUE)
      probability <- .autodesn_softmax(logw); weights[t, ] <- probability
    }
    error <- history[t] - component$mean
    lag <- hh_shift(lag, history[t])
  }
  list(lag = lag, variance = variance, error = error, probability = probability,
       mean = means, predictive_sd = scales, filtered_weights = weights)
}

hh_oracle <- function(kind, history, H, N, seed, observed = NULL) {
  filtered <- hh_filter(kind, history)
  .autodesn_seed(seed, function() {
    z <- matrix(rnorm(H*N), H, N); u <- matrix(runif(H*N), H, N)
    state <- ifelse(runif(N) < filtered$probability[1L], 1L, 2L)
    lag <- hh_lags(history, N); variance <- rep(filtered$variance, N); error <- rep(filtered$error, N)
    probability <- filtered$probability
    mu <- sd <- y <- matrix(NA_real_, H, N)
    exact_mean <- exact_sd <- rep(NA_real_, H)
    for (h in seq_len(H)) {
      t <- length(history) + h
      if (kind == "threshold_gjr") variance <- hh_gjr_step(error, variance)
      if (kind == "switching_seasonal") {
        if (is.null(observed)) {
          state <- ifelse(u[h, ] < hh_transition[state, 1L], 1L, 2L)
        } else {
          component <- hh_components(kind, t, lag[, 1L, drop = FALSE], variance[1L], probability)
          state <- ifelse(u[h, ] < component$probability[1L], 1L, 2L)
        }
      }
      mu[h, ] <- hh_location(kind, t, lag, state)
      sd[h, ] <- hh_scale(kind, t, lag, state, variance)
      y[h, ] <- mu[h, ] + sd[h, ] * z[h, ]
      if (!is.null(observed)) {
        component <- hh_components(kind, t, lag[, 1L, drop = FALSE], variance[1L], probability)
        exact_mean[h] <- component$mean; exact_sd[h] <- component$predictive_sd
        if (kind == "switching_seasonal") probability <- .autodesn_softmax(
          log(component$probability) + dnorm(observed[h], component$mu, component$sd, log = TRUE))
        next_y <- rep(observed[h], N)
        # For GJR there is a single mean conditional on observed history.
        error <- next_y - component$mean
      } else { next_y <- y[h, ]; error <- next_y - mu[h, ] }
      lag <- hh_shift(lag, next_y)
    }
    list(yrep = y, mu_draws = mu, sd_draws = sd, exact_mean = exact_mean, exact_sd = exact_sd)
  })
}

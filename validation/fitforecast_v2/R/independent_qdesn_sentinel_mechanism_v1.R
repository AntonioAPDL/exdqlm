ism1_schema <- "independent_qdesn_sentinel_mechanism_v1"
ism1_stages <- c("smoke", "normal_screen", "quantile_screen", "online_pilot",
  "short_mcmc", "full_mcmc", "controls_vb", "controls_mcmc")
ism1_sentinel <- "normal__exal__p005"
ism1_controls <- c("normal__al__p005", "laplace__exal__p005")
ism1_folds <- c("S1", "S2", "S3", "S4")

ism1_base_runtime <- iqt12_runtime
ism1_base_design <- iqt12_design
ism1_base_prior <- iqt12_prior

ism1_runtime <- function(repo, library) {
  e <- ism1_base_runtime(repo, library)
  sys.source(file.path(repo, "R/exal_online_vbld.R"), e)
  e
}
iqt12_runtime_hook <- ism1_runtime

ism1_widths <- function(total, D, pattern) {
  D <- as.integer(D); total <- max(as.integer(total), 20L * D)
  w <- switch(pattern,
    equal = rep(1, D),
    tapered = rev(seq_len(D)),
    expanding = seq_len(D),
    bottleneck = if (D == 1L) 1 else c(2, rep(.5, max(0, D - 2L)), 2),
    rep(1, D))
  n <- pmax(20L, as.integer(round(total * w / sum(w))))
  n[which.max(n)] <- n[which.max(n)] + total - sum(n)
  while (any(n < 20L)) {
    j <- which.min(n); k <- which.max(n)
    take <- min(20L - n[j], n[k] - 20L)
    n[j] <- n[j] + take; n[k] <- n[k] - take
  }
  n
}

ism1_signature <- function(c) {
  fields <- c("n", "m", "alpha", "rho", "center_scale", "input_bound",
    "input_gain", "recurrent_indegree", "input_fanin", "interlayer_fanin",
    "matrix_seed", "readout_mode", "effective_p0", "lag_precision_multiplier")
  digest::digest(jsonlite::toJSON(c[fields], auto_unbox = TRUE, digits = NA),
    serialize = FALSE, algo = "sha256")
}

ism1_candidate <- function(c, reference, readout_mode = "reservoir_only",
                           effective_p0 = 15, lag_precision_multiplier = 1,
                           role = "space_filling") {
  n <- iqt12_unpack(c$n); D <- length(n); m <- as.integer(c$m)
  stopifnot(D >= 1L, D <= 6L, all(n >= 20L), sum(n) <= 1500L,
    m >= 1L, m <= 500L, c$alpha > 0, c$alpha < 1,
    c$rho > 0, c$rho < 1, readout_mode %in%
      c("reservoir_only", "lag_only", "hybrid_direct_lags"))
  c$input_fanin <- min(as.integer(c$input_fanin), m + 1L)
  c$recurrent_indegree <- min(as.integer(c$recurrent_indegree), min(n))
  c$interlayer_fanin <- if (D == 1L) 1L else
    min(as.integer(c$interlayer_fanin), min(n))
  c$n_tilde <- paste(head(n, -1L), collapse = ";")
  c$D <- D; c$total_states <- sum(n); c$m <- m
  c$matrix_seed <- 920001L
  c$readout_mode <- readout_mode
  c$effective_p0 <- as.numeric(effective_p0)
  c$lag_precision_multiplier <- as.numeric(lag_precision_multiplier)
  c$readout_dimension <- switch(readout_mode,
    reservoir_only = 1L + sum(n), lag_only = 1L + m,
    hybrid_direct_lags = 1L + sum(n) + m)
  p_active <- c$readout_dimension - 1L
  p0 <- min(max(1, c$effective_p0), max(1, p_active - 1))
  tau_unit <- p0 / max(1, p_active - p0) / sqrt(1000)
  response_scale <- reference$sigma_b_source %||%
    reference$response_scale %||% 1
  c$tau_source <- response_scale * tau_unit
  c$slab_source <- reference$slab_source
  c$sigma_b_source <- reference$sigma_b_source
  c$omega_b_source <- reference$omega_b_source
  c$role <- role
  c$structure_id <- substr(ism1_signature(c), 1L, 16L)
  c$id <- substr(digest::digest(list(schema = ism1_schema,
    signature = ism1_signature(c), tau_source = c$tau_source),
    algo = "sha256"), 1L, 20L)
  c
}

ism1_maximin <- function(features, count) {
  stopifnot(is.matrix(features), count >= 1L, count <= nrow(features))
  features <- scale(features)
  selected <- which.min(rowSums(features^2))
  distance <- rep(Inf, nrow(features))
  while (length(selected) < count) {
    last <- features[selected[length(selected)], ]
    distance <- pmin(distance, rowSums((features - rep(last,
      each = nrow(features)))^2))
    distance[selected] <- -Inf
    selected <- c(selected, which.max(distance))
  }
  selected
}

ism1_generate_bank <- function(reference, counts = c(reservoir_only = 96L,
    hybrid_direct_lags = 96L, lag_only = 48L)) {
  stopifnot(identical(sort(names(counts)),
      sort(c("reservoir_only", "hybrid_direct_lags", "lag_only"))),
    all(counts >= 8L), counts[["reservoir_only"]] == counts[["hybrid_direct_lags"]])
  set.seed(102071L)
  pool <- vector("list", 1200L)
  patterns <- c("equal", "tapered", "expanding", "bottleneck")
  m_grid <- c(1L, 5L, 10L, 15L, 30L, 60L, 90L, 120L, 180L,
    240L, 300L, 390L, 450L, 500L)
  p0_grid <- c(3, 8, 15, 30, 60, 120)
  for (i in seq_along(pool)) {
    D <- sample(1:6, 1L)
    total <- as.integer(round(exp(runif(1L, log(max(40, 20 * D)), log(1500)))))
    n <- ism1_widths(total, D, sample(patterns, 1L))
    c <- reference
    c$n <- paste(n, collapse = ";"); c$m <- sample(m_grid, 1L)
    c$alpha <- plogis(runif(1L, qlogis(.01), qlogis(.995)))
    c$rho <- plogis(runif(1L, qlogis(.40), qlogis(.999)))
    c$input_gain <- exp(runif(1L, log(.02), log(3)))
    c$input_fanin <- max(1L, ceiling((c$m + 1L) * sample(c(.02, .05, .1, .25, .5, 1), 1L)))
    c$recurrent_indegree <- min(sample(c(5L, 10L, 20L, 40L, 80L), 1L), min(n))
    c$interlayer_fanin <- min(sample(c(5L, 10L, 20L, 40L, 80L), 1L), min(n))
    c$center_scale <- sample(c("mean_sd", "median_mad"), 1L)
    c$input_bound <- sample(c("none", "tanh_z_over_3"), 1L)
    c$effective_p0 <- sample(p0_grid, 1L)
    c$lag_precision_multiplier <- sample(c(.25, 1, 4), 1L)
    pool[[i]] <- c
  }
  features <- do.call(rbind, lapply(pool, function(c) {
    n <- iqt12_unpack(c$n)
    c(log(sum(n)), length(n), log(c$m + 1), qlogis(c$alpha),
      qlogis(c$rho), log(c$input_gain), c$input_fanin / (c$m + 1L),
      log(c$effective_p0))
  }))
  selected <- ism1_maximin(features, counts[["reservoir_only"]] - 1L)
  bases <- c(list(reference), pool[selected])
  out <- list()
  for (i in seq_along(bases)) for (mode in c("reservoir_only", "hybrid_direct_lags")) {
    candidate <- bases[[i]]
    out[[length(out) + 1L]] <- ism1_candidate(candidate, reference, mode,
      candidate$effective_p0 %||% 15,
      if (mode == "reservoir_only") 1 else candidate$lag_precision_multiplier %||% 1,
      if (i == 1L) "exact_anchor_readout_ablation" else "maximin_space_filling")
  }

  lag_grid <- expand.grid(m = m_grid, effective_p0 = p0_grid,
    lag_precision_multiplier = c(.25, 1, 4),
    center_scale = c("mean_sd", "median_mad"),
    input_bound = c("none", "tanh_z_over_3"),
    stringsAsFactors = FALSE)
  lag_features <- cbind(log(lag_grid$m + 1), log(lag_grid$effective_p0),
    log(lag_grid$lag_precision_multiplier),
    as.integer(lag_grid$center_scale == "median_mad"),
    as.integer(lag_grid$input_bound == "tanh_z_over_3"))
  lag_anchor <- reference
  lag_anchor$n <- "20"; lag_anchor$alpha <- .5; lag_anchor$rho <- .5
  lag_anchor$input_gain <- 1; lag_anchor$input_fanin <- 1L
  lag_anchor$recurrent_indegree <- 5L; lag_anchor$interlayer_fanin <- 1L
  lag_anchor$effective_p0 <- 15; lag_anchor$lag_precision_multiplier <- 1
  lag_candidates <- list(ism1_candidate(lag_anchor, reference, "lag_only", 15, 1,
    "exact_anchor_readout_ablation"))
  lag_order <- ism1_maximin(lag_features, nrow(lag_features))
  for (i in lag_order) {
    candidate <- lag_anchor
    candidate$m <- lag_grid$m[i]
    candidate$effective_p0 <- lag_grid$effective_p0[i]
    candidate$lag_precision_multiplier <- lag_grid$lag_precision_multiplier[i]
    candidate$center_scale <- lag_grid$center_scale[i]
    candidate$input_bound <- lag_grid$input_bound[i]
    candidate$input_fanin <- min(candidate$m + 1L, 1L)
    candidate <- ism1_candidate(candidate, reference, "lag_only",
      candidate$effective_p0, candidate$lag_precision_multiplier,
      "lag_active_parameter_maximin")
    if (!candidate$id %in% vapply(lag_candidates, `[[`, "", "id"))
      lag_candidates[[length(lag_candidates) + 1L]] <- candidate
    if (length(lag_candidates) == counts[["lag_only"]]) break
  }
  stopifnot(length(lag_candidates) == counts[["lag_only"]])
  out <- c(out, lag_candidates)
  ids <- vapply(out, `[[`, "", "id")
  observed <- table(factor(vapply(out, `[[`, "", "readout_mode"),
    levels = names(counts)))
  stopifnot(length(out) == sum(counts), all(observed == counts), !anyDuplicated(ids))
  out
}

ism1_window <- function(fold, candidate, stage) {
  ends <- c(S1 = 8000L, S2 = 8250L, S3 = 8500L, S4 = 8750L)
  stopifnot(fold %in% names(ends))
  end <- unname(ends[fold]); N <- 1000L
  stride <- if (stage %in% c("full_mcmc", "controls_mcmc")) 5L else 10L
  train <- seq.int(end - N + 1L, end)
  wash <- seq.int(min(train) - 500L, min(train) - 1L)
  list(fold = fold, N = N, train = train, washout = wash,
    buffer = seq.int(min(wash) - candidate$m, min(wash) - 1L),
    origins = seq.int(end, end + 220L, stride), end = end + 250L,
    horizon = 30L, origin_stride = stride)
}

ism1_seed <- function(...) {
  key <- digest::digest(paste(..., collapse = "|"), algo = "sha256")
  71000000L + strtoi(substr(key, 1L, 7L), base = 16L) %% 10000000L
}

ism1_config <- function(state, cell, candidate, stage, engine = "vb",
                        fold = "S1", model = "qdesn", chain = 1L,
                        online_update = FALSE) {
  ref <- state$references[[cell]]
  budget <- switch(stage,
    smoke = list(outer = 12L, inner = 8L, vb = 60L, normal = 50L, burn = 50L, retained = 80L),
    normal_screen = list(outer = 48L, inner = 24L, vb = 200L, normal = 300L),
    quantile_screen = list(outer = 64L, inner = 48L, vb = 600L, normal = 300L),
    online_pilot = list(outer = 64L, inner = 48L, vb = 600L, normal = 300L),
    short_mcmc = list(outer = 80L, inner = 64L, vb = 600L, normal = 300L,
      burn = 1000L, retained = 3000L),
    full_mcmc = list(outer = 200L, inner = 128L, vb = 800L, normal = 300L,
      burn = 5000L, retained = 20000L),
    controls_vb = list(outer = 80L, inner = 64L, vb = 700L, normal = 300L),
    controls_mcmc = list(outer = 160L, inner = 96L, vb = 700L, normal = 300L,
      burn = 3000L, retained = 10000L),
    stop("Unknown sentinel stage"))
  w <- ism1_window(fold, candidate, stage)
  id <- paste(stage, cell, model, engine, fold, candidate$id,
    if (online_update) "online" else "static", chain, sep = "__")
  list(schema = ism1_schema, run = state$run, repo = state$repo,
    library = state$library, id = id, cell = cell, family = ref$family,
    p = ref$p, likelihood = ref$likelihood, candidate = candidate,
    stage = stage, engine = engine, model = model, chain = chain,
    online_update = online_update, source_path = ref$source_path,
    source_sha = ref$source_sha, baseline = ref$baseline, window = w,
    outer = budget$outer, inner = budget$inner, vb_iter = budget$vb,
    normal_iter = budget$normal, burn = budget$burn %||% 0L,
    retained = budget$retained %||% 0L, seed = ism1_seed(id),
    path = file.path(state$run, "configs", paste0(id, ".json")),
    status_path = file.path(state$run, "status", paste0(id, ".json")),
    evidence = file.path(state$run, "evidence", id),
    timeout = if (stage %in% c("full_mcmc", "controls_mcmc")) 172800L else 43200L)
}

ism1_plan <- function(state, configs, stage) {
  stopifnot(length(configs) > 0L)
  iqt12_plan(state, configs, stage)
}

ism1_direct_lags <- function(cx) {
  m <- cx$object$reservoir$m
  L <- matrix(NA_real_, length(cx$y), m)
  for (t in seq.int(m + 1L, length(cx$y)))
    L[t, ] <- cx$y[t - seq_len(m)]
  L <- (L - cx$object$meta$lag_center) / cx$object$meta$lag_scale
  if (cx$object$meta$input_bound == "tanh")
    L <- tanh(L / cx$object$meta$input_bound_divisor)
  L
}

ism1_design <- function(e, cfg, source, last = max(cfg$window$train)) {
  cx <- ism1_base_design(e, cfg, source, last)
  mode <- cfg$candidate$readout_mode %||% "reservoir_only"
  cx$state_all_X <- cx$all_X; cx$state_fit_X <- cx$object$X
  L <- ism1_direct_lags(cx); cx$direct_lag_X <- L
  cx$all_X <- switch(mode,
    reservoir_only = cx$state_all_X,
    lag_only = cbind(1, L),
    hybrid_direct_lags = cbind(cx$state_all_X, L))
  cx$object$X <- cx$all_X[cx$train, , drop = FALSE]
  cx$object$meta$sentinel_readout_mode <- mode
  cx$object$meta$sentinel_state_columns <- ncol(cx$state_all_X)
  cx$object$meta$sentinel_lag_columns <- ncol(L)
  stopifnot(ncol(cx$object$X) == cfg$candidate$readout_dimension,
    all(is.finite(cx$object$X)))
  cx$design_hash <- digest::digest(cx$object$X, algo = "sha256")
  cx
}
iqt12_design_hook <- ism1_design

ism1_prior <- function(e, cfg, scale) {
  prior <- ism1_base_prior(e, cfg, scale)
  mode <- cfg$candidate$readout_mode %||% "reservoir_only"
  if (mode == "reservoir_only") return(prior)
  nstate <- sum(iqt12_unpack(cfg$candidate$n)); m <- cfg$candidate$m
  lag_idx <- if (mode == "lag_only") seq.int(2L, 1L + m) else
    seq.int(2L + nstate, 1L + nstate + m)
  factor <- cfg$candidate$lag_precision_multiplier %||% 1
  old <- prior$beta$expected_prec
  prior$beta$expected_prec <- function(state, p) {
    z <- old(state, p); z[lag_idx] <- z[lag_idx] * factor; z
  }
  prior$rhs$lag_precision_multiplier <- factor
  prior
}
iqt12_prior <- ism1_prior

ism1_readout_row <- function(object, h, z) {
  mode <- object$meta$sentinel_readout_mode %||% "reservoir_only"
  switch(mode,
    reservoir_only = {
      states <- rbind(h[[object$reservoir$D]], do.call(rbind, head(h, -1L)))
      rbind(1, states)
    },
    lag_only = rbind(1, z),
    hybrid_direct_lags = {
      states <- rbind(h[[object$reservoir$D]], do.call(rbind, head(h, -1L)))
      rbind(1, states, z)
    })
}

ism1_particle_paths <- function(e, object, y, local, H, draws, noise,
                                capture_first_step = FALSE) {
  r <- object$reservoir; meta <- object$meta; count <- nrow(draws$beta)
  use_states <- (meta$sentinel_readout_mode %||% "reservoir_only") != "lag_only"
  h <- if (use_states) lapply(object$states$H_all, function(z)
    matrix(z[local, ], nrow = ncol(z), ncol = count)) else NULL
  lags <- matrix(y[local - seq_len(r$m) + 1L], nrow = r$m, ncol = count)
  abc <- lapply(draws$gamma, function(g) e$exal_get_ABC(meta$p0 %||% object$fit$misc$p0, g))
  A <- vapply(abc, `[[`, 0, "A"); B <- vapply(abc, `[[`, 0, "B")
  lambda <- vapply(abc, `[[`, 0, "C") * abs(draws$gamma)
  beta <- t(draws$beta); mu <- yrep <- matrix(0, H, count)
  first_step_x <- NULL
  for (lead in seq_len(H)) {
    z <- (lags - meta$lag_center) / meta$lag_scale
    if (meta$input_bound == "tanh") z <- tanh(z / meta$input_bound_divisor)
    if (use_states) {
      u <- rbind(rep(meta$win_scale_bias, count), z * meta$win_scale_global)
      for (d in seq_len(r$D)) {
        input <- if (d == 1L) u else h[[d - 1L]]
        h[[d]] <- as.matrix((1 - r$alpha[d]) * h[[d]] + r$alpha[d] *
          tanh(r$W[[d]] %*% h[[d]] + r$Win[[d]] %*% input))
      }
    }
    x <- ism1_readout_row(object, h, z)
    if (lead == 1L && capture_first_step) first_step_x <- x
    stopifnot(nrow(x) == nrow(beta))
    mu[lead, ] <- colSums(x * beta)
    yrep[lead, ] <- mu[lead, ] + lambda * draws$sigma * noise$s[lead, ] +
      A * noise$v[lead, ] + sqrt(B * draws$sigma * noise$v[lead, ]) * noise$z[lead, ]
    lags <- rbind(yrep[lead, ], head(lags, -1L))
  }
  stopifnot(all(is.finite(mu)), all(is.finite(yrep)))
  list(mu_draws = mu, yrep = yrep, first_step_x = first_step_x)
}

ism1_numeric_identity <- function(expected, observed, absolute_tolerance = 1e-10,
                                  relative_tolerance = 1e-10) {
  expected <- as.numeric(expected); observed <- as.numeric(observed)
  finite <- length(expected) == length(observed) &&
    all(is.finite(expected)) && all(is.finite(observed))
  if (!finite) return(list(pass = FALSE, max_absolute_error = Inf,
    max_relative_error = Inf, comparison_scale = Inf))
  delta <- abs(expected - observed)
  scale <- pmax(1, abs(expected), abs(observed))
  allowed <- absolute_tolerance + relative_tolerance * scale
  list(pass = all(delta <= allowed), max_absolute_error = max(delta),
    max_relative_error = max(delta / scale), comparison_scale = max(scale))
}

ism1_assert_first_step <- function(expected_x, observed_x, expected_prediction,
                                   observed_prediction) {
  feature <- ism1_numeric_identity(expected_x, observed_x,
    absolute_tolerance = 1e-10, relative_tolerance = 1e-10)
  prediction <- ism1_numeric_identity(expected_prediction, observed_prediction,
    absolute_tolerance = 1e-8, relative_tolerance = 1e-10)
  if (!feature$pass) stop(sprintf(
    "First-step teacher-forcing feature identity failed: abs=%g rel=%g scale=%g",
    feature$max_absolute_error, feature$max_relative_error,
    feature$comparison_scale), call. = FALSE)
  if (!prediction$pass) stop(sprintf(
    "First-step prediction identity failed: abs=%g rel=%g scale=%g",
    prediction$max_absolute_error, prediction$max_relative_error,
    prediction$comparison_scale), call. = FALSE)
  list(feature = feature, prediction = prediction)
}

ism1_mvn <- function(mean, V, n, seed) {
  set.seed(seed); V <- (V + t(V)) / 2
  R <- tryCatch(chol(V), error = function(e) chol(V + diag(1e-10, nrow(V))))
  sweep(matrix(rnorm(n * length(mean)), n, length(mean)) %*% R,
    2L, mean, "+")
}

ism1_qforecast_static <- function(e, cx, cfg, fit, draws, progress = NULL) {
  object <- cx$object; object$fit <- fit; w <- cfg$window
  out <- plugin <- vector("list", length(w$origins))
  guards <- vector("list", length(w$origins))
  for (i in seq_along(w$origins)) {
    o <- w$origins[i]; local <- o - cx$first + 1L
    H <- min(w$horizon, w$end - o)
    bank <- e$iqcf_v3_make_noise_bank(draws, H, 1L,
      if (cfg$inner >= 128L) 256L else cfg$inner, cfg$seed + o)
    noise <- e$iqcf_v3_subset_noise_bank(bank, cfg$inner)[[1]]
    outer <- nrow(draws$beta); means <- plug <- matrix(0, H, outer)
    batches <- split(seq_len(outer), ceiling(seq_len(outer) / max(1L, 256L %/% cfg$inner)))
    feature_guard <- NULL
    for (ids in batches) {
      subset <- e$iqcf_v3_subset_draws(draws, ids)
      repeated <- e$iqcf_v3_repeat_draws(subset, cfg$inner)
      columns <- unlist(lapply(ids, function(j) (j - 1L) * cfg$inner + seq_len(cfg$inner)))
      path <- ism1_particle_paths(e, object, cx$y, local, H, repeated,
        lapply(noise, function(z) z[, columns, drop = FALSE]),
        capture_first_step = TRUE)
      expected_x <- matrix(cx$all_X[local + 1L, ], nrow = nrow(path$first_step_x),
        ncol = ncol(path$first_step_x))
      one <- ism1_numeric_identity(expected_x, path$first_step_x,
        absolute_tolerance = 1e-10, relative_tolerance = 1e-10)
      if (!one$pass) stop(sprintf(
        "First-step teacher-forcing feature identity failed: abs=%g rel=%g scale=%g",
        one$max_absolute_error, one$max_relative_error, one$comparison_scale),
        call. = FALSE)
      if (is.null(feature_guard) ||
          one$max_relative_error > feature_guard$max_relative_error) feature_guard <- one
      means[, ids] <- e$iqcf_v3_matrix_by_outer_draw(path$mu_draws, length(ids), cfg$inner, "mean")
      zeros <- matrix(0, H, length(ids))
      plug[, ids] <- ism1_particle_paths(e, object, cx$y, local, H, subset,
        list(s = zeros, v = zeros, z = zeros))$mu_draws
    }
    out[[i]] <- means * cx$scale; plugin[[i]] <- plug * cx$scale
    expected <- cx$all_X[local + 1L, , drop = FALSE] %*% t(draws$beta) * cx$scale
    checked <- ism1_assert_first_step(cx$all_X[local + 1L, ],
      path$first_step_x[, 1L], expected, out[[i]][1L, , drop = FALSE])
    guards[[i]] <- data.frame(origin = o,
      feature_max_absolute_error = feature_guard$max_absolute_error,
      feature_max_relative_error = feature_guard$max_relative_error,
      prediction_max_absolute_error = checked$prediction$max_absolute_error,
      prediction_max_relative_error = checked$prediction$max_relative_error,
      prediction_comparison_scale = checked$prediction$comparison_scale,
      pass = TRUE)
    if (!is.null(progress)) progress(i, length(w$origins))
  }
  list(primary = do.call(rbind, out), plugin = do.call(rbind, plugin),
    first_step_guard = do.call(rbind, guards))
}

ism1_qforecast_online <- function(e, cx, cfg, fit, draws, progress = NULL) {
  stopifnot(inherits(fit, "exal_vb"), cfg$likelihood == "exal")
  prior <- iqt12_prior(e, cfg, cx$scale)
  state <- e$exal_online_init(cx$object$y_fit, cx$object$X, cfg$p,
    c(e$L.fn(cfg$p), e$U.fn(cfg$p)),
    control = list(M = 5L, K = 20L, W = 250L, L_loc = 2L,
      window_passes = 1L), batch_fit = fit,
    prior_gamma = list(mu0 = 0, s20 = 10), prior_sigma = prior$sigma,
    beta_prior_obj = prior$beta)
  object <- cx$object; object$fit <- fit; previous <- max(cfg$window$train)
  out <- plugin <- vector("list", length(cfg$window$origins))
  guards <- vector("list", length(cfg$window$origins))
  for (i in seq_along(cfg$window$origins)) {
    o <- cfg$window$origins[i]
    if (o > previous) {
      idx <- seq.int(previous + 1L, o); local_idx <- idx - cx$first + 1L
      state <- e$exal_online_run(state, cx$y[local_idx],
        cx$all_X[local_idx, , drop = FALSE], update_rhs = TRUE,
        update_sigmagam = TRUE, keep_trace = FALSE)
    }
    previous <- o; local <- o - cx$first + 1L
    H <- min(cfg$window$horizon, cfg$window$end - o)
    online_draws <- list(beta = ism1_mvn(state$qbeta$m, state$qbeta$V,
      cfg$outer, cfg$seed + o), sigma = rep(state$qsiggam$sigma_mean, cfg$outer),
      gamma = rep(state$qsiggam$gamma_mean, cfg$outer))
    bank <- e$iqcf_v3_make_noise_bank(online_draws, H, 1L, cfg$inner, cfg$seed + o)
    noise <- e$iqcf_v3_subset_noise_bank(bank, cfg$inner)[[1]]
    repeated <- e$iqcf_v3_repeat_draws(online_draws, cfg$inner)
    path <- ism1_particle_paths(e, object, cx$y, local, H, repeated, noise,
      capture_first_step = TRUE)
    out[[i]] <- e$iqcf_v3_matrix_by_outer_draw(path$mu_draws, cfg$outer, cfg$inner, "mean") * cx$scale
    zeros <- matrix(0, H, cfg$outer)
    plugin[[i]] <- ism1_particle_paths(e, object, cx$y, local, H,
      online_draws, list(s = zeros, v = zeros, z = zeros))$mu_draws * cx$scale
    expected_x <- matrix(cx$all_X[local + 1L, ], nrow = nrow(path$first_step_x),
      ncol = ncol(path$first_step_x))
    expected_prediction <- cx$all_X[local + 1L, , drop = FALSE] %*%
      t(online_draws$beta) * cx$scale
    checked <- ism1_assert_first_step(expected_x, path$first_step_x,
      expected_prediction, out[[i]][1L, , drop = FALSE])
    guards[[i]] <- data.frame(origin = o,
      feature_max_absolute_error = checked$feature$max_absolute_error,
      feature_max_relative_error = checked$feature$max_relative_error,
      prediction_max_absolute_error = checked$prediction$max_absolute_error,
      prediction_max_relative_error = checked$prediction$max_relative_error,
      prediction_comparison_scale = checked$prediction$comparison_scale,
      pass = TRUE)
    if (!is.null(progress)) progress(i, length(cfg$window$origins))
  }
  list(primary = do.call(rbind, out), plugin = do.call(rbind, plugin),
    first_step_guard = do.call(rbind, guards))
}

ism1_qforecast <- function(e, cx, cfg, fit, draws, progress = NULL) {
  if (isTRUE(cfg$online_update)) ism1_qforecast_online(e, cx, cfg, fit, draws, progress)
  else ism1_qforecast_static(e, cx, cfg, fit, draws, progress)
}
iqt12_qforecast_hook <- ism1_qforecast

ism1_normal_forecast <- function(e, cx, cfg, object, draws) {
  w <- cfg$window; out <- vector("list", length(w$origins))
  use_states <- (object$meta$sentinel_readout_mode %||% "reservoir_only") != "lag_only"
  for (i in seq_along(w$origins)) {
    o <- w$origins[i]; local <- o - cx$first + 1L
    H <- min(w$horizon, w$end - o)
    index <- rep(seq_len(nrow(draws$beta)), each = cfg$inner)
    beta <- draws$beta[index, , drop = FALSE]; count <- length(index)
    h <- if (use_states) lapply(object$states$H_all, function(z)
      matrix(z[local, ], ncol = count, nrow = ncol(z))) else NULL
    lags <- matrix(cx$y[local - seq_len(object$reservoir$m) + 1L],
      ncol = count, nrow = object$reservoir$m)
    values <- matrix(0, H, count)
    set.seed(cfg$seed + o)
    noise <- sweep(matrix(rnorm(H * count), H, count), 2,
      sqrt(draws$omega2[index]), "*")
    for (lead in seq_len(H)) {
      z <- (lags - object$meta$lag_center) / object$meta$lag_scale
      if (object$meta$input_bound == "tanh") z <- tanh(z / object$meta$input_bound_divisor)
      if (use_states) {
        u <- rbind(rep(object$meta$win_scale_bias, count), z * object$meta$win_scale_global)
        for (d in seq_len(object$reservoir$D)) {
          input <- if (d == 1L) u else h[[d - 1L]]
          h[[d]] <- as.matrix((1 - object$reservoir$alpha[d]) * h[[d]] +
            object$reservoir$alpha[d] * tanh(object$reservoir$W[[d]] %*% h[[d]] +
              object$reservoir$Win[[d]] %*% input))
        }
      }
      xx <- ism1_readout_row(object, h, z)
      mu <- colSums(xx * t(beta)); values[lead, ] <- mu
      lags <- rbind(mu + noise[lead, ], head(lags, -1L))
    }
    out[[i]] <- e$iqcf_v3_matrix_by_outer_draw(values,
      nrow(draws$beta), cfg$inner, "mean") * cx$scale
  }
  do.call(rbind, out)
}
iqt12_normal_forecast_hook <- ism1_normal_forecast

ism1_bank_frame <- function(bank) do.call(rbind, lapply(bank, function(c)
  data.frame(id = c$id, structure_id = c$structure_id, role = c$role,
    readout_mode = c$readout_mode, n = c$n, D = c$D,
    total_states = c$total_states, m = c$m, alpha = c$alpha, rho = c$rho,
    input_gain = c$input_gain, input_fanin = c$input_fanin,
    recurrent_indegree = c$recurrent_indegree,
    interlayer_fanin = c$interlayer_fanin, center_scale = c$center_scale,
    input_bound = c$input_bound, effective_p0 = c$effective_p0,
    lag_precision_multiplier = c$lag_precision_multiplier,
    readout_dimension = c$readout_dimension, tau_source = c$tau_source)))

ism1_materialize <- function(repo, run, parent, library) {
  stopifnot(!dir.exists(run), dir.exists(parent), dir.exists(library))
  for (name in c("source_hashes.csv", "input_hashes.csv", "package_hashes.csv", "frozen_hashes.csv"))
    iqt12_verify(file.path(parent, name))
  parent_state <- iqt12_read(file.path(parent, "campaign.json"))
  state <- list(schema = ism1_schema, repo = repo, run = run,
    library = library, head = system2("git", c("-C", repo, "rev-parse", "HEAD"), stdout = TRUE),
    parent = parent, max_workers = 15L, maximum_campaign_cpu_hours = 900,
    maximum_worker_wall_seconds = 172800L, article_changed = FALSE,
    selection_block = "internal_training_only_S1_to_S4",
    sentinel = ism1_sentinel, controls = ism1_controls, references = list())
  for (cell in c(ism1_sentinel, ism1_controls)) {
    ref <- parent_state$references[[cell]]; stopifnot(!is.null(ref))
    original <- ref$original_source %||% ref$source_path
    stopifnot(file.exists(original))
    x <- read.csv(original); stopifnot(nrow(x) >= 9000L)
    source <- file.path(run, "sources", paste0(cell, ".csv"))
    iqt12_csv(x[x$t >= 6001L & x$t <= 9000L, ], source)
    ref$source_path <- source; ref$source_sha <- unname(tools::sha256sum(source))
    state$references[[cell]] <- ref
  }
  state$bank <- ism1_generate_bank(state$references[[ism1_sentinel]]$candidate)
  dir.create(run, recursive = TRUE, showWarnings = FALSE)
  dir.create(file.path(run, "control"), recursive = TRUE, showWarnings = FALSE)
  iqt12_csv(ism1_bank_frame(state$bank), file.path(run, "candidate_bank.csv"))
  env <- list(exdqlm_version = as.character(utils::packageVersion("exdqlm", lib.loc = library)),
    package_path = find.package("exdqlm", lib.loc = library),
    session = capture.output(sessionInfo()), threads = list(OMP_NUM_THREADS = 1,
      OPENBLAS_NUM_THREADS = 1, MKL_NUM_THREADS = 1),
    source_head = state$head)
  iqt12_json(env, file.path(run, "environment.json"))
  iqt12_json(state, file.path(run, "campaign.json"))
  code <- c(file.path(repo, "validation/fitforecast_v2/R", c(
    "independent_qdesn_training1000_runtime_v1.R",
    "independent_qdesn_training1000_campaign_v1.R",
    "independent_qdesn_sentinel_mechanism_v1.R")),
    file.path(repo, "validation/fitforecast_v2/scripts", c(
      "independent_qdesn_sentinel_mechanism_v1.R",
      "run_independent_qdesn_sentinel_mechanism_v1.sh")),
    file.path(repo, "validation/fitforecast_v2/docs/INDEPENDENT_QDESN_SENTINEL_MECHANISM_V1_20261007.md"))
  iqt12_hash(code, file.path(run, "source_hashes.csv"))
  iqt12_hash(c(file.path(run, c("campaign.json", "environment.json", "candidate_bank.csv")),
    vapply(state$references, `[[`, "", "source_path")), file.path(run, "input_hashes.csv"))
  iqt12_hash(list.files(file.path(library, "exdqlm"), recursive = TRUE,
    full.names = TRUE), file.path(run, "package_hashes.csv"))
  configs <- list()
  anchors <- state$bank[vapply(state$bank, function(c)
    c$role == "exact_anchor_readout_ablation", TRUE)]
  for (c in anchors) {
    configs[[length(configs) + 1L]] <- ism1_config(state, ism1_sentinel,
      c, "smoke", "normal", "S1")
    configs[[length(configs) + 1L]] <- ism1_config(state, ism1_sentinel,
      c, "smoke", "vb", "S1")
  }
  ism1_plan(state, configs, "smoke")
  iqt12_hash(c(file.path(run, c("campaign.json", "environment.json",
    "candidate_bank.csv", "source_hashes.csv", "input_hashes.csv", "package_hashes.csv")),
    vapply(state$references, `[[`, "", "source_path")), file.path(run, "frozen_hashes.csv"))
  invisible(state)
}

ism1_results <- function(run, stages) iqt12_results(run, stages)

ism1_aggregate <- function(run, stage, normal = FALSE, model = "qdesn",
                           online = NULL) {
  z <- ism1_results(run, stage); z <- z[z$model == model, ]
  if (!is.null(online)) {
    flags <- vapply(z$config_path, function(p) isTRUE(iqt12_read(p)$online_update), TRUE)
    z <- z[flags == online, ]
  }
  ids <- unique(z$candidate_id); out <- list()
  for (id in ids) {
    q <- z[z$candidate_id == id, ]
    cfg <- iqt12_read(q$config_path[1L])
    if (normal) {
      values <- unique(q[c("fold", "normal_observed_mae")])$normal_observed_mae
      out[[length(out) + 1L]] <- data.frame(candidate_id = id,
        median_forecast_mae = median(values), max_forecast_mae = max(values),
        median_check_loss = NA_real_, max_check_loss = NA_real_,
        folds = length(values), config_path = q$config_path[1L],
        readout_mode = cfg$candidate$readout_mode,
        readout_dimension = cfg$candidate$readout_dimension,
        total_states = cfg$candidate$total_states)
    } else {
      get <- function(metric, fun) fun(q$mean[q$metric == metric])
      out[[length(out) + 1L]] <- data.frame(candidate_id = id,
        median_forecast_mae = get("forecast_mae", median),
        max_forecast_mae = get("forecast_mae", max),
        median_check_loss = get("forecast_check_loss", median),
        max_check_loss = get("forecast_check_loss", max),
        folds = length(unique(q$fold)), config_path = q$config_path[1L],
        readout_mode = cfg$candidate$readout_mode,
        readout_dimension = cfg$candidate$readout_dimension,
        total_states = cfg$candidate$total_states)
    }
  }
  out <- do.call(rbind, out)
  out[order(out$median_forecast_mae, out$median_check_loss,
    out$max_forecast_mae, out$readout_dimension, out$candidate_id), ]
}

ism1_diverse_select <- function(rank, n = 50L) {
  top <- head(seq_len(nrow(rank)), min(30L, nrow(rank)))
  bins <- cut(rank$total_states, breaks = c(-Inf, 100, 300, 700, Inf), labels = FALSE)
  strata <- paste(rank$readout_mode, bins)
  diverse <- unlist(lapply(split(seq_len(nrow(rank)), strata), head, 2L))
  edge <- unique(c(which.max(rank$readout_dimension), which.min(rank$readout_dimension),
    tail(seq_len(nrow(rank)), min(10L, nrow(rank)))))
  idx <- unique(c(top, diverse, edge, seq_len(nrow(rank))))
  head(idx, min(n, nrow(rank)))
}

ism1_warm <- function(run, stage, candidate_id, fold) {
  z <- ism1_results(run, stage)
  row <- z[z$candidate_id == candidate_id & z$fold == fold & z$model == "qdesn", ][1L, ]
  stopifnot(nrow(row) == 1L)
  cfg <- iqt12_read(row$config_path)
  path <- file.path(cfg$evidence, "mcmc_initializer.json")
  stopifnot(file.exists(path)); list(path = path, sha = unname(tools::sha256sum(path)))
}

ism1_control_candidate <- function(selected, reference, mode = selected$readout_mode) {
  selected$slab_source <- reference$slab_source
  selected$sigma_b_source <- reference$sigma_b_source
  selected$omega_b_source <- reference$omega_b_source
  ism1_candidate(selected, reference, mode, selected$effective_p0,
    selected$lag_precision_multiplier, "sentinel_mechanism_transfer")
}

ism1_advance <- function(run, finished) {
  state <- iqt12_read(file.path(run, "campaign.json"))
  stopifnot(finished %in% ism1_stages)
  result <- ism1_results(run, finished)
  iqt12_csv(result, file.path(run, "summaries", paste0(finished, ".csv")))
  configs <- list(); add <- function(x) configs[[length(configs) + 1L]] <<- x
  next_stage <- ism1_stages[match(finished, ism1_stages) + 1L]
  if (finished == "smoke") {
    for (c in state$bank) for (fold in c("S1", "S3"))
      add(ism1_config(state, ism1_sentinel, c, next_stage, "normal", fold))
  } else if (finished == "normal_screen") {
    rank <- ism1_aggregate(run, finished, normal = TRUE)
    iqt12_csv(rank, file.path(run, "selections/normal_rank.csv"))
    keep <- rank[ism1_diverse_select(rank, 50L), ]
    iqt12_csv(keep, file.path(run, "selections/normal_diverse_top50.csv"))
    for (id in keep$candidate_id) {
      c <- state$bank[[match(id, vapply(state$bank, `[[`, "", "id"))]]
      for (fold in ism1_folds) add(ism1_config(state, ism1_sentinel,
        c, next_stage, "vb", fold))
    }
    for (fold in ism1_folds) add(ism1_config(state, ism1_sentinel,
      state$references[[ism1_sentinel]]$candidate, next_stage, "vb", fold,
      model = "baseline"))
  } else if (finished == "quantile_screen") {
    rank <- ism1_aggregate(run, finished)
    iqt12_csv(rank, file.path(run, "selections/quantile_rank.csv"))
    eligible <- rank[rank$readout_dimension <= 500L, ]
    keep <- head(eligible, 6L)
    if (nrow(keep) < 3L) stop("Insufficient online-feasible quantile finalists")
    iqt12_csv(keep, file.path(run, "selections/online_top6.csv"))
    for (id in keep$candidate_id) {
      c <- state$bank[[match(id, vapply(state$bank, `[[`, "", "id"))]]
      for (fold in ism1_folds) add(ism1_config(state, ism1_sentinel,
        c, next_stage, "vb", fold, online_update = TRUE))
    }
  } else if (finished == "online_pilot") {
    static <- ism1_aggregate(run, "quantile_screen")
    online <- ism1_aggregate(run, finished, online = TRUE)
    audit <- merge(online, static, by = "candidate_id", suffixes = c("_online", "_static"))
    audit$online_mae_gain <- audit$median_forecast_mae_online < audit$median_forecast_mae_static
    iqt12_csv(audit, file.path(run, "summaries/online_mechanism_audit.csv"))
    rank <- static
    feasible <- rank[rank$readout_dimension <= 500L, ]
    keep <- head(feasible, 12L)
    iqt12_csv(keep, file.path(run, "selections/short_mcmc_top12.csv"))
    for (id in keep$candidate_id) {
      c <- state$bank[[match(id, vapply(state$bank, `[[`, "", "id"))]]
      for (fold in c("S2", "S4")) {
        cfg <- ism1_config(state, ism1_sentinel, c, next_stage, "mcmc", fold)
        warm <- ism1_warm(run, "quantile_screen", id, fold)
        cfg$warm_path <- warm$path; cfg$warm_sha <- warm$sha; add(cfg)
      }
    }
    for (fold in c("S2", "S4")) {
      cfg <- ism1_config(state, ism1_sentinel,
        state$references[[ism1_sentinel]]$candidate, next_stage, "mcmc", fold,
        model = "baseline")
      vb <- ism1_results(run, "quantile_screen")
      row <- vb[vb$model == "baseline" & vb$fold == fold, ][1L, ]
      p <- file.path(iqt12_read(row$config_path)$evidence, "mcmc_initializer.json")
      cfg$warm_path <- p; cfg$warm_sha <- unname(tools::sha256sum(p)); add(cfg)
    }
  } else if (finished == "short_mcmc") {
    rank <- ism1_aggregate(run, finished)
    keep <- head(rank, 3L)
    iqt12_csv(keep, file.path(run, "selections/full_mcmc_top3.csv"))
    for (id in keep$candidate_id) {
      c <- state$bank[[match(id, vapply(state$bank, `[[`, "", "id"))]]
      for (fold in ism1_folds) for (chain in 1:3) {
        cfg <- ism1_config(state, ism1_sentinel, c, next_stage, "mcmc", fold, chain = chain)
        warm <- ism1_warm(run, "quantile_screen", id, fold)
        cfg$warm_path <- warm$path; cfg$warm_sha <- warm$sha; add(cfg)
      }
    }
    for (fold in ism1_folds) for (chain in 1:3) {
      c <- state$references[[ism1_sentinel]]$candidate
      cfg <- ism1_config(state, ism1_sentinel, c, next_stage, "mcmc", fold,
        model = "baseline", chain = chain)
      vb <- ism1_results(run, "quantile_screen")
      row <- vb[vb$model == "baseline" & vb$fold == fold, ][1L, ]
      p <- file.path(iqt12_read(row$config_path)$evidence, "mcmc_initializer.json")
      cfg$warm_path <- p; cfg$warm_sha <- unname(tools::sha256sum(p)); add(cfg)
    }
  } else if (finished == "full_mcmc") {
    rank <- ism1_aggregate(run, finished)
    iqt12_csv(rank, file.path(run, "selections/sentinel_full_mcmc_rank.csv"))
    selected <- iqt12_read(rank$config_path[1L])$candidate
    iqt12_json(selected, file.path(run, "selections/sentinel_selected_candidate.json"))
    for (cell in ism1_controls) {
      ref <- state$references[[cell]]$candidate
      candidates <- list(ism1_candidate(ref, ref, "reservoir_only", 15, 1,
        "control_anchor"), ism1_control_candidate(selected, ref))
      candidates <- candidates[!duplicated(vapply(candidates, `[[`, "", "id"))]
      for (c in candidates) for (fold in ism1_folds)
        add(ism1_config(state, cell, c, next_stage, "vb", fold))
      for (fold in ism1_folds) add(ism1_config(state, cell, ref,
        next_stage, "vb", fold, model = "baseline"))
    }
  } else if (finished == "controls_vb") {
    for (cell in ism1_controls) {
      z <- result[result$cell == cell, ]
      ids <- unique(z$candidate_id[z$model == "qdesn"])
      ranks <- lapply(ids, function(id) {
        q <- z[z$candidate_id == id & z$model == "qdesn", ]
        data.frame(candidate_id = id,
          mae = median(q$mean[q$metric == "forecast_mae"]))
      })
      id <- do.call(rbind, ranks)$candidate_id[which.min(do.call(rbind, ranks)$mae)]
      cfg0 <- iqt12_read(z$config_path[z$candidate_id == id][1L]); c <- cfg0$candidate
      for (fold in c("S2", "S4")) for (chain in 1:3) {
        cfg <- ism1_config(state, cell, c, next_stage, "mcmc", fold, chain = chain)
        row <- z[z$candidate_id == id & z$fold == fold & z$model == "qdesn", ][1L, ]
        p <- file.path(iqt12_read(row$config_path)$evidence, "mcmc_initializer.json")
        cfg$warm_path <- p; cfg$warm_sha <- unname(tools::sha256sum(p)); add(cfg)
      }
      for (fold in c("S2", "S4")) for (chain in 1:3) {
        ref <- state$references[[cell]]$candidate
        cfg <- ism1_config(state, cell, ref, next_stage, "mcmc", fold,
          model = "baseline", chain = chain)
        row <- z[z$model == "baseline" & z$fold == fold, ][1L, ]
        p <- file.path(iqt12_read(row$config_path)$evidence, "mcmc_initializer.json")
        cfg$warm_path <- p; cfg$warm_sha <- unname(tools::sha256sum(p)); add(cfg)
      }
    }
  } else if (finished == "controls_mcmc") {
    return(ism1_closeout(run))
  } else stop("Unsupported sentinel stage")
  ism1_plan(state, configs, next_stage)
  next_stage
}

ism1_closeout <- function(run) {
  state <- iqt12_read(file.path(run, "campaign.json"))
  stages <- c("full_mcmc", "controls_mcmc")
  rows <- ism1_results(run, stages)
  aggregate <- do.call(rbind, lapply(split(rows, paste(rows$cell, rows$model,
    rows$candidate_id, rows$metric, sep = "|")), function(z) data.frame(
      cell = z$cell[1L], model = z$model[1L], candidate_id = z$candidate_id[1L],
      metric = z$metric[1L], mean = mean(z$mean), fold_median = median(z$mean),
      fold_max = max(z$mean), chains = length(unique(paste(z$fold, z$chain))))))
  iqt12_csv(aggregate, file.path(run, "review/multifold_multichain_metrics.csv"))
  sentinel <- aggregate[aggregate$cell == ism1_sentinel &
    aggregate$metric == "forecast_mae", ]
  q <- sentinel[sentinel$model == "qdesn", ]; b <- sentinel[sentinel$model == "baseline", ]
  q$ratio_to_exDQLM <- q$mean / b$mean[1L]
  q$strict_gain <- q$mean < b$mean[1L]
  iqt12_csv(q, file.path(run, "review/sentinel_decision_ledger.csv"))
  payloads <- list.files(run, recursive = TRUE, full.names = TRUE,
    pattern = "[.](rds|rda|RData)$", ignore.case = TRUE)
  stopifnot(!length(payloads))
  iqt12_json(list(status = "COMPLETE_REVIEW_REQUIRED", article_changed = FALSE,
    scientific_decision = "SENTINEL_MECHANISM_COMPLETE_NOT_ARTICLE_PROMOTION",
    active_jobs = 0L, sentinel_strict_gain = any(q$strict_gain),
    next_action = "investigator_review_then_fresh_DGP_confirmation_if_supported"),
    file.path(run, "closeout.json"))
  artifact_files <- function(path) {
    files <- list.files(path, recursive = TRUE, full.names = TRUE)
    files[file.exists(files) & !file.info(files)$isdir]
  }
  files <- c(file.path(run, c("campaign.json", "environment.json", "candidate_bank.csv",
    "source_hashes.csv", "input_hashes.csv", "package_hashes.csv", "frozen_hashes.csv",
    "closeout.json")), artifact_files(file.path(run, "selections")),
    artifact_files(file.path(run, "review")))
  iqt12_hash(files, file.path(run, "closeout_manifest.csv"))
  "COMPLETE_REVIEW_REQUIRED"
}

ism1_health <- function(run) {
  plans <- list.files(file.path(run, "plans"), "[.]csv$", full.names = TRUE)
  plans <- plans[!grepl("_hashes[.]csv$", plans)]
  z <- do.call(rbind, lapply(plans, read.csv, stringsAsFactors = FALSE))
  status <- vapply(z$status_path, function(p)
    if (file.exists(p)) iqt12_read(p)$status else "PENDING", "")
  data.frame(total = nrow(z), complete = sum(status == "SUCCESS"),
    running = sum(status == "RUNNING"), pending = sum(status == "PENDING"),
    failed = sum(grepl("FAILED", status)), stages = length(unique(z$stage)))
}

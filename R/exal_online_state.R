# Shared natural-parameter helpers for exAL VB beta updates.

.exal_default_vb_chunking_cfg <- function() {
  list(
    enabled = FALSE,
    mode = "exact",
    chunk_size = NULL,
    order = "sequential",
    trace = FALSE,
    seed = NULL,
    learning_rate = list(
      schedule = "robbins_monro",
      t0 = 10,
      kappa = 0.75,
      rho_min = 1.0e-4
    ),
    refresh = list(
      full_every = 20L,
      objective_every = 20L,
      sigma_every = 5L,
      rhs_every = 20L,
      local_every = 20L
    ),
    diagnostics = list(
      trace = TRUE,
      store_batch_ids = FALSE,
      check_finite_every = 1L
    )
  )
}

.exal_normalize_vb_chunking_cfg <- function(chunking = NULL) {
  `%||%` <- function(a, b) if (is.null(a)) b else a
  cfg <- .exal_default_vb_chunking_cfg()
  if (is.null(chunking)) return(cfg)
  if (!is.list(chunking)) .stopf("vb_control$chunking must be a list.")

  for (nm in names(chunking)) cfg[[nm]] <- chunking[[nm]]
  cfg$enabled <- isTRUE(cfg$enabled)

  cfg$mode <- tolower(as.character(cfg$mode %||% "exact")[1L])
  if (!cfg$mode %in% c("exact", "stochastic", "hybrid")) {
    .stopf("vb_control$chunking$mode must be 'exact', 'stochastic', or 'hybrid'.")
  }

  if (is.null(cfg$chunk_size) || length(cfg$chunk_size) == 0L || is.na(cfg$chunk_size[1L])) {
    cfg$chunk_size <- if (cfg$mode %in% c("stochastic", "hybrid")) 512L else NULL
  } else {
    cfg$chunk_size <- as.integer(cfg$chunk_size[1L])
    if (!is.finite(cfg$chunk_size) || cfg$chunk_size < 1L) {
      .stopf("vb_control$chunking$chunk_size must be NULL or a positive integer.")
    }
  }

  cfg$order <- tolower(as.character(cfg$order %||% "sequential")[1L])
  if (identical(cfg$mode, "exact") && !identical(cfg$order, "sequential")) {
    .stopf("vb_control$chunking$order must be 'sequential' for exact chunking.")
  }
  if (cfg$mode %in% c("stochastic", "hybrid") && !cfg$order %in% c("random", "shuffled", "sequential")) {
    .stopf("vb_control$chunking$order must be 'random', 'shuffled', or 'sequential' for stochastic or hybrid chunking.")
  }

  cfg$trace <- isTRUE(cfg$trace)

  if (identical(cfg$mode, "exact")) {
    return(list(
      enabled = cfg$enabled,
      mode = cfg$mode,
      chunk_size = cfg$chunk_size,
      order = cfg$order,
      trace = cfg$trace
    ))
  }

  if (is.null(cfg$seed) || length(cfg$seed) == 0L || is.na(cfg$seed[1L])) {
    cfg$seed <- NULL
  } else {
    cfg$seed <- as.integer(cfg$seed[1L])
    if (!is.finite(cfg$seed)) .stopf("vb_control$chunking$seed must be NULL or a finite integer.")
  }

  lr <- cfg$learning_rate %||% list()
  if (!is.list(lr)) .stopf("vb_control$chunking$learning_rate must be a list.")
  lr_def <- .exal_default_vb_chunking_cfg()$learning_rate
  lr <- utils::modifyList(lr_def, lr)
  lr$schedule <- tolower(as.character(lr$schedule %||% "robbins_monro")[1L])
  if (!identical(lr$schedule, "robbins_monro")) {
    .stopf("vb_control$chunking$learning_rate$schedule must be 'robbins_monro'.")
  }
  lr$t0 <- as.numeric(lr$t0)[1L]
  lr$kappa <- as.numeric(lr$kappa)[1L]
  lr$rho_min <- as.numeric(lr$rho_min)[1L]
  if (!is.finite(lr$t0) || lr$t0 <= 0) {
    .stopf("vb_control$chunking$learning_rate$t0 must be finite and > 0.")
  }
  if (!is.finite(lr$kappa) || lr$kappa <= 0.5 || lr$kappa > 1) {
    .stopf("vb_control$chunking$learning_rate$kappa must be finite with 0.5 < kappa <= 1.")
  }
  if (!is.finite(lr$rho_min) || lr$rho_min < 0 || lr$rho_min >= 1) {
    .stopf("vb_control$chunking$learning_rate$rho_min must be finite with 0 <= rho_min < 1.")
  }

  normalize_every <- function(x, nm) {
    x <- as.integer(x)[1L]
    if (!is.finite(x) || x < 1L) {
      .stopf("vb_control$chunking$refresh$%s must be a positive integer.", nm)
    }
    x
  }
  refresh <- cfg$refresh %||% list()
  if (!is.list(refresh)) .stopf("vb_control$chunking$refresh must be a list.")
  refresh <- utils::modifyList(.exal_default_vb_chunking_cfg()$refresh, refresh)
  refresh <- list(
    full_every = normalize_every(refresh$full_every, "full_every"),
    objective_every = normalize_every(refresh$objective_every, "objective_every"),
    sigma_every = normalize_every(refresh$sigma_every, "sigma_every"),
    rhs_every = normalize_every(refresh$rhs_every, "rhs_every"),
    local_every = normalize_every(refresh$local_every, "local_every")
  )

  diag_cfg <- cfg$diagnostics %||% list()
  if (!is.list(diag_cfg)) .stopf("vb_control$chunking$diagnostics must be a list.")
  diag_cfg <- utils::modifyList(.exal_default_vb_chunking_cfg()$diagnostics, diag_cfg)
  diag_cfg$trace <- if (is.null(diag_cfg$trace)) cfg$trace else isTRUE(diag_cfg$trace)
  diag_cfg$store_batch_ids <- isTRUE(diag_cfg$store_batch_ids)
  diag_cfg$check_finite_every <- as.integer(diag_cfg$check_finite_every)[1L]
  if (!is.finite(diag_cfg$check_finite_every) || diag_cfg$check_finite_every < 1L) {
    .stopf("vb_control$chunking$diagnostics$check_finite_every must be a positive integer.")
  }

  list(
    enabled = cfg$enabled,
    mode = cfg$mode,
    chunk_size = cfg$chunk_size,
    order = cfg$order,
    trace = cfg$trace,
    seed = cfg$seed,
    learning_rate = lr,
    refresh = refresh,
    diagnostics = diag_cfg
  )
}

.exal_make_row_chunks <- function(n, chunk_size = NULL) {
  n <- as.integer(n)[1L]
  if (!is.finite(n) || n < 0L) .stopf("row chunks: n must be a non-negative integer.")
  if (n == 0L) return(list(integer(0)))

  if (is.null(chunk_size) || length(chunk_size) == 0L || is.na(chunk_size[1L])) {
    chunk_size <- n
  } else {
    chunk_size <- as.integer(chunk_size[1L])
    if (!is.finite(chunk_size) || chunk_size < 1L) {
      .stopf("row chunks: chunk_size must be NULL or a positive integer.")
    }
  }

  starts <- seq.int(1L, n, by = chunk_size)
  lapply(starts, function(i) seq.int(i, min(n, i + chunk_size - 1L)))
}

.exal_with_seed <- function(seed, expr) {
  if (is.null(seed)) return(eval.parent(substitute(expr)))
  seed <- as.integer(seed)[1L]
  old_seed <- if (exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)) {
    get(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
  } else {
    NULL
  }
  on.exit({
    if (is.null(old_seed)) {
      if (exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)) {
        rm(".Random.seed", envir = .GlobalEnv)
      }
    } else {
      assign(".Random.seed", old_seed, envir = .GlobalEnv)
    }
  }, add = TRUE)
  set.seed(seed)
  eval.parent(substitute(expr))
}

.exal_batch_sampler_init <- function(n, chunk_size = NULL, order = "random", seed = NULL) {
  `%||%` <- function(a, b) if (is.null(a)) b else a
  n <- as.integer(n)[1L]
  if (!is.finite(n) || n < 1L) .stopf("batch sampler: n must be a positive integer.")
  if (is.null(chunk_size) || length(chunk_size) == 0L || is.na(chunk_size[1L])) {
    chunk_size <- n
  } else {
    chunk_size <- as.integer(chunk_size[1L])
  }
  if (!is.finite(chunk_size) || chunk_size < 1L) {
    .stopf("batch sampler: chunk_size must be NULL or a positive integer.")
  }
  chunk_size <- min(chunk_size, n)

  order <- tolower(as.character(order %||% "random")[1L])
  if (!order %in% c("random", "shuffled", "sequential")) {
    .stopf("batch sampler: order must be 'random', 'shuffled', or 'sequential'.")
  }
  if (is.null(seed) || length(seed) == 0L || is.na(seed[1L])) {
    seed <- NULL
  } else {
    seed <- as.integer(seed[1L])
    if (!is.finite(seed)) .stopf("batch sampler: seed must be NULL or a finite integer.")
  }

  permutation <- seq_len(n)
  if (identical(order, "shuffled")) {
    permutation <- .exal_with_seed(seed %||% sample.int(.Machine$integer.max, 1L), sample.int(n))
  }

  list(
    n = n,
    chunk_size = as.integer(chunk_size),
    order = order,
    seed = seed,
    step = 0L,
    epoch = 1L,
    position = 1L,
    permutation = as.integer(permutation)
  )
}

.exal_batch_sampler_next <- function(state) {
  `%||%` <- function(a, b) if (is.null(a)) b else a
  if (!is.list(state)) .stopf("batch sampler state must be a list.")
  n <- as.integer(state$n)[1L]
  chunk_size <- as.integer(state$chunk_size)[1L]
  order <- as.character(state$order)[1L]
  if (!is.finite(n) || n < 1L || !is.finite(chunk_size) || chunk_size < 1L) {
    .stopf("batch sampler state has invalid n or chunk_size.")
  }
  chunk_size <- min(chunk_size, n)

  step <- as.integer(state$step %||% 0L) + 1L
  epoch <- as.integer(state$epoch %||% 1L)
  position <- as.integer(state$position %||% 1L)
  seed <- state$seed

  if (identical(order, "random")) {
    idx <- .exal_with_seed(if (is.null(seed)) NULL else seed + step, sample.int(n, chunk_size))
    epoch <- ceiling(step / ceiling(n / chunk_size))
  } else {
    permutation <- as.integer(state$permutation %||% seq_len(n))
    if (length(permutation) != n) permutation <- seq_len(n)
    if (position > n) {
      epoch <- epoch + 1L
      position <- 1L
      if (identical(order, "shuffled")) {
        permutation <- .exal_with_seed(if (is.null(seed)) NULL else seed + epoch - 1L, sample.int(n))
      }
    }
    stop_pos <- min(n, position + chunk_size - 1L)
    idx <- permutation[seq.int(position, stop_pos)]
    position <- stop_pos + 1L
    state$permutation <- as.integer(permutation)
  }

  state$step <- as.integer(step)
  state$epoch <- as.integer(epoch)
  state$position <- as.integer(position)
  list(
    state = state,
    idx = as.integer(idx),
    step = as.integer(step),
    epoch = as.integer(epoch)
  )
}

.exal_learning_rate <- function(t, learning_rate) {
  if (!is.list(learning_rate)) .stopf("learning_rate must be a list.")
  cfg <- utils::modifyList(.exal_default_vb_chunking_cfg()$learning_rate, learning_rate)
  schedule <- tolower(as.character(cfg$schedule %||% "robbins_monro")[1L])
  if (!identical(schedule, "robbins_monro")) .stopf("learning_rate$schedule must be 'robbins_monro'.")
  t <- as.integer(t)[1L]
  t0 <- as.numeric(cfg$t0)[1L]
  kappa <- as.numeric(cfg$kappa)[1L]
  rho_min <- as.numeric(cfg$rho_min)[1L]
  if (!is.finite(t) || t < 1L) .stopf("learning rate step t must be a positive integer.")
  if (!is.finite(t0) || t0 <= 0) .stopf("learning_rate$t0 must be finite and > 0.")
  if (!is.finite(kappa) || kappa <= 0.5 || kappa > 1) .stopf("learning_rate$kappa must be finite with 0.5 < kappa <= 1.")
  if (!is.finite(rho_min) || rho_min < 0 || rho_min >= 1) .stopf("learning_rate$rho_min must be finite with 0 <= rho_min < 1.")
  as.numeric(max(rho_min, (t0 + t)^(-kappa)))
}

.exal_stochastic_beta_stats <- function(X, y, xis, qv_m_inv, qs_m, batch_idx, n_total = nrow(X)) {
  assert_matrix(X, "X")
  y <- as.numeric(y)
  n <- nrow(X)
  p <- ncol(X)
  if (length(y) != n) .stopf("stochastic beta stats: y length must match nrow(X).")
  qv_m_inv <- as.numeric(qv_m_inv)
  qs_m <- as.numeric(qs_m)
  if (length(qv_m_inv) != n || length(qs_m) != n) {
    .stopf("stochastic beta stats: qv_m_inv and qs_m lengths must match nrow(X).")
  }
  batch_idx <- as.integer(batch_idx)
  if (!length(batch_idx)) .stopf("stochastic beta stats: batch_idx must be non-empty.")
  if (any(!is.finite(batch_idx)) || any(batch_idx < 1L) || any(batch_idx > n)) {
    .stopf("stochastic beta stats: batch_idx contains rows outside 1:n.")
  }
  n_total <- as.numeric(n_total)[1L]
  if (!is.finite(n_total) || n_total < length(batch_idx)) {
    .stopf("stochastic beta stats: n_total must be finite and at least the batch size.")
  }

  stats <- .exal_beta_data_stats(
    X = X[batch_idx, , drop = FALSE],
    y = y[batch_idx],
    xis = xis,
    qv_m_inv = qv_m_inv[batch_idx],
    qs_m = qs_m[batch_idx]
  )
  scale <- as.numeric(n_total / length(batch_idx))
  list(
    batch_idx = batch_idx,
    scale = scale,
    batch_size = length(batch_idx),
    n_total = as.integer(n_total),
    barw = stats$barw,
    barm = stats$barm,
    S = 0.5 * (scale * stats$S + t(scale * stats$S)),
    g = as.numeric(scale * stats$g),
    p = p
  )
}

.exal_effective_barw_barm <- function(y, xis, qv_m_inv, qs_m) {
  y <- as.numeric(y)
  qv_m_inv <- as.numeric(qv_m_inv)
  qs_m <- as.numeric(qs_m)
  n <- length(y)
  if (length(qv_m_inv) != n || length(qs_m) != n) {
    .stopf("effective moments: y, qv_m_inv, qs_m lengths must match.")
  }

  xi1 <- as.numeric(xis$xi1)
  xi_lambda <- as.numeric(xis$xi_lambda)
  xi_A <- as.numeric(xis$xi_A)
  if (!is.finite(xi1) || !is.finite(xi_lambda) || !is.finite(xi_A)) {
    .stopf("effective moments: xis contains non-finite values.")
  }

  barw <- as.numeric(xi1 * qv_m_inv)
  barw <- pmax(barw, 1e-16)
  barm <- as.numeric(y * barw - xi_lambda * (qv_m_inv * qs_m) - xi_A)

  if (any(!is.finite(barw)) || any(barw <= 0)) {
    .stopf("effective moments: invalid barw.")
  }
  if (any(!is.finite(barm))) {
    .stopf("effective moments: invalid barm.")
  }

  list(barw = barw, barm = barm)
}

.exal_check_chunks <- function(chunks, n, context = "chunks") {
  if (is.null(chunks)) return(.exal_make_row_chunks(n))
  if (!is.list(chunks)) .stopf("%s must be a list of integer row indices.", context)
  if (!length(chunks)) .stopf("%s must contain at least one chunk.", context)

  seen <- integer(0)
  for (idx in chunks) {
    idx <- as.integer(idx)
    if (!length(idx)) next
    if (any(!is.finite(idx)) || any(idx < 1L) || any(idx > n)) {
      .stopf("%s contains row indices outside 1:n.", context)
    }
    seen <- c(seen, idx)
  }
  if (!identical(sort(seen), seq_len(n))) {
    .stopf("%s must cover each row exactly once.", context)
  }
  lapply(chunks, as.integer)
}

.exal_beta_data_stats <- function(X, y, xis, qv_m_inv, qs_m) {
  assert_matrix(X, "X")
  y <- as.numeric(y)
  if (length(y) != nrow(X)) .stopf("beta data stats: y length must match nrow(X).")

  eff <- .exal_effective_barw_barm(
    y = y,
    xis = xis,
    qv_m_inv = qv_m_inv,
    qs_m = qs_m
  )

  Xw <- X * sqrt(eff$barw)
  S <- crossprod(Xw)
  S <- 0.5 * (S + t(S))
  g <- as.numeric(crossprod(X, eff$barm))

  out <- list(
    barw = eff$barw,
    barm = eff$barm,
    S = S,
    g = g
  )
}

.exal_beta_data_stats_chunks <- function(X, y, xis, qv_m_inv, qs_m, chunks = NULL) {
  assert_matrix(X, "X")
  y <- as.numeric(y)
  n <- nrow(X)
  p <- ncol(X)
  if (length(y) != n) .stopf("chunked beta data stats: y length must match nrow(X).")

  eff <- .exal_effective_barw_barm(
    y = y,
    xis = xis,
    qv_m_inv = qv_m_inv,
    qs_m = qs_m
  )
  chunks <- .exal_check_chunks(chunks, n, context = "chunked beta data stats: chunks")

  S <- matrix(0, p, p)
  g <- numeric(p)
  for (idx in chunks) {
    if (!length(idx)) next
    X_i <- X[idx, , drop = FALSE]
    Xw_i <- X_i * sqrt(eff$barw[idx])
    S <- S + crossprod(Xw_i)
    g <- g + as.numeric(crossprod(X_i, eff$barm[idx]))
  }
  S <- 0.5 * (S + t(S))

  list(
    barw = eff$barw,
    barm = eff$barm,
    S = S,
    g = as.numeric(g)
  )
}

.exal_beta_solve_from_data_stats <- function(stats, prec_diag,
                                            prior_precision = NULL,
                                            prior_natural = NULL) {
  if (!is.list(stats) || is.null(stats$S) || is.null(stats$g)) {
    .stopf("beta solve: stats must contain S and g.")
  }
  S <- as.matrix(stats$S)
  p <- ncol(S)
  if (!all(dim(S) == c(p, p))) .stopf("beta solve: stats$S must be square.")
  g <- as.numeric(stats$g)
  if (length(g) != p) .stopf("beta solve: stats$g must have length p.")

  prec_diag <- as.numeric(prec_diag)
  if (length(prec_diag) != p) {
    .stopf("beta solve: prec_diag must have length p=%d.", p)
  }
  if (any(!is.finite(prec_diag)) || any(prec_diag <= 0)) {
    .stopf("beta solve: prec_diag must be finite and > 0.")
  }

  P <- S + diag(prec_diag, p)
  if (!is.null(prior_precision)) {
    prior_precision <- as.matrix(prior_precision)
    if (!all(dim(prior_precision) == c(p, p)) || any(!is.finite(prior_precision))) {
      .stopf("beta solve: prior_precision must be a finite p x p matrix.")
    }
    prior_precision <- 0.5 * (prior_precision + t(prior_precision))
    P <- P + prior_precision
  }
  P <- 0.5 * (P + t(P))
  h <- g
  if (!is.null(prior_natural)) {
    prior_natural <- as.numeric(prior_natural)
    if (length(prior_natural) != p || any(!is.finite(prior_natural))) {
      .stopf("beta solve: prior_natural must be finite with length p=%d.", p)
    }
    h <- h + prior_natural
  }
  sol <- .solve_sympd(P, h)

  list(
    P = P,
    h = h,
    prec_diag = prec_diag,
    prior_precision = prior_precision,
    prior_natural = prior_natural,
    sol = sol
  )
}

.exal_beta_natural_stats <- function(X, y, xis, qv_m_inv, qs_m, prec_diag = NULL) {
  out <- .exal_beta_data_stats(
    X = X,
    y = y,
    xis = xis,
    qv_m_inv = qv_m_inv,
    qs_m = qs_m
  )

  if (!is.null(prec_diag)) {
    solved <- .exal_beta_solve_from_data_stats(out, prec_diag)
    out$P <- solved$P
    out$h <- solved$h
    out$prec_diag <- solved$prec_diag
  }

  out
}

.exal_row_quad_form_chunks <- function(X, V, m = NULL, chunks = NULL) {
  assert_matrix(X, "X")
  V <- as.matrix(V)
  p <- ncol(X)
  n <- nrow(X)
  if (!all(dim(V) == c(p, p))) .stopf("row quadratic chunks: V must be p x p.")
  chunks <- .exal_check_chunks(chunks, n, context = "row quadratic chunks: chunks")

  q_i <- numeric(n)
  xb <- if (is.null(m)) NULL else numeric(n)
  if (!is.null(m)) {
    m <- as.numeric(m)
    if (length(m) != p) .stopf("row quadratic chunks: m must have length p.")
  }

  for (idx in chunks) {
    if (!length(idx)) next
    X_i <- X[idx, , drop = FALSE]
    q_i[idx] <- rowSums((X_i %*% V) * X_i)
    if (!is.null(m)) xb[idx] <- as.numeric(X_i %*% m)
  }

  out <- list(q_i = as.numeric(q_i))
  if (!is.null(m)) out$xb <- as.numeric(xb)
  out
}

.exal_local_updates_chunks <- function(X, y, qbeta, qv, qs, xis, chunks = NULL) {
  assert_matrix(X, "X")
  y <- as.numeric(y)
  n <- nrow(X)
  if (length(y) != n) .stopf("chunked local updates: y length must match nrow(X).")
  chunks <- .exal_check_chunks(chunks, n, context = "chunked local updates: chunks")

  row_quad <- .exal_row_quad_form_chunks(
    X = X,
    V = qbeta$V,
    m = qbeta$m,
    chunks = chunks
  )
  xb <- row_quad$xb
  q_i <- row_quad$q_i

  qv_m <- qv_m_inv <- chi <- z_gig <- numeric(n)
  psi <- NA_real_
  qs_m <- qs_m2 <- mu_s <- tau2 <- numeric(n)

  for (idx in chunks) {
    if (!length(idx)) next
    qv_i <- .exal_local_qv_update(
      y = y[idx],
      xb = xb[idx],
      q_i = q_i[idx],
      qs_m = qs$m[idx],
      qs_m2 = qs$m2[idx],
      xis = xis
    )
    qv_m[idx] <- as.numeric(qv_i$m)
    qv_m_inv[idx] <- as.numeric(qv_i$m_inv)
    chi[idx] <- as.numeric(qv_i$chi)
    z_gig[idx] <- as.numeric(qv_i$z)
    psi <- as.numeric(qv_i$psi)

    qs_i <- .exal_local_qs_update(
      y = y[idx],
      xb = xb[idx],
      qv_m_inv = qv_m_inv[idx],
      xis = xis
    )
    qs_m[idx] <- as.numeric(qs_i$m)
    qs_m2[idx] <- as.numeric(qs_i$m2)
    mu_s[idx] <- as.numeric(qs_i$mu)
    tau2[idx] <- as.numeric(qs_i$tau2)
  }

  list(
    xb = as.numeric(xb),
    t_i = as.numeric(y - xb),
    q_i = as.numeric(q_i),
    qv = list(
      m = as.numeric(qv_m),
      m_inv = as.numeric(qv_m_inv),
      chi = as.numeric(chi),
      psi = as.numeric(psi),
      z = as.numeric(z_gig)
    ),
    qs = list(
      m = as.numeric(qs_m),
      m2 = as.numeric(qs_m2),
      mu = as.numeric(mu_s),
      tau2 = as.numeric(tau2)
    )
  )
}

.exal_sigmagam_stats_chunks <- function(X, y, qbeta, qv, qs, chunks = NULL, xb = NULL, q_i = NULL) {
  assert_matrix(X, "X")
  y <- as.numeric(y)
  n <- nrow(X)
  if (length(y) != n) .stopf("chunked sigmagam stats: y length must match nrow(X).")
  chunks <- .exal_check_chunks(chunks, n, context = "chunked sigmagam stats: chunks")

  if (is.null(xb) || is.null(q_i)) {
    row_quad <- .exal_row_quad_form_chunks(
      X = X,
      V = qbeta$V,
      m = qbeta$m,
      chunks = chunks
    )
    xb <- row_quad$xb
    q_i <- row_quad$q_i
  } else {
    xb <- as.numeric(xb)
    q_i <- as.numeric(q_i)
    if (length(xb) != n || length(q_i) != n) {
      .stopf("chunked sigmagam stats: xb and q_i lengths must match nrow(X).")
    }
  }

  mv_inv <- as.numeric(qv$m_inv)
  mv <- as.numeric(qv$m)
  ms <- as.numeric(qs$m)
  ms2 <- as.numeric(qs$m2)
  if (length(mv_inv) != n || length(mv) != n || length(ms) != n || length(ms2) != n) {
    .stopf("chunked sigmagam stats: qv and qs lengths must match nrow(X).")
  }

  out <- c(S1 = 0, S2 = 0, S3 = 0, S4 = 0, S5 = 0, S6 = 0)
  t_i <- as.numeric(y - xb)
  for (idx in chunks) {
    if (!length(idx)) next
    out[["S1"]] <- out[["S1"]] + sum(mv_inv[idx] * (t_i[idx]^2 + q_i[idx]))
    out[["S2"]] <- out[["S2"]] + sum(t_i[idx])
    out[["S3"]] <- out[["S3"]] + sum(mv[idx])
    out[["S4"]] <- out[["S4"]] + sum(ms[idx] * mv_inv[idx] * t_i[idx])
    out[["S5"]] <- out[["S5"]] + sum(ms2[idx] * mv_inv[idx])
    out[["S6"]] <- out[["S6"]] + sum(ms[idx])
  }

  list(
    S1 = as.numeric(out[["S1"]]),
    S2 = as.numeric(out[["S2"]]),
    S3 = as.numeric(out[["S3"]]),
    S4 = as.numeric(out[["S4"]]),
    S5 = as.numeric(out[["S5"]]),
    S6 = as.numeric(out[["S6"]]),
    xb = as.numeric(xb),
    t_i = as.numeric(t_i),
    q_i = as.numeric(q_i)
  )
}

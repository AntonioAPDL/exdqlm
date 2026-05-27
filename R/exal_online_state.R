# Shared natural-parameter helpers for exAL VB beta updates.

.exal_default_vb_chunking_cfg <- function() {
  list(
    enabled = FALSE,
    mode = "exact",
    chunk_size = NULL,
    order = "sequential",
    trace = FALSE
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
  if (!identical(cfg$mode, "exact")) {
    .stopf("vb_control$chunking$mode must be 'exact'.")
  }

  if (is.null(cfg$chunk_size) || length(cfg$chunk_size) == 0L || is.na(cfg$chunk_size[1L])) {
    cfg$chunk_size <- NULL
  } else {
    cfg$chunk_size <- as.integer(cfg$chunk_size[1L])
    if (!is.finite(cfg$chunk_size) || cfg$chunk_size < 1L) {
      .stopf("vb_control$chunking$chunk_size must be NULL or a positive integer.")
    }
  }

  cfg$order <- tolower(as.character(cfg$order %||% "sequential")[1L])
  if (!identical(cfg$order, "sequential")) {
    .stopf("vb_control$chunking$order must be 'sequential' for exact chunking.")
  }

  cfg$trace <- isTRUE(cfg$trace)
  cfg
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

.exal_beta_solve_from_data_stats <- function(stats, prec_diag) {
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
  P <- 0.5 * (P + t(P))
  sol <- .solve_sympd(P, g)

  list(
    P = P,
    h = g,
    prec_diag = prec_diag,
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

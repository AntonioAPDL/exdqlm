.stopf <- function(fmt, ...) stop(sprintf(fmt, ...), call. = FALSE)

`%||%` <- function(x, y) if (!is.null(x)) x else y

assert_scalar_numeric <- function(x, nm) {
  if (!is.numeric(x) || length(x) != 1L || !is.finite(x)) .stopf("%s must be a finite numeric scalar.", nm)
  invisible(TRUE)
}

assert_matrix <- function(X, nm) {
  if (!is.matrix(X) || !is.numeric(X)) .stopf("%s must be a numeric matrix.", nm)
  invisible(TRUE)
}

is_diag_matrix <- function(M, tol = 0) {
  if (!is.matrix(M)) return(FALSE)
  off <- M
  diag(off) <- 0
  all(abs(off) <= tol)
}

.require_fun <- function(fname, pkg = NULL) {
  stopifnot(is.character(fname), length(fname) == 1L, nzchar(fname))

  fn <- get0(fname, mode = "function", inherits = TRUE)
  if (is.function(fn)) return(fn)

  if (is.null(pkg)) pkg <- utils::packageName()
  if (!is.null(pkg)) {
    ns <- tryCatch(asNamespace(pkg), error = function(e) NULL)
    fn <- if (!is.null(ns)) get0(fname, envir = ns, mode = "function", inherits = FALSE) else NULL
    if (is.function(fn)) return(fn)
  }

  stop(sprintf("Required internal function '%s()' not found.", fname), call. = FALSE)
}


# ------------------------------------------------------------------------------
# Linear algebra helpers (SPD solve with jitter)
# ------------------------------------------------------------------------------

.solve_sympd <- function(A, b = NULL, jitter = 1e-10, max_tries = 8L) {
  if (!is.matrix(A)) .stopf(".solve_sympd: A must be a matrix.")
  if (nrow(A) != ncol(A)) .stopf(".solve_sympd: A must be square.")
  A <- 0.5 * (A + t(A))  # symmetrize

  p <- nrow(A)
  d0 <- mean(diag(A))
  if (!is.finite(d0) || d0 <= 0) d0 <- 1

  last_err <- NULL
  for (i in seq_len(max_tries)) {
    eps <- jitter * (10^(i - 1L)) * d0
    Ai <- A + diag(eps, p)
    L <- tryCatch(chol(Ai), error = function(e) e)
    if (!inherits(L, "error")) {
      Ainv <- chol2inv(L)
      if (is.null(b)) return(list(inv = Ainv, chol = L, method = "chol", jitter_eps = eps))
      x <- as.numeric(Ainv %*% b)
      return(list(inv = Ainv, chol = L, x = x, method = "chol", jitter_eps = eps))
    }
    last_err <- L
  }

  # eigen fallback (clips eigenvalues)
  eg <- eigen(A, symmetric = TRUE)
  vals <- pmax(eg$values, 1e-10)
  Ainv <- eg$vectors %*% diag(1 / vals, p) %*% t(eg$vectors)
  if (is.null(b)) return(list(inv = Ainv, chol = NULL, method = "eigen_fallback", jitter_eps = NA_real_))
  x <- as.numeric(Ainv %*% b)
  list(
    inv = Ainv,
    chol = NULL,
    x = x,
    warning = last_err$message %||% "chol failed",
    method = "eigen_fallback",
    jitter_eps = NA_real_
  )
}

# ------------------------------------------------------------------------------
# exAL constants lookup (robust to your internal naming)
# Returns list(A=..., B=..., C=...)
# ------------------------------------------------------------------------------

exal_get_ABC <- function(p0, gamma) {
  assert_scalar_numeric(p0, "p0")
  assert_scalar_numeric(gamma, "gamma")

  # 1) Try a single function returning A,B,C
  cand <- c("exal_ABC", "exal_consts", "exal_constants", "gal_constants", "exal_const")
  for (nm in cand) {
    if (!exists(nm, mode = "function", inherits = TRUE)) next
    fn <- get(nm, mode = "function", inherits = TRUE)

    out <- tryCatch(fn(p0 = p0, gamma = gamma), error = function(e) NULL)
    if (is.null(out)) out <- tryCatch(fn(p0, gamma), error = function(e) NULL)

    if (!is.null(out)) {
      if (is.list(out) && all(c("A","B","C") %in% names(out))) {
        return(list(A = as.numeric(out$A), B = as.numeric(out$B), C = as.numeric(out$C)))
      }
      if (is.numeric(out) && length(out) >= 3L) {
        return(list(A = as.numeric(out[1]), B = as.numeric(out[2]), C = as.numeric(out[3])))
      }
    }
  }

  # 2) Try separate functions A(·), B(·), C(·)
  Af <- c("A.fn","A_exal","exal_A","GAL_A")
  Bf <- c("B.fn","B_exal","exal_B","GAL_B")
  Cf <- c("C.fn","C_exal","exal_C","GAL_C")

  pick_fun <- function(v) {
    for (nm in v) if (exists(nm, mode="function", inherits=TRUE)) return(get(nm, mode="function", inherits=TRUE))
    NULL
  }

  fA <- pick_fun(Af); fB <- pick_fun(Bf); fC <- pick_fun(Cf)
  if (!is.null(fA) && !is.null(fB) && !is.null(fC)) {
    A <- tryCatch(fA(p0 = p0, gamma = gamma), error = function(e) fA(p0, gamma))
    B <- tryCatch(fB(p0 = p0, gamma = gamma), error = function(e) fB(p0, gamma))
    C <- tryCatch(fC(p0 = p0, gamma = gamma), error = function(e) fC(p0, gamma))
    return(list(A = as.numeric(A), B = as.numeric(B), C = as.numeric(C)))
  }

  .stopf(
    "Could not locate exAL constants A,B,C. Expected one of %s or separate A.fn/B.fn/C.fn-like functions.",
    paste(cand, "A.fn/B.fn/C.fn", collapse = ", ")
  )
}

# ------------------------------------------------------------------------------
# GIG moments for lambda = 1/2 (closed form; no Bessel calls)
# If V ~ GIG(1/2, chi, psi), then
#   E[1/V] = sqrt(psi/chi)
#   E[V]   = sqrt(chi/psi) * (1 + 1/sqrt(chi*psi))
# ------------------------------------------------------------------------------
.gig_half_moments <- function(chi, psi, eps = 1e-12) {
  chi <- pmax(as.numeric(chi), eps)
  psi <- pmax(as.numeric(psi), eps)

  z <- sqrt(chi * psi)
  z <- pmax(z, eps)

  m_inv <- sqrt(psi / chi)
  m     <- sqrt(chi / psi) * (1 + 1 / z)

  list(m = m, m_inv = m_inv, z = z)
}

# ------------------------------------------------------------------------------
# Stable derivative d/dnu log K_nu(z)
# Central difference + Richardson extrapolation.
# Default step is "conventionally small" for special functions (1e-4 scale),
# not machine-epsilon-small.
# ------------------------------------------------------------------------------

.log_besselK <- function(z, nu, z_floor = 1e-300) {
  z <- pmax(as.numeric(z), z_floor)
  val <- besselK(z, nu = nu, expon.scaled = TRUE)
  log(pmax(val, 1e-300)) - z  # log K_nu(z)
}

.dlog_besselK_dnu <- function(z, nu, h = NULL) {
  z  <- pmax(as.numeric(z), 1e-300)
  nu <- as.numeric(nu)[1L]
  if (!is.finite(nu)) .stopf(".dlog_besselK_dnu: nu must be finite.")

  if (is.null(h)) {
    # Good default for order-differentiation. Avoid cancellation.
    h <- 1e-4 * (1 + abs(nu))
    h <- max(h, 1e-6)
  }
  h <- as.numeric(h)[1L]
  if (!is.finite(h) || h <= 0) h <- 1e-4

  # central diff at h
  lp1 <- .log_besselK(z, nu + h)
  lm1 <- .log_besselK(z, nu - h)
  d1  <- (lp1 - lm1) / (2 * h)

  # central diff at h/2
  h2  <- 0.5 * h
  lp2 <- .log_besselK(z, nu + h2)
  lm2 <- .log_besselK(z, nu - h2)
  d2  <- (lp2 - lm2) / (2 * h2)

  # Richardson extrapolation (cancels O(h^2) term)
  d <- d2 + (d2 - d1) / 3

  # fallbacks if something goes non-finite
  bad <- !is.finite(d)
  if (any(bad)) d[bad] <- d2[bad]
  bad <- !is.finite(d)
  if (any(bad)) d[bad] <- d1[bad]

  d
}

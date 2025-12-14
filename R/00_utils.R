.stopf <- function(fmt, ...) stop(sprintf(fmt, ...), call. = FALSE)

`%||%` <- function(x, y) if (!is.null(x)) x else y

assert_scalar_numeric <- function(x, nm) {
  if (!is.numeric(x) || length(x) != 1L || !is.finite(x)) .stopf("%s must be a finite numeric scalar.", nm)
  invisible(TRUE)
}

assert_in <- function(x, set, nm) {
  if (!x %in% set) .stopf("%s must be one of: %s. Got: %s", nm, paste(set, collapse=", "), x)
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

.require_fun <- function(name) {
  if (exists(name, mode = "function", inherits = TRUE)) {
    return(get(name, mode = "function", inherits = TRUE))
  }
  .stopf("Required function '%s' not found. Is the file that defines it loaded/sourced?", name)
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
      if (is.null(b)) return(list(inv = Ainv, chol = L))
      x <- as.numeric(Ainv %*% b)
      return(list(inv = Ainv, chol = L, x = x))
    }
    last_err <- L
  }

  # eigen fallback (clips eigenvalues)
  eg <- eigen(A, symmetric = TRUE)
  vals <- pmax(eg$values, 1e-10)
  Ainv <- eg$vectors %*% (t(eg$vectors) * (1 / vals))
  if (is.null(b)) return(list(inv = Ainv, chol = NULL))
  x <- as.numeric(Ainv %*% b)
  list(inv = Ainv, chol = NULL, x = x, warning = last_err$message %||% "chol failed")
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
# diag(X %*% S %*% t(X)) for dense S without forming n x n
# ------------------------------------------------------------------------------
.diag_XSX <- function(X, S) {
  XS <- X %*% S
  rowSums(XS * X)
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
# Moments of N(mu, var) truncated to (0, Inf)
# Returns E[S], E[S^2], Var[S]
# ------------------------------------------------------------------------------
.truncnorm_pos_moments <- function(mu, var, eps = 1e-12) {
  mu  <- as.numeric(mu)
  var <- pmax(as.numeric(var), eps)
  sd  <- sqrt(var)

  # Z = P(N(mu,sd^2) > 0) = Phi(mu/sd)
  t0   <- mu / sd
  logZ <- pnorm(t0, log.p = TRUE)

  # lambda = phi(a_std)/Z with a_std = (0-mu)/sd = -t0
  log_phi    <- dnorm(-t0, log = TRUE)
  log_lambda <- log_phi - logZ

  # guard exp overflow
  lambda <- exp(pmin(log_lambda, 700))

  m1 <- mu + sd * lambda

  a_std  <- -t0
  var_tr <- var * (1 + a_std * lambda - lambda^2)
  var_tr <- pmax(var_tr, 0)

  m2 <- var_tr + m1^2

  list(m = m1, m2 = m2, var = var_tr)
}

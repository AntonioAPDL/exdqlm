#' Construct beta prior object used by LDVB engine
#' @param type "ridge" or "rhs"
#' @param ridge list(tau2=...)
#' @param rhs list(tau0, nu, s2, init_log_lambda, init_log_tau, init_log_c2,
#'                 rhs_maxit, rhs_reltol)
#' @export

`%||%` <- function(x, alt) if (!is.null(x)) x else alt

#' @keywords internal
.call_with_supported_args <- function(fn, ...) {
  dots <- list(...)
  if (!length(dots)) return(do.call(fn, list()))

  nm <- names(dots)
  if (is.null(nm) || any(nm == "")) {
    # caller used positional args -> don't filter
    return(do.call(fn, dots))
  }

  fmls <- names(formals(fn))
  if (is.null(fmls) || "..." %in% fmls) return(do.call(fn, dots))

  keep <- intersect(nm, fmls)
  do.call(fn, dots[keep])
}

#' Construct beta prior object used by LDVB engine
#' @param type "ridge" or "rhs"
#' @param ridge list(tau2=...)
#' @param rhs list(tau0, nu, s2, init_log_lambda, init_log_tau, init_log_c2,
#'            rhs_maxit, rhs_reltol)
#' @export
beta_prior <- function(type = c("ridge","rhs"), ridge = list(), rhs = list()) {
  type <- tolower(match.arg(type))
  if (type == "ridge") beta_prior_ridge(ridge$tau2 %||% 1e4)
  else beta_prior_rhs(rhs)
}

beta_prior_ridge <- function(tau2) {
  assert_scalar_numeric(tau2, "ridge$tau2")

  list(
    type = "ridge",
    hypers = list(tau2 = tau2),

    init = function(p) list(),

    expected_prec = function(state, p) rep(1 / tau2, p),

    update = function(state, qb) state,

    elbo = function(state, qb) list(elbo = 0)
  )
}

beta_prior_rhs <- function(rhs) {
  tau0 <- rhs$tau0 %||% 1.0
  nu   <- rhs$nu   %||% 4.0
  s2   <- rhs$s2   %||% 1.0

  rhs_maxit  <- rhs$rhs_maxit  %||% 200L
  rhs_reltol <- rhs$rhs_reltol %||% 1e-8

  list(
    type   = "rhs",
    hypers = list(tau0 = tau0, nu = nu, s2 = s2),

    init = function(p) {
      init_log_lambda <- rhs$init_log_lambda %||% 0.0
      init_log_tau    <- rhs$init_log_tau    %||% 0.0
      init_log_c2     <- rhs$init_log_c2     %||% 0.0

      # allow scalar or length-p init for log-lambdas
      init_log_lambda <- as.numeric(init_log_lambda)
      if (length(init_log_lambda) == 1L) init_log_lambda <- rep(init_log_lambda, p)
      if (length(init_log_lambda) != p) {
        .stopf("rhs$init_log_lambda must be scalar or length p=%d (got %d).", p, length(init_log_lambda))
      }

      eta_mu    <- c(init_log_lambda, as.numeric(init_log_tau)[1L], as.numeric(init_log_c2)[1L])
      eta_Sigma <- diag(1e-2, p + 2L)

      st <- list(eta_mu = eta_mu, eta_Sigma = eta_Sigma)

      rhs_compute_V_moments <- .require_fun("rhs_compute_V_moments")
      vb_state <- list(
        beta = list(mu = rep(0, p), Sigma = diag(1, p)),
        rhs  = list(eta_mu = eta_mu, eta_Sigma = eta_Sigma)
      )

      moms <- tryCatch(
        .call_with_supported_args(rhs_compute_V_moments, vb_state = vb_state),
        error = function(e) .stopf("rhs_compute_V_moments() failed during init(): %s", conditionMessage(e))
      )

      st$V_inv <- as.numeric(moms$V_inv)
      st$V     <- moms$V
      st
    },

    expected_prec = function(state, p) {
      if (is.null(state$V_inv) || length(state$V_inv) != p) {
        .stopf("RHS state missing V_inv cache (expected length %d).", p)
      }
      as.numeric(state$V_inv)
    },

    update = function(state, qb) {
      p <- length(qb$m)

      # Build vb_state object (what rhs_* helpers expect)
      vb_state <- list(
        beta = list(mu = as.numeric(qb$m), Sigma = as.matrix(qb$V)),
        rhs  = list(eta_mu = as.numeric(state$eta_mu),
                    eta_Sigma = as.matrix(state$eta_Sigma))
      )

      cfg <- list(vb = list(
        priors = list(beta = list(rhs = list(tau0 = tau0, nu = nu, s2 = s2))),
        rhs_maxit  = rhs_maxit,
        rhs_reltol = rhs_reltol
      ))

      # NOTE: algebra later — but wiring now should be consistent.
      # We pass beta_m2, which is the natural sufficient statistic for RHS updates.
      beta_m2 <- qb$m^2 + diag(qb$V)

      rhs_update_eta <- .require_fun("rhs_update_eta")
      vb_state <- tryCatch(
        .call_with_supported_args(rhs_update_eta, vb_state = vb_state, beta_m2 = beta_m2, config = cfg),
        error = function(e) .stopf("rhs_update_eta() failed. Expected args like (vb_state, beta_m2, config). Error: %s",
                                  conditionMessage(e))
      )

      rhs_compute_V_moments <- .require_fun("rhs_compute_V_moments")
      moms <- tryCatch(
        .call_with_supported_args(rhs_compute_V_moments, vb_state = vb_state),
        error = function(e) .stopf("rhs_compute_V_moments() failed. Error: %s", conditionMessage(e))
      )

      state$eta_mu    <- vb_state$rhs$eta_mu
      state$eta_Sigma <- vb_state$rhs$eta_Sigma
      state$V_inv     <- moms$V_inv
      state$V         <- moms$V
      state
    },

    elbo = function(state, qb) {
      p <- length(qb$m)
      eta_mu <- state$eta_mu
      eta_Sigma <- state$eta_Sigma

      beta_m2 <- qb$m^2 + diag(qb$V)
      hyper <- list(tau0 = tau0, nu = nu, s2 = s2)

      # 0th-order LD: plug in at eta_mu (consistent with your V_inv plug-in)
      rhs_log_kernel_eta <- .require_fun("rhs_log_kernel_eta")
      E_log_joint <- tryCatch(
        .call_with_supported_args(
          rhs_log_kernel_eta,
          eta_mu  = eta_mu,
          eta     = eta_mu,     # supports alternate arg naming
          beta_m2 = beta_m2,
          hyper   = hyper
        ),
        error = function(e) .stopf("rhs_log_kernel_eta() failed: %s", conditionMessage(e))
      )

      # entropy of Gaussian q(eta)
      d <- length(eta_mu)
      logdet <- as.numeric(determinant(eta_Sigma, logarithm = TRUE)$modulus)
      H_qeta <- 0.5 * (d * (1 + log(2*pi)) + logdet)

      list(elbo = E_log_joint + H_qeta)
    }
  )
}

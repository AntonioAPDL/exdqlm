#' Fit exAL readout with LDVB and pluggable beta prior
#'
#' This wrapper is backward compatible with the "list-style" API:
#'   - vb_control = list(max_iter, tol, tol_par, n_samp_xi, verbose)
#'   - prior_gamma = list(mu0, s20)
#'   - prior_sigma = list(a, b)
#'
#' And it also supports the "flat" arguments used by pipeline_sim_main.R:
#'   - max_iter, tol, tol_par, n_samp_xi, verbose
#'   - prior_gamma_mu0, prior_gamma_s20, log_prior_gamma
#'   - a_sigma, b_sigma
#'
#' @export
exal_ldvb_fit <- function(y, X, p0, gamma_bounds,
                          vb_control = NULL,
                          max_iter = NULL, tol = NULL, tol_par = NULL,
                          n_samp_xi = NULL, verbose = NULL,
                          init = list(),
                          prior_gamma = NULL,
                          prior_gamma_mu0 = NULL,
                          prior_gamma_s20 = NULL,
                          log_prior_gamma = NULL,
                          prior_sigma = NULL,
                          a_sigma = NULL,
                          b_sigma = NULL,
                          beta_prior_obj = NULL,
                          ...) {

  assert_matrix(X, "X")
  if (!is.numeric(y) || length(y) != nrow(X)) .stopf("y length must match nrow(X).")
  assert_scalar_numeric(p0, "p0")

  if (!is.numeric(gamma_bounds) || length(gamma_bounds) != 2L) {
    .stopf("gamma_bounds must be a numeric vector of length 2.")
  }
  gamma_bounds <- as.numeric(gamma_bounds)
  if (!all(is.finite(gamma_bounds)) || gamma_bounds[1] >= gamma_bounds[2]) {
    .stopf("gamma_bounds must be finite with lower < upper.")
  }

  if (!is.list(init)) .stopf("init must be a list.")

  # ---- VB control: accept either vb_control list or flat args ---------------
  if (is.null(vb_control)) vb_control <- list()
  if (!is.list(vb_control)) .stopf("vb_control must be a list.")

  if (!is.null(max_iter))  vb_control$max_iter  <- as.integer(max_iter)[1L]
  if (!is.null(tol))       vb_control$tol       <- as.numeric(tol)[1L]
  if (!is.null(tol_par))   vb_control$tol_par   <- as.numeric(tol_par)[1L]
  if (!is.null(n_samp_xi)) vb_control$n_samp_xi <- as.integer(n_samp_xi)[1L]
  if (!is.null(verbose))   vb_control$verbose   <- isTRUE(verbose)

  # sensible defaults if missing
  if (is.null(vb_control$max_iter))  vb_control$max_iter  <- 150L
  if (is.null(vb_control$tol))       vb_control$tol       <- 1e-4
  if (is.null(vb_control$tol_par))   vb_control$tol_par   <- vb_control$tol
  if (is.null(vb_control$n_samp_xi)) vb_control$n_samp_xi <- 500L
  if (is.null(vb_control$verbose))   vb_control$verbose   <- FALSE

  # ---- Priors: accept list-style or flat args ------------------------------
  if (is.null(prior_gamma)) prior_gamma <- list(mu0 = 0, s20 = 10)
  if (!is.list(prior_gamma)) .stopf("prior_gamma must be a list.")
  if (!is.null(prior_gamma_mu0)) prior_gamma$mu0 <- as.numeric(prior_gamma_mu0)[1L]
  if (!is.null(prior_gamma_s20)) prior_gamma$s20 <- as.numeric(prior_gamma_s20)[1L]
  if (!is.null(log_prior_gamma)) prior_gamma$log_prior <- log_prior_gamma
  if (is.null(prior_sigma)) prior_sigma <- list(a = 1, b = 1)
  if (!is.list(prior_sigma)) .stopf("prior_sigma must be a list.")
  if (!is.null(a_sigma)) prior_sigma$a <- as.numeric(a_sigma)[1L]
  if (!is.null(b_sigma)) prior_sigma$b <- as.numeric(b_sigma)[1L]

  # ---- Default beta prior object -------------------------------------------
  if (is.null(beta_prior_obj)) {
    if (exists("beta_prior", mode = "function", inherits = TRUE)) {
      beta_prior_obj <- beta_prior("ridge", ridge = list(tau2 = 1e4))
    } else {
      tau2 <- 1e4
      beta_prior_obj <- list(
        type = "ridge",
        hypers = list(tau2 = tau2),
        init = function(p) list(),
        expected_prec = function(state, p) rep(1 / tau2, p),
        update = function(state, qb) state,
        elbo = function(state, qb) list(elbo = 0)
      )
    }
  }


  # ---- Call engine (only pass args it accepts, unless engine has ...) -------
  eng <- get("exal_ldvb_engine", mode = "function")
  eng_fmls <- names(formals(eng))

  arglist <- list(
    y = y, X = X, p0 = p0, gamma_bounds = gamma_bounds,
    vb_control = vb_control, init = init,
    prior_gamma = prior_gamma, prior_sigma = prior_sigma,
    beta_prior_obj = beta_prior_obj
  )

  if (!is.null(log_prior_gamma)) arglist$log_prior_gamma <- log_prior_gamma

  dots <- list(...)
  if (length(dots)) {
    for (nm in names(dots)) arglist[[nm]] <- dots[[nm]]
  }

  if (!("..." %in% eng_fmls)) {
    arglist <- arglist[names(arglist) %in% eng_fmls]
  }

  do.call(eng, arglist)
}

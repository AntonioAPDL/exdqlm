#' Fit Q-DESN with configurable readout inference
#'
#' This is a light dispatcher that keeps the existing `qdesn_fit_vb()` path
#' intact while adding an MCMC readout alternative that reuses the same
#' reservoir and design construction.
#'
#' @param method One of `"vb"` or `"mcmc"`.
#' @param vb_args,mcmc_args Named lists of inference-specific settings. If
#'   \code{beta_prior_type} is omitted in either list, Q-DESN defaults to
#'   \code{"rhs_ns"}. For RHS-family priors, \code{shrink_intercept} is
#'   enforced as \code{FALSE}.
#' @param ... Additional arguments forwarded to the underlying Q-DESN fitter.
#' @export
qdesn_fit <- function(..., method = c("vb", "mcmc"), vb_args = list(), mcmc_args = list()) {
  method <- match.arg(method)
  if (identical(method, "vb")) {
    return(do.call(qdesn_fit_vb, c(list(vb_args = vb_args), list(...))))
  }
  do.call(qdesn_fit_mcmc, c(list(mcmc_args = mcmc_args), list(...)))
}

#' Fit Q-DESN with an exAL MCMC readout
#'
#' The reservoir and readout design are built by reusing the existing
#' `qdesn_fit_vb(..., fit_readout = FALSE)` path. The readout is then fit with
#' [exal_mcmc_fit()] so the returned object remains compatible with the current
#' `qdesn_fit` forecasting code.
#'
#' @param mcmc_args Named list forwarded to [exal_mcmc_fit()]. If
#'   \code{mcmc_args$beta_prior_type} is omitted, Q-DESN defaults to
#'   \code{"rhs_ns"}.
#' @param fit_readout Logical; if `FALSE`, return the shared design-only object.
#' @param ... Additional arguments forwarded to the Q-DESN design builder.
#' @export
qdesn_fit_mcmc <- function(..., mcmc_args = list(), fit_readout = TRUE) {
  `%||%` <- function(a, b) if (is.null(a)) b else a
  get_exact <- function(x, name, default = NULL) {
    if (!is.list(x)) return(default)
    out <- x[[name, exact = TRUE]]
    if (is.null(out)) default else out
  }

  design_fit <- do.call(qdesn_fit_vb, c(list(fit_readout = FALSE, vb_args = list()), list(...)))
  if (!isTRUE(fit_readout)) {
    return(design_fit)
  }

  p0 <- as.numeric(design_fit$meta$p0 %||% NA_real_)
  if (!is.finite(p0) || length(p0) != 1L) {
    stop("qdesn_fit_mcmc: design object is missing a valid p0.", call. = FALSE)
  }

  beta_prior_obj <- get_exact(mcmc_args, "beta_prior_obj")
  if (is.null(beta_prior_obj)) {
    beta_type <- tolower(as.character(get_exact(mcmc_args, "beta_prior_type", "rhs_ns")))
    rhs_list <- get_exact(mcmc_args, "beta_rhs", list())
    if (beta_type %in% c("rhs", "rhs_ns")) {
      rhs_list <- .qdesn_enforce_rhs_controls(rhs_list, context = "qdesn_fit_mcmc")
    }
    tau2 <- as.numeric(get_exact(mcmc_args, "beta_ridge_tau2", get_exact(mcmc_args, "tau2", 1e4)))
    beta_prior_obj <- exal_make_beta_prior(type = beta_type, tau2 = tau2, rhs = rhs_list)
  } else {
    .qdesn_assert_rhs_prior_obj_intercept_policy(beta_prior_obj, context = "qdesn_fit_mcmc")
  }

  mcmc_control <- modifyList(list(
    n_burn = get_exact(mcmc_args, "n_burn", 2000L),
    n_mcmc = get_exact(mcmc_args, "n_mcmc", 1500L),
    thin = get_exact(mcmc_args, "thin", 1L),
    verbose = isTRUE(get_exact(mcmc_args, "verbose", FALSE)),
    progress_every = get_exact(mcmc_args, "progress_every", 100L),
    init_from_vb = isTRUE(get_exact(mcmc_args, "init_from_vb", FALSE)),
    store_latent_draws = isTRUE(get_exact(mcmc_args, "store_latent_draws", FALSE)),
    store_rhs_draws = isTRUE(get_exact(mcmc_args, "store_rhs_draws", FALSE)),
    slice = get_exact(mcmc_args, "slice", list()),
    conditioning = get_exact(mcmc_args, "conditioning", list())
  ), get_exact(mcmc_args, "mcmc_control", list()))

  fit <- exal_mcmc_fit(
    y = design_fit$y_fit,
    X = design_fit$X,
    p0 = p0,
	    gamma_bounds = get_exact(mcmc_args, "gamma_bounds", c(L.fn(p0), U.fn(p0))),
	    likelihood_family = get_exact(mcmc_args, "likelihood_family", "exal"),
	    al_fixed_gamma = get_exact(mcmc_args, "al_fixed_gamma", NULL),
	    mcmc_control = mcmc_control,
	    init = get_exact(mcmc_args, "init", list()),
	    prior_gamma = get_exact(mcmc_args, "prior_gamma", list(
	      mu0 = get_exact(mcmc_args, "prior_gamma_mu0", 0),
	      s20 = get_exact(mcmc_args, "prior_gamma_s20", 10)
	    )),
	    prior_sigma = get_exact(mcmc_args, "prior_sigma", list(
	      a = get_exact(mcmc_args, "a_sigma", 1),
	      b = get_exact(mcmc_args, "b_sigma", 1)
	    )),
	    log_prior_gamma = get_exact(mcmc_args, "log_prior_gamma"),
	    beta_prior_obj = beta_prior_obj
	  )

  design_fit$fit <- fit
  design_fit$mu_hat <- as.numeric(design_fit$X %*% fit$summary$beta_mean)
  design_fit$meta$inference_method <- "mcmc"
  design_fit
}

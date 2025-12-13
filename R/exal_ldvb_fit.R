#' Fit exAL readout with LDVB and pluggable beta prior
#' @export
exal_ldvb_fit <- function(y, X, p0, gamma_bounds,
                          vb_control,
                          init = list(),
                          prior_gamma = list(mu0 = 0, s20 = 10),
                          prior_sigma = list(a = 1, b = 1),
                          beta_prior_obj = beta_prior("ridge", ridge = list(tau2 = 1e4))) {

  assert_matrix(X, "X")
  if (!is.numeric(y) || length(y) != nrow(X)) .stopf("y length must match nrow(X).")
  assert_scalar_numeric(p0, "p0")
  if (length(gamma_bounds) != 2L) .stopf("gamma_bounds must be length 2.")
  exal_ldvb_engine(
    y = y, X = X, p0 = p0, gamma_bounds = gamma_bounds,
    vb_control = vb_control, init = init,
    prior_gamma = prior_gamma, prior_sigma = prior_sigma,
    beta_prior_obj = beta_prior_obj
  )
}

\name{qdesn_interlayer_residual}
\alias{qdesn_build_paired_architecture_designs}
\alias{qdesn_fit_al_vb_from_design}
\alias{qdesn_forecast_single_origin_al_vb}
\alias{qdesn_architecture_forgetting_diagnostic}
\title{Inter-layer residual Q-DESN utilities}
\description{
Builds paired ordinary and inter-layer residual Q-DESN feature maps from the
same fixed reservoir matrices, fits the existing asymmetric-Laplace
variational readout, and produces a single-origin recursive forecast.
}
\usage{
qdesn_build_paired_architecture_designs(
  y, D = 2L, n = 30L, n_tilde = NULL, m = 12L,
  alpha = 0.3, rho = 0.85, pi_w = 0.1, pi_in = 1,
  washout = 500L, add_bias = TRUE, standardize_inputs = TRUE,
  input_bound = "none", act_f = "tanh", act_k = "identity",
  seed = 123L, skip_scale = 1, ...
)

qdesn_fit_al_vb_from_design(
  design, p0, tau0 = 0.1, standardize_readout = TRUE,
  vb_control = list(), fit_seed = NULL
)

qdesn_forecast_single_origin_al_vb(
  object, y_history, H = 100L, nd = 1000L,
  posterior_seed = NULL, noise_draws = NULL
)

qdesn_architecture_forgetting_diagnostic(design, y)
}
\arguments{
  \item{y}{Finite numeric response history.}
  \item{D}{Number of reservoir layers.}
  \item{n}{Common reservoir width or a length-\code{D} vector.}
  \item{n_tilde}{Reducer widths; defaults to the lower-layer widths.}
  \item{m}{Number of lagged responses entering the reservoir.}
  \item{alpha}{Scalar or layer-specific leak rate.}
  \item{rho}{Scalar or layer-specific spectral radius.}
  \item{pi_w, pi_in}{Fixed recurrent and input sparsity probabilities.}
  \item{washout}{Number of initial states excluded from readout fitting.}
  \item{add_bias}{Whether the readout includes an intercept.}
  \item{standardize_inputs}{Whether lagged reservoir inputs are standardized.}
  \item{input_bound}{Optional lag-input bounding rule.}
  \item{act_f, act_k}{Reservoir and reduced-state activations.}
  \item{seed}{Reservoir seed.}
  \item{skip_scale}{Fixed multiplier on the inter-layer identity skip.}
  \item{...}{Additional arguments passed to \code{qdesn_fit_vb}.}
  \item{design}{Architecture design returned by
  \code{qdesn_build_paired_architecture_designs}.}
  \item{p0}{Target quantile.}
  \item{tau0}{Global RHS-NS half-Cauchy scale; the ablation default is 0.1.}
  \item{standardize_readout}{Whether non-intercept readout columns are
  standardized using fitting rows only.}
  \item{vb_control}{Overrides for the existing variational algorithm.}
  \item{fit_seed}{Seed for stochastic variational components.}
  \item{object}{Fitted AL-VB Q-DESN object.}
  \item{y_history}{Observed response history through the forecast origin.}
  \item{H}{Forecast horizon.}
  \item{nd}{Number of posterior-predictive paths.}
  \item{posterior_seed}{Seed for variational posterior draws.}
  \item{noise_draws}{Optional common-random-number matrices.}
}
\details{
For a deep layer \eqn{d \ge 2}, the residual candidate is
\deqn{f(W_d h_{t-1,d} + W_d^{in} \widetilde h_{t,d-1}) +
P_d \widetilde h_{t,d-1}.}
The plain arm is produced by the existing \code{qdesn_fit_vb} implementation.
The residual arm reuses exactly the same \eqn{W_d}, \eqn{W_d^{in}}, and
reduction matrices. The first layer and readout definition are unchanged.
}
\value{
The paired builder returns ordinary and residual design objects. The fitter
returns a \code{qdesn_fit} object. The forecaster returns predictive paths,
location paths, and the empirical target-quantile path. The forgetting
function returns layerwise final-state discrepancies.
}

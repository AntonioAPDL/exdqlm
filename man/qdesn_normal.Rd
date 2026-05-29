% Generated for the Q-DESN Normal readout implementation.
\name{qdesn_normal}
\alias{normal_desn_fit}
\alias{normal_desn_posterior_draws}
\alias{normal_desn_posterior_predict}
\alias{qdesn_fit_normal}
\alias{predict_mu.qdesn_normal_fit}
\alias{posterior_predict.qdesn_normal_fit}
\alias{forecast_paths.qdesn_normal_fit}
\alias{qdesn_normal_to_vb_init}
\alias{qdesn_normal_to_mcmc_init}
\title{Normal DESN readouts}
\usage{
normal_desn_fit(
  X,
  y,
  beta_prior_type = c("scaled_ridge", "ridge", "rhs", "rhs_ns"),
  prior = list(),
  omega_prior = list(a = 2, b = 1),
  rhs = list(),
  control = list()
)

qdesn_fit_normal(..., p0 = 0.5, normal_args = list(), fit_readout = TRUE)

normal_desn_posterior_draws(fit, nd = 1000L, seed = NULL)

normal_desn_posterior_predict(
  fit,
  X_new = NULL,
  nd = 1000L,
  seed = NULL,
  draws = NULL
)

predict_mu.qdesn_normal_fit(object)

posterior_predict.qdesn_normal_fit(
  object,
  nd = 1000L,
  X_new = NULL,
  seed = NULL,
  draws = NULL
)

forecast_paths.qdesn_normal_fit(
  object,
  H,
  nd = 1000L,
  y_hist = NULL,
  seed = NULL,
  draws = NULL,
  y_future_obs = NULL,
  return_design = FALSE,
  ...
)

qdesn_normal_to_vb_init(
  normal_fit,
  likelihood_family = c("al", "exal"),
  beta_prior_type = c("ridge", "rhs", "rhs_ns"),
  p0 = 0.5,
  eps = 1e-08
)

qdesn_normal_to_mcmc_init(
  normal_fit,
  likelihood_family = c("al", "exal"),
  beta_prior_type = c("ridge", "rhs", "rhs_ns"),
  p0 = 0.5,
  gamma = 0,
  al_fixed_gamma = 0
)
}
\arguments{
\item{X}{Numeric fixed DESN design matrix.}
\item{y}{Numeric response vector aligned with \code{X}.}
\item{beta_prior_type}{Readout prior. Use \code{"scaled_ridge"} for the
exact Normal-inverse-gamma target. \code{"ridge"} is accepted as an alias.
\code{"rhs"} and \code{"rhs_ns"} use an approximate global VB update.}
\item{prior}{Scaled-ridge prior controls. Supported entries include
\code{precision}, \code{mean}, \code{beta_ridge_tau2},
\code{intercept_var}, and \code{intercept_mean}.}
\item{omega_prior}{Inverse-gamma prior controls with positive \code{a} and
\code{b}, using density proportional to \eqn{x^{-a-1}\exp(-b/x)}.}
\item{rhs}{RHS or RHS_NS controls passed to the package beta-prior machinery.}
\item{control}{Readout controls. For \code{"scaled_ridge"}, optional
\code{control$chunking} supports exact sequential row chunking with entries
\code{enabled}, \code{mode = "exact"}, \code{chunk_size}, \code{order =
"sequential"}, and \code{trace}. For RHS-family readouts, \code{control}
contains VB controls and chunking is currently forbidden.}
\item{...}{Arguments forwarded to \code{\link{qdesn_fit_vb}} for DESN feature
construction. The readout fit is suppressed and replaced by the Normal readout.}
\item{p0}{Quantile-level placeholder forwarded to \code{\link{qdesn_fit_vb}}
for DESN construction compatibility. Normal DESN targets the conditional mean
and does not use \code{p0} in the Gaussian readout.}
\item{normal_args}{Named list forwarded to \code{normal_desn_fit}.}
\item{fit_readout}{Logical. If \code{FALSE}, return the design-only object.}
\item{fit, normal_fit}{A \code{normal_desn_readout} or
\code{qdesn_normal_fit} object.}
\item{nd}{Number of posterior draws.}
\item{seed}{Optional RNG seed.}
\item{X_new}{Optional fixed design matrix for posterior prediction.}
\item{draws}{Optional result from \code{normal_desn_posterior_draws}.}
\item{object}{A fitted \code{qdesn_normal_fit}.}
\item{H}{Positive forecast horizon.}
\item{y_hist}{Optional observed history through the forecast origin.}
\item{y_future_obs}{Optional numeric vector of length \code{H}; non-missing
values are treated as observed future values for recursive reservoir inputs.}
\item{return_design}{Logical; if \code{TRUE}, return per-draw forecast design
rows when available.}
\item{likelihood_family}{Target AL/exAL family recorded in initialization
metadata.}
\item{p0}{Target quantile level recorded in initialization metadata.}
\item{eps}{Non-negative covariance jitter for initialization metadata.}
\item{gamma}{Initial gamma for exAL MCMC.}
\item{al_fixed_gamma}{Fixed AL gamma used when \code{likelihood_family = "al"}.}
}
\value{
\code{normal_desn_fit()} returns a \code{normal_desn_readout}. The exact
scaled-ridge path contains closed-form beta and variance posterior summaries,
log marginal likelihood, fitted means, and reproducibility metadata. The
RHS-family path is labeled as approximate VB.

\code{qdesn_fit_normal()} returns a \code{qdesn_normal_fit} object that reuses
the current Q-DESN feature builder and stores the Normal readout separately
from AL/exAL \code{qdesn_fit} objects.
}
\description{
Fit Normal-likelihood DESN readouts. The scaled-ridge prior is exact and uses
the closed-form Normal-inverse-gamma posterior. RHS and RHS_NS variants are
global VB approximations and are not labeled as exact conjugate posteriors.
}
\details{
The exact scaled-ridge target is
\deqn{y \mid \beta,\omega^2,X \sim N(X\beta,\omega^2 I),}
\deqn{\beta \mid \omega^2 \sim N(b,\omega^2 P^{-1}),}
\deqn{\omega^2 \sim IG(a,b).}
With \eqn{P_n=P+X'X}, \eqn{h_n=Pb+X'y}, and
\eqn{m_n=P_n^{-1}h_n}, the posterior inverse-gamma rate is
\eqn{B_n=b+0.5(y'y+b'Pb-m_n'P_nm_n)} and the marginal beta posterior is
Student-\eqn{t}.

The scaled-ridge path may accumulate \eqn{X'X}, \eqn{X'y}, and \eqn{y'y}
in deterministic row chunks through \code{control$chunking}. This preserves
the exact full-data target: chunking changes only how row-additive sufficient
statistics are accumulated, not the posterior equations. Non-exact chunking
and RHS/RHS_NS chunking fail early.

Normal DESN is a conditional-mean model. It is useful as a Gaussian baseline
and as a beta-moment initialization source for AL/exAL Q-DESN fits, but it is
not a quantile likelihood.

\code{forecast_paths.qdesn_normal_fit()} recursively samples Normal
multi-step forecast paths for standard univariate raw-y-lag DESN inputs and
reservoir-only readout designs. Exogenous, decomposition, and richer readout
forecast settings fail early until a separate Normal DESN forecast contract is
implemented for those cases.
}
\seealso{
\code{\link{qdesn_fit_vb}}, \code{\link{qdesn_build_design}},
\code{\link{qdesn_vb_make_warm_start}}
}

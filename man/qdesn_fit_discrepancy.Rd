\name{qdesn_fit_discrepancy}
\alias{qdesn_fit_discrepancy}
\title{Fit a source-indexed Q-DESN discrepancy readout}
\usage{
qdesn_fit_discrepancy(
  z,
  H,
  source,
  p0,
  method = c("mcmc", "vb"),
  likelihood_family = c("al", "exal"),
  beta_prior_type = "rhs_ns",
  source_levels = c("Y", "G"),
  intercept_index = integer(),
  vb_args = list(),
  mcmc_args = list(),
  control = list()
)
}
\arguments{
\item{z}{Numeric stacked response vector.}

\item{H}{Numeric augmented design matrix. For the GloFAS application, rows
have the form \code{[X, 0]} for the reference source and \code{[X, X]} for
the forecast-system source.}

\item{source}{Source labels for rows of \code{z} and \code{H}.}

\item{p0}{Target quantile level in \code{(0, 1)}.}

\item{method}{Inference method. Currently only \code{"mcmc"} is implemented.}

\item{likelihood_family}{Working likelihood family. Currently only
\code{"al"} is implemented.}

\item{beta_prior_type}{Coefficient prior. The default is \code{"rhs_ns"}.
The value \code{"rhs"} is mapped internally to \code{"rhs_ns"}.}

\item{source_levels}{Character vector giving source order.}

\item{intercept_index}{Coefficient indices that receive weak Gaussian
intercept priors under RHS-family shrinkage.}

\item{vb_args, mcmc_args, control}{Named control lists. \code{vb_args} is
reserved for the future VB-LD implementation.}
}
\value{
A \code{qdesn_discrepancy_fit} object containing coefficient draws,
source-specific scale draws, fitted readout summaries, prior state, and basic
MCMC diagnostics.
}
\description{
This fitter is the package-side engine for applications that stack a reference
stream and a forecast-system stream on a fixed Q-DESN design. The first
implemented kernel is an asymmetric-Laplace working likelihood with
source-specific scales and a shared augmented readout. The exAL and VB-LD
variants are intentionally left unimplemented until the AL MCMC path passes
synthetic and application-side validation.
}
\details{
The function expects the caller to construct the fixed augmented design. For
the two-source discrepancy model, reference rows use \code{[X, 0]} and
forecast-system rows use \code{[X, X]}. The coefficient vector is therefore
interpreted as a reference readout followed by a discrepancy readout.
}

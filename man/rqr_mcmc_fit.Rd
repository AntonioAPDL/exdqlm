\name{rqr_mcmc_fit}
\alias{rqr_mcmc_fit}
\alias{print.rqr_mcmc}
\title{Fit fixed-design RQR with Gibbs MCMC}
\usage{
rqr_mcmc_fit(
  y,
  X,
  coverage_level,
  learning_rate = 1,
  beta_prior_obj = NULL,
  mcmc_control = list(),
  init = list(),
  ...
)
}
\arguments{
\item{y}{Response vector.}

\item{X}{Fixed design matrix.}

\item{coverage_level}{Interval coverage level in \code{(0, 1)}.}

\item{learning_rate}{Positive generalized-Bayes learning rate.}

\item{beta_prior_obj}{Beta-prior object. Version 1 supports ridge and
\code{rhs_ns}.}

\item{mcmc_control}{Named list with \code{n_burn}, \code{n_mcmc},
\code{thin}, \code{seed}, \code{verbose}, \code{progress_every},
\code{precision_beta}, and \code{store_latent_draws}.}

\item{init}{Optional initial values for the two root coefficient vectors and
latent scales.}

\item{...}{Reserved for future use.}
}
\value{
An object of class \code{rqr_mcmc}.
}
\description{
Fits the fixed-design RQR generalized posterior with a two-root readout and
latent pseudo-asymmetric-Laplace Gibbs updates. This is an interval readout, not
a data-generating likelihood for the response.
}

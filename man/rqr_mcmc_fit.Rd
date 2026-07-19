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
  loss_reference_scale = 1,
  learning_rate_mode = c("fixed", "learned_scale", "learned_pure"),
  lambda_prior = list(shape = 4, rate = 4),
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

\item{loss_reference_scale}{Positive scale dividing the RQR loss before
applying \code{learning_rate} or learned \code{lambda}. The default \code{1}
reproduces the existing raw-loss target.}

\item{learning_rate_mode}{Learning-rate treatment. \code{"fixed"} preserves
the existing fixed generalized-Bayes target. \code{"learned_scale"} samples the
recommended inverse-loss scale from the generalized posterior proportional to
\code{lambda^T exp(-lambda L_c)}. \code{"learned_pure"} is a diagnostic target
proportional to \code{exp(-lambda L_c)}.}

\item{lambda_prior}{Gamma prior for learned \code{lambda}, as a list with
positive \code{shape} and \code{rate}. The optional \code{power} field defaults
to one for \code{"learned_scale"} and zero for \code{"learned_pure"}.}

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

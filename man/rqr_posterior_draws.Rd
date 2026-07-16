\name{rqr_posterior_draws}
\alias{rqr_posterior_draws}
\alias{rqr_posterior_draws.rqr_mcmc}
\alias{rqr_posterior_draws.rqr_vb}
\alias{rqr_posterior_draws.rqr_desn_fit}
\title{Draw RQR posterior root coefficients}
\usage{
rqr_posterior_draws(object, nd = NULL, seed = NULL, ...)
}
\arguments{
\item{object}{An RQR fit object.}

\item{nd}{Number of draws. \code{NULL} keeps all available draws.}

\item{seed}{Optional RNG seed used when subsampling draws.}

\item{...}{Reserved for method-specific arguments.}
}
\value{
A list with \code{beta_root1}, \code{beta_root2}, and \code{nd}.
}
\description{
Extracts or subsamples posterior draws of the two RQR root coefficient vectors.
}

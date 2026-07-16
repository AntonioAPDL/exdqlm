\name{rqr_vb_fit}
\alias{rqr_vb_fit}
\alias{print.rqr_vb}
\title{Fit fixed-design RQR with a coordinate-Gaussian VB approximation}
\usage{
rqr_vb_fit(
  y,
  X,
  coverage_level,
  learning_rate = 1,
  beta_prior_obj = NULL,
  vb_control = list(),
  init = list(),
  ...
)
}
\arguments{
\item{y}{Response vector.}

\item{X}{Fixed design matrix.}

\item{coverage_level}{Interval coverage level in \code{(0, 1)}.}

\item{learning_rate}{Positive generalized-Bayes learning rate.}

\item{beta_prior_obj}{Beta-prior object. The initial VB backend supports ridge
priors.}

\item{vb_control}{Named list with \code{max_iter}, \code{tol},
\code{verbose}, \code{seed}, \code{n_draws}, and optional ridge scale fields.}

\item{init}{Optional initial values.}

\item{...}{Reserved for future use.}
}
\value{
An object of class \code{rqr_vb}.
}
\description{
Fast coordinate-Gaussian approximation to the RQR generalized posterior. MCMC
remains the reference backend; VB uncertainty is marked as uncalibrated unless
validated separately.
}

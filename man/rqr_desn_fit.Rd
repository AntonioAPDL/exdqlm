\name{rqr_desn_fit}
\alias{rqr_desn_fit}
\alias{print.rqr_desn_fit}
\title{Fit an RQR-DESN interval readout}
\usage{
rqr_desn_fit(
  y,
  coverage_level,
  ...,
  inference = c("mcmc", "vb"),
  learning_rate = 1,
  loss_reference_scale = 1,
  learning_rate_mode = c("fixed", "learned_scale", "learned_pure"),
  lambda_prior = list(shape = 4, rate = 4),
  mcmc_args = list(),
  vb_args = list(),
  fit_readout = TRUE
)
}
\arguments{
\item{y}{Response vector.}

\item{coverage_level}{Interval coverage level in \code{(0, 1)}.}

\item{...}{Arguments forwarded to \code{qdesn_fit_vb()} for deterministic
DESN design construction. \code{p0} and \code{target_p} are rejected because
the RQR interval target is controlled by \code{coverage_level}.}

\item{inference}{Either \code{"mcmc"} or \code{"vb"}.}

\item{learning_rate}{Positive generalized-Bayes learning rate.}

\item{loss_reference_scale}{Positive scale dividing the RQR loss before
applying the learning rate. Passed to \code{rqr_mcmc_fit()}.}

\item{learning_rate_mode}{Learning-rate treatment passed to
\code{rqr_mcmc_fit()}. Learned-scale inference is currently available for
MCMC.}

\item{lambda_prior}{Gamma prior for learned \code{lambda}, passed to
\code{rqr_mcmc_fit()}.}

\item{mcmc_args}{Named list for \code{rqr_mcmc_fit()}.}

\item{vb_args}{Named list for \code{rqr_vb_fit()}.}

\item{fit_readout}{If \code{FALSE}, return the design shell before fitting the
RQR readout.}
}
\value{
An object of class \code{rqr_desn_fit}, or the underlying Q-DESN design shell
when \code{fit_readout = FALSE}.
}
\description{
Builds the deterministic DESN reservoir/design through the existing Q-DESN
design shell and fits a two-root RQR interval readout on that fixed design.
Observation weights are rejected in version 1 because square-root
premultiplication is not valid for the RQR product loss.
\code{rqr_desn_fit()} also rejects \code{p0} and \code{target_p} in \code{...}:
the inherited Q-DESN shell is used only to build the deterministic design, and
the RQR estimand is an interval indexed by \code{coverage_level}.
When \code{fit_readout = TRUE}, an all-zero Q-DESN design shell is rejected
because it would produce a degenerate interval readout.
}

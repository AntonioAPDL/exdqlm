\name{autodesn_rhs_joint_proposal}
\alias{autodesn_rhs_joint_proposal}
\title{Frozen joint architecture and scale proposal for AutoDESN-RHS}
\usage{
autodesn_rhs_joint_proposal(center, scale, df = 5, moves = 1L,
  wide_weight = 0.1, wide_center = c(0, 0, 0),
  wide_scale = diag(c(1.5, 2, 1.5)^2))
}
\arguments{
\item{center}{Finite M by 3 matrix, columns log(variance), log(u), log(c squared).}
\item{scale}{Positive-definite 3 by 3 Student-t scale matrix, or 3 by 3 by M array. This is a shape matrix, not a standard deviation.}
\item{df}{Positive Student-t degrees of freedom.}
\item{moves}{Positive number of additional joint proposals per sweep.}
\item{wide_weight}{Mixture weight in [0,1] for a common broad Student-t.}
\item{wide_center}{Length-three center of the broad component.}
\item{wide_scale}{Positive-definite 3 by 3 shape matrix of the broad component.}
}
\value{A validated proposal for \code{model_control$joint_proposal}. Model probabilities use \code{model_control$proposal}, with positive mass on every architecture.}
\description{This is a Metropolis--Hastings proposal, not a prior. Estimate its parameters with training chains only and freeze it before fresh production chains. Coefficients are integrated out in the joint architecture/scale move and immediately redrawn. Both sampled global and slab scales and method \code{mh} are required. The default NULL joint proposal preserves the historical sampler and random-number stream.}

\examples{
# A deliberately broad fixed proposal for a two-architecture bank:
joint <- autodesn_rhs_joint_proposal(
  center = matrix(0, nrow = 2, ncol = 3), scale = diag(3), moves = 2)
# Supply it to autodesn_fit_bank(..., beta_prior = "rhs",
#   model_control = list(method = "mh", proposal = c(.5, .5),
#                        joint_proposal = joint)).
# In an actual study, fit proposal parameters using training chains, then
# freeze them before fresh production chains and inspect multiple-chain diagnostics.
}

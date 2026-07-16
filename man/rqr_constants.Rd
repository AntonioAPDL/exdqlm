\name{rqr_constants}
\alias{rqr_constants}
\alias{rqr_check_loss}
\alias{rqr_residual_product}
\alias{rqr_pseudo_residual}
\alias{rqr_order_endpoints}
\alias{rqr_gig_params}
\title{Reduced quantile regression interval helpers}
\usage{
rqr_constants(coverage_level, learning_rate = 1)

rqr_check_loss(u, coverage_level)

rqr_residual_product(y, eta1, eta2)

rqr_pseudo_residual(y, eta1, eta2)

rqr_order_endpoints(eta1, eta2)

rqr_gig_params(e, coverage_level, learning_rate = 1)
}
\arguments{
\item{coverage_level}{Interval coverage level in \code{(0, 1)}.}

\item{learning_rate}{Positive generalized-Bayes learning rate.}

\item{u}{Numeric residual product.}

\item{y}{Response vector.}

\item{eta1, eta2}{Numeric root ordinates.}

\item{e}{Residual product.}
}
\value{
\code{rqr_constants()} and \code{rqr_gig_params()} return named lists.
\code{rqr_check_loss()}, \code{rqr_residual_product()}, and
\code{rqr_pseudo_residual()} return numeric vectors. \code{rqr_order_endpoints()}
returns ordered lower and upper endpoint summaries.
}
\description{
Utility functions for the two-root reduced quantile regression (RQR) interval
readout. The residual product is
\code{(y - eta1) * (y - eta2)}, and endpoint summaries are invariant to the
arbitrary labels of the two roots.
}

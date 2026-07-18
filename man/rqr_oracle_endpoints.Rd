\name{rqr_oracle_endpoints}
\alias{rqr_oracle_endpoints}
\title{Location-scale RQR oracle endpoints}
\usage{
rqr_oracle_endpoints(mu, sigma = 1, family, coverage_level, params = list(),
  tol = 1e-08)
}
\arguments{
\item{mu}{Location vector.}

\item{sigma}{Positive scale vector or scalar.}

\item{family}{Innovation family. See \code{\link{rqr_oracle_roots}}.}

\item{coverage_level}{Target interval coverage in \code{(0, 1)}.}

\item{params}{Optional family parameters.}

\item{tol}{Numerical tolerance for the scalar root search.}
}
\value{
A data frame with lower endpoint, upper endpoint, midpoint, width, and the
underlying standardized RQR roots.
}
\description{
Transforms standardized RQR oracle roots to location-scale endpoints for
simulation designs with conditional location \code{mu} and positive scale
\code{sigma}.
}
\seealso{
\code{\link{rqr_oracle_roots}}
}

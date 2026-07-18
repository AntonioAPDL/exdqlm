\name{rqr_oracle_roots}
\alias{rqr_oracle_roots}
\title{RQR oracle roots for centered innovation laws}
\usage{
rqr_oracle_roots(family, coverage_level, params = list(), tol = 1e-08)
}
\arguments{
\item{family}{Innovation family. Supported values are \code{"gaussian"},
\code{"laplace"}, \code{"student_t"}, \code{"centered_gamma"},
\code{"asymmetric_laplace"}, and \code{"gaussian_mixture"}.}

\item{coverage_level}{Target interval coverage in \code{(0, 1)}.}

\item{params}{Optional family parameters.}

\item{tol}{Numerical tolerance for the scalar root search.}
}
\value{
A list with the lower and upper roots, endpoint probabilities, residuals for
the coverage and first-moment balance equations, and family metadata.
}
\description{
The reduced quantile regression (RQR) oracle roots \eqn{(a_c, b_c)} solve
\eqn{F(b_c) - F(a_c) = c} and
\eqn{M(b_c) - M(a_c) = c E(E)}, where
\eqn{M(z) = E\{E 1(E \le z)\}}. The helper is intended for simulation
design and endpoint-recovery audits; it is not a fitted model.
}
\seealso{
\code{\link{rqr_oracle_endpoints}}
}

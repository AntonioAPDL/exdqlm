\name{predict_interval}
\alias{predict_interval}
\alias{predict_interval.rqr_mcmc}
\alias{predict_interval.rqr_vb}
\alias{predict_interval.rqr_desn_fit}
\title{Predict RQR interval endpoints}
\usage{
predict_interval(object, ...)
}
\arguments{
\item{object}{An RQR fit object.}

\item{...}{Method-specific arguments such as \code{X_new}, \code{nd},
\code{draws}, and \code{seed}.}
}
\value{
A list with lower, upper, midpoint, and width draws and posterior summaries.
}
\description{
Predicts interval endpoints from an RQR fit. For \code{rqr_desn_fit} objects an
explicit future design matrix is required; recursive DESN state construction is
handled by \code{forecast_paths.rqr_desn_fit()} under an explicit driver
contract.
}

\name{forecast_paths.rqr_desn_fit}
\alias{forecast_paths.rqr_desn_fit}
\title{Forecast interval paths from an RQR-DESN fit}
\usage{
forecast_paths.rqr_desn_fit(
  object,
  H,
  X_future = NULL,
  history_driver = c("none", "teacher_forced", "companion_fit", "plugin"),
  plugin = NULL,
  nd = NULL,
  seed = NULL,
  ...
)
}
\arguments{
\item{object}{An \code{rqr_desn_fit} object.}

\item{H}{Forecast horizon.}

\item{X_future}{Optional explicit future design matrix with \code{H} rows.}

\item{history_driver}{One of \code{"none"}, \code{"teacher_forced"},
\code{"companion_fit"}, or \code{"plugin"}.}

\item{plugin}{Optional function returning an explicit future design matrix.}

\item{nd}{Number of posterior draws.}

\item{seed}{Optional RNG seed.}

\item{...}{Reserved for plugin or future adapter arguments.}
}
\value{
A list with interval draws and summaries. The field
\code{response_predictive_draws} is \code{FALSE}.
}
\description{
RQR-DESN does not define response predictive draws. This method therefore
requires an explicit future design matrix, or a plugin that returns one, and
refuses silent recursive response sampling.
}

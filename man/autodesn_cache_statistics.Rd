\name{autodesn_cache_statistics}
\alias{autodesn_cache_statistics}
\title{Cache fixed augmented-design sufficient statistics}
\usage{autodesn_cache_statistics(bank, max_bytes = 512 * 1024^2)}
\arguments{
\item{bank}{An augmented AutoDESN bank with frozen training geometry.}
\item{max_bytes}{Bound on cached numeric matrix/vector payload bytes. Small
list/index overhead is additional. Entries are considered in period/model
order; entries exceeding the remaining budget remain uncached.}}
\value{The same bank with a bounded computational statistics cache.}
\description{Precompute unweighted cross-products without retaining additional
design matrices. Every uncached architecture/period remains available and is
computed on demand. Conditional bank identity, priors, likelihood, proposals
and random stream are preserved. Weighted SV cross-products continue to be
recomputed whenever observation variances change.}

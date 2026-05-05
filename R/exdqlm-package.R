#' exdqlm: Extended Dynamic Quantile Linear Models
#'
#' Bayesian quantile-regression tools for dynamic state-space models and static
#' regression under the extended asymmetric Laplace error distribution (exAL).
#'
#' The package centers on native dynamic quantile state-space modeling for
#' univariate time series, while version 0.4.0 also provides a static exAL
#' regression workflow. Across these settings, `exdqlm` combines model
#' construction helpers, multiple Bayesian inference engines, shrinkage priors
#' for static coefficients, and post hoc synthesis of several fitted quantiles.
#'
#' @section Main workflows:
#' \itemize{
#'   \item Dynamic/state-space quantile modeling via
#'         [exdqlmLDVB()] and [exdqlmMCMC()], with legacy [exdqlmISVB()]
#'         retained for backward compatibility and transfer-function extensions
#'         through [exdqlmTransferLDVB()], [exdqlmTransferMCMC()], and legacy
#'         [exdqlmTransferISVB()].
#'   \item Static Bayesian exAL regression via [exalStaticLDVB()] and
#'         [exalStaticMCMC()].
#'   \item Modular state-space construction via [polytrendMod()], [seasMod()],
#'         and [regMod()].
#'   \item Multi-quantile post-processing via
#'         [quantileSynthesis()] for post hoc posterior-predictive
#'         synthesis from separately fitted quantiles into a unified
#'         predictive distribution.
#' }
#'
#' @section Distinctive features in 0.4.0:
#' \itemize{
#'   \item Dynamic Bayesian quantile state-space inference with LDVB as the
#'         main VB engine, MCMC for posterior simulation, and legacy ISVB
#'         retained for compatibility and historical comparisons.
#'   \item A unified package covering both dynamic exDQLM models and static
#'         exAL regression.
#'   \item Static shrinkage priors including ridge, regularized horseshoe
#'         (`"rhs"`), and `rhs_ns`.
#'   \item Reduced AL/DQLM paths through `dqlm.ind = TRUE` in both dynamic and
#'         static APIs.
#'   \item Standardized VB diagnostics traces via
#'         `fit$diagnostics$vb_trace` for ELBO, `sigma`, `gamma`, and
#'         convergence deltas across VB engines.
#'   \item Conservative automatic warmup defaults for the most failure-prone
#'         shared blocks: RHS-family `tau` scheduling plus exAL
#'         `(sigma, gamma)` warmup in VB and MCMC entry points, with explicit
#'         controls available only when users need to override the defaults.
#'   \item Optional C++ acceleration for selected state-space computations.
#' }
#'
#' @section Development changes in 0.5.0:
#' \itemize{
#'   \item Dynamic diagnostics report CRPS through a finite integrated
#'         quantile-score approximation over posterior predictive empirical
#'         quantiles, with user-configurable quantile levels and weights in
#'         [exdqlmDiagnostics()].
#' }
#'
#' @section Runtime options:
#' \itemize{
#'   \item `options(exdqlm.use_cpp_kf = TRUE|FALSE)` – C++ Kalman bridge (optional; default TRUE).
#'   \item `options(exdqlm.compute_elbo = TRUE|FALSE)` – Compute ELBO (optional; default TRUE).
#'   \item `options(exdqlm.tol_elbo = numeric)` – Positive ELBO convergence tolerance used when
#'         `exdqlm.compute_elbo = TRUE`; smaller values enforce stricter ELBO stabilization checks
#'         (default `1e-6`).
#'   \item `options(exdqlm.use_cpp_builders = TRUE|FALSE)` – C++ model builders (optional; default FALSE).
#'   \item `options(exdqlm.use_cpp_samplers = TRUE|FALSE)` – C++ samplers (optional; default FALSE).
#'   \item `options(exdqlm.use_cpp_postpred = TRUE|FALSE)` – C++ posterior predictive sampler (optional; default FALSE).
#'   \item `options(exdqlm.use_cpp_mcmc = TRUE|FALSE)` – MCMC backend routing (optional; default TRUE).
#'   \item `options(exdqlm.cpp_mcmc_mode = "strict"|"fast")` – strict keeps legacy R-kernel parity; fast enables C++ FFBS in MCMC (default "fast").
#'   \item `options(exdqlm.cpp_threads = numeric)` – Positive integer thread cap for eligible
#'         OpenMP-enabled C++ paths (`1L` forces single-thread; default `1L`).
#' }
#'
#' @useDynLib exdqlm, .registration = TRUE
#' @import Rcpp
#' @docType package
#' @name exdqlm-package
#' @keywords package
"_PACKAGE"

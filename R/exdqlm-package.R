#' exdqlm: Extended Dynamic Quantile Linear Models
#'
#' Routines for Bayesian estimation and analysis of dynamic quantile linear models
#' using the extended asymmetric Laplace error distribution (exDQLM).
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
#' @import data.table
#' @import Rcpp
#' @docType package
#' @name exdqlm-package
#' @keywords package
"_PACKAGE"

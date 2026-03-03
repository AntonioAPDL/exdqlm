#' exdqlm: Extended Dynamic Quantile Linear Models
#'
#' Routines for Bayesian estimation and analysis of dynamic quantile linear models
#' using the extended asymmetric Laplace error distribution (exDQLM).
#'
#' @section Runtime options:
#' \itemize{
#'   \item `options(exdqlm.use_cpp_kf = TRUE|FALSE)` – C++ Kalman bridge (optional; default TRUE).
#'   \item `options(exdqlm.use_cpp_samplers = TRUE|FALSE)` – C++ samplers (optional; default FALSE).
#'   \item `options(exdqlm.use_cpp_mcmc = TRUE|FALSE)` – MCMC backend routing (optional; default FALSE).
#'   \item `options(exdqlm.cpp_mcmc_mode = "strict"|"fast")` – strict keeps legacy R-kernel parity; fast enables C++ FFBS in MCMC.
#' }
#'
#' @useDynLib exdqlm, .registration = TRUE
#' @import Rcpp
#' @docType package
#' @name exdqlm-package
#' @keywords package
"_PACKAGE"

# R/zzz.R
.onLoad <- function(libname, pkgname) {
  op <- options()
  op.exdqlm <- list(
    exdqlm.use_cpp_kf        = TRUE,   # KF bridge is proven & fast
    exdqlm.compute_elbo      = TRUE,
    exdqlm.tol_elbo          = 1e-6,
    exdqlm.use_cpp_builders  = FALSE,  # keep OFF until parity is verified
    exdqlm.use_cpp_samplers  = FALSE,  # keep OFF by default (OpenMP/RNG)
    exdqlm.use_cpp_postpred  = FALSE,  # keep OFF by default
    exdqlm.use_cpp_mcmc      = FALSE,  # MCMC C++ backend (opt-in)
    exdqlm.cpp_mcmc_mode     = "strict", # strict=R legacy parity; fast=C++ FFBS
    exdqlm.cpp_threads       = 1L
  )
  toset <- !(names(op.exdqlm) %in% names(op))
  if (any(toset)) options(op.exdqlm[toset])
  invisible()
}

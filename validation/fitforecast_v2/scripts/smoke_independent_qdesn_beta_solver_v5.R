#!/usr/bin/env Rscript
args <- commandArgs(TRUE)
repo <- normalizePath(args[1]); out <- args[2]
setwd(repo)
Sys.setenv(OMP_NUM_THREADS = "1", OPENBLAS_NUM_THREADS = "1", MKL_NUM_THREADS = "1")
pkgload::load_all(repo, quiet = TRUE, compile = FALSE)
source("validation/fitforecast_v2/R/independent_qdesn_beta_solver_v5.R")
iqbs_v5_source(repo)
x <- seq(-1, 1, length.out = 30L)
X <- cbind(1, x, x + .01 * cos(seq_along(x)))
y <- .1 + .4 * x + .03 * sin(seq_along(x))
source_rows <- data.frame(t = seq_along(x), y = y, q_target = .1 + .4 * x)
transport <- list(forward = identity, inverse = identity, center = 0, scale = 1)
records <- list()
for (family in c("al", "exal")) for (mode in c("diagonal", "full")) {
  set.seed(9101)
  prior <- exdqlm:::exal_make_beta_prior(type = "rhs_ns",
    rhs = list(tau0 = .01, s2 = 1, shrink_intercept = FALSE, n_inner = 2L))
  fit <- exdqlm:::exal_fit(y = y, X = X, p0 = .5,
    gamma_bounds = c(-.5, .5), method = "vb", likelihood_family = family,
    al_fixed_gamma = 0, beta_prior_obj = prior,
    vb_control = list(max_iter = 3L, min_iter_elbo = 3L, tol = 0, tol_par = 0,
      n_samp_xi = 16L, verbose = FALSE,
      sigmagam = exdqlm::exal_make_vb_sigmagam_control(),
      beta_covariance = list(approximation = mode)),
    prior_sigma = list(a = 1, b = 1), prior_gamma = list(mu0 = 0, s20 = 10))
  draws <- exdqlm::exal_posterior_draws(fit, nd = 8L, seed = 9002L)
  cfg <- list(job_id = paste("smoke", family, mode, sep = "__"),
    run_root = out, beta_covariance_approximation = mode,
    baseline_config_sha256 = "synthetic_smoke_not_scientific_result", probability = .5)
  paths <- iqbs_v5_capture_fit(cfg, list(X = X, fit = fit), draws,
    source_rows, rep(TRUE, length(x)), transport)
  stopifnot(all(file.exists(paths)))
  summary <- iqfr_v2_read_json(paths[["solver_diagnostics"]])
  stopifnot(is.finite(summary$fit_point_rmse), summary$full_frozen_moment_residual < 1e-6)
  records[[length(records) + 1L]] <- data.frame(family = family, mode = mode,
    artifacts = length(paths), full_solve_residual = summary$full_frozen_moment_residual,
    diagnostic_hook_pass = TRUE)
}
result <- do.call(rbind, records)
iqfr_v2_write_csv(result, file.path(out, "smoke_summary.csv"))
print(result)

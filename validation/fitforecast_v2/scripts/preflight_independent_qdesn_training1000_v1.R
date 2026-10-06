args <- commandArgs(trailingOnly = TRUE)
repo <- normalizePath(args[1], mustWork = TRUE); output <- args[2]
source(file.path(repo, "validation/fitforecast_v2/R/independent_qdesn_training1000_runtime_v1.R"))
source(file.path(repo, "validation/fitforecast_v2/R/independent_qdesn_training1000_campaign_v1.R"))
e <- iqt12_runtime(repo, file.path(repo, "validation/fitforecast_v2/local_trackers/training1000_exdqlm112_runtime/Rlib"))
checks <- list(); add <- function(name, value, detail = "") {
  checks[[length(checks) + 1L]] <<- data.frame(check = name, pass = isTRUE(value), detail = detail)
}
add("official_CRAN_112", packageVersion("exdqlm") == "1.1.2" &&
  packageDescription("exdqlm")$Repository == "CRAN")
add("official_MCMC_default", eval(formals(exdqlm::exdqlmMCMC)$mh.proposal)[1] == "collapsed_slice")
add("official_static_default", eval(formals(exdqlm::exalStaticMCMC)$mh.proposal)[1] == "collapsed_slice")
control <- e$exal_make_vb_sigmagam_control()
add("structured_sigmagam_default", control$factorization == "structured")
add("151_grid", control$structured_grid_size == 151L)
add("private_QDESN_not_CRAN_override", identical(environment(e$qdesn_fit_vb), e) &&
  identical(environment(exdqlm::exdqlmMCMC), asNamespace("exdqlm")))
set.seed(11); X <- matrix(rnorm(400), 100, 4)
P <- crossprod(X) * 1e7 + diag(c(2500, 1e5, 1e6, 1e8)); h <- c(2e7, 1e8, -2e8, 4e7)
s <- iqt12_solve(P, h)
add("nominal_SPD_no_jitter", s$jitter_eps == 0 && s$nominal_residual < 1e-6)
add("precision_covariance_consistency", max(abs(P %*% s$inv - diag(4))) < 1e-6)
add("non_SPD_fails_explicitly", inherits(try(iqt12_solve(diag(c(-1, 1))), silent = TRUE), "try-error"))
add("normal_screen_non_SPD_fails_explicitly",
  inherits(try(e$.normal_desn_sym_solve(diag(c(-1, 1))), silent = TRUE), "try-error"))
for (fold in c("A", "B", "final")) for (N in c(500L, 1000L)) {
  w <- iqt12_window(fold, N)
  add(paste("window", fold, N), length(w$train) == N && length(w$washout) == 500L &&
    length(w$buffer) == 390L && max(w$washout) < min(w$train))
  add(paste("pairs", fold, N), nrow(iqt12_grid(w)) == if (fold == "final") 1000L else 1350L)
}
source_root <- "/data/jaguir26/local/src/shared_dynamic_fit_forecast_validation/sources/dlm_constV_p90_m0amp_highnoise_steepertrend_v2_TTmain10000_fitforecast"
series <- read.csv(file.path(source_root, "normal/tau_0p50/series_wide.csv"))
candidate <- list(n = "12;8", D = 2L, m = 30L, alpha = .7, rho = .9,
  input_gain = .3, center_scale = "mean_sd", input_bound = "none",
  recurrent_indegree = 8L, input_fanin = 10L, interlayer_fanin = 8L,
  matrix_seed = 920001L, tau_source = .3, slab_source = 400,
  sigma_b_source = 20, omega_b_source = 400)
cfg <- list(window = iqt12_window("A", 1000L), candidate = candidate, p = .5,
  likelihood = "al", seed = 441L, normal_iter = 40L, vb_iter = 40L,
  engine = "vb", outer = 4L, inner = 4L, burn = 20L, retained = 40L)
cfg$window$origins <- c(8500L, 8505L); cfg$window$horizon <- 2L
cx <- iqt12_design(e, cfg, series, 8507L)
add("identity_Q_readout", all(cx$object$reservoir$Q_is_identity) && ncol(cx$object$X) == 21L)
add("1000_likelihood_not_washout", nrow(cx$object$X) == 1000L)
for (widths in list(c(6, 5, 4), c(6, 5, 4, 3))) {
  deep <- cfg; deep$candidate$n <- paste(widths, collapse = ";")
  deep$candidate$recurrent_indegree <- 2L; deep$candidate$interlayer_fanin <- 2L
  z <- iqt12_design(e, deep, series)
  add(paste0("depth", length(widths), "_shared_fanin_identity_Q"),
    all(z$object$reservoir$Q_is_identity) && ncol(z$object$X) == sum(widths) + 1L)
}
other <- series; other$y[8501:10000] <- other$y[8501:10000] + 1e5
changed <- iqt12_design(e, cfg, other, 8507L)
add("future_mutation_does_not_change_fit_basis", max(abs(cx$object$X - changed$object$X)) < 1e-12)
later <- 8506L - cx$first + 1L
add("later_teacher_forced_state_changes", max(abs(cx$all_X[later, ] - changed$all_X[later, ])) > 0)
normal <- iqt12_normal(e, cx, cfg)
draws <- e$normal_desn_posterior_draws(normal, 4L, seed = 4L)
add("normal_RHS_smoke", all(is.finite(draws$beta)))
share <- TRUE; all_errors <- list()
for (family in c("normal", "laplace", "gausmix")) {
  shifts <- list()
  for (p in c(.05, .25, .5)) {
    s <- read.csv(file.path(source_root, sprintf("%s/tau_0p%02d/series_wide.csv", family, round(p * 100))))
    cc <- cfg; cc$p <- p
    z <- iqt12_design(e, cc, s, 8507L); f <- iqt12_normal(e, z, cc)
    shifts[[as.character(p)]] <- list(X = z$object$X, beta = f$fit$beta$mean,
      scale = z$scale, y = s$y, fitted = z$object$X %*% f$fit$beta$mean * z$scale)
  }
  errors <- vapply(shifts, function(z) max(abs(z$fitted - shifts[["0.5"]]$fitted -
    (z$y[7501:8500] - shifts[["0.5"]]$y[7501:8500]))), 0.0)
  good <- all(errors <= 1e-6) && all(vapply(shifts,
    function(z) max(abs(z$X - shifts[["0.5"]]$X)) < 1e-6, TRUE))
  share <- share && good; all_errors[[family]] <- errors
  add(paste(family, "normal_affine_sharing_within_tolerance"), good, paste(errors, collapse = ";"))
}
for (likelihood in c("al", "exal")) {
  cc <- cfg; cc$p <- .25; cc$likelihood <- likelihood
  fit <- iqt12_quantile(e, cx, cc)
  d <- iqt12_draws(e, fit, 4L, seed = 13L)
  if (likelihood == "exal") add("structured_VB_actual_draw_sampler",
    d$sigmagam_draw_contract == "structured_gamma_grid_conditional_GIG_sigma" &&
      all(d$gamma %in% fit$qsiggam$structured$grid$gamma))
  add(paste(likelihood, "VB_full_covariance"), all(is.finite(d$beta)))
  fc <- iqt12_qforecast(e, cx, cc, fit, d)
  add(paste(likelihood, "recursive_causal_H1"), all(is.finite(fc$primary)))
  cc$engine <- "mcmc"; m <- iqt12_quantile(e, cx, cc)
  add(paste(likelihood, "MCMC_kernel"), m$diagnostics$core_update_mode ==
    if (likelihood == "exal") "m0_v_collapsed_support_logit" else "sigma_then_gamma")
}
dir.create(output, recursive = TRUE, showWarnings = FALSE)
for (threads in c(1L, 4L)) {
  path <- file.path(output, paste0("official_rng_threads", threads, ".json"))
  old <- Sys.getenv("OMP_NUM_THREADS"); Sys.setenv(OMP_NUM_THREADS = threads)
  status <- system2(file.path(R.home("bin"), "Rscript"), c(
    file.path(repo, "validation/fitforecast_v2/scripts/smoke_independent_qdesn_training1000_rng_v1.R"), repo, path),
    stdout = file.path(output, paste0("official_rng_threads", threads, ".log")),
    stderr = file.path(output, paste0("official_rng_threads", threads, ".log")))
  Sys.setenv(OMP_NUM_THREADS = old)
  add(paste("official_four_model_contract_threads", threads), status == 0L)
}
paths <- file.path(output, paste0("official_rng_threads", c(1, 4), ".json"))
add("official_serial_RNG_thread_independent", all(file.exists(paths)) &&
  iqt12_read(paths[1])$hash == iqt12_read(paths[2])$hash)
# Each draw has its own loss; intervals are not losses of the posterior mean path.
w <- iqt12_window("A", 500L); w$origins <- 8500L; w$horizon <- 2L
q <- matrix(c(0, 2, 2, 0), 2, 2); f <- matrix(0, 500, 2)
s <- series; s$q_target[w$train] <- 0; s$q_target[8501:8502] <- 1
z <- iqt12_scores(f, q, s, w, .5)
add("mean_draw_loss_not_loss_mean_path", all(z$draws$forecast_mae == 1) &&
  mean(abs(rowMeans(q) - 1)) == 0)
checks <- do.call(rbind, checks)
dir.create(output, recursive = TRUE, showWarnings = FALSE)
iqt12_csv(checks, file.path(output, "checks.csv"))
iqt12_json(list(pass = all(checks$pass), checks = nrow(checks),
  normal_affine_share_pass = share, affine_errors = all_errors,
  session = capture.output(sessionInfo()), normal_shared_tested_family = c("normal", "laplace", "gausmix"),
  cross_family_sharing = FALSE), file.path(output, "preflight.json"))
stopifnot(all(checks$pass))
print(checks, row.names = FALSE)

#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(devtools)
})

Sys.setenv(
  OMP_NUM_THREADS = "1",
  OPENBLAS_NUM_THREADS = "1",
  MKL_NUM_THREADS = "1",
  VECLIB_MAXIMUM_THREADS = "1",
  NUMEXPR_NUM_THREADS = "1"
)

devtools::load_all(".", quiet = TRUE)

out_root <- file.path(
  "results", "sim_suite_static", "audits", "static_exal_shared_issue_u1_u4_20260306"
)
out_plots <- file.path(out_root, "plots")
dir.create(out_plots, recursive = TRUE, showWarnings = FALSE)

safe_num <- function(x, default = NA_real_) {
  v <- suppressWarnings(as.numeric(x)[1])
  if (!is.finite(v) || is.na(v)) default else v
}

tau_lab <- function(tau) gsub("\\.", "p", format(as.numeric(tau), nsmall = 2))

trim_gamma_grid <- function(tau, n = 401L, frac = 0.02) {
  b <- .gamma_bounds(tau)
  L <- as.numeric(b[[1]])
  U <- as.numeric(b[[2]])
  eps <- frac * (U - L)
  seq(L + eps, U - eps, length.out = n)
}

valid_gamma_grid <- function(tau) {
  b <- .gamma_bounds(tau)
  L <- as.numeric(b[[1]])
  U <- as.numeric(b[[2]])
  raw <- c(0, 0.1 * U, 0.2 * U, 0.1 * L, 0.2 * L)
  raw[raw > L & raw < U]
}

al_A <- function(tau) (1 - 2 * tau) / (tau * (1 - tau))
al_B <- function(tau) 2 / (tau * (1 - tau))
lam_of <- function(tau, gamma) C.fn(tau, gamma) * abs(gamma)

u1_reduction_rows <- list()
u1_quantile_rows <- list()
k <- 1L
l <- 1L
for (tau in c(0.05, 0.50, 0.95)) {
  reduction_row <- data.frame(
    tau = tau,
    p_at_gamma0 = p.fn(tau, 0),
    p_err_gamma0 = p.fn(tau, 0) - tau,
    A_at_gamma0 = A.fn(tau, 0),
    A_al = al_A(tau),
    A_err_gamma0 = A.fn(tau, 0) - al_A(tau),
    B_at_gamma0 = B.fn(tau, 0),
    B_al = al_B(tau),
    B_err_gamma0 = B.fn(tau, 0) - al_B(tau),
    lambda_at_gamma0 = lam_of(tau, 0),
    stringsAsFactors = FALSE
  )
  u1_reduction_rows[[k]] <- reduction_row
  k <- k + 1L

  for (gamma in valid_gamma_grid(tau)) {
    for (mu in c(-2, 0.5, 3)) {
      for (sigma in c(0.5, 1.5)) {
        q_at_tau <- suppressWarnings(qexal(tau, p0 = tau, mu = mu, sigma = sigma, gamma = gamma))
        p_at_mu <- suppressWarnings(pexal(mu, p0 = tau, mu = mu, sigma = sigma, gamma = gamma))
        u1_quantile_rows[[l]] <- data.frame(
          tau = tau,
          gamma = gamma,
          mu = mu,
          sigma = sigma,
          q_tau_minus_mu = q_at_tau - mu,
          p_mu_minus_tau = p_at_mu - tau,
          stringsAsFactors = FALSE
        )
        l <- l + 1L
      }
    }
  }
}
u1_reduction_df <- do.call(rbind, u1_reduction_rows)
u1_quantile_df <- do.call(rbind, u1_quantile_rows)
utils::write.csv(u1_reduction_df, file.path(out_root, "u1_reduction_identity_checks.csv"), row.names = FALSE)
utils::write.csv(u1_quantile_df, file.path(out_root, "u1_quantile_fixed_checks.csv"), row.names = FALSE)

rich_run <- file.path("results", "sim_suite_static", "static_vb_then_mcmc_tt5000_vbns1000_burn2000_n1000_20260305_160734")
het_run <- file.path(
  "results", "function_testing_20260306_static_heteroskedastic_skewnormal",
  "static_vb_then_mcmc_tt5000_vbns1000_burn2000_n1000_20260305_200656_het_skewnormal_sub5000"
)

load_run_case <- function(run_root, tau) {
  cfg <- readRDS(file.path(run_root, "tables", "run_config.rds"))
  sim <- readRDS(cfg$sim_path)
  TT <- if (!is.null(cfg$TT)) as.integer(cfg$TT) else nrow(sim$extras$X)
  X <- as.matrix(sim$extras$X[seq_len(TT), , drop = FALSE])
  y <- as.numeric(sim$y[seq_len(TT)])
  tau_str <- tau_lab(tau)
  list(
    run_root = run_root,
    tau = tau,
    X = X,
    y = y,
    vb = readRDS(file.path(run_root, "fits", "vb", sprintf("vb_exal_tau_%s_fit.rds", tau_str))),
    mcmc = readRDS(file.path(run_root, "fits", "mcmc", sprintf("mcmc_exal_tau_%s_fit.rds", tau_str)))
  )
}

cases <- list(
  rich_005 = load_run_case(rich_run, 0.05),
  rich_095 = load_run_case(rich_run, 0.95),
  het_005 = load_run_case(het_run, 0.05),
  het_095 = load_run_case(het_run, 0.95)
)

u2_rows <- list()
k <- 1L
for (nm in names(cases)) {
  case <- cases[[nm]]
  X <- case$X
  vb_fit <- case$vb$fit
  mc_fit <- case$mcmc$fit

  vb_path <- exdqlm:::.static_quantile_path_from_fit(vb_fit, X, algorithm = "vb")
  mc_path <- exdqlm:::.static_quantile_path_from_fit(mc_fit, X, algorithm = "mcmc")

  vb_mu <- as.numeric(X %*% vb_fit$qbeta$m)
  vb_direct <- vapply(
    vb_mu,
    function(mu_i) qexal(
      case$tau,
      p0 = case$tau,
      mu = mu_i,
      sigma = as.numeric(vb_fit$qsiggam$sigma_mean)[1],
      gamma = as.numeric(vb_fit$qsiggam$gamma_mean)[1]
    ),
    numeric(1)
  )

  mc_beta <- colMeans(as.matrix(mc_fit$samp.beta))
  mc_mu <- as.numeric(X %*% mc_beta)
  mc_direct <- vapply(
    mc_mu,
    function(mu_i) qexal(
      case$tau,
      p0 = case$tau,
      mu = mu_i,
      sigma = mean(as.numeric(mc_fit$samp.sigma)),
      gamma = mean(as.numeric(mc_fit$samp.gamma))
    ),
    numeric(1)
  )

  u2_rows[[k]] <- data.frame(
    dataset = nm,
    tau = case$tau,
    method = "vb",
    max_abs_diff = max(abs(vb_path$mean - vb_direct), na.rm = TRUE),
    mean_abs_diff = mean(abs(vb_path$mean - vb_direct), na.rm = TRUE),
    stringsAsFactors = FALSE
  )
  k <- k + 1L
  u2_rows[[k]] <- data.frame(
    dataset = nm,
    tau = case$tau,
    method = "mcmc",
    max_abs_diff = max(abs(mc_path$mean - mc_direct), na.rm = TRUE),
    mean_abs_diff = mean(abs(mc_path$mean - mc_direct), na.rm = TRUE),
    stringsAsFactors = FALSE
  )
  k <- k + 1L
}
u2_df <- do.call(rbind, u2_rows)
utils::write.csv(u2_df, file.path(out_root, "u2_quantile_path_mapping_checks.csv"), row.names = FALSE)

logpost_gamma_direct <- function(gamma, y, X, beta, sigma, v, s_vec, tau, log_prior_gamma = function(g) 0) {
  if (!is.finite(gamma) || gamma <= .gamma_bounds(tau)[1] || gamma >= .gamma_bounds(tau)[2]) return(-Inf)
  A <- A.fn(tau, gamma)
  B <- B.fn(tau, gamma)
  lam <- C.fn(tau, gamma) * abs(gamma)
  if (!is.finite(A) || !is.finite(B) || B <= 0 || !is.finite(lam) || sigma <= 0 || any(v <= 0)) return(-Inf)
  mu <- as.numeric(X %*% beta) + lam * sigma * s_vec + A * v
  res <- y - mu
  quad <- sum((res * res) / (B * sigma * v))
  if (!is.finite(quad)) return(-Inf)
  -(length(y) / 2) * log(B) - 0.5 * quad + log_prior_gamma(gamma)
}

fd_deriv <- function(fn, x, h) {
  (fn(x + h) - fn(x - h)) / (2 * h)
}

u3_rows <- list()
k <- 1L
for (nm in names(cases)) {
  case <- cases[[nm]]
  fit <- case$mcmc$fit
  beta_mean <- colMeans(as.matrix(fit$samp.beta))
  sigma_mean <- mean(as.numeric(fit$samp.sigma))
  gamma_mean <- mean(as.numeric(fit$samp.gamma))
  gamma_sd <- stats::sd(as.numeric(fit$samp.gamma))
  v_mean <- colMeans(as.matrix(fit$samp.v))
  s_mean <- colMeans(as.matrix(fit$samp.s))
  grid <- trim_gamma_grid(case$tau, n = 401L, frac = 0.02)
  lp <- vapply(grid, function(g) logpost_gamma_direct(g, case$y, case$X, beta_mean, sigma_mean, v_mean, s_mean, case$tau), numeric(1))
  mode_idx <- which.max(lp)
  gamma_mode <- grid[mode_idx]
  lp_mode <- lp[mode_idx]
  lp_zero <- logpost_gamma_direct(0, case$y, case$X, beta_mean, sigma_mean, v_mean, s_mean, case$tau)
  rel_support <- (gamma_mode - .gamma_bounds(case$tau)[1]) / diff(.gamma_bounds(case$tau))
  h <- 1e-4 * diff(.gamma_bounds(case$tau))
  deriv_A <- fd_deriv(function(g) A.fn(case$tau, g), gamma_mean, h)
  deriv_B <- fd_deriv(function(g) B.fn(case$tau, g), gamma_mean, h)
  deriv_C <- fd_deriv(function(g) C.fn(case$tau, g), gamma_mean, h)
  deriv_lambda <- fd_deriv(function(g) C.fn(case$tau, g) * abs(g), gamma_mean, h)
  u3_rows[[k]] <- data.frame(
    dataset = nm,
    tau = case$tau,
    gamma_mean = gamma_mean,
    gamma_sd = gamma_sd,
    gamma_mode_cond = gamma_mode,
    log_kernel_gap_mode_vs_zero = lp_mode - lp_zero,
    abs_mode_minus_zero = abs(gamma_mode),
    rel_support_position_mode = rel_support,
    A_at_zero = A.fn(case$tau, 0),
    A_at_mode = A.fn(case$tau, gamma_mode),
    B_at_zero = B.fn(case$tau, 0),
    B_at_mode = B.fn(case$tau, gamma_mode),
    lambda_at_zero = lam_of(case$tau, 0),
    lambda_at_mode = lam_of(case$tau, gamma_mode),
    dA_dgamma_at_mean = deriv_A,
    dB_dgamma_at_mean = deriv_B,
    dC_dgamma_at_mean = deriv_C,
    dlambda_dgamma_at_mean = deriv_lambda,
    stringsAsFactors = FALSE
  )
  k <- k + 1L

  png(file.path(out_plots, sprintf("u3_gamma_profile_%s_tau_%s.png", nm, tau_lab(case$tau))), width = 1200, height = 800)
  plot(grid, lp - max(lp), type = "l", lwd = 3, col = "#1f4e79",
       main = sprintf("exAL gamma conditional profile: %s tau=%.2f", nm, case$tau),
       xlab = expression(gamma), ylab = "centered log-kernel")
  abline(v = 0, col = "#2c7a7b", lty = 2, lwd = 2)
  abline(v = gamma_mean, col = "#b7791f", lty = 3, lwd = 2)
  abline(v = gamma_mode, col = "#c53030", lty = 1, lwd = 2)
  legend("topright", bty = "n", lwd = 2,
         col = c("#2c7a7b", "#b7791f", "#c53030"),
         lty = c(2, 3, 1),
         legend = c("gamma = 0", "posterior mean gamma", "conditional mode gamma"))
  dev.off()
}
u3_df <- do.call(rbind, u3_rows)
utils::write.csv(u3_df, file.path(out_root, "u3_gamma_geometry_profile_summary.csv"), row.names = FALSE)

make_design <- function(n = 220L) {
  x <- seq(-1, 1, length.out = n)
  X <- cbind(1, x, x^2)
  colnames(X) <- c("intercept", "x", "x_sq")
  X
}

sim_static_exal <- function(n, tau, beta, sigma, gamma, seed) {
  set.seed(seed)
  X <- make_design(n)
  mu <- as.numeric(X %*% beta)
  y <- rexal(n, p0 = tau, mu = mu, sigma = sigma, gamma = gamma)
  list(X = X, y = y, q_true = mu)
}

fit_one_recovery <- function(dat, tau, model, method) {
  dqlm.ind <- identical(model, "al")
  if (identical(method, "vb")) {
    fit <- exal_static_LDVB(
      y = dat$y,
      X = dat$X,
      p0 = tau,
      dqlm.ind = dqlm.ind,
      max_iter = 180,
      tol = 1e-4,
      n_samp_xi = 100,
      ld_controls = list(xi_mode = "replicated", xi_replicates = 3L, reuse_seed = 20260306L),
      verbose = FALSE
    )
    qhat <- exdqlm:::.static_quantile_path_from_fit(fit, dat$X, algorithm = "vb")$mean
    gamma_est <- if (dqlm.ind) NA_real_ else as.numeric(fit$qsiggam$gamma_mean)[1]
    sigma_est <- if (dqlm.ind) as.numeric(fit$qsig$E_sigma)[1] else as.numeric(fit$qsiggam$sigma_mean)[1]
    list(
      qhat = qhat,
      gamma_est = gamma_est,
      sigma_est = sigma_est,
      fit = fit
    )
  } else {
    fit <- exal_static_mcmc(
      y = dat$y,
      X = dat$X,
      p0 = tau,
      dqlm.ind = dqlm.ind,
      n.burn = 120,
      n.mcmc = 120,
      thin = 1,
      init.from.vb = TRUE,
      vb_init_controls = list(max_iter = 80L, tol = 1e-3, n_samp_xi = 60L, verbose = FALSE),
      mh.proposal = if (dqlm.ind) "laplace_local" else "rw",
      mh.adapt = TRUE,
      mh.adapt.interval = 20L,
      verbose = FALSE
    )
    qhat <- exdqlm:::.static_quantile_path_from_fit(fit, dat$X, algorithm = "mcmc")$mean
    gamma_est <- if (dqlm.ind) NA_real_ else mean(as.numeric(fit$samp.gamma))
    sigma_est <- mean(as.numeric(fit$samp.sigma))
    list(
      qhat = qhat,
      gamma_est = gamma_est,
      sigma_est = sigma_est,
      fit = fit
    )
  }
}

recovery_jobs <- list(
  list(dgp = "al_generated", tau = 0.05, gamma_true = 0, seed = 6101L),
  list(dgp = "al_generated", tau = 0.95, gamma_true = 0, seed = 6102L),
  list(dgp = "exal_generated", tau = 0.05, gamma_true = 0.6, seed = 6201L),
  list(dgp = "exal_generated", tau = 0.95, gamma_true = -0.6, seed = 6202L)
)

run_job <- function(job) {
  beta_true <- c(0.4, -0.9, 0.6)
  sigma_true <- 0.8
  message(sprintf("U4 start | dgp=%s tau=%.2f gamma_true=%.2f", job$dgp, job$tau, job$gamma_true))
  dat <- sim_static_exal(n = 160L, tau = job$tau, beta = beta_true, sigma = sigma_true, gamma = job$gamma_true, seed = job$seed)
  fits <- list(
    al_vb = fit_one_recovery(dat, job$tau, "al", "vb"),
    exal_vb = fit_one_recovery(dat, job$tau, "exal", "vb"),
    al_mcmc = fit_one_recovery(dat, job$tau, "al", "mcmc"),
    exal_mcmc = fit_one_recovery(dat, job$tau, "exal", "mcmc")
  )
  rows <- list()
  kk <- 1L
  for (nm in names(fits)) {
    parts <- strsplit(nm, "_", fixed = TRUE)[[1]]
    model <- parts[1]
    method <- parts[2]
    qhat <- fits[[nm]]$qhat
    err <- qhat - dat$q_true
    rows[[kk]] <- data.frame(
      dgp = job$dgp,
      tau = job$tau,
      gamma_true = job$gamma_true,
      model = model,
      method = method,
      rmse = sqrt(mean(err^2)),
      mae = mean(abs(err)),
      bias = mean(err),
      gamma_est = fits[[nm]]$gamma_est,
      sigma_est = fits[[nm]]$sigma_est,
      stringsAsFactors = FALSE
    )
    kk <- kk + 1L
  }
  message(sprintf("U4 done  | dgp=%s tau=%.2f gamma_true=%.2f", job$dgp, job$tau, job$gamma_true))
  do.call(rbind, rows)
}

recovery_list <- lapply(recovery_jobs, run_job)
u4_df <- do.call(rbind, recovery_list)
utils::write.csv(u4_df, file.path(out_root, "u4_recovery_experiment_summary.csv"), row.names = FALSE)

# Pairwise deltas for recovery.
pair_rows <- list()
k <- 1L
for (dgp_i in unique(u4_df$dgp)) {
  for (tau_i in sort(unique(u4_df$tau))) {
    for (method_i in sort(unique(u4_df$method))) {
      ex <- u4_df[u4_df$dgp == dgp_i & u4_df$tau == tau_i & u4_df$method == method_i & u4_df$model == "exal", , drop = FALSE]
      al <- u4_df[u4_df$dgp == dgp_i & u4_df$tau == tau_i & u4_df$method == method_i & u4_df$model == "al", , drop = FALSE]
      if (nrow(ex) == 1L && nrow(al) == 1L) {
        pair_rows[[k]] <- data.frame(
          dgp = dgp_i,
          tau = tau_i,
          method = method_i,
          rmse_exal = ex$rmse,
          rmse_al = al$rmse,
          rmse_delta_exal_minus_al = ex$rmse - al$rmse,
          gamma_est_exal = ex$gamma_est,
          stringsAsFactors = FALSE
        )
        k <- k + 1L
      }
    }
  }
}
u4_pair_df <- do.call(rbind, pair_rows)
utils::write.csv(u4_pair_df, file.path(out_root, "u4_recovery_pairwise_exal_vs_al.csv"), row.names = FALSE)

note_path <- file.path(out_root, "u1_u4_audit_note.md")
writeLines(c(
  "# Static exAL Shared-Issue Audit (`U1-U4`)",
  "",
  "## Scope",
  "",
  "- `U1`: structural reduction and quantile-fixed checks",
  "- `U2`: static quantile-path mapping audit",
  "- `U3`: shared gamma-geometry / conditional-profile audit on frozen runs",
  "- `U4`: focused recovery experiment on AL-generated and exAL-generated static data",
  "",
  "## Primary outputs",
  "",
  "- `u1_reduction_identity_checks.csv`",
  "- `u1_quantile_fixed_checks.csv`",
  "- `u2_quantile_path_mapping_checks.csv`",
  "- `u3_gamma_geometry_profile_summary.csv`",
  "- `u4_recovery_experiment_summary.csv`",
  "- `u4_recovery_pairwise_exal_vs_al.csv`",
  "",
  "## Headline findings (see CSVs for exact values)",
  "",
  sprintf("- U1 max |A(gamma=0) - A_AL|: %.3e", max(abs(u1_reduction_df$A_err_gamma0), na.rm = TRUE)),
  sprintf("- U1 max |B(gamma=0) - B_AL|: %.3e", max(abs(u1_reduction_df$B_err_gamma0), na.rm = TRUE)),
  sprintf("- U1 max |q_tau - mu|: %.3e", max(abs(u1_quantile_df$q_tau_minus_mu), na.rm = TRUE)),
  sprintf("- U1 max |p(mu) - tau|: %.3e", max(abs(u1_quantile_df$p_mu_minus_tau), na.rm = TRUE)),
  sprintf("- U2 max quantile-path diff: %.3e", max(u2_df$max_abs_diff, na.rm = TRUE)),
  sprintf("- U3 largest conditional log-kernel gap (mode vs gamma=0): %.3f", max(u3_df$log_kernel_gap_mode_vs_zero, na.rm = TRUE)),
  sprintf("- U4 worst exAL-AL RMSE delta on AL-generated data: %.3f", max(subset(u4_pair_df, dgp == "al_generated")$rmse_delta_exal_minus_al, na.rm = TRUE)),
  sprintf("- U4 worst exAL-AL RMSE delta on exAL-generated data: %.3f", max(subset(u4_pair_df, dgp == "exal_generated")$rmse_delta_exal_minus_al, na.rm = TRUE))
), con = note_path)

message("Audit outputs written under: ", out_root)

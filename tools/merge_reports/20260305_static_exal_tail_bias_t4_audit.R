#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(devtools)
})

devtools::load_all(".", quiet = TRUE)

tau_lab <- function(tau) gsub("\\.", "p", format(as.numeric(tau), nsmall = 2))

run_root <- Sys.getenv(
  "EXDQLM_STATIC_AUDIT_RUN_ROOT",
  "results/sim_suite_static/static_vb_then_mcmc_tt5000_vbns1000_burn2000_n1000_20260305_160734"
)
sim_path <- Sys.getenv(
  "EXDQLM_STATIC_AUDIT_SIM_PATH",
  "results/sim_suite_static/series/static_exal_rich1d_mcq/sim_output.rds"
)
out_dir <- Sys.getenv(
  "EXDQLM_STATIC_AUDIT_T4_OUT_DIR",
  "results/sim_suite_static/audits/static_exal_tail_bias_t4_20260305"
)

if (!dir.exists(run_root)) stop("Audit run root not found: ", run_root)
if (!file.exists(sim_path)) stop("Audit sim file not found: ", sim_path)

dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

sim <- readRDS(sim_path)
cfg <- readRDS(file.path(run_root, "tables", "run_config.rds"))
TT <- min(as.integer(cfg$TT)[1], length(sim$y))
y <- as.numeric(sim$y[seq_len(TT)])
X <- as.matrix(sim$extras$X[seq_len(TT), , drop = FALSE])

focus_taus <- c(0.05, 0.95)
obs_idx <- ceiling(TT / 2)
a_sigma <- 1
b_sigma <- 1
log_prior_gamma <- function(g) 0

centered_diff <- function(a, b) {
  aa <- a - max(a, na.rm = TRUE)
  bb <- b - max(b, na.rm = TRUE)
  max(abs(aa - bb), na.rm = TRUE)
}

gig_log_kernel <- function(x, k, chi, psi) {
  ifelse(x > 0, (k - 1) * log(x) - 0.5 * (chi / x + psi * x), -Inf)
}

tn_unnorm_log_kernel <- function(x, mu, tau2) {
  ifelse(x > 0, -0.5 * ((x - mu)^2) / tau2, -Inf)
}

for (tau in focus_taus) {
  m_path <- file.path(run_root, "fits", "mcmc", sprintf("mcmc_exal_tau_%s_fit.rds", tau_lab(tau)))
  if (!file.exists(m_path)) stop("Missing MCMC fit file: ", m_path)
}

check_rows <- vector("list", length(focus_taus))

for (i in seq_along(focus_taus)) {
  tau <- focus_taus[i]
  m_path <- file.path(run_root, "fits", "mcmc", sprintf("mcmc_exal_tau_%s_fit.rds", tau_lab(tau)))
  fit_obj <- readRDS(m_path)$fit

  draw_idx <- max(1L, floor(nrow(fit_obj$samp.beta) / 2))
  beta <- as.numeric(fit_obj$samp.beta[draw_idx, ])
  sigma <- as.numeric(fit_obj$samp.sigma[draw_idx])
  gamma <- as.numeric(fit_obj$samp.gamma[draw_idx])
  v <- as.numeric(fit_obj$samp.v[draw_idx, ])
  s <- as.numeric(fit_obj$samp.s[draw_idx, ])

  L <- as.numeric(fit_obj$bounds["L"])[1]
  U <- as.numeric(fit_obj$bounds["U"])[1]
  A_of <- function(g) A.fn(tau, g)
  B_of <- function(g) B.fn(tau, g)
  C_of <- function(g) C.fn(tau, g)
  lam_of <- function(g) C_of(g) * abs(g)
  g_from_eta <- function(eta) {
    ss <- stats::plogis(eta)
    ss <- pmin(pmax(ss, 1e-12), 1 - 1e-12)
    L + (U - L) * ss
  }
  logJ <- function(eta) {
    ss <- stats::plogis(eta)
    ss <- pmin(pmax(ss, 1e-12), 1 - 1e-12)
    log(U - L) + log(ss) + log1p(-ss)
  }

  A <- A_of(gamma)
  B <- B_of(gamma)
  lambda <- lam_of(gamma)
  xb <- drop(X %*% beta)

  # v conditional: direct kernel vs GIG parameterization
  z_i <- y[obs_idx] - xb[obs_idx] - lambda * sigma * s[obs_idx]
  chi_v <- (z_i * z_i) / (B * sigma)
  psi_v <- (A * A) / (B * sigma) + 2 / sigma
  v_grid <- exp(seq(log(max(1e-6, v[obs_idx] / 8)), log(v[obs_idx] * 8 + 1e-6), length.out = 51))
  log_v_direct <- -0.5 * log(v_grid) -
    ((z_i - A * v_grid)^2) / (2 * B * sigma * v_grid) -
    v_grid / sigma
  log_v_gig <- gig_log_kernel(v_grid, k = 0.5, chi = chi_v, psi = psi_v)

  # s conditional: direct kernel vs truncated-normal parameterization
  r_i <- y[obs_idx] - xb[obs_idx] - A * v[obs_idx]
  tau2_s <- 1 / (1 + (lambda * lambda) * sigma / (B * v[obs_idx]))
  mu_s <- tau2_s * (lambda * r_i) / (B * v[obs_idx])
  s_grid <- seq(1e-6, max(1, s[obs_idx] * 4 + 1), length.out = 51)
  log_s_direct <- -0.5 * s_grid^2 -
    ((r_i - lambda * sigma * s_grid)^2) / (2 * B * sigma * v[obs_idx])
  log_s_tn <- tn_unnorm_log_kernel(s_grid, mu = mu_s, tau2 = tau2_s)

  # sigma conditional: direct kernel vs GIG parameterization
  r_vec <- y - xb - A * v
  chi_sigma <- sum((r_vec * r_vec) / (B * v)) + 2 * sum(v) + 2 * b_sigma
  psi_sigma <- (lambda * lambda / B) * sum((s * s) / v)
  k_sigma <- -(a_sigma + 1.5 * length(y))
  sigma_grid <- exp(seq(log(max(1e-6, sigma / 5)), log(sigma * 5 + 1e-6), length.out = 61))
  log_sigma_direct <- -(a_sigma + 1 + 1.5 * length(y)) * log(sigma_grid) -
    0.5 * (chi_sigma / sigma_grid + psi_sigma * sigma_grid)
  log_sigma_gig <- gig_log_kernel(sigma_grid, k = k_sigma, chi = chi_sigma, psi = psi_sigma)

  # gamma conditional on eta scale: direct squared form vs expanded form
  eta0 <- stats::qlogis((gamma - L) / (U - L))
  eta_grid <- seq(eta0 - 2, eta0 + 2, length.out = 81)
  log_eta_direct <- numeric(length(eta_grid))
  log_eta_expanded <- numeric(length(eta_grid))
  r_base <- y - xb - A * v
  for (j in seq_along(eta_grid)) {
    eta <- eta_grid[j]
    g <- g_from_eta(eta)
    Aj <- A_of(g)
    Bj <- B_of(g)
    lambdaj <- lam_of(g)
    res <- y - xb - lambdaj * sigma * s - Aj * v
    direct <- -(length(y) / 2) * log(Bj) - 0.5 * sum((res * res) / (Bj * sigma * v)) +
      log_prior_gamma(g) + logJ(eta)
    r0 <- y - xb - Aj * v
    expanded <- -(length(y) / 2) * log(Bj) -
      sum((r0 * r0) / (2 * Bj * sigma * v)) +
      (lambdaj / Bj) * sum(s * r0 / v) -
      ((lambdaj * lambdaj) * sigma / (2 * Bj)) * sum((s * s) / v) +
      log_prior_gamma(g) + logJ(eta)
    log_eta_direct[j] <- direct
    log_eta_expanded[j] <- expanded
  }

  check_rows[[i]] <- data.frame(
    tau = tau,
    draw_index = draw_idx,
    obs_index = obs_idx,
    current_run_gamma_kernel = as.character(fit_obj$mh.diagnostics$proposal)[1],
    current_run_gamma_kernel_exact = fit_obj$mh.diagnostics$proposal %in% c("rw", "laplace_rw"),
    v_kernel_max_centered_diff = centered_diff(log_v_direct, log_v_gig),
    s_kernel_max_centered_diff = centered_diff(log_s_direct, log_s_tn),
    sigma_kernel_max_centered_diff = centered_diff(log_sigma_direct, log_sigma_gig),
    gamma_kernel_max_centered_diff = centered_diff(log_eta_direct, log_eta_expanded),
    stringsAsFactors = FALSE
  )
}

kernel_checks <- do.call(rbind, check_rows)
write.csv(kernel_checks, file.path(out_dir, "t4_kernel_equivalence_checks.csv"), row.names = FALSE)

consistency_df <- data.frame(
  component = c(
    "Latent augmentation hierarchy",
    "beta conditional",
    "v conditional",
    "s conditional",
    "sigma conditional",
    "gamma support and eta transform",
    "gamma conditional exact kernels",
    "gamma laplace_local kernel",
    "VB/MCMC shared A-B-C-lambda map",
    "VB/MCMC shared sigma and gamma priors"
  ),
  original_paper_status = c(
    "Explicit in Section 3.1 of exAL_Original.pdf.",
    "Explicit Normal full conditional.",
    "Explicit GIG full conditional.",
    "Explicit truncated-Normal full conditional.",
    "Explicit GIG full conditional.",
    "Gamma support (L,U) and p(gamma,p0) map are explicit in Section 2.2.",
    "Paper suggests slice sampling or MH over gamma; both can target the exact conditional.",
    "Not part of the original exact posterior simulation scheme.",
    "Same quantile-fixed GAL parameterization underlies both VB and MCMC.",
    "Same bounded gamma prior class and IG sigma prior are used."
  ),
  code_location = c(
    "R/exal_static_mcmc.R augmented hierarchy and shorthands",
    "R/exal_static_mcmc.R beta update block",
    "R/exal_static_mcmc.R v update block",
    "R/exal_static_mcmc.R s update block",
    "R/exal_static_mcmc.R sigma update block",
    "R/exal_static_mcmc.R g_from_eta(), logJ(); R/utils.R support helpers",
    "R/exal_static_mcmc.R rw / laplace_rw eta proposals with MH accept-reject",
    "R/exal_static_mcmc.R laplace_local branch",
    "R/utils.R plus R/exal_static_LDVB.R and R/exal_static_mcmc.R helper usage",
    "R/exal_static_LDVB.R and R/exal_static_mcmc.R argument defaults"
  ),
  update_type = c(
    "shared hierarchy",
    "exact Gibbs",
    "exact Gibbs",
    "exact Gibbs",
    "exact Gibbs",
    "shared transform",
    "exact Metropolis-within-Gibbs",
    "approximate local Gaussian draw",
    "shared posterior ingredients",
    "shared priors"
  ),
  verdict = c(
    "consistent",
    "consistent",
    "consistent",
    "consistent",
    "consistent",
    "consistent",
    "consistent_when_using_rw_or_laplace_rw",
    "not_exact_posterior_kernel",
    "consistent",
    "consistent"
  ),
  note = c(
    "Static MCMC implements the same quantile-fixed GAL / exAL augmentation audited in T2.",
    "Matches the original paper's Normal update.",
    "Matches the original paper's GIG update.",
    "Matches the original paper's truncated-Normal update.",
    "Matches the original paper's GIG update for sigma.",
    "The eta logit transform and Jacobian are aligned with the bounded gamma support.",
    "The current frozen rich static run uses rw, so its gamma update targets the exact conditional density.",
    "laplace_local draws from a local Gaussian approximation without accept-reject; this is not exact MCMC and should not be used for signoff.",
    "VB and MCMC share the same A/B/C/C|gamma| construction, bounds, and latent definitions.",
    "No prior mismatch was found between static VB and static MCMC."
  ),
  stringsAsFactors = FALSE
)
write.csv(consistency_df, file.path(out_dir, "t4_mcmc_vb_consistency.csv"), row.names = FALSE)

cat("T4 audit artifacts written to:", out_dir, "\n")

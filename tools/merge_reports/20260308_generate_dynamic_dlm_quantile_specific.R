#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(devtools)
  library(Matrix)
})

devtools::load_all('.', quiet = TRUE)
source('tools/merge_reports/20260308_quantile_specific_sim_helpers.R')

Sys.setenv(
  OMP_NUM_THREADS = '1',
  OPENBLAS_NUM_THREADS = '1',
  MKL_NUM_THREADS = '1',
  VECLIB_MAXIMUM_THREADS = '1',
  NUMEXPR_NUM_THREADS = '1'
)

build_dlm_trend2harm <- function(period, no_trend = FALSE) {
  stopifnot(period > 2)
  lam1 <- 2 * pi / period
  lam2 <- 2 * lam1
  F <- c(1, 0, 1, 0, 1, 0)
  if (isTRUE(no_trend)) {
    G_trend <- diag(2)
    eps <- 1e-12
    Sigma <- diag(c(eps, eps, 1, 1, 1, 1))
  } else {
    G_trend <- matrix(c(1, 1, 0, 1), 2, 2, byrow = TRUE)
    Sigma <- diag(6)
  }
  R1 <- matrix(c(cos(lam1), sin(lam1), -sin(lam1), cos(lam1)), 2, 2, byrow = TRUE)
  R2 <- matrix(c(cos(lam2), sin(lam2), -sin(lam2), cos(lam2)), 2, 2, byrow = TRUE)
  G <- as.matrix(Matrix::bdiag(G_trend, R1, R2))
  list(F = F, G = G, Sigma = Sigma, d = length(F))
}

rmvnorm_chol <- function(n, mean, Sigma) {
  d <- length(mean)
  L <- chol(Sigma, pivot = FALSE)
  Z <- matrix(rnorm(d * n), d, n)
  sweep(L %*% Z, 1L, mean, `+`)
}

safe_list_num <- function(x, default) {
  z <- as.numeric(x)
  if (!length(z) || any(!is.finite(z))) default else z
}

scenario <- Sys.getenv('EXDQLM_DYNAMIC_DLM_SCENARIO', 'dlm_constV_smallW')
allowed <- c('dlm_constV_smallW', 'dlm_constV_bigW', 'dlm_ar1V')
if (!(scenario %in% allowed)) stop('Unsupported dynamic qspec scenario: ', scenario)

tau <- resolve_target_tau()
seed <- safe_int(Sys.getenv('EXDQLM_SIM_SEED', '123'), 123L)
TT <- safe_int(Sys.getenv('EXDQLM_SIM_T', '5000'), 5000L)
period <- safe_int(Sys.getenv('EXDQLM_DLM_PERIOD', '50'), 50L)
no_trend <- safe_bool(Sys.getenv('EXDQLM_DLM_NO_TREND', 'true'), TRUE)
m0 <- safe_num_vec(Sys.getenv('EXDQLM_DLM_M0', ''), default = rep(0, 6), length_out = 6L)
if (is.null(m0)) m0 <- rep(0, 6)
C0_scale <- safe_num(Sys.getenv('EXDQLM_DLM_C0_SCALE', '25'), 25)
C0 <- diag(C0_scale, 6)
V_base <- safe_num(Sys.getenv('EXDQLM_DLM_V', '9'), 9)
alpha <- switch(scenario,
  dlm_constV_smallW = safe_num(Sys.getenv('EXDQLM_DLM_ALPHA', '1e-4'), 1e-4),
  dlm_constV_bigW = safe_num(Sys.getenv('EXDQLM_DLM_ALPHA', '1'), 1),
  dlm_ar1V = safe_num(Sys.getenv('EXDQLM_DLM_ALPHA', '1e-4'), 1e-4)
)
mu_v <- safe_num(Sys.getenv('EXDQLM_DLM_MU_V', as.character(log(V_base))), log(V_base))
phi_v <- safe_num(Sys.getenv('EXDQLM_DLM_PHI_V', '0.95'), 0.95)
s_v <- safe_num(Sys.getenv('EXDQLM_DLM_S_V', '0.25'), 0.25)

set.seed(seed)
built <- build_dlm_trend2harm(period, no_trend = no_trend)
Fvec <- built$F
Gmat <- built$G
W <- alpha * built$Sigma
q_shift <- qnorm(tau)

theta_prev <- as.numeric(rmvnorm_chol(1L, m0, C0))
y <- numeric(TT)
mu <- numeric(TT)
V_t <- numeric(TT)
theta_store <- matrix(NA_real_, nrow = 6L, ncol = TT)
logV_prev <- mu_v
for (tt in seq_len(TT)) {
  a_t <- as.numeric(Gmat %*% theta_prev)
  theta_t <- as.numeric(rmvnorm_chol(1L, a_t, W))
  theta_store[, tt] <- theta_t
  mu[tt] <- sum(Fvec * theta_t)
  if (scenario == 'dlm_ar1V') {
    logV_t <- if (tt == 1L) mu_v else mu_v + phi_v * (logV_prev - mu_v) + s_v * rnorm(1)
    logV_prev <- logV_t
    V_t[tt] <- exp(logV_t)
  } else {
    V_t[tt] <- V_base
  }
  z <- rnorm(1)
  eps_star <- sqrt(V_t[tt]) * (z - q_shift)
  y[tt] <- mu[tt] + eps_star
  theta_prev <- theta_t
}
q_mat <- matrix(mu, ncol = 1L)
colnames(q_mat) <- sprintf('q_%s', tau_lab(tau))
scenario_root <- file.path('results', 'sim_suite_dlm_qspec', 'series', scenario, sprintf('tau_%s', tau_lab(tau)))
out_root <- Sys.getenv('EXDQLM_DYNAMIC_DLM_OUT_ROOT', scenario_root)
dir.create(out_root, recursive = TRUE, showWarnings = FALSE)

df_wide <- data.frame(t = seq_len(TT), y = y, mu = mu, q = mu, V_t = V_t)
df_long <- data.frame(t = seq_len(TT), p = tau, q = mu, y = y, mu = mu, V_t = V_t)
utils::write.csv(df_wide, file.path(out_root, 'series_wide.csv'), row.names = FALSE)
utils::write.csv(df_long, file.path(out_root, 'series_long.csv'), row.names = FALSE)
utils::write.csv(data.frame(t = seq_len(TT), p = tau, q_true = mu), file.path(out_root, 'true_quantile_grid.csv'), row.names = FALSE)
meta <- list(
  scenario = scenario,
  params = list(period = period, m0 = m0, C0 = C0, V = V_base, alpha = alpha, no_trend = no_trend, mu_v = mu_v, phi_v = phi_v, s_v = s_v),
  burnin = 0L,
  R_mc = 0L,
  seed = seed,
  quantile_target = tau,
  quantile_truth_method = 'exact_shifted_gaussian_dlm',
  noise_quantile_shift = q_shift
)
sim <- list(y = y, q = q_mat, p = tau, info = meta, extras = list(mu = mu, V_t = V_t, theta = theta_store))
saveRDS(sim, file.path(out_root, 'sim_output.rds'))
saveRDS(sim, file.path(out_root, 'sim_data.rds'))
fit_n <- min(TT, safe_int(Sys.getenv('EXDQLM_DYNAMIC_FIT_TT', as.character(TT)), TT))
fit_root <- file.path(out_root, sprintf('fit_input_tt%d', fit_n))
dir.create(fit_root, recursive = TRUE, showWarnings = FALSE)
fit_sim <- sim
fit_sim$y <- sim$y[seq_len(fit_n)]
fit_sim$q <- as.matrix(sim$q[seq_len(fit_n), , drop = FALSE])
fit_sim$extras <- lapply(sim$extras, function(obj) {
  if (is.vector(obj) && length(obj) >= fit_n) return(obj[seq_len(fit_n)])
  if (is.matrix(obj) && ncol(obj) >= fit_n) return(obj[, seq_len(fit_n), drop = FALSE])
  obj
})
saveRDS(fit_sim, file.path(fit_root, 'sim_output.rds'))
saveRDS(list(sim_path = file.path(fit_root, 'sim_output.rds'), tau = tau, TT = fit_n), file.path(fit_root, 'run_config.rds'))
cat(sprintf('Generated dynamic quantile-specific DLM sim at %s\n', out_root))

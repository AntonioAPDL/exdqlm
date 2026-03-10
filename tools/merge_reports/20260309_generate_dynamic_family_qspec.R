#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(devtools)
  library(Matrix)
  library(ggplot2)
})

devtools::load_all('.', quiet = TRUE)
source('tools/merge_reports/20260308_quantile_specific_sim_helpers.R')

Sys.setenv(OMP_NUM_THREADS='1', OPENBLAS_NUM_THREADS='1', MKL_NUM_THREADS='1', VECLIB_MAXIMUM_THREADS='1', NUMEXPR_NUM_THREADS='1')

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
    G_trend <- matrix(c(1,1,0,1), 2, 2, byrow = TRUE)
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

family <- safe_chr(Sys.getenv('EXDQLM_DYNAMIC_FAMILY', 'normal'), 'normal')
tau <- resolve_target_tau(default = 0.05)
tau_tag <- tau_lab(tau)
base_root <- safe_chr(Sys.getenv('EXDQLM_DYNAMIC_FAMILY_OUT_ROOT', 'results/function_testing_20260309_dynamic_dlm_family_qspec'), 'results/function_testing_20260309_dynamic_dlm_family_qspec')
out_root <- file.path(base_root, 'dlm_constV_smallW', family, paste0('tau_', tau_tag))
seed <- safe_int(Sys.getenv('EXDQLM_DYNAMIC_FAMILY_SEED', '20260309'), 20260309L)
TT_main <- safe_int(Sys.getenv('EXDQLM_DYNAMIC_FAMILY_T', '7000'), 7000L)
TT_warmup <- safe_int(Sys.getenv('EXDQLM_DYNAMIC_FAMILY_WARMUP', '2000'), 2000L)
period <- safe_int(Sys.getenv('EXDQLM_DYNAMIC_FAMILY_PERIOD', '50'), 50L)
no_trend <- safe_bool(Sys.getenv('EXDQLM_DYNAMIC_FAMILY_NO_TREND', 'false'), FALSE)
m0 <- safe_num_vec(Sys.getenv('EXDQLM_DYNAMIC_FAMILY_M0', ''), default = rep(0, 6), length_out = 6L)
if (is.null(m0)) m0 <- rep(0, 6)
C0_scale <- safe_num(Sys.getenv('EXDQLM_DYNAMIC_FAMILY_C0_SCALE', '25'), 25)
alpha <- safe_num(Sys.getenv('EXDQLM_DYNAMIC_FAMILY_ALPHA', '1e-4'), 1e-4)
normal_sigma <- safe_num(Sys.getenv('EXDQLM_DYNAMIC_FAMILY_NORMAL_SIGMA', '3'), 3)
laplace_scale <- safe_num(Sys.getenv('EXDQLM_DYNAMIC_FAMILY_LAPLACE_SCALE', '3'), 3)
gausmix_sigma <- safe_num_vec(Sys.getenv('EXDQLM_DYNAMIC_FAMILY_GAUSMIX_SIGMA', '1,2.23606797749979'), c(1, sqrt(5)), length_out = 2L)
if (is.null(gausmix_sigma)) gausmix_sigma <- c(1, sqrt(5))
gausmix_weights <- safe_num_vec(Sys.getenv('EXDQLM_DYNAMIC_FAMILY_GAUSMIX_WEIGHTS', '0.1,0.9'), c(0.1, 0.9), length_out = 2L)
if (is.null(gausmix_weights)) gausmix_weights <- c(0.1, 0.9)
gausmix_offset <- safe_num(Sys.getenv('EXDQLM_DYNAMIC_FAMILY_GAUSMIX_OFFSET', '1'), 1)
gpd_xi <- safe_num(Sys.getenv('EXDQLM_DYNAMIC_FAMILY_GPD_XI', '3'), 3)
fit_t_vals <- safe_num_vec(Sys.getenv('EXDQLM_DYNAMIC_FAMILY_FIT_T_LIST', '1000,2000,5000'), default = c(1000, 2000, 5000))

set.seed(seed)
built <- build_dlm_trend2harm(period, no_trend = no_trend)
Fvec <- built$F
Gmat <- built$G
W <- alpha * built$Sigma
C0 <- diag(C0_scale, 6)
TT_total <- TT_warmup + TT_main

theta_prev <- as.numeric(rmvnorm_chol(1L, m0, C0))
y_all <- numeric(TT_total)
mu_all <- numeric(TT_total)
theta_store <- matrix(NA_real_, nrow = 6L, ncol = TT_total)
eps_store <- numeric(TT_total)
for (tt in seq_len(TT_total)) {
  a_t <- as.numeric(Gmat %*% theta_prev)
  theta_t <- as.numeric(rmvnorm_chol(1L, a_t, W))
  theta_store[, tt] <- theta_t
  mu_all[tt] <- sum(Fvec * theta_t)
  err <- draw_qspec_error(
    n = 1L,
    tau = tau,
    family = family,
    normal_sigma = normal_sigma,
    laplace_scale = laplace_scale,
    gausmix_sigma = gausmix_sigma,
    gausmix_weights = gausmix_weights,
    gausmix_offset = gausmix_offset,
    gpd_xi = gpd_xi
  )
  eps_store[tt] <- err$eps[1]
  y_all[tt] <- mu_all[tt] + eps_store[tt]
  theta_prev <- theta_t
}
keep_idx <- seq.int(TT_warmup + 1L, TT_total)
y <- y_all[keep_idx]
mu <- mu_all[keep_idx]
theta_keep <- theta_store[, keep_idx, drop = FALSE]
eps_keep <- eps_store[keep_idx]
q_mat <- matrix(mu, ncol = 1L)
colnames(q_mat) <- sprintf('q_%s', tau_tag)

series_wide <- data.frame(t = seq_len(TT_main), y = y, mu = mu, q_target = mu, eps = eps_keep, stringsAsFactors = FALSE)
series_long <- data.frame(t = seq_len(TT_main), tau = tau, y = y, q = mu, mu = mu, eps = eps_keep, stringsAsFactors = FALSE)
true_grid <- data.frame(t = seq_len(TT_main), tau = tau, q_true = mu, stringsAsFactors = FALSE)

sim <- make_quantile_specific_sim_output(
  y = y,
  tau = tau,
  q_true = q_mat,
  info = list(
    scenario = 'dynamic_dlm_family_qspec',
    params = list(family = family, TT = TT_main, TT_warmup = TT_warmup, period = period, alpha = alpha, normal_sigma = normal_sigma, laplace_scale = laplace_scale, gausmix_sigma = gausmix_sigma, gausmix_weights = gausmix_weights, gausmix_offset = gausmix_offset, gpd_xi = gpd_xi),
    burnin = as.integer(TT_warmup),
    R_mc = 0L,
    seed = seed,
    quantile_truth_method = err$truth_method,
    quantile_target = tau,
    noise_quantile_shift = err$shift
  ),
  extras = c(list(mu = mu, theta = theta_keep, eps_shifted = eps_keep, noise_family = family), err$family_params)
)

dir.create(out_root, recursive = TRUE, showWarnings = FALSE)
write.csv(series_wide, file.path(out_root, 'series_wide.csv'), row.names = FALSE)
write.csv(series_long, file.path(out_root, 'series_long.csv'), row.names = FALSE)
write.csv(true_grid, file.path(out_root, 'true_quantile_grid.csv'), row.names = FALSE)
saveRDS(sim, file.path(out_root, 'sim_output.rds'))
saveRDS(sim, file.path(out_root, 'sim_data.rds'))
saveRDS(list(timestamp = format(Sys.time(), '%Y-%m-%d %H:%M:%S'), seed = seed, tau = tau, family = family, TT_main = TT_main, TT_warmup = TT_warmup), file.path(out_root, 'run_config.rds'))

plot_df <- data.frame(t = seq_len(TT_main), y = y, q = mu)
plt <- ggplot(plot_df, aes(x = t, y = y)) +
  geom_line(color = '#23344B', alpha = 0.45, linewidth = 0.35) +
  geom_line(aes(y = q), color = '#A63446', linewidth = 0.7) +
  labs(title = sprintf('Dynamic family qspec | %s | tau = %.2f', family, tau), subtitle = 'Small-W trend + seasonal DLM with quantile-specific centered errors', x = 'time', y = 'y') +
  theme_minimal(base_size = 14)
ggsave(file.path(out_root, sprintf('dynamic_family_%s_tau_%s.png', family, tau_tag)), plt, width = 13, height = 8, dpi = 160)

sub_roots <- write_dynamic_tail_subsets(
  sim_output = sim,
  out_root = out_root,
  target_n_values = fit_t_vals[fit_t_vals <= TT_main],
  series_wide = series_wide,
  series_long = series_long,
  extra_files = c('true_quantile_grid.csv')
)

writeLines(
  c('Dynamic family qspec dataset', sprintf('out_root: %s', out_root), sprintf('family: %s', family), sprintf('tau: %.2f', tau), sprintf('TT_main: %d', TT_main), sprintf('TT_warmup: %d', TT_warmup), sprintf('truth_method: %s', err$truth_method), sprintf('tail fit inputs: %s', paste(sub_roots, collapse = '; '))),
  file.path(out_root, 'meta.txt')
)

cat(sprintf('Generated dynamic family qspec dataset under: %s\n', out_root))

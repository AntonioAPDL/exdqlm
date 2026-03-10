#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(ggplot2)
})

source('tools/merge_reports/20260308_quantile_specific_sim_helpers.R')

family <- safe_chr(Sys.getenv('EXDQLM_STATIC_PAPER_FAMILY', 'normal'), 'normal')
tau <- resolve_target_tau(default = 0.05)
tau_tag <- tau_lab(tau)
base_root <- safe_chr(
  Sys.getenv('EXDQLM_STATIC_PAPER_FAMILY_OUT_ROOT', 'results/function_testing_20260309_static_paper_family_qspec'),
  'results/function_testing_20260309_static_paper_family_qspec'
)
out_root <- file.path(base_root, family, paste0('tau_', tau_tag))
n_total <- safe_int(Sys.getenv('EXDQLM_STATIC_PAPER_N', '7000'), 7000L)
target_n <- safe_int(Sys.getenv('EXDQLM_STATIC_PAPER_TARGET_N', '5000'), 5000L)
seed <- safe_int(Sys.getenv('EXDQLM_STATIC_PAPER_SEED', '20260309'), 20260309L)
rho <- safe_num(Sys.getenv('EXDQLM_STATIC_PAPER_RHO', '0.5'), 0.5)
normal_sigma <- safe_num(Sys.getenv('EXDQLM_STATIC_PAPER_NORMAL_SIGMA', '3'), 3)
laplace_scale <- safe_num(Sys.getenv('EXDQLM_STATIC_PAPER_LAPLACE_SCALE', '3'), 3)
gausmix_sigma <- safe_num_vec(Sys.getenv('EXDQLM_STATIC_PAPER_GAUSMIX_SIGMA', '1,2.23606797749979'), c(1, sqrt(5)), length_out = 2L)
if (is.null(gausmix_sigma)) gausmix_sigma <- c(1, sqrt(5))
gausmix_weights <- safe_num_vec(Sys.getenv('EXDQLM_STATIC_PAPER_GAUSMIX_WEIGHTS', '0.1,0.9'), c(0.1, 0.9), length_out = 2L)
if (is.null(gausmix_weights)) gausmix_weights <- c(0.1, 0.9)
gausmix_offset <- safe_num(Sys.getenv('EXDQLM_STATIC_PAPER_GAUSMIX_OFFSET', '1'), 1)
gpd_xi <- safe_num(Sys.getenv('EXDQLM_STATIC_PAPER_GPD_XI', '3'), 3)

beta_slopes <- c(3, 1.5, 0, 0, 2, 0, 0, 0)
true_ind <- as.integer(beta_slopes != 0)
feature_names <- sprintf('x%02d', seq_along(beta_slopes))

if (n_total < 500L) stop('n_total must be at least 500')
if (target_n < 200L || target_n > n_total) stop('target_n must satisfy 200 <= target_n <= n_total')
if (!(tau > 0 && tau < 1)) stop('tau must lie in (0,1)')
if (!(rho >= 0 && rho < 1)) stop('rho must lie in [0,1)')

set.seed(seed)
Sigma_x <- build_ar1_cov(length(beta_slopes), rho)
Z <- matrix(stats::rnorm(n_total * length(beta_slopes)), nrow = n_total, ncol = length(beta_slopes))
X_cov <- Z %*% chol(Sigma_x)
colnames(X_cov) <- feature_names
X <- cbind('(Intercept)' = 1, X_cov)
mu_x <- as.numeric(X_cov %*% beta_slopes)
err <- draw_qspec_error(
  n = n_total,
  tau = tau,
  family = family,
  normal_sigma = normal_sigma,
  laplace_scale = laplace_scale,
  gausmix_sigma = gausmix_sigma,
  gausmix_weights = gausmix_weights,
  gausmix_offset = gausmix_offset,
  gpd_xi = gpd_xi
)
y <- mu_x + err$eps
q_true <- matrix(mu_x, ncol = 1L)
colnames(q_true) <- sprintf('q_%s', tau_tag)

coef_truth <- data.frame(
  tau = tau,
  term = feature_names,
  beta_truth = beta_slopes,
  is_signal = beta_slopes != 0,
  stringsAsFactors = FALSE
)

series_wide <- data.frame(
  row_id = seq_len(n_total),
  y = y,
  mu = mu_x,
  x_main = X_cov[, 1],
  q_target = mu_x,
  stringsAsFactors = FALSE
)
series_wide <- cbind(series_wide, as.data.frame(X_cov, check.names = FALSE))
series_long <- data.frame(
  row_id = seq_len(n_total),
  tau = tau,
  y = y,
  q = mu_x,
  mu = mu_x,
  x_main = X_cov[, 1],
  stringsAsFactors = FALSE
)

x_grid <- seq(quantile(X_cov[, 1], 0.01), quantile(X_cov[, 1], 0.99), length.out = 1200L)
grid_cov <- matrix(0, nrow = length(x_grid), ncol = ncol(X_cov))
grid_cov[, 1] <- x_grid
colnames(grid_cov) <- feature_names
q_grid <- data.frame(x_main = x_grid, tau = tau, q = as.numeric(grid_cov %*% beta_slopes), stringsAsFactors = FALSE)

sim_output <- make_quantile_specific_sim_output(
  y = y,
  tau = tau,
  q_true = q_true,
  info = list(
    scenario = 'static_paper_family_qspec',
    params = list(
      family = family,
      beta_slopes = beta_slopes,
      rho = rho,
      p_covariates = length(beta_slopes),
      n = n_total,
      normal_sigma = normal_sigma,
      laplace_scale = laplace_scale,
      gausmix_sigma = gausmix_sigma,
      gausmix_weights = gausmix_weights,
      gausmix_offset = gausmix_offset,
      gpd_xi = gpd_xi
    ),
    burnin = 0L,
    R_mc = 0L,
    seed = seed,
    quantile_truth_method = err$truth_method,
    quantile_target = tau,
    noise_quantile_shift = err$shift
  ),
  extras = c(
    list(
      X = X,
      x_main = as.numeric(X_cov[, 1]),
      mu = mu_x,
      coef_truth = coef_truth,
      true_ind = true_ind,
      beta_mean = beta_slopes,
      noise_family = family,
      eps_shifted = err$eps
    ),
    err$family_params
  )
)

dir.create(out_root, recursive = TRUE, showWarnings = FALSE)
write.csv(series_wide, file.path(out_root, 'series_wide.csv'), row.names = FALSE)
write.csv(series_long, file.path(out_root, 'series_long.csv'), row.names = FALSE)
write.csv(q_grid, file.path(out_root, 'true_quantile_grid.csv'), row.names = FALSE)
write.csv(coef_truth, file.path(out_root, 'coef_truth.csv'), row.names = FALSE)
saveRDS(sim_output, file.path(out_root, 'sim_output.rds'))
saveRDS(sim_output, file.path(out_root, 'sim_data.rds'))
saveRDS(list(timestamp = format(Sys.time(), '%Y-%m-%d %H:%M:%S'), seed = seed, tau = tau, family = family), file.path(out_root, 'run_config.rds'))

plt <- ggplot(data.frame(x_main = X_cov[, 1], y = y), aes(x = x_main, y = y)) +
  geom_point(shape = 16, size = 0.9, alpha = 0.12, color = '#23344B') +
  geom_line(data = q_grid, aes(x = x_main, y = q), inherit.aes = FALSE, color = '#A63446', linewidth = 1.0) +
  labs(
    title = sprintf('Paper-family static qspec | %s | tau = %.2f', family, tau),
    subtitle = 'Paper-style correlated p=8 design with quantile-specific centering',
    x = 'x01',
    y = 'y'
  ) +
  theme_minimal(base_size = 14)
ggsave(file.path(out_root, sprintf('paper_family_%s_tau_%s.png', family, tau_tag)), plt, width = 13, height = 8, dpi = 160)

sub_root <- write_quantile_specific_subsample(
  sim_output = sim_output,
  out_root = out_root,
  target_n = target_n,
  order_key = X_cov[, 1],
  sub_label = 'x01_sorted',
  series_wide = series_wide,
  series_long = series_long,
  extra_files = c('coef_truth.csv', 'true_quantile_grid.csv')
)

writeLines(
  c(
    'Static paper-family qspec dataset',
    sprintf('out_root: %s', out_root),
    sprintf('family: %s', family),
    sprintf('tau: %.2f', tau),
    sprintf('n_total: %d', n_total),
    sprintf('target_n: %d', target_n),
    sprintf('seed: %d', seed),
    sprintf('truth_method: %s', err$truth_method),
    sprintf('shift: %.8f', err$shift),
    sprintf('fit_input_subsample: %s', sub_root)
  ),
  file.path(out_root, 'meta.txt')
)

cat(sprintf('Generated static paper-family qspec dataset under: %s\n', out_root))

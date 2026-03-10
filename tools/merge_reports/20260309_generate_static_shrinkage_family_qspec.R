#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(ggplot2)
})

source('tools/merge_reports/20260308_quantile_specific_sim_helpers.R')

family <- safe_chr(Sys.getenv('EXDQLM_STATIC_SHRINK_FAMILY', 'normal'), 'normal')
tau <- resolve_target_tau(default = 0.05)
tau_tag <- tau_lab(tau)
base_root <- safe_chr(
  Sys.getenv('EXDQLM_STATIC_SHRINK_FAMILY_OUT_ROOT', 'results/function_testing_20260309_static_shrinkage_family_qspec'),
  'results/function_testing_20260309_static_shrinkage_family_qspec'
)
out_root <- file.path(base_root, family, paste0('tau_', tau_tag))
n_total <- safe_int(Sys.getenv('EXDQLM_STATIC_SHRINK_FAMILY_N', '7000'), 7000L)
target_n <- safe_int(Sys.getenv('EXDQLM_STATIC_SHRINK_FAMILY_TARGET_N', '5000'), 5000L)
seed <- safe_int(Sys.getenv('EXDQLM_STATIC_SHRINK_FAMILY_SEED', '20260309'), 20260309L)
rho <- safe_num(Sys.getenv('EXDQLM_STATIC_SHRINK_FAMILY_RHO', '0.35'), 0.35)
normal_sigma <- safe_num(Sys.getenv('EXDQLM_STATIC_SHRINK_FAMILY_NORMAL_SIGMA', '1'), 1)
laplace_scale <- safe_num(Sys.getenv('EXDQLM_STATIC_SHRINK_FAMILY_LAPLACE_SCALE', '1'), 1)
gausmix_sigma <- safe_num_vec(Sys.getenv('EXDQLM_STATIC_SHRINK_FAMILY_GAUSMIX_SIGMA', '1,2.23606797749979'), c(1, sqrt(5)), length_out = 2L)
if (is.null(gausmix_sigma)) gausmix_sigma <- c(1, sqrt(5))
gausmix_weights <- safe_num_vec(Sys.getenv('EXDQLM_STATIC_SHRINK_FAMILY_GAUSMIX_WEIGHTS', '0.1,0.9'), c(0.1, 0.9), length_out = 2L)
if (is.null(gausmix_weights)) gausmix_weights <- c(0.1, 0.9)
gausmix_offset <- safe_num(Sys.getenv('EXDQLM_STATIC_SHRINK_FAMILY_GAUSMIX_OFFSET', '1'), 1)
gpd_xi <- safe_num(Sys.getenv('EXDQLM_STATIC_SHRINK_FAMILY_GPD_XI', '3'), 3)
beta0 <- safe_num(Sys.getenv('EXDQLM_STATIC_SHRINK_FAMILY_BETA0', '1.0'), 1.0)

beta_slopes <- c(1.50, -1.10, 0.75, -0.55, 0.20, -0.15, 0.06, -0.04, 0.02, 0, 0, 0, 0, 0)
coef_groups <- c('strong', 'strong', 'moderate', 'moderate', 'small', 'small', 'near_zero', 'near_zero', 'near_zero', 'zero', 'zero', 'zero', 'zero', 'zero')
feature_names <- sprintf('x%02d', seq_along(beta_slopes))

set.seed(seed)
Sigma_x <- build_ar1_cov(length(beta_slopes), rho)
Z <- matrix(stats::rnorm(n_total * length(beta_slopes)), nrow = n_total, ncol = length(beta_slopes))
X_raw <- Z %*% chol(Sigma_x)
X_cov <- scale(X_raw)
colnames(X_cov) <- feature_names
X <- cbind('(Intercept)' = 1, X_cov)
mu_x <- as.numeric(beta0 + X_cov %*% beta_slopes)
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
  term = c('(Intercept)', feature_names),
  beta_truth = c(beta0, beta_slopes),
  group = c('intercept', coef_groups),
  abs_truth = abs(c(beta0, beta_slopes)),
  is_zero = c(FALSE, beta_slopes == 0),
  is_near_zero = c(FALSE, abs(beta_slopes) > 0 & abs(beta_slopes) < 0.10),
  is_signal = c(FALSE, abs(beta_slopes) >= 0.10),
  stringsAsFactors = FALSE
)

series_wide <- data.frame(row_id = seq_len(n_total), y = y, mu = mu_x, x_main = X_cov[, 1], q_target = mu_x, stringsAsFactors = FALSE)
series_wide <- cbind(series_wide, as.data.frame(X_cov, check.names = FALSE))
series_long <- data.frame(row_id = seq_len(n_total), tau = tau, y = y, q = mu_x, mu = mu_x, x_main = X_cov[, 1], stringsAsFactors = FALSE)

x_grid <- seq(quantile(X_cov[, 1], 0.01), quantile(X_cov[, 1], 0.99), length.out = 1200L)
grid_cov <- matrix(0, nrow = length(x_grid), ncol = ncol(X_cov))
grid_cov[, 1] <- x_grid
colnames(grid_cov) <- feature_names
q_grid <- data.frame(x_main = x_grid, tau = tau, q = as.numeric(beta0 + grid_cov %*% beta_slopes), stringsAsFactors = FALSE)

sim_output <- make_quantile_specific_sim_output(
  y = y,
  tau = tau,
  q_true = q_true,
  info = list(
    scenario = 'static_shrinkage_family_qspec',
    params = list(
      family = family,
      beta0 = beta0,
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
      beta_mean = c(beta0, beta_slopes),
      coef_groups = c('intercept', coef_groups),
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
saveRDS(list(timestamp = format(Sys.time(), '%Y-%m-%d %H:%M:%S'), seed = seed, tau = tau, family = family), file.path(out_root, 'run_config.rds'))

plt <- ggplot(data.frame(x_main = X_cov[, 1], y = y), aes(x = x_main, y = y)) +
  geom_point(shape = 16, size = 0.9, alpha = 0.12, color = '#23344B') +
  geom_line(data = q_grid, aes(x = x_main, y = q), inherit.aes = FALSE, color = '#A63446', linewidth = 1.0) +
  labs(title = sprintf('Static shrinkage-family qspec | %s | tau = %.2f', family, tau), subtitle = 'Correlated high-dimensional shrinkage design with quantile-specific centering', x = 'x01', y = 'y') +
  theme_minimal(base_size = 14)
ggsave(file.path(out_root, sprintf('shrinkage_family_%s_tau_%s.png', family, tau_tag)), plt, width = 13, height = 8, dpi = 160)

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
  c('Static shrinkage-family qspec dataset', sprintf('out_root: %s', out_root), sprintf('family: %s', family), sprintf('tau: %.2f', tau), sprintf('n_total: %d', n_total), sprintf('target_n: %d', target_n), sprintf('truth_method: %s', err$truth_method), sprintf('fit_input_subsample: %s', sub_root)),
  file.path(out_root, 'meta.txt')
)

cat(sprintf('Generated static shrinkage-family qspec dataset under: %s\n', out_root))

#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(ggplot2)
})

source("tools/merge_reports/20260308_quantile_specific_sim_helpers.R")

tau <- resolve_target_tau(default = 0.50)
tau_tag <- tau_lab(tau)
base_root <- safe_chr(
  Sys.getenv("EXDQLM_STATIC_SHRINK_OUT_ROOT", "results/function_testing_20260308_static_homoskedastic_shrinkage_gaussian_qspec"),
  "results/function_testing_20260308_static_homoskedastic_shrinkage_gaussian_qspec"
)
out_root <- file.path(base_root, paste0("tau_", tau_tag))
n_total <- safe_int(Sys.getenv("EXDQLM_STATIC_SHRINK_N", "7000"), 7000L)
target_n <- safe_int(Sys.getenv("EXDQLM_STATIC_SHRINK_TARGET_N", "5000"), 5000L)
seed <- safe_int(Sys.getenv("EXDQLM_STATIC_SHRINK_SEED", "20260308"), 20260308L)
rho <- safe_num(Sys.getenv("EXDQLM_STATIC_SHRINK_RHO", "0.35"), 0.35)
sigma0 <- safe_num(Sys.getenv("EXDQLM_STATIC_SHRINK_SIGMA", "1.0"), 1.0)
beta0 <- safe_num(Sys.getenv("EXDQLM_STATIC_SHRINK_BETA0", "1.0"), 1.0)
x_main_clip <- safe_num(Sys.getenv("EXDQLM_STATIC_SHRINK_XMAIN_CLIP", "2.5"), 2.5)

beta_slopes <- c(
  1.50, -1.10, 0.75, -0.55,
  0.20, -0.15,
  0.06, -0.04, 0.02,
  0.00, 0.00, 0.00, 0.00, 0.00
)
coef_groups <- c(
  "strong", "strong", "moderate", "moderate",
  "small", "small",
  "near_zero", "near_zero", "near_zero",
  "zero", "zero", "zero", "zero", "zero"
)
stopifnot(length(beta_slopes) == length(coef_groups))

if (n_total < 500L) stop("n_total must be at least 500")
if (target_n < 200L || target_n > n_total) stop("target_n must satisfy 200 <= target_n <= n_total")
if (!(sigma0 > 0)) stop("sigma must be positive")
if (!(rho >= 0 && rho < 1)) stop("rho must lie in [0,1)")
if (!(tau > 0 && tau < 1)) stop("tau must lie in (0,1)")

set.seed(seed)
p_cov <- length(beta_slopes)
Sigma_x <- outer(seq_len(p_cov), seq_len(p_cov), function(i, j) rho ^ abs(i - j))
Z <- matrix(stats::rnorm(n_total * p_cov), nrow = n_total, ncol = p_cov)
X_raw <- Z %*% chol(Sigma_x)
X_cov <- scale(X_raw)
feature_names <- sprintf("x%02d", seq_along(beta_slopes))
colnames(X_cov) <- feature_names
X <- cbind("(Intercept)" = 1, X_cov)

mu_x <- as.numeric(beta0 + X_cov %*% beta_slopes)
q_eps <- stats::qnorm(tau)
z_raw <- stats::rnorm(n_total)
z_shift <- z_raw - q_eps
y <- mu_x + sigma0 * z_shift
q_true <- matrix(mu_x, ncol = 1)
colnames(q_true) <- sprintf("q_%03d", as.integer(round(100 * tau)))
coef_names <- c("(Intercept)", feature_names)
coef_truth <- data.frame(
  tau = tau,
  term = coef_names,
  beta_truth = c(beta0, beta_slopes),
  group = c("intercept", coef_groups),
  abs_truth = abs(c(beta0, beta_slopes)),
  is_zero = c(FALSE, beta_slopes == 0),
  is_near_zero = c(FALSE, abs(beta_slopes) > 0 & abs(beta_slopes) < 0.10),
  is_signal = c(FALSE, abs(beta_slopes) >= 0.10),
  stringsAsFactors = FALSE
)

series_wide <- data.frame(
  row_id = seq_len(n_total),
  y = y,
  mu = mu_x,
  x_main = X_cov[, 1],
  sigma = sigma0,
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
  sigma = sigma0,
  stringsAsFactors = FALSE
)

x_main_grid <- seq(
  quantile(X_cov[, 1], probs = 0.01),
  quantile(X_cov[, 1], probs = 0.99),
  length.out = 1200L
)
mu_grid <- beta0 + beta_slopes[1] * x_main_grid
q_grid <- data.frame(x_main = x_main_grid, tau = tau, q = mu_grid, stringsAsFactors = FALSE)

sim_output <- make_quantile_specific_sim_output(
  y = y,
  tau = tau,
  q_true = q_true,
  info = list(
    scenario = "static_homoskedastic_gaussian_shrinkage_quantile_specific",
    params = list(
      beta0 = beta0,
      beta_slopes = beta_slopes,
      sigma0 = sigma0,
      rho = rho,
      p_covariates = p_cov,
      n = n_total,
      noise_family = "normal"
    ),
    burnin = 0L,
    R_mc = 0L,
    seed = seed,
    quantile_truth_method = "exact_shifted_normal_closed_form",
    quantile_target = tau,
    noise_quantile_shift = q_eps
  ),
  extras = list(
    X = X,
    x_main = as.numeric(X_cov[, 1]),
    mu = mu_x,
    sigma = rep(sigma0, n_total),
    z_raw = z_raw,
    z_shift = z_shift,
    noise_family = "normal",
    coef_truth = coef_truth,
    beta_mean = c(beta0, beta_slopes),
    coef_groups = c("intercept", coef_groups)
  )
)

dir.create(out_root, recursive = TRUE, showWarnings = FALSE)
write.csv(series_wide, file.path(out_root, "series_wide.csv"), row.names = FALSE)
write.csv(series_long, file.path(out_root, "series_long.csv"), row.names = FALSE)
write.csv(q_grid, file.path(out_root, "true_quantile_grid.csv"), row.names = FALSE)
write.csv(coef_truth, file.path(out_root, "coef_truth.csv"), row.names = FALSE)
saveRDS(sim_output, file.path(out_root, "sim_output.rds"))
saveRDS(
  list(
    timestamp = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
    seed = seed,
    tau = tau,
    beta0 = beta0,
    beta_slopes = beta_slopes,
    sigma0 = sigma0,
    rho = rho,
    n_total = n_total,
    target_n = target_n,
    truth_method = "exact_shifted_normal_closed_form",
    q_eps = q_eps
  ),
  file.path(out_root, "run_config.rds")
)

plt <- ggplot(data.frame(x_main = pmin(pmax(X_cov[, 1], -x_main_clip), x_main_clip), y = y), aes(x = x_main, y = y)) +
  geom_point(shape = 16, size = 0.95, alpha = 0.13, color = "#1F2A44") +
  geom_line(data = q_grid, aes(x = x_main, y = q), inherit.aes = FALSE, color = "#A63446", linewidth = 1.0) +
  labs(
    title = sprintf("Static homoskedastic Gaussian shrinkage DGP | quantile-specific tau = %.2f", tau),
    subtitle = "Correlated covariates with strong, weak, near-zero, and exact-zero coefficients",
    x = "x01",
    y = "y",
    caption = sprintf(
      "n = %s, p = %d, seed = %d | sigma = %.2f, rho = %.2f | shifted by qnorm(%.2f) = %.4f",
      format(n_total, big.mark = ","), p_cov, seed, sigma0, rho, tau, q_eps
    )
  ) +
  theme_minimal(base_size = 14) +
  theme(
    plot.title = element_text(face = "bold", size = 18, color = "#111111"),
    plot.subtitle = element_text(size = 11, color = "#3A3A3A"),
    axis.title = element_text(face = "bold"),
    panel.grid.minor = element_blank(),
    panel.grid.major.x = element_line(color = "#E8E2D6", linewidth = 0.35),
    panel.grid.major.y = element_line(color = "#E8E2D6", linewidth = 0.35),
    plot.caption = element_text(hjust = 0, color = "#555555")
  )
ggsave(file.path(out_root, sprintf("shrinkage_gaussian_quantile_tau_%s.png", tau_tag)), plot = plt, width = 13.5, height = 8.5, dpi = 160)
ggsave(file.path(out_root, sprintf("shrinkage_gaussian_quantile_tau_%s.pdf", tau_tag)), plot = plt, width = 13.5, height = 8.5, dpi = 160)

sub_root <- write_quantile_specific_subsample(
  sim_output = sim_output,
  out_root = out_root,
  target_n = target_n,
  order_key = X_cov[, 1],
  sub_label = "xmain_sorted",
  series_wide = series_wide,
  series_long = series_long,
  extra_files = c("coef_truth.csv", "true_quantile_grid.csv")
)

writeLines(
  c(
    "Static homoskedastic Gaussian shrinkage scenario | quantile-specific",
    "---------------------------------------------------------------",
    sprintf("out root: %s", out_root),
    sprintf("target tau: %.2f", tau),
    sprintf("n_total: %d", n_total),
    sprintf("target_n: %d", target_n),
    sprintf("p_covariates: %d", p_cov),
    sprintf("sigma0: %.4f", sigma0),
    sprintf("rho: %.4f", rho),
    sprintf("seed: %d", seed),
    sprintf("noise quantile shift: %.8f", q_eps),
    "beta groups: strong, moderate, small, near_zero, zero",
    sprintf("saved fit_input_subsample: %s", sub_root)
  ),
  file.path(out_root, "meta.txt")
)

cat(sprintf("Prepared quantile-specific static shrinkage scenario under: %s\n", out_root))

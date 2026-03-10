#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(ggplot2)
})

source("tools/merge_reports/20260308_quantile_specific_sim_helpers.R")

tau <- resolve_target_tau(default = 0.50)
tau_tag <- tau_lab(tau)
base_root <- safe_chr(
  Sys.getenv("EXDQLM_SIMPLE_NORMAL_OUT_ROOT", "results/function_testing_20260306_static_simple_linear_normal_qspec"),
  "results/function_testing_20260306_static_simple_linear_normal_qspec"
)
out_root <- file.path(base_root, paste0("tau_", tau_tag))
n_total <- safe_int(Sys.getenv("EXDQLM_SIMPLE_NORMAL_N", "7000"), 7000L)
target_n <- safe_int(Sys.getenv("EXDQLM_SIMPLE_NORMAL_TARGET_N", "5000"), 5000L)
seed <- safe_int(Sys.getenv("EXDQLM_SIMPLE_NORMAL_SEED", "20260306"), 20260306L)
beta0 <- safe_num(Sys.getenv("EXDQLM_SIMPLE_NORMAL_BETA0", "1.0"), 1.0)
beta1 <- safe_num(Sys.getenv("EXDQLM_SIMPLE_NORMAL_BETA1", "2.0"), 2.0)
sigma0 <- safe_num(Sys.getenv("EXDQLM_SIMPLE_NORMAL_SIGMA", "1.0"), 1.0)
x_min <- safe_num(Sys.getenv("EXDQLM_SIMPLE_NORMAL_XMIN", "-2.0"), -2.0)
x_max <- safe_num(Sys.getenv("EXDQLM_SIMPLE_NORMAL_XMAX", "2.0"), 2.0)

if (n_total < 200L) stop("n_total must be at least 200")
if (target_n < 100L || target_n > n_total) stop("target_n must satisfy 100 <= target_n <= n_total")
if (!(sigma0 > 0)) stop("sigma must be positive")
if (!(x_max > x_min)) stop("x_max must be greater than x_min")
if (!(tau > 0 && tau < 1)) stop("tau must lie in (0,1)")

set.seed(seed)
x <- stats::runif(n_total, min = x_min, max = x_max)
mu_x <- beta0 + beta1 * x
sigma_x <- rep(sigma0, n_total)
q_eps <- stats::qnorm(tau)
z_raw <- stats::rnorm(n_total)
z_shift <- z_raw - q_eps
y <- mu_x + sigma_x * z_shift
q_true <- matrix(mu_x, ncol = 1)
colnames(q_true) <- sprintf("q_%03d", as.integer(round(100 * tau)))

X <- cbind(intercept = 1, x_main = x)
series_wide <- data.frame(
  row_id = seq_len(n_total),
  y = y,
  mu = mu_x,
  x_main = x,
  sigma = sigma_x,
  q_target = mu_x,
  stringsAsFactors = FALSE
)
series_long <- data.frame(
  row_id = seq_len(n_total),
  tau = tau,
  q = mu_x,
  y = y,
  mu = mu_x,
  x_main = x,
  sigma = sigma_x,
  stringsAsFactors = FALSE
)

x_grid <- seq(x_min, x_max, length.out = 1200L)
mu_grid <- beta0 + beta1 * x_grid
q_grid <- data.frame(x = x_grid, tau = tau, q = mu_grid, stringsAsFactors = FALSE)

sim_output <- make_quantile_specific_sim_output(
  y = y,
  tau = tau,
  q_true = q_true,
  info = list(
    scenario = "static_simple_linear_normal_homoskedastic_quantile_specific",
    params = list(
      beta0 = beta0,
      beta1 = beta1,
      sigma0 = sigma0,
      sigma_mode = "homoskedastic",
      sigma_const = sigma0,
      x_range = c(x_min, x_max),
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
    mu = mu_x,
    sigma = sigma_x,
    x_main = x,
    X = X,
    z_raw = z_raw,
    z_shift = z_shift,
    noise_family = "normal"
  )
)

dir.create(out_root, recursive = TRUE, showWarnings = FALSE)
utils::write.csv(series_wide, file.path(out_root, "series_wide.csv"), row.names = FALSE)
utils::write.csv(series_long, file.path(out_root, "series_long.csv"), row.names = FALSE)
utils::write.csv(q_grid, file.path(out_root, "true_quantile_grid.csv"), row.names = FALSE)
saveRDS(sim_output, file.path(out_root, "sim_output.rds"))
saveRDS(
  list(sample = data.frame(x = x, y = y, mu = mu_x, sigma = sigma_x, stringsAsFactors = FALSE), quantile_grid = q_grid),
  file.path(out_root, "sim_data.rds")
)
saveRDS(
  list(
    timestamp = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
    seed = seed,
    tau = tau,
    beta0 = beta0,
    beta1 = beta1,
    sigma0 = sigma0,
    x_min = x_min,
    x_max = x_max,
    n_total = n_total,
    target_n = target_n,
    truth_method = "exact_shifted_normal_closed_form",
    q_eps = q_eps
  ),
  file.path(out_root, "run_config.rds")
)

plt <- ggplot(data.frame(x = x, y = y), aes(x = x, y = y)) +
  geom_point(shape = 16, size = 1.0, alpha = 0.14, color = "#2A2F43") +
  geom_line(data = q_grid, aes(x = x, y = q), inherit.aes = FALSE, linewidth = 1.0, color = "#A63446") +
  labs(
    title = sprintf("Simple linear Gaussian DGP | quantile-specific tau = %.2f", tau),
    subtitle = "Noise shifted so the target conditional quantile equals the linear signal",
    x = "x_main",
    y = "y",
    caption = sprintf(
      "n = %s, seed = %d | beta0 = %.2f, beta1 = %.2f, sigma = %.2f | shifted by qnorm(%.2f) = %.4f",
      format(n_total, big.mark = ","), seed, beta0, beta1, sigma0, tau, q_eps
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
ggplot2::ggsave(file.path(out_root, sprintf("simple_linear_normal_quantile_tau_%s.png", tau_tag)), plot = plt, width = 13.5, height = 8.5, dpi = 160)
ggplot2::ggsave(file.path(out_root, sprintf("simple_linear_normal_quantile_tau_%s.pdf", tau_tag)), plot = plt, width = 13.5, height = 8.5, dpi = 160)

sub_root <- write_quantile_specific_subsample(
  sim_output = sim_output,
  out_root = out_root,
  target_n = target_n,
  order_key = x,
  sub_label = "xmain_sorted",
  series_wide = series_wide,
  series_long = series_long,
  extra_files = c("true_quantile_grid.csv")
)

writeLines(
  c(
    "Simple quantile-specific Gaussian static simulation",
    "-----------------------------------------------",
    sprintf("out root: %s", out_root),
    sprintf("target tau: %.2f", tau),
    sprintf("n_total: %d", n_total),
    sprintf("target_n: %d", target_n),
    sprintf("seed: %d", seed),
    sprintf("beta0: %.6f", beta0),
    sprintf("beta1: %.6f", beta1),
    sprintf("sigma: %.6f", sigma0),
    sprintf("noise quantile shift: %.8f", q_eps),
    "truth method: exact_shifted_normal_closed_form",
    sprintf("saved fit_input_subsample: %s", sub_root)
  ),
  file.path(out_root, "meta.txt")
)

cat(sprintf("Generated quantile-specific simple Gaussian static scenario under: %s\n", out_root))

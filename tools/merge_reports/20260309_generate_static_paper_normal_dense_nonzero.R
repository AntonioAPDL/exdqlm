#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(ggplot2)
  library(mvtnorm)
})

source("tools/merge_reports/20260308_quantile_specific_sim_helpers.R")

tau <- resolve_target_tau(default = 0.05)
tau_tag <- tau_lab(tau)
base_root <- safe_chr(
  Sys.getenv(
    "EXDQLM_PAPER_NORMAL_DENSE_OUT_ROOT",
    "results/function_testing_20260309_static_paper_normal_dense_nonzero_qspec"
  ),
  "results/function_testing_20260309_static_paper_normal_dense_nonzero_qspec"
)
out_root <- file.path(base_root, paste0("tau_", tau_tag))
n_total <- safe_int(Sys.getenv("EXDQLM_PAPER_NORMAL_DENSE_N", "1000"), 1000L)
target_n <- safe_int(Sys.getenv("EXDQLM_PAPER_NORMAL_DENSE_TARGET_N", as.character(n_total)), n_total)
seed <- safe_int(Sys.getenv("EXDQLM_PAPER_NORMAL_DENSE_SEED", "20260309"), 20260309L)
sigma0 <- safe_num(Sys.getenv("EXDQLM_PAPER_NORMAL_DENSE_SIGMA", "3.0"), 3.0)
beta_vec <- safe_num_vec(
  Sys.getenv("EXDQLM_PAPER_NORMAL_DENSE_BETA", "3,1.5,1.0,0.75,2,0.5,0.35,0.2"),
  default = c(3, 1.5, 1.0, 0.75, 2.0, 0.5, 0.35, 0.2),
  length_out = 8L
)

if (n_total < 100L) stop("n_total must be at least 100")
if (target_n < 100L || target_n > n_total) stop("target_n must satisfy 100 <= target_n <= n_total")
if (!(sigma0 > 0)) stop("sigma must be positive")
if (!(tau > 0 && tau < 1)) stop("tau must lie in (0,1)")

cov_mat <- 0.5 ^ abs(outer(seq_len(8L), seq_len(8L), "-"))
colnames(cov_mat) <- rownames(cov_mat) <- paste0("x", seq_len(8L))

set.seed(seed)
X <- mvtnorm::rmvnorm(n_total, sigma = cov_mat)
colnames(X) <- paste0("x", seq_len(ncol(X)))
mu_x <- as.numeric(drop(X %*% beta_vec))
q_eps <- stats::qnorm(tau)
z_raw <- stats::rnorm(n_total)
z_shift <- z_raw - q_eps
y <- mu_x + sigma0 * z_shift
q_true <- matrix(mu_x, ncol = 1L)
colnames(q_true) <- sprintf("q_%03d", as.integer(round(100 * tau)))

series_wide <- data.frame(
  row_id = seq_len(n_total),
  y = y,
  mu = mu_x,
  q_target = mu_x,
  x_main = X[, 1],
  sigma = sigma0,
  X,
  stringsAsFactors = FALSE
)
series_long <- data.frame(
  row_id = seq_len(n_total),
  tau = tau,
  q = mu_x,
  y = y,
  mu = mu_x,
  x_main = X[, 1],
  sigma = sigma0,
  stringsAsFactors = FALSE
)
q_grid <- data.frame(
  obs_id = seq_len(n_total),
  q_true = mu_x,
  stringsAsFactors = FALSE
)

sim_output <- make_quantile_specific_sim_output(
  y = y,
  tau = tau,
  q_true = q_true,
  info = list(
    scenario = "static_paper_normal_dense_nonzero_quantile_specific",
    params = list(
      beta = beta_vec,
      sigma0 = sigma0,
      n = n_total,
      p = ncol(X),
      covariance_scheme = "0.5^|i-j|",
      noise_family = "normal",
      paper_reference = "UCSC-SOE-24-01 section 4.1",
      variant = "dense_nonzero_coefficients"
    ),
    seed = seed,
    quantile_truth_method = "exact_shifted_normal_closed_form",
    quantile_target = tau,
    noise_quantile_shift = q_eps
  ),
  extras = list(
    mu = mu_x,
    sigma = rep(sigma0, n_total),
    x_main = X[, 1],
    X = X,
    z_raw = z_raw,
    z_shift = z_shift,
    beta_true = beta_vec,
    cov_mat = cov_mat,
    display_var = "x1",
    display_signal = mu_x,
    noise_family = "normal"
  )
)

dir.create(out_root, recursive = TRUE, showWarnings = FALSE)
utils::write.csv(series_wide, file.path(out_root, "series_wide.csv"), row.names = FALSE)
utils::write.csv(series_long, file.path(out_root, "series_long.csv"), row.names = FALSE)
utils::write.csv(q_grid, file.path(out_root, "true_quantile_by_obs.csv"), row.names = FALSE)
utils::write.csv(
  data.frame(term = colnames(X), beta_true = beta_vec, stringsAsFactors = FALSE),
  file.path(out_root, "true_beta.csv"),
  row.names = FALSE
)
utils::write.csv(
  as.data.frame(cov_mat),
  file.path(out_root, "covariance_matrix.csv"),
  row.names = TRUE
)
saveRDS(sim_output, file.path(out_root, "sim_output.rds"))
saveRDS(
  list(
    sample = data.frame(x1 = X[, 1], y = y, mu = mu_x, stringsAsFactors = FALSE),
    beta_true = beta_vec,
    cov_mat = cov_mat
  ),
  file.path(out_root, "sim_data.rds")
)
saveRDS(
  list(
    timestamp = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
    seed = seed,
    tau = tau,
    sigma0 = sigma0,
    beta_true = beta_vec,
    n_total = n_total,
    target_n = target_n,
    truth_method = "exact_shifted_normal_closed_form",
    q_eps = q_eps,
    covariance_scheme = "0.5^|i-j|",
    source_design = "paper_style_normal_dense_nonzero"
  ),
  file.path(out_root, "run_config.rds")
)

obs_order <- order(mu_x, X[, 1])
plot_df <- data.frame(
  obs_id = seq_len(n_total),
  y = y[obs_order],
  q_true = mu_x[obs_order],
  x1 = X[obs_order, 1],
  stringsAsFactors = FALSE
)

plt <- ggplot(plot_df, aes(x = obs_id)) +
  geom_point(aes(y = y), shape = 16, size = 0.9, alpha = 0.18, color = "#2A2F43") +
  geom_line(aes(y = q_true), linewidth = 1.0, color = "#A63446") +
  labs(
    title = sprintf("Paper-style normal benchmark | dense beta | tau = %.2f", tau),
    subtitle = "Normal noise shifted so the target conditional quantile equals X beta",
    x = "observation index sorted by true quantile",
    y = "y / true target quantile",
    caption = sprintf(
      "n = %d | sigma = %.2f | covariance = 0.5^|i-j| | qnorm(%.2f) shift = %.4f",
      n_total, sigma0, tau, q_eps
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
ggplot2::ggsave(file.path(out_root, sprintf("paper_normal_dense_quantile_tau_%s.png", tau_tag)), plot = plt, width = 13.5, height = 8.5, dpi = 160)
ggplot2::ggsave(file.path(out_root, sprintf("paper_normal_dense_quantile_tau_%s.pdf", tau_tag)), plot = plt, width = 13.5, height = 8.5, dpi = 160)

sub_root <- write_quantile_specific_subsample(
  sim_output = sim_output,
  out_root = out_root,
  target_n = target_n,
  order_key = mu_x,
  sub_label = "mu_sorted",
  series_wide = series_wide,
  series_long = series_long,
  extra_files = c("true_quantile_by_obs.csv", "true_beta.csv", "covariance_matrix.csv")
)

writeLines(
  c(
    "Paper-style normal dense-nonzero static simulation",
    "------------------------------------------------",
    sprintf("out root: %s", out_root),
    sprintf("target tau: %.2f", tau),
    sprintf("n_total: %d", n_total),
    sprintf("target_n: %d", target_n),
    sprintf("seed: %d", seed),
    sprintf("sigma: %.6f", sigma0),
    sprintf("beta_true: %s", paste(format(beta_vec, digits = 6), collapse = ", ")),
    "covariance scheme: 0.5^|i-j|",
    sprintf("noise quantile shift: %.8f", q_eps),
    "truth method: exact_shifted_normal_closed_form",
    sprintf("saved fit_input_subsample: %s", sub_root)
  ),
  file.path(out_root, "meta.txt")
)

cat(sprintf("Generated paper-style dense normal static scenario under: %s\n", out_root))

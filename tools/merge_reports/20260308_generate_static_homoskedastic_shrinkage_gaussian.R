#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(ggplot2)
})

safe_int <- function(x, default) {
  v <- suppressWarnings(as.integer(x)[1])
  if (!is.finite(v) || is.na(v)) default else v
}

safe_num <- function(x, default) {
  v <- suppressWarnings(as.numeric(x)[1])
  if (!is.finite(v) || is.na(v)) default else v
}

safe_chr <- function(x, default) {
  v <- as.character(x)[1]
  if (!nzchar(v) || is.na(v)) default else v
}

systematic_rank_subsample <- function(x, target_n) {
  n <- length(x)
  if (target_n >= n) return(seq_len(n))
  pos <- floor(seq(0, n - 1, length.out = target_n)) + 1L
  pos <- unique(pos)
  if (length(pos) < target_n) {
    fill <- setdiff(seq_len(n), pos)
    pos <- c(pos, fill[seq_len(target_n - length(pos))])
    pos <- sort(pos)
  }
  pos[seq_len(target_n)]
}

compose_quantiles <- function(mu, sigma, q_std) {
  sweep(
    matrix(rep(q_std, each = length(mu)), nrow = length(mu)),
    1L,
    sigma,
    `*`
  ) + mu
}

out_root <- safe_chr(
  Sys.getenv(
    "EXDQLM_STATIC_SHRINK_OUT_ROOT",
    "results/function_testing_20260308_static_homoskedastic_shrinkage_gaussian"
  ),
  "results/function_testing_20260308_static_homoskedastic_shrinkage_gaussian"
)
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
if (!(rho >= 0 && rho < 1)) stop("rho must lie in [0, 1)")

set.seed(seed)

p_levels <- seq(0.05, 0.95, by = 0.05)
q_std <- stats::qnorm(p_levels)
p_names <- sprintf("%.2f", p_levels)
feature_names <- sprintf("x%02d", seq_along(beta_slopes))
coef_names <- c("(Intercept)", feature_names)

p_cov <- length(beta_slopes)
Sigma_x <- outer(seq_len(p_cov), seq_len(p_cov), function(i, j) rho ^ abs(i - j))
Z <- matrix(stats::rnorm(n_total * p_cov), nrow = n_total, ncol = p_cov)
X_raw <- Z %*% chol(Sigma_x)
X_cov <- scale(X_raw)
colnames(X_cov) <- feature_names
X <- cbind("(Intercept)" = 1, X_cov)

mu_x <- as.numeric(beta0 + X_cov %*% beta_slopes)
sigma_x <- rep(sigma0, n_total)
z_std <- stats::rnorm(n_total)
y <- mu_x + sigma_x * z_std
q_obs <- compose_quantiles(mu_x, sigma_x, q_std)
colnames(q_obs) <- sprintf("q_%03d", as.integer(round(100 * p_levels)))

beta_by_tau <- vapply(
  p_levels,
  function(tau) {
    c(beta0 + stats::qnorm(tau) * sigma0, beta_slopes)
  },
  numeric(length(coef_names))
)
rownames(beta_by_tau) <- coef_names
colnames(beta_by_tau) <- p_names

coef_truth <- do.call(
  rbind,
  lapply(seq_along(p_levels), function(j) {
    tau <- p_levels[j]
    data.frame(
      tau = tau,
      term = coef_names,
      beta_truth = beta_by_tau[, j],
      group = c("intercept", coef_groups),
      abs_truth = abs(beta_by_tau[, j]),
      is_zero = c(FALSE, beta_slopes == 0),
      is_near_zero = c(FALSE, abs(beta_slopes) > 0 & abs(beta_slopes) < 0.10),
      is_signal = c(FALSE, abs(beta_slopes) >= 0.10),
      stringsAsFactors = FALSE
    )
  })
)

series_wide <- data.frame(
  row_id = seq_len(n_total),
  y = y,
  mu = mu_x,
  x_main = X_cov[, 1],
  sigma = sigma_x,
  stringsAsFactors = FALSE
)
series_wide <- cbind(series_wide, as.data.frame(X_cov, check.names = FALSE), as.data.frame(q_obs, check.names = FALSE))

series_long <- do.call(
  rbind,
  lapply(seq_along(p_levels), function(j) {
    data.frame(
      row_id = seq_len(n_total),
      tau = p_levels[j],
      y = y,
      q = q_obs[, j],
      mu = mu_x,
      x_main = X_cov[, 1],
      sigma = sigma_x,
      stringsAsFactors = FALSE
    )
  })
)

x_main_grid <- seq(
  quantile(X_cov[, 1], probs = 0.01),
  quantile(X_cov[, 1], probs = 0.99),
  length.out = 1200L
)
mu_grid <- beta0 + beta_slopes[1] * x_main_grid
q_grid_mat <- compose_quantiles(mu_grid, rep(sigma0, length(x_main_grid)), q_std)
q_grid <- do.call(
  rbind,
  lapply(seq_along(p_levels), function(j) {
    data.frame(
      x_main = x_main_grid,
      tau = p_levels[j],
      q = q_grid_mat[, j],
      stringsAsFactors = FALSE
    )
  })
)

sim_output <- list(
  y = y,
  q = q_obs,
  p = p_levels,
  info = list(
    scenario = "static_homoskedastic_gaussian_shrinkage",
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
    quantile_truth_method = "exact_normal_closed_form"
  ),
  extras = list(
    X = X,
    x_main = as.numeric(X_cov[, 1]),
    mu = mu_x,
    sigma = sigma_x,
    q_std = q_std,
    noise_family = "normal",
    z_std = z_std,
    coef_truth = coef_truth,
    beta_mean = c(beta0, beta_slopes),
    beta_by_tau = beta_by_tau,
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
    beta0 = beta0,
    beta_slopes = beta_slopes,
    sigma0 = sigma0,
    rho = rho,
    n_total = n_total,
    target_n = target_n,
    truth_method = "exact_normal_closed_form"
  ),
  file.path(out_root, "run_config.rds")
)

sample_df <- data.frame(
  x_main = pmin(pmax(X_cov[, 1], -x_main_clip), x_main_clip),
  y = y,
  stringsAsFactors = FALSE
)
ribbon_df <- data.frame(
  x_main = x_main_grid,
  q05 = q_grid_mat[, which.min(abs(p_levels - 0.05))],
  q50 = q_grid_mat[, which.min(abs(p_levels - 0.50))],
  q95 = q_grid_mat[, which.min(abs(p_levels - 0.95))],
  mu = mu_grid,
  stringsAsFactors = FALSE
)

plt <- ggplot(sample_df, aes(x = x_main, y = y)) +
  geom_ribbon(data = ribbon_df, aes(x = x_main, ymin = q05, ymax = q95), inherit.aes = FALSE,
              fill = "#B7D1C4", alpha = 0.24) +
  geom_point(shape = 16, size = 0.95, alpha = 0.13, color = "#1F2A44") +
  geom_line(data = ribbon_df, aes(x = x_main, y = q05), inherit.aes = FALSE, color = "#A63446", linewidth = 0.9) +
  geom_line(data = ribbon_df, aes(x = x_main, y = q50), inherit.aes = FALSE, color = "#111111", linewidth = 1.0) +
  geom_line(data = ribbon_df, aes(x = x_main, y = q95), inherit.aes = FALSE, color = "#2B59C3", linewidth = 0.9) +
  geom_line(data = ribbon_df, aes(x = x_main, y = mu), inherit.aes = FALSE, color = "#6D597A", linewidth = 0.9, linetype = "22") +
  labs(
    title = "Static homoskedastic Gaussian shrinkage DGP",
    subtitle = "Correlated covariates with strong, weak, near-zero, and exact-zero coefficients",
    x = "x01",
    y = "y",
    caption = sprintf(
      "n = %s, p = %d, seed = %d | sigma = %.2f, rho = %.2f | dashed line = conditional mean along x01",
      format(n_total, big.mark = ","),
      p_cov,
      seed,
      sigma0,
      rho
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

ggsave(file.path(out_root, "shrinkage_gaussian_quantiles.png"), plot = plt, width = 13.5, height = 8.5, dpi = 160)
ggsave(file.path(out_root, "shrinkage_gaussian_quantiles.pdf"), plot = plt, width = 13.5, height = 8.5, dpi = 160)

ord <- order(X_cov[, 1], seq_len(n_total))
idx <- ord[systematic_rank_subsample(X_cov[ord, 1], target_n)]
sub_root <- file.path(out_root, sprintf("fit_input_subsample_tt%d_xmain_sorted", target_n))
dir.create(sub_root, recursive = TRUE, showWarnings = FALSE)

subset_sim <- sim_output
subset_sim$y <- as.numeric(sim_output$y[idx])
subset_sim$q <- as.matrix(sim_output$q[idx, , drop = FALSE])
subset_sim$extras$X <- as.matrix(sim_output$extras$X[idx, , drop = FALSE])
subset_sim$extras$x_main <- as.numeric(sim_output$extras$x_main[idx])
subset_sim$extras$mu <- as.numeric(sim_output$extras$mu[idx])
subset_sim$extras$sigma <- as.numeric(sim_output$extras$sigma[idx])
subset_sim$extras$z_std <- as.numeric(sim_output$extras$z_std[idx])
subset_sim$extras$source_index <- as.integer(idx)
subset_sim$extras$source_n <- as.integer(n_total)
subset_sim$info$subsample <- list(
  source_root = out_root,
  source_n = as.integer(n_total),
  target_n = as.integer(target_n),
  selection_method = "systematic_rank_x01",
  sorted_by = "x01"
)
if (!is.null(subset_sim$info$params$n)) subset_sim$info$params$n <- as.integer(target_n)

saveRDS(subset_sim, file.path(sub_root, "sim_output.rds"))
write.csv(series_wide[idx, , drop = FALSE], file.path(sub_root, "series_wide.csv"), row.names = FALSE)
write.csv(series_long[series_long$row_id %in% idx, , drop = FALSE], file.path(sub_root, "series_long.csv"), row.names = FALSE)
write.csv(data.frame(row_id = seq_along(idx), source_index = idx, x_main = X_cov[idx, 1]), file.path(sub_root, "selection_indices.csv"), row.names = FALSE)
file.copy(file.path(out_root, "coef_truth.csv"), file.path(sub_root, "coef_truth.csv"), overwrite = TRUE)
file.copy(file.path(out_root, "true_quantile_grid.csv"), file.path(sub_root, "true_quantile_grid.csv"), overwrite = TRUE)

meta_lines <- c(
  "Static homoskedastic Gaussian shrinkage scenario",
  "-----------------------------------------------",
  sprintf("scenario_root: %s", out_root),
  sprintf("n_total: %d", n_total),
  sprintf("target_n: %d", target_n),
  sprintf("p_covariates: %d", p_cov),
  sprintf("sigma0: %.4f", sigma0),
  sprintf("rho: %.4f", rho),
  sprintf("seed: %d", seed),
  "beta groups: strong, moderate, small, near_zero, zero",
  sprintf("saved sim_output.rds: %s", file.path(out_root, "sim_output.rds")),
  sprintf("saved fit_input_subsample: %s", sub_root)
)
writeLines(meta_lines, file.path(out_root, "meta.txt"))

cat(sprintf("Prepared static shrinkage scenario under: %s\n", out_root))

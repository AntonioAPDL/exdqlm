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
    "EXDQLM_SIMPLE_NORMAL_OUT_ROOT",
    "results/function_testing_20260306_static_simple_linear_normal"
  ),
  "results/function_testing_20260306_static_simple_linear_normal"
)
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

set.seed(seed)

p_levels <- seq(0.05, 0.95, by = 0.05)
q_std <- stats::qnorm(p_levels)
names(q_std) <- sprintf("%.2f", p_levels)

x <- stats::runif(n_total, min = x_min, max = x_max)
mu_x <- beta0 + beta1 * x
sigma_x <- rep(sigma0, n_total)
z_std <- stats::rnorm(n_total)
y <- mu_x + sigma_x * z_std
q_obs <- compose_quantiles(mu_x, sigma_x, q_std)
q_names <- sprintf("q_%03d", as.integer(round(100 * p_levels)))
colnames(q_obs) <- q_names

X <- cbind(intercept = 1, x_main = x)
t_idx <- seq_len(n_total)

series_wide <- data.frame(
  t = t_idx,
  y = y,
  mu = mu_x,
  x_main = x,
  sigma = sigma_x,
  stringsAsFactors = FALSE
)
series_wide <- cbind(series_wide, as.data.frame(q_obs, check.names = FALSE))

series_long <- do.call(
  rbind,
  lapply(seq_along(p_levels), function(j) {
    data.frame(
      t = t_idx,
      p = p_levels[j],
      q = q_obs[, j],
      y = y,
      mu = mu_x,
      x_main = x,
      sigma = sigma_x,
      stringsAsFactors = FALSE
    )
  })
)

x_grid <- seq(x_min, x_max, length.out = 1200L)
mu_grid <- beta0 + beta1 * x_grid
sigma_grid <- rep(sigma0, length(x_grid))
q_grid_mat <- compose_quantiles(mu_grid, sigma_grid, q_std)
q_grid <- do.call(
  rbind,
  lapply(seq_along(p_levels), function(j) {
    data.frame(
      x = x_grid,
      p = p_levels[j],
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
    scenario = "static_simple_linear_normal_homoskedastic",
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
    quantile_truth_method = "exact_normal_closed_form"
  ),
  extras = list(
    mu = mu_x,
    sigma = sigma_x,
    x_main = x,
    q_std = q_std,
    noise_family = "normal",
    X = X,
    z_std = z_std
  )
)

dir.create(out_root, recursive = TRUE, showWarnings = FALSE)
utils::write.csv(series_wide, file.path(out_root, "series_wide.csv"), row.names = FALSE)
utils::write.csv(series_long, file.path(out_root, "series_long.csv"), row.names = FALSE)
utils::write.csv(q_grid, file.path(out_root, "true_quantile_grid.csv"), row.names = FALSE)
saveRDS(sim_output, file.path(out_root, "sim_output.rds"))
saveRDS(
  list(
    sample = data.frame(x = x, y = y, mu = mu_x, sigma = sigma_x, stringsAsFactors = FALSE),
    quantile_grid = q_grid
  ),
  file.path(out_root, "sim_data.rds")
)
saveRDS(
  list(
    timestamp = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
    seed = seed,
    beta0 = beta0,
    beta1 = beta1,
    sigma0 = sigma0,
    x_min = x_min,
    x_max = x_max,
    n_total = n_total,
    target_n = target_n,
    truth_method = "exact_normal_closed_form"
  ),
  file.path(out_root, "run_config.rds")
)

sample_df <- data.frame(x = x, y = y, stringsAsFactors = FALSE)
ribbon_df <- data.frame(
  x = x_grid,
  q05 = q_grid_mat[, which.min(abs(p_levels - 0.05))],
  q25 = q_grid_mat[, which.min(abs(p_levels - 0.25))],
  q50 = q_grid_mat[, which.min(abs(p_levels - 0.50))],
  q75 = q_grid_mat[, which.min(abs(p_levels - 0.75))],
  q95 = q_grid_mat[, which.min(abs(p_levels - 0.95))],
  mu = mu_grid,
  stringsAsFactors = FALSE
)
q_grid$p_lab <- factor(sprintf("p = %.2f", q_grid$p), levels = sprintf("p = %.2f", p_levels))
line_cols <- setNames(
  grDevices::colorRampPalette(c("#A63446", "#D17B0F", "#E5C84B", "#111111", "#1E8E89", "#2B59C3"))(length(p_levels)),
  levels(q_grid$p_lab)
)

plt <- ggplot(sample_df, aes(x = x, y = y)) +
  geom_ribbon(data = ribbon_df, aes(x = x, ymin = q05, ymax = q95), inherit.aes = FALSE, fill = "#A9C5A0", alpha = 0.22) +
  geom_ribbon(data = ribbon_df, aes(x = x, ymin = q25, ymax = q75), inherit.aes = FALSE, fill = "#6BA292", alpha = 0.26) +
  geom_point(shape = 16, size = 1.0, alpha = 0.14, color = "#2A2F43") +
  geom_line(data = q_grid, aes(y = q, color = p_lab), linewidth = 0.85, alpha = 0.95) +
  geom_line(data = ribbon_df, aes(x = x, y = mu), inherit.aes = FALSE, linewidth = 1.0, linetype = "22", color = "#5C4B51") +
  scale_color_manual(values = line_cols, name = "True conditional quantiles") +
  labs(
    title = "Simple linear Gaussian DGP",
    subtitle = "Single covariate, homoskedastic normal noise, exact conditional quantiles",
    x = "x_main",
    y = "y",
    caption = sprintf(
      "n = %s, seed = %d | beta0 = %.2f, beta1 = %.2f, sigma = %.2f | dashed line = conditional mean",
      format(n_total, big.mark = ","),
      seed,
      beta0,
      beta1,
      sigma0
    )
  ) +
  coord_cartesian(expand = FALSE) +
  theme_minimal(base_size = 14) +
  theme(
    plot.title = element_text(face = "bold", size = 18, color = "#111111"),
    plot.subtitle = element_text(size = 11, color = "#3A3A3A"),
    axis.title = element_text(face = "bold"),
    panel.grid.minor = element_blank(),
    panel.grid.major.x = element_line(color = "#E8E2D6", linewidth = 0.35),
    panel.grid.major.y = element_line(color = "#E8E2D6", linewidth = 0.35),
    legend.position = c(0.03, 0.98),
    legend.justification = c(0, 1),
    legend.background = element_rect(fill = grDevices::adjustcolor("white", alpha.f = 0.82), color = NA),
    legend.title = element_text(face = "bold"),
    legend.key.height = grid::unit(0.32, "cm"),
    legend.text = element_text(size = 8.5),
    plot.caption = element_text(hjust = 0, color = "#555555")
  )

ggplot2::ggsave(file.path(out_root, "simple_linear_normal_quantiles.png"), plot = plt, width = 13.5, height = 8.5, dpi = 160)
ggplot2::ggsave(file.path(out_root, "simple_linear_normal_quantiles.pdf"), plot = plt, width = 13.5, height = 8.5, dpi = 160)

ord <- order(x, seq_along(x))
idx <- ord[systematic_rank_subsample(x[ord], target_n)]
sub_root <- file.path(out_root, sprintf("fit_input_subsample_tt%d_xmain_sorted", target_n))
dir.create(sub_root, recursive = TRUE, showWarnings = FALSE)

subset_sim <- sim_output
subset_sim$y <- as.numeric(sim_output$y[idx])
subset_sim$q <- as.matrix(sim_output$q[idx, , drop = FALSE])
subset_sim$extras$mu <- as.numeric(sim_output$extras$mu[idx])
subset_sim$extras$sigma <- as.numeric(sim_output$extras$sigma[idx])
subset_sim$extras$x_main <- as.numeric(sim_output$extras$x_main[idx])
subset_sim$extras$X <- as.matrix(sim_output$extras$X[idx, , drop = FALSE])
subset_sim$extras$z_std <- as.numeric(sim_output$extras$z_std[idx])
subset_sim$extras$source_index <- as.integer(idx)
subset_sim$extras$source_n <- as.integer(n_total)
subset_sim$info$subsample <- list(
  source_root = out_root,
  source_n = as.integer(n_total),
  target_n = as.integer(target_n),
  selection_method = "systematic_rank_x_main",
  sorted_by = "x_main"
)
subset_sim$info$params$n <- as.integer(target_n)

series_wide_sub <- series_wide[idx, , drop = FALSE]
series_long_sub <- do.call(
  rbind,
  lapply(seq_along(p_levels), function(j) {
    data.frame(
      row_id = seq_len(target_n),
      source_index = as.integer(idx),
      x_main = subset_sim$extras$x_main,
      y = subset_sim$y,
      p = subset_sim$p[j],
      q = subset_sim$q[, j],
      stringsAsFactors = FALSE
    )
  })
)
selection_df <- data.frame(
  row_id = seq_len(target_n),
  source_index = as.integer(idx),
  x_main = subset_sim$extras$x_main,
  stringsAsFactors = FALSE
)

utils::write.csv(series_wide_sub, file.path(sub_root, "series_wide.csv"), row.names = FALSE)
utils::write.csv(series_long_sub, file.path(sub_root, "series_long.csv"), row.names = FALSE)
utils::write.csv(selection_df, file.path(sub_root, "selection_indices.csv"), row.names = FALSE)
utils::write.csv(q_grid, file.path(sub_root, "true_quantile_grid.csv"), row.names = FALSE)
saveRDS(subset_sim, file.path(sub_root, "sim_output.rds"))

writeLines(
  c(
    "Simple static Gaussian fit input subsample",
    "----------------------------------------",
    sprintf("source root: %s", out_root),
    sprintf("source n: %d", n_total),
    sprintf("target n: %d", target_n),
    "selection method: systematic_rank_x_main",
    "ordering: x_main ascending after selection",
    "truth method: exact_normal_closed_form"
  ),
  file.path(sub_root, "meta.txt")
)

writeLines(
  c(
    "Simple linear Gaussian static simulation",
    "--------------------------------------",
    sprintf("out root: %s", out_root),
    sprintf("n_total: %d", n_total),
    sprintf("target_n: %d", target_n),
    sprintf("seed: %d", seed),
    sprintf("beta0: %.6f", beta0),
    sprintf("beta1: %.6f", beta1),
    sprintf("sigma: %.6f", sigma0),
    sprintf("x range: [%.3f, %.3f]", x_min, x_max),
    "truth method: exact_normal_closed_form"
  ),
  file.path(out_root, "meta.txt")
)

cat(sprintf("Generated simple linear Gaussian static scenario under: %s\n", out_root))

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

rskewnorm_std <- function(n, shape) {
  delta <- shape / sqrt(1 + shape^2)
  z_raw <- delta * abs(stats::rnorm(n)) + sqrt(1 - delta^2) * stats::rnorm(n)
  mu_z <- delta * sqrt(2 / pi)
  sd_z <- sqrt(1 - 2 * delta^2 / pi)
  (z_raw - mu_z) / sd_z
}

draw_std_noise <- function(n, family, shape) {
  if (family == "normal") {
    stats::rnorm(n)
  } else if (family == "skew_normal") {
    rskewnorm_std(n, shape)
  } else {
    stop("Unsupported noise_family: ", family)
  }
}

compose_quantiles <- function(mu, sigma, q_std) {
  sweep(
    sweep(matrix(rep(q_std, each = length(mu)), nrow = length(mu)), 1L, sigma, `*`),
    1L, mu, `+`
  )
}

n <- safe_int(Sys.getenv("EXDQLM_HET_N", "7000"), 7000L)
seed <- safe_int(Sys.getenv("EXDQLM_HET_SEED", "20260306"), 20260306L)
beta0 <- safe_num(Sys.getenv("EXDQLM_HET_BETA0", "2.0"), 2.0)
beta1 <- safe_num(Sys.getenv("EXDQLM_HET_BETA1", "0.22"), 0.22)
sigma0 <- safe_num(Sys.getenv("EXDQLM_HET_SIGMA0", "0.5"), 0.5)
x_min <- safe_num(Sys.getenv("EXDQLM_HET_X_MIN", "0"), 0)
x_max <- safe_num(Sys.getenv("EXDQLM_HET_X_MAX", "50"), 50)
grid_n <- safe_int(Sys.getenv("EXDQLM_HET_GRID_N", "1200"), 1200L)
cos_scale <- safe_num(Sys.getenv("EXDQLM_HET_COS_SCALE", "4.0"), 4.0)
cos_amp <- safe_num(Sys.getenv("EXDQLM_HET_COS_AMP", "10.0"), 10.0)
hetero_mult <- safe_num(Sys.getenv("EXDQLM_HET_HETERO_MULT", "0.005"), 0.005)
hetero_power <- safe_num(Sys.getenv("EXDQLM_HET_HETERO_POWER", "4.0"), 4.0)
noise_family <- tolower(Sys.getenv("EXDQLM_HET_NOISE_FAMILY", "normal"))
skew_shape <- safe_num(Sys.getenv("EXDQLM_HET_SKEW_SHAPE", "12.0"), 12.0)
R_mc <- safe_int(Sys.getenv("EXDQLM_HET_R_MC", "200000"), 200000L)
out_root <- Sys.getenv(
  "EXDQLM_HET_OUT",
  "results/function_testing_20260306_static_heteroskedastic_cosine"
)

if (n < 100L) stop("n must be at least 100")
if (!is.finite(sigma0) || sigma0 <= 0) stop("sigma0 must be > 0")
if (!is.finite(x_min) || !is.finite(x_max) || x_min >= x_max) stop("Invalid x range")
if (grid_n < 200L) stop("grid_n must be at least 200")
if (!is.finite(cos_scale) || cos_scale <= 0) stop("cos_scale must be > 0")
if (!is.finite(cos_amp) || cos_amp <= 0) stop("cos_amp must be > 0")
if (!is.finite(hetero_mult) || hetero_mult <= 0) stop("hetero_mult must be > 0")
if (!is.finite(hetero_power) || hetero_power <= 0) stop("hetero_power must be > 0")
if (!(noise_family %in% c("normal", "skew_normal"))) stop("noise_family must be 'normal' or 'skew_normal'")
if (!is.finite(skew_shape)) stop("skew_shape must be finite")
if (!is.finite(R_mc) || R_mc < 1000L) stop("R_mc must be at least 1000")

g_fun <- function(x) cos_amp * cos(x / cos_scale) + x
mu_fun <- function(x) beta0 + beta1 * g_fun(x)
sigma_fun <- function(x) sigma0 * sqrt(log(hetero_mult * abs(x)^hetero_power + 1))

p_levels <- seq(0.05, 0.95, by = 0.05)
p_int <- pmin(pmax(as.integer(round(100 * p_levels)), 0L), 999L)
q_names <- sprintf("q_%03d", p_int)

set.seed(seed)
x <- stats::runif(n, min = x_min, max = x_max)
t_idx <- seq_len(n)
cos_term <- cos_amp * cos(x / cos_scale)
mu_x <- mu_fun(x)
sigma_x <- sigma_fun(x)

set.seed(seed + 1L)
q_std <- if (noise_family == "normal") {
  stats::qnorm(p_levels)
} else {
  as.numeric(stats::quantile(
    draw_std_noise(R_mc, family = noise_family, shape = skew_shape),
    probs = p_levels,
    names = FALSE,
    type = 8
  ))
}
names(q_std) <- sprintf("%.2f", p_levels)

set.seed(seed + 2L)
y <- mu_x + sigma_x * draw_std_noise(n, family = noise_family, shape = skew_shape)

q_obs <- compose_quantiles(mu_x, sigma_x, q_std)
colnames(q_obs) <- q_names

series_wide <- data.frame(
  t = t_idx,
  y = y,
  mu = mu_x,
  x_main = x,
  cos_term = cos_term,
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
      cos_term = cos_term,
      stringsAsFactors = FALSE
    )
  })
)

x_grid <- seq(x_min, x_max, length.out = grid_n)
mu_grid <- mu_fun(x_grid)
sigma_grid <- sigma_fun(x_grid)
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
q_grid$p_lab <- factor(
  sprintf("p = %.2f", q_grid$p),
  levels = sprintf("p = %.2f", p_levels)
)

sample_df <- data.frame(
  x = x,
  y = y,
  mu = mu_x,
  sigma = sigma_x,
  cos_term = cos_term,
  stringsAsFactors = FALSE
)

ribbon_df <- data.frame(
  x = x_grid,
  q05 = q_grid_mat[, which.min(abs(p_levels - 0.05))],
  q25 = q_grid_mat[, which.min(abs(p_levels - 0.25))],
  q50 = q_grid_mat[, which.min(abs(p_levels - 0.50))],
  q75 = q_grid_mat[, which.min(abs(p_levels - 0.75))],
  q95 = q_grid_mat[, which.min(abs(p_levels - 0.95))],
  mu = mu_grid,
  sigma = sigma_grid
)

dir.create(out_root, recursive = TRUE, showWarnings = FALSE)

line_cols <- setNames(
  grDevices::colorRampPalette(
    c("#A63446", "#D17B0F", "#E5C84B", "#111111", "#1E8E89", "#2B59C3")
  )(length(p_levels)),
  sprintf("p = %.2f", p_levels)
)

noise_subtitle <- if (noise_family == "normal") {
  "Gaussian noise with heteroskedastic scale"
} else {
  sprintf("Centered skew-normal noise (shape = %.1f) with heteroskedastic scale", skew_shape)
}

main_plot <- ggplot(sample_df, aes(x = x, y = y)) +
  geom_ribbon(
    data = ribbon_df,
    aes(x = x, ymin = q05, ymax = q95),
    inherit.aes = FALSE,
    fill = "#A9C5A0",
    alpha = 0.22
  ) +
  geom_ribbon(
    data = ribbon_df,
    aes(x = x, ymin = q25, ymax = q75),
    inherit.aes = FALSE,
    fill = "#6BA292",
    alpha = 0.26
  ) +
  geom_point(
    shape = 16,
    size = 1.0,
    alpha = 0.16,
    color = "#2A2F43"
  ) +
  geom_line(
    data = q_grid,
    aes(y = q, color = p_lab),
    linewidth = 0.8,
    alpha = 0.95
  ) +
  geom_line(
    data = ribbon_df,
    aes(x = x, y = mu),
    inherit.aes = FALSE,
    linewidth = 1.0,
    linetype = "22",
    color = "#5C4B51"
  ) +
  scale_color_manual(values = line_cols, name = "True conditional quantiles") +
  labs(
    title = "Heteroskedastic linear-plus-cosine DGP",
    subtitle = paste(
      "Cloud of simulated points with true conditional quantile curves;",
      noise_subtitle
    ),
    x = "x",
    y = "y",
    caption = paste0(
      "n = ", format(n, big.mark = ","), ", seed = ", seed,
      " | beta0 = ", beta0, ", beta1 = ", beta1, ", sigma0 = ", sigma0,
      " | a = ", cos_amp, ", c = ", cos_scale, ", k = ", hetero_mult, ", m = ", hetero_power,
      if (noise_family == "skew_normal") paste0(" | shape = ", skew_shape) else "",
      " | Dashed line = conditional mean"
    )
  ) +
  coord_cartesian(expand = FALSE) +
  theme_minimal(base_size = 14, base_family = "sans") +
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

png_path <- file.path(out_root, "heteroskedastic_linear_cosine_quantiles.png")
pdf_path <- file.path(out_root, "heteroskedastic_linear_cosine_quantiles.pdf")
csv_sample_path <- file.path(out_root, "sample_data.csv")
csv_quant_path <- file.path(out_root, "true_quantile_grid.csv")
wide_csv_path <- file.path(out_root, "series_wide.csv")
long_csv_path <- file.path(out_root, "series_long.csv")
rds_path <- file.path(out_root, "sim_data.rds")
sim_rds_path <- file.path(out_root, "sim_output.rds")
cfg_rds_path <- file.path(out_root, "run_config.rds")
meta_path <- file.path(out_root, "meta.txt")

ggsave(filename = png_path, plot = main_plot, width = 13.5, height = 8.2, dpi = 220, bg = "white")
ggsave(filename = pdf_path, plot = main_plot, width = 13.5, height = 8.2, bg = "white")

utils::write.csv(sample_df, csv_sample_path, row.names = FALSE)
utils::write.csv(q_grid[, c("x", "p", "q")], csv_quant_path, row.names = FALSE)
utils::write.csv(series_wide, wide_csv_path, row.names = FALSE)
utils::write.csv(series_long, long_csv_path, row.names = FALSE)

scenario_name <- if (noise_family == "normal") {
  "static_gaussian_heteroskedastic_linear_cosine"
} else {
  "static_skewnormal_heteroskedastic_linear_cosine"
}

sim_output <- list(
  y = as.numeric(y),
  q = unname(as.matrix(q_obs)),
  p = as.numeric(p_levels),
  info = list(
    scenario = scenario_name,
    params = list(
      beta0 = beta0,
      beta1 = beta1,
      sigma0 = sigma0,
      noise_family = noise_family,
      skew_shape = skew_shape,
      cos_amp = cos_amp,
      cos_scale = cos_scale,
      hetero_mult = hetero_mult,
      hetero_power = hetero_power,
      x_range = c(x_min, x_max),
      n = n
    ),
    burnin = 0L,
    R_mc = if (noise_family == "normal") 0L else as.integer(R_mc),
    seed = seed,
    quantile_truth_method = if (noise_family == "normal") "analytic_gaussian" else "mc_standardized_shift_skew_normal"
  ),
  extras = list(
    mu = as.numeric(mu_x),
    sigma = as.numeric(sigma_x),
    x_main = as.numeric(x),
    cos_term = as.numeric(cos_term),
    q_std = as.numeric(q_std),
    noise_family = noise_family,
    skew_shape = skew_shape,
    X = cbind(
      intercept = 1,
      x_main = x,
      cos_term = cos_term
    )
  )
)
class(sim_output) <- "ts_mc_quantiles"

cfg <- list(
  timestamp = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
  out_root = out_root,
  scenario = scenario_name,
  n = n,
  seed = seed,
  p_grid = p_levels,
  beta0 = beta0,
  beta1 = beta1,
  sigma0 = sigma0,
  noise_family = noise_family,
  skew_shape = skew_shape,
  R_mc = if (noise_family == "normal") 0L else as.integer(R_mc),
  cos_amp = cos_amp,
  cos_scale = cos_scale,
  hetero_mult = hetero_mult,
  hetero_power = hetero_power,
  x_range = c(x_min, x_max)
)

saveRDS(
  list(
    sample = sample_df,
    quantile_grid = q_grid[, c("x", "p", "q")],
    config = cfg
  ),
  rds_path,
  compress = "xz"
)
saveRDS(sim_output, sim_rds_path, compress = "xz")
saveRDS(cfg, cfg_rds_path)

writeLines(
  c(
    "Heteroskedastic linear-plus-cosine DGP",
    "--------------------------------------",
    sprintf("seed: %d", seed),
    sprintf("n: %d", n),
    sprintf("beta0: %.4f", beta0),
    sprintf("beta1: %.4f", beta1),
    sprintf("sigma0: %.4f", sigma0),
    sprintf("noise family: %s", noise_family),
    sprintf("skew shape: %.4f", skew_shape),
    sprintf("R_mc: %d", if (noise_family == "normal") 0L else as.integer(R_mc)),
    sprintf("cos amplitude a: %.4f", cos_amp),
    sprintf("cos scale c: %.4f", cos_scale),
    sprintf("heteroskedastic multiplier k: %.6f", hetero_mult),
    sprintf("heteroskedastic power m: %.4f", hetero_power),
    sprintf("x range: [%.4f, %.4f]", x_min, x_max),
    "CSV/schema compatibility:",
    "  series_wide.csv and series_long.csv follow the static sim-suite style",
    "  used by the exAL/AL testing datasets",
    "DGP:",
    "  Y = beta0 + beta1 * (a cos(X / c) + X) + eps(X)",
    if (noise_family == "normal") {
      "  eps(X) | X = x ~ N(0, sigma0^2 * log(k|x|^m + 1))"
    } else {
      "  eps(X) | X = x ~ sigma(x) * Z, with Z a centered/unit-variance skew-normal"
    },
    "True conditional quantiles:",
    if (noise_family == "normal") {
      "  Q_p(Y | X = x) = beta0 + beta1 * (a cos(x / c) + x) + sigma0 * sqrt(log(k|x|^m + 1)) * qnorm(p)"
    } else {
      "  Q_p(Y | X = x) = mu(x) + sigma(x) * q_p(Z), where q_p(Z) is approximated by MC"
    },
    sprintf("Quantile levels: %s", paste(sprintf("%.2f", p_levels), collapse = ", ")),
    sprintf("Saved series_wide.csv: %s", wide_csv_path),
    sprintf("Saved series_long.csv: %s", long_csv_path),
    sprintf("Saved sim_output.rds: %s", sim_rds_path),
    sprintf("Saved run_config.rds: %s", cfg_rds_path),
    sprintf("Saved PNG: %s", png_path),
    sprintf("Saved PDF: %s", pdf_path)
  ),
  con = meta_path
)

cat(sprintf("Wrote figure and data to: %s\n", out_root))

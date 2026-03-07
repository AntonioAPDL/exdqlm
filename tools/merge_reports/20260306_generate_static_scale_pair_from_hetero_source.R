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
    sweep(matrix(rep(q_std, each = length(mu)), nrow = length(mu)), 1L, sigma, `*`),
    1L, mu, `+`
  )
}

make_series_long <- function(t_idx, p_levels, q_obs, y, mu_x, sigma_x, x, cos_term) {
  do.call(
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
}

make_plot <- function(sample_df, ribbon_df, q_grid, p_levels, out_png, out_pdf, title_txt, subtitle_txt, caption_txt) {
  line_cols <- setNames(
    grDevices::colorRampPalette(c("#A63446", "#D17B0F", "#E5C84B", "#111111", "#1E8E89", "#2B59C3"))(length(p_levels)),
    sprintf("p = %.2f", p_levels)
  )
  q_grid$p_lab <- factor(sprintf("p = %.2f", q_grid$p), levels = sprintf("p = %.2f", p_levels))

  plt <- ggplot(sample_df, aes(x = x, y = y)) +
    geom_ribbon(data = ribbon_df, aes(x = x, ymin = q05, ymax = q95), inherit.aes = FALSE, fill = "#A9C5A0", alpha = 0.22) +
    geom_ribbon(data = ribbon_df, aes(x = x, ymin = q25, ymax = q75), inherit.aes = FALSE, fill = "#6BA292", alpha = 0.26) +
    geom_point(shape = 16, size = 1.0, alpha = 0.16, color = "#2A2F43") +
    geom_line(data = q_grid, aes(y = q, color = p_lab), linewidth = 0.8, alpha = 0.95) +
    geom_line(data = ribbon_df, aes(x = x, y = mu), inherit.aes = FALSE, linewidth = 1.0, linetype = "22", color = "#5C4B51") +
    scale_color_manual(values = line_cols, name = "True conditional quantiles") +
    labs(title = title_txt, subtitle = subtitle_txt, x = "x", y = "y", caption = caption_txt) +
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

  ggplot2::ggsave(out_png, plot = plt, width = 13.5, height = 8.5, dpi = 160)
  ggplot2::ggsave(out_pdf, plot = plt, width = 13.5, height = 8.5, dpi = 160)
}

write_scenario <- function(root, scenario_name, x, mu_x, sigma_x, z_std, q_std, p_levels, cfg, target_n) {
  dir.create(root, recursive = TRUE, showWarnings = FALSE)

  y <- mu_x + sigma_x * z_std
  q_obs <- compose_quantiles(mu_x, sigma_x, q_std)
  q_names <- sprintf("q_%03d", pmin(pmax(as.integer(round(100 * p_levels)), 0L), 999L))
  colnames(q_obs) <- q_names

  t_idx <- seq_along(y)
  cos_term <- cfg$cos_amp * cos(x / cfg$cos_scale)
  X <- cbind(intercept = 1, x_main = x, cos_term = cos_term)

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
  series_long <- make_series_long(t_idx, p_levels, q_obs, y, mu_x, sigma_x, x, cos_term)

  x_grid <- seq(cfg$x_range[1], cfg$x_range[2], length.out = 1200L)
  mu_grid <- cfg$beta0 + cfg$beta1 * (cfg$cos_amp * cos(x_grid / cfg$cos_scale) + x_grid)
  if (length(sigma_x) == 1L || max(abs(sigma_x - sigma_x[1])) < 1e-12) {
    sigma_grid <- rep(sigma_x[1], length(x_grid))
  } else {
    sigma_grid <- cfg$sigma0 * sqrt(log(cfg$hetero_mult * abs(x_grid)^cfg$hetero_power + 1))
  }
  q_grid_mat <- compose_quantiles(mu_grid, sigma_grid, q_std)
  q_grid <- do.call(rbind, lapply(seq_along(p_levels), function(j) {
    data.frame(x = x_grid, p = p_levels[j], q = q_grid_mat[, j], stringsAsFactors = FALSE)
  }))

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

  sim_output <- list(
    y = y,
    q = q_obs,
    p = p_levels,
    info = list(
      scenario = scenario_name,
      params = list(
        beta0 = cfg$beta0,
        beta1 = cfg$beta1,
        sigma0 = cfg$sigma0,
        sigma_mode = if (length(sigma_x) == 1L || max(abs(sigma_x - sigma_x[1])) < 1e-12) "homoskedastic" else "heteroskedastic",
        sigma_const = if (length(sigma_x) == 1L || max(abs(sigma_x - sigma_x[1])) < 1e-12) sigma_x[1] else NA_real_,
        noise_family = cfg$noise_family,
        skew_shape = cfg$skew_shape,
        cos_amp = cfg$cos_amp,
        cos_scale = cfg$cos_scale,
        hetero_mult = cfg$hetero_mult,
        hetero_power = cfg$hetero_power,
        x_range = cfg$x_range,
        n = length(y)
      ),
      burnin = 0L,
      R_mc = cfg$R_mc,
      seed = cfg$seed,
      quantile_truth_method = cfg$quantile_truth_method,
      paired_source = cfg$source_root
    ),
    extras = list(
      mu = mu_x,
      sigma = sigma_x,
      x_main = x,
      cos_term = cos_term,
      q_std = q_std,
      noise_family = cfg$noise_family,
      skew_shape = cfg$skew_shape,
      X = X,
      z_std = z_std
    )
  )

  sim_data <- list(
    sample = sample_df,
    quantile_grid = q_grid,
    config = cfg
  )

  utils::write.csv(sample_df, file.path(root, "sample_data.csv"), row.names = FALSE)
  utils::write.csv(series_wide, file.path(root, "series_wide.csv"), row.names = FALSE)
  utils::write.csv(series_long, file.path(root, "series_long.csv"), row.names = FALSE)
  utils::write.csv(q_grid, file.path(root, "true_quantile_grid.csv"), row.names = FALSE)
  saveRDS(sim_output, file.path(root, "sim_output.rds"))
  saveRDS(sim_data, file.path(root, "sim_data.rds"))
  saveRDS(cfg, file.path(root, "run_config.rds"))

  plot_stub <- if (grepl("homoskedastic", scenario_name, fixed = TRUE)) {
    "homoskedastic_linear_cosine_quantiles"
  } else {
    "heteroskedastic_linear_cosine_quantiles"
  }
  subtitle_txt <- if (grepl("homoskedastic", scenario_name, fixed = TRUE)) {
    sprintf("Centered %s noise with constant scale matched to the heteroskedastic sample mean", cfg$noise_family)
  } else {
    sprintf("Centered %s noise with heteroskedastic scale", cfg$noise_family)
  }
  caption_txt <- paste0(
    "n = ", format(length(y), big.mark = ","), ", seed = ", cfg$seed,
    " | beta0 = ", cfg$beta0, ", beta1 = ", cfg$beta1,
    " | sigma mode = ", if (grepl("homoskedastic", scenario_name, fixed = TRUE)) "constant" else "heteroskedastic",
    if (grepl("homoskedastic", scenario_name, fixed = TRUE)) paste0(" (const = ", round(sigma_x[1], 4), ")") else "",
    " | shape = ", cfg$skew_shape,
    " | Dashed line = conditional mean"
  )
  make_plot(
    sample_df = sample_df,
    ribbon_df = ribbon_df,
    q_grid = q_grid,
    p_levels = p_levels,
    out_png = file.path(root, paste0(plot_stub, ".png")),
    out_pdf = file.path(root, paste0(plot_stub, ".pdf")),
    title_txt = if (grepl("homoskedastic", scenario_name, fixed = TRUE)) "Homoskedastic linear-plus-cosine DGP" else "Heteroskedastic linear-plus-cosine DGP",
    subtitle_txt = subtitle_txt,
    caption_txt = caption_txt
  )

  ord <- order(x, seq_along(x))
  rank_pos <- systematic_rank_subsample(x[ord], target_n)
  idx <- ord[rank_pos]
  sub_root <- file.path(root, sprintf("fit_input_subsample_tt%d_xmain_sorted", target_n))
  dir.create(sub_root, recursive = TRUE, showWarnings = FALSE)

  subset_sim <- sim_output
  subset_sim$y <- as.numeric(sim_output$y[idx])
  subset_sim$q <- as.matrix(sim_output$q[idx, , drop = FALSE])
  subset_sim$extras$mu <- as.numeric(sim_output$extras$mu[idx])
  subset_sim$extras$sigma <- as.numeric(sim_output$extras$sigma[idx])
  subset_sim$extras$x_main <- as.numeric(sim_output$extras$x_main[idx])
  subset_sim$extras$cos_term <- as.numeric(sim_output$extras$cos_term[idx])
  subset_sim$extras$X <- as.matrix(sim_output$extras$X[idx, , drop = FALSE])
  subset_sim$extras$z_std <- as.numeric(sim_output$extras$z_std[idx])
  subset_sim$extras$source_index <- as.integer(idx)
  subset_sim$extras$source_n <- as.integer(length(y))
  subset_sim$info$subsample <- list(
    source_root = root,
    source_n = as.integer(length(y)),
    target_n = as.integer(target_n),
    selection_method = "systematic_rank_x_main",
    sorted_by = "x_main"
  )
  if (!is.null(subset_sim$info$params$n)) subset_sim$info$params$n <- as.integer(target_n)

  series_wide_sub <- series_wide[idx, , drop = FALSE]
  series_long_sub <- do.call(rbind, lapply(seq_along(p_levels), function(j) {
    data.frame(
      row_id = seq_len(target_n),
      source_index = as.integer(idx),
      x_main = subset_sim$extras$x_main,
      y = subset_sim$y,
      p = subset_sim$p[j],
      q = subset_sim$q[, j],
      stringsAsFactors = FALSE
    )
  }))
  selection_df <- data.frame(row_id = seq_len(target_n), source_index = as.integer(idx), x_main = subset_sim$extras$x_main, stringsAsFactors = FALSE)

  utils::write.csv(series_wide_sub, file.path(sub_root, "series_wide.csv"), row.names = FALSE)
  utils::write.csv(series_long_sub, file.path(sub_root, "series_long.csv"), row.names = FALSE)
  utils::write.csv(selection_df, file.path(sub_root, "selection_indices.csv"), row.names = FALSE)
  utils::write.csv(q_grid, file.path(sub_root, "true_quantile_grid.csv"), row.names = FALSE)
  saveRDS(subset_sim, file.path(sub_root, "sim_output.rds"))
  writeLines(c(
    "Static fit input subsample",
    "--------------------------",
    sprintf("source root: %s", root),
    sprintf("source n: %d", length(y)),
    sprintf("target n: %d", target_n),
    "selection method: systematic_rank_x_main",
    "ordering: x_main ascending after selection"
  ), file.path(sub_root, "meta.txt"))
}

source_root <- safe_chr(Sys.getenv("EXDQLM_SCALE_PAIR_SOURCE_ROOT", "results/function_testing_20260306_static_heteroskedastic_skewnormal"), "results/function_testing_20260306_static_heteroskedastic_skewnormal")
source_sim_path <- file.path(source_root, "sim_output.rds")
source_cfg_path <- file.path(source_root, "run_config.rds")
if (!file.exists(source_sim_path) || !file.exists(source_cfg_path)) stop("Missing source heteroskedastic root files under: ", source_root)

target_n <- safe_int(Sys.getenv("EXDQLM_SCALE_PAIR_SUBSAMPLE_N", "5000"), 5000L)
out_root <- safe_chr(Sys.getenv("EXDQLM_SCALE_PAIR_OUT_ROOT", "results/function_testing_20260306_static_scale_pair_skewnormal"), "results/function_testing_20260306_static_scale_pair_skewnormal")
homo_sigma_mode <- safe_chr(Sys.getenv("EXDQLM_HOMO_SIGMA_MODE", "mean_sample"), "mean_sample")
homo_sigma_const_user <- suppressWarnings(as.numeric(Sys.getenv("EXDQLM_HOMO_SIGMA_CONST", "NA"))[1])

src_sim <- readRDS(source_sim_path)
src_cfg <- readRDS(source_cfg_path)

x <- as.numeric(src_sim$extras$x_main)
mu_x <- as.numeric(src_sim$extras$mu)
sigma_het <- as.numeric(src_sim$extras$sigma)
z_std <- (as.numeric(src_sim$y) - mu_x) / sigma_het
q_std <- as.numeric(src_sim$extras$q_std)
names(q_std) <- names(src_sim$extras$q_std)
p_levels <- as.numeric(src_sim$p)

sigma_homo <- if (is.finite(homo_sigma_const_user)) {
  rep(homo_sigma_const_user, length(x))
} else if (identical(homo_sigma_mode, "mean_sample")) {
  rep(mean(sigma_het), length(x))
} else if (identical(homo_sigma_mode, "median_sample")) {
  rep(stats::median(sigma_het), length(x))
} else {
  stop("Unsupported EXDQLM_HOMO_SIGMA_MODE: ", homo_sigma_mode)
}

cfg_common <- src_cfg
cfg_common$timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
cfg_common$source_root <- source_root
cfg_common$homoskedastic_sigma_mode <- homo_sigma_mode
cfg_common$homoskedastic_sigma_const <- sigma_homo[1]

hetero_root <- file.path(out_root, "heteroskedastic")
homo_root <- file.path(out_root, "homoskedastic")

cfg_het <- cfg_common
cfg_het$out_root <- hetero_root
cfg_het$scenario <- "static_skewnormal_heteroskedastic_linear_cosine_paired"
write_scenario(hetero_root, cfg_het$scenario, x, mu_x, sigma_het, z_std, q_std, p_levels, cfg_het, target_n)

cfg_homo <- cfg_common
cfg_homo$out_root <- homo_root
cfg_homo$scenario <- "static_skewnormal_homoskedastic_linear_cosine_paired"
write_scenario(homo_root, cfg_homo$scenario, x, mu_x, sigma_homo, z_std, q_std, p_levels, cfg_homo, target_n)

meta_lines <- c(
  "Static scale-pair generation from heteroskedastic source",
  "------------------------------------------------------",
  sprintf("source root: %s", source_root),
  sprintf("heteroskedastic output root: %s", hetero_root),
  sprintf("homoskedastic output root: %s", homo_root),
  sprintf("paired sample size: %d", length(x)),
  sprintf("paired fit subsample size: %d", target_n),
  sprintf("homoskedastic sigma mode: %s", homo_sigma_mode),
  sprintf("homoskedastic sigma constant: %.6f", sigma_homo[1]),
  "construction: same x, same conditional mean, same standardized noise draw z_std; only sigma(x) differs"
)
dir.create(out_root, recursive = TRUE, showWarnings = FALSE)
writeLines(meta_lines, file.path(out_root, "meta.txt"))
cat(sprintf("Generated paired static scenarios under: %s\n", out_root))

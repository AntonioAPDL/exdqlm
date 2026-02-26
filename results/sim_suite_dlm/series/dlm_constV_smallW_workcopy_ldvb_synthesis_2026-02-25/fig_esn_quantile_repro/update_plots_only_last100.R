#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  req <- c("ggplot2", "jsonlite")
  miss <- setdiff(req, rownames(installed.packages()))
  if (length(miss)) stop("Missing packages: ", paste(miss, collapse = ", "))
  invisible(lapply(req, require, character.only = TRUE))
})

output_root <- "/data/muscat_data/jaguir26/exdqlm__wt__0.3.0-cpp/results/sim_suite_dlm/series/dlm_constV_smallW_workcopy_20260225/fig_esn_quantile_repro"
fig_dir <- file.path(output_root, "figs")
tab_dir <- file.path(output_root, "tables")
man_dir <- file.path(output_root, "manifest")

cmp_path <- file.path(tab_dir, "comparison_series_selected_quantiles.csv")
cfg_path <- file.path(man_dir, "run_config.json")
if (!file.exists(cmp_path)) stop("Missing table: ", cmp_path)
if (!file.exists(cfg_path)) stop("Missing config: ", cfg_path)

cmp <- read.csv(cmp_path)
cfg <- jsonlite::fromJSON(cfg_path, simplifyVector = TRUE)

train_end <- as.integer(cfg$split$train_end)
fc_start <- as.integer(cfg$split$forecast_start)
if (!all(c("t", "window", "y", "q_true_05", "q_true_50", "q_true_95", "q_syn_05", "q_syn_50", "q_syn_95") %in% names(cmp))) {
  stop("comparison table missing required columns")
}

idx_train100 <- (train_end - 99L):train_end
idx_train100 <- idx_train100[idx_train100 >= min(cmp$t)]
idx_fc <- fc_start:max(cmp$t)

plot_band <- function(df, title_txt, out_file) {
  g <- ggplot(df, aes(x = t)) +
    geom_ribbon(aes(ymin = q_true_05, ymax = q_true_95), fill = "steelblue", alpha = 0.15) +
    geom_ribbon(aes(ymin = q_syn_05, ymax = q_syn_95), fill = "darkorange", alpha = 0.18) +
    geom_line(aes(y = q_true_50), color = "steelblue4", linewidth = 0.7, linetype = "dashed") +
    geom_line(aes(y = q_syn_50), color = "darkorange4", linewidth = 0.85) +
    geom_line(aes(y = y), color = "black", linewidth = 0.45) +
    labs(
      title = title_txt,
      subtitle = "Black=y, blue=true quantiles, orange=synthesized quantiles",
      x = "t", y = "value"
    ) +
    theme_minimal(base_size = 11)
  ggsave(out_file, g, width = 12, height = 5, dpi = 140)
}

plot_lines_compare <- function(df, title_txt, out_file) {
  long <- rbind(
    data.frame(t = df$t, quantile = "0.05", source = "true", value = df$q_true_05),
    data.frame(t = df$t, quantile = "0.05", source = "synth", value = df$q_syn_05),
    data.frame(t = df$t, quantile = "0.50", source = "true", value = df$q_true_50),
    data.frame(t = df$t, quantile = "0.50", source = "synth", value = df$q_syn_50),
    data.frame(t = df$t, quantile = "0.95", source = "true", value = df$q_true_95),
    data.frame(t = df$t, quantile = "0.95", source = "synth", value = df$q_syn_95)
  )
  long$series <- paste(long$quantile, long$source, sep = "-")

  col_map <- c(
    "0.05-true" = "#1f77b4",
    "0.05-synth" = "#ff7f0e",
    "0.50-true" = "#2c5aa0",
    "0.50-synth" = "#d95f02",
    "0.95-true" = "#4c78a8",
    "0.95-synth" = "#b24d00"
  )

  g <- ggplot(long, aes(x = t, y = value, color = series, linetype = source)) +
    geom_line(linewidth = 0.8) +
    facet_wrap(~quantile, ncol = 1, scales = "free_y") +
    scale_color_manual(values = col_map) +
    scale_linetype_manual(values = c(true = "dashed", synth = "solid")) +
    labs(
      title = title_txt,
      subtitle = "Per-quantile dynamics: dashed=true, solid=synthesized",
      x = "t", y = "quantile value", color = "series", linetype = "source"
    ) +
    theme_minimal(base_size = 11)

  ggsave(out_file, g, width = 11, height = 7, dpi = 140)
}

plot_delta <- function(df, title_txt, out_file) {
  dd <- rbind(
    data.frame(t = df$t, quantile = "0.05", delta = df$q_syn_05 - df$q_true_05),
    data.frame(t = df$t, quantile = "0.50", delta = df$q_syn_50 - df$q_true_50),
    data.frame(t = df$t, quantile = "0.95", delta = df$q_syn_95 - df$q_true_95)
  )

  g <- ggplot(dd, aes(x = t, y = delta, color = quantile)) +
    geom_hline(yintercept = 0, linetype = "dashed", color = "gray45") +
    geom_line(linewidth = 0.8) +
    facet_wrap(~quantile, ncol = 1, scales = "free_y") +
    labs(
      title = title_txt,
      subtitle = "Difference = synthesized - true quantile",
      x = "t", y = "delta"
    ) +
    theme_minimal(base_size = 11)

  ggsave(out_file, g, width = 11, height = 7, dpi = 140)
}

train100 <- cmp[cmp$t %in% idx_train100, ]
train100 <- train100[order(train100$t), ]
fc <- cmp[cmp$t %in% idx_fc, ]
fc <- fc[order(fc$t), ]

if (nrow(train100) == 0L) stop("No rows found for train last-100 slice")
if (nrow(fc) == 0L) stop("No rows found for forecast slice")

# 1) Overwrite existing train plot with last 100 points (as requested)
plot_band(
  train100,
  sprintf("Train window (last %d points): synthesized vs true quantiles", nrow(train100)),
  file.path(fig_dir, "train_last_window_syn_vs_true.png")
)

# 2) Keep explicit last100 band variant too
plot_band(
  train100,
  sprintf("Train window (last %d points): synthesized vs true quantiles", nrow(train100)),
  file.path(fig_dir, "train_last100_syn_vs_true.png")
)

# 3) Lines-only true vs synth quantile dynamics (train last100)
plot_lines_compare(
  train100,
  sprintf("Train window (last %d): true vs synthesized quantile dynamics", nrow(train100)),
  file.path(fig_dir, "train_last100_true_vs_synth_quantile_dynamics_lines.png")
)

# 4) Same lines-only comparison for forecast window
plot_lines_compare(
  fc,
  "Forecast window: true vs synthesized quantile dynamics",
  file.path(fig_dir, "forecast_true_vs_synth_quantile_dynamics_lines.png")
)

# 5) Optional delta plots for clarity
plot_delta(
  train100,
  sprintf("Train window (last %d): synthesized minus true quantiles", nrow(train100)),
  file.path(fig_dir, "train_last100_synth_minus_true_quantile_delta.png")
)
plot_delta(
  fc,
  "Forecast window: synthesized minus true quantiles",
  file.path(fig_dir, "forecast_synth_minus_true_quantile_delta.png")
)

cat("Done. Added/updated plots in:", fig_dir, "\n")

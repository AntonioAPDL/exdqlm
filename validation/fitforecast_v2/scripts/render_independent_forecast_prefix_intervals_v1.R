#!/usr/bin/env Rscript
options(stringsAsFactors = FALSE)
script <- normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1]))
repo <- normalizePath(file.path(dirname(script), "../../.."))
source(file.path(repo, "validation/fitforecast_v2/R/forecast_prefix_metric_intervals_v1.R"))
args <- commandArgs(trailingOnly = TRUE)
arg <- function(flag) {
  i <- match(flag, args)
  fpf_assert(!is.na(i) && i < length(args), paste("Required argument:", flag))
  args[i + 1L]
}
root <- normalizePath(arg("--run"))
data <- fpf_read(file.path(root, "available_display_intervals.csv"))
manifest <- fpf_read(file.path(root, "artifact_manifest.csv"))
fpf_assert(all(vapply(manifest$path, fpf_sha, character(1)) == manifest$sha256), "Run evidence hashes changed.")
out <- file.path(root, "review")
dir.create(out, showWarnings = FALSE)
pdf <- file.path(out, if (nrow(data) == 216L) "full_500_300_article_interval_review.pdf" else
  "verified_partial_prefix_interval_recovery.pdf")
grDevices::cairo_pdf(pdf, width = 8.4, height = 7.4, onefile = TRUE)
if (nrow(data) == 216L) {
  source(normalizePath(arg("--style")))
  for (n in c(1000L, 500L, 300L)) for (role in c("forecast_mae", "forecast_check")) {
    d <- data[data$cutoff == n, ]
    p <- qdesn_independent_interval_plot(d, "mcmc", role)
    bounds <- data[data$metric_role == role, ]
    bounds$panel_key <- factor(paste(bounds$family, sprintf("%.2f", bounds$tau), sep = "|"),
      levels = levels(p$data$panel_key))
    limits <- rbind(data.frame(panel_key = bounds$panel_key, x = bounds$cri_lower),
      data.frame(panel_key = bounds$panel_key, x = bounds$cri_upper),
      data.frame(panel_key = bounds$panel_key, x = bounds$plot_reference_value))
    p <- p + ggplot2::geom_blank(data = limits, ggplot2::aes(x = x), inherit.aes = FALSE) +
      ggplot2::labs(title = paste(if (role == "forecast_mae") "Figure 1" else "Figure 2", "- first", n, "targets"),
        subtitle = sprintf("Targets 9001:%d | %d origins | original posterior sources", 9000 + n, ceiling(n / 30)),
        caption = "Posterior mean scores and equal-tailed 95% intervals. Evaluation-window sensitivity only.") +
      ggplot2::theme(text = ggplot2::element_text(size = 10),
        strip.text = ggplot2::element_text(size = 10, face = "bold"),
        plot.caption = ggplot2::element_text(size = 8, hjust = 0))
    print(p)
  }
} else {
  ids <- unique(data$replay_id[data$cutoff != 1000L])
  fpf_assert(length(ids) > 0, "No shorter-window posterior intervals have been recovered.")
  for (id in ids) for (role in c("forecast_mae", "forecast_check")) {
    d <- data[data$replay_id == id & data$metric_role == role, ]
    d$window <- factor(d$cutoff, levels = c(300, 500, 1000),
      labels = c("First 300 targets", "First 500 targets", "Full 1,000 targets"))
    unavailable <- data.frame(window = factor("First 500 targets", levels = levels(d$window)),
      x = min(d$cri_lower))
    label <- if (role == "forecast_mae") "Forecast quantile-path MAE" else "Forecast check loss"
    p <- ggplot2::ggplot(d, ggplot2::aes(y = window)) +
      ggplot2::geom_vline(xintercept = unique(d$plot_reference_value), linetype = "22", colour = "#333333") +
      ggplot2::geom_segment(ggplot2::aes(x = cri_lower, xend = cri_upper, yend = window),
        colour = "#1F4E79", linewidth = 1.1) +
      ggplot2::geom_point(ggplot2::aes(x = posterior_mean), colour = "#1F4E79", size = 3) +
      ggplot2::geom_text(ggplot2::aes(x = posterior_mean,
        label = sprintf("%.3f [%.3f, %.3f]", posterior_mean, cri_lower, cri_upper)),
        nudge_y = .2, size = 4, colour = "#222222") +
      ggplot2::geom_text(data = unavailable, ggplot2::aes(x = x, y = window),
        label = "Not recovered: cutoff includes part of an origin", inherit.aes = FALSE,
        hjust = 0, colour = "#777777", size = 4) +
      ggplot2::scale_y_discrete(drop = FALSE) +
      ggplot2::labs(title = paste(label, "- verified partial recovery"),
        subtitle = paste(d$model_label[1], "| Gaussian | p = 0.05 | 3,000 pooled draws"),
        x = label, y = NULL,
        caption = paste("Means and equal-tailed 95% metric intervals from the SAME retained source draws.",
          "First 300: 10 origins; full 1,000: 34 origins. No fits or forecasts were run.",
          "Other cases remain unavailable. This is not a complete article replacement.", sep = "\n")) +
      ggplot2::theme_bw(base_size = 13) +
      ggplot2::theme(panel.grid.major.y = ggplot2::element_blank(), panel.grid.minor = ggplot2::element_blank(),
        plot.title = ggplot2::element_text(face = "bold", size = 16),
        plot.caption = ggplot2::element_text(size = 10, hjust = 0, lineheight = 1.2),
        plot.margin = ggplot2::margin(15, 15, 15, 15))
    print(p)
  }
}
grDevices::dev.off()
fpf_write(data.frame(path = normalizePath(pdf), sha256 = fpf_sha(pdf),
  bytes = file.info(pdf)$size, complete = nrow(data) == 216L), file.path(out, "review_manifest.csv"))
cat("REVIEW_PDF ", normalizePath(pdf), "\n", sep = "")

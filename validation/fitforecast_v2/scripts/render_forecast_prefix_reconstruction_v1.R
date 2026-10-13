# Sourced by the reconstruction controller only after all selected chains finish.
data <- fpf_read(file.path(out, "reconstructed_display_intervals.csv"))
baseline <- fpf_read(file.path(out, "article_baseline.csv"))
fpf_assert(nrow(data) == 216L && nrow(baseline) == 72L, "Complete figures require all selected sources.")
source(file.path(out, "frozen_article_style.R"))
review <- file.path(out, "review")
dir.create(review, showWarnings = FALSE)
pdf <- file.path(review, "full_500_300_reconstruction_comparison.pdf")
grDevices::cairo_pdf(pdf, width = 8.4, height = 7.4, onefile = TRUE)
for (n in c(0L, 1000L, 500L, 300L)) for (role in c("forecast_mae", "forecast_check")) {
  d <- if (n == 0L) baseline else data[data$cutoff == n, ]
  p <- qdesn_independent_interval_plot(d, "mcmc", role)
  bounds <- rbind(baseline[baseline$metric_role == role, ],
    data[data$metric_role == role, names(baseline)])
  bounds$panel_key <- factor(paste(bounds$family, sprintf("%.2f", bounds$tau), sep = "|"),
    levels = levels(p$data$panel_key))
  limits <- rbind(data.frame(panel_key = bounds$panel_key, x = bounds$cri_lower),
    data.frame(panel_key = bounds$panel_key, x = bounds$cri_upper),
    data.frame(panel_key = bounds$panel_key, x = bounds$plot_reference_value))
  title <- if (n == 0L) "Published baseline - full 1,000 targets" else
    paste("Selected-source reconstruction - first", format(n, big.mark = ","), "targets")
  p <- p + ggplot2::geom_blank(data = limits, ggplot2::aes(x = x), inherit.aes = FALSE) +
    ggplot2::labs(title = title,
      subtitle = paste(if (role == "forecast_mae") "Figure 1: forecast quantile-path MAE" else
        "Figure 2: forecast check loss", "| matched panel scales"),
      caption = if (n == 0L) "Retained article numbers; no refit results replace this baseline automatically." else
        paste("Frozen specifications; newly reconstructed posterior samples; three chains per selected source.",
          "Same draws across all cutoffs. Posterior mean and equal-tailed 95% metric interval. Review only.", sep = "\n")) +
    ggplot2::theme(text = ggplot2::element_text(size = 10),
      strip.text = ggplot2::element_text(size = 10, face = "bold"),
      plot.title = ggplot2::element_text(size = 14),
      plot.caption = ggplot2::element_text(size = 8, hjust = 0))
  print(p)
}
grDevices::dev.off()
fpf_write(fpr_hashes(pdf), file.path(review, "review_manifest.csv"))
cat("COMPLETE_COMPARISON_PDF", normalizePath(pdf), "\n")

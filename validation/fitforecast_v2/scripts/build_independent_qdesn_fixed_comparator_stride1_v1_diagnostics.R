#!/usr/bin/env Rscript

cmd_args0 <- commandArgs(FALSE)
file_arg <- grep("^--file=", cmd_args0, value = TRUE)
this_file <- if (length(file_arg)) sub("^--file=", "", file_arg[[1L]]) else
  "validation/fitforecast_v2/scripts/build_independent_qdesn_fixed_comparator_stride1_v1_diagnostics.R"
harness_root <- normalizePath(file.path(dirname(this_file), ".."), winslash = "/",
                              mustWork = TRUE)
source(file.path(harness_root, "R", "utils.R"))
ffv2_source_all(harness_root)
ffv2_require_namespace("ggplot2")

args <- ffv2_parse_args()
run_root <- ffv2_resolve_path(args$`run-root` %||% "", must_work = TRUE)
closeout_root <- file.path(run_root, "closeout")
output_root <- ffv2_ensure_dir(args$`output-root` %||%
                                file.path(run_root, "diagnostics"))

intervals <- iqfc_v1_read_csv(file.path(
  closeout_root, "unified_four_model_intervals.csv"
))
matched <- iqfc_v1_read_csv(file.path(
  closeout_root, "likelihood_matched_comparison.csv"
))
leads <- iqfc_v1_read_csv(file.path(closeout_root, "forecast_lead_profiles.csv"))
origins <- iqfc_v1_read_csv(file.path(closeout_root, "forecast_origin_profiles.csv"))
origin_lead <- iqfc_v1_read_csv(file.path(
  closeout_root, "forecast_origin_lead_profiles.csv.gz"
))

model_labels <- c(
  dqlm = "DQLM", qdesn_al_rhs = "Q-DESN AL-RHS",
  exdqlm = "exDQLM", qdesn_exal_rhs = "Q-DESN exAL-RHS"
)
model_colors <- c(
  "DQLM" = "#2C3E50", "Q-DESN AL-RHS" = "#D55E00",
  "exDQLM" = "#0072B2", "Q-DESN exAL-RHS" = "#009E73"
)
metric_labels <- c(
  fit_qtrue_rmse = "Fit RMSE", fit_qtrue_mae = "Fit MAE",
  fit_check_loss = "Fit check loss",
  forecast_qtrue_mae = "Forecast MAE",
  forecast_qtrue_rmse = "Forecast RMSE",
  forecast_check_loss = "Forecast check loss"
)
family_labels <- c(normal = "Gaussian", laplace = "Laplace",
                   gausmix = "Gaussian mixture")

decorate <- function(x) {
  x$model <- unname(model_labels[x$model_variant])
  x$tau_label <- paste0("p = ", sprintf("%.2f", x$tau))
  x$family_label <- unname(family_labels[x$family])
  x
}
intervals <- decorate(intervals)
leads <- decorate(leads)
origins <- decorate(origins)
origin_lead <- decorate(origin_lead)
intervals$metric_label <- factor(
  unname(metric_labels[intervals$metric]), levels = unname(metric_labels)
)

theme_ind <- function() {
  ggplot2::theme_bw(base_size = 9) +
    ggplot2::theme(
      panel.grid.minor = ggplot2::element_blank(),
      strip.background = ggplot2::element_rect(fill = "#F2F2F2", colour = "#B8B8B8"),
      legend.position = "bottom", legend.title = ggplot2::element_blank(),
      plot.title.position = "plot"
    )
}

pdf_path <- file.path(
  output_root, "independent_fixed_comparator_stride1_four_model_diagnostics.pdf"
)
grDevices::pdf(pdf_path, width = 12, height = 8.5, onefile = TRUE)
on.exit(grDevices::dev.off(), add = TRUE)

for (family in c("normal", "laplace", "gausmix")) {
  x <- intervals[intervals$family == family, , drop = FALSE]
  p <- ggplot2::ggplot(
    x, ggplot2::aes(x = posterior_mean, y = model, colour = model)
  ) +
    ggplot2::geom_errorbar(
      ggplot2::aes(xmin = cri_lower, xmax = cri_upper), orientation = "y",
      width = 0.16,
      linewidth = 0.45
    ) +
    ggplot2::geom_point(shape = 4, stroke = 0.8, size = 2.2) +
    ggplot2::facet_grid(metric_label ~ tau_label, scales = "free_x") +
    ggplot2::scale_colour_manual(values = model_colors, drop = FALSE) +
    ggplot2::labs(
      title = paste0(family_labels[[family]], ": posterior metric summaries"),
      subtitle = "Crosses are posterior means; bars are equal-tailed 95% intervals",
      x = NULL, y = NULL
    ) + theme_ind()
  print(p)
}

matched$model <- unname(model_labels[matched$model_variant_qdesn])
matched$cell <- paste0(unname(family_labels[matched$family]), " | p=",
                       sprintf("%.2f", matched$tau))
matched$metric_label <- unname(metric_labels[matched$metric])
matched$likelihood <- ifelse(matched$likelihood_family == "al", "AL", "exAL")
p <- ggplot2::ggplot(
  matched,
  ggplot2::aes(x = metric_label, y = cell,
               fill = log2(qdesn_to_comparator_ratio))
) +
  ggplot2::geom_tile(colour = "white", linewidth = 0.25) +
  ggplot2::facet_wrap(~likelihood, ncol = 1, scales = "free_y") +
  ggplot2::scale_fill_gradient2(
    low = "#2166AC", mid = "white", high = "#B2182B", midpoint = 0,
    name = "log2 Q-DESN/comparator"
  ) +
  ggplot2::labs(
    title = "Likelihood-matched Q-DESN/comparator score ratios",
    subtitle = "Blue favors Q-DESN; red favors the corresponding DQLM comparator",
    x = NULL, y = NULL
  ) + theme_ind() +
  ggplot2::theme(axis.text.x = ggplot2::element_text(angle = 30, hjust = 1))
print(p)

for (likelihood in c("al", "exal")) {
  x <- leads[leads$likelihood_family == likelihood, , drop = FALSE]
  p <- ggplot2::ggplot(
    x, ggplot2::aes(x = forecast_lead, y = abs_q_error,
                    colour = model, group = model)
  ) +
    ggplot2::geom_line(linewidth = 0.55) +
    ggplot2::facet_grid(family_label ~ tau_label, scales = "free_y") +
    ggplot2::scale_colour_manual(values = model_colors, drop = FALSE) +
    ggplot2::labs(
      title = paste0(ifelse(likelihood == "al", "AL", "exAL"),
                     ": forecast MAE by lead"),
      x = "Forecast lead", y = "Mean absolute oracle-quantile error"
    ) + theme_ind()
  print(p)
}

for (family in c("normal", "laplace", "gausmix")) {
  x <- origin_lead[origin_lead$family == family, , drop = FALSE]
  p <- ggplot2::ggplot(
    x, ggplot2::aes(x = forecast_origin_source_index,
                    y = forecast_lead, fill = abs_q_error)
  ) +
    ggplot2::geom_raster() +
    ggplot2::facet_grid(model ~ tau_label, scales = "free_x") +
    ggplot2::scale_fill_viridis_c(option = "C", trans = "sqrt") +
    ggplot2::labs(
      title = paste0(family_labels[[family]],
                     ": origin-by-lead absolute oracle-quantile error"),
      x = "Forecast origin", y = "Lead", fill = "MAE"
    ) + theme_ind() +
    ggplot2::theme(legend.position = "right")
  print(p)
}

grDevices::dev.off()
on.exit(NULL, add = FALSE)
manifest <- data.frame(
  artifact = "four_model_diagnostic_pdf",
  path = normalizePath(pdf_path, winslash = "/", mustWork = TRUE),
  sha256 = iqfc_v1_sha256(pdf_path),
  bytes = as.numeric(file.info(pdf_path)$size),
  article_asset = FALSE, stringsAsFactors = FALSE
)
manifest_path <- iqfc_v1_write_csv(
  manifest, file.path(output_root, "diagnostic_manifest.csv")
)
cat(sprintf("DIAGNOSTIC_PDF path=%s sha256=%s manifest=%s\n",
            pdf_path, manifest$sha256[[1L]], manifest_path))

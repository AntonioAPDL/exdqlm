#!/usr/bin/env Rscript

cmd_args0 <- commandArgs(FALSE)
file_arg <- grep("^--file=", cmd_args0, value = TRUE)
this_file <- if (length(file_arg)) sub("^--file=", "", file_arg[[1L]]) else
  "validation/fitforecast_v2/scripts/build_independent_exdqlm_mcmc_rolling_state_fix_v1_diagnostics.R"
harness_root <- normalizePath(file.path(dirname(this_file), ".."), winslash = "/",
                              mustWork = TRUE)
source(file.path(harness_root, "R", "utils.R"))
ffv2_source_all(harness_root)

args <- ffv2_parse_args()
repo_root <- normalizePath(args$`repo-root` %||% ffv2_repo_root(), winslash = "/",
                           mustWork = TRUE)
closeout_root <- normalizePath(args$`closeout-root` %||% "", winslash = "/",
                               mustWork = TRUE)
packet_root <- ffv2_resolve_path(
  args$`output-root` %||% file.path(dirname(closeout_root), "diagnostics"),
  repo_root = repo_root, must_work = FALSE
)
if (!requireNamespace("ggplot2", quietly = TRUE)) {
  stop("ggplot2 is required for the diagnostic packet.", call. = FALSE)
}
figure_root <- file.path(packet_root, "figures")
ffv2_ensure_dir(figure_root)

handoff <- ffv2_read_json(file.path(closeout_root, "integration_handoff.json"))
if (!identical(as.character(handoff$status), "READY_FOR_INTEGRATION")) {
  stop("Diagnostics require a successful full closeout.", call. = FALSE)
}
cell <- ffv2_read_csv(file.path(closeout_root, "cell_metric_comparison.csv"))
intervals <- ffv2_read_csv(file.path(closeout_root, "candidate_interval_exdqlm_mcmc_roles.csv"))
lead <- ffv2_read_csv(file.path(closeout_root, "forecast_lead_profiles.csv"))
origin <- ffv2_read_csv(file.path(closeout_root, "forecast_origin_profiles.csv"))
inference <- ffv2_read_csv(file.path(closeout_root, "exdqlm_inference_diagnostics.csv"))

family_label <- c(
  normal = "Gaussian", laplace = "Laplace", gausmix = "Gaussian mixture"
)
metric_label <- c(
  fit_rmse = "Fit RMSE", forecast_mae = "Forecast MAE",
  forecast_check_loss = "Forecast check loss"
)
palette <- c(Historical = "#8A8178", Corrected = "#0072B2")
theme_packet <- function() {
  ggplot2::theme_minimal(base_size = 9) +
    ggplot2::theme(
      plot.title = ggplot2::element_text(face = "bold", size = 12),
      panel.grid.minor = ggplot2::element_blank(),
      strip.text = ggplot2::element_text(face = "bold"),
      legend.position = "bottom"
    )
}
save_plot <- function(plot, stem, width = 11, height = 7) {
  path <- file.path(figure_root, paste0(stem, ".pdf"))
  ggplot2::ggsave(
    path, plot, width = width, height = height, device = grDevices::cairo_pdf
  )
  normalizePath(path, winslash = "/", mustWork = TRUE)
}

cell_long <- ffv2_bind_rows(lapply(names(metric_label), function(metric) {
  historical <- c(
    fit_rmse = "historical_fit_rmse", forecast_mae = "historical_forecast_mae",
    forecast_check_loss = "historical_forecast_check"
  )[[metric]]
  corrected <- c(
    fit_rmse = "corrected_fit_rmse", forecast_mae = "corrected_forecast_mae",
    forecast_check_loss = "corrected_forecast_check"
  )[[metric]]
  rbind(
    data.frame(cell[c("family", "tau")], metric = metric, version = "Historical",
               value = cell[[historical]], stringsAsFactors = FALSE),
    data.frame(cell[c("family", "tau")], metric = metric, version = "Corrected",
               value = cell[[corrected]], stringsAsFactors = FALSE)
  )
}))
cell_long$family_label <- unname(family_label[cell_long$family])
cell_long$metric_label <- unname(metric_label[cell_long$metric])
cell_long$tau_label <- sprintf("p = %.2f", cell_long$tau)
comparison_plot <- ggplot2::ggplot(
  cell_long,
  ggplot2::aes(x = value, y = tau_label, colour = version, group = tau_label)
) +
  ggplot2::geom_line(linewidth = 0.55) +
  ggplot2::geom_point(size = 2.1) +
  ggplot2::facet_grid(metric_label ~ family_label, scales = "free_x") +
  ggplot2::scale_colour_manual(values = palette) +
  ggplot2::labs(
    title = "Historical and corrected exDQLM MCMC metrics",
    subtitle = "Only the held-out rolling-state transport differs",
    x = "Metric value (lower is better)", y = NULL, colour = NULL
  ) + theme_packet()
comparison_pdf <- save_plot(comparison_plot, "01_historical_vs_corrected_metrics", 11, 7.5)

intervals$family_label <- unname(family_label[intervals$family])
intervals$metric_label <- unname(metric_label[intervals$metric])
intervals$tau_label <- sprintf("p = %.2f", intervals$tau)
interval_plot <- ggplot2::ggplot(
  intervals, ggplot2::aes(x = posterior_mean, y = tau_label)
) +
  ggplot2::geom_errorbar(
    ggplot2::aes(xmin = cri_lower, xmax = cri_upper), orientation = "y",
    width = 0.18, linewidth = 0.45, colour = "#0072B2"
  ) +
  ggplot2::geom_point(shape = 4, size = 2.2, stroke = 0.8, colour = "#0072B2") +
  ggplot2::geom_point(
    ggplot2::aes(x = authoritative_value), shape = 18, size = 2.2,
    colour = "#B24C2A"
  ) +
  ggplot2::facet_grid(metric_label ~ family_label, scales = "free_x") +
  ggplot2::labs(
    title = "Corrected exDQLM posterior metric intervals",
    subtitle = "Blue: posterior metric mean and 95% credible interval; red: fixed-path point score",
    x = "Metric value (lower is better)", y = NULL
  ) + theme_packet()
interval_pdf <- save_plot(interval_plot, "02_corrected_metric_intervals", 11, 7.5)

lead_long <- rbind(
  data.frame(
    lead[c("family", "tau", "forecast_lead")], metric = "forecast_mae",
    value = lead$forecast_qtrue_mae_mean
  ),
  data.frame(
    lead[c("family", "tau", "forecast_lead")], metric = "forecast_check_loss",
    value = lead$forecast_pinball_mean_mean
  )
)
lead_long$family_label <- unname(family_label[lead_long$family])
lead_long$metric_label <- unname(metric_label[lead_long$metric])
lead_long$tau_label <- sprintf("p = %.2f", lead_long$tau)
lead_plot <- ggplot2::ggplot(
  lead_long,
  ggplot2::aes(x = forecast_lead, y = value, colour = tau_label)
) +
  ggplot2::geom_line(linewidth = 0.55) +
  ggplot2::facet_grid(metric_label ~ family_label, scales = "free_y") +
  ggplot2::scale_colour_manual(values = c(
    "p = 0.05" = "#0072B2", "p = 0.25" = "#D55E00", "p = 0.50" = "#4D8B31"
  )) +
  ggplot2::labs(
    title = "Corrected forecast error by lead", x = "Forecast lead",
    y = "Three-chain mean", colour = "Target"
  ) + theme_packet()
lead_pdf <- save_plot(lead_plot, "03_forecast_lead_profiles", 11, 7)

origin_long <- rbind(
  data.frame(
    origin[c("family", "tau", "forecast_origin_source_index")],
    metric = "forecast_mae", value = origin$abs_q_error_mean
  ),
  data.frame(
    origin[c("family", "tau", "forecast_origin_source_index")],
    metric = "forecast_check_loss", value = origin$pinball_tau_mean
  )
)
origin_long$family_label <- unname(family_label[origin_long$family])
origin_long$metric_label <- unname(metric_label[origin_long$metric])
origin_long$tau_label <- sprintf("p = %.2f", origin_long$tau)
origin_plot <- ggplot2::ggplot(
  origin_long,
  ggplot2::aes(x = forecast_origin_source_index, y = value, colour = tau_label)
) +
  ggplot2::geom_line(linewidth = 0.48) + ggplot2::geom_point(size = 0.7) +
  ggplot2::facet_grid(metric_label ~ family_label, scales = "free_y") +
  ggplot2::scale_colour_manual(values = c(
    "p = 0.05" = "#0072B2", "p = 0.25" = "#D55E00", "p = 0.50" = "#4D8B31"
  )) +
  ggplot2::labs(
    title = "Corrected forecast error by rolling origin",
    x = "Forecast-origin source index", y = "Three-chain mean", colour = "Target"
  ) + theme_packet()
origin_pdf <- save_plot(origin_plot, "04_forecast_origin_profiles", 11, 7)

diagnostic_long <- rbind(
  data.frame(inference[c("family", "tau", "chain_id")], parameter = "gamma",
             ess = inference$gamma_ess),
  data.frame(inference[c("family", "tau", "chain_id")], parameter = "sigma",
             ess = inference$sigma_ess)
)
diagnostic_long$family_label <- unname(family_label[diagnostic_long$family])
diagnostic_long$tau_label <- sprintf("p = %.2f", diagnostic_long$tau)
diagnostic_plot <- ggplot2::ggplot(
  diagnostic_long,
  ggplot2::aes(x = factor(chain_id), y = ess, fill = parameter)
) +
  ggplot2::geom_col(position = "dodge") +
  ggplot2::facet_grid(tau_label ~ family_label, scales = "free_y") +
  ggplot2::scale_fill_manual(values = c(gamma = "#D55E00", sigma = "#0072B2")) +
  ggplot2::labs(
    title = "Corrected-run scale-skewness effective sample sizes",
    x = "Chain", y = "ESS", fill = "Parameter"
  ) + theme_packet()
diagnostic_pdf <- save_plot(diagnostic_plot, "05_gamma_sigma_diagnostics", 10.5, 8)

pdf_paths <- c(comparison_pdf, interval_pdf, lead_pdf, origin_pdf, diagnostic_pdf)
combined_path <- file.path(
  packet_root, "independent_exdqlm_mcmc_rolling_state_fix_v1_diagnostics.pdf"
)
pdfunite <- Sys.which("pdfunite")
if (nzchar(pdfunite)) {
  output <- system2(pdfunite, c(pdf_paths, combined_path), stdout = TRUE, stderr = TRUE)
  if (!identical(attr(output, "status") %||% 0L, 0L) || !file.exists(combined_path)) {
    stop("pdfunite could not assemble the diagnostic packet.", call. = FALSE)
  }
} else {
  file.copy(comparison_pdf, combined_path, overwrite = TRUE)
}

figure_manifest <- data.frame(
  figure = basename(pdf_paths), path = pdf_paths,
  sha256 = vapply(pdf_paths, ffv2_file_sha256, character(1L)),
  stringsAsFactors = FALSE
)
figure_manifest_path <- ffv2_write_csv(
  figure_manifest, file.path(packet_root, "figure_manifest.csv")
)
packet_manifest <- list(
  schema_version = iems_v1_schema,
  generated_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"),
  status = "PASS", purpose = "ignored_diagnostic_review_not_article_asset",
  run_id = as.character(handoff$run_id), figures = length(pdf_paths),
  combined_pdf_path = normalizePath(combined_path, winslash = "/", mustWork = TRUE),
  combined_pdf_sha256 = ffv2_file_sha256(combined_path),
  figure_manifest_path = figure_manifest_path,
  figure_manifest_sha256 = ffv2_file_sha256(figure_manifest_path),
  closeout_handoff_sha256 = ffv2_file_sha256(
    file.path(closeout_root, "integration_handoff.json")
  ),
  article_write_performed = FALSE
)
manifest_path <- ffv2_write_json(
  packet_manifest, file.path(packet_root, "packet_manifest.json")
)
cat(sprintf("DIAGNOSTIC_PACKET=%s\n", combined_path))
cat(sprintf("PACKET_MANIFEST=%s\n", manifest_path))

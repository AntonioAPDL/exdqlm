#!/usr/bin/env Rscript

cmd_args0 <- commandArgs(FALSE)
file_arg <- grep("^--file=", cmd_args0, value = TRUE)
this_file <- if (length(file_arg)) sub("^--file=", "", file_arg[[1L]]) else
  "validation/fitforecast_v2/scripts/build_independent_exdqlm_1p1p1_scoped_diagnostic_packet_v1.R"
harness_root <- normalizePath(file.path(dirname(this_file), ".."), winslash = "/",
                              mustWork = TRUE)
source(file.path(harness_root, "R", "utils.R"))
ffv2_source_all(harness_root)

args <- ffv2_parse_args()
state_root <- normalizePath(args$`state-root` %||% "", winslash = "/", mustWork = TRUE)
manifest <- ffv2_read_json(file.path(state_root, "manifests", "materialization_manifest.json"))
if (!identical(as.character(manifest$schema_version), i111s_schema)) {
  stop("The diagnostic packet requires the exDQLM-only scoped campaign.", call. = FALSE)
}
if (!requireNamespace("ggplot2", quietly = TRUE)) {
  stop("ggplot2 is required for the scoped diagnostic packet.", call. = FALSE)
}
packet_root <- ffv2_resolve_path(
  args$`output-root` %||% file.path(state_root, "diagnostics", "exdqlm_1p1p1_scoped"),
  repo_root = ffv2_repo_root(), must_work = FALSE
)
closeout_root <- ffv2_resolve_path(
  args$`closeout-root` %||% file.path(state_root, "closeout"),
  repo_root = ffv2_repo_root(), must_work = TRUE
)
figure_root <- file.path(packet_root, "figures")
table_root <- file.path(packet_root, "tables")
ffv2_ensure_dir(figure_root)
ffv2_ensure_dir(table_root)

comparison_candidates <- file.path(
  closeout_root,
  c("exdqlm_1p1p1_scoped_vs_authority_v2.csv",
    "exdqlm_1p1p1_scoped_vs_authority.csv")
)
comparison_path <- comparison_candidates[file.exists(comparison_candidates)][1L]
if (is.na(comparison_path)) {
  stop("No scoped comparison table exists in the requested closeout root.",
       call. = FALSE)
}
comparison <- ffv2_read_csv(comparison_path)
job_audit <- ffv2_read_csv(file.path(closeout_root, "job_artifact_audit.csv"))
inference_diagnostics <- ffv2_read_csv(file.path(
  closeout_root, "exdqlm_inference_diagnostics.csv"
))
metric_diagnostics <- ffv2_read_csv(file.path(
  closeout_root, "mcmc_metric_diagnostics.csv"
))
if (nrow(comparison) != i111s_expected_metric_roles ||
    nrow(job_audit) != i111s_expected_jobs) {
  stop("Scoped closeout tables are incomplete.", call. = FALSE)
}

family_label <- c(normal = "Gaussian", laplace = "Laplace",
                  gausmix = "Gaussian mixture")
metric_label <- c(fit = "Fit RMSE", forecast_mae = "Forecast MAE",
                  forecast_check = "Forecast check loss")
theme_scoped <- function() {
  ggplot2::theme_minimal(base_size = 9) +
    ggplot2::theme(
      plot.title = ggplot2::element_text(face = "bold", size = 12),
      panel.grid.minor = ggplot2::element_blank(),
      strip.text = ggplot2::element_text(face = "bold"),
      legend.position = "bottom"
    )
}
save_plot <- function(plot, stem, width = 10, height = 7) {
  path <- file.path(figure_root, paste0(stem, ".pdf"))
  ggplot2::ggsave(path, plot, width = width, height = height,
                  device = grDevices::cairo_pdf)
  normalizePath(path, winslash = "/", mustWork = TRUE)
}

mcmc_comparison <- comparison[comparison$inference == "mcmc", , drop = FALSE]
mcmc_comparison$family_label <- unname(family_label[mcmc_comparison$family])
mcmc_comparison$metric_label <- unname(metric_label[mcmc_comparison$metric_role])
mcmc_comparison$case <- sprintf("p = %.2f", mcmc_comparison$tau)
metric_plot <- ggplot2::ggplot(
  mcmc_comparison,
  ggplot2::aes(x = posterior_mean, y = case)
) +
  ggplot2::geom_errorbar(
    ggplot2::aes(xmin = cri_lower, xmax = cri_upper), width = 0.18,
    orientation = "y",
    colour = "#1B6CA8", linewidth = 0.45
  ) +
  ggplot2::geom_point(shape = 4, size = 2.1, stroke = 0.8, colour = "#1B6CA8") +
  ggplot2::geom_point(
    ggplot2::aes(x = authoritative_value), shape = 18, size = 2.2,
    colour = "#B24C2A"
  ) +
  ggplot2::facet_grid(metric_label ~ family_label, scales = "free_x") +
  ggplot2::labs(
    title = "exDQLM 1.1.1 MCMC metric intervals",
    subtitle = "Blue crosses and intervals: 1.1.1 posterior metric summaries; red diamonds: frozen authority",
    x = "Metric value (lower is better)", y = NULL
  ) + theme_scoped()
metric_pdf <- save_plot(metric_plot, "01_mcmc_metric_intervals_vs_authority", 11, 7.4)

mcmc_jobs <- job_audit[job_audit$inference == "mcmc", , drop = FALSE]
granular <- lapply(seq_len(nrow(mcmc_jobs)), function(i) {
  row <- mcmc_jobs[i, , drop = FALSE]
  cfg <- ffv2_read_json(row$config_path[[1L]])
  lead <- ffv2_read_csv(cfg$forecast_lead_metrics_path)
  forecast <- ffv2_read_csv(cfg$forecast_path_summary_path)
  fit <- ffv2_read_csv(cfg$fit_path_summary_path)
  lead <- i111s_add_job_metadata(lead, row, "forecast lead metrics")
  forecast <- i111s_add_job_metadata(forecast, row, "forecast path summary")
  fit <- i111s_add_job_metadata(fit, row, "fit path summary")
  i111s_require_columns(
    lead,
    c("family", "tau", "chain_id", "forecast_lead", "forecast_qtrue_mae",
      "forecast_pinball_mean"),
    "forecast lead metrics"
  )
  i111s_require_columns(
    forecast,
    c("family", "tau", "chain_id", "source_index", "q_true", "qhat",
      "abs_q_error", "pinball_tau", "forecast_origin_source_index",
      "forecast_lead"),
    "forecast path summary"
  )
  i111s_require_columns(
    fit, c("family", "tau", "chain_id", "source_index", "q_true", "qhat"),
    "fit path summary"
  )
  list(lead = lead, forecast = forecast, fit = fit)
})
lead <- ffv2_bind_rows(lapply(granular, `[[`, "lead"))
forecast <- ffv2_bind_rows(lapply(granular, `[[`, "forecast"))
fit <- ffv2_bind_rows(lapply(granular, `[[`, "fit"))
lead_path <- ffv2_write_csv(
  lead, file.path(table_root, "mcmc_forecast_lead_profiles.csv")
)
forecast_path <- ffv2_write_csv(
  forecast, file.path(table_root, "mcmc_forecast_path_summaries.csv")
)
fit_path <- ffv2_write_csv(
  fit, file.path(table_root, "mcmc_fit_path_summaries.csv")
)
cell_key <- function(x) paste(x$family, sprintf("%.2f", x$tau), sep = "|")
input_checks <- c(
  mcmc_jobs_27 = nrow(mcmc_jobs) == i111s_expected_mcmc_jobs,
  lead_cells_9 = length(unique(cell_key(lead))) == 9L,
  forecast_cells_9 = length(unique(cell_key(forecast))) == 9L,
  fit_cells_9 = length(unique(cell_key(fit))) == 9L,
  lead_chains_27 = length(unique(paste(cell_key(lead), lead$chain_id))) == 27L,
  forecast_chains_27 = length(unique(paste(cell_key(forecast), forecast$chain_id))) == 27L,
  fit_chains_27 = length(unique(paste(cell_key(fit), fit$chain_id))) == 27L,
  comparison_roles_54 = nrow(comparison) == i111s_expected_metric_roles,
  metric_diagnostics_27 = nrow(metric_diagnostics) == 27L
)
input_checks_path <- ffv2_write_csv(
  data.frame(check = names(input_checks), pass = unname(input_checks),
             stringsAsFactors = FALSE),
  file.path(packet_root, "diagnostic_input_checks.csv")
)
if (!all(input_checks)) {
  stop(sprintf("Diagnostic input checks failed: %s",
               paste(names(input_checks)[!input_checks], collapse = ", ")),
       call. = FALSE)
}

lead_summary <- stats::aggregate(
  lead[c("forecast_qtrue_mae", "forecast_pinball_mean")],
  by = lead[c("family", "tau", "forecast_lead")], FUN = mean
)
lead_long <- rbind(
  data.frame(lead_summary[c("family", "tau", "forecast_lead")],
             metric = "Forecast MAE", value = lead_summary$forecast_qtrue_mae),
  data.frame(lead_summary[c("family", "tau", "forecast_lead")],
             metric = "Forecast check loss", value = lead_summary$forecast_pinball_mean)
)
lead_long$family_label <- unname(family_label[lead_long$family])
lead_long$tau_label <- sprintf("p = %.2f", lead_long$tau)
lead_plot <- ggplot2::ggplot(
  lead_long, ggplot2::aes(x = forecast_lead, y = value, colour = tau_label)
) + ggplot2::geom_line(linewidth = 0.55) +
  ggplot2::facet_grid(metric ~ family_label, scales = "free_y") +
  ggplot2::scale_colour_manual(values = c("p = 0.05" = "#0072B2",
                                          "p = 0.25" = "#D55E00",
                                          "p = 0.50" = "#4D8B31")) +
  ggplot2::labs(title = "Forecast error by lead", x = "Forecast lead",
                y = "Chain-averaged metric", colour = "Target") + theme_scoped()
lead_pdf <- save_plot(lead_plot, "02_forecast_lead_profiles", 11, 7)

origin <- stats::aggregate(
  forecast[c("abs_q_error", "pinball_tau")],
  by = forecast[c("family", "tau", "chain_id", "forecast_origin_source_index")],
  FUN = mean
)
origin <- stats::aggregate(
  origin[c("abs_q_error", "pinball_tau")],
  by = origin[c("family", "tau", "forecast_origin_source_index")], FUN = mean
)
origin_long <- rbind(
  data.frame(origin[c("family", "tau", "forecast_origin_source_index")],
             metric = "Forecast MAE", value = origin$abs_q_error),
  data.frame(origin[c("family", "tau", "forecast_origin_source_index")],
             metric = "Forecast check loss", value = origin$pinball_tau)
)
origin_long$family_label <- unname(family_label[origin_long$family])
origin_long$tau_label <- sprintf("p = %.2f", origin_long$tau)
origin_plot <- ggplot2::ggplot(
  origin_long,
  ggplot2::aes(x = forecast_origin_source_index, y = value, colour = tau_label)
) + ggplot2::geom_line(linewidth = 0.5) + ggplot2::geom_point(size = 0.8) +
  ggplot2::facet_grid(metric ~ family_label, scales = "free_y") +
  ggplot2::scale_colour_manual(values = c("p = 0.05" = "#0072B2",
                                          "p = 0.25" = "#D55E00",
                                          "p = 0.50" = "#4D8B31")) +
  ggplot2::labs(title = "Forecast error by rolling origin",
                x = "Forecast-origin source index", y = "Chain-averaged metric",
                colour = "Target") + theme_scoped()
origin_pdf <- save_plot(origin_plot, "03_forecast_origin_profiles", 11, 7)

path_summary <- function(x, split_label) {
  stats::aggregate(
    x[c("q_true", "qhat")],
    by = x[c("family", "tau", "source_index")], FUN = mean
  ) |>
    transform(split = split_label)
}
paths <- rbind(path_summary(fit, "Training fit"), path_summary(forecast, "Forecast"))
paths$family_label <- unname(family_label[paths$family])
paths$tau_label <- sprintf("p = %.2f", paths$tau)
path_long <- rbind(
  data.frame(paths[c("family_label", "tau_label", "source_index", "split")],
             path = "Oracle", value = paths$q_true),
  data.frame(paths[c("family_label", "tau_label", "source_index", "split")],
             path = "exDQLM 1.1.1", value = paths$qhat)
)
path_plot <- ggplot2::ggplot(
  path_long, ggplot2::aes(x = source_index, y = value, colour = path)
) + ggplot2::geom_line(linewidth = 0.38) +
  ggplot2::facet_grid(split + tau_label ~ family_label, scales = "free_x") +
  ggplot2::scale_colour_manual(values = c("Oracle" = "#202020",
                                          "exDQLM 1.1.1" = "#0072B2")) +
  ggplot2::labs(title = "Oracle and fitted conditional-quantile paths",
                x = "Source index", y = "Conditional quantile", colour = NULL) +
  theme_scoped() + ggplot2::theme(strip.text.y = ggplot2::element_text(size = 7))
path_pdf <- save_plot(path_plot, "04_fit_and_forecast_path_recovery", 11.5, 13)

mcmc_inference <- inference_diagnostics[inference_diagnostics$inference == "mcmc", ]
mcmc_inference$family_label <- unname(family_label[mcmc_inference$family])
mcmc_inference$tau_label <- sprintf("p = %.2f", mcmc_inference$tau)
diagnostic_long <- rbind(
  data.frame(mcmc_inference[c("family_label", "tau_label", "chain_id")],
             parameter = "gamma", ess = mcmc_inference$gamma_ess,
             acf1 = mcmc_inference$gamma_acf1),
  data.frame(mcmc_inference[c("family_label", "tau_label", "chain_id")],
             parameter = "sigma", ess = mcmc_inference$sigma_ess,
             acf1 = mcmc_inference$sigma_acf1)
)
diagnostic_plot <- ggplot2::ggplot(
  diagnostic_long, ggplot2::aes(x = factor(chain_id), y = ess, fill = parameter)
) + ggplot2::geom_col(position = "dodge") +
  ggplot2::facet_grid(tau_label ~ family_label, scales = "free_y") +
  ggplot2::scale_fill_manual(values = c(gamma = "#D55E00", sigma = "#0072B2")) +
  ggplot2::labs(title = "Scale-skewness effective sample sizes",
                x = "Chain", y = "ESS", fill = "Parameter") + theme_scoped()
diagnostic_pdf <- save_plot(diagnostic_plot, "05_gamma_sigma_diagnostics", 10.5, 8)

pdf_paths <- c(metric_pdf, lead_pdf, origin_pdf, path_pdf, diagnostic_pdf)
combined_path <- file.path(packet_root, "independent_exdqlm_1p1p1_scoped_diagnostics.pdf")
pdfunite <- Sys.which("pdfunite")
if (nzchar(pdfunite)) {
  status <- system2(pdfunite, c(pdf_paths, combined_path), stdout = TRUE, stderr = TRUE)
  if (!identical(attr(status, "status") %||% 0L, 0L) || !file.exists(combined_path)) {
    stop("pdfunite could not assemble the scoped diagnostic packet.", call. = FALSE)
  }
} else {
  file.copy(metric_pdf, combined_path, overwrite = TRUE)
}
figure_manifest <- data.frame(
  figure = basename(pdf_paths), path = pdf_paths,
  sha256 = vapply(pdf_paths, ffv2_file_sha256, character(1L)),
  stringsAsFactors = FALSE
)
figure_manifest_path <- ffv2_write_csv(
  figure_manifest, file.path(packet_root, "figure_manifest.csv")
)
table_manifest <- data.frame(
  table = basename(c(lead_path, forecast_path, fit_path, input_checks_path)),
  path = c(lead_path, forecast_path, fit_path, input_checks_path),
  sha256 = vapply(c(lead_path, forecast_path, fit_path, input_checks_path),
                  ffv2_file_sha256, character(1L)),
  stringsAsFactors = FALSE
)
table_manifest_path <- ffv2_write_csv(
  table_manifest, file.path(packet_root, "table_manifest.csv")
)
packet_manifest <- list(
  schema_version = i111s_schema,
  generated_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"),
  status = "PASS", run_id = as.character(manifest$run_id),
  purpose = "ignored_exdqlm_1p1p1_scoped_diagnostic_review_not_article_asset",
  closeout_root = closeout_root,
  comparison_path = comparison_path,
  comparison_sha256 = ffv2_file_sha256(comparison_path),
  figures = nrow(figure_manifest),
  combined_pdf_path = normalizePath(combined_path, winslash = "/", mustWork = TRUE),
  combined_pdf_sha256 = ffv2_file_sha256(combined_path),
  figure_manifest_path = figure_manifest_path,
  figure_manifest_sha256 = ffv2_file_sha256(figure_manifest_path),
  table_manifest_path = table_manifest_path,
  table_manifest_sha256 = ffv2_file_sha256(table_manifest_path),
  input_checks_path = input_checks_path,
  input_checks_sha256 = ffv2_file_sha256(input_checks_path),
  mcmc_metric_warning_rows = sum(metric_diagnostics$diagnostic_grade == "WARN"),
  article_write_performed = FALSE
)
ffv2_write_json(packet_manifest, file.path(packet_root, "packet_manifest.json"))
cat(sprintf("scoped diagnostic packet: %s\n", combined_path))

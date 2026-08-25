imir_v1_schema <- "independent_metric_interval_reporting_v1"
imir_v1_source_promotion_id <- "qdesn_dqlm_500obs_metric_intervals_v10_20260824"
imir_v1_reporting_id <- "qdesn_dqlm_500obs_metric_interval_reporting_v10_1_20260825"
imir_v1_estimator_id <- "posterior_mean_draw_metric_equal_tailed_95cri_v1"
imir_v1_deterministic_tolerance <- 1e-6

imir_v1_source_dir <- function(repo_root = ffv2_repo_root()) {
  file.path(repo_root, "validation", "fitforecast_v2", "promotions",
            imir_v1_source_promotion_id)
}

imir_v1_output_dir <- function(repo_root = ffv2_repo_root()) {
  file.path(repo_root, "validation", "fitforecast_v2", "promotions",
            imir_v1_reporting_id)
}

imir_v1_source_path <- function(repo_root = ffv2_repo_root()) {
  file.path(imir_v1_source_dir(repo_root), "article_metric_role_intervals.csv")
}

imir_v1_palette <- c(
  dqlm = "#0072B2",
  exdqlm = "#56B4E9",
  qdesn_al_rhs_ns = "#D55E00",
  qdesn_exal_rhs_ns = "#009E73"
)

imir_v1_model_labels <- c(
  dqlm = "DQLM",
  exdqlm = "exDQLM",
  qdesn_al_rhs_ns = "Q-DESN AL-RHS",
  qdesn_exal_rhs_ns = "Q-DESN exAL-RHS"
)

imir_v1_family_labels <- c(
  normal = "Gaussian",
  laplace = "Laplace",
  gausmix = "Gaussian mixture"
)

imir_v1_metric_labels <- c(
  fit = "Fit RMSE",
  forecast_mae = "Forecast MAE",
  forecast_check = "Forecast check loss"
)

imir_v1_metric_file_labels <- c(
  fit = "fit_rmse",
  forecast_mae = "forecast_mae",
  forecast_check = "forecast_check_loss"
)

imir_v1_read_roles <- function(repo_root = ffv2_repo_root()) {
  path <- imir_v1_source_path(repo_root)
  if (!file.exists(path)) stop(sprintf("Frozen v10 role interval file is missing: %s", path),
                               call. = FALSE)
  ffv2_read_csv(path)
}

imir_v1_prepare_plot_data <- function(roles) {
  required <- c(
    "article_row", "inference", "model_variant", "model_label", "family", "tau",
    "metric_role", "posterior_mean", "cri_lower", "posterior_median", "cri_upper",
    "interval_label", "estimator_id", "replay_id", "diagnostic_grade"
  )
  missing <- setdiff(required, names(roles))
  if (length(missing)) {
    stop(sprintf("Interval role file is missing: %s", paste(missing, collapse = ", ")),
         call. = FALSE)
  }
  out <- roles
  out$inference <- tolower(as.character(out$inference))
  out$model_variant <- as.character(out$model_variant)
  out$family <- as.character(out$family)
  out$metric_role <- as.character(out$metric_role)
  out$tau <- as.numeric(out$tau)
  out$posterior_mean <- as.numeric(out$posterior_mean)
  out$cri_lower <- as.numeric(out$cri_lower)
  out$posterior_median <- as.numeric(out$posterior_median)
  out$cri_upper <- as.numeric(out$cri_upper)
  out$model_label <- unname(imir_v1_model_labels[out$model_variant])
  out$family_label <- unname(imir_v1_family_labels[out$family])
  out$metric_label <- unname(imir_v1_metric_labels[out$metric_role])
  out$tau_label <- sprintf("p = %.2f", out$tau)
  out$panel_label <- paste(out$family_label, out$tau_label, sep = "\n")
  panel_levels <- unlist(lapply(unname(imir_v1_family_labels), function(family) {
    paste(family, sprintf("p = %.2f", c(0.05, 0.25, 0.50)), sep = "\n")
  }), use.names = FALSE)
  out$panel_label <- factor(out$panel_label, levels = panel_levels)
  out$model_label <- factor(
    out$model_label,
    levels = rev(unname(imir_v1_model_labels))
  )
  out$inference_label <- ifelse(out$inference == "mcmc", "MCMC", "Variational Bayes")
  out[order(out$inference, out$metric_role, out$family, out$tau, out$model_variant),
      , drop = FALSE]
}

imir_v1_contract_checks <- function(plot_data) {
  expected_models <- names(imir_v1_model_labels)
  expected_families <- names(imir_v1_family_labels)
  expected_metrics <- names(imir_v1_metric_labels)
  key <- do.call(paste, c(plot_data[c(
    "inference", "model_variant", "family", "tau", "metric_role"
  )], sep = "|"))
  finite <- is.finite(plot_data$posterior_mean) & is.finite(plot_data$cri_lower) &
    is.finite(plot_data$posterior_median) & is.finite(plot_data$cri_upper)
  interval_ordered <- plot_data$cri_lower <= plot_data$posterior_median &
    plot_data$posterior_median <= plot_data$cri_upper
  mean_inside <- plot_data$posterior_mean >= plot_data$cri_lower &
    plot_data$posterior_mean <= plot_data$cri_upper
  checks <- data.frame(
    check = c(
      "source_rows_216", "unique_cells_216", "inference_levels_exact",
      "model_levels_exact", "family_levels_exact", "tau_levels_exact",
      "metric_levels_exact", "rows_108_per_inference", "rows_36_per_inference_metric",
      "finite_intervals", "ordered_intervals", "posterior_means_inside_intervals",
      "estimator_id_frozen", "mcmc_interval_label_exact", "vb_interval_label_approximate",
      "model_labels_resolved", "family_labels_resolved", "metric_labels_resolved"
    ),
    pass = c(
      nrow(plot_data) == 216L,
      length(unique(key)) == 216L,
      setequal(unique(plot_data$inference), c("mcmc", "vb")),
      setequal(unique(plot_data$model_variant), expected_models),
      setequal(unique(plot_data$family), expected_families),
      setequal(unique(plot_data$tau), c(0.05, 0.25, 0.50)),
      setequal(unique(plot_data$metric_role), expected_metrics),
      all(table(plot_data$inference) == 108L),
      all(table(plot_data$inference, plot_data$metric_role) == 36L),
      all(finite), all(interval_ordered), all(mean_inside),
      all(as.character(plot_data$estimator_id) == imir_v1_estimator_id),
      all(as.character(plot_data$interval_label[plot_data$inference == "mcmc"]) ==
            "95pct_credible_interval"),
      all(as.character(plot_data$interval_label[plot_data$inference == "vb"]) ==
            "approximate_95pct_credible_interval"),
      all(!is.na(plot_data$model_label)), all(!is.na(plot_data$family_label)),
      all(!is.na(plot_data$metric_label))
    ),
    stringsAsFactors = FALSE
  )
  checks
}

imir_v1_contract_ledger <- function() {
  data.frame(
    engine = c("qdesn", "dqlm"),
    fit_draw_contract = c(
      "aligned posterior readout draw across the 500-row training path",
      "aligned sampled state path across the 500-row training path"
    ),
    forecast_draw_contract = c(
      "native posterior readout identity aligned across rolling origins and leads",
      "product coupling of origin-lead latent quantile marginals from ff and fQ"
    ),
    response_predictive_draws_used = FALSE,
    implementation_status = "MATCHES_DECLARED_NATIVE_CONTRACT",
    primary_interval_status = "RETAIN",
    stringsAsFactors = FALSE
  )
}

imir_v1_implementation_ledger <- function() {
  data.frame(
    engine = c("qdesn", "qdesn", "dqlm", "dqlm"),
    component = c("fit", "forecast", "fit", "forecast"),
    implementation_file = c(
      "R/qdesn_validation_metric_intervals.R",
      "R/qdesn_validation_metric_intervals.R",
      "validation/fitforecast_v2/R/metric_intervals_v1.R",
      "validation/fitforecast_v2/R/exdqlm_rolling_state.R"
    ),
    implementation_function = c(
      ".qdesn_validation_metric_draws_from_summary",
      ".qdesn_validation_metric_draws_from_summary",
      "ffv2_dqlm_conditional_quantile_draws",
      "ffv2_rolling_exdqlm_forecast_summary"
    ),
    rows = c(500L, 1000L, 500L, 1000L),
    draw_source = c(
      "mu_draws_tr", "mu_by_origin", "samp.theta projected by FF", "latent ff/fQ marginals"
    ),
    audit_result = "MATCHES_DECLARED_NATIVE_CONTRACT",
    stringsAsFactors = FALSE
  )
}

imir_v1_fresh_chain_equivalence <- function(replay,
                                            deterministic_tolerance =
                                              imir_v1_deterministic_tolerance,
                                            standardized_mean_limit = 0.10,
                                            interval_overlap_limit = 0.95) {
  required <- c(
    "replay_id", "metric", "posterior_mean_pilot", "posterior_sd_v10",
    "cri_lower_pilot", "cri_upper_pilot", "cri_lower_v10", "cri_upper_v10"
  )
  missing <- setdiff(required, names(replay))
  if (length(missing)) {
    stop(sprintf("Replay comparison is missing: %s", paste(missing, collapse = ", ")),
         call. = FALSE)
  }
  fields <- c("posterior_mean", "posterior_sd", "cri_lower", "posterior_median", "cri_upper")
  out <- replay
  for (field in fields) {
    out[[paste0(field, "_absolute_difference")]] <- abs(
      as.numeric(out[[paste0(field, "_pilot")]]) -
        as.numeric(out[[paste0(field, "_v10")]])
    )
  }
  out$deterministic_all_summary_match <- apply(
    out[paste0(fields, "_absolute_difference")], 1L,
    function(x) all(is.finite(x) & x <= deterministic_tolerance)
  )
  out$standardized_mean_difference <- out$posterior_mean_absolute_difference /
    pmax(as.numeric(out$posterior_sd_v10), .Machine$double.eps)
  overlap <- pmax(
    0,
    pmin(as.numeric(out$cri_upper_pilot), as.numeric(out$cri_upper_v10)) -
      pmax(as.numeric(out$cri_lower_pilot), as.numeric(out$cri_lower_v10))
  )
  minimum_width <- pmin(
    as.numeric(out$cri_upper_pilot) - as.numeric(out$cri_lower_pilot),
    as.numeric(out$cri_upper_v10) - as.numeric(out$cri_lower_v10)
  )
  out$interval_overlap_fraction <- overlap / pmax(minimum_width, .Machine$double.eps)
  out$fresh_chain_statistical_equivalence <-
    out$standardized_mean_difference <= standardized_mean_limit &
    out$interval_overlap_fraction >= interval_overlap_limit
  out
}

imir_v1_figure_spec <- function() {
  data.frame(
    inference = rep(c("mcmc", "vb"), each = 3L),
    metric_role = rep(names(imir_v1_metric_labels), times = 2L),
    metric_label = rep(unname(imir_v1_metric_labels), times = 2L),
    expected_rows = 36L,
    width_inches = 7.2,
    height_inches = 6.6,
    png_dpi = 600L,
    point_shape = "x",
    interval_probability = 0.95,
    stringsAsFactors = FALSE
  )
}

imir_v1_plot_metric_intervals <- function(plot_data, inference, metric_role) {
  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    stop("ggplot2 is required to generate article interval figures.", call. = FALSE)
  }
  inference <- tolower(as.character(inference)[1L])
  metric_role <- as.character(metric_role)[1L]
  block <- plot_data[plot_data$inference == inference &
                       plot_data$metric_role == metric_role, , drop = FALSE]
  if (nrow(block) != 36L) {
    stop(sprintf("Expected 36 rows for %s/%s; found %d.", inference, metric_role,
                 nrow(block)), call. = FALSE)
  }
  title <- sprintf("%s: %s", ifelse(inference == "mcmc", "MCMC", "Variational Bayes"),
                   unname(imir_v1_metric_labels[[metric_role]]))
  subtitle <- if (inference == "mcmc") {
    "Posterior mean (x) and equal-tailed 95% credible interval"
  } else {
    "Variational posterior mean (x) and equal-tailed approximate 95% interval"
  }
  ggplot2::ggplot(
    block,
    ggplot2::aes(
      x = posterior_mean, y = model_label, xmin = cri_lower, xmax = cri_upper,
      colour = model_variant
    )
  ) +
    ggplot2::geom_errorbar(orientation = "y", width = 0.18, linewidth = 0.72) +
    ggplot2::geom_point(shape = 4, size = 2.8, stroke = 1.05) +
    ggplot2::facet_wrap(~panel_label, ncol = 3L, scales = "free_x") +
    ggplot2::scale_colour_manual(
      values = imir_v1_palette,
      breaks = names(imir_v1_model_labels),
      labels = unname(imir_v1_model_labels),
      drop = FALSE
    ) +
    ggplot2::scale_x_continuous(
      expand = ggplot2::expansion(mult = c(0.04, 0.06)),
      breaks = scales::breaks_pretty(n = 4L),
      labels = scales::label_number(accuracy = 0.01, trim = TRUE),
      guide = ggplot2::guide_axis(check.overlap = TRUE)
    ) +
    ggplot2::labs(
      title = title,
      subtitle = subtitle,
      x = unname(imir_v1_metric_labels[[metric_role]]),
      y = NULL,
      colour = NULL
    ) +
    ggplot2::theme_minimal(base_size = 9.5, base_family = "sans") +
    ggplot2::theme(
      plot.title = ggplot2::element_text(face = "bold", size = 11.5, hjust = 0),
      plot.subtitle = ggplot2::element_text(size = 9, colour = "#333333"),
      panel.grid.major.y = ggplot2::element_blank(),
      panel.grid.minor = ggplot2::element_blank(),
      panel.grid.major.x = ggplot2::element_line(colour = "#E3E3E3", linewidth = 0.3),
      strip.text = ggplot2::element_text(face = "bold", size = 8.6, lineheight = 0.95),
      strip.background = ggplot2::element_rect(fill = "#F3F3F3", colour = "#D0D0D0",
                                                linewidth = 0.35),
      axis.text.x = ggplot2::element_text(size = 7.4),
      axis.text.y = ggplot2::element_text(size = 7.8, colour = "#222222"),
      axis.title.x = ggplot2::element_text(size = 9, margin = ggplot2::margin(t = 5)),
      panel.spacing = grid::unit(1.15, "lines"),
      legend.position = "bottom",
      legend.text = ggplot2::element_text(size = 8),
      legend.key.width = grid::unit(1.1, "lines"),
      plot.margin = ggplot2::margin(7, 7, 5, 7)
    ) +
    ggplot2::guides(colour = ggplot2::guide_legend(
      override.aes = list(shape = 4, linewidth = 0.8), nrow = 1L
    ))
}

imir_v1_figure_filename <- function(inference, metric_role, extension) {
  sprintf("qdesn_validation_500obs_%s_%s_intervals.%s",
          tolower(inference), unname(imir_v1_metric_file_labels[[metric_role]]), extension)
}

imir_v1_save_plot <- function(plot, pdf_path, png_path, width = 7.2, height = 6.6,
                              dpi = 600L) {
  ffv2_ensure_dir(dirname(pdf_path))
  ggplot2::ggsave(pdf_path, plot = plot, device = grDevices::cairo_pdf,
                  width = width, height = height, units = "in", bg = "white")
  grDevices::png(
    filename = png_path, width = width, height = height, units = "in",
    res = dpi, type = "cairo", bg = "white"
  )
  on.exit(grDevices::dev.off(), add = TRUE)
  print(plot)
  grDevices::dev.off()
  on.exit(NULL, add = FALSE)
  invisible(c(pdf_path, png_path))
}

imir_v1_file_ledger <- function(paths, root) {
  paths <- normalizePath(paths, winslash = "/", mustWork = TRUE)
  root <- paste0(normalizePath(root, winslash = "/", mustWork = TRUE), "/")
  data.frame(
    relative_path = ifelse(startsWith(paths, root), substring(paths, nchar(root) + 1L), paths),
    bytes = as.numeric(file.info(paths)$size),
    sha256 = vapply(paths, ffv2_file_sha256, character(1L)),
    stringsAsFactors = FALSE
  )
}

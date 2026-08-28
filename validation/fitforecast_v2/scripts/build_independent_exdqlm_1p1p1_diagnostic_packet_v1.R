#!/usr/bin/env Rscript

cmd_args0 <- commandArgs(FALSE)
file_arg <- grep("^--file=", cmd_args0, value = TRUE)
this_file <- if (length(file_arg)) sub("^--file=", "", file_arg[[1L]]) else
  "validation/fitforecast_v2/scripts/build_independent_exdqlm_1p1p1_diagnostic_packet_v1.R"
harness_root <- normalizePath(file.path(dirname(this_file), ".."), winslash = "/",
                              mustWork = TRUE)
source(file.path(harness_root, "R", "utils.R"))
ffv2_source_all(harness_root)

args <- ffv2_parse_args()
repo_root <- normalizePath(args$`repo-root` %||% ffv2_repo_root(), winslash = "/",
                           mustWork = TRUE)
state_root <- normalizePath(args$`state-root` %||% "", winslash = "/", mustWork = TRUE)
materialization <- ffv2_read_json(
  file.path(state_root, "manifests", "materialization_manifest.json")
)
if (!identical(as.character(materialization$schema_version), i111_schema)) {
  stop("The diagnostic packet requires a completed exdqlm 1.1.1 rerun state.",
       call. = FALSE)
}
if (isTRUE(materialization$smoke)) {
  stop("The diagnostic packet requires the complete production closeout, not a smoke run.",
       call. = FALSE)
}
packet_root <- ffv2_resolve_path(
  args$`output-root` %||% file.path(
    state_root, "diagnostics", "independent_four_model_granular_diagnostics_1p1p1"
  ),
  repo_root = repo_root, must_work = FALSE
)
dir.create(packet_root, recursive = TRUE, showWarnings = FALSE)
plot_ready_path <- normalizePath(
  file.path(state_root, "closeout", "article_metric_role_intervals.csv"),
  winslash = "/", mustWork = TRUE
)
job_audit_path <- normalizePath(
  file.path(state_root, "closeout", "job_artifact_audit.csv"),
  winslash = "/", mustWork = TRUE
)

fig_dir <- file.path(packet_root, "figures")
tab_dir <- file.path(packet_root, "tables")
dir.create(fig_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(tab_dir, recursive = TRUE, showWarnings = FALSE)

if (!requireNamespace("ggplot2", quietly = TRUE)) {
  stop("The ggplot2 package is required.", call. = FALSE)
}

read_csv <- function(path, ...) {
  utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE, ...)
}
write_csv <- function(x, path) {
  utils::write.csv(x, path, row.names = FALSE, na = "")
  invisible(normalizePath(path, winslash = "/", mustWork = TRUE))
}
sha256 <- function(path) {
  out <- system2("sha256sum", path, stdout = TRUE)
  sub("[[:space:]].*$", "", out[[1L]])
}
git_rev <- function(root, ref = "HEAD") {
  out <- try(system2("git", c("-C", root, "rev-parse", ref), stdout = TRUE,
                     stderr = TRUE), silent = TRUE)
  if (inherits(out, "try-error") || !length(out)) "" else out[[1L]]
}

family_label <- function(x) {
  y <- as.character(x)
  y[y == "normal"] <- "Gaussian"
  y[y == "gausmix"] <- "Gaussian mixture"
  y[y == "laplace"] <- "Laplace"
  y
}
safe_family <- function(x) {
  y <- as.character(x)
  y[y == "normal"] <- "gaussian"
  y[y == "gausmix"] <- "gaussian_mixture"
  y
}
tau_label <- function(x) {
  out <- format(as.numeric(x), trim = TRUE, scientific = FALSE)
  out <- sub("0+$", "", out)
  out <- sub("[.]$", "", out)
  paste0("p = ", out)
}
safe_tau <- function(x) {
  paste0("p", gsub("[.]", "", sprintf("%.2f", as.numeric(x))))
}
likelihood_group <- function(x) {
  ifelse(as.character(x) %in% c("dqlm", "qdesn_al_rhs_ns"), "AL", "exAL")
}
model_class <- function(x) {
  ifelse(as.character(x) %in% c("dqlm", "exdqlm"), "DQLM / exDQLM", "Q-DESN")
}
variant_label <- function(x) {
  y <- as.character(x)
  y[y == "dqlm"] <- "AL: DQLM"
  y[y == "qdesn_al_rhs_ns"] <- "AL: Q-DESN"
  y[y == "exdqlm"] <- "exAL: exDQLM"
  y[y == "qdesn_exal_rhs_ns"] <- "exAL: Q-DESN"
  y
}
metric_label <- function(x) {
  y <- as.character(x)
  y[y == "fit"] <- "Fit RMSE"
  y[y == "forecast_mae"] <- "Forecast MAE"
  y[y == "forecast_rmse"] <- "Forecast RMSE"
  y[y == "forecast_check"] <- "Forecast check loss"
  y[y == "forecast_check_loss"] <- "Forecast check loss"
  y
}
case_label <- function(family, tau) {
  paste(family_label(family), tau_label(tau), sep = ", ")
}

theme_qdesn <- function(base_size = 10) {
  ggplot2::theme_minimal(base_size = base_size) +
    ggplot2::theme(
      plot.title.position = "plot",
      plot.title = ggplot2::element_text(face = "bold", size = base_size + 3),
      plot.subtitle = ggplot2::element_text(size = base_size),
      panel.grid.minor = ggplot2::element_blank(),
      panel.grid.major.x = ggplot2::element_line(linewidth = 0.18, colour = "#E6E6E6"),
      panel.grid.major.y = ggplot2::element_line(linewidth = 0.18, colour = "#E6E6E6"),
      axis.title = ggplot2::element_text(face = "bold"),
      strip.text = ggplot2::element_text(face = "bold", size = base_size - 1),
      strip.background = ggplot2::element_rect(fill = "#F2F2F2", colour = NA),
      legend.position = "bottom",
      legend.title = ggplot2::element_text(face = "bold"),
      plot.caption = ggplot2::element_text(hjust = 0, size = base_size - 2,
                                           colour = "#4A4A4A")
    )
}

palette_class <- c("DQLM / exDQLM" = "#666666", "Q-DESN" = "#0072B2")
palette_variant <- c(
  "AL: DQLM" = "#686868",
  "AL: Q-DESN" = "#0072B2",
  "exAL: exDQLM" = "#A56A2A",
  "exAL: Q-DESN" = "#D55E00"
)
palette_likelihood <- c("AL" = "#2A6F97", "exAL" = "#D55E00")

save_pdf <- function(plot, stem, width, height) {
  pdf_path <- file.path(fig_dir, paste0(stem, ".pdf"))
  ggplot2::ggsave(pdf_path, plot, width = width, height = height,
                  device = grDevices::cairo_pdf)
  data.frame(
    figure = stem,
    pdf_path = normalizePath(pdf_path, winslash = "/", mustWork = TRUE),
    pdf_sha256 = sha256(pdf_path),
    stringsAsFactors = FALSE
  )
}

summarise_group <- function(dat, keys, value_col) {
  split_id <- interaction(dat[keys], drop = TRUE, lex.order = TRUE)
  out <- lapply(split(dat, split_id), function(z) {
    values <- as.numeric(z[[value_col]])
    first <- z[1L, keys, drop = FALSE]
    data.frame(
      first,
      value = mean(values, na.rm = TRUE),
      lower = min(values, na.rm = TRUE),
      upper = max(values, na.rm = TRUE),
      n_chains = length(unique(z$chain_id)),
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, out)
}

plot_ready <- read_csv(plot_ready_path)
job_audit <- read_csv(job_audit_path)
plot_ready <- plot_ready[plot_ready$inference == "mcmc", , drop = FALSE]
plot_ready <- plot_ready[plot_ready$model_variant %in%
                           c("dqlm", "exdqlm", "qdesn_al_rhs_ns",
                             "qdesn_exal_rhs_ns"), , drop = FALSE]
if (nrow(plot_ready) != 108L) {
  stop(sprintf("Expected 108 MCMC metric rows; found %d.", nrow(plot_ready)),
       call. = FALSE)
}

plot_ready$likelihood_group <- likelihood_group(plot_ready$model_variant)
plot_ready$model_class <- model_class(plot_ready$model_variant)
plot_ready$variant_display <- variant_label(plot_ready$model_variant)
plot_ready$family_display <- family_label(plot_ready$family)
plot_ready$tau_display <- tau_label(plot_ready$tau)
plot_ready$case_display <- paste(plot_ready$family_display, plot_ready$tau_display,
                                 sep = "\n")
plot_ready$metric_display <- factor(
  metric_label(plot_ready$metric_role),
  levels = c("Fit RMSE", "Forecast MAE", "Forecast check loss")
)
plot_ready$variant_display <- factor(
  plot_ready$variant_display,
  levels = c("AL: DQLM", "AL: Q-DESN", "exAL: exDQLM", "exAL: Q-DESN")
)
write_csv(plot_ready, file.path(tab_dir, "rerun_mcmc_metric_rows.csv"))

artifact_paths_from_metric_draw <- function(path) {
  base <- basename(path)
  if (grepl("^row_[0-9]+_metric_draws[.]csv[.]gz$", base)) {
    root <- dirname(dirname(path))
    prefix <- sub("_metric_draws[.]csv[.]gz$", "", base)
    list(
      lead_path = file.path(root, "forecast_lead_metrics",
                            paste0(prefix, "_forecast_lead_metrics.csv")),
      forecast_path = file.path(root, "forecast_path_summaries",
                                paste0(prefix, "_forecast_path_summary.csv")),
      fit_path = file.path(root, "fit_path_summaries",
                           paste0(prefix, "_fit_path_summary.csv"))
    )
  } else {
    root <- dirname(dirname(path))
    list(
      lead_path = file.path(root, "tables", "forecast_lead_metrics.csv"),
      forecast_path = file.path(root, "tables", "forecast_rolling_origin_paths.csv"),
      fit_path = file.path(root, "tables", "fit_quantile_path_train.csv")
    )
  }
}

resolve_artifacts <- function(row) {
  matched <- job_audit[
    job_audit$inference == row$inference[[1L]] &
      job_audit$model_variant == row$model_variant[[1L]] &
      job_audit$family == row$family[[1L]] &
      abs(as.numeric(job_audit$tau) - as.numeric(row$tau[[1L]])) < 1e-9 &
      job_audit$replay_id == row$replay_id[[1L]],
    ,
    drop = FALSE
  ]
  if (nrow(matched) != 3L) {
    stop(sprintf("Could not resolve three chains for %s %s p=%s %s %s.",
                 row$model_variant[[1L]], row$family[[1L]], row$tau[[1L]],
                 row$metric_role[[1L]], row$replay_id[[1L]]), call. = FALSE)
  }
  rows <- lapply(seq_len(nrow(matched)), function(i) {
    p <- artifact_paths_from_metric_draw(matched$metric_draws_path[[i]])
    data.frame(
      article_row = row$article_row[[1L]],
      metric_role = row$metric_role[[1L]],
      model_variant = row$model_variant[[1L]],
      family = row$family[[1L]],
      tau = row$tau[[1L]],
      replay_id = row$replay_id[[1L]],
      chain_id = matched$chain_id[[i]],
      lead_path = p$lead_path,
      forecast_path = p$forecast_path,
      fit_path = p$fit_path,
      source_generation = "exdqlm_1p1p1_rerun_job_artifact_audit",
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}

metric_sources <- unique(plot_ready[, c("article_row", "inference", "model_variant",
                                        "family", "tau", "metric_role", "replay_id")])
source_map <- do.call(rbind, lapply(seq_len(nrow(metric_sources)), function(i) {
  resolve_artifacts(metric_sources[i, , drop = FALSE])
}))
source_map$likelihood_group <- likelihood_group(source_map$model_variant)
source_map$model_class <- model_class(source_map$model_variant)
source_map$variant_display <- variant_label(source_map$model_variant)
source_map$family_display <- family_label(source_map$family)
source_map$tau_display <- tau_label(source_map$tau)
source_map$case_display <- paste(source_map$family_display, source_map$tau_display,
                                 sep = "\n")
for (col in c("lead_path", "forecast_path", "fit_path")) {
  source_map[[paste0(col, "_exists")]] <- file.exists(source_map[[col]])
}
if (!all(source_map$lead_path_exists & source_map$forecast_path_exists &
         source_map$fit_path_exists)) {
  write_csv(source_map, file.path(tab_dir, "artifact_source_map_failed.csv"))
  stop("Some granular source files are missing; see artifact_source_map_failed.csv.",
       call. = FALSE)
}
write_csv(source_map, file.path(tab_dir, "artifact_source_map.csv"))

lead_metrics_for <- function(role, output_metric, value_col) {
  src <- source_map[source_map$metric_role == role, , drop = FALSE]
  pieces <- lapply(seq_len(nrow(src)), function(i) {
    x <- read_csv(src$lead_path[[i]])
    data.frame(
      family = src$family[[i]],
      tau = as.numeric(src$tau[[i]]),
      likelihood_group = src$likelihood_group[[i]],
      model_class = src$model_class[[i]],
      variant_display = src$variant_display[[i]],
      model_variant = src$model_variant[[i]],
      chain_id = src$chain_id[[i]],
      forecast_lead = as.integer(x$forecast_lead),
      metric = output_metric,
      value = as.numeric(x[[value_col]]),
      n_origins_scored = as.integer(x$n_origins_scored),
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, pieces)
}
lead_raw <- rbind(
  lead_metrics_for("forecast_mae", "forecast_mae", "forecast_qtrue_mae"),
  lead_metrics_for("forecast_mae", "forecast_rmse", "forecast_qtrue_rmse"),
  lead_metrics_for("forecast_check", "forecast_check", "forecast_pinball_mean")
)
lead_summary <- summarise_group(
  lead_raw,
  c("family", "tau", "likelihood_group", "model_class", "variant_display",
    "model_variant", "forecast_lead", "metric"),
  "value"
)
lead_summary$metric_display <- factor(metric_label(lead_summary$metric),
                                      levels = c("Forecast MAE", "Forecast RMSE",
                                                 "Forecast check loss"))
lead_summary$family_display <- family_label(lead_summary$family)
lead_summary$tau_display <- tau_label(lead_summary$tau)
lead_summary$case_display <- paste(lead_summary$family_display,
                                   lead_summary$tau_display, sep = "\n")
lead_summary$model_class <- factor(lead_summary$model_class,
                                   levels = c("DQLM / exDQLM", "Q-DESN"))
write_csv(lead_summary, file.path(tab_dir, "forecast_lead_profiles_for_plot.csv"))

read_forecast_path <- function(path) {
  x <- read_csv(path)
  qhat <- if ("qhat" %in% names(x)) x$qhat else if ("q_pred" %in% names(x)) x$q_pred else NA_real_
  lo <- if ("qhat_p0025" %in% names(x)) x$qhat_p0025 else if ("lo" %in% names(x)) x$lo else qhat
  hi <- if ("qhat_p0975" %in% names(x)) x$qhat_p0975 else if ("hi" %in% names(x)) x$hi else qhat
  data.frame(
    source_index = as.integer(x$source_index %||% x$target_source_index),
    y = as.numeric(x$y),
    q_true = as.numeric(x$q_true),
    qhat = as.numeric(qhat),
    lower = as.numeric(lo),
    upper = as.numeric(hi),
    abs_q_error = as.numeric(x$abs_q_error),
    squared_q_error = as.numeric(x$squared_q_error),
    check_loss = as.numeric(x$pinball_tau),
    forecast_origin_source_index = as.integer(x$forecast_origin_source_index),
    forecast_lead = as.integer(x$forecast_lead),
    origin_sequence_id = as.integer(x$origin_sequence_id),
    stringsAsFactors = FALSE
  )
}
`%||%` <- function(x, y) if (is.null(x)) y else x

forecast_metrics_for <- function(role, output_metric) {
  src <- source_map[source_map$metric_role == role, , drop = FALSE]
  pieces <- lapply(seq_len(nrow(src)), function(i) {
    x <- read_forecast_path(src$forecast_path[[i]])
    if (output_metric == "forecast_mae") {
      chain_by_origin <- stats::aggregate(
        value ~ origin_sequence_id, data.frame(origin_sequence_id = x$origin_sequence_id,
                                               value = x$abs_q_error),
        mean, na.rm = TRUE
      )
    } else if (output_metric == "forecast_rmse") {
      chain_by_origin <- stats::aggregate(
        value ~ origin_sequence_id, data.frame(origin_sequence_id = x$origin_sequence_id,
                                               value = x$squared_q_error),
        function(v) sqrt(mean(v, na.rm = TRUE))
      )
    } else {
      chain_by_origin <- stats::aggregate(
        value ~ origin_sequence_id, data.frame(origin_sequence_id = x$origin_sequence_id,
                                               value = x$check_loss),
        mean, na.rm = TRUE
      )
    }
    data.frame(
      family = src$family[[i]],
      tau = as.numeric(src$tau[[i]]),
      likelihood_group = src$likelihood_group[[i]],
      model_class = src$model_class[[i]],
      variant_display = src$variant_display[[i]],
      model_variant = src$model_variant[[i]],
      chain_id = src$chain_id[[i]],
      origin_sequence_id = as.integer(chain_by_origin$origin_sequence_id),
      metric = output_metric,
      value = as.numeric(chain_by_origin$value),
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, pieces)
}
origin_raw <- rbind(
  forecast_metrics_for("forecast_mae", "forecast_mae"),
  forecast_metrics_for("forecast_mae", "forecast_rmse"),
  forecast_metrics_for("forecast_check", "forecast_check")
)
origin_summary <- summarise_group(
  origin_raw,
  c("family", "tau", "likelihood_group", "model_class", "variant_display",
    "model_variant", "origin_sequence_id", "metric"),
  "value"
)
origin_summary$metric_display <- factor(metric_label(origin_summary$metric),
                                        levels = c("Forecast MAE", "Forecast RMSE",
                                                   "Forecast check loss"))
origin_summary$family_display <- family_label(origin_summary$family)
origin_summary$tau_display <- tau_label(origin_summary$tau)
origin_summary$case_display <- paste(origin_summary$family_display,
                                     origin_summary$tau_display, sep = "\n")
origin_summary$model_class <- factor(origin_summary$model_class,
                                     levels = c("DQLM / exDQLM", "Q-DESN"))
write_csv(origin_summary, file.path(tab_dir, "forecast_origin_profiles_for_plot.csv"))

heatmap_for <- function(role, output_metric) {
  src <- source_map[source_map$metric_role == role, , drop = FALSE]
  pieces <- lapply(seq_len(nrow(src)), function(i) {
    x <- read_forecast_path(src$forecast_path[[i]])
    value <- if (output_metric == "forecast_mae") x$abs_q_error else x$check_loss
    chain_grid <- stats::aggregate(
      value ~ origin_sequence_id + forecast_lead,
      data.frame(origin_sequence_id = x$origin_sequence_id,
                 forecast_lead = x$forecast_lead, value = value),
      mean, na.rm = TRUE
    )
    data.frame(
      family = src$family[[i]],
      tau = as.numeric(src$tau[[i]]),
      likelihood_group = src$likelihood_group[[i]],
      model_class = src$model_class[[i]],
      variant_display = src$variant_display[[i]],
      model_variant = src$model_variant[[i]],
      chain_id = src$chain_id[[i]],
      origin_sequence_id = chain_grid$origin_sequence_id,
      forecast_lead = chain_grid$forecast_lead,
      metric = output_metric,
      value = chain_grid$value,
      stringsAsFactors = FALSE
    )
  })
  raw <- do.call(rbind, pieces)
  summarise_group(
    raw,
    c("family", "tau", "likelihood_group", "model_class", "variant_display",
      "model_variant", "origin_sequence_id", "forecast_lead", "metric"),
    "value"
  )
}
heatmap_summary <- rbind(
  heatmap_for("forecast_mae", "forecast_mae"),
  heatmap_for("forecast_check", "forecast_check")
)
heatmap_summary$metric_display <- metric_label(heatmap_summary$metric)
heatmap_summary$family_display <- family_label(heatmap_summary$family)
heatmap_summary$tau_display <- tau_label(heatmap_summary$tau)
heatmap_summary$model_class <- factor(heatmap_summary$model_class,
                                      levels = c("DQLM / exDQLM", "Q-DESN"))
write_csv(heatmap_summary, file.path(tab_dir, "origin_horizon_heatmaps_for_plot.csv"))

path_summary_for <- function(role, source_type) {
  src <- source_map[source_map$metric_role == role, , drop = FALSE]
  pieces <- lapply(seq_len(nrow(src)), function(i) {
    path <- if (source_type == "forecast") src$forecast_path[[i]] else src$fit_path[[i]]
    x <- if (source_type == "forecast") read_forecast_path(path) else {
      y <- read_csv(path)
      if ("effective_train" %in% names(y)) {
        keep <- y$effective_train %in% c(TRUE, "TRUE", "true", 1L, "1")
        y <- y[keep, , drop = FALSE]
      }
      qhat <- if ("qhat" %in% names(y)) y$qhat else if ("q_pred" %in% names(y)) y$q_pred else NA_real_
      lo <- if ("qhat_p0025" %in% names(y)) y$qhat_p0025 else if ("lo" %in% names(y)) y$lo else qhat
      hi <- if ("qhat_p0975" %in% names(y)) y$qhat_p0975 else if ("hi" %in% names(y)) y$hi else qhat
      data.frame(
        source_index = as.integer(y$source_index),
        y = as.numeric(y$y),
        q_true = as.numeric(y$q_true),
        qhat = as.numeric(qhat),
        lower = as.numeric(lo),
        upper = as.numeric(hi),
        forecast_origin_source_index = NA_integer_,
        forecast_lead = NA_integer_,
        origin_sequence_id = NA_integer_,
        stringsAsFactors = FALSE
      )
    }
    data.frame(
      family = src$family[[i]],
      tau = as.numeric(src$tau[[i]]),
      likelihood_group = src$likelihood_group[[i]],
      model_class = src$model_class[[i]],
      variant_display = src$variant_display[[i]],
      model_variant = src$model_variant[[i]],
      chain_id = src$chain_id[[i]],
      source_index = x$source_index,
      y = x$y,
      q_true = x$q_true,
      qhat = x$qhat,
      lower = x$lower,
      upper = x$upper,
      forecast_origin_source_index = x$forecast_origin_source_index,
      forecast_lead = x$forecast_lead,
      origin_sequence_id = x$origin_sequence_id,
      stringsAsFactors = FALSE
    )
  })
  raw <- do.call(rbind, pieces)
  keys <- c("family", "tau", "likelihood_group", "model_class", "variant_display",
            "model_variant", "source_index")
  if (source_type == "forecast") {
    keys <- c(keys, "forecast_origin_source_index", "forecast_lead", "origin_sequence_id")
  }
  split_id <- interaction(raw[keys], drop = TRUE, lex.order = TRUE)
  out <- lapply(split(raw, split_id), function(z) {
    first <- z[1L, keys, drop = FALSE]
    data.frame(
      first,
      y = mean(z$y, na.rm = TRUE),
      q_true = mean(z$q_true, na.rm = TRUE),
      qhat = mean(z$qhat, na.rm = TRUE),
      lower = min(z$lower, na.rm = TRUE),
      upper = max(z$upper, na.rm = TRUE),
      n_chains = length(unique(z$chain_id)),
      stringsAsFactors = FALSE
    )
  })
  out <- do.call(rbind, out)
  out$family_display <- family_label(out$family)
  out$tau_display <- tau_label(out$tau)
  out$model_class <- factor(out$model_class, levels = c("DQLM / exDQLM", "Q-DESN"))
  out
}
forecast_path_summary <- path_summary_for("forecast_mae", "forecast")
fit_path_summary <- path_summary_for("fit", "fit")
fit_path_summary <- fit_path_summary[order(fit_path_summary$family, fit_path_summary$tau,
                                           fit_path_summary$model_variant,
                                           fit_path_summary$source_index), ]
fit_path_summary$fit_order <- ave(fit_path_summary$source_index,
                                  interaction(fit_path_summary$family,
                                              fit_path_summary$tau,
                                              fit_path_summary$model_variant),
                                  FUN = function(x) rank(x, ties.method = "first"))
write_csv(forecast_path_summary, file.path(tab_dir, "forecast_path_fans_for_plot.csv"))
write_csv(fit_path_summary, file.path(tab_dir, "fit_path_recovery_for_plot.csv"))

fig_manifest <- list()
add_figure <- function(plot, stem, width, height) {
  fig_manifest[[length(fig_manifest) + 1L]] <<- save_pdf(plot, stem, width, height)
}

p_agg <- ggplot2::ggplot(plot_ready, ggplot2::aes(
  x = posterior_mean, y = variant_display, xmin = cri_lower, xmax = cri_upper,
  colour = variant_display
)) +
  ggplot2::geom_vline(xintercept = 0, linewidth = 0.2, colour = "#D0D0D0") +
  ggplot2::geom_errorbarh(height = 0.16, linewidth = 0.35, alpha = 0.70) +
  ggplot2::geom_point(size = 1.2) +
  ggplot2::facet_grid(metric_display ~ case_display, scales = "free_x") +
  ggplot2::scale_colour_manual(values = palette_variant, drop = FALSE) +
  ggplot2::labs(
    title = "Pinned exdqlm 1.1.1 MCMC aggregate metric summaries",
    subtitle = "Each scenario/quantile panel shows all four model variants from the candidate rerun; no result is promoted by this packet.",
    x = "Metric value", y = NULL, colour = "Model variant",
    caption = "Lower values are better for all three displayed metrics."
  ) +
  theme_qdesn(8) +
  ggplot2::theme(axis.text.y = ggplot2::element_text(size = 6.6),
                 axis.text.x = ggplot2::element_text(size = 6.3),
                 strip.text.x = ggplot2::element_text(size = 6.5))
add_figure(p_agg, "figure_01_current_mcmc_aggregate_intervals", 18, 9.8)

ratio_base <- plot_ready
ratio_base$pair <- paste(ratio_base$family, ratio_base$tau,
                         ratio_base$metric_role, ratio_base$likelihood_group,
                         sep = "|")
ratio_rows <- list()
for (key in unique(ratio_base$pair)) {
  z <- ratio_base[ratio_base$pair == key, , drop = FALSE]
  if (unique(z$likelihood_group) == "AL") {
    baseline <- z[z$model_variant == "dqlm", , drop = FALSE]
    challenger <- z[z$model_variant == "qdesn_al_rhs_ns", , drop = FALSE]
  } else {
    baseline <- z[z$model_variant == "exdqlm", , drop = FALSE]
    challenger <- z[z$model_variant == "qdesn_exal_rhs_ns", , drop = FALSE]
  }
  if (nrow(baseline) == 1L && nrow(challenger) == 1L) {
    ratio_rows[[length(ratio_rows) + 1L]] <- data.frame(
      family = challenger$family,
      tau = challenger$tau,
      metric_role = challenger$metric_role,
      likelihood_group = challenger$likelihood_group,
      ratio = challenger$posterior_mean / baseline$posterior_mean,
      qdesn_value = challenger$posterior_mean,
      baseline_value = baseline$posterior_mean,
      stringsAsFactors = FALSE
    )
  }
}
ratio_df <- do.call(rbind, ratio_rows)
ratio_df$family_display <- family_label(ratio_df$family)
ratio_df$tau_display <- tau_label(ratio_df$tau)
ratio_df$metric_display <- factor(metric_label(ratio_df$metric_role),
                                  levels = c("Fit RMSE", "Forecast MAE",
                                             "Forecast check loss"))
write_csv(ratio_df, file.path(tab_dir, "qdesn_relative_to_baseline_ratios.csv"))

p_ratio <- ggplot2::ggplot(ratio_df, ggplot2::aes(
  x = factor(tau_display, levels = c("p = 0.05", "p = 0.25", "p = 0.5")),
  y = ratio, colour = likelihood_group, group = likelihood_group
)) +
  ggplot2::geom_hline(yintercept = 1, linetype = "dashed", colour = "#666666",
                      linewidth = 0.35) +
  ggplot2::geom_line(linewidth = 0.55) +
  ggplot2::geom_point(size = 1.5) +
  ggplot2::facet_grid(metric_display ~ family_display, scales = "free_y") +
  ggplot2::scale_colour_manual(values = palette_likelihood) +
  ggplot2::labs(
    title = "Q-DESN relative to the matching state-space baseline",
    subtitle = "Ratios compare Q-DESN with DQLM under AL, and Q-DESN with exDQLM under exAL.",
    x = "Quantile level", y = "Q-DESN / baseline metric ratio",
    colour = "Working likelihood",
    caption = "Values below one favor Q-DESN under the same likelihood."
  ) +
  theme_qdesn(10)
add_figure(p_ratio, "figure_02_qdesn_relative_to_baseline_ratios", 12, 8.4)

make_case_profile_plot <- function(data, family_value, tau_value, x_col, x_label,
                                   title, subtitle, caption) {
  z <- data[data$family == family_value & abs(as.numeric(data$tau) - tau_value) < 1e-9,
            ,
            drop = FALSE]
  z$likelihood_group <- factor(z$likelihood_group, levels = c("AL", "exAL"))
  ggplot2::ggplot(z, ggplot2::aes(
    x = .data[[x_col]], y = value, ymin = lower, ymax = upper,
    colour = model_class, fill = model_class
  )) +
    ggplot2::geom_ribbon(alpha = 0.10, colour = NA) +
    ggplot2::geom_line(linewidth = 0.55) +
    ggplot2::geom_point(size = 0.65, stroke = 0) +
    ggplot2::facet_grid(likelihood_group ~ metric_display, scales = "free_y") +
    ggplot2::scale_colour_manual(values = palette_class, drop = FALSE) +
    ggplot2::scale_fill_manual(values = palette_class, drop = FALSE) +
    ggplot2::labs(
      title = sprintf("%s: %s", case_label(family_value, tau_value), title),
      subtitle = subtitle,
      x = x_label, y = "Three-chain mean with chain range",
      colour = "Model class", fill = "Model class",
      caption = caption
    ) +
    theme_qdesn(10)
}

families <- c("normal", "laplace", "gausmix")
taus <- c(0.05, 0.25, 0.50)
for (fam in families) {
  for (tau in taus) {
    lead_plot <- make_case_profile_plot(
      lead_summary, fam, tau, "forecast_lead", "Forecast lead",
      "forecast scores by lead",
      "Rows control for the working likelihood; within each row the baseline is compared directly with Q-DESN.",
      "The ribbon is the range across the three MCMC chains for the lead-specific point summaries."
    ) + ggplot2::scale_x_continuous(breaks = c(1, 10, 20, 30))
    add_figure(
      lead_plot,
      paste0("figure_03_lead_profiles_", safe_family(fam), "_", safe_tau(tau)),
      12, 7.6
    )
    origin_plot <- make_case_profile_plot(
      origin_summary, fam, tau, "origin_sequence_id", "Forecast origin sequence",
      "forecast scores by origin",
      "Rows control for the working likelihood; profiles reveal localized difficult blocks and broad shifts.",
      "The ribbon is the range across the three MCMC chains after averaging over leads within each origin."
    ) + ggplot2::scale_x_continuous(breaks = c(1, 10, 20, 30, 34))
    add_figure(
      origin_plot,
      paste0("figure_04_origin_profiles_", safe_family(fam), "_", safe_tau(tau)),
      12, 7.6
    )
  }
}

make_heatmap_plot <- function(data, family_value, tau_value, metric_value,
                              title, fill_label, colours) {
  z <- data[data$family == family_value & abs(as.numeric(data$tau) - tau_value) < 1e-9 &
              data$metric == metric_value, , drop = FALSE]
  cap <- as.numeric(stats::quantile(z$value, 0.98, na.rm = TRUE))
  z$value_cap <- pmin(z$value, cap)
  z$likelihood_group <- factor(z$likelihood_group, levels = c("AL", "exAL"))
  ggplot2::ggplot(z, ggplot2::aes(
    x = forecast_lead, y = origin_sequence_id, fill = value_cap
  )) +
    ggplot2::geom_tile() +
    ggplot2::facet_grid(likelihood_group ~ model_class) +
    ggplot2::scale_fill_gradientn(colours = colours, name = fill_label) +
    ggplot2::scale_x_continuous(breaks = c(1, 10, 20, 30)) +
    ggplot2::scale_y_continuous(breaks = c(1, 10, 20, 30, 34)) +
    ggplot2::labs(
      title = sprintf("%s: %s", case_label(family_value, tau_value), title),
      subtitle = "Rows control for the working likelihood; columns compare the baseline with Q-DESN.",
      x = "Forecast lead", y = "Forecast origin sequence",
      caption = "Colours are capped at the 98th percentile within the page to preserve visible structure."
    ) +
    theme_qdesn(10) +
    ggplot2::theme(legend.position = "right")
}

for (fam in families) {
  for (tau in taus) {
    p_abs <- make_heatmap_plot(
      heatmap_summary, fam, tau, "forecast_mae",
      "absolute true-quantile error by origin and lead",
      "Absolute error",
      c("#F7FBFF", "#C6DBEF", "#6BAED6", "#2171B5", "#08306B")
    )
    add_figure(
      p_abs,
      paste0("figure_05_origin_horizon_abs_error_", safe_family(fam), "_",
             safe_tau(tau)),
      10.5, 7.6
    )
    p_check <- make_heatmap_plot(
      heatmap_summary, fam, tau, "forecast_check",
      "check loss by origin and lead",
      "Check loss",
      c("#FFFFE5", "#FEE391", "#FEC44F", "#EC7014", "#8C2D04")
    )
    add_figure(
      p_check,
      paste0("figure_06_origin_horizon_check_loss_", safe_family(fam), "_",
             safe_tau(tau)),
      10.5, 7.6
    )
  }
}

make_path_plot <- function(data, family_value, tau_value, source_type) {
  z <- data[data$family == family_value & abs(as.numeric(data$tau) - tau_value) < 1e-9,
            ,
            drop = FALSE]
  z$likelihood_group <- factor(z$likelihood_group, levels = c("AL", "exAL"))
  x_col <- if (source_type == "forecast") "source_index" else "fit_order"
  x_label <- if (source_type == "forecast") "Held-out observation" else
    "Training observation within the effective fit window"
  title <- if (source_type == "forecast") "official rolling forecast fans" else
    "fit-window quantile-path recovery"
  subtitle <- if (source_type == "forecast") {
    "Official origins are 30 observations apart with maximum lead 30; the displayed forecast blocks are adjacent."
  } else {
    "Fit RMSE is a path-recovery diagnostic over the effective training window."
  }
  caption <- if (source_type == "forecast") {
    "Black line: true conditional quantile. Coloured lines: forecast posterior means. Thin vertical intervals mark pointwise posterior bands at leads 1, 10, 20, and 30 within each official origin block."
  } else {
    "Black line: true conditional quantile. Coloured line: fitted posterior mean. Ribbon: pointwise posterior band envelope across chains."
  }
  z$x_value <- z[[x_col]]
  z$path_group <- if (source_type == "forecast") {
    interaction(z$model_class, z$likelihood_group, z$origin_sequence_id,
                drop = TRUE)
  } else {
    interaction(z$model_class, z$likelihood_group, drop = TRUE)
  }
  z <- z[order(z$likelihood_group, z$model_class, z$path_group, z$x_value),
         ,
         drop = FALSE]
  truth <- z[, c("likelihood_group", "model_class", "x_value", "q_true")]
  truth <- truth[!duplicated(truth), , drop = FALSE]
  truth <- truth[order(truth$likelihood_group, truth$model_class,
                       truth$x_value), , drop = FALSE]
  p <- ggplot2::ggplot()
  if (source_type == "forecast") {
    band <- z[z$forecast_lead %in% c(1L, 10L, 20L, 30L), , drop = FALSE]
    p <- p +
      ggplot2::geom_linerange(
        ggplot2::aes(x = x_value, ymin = lower, ymax = upper,
                     colour = model_class, group = path_group),
        data = band, alpha = 0.20, linewidth = 0.22
      )
  } else {
    p <- p +
      ggplot2::geom_ribbon(
        ggplot2::aes(ymin = lower, ymax = upper, x = x_value,
                     fill = model_class, group = path_group),
        data = z, alpha = 0.12, colour = NA
      )
  }
  p +
    ggplot2::geom_line(
      ggplot2::aes(x = x_value, y = q_true),
      data = truth, colour = "#111111", linewidth = 0.35
    ) +
    ggplot2::geom_line(
      ggplot2::aes(x = x_value, y = qhat, colour = model_class,
                   group = path_group),
      data = z, linewidth = 0.38, alpha = 0.92
    ) +
    ggplot2::facet_grid(likelihood_group ~ model_class, scales = "free_y") +
    ggplot2::scale_colour_manual(values = palette_class, drop = FALSE) +
    ggplot2::scale_fill_manual(values = palette_class, drop = FALSE) +
    ggplot2::labs(
      title = sprintf("%s: %s", case_label(family_value, tau_value), title),
      subtitle = subtitle,
      x = x_label, y = "Conditional quantile",
      colour = "Model class", fill = "Model class",
      caption = caption
    ) +
    theme_qdesn(10)
}

for (fam in families) {
  for (tau in taus) {
    p_forecast <- make_path_plot(forecast_path_summary, fam, tau, "forecast")
    add_figure(
      p_forecast,
      paste0("figure_07_forecast_path_fans_", safe_family(fam), "_", safe_tau(tau)),
      12, 7.8
    )
    p_fit <- make_path_plot(fit_path_summary, fam, tau, "fit")
    add_figure(
      p_fit,
      paste0("figure_08_fit_path_recovery_", safe_family(fam), "_", safe_tau(tau)),
      12, 7.8
    )
  }
}

fig_manifest <- do.call(rbind, fig_manifest)
write_csv(fig_manifest, file.path(tab_dir, "figure_manifest.csv"))

combined_pdf <- file.path(
  packet_root,
  "independent_four_model_granular_diagnostics_exdqlm_1p1p1_all_figures.pdf"
)
if (file.exists(combined_pdf)) unlink(combined_pdf)
pdf_files <- fig_manifest$pdf_path
if (nzchar(Sys.which("pdfunite"))) {
  status <- system2("pdfunite", c(pdf_files, combined_pdf))
} else if (nzchar(Sys.which("gs"))) {
  status <- system2("gs", c("-q", "-dNOPAUSE", "-dBATCH", "-sDEVICE=pdfwrite",
                            paste0("-sOutputFile=", combined_pdf), pdf_files))
} else {
  status <- 1L
}
if (!identical(as.integer(status), 0L) || !file.exists(combined_pdf)) {
  stop("Could not create the combined review PDF.", call. = FALSE)
}

summary_table <- data.frame(
  quantity = c(
    "validation_branch_head",
    "run_id",
    "package_version",
    "package_source_commit",
    "plot_ready_rows",
    "source_map_rows",
    "figures_created",
    "combined_pdf",
    "combined_pdf_sha256"
  ),
  value = c(
    git_rev(repo_root, "HEAD"),
    as.character(materialization$run_id),
    as.character(materialization$package_version),
    as.character(materialization$package_source_commit),
    nrow(plot_ready),
    nrow(source_map),
    nrow(fig_manifest),
    normalizePath(combined_pdf, winslash = "/", mustWork = TRUE),
    sha256(combined_pdf)
  ),
  stringsAsFactors = FALSE
)
write_csv(summary_table, file.path(tab_dir, "run_summary.csv"))

run_summary <- c(
  "# Independent four-model exdqlm 1.1.1 diagnostics run summary",
  "",
  sprintf("Generated: %s", format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")),
  "",
  "## Frozen rerun",
  "",
  sprintf("- Validation branch HEAD: `%s`", summary_table$value[summary_table$quantity == "validation_branch_head"]),
  sprintf("- Run ID: `%s`", summary_table$value[summary_table$quantity == "run_id"]),
  sprintf("- exdqlm version: `%s`", summary_table$value[summary_table$quantity == "package_version"]),
  sprintf("- Required source commit: `%s`", summary_table$value[summary_table$quantity == "package_source_commit"]),
  sprintf("- Plot-ready metric rows: `%s`", summary_table$value[summary_table$quantity == "plot_ready_rows"]),
  sprintf("- Source-map rows: `%s`", summary_table$value[summary_table$quantity == "source_map_rows"]),
  "",
  "## Outputs",
  "",
  sprintf("- Figures created: `%s`", summary_table$value[summary_table$quantity == "figures_created"]),
  sprintf("- Combined PDF: `%s`", summary_table$value[summary_table$quantity == "combined_pdf"]),
  sprintf("- Combined PDF SHA-256: `%s`", summary_table$value[summary_table$quantity == "combined_pdf_sha256"]),
  "",
  "## Interpretation",
  "",
  "The figures compare DQLM/exDQLM and Q-DESN within the same likelihood row under one pinned exdqlm 1.1.1 environment. Forecast MAE and forecast RMSE use the forecast-MAE source; forecast check loss uses the forecast-check-loss source. Fit-window displays use the fit-RMSE source. The official rolling forecast paths use the evaluated origin stride of 30 and maximum lead of 30, so the forecast blocks tile rather than overlap.",
  "",
  "## Promotion note",
  "",
  "These are diagnostic review figures. They do not edit article metrics, tables, captions, manuscript text, or Overleaf files."
)
writeLines(run_summary, file.path(packet_root, "RUN_SUMMARY.md"))

cat(sprintf("created_figures=%d combined_pdf=%s sha256=%s\n",
            nrow(fig_manifest), normalizePath(combined_pdf, winslash = "/", mustWork = TRUE),
            sha256(combined_pdf)))

#!/usr/bin/env Rscript

options(stringsAsFactors = FALSE)

args <- commandArgs(trailingOnly = TRUE)
if (!length(args)) {
  stop("Usage: Rscript scripts/online_vbld_make_diagnostics_pack.R <run_dir>", call. = FALSE)
}

run_dir <- normalizePath(args[[1L]], mustWork = TRUE)
tab_dir <- file.path(run_dir, "tables")
fig_dir <- file.path(run_dir, "figs")
if (!dir.exists(tab_dir)) stop("Missing tables dir: ", tab_dir, call. = FALSE)
if (!dir.exists(fig_dir)) stop("Missing figs dir: ", fig_dir, call. = FALSE)

need <- c("readr", "dplyr", "tidyr", "ggplot2", "tibble")
for (p in need) {
  if (!requireNamespace(p, quietly = TRUE)) {
    install.packages(p, repos = "https://cloud.r-project.org")
  }
}

suppressPackageStartupMessages({
  library(readr)
  library(dplyr)
  library(tidyr)
  library(ggplot2)
  library(tibble)
})

roll_mean <- function(x, w = 20L) {
  x <- as.numeric(x)
  n <- length(x)
  w <- max(1L, as.integer(w)[1L])
  if (!n) return(numeric(0))
  cs <- c(0, cumsum(x))
  out <- numeric(n)
  for (i in seq_len(n)) {
    lo <- max(1L, i - w + 1L)
    out[i] <- (cs[i + 1L] - cs[lo]) / (i - lo + 1L)
  }
  out
}

save_plot <- function(path, expr, width = 12, height = 5.4, dpi = 180) {
  p <- tryCatch(force(expr), error = function(e) {
    message("Skipping plot ", basename(path), ": ", conditionMessage(e))
    NULL
  })
  if (!is.null(p)) ggsave(path, p, width = width, height = height, dpi = dpi)
}

summary_path <- file.path(tab_dir, "run_summary.csv")
if (!file.exists(summary_path)) stop("Missing run summary: ", summary_path, call. = FALSE)
summary_df <- suppressMessages(readr::read_csv(summary_path, show_col_types = FALSE))

series_files <- list.files(tab_dir, pattern = "^series_.*\\.csv$", full.names = TRUE)
if (!length(series_files)) stop("No series files found in ", tab_dir, call. = FALSE)
series_df <- bind_rows(lapply(series_files, function(f) suppressMessages(readr::read_csv(f, show_col_types = FALSE))))
series_df <- series_df %>% arrange(run_label, t)

trace_files <- list.files(tab_dir, pattern = "^trace_.*\\.csv$", full.names = TRUE)
trace_df <- if (length(trace_files)) {
  bind_rows(lapply(trace_files, function(f) suppressMessages(readr::read_csv(f, show_col_types = FALSE)))) %>%
    arrange(run_label, t)
} else {
  tibble()
}

param_all_path <- file.path(tab_dir, "param_trace_all.csv")
param_df <- if (file.exists(param_all_path)) {
  suppressMessages(readr::read_csv(param_all_path, show_col_types = FALSE))
} else {
  param_files <- list.files(tab_dir, pattern = "^param_trace_.*\\.csv$", full.names = TRUE)
  if (length(param_files)) {
    bind_rows(lapply(param_files, function(f) suppressMessages(readr::read_csv(f, show_col_types = FALSE))))
  } else {
    tibble()
  }
}
if (nrow(param_df)) {
  if (!("run_label" %in% names(param_df))) param_df$run_label <- NA_character_
  if (!("trace_phase" %in% names(param_df))) param_df$trace_phase <- NA_character_
  param_df <- param_df %>% arrange(run_label, trace_phase, iter, t)
}

p0 <- 0.5
lock_path <- file.path(run_dir, "manifest", "case_study_lock.json")
if (file.exists(lock_path) && requireNamespace("jsonlite", quietly = TRUE)) {
  lock <- tryCatch(jsonlite::read_json(lock_path), error = function(e) NULL)
  if (!is.null(lock$target_quantile)) p0 <- as.numeric(lock$target_quantile)
}

stamp <- format(Sys.time(), "%Y%m%d-%H%M%S")
out_dir <- file.path(fig_dir, paste0("diagnostics_visual_pack_", stamp))
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

cols <- c(
  "run_label", "mode", "status", "runtime_sec", "check_loss_mean", "coverage",
  "coverage_error", "rmse_qtrue", "delta_check_vs_offline", "delta_rmse_qtrue_vs_offline",
  "n_jitter", "max_jitter_eps"
)
cols <- cols[cols %in% names(summary_df)]
readr::write_csv(summary_df %>% select(all_of(cols)), file.path(out_dir, "00_performance_dashboard.csv"))

run_levels <- unique(summary_df$run_label)
if ("offline" %in% run_levels) run_levels <- c("offline", setdiff(run_levels, "offline"))
series_df <- series_df %>% mutate(run_label = factor(run_label, levels = run_levels))
if (nrow(trace_df)) trace_df <- trace_df %>% mutate(run_label = factor(run_label, levels = run_levels))
if (nrow(param_df)) param_df <- param_df %>% mutate(run_label = factor(run_label, levels = run_levels))

base_obs <- series_df %>%
  filter(run_label == "offline") %>%
  distinct(t, y)
if (!nrow(base_obs)) base_obs <- series_df %>% distinct(t, y)

save_plot(
  file.path(out_dir, "01_overlay_offline_vs_online.png"),
  ggplot() +
    geom_line(data = base_obs, aes(x = t, y = y), color = "grey35", linewidth = 0.6, alpha = 0.8) +
    geom_line(data = series_df, aes(x = t, y = qhat, color = run_label), linewidth = 0.8) +
    labs(title = "Offline vs Online Predictions (Eval)", x = "t", y = "Value", color = "Run") +
    theme_minimal(base_size = 12)
)

err_col <- if ("abs_err_qtrue" %in% names(series_df) && any(is.finite(series_df$abs_err_qtrue))) {
  "abs_err_qtrue"
} else {
  NULL
}
if (is.null(err_col) && all(c("y", "qhat") %in% names(series_df))) {
  series_df <- series_df %>% mutate(abs_err_y = abs(y - qhat))
  err_col <- "abs_err_y"
}
if (!is.null(err_col)) {
  save_plot(
    file.path(out_dir, "02_error_trajectories.png"),
    ggplot(series_df, aes(x = t, y = .data[[err_col]], color = run_label)) +
      geom_line(linewidth = 0.7) +
      labs(title = "Absolute Error Trajectories", x = "t", y = "Absolute error", color = "Run") +
      theme_minimal(base_size = 12)
  )
}

if ("check_loss" %in% names(series_df)) {
  roll_df <- series_df %>%
    group_by(run_label) %>%
    arrange(t, .by_group = TRUE) %>%
    mutate(rolling_check = roll_mean(check_loss, 20L)) %>%
    ungroup()

  save_plot(
    file.path(out_dir, "03a_rolling_check_loss.png"),
    ggplot(roll_df, aes(x = t, y = rolling_check, color = run_label)) +
      geom_line(linewidth = 0.8) +
      labs(title = "Rolling Check-Loss (w=20)", x = "t", y = "Rolling check-loss", color = "Run") +
      theme_minimal(base_size = 12)
  )

  if ("offline" %in% unique(roll_df$run_label)) {
    off_roll <- roll_df %>% filter(run_label == "offline") %>% select(t, off_roll = rolling_check)
    delta_df <- roll_df %>%
      filter(run_label != "offline") %>%
      left_join(off_roll, by = "t") %>%
      mutate(delta_roll = rolling_check - off_roll)

    save_plot(
      file.path(out_dir, "03b_rolling_check_loss_delta_vs_offline.png"),
      ggplot(delta_df, aes(x = t, y = delta_roll, color = run_label)) +
        geom_hline(yintercept = 0, color = "grey45", linetype = 2, linewidth = 0.5) +
        geom_line(linewidth = 0.8) +
        labs(title = "Rolling Check-Loss Delta vs Offline", x = "t", y = "Delta", color = "Run") +
        theme_minimal(base_size = 12)
    )
  }
}

if (all(c("y", "qhat") %in% names(series_df))) {
  cov_df <- series_df %>%
    group_by(run_label) %>%
    arrange(t, .by_group = TRUE) %>%
    mutate(covered = as.numeric(y <= qhat), running_coverage = cumsum(covered) / row_number()) %>%
    ungroup()

  save_plot(
    file.path(out_dir, "04_running_coverage.png"),
    ggplot(cov_df, aes(x = t, y = running_coverage, color = run_label)) +
      geom_hline(yintercept = p0, color = "grey35", linetype = 2, linewidth = 0.6) +
      geom_line(linewidth = 0.8) +
      labs(title = sprintf("Running Coverage (target p=%.2f)", p0), x = "t", y = "Running coverage", color = "Run") +
      theme_minimal(base_size = 12)
  )
}

dist_cols <- character(0)
if ("check_loss" %in% names(series_df)) dist_cols <- c(dist_cols, "check_loss")
if ("abs_err_qtrue" %in% names(series_df) && any(is.finite(series_df$abs_err_qtrue))) dist_cols <- c(dist_cols, "abs_err_qtrue")
if (!length(dist_cols) && "abs_err_y" %in% names(series_df)) dist_cols <- c(dist_cols, "abs_err_y")
if (length(dist_cols)) {
  dist_df <- series_df %>%
    select(run_label, all_of(dist_cols)) %>%
    pivot_longer(cols = all_of(dist_cols), names_to = "metric", values_to = "value")

  save_plot(
    file.path(out_dir, "05_error_distributions.png"),
    ggplot(dist_df, aes(x = run_label, y = value, fill = run_label)) +
      geom_boxplot(outlier.alpha = 0.15) +
      facet_wrap(~ metric, scales = "free_y") +
      labs(title = "Error Distributions by Run", x = "Run", y = "Value") +
      theme_minimal(base_size = 12) +
      theme(legend.position = "none")
  )
}

if (nrow(trace_df) > 0) {
  if ("check_loss_pre" %in% names(trace_df)) {
    save_plot(
      file.path(out_dir, "06a_trace_preupdate_checkloss.png"),
      ggplot(trace_df, aes(x = t, y = check_loss_pre, color = run_label)) +
        geom_line(linewidth = 0.75) +
        labs(title = "Online Trace: Pre-update Check-Loss", x = "t", y = "check_loss_pre", color = "Run") +
        theme_minimal(base_size = 12)
    )
  }
  if ("jitter_eps" %in% names(trace_df)) {
    tr_j <- trace_df %>% mutate(log10_jitter = log10(pmax(as.numeric(jitter_eps), 1e-16)))
    save_plot(
      file.path(out_dir, "06b_trace_log10_jitter.png"),
      ggplot(tr_j, aes(x = t, y = log10_jitter, color = run_label)) +
        geom_line(linewidth = 0.75) +
        labs(title = "Online Trace: log10(jitter_eps)", x = "t", y = "log10(jitter_eps)", color = "Run") +
        theme_minimal(base_size = 12)
    )
  }
  msg_cols <- intersect(c("barw", "barm"), names(trace_df))
  if (length(msg_cols)) {
    tr_msg <- trace_df %>%
      select(run_label, t, all_of(msg_cols)) %>%
      pivot_longer(cols = all_of(msg_cols), names_to = "message", values_to = "value")
    save_plot(
      file.path(out_dir, "07_trace_local_messages.png"),
      ggplot(tr_msg, aes(x = t, y = value, color = run_label)) +
        geom_line(linewidth = 0.75) +
        facet_wrap(~ message, scales = "free_y", ncol = 1) +
        labs(title = "Online Trace: Local Message Diagnostics", x = "t", y = "value", color = "Run") +
        theme_minimal(base_size = 12),
      height = 7.4
    )
  }
}

if (nrow(param_df) > 0) {
  batch_param_df <- param_df %>%
    filter(trace_phase == "batch_iter") %>%
    mutate(iter = as.numeric(iter))

  if ("elbo" %in% names(batch_param_df) && any(is.finite(batch_param_df$elbo))) {
    save_plot(
      file.path(out_dir, "08_elbo_batch_trace.png"),
      ggplot(batch_param_df, aes(x = iter, y = elbo, color = run_label)) +
        geom_line(linewidth = 0.85) +
        labs(title = "ELBO Trace (Batch / Warm-Start)", x = "Iteration", y = "ELBO", color = "Run") +
        theme_minimal(base_size = 12)
    )
  }

  if (all(c("gamma", "sigma") %in% names(batch_param_df)) &&
      (any(is.finite(batch_param_df$gamma)) || any(is.finite(batch_param_df$sigma)))) {
    batch_gs_df <- batch_param_df %>%
      select(run_label, iter, gamma, sigma) %>%
      pivot_longer(cols = c(gamma, sigma), names_to = "param", values_to = "value")

    save_plot(
      file.path(out_dir, "09_gamma_sigma_batch_trace.png"),
      ggplot(batch_gs_df, aes(x = iter, y = value, color = run_label)) +
        geom_line(linewidth = 0.85) +
        facet_wrap(~ param, scales = "free_y", ncol = 1) +
        labs(title = "Gamma/Sigma Trace (Batch / Warm-Start)", x = "Iteration", y = "Value", color = "Run") +
        theme_minimal(base_size = 12),
      height = 7.2
    )
  }

  online_param_df <- param_df %>%
    filter(trace_phase == "online_step") %>%
    mutate(t = as.numeric(t))

  if (all(c("gamma", "sigma") %in% names(online_param_df)) &&
      nrow(online_param_df) &&
      (any(is.finite(online_param_df$gamma)) || any(is.finite(online_param_df$sigma)))) {
    online_gs_df <- online_param_df %>%
      select(run_label, t, gamma, sigma) %>%
      pivot_longer(cols = c(gamma, sigma), names_to = "param", values_to = "value")

    save_plot(
      file.path(out_dir, "10_gamma_sigma_online_trace.png"),
      ggplot(online_gs_df, aes(x = t, y = value, color = run_label)) +
        geom_line(linewidth = 0.85) +
        facet_wrap(~ param, scales = "free_y", ncol = 1) +
        labs(title = "Gamma/Sigma Trace (Online Streaming)", x = "t", y = "Value", color = "Run") +
        theme_minimal(base_size = 12),
      height = 7.2
    )
  }
}

readme <- c(
  "Online VB-LD Diagnostic Visual Pack",
  paste0("Run dir: ", run_dir),
  paste0("Generated: ", format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")),
  "",
  "Files:",
  "- 00_performance_dashboard.csv",
  "- 01_overlay_offline_vs_online.png",
  "- 02_error_trajectories.png",
  "- 03a_rolling_check_loss.png",
  "- 03b_rolling_check_loss_delta_vs_offline.png",
  "- 04_running_coverage.png",
  "- 05_error_distributions.png",
  "- 06a_trace_preupdate_checkloss.png",
  "- 06b_trace_log10_jitter.png",
  "- 07_trace_local_messages.png",
  "- 08_elbo_batch_trace.png",
  "- 09_gamma_sigma_batch_trace.png",
  "- 10_gamma_sigma_online_trace.png"
)
writeLines(readme, file.path(out_dir, "README.txt"))

cat(sprintf("diagnostics_pack=%s\n", out_dir))

#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(ggplot2)
})

safe_chr <- function(x, default) {
  v <- as.character(x)[1]
  if (!nzchar(v) || is.na(v)) default else v
}

tau_lab <- function(tau) gsub("\\.", "p", sprintf("%.2f", as.numeric(tau)[1]))

fit_file_path <- function(run_root, inference, model, tau) {
  file.path(run_root, "fits", inference, sprintf("%s_%s_tau_%s_fit.rds", inference, model, tau_lab(tau)))
}

vb_beta_summary <- function(fit) {
  beta_mean <- as.numeric(fit$qbeta$m)
  beta_sd <- rep(NA_real_, length(beta_mean))
  if (!is.null(fit$qbeta$V)) {
    Vb <- as.matrix(fit$qbeta$V)
    if (all(dim(Vb) == c(length(beta_mean), length(beta_mean)))) {
      beta_sd <- sqrt(pmax(diag(Vb), 0))
    }
  }
  z <- stats::qnorm(0.975)
  data.frame(
    beta_mean = beta_mean,
    beta_sd = beta_sd,
    ci_lo = beta_mean - z * beta_sd,
    ci_hi = beta_mean + z * beta_sd,
    stringsAsFactors = FALSE
  )
}

mcmc_beta_summary <- function(fit) {
  beta_draws <- as.matrix(fit$samp.beta)
  data.frame(
    beta_mean = colMeans(beta_draws),
    beta_sd = apply(beta_draws, 2, stats::sd),
    ci_lo = apply(beta_draws, 2, stats::quantile, probs = 0.025),
    ci_hi = apply(beta_draws, 2, stats::quantile, probs = 0.975),
    stringsAsFactors = FALSE
  )
}

load_fit_summary <- function(run_root, inference, model, tau) {
  fp <- fit_file_path(run_root, inference, model, tau)
  if (!file.exists(fp)) return(NULL)
  obj <- readRDS(fp)
  fit <- obj$fit
  summ <- if (identical(inference, "vb")) vb_beta_summary(fit) else mcmc_beta_summary(fit)
  beta_prior <- if (!is.null(fit$beta_prior$type)) as.character(fit$beta_prior$type)[1] else "ridge"
  data.frame(
    summ,
    inference = inference,
    model = model,
    tau = as.numeric(tau),
    beta_prior = beta_prior,
    runtime_sec = if (!is.null(fit$run.time)) as.numeric(fit$run.time)[1] else NA_real_,
    stringsAsFactors = FALSE
  )
}

metric_row <- function(df) {
  signal_mask <- df$is_signal
  near_mask <- df$is_near_zero
  zero_mask <- df$is_zero
  data.frame(
    beta_rmse_all = sqrt(mean(df$bias ^ 2)),
    beta_rmse_signal = if (any(signal_mask)) sqrt(mean(df$bias[signal_mask] ^ 2)) else NA_real_,
    beta_rmse_near_zero = if (any(near_mask)) sqrt(mean(df$bias[near_mask] ^ 2)) else NA_real_,
    beta_rmse_zero = if (any(zero_mask)) sqrt(mean(df$bias[zero_mask] ^ 2)) else NA_real_,
    mean_abs_est_zero = if (any(zero_mask)) mean(abs(df$beta_mean[zero_mask])) else NA_real_,
    mean_abs_est_near_zero = if (any(near_mask)) mean(abs(df$beta_mean[near_mask])) else NA_real_,
    mean_abs_bias_signal = if (any(signal_mask)) mean(abs(df$bias[signal_mask])) else NA_real_,
    support_tpr_signal = if (any(signal_mask)) mean(df$selected[signal_mask]) else NA_real_,
    support_rate_near_zero = if (any(near_mask)) mean(df$selected[near_mask]) else NA_real_,
    support_fpr_zero = if (any(zero_mask)) mean(df$selected[zero_mask]) else NA_real_,
    stringsAsFactors = FALSE
  )
}

plot_coef_recovery <- function(df, file_path, title_txt) {
  df$term <- factor(df$term, levels = rev(unique(df$term)))
  p <- ggplot(df, aes(x = beta_mean, y = term, color = beta_prior)) +
    geom_vline(xintercept = 0, color = "#DDDDDD", linewidth = 0.5) +
    geom_errorbar(aes(xmin = ci_lo, xmax = ci_hi), position = position_dodge(width = 0.65), width = 0.0, linewidth = 0.7, alpha = 0.9, orientation = "y") +
    geom_point(position = position_dodge(width = 0.65), size = 2.2) +
    geom_point(aes(x = beta_truth, y = term), inherit.aes = FALSE, shape = 4, size = 2.7, stroke = 1.0, color = "#111111") +
    facet_grid(group ~ ., scales = "free_y", space = "free_y") +
    scale_color_manual(values = c(ridge = "#1F77B4", rhs = "#D95F02")) +
    labs(
      title = title_txt,
      subtitle = "Points and intervals are posterior coefficient summaries; black x marks true coefficients",
      x = "coefficient value",
      y = NULL,
      color = "beta prior"
    ) +
    theme_minimal(base_size = 13) +
    theme(
      plot.title = element_text(face = "bold"),
      panel.grid.minor = element_blank(),
      legend.position = "top",
      strip.text.y = element_text(face = "bold")
    )
  ggsave(file_path, plot = p, width = 10.5, height = 8.5, dpi = 160)
}

plot_group_summary <- function(df, file_path) {
  df$group <- factor(df$group, levels = c("signal", "near_zero", "zero"))
  df$facet_label <- sprintf("%s @ tau=%.2f", toupper(df$model), df$tau)
  p <- ggplot(df, aes(x = group, y = mean_abs_est, fill = beta_prior)) +
    geom_col(position = position_dodge(width = 0.7), width = 0.62) +
    facet_grid(inference ~ facet_label) +
    scale_fill_manual(values = c(ridge = "#1F77B4", rhs = "#D95F02")) +
    labs(
      title = "Mean absolute coefficient estimate by coefficient group",
      x = "coefficient group",
      y = "mean |posterior coefficient mean|",
      fill = "beta prior"
    ) +
    theme_minimal(base_size = 12) +
    theme(
      plot.title = element_text(face = "bold"),
      panel.grid.minor = element_blank(),
      legend.position = "top",
      strip.text = element_text(face = "bold")
    )
  ggsave(file_path, plot = p, width = 13, height = 7.5, dpi = 160)
}

plot_support_summary <- function(df, file_path) {
  long <- rbind(
    data.frame(df[c("inference", "model", "tau", "beta_prior")], metric = "TPR signal", value = df$support_tpr_signal),
    data.frame(df[c("inference", "model", "tau", "beta_prior")], metric = "Select near-zero", value = df$support_rate_near_zero),
    data.frame(df[c("inference", "model", "tau", "beta_prior")], metric = "FPR zero", value = df$support_fpr_zero)
  )
  long$facet_label <- sprintf("%s @ tau=%.2f", toupper(long$model), long$tau)
  p <- ggplot(long, aes(x = metric, y = value, fill = beta_prior)) +
    geom_col(position = position_dodge(width = 0.72), width = 0.62) +
    facet_grid(inference ~ facet_label) +
    scale_fill_manual(values = c(ridge = "#1F77B4", rhs = "#D95F02")) +
    coord_cartesian(ylim = c(0, 1)) +
    labs(
      title = "Support diagnostics by prior",
      x = NULL,
      y = "rate",
      fill = "beta prior"
    ) +
    theme_minimal(base_size = 12) +
    theme(
      plot.title = element_text(face = "bold"),
      panel.grid.minor = element_blank(),
      legend.position = "top",
      strip.text = element_text(face = "bold")
    )
  ggsave(file_path, plot = p, width = 13, height = 7.5, dpi = 160)
}

plot_rmse_summary <- function(df, file_path) {
  long <- rbind(
    data.frame(df[c("inference", "model", "tau", "beta_prior")], metric = "RMSE all", value = df$beta_rmse_all),
    data.frame(df[c("inference", "model", "tau", "beta_prior")], metric = "RMSE signal", value = df$beta_rmse_signal),
    data.frame(df[c("inference", "model", "tau", "beta_prior")], metric = "RMSE near-zero", value = df$beta_rmse_near_zero),
    data.frame(df[c("inference", "model", "tau", "beta_prior")], metric = "RMSE zero", value = df$beta_rmse_zero)
  )
  long$facet_label <- sprintf("%s @ tau=%.2f", toupper(long$model), long$tau)
  p <- ggplot(long, aes(x = metric, y = value, fill = beta_prior)) +
    geom_col(position = position_dodge(width = 0.72), width = 0.62) +
    facet_grid(inference ~ facet_label, scales = "free_y") +
    scale_fill_manual(values = c(ridge = "#1F77B4", rhs = "#D95F02")) +
    labs(
      title = "Coefficient RMSE by prior and coefficient group",
      x = NULL,
      y = "RMSE",
      fill = "beta prior"
    ) +
    theme_minimal(base_size = 12) +
    theme(
      plot.title = element_text(face = "bold"),
      panel.grid.minor = element_blank(),
      legend.position = "top",
      strip.text = element_text(face = "bold")
    )
  ggsave(file_path, plot = p, width = 13, height = 7.5, dpi = 160)
}

sim_path <- safe_chr(Sys.getenv("EXDQLM_STATIC_SHRINK_SIM_PATH", ""), "")
ridge_run_root <- safe_chr(Sys.getenv("EXDQLM_STATIC_SHRINK_RIDGE_RUN_ROOT", ""), "")
rhs_run_root <- safe_chr(Sys.getenv("EXDQLM_STATIC_SHRINK_RHS_RUN_ROOT", ""), "")
if (!file.exists(sim_path)) stop("Missing EXDQLM_STATIC_SHRINK_SIM_PATH: ", sim_path)
if (!dir.exists(ridge_run_root)) stop("Missing ridge run root: ", ridge_run_root)
if (!dir.exists(rhs_run_root)) stop("Missing rhs run root: ", rhs_run_root)

default_out_root <- file.path(dirname(dirname(sim_path)), sprintf("shrinkage_compare_%s", format(Sys.time(), "%Y%m%d_%H%M%S")))
out_root <- safe_chr(Sys.getenv("EXDQLM_STATIC_SHRINK_OUT_ROOT", default_out_root), default_out_root)
dir.create(file.path(out_root, "tables"), recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(out_root, "plots", "coefficients"), recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(out_root, "plots", "diagnostics"), recursive = TRUE, showWarnings = FALSE)

sim <- readRDS(sim_path)
coef_truth <- sim$extras$coef_truth
if (is.null(coef_truth) || !is.data.frame(coef_truth)) {
  stop("sim$extras$coef_truth must be present for shrinkage comparison")
}

taus <- c(0.05, 0.50, 0.95)
inferences <- c("vb", "mcmc")
models <- c("al", "exal")
run_roots <- list(ridge = ridge_run_root, rhs = rhs_run_root)

coef_rows <- list()
for (prior_name in names(run_roots)) {
  run_root <- run_roots[[prior_name]]
  for (inference in inferences) {
    for (model in models) {
      for (tau in taus) {
        fit_sum <- load_fit_summary(run_root, inference, model, tau)
        if (is.null(fit_sum)) next
        truth_tau <- coef_truth[abs(coef_truth$tau - tau) < 1e-8, , drop = FALSE]
        fit_sum$term <- truth_tau$term
        fit_sum$group <- truth_tau$group
        fit_sum$beta_truth <- truth_tau$beta_truth
        fit_sum$abs_truth <- truth_tau$abs_truth
        fit_sum$is_zero <- truth_tau$is_zero
        fit_sum$is_near_zero <- truth_tau$is_near_zero
        fit_sum$is_signal <- truth_tau$is_signal
        fit_sum$bias <- fit_sum$beta_mean - fit_sum$beta_truth
        fit_sum$abs_error <- abs(fit_sum$bias)
        fit_sum$selected <- with(fit_sum, is.finite(ci_lo) & is.finite(ci_hi) & ((ci_lo > 0 & ci_hi > 0) | (ci_lo < 0 & ci_hi < 0)))
        fit_sum$run_root <- run_root
        coef_rows[[length(coef_rows) + 1L]] <- fit_sum
      }
    }
  }
}

coef_df <- do.call(rbind, coef_rows)
coef_df$group_simple <- ifelse(coef_df$is_signal, "signal", ifelse(coef_df$is_near_zero, "near_zero", ifelse(coef_df$is_zero, "zero", "other")))
write.csv(coef_df, file.path(out_root, "tables", "coefficient_recovery_long.csv"), row.names = FALSE)

summary_split <- split(coef_df, list(coef_df$inference, coef_df$model, coef_df$tau, coef_df$beta_prior), drop = TRUE)
summary_keys <- unique(coef_df[c("inference", "model", "tau", "beta_prior")])
summary_rows <- lapply(seq_len(nrow(summary_keys)), function(i) {
  key <- summary_keys[i, , drop = FALSE]
  ss <- coef_df[
    coef_df$inference == key$inference &
      coef_df$model == key$model &
      abs(coef_df$tau - key$tau) < 1e-8 &
      coef_df$beta_prior == key$beta_prior,
    ,
    drop = FALSE
  ]
  cbind(key, metric_row(ss))
})
summary_df <- do.call(rbind, summary_rows)
write.csv(summary_df, file.path(out_root, "tables", "coefficient_recovery_summary.csv"), row.names = FALSE)

group_keys <- unique(coef_df[c("inference", "model", "tau", "beta_prior", "group_simple")])
group_rows <- lapply(seq_len(nrow(group_keys)), function(i) {
  key <- group_keys[i, , drop = FALSE]
  ss <- coef_df[
    coef_df$inference == key$inference &
      coef_df$model == key$model &
      abs(coef_df$tau - key$tau) < 1e-8 &
      coef_df$beta_prior == key$beta_prior &
      coef_df$group_simple == key$group_simple,
    ,
    drop = FALSE
  ]
  cbind(key, data.frame(
    mean_abs_est = mean(abs(ss$beta_mean)),
    mean_abs_truth = mean(abs(ss$beta_truth)),
    rmse = sqrt(mean(ss$bias ^ 2)),
    selection_rate = mean(ss$selected),
    stringsAsFactors = FALSE
  ))
})
group_df <- do.call(rbind, group_rows)
names(group_df)[names(group_df) == "group_simple"] <- "group"
write.csv(group_df, file.path(out_root, "tables", "coefficient_group_summary.csv"), row.names = FALSE)

rhs_df <- summary_df[summary_df$beta_prior == "rhs", , drop = FALSE]
ridge_df <- summary_df[summary_df$beta_prior == "ridge", , drop = FALSE]
pair_df <- merge(rhs_df, ridge_df, by = c("inference", "model", "tau"), suffixes = c("_rhs", "_ridge"))
metric_names <- c(
  "beta_rmse_all", "beta_rmse_signal", "beta_rmse_near_zero", "beta_rmse_zero",
  "mean_abs_est_zero", "mean_abs_est_near_zero", "mean_abs_bias_signal",
  "support_tpr_signal", "support_rate_near_zero", "support_fpr_zero"
)
for (nm in metric_names) {
  pair_df[[paste0(nm, "_rhs_minus_ridge")]] <- pair_df[[paste0(nm, "_rhs")]] - pair_df[[paste0(nm, "_ridge")]]
}
write.csv(pair_df, file.path(out_root, "tables", "rhs_vs_ridge_summary.csv"), row.names = FALSE)

for (inference in inferences) {
  for (model in models) {
    for (tau in taus) {
      ss <- coef_df[coef_df$inference == inference & coef_df$model == model & abs(coef_df$tau - tau) < 1e-8, , drop = FALSE]
      if (!nrow(ss)) next
      plot_coef_recovery(
        ss,
        file.path(out_root, "plots", "coefficients", sprintf("%s_%s_tau_%s_coef_recovery.png", inference, model, tau_lab(tau))),
        sprintf("%s %s coefficient recovery (tau=%.2f)", toupper(inference), toupper(model), tau)
      )
    }
  }
}

group_plot_df <- group_df[group_df$group %in% c("signal", "near_zero", "zero"), , drop = FALSE]
if (nrow(group_plot_df)) {
  plot_group_summary(group_plot_df, file.path(out_root, "plots", "diagnostics", "mean_abs_est_by_group.png"))
}
if (nrow(summary_df)) {
  plot_support_summary(summary_df, file.path(out_root, "plots", "diagnostics", "support_rates_by_prior.png"))
  plot_rmse_summary(summary_df, file.path(out_root, "plots", "diagnostics", "coefficient_rmse_by_prior.png"))
}

summary_md <- file.path(out_root, "tables", "report_summary.md")
writeLines(c(
  "# Static Shrinkage Comparison Report",
  "",
  sprintf("- generated_at: `%s`", format(Sys.time(), "%Y-%m-%d %H:%M:%S")),
  sprintf("- sim_path: `%s`", sim_path),
  sprintf("- ridge_run_root: `%s`", ridge_run_root),
  sprintf("- rhs_run_root: `%s`", rhs_run_root),
  "",
  "## Core tables",
  "- `tables/coefficient_recovery_long.csv`",
  "- `tables/coefficient_recovery_summary.csv`",
  "- `tables/coefficient_group_summary.csv`",
  "- `tables/rhs_vs_ridge_summary.csv`",
  "",
  sprintf("- coefficient_rows: %d", nrow(coef_df)),
  sprintf("- summary_rows: %d", nrow(summary_df)),
  sprintf("- group_rows: %d", nrow(group_df)),
  sprintf("- plot_png_count: %d", length(list.files(file.path(out_root, "plots"), pattern = "\\.png$", recursive = TRUE, full.names = TRUE)))
), con = summary_md)

cat(sprintf("Shrinkage comparison outputs written under: %s\n", out_root))

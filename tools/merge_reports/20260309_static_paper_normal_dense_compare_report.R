#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(devtools)
  library(ggplot2)
})

devtools::load_all(".", quiet = TRUE)

run_root <- Sys.getenv("EXDQLM_PAPER_NORMAL_DENSE_RUN_ROOT", "")
if (!nzchar(run_root) || !dir.exists(run_root)) {
  stop("EXDQLM_PAPER_NORMAL_DENSE_RUN_ROOT must point to a completed run root")
}

sim_root <- dirname(run_root)
true_beta_path <- file.path(sim_root, "true_beta.csv")
sim_path <- file.path(sim_root, "fit_input_subsample_tt1000_mu_sorted", "sim_output.rds")
if (!file.exists(sim_path)) {
  sim_candidates <- Sys.glob(file.path(sim_root, "fit_input_subsample_tt*_mu_sorted", "sim_output.rds"))
  if (!length(sim_candidates)) stop("Could not locate quantile-specific sim_output.rds under ", sim_root)
  sim_path <- sim_candidates[[1]]
}
if (!file.exists(true_beta_path)) stop("Missing true_beta.csv under ", sim_root)

sim <- readRDS(sim_path)
true_beta <- utils::read.csv(true_beta_path, stringsAsFactors = FALSE)
tau <- as.numeric(sim$p)[1]
tau_tag <- gsub("\\.", "p", format(tau, nsmall = 2))

fit_specs <- data.frame(
  inference = c("vb", "vb", "mcmc", "mcmc"),
  model = c("al", "exal", "al", "exal"),
  fit_file = c(
    file.path(run_root, "fits", "vb", sprintf("vb_al_tau_%s_fit.rds", tau_tag)),
    file.path(run_root, "fits", "vb", sprintf("vb_exal_tau_%s_fit.rds", tau_tag)),
    file.path(run_root, "fits", "mcmc", sprintf("mcmc_al_tau_%s_fit.rds", tau_tag)),
    file.path(run_root, "fits", "mcmc", sprintf("mcmc_exal_tau_%s_fit.rds", tau_tag))
  ),
  stringsAsFactors = FALSE
)
if (!all(file.exists(fit_specs$fit_file))) {
  missing <- fit_specs$fit_file[!file.exists(fit_specs$fit_file)]
  stop("Missing fit files:\n", paste(missing, collapse = "\n"))
}

coef_rows <- lapply(seq_len(nrow(fit_specs)), function(i) {
  spec <- fit_specs[i, , drop = FALSE]
  fit <- .exdqlm_unwrap_fit_bundle(readRDS(spec$fit_file))$fit
  if (spec$inference == "vb") {
    beta_mean <- as.numeric(fit$qbeta$m)
    beta_sd <- if (!is.null(fit$qbeta$V)) sqrt(pmax(diag(as.matrix(fit$qbeta$V)), 0)) else rep(NA_real_, length(beta_mean))
    lo <- beta_mean - 1.96 * beta_sd
    hi <- beta_mean + 1.96 * beta_sd
  } else {
    beta_draws <- as.matrix(fit$samp.beta)
    beta_mean <- colMeans(beta_draws)
    lo <- apply(beta_draws, 2, stats::quantile, probs = 0.025)
    hi <- apply(beta_draws, 2, stats::quantile, probs = 0.975)
  }
  data.frame(
    inference = spec$inference,
    model = spec$model,
    term = true_beta$term,
    beta_true = true_beta$beta_true,
    beta_mean = beta_mean,
    beta_lo = as.numeric(lo),
    beta_hi = as.numeric(hi),
    abs_error = abs(beta_mean - true_beta$beta_true),
    stringsAsFactors = FALSE
  )
})
coef_df <- do.call(rbind, coef_rows)

summary_df <- aggregate(
  cbind(beta_rmse = (beta_mean - beta_true)^2, beta_mae = abs_error) ~ inference + model,
  data = transform(coef_df, beta_rmse = (beta_mean - beta_true)^2),
  FUN = mean
)
summary_df$beta_rmse <- sqrt(summary_df$beta_rmse)

tables_dir <- file.path(run_root, "tables")
plots_dir <- file.path(run_root, "plots", "paper_dense_compare")
dir.create(plots_dir, recursive = TRUE, showWarnings = FALSE)

utils::write.csv(coef_df, file.path(tables_dir, "paper_dense_coefficient_summary.csv"), row.names = FALSE)
utils::write.csv(summary_df, file.path(tables_dir, "paper_dense_coefficient_recovery_metrics.csv"), row.names = FALSE)

coef_df$label <- sprintf("%s-%s", toupper(coef_df$inference), toupper(coef_df$model))
coef_df$term <- factor(coef_df$term, levels = true_beta$term)

p_coef <- ggplot(coef_df, aes(x = term, y = beta_mean, ymin = beta_lo, ymax = beta_hi, color = label)) +
  geom_hline(aes(yintercept = beta_true), data = unique(coef_df[, c("term", "beta_true")]), color = "black", linewidth = 0.5, linetype = 2) +
  geom_pointrange(position = position_dodge(width = 0.55), linewidth = 0.45) +
  labs(
    title = "Paper-style normal dense benchmark: coefficient recovery",
    subtitle = "Posterior mean and 95% interval; dashed line is the true coefficient",
    x = "coefficient",
    y = "value",
    color = "fit"
  ) +
  theme_minimal(base_size = 13) +
  theme(
    plot.title = element_text(face = "bold"),
    axis.title = element_text(face = "bold"),
    legend.position = "bottom",
    panel.grid.minor = element_blank()
  )
ggplot2::ggsave(file.path(plots_dir, "paper_dense_coefficient_recovery.png"), p_coef, width = 13, height = 8, dpi = 160)

q_true <- as.numeric(sim$q[, 1])
X <- as.matrix(sim$extras$X)
obs_df <- data.frame(
  obs_id = seq_along(q_true),
  q_true = q_true,
  stringsAsFactors = FALSE
)
pred_rows <- lapply(seq_len(nrow(fit_specs)), function(i) {
  spec <- fit_specs[i, , drop = FALSE]
  fit <- .exdqlm_unwrap_fit_bundle(readRDS(spec$fit_file))$fit
  if (spec$inference == "vb") {
    q_hat <- as.numeric(drop(X %*% fit$qbeta$m))
  } else {
    q_hat <- as.numeric(drop(X %*% colMeans(as.matrix(fit$samp.beta))))
  }
  data.frame(obs_id = seq_along(q_hat), inference = spec$inference, model = spec$model, q_hat = q_hat, stringsAsFactors = FALSE)
})
pred_df <- do.call(rbind, pred_rows)
pred_df$label <- sprintf("%s-%s", toupper(pred_df$inference), toupper(pred_df$model))
pred_plot_df <- merge(pred_df, obs_df, by = "obs_id", all.x = TRUE)
pred_plot_df <- pred_plot_df[order(pred_plot_df$q_true, pred_plot_df$obs_id), ]
pred_plot_df$rank_id <- ave(pred_plot_df$obs_id, pred_plot_df$label, FUN = seq_along)

p_path <- ggplot(pred_plot_df, aes(x = rank_id, y = q_hat, color = label)) +
  geom_line(linewidth = 0.8) +
  geom_line(aes(y = q_true), color = "black", linewidth = 1.0, linetype = 2) +
  labs(
    title = "Predicted target quantile versus true target quantile",
    subtitle = "Observations sorted by true quantile value",
    x = "observation rank by true quantile",
    y = "quantile value",
    color = "fit"
  ) +
  theme_minimal(base_size = 13) +
  theme(
    plot.title = element_text(face = "bold"),
    axis.title = element_text(face = "bold"),
    legend.position = "bottom",
    panel.grid.minor = element_blank()
  )
ggplot2::ggsave(file.path(plots_dir, "paper_dense_quantile_path_compare.png"), p_path, width = 13, height = 8, dpi = 160)

writeLines(
  c(
    "# Paper-style normal dense benchmark review",
    "",
    sprintf("- run_root: `%s`", run_root),
    sprintf("- sim_path: `%s`", sim_path),
    "- benchmark: paper-style normal case with dense nonzero beta",
    sprintf("- target quantile: %.2f", tau),
    "- comparison: our AL vs our exAL, each under VB and MCMC, ridge prior",
    "",
    "## Coefficient recovery RMSE/MAE",
    "",
    paste(apply(summary_df, 1, function(r) {
      sprintf("- %s %s: beta_rmse=%.6f, beta_mae=%.6f", toupper(r[["inference"]]), toupper(r[["model"]]), as.numeric(r[["beta_rmse"]]), as.numeric(r[["beta_mae"]]))
    }), collapse = "\n")
  ),
  file.path(tables_dir, "paper_dense_compare_note.md")
)

cat(sprintf("Paper-style dense comparison outputs written under: %s\n", run_root))

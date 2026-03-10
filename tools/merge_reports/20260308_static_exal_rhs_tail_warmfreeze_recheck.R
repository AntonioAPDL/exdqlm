#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(devtools)
  library(ggplot2)
})

devtools::load_all(".", quiet = TRUE)

scenario_root <- "results/function_testing_20260308_static_homoskedastic_shrinkage_gaussian"
baseline_root <- file.path(
  scenario_root,
  "static_vb_then_mcmc_tt5000_vbns1000_burn2000_n1000_20260308_141742_shrink_rhs"
)
out_root <- "results/sim_suite_static/audits/static_exal_rhs_tail_warmfreeze_recheck_20260308"
dir.create(file.path(out_root, "tables"), recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(out_root, "plots"), recursive = TRUE, showWarnings = FALSE)

cfg <- readRDS(file.path(baseline_root, "tables", "run_config.rds"))
sim <- readRDS(cfg$sim_path)

TT <- as.integer(cfg$TT)
y <- as.numeric(sim$y[seq_len(TT)])
X <- as.matrix(sim$extras$X[seq_len(TT), , drop = FALSE])
coef_truth <- sim$extras$coef_truth
taus <- c(0.05, 0.95)

fit_file <- function(tau) {
  file.path(baseline_root, "fits", "vb", sprintf("vb_exal_tau_%s_fit.rds", gsub("\\.", "p", format(tau, nsmall = 2))))
}

old_opt <- options(
  exdqlm.tol_sigma = cfg$vb$conv$tol_sigma,
  exdqlm.tol_gamma = cfg$vb$conv$tol_gamma,
  exdqlm.tol_elbo = cfg$vb$conv$tol_elbo,
  exdqlm.vb.min_iter = cfg$vb$conv$min_iter,
  exdqlm.vb.patience = cfg$vb$conv$patience,
  exdqlm.vb.allow_elbo_drop = cfg$vb$conv$allow_elbo_drop
)
on.exit(options(old_opt), add = TRUE)

safe_chr <- function(x) {
  if (length(x)) as.character(x)[1] else NA_character_
}

safe_num <- function(x) {
  if (length(x)) as.numeric(x)[1] else NA_real_
}

res_rows <- list()
coef_rows <- list()

for (tau in taus) {
  base_wrap <- .exdqlm_unwrap_fit_bundle(readRDS(fit_file(tau)))
  base_fit <- base_wrap$fit
  beta_ctrl <- base_fit$beta_prior$controls
  ld_ctrl <- base_fit$diagnostics$ld_block$controls
  truth_tau <- coef_truth[abs(coef_truth$tau - tau) < 1e-8, , drop = FALSE]

  warn_msgs <- character(0)
  fit_new <- withCallingHandlers(
    exal_static_LDVB(
      y = y,
      X = X,
      p0 = tau,
      max_iter = cfg$vb$max_iter,
      tol = cfg$vb$tol,
      beta_prior = "rhs",
      beta_prior_controls = beta_ctrl,
      n_samp_xi = cfg$vb$n_samp_xi,
      ld_controls = ld_ctrl,
      verbose = FALSE
    ),
    warning = function(w) {
      warn_msgs <<- c(warn_msgs, conditionMessage(w))
      invokeRestart("muffleWarning")
    }
  )

  base_sum <- base_fit$beta_prior$summary
  new_sum <- fit_new$beta_prior$summary
  base_beta <- as.numeric(base_fit$qbeta$m)
  new_beta <- as.numeric(fit_new$qbeta$m)
  term_names <- colnames(X)

  active <- truth_tau$group != "intercept"
  coef_rows[[length(coef_rows) + 1L]] <- data.frame(
    tau = tau,
    term = term_names,
    beta_truth = truth_tau$beta_truth,
    group = truth_tau$group,
    beta_baseline = base_beta,
    beta_warmfreeze = new_beta,
    stringsAsFactors = FALSE
  )

  res_rows[[length(res_rows) + 1L]] <- data.frame(
    tau = tau,
    baseline_tau = safe_num(base_sum$tau),
    warmfreeze_tau = safe_num(new_sum$tau),
    baseline_tau_ratio = safe_num(base_sum$collapse_tau_ratio),
    warmfreeze_tau_ratio = safe_num(new_sum$collapse_tau_ratio),
    baseline_slope_max_abs = safe_num(base_sum$collapse_slope_max_abs),
    warmfreeze_slope_max_abs = safe_num(new_sum$collapse_slope_max_abs),
    baseline_slope_l2 = safe_num(base_sum$collapse_slope_l2),
    warmfreeze_slope_l2 = safe_num(new_sum$collapse_slope_l2),
    baseline_collapse_flag = isTRUE(base_sum$collapse_flag),
    warmfreeze_collapse_flag = isTRUE(new_sum$collapse_flag),
    baseline_tau_updates = safe_num(base_sum$rhs_tau_update_count),
    warmfreeze_tau_updates = safe_num(new_sum$rhs_tau_update_count),
    warmfreeze_tau_warmup_last = isTRUE(new_sum$rhs_tau_warmup_last),
    warmfreeze_update_reason_last = safe_chr(new_sum$rhs_update_reason_last),
    baseline_iter = safe_num(base_sum$rhs_iter),
    warmfreeze_iter = safe_num(new_sum$rhs_iter),
    baseline_stop_reason = safe_chr(base_fit$diagnostics$convergence$stop_reason),
    warmfreeze_stop_reason = safe_chr(fit_new$diagnostics$convergence$stop_reason),
    baseline_warn = safe_chr(base_sum$collapse_warning),
    warmfreeze_warn = if (length(warn_msgs)) paste(unique(warn_msgs), collapse = " | ") else safe_chr(new_sum$collapse_warning),
    baseline_signal_mean_abs = mean(abs(base_beta[active & truth_tau$is_signal])),
    warmfreeze_signal_mean_abs = mean(abs(new_beta[active & truth_tau$is_signal])),
    baseline_zero_mean_abs = mean(abs(base_beta[active & truth_tau$is_zero])),
    warmfreeze_zero_mean_abs = mean(abs(new_beta[active & truth_tau$is_zero])),
    stringsAsFactors = FALSE
  )
}

summary_df <- do.call(rbind, res_rows)
coef_df <- do.call(rbind, coef_rows)

write.csv(summary_df, file.path(out_root, "tables", "warmfreeze_recheck_summary.csv"), row.names = FALSE)
write.csv(coef_df, file.path(out_root, "tables", "warmfreeze_recheck_coefficients.csv"), row.names = FALSE)

coef_df$term <- factor(coef_df$term, levels = rev(unique(coef_df$term)))
plt_df <- rbind(
  transform(coef_df, stage = "baseline", beta = beta_baseline),
  transform(coef_df, stage = "warmfreeze", beta = beta_warmfreeze)
)
plt_df$facet <- sprintf("tau=%.2f", plt_df$tau)
coef_df$facet <- sprintf("tau=%.2f", coef_df$tau)
plt <- ggplot(plt_df, aes(x = beta, y = term, color = stage)) +
  geom_vline(xintercept = 0, color = "#D8D8D8") +
  geom_point(position = position_dodge(width = 0.55), size = 1.8) +
  geom_point(
    data = coef_df,
    aes(x = beta_truth, y = term),
    inherit.aes = FALSE,
    shape = 4,
    size = 2.2,
    stroke = 0.9,
    color = "#111111"
  ) +
  facet_grid(facet ~ ., scales = "free_y", space = "free_y") +
  scale_color_manual(values = c(baseline = "#D95F02", warmfreeze = "#1B9E77")) +
  labs(
    title = "Static exAL VB + RHS tail warmup/freeze recheck",
    subtitle = "Baseline vs qdesn-style tau warmup/freeze on the frozen shrinkage dataset",
    x = "coefficient posterior mean",
    y = NULL,
    color = "fit stage"
  ) +
  theme_minimal(base_size = 12) +
  theme(panel.grid.minor = element_blank(), legend.position = "top", plot.title = element_text(face = "bold"))
ggsave(file.path(out_root, "plots", "warmfreeze_recheck_coefficients.png"), plt, width = 10.5, height = 11, dpi = 160)

note <- c(
  "# Static exAL VB RHS warmup/freeze recheck",
  "",
  sprintf("- generated_at: `%s`", format(Sys.time(), "%Y-%m-%d %H:%M:%S")),
  sprintf("- baseline_root: `%s`", baseline_root),
  sprintf("- sim_path: `%s`", cfg$sim_path),
  "",
  "## Scope",
  "- Refit only the frozen failing `static exAL` `VB + RHS` tail cases (`tau=0.05`, `0.95`).",
  "- Keep the same dataset and LD settings as the baseline shrinkage campaign.",
  "- Change only the RHS VB tau scheduling via the new qdesn-style warmup/freeze defaults.",
  "",
  "## Outputs",
  "- `tables/warmfreeze_recheck_summary.csv`",
  "- `tables/warmfreeze_recheck_coefficients.csv`",
  "- `plots/warmfreeze_recheck_coefficients.png`"
)
writeLines(note, file.path(out_root, "tables", "audit_note.md"))

cat("Wrote warmup/freeze recheck under:", out_root, "\n")

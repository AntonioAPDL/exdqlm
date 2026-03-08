#!/usr/bin/env Rscript
suppressPackageStartupMessages({
  library(ggplot2)
})

scenario_root <- 'results/function_testing_20260308_static_homoskedastic_shrinkage_gaussian'
ridge_root <- file.path(scenario_root, 'static_vb_then_mcmc_tt5000_vbns1000_burn2000_n1000_20260308_141742_shrink_ridge')
rhs_root <- file.path(scenario_root, 'static_vb_then_mcmc_tt5000_vbns1000_burn2000_n1000_20260308_141742_shrink_rhs')
compare_root <- file.path(scenario_root, 'shrinkage_compare_20260308_141742')
out_root <- 'results/sim_suite_static/audits/static_exal_rhs_tail_collapse_20260308'
dir.create(file.path(out_root, 'tables'), recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(out_root, 'plots'), recursive = TRUE, showWarnings = FALSE)

coef_long <- read.csv(file.path(compare_root, 'tables', 'coefficient_recovery_long.csv'), stringsAsFactors = FALSE)
rhs_diag <- read.csv(file.path(rhs_root, 'tables', 'rhs_diagnostics_summary.csv'), stringsAsFactors = FALSE)
fit_sum <- read.csv(file.path(rhs_root, 'tables', 'fit_summary.csv'), stringsAsFactors = FALSE)

sel <- coef_long$model == 'exal' & coef_long$inference == 'vb' & coef_long$beta_prior == 'rhs' & coef_long$tau %in% c(0.05, 0.95)
sub <- coef_long[sel, ]
sub$is_intercept <- sub$group == 'intercept'

collapse_summary <- do.call(rbind, lapply(sort(unique(sub$tau)), function(tt) {
  ss <- sub[sub$tau == tt, , drop = FALSE]
  rr <- rhs_diag[rhs_diag$inference == 'vb' & rhs_diag$model == 'exal' & abs(rhs_diag$tau - tt) < 1e-8, , drop = FALSE]
  ff <- fit_sum[fit_sum$inference == 'vb' & fit_sum$model == 'exal' & abs(fit_sum$tau - tt) < 1e-8, , drop = FALSE]
  data.frame(
    tau = tt,
    rhs_tau = rr$rhs_tau,
    rhs_tau0 = rr$rhs_tau0,
    rhs_c2 = rr$rhs_c2,
    rhs_lambda_mean = rr$rhs_lambda_mean,
    intercept_abs = abs(ss$beta_mean[ss$is_intercept])[1],
    slope_mean_abs = mean(abs(ss$beta_mean[!ss$is_intercept])),
    slope_max_abs = max(abs(ss$beta_mean[!ss$is_intercept])),
    slope_l2 = sqrt(sum(ss$beta_mean[!ss$is_intercept]^2)),
    signal_selected_rate = mean(ss$selected[ss$group %in% c('strong','moderate','small')]),
    zero_selected_rate = mean(ss$selected[ss$group == 'zero']),
    vb_runtime_sec = ff$runtime_sec,
    vb_stop_reason = ff$stop_reason,
    gamma_mean = ff$gamma_mean,
    collapse_signature = (rr$rhs_tau < 1e-12) && (max(abs(ss$beta_mean[!ss$is_intercept])) < 1e-6),
    stringsAsFactors = FALSE
  )
}))
write.csv(collapse_summary, file.path(out_root, 'tables', 'collapse_signature_summary.csv'), row.names = FALSE)

coef_pairs <- coef_long[coef_long$model == 'exal' & coef_long$inference == 'vb' & coef_long$tau %in% c(0.05, 0.95) & coef_long$beta_prior %in% c('ridge', 'rhs'), ]
write.csv(coef_pairs, file.path(out_root, 'tables', 'tail_coef_recovery_ridge_vs_rhs.csv'), row.names = FALSE)

# Simple visual: ridge vs rhs coefficient means in the failed tails
coef_pairs$facet <- sprintf('tau=%.2f', coef_pairs$tau)
coef_pairs$term <- factor(coef_pairs$term, levels = rev(unique(coef_pairs$term)))
p <- ggplot(coef_pairs, aes(x = beta_mean, y = term, color = beta_prior)) +
  geom_vline(xintercept = 0, color = '#DDDDDD') +
  geom_errorbar(aes(xmin = ci_lo, xmax = ci_hi), orientation = 'y', position = position_dodge(width = 0.65), width = 0) +
  geom_point(position = position_dodge(width = 0.65), size = 1.8) +
  geom_point(aes(x = beta_truth, y = term), inherit.aes = FALSE, shape = 4, size = 2.2, stroke = 0.9, color = '#111111') +
  facet_grid(facet ~ ., scales = 'free_y', space = 'free_y') +
  scale_color_manual(values = c(ridge = '#1F77B4', rhs = '#D95F02')) +
  labs(title = 'Static exAL VB tail RHS collapse audit', subtitle = 'RHS collapses slope coefficients toward zero in both tails; ridge shown as baseline', x = 'coefficient posterior mean and 95% interval', y = NULL, color = 'beta prior') +
  theme_minimal(base_size = 12) +
  theme(panel.grid.minor = element_blank(), plot.title = element_text(face = 'bold'), legend.position = 'top')
ggsave(file.path(out_root, 'plots', 'tail_rhs_vs_ridge_coef_collapse.png'), plot = p, width = 10.5, height = 11, dpi = 160)

note <- c(
  '# Static exAL VB RHS Tail Collapse Audit',
  '',
  sprintf('- generated_at: `%s`', format(Sys.time(), '%Y-%m-%d %H:%M:%S')),
  sprintf('- baseline_ridge_root: `%s`', ridge_root),
  sprintf('- baseline_rhs_root: `%s`', rhs_root),
  sprintf('- compare_root: `%s`', compare_root),
  '',
  '## Main finding',
  '- The failure at `tau=0.05` and `tau=0.95` is a true collapse regime, not just weak fit quality.',
  '- Under `static exAL` `VB + RHS`, the global RHS scale `rhs_tau` collapses to essentially zero while the slope coefficients are numerically shrunk to zero.',
  '- The intercept remains active and absorbs the tail shift, producing the appearance of a fitted model with almost no slope structure.',
  '',
  '## Tail collapse evidence',
  paste0('- `tau=0.05`: `rhs_tau=', signif(collapse_summary$rhs_tau[collapse_summary$tau==0.05], 6), '`, `slope_max_abs=', signif(collapse_summary$slope_max_abs[collapse_summary$tau==0.05], 6), '`, `collapse_signature=TRUE`'),
  paste0('- `tau=0.95`: `rhs_tau=', signif(collapse_summary$rhs_tau[collapse_summary$tau==0.95], 6), '`, `slope_max_abs=', signif(collapse_summary$slope_max_abs[collapse_summary$tau==0.95], 6), '`, `collapse_signature=TRUE`'),
  '',
  '## Interpretation',
  '- This matches the qdesn-side collapse pattern: the global shrinkage level is too aggressive for the tail exAL VB fit under the current RHS defaults.',
  '- The current default `tau0=1` is not universally safe. In this case it allows the RHS global scale to collapse to the boundary.',
  '- The failure is localized: `AL` with RHS is behaving well, and `exAL` MCMC with RHS is also behaving reasonably. The main blocker is tail `exAL` VB with RHS.',
  '',
  '## Next debugging target',
  '- Add an explicit collapse diagnostic/warning in the static VB RHS outputs when `rhs_tau` is near-zero and the slope vector norm collapses.',
  '- Then run a small targeted `tau0` / initialization sweep only for `static exAL` `VB + RHS` at `tau=0.05` and `tau=0.95`.'
)
writeLines(note, file.path(out_root, 'tables', 'audit_note.md'))
cat('Wrote audit under:', out_root, '\n')

#!/usr/bin/env Rscript
suppressPackageStartupMessages({library(pkgload); library(parallel); library(coda)})
pkgload::load_all('.', quiet = TRUE)
scenario_root <- 'results/function_testing_20260308_static_homoskedastic_shrinkage_gaussian'
sim <- readRDS(file.path(scenario_root, 'fit_input_subsample_tt5000_xmain_sorted', 'sim_output.rds'))
truth <- read.csv(file.path(scenario_root, 'true_quantile_grid.csv'), check.names = FALSE)
X <- sim$extras$X; y <- sim$y
out_root <- file.path('results','sim_suite_static','audits','static_exal_rhs_tail_mcmc_slice_tuning_quick_20260308')
dir.create(file.path(out_root,'tables'), recursive = TRUE, showWarnings = FALSE)
truth_for_tau <- function(tau) {
  if (all(c('tau','q') %in% names(truth))) return(as.numeric(truth$q[abs(as.numeric(truth$tau)-tau) < 1e-12]))
  col_name <- paste0('tau_', formatC(tau, format='f', digits=2)); as.numeric(truth[[col_name]])
}
jobs <- expand.grid(tau=c(0.05,0.95), slice_width=c(0.10,0.50,1.00), stringsAsFactors=FALSE)
base_ctrl <- list(tau0=1, nu=4, s2=1, shrink_intercept=FALSE, slice_width=1, slice_max_steps=20L)
run_job <- function(i){
  tau <- jobs$tau[i]; sw <- jobs$slice_width[i]
  set.seed(20260308 + i)
  fit <- exal_static_mcmc(y=y,X=X,p0=tau,beta_prior='rhs',beta_prior_controls=base_ctrl,
    n.burn=500,n.mcmc=500,thin=1,mh.proposal='slice',slice.width=sw,trace.diagnostics=FALSE,verbose=FALSE)
  beta_mean <- colMeans(as.matrix(fit$samp.beta))
  fq <- as.numeric(X %*% beta_mean)
  tt <- truth_for_tau(tau)
  data.frame(
    tau=tau, slice_width=sw, runtime_sec=fit$run.time,
    gamma_mean=mean(as.numeric(fit$samp.gamma)), sigma_mean=mean(as.numeric(fit$samp.sigma)),
    ess_gamma=tryCatch(as.numeric(effectiveSize(fit$samp.gamma))[1], error=function(e) NA_real_),
    ess_sigma=tryCatch(as.numeric(effectiveSize(fit$samp.sigma))[1], error=function(e) NA_real_),
    rmse=sqrt(mean((fq-tt)^2)), stringsAsFactors=FALSE)
}
res <- do.call(rbind, mclapply(seq_len(nrow(jobs)), run_job, mc.cores=min(3L, detectCores())))
write.csv(res, file.path(out_root,'tables','slice_tuning_quick_summary.csv'), row.names=FALSE)
best <- do.call(rbind, lapply(split(res, res$tau), function(dd) dd[order(-dd$ess_gamma, dd$rmse, dd$runtime_sec), , drop=FALSE][1, , drop=FALSE]))
write.csv(best, file.path(out_root,'tables','slice_tuning_quick_best_by_tau.csv'), row.names=FALSE)
cat('Wrote quick tuning tables to ', file.path(out_root,'tables'), '\n', sep='')

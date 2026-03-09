#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(pkgload)
  library(parallel)
  library(coda)
})

pkgload::load_all(".", quiet = TRUE)

scenario_root <- "results/function_testing_20260308_static_homoskedastic_shrinkage_gaussian"
sim <- readRDS(file.path(scenario_root, "fit_input_subsample_tt5000_xmain_sorted", "sim_output.rds"))
truth <- read.csv(file.path(scenario_root, "true_quantile_grid.csv"), check.names = FALSE)

X <- sim$extras$X
y <- sim$y
x_main <- sim$extras$x_main

out_root <- file.path("results", "sim_suite_static", "audits", "static_exal_rhs_tail_mcmc_slice_tuning_20260308")
dir.create(file.path(out_root, "tables"), recursive = TRUE, showWarnings = FALSE)

taus <- c(0.05, 0.95)
slice_widths <- c(0.10, 0.25, 0.50, 1.00)

beta_prior_controls <- list(
  tau0 = 1,
  nu = 4,
  s2 = 1,
  shrink_intercept = FALSE,
  slice_width = 1,
  slice_max_steps = 20L
)

truth_for_tau <- function(tau) {
  col_name <- paste0("tau_", formatC(tau, format = "f", digits = 2))
  if (col_name %in% names(truth)) {
    return(truth[[col_name]])
  }
  if (all(c("tau", "q") %in% names(truth))) {
    idx <- abs(as.numeric(truth$tau) - tau) < 1e-12
    vals <- truth$q[idx]
    if (!length(vals)) stop("Missing truth rows for tau=", tau)
    return(as.numeric(vals))
  }
  stop("Missing truth representation for tau=", tau)
}

jobs <- expand.grid(
  tau = taus,
  slice_width = slice_widths,
  stringsAsFactors = FALSE
)

run_job <- function(i) {
  tau <- jobs$tau[i]
  sw <- jobs$slice_width[i]
  set.seed(20260308 + i)
  tryCatch({
    fit <- exal_static_mcmc(
      y = y,
      X = X,
      p0 = tau,
      beta_prior = "rhs",
      beta_prior_controls = beta_prior_controls,
      n.burn = 1000,
      n.mcmc = 1000,
      thin = 1,
      mh.proposal = "slice",
      slice.width = sw,
      trace.diagnostics = FALSE,
      verbose = FALSE
    )
    beta_mean <- colMeans(as.matrix(fit$samp.beta))
    fitted_quantile <- as.numeric(X %*% beta_mean)
    truth_tau <- truth_for_tau(tau)
    rmse <- sqrt(mean((fitted_quantile - truth_tau)^2))
    sigma_ess <- suppressWarnings(tryCatch(as.numeric(effectiveSize(fit$samp.sigma))[1], error = function(e) NA_real_))
    gamma_ess <- suppressWarnings(tryCatch(as.numeric(effectiveSize(fit$samp.gamma))[1], error = function(e) NA_real_))
    data.frame(
      tau = tau,
      slice_width = sw,
      status = "ok",
      error = NA_character_,
      runtime_sec = fit$run.time,
      sigma_mean = mean(as.numeric(fit$samp.sigma)),
      gamma_mean = mean(as.numeric(fit$samp.gamma)),
      ess_sigma = sigma_ess,
      ess_gamma = gamma_ess,
      rmse = rmse,
      stringsAsFactors = FALSE
    )
  }, error = function(e) {
    data.frame(
      tau = tau,
      slice_width = sw,
      status = "error",
      error = conditionMessage(e),
      runtime_sec = NA_real_,
      sigma_mean = NA_real_,
      gamma_mean = NA_real_,
      ess_sigma = NA_real_,
      ess_gamma = NA_real_,
      rmse = NA_real_,
      stringsAsFactors = FALSE
    )
  })
}

res <- do.call(rbind, mclapply(seq_len(nrow(jobs)), run_job, mc.cores = min(4L, detectCores())))
utils::write.csv(res, file.path(out_root, "tables", "slice_tuning_summary.csv"), row.names = FALSE)

ok_res <- res[res$status == "ok", , drop = FALSE]
best_rows <- do.call(rbind, lapply(split(ok_res, ok_res$tau), function(dd) {
  dd[order(-dd$ess_gamma, dd$rmse, dd$runtime_sec), , drop = FALSE][1, , drop = FALSE]
}))
utils::write.csv(best_rows, file.path(out_root, "tables", "slice_tuning_best_by_tau.csv"), row.names = FALSE)

cat("Wrote tuning tables to ", file.path(out_root, "tables"), "\n", sep = "")

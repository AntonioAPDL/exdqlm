#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(readr)
  library(ggplot2)
  library(dplyr)
  library(tidyr)
})

repo_root <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
pkgload::load_all(repo_root, quiet = TRUE)

out_root <- file.path(
  repo_root,
  "results/sim_suite_static/audits/exal_vb_ld_stabilization_20260309"
)
dir.create(file.path(out_root, "tables"), recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(out_root, "plots"), recursive = TRUE, showWarnings = FALSE)

`%||%` <- function(x, y) if (is.null(x)) y else x

sim <- readRDS(file.path(out_root, "sim_output_n100.rds"))
X <- sim$extras$X
y <- sim$y
q_true <- as.numeric(sim$q[, 1])
beta_true <- as.numeric(sim$extras$beta_true)
p0 <- sim$p

tail_cycle_metrics <- function(x, tail_n = 20L) {
  x <- as.numeric(x)
  x <- x[is.finite(x)]
  if (!length(x)) {
    return(c(lag1 = NA_real_, lag2 = NA_real_, mean_abs_diff = NA_real_, range = NA_real_))
  }
  x <- tail(x, min(length(x), tail_n))
  if (length(x) < 4L || length(unique(x)) < 2L) {
    return(c(
      lag1 = NA_real_,
      lag2 = NA_real_,
      mean_abs_diff = if (length(x) >= 2L) mean(abs(diff(x))) else NA_real_,
      range = diff(range(x))
    ))
  }
  c(
    lag1 = cor(x[-1L], x[-length(x)]),
    lag2 = cor(x[-(1:2)], x[-((length(x) - 1L):length(x))]),
    mean_abs_diff = mean(abs(diff(x))),
    range = diff(range(x))
  )
}

fit_summary_row <- function(name, fit) {
  ld_trace <- fit$diagnostics$ld_block$trace
  s_trace <- fit$diagnostics$s_block$trace
  gamma_metrics <- tail_cycle_metrics(ld_trace$gamma)
  sigma_metrics <- tail_cycle_metrics(ld_trace$sigma)
  s_metrics <- tail_cycle_metrics(s_trace$s_mean)
  tau2_metrics <- tail_cycle_metrics(s_trace$tau2_mean)
  beta_hat <- as.numeric(fit$qbeta$m)
  q_hat <- as.numeric(drop(X %*% beta_hat))
  mode_quality <- fit$diagnostics$ld_block$mode_quality
  stab <- fit$diagnostics$ld_block$stabilization

  tibble(
    case = name,
    converged = fit$diagnostics$convergence$converged,
    stop_reason = fit$diagnostics$convergence$stop_reason,
    iter = fit$iter,
    beta_rmse = sqrt(mean((beta_hat - beta_true)^2)),
    beta_max_abs = max(abs(beta_hat)),
    quantile_rmse = sqrt(mean((q_hat - q_true)^2)),
    ld_local_mode_pass = isTRUE(mode_quality$local_mode_pass),
    ld_grad_inf_norm = as.numeric(mode_quality$grad_inf_norm),
    ld_neg_hess_min_eig = as.numeric(mode_quality$neg_hess_min_eig),
    cycle_detect_count = stab$cycle_detect_count %||% NA_integer_,
    stabilized_iter_count = stab$stabilized_iter_count %||% NA_integer_,
    gamma_lag1 = gamma_metrics[["lag1"]],
    gamma_lag2 = gamma_metrics[["lag2"]],
    gamma_mean_abs_diff = gamma_metrics[["mean_abs_diff"]],
    sigma_lag1 = sigma_metrics[["lag1"]],
    sigma_lag2 = sigma_metrics[["lag2"]],
    sigma_mean_abs_diff = sigma_metrics[["mean_abs_diff"]],
    s_lag1 = s_metrics[["lag1"]],
    s_lag2 = s_metrics[["lag2"]],
    s_mean_abs_diff = s_metrics[["mean_abs_diff"]],
    tau2_lag1 = tau2_metrics[["lag1"]],
    tau2_lag2 = tau2_metrics[["lag2"]],
    tau2_mean_abs_diff = tau2_metrics[["mean_abs_diff"]]
  )
}

run_exal_mc <- function() {
  fit_path <- file.path(out_root, "exal_mc.rds")
  if (file.exists(fit_path)) return(readRDS(fit_path))
  fit <- exal_static_LDVB(
    y = y,
    X = X,
    p0 = p0,
    max_iter = 120,
    tol = 1e-4,
    n_samp_xi = 60,
    ld_controls = list(
      xi_method = "mc",
      xi_mode = "replicated",
      xi_replicates = 2L,
      reuse_draws = TRUE,
      reuse_seed = 20260309L,
      optimizer_method = "lbfgsb",
      direct_commit = TRUE,
      auto_stabilize = TRUE,
      store_trace = TRUE,
      sigma_init_mode = "data_scale"
    ),
    verbose = FALSE
  )
  saveRDS(fit, fit_path)
  fit
}

run_exal_mcmc_short <- function() {
  fit_path <- file.path(out_root, "exal_mcmc_short.rds")
  if (file.exists(fit_path)) return(readRDS(fit_path))
  fit <- exal_static_mcmc(
    y = y,
    X = X,
    p0 = p0,
    n.burn = 100,
    n.mcmc = 100,
    thin = 1,
    mh.proposal = "slice",
    trace.diagnostics = FALSE,
    verbose = FALSE
  )
  saveRDS(fit, fit_path)
  fit
}

fits <- list(
  al_reduced = readRDS(file.path(out_root, "al_reduced.rds")),
  exal_base = readRDS(file.path(out_root, "exal_base.rds")),
  exal_auto = readRDS(file.path(out_root, "exal_auto.rds")),
  exal_damped = readRDS(file.path(out_root, "exal_damped.rds")),
  exal_mc = run_exal_mc(),
  exal_mcmc_short = run_exal_mcmc_short()
)

al_row <- tibble(
  case = "al_reduced",
  converged = fits$al_reduced$diagnostics$convergence$converged,
  stop_reason = fits$al_reduced$diagnostics$convergence$stop_reason,
  iter = fits$al_reduced$iter,
  beta_rmse = sqrt(mean((as.numeric(fits$al_reduced$qbeta$m) - beta_true)^2)),
  beta_max_abs = max(abs(as.numeric(fits$al_reduced$qbeta$m))),
  quantile_rmse = sqrt(mean((drop(X %*% fits$al_reduced$qbeta$m) - q_true)^2)),
  ld_local_mode_pass = NA,
  ld_grad_inf_norm = NA_real_,
  ld_neg_hess_min_eig = NA_real_,
  cycle_detect_count = NA_integer_,
  stabilized_iter_count = NA_integer_,
  gamma_lag1 = NA_real_,
  gamma_lag2 = NA_real_,
  gamma_mean_abs_diff = NA_real_,
  sigma_lag1 = NA_real_,
  sigma_lag2 = NA_real_,
  sigma_mean_abs_diff = NA_real_,
  s_lag1 = tail_cycle_metrics(fits$al_reduced$diagnostics$s_block$trace$s_mean)[["lag1"]],
  s_lag2 = tail_cycle_metrics(fits$al_reduced$diagnostics$s_block$trace$s_mean)[["lag2"]],
  s_mean_abs_diff = tail_cycle_metrics(fits$al_reduced$diagnostics$s_block$trace$s_mean)[["mean_abs_diff"]],
  tau2_lag1 = tail_cycle_metrics(fits$al_reduced$diagnostics$s_block$trace$tau2_mean)[["lag1"]],
  tau2_lag2 = tail_cycle_metrics(fits$al_reduced$diagnostics$s_block$trace$tau2_mean)[["lag2"]],
  tau2_mean_abs_diff = tail_cycle_metrics(fits$al_reduced$diagnostics$s_block$trace$tau2_mean)[["mean_abs_diff"]]
)

vb_rows <- bind_rows(
  fit_summary_row("exal_base", fits$exal_base),
  fit_summary_row("exal_auto", fits$exal_auto),
  fit_summary_row("exal_damped", fits$exal_damped),
  fit_summary_row("exal_mc", fits$exal_mc)
)

mcmc_row <- tibble(
  case = "exal_mcmc_short",
  converged = NA,
  stop_reason = "mcmc",
  iter = nrow(fits$exal_mcmc_short$samp.beta),
  beta_rmse = sqrt(mean((colMeans(fits$exal_mcmc_short$samp.beta) - beta_true)^2)),
  beta_max_abs = max(abs(colMeans(fits$exal_mcmc_short$samp.beta))),
  quantile_rmse = sqrt(mean((drop(X %*% colMeans(fits$exal_mcmc_short$samp.beta)) - q_true)^2)),
  ld_local_mode_pass = NA,
  ld_grad_inf_norm = NA_real_,
  ld_neg_hess_min_eig = NA_real_,
  cycle_detect_count = NA_integer_,
  stabilized_iter_count = NA_integer_,
  gamma_lag1 = tail_cycle_metrics(fits$exal_mcmc_short$samp.gamma)[["lag1"]],
  gamma_lag2 = tail_cycle_metrics(fits$exal_mcmc_short$samp.gamma)[["lag2"]],
  gamma_mean_abs_diff = tail_cycle_metrics(fits$exal_mcmc_short$samp.gamma)[["mean_abs_diff"]],
  sigma_lag1 = tail_cycle_metrics(fits$exal_mcmc_short$samp.sigma)[["lag1"]],
  sigma_lag2 = tail_cycle_metrics(fits$exal_mcmc_short$samp.sigma)[["lag2"]],
  sigma_mean_abs_diff = tail_cycle_metrics(fits$exal_mcmc_short$samp.sigma)[["mean_abs_diff"]],
  s_lag1 = tail_cycle_metrics(rowMeans(fits$exal_mcmc_short$samp.s))[["lag1"]],
  s_lag2 = tail_cycle_metrics(rowMeans(fits$exal_mcmc_short$samp.s))[["lag2"]],
  s_mean_abs_diff = tail_cycle_metrics(rowMeans(fits$exal_mcmc_short$samp.s))[["mean_abs_diff"]],
  tau2_lag1 = NA_real_,
  tau2_lag2 = NA_real_,
  tau2_mean_abs_diff = NA_real_
)

summary_all <- bind_rows(al_row, vb_rows, mcmc_row)
write_csv(summary_all, file.path(out_root, "tables", "ld_stabilization_summary.csv"))

trace_long <- bind_rows(
  fits$exal_base$diagnostics$ld_block$trace %>% mutate(case = "exal_base"),
  fits$exal_auto$diagnostics$ld_block$trace %>% mutate(case = "exal_auto"),
  fits$exal_damped$diagnostics$ld_block$trace %>% mutate(case = "exal_damped"),
  fits$exal_mc$diagnostics$ld_block$trace %>% mutate(case = "exal_mc")
) %>%
  select(case, iter, gamma, sigma, ld_cycle_detected, ld_stabilized)

s_long <- bind_rows(
  fits$exal_base$diagnostics$s_block$trace %>% mutate(case = "exal_base"),
  fits$exal_auto$diagnostics$s_block$trace %>% mutate(case = "exal_auto"),
  fits$exal_damped$diagnostics$s_block$trace %>% mutate(case = "exal_damped"),
  fits$exal_mc$diagnostics$s_block$trace %>% mutate(case = "exal_mc")
) %>%
  select(case, iter, s_mean, tau2_mean, ld_cycle_detected, ld_stabilized)

write_csv(trace_long, file.path(out_root, "tables", "ld_trace_long.csv"))
write_csv(s_long, file.path(out_root, "tables", "s_trace_long.csv"))

plot_tail <- function(df, value_col, title, file_name) {
  p <- ggplot(df %>% group_by(case) %>% slice_tail(n = 40), aes(x = iter, y = .data[[value_col]], color = case)) +
    geom_line(linewidth = 0.6) +
    facet_wrap(~ case, scales = "free_y") +
    theme_minimal(base_size = 11) +
    theme(legend.position = "none") +
    labs(title = title, x = "Iteration", y = value_col)
  ggsave(file.path(out_root, "plots", file_name), p, width = 10, height = 6, dpi = 180)
}

plot_tail(trace_long, "gamma", "Tail gamma traces by stabilization variant", "tail_gamma_traces.png")
plot_tail(trace_long, "sigma", "Tail sigma traces by stabilization variant", "tail_sigma_traces.png")
plot_tail(s_long, "s_mean", "Tail s_mean traces by stabilization variant", "tail_s_mean_traces.png")
plot_tail(s_long, "tau2_mean", "Tail tau2_mean traces by stabilization variant", "tail_tau2_mean_traces.png")

note <- c(
  "# Static exAL VB LD stabilization audit",
  "",
  "- Data: current paper-style dense normal tau=0.05 sim, reduced deterministically to n=100.",
  "- Goal: compare base exAL VB against stabilization variants on the exact same data.",
  "- Cases: exal_base, exal_auto, exal_damped, exal_mc, plus AL and short MCMC references.",
  "- Main table: `ld_stabilization_summary.csv`."
)
writeLines(note, file.path(out_root, "tables", "audit_note.md"))

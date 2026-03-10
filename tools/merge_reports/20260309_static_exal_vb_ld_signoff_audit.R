#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(pkgload)
  library(readr)
  library(dplyr)
  library(tibble)
})

repo_root <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
pkgload::load_all(repo_root, quiet = TRUE)

`%||%` <- function(x, y) if (is.null(x)) y else x

source_sim <- file.path(
  repo_root,
  "results/function_testing_20260309_static_paper_normal_dense_nonzero_qspec/tau_0p05/fit_input_subsample_tt10000_mu_sorted/sim_output.rds"
)
stopifnot(file.exists(source_sim))
sim <- readRDS(source_sim)

idx <- unique(round(seq(1, length(sim$y), length.out = 100)))
idx <- idx[idx >= 1 & idx <= length(sim$y)]

sim_n100 <- sim
sim_n100$y <- sim$y[idx]
sim_n100$q <- sim$q[idx, , drop = FALSE]
sim_n100$extras$mu <- sim$extras$mu[idx]
sim_n100$extras$sigma <- sim$extras$sigma[idx]
sim_n100$extras$x_main <- sim$extras$x_main[idx]
sim_n100$extras$X <- sim$extras$X[idx, , drop = FALSE]
sim_n100$extras$source_index <- idx
sim_n100$extras$source_n <- nrow(sim$extras$X)
sim_n100$info$subsample <- list(
  source_n = nrow(sim$extras$X),
  fit_n = length(idx),
  source_index = idx
)

out_root <- file.path(
  repo_root,
  "results/sim_suite_static/audits/exal_vb_ld_signoff_20260309"
)
dir.create(out_root, recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(out_root, "tables"), showWarnings = FALSE)
saveRDS(sim_n100, file.path(out_root, "sim_output_n100.rds"))

X <- sim_n100$extras$X
y <- sim_n100$y
q_true <- as.numeric(sim_n100$q[, 1])
beta_true <- as.numeric(sim_n100$extras$beta_true)
p0 <- sim_n100$p

tail_sd <- function(x, tail_n = 25L) {
  x <- as.numeric(x)
  x <- x[is.finite(x)]
  if (!length(x)) return(NA_real_)
  stats::sd(utils::tail(x, min(length(x), tail_n)))
}

tail_cycle_metrics <- function(x, tail_n = 25L) {
  x <- as.numeric(x)
  x <- x[is.finite(x)]
  if (!length(x)) {
    return(c(lag1 = NA_real_, lag2 = NA_real_, mean_abs_diff = NA_real_, range = NA_real_))
  }
  x <- utils::tail(x, min(length(x), tail_n))
  if (length(x) < 4L || length(unique(x)) < 2L) {
    return(c(
      lag1 = NA_real_,
      lag2 = NA_real_,
      mean_abs_diff = if (length(x) >= 2L) mean(abs(diff(x))) else NA_real_,
      range = diff(range(x))
    ))
  }
  c(
    lag1 = stats::cor(x[-1L], x[-length(x)]),
    lag2 = stats::cor(x[-(1:2)], x[-((length(x) - 1L):length(x))]),
    mean_abs_diff = mean(abs(diff(x))),
    range = diff(range(x))
  )
}

classify_case <- function(row) {
  fit_stable <- isTRUE(all(
    c(row$delta_state_last, row$delta_sigma_last, row$delta_gamma_last) <
      c(5e-3, 5e-3, 5e-3),
    na.rm = TRUE
  ))
  strong_cycle <- is.finite(row$gamma_lag1) &&
    is.finite(row$gamma_lag2) &&
    row$gamma_lag1 <= -0.8 &&
    row$gamma_lag2 >= 0.95 &&
    is.finite(row$sigma_lag1) &&
    is.finite(row$sigma_lag2) &&
    row$sigma_lag1 <= -0.8 &&
    row$sigma_lag2 >= 0.95
  committed_ok <- isTRUE(row$committed_stable)
  candidate_bad <- is.finite(row$candidate_local_pass_rate) &&
    row$candidate_local_pass_rate < 0.5

  dplyr::case_when(
    strong_cycle ~ "residual_instability_cycle",
    fit_stable && committed_ok && candidate_bad ~ "signoff_only_candidate_bad_committed_good",
    fit_stable && !committed_ok ~ "residual_instability_committed_bad",
    !fit_stable && committed_ok ~ "residual_instability_fit_not_stable",
    TRUE ~ "unclear_needs_followup"
  )
}

extract_row <- function(name, fit) {
  ld_trace <- fit$diagnostics$ld_block$trace
  s_trace <- fit$diagnostics$s_block$trace
  signoff <- fit$diagnostics$ld_block$signoff_summary %||% list()
  beta_hat <- as.numeric(fit$qbeta$m)
  q_hat <- as.numeric(drop(X %*% beta_hat))
  conv_final <- fit$diagnostics$convergence$final

  gamma_metrics <- tail_cycle_metrics(ld_trace$gamma)
  sigma_metrics <- tail_cycle_metrics(ld_trace$sigma)
  s_metrics <- tail_cycle_metrics(s_trace$s_mean)

  row <- tibble(
    case = name,
    iter = fit$iter,
    converged = isTRUE(fit$diagnostics$convergence$converged),
    stop_reason = fit$diagnostics$convergence$stop_reason %||% NA_character_,
    quantile_rmse = sqrt(mean((q_hat - q_true)^2)),
    beta_rmse = sqrt(mean((beta_hat - beta_true)^2)),
    delta_state_last = as.numeric(conv_final$delta_state %||% NA_real_),
    delta_sigma_last = as.numeric(conv_final$delta_sigma %||% NA_real_),
    delta_gamma_last = as.numeric(conv_final$delta_gamma %||% NA_real_),
    delta_elbo_last = as.numeric(conv_final$delta_elbo %||% NA_real_),
    gamma_tail_sd = tail_sd(ld_trace$gamma),
    sigma_tail_sd = tail_sd(ld_trace$sigma),
    s_tail_sd = tail_sd(s_trace$s_mean),
    gamma_lag1 = gamma_metrics[["lag1"]],
    gamma_lag2 = gamma_metrics[["lag2"]],
    sigma_lag1 = sigma_metrics[["lag1"]],
    sigma_lag2 = sigma_metrics[["lag2"]],
    s_lag1 = s_metrics[["lag1"]],
    s_lag2 = s_metrics[["lag2"]],
    candidate_local_pass_rate = as.numeric(signoff$candidate_local_pass_rate %||% NA_real_),
    committed_local_pass_rate = as.numeric(signoff$committed_local_pass_rate %||% NA_real_),
    committed_stable = isTRUE(signoff$committed_stable %||% FALSE),
    candidate_grad_inf_median = as.numeric(signoff$candidate_grad_inf_median %||% NA_real_),
    committed_grad_inf_median = as.numeric(signoff$committed_grad_inf_median %||% NA_real_),
    candidate_min_eig_median = as.numeric(signoff$candidate_min_eig_median %||% NA_real_),
    committed_min_eig_median = as.numeric(signoff$committed_min_eig_median %||% NA_real_),
    fallback_rate = as.numeric(signoff$fallback_rate %||% NA_real_),
    optim_fallback_rate = as.numeric(signoff$optim_fallback_rate %||% NA_real_),
    numeric_hessian_rate = as.numeric(signoff$numeric_hessian_rate %||% NA_real_),
    identity_hessian_rate = as.numeric(signoff$identity_hessian_rate %||% NA_real_),
    cov_floor_rate = as.numeric(signoff$cov_floor_rate %||% NA_real_),
    direct_commit_rate = as.numeric(signoff$direct_commit_rate %||% NA_real_),
    damped_commit_rate = as.numeric(signoff$damped_commit_rate %||% NA_real_),
    objective_gap_median = as.numeric(signoff$objective_gap_median %||% NA_real_),
    classification = NA_character_
  )
  row$classification <- classify_case(row)
  row
}

run_exal_vb <- function(name, ld_controls, max_iter = 400L, tol = 1e-4, n_samp_xi = 150L) {
  message("Running ", name)
  fit <- exal_static_LDVB(
    y = y,
    X = X,
    p0 = p0,
    max_iter = max_iter,
    tol = tol,
    n_samp_xi = n_samp_xi,
    ld_controls = ld_controls,
    verbose = FALSE
  )
  saveRDS(fit, file.path(out_root, paste0(name, ".rds")))
  fit
}

base_ctrl <- list(
  xi_method = "delta",
  optimizer_method = "lbfgsb",
  direct_commit = TRUE,
  auto_stabilize = FALSE,
  reject_bad_mode_commit = FALSE,
  store_trace = TRUE,
  sigma_init_mode = "data_scale"
)

auto_ctrl <- list(
  xi_method = "delta",
  optimizer_method = "lbfgsb",
  direct_commit = TRUE,
  auto_stabilize = TRUE,
  reject_bad_mode_commit = TRUE,
  store_trace = TRUE,
  sigma_init_mode = "data_scale"
)

mc_ctrl <- list(
  xi_method = "mc",
  xi_mode = "replicated",
  xi_replicates = 2L,
  reuse_draws = TRUE,
  reuse_seed = 20260309L,
  optimizer_method = "lbfgsb",
  direct_commit = TRUE,
  auto_stabilize = TRUE,
  reject_bad_mode_commit = TRUE,
  store_trace = TRUE,
  sigma_init_mode = "data_scale"
)

fits <- list(
  exal_base = run_exal_vb("exal_base", base_ctrl, max_iter = 300L),
  exal_auto = run_exal_vb("exal_auto", auto_ctrl, max_iter = 400L),
  exal_mc = run_exal_vb("exal_mc", mc_ctrl, max_iter = 200L, n_samp_xi = 60L)
)

summary_tbl <- bind_rows(
  extract_row("exal_base", fits$exal_base),
  extract_row("exal_auto", fits$exal_auto),
  extract_row("exal_mc", fits$exal_mc)
)

write_csv(summary_tbl, file.path(out_root, "tables", "ld_signoff_audit_summary.csv"))

note <- c(
  "# exAL VB LD signoff audit",
  "",
  "Reference DGP: paper-style dense normal lower-tail case (`tau=0.05`) reduced to `n=100`.",
  "",
  "Classification rule:",
  "- `residual_instability_cycle`: strong 2-cycle remains in sigma/gamma",
  "- `signoff_only_candidate_bad_committed_good`: tail fit stable and committed state numerically acceptable, but candidate raw LD state still fails local-mode checks",
  "- `residual_instability_committed_bad`: committed state itself still fails the reduced signoff rule",
  "- `residual_instability_fit_not_stable`: fit remains numerically unstable even if candidate/committed mode checks look acceptable",
  "",
  "See `ld_signoff_audit_summary.csv` for the case-by-case classification."
)
writeLines(note, file.path(out_root, "tables", "audit_note.md"))

message("Wrote audit outputs to: ", out_root)

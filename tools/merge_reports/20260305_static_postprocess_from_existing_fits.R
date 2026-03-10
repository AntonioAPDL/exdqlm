#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(devtools)
  library(matrixStats)
})

Sys.setenv(
  OMP_NUM_THREADS = "1",
  OPENBLAS_NUM_THREADS = "1",
  MKL_NUM_THREADS = "1",
  VECLIB_MAXIMUM_THREADS = "1",
  NUMEXPR_NUM_THREADS = "1"
)

devtools::load_all(".", quiet = TRUE)

safe_int <- function(x, default) {
  v <- suppressWarnings(as.integer(x)[1])
  if (!is.finite(v) || is.na(v)) default else v
}

tau_lab <- function(tau) gsub("\\.", "p", format(as.numeric(tau), nsmall = 2))

resolve_run_root <- function() {
  rr <- Sys.getenv("EXDQLM_STATIC_RUN_ROOT", "")
  if (nzchar(rr) && dir.exists(rr)) return(rr)

  cands <- Sys.glob("results/sim_suite_static/static_vb_then_mcmc_tt*")
  cands <- cands[file.exists(file.path(cands, "tables", "run_config.rds"))]
  if (!length(cands)) stop("No static run roots found.")
  cands[which.max(file.info(cands)$mtime)]
}

resolve_summary_path <- function(run_root) {
  explicit <- Sys.getenv("EXDQLM_STATIC_SUMMARY_PATH", "")
  if (nzchar(explicit) && file.exists(explicit)) return(explicit)

  p_main <- file.path(run_root, "tables", "pipeline_task_summary.csv")
  if (file.exists(p_main)) return(p_main)

  p_resume <- Sys.glob(file.path(run_root, "tables", "pipeline_task_summary_resume_static_*.csv"))
  if (length(p_resume)) return(p_resume[which.max(file.info(p_resume)$mtime)])
  stop("No static summary table found under run root: ", run_root)
}

log_file <- "tools/merge_reports/20260305_static_postprocess_from_existing_fits.log"
dir.create(dirname(log_file), recursive = TRUE, showWarnings = FALSE)
if (file.exists(log_file)) file.remove(log_file)

log_msg <- function(...) {
  line <- paste(format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "|", paste(..., collapse = " "))
  cat(line, "\n")
  cat(line, "\n", file = log_file, append = TRUE)
  flush.console()
}

run_root <- resolve_run_root()
summary_path <- resolve_summary_path(run_root)
run_cfg_path <- file.path(run_root, "tables", "run_config.rds")
if (!file.exists(run_cfg_path)) stop("Missing run config: ", run_cfg_path)
run_cfg <- readRDS(run_cfg_path)

sim_path <- run_cfg$sim_path
if (is.null(sim_path) || !file.exists(sim_path)) stop("Missing sim_path in run config or file missing.")
sim <- readRDS(sim_path)

TT <- if (!is.null(run_cfg$TT)) as.integer(run_cfg$TT) else length(sim$y)
taus <- if (!is.null(run_cfg$taus)) as.numeric(run_cfg$taus) else c(0.05, 0.50, 0.95)
trace_start <- max(1L, safe_int(Sys.getenv("EXDQLM_STATIC_TRACE_START", "20"), 20L))

y <- as.numeric(sim$y[seq_len(TT)])
X <- as.matrix(sim$extras$X[seq_len(TT), , drop = FALSE])
p_grid <- as.numeric(sim$p)
q_true_mat <- as.matrix(sim$q[seq_len(TT), , drop = FALSE])

fit_file <- function(inf, model, tau) {
  file.path(run_root, "fits", inf, sprintf("%s_%s_tau_%s_fit.rds", inf, model, tau_lab(tau)))
}

closest_q <- function(tau) {
  q_true_mat[, which.min(abs(p_grid - tau))]
}

trim_trace <- function(z, start_idx) {
  z <- as.numeric(z)
  z <- z[is.finite(z)]
  if (!length(z)) return(list(x = numeric(0), y = numeric(0)))
  idx <- seq_len(length(z))
  keep <- idx >= start_idx
  list(x = idx[keep], y = z[keep])
}

flip_rate <- function(z) {
  z <- as.numeric(z)
  z <- z[is.finite(z)]
  if (length(z) < 3L) return(NA_real_)
  dz <- diff(z)
  s <- sign(dz)
  s <- s[s != 0]
  if (length(s) < 2L) return(0)
  mean(s[-1] != s[-length(s)])
}

tail_stat <- function(z, start_idx) {
  tr <- trim_trace(z, start_idx)
  yy <- tr$y
  list(
    sd = if (length(yy) >= 2L) stats::sd(yy) else NA_real_,
    range = if (length(yy)) diff(range(yy, finite = TRUE)) else NA_real_,
    flip_rate = flip_rate(yy),
    median_abs = if (length(yy)) stats::median(abs(yy), na.rm = TRUE) else NA_real_,
    last = if (length(yy)) utils::tail(yy, 1L) else NA_real_
  )
}

plot_fit_compare <- function(file_path, idx_use, obj_a, obj_b, label_a, label_b, col_a, col_b, title_txt, y_raw, y_true) {
  y_use <- y_raw[idx_use]
  t_use <- idx_use
  true_q <- y_true[idx_use]

  map_a <- obj_a$map[idx_use]
  lb_a <- obj_a$lb[idx_use]
  ub_a <- obj_a$ub[idx_use]
  map_b <- obj_b$map[idx_use]
  lb_b <- obj_b$lb[idx_use]
  ub_b <- obj_b$ub[idx_use]

  grDevices::png(file_path, width = 1900, height = 980, res = 150)
  y_lim <- range(c(y_use, true_q, lb_a, ub_a, lb_b, ub_b), finite = TRUE)
  graphics::plot(t_use, y_use, type = "l", col = "grey45", lwd = 1.0,
                 xlab = "index", ylab = "value", main = title_txt, ylim = y_lim)
  xx <- c(t_use, rev(t_use))
  graphics::polygon(xx, c(lb_a, rev(ub_a)), border = NA,
                    col = grDevices::adjustcolor(col_a, alpha.f = 0.16))
  graphics::polygon(xx, c(lb_b, rev(ub_b)), border = NA,
                    col = grDevices::adjustcolor(col_b, alpha.f = 0.16))
  graphics::lines(t_use, true_q, lwd = 2.0, lty = 2, col = "#202020")
  graphics::lines(t_use, map_a, lwd = 1.8, col = col_a)
  graphics::lines(t_use, map_b, lwd = 1.8, col = col_b)
  graphics::legend(
    "topleft",
    legend = c("y", "true quantile", label_a, label_b, paste0(label_a, " 95% CrI"), paste0(label_b, " 95% CrI")),
    col = c("grey45", "#202020", col_a, col_b,
            grDevices::adjustcolor(col_a, alpha.f = 0.35),
            grDevices::adjustcolor(col_b, alpha.f = 0.35)),
    lty = c(1, 2, 1, 1, 1, 1),
    lwd = c(1.0, 2.0, 1.8, 1.8, 8, 8),
    bty = "n", cex = 0.9
  )
  grDevices::dev.off()
}

plot_trace_two <- function(file_path, x_a, y_a, x_b, y_b, label_a, label_b, col_a, col_b, title_txt, ylab_txt) {
  y_lim <- range(c(y_a, y_b), finite = TRUE)
  if (!all(is.finite(y_lim)) || diff(y_lim) <= 0) y_lim <- y_lim + c(-1e-6, 1e-6)

  grDevices::png(file_path, width = 1700, height = 900, res = 140)
  graphics::plot(x_a, y_a, type = "l", lwd = 1.7, col = col_a,
                 xlab = "iteration", ylab = ylab_txt, main = title_txt, ylim = y_lim)
  graphics::lines(x_b, y_b, lwd = 1.7, col = col_b)
  graphics::legend("topright", legend = c(label_a, label_b), col = c(col_a, col_b), lwd = 2, bty = "n")
  grDevices::dev.off()
}

plot_trace_single <- function(file_path, x, y, col, title_txt, ylab_txt) {
  y_lim <- range(y, finite = TRUE)
  if (!all(is.finite(y_lim)) || diff(y_lim) <= 0) y_lim <- y_lim + c(-1e-6, 1e-6)

  grDevices::png(file_path, width = 1700, height = 900, res = 140)
  graphics::plot(x, y, type = "l", lwd = 1.7, col = col,
                 xlab = "iteration", ylab = ylab_txt, main = title_txt, ylim = y_lim)
  grDevices::dev.off()
}

# Clean and recreate dynamic-style plot folders.
unlink(file.path(run_root, "plots"), recursive = TRUE, force = TRUE)
needed_dirs <- c(
  "derived",
  "plots/fit_within_inference",
  "plots/fit_between_inference",
  "plots/traces",
  "tables",
  "logs"
)
for (d in needed_dirs) dir.create(file.path(run_root, d), recursive = TRUE, showWarnings = FALSE)

log_msg("static postprocess started", sprintf("run_root=%s", run_root), sprintf("summary=%s", summary_path), sprintf("trace_start=%d", trace_start))

fit_rows <- list()
vb_rows <- list()
ld_rows <- list()
mc_rows <- list()
metrics_rows <- list()
rhs_rows <- list()
derived <- list()

for (inf in c("vb", "mcmc")) {
  for (mdl in c("exal", "al")) {
    for (tau in taus) {
      ff <- fit_file(inf, mdl, tau)
      if (!file.exists(ff)) stop("Missing fit file: ", ff)
      wrap <- readRDS(ff)
      fit <- wrap$fit
      norm <- wrap$normalized

      if (is.null(norm) ||
          (identical(inf, "vb") && is.null(norm$diagnostics$ld_block$mode_quality)) ||
          (identical(inf, "mcmc") && is.null(norm$diagnostics$mh$kernel_exact))) {
        norm <- if (identical(inf, "vb")) {
          .static_normalize_vb_fit(fit, model_name = mdl, tau = tau)
        } else {
          .static_normalize_mcmc_fit(fit, model_name = mdl, tau = tau)
        }
      }

      q_path <- .static_quantile_path_from_fit(fit, X, algorithm = inf)
      true_q <- as.numeric(closest_q(tau))
      rmse <- sqrt(mean((q_path$mean - true_q)^2))
      coverage <- mean(true_q >= q_path$lo & true_q <= q_path$hi)
      mean_ci_width <- mean(q_path$hi - q_path$lo)
      rhs_diag <- norm$diagnostics$rhs
      rhs_summary <- if (!is.null(rhs_diag$summary)) rhs_diag$summary else list()

      d_key <- sprintf("%s_%s_tau_%s", inf, mdl, tau_lab(tau))
      derived[[d_key]] <- list(map = q_path$mean, lb = q_path$lo, ub = q_path$hi, true_q = true_q)
      saveRDS(
        list(
          inference = inf,
          model = mdl,
          tau = tau,
          summary = list(map = q_path$mean, lb = q_path$lo, ub = q_path$hi),
          true_q = true_q
        ),
        file.path(run_root, "derived", sprintf("%s_%s_tau_%s_summary.rds", inf, mdl, tau_lab(tau))),
        compress = "xz"
      )

      fit_rows[[length(fit_rows) + 1L]] <- data.frame(
        inference = inf,
        model = mdl,
        tau = tau,
        beta_prior = if (!is.null(norm$diagnostics$beta_prior$type)) as.character(norm$diagnostics$beta_prior$type)[1] else "ridge",
        runtime_sec = as.numeric(norm$runtime_sec)[1],
        iter_like = if (!is.null(norm$iter)) as.integer(norm$iter)[1] else NA_integer_,
        converged = if (!is.null(norm$converged)) isTRUE(norm$converged) else NA,
        stop_reason = if (!is.null(norm$stop_reason)) as.character(norm$stop_reason)[1] else NA_character_,
        sigma_mean = as.numeric(norm$sigma_est)[1],
        gamma_mean = as.numeric(norm$gamma_est)[1],
        rhs_collapse_flag = if (!is.null(rhs_summary$collapse_flag)) isTRUE(rhs_summary$collapse_flag) else NA,
        rhs_collapse_warning = if (!is.null(rhs_summary$collapse_warning)) as.character(rhs_summary$collapse_warning)[1] else NA_character_,
        fit_file = ff,
        stringsAsFactors = FALSE
      )

      metrics_rows[[length(metrics_rows) + 1L]] <- data.frame(
        inference = inf,
        model = mdl,
        tau = tau,
        rmse = rmse,
        coverage = coverage,
        mean_ci_width = mean_ci_width,
        stringsAsFactors = FALSE
      )

      if (identical(inf, "vb")) {
        dlt <- fit$diagnostics$deltas
        ld_block <- norm$diagnostics$ld_block
        ld_signoff <- if (!is.null(ld_block$signoff_summary)) ld_block$signoff_summary else list()
        ld_trace <- if (!is.null(ld_block$trace)) ld_block$trace else data.frame()
        ld_last <- if (is.data.frame(ld_trace) && nrow(ld_trace)) ld_trace[nrow(ld_trace), , drop = FALSE] else NULL
        mode_quality <- if (!is.null(ld_block$mode_quality)) ld_block$mode_quality else list()
        sigma_tail <- tail_stat(if (is.data.frame(ld_trace) && "sigma" %in% names(ld_trace)) ld_trace$sigma else numeric(0), trace_start)
        gamma_tail <- tail_stat(if (is.data.frame(ld_trace) && "gamma" %in% names(ld_trace)) ld_trace$gamma else numeric(0), trace_start)
        xi_tail <- tail_stat(if (is.data.frame(ld_trace) && "xi_rel_drift" %in% names(ld_trace)) ld_trace$xi_rel_drift else numeric(0), trace_start)
        xi_mcse_trace <- if (is.data.frame(ld_trace) && "xi_mcse_max" %in% names(ld_trace)) ld_trace$xi_mcse_max else numeric(0)
        xi_mcse_tail <- trim_trace(xi_mcse_trace, trace_start)$y
        vb_rows[[length(vb_rows) + 1L]] <- data.frame(
          model = mdl,
          tau = tau,
          beta_prior = if (!is.null(norm$diagnostics$beta_prior$type)) as.character(norm$diagnostics$beta_prior$type)[1] else "ridge",
          iter = if (!is.null(norm$iter)) as.integer(norm$iter)[1] else NA_integer_,
          converged = if (!is.null(norm$converged)) isTRUE(norm$converged) else NA,
          stop_reason = if (!is.null(norm$stop_reason)) as.character(norm$stop_reason)[1] else NA_character_,
          elbo_len = if (!is.null(fit$diagnostics$elbo)) length(fit$diagnostics$elbo) else NA_integer_,
          delta_state_last = if (!is.null(dlt$state)) utils::tail(as.numeric(dlt$state), 1) else NA_real_,
          delta_sigma_last = if (!is.null(dlt$sigma)) utils::tail(as.numeric(dlt$sigma), 1) else NA_real_,
          delta_gamma_last = if (!is.null(dlt$gamma)) utils::tail(as.numeric(dlt$gamma), 1) else NA_real_,
          delta_s_last = if (!is.null(dlt$s)) utils::tail(as.numeric(dlt$s), 1) else NA_real_,
          stringsAsFactors = FALSE
        )
        ld_rows[[length(ld_rows) + 1L]] <- data.frame(
          model = mdl,
          tau = tau,
          ld_trace_rows = if (is.data.frame(ld_trace)) nrow(ld_trace) else NA_integer_,
          ld_xi_rel_drift_last = if (!is.null(ld_last)) as.numeric(ld_last$xi_rel_drift)[1] else NA_real_,
          ld_xi_median_abs_tail = xi_tail$median_abs,
          ld_xi_flip_rate_tail = xi_tail$flip_rate,
          ld_cov_condition_last = if (!is.null(ld_last)) as.numeric(ld_last$ld_cov_condition)[1] else NA_real_,
          ld_hess_condition_last = if (!is.null(ld_last)) as.numeric(ld_last$ld_hess_condition)[1] else NA_real_,
          ld_sigma_sd_tail = sigma_tail$sd,
          ld_sigma_range_tail = sigma_tail$range,
          ld_sigma_flip_rate_tail = sigma_tail$flip_rate,
          ld_gamma_sd_tail = gamma_tail$sd,
          ld_gamma_range_tail = gamma_tail$range,
          ld_gamma_flip_rate_tail = gamma_tail$flip_rate,
          ld_xi_mcse_max_last = if (!is.null(ld_last)) as.numeric(ld_last$xi_mcse_max)[1] else NA_real_,
          ld_xi_mcse_mean_last = if (!is.null(ld_last)) as.numeric(ld_last$xi_mcse_mean)[1] else NA_real_,
          ld_xi_mcse_max_tail = if (length(xi_mcse_tail)) max(xi_mcse_tail, na.rm = TRUE) else NA_real_,
          ld_mode_grad_inf_norm_final = if (!is.null(mode_quality$grad_inf_norm)) as.numeric(mode_quality$grad_inf_norm)[1] else NA_real_,
          ld_mode_neg_hess_min_eig_final = if (!is.null(mode_quality$neg_hess_min_eig)) as.numeric(mode_quality$neg_hess_min_eig)[1] else NA_real_,
          ld_mode_neg_hess_condition_final = if (!is.null(mode_quality$neg_hess_condition)) as.numeric(mode_quality$neg_hess_condition)[1] else NA_real_,
          ld_local_mode_pass = if (!is.null(mode_quality$local_mode_pass)) isTRUE(mode_quality$local_mode_pass) else NA,
          ld_candidate_local_pass_rate_tail = if (!is.null(ld_signoff$candidate_local_pass_rate)) as.numeric(ld_signoff$candidate_local_pass_rate)[1] else NA_real_,
          ld_committed_local_pass_rate_tail = if (!is.null(ld_signoff$committed_local_pass_rate)) as.numeric(ld_signoff$committed_local_pass_rate)[1] else NA_real_,
          ld_committed_stable_tail = if (!is.null(ld_signoff$committed_stable)) isTRUE(ld_signoff$committed_stable) else NA,
          ld_candidate_grad_inf_median_tail = if (!is.null(ld_signoff$candidate_grad_inf_median)) as.numeric(ld_signoff$candidate_grad_inf_median)[1] else NA_real_,
          ld_committed_grad_inf_median_tail = if (!is.null(ld_signoff$committed_grad_inf_median)) as.numeric(ld_signoff$committed_grad_inf_median)[1] else NA_real_,
          ld_objective_gap_median_tail = if (!is.null(ld_signoff$objective_gap_median)) as.numeric(ld_signoff$objective_gap_median)[1] else NA_real_,
          ld_stabilized_rate_tail = if (!is.null(ld_signoff$stabilized_rate)) as.numeric(ld_signoff$stabilized_rate)[1] else NA_real_,
          ld_direct_commit_rate_tail = if (!is.null(ld_signoff$direct_commit_rate)) as.numeric(ld_signoff$direct_commit_rate)[1] else NA_real_,
          ld_damped_commit_rate_tail = if (!is.null(ld_signoff$damped_commit_rate)) as.numeric(ld_signoff$damped_commit_rate)[1] else NA_real_,
          ld_optim_fallback_rate = if (!is.null(ld_signoff$optim_fallback_rate)) as.numeric(ld_signoff$optim_fallback_rate)[1] else NA_real_,
          ld_numeric_hessian_rate = if (!is.null(ld_signoff$numeric_hessian_rate)) as.numeric(ld_signoff$numeric_hessian_rate)[1] else NA_real_,
          ld_identity_hessian_rate = if (!is.null(ld_signoff$identity_hessian_rate)) as.numeric(ld_signoff$identity_hessian_rate)[1] else NA_real_,
          ld_cov_floor_rate = if (!is.null(ld_signoff$cov_floor_rate)) as.numeric(ld_signoff$cov_floor_rate)[1] else NA_real_,
          ld_mode_fallback_rate = if (is.data.frame(ld_trace) && nrow(ld_trace) && "ld_used_fallback" %in% names(ld_trace)) {
            mean(as.logical(ld_trace$ld_used_fallback))
          } else {
            NA_real_
          },
          stringsAsFactors = FALSE
        )
      } else {
        ess <- norm$diagnostics$ess
        acc <- norm$diagnostics$acceptance
        mh <- norm$diagnostics$mh
        mh_trace <- if (!is.null(mh$trace)) mh$trace else data.frame()
        mc_rows[[length(mc_rows) + 1L]] <- data.frame(
          model = mdl,
          tau = tau,
          beta_prior = if (!is.null(norm$diagnostics$beta_prior$type)) as.character(norm$diagnostics$beta_prior$type)[1] else "ridge",
          accept_rate = as.numeric(acc$total)[1],
          accept_rate_burn = as.numeric(acc$burn)[1],
          accept_rate_keep = as.numeric(acc$keep)[1],
          ess_sigma = as.numeric(ess$sigma)[1],
          ess_gamma = as.numeric(ess$gamma)[1],
          mh_proposal = if (!is.null(mh$proposal)) as.character(mh$proposal)[1] else NA_character_,
          mh_kernel_exact = if (!is.null(mh$kernel_exact)) isTRUE(mh$kernel_exact) else NA,
          mh_signoff_ready = if (!is.null(mh$signoff_ready)) isTRUE(mh$signoff_ready) else NA,
          mh_approximation_note = if (!is.null(mh$approximation_note)) as.character(mh$approximation_note)[1] else NA_character_,
          mh_adapt = if (!is.null(mh$adapt)) isTRUE(mh$adapt) else NA,
          mh_scale_initial = if (!is.null(mh$scale_initial)) as.numeric(mh$scale_initial)[1] else NA_real_,
          mh_scale_final = if (!is.null(mh$scale_final)) as.numeric(mh$scale_final)[1] else NA_real_,
          mh_adapt_steps = if (!is.null(mh$adapt_trace) && is.data.frame(mh$adapt_trace)) nrow(mh$adapt_trace) else NA_integer_,
          s_mean_avg = if (is.data.frame(mh_trace) && "s_mean" %in% names(mh_trace)) mean(mh_trace$s_mean, na.rm = TRUE) else NA_real_,
          s_sd_avg = if (is.data.frame(mh_trace) && "s_sd" %in% names(mh_trace)) mean(mh_trace$s_sd, na.rm = TRUE) else NA_real_,
          stringsAsFactors = FALSE
        )
      }

      if (!is.null(rhs_diag)) {
        rhs_rows[[length(rhs_rows) + 1L]] <- data.frame(
          inference = inf,
          model = mdl,
          tau = tau,
          beta_prior = if (!is.null(norm$diagnostics$beta_prior$type)) as.character(norm$diagnostics$beta_prior$type)[1] else "ridge",
          rhs_tau = if (!is.null(rhs_summary$tau)) as.numeric(rhs_summary$tau)[1] else NA_real_,
          rhs_c2 = if (!is.null(rhs_summary$c2)) as.numeric(rhs_summary$c2)[1] else NA_real_,
          rhs_lambda_mean = if (!is.null(rhs_summary$lambda_mean)) as.numeric(rhs_summary$lambda_mean)[1] else NA_real_,
          rhs_lambda_min = if (!is.null(rhs_summary$lambda_min)) as.numeric(rhs_summary$lambda_min)[1] else NA_real_,
          rhs_lambda_max = if (!is.null(rhs_summary$lambda_max)) as.numeric(rhs_summary$lambda_max)[1] else NA_real_,
          rhs_tau0 = if (!is.null(rhs_summary$tau0)) as.numeric(rhs_summary$tau0)[1] else NA_real_,
          rhs_nu = if (!is.null(rhs_summary$nu)) as.numeric(rhs_summary$nu)[1] else NA_real_,
          rhs_s = if (!is.null(rhs_summary$s)) as.numeric(rhs_summary$s)[1] else NA_real_,
          rhs_s2 = if (!is.null(rhs_summary$s2)) as.numeric(rhs_summary$s2)[1] else NA_real_,
          rhs_shrink_intercept = if (!is.null(rhs_summary$shrink_intercept)) isTRUE(rhs_summary$shrink_intercept) else NA,
          rhs_iter = if (!is.null(rhs_summary$rhs_iter)) as.integer(rhs_summary$rhs_iter)[1] else NA_integer_,
          rhs_tau_update_count = if (!is.null(rhs_summary$rhs_tau_update_count)) as.integer(rhs_summary$rhs_tau_update_count)[1] else NA_integer_,
          rhs_tau_warmup_last = if (!is.null(rhs_summary$rhs_tau_warmup_last)) isTRUE(rhs_summary$rhs_tau_warmup_last) else NA,
          rhs_update_reason_last = if (!is.null(rhs_summary$rhs_update_reason_last)) as.character(rhs_summary$rhs_update_reason_last)[1] else NA_character_,
          rhs_update_every_last = if (!is.null(rhs_summary$rhs_update_every_last)) as.integer(rhs_summary$rhs_update_every_last)[1] else NA_integer_,
          rhs_collapse_flag = if (!is.null(rhs_summary$collapse_flag)) isTRUE(rhs_summary$collapse_flag) else NA,
          rhs_tau_near_zero = if (!is.null(rhs_summary$collapse_tau_near_zero)) isTRUE(rhs_summary$collapse_tau_near_zero) else NA,
          rhs_beta_collapse = if (!is.null(rhs_summary$collapse_beta)) isTRUE(rhs_summary$collapse_beta) else NA,
          rhs_tau_ratio = if (!is.null(rhs_summary$collapse_tau_ratio)) as.numeric(rhs_summary$collapse_tau_ratio)[1] else NA_real_,
          rhs_slope_l2 = if (!is.null(rhs_summary$collapse_slope_l2)) as.numeric(rhs_summary$collapse_slope_l2)[1] else NA_real_,
          rhs_slope_max_abs = if (!is.null(rhs_summary$collapse_slope_max_abs)) as.numeric(rhs_summary$collapse_slope_max_abs)[1] else NA_real_,
          rhs_collapse_warning = if (!is.null(rhs_summary$collapse_warning)) as.character(rhs_summary$collapse_warning)[1] else NA_character_,
          rhs_ess_tau = if (!is.null(rhs_diag$ess$tau)) as.numeric(rhs_diag$ess$tau)[1] else NA_real_,
          rhs_ess_c2 = if (!is.null(rhs_diag$ess$c2)) as.numeric(rhs_diag$ess$c2)[1] else NA_real_,
          stringsAsFactors = FALSE
        )
      }
    }
  }
}

fit_summary <- do.call(rbind, fit_rows)
vb_conv <- do.call(rbind, vb_rows)
ld_diag <- do.call(rbind, ld_rows)
mc_diag <- do.call(rbind, mc_rows)
metrics_df <- do.call(rbind, metrics_rows)
rhs_diag_df <- if (length(rhs_rows)) {
  do.call(rbind, rhs_rows)
} else {
  data.frame(
    inference = character(0),
    model = character(0),
    tau = numeric(0),
    beta_prior = character(0),
    rhs_tau = numeric(0),
    rhs_c2 = numeric(0),
    rhs_lambda_mean = numeric(0),
    rhs_lambda_min = numeric(0),
    rhs_lambda_max = numeric(0),
    rhs_tau0 = numeric(0),
    rhs_nu = numeric(0),
    rhs_s = numeric(0),
    rhs_s2 = numeric(0),
    rhs_shrink_intercept = logical(0),
    rhs_iter = integer(0),
    rhs_tau_update_count = integer(0),
    rhs_tau_warmup_last = logical(0),
    rhs_update_reason_last = character(0),
    rhs_update_every_last = integer(0),
    rhs_collapse_flag = logical(0),
    rhs_tau_near_zero = logical(0),
    rhs_beta_collapse = logical(0),
    rhs_tau_ratio = numeric(0),
    rhs_slope_l2 = numeric(0),
    rhs_slope_max_abs = numeric(0),
    rhs_collapse_warning = character(0),
    rhs_ess_tau = numeric(0),
    rhs_ess_c2 = numeric(0),
    stringsAsFactors = FALSE
  )
}

utils::write.csv(fit_summary, file.path(run_root, "tables", "fit_summary.csv"), row.names = FALSE)
utils::write.csv(vb_conv, file.path(run_root, "tables", "vb_convergence_summary.csv"), row.names = FALSE)
utils::write.csv(ld_diag, file.path(run_root, "tables", "vb_ld_diagnostics_summary.csv"), row.names = FALSE)
utils::write.csv(mc_diag, file.path(run_root, "tables", "mcmc_diagnostics_summary.csv"), row.names = FALSE)
utils::write.csv(metrics_df, file.path(run_root, "tables", "metrics_summary.csv"), row.names = FALSE)
utils::write.csv(rhs_diag_df, file.path(run_root, "tables", "rhs_diagnostics_summary.csv"), row.names = FALSE)

log_msg("wrote tables: fit_summary, vb_convergence_summary, vb_ld_diagnostics_summary, mcmc_diagnostics_summary, metrics_summary, rhs_diagnostics_summary")

last_n <- min(200L, TT)
idx_full <- seq_len(TT)
idx_tail <- seq.int(TT - last_n + 1L, TT)

# Within-inference: exAL vs AL.
for (tau in taus) {
  tlabel <- tau_lab(tau)
  for (inf in c("vb", "mcmc")) {
    ex_key <- sprintf("%s_exal_tau_%s", inf, tlabel)
    al_key <- sprintf("%s_al_tau_%s", inf, tlabel)
    ex_obj <- derived[[ex_key]]
    al_obj <- derived[[al_key]]

    plot_fit_compare(
      file.path(run_root, "plots", "fit_within_inference", sprintf("%s_tau_%s_al_vs_exal_full.png", inf, tlabel)),
      idx_full, ex_obj, al_obj,
      label_a = paste0(toupper(inf), " exAL"),
      label_b = paste0(toupper(inf), " AL"),
      col_a = "#C73E1D", col_b = "#1F78B4",
      title_txt = sprintf("%s fit compare (tau=%.2f): exAL vs AL [full]", toupper(inf), tau),
      y_raw = y, y_true = ex_obj$true_q
    )

    plot_fit_compare(
      file.path(run_root, "plots", "fit_within_inference", sprintf("%s_tau_%s_al_vs_exal_last200.png", inf, tlabel)),
      idx_tail, ex_obj, al_obj,
      label_a = paste0(toupper(inf), " exAL"),
      label_b = paste0(toupper(inf), " AL"),
      col_a = "#C73E1D", col_b = "#1F78B4",
      title_txt = sprintf("%s fit compare (tau=%.2f): exAL vs AL [last %d]", toupper(inf), tau, last_n),
      y_raw = y, y_true = ex_obj$true_q
    )
  }
}

# Between-inference: VB vs MCMC.
for (tau in taus) {
  tlabel <- tau_lab(tau)
  for (mdl in c("exal", "al")) {
    vb_key <- sprintf("vb_%s_tau_%s", mdl, tlabel)
    mc_key <- sprintf("mcmc_%s_tau_%s", mdl, tlabel)
    vb_obj <- derived[[vb_key]]
    mc_obj <- derived[[mc_key]]

    plot_fit_compare(
      file.path(run_root, "plots", "fit_between_inference", sprintf("%s_tau_%s_vb_vs_mcmc_full.png", mdl, tlabel)),
      idx_full, vb_obj, mc_obj,
      label_a = paste("VB", toupper(mdl)),
      label_b = paste("MCMC", toupper(mdl)),
      col_a = "#8E44AD", col_b = "#16A085",
      title_txt = sprintf("%s fit compare (tau=%.2f): VB vs MCMC [full]", toupper(mdl), tau),
      y_raw = y, y_true = vb_obj$true_q
    )

    plot_fit_compare(
      file.path(run_root, "plots", "fit_between_inference", sprintf("%s_tau_%s_vb_vs_mcmc_last200.png", mdl, tlabel)),
      idx_tail, vb_obj, mc_obj,
      label_a = paste("VB", toupper(mdl)),
      label_b = paste("MCMC", toupper(mdl)),
      col_a = "#8E44AD", col_b = "#16A085",
      title_txt = sprintf("%s fit compare (tau=%.2f): VB vs MCMC [last %d]", toupper(mdl), tau, last_n),
      y_raw = y, y_true = vb_obj$true_q
    )
  }
}

# Traces (trim from trace_start onward).
for (tau in taus) {
  tlabel <- tau_lab(tau)
  vb_ex <- readRDS(fit_file("vb", "exal", tau))$fit
  vb_al <- readRDS(fit_file("vb", "al", tau))$fit
  mc_ex <- readRDS(fit_file("mcmc", "exal", tau))$fit
  mc_al <- readRDS(fit_file("mcmc", "al", tau))$fit

  # ELBO traces (post warm-up).
  elbo_ex <- trim_trace(vb_ex$diagnostics$elbo, trace_start)
  elbo_al <- trim_trace(vb_al$diagnostics$elbo, trace_start)
  if (length(elbo_ex$y) > 1L && length(elbo_al$y) > 1L) {
    out_file <- file.path(run_root, "plots", "traces", sprintf("vb_tau_%s_elbo_trace.png", tlabel))
    grDevices::png(out_file, width = 1900, height = 900, res = 140)
    old_par <- graphics::par(no.readonly = TRUE)
    graphics::par(mfrow = c(1, 2), mar = c(4.2, 4.2, 3.0, 1.2))

    y_lim <- range(c(elbo_ex$y, elbo_al$y), finite = TRUE)
    graphics::plot(elbo_ex$x, elbo_ex$y, type = "l", lwd = 1.8, col = "#C73E1D",
                   xlab = "iteration", ylab = "ELBO",
                   main = sprintf("VB raw ELBO (tau=%.2f; iter >= %d)", tau, trace_start), ylim = y_lim)
    graphics::lines(elbo_al$x, elbo_al$y, lwd = 1.8, col = "#1F78B4")
    graphics::legend("bottomright", legend = c("exAL", "AL"), col = c("#C73E1D", "#1F78B4"), lwd = 2, bty = "n")

    d_ex <- elbo_ex$y - elbo_ex$y[1]
    d_al <- elbo_al$y - elbo_al$y[1]
    yd <- range(c(d_ex, d_al), finite = TRUE)
    graphics::plot(elbo_ex$x, d_ex, type = "l", lwd = 1.8, col = "#C73E1D",
                   xlab = "iteration", ylab = "ELBO - ELBO[start]",
                   main = "VB centered ELBO change", ylim = yd)
    graphics::lines(elbo_al$x, d_al, lwd = 1.8, col = "#1F78B4")
    graphics::legend("bottomright", legend = c("exAL", "AL"), col = c("#C73E1D", "#1F78B4"), lwd = 2, bty = "n")

    graphics::par(old_par)
    grDevices::dev.off()
  }

  # Parameter convergence traces (VB): use sequence if available, otherwise use deltas.
  vb_sigma_ex <- if (!is.null(vb_ex$seq.sigma) && length(vb_ex$seq.sigma) > 1L) vb_ex$seq.sigma else vb_ex$diagnostics$deltas$sigma
  vb_sigma_al <- if (!is.null(vb_al$seq.sigma) && length(vb_al$seq.sigma) > 1L) vb_al$seq.sigma else vb_al$diagnostics$deltas$sigma
  tr_sigma_ex <- trim_trace(vb_sigma_ex, trace_start)
  tr_sigma_al <- trim_trace(vb_sigma_al, trace_start)
  if (length(tr_sigma_ex$y) > 1L && length(tr_sigma_al$y) > 1L) {
    plot_trace_two(
      file_path = file.path(run_root, "plots", "traces", sprintf("vb_tau_%s_sigma_trace.png", tlabel)),
      x_a = tr_sigma_ex$x, y_a = tr_sigma_ex$y,
      x_b = tr_sigma_al$x, y_b = tr_sigma_al$y,
      label_a = "VB exAL", label_b = "VB AL",
      col_a = "#C73E1D", col_b = "#1F78B4",
      title_txt = sprintf("VB sigma convergence trace (tau=%.2f; iter >= %d)", tau, trace_start),
      ylab_txt = "sigma proxy (or delta sigma)"
    )
  }

  vb_state_ex <- trim_trace(vb_ex$diagnostics$deltas$state, trace_start)
  vb_state_al <- trim_trace(vb_al$diagnostics$deltas$state, trace_start)
  if (length(vb_state_ex$y) > 1L && length(vb_state_al$y) > 1L) {
    plot_trace_two(
      file_path = file.path(run_root, "plots", "traces", sprintf("vb_tau_%s_state_delta_trace.png", tlabel)),
      x_a = vb_state_ex$x, y_a = vb_state_ex$y,
      x_b = vb_state_al$x, y_b = vb_state_al$y,
      label_a = "VB exAL", label_b = "VB AL",
      col_a = "#C73E1D", col_b = "#1F78B4",
      title_txt = sprintf("VB state convergence delta (tau=%.2f; iter >= %d)", tau, trace_start),
      ylab_txt = "delta state"
    )
  }

  vb_gamma_ex <- if (!is.null(vb_ex$seq.gamma) && length(vb_ex$seq.gamma) > 1L) vb_ex$seq.gamma else vb_ex$diagnostics$deltas$gamma
  tr_gamma_ex <- trim_trace(vb_gamma_ex, trace_start)
  if (length(tr_gamma_ex$y) > 1L) {
    plot_trace_single(
      file_path = file.path(run_root, "plots", "traces", sprintf("vb_tau_%s_gamma_trace_exal.png", tlabel)),
      x = tr_gamma_ex$x, y = tr_gamma_ex$y,
      col = "#C73E1D",
      title_txt = sprintf("VB gamma convergence trace exAL (tau=%.2f; iter >= %d)", tau, trace_start),
      ylab_txt = "gamma proxy (or delta gamma)"
    )
  }
  vb_s_trace <- if (!is.null(vb_ex$diagnostics$s_block$trace)) vb_ex$diagnostics$s_block$trace else data.frame()
  if (is.data.frame(vb_s_trace) && nrow(vb_s_trace) > 1L && "s_mean" %in% names(vb_s_trace)) {
    tr_s_mean <- trim_trace(vb_s_trace$s_mean, trace_start)
    if (length(tr_s_mean$y) > 1L) {
      plot_trace_single(
        file_path = file.path(run_root, "plots", "traces", sprintf("vb_tau_%s_s_mean_trace_exal.png", tlabel)),
        x = tr_s_mean$x, y = tr_s_mean$y,
        col = "#D35400",
        title_txt = sprintf("VB s_i mean trace exAL (tau=%.2f; iter >= %d)", tau, trace_start),
        ylab_txt = "mean E[s_i]"
      )
    }
    if ("tau2_mean" %in% names(vb_s_trace)) {
      tr_s_tau2 <- trim_trace(vb_s_trace$tau2_mean, trace_start)
      if (length(tr_s_tau2$y) > 1L) {
        plot_trace_single(
          file_path = file.path(run_root, "plots", "traces", sprintf("vb_tau_%s_s_tau2_trace_exal.png", tlabel)),
          x = tr_s_tau2$x, y = tr_s_tau2$y,
          col = "#884EA0",
          title_txt = sprintf("VB s_i variance proxy exAL (tau=%.2f; iter >= %d)", tau, trace_start),
          ylab_txt = "mean tau2(s_i)"
        )
      }
    }
  }

  ld_trace_ex <- if (!is.null(vb_ex$diagnostics$ld_block$trace)) vb_ex$diagnostics$ld_block$trace else data.frame()
  if (is.data.frame(ld_trace_ex) && nrow(ld_trace_ex) > 1L) {
    tr_xi <- trim_trace(ld_trace_ex$xi_rel_drift, trace_start)
    if (length(tr_xi$y) > 1L) {
      plot_trace_single(
        file_path = file.path(run_root, "plots", "traces", sprintf("vb_tau_%s_ld_xi_drift_exal.png", tlabel)),
        x = tr_xi$x, y = tr_xi$y,
        col = "#B9770E",
        title_txt = sprintf("VB LD xi drift exAL (tau=%.2f; iter >= %d)", tau, trace_start),
        ylab_txt = "relative xi drift"
      )
    }
    tr_cond <- trim_trace(log10(pmax(ld_trace_ex$ld_cov_condition, 1e-8)), trace_start)
    if (length(tr_cond$y) > 1L) {
      plot_trace_single(
        file_path = file.path(run_root, "plots", "traces", sprintf("vb_tau_%s_ld_cov_condition_exal.png", tlabel)),
        x = tr_cond$x, y = tr_cond$y,
        col = "#7D3C98",
        title_txt = sprintf("VB LD covariance condition exAL (tau=%.2f; iter >= %d)", tau, trace_start),
        ylab_txt = "log10(condition number)"
      )
    }
  }

  # MCMC traces, also trimmed from trace_start for consistency.
  mc_sigma_ex <- trim_trace(mc_ex$samp.sigma, trace_start)
  mc_sigma_al <- trim_trace(mc_al$samp.sigma, trace_start)
  if (length(mc_sigma_ex$y) > 1L && length(mc_sigma_al$y) > 1L) {
    plot_trace_two(
      file_path = file.path(run_root, "plots", "traces", sprintf("mcmc_tau_%s_sigma_trace.png", tlabel)),
      x_a = mc_sigma_ex$x, y_a = mc_sigma_ex$y,
      x_b = mc_sigma_al$x, y_b = mc_sigma_al$y,
      label_a = "MCMC exAL", label_b = "MCMC AL",
      col_a = "#C73E1D", col_b = "#1F78B4",
      title_txt = sprintf("MCMC sigma trace (tau=%.2f; iter >= %d)", tau, trace_start),
      ylab_txt = "sigma sample"
    )
  }

  mc_gamma_ex <- trim_trace(mc_ex$samp.gamma, trace_start)
  if (length(mc_gamma_ex$y) > 1L) {
    plot_trace_single(
      file_path = file.path(run_root, "plots", "traces", sprintf("mcmc_tau_%s_gamma_trace_exal.png", tlabel)),
      x = mc_gamma_ex$x, y = mc_gamma_ex$y,
      col = "#C73E1D",
      title_txt = sprintf("MCMC gamma trace exAL (tau=%.2f; iter >= %d)", tau, trace_start),
      ylab_txt = "gamma sample"
    )
  }
  mc_s_trace <- if (!is.null(mc_ex$mh.diagnostics$trace)) mc_ex$mh.diagnostics$trace else data.frame()
  if (is.data.frame(mc_s_trace) && nrow(mc_s_trace) > 1L && "s_mean" %in% names(mc_s_trace)) {
    tr_mc_s <- trim_trace(mc_s_trace$s_mean, trace_start)
    if (length(tr_mc_s$y) > 1L) {
      plot_trace_single(
        file_path = file.path(run_root, "plots", "traces", sprintf("mcmc_tau_%s_s_mean_trace_exal.png", tlabel)),
        x = tr_mc_s$x, y = tr_mc_s$y,
        col = "#D35400",
        title_txt = sprintf("MCMC s_i mean trace exAL (tau=%.2f; iter >= %d)", tau, trace_start),
        ylab_txt = "mean sampled s_i"
      )
    }
  }

  mc_trace_ex <- if (!is.null(mc_ex$mh.diagnostics$trace)) mc_ex$mh.diagnostics$trace else data.frame()
  if (is.data.frame(mc_trace_ex) && nrow(mc_trace_ex) > 1L && "proposal_sd" %in% names(mc_trace_ex)) {
    tr_ps <- trim_trace(mc_trace_ex$proposal_sd, trace_start)
    if (length(tr_ps$y) > 1L) {
      plot_trace_single(
        file_path = file.path(run_root, "plots", "traces", sprintf("mcmc_tau_%s_proposal_scale_exal.png", tlabel)),
        x = tr_ps$x, y = tr_ps$y,
        col = "#117A65",
        title_txt = sprintf("MCMC proposal scale exAL (tau=%.2f; iter >= %d)", tau, trace_start),
        ylab_txt = "proposal scale"
      )
    }
  }
}

plot_count <- length(list.files(file.path(run_root, "plots"), pattern = "\\.png$", recursive = TRUE))
summary_md <- file.path(run_root, "tables", "report_summary.md")
writeLines(c(
  "# Static Dynamic-Style Postprocess",
  "",
  sprintf("- run_root: `%s`", run_root),
  sprintf("- summary_source: `%s`", summary_path),
  sprintf("- sim_path: `%s`", sim_path),
  sprintf("- generated_at: `%s`", format(Sys.time(), "%Y-%m-%d %H:%M:%S")),
  sprintf("- trace_start_iteration: %d", trace_start),
  sprintf("- total_png_plots: %d", plot_count),
  "",
  "## Core tables",
  "- `tables/fit_summary.csv`",
  "- `tables/vb_convergence_summary.csv`",
  "- `tables/vb_ld_diagnostics_summary.csv`",
  "- `tables/mcmc_diagnostics_summary.csv`",
  "- `tables/metrics_summary.csv`",
  "- `tables/rhs_diagnostics_summary.csv`",
  "",
  "## Plot directories",
  "- `plots/fit_within_inference`",
  "- `plots/fit_between_inference`",
  "- `plots/traces`"
), con = summary_md)

log_msg("static postprocess completed", sprintf("plot_count=%d", plot_count))
cat(sprintf("Static postprocess complete. Outputs under: %s\n", run_root))

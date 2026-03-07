#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(devtools)
  library(Matrix)
  library(matrixStats)
})

devtools::load_all(".", quiet = TRUE)

build_dgp_matched_model <- function(params, TT) {
  period <- as.numeric(params$period)[1]
  if (!is.finite(period) || period <= 2) stop("Invalid DGP period.")

  lam1 <- 2 * pi / period
  lam2 <- 2 * lam1
  rot <- function(lam) {
    matrix(c(cos(lam), sin(lam), -sin(lam), cos(lam)), nrow = 2, byrow = TRUE)
  }

  GG_one <- as.matrix(Matrix::bdiag(diag(2), rot(lam1), rot(lam2)))
  GG <- array(0, dim = c(6, 6, TT))
  for (t in seq_len(TT)) GG[, , t] <- GG_one

  FF <- matrix(rep(c(1, 0, 1, 0, 1, 0), TT), nrow = 6, ncol = TT)
  m0 <- as.numeric(params$m0)
  C0 <- as.matrix(params$C0)
  if (length(m0) != 6L || !all(dim(C0) == c(6L, 6L))) {
    stop("DGP model dimensions are not 6x6 as expected.")
  }
  as.exdqlm(list(FF = FF, GG = GG, m0 = m0, C0 = C0))
}

map_and_ci <- function(fit, cr = 0.95) {
  TT <- ncol(fit$model$FF)
  ns <- dim(fit$samp.theta)[3]
  q_draws <- vapply(seq_len(ns), function(i) {
    colSums(fit$model$FF * fit$samp.theta[, , i])
  }, numeric(TT))
  alpha <- (1 - cr) / 2
  list(
    draws = q_draws,
    map = rowMeans(q_draws),
    lb = matrixStats::rowQuantiles(q_draws, probs = alpha),
    ub = matrixStats::rowQuantiles(q_draws, probs = 1 - alpha)
  )
}

rmse_vec <- function(a, b) sqrt(mean((a - b)^2))

old_opts <- options(
  exdqlm.use_cpp_kf = FALSE,
  exdqlm.compute_elbo = TRUE,
  exdqlm.use_cpp_samplers = FALSE,
  exdqlm.use_cpp_postpred = FALSE
)
on.exit(options(old_opts), add = TRUE)

set.seed(20260304)
sim_path <- file.path("results", "sim_suite_dlm", "series", "dlm_constV_smallW", "sim_output.rds")
if (!file.exists(sim_path)) {
  stop("Simulation file not found: ", sim_path)
}
sim <- readRDS(sim_path)

TT_req <- suppressWarnings(as.integer(Sys.getenv("EXDQLM_TEST_TT", "1200")))
if (!is.finite(TT_req) || TT_req < 200L) TT_req <- 1200L
TT <- min(TT_req, length(sim$y))

y <- as.numeric(sim$y[seq_len(TT)])
mu_true <- if (!is.null(sim$extras$mu)) as.numeric(sim$extras$mu[seq_len(TT)]) else rep(NA_real_, TT)
t_idx <- seq_len(TT)

model <- build_dgp_matched_model(sim$info$params, TT = TT)
p_vec <- c(0.05, 0.50, 0.95)

df_vec <- rep(0.98, 3)
dim_df <- c(2, 2, 2)
tol <- 0.03
n_samp <- 120L

sanitize_exps0 <- function(x, fallback) {
  z <- as.numeric(x)
  if (length(z) != length(fallback)) {
    z <- rep_len(stats::median(fallback), length(fallback))
  }
  bad <- !is.finite(z)
  if (any(bad)) z[bad] <- stats::median(fallback)
  z
}

exps0_candidates <- list(
  if (all(is.finite(mu_true))) mu_true else rep(stats::median(y), TT),
  stats::filter(y, rep(1 / 9, 9), sides = 1),
  rep(stats::median(y), TT)
)

fit_ldvb_safe <- function(y, tau, model, df_vec, dim_df, dqlm_flag, base_seed, tol, n_samp) {
  errs <- character(0)
  for (j in seq_along(exps0_candidates)) {
    exps0_try <- sanitize_exps0(exps0_candidates[[j]], y)
    set.seed(base_seed + 100L * j + if (dqlm_flag) 37L else 0L)
    fit_try <- tryCatch(
      exdqlmLDVB(
        y = y, p0 = tau, model = model, df = df_vec, dim.df = dim_df,
        dqlm.ind = dqlm_flag, exps0 = exps0_try,
        fix.sigma = FALSE, tol = tol, n.samp = n_samp, verbose = FALSE
      ),
      error = function(e) e
    )
    if (!inherits(fit_try, "error")) return(fit_try)
    errs <- c(errs, conditionMessage(fit_try))
  }
  model_tag <- if (isTRUE(dqlm_flag)) "DQLM" else "exDQLM"
  stop(sprintf(
    "%s fit failed at tau=%.2f after %d init attempts: %s",
    model_tag, tau, length(exps0_candidates), paste(unique(errs), collapse = " | ")
  ))
}

out_root <- file.path("results", "function_testing_20260304_vb_quantiles")
if (dir.exists(out_root)) unlink(out_root, recursive = TRUE, force = TRUE)
sim_dir <- file.path(out_root, "sim")
dir.create(sim_dir, recursive = TRUE, showWarnings = FALSE)

metric_rows <- list()

for (k in seq_along(p_vec)) {
  tau <- p_vec[k]
  tau_lab <- gsub("\\.", "p", format(tau, nsmall = 2))
  true_idx <- which.min(abs(sim$p - tau))
  true_q <- as.numeric(sim$q[seq_len(TT), true_idx])

  fit_ex <- fit_ldvb_safe(
    y = y, tau = tau, model = model, df_vec = df_vec, dim_df = dim_df,
    dqlm_flag = FALSE, base_seed = 20260304 + k, tol = tol, n_samp = n_samp
  )
  fit_dq <- fit_ldvb_safe(
    y = y, tau = tau, model = model, df_vec = df_vec, dim_df = dim_df,
    dqlm_flag = TRUE, base_seed = 20260304 + k, tol = tol, n_samp = n_samp
  )

  ex_q <- map_and_ci(fit_ex)
  dq_q <- map_and_ci(fit_dq)

  rmse_ex <- rmse_vec(ex_q$map, true_q)
  rmse_dq <- rmse_vec(dq_q$map, true_q)
  cov_ex <- mean(true_q >= ex_q$lb & true_q <= ex_q$ub)
  cov_dq <- mean(true_q >= dq_q$lb & true_q <= dq_q$ub)
  wid_ex <- mean(ex_q$ub - ex_q$lb)
  wid_dq <- mean(dq_q$ub - dq_q$lb)

  metric_rows[[k]] <- data.frame(
    tau = tau,
    T_used = TT,
    rmse_exdqlm = rmse_ex,
    rmse_dqlm = rmse_dq,
    coverage_exdqlm = cov_ex,
    coverage_dqlm = cov_dq,
    mean_ci_width_exdqlm = wid_ex,
    mean_ci_width_dqlm = wid_dq,
    iter_exdqlm = fit_ex$iter,
    iter_dqlm = fit_dq$iter,
    runtime_exdqlm = fit_ex$run.time,
    runtime_dqlm = fit_dq$run.time,
    sigma_mean_exdqlm = mean(as.numeric(fit_ex$samp.sigma)),
    sigma_sd_exdqlm = stats::sd(as.numeric(fit_ex$samp.sigma)),
    sigma_mean_dqlm = mean(as.numeric(fit_dq$samp.sigma)),
    sigma_sd_dqlm = stats::sd(as.numeric(fit_dq$samp.sigma))
  )

  plot_fit_ci_window <- function(file_path, idx_use, title_suffix) {
    grDevices::png(file_path, width = 1900, height = 980, res = 150)
    t_use <- t_idx[idx_use]
    y_use <- y[idx_use]
    true_q_use <- true_q[idx_use]
    ex_lb <- ex_q$lb[idx_use]
    ex_ub <- ex_q$ub[idx_use]
    dq_lb <- dq_q$lb[idx_use]
    dq_ub <- dq_q$ub[idx_use]
    ex_map <- ex_q$map[idx_use]
    dq_map <- dq_q$map[idx_use]

    y_lim <- range(c(y_use, true_q_use, ex_lb, ex_ub, dq_lb, dq_ub), finite = TRUE)
    graphics::plot(
      t_use, y_use, type = "l", col = "grey45", lwd = 1.1,
      xlab = "time index", ylab = "value",
      main = sprintf("DGP-matched fit (tau = %.2f): exDQLM vs DQLM (LDVB) [%s]", tau, title_suffix),
      ylim = y_lim
    )
    xx <- c(t_use, rev(t_use))
    graphics::polygon(xx, c(ex_lb, rev(ex_ub)), border = NA,
                      col = grDevices::adjustcolor("#C73E1D", alpha.f = 0.16))
    graphics::polygon(xx, c(dq_lb, rev(dq_ub)), border = NA,
                      col = grDevices::adjustcolor("#1F78B4", alpha.f = 0.16))
    graphics::lines(t_use, true_q_use, lwd = 2.1, lty = 2, col = "#202020")
    graphics::lines(t_use, ex_map, lwd = 1.9, col = "#C73E1D")
    graphics::lines(t_use, dq_map, lwd = 1.9, col = "#1F78B4")
    if (all(is.finite(mu_true))) {
      graphics::lines(t_use, mu_true[idx_use], lwd = 1.2, lty = 3, col = "#2CA02C")
    }
    graphics::legend(
      "topleft",
      legend = c(
        "y", "true quantile (sim truth)", "exDQLM MAP", "DQLM MAP",
        "exDQLM 95% CrI", "DQLM 95% CrI", "true mean (mu_t)"
      ),
      col = c(
        "grey45", "#202020", "#C73E1D", "#1F78B4",
        grDevices::adjustcolor("#C73E1D", alpha.f = 0.4),
        grDevices::adjustcolor("#1F78B4", alpha.f = 0.4), "#2CA02C"
      ),
      lty = c(1, 2, 1, 1, 1, 1, 3),
      lwd = c(1.1, 2.1, 1.9, 1.9, 8, 8, 1.2),
      bty = "n", cex = 0.88
    )
    graphics::mtext(
      sprintf(
        "RMSE ex=%.3f | RMSE dq=%.3f | Cov ex=%.3f | Cov dq=%.3f | T=%d | n_window=%d",
        rmse_ex, rmse_dq, cov_ex, cov_dq, TT, length(idx_use)
      ),
      side = 3, line = 0.2, cex = 0.86
    )
    grDevices::dev.off()
  }

  fit_file <- file.path(sim_dir, sprintf("sim_tau_%s_fit_ci.png", tau_lab))
  plot_fit_ci_window(fit_file, seq_len(TT), "full sample")

  tail_n <- min(200L, TT)
  tail_idx <- seq.int(TT - tail_n + 1L, TT)
  fit_tail_file <- file.path(sim_dir, sprintf("sim_tau_%s_fit_ci_last200.png", tau_lab))
  plot_fit_ci_window(fit_tail_file, tail_idx, sprintf("last %d observations", tail_n))

  elbo_file <- file.path(sim_dir, sprintf("sim_tau_%s_elbo_trace.png", tau_lab))
  grDevices::png(elbo_file, width = 1900, height = 860, res = 140)
  elbo_ex <- as.numeric(fit_ex$diagnostics$elbo)
  elbo_dq <- as.numeric(fit_dq$diagnostics$elbo)
  y_lim_elbo <- range(c(elbo_ex, elbo_dq), finite = TRUE)
  old_par_elbo <- graphics::par(no.readonly = TRUE)
  graphics::par(mfrow = c(1, 2), mar = c(4.2, 4.2, 3.0, 1.2))
  graphics::plot(seq_along(elbo_ex), elbo_ex, type = "l", lwd = 2.0, col = "#C73E1D",
                 xlab = "iteration", ylab = "ELBO",
                 main = sprintf("Raw ELBO (tau = %.2f)", tau),
                 ylim = y_lim_elbo)
  graphics::lines(seq_along(elbo_dq), elbo_dq, lwd = 2.0, col = "#1F78B4")
  graphics::legend("bottomright", legend = c("exDQLM", "DQLM"),
                   col = c("#C73E1D", "#1F78B4"), lwd = 2, bty = "n", cex = 0.9)
  d_ex <- elbo_ex - elbo_ex[1]
  d_dq <- elbo_dq - elbo_dq[1]
  graphics::plot(seq_along(d_ex), d_ex, type = "l", lwd = 2.0, col = "#C73E1D",
                 xlab = "iteration", ylab = "ELBO - ELBO[1]",
                 main = "Centered ELBO change")
  graphics::lines(seq_along(d_dq), d_dq, lwd = 2.0, col = "#1F78B4")
  graphics::legend("bottomright", legend = c("exDQLM", "DQLM"),
                   col = c("#C73E1D", "#1F78B4"), lwd = 2, bty = "n", cex = 0.9)
  graphics::par(old_par_elbo)
  grDevices::dev.off()

  sig_trace_file <- file.path(sim_dir, sprintf("sim_tau_%s_sigma_trace.png", tau_lab))
  grDevices::png(sig_trace_file, width = 1700, height = 860, res = 140)
  seq_ex <- as.numeric(fit_ex$seq.sigma)
  seq_dq <- as.numeric(fit_dq$seq.sigma)
  y_lim_sig <- range(c(seq_ex, seq_dq), finite = TRUE)
  graphics::plot(seq_along(seq_ex) - 1L, seq_ex, type = "l", lwd = 2.0, col = "#C73E1D",
                 xlab = "VB iteration", ylab = "E[sigma]",
                 main = sprintf("Sigma trace (tau = %.2f)", tau),
                 ylim = y_lim_sig)
  graphics::lines(seq_along(seq_dq) - 1L, seq_dq, lwd = 2.0, col = "#1F78B4")
  graphics::legend("topright", legend = c("exDQLM", "DQLM"),
                   col = c("#C73E1D", "#1F78B4"), lwd = 2, bty = "n")
  grDevices::dev.off()

  sig_hist_file <- file.path(sim_dir, sprintf("sim_tau_%s_sigma_hist.png", tau_lab))
  grDevices::png(sig_hist_file, width = 1900, height = 900, res = 140)
  old_par <- graphics::par(no.readonly = TRUE)
  graphics::par(mfrow = c(1, 2), mar = c(4.2, 4.2, 3.2, 1.2))

  draw_sigma_hist <- function(samples, col, title_txt) {
    samples <- as.numeric(samples)
    sdev <- stats::sd(samples)
    sval <- mean(samples)
    if (is.finite(sdev) && sdev > 1e-5) {
      graphics::hist(samples, breaks = "FD", probability = TRUE, border = "white",
                     col = grDevices::adjustcolor(col, alpha.f = 0.65),
                     xlab = "sigma", main = title_txt)
      graphics::lines(stats::density(samples), lwd = 2.0, col = col)
    } else {
      graphics::plot(c(sval - 0.05, sval + 0.05), c(0, 1), type = "n",
                     xlab = "sigma", ylab = "density", main = title_txt)
      graphics::abline(v = sval, lwd = 2.2, col = col)
      graphics::mtext("posterior SD ~ 0", side = 3, line = -1.2, adj = 1, cex = 0.8)
    }
    graphics::mtext(sprintf("mean=%.4f | sd=%.4g", mean(samples), sdev),
                    side = 3, line = -2.3, cex = 0.86)
  }

  draw_sigma_hist(fit_ex$samp.sigma, "#C73E1D", sprintf("exDQLM sigma posterior (tau=%.2f)", tau))
  draw_sigma_hist(fit_dq$samp.sigma, "#1F78B4", sprintf("DQLM sigma posterior (tau=%.2f)", tau))
  graphics::par(old_par)
  grDevices::dev.off()

  # Keep legacy file name so downstream references still open.
  diag_file <- file.path(sim_dir, sprintf("sim_tau_%s_diag.png", tau_lab))
  grDevices::png(diag_file, width = 2000, height = 1150, res = 140)
  old_par2 <- graphics::par(no.readonly = TRUE)
  graphics::par(mfrow = c(2, 2), mar = c(4.0, 4.0, 2.8, 1.2))
  graphics::plot(seq_along(elbo_ex), elbo_ex, type = "l", lwd = 1.8, col = "#C73E1D",
                 xlab = "iter", ylab = "ELBO", main = "ELBO trace",
                 ylim = range(c(elbo_ex, elbo_dq), finite = TRUE))
  graphics::lines(seq_along(elbo_dq), elbo_dq, lwd = 1.8, col = "#1F78B4")
  graphics::legend("bottomright", legend = c("exDQLM", "DQLM"),
                   col = c("#C73E1D", "#1F78B4"), lwd = 2, bty = "n", cex = 0.9)
  graphics::plot(seq_along(seq_ex) - 1L, seq_ex, type = "l", lwd = 1.8, col = "#C73E1D",
                 xlab = "iter", ylab = "E[sigma]", main = "Sigma trace",
                 ylim = range(c(seq_ex, seq_dq), finite = TRUE))
  graphics::lines(seq_along(seq_dq) - 1L, seq_dq, lwd = 1.8, col = "#1F78B4")
  draw_sigma_hist(fit_ex$samp.sigma, "#C73E1D", "exDQLM sigma posterior")
  draw_sigma_hist(fit_dq$samp.sigma, "#1F78B4", "DQLM sigma posterior")
  graphics::par(old_par2)
  grDevices::dev.off()
}

metrics <- do.call(rbind, metric_rows)
utils::write.csv(metrics, file.path(out_root, "metrics_summary.csv"), row.names = FALSE)

cat("Wrote outputs to:", normalizePath(out_root), "\n")

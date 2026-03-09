#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(devtools)
})

Sys.setenv(
  OMP_NUM_THREADS = "1",
  OPENBLAS_NUM_THREADS = "1",
  MKL_NUM_THREADS = "1",
  VECLIB_MAXIMUM_THREADS = "1",
  NUMEXPR_NUM_THREADS = "1"
)

devtools::load_all(".", quiet = TRUE)

safe_num <- function(x, default = NA_real_) {
  v <- suppressWarnings(as.numeric(x)[1])
  if (!is.finite(v) || is.na(v)) default else v
}

read_csv_maybe_empty <- function(path) {
  if (!file.exists(path)) return(data.frame())
  if (!isTRUE(file.info(path)$size > 0)) return(data.frame())
  out <- tryCatch(
    utils::read.csv(path, check.names = FALSE),
    error = function(e) data.frame()
  )
  out
}

tau_lab <- function(tau) gsub("\\.", "p", format(as.numeric(tau), nsmall = 2))

resolve_run_root <- function() {
  rr <- Sys.getenv("EXDQLM_STATIC_RUN_ROOT", "")
  if (nzchar(rr) && dir.exists(rr)) return(rr)

  cands <- Sys.glob("results/sim_suite_static/static_vb_then_mcmc_tt*")
  if (!length(cands)) stop("No static pipeline run directories found.")
  cands <- cands[file.exists(file.path(cands, "tables", "run_config.rds"))]
  if (!length(cands)) stop("No valid static run roots with run_config.rds found.")
  cands[which.max(file.info(cands)$mtime)]
}

resolve_summary_path <- function(run_root) {
  sp <- Sys.getenv("EXDQLM_STATIC_SUMMARY_PATH", "")
  if (nzchar(sp) && file.exists(sp)) return(sp)

  default_path <- file.path(run_root, "tables", "pipeline_task_summary.csv")
  if (file.exists(default_path)) return(default_path)

  resume_paths <- Sys.glob(file.path(run_root, "tables", "pipeline_task_summary_resume_static_*.csv"))
  if (length(resume_paths)) {
    return(resume_paths[which.max(file.info(resume_paths)$mtime)])
  }
  stop("Missing pipeline summary in run root: ", run_root)
}

ensure_col <- function(df, col, value) {
  if (!col %in% names(df)) df[[col]] <- value
  df
}

resolve_file_path <- function(path_like, run_root) {
  p <- as.character(path_like)[1]
  if (!nzchar(p) || is.na(p)) return(NA_character_)
  if (file.exists(p)) return(p)
  p_repo <- file.path(getwd(), p)
  if (file.exists(p_repo)) return(p_repo)
  p_run <- file.path(run_root, p)
  if (file.exists(p_run)) return(p_run)
  NA_character_
}

infer_vb_file <- function(run_root, model, tau) {
  file.path(run_root, "fits", "vb", sprintf("vb_%s_tau_%s_fit.rds", model, tau_lab(tau)))
}

infer_mcmc_file <- function(run_root, model, tau) {
  file.path(run_root, "fits", "mcmc", sprintf("mcmc_%s_tau_%s_fit.rds", model, tau_lab(tau)))
}

plot_coef_tree <- function(file_path, beta_draws, main, lambda_summary = NULL) {
  beta_draws <- as.matrix(beta_draws)
  if (!nrow(beta_draws) || !ncol(beta_draws)) return(invisible(NULL))
  cn <- colnames(beta_draws)
  if (is.null(cn)) cn <- paste0("beta", seq_len(ncol(beta_draws)))
  post_mean <- colMeans(beta_draws, na.rm = TRUE)
  qs <- t(apply(beta_draws, 2, stats::quantile, probs = c(0.05, 0.5, 0.95), na.rm = TRUE))
  ord <- order(abs(post_mean), decreasing = TRUE)
  qs <- qs[ord, , drop = FALSE]
  cn <- cn[ord]
  grDevices::png(file_path, width = 1500, height = max(900, 220 + 70 * ncol(beta_draws)), res = 140)
  old_par <- graphics::par(no.readonly = TRUE)
  on.exit({
    graphics::par(old_par)
    grDevices::dev.off()
  }, add = TRUE)
  graphics::par(mar = c(5, 8, 4, 2))
  yy <- seq_along(cn)
  xlim <- range(qs, finite = TRUE)
  graphics::plot(qs[, 2], yy,
    xlim = xlim, ylim = c(0.5, length(cn) + 0.5),
    yaxt = "n", ylab = "", xlab = "posterior coefficient value",
    pch = 19, col = "#C73E1D", main = main
  )
  graphics::segments(qs[, 1], yy, qs[, 3], yy, lwd = 2.2, col = "#1F78B4")
  graphics::abline(v = 0, lty = 2, col = "grey40")
  graphics::axis(2, at = yy, labels = cn, las = 1)
  if (!is.null(lambda_summary) && length(lambda_summary) == length(cn)) {
    usr <- graphics::par("usr")
    x_txt <- usr[2] - 0.03 * diff(usr[1:2])
    graphics::text(x_txt, yy,
      labels = sprintf("lambda=%.2f", lambda_summary[ord]),
      pos = 2, cex = 0.85, col = "grey25"
    )
  }
}

run_root <- resolve_run_root()
if (!dir.exists(run_root)) stop("Run root does not exist: ", run_root)

cfg_path <- file.path(run_root, "tables", "run_config.rds")
if (!file.exists(cfg_path)) stop("Missing run config: ", cfg_path)
cfg <- readRDS(cfg_path)

sim_path <- cfg$sim_path
if (is.null(sim_path) || !file.exists(sim_path)) {
  stop("sim_path missing/not found in run_config: ", sim_path)
}
sim <- readRDS(sim_path)

summary_path <- resolve_summary_path(run_root)
summary_df <- utils::read.csv(summary_path, check.names = FALSE)
summary_df <- ensure_col(summary_df, "status", "unknown")
summary_df <- ensure_col(summary_df, "vb_runtime_sec", NA_real_)
summary_df <- ensure_col(summary_df, "mcmc_runtime_sec", NA_real_)
summary_df <- ensure_col(summary_df, "vb_converged", NA)
summary_df <- ensure_col(summary_df, "vb_stop_reason", NA_character_)
summary_df <- ensure_col(summary_df, "ess_sigma", NA_real_)
summary_df <- ensure_col(summary_df, "ess_gamma", NA_real_)
summary_df <- ensure_col(summary_df, "accept_rate", NA_real_)
summary_df <- ensure_col(summary_df, "mcmc_gamma_kernel_exact", NA)
summary_df <- ensure_col(summary_df, "mcmc_signoff_ready", NA)
summary_df <- ensure_col(summary_df, "vb_file", NA_character_)
summary_df <- ensure_col(summary_df, "mcmc_file", NA_character_)
if ("runtime_sec" %in% names(summary_df)) {
  rt <- suppressWarnings(as.numeric(summary_df$runtime_sec))
  idx <- is.na(summary_df$mcmc_runtime_sec) & is.finite(rt)
  summary_df$mcmc_runtime_sec[idx] <- rt[idx]
}

out_tables <- file.path(run_root, "tables")
out_plots <- file.path(run_root, "plots")
out_plots_comp <- file.path(out_plots, "comparison")
out_plots_diag <- file.path(out_plots, "diagnostics")
out_plots_cloud <- file.path(out_plots, "cloud")
out_plots_rhs <- file.path(out_plots, "rhs")
dir.create(out_tables, recursive = TRUE, showWarnings = FALSE)
dir.create(out_plots, recursive = TRUE, showWarnings = FALSE)
dir.create(out_plots_comp, recursive = TRUE, showWarnings = FALSE)
dir.create(out_plots_diag, recursive = TRUE, showWarnings = FALSE)
dir.create(out_plots_cloud, recursive = TRUE, showWarnings = FALSE)
dir.create(out_plots_rhs, recursive = TRUE, showWarnings = FALSE)

TT <- if (!is.null(cfg$TT)) as.integer(cfg$TT) else nrow(sim$extras$X)
X <- as.matrix(sim$extras$X[seq_len(TT), , drop = FALSE])
if (is.null(colnames(X))) colnames(X) <- paste0("x", seq_len(ncol(X)))
q_true <- as.matrix(sim$q[seq_len(TT), , drop = FALSE])
p_grid <- as.numeric(sim$p)
y_obs <- as.numeric(sim$y[seq_len(TT)])

default_cov <- {
  cn <- colnames(X)
  nn <- setdiff(cn, c("intercept", "(Intercept)"))
  if (length(nn)) nn[1] else cn[1]
}
covar_name <- Sys.getenv("EXDQLM_STATIC_PLOT_COVAR", default_cov)
covar_idx <- match(covar_name, colnames(X))
if (!is.finite(covar_idx) || is.na(covar_idx)) {
  covar_name <- default_cov
  covar_idx <- match(covar_name, colnames(X))
}
if (!is.finite(covar_idx) || is.na(covar_idx)) covar_idx <- 1L
x_primary <- as.numeric(X[, covar_idx])

closest_p_index <- function(tau) which.min(abs(p_grid - tau))

collect_rows <- list()
plot_payload <- list()
fit_file_payload <- list()

for (i in seq_len(nrow(summary_df))) {
  row <- summary_df[i, , drop = FALSE]
  row_status <- as.character(row$status)
  if (!(row_status %in% c("done", "skipped_existing"))) next

  model <- as.character(row$model)
  tau <- as.numeric(row$tau)
  vb_file <- resolve_file_path(row$vb_file, run_root)
  mcmc_file <- resolve_file_path(row$mcmc_file, run_root)
  if (is.na(vb_file)) {
    vb_guess <- infer_vb_file(run_root, model, tau)
    if (file.exists(vb_guess)) vb_file <- vb_guess
  }
  if (is.na(mcmc_file)) {
    mc_guess <- infer_mcmc_file(run_root, model, tau)
    if (file.exists(mc_guess)) mcmc_file <- mc_guess
  }
  if (is.na(vb_file) || is.na(mcmc_file)) next
  summary_df$vb_file[i] <- vb_file
  summary_df$mcmc_file[i] <- mcmc_file

  vb_obj <- readRDS(vb_file)
  m_obj <- readRDS(mcmc_file)
  vb_fit <- vb_obj$fit
  m_fit <- m_obj$fit
  vb_norm <- .static_normalize_vb_fit(vb_fit)
  m_norm <- .static_normalize_mcmc_fit(m_fit)
  if (is.na(summary_df$vb_converged[i])) summary_df$vb_converged[i] <- isTRUE(vb_norm$converged)
  if (is.na(summary_df$vb_stop_reason[i]) || !nzchar(summary_df$vb_stop_reason[i])) {
    summary_df$vb_stop_reason[i] <- vb_norm$stop_reason
  }
  if (is.na(summary_df$ess_sigma[i])) summary_df$ess_sigma[i] <- as.numeric(m_norm$diagnostics$ess$sigma)[1]
  if (is.na(summary_df$ess_gamma[i])) summary_df$ess_gamma[i] <- as.numeric(m_norm$diagnostics$ess$gamma)[1]
  if (is.na(summary_df$accept_rate[i])) summary_df$accept_rate[i] <- as.numeric(m_norm$diagnostics$acceptance$total)[1]
  summary_df$mcmc_gamma_kernel_exact[i] <- isTRUE(m_norm$diagnostics$mh$kernel_exact)
  summary_df$mcmc_signoff_ready[i] <- isTRUE(m_norm$diagnostics$mh$signoff_ready)

  true_idx <- closest_p_index(tau)
  q_ref <- q_true[, true_idx]

  vb_path <- .static_quantile_path_from_fit(vb_fit, X, algorithm = "vb")
  m_path <- .static_quantile_path_from_fit(m_fit, X, algorithm = "mcmc")

  metric_row <- function(method, qhat, payload) {
    err <- as.numeric(qhat - q_ref)
    data.frame(
      model = model,
      tau = tau,
      method = method,
      n = length(qhat),
      mae = mean(abs(err)),
      rmse = sqrt(mean(err^2)),
      bias = mean(err),
      corr = suppressWarnings(stats::cor(qhat, q_ref)),
      stringsAsFactors = FALSE
    )
  }

  collect_rows[[length(collect_rows) + 1L]] <- metric_row("vb", vb_path$mean, vb_path)
  collect_rows[[length(collect_rows) + 1L]] <- metric_row("mcmc", m_path$mean, m_path)

  key <- sprintf("%s_tau_%s", model, tau_lab(tau))
  plot_payload[[key]] <- list(model = model, tau = tau, q_ref = q_ref, vb = vb_path, mcmc = m_path)
  fit_file_payload[[key]] <- list(vb_file = vb_file, mcmc_file = mcmc_file)
}

metrics_df <- if (length(collect_rows)) do.call(rbind, collect_rows) else data.frame()
utils::write.csv(metrics_df, file.path(out_tables, "fit_metrics_by_task.csv"), row.names = FALSE)

# Runtime + diagnostic summary from pipeline table
runtime_diag <- summary_df
runtime_diag$vb_runtime_sec <- suppressWarnings(as.numeric(runtime_diag$vb_runtime_sec))
runtime_diag$mcmc_runtime_sec <- suppressWarnings(as.numeric(runtime_diag$mcmc_runtime_sec))
runtime_diag$ess_sigma <- suppressWarnings(as.numeric(runtime_diag$ess_sigma))
runtime_diag$ess_gamma <- suppressWarnings(as.numeric(runtime_diag$ess_gamma))
utils::write.csv(runtime_diag, file.path(out_tables, "runtime_diagnostics_summary.csv"), row.names = FALSE)

ld_diag_path <- file.path(out_tables, "vb_ld_diagnostics_summary.csv")
ld_diag <- read_csv_maybe_empty(ld_diag_path)
rhs_diag_path <- file.path(out_tables, "rhs_diagnostics_summary.csv")
rhs_diag <- read_csv_maybe_empty(rhs_diag_path)

# Pairwise comparisons (exAL vs AL within method/tau)
pair_rows <- list()
if (nrow(metrics_df) > 0) {
  taus <- sort(unique(metrics_df$tau))
  methods <- sort(unique(metrics_df$method))
  for (tau in taus) {
    for (method in methods) {
      ex <- metrics_df[metrics_df$model == "exal" & metrics_df$tau == tau & metrics_df$method == method, , drop = FALSE]
      al <- metrics_df[metrics_df$model == "al" & metrics_df$tau == tau & metrics_df$method == method, , drop = FALSE]
      if (nrow(ex) == 1 && nrow(al) == 1) {
        pair_rows[[length(pair_rows) + 1L]] <- data.frame(
          tau = tau,
          method = method,
          rmse_exal = ex$rmse,
          rmse_al = al$rmse,
          mae_exal = ex$mae,
          mae_al = al$mae,
          rmse_delta_exal_minus_al = ex$rmse - al$rmse,
          mae_delta_exal_minus_al = ex$mae - al$mae,
          stringsAsFactors = FALSE
        )
      }
    }
  }
}
pair_df <- if (length(pair_rows)) do.call(rbind, pair_rows) else data.frame()
utils::write.csv(pair_df, file.path(out_tables, "pairwise_exal_vs_al.csv"), row.names = FALSE)

# Acceptance gates
ess_sigma_min <- safe_num(Sys.getenv("EXDQLM_STATIC_GATE_ESS_SIGMA_MIN", "30"), 30)
ess_gamma_min <- safe_num(Sys.getenv("EXDQLM_STATIC_GATE_ESS_GAMMA_MIN", "20"), 20)
ld_xi_median_abs_max <- safe_num(Sys.getenv("EXDQLM_STATIC_GATE_LD_XI_MEDIAN_ABS_MAX", "0.10"), 0.10)
ld_flip_rate_max <- safe_num(Sys.getenv("EXDQLM_STATIC_GATE_LD_FLIP_RATE_MAX", "0.55"), 0.55)
ld_fallback_max <- safe_num(Sys.getenv("EXDQLM_STATIC_GATE_LD_FALLBACK_MAX", "0.10"), 0.10)

vb_rows <- runtime_diag[, c("model", "tau", "beta_prior", "vb_converged", "vb_stop_reason", "ess_sigma", "ess_gamma", "status"), drop = FALSE]
vb_rows$gate_vb_converged <- isTRUE(vb_rows$vb_converged) # placeholder scalar
vb_rows$gate_vb_converged <- as.logical(vb_rows$vb_converged)
vb_rows$gate_mcmc_ess_sigma <- !is.na(vb_rows$ess_sigma) & vb_rows$ess_sigma >= ess_sigma_min
vb_rows$gate_mcmc_ess_gamma <- ifelse(
  vb_rows$model == "exal",
  !is.na(vb_rows$ess_gamma) & vb_rows$ess_gamma >= ess_gamma_min,
  TRUE
)
if (nrow(ld_diag) > 0) {
  vb_rows <- merge(vb_rows, ld_diag, by = c("model", "tau"), all.x = TRUE)
} else {
  vb_rows$ld_xi_median_abs_tail <- NA_real_
  vb_rows$ld_sigma_flip_rate_tail <- NA_real_
  vb_rows$ld_gamma_flip_rate_tail <- NA_real_
  vb_rows$ld_mode_fallback_rate <- NA_real_
  vb_rows$ld_local_mode_pass <- NA
}
rhs_exal <- vb_rows$model == "exal" & !is.na(vb_rows$beta_prior) & vb_rows$beta_prior == "rhs"
ridge_exal <- vb_rows$model == "exal" & !rhs_exal
vb_rows$gate_vb_ld_stable <- TRUE
vb_rows$gate_vb_ld_stable[ridge_exal] <-
  !is.na(vb_rows$ld_xi_median_abs_tail[ridge_exal]) &
  vb_rows$ld_xi_median_abs_tail[ridge_exal] <= ld_xi_median_abs_max &
  (is.na(vb_rows$ld_sigma_flip_rate_tail[ridge_exal]) | vb_rows$ld_sigma_flip_rate_tail[ridge_exal] <= ld_flip_rate_max) &
  (is.na(vb_rows$ld_gamma_flip_rate_tail[ridge_exal]) | vb_rows$ld_gamma_flip_rate_tail[ridge_exal] <= ld_flip_rate_max) &
  (is.na(vb_rows$ld_mode_fallback_rate[ridge_exal]) | vb_rows$ld_mode_fallback_rate[ridge_exal] <= ld_fallback_max)
vb_rows$gate_vb_ld_stable[rhs_exal] <-
  !is.na(vb_rows$ld_xi_median_abs_tail[rhs_exal]) &
  vb_rows$ld_xi_median_abs_tail[rhs_exal] <= ld_xi_median_abs_max &
  (is.na(vb_rows$ld_mode_fallback_rate[rhs_exal]) | vb_rows$ld_mode_fallback_rate[rhs_exal] <= ld_fallback_max)
vb_rows$gate_vb_ld_local_mode <- ifelse(
  vb_rows$model == "exal",
  !is.na(vb_rows$ld_local_mode_pass) & as.logical(vb_rows$ld_local_mode_pass),
  TRUE
)
vb_rows$gate_mcmc_kernel_exact <- ifelse(
  vb_rows$model == "exal",
  !is.na(summary_df$mcmc_gamma_kernel_exact[match(paste(vb_rows$model, vb_rows$tau), paste(summary_df$model, summary_df$tau))]) &
    as.logical(summary_df$mcmc_gamma_kernel_exact[match(paste(vb_rows$model, vb_rows$tau), paste(summary_df$model, summary_df$tau))]),
  TRUE
)

# Accuracy gate compares VB vs MCMC RMSE for the same model/tau.
acc_df <- data.frame(model = character(0), tau = numeric(0), gate_accuracy = logical(0), stringsAsFactors = FALSE)
if (nrow(metrics_df) > 0) {
  keys <- unique(metrics_df[, c("model", "tau")])
  acc_rows <- lapply(seq_len(nrow(keys)), function(i) {
    m <- keys$model[i]
    t <- keys$tau[i]
    vb <- metrics_df[metrics_df$model == m & metrics_df$tau == t & metrics_df$method == "vb", , drop = FALSE]
    mc <- metrics_df[metrics_df$model == m & metrics_df$tau == t & metrics_df$method == "mcmc", , drop = FALSE]
    gate <- FALSE
    if (nrow(vb) == 1 && nrow(mc) == 1 && is.finite(vb$rmse) && is.finite(mc$rmse)) {
      gate <- (mc$rmse <= 1.25 * vb$rmse)
    }
    data.frame(model = m, tau = t, gate_accuracy = gate, stringsAsFactors = FALSE)
  })
  acc_df <- do.call(rbind, acc_rows)
}

gate_df <- merge(vb_rows, acc_df, by = c("model", "tau"), all.x = TRUE)
gate_df$gate_accuracy[is.na(gate_df$gate_accuracy)] <- FALSE
gate_df$overall_pass <- with(
  gate_df,
  gate_vb_converged & gate_vb_ld_stable & gate_vb_ld_local_mode &
    gate_mcmc_kernel_exact & gate_mcmc_ess_sigma & gate_mcmc_ess_gamma & gate_accuracy
)
utils::write.csv(gate_df, file.path(out_tables, "acceptance_gate_summary.csv"), row.names = FALSE)

# Plots: per tau compare truth vs four model-method combos when all available.
if (nrow(metrics_df) > 0) {
  for (tau in sort(unique(metrics_df$tau))) {
    target_keys <- c(
      sprintf("al_tau_%s", tau_lab(tau)),
      sprintf("exal_tau_%s", tau_lab(tau))
    )
    if (!all(target_keys %in% names(plot_payload))) next

    al <- plot_payload[[target_keys[1]]]
    ex <- plot_payload[[target_keys[2]]]

    png(file.path(out_plots, sprintf("fit_compare_tau_%s.png", tau_lab(tau))), width = 1400, height = 700)
    par(mfrow = c(1, 2), mar = c(4, 4, 3, 1))

    idx <- seq_len(length(al$q_ref))
    plot(idx, al$q_ref, type = "l", lwd = 2, col = "black",
         main = sprintf("Static Quantile Fit (tau=%.2f)", tau), xlab = "t", ylab = "quantile")
    lines(idx, al$vb$mean, col = "#1f77b4", lwd = 1.5)
    lines(idx, al$mcmc$mean, col = "#17becf", lwd = 1.5)
    lines(idx, ex$vb$mean, col = "#d62728", lwd = 1.5)
    lines(idx, ex$mcmc$mean, col = "#ff7f0e", lwd = 1.5)
    legend("topright", bty = "n", lwd = c(2, 1.5, 1.5, 1.5, 1.5),
           col = c("black", "#1f77b4", "#17becf", "#d62728", "#ff7f0e"),
           legend = c("truth", "AL-VB", "AL-MCMC", "exAL-VB", "exAL-MCMC"))

    err_al_m <- al$mcmc$mean - al$q_ref
    err_ex_m <- ex$mcmc$mean - ex$q_ref
    plot(idx, err_al_m, type = "l", col = "#17becf", lwd = 1.5,
         main = sprintf("MCMC Error (tau=%.2f)", tau), xlab = "t", ylab = "error")
    lines(idx, err_ex_m, col = "#ff7f0e", lwd = 1.5)
    abline(h = 0, lty = 2, col = "grey40")
    legend("topright", bty = "n", lwd = 1.5,
           col = c("#17becf", "#ff7f0e"),
           legend = c("AL-MCMC", "exAL-MCMC"))

    dev.off()

    # Higher-detail comparison panel in dedicated folder.
    png(file.path(out_plots_comp, sprintf("fit_compare_tau_%s_detailed.png", tau_lab(tau))), width = 1800, height = 900)
    par(mfrow = c(2, 2), mar = c(4, 4, 3, 1))

    # Truth + all estimates over observation index.
    plot(idx, y_obs, type = "l", col = "grey70", lwd = 1.0,
         main = sprintf("Observed y with Quantile Fits (tau=%.2f)", tau), xlab = "t", ylab = "value")
    lines(idx, al$q_ref, col = "black", lwd = 2.0, lty = 2)
    lines(idx, al$vb$mean, col = "#1f77b4", lwd = 1.4)
    lines(idx, al$mcmc$mean, col = "#17becf", lwd = 1.4)
    lines(idx, ex$vb$mean, col = "#d62728", lwd = 1.4)
    lines(idx, ex$mcmc$mean, col = "#ff7f0e", lwd = 1.4)
    legend("topright", bty = "n", lwd = c(1.0, 2.0, 1.4, 1.4, 1.4, 1.4),
           col = c("grey70", "black", "#1f77b4", "#17becf", "#d62728", "#ff7f0e"),
           lty = c(1, 2, 1, 1, 1, 1),
           legend = c("y", "truth", "AL-VB", "AL-MCMC", "exAL-VB", "exAL-MCMC"))

    # Error series by method.
    plot(idx, y_obs - al$vb$mean, type = "l", col = "#1f77b4", lwd = 1.2,
         main = "Residual Series", xlab = "t", ylab = "y - qhat")
    lines(idx, y_obs - al$mcmc$mean, col = "#17becf", lwd = 1.2)
    lines(idx, y_obs - ex$vb$mean, col = "#d62728", lwd = 1.2)
    lines(idx, y_obs - ex$mcmc$mean, col = "#ff7f0e", lwd = 1.2)
    abline(h = 0, lty = 2, col = "grey35")
    legend("topright", bty = "n", lwd = 1.2,
           col = c("#1f77b4", "#17becf", "#d62728", "#ff7f0e"),
           legend = c("AL-VB", "AL-MCMC", "exAL-VB", "exAL-MCMC"))

    # Absolute error comparison.
    plot(idx, abs(y_obs - al$q_ref), type = "l", col = "black", lwd = 1.4,
         main = "Absolute Error vs Truth", xlab = "t", ylab = "|qhat - q_true|")
    lines(idx, abs(al$vb$mean - al$q_ref), col = "#1f77b4", lwd = 1.2)
    lines(idx, abs(al$mcmc$mean - al$q_ref), col = "#17becf", lwd = 1.2)
    lines(idx, abs(ex$vb$mean - ex$q_ref), col = "#d62728", lwd = 1.2)
    lines(idx, abs(ex$mcmc$mean - ex$q_ref), col = "#ff7f0e", lwd = 1.2)
    legend("topright", bty = "n", lwd = 1.2,
           col = c("#1f77b4", "#17becf", "#d62728", "#ff7f0e"),
           legend = c("AL-VB", "AL-MCMC", "exAL-VB", "exAL-MCMC"))

    # Coverage indicator over t.
    cov_al <- as.integer(y_obs <= al$mcmc$mean)
    cov_ex <- as.integer(y_obs <= ex$mcmc$mean)
    plot(idx, cov_al, type = "h", col = "#17becf", lwd = 1,
         main = "Indicator(y <= qhat_MCMC)", xlab = "t", ylab = "indicator", ylim = c(0, 1))
    lines(idx, cov_ex, type = "h", col = grDevices::adjustcolor("#ff7f0e", 0.6), lwd = 1)
    abline(h = tau, lty = 2, col = "grey35")
    legend("topright", bty = "n", lwd = 2, lty = 1,
           col = c("#17becf", "#ff7f0e", "grey35"),
           legend = c("AL-MCMC", "exAL-MCMC", sprintf("target tau=%.2f", tau)))
    dev.off()

    # Cloud plot: data cloud around truth/estimate quantile curves vs selected covariate.
    draw_curve <- function(x, yy, col, lwd = 2, lty = 1) {
      ok <- is.finite(x) & is.finite(yy)
      if (sum(ok) < 5) return(invisible(NULL))
      ord <- order(x[ok], yy[ok])
      graphics::lines(x[ok][ord], yy[ok][ord], col = col, lwd = lwd, lty = lty)
    }
    png(file.path(out_plots_cloud, sprintf("cloud_quantile_fit_tau_%s.png", tau_lab(tau))), width = 1400, height = 900)
    graphics::plot(
      x_primary, y_obs,
      pch = 16, cex = 0.35, col = grDevices::adjustcolor("grey35", alpha.f = 0.24),
      xlab = sprintf("covariate: %s", covar_name), ylab = "y",
      main = sprintf("Data Cloud with True/Estimated Quantiles (tau=%.2f)", tau)
    )
    draw_curve(x_primary, al$q_ref, col = "black", lwd = 2.4, lty = 2)
    draw_curve(x_primary, al$vb$mean, col = "#1f77b4", lwd = 2.0)
    draw_curve(x_primary, al$mcmc$mean, col = "#17becf", lwd = 2.0)
    draw_curve(x_primary, ex$vb$mean, col = "#d62728", lwd = 2.0)
    draw_curve(x_primary, ex$mcmc$mean, col = "#ff7f0e", lwd = 2.0)
    graphics::legend("topleft", bty = "n", lwd = c(2.4, 2, 2, 2, 2),
                     lty = c(2, 1, 1, 1, 1),
                     col = c("black", "#1f77b4", "#17becf", "#d62728", "#ff7f0e"),
                     legend = c("truth", "AL-VB", "AL-MCMC", "exAL-VB", "exAL-MCMC"))
    grDevices::dev.off()

    # Residual density diagnostics.
    res_list <- list(
      `AL-VB` = y_obs - al$vb$mean,
      `AL-MCMC` = y_obs - al$mcmc$mean,
      `exAL-VB` = y_obs - ex$vb$mean,
      `exAL-MCMC` = y_obs - ex$mcmc$mean
    )
    dens_cols <- c("#1f77b4", "#17becf", "#d62728", "#ff7f0e")
    dens_vals <- lapply(res_list, function(z) stats::density(z[is.finite(z)], n = 512))
    xlim_den <- range(unlist(lapply(dens_vals, `[[`, "x")), finite = TRUE)
    ylim_den <- range(unlist(lapply(dens_vals, `[[`, "y")), finite = TRUE)
    png(file.path(out_plots_diag, sprintf("residual_density_tau_%s.png", tau_lab(tau))), width = 1400, height = 900)
    plot(dens_vals[[1]], col = dens_cols[1], lwd = 2, main = sprintf("Residual Density (tau=%.2f)", tau),
         xlab = "residual (y - qhat)", ylab = "density", xlim = xlim_den, ylim = ylim_den)
    for (k in 2:length(dens_vals)) lines(dens_vals[[k]], col = dens_cols[k], lwd = 2)
    abline(v = 0, lty = 2, col = "grey35")
    legend("topright", bty = "n", lwd = 2, col = dens_cols, legend = names(res_list))
    dev.off()

    # MCMC/VB trace diagnostics by tau using AL vs exAL.
    ex_files <- fit_file_payload[[target_keys[2]]]
    al_files <- fit_file_payload[[target_keys[1]]]
    ex_m_fit <- readRDS(ex_files$mcmc_file)$fit
    al_m_fit <- readRDS(al_files$mcmc_file)$fit
    ex_v_fit <- readRDS(ex_files$vb_file)$fit
    al_v_fit <- readRDS(al_files$vb_file)$fit

    ex_sig <- as.numeric(ex_m_fit$samp.sigma)
    al_sig <- as.numeric(al_m_fit$samp.sigma)
    if (length(ex_sig) > 1 && length(al_sig) > 1) {
      png(file.path(out_plots_diag, sprintf("mcmc_sigma_trace_tau_%s.png", tau_lab(tau))), width = 1400, height = 900)
      plot(seq_along(al_sig), al_sig, type = "l", col = "#17becf", lwd = 1.4,
           xlab = "iteration", ylab = "sigma", main = sprintf("MCMC Sigma Trace (tau=%.2f)", tau))
      lines(seq_along(ex_sig), ex_sig, col = "#ff7f0e", lwd = 1.4)
      legend("topright", bty = "n", lwd = 2, col = c("#17becf", "#ff7f0e"), legend = c("AL", "exAL"))
      dev.off()
    }

    ex_gam <- as.numeric(ex_m_fit$samp.gamma)
    if (length(ex_gam) > 1) {
      png(file.path(out_plots_diag, sprintf("mcmc_gamma_trace_exal_tau_%s.png", tau_lab(tau))), width = 1400, height = 900)
      plot(seq_along(ex_gam), ex_gam, type = "l", col = "#d62728", lwd = 1.4,
           xlab = "iteration", ylab = "gamma", main = sprintf("MCMC Gamma Trace exAL (tau=%.2f)", tau))
      dev.off()
    }

    al_elbo <- as.numeric(al_v_fit$diagnostics$elbo)
    ex_elbo <- as.numeric(ex_v_fit$diagnostics$elbo)
    if (length(al_elbo) > 1 || length(ex_elbo) > 1) {
      y_lim <- range(c(al_elbo, ex_elbo), finite = TRUE)
      png(file.path(out_plots_diag, sprintf("vb_elbo_trace_tau_%s.png", tau_lab(tau))), width = 1400, height = 900)
      plot(seq_along(al_elbo), al_elbo, type = "l", col = "#1f77b4", lwd = 1.4,
           xlab = "iteration", ylab = "ELBO", main = sprintf("VB ELBO Trace (tau=%.2f)", tau), ylim = y_lim)
      lines(seq_along(ex_elbo), ex_elbo, col = "#d62728", lwd = 1.4)
      legend("bottomright", bty = "n", lwd = 2, col = c("#1f77b4", "#d62728"), legend = c("AL", "exAL"))
      dev.off()
    }
  }

  # RHS-only coefficient tree plots.
  for (key in names(plot_payload)) {
    files <- fit_file_payload[[key]]
    tau <- plot_payload[[key]]$tau
    model <- plot_payload[[key]]$model
    for (method in c("vb", "mcmc")) {
      fit_path <- if (identical(method, "vb")) files$vb_file else files$mcmc_file
      if (is.null(fit_path) || !file.exists(fit_path)) next
      fit <- readRDS(fit_path)$fit
      if (is.null(fit$beta_prior) || !identical(fit$beta_prior$type, "rhs")) next
      if (identical(method, "vb")) {
        beta_draws <- matrix(as.numeric(fit$qbeta$m), nrow = 1L)
        colnames(beta_draws) <- colnames(X)
        lambda_sum <- if (!is.null(fit$beta_prior$summary$lambda)) fit$beta_prior$summary$lambda else NULL
      } else {
        beta_draws <- as.matrix(fit$samp.beta)
        lambda_sum <- if (!is.null(fit$rhs.diagnostics$summary$lambda)) fit$rhs.diagnostics$summary$lambda else NULL
      }
      plot_coef_tree(
        file.path(out_plots_rhs, sprintf("%s_%s_tau_%s_coef_tree.png", method, model, tau_lab(tau))),
        beta_draws = beta_draws,
        main = sprintf("%s %s coefficient tree (tau=%.2f)", toupper(method), toupper(model), tau),
        lambda_summary = lambda_sum
      )
    }
  }

  # Runtime bar plot
  done_df <- runtime_diag[runtime_diag$status %in% c("done", "skipped_existing"), , drop = FALSE]
  if (nrow(done_df) > 0) {
    ord <- order(done_df$model, done_df$tau)
    done_df <- done_df[ord, ]
    labels <- sprintf("%s@%.2f", done_df$model, done_df$tau)
    vb_rt <- suppressWarnings(as.numeric(done_df$vb_runtime_sec))
    mc_rt <- suppressWarnings(as.numeric(done_df$mcmc_runtime_sec))
    if (any(is.finite(vb_rt)) || any(is.finite(mc_rt))) {
      mat <- rbind(ifelse(is.finite(vb_rt), vb_rt, 0), ifelse(is.finite(mc_rt), mc_rt, 0))

      png(file.path(out_plots, "runtime_vb_mcmc_by_task.png"), width = 1200, height = 700)
      barplot(mat, beside = TRUE, names.arg = labels, las = 2,
              col = c("#4e79a7", "#f28e2b"), ylab = "seconds",
              main = "Runtime by Task (Static VB vs MCMC)")
      legend("topright", bty = "n", fill = c("#4e79a7", "#f28e2b"), legend = c("VB", "MCMC"))
      mtext("Zero-height bars indicate runtime unavailable in source summary.", side = 1, line = 6, cex = 0.8)
      dev.off()
    }
  }
}

# Markdown summary
summary_md <- file.path(out_tables, "report_summary.md")
con <- file(summary_md, open = "wt")
on.exit(close(con), add = TRUE)

writeLines(c(
  "# Static VB/MCMC Report",
  "",
  sprintf("- run_root: `%s`", run_root),
  sprintf("- summary_source: `%s`", summary_path),
  sprintf("- sim_path: `%s`", sim_path),
  sprintf("- generated_at: `%s`", format(Sys.time(), "%Y-%m-%d %H:%M:%S")),
  sprintf("- primary_cloud_covariate: `%s`", covar_name),
  "",
  sprintf("- tasks_total: %d", nrow(summary_df)),
  sprintf("- tasks_done_or_reused: %d", sum(summary_df$status %in% c("done", "skipped_existing"), na.rm = TRUE)),
  sprintf("- tasks_reused_existing: %d", sum(summary_df$status == "skipped_existing", na.rm = TRUE)),
  sprintf("- tasks_failed: %d", sum(summary_df$status == "failed", na.rm = TRUE)),
  "",
  "## Plot Outputs",
  sprintf("- root_plot_png_count: %d", length(list.files(out_plots, pattern = "\\.png$", full.names = TRUE))),
  sprintf("- comparison_plot_png_count: %d", length(list.files(out_plots_comp, pattern = "\\.png$", full.names = TRUE))),
  sprintf("- cloud_plot_png_count: %d", length(list.files(out_plots_cloud, pattern = "\\.png$", full.names = TRUE))),
  sprintf("- diagnostics_plot_png_count: %d", length(list.files(out_plots_diag, pattern = "\\.png$", full.names = TRUE))),
  sprintf("- rhs_plot_png_count: %d", length(list.files(out_plots_rhs, pattern = "\\.png$", full.names = TRUE))),
  "",
  "## Gate thresholds",
  sprintf("- ESS sigma min: %.1f", ess_sigma_min),
  sprintf("- ESS gamma min (exAL): %.1f", ess_gamma_min),
  sprintf("- LD xi median abs tail max (exAL): %.3f", ld_xi_median_abs_max),
  sprintf("- LD flip rate tail max (exAL): %.3f", ld_flip_rate_max),
  sprintf("- LD fallback rate max (exAL): %.3f", ld_fallback_max),
  "- accuracy gate: RMSE(MCMC) <= 1.25 * RMSE(VB)",
  "",
  sprintf("- gate_pass_count: %d", sum(gate_df$overall_pass, na.rm = TRUE)),
  sprintf("- gate_fail_count: %d", sum(!gate_df$overall_pass, na.rm = TRUE)),
  sprintf("- rhs_rows: %d", if (nrow(rhs_diag)) nrow(rhs_diag) else 0L),
  sprintf("- rhs_collapse_flag_count: %d", if (nrow(rhs_diag) && "rhs_collapse_flag" %in% names(rhs_diag)) sum(rhs_diag$rhs_collapse_flag, na.rm = TRUE) else 0L)
), con)

cat(sprintf("S4 report generated under: %s\n", run_root))

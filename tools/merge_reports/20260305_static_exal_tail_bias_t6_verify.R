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

safe_int <- function(x, default) {
  v <- suppressWarnings(as.integer(x)[1])
  if (!is.finite(v) || is.na(v)) default else v
}

safe_num <- function(x, default) {
  v <- suppressWarnings(as.numeric(x)[1])
  if (!is.finite(v) || is.na(v)) default else v
}

tau_lab <- function(tau) gsub("\\.", "p", format(as.numeric(tau), nsmall = 2))
`%||%` <- function(x, y) if (is.null(x)) y else x

baseline_run_root <- Sys.getenv(
  "EXDQLM_STATIC_T6_BASELINE_RUN_ROOT",
  "results/sim_suite_static/static_vb_then_mcmc_tt5000_vbns1000_burn2000_n1000_20260305_160734"
)
sim_path <- Sys.getenv(
  "EXDQLM_STATIC_T6_SIM_PATH",
  "results/sim_suite_static/series/static_exal_rich1d_mcq/sim_output.rds"
)
out_dir <- Sys.getenv(
  "EXDQLM_STATIC_T6_OUT_DIR",
  "results/sim_suite_static/audits/static_exal_tail_bias_t6_20260305"
)

if (!dir.exists(baseline_run_root)) stop("Missing baseline run root: ", baseline_run_root)
if (!file.exists(sim_path)) stop("Missing sim file: ", sim_path)

dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(out_dir, "fits"), recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(out_dir, "plots"), recursive = TRUE, showWarnings = FALSE)
overwrite_existing <- identical(tolower(Sys.getenv("EXDQLM_STATIC_T6_OVERWRITE", "false")), "true")

cfg <- readRDS(file.path(baseline_run_root, "tables", "run_config.rds"))
sim <- readRDS(sim_path)
TT <- min(as.integer(cfg$TT)[1], length(sim$y))
y <- as.numeric(sim$y[seq_len(TT)])
X <- as.matrix(sim$extras$X[seq_len(TT), , drop = FALSE])
q_true <- as.matrix(sim$q[seq_len(TT), , drop = FALSE])
p_grid <- as.numeric(sim$p)
focus_taus <- c(0.05, 0.95)

baseline_cfg_ld <- cfg$vb$ld
if (is.null(baseline_cfg_ld)) baseline_cfg_ld <- list()

xi_replicates <- safe_int(Sys.getenv("EXDQLM_STATIC_T6_XI_REPLICATES", "4"), 4L)
xi_total_draws <- safe_int(Sys.getenv("EXDQLM_STATIC_T6_XI_TOTAL_DRAWS", "1000"), 1000L)
xi_draws_per_rep <- max(50L, ceiling(xi_total_draws / xi_replicates))
reuse_seed <- safe_int(Sys.getenv("EXDQLM_STATIC_T6_XI_REUSE_SEED", "20260305"), 20260305L)
vb_max_iter <- safe_int(Sys.getenv("EXDQLM_STATIC_T6_VB_MAX_ITER", as.character(cfg$vb$max_iter %||% 500L)), cfg$vb$max_iter %||% 500L)
vb_tol <- safe_num(Sys.getenv("EXDQLM_STATIC_T6_VB_TOL", as.character(cfg$vb$tol %||% 1e-4)), cfg$vb$tol %||% 1e-4)

closest_q <- function(tau) {
  q_true[, which.min(abs(p_grid - tau))]
}

metric_row <- function(label, tau, qhat, qref) {
  err <- as.numeric(qhat - qref)
  data.frame(
    source = label,
    tau = tau,
    rmse = sqrt(mean(err^2)),
    mae = mean(abs(err)),
    bias = mean(err),
    corr = suppressWarnings(stats::cor(qhat, qref)),
    stringsAsFactors = FALSE
  )
}

load_fit <- function(kind, model, tau) {
  path <- file.path(
    baseline_run_root,
    "fits",
    kind,
    sprintf("%s_%s_tau_%s_fit.rds", kind, model, tau_lab(tau))
  )
  if (!file.exists(path)) stop("Missing baseline fit file: ", path)
  readRDS(path)$fit
}

default_cov <- {
  cn <- colnames(X)
  nn <- setdiff(cn, c("intercept", "(Intercept)"))
  if (length(nn)) nn[1] else cn[1]
}
x_primary <- as.numeric(X[, default_cov])

metrics_rows <- list()
diag_rows <- list()

for (i in seq_along(focus_taus)) {
  tau <- focus_taus[i]
  true_q <- closest_q(tau)

  al_vb_fit <- load_fit("vb", "al", tau)
  al_mc_fit <- load_fit("mcmc", "al", tau)
  ex_vb_fit <- load_fit("vb", "exal", tau)
  ex_mc_fit <- load_fit("mcmc", "exal", tau)
  corrected_fit_path <- file.path(out_dir, "fits", sprintf("vb_exal_corrected_tau_%s_fit.rds", tau_lab(tau)))

  if (!overwrite_existing && file.exists(corrected_fit_path)) {
    corrected_fit <- readRDS(corrected_fit_path)
  } else {
    set.seed(5000L + i)
    corrected_fit <- exal_static_LDVB(
      y = y,
      X = X,
      p0 = tau,
      max_iter = vb_max_iter,
      tol = vb_tol,
      dqlm.ind = FALSE,
      n_samp_xi = xi_draws_per_rep,
      ld_controls = utils::modifyList(
        baseline_cfg_ld,
        list(
          xi_mode = "replicated",
          xi_replicates = xi_replicates,
          reuse_draws = TRUE,
          reuse_seed = reuse_seed + i - 1L,
          store_trace = TRUE
        )
      ),
      verbose = FALSE
    )

    saveRDS(corrected_fit, corrected_fit_path, compress = "xz")
  }

  al_vb_path <- .static_quantile_path_from_fit(al_vb_fit, X, algorithm = "vb")
  al_mc_path <- .static_quantile_path_from_fit(al_mc_fit, X, algorithm = "mcmc")
  ex_vb_path <- .static_quantile_path_from_fit(ex_vb_fit, X, algorithm = "vb")
  ex_mc_path <- .static_quantile_path_from_fit(ex_mc_fit, X, algorithm = "mcmc")
  ex_vb_corr_path <- .static_quantile_path_from_fit(corrected_fit, X, algorithm = "vb")

  metrics_rows[[length(metrics_rows) + 1L]] <- metric_row("al_vb_baseline", tau, al_vb_path$mean, true_q)
  metrics_rows[[length(metrics_rows) + 1L]] <- metric_row("al_mcmc_baseline", tau, al_mc_path$mean, true_q)
  metrics_rows[[length(metrics_rows) + 1L]] <- metric_row("exal_vb_baseline", tau, ex_vb_path$mean, true_q)
  metrics_rows[[length(metrics_rows) + 1L]] <- metric_row("exal_mcmc_baseline", tau, ex_mc_path$mean, true_q)
  metrics_rows[[length(metrics_rows) + 1L]] <- metric_row("exal_vb_corrected", tau, ex_vb_corr_path$mean, true_q)

  base_ld <- ex_vb_fit$diagnostics$ld_block
  corr_ld <- corrected_fit$diagnostics$ld_block
  base_trace <- if (is.data.frame(base_ld$trace)) base_ld$trace else data.frame()
  corr_trace <- if (is.data.frame(corr_ld$trace)) corr_ld$trace else data.frame()
  base_last <- if (nrow(base_trace)) base_trace[nrow(base_trace), , drop = FALSE] else NULL
  corr_last <- if (nrow(corr_trace)) corr_trace[nrow(corr_trace), , drop = FALSE] else NULL
  corr_mode <- if (!is.null(corr_ld$mode_quality)) corr_ld$mode_quality else list()

  diag_rows[[length(diag_rows) + 1L]] <- data.frame(
    tau = tau,
    baseline_iter = as.integer(ex_vb_fit$iter)[1],
    baseline_stop_reason = as.character(ex_vb_fit$diagnostics$convergence$stop_reason)[1],
    baseline_xi_rel_last = if (!is.null(base_last)) as.numeric(base_last$xi_rel_drift)[1] else NA_real_,
    baseline_ld_cov_condition_last = if (!is.null(base_last)) as.numeric(base_last$ld_cov_condition)[1] else NA_real_,
    corrected_iter = as.integer(corrected_fit$iter)[1],
    corrected_stop_reason = as.character(corrected_fit$diagnostics$convergence$stop_reason)[1],
    corrected_xi_rel_last = if (!is.null(corr_last)) as.numeric(corr_last$xi_rel_drift)[1] else NA_real_,
    corrected_xi_mcse_max_last = if (!is.null(corr_last)) as.numeric(corr_last$xi_mcse_max)[1] else NA_real_,
    corrected_ld_cov_condition_last = if (!is.null(corr_last)) as.numeric(corr_last$ld_cov_condition)[1] else NA_real_,
    corrected_mode_grad_inf_norm = if (!is.null(corr_mode$grad_inf_norm)) as.numeric(corr_mode$grad_inf_norm)[1] else NA_real_,
    corrected_mode_neg_hess_condition = if (!is.null(corr_mode$neg_hess_condition)) as.numeric(corr_mode$neg_hess_condition)[1] else NA_real_,
    corrected_local_mode_pass = if (!is.null(corr_mode$local_mode_pass)) isTRUE(corr_mode$local_mode_pass) else NA,
    xi_draws_per_rep = xi_draws_per_rep,
    xi_replicates = xi_replicates,
    stringsAsFactors = FALSE
  )

  png(file.path(out_dir, "plots", sprintf("t6_tail_compare_tau_%s.png", tau_lab(tau))), width = 1500, height = 900, res = 140)
  plot(
    x_primary, y,
    pch = 16, cex = 0.35,
    col = grDevices::adjustcolor("grey35", alpha.f = 0.18),
    xlab = default_cov, ylab = "y",
    main = sprintf("T6 static tail verification (tau=%.2f)", tau)
  )
  ord <- order(x_primary)
  lines(x_primary[ord], true_q[ord], lwd = 2.2, lty = 2, col = "#202020")
  lines(x_primary[ord], al_mc_path$mean[ord], lwd = 2.0, col = "#1F78B4")
  lines(x_primary[ord], ex_vb_path$mean[ord], lwd = 2.0, col = "#C73E1D")
  lines(x_primary[ord], ex_vb_corr_path$mean[ord], lwd = 2.2, col = "#0E7490")
  legend(
    "topleft",
    legend = c("truth", "AL MCMC baseline", "exAL VB baseline", "exAL VB corrected"),
    col = c("#202020", "#1F78B4", "#C73E1D", "#0E7490"),
    lty = c(2, 1, 1, 1),
    lwd = c(2.2, 2, 2, 2.2),
    bty = "n"
  )
  dev.off()
}

metrics_df <- do.call(rbind, metrics_rows)
diag_df <- do.call(rbind, diag_rows)
write.csv(metrics_df, file.path(out_dir, "t6_metrics_comparison.csv"), row.names = FALSE)
write.csv(diag_df, file.path(out_dir, "t6_diagnostics_before_after.csv"), row.names = FALSE)

delta_rows <- lapply(focus_taus, function(tau) {
  vb_base <- metrics_df[metrics_df$source == "exal_vb_baseline" & metrics_df$tau == tau, , drop = FALSE]
  vb_corr <- metrics_df[metrics_df$source == "exal_vb_corrected" & metrics_df$tau == tau, , drop = FALSE]
  al_ref <- metrics_df[metrics_df$source == "al_mcmc_baseline" & metrics_df$tau == tau, , drop = FALSE]
  data.frame(
    tau = tau,
    exal_vb_rmse_delta = vb_corr$rmse - vb_base$rmse,
    exal_vb_mae_delta = vb_corr$mae - vb_base$mae,
    corrected_vs_al_mcmc_rmse_delta = vb_corr$rmse - al_ref$rmse,
    stringsAsFactors = FALSE
  )
})
delta_df <- do.call(rbind, delta_rows)
write.csv(delta_df, file.path(out_dir, "t6_delta_summary.csv"), row.names = FALSE)

baseline_tail_rmse <- vapply(delta_df$tau, function(tau) {
  metrics_df$rmse[metrics_df$source == "exal_vb_baseline" & metrics_df$tau == tau][1]
}, numeric(1))
improved_all <- all(
  is.finite(delta_df$exal_vb_rmse_delta) &
    is.finite(baseline_tail_rmse) &
    delta_df$exal_vb_rmse_delta <= -0.05 * baseline_tail_rmse
)
local_mode_all <- all(diag_df$corrected_local_mode_pass %in% TRUE)
go_decision <- isTRUE(improved_all) && isTRUE(local_mode_all)

note_path <- file.path(out_dir, "t6_verification_note.md")
writeLines(c(
  "# T6 Focused Verification",
  "",
  sprintf("- baseline_run_root: `%s`", baseline_run_root),
  sprintf("- sim_path: `%s`", sim_path),
  sprintf("- generated_at: `%s`", format(Sys.time(), "%Y-%m-%d %H:%M:%S")),
  "",
  "## Verification scope",
  "- frozen rich static dataset only",
  "- exAL focus taus: `0.05`, `0.95`",
  "- corrected path: static `exAL` VB only",
  "- rationale: `P2-P4` change signoff metadata and VB approximation diagnostics; they do not change the exact static MCMC target",
  "",
  "## Controls",
  sprintf("- VB max_iter: `%d`", vb_max_iter),
  sprintf("- VB tol: `%s`", format(vb_tol, scientific = TRUE)),
  sprintf("- xi mode: `replicated`"),
  sprintf("- xi replicates: `%d`", xi_replicates),
  sprintf("- xi draws per replicate: `%d`", xi_draws_per_rep),
  sprintf("- xi reuse seed base: `%d`", reuse_seed),
  "",
  "## Decision",
  sprintf("- go_for_broader_reruns: `%s`", if (go_decision) "YES" else "NO"),
  sprintf("- local_mode_all: `%s`", if (local_mode_all) "TRUE" else "FALSE"),
  sprintf("- materially_improved_all_tail_rmse: `%s`", if (improved_all) "TRUE" else "FALSE"),
  "",
  "## Artifacts",
  "- `t6_metrics_comparison.csv`",
  "- `t6_diagnostics_before_after.csv`",
  "- `t6_delta_summary.csv`",
  "- `plots/t6_tail_compare_tau_0p05.png`",
  "- `plots/t6_tail_compare_tau_0p95.png`"
), note_path)

cat("T6 verification complete.\n")

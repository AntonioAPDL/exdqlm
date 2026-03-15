#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(matrixStats)
})

load_exdqlm <- function(repo_root = ".") {
  if (requireNamespace("devtools", quietly = TRUE)) {
    devtools::load_all(repo_root, quiet = TRUE)
    return(invisible(TRUE))
  }
  if (requireNamespace("pkgload", quietly = TRUE)) {
    pkgload::load_all(repo_root, quiet = TRUE)
    return(invisible(TRUE))
  }
  stop("Neither devtools nor pkgload is installed; cannot load local exdqlm package.")
}

load_exdqlm(".")

log_file <- "tools/merge_reports/20260305_postprocess_from_existing_fits.log"
dir.create(dirname(log_file), recursive = TRUE, showWarnings = FALSE)
if (file.exists(log_file)) file.remove(log_file)

log_msg <- function(...) {
  line <- paste(format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "|", paste(..., collapse = " "))
  cat(line, "\n")
  cat(line, "\n", file = log_file, append = TRUE)
  flush.console()
}

tau_lab <- function(tau) gsub("\\.", "p", format(as.numeric(tau), nsmall = 2))

read_csv_maybe_empty <- function(path) {
  if (!file.exists(path)) return(data.frame(stringsAsFactors = FALSE))
  utils::read.csv(path, stringsAsFactors = FALSE)
}

ensure_col <- function(df, nm, default = NA) {
  if (!nm %in% names(df)) df[[nm]] <- default
  df
}

resolve_out_root <- function() {
  args <- commandArgs(trailingOnly = TRUE)
  if (length(args) && nzchar(args[1]) && dir.exists(args[1])) return(args[1])
  rr <- Sys.getenv("EXDQLM_DYNAMIC_RUN_ROOT", "")
  if (nzchar(rr) && dir.exists(rr)) return(rr)
  "results/function_testing_20260304_vb_quantiles"
}

out_root <- resolve_out_root()
if (!dir.exists(out_root)) stop("Run root does not exist: ", out_root)

cfg_candidates <- c(
  file.path(out_root, "tables", "run_config.rds"),
  file.path(out_root, "run_config.rds")
)
cfg_path <- cfg_candidates[file.exists(cfg_candidates)][1]
if (!length(cfg_path) || is.na(cfg_path)) stop("run_config.rds not found under: ", out_root)
run_cfg <- readRDS(cfg_path)
sim_path <- if (!is.null(run_cfg$sim_path) && nzchar(run_cfg$sim_path)) {
  run_cfg$sim_path
} else {
  "results/sim_suite_dlm/series/dlm_constV_smallW/sim_output.rds"
}
if (!file.exists(sim_path)) stop("Simulation file not found: ", sim_path)
sim <- readRDS(sim_path)

TT <- if (!is.null(run_cfg$TT_used)) as.integer(run_cfg$TT_used) else as.integer(run_cfg$TT)
p_vec <- as.numeric(run_cfg$taus)
y <- as.numeric(sim$y[seq_len(TT)])
mu_true <- if (!is.null(sim$extras$mu)) as.numeric(sim$extras$mu[seq_len(TT)]) else rep(NA_real_, TT)

needed_dirs <- c(
  "derived",
  "plots/fit_within_inference",
  "plots/fit_between_inference",
  "plots/traces",
  "tables",
  "logs"
)
for (d in needed_dirs) dir.create(file.path(out_root, d), recursive = TRUE, showWarnings = FALSE)
out_tables <- file.path(out_root, "tables")

get_fit_file <- function(inference, model_name, tau) {
  file.path(out_root, "fits", inference,
            sprintf("%s_%s_tau_%s_fit.rds", inference, model_name, tau_lab(tau)))
}

parse_fit <- function(inference, model_name, tau) {
  fit_file <- get_fit_file(inference, model_name, tau)
  if (!file.exists(fit_file)) stop("Missing fit file: ", fit_file)
  wrap <- .exdqlm_unwrap_fit_bundle(readRDS(fit_file))
  fit <- wrap$fit
  meta <- wrap$meta

  data.frame(
    inference = inference,
    model = model_name,
    tau = tau,
    seed = if (!is.null(meta$seed)) as.integer(meta$seed) else NA_integer_,
    df_used = if (!is.null(meta$df_used)) as.numeric(meta$df_used) else NA_real_,
    runtime_sec = if (!is.null(meta$runtime_sec)) as.numeric(meta$runtime_sec) else NA_real_,
    iter_like = if (!is.null(fit$iter)) as.integer(fit$iter) else NA_integer_,
    converged = if (!is.null(fit$converged)) isTRUE(fit$converged) else NA,
    stop_reason = if (!is.null(fit$diagnostics$convergence$stop_reason)) {
      as.character(fit$diagnostics$convergence$stop_reason)[1]
    } else NA_character_,
    accept_rate_burn = if (!is.null(fit$accept.rate.burn)) as.numeric(fit$accept.rate.burn) else NA_real_,
    accept_rate_keep = if (!is.null(fit$accept.rate.keep)) as.numeric(fit$accept.rate.keep) else NA_real_,
    sigma_mean = mean(as.numeric(fit$samp.sigma)),
    gamma_mean = if (!is.null(fit$samp.gamma)) mean(as.numeric(fit$samp.gamma)) else NA_real_,
    fit_file = fit_file,
    stringsAsFactors = FALSE
  )
}

get_mh_adapt_table <- function(mh_diag) {
  if (is.null(mh_diag)) return(NULL)
  if (!is.null(mh_diag$adaptation)) return(mh_diag$adaptation)
  if (!is.null(mh_diag$adapt_trace)) return(mh_diag$adapt_trace)
  NULL
}

get_mh_scale_final <- function(mh_diag) {
  if (is.null(mh_diag)) return(NA_real_)
  if (!is.null(mh_diag$scale_final)) return(as.numeric(mh_diag$scale_final)[1])
  if (!is.null(mh_diag$final_scale)) return(as.numeric(mh_diag$final_scale)[1])
  NA_real_
}

derive_map_ci <- function(fit_obj, ci_level = 0.95) {
  TT_loc <- ncol(fit_obj$model$FF)
  theta_arr <- fit_obj$samp.theta
  if (inherits(theta_arr, "mcmc")) {
    class(theta_arr) <- setdiff(class(theta_arr), "mcmc")
  }
  if (!is.array(theta_arr)) stop("samp.theta is not an array after coercion.")
  ns <- dim(theta_arr)[3]
  q_draws <- vapply(seq_len(ns), function(i) {
    colSums(fit_obj$model$FF * theta_arr[, , i])
  }, numeric(TT_loc))

  alpha <- (1 - ci_level) / 2
  list(
    map = rowMeans(q_draws),
    lb = matrixStats::rowQuantiles(q_draws, probs = alpha),
    ub = matrixStats::rowQuantiles(q_draws, probs = 1 - alpha),
    n_draws = ns
  )
}

load_derived <- function(inference, model_name, tau) {
  readRDS(file.path(out_root, "derived", sprintf("%s_%s_tau_%s_summary.rds", inference, model_name, tau_lab(tau))))
}

plot_fit_compare <- function(file_path, idx_use, obj_a, obj_b, label_a, label_b, col_a, col_b, title_txt) {
  y_use <- y[idx_use]
  t_use <- idx_use
  true_q_use <- obj_a$true_q[idx_use]

  map_a <- obj_a$summary$map[idx_use]
  lb_a <- obj_a$summary$lb[idx_use]
  ub_a <- obj_a$summary$ub[idx_use]

  map_b <- obj_b$summary$map[idx_use]
  lb_b <- obj_b$summary$lb[idx_use]
  ub_b <- obj_b$summary$ub[idx_use]

  grDevices::png(file_path, width = 1900, height = 980, res = 150)
  y_lim <- range(c(y_use, true_q_use, lb_a, ub_a, lb_b, ub_b), finite = TRUE)

  graphics::plot(t_use, y_use, type = "l", col = "grey45", lwd = 1.0,
                 xlab = "time index", ylab = "value",
                 main = title_txt, ylim = y_lim)
  xx <- c(t_use, rev(t_use))
  graphics::polygon(xx, c(lb_a, rev(ub_a)), border = NA,
                    col = grDevices::adjustcolor(col_a, alpha.f = 0.16))
  graphics::polygon(xx, c(lb_b, rev(ub_b)), border = NA,
                    col = grDevices::adjustcolor(col_b, alpha.f = 0.16))

  graphics::lines(t_use, true_q_use, lwd = 2.0, lty = 2, col = "#202020")
  graphics::lines(t_use, map_a, lwd = 1.8, col = col_a)
  graphics::lines(t_use, map_b, lwd = 1.8, col = col_b)
  if (all(is.finite(mu_true))) graphics::lines(t_use, mu_true[idx_use], lwd = 1.1, lty = 3, col = "#2CA02C")

  graphics::legend(
    "topleft",
    legend = c("y", "true quantile", label_a, label_b,
               paste0(label_a, " 95% CrI"), paste0(label_b, " 95% CrI"), "true mean (mu_t)"),
    col = c("grey45", "#202020", col_a, col_b,
            grDevices::adjustcolor(col_a, alpha.f = 0.35),
            grDevices::adjustcolor(col_b, alpha.f = 0.35), "#2CA02C"),
    lty = c(1, 2, 1, 1, 1, 1, 3),
    lwd = c(1.0, 2.0, 1.8, 1.8, 8, 8, 1.1),
    bty = "n", cex = 0.9
  )
  grDevices::dev.off()
}

plot_trace_two <- function(file_path, x_a, y_a, x_b, y_b, label_a, label_b, col_a, col_b, title_txt, ylab_txt) {
  y_lim <- range(c(y_a, y_b), finite = TRUE)
  if (!all(is.finite(y_lim)) || diff(y_lim) <= 0) y_lim <- y_lim + c(-1e-6, 1e-6)

  grDevices::png(file_path, width = 1700, height = 900, res = 140)
  graphics::plot(x_a, y_a, type = "l", lwd = 1.7, col = col_a,
                 xlab = "iteration", ylab = ylab_txt,
                 main = title_txt, ylim = y_lim)
  graphics::lines(x_b, y_b, lwd = 1.7, col = col_b)
  graphics::legend("topright", legend = c(label_a, label_b),
                   col = c(col_a, col_b), lwd = 2, bty = "n")
  grDevices::dev.off()
}

plot_trace_single <- function(file_path, x, y, col, title_txt, ylab_txt) {
  y_lim <- range(y, finite = TRUE)
  if (!all(is.finite(y_lim)) || diff(y_lim) <= 0) y_lim <- y_lim + c(-1e-6, 1e-6)

  grDevices::png(file_path, width = 1700, height = 900, res = 140)
  graphics::plot(x, y, type = "l", lwd = 1.7, col = col,
                 xlab = "iteration", ylab = ylab_txt,
                 main = title_txt, ylim = y_lim)
  grDevices::dev.off()
}

log_msg("Post-processing from existing fits started")

fit_rows <- list()
for (inf in c("vb", "mcmc")) {
  for (mdl in c("exdqlm", "dqlm")) {
    for (tau in p_vec) {
      fit_rows[[length(fit_rows) + 1L]] <- parse_fit(inf, mdl, tau)
    }
  }
}
fit_summary <- do.call(rbind, fit_rows)
utils::write.csv(fit_summary, file.path(out_root, "tables", "fit_summary.csv"), row.names = FALSE)
log_msg("Wrote fit summary table")

vb_rows <- list()
mc_rows <- list()
ld_diag_rows <- list()
for (tau in p_vec) {
  for (mdl in c("exdqlm", "dqlm")) {
    vb_fit <- readRDS(get_fit_file("vb", mdl, tau))$fit
    dlt <- vb_fit$diagnostics$deltas
    vb_rows[[length(vb_rows) + 1L]] <- data.frame(
      model = mdl,
      tau = tau,
      iter = if (!is.null(vb_fit$iter)) as.integer(vb_fit$iter) else NA_integer_,
      converged = if (!is.null(vb_fit$converged)) isTRUE(vb_fit$converged) else NA,
      stop_reason = if (!is.null(vb_fit$diagnostics$convergence$stop_reason)) {
        as.character(vb_fit$diagnostics$convergence$stop_reason)[1]
      } else NA_character_,
      elbo_len = if (!is.null(vb_fit$diagnostics$elbo)) length(vb_fit$diagnostics$elbo) else NA_integer_,
      delta_state_last = if (!is.null(dlt$state)) utils::tail(as.numeric(dlt$state), 1) else NA_real_,
      delta_sigma_last = if (!is.null(dlt$sigma)) utils::tail(as.numeric(dlt$sigma), 1) else NA_real_,
      delta_gamma_last = if (!is.null(dlt$gamma)) utils::tail(as.numeric(dlt$gamma), 1) else NA_real_,
      delta_s_last = if (!is.null(dlt$s)) utils::tail(as.numeric(dlt$s), 1) else NA_real_,
      stringsAsFactors = FALSE
    )
    ld_block <- if (!is.null(vb_fit$diagnostics$ld_block)) vb_fit$diagnostics$ld_block else list()
    ld_signoff <- if (!is.null(ld_block$signoff_summary)) ld_block$signoff_summary else list()
    ld_trace <- if (!is.null(ld_block$trace)) ld_block$trace else data.frame()
    ld_final <- if (!is.null(ld_block$final)) ld_block$final else list()
    mode_quality <- if (!is.null(ld_block$mode_quality)) ld_block$mode_quality else list()
    ld_diag_rows[[length(ld_diag_rows) + 1L]] <- data.frame(
      model = mdl,
      tau = tau,
      ld_trace_rows = if (is.data.frame(ld_trace)) nrow(ld_trace) else NA_integer_,
      ld_hess_condition_last = if (!is.null(ld_final$ld_hess_condition)) as.numeric(ld_final$ld_hess_condition)[1] else NA_real_,
      ld_cov_condition_last = if (!is.null(ld_final$ld_cov_condition)) as.numeric(ld_final$ld_cov_condition)[1] else NA_real_,
      ld_cov_eig_min = if (!is.null(ld_final$ld_cov_eig_min)) as.numeric(ld_final$ld_cov_eig_min)[1] else NA_real_,
      ld_cov_eig_max = if (!is.null(ld_final$ld_cov_eig_max)) as.numeric(ld_final$ld_cov_eig_max)[1] else NA_real_,
      ld_mode_grad_inf_norm_final = if (!is.null(mode_quality$grad_inf_norm)) as.numeric(mode_quality$grad_inf_norm)[1] else NA_real_,
      ld_mode_neg_hess_min_eig_final = if (!is.null(mode_quality$neg_hess_min_eig)) as.numeric(mode_quality$neg_hess_min_eig)[1] else NA_real_,
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
      ld_mode_fallback_rate = if (!is.null(ld_signoff$fallback_rate)) as.numeric(ld_signoff$fallback_rate)[1] else NA_real_,
      ld_sigma_flip_rate_tail = if (!is.null(ld_signoff$sigma_flip_rate)) as.numeric(ld_signoff$sigma_flip_rate)[1] else NA_real_,
      ld_gamma_flip_rate_tail = if (!is.null(ld_signoff$gamma_flip_rate)) as.numeric(ld_signoff$gamma_flip_rate)[1] else NA_real_,
      stringsAsFactors = FALSE
    )

    mc_fit <- readRDS(get_fit_file("mcmc", mdl, tau))$fit
    mh_diag <- mc_fit$mh.diagnostics
    adapt_tbl <- get_mh_adapt_table(mh_diag)
    mh_trace <- if (!is.null(mh_diag$trace)) mh_diag$trace else data.frame()
    mc_rows[[length(mc_rows) + 1L]] <- data.frame(
      model = mdl,
      tau = tau,
      accept_rate = if (!is.null(mc_fit$accept.rate)) as.numeric(mc_fit$accept.rate) else NA_real_,
      accept_rate_burn = if (!is.null(mc_fit$accept.rate.burn)) as.numeric(mc_fit$accept.rate.burn) else NA_real_,
      accept_rate_keep = if (!is.null(mc_fit$accept.rate.keep)) as.numeric(mc_fit$accept.rate.keep) else NA_real_,
      ess_sigma = if (!is.null(mc_fit$diagnostics$ess$sigma)) as.numeric(mc_fit$diagnostics$ess$sigma)[1] else NA_real_,
      ess_gamma = if (!is.null(mc_fit$diagnostics$ess$gamma)) as.numeric(mc_fit$diagnostics$ess$gamma)[1] else NA_real_,
      mh_proposal = if (!is.null(mh_diag$proposal)) as.character(mh_diag$proposal)[1] else NA_character_,
      mh_joint_sample = if (!is.null(mh_diag$joint_sample)) isTRUE(mh_diag$joint_sample) else NA,
      mh_adapt = if (!is.null(mh_diag$adapt)) isTRUE(mh_diag$adapt) else NA,
      mh_scale_final = get_mh_scale_final(mh_diag),
      mh_adapt_steps = if (!is.null(adapt_tbl)) nrow(adapt_tbl) else NA_integer_,
      s_mean_avg = if (is.data.frame(mh_trace) && "s_mean" %in% names(mh_trace)) mean(mh_trace$s_mean, na.rm = TRUE) else NA_real_,
      s_sd_avg = if (is.data.frame(mh_trace) && "s_sd" %in% names(mh_trace)) mean(mh_trace$s_sd, na.rm = TRUE) else NA_real_,
      stringsAsFactors = FALSE
    )
  }
}

vb_conv <- do.call(rbind, vb_rows)
mc_diag <- do.call(rbind, mc_rows)
ld_diag <- do.call(rbind, ld_diag_rows)
utils::write.csv(vb_conv, file.path(out_root, "tables", "vb_convergence_summary.csv"), row.names = FALSE)
utils::write.csv(mc_diag, file.path(out_root, "tables", "mcmc_diagnostics_summary.csv"), row.names = FALSE)
utils::write.csv(ld_diag, file.path(out_root, "tables", "vb_ld_diagnostics_summary.csv"), row.names = FALSE)
log_msg("Wrote VB, MCMC, and LD diagnostics tables")

metrics_rows <- list()
for (inf in c("vb", "mcmc")) {
  for (mdl in c("exdqlm", "dqlm")) {
    for (tau in p_vec) {
      tlabel <- tau_lab(tau)
      fit_obj <- readRDS(get_fit_file(inf, mdl, tau))$fit
      summ <- derive_map_ci(fit_obj)
      tq_idx <- which.min(abs(sim$p - tau))
      true_q <- as.numeric(sim$q[seq_len(TT), tq_idx])

      rmse <- sqrt(mean((summ$map - true_q)^2))
      coverage <- mean(true_q >= summ$lb & true_q <= summ$ub)
      mean_ci_width <- mean(summ$ub - summ$lb)

      saveRDS(
        list(
          inference = inf,
          model = mdl,
          tau = tau,
          summary = summ,
          true_q = true_q,
          metrics = list(rmse = rmse, coverage = coverage, mean_ci_width = mean_ci_width)
        ),
        file.path(out_root, "derived", sprintf("%s_%s_tau_%s_summary.rds", inf, mdl, tlabel)),
        compress = "xz"
      )

      metrics_rows[[length(metrics_rows) + 1L]] <- data.frame(
        inference = inf,
        model = mdl,
        tau = tau,
        rmse = rmse,
        coverage = coverage,
        mean_ci_width = mean_ci_width,
        n_draws = summ$n_draws,
        stringsAsFactors = FALSE
      )
    }
  }
}

metrics_df <- do.call(rbind, metrics_rows)
utils::write.csv(metrics_df, file.path(out_root, "tables", "metrics_summary.csv"), row.names = FALSE)
log_msg("Wrote derived summaries and metrics table")

method_signoff <- read_csv_maybe_empty(file.path(out_tables, "method_signoff_long.csv"))
algorithm_pair_signoff <- read_csv_maybe_empty(file.path(out_tables, "algorithm_pair_signoff.csv"))
model_pair_signoff <- read_csv_maybe_empty(file.path(out_tables, "model_pair_signoff.csv"))
root_signoff_summary <- read_csv_maybe_empty(file.path(out_tables, "root_signoff_summary.csv"))

if (nrow(method_signoff) > 0) {
  method_signoff$inference <- tolower(as.character(method_signoff$inference))
  method_signoff$model <- tolower(as.character(method_signoff$model))
  method_signoff$tau <- suppressWarnings(as.numeric(method_signoff$tau))
}
if (nrow(algorithm_pair_signoff) > 0) {
  algorithm_pair_signoff$model <- tolower(as.character(algorithm_pair_signoff$model))
  algorithm_pair_signoff$tau <- suppressWarnings(as.numeric(algorithm_pair_signoff$tau))
}
if (nrow(model_pair_signoff) > 0) {
  model_pair_signoff$inference <- tolower(as.character(model_pair_signoff$inference))
  model_pair_signoff$tau <- suppressWarnings(as.numeric(model_pair_signoff$tau))
}

if (nrow(metrics_df) > 0 && nrow(method_signoff) > 0) {
  signoff_cols <- method_signoff[, c(
    "inference", "model", "tau", "signoff_grade", "comparison_eligible",
    "convergence_certified", "execution_healthy", "signoff_reason"
  ), drop = FALSE]
  metrics_df <- merge(
    metrics_df,
    signoff_cols,
    by = c("inference", "model", "tau"),
    all.x = TRUE,
    sort = FALSE
  )
}
metrics_df <- ensure_col(metrics_df, "signoff_grade", NA_character_)
metrics_df <- ensure_col(metrics_df, "comparison_eligible", NA)
metrics_df <- ensure_col(metrics_df, "convergence_certified", NA)
metrics_df <- ensure_col(metrics_df, "execution_healthy", NA)
metrics_df <- ensure_col(metrics_df, "signoff_reason", NA_character_)
eligible_metrics_df <- if (nrow(metrics_df)) metrics_df[as.logical(metrics_df$comparison_eligible %in% TRUE), , drop = FALSE] else metrics_df
utils::write.csv(metrics_df, file.path(out_tables, "fit_metrics_by_task.csv"), row.names = FALSE)
utils::write.csv(eligible_metrics_df, file.path(out_tables, "fit_metrics_by_task_eligible.csv"), row.names = FALSE)

pair_df <- merge(
  metrics_df[metrics_df$model == "dqlm", c("inference", "tau", "rmse", "coverage", "mean_ci_width", "n_draws", "signoff_grade", "comparison_eligible", "signoff_reason"), drop = FALSE],
  metrics_df[metrics_df$model == "exdqlm", c("inference", "tau", "rmse", "coverage", "mean_ci_width", "n_draws", "signoff_grade", "comparison_eligible", "signoff_reason"), drop = FALSE],
  by = c("inference", "tau"),
  suffixes = c("_baseline", "_extended"),
  all = TRUE,
  sort = FALSE
)
if (nrow(pair_df) > 0) {
  pair_df$rmse_delta_extended_minus_baseline <- pair_df$rmse_extended - pair_df$rmse_baseline
  pair_df$coverage_delta_extended_minus_baseline <- pair_df$coverage_extended - pair_df$coverage_baseline
  pair_df$mean_ci_width_delta_extended_minus_baseline <- pair_df$mean_ci_width_extended - pair_df$mean_ci_width_baseline
}
pair_df <- ensure_col(pair_df, "pair_signoff_grade", NA_character_)
pair_df <- ensure_col(pair_df, "pair_comparison_eligible", NA)
if (nrow(pair_df) > 0 && nrow(model_pair_signoff) > 0) {
  pair_map <- model_pair_signoff[, c(
    "inference", "tau", "pair_signoff_grade", "pair_comparison_eligible",
    "baseline_signoff_grade", "extended_signoff_grade"
  ), drop = FALSE]
  pair_df <- merge(pair_df, pair_map, by = c("inference", "tau"), all.x = TRUE, sort = FALSE, suffixes = c("", ".signoff"))
  for (nm in c("pair_signoff_grade", "pair_comparison_eligible")) {
    nm_new <- paste0(nm, ".signoff")
    if (nm_new %in% names(pair_df)) {
      pair_df[[nm]] <- ifelse(is.na(pair_df[[nm]]), pair_df[[nm_new]], pair_df[[nm]])
      pair_df[[nm_new]] <- NULL
    }
  }
}
pair_df_eligible <- if (nrow(pair_df)) pair_df[as.logical(pair_df$pair_comparison_eligible %in% TRUE), , drop = FALSE] else pair_df
pair_df_excluded <- if (nrow(pair_df)) pair_df[!as.logical(pair_df$pair_comparison_eligible %in% TRUE), , drop = FALSE] else pair_df
utils::write.csv(pair_df_eligible, file.path(out_tables, "pairwise_exdqlm_vs_dqlm.csv"), row.names = FALSE)
utils::write.csv(pair_df_excluded, file.path(out_tables, "pairwise_exdqlm_vs_dqlm_excluded.csv"), row.names = FALSE)

gate_df <- merge(
  metrics_df[metrics_df$inference == "vb", c("model", "tau", "rmse", "coverage", "mean_ci_width", "n_draws", "signoff_grade", "comparison_eligible", "signoff_reason"), drop = FALSE],
  metrics_df[metrics_df$inference == "mcmc", c("model", "tau", "rmse", "coverage", "mean_ci_width", "n_draws", "signoff_grade", "comparison_eligible", "signoff_reason"), drop = FALSE],
  by = c("model", "tau"),
  suffixes = c("_vb", "_mcmc"),
  all = TRUE,
  sort = FALSE
)
if (nrow(gate_df) > 0) {
  gate_df$rmse_ratio_vb_over_mcmc <- gate_df$rmse_vb / gate_df$rmse_mcmc
  gate_df$coverage_delta_vb_minus_mcmc <- gate_df$coverage_vb - gate_df$coverage_mcmc
  gate_df$mean_ci_width_delta_vb_minus_mcmc <- gate_df$mean_ci_width_vb - gate_df$mean_ci_width_mcmc
}
gate_df <- ensure_col(gate_df, "algorithm_pair_signoff_grade", NA_character_)
gate_df <- ensure_col(gate_df, "algorithm_pair_comparison_eligible", NA)
if (nrow(gate_df) > 0 && nrow(algorithm_pair_signoff) > 0) {
  alg_cols <- algorithm_pair_signoff[, c("model", "tau", "pair_signoff_grade", "pair_comparison_eligible"), drop = FALSE]
  names(alg_cols) <- c("model", "tau", "algorithm_pair_signoff_grade", "algorithm_pair_comparison_eligible")
  gate_df <- merge(gate_df, alg_cols, by = c("model", "tau"), all.x = TRUE, sort = FALSE)
}
utils::write.csv(gate_df, file.path(out_tables, "acceptance_gate_summary.csv"), row.names = FALSE)

last_n <- min(200L, TT)
idx_full <- seq_len(TT)
idx_tail <- seq.int(TT - last_n + 1L, TT)

for (tau in p_vec) {
  tlabel <- tau_lab(tau)
  for (inf in c("vb", "mcmc")) {
    obj_ex <- load_derived(inf, "exdqlm", tau)
    obj_dq <- load_derived(inf, "dqlm", tau)
    plot_fit_compare(
      file.path(out_root, "plots", "fit_within_inference",
                sprintf("%s_tau_%s_dqlm_vs_exdqlm_full.png", inf, tlabel)),
      idx_full, obj_ex, obj_dq,
      label_a = paste0(toupper(inf), " exDQLM"),
      label_b = paste0(toupper(inf), " DQLM"),
      col_a = "#C73E1D", col_b = "#1F78B4",
      title_txt = sprintf("%s fit compare (tau=%.2f): exDQLM vs DQLM [full]", toupper(inf), tau)
    )
    plot_fit_compare(
      file.path(out_root, "plots", "fit_within_inference",
                sprintf("%s_tau_%s_dqlm_vs_exdqlm_last200.png", inf, tlabel)),
      idx_tail, obj_ex, obj_dq,
      label_a = paste0(toupper(inf), " exDQLM"),
      label_b = paste0(toupper(inf), " DQLM"),
      col_a = "#C73E1D", col_b = "#1F78B4",
      title_txt = sprintf("%s fit compare (tau=%.2f): exDQLM vs DQLM [last %d]", toupper(inf), tau, last_n)
    )
  }

  for (mdl in c("exdqlm", "dqlm")) {
    obj_vb <- load_derived("vb", mdl, tau)
    obj_mc <- load_derived("mcmc", mdl, tau)
    plot_fit_compare(
      file.path(out_root, "plots", "fit_between_inference",
                sprintf("%s_tau_%s_vb_vs_mcmc_full.png", mdl, tlabel)),
      idx_full, obj_vb, obj_mc,
      label_a = paste("VB", toupper(mdl)),
      label_b = paste("MCMC", toupper(mdl)),
      col_a = "#8E44AD", col_b = "#16A085",
      title_txt = sprintf("%s fit compare (tau=%.2f): VB vs MCMC [full]", toupper(mdl), tau)
    )
    plot_fit_compare(
      file.path(out_root, "plots", "fit_between_inference",
                sprintf("%s_tau_%s_vb_vs_mcmc_last200.png", mdl, tlabel)),
      idx_tail, obj_vb, obj_mc,
      label_a = paste("VB", toupper(mdl)),
      label_b = paste("MCMC", toupper(mdl)),
      col_a = "#8E44AD", col_b = "#16A085",
      title_txt = sprintf("%s fit compare (tau=%.2f): VB vs MCMC [last %d]", toupper(mdl), tau, last_n)
    )
  }
}

for (tau in p_vec) {
  tlabel <- tau_lab(tau)
  vb_ex <- readRDS(get_fit_file("vb", "exdqlm", tau))$fit
  vb_dq <- readRDS(get_fit_file("vb", "dqlm", tau))$fit
  elbo_ex <- as.numeric(vb_ex$diagnostics$elbo)
  elbo_dq <- as.numeric(vb_dq$diagnostics$elbo)

  out_file <- file.path(out_root, "plots", "traces", sprintf("vb_tau_%s_elbo_trace.png", tlabel))
  grDevices::png(out_file, width = 1900, height = 900, res = 140)
  old_par <- graphics::par(no.readonly = TRUE)
  graphics::par(mfrow = c(1, 2), mar = c(4.2, 4.2, 3.0, 1.2))

  y_lim <- range(c(elbo_ex, elbo_dq), finite = TRUE)
  graphics::plot(seq_along(elbo_ex), elbo_ex, type = "l", lwd = 1.8, col = "#C73E1D",
                 xlab = "iteration", ylab = "ELBO",
                 main = sprintf("VB raw ELBO (tau=%.2f)", tau), ylim = y_lim)
  graphics::lines(seq_along(elbo_dq), elbo_dq, lwd = 1.8, col = "#1F78B4")
  graphics::legend("bottomright", legend = c("exDQLM", "DQLM"),
                   col = c("#C73E1D", "#1F78B4"), lwd = 2, bty = "n")

  d_ex <- elbo_ex - elbo_ex[1]
  d_dq <- elbo_dq - elbo_dq[1]
  yd <- range(c(d_ex, d_dq), finite = TRUE)
  graphics::plot(seq_along(d_ex), d_ex, type = "l", lwd = 1.8, col = "#C73E1D",
                 xlab = "iteration", ylab = "ELBO - ELBO[1]",
                 main = "VB centered ELBO change", ylim = yd)
  graphics::lines(seq_along(d_dq), d_dq, lwd = 1.8, col = "#1F78B4")
  graphics::legend("bottomright", legend = c("exDQLM", "DQLM"),
                   col = c("#C73E1D", "#1F78B4"), lwd = 2, bty = "n")

  graphics::par(old_par)
  grDevices::dev.off()

  plot_trace_two(
    file_path = file.path(out_root, "plots", "traces", sprintf("vb_tau_%s_sigma_trace.png", tlabel)),
    x_a = seq_along(vb_ex$seq.sigma) - 1L,
    y_a = as.numeric(vb_ex$seq.sigma),
    x_b = seq_along(vb_dq$seq.sigma) - 1L,
    y_b = as.numeric(vb_dq$seq.sigma),
    label_a = "VB exDQLM", label_b = "VB DQLM",
    col_a = "#C73E1D", col_b = "#1F78B4",
    title_txt = sprintf("VB sigma trace (tau=%.2f)", tau),
    ylab_txt = "E[sigma]"
  )

  if (!is.null(vb_ex$seq.gamma)) {
    plot_trace_single(
      file_path = file.path(out_root, "plots", "traces", sprintf("vb_tau_%s_gamma_trace_exdqlm.png", tlabel)),
      x = seq_along(vb_ex$seq.gamma) - 1L,
      y = as.numeric(vb_ex$seq.gamma),
      col = "#C73E1D",
      title_txt = sprintf("VB gamma trace exDQLM (tau=%.2f)", tau),
      ylab_txt = "E[gamma]"
    )
  }
  vb_s_trace <- if (!is.null(vb_ex$diagnostics$s_block$trace)) vb_ex$diagnostics$s_block$trace else data.frame()
  if (is.data.frame(vb_s_trace) && nrow(vb_s_trace) > 1L && "s_mean" %in% names(vb_s_trace)) {
    plot_trace_single(
      file_path = file.path(out_root, "plots", "traces", sprintf("vb_tau_%s_s_mean_trace_exdqlm.png", tlabel)),
      x = vb_s_trace$iter,
      y = vb_s_trace$s_mean,
      col = "#D35400",
      title_txt = sprintf("VB s_t mean trace exDQLM (tau=%.2f)", tau),
      ylab_txt = "mean E[s_t]"
    )
    if ("tau2_mean" %in% names(vb_s_trace)) {
      plot_trace_single(
        file_path = file.path(out_root, "plots", "traces", sprintf("vb_tau_%s_s_tau2_trace_exdqlm.png", tlabel)),
        x = vb_s_trace$iter,
        y = vb_s_trace$tau2_mean,
        col = "#884EA0",
        title_txt = sprintf("VB s_t variance proxy exDQLM (tau=%.2f)", tau),
        ylab_txt = "mean tau2(s_t)"
      )
    }
  }

  mc_ex <- readRDS(get_fit_file("mcmc", "exdqlm", tau))$fit
  mc_dq <- readRDS(get_fit_file("mcmc", "dqlm", tau))$fit
  plot_trace_two(
    file_path = file.path(out_root, "plots", "traces", sprintf("mcmc_tau_%s_sigma_trace.png", tlabel)),
    x_a = seq_along(mc_ex$samp.sigma),
    y_a = as.numeric(mc_ex$samp.sigma),
    x_b = seq_along(mc_dq$samp.sigma),
    y_b = as.numeric(mc_dq$samp.sigma),
    label_a = "MCMC exDQLM", label_b = "MCMC DQLM",
    col_a = "#C73E1D", col_b = "#1F78B4",
    title_txt = sprintf("MCMC sigma trace (tau=%.2f)", tau),
    ylab_txt = "sigma sample"
  )

  if (!is.null(mc_ex$samp.gamma)) {
    plot_trace_single(
      file_path = file.path(out_root, "plots", "traces", sprintf("mcmc_tau_%s_gamma_trace_exdqlm.png", tlabel)),
      x = seq_along(mc_ex$samp.gamma),
      y = as.numeric(mc_ex$samp.gamma),
      col = "#C73E1D",
      title_txt = sprintf("MCMC gamma trace exDQLM (tau=%.2f)", tau),
      ylab_txt = "gamma sample"
    )
  }
  mc_s_trace <- if (!is.null(mc_ex$mh.diagnostics$trace)) mc_ex$mh.diagnostics$trace else data.frame()
  if (is.data.frame(mc_s_trace) && nrow(mc_s_trace) > 1L && "s_mean" %in% names(mc_s_trace)) {
    plot_trace_single(
      file_path = file.path(out_root, "plots", "traces", sprintf("mcmc_tau_%s_s_mean_trace_exdqlm.png", tlabel)),
      x = mc_s_trace$iter,
      y = mc_s_trace$s_mean,
      col = "#D35400",
      title_txt = sprintf("MCMC s_t mean trace exDQLM (tau=%.2f)", tau),
      ylab_txt = "mean sampled s_t"
    )
  }
}

summary_md <- file.path(out_tables, "report_summary.md")
writeLines(c(
  "# Dynamic VB/MCMC Review Summary",
  "",
  sprintf("- generated_at: `%s`", format(Sys.time(), "%Y-%m-%d %H:%M:%S")),
  sprintf("- out_root: `%s`", out_root),
  sprintf("- method_signoff_pass_count: %d", if (nrow(method_signoff)) sum(method_signoff$signoff_grade == "PASS", na.rm = TRUE) else 0L),
  sprintf("- method_signoff_warn_count: %d", if (nrow(method_signoff)) sum(method_signoff$signoff_grade == "WARN", na.rm = TRUE) else 0L),
  sprintf("- method_signoff_fail_count: %d", if (nrow(method_signoff)) sum(method_signoff$signoff_grade == "FAIL", na.rm = TRUE) else 0L),
  sprintf("- method_comparison_eligible_count: %d", if (nrow(method_signoff)) sum(as.logical(method_signoff$comparison_eligible), na.rm = TRUE) else 0L),
  sprintf("- algorithm_pair_eligible_count: %d", if (nrow(algorithm_pair_signoff)) sum(as.logical(algorithm_pair_signoff$pair_comparison_eligible), na.rm = TRUE) else 0L),
  sprintf("- model_pair_eligible_count: %d", if (nrow(model_pair_signoff)) sum(as.logical(model_pair_signoff$pair_comparison_eligible), na.rm = TRUE) else 0L),
  sprintf("- root_full_eligible_count: %d", if (nrow(root_signoff_summary)) sum(as.logical(root_signoff_summary$root_comparison_eligible_full), na.rm = TRUE) else 0L),
  sprintf("- root_any_eligible_count: %d", if (nrow(root_signoff_summary)) sum(as.logical(root_signoff_summary$root_comparison_eligible_any), na.rm = TRUE) else 0L),
  sprintf("- fit_metric_rows_all: %d", nrow(metrics_df)),
  sprintf("- fit_metric_rows_eligible: %d", nrow(eligible_metrics_df)),
  sprintf("- eligible_pairwise_rows: %d", nrow(pair_df_eligible)),
  sprintf("- excluded_pairwise_rows: %d", nrow(pair_df_excluded)),
  "",
  "## Core tables",
  "- `tables/fit_summary.csv`",
  "- `tables/metrics_summary.csv`",
  "- `tables/fit_metrics_by_task.csv`",
  "- `tables/fit_metrics_by_task_eligible.csv`",
  "- `tables/pairwise_exdqlm_vs_dqlm.csv`",
  "- `tables/pairwise_exdqlm_vs_dqlm_excluded.csv`",
  "- `tables/acceptance_gate_summary.csv`"
), con = summary_md)

log_msg("Post-processing from existing fits completed")

#!/usr/bin/env Rscript

suppressPackageStartupMessages({
})

Sys.setenv(
  OMP_NUM_THREADS = "1",
  OPENBLAS_NUM_THREADS = "1",
  MKL_NUM_THREADS = "1",
  VECLIB_MAXIMUM_THREADS = "1",
  NUMEXPR_NUM_THREADS = "1"
)

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

infer_root_beta_prior <- function(run_root) {
  rr <- normalizePath(run_root, winslash = "/", mustWork = FALSE)
  if (grepl("validation_shrink_rhs", rr, fixed = TRUE)) return("rhs")
  if (grepl("validation_shrink_ridge", rr, fixed = TRUE)) return("ridge")
  "ridge"
}

build_runtime_diag <- function(run_root, out_tables, summary_df) {
  fit_summary <- read_csv_maybe_empty(file.path(out_tables, "fit_summary.csv"))
  vb_conv <- read_csv_maybe_empty(file.path(out_tables, "vb_convergence_summary.csv"))
  mc_diag <- read_csv_maybe_empty(file.path(out_tables, "mcmc_diagnostics_summary.csv"))

  if (!nrow(fit_summary)) {
    stop("Missing or empty fit_summary.csv under run root: ", run_root)
  }

  root_prior <- infer_root_beta_prior(run_root)

  fit_summary$model <- as.character(fit_summary$model)
  fit_summary$tau <- suppressWarnings(as.numeric(fit_summary$tau))
  fit_summary$inference <- tolower(as.character(fit_summary$inference))

  vb_fit <- fit_summary[fit_summary$inference == "vb", c("model", "tau", "runtime_sec", "fit_file"), drop = FALSE]
  names(vb_fit) <- c("model", "tau", "vb_runtime_sec", "vb_file")

  mc_fit <- fit_summary[fit_summary$inference == "mcmc", c("model", "tau", "runtime_sec", "fit_file"), drop = FALSE]
  names(mc_fit) <- c("model", "tau", "mcmc_runtime_sec", "mcmc_file")

  key_df <- unique(rbind(
    vb_fit[, c("model", "tau"), drop = FALSE],
    mc_fit[, c("model", "tau"), drop = FALSE]
  ))
  key_df$model <- as.character(key_df$model)
  key_df$tau <- suppressWarnings(as.numeric(key_df$tau))

  runtime_diag <- merge(key_df, vb_fit, by = c("model", "tau"), all.x = TRUE, sort = FALSE)
  runtime_diag <- merge(runtime_diag, mc_fit, by = c("model", "tau"), all.x = TRUE, sort = FALSE)

  if (nrow(vb_conv) > 0) {
    vb_conv$model <- as.character(vb_conv$model)
    vb_conv$tau <- suppressWarnings(as.numeric(vb_conv$tau))
    vb_conv <- vb_conv[, c("model", "tau", "converged", "stop_reason"), drop = FALSE]
    names(vb_conv) <- c("model", "tau", "vb_converged", "vb_stop_reason")
    runtime_diag <- merge(runtime_diag, vb_conv, by = c("model", "tau"), all.x = TRUE, sort = FALSE)
  } else {
    runtime_diag$vb_converged <- NA
    runtime_diag$vb_stop_reason <- NA_character_
  }

  if (nrow(mc_diag) > 0) {
    mc_diag$model <- as.character(mc_diag$model)
    mc_diag$tau <- suppressWarnings(as.numeric(mc_diag$tau))
    mc_diag <- mc_diag[, c(
      "model", "tau", "accept_rate", "ess_sigma", "ess_gamma",
      "mh_kernel_exact", "mh_signoff_ready"
    ), drop = FALSE]
    names(mc_diag) <- c(
      "model", "tau", "accept_rate", "ess_sigma", "ess_gamma",
      "mcmc_gamma_kernel_exact", "mcmc_signoff_ready"
    )
    runtime_diag <- merge(runtime_diag, mc_diag, by = c("model", "tau"), all.x = TRUE, sort = FALSE)
  } else {
    runtime_diag$accept_rate <- NA_real_
    runtime_diag$ess_sigma <- NA_real_
    runtime_diag$ess_gamma <- NA_real_
    runtime_diag$mcmc_gamma_kernel_exact <- NA
    runtime_diag$mcmc_signoff_ready <- NA
  }

  if (nrow(summary_df) > 0) {
    summary_sel <- unique(summary_df[, c("model", "tau", "status"), drop = FALSE])
    summary_sel$model <- as.character(summary_sel$model)
    summary_sel$tau <- suppressWarnings(as.numeric(summary_sel$tau))
    summary_sel$status <- as.character(summary_sel$status)
    runtime_diag <- merge(runtime_diag, summary_sel, by = c("model", "tau"), all.x = TRUE, sort = FALSE)
  } else {
    runtime_diag$status <- NA_character_
  }

  runtime_diag$beta_prior <- root_prior
  runtime_diag$vb_runtime_sec <- suppressWarnings(as.numeric(runtime_diag$vb_runtime_sec))
  runtime_diag$mcmc_runtime_sec <- suppressWarnings(as.numeric(runtime_diag$mcmc_runtime_sec))
  runtime_diag$accept_rate <- suppressWarnings(as.numeric(runtime_diag$accept_rate))
  runtime_diag$ess_sigma <- suppressWarnings(as.numeric(runtime_diag$ess_sigma))
  runtime_diag$ess_gamma <- suppressWarnings(as.numeric(runtime_diag$ess_gamma))
  runtime_diag$runtime_sec <- runtime_diag$mcmc_runtime_sec

  for (i in seq_len(nrow(runtime_diag))) {
    vb_file <- resolve_file_path(runtime_diag$vb_file[i], run_root)
    mc_file <- resolve_file_path(runtime_diag$mcmc_file[i], run_root)
    if (is.na(vb_file)) {
      vb_guess <- infer_vb_file(run_root, runtime_diag$model[i], runtime_diag$tau[i])
      if (file.exists(vb_guess)) vb_file <- vb_guess
    }
    if (is.na(mc_file)) {
      mc_guess <- infer_mcmc_file(run_root, runtime_diag$model[i], runtime_diag$tau[i])
      if (file.exists(mc_guess)) mc_file <- mc_guess
    }
    runtime_diag$vb_file[i] <- vb_file
    runtime_diag$mcmc_file[i] <- mc_file
  }

  complete_idx <- !is.na(runtime_diag$vb_file) & file.exists(runtime_diag$vb_file) &
    !is.na(runtime_diag$mcmc_file) & file.exists(runtime_diag$mcmc_file)
  runtime_diag$status[complete_idx] <- "done"
  runtime_diag$status[is.na(runtime_diag$status) | !nzchar(runtime_diag$status)] <- "unknown"

  runtime_diag[order(runtime_diag$model, runtime_diag$tau), , drop = FALSE]
}

plot_coef_tree <- function(file_path, beta_draws, main, lambda_summary = NULL) {
  beta_draws <- as.matrix(beta_draws)
  if (!nrow(beta_draws) || !ncol(beta_draws)) return(invisible(NULL))
  cn <- colnames(beta_draws)
  if (is.null(cn)) cn <- paste0("beta", seq_len(ncol(beta_draws)))
  post_mean <- colMeans(beta_draws, na.rm = TRUE)
  qs <- t(apply(beta_draws, 2, stats::quantile, probs = c(0.05, 0.5, 0.95), na.rm = TRUE))
  if (!any(is.finite(qs))) return(invisible(NULL))
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
  if (!all(is.finite(xlim))) return(invisible(NULL))
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

runtime_diag <- build_runtime_diag(run_root, out_tables, summary_df)
utils::write.csv(runtime_diag, file.path(out_tables, "runtime_diagnostics_summary.csv"), row.names = FALSE)

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

for (i in seq_len(nrow(runtime_diag))) {
  row <- runtime_diag[i, , drop = FALSE]
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
  runtime_diag$vb_file[i] <- vb_file
  runtime_diag$mcmc_file[i] <- mcmc_file

  vb_obj <- readRDS(vb_file)
  m_obj <- readRDS(mcmc_file)
  vb_fit <- vb_obj$fit
  m_fit <- m_obj$fit
  vb_norm <- .static_normalize_vb_fit(vb_fit)
  m_norm <- .static_normalize_mcmc_fit(m_fit)
  if (is.na(runtime_diag$vb_converged[i])) runtime_diag$vb_converged[i] <- isTRUE(vb_norm$converged)
  if (is.na(runtime_diag$vb_stop_reason[i]) || !nzchar(runtime_diag$vb_stop_reason[i])) {
    runtime_diag$vb_stop_reason[i] <- vb_norm$stop_reason
  }
  if (is.na(runtime_diag$ess_sigma[i])) runtime_diag$ess_sigma[i] <- as.numeric(m_norm$diagnostics$ess$sigma)[1]
  if (is.na(runtime_diag$ess_gamma[i])) runtime_diag$ess_gamma[i] <- as.numeric(m_norm$diagnostics$ess$gamma)[1]
  if (is.na(runtime_diag$accept_rate[i])) runtime_diag$accept_rate[i] <- as.numeric(m_norm$diagnostics$acceptance$total)[1]
  runtime_diag$mcmc_gamma_kernel_exact[i] <- isTRUE(m_norm$diagnostics$mh$kernel_exact)
  runtime_diag$mcmc_signoff_ready[i] <- isTRUE(m_norm$diagnostics$mh$signoff_ready)

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
if (nrow(metrics_df) > 0 && nrow(method_signoff) > 0) {
  signoff_cols <- method_signoff[, c(
    "inference", "model", "tau", "signoff_grade", "comparison_eligible",
    "convergence_certified", "execution_healthy", "signoff_reason"
  ), drop = FALSE]
  metrics_df <- merge(
    metrics_df,
    signoff_cols,
    by.x = c("method", "model", "tau"),
    by.y = c("inference", "model", "tau"),
    all.x = TRUE,
    sort = FALSE
  )
}
metrics_df <- ensure_col(metrics_df, "signoff_grade", NA_character_)
metrics_df <- ensure_col(metrics_df, "comparison_eligible", NA)
metrics_df <- ensure_col(metrics_df, "convergence_certified", NA)
metrics_df <- ensure_col(metrics_df, "execution_healthy", NA)
metrics_df <- ensure_col(metrics_df, "signoff_reason", NA_character_)
utils::write.csv(metrics_df, file.path(out_tables, "fit_metrics_by_task.csv"), row.names = FALSE)
eligible_metrics_df <- if (nrow(metrics_df)) metrics_df[as.logical(metrics_df$comparison_eligible %in% TRUE), , drop = FALSE] else metrics_df
utils::write.csv(eligible_metrics_df, file.path(out_tables, "fit_metrics_by_task_eligible.csv"), row.names = FALSE)

# Runtime + diagnostic summary from canonical postprocess tables
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
pair_df <- if (length(pair_rows)) {
  do.call(rbind, pair_rows)
} else {
  data.frame(
    tau = numeric(0),
    method = character(0),
    rmse_exal = numeric(0),
    rmse_al = numeric(0),
    mae_exal = numeric(0),
    mae_al = numeric(0),
    rmse_delta_exal_minus_al = numeric(0),
    mae_delta_exal_minus_al = numeric(0),
    stringsAsFactors = FALSE
  )
}
pair_df <- ensure_col(pair_df, "pair_signoff_grade", NA_character_)
pair_df <- ensure_col(pair_df, "pair_comparison_eligible", NA)
pair_df <- ensure_col(pair_df, "baseline_signoff_grade", NA_character_)
pair_df <- ensure_col(pair_df, "extended_signoff_grade", NA_character_)
if (nrow(pair_df) > 0 && nrow(model_pair_signoff) > 0) {
  pair_map <- model_pair_signoff[, c(
    "inference", "tau", "pair_signoff_grade", "pair_comparison_eligible",
    "baseline_signoff_grade", "extended_signoff_grade"
  ), drop = FALSE]
  names(pair_map)[names(pair_map) == "inference"] <- "method"
  pair_df <- merge(pair_df, pair_map, by = c("method", "tau"), all.x = TRUE, sort = FALSE, suffixes = c("", ".signoff"))
  for (nm in c("pair_signoff_grade", "pair_comparison_eligible", "baseline_signoff_grade", "extended_signoff_grade")) {
    nm_new <- paste0(nm, ".signoff")
    if (nm_new %in% names(pair_df)) {
      idx <- is.na(pair_df[[nm]]) | !nzchar(as.character(pair_df[[nm]]))
      pair_df[[nm]][idx] <- pair_df[[nm_new]][idx]
      pair_df[[nm_new]] <- NULL
    }
  }
}
pair_df_eligible <- if (nrow(pair_df)) pair_df[as.logical(pair_df$pair_comparison_eligible %in% TRUE), , drop = FALSE] else pair_df
pair_df_excluded <- if (nrow(pair_df)) pair_df[!as.logical(pair_df$pair_comparison_eligible %in% TRUE), , drop = FALSE] else pair_df
utils::write.csv(pair_df_eligible, file.path(out_tables, "pairwise_exal_vs_al.csv"), row.names = FALSE)
utils::write.csv(pair_df_excluded, file.path(out_tables, "pairwise_exal_vs_al_excluded.csv"), row.names = FALSE)

# Acceptance gates
ess_sigma_min <- safe_num(Sys.getenv("EXDQLM_STATIC_GATE_ESS_SIGMA_MIN", "30"), 30)
ess_gamma_min <- safe_num(Sys.getenv("EXDQLM_STATIC_GATE_ESS_GAMMA_MIN", "20"), 20)
ld_xi_median_abs_max <- safe_num(Sys.getenv("EXDQLM_STATIC_GATE_LD_XI_MEDIAN_ABS_MAX", "0.10"), 0.10)
ld_flip_rate_max <- safe_num(Sys.getenv("EXDQLM_STATIC_GATE_LD_FLIP_RATE_MAX", "0.55"), 0.55)
ld_fallback_max <- safe_num(Sys.getenv("EXDQLM_STATIC_GATE_LD_FALLBACK_MAX", "0.10"), 0.10)

vb_rows <- runtime_diag[, c(
  "model", "tau", "beta_prior", "vb_converged", "vb_stop_reason",
  "ess_sigma", "ess_gamma", "status", "mcmc_gamma_kernel_exact", "mcmc_signoff_ready"
), drop = FALSE]
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
  vb_rows$ld_candidate_local_pass_rate_tail <- NA_real_
  vb_rows$ld_committed_local_pass_rate_tail <- NA_real_
  vb_rows$ld_committed_stable_tail <- NA
  vb_rows$ld_objective_gap_median_tail <- NA_real_
  vb_rows$ld_stabilized_rate_tail <- NA_real_
  vb_rows$ld_optim_fallback_rate <- NA_real_
  vb_rows$ld_numeric_hessian_rate <- NA_real_
  vb_rows$ld_identity_hessian_rate <- NA_real_
  vb_rows$ld_cov_floor_rate <- NA_real_
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
  ifelse(
    !is.na(vb_rows$ld_stabilized_rate_tail[rhs_exal]) & vb_rows$ld_stabilized_rate_tail[rhs_exal] > 0,
    !is.na(vb_rows$ld_committed_stable_tail[rhs_exal]) &
      as.logical(vb_rows$ld_committed_stable_tail[rhs_exal]) &
      (is.na(vb_rows$ld_optim_fallback_rate[rhs_exal]) | vb_rows$ld_optim_fallback_rate[rhs_exal] <= ld_fallback_max) &
      (is.na(vb_rows$ld_identity_hessian_rate[rhs_exal]) | vb_rows$ld_identity_hessian_rate[rhs_exal] <= ld_fallback_max) &
      (is.na(vb_rows$ld_cov_floor_rate[rhs_exal]) | vb_rows$ld_cov_floor_rate[rhs_exal] <= ld_fallback_max),
    !is.na(vb_rows$ld_xi_median_abs_tail[rhs_exal]) &
      vb_rows$ld_xi_median_abs_tail[rhs_exal] <= ld_xi_median_abs_max &
      (is.na(vb_rows$ld_mode_fallback_rate[rhs_exal]) | vb_rows$ld_mode_fallback_rate[rhs_exal] <= ld_fallback_max)
  )
vb_rows$gate_vb_ld_local_mode <- ifelse(
  vb_rows$model == "exal" & !is.na(vb_rows$ld_stabilized_rate_tail) & vb_rows$ld_stabilized_rate_tail > 0,
  !is.na(vb_rows$ld_candidate_local_pass_rate_tail) & vb_rows$ld_candidate_local_pass_rate_tail >= 0.80,
  ifelse(
    vb_rows$model == "exal",
    !is.na(vb_rows$ld_local_mode_pass) & as.logical(vb_rows$ld_local_mode_pass),
    TRUE
  )
)
vb_rows$gate_vb_ld_local_mode[is.na(vb_rows$gate_vb_ld_local_mode)] <- TRUE
vb_rows$gate_mcmc_kernel_exact <- ifelse(
  vb_rows$model == "exal",
  !is.na(vb_rows$mcmc_gamma_kernel_exact) & as.logical(vb_rows$mcmc_gamma_kernel_exact),
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
if (nrow(method_signoff) > 0) {
  vb_signoff <- method_signoff[method_signoff$inference == "vb", c("model", "tau", "signoff_grade", "comparison_eligible", "signoff_reason"), drop = FALSE]
  names(vb_signoff) <- c("model", "tau", "vb_signoff_grade", "vb_comparison_eligible", "vb_signoff_reason")
  gate_df <- merge(gate_df, vb_signoff, by = c("model", "tau"), all.x = TRUE, sort = FALSE)
  mc_signoff <- method_signoff[method_signoff$inference == "mcmc", c("model", "tau", "signoff_grade", "comparison_eligible", "signoff_reason"), drop = FALSE]
  names(mc_signoff) <- c("model", "tau", "mcmc_signoff_grade", "mcmc_comparison_eligible", "mcmc_signoff_reason")
  gate_df <- merge(gate_df, mc_signoff, by = c("model", "tau"), all.x = TRUE, sort = FALSE)
}
if (nrow(algorithm_pair_signoff) > 0) {
  alg_cols <- algorithm_pair_signoff[, c("model", "tau", "pair_signoff_grade", "pair_comparison_eligible"), drop = FALSE]
  names(alg_cols) <- c("model", "tau", "algorithm_pair_signoff_grade", "algorithm_pair_comparison_eligible")
  gate_df <- merge(gate_df, alg_cols, by = c("model", "tau"), all.x = TRUE, sort = FALSE)
}
gate_df$overall_pass <- with(
  gate_df,
  gate_vb_converged & gate_vb_ld_stable & gate_vb_ld_local_mode &
    gate_mcmc_kernel_exact & gate_mcmc_ess_sigma & gate_mcmc_ess_gamma & gate_accuracy
)
utils::write.csv(gate_df, file.path(out_tables, "acceptance_gate_summary.csv"), row.names = FALSE)

vb_mcmc_rows <- list()
if (nrow(metrics_df) > 0) {
  taus <- sort(unique(metrics_df$tau))
  models <- sort(unique(metrics_df$model))
  for (tau in taus) {
    for (model in models) {
      vb <- metrics_df[metrics_df$model == model & metrics_df$tau == tau & metrics_df$method == "vb", , drop = FALSE]
      mc <- metrics_df[metrics_df$model == model & metrics_df$tau == tau & metrics_df$method == "mcmc", , drop = FALSE]
      if (nrow(vb) == 1 && nrow(mc) == 1) {
        vb_mcmc_rows[[length(vb_mcmc_rows) + 1L]] <- data.frame(
          model = model,
          tau = tau,
          mae_vb = vb$mae,
          mae_mcmc = mc$mae,
          mae_delta_mcmc_minus_vb = mc$mae - vb$mae,
          rmse_vb = vb$rmse,
          rmse_mcmc = mc$rmse,
          rmse_delta_mcmc_minus_vb = mc$rmse - vb$rmse,
          bias_vb = vb$bias,
          bias_mcmc = mc$bias,
          bias_delta_mcmc_minus_vb = mc$bias - vb$bias,
          corr_vb = vb$corr,
          corr_mcmc = mc$corr,
          corr_delta_mcmc_minus_vb = mc$corr - vb$corr,
          coverage_vb = NA_real_,
          coverage_mcmc = NA_real_,
          coverage_delta_mcmc_minus_vb = NA_real_,
          mean_ci_width_vb = NA_real_,
          mean_ci_width_mcmc = NA_real_,
          mean_ci_width_delta_mcmc_minus_vb = NA_real_,
          n_draws_vb = NA_real_,
          n_draws_mcmc = NA_real_,
          stringsAsFactors = FALSE
        )
      }
    }
  }
}
vb_mcmc_df <- if (length(vb_mcmc_rows)) do.call(rbind, vb_mcmc_rows) else data.frame(
  model = character(0),
  tau = numeric(0),
  mae_vb = numeric(0),
  mae_mcmc = numeric(0),
  mae_delta_mcmc_minus_vb = numeric(0),
  rmse_vb = numeric(0),
  rmse_mcmc = numeric(0),
  rmse_delta_mcmc_minus_vb = numeric(0),
  bias_vb = numeric(0),
  bias_mcmc = numeric(0),
  bias_delta_mcmc_minus_vb = numeric(0),
  corr_vb = numeric(0),
  corr_mcmc = numeric(0),
  corr_delta_mcmc_minus_vb = numeric(0),
  coverage_vb = numeric(0),
  coverage_mcmc = numeric(0),
  coverage_delta_mcmc_minus_vb = numeric(0),
  mean_ci_width_vb = numeric(0),
  mean_ci_width_mcmc = numeric(0),
  mean_ci_width_delta_mcmc_minus_vb = numeric(0),
  n_draws_vb = numeric(0),
  n_draws_mcmc = numeric(0),
  stringsAsFactors = FALSE
)
if (nrow(vb_mcmc_df) > 0) {
  rt_cols <- runtime_diag[, c("model", "tau", "beta_prior", "vb_runtime_sec", "mcmc_runtime_sec"), drop = FALSE]
  vb_mcmc_df <- merge(vb_mcmc_df, rt_cols, by = c("model", "tau"), all.x = TRUE, sort = FALSE)
  vb_mcmc_df$runtime_ratio_mcmc_vs_vb <- vb_mcmc_df$mcmc_runtime_sec / vb_mcmc_df$vb_runtime_sec
  gate_cols <- gate_df[, c(
    "model", "tau", "vb_signoff_grade", "vb_comparison_eligible", "vb_signoff_reason",
    "mcmc_signoff_grade", "mcmc_comparison_eligible", "mcmc_signoff_reason",
    "algorithm_pair_signoff_grade", "algorithm_pair_comparison_eligible",
    "gate_accuracy", "overall_pass"
  ), drop = FALSE]
  vb_mcmc_df <- merge(vb_mcmc_df, gate_cols, by = c("model", "tau"), all.x = TRUE, sort = FALSE)
}
vb_mcmc_df <- ensure_col(vb_mcmc_df, "beta_prior", NA_character_)
vb_mcmc_df <- ensure_col(vb_mcmc_df, "vb_runtime_sec", NA_real_)
vb_mcmc_df <- ensure_col(vb_mcmc_df, "mcmc_runtime_sec", NA_real_)
vb_mcmc_df <- ensure_col(vb_mcmc_df, "runtime_ratio_mcmc_vs_vb", NA_real_)
vb_mcmc_df <- ensure_col(vb_mcmc_df, "vb_signoff_grade", NA_character_)
vb_mcmc_df <- ensure_col(vb_mcmc_df, "vb_comparison_eligible", NA)
vb_mcmc_df <- ensure_col(vb_mcmc_df, "vb_signoff_reason", NA_character_)
vb_mcmc_df <- ensure_col(vb_mcmc_df, "mcmc_signoff_grade", NA_character_)
vb_mcmc_df <- ensure_col(vb_mcmc_df, "mcmc_comparison_eligible", NA)
vb_mcmc_df <- ensure_col(vb_mcmc_df, "mcmc_signoff_reason", NA_character_)
vb_mcmc_df <- ensure_col(vb_mcmc_df, "algorithm_pair_signoff_grade", NA_character_)
vb_mcmc_df <- ensure_col(vb_mcmc_df, "algorithm_pair_comparison_eligible", NA)
vb_mcmc_df <- ensure_col(vb_mcmc_df, "gate_accuracy", NA)
vb_mcmc_df <- ensure_col(vb_mcmc_df, "overall_pass", NA)
vb_mcmc_df_eligible <- if (nrow(vb_mcmc_df)) vb_mcmc_df[as.logical(vb_mcmc_df$algorithm_pair_comparison_eligible %in% TRUE), , drop = FALSE] else vb_mcmc_df
vb_mcmc_df_excluded <- if (nrow(vb_mcmc_df)) vb_mcmc_df[!as.logical(vb_mcmc_df$algorithm_pair_comparison_eligible %in% TRUE), , drop = FALSE] else vb_mcmc_df
utils::write.csv(vb_mcmc_df, file.path(out_tables, "pairwise_vb_vs_mcmc.csv"), row.names = FALSE)
utils::write.csv(vb_mcmc_df_eligible, file.path(out_tables, "pairwise_vb_vs_mcmc_eligible.csv"), row.names = FALSE)
utils::write.csv(vb_mcmc_df_excluded, file.path(out_tables, "pairwise_vb_vs_mcmc_excluded.csv"), row.names = FALSE)

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
    safe_density <- function(z) {
      z <- as.numeric(z)
      z <- z[is.finite(z)]
      if (length(z) < 2L) return(NULL)
      if (length(unique(signif(z, 12L))) < 2L) return(NULL)
      tryCatch(stats::density(z, n = 512), error = function(e) NULL)
    }
    dens_vals <- lapply(res_list, safe_density)
    keep_idx <- vapply(dens_vals, function(x) !is.null(x), logical(1))
    png(file.path(out_plots_diag, sprintf("residual_density_tau_%s.png", tau_lab(tau))), width = 1400, height = 900)
    if (any(keep_idx)) {
      dens_keep <- dens_vals[keep_idx]
      cols_keep <- dens_cols[keep_idx]
      labels_keep <- names(res_list)[keep_idx]
      xlim_den <- range(unlist(lapply(dens_keep, `[[`, "x")), finite = TRUE)
      ylim_den <- range(unlist(lapply(dens_keep, `[[`, "y")), finite = TRUE)
      plot(dens_keep[[1]], col = cols_keep[1], lwd = 2, main = sprintf("Residual Density (tau=%.2f)", tau),
           xlab = "residual (y - qhat)", ylab = "density", xlim = xlim_den, ylim = ylim_den)
      if (length(dens_keep) > 1L) {
        for (k in 2:length(dens_keep)) lines(dens_keep[[k]], col = cols_keep[k], lwd = 2)
      }
      abline(v = 0, lty = 2, col = "grey35")
      legend("topright", bty = "n", lwd = 2, col = cols_keep, legend = labels_keep)
    } else {
      plot.new()
      title(main = sprintf("Residual Density (tau=%.2f)", tau))
      text(0.5, 0.5, "Insufficient finite residual variation for density plot", cex = 1.0)
    }
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
  sprintf("- tasks_total: %d", nrow(runtime_diag)),
  sprintf("- tasks_done_or_reused: %d", sum(runtime_diag$status %in% c("done", "skipped_existing"), na.rm = TRUE)),
  sprintf("- tasks_reused_existing: %d", sum(runtime_diag$status == "skipped_existing", na.rm = TRUE)),
  sprintf("- tasks_failed: %d", sum(runtime_diag$status == "failed", na.rm = TRUE)),
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
  sprintf("- method_signoff_pass_count: %d", if (nrow(method_signoff)) sum(method_signoff$signoff_grade == "PASS", na.rm = TRUE) else 0L),
  sprintf("- method_signoff_warn_count: %d", if (nrow(method_signoff)) sum(method_signoff$signoff_grade == "WARN", na.rm = TRUE) else 0L),
  sprintf("- method_signoff_fail_count: %d", if (nrow(method_signoff)) sum(method_signoff$signoff_grade == "FAIL", na.rm = TRUE) else 0L),
  sprintf("- method_comparison_eligible_count: %d", if (nrow(method_signoff)) sum(as.logical(method_signoff$comparison_eligible), na.rm = TRUE) else 0L),
  sprintf("- algorithm_pair_eligible_count: %d", if (nrow(algorithm_pair_signoff)) sum(as.logical(algorithm_pair_signoff$pair_comparison_eligible), na.rm = TRUE) else 0L),
  sprintf("- model_pair_eligible_count: %d", if (nrow(model_pair_signoff)) sum(as.logical(model_pair_signoff$pair_comparison_eligible), na.rm = TRUE) else 0L),
  sprintf("- vb_vs_mcmc_rows_all: %d", nrow(vb_mcmc_df)),
  sprintf("- vb_vs_mcmc_rows_eligible: %d", nrow(vb_mcmc_df_eligible)),
  sprintf("- vb_vs_mcmc_rows_excluded: %d", nrow(vb_mcmc_df_excluded)),
  sprintf("- eligible_metric_rows: %d", nrow(eligible_metrics_df)),
  sprintf("- eligible_pairwise_rows: %d", nrow(pair_df_eligible)),
  sprintf("- excluded_pairwise_rows: %d", nrow(pair_df_excluded)),
  sprintf("- rhs_rows: %d", if (nrow(rhs_diag)) nrow(rhs_diag) else 0L),
  sprintf("- rhs_collapse_flag_count: %d", if (nrow(rhs_diag) && "rhs_collapse_flag" %in% names(rhs_diag)) sum(rhs_diag$rhs_collapse_flag, na.rm = TRUE) else 0L)
), con)

cat(sprintf("S4 report generated under: %s\n", run_root))

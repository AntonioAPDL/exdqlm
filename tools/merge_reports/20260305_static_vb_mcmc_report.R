#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(devtools)
})

devtools::load_all(".", quiet = TRUE)

safe_num <- function(x, default = NA_real_) {
  v <- suppressWarnings(as.numeric(x)[1])
  if (!is.finite(v) || is.na(v)) default else v
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

summary_path <- file.path(run_root, "tables", "pipeline_task_summary.csv")
if (!file.exists(summary_path)) stop("Missing pipeline summary: ", summary_path)
summary_df <- utils::read.csv(summary_path, check.names = FALSE)

out_tables <- file.path(run_root, "tables")
out_plots <- file.path(run_root, "plots")
dir.create(out_tables, recursive = TRUE, showWarnings = FALSE)
dir.create(out_plots, recursive = TRUE, showWarnings = FALSE)

TT <- if (!is.null(cfg$TT)) as.integer(cfg$TT) else nrow(sim$extras$X)
X <- as.matrix(sim$extras$X[seq_len(TT), , drop = FALSE])
q_true <- as.matrix(sim$q[seq_len(TT), , drop = FALSE])
p_grid <- as.numeric(sim$p)

closest_p_index <- function(tau) which.min(abs(p_grid - tau))

collect_rows <- list()
plot_payload <- list()

for (i in seq_len(nrow(summary_df))) {
  row <- summary_df[i, , drop = FALSE]
  if (!identical(as.character(row$status), "done")) next

  model <- as.character(row$model)
  tau <- as.numeric(row$tau)
  vb_file <- as.character(row$vb_file)
  mcmc_file <- as.character(row$mcmc_file)
  if (!file.exists(vb_file) || !file.exists(mcmc_file)) next

  vb_obj <- readRDS(vb_file)
  m_obj <- readRDS(mcmc_file)
  vb_fit <- vb_obj$fit
  m_fit <- m_obj$fit

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

vb_rows <- runtime_diag[, c("model", "tau", "vb_converged", "vb_stop_reason", "ess_sigma", "ess_gamma", "status"), drop = FALSE]
vb_rows$gate_vb_converged <- isTRUE(vb_rows$vb_converged) # placeholder scalar
vb_rows$gate_vb_converged <- as.logical(vb_rows$vb_converged)
vb_rows$gate_mcmc_ess_sigma <- !is.na(vb_rows$ess_sigma) & vb_rows$ess_sigma >= ess_sigma_min
vb_rows$gate_mcmc_ess_gamma <- ifelse(
  vb_rows$model == "exal",
  !is.na(vb_rows$ess_gamma) & vb_rows$ess_gamma >= ess_gamma_min,
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
gate_df$overall_pass <- with(gate_df, gate_vb_converged & gate_mcmc_ess_sigma & gate_mcmc_ess_gamma & gate_accuracy)
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
  }

  # Runtime bar plot
  done_df <- runtime_diag[runtime_diag$status == "done", , drop = FALSE]
  if (nrow(done_df) > 0) {
    ord <- order(done_df$model, done_df$tau)
    done_df <- done_df[ord, ]
    labels <- sprintf("%s@%.2f", done_df$model, done_df$tau)
    mat <- rbind(done_df$vb_runtime_sec, done_df$mcmc_runtime_sec)

    png(file.path(out_plots, "runtime_vb_mcmc_by_task.png"), width = 1200, height = 700)
    barplot(mat, beside = TRUE, names.arg = labels, las = 2,
            col = c("#4e79a7", "#f28e2b"), ylab = "seconds",
            main = "Runtime by Task (Static VB vs MCMC)")
    legend("topright", bty = "n", fill = c("#4e79a7", "#f28e2b"), legend = c("VB", "MCMC"))
    dev.off()
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
  sprintf("- sim_path: `%s`", sim_path),
  sprintf("- generated_at: `%s`", format(Sys.time(), "%Y-%m-%d %H:%M:%S")),
  "",
  sprintf("- tasks_total: %d", nrow(summary_df)),
  sprintf("- tasks_done: %d", sum(summary_df$status == "done", na.rm = TRUE)),
  sprintf("- tasks_failed: %d", sum(summary_df$status == "failed", na.rm = TRUE)),
  "",
  "## Gate thresholds",
  sprintf("- ESS sigma min: %.1f", ess_sigma_min),
  sprintf("- ESS gamma min (exAL): %.1f", ess_gamma_min),
  "- accuracy gate: RMSE(MCMC) <= 1.25 * RMSE(VB)",
  "",
  sprintf("- gate_pass_count: %d", sum(gate_df$overall_pass, na.rm = TRUE)),
  sprintf("- gate_fail_count: %d", sum(!gate_df$overall_pass, na.rm = TRUE))
), con)

cat(sprintf("S4 report generated under: %s\n", run_root))

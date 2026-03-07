#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(grDevices)
})

safe_int <- function(x, default) {
  v <- suppressWarnings(as.integer(x)[1])
  if (!is.finite(v) || is.na(v)) default else v
}

tau_lab <- function(tau) gsub("\\.", "p", format(as.numeric(tau), nsmall = 2))

out_root <- Sys.getenv("EXDQLM_OUT_ROOT", "results/function_testing_20260304_vb_quantiles")
sim_path <- Sys.getenv("EXDQLM_SIM_PATH", "results/sim_suite_dlm/series/dlm_constV_smallW/sim_output.rds")
tail_n_req <- safe_int(Sys.getenv("EXDQLM_PLOT_TAIL_N", "100"), 100L)
ci_level <- 0.95

if (!dir.exists(out_root)) stop("Output root not found: ", out_root)
if (!file.exists(sim_path)) stop("Simulation file not found: ", sim_path)

cfg_path <- file.path(out_root, "run_config.rds")
if (!file.exists(cfg_path)) stop("run_config.rds not found in ", out_root)

cfg <- readRDS(cfg_path)
TT <- as.integer(cfg$TT_used)
if (!is.finite(TT) || is.na(TT) || TT < 50L) stop("Invalid TT_used in run_config.rds.")

sim <- readRDS(sim_path)
y <- as.numeric(sim$y[seq_len(TT)])
mu_true <- if (!is.null(sim$extras$mu)) as.numeric(sim$extras$mu[seq_len(TT)]) else rep(NA_real_, TT)
p_vec <- c(0.05, 0.50, 0.95)
tail_n <- min(tail_n_req, TT)

load_derived <- function(inference, model_name, tau) {
  path <- file.path(
    out_root, "derived",
    sprintf("%s_%s_tau_%s_summary.rds", inference, model_name, tau_lab(tau))
  )
  if (!file.exists(path)) stop("Missing derived file: ", path)
  readRDS(path)
}

plot_fit_compare <- function(
  file_path, idx_use, obj_a, obj_b, label_a, label_b, col_a, col_b, title_txt, ci_label
) {
  y_use <- y[idx_use]
  t_use <- idx_use
  true_q_use <- obj_a$true_q[idx_use]

  map_a <- obj_a$summary$map[idx_use]
  lb_a <- obj_a$summary$lb[idx_use]
  ub_a <- obj_a$summary$ub[idx_use]

  map_b <- obj_b$summary$map[idx_use]
  lb_b <- obj_b$summary$lb[idx_use]
  ub_b <- obj_b$summary$ub[idx_use]

  y_lim <- range(c(y_use, true_q_use, lb_a, ub_a, lb_b, ub_b), finite = TRUE)
  y_pad <- 0.04 * diff(y_lim)
  if (!is.finite(y_pad) || y_pad <= 0) y_pad <- 1e-6
  y_lim <- y_lim + c(-y_pad, y_pad)

  grDevices::png(file_path, width = 2300, height = 1200, res = 180)
  old_par <- graphics::par(no.readonly = TRUE)
  on.exit({
    graphics::par(old_par)
    grDevices::dev.off()
  }, add = TRUE)

  graphics::par(mar = c(5.2, 5.4, 4.2, 1.2), las = 1)
  graphics::plot(
    t_use, y_use, type = "l", col = "#6B6B6B", lwd = 1.2,
    xlab = "time index", ylab = "value", main = title_txt, ylim = y_lim
  )
  graphics::abline(h = pretty(y_lim, n = 8), col = "#ECECEC", lty = 1, lwd = 0.9)
  graphics::abline(v = pretty(t_use, n = 8), col = "#F4F4F4", lty = 1, lwd = 0.8)

  xx <- c(t_use, rev(t_use))
  graphics::polygon(xx, c(lb_a, rev(ub_a)), border = NA, col = grDevices::adjustcolor(col_a, alpha.f = 0.24))
  graphics::polygon(xx, c(lb_b, rev(ub_b)), border = NA, col = grDevices::adjustcolor(col_b, alpha.f = 0.24))

  graphics::lines(t_use, lb_a, lwd = 1.1, lty = 3, col = grDevices::adjustcolor(col_a, alpha.f = 0.92))
  graphics::lines(t_use, ub_a, lwd = 1.1, lty = 3, col = grDevices::adjustcolor(col_a, alpha.f = 0.92))
  graphics::lines(t_use, lb_b, lwd = 1.1, lty = 3, col = grDevices::adjustcolor(col_b, alpha.f = 0.92))
  graphics::lines(t_use, ub_b, lwd = 1.1, lty = 3, col = grDevices::adjustcolor(col_b, alpha.f = 0.92))

  graphics::lines(t_use, true_q_use, lwd = 2.4, lty = 2, col = "#1A1A1A")
  graphics::lines(t_use, map_a, lwd = 2.5, col = col_a)
  graphics::lines(t_use, map_b, lwd = 2.5, col = col_b)
  if (all(is.finite(mu_true))) {
    graphics::lines(t_use, mu_true[idx_use], lwd = 1.4, lty = 4, col = "#2A9D8F")
  }

  graphics::legend(
    "topleft",
    legend = c("y", "true quantile", label_a, label_b,
               sprintf("%s %s", label_a, ci_label), sprintf("%s %s", label_b, ci_label), "true mean (mu_t)"),
    col = c("#6B6B6B", "#1A1A1A", col_a, col_b,
            grDevices::adjustcolor(col_a, alpha.f = 0.5),
            grDevices::adjustcolor(col_b, alpha.f = 0.5), "#2A9D8F"),
    lty = c(1, 2, 1, 1, 1, 1, 4),
    lwd = c(1.2, 2.4, 2.5, 2.5, 10, 10, 1.4),
    bty = "n", cex = 0.95
  )
}

dir_within <- file.path(out_root, "plots", "fit_within_inference")
dir_between <- file.path(out_root, "plots", "fit_between_inference")
if (!dir.exists(dir_within) || !dir.exists(dir_between)) {
  stop("Expected plot directories not found under ", out_root)
}

unlink(Sys.glob(file.path(dir_within, "*.png")), force = TRUE)
unlink(Sys.glob(file.path(dir_between, "*.png")), force = TRUE)

idx_full <- seq_len(TT)
idx_tail <- seq.int(TT - tail_n + 1L, TT)
ci_label <- sprintf("%.0f%% CrI", ci_level * 100)

# Color-blind safe palettes with high contrast for overlap.
cols_within <- c(exdqlm = "#D55E00", dqlm = "#0072B2")
cols_between <- c(vb = "#009E73", mcmc = "#CC79A7")

for (tau in p_vec) {
  tlabel <- tau_lab(tau)

  for (inf in c("vb", "mcmc")) {
    obj_ex <- load_derived(inf, "exdqlm", tau)
    obj_dq <- load_derived(inf, "dqlm", tau)

    file_full <- file.path(dir_within, sprintf("%s_tau_%s_dqlm_vs_exdqlm_full.png", inf, tlabel))
    file_tail <- file.path(dir_within, sprintf("%s_tau_%s_dqlm_vs_exdqlm_last%d.png", inf, tlabel, tail_n))

    plot_fit_compare(
      file_full, idx_full,
      obj_a = obj_ex, obj_b = obj_dq,
      label_a = paste0(toupper(inf), " exDQLM"),
      label_b = paste0(toupper(inf), " DQLM"),
      col_a = cols_within[["exdqlm"]],
      col_b = cols_within[["dqlm"]],
      title_txt = sprintf("%s fit compare (tau=%.2f): exDQLM vs DQLM [full]", toupper(inf), tau),
      ci_label = ci_label
    )

    plot_fit_compare(
      file_tail, idx_tail,
      obj_a = obj_ex, obj_b = obj_dq,
      label_a = paste0(toupper(inf), " exDQLM"),
      label_b = paste0(toupper(inf), " DQLM"),
      col_a = cols_within[["exdqlm"]],
      col_b = cols_within[["dqlm"]],
      title_txt = sprintf("%s fit compare (tau=%.2f): exDQLM vs DQLM [last %d]", toupper(inf), tau, tail_n),
      ci_label = ci_label
    )
  }

  for (mdl in c("exdqlm", "dqlm")) {
    obj_vb <- load_derived("vb", mdl, tau)
    obj_mc <- load_derived("mcmc", mdl, tau)

    file_full <- file.path(dir_between, sprintf("%s_tau_%s_vb_vs_mcmc_full.png", mdl, tlabel))
    file_tail <- file.path(dir_between, sprintf("%s_tau_%s_vb_vs_mcmc_last%d.png", mdl, tlabel, tail_n))

    plot_fit_compare(
      file_full, idx_full,
      obj_a = obj_vb, obj_b = obj_mc,
      label_a = paste("VB", toupper(mdl)),
      label_b = paste("MCMC", toupper(mdl)),
      col_a = cols_between[["vb"]],
      col_b = cols_between[["mcmc"]],
      title_txt = sprintf("%s fit compare (tau=%.2f): VB vs MCMC [full]", toupper(mdl), tau),
      ci_label = ci_label
    )

    plot_fit_compare(
      file_tail, idx_tail,
      obj_a = obj_vb, obj_b = obj_mc,
      label_a = paste("VB", toupper(mdl)),
      label_b = paste("MCMC", toupper(mdl)),
      col_a = cols_between[["vb"]],
      col_b = cols_between[["mcmc"]],
      title_txt = sprintf("%s fit compare (tau=%.2f): VB vs MCMC [last %d]", toupper(mdl), tau, tail_n),
      ci_label = ci_label
    )
  }
}

cat(sprintf(
  "%s | Replotted CI figures with tail window = %d at %s\n",
  format(Sys.time(), "%Y-%m-%d %H:%M:%S"), tail_n, out_root
))

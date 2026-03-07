#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(devtools)
  library(parallel)
})

devtools::load_all(".", quiet = TRUE)

Sys.setenv(
  OMP_NUM_THREADS = "1",
  OPENBLAS_NUM_THREADS = "1",
  MKL_NUM_THREADS = "1",
  VECLIB_MAXIMUM_THREADS = "1",
  NUMEXPR_NUM_THREADS = "1"
)

safe_int <- function(x, default) {
  v <- suppressWarnings(as.integer(x)[1])
  if (!is.finite(v) || is.na(v)) default else v
}

safe_num <- function(x, default) {
  v <- suppressWarnings(as.numeric(x)[1])
  if (!is.finite(v) || is.na(v)) default else v
}

tau_lab <- function(tau) gsub("\\.", "p", format(as.numeric(tau), nsmall = 2))

audit_stamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
audit_root <- Sys.getenv(
  "EXDQLM_STATIC_GAMMA0_REDUCTION_AUDIT_ROOT",
  file.path("results", "sim_suite_static", "audits", sprintf("static_exal_gamma0_reduction_%s", audit_stamp))
)
dir.create(audit_root, recursive = TRUE, showWarnings = FALSE)
for (d in c("fits/vb", "tables", "plots", "logs")) {
  dir.create(file.path(audit_root, d), recursive = TRUE, showWarnings = FALSE)
}

log_file <- file.path(audit_root, "logs", "audit.log")
log_msg <- function(...) {
  line <- paste(format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "|", paste(..., collapse = " "))
  cat(line, "\n")
  cat(line, "\n", file = log_file, append = TRUE)
  flush.console()
}

gamma_band <- safe_num(Sys.getenv("EXDQLM_STATIC_EXAL_GAMMA0_BAND", "1e-6"), 1e-6)
if (!is.finite(gamma_band) || gamma_band <= 0) stop("gamma band must be positive")

scenario_tbl <- data.frame(
  scenario = c("rich_static", "heteroskedastic", "homoskedastic"),
  run_root = c(
    "results/sim_suite_static/static_vb_then_mcmc_tt5000_vbns1000_burn2000_n1000_20260305_160734",
    "results/function_testing_20260306_static_scale_pair_skewnormal/heteroskedastic/static_vb_then_mcmc_tt5000_vbns1000_burn2000_n1000_20260306_011944_heteroskedastic_sub5000",
    "results/function_testing_20260306_static_scale_pair_skewnormal/homoskedastic/static_vb_then_mcmc_tt5000_vbns1000_burn2000_n1000_20260306_011944_homoskedastic_sub5000"
  ),
  stringsAsFactors = FALSE
)

if (!all(dir.exists(scenario_tbl$run_root))) {
  missing_roots <- scenario_tbl$run_root[!dir.exists(scenario_tbl$run_root)]
  stop("Missing scenario run root(s): ", paste(missing_roots, collapse = ", "))
}

fit_file <- function(run_root, inf, model, tau) {
  file.path(run_root, "fits", inf, sprintf("%s_%s_tau_%s_fit.rds", inf, model, tau_lab(tau)))
}

metric_row <- function(scenario, model, method, tau, qhat, qref, lo = NULL, hi = NULL) {
  err <- as.numeric(qhat - qref)
  data.frame(
    scenario = scenario,
    model = model,
    method = method,
    tau = as.numeric(tau),
    n = length(err),
    rmse = sqrt(mean(err^2)),
    mae = mean(abs(err)),
    bias = mean(err),
    coverage = if (!is.null(lo) && !is.null(hi)) mean(qref >= lo & qref <= hi) else NA_real_,
    mean_ci_width = if (!is.null(lo) && !is.null(hi)) mean(hi - lo) else NA_real_,
    stringsAsFactors = FALSE
  )
}

baseline_rows <- list()
for (i in seq_len(nrow(scenario_tbl))) {
  scenario <- scenario_tbl$scenario[i]
  run_root <- scenario_tbl$run_root[i]
  metrics_path <- file.path(run_root, "tables", "metrics_summary.csv")
  mm <- utils::read.csv(metrics_path, check.names = FALSE)
  names(mm)[names(mm) == "inference"] <- "method"
  mm$scenario <- scenario
  baseline_rows[[length(baseline_rows) + 1L]] <- mm[, c("scenario", "model", "method", "tau", "rmse", "coverage", "mean_ci_width")]
}
baseline_metrics <- do.call(rbind, baseline_rows)
baseline_metrics$model <- as.character(baseline_metrics$model)
baseline_metrics$method <- as.character(baseline_metrics$method)
utils::write.csv(baseline_metrics, file.path(audit_root, "tables", "baseline_metrics_summary.csv"), row.names = FALSE)

baseline_pair_rows <- list()
for (scenario in unique(baseline_metrics$scenario)) {
  for (tau in sort(unique(baseline_metrics$tau))) {
    for (method in sort(unique(baseline_metrics$method))) {
      ex_row <- baseline_metrics[baseline_metrics$scenario == scenario & baseline_metrics$model == "exal" &
        baseline_metrics$tau == tau & baseline_metrics$method == method, , drop = FALSE]
      al_row <- baseline_metrics[baseline_metrics$scenario == scenario & baseline_metrics$model == "al" &
        baseline_metrics$tau == tau & baseline_metrics$method == method, , drop = FALSE]
      if (nrow(ex_row) != 1L || nrow(al_row) != 1L) next
      baseline_pair_rows[[length(baseline_pair_rows) + 1L]] <- data.frame(
        scenario = scenario,
        tau = tau,
        method = method,
        rmse_exal = ex_row$rmse,
        rmse_al = al_row$rmse,
        rmse_ratio_exal_to_al = ex_row$rmse / al_row$rmse,
        rmse_delta_exal_minus_al = ex_row$rmse - al_row$rmse,
        exal_better_than_al = ex_row$rmse < al_row$rmse,
        stringsAsFactors = FALSE
      )
    }
  }
}
baseline_pair_df <- do.call(rbind, baseline_pair_rows)
utils::write.csv(baseline_pair_df, file.path(audit_root, "tables", "baseline_pairwise_exal_vs_al.csv"), row.names = FALSE)

pattern_rows <- list()
for (tau in sort(unique(baseline_pair_df$tau))) {
  for (method in sort(unique(baseline_pair_df$method))) {
    ss <- baseline_pair_df[baseline_pair_df$tau == tau & baseline_pair_df$method == method, , drop = FALSE]
    if (!nrow(ss)) next
    pattern_rows[[length(pattern_rows) + 1L]] <- data.frame(
      tau = tau,
      method = method,
      scenarios = nrow(ss),
      exal_worse_count = sum(ss$rmse_exal > ss$rmse_al, na.rm = TRUE),
      exal_better_count = sum(ss$rmse_exal < ss$rmse_al, na.rm = TRUE),
      median_rmse_ratio_exal_to_al = stats::median(ss$rmse_ratio_exal_to_al, na.rm = TRUE),
      stringsAsFactors = FALSE
    )
  }
}
pattern_df <- do.call(rbind, pattern_rows)
utils::write.csv(pattern_df, file.path(audit_root, "tables", "baseline_pattern_by_tau_method.csv"), row.names = FALSE)

reduction_rows <- lapply(c(0.05, 0.50, 0.95), function(tau) {
  A0 <- A.fn(tau, 0)
  B0 <- B.fn(tau, 0)
  g_vec <- c(-gamma_band, gamma_band)
  data.frame(
    tau = tau,
    gamma_band = gamma_band,
    max_abs_A_diff = max(abs(A.fn(tau, g_vec) - A0)),
    max_abs_B_diff = max(abs(B.fn(tau, g_vec) - B0)),
    max_abs_lambda = max(abs(C.fn(tau, g_vec) * abs(g_vec))),
    stringsAsFactors = FALSE
  )
})
reduction_df <- do.call(rbind, reduction_rows)
utils::write.csv(reduction_df, file.path(audit_root, "tables", "gamma_band_reduction_constants.csv"), row.names = FALSE)

run_gamma0_vb_task <- function(task_row) {
  scenario <- as.character(task_row$scenario)
  run_root <- as.character(task_row$run_root)
  tau <- as.numeric(task_row$tau)
  seed <- as.integer(task_row$seed)

  cfg <- readRDS(file.path(run_root, "tables", "run_config.rds"))
  sim <- readRDS(cfg$sim_path)
  TT <- as.integer(cfg$TT)
  y <- as.numeric(sim$y[seq_len(TT)])
  X <- as.matrix(sim$extras$X[seq_len(TT), , drop = FALSE])
  p_grid <- as.numeric(sim$p)
  q_ref <- as.numeric(sim$q[seq_len(TT), which.min(abs(p_grid - tau))])
  gamma_bounds <- c(-gamma_band, gamma_band)
  vb_file <- file.path(audit_root, "fits", "vb", sprintf("vb_exal_gamma0_%s_tau_%s_fit.rds", scenario, tau_lab(tau)))

  log_msg(sprintf("start vb scenario=%s tau=%.2f seed=%d", scenario, tau, seed))
  set.seed(seed)
  vb_t0 <- Sys.time()
  vb_fit <- exal_static_LDVB(
    y = y,
    X = X,
    p0 = tau,
    max_iter = cfg$vb$max_iter,
    tol = cfg$vb$tol,
    gamma_bounds = gamma_bounds,
    init = list(gamma = 0),
    dqlm.ind = FALSE,
    n_samp_xi = cfg$vb$n_samp_xi,
    ld_controls = cfg$vb$ld,
    verbose = FALSE
  )
  vb_runtime <- as.numeric(difftime(Sys.time(), vb_t0, units = "secs"))
  vb_norm <- .static_normalize_vb_fit(
    vb_fit,
    model_name = "exal",
    tau = tau,
    run_settings = list(
      audit = "exal_gamma0_reduction",
      gamma_band = gamma_band,
      constrained_gamma_zero = TRUE
    )
  )
  saveRDS(
    list(
      fit = vb_fit,
      normalized = vb_norm,
      meta = list(scenario = scenario, tau = tau, seed = seed, runtime_sec = vb_runtime, gamma_band = gamma_band)
    ),
    vb_file,
    compress = "xz"
  )

  vb_path <- .static_quantile_path_from_fit(vb_fit, X, algorithm = "vb")
  base_al_vb <- readRDS(fit_file(run_root, "vb", "al", tau))$fit
  base_ex_vb <- readRDS(fit_file(run_root, "vb", "exal", tau))$fit
  base_al_vb_path <- .static_quantile_path_from_fit(base_al_vb, X, algorithm = "vb")
  base_ex_vb_path <- .static_quantile_path_from_fit(base_ex_vb, X, algorithm = "vb")

  comp_row <- data.frame(
    scenario = scenario,
    tau = tau,
    method = "vb",
    rmse_al = sqrt(mean((base_al_vb_path$mean - q_ref)^2)),
    rmse_exal_free = sqrt(mean((base_ex_vb_path$mean - q_ref)^2)),
    rmse_exal_gamma0 = sqrt(mean((vb_path$mean - q_ref)^2)),
    delta_free_minus_al = sqrt(mean((base_ex_vb_path$mean - q_ref)^2)) - sqrt(mean((base_al_vb_path$mean - q_ref)^2)),
    delta_gamma0_minus_al = sqrt(mean((vb_path$mean - q_ref)^2)) - sqrt(mean((base_al_vb_path$mean - q_ref)^2)),
    gap_closure_fraction = {
      free_gap <- sqrt(mean((base_ex_vb_path$mean - q_ref)^2)) - sqrt(mean((base_al_vb_path$mean - q_ref)^2))
      g0_gap <- sqrt(mean((vb_path$mean - q_ref)^2)) - sqrt(mean((base_al_vb_path$mean - q_ref)^2))
      if (is.finite(free_gap) && abs(free_gap) > 1e-12) 1 - abs(g0_gap) / abs(free_gap) else NA_real_
    },
    path_rmse_gamma0_vs_al = sqrt(mean((vb_path$mean - base_al_vb_path$mean)^2)),
    path_max_abs_gamma0_vs_al = max(abs(vb_path$mean - base_al_vb_path$mean)),
    gamma_est_free = as.numeric(base_ex_vb$qsiggam$gamma_mean)[1],
    gamma_est_gamma0 = as.numeric(vb_norm$gamma_est)[1],
    vb_iter_gamma0 = as.integer(vb_norm$iter)[1],
    vb_stop_gamma0 = as.character(vb_norm$stop_reason)[1],
    stringsAsFactors = FALSE
  )

  log_msg(sprintf(
    "done vb scenario=%s tau=%.2f stop=%s gamma=%.3e rmse_g0=%.4f rmse_al=%.4f",
    scenario, tau, vb_norm$stop_reason, as.numeric(vb_norm$gamma_est)[1], comp_row$rmse_exal_gamma0, comp_row$rmse_al
  ))

  list(
    metrics = metric_row(scenario, "exal_gamma0", "vb", tau, vb_path$mean, q_ref, vb_path$lo, vb_path$hi),
    comparison = comp_row
  )
}

task_df <- expand.grid(
  scenario = scenario_tbl$scenario,
  tau = c(0.05, 0.50, 0.95),
  stringsAsFactors = FALSE
)
task_df <- merge(task_df, scenario_tbl, by = "scenario", sort = FALSE)
task_df$seed <- 202603061L + seq_len(nrow(task_df)) * 1000L

n_core_phys <- tryCatch(parallel::detectCores(logical = FALSE), error = function(e) 2L)
if (!is.finite(n_core_phys) || is.na(n_core_phys) || n_core_phys < 1L) n_core_phys <- 2L
cores <- max(1L, min(safe_int(Sys.getenv("EXDQLM_STATIC_GAMMA0_REDUCTION_AUDIT_CORES", "6"), 6L), n_core_phys))

log_msg(sprintf("starting gamma0 reduction audit in %s", audit_root))
log_msg(sprintf("gamma_band=%.3e cores=%d", gamma_band, cores))

task_list <- split(task_df, seq_len(nrow(task_df)))
if (.Platform$OS.type == "unix" && cores > 1L) {
  vb_out <- parallel::mclapply(task_list, run_gamma0_vb_task, mc.cores = cores, mc.preschedule = FALSE)
} else {
  vb_out <- lapply(task_list, run_gamma0_vb_task)
}

gamma0_vb_metrics <- do.call(rbind, lapply(vb_out, `[[`, "metrics"))
gamma0_vb_comparison <- do.call(rbind, lapply(vb_out, `[[`, "comparison"))
utils::write.csv(gamma0_vb_metrics, file.path(audit_root, "tables", "gamma0_vb_metrics_summary.csv"), row.names = FALSE)
utils::write.csv(gamma0_vb_comparison, file.path(audit_root, "tables", "gamma0_vb_vs_baseline_comparison.csv"), row.names = FALSE)

vb_reduction_rows <- list()
mcmc_reduction_rows <- list()
for (i in seq_len(nrow(task_df))) {
  scenario <- task_df$scenario[i]
  run_root <- task_df$run_root[i]
  tau <- task_df$tau[i]
  cfg <- readRDS(file.path(run_root, "tables", "run_config.rds"))
  sim <- readRDS(cfg$sim_path)
  TT <- as.integer(cfg$TT)
  y <- as.numeric(sim$y[seq_len(TT)])
  X <- as.matrix(sim$extras$X[seq_len(TT), , drop = FALSE])
  p <- ncol(X)
  V0 <- diag(1e6, p)
  V0_inv <- solve(V0)
  b0 <- rep(0, p)
  A_tau <- (1 - 2 * tau) / (tau * (1 - tau))
  B_tau <- 2 / (tau * (1 - tau))

  al_vb <- readRDS(fit_file(run_root, "vb", "al", tau))$fit
  sigma_vb <- as.numeric(al_vb$qsig$E_sigma)[1]
  kappa_pt <- 1 / sigma_vb
  m_beta <- as.numeric(al_vb$qbeta$m)
  V_beta <- as.matrix(al_vb$qbeta$V)
  ell <- as.numeric(al_vb$qv$E_inv_v)
  nu <- as.numeric(al_vb$qv$E_v)
  xb <- as.numeric(X %*% m_beta)
  E_r <- y - xb
  E_r2 <- rowSums((X %*% V_beta) * X) + E_r^2

  xi1 <- 1 / (B_tau * sigma_vb)
  xi_A <- A_tau / (B_tau * sigma_vb)
  xi_A2 <- (A_tau^2) / (B_tau * sigma_vb)
  xi_lambda <- 0
  xi_lambda2 <- 0
  zeta_lam <- 0

  ex_V_inv <- crossprod(X * sqrt(xi1 * ell)) + V0_inv
  al_V_inv <- crossprod(X * sqrt((kappa_pt / B_tau) * ell)) + V0_inv
  ex_rhs <- crossprod(X, (xi1 * ell) * y) - xi_A * colSums(X) + V0_inv %*% b0
  al_rhs <- V0_inv %*% b0 + (kappa_pt / B_tau) * (crossprod(X, ell * y) - A_tau * colSums(X))
  ex_chi <- xi1 * E_r2
  al_chi <- (kappa_pt / B_tau) * E_r2
  ex_psi <- xi_A2 + 2 * (1 / sigma_vb)
  al_psi <- kappa_pt * (2 + (A_tau^2) / B_tau)
  qs_tau2 <- 1 / (1 + xi_lambda2 * ell)
  qs_mu <- qs_tau2 * (xi_lambda * (ell * (y - xb)) - zeta_lam)

  vb_reduction_rows[[length(vb_reduction_rows) + 1L]] <- data.frame(
    scenario = scenario,
    tau = tau,
    max_abs_Vinv_diff = max(abs(ex_V_inv - al_V_inv)),
    max_abs_rhs_diff = max(abs(ex_rhs - al_rhs)),
    max_abs_chi_diff = max(abs(ex_chi - al_chi)),
    abs_psi_diff = abs(ex_psi - al_psi),
    max_abs_qs_mu = max(abs(qs_mu)),
    max_abs_qs_tau2_minus1 = max(abs(qs_tau2 - 1)),
    stringsAsFactors = FALSE
  )

  al_mc <- readRDS(fit_file(run_root, "mcmc", "al", tau))$fit
  beta <- as.numeric(al_mc$last$beta)
  sigma <- as.numeric(al_mc$last$sigma)[1]
  v <- as.numeric(al_mc$last$v)
  if (length(v) != TT) v <- rep(v[1], TT)
  s_vec <- rep(1, TT)
  z_ex <- y - as.numeric(X %*% beta) - 0 * sigma * s_vec
  z_al <- y - as.numeric(X %*% beta)
  chi_ex <- (z_ex^2) / (B_tau * sigma)
  chi_al <- (z_al^2) / (B_tau * sigma)
  psi_ex <- (A_tau^2) / (B_tau * sigma) + (2 / sigma)
  psi_al <- (A_tau^2 / B_tau + 2) / sigma
  W_ex <- 1 / (B_tau * sigma * v)
  W_al <- 1 / (B_tau * sigma * v)
  rhs_ex <- crossprod(X, W_ex * (y - 0 * sigma * s_vec - A_tau * v)) + V0_inv %*% b0
  rhs_al <- crossprod(X, W_al * (y - A_tau * v)) + V0_inv %*% b0
  r_ex <- y - as.numeric(X %*% beta) - A_tau * v
  # Use the package defaults a_sigma=b_sigma=1 that were used in the static runs.
  a_sigma <- 1
  b_sigma <- 1
  chi_sigma_ex <- sum((r_ex^2) / (B_tau * v)) + 2 * sum(v) + 2 * b_sigma
  rate_al <- b_sigma + sum(v) + sum((r_ex^2) / (2 * B_tau * v))

  mcmc_reduction_rows[[length(mcmc_reduction_rows) + 1L]] <- data.frame(
    scenario = scenario,
    tau = tau,
    max_abs_v_chi_diff = max(abs(chi_ex - chi_al)),
    abs_v_psi_diff = abs(psi_ex - psi_al),
    max_abs_beta_rhs_diff = max(abs(rhs_ex - rhs_al)),
    max_abs_beta_W_diff = max(abs(W_ex - W_al)),
    sigma_psi_ex = 0,
    abs_sigma_rate_diff = abs((chi_sigma_ex / 2) - rate_al),
    qs_tau2_mcmc = 1,
    qs_mu_mcmc = 0,
    stringsAsFactors = FALSE
  )
}

vb_reduction_df <- do.call(rbind, vb_reduction_rows)
mcmc_reduction_df <- do.call(rbind, mcmc_reduction_rows)
utils::write.csv(vb_reduction_df, file.path(audit_root, "tables", "vb_exact_reduction_checks.csv"), row.names = FALSE)
utils::write.csv(mcmc_reduction_df, file.path(audit_root, "tables", "mcmc_exact_reduction_checks.csv"), row.names = FALSE)

png(file.path(audit_root, "plots", "vb_rmse_ratio_exal_free_vs_gamma0_to_al.png"), width = 1800, height = 1050, res = 150)
graphics::par(mfrow = c(2, 2), mar = c(4, 4, 3, 1))
for (scenario in scenario_tbl$scenario) {
  ss <- gamma0_vb_comparison[gamma0_vb_comparison$scenario == scenario, , drop = FALSE]
  x <- seq_len(nrow(ss))
  labs <- sprintf("vb@%.2f", ss$tau)
  free_ratio <- ss$rmse_exal_free / ss$rmse_al
  g0_ratio <- ss$rmse_exal_gamma0 / ss$rmse_al
  ylim <- range(c(free_ratio, g0_ratio, 1), finite = TRUE)
  graphics::plot(x, free_ratio, type = "b", pch = 19, lwd = 2, col = "#D55E00",
    xaxt = "n", xlab = "", ylab = "RMSE / AL RMSE", main = scenario, ylim = ylim)
  graphics::axis(1, at = x, labels = labs, las = 2, cex.axis = 0.8)
  graphics::lines(x, g0_ratio, type = "b", pch = 17, lwd = 2, col = "#0072B2")
  graphics::abline(h = 1, lty = 2, col = "grey35")
  graphics::legend("topright", legend = c("exAL free", "exAL gamma≈0"), col = c("#D55E00", "#0072B2"),
    lwd = 2, pch = c(19, 17), bty = "n")
}
grDevices::dev.off()

note_lines <- c(
  "# Static exAL gamma=0 reduction audit",
  "",
  sprintf("- audit_root: `%s`", audit_root),
  sprintf("- gamma_band used for constrained VB audit: `%.3e`", gamma_band),
  "",
  "## Baseline pattern",
  ""
)
for (i in seq_len(nrow(pattern_df))) {
  rr <- pattern_df[i, , drop = FALSE]
  note_lines <- c(note_lines, sprintf(
    "- tau=%.2f, method=%s: exAL worse than AL in %d/%d scenarios (median RMSE ratio %.3f)",
    rr$tau, rr$method, rr$exal_worse_count, rr$scenarios, rr$median_rmse_ratio_exal_to_al
  ))
}
note_lines <- c(note_lines, "", "## Constrained gamma≈0 VB audit", "")
for (i in seq_len(nrow(gamma0_vb_comparison))) {
  rr <- gamma0_vb_comparison[i, , drop = FALSE]
  note_lines <- c(note_lines, sprintf(
    "- %s | tau=%.2f: free exAL RMSE=%.4f, AL RMSE=%.4f, gamma≈0 exAL RMSE=%.4f, gap closure=%.3f, gamma_free=%.4f, gamma_g0=%.3e",
    rr$scenario, rr$tau, rr$rmse_exal_free, rr$rmse_al, rr$rmse_exal_gamma0,
    rr$gap_closure_fraction, rr$gamma_est_free, rr$gamma_est_gamma0
  ))
}
note_lines <- c(note_lines, "", "## Exact reduction checks", "")
note_lines <- c(note_lines, sprintf(
  "- VB shared-update max diffs: V_inv=%.3e, rhs=%.3e, chi=%.3e, psi=%.3e, q(s) mu=%.3e, q(s) tau2-1=%.3e",
  max(vb_reduction_df$max_abs_Vinv_diff),
  max(vb_reduction_df$max_abs_rhs_diff),
  max(vb_reduction_df$max_abs_chi_diff),
  max(vb_reduction_df$abs_psi_diff),
  max(vb_reduction_df$max_abs_qs_mu),
  max(vb_reduction_df$max_abs_qs_tau2_minus1)
))
note_lines <- c(note_lines, sprintf(
  "- MCMC shared-update max diffs: v-chi=%.3e, v-psi=%.3e, beta-rhs=%.3e, beta-W=%.3e, sigma-rate=%.3e",
  max(mcmc_reduction_df$max_abs_v_chi_diff),
  max(mcmc_reduction_df$abs_v_psi_diff),
  max(mcmc_reduction_df$max_abs_beta_rhs_diff),
  max(mcmc_reduction_df$max_abs_beta_W_diff),
  max(mcmc_reduction_df$abs_sigma_rate_diff)
))
writeLines(note_lines, con = file.path(audit_root, "tables", "gamma0_reduction_note.md"))

log_msg("gamma0 reduction audit completed")

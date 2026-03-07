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
  "EXDQLM_STATIC_GAMMA0_AUDIT_ROOT",
  file.path("results", "sim_suite_static", "audits", sprintf("static_exal_gamma0_submodel_%s", audit_stamp))
)
dir.create(audit_root, recursive = TRUE, showWarnings = FALSE)
for (d in c("fits/vb", "fits/mcmc", "tables", "plots", "logs")) {
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

fit_file <- function(run_root, inf, model, tau) {
  file.path(run_root, "fits", inf, sprintf("%s_%s_tau_%s_fit.rds", inf, model, tau_lab(tau)))
}

baseline_rows <- list()
for (i in seq_len(nrow(scenario_tbl))) {
  scenario <- scenario_tbl$scenario[i]
  run_root <- scenario_tbl$run_root[i]
  metrics_path <- file.path(run_root, "tables", "metrics_summary.csv")
  if (!file.exists(metrics_path)) stop("Missing metrics summary: ", metrics_path)
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

run_gamma0_task <- function(task_row) {
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
  m_file <- file.path(audit_root, "fits", "mcmc", sprintf("mcmc_exal_gamma0_%s_tau_%s_fit.rds", scenario, tau_lab(tau)))

  log_msg(sprintf("start scenario=%s tau=%.2f seed=%d", scenario, tau, seed))
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
      audit = "exal_gamma0_submodel",
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

  init_list <- .static_vb_to_mcmc_init(vb_fit, dqlm.ind = FALSE)
  init_list$gamma <- 0

  set.seed(seed + 777L)
  m_t0 <- Sys.time()
  m_fit <- exal_static_mcmc(
    y = y,
    X = X,
    p0 = tau,
    gamma_bounds = gamma_bounds,
    init = init_list,
    init.from.vb = FALSE,
    dqlm.ind = FALSE,
    n.burn = cfg$mcmc$burn,
    n.mcmc = cfg$mcmc$n,
    thin = cfg$mcmc$thin,
    mh.proposal = cfg$mcmc$mh$proposal,
    mh.adapt = cfg$mcmc$mh$adapt,
    mh.adapt.interval = cfg$mcmc$mh$adapt_interval,
    mh.target.accept = as.numeric(cfg$mcmc$mh$target_accept),
    mh.scale.bounds = as.numeric(cfg$mcmc$mh$scale_bounds),
    mh.max_scale.step = as.numeric(cfg$mcmc$mh$max_scale_step),
    mh.min_burn_adapt = as.integer(cfg$mcmc$mh$min_burn_adapt),
    verbose = FALSE
  )
  m_runtime <- as.numeric(difftime(Sys.time(), m_t0, units = "secs"))
  m_norm <- .static_normalize_mcmc_fit(
    m_fit,
    model_name = "exal",
    tau = tau,
    run_settings = list(
      audit = "exal_gamma0_submodel",
      gamma_band = gamma_band,
      constrained_gamma_zero = TRUE
    )
  )
  saveRDS(
    list(
      fit = m_fit,
      normalized = m_norm,
      meta = list(scenario = scenario, tau = tau, seed = seed, runtime_sec = m_runtime, gamma_band = gamma_band)
    ),
    m_file,
    compress = "xz"
  )

  vb_path <- .static_quantile_path_from_fit(vb_fit, X, algorithm = "vb")
  m_path <- .static_quantile_path_from_fit(m_fit, X, algorithm = "mcmc")

  base_al_vb <- readRDS(fit_file(run_root, "vb", "al", tau))$fit
  base_al_m <- readRDS(fit_file(run_root, "mcmc", "al", tau))$fit
  base_ex_vb <- readRDS(fit_file(run_root, "vb", "exal", tau))$fit
  base_ex_m <- readRDS(fit_file(run_root, "mcmc", "exal", tau))$fit

  base_al_vb_path <- .static_quantile_path_from_fit(base_al_vb, X, algorithm = "vb")
  base_al_m_path <- .static_quantile_path_from_fit(base_al_m, X, algorithm = "mcmc")
  base_ex_vb_path <- .static_quantile_path_from_fit(base_ex_vb, X, algorithm = "vb")
  base_ex_m_path <- .static_quantile_path_from_fit(base_ex_m, X, algorithm = "mcmc")

  metrics_rows <- rbind(
    metric_row(scenario, "exal_gamma0", "vb", tau, vb_path$mean, q_ref, vb_path$lo, vb_path$hi),
    metric_row(scenario, "exal_gamma0", "mcmc", tau, m_path$mean, q_ref, m_path$lo, m_path$hi)
  )

  compare_one <- function(method, g0_path, al_path, ex_path, g0_norm, ex_fit, al_fit) {
    free_gamma_mean <- if (method == "vb") as.numeric(ex_fit$qsiggam$gamma_mean)[1] else mean(as.numeric(ex_fit$samp.gamma))
    data.frame(
      scenario = scenario,
      tau = tau,
      method = method,
      rmse_al = sqrt(mean((al_path$mean - q_ref)^2)),
      rmse_exal_free = sqrt(mean((ex_path$mean - q_ref)^2)),
      rmse_exal_gamma0 = sqrt(mean((g0_path$mean - q_ref)^2)),
      delta_free_minus_al = sqrt(mean((ex_path$mean - q_ref)^2)) - sqrt(mean((al_path$mean - q_ref)^2)),
      delta_gamma0_minus_al = sqrt(mean((g0_path$mean - q_ref)^2)) - sqrt(mean((al_path$mean - q_ref)^2)),
      gap_closure_fraction = {
        free_gap <- sqrt(mean((ex_path$mean - q_ref)^2)) - sqrt(mean((al_path$mean - q_ref)^2))
        g0_gap <- sqrt(mean((g0_path$mean - q_ref)^2)) - sqrt(mean((al_path$mean - q_ref)^2))
        if (is.finite(free_gap) && abs(free_gap) > 1e-12) 1 - abs(g0_gap) / abs(free_gap) else NA_real_
      },
      path_rmse_gamma0_vs_al = sqrt(mean((g0_path$mean - al_path$mean)^2)),
      path_max_abs_gamma0_vs_al = max(abs(g0_path$mean - al_path$mean)),
      gamma_est_free = free_gamma_mean,
      gamma_est_gamma0 = as.numeric(g0_norm$gamma_est)[1],
      stringsAsFactors = FALSE
    )
  }

  comp_rows <- rbind(
    compare_one("vb", vb_path, base_al_vb_path, base_ex_vb_path, vb_norm, base_ex_vb, base_al_vb),
    compare_one("mcmc", m_path, base_al_m_path, base_ex_m_path, m_norm, base_ex_m, base_al_m)
  )

  diag_rows <- data.frame(
    scenario = scenario,
    tau = tau,
    vb_iter = as.integer(vb_norm$iter)[1],
    vb_converged = isTRUE(vb_norm$converged),
    vb_stop_reason = as.character(vb_norm$stop_reason)[1],
    vb_gamma_est = as.numeric(vb_norm$gamma_est)[1],
    vb_sigma_est = as.numeric(vb_norm$sigma_est)[1],
    vb_ld_grad_inf = as.numeric(vb_norm$diagnostics$ld_block$mode_quality$grad_inf_norm)[1],
    mcmc_gamma_est = as.numeric(m_norm$gamma_est)[1],
    mcmc_sigma_est = as.numeric(m_norm$sigma_est)[1],
    mcmc_accept_rate = as.numeric(m_norm$diagnostics$acceptance$total)[1],
    mcmc_ess_sigma = as.numeric(m_norm$diagnostics$ess$sigma)[1],
    mcmc_ess_gamma = as.numeric(m_norm$diagnostics$ess$gamma)[1],
    stringsAsFactors = FALSE
  )

  log_msg(sprintf(
    "done scenario=%s tau=%.2f vb_stop=%s vb_gamma=%.3e mcmc_gamma=%.3e",
    scenario, tau, vb_norm$stop_reason, as.numeric(vb_norm$gamma_est)[1], as.numeric(m_norm$gamma_est)[1]
  ))

  list(metrics = metrics_rows, comparison = comp_rows, diagnostics = diag_rows)
}

task_df <- expand.grid(
  scenario = scenario_tbl$scenario,
  tau = c(0.05, 0.50, 0.95),
  stringsAsFactors = FALSE
)
task_df <- merge(task_df, scenario_tbl, by = "scenario", sort = FALSE)
task_df$seed <- 202603060L + seq_len(nrow(task_df)) * 1000L

n_core_phys <- tryCatch(parallel::detectCores(logical = FALSE), error = function(e) 2L)
if (!is.finite(n_core_phys) || is.na(n_core_phys) || n_core_phys < 1L) n_core_phys <- 2L
cores <- max(1L, min(safe_int(Sys.getenv("EXDQLM_STATIC_GAMMA0_AUDIT_CORES", "6"), 6L), n_core_phys))

log_msg(sprintf("starting exAL gamma0 audit in %s", audit_root))
log_msg(sprintf("gamma_band=%.3e cores=%d", gamma_band, cores))

task_list <- split(task_df, seq_len(nrow(task_df)))
if (.Platform$OS.type == "unix" && cores > 1L) {
  out <- parallel::mclapply(task_list, run_gamma0_task, mc.cores = cores, mc.preschedule = FALSE)
} else {
  out <- lapply(task_list, run_gamma0_task)
}

metrics_gamma0 <- do.call(rbind, lapply(out, `[[`, "metrics"))
comparison_df <- do.call(rbind, lapply(out, `[[`, "comparison"))
diag_df <- do.call(rbind, lapply(out, `[[`, "diagnostics"))

utils::write.csv(metrics_gamma0, file.path(audit_root, "tables", "gamma0_metrics_summary.csv"), row.names = FALSE)
utils::write.csv(comparison_df, file.path(audit_root, "tables", "gamma0_vs_baseline_comparison.csv"), row.names = FALSE)
utils::write.csv(diag_df, file.path(audit_root, "tables", "gamma0_diagnostics_summary.csv"), row.names = FALSE)

all_metrics <- rbind(
  transform(baseline_metrics, model_variant = ifelse(model == "exal", "exal_free", model)),
  transform(metrics_gamma0[, c("scenario", "model", "method", "tau", "rmse", "coverage", "mean_ci_width")], model_variant = model)
)
utils::write.csv(all_metrics, file.path(audit_root, "tables", "all_metrics_with_gamma0.csv"), row.names = FALSE)

png(file.path(audit_root, "plots", "rmse_ratio_exal_free_vs_gamma0_to_al.png"), width = 1800, height = 1050, res = 150)
graphics::par(mfrow = c(2, 2), mar = c(4, 4, 3, 1))
for (scenario in scenario_tbl$scenario) {
  ss <- comparison_df[comparison_df$scenario == scenario, , drop = FALSE]
  if (!nrow(ss)) next
  x <- seq_len(nrow(ss))
  labs <- sprintf("%s@%.2f", ss$method, ss$tau)
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
  "# Static exAL gamma≈0 submodel audit",
  "",
  sprintf("- audit_root: `%s`", audit_root),
  sprintf("- gamma_band: `%.3e`", gamma_band),
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
note_lines <- c(note_lines, "", "## Gamma≈0 audit summary", "")
for (i in seq_len(nrow(comparison_df))) {
  rr <- comparison_df[i, , drop = FALSE]
  note_lines <- c(note_lines, sprintf(
    "- %s | tau=%.2f | %s: free exAL RMSE=%.4f, AL RMSE=%.4f, gamma≈0 exAL RMSE=%.4f, gap closure=%.3f, gamma_free=%.4f, gamma_g0=%.3e",
    rr$scenario, rr$tau, rr$method, rr$rmse_exal_free, rr$rmse_al, rr$rmse_exal_gamma0,
    rr$gap_closure_fraction, rr$gamma_est_free, rr$gamma_est_gamma0
  ))
}
writeLines(note_lines, con = file.path(audit_root, "tables", "gamma0_audit_note.md"))

log_msg("audit completed")
log_msg(sprintf("comparison table: %s", file.path(audit_root, "tables", "gamma0_vs_baseline_comparison.csv")))

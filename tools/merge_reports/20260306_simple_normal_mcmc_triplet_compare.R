#!/usr/bin/env Rscript
suppressPackageStartupMessages({
  library(pkgload)
  library(ggplot2)
  library(dplyr)
  library(tidyr)
  library(purrr)
  library(readr)
  library(coda)
  library(scales)
  library(parallel)
})

pkgload::load_all(".", quiet = TRUE, export_all = FALSE, helpers = FALSE, attach_testthat = FALSE)
pkgload::load_all("/data/muscat_data/jaguir26/bqrgal-examples/bqrgal", quiet = TRUE, export_all = FALSE, helpers = FALSE, attach_testthat = FALSE)

scenario_root <- Sys.getenv(
  "EXDQLM_COMPARE_SCENARIO_ROOT",
  unset = file.path("results", "function_testing_20260306_static_simple_linear_normal")
)
input_root <- Sys.getenv(
  "EXDQLM_COMPARE_INPUT_ROOT",
  unset = file.path(scenario_root, "fit_input_subsample_tt5000_xmain_sorted")
)
output_parent <- Sys.getenv(
  "EXDQLM_COMPARE_OUTPUT_PARENT",
  unset = scenario_root
)
scenario_title <- Sys.getenv(
  "EXDQLM_COMPARE_SCENARIO_TITLE",
  unset = "Simple Normal DGP"
)
sim <- readRDS(file.path(input_root, "sim_output.rds"))
truth_grid <- read_csv(file.path(input_root, "true_quantile_grid.csv"), show_col_types = FALSE)

taus <- c(0.05, 0.50, 0.95)
methods <- c("our_al", "our_exal_slice", "bqrgal_slice")
method_labels <- c(
  our_al = "Our AL",
  our_exal_slice = "Our exAL (slice, flat prior)",
  bqrgal_slice = "bqrgal GAL (slice)"
)
method_colors <- c(
  our_al = "#1B4D3E",
  our_exal_slice = "#B03A2E",
  bqrgal_slice = "#0E7490"
)
method_label_colors <- setNames(unname(method_colors[names(method_labels)]), unname(method_labels[names(method_labels)]))

n_burn <- 2000L
n_keep <- 1000L
n_total <- n_burn + n_keep
thin <- 1L
compare_n_raw <- Sys.getenv("EXDQLM_COMPARE_N", unset = "1000")
compare_n <- if (tolower(compare_n_raw) %in% c("full", "all", "inf")) Inf else as.integer(compare_n_raw)
compare_label <- Sys.getenv(
  "EXDQLM_COMPARE_LABEL",
  unset = if (is.finite(compare_n)) sprintf("sub%d", compare_n) else "full"
)
slice_width <- 1.0
slice_max_steps <- 100L
seed_base <- 2026030619L

existing_out_root <- Sys.getenv("EXDQLM_COMPARE_OUT_ROOT", unset = "")
if (nzchar(existing_out_root)) {
  out_root <- existing_out_root
} else {
  stamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
  out_root <- file.path(
    output_parent,
    sprintf("mcmc_triplet_compare_%s_burn%d_n%d_%s", compare_label, n_burn, n_keep, stamp)
  )
}
dir.create(out_root, recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(out_root, "fits"), showWarnings = FALSE)
dir.create(file.path(out_root, "tables"), showWarnings = FALSE)
dir.create(file.path(out_root, "plots"), showWarnings = FALSE)
dir.create(file.path(out_root, "plots", "fit"), recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(out_root, "plots", "traces"), recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(out_root, "plots", "diagnostics"), recursive = TRUE, showWarnings = FALSE)

run_config <- list(
  input_root = normalizePath(input_root),
  output_root = normalizePath(out_root),
  scenario_root = normalizePath(scenario_root),
  output_parent = normalizePath(output_parent),
  scenario_title = scenario_title,
  taus = taus,
  methods = methods,
  n_burn = n_burn,
  n_keep = n_keep,
  thin = thin,
  compare_n = compare_n,
  slice_width = slice_width,
  slice_max_steps = slice_max_steps,
  our_exal_gamma_prior = "flat_bounded_uniform_for_external_parity",
  our_exal_kernel = "slice",
  seed_base = seed_base
)
saveRDS(run_config, file.path(out_root, "tables", "run_config.rds"))

cat(sprintf("Output root: %s\n", out_root))

x_main_full <- as.numeric(sim$extras$x_main)
y_full <- as.numeric(sim$y)
X_full <- as.matrix(sim$extras$X)
compare_n_eff <- min(length(y_full), if (is.finite(compare_n)) compare_n else length(y_full))
x_idx <- unique(round(seq(1, length(y_full), length.out = compare_n_eff)))
x_idx <- x_idx[seq_len(min(compare_n_eff, length(x_idx)))]

x_main <- x_main_full[x_idx]
y <- y_full[x_idx]
X <- X_full[x_idx, , drop = FALSE]
p <- ncol(X)
stopifnot(nrow(X) == length(y), length(x_main) == length(y))

truth_lookup <- function(tau) {
  idx <- which.min(abs(sim$p - tau))
  as.numeric(sim$q[x_idx, idx])
}

bqrgal_gamma_bounds <- function(tau) {
  c(
    find_ga_lb(tau, interval = c(-50, -1e-8), extendInt = "yes"),
    find_ga_ub(tau, interval = c(1e-8, 50), extendInt = "yes")
  )
}

calc_path_summary <- function(draws, X) {
  beta_draws <- as.matrix(draws)
  q_draws <- beta_draws %*% t(X)
  list(
    mean = as.numeric(colMeans(q_draws)),
    lo = as.numeric(apply(q_draws, 2, stats::quantile, probs = 0.05, na.rm = TRUE)),
    hi = as.numeric(apply(q_draws, 2, stats::quantile, probs = 0.95, na.rm = TRUE)),
    sd = as.numeric(apply(q_draws, 2, stats::sd, na.rm = TRUE))
  )
}

extract_ours <- function(fit, tau, method) {
  beta_draws <- as.matrix(fit$samp.beta)
  sigma_draws <- as.numeric(fit$samp.sigma)
  gamma_draws <- if (!isTRUE(fit$dqlm.ind)) as.numeric(fit$samp.gamma) else numeric(0)
  s_draws <- if (!isTRUE(fit$dqlm.ind)) as.matrix(fit$samp.s) else NULL
  path <- calc_path_summary(beta_draws, X)
  s_mean_trace <- if (!is.null(s_draws)) rowMeans(s_draws) else rep(NA_real_, nrow(beta_draws))
  s_sd_trace <- if (!is.null(s_draws)) apply(s_draws, 1, stats::sd) else rep(NA_real_, nrow(beta_draws))
  list(
    path = path,
    metrics = tibble(
      method = method,
      tau = tau,
      runtime_sec = as.numeric(fit$run.time),
      sigma_mean = mean(sigma_draws),
      gamma_mean = if (length(gamma_draws)) mean(gamma_draws) else NA_real_,
      ess_beta0 = as.numeric(coda::effectiveSize(coda::as.mcmc(beta_draws[, 1]))),
      ess_beta1 = if (ncol(beta_draws) >= 2) as.numeric(coda::effectiveSize(coda::as.mcmc(beta_draws[, 2]))) else NA_real_,
      ess_sigma = as.numeric(coda::effectiveSize(coda::as.mcmc(sigma_draws))),
      ess_gamma = if (length(gamma_draws)) as.numeric(coda::effectiveSize(coda::as.mcmc(gamma_draws))) else NA_real_,
      accept_rate = if (!is.null(fit$accept.rate)) as.numeric(fit$accept.rate) else NA_real_,
      kernel = if (!is.null(fit$mh.diagnostics$proposal)) as.character(fit$mh.diagnostics$proposal) else NA_character_,
      signoff_ready = if (!is.null(fit$mh.diagnostics$signoff_ready)) isTRUE(fit$mh.diagnostics$signoff_ready) else TRUE,
      s_mean_avg = mean(s_mean_trace, na.rm = TRUE),
      s_sd_avg = mean(s_sd_trace, na.rm = TRUE)
    ),
    traces = tibble(
      iter = seq_len(nrow(beta_draws)),
      method = method,
      tau = tau,
      beta0 = beta_draws[, 1],
      beta1 = if (ncol(beta_draws) >= 2) beta_draws[, 2] else NA_real_,
      sigma = sigma_draws,
      gamma = if (length(gamma_draws)) gamma_draws else NA_real_,
      s_mean = s_mean_trace,
      s_sd = s_sd_trace
    )
  )
}

extract_bqrgal <- function(fit, tau, method) {
  beta_draws <- t(as.matrix(fit$post_sams$be))
  sigma_draws <- as.numeric(fit$post_sams$sigma)
  gamma_draws <- as.numeric(fit$post_sams$ga)
  ss_draws <- as.matrix(fit$post_sams$ss)
  if (ncol(ss_draws) != length(sigma_draws)) ss_draws <- t(ss_draws)
  if (nrow(ss_draws) == length(sigma_draws) && ncol(ss_draws) == length(y)) {
    s_mean_trace <- rowMeans(ss_draws)
    s_sd_trace <- apply(ss_draws, 1, stats::sd)
  } else {
    s_mean_trace <- colMeans(ss_draws)
    s_sd_trace <- apply(ss_draws, 2, stats::sd)
  }
  path <- calc_path_summary(beta_draws, X)
  list(
    path = path,
    metrics = tibble(
      method = method,
      tau = tau,
      runtime_sec = as.numeric(fit$runtime[["elapsed"]]),
      sigma_mean = mean(sigma_draws),
      gamma_mean = mean(gamma_draws),
      ess_beta0 = as.numeric(coda::effectiveSize(coda::as.mcmc(beta_draws[, 1]))),
      ess_beta1 = if (ncol(beta_draws) >= 2) as.numeric(coda::effectiveSize(coda::as.mcmc(beta_draws[, 2]))) else NA_real_,
      ess_sigma = as.numeric(coda::effectiveSize(coda::as.mcmc(sigma_draws))),
      ess_gamma = as.numeric(coda::effectiveSize(coda::as.mcmc(gamma_draws))),
      accept_rate = NA_real_,
      kernel = "slice",
      signoff_ready = TRUE,
      s_mean_avg = mean(s_mean_trace, na.rm = TRUE),
      s_sd_avg = mean(s_sd_trace, na.rm = TRUE)
    ),
    traces = tibble(
      iter = seq_len(nrow(beta_draws)),
      method = method,
      tau = tau,
      beta0 = beta_draws[, 1],
      beta1 = if (ncol(beta_draws) >= 2) beta_draws[, 2] else NA_real_,
      sigma = sigma_draws,
      gamma = gamma_draws,
      s_mean = s_mean_trace,
      s_sd = s_sd_trace
    )
  )
}

fit_one <- function(tau, method) {
  seed <- seed_base + round(tau * 1000) + match(method, methods) * 100L
  set.seed(seed)
  fit_path <- file.path(out_root, "fits", sprintf("%s_tau_%s.rds", method, format(tau, nsmall = 2)))
  if (file.exists(fit_path)) {
    cat(sprintf("Reusing %s at tau=%.2f\n", method, tau))
    fit <- readRDS(fit_path)
    extracted <- if (identical(method, "bqrgal_slice")) extract_bqrgal(fit, tau, method) else extract_ours(fit, tau, method)
  } else {
    cat(sprintf("Running %s at tau=%.2f\n", method, tau))

    if (identical(method, "our_al")) {
      fit <- exal_static_mcmc(
        y = y,
        X = X,
        p0 = tau,
        dqlm.ind = TRUE,
        n.burn = n_burn,
        n.mcmc = n_keep,
        thin = thin,
        trace.diagnostics = FALSE,
        verbose = FALSE
      )
      saveRDS(fit, fit_path)
      extracted <- extract_ours(fit, tau, method)
    } else if (identical(method, "our_exal_slice")) {
      fit <- exal_static_mcmc(
        y = y,
        X = X,
        p0 = tau,
        dqlm.ind = FALSE,
        n.burn = n_burn,
        n.mcmc = n_keep,
        thin = thin,
        mh.proposal = "slice",
        slice.width = slice_width,
        slice.max.steps = slice_max_steps,
        log_prior_gamma = function(g) 0,
        trace.diagnostics = FALSE,
        verbose = FALSE
      )
      saveRDS(fit, fit_path)
      extracted <- extract_ours(fit, tau, method)
    } else if (identical(method, "bqrgal_slice")) {
      bounds <- bqrgal_gamma_bounds(tau)
      fit <- bgal(
        resp = y,
        covars = X,
        prob = tau,
        beta_prior = "gaussian",
        priors = list(
          beta_gaus = list(mean_vec = rep(0, ncol(X)), var_mat = diag(1e6, ncol(X))),
          sigma_invgamma = c(1, 1),
          ga_uniform = bounds
        ),
        starting = list(
          ga = 0,
          sigma = 1,
          vv = rep(1, length(y)),
          ss = abs(stats::rnorm(length(y))),
          omega = NULL
        ),
        tuning = list(step_size = slice_width),
        mcmc_settings = list(n_iter = n_total, n_burn = n_burn, n_thin = thin, n_report = 1000),
        ga_sampler = "slice",
        verbose = FALSE
      )
      saveRDS(fit, fit_path)
      extracted <- extract_bqrgal(fit, tau, method)
    } else {
      stop("Unknown method: ", method)
    }
  }

  truth <- truth_lookup(tau)
  metrics <- extracted$metrics %>%
    mutate(
      rmse = sqrt(mean((extracted$path$mean - truth)^2)),
      mae = mean(abs(extracted$path$mean - truth)),
      bias = mean(extracted$path$mean - truth),
      cor_truth = suppressWarnings(stats::cor(extracted$path$mean, truth))
    )

  cat(sprintf("Completed %s at tau=%.2f\n", method, tau))

  path_df <- tibble(
    idx = seq_along(y),
    x_main = x_main,
    y = y,
    truth = truth,
    fit_mean = extracted$path$mean,
    fit_lo = extracted$path$lo,
    fit_hi = extracted$path$hi,
    tau = tau,
    method = method
  )

  list(metrics = metrics, traces = extracted$traces, path = path_df)
}

fit_tau_bundle <- function(tau) {
  out <- list()
  for (method in methods) {
    key <- sprintf("%s_tau_%s", method, format(tau, nsmall = 2))
    out[[key]] <- fit_one(tau, method)
    gc(verbose = FALSE)
  }
  out
}

mc_cores <- min(length(taus), max(1L, parallel::detectCores(logical = FALSE)))
cat(sprintf("Running tau bundles in parallel with %d workers\n", mc_cores))
results_nested <- parallel::mclapply(taus, fit_tau_bundle, mc.cores = mc_cores)
results <- unlist(results_nested, recursive = FALSE)

metrics_tbl <- bind_rows(lapply(results, `[[`, "metrics")) %>%
  mutate(method_label = recode(method, !!!method_labels)) %>%
  arrange(tau, rmse)
traces_tbl <- bind_rows(lapply(results, `[[`, "traces")) %>%
  mutate(method_label = recode(method, !!!method_labels))
path_tbl <- bind_rows(lapply(results, `[[`, "path")) %>%
  mutate(method_label = recode(method, !!!method_labels))

write_csv(metrics_tbl, file.path(out_root, "tables", "metrics_summary.csv"))
write_csv(traces_tbl, file.path(out_root, "tables", "trace_summary_long.csv"))
write_csv(path_tbl, file.path(out_root, "tables", "fit_path_summary_long.csv"))

ranking_tbl <- metrics_tbl %>%
  group_by(tau) %>%
  arrange(rmse, .by_group = TRUE) %>%
  mutate(rank = row_number()) %>%
  ungroup()
write_csv(ranking_tbl, file.path(out_root, "tables", "method_ranking_by_tau.csv"))

winner_tbl <- ranking_tbl %>%
  filter(rank == 1L) %>%
  transmute(tau, winner = method_label, rmse, mae, bias, cor_truth)
write_csv(winner_tbl, file.path(out_root, "tables", "winner_summary.csv"))

points_df <- tibble(x_main = x_main, y = y)
if (nrow(points_df) > 2000L) {
  points_df <- dplyr::slice_sample(points_df, n = 2000L)
}

for (tau in taus) {
  tau_paths <- path_tbl %>%
    filter(abs(tau - !!tau) < 1e-12) %>%
    arrange(x_main)

  fit_plot <- ggplot() +
    geom_point(data = points_df, aes(x = x_main, y = y), color = "grey40", alpha = 0.18, size = 0.7) +
    geom_line(data = tau_paths %>% distinct(x_main, truth), aes(x = x_main, y = truth), color = "black", linewidth = 1.1, linetype = "22") +
    geom_line(data = tau_paths, aes(x = x_main, y = fit_mean, color = method_label), linewidth = 0.95) +
    scale_color_manual(values = method_label_colors, guide = guide_legend(title = NULL)) +
    labs(
      title = sprintf("%s: MCMC Fit Comparison at tau = %.2f", scenario_title, tau),
      subtitle = "Point cloud with exact quantile truth and posterior mean fitted quantiles",
      x = "x",
      y = "y"
    ) +
    theme_minimal(base_size = 12) +
    theme(legend.position = "bottom")

  ggsave(
    filename = file.path(out_root, "plots", "fit", sprintf("fit_compare_tau_%s.png", format(tau, nsmall = 2))),
    plot = fit_plot,
    width = 9,
    height = 5.5,
    dpi = 180
  )

  tau_traces <- traces_tbl %>% filter(abs(tau - !!tau) < 1e-12)
  trace_specs <- list(
    list(var = "beta0", title = sprintf("beta0 traces at tau = %.2f", tau), methods = methods),
    list(var = "beta1", title = sprintf("beta1 traces at tau = %.2f", tau), methods = methods),
    list(var = "sigma", title = sprintf("sigma traces at tau = %.2f", tau), methods = methods),
    list(var = "gamma", title = sprintf("gamma traces at tau = %.2f", tau), methods = c("our_exal_slice", "bqrgal_slice")),
    list(var = "s_mean", title = sprintf("mean(s) traces at tau = %.2f", tau), methods = c("our_exal_slice", "bqrgal_slice"))
  )

  for (spec in trace_specs) {
    plot_dat <- tau_traces %>%
      filter(method %in% spec$methods) %>%
      mutate(value = .data[[spec$var]]) %>%
      filter(is.finite(value))
    if (!nrow(plot_dat)) next
    p_trace <- ggplot(plot_dat, aes(x = iter, y = value, color = method_label)) +
      geom_line(alpha = 0.8, linewidth = 0.35) +
      scale_color_manual(values = method_label_colors, guide = guide_legend(title = NULL)) +
      labs(title = spec$title, x = "Saved draw", y = spec$var) +
      theme_minimal(base_size = 12) +
      theme(legend.position = "bottom")
    ggsave(
      filename = file.path(out_root, "plots", "traces", sprintf("trace_%s_tau_%s.png", spec$var, format(tau, nsmall = 2))),
      plot = p_trace,
      width = 9,
      height = 4.8,
      dpi = 180
    )
  }
}

rmse_plot <- metrics_tbl %>%
  mutate(tau = factor(sprintf("%.2f", tau), levels = sprintf("%.2f", taus))) %>%
ggplot(aes(x = tau, y = rmse, fill = method_label)) +
  geom_col(position = position_dodge(width = 0.7), width = 0.62) +
  scale_fill_manual(values = method_label_colors, guide = guide_legend(title = NULL)) +
  labs(title = "RMSE by tau and method", x = "tau", y = "RMSE") +
  theme_minimal(base_size = 12) +
  theme(legend.position = "bottom")

ggsave(
  filename = file.path(out_root, "plots", "diagnostics", "rmse_by_tau.png"),
  plot = rmse_plot,
  width = 8.5,
  height = 4.8,
  dpi = 180
)

gamma_plot <- metrics_tbl %>%
  filter(method != "our_al") %>%
  mutate(tau = factor(sprintf("%.2f", tau), levels = sprintf("%.2f", taus))) %>%
ggplot(aes(x = tau, y = gamma_mean, fill = method_label)) +
  geom_col(position = position_dodge(width = 0.7), width = 0.62) +
  scale_fill_manual(values = method_label_colors, guide = guide_legend(title = NULL)) +
  labs(title = "Posterior mean gamma by tau", x = "tau", y = "Posterior mean gamma") +
  theme_minimal(base_size = 12) +
  theme(legend.position = "bottom")

ggsave(
  filename = file.path(out_root, "plots", "diagnostics", "gamma_mean_by_tau.png"),
  plot = gamma_plot,
  width = 8.5,
  height = 4.8,
  dpi = 180
)

summary_lines <- c(
  sprintf("# %s MCMC Comparison", scenario_title),
  "",
  sprintf("Input root: `%s`", normalizePath(input_root)),
  sprintf("Output root: `%s`", normalizePath(out_root)),
  sprintf("MCMC settings: burn=%d, keep=%d, thin=%d", n_burn, n_keep, thin),
  "External parity note: our exAL used a flat bounded gamma prior in this comparison to match bqrgal's default.",
  "",
  "## Winner by tau",
  ""
)
summary_lines <- c(summary_lines, capture.output(print(winner_tbl, n = nrow(winner_tbl))))
summary_lines <- c(summary_lines, "", "## Metrics summary", "")
summary_lines <- c(summary_lines, capture.output(print(metrics_tbl %>% select(method_label, tau, rmse, mae, bias, cor_truth, ess_sigma, ess_gamma, gamma_mean), n = nrow(metrics_tbl))))
writeLines(summary_lines, file.path(out_root, "tables", "report_summary.md"))

cat("Completed comparison run.\n")
cat(sprintf("Results written to %s\n", out_root))

# scripts/esn_quantile_main.R
# Standalone main for ESN quantile pipeline (fit → forecast → synthesis → diagnostics)
# Reads configuration from EXDQLM_* environment variables set by scripts/run_one.R

suppressPackageStartupMessages({
  req <- c("devtools","ggplot2","dplyr","tidyr","tibble","scales",
           "MASS","numDeriv","matrixStats","purrr","readr","patchwork","jsonlite")
  need <- setdiff(req, rownames(installed.packages()))
  if (length(need)) install.packages(need, repos="https://cloud.r-project.org", dependencies = TRUE)
  invisible(lapply(req, require, character.only = TRUE))
})

# --- repo root (works from anywhere in repo)
repo_root <- tryCatch(
  normalizePath(system("git rev-parse --show-toplevel", intern = TRUE)),
  error = function(...) normalizePath(".", mustWork = TRUE)
)
devtools::load_all(repo_root)
set.seed(12345)

# --- Batch-run overrides from runner (file paths, outputs, full YAML cfg)
file_long <- Sys.getenv("EXDQLM_FILE_LONG", unset = NA)
out_dir   <- Sys.getenv("EXDQLM_OUT_DIR",   unset = NA)
save_outputs <- if (!is.na(Sys.getenv("EXDQLM_SAVE_OUTPUTS", unset = NA)))
  as.integer(Sys.getenv("EXDQLM_SAVE_OUTPUTS")) == 1L else TRUE

if (is.na(file_long) || !file.exists(file_long)) {
  stop("EXDQLM_FILE_LONG not set or file missing: ", file_long)
}
if (is.na(out_dir) || !nzchar(out_dir)) {
  out_dir <- file.path(dirname(file_long), "fig_esn_quantile_main")
}
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

cfg_json <- Sys.getenv("EXDQLM_CFG_JSON", unset = NA)
cfg <- if (!is.na(cfg_json) && nzchar(cfg_json)) jsonlite::fromJSON(cfg_json, simplifyVector = TRUE) else list()

`%nz%` <- function(x, alt) if (!is.null(x)) x else alt
near_equal <- function(x, y, tol = 1e-8) abs(x - y) <= tol

# --- Defaults (will be overridden by cfg when present)
p_vec <- c(0.05, 0.50, 0.95)

desn_args <- list(
  D = 1L, n = c(800L), n_tilde = integer(0), m = 50L,
  alpha = 0.2, rho = c(0.95), act_f = "tanh", act_k = "identity",
  pi_w = 0.05, pi_in = 1.00, washout = 500L, add_bias = TRUE, seed = 42
)

vb_args_base <- list(max_iter = 150, tol = 1e-4, n_samp_xi = 500, verbose = TRUE)
vb_tol_for <- function(p0) if (near_equal(p0, 0.50)) 1e-4 else 1e-5

nd_draws  <- 3000L
chunk_sz  <- 250L
last_window <- 200L

synth_isotonic  <- TRUE
synth_rearrange <- TRUE
synth_grid_M    <- 2001L
synth_nsamp     <- 4000L
synth_seed      <- 123L

rolling_origin <- TRUE
H_step         <- 1L
tf_enable      <- TRUE
tf_first_k     <- desn_args$m
y_future_obs_explicit <- NULL

# --- Apply cfg overrides (if present)
if (length(cfg)) {
  if (!is.null(cfg$p_vec))             p_vec <- as.numeric(cfg$p_vec)

  if (!is.null(cfg$desn)) {
    desn_args$D        <- cfg$desn$D        %nz% desn_args$D
    desn_args$n        <- if (!is.null(cfg$desn$n))       as.integer(cfg$desn$n)       else desn_args$n
    desn_args$n_tilde  <- if (!is.null(cfg$desn$n_tilde)) as.integer(cfg$desn$n_tilde) else desn_args$n_tilde
    desn_args$m        <- cfg$desn$m        %nz% desn_args$m
    desn_args$alpha    <- cfg$desn$alpha    %nz% desn_args$alpha
    desn_args$rho      <- if (!is.null(cfg$desn$rho))     as.numeric(cfg$desn$rho)     else desn_args$rho
    desn_args$act_f    <- cfg$desn$act_f    %nz% desn_args$act_f
    desn_args$act_k    <- cfg$desn$act_k    %nz% desn_args$act_k
    desn_args$pi_w     <- cfg$desn$pi_w     %nz% desn_args$pi_w
    desn_args$pi_in    <- cfg$desn$pi_in    %nz% desn_args$pi_in
    desn_args$washout  <- cfg$desn$washout  %nz% desn_args$washout
    desn_args$add_bias <- cfg$desn$add_bias %nz% desn_args$add_bias
    desn_args$seed     <- cfg$desn$seed     %nz% desn_args$seed
  }

  if (!is.null(cfg$vb)) {
    vb_args_base$max_iter  <- cfg$vb$max_iter  %nz% vb_args_base$max_iter
    vb_args_base$n_samp_xi <- cfg$vb$n_samp_xi %nz% vb_args_base$n_samp_xi
    tol50  <- cfg$vb$tol_50      %nz% 1e-4
    tolext <- cfg$vb$tol_extreme %nz% 1e-5
    vb_tol_for <- function(p0) if (abs(p0 - 0.50) < 1e-12) tol50 else tolext
  }

  if (!is.null(cfg$sampling)) {
    nd_draws <- cfg$sampling$nd_draws %nz% nd_draws
    chunk_sz <- cfg$sampling$chunk    %nz% chunk_sz
  }

  if (!is.null(cfg$forecast)) {
    last_window    <- cfg$forecast$last_window    %nz% last_window
    rolling_origin <- cfg$forecast$rolling_origin %nz% rolling_origin
    H_step         <- cfg$forecast$H_step         %nz% H_step
  }

  if (!is.null(cfg$synthesis)) {
    synth_isotonic  <- cfg$synthesis$isotonic  %nz% synth_isotonic
    synth_rearrange <- cfg$synthesis$rearrange %nz% synth_rearrange
    synth_grid_M    <- cfg$synthesis$grid_M    %nz% synth_grid_M
    synth_nsamp     <- cfg$synthesis$n_samp    %nz% synth_nsamp
    synth_seed      <- cfg$synthesis$seed      %nz% synth_seed
  }
}

# --- Plot helpers (same as notebook)
fmt_p <- function(x) sprintf("%.3f", as.numeric(x))
col_map <- setNames(c("#ef4444", "#10b981", "#0ea5e9"), as.character(p_vec))
theme_exdqlm <- function(base_size = 11) {
  ggplot2::theme_minimal(base_size = base_size) +
    ggplot2::theme(panel.grid.minor = ggplot2::element_blank(), legend.position="right",
                   plot.title=ggplot2::element_text(face="bold"))
}
caption_exdqlm <- function(window) sprintf("window: last %d steps • ndraws: %d", as.integer(window), as.integer(nd_draws))
band_from_draws <- function(mat, level = 0.95) {
  probs <- c((1 - level)/2, 0.5, (1 + level)/2)
  qs <- t(apply(mat, 1, stats::quantile, probs = probs, names = FALSE))
  colnames(qs) <- c("lo","med","hi"); qs
}
true_q_at_tau <- function(dat_long, tau) {
  dat_long %>%
    dplyr::arrange(t, p) %>%
    dplyr::group_by(t) %>%
    dplyr::summarise(
      q_tau = {
        p_i <- as.numeric(p); q_i <- as.numeric(q); ord <- order(p_i)
        approx(x = p_i[ord], y = q_i[ord], xout = tau, method = "linear", rule = 2)$y
      },
      .groups = "drop"
    ) %>% dplyr::arrange(t) %>% dplyr::pull(q_tau)
}

plot_mu_band <- function(df, p0, scope = "Forecast", window = 200L) {
  i2 <- max(df$h); i1 <- max(1L, i2 - window + 1L); d <- dplyr::filter(df, dplyr::between(h, i1, i2))
  coverage <- mean(d$q_true >= d$lo & d$q_true <= d$hi, na.rm = TRUE)
  ggplot2::ggplot(d, ggplot2::aes(x = h)) + theme_exdqlm() +
    ggplot2::labs(title=sprintf("%s: μ̂ ±95%% vs true qₚ (p=%s)", scope, scales::percent(p0,1)),
                  subtitle=sprintf("q_true-in-band = %s", scales::percent(coverage,0.1)),
                  caption=caption_exdqlm(window), x="time", y="value") +
    ggplot2::geom_ribbon(ggplot2::aes(ymin=lo, ymax=hi),
                         fill=scales::alpha(col_map[as.character(p0)],0.22), colour=NA) +
    ggplot2::geom_line(ggplot2::aes(y = mu,     colour = "mu"),   linewidth=0.95) +
    ggplot2::geom_line(ggplot2::aes(y = q_true, colour = "true"), linewidth=0.9, linetype=2) +
    ggplot2::geom_line(ggplot2::aes(y = y,      colour = "data"), linewidth=0.6, alpha=0.9) +
    ggplot2::scale_color_manual(name="", values=c(mu=col_map[as.character(p0)], true="#7c3aed", data="#6b7280"))
}

plot_empirical_quantile <- function(df, p0, scope = "Forecast", window = 200L) {
  i2 <- max(df$h); i1 <- max(1L, i2 - window + 1L); d <- dplyr::filter(df, dplyr::between(h, i1, i2))
  mae <- mean(abs(d$q_pred - d$q_true), na.rm = TRUE)
  ggplot2::ggplot(d, ggplot2::aes(x = h)) + theme_exdqlm() +
    ggplot2::labs(title=sprintf("%s: q̂ₚ vs true qₚ (p=%s)", scope, scales::percent(p0,1)),
                  subtitle=sprintf("MAE = %.3f", mae), caption=caption_exdqlm(window),
                  x="time", y="value") +
    ggplot2::geom_line(ggplot2::aes(y = q_pred, colour = "pred"), linewidth=0.95) +
    ggplot2::geom_line(ggplot2::aes(y = q_true, colour = "true"), linewidth=0.9, linetype=2) +
    ggplot2::geom_line(ggplot2::aes(y = y,      colour = "data"), linewidth=0.6, alpha=0.85) +
    ggplot2::scale_color_manual(name="", values=c(pred=col_map[as.character(p0)], true="#7c3aed", data="#6b7280"))
}

plot_synth_q_vs_true <- function(df_s, tau, scope = "Forecast", window = 200L) {
  tau_lab <- fmt_p(tau); c_true <- paste0("true_q_", tau_lab); c_synth <- paste0("synth_q_", tau_lab)
  i2 <- max(df_s$h); i1 <- max(1L, i2 - window + 1L); d <- dplyr::filter(df_s, dplyr::between(h, i1, i2))
  mae <- mean(abs(d[[c_synth]] - d[[c_true]]), na.rm = TRUE)
  ggplot2::ggplot(d, ggplot2::aes(x = h)) + theme_exdqlm() +
    ggplot2::labs(title=sprintf("%s: synthesized qₚ vs true qₚ (p=%s)", scope, scales::percent(as.numeric(tau),1)),
                  subtitle=sprintf("MAE = %.3f", mae), caption=caption_exdqlm(window), x="time", y="value") +
    ggplot2::geom_line(ggplot2::aes(y = .data[[c_synth]], colour = "synth"), linewidth=0.95) +
    ggplot2::geom_line(ggplot2::aes(y = .data[[c_true]],  colour = "true"),  linewidth=0.9, linetype=2) +
    ggplot2::geom_line(ggplot2::aes(y = y,                 colour = "data"),  linewidth=0.6, alpha=0.85) +
    ggplot2::scale_color_manual(name="", values=c(synth="#0ea5e9", true="#7c3aed", data="#6b7280"))
}

plot_synth_predictive_band <- function(synth_draws, y_vec, scope="Forecast", window=50L, fill_col="#0ea5e9", show_median=TRUE) {
  stopifnot(is.matrix(synth_draws), length(y_vec) == nrow(synth_draws))
  T_h <- nrow(synth_draws); i2 <- T_h; i1 <- max(1L, i2 - as.integer(window) + 1L)
  q_mat <- t(apply(synth_draws, 1L, stats::quantile, probs = c(0.025, 0.50, 0.975), names = FALSE))
  colnames(q_mat) <- c("q05","q50","q95")
  df <- tibble::tibble(h=seq_len(T_h), y=y_vec, q05=q_mat[,"q05"], q50=q_mat[,"q50"], q95=q_mat[,"q95"]) |>
    dplyr::filter(dplyr::between(h, i1, i2))
  coverage <- mean(df$y >= df$q05 & df$y <= df$q95, na.rm = TRUE)
  mean_w   <- mean(df$q95 - df$q05, na.rm = TRUE)
  ggplot2::ggplot(df, ggplot2::aes(x = h)) + theme_exdqlm() +
    ggplot2::labs(title=sprintf("%s: synthesized 95%% predictive band", scope),
                  subtitle=paste(sprintf("coverage=%s", scales::percent(coverage,0.1)), sprintf("mean width=%.3f", mean_w), sep=" • "),
                  caption=caption_exdqlm(window), x="time", y="value") +
    ggplot2::geom_ribbon(ggplot2::aes(ymin = q05, ymax = q95), fill=scales::alpha(fill_col,0.22), colour=NA) +
    { if (isTRUE(show_median)) ggplot2::geom_line(ggplot2::aes(y=q50, colour="median"), linewidth=0.8) else ggplot2::geom_blank() } +
    ggplot2::geom_line(ggplot2::aes(y=y, colour="data"), linewidth=0.75) +
    ggplot2::scale_color_manual(name="", breaks=c("data","median"), values=c(data="#6b7280", median=fill_col))
}

# --- 1) Load data + split
dat_long <- read.csv(file_long) |>
  tibble::as_tibble() |>
  dplyr::mutate(t=as.integer(t), p=as.numeric(p), q=as.numeric(q), y=as.numeric(y), mu=as.numeric(mu)) |>
  dplyr::arrange(t, p)

y_full_all <- dat_long |> dplyr::distinct(t, y) |> dplyr::arrange(t)
T_full <- nrow(y_full_all)
T_use  <- T_full
y_full <- y_full_all

n_train    <- max(1L, floor(0.9 * T_use))
H_forecast <- T_use - n_train
idx_tr <- 1:n_train
idx_fc <- (n_train + 1):T_use
y_train    <- y_full$y[idx_tr]
y_forecast <- y_full$y[idx_fc]

y_future_obs_fc <- {
  if (!isTRUE(tf_enable)) rep(NA_real_, H_forecast)
  else if (!is.null(y_future_obs_explicit)) as.numeric(y_future_obs_explicit)
  else if (is.null(tf_first_k)) as.numeric(y_forecast)
  else { k <- max(0L, min(as.integer(tf_first_k), H_forecast)); vec <- rep(NA_real_, H_forecast); if (k > 0L) vec[seq_len(k)] <- y_forecast[seq_len(k)]; vec }
}

# --- 2) Fit & Forecast per p
fit_and_forecast_p <- function(p0) {
  vb_args_p <- vb_args_base; vb_args_p$tol <- vb_tol_for(p0)
  fit_tr <- do.call(qdesn_fit_vb, c(list(y = y_train, p0 = p0, vb_args = vb_args_p), desn_args))
  m_lag <- as.integer(fit_tr$meta$m)

  if (!isTRUE(rolling_origin)) {
    y_hist <- if (m_lag > 0L) tail(y_train, m_lag) else numeric(0)
    fc <- forecast_paths.qdesn_fit(object=fit_tr, H=H_forecast, nd=nd_draws, method="recursive",
                                   y_hist=y_hist, y_future_obs=y_future_obs_fc, chunk=chunk_sz)
    yrep_fc     <- fc$yrep
    mu_draws_fc <- fc$mu_draws
  } else {
    yrep_ro_list     <- replicate(H_step, matrix(NA_real_, H_forecast, nd_draws), simplify = FALSE)
    mu_draws_ro_list <- replicate(H_step, matrix(NA_real_, H_forecast, nd_draws), simplify = FALSE)
    for (o in 0:(H_forecast - 1L)) {
      H_o <- min(H_step, H_forecast - o)
      idx_end <- n_train + o
      y_hist_o <- if (m_lag > 0L) tail(y_full$y[seq_len(idx_end)], m_lag) else numeric(0)
      yfo <- rep(NA_real_, H_o)
      fc_o <- forecast_paths.qdesn_fit(object=fit_tr, H=H_o, nd=nd_draws, method="recursive",
                                       y_hist=y_hist_o, y_future_obs=yfo, chunk=chunk_sz)
      for (s in 1:H_o) {
        yrep_ro_list[[s]][o + 1L, ]     <- fc_o$yrep[s, ]
        mu_draws_ro_list[[s]][o + 1L, ] <- fc_o$mu_draws[s, ]
      }
    }
    yrep_fc     <- yrep_ro_list[[1L]]
    mu_draws_fc <- mu_draws_ro_list[[1L]]
  }

  q_pred_fc <- apply(yrep_fc, 1, stats::quantile, probs = p0, names = FALSE)
  mu_qs_fc  <- band_from_draws(mu_draws_fc, level = 0.95)
  q_true_fc <- true_q_at_tau(dat_long, tau = p0)[idx_fc]

  df_mu_fc <- tibble::tibble(
    h = seq_len(H_forecast), p0 = p0,
    mu = mu_qs_fc[, "med"], lo = mu_qs_fc[, "lo"], hi = mu_qs_fc[, "hi"],
    q_true = q_true_fc, y = y_forecast
  )
  df_pred_fc <- tibble::tibble(
    h = seq_len(H_forecast), p0 = p0,
    q_pred = q_pred_fc, q_true = q_true_fc, y = y_forecast
  )

  # In-sample (post-washout) checks
  pp_tr <- posterior_predict.qdesn_fit(fit_tr, nd = nd_draws, chunk = chunk_sz)
  yrep_tr     <- pp_tr$yrep
  mu_draws_tr <- pp_tr$mu_draws
  keep        <- fit_tr$meta$keep_idx
  q_true_tr   <- true_q_at_tau(dat_long, tau = p0)[keep]
  mu_qs_tr    <- band_from_draws(mu_draws_tr, level = 0.95)
  df_mu_tr <- tibble::tibble(h = seq_along(keep), p0 = p0,
                             mu=mu_qs_tr[,"med"], lo=mu_qs_tr[,"lo"], hi=mu_qs_tr[,"hi"],
                             q_true=q_true_tr, y=y_train[keep])
  df_pred_tr <- tibble::tibble(h = seq_along(keep), p0 = p0,
                               q_pred = apply(yrep_tr, 1, stats::quantile, probs=p0, names=FALSE),
                               q_true = q_true_tr, y = y_train[keep])

  list(
    fit_train = fit_tr,
    yrep_fc = yrep_fc, mu_draws_fc = mu_draws_fc,
    df_mu_fc = df_mu_fc, df_pred_fc = df_pred_fc,
    yrep_tr = yrep_tr, mu_draws_tr = mu_draws_tr,
    df_mu_tr = df_mu_tr, df_pred_tr = df_pred_tr
  )
}

fits_fc <- lapply(p_vec, fit_and_forecast_p)
names(fits_fc) <- paste0("p=", p_vec)

# --- 3) Per-p forecast plots
for (k in seq_along(p_vec)) {
  p0 <- p_vec[k]
  g1 <- plot_mu_band(fits_fc[[k]]$df_mu_fc, p0, scope="Forecast", window=last_window)
  g2 <- plot_empirical_quantile(fits_fc[[k]]$df_pred_fc, p0, scope="Forecast", window=last_window)
  print(g1); print(g2)
  if (isTRUE(save_outputs)) {
    ggsave(file.path(out_dir, sprintf("forecast_mu_band_p=%s.png", as.character(p0))), g1, width=9, height=4.8, dpi=150)
    ggsave(file.path(out_dir, sprintf("forecast_emp_q_vs_true_p=%s.png", as.character(p0))), g2, width=9, height=4.8, dpi=150)
  }
}

# --- 4) ELBO traces
k_burn <- 20
elbo_df <- dplyr::bind_rows(lapply(seq_along(fits_fc), function(i) {
  tr <- fits_fc[[i]]$fit_train$fit$misc$elbo
  if (is.null(tr) || !length(tr)) return(tibble::tibble())
  tibble::tibble(p0 = p_vec[i], iter = seq_along(tr), elbo = as.numeric(tr))
}))
if (nrow(elbo_df)) {
  elbo_df <- elbo_df |> dplyr::filter(iter > k_burn) |> dplyr::mutate(p0_chr = factor(sprintf("%.2f", p0)))
  g_elbo <- ggplot2::ggplot(elbo_df, ggplot2::aes(x = iter, y = elbo, colour = p0_chr)) +
    theme_exdqlm() + ggplot2::labs(x="VB iteration", y="ELBO", colour="p0",
    title="ELBO traces across quantile models", subtitle=sprintf("First k=%d iterations omitted", k_burn)) +
    ggplot2::geom_line(linewidth=0.8, alpha=0.95) + ggplot2::scale_color_manual(values = setNames(col_map, sprintf("%.2f", p_vec)))
  print(g_elbo)
  if (isTRUE(save_outputs)) ggsave(file.path(out_dir, sprintf("elbo_traces_skip_k=%d.png", k_burn)), g_elbo, width=9, height=4.8, dpi=150)
}

# --- 5) Synthesis (forecast + train)
draws_list_fc <- lapply(fits_fc, function(obj) obj$yrep_fc)
synth_fc <- exdqlm_synthesize_from_draws(
  draws_list = draws_list_fc, p = p_vec,
  enforce_isotonic = synth_isotonic, rearrange = synth_rearrange,
  grid_M = synth_grid_M, n_samp = synth_nsamp, seed = synth_seed, T_expected = H_forecast
)

p_comp <- c(0.05, 0.50, 0.95)
synth_cols_fc <- lapply(p_comp, function(tau) apply(synth_fc$draws, 1L, stats::quantile, probs = tau, names = FALSE))
names(synth_cols_fc) <- paste0("synth_q_", fmt_p(p_comp))
synth_q_fc <- tibble::as_tibble(synth_cols_fc)

true_cols_fc <- setNames(vector("list", length(p_comp)), paste0("true_q_", fmt_p(p_comp)))
for (i in seq_along(p_comp)) true_cols_fc[[i]] <- true_q_at_tau(dat_long, tau = p_comp[i])[idx_fc]
true_q_fc <- tibble::as_tibble(true_cols_fc)

compare_fc <- tibble::tibble(h = seq_len(H_forecast), y = y_forecast) |>
  dplyr::bind_cols(true_q_fc) |>
  dplyr::bind_cols(synth_q_fc)

plots_synth_fc <- lapply(p_comp, function(tau) plot_synth_q_vs_true(compare_fc, tau, scope="Forecast", window=last_window))
for (j in seq_along(plots_synth_fc)) {
  print(plots_synth_fc[[j]])
  if (isTRUE(save_outputs)) ggsave(file.path(out_dir, sprintf("forecast_synth_vs_true_p=%s.png", fmt_p(p_comp[j]))),
                                   plots_synth_fc[[j]], width=9, height=4.8, dpi=150)
}

g_band_fc <- plot_synth_predictive_band(synth_draws = synth_fc$draws, y_vec = y_forecast,
                                        scope="Forecast", window=last_window, fill_col="#3B82F6", show_median=TRUE)
print(g_band_fc)
if (isTRUE(save_outputs)) ggsave(file.path(out_dir, "forecast_obs_with_95_band.png"), g_band_fc, width=9, height=4.8, dpi=150)

# Train synthesis (for completeness)
draws_list_tr <- lapply(fits_fc, function(obj) obj$yrep_tr)
T_train_keep  <- nrow(draws_list_tr[[1]])
keep_train    <- fits_fc[[1]]$fit_train$meta$keep_idx
synth_tr <- exdqlm_synthesize_from_draws(
  draws_list = draws_list_tr, p = p_vec,
  enforce_isotonic = synth_isotonic, rearrange = synth_rearrange,
  grid_M = synth_grid_M, n_samp = synth_nsamp, seed = synth_seed, T_expected = T_train_keep
)

synth_cols_tr <- lapply(p_comp, function(tau) apply(synth_tr$draws, 1L, stats::quantile, probs = tau, names = FALSE))
names(synth_cols_tr) <- paste0("synth_q_", fmt_p(p_comp))
synth_q_tr <- tibble::as_tibble(synth_cols_tr)

true_cols_tr <- setNames(vector("list", length(p_comp)), paste0("true_q_", fmt_p(p_comp)))
for (i in seq_along(p_comp)) true_cols_tr[[i]] <- true_q_at_tau(dat_long, tau = p_comp[i])[keep_train]
true_q_tr <- tibble::as_tibble(true_cols_tr)

compare_tr <- tibble::tibble(h = seq_len(T_train_keep), y = y_train[keep_train]) |>
  dplyr::bind_cols(true_q_tr) |>
  dplyr::bind_cols(synth_q_tr)

plots_synth_tr <- lapply(p_comp, function(tau) plot_synth_q_vs_true(compare_tr, tau, scope="Train", window=200L))
for (j in seq_along(plots_synth_tr)) {
  print(plots_synth_tr[[j]])
  if (isTRUE(save_outputs)) ggsave(file.path(out_dir, sprintf("train_synth_vs_true_p=%s.png", fmt_p(p_comp[j]))),
                                   plots_synth_tr[[j]], width=9, height=4.8, dpi=150)
}

g_band_tr <- plot_synth_predictive_band(synth_draws = synth_tr$draws, y_vec = y_train[keep_train],
                                        scope="Train", window=200L, fill_col="#0ea5e9", show_median=TRUE)
print(g_band_tr)
if (isTRUE(save_outputs)) ggsave(file.path(out_dir, "train_obs_with_95_band.png"), g_band_tr, width=9, height=4.8, dpi=150)

# --- 6) Save core objects
if (isTRUE(save_outputs)) {
  saveRDS(
    list(
      fits_fc = fits_fc, synth_fc = synth_fc, compare_fc = compare_fc,
      cfg = list(
        p_vec = p_vec, desn_args = desn_args, vb_args_base = vb_args_base,
        nd_draws = nd_draws, chunk_sz = chunk_sz, last_window = last_window,
        teacher_forcing = list(enable = tf_enable, first_k = tf_first_k,
                               explicit = y_future_obs_explicit, y_future_obs_fc = y_future_obs_fc),
        synth = list(isotonic = synth_isotonic, rearrange = synth_rearrange,
                     grid_M = synth_grid_M, n_samp = synth_nsamp, seed = synth_seed),
        split = list(T_use = T_use, n_train = n_train, H_forecast = H_forecast)
      )
    ),
    file.path(out_dir, "forecast_objects.rds")
  )
}

# (Optional) You can append your calibration & PIT diagnostics blocks below
# exactly as in the notebook if you want them emitted during batch runs.

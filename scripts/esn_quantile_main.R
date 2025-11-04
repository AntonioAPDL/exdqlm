# scripts/esn_quantile_main.R
# Standalone main for ESN quantile pipeline (fit → forecast → synthesis → diagnostics)
# Reads configuration from EXDQLM_* environment variables set by scripts/run_one.R

as_num_vec <- function(x) {
  if (is.null(x)) return(NULL)
  if (is.list(x)) x <- unlist(x, use.names = FALSE)
  as.numeric(x)
}
fix_len <- function(x, D, nm) {
  if (is.null(x)) return(NULL)
  if (length(x) == D) return(x)
  if (length(x) == 1L && D > 1L) {
    message(sprintf("Note: recycling %s=%s to length D=%d", nm, paste(x, collapse=","), D))
    return(rep(x, D))
  }
  stop(sprintf("Config error: length(%s)=%d but D=%d", nm, length(x), D))
}

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

val <- Sys.getenv("EXDQLM_SAVE_OUTPUTS", unset = NA)
save_outputs <- if (!is.na(val) && nzchar(val)) (as.integer(val) == 1L) else TRUE

if (is.na(file_long) || !file.exists(file_long)) {
  stop("EXDQLM_FILE_LONG not set or file missing: ", file_long)
}
if (is.na(out_dir) || !nzchar(out_dir)) {
  out_dir <- file.path(dirname(file_long), "fig_esn_quantile_main")
}

# Ensure base + subdirs exist
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
FIGS   <- file.path(out_dir, "figs");   dir.create(FIGS,   recursive = TRUE, showWarnings = FALSE)
TABLES <- file.path(out_dir, "tables"); dir.create(TABLES, recursive = TRUE, showWarnings = FALSE)
MODELS <- file.path(out_dir, "models"); dir.create(MODELS, recursive = TRUE, showWarnings = FALSE)

message(sprintf("[esn_main] out_dir=%s | save_outputs=%s", out_dir, save_outputs))


cfg_json <- Sys.getenv("EXDQLM_CFG_JSON", unset = NA)
cfg <- if (!is.na(cfg_json) && nzchar(cfg_json)) jsonlite::fromJSON(cfg_json, simplifyVector = TRUE) else list()

`%nz%` <- function(x, alt) if (!is.null(x)) x else alt
`%||%` <- function(x, alt) if (!is.null(x)) x else alt

near_equal <- function(x, y, tol = 1e-8) abs(x - y) <= tol

# --- Defaults (overridden by cfg when present)
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

# Diagnostics toggles (can be overridden via cfg$diagnostics)
do_calibration <- TRUE
do_pit         <- TRUE
do_scores      <- TRUE  # CRPS + S

# --- Apply cfg overrides (if present)
if (length(cfg)) {
  if (!is.null(cfg$p_vec))             p_vec <- as.numeric(cfg$p_vec)

  if (!is.null(cfg$desn)) {
    D_in   <- as.integer(cfg$desn$D %||% desn_args$D)
    n_in   <- as_num_vec(cfg$desn$n)
    rho_in <- as_num_vec(cfg$desn$rho)

    desn_args$D   <- D_in
    desn_args$n   <- fix_len(n_in   %||% desn_args$n,   D_in, "desn$n")
    desn_args$rho <- fix_len(rho_in %||% desn_args$rho, D_in, "desn$rho")

    desn_args$m        <- cfg$desn$m        %nz% desn_args$m
    desn_args$alpha    <- cfg$desn$alpha    %nz% desn_args$alpha
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

  if (!is.null(cfg$diagnostics)) {
    do_calibration <- cfg$diagnostics$calibration %nz% do_calibration
    do_pit         <- cfg$diagnostics$pit         %nz% do_pit
    do_scores      <- cfg$diagnostics$scores      %nz% do_scores
  }
}

# --- Plot helpers (same as notebook, locked to 3 decimals for tau labels)
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
# --- 1) Load data + split (INSTRUMENTED) --------------------------------------
dat_long <- read.csv(file_long) |>
  tibble::as_tibble() |>
  dplyr::mutate(t=as.integer(t), p=as.numeric(p), q=as.numeric(q), y=as.numeric(y), mu=as.numeric(mu)) |>
  dplyr::arrange(t, p)

y_full_all <- dat_long |> dplyr::distinct(t, y) |> dplyr::arrange(t)
T_full <- nrow(y_full_all)

# ---- Configurable data limiting + split (YAML-aware, verbose) ----
# cfg$split fields (optional):
#   T_use, use_prop, use_last, train_n, train_prop
cat("SPLIT_RAW | cfg$split=",
    jsonlite::toJSON(cfg$split, auto_unbox = TRUE, null = "null"), "\n", sep="")

use_last   <- TRUE
T_use      <- T_full
train_n    <- NULL
train_prop <- NULL

if (!is.null(cfg$split)) {
  # Presence + null/NA audit
  has_train_n    <- "train_n"    %in% names(cfg$split)
  has_train_prop <- "train_prop" %in% names(cfg$split)
  cat("SPLIT_KEYS | has(train_n)=", has_train_n,
      " is.null(train_n)=", is.null(cfg$split$train_n),
      " has(train_prop)=", has_train_prop,
      " is.null(train_prop)=", is.null(cfg$split$train_prop), "\n", sep="")

  # Parse primitives
  if (!is.null(cfg$split$use_last))   use_last   <- isTRUE(cfg$split$use_last)
  if (!is.null(cfg$split$use_prop))   T_use      <- max(1L, floor(as.numeric(cfg$split$use_prop) * T_full))
  if (!is.null(cfg$split$T_use))      T_use      <- as.integer(cfg$split$T_use)
  if (has_train_n)                    train_n    <- suppressWarnings(as.integer(cfg$split$train_n))
  if (has_train_prop)                 train_prop <- suppressWarnings(as.numeric(cfg$split$train_prop))

  # Canonicalize pseudo-nulls: treat length-0 / NA as absent
  norm_opt <- function(x) {
    if (is.null(x)) return(NULL)
    if (length(x) == 0L) return(NULL)
    if (all(is.na(x))) return(NULL)
    x
  }
  train_n    <- norm_opt(train_n)
  train_prop <- norm_opt(train_prop)
}

T_use <- min(T_full, as.integer(T_use))
idx_use <- if (use_last) seq.int(T_full - T_use + 1L, T_full) else seq_len(T_use)
y_full  <- y_full_all[idx_use, , drop = FALSE]

# Keep a matching long frame for "true q_p" computation restricted to used t's
dat_long_use <- dat_long |>
  dplyr::semi_join(y_full, by = c("t")) |>
  dplyr::arrange(t, p)

# ---- Split validation (fail fast; no silent patches) ----
# 1) Mutually exclusive options
if (!is.null(train_n) && !is.null(train_prop)) {
  stop(sprintf("Split config conflict: both train_n (%s) and train_prop (%s) are set. Specify only one.",
               as.character(train_n), as.character(train_prop)))
}
# 2) Range checks
if (!is.null(train_prop) && !(is.finite(train_prop) && train_prop > 0 && train_prop < 1)) {
  stop(sprintf("Invalid train_prop=%s. Must be in (0,1).", as.character(train_prop)))
}
if (!is.null(train_n) && !(is.finite(train_n) && train_n >= 1L && train_n <= (T_use - 1L))) {
  stop(sprintf("Invalid train_n=%s for T_use=%d. Must be in [1, %d].",
               as.character(train_n), T_use, T_use - 1L))
}

# 3) Resolve n_train with clear source tag
split_src <- "default"
n_train <- if (!is.null(train_n)) {
  split_src <- "train_n"
  as.integer(train_n)
} else if (!is.null(train_prop)) {
  split_src <- "train_prop"
  max(1L, min(T_use - 1L, floor(train_prop * T_use)))
} else {
  split_src <- "fallback_0.9"
  max(1L, min(T_use - 1L, floor(0.9 * T_use)))
}

H_forecast <- as.integer(T_use - n_train)

# Audit lines BEFORE any modeling
cat(sprintf(
  paste0("SPLIT_RESOLVE | source=%s | T_full=%d | T_use=%d | use_last=%s | ",
         "train_n=%s | train_prop=%s | n_train=%d | H_forecast=%d | washout=%d\n"),
  split_src, T_full, T_use, as.character(use_last),
  ifelse(is.null(train_n), "NULL", as.character(train_n)),
  ifelse(is.null(train_prop), "NULL", format(train_prop, digits=6, trim=TRUE)),
  n_train, H_forecast, as.integer(desn_args$washout))
)

# Hard stops for impossible/pointless configs
if (H_forecast < 1L) {
  stop(sprintf("Invalid split: H_forecast=%d (n_train=%d, T_use=%d). Adjust train_n/train_prop/T_use.", 
               H_forecast, n_train, T_use))
}

# Index diagnostics
idx_tr <- 1:n_train
idx_fc <- (n_train + 1L):T_use
cat(sprintf("IDX | use_range=[%d..%d] | train=[%d..%d] | forecast=[%d..%d] | lens train=%d, fore=%d\n",
            min(idx_use), max(idx_use),
            ifelse(length(idx_tr), min(idx_tr), NA_integer_),
            ifelse(length(idx_tr), max(idx_tr), NA_integer_),
            ifelse(length(idx_fc), min(idx_fc), NA_integer_),
            ifelse(length(idx_fc), max(idx_fc), NA_integer_),
            length(idx_tr), length(idx_fc)))

y_train    <- y_full$y[idx_tr]
y_forecast <- y_full$y[idx_fc]

cat(sprintf("[lens] y_train=%d | y_forecast=%d\n", length(y_train), length(y_forecast)))

# Teacher forcing vector (auditable)
y_future_obs_fc <- {
  if (!isTRUE(tf_enable)) rep(NA_real_, H_forecast)
  else if (!is.null(y_future_obs_explicit)) as.numeric(y_future_obs_explicit)
  else if (is.null(tf_first_k)) as.numeric(y_forecast)
  else { k <- max(0L, min(as.integer(tf_first_k), H_forecast)); vec <- rep(NA_real_, H_forecast); if (k > 0L) vec[seq_len(k)] <- y_forecast[seq_len(k)]; vec }
}
cat(sprintf("TF | enable=%s | first_k=%s | len(y_future_obs_fc)=%d\n",
            as.character(tf_enable),
            ifelse(is.null(tf_first_k), "NULL", as.character(tf_first_k)),
            length(y_future_obs_fc)))
flush.console()
# ---------------------------------------------------------------------------

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
      yfo <- rep(NA_real_, H_o)  # no teacher forcing inside RO blocks
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
  q_true_fc <- true_q_at_tau(dat_long_use, tau = p0)[idx_fc]

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
  q_true_tr <- true_q_at_tau(dat_long_use, tau = p0)[keep]
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
    ggsave(file.path(FIGS, sprintf("forecast_mu_band_p=%s.png", as.character(p0))), g1, width=9, height=4.8, dpi=150)
    ggsave(file.path(FIGS, sprintf("forecast_emp_q_vs_true_p=%s.png", as.character(p0))), g2, width=9, height=4.8, dpi=150)
  }
}

# --- 3b) Per-p TRAIN plots for mû band (new)
for (k in seq_along(p_vec)) {
  p0 <- p_vec[k]
  g1_tr <- plot_mu_band(fits_fc[[k]]$df_mu_tr, p0, scope = "Train", window = 200L)
  print(g1_tr)
  if (isTRUE(save_outputs)) {
    ggplot2::ggsave(file.path(FIGS, sprintf("train_mu_band_p=%s.png", as.character(p0))),
                    g1_tr, width = 9, height = 4.8, dpi = 150)
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
  if (isTRUE(save_outputs)) ggsave(file.path(FIGS, sprintf("elbo_traces_skip_k=%d.png", k_burn)), g_elbo, width=9, height=4.8, dpi=150)
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
for (i in seq_along(p_comp)) true_cols_fc[[i]] <- true_q_at_tau(dat_long_use, tau = p_comp[i])[idx_fc]
true_q_fc <- tibble::as_tibble(true_cols_fc)

compare_fc <- tibble::tibble(h = seq_len(H_forecast), y = y_forecast) |>
  dplyr::bind_cols(true_q_fc) |>
  dplyr::bind_cols(synth_q_fc)

plots_synth_fc <- lapply(p_comp, function(tau) plot_synth_q_vs_true(compare_fc, tau, scope="Forecast", window=last_window))
for (j in seq_along(plots_synth_fc)) {
  print(plots_synth_fc[[j]])
  if (isTRUE(save_outputs)) ggsave(file.path(FIGS, sprintf("forecast_synth_vs_true_p=%s.png", fmt_p(p_comp[j]))),
                                   plots_synth_fc[[j]], width=9, height=4.8, dpi=150)
}

g_band_fc <- plot_synth_predictive_band(synth_draws = synth_fc$draws, y_vec = y_forecast,
                                        scope="Forecast", window=last_window, fill_col="#3B82F6", show_median=TRUE)
print(g_band_fc)
if (isTRUE(save_outputs)) ggsave(file.path(FIGS, "forecast_obs_with_95_band.png"), g_band_fc, width=9, height=4.8, dpi=150)

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
for (i in seq_along(p_comp)) true_cols_tr[[i]] <- true_q_at_tau(dat_long_use, tau = p_comp[i])[keep_train]
true_q_tr <- tibble::as_tibble(true_cols_tr)

compare_tr <- tibble::tibble(h = seq_len(T_train_keep), y = y_train[keep_train]) |>
  dplyr::bind_cols(true_q_tr) |>
  dplyr::bind_cols(synth_q_tr)

plots_synth_tr <- lapply(p_comp, function(tau) plot_synth_q_vs_true(compare_tr, tau, scope="Train", window=200L))
for (j in seq_along(plots_synth_tr)) {
  print(plots_synth_tr[[j]])
  if (isTRUE(save_outputs)) ggsave(file.path(FIGS, sprintf("train_synth_vs_true_p=%s.png", fmt_p(p_comp[j]))),
                                   plots_synth_tr[[j]], width=9, height=4.8, dpi=150)
}

g_band_tr <- plot_synth_predictive_band(synth_draws = synth_tr$draws, y_vec = y_train[keep_train],
                                        scope="Train", window=200L, fill_col="#0ea5e9", show_median=TRUE)
print(g_band_tr)
if (isTRUE(save_outputs)) ggsave(file.path(FIGS, "train_obs_with_95_band.png"), g_band_tr, width=9, height=4.8, dpi=150)

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
    file.path(MODELS, "forecast_objects.rds")
  )
}

# ================================================================
# 7) Calibration diagnostics (μ, q̂ₚ, synthesized q): tables + rolling plots
# ================================================================
if (isTRUE(do_calibration)) {
  # helpers
  wilson_ci <- function(k, n, conf = 0.95) {
    if (n <= 0) return(c(NA_real_, NA_real_))
    z <- stats::qnorm(0.5 + conf/2)
    p <- k / n
    den <- 1 + z^2 / n
    cen <- (p + z^2/(2*n)) / den
    rad <- z * sqrt(p*(1-p)/n + z^2/(4*n^2)) / den
    c(max(0, cen - rad), min(1, cen + rad))
  }
  pinball_loss <- function(y, qhat, p) { e <- y - qhat; (p - (e < 0)) * e }
  roll_mean <- function(x, W) { if (W <= 1) return(x); as.numeric(stats::filter(x, rep(1 / W, W), sides = 1)) }

  # Build long frames aligned in "time" for train and forecast
  # μ
  mu_tr_long <- dplyr::bind_rows(purrr::compact(lapply(seq_along(p_vec), function(i) {
    d <- fits_fc[[i]]$df_mu_tr; if (is.null(d) || !nrow(d)) return(NULL)
    keep <- fits_fc[[i]]$fit_train$meta$keep_idx
    d %>% dplyr::mutate(scope="train", p_chr=sprintf("%.2f", p_vec[i]),
                        t_aligned=keep, mu_hat=mu)
  })))
  mu_fc_long <- dplyr::bind_rows(lapply(seq_along(p_vec), function(i) {
    d <- fits_fc[[i]]$df_mu_fc
    d |> dplyr::mutate(scope = "forecast", p_chr = sprintf("%.2f", p_vec[i]),
                       t_aligned = n_train + h, mu_hat = mu)
  }))
  mu_long <- dplyr::bind_rows(mu_tr_long, mu_fc_long)

  # q̂_p
  q_tr_long <- dplyr::bind_rows(lapply(seq_along(p_vec), function(i) {
    d <- fits_fc[[i]]$df_pred_tr; keep <- fits_fc[[i]]$fit_train$meta$keep_idx
    d |> dplyr::mutate(scope="train", p_chr=sprintf("%.2f", p_vec[i]),
                       t_aligned=keep, qhat=q_pred)
  }))
  q_fc_long <- dplyr::bind_rows(lapply(seq_along(p_vec), function(i) {
    d <- fits_fc[[i]]$df_pred_fc
    d |> dplyr::mutate(scope="forecast", p_chr=sprintf("%.2f", p_vec[i]),
                       t_aligned = n_train + h, qhat=q_pred)
  }))
  q_long <- dplyr::bind_rows(q_tr_long, q_fc_long)

  # Synthesized q_p (train + forecast) at p_comp
  qsynth_tr_long <- dplyr::bind_rows(lapply(p_comp, function(tau) {
    tibble::tibble(
      scope     = "train", p0 = tau, p_chr = sprintf("%.2f", tau),
      t_aligned = keep_train,
      q_synth   = synth_q_tr[[paste0("synth_q_", fmt_p(tau))]],
      y         = y_train[keep_train]
    )
  }))
  qsynth_fc_long <- dplyr::bind_rows(lapply(p_comp, function(tau) {
    tibble::tibble(
      scope     = "forecast", p0 = tau, p_chr = sprintf("%.2f", tau),
      t_aligned = n_train + seq_len(H_forecast),
      q_synth   = synth_q_fc[[paste0("synth_q_", fmt_p(tau))]],
      y         = y_forecast
    )
  }))
  qsynth_long <- dplyr::bind_rows(qsynth_tr_long, qsynth_fc_long)

  # ---- SAFE COERCION for calibration summaries ----
  force_numeric_column <- function(df, qcol) {
    x <- df[[qcol]]
    # If it's a matrix (e.g., T x M draws accidentally carried over), use the first column
    if (is.matrix(x)) x <- drop(x[, 1, drop = TRUE])
    # If it's a list column, take the first numeric scalar from each cell
    if (is.list(x))  x <- vapply(x, function(z) as.numeric(z)[1], numeric(1))
    x <- as.numeric(x)
    if (length(x) != nrow(df)) {
      stop(sprintf("Column '%s' has length %d but nrow(df)=%d (class=%s).",
                  qcol, length(x), nrow(df), paste(class(df[[qcol]]), collapse=",")))
    }
    df[[qcol]] <- x
    df
  }

  summarize_cov_tbl_safe <- function(df, qcol) {
    stopifnot(all(c("y","p0","scope", qcol) %in% names(df)))
    df <- force_numeric_column(df, qcol)
    df |>
      dplyr::filter(is.finite(.data$y), is.finite(.data[[qcol]])) |>
      dplyr::group_by(.data$scope, .data$p0) |>
      dplyr::summarise(
        N        = dplyr::n(),
        k        = sum(.data$y <= .data[[qcol]], na.rm = TRUE),
        coverage = ifelse(N > 0, k / N, NA_real_),
        cov_lo95 = wilson_ci(k, N)[1],
        cov_hi95 = wilson_ci(k, N)[2],
        pinball  = mean(pinball_loss(.data$y, .data[[qcol]], dplyr::first(.data$p0)), na.rm = TRUE),
        .groups  = "drop"
      ) |>
      dplyr::arrange(.data$scope, .data$p0)
  }

  cov_mu_tbl   <- summarize_cov_tbl_safe(dplyr::rename(mu_long,  qcol = mu_hat) |> dplyr::mutate(p0 = as.numeric(p_chr)), "qcol")
  cov_qhat_tbl <- summarize_cov_tbl_safe(dplyr::rename(q_long,   qcol = qhat)   |> dplyr::mutate(p0 = as.numeric(p_chr)), "qcol")
  cov_qsynth_tbl <- summarize_cov_tbl_safe(dplyr::rename(qsynth_long, qcol = q_synth), "qcol")

  print(cov_mu_tbl); print(cov_qhat_tbl); print(cov_qsynth_tbl)
  if (isTRUE(save_outputs)) {
    readr::write_csv(cov_mu_tbl,     file.path(TABLES, "calibration_mu_table.csv"))
    readr::write_csv(cov_qhat_tbl,   file.path(TABLES, "calibration_qhat_table.csv"))
    readr::write_csv(cov_qsynth_tbl, file.path(TABLES, "calibration_qsynth_table.csv"))
  }

  # Rolling-coverage plots (μ, q̂ₚ, q_synth)
  cov_window <- 365L
  show_last  <- 300L

plot_rolling_cov <- function(df_long, qcol,
                             window = NULL, show_last = NULL,
                             title_left = "Rolling empirical coverage",
                             show_rcov_band = FALSE,
                             show_target_band = FALSE) {

  if (is.null(window))    window    <- get0("cov_window", ifnotfound = 365L, inherits = TRUE)
  if (is.null(show_last)) show_last <- get0("show_last",  ifnotfound = 300L, inherits = TRUE)

  # Coerce target column to numeric (handles list/matrix edge cases)
  if (is.matrix(df_long[[qcol]])) df_long[[qcol]] <- drop(df_long[[qcol]][, 1, drop = TRUE])
  if (is.list(df_long[[qcol]]))   df_long[[qcol]] <- vapply(df_long[[qcol]], function(z) as.numeric(z)[1], numeric(1))
  df_long[[qcol]] <- as.numeric(df_long[[qcol]])

  # SAFE helpers (auto-shrink W to series length)
  roll_sum  <- function(x, W) { W_eff <- min(W, length(x)); if (W_eff < 1) return(rep(NA_real_, length(x)))
                                as.numeric(stats::filter(x, rep(1,        W_eff), sides = 1)) }
  roll_mean <- function(x, W) { W_eff <- min(W, length(x)); if (W_eff < 1) return(rep(NA_real_, length(x)))
                                as.numeric(stats::filter(x, rep(1/W_eff,  W_eff), sides = 1)) }

  d <- df_long |>
    dplyr::mutate(ind = as.integer(.data$y <= .data[[qcol]])) |>
    dplyr::arrange(scope, p_chr, t_aligned) |>
    dplyr::group_by(scope, p_chr) |>
    dplyr::mutate(
      W_use = pmax(1L, pmin(window, dplyr::n())),
      k_win = roll_sum(ind,  W_use[1]),
      rcov  = roll_mean(ind, W_use[1]),
      t_max = max(t_aligned, na.rm = TRUE)
    ) |>
    dplyr::ungroup() |>
    dplyr::filter(t_aligned > (t_max - show_last))

  wilson_ci_vec <- function(k, n, conf = 0.95) {
    z <- stats::qnorm(0.5 + conf/2); p <- k / n
    den <- 1 + z^2 / n; cen <- (p + z^2/(2*n)) / den
    rad <- z * sqrt(p*(1-p)/n + z^2/(4*n^2)) / den
    list(lo = pmax(0, cen - rad), hi = pmin(1, cen + rad))
  }
  ci <- wilson_ci_vec(d$k_win, d$W_use)
  d$lo_cov <- ci$lo; d$hi_cov <- ci$hi

  W_lab <- if (any(d$W_use < window, na.rm = TRUE)) paste0("≤", window) else as.character(window)

  d <- d |> dplyr::mutate(p_chr = factor(p_chr, levels = sprintf("%.2f", p_vec)))
  ref <- d |> dplyr::distinct(scope, p_chr) |> dplyr::mutate(p0 = as.numeric(as.character(p_chr)))

  x_rng <- range(d$t_aligned, na.rm = TRUE)
  last_pts <- d %>%
    dplyr::group_by(scope, p_chr) %>% dplyr::slice_tail(n = 1) %>% dplyr::ungroup() %>%
    dplyr::mutate(x_lab = t_aligned - 0.03 * diff(x_rng), y_lab = pmin(pmax(rcov + 0.02, 0), 1))

  ggplot2::ggplot(d, ggplot2::aes(x = t_aligned, y = rcov, colour = p_chr)) +
    theme_exdqlm() +
    ggplot2::labs(
      x = "time index (aligned)",
      y = sprintf("rolling Pr(y ≤ %s)  (W %s)", if (qcol=="mu_hat") "μ" else "q", W_lab),
      title    = paste0(title_left, if (qcol=="mu_hat") " of μ" else " of q"),
      subtitle = sprintf("Last %d points; ribbon: Wilson CI of rolling coverage", show_last)
    ) +
    ggplot2::geom_hline(data = ref, ggplot2::aes(yintercept = p0, colour = p_chr),
                        linetype = "dashed", linewidth = 0.7, show.legend = FALSE) +
    { if (isTRUE(show_rcov_band))
        ggplot2::geom_ribbon(ggplot2::aes(x = t_aligned, ymin = lo_cov, ymax = hi_cov,
                                           fill = p_chr, group = p_chr),
                              inherit.aes = FALSE, alpha = 0.18)
      else ggplot2::geom_blank() } +
    ggplot2::geom_line(linewidth = 0.9, na.rm = TRUE) +
    ggplot2::geom_point(data = last_pts, size = 2.4) +
    ggplot2::geom_text(data = last_pts,
                       ggplot2::aes(x = x_lab, y = y_lab, label = sprintf("%.2f", rcov)),
                       size = 3, hjust = 1) +
    ggplot2::scale_color_manual(name = "quantile p",
      values = setNames(col_map, sprintf("%.2f", p_vec)),
      labels = function(x) scales::percent(as.numeric(x))) +
    ggplot2::scale_fill_manual(name = "quantile p",
      values = setNames(sapply(col_map, scales::alpha, alpha = 0.18), sprintf("%.2f", p_vec)),
      labels = function(x) scales::percent(as.numeric(x))) +
    ggplot2::scale_y_continuous(breaks = seq(0,1,0.1), labels = scales::percent_format(accuracy = 1)) +
    ggplot2::scale_x_continuous(limits = x_rng, expand = c(0, 0)) +
    ggplot2::coord_cartesian(ylim = c(0, 1), expand = FALSE)
}


g_cov_mu_train <- plot_rolling_cov(mu_long |> dplyr::filter(scope=="train"),
                                   qcol = "mu_hat",
                                   window = cov_window, show_last = show_last,
                                   show_rcov_band = TRUE,  show_target_band = FALSE)

g_cov_mu_fore  <- plot_rolling_cov(mu_long |> dplyr::filter(scope=="forecast"),
                                   qcol = "mu_hat",
                                   window = cov_window, show_last = show_last,
                                   show_rcov_band = TRUE,  show_target_band = FALSE)

# Keep q̂ and q_synth as purely empirical rolling curves (no ribbons)
g_cov_q_train  <- plot_rolling_cov(q_long  |> dplyr::filter(scope=="train"),
                                   qcol = "qhat",
                                   window = cov_window, show_last = show_last,
                                   show_rcov_band = FALSE, show_target_band = FALSE)

g_cov_q_fore   <- plot_rolling_cov(q_long  |> dplyr::filter(scope=="forecast"),
                                   qcol = "qhat",
                                   window = cov_window, show_last = show_last,
                                   show_rcov_band = FALSE, show_target_band = FALSE)

g_cov_qsynth_train <- plot_rolling_cov(qsynth_long |> dplyr::filter(scope=="train") |> dplyr::rename(q = q_synth),
                                       qcol = "q",
                                       window = cov_window, show_last = show_last,
                                       show_rcov_band = FALSE, show_target_band = FALSE)

g_cov_qsynth_fore  <- plot_rolling_cov(qsynth_long |> dplyr::filter(scope=="forecast") |> dplyr::rename(q = q_synth),
                                       qcol = "q",
                                       window = cov_window, show_last = show_last,
                                       show_rcov_band = FALSE, show_target_band = FALSE)

  print(g_cov_mu_train); print(g_cov_mu_fore)
  print(g_cov_q_train);  print(g_cov_q_fore)
  print(g_cov_qsynth_train); print(g_cov_qsynth_fore)

  if (isTRUE(save_outputs)) {
    ggplot2::ggsave(file.path(FIGS, sprintf("rolling_cov_mu_train_W=%d.png", cov_window)),      g_cov_mu_train, width=9, height=4.8, dpi=150)
    ggplot2::ggsave(file.path(FIGS, sprintf("rolling_cov_mu_forecast_W=%d.png", cov_window)),   g_cov_mu_fore,  width=9, height=4.8, dpi=150)
    ggplot2::ggsave(file.path(FIGS, sprintf("rolling_cov_qhat_train_W=%d.png", cov_window)),    g_cov_q_train,  width=9, height=4.8, dpi=150)
    ggplot2::ggsave(file.path(FIGS, sprintf("rolling_cov_qhat_forecast_W=%d.png", cov_window)), g_cov_q_fore,   width=9, height=4.8, dpi=150)
    ggplot2::ggsave(file.path(FIGS, sprintf("rolling_cov_qsynth_train_W=%d.png", cov_window)),  g_cov_qsynth_train, width=9, height=4.8, dpi=150)
    ggplot2::ggsave(file.path(FIGS, sprintf("rolling_cov_qsynth_forecast_W=%d.png", cov_window)), g_cov_qsynth_fore, width=9, height=4.8, dpi=150)
  }
}

# ================================================================
# 8) PIT diagnostics (train & forecast) using a chosen p model (0.50)
# ================================================================
if (isTRUE(do_pit)) {
  emp_pit_vec <- function(y, yrep_mat) {
    stopifnot(length(y) == nrow(yrep_mat))
    rowMeans(sweep(yrep_mat, 1, y, FUN = "<="), na.rm = TRUE)
  }
  i_med <- which.min(abs(p_vec - 0.50))
  pit_tr <- emp_pit_vec(y_train[fits_fc[[i_med]]$fit_train$meta$keep_idx], fits_fc[[i_med]]$yrep_tr)
  pit_fc <- emp_pit_vec(y_forecast, fits_fc[[i_med]]$yrep_fc)

  plot_pit_hist <- function(pit, title) {
    pit <- pit[is.finite(pit)]
    ks  <- suppressWarnings(stats::ks.test(pit, "punif"))
    ggplot2::ggplot(tibble::tibble(pit = pit), ggplot2::aes(x = pit)) +
      theme_exdqlm() +
      ggplot2::geom_histogram(ggplot2::aes(y = after_stat(density)),
                              boundary = 0, bins = 20, color = "white") +
      ggplot2::geom_hline(yintercept = 1, linetype = 2) +
      ggplot2::labs(title = title,
                    subtitle = sprintf("KS p = %.3f", ks$p.value),
                    x = "PIT", y = "density") +
      ggplot2::coord_cartesian(xlim = c(0, 1), ylim = c(0, NA))
  }
  plot_pit_qq <- function(pit, title) {
    n <- sum(is.finite(pit)); pit_s <- sort(pit[is.finite(pit)])
    u <- stats::ppoints(n)
    ggplot2::ggplot(tibble::tibble(u = u, pit = pit_s), ggplot2::aes(x = u, y = pit)) +
      theme_exdqlm() +
      ggplot2::geom_abline(slope = 1, intercept = 0, linetype = 2) +
      ggplot2::geom_point(alpha = 0.7, size = 1.6) +
      ggplot2::labs(title = title, x = "Uniform(0,1) quantiles", y = "PIT quantiles") +
      ggplot2::coord_cartesian(xlim = c(0,1), ylim = c(0,1))
  }

  g_pit_tr_hist <- plot_pit_hist(pit_tr, "PIT histogram (train)")
  g_pit_fc_hist <- plot_pit_hist(pit_fc, "PIT histogram (forecast)")
  g_pit_tr_qq   <- plot_pit_qq(pit_tr,   "PIT QQ (train)")
  g_pit_fc_qq   <- plot_pit_qq(pit_fc,   "PIT QQ (forecast)")
  g_pit_train    <- g_pit_tr_hist | g_pit_tr_qq
  g_pit_forecast <- g_pit_fc_hist | g_pit_fc_qq

  print(g_pit_train); print(g_pit_forecast)
  if (isTRUE(save_outputs)) {
    ggplot2::ggsave(file.path(FIGS, "pit_train.png"),    g_pit_train,    width = 12, height = 4.5, dpi = 150)
    ggplot2::ggsave(file.path(FIGS, "pit_forecast.png"), g_pit_forecast, width = 12, height = 4.5, dpi = 150)
  }
}

# ================================================================
# 9) CRPS and S score (CRPS + averaged marginal pinball over K)
# ================================================================
if (isTRUE(do_scores)) {
  # Efficient CRPS from samples:
  # CRPS(F, y) ≈ (1/M)∑|z_m - y| - (1/M^2)∑_{k=1..M} (2k - M - 1) z_(k), where z_(k) is sorted draws
  crps_row <- function(y, z) {
    z <- sort(z); M <- length(z)
    term1 <- mean(abs(z - y))
    # ∑_{k}(2k - M - 1) z_(k)
    k <- seq_len(M)
    term2 <- sum((2*k - M - 1) * z) / (M^2)
    term1 - term2
  }
  crps_vec <- function(y_vec, draws_mat) {
    stopifnot(length(y_vec) == nrow(draws_mat))
    vapply(seq_len(nrow(draws_mat)), function(i) crps_row(y_vec[i], draws_mat[i, ]), numeric(1))
  }

  # Forecast-window CRPS from synthesized draws
  crps_fc <- crps_vec(y_forecast, synth_fc$draws)

  # Marginal pinball (using synthesized quantiles at p_comp), average over K
  pinball_loss <- function(y, qhat, p) { e <- y - qhat; (p - (e < 0)) * e }
  # Build matrix of synthesized quantiles T × K at selected p_comp
  synth_q_fc_mat <- do.call(cbind, lapply(p_comp, function(tau) synth_q_fc[[paste0("synth_q_", fmt_p(tau))]]))
  colnames(synth_q_fc_mat) <- sprintf("p=%s", fmt_p(p_comp))

  # Per-time averaged marginal pinball
  pinball_fc_mean <- rowMeans(vapply(seq_along(p_comp), function(j)
    pinball_loss(y_forecast, synth_q_fc_mat[, j], p_comp[j]), numeric(length(y_forecast))))

  # S score per time and summary
  S_fc <- crps_fc + pinball_fc_mean

  scores_fc_df <- tibble::tibble(
    h = seq_len(H_forecast),
    y = y_forecast,
    CRPS = crps_fc,
    pinball_mean = pinball_fc_mean,
    S = S_fc
  )

  # Train-window scores (optional but often handy)
  crps_tr <- crps_vec(y_train[keep_train], synth_tr$draws)
  synth_q_tr_mat <- do.call(cbind, lapply(p_comp, function(tau) synth_q_tr[[paste0("synth_q_", fmt_p(tau))]]))
  colnames(synth_q_tr_mat) <- sprintf("p=%s", fmt_p(p_comp))
  pinball_tr_mean <- rowMeans(vapply(seq_along(p_comp), function(j)
    pinball_loss(y_train[keep_train], synth_q_tr_mat[, j], p_comp[j]), numeric(length(keep_train))))
  S_tr <- crps_tr + pinball_tr_mean

  scores_tr_df <- tibble::tibble(
    h = seq_len(T_train_keep),
    y = y_train[keep_train],
    CRPS = crps_tr,
    pinball_mean = pinball_tr_mean,
    S = S_tr
  )

  # Summaries
  scores_summary <- tibble::tibble(
    split = c("train","forecast"),
    CRPS_mean = c(mean(crps_tr), mean(crps_fc)),
    PinballMean_mean = c(mean(pinball_tr_mean), mean(pinball_fc_mean)),
    S_mean = c(mean(S_tr), mean(S_fc))
  )

  print(scores_summary)
  if (isTRUE(save_outputs)) {
    readr::write_csv(scores_fc_df,    file.path(TABLES, "scores_forecast_series.csv"))
    readr::write_csv(scores_tr_df,    file.path(TABLES, "scores_train_series.csv"))
    readr::write_csv(scores_summary,  file.path(TABLES, "scores_summary.csv"))
  }
}

# scripts/pipeline_real_main.R
#!/usr/bin/env Rscript

suppressWarnings(suppressMessages({
  req <- c("jsonlite","readr","tibble","dplyr","purrr","stringr","ggplot2","matrixStats","scales","patchwork")
  need <- setdiff(req, rownames(installed.packages()))
  if (length(need)) install.packages(need, repos="https://cloud.r-project.org", dependencies = TRUE)
  invisible(lapply(req, require, character.only = TRUE))
}))

`%||%` <- function(a,b) if (!is.null(a)) a else b
.now <- function() format(Sys.time(), "%Y-%m-%d %H:%M:%S")
logf <- function(fmt, ...) { cat(sprintf("[%s] %s\n", .now(), sprintf(fmt, ...))); flush.console() }

# ---- repo root
args_all <- commandArgs(trailingOnly = FALSE)
script_idx  <- grep("^--file=", args_all)
script_arg  <- if (length(script_idx)) sub("^--file=", "", args_all[script_idx]) else ""
repo_root <- tryCatch(
  normalizePath(system("git rev-parse --show-toplevel", intern = TRUE)),
  error = function(...) {
    if (length(script_arg) && nzchar(script_arg)) {
      normalizePath(file.path(script_arg, ".."), mustWork = FALSE)
    } else {
      normalizePath(".", mustWork = FALSE)
    }
  }
)

# ---- ENV
file_obs <- Sys.getenv("EXDQLM_FILE_OBS", unset = NA)
out_dir  <- Sys.getenv("EXDQLM_OUT_DIR",  unset = file.path(repo_root, "out_real"))
cfg_json <- Sys.getenv("EXDQLM_CFG_JSON", unset = NA)
cfg      <- if (!is.na(cfg_json) && nzchar(cfg_json)) jsonlite::fromJSON(cfg_json, simplifyVector = TRUE) else list()

# ---- I/O dirs
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
FIGS   <- file.path(out_dir, "figs");   dir.create(FIGS,   recursive = TRUE, showWarnings = FALSE)
TABLES <- file.path(out_dir, "tables"); dir.create(TABLES, recursive = TRUE, showWarnings = FALSE)
MODELS <- file.path(out_dir, "models"); dir.create(MODELS, recursive = TRUE, showWarnings = FALSE)
MANI   <- file.path(out_dir, "manifest"); dir.create(MANI, showWarnings = FALSE, recursive = TRUE)
logf("[real_main] out_dir=%s", out_dir)

# ---- Load exdqlm (your package) and set seed
suppressWarnings(suppressMessages({
  if (requireNamespace("devtools", quietly = TRUE)) devtools::load_all(repo_root, quiet = TRUE)
}))
set.seed(12345)

# ---- Read CSV with mapped columns
stopifnot(!is.na(file_obs) && file.exists(file_obs))
raw <- readr::read_csv(file_obs, show_col_types = FALSE)
cols_cfg <- cfg$columns %||% list()
y_col <- cols_cfg$y %||% "y"
x_cols <- cols_cfg$x %||% character(0)

if (!(y_col %in% names(raw))) stop("Target column '", y_col, "' not found in: ", paste(names(raw), collapse=", "))
for (xn in x_cols) if (!(xn %in% names(raw))) stop("Exogenous column '", xn, "' not found.")

y_all <- as.numeric(raw[[y_col]])
T_full <- length(y_all)
X_all  <- if (length(x_cols)) as.matrix(raw[, x_cols, drop = FALSE]) else NULL

# ---- Split config (same contract as defaults.yaml)
spl <- cfg$split %||% list()
T_use    <- as.integer(spl$T_use %||% T_full)
use_last <- isTRUE(spl$use_last %||% TRUE)
train_n  <- spl$train_n
train_p  <- spl$train_prop
if (!is.null(train_n)) train_n <- as.integer(train_n)
if (!is.null(train_p)) train_p <- as.numeric(train_p)

T_use <- min(T_use, T_full)
idx_use <- if (use_last) seq.int(T_full - T_use + 1L, T_full) else seq_len(T_use)

y_full <- y_all[idx_use]
X_use  <- if (!is.null(X_all)) X_all[idx_use, , drop = FALSE] else NULL

# ---- Lags config
lags_cfg <- cfg$lags %||% list()

# Back-compat: explicit vectors take precedence if present
exp_y <- lags_cfg$y
exp_x <- lags_cfg$x

m_y <- as.integer(lags_cfg$m_y %||% 0L)
m_x <- as.integer(lags_cfg$m_x %||% 0L)

lags_y <- if (!is.null(exp_y)) as.integer(exp_y) else if (m_y > 0L) seq_len(m_y) else integer(0)
lags_x <- if (!is.null(exp_x)) as.integer(exp_x) else if (m_x > 0L) 0:m_x        else integer(0)

lag_max <- max(c(0L, lags_y, lags_x))


# ---- Resolve train length
if (!is.null(train_n) && !is.null(train_p)) stop("Specify only one of split.train_n or split.train_prop.")
if (!is.null(train_p)) {
  train_n <- max(1L, min(T_use - 1L, floor(train_p * T_use)))
}
if (is.null(train_n)) train_n <- max(1L, min(T_use - 1L, floor(0.9 * T_use)))
H_forecast <- as.integer(T_use - train_n)

logf("Data: T_full=%d | T_use=%d (use_last=%s) | train_n=%d | H_forecast=%d", T_full, T_use, use_last, train_n, H_forecast)

# ---- Minimal theming + helper
ACCENT <- "#c2410c"
theme_exdqlm <- function(base_size = 11) {
  ggplot2::theme_minimal(base_size = base_size) +
    ggplot2::theme(panel.grid.minor = ggplot2::element_blank(), legend.position="right",
                   plot.title=ggplot2::element_text(face="bold"))
}

plot_pred_band <- function(draws, y_vec, scope="Forecast", window=300L) {
  stopifnot(is.matrix(draws), length(y_vec) == nrow(draws))
  T_h <- nrow(draws); i2 <- T_h; i1 <- max(1L, i2 - as.integer(window) + 1L)
  qs <- t(apply(draws, 1L, stats::quantile, probs = c(0.025,0.50,0.975), names = FALSE))
  colnames(qs) <- c("lo","med","hi")
  df <- tibble::tibble(h = seq_len(T_h), y = y_vec, lo = qs[,"lo"], med = qs[,"med"], hi = qs[,"hi"]) |>
        dplyr::filter(dplyr::between(h, i1, i2))
  cov95 <- mean(df$y >= df$lo & df$y <= df$hi, na.rm = TRUE)
  ggplot2::ggplot(df, ggplot2::aes(x=h)) + theme_exdqlm() +
    ggplot2::labs(title=sprintf("%s: synthesized 95%% predictive band", scope),
                  subtitle=sprintf("emp. coverage = %s", scales::percent(cov95, 0.1)),
                  x="time", y="value") +
    ggplot2::geom_ribbon(ggplot2::aes(ymin=lo, ymax=hi), alpha=0.20) +
    ggplot2::geom_line(ggplot2::aes(y=med, colour="median"), linewidth=0.8) +
    ggplot2::geom_line(ggplot2::aes(y=y,   colour="data"),   linewidth=0.7) +
    ggplot2::scale_color_manual(name="", values=c(median=ACCENT, data="#6b7280"))
}

# ---- Reservoir shared pass (identical trick to sim): get X rows aligned to times
desn <- cfg$desn %||% list()
m        <- as.integer(desn$m %||% 60L)
washout  <- as.integer(desn$washout %||% 200L)
drop_res <- washout

shared_fit <- do.call(qdesn_fit_vb, c(
  list(y = y_full, p0 = 0.50, vb_args = list(max_iter=1, tol=1e9, n_samp_xi=1, verbose=FALSE)),
  desn
))
keep_abs <- as.integer(shared_fit$meta$keep_idx)      # absolute 1..T_use (post drop)
X_res    <- as.matrix(shared_fit$X)

# ---- Build lagged features and align with reservoir rows
build_lag_mat <- function(vec, lags) {
  if (!length(lags)) return(NULL)
  cols <- lapply(lags, function(L) c(rep(NA_real_, L), vec[seq_len(length(vec) - L)]))
  out  <- do.call(cbind, cols)
  colnames(out) <- paste0("lag_y_", lags)
  out
}
build_lag_mat_multi <- function(M, lags, base_names) {
  if (is.null(M) || !length(lags)) return(NULL)
  out_list <- lapply(seq_along(base_names), function(j) {
    v <- M[, j]
    cols <- lapply(lags, function(L) c(rep(NA_real_, L), v[seq_len(length(v) - L)]))
    tmp  <- do.call(cbind, cols)
    colnames(tmp) <- paste0(base_names[j], "_lag_", lags)
    tmp
  })
  do.call(cbind, out_list)
}


Ylags_all <- build_lag_mat(y_full, lags_y)
Xlags_all <- build_lag_mat_multi(X_use, lags_x, base_names = if (!is.null(X_use)) colnames(X_use) else character(0))

# effective extra drop due to lags
drop_lag <- lag_max
keep_abs2 <- keep_abs[keep_abs > drop_lag]
row_sel   <- which(keep_abs %in% keep_abs2)

X_res2   <- X_res[row_sel, , drop = FALSE]
Ylags2   <- if (!is.null(Ylags_all)) Ylags_all[keep_abs2, , drop = FALSE] else NULL
Xlags2   <- if (!is.null(Xlags_all)) Xlags_all[keep_abs2, , drop = FALSE] else NULL
X_aug2   <- cbind(X_res2, Ylags2, Xlags2)

# ---- Split the aligned matrices into train/forecast by absolute time
seq_if <- function(a,b) if (a <= b) seq.int(a,b) else integer(0)

idx_tr_abs <- seq_if(drop_lag + drop_res + 1L, train_n)
idx_fc_abs <- seq_if(train_n + 1L, T_use)


row_tr <- which(keep_abs2 %in% idx_tr_abs)
row_fc <- which(keep_abs2 %in% idx_fc_abs)

if (length(row_tr) < 5 || length(row_fc) < 1) {
  stop(sprintf("Not enough rows after lags/washout. Got train=%d, forecast=%d. Consider lowering lags or washout.",
               length(row_tr), length(row_fc)))
}

X_train <- X_aug2[row_tr, , drop = FALSE]
X_fc1   <- X_aug2[row_fc, , drop = FALSE]
y_tr_keep <- y_full[keep_abs2[row_tr]]
y_fc      <- y_full[idx_fc_abs]
stopifnot(nrow(X_train) == length(y_tr_keep), nrow(X_fc1) == length(y_fc))

logf("[aligned] drop_res=%d | drop_lag=%d | X_train rows=%d, X_fc1 rows=%d, p=%d",
     drop_res, drop_lag, nrow(X_train), nrow(X_fc1), ncol(X_train))

# ---- VB + posterior predictive for p ∈ p_vec
p_vec <- as.numeric(cfg$p_vec %||% c(0.05, 0.50, 0.95))
vb    <- cfg$vb %||% list()
tol50 <- vb$tol_50      %||% 1e-4
tolex <- vb$tol_extreme %||% 1e-5
vb_tol_for <- function(p0) if (abs(p0 - 0.50) < 1e-12) tol50 else tolex
nd    <- as.integer((cfg$sampling$nd_draws %||% 2000))
chunk <- as.integer((cfg$sampling$chunk    %||% 300))

fit_and_pp <- function(p0) {
  vb_args_p <- list(max_iter = as.integer(vb$max_iter %||% 150),
                    tol = vb_tol_for(p0),
                    n_samp_xi = as.integer(vb$n_samp_xi %||% 300),
                    verbose = TRUE)
  p <- ncol(X_train)
  fit <- do.call(exal_static_LDVB, c(list(
    y = y_tr_keep, X = X_train,
    b0 = rep(0, p), V0 = diag(1e4, p),
    a_sigma = 1, b_sigma = 1,
    max_iter = vb_args_p$max_iter, tol = vb_args_p$tol,
    n_samp_xi = vb_args_p$n_samp_xi, verbose = vb_args_p$verbose,
    p0 = p0, gamma_bounds = c(L.fn(p0), U.fn(p0)), log_prior_gamma = function(g) 0
  )))
  pp_tr <- exal_vb_posterior_predict(fit, X_new = X_train, nd = nd, chunk = chunk)
  pp_fc <- exal_vb_posterior_predict(fit, X_new = X_fc1,   nd = nd, chunk = chunk)
  list(fit=fit, yrep_tr=pp_tr$yrep, mu_tr=pp_tr$mu_draws, yrep_fc=pp_fc$yrep, mu_fc=pp_fc$mu_draws)
}

fits <- lapply(p_vec, fit_and_pp); names(fits) <- sprintf("p=%.2f", p_vec)

# ---- Synthesis (forecast and train)
draws_fc <- lapply(fits, function(z) z$yrep_fc)
draws_tr <- lapply(fits, function(z) z$yrep_tr)

syn_cfg <- cfg$synthesis %||% list()
syn <- exdqlm_synthesize_from_draws(
  draws_list = draws_fc, p = p_vec,
  enforce_isotonic = isTRUE(syn_cfg$isotonic %||% TRUE),
  rearrange       = isTRUE(syn_cfg$rearrange %||% TRUE),
  grid_M = as.integer(syn_cfg$grid_M %||% 2001),
  n_samp = as.integer(syn_cfg$n_samp %||% 2000),
  seed   = as.integer(syn_cfg$seed   %||% 123),
  T_expected = length(y_fc)
)
syn_tr <- exdqlm_synthesize_from_draws(
  draws_list = draws_tr, p = p_vec,
  enforce_isotonic = isTRUE(syn_cfg$isotonic %||% TRUE),
  rearrange       = isTRUE(syn_cfg$rearrange %||% TRUE),
  grid_M = as.integer(syn_cfg$grid_M %||% 2001),
  n_samp = as.integer(syn_cfg$n_samp %||% 2000),
  seed   = as.integer((syn_cfg$seed %||% 123) + 1L),
  T_expected = length(y_tr_keep)
)

# ---- Plots: predictive band only (no true-q overlays)
g_fc <- plot_pred_band(syn$draws, y_fc, scope="Forecast", window = as.integer((cfg$forecast$last_window %||% 300)))
g_tr <- plot_pred_band(syn_tr$draws, y_tr_keep, scope="Train", window = 200L)
print(g_fc); print(g_tr)
ggplot2::ggsave(file.path(FIGS, "forecast_obs_with_95_band.png"), g_fc, width=9, height=4.8, dpi=150)
ggplot2::ggsave(file.path(FIGS, "train_obs_with_95_band.png"),    g_tr, width=9, height=4.8, dpi=150)

# ---- PIT (median model)
i_med <- which.min(abs(p_vec - 0.50))
emp_pit_vec <- function(y, yrep) { rowMeans(sweep(yrep, 1, y, FUN = "<="), na.rm = TRUE) }
pit_tr <- emp_pit_vec(y_tr_keep, fits[[i_med]]$yrep_tr)
pit_fc <- emp_pit_vec(y_fc,      fits[[i_med]]$yrep_fc)

plot_pit_hist <- function(pit, title) {
  pit <- pit[is.finite(pit)]
  ks  <- suppressWarnings(stats::ks.test(pit, "punif"))
  ggplot2::ggplot(tibble::tibble(pit = pit), ggplot2::aes(x = pit)) +
    theme_exdqlm() +
    ggplot2::geom_histogram(ggplot2::aes(y = after_stat(density)), boundary = 0, bins = 20, color="white") +
    ggplot2::geom_hline(yintercept = 1, linetype = 2) +
    ggplot2::labs(title = title, subtitle = sprintf("KS p = %.3f", ks$p.value), x="PIT", y="density") +
    ggplot2::coord_cartesian(xlim = c(0,1), ylim = c(0, NA))
}
plot_pit_qq <- function(pit, title) {
  n <- sum(is.finite(pit)); pit_s <- sort(pit[is.finite(pit)]); u <- stats::ppoints(n)
  ggplot2::ggplot(tibble::tibble(u = u, pit = pit_s), ggplot2::aes(x = u, y = pit)) +
    theme_exdqlm() + ggplot2::geom_abline(slope = 1, intercept = 0, linetype = 2) +
    ggplot2::geom_point(alpha = 0.7, size = 1.6) +
    ggplot2::labs(title = title, x="Uniform(0,1) quantiles", y="PIT quantiles") +
    ggplot2::coord_cartesian(xlim=c(0,1), ylim=c(0,1))
}
g_pit_tr <- plot_pit_hist(pit_tr, "PIT histogram (train)") | plot_pit_qq(pit_tr, "PIT QQ (train)")
g_pit_fc <- plot_pit_hist(pit_fc, "PIT histogram (forecast)") | plot_pit_qq(pit_fc, "PIT QQ (forecast)")
ggplot2::ggsave(file.path(FIGS, "pit_train.png"),    g_pit_tr, width=12, height=4.5, dpi=150)
ggplot2::ggsave(file.path(FIGS, "pit_forecast.png"), g_pit_fc, width=12, height=4.5, dpi=150)

# ---- Calibration tables (q̂ from yrep and q_synth) via empirical coverage of y ≤ q
wilson_ci <- function(k, n, conf = 0.95) {
  if (n <= 0) return(c(NA_real_, NA_real_))
  z <- stats::qnorm(0.5 + conf/2); p <- k/n; den <- 1 + z^2/n
  cen <- (p + z^2/(2*n))/den; rad <- z*sqrt(p*(p-1)/n + z^2/(4*n^2))/den
  c(max(0, cen - rad), min(1, cen + rad))
}
pinball <- function(y, qhat, p) { e <- y - qhat; (p - (e < 0)) * e }

# μ coverage uses posterior mean draws; we use mu_fc/mu_tr from fits[[i]]$mu_*
summ_cov_tbl <- function(y, qhat_mat_list, p, scope) {
  # qhat_mat_list: list of matrices T×nd (one per p). We compute q̂_p from yrep at that p.
  stopifnot(length(p) == length(qhat_mat_list))
  d <- dplyr::bind_rows(lapply(seq_along(p), function(i) {
    qhat <- apply(qhat_mat_list[[i]], 1, stats::quantile, probs = p[i], names = FALSE)
    tibble::tibble(scope = scope, p0 = p[i], N = length(y),
                   k = sum(y <= qhat), coverage = mean(y <= qhat),
                   pinball = mean(pinball(y, qhat, p[i])))
  }))
  d <- d |> dplyr::rowwise() |>
    dplyr::mutate(ci = list(wilson_ci(k, N)), cov_lo95 = ci[1], cov_hi95 = ci[2]) |>
    dplyr::ungroup() |> dplyr::select(-ci)
  d
}

cov_qhat_tr <- summ_cov_tbl(y_tr_keep, lapply(fits, `[[`, "yrep_tr"), p_vec, "train")
cov_qhat_fc <- summ_cov_tbl(y_fc,      lapply(fits, `[[`, "yrep_fc"), p_vec, "forecast")

# Synth coverage: use synthesized draws directly
summ_cov_synth <- function(y, syn_draws, p, scope) {
  qcols <- sapply(p, function(tau) apply(syn_draws, 1, stats::quantile, probs = tau, names = FALSE))
  dplyr::bind_rows(lapply(seq_along(p), function(i) {
    qhat <- qcols[, i]
    tibble::tibble(scope=scope, p0=p[i], N=length(y),
                   k=sum(y <= qhat), coverage=mean(y <= qhat),
                   pinball=mean(pinball(y, qhat, p[i])))
  })) |>
    dplyr::rowwise() |>
    dplyr::mutate(ci = list(wilson_ci(k, N)), cov_lo95 = ci[1], cov_hi95 = ci[2]) |>
    dplyr::ungroup() |> dplyr::select(-ci)
}
cov_qs_tr <- summ_cov_synth(y_tr_keep, syn_tr$draws, p_vec, "train")
cov_qs_fc <- summ_cov_synth(y_fc,      syn$draws,    p_vec, "forecast")

readr::write_csv(dplyr::bind_rows(cov_qhat_tr, cov_qhat_fc), file.path(TABLES, "calibration_qhat_table.csv"))
readr::write_csv(dplyr::bind_rows(cov_qs_tr,   cov_qs_fc),   file.path(TABLES, "calibration_qsynth_table.csv"))

# ---- Scores: CRPS + average pinball over selected p’s
crps_row <- function(y, z) { z <- sort(z); M <- length(z); mean(abs(z - y)) - sum((2*seq_len(M) - M - 1)*z)/(M^2) }
crps_vec <- function(y, Z)  { vapply(seq_len(nrow(Z)), function(i) crps_row(y[i], Z[i,]), numeric(1)) }

crps_fc <- crps_vec(y_fc, syn$draws)
crps_tr <- crps_vec(y_tr_keep, syn_tr$draws)

pinball_mean_fc <- rowMeans(sapply(p_vec, function(tau) {
  qhat <- apply(syn$draws, 1, stats::quantile, probs = tau, names = FALSE)
  pinball(y_fc, qhat, tau)
}))
pinball_mean_tr <- rowMeans(sapply(p_vec, function(tau) {
  qhat <- apply(syn_tr$draws, 1, stats::quantile, probs = tau, names = FALSE)
  pinball(y_tr_keep, qhat, tau)
}))
S_fc <- crps_fc + pinball_mean_fc
S_tr <- crps_tr + pinball_mean_tr

readr::write_csv(tibble::tibble(h=seq_along(y_fc), y=y_fc, CRPS=crps_fc, pinball_mean=pinball_mean_fc, S=S_fc),
                 file.path(TABLES, "scores_forecast_series.csv"))
readr::write_csv(tibble::tibble(h=seq_along(y_tr_keep), y=y_tr_keep, CRPS=crps_tr, pinball_mean=pinball_mean_tr, S=S_tr),
                 file.path(TABLES, "scores_train_series.csv"))
readr::write_csv(tibble::tibble(split=c("train","forecast"),
                                CRPS_mean=c(mean(crps_tr),mean(crps_fc)),
                                PinballMean_mean=c(mean(pinball_mean_tr),mean(pinball_mean_fc)),
                                S_mean=c(mean(S_tr),mean(S_fc))),
                 file.path(TABLES, "scores_summary.csv"))

# ---- Manifest
manifest <- list(
  pipeline=list(mode="real", version="real-1"),
  inputs=list(file_obs=file_obs),
  data=list(T_full=T_full, T_use=T_use, train_n=train_n, H_forecast=H_forecast,
            y_col=y_col, x_cols=x_cols, lags=list(y=lags_y, x=lags_x)),
  cfg=cfg
)
readr::write_file(jsonlite::toJSON(manifest, auto_unbox=TRUE, pretty=TRUE),
                  file.path(MANI, "manifest_real.json"))

logf("Real pipeline completed successfully.")

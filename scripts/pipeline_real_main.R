# scripts/pipeline_real_main.R
#!/usr/bin/env Rscript

# ================================================================
# Real-data ESN quantile pipeline (fit → forecast → synthesis → diagnostics)
# Mirrors pipeline_main.R (sim) structure, logs, filenames, and tables.
# Differences vs sim:
#   - No true-quantile overlays (no q_true)
#   - Plots that require true quantiles are omitted or adapted
# ================================================================

# Global verbosity (overridden by cfg$pipeline$verbose or cfg$verbose)
VERBOSE <- TRUE

suppressPackageStartupMessages({
  req <- c(
    "devtools","ggplot2","dplyr","tidyr","tibble","scales","MASS","numDeriv",
    "matrixStats","purrr","readr","patchwork","jsonlite","stringr"
  )
  need <- setdiff(req, rownames(installed.packages()))
  if (length(need)) install.packages(need, repos = "https://cloud.r-project.org", dependencies = TRUE)
  invisible(lapply(req, require, character.only = TRUE))
})

`%||%` <- function(a, b) if (!is.null(a)) a else b
`%nz%` <- function(x, alt) if (!is.null(x)) x else alt

# --- Small helpers (compat with sim) ------------------------------------------
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
near_equal <- function(x, y, tol = 1e-8) abs(x - y) <= tol
pretty_vec <- function(x) paste0("[", paste(x, collapse = ", "), "]")
infer_p_digits <- function(p, min_digits = 2L, max_digits = 8L) {
  for (d in min_digits:max_digits) {
    labs <- formatC(p, format = "f", digits = d)
    if (length(unique(labs)) == length(p)) return(d)
  }
  max_digits
}
fmt_p <- function(x) {
  digits <- getOption("exdqlm.p_digits", 2L)
  formatC(as.numeric(x), format = "f", digits = digits)
}

# --- Logging & timing (parity with sim) ---------------------------------------
.now <- function() format(Sys.time(), "%Y-%m-%d %H:%M:%S")
log_msg <- function(fmt, ...) {
  if (!isTRUE(VERBOSE)) return(invisible(NULL))
  cat(sprintf("[%s] %s\n", .now(), sprintf(fmt, ...)))
  flush.console()
}

options(exdqlm.timing = TRUE)
.timing_env <- if (exists(".timing_env", inherits = FALSE)) get(".timing_env") else new.env(parent = emptyenv())
if (is.null(.timing_env$rows)) .timing_env$rows <- data.frame(
  when = character(), tag = character(), seconds = double(), stringsAsFactors = FALSE
)
timed <- function(tag, expr) {
  if (!isTRUE(getOption("exdqlm.timing", TRUE))) return(eval.parent(substitute(expr)))
  t0 <- Sys.time()
  log_msg("▶ %s", tag)
  on.exit({
    dt <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
    .timing_env$rows <- rbind(.timing_env$rows, data.frame(when = .now(), tag = tag, seconds = dt))
    log_msg("■ %s took %.3fs", tag, dt)
  }, add = TRUE)
  eval.parent(substitute(expr))
}

# --- Repo root + load package -------------------------------------------------
repo_root <- tryCatch(
  normalizePath(system("git rev-parse --show-toplevel", intern = TRUE)),
  error = function(...) normalizePath(".", mustWork = TRUE)
)
devtools::load_all(repo_root, quiet = TRUE)
set.seed(12345)

# --- ENV & I/O (parity with sim) ---------------------------------------------
file_long <- Sys.getenv("EXDQLM_FILE_LONG", unset = NA)
file_obs  <- Sys.getenv("EXDQLM_FILE_OBS",  unset = NA)
out_dir   <- Sys.getenv("EXDQLM_OUT_DIR",   unset = NA)
val_save  <- Sys.getenv("EXDQLM_SAVE_OUTPUTS", unset = NA)
save_outputs <- if (!is.na(val_save) && nzchar(val_save)) (as.integer(val_save) == 1L) else TRUE

cfg_json <- Sys.getenv("EXDQLM_CFG_JSON", unset = NA)
cfg <- if (!is.na(cfg_json) && nzchar(cfg_json)) jsonlite::fromJSON(cfg_json, simplifyVector = TRUE) else list()
readout_scale <- isTRUE(cfg$vb$readout_scale %||% FALSE)

if (!is.null(cfg$pipeline) && !is.null(cfg$pipeline$verbose)) {
  VERBOSE <- isTRUE(cfg$pipeline$verbose)
} else if (!is.null(cfg$verbose)) {
  VERBOSE <- isTRUE(cfg$verbose)
}

keep_draws    <- FALSE
thesis_subset <- FALSE
if (!is.null(cfg$outputs)) {
  if (!is.null(cfg$outputs$save)) {
    save_outputs <- isTRUE(cfg$outputs$save)
  }
  if (!is.null(cfg$outputs$keep_draws)) {
    keep_draws <- isTRUE(cfg$outputs$keep_draws)
  }
  if (!is.null(cfg$outputs$thesis_subset)) {
    thesis_subset <- isTRUE(cfg$outputs$thesis_subset)
  }
}

do_calibration <- TRUE
do_pit         <- TRUE
do_scores      <- TRUE
do_lead_eval   <- FALSE
do_plots       <- TRUE
pit_scope      <- "all+synth"
do_fan_charts  <- FALSE
fan_stride     <- 1L
if (!is.null(cfg$diagnostics)) {
  do_calibration <- cfg$diagnostics$calibration %nz% do_calibration
  do_pit         <- cfg$diagnostics$pit         %nz% do_pit
  do_scores      <- cfg$diagnostics$scores      %nz% do_scores
  do_lead_eval   <- cfg$diagnostics$lead_eval   %nz% do_lead_eval
  do_fan_charts  <- cfg$diagnostics$fan_charts  %nz% do_fan_charts
  if (!is.null(cfg$diagnostics$fan_stride)) {
    fan_stride <- as.integer(cfg$diagnostics$fan_stride)
  }
  if (!is.null(cfg$diagnostics$pit_scope)) {
    pit_scope <- tolower(as.character(cfg$diagnostics$pit_scope))
  }
  if (!is.null(cfg$diagnostics$plots)) {
    do_plots <- isTRUE(cfg$diagnostics$plots)
  }
}

# --- Fan chart config normalization ---
fan_stride <- as.integer(fan_stride)
if (!is.finite(fan_stride) || fan_stride < 1L) {
  message(sprintf("[fan_charts] invalid fan_stride=%s; using 1.", as.character(fan_stride)))
  fan_stride <- 1L
}
if (!isTRUE(do_plots)) {
  do_fan_charts <- FALSE
}

# Naming config (align filenames with config/defaults.yaml → naming: ...)
nms <- cfg$naming %||% list()
nm <- function(key, default) {
  v <- nms[[key]]
  if (is.null(v) || !nzchar(v)) default else as.character(v)
}

# Mode is real here, but keep the same guard as sim
mode <- tolower(Sys.getenv("EXDQLM_PIPELINE_MODE", unset = (cfg$pipeline$mode %||% "real")))

if (!mode %in% c("real","observed","data","sim","simulation")) {
  message(sprintf("[pipeline_real_main] WARNING: pipeline.mode=%s not recognized; proceeding.", mode))
}
if (mode %in% c("real","observed","data")) {
  file_long <- file_obs
}

if (is.na(file_long) || !file.exists(file_long)) {
  stop("EXDQLM_FILE_OBS/EXDQLM_FILE_LONG not set or file missing: ", file_long)
}

# Directories
if (is.na(out_dir) || !nzchar(out_dir)) out_dir <- file.path(dirname(file_long), "fig_esn_quantile_real")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
FIGS   <- file.path(out_dir, "figs");    dir.create(FIGS,   recursive = TRUE, showWarnings = FALSE)
TABLES <- file.path(out_dir, "tables");  dir.create(TABLES, recursive = TRUE, showWarnings = FALSE)
MODELS <- file.path(out_dir, "models");  dir.create(MODELS, recursive = TRUE, showWarnings = FALSE)
MANI   <- file.path(out_dir, "manifest");dir.create(MANI,   recursive = TRUE, showWarnings = FALSE)

log_msg("[real_main] out_dir=%s | save_outputs=%s", out_dir, as.character(save_outputs))

# --- Theme & small plot helpers (parity with sim) -----------------------------
ACCENT_ORANGE <- "#ff9c11fc"
FAN_FILL <- "#0ea5a4"  # teal for overlapping fan bands
theme_exdqlm <- function(base_size = 11) {
  ggplot2::theme_minimal(base_size = base_size) +
    ggplot2::theme(panel.grid.minor = ggplot2::element_blank(), legend.position="right",
                   plot.title=ggplot2::element_text(face="bold"))
}
caption_exdqlm <- function(window, nd = NULL) {
  nd_val <- if (!is.null(nd)) as.integer(nd) else NA_integer_
  if (is.na(nd_val)) sprintf("window: last %d steps", as.integer(window))
  else sprintf("window: last %d steps • ndraws: %d", as.integer(window), nd_val)
}

lead_weights_from_power <- function(H, power) {
  power <- as.numeric(power)[1L]
  if (!is.finite(power) || power < 0) {
    stop("forecast.lead_weight_power must be a finite number >= 0.")
  }
  r <- seq_len(as.integer(H))
  log_w <- -power * log(r)
  log_w <- log_w - max(log_w)
  exp(log_w)
}

sanitize_eval_leads <- function(eval_leads, H, default_all = FALSE) {
  if (is.null(eval_leads)) {
    if (isTRUE(default_all)) return(seq_len(H))
    return(integer(0))
  }
  if (is.character(eval_leads) && length(eval_leads) == 1L &&
      tolower(eval_leads) %in% c("all", "any")) {
    return(seq_len(H))
  }
  v <- unique(as.integer(eval_leads))
  v <- v[is.finite(v)]
  dropped <- v[v < 1L | v > H]
  if (length(dropped)) {
    message(sprintf(
      "[lead_eval] dropping out-of-range leads: %s (valid range: 1..%d).",
      paste(dropped, collapse = ", "), H
    ))
  }
  v <- v[v >= 1L & v <= H]
  if (!length(v)) {
    message("[lead_eval] no valid leads remain after filtering; lead evaluation disabled.")
    return(integer(0))
  }
  sort(v)
}

# CRPS from samples (used by scores + lead evaluation)
crps_row <- function(y, z) { z <- sort(z); M <- length(z); mean(abs(z - y)) - sum((2*seq_len(M) - M - 1) * z)/(M^2) }
crps_vec <- function(y_vec, draws_mat) {
  stopifnot(length(y_vec) == nrow(draws_mat))
  vapply(seq_len(nrow(draws_mat)), function(i) crps_row(y_vec[i], draws_mat[i, ]), numeric(1))
}

band_from_draws <- function(mat, level = 0.95, target_len = NULL) {
  mat <- as.matrix(mat)
  probs <- c((1 - level)/2, 0.5, (1 + level)/2)
  if (!is.null(target_len)) {
    if (nrow(mat) == target_len) {
      qs <- cbind(
        lo  = matrixStats::rowQuantiles(mat, probs = probs[1], na.rm = TRUE),
        med = matrixStats::rowQuantiles(mat, probs = probs[2], na.rm = TRUE),
        hi  = matrixStats::rowQuantiles(mat, probs = probs[3], na.rm = TRUE)
      )
    } else if (ncol(mat) == target_len) {
      qs <- cbind(
        lo  = matrixStats::colQuantiles(mat, probs = probs[1], na.rm = TRUE),
        med = matrixStats::colQuantiles(mat, probs = probs[2], na.rm = TRUE),
        hi  = matrixStats::colQuantiles(mat, probs = probs[3], na.rm = TRUE)
      )
    } else {
      stop(sprintf(
        "band_from_draws(): target_len=%d but mat dim is %dx%d.",
        target_len, nrow(mat), ncol(mat)
      ))
    }
  } else {
    qs <- cbind(
      lo  = matrixStats::rowQuantiles(mat, probs = probs[1], na.rm = TRUE),
      med = matrixStats::rowQuantiles(mat, probs = probs[2], na.rm = TRUE),
      hi  = matrixStats::rowQuantiles(mat, probs = probs[3], na.rm = TRUE)
    )
  }
  colnames(qs) <- c("lo","med","hi")
  qs
}

# Robust per-time quantile from a draws matrix (handles row/col orientation)
quantile_by_time <- function(yrep, tau, target_len) {
  yrep <- as.matrix(yrep)
  if (nrow(yrep) == target_len) {
    return(drop(matrixStats::rowQuantiles(yrep, probs = tau, na.rm = TRUE)))
  } else if (ncol(yrep) == target_len) {
    return(drop(matrixStats::colQuantiles(yrep, probs = tau, na.rm = TRUE)))
  } else {
    stop(sprintf("yrep dim %dx%d doesn't match target_len=%d",
                 nrow(yrep), ncol(yrep), target_len))
  }
}

# --- Load data + mapping ------------------------------------------------------
raw <- readr::read_csv(file_long, show_col_types = FALSE)
cols_cfg <- cfg$columns %||% list()
y_col    <- cols_cfg$y %||% "y"
x_cols   <- cols_cfg$x %||% character(0)

if (!(y_col %in% names(raw))) stop("Target column '", y_col, "' not found. Header: ", paste(names(raw), collapse=", "))
for (xn in x_cols) if (!(xn %in% names(raw))) stop("Exogenous column '", xn, "' not found.")

y_all  <- as.numeric(raw[[y_col]])
X_all  <- if (length(x_cols)) as.matrix(raw[, x_cols, drop = FALSE]) else NULL
T_full <- length(y_all)

# --- Preprocessing: scale y and X, but ALWAYS report/plot on original scale ----
pre <- cfg$preproc %||% list()
scale_y <- isTRUE(pre$scale_y %||% TRUE)
scale_x <- isTRUE(pre$scale_x %||% TRUE)

y_mean <- mean(y_all, na.rm = TRUE)
y_sd   <- stats::sd(y_all, na.rm = TRUE); if (!is.finite(y_sd) || y_sd == 0) y_sd <- 1

if (scale_y) y_all <- (y_all - y_mean) / y_sd

if (!is.null(X_all) && ncol(X_all) > 0 && scale_x) {
  X_mu <- matrix(colMeans(X_all, na.rm = TRUE), nrow = 1)
  X_sd <- apply(X_all, 2, function(v) { s <- stats::sd(v, na.rm = TRUE); if (!is.finite(s) || s == 0) 1 else s })
  X_all <- sweep(sweep(X_all, 2, X_mu, "-"), 2, X_sd, "/")
} else {
  X_mu <- NULL; X_sd <- NULL
}

# Applies the inverse scaling to ANY vector/matrix (elementwise)
bt_y <- function(z) {
  if (!scale_y) return(z)
  z * y_sd + y_mean
}

# --- Split config (identical contract + audits) -------------------------------
cat("SPLIT_RAW | cfg$split=", jsonlite::toJSON(cfg$split, auto_unbox = TRUE, null = "null"), "\n", sep = "")

use_last   <- TRUE
T_use      <- T_full
train_n    <- NULL
train_prop <- NULL

if (!is.null(cfg$split)) {
  has_train_n    <- "train_n"    %in% names(cfg$split)
  has_train_prop <- "train_prop" %in% names(cfg$split)
  cat("SPLIT_KEYS | has(train_n)=", has_train_n,
      " is.null(train_n)=", is.null(cfg$split$train_n),
      " has(train_prop)=", has_train_prop,
      " is.null(train_prop)=", is.null(cfg$split$train_prop), "\n", sep = "")

  if (!is.null(cfg$split$use_last)) use_last <- isTRUE(cfg$split$use_last)
  if (!is.null(cfg$split$use_prop)) T_use    <- max(1L, floor(as.numeric(cfg$split$use_prop) * T_full))
  if (!is.null(cfg$split$T_use))    T_use    <- as.integer(cfg$split$T_use)

  # Treat explicit NULL / length-0 / NA as "not set"
  if (has_train_n) {
    tn <- cfg$split$train_n
    train_n <- if (is.null(tn) || length(tn) == 0L || (length(tn) == 1L && is.na(tn))) NULL else as.integer(tn)
  }
  if (has_train_prop) {
    tp <- cfg$split$train_prop
    train_prop <- if (is.null(tp) || length(tp) == 0L || (length(tp) == 1L && is.na(tp))) NULL else as.numeric(tp)
  }

}

T_use <- min(T_full, as.integer(T_use))
idx_use <- if (use_last) seq.int(T_full - T_use + 1L, T_full) else seq_len(T_use)

# Split validations
if (!is.null(train_n) && !is.null(train_prop)) {
  stop(sprintf("Split config conflict: both train_n (%s) and train_prop (%s) are set. Specify only one.",
               as.character(train_n), as.character(train_prop)))
}
if (!is.null(train_prop) && !(is.finite(train_prop) && train_prop > 0 && train_prop < 1)) {
  stop(sprintf("Invalid train_prop=%s. Must be in (0,1).", as.character(train_prop)))
}

# Resolve n_train
split_src <- "fallback_0.9"
n_train <- if (!is.null(train_n)) {
  split_src <- "train_n"; as.integer(train_n)
} else if (!is.null(train_prop)) {
  split_src <- "train_prop"; max(1L, min(T_use - 1L, floor(train_prop * T_use)))
} else {
  split_src <- "fallback_0.9"; max(1L, min(T_use - 1L, floor(0.9 * T_use)))
}
H_forecast <- as.integer(T_use - n_train)

cat(sprintf(
  paste0("SPLIT_RESOLVE | source=%s | T_full=%d | T_use=%d | use_last=%s | ",
         "train_n=%s | train_prop=%s | n_train=%d | H_forecast=%d\n"),
  split_src, T_full, T_use, as.character(use_last),
  ifelse(is.null(train_n), "NULL", as.character(train_n)),
  ifelse(is.null(train_prop), "NULL", format(train_prop, digits=6, trim=TRUE)),
  n_train, H_forecast)
)

if (H_forecast < 1L) {
  stop(sprintf("Invalid split: H_forecast=%d (n_train=%d, T_use=%d). Adjust train_n/train_prop/T_use.",
               H_forecast, n_train, T_use))
}

y_full <- y_all[idx_use]
X_use  <- if (!is.null(X_all)) X_all[idx_use, , drop = FALSE] else NULL

# --- Lags config & construction (real-only) -----------------------------------
lags_cfg <- cfg$lags %||% list()
exp_y <- lags_cfg$y
exp_x <- lags_cfg$x
m_y <- as.integer(lags_cfg$m_y %||% 0L)
m_x <- as.integer(lags_cfg$m_x %||% 0L)
lags_y <- if (!is.null(exp_y)) as.integer(exp_y) else if (m_y > 0L) seq_len(m_y) else integer(0)
lags_x <- if (!is.null(exp_x)) as.integer(exp_x) else if (m_x > 0L) 0:m_x        else integer(0)
lag_max <- max(c(0L, lags_y, lags_x))

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

# --- DESN config normalization (parity with sim) ------------------------------
desn_args <- list(
  D = 1L, n = c(800L), n_tilde = integer(0), m = 50L,
  alpha = 0.2, rho = c(0.95), act_f = "tanh", act_k = "identity",
  pi_w = 0.05, pi_in = 1.00, washout = 500L, add_bias = TRUE, seed = 42
)
if (!is.null(cfg$desn)) {
  D_in   <- as.integer(cfg$desn$D %||% desn_args$D)
  n_in   <- as_num_vec(cfg$desn$n)
  rho_in <- as_num_vec(cfg$desn$rho)

  desn_args$D   <- D_in
  desn_args$n   <- fix_len(n_in   %||% desn_args$n,   D_in, "desn$n")
  desn_args$rho <- fix_len(rho_in %||% desn_args$rho, D_in, "desn$rho")

  as_chr_vec <- function(x) { if (is.null(x)) return(NULL); as.character(x) }
  as_num     <- function(x) { if (is.null(x)) return(NULL); as.numeric(x) }

  if (!is.null(cfg$desn$alpha)) { a  <- as_num(cfg$desn$alpha); desn_args$alpha <- fix_len(a,  D_in, "desn$alpha") }
  if (!is.null(cfg$desn$act_f)) { af <- as_chr_vec(cfg$desn$act_f); desn_args$act_f <- fix_len(af, D_in, "desn$act_f") }
  if (!is.null(cfg$desn$act_k)) { ak <- as_chr_vec(cfg$desn$act_k); desn_args$act_k <- fix_len(ak, D_in, "desn$act_k") }
  if (!is.null(cfg$desn$pi_w))   { pw <- as_num(cfg$desn$pi_w);   desn_args$pi_w  <- fix_len(pw, D_in, "desn$pi_w") }
  if (!is.null(cfg$desn$pi_in))  { pin<- as_num(cfg$desn$pi_in);  desn_args$pi_in <- fix_len(pin,D_in, "desn$pi_in") }
  if (!is.null(cfg$desn$seed))   {
    sd <- as_num(cfg$desn$seed); desn_args$seed <- if (length(sd) == 1L) sd else fix_len(sd, D_in, "desn$seed")
  }

  if (!is.null(cfg$desn$n_tilde)) {
    nt <- as_num(cfg$desn$n_tilde)
    if (length(nt) == 0L) {
      desn_args$n_tilde <- integer(0)
    } else if (length(nt) == 1L) {
      desn_args$n_tilde <- rep(as.integer(nt), D_in)
    } else if (length(nt) %in% c(D_in - 1L, D_in)) {
      desn_args$n_tilde <- as.integer(nt)
    } else {
      stop(sprintf("Config error: length(desn$n_tilde)=%d not in {0,1,%d,%d}",
                   length(nt), D_in - 1L, D_in))
    }
  }

  desn_args$m        <- cfg$desn$m        %nz% desn_args$m
  desn_args$washout  <- cfg$desn$washout  %nz% desn_args$washout
  desn_args$add_bias <- cfg$desn$add_bias %nz% desn_args$add_bias
}

# Sanitize vectors to scalar where required (parity with sim)
D_eff <- as.integer(desn_args$D)
as_num <- function(x) if (is.null(x)) NULL else as.numeric(x)
as_chr <- function(x) if (is.null(x)) NULL else as.character(x)
sanitize_vec <- function(x, D) {
  if (is.null(x)) return(x)
  if (length(x) == 1L) return(x)
  if (length(x) >= D) return(x[seq_len(D)])
  rep(x[1L], D)
}
desn_args$alpha <- sanitize_vec(as_num(desn_args$alpha), D_eff)
desn_args$act_f <- sanitize_vec(as_chr(desn_args$act_f), D_eff)
desn_args$act_k <- sanitize_vec(as_chr(desn_args$act_k), D_eff)
desn_args$pi_w  <- sanitize_vec(as_num(desn_args$pi_w),  D_eff)
desn_args$pi_in <- sanitize_vec(as_num(desn_args$pi_in), D_eff)
desn_args$seed  <- sanitize_vec(as_num(desn_args$seed),  D_eff)
if (D_eff == 1L) {
  if (length(desn_args$alpha)) desn_args$alpha <- as.numeric(desn_args$alpha[1L])
  if (length(desn_args$act_f)) desn_args$act_f <- as.character(desn_args$act_f[1L])
  if (length(desn_args$act_k)) desn_args$act_k <- as.character(desn_args$act_k[1L])
  if (length(desn_args$pi_w))  desn_args$pi_w  <- as.numeric(desn_args$pi_w[1L])
  if (length(desn_args$pi_in)) desn_args$pi_in <- as.numeric(desn_args$pi_in[1L])
  if (length(desn_args$seed))  desn_args$seed  <- as.numeric(desn_args$seed[1L])
}
if (D_eff == 1L) {
  desn_args$act_f <- as.character(desn_args$act_f)[1L]
  desn_args$act_k <- as.character(desn_args$act_k)[1L]
}

# Backend expects a single activation name; collapse if all equal
if (length(desn_args$act_f) != 1L) {
  if (length(unique(desn_args$act_f)) == 1L) {
    desn_args$act_f <- as.character(desn_args$act_f[1L])
  } else {
    stop(sprintf("Config error: multiple act_f values not supported in this pipeline: %s",
                 paste(desn_args$act_f, collapse = ", ")))
  }
}
if (length(desn_args$act_k) != 1L) {
  if (length(unique(desn_args$act_k)) == 1L) {
    desn_args$act_k <- as.character(desn_args$act_k[1L])
  } else {
    stop(sprintf("Config error: multiple act_k values not supported in this pipeline: %s",
                 paste(desn_args$act_k, collapse = ", ")))
  }
}


log_msg(
  "DESN (used) → D=%d | n=%s | n_tilde=%s | m=%d | rho=%s | alpha=%s | act_f=%s | act_k=%s | pi_w=%s | pi_in=%s | washout=%d | add_bias=%s | seed=%s",
  as.integer(desn_args$D),
  pretty_vec(as.integer(desn_args$n)),
  pretty_vec(as.integer(desn_args$n_tilde)),
  as.integer(desn_args$m),
  pretty_vec(as.numeric(desn_args$rho)),
  pretty_vec(as.numeric(desn_args$alpha)),
  pretty_vec(as.character(desn_args$act_f)),
  pretty_vec(as.character(desn_args$act_k)),
  pretty_vec(as.numeric(desn_args$pi_w)),
  pretty_vec(as.numeric(desn_args$pi_in)),
  as.integer(desn_args$washout),
  as.character(isTRUE(desn_args$add_bias)),
  pretty_vec(as.numeric(desn_args$seed))
)

# --- Shared reservoir pass (one roll over y_full) -----------------------------
shared_fit <- timed("shared_reservoir_roll (one pass over y_full)",
  do.call(qdesn_fit_vb, c(
    list(
      y = y_full, p0 = 0.50,
      fit_readout = FALSE
    ),
    desn_args
  ))
)

keep_all_abs <- as.integer(shared_fit$meta$keep_idx) # absolute times 1..T_use after washout & m
X_all_kept   <- as.matrix(shared_fit$X)

# Real-only: align with lags (drop first lag_max times)
keep_abs2 <- keep_all_abs[keep_all_abs > lag_max]
row_sel   <- which(keep_all_abs %in% keep_abs2)

X_res2 <- X_all_kept[row_sel, , drop = FALSE]
Ylags2 <- if (!is.null(Ylags_all)) Ylags_all[keep_abs2, , drop = FALSE] else NULL
Xlags2 <- if (!is.null(Xlags_all)) Xlags_all[keep_abs2, , drop = FALSE] else NULL
X_aug2 <- cbind(X_res2, Ylags2, Xlags2)

# Split into train/forecast by absolute time
seq_if <- function(a,b) if (a <= b) seq.int(a,b) else integer(0)
washout <- as.integer(desn_args$washout)
drop_res <- washout

idx_tr_abs <- seq_if(lag_max + drop_res + 1L, n_train)
idx_fc_abs <- seq_if(n_train + 1L, T_use)

row_tr <- which(keep_abs2 %in% idx_tr_abs)
row_fc <- which(keep_abs2 %in% idx_fc_abs)
keep_train_abs <- keep_abs2[row_tr]
if (length(row_tr) < 5 || length(row_fc) < 1) {
  stop(sprintf("Not enough rows after lags/washout. Got train=%d, forecast=%d. Lower lags or washout.",
               length(row_tr), length(row_fc)))
}

X_train     <- X_aug2[row_tr, , drop = FALSE]
X_fc1       <- X_aug2[row_fc, , drop = FALSE]
y_train_all <- y_full
y_tr_keep   <- y_full[keep_abs2[row_tr]]
y_fc        <- y_full[idx_fc_abs]

stopifnot(nrow(X_train) == length(y_tr_keep), nrow(X_fc1) == length(y_fc))

cat(sprintf("[shared] drop_res=%d | drop_lag=%d | rows: X_train=%d, X_fc1=%d | cols=%d\n",
            drop_res, lag_max, nrow(X_train), nrow(X_fc1), ncol(X_train)))

readout_scale_info <- NULL
if (isTRUE(readout_scale)) {
  scale_fit <- readout_scale_fit(X_train, has_intercept = isTRUE(desn_args$add_bias))
  X_train <- scale_fit$X
  X_fc1   <- readout_scale_apply(X_fc1, scale_fit$scale_info)
  readout_scale_info <- scale_fit$scale_info
  log_msg("Readout scaling → enabled (center+scale; intercept_excluded=%s)",
          as.character(isTRUE(desn_args$add_bias)))
}

# Forecast mode + horizon (lattice/mixture default)
forecast_mode       <- tolower(cfg$forecast$mode %||% "mixture")
forecast_horizon    <- as.integer(cfg$forecast$horizon %||% 1L)
lead_weight_power   <- cfg$forecast$lead_weight_power %||% 1
lead_weights        <- NULL
mix_nd              <- NULL
eval_leads_raw      <- NULL

if (!is.null(cfg$forecast$lead_weights)) {
  message("[forecast] 'lead_weights' is deprecated; use 'lead_weight_power'.")
}
if (!is.null(cfg$forecast$paths)) {
  message("[forecast] 'paths' is deprecated; mixture draws now follow sampling.nd_draws.")
}
if (!is.null(cfg$forecast$eval_leads)) {
  eval_leads_raw <- cfg$forecast$eval_leads
}
if (!forecast_mode %in% c("mixture", "lattice", "origin")) {
  message(sprintf("[forecast] Unknown mode '%s'; defaulting to 'mixture'.", forecast_mode))
  forecast_mode <- "mixture"
}

# Readout spec for recursive forecasts (reservoir + explicit lags)
x_names <- if (!is.null(X_use)) colnames(X_use) else character(0)
x_lags_list <- list()
if (length(x_names)) {
  x_lags_list <- rep(list(as.integer(lags_x)), length(x_names))
  names(x_lags_list) <- x_names
}
readout_spec <- list(
  y_lags     = as.integer(lags_y),
  x_names    = x_names,
  x_lags     = x_lags_list,
  p_res      = ncol(X_res2),
  scale_info = readout_scale_info
)

# Exogenous series for forecasting (must cover [T_use+1 .. T_use+H])
origins_max <- T_use
xreg_all <- NULL
if (length(x_names)) {
  start_idx  <- idx_use[1L]
  end_avail <- nrow(X_all)
  xreg_len <- end_avail - start_idx + 1L
  max_origin_by_x <- xreg_len - forecast_horizon
  origins_max <- min(T_use, max_origin_by_x)
  if (origins_max < n_train) {
    stop(sprintf(
      "Not enough exogenous rows for forecast_horizon=%d. Need at least %d rows from start_idx=%d, have %d.",
      forecast_horizon, start_idx + n_train + forecast_horizon - 1L, start_idx, end_avail
    ))
  }
  if (origins_max < T_use) {
    message(sprintf(
      "[forecast] trimming origins to %d to match available exogenous rows (H=%d).",
      origins_max, forecast_horizon
    ))
  }
  end_needed <- start_idx + origins_max + forecast_horizon - 1L
  X_future_all <- X_all[start_idx:end_needed, , drop = FALSE]
  xreg_all <- lapply(seq_len(ncol(X_future_all)), function(j) X_future_all[, j])
  names(xreg_all) <- colnames(X_future_all)
}
origins <- seq.int(n_train, origins_max)

# Index diagnostics (parity with sim)
cat(sprintf("IDX | use_range=[%d..%d] | train=[%d..%d] | forecast=[%d..%d] | lens train=%d, fore=%d\n",
            min(idx_use), max(idx_use),
            ifelse(length(idx_tr_abs), min(idx_tr_abs), NA_integer_),
            ifelse(length(idx_tr_abs), max(idx_tr_abs), NA_integer_),
            ifelse(length(idx_fc_abs), min(idx_fc_abs), NA_integer_),
            ifelse(length(idx_fc_abs), max(idx_fc_abs), NA_integer_),
            length(idx_tr_abs), length(idx_fc_abs)))

cat(sprintf("[lens] y_train_keep=%d | y_forecast=%d\n", length(y_tr_keep), length(y_fc)))

# --- VB / sampling / synthesis config (parity with sim) -----------------------
p_vec <- as.numeric(cfg$p_vec %||% c(0.05, 0.50, 0.95))
options(exdqlm.p_digits = infer_p_digits(p_vec))

vb_args_base <- list(max_iter = 150, tol = 1e-4, n_samp_xi = 500, verbose = TRUE)

# Per-quantile VB init / priors (natural scale)
vb_init_gamma <- NULL
vb_init_sigma <- NULL
vb_prior_gamma_mu0 <- NULL
vb_prior_gamma_s20 <- NULL
vb_prior_sigma_a <- NULL
vb_prior_sigma_b <- NULL
vb_prior_beta_tau2 <- NULL
vb_prior_beta_type <- "ridge"
vb_prior_beta_rhs <- list(
  tau0 = 10000,
  nu   = 4.0,
  s2   = 10000,
  shrink_intercept = FALSE,
  intercept_prec   = 1e-24,
  n_inner    = 1L,
  eta_bounds = list(lambda = c(-12, 12), tau = c(-12, 12), c2 = c(-12, 12)),
  h_curv    = 1e-24,
  var_floor = 1e-24,
  verbose   = FALSE,
  init_log_lambda = 0.0,
  init_log_tau    = 0.0,
  init_log_c2     = 0.0
)

tol50  <- 1e-4
tolext <- 1e-5
vb_tol_for <- function(p0) if (near_equal(p0, 0.50)) tol50 else tolext
vb_tol_par_for <- vb_tol_for

if (!is.null(cfg$vb)) {
  if (!is.null(cfg$vb$readout_scale)) {
    readout_scale <- isTRUE(cfg$vb$readout_scale)
  }
  vb_args_base$max_iter  <- cfg$vb$max_iter  %nz% vb_args_base$max_iter
  vb_args_base$n_samp_xi <- cfg$vb$n_samp_xi %nz% vb_args_base$n_samp_xi
  if (!is.null(cfg$vb$verbose)) vb_args_base$verbose <- isTRUE(cfg$vb$verbose)

  tol50  <- cfg$vb$tol_50      %nz% tol50
  tolext <- cfg$vb$tol_extreme %nz% tolext
  vb_tol_for <- function(p0) if (abs(p0 - 0.50) < 1e-12) tol50 else tolext

  tol_par_50  <- cfg$vb$tol_par_50      %nz% tol50
  tol_par_ext <- cfg$vb$tol_par_extreme %nz% tolext
  vb_tol_par_for <- function(p0) if (abs(p0 - 0.50) < 1e-12) tol_par_50 else tol_par_ext

  len_p <- length(p_vec)
  recycle_p <- function(x, nm) {
    if (is.null(x)) return(NULL)
    x <- as.numeric(x)
    if (length(x) == 1L && len_p > 1L) {
      if (isTRUE(VERBOSE)) {
        message(sprintf("Note: recycling vb.%s=%s to length(p_vec)=%d", nm, paste(x, collapse=","), len_p))
      }
      return(rep(x, len_p))
    }
    if (length(x) != len_p) {
      stop(sprintf("Config error: length(vb.%s)=%d but length(p_vec)=%d", nm, length(x), len_p))
    }
    x
  }

  if (!is.null(cfg$vb$init)) {
    vb_init_gamma <- recycle_p(cfg$vb$init$gamma, "init$gamma")
    vb_init_sigma <- recycle_p(cfg$vb$init$sigma, "init$sigma")
  }

  if (!is.null(cfg$vb$priors)) {
    if (!is.null(cfg$vb$priors$gamma)) {
      vb_prior_gamma_mu0 <- recycle_p(cfg$vb$priors$gamma$mu0, "priors$gamma$mu0")
      vb_prior_gamma_s20 <- recycle_p(cfg$vb$priors$gamma$s20, "priors$gamma$s20")
    }
    if (!is.null(cfg$vb$priors$sigma)) {
      vb_prior_sigma_a <- recycle_p(cfg$vb$priors$sigma$a, "priors$sigma$a")
      vb_prior_sigma_b <- recycle_p(cfg$vb$priors$sigma$b, "priors$sigma$b")
    }
    if (!is.null(cfg$vb$priors$beta)) {
      beta_cfg <- cfg$vb$priors$beta
      vb_prior_beta_type <- tolower(beta_cfg$type %||% "ridge")

      tau2_val <- NULL
      if (!is.null(beta_cfg$ridge) && !is.null(beta_cfg$ridge$tau2)) {
        tau2_val <- as.numeric(beta_cfg$ridge$tau2)[1L]
      } else if (!is.null(beta_cfg$tau2)) {
        tau2_val <- as.numeric(beta_cfg$tau2)[1L]
      }
      vb_prior_beta_tau2 <- tau2_val

      if (!is.null(beta_cfg$rhs)) {
        rhs_cfg <- beta_cfg$rhs
        vb_prior_beta_rhs <- modifyList(
          vb_prior_beta_rhs,
          list(
            tau0 = rhs_cfg$tau0 %nz% vb_prior_beta_rhs$tau0,
            nu   = rhs_cfg$nu   %nz% vb_prior_beta_rhs$nu,
            s2   = rhs_cfg$s2   %nz% vb_prior_beta_rhs$s2,
            shrink_intercept = rhs_cfg$shrink_intercept %nz% FALSE,
            intercept_prec   = rhs_cfg$intercept_prec   %nz% 1e-24,
            n_inner    = rhs_cfg$n_inner    %nz% vb_prior_beta_rhs$n_inner,
            eta_bounds = rhs_cfg$eta_bounds %nz% vb_prior_beta_rhs$eta_bounds,
            h_curv     = rhs_cfg$h_curv     %nz% vb_prior_beta_rhs$h_curv,
            var_floor  = rhs_cfg$var_floor  %nz% vb_prior_beta_rhs$var_floor,
            verbose    = rhs_cfg$verbose    %nz% vb_prior_beta_rhs$verbose,
            init_log_lambda = rhs_cfg$init_log_lambda %nz% vb_prior_beta_rhs$init_log_lambda,
            init_log_tau    = rhs_cfg$init_log_tau    %nz% vb_prior_beta_rhs$init_log_tau,
            init_log_c2     = rhs_cfg$init_log_c2     %nz% vb_prior_beta_rhs$init_log_c2
          )
        )
      }
    }
  }
}

nd_draws <- as.integer((cfg$sampling$nd_draws %||% 3000L))
chunk_sz <- as.integer((cfg$sampling$chunk    %||% 250L))
# Mixture draws per target time are tied to posterior draws.
mix_nd <- as.integer(nd_draws)
forecast_horizon <- as.integer(forecast_horizon)
if (forecast_horizon < 1L) stop("forecast.horizon must be >= 1.")
lead_weights <- lead_weights_from_power(forecast_horizon, lead_weight_power)
eval_leads <- sanitize_eval_leads(eval_leads_raw, forecast_horizon, default_all = do_lead_eval)
if (isTRUE(do_lead_eval) && length(p_vec) < 2L) {
  message("[lead_eval] need at least two quantile models to synthesize; lead evaluation disabled.")
  eval_leads <- integer(0)
}
lead_eval_enabled <- isTRUE(do_lead_eval) && length(eval_leads) > 0L
lead_eval_store <- if (isTRUE(lead_eval_enabled)) vector("list", length(p_vec)) else NULL

# IJ correction
use_ij_correction <- TRUE
ij_nd_draws <- 2000L
if (!is.null(cfg$ij)) {
  if (!is.null(cfg$ij$use_ij_correction)) use_ij_correction <- isTRUE(cfg$ij$use_ij_correction)
  if (!is.null(cfg$ij$nd_draws)) ij_nd_draws <- as.integer(cfg$ij$nd_draws)
}

# Forecast windows
last_window <- as.integer((cfg$forecast$last_window %||% 200L))
train_last_window <- as.integer(cfg$forecast$train_last_window %||% last_window)
fore_last_window  <- as.integer(cfg$forecast$fore_last_window  %||% last_window)

# Synthesis
synth_isotonic  <- cfg$synthesis$isotonic  %nz% TRUE
synth_rearrange <- cfg$synthesis$rearrange %nz% TRUE
synth_grid_M    <- as.integer((cfg$synthesis$grid_M %||% 2001L))
synth_nsamp     <- as.integer((cfg$synthesis$n_samp %||% 4000L))
synth_seed      <- as.integer((cfg$synthesis$seed   %||% 123L))

log_msg(
  "Effective VB → max_iter=%d | tol_50=%.1e | tol_extreme=%.1e | n_samp_xi=%d",
  vb_args_base$max_iter, tol50, tolext, vb_args_base$n_samp_xi
)
log_msg(
  "Effective beta prior → type=%s | ridge_tau2=%s | rhs(tau0=%.3f, nu=%.3f, s2=%.3f)",
  vb_prior_beta_type,
  if (is.null(vb_prior_beta_tau2)) "NULL" else format(vb_prior_beta_tau2, digits = 4, trim = TRUE),
  vb_prior_beta_rhs$tau0, vb_prior_beta_rhs$nu, vb_prior_beta_rhs$s2
)
log_msg("Effective sampling → nd_draws=%d | chunk=%d", nd_draws, chunk_sz)
log_msg("Effective IJ → use_ij_correction=%s | ij_nd_draws=%d",
        as.character(use_ij_correction), as.integer(ij_nd_draws))

# Color map per p (for multi-p plots)
pal <- scales::hue_pal()(length(p_vec))
col_map <- setNames(pal, fmt_p(p_vec))

# ----- Posterior helpers + IJ (copied from sim for parity) -------------------
qs_ci <- function(x, level = 0.95) {
  p <- (1 - level) / 2
  c(
    lo  = unname(stats::quantile(x, p)),
    med = unname(stats::quantile(x, 0.5)),
    hi  = unname(stats::quantile(x, 1 - p))
  )
}

plot_beta_forest <- function(beta_draws,
                             term_names = NULL,
                             top_k = NULL,
                             zero_line = TRUE) {
  stopifnot(is.matrix(beta_draws))
  p <- ncol(beta_draws)
  if (is.null(term_names) || length(term_names) != p) {
    term_names <- paste0("β", seq_len(p))
  }

  qs <- apply(beta_draws, 2L, qs_ci, level = 0.95)
  df <- tibble::tibble(
    term   = term_names,
    lo     = qs["lo", ],
    med    = qs["med", ],
    hi     = qs["hi", ],
    width  = qs["hi", ] - qs["lo", ],
    absmed = abs(qs["med", ])
  )

  if (!is.null(top_k)) {
    df <- df %>% dplyr::arrange(dplyr::desc(absmed)) %>% dplyr::slice_head(n = top_k)
  }

  ggplot2::ggplot(df, ggplot2::aes(y = reorder(term, absmed), x = med)) +
    theme_exdqlm() +
    ggplot2::geom_errorbarh(ggplot2::aes(xmin = lo, xmax = hi), height = 0, alpha = 0.9) +
    ggplot2::geom_point(size = 1.4) +
    {
      if (zero_line) ggplot2::geom_vline(xintercept = 0, colour = "red", linetype = "dashed")
      else ggplot2::geom_blank()
    } +
    ggplot2::labs(
      title = "Readout coefficients: 95% credible intervals",
      subtitle = if (!is.null(top_k)) sprintf("Top %d by |median| • red line at 0", top_k) else "All coefficients • red line at 0",
      x = "value",
      y = NULL
    )
}

plot_beta_forest_summary <- function(beta_hat,
                                     lo,
                                     hi,
                                     term_names = NULL,
                                     top_k = NULL,
                                     zero_line = TRUE,
                                     title = "Readout coefficients: IJ-corrected 95% band") {
  stopifnot(length(beta_hat) == length(lo), length(beta_hat) == length(hi))
  p <- length(beta_hat)
  if (is.null(term_names) || length(term_names) != p) {
    term_names <- paste0("β", seq_len(p))
  }

  df <- tibble::tibble(
    term   = term_names,
    lo     = as.numeric(lo),
    med    = as.numeric(beta_hat),
    hi     = as.numeric(hi),
    width  = hi - lo,
    absmed = abs(med)
  )

  if (!is.null(top_k)) {
    df <- df %>% dplyr::arrange(dplyr::desc(absmed)) %>% dplyr::slice_head(n = top_k)
  }

  ggplot2::ggplot(df, ggplot2::aes(y = reorder(term, absmed), x = med)) +
    theme_exdqlm() +
    ggplot2::geom_errorbarh(ggplot2::aes(xmin = lo, xmax = hi), height = 0, alpha = 0.9) +
    ggplot2::geom_point(size = 1.4) +
    {
      if (zero_line) ggplot2::geom_vline(xintercept = 0, colour = "red", linetype = "dashed")
      else ggplot2::geom_blank()
    } +
    ggplot2::labs(
      title    = title,
      subtitle = if (!is.null(top_k)) sprintf("Top %d by |median| • red line at 0", top_k) else "All coefficients • red line at 0",
      x = "value",
      y = NULL
    )
}

get_exal_param_draws <- function(fit, p, nd = 2000, gamma_bounds = NULL, seed = NULL) {
  stopifnot(inherits(fit, "exal_vb"))
  if (!is.null(seed)) set.seed(seed)
  if (!exists("exal_vb_posterior_draws", mode = "function")) {
    stop("exal_vb_posterior_draws() not found; cannot get parameter draws.")
  }
  dr <- exal_vb_posterior_draws(fit, nd = nd)
  if (!is.null(dr$beta) && is.matrix(dr$beta) && ncol(dr$beta) != p) {
    stop(sprintf("exal_vb_posterior_draws(): expected %d columns in beta, got %d", p, ncol(dr$beta)))
  }
  list(gamma = dr$gamma, sigma = dr$sigma, beta = dr$beta, gamma_bounds = gamma_bounds)
}

ij_sd_for_functional <- function(F_all, loglik_mat, n_obs) {
  stopifnot(is.matrix(F_all), is.matrix(loglik_mat))
  M_eff <- nrow(F_all)
  K     <- ncol(F_all)
  if (M_eff < 2L || n_obs < 2L || K < 1L) return(rep(0, K))

  F_centered <- sweep(F_all,     2L, colMeans(F_all),     "-")
  L_centered <- sweep(loglik_mat, 2L, colMeans(loglik_mat), "-")

  Cmat <- crossprod(F_centered, L_centered) / (M_eff - 1)
  I_mat      <- n_obs * Cmat
  I_bar      <- rowMeans(I_mat)
  I_centered <- sweep(I_mat, 1L, I_bar, "-")

  var_ij <- rowSums(I_centered^2) / (n_obs * (n_obs - 1))
  var_ij <- pmax(var_ij, 0)
  sqrt(var_ij)
}

compute_mu_bands_with_ij <- function(
  X_train,
  y_train_keep,
  X_fc1,
  p0,
  param_draws,
  use_ij = use_ij_correction
) {
  stopifnot(is.matrix(X_train), is.matrix(X_fc1))

  beta_draws  <- param_draws$beta
  sigma_draws <- param_draws$sigma
  gamma_draws <- param_draws$gamma

  if (is.null(beta_draws) || !is.matrix(beta_draws)) {
    stop("compute_mu_bands_with_ij(): beta_draws is missing or not a matrix.")
  }

  M <- nrow(beta_draws)
  n <- nrow(X_train)
  H <- nrow(X_fc1)

  if (length(sigma_draws) != M || length(gamma_draws) != M) {
    stop(sprintf(
      "compute_mu_bands_with_ij(): length(sigma_draws)=%d, length(gamma_draws)=%d, but nrow(beta_draws)=%d.",
      length(sigma_draws), length(gamma_draws), M
    ))
  }

  finite_draw <- rep(TRUE, M)
  loglik_mat  <- NULL

  mu_mat_tr <- X_train %*% t(beta_draws)
  mu_mat_fc <- X_fc1   %*% t(beta_draws)

  mu_draws_tr_TxM <- mu_mat_tr
  mu_draws_fc_TxM <- mu_mat_fc

  mu_qs_tr <- band_from_draws(mu_draws_tr_TxM, level = 0.95, target_len = n)
  mu_qs_fc <- band_from_draws(mu_draws_fc_TxM, level = 0.95, target_len = H)

  mu_hat_tr <- mu_qs_tr[, "med"]
  mu_hat_fc <- mu_qs_fc[, "med"]

  lo_post_tr <- mu_qs_tr[, "lo"]
  hi_post_tr <- mu_qs_tr[, "hi"]
  lo_post_fc <- mu_qs_fc[, "lo"]
  hi_post_fc <- mu_qs_fc[, "hi"]

  sd_ij_tr <- rep(0, n)
  sd_ij_fc <- rep(0, H)
  lo_tr    <- lo_post_tr
  hi_tr    <- hi_post_tr
  lo_fc    <- lo_post_fc
  hi_fc    <- hi_post_fc

  if (isTRUE(use_ij)) {
    loglik_full <- exal_loglik_from_mu_cpp(
      y           = y_train_keep,
      mu_mat      = mu_mat_tr,
      sigma_draws = sigma_draws,
      gamma_draws = gamma_draws,
      p0          = p0
    )

    finite_draw <- apply(is.finite(loglik_full), 1L, all)
    M_eff       <- sum(finite_draw)
    n_obs       <- length(y_train_keep)

    if (M_eff < 2L || n_obs < 2L) {
      warning("compute_mu_bands_with_ij(): IJ skipped (too few finite draws or obs); using posterior-only μ bands.")
      loglik_mat  <- NULL
      finite_draw <- rep(TRUE, M)
    } else {
      loglik_mat      <- loglik_full[finite_draw, , drop = FALSE]
      mu_draws_tr_TxM <- mu_draws_tr_TxM[, finite_draw, drop = FALSE]
      mu_draws_fc_TxM <- mu_draws_fc_TxM[, finite_draw, drop = FALSE]

      mu_qs_tr <- band_from_draws(mu_draws_tr_TxM, level = 0.95, target_len = n)
      mu_qs_fc <- band_from_draws(mu_draws_fc_TxM, level = 0.95, target_len = H)

      mu_hat_tr <- mu_qs_tr[, "med"]
      mu_hat_fc <- mu_qs_fc[, "med"]

      lo_post_tr <- mu_qs_tr[, "lo"]
      hi_post_tr <- mu_qs_tr[, "hi"]
      lo_post_fc <- mu_qs_fc[, "lo"]
      hi_post_fc <- mu_qs_fc[, "hi"]

      F_tr  <- t(mu_draws_tr_TxM)
      F_fc  <- t(mu_draws_fc_TxM)
      F_all <- cbind(F_tr, F_fc)

      sd_ij_all <- ij_sd_for_functional(F_all = F_all, loglik_mat = loglik_mat, n_obs = n_obs)
      sd_ij_tr <- sd_ij_all[seq_len(n)]
      sd_ij_fc <- sd_ij_all[n + seq_len(H)]

      sd_total_tr <- sd_ij_tr
      sd_total_fc <- sd_ij_fc

      alpha <- 0.05
      z_975 <- stats::qnorm(1 - alpha / 2)
      lo_tr <- mu_hat_tr - z_975 * sd_total_tr
      hi_tr <- mu_hat_tr + z_975 * sd_total_tr
      lo_fc <- mu_hat_fc - z_975 * sd_total_fc
      hi_fc <- mu_hat_fc + z_975 * sd_total_fc
    }
  }

  draw_idx_keep <- if (!is.null(loglik_mat)) which(finite_draw) else NULL

  list(
    mu_draws_tr   = mu_draws_tr_TxM,
    mu_draws_fc   = mu_draws_fc_TxM,
    mu_hat_tr     = mu_hat_tr,
    mu_hat_fc     = mu_hat_fc,
    lo_tr         = lo_tr,
    hi_tr         = hi_tr,
    lo_fc         = lo_fc,
    hi_fc         = hi_fc,
    lo_post_tr    = lo_post_tr,
    hi_post_tr    = hi_post_tr,
    lo_post_fc    = lo_post_fc,
    hi_post_fc    = hi_post_fc,
    loglik_mat    = loglik_mat,
    draw_idx_keep = draw_idx_keep
  )
}

# --- Per-p fit + posterior predictive + frames (parity object structure) ------
fit_and_forecast_p <- function(p0) {
  # Index of this quantile in p_vec
  idx_p <- which.min(abs(p_vec - p0))

  # Beta prior (ridge or RHS)
  beta_type <- tolower(vb_prior_beta_type %||% "ridge")
  if (!beta_type %in% c("ridge", "rhs")) {
    stop(sprintf("Unknown beta prior type '%s' (expected 'ridge' or 'rhs')", beta_type))
  }
  tau2_beta_p <- if (!is.null(vb_prior_beta_tau2)) vb_prior_beta_tau2 else 1e4
  beta_prior_obj <- if (beta_type == "rhs") {
    if (is.null(vb_prior_beta_rhs) || !is.list(vb_prior_beta_rhs)) {
      stop("vb$priors$beta$rhs must be a YAML mapping (list).")
    }
    beta_prior("rhs", rhs = vb_prior_beta_rhs)
  } else {
    beta_prior("ridge", ridge = list(tau2 = tau2_beta_p))
  }

  vb_args_p <- vb_args_base
  vb_args_p$tol     <- vb_tol_for(p0)
  vb_args_p$tol_par <- vb_tol_par_for(p0)

  gamma_init_p <- if (!is.null(vb_init_gamma)) vb_init_gamma[idx_p] else 0
  sigma_init_p <- if (!is.null(vb_init_sigma)) vb_init_sigma[idx_p] else 1

  gamma_mu0_p <- if (!is.null(vb_prior_gamma_mu0)) vb_prior_gamma_mu0[idx_p] else 0
  gamma_s20_p <- if (!is.null(vb_prior_gamma_s20)) vb_prior_gamma_s20[idx_p] else 10

  sigma_a_p <- if (!is.null(vb_prior_sigma_a)) vb_prior_sigma_a[idx_p] else 1
  sigma_b_p <- if (!is.null(vb_prior_sigma_b)) vb_prior_sigma_b[idx_p] else 1

  fit_args <- list(
    y            = y_tr_keep,
    X            = X_train,
    p0           = p0,
    gamma_bounds = c(L.fn(p0), U.fn(p0)),
    a_sigma      = sigma_a_p,
    b_sigma      = sigma_b_p,
    max_iter     = vb_args_p$max_iter,
    tol          = vb_args_p$tol,
    tol_par      = vb_args_p$tol_par,
    n_samp_xi    = vb_args_p$n_samp_xi,
    verbose      = vb_args_p$verbose,
    init         = list(gamma = gamma_init_p, sigma = sigma_init_p),
    beta_prior_obj = beta_prior_obj
  )

  if (!is.null(vb_prior_gamma_mu0)) {
    fit_args$prior_gamma_mu0 <- gamma_mu0_p
    fit_args$prior_gamma_s20 <- gamma_s20_p
    fit_args$log_prior_gamma <- function(g) {
      sum(stats::dnorm(g, mean = gamma_mu0_p, sd = sqrt(gamma_s20_p), log = TRUE))
    }
  } else {
    fit_args$log_prior_gamma <- function(g) 0
  }

  fit_exal <- timed(
    sprintf("fit_exAL_on_X_train(p=%s, prior=%s)", fmt_p(p0), beta_type),
    do.call(exal_ldvb_fit, fit_args)
  )

  if (isTRUE(readout_scale) && !is.null(readout_scale_info)) {
    if (is.null(fit_exal$misc)) fit_exal$misc <- list()
    fit_exal$misc$readout_scale <- readout_scale_info
  }

  # ---- Parameter draws for IJ + diagnostics -------------------------------
  gamma_bounds_here <- c(L.fn(p0), U.fn(p0))
  param_draws <- get_exal_param_draws(
    fit_exal,
    p            = ncol(X_train),
    nd           = ij_nd_draws,
    gamma_bounds = gamma_bounds_here,
    seed         = synth_seed + round(1000 * p0)
  )

  # ---- μ bands + IJ correction --------------------------------------------
  mu_ij <- compute_mu_bands_with_ij(
    X_train      = X_train,
    y_train_keep = y_tr_keep,
    X_fc1        = X_fc1,
    p0           = p0,
    param_draws  = param_draws,
    use_ij       = use_ij_correction
  )

  # IJ correction for beta coefficients
  beta_ij <- NULL
  if (isTRUE(use_ij_correction) &&
      !is.null(mu_ij$loglik_mat) &&
      !is.null(mu_ij$draw_idx_keep)) {

    beta_draws_full <- param_draws$beta
    if (!is.null(beta_draws_full) && is.matrix(beta_draws_full) &&
        isTRUE(readout_scale) && !is.null(readout_scale_info)) {
      beta_draws_full <- readout_unscale_beta(beta_draws_full, readout_scale_info)
    }
    if (!is.null(beta_draws_full) && is.matrix(beta_draws_full)) {
      draw_idx_keep <- mu_ij$draw_idx_keep
      if (length(draw_idx_keep) >= 2L) {
        beta_draws_eff <- beta_draws_full[draw_idx_keep, , drop = FALSE]
        M_eff_beta     <- nrow(beta_draws_eff)
        if (M_eff_beta >= 2L) {
          F_beta <- beta_draws_eff
          sd_ij_beta <- ij_sd_for_functional(
            F_all      = F_beta,
            loglik_mat = mu_ij$loglik_mat,
            n_obs      = length(y_tr_keep)
          )
          beta_hat     <- apply(beta_draws_eff, 2L, stats::median)
          sd_post_beta <- matrixStats::colSds(beta_draws_eff)
          alpha      <- 0.05
          z_975      <- stats::qnorm(1 - alpha / 2)
          lo_beta_ij <- beta_hat - z_975 * sd_ij_beta
          hi_beta_ij <- beta_hat + z_975 * sd_ij_beta
          beta_ij <- list(
            beta_hat = beta_hat,
            sd_post  = sd_post_beta,
            sd_ij    = sd_ij_beta,
            lo_ij    = lo_beta_ij,
            hi_ij    = hi_beta_ij
          )
        }
      }
    }
  }
  param_draws$beta_ij <- beta_ij

  # Back-transform μ bands & draws to original units
  mu_ij$mu_draws_tr <- bt_y(mu_ij$mu_draws_tr)
  mu_ij$mu_draws_fc <- bt_y(mu_ij$mu_draws_fc)
  mu_ij$mu_hat_tr   <- bt_y(mu_ij$mu_hat_tr)
  mu_ij$mu_hat_fc   <- bt_y(mu_ij$mu_hat_fc)
  mu_ij$lo_tr       <- bt_y(mu_ij$lo_tr)
  mu_ij$hi_tr       <- bt_y(mu_ij$hi_tr)
  mu_ij$lo_fc       <- bt_y(mu_ij$lo_fc)
  mu_ij$hi_fc       <- bt_y(mu_ij$hi_fc)
  mu_ij$lo_post_tr  <- bt_y(mu_ij$lo_post_tr)
  mu_ij$hi_post_tr  <- bt_y(mu_ij$hi_post_tr)
  mu_ij$lo_post_fc  <- bt_y(mu_ij$lo_post_fc)
  mu_ij$hi_post_fc  <- bt_y(mu_ij$hi_post_fc)

  # ---- Posterior predictive (train + forecast) ----------------------------
  pp_tr <- timed(
    sprintf("posterior_predict TRAIN (p=%s, nd=%d)", fmt_p(p0), nd_draws),
    exal_vb_posterior_predict(fit_exal, X_new = X_train, nd = nd_draws, chunk = chunk_sz)
  )
  yrep_tr <- bt_y(pp_tr$yrep)
  y_tr_keep_bt <- bt_y(y_tr_keep)

  df_mu_tr <- tibble::tibble(
    h  = seq_along(keep_train_abs),
    p0 = p0,
    mu = mu_ij$mu_hat_tr,
    lo = mu_ij$lo_tr,
    hi = mu_ij$hi_tr,
    band_type = if (isTRUE(use_ij_correction)) "IJ" else "posterior",
    y  = y_tr_keep_bt
  )
  df_pred_tr <- tibble::tibble(
    h      = seq_along(keep_train_abs),
    p0     = p0,
    q_pred = quantile_by_time(yrep_tr, p0, length(y_tr_keep)),
    y      = y_tr_keep_bt
  )
  if (isTRUE(use_ij_correction)) {
    df_pred_tr <- df_pred_tr %>%
      dplyr::mutate(
        q_hat_ij  = mu_ij$mu_hat_tr,
        lo_q_ij   = mu_ij$lo_tr,
        hi_q_ij   = mu_ij$hi_tr,
        lo_q_post = mu_ij$lo_post_tr,
        hi_q_post = mu_ij$hi_post_tr
      )
  }

  # ---- Forecast via lattice (multi-step posterior predictive) -------------
  fit_meta <- shared_fit$meta
  fit_meta$readout_spec <- readout_spec
  fit_q <- list(
    fit       = fit_exal,
    X         = X_train,
    y_fit     = y_tr_keep,
    reservoir = shared_fit$reservoir,
    states    = shared_fit$states,
    meta      = fit_meta
  )
  class(fit_q) <- "qdesn_fit"

  fore <- timed(
    sprintf("forecast_lattice(p=%s, H=%d, nd=%d, mix=%d)", fmt_p(p0), forecast_horizon, nd_draws, mix_nd),
    forecast_lattice.qdesn_fit(
      fit_q,
      y_all       = y_full,
      origins     = origins,
      H           = forecast_horizon,
      nd          = nd_draws,
      xreg_all    = xreg_all,
      y_obs_last  = T_use,
      lead_weights = lead_weights,
      mix_nd      = mix_nd,
      chunk       = chunk_sz,
      seed        = synth_seed + round(1000 * p0),
      keep_origin_draws = isTRUE(keep_draws) || isTRUE(lead_eval_enabled) || isTRUE(do_fan_charts)
    )
  )

  if (isTRUE(lead_eval_enabled)) {
    if (is.null(fore$yrep_by_origin)) {
      message("[lead_eval] missing per-origin draws; lead evaluation will be skipped.")
    } else {
      lead_eval_store[[idx_p]] <<- lapply(
        fore$yrep_by_origin,
        function(mat) mat[eval_leads, , drop = FALSE]
      )
    }
  }

  targets_all <- fore$targets
  idx_obs <- which(targets_all <= T_use)
  if (length(idx_obs) != H_forecast) {
    stop(sprintf(
      "Forecast lattice mismatch: expected %d observed targets, got %d.",
      H_forecast, length(idx_obs)
    ))
  }

  yrep_fc_full     <- bt_y(fore$mix$y)
  mu_draws_fc_full <- bt_y(fore$mix$mu)

  yrep_fc     <- yrep_fc_full[idx_obs, , drop = FALSE]
  mu_draws_fc <- mu_draws_fc_full[idx_obs, , drop = FALSE]
  y_fc_bt     <- bt_y(y_fc)

  mu_qs_fc  <- band_from_draws(mu_draws_fc, level = 0.95, target_len = length(idx_obs))
  mu_hat_fc <- mu_qs_fc[, "med"]
  lo_fc     <- mu_qs_fc[, "lo"]
  hi_fc     <- mu_qs_fc[, "hi"]

  df_mu_fc <- tibble::tibble(
    h  = seq_len(H_forecast),
    p0 = p0,
    mu = mu_hat_fc,
    lo = lo_fc,
    hi = hi_fc,
    band_type = "posterior",
    y  = y_fc_bt
  )
  df_pred_fc <- tibble::tibble(
    h      = seq_len(H_forecast),
    p0     = p0,
    q_pred = quantile_by_time(yrep_fc, p0, H_forecast),
    y      = y_fc_bt
  )

  forecast_full <- list(
    targets      = targets_all,
    yrep_mix     = yrep_fc_full,
    mu_draws_mix = mu_draws_fc_full
  )
  forecast_full$origins <- fore$origins
  if (isTRUE(keep_draws)) {
    forecast_full$yrep_by_origin <- fore$yrep_by_origin
    forecast_full$mu_by_origin   <- fore$mu_by_origin
  } else if (isTRUE(do_fan_charts)) {
    forecast_full$yrep_by_origin <- fore$yrep_by_origin
  }

  list(
    fit_train   = list(fit = fit_exal, meta = list(keep_idx = keep_train_abs)),
    yrep_fc     = yrep_fc,
    mu_draws_fc = mu_draws_fc,
    df_mu_fc    = df_mu_fc,
    df_pred_fc  = df_pred_fc,
    yrep_tr     = yrep_tr,
    mu_draws_tr = mu_ij$mu_draws_tr,
    df_mu_tr    = df_mu_tr,
    df_pred_tr  = df_pred_tr,
    param_draws = param_draws,
    forecast_full = forecast_full
  )
}

fits_fc <- lapply(p_vec, fit_and_forecast_p)
names(fits_fc) <- paste0("p=", p_vec)

# --- Per-p forecast/train plots for μ̂ band (no true overlays) -----------------
plot_mu_band_real <- function(df, p0, scope = "Forecast", window = 200L) {
  i2 <- max(df$h); i1 <- max(1L, i2 - window + 1L)
  d  <- dplyr::filter(df, dplyr::between(h, i1, i2))
  p_emp <- mean(d$y <= d$mu, na.rm = TRUE)            # descriptive; not a target
  w_med <- stats::median(d$hi - d$lo, na.rm = TRUE)   # median posterior width for μ̂
  band_type <- if ("band_type" %in% names(df)) unique(df$band_type)[1] else if (isTRUE(use_ij_correction)) "IJ" else "posterior"
  band_label <- if (identical(band_type, "IJ")) "IJ-corrected 95% band for μ̂" else "μ̂ ±95% posterior band"
  ggplot2::ggplot(d, ggplot2::aes(x = h)) + theme_exdqlm() +
    ggplot2::labs(
      title = sprintf("%s: %s (model at p=%s)", scope, band_label, scales::percent(p0, 1)),
      subtitle = paste(
        sprintf("Pr(y ≤ μ̂)=%s", scales::percent(p_emp, 0.1)),
        sprintf("median band width=%.3f", w_med),
        sep = " • "
      ),
      caption = caption_exdqlm(window, nd_draws),
      x = "time", y = "value"
    ) +

    ggplot2::geom_ribbon(ggplot2::aes(ymin = lo, ymax = hi),
                         fill = scales::alpha(col_map[fmt_p(p0)], 0.22), colour = NA) +
    ggplot2::geom_line(ggplot2::aes(y = mu, colour = "mu"),   linewidth = 0.95) +
    ggplot2::geom_line(ggplot2::aes(y = y,  colour = "data"), linewidth = 0.6, alpha = 0.9) +
    ggplot2::scale_color_manual(name = "", values = c(mu = ACCENT_ORANGE, data = "#6b7280"))
}

synthesize_fan_by_origin <- function(yrep_by_origin_list, p_vec, origins, horizon, t_vec,
                                     stride = 1L, level = 0.95,
                                     synth_isotonic = TRUE, synth_rearrange = TRUE,
                                     synth_grid_M = 2001L, synth_nsamp = 4000L,
                                     synth_seed = 123L, bt_fn = NULL) {
  if (is.null(yrep_by_origin_list) || !length(yrep_by_origin_list)) {
    return(tibble::tibble())
  }
  if (length(yrep_by_origin_list) != length(p_vec)) {
    message("[fan_charts] yrep_by_origin_list length mismatch; skipping fan charts.")
    return(tibble::tibble())
  }
  stride <- max(1L, as.integer(stride))
  keep_idx <- seq_along(origins)
  if (stride > 1L) keep_idx <- keep_idx[seq(1L, length(keep_idx), by = stride)]
  t_max <- length(t_vec)
  out <- dplyr::bind_rows(lapply(keep_idx, function(i) {
    draws_list <- lapply(seq_along(yrep_by_origin_list), function(k) {
      yrep_by_origin_list[[k]][[i]]
    })
    if (any(vapply(draws_list, is.null, logical(1)))) return(NULL)
    if (any(vapply(draws_list, nrow, integer(1)) != horizon)) return(NULL)

    synth_i <- exdqlm_synthesize_from_draws(
      draws_list = draws_list,
      p = p_vec,
      enforce_isotonic = synth_isotonic,
      rearrange = synth_rearrange,
      grid_M = synth_grid_M,
      n_samp = synth_nsamp,
      seed = synth_seed + as.integer(origins[i]),
      T_expected = horizon
    )
    qs <- band_from_draws(synth_i$draws, level = level, target_len = horizon)
    if (!is.null(bt_fn)) {
      qs <- bt_fn(qs)
    }

    leads <- seq_len(horizon)
    target_idx <- origins[i] + leads
    ok <- which(target_idx <= t_max)
    if (!length(ok)) return(NULL)
    tibble::tibble(
      origin     = origins[i],
      lead       = leads[ok],
      target_idx = target_idx[ok],
      t          = t_vec[target_idx[ok]],
      lo         = qs[ok, "lo"],
      hi         = qs[ok, "hi"],
      med        = qs[ok, "med"]
    )
  }))
  dplyr::arrange(out, origin, t)
}

plot_fan_overlap <- function(fan_df, y_obs_df, title, horizon, stride,
                             fill_col = FAN_FILL) {
  if (is.null(fan_df) || !nrow(fan_df)) return(NULL)
  t_rng <- range(fan_df$t, na.rm = TRUE)
  y_obs_df <- dplyr::filter(y_obs_df, dplyr::between(t, t_rng[1], t_rng[2]))
  col_fill <- scales::alpha(fill_col, 0.05)
  ggplot2::ggplot(fan_df, ggplot2::aes(x = t, group = origin)) +
    theme_exdqlm() +
    ggplot2::geom_ribbon(
      ggplot2::aes(ymin = lo, ymax = hi),
      fill = col_fill,
      colour = NA
    ) +
    ggplot2::geom_line(
      data = y_obs_df,
      ggplot2::aes(x = t, y = y),
      inherit.aes = FALSE,
      color = "#111827",
      linewidth = 0.4,
      alpha = 0.7
    ) +
    ggplot2::labs(
      title = title,
      subtitle = sprintf("stride=%d, horizon=%d", stride, horizon),
      x = "time index",
      y = "value"
    )
}

if (isTRUE(do_plots)) {
  for (k in seq_along(p_vec)) {
    p0 <- p_vec[k]
    g1 <- plot_mu_band_real(fits_fc[[k]]$df_mu_fc, p0, scope = "Forecast", window = fore_last_window)
    g1tr <- plot_mu_band_real(fits_fc[[k]]$df_mu_tr, p0, scope = "Train", window = train_last_window)
    band_suffix_fc <- if (isTRUE(use_ij_correction)) "_post" else ""
    band_suffix_tr <- if (isTRUE(use_ij_correction)) "_IJcorr" else ""

    timed(sprintf("plot+save forecast_mu_band(p=%s)", fmt_p(p0)), {
      print(g1)
      if (isTRUE(save_outputs)) {
        ggsave(file.path(FIGS, sprintf("forecast_mu_band%s_p=%s.png", band_suffix_fc, as.character(p0))),
               g1, width=9, height=4.8, dpi=150)
      }
    })
    timed(sprintf("plot+save train_mu_band(p=%s)", fmt_p(p0)), {
      print(g1tr)
      if (isTRUE(save_outputs)) {
        ggsave(file.path(FIGS, sprintf("train_mu_band%s_p=%s.png", band_suffix_tr, as.character(p0))),
               g1tr, width=9, height=4.8, dpi=150)
      }
    })
  }
}

# --- Overlapping forecast fan charts (95% bands) ------------------------------
if (isTRUE(do_plots) && isTRUE(do_fan_charts)) {
  y_obs_df <- tibble::tibble(
    t = idx_use,
    y = bt_y(y_full)
  )
  yrep_by_origin_list <- lapply(fits_fc, function(obj) obj$forecast_full$yrep_by_origin)
  if (any(vapply(yrep_by_origin_list, is.null, logical(1)))) {
    message("[fan_charts] missing per-origin draws; skipping synthesized fan chart.")
  } else {
    timed("fan_chart: synth", {
      fan_df <- synthesize_fan_by_origin(
        yrep_by_origin_list = yrep_by_origin_list,
        p_vec = p_vec,
        origins = fits_fc[[1]]$forecast_full$origins,
        horizon = forecast_horizon,
        t_vec   = idx_use,
        stride  = fan_stride,
        level   = 0.95,
        synth_isotonic = synth_isotonic,
        synth_rearrange = synth_rearrange,
        synth_grid_M = synth_grid_M,
        synth_nsamp = synth_nsamp,
        synth_seed  = synth_seed,
        bt_fn   = bt_y
      )
      g_fan <- plot_fan_overlap(
        fan_df = fan_df,
        y_obs_df = y_obs_df,
        title = "Overlapping forecast fans (95% band, synthesized)",
        horizon = forecast_horizon,
        stride = fan_stride,
        fill_col = FAN_FILL
      )
      if (!is.null(g_fan)) {
        print(g_fan)
        if (isTRUE(save_outputs)) {
          ggplot2::ggsave(
            file.path(FIGS, "forecast_fan_overlap_synth.png"),
            g_fan, width = 9, height = 4.8, dpi = 150
          )
        }
      }
    })
  }
}

# --- Minimal canonical single-plot exports (median p=0.50) ------
i_med <- which.min(abs(p_vec - 0.50))
p_med <- p_vec[i_med]

g_mu_fc_med <- plot_mu_band_real(fits_fc[[i_med]]$df_mu_fc, p_med, scope = "Forecast", window = fore_last_window)
g_mu_tr_med <- plot_mu_band_real(fits_fc[[i_med]]$df_mu_tr, p_med, scope = "Train",    window = train_last_window)

if (isTRUE(do_plots)) {
  print(g_mu_fc_med); print(g_mu_tr_med)
  if (isTRUE(save_outputs)) {
    if (!file.exists(file.path(FIGS, "forecast_mu_band.png")))
      ggplot2::ggsave(file.path(FIGS, "forecast_mu_band.png"), g_mu_fc_med, width=9, height=4.8, dpi=150)
    if (!file.exists(file.path(FIGS, "train_mu_band.png")))
      ggplot2::ggsave(file.path(FIGS, "train_mu_band.png"), g_mu_tr_med, width=9, height=4.8, dpi=150)
  }
}

# --- Posterior parameter plots (γ, σ, β) ------------------------------------
if (isTRUE(do_plots)) {
  for (k in seq_along(p_vec)) {
    p0 <- p_vec[k]
    pars <- fits_fc[[k]]$param_draws
    if (is.null(pars) || (!length(pars$gamma) && !length(pars$sigma) && is.null(pars$beta))) {
      message(sprintf("[warn] No parameter draws available for p=%s; skipping posterior param plots.", fmt_p(p0)))
      next
    }

    plots_left <- list()

    # γ
    if (!is.null(pars$gamma) && length(pars$gamma)) {
      qs_gam <- qs_ci(pars$gamma, 0.95)
      x_lim_g <- stats::quantile(pars$gamma, c(0.01, 0.99), names = FALSE)
      if (!all(is.finite(x_lim_g)) || x_lim_g[1] >= x_lim_g[2]) {
        x_lim_g <- range(pars$gamma[is.finite(pars$gamma)])
      }
      sub_txt_g <- sprintf(
        "median=%.3f, 95%% CI=[%.3f, %.3f]\nSupport bounds=[%.3f, %.3f]",
        qs_gam["med"], qs_gam["lo"], qs_gam["hi"],
        pars$gamma_bounds[1], pars$gamma_bounds[2]
      )
      df_gam <- tibble::tibble(x = pars$gamma)
      plots_left$gamma <-
        ggplot2::ggplot(df_gam, ggplot2::aes(x = x)) +
        theme_exdqlm() +
        ggplot2::geom_histogram(bins = 100, colour = "white") +
        ggplot2::geom_vline(xintercept = qs_gam["med"], linetype = "solid") +
        ggplot2::geom_vline(xintercept = c(qs_gam["lo"], qs_gam["hi"]),
                            linetype = "dashed", alpha = 0.8) +
        ggplot2::labs(
          title    = "Posterior of γ",
          subtitle = sub_txt_g,
          x        = "γ",
          y        = "count"
        ) +
        ggplot2::coord_cartesian(xlim = x_lim_g)
    }

    # σ (optionally back-transform to original units)
    if (!is.null(pars$sigma) && length(pars$sigma)) {
      sig_draws <- pars$sigma
      if (isTRUE(scale_y)) sig_draws <- sig_draws * y_sd
      qs_sig <- qs_ci(sig_draws, 0.95)
      x_lim_s <- stats::quantile(sig_draws, c(0.01, 0.99), names = FALSE)
      if (!all(is.finite(x_lim_s)) || x_lim_s[1] >= x_lim_s[2]) {
        x_lim_s <- range(sig_draws[is.finite(sig_draws)])
      }
      df_sig <- tibble::tibble(x = sig_draws)
      plots_left$sigma <-
        ggplot2::ggplot(df_sig, ggplot2::aes(x = x)) +
        theme_exdqlm() +
        ggplot2::geom_histogram(bins = 100, colour = "white") +
        ggplot2::geom_vline(xintercept = qs_sig["med"], linetype = "solid") +
        ggplot2::geom_vline(xintercept = c(qs_sig["lo"], qs_sig["hi"]),
                            linetype = "dashed", alpha = 0.8) +
        ggplot2::labs(
          title    = "Posterior of σ",
          subtitle = sprintf("median=%.3f, 95%% CI=[%.3f, %.3f]", qs_sig["med"], qs_sig["lo"], qs_sig["hi"]),
          x        = "σ",
          y        = "count"
        ) +
        ggplot2::coord_cartesian(xlim = x_lim_s)
    }

    if (length(plots_left)) {
      g_params <- Reduce(`|`, plots_left)
      print(g_params)
      if (isTRUE(save_outputs)) {
        ggsave(file.path(FIGS, sprintf("posterior_gamma_sigma_p=%s.png", as.character(p0))),
               g_params, width = 10.5, height = 4.8, dpi = 150)
      }
    }

    # β forest (all + top-K)
    if (!is.null(pars$beta) && is.matrix(pars$beta)) {
      beta_draws_plot <- pars$beta
      scale_info <- fits_fc[[k]]$fit_train$fit$misc$readout_scale %||% NULL
      if (!is.null(scale_info) && isTRUE(scale_info$scaled)) {
        beta_draws_plot <- readout_unscale_beta(beta_draws_plot, scale_info)
      }
      term_names <- colnames(X_train)
      if (is.null(term_names)) term_names <- paste0("β", seq_len(ncol(beta_draws_plot)))
      p_all <- ncol(beta_draws_plot)

      g_beta_all <- plot_beta_forest(beta_draws_plot, term_names = term_names, top_k = NULL)
      g_beta_top <- plot_beta_forest(beta_draws_plot, term_names = term_names, top_k = min(50L, p_all))

      print(g_beta_all); print(g_beta_top)
      if (isTRUE(save_outputs)) {
        if (p_all <= 250L) {
          height_all <- max(5, 0.18 * p_all)
          ggplot2::ggsave(
            file.path(FIGS, sprintf("posterior_beta_forest_ALL_p=%s.png", as.character(p0))),
            g_beta_all, width = 9.5, height = height_all, dpi = 150
          )
        } else {
          message(sprintf("[info] Skipping posterior_beta_forest_ALL_p=%s (p=%d too large).", fmt_p(p0), p_all))
        }
        ggplot2::ggsave(
          file.path(FIGS, sprintf("posterior_beta_forest_TOP50_p=%s.png", as.character(p0))),
          g_beta_top, width = 9.5, height = 10, dpi = 150
        )
      }

      # IJ β forest (top-K) if available
      if (isTRUE(use_ij_correction) &&
          !is.null(pars$beta_ij) &&
          !is.null(pars$beta_ij$beta_hat) &&
          !is.null(pars$beta_ij$lo_ij) &&
          !is.null(pars$beta_ij$hi_ij)) {

        beta_hat_ij <- pars$beta_ij$beta_hat
        lo_ij_beta  <- pars$beta_ij$lo_ij
        hi_ij_beta  <- pars$beta_ij$hi_ij
        len_beta <- length(beta_hat_ij)
        if (len_beta != p_all) {
          warning(sprintf("[warn] beta_ij length (%d) != p_all (%d) for p=%s; skipping IJ β forest.",
                          len_beta, p_all, fmt_p(p0)))
        } else {
          g_beta_ij_top <- plot_beta_forest_summary(
            beta_hat   = beta_hat_ij,
            lo         = lo_ij_beta,
            hi         = hi_ij_beta,
            term_names = term_names,
            top_k      = min(50L, p_all),
            title      = "Readout coefficients: IJ-corrected 95% band"
          )
          print(g_beta_ij_top)
          if (isTRUE(save_outputs)) {
            ggplot2::ggsave(
              file.path(FIGS, sprintf("posterior_beta_forest_IJ_TOP50_p=%s.png", as.character(p0))),
              g_beta_ij_top, width = 9.5, height = 10, dpi = 150
            )
          }
        }
      }
    }
  }
}

# --- ELBO traces (same as sim) -----------------------------------------------
k_burn <- 20
elbo_df <- dplyr::bind_rows(lapply(seq_along(fits_fc), function(i) {
  tr <- fits_fc[[i]]$fit_train$fit$misc$elbo
  if (is.null(tr) || !length(tr)) return(tibble::tibble())
  tibble::tibble(p0 = p_vec[i], iter = seq_along(tr), elbo = as.numeric(tr))
}))
if (isTRUE(do_plots) && nrow(elbo_df)) {
  elbo_df <- elbo_df |> dplyr::filter(iter > k_burn) |> dplyr::mutate(p0_chr = factor(fmt_p(p0)))
  g_elbo <- ggplot2::ggplot(elbo_df, ggplot2::aes(x = iter, y = elbo, colour = p0_chr)) +
    theme_exdqlm() + ggplot2::labs(x="VB iteration", y="ELBO", colour="p0",
    title="ELBO traces across quantile models", subtitle=sprintf("First k=%d iterations omitted", k_burn)) +
    ggplot2::geom_line(linewidth=0.8, alpha=0.95) + ggplot2::scale_color_manual(values = col_map)
  print(g_elbo)
  if (isTRUE(save_outputs)) ggsave(file.path(FIGS, sprintf("%s%d.png", nm("elbo_prefix","elbo_traces_skip_k="), k_burn)), g_elbo, width=9, height=4.8, dpi=150)
}

# --- γ and σ traces -----------------------------------------------------------
gamma_df <- dplyr::bind_rows(lapply(seq_along(fits_fc), function(i) {
  tr <- fits_fc[[i]]$fit_train$fit$misc$gamma_trace
  if (is.null(tr) || !length(tr)) return(tibble::tibble())
  tibble::tibble(p0 = p_vec[i], iter = seq_along(tr), gamma = as.numeric(tr))
}))

sigma_df <- dplyr::bind_rows(lapply(seq_along(fits_fc), function(i) {
  tr <- fits_fc[[i]]$fit_train$fit$misc$sigma_trace
  if (is.null(tr) || !length(tr)) return(tibble::tibble())
  sigma_vals <- as.numeric(tr)
  if (isTRUE(scale_y)) sigma_vals <- sigma_vals * y_sd
  tibble::tibble(p0 = p_vec[i], iter = seq_along(tr), sigma = sigma_vals)
}))

if (isTRUE(do_plots) && nrow(gamma_df) && nrow(sigma_df)) {
  gamma_df <- gamma_df |> dplyr::filter(iter > k_burn) |>
    dplyr::mutate(p0_chr = factor(fmt_p(p0), levels = fmt_p(p_vec)))
  sigma_df <- sigma_df |> dplyr::filter(iter > k_burn) |>
    dplyr::mutate(p0_chr = factor(fmt_p(p0), levels = fmt_p(p_vec)))

  g_gamma <- ggplot2::ggplot(gamma_df, ggplot2::aes(x = iter, y = gamma, colour = p0_chr)) +
    theme_exdqlm() +
    ggplot2::labs(x = "VB iteration", y = "γ", colour = "p0",
                  title = "γ traces across quantile models",
                  subtitle = sprintf("First k=%d iterations omitted", k_burn)) +
    ggplot2::geom_line(linewidth = 0.8, alpha = 0.95) +
    ggplot2::scale_color_manual(values = col_map)

  g_sigma <- ggplot2::ggplot(sigma_df, ggplot2::aes(x = iter, y = sigma, colour = p0_chr)) +
    theme_exdqlm() +
    ggplot2::labs(x = "VB iteration", y = "σ", colour = "p0",
                  title = "σ traces across quantile models",
                  subtitle = sprintf("First k=%d iterations omitted", k_burn)) +
    ggplot2::geom_line(linewidth = 0.8, alpha = 0.95) +
    ggplot2::scale_color_manual(values = col_map)

  g_gamma_sigma <- g_gamma | g_sigma
  print(g_gamma_sigma)
  if (isTRUE(save_outputs)) {
    ggplot2::ggsave(
      file.path(FIGS, sprintf("gamma_sigma_traces_skip_k=%d.png", k_burn)),
      g_gamma_sigma, width = 11, height = 4.8, dpi = 150
    )
  }
}

# --- LD safeguard new_term traces -------------------------------------------
newterm_df <- dplyr::bind_rows(lapply(seq_along(fits_fc), function(i) {
  tr <- fits_fc[[i]]$fit_train$fit$misc$new_term_trace
  if (is.null(tr) || !length(tr)) return(tibble::tibble())
  tibble::tibble(p0 = p_vec[i], iter = seq_along(tr), new_term = as.numeric(tr))
}))

if (isTRUE(do_plots) && nrow(newterm_df)) {
  newterm_df <- newterm_df |>
    dplyr::filter(iter > k_burn, is.finite(new_term)) |>
    dplyr::mutate(p0_chr = factor(fmt_p(p0), levels = fmt_p(p_vec)))

  g_newterm <- ggplot2::ggplot(newterm_df, ggplot2::aes(x = iter, y = new_term, colour = p0_chr)) +
    theme_exdqlm() +
    ggplot2::labs(
      x = "VB iteration", y = "|ΔE[γ]| + |ΔE[σ]|", colour = "p0",
      title = "LD safeguard term traces across quantile models",
      subtitle = sprintf("First k=%d iterations omitted", k_burn)
    ) +
    ggplot2::geom_line(linewidth = 0.8, alpha = 0.95) +
    ggplot2::scale_color_manual(values = col_map)

  print(g_newterm)
  if (isTRUE(save_outputs)) {
    ggplot2::ggsave(
      file.path(FIGS, sprintf("new_term_traces_skip_k=%d.png", k_burn)),
      g_newterm, width = 9, height = 4.8, dpi = 150
    )
  }
}

# --- RHS latent traces (if RHS prior used) -----------------------------------
rhs_tau_df <- dplyr::bind_rows(lapply(seq_along(fits_fc), function(i) {
  fit <- fits_fc[[i]]$fit_train$fit
  if (is.null(fit) || is.null(fit$beta_prior) || fit$beta_prior$type != "rhs") return(tibble::tibble())
  tr <- fit$misc$rhs_tau_trace
  if (is.null(tr) || !length(tr)) return(tibble::tibble())
  tibble::tibble(p0 = p_vec[i], iter = seq_along(tr), tau = as.numeric(tr))
}))

rhs_c2_df <- dplyr::bind_rows(lapply(seq_along(fits_fc), function(i) {
  fit <- fits_fc[[i]]$fit_train$fit
  if (is.null(fit) || is.null(fit$beta_prior) || fit$beta_prior$type != "rhs") return(tibble::tibble())
  tr <- fit$misc$rhs_c2_trace
  if (is.null(tr) || !length(tr)) return(tibble::tibble())
  tibble::tibble(p0 = p_vec[i], iter = seq_along(tr), c2 = as.numeric(tr))
}))

if (isTRUE(do_plots) && nrow(rhs_tau_df) && nrow(rhs_c2_df)) {
  rhs_tau_df <- rhs_tau_df |> dplyr::filter(iter > k_burn, is.finite(tau)) |>
    dplyr::mutate(p0_chr = factor(fmt_p(p0), levels = fmt_p(p_vec)))
  rhs_c2_df <- rhs_c2_df |> dplyr::filter(iter > k_burn, is.finite(c2)) |>
    dplyr::mutate(p0_chr = factor(fmt_p(p0), levels = fmt_p(p_vec)))

  g_tau <- ggplot2::ggplot(rhs_tau_df, ggplot2::aes(x = iter, y = tau, colour = p0_chr)) +
    theme_exdqlm() +
    ggplot2::labs(x = "VB iteration", y = "tau", colour = "p0",
                  title = "RHS tau traces across quantile models",
                  subtitle = sprintf("First k=%d iterations omitted", k_burn)) +
    ggplot2::geom_line(linewidth = 0.8, alpha = 0.95) +
    ggplot2::scale_color_manual(values = col_map)

  g_c2 <- ggplot2::ggplot(rhs_c2_df, ggplot2::aes(x = iter, y = c2, colour = p0_chr)) +
    theme_exdqlm() +
    ggplot2::labs(x = "VB iteration", y = "c2", colour = "p0",
                  title = "RHS c2 traces across quantile models",
                  subtitle = sprintf("First k=%d iterations omitted", k_burn)) +
    ggplot2::geom_line(linewidth = 0.8, alpha = 0.95) +
    ggplot2::scale_color_manual(values = col_map)

  print(g_tau); print(g_c2)
  if (isTRUE(save_outputs)) {
    ggplot2::ggsave(file.path(FIGS, sprintf("rhs_tau_traces_skip_k=%d.png", k_burn)), g_tau, width = 9, height = 4.8, dpi = 150)
    ggplot2::ggsave(file.path(FIGS, sprintf("rhs_c2_traces_skip_k=%d.png", k_burn)), g_c2, width = 9, height = 4.8, dpi = 150)
  }
}

rhs_lambda_df <- dplyr::bind_rows(lapply(seq_along(fits_fc), function(i) {
  fit <- fits_fc[[i]]$fit_train$fit
  if (is.null(fit) || is.null(fit$beta_prior) || fit$beta_prior$type != "rhs") return(tibble::tibble())
  tr_mean <- fit$misc$rhs_lambda_mean_trace
  tr_min  <- fit$misc$rhs_lambda_min_trace
  tr_max  <- fit$misc$rhs_lambda_max_trace
  if (is.null(tr_mean) || !length(tr_mean)) return(tibble::tibble())
  n_iter <- length(tr_mean)
  tibble::tibble(
    p0   = p_vec[i],
    iter = seq_len(n_iter),
    lambda_mean = as.numeric(tr_mean[seq_len(n_iter)]),
    lambda_min  = as.numeric(tr_min[seq_len(n_iter)]),
    lambda_max  = as.numeric(tr_max[seq_len(n_iter)])
  )
}))

if (isTRUE(do_plots) && nrow(rhs_lambda_df)) {
  rhs_lambda_long <- rhs_lambda_df |>
    tidyr::pivot_longer(cols = dplyr::starts_with("lambda_"),
                        names_to = "stat", values_to = "lambda") |>
    dplyr::mutate(
      stat = dplyr::recode(stat, lambda_min = "min", lambda_mean = "mean", lambda_max = "max"),
      p0_chr = factor(fmt_p(p0), levels = fmt_p(p_vec))
    ) |>
    dplyr::filter(iter > k_burn, is.finite(lambda))

  g_lambda <- ggplot2::ggplot(rhs_lambda_long,
                              ggplot2::aes(x = iter, y = lambda, colour = p0_chr)) +
    theme_exdqlm() +
    ggplot2::labs(
      x = "VB iteration", y = "lambda summary", colour = "p0",
      title = "RHS lambda summaries across quantile models",
      subtitle = sprintf("First k=%d iterations omitted", k_burn)
    ) +
    ggplot2::geom_line(linewidth = 0.8, alpha = 0.95) +
    ggplot2::scale_color_manual(values = col_map) +
    ggplot2::facet_wrap(~ stat, nrow = 1, scales = "free_y")

  print(g_lambda)
  if (isTRUE(save_outputs)) {
    ggplot2::ggsave(
      file.path(FIGS, sprintf("rhs_lambda_summary_traces_skip_k=%d.png", k_burn)),
      g_lambda, width = 12, height = 4.2, dpi = 150
    )
  }
}

# --- Synthesis (forecast + train) --------------------------------------------
draws_list_fc <- lapply(fits_fc, function(obj) obj$yrep_fc)
draws_list_tr <- lapply(fits_fc, function(obj) obj$yrep_tr)

synth_fc <- timed(sprintf("synthesize_forecast_draws(T=%d,nd=%d,grid_M=%d,n_samp=%d)",
                          H_forecast, nd_draws, synth_grid_M, synth_nsamp),
  exdqlm_synthesize_from_draws(
    draws_list = draws_list_fc, p = p_vec,
    enforce_isotonic = synth_isotonic, rearrange = synth_rearrange,
    grid_M = synth_grid_M, n_samp = synth_nsamp, seed = synth_seed, T_expected = H_forecast
  )
)
T_train_keep <- nrow(draws_list_tr[[1]])
keep_train   <- fits_fc[[1]]$fit_train$meta$keep_idx
synth_tr <- timed(sprintf("synthesize_train_draws(T=%d,grid_M=%d,n_samp=%d)",
                          T_train_keep, synth_grid_M, synth_nsamp),
  exdqlm_synthesize_from_draws(
    draws_list = draws_list_tr, p = p_vec,
    enforce_isotonic = synth_isotonic, rearrange = synth_rearrange,
    grid_M = synth_grid_M, n_samp = synth_nsamp, seed = synth_seed + 1L, T_expected = T_train_keep
  )
)

# Canonical comparison grid for synthesis/metrics (same as fitted models)
p_comp <- p_vec

# Predictive band plots (same names as sim)
plot_synth_predictive_band <- function(synth_draws, y_vec, scope = "Forecast", window = 50L,
                                       fill_col = ACCENT_ORANGE, show_median = TRUE) {
  stopifnot(is.matrix(synth_draws), length(y_vec) == nrow(synth_draws))
  T_h <- nrow(synth_draws); i2 <- T_h; i1 <- max(1L, i2 - as.integer(window) + 1L)
  q_mat <- t(apply(synth_draws, 1L, stats::quantile, probs = c(0.025, 0.50, 0.975), names = FALSE))
  colnames(q_mat) <- c("q025","q50","q975")
  df <- tibble::tibble(h = seq_len(T_h), y = y_vec,
                       q025 = q_mat[, "q025"], q50 = q_mat[, "q50"], q975 = q_mat[, "q975"]) |>
        dplyr::filter(dplyr::between(h, i1, i2))
  coverage <- mean(df$y >= df$q025 & df$y <= df$q975, na.rm = TRUE)
  mean_w   <- mean(df$q975 - df$q025, na.rm = TRUE)

  ggplot2::ggplot(df, ggplot2::aes(x = h)) + theme_exdqlm() +
    ggplot2::labs(
      title   = sprintf("%s: synthesized 95%% predictive band", scope),
      subtitle = paste(
        sprintf("coverage=%s", scales::percent(coverage, 0.1)),
        sprintf("mean width=%.3f", mean_w), sep = " • "
      ),
      caption = caption_exdqlm(if (scope=="Forecast") fore_last_window else train_last_window, nd_draws),
      x = "time", y = "value"
    ) +
    ggplot2::geom_ribbon(ggplot2::aes(ymin = q025, ymax = q975),
                         fill = scales::alpha(fill_col, 0.22), colour = NA) +
    { if (isTRUE(show_median))
        ggplot2::geom_line(ggplot2::aes(y = q50, colour = "median"), linewidth = 0.8)
      else ggplot2::geom_blank() } +
    ggplot2::geom_line(ggplot2::aes(y = y, colour = "data"), linewidth = 0.75) +
    ggplot2::scale_color_manual(name = "", breaks = c("data", "median"),
                                values = c(data = "#6b7280", median = fill_col))
}

if (isTRUE(do_plots)) {
  timed("plot+save synth bands (train+forecast)", {
    g_band_fc <- plot_synth_predictive_band(
      synth_draws = synth_fc$draws, y_vec = bt_y(y_fc),
      scope = "Forecast", window = fore_last_window, fill_col = ACCENT_ORANGE, show_median = TRUE
    )
    g_band_tr <- plot_synth_predictive_band(
      synth_draws = synth_tr$draws, y_vec = bt_y(y_tr_keep),
      scope = "Train", window = train_last_window, fill_col = ACCENT_ORANGE, show_median = TRUE
    )
    print(g_band_fc); print(g_band_tr)
    if (isTRUE(save_outputs)) {
      ggsave(file.path(FIGS, "forecast_obs_with_95_band.png"), g_band_fc, width=9, height=4.8, dpi=150)
      ggsave(file.path(FIGS, "train_obs_with_95_band.png"),    g_band_tr, width=9, height=4.8, dpi=150)
    }
  })
}

# --- Lead-specific synthesized CRPS evaluation (optional) -------------------
if (isTRUE(lead_eval_enabled)) {
  timed("lead_eval: synthesized CRPS by lead", {
    if (any(vapply(lead_eval_store, function(x) is.null(x) || !length(x), logical(1)))) {
      message("[lead_eval] missing per-origin draws; skipping lead evaluation.")
    } else {
      lead_row_map <- setNames(seq_along(eval_leads), eval_leads)
      rows <- vector("list", 0L)
      row_id <- 1L

      for (lead in eval_leads) {
        lead_row <- lead_row_map[[as.character(lead)]]
        valid_idx <- which((origins + lead) <= T_use)
        if (!length(valid_idx)) next

        for (oi in valid_idx) {
          draws_list <- lapply(seq_along(p_vec), function(k) {
            mat <- lead_eval_store[[k]][[oi]]
            if (is.null(mat) || !is.matrix(mat) || nrow(mat) < lead_row) return(NULL)
            matrix(bt_y(mat[lead_row, ]), nrow = 1L)
          })
          if (any(vapply(draws_list, is.null, logical(1)))) next

          synth <- exdqlm_synthesize_from_draws(
            draws_list = draws_list, p = p_vec,
            enforce_isotonic = synth_isotonic, rearrange = synth_rearrange,
            grid_M = synth_grid_M, n_samp = synth_nsamp,
            seed = synth_seed + lead * 1000L + oi, T_expected = 1L
          )
          y_obs <- bt_y(y_full[origins[oi] + lead])
          rows[[row_id]] <- tibble::tibble(
            origin = origins[oi],
            lead = lead,
            target_idx = origins[oi] + lead,
            y_obs = y_obs,
            crps = crps_row(y_obs, as.numeric(synth$draws)),
            n_samp = ncol(synth$draws)
          )
          row_id <- row_id + 1L
        }
      }

      lead_eval_rows <- dplyr::bind_rows(rows)
      if (nrow(lead_eval_rows)) {
        lead_eval_summary <- lead_eval_rows |>
          dplyr::group_by(lead) |>
          dplyr::summarise(
            n = dplyr::n(),
            CRPS_mean = mean(crps),
            CRPS_median = stats::median(crps),
            .groups = "drop"
          )

        if (isTRUE(save_outputs)) {
          readr::write_csv(lead_eval_rows, file.path(TABLES, "lead_eval_rows.csv"))
          readr::write_csv(lead_eval_summary, file.path(TABLES, "lead_eval_summary.csv"))
        }

        if (isTRUE(do_plots)) {
          g_lead_crps <- ggplot2::ggplot(lead_eval_summary, ggplot2::aes(x = lead, y = CRPS_mean)) +
            theme_exdqlm() +
            ggplot2::geom_line(linewidth = 0.9) +
            ggplot2::geom_point(size = 2.2) +
            ggplot2::labs(
              title = "Synthesized CRPS by lead",
              subtitle = sprintf("Leads: %s", paste(eval_leads, collapse = ", ")),
              x = "lead (steps ahead)",
              y = "mean CRPS"
            )
          print(g_lead_crps)
          if (isTRUE(save_outputs)) {
            ggplot2::ggsave(file.path(FIGS, "lead_eval_crps_by_lead.png"),
                            g_lead_crps, width = 9, height = 4.8, dpi = 150)
          }
        }
      } else {
        message("[lead_eval] no valid lead rows were produced; skipping outputs.")
      }
    }
  })
  lead_eval_store <- NULL
}

# --- NEW (minimal): overlay of synthesized vs TRUE quantiles (p in taus) ----
plot_quantiles_overlay_from_compare <- function(compare_df, taus = p_comp,
                                               scope = "Forecast", window = 200L) {
  i2 <- max(compare_df$h, na.rm = TRUE)
  if (!is.finite(i2)) {
    return(ggplot2::ggplot() + theme_exdqlm() +
             ggplot2::labs(title = sprintf("%s: synthesized quantiles", scope),
                           subtitle = "No finite time index available"))
  }
  i1 <- max(1L, i2 - as.integer(window) + 1L)
  d <- dplyr::filter(compare_df, dplyr::between(h, i1, i2))

  true_cols  <- paste0("true_q_",  fmt_p(taus))
  synth_cols <- paste0("synth_q_", fmt_p(taus))

  # Long frames (will be empty for TRUE if NA)
  d_true  <- tidyr::pivot_longer(d, cols = dplyr::all_of(true_cols),
                                 names_to = "p_chr", values_to = "val") |>
             dplyr::mutate(kind="true",  p_chr = sub("true_q_",  "", .data$p_chr)) |>
             dplyr::filter(is.finite(val))

  d_synth <- tidyr::pivot_longer(d, cols = dplyr::all_of(synth_cols),
                                 names_to = "p_chr", values_to = "val") |>
             dplyr::mutate(kind="synth", p_chr = sub("synth_q_", "", .data$p_chr))

  dl <- dplyr::bind_rows(d_true, d_synth) |>
        dplyr::mutate(p_chr = factor(p_chr, levels = fmt_p(taus)))

  title_txt <- if (nrow(d_true)) sprintf("%s: synthesized vs true quantiles", scope)
               else sprintf("%s: synthesized quantiles", scope)

  ggplot2::ggplot() +
    theme_exdqlm() +
    ggplot2::labs(
      title   = title_txt,
      subtitle= sprintf("p ∈ {%s}", paste(fmt_p(taus), collapse=", ")),
      caption = caption_exdqlm(window, nd_draws),
      x = "time", y = "value", colour = "p", linetype = ""
    ) +
    ggplot2::geom_line(data = dl,
                       ggplot2::aes(x = h, y = val, colour = p_chr, linetype = kind),
                       linewidth = 0.9, na.rm = TRUE) +
    ggplot2::geom_line(data = d, ggplot2::aes(x = h, y = y), inherit.aes = FALSE,
                       linewidth = 0.6, alpha = 0.6, colour = "#6b7280") +
    ggplot2::scale_color_manual(values = col_map[levels(dl$p_chr)],
                                labels = function(x) scales::percent(as.numeric(x))) +
    ggplot2::scale_linetype_manual(values = c(synth = "solid", true = "dashed"))
}


# --- Calibration (μ, q̂, q_synth): tables + rolling plots (no true) -----------
if (isTRUE(do_calibration)) {
wilson_ci <- function(k, n, conf = 0.95) {
  if (n <= 0) return(c(NA_real_, NA_real_))
  z <- stats::qnorm(0.5 + conf/2); p <- k / n
  den <- 1 + z^2 / n; cen <- (p + z^2/(2*n)) / den
  rad <- z * sqrt(p*(1-p)/n + z^2/(4*n^2)) / den
  c(max(0, cen - rad), min(1, cen + rad))
}
pinball_loss <- function(y, qhat, p) { e <- y - qhat; (p - (e < 0)) * e }
qhat_from_fit <- function(fit_obj, d_pred, p0, target_len, scope) {
  qhat <- as.numeric(d_pred$q_pred)
  if (length(qhat) != target_len) {
    message(sprintf(
      "[calibration] qhat length mismatch (%s): got %d, expected %d; recomputing from yrep.",
      scope, length(qhat), target_len
    ))
    yrep <- if (identical(scope, "train")) fit_obj$yrep_tr else fit_obj$yrep_fc
    qhat <- quantile_by_time(yrep, p0, target_len)
  }
  if (length(qhat) != target_len) {
    stop(sprintf(
      "qhat length mismatch (%s): got %d, expected %d.",
      scope, length(qhat), target_len
    ))
  }
  qhat
}

# Long frames (train + forecast)
mu_tr_long <- dplyr::bind_rows(purrr::compact(lapply(seq_along(p_vec), function(i) {
  d <- fits_fc[[i]]$df_mu_tr; if (is.null(d) || !nrow(d)) return(NULL)
  keep <- fits_fc[[i]]$fit_train$meta$keep_idx
  d %>% dplyr::mutate(scope="train", p_chr=fmt_p(p_vec[i]),
                      t_aligned=keep, mu_hat=mu)
})))
mu_fc_long <- dplyr::bind_rows(lapply(seq_along(p_vec), function(i) {
  d <- fits_fc[[i]]$df_mu_fc
  d |> dplyr::mutate(scope = "forecast", p_chr = fmt_p(p_vec[i]),
                     t_aligned = n_train + h, mu_hat = mu)
}))
mu_long <- dplyr::bind_rows(mu_tr_long, mu_fc_long)

# qhat (train + forecast) with explicit numeric coercion
q_tr_long <- dplyr::bind_rows(lapply(seq_along(p_vec), function(i) {
  d    <- fits_fc[[i]]$df_pred_tr
  keep <- fits_fc[[i]]$fit_train$meta$keep_idx
  tibble::tibble(
    scope     = "train",
    p_chr     = fmt_p(p_vec[i]),
    p0        = as.numeric(p_vec[i]),
    t_aligned = keep,
    qhat      = qhat_from_fit(fits_fc[[i]], d, p_vec[i], length(keep), "train"),
    y         = as.numeric(d$y)
  )
}))

q_fc_long <- dplyr::bind_rows(lapply(seq_along(p_vec), function(i) {
  d <- fits_fc[[i]]$df_pred_fc
  tibble::tibble(
    scope     = "forecast",
    p_chr     = fmt_p(p_vec[i]),
    p0        = as.numeric(p_vec[i]),
    t_aligned = n_train + d$h,
    qhat      = qhat_from_fit(fits_fc[[i]], d, p_vec[i], H_forecast, "forecast"),
    y         = as.numeric(d$y)
  )
}))

q_long <- dplyr::bind_rows(q_tr_long, q_fc_long)

synth_cols_fc <- lapply(p_comp, function(tau) apply(synth_fc$draws, 1L, stats::quantile, probs = tau, names = FALSE))
names(synth_cols_fc) <- paste0("synth_q_", fmt_p(p_comp))
synth_q_fc <- tibble::as_tibble(synth_cols_fc)

synth_cols_tr <- lapply(p_comp, function(tau) apply(synth_tr$draws, 1L, stats::quantile, probs = tau, names = FALSE))
names(synth_cols_tr) <- paste0("synth_q_", fmt_p(p_comp))
synth_q_tr <- tibble::as_tibble(synth_cols_tr)

# Build long frames for synthesized quantiles (train + forecast)
# We use p_comp = p_vec already defined above.
qsynth_tr_long <- dplyr::bind_rows(lapply(seq_along(p_comp), function(j) {
  tau <- p_comp[j]
  col <- paste0("synth_q_", fmt_p(tau))
  tibble::tibble(
    scope     = "train",
    p_chr     = fmt_p(tau),
    p0        = as.numeric(tau),
    t_aligned = fits_fc[[1]]$fit_train$meta$keep_idx,
    q_synth   = as.numeric(synth_q_tr[[col]]),
    y         = as.numeric(bt_y(y_tr_keep))
  )
}))

qsynth_fc_long <- dplyr::bind_rows(lapply(seq_along(p_comp), function(j) {
  tau <- p_comp[j]
  col <- paste0("synth_q_", fmt_p(tau))
  tibble::tibble(
    scope     = "forecast",
    p_chr     = fmt_p(tau),
    p0        = as.numeric(tau),
    t_aligned = n_train + seq_len(H_forecast),
    q_synth   = as.numeric(synth_q_fc[[col]]),
    y         = as.numeric(bt_y(y_fc))
  )
}))

qsynth_long <- dplyr::bind_rows(qsynth_tr_long, qsynth_fc_long)


# Safe coercion + summarizers (parity with sim)
force_numeric_column <- function(df, qcol) {
  x <- df[[qcol]]
  if (is.matrix(x)) x <- drop(x[, 1, drop = TRUE])
  if (is.list(x))  x <- vapply(x, function(z) as.numeric(z)[1], numeric(1))
  x <- as.numeric(x)
  if (length(x) != nrow(df)) stop(sprintf("Column '%s' length mismatch.", qcol))
  df[[qcol]] <- x; df
}
summarize_cov_tbl_safe <- function(df, qcol) {
  stopifnot(all(c("y","p0","scope", qcol) %in% names(df)) || qcol=="qcol")
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

timed("calibration: summarize tables (mu, qhat, qsynth)", {
  cov_mu_tbl     <- summarize_cov_tbl_safe(dplyr::rename(mu_long,  qcol = mu_hat) |> dplyr::mutate(p0 = as.numeric(p_chr)), "qcol")
  cov_qhat_tbl   <- summarize_cov_tbl_safe(dplyr::rename(q_long,   qcol = qhat)   |> dplyr::mutate(p0 = as.numeric(p_chr)), "qcol")
  cov_qsynth_tbl <- summarize_cov_tbl_safe(dplyr::rename(qsynth_long, qcol = q_synth), "qcol")
  print(cov_mu_tbl); print(cov_qhat_tbl); print(cov_qsynth_tbl)
  if (isTRUE(save_outputs)) {
    readr::write_csv(cov_mu_tbl,     file.path(TABLES, nm("calib_mu",    "calibration_mu_table.csv")))
    readr::write_csv(cov_qhat_tbl,   file.path(TABLES, nm("calib_qhat",  "calibration_qhat_table.csv")))
    readr::write_csv(cov_qsynth_tbl, file.path(TABLES, nm("calib_qsynth","calibration_qsynth_table.csv")))
  }
})

# Rolling coverage plots (μ, q̂, q_synth) — same function as sim
plot_rolling_cov <- function(df_long, qcol,
                             window = 365L, show_last = 300L,
                             title_left = "Rolling empirical coverage",
                             show_rcov_band = FALSE, show_target_band = FALSE) {

  if (is.matrix(df_long[[qcol]])) df_long[[qcol]] <- drop(df_long[[qcol]][, 1, drop = TRUE])
  if (is.list(df_long[[qcol]]))   df_long[[qcol]] <- vapply(df_long[[qcol]], function(z) as.numeric(z)[1], numeric(1))
  df_long[[qcol]] <- as.numeric(df_long[[qcol]])

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
  d <- d |> dplyr::mutate(p_chr = factor(p_chr, levels = fmt_p(p_vec)))
  ref <- d |> dplyr::distinct(scope, p_chr) |> dplyr::mutate(p0 = as.numeric(as.character(p_chr)))

  x_rng <- range(d$t_aligned, na.rm = TRUE)
  last_pts <- d %>% dplyr::group_by(scope, p_chr) %>% dplyr::slice_tail(n = 1) %>% dplyr::ungroup() %>%
    dplyr::mutate(x_lab = t_aligned - 0.03 * diff(x_rng), y_lab = pmin(pmax(rcov + 0.02, 0), 1))

  ggplot2::ggplot(d, ggplot2::aes(x = t_aligned, y = rcov, colour = p_chr)) +
    theme_exdqlm() +
    ggplot2::labs(
      x = "time index (aligned)",
      y = sprintf("rolling Pr(y ≤ %s)  (W %s)", if (qcol=="mu_hat") "μ" else "q", W_lab),
      title    = paste0(title_left, if (qcol=="mu_hat") " of μ" else " of q"),
      subtitle = sprintf("Last %d points; ribbon: Wilson CI of rolling coverage", show_last)
    ) +
    { if (isTRUE(show_target_band))
        ggplot2::geom_hline(data = ref,
                            ggplot2::aes(yintercept = p0, colour = p_chr),
                            linetype = "dashed", linewidth = 0.7, show.legend = FALSE)
      else ggplot2::geom_blank() } +

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
      values = setNames(col_map, fmt_p(p_vec)),
      labels = function(x) scales::percent(as.numeric(x))) +
    ggplot2::scale_fill_manual(name = "quantile p",
      values = setNames(sapply(col_map, scales::alpha, alpha = 0.18), fmt_p(p_vec)),
      labels = function(x) scales::percent(as.numeric(x))) +
    ggplot2::scale_y_continuous(breaks = seq(0,1,0.1), labels = scales::percent_format(accuracy = 1)) +
    ggplot2::scale_x_continuous(limits = x_rng, expand = c(0, 0)) +
    ggplot2::coord_cartesian(ylim = c(0, 1), expand = FALSE)
}

cov_window <- 365L
show_last  <- 300L
g_cov_mu_train <- plot_rolling_cov(mu_long |> dplyr::filter(scope=="train"),
                                   qcol = "mu_hat",
                                   window = cov_window, show_last = show_last,
                                   show_rcov_band = TRUE,  show_target_band = FALSE)
g_cov_mu_fore  <- plot_rolling_cov(mu_long |> dplyr::filter(scope=="forecast"),
                                   qcol = "mu_hat",
                                   window = cov_window, show_last = show_last,
                                   show_rcov_band = TRUE,  show_target_band = FALSE)
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

timed("calibration: rolling coverage plots", {
  print(g_cov_mu_train); print(g_cov_mu_fore)
  print(g_cov_q_train);  print(g_cov_q_fore)
  print(g_cov_qsynth_train); print(g_cov_qsynth_fore)
  if (isTRUE(save_outputs)) {
    ggplot2::ggsave(file.path(FIGS, sprintf("%s%d.png", nm("cov_mu_train_prefix","rolling_cov_mu_train_W="),      cov_window)), g_cov_mu_train,      width=9, height=4.8, dpi=150)
    ggplot2::ggsave(file.path(FIGS, sprintf("%s%d.png", nm("cov_mu_fore_prefix","rolling_cov_mu_forecast_W="),   cov_window)), g_cov_mu_fore,       width=9, height=4.8, dpi=150)
    ggplot2::ggsave(file.path(FIGS, sprintf("%s%d.png", nm("cov_qhat_train_prefix","rolling_cov_qhat_train_W="), cov_window)), g_cov_q_train,       width=9, height=4.8, dpi=150)
    ggplot2::ggsave(file.path(FIGS, sprintf("%s%d.png", nm("cov_qhat_fore_prefix","rolling_cov_qhat_forecast_W="), cov_window)), g_cov_q_fore,      width=9, height=4.8, dpi=150)
    ggplot2::ggsave(file.path(FIGS, sprintf("%s%d.png", nm("cov_qsynth_train_prefix","rolling_cov_qsynth_train_W="), cov_window)), g_cov_qsynth_train, width=9, height=4.8, dpi=150)
    ggplot2::ggsave(file.path(FIGS, sprintf("%s%d.png", nm("cov_qsynth_fore_prefix","rolling_cov_qsynth_forecast_W="), cov_window)), g_cov_qsynth_fore, width=9, height=4.8, dpi=150)
  }
})
}

# --- PIT diagnostics (train & forecast) --------------------------------------
if (isTRUE(do_pit)) {
  emp_pit_vec <- function(y, yrep_mat) {
    stopifnot(length(y) == nrow(yrep_mat))
    rowMeans(sweep(yrep_mat, 1, y, FUN = "<="), na.rm = TRUE)
  }

  pit_scope_norm <- tolower(gsub("[ _+]", "", pit_scope))
  pit_use_all   <- pit_scope_norm %in% c("all", "allsynth", "synthall")
  pit_use_synth <- pit_scope_norm %in% c("synth", "allsynth", "synthall")
  pit_use_median <- pit_scope_norm %in% c("median", "mid", "medianonly")
  if (!pit_use_all && !pit_use_synth && !pit_use_median) {
    message(sprintf("[PIT] unknown pit_scope='%s'; defaulting to all+synth.", pit_scope))
    pit_use_all <- TRUE
    pit_use_synth <- TRUE
  }

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

  timed("PIT: compute + plots + save", {
    if (isTRUE(pit_use_median)) {
      i_med <- which.min(abs(p_vec - 0.50))
      pit_tr <- emp_pit_vec(bt_y(y_tr_keep), fits_fc[[i_med]]$yrep_tr)
      pit_fc <- emp_pit_vec(bt_y(y_fc),      fits_fc[[i_med]]$yrep_fc)
      g_pit_tr_hist <- plot_pit_hist(pit_tr, "PIT histogram (train, median model)")
      g_pit_fc_hist <- plot_pit_hist(pit_fc, "PIT histogram (forecast, median model)")
      g_pit_tr_qq   <- plot_pit_qq(pit_tr,   "PIT QQ (train, median model)")
      g_pit_fc_qq   <- plot_pit_qq(pit_fc,   "PIT QQ (forecast, median model)")
      g_pit_train    <- g_pit_tr_hist | g_pit_tr_qq
      g_pit_forecast <- g_pit_fc_hist | g_pit_fc_qq
      print(g_pit_train); print(g_pit_forecast)
      if (isTRUE(save_outputs)) {
        ggplot2::ggsave(file.path(FIGS, nm("pit_train","pit_train.png")),       g_pit_train,    width = 12, height = 4.5, dpi = 150)
        ggplot2::ggsave(file.path(FIGS, nm("pit_forecast","pit_forecast.png")), g_pit_forecast, width = 12, height = 4.5, dpi = 150)
      }
    }

    if (isTRUE(pit_use_all)) {
      pit_tr_list <- lapply(seq_along(p_vec), function(i) emp_pit_vec(bt_y(y_tr_keep), fits_fc[[i]]$yrep_tr))
      pit_fc_list <- lapply(seq_along(p_vec), function(i) emp_pit_vec(bt_y(y_fc),      fits_fc[[i]]$yrep_fc))
      names(pit_tr_list) <- fmt_p(p_vec)
      names(pit_fc_list) <- fmt_p(p_vec)

      pit_long <- function(pit_list) {
        dplyr::bind_rows(lapply(names(pit_list), function(p_chr) {
          tibble::tibble(p_chr = p_chr, pit = pit_list[[p_chr]])
        })) |> dplyr::filter(is.finite(pit))
      }
      pit_qq_long <- function(pit_list) {
        dplyr::bind_rows(lapply(names(pit_list), function(p_chr) {
          pit <- pit_list[[p_chr]]
          pit <- pit[is.finite(pit)]
          if (!length(pit)) return(tibble::tibble())
          pit_s <- sort(pit); u <- stats::ppoints(length(pit_s))
          tibble::tibble(p_chr = p_chr, u = u, pit = pit_s)
        }))
      }

      d_tr <- pit_long(pit_tr_list)
      d_fc <- pit_long(pit_fc_list)
      qq_tr <- pit_qq_long(pit_tr_list)
      qq_fc <- pit_qq_long(pit_fc_list)
      ncol_fac <- min(3L, length(p_vec))

      g_tr_hist <- ggplot2::ggplot(d_tr, ggplot2::aes(x = pit)) +
        theme_exdqlm() +
        ggplot2::geom_histogram(ggplot2::aes(y = after_stat(density)),
                                boundary = 0, bins = 20, color = "white") +
        ggplot2::geom_hline(yintercept = 1, linetype = 2) +
        ggplot2::facet_wrap(~ p_chr, ncol = ncol_fac) +
        ggplot2::labs(title = "PIT histograms (train, per-quantile models)",
                      x = "PIT", y = "density")
      g_fc_hist <- ggplot2::ggplot(d_fc, ggplot2::aes(x = pit)) +
        theme_exdqlm() +
        ggplot2::geom_histogram(ggplot2::aes(y = after_stat(density)),
                                boundary = 0, bins = 20, color = "white") +
        ggplot2::geom_hline(yintercept = 1, linetype = 2) +
        ggplot2::facet_wrap(~ p_chr, ncol = ncol_fac) +
        ggplot2::labs(title = "PIT histograms (forecast, per-quantile models)",
                      x = "PIT", y = "density")

      g_tr_qq <- ggplot2::ggplot(qq_tr, ggplot2::aes(x = u, y = pit)) +
        theme_exdqlm() +
        ggplot2::geom_abline(slope = 1, intercept = 0, linetype = 2) +
        ggplot2::geom_point(alpha = 0.7, size = 1.2) +
        ggplot2::facet_wrap(~ p_chr, ncol = ncol_fac) +
        ggplot2::labs(title = "PIT QQ (train, per-quantile models)",
                      x = "Uniform(0,1) quantiles", y = "PIT quantiles") +
        ggplot2::coord_cartesian(xlim = c(0,1), ylim = c(0,1))
      g_fc_qq <- ggplot2::ggplot(qq_fc, ggplot2::aes(x = u, y = pit)) +
        theme_exdqlm() +
        ggplot2::geom_abline(slope = 1, intercept = 0, linetype = 2) +
        ggplot2::geom_point(alpha = 0.7, size = 1.2) +
        ggplot2::facet_wrap(~ p_chr, ncol = ncol_fac) +
        ggplot2::labs(title = "PIT QQ (forecast, per-quantile models)",
                      x = "Uniform(0,1) quantiles", y = "PIT quantiles") +
        ggplot2::coord_cartesian(xlim = c(0,1), ylim = c(0,1))

      g_pit_train_all <- g_tr_hist | g_tr_qq
      g_pit_fore_all  <- g_fc_hist | g_fc_qq
      print(g_pit_train_all); print(g_pit_fore_all)
      if (isTRUE(save_outputs)) {
        ggplot2::ggsave(file.path(FIGS, "pit_train_models.png"),    g_pit_train_all, width = 12, height = 6.5, dpi = 150)
        ggplot2::ggsave(file.path(FIGS, "pit_forecast_models.png"), g_pit_fore_all,  width = 12, height = 6.5, dpi = 150)
      }
    }

    if (isTRUE(pit_use_synth)) {
      pit_tr_syn <- emp_pit_vec(bt_y(y_tr_keep), synth_tr$draws)
      pit_fc_syn <- emp_pit_vec(bt_y(y_fc),      synth_fc$draws)
      g_tr_hist <- plot_pit_hist(pit_tr_syn, "PIT histogram (train, synthesized)")
      g_fc_hist <- plot_pit_hist(pit_fc_syn, "PIT histogram (forecast, synthesized)")
      g_tr_qq   <- plot_pit_qq(pit_tr_syn,   "PIT QQ (train, synthesized)")
      g_fc_qq   <- plot_pit_qq(pit_fc_syn,   "PIT QQ (forecast, synthesized)")
      g_pit_train <- g_tr_hist | g_tr_qq
      g_pit_fore  <- g_fc_hist | g_fc_qq
      print(g_pit_train); print(g_pit_fore)
      if (isTRUE(save_outputs)) {
        ggplot2::ggsave(file.path(FIGS, "pit_train_synth.png"),    g_pit_train, width = 12, height = 4.5, dpi = 150)
        ggplot2::ggsave(file.path(FIGS, "pit_forecast_synth.png"), g_pit_fore,  width = 12, height = 4.5, dpi = 150)
      }
    }
  })
}

# --- Scores: CRPS + mean pinball over p_comp (parity with sim) ----------------
if (isTRUE(do_scores)) {
  crps_fc <- crps_vec(bt_y(y_fc), synth_fc$draws)
  crps_tr <- crps_vec(bt_y(y_tr_keep), synth_tr$draws)

  pinball_mean_fc <- rowMeans(vapply(seq_along(p_comp), function(j) {
    tau <- p_comp[j]; qhat <- apply(synth_fc$draws, 1, stats::quantile, probs = tau, names = FALSE)
    pinball_loss(bt_y(y_fc), qhat, tau)
  }, numeric(length(y_fc))))
  pinball_mean_tr <- rowMeans(vapply(seq_along(p_comp), function(j) {
    tau <- p_comp[j]; qhat <- apply(synth_tr$draws, 1, stats::quantile, probs = tau, names = FALSE)
    pinball_loss(bt_y(y_tr_keep), qhat, tau)
  }, numeric(length(y_tr_keep))))

  S_fc <- crps_fc + pinball_mean_fc
  S_tr <- crps_tr + pinball_mean_tr

  scores_fc_df <- tibble::tibble(h = seq_len(H_forecast), y = bt_y(y_fc), CRPS = crps_fc, pinball_mean = pinball_mean_fc, S = S_fc)
  scores_tr_df <- tibble::tibble(h = seq_len(T_train_keep), y = bt_y(y_tr_keep), CRPS = crps_tr, pinball_mean = pinball_mean_tr, S = S_tr)
  scores_summary <- tibble::tibble(
    split = c("train","forecast"),
    CRPS_mean = c(mean(crps_tr), mean(crps_fc)),
    PinballMean_mean = c(mean(pinball_mean_tr), mean(pinball_mean_fc)),
    S_mean = c(mean(S_tr), mean(S_fc))
  )

  timed("Scores: write tables", {
    if (isTRUE(save_outputs)) {
      readr::write_csv(scores_fc_df,   file.path(TABLES, "scores_forecast_series.csv"))
      readr::write_csv(scores_tr_df,   file.path(TABLES, "scores_train_series.csv"))
      readr::write_csv(scores_summary, file.path(TABLES, nm("metrics_summary","metrics_summary.csv")))
    }
  })
}

# --- Save core objects (parity with sim names/keys) ---------------------------
if (isTRUE(save_outputs)) {
  # For compatibility with sim, build compare_* frames with synth quantiles;
  # include NA placeholders for true_q_* columns so downstream code can reuse keys.
  make_compare_df <- function(y_vec, synth_q_tbl, H, p_comp, label="Forecast") {
    synth_cols <- lapply(p_comp, function(tau) synth_q_tbl[[paste0("synth_q_", fmt_p(tau))]])
    names(synth_cols) <- paste0("synth_q_", fmt_p(p_comp))
    true_cols <- setNames(replicate(length(p_comp), rep(NA_real_, H), simplify = FALSE),
                          paste0("true_q_", fmt_p(p_comp)))
    tibble::tibble(h = seq_len(H), y = y_vec) |>
      dplyr::bind_cols(as_tibble(true_cols)) |>
      dplyr::bind_cols(as_tibble(synth_cols))
  }
  compare_fc <- make_compare_df(bt_y(y_fc),      synth_q_fc, H_forecast,   p_comp, "Forecast")
  compare_tr <- make_compare_df(bt_y(y_tr_keep), synth_q_tr, T_train_keep, p_comp, "Train")

  # --- Minimal canonical overlay (TRAIN) --------------------------
  g_q_overlay_tr <- plot_quantiles_overlay_from_compare(
    compare_df = compare_tr, taus = p_comp, scope = "Train", window = train_last_window
  )
  if (isTRUE(do_plots)) {
    print(g_q_overlay_tr)
    if (isTRUE(save_outputs)) {
      fn <- file.path(FIGS, "train_quantiles_overlay.png")
      if (!file.exists(fn)) ggplot2::ggsave(fn, g_q_overlay_tr, width=9, height=4.8, dpi=150)
    }
  }

  # --- Minimal canonical overlay (FORECAST) -----------------------
  g_q_overlay_fc <- plot_quantiles_overlay_from_compare(
    compare_df = compare_fc, taus = p_comp, scope = "Forecast", window = fore_last_window
  )
  if (isTRUE(do_plots)) {
    print(g_q_overlay_fc)
    if (isTRUE(save_outputs)) {
      fn <- file.path(FIGS, "forecast_quantiles_overlay.png")
      if (!file.exists(fn)) ggplot2::ggsave(fn, g_q_overlay_fc, width=9, height=4.8, dpi=150)
    }
  }

  saveRDS(
    list(
      fits_fc = fits_fc,
      synth_fc = synth_fc,
      compare_fc = compare_fc,
      compare_tr = compare_tr,
      cfg = list(
        p_vec = p_vec, desn_args = desn_args, vb_args_base = vb_args_base,
        nd_draws = nd_draws, chunk_sz = chunk_sz,
        last_window          = fore_last_window,
        last_window_train    = train_last_window,
        last_window_forecast = fore_last_window,
        forecast = list(
          mode         = forecast_mode,
          horizon      = forecast_horizon,
          lead_weight_power = lead_weight_power,
          lead_weights = lead_weights,
          mix_nd       = mix_nd,
          eval_leads   = eval_leads
        ),
        teacher_forcing = list(enable = FALSE, first_k = 0L,
                               explicit = NULL, y_future_obs_fc = NULL),
        synth = list(isotonic = synth_isotonic, rearrange = synth_rearrange,
                     grid_M = synth_grid_M, n_samp = synth_nsamp, seed = synth_seed),
        split = list(T_use = T_use, n_train = n_train, H_forecast = H_forecast),
        ij = list(use_ij_correction = use_ij_correction, nd_draws = ij_nd_draws),
        outputs = list(save = save_outputs, keep_draws = keep_draws, thesis_subset = thesis_subset),
        diagnostics = list(
          lead_eval  = do_lead_eval,
          fan_charts = do_fan_charts,
          fan_stride = fan_stride
        ),
        vb_priors = list(
          beta_type = vb_prior_beta_type,
          beta_ridge_tau2 = vb_prior_beta_tau2,
          beta_rhs = vb_prior_beta_rhs
        )
      )
    ),
    file.path(MODELS, nm("objects_rds","forecast_objects.rds"))
  )
}

# --- Manifest (kept; mirrors runner style) ------------------------------------
manifest <- list(
  pipeline = list(mode = "real", version = "real-2"),
  inputs   = list(file_obs = file_long),
  data     = list(T_full = T_full, T_use = T_use, train_n = n_train, H_forecast = H_forecast,
                  y_col = y_col, x_cols = x_cols, lags = list(y = lags_y, x = lags_x)),
  cfg      = cfg
)
if (isTRUE(save_outputs)) {
  readr::write_file(jsonlite::toJSON(manifest, auto_unbox = TRUE, pretty = TRUE),
                    file.path(MANI, "manifest_real.json"))
}

log_msg("Real pipeline completed successfully.")

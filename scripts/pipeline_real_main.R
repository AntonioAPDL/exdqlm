# scripts/pipeline_real_main.R
#!/usr/bin/env Rscript

# ================================================================
# Real-data ESN quantile pipeline (fit → forecast → synthesis → diagnostics)
# Mirrors pipeline_main.R (sim) structure, logs, filenames, and tables.
# Differences vs sim:
#   - No true-quantile overlays (no q_true)
#   - Plots that require true quantiles are omitted or adapted
# ================================================================

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
fmt_p <- function(x) sprintf("%.2f", as.numeric(x))

# --- Logging & timing (parity with sim) ---------------------------------------
.now <- function() format(Sys.time(), "%Y-%m-%d %H:%M:%S")
log_msg <- function(fmt, ...) { cat(sprintf("[%s] %s\n", .now(), sprintf(fmt, ...))); flush.console() }

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

band_from_draws <- function(mat, level = 0.95) {
  mat <- as.matrix(mat)
  probs <- c((1 - level)/2, 0.5, (1 + level)/2)
  if (nrow(mat) >= ncol(mat)) {
    qs <- cbind(
      lo  = matrixStats::rowQuantiles(mat, probs = probs[1], na.rm = TRUE),
      med = matrixStats::rowQuantiles(mat, probs = probs[2], na.rm = TRUE),
      hi  = matrixStats::rowQuantiles(mat, probs = probs[3], na.rm = TRUE)
    )
  } else {
    qs <- cbind(
      lo  = matrixStats::colQuantiles(mat, probs = probs[1], na.rm = TRUE),
      med = matrixStats::colQuantiles(mat, probs = probs[2], na.rm = TRUE),
      hi  = matrixStats::colQuantiles(mat, probs = probs[3], na.rm = TRUE)
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
      vb_args = list(max_iter = 1, tol = 1e9, n_samp_xi = 1, verbose = FALSE)
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

# Index diagnostics (parity with sim)
cat(sprintf("IDX | use_range=[%d..%d] | train=[%d..%d] | forecast=[%d..%d] | lens train=%d, fore=%d\n",
            min(idx_use), max(idx_use),
            ifelse(length(idx_tr_abs), min(idx_tr_abs), NA_integer_),
            ifelse(length(idx_tr_abs), max(idx_tr_abs), NA_integer_),
            ifelse(length(idx_fc_abs), min(idx_fc_abs), NA_integer_),
            ifelse(length(idx_fc_abs), max(idx_fc_abs), NA_integer_),
            length(idx_tr_abs), length(idx_fc_abs)))

cat(sprintf("[lens] y_train_keep=%d | y_forecast=%d\n", length(y_tr_keep), length(y_fc)))

# Teacher forcing meta (same semantics as sim: forecasting window is held-out obs)
tf_enable       <- TRUE
tf_first_k      <- as.integer(cfg$forecast$tf_first_k %||% 0L)
y_future_obs_fc <- y_fc
req_mode <- tolower(cfg$forecast$mode %||% "tf")
if (!identical(req_mode, "tf") && !identical(req_mode, "tf1")) {
  message(sprintf("[forecast] WARNING: requested forecast.mode='%s' but this pipeline currently runs with full teacher forcing; recursive modes are ignored for now.", req_mode))
}
cat(sprintf("TF | mode=full | len(y_future_obs_fc)=%d\n", length(y_future_obs_fc))); flush.console()

# --- VB / sampling / synthesis config (parity with sim) -----------------------
p_vec <- as.numeric(cfg$p_vec %||% c(0.05, 0.50, 0.95))

vb_args_base <- list(max_iter = 150, tol = 1e-4, n_samp_xi = 500, verbose = TRUE)
if (!is.null(cfg$vb)) {
  vb_args_base$max_iter  <- cfg$vb$max_iter  %nz% vb_args_base$max_iter
  vb_args_base$n_samp_xi <- cfg$vb$n_samp_xi %nz% vb_args_base$n_samp_xi
}
tol50  <- cfg$vb$tol_50      %||% 1e-4
tolext <- cfg$vb$tol_extreme %||% 1e-5
vb_tol_for <- function(p0) if (near_equal(p0, 0.50)) tol50 else tolext
log_msg("Effective VB → max_iter=%d | tol_50=%.1e | tol_extreme=%.1e | n_samp_xi=%d",
        vb_args_base$max_iter, tol50, tolext, vb_args_base$n_samp_xi)

vb_iter_for <- function(p0) {
  base_it <- as.integer(vb_args_base$max_iter %||% 150)
  if (near_equal(p0, 0.50)) base_it else max(60L, base_it)
}

nd_draws <- as.integer((cfg$sampling$nd_draws %||% 3000L))
chunk_sz <- as.integer((cfg$sampling$chunk    %||% 250L))
log_msg("Effective sampling → nd_draws=%d | chunk=%d", nd_draws, chunk_sz)

last_window <- as.integer((cfg$forecast$last_window %||% 200L))

# Color map per p (for multi-p plots)
pal <- scales::hue_pal()(length(p_vec))
col_map <- setNames(pal, fmt_p(p_vec))

# --- Per-p fit + posterior predictive + frames (parity object structure) ------
fit_and_forecast_p <- function(p0) {
  vb_args_p <- vb_args_base
  vb_args_p$tol <- vb_tol_for(p0)
  vb_args_p$max_iter <- vb_iter_for(p0)

  tau <- as.numeric(p0)  # avoid name masking by tibble columns

  p <- ncol(X_train)
  exal_defaults <- list(
    b0 = rep(0, p), V0 = diag(1e4, p),
    a_sigma = 1, b_sigma = 1,
    max_iter = vb_args_p$max_iter, tol = vb_args_p$tol,
    n_samp_xi = vb_args_p$n_samp_xi, verbose = TRUE,
    p0 = p0, gamma_bounds = c(L.fn(p0), U.fn(p0)), log_prior_gamma = function(g) 0
  )

  fit_exal <- timed(sprintf("fit_exAL_on_X_train(p=%s)", fmt_p(p0)),
    do.call(exal_static_LDVB, c(list(y = y_tr_keep, X = X_train), exal_defaults))
  )
  if (isTRUE(readout_scale) && !is.null(readout_scale_info)) {
    if (is.null(fit_exal$misc)) fit_exal$misc <- list()
    fit_exal$misc$readout_scale <- readout_scale_info
  }

  pp_tr <- timed(sprintf("posterior_predict TRAIN (p=%s, nd=%d)", fmt_p(p0), nd_draws),
    exal_vb_posterior_predict(fit_exal, X_new = X_train, nd = nd_draws, chunk = chunk_sz)
  )
  yrep_tr     <- pp_tr$yrep
  mu_draws_tr <- pp_tr$mu_draws
  # Back-transform TRAIN draws to original units
  yrep_tr     <- bt_y(yrep_tr)
  mu_draws_tr <- bt_y(mu_draws_tr)
  y_tr_keep_bt <- bt_y(y_tr_keep)

mu_qs_tr <- band_from_draws(mu_draws_tr, level = 0.95)

  df_mu_tr <- tibble::tibble(
    h = seq_along(keep_train_abs), p0 = p0,
    mu = mu_qs_tr[, "med"], lo = mu_qs_tr[, "lo"], hi = mu_qs_tr[, "hi"],
    y = y_tr_keep_bt
  )
  df_pred_tr <- tibble::tibble(
    h = seq_along(keep_train_abs), p0 = tau,
    q_pred = quantile_by_time(yrep_tr, tau, length(y_tr_keep)),
    y = y_tr_keep_bt
  )

  pp_fc <- timed(sprintf("posterior_predict FORECAST (p=%s, nd=%d)", fmt_p(p0), nd_draws),
    exal_vb_posterior_predict(fit_exal, X_new = X_fc1, nd = nd_draws, chunk = chunk_sz)
  )
  yrep_fc     <- pp_fc$yrep
  mu_draws_fc <- pp_fc$mu_draws
  # Back-transform FORECAST draws to original units
  yrep_fc     <- bt_y(yrep_fc)
  mu_draws_fc <- bt_y(mu_draws_fc)
  y_fc_bt     <- bt_y(y_fc)

  mu_qs_fc    <- band_from_draws(mu_draws_fc, level = 0.95)

  df_mu_fc <- tibble::tibble(
    h = seq_len(H_forecast), p0 = p0,
    mu = mu_qs_fc[, "med"], lo = mu_qs_fc[, "lo"], hi = mu_qs_fc[, "hi"],
    y = y_fc_bt
  )
  df_pred_fc <- tibble::tibble(
    h = seq_len(H_forecast), p0 = tau,
    q_pred = quantile_by_time(yrep_fc, tau, H_forecast),
    y = y_fc_bt
  )

  list(
    fit_train = list(fit = fit_exal, meta = list(keep_idx = keep_train_abs)),
    yrep_fc = yrep_fc,   mu_draws_fc = mu_draws_fc,
    df_mu_fc = df_mu_fc, df_pred_fc  = df_pred_fc,
    yrep_tr = yrep_tr,   mu_draws_tr = mu_draws_tr,
    df_mu_tr = df_mu_tr, df_pred_tr  = df_pred_tr
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
  ggplot2::ggplot(d, ggplot2::aes(x = h)) + theme_exdqlm() +
    ggplot2::labs(
      title = sprintf("%s: μ̂ ±95%% (model at p=%s)", scope, scales::percent(p0, 1)),
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

for (k in seq_along(p_vec)) {
  p0 <- p_vec[k]
  g1 <- plot_mu_band_real(fits_fc[[k]]$df_mu_fc, p0, scope = "Forecast", window = last_window)
  g1tr <- plot_mu_band_real(fits_fc[[k]]$df_mu_tr, p0, scope = "Train", window = 200L)

  timed(sprintf("plot+save forecast_mu_band(p=%s)", fmt_p(p0)), {
    print(g1)
    if (isTRUE(save_outputs)) {
      ggsave(file.path(FIGS, sprintf("forecast_mu_band_p=%s.png", as.character(p0))), g1, width=9, height=4.8, dpi=150)
    }
  })
  timed(sprintf("plot+save train_mu_band(p=%s)", fmt_p(p0)), {
    print(g1tr)
    if (isTRUE(save_outputs)) {
      ggsave(file.path(FIGS, sprintf("train_mu_band_p=%s.png", as.character(p0))), g1tr, width=9, height=4.8, dpi=150)
    }
  })
}

# --- Minimal canonical single-plot exports (median p=0.50) ------
i_med <- which.min(abs(p_vec - 0.50))
p_med <- p_vec[i_med]

g_mu_fc_med <- plot_mu_band_real(fits_fc[[i_med]]$df_mu_fc, p_med, scope = "Forecast", window = last_window)
g_mu_tr_med <- plot_mu_band_real(fits_fc[[i_med]]$df_mu_tr, p_med, scope = "Train",    window = 200L)

print(g_mu_fc_med); print(g_mu_tr_med)

if (isTRUE(save_outputs)) {
  if (!file.exists(file.path(FIGS, "forecast_mu_band.png")))
    ggplot2::ggsave(file.path(FIGS, "forecast_mu_band.png"), g_mu_fc_med, width=9, height=4.8, dpi=150)
  if (!file.exists(file.path(FIGS, "train_mu_band.png")))
    ggplot2::ggsave(file.path(FIGS, "train_mu_band.png"), g_mu_tr_med, width=9, height=4.8, dpi=150)
}

# --- ELBO traces (same as sim) -----------------------------------------------
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
    ggplot2::geom_line(linewidth=0.8, alpha=0.95) + ggplot2::scale_color_manual(values = col_map)
  print(g_elbo)
  if (isTRUE(save_outputs)) ggsave(file.path(FIGS, sprintf("%s%d.png", nm("elbo_prefix","elbo_traces_skip_k="), k_burn)), g_elbo, width=9, height=4.8, dpi=150)
}

# --- Synthesis (forecast + train) --------------------------------------------
draws_list_fc <- lapply(fits_fc, function(obj) obj$yrep_fc)
draws_list_tr <- lapply(fits_fc, function(obj) obj$yrep_tr)

synth_isotonic  <- cfg$synthesis$isotonic  %nz% TRUE
synth_rearrange <- cfg$synthesis$rearrange %nz% TRUE
synth_grid_M    <- as.integer((cfg$synthesis$grid_M %||% 2001L))
synth_nsamp     <- as.integer((cfg$synthesis$n_samp %||% 4000L))
synth_seed      <- as.integer((cfg$synthesis$seed   %||% 123L))

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
      caption = caption_exdqlm(if (scope=="Forecast") last_window else 200L, nd_draws),
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

timed("plot+save synth bands (train+forecast)", {
  g_band_fc <- plot_synth_predictive_band(synth_draws = synth_fc$draws, y_vec = bt_y(y_fc), 
                                          scope="Forecast", window = last_window, fill_col = ACCENT_ORANGE, show_median = TRUE)
  g_band_tr <- plot_synth_predictive_band(synth_draws = synth_tr$draws, y_vec = bt_y(y_tr_keep),
                                          scope="Train", window = 200L, fill_col = ACCENT_ORANGE, show_median = TRUE)
  print(g_band_fc); print(g_band_tr)
  if (isTRUE(save_outputs)) {
    ggsave(file.path(FIGS, "forecast_obs_with_95_band.png"), g_band_fc, width=9, height=4.8, dpi=150)
    ggsave(file.path(FIGS, "train_obs_with_95_band.png"),    g_band_tr, width=9, height=4.8, dpi=150)
  }
})

# --- NEW (minimal): overlay of synthesized vs TRUE quantiles (p in taus) ----
plot_quantiles_overlay_from_compare <- function(compare_df, taus = c(0.05, 0.50, 0.95),
                                               scope = "Forecast", window = 200L) {
  i2 <- max(compare_df$h); i1 <- max(1L, i2 - as.integer(window) + 1L)
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

  ggplot2::ggplot(dl, ggplot2::aes(x = h, y = val, colour = p_chr, linetype = kind)) +
    theme_exdqlm() +
    ggplot2::labs(
      title   = title_txt,
      subtitle= sprintf("p ∈ {%s}", paste(fmt_p(taus), collapse=", ")),
      caption = caption_exdqlm(window, nd_draws),
      x = "time", y = "value", colour = "p", linetype = ""
    ) +
    ggplot2::geom_line(linewidth = 0.9, na.rm = TRUE) +
    ggplot2::geom_line(data = d, ggplot2::aes(y = y), inherit.aes = FALSE,
                       linewidth = 0.6, alpha = 0.6, colour = "#6b7280") +
    ggplot2::scale_color_manual(values = col_map[levels(dl$p_chr)],
                                labels = function(x) scales::percent(as.numeric(x))) +
    ggplot2::scale_linetype_manual(values = c(synth = "solid", true = "dashed"))
}


# --- Calibration (μ, q̂, q_synth): tables + rolling plots (no true) -----------
wilson_ci <- function(k, n, conf = 0.95) {
  if (n <= 0) return(c(NA_real_, NA_real_))
  z <- stats::qnorm(0.5 + conf/2); p <- k / n
  den <- 1 + z^2 / n; cen <- (p + z^2/(2*n)) / den
  rad <- z * sqrt(p*(1-p)/n + z^2/(4*n^2)) / den
  c(max(0, cen - rad), min(1, cen + rad))
}
pinball_loss <- function(y, qhat, p) { e <- y - qhat; (p - (e < 0)) * e }

# Long frames (train + forecast)
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

# qhat (train + forecast) with explicit numeric coercion
q_tr_long <- dplyr::bind_rows(lapply(seq_along(p_vec), function(i) {
  d    <- fits_fc[[i]]$df_pred_tr
  keep <- fits_fc[[i]]$fit_train$meta$keep_idx
  tibble::tibble(
    scope     = "train",
    p_chr     = sprintf("%.2f", p_vec[i]),
    p0        = as.numeric(p_vec[i]),
    t_aligned = keep,
    qhat      = as.numeric(d$q_pred),
    y         = as.numeric(d$y)
  )
}))

q_fc_long <- dplyr::bind_rows(lapply(seq_along(p_vec), function(i) {
  d <- fits_fc[[i]]$df_pred_fc
  tibble::tibble(
    scope     = "forecast",
    p_chr     = sprintf("%.2f", p_vec[i]),
    p0        = as.numeric(p_vec[i]),
    t_aligned = n_train + d$h,
    qhat      = as.numeric(d$q_pred),
    y         = as.numeric(d$y)
  )
}))

q_long <- dplyr::bind_rows(q_tr_long, q_fc_long)


p_comp <- c(0.05, 0.50, 0.95)
synth_cols_fc <- lapply(p_comp, function(tau) apply(synth_fc$draws, 1L, stats::quantile, probs = tau, names = FALSE))
names(synth_cols_fc) <- paste0("synth_q_", fmt_p(p_comp))
synth_q_fc <- tibble::as_tibble(synth_cols_fc)

synth_cols_tr <- lapply(p_comp, function(tau) apply(synth_tr$draws, 1L, stats::quantile, probs = tau, names = FALSE))
names(synth_cols_tr) <- paste0("synth_q_", fmt_p(p_comp))
synth_q_tr <- tibble::as_tibble(synth_cols_tr)

# Build long frames for synthesized quantiles (train + forecast)
# We use p_comp = c(0.05, 0.50, 0.95) already defined above.
qsynth_tr_long <- dplyr::bind_rows(lapply(seq_along(p_comp), function(j) {
  tau <- p_comp[j]
  col <- paste0("synth_q_", fmt_p(tau))
  tibble::tibble(
    scope     = "train",
    p_chr     = sprintf("%.2f", tau),
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
    p_chr     = sprintf("%.2f", tau),
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
  d <- d |> dplyr::mutate(p_chr = factor(p_chr, levels = sprintf("%.2f", p_vec)))
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
      values = setNames(col_map, sprintf("%.2f", p_vec)),
      labels = function(x) scales::percent(as.numeric(x))) +
    ggplot2::scale_fill_manual(name = "quantile p",
      values = setNames(sapply(col_map, scales::alpha, alpha = 0.18), sprintf("%.2f", p_vec)),
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

# --- PIT diagnostics (median model) -------------------------------------------
emp_pit_vec <- function(y, yrep_mat) { stopifnot(length(y) == nrow(yrep_mat)); rowMeans(sweep(yrep_mat, 1, y, FUN = "<="), na.rm = TRUE) }
i_med <- which.min(abs(p_vec - 0.50))
pit_tr <- emp_pit_vec(bt_y(y_tr_keep), fits_fc[[i_med]]$yrep_tr)
pit_fc <- emp_pit_vec(bt_y(y_fc),      fits_fc[[i_med]]$yrep_fc)

plot_pit_hist <- function(pit, title) {
  pit <- pit[is.finite(pit)]
  ks  <- suppressWarnings(stats::ks.test(pit, "punif"))
  ggplot2::ggplot(tibble::tibble(pit = pit), ggplot2::aes(x = pit)) +
    theme_exdqlm() +
    ggplot2::geom_histogram(ggplot2::aes(y = after_stat(density)),
                            boundary = 0, bins = 20, color = "white") +
    ggplot2::geom_hline(yintercept = 1, linetype = 2) +
    ggplot2::labs(title = title, subtitle = sprintf("KS p = %.3f", ks$p.value), x = "PIT", y = "density") +
    ggplot2::coord_cartesian(xlim = c(0, 1), ylim = c(0, NA))
}
plot_pit_qq <- function(pit, title) {
  n <- sum(is.finite(pit)); pit_s <- sort(pit[is.finite(pit)])
  u <- stats::ppoints(n)
  ggplot2::ggplot(tibble::tibble(u = u, pit = pit_s), ggplot2::aes(x = u, y = pit)) +
    theme_exdqlm() + ggplot2::geom_abline(slope = 1, intercept = 0, linetype = 2) +
    ggplot2::geom_point(alpha = 0.7, size = 1.6) +
    ggplot2::labs(title = title, x = "Uniform(0,1) quantiles", y = "PIT quantiles") +
    ggplot2::coord_cartesian(xlim = c(0,1), ylim = c(0,1))
}
g_pit_train    <- plot_pit_hist(pit_tr, "PIT histogram (train)")    | plot_pit_qq(pit_tr, "PIT QQ (train)")
g_pit_forecast <- plot_pit_hist(pit_fc, "PIT histogram (forecast)") | plot_pit_qq(pit_fc, "PIT QQ (forecast)")
timed("PIT: compute + plots + save", {
  print(g_pit_train); print(g_pit_forecast)
  if (isTRUE(save_outputs)) {
   ggplot2::ggsave(file.path(FIGS, nm("pit_train","pit_train.png")),    g_pit_train,    width = 12, height = 4.5, dpi = 150)
   ggplot2::ggsave(file.path(FIGS, nm("pit_forecast","pit_forecast.png")), g_pit_forecast, width = 12, height = 4.5, dpi = 150)
  }
})

# --- Scores: CRPS + mean pinball over p_comp (parity with sim) ----------------
crps_row <- function(y, z) { z <- sort(z); M <- length(z); mean(abs(z - y)) - sum((2*seq_len(M) - M - 1) * z)/(M^2) }
crps_vec <- function(y_vec, draws_mat) {
  stopifnot(length(y_vec) == nrow(draws_mat))
  vapply(seq_len(nrow(draws_mat)), function(i) crps_row(y_vec[i], draws_mat[i, ]), numeric(1))
}

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

# --- Save core objects (parity with sim names/keys) ---------------------------
if (isTRUE(save_outputs)) {
  # For compatibility with sim, build compare_* frames with synth quantiles;
  # include NA placeholders for true_q_* columns so downstream code can reuse keys.
  make_compare_df <- function(y_vec, synth_q_tbl, H, label="Forecast") {
    p_comp <- c(0.05, 0.50, 0.95)
    synth_cols <- lapply(p_comp, function(tau) synth_q_tbl[[paste0("synth_q_", fmt_p(tau))]])
    names(synth_cols) <- paste0("synth_q_", fmt_p(p_comp))
    true_cols <- setNames(replicate(length(p_comp), rep(NA_real_, H), simplify = FALSE),
                          paste0("true_q_", fmt_p(p_comp)))
    tibble::tibble(h = seq_len(H), y = y_vec) |>
      dplyr::bind_cols(as_tibble(true_cols)) |>
      dplyr::bind_cols(as_tibble(synth_cols))
  }
  compare_fc <- make_compare_df(bt_y(y_fc),      synth_q_fc, H_forecast,    "Forecast")
  compare_tr <- make_compare_df(bt_y(y_tr_keep), synth_q_tr, T_train_keep,  "Train")

  # --- Minimal canonical overlay (TRAIN) --------------------------
  g_q_overlay_tr <- plot_quantiles_overlay_from_compare(
    compare_df = compare_tr, taus = p_comp, scope = "Train", window = 200L
  )
  print(g_q_overlay_tr)
  if (isTRUE(save_outputs)) {
    fn <- file.path(FIGS, "train_quantiles_overlay.png")
    if (!file.exists(fn)) ggplot2::ggsave(fn, g_q_overlay_tr, width=9, height=4.8, dpi=150)
  }

  # --- Minimal canonical overlay (FORECAST) -----------------------
  g_q_overlay_fc <- plot_quantiles_overlay_from_compare(
    compare_df = compare_fc, taus = p_comp, scope = "Forecast", window = last_window
  )
  print(g_q_overlay_fc)
  if (isTRUE(save_outputs)) {
    fn <- file.path(FIGS, "forecast_quantiles_overlay.png")
    if (!file.exists(fn)) ggplot2::ggsave(fn, g_q_overlay_fc, width=9, height=4.8, dpi=150)
  }

  saveRDS(
    list(
      fits_fc = fits_fc,
      synth_fc = synth_fc,
      compare_fc = compare_fc,
      compare_tr = compare_tr,
      cfg = list(
        p_vec = p_vec, desn_args = desn_args, vb_args_base = vb_args_base,
        nd_draws = nd_draws, chunk_sz = chunk_sz, last_window = last_window,
        teacher_forcing = list(enable = tf_enable, first_k = tf_first_k,
                               explicit = NULL, y_future_obs_fc = y_future_obs_fc),
        synth = list(isotonic = synth_isotonic, rearrange = synth_rearrange,
                     grid_M = synth_grid_M, n_samp = synth_nsamp, seed = synth_seed),
        split = list(T_use = T_use, n_train = n_train, H_forecast = H_forecast)
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

#!/usr/bin/env Rscript

options(stringsAsFactors = FALSE)

`%||%` <- function(x, y) if (!is.null(x)) x else y

args <- commandArgs(trailingOnly = TRUE)
get_arg <- function(flag, default = NULL) {
  i <- which(args == flag)
  if (length(i) && i < length(args)) args[i + 1L] else default
}

cfg_path <- get_arg("--config", "config/online_vbld/case_study_dlm_constV_smallW.yaml")
out_root <- get_arg("--out_root", "results/online_vbld/case_study")

if (is.null(cfg_path) || !nzchar(cfg_path)) {
  stop("Missing --config path.", call. = FALSE)
}

req <- c("yaml", "jsonlite", "dplyr", "readr", "tibble", "tidyr", "ggplot2", "scales", "pkgload")
for (p in req) {
  if (!requireNamespace(p, quietly = TRUE)) {
    install.packages(p, repos = "https://cloud.r-project.org")
  }
}

suppressPackageStartupMessages({
  library(yaml)
  library(jsonlite)
  library(dplyr)
  library(readr)
  library(tibble)
  library(tidyr)
  library(ggplot2)
  library(scales)
})

script_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
repo_root <- if (length(script_arg)) {
  normalizePath(file.path(dirname(sub("^--file=", "", script_arg[1L])), ".."), mustWork = TRUE)
} else {
  tryCatch(
    normalizePath(system("git rev-parse --show-toplevel", intern = TRUE), mustWork = TRUE),
    error = function(...) normalizePath(".", mustWork = TRUE)
  )
}
setwd(repo_root)

pkgload::load_all(repo_root, quiet = TRUE, export_all = FALSE)
L_fn <- getFromNamespace("L.fn", "exdqlm")
U_fn <- getFromNamespace("U.fn", "exdqlm")

cfg <- yaml::read_yaml(cfg_path)
if (is.null(cfg$case_study)) stop("Config must include case_study block.", call. = FALSE)
cs <- cfg$case_study
diag_cfg <- cfg$diagnostics %||% list()

fix_yaml_bool_keys <- function(x) {
  if (is.null(x) || !is.list(x)) return(x)
  nm <- names(x)
  if (!is.null(nm) && "FALSE" %in% nm && is.null(x$n)) {
    x$n <- x$`FALSE`
    x$`FALSE` <- NULL
  }
  if (!is.null(nm) && "TRUE" %in% nm && is.null(x$y)) {
    x$y <- x$`TRUE`
    x$`TRUE` <- NULL
  }
  x
}

if (!is.null(cs$desn)) cs$desn <- fix_yaml_bool_keys(cs$desn)

dataset_slug <- as.character(cs$dataset_slug %||% "")
if (!nzchar(dataset_slug)) stop("case_study.dataset_slug is required.", call. = FALSE)

stamp <- format(Sys.time(), "%Y%m%d-%H%M%S")
run_dir <- file.path(out_root, dataset_slug, "runs", paste0("online_vbld_case_study__", stamp))
fig_dir <- file.path(run_dir, "figs")
tab_dir <- file.path(run_dir, "tables")
log_dir <- file.path(run_dir, "logs")
man_dir <- file.path(run_dir, "manifest")
dir.create(fig_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(tab_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(log_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(man_dir, recursive = TRUE, showWarnings = FALSE)

log_file <- file.path(log_dir, "run.log")
log_msg <- function(fmt, ...) {
  msg <- sprintf("[%s] %s", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), sprintf(fmt, ...))
  cat(msg, "\n")
  cat(msg, "\n", file = log_file, append = TRUE)
}

writeLines(c(
  sprintf("command: Rscript scripts/online_vbld_case_study_smoke_tuning.R --config %s --out_root %s", cfg_path, out_root),
  sprintf("repo_root: %s", repo_root),
  sprintf("run_dir: %s", run_dir)
), file.path(man_dir, "command.txt"))

set.seed(20260223)

pinball_vec <- function(y, qhat, p0) {
  e <- y - qhat
  (p0 - (e < 0)) * e
}

roll_mean <- function(x, w) {
  x <- as.numeric(x)
  w <- as.integer(w)
  if (!is.finite(w) || w <= 1L) return(x)
  n <- length(x)
  if (!n) return(numeric(0))
  s <- cumsum(c(0, x))
  out <- numeric(n)
  for (i in seq_len(n)) {
    lo <- max(1L, i - w + 1L)
    out[i] <- (s[i + 1L] - s[lo]) / (i - lo + 1L)
  }
  out
}

deep_merge <- function(a, b) {
  if (is.null(b)) return(a)
  if (is.null(a)) return(b)
  if (is.list(a) && is.list(b)) {
    keys <- unique(c(names(a), names(b)))
    out <- lapply(keys, function(k) deep_merge(a[[k]], b[[k]]))
    names(out) <- keys
    return(out)
  }
  b
}

as_num <- function(x, d = NA_real_) {
  x <- suppressWarnings(as.numeric(x)[1L])
  if (is.na(x)) d else x
}

as_int <- function(x, d = NA_integer_) {
  x <- suppressWarnings(as.integer(x)[1L])
  if (is.na(x)) d else x
}

sanitize_nonneg_num <- function(x, d = NA_real_, cap = Inf) {
  v <- suppressWarnings(as.numeric(x)[1L])
  if (!is.finite(v) || v < 0) return(d)
  cap <- suppressWarnings(as.numeric(cap)[1L])
  if (is.finite(cap) && cap > 0 && v > cap) return(d)
  v
}

# -------------------------------
# 1) Case-study lock and evidence
# -------------------------------

datasets_file <- cs$datasets_file %||% "config/datasets.yaml"
if (!file.exists(datasets_file)) stop("datasets file not found: ", datasets_file, call. = FALSE)

datasets <- yaml::read_yaml(datasets_file)$datasets
if (is.null(datasets) || !length(datasets)) stop("No datasets found in ", datasets_file, call. = FALSE)

ds <- NULL
for (d in datasets) {
  if (identical(d$slug, dataset_slug)) {
    ds <- d
    break
  }
}
if (is.null(ds)) stop("Dataset slug not found in registry: ", dataset_slug, call. = FALSE)

input_path <- ds$input_path
if (!file.exists(input_path)) stop("Dataset input missing: ", input_path, call. = FALSE)

opt_spec_file <- as.character(cs$optimal_spec_file %||% "")
opt_candidate_id <- as.character(cs$optimal_candidate_id %||% "")
if (!nzchar(opt_spec_file) || !file.exists(opt_spec_file)) {
  stop("case_study.optimal_spec_file missing or not found.", call. = FALSE)
}
if (!nzchar(opt_candidate_id)) {
  stop("case_study.optimal_candidate_id is required.", call. = FALSE)
}

ms_expand_candidate_grid <- getFromNamespace("ms_expand_candidate_grid", "exdqlm")
ms_candidate_id <- getFromNamespace("ms_candidate_id", "exdqlm")

spec_obj <- yaml::read_yaml(opt_spec_file)
stage1 <- spec_obj$model_selection$stages[[1L]]

cand_list <- ms_expand_candidate_grid(stage1$candidate_grid, stage1$budget, stage1$origins$seed %||% NULL)
cand_ids <- vapply(cand_list, ms_candidate_id, character(1))
cand_idx <- match(opt_candidate_id, cand_ids)
if (is.na(cand_idx)) {
  stop("Could not match optimal_candidate_id in reconstructed candidate grid.", call. = FALSE)
}

cand <- cand_list[[cand_idx]]
opt_specs <- list(
  D = as_int(cand$D, 1L),
  n = as.integer(cand$n),
  n_tilde = as.integer(cand$n_tilde %||% integer(0)),
  m = as_int(cand$m, 60L),
  alpha = as.numeric(cand$alpha),
  rho = as.numeric(cand$rho)
)

records_path <- cs$model_selection_records %||% "docs/model_selection_optimal_records.md"
record_lines <- if (file.exists(records_path)) {
  rr <- readLines(records_path, warn = FALSE)
  rr[grepl(dataset_slug, rr, fixed = TRUE)]
} else character(0)

case_lock <- list(
  timestamp_utc = format(Sys.time(), "%Y-%m-%d %H:%M:%S UTC", tz = "UTC"),
  dataset_slug = dataset_slug,
  dataset_mode = ds$mode,
  dataset_input_path = normalizePath(input_path),
  evidence_paths = list(
    model_selection_records = records_path,
    optimal_spec_file = opt_spec_file,
    optimal_run_status = "results/model_selection/sim/dlm_constV_smallW/runs/20260213-174406__git-1ed4734__spec-modelsel_sim_big_pragmatic_refined_d2probe/tables/model_selection_status.json",
    dataset_registry = datasets_file
  ),
  optimal_candidate_id = opt_candidate_id,
  optimal_candidate_idx_stage1 = as.integer(cand_idx),
  optimal_specs = opt_specs,
  target_quantile = as_num(cs$p0, 0.5),
  record_lines = record_lines,
  assumptions = list(
    single_quantile_used_for_tuning = TRUE,
    selected_quantile = as_num(cs$p0, 0.5),
    schedule_grid_from_prompt = TRUE
  )
)

jsonlite::write_json(case_lock, file.path(man_dir, "case_study_lock.json"), pretty = TRUE, auto_unbox = TRUE)
log_msg("Case-study lock written: %s", file.path(man_dir, "case_study_lock.json"))

# -------------------------------
# 2) Load data and build split
# -------------------------------

log_msg("Loading dataset: %s", input_path)
dat_long <- suppressMessages(readr::read_csv(input_path, show_col_types = FALSE))
need_cols <- c("t", "p", "q", "y")
if (!all(need_cols %in% names(dat_long))) {
  stop(sprintf("Input data must include columns: %s", paste(need_cols, collapse = ", ")), call. = FALSE)
}

dat_long <- dat_long %>%
  mutate(
    t = as.integer(t),
    p = as.numeric(p),
    q = as.numeric(q),
    y = as.numeric(y)
  ) %>%
  arrange(t, p)

y_full_df <- dat_long %>% distinct(t, y) %>% arrange(t)
T_full <- nrow(y_full_df)

split_cfg <- cs$split %||% list()
T_use <- as_int(split_cfg$T_use, T_full)
if (!is.finite(T_use) || T_use <= 0L) T_use <- T_full
T_use <- min(T_use, T_full)
use_last <- isTRUE(split_cfg$use_last %||% TRUE)
train_prop <- as_num(split_cfg$train_prop, 0.94)
if (!is.finite(train_prop) || train_prop <= 0 || train_prop >= 1) train_prop <- 0.94

idx_use <- if (use_last) {
  seq.int(T_full - T_use + 1L, T_full)
} else {
  seq_len(T_use)
}

y_use_df <- y_full_df[idx_use, , drop = FALSE]
y_use <- as.numeric(y_use_df$y)
t_use <- as.integer(y_use_df$t)

n_train <- max(10L, min(T_use - 1L, floor(T_use * train_prop)))
idx_train <- seq_len(n_train)
idx_eval <- seq.int(n_train + 1L, T_use)

p0 <- as_num(cs$p0, 0.5)

# q_true per t at target quantile (nearest available p)
q_true_tbl <- dat_long %>%
  group_by(t) %>%
  slice_min(order_by = abs(p - p0), n = 1, with_ties = FALSE) %>%
  ungroup() %>%
  select(t, p, q)

q_true_use <- q_true_tbl$q[match(t_use, q_true_tbl$t)]

# -------------------------------
# 3) Build design matrix (optimal DESN)
# -------------------------------

defaults_cfg <- yaml::read_yaml("config/defaults.yaml")
if (!is.null(defaults_cfg$desn)) defaults_cfg$desn <- fix_yaml_bool_keys(defaults_cfg$desn)
defaults_vb <- defaults_cfg$vb %||% list()

u_first <- function(x, default = NULL) {
  if (is.null(x)) return(default)
  if (is.list(x)) x <- unlist(x, use.names = FALSE)
  x[1L]
}

desn_cfg <- cs$desn %||% list()
D_opt <- as_int(desn_cfg$D, opt_specs$D)
if (D_opt != opt_specs$D) {
  warning("Config D differs from optimal lock; using locked optimal D.")
  D_opt <- opt_specs$D
}

n_opt_raw <- desn_cfg$n %||% opt_specs$n
if (is.list(n_opt_raw)) n_opt_raw <- unlist(n_opt_raw, use.names = FALSE)
n_opt <- as.integer(n_opt_raw)
if (!length(n_opt) || all(is.na(n_opt))) n_opt <- as.integer(opt_specs$n)
if (length(n_opt) != D_opt) n_opt <- rep(n_opt[1L], D_opt)

alpha_raw <- desn_cfg$alpha %||% opt_specs$alpha
if (is.list(alpha_raw)) alpha_raw <- unlist(alpha_raw, use.names = FALSE)
alpha_opt <- as.numeric(alpha_raw)
if (!length(alpha_opt) || all(is.na(alpha_opt))) alpha_opt <- as.numeric(opt_specs$alpha)
if (length(alpha_opt) != D_opt) alpha_opt <- rep(alpha_opt[1L], D_opt)

rho_raw <- desn_cfg$rho %||% opt_specs$rho
if (is.list(rho_raw)) rho_raw <- unlist(rho_raw, use.names = FALSE)
rho_opt <- as.numeric(rho_raw)
if (!length(rho_opt) || all(is.na(rho_opt))) rho_opt <- as.numeric(opt_specs$rho)
if (length(rho_opt) != D_opt) rho_opt <- rep(rho_opt[1L], D_opt)

n_tilde_opt <- as.integer(desn_cfg$n_tilde %||% opt_specs$n_tilde)
if (D_opt <= 1L) n_tilde_opt <- integer(0)
if (D_opt > 1L && length(n_tilde_opt) == 1L) n_tilde_opt <- rep(n_tilde_opt[1L], D_opt - 1L)
if (D_opt > 1L && length(n_tilde_opt) != (D_opt - 1L)) {
  stop("n_tilde length mismatch for D.", call. = FALSE)
}

pi_w_val <- as.numeric(desn_cfg$pi_w %||% defaults_cfg$desn$pi_w %||% 0.1)
if (length(pi_w_val) == 1L) pi_w_val <- rep(pi_w_val, D_opt)

pi_in_val <- as.numeric(desn_cfg$pi_in %||% defaults_cfg$desn$pi_in %||% 1.0)
if (length(pi_in_val) == 1L) pi_in_val <- rep(pi_in_val, D_opt)

seed_val <- as.integer(u_first(desn_cfg$seed %||% defaults_cfg$desn$seed, 12345))

m_opt <- as_int(desn_cfg$m, opt_specs$m)
if (!identical(m_opt, opt_specs$m)) {
  warning("Config m differs from optimal lock; using locked optimal m.")
  m_opt <- opt_specs$m
}

washout_val <- as_int(desn_cfg$washout, as_int(defaults_cfg$desn$washout, 500L))
add_bias_val <- isTRUE(desn_cfg$add_bias %||% defaults_cfg$desn$add_bias %||% TRUE)

act_f_val <- as.character(u_first(desn_cfg$act_f %||% defaults_cfg$desn$act_f, "tanh"))
act_k_val <- as.character(u_first(desn_cfg$act_k %||% defaults_cfg$desn$act_k, "identity"))

desn_args <- list(
  D = D_opt,
  n = n_opt,
  n_tilde = n_tilde_opt,
  m = m_opt,
  alpha = alpha_opt,
  rho = rho_opt,
  act_f = act_f_val,
  act_k = act_k_val,
  pi_w = pi_w_val,
  pi_in = pi_in_val,
  washout = washout_val,
  add_bias = add_bias_val,
  seed = seed_val
)

log_msg("Building Q-DESN design matrix with optimal specs: D=%d n=%s m=%d alpha=%s rho=%s",
        D_opt, paste(n_opt, collapse = ","), m_opt,
        paste(round(alpha_opt, 4), collapse = ","),
        paste(round(rho_opt, 4), collapse = ","))

design <- qdesn_build_design(y_use, desn_args = desn_args)
X_all <- as.matrix(design$X)
keep_idx <- as.integer(design$keep_idx)

train_mask <- keep_idx <= n_train
eval_mask <- keep_idx %in% idx_eval
if (!any(train_mask)) stop("No training rows after washout/lag alignment.", call. = FALSE)
if (!any(eval_mask)) stop("No evaluation rows after washout/lag alignment.", call. = FALSE)

X_train <- X_all[train_mask, , drop = FALSE]
y_train <- y_use[keep_idx[train_mask]]

X_eval <- X_all[eval_mask, , drop = FALSE]
y_eval <- y_use[keep_idx[eval_mask]]
q_true_eval <- q_true_use[keep_idx[eval_mask]]
t_eval <- t_use[keep_idx[eval_mask]]

k_dim <- ncol(X_train)
log_msg("Design ready: train=%d eval=%d k=%d", nrow(X_train), nrow(X_eval), k_dim)

# -------------------------------
# 4) Prior and fit controls
# -------------------------------

vb_cfg <- cs$vb %||% list()

selection_cfg <- cfg$selection %||% list()
jitter_eps_cap <- as_num(selection_cfg$jitter_eps_cap, 1e50)
if (!is.finite(jitter_eps_cap) || jitter_eps_cap <= 0) jitter_eps_cap <- 1e50

vb_control <- list(
  max_iter = as_int(vb_cfg$max_iter, 80L),
  min_iter_elbo = as_int(vb_cfg$min_iter_elbo, 20L),
  tol = as_num(vb_cfg$tol, 1e-4),
  tol_par = as_num(vb_cfg$tol_par, 1e-4),
  n_samp_xi = as_int(vb_cfg$n_samp_xi, 500L),
  verbose = FALSE
)

beta_prior_type <- tolower(as.character(vb_cfg$beta_prior_type %||% defaults_vb$priors$beta$type %||% "rhs"))

if (beta_prior_type == "rhs") {
  rhs_hypers <- defaults_vb$priors$beta$rhs %||% list()
  if (!is.list(rhs_hypers)) rhs_hypers <- list()
  beta_prior_obj <- beta_prior("rhs", rhs = rhs_hypers)
} else {
  tau2 <- as_num(defaults_vb$priors$beta$ridge$tau2, 1e4)
  beta_prior_obj <- beta_prior("ridge", ridge = list(tau2 = tau2))
}

gamma_bounds <- c(L_fn(p0), U_fn(p0))

# -------------------------------
# 5) Runner helpers
# -------------------------------

extract_offline_health <- function(fit) {
  V <- as.matrix(fit$qbeta$V)
  V <- 0.5 * (V + t(V))
  eg <- suppressWarnings(eigen(V, symmetric = TRUE, only.values = TRUE)$values)
  min_eig <- suppressWarnings(min(eg))
  list(
    is_finite_beta = all(is.finite(fit$qbeta$m)) && all(is.finite(V)),
    is_finite_sigmagam = all(is.finite(c(fit$qsiggam$eta_hat, fit$qsiggam$ell_hat, fit$qsiggam$gamma_mean, fit$qsiggam$sigma_mean))),
    P_spd = is.finite(min_eig) && (min_eig > 0),
    min_eig_P = as_num(min_eig, NA_real_),
    rhs_refreshes = NA_integer_,
    sigmagam_refreshes = NA_integer_,
    window_backfits = NA_integer_,
    n_chol_fail = NA_integer_,
    n_jitter = NA_integer_,
    max_jitter_eps = NA_real_,
    last_jitter_eps = NA_real_
  )
}

run_one_fit <- function(label, schedule = NULL, online = FALSE) {
  log_msg("Run start: %s", label)
  keep_trace <- isTRUE(diag_cfg$keep_trace) && isTRUE(online)

  ctrl <- if (isTRUE(online)) {
    list(
      enabled = TRUE,
      strict = as_int(schedule$W, 0L) == 0L,
      M = as_int(schedule$M, 2L),
      K = as_int(schedule$K, 4L),
      W = as_int(schedule$W, 24L),
      L_loc = as_int(schedule$L_loc, 2L),
      window_passes = 1L,
      keep_trace = keep_trace,
      jitter = 1e-10,
      update_rhs = TRUE,
      update_sigmagam = TRUE
    )
  } else {
    list(enabled = FALSE)
  }

  if (isTRUE(online) && ctrl$K < ctrl$M) {
    return(list(
      row = tibble(
        run_label = label,
        mode = if (online) "online" else "offline",
        status = "failed",
        error = sprintf("Invalid schedule: K(%d) < M(%d)", ctrl$K, ctrl$M),
        runtime_sec = NA_real_,
        M = ctrl$M, K = ctrl$K, W = ctrl$W, L_loc = ctrl$L_loc,
        check_loss_mean = NA_real_,
        coverage = NA_real_,
        coverage_error = NA_real_,
        mae_qtrue = NA_real_,
        rmse_qtrue = NA_real_,
        finite_ok = FALSE,
        spd_ok = FALSE,
        n_chol_fail = NA_real_,
        n_jitter = NA_real_,
        max_jitter_eps = NA_real_,
        last_jitter_eps = NA_real_,
        rhs_refreshes = NA_real_,
        sigmagam_refreshes = NA_real_,
        window_backfits = NA_real_
      ),
      series = NULL,
      fit = NULL,
      trace = NULL
    ))
  }

  t0 <- proc.time()[3]
  fit <- tryCatch(
    exal_online_fit(
      y = y_train,
      X = X_train,
      p0 = p0,
      gamma_bounds = gamma_bounds,
      control = ctrl,
      vb_control = vb_control,
      max_iter = vb_control$max_iter,
      tol = vb_control$tol,
      tol_par = vb_control$tol_par,
      n_samp_xi = vb_control$n_samp_xi,
      verbose = FALSE,
      init = list(gamma = 0, sigma = 1),
      beta_prior_obj = beta_prior_obj
    ),
    error = function(e) e
  )
  runtime_sec <- as.numeric(proc.time()[3] - t0)

  if (inherits(fit, "error")) {
    log_msg("Run failed: %s | %s", label, conditionMessage(fit))
    return(list(
      row = tibble(
        run_label = label,
        mode = if (online) "online" else "offline",
        status = "failed",
        error = conditionMessage(fit),
        runtime_sec = runtime_sec,
        M = if (online) ctrl$M else NA_integer_,
        K = if (online) ctrl$K else NA_integer_,
        W = if (online) ctrl$W else NA_integer_,
        L_loc = if (online) ctrl$L_loc else NA_integer_,
        check_loss_mean = NA_real_,
        coverage = NA_real_,
        coverage_error = NA_real_,
        mae_qtrue = NA_real_,
        rmse_qtrue = NA_real_,
        finite_ok = FALSE,
        spd_ok = FALSE,
        n_chol_fail = NA_real_,
        n_jitter = NA_real_,
        max_jitter_eps = NA_real_,
        last_jitter_eps = NA_real_,
        rhs_refreshes = NA_real_,
        sigmagam_refreshes = NA_real_,
        window_backfits = NA_real_
      ),
      series = NULL,
      fit = NULL,
      trace = NULL
    ))
  }

  qhat_eval <- as.numeric(X_eval %*% fit$qbeta$m)
  check_vals <- pinball_vec(y_eval, qhat_eval, p0)
  coverage <- mean(y_eval <= qhat_eval, na.rm = TRUE)
  coverage_error <- abs(coverage - p0)

  has_qtrue <- all(is.finite(q_true_eval))
  mae_qtrue <- if (has_qtrue) mean(abs(qhat_eval - q_true_eval), na.rm = TRUE) else NA_real_
  rmse_qtrue <- if (has_qtrue) sqrt(mean((qhat_eval - q_true_eval)^2, na.rm = TRUE)) else NA_real_

  if (isTRUE(online) && isTRUE(fit$misc$online$enabled %||% FALSE) && !is.null(fit$misc$online$health)) {
    h <- fit$misc$online$health
  } else {
    h <- extract_offline_health(fit)
  }

  finite_ok <- isTRUE(h$is_finite_beta) && isTRUE(h$is_finite_sigmagam)
  spd_ok <- isTRUE(h$P_spd)
  n_jitter <- sanitize_nonneg_num(h$n_jitter, d = NA_real_)
  max_jitter_eps_raw <- sanitize_nonneg_num(h$max_jitter_eps, d = NA_real_)
  last_jitter_eps_raw <- sanitize_nonneg_num(h$last_jitter_eps, d = NA_real_)
  max_jitter_eps <- sanitize_nonneg_num(h$max_jitter_eps, d = NA_real_, cap = jitter_eps_cap)
  last_jitter_eps <- sanitize_nonneg_num(h$last_jitter_eps, d = NA_real_, cap = jitter_eps_cap)

  series <- tibble(
    run_label = label,
    t = as.integer(t_eval),
    y = as.numeric(y_eval),
    q_true = as.numeric(q_true_eval),
    qhat = as.numeric(qhat_eval),
    check_loss = as.numeric(check_vals),
    abs_err_qtrue = if (has_qtrue) as.numeric(abs(qhat_eval - q_true_eval)) else NA_real_
  )
  trace <- NULL
  if (isTRUE(online) && isTRUE(keep_trace)) {
    tr <- fit$misc$online$trace %||% NULL
    if (is.data.frame(tr) && nrow(tr)) {
      trace <- as_tibble(tr) %>% mutate(run_label = label, .before = 1)
    }
  }

  row <- tibble(
    run_label = label,
    mode = if (online) "online" else "offline",
    status = "success",
    error = NA_character_,
    runtime_sec = runtime_sec,
    M = if (online) as.integer(ctrl$M) else NA_integer_,
    K = if (online) as.integer(ctrl$K) else NA_integer_,
    W = if (online) as.integer(ctrl$W) else NA_integer_,
    L_loc = if (online) as.integer(ctrl$L_loc) else NA_integer_,
    check_loss_mean = mean(check_vals, na.rm = TRUE),
    coverage = coverage,
    coverage_error = coverage_error,
    mae_qtrue = mae_qtrue,
    rmse_qtrue = rmse_qtrue,
    finite_ok = finite_ok,
    spd_ok = spd_ok,
    n_chol_fail = as_num(h$n_chol_fail, NA_real_),
    n_jitter = n_jitter,
    max_jitter_eps_raw = max_jitter_eps_raw,
    last_jitter_eps_raw = last_jitter_eps_raw,
    max_jitter_eps = max_jitter_eps,
    last_jitter_eps = last_jitter_eps,
    rhs_refreshes = as_num(h$rhs_refreshes, NA_real_),
    sigmagam_refreshes = as_num(h$sigmagam_refreshes, NA_real_),
    window_backfits = as_num(h$window_backfits, NA_real_)
  )

  log_msg(
    "Run done: %s | status=success | runtime=%.2fs | check=%.4f | cov_err=%.4f | rmse_qtrue=%.4f",
    label, runtime_sec, row$check_loss_mean, row$coverage_error, row$rmse_qtrue
  )

  list(row = row, series = series, fit = fit, trace = trace)
}

# -------------------------------
# 6) Smoke checks in both modes
# -------------------------------

run_pipeline_smoke <- function(smoke_label, online_enabled, online_schedule = NULL) {
  smoke_cfg <- cs$smoke %||% list(enabled = FALSE)
  if (!isTRUE(smoke_cfg$enabled)) {
    return(tibble(
      smoke_label = smoke_label,
      vb_online_enabled = online_enabled,
      status = "skipped",
      runtime_sec = NA_real_,
      log_file = NA_character_,
      out_dir = NA_character_,
      notes = "smoke disabled in config"
    ))
  }

  cfg_base <- defaults_cfg
  mode_key <- tolower(ds$mode %||% cfg_base$pipeline$mode %||% "sim")
  if (!is.null(cfg_base$mode_overrides) && !is.null(cfg_base$mode_overrides[[mode_key]])) {
    cfg_base <- deep_merge(cfg_base, cfg_base$mode_overrides[[mode_key]])
  }

  cfg_base$pipeline$mode <- "sim"
  cfg_base$p_vec <- c(p0)
  cfg_base$split$T_use <- T_use
  cfg_base$split$train_prop <- train_prop
  cfg_base$split$use_last <- use_last

  cfg_base$desn$D <- D_opt
  cfg_base$desn$n <- n_opt
  cfg_base$desn$n_tilde <- n_tilde_opt
  cfg_base$desn$m <- m_opt
  cfg_base$desn$alpha <- alpha_opt
  cfg_base$desn$rho <- rho_opt
  cfg_base$desn$act_f <- act_f_val
  cfg_base$desn$act_k <- act_k_val
  cfg_base$desn$pi_w <- pi_w_val
  cfg_base$desn$pi_in <- pi_in_val
  cfg_base$desn$washout <- washout_val
  cfg_base$desn$add_bias <- add_bias_val
  cfg_base$desn$seed <- seed_val

  cfg_base$vb$max_iter <- as_int(smoke_cfg$vb_max_iter, 35L)
  cfg_base$vb$min_iter_elbo <- min(as_int(vb_control$min_iter_elbo, 10L), cfg_base$vb$max_iter)
  cfg_base$vb$tol <- vb_control$tol
  cfg_base$vb$tol_par <- vb_control$tol_par
  cfg_base$vb$n_samp_xi <- vb_control$n_samp_xi
  cfg_base$vb$verbose <- FALSE

  cfg_base$sampling$nd_draws <- as_int(smoke_cfg$nd_draws, 600L)
  cfg_base$synthesis$n_samp <- as_int(smoke_cfg$synth_n_samp, 600L)
  cfg_base$forecast$horizon <- as_int(smoke_cfg$horizon, 60L)

  cfg_base$diagnostics$plots <- FALSE
  cfg_base$diagnostics$calibration <- FALSE
  cfg_base$diagnostics$pit <- FALSE
  cfg_base$diagnostics$fan_charts <- FALSE
  cfg_base$diagnostics$scores <- TRUE

  cfg_base$outputs$save <- TRUE
  cfg_base$outputs$keep_draws <- FALSE
  cfg_base$outputs$thesis_subset <- FALSE

  online_cfg <- cfg_base$vb$online %||% list()
  online_cfg$enabled <- isTRUE(online_enabled)
  if (isTRUE(online_enabled) && !is.null(online_schedule)) {
    online_cfg$M <- as_int(online_schedule$M, 5L)
    online_cfg$K <- as_int(online_schedule$K, 20L)
    online_cfg$W <- as_int(online_schedule$W, 100L)
    online_cfg$L_loc <- as_int(online_schedule$L_loc, 2L)
    online_cfg$strict <- as_int(online_cfg$W, 0L) == 0L
  }
  online_cfg$keep_trace <- FALSE
  cfg_base$vb$online <- online_cfg

  smoke_out_dir <- file.path(run_dir, "smoke", smoke_label)
  dir.create(smoke_out_dir, recursive = TRUE, showWarnings = FALSE)
  smoke_log <- file.path(log_dir, sprintf("smoke_%s.log", smoke_label))

  env_new <- c(
    EXDQLM_FILE_LONG = normalizePath(input_path),
    EXDQLM_OUT_DIR = normalizePath(smoke_out_dir, mustWork = FALSE),
    EXDQLM_SAVE_OUTPUTS = "1",
    EXDQLM_CFG_JSON = as.character(
      jsonlite::toJSON(cfg_base, auto_unbox = TRUE, null = "null", digits = NA)
    )
  )
  env_keys <- names(env_new)
  env_old <- Sys.getenv(env_keys, unset = NA_character_)
  restore_env <- function() {
    to_unset <- env_keys[is.na(env_old)]
    if (length(to_unset)) Sys.unsetenv(to_unset)
    to_set <- env_keys[!is.na(env_old)]
    if (length(to_set)) {
      vals <- as.list(stats::setNames(unname(env_old[to_set]), to_set))
      do.call(Sys.setenv, vals)
    }
  }
  on.exit(restore_env(), add = TRUE)
  do.call(Sys.setenv, as.list(env_new))

  cmd <- c("scripts/pipeline_sim_main.R")
  t0 <- proc.time()[3]
  status <- system2("Rscript", args = cmd, stdout = smoke_log, stderr = smoke_log)
  runtime_sec <- as.numeric(proc.time()[3] - t0)

  smoke_ok <- identical(as.integer(status), 0L)
  p_vec_smoke <- as.numeric(cfg_base$p_vec %||% numeric(0))
  n_q_smoke <- length(unique(p_vec_smoke[is.finite(p_vec_smoke)]))
  single_quantile_smoke <- n_q_smoke <= 1L

  score_path <- file.path(smoke_out_dir, "tables", "scores_summary.csv")
  forecast_path <- file.path(smoke_out_dir, "models", "forecast_objects.rds")
  rhs_summary_path <- file.path(smoke_out_dir, "models", "rhs_run_summary.csv")
  outputs_ok <- if (single_quantile_smoke) {
    file.exists(forecast_path) && file.exists(rhs_summary_path)
  } else {
    file.exists(score_path)
  }

  status_txt <- if (smoke_ok && outputs_ok) "success" else "failed"
  notes_txt <- if (!smoke_ok) {
    "pipeline returned non-zero exit status"
  } else if (!outputs_ok && single_quantile_smoke) {
    "pipeline completed but missing single-quantile smoke artifacts"
  } else if (!outputs_ok) {
    "pipeline completed but missing scores_summary.csv"
  } else if (single_quantile_smoke) {
    "pipeline completed; single-quantile smoke artifacts found"
  } else {
    "pipeline completed and scores_summary.csv found"
  }

  tibble(
    smoke_label = smoke_label,
    vb_online_enabled = online_enabled,
    status = status_txt,
    runtime_sec = runtime_sec,
    log_file = smoke_log,
    out_dir = smoke_out_dir,
    notes = notes_txt
  )
}

smoke_rows <- list()
smoke_rows[[1L]] <- run_pipeline_smoke("offline", online_enabled = FALSE)
smoke_rows[[2L]] <- run_pipeline_smoke("online_default", online_enabled = TRUE, online_schedule = cfg$schedules$grid[[cfg$schedules$default_candidate %||% "C4"]])
smoke_df <- bind_rows(smoke_rows)
readr::write_csv(smoke_df, file.path(tab_dir, "smoke_summary.csv"))

# -------------------------------
# 7) Schedule tuning runs
# -------------------------------

sched_grid <- cfg$schedules$grid
if (is.null(sched_grid) || !length(sched_grid)) stop("schedules.grid is required.", call. = FALSE)

res_rows <- list()
series_map <- list()
fit_map <- list()
trace_map <- list()

# Offline baseline
off_res <- run_one_fit("offline", online = FALSE)
res_rows[[length(res_rows) + 1L]] <- off_res$row
series_map[["offline"]] <- off_res$series
fit_map[["offline"]] <- off_res$fit
trace_map[["offline"]] <- off_res$trace

# Online C1..C6
sched_names <- names(sched_grid)
for (nm in sched_names) {
  sc <- sched_grid[[nm]]
  rr <- run_one_fit(nm, schedule = sc, online = TRUE)
  res_rows[[length(res_rows) + 1L]] <- rr$row
  series_map[[nm]] <- rr$series
  fit_map[[nm]] <- rr$fit
  trace_map[[nm]] <- rr$trace
}

summary_df <- bind_rows(res_rows)

default_id <- as.character(cfg$schedules$default_candidate %||% "C4")
if (!(default_id %in% summary_df$run_label)) {
  stop("default_candidate not found in run results: ", default_id, call. = FALSE)
}

default_row <- summary_df %>% filter(run_label == default_id) %>% slice(1)
default_alias <- default_row %>% mutate(run_label = "online_default", notes_alias = sprintf("alias_of_%s", default_id))
if (!("notes_alias" %in% names(summary_df))) summary_df$notes_alias <- NA_character_
summary_df <- bind_rows(summary_df, default_alias)

# Offline-relative deltas
offline_row <- summary_df %>% filter(run_label == "offline") %>% slice(1)
if (nrow(offline_row) == 1L && is.finite(offline_row$check_loss_mean)) {
  summary_df <- summary_df %>%
    mutate(
      delta_check_vs_offline = check_loss_mean - offline_row$check_loss_mean,
      delta_rmse_qtrue_vs_offline = rmse_qtrue - offline_row$rmse_qtrue
    )
} else {
  summary_df <- summary_df %>% mutate(delta_check_vs_offline = NA_real_, delta_rmse_qtrue_vs_offline = NA_real_)
}

readr::write_csv(summary_df, file.path(tab_dir, "run_summary.csv"))
readr::write_csv(summary_df %>% mutate(across(where(is.numeric), ~ round(., 6))), file.path(tab_dir, "run_summary_pretty.csv"))

# Save per-run series
for (nm in names(series_map)) {
  s <- series_map[[nm]]
  if (!is.null(s) && nrow(s)) {
    readr::write_csv(s, file.path(tab_dir, sprintf("series_%s.csv", nm)))
  }
}

# Save per-run trace when enabled/available
for (nm in names(trace_map)) {
  tr <- trace_map[[nm]]
  if (!is.null(tr) && nrow(tr)) {
    readr::write_csv(tr, file.path(tab_dir, sprintf("trace_%s.csv", nm)))
  }
}

# Drift diagnostics across phases (offline from series; online from trace when available)
phase_summaries <- list()
phase_breaks <- function(n) {
  if (n <= 0L) return(list())
  b1 <- max(1L, floor(n / 3L))
  b2 <- max(b1 + 1L, floor(2L * n / 3L))
  list(
    start = seq.int(1L, b1),
    mid = seq.int(b1 + 1L, max(b1 + 1L, b2)),
    end = seq.int(max(b2 + 1L, 1L), n)
  )
}

diag_ids <- unique(c("offline", names(sched_grid)))
for (id in diag_ids) {
  tr <- trace_map[[id]]
  sr <- series_map[[id]]
  mode_i <- summary_df %>% filter(run_label == id) %>% slice(1) %>% pull(mode)
  mode_i <- if (length(mode_i)) as.character(mode_i[[1L]]) else ifelse(id == "offline", "offline", "online")

  source_type <- "series"
  if (!is.null(tr) && nrow(tr)) {
    check_vec <- as.numeric(tr$check_loss_pre)
    covered_vec <- as.numeric(tr$covered_pre)
    jitter_vec <- as.numeric(tr$jitter_eps)
    source_type <- "trace"
  } else if (!is.null(sr) && nrow(sr)) {
    check_vec <- as.numeric(sr$check_loss)
    covered_vec <- as.numeric(sr$y <= sr$qhat)
    jitter_vec <- rep(NA_real_, length(check_vec))
  } else {
    next
  }

  n_i <- length(check_vec)
  pmap <- phase_breaks(n_i)
  if (!length(pmap)) next

  for (ph in names(pmap)) {
    idx <- pmap[[ph]]
    if (!length(idx)) next
    chk <- check_vec[idx]
    covr <- covered_vec[idx]
    jit <- jitter_vec[idx]
    cov_mean <- mean(covr, na.rm = TRUE)
    phase_summaries[[length(phase_summaries) + 1L]] <- tibble(
      run_label = id,
      mode = mode_i,
      source = source_type,
      phase = ph,
      n_points = length(idx),
      check_loss_mean = mean(chk, na.rm = TRUE),
      coverage = cov_mean,
      coverage_gap = cov_mean - p0,
      jitter_mean = mean(jit, na.rm = TRUE),
      jitter_pos_rate = mean(jit > 0, na.rm = TRUE)
    )
  }
}

drift_df <- bind_rows(phase_summaries)
if (nrow(drift_df)) {
  drift_df <- drift_df %>%
    mutate(
      jitter_mean = ifelse(is.nan(jitter_mean), NA_real_, jitter_mean),
      jitter_pos_rate = ifelse(is.nan(jitter_pos_rate), NA_real_, jitter_pos_rate)
    )
  readr::write_csv(drift_df, file.path(tab_dir, "diagnostic_drift_summary.csv"))
}

# Config diffs table for schedules
sched_tbl <- bind_rows(lapply(names(sched_grid), function(nm) {
  sc <- sched_grid[[nm]]
  tibble(run_label = nm, M = as_int(sc$M, NA_integer_), K = as_int(sc$K, NA_integer_), W = as_int(sc$W, NA_integer_), L_loc = as_int(sc$L_loc, NA_integer_))
}))
readr::write_csv(sched_tbl, file.path(tab_dir, "config_diffs.csv"))

# -------------------------------
# 8) Recommendation logic
# -------------------------------

coverage_error_max <- as_num(cfg$selection$coverage_error_max, 0.08)
near_best_tol <- as_num(cfg$selection$near_best_tol, 0.05)
jitter_stability_cap <- as_num(selection_cfg$max_jitter_eps_for_stability, jitter_eps_cap)
if (!is.finite(jitter_stability_cap) || jitter_stability_cap <= 0) jitter_stability_cap <- jitter_eps_cap

gate_cfg <- selection_cfg$acceptance %||% list()
gate_enabled <- if (is.null(gate_cfg$enabled)) TRUE else isTRUE(gate_cfg$enabled)
gate_max_check_increase <- as_num(gate_cfg$max_check_loss_increase, 0)
gate_max_cov_err_increase <- as_num(gate_cfg$max_coverage_error_increase, 0)
if (!is.finite(gate_max_check_increase) || gate_max_check_increase < 0) gate_max_check_increase <- 0
if (!is.finite(gate_max_cov_err_increase) || gate_max_cov_err_increase < 0) gate_max_cov_err_increase <- 0

cand_df <- summary_df %>%
  filter(run_label %in% names(sched_grid)) %>%
  mutate(
    jitter_ok = is.na(max_jitter_eps_raw) | (is.finite(max_jitter_eps_raw) & max_jitter_eps_raw <= jitter_stability_cap),
    stable = status == "success" &
      ifelse(is.na(finite_ok), FALSE, finite_ok) &
      ifelse(is.na(spd_ok), FALSE, spd_ok) &
      ifelse(is.na(jitter_ok), TRUE, jitter_ok),
    coverage_ok = is.finite(coverage_error) & coverage_error <= coverage_error_max
  )

cand_pool <- cand_df %>% filter(stable, coverage_ok)
if (!nrow(cand_pool)) cand_pool <- cand_df %>% filter(stable)
if (!nrow(cand_pool)) cand_pool <- cand_df %>% filter(status == "success")

if (!nrow(cand_pool)) {
  rec_id <- NA_character_
  fallback_id <- NA_character_
} else {
  ord_cols <- c("check_loss_mean", "runtime_sec")
  if (all(is.finite(cand_pool$rmse_qtrue))) ord_cols <- c("check_loss_mean", "rmse_qtrue", "runtime_sec")
  cand_pool <- cand_pool %>% arrange(across(all_of(ord_cols)))
  rec_id <- cand_pool$run_label[1L]

  best_check <- cand_pool$check_loss_mean[1L]
  fb_pool <- cand_pool %>%
    filter(run_label != rec_id, check_loss_mean <= (1 + near_best_tol) * best_check)
  if (!nrow(fb_pool)) fb_pool <- cand_pool %>% filter(run_label != rec_id)

  fallback_id <- if (nrow(fb_pool)) {
    fb_pool %>% arrange(runtime_sec, coverage_error, check_loss_mean) %>% slice(1) %>% pull(run_label)
  } else {
    rec_id
  }
}

rec_schedule_id <- rec_id
fallback_schedule_id <- fallback_id
gate_triggered <- FALSE
gate_reason <- NA_character_
rec_id <- rec_schedule_id
fallback_id <- fallback_schedule_id

if (gate_enabled && !is.na(rec_schedule_id) && rec_schedule_id %in% names(sched_grid)) {
  offline_ok <- nrow(offline_row) == 1L && identical(offline_row$status[[1L]], "success")
  rec_row <- summary_df %>% filter(run_label == rec_schedule_id) %>% slice(1)
  rec_ok <- nrow(rec_row) == 1L && identical(rec_row$status[[1L]], "success")

  if (offline_ok && rec_ok) {
    d_check <- rec_row$check_loss_mean[[1L]] - offline_row$check_loss_mean[[1L]]
    d_cov <- rec_row$coverage_error[[1L]] - offline_row$coverage_error[[1L]]
    check_worse <- is.finite(d_check) && (d_check > gate_max_check_increase)
    cov_worse <- is.finite(d_cov) && (d_cov > gate_max_cov_err_increase)

    if (isTRUE(check_worse) && isTRUE(cov_worse)) {
      gate_triggered <- TRUE
      rec_id <- "offline"
      fallback_id <- fallback_schedule_id %||% rec_schedule_id
      gate_reason <- sprintf(
        "online_vs_offline gate triggered (delta_check=%.6f > %.6f, delta_cov_err=%.6f > %.6f)",
        d_check, gate_max_check_increase, d_cov, gate_max_cov_err_increase
      )
    }
  }
}

rec_tbl <- tibble(
  recommended_default = rec_id,
  safer_fallback = fallback_id,
  recommended_online_candidate = rec_schedule_id,
  gate_enabled = gate_enabled,
  gate_triggered = gate_triggered,
  gate_reason = gate_reason,
  gate_max_check_loss_increase = gate_max_check_increase,
  gate_max_coverage_error_increase = gate_max_cov_err_increase,
  recommended_vb_online_enabled = !is.na(rec_id) && rec_id != "offline",
  coverage_error_max = coverage_error_max,
  near_best_tol = near_best_tol,
  max_jitter_eps_for_stability = jitter_stability_cap
)
readr::write_csv(rec_tbl, file.path(tab_dir, "recommendation.csv"))

# -------------------------------
# 9) Visualizations
# -------------------------------

best_id <- rec_id %||% default_id

safe_series <- function(id) series_map[[id]]

overlay_ids <- unique(c("offline", default_id, best_id))
overlay_ids <- overlay_ids[overlay_ids %in% names(series_map)]

if (length(overlay_ids) >= 2L) {
  ov <- bind_rows(lapply(overlay_ids, function(id) {
    s <- safe_series(id)
    if (is.null(s)) return(NULL)
    s %>% mutate(series = id)
  }))

  if (!is.null(ov) && nrow(ov)) {
    df_y <- ov %>% distinct(t, y, q_true)
    p_overlay <- ggplot() +
      geom_line(data = df_y, aes(x = t, y = y, colour = "y"), linewidth = 0.5, alpha = 0.55) +
      geom_line(data = df_y, aes(x = t, y = q_true, colour = "q_true"), linewidth = 0.8, linetype = 2) +
      geom_line(data = ov, aes(x = t, y = qhat, colour = series), linewidth = 0.9) +
      scale_colour_manual(values = c("y" = "grey50", "q_true" = "black", "offline" = "#1f77b4", "C4" = "#ff7f0e", "online_default" = "#ff7f0e", "C1" = "#2ca02c", "C2" = "#9467bd", "C3" = "#8c564b", "C5" = "#17becf", "C6" = "#d62728")) +
      labs(
        title = "Offline vs Online Quantile Prediction on Evaluation Horizon",
        subtitle = sprintf("Dataset=%s | p0=%.2f | default=%s | best=%s", dataset_slug, p0, default_id, best_id),
        x = "time",
        y = "value",
        colour = "series"
      ) +
      theme_minimal(base_size = 12)

    ggsave(file.path(fig_dir, "offline_vs_online_overlay_eval.png"), p_overlay, width = 11, height = 5.2, dpi = 170)
  }
}

# Rolling check-loss / rolling error
roll_w <- as_int(cs$rolling_window, 40L)
roll_df <- bind_rows(lapply(names(series_map), function(id) {
  s <- series_map[[id]]
  if (is.null(s) || !nrow(s)) return(NULL)
  s %>%
    mutate(
      run_label = id,
      rolling_check = roll_mean(check_loss, roll_w),
      rolling_abs_err = roll_mean(abs_err_qtrue, roll_w)
    )
}))

if (!is.null(roll_df) && nrow(roll_df)) {
  rr <- roll_df %>%
    select(t, run_label, rolling_check, rolling_abs_err) %>%
    pivot_longer(cols = c(rolling_check, rolling_abs_err), names_to = "metric", values_to = "value")

  p_roll <- ggplot(rr, aes(x = t, y = value, colour = run_label)) +
    geom_line(linewidth = 0.9, alpha = 0.9) +
    facet_wrap(~ metric, scales = "free_y", ncol = 1) +
    labs(
      title = sprintf("Rolling Metrics (window=%d)", roll_w),
      subtitle = "Includes offline and online schedules",
      x = "time",
      y = "rolling value",
      colour = "run"
    ) +
    theme_minimal(base_size = 12)

  ggsave(file.path(fig_dir, "rolling_check_loss_error.png"), p_roll, width = 11, height = 7.2, dpi = 170)
}

# Runtime vs performance (Pareto)
pareto_df <- summary_df %>%
  filter(run_label %in% c("offline", names(sched_grid))) %>%
  mutate(
    stable = status == "success" &
      ifelse(is.na(finite_ok), FALSE, finite_ok) &
      ifelse(is.na(spd_ok), FALSE, spd_ok),
    label_txt = run_label
  )

if (nrow(pareto_df)) {
  p_pareto <- ggplot(pareto_df, aes(x = runtime_sec, y = check_loss_mean, colour = stable, shape = mode)) +
    geom_point(size = 3.2, alpha = 0.95) +
    geom_text(aes(label = label_txt), nudge_y = 0.01, size = 3, check_overlap = TRUE) +
    scale_colour_manual(values = c(`TRUE` = "#1b9e77", `FALSE` = "#d95f02")) +
    labs(
      title = "Runtime vs Check-Loss (Pareto View)",
      subtitle = "Lower is better on both axes",
      x = "runtime (seconds)",
      y = "mean pinball/check loss",
      colour = "stable"
    ) +
    theme_minimal(base_size = 12)

  ggsave(file.path(fig_dir, "runtime_vs_performance_pareto.png"), p_pareto, width = 9, height = 5.5, dpi = 170)
}

# Compact heatmap across C1..C6
heat_df <- summary_df %>%
  filter(run_label %in% names(sched_grid), status == "success") %>%
  select(run_label, check_loss_mean, coverage_error, rmse_qtrue, runtime_sec)

if (nrow(heat_df)) {
  to_minmax <- function(x) {
    xr <- range(x, na.rm = TRUE)
    if (!all(is.finite(xr)) || abs(xr[2] - xr[1]) < 1e-12) return(rep(0.5, length(x)))
    (x - xr[1]) / (xr[2] - xr[1])
  }

  hm <- heat_df %>%
    pivot_longer(cols = c(check_loss_mean, coverage_error, rmse_qtrue, runtime_sec), names_to = "metric", values_to = "value") %>%
    group_by(metric) %>%
    mutate(norm_bad = to_minmax(value), score_good = 1 - norm_bad) %>%
    ungroup()

  p_heat <- ggplot(hm, aes(x = metric, y = run_label, fill = score_good)) +
    geom_tile(colour = "white", linewidth = 0.5) +
    geom_text(aes(label = sprintf("%.3f", value)), size = 3.1) +
    scale_fill_gradient2(low = "#b2182b", mid = "#fddbc7", high = "#1a9850", midpoint = 0.5, limits = c(0, 1), name = "higher is better") +
    labs(
      title = "Schedule Comparison Heatmap (C1-C6)",
      subtitle = "Cell text shows raw metric; color shows normalized goodness",
      x = "metric",
      y = "schedule"
    ) +
    theme_minimal(base_size = 12)

  ggsave(file.path(fig_dir, "schedule_grid_heatmap.png"), p_heat, width = 9, height = 5.2, dpi = 170)
}

# -------------------------------
# 10) Markdown report
# -------------------------------

fmt_num <- function(x, d = 4L) ifelse(is.finite(x), format(round(x, d), nsmall = d), "NA")

summary_tbl <- summary_df %>%
  filter(run_label %in% c("offline", "online_default", names(sched_grid))) %>%
  mutate(
    runtime_sec = as.numeric(runtime_sec),
    check_loss_mean = as.numeric(check_loss_mean),
    coverage_error = as.numeric(coverage_error),
    rmse_qtrue = as.numeric(rmse_qtrue)
  ) %>%
  select(run_label, mode, status, runtime_sec, check_loss_mean, coverage_error, rmse_qtrue, finite_ok, spd_ok, n_chol_fail, n_jitter)

md_lines <- c(
  "# ONLINE VB-LD Case Study Smoke + Schedule Tuning",
  "",
  sprintf("Generated: %s", format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")),
  "",
  "## Scope",
  "- Single-quantile case study for online VB-LD scheduling.",
  "- Dataset and optimal DESN spec locked from model-selection evidence.",
  "- Offline behavior preserved; online is evaluated as additional feature.",
  "",
  "## Case-Study Lock (Evidence)",
  sprintf("- Dataset slug: `%s`", dataset_slug),
  sprintf("- Dataset path: `%s`", normalizePath(input_path)),
  sprintf("- Optimal candidate id: `%s`", opt_candidate_id),
  sprintf("- Optimal spec source: `%s`", opt_spec_file),
  sprintf("- Model-selection records: `%s`", records_path),
  sprintf("- Locked architecture: `D=%d, n=%s, m=%d, alpha=%s, rho=%s`",
          D_opt, paste(n_opt, collapse = ","), m_opt,
          paste(alpha_opt, collapse = ","), paste(rho_opt, collapse = ",")),
  sprintf("- Target quantile used for tuning: `p0=%.2f`", p0),
  "",
  "## Commands Used",
  "```bash",
  sprintf("Rscript scripts/online_vbld_case_study_smoke_tuning.R --config %s --out_root %s", cfg_path, out_root),
  "```",
  "",
  "## Smoke Checks (Pipeline Mode Toggle)",
  "",
  "| smoke_label | vb.online.enabled | status | runtime_sec | notes |",
  "|---|---:|---|---:|---|"
)

for (i in seq_len(nrow(smoke_df))) {
  r <- smoke_df[i, ]
  md_lines <- c(md_lines, sprintf("| %s | %s | %s | %.2f | %s |",
                                  r$smoke_label,
                                  as.character(isTRUE(r$vb_online_enabled)),
                                  r$status,
                                  as_num(r$runtime_sec, NA_real_),
                                  r$notes))
}

md_lines <- c(md_lines,
  "",
  "## Schedule Results",
  "",
  "| run | mode | status | runtime_sec | check_loss | coverage_error | rmse_qtrue | finite_ok | spd_ok | chol_fail | jitter |",
  "|---|---|---|---:|---:|---:|---:|---|---|---:|---:|"
)

for (i in seq_len(nrow(summary_tbl))) {
  r <- summary_tbl[i, ]
  md_lines <- c(md_lines, sprintf(
    "| %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s |",
    r$run_label,
    r$mode,
    r$status,
    fmt_num(r$runtime_sec, 2),
    fmt_num(r$check_loss_mean, 4),
    fmt_num(r$coverage_error, 4),
    fmt_num(r$rmse_qtrue, 4),
    as.character(isTRUE(r$finite_ok)),
    as.character(isTRUE(r$spd_ok)),
    fmt_num(r$n_chol_fail, 0),
    fmt_num(r$n_jitter, 0)
  ))
}

md_lines <- c(md_lines,
  "",
  "## Recommendation",
  sprintf("- Recommended `vb.online.enabled`: `%s`", tolower(as.character(!is.na(rec_id) && rec_id != "offline"))),
  sprintf("- Recommended default schedule: `%s`", ifelse(is.na(rec_id), "NA", rec_id)),
  sprintf("- Safer fallback schedule: `%s`", ifelse(is.na(fallback_id), "NA", fallback_id)),
  sprintf("- Best online candidate before acceptance gate: `%s`", ifelse(is.na(rec_schedule_id), "NA", rec_schedule_id)),
  sprintf("- Acceptance gate enabled: `%s`", tolower(as.character(isTRUE(gate_enabled)))),
  sprintf("- Acceptance gate triggered: `%s`", tolower(as.character(isTRUE(gate_triggered)))),
  sprintf("- Gate thresholds: `delta_check <= %.6f`, `delta_coverage_error <= %.6f`",
          gate_max_check_increase, gate_max_cov_err_increase),
  sprintf("- Jitter stability cap used in selection: `max_jitter_eps <= %.3e`", jitter_stability_cap),
  sprintf("- Gate reason: `%s`", ifelse(is.na(gate_reason), "NA", gate_reason)),
  "",
  "Decision rule:",
  "- Primary: best predictive check-loss (with RMSE to true quantile as secondary when available).",
  "- Constraints: successful run, finite/SPD health, acceptable coverage error, jitter sanity, and runtime sanity.",
  "- Acceptance gate: keep `vb.online.enabled=false` when the recommended online candidate is worse than offline on both check-loss and coverage-error thresholds.",
  "",
  "## Artifacts",
  sprintf("- Run directory: `%s`", normalizePath(run_dir)),
  sprintf("- Summary table: `%s`", file.path(run_dir, "tables", "run_summary.csv")),
  sprintf("- Smoke table: `%s`", file.path(run_dir, "tables", "smoke_summary.csv")),
  sprintf("- Config diffs: `%s`", file.path(run_dir, "tables", "config_diffs.csv")),
  sprintf("- Overlay plot: `%s`", file.path(run_dir, "figs", "offline_vs_online_overlay_eval.png")),
  sprintf("- Rolling plot: `%s`", file.path(run_dir, "figs", "rolling_check_loss_error.png")),
  sprintf("- Pareto plot: `%s`", file.path(run_dir, "figs", "runtime_vs_performance_pareto.png")),
  sprintf("- Heatmap: `%s`", file.path(run_dir, "figs", "schedule_grid_heatmap.png")),
  sprintf("- Drift summary table: `%s`", file.path(run_dir, "tables", "diagnostic_drift_summary.csv")),
  sprintf("- Online trace tables (if enabled): `%s`", file.path(run_dir, "tables", "trace_<run>.csv")),
  "",
  "## Assumptions",
  "- Single quantile (`p0=0.50`) was used for schedule tuning.",
  "- The model-selection optimal candidate id was reconstructed from stage-1 candidate grid and matched exactly.",
  "- Ground-truth quantile was extracted from the simulation long file at nearest available `p` per time (exact `p=0.50` present)."
)

report_path <- file.path(repo_root, "docs", "ONLINE_VBLD_CASE_STUDY_SMOKE_TUNING.md")
writeLines(md_lines, report_path)

# Run manifest
manifest <- list(
  timestamp = format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"),
  repo_root = repo_root,
  cfg_path = cfg_path,
  out_root = out_root,
  run_dir = normalizePath(run_dir),
  dataset_slug = dataset_slug,
  input_path = normalizePath(input_path),
  p0 = p0,
  split = list(T_use = T_use, n_train = n_train, n_eval = length(idx_eval)),
  recommendation = list(
    default = rec_id,
    fallback = fallback_id,
    recommended_vb_online_enabled = (!is.na(rec_id) && rec_id != "offline"),
    best_online_candidate = rec_schedule_id,
    gate = list(
      enabled = gate_enabled,
      triggered = gate_triggered,
      max_check_loss_increase = gate_max_check_increase,
      max_coverage_error_increase = gate_max_cov_err_increase,
      reason = gate_reason
    )
  )
)
jsonlite::write_json(manifest, file.path(man_dir, "manifest.json"), pretty = TRUE, auto_unbox = TRUE)

log_msg("Done. Report written: %s", report_path)
log_msg("Run artifacts: %s", normalizePath(run_dir))

cat(sprintf("\nReport: %s\n", report_path))
cat(sprintf("Run dir: %s\n", normalizePath(run_dir)))

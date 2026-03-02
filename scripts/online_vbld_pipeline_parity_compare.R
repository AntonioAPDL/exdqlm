#!/usr/bin/env Rscript

options(stringsAsFactors = FALSE)

`%||%` <- function(x, y) if (!is.null(x)) x else y

args <- commandArgs(trailingOnly = TRUE)
get_arg <- function(flag, default = NULL) {
  i <- which(args == flag)
  if (length(i) && i < length(args)) args[i + 1L] else default
}
has_flag <- function(flag) any(args == flag)

dataset_slug <- get_arg("--dataset_slug", "dlm_constV_smallW")
defaults_path <- get_arg("--defaults", "config/defaults.yaml")
datasets_path <- get_arg("--datasets", "config/datasets.yaml")
out_root <- get_arg("--out_root", "results/online_vbld/pipeline_parity")
stamp_in <- get_arg("--stamp", "")
dry_run <- has_flag("--dry-run")

need <- c("yaml", "jsonlite", "readr", "dplyr", "tibble", "tidyr", "pkgload")
for (p in need) {
  if (!requireNamespace(p, quietly = TRUE)) {
    install.packages(p, repos = "https://cloud.r-project.org")
  }
}

suppressPackageStartupMessages({
  library(yaml)
  library(jsonlite)
  library(readr)
  library(dplyr)
  library(tibble)
  library(tidyr)
})

args_all <- commandArgs(trailingOnly = FALSE)
script_arg <- grep("^--file=", args_all, value = TRUE)
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

pinball_vec <- function(y, qhat, p0) {
  e <- y - qhat
  (p0 - (e < 0)) * e
}

pad_numeric <- function(x, n) {
  out <- rep(NA_real_, n)
  x <- as.numeric(x %||% numeric(0))
  if (length(x)) {
    m <- min(length(x), n)
    out[seq_len(m)] <- x[seq_len(m)]
  }
  out
}

load_yaml <- function(path) {
  if (!file.exists(path)) stop("Missing YAML: ", path, call. = FALSE)
  yaml::read_yaml(path)
}

defaults_cfg <- load_yaml(defaults_path)
datasets_obj <- load_yaml(datasets_path)
datasets <- datasets_obj$datasets
if (is.null(datasets) || !length(datasets)) {
  stop("No datasets found in ", datasets_path, call. = FALSE)
}

ds <- NULL
for (d in datasets) {
  if (identical(d$slug, dataset_slug)) {
    ds <- d
    break
  }
}
if (is.null(ds)) stop("Dataset slug not found: ", dataset_slug, call. = FALSE)
if (!file.exists(ds$input_path)) stop("Dataset file missing: ", ds$input_path, call. = FALSE)

mode_key <- tolower(ds$mode %||% defaults_cfg$pipeline$mode %||% "sim")
cfg_base <- defaults_cfg
if (!is.null(cfg_base$mode_overrides) && !is.null(cfg_base$mode_overrides[[mode_key]])) {
  cfg_base <- deep_merge(cfg_base, cfg_base$mode_overrides[[mode_key]])
}

# Parity config: keep the same offline pipeline path and restrict to one quantile.
cfg_base$pipeline$mode <- "sim"
cfg_base$p_vec <- c(0.5)

# Keep diagnostics/traces, skip expensive extras not needed for this parity check.
cfg_base$diagnostics$fan_charts <- FALSE
cfg_base$diagnostics$pit <- FALSE
cfg_base$diagnostics$calibration <- FALSE
cfg_base$diagnostics$lead_eval <- FALSE
cfg_base$diagnostics$scores <- TRUE
cfg_base$forecast$horizon <- as_int(cfg_base$forecast$horizon, 1L)
cfg_base$forecast$mode <- "origin"
cfg_base$outputs$save <- TRUE
cfg_base$outputs$keep_draws <- FALSE
cfg_base$outputs$thesis_subset <- FALSE

if (is.null(cfg_base$vb$online)) cfg_base$vb$online <- list()
cfg_base$vb$online$keep_trace <- TRUE

stamp <- if (nzchar(stamp_in)) stamp_in else format(Sys.time(), "%Y%m%d-%H%M%S")
run_dir <- file.path(out_root, dataset_slug, "runs", paste0("pipeline_parity__", stamp))
tab_dir <- file.path(run_dir, "tables")
fig_dir <- file.path(run_dir, "figs")
log_dir <- file.path(run_dir, "logs")
man_dir <- file.path(run_dir, "manifest")
pipe_dir <- file.path(run_dir, "pipeline_runs")
for (d in c(tab_dir, fig_dir, log_dir, man_dir, pipe_dir)) {
  dir.create(d, recursive = TRUE, showWarnings = FALSE)
}

log_file <- file.path(log_dir, "run.log")
log_msg <- function(fmt, ...) {
  msg <- sprintf("[%s] %s", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), sprintf(fmt, ...))
  cat(msg, "\n")
  cat(msg, "\n", file = log_file, append = TRUE)
}

writeLines(
  c(
    sprintf("command: Rscript scripts/online_vbld_pipeline_parity_compare.R --dataset_slug %s --defaults %s --datasets %s --out_root %s%s",
            dataset_slug, defaults_path, datasets_path, out_root, if (dry_run) " --dry-run" else ""),
    sprintf("repo_root: %s", repo_root),
    sprintf("dataset_slug: %s", dataset_slug),
    sprintf("dataset_input: %s", normalizePath(ds$input_path)),
    sprintf("run_dir: %s", run_dir)
  ),
  file.path(man_dir, "command.txt")
)

save_cfg <- function(cfg, path) {
  txt <- jsonlite::toJSON(cfg, auto_unbox = TRUE, digits = NA, null = "null", pretty = TRUE)
  writeLines(txt, path)
}

extract_fit_bundle <- function(run_label, run_path, p0 = 0.5) {
  fobj_path <- file.path(run_path, "models", "forecast_objects.rds")
  if (!file.exists(fobj_path)) {
    stop(sprintf("[%s] missing forecast object: %s", run_label, fobj_path), call. = FALSE)
  }
  obj <- readRDS(fobj_path)
  fits_fc <- obj$fits_fc %||% list()
  if (!length(fits_fc)) {
    stop(sprintf("[%s] forecast_objects has empty fits_fc.", run_label), call. = FALSE)
  }

  # single-quantile run by construction
  ff <- fits_fc[[1L]]
  fit <- ff$fit_train$fit %||% NULL
  if (is.null(fit)) stop(sprintf("[%s] fit object missing in forecast_objects.", run_label), call. = FALSE)
  pred_fc <- ff$df_pred_fc %||% NULL
  if (is.null(pred_fc) || !nrow(pred_fc)) stop(sprintf("[%s] df_pred_fc missing/empty.", run_label), call. = FALSE)

  pred_fc <- as_tibble(pred_fc)
  if (!("q_pred" %in% names(pred_fc))) {
    stop(sprintf("[%s] df_pred_fc missing q_pred.", run_label), call. = FALSE)
  }
  if (!("q_true" %in% names(pred_fc))) pred_fc$q_true <- NA_real_
  if (!("y" %in% names(pred_fc))) pred_fc$y <- NA_real_
  if (!("h" %in% names(pred_fc))) pred_fc$h <- seq_len(nrow(pred_fc))

  series <- pred_fc %>%
    transmute(
      run_label = run_label,
      t = as.integer(h),
      y = as.numeric(y),
      q_true = as.numeric(q_true),
      qhat = as.numeric(q_pred),
      check_loss = as.numeric(pinball_vec(y, q_pred, p0)),
      abs_err_qtrue = ifelse(is.finite(q_true), abs(q_pred - q_true), NA_real_)
    )

  # Batch traces from fit$misc
  misc <- fit$misc %||% list()
  elbo <- as.numeric(misc$elbo_trace %||% misc$elbo %||% numeric(0))
  gamma <- as.numeric(misc$gamma_trace %||% numeric(0))
  sigma <- as.numeric(misc$sigma_trace %||% numeric(0))
  new_term <- as.numeric(misc$new_term_trace %||% numeric(0))
  rhs_tau <- as.numeric(misc$rhs_tau_trace %||% numeric(0))
  rhs_c2 <- as.numeric(misc$rhs_c2_trace %||% numeric(0))
  rhs_lam_mean <- as.numeric(misc$rhs_lambda_mean_trace %||% numeric(0))
  rhs_lam_min <- as.numeric(misc$rhs_lambda_min_trace %||% numeric(0))
  rhs_lam_max <- as.numeric(misc$rhs_lambda_max_trace %||% numeric(0))

  n_batch <- max(length(elbo), length(gamma), length(sigma), length(new_term),
                 length(rhs_tau), length(rhs_c2), length(rhs_lam_mean), length(rhs_lam_min), length(rhs_lam_max))

  batch_trace <- if (n_batch > 0L) {
    tibble(
      run_label = run_label,
      mode = if (isTRUE(misc$online$enabled %||% FALSE)) "online" else "offline",
      trace_phase = "batch_iter",
      trace_segment = if (isTRUE(misc$online$enabled %||% FALSE)) "warm_start_batch" else "offline_batch",
      iter = as.integer(seq_len(n_batch)),
      t = NA_integer_,
      step = as.integer(seq_len(n_batch)),
      elbo = pad_numeric(elbo, n_batch),
      gamma = pad_numeric(gamma, n_batch),
      sigma = pad_numeric(sigma, n_batch),
      new_term = pad_numeric(new_term, n_batch),
      tau = pad_numeric(rhs_tau, n_batch),
      c2 = pad_numeric(rhs_c2, n_batch),
      lambda_mean = pad_numeric(rhs_lam_mean, n_batch),
      lambda_min = pad_numeric(rhs_lam_min, n_batch),
      lambda_max = pad_numeric(rhs_lam_max, n_batch),
      check_loss_pre = NA_real_,
      covered_pre = NA_real_,
      barw = NA_real_,
      barm = NA_real_,
      jitter_eps = NA_real_,
      rhs_refreshed = NA_integer_,
      sigmagam_refreshed = NA_integer_,
      sigmagam_logpost = NA_real_
    )
  } else {
    tibble()
  }

  on_trace <- misc$online$trace %||% NULL
  online_trace <- tibble()
  if (is.data.frame(on_trace) && nrow(on_trace)) {
    n_on <- nrow(on_trace)
    online_trace <- tibble(
      run_label = run_label,
      mode = "online",
      trace_phase = "online_step",
      trace_segment = "streaming",
      iter = NA_integer_,
      t = as.integer(on_trace$t %||% seq_len(n_on)),
      step = as.integer(seq_len(n_on)),
      elbo = NA_real_,
      gamma = pad_numeric(on_trace$gamma_post %||% numeric(0), n_on),
      sigma = pad_numeric(on_trace$sigma_post %||% numeric(0), n_on),
      new_term = NA_real_,
      tau = NA_real_,
      c2 = NA_real_,
      lambda_mean = NA_real_,
      lambda_min = NA_real_,
      lambda_max = NA_real_,
      check_loss_pre = pad_numeric(on_trace$check_loss_pre %||% numeric(0), n_on),
      covered_pre = pad_numeric(on_trace$covered_pre %||% numeric(0), n_on),
      barw = pad_numeric(on_trace$barw %||% numeric(0), n_on),
      barm = pad_numeric(on_trace$barm %||% numeric(0), n_on),
      jitter_eps = pad_numeric(on_trace$jitter_eps %||% numeric(0), n_on),
      rhs_refreshed = as.integer(on_trace$rhs_refreshed %||% rep(NA_integer_, n_on)),
      sigmagam_refreshed = as.integer(on_trace$sigmagam_refreshed %||% rep(NA_integer_, n_on)),
      sigmagam_logpost = pad_numeric(on_trace$sigmagam_logpost_post %||% numeric(0), n_on)
    )
  }

  # Health summary
  V <- as.matrix(fit$qbeta$V)
  V <- 0.5 * (V + t(V))
  eg <- suppressWarnings(eigen(V, symmetric = TRUE, only.values = TRUE)$values)
  min_eig <- suppressWarnings(min(eg))
  online_health <- misc$online$health %||% list()

  metrics <- list(
    check_loss_mean = mean(series$check_loss, na.rm = TRUE),
    coverage = mean(series$y <= series$qhat, na.rm = TRUE),
    coverage_error = abs(mean(series$y <= series$qhat, na.rm = TRUE) - p0),
    mae_qtrue = if (all(is.finite(series$q_true))) mean(abs(series$qhat - series$q_true), na.rm = TRUE) else NA_real_,
    rmse_qtrue = if (all(is.finite(series$q_true))) sqrt(mean((series$qhat - series$q_true)^2, na.rm = TRUE)) else NA_real_,
    finite_ok = all(is.finite(fit$qbeta$m)) && all(is.finite(V)) &&
      all(is.finite(c(fit$qsiggam$eta_hat, fit$qsiggam$ell_hat, fit$qsiggam$gamma_mean, fit$qsiggam$sigma_mean))),
    spd_ok = is.finite(min_eig) && (min_eig > 0),
    n_chol_fail = as_num(online_health$n_chol_fail, NA_real_),
    n_jitter = as_num(online_health$n_jitter, NA_real_),
    max_jitter_eps = as_num(online_health$max_jitter_eps, NA_real_),
    last_jitter_eps = as_num(online_health$last_jitter_eps, NA_real_),
    rhs_refreshes = as_num(online_health$rhs_refreshes, NA_real_),
    sigmagam_refreshes = as_num(online_health$sigmagam_refreshes, NA_real_),
    window_backfits = as_num(online_health$window_backfits, NA_real_)
  )

  list(
    fit = fit,
    series = series,
    traces = bind_rows(batch_trace, online_trace),
    metrics = metrics
  )
}

run_pipeline <- function(label, cfg, input_path, out_dir, log_path) {
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
  env_new <- c(
    EXDQLM_FILE_LONG = normalizePath(input_path),
    EXDQLM_OUT_DIR = normalizePath(out_dir, mustWork = FALSE),
    EXDQLM_SAVE_OUTPUTS = "1",
    EXDQLM_CFG_JSON = as.character(
      jsonlite::toJSON(cfg, auto_unbox = TRUE, null = "null", digits = NA)
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

  do.call(Sys.setenv, as.list(env_new))
  on.exit(restore_env(), add = TRUE)

  t0 <- proc.time()[3]
  if (isTRUE(dry_run)) {
    writeLines(c(
      sprintf("[dry-run] would run pipeline_sim_main.R for %s", label),
      sprintf("out_dir=%s", out_dir)
    ), log_path)
    return(list(status = 0L, runtime_sec = 0))
  }
  status <- system2("Rscript", args = c("scripts/pipeline_sim_main.R"), stdout = log_path, stderr = log_path)
  runtime <- as.numeric(proc.time()[3] - t0)
  list(status = as.integer(status), runtime_sec = runtime)
}

offline_cfg <- cfg_base
offline_cfg$vb$online$enabled <- FALSE
online_cfg <- cfg_base
online_cfg$vb$online$enabled <- TRUE

save_cfg(offline_cfg, file.path(man_dir, "cfg_offline.json"))
save_cfg(online_cfg, file.path(man_dir, "cfg_online.json"))

if (isTRUE(dry_run)) {
  log_msg("Dry-run mode: configs/materialization ready; no pipeline execution performed.")
  log_msg("Run dir: %s", normalizePath(run_dir))
  cat(sprintf("run_dir=%s\n", normalizePath(run_dir)))
  quit(save = "no", status = 0)
}

offline_dir <- file.path(pipe_dir, "offline")
online_dir <- file.path(pipe_dir, "online")
offline_log <- file.path(log_dir, "pipeline_offline.log")
online_log <- file.path(log_dir, "pipeline_online.log")

log_msg("Dataset: %s", dataset_slug)
log_msg("Input: %s", normalizePath(ds$input_path))
log_msg("Running OFFLINE pipeline parity run...")
res_off <- run_pipeline("offline", offline_cfg, ds$input_path, offline_dir, offline_log)
if (!identical(res_off$status, 0L)) {
  stop(sprintf("Offline pipeline failed with status=%d. See %s", res_off$status, offline_log), call. = FALSE)
}
log_msg("Offline completed in %.2fs", res_off$runtime_sec)

log_msg("Running ONLINE pipeline parity run...")
res_on <- run_pipeline("online", online_cfg, ds$input_path, online_dir, online_log)
if (!identical(res_on$status, 0L)) {
  stop(sprintf("Online pipeline failed with status=%d. See %s", res_on$status, online_log), call. = FALSE)
}
log_msg("Online completed in %.2fs", res_on$runtime_sec)

p0 <- as_num(cfg_base$p_vec, 0.5)
bundle_off <- extract_fit_bundle("offline", offline_dir, p0 = p0)
bundle_on <- extract_fit_bundle("online_default", online_dir, p0 = p0)

summary_df <- bind_rows(
  tibble(
    run_label = "offline",
    mode = "offline",
    status = "success",
    error = NA_character_,
    runtime_sec = res_off$runtime_sec,
    M = NA_integer_,
    K = NA_integer_,
    W = NA_integer_,
    L_loc = NA_integer_,
    check_loss_mean = bundle_off$metrics$check_loss_mean,
    coverage = bundle_off$metrics$coverage,
    coverage_error = bundle_off$metrics$coverage_error,
    mae_qtrue = bundle_off$metrics$mae_qtrue,
    rmse_qtrue = bundle_off$metrics$rmse_qtrue,
    finite_ok = bundle_off$metrics$finite_ok,
    spd_ok = bundle_off$metrics$spd_ok,
    n_chol_fail = bundle_off$metrics$n_chol_fail,
    n_jitter = bundle_off$metrics$n_jitter,
    max_jitter_eps = bundle_off$metrics$max_jitter_eps,
    last_jitter_eps = bundle_off$metrics$last_jitter_eps,
    rhs_refreshes = bundle_off$metrics$rhs_refreshes,
    sigmagam_refreshes = bundle_off$metrics$sigmagam_refreshes,
    window_backfits = bundle_off$metrics$window_backfits
  ),
  tibble(
    run_label = "online_default",
    mode = "online",
    status = "success",
    error = NA_character_,
    runtime_sec = res_on$runtime_sec,
    M = as_int(online_cfg$vb$online$M, 10L),
    K = as_int(online_cfg$vb$online$K, 40L),
    W = as_int(online_cfg$vb$online$W, 100L),
    L_loc = as_int(online_cfg$vb$online$L_loc, 2L),
    check_loss_mean = bundle_on$metrics$check_loss_mean,
    coverage = bundle_on$metrics$coverage,
    coverage_error = bundle_on$metrics$coverage_error,
    mae_qtrue = bundle_on$metrics$mae_qtrue,
    rmse_qtrue = bundle_on$metrics$rmse_qtrue,
    finite_ok = bundle_on$metrics$finite_ok,
    spd_ok = bundle_on$metrics$spd_ok,
    n_chol_fail = bundle_on$metrics$n_chol_fail,
    n_jitter = bundle_on$metrics$n_jitter,
    max_jitter_eps = bundle_on$metrics$max_jitter_eps,
    last_jitter_eps = bundle_on$metrics$last_jitter_eps,
    rhs_refreshes = bundle_on$metrics$rhs_refreshes,
    sigmagam_refreshes = bundle_on$metrics$sigmagam_refreshes,
    window_backfits = bundle_on$metrics$window_backfits
  )
)

off_row <- summary_df %>% filter(run_label == "offline") %>% slice(1)
summary_df <- summary_df %>%
  mutate(
    delta_check_vs_offline = check_loss_mean - off_row$check_loss_mean,
    delta_rmse_qtrue_vs_offline = rmse_qtrue - off_row$rmse_qtrue
  )

readr::write_csv(summary_df, file.path(tab_dir, "run_summary.csv"))
readr::write_csv(summary_df, file.path(tab_dir, "run_summary_pretty.csv"))
readr::write_csv(bundle_off$series, file.path(tab_dir, "series_offline.csv"))
readr::write_csv(bundle_on$series %>% mutate(run_label = "online_default"), file.path(tab_dir, "series_online_default.csv"))
readr::write_csv(
  tibble(
    run_label = "online_default",
    M = as_int(online_cfg$vb$online$M, 10L),
    K = as_int(online_cfg$vb$online$K, 40L),
    W = as_int(online_cfg$vb$online$W, 100L),
    L_loc = as_int(online_cfg$vb$online$L_loc, 2L)
  ),
  file.path(tab_dir, "config_diffs.csv")
)

param_all <- bind_rows(bundle_off$traces, bundle_on$traces)
if (nrow(param_all)) {
  readr::write_csv(param_all, file.path(tab_dir, "param_trace_all.csv"))
  readr::write_csv(param_all %>% filter(run_label == "offline"), file.path(tab_dir, "param_trace_offline.csv"))
  readr::write_csv(param_all %>% filter(run_label == "online_default"), file.path(tab_dir, "param_trace_online_default.csv"))
}

trace_on <- bundle_on$traces %>% filter(trace_phase == "online_step")
if (nrow(trace_on)) {
  readr::write_csv(trace_on, file.path(tab_dir, "trace_online_default.csv"))
}

recommendation <- tibble(
  recommended_default = "online_default",
  safer_fallback = "offline",
  recommended_online_candidate = "online_default",
  gate_enabled = FALSE,
  gate_triggered = FALSE,
  gate_reason = NA_character_,
  recommended_vb_online_enabled = TRUE
)
readr::write_csv(recommendation, file.path(tab_dir, "recommendation.csv"))

diag_status <- system2(
  "Rscript",
  args = c("scripts/online_vbld_make_diagnostics_pack.R", run_dir),
  stdout = file.path(log_dir, "diagnostics_pack.log"),
  stderr = file.path(log_dir, "diagnostics_pack.log")
)
if (!identical(as.integer(diag_status), 0L)) {
  warning("Diagnostics pack script returned non-zero status. See logs/diagnostics_pack.log", call. = FALSE)
}

manifest <- list(
  timestamp_utc = format(Sys.time(), "%Y-%m-%d %H:%M:%S UTC", tz = "UTC"),
  dataset_slug = dataset_slug,
  dataset_input = normalizePath(ds$input_path),
  run_dir = normalizePath(run_dir),
  pipeline_runs = list(offline = normalizePath(offline_dir), online = normalizePath(online_dir)),
  p_vec = as.numeric(cfg_base$p_vec),
  parity_settings = list(
    same_pipeline_path = TRUE,
    disabled_extras = list(
      fan_charts = TRUE,
      pit = TRUE,
      calibration = TRUE,
      lead_eval = TRUE
    )
  )
)
jsonlite::write_json(manifest, file.path(man_dir, "manifest.json"), pretty = TRUE, auto_unbox = TRUE)

log_msg("Completed parity comparison run.")
log_msg("Run dir: %s", normalizePath(run_dir))
cat(sprintf("run_dir=%s\n", normalizePath(run_dir)))

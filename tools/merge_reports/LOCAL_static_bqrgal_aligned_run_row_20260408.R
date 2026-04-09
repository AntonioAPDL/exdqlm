#!/usr/bin/env Rscript

options(stringsAsFactors = FALSE)

`%||%` <- function(x, y) if (is.null(x) || !length(x)) y else x

parse_args_static_bqrgal <- function(args) {
  out <- list()
  for (x in args) {
    if (grepl("^--[^=]+=.*$", x)) {
      key <- sub("^--([^=]+)=.*$", "\\1", x)
      val <- sub("^--[^=]+=(.*)$", "\\1", x)
      out[[key]] <- val
    } else if (grepl("^--", x)) {
      key <- sub("^--", "", x)
      out[[key]] <- "TRUE"
    }
  }
  out
}

args <- parse_args_static_bqrgal(commandArgs(trailingOnly = TRUE))
repo_root <- normalizePath(".", winslash = "/", mustWork = TRUE)
setwd(repo_root)

source("tools/merge_reports/LOCAL_static_bqrgal_aligned_helpers_20260408.R")
source("tools/merge_reports/LOCAL_validation_health_gate_common_20260321.R")

manifest_path <- safe_chr_static_bqrgal(args$manifest, NA_character_)
row_id <- safe_int_static_bqrgal(args$row_id, NA_integer_)
tag <- safe_chr_static_bqrgal(args$tag, static_bqrgal_aligned_tag_20260408())
force <- as_flag_static_bqrgal(args$force, FALSE)

if (is.na(manifest_path) || !file.exists(manifest_path)) stop("manifest is required and must exist")
if (!is.finite(row_id)) stop("row_id is required")

manifest <- utils::read.csv(manifest_path, stringsAsFactors = FALSE)
row <- manifest[manifest$row_id == row_id, , drop = FALSE]
if (!nrow(row)) stop(sprintf("row_id %d not found in manifest", row_id))
if (nrow(row) > 1L) stop(sprintf("row_id %d appears multiple times in manifest", row_id))

cfg <- readRDS(row$config_path[1])
paths <- static_bqrgal_aligned_paths_20260408()

start_ts <- as.character(Sys.time())
status <- "pending"
error_msg <- NA_character_

ensure_dir_static_bqrgal(dirname(cfg$fit_path))
ensure_dir_static_bqrgal(dirname(cfg$row_status_path))
ensure_dir_static_bqrgal(dirname(cfg$health_path))
ensure_dir_static_bqrgal(dirname(cfg$metrics_path))

write_failure_row <- function(reason) {
  out <- data.frame(
    row_id = row_id,
    ts_start = start_ts,
    ts_end = as.character(Sys.time()),
    status = "failed_runtime",
    error = reason,
    gate_overall = "FAIL",
    healthy = FALSE,
    runtime_sec = NA_real_,
    phase = cfg$phase,
    lane_label = cfg$lane_label,
    family = cfg$family,
    tau_label = cfg$tau_label,
    n_train = cfg$n_train,
    rep_id = cfg$rep_id,
    model = cfg$model,
    fit_path = cfg$fit_path,
    health_csv = cfg$health_path,
    metrics_csv = cfg$metrics_path,
    stringsAsFactors = FALSE
  )
  utils::write.csv(out, cfg$row_status_path, row.names = FALSE)
}

if (isTRUE(row$missing_inputs[1])) {
  write_failure_row("missing_inputs flag is TRUE in manifest")
  quit(save = "no", status = 0)
}

bootstrap_static_bqrgal_lib_20260408(paths)
activate_static_bqrgal_lib_20260408(paths)
source(cfg$bqrgal_run_wrapper)
if (!exists("run_gal_mcmc", mode = "function", inherits = TRUE)) {
  stop(sprintf("run_gal_mcmc is not available after sourcing %s", cfg$bqrgal_run_wrapper))
}

dataset <- readRDS(cfg$data_path)
tau_idx <- match(cfg$tau, dataset$true_params$p0_vals)
if (is.na(tau_idx)) stop(sprintf("tau %s not found in dataset", cfg$tau))

XX_train <- dataset$train_covar_list[[tau_idx]][[cfg$rep_id]]
yy_train <- dataset$train_data[[cfg$family]][[tau_idx]][[cfg$rep_id]]
XX_test <- dataset$test_covar_list[[tau_idx]][[cfg$rep_id]]
yy_test <- dataset$test_data[[cfg$family]][[tau_idx]][[cfg$rep_id]]

make_starting_values <- function(model, n_obs, p_dim) {
  base <- list(
    be0 = 0,
    sigma = 1,
    vv = stats::rexp(n_obs),
    omega = rep(1, p_dim)
  )
  if (identical(model, "exal")) {
    base$ss <- truncnorm::rtruncnorm(n_obs, a = 0, b = Inf, mean = 0, sd = 1)
  }
  base
}

case_id <- sprintf(
  "%s::%s::%s::n%d::rep%03d::%s",
  cfg$lane_label, cfg$family, cfg$tau_label, cfg$n_train, cfg$rep_id, cfg$model
)

health_row <- NULL
metrics_row <- NULL
runtime_sec <- NA_real_

tryCatch({
  if (file.exists(cfg$fit_path) && !force) {
    wrapped <- readRDS(cfg$fit_path)
    fit_obj <- wrapped$fit %||% wrapped
    runtime_sec <- safe_num_static_bqrgal(wrapped$meta$runtime_sec %||% fit_obj$runtime[["elapsed"]] %||% fit_obj$runtime[3], NA_real_)
    status <- "skipped_existing"
  } else {
    set.seed(cfg$fit_seed)
    starting <- make_starting_values(cfg$model, nrow(XX_train), ncol(XX_train))

    runtime_obj <- system.time({
      fit_obj <- if (identical(cfg$model, "al")) {
        bal(
          resp = yy_train,
          covars = XX_train,
          prob = cfg$tau,
          beta_prior = cfg$beta_prior_keyword,
          priors = cfg$priors,
          starting = starting,
          mcmc_settings = cfg$mcmc_settings,
          verbose = FALSE
        )
      } else {
        run_gal_mcmc(
          yy = yy_train,
          XX = XX_train,
          p0 = cfg$tau,
          beta_prior = cfg$beta_prior_keyword,
          priors = cfg$priors,
          starting = starting,
          tuning = cfg$tuning,
          mcmc_settings = cfg$mcmc_settings,
          ga_sampler = cfg$gamma_kernel,
          verbose = FALSE
        )
      }
    })
    runtime_sec <- as.numeric(runtime_obj[["elapsed"]])

    compact_fit <- compact_bqrgal_fit_20260408(fit_obj, cfg$model)
    wrapped <- list(
      fit = compact_fit,
      meta = list(
        runtime_sec = runtime_sec,
        seed = cfg$fit_seed,
        engine = cfg$engine,
        tag = tag
      )
    )
    saveRDS(wrapped, cfg$fit_path)
    status <- "done"
  }

  fit_for_metrics <- fit_obj %||% wrapped$fit
  metrics_row <- compute_bqrgal_metrics_20260408(
    fit = fit_for_metrics,
    model = cfg$model,
    XX_train = XX_train,
    yy_train = yy_train,
    XX_test = XX_test,
    yy_test = yy_test,
    beta_truth = cfg$true_params$beta_truth,
    true_ind = cfg$true_params$true_ind
  )
  metrics_row <- cbind(
    data.frame(
      row_id = row_id,
      case_id = case_id,
      phase = cfg$phase,
      lane_label = cfg$lane_label,
      family = cfg$family,
      tau = cfg$tau,
      tau_label = cfg$tau_label,
      n_train = cfg$n_train,
      rep_id = cfg$rep_id,
      model = cfg$model,
      engine = cfg$engine,
      runtime_sec = runtime_sec,
      fit_path = cfg$fit_path,
      stringsAsFactors = FALSE
    ),
    metrics_row,
    stringsAsFactors = FALSE
  )

  health_metrics <- collect_bqrgal_health_metrics_20260408(
    fit = fit_for_metrics,
    case_id = case_id,
    variant = tag,
    candidate_path = cfg$fit_path,
    model = cfg$model,
    runtime_sec = runtime_sec
  )
  health_row <- vhg_apply_health_gates(health_metrics)

  utils::write.csv(metrics_row, cfg$metrics_path, row.names = FALSE)
  utils::write.csv(health_row, cfg$health_path, row.names = FALSE)
}, error = function(e) {
  status <<- "failed_runtime"
  error_msg <<- conditionMessage(e)
})

if (!is.null(error_msg) && (is.null(health_row) || !nrow(health_row))) {
  health_row <- data.frame(
    gate_overall = "FAIL",
    healthy = FALSE,
    run_time_sec = runtime_sec,
    stringsAsFactors = FALSE
  )
}

row_out <- data.frame(
  row_id = row_id,
  ts_start = start_ts,
  ts_end = as.character(Sys.time()),
  status = status,
  error = error_msg,
  gate_overall = safe_chr_static_bqrgal(health_row$gate_overall[1], "FAIL"),
  healthy = isTRUE(health_row$healthy[1]),
  runtime_sec = runtime_sec,
  phase = cfg$phase,
  lane_label = cfg$lane_label,
  family = cfg$family,
  tau_label = cfg$tau_label,
  n_train = cfg$n_train,
  rep_id = cfg$rep_id,
  model = cfg$model,
  fit_path = cfg$fit_path,
  health_csv = cfg$health_path,
  metrics_csv = cfg$metrics_path,
  stringsAsFactors = FALSE
)

utils::write.csv(row_out, cfg$row_status_path, row.names = FALSE)
cat(sprintf(
  "[row %d] status=%s gate=%s healthy=%s lane=%s family=%s tau=%s n=%d rep=%03d model=%s\n",
  row_id,
  status,
  row_out$gate_overall[1],
  row_out$healthy[1],
  cfg$lane_label,
  cfg$family,
  cfg$tau_label,
  cfg$n_train,
  cfg$rep_id,
  cfg$model
))
if (!is.na(error_msg)) {
  cat(sprintf("[row %d] error=%s\n", row_id, error_msg))
}

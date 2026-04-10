#!/usr/bin/env Rscript

options(stringsAsFactors = FALSE)

`%||%` <- function(x, y) if (is.null(x) || !length(x)) y else x

parse_args_rhsns_exal_repair <- function(args) {
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

safe_chr_rhsns_exal_repair <- function(x, default = NA_character_) {
  if (is.null(x) || !length(x) || is.na(x[1]) || !nzchar(trimws(as.character(x[1])))) return(default)
  as.character(x[1])
}

safe_num_rhsns_exal_repair <- function(x, default = NA_real_) {
  v <- suppressWarnings(as.numeric(x)[1])
  if (is.finite(v)) v else default
}

safe_int_rhsns_exal_repair <- function(x, default = NA_integer_) {
  v <- suppressWarnings(as.integer(x)[1])
  if (is.finite(v)) v else default
}

as_flag_rhsns_exal_repair <- function(x, default = FALSE) {
  if (is.null(x) || !length(x)) return(default)
  if (is.logical(x)) return(isTRUE(x[1]))
  tolower(as.character(x)[1]) %in% c("1", "true", "yes", "y", "t")
}

safe_rmvnorm_rhsns_exal_repair <- function(n, mean, sigma) {
  mean <- as.numeric(mean)
  sigma <- as.matrix(sigma)
  if (!nrow(sigma)) return(matrix(mean, nrow = n, byrow = TRUE))
  if (any(!is.finite(sigma))) sigma[!is.finite(sigma)] <- 0
  if (!all(is.finite(mean))) mean[!is.finite(mean)] <- 0
  if (nrow(sigma) != ncol(sigma) || nrow(sigma) != length(mean)) {
    return(matrix(mean, nrow = n, byrow = TRUE))
  }
  out <- tryCatch(
    mvtnorm::rmvnorm(n, mean = mean, sigma = sigma, method = "svd"),
    error = function(e) NULL
  )
  if (!is.null(out)) return(out)
  sigma <- sigma + diag(1e-8, nrow(sigma))
  mvtnorm::rmvnorm(n, mean = mean, sigma = sigma, method = "svd")
}

compact_fit_rhsns_exal_repair <- function(fit, inference) {
  out <- fit
  if (identical(inference, "mcmc")) {
    out$samp.v <- NULL
    out$samp.s <- NULL
    if (!is.null(out$mh.diagnostics$trace)) {
      out$mh.diagnostics$trace <- NULL
    }
  } else {
    if (!is.null(out$diagnostics$trace)) {
      out$diagnostics$trace <- NULL
    }
  }
  out
}

compute_static_metrics_rhsns_exal_repair <- function(cfg, fit_obj, series_wide, coef_truth, vb_draws = 1000L) {
  X_slopes <- as.matrix(series_wide[, grepl("^x[0-9]+$", names(series_wide)), drop = FALSE])
  X <- cbind(`(Intercept)` = 1, X_slopes)
  y <- as.numeric(series_wide$y)
  q_truth <- as.numeric(series_wide$q_target)

  slope_terms <- coef_truth$term[grepl("^x[0-9]+$", coef_truth$term)]
  beta_truth <- as.numeric(coef_truth$beta_truth[match(slope_terms, coef_truth$term)])
  true_ind <- as.logical(coef_truth$is_signal[match(slope_terms, coef_truth$term)])

  if (identical(cfg$inference, "mcmc")) {
    beta_draws <- as.matrix(fit_obj$samp.beta)
    if (!length(dim(beta_draws))) beta_draws <- matrix(beta_draws, nrow = 1L)
    beta_mean <- colMeans(beta_draws)
  } else {
    beta_mean <- as.numeric(fit_obj$qbeta$m)
    beta_draws <- safe_rmvnorm_rhsns_exal_repair(vb_draws, beta_mean, as.matrix(fit_obj$qbeta$V))
  }

  coef_names <- colnames(beta_draws)
  expected_coef_names <- c("(Intercept)", slope_terms)
  if ((is.null(coef_names) || !length(coef_names)) && ncol(beta_draws) == length(expected_coef_names)) {
    colnames(beta_draws) <- expected_coef_names
    coef_names <- expected_coef_names
  }
  if (length(beta_mean) == length(expected_coef_names)) {
    names(beta_mean) <- expected_coef_names
  }

  slope_idx <- match(slope_terms, coef_names %||% expected_coef_names)
  if (any(!is.finite(slope_idx)) && ncol(beta_draws) == length(expected_coef_names)) {
    slope_idx <- seq_along(slope_terms) + 1L
  }
  if (any(!is.finite(slope_idx))) {
    stop(
      sprintf(
        "unable to align slope coefficients for metric computation (coef_names=%s)",
        paste(coef_names %||% "<NULL>", collapse = ",")
      )
    )
  }
  slope_draws <- beta_draws[, slope_idx, drop = FALSE]

  q_fit <- as.numeric(drop(X %*% beta_mean))
  q_rmse <- sqrt(mean((q_fit - q_truth)^2, na.rm = TRUE))

  rmse_per_beta <- sqrt(colMeans((sweep(slope_draws, 2, beta_truth, "-"))^2, na.rm = TRUE))
  beta_qq <- t(apply(slope_draws, 2, stats::quantile, probs = c(0.025, 0.975), na.rm = TRUE))
  beta_cover <- beta_truth >= beta_qq[, 1] & beta_truth <= beta_qq[, 2]

  sd_x <- apply(X_slopes, 2, stats::sd)
  sd_y <- stats::sd(y)
  be_star <- sweep(slope_draws, 2, sd_x / sd_y, "*")
  be_ind <- abs(be_star) > 0.1
  cie <- mean(rowMeans(sweep(be_ind, 2, true_ind, "==")))

  out <- data.frame(
    q_rmse = q_rmse,
    cie = cie,
    beta_rmse_mean = mean(rmse_per_beta),
    beta_coverage_mean = mean(beta_cover),
    beta_coverage_gap = abs(mean(beta_cover) - 0.95),
    stringsAsFactors = FALSE
  )

  for (j in seq_along(slope_terms)) {
    out[[sprintf("beta_rmse_%s", slope_terms[j])]] <- rmse_per_beta[j]
    out[[sprintf("beta_cover_%s", slope_terms[j])]] <- as.numeric(beta_cover[j])
  }

  out
}

args <- parse_args_rhsns_exal_repair(commandArgs(trailingOnly = TRUE))
repo_root <- normalizePath(".", winslash = "/", mustWork = TRUE)
setwd(repo_root)

source("tools/merge_reports/LOCAL_original288_static_shrink_rhsns_exal_mcmc_repair_helpers_20260410.R")
source("tools/merge_reports/LOCAL_validation_health_gate_common_20260321.R")

manifest_path <- safe_chr_rhsns_exal_repair(args$manifest, NA_character_)
row_id <- safe_int_rhsns_exal_repair(args$row_id, NA_integer_)
tag <- safe_chr_rhsns_exal_repair(args$tag, run_tag_original288_static_shrink_rhsns_exal_mcmc_repair())
force <- as_flag_rhsns_exal_repair(args$force, FALSE)

if (is.na(manifest_path) || !file.exists(manifest_path)) stop("manifest is required and must exist")
if (!is.finite(row_id)) stop("row_id is required")

manifest <- utils::read.csv(manifest_path, stringsAsFactors = FALSE)
row <- manifest[manifest$row_id == row_id, , drop = FALSE]
if (!nrow(row)) stop(sprintf("row_id %d not found in manifest", row_id))
if (nrow(row) > 1L) stop(sprintf("row_id %d appears multiple times in manifest", row_id))

cfg <- readRDS(row$config_path[1])
start_ts <- as.character(Sys.time())
status <- "pending"
error_msg <- NA_character_
runtime_sec <- NA_real_
health_row <- NULL
metrics_row <- NULL

ensure_dir_original288_syncedbase_rerun(dirname(cfg$fit_path))
ensure_dir_original288_syncedbase_rerun(dirname(cfg$row_status_path))
ensure_dir_original288_syncedbase_rerun(dirname(cfg$health_path))
ensure_dir_original288_syncedbase_rerun(dirname(cfg$metrics_path))
ensure_dir_original288_syncedbase_rerun(file.path(cfg$run_root, "tables"))

write_failure_row_rhsns_exal_repair <- function(reason) {
  out <- data.frame(
    row_id = row_id,
    base_row_id = cfg$base_row_id,
    ts_start = start_ts,
    ts_end = as.character(Sys.time()),
    status = "failed_runtime",
    error = reason,
    gate_overall = "FAIL",
    healthy = FALSE,
    runtime_sec = NA_real_,
    phase = cfg$phase,
    lane_label = cfg$lane_label,
    repair_class = cfg$repair_class,
    root_kind = cfg$root_kind,
    family = cfg$family,
    tau_label = cfg$tau_label,
    fit_size = cfg$fit_size,
    model = cfg$model,
    inference = cfg$inference,
    profile_id = cfg$profile_id,
    selected_variant_tag = cfg$source_variant_tag,
    candidate_fit_path = cfg$fit_path,
    health_csv = cfg$health_path,
    metrics_csv = cfg$metrics_path,
    stringsAsFactors = FALSE
  )
  utils::write.csv(out, cfg$row_status_path, row.names = FALSE)
  utils::write.csv(
    data.frame(
      case_id = cfg$target_original_case_key %||% sprintf("row_%04d", row_id),
      variant = tag,
      gate_overall = "FAIL",
      healthy = FALSE,
      unhealthy_reason = "runtime_fail",
      run_time_sec = NA_real_,
      candidate_path = cfg$fit_path,
      stringsAsFactors = FALSE
    ),
    cfg$health_path,
    row.names = FALSE
  )
}

if (isTRUE(row$missing_inputs[1])) {
  write_failure_row_rhsns_exal_repair("missing_inputs flag is TRUE in manifest")
  quit(save = "no", status = 0)
}

if (!requireNamespace("pkgload", quietly = TRUE)) stop("pkgload is required")
if (!requireNamespace("mvtnorm", quietly = TRUE)) stop("mvtnorm is required")
pkgload::load_all(repo_root, quiet = TRUE)

series_wide <- utils::read.csv(cfg$series_wide_path, stringsAsFactors = FALSE)
coef_truth <- utils::read.csv(cfg$coef_truth_path, stringsAsFactors = FALSE)

X_slopes <- as.matrix(series_wide[, grepl("^x[0-9]+$", names(series_wide)), drop = FALSE])
X <- cbind(`(Intercept)` = 1, X_slopes)
y <- as.numeric(series_wide$y)

case_id <- safe_chr_rhsns_exal_repair(cfg$target_original_case_key, sprintf("static_shrink_rhsns::row_%04d", row_id))

tryCatch({
  if (file.exists(cfg$fit_path) && !force) {
    wrapped <- readRDS(cfg$fit_path)
    fit_obj <- wrapped$fit %||% wrapped
    runtime_sec <- safe_num_rhsns_exal_repair(wrapped$meta$runtime_sec %||% fit_obj$run.time, NA_real_)
    status <- "skipped_existing"
  } else {
    set.seed(cfg$fit_seed)

    old_refresh_int <- getOption("exdqlm.static.mcmc.laplace_refresh_interval")
    old_refresh_start <- getOption("exdqlm.static.mcmc.laplace_refresh_start")
    old_refresh_weight <- getOption("exdqlm.static.mcmc.laplace_refresh_weight")
    options(
      exdqlm.static.mcmc.laplace_refresh_interval = safe_int_rhsns_exal_repair(cfg$laplace_refresh_interval, 50L),
      exdqlm.static.mcmc.laplace_refresh_start = safe_int_rhsns_exal_repair(cfg$laplace_refresh_start, 333L),
      exdqlm.static.mcmc.laplace_refresh_weight = safe_num_rhsns_exal_repair(cfg$laplace_refresh_weight, 0.60)
    )
    on.exit(
      options(
        exdqlm.static.mcmc.laplace_refresh_interval = old_refresh_int,
        exdqlm.static.mcmc.laplace_refresh_start = old_refresh_start,
        exdqlm.static.mcmc.laplace_refresh_weight = old_refresh_weight
      ),
      add = TRUE
    )

    runtime_obj <- system.time({
      fit_obj <- exal_static_mcmc(
        y = y,
        X = X,
        p0 = cfg$tau,
        beta_prior = cfg$beta_prior,
        beta_prior_controls = NULL,
        dqlm.ind = FALSE,
        n.burn = safe_int_rhsns_exal_repair(cfg$n_burn, 2000L),
        n.mcmc = safe_int_rhsns_exal_repair(cfg$n_mcmc, 1000L),
        thin = safe_int_rhsns_exal_repair(cfg$thin, 1L),
        init.from.vb = isTRUE(cfg$init_from_vb),
        vb_init_controls = cfg$vb_init_controls %||% list(max_iter = 1000L, tol = 1e-4, n_samp_xi = 200L, verbose = FALSE),
        mh.proposal = safe_chr_rhsns_exal_repair(cfg$mh_proposal, "laplace_rw"),
        mh.adapt = as_flag_rhsns_exal_repair(cfg$mh_adapt, TRUE),
        slice.width = safe_num_rhsns_exal_repair(cfg$slice_width, 0.12),
        slice.max.steps = safe_num_rhsns_exal_repair(cfg$slice_max_steps, 80),
        gamma.substeps = safe_int_rhsns_exal_repair(cfg$gamma_substeps, 1L),
        p.global.eta.jump = safe_num_rhsns_exal_repair(cfg$p_global_eta_jump, 0),
        global.eta.jump.scale = safe_num_rhsns_exal_repair(cfg$global_eta_jump_scale, 1),
        trace.diagnostics = TRUE,
        trace.every = safe_int_rhsns_exal_repair(cfg$trace_every, 50L),
        verbose = FALSE
      )
    })

    runtime_sec <- as.numeric(runtime_obj[["elapsed"]])
    wrapped <- list(
      fit = compact_fit_rhsns_exal_repair(fit_obj, cfg$inference),
      meta = list(
        runtime_sec = runtime_sec,
        seed = cfg$fit_seed,
        profile_id = cfg$profile_id,
        requested_init_mode = cfg$requested_init_mode,
        resolved_init_mode = cfg$resolved_init_mode,
        source_variant_tag = cfg$source_variant_tag,
        historical_source = cfg$historical_source,
        base_row_id = cfg$base_row_id,
        tag = tag
      )
    )
    saveRDS(wrapped, cfg$fit_path)
    status <- "done"
  }

  fit_for_metrics <- fit_obj %||% wrapped$fit
  metrics_row <- compute_static_metrics_rhsns_exal_repair(cfg, fit_for_metrics, series_wide, coef_truth)
  metrics_row <- cbind(
    data.frame(
      row_id = row_id,
      base_row_id = cfg$base_row_id,
      case_id = case_id,
      phase = cfg$phase,
      lane_label = cfg$lane_label,
      repair_class = cfg$repair_class,
      block = cfg$block,
      root_kind = cfg$root_kind,
      family = cfg$family,
      tau = cfg$tau,
      tau_label = cfg$tau_label,
      fit_size = cfg$fit_size,
      model = cfg$model,
      inference = cfg$inference,
      prior_semantics = cfg$target_prior_semantics,
      profile_id = cfg$profile_id,
      selected_variant_tag = cfg$source_variant_tag,
      runtime_sec = runtime_sec,
      fit_path = cfg$fit_path,
      stringsAsFactors = FALSE
    ),
    metrics_row,
    stringsAsFactors = FALSE
  )

  health_metrics <- vhg_collect_mcmc_metrics(
    wrapped,
    case_id = case_id,
    variant = tag,
    candidate_path = cfg$fit_path
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
    case_id = case_id,
    variant = tag,
    gate_overall = "FAIL",
    healthy = FALSE,
    unhealthy_reason = "runtime_fail",
    run_time_sec = runtime_sec,
    candidate_path = cfg$fit_path,
    stringsAsFactors = FALSE
  )
  utils::write.csv(health_row, cfg$health_path, row.names = FALSE)
}

row_out <- data.frame(
  row_id = row_id,
  base_row_id = cfg$base_row_id,
  ts_start = start_ts,
  ts_end = as.character(Sys.time()),
  status = status,
  error = error_msg,
  gate_overall = safe_chr_rhsns_exal_repair(health_row$gate_overall[1], "FAIL"),
  healthy = isTRUE(health_row$healthy[1]),
  runtime_sec = runtime_sec,
  phase = cfg$phase,
  lane_label = cfg$lane_label,
  repair_class = cfg$repair_class,
  root_kind = cfg$root_kind,
  family = cfg$family,
  tau_label = cfg$tau_label,
  fit_size = cfg$fit_size,
  model = cfg$model,
  inference = cfg$inference,
  profile_id = cfg$profile_id,
  selected_variant_tag = cfg$source_variant_tag,
  candidate_fit_path = cfg$fit_path,
  health_csv = cfg$health_path,
  metrics_csv = cfg$metrics_path,
  stringsAsFactors = FALSE
)

utils::write.csv(row_out, cfg$row_status_path, row.names = FALSE)
cat(sprintf(
  "[row %d|base %d] status=%s gate=%s healthy=%s phase=%s class=%s family=%s tau=%s tt=%d profile=%s\n",
  row_id,
  cfg$base_row_id,
  status,
  row_out$gate_overall[1],
  row_out$healthy[1],
  cfg$phase,
  cfg$repair_class,
  cfg$family,
  cfg$tau_label,
  cfg$fit_size,
  cfg$profile_id
))

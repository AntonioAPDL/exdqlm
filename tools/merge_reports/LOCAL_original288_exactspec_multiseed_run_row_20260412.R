#!/usr/bin/env Rscript

options(stringsAsFactors = FALSE)

source("tools/merge_reports/LOCAL_original288_exactspec_multiseed_helpers_20260412.R")

`%||%` <- function(x, y) if (is.null(x) || !length(x)) y else x

parse_args_original288_exactspec_multiseed <- function(args) {
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

is_missing_scalar_original288_exactspec_multiseed <- function(x) {
  if (is.null(x) || !length(x)) return(TRUE)
  if (all(is.na(x))) return(TRUE)
  y <- as.character(x)[1]
  !nzchar(trimws(y)) || identical(toupper(trimws(y)), "NA")
}

first_present_original288_exactspec_multiseed <- function(..., default = NULL) {
  vals <- list(...)
  for (v in vals) {
    if (!is_missing_scalar_original288_exactspec_multiseed(v)) return(v)
  }
  default
}

safe_num_vec_original288_exactspec_multiseed <- function(x, default) {
  v <- suppressWarnings(as.numeric(x))
  if (!length(v) || any(!is.finite(v))) return(as.numeric(default))
  v
}

collect_vb_health_original288_exactspec_multiseed <- function(wrapped,
                                                              case_id,
                                                              variant,
                                                              candidate_path,
                                                              vhg_extract_rhs_collapse) {
  fit <- wrapped$fit %||% wrapped
  conv <- fit$diagnostics$convergence$converged %||% fit$converged %||% NA
  stop_reason <- as.character(fit$diagnostics$convergence$stop_reason %||% NA_character_)
  rhs <- vhg_extract_rhs_collapse(fit)

  finite_ok <- TRUE
  if (!is.null(fit$diagnostics$deltas)) {
    d <- unlist(fit$diagnostics$deltas, use.names = FALSE)
    d <- d[is.finite(d)]
    finite_ok <- length(d) > 0L
  }

  gate_overall <- if (isTRUE(rhs$collapse_flag)) {
    "FAIL"
  } else if (isTRUE(conv)) {
    "PASS"
  } else if (isTRUE(finite_ok)) {
    "WARN"
  } else {
    "FAIL"
  }

  data.frame(
    case_id = case_id,
    variant = variant,
    gate_overall = gate_overall,
    healthy = gate_overall %in% c("PASS", "WARN") && !isTRUE(rhs$collapse_flag),
    unhealthy_reason = if (isTRUE(rhs$collapse_flag)) "rhs_collapse" else if (gate_overall == "FAIL") "vb_fail" else NA_character_,
    rhs_collapse_flag = isTRUE(rhs$collapse_flag),
    rhs_collapse_sources = rhs$collapse_sources,
    vb_converged = isTRUE(conv),
    vb_stop_reason = stop_reason,
    run_time_sec = safe_num_original288_exactspec_multiseed(wrapped$meta$runtime_sec %||% fit$run.time, NA_real_),
    candidate_path = candidate_path,
    stringsAsFactors = FALSE
  )
}

compact_fit_original288_exactspec_multiseed <- function(fit, inference) {
  out <- fit
  if (identical(inference, "mcmc")) {
    out$samp.v <- NULL
    out$samp.s <- NULL
    if (!is.null(out$mh.diagnostics$trace)) out$mh.diagnostics$trace <- NULL
  } else {
    if (!is.null(out$diagnostics$trace)) out$diagnostics$trace <- NULL
  }
  out
}

set_dynamic_ld_options_original288_exactspec_multiseed <- function(ld_list) {
  if (!is.list(ld_list) || !length(ld_list)) return(list())
  named <- ld_list
  names(named) <- paste0("exdqlm.dynamic.ldvb.", names(ld_list))
  options(named)
}

write_row_failure_original288_exactspec_multiseed <- function(row, row_id, reason) {
  health_row <- data.frame(
    case_id = row$original_case_key,
    variant = run_tag_original288_exactspec_multiseed(),
    gate_overall = "FAIL",
    healthy = FALSE,
    unhealthy_reason = "runtime_fail",
    rhs_collapse_flag = NA,
    run_time_sec = NA_real_,
    candidate_path = row$candidate_fit_path,
    stringsAsFactors = FALSE
  )
  metrics_row <- data.frame(
    row_id = row_id,
    base_row_id = row$base_row_id,
    original_case_key = row$original_case_key,
    phase = row$phase,
    seed_slot = row$seed_slot,
    seed = row$seed,
    block = row$block,
    root_kind = row$root_kind,
    family = row$family,
    tau_label = row$tau_label,
    fit_size = row$fit_size,
    prior_semantics = row$prior_semantics,
    model = row$model,
    inference = row$inference,
    gate_overall = "FAIL",
    healthy = FALSE,
    runtime_sec = NA_real_,
    crps_metric = NA_real_,
    primary_accuracy_metric = NA_real_,
    q_rmse_metric = NA_real_,
    coverage95_metric = NA_real_,
    coverage95_gap_metric = NA_real_,
    mean_ci_width_metric = NA_real_,
    cie_metric = NA_real_,
    beta_rmse_mean_metric = NA_real_,
    beta_coverage_gap_metric = NA_real_,
    metric_source = "runtime_fail",
    metric_error = reason,
    stringsAsFactors = FALSE
  )
  row_out <- data.frame(
    row_id = row_id,
    base_row_id = row$base_row_id,
    original_case_key = row$original_case_key,
    ts_start = as.character(Sys.time()),
    ts_end = as.character(Sys.time()),
    status = "failed_runtime",
    error = reason,
    gate_overall = "FAIL",
    healthy = FALSE,
    runtime_sec = NA_real_,
    phase = row$phase,
    block = row$block,
    root_kind = row$root_kind,
    family = row$family,
    tau_label = row$tau_label,
    fit_size = row$fit_size,
    prior_semantics = row$prior_semantics,
    model = row$model,
    inference = row$inference,
    seed_slot = row$seed_slot,
    seed = row$seed,
    candidate_fit_path = row$candidate_fit_path,
    health_csv = row$health_path,
    metrics_csv = row$metrics_path,
    draws_rds = row$draws_path,
    stringsAsFactors = FALSE
  )
  utils::write.csv(health_row, row$health_path, row.names = FALSE)
  utils::write.csv(metrics_row, row$metrics_path, row.names = FALSE)
  utils::write.csv(row_out, row$row_status_path, row.names = FALSE)
}

args <- parse_args_original288_exactspec_multiseed(commandArgs(trailingOnly = TRUE))
repo_root <- normalizePath(".", winslash = "/", mustWork = TRUE)
setwd(repo_root)

source("tools/merge_reports/LOCAL_validation_health_gate_common_20260321.R")

manifest_path <- safe_chr_original288_exactspec_multiseed(
  args$manifest,
  paths_original288_exactspec_multiseed()$full_manifest
)
row_id <- safe_int_original288_exactspec_multiseed(args$row_id, NA_integer_)
tag <- safe_chr_original288_exactspec_multiseed(args$tag, run_tag_original288_exactspec_multiseed())
force <- as_flag_original288_exactspec_multiseed(args$force, FALSE)

if (is.na(manifest_path) || !file.exists(manifest_path)) stop("manifest is required and must exist")
if (!is.finite(row_id)) stop("row_id is required")

manifest <- utils::read.csv(manifest_path, stringsAsFactors = FALSE, check.names = FALSE)
row <- manifest[manifest$row_id == row_id, , drop = FALSE]
if (!nrow(row)) stop(sprintf("row_id %d not found in manifest", row_id))
if (nrow(row) > 1L) stop(sprintf("row_id %d appears multiple times in manifest", row_id))
row <- row[1, , drop = FALSE]
cfg <- readRDS(row$config_path)

for (path in c(dirname(cfg$fit_path), dirname(cfg$row_status_path), dirname(cfg$health_path), dirname(cfg$metrics_path), dirname(cfg$draws_path))) {
  ensure_dir_original288_exactspec_multiseed(path)
}

if (isTRUE(row$missing_inputs)) {
  write_row_failure_original288_exactspec_multiseed(row, row_id, "missing_inputs flag is TRUE in manifest")
  quit(save = "no", status = 0)
}

if (!requireNamespace("pkgload", quietly = TRUE)) stop("pkgload is required")
if (!requireNamespace("mvtnorm", quietly = TRUE)) stop("mvtnorm is required")
pkgload::load_all(repo_root, quiet = TRUE)

Sys.setenv(
  OMP_NUM_THREADS = "1",
  OPENBLAS_NUM_THREADS = "1",
  MKL_NUM_THREADS = "1"
)

run_dynamic_original288_exactspec_multiseed <- function() {
  sim_obj <- readRDS(cfg$sim_output_path)
  model_obj <- build_dlm_constV_smallW_model_original288_syncedbase_dynamic_restored_closure(
    period = cfg$period,
    no_trend = TRUE
  )

  start_ts <- as.character(Sys.time())
  status <- "pending"
  error_msg <- NA_character_
  health_row <- NULL
  metrics_row <- NULL
  wrapped <- NULL

  tryCatch({
    if (file.exists(cfg$fit_path) && !force) {
      wrapped <- readRDS(cfg$fit_path)
      status <- "skipped_existing"
    } else {
      fit_obj <- NULL
      runtime_obj <- NULL
      set.seed(cfg$fit_seed)

      if (identical(cfg$inference, "vb")) {
        old_ld <- set_dynamic_ld_options_original288_exactspec_multiseed(cfg$ld_controls %||% list())
        on.exit(if (length(old_ld)) options(old_ld), add = TRUE)
        old_opt <- options(list(
          exdqlm.max_iter = safe_int_original288_exactspec_multiseed(cfg$vb_max_iter, 1200L),
          exdqlm.tol_sigma = safe_num_original288_exactspec_multiseed(cfg$vb_tol_sigma, cfg$vb_tol),
          exdqlm.tol_gamma = safe_num_original288_exactspec_multiseed(cfg$vb_tol_gamma, cfg$vb_tol),
          exdqlm.tol_elbo = safe_num_original288_exactspec_multiseed(cfg$vb_tol_elbo, 1e-6),
          exdqlm.vb.min_iter = safe_int_original288_exactspec_multiseed(cfg$vb_min_iter, 10L),
          exdqlm.vb.patience = safe_int_original288_exactspec_multiseed(cfg$vb_patience, 3L),
          exdqlm.vb.allow_elbo_drop = safe_num_original288_exactspec_multiseed(cfg$vb_allow_elbo_drop, 1e-5)
        ))
        on.exit(options(old_opt), add = TRUE)

        runtime_obj <- system.time({
          fit_obj <- exdqlmLDVB(
            y = as.numeric(sim_obj$y),
            p0 = cfg$tau,
            model = model_obj,
            df = rep(cfg$df_value, 2L),
            dim.df = cfg$dim_df,
            fix.sigma = FALSE,
            sig.init = NA_real_,
            dqlm.ind = isTRUE(cfg$dqlm_ind),
            tol = safe_num_original288_exactspec_multiseed(cfg$vb_tol, 0.03),
            n.samp = safe_int_original288_exactspec_multiseed(cfg$vb_n_samp_internal, 1000L),
            verbose = FALSE
          )
        })
      } else {
        refresh_opts <- list()
        if (is.finite(safe_int_original288_exactspec_multiseed(cfg$laplace_refresh_interval, NA_integer_))) {
          refresh_opts$exdqlm.mcmc.laplace_refresh_interval <- cfg$laplace_refresh_interval
        }
        if (is.finite(safe_int_original288_exactspec_multiseed(cfg$laplace_refresh_start, NA_integer_))) {
          refresh_opts$exdqlm.mcmc.laplace_refresh_start <- cfg$laplace_refresh_start
        }
        if (is.finite(safe_num_original288_exactspec_multiseed(cfg$laplace_refresh_weight, NA_real_))) {
          refresh_opts$exdqlm.mcmc.laplace_refresh_weight <- cfg$laplace_refresh_weight
        }
        if (length(refresh_opts)) {
          old_refresh <- options(refresh_opts)
          on.exit(options(old_refresh), add = TRUE)
        }

        call_args <- list(
          y = as.numeric(sim_obj$y),
          p0 = cfg$tau,
          model = model_obj,
          df = rep(cfg$df_value, 2L),
          dim.df = cfg$dim_df,
          dqlm.ind = isTRUE(cfg$dqlm_ind),
          n.burn = safe_int_original288_exactspec_multiseed(cfg$n_burn, 5000L),
          n.mcmc = safe_int_original288_exactspec_multiseed(cfg$n_mcmc, 20000L),
          init.from.vb = as_flag_original288_exactspec_multiseed(cfg$init_from_vb, TRUE),
          init.from.isvb = as_flag_original288_exactspec_multiseed(cfg$init_from_isvb, FALSE),
          vb_init_controls = list(
            method = safe_chr_original288_exactspec_multiseed(cfg$vb_method, "ldvb"),
            tol = safe_num_original288_exactspec_multiseed(cfg$vb_tol, 0.03),
            n.IS = safe_int_original288_exactspec_multiseed(cfg$vb_n_IS, 200L),
            n.samp = safe_int_original288_exactspec_multiseed(cfg$vb_n_samp_internal, 1000L),
            max_iter = safe_int_original288_exactspec_multiseed(cfg$vb_max_iter, 1200L),
            verbose = FALSE
          ),
          joint.sample = as_flag_original288_exactspec_multiseed(cfg$mh_joint_sample, FALSE),
          mh.proposal = safe_chr_original288_exactspec_multiseed(cfg$mh_proposal, "laplace_rw"),
          mh.adapt = as_flag_original288_exactspec_multiseed(cfg$mh_adapt, TRUE),
          mh.adapt.interval = safe_int_original288_exactspec_multiseed(cfg$mh_adapt_interval, 50L),
          mh.target.accept = safe_num_vec_original288_exactspec_multiseed(cfg$mh_target_accept, c(0.20, 0.45)),
          mh.scale.bounds = safe_num_vec_original288_exactspec_multiseed(cfg$mh_scale_bounds, c(0.1, 10)),
          mh.max_scale.step = safe_num_original288_exactspec_multiseed(cfg$mh_max_scale_step, 0.35),
          mh.min_burn_adapt = safe_int_original288_exactspec_multiseed(cfg$mh_min_burn_adapt, 50L),
          trace.diagnostics = TRUE,
          trace.every = safe_int_original288_exactspec_multiseed(cfg$trace_every, 50L),
          verbose = FALSE
        )
        if (is.finite(safe_num_original288_exactspec_multiseed(cfg$slice_width, NA_real_))) {
          call_args$slice.width <- safe_num_original288_exactspec_multiseed(cfg$slice_width, NA_real_)
        }
        if (is.finite(safe_int_original288_exactspec_multiseed(cfg$slice_max_steps, NA_integer_))) {
          call_args$slice.max.steps <- safe_int_original288_exactspec_multiseed(cfg$slice_max_steps, NA_integer_)
        }

        runtime_obj <- system.time({
          fit_obj <- do.call(exdqlmMCMC, call_args)
        })
      }

      wrapped <- list(
        fit = compact_fit_original288_exactspec_multiseed(fit_obj, cfg$inference),
        meta = list(
          runtime_sec = as.numeric(runtime_obj[["elapsed"]]),
          seed = cfg$fit_seed,
          tag = tag
        )
      )
      saveRDS(wrapped, cfg$fit_path)
      status <- "done"
    }

    case_id <- safe_chr_original288_exactspec_multiseed(cfg$original_case_key, sprintf("row_%04d", row_id))
    fit_obj <- wrapped$fit %||% wrapped

    if (identical(cfg$inference, "mcmc")) {
      health_metrics <- vhg_collect_mcmc_metrics(wrapped, case_id = case_id, variant = tag, candidate_path = cfg$fit_path)
      health_row <- vhg_apply_health_gates(health_metrics)
    } else {
      health_row <- collect_vb_health_original288_exactspec_multiseed(
        wrapped,
        case_id = case_id,
        variant = tag,
        candidate_path = cfg$fit_path,
        vhg_extract_rhs_collapse = vhg_extract_rhs_collapse
      )
    }

    draw_mat <- as.matrix(fit_obj$samp.post.pred)
    draw_idx <- select_draw_indices_original288_exactspec_multiseed(ncol(draw_mat), 20000L, cfg$fit_seed)
    draw_keep <- draw_mat[, draw_idx, drop = FALSE]
    metric_core <- dynamic_metrics_original288_exactspec_multiseed(row, sim_obj, draw_keep)

    saveRDS(
      list(
        kind = "dynamic_predictive_draw_contract",
        source_fit_path = cfg$fit_path,
        n_posterior_draws = 20000L,
        selected_indices = draw_idx,
        source_draw_count = ncol(draw_mat),
        seed = as.integer(cfg$fit_seed)
      ),
      cfg$draws_path
    )

    metrics_row <- data.frame(
      row_id = row_id,
      base_row_id = row$base_row_id,
      original_case_key = row$original_case_key,
      phase = row$phase,
      seed_slot = row$seed_slot,
      seed = row$seed,
      block = row$block,
      root_kind = row$root_kind,
      family = row$family,
      tau_label = row$tau_label,
      fit_size = row$fit_size,
      prior_semantics = row$prior_semantics,
      model = row$model,
      inference = row$inference,
      gate_overall = safe_chr_original288_exactspec_multiseed(health_row$gate_overall[1], "FAIL"),
      healthy = isTRUE(health_row$healthy[1]),
      runtime_sec = safe_num_original288_exactspec_multiseed(health_row$run_time_sec[1], safe_num_original288_exactspec_multiseed(wrapped$meta$runtime_sec, NA_real_)),
      crps_metric = metric_core$crps[[1]],
      primary_accuracy_metric = metric_core$q_rmse[[1]],
      q_rmse_metric = metric_core$q_rmse[[1]],
      coverage95_metric = metric_core$coverage95[[1]],
      coverage95_gap_metric = metric_core$coverage95_gap[[1]],
      mean_ci_width_metric = metric_core$mean_ci_width[[1]],
      cie_metric = NA_real_,
      beta_rmse_mean_metric = NA_real_,
      beta_coverage_gap_metric = NA_real_,
      metric_source = "exactspec_multiseed_dynamic",
      metric_error = NA_character_,
      stringsAsFactors = FALSE
    )

    utils::write.csv(health_row, cfg$health_path, row.names = FALSE)
    utils::write.csv(metrics_row, cfg$metrics_path, row.names = FALSE)

    row_out <- data.frame(
      row_id = row_id,
      base_row_id = row$base_row_id,
      original_case_key = row$original_case_key,
      ts_start = start_ts,
      ts_end = as.character(Sys.time()),
      status = status,
      error = error_msg,
      gate_overall = safe_chr_original288_exactspec_multiseed(health_row$gate_overall[1], "FAIL"),
      healthy = isTRUE(health_row$healthy[1]),
      runtime_sec = metrics_row$runtime_sec[1],
      phase = row$phase,
      block = row$block,
      root_kind = row$root_kind,
      family = row$family,
      tau_label = row$tau_label,
      fit_size = row$fit_size,
      prior_semantics = row$prior_semantics,
      model = row$model,
      inference = row$inference,
      seed_slot = row$seed_slot,
      seed = row$seed,
      candidate_fit_path = row$candidate_fit_path,
      health_csv = row$health_path,
      metrics_csv = row$metrics_path,
      draws_rds = row$draws_path,
      stringsAsFactors = FALSE
    )
    utils::write.csv(row_out, row$row_status_path, row.names = FALSE)
  }, error = function(e) {
    write_row_failure_original288_exactspec_multiseed(row, row_id, conditionMessage(e))
  })
}

run_static_original288_exactspec_multiseed <- function() {
  series_wide <- utils::read.csv(cfg$series_wide_path, stringsAsFactors = FALSE)
  coef_truth <- utils::read.csv(cfg$coef_truth_path, stringsAsFactors = FALSE)
  design <- static_build_design_original288_normalized_multiseed(series_wide)

  start_ts <- as.character(Sys.time())
  status <- "pending"
  error_msg <- NA_character_
  health_row <- NULL
  metrics_row <- NULL
  wrapped <- NULL

  tryCatch({
    if (file.exists(cfg$fit_path) && !force) {
      wrapped <- readRDS(cfg$fit_path)
      status <- "skipped_existing"
    } else {
      fit_obj <- NULL
      runtime_obj <- NULL
      set.seed(cfg$fit_seed)

      if (identical(cfg$inference, "vb")) {
        runtime_obj <- system.time({
          fit_obj <- exal_static_LDVB(
            y = design$y,
            X = design$X,
            p0 = cfg$tau,
            max_iter = safe_int_original288_exactspec_multiseed(cfg$max_iter, 300L),
            tol = safe_num_original288_exactspec_multiseed(cfg$tol, 0.03),
            beta_prior = cfg$beta_prior,
            beta_prior_controls = cfg$beta_prior_controls %||% NULL,
            dqlm.ind = isTRUE(cfg$dqlm_ind),
            n_samp_xi = safe_int_original288_exactspec_multiseed(cfg$n_samp_xi, 1000L),
            ld_controls = cfg$ld_controls %||% list(store_trace = FALSE),
            verbose = FALSE
          )
        })
      } else {
        refresh_opts <- list()
        if (is.finite(safe_int_original288_exactspec_multiseed(cfg$laplace_refresh_interval, NA_integer_))) {
          refresh_opts$exdqlm.static.mcmc.laplace_refresh_interval <- cfg$laplace_refresh_interval
        }
        if (is.finite(safe_int_original288_exactspec_multiseed(cfg$laplace_refresh_start, NA_integer_))) {
          refresh_opts$exdqlm.static.mcmc.laplace_refresh_start <- cfg$laplace_refresh_start
        }
        if (is.finite(safe_num_original288_exactspec_multiseed(cfg$laplace_refresh_weight, NA_real_))) {
          refresh_opts$exdqlm.static.mcmc.laplace_refresh_weight <- cfg$laplace_refresh_weight
        }
        if (length(refresh_opts)) {
          old_refresh <- options(refresh_opts)
          on.exit(options(old_refresh), add = TRUE)
        }

        call_args <- list(
          y = design$y,
          X = design$X,
          p0 = cfg$tau,
          beta_prior = cfg$beta_prior,
          beta_prior_controls = cfg$beta_prior_controls %||% NULL,
          dqlm.ind = isTRUE(cfg$dqlm_ind),
          n.burn = safe_int_original288_exactspec_multiseed(cfg$n_burn, 5000L),
          n.mcmc = safe_int_original288_exactspec_multiseed(cfg$n_mcmc, 20000L),
          thin = safe_int_original288_exactspec_multiseed(cfg$thin, 1L),
          init.from.vb = as_flag_original288_exactspec_multiseed(cfg$init_from_vb, TRUE),
          vb_init_controls = cfg$vb_init_controls %||% list(max_iter = 300L, tol = 0.03, n_samp_xi = 1000L, ld_controls = cfg$ld_controls %||% NULL, verbose = FALSE),
          mh.proposal = safe_chr_original288_exactspec_multiseed(cfg$mh_proposal, "laplace_rw"),
          mh.adapt = as_flag_original288_exactspec_multiseed(cfg$mh_adapt, TRUE),
          mh.adapt.interval = safe_int_original288_exactspec_multiseed(cfg$mh_adapt_interval, 50L),
          mh.target.accept = safe_num_vec_original288_exactspec_multiseed(cfg$mh_target_accept, c(0.20, 0.45)),
          mh.scale.bounds = safe_num_vec_original288_exactspec_multiseed(cfg$mh_scale_bounds, c(0.1, 10)),
          mh.max_scale.step = safe_num_original288_exactspec_multiseed(cfg$mh_max_scale_step, 0.35),
          mh.min_burn_adapt = safe_int_original288_exactspec_multiseed(cfg$mh_min_burn_adapt, 50L),
          gamma.substeps = safe_int_original288_exactspec_multiseed(cfg$gamma_substeps, 1L),
          p.global.eta.jump = safe_num_original288_exactspec_multiseed(cfg$p_global_eta_jump, 0),
          global.eta.jump.scale = safe_num_original288_exactspec_multiseed(cfg$global_eta_jump_scale, 1),
          trace.diagnostics = as_flag_original288_exactspec_multiseed(cfg$trace_diagnostics, TRUE),
          trace.every = safe_int_original288_exactspec_multiseed(cfg$trace_every, 50L),
          verbose = FALSE
        )
        if (is.finite(safe_num_original288_exactspec_multiseed(cfg$slice_width, NA_real_))) {
          call_args$slice.width <- safe_num_original288_exactspec_multiseed(cfg$slice_width, NA_real_)
        }
        if (is.finite(safe_int_original288_exactspec_multiseed(cfg$slice_max_steps, NA_integer_))) {
          call_args$slice.max.steps <- safe_int_original288_exactspec_multiseed(cfg$slice_max_steps, NA_integer_)
        }

        runtime_obj <- system.time({
          fit_obj <- do.call(exal_static_mcmc, call_args)
        })
      }

      wrapped <- list(
        fit = compact_fit_original288_exactspec_multiseed(fit_obj, cfg$inference),
        meta = list(
          runtime_sec = as.numeric(runtime_obj[["elapsed"]]),
          seed = cfg$fit_seed,
          tag = tag
        )
      )
      saveRDS(wrapped, cfg$fit_path)
      status <- "done"
    }

    case_id <- safe_chr_original288_exactspec_multiseed(cfg$original_case_key, sprintf("row_%04d", row_id))
    fit_obj <- wrapped$fit %||% wrapped

    if (identical(cfg$inference, "mcmc")) {
      health_metrics <- vhg_collect_mcmc_metrics(wrapped, case_id = case_id, variant = tag, candidate_path = cfg$fit_path)
      health_row <- vhg_apply_health_gates(health_metrics)
    } else {
      health_row <- collect_vb_health_original288_exactspec_multiseed(
        wrapped,
        case_id = case_id,
        variant = tag,
        candidate_path = cfg$fit_path,
        vhg_extract_rhs_collapse = vhg_extract_rhs_collapse
      )
    }

    draw_bundle <- static_predictive_draws_original288_exactspec_multiseed(
      fit_obj = fit_obj,
      row = row,
      series_wide = series_wide,
      n_draws = 20000L,
      seed = cfg$fit_seed
    )
    metric_core <- static_metrics_original288_exactspec_multiseed(row, fit_obj, series_wide, coef_truth, draw_bundle)

    saveRDS(
      list(
        kind = "static_parameter_draw_export",
        model = row$model,
        inference = row$inference,
        n_posterior_draws = 20000L,
        seed = as.integer(cfg$fit_seed),
        beta_draws = draw_bundle$beta_draws,
        sigma_draws = draw_bundle$sigma_draws,
        gamma_draws = draw_bundle$gamma_draws
      ),
      cfg$draws_path
    )

    metrics_row <- data.frame(
      row_id = row_id,
      base_row_id = row$base_row_id,
      original_case_key = row$original_case_key,
      phase = row$phase,
      seed_slot = row$seed_slot,
      seed = row$seed,
      block = row$block,
      root_kind = row$root_kind,
      family = row$family,
      tau_label = row$tau_label,
      fit_size = row$fit_size,
      prior_semantics = row$prior_semantics,
      model = row$model,
      inference = row$inference,
      gate_overall = safe_chr_original288_exactspec_multiseed(health_row$gate_overall[1], "FAIL"),
      healthy = isTRUE(health_row$healthy[1]),
      runtime_sec = safe_num_original288_exactspec_multiseed(health_row$run_time_sec[1], safe_num_original288_exactspec_multiseed(wrapped$meta$runtime_sec, NA_real_)),
      crps_metric = metric_core$crps[[1]],
      primary_accuracy_metric = metric_core$q_rmse[[1]],
      q_rmse_metric = metric_core$q_rmse[[1]],
      coverage95_metric = metric_core$coverage95[[1]],
      coverage95_gap_metric = metric_core$coverage95_gap[[1]],
      mean_ci_width_metric = metric_core$mean_ci_width[[1]],
      cie_metric = metric_core$cie[[1]],
      beta_rmse_mean_metric = metric_core$beta_rmse_mean[[1]],
      beta_coverage_gap_metric = metric_core$beta_coverage_gap[[1]],
      metric_source = "exactspec_multiseed_static",
      metric_error = NA_character_,
      stringsAsFactors = FALSE
    )

    utils::write.csv(health_row, cfg$health_path, row.names = FALSE)
    utils::write.csv(metrics_row, cfg$metrics_path, row.names = FALSE)

    row_out <- data.frame(
      row_id = row_id,
      base_row_id = row$base_row_id,
      original_case_key = row$original_case_key,
      ts_start = start_ts,
      ts_end = as.character(Sys.time()),
      status = status,
      error = error_msg,
      gate_overall = safe_chr_original288_exactspec_multiseed(health_row$gate_overall[1], "FAIL"),
      healthy = isTRUE(health_row$healthy[1]),
      runtime_sec = metrics_row$runtime_sec[1],
      phase = row$phase,
      block = row$block,
      root_kind = row$root_kind,
      family = row$family,
      tau_label = row$tau_label,
      fit_size = row$fit_size,
      prior_semantics = row$prior_semantics,
      model = row$model,
      inference = row$inference,
      seed_slot = row$seed_slot,
      seed = row$seed,
      candidate_fit_path = row$candidate_fit_path,
      health_csv = row$health_path,
      metrics_csv = row$metrics_path,
      draws_rds = row$draws_path,
      stringsAsFactors = FALSE
    )
    utils::write.csv(row_out, row$row_status_path, row.names = FALSE)
    gc()
  }, error = function(e) {
    write_row_failure_original288_exactspec_multiseed(row, row_id, conditionMessage(e))
  })
}

if (identical(cfg$block, "dynamic")) {
  run_dynamic_original288_exactspec_multiseed()
} else {
  run_static_original288_exactspec_multiseed()
}

cat(sprintf(
  "[exactspec-multiseed row %d] phase=%s model=%s inference=%s seed_slot=%s done\n",
  row_id,
  row$phase[[1]],
  row$model[[1]],
  row$inference[[1]],
  row$seed_slot[[1]]
))

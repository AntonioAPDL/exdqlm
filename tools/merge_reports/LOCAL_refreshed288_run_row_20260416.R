#!/usr/bin/env Rscript

options(stringsAsFactors = FALSE)

source("tools/merge_reports/LOCAL_refreshed288_helpers_20260416.R")

args <- parse_args_refreshed288(commandArgs(trailingOnly = TRUE))
repo_root <- normalizePath(".", winslash = "/", mustWork = TRUE)
setwd(repo_root)

source("tools/merge_reports/LOCAL_validation_health_gate_common_20260321.R")

manifest_path <- safe_chr_refreshed288(args$manifest, paths_refreshed288()$full_manifest)
row_id <- safe_int_refreshed288(args$row_id, NA_integer_)
tag <- safe_chr_refreshed288(args$tag, run_tag_refreshed288())
force <- as_flag_refreshed288(args$force, FALSE)

if (!file.exists(manifest_path)) stop("manifest is required and must exist")
if (!is.finite(row_id)) stop("row_id is required")
if (!requireNamespace("pkgload", quietly = TRUE)) stop("pkgload is required")
if (!requireNamespace("mvtnorm", quietly = TRUE)) stop("mvtnorm is required")
if (!requireNamespace("coda", quietly = TRUE)) stop("coda is required")

manifest <- utils::read.csv(manifest_path, stringsAsFactors = FALSE, check.names = FALSE)
row <- manifest[manifest$row_id == row_id, , drop = FALSE]
if (!nrow(row)) stop(sprintf("row_id %d not found in manifest", row_id))
if (nrow(row) > 1L) stop(sprintf("row_id %d appears multiple times in manifest", row_id))
row <- row[1, , drop = FALSE]
cfg <- readRDS(row$config_path)

for (path in c(
  dirname(cfg$candidate_fit_path),
  dirname(cfg$row_status_path),
  dirname(cfg$health_path),
  dirname(cfg$metrics_path),
  dirname(cfg$draws_path),
  dirname(cfg$vb_init_fit_path %||% "")
) ) {
  if (nzchar(path)) ensure_dir_refreshed288(path)
}

if (isTRUE(cfg$missing_inputs)) {
  write_row_failure_refreshed288(row, sprintf("missing_inputs is TRUE: %s", safe_chr_refreshed288(cfg$missing_paths, "unknown")))
  quit(save = "no", status = 0)
}

pkgload::load_all(repo_root, quiet = TRUE)

Sys.setenv(
  OMP_NUM_THREADS = "1",
  OPENBLAS_NUM_THREADS = "1",
  MKL_NUM_THREADS = "1"
)

resolve_wrapped_fit_refreshed288 <- function(obj) obj$fit %||% obj

build_dynamic_ldvb_fit_refreshed288 <- function(sim_obj, model_obj, controls, ld_controls, save_path = NA_character_, role = c("main_vb", "vb_init")) {
  role <- match.arg(role)
  old_ld <- set_dynamic_ld_options_refreshed288(ld_controls %||% list())
  on.exit(if (length(old_ld)) options(old_ld), add = TRUE)
  old_opt <- options(list(
    exdqlm.max_iter = safe_int_refreshed288(controls$max_iter, 300L),
    exdqlm.tol_sigma = safe_num_refreshed288(controls$tol_sigma %||% controls$tol, 0.03),
    exdqlm.tol_gamma = safe_num_refreshed288(controls$tol_gamma %||% controls$tol, 0.03),
    exdqlm.tol_elbo = safe_num_refreshed288(controls$tol_elbo, 1e-6),
    exdqlm.vb.min_iter = safe_int_refreshed288(controls$min_iter, 10L),
    exdqlm.vb.patience = safe_int_refreshed288(controls$patience, 3L),
    exdqlm.vb.allow_elbo_drop = safe_num_refreshed288(controls$allow_elbo_drop, 1e-5)
  ))
  on.exit(options(old_opt), add = TRUE)

  runtime_obj <- system.time({
    fit_obj <- exdqlmLDVB(
      y = as.numeric(sim_obj$y),
      p0 = cfg$tau,
      model = model_obj,
      df = rep(cfg$df_value, length(cfg$dim_df)),
      dim.df = as.integer(cfg$dim_df),
      fix.sigma = FALSE,
      sig.init = NA_real_,
      dqlm.ind = isTRUE(cfg$dqlm_ind),
      tol = safe_num_refreshed288(controls$tol, 0.03),
      n.samp = safe_int_refreshed288(controls$n.samp %||% cfg$vb_n_samp_internal, 1000L),
      verbose = FALSE
    )
  })

  wrapped <- list(
    fit = compact_fit_refreshed288(fit_obj, "vb"),
    meta = list(
      runtime_sec = as.numeric(runtime_obj[["elapsed"]]),
      seed = cfg$fit_seed,
      role = role,
      tag = tag
    )
  )
  if (!is.na(save_path) && nzchar(save_path)) saveRDS(wrapped, save_path)
  wrapped
}

build_static_ldvb_fit_refreshed288 <- function(design, controls, ld_controls, save_path = NA_character_, role = c("main_vb", "vb_init")) {
  role <- match.arg(role)
  runtime_obj <- system.time({
    fit_obj <- exal_static_LDVB(
      y = design$y,
      X = design$X,
      p0 = cfg$tau,
      max_iter = safe_int_refreshed288(controls$max_iter, 300L),
      tol = safe_num_refreshed288(controls$tol, 0.03),
      beta_prior = cfg$beta_prior,
      beta_prior_controls = cfg$beta_prior_controls %||% NULL,
      dqlm.ind = isTRUE(cfg$dqlm_ind),
      n_samp_xi = safe_int_refreshed288(controls$n_samp_xi, 1000L),
      ld_controls = ld_controls %||% list(store_trace = TRUE),
      verbose = FALSE
    )
  })

  wrapped <- list(
    fit = compact_fit_refreshed288(fit_obj, "vb"),
    meta = list(
      runtime_sec = as.numeric(runtime_obj[["elapsed"]]),
      seed = cfg$fit_seed,
      role = role,
      tag = tag
    )
  )
  if (!is.na(save_path) && nzchar(save_path)) saveRDS(wrapped, save_path)
  wrapped
}

run_dynamic_refreshed288 <- function() {
  sim_obj <- build_dynamic_sim_object_refreshed288(
    series_wide_path = cfg$series_wide_path,
    true_quantile_grid_path = cfg$true_quantile_grid_path,
    tau = cfg$tau,
    period = cfg$period
  )
  model_obj <- build_dlm_constV_smallW_model_original288_syncedbase_dynamic_restored_closure(
    period = cfg$period,
    no_trend = TRUE
  )

  start_ts <- as.character(Sys.time())
  write_row_status_refreshed288(row, status = "running", ts_start = start_ts)

  tryCatch({
    wrapped <- NULL
    status <- "pending"

    if (file.exists(cfg$candidate_fit_path) && !force) {
      wrapped <- readRDS(cfg$candidate_fit_path)
      status <- "skipped_existing"
    } else {
      set.seed(cfg$fit_seed)
      if (identical(cfg$inference, "vb")) {
        wrapped <- build_dynamic_ldvb_fit_refreshed288(
          sim_obj = sim_obj,
          model_obj = model_obj,
          controls = list(
            max_iter = cfg$vb_max_iter,
            tol = cfg$vb_tol,
            n.samp = cfg$vb_n_samp_internal
          ),
          ld_controls = cfg$ld_controls,
          role = "main_vb"
        )
      } else {
        vb_init_fit <- NULL
        if (isTRUE(cfg$init_from_vb)) {
          if (file.exists(cfg$vb_init_fit_path) && !force) {
            vb_init_fit <- resolve_wrapped_fit_refreshed288(readRDS(cfg$vb_init_fit_path))
          } else {
            vb_wrapped <- build_dynamic_ldvb_fit_refreshed288(
              sim_obj = sim_obj,
              model_obj = model_obj,
              controls = cfg$vb_init_controls,
              ld_controls = cfg$vb_init_ld_controls,
              save_path = cfg$vb_init_fit_path,
              role = "vb_init"
            )
            vb_init_fit <- resolve_wrapped_fit_refreshed288(vb_wrapped)
          }
        }

        call_args <- list(
          y = as.numeric(sim_obj$y),
          p0 = cfg$tau,
          model = model_obj,
          df = rep(cfg$df_value, length(cfg$dim_df)),
          dim.df = as.integer(cfg$dim_df),
          dqlm.ind = isTRUE(cfg$dqlm_ind),
          n.burn = safe_int_refreshed288(cfg$n_burn, 5000L),
          n.mcmc = safe_int_refreshed288(cfg$n_mcmc, 20000L),
          init.from.vb = as_flag_refreshed288(cfg$init_from_vb, TRUE),
          init.from.isvb = FALSE,
          vb_init_controls = cfg$vb_init_controls %||% NULL,
          mh.proposal = safe_chr_refreshed288(cfg$mh_proposal, "slice"),
          mh.adapt = as_flag_refreshed288(cfg$mh_adapt, TRUE),
          mh.adapt.interval = safe_int_refreshed288(cfg$mh_adapt_interval, 50L),
          mh.target.accept = c(cfg$mh_target_accept_lo, cfg$mh_target_accept_hi),
          mh.scale.bounds = c(cfg$mh_scale_lo, cfg$mh_scale_hi),
          mh.max_scale.step = safe_num_refreshed288(cfg$mh_max_scale_step, 0.35),
          mh.min_burn_adapt = safe_int_refreshed288(cfg$mh_min_burn_adapt, 50L),
          trace.diagnostics = as_flag_refreshed288(cfg$trace_diagnostics, TRUE),
          trace.every = safe_int_refreshed288(cfg$trace_every, 50L),
          verbose = FALSE
        )
        if (!is.null(vb_init_fit)) call_args$vb_init_fit <- vb_init_fit
        if (!is.null(cfg$slice_width) && (is.finite(cfg$slice_width) || is.infinite(cfg$slice_width))) {
          call_args$slice.width <- as.numeric(cfg$slice_width)
        }
        if (!is.null(cfg$slice_max_steps) && (is.finite(cfg$slice_max_steps) || is.infinite(cfg$slice_max_steps))) {
          call_args$slice.max.steps <- as.numeric(cfg$slice_max_steps)
        }

        runtime_obj <- system.time({
          fit_obj <- do.call(exdqlmMCMC, call_args)
        })
        wrapped <- list(
          fit = compact_fit_refreshed288(fit_obj, "mcmc"),
          meta = list(
            runtime_sec = as.numeric(runtime_obj[["elapsed"]]),
            seed = cfg$fit_seed,
            tag = tag
          )
        )
      }

      saveRDS(wrapped, cfg$candidate_fit_path)
      status <- "done"
    }

    fit_obj <- resolve_wrapped_fit_refreshed288(wrapped)
    case_id <- safe_chr_refreshed288(cfg$original_case_key, sprintf("row_%04d", row_id))

    if (identical(cfg$inference, "mcmc")) {
      health_metrics <- vhg_collect_mcmc_metrics(wrapped, case_id = case_id, variant = tag, candidate_path = cfg$candidate_fit_path)
      health_row <- vhg_apply_health_gates(health_metrics)
    } else {
      health_row <- collect_vb_health_refreshed288(
        wrapped = wrapped,
        case_id = case_id,
        variant = tag,
        candidate_path = cfg$candidate_fit_path,
        vhg_extract_rhs_collapse = vhg_extract_rhs_collapse
      )
    }

    source_draw_count <- ncol(as.matrix(fit_obj$samp.post.pred))
    selected_indices <- select_draw_indices_refreshed288(source_draw_count, cfg$stored_posterior_draws, cfg$fit_seed)
    draw_keep <- as.matrix(fit_obj$samp.post.pred)[, selected_indices, drop = FALSE]
    metric_core <- dynamic_metrics_refreshed288(row, sim_obj, draw_keep)

    saveRDS(
      list(
        kind = "dynamic_predictive_draw_contract",
        source_fit_path = cfg$candidate_fit_path,
        source_draw_count = source_draw_count,
        selected_indices = selected_indices,
        n_posterior_draws = cfg$stored_posterior_draws,
        seed = cfg$fit_seed
      ),
      cfg$draws_path
    )

    metrics_row <- data.frame(
      row_id = row_id,
      base_row_id = row$base_row_id,
      original_case_key = row$original_case_key,
      phase = row$phase,
      block = row$block,
      root_kind = row$root_kind,
      family = row$family,
      tau_label = row$tau_label,
      fit_size = row$fit_size,
      prior_semantics = row$prior_semantics,
      model = row$model,
      inference = row$inference,
      method_profile_id = row$method_profile_id,
      seed = row$seed,
      gate_overall = safe_chr_refreshed288(health_row$gate_overall[1], "FAIL"),
      healthy = isTRUE(health_row$healthy[1]),
      runtime_sec = safe_num_refreshed288(health_row$run_time_sec[1], safe_num_refreshed288(wrapped$meta$runtime_sec, NA_real_)),
      crps_metric = metric_core$crps[[1]],
      primary_accuracy_metric = metric_core$q_rmse[[1]],
      q_rmse_metric = metric_core$q_rmse[[1]],
      coverage95_metric = metric_core$coverage95[[1]],
      coverage95_gap_metric = metric_core$coverage95_gap[[1]],
      mean_ci_width_metric = metric_core$mean_ci_width[[1]],
      cie_metric = NA_real_,
      beta_rmse_mean_metric = NA_real_,
      beta_coverage_gap_metric = NA_real_,
      metric_source = "refreshed288_dynamic",
      metric_error = NA_character_,
      stringsAsFactors = FALSE
    )

    utils::write.csv(health_row, cfg$health_path, row.names = FALSE)
    utils::write.csv(metrics_row, cfg$metrics_path, row.names = FALSE)
    write_row_status_refreshed288(
      row = row,
      status = status,
      ts_start = start_ts,
      ts_end = as.character(Sys.time()),
      error = NA_character_,
      gate_overall = metrics_row$gate_overall[1],
      healthy = isTRUE(metrics_row$healthy[1]),
      runtime_sec = metrics_row$runtime_sec[1]
    )
  }, error = function(e) {
    write_row_failure_refreshed288(row, conditionMessage(e))
  })
}

run_static_refreshed288 <- function() {
  series_wide <- utils::read.csv(cfg$series_wide_path, stringsAsFactors = FALSE, check.names = FALSE)
  coef_truth <- utils::read.csv(cfg$coef_truth_path, stringsAsFactors = FALSE, check.names = FALSE)
  design <- static_build_design_refreshed288(series_wide)

  start_ts <- as.character(Sys.time())
  write_row_status_refreshed288(row, status = "running", ts_start = start_ts)

  tryCatch({
    wrapped <- NULL
    status <- "pending"

    if (file.exists(cfg$candidate_fit_path) && !force) {
      wrapped <- readRDS(cfg$candidate_fit_path)
      status <- "skipped_existing"
    } else {
      set.seed(cfg$fit_seed)
      if (identical(cfg$inference, "vb")) {
        wrapped <- build_static_ldvb_fit_refreshed288(
          design = design,
          controls = list(
            max_iter = cfg$max_iter,
            tol = cfg$tol,
            n_samp_xi = cfg$n_samp_xi
          ),
          ld_controls = cfg$ld_controls,
          role = "main_vb"
        )
      } else {
        vb_init_fit <- NULL
        if (isTRUE(cfg$init_from_vb)) {
          if (file.exists(cfg$vb_init_fit_path) && !force) {
            vb_init_fit <- resolve_wrapped_fit_refreshed288(readRDS(cfg$vb_init_fit_path))
          } else {
            vb_wrapped <- build_static_ldvb_fit_refreshed288(
              design = design,
              controls = cfg$vb_init_controls,
              ld_controls = cfg$vb_init_controls$ld_controls %||% canonical_static_ld_controls_refreshed288(store_trace = FALSE),
              save_path = cfg$vb_init_fit_path,
              role = "vb_init"
            )
            vb_init_fit <- resolve_wrapped_fit_refreshed288(vb_wrapped)
          }
        }

        call_args <- list(
          y = design$y,
          X = design$X,
          p0 = cfg$tau,
          beta_prior = cfg$beta_prior,
          beta_prior_controls = cfg$beta_prior_controls %||% NULL,
          dqlm.ind = isTRUE(cfg$dqlm_ind),
          n.burn = safe_int_refreshed288(cfg$n_burn, 5000L),
          n.mcmc = safe_int_refreshed288(cfg$n_mcmc, 20000L),
          thin = safe_int_refreshed288(cfg$thin, 1L),
          init.from.vb = as_flag_refreshed288(cfg$init_from_vb, TRUE),
          vb_init_controls = cfg$vb_init_controls %||% NULL,
          mh.proposal = safe_chr_refreshed288(cfg$mh_proposal, "slice"),
          mh.adapt = as_flag_refreshed288(cfg$mh_adapt, TRUE),
          mh.adapt.interval = safe_int_refreshed288(cfg$mh_adapt_interval, 50L),
          mh.target.accept = c(cfg$mh_target_accept_lo, cfg$mh_target_accept_hi),
          mh.scale.bounds = c(cfg$mh_scale_lo, cfg$mh_scale_hi),
          mh.max_scale.step = safe_num_refreshed288(cfg$mh_max_scale_step, 0.35),
          mh.min_burn_adapt = safe_int_refreshed288(cfg$mh_min_burn_adapt, 50L),
          gamma.substeps = safe_int_refreshed288(cfg$gamma_substeps, 1L),
          p.global.eta.jump = safe_num_refreshed288(cfg$p_global_eta_jump, 0),
          global.eta.jump.scale = safe_num_refreshed288(cfg$global_eta_jump_scale, 1),
          trace.diagnostics = as_flag_refreshed288(cfg$trace_diagnostics, TRUE),
          trace.every = safe_int_refreshed288(cfg$trace_every, 50L),
          verbose = FALSE
        )
        if (!is.null(vb_init_fit)) call_args$vb_init_fit <- vb_init_fit
        if (!is.null(cfg$slice_width) && (is.finite(cfg$slice_width) || is.infinite(cfg$slice_width))) {
          call_args$slice.width <- as.numeric(cfg$slice_width)
        }
        if (!is.null(cfg$slice_max_steps) && (is.finite(cfg$slice_max_steps) || is.infinite(cfg$slice_max_steps))) {
          call_args$slice.max.steps <- as.numeric(cfg$slice_max_steps)
        }

        runtime_obj <- system.time({
          fit_obj <- do.call(exal_static_mcmc, call_args)
        })
        wrapped <- list(
          fit = compact_fit_refreshed288(fit_obj, "mcmc"),
          meta = list(
            runtime_sec = as.numeric(runtime_obj[["elapsed"]]),
            seed = cfg$fit_seed,
            tag = tag
          )
        )
      }

      saveRDS(wrapped, cfg$candidate_fit_path)
      status <- "done"
    }

    fit_obj <- resolve_wrapped_fit_refreshed288(wrapped)
    case_id <- safe_chr_refreshed288(cfg$original_case_key, sprintf("row_%04d", row_id))

    if (identical(cfg$inference, "mcmc")) {
      health_metrics <- vhg_collect_mcmc_metrics(wrapped, case_id = case_id, variant = tag, candidate_path = cfg$candidate_fit_path)
      health_row <- vhg_apply_health_gates(health_metrics)
    } else {
      health_row <- collect_vb_health_refreshed288(
        wrapped = wrapped,
        case_id = case_id,
        variant = tag,
        candidate_path = cfg$candidate_fit_path,
        vhg_extract_rhs_collapse = vhg_extract_rhs_collapse
      )
    }

    draw_bundle <- static_predictive_draws_refreshed288(
      fit_obj = fit_obj,
      row = row,
      series_wide = series_wide,
      n_draws = cfg$stored_posterior_draws,
      seed = cfg$fit_seed
    )
    metric_core <- static_metrics_refreshed288(row, fit_obj, series_wide, coef_truth, draw_bundle)

    saveRDS(
      list(
        kind = "static_parameter_draw_export",
        source_fit_path = cfg$candidate_fit_path,
        n_posterior_draws = cfg$stored_posterior_draws,
        seed = cfg$fit_seed,
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
      block = row$block,
      root_kind = row$root_kind,
      family = row$family,
      tau_label = row$tau_label,
      fit_size = row$fit_size,
      prior_semantics = row$prior_semantics,
      model = row$model,
      inference = row$inference,
      method_profile_id = row$method_profile_id,
      seed = row$seed,
      gate_overall = safe_chr_refreshed288(health_row$gate_overall[1], "FAIL"),
      healthy = isTRUE(health_row$healthy[1]),
      runtime_sec = safe_num_refreshed288(health_row$run_time_sec[1], safe_num_refreshed288(wrapped$meta$runtime_sec, NA_real_)),
      crps_metric = metric_core$crps[[1]],
      primary_accuracy_metric = metric_core$q_rmse[[1]],
      q_rmse_metric = metric_core$q_rmse[[1]],
      coverage95_metric = metric_core$coverage95[[1]],
      coverage95_gap_metric = metric_core$coverage95_gap[[1]],
      mean_ci_width_metric = metric_core$mean_ci_width[[1]],
      cie_metric = metric_core$cie[[1]],
      beta_rmse_mean_metric = metric_core$beta_rmse_mean[[1]],
      beta_coverage_gap_metric = metric_core$beta_coverage_gap[[1]],
      metric_source = "refreshed288_static",
      metric_error = NA_character_,
      stringsAsFactors = FALSE
    )

    utils::write.csv(health_row, cfg$health_path, row.names = FALSE)
    utils::write.csv(metrics_row, cfg$metrics_path, row.names = FALSE)
    write_row_status_refreshed288(
      row = row,
      status = status,
      ts_start = start_ts,
      ts_end = as.character(Sys.time()),
      error = NA_character_,
      gate_overall = metrics_row$gate_overall[1],
      healthy = isTRUE(metrics_row$healthy[1]),
      runtime_sec = metrics_row$runtime_sec[1]
    )
    gc()
  }, error = function(e) {
    write_row_failure_refreshed288(row, conditionMessage(e))
  })
}

if (identical(cfg$block, "dynamic")) {
  run_dynamic_refreshed288()
} else {
  run_static_refreshed288()
}

cat(sprintf(
  "[refreshed288 row %d] phase=%s model=%s inference=%s done\n",
  row_id,
  row$phase[[1]],
  row$model[[1]],
  row$inference[[1]]
))

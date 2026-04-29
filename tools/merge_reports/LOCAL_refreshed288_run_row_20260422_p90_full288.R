#!/usr/bin/env Rscript

options(stringsAsFactors = FALSE)

source("tools/merge_reports/LOCAL_refreshed288_helpers_20260422_p90_full288.R")
source("tools/merge_reports/LOCAL_validation_health_gate_common_20260321.R")

args <- parse_args_refreshed288(commandArgs(trailingOnly = TRUE))
repo_root <- normalizePath(".", winslash = "/", mustWork = TRUE)
setwd(repo_root)

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
  dirname(cfg$plot_summary_path %||% plot_summary_path_refreshed288(row)),
  dirname(cfg$parameter_summary_path %||% parameter_summary_path_refreshed288(row)),
  dirname(cfg$predictive_quantile_grid_path %||% predictive_quantile_grid_path_refreshed288(row)),
  dirname(cfg$vb_init_fit_path %||% "")
)) {
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

set_vb_joint_options_refreshed288 <- function(min_iter, tol) {
  options(list(
    exdqlm.tol_sigma = safe_num_refreshed288(tol, 0.03),
    exdqlm.tol_gamma = safe_num_refreshed288(tol, 0.03),
    exdqlm.tol_elbo = 1e-6,
    exdqlm.vb.min_iter = safe_int_refreshed288(min_iter, 80L),
    exdqlm.vb.patience = 3L,
    exdqlm.vb.allow_elbo_drop = 1e-5
  ))
}

set_dynamic_mcmc_options_refreshed288 <- function(cfg) {
  opt <- list()
  if (!is.null(cfg$mcmc_use_cpp)) {
    opt$exdqlm.use_cpp_mcmc <- as_flag_refreshed288(cfg$mcmc_use_cpp, TRUE)
  }
  if (!is.null(cfg$mcmc_cpp_mode) && nzchar(safe_chr_refreshed288(cfg$mcmc_cpp_mode, ""))) {
    opt$exdqlm.cpp_mcmc_mode <- safe_chr_refreshed288(cfg$mcmc_cpp_mode, "strict")
  }
  if (!length(opt)) return(list())
  options(opt)
}

build_dynamic_sim_object_refreshed288_p90 <- function(cfg) {
  use_full_root <- as_flag_refreshed288(
    cfg$dynamic_use_full_root %||% Sys.getenv("REFRESHED288_DYNAMIC_USE_FULL_ROOT", unset = "false"),
    FALSE
  )
  if (isTRUE(use_full_root) && !is.null(cfg$sim_output_path) && nzchar(cfg$sim_output_path) && file.exists(cfg$sim_output_path)) {
    return(readRDS(cfg$sim_output_path))
  }

  sim_obj <- build_dynamic_sim_object_refreshed288(
    series_wide_path = cfg$series_wide_path,
    true_quantile_grid_path = cfg$true_quantile_grid_path,
    tau = cfg$tau,
    period = cfg$period
  )
  expected_n <- safe_int_refreshed288(cfg$fit_size, safe_int_refreshed288(row$fit_size, NA_integer_))
  if (is.finite(expected_n) && length(sim_obj$y) != expected_n) {
    stop(
      sprintf("dynamic_window_length_mismatch: expected fit_size=%d but got n=%d from %s", expected_n, length(sim_obj$y), cfg$series_wide_path),
      call. = FALSE
    )
  }
  sim_obj
}

dynamic_source_index_start_refreshed288_p90 <- function(sim_obj) {
  series <- sim_obj$source_series_wide %||% NULL
  if (is.null(series) || !"t" %in% names(series) || !nrow(series)) return(1L)
  start_index <- suppressWarnings(as.integer(series$t[1L]))
  if (!is.finite(start_index) || start_index < 1L) 1L else start_index
}

build_dynamic_model_refreshed288_p90 <- function(cfg, TT, source_index_start = 1L) {
  params <- cfg$dynamic_model_params %||% list(period = cfg$period, harmonics = c(1L, 2L))
  if (is.character(params$harmonics)) {
    params$harmonics <- suppressWarnings(as.integer(trimws(strsplit(params$harmonics, ",", fixed = TRUE)[[1L]])))
  }
  build_dynamic_dgp_matched_model(
    params = params,
    TT = TT,
    backend = "R",
    start_index = source_index_start
  )
}

build_dynamic_vb_control_refreshed288_p90 <- function(cfg, verbose = FALSE) {
  exal_make_vb_control(
    max_iter = safe_int_refreshed288(cfg$vb_max_iter, 300L),
    tol = safe_num_refreshed288(cfg$vb_tol, 0.03),
    verbose = isTRUE(verbose)
  )
}

build_static_vb_control_refreshed288_p90 <- function(cfg, verbose = FALSE) {
  exal_make_vb_control(
    max_iter = safe_int_refreshed288(cfg$vb_max_iter %||% cfg$max_iter, 300L),
    tol = safe_num_refreshed288(cfg$vb_tol %||% cfg$tol, 0.03),
    n_samp_xi = safe_int_refreshed288(cfg$n_samp_xi, 1000L),
    verbose = isTRUE(verbose)
  )
}

build_dynamic_mcmc_control_refreshed288_p90 <- function(cfg) {
  exal_make_mcmc_control(
    n_burn = safe_int_refreshed288(cfg$n_burn, 5000L),
    n_mcmc = safe_int_refreshed288(cfg$n_mcmc, 20000L),
    init_from_vb = as_flag_refreshed288(cfg$init_from_vb, TRUE),
    verbose = FALSE,
    progress_every = safe_int_refreshed288(cfg$trace_every, 50L)
  )
}

build_static_mcmc_control_refreshed288_p90 <- function(cfg) {
  exal_make_mcmc_control(
    n_burn = safe_int_refreshed288(cfg$n_burn, 5000L),
    n_mcmc = safe_int_refreshed288(cfg$n_mcmc, 20000L),
    thin = safe_int_refreshed288(cfg$thin, 1L),
    init_from_vb = as_flag_refreshed288(cfg$init_from_vb, TRUE),
    verbose = FALSE
  )
}

build_dynamic_ldvb_fit_refreshed288 <- function(sim_obj, model_obj, cfg, save_path = NA_character_, role = c("main_vb", "vb_init")) {
  role <- match.arg(role)
  old_ld <- set_dynamic_ld_options_refreshed288(cfg$ld_controls %||% list(store_trace = identical(role, "main_vb")))
  on.exit(if (length(old_ld)) options(old_ld), add = TRUE)
  old_joint <- set_vb_joint_options_refreshed288(cfg$vb_min_iter %||% cfg$min_iter, cfg$vb_tol %||% cfg$tol)
  on.exit(options(old_joint), add = TRUE)

  vb_control <- build_dynamic_vb_control_refreshed288_p90(cfg, verbose = FALSE)
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
      tol = safe_num_refreshed288(cfg$vb_tol %||% cfg$tol, 0.03),
      n.samp = safe_int_refreshed288(cfg$vb_n_samp_internal, 20000L),
      vb_control = vb_control,
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

build_static_ldvb_fit_refreshed288 <- function(design, cfg, save_path = NA_character_, role = c("main_vb", "vb_init")) {
  role <- match.arg(role)
  vb_control <- build_static_vb_control_refreshed288_p90(cfg, verbose = FALSE)
  ld_controls <- cfg$ld_controls %||% list(store_trace = identical(role, "main_vb"))
  runtime_obj <- system.time({
    fit_obj <- exalStaticLDVB(
      y = design$y,
      X = design$X,
      p0 = cfg$tau,
      beta_prior = cfg$beta_prior,
      beta_prior_controls = cfg$beta_prior_controls %||% NULL,
      dqlm.ind = isTRUE(cfg$dqlm_ind),
      n_samp_xi = safe_int_refreshed288(cfg$n_samp_xi, 1000L),
      ld_controls = ld_controls,
      vb_control = vb_control,
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

validate_dynamic_vb_init_fit_refreshed288 <- function(fit_obj, validation) {
  validation <- validation %||% list()
  if (!length(validation)) return(invisible(TRUE))

  failures <- character(0)
  check_required <- function(flag, ok, label) {
    if (as_flag_refreshed288(flag, FALSE) && !isTRUE(ok)) {
      failures <<- c(failures, label)
    }
  }

  theta_vals <- suppressWarnings(as.numeric(fit_obj$samp.theta))
  post_pred_vals <- suppressWarnings(as.numeric(fit_obj$samp.post.pred))
  sfe_vals <- suppressWarnings(as.numeric(fit_obj$map.standard.forecast.errors))
  sigma_vals <- suppressWarnings(as.numeric(fit_obj$samp.sigma))
  gamma_vals <- if (!is.null(fit_obj$samp.gamma)) suppressWarnings(as.numeric(fit_obj$samp.gamma)) else numeric(0)

  check_required(validation$require_theta_finite, length(theta_vals) > 0L && all(is.finite(theta_vals)), "theta_nonfinite")
  check_required(validation$require_post_pred_finite, length(post_pred_vals) > 0L && all(is.finite(post_pred_vals)), "post_pred_nonfinite")
  check_required(validation$require_sfe_finite, length(sfe_vals) > 0L && all(is.finite(sfe_vals)), "sfe_nonfinite")
  check_required(validation$require_sigma_finite, length(sigma_vals) > 0L && all(is.finite(sigma_vals)) && all(sigma_vals > 0), "sigma_invalid")
  check_required(validation$require_gamma_finite, length(gamma_vals) > 0L && all(is.finite(gamma_vals)), "gamma_invalid")

  if (length(failures)) {
    stop(sprintf("vb_init_validation_fail: %s", paste(unique(failures), collapse = "; ")), call. = FALSE)
  }

  invisible(TRUE)
}

mcmc_vb_init_cache_enabled_refreshed288 <- function() {
  mode <- tolower(trimws(Sys.getenv("REFRESHED288_MCMC_VB_INIT_CACHE", unset = "memory_only")))
  memory_only_modes <- c(
    "0", "false", "no", "none", "off", "disable", "disabled",
    "memory_only", "memory-only", "no_cache", "nocache"
  )
  !mode %in% memory_only_modes
}

run_dynamic_refreshed288 <- function() {
  if (!force && row_completed_lightweight_artifacts_ready_refreshed288(row, cfg)) {
    cat(sprintf("[refreshed288 p90 row %d] lightweight artifacts already complete; skipping\n", row_id))
    return(invisible(TRUE))
  }

  sim_obj <- build_dynamic_sim_object_refreshed288_p90(cfg)
  source_index_start <- dynamic_source_index_start_refreshed288_p90(sim_obj)
  model_obj <- build_dynamic_model_refreshed288_p90(
    cfg,
    TT = length(sim_obj$y),
    source_index_start = source_index_start
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
          cfg = cfg,
          role = "main_vb"
        )
      } else {
        vb_init_fit <- NULL
        if (isTRUE(cfg$init_from_vb)) {
          cache_vb_init <- mcmc_vb_init_cache_enabled_refreshed288() &&
            isTRUE(retention_policy_refreshed288(cfg$retention_mode %||% default_retention_mode_refreshed288())$retain_vb_init_binaries)
          if (cache_vb_init && file.exists(cfg$vb_init_fit_path) && !force) {
            vb_init_fit <- resolve_wrapped_fit_refreshed288(readRDS(cfg$vb_init_fit_path))
          } else {
            vb_wrapped <- build_dynamic_ldvb_fit_refreshed288(
              sim_obj = sim_obj,
              model_obj = model_obj,
              cfg = c(cfg, cfg$vb_init_controls %||% list()),
              save_path = if (cache_vb_init) cfg$vb_init_fit_path else NA_character_,
              role = "vb_init"
            )
            vb_init_fit <- resolve_wrapped_fit_refreshed288(vb_wrapped)
          }
          validate_dynamic_vb_init_fit_refreshed288(vb_init_fit, cfg$vb_init_validation %||% NULL)
        }

        call_args <- list(
          y = as.numeric(sim_obj$y),
          p0 = cfg$tau,
          model = model_obj,
          df = rep(cfg$df_value, length(cfg$dim_df)),
          dim.df = as.integer(cfg$dim_df),
          dqlm.ind = isTRUE(cfg$dqlm_ind),
          fix.sigma = FALSE,
          n.burn = safe_int_refreshed288(cfg$n_burn, 5000L),
          n.mcmc = safe_int_refreshed288(cfg$n_mcmc, 20000L),
          init.from.vb = as_flag_refreshed288(cfg$init_from_vb, TRUE),
          init.from.isvb = FALSE,
          vb_init_controls = cfg$vb_init_controls %||% NULL,
          vb_init_fit = vb_init_fit,
          mcmc_control = build_dynamic_mcmc_control_refreshed288_p90(cfg),
          sigmagam_controls = cfg$sigmagam_controls %||% NULL,
          latent_state_controls = cfg$latent_state_controls %||% NULL,
          theta_state_controls = cfg$theta_state_controls %||% NULL,
          dqlm_sigma_controls = cfg$dqlm_sigma_controls %||% NULL,
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
        if (!is.null(cfg$slice_width) && (is.finite(cfg$slice_width) || is.infinite(cfg$slice_width))) {
          call_args$slice.width <- as.numeric(cfg$slice_width)
        }
        if (!is.null(cfg$slice_max_steps) && (is.finite(cfg$slice_max_steps) || is.infinite(cfg$slice_max_steps))) {
          call_args$slice.max.steps <- as.numeric(cfg$slice_max_steps)
        }

        old_mcmc_opt <- set_dynamic_mcmc_options_refreshed288(cfg)
        on.exit(if (length(old_mcmc_opt)) options(old_mcmc_opt), add = TRUE)
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

    policy <- retention_policy_refreshed288(cfg$retention_mode %||% default_retention_mode_refreshed288(), metrics_row$gate_overall[1])
    if (isTRUE(policy$write_plot_summary)) {
      source_index <- if (!is.null(sim_obj$source_series_wide) && "t" %in% names(sim_obj$source_series_wide)) sim_obj$source_series_wide$t else seq_along(sim_obj$y)
      q_true <- if (!is.null(sim_obj$q) && nrow(as.matrix(sim_obj$q)) == length(sim_obj$y)) as.numeric(as.matrix(sim_obj$q)[, 1L]) else rep(NA_real_, length(sim_obj$y))
      write_plot_summary_refreshed288(
        row = row,
        y = as.numeric(sim_obj$y),
        q_true = q_true,
        draw_mat = draw_keep,
        source_index = source_index,
        path = cfg$plot_summary_path %||% plot_summary_path_refreshed288(row),
        artifact_note = "generated_in_runner"
      )
      if (isTRUE(policy$write_predictive_quantile_grid)) {
        write_predictive_quantile_grid_refreshed288(
          row = row,
          draw_mat = draw_keep,
          source_index = source_index,
          path = cfg$predictive_quantile_grid_path %||% predictive_quantile_grid_path_refreshed288(row)
        )
      }
    }

    if (isTRUE(policy$retain_draw_binaries)) {
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
    }
    if (isTRUE(policy$retain_candidate_fit_binaries)) {
      saveRDS(wrapped, cfg$candidate_fit_path)
    }

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
      runtime_sec = metrics_row$runtime_sec[1],
      retention_mode = policy$mode,
      fit_retained = file.exists(cfg$candidate_fit_path),
      draws_retained = file.exists(cfg$draws_path),
      vb_init_retained = file.exists(cfg$vb_init_fit_path),
      plot_summary_retained = file.exists(cfg$plot_summary_path %||% plot_summary_path_refreshed288(row)),
      parameter_summary_retained = NA
    )
  }, error = function(e) {
    write_row_failure_refreshed288(row, conditionMessage(e))
  })
}

run_static_refreshed288 <- function() {
  if (!force && row_completed_lightweight_artifacts_ready_refreshed288(row, cfg)) {
    cat(sprintf("[refreshed288 p90 row %d] lightweight artifacts already complete; skipping\n", row_id))
    return(invisible(TRUE))
  }

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
          cfg = cfg,
          role = "main_vb"
        )
      } else {
        vb_init_fit <- NULL
        if (isTRUE(cfg$init_from_vb)) {
          cache_vb_init <- mcmc_vb_init_cache_enabled_refreshed288() &&
            isTRUE(retention_policy_refreshed288(cfg$retention_mode %||% default_retention_mode_refreshed288())$retain_vb_init_binaries)
          if (cache_vb_init && file.exists(cfg$vb_init_fit_path) && !force) {
            vb_init_fit <- resolve_wrapped_fit_refreshed288(readRDS(cfg$vb_init_fit_path))
          } else {
            vb_wrapped <- build_static_ldvb_fit_refreshed288(
              design = design,
              cfg = c(cfg, cfg$vb_init_controls %||% list()),
              save_path = if (cache_vb_init) cfg$vb_init_fit_path else NA_character_,
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
          vb_init_fit = vb_init_fit,
          mcmc_control = build_static_mcmc_control_refreshed288_p90(cfg),
          sigmagam_controls = cfg$sigmagam_controls %||% NULL,
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
        if (!is.null(cfg$slice_width) && (is.finite(cfg$slice_width) || is.infinite(cfg$slice_width))) {
          call_args$slice.width <- as.numeric(cfg$slice_width)
        }
        if (!is.null(cfg$slice_max_steps) && (is.finite(cfg$slice_max_steps) || is.infinite(cfg$slice_max_steps))) {
          call_args$slice.max.steps <- as.numeric(cfg$slice_max_steps)
        }

        runtime_obj <- system.time({
          fit_obj <- do.call(exalStaticMCMC, call_args)
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

    policy <- retention_policy_refreshed288(cfg$retention_mode %||% default_retention_mode_refreshed288(), metrics_row$gate_overall[1])
    if (isTRUE(policy$write_plot_summary)) {
      write_plot_summary_refreshed288(
        row = row,
        y = design$y,
        q_true = design$q_truth,
        draw_mat = draw_bundle$draws,
        source_index = if ("row_id" %in% names(series_wide)) series_wide$row_id else seq_along(design$y),
        path = cfg$plot_summary_path %||% plot_summary_path_refreshed288(row),
        artifact_note = "generated_in_runner"
      )
      if (isTRUE(policy$write_predictive_quantile_grid)) {
        write_predictive_quantile_grid_refreshed288(
          row = row,
          draw_mat = draw_bundle$draws,
          source_index = if ("row_id" %in% names(series_wide)) series_wide$row_id else seq_along(design$y),
          path = cfg$predictive_quantile_grid_path %||% predictive_quantile_grid_path_refreshed288(row)
        )
      }
    }
    if (isTRUE(policy$write_parameter_summary)) {
      write_parameter_summary_refreshed288(
        row = row,
        beta_draws = draw_bundle$beta_draws,
        sigma_draws = draw_bundle$sigma_draws,
        gamma_draws = draw_bundle$gamma_draws,
        coef_truth = coef_truth,
        design = design,
        path = cfg$parameter_summary_path %||% parameter_summary_path_refreshed288(row)
      )
    }
    if (isTRUE(policy$retain_draw_binaries)) {
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
    }
    if (isTRUE(policy$retain_candidate_fit_binaries)) {
      saveRDS(wrapped, cfg$candidate_fit_path)
    }

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
      runtime_sec = metrics_row$runtime_sec[1],
      retention_mode = policy$mode,
      fit_retained = file.exists(cfg$candidate_fit_path),
      draws_retained = file.exists(cfg$draws_path),
      vb_init_retained = file.exists(cfg$vb_init_fit_path),
      plot_summary_retained = file.exists(cfg$plot_summary_path %||% plot_summary_path_refreshed288(row)),
      parameter_summary_retained = file.exists(cfg$parameter_summary_path %||% parameter_summary_path_refreshed288(row))
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
  "[refreshed288 p90 row %d] phase=%s model=%s inference=%s done\n",
  row_id,
  row$phase[[1]],
  row$model[[1]],
  row$inference[[1]]
))
